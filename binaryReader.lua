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

local BinaryReader = {}
function BinaryReader.new(filePointer, start, length, parent)
  local self = setmetatable({}, { __index = BinaryReader })

  self.filePointer = filePointer
  self.count = start or 0
  self.stop = length and self.count + length
  self.parent = parent

  return self
end

-- push a sub-reader that can optionally be limited by length
function BinaryReader:push(length)
  if self.child then error("can't double-push") end
  self.child = BinaryReader.new(self.filePointer, self.count, length, self)

  return self.child
end

-- stop using a sub-reader
-- if sub-reader is limited, skips parent past the limit
-- otherwise, skips to sub-readers parent last position
function BinaryReader:pop()
  if not self.parent then error("not a child reader") end

  self.parent.count = self.stop or self.count

  self.parent.child = nil
end

function BinaryReader:skip(length)
  self.count = self.count + length
end

function BinaryReader:padTo(width)
  self:skip(-(self.count % -width))
end

function BinaryReader:inkUint(length)
  length = length or 1

  assert(length == 1 or length == 2 or length == 4, "ink length must be a power of 2, no higher than 4")
  assert(not self.child, "attempting to read while child reader active")
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

function BinaryReader:inkInt(length)
  local num = self:inkUint(length)

  if num >= 2^(length*8-1) then
    return num - 2^(length*8)
  end

  return num
end

function BinaryReader:inkString(length, step)
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

function BinaryReader:inkUnicodeString()
  local charCount = self:inkUint(4)

  local res = ""
  while utf8.len(res) < charCount do
    res = res .. utf8.char(self:inkUint(2))
  end

  return res
end

return BinaryReader
