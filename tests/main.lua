package.path = "../../?/init.lua;../../?.lua;" .. package.path
require "artal.debug"

local RUNNING, SUCCESS, FAILED = {1, 1, 0}, {0, 1, 0}, {1, 0, 0}

local tests, visualization = {}
local function add_test(test)
  local thread = love.thread.newThread(test .. "/init.lua")

  table.insert(
    tests,
    {
      name = test,
      thread = thread,
    }
  )
end

local function start_test(test)
  print()
  print("=== STARTING: " .. test.name .. " ===")
  test.thread:start(test.name .. "/")
  test.started = true
end

local function finish_test(test, i)
  test.color = SUCCESS

  if test.error then
    test.color = FAILED

    line, done = box("result: ERROR")
    line(test.error)
    done()
  end

  local next_test = tests[i+1]
  if next_test then start_test(next_test) end
end

if #arg > 1 then
  for i=2,#arg do
    add_test(arg[i])
  end
else
  for _, test in ipairs(love.filesystem.getDirectoryItems("/")) do
    if love.filesystem.getInfo(test .. "/init.lua", "file") then
      add_test(test)
    end
  end
end

start_test(tests[1])

local time = 0
function love.update(dt)
  time = time + dt

  local b = math.sin(time / 4) * 0.1 + 0.1
  love.graphics.setBackgroundColor(b, b, b)

  for i, test in ipairs(tests) do
    if test.started and not test.color and not test.thread:isRunning() then
      finish_test(test, i)
    end
  end
end

function love.draw()
  love.graphics.push()
  for i, test in ipairs(tests) do
    local color = test.color or RUNNING
    love.graphics.setColor(color)
    love.graphics.circle("fill", 10, 10, 6)
    love.graphics.translate(20, 0)
  end
  love.graphics.pop()

  local hovered = tests[math.ceil(love.mouse.getX() / 20)]
  if hovered then
    love.graphics.setColor(1, 1, 1)
    local w = love.graphics.getWidth() / 2 - 20
    local x = love.graphics.getWidth() / 2 + 10
    love.graphics.print(hovered.name, x, 30)
    if hovered.error then
      love.graphics.printf(hovered.error, x, 50, w)
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
      test.error = str
      finish_test(test, i)
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
