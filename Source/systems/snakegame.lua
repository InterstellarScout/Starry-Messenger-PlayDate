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
SnakeGame.MODE_STANDARD = "standard"
SnakeGame.MODE_COMPETITIVE = "competitive"

local CELL_SIZE <const> = 8
local MIN_SPEED <const> = 3
local MAX_SPEED <const> = 18
local START_LENGTH <const> = 10
local RIVAL_START_LENGTH <const> = 8
local BUMP_COOLDOWN_FRAMES <const> = 8
local COMPETITIVE_START_FOOD <const> = 2
local COMPETITIVE_MAX_FOOD <const> = 3
local FOOD_SPAWN_MIN_FRAMES <const> = 15
local FOOD_SPAWN_MAX_FRAMES <const> = 150

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

local function sign(value)
    if value < 0 then
        return -1
    elseif value > 0 then
        return 1
    end
    return 0
end

function SnakeGame.getModeLabel(modeId)
    if modeId == SnakeGame.MODE_COMPETITIVE then
        return "Competitive"
    end
    return "Standard"
end

function SnakeGame.new(width, height, options)
    options = options or {}
    local self = setmetatable({}, SnakeGame)
    self.width = width
    self.height = height
    self.modeId = options.modeId or SnakeGame.MODE_STANDARD
    self.cols = math.floor(width / CELL_SIZE)
    self.rows = math.floor(height / CELL_SIZE)
    self.angle = 0
    self.inputDirX = 0
    self.inputDirY = 0
    self.lastStepX = 1
    self.lastStepY = 0
    self.speed = 7
    self.stepTimer = 0
    self.score = 0
    self.rivalScore = 0
    self.bumpCooldown = 0
    self.statusMessage = nil
    self.statusFrames = 0
    self.foods = {}
    self.foodSpawnQueue = {}
    self.snake = {}
    self.rivalSnake = {}
    self:resetSnake()
    self:resetRivalSnake()
    self:resetFoods()
    return self
end

function SnakeGame:isCompetitive()
    return self.modeId == SnakeGame.MODE_COMPETITIVE
end

function SnakeGame:resetSnake()
    self.snake = {}
    local startX = math.floor(self.cols * 0.5)
    local startY = math.floor(self.rows * 0.5)
    self.lastStepX = 1
    self.lastStepY = 0
    self.angle = 0
    for index = 1, START_LENGTH do
        self.snake[index] = {
            x = wrap(startX - index + 1, self.cols),
            y = startY
        }
    end
end

function SnakeGame:resetRivalSnake()
    self.rivalSnake = {}
    if not self:isCompetitive() then
        return
    end

    local startX = math.floor(self.cols * 0.5)
    local startY = math.floor(self.rows * 0.28)
    for index = 1, RIVAL_START_LENGTH do
        self.rivalSnake[index] = {
            x = wrap(startX + index - 1, self.cols),
            y = startY
        }
    end
end

function SnakeGame:resetRound(message)
    self.stepTimer = 0
    self.bumpCooldown = 0
    self:resetSnake()
    self:resetRivalSnake()
    self:resetFoods()
    self.statusMessage = message
    self.statusFrames = 45
end

function SnakeGame:spawnFood()
    self.foods[#self.foods + 1] = {
        x = math.random(0, self.cols - 1),
        y = math.random(0, self.rows - 1)
    }
end

function SnakeGame:resetFoods()
    self.foods = {}
    self.foodSpawnQueue = {}
    local count = self:isCompetitive() and COMPETITIVE_START_FOOD or 1
    for _ = 1, count do
        self:spawnFood()
    end
end

function SnakeGame:getMaxFood()
    return self:isCompetitive() and COMPETITIVE_MAX_FOOD or 1
end

