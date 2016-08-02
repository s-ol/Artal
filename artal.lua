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
local utf8 = require("utf8")

local _assert, _error = assert, error
local function assert(test, message)
  _assert(test, debug.traceback("Artal: " .. message, 2))
end
local function error(message)
  _error(debug.traceback("Artal: " .. message, 2))
end

local function bytes2word(first,second,third,forth) -- first is the direct hex -- Lack 8 length support
  local result = first

  if forth ~= nil then
    result = result + second * ( 0xff +1)
    result = result + third * ( 0xffff +1)
    result = result + forth * ( 0xffffff +1)
  elseif third ~= nil then
    result = result + second * ( 0xff +1)
    result = result + third * ( 0xffff +1)
  elseif second ~= nil then
    result = result + second * ( 0xff +1)
  end

  return result
end

local PSDReader = {}
function PSDReader.new(filePointer, start, length, parent)
  local self = setmetatable({}, { __index = PSDReader })

  self.filePointer = filePointer
  self.count = start or 0
  self.stop = length and self.count + length
  self.parent = parent

  return self
end

-- push a sub-reader that can optionally be limited by length
function PSDReader:push(length)
  if self.child then error("can't double-push") end
  self.child = PSDReader.new(self.filePointer, self.count, length, self)

  return self.child
end

-- stop using a sub-reader
-- if sub-reader is limited, skips parent past the limit
-- otherwise, skips to sub-readers parent last position
function PSDReader:pop()
  if not self.parent then error("not a child reader") end

  self.parent.count = self.stop or self.count

  self.parent.child = nil
end

function PSDReader:skip(length)
  self.count = self.count + length
end

function PSDReader:inkUint(length)
  length = length or 1

  assert(length == 1 or length == 2 or length == 4 ,"ink length must be a power of 2, no higher than 4")
  if self.stop then assert(self.stop >= self.count + length, "attempting to read out of bounds") end

  local first = self.filePointer[self.count]
  local second
  local third
  local forth

  if length == 2 then
    second = self.filePointer[self.count+1]
    first, second = second, first
  elseif length == 4 then
    second = self.filePointer[self.count+1]
    third = self.filePointer[self.count+2]
    forth = self.filePointer[self.count+3]
    first, second, third, forth = forth, third, second, first
  end

  self.count = self.count + length

  return bytes2word(first, second, third, forth)
end

function PSDReader:inkInt(length)
  local num = self:inkUint(length)

  if num >= 2^(length*8-1) then
    return num - 2^(length*8)
  end

  return num
end

function PSDReader:inkString(length, step)
  step = step or 1

  local res = ""
  for i = 1, length do
    word = self:inkUint(step)

    if word > 31 and word < 127 then
      res = res .. string.char(word)
    end
  end

  return res
end

local function readHeader(reader)
  local reader = reader:push(26)
  assert(reader:inkString(4) == "8BPS", ".psd magic wrong")
  assert(reader:inkUint(2) == 1, ".psd magic version wrong")

  reader:skip(6) -- reserved space

  local channels = reader:inkUint(2)
  local width, height = reader:inkUint(4), reader:inkUint(4)
  local depth = reader:inkUint(2)
  local colorMode = reader:inkUint(2)

  assert(depth == 8, "currently only 8-bit images are supported, depth was " .. depth)
  assert(colorMode == 3, "currently only RGB images are supported, colorModa was " .. colorMode)
  reader:pop()

  return width, height
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

    for i=1, channelCount do
      local id = reader:inkInt(2)
      local dataLength = reader:inkUint(4)

      assert(id >= -1 and id <= 2, "unsupported channel ID: " .. id)
    end

    assert(reader:inkString(4) == "8BIM", "BlendMode signature wrong")
    layer.blendMode = reader:inkString(4)
    layer.opacity = reader:inkUint(1)
    layer.clipping = reader:inkUint(1)
    layer.flags = reader:inkUint(1)
    reader:skip(1)

    local extra = reader:push(reader:inkUint(4))
      local maskAdjustment = extra:push(extra:inkUint(4))
      assert(
        maskAdjustment.count == maskAdjustment.stop,
        "expected layer mask/adjustment layer data to be empty, length was " .. maskAdjustment.stop - maskAdjustment.count
      )
      maskAdjustment:pop()

      local blendingRanges = extra:push(reader:inkUint(4))
      blendingRanges:pop()

      extra:skip(44)
      local nameLength = extra:inkUint(1)
      layer.name = extra:inkString(nameLength)
    extra:pop()


    table.insert(layers, layer)
  end

  reader:pop()
  return layers
end

local function readGlobalLayerMask(reader)
  reader = reader:push(reader:inkUint(4))
  -- TODO: stub
  reader:pop()
end

local function readAdditionalLayerData(reader)
end

local function readLayerMaskInfo(reader)
  reader = reader:push(reader:inkUint(4))

  local layers = readLayers(reader)
  readGlobalLayerMask(reader)
  readAdditionalLayerData(reader)

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
      "file is not a valid filename or FileData"
    )

    local reader = PSDReader.new(ffi.cast("uint8_t *", file:getPointer()), nil, file:getSize())

    local result = {}

    result.width, result.height = readHeader(reader)
    readColorModeData(reader)
    readImageResources(reader)
    local layers = readLayerMaskInfo(reader)

    return layers
  end,
}
