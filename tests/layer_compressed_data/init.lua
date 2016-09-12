require "setup"
path = select(1, ...)

image = artal.newPSD(path .. "test.psd")
for i, layer in ipairs(image) do
  if layer.image then
    assert(
      compareData(
        love.image.newImageData(path .. "expected_" .. i .. ".png"),
        layer.image
      ),
      ("layer %i ('%s') doesn't match expected image"):format(i, layer.name)
    )
  end
end
