require "setup"

local info = artal.newPSD("cases/unicode_names.psd")

deepAssert({ name = "very long ☭ unicode name with extra characters wow is this long"}, info[1])
