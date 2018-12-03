package.path = "../?.lua;" .. package.path
local artal = require "artal"

love.graphics.setDefaultFilter("nearest", "nearest")
local image = artal.newPSD("layer_uncompressed_data/test.psd")
for i, layer in ipairs(image) do
  if layer.image then
    layer.expected = love.graphics.newImage("layer_uncompressed_data/expected_" .. i .. ".png")
  end
end

return function ()
  love.graphics.setColor(255, 255, 255)
  love.graphics.print("actual", 10, 0)
  love.graphics.print("expected", image.width * 20 + 30, 0)
  love.graphics.translate(0, 20)

  for i, layer in ipairs(image) do
    love.graphics.print(i, 0, 5)
    if layer.image then
      love.graphics.draw(layer.image, 20, 0, 0, 20, 20)
    else
      love.graphics.print("<empty layer>", 20, 5)
    end

    love.graphics.translate(image.width * 20 + 20, 0)
    if layer.expected then
      love.graphics.draw(layer.expected, 20, 0, 0, 20, 20)
    else
      love.graphics.print("<empty layer>", 20, 5)
    end

    love.graphics.translate(0, image.height * 20 + 20)
  end
end
