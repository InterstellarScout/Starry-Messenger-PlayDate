--[[
Snake mini-game.

Purpose:
- crank-steered snake loop with forgiving tail overlap and screen wrapping
- keeps the game low-risk on device by using a fixed cell grid and simple drawing
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

SnakeGame = {}
SnakeGame.__index = SnakeGame

local CELL_SIZE <const> = 8
local MIN_SPEED <const> = 3
local MAX_SPEED <const> = 18
local START_LENGTH <const> = 10

local function roundToInt(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function wrap(value, limit)
    while value < 0 do
        value = value + limit
    end
    while value >= limit do
        value = value - limit
    end
    return value
end

function SnakeGame.new(width, height)
    local self = setmetatable({}, SnakeGame)
    self.width = width
    self.height = height
    self.cols = math.floor(width / CELL_SIZE)
    self.rows = math.floor(height / CELL_SIZE)
    self.angle = 0
    self.speed = 7
    self.stepTimer = 0
    self.score = 0
    self.snake = {}
    self:resetSnake()
    self:spawnFood()
    return self
end

function SnakeGame:resetSnake()
    self.snake = {}
    local startX = math.floor(self.cols * 0.5)
    local startY = math.floor(self.rows * 0.5)
    for index = 1, START_LENGTH do
        self.snake[index] = {
            x = wrap(startX - index + 1, self.cols),
            y = startY
        }
    end
end

function SnakeGame:spawnFood()
    self.food = {
        x = math.random(0, self.cols - 1),
        y = math.random(0, self.rows - 1)
    }
end

function SnakeGame:applyCrank(change)
    if math.abs(change or 0) <= 0.01 then
        return
    end
    self.angle = (self.angle + (change * 1.35)) % 360
end

function SnakeGame:stepSpeed(direction)
    if direction == 0 then
        return
    end
    self.speed = math.max(MIN_SPEED, math.min(MAX_SPEED, self.speed + direction))
end

function SnakeGame:handleDirectionalInput(_left, _right, upPressed, downPressed)
    if upPressed then
        self:stepSpeed(1)
    elseif downPressed then
        self:stepSpeed(-1)
    end
end

function SnakeGame:handlePrimaryAction()
    self.score = 0
    self:resetSnake()
    self:spawnFood()
end

function SnakeGame:update()
    self.stepTimer = self.stepTimer + self.speed
    while self.stepTimer >= 30 do
        self.stepTimer = self.stepTimer - 30
        self:advance()
    end
end

function SnakeGame:advance()
    local head = self.snake[1]
    local radians = math.rad(self.angle)
    local dx = math.cos(radians)
    local dy = math.sin(radians)
    local stepX = math.abs(dx) >= math.abs(dy) and (dx >= 0 and 1 or -1) or 0
    local stepY = stepX == 0 and (dy >= 0 and 1 or -1) or 0
    local nextHead = {
        x = wrap(head.x + stepX, self.cols),
        y = wrap(head.y + stepY, self.rows)
    }

    table.insert(self.snake, 1, nextHead)
    if self.food and nextHead.x == self.food.x and nextHead.y == self.food.y then
        self.score = self.score + 1
        self:spawnFood()
    else
        self.snake[#self.snake] = nil
    end
end

function SnakeGame:drawCell(cell, filled)
    local x = cell.x * CELL_SIZE
    local y = cell.y * CELL_SIZE
    if filled then
        gfx.fillRect(x + 1, y + 1, CELL_SIZE - 2, CELL_SIZE - 2)
    else
        gfx.drawRect(x + 1, y + 1, CELL_SIZE - 2, CELL_SIZE - 2)
    end
end

function SnakeGame:draw()
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, self.width, self.height)
    gfx.setColor(gfx.kColorWhite)
    if self.food then
        gfx.fillCircleAtPoint(
            roundToInt((self.food.x * CELL_SIZE) + (CELL_SIZE * 0.5)),
            roundToInt((self.food.y * CELL_SIZE) + (CELL_SIZE * 0.5)),
            3
        )
    end
    for index = #self.snake, 1, -1 do
        self:drawCell(self.snake[index], index == 1)
    end
    gfx.drawText(string.format("Speed %d  Score %d", self.speed, self.score), 8, 8)
end
