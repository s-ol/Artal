package.path = "../?.lua;" .. package.path
local artal = require "artal"

local image = artal.newPSD("layer_uncompressed_data/test.psd")
for i, layer in ipairs(image) do
  if layer.image then
    layer.image = love.graphics.newImage(layer.image)
    layer.expected = love.graphics.newImage("layer_uncompressed_data/expected_" .. i .. ".png")
  end
end

return function ()
  love.graphics.setColor(255, 255, 255)
  for i, layer in ipairs(image) do
    if layer.image then
      love.graphics.draw(layer.image)
      love.graphics.print("expected:", image.width + 20, 5)
      love.graphics.draw(layer.expected, image.width + 120, 0)
    else
      love.graphics.print("<empty layer>", 0, 5)
    end
    love.graphics.translate(0, image.height + 20)
  end
end
