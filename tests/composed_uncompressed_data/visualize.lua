package.path = "../?.lua;" .. package.path
local artal = require "artal"

local image = artal.newPSD("composed_uncompressed_data/test.psd")
local composed = love.graphics.newImage(image.composed)
local expected = love.graphics.newImage("composed_uncompressed_data/expected.png")

composed:setFilter("nearest")
expected:setFilter("nearest")

return function ()
  love.graphics.setColor(255, 255, 255)
  love.graphics.scale(20)
  love.graphics.draw(composed)
  love.graphics.draw(expected, image.width + 1)
end
