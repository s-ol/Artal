package.path = "../?.lua;" .. package.path
local artal = require "artal"

local image = artal.newPSD("composed_compressed_data/test.psd")
local expected = love.graphics.newImage("composed_compressed_data/expected.png")

image.composed:setFilter("nearest")
expected:setFilter("nearest")

return function ()
  love.graphics.setColor(255, 255, 255)
  love.graphics.scale(20)
  love.graphics.draw(image.composed)
  love.graphics.draw(expected, image.width + 1)
end
