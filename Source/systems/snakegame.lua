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
local SAVE_KEY <const> = "snake_state"
local SAVE_COOLDOWN_FRAMES <const> = 60
local PLAYER_RESPAWN_FRAMES <const> = 150
local MENU_X <const> = 216
local MENU_Y <const> = 18
local MENU_WIDTH <const> = 168
local MENU_ROW_HEIGHT <const> = 20

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
    self.npcSnakes = {}
    self.npcEnabled = { false, false, false, false }
    self.npcScores = { 0, 0, 0, 0 }
    self.trimFat = false
    self.menuOpen = false
    self.menuIndex = 1
    self.menuInputCooldown = 0
    self.saveDirty = false
    self.saveCooldown = 0
    self.playerRespawnFrames = 0
    self.playerRespawnBlinkFrames = 0
    self:resetSnake()
    self:resetNpcSnakes()
    self:enforceModeNpcDefaults()
    self:resetFoods()
    self:loadState()
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

function SnakeGame:isCellOpenForPlayer(x, y)
    for _, food in ipairs(self.foods) do
        if food.x == x and food.y == y then
            return false
        end
    end
    for index = 1, 4 do
        if self.npcEnabled[index] then
            local body = self.npcSnakes[index]
            if body ~= nil and self:bodyContains(body, x, y, 1) then
                return false
            end
        end
    end
    return true
end

function SnakeGame:startPlayerRespawn(message)
    self.snake = {}
    self.playerRespawnFrames = PLAYER_RESPAWN_FRAMES
    self.playerRespawnBlinkFrames = PLAYER_RESPAWN_FRAMES
    self.statusMessage = message or "Respawning"
    self.statusFrames = PLAYER_RESPAWN_FRAMES
    self:markStateDirty()
end

function SnakeGame:tryRespawnPlayer()
    local centerX = math.floor(self.cols * 0.5)
    local centerY = math.floor(self.rows * 0.5)
    if not self:isCellOpenForPlayer(centerX, centerY) then
        self.playerRespawnFrames = 15
        return
    end
    self:resetSnake()
    self.playerRespawnFrames = 0
    self.playerRespawnBlinkFrames = 45
    self.statusMessage = "Back in"
    self.statusFrames = 35
    self:markStateDirty()
end

function SnakeGame:enforceModeNpcDefaults()
    if self:isCompetitive() then
        self.npcEnabled[1] = true
    end
end

function SnakeGame:resetNpcSnake(index)
    local startX = math.floor(self.cols * (0.2 + (index * 0.13)))
    local startY = math.floor(self.rows * (0.16 + (index * 0.13)))
    local body = {}
    for segment = 1, RIVAL_START_LENGTH do
        body[segment] = {
            x = wrap(startX + segment - 1, self.cols),
            y = wrap(startY, self.rows)
        }
    end
    self.npcSnakes[index] = body
end

function SnakeGame:resetNpcSnakes()
    for index = 1, 4 do
        self:resetNpcSnake(index)
    end
end

function SnakeGame:resetRound(message)
    self.stepTimer = 0
    self.bumpCooldown = 0
    self:resetSnake()
    self:resetNpcSnakes()
    self:enforceModeNpcDefaults()
    self:resetFoods()
    self.statusMessage = message
    self.statusFrames = 45
    self:markStateDirty()
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
    count = math.min(count, self:getMaxFood())
    for _ = 1, count do
        self:spawnFood()
    end
end

function SnakeGame:getMaxFood()
    local npcBonus = 0
    for _, enabled in ipairs(self.npcEnabled) do
        if enabled then
            npcBonus = npcBonus + 1
        end
    end
    local base = self:isCompetitive() and COMPETITIVE_MAX_FOOD or 1
    return base + npcBonus
end

function SnakeGame:queueFoodSpawn()
    if #self.foods >= self:getMaxFood() then
        return
    end
    if not self:isCompetitive() and self:getMaxFood() <= 1 then
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
    if not self:isCompetitive() and self:getMaxFood() <= 1 then
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

function SnakeGame:markStateDirty()
    self.saveDirty = true
    if self.saveCooldown <= 0 then
        self.saveCooldown = SAVE_COOLDOWN_FRAMES
    end
end

function SnakeGame:getSaveData()
    return {
        modeId = self.modeId,
        snake = self.snake,
        speed = self.speed,
        score = self.score,
        angle = self.angle,
        lastStepX = self.lastStepX,
        lastStepY = self.lastStepY,
        npcEnabled = self.npcEnabled,
        npcScores = self.npcScores,
        trimFat = self.trimFat
    }
end

