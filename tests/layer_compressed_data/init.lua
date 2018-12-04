path = ...
require "setup"

image = artal.newPSD(path .. "test.psd")
for i, layer in ipairs(image) do
  if layer.image then
    assert(
      compareData(
        love.image.newImageData(path .. "expected_" .. i .. ".png"),
        layer.image:getData()
      ),
      ("layer %i ('%s') doesn't match expected image"):format(i, layer.name)
    )
  end
end
