--[[
Touching Grass field.

Purpose:
- lets the player move a hand through simple simulated grass blades
- bends nearby blades away from the hand and lets them settle back upright
]]
local gfx <const> = playdate.graphics

TouchingGrass = {}
TouchingGrass.__index = TouchingGrass

local BLADE_SPACING <const> = 10
local HAND_SPEED <const> = 3.4
local HAND_RADIUS <const> = 17
local REPEL_RADIUS <const> = 38
local LIFTED_RADIUS <const> = 2
local HAND_LIFT_SPEED <const> = 0.08
local HAND_CRANK_LIFT_STEP <const> = 0.008
local BLADE_UPDATES_PER_SECOND <const> = 40
local HAND_HIDE_DELAY_SECONDS <const> = 5
local HAND_HIDDEN_LIFT_THRESHOLD <const> = 0.97
local WIND_MIN_SECONDS <const> = 10
local WIND_MAX_SECONDS <const> = 20
local WIND_DURATION_SECONDS <const> = 4
local WIND_MIN_WIDTH <const> = 70
local WIND_MAX_WIDTH <const> = 145
local WIND_MIN_STRENGTH <const> = 0.32
local WIND_MAX_STRENGTH <const> = 0.72
local ACTIVE_LEAN_EPSILON <const> = 0.025
local ACTIVE_VELOCITY_EPSILON <const> = 0.015
local GRID_CELL_SIZE <const> = 32
local CACHE_REDRAW_PADDING <const> = 34
local LEAN_DIRTY_EPSILON <const> = 0.003

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function roundToInt(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

function TouchingGrass.new(width, height, options)
    options = options or {}
    local self = setmetatable({}, TouchingGrass)
    self.width = width
    self.height = height
    self.preview = options.preview == true
    self.handX = width * 0.5
    self.handY = height * 0.52
    self.handLift = 0
    self.handLiftTarget = 0
    self.phase = 0
    self.blades = {}
    self.gridCells = {}
    self.gridColumns = math.max(1, math.ceil(width / GRID_CELL_SIZE))
    self.gridRows = math.max(1, math.ceil(height / GRID_CELL_SIZE))
    self.activeBladeIndexes = {}
    self.updateCursor = 1
    self.bladeMoveBudget = 0
    self.handHidden = false
    self.outOfGrassFrames = 0
    self.wind = nil
    self.windFramesUntilNext = self:getRandomWindDelayFrames()
    self.grassImage = gfx.image.new(width, height, gfx.kColorBlack)
    self.dirtyMinX = nil
    self:seedGrass()
    return self
end

function TouchingGrass:setPreview(isPreview)
    self.preview = isPreview == true
end

function TouchingGrass:seedGrass()
    self.blades = {}
    self.gridCells = {}
    self.activeBladeIndexes = {}
    for index = 1, self.gridColumns * self.gridRows do
        self.gridCells[index] = {}
    end
    local index = 0
    for y = 34, self.height - 8, BLADE_SPACING do
        local rowOffset = ((math.floor(y / BLADE_SPACING) % 2) == 0) and 0 or (BLADE_SPACING * 0.5)
        for x = 8 + rowOffset, self.width - 8, BLADE_SPACING do
            index = index + 1
            self.blades[index] = {
                x = x + (math.random() * 3) - 1.5,
                y = y + (math.random() * 3) - 1.5,
                length = 12 + math.random() * 18,
                lean = 0,
                velocity = 0,
                active = false,
                index = index,
                seed = math.random() * math.pi * 2
            }
            self:addBladeToGrid(self.blades[index])
        end
    end
    self:markGrassCacheDirty()
end

function TouchingGrass:getCellColumn(x)
    return clamp(math.floor(x / GRID_CELL_SIZE) + 1, 1, self.gridColumns)
end

function TouchingGrass:getCellRow(y)
    return clamp(math.floor(y / GRID_CELL_SIZE) + 1, 1, self.gridRows)
end

function TouchingGrass:getCellIndex(column, row)
    return ((row - 1) * self.gridColumns) + column
end

function TouchingGrass:addBladeToGrid(blade)
    local column = self:getCellColumn(blade.x)
    local row = self:getCellRow(blade.y)
    blade.gridColumn = column
    blade.gridRow = row
    local cell = self.gridCells[self:getCellIndex(column, row)]
    cell[#cell + 1] = blade.index
end

function TouchingGrass:visitBladesInRect(x1, y1, x2, y2, callback)
    local minColumn = self:getCellColumn(x1)
    local maxColumn = self:getCellColumn(x2)
    local minRow = self:getCellRow(y1)
    local maxRow = self:getCellRow(y2)
    for row = minRow, maxRow do
        for column = minColumn, maxColumn do
            local cell = self.gridCells[self:getCellIndex(column, row)]
            for _, bladeIndex in ipairs(cell) do
                local blade = self.blades[bladeIndex]
                if blade ~= nil then
                    callback(blade)
                end
            end
        end
    end
end

function TouchingGrass:markDirtyRect(x1, y1, x2, y2)
    x1 = clamp(math.floor(x1), 0, self.width)
    y1 = clamp(math.floor(y1), 0, self.height)
    x2 = clamp(math.ceil(x2), 0, self.width)
    y2 = clamp(math.ceil(y2), 0, self.height)
    if x2 <= x1 or y2 <= y1 then
        return
    end

    self.dirtyMinX = self.dirtyMinX == nil and x1 or math.min(self.dirtyMinX, x1)
    self.dirtyMinY = self.dirtyMinY == nil and y1 or math.min(self.dirtyMinY, y1)
    self.dirtyMaxX = self.dirtyMaxX == nil and x2 or math.max(self.dirtyMaxX, x2)
    self.dirtyMaxY = self.dirtyMaxY == nil and y2 or math.max(self.dirtyMaxY, y2)
end

function TouchingGrass:markDirtyAroundBlade(blade)
    local reach = blade.length + (math.abs(blade.lean or 0) * blade.length * 0.72) + 3
    self:markDirtyRect(blade.x - reach, blade.y - blade.length - 3, blade.x + reach, blade.y + 3)
end

function TouchingGrass:markGrassCacheDirty()
    self:markDirtyRect(0, 0, self.width, self.height)
end

function TouchingGrass:getRefreshRate()
    if playdate.display and playdate.display.getRefreshRate then
        return math.max(1, playdate.display.getRefreshRate() or 30)
    end
    return 30
end

function TouchingGrass:getRandomWindDelayFrames()
    local seconds = WIND_MIN_SECONDS + (math.random() * (WIND_MAX_SECONDS - WIND_MIN_SECONDS))
    return math.floor(seconds * self:getRefreshRate() + 0.5)
end

function TouchingGrass:markPlayerInteraction()
    self.handHidden = false
    self.outOfGrassFrames = 0
end

function TouchingGrass:handleDirectionalInput(leftHeld, rightHeld, upHeld, downHeld)
    if self.preview then
        return
    end

    local dx = 0
    local dy = 0
    if leftHeld then
        dx = dx - HAND_SPEED
    end
    if rightHeld then
        dx = dx + HAND_SPEED
    end
    if upHeld then
        dy = dy - HAND_SPEED
    end
    if downHeld then
        dy = dy + HAND_SPEED
    end

    if dx ~= 0 or dy ~= 0 then
        self:markPlayerInteraction()
    end

    self.handX = clamp(self.handX + dx, HAND_RADIUS, self.width - HAND_RADIUS)
    self.handY = clamp(self.handY + dy, HAND_RADIUS, self.height - HAND_RADIUS)
end

function TouchingGrass:handlePrimaryAction()
    self:markPlayerInteraction()
    self.handLiftTarget = self.handLiftTarget < 0.5 and 1 or 0
end

function TouchingGrass:applyCrank(change)
    if self.preview or math.abs(change or 0) <= 0.01 then
        return
    end

    self:markPlayerInteraction()
    self.handLift = clamp((self.handLift or 0) + (change * HAND_CRANK_LIFT_STEP), 0, 1)
    self.handLiftTarget = self.handLift
end

function TouchingGrass:getEffectiveRepelRadius()
    return LIFTED_RADIUS + ((REPEL_RADIUS - LIFTED_RADIUS) * (1 - (self.handLift or 0)))
end

function TouchingGrass:updateBladeToward(blade, targetLean)
    local previousLean = blade.lean or 0
    self:markDirtyAroundBlade(blade)
    blade.velocity = ((blade.velocity or 0) + ((targetLean - (blade.lean or 0)) * 0.18)) * 0.72
    blade.lean = clamp((blade.lean or 0) + blade.velocity, -1.4, 1.4)
    blade.active = math.abs(blade.lean or 0) > ACTIVE_LEAN_EPSILON
        or math.abs(blade.velocity or 0) > ACTIVE_VELOCITY_EPSILON
    if math.abs((blade.lean or 0) - previousLean) > LEAN_DIRTY_EPSILON or not blade.active then
        self:markDirtyAroundBlade(blade)
    end
    if blade.active then
        self.activeBladeIndexes[blade.index] = true
    else
        self.activeBladeIndexes[blade.index] = nil
    end
end

function TouchingGrass:updateInteractedBlade(blade, dx, distance, radius)
    local push = (1 - (distance / radius)) * 1.45
    self:updateBladeToward(blade, (dx / distance) * push)
    blade.active = true
    blade.lastInteractedFrame = self.frame
    self.activeBladeIndexes[blade.index] = true
end

function TouchingGrass:getWindLean(blade)
    local wind = self.wind
    if wind == nil then
        return 0
    end

    local bandDistance = math.abs(blade.x - wind.centerX)
    if bandDistance > wind.width then
        return 0
    end

    local bandFalloff = 1 - (bandDistance / wind.width)
    local progress = wind.age / wind.duration
    local wave = math.sin(progress * math.pi)
    return wind.direction * wind.strength * bandFalloff * wave
end

function TouchingGrass:updateAmbientBlade(blade)
    local targetLean = math.sin(self.phase + blade.seed) * 0.08
    targetLean = targetLean + self:getWindLean(blade)
    self:updateBladeToward(blade, targetLean)
end

function TouchingGrass:updateBudgetedAmbientBlades()
    local bladeCount = #self.blades
    if bladeCount <= 0 then
        return
    end

    local refreshRate = self:getRefreshRate()

    self.bladeMoveBudget = math.min(
        BLADE_UPDATES_PER_SECOND,
        (self.bladeMoveBudget or 0) + (BLADE_UPDATES_PER_SECOND / refreshRate)
    )

    local moves = math.floor(self.bladeMoveBudget)
    self.bladeMoveBudget = self.bladeMoveBudget - moves

    for _ = 1, moves do
        local checked = 0
        while checked < bladeCount do
            local blade = self.blades[self.updateCursor]
            self.updateCursor = self.updateCursor + 1
            if self.updateCursor > bladeCount then
                self.updateCursor = 1
            end
            checked = checked + 1

            if blade ~= nil and blade.lastInteractedFrame ~= self.frame then
                self:updateAmbientBlade(blade)
                break
            end
        end
    end
end

function TouchingGrass:updateActiveBlades()
    for bladeIndex, _ in pairs(self.activeBladeIndexes) do
        local blade = self.blades[bladeIndex]
        if blade == nil then
            self.activeBladeIndexes[bladeIndex] = nil
        elseif blade.lastInteractedFrame ~= self.frame then
            self:updateAmbientBlade(blade)
        end
    end
end

function TouchingGrass:startWindWave()
    local travelDirection = math.random(0, 1) == 0 and -1 or 1
    local width = WIND_MIN_WIDTH + math.random() * (WIND_MAX_WIDTH - WIND_MIN_WIDTH)
    local startX = travelDirection > 0 and -width or (self.width + width)
    local endX = travelDirection > 0 and (self.width + width) or -width
    self.wind = {
        age = 0,
        duration = math.max(1, math.floor(WIND_DURATION_SECONDS * self:getRefreshRate() + 0.5)),
        centerX = startX,
        startX = startX,
        endX = endX,
        width = width,
        direction = travelDirection,
        strength = WIND_MIN_STRENGTH + math.random() * (WIND_MAX_STRENGTH - WIND_MIN_STRENGTH)
    }
end

function TouchingGrass:updateWind()
    if self.preview then
        return
    end

    if self.wind ~= nil then
        self.wind.age = self.wind.age + 1
        local progress = clamp(self.wind.age / self.wind.duration, 0, 1)
        self.wind.centerX = self.wind.startX + ((self.wind.endX - self.wind.startX) * progress)
        if self.wind.age >= self.wind.duration then
            self.wind = nil
            self.windFramesUntilNext = self:getRandomWindDelayFrames()
        end
        return
    end

    self.windFramesUntilNext = (self.windFramesUntilNext or self:getRandomWindDelayFrames()) - 1
    if self.windFramesUntilNext <= 0 then
        self:startWindWave()
    end
end

function TouchingGrass:updateHandVisibility()
    if self.preview then
        self.handHidden = false
        self.outOfGrassFrames = 0
        return
    end

    if (self.handLift or 0) >= HAND_HIDDEN_LIFT_THRESHOLD then
        self.outOfGrassFrames = (self.outOfGrassFrames or 0) + 1
        if self.outOfGrassFrames >= (HAND_HIDE_DELAY_SECONDS * self:getRefreshRate()) then
            self.handHidden = true
        end
    else
        self.outOfGrassFrames = 0
        self.handHidden = false
    end
end

function TouchingGrass:update()
    self.phase = self.phase + 0.045
    self.handLift = self.handLift + ((self.handLiftTarget - self.handLift) * HAND_LIFT_SPEED)
    self:updateWind()
    if self.preview then
        self.handX = (self.width * 0.5) + math.sin(self.phase * 0.7) * 92
        self.handY = (self.height * 0.52) + math.cos(self.phase * 0.9) * 38
        self.handLift = 0.15 + ((math.sin(self.phase * 0.6) + 1) * 0.22)
        self.handLiftTarget = self.handLift
    end

    local repelRadius = self:getEffectiveRepelRadius()
    local repelRadiusSquared = repelRadius * repelRadius
    if repelRadius > LIFTED_RADIUS then
        self:visitBladesInRect(
            self.handX - repelRadius,
            self.handY - repelRadius,
            self.handX + repelRadius,
            self.handY + repelRadius,
            function(blade)
                local dx = blade.x - self.handX
                local dy = blade.y - self.handY
                local distanceSquared = (dx * dx) + (dy * dy)
                if distanceSquared < repelRadiusSquared then
                    local distance = math.max(1, math.sqrt(distanceSquared))
                    self:updateInteractedBlade(blade, dx, distance, repelRadius)
                end
            end
        )
    end

    self:updateActiveBlades()
    self:updateBudgetedAmbientBlades()
    self:updateHandVisibility()
end

function TouchingGrass:drawBlade(blade)
    local baseX = blade.x
    local baseY = blade.y
    local tipX = baseX + ((blade.lean or 0) * blade.length * 0.72)
    local tipY = baseY - blade.length
    gfx.drawLine(roundToInt(baseX), roundToInt(baseY), roundToInt(tipX), roundToInt(tipY))
end

function TouchingGrass:flushGrassCache()
    if self.grassImage == nil then
        self.grassImage = gfx.image.new(self.width, self.height, gfx.kColorBlack)
        self:markGrassCacheDirty()
    end
    if self.dirtyMinX == nil then
        return
    end

    local x = self.dirtyMinX
    local y = self.dirtyMinY
    local width = self.dirtyMaxX - self.dirtyMinX
    local height = self.dirtyMaxY - self.dirtyMinY

    gfx.pushContext(self.grassImage)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(x, y, width, height)
    gfx.setColor(gfx.kColorWhite)
    self:visitBladesInRect(
        x - CACHE_REDRAW_PADDING,
        y - CACHE_REDRAW_PADDING,
        x + width + CACHE_REDRAW_PADDING,
        y + height + CACHE_REDRAW_PADDING,
        function(blade)
            self:drawBlade(blade)
        end
    )
    gfx.popContext()

    self.dirtyMinX = nil
    self.dirtyMinY = nil
    self.dirtyMaxX = nil
    self.dirtyMaxY = nil
end

function TouchingGrass:drawGrass()
    self:flushGrassCache()
    if self.grassImage ~= nil then
        self.grassImage:draw(0, 0)
        return
    end

    gfx.setColor(gfx.kColorWhite)
    for _, blade in ipairs(self.blades) do
        self:drawBlade(blade)
    end
end

function TouchingGrass:drawHand()
    if self.handHidden then
        return
    end

    local x = roundToInt(self.handX)
    local liftPixels = roundToInt((self.handLift or 0) * 14)
    local y = roundToInt(self.handY - liftPixels)
    gfx.fillCircleAtPoint(x, y, 9)
    gfx.drawCircleAtPoint(x, y, HAND_RADIUS)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(x + 3, y - 2, 2)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(x - 6, y + 8, x - 14, y + 18)
    gfx.drawLine(x - 1, y + 9, x - 4, y + 22)
    gfx.drawLine(x + 5, y + 8, x + 7, y + 20)
end

function TouchingGrass:draw()
    self:drawGrass()
    self:drawHand()
end