function SnakeGame:saveState(force)
    if not force and not self.saveDirty then
        return
    end
    local ok, errorMessage = pcall(function()
        pd.datastore.write(self:getSaveData(), SAVE_KEY)
    end)
    if ok then
        self.saveDirty = false
        self.saveCooldown = 0
    else
        StarryLog.error("snake save failed: %s", tostring(errorMessage))
    end
end

function SnakeGame:loadState()
    local ok, data = pcall(function()
        return pd.datastore.read(SAVE_KEY)
    end)
    if not ok or type(data) ~= "table" then
        return
    end
    if type(data.snake) == "table" and #data.snake > 0 then
        self.snake = {}
        for index, cell in ipairs(data.snake) do
            if type(cell) == "table" and type(cell.x) == "number" and type(cell.y) == "number" then
                self.snake[index] = {
                    x = wrap(math.floor(cell.x), self.cols),
                    y = wrap(math.floor(cell.y), self.rows)
                }
            end
        end
        if #self.snake == 0 then
            self:resetSnake()
        end
    end
    self.speed = math.max(MIN_SPEED, math.min(MAX_SPEED, tonumber(data.speed) or self.speed))
    self.score = tonumber(data.score) or self.score
    self.angle = tonumber(data.angle) or self.angle
    self.lastStepX = tonumber(data.lastStepX) or self.lastStepX
    self.lastStepY = tonumber(data.lastStepY) or self.lastStepY
    if type(data.npcEnabled) == "table" then
        for index = 1, 4 do
            self.npcEnabled[index] = data.npcEnabled[index] == true
        end
    end
    if type(data.npcScores) == "table" then
        for index = 1, 4 do
            self.npcScores[index] = tonumber(data.npcScores[index]) or 0
        end
    end
    self:enforceModeNpcDefaults()
    self.trimFat = data.trimFat == true
    self:resetFoods()
end

function SnakeGame:shutdown()
    self:saveState(true)
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
    self.menuOpen = true
    self.menuInputCooldown = 1
end

function SnakeGame:isMenuOpen()
    return self.menuOpen == true
end

function SnakeGame:closeMenu()
    self.menuOpen = false
end

function SnakeGame:getMenuItems()
    local npc1Type = self:isCompetitive() and "locked" or "toggle"
    return {
        { id = "npc1", label = "NPC Snake 1", type = npc1Type, value = self.npcEnabled[1] },
        { id = "npc2", label = "NPC Snake 2", type = "toggle", value = self.npcEnabled[2] },
        { id = "npc3", label = "NPC Snake 3", type = "toggle", value = self.npcEnabled[3] },
        { id = "npc4", label = "NPC Snake 4", type = "toggle", value = self.npcEnabled[4] },
        { id = "reset", label = "Reset Size", type = "button" },
        { id = "trim", label = "Trim Fat", type = "toggle", value = self.trimFat }
    }
end

