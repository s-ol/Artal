require "setup"
path = select(1, ...)

local info = artal.newPSD(path .. "test.psd")

deepAssert({ name = "very long ☭ unicode name with extra characters wow is this long"}, info[1])
