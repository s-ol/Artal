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

local path = (...):gsub("%.init$", "")

local ffi = require("ffi")
local BinaryReader = require(path .. ".binaryReader")

-- read one `pixels` pixels from `reader` into
-- data[offset + i * stride]
local function readChannelRaw(reader, pixels, data, offset, stride)
  for i = 0, pixels - 1 do
    data[offset + i * stride] = reader.filePointer[reader.count]
    reader:skip(1)
  end
end

-- uncompress all the RLE-compressed data in `reader` into
-- data[offset + i * stride] and return the uncompressed length
local function readRLE(reader, data, offset, stride)
  local i = 0
  while reader:hasData() do
    local head = reader:inkInt(1)
    if head >= 0 then
      for _=1, 1 + head do
        local value = reader:inkUint(1)
        data[offset + i * stride] = value
        i = i + 1
      end
    elseif head > -128 then
      local value = reader:inkUint(1)
      for _=1, 1 - head do
        data[offset + i * stride] = value
        i = i + 1
      end
    end
  end

  return i
end

-- read one 'Channel Image Data' into data[offset + i * stride]
-- according to its compression mode.
-- `channel` needs keys .width, .height, .length
local function readChannel(reader, channel, data, offset, stride, name)
  reader = reader:push(channel.length, name or "channel")

  local compression = reader:inkUint(2)

  if compression == 0 then
    local pixels = channel.width * channel.height
    local chan = reader:push(pixels, "uncomp")
    readChannelRaw(chan, pixels, data, offset, stride)
    chan:pop()
  elseif compression == 1 then
    local lineLengths = {}
    for l=1,channel.height do
      lineLengths[l] = reader:inkUint(2)
    end

    local lineOffset = 0
    for l, length in ipairs(lineLengths) do
      local line = reader:push(length, "L" .. l)
      readRLE(line, data, lineOffset + offset, stride)
      lineOffset = lineOffset + channel.width * 4
      line:pop()
    end
  else
    reader:error("unknown compression mode " .. compression)
  end

  reader:pop()
end

local offsetTable = {
  [0] = 0, -- red
  [1] = 1, -- green
  [2] = 2, -- blue
  [-1] = 3, -- alpha
}

