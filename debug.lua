DEBUG = true

function box(header)
  local n = "\n"
  local buffer = ""
  local content

  buffer = buffer .. "┏╸ " .. header .. n
  buffer = buffer .. "┠──" .. string.rep("─", header:len()) .. n

  local function line(...)
    local args = { ... }
    buffer = buffer .. "┠╴ " .. string.format(...) .. n

    content = true
  end

  local function done()
    if content then
      buffer = buffer ..  "┗━━" .. string.rep("━", header:len())
      print(buffer)
    end
  end

  return line, done
end
