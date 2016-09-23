--[[
The MIT License (MIT)

Copyright (c) 2016 Daniel Rasmussen, Sol Bekic

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

local ffi = require("ffi")
local BinaryReader = require("binaryReader")

function readImage(reader, width, height, channelCount)
  if width == 0 or height == 0 then
    reader:skip(1) -- skip compression
    return nil
  end

  reader = reader:push()
  local imageData = love.image.newImageData(width, height)
  local data = ffi.cast("uint8_t *", imageData:getPointer())

  local compression = reader:inkUint(2)

  if compression == 0 then
    local channelSize = width * height

    -- Photoshop:      LÖVE/GL:
    --  RRRR...         RGBA
    --  GGGG...         RGBA
    --  BBBB...         RGBA
    --  AAAA...         RGBA
    --                  ...
    for pixel = 0, channelSize*4, 4 do
      data[pixel + 0] = reader.filePointer[reader.count]
      data[pixel + 1] = reader.filePointer[reader.count + channelSize]
      data[pixel + 2] = reader.filePointer[reader.count + channelSize + channelSize]
      if channelCount > 3 then
        data[pixel + 3] = reader.filePointer[reader.count + channelSize + channelSize + channelSize]
      else
        data[pixel + 3] = 255
      end

      reader:skip(1)
    end
  elseif compression == 1 then
    local channels = {}
    for i=1,channelCount do
      channels[i] = {}
      for l=1,height do
        channels[i][l] = reader:inkUint(1)
      end
    end

    for i, channel in ipairs(channels) do
      local channelOffset = i - 1
      for l, length in ipairs(channel) do
        local line = reader:push(length)

        local pixel = (l - 1) * width

        while line.count < line.stop do
          local head = line:inkInt(2)
          --if head >= 0 then
          --  for i=1, 1 + head do
          --    local value = line:inkUint(1)
          --    data[pixel * 4 + channelOffset] = value
          --    pixel = pixel + 1
          --  end
          --elseif head > -128 then
          --  local value = line:inkUint(1)
          --  for i=1, 1 - head do
          --    data[pixel * 4 + channelOffset] = value
          --    pixel = pixel + 1
          --  end
          --else
          --  line:skip(1)
          --end
        end
        line:pop()
      end
    end

    --print("compression not currently supported")
  end

  reader:pop()
  return love.graphics.newImage(imageData)
end

local function readHeader(reader)
  local reader = reader:push(26)
  assert(reader:inkString(4) == "8BPS", ".psd magic wrong")
  assert(reader:inkUint(2) == 1, ".psd magic version wrong")

  reader:skip(6) -- reserved space

  local channelCount = reader:inkUint(2)
  local width, height = reader:inkUint(4), reader:inkUint(4)
  local depth = reader:inkUint(2)
  local colorMode = reader:inkUint(2)

  assert(depth == 8, "currently only 8-bit images are supported, depth was " .. depth)
  assert(colorMode == 3, "currently only RGB images are supported, colorMode was " .. colorMode)
  reader:pop()

  return width, height, channelCount
end

local function readColorModeData(reader)
  local length = reader:inkUint(4)
  assert(length == 0, "expected color mode data to be empty, length was " .. length)
end

local function readImageResources(reader)
  reader = reader:push(reader:inkUint(4))
  -- TODO: stub
  reader:pop()
end

local function readLayers(reader)
  reader = reader:push(reader:inkUint(4))
  local layerCount = reader:inkInt(2)
  local globalAlpha = layerCount < 1
  layerCount = math.abs(layerCount)

  local layers = {}
  for i=1, layerCount do
    local layer = {}
    layer.top, layer.left = reader:inkUint(4), reader:inkUint(4)
    layer.bottom, layer.right = reader:inkUint(4), reader:inkUint(4)

    local channelCount = reader:inkUint(2)
    assert(channelCount == 3 or channelCount == 4, "only 3 or 4 channels supported per layer, channelCount was " .. channelCount)

    layer.channels = {}
    for i=1, channelCount do
      local id = reader:inkInt(2)
      local dataLength = reader:inkUint(4)

      assert(id >= -1 and id <= 2, "unsupported channel ID: " .. id)

      table.insert(layer.channels, { id = id, length = dataLength })
    end

    assert(reader:inkString(4) == "8BIM", "BlendMode signature wrong")
    layer.blendMode = reader:inkString(4)
    layer.opacity = reader:inkUint(1)
    layer.clipping = reader:inkUint(1)
    layer.flags = reader:inkUint(1)
    reader:skip(1)

    local extra = reader:push(reader:inkUint(4))
      local maskAdjustment = extra:push(extra:inkUint(4))
      -- TODO: stub
      maskAdjustment:pop()

      local blendingRanges = extra:push(extra:inkUint(4))
      -- TODO: stub
      blendingRanges:pop()

      local nameLength = extra:inkUint(1)
      layer.name = extra:inkString(nameLength)
      nameLength = nameLength + 1
      if nameLength % 4 > 0 then
        extra:skip(4 - (nameLength % 4))
      end

      while extra.count < extra.stop do
        assert(extra:inkString(4) == "8BIM", "extra info signature wrong")
        local key = extra:inkString(4)
        local info = extra:push(extra:inkUint(4))
        if key == "luni" then -- unicode layer name
          layer.name = info:inkUnicodeString(info.stop - info.count)
          if layer.other then layer.other.name = layer.name end
        elseif key == "lsct" then -- section divider setting
          local type = info:inkUint(4)
          if type == 3 then
            layer.type = "still_open"
          elseif type == 1 or type == 2 then -- open / close
            for i=#layers, 1, -1 do
              local other = layers[i]
              if other.type == "still_open" then
                other.type = "open"
                other.name = layer.name
                layer.other = other
                -- TODO: opacity baking
                break
              end
            end
            assert(layer.other, "couldnt't find 'open' layer for 'close' layer")
            layer.type = "close"
          end
          -- TODO: optional fields
        end
        info:pop()
      end
    extra:pop()

    table.insert(layers, layer)
  end

  for i, layer in ipairs(layers) do
    layer.image = readImage(
      reader,
      layer.right - layer.left,
      layer.bottom - layer.top,
      #layer.channels
    )
  end

  reader:pop()
  return layers
end

local function readGlobalLayerMask(reader)
  reader = reader:push(reader:inkUint(4))
  -- TODO: stub
  reader:pop()
end

local function readLayerMaskInfo(reader)
  reader = reader:push(reader:inkUint(4))

  local layers = readLayers(reader)
  readGlobalLayerMask(reader)

  reader:pop()
  return layers
end

return {
  newPSD = function(file, structure)
    if type(file) == "string" then
      file = love.filesystem.newFileData(file)
    end

    assert(
      type(file) == "userdata" and file:type() == "FileData",
      ("file is not a valid filename or FileData: %s"):format(file)
    )

    local reader = BinaryReader.new(ffi.cast("uint8_t *", file:getPointer()), nil, file:getSize())

    local result = {}

    local width, height, channelCount = readHeader(reader)
    result.width, result.height = width, height
    readColorModeData(reader)
    readImageResources(reader)
    local layers = readLayerMaskInfo(reader)
    for i, layer in ipairs(layers) do
      result[i] = layer
    end
    result.composed = readImage(reader, width, height, channelCount)

    return result
  end,
}
