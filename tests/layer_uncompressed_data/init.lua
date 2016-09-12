require "setup"
path = select(1, ...)

compareData(
  love.image.newImageData(path .. "expected.png"),
  artal.newPSD(path .. "test.psd")[1].image
)
