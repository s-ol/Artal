require "setup"
path = select(1, ...)

image = artal.newPSD(path .. "test.psd")
for i, layer in ipairs(image) do
  if layer.image then
    compareData(
      love.image.newImageData(path .. "expected_" .. i .. ".png"),
      layer.image
    )
  end
end
