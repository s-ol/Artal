require "setup"

compareData(
  love.image.newImageData("cases/basic_data.png"),
  artal.newPSD("cases/basic_data.psd")[1].image:getData()
)
