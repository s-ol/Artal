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

local function bytes2word(first, second, third, fourth)
  local result = first

  if forth ~= nil then
    result = result + second * (1 + 0xff)
    result = result + third  * (1 + 0xffff)
    result = result + fourth * (1 + 0xffffff)
  elseif third ~= nil then
    result = result + second * (1 + 0xff)
    result = result + third  * (1 + 0xffff)
  elseif second ~= nil then
    result = result + second * (1 + 0xff)
  end

  return result
end

local BinaryReader = {}

function BinaryReader:flush()
  if self.debug then self.debug.done() end
  if self.parent then self.parent:flush() end
end

function BinaryReader:assert(test, message)
  if not test then
    self:error(message, 3)
  end
  return test
end

function BinaryReader:error(message, level)
  self:flush()
  error(debug.traceback(tostring(self) .. ": " .. message, level or 2))
end

function BinaryReader:log(...)
  if self.debug then
    self.debug.log(...)
  end
end

function BinaryReader:getName()
  local name = self.name or "?"
  if self.parent then
    name = self.parent:getName() .. "/" .. name
  end

  return name
end

local meta = {
  __index = BinaryReader,
  __tostring = function(self)
    return "BinaryReader<" .. self:getName() .. ">@" .. tostring(self.count) .. "/" .. tostring(self.stop)
  end
}

function BinaryReader.new(filePointer, start, parent, length, name)
  local self = setmetatable({}, meta)

  self.filePointer = filePointer
  self.count = start or 0
  self.stop = length and self.count + length
  self.parent = parent
  self.name = name

  if self.stop and self.parent and self.parent.stop then
    assert(self.stop <= self.parent.stop, "can't push() length longer than parent has left: "
      .. tostring(self.parent) .. " and "
      .. tostring(self)
    )
  end

  if DEBUG and self.name then
    local log, done = box(tostring(self))
    self.debug = {
      log = log,
      done = done,
    }
  end

  return self
end

-- push a sub-reader that can optionally be limited by length
function BinaryReader:push(...)
  if self.child then self:error("can't push() while a child is already active") end
  self.child = BinaryReader.new(self.filePointer, self.count, self, ...)

  return self.child
end

-- stop using a sub-reader
-- if sub-reader is limited, skips parent past the limit
-- otherwise, skips to sub-readers parent last position
function BinaryReader:pop()
  if not self.parent then self:error("cannot pop() root reader") end

  if self.stop and self.stop < self.count then
    self:error("stepped past self.stop")
  end

  if self.stop and self.stop ~= self.count then
    print("WARN: " .. tostring(self) .. " pop()ed before reaching self.stop")
  end

  if self.debug then self.debug.done() end
  self.parent.count = self.stop or self.count

  self.parent.child = nil
end

function BinaryReader:skip(length)
  self.count = self.count + length
end

function BinaryReader:stub()
  self.count = self.stop
end

function BinaryReader:padTo(width)
  self:skip(-(self.count % -width))
end

function BinaryReader:inkUint(length)
  length = length or 1

  self:assert(length == 1 or length == 2 or length == 4, "ink length must be a power of 2, no higher than 4")
  self:assert(not self.child, "attempting to read while child reader active")
  if self.stop then self:assert(self.stop >= self.count + length, "attempting to read out of bounds") end

  local first = self.filePointer[self.count]
  local second
  local third
  local fourth

  if length == 2 then
    second = self.filePointer[self.count+1]
    first, second = second, first
  elseif length == 4 then
    second = self.filePointer[self.count+1]
    third = self.filePointer[self.count+2]
    fourth = self.filePointer[self.count+3]
    first, second, third, fourth = fourth, third, second, first
  end

  self.count = self.count + length

  return bytes2word(first, second, third, fourth)
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
