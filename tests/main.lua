local tests, visualization = {}
for i, test in ipairs(love.filesystem.getDirectoryItems("/")) do
  if love.filesystem.getInfo(test .. "/init.lua", "file") then
    local thread = love.thread.newThread(test .. "/init.lua")
    if i == 1 and thread then thread:start(test .. "/") end

    table.insert(
      tests,
      {
        name = test,
        thread = thread,
      }
    )
  end
end

local RUNNING, SUCCESS, FAILED = {1, 1, 0}, {0, 1, 0}, {1, 0, 0}

function love.draw()
  love.graphics.push()
  for i, test in ipairs(tests) do
    local color
    if test.thread:isRunning() then
      color = RUNNING
    else
      if not test.done then
        test.done = true
        if tests[i+1] then
          tests[i+1].thread:start(tests[i+1].name .. "/")
        end
      end

      if test.error then
        color = FAILED
      else
        color = SUCCESS
      end
    end
    love.graphics.setColor(color)
    love.graphics.circle("fill", 10, 10, 6)
    love.graphics.translate(20, 0)
  end
  love.graphics.pop()

  local hovered = tests[math.ceil(love.mouse.getX() / 20)]
  if hovered then
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(hovered.name, 10, 30)
    if hovered.error then
      love.graphics.printf(hovered.error, 10, 50, love.graphics.getWidth() - 20)
    end
  end

  love.graphics.translate(0, 50)
  if visualization then visualization() end
end

function love.keypressed(key)
  if key == "escape" then love.event.push "quit" end
end

function love.threaderror(thread, str)
  for i, test in ipairs(tests) do
    if test.thread == thread then
      len = test.name:len()
      print("┏╸ ERROR in " .. test.name .. ":")
      print("┠────────────" .. string.rep("─", len))
      print(str)
      print("┗━━━━━━━━━━━━" .. string.rep("━", len))
      test.error = str
      return
    end
  end

  error("couldn't match thread to a test: " .. tostring(thread))
end

function love.mousepressed(x, y)
  visualization = nil
  local selected = tests[math.ceil(x / 20)]
  if selected then
    local okay, mod = pcall(require, selected.name .. ".visualize")
    if okay then visualization = mod end
  end
end