function SnakeGame:queueFoodSpawn()
    if not self:isCompetitive() then
        self:spawnFood()
        return
    end
    if (#self.foods + #self.foodSpawnQueue) >= self:getMaxFood() then
        return
    end
    self.foodSpawnQueue[#self.foodSpawnQueue + 1] = {
        frames = math.random(FOOD_SPAWN_MIN_FRAMES, FOOD_SPAWN_MAX_FRAMES)
    }
end

function SnakeGame:updateFoodSpawns()
    if not self:isCompetitive() then
        return
    end
    while (#self.foods + #self.foodSpawnQueue) < self:getMaxFood() do
        self:queueFoodSpawn()
    end
    for index = #self.foodSpawnQueue, 1, -1 do
        local queued = self.foodSpawnQueue[index]
        queued.frames = queued.frames - 1
        if queued.frames <= 0 and #self.foods < self:getMaxFood() then
            self:spawnFood()
            table.remove(self.foodSpawnQueue, index)
        end
    end
end

function SnakeGame:addFoodAt(x, y)
    if #self.foods >= self:getMaxFood() then
        return
    end
    self.foods[#self.foods + 1] = {
        x = wrap(x, self.cols),
        y = wrap(y, self.rows)
    }
end

function SnakeGame:getFoodAt(x, y)
    for index, food in ipairs(self.foods) do
        if food.x == x and food.y == y then
            return index, food
        end
    end
    return nil, nil
end

function SnakeGame:getNearestFood(head)
    local nearest = nil
    local nearestDistance = math.huge
    for _, food in ipairs(self.foods) do
        local dx = food.x - head.x
        local dy = food.y - head.y
        if math.abs(dx) > self.cols * 0.5 then
            dx = -sign(dx) * (self.cols - math.abs(dx))
        end
        if math.abs(dy) > self.rows * 0.5 then
            dy = -sign(dy) * (self.rows - math.abs(dy))
        end
        local distance = (dx * dx) + (dy * dy)
        if distance < nearestDistance then
            nearest = food
            nearestDistance = distance
        end
    end
    return nearest
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

function SnakeGame:handleDirectionalInput(leftHeld, rightHeld, upHeld, downHeld, leftPressed, rightPressed, upPressed, downPressed)
    local inputX = 0
    local inputY = 0
    if leftHeld then
        inputX = inputX - 1
    end
    if rightHeld then
        inputX = inputX + 1
    end
    if upHeld then
        inputY = inputY - 1
    end
    if downHeld then
        inputY = inputY + 1
    end

    self.inputDirX = inputX
    self.inputDirY = inputY

    if inputX ~= 0 or inputY ~= 0 then
        self.angle = math.deg(math.atan(inputY, inputX))
    end

    if self.bumpCooldown <= 0
        and ((leftPressed and self.lastStepX < 0)
            or (rightPressed and self.lastStepX > 0)
            or (upPressed and self.lastStepY < 0)
            or (downPressed and self.lastStepY > 0)) then
        self:advancePlayer(true)
        self.bumpCooldown = BUMP_COOLDOWN_FRAMES
    end
end

function SnakeGame:handlePrimaryAction()
    self.score = 0
    self.rivalScore = 0
    self:resetRound("Reset")
end

function SnakeGame:update()
    if self.bumpCooldown > 0 then
        self.bumpCooldown = self.bumpCooldown - 1
    end
    if self.statusFrames > 0 then
        self.statusFrames = self.statusFrames - 1
        if self.statusFrames <= 0 then
            self.statusMessage = nil
        end
    end
    self:updateFoodSpawns()

    self.stepTimer = self.stepTimer + self.speed
    while self.stepTimer >= 30 do
        self.stepTimer = self.stepTimer - 30
        self:advancePlayer(false)
        self:advanceRival()
        self:resolveSnakeCollision()
    end
end

function SnakeGame:getPlayerStep()
    if self.inputDirX ~= 0 or self.inputDirY ~= 0 then
        return self.inputDirX, self.inputDirY
    end

    local radians = math.rad(self.angle)
    local dx = math.cos(radians)
    local dy = math.sin(radians)
    local stepX = math.abs(dx) > 0.38 and sign(dx) or 0
    local stepY = math.abs(dy) > 0.38 and sign(dy) or 0
    if stepX == 0 and stepY == 0 then
        stepX = self.lastStepX ~= 0 and self.lastStepX or 1
        stepY = self.lastStepY or 0
    end
    return stepX, stepY
end

function SnakeGame:advanceBody(body, stepX, stepY, grow)
    local head = body[1]
    if head == nil then
        return nil
    end
    local nextHead = {
        x = wrap(head.x + stepX, self.cols),
        y = wrap(head.y + stepY, self.rows)
    }

    table.insert(body, 1, nextHead)
    if not grow then
        body[#body] = nil
    end
    return nextHead
end

function SnakeGame:advancePlayer(isBump)
    local head = self.snake[1]
    if head == nil then
        return
    end
    local stepX, stepY = self:getPlayerStep()
    self.lastStepX = stepX
    self.lastStepY = stepY
    local nextHead = {
        x = wrap(head.x + stepX, self.cols),
        y = wrap(head.y + stepY, self.rows)
    }
    local foodIndex = self:getFoodAt(nextHead.x, nextHead.y)
    local grow = foodIndex ~= nil
    self:advanceBody(self.snake, stepX, stepY, grow)
    if foodIndex ~= nil then
        self.score = self.score + 1
        table.remove(self.foods, foodIndex)
        self:queueFoodSpawn()
    elseif isBump then
        if self:isCompetitive() then
            self:addFoodAt(head.x, head.y)
        end
        self.statusMessage = "Bump"
        self.statusFrames = 12
    end

    if isBump then
        self:resolveSnakeCollision()
    end
end

function SnakeGame:getRivalStep()
    local head = self.rivalSnake[1]
    local food = head and self:getNearestFood(head) or nil
    if head == nil or food == nil then
        return -1, 0
    end

    local dx = food.x - head.x
    local dy = food.y - head.y
    if math.abs(dx) > self.cols * 0.5 then
        dx = -sign(dx) * (self.cols - math.abs(dx))
    end
    if math.abs(dy) > self.rows * 0.5 then
        dy = -sign(dy) * (self.rows - math.abs(dy))
    end
    return sign(dx), sign(dy)
end

function SnakeGame:advanceRival()
    if not self:isCompetitive() then
        return
    end

    local stepX, stepY = self:getRivalStep()
    if stepX == 0 and stepY == 0 then
        stepX = -1
    end
    local head = self.rivalSnake[1]
    if head == nil then
        return
    end
    local nextHead = {
        x = wrap(head.x + stepX, self.cols),
        y = wrap(head.y + stepY, self.rows)
    }
    local foodIndex = self:getFoodAt(nextHead.x, nextHead.y)
    local grow = foodIndex ~= nil
    self:advanceBody(self.rivalSnake, stepX, stepY, grow)
    if grow then
        self.rivalScore = self.rivalScore + 1
        table.remove(self.foods, foodIndex)
        self:queueFoodSpawn()
    end
end

function SnakeGame:bodyContains(body, x, y, startIndex)
    for index = startIndex or 1, #body do
        local cell = body[index]
        if cell.x == x and cell.y == y then
            return true
        end
    end
    return false
end

function SnakeGame:resolveSnakeCollision()
    if not self:isCompetitive() then
        return
    end

    local playerHead = self.snake[1]
    local rivalHead = self.rivalSnake[1]
    if playerHead == nil or rivalHead == nil then
        return
    end

    local playerHitRivalBody = self:bodyContains(self.rivalSnake, playerHead.x, playerHead.y, 2)
    local rivalHitPlayerBody = self:bodyContains(self.snake, rivalHead.x, rivalHead.y, 2)

    if playerHead.x == rivalHead.x and playerHead.y == rivalHead.y then
        self:resetRound("Head-on")
    elseif playerHitRivalBody then
        self.rivalScore = self.rivalScore + 1
        self:resetRound("Player loses")
    elseif rivalHitPlayerBody then
        self.score = self.score + 1
        self:resetRound("Rival loses")
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
    for _, food in ipairs(self.foods) do
        gfx.fillCircleAtPoint(
            roundToInt((food.x * CELL_SIZE) + (CELL_SIZE * 0.5)),
            roundToInt((food.y * CELL_SIZE) + (CELL_SIZE * 0.5)),
            3
        )
    end
    if self:isCompetitive() then
        for index = #self.rivalSnake, 1, -1 do
            local cell = self.rivalSnake[index]
            local x = cell.x * CELL_SIZE
            local y = cell.y * CELL_SIZE
            if index == 1 then
                gfx.drawRect(x, y, CELL_SIZE, CELL_SIZE)
                gfx.drawLine(x, y, x + CELL_SIZE, y + CELL_SIZE)
                gfx.drawLine(x + CELL_SIZE, y, x, y + CELL_SIZE)
            elseif index % 2 == 0 then
                gfx.drawRect(x + 1, y + 1, CELL_SIZE - 2, CELL_SIZE - 2)
            else
                gfx.fillRect(x + 3, y + 3, CELL_SIZE - 5, CELL_SIZE - 5)
            end
        end
    end
    for index = #self.snake, 1, -1 do
        self:drawCell(self.snake[index], index == 1)
    end
    if not UIState or UIState.isShown() then
        if self:isCompetitive() then
            gfx.drawText(string.format("Speed %d  You %d Rival %d", self.speed, self.score, self.rivalScore), 8, 8)
        else
            gfx.drawText(string.format("Speed %d  Score %d", self.speed, self.score), 8, 8)
        end
        if self.statusMessage ~= nil then
            gfx.drawTextAligned(self.statusMessage, self.width * 0.5, 24, kTextAlignment.center)
        end
    end
end
