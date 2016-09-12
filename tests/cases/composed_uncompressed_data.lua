require "setup"

compareData(
  love.image.newImageData("cases/basic_data.png"),
  artal.newPSD("cases/composed_uncompressed_data.psd").composed
)
