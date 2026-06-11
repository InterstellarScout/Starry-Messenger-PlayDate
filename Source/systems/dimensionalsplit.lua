--[[
Dimensional Split view.

Purpose:
- fills the screen with independently blinking black/white cells
- lets the crank move from one full-screen box down toward pixel-sized cells
- regenerates cell colors and blink timing whenever A is pressed
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

DimensionalSplit = {}
DimensionalSplit.__index = DimensionalSplit

local MIN_BLINK_FRAMES <const> = 3
local MAX_BLINK_FRAMES <const> = 150
local CRANK_STEP_THRESHOLD <const> = 18

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function randomBlinkFrames()
    return math.random(MIN_BLINK_FRAMES, MAX_BLINK_FRAMES)
end

function DimensionalSplit.getModeLabel(_modeId)
    return "Dimensional Split"
end

function DimensionalSplit.new(width, height, options)
    local self = setmetatable({}, DimensionalSplit)
    options = options or {}
    self.width = width
    self.height = height
    self.preview = options.preview == true
    self.maxCellSize = math.max(width, height)
    self.cellSize = self.preview and 40 or 32
    self.crankAccumulator = 0
    self.frame = 0
    self.columns = 0
    self.rows = 0
    self.cellCount = 0
    self.cellWhite = {}
    self.cellTimers = {}
    self:regenerateGrid()
    return self
end

function DimensionalSplit:setPreview(isPreview)
    self.preview = isPreview == true
end

function DimensionalSplit:getCellSize()
    return self.cellSize
end

function DimensionalSplit:getGridCount()
    return math.max(self.columns, self.rows)
end

function DimensionalSplit:allocateCellArrays(count)
    for index = 1, count do
        self.cellWhite[index] = math.random() > 0.5
        self.cellTimers[index] = randomBlinkFrames()
    end

    for index = count + 1, #self.cellWhite do
        self.cellWhite[index] = nil
        self.cellTimers[index] = nil
    end
end

function DimensionalSplit:regenerateGrid()
    self.columns = math.max(1, math.ceil(self.width / self.cellSize))
    self.rows = math.max(1, math.ceil(self.height / self.cellSize))
    self.cellCount = self.columns * self.rows
    self:allocateCellArrays(self.cellCount)
end

function DimensionalSplit:handlePrimaryAction()
    self:regenerateGrid()
end

function DimensionalSplit:getCellSizeStep(direction)
    local size = self.cellSize
    local magnitude = 1
    if size >= 96 then
        magnitude = 24
    elseif size >= 48 then
        magnitude = 12
    elseif size >= 24 then
        magnitude = 6
    elseif size >= 12 then
        magnitude = 3
    elseif size >= 4 then
        magnitude = 2
    end

    if direction > 0 then
        return magnitude
    end
    return math.max(1, magnitude)
end

function DimensionalSplit:applySubdivisionStep(direction)
    local stepSize = self:getCellSizeStep(direction)
    local nextCellSize = clamp(self.cellSize - (direction * stepSize), 1, self.maxCellSize)
    if nextCellSize == self.cellSize then
        return false
    end

    self.cellSize = nextCellSize
    self:regenerateGrid()
    return true
end

function DimensionalSplit:applyCrank(change)
    if math.abs(change) < 0.01 then
        return
    end

    self.crankAccumulator = self.crankAccumulator + change
    while math.abs(self.crankAccumulator) >= CRANK_STEP_THRESHOLD do
        local direction = self.crankAccumulator > 0 and 1 or -1
        local changed = self:applySubdivisionStep(direction)
        self.crankAccumulator = self.crankAccumulator - (CRANK_STEP_THRESHOLD * direction)
        if not changed then
            self.crankAccumulator = 0
            break
        end
    end
end

function DimensionalSplit:update()
    self.frame = self.frame + 1
    for index = 1, self.cellCount do
        local nextTimer = (self.cellTimers[index] or 1) - 1
        if nextTimer <= 0 then
            self.cellWhite[index] = not self.cellWhite[index]
            self.cellTimers[index] = randomBlinkFrames()
        else
            self.cellTimers[index] = nextTimer
        end
    end
end

function DimensionalSplit:draw()
    gfx.clear(gfx.kColorBlack)
    local index = 1
    for row = 1, self.rows do
        local y = math.floor((row - 1) * self.cellSize)
        local bottom = math.floor(math.min(self.height, row * self.cellSize))
        local cellHeight = math.max(1, bottom - y)
        for column = 1, self.columns do
            local x = math.floor((column - 1) * self.cellSize)
            local right = math.floor(math.min(self.width, column * self.cellSize))
            local cellWidth = math.max(1, right - x)
            gfx.setColor(self.cellWhite[index] and gfx.kColorWhite or gfx.kColorBlack)
            gfx.fillRect(x, y, cellWidth, cellHeight)
            index = index + 1
        end
    end
end
