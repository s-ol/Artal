require "setup"
path = select(1, ...)

assert(
  compareData(
    love.image.newImageData(path .. "expected.png"),
    artal.newPSD(path .. "test.psd").composed
  ),
  "composed Image doesn't match expected one"
)