function SnakeGame:trimPlayerHalf()
    local targetLength = math.max(START_LENGTH, math.ceil(#self.snake * 0.5))
    while #self.snake > targetLength do
        self.snake[#self.snake] = nil
    end
    self.statusMessage = "Trimmed"
    self.statusFrames = 45
    self:markStateDirty()
end

function SnakeGame:resetPlayerSize()
    local head = self.snake[1]
    local stepX = self.lastStepX ~= 0 and self.lastStepX or 1
    local stepY = self.lastStepY or 0
    self.snake = {}
    local startX = head and head.x or math.floor(self.cols * 0.5)
    local startY = head and head.y or math.floor(self.rows * 0.5)
    for index = 1, START_LENGTH do
        self.snake[index] = {
            x = wrap(startX - (stepX * (index - 1)), self.cols),
            y = wrap(startY - (stepY * (index - 1)), self.rows)
        }
    end
    self.statusMessage = "Size reset"
    self.statusFrames = 45
    self:markStateDirty()
end

function SnakeGame:toggleMenuSelection()
    local item = self:getMenuItems()[self.menuIndex]
    if item == nil then
        return
    end
    if item.id == "reset" then
        self:resetPlayerSize()
    elseif item.id == "trim" then
        self.trimFat = not self.trimFat
        if self.trimFat then
            self:trimPlayerHalf()
        end
        self:markStateDirty()
    else
        local npcIndex = tonumber(string.sub(item.id, 4))
        if npcIndex ~= nil then
            if self:isCompetitive() and npcIndex == 1 then
                self.npcEnabled[1] = true
                self.statusMessage = "NPC Snake 1 locked on"
                self.statusFrames = 45
                return
            end
            self.npcEnabled[npcIndex] = not self.npcEnabled[npcIndex]
            if self.npcEnabled[npcIndex] and (self.npcSnakes[npcIndex] == nil or self.npcSnakes[npcIndex][1] == nil) then
                self:resetNpcSnake(npcIndex)
            end
            self:queueFoodSpawn()
            self:markStateDirty()
        end
    end
end

function SnakeGame:updateMenuInput(upPressed, downPressed, leftPressed, rightPressed, aPressed)
    if not self.menuOpen then
        return
    end
    if self.menuInputCooldown > 0 then
        self.menuInputCooldown = self.menuInputCooldown - 1
        return
    end
    local itemCount = #self:getMenuItems()
    if upPressed then
        self.menuIndex = self.menuIndex - 1
        if self.menuIndex < 1 then
            self.menuIndex = itemCount
        end
    elseif downPressed then
        self.menuIndex = self.menuIndex + 1
        if self.menuIndex > itemCount then
            self.menuIndex = 1
        end
    elseif leftPressed or rightPressed or aPressed then
        self:toggleMenuSelection()
    end
end

function SnakeGame:update()
    if self.menuOpen then
        if self.saveDirty then
            self:saveState(false)
        end
        return
    end
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
    if self.playerRespawnFrames > 0 then
        self.playerRespawnFrames = self.playerRespawnFrames - 1
        if self.playerRespawnFrames <= 0 then
            self:tryRespawnPlayer()
        end
    end
    if self.playerRespawnBlinkFrames > 0 then
        self.playerRespawnBlinkFrames = self.playerRespawnBlinkFrames - 1
    end

    self.stepTimer = self.stepTimer + self.speed
    while self.stepTimer >= 30 do
        self.stepTimer = self.stepTimer - 30
        if self.playerRespawnFrames <= 0 then
            self:advancePlayer(false)
        end
        self:advanceNpcSnakes()
        self:resolveSnakeCollision()
    end
    if self.saveDirty then
        self.saveCooldown = self.saveCooldown - 1
        if self.saveCooldown <= 0 then
            self:saveState(false)
        end
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
        self:markStateDirty()
    elseif isBump then
        if self:isCompetitive() then
            self:addFoodAt(head.x, head.y)
        end
        self.statusMessage = "Bump"
        self.statusFrames = 12
        self:markStateDirty()
    end

    if isBump then
        self:resolveSnakeCollision()
    end
    self:markStateDirty()
end

function SnakeGame:getNpcStep(body, index)
    local head = body and body[1]
    local food = head and self:getNearestFood(head) or nil
    if head == nil or food == nil then
        return index % 2 == 0 and 1 or -1, 0
    end

    local dx = food.x - head.x
    local dy = food.y - head.y
    if math.abs(dx) > self.cols * 0.5 then
        dx = -sign(dx) * (self.cols - math.abs(dx))
    end
    if math.abs(dy) > self.rows * 0.5 then
        dy = -sign(dy) * (self.rows - math.abs(dy))
    end
    if math.abs(dx) > math.abs(dy) then
        return sign(dx), 0
    end
    return 0, sign(dy)
end

function SnakeGame:advanceNpcSnakes()
    for index = 1, 4 do
        if self.npcEnabled[index] then
            local body = self.npcSnakes[index]
            local stepX, stepY = self:getNpcStep(body, index)
            if stepX == 0 and stepY == 0 then
                stepX = index % 2 == 0 and 1 or -1
            end
            local head = body and body[1]
            if head ~= nil then
                local nextHead = {
                    x = wrap(head.x + stepX, self.cols),
                    y = wrap(head.y + stepY, self.rows)
                }
                local foodIndex = self:getFoodAt(nextHead.x, nextHead.y)
                local grow = foodIndex ~= nil
                self:advanceBody(body, stepX, stepY, grow)
                if grow then
                    self.npcScores[index] = (self.npcScores[index] or 0) + 1
                    if index == 1 and self:isCompetitive() then
                        self.rivalScore = self.npcScores[index]
                    end
                    table.remove(self.foods, foodIndex)
                    self:queueFoodSpawn()
                    self:markStateDirty()
                end
            end
        end
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
    local playerHead = self.snake[1]
    self:enforceModeNpcDefaults()
    if playerHead == nil then
        return
    end

    for npcIndex = 1, 4 do
        if self.npcEnabled[npcIndex] then
            local rivalBody = self.npcSnakes[npcIndex]
            local rivalHead = rivalBody and rivalBody[1]
            if rivalHead ~= nil then
                local headOn = playerHead.x == rivalHead.x and playerHead.y == rivalHead.y
                local playerHitRivalBody = self:bodyContains(rivalBody, playerHead.x, playerHead.y, 2)
                local rivalHitPlayerBody = self:bodyContains(self.snake, rivalHead.x, rivalHead.y, 2)
                if headOn or playerHitRivalBody then
                    self.npcScores[npcIndex] = (self.npcScores[npcIndex] or 0) + 1
                    if npcIndex == 1 and self:isCompetitive() then
                        self.rivalScore = self.npcScores[npcIndex]
                    end
                    self:startPlayerRespawn(headOn and "Head-on" or "Player loses")
                    return
                elseif rivalHitPlayerBody then
                    self.score = self.score + 1
                    self.npcEnabled[npcIndex] = false
                    self.npcSnakes[npcIndex] = {}
                    self.statusMessage = string.format("NPC %d loses", npcIndex)
                    self.statusFrames = 45
                    self:markStateDirty()
                end
            end
        end
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

function SnakeGame:drawDirectionIndicator()
    local head = self.snake[1]
    if head == nil then
        return
    end
    local cx = roundToInt((head.x * CELL_SIZE) + (CELL_SIZE * 0.5))
    local cy = roundToInt((head.y * CELL_SIZE) + (CELL_SIZE * 0.5))
    local dx = self.lastStepX ~= 0 and self.lastStepX or 0
    local dy = self.lastStepY ~= 0 and self.lastStepY or 0
    if dx == 0 and dy == 0 then
        dx = 1
    end
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(cx, cy, cx + dx * 5, cy + dy * 5)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawCircleAtPoint(cx + dx * 5, cy + dy * 5, 1)
end

function SnakeGame:drawNpcSnake(body, npcIndex)
    for index = #body, 1, -1 do
        local cell = body[index]
        local x = cell.x * CELL_SIZE
        local y = cell.y * CELL_SIZE
        if index == 1 then
            gfx.drawRect(x, y, CELL_SIZE, CELL_SIZE)
            gfx.drawLine(x + CELL_SIZE * 0.5, y + 1, x + CELL_SIZE * 0.5, y + CELL_SIZE - 1)
        elseif (index + npcIndex) % 2 == 0 then
            gfx.drawRect(x + 1, y + 1, CELL_SIZE - 2, CELL_SIZE - 2)
        else
            gfx.fillRect(x + 3, y + 3, CELL_SIZE - 5, CELL_SIZE - 5)
        end
    end
end

function SnakeGame:drawMenu()
    if not self.menuOpen then
        return
    end
    local items = self:getMenuItems()
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(MENU_X, MENU_Y, MENU_WIDTH, 154, 6)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(MENU_X, MENU_Y, MENU_WIDTH, 154, 6)
    gfx.drawText("Snake Menu", MENU_X + 10, MENU_Y + 8)
    for index, item in ipairs(items) do
        local rowY = MENU_Y + 28 + ((index - 1) * MENU_ROW_HEIGHT)
        if index == self.menuIndex then
            gfx.fillRect(MENU_X + 6, rowY - 1, MENU_WIDTH - 12, MENU_ROW_HEIGHT)
            gfx.setImageDrawMode(gfx.kDrawModeInverted)
        end
        local valueText = ""
        if item.type == "toggle" or item.type == "locked" then
            valueText = item.value and "On" or "Off"
        end
        gfx.drawText(item.label, MENU_X + 12, rowY + 2)
        if valueText ~= "" then
            gfx.drawTextAligned(valueText, MENU_X + MENU_WIDTH - 12, rowY + 2, kTextAlignment.right)
        end
        if index == self.menuIndex then
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
        end
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
    self:enforceModeNpcDefaults()
    for index = 1, 4 do
        if self.npcEnabled[index] then
            self:drawNpcSnake(self.npcSnakes[index], index)
        end
    end
    for index = #self.snake, 1, -1 do
        self:drawCell(self.snake[index], index == 1)
    end
    self:drawDirectionIndicator()
    if self.playerRespawnFrames > 0 and math.floor((self.playerRespawnBlinkFrames or 0) / 8) % 2 == 0 then
        gfx.drawRect(
            math.floor(self.cols * 0.5) * CELL_SIZE + 1,
            math.floor(self.rows * 0.5) * CELL_SIZE + 1,
            CELL_SIZE - 2,
            CELL_SIZE - 2
        )
    end
    if not UIState or UIState.isShown() then
        if self:isCompetitive() then
            gfx.drawText(string.format("Speed %d  You %d NPC1 %d", self.speed, self.score, self.npcScores[1] or self.rivalScore), 8, 8)
        else
            gfx.drawText(string.format("Speed %d  Score %d  Food %d/%d", self.speed, self.score, #self.foods, self:getMaxFood()), 8, 8)
        end
        if self.statusMessage ~= nil then
            gfx.drawTextAligned(self.statusMessage, self.width * 0.5, 24, kTextAlignment.center)
        end
    end
    self:drawMenu()
end