-- read all 'Channel Image Data' for `layer` and compose
-- into a love2d Image instance
-- `layer` needs keys .width, .height, .channels (see readChannel)
local function readImage(reader, layer, name)
  reader = reader:push(nil, name or "image")

  if layer.width == 0 or layer.height == 0 then
    reader:skip(2 * #layer.channels) -- skip compression flags
    reader:pop()
    return nil
  end

  local imageData = love.image.newImageData(layer.width, layer.height)
  local data = ffi.cast("uint8_t *", imageData:getPointer())

  for i, channel in ipairs(layer.channels) do
    local channelOffset = offsetTable[channel.id]
    if not channelOffset then
      error("unsupported channelId: " .. channel.id)
    end

    readChannel(reader, channel, data, channelOffset, 4, "C" .. i)
  end

  reader:pop()
  return love.graphics.newImage(imageData)
end

-- read PSD file header
-- returns width, height, channelCount
local function readHeader(reader)
  local reader = reader:push(26, "header")

  assert(reader:inkString(4) == "8BPS", ".psd magic wrong")
  assert(reader:inkUint(2) == 1, ".psd magic version wrong")

  reader:skip(6) -- reserved space

  local channelCount = reader:inkUint(2)
  local height, width = reader:inkUint(4), reader:inkUint(4)
  local depth = reader:inkUint(2)
  local colorMode = reader:inkUint(2)

  reader:log("channelCount: " .. channelCount)
  reader:log("width, height: " .. width .. ", " .. height)
  reader:log("depth: " .. depth)
  reader:log("colorMode: " .. colorMode)

  assert(depth == 8, "currently only 8-bit images are supported, depth was " .. depth)
  assert(colorMode == 3, "currently only RGB images are supported, colorMode was " .. colorMode)
  reader:pop()

  return width, height, channelCount
end

local function readColorModeData(reader)
  local length = reader:inkUint(4)
  local reader = reader:push(length, "colorModeData")

  reader:log("length: " .. length)

  assert(length == 0, "expected color mode data to be empty, length was " .. length)

  reader:pop()
end

local function readImageResources(reader)
  reader = reader:push(reader:inkUint(4), "imageResources")
  -- TODO: stub
  reader:stub()
  reader:pop()
end

-- read a 'Layer Record' into a table with
-- .top, .bottom, .left, .right, .width, .height,
-- .channels, .blendMode, .opacity, .clipping, .flags,
-- .type, .name
local function readLayerRecord(layers, reader, id)
  reader = reader:push(nil, "layerRecord_" .. id)

  local layer = {}
  layer.top, layer.left = reader:inkUint(4), reader:inkUint(4)
  layer.bottom, layer.right = reader:inkUint(4), reader:inkUint(4)
  layer.width = layer.right - layer.left
  layer.height = layer.bottom - layer.top

  local channelCount = reader:inkUint(2)
  assert(channelCount == 3 or channelCount == 4, "only 3 or 4 channels supported per layer, channelCount was " .. channelCount)

  layer.channels = {}
  for i=1, channelCount do
    local id = reader:inkInt(2)
    local dataLength = reader:inkUint(4)

    assert(id >= -1 and id <= 2, "unsupported channel ID: " .. id)

    table.insert(layer.channels, {
      id = id,
      length = dataLength,
      width = layer.width,
      height = layer.height,
    })
  end

  assert(reader:inkString(4) == "8BIM", "BlendMode signature wrong")
  layer.blendMode = reader:inkString(4)
  layer.opacity = reader:inkUint(1)
  layer.clipping = reader:inkUint(1)
  layer.flags = reader:inkUint(1)
  reader:skip(1)

  do
    local extra = reader:push(reader:inkUint(4), "extra")
    local maskAdjustment = extra:push(extra:inkUint(4), "maskAdjustment")
    -- TODO: stub
    maskAdjustment:stub()
    maskAdjustment:pop()

    local blendingRanges = extra:push(extra:inkUint(4), "blendingRanges")
    -- TODO: stub
    blendingRanges:stub()
    blendingRanges:pop()

    local nameLength = extra:inkUint(1)
    layer.name = extra:inkString(nameLength)
    nameLength = nameLength + 1
    if nameLength % 4 > 0 then
      extra:skip(4 - (nameLength % 4))
    end

    while extra:hasData() do
      assert(extra:inkString(4) == "8BIM", "extra info signature wrong")
      local key = extra:inkString(4)
      local info = extra:push(extra:inkUint(4), "info:" .. key)
      if key == "luni" then -- unicode layer name
        layer.name = info:inkUnicodeString()
        extra:log("unicode name = '%s'", layer.name)
        if layer.other then layer.other.name = layer.name end
        info:stub()
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
      else
        extra:log("unknown additional layer info: %s", key)
        info:stub()
      end
      info:pop()
    end
    extra:pop()
  end

  reader:pop()
  return layer
end

-- read 'Layer Info' structure and return list of layers
local function readLayers(reader)
  reader = reader:push(reader:inkUint(4), "layerInfo")
  local layerCount = reader:inkInt(2)
  local globalAlpha = layerCount < 1
  layerCount = math.abs(layerCount)

  local layers = {}
  for i=1, layerCount do
    table.insert(layers, readLayerRecord(layers, reader, i))
  end

  for i, layer in ipairs(layers) do
    layer.image = readImage(
      reader,
      layer,
      "L" .. i .. "_image"
    )
  end

  reader:pop()
  return layers
end

local function readGlobalLayerMask(reader)
  reader = reader:push(reader:inkUint(4), "globalLayerMask")
  -- TODO: stub
  reader:stub()
  reader:pop()
end

local function readLayerMaskInfo(reader)
  reader = reader:push(reader:inkUint(4), "layerMaskInfo")

  local layers = readLayers(reader)

  if reader:hasData() then
    readGlobalLayerMask(reader)
  end

  reader:stub()

  reader:pop()
  return layers
end

-- read composed image into love2d Image instance
local function readComposed(reader, width, height, channelCount)
  reader = reader:push(nil, "composed")
  local imageData = love.image.newImageData(width, height)
  local data = ffi.cast("uint8_t *", imageData:getPointer())

  local compression = reader:inkUint(2)
  reader:log("compression = %d", compression)
  reader:log("width, height = %d, %d", width, height)
  reader:log("channels = %d", channelCount)
  if compression == 0 then
    for i=0, channelCount-1 do
      local chan = reader:push(nil, "C" .. i)
      readChannelRaw(chan, width * height, data, i, 4)
      chan:pop()
    end
  elseif compression == 1 then
    local lineLengths, totalLength = {}, 0
    for l=1,height * channelCount do
      local length = reader:inkUint(2)
      lineLengths[l] = length
      totalLength = totalLength + length
    end

    local i = 1
    local rle = reader:push(totalLength, "RLEdata")
    for c=0, channelCount - 1 do
      local lineOffset = 0
      for l=0, height - 1 do
        local line = rle:push(lineLengths[i], "L" .. l)
        assert(readRLE(line, data, lineOffset + c, 4) == width)
        lineOffset = lineOffset + width * 4
        line:pop()
      end
    end
    rle:pop()
  else
    chan:error("unknown compression: " .. compression)
  end

  -- fill in alpha
  if channelCount < 4 then
    for i=0, width*height - 1 do
      data[i * 4 + 3] = 255
    end
  end

  reader:pop()
  return love.graphics.newImage(imageData)
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

    local reader = BinaryReader.new(ffi.cast("uint8_t *", file:getPointer()), nil, nil, file:getSize(), '')

    local result = {}

    local width, height, channelCount = readHeader(reader)
    result.width, result.height = width, height
    readColorModeData(reader)
    readImageResources(reader)
    local layers = readLayerMaskInfo(reader)
    for i, layer in ipairs(layers) do
      result[i] = layer
    end

    if reader:hasData() then
      result.composed = readComposed(reader, width, height, channelCount)
    end

    return result
  end,
}
