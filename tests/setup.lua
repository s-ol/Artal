package.path = "../../?/init.lua;../../?.lua;" .. package.path

require "love.image"
require "love.filesystem"
require "love.thread"
require "artal.debug"
artal = require "artal"

local ffi = require "ffi"
ffi.cdef [[
  int memcmp(const void *s1, const void *s2, size_t n);
]]

love.graphics = love.graphics or {}
function love.graphics.newImage(imagedata)
  return {
    getData = function () return imagedata end
  }
end

function compareData(a, b)
  if not a:getSize() == b:getSize() then return false end
  return 0 == ffi.C.memcmp(
    a:getPointer(),
    b:getPointer(),
    math.min(a:getSize(), b:getSize())
  )
end

function deepAssert(shape, table, path)
  path = path or ""

  for key, expected in pairs(shape) do
    local actual = table[key]
    if type(expected) ~= type(actual) then
      error(
        string.format(
          "type mismatch at '%s': expected %s but got '%s'",
          path .. "." .. key,
          type(expected),
          type(actual)
        )
      )
    elseif type(expected) == "userdata" and expected.type then
      assert(
        actual.type and expected:type() == actual:type(),
        string.format(
          "type mismatch at '%s': expected %s but got '%s'",
          path .. "." .. key,
          expected:type(),
          actual.type and actual:type() or type(actual)
        )
      )
    end

    local compare = function (a, b) return a == b end
    if type(expected) == "table" then
      compare = deepAssert
    elseif type(expected) == "userdata" then
      if expected.type and (expected:type() == "ImageData" or expected:type() == "FileData") then
        compare = compareData
      end
    end

    assert(
      compare(expected, actual, path .. "." .. key),
      string.format(
        "value mismatch at '%s': expected %s '%s' but got %s '%s'",
        path .. "." .. key,
        type(expected), expected,
        type(actual), actual
      )
    )
  end

  return true
end
