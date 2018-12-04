path = ...
require "setup"

assert(
  compareData(
    love.image.newImageData(path .. "expected.png"),
    artal.newPSD(path .. "test.psd").composed:getData()
  ),
  "composed Image doesn't match expected one"
)
