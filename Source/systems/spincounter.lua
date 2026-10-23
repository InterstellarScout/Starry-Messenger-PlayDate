-- Spin Counter: a crank-driven dice chooser and roller.
local pd <const> = playdate
local gfx <const> = pd.graphics

SpinCounter = {}
SpinCounter.__index = SpinCounter

local DICE <const> = { 20, 100, 1000, 12, 10, 8, 6, 4, 3, 2 }
local AMBIENT_DICE <const> = { 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 20, 50, 100, 1000 }
local CRANK_DETENT <const> = 12

local function wrap(index)
    while index < 1 do index = index + #DICE end
    while index > #DICE do index = index - #DICE end
    return index
end

function SpinCounter.new(width, height, options)
    local self = setmetatable({}, SpinCounter)
    self.width, self.height = width or 400, height or 240
    self.preview = options and options.preview == true
    self.selected, self.displayPosition, self.crankAccumulator = 1, 1, 0
    self.dieScreen = false
    self.rolling, self.rollVelocity, self.rollFrames = false, 0, 0
    self.stopRequested = false
    self.rollValue, self.rollTotal = 1, 0
    self.dieX, self.dieY = self.width * .5, self.height * .5
    self.dieVX, self.dieVY = 0, 0
    self.dieAngle = 0
    self.ambientDice = {}
    self.ambientValue = 20
    self.titleFont = gfx.font.new("/System/Fonts/Roobert-20-Medium")
    self.centerFont = gfx.font.new("/System/Fonts/Roobert-24-Medium")
    self.nearFont = self.titleFont
    self.farFont = gfx.getSystemFont()
    for _, sides in ipairs(AMBIENT_DICE) do
        local radius = math.random(10, 18)
        self.ambientDice[#self.ambientDice + 1] = {
            sides = sides,
            x = math.random(radius, self.width - radius),
            y = math.random(radius + 4, self.height - radius),
            vx = (math.random() < .5 and -1 or 1) * (0.35 + math.random() * 0.8),
            vy = (math.random() < .5 and -1 or 1) * (0.35 + math.random() * 0.8),
            radius = radius,
            angle = math.random() * math.pi * 2,
            spin = (math.random() - .5) * 0.1
        }
    end
    return self
end

function SpinCounter:setPreview(enabled) self.preview = enabled == true end

function SpinCounter:getSelectedSides() return DICE[self.selected] end

function SpinCounter:getWrappedOffset(index)
    local offset, half = index - self.displayPosition, #DICE * .5
    if offset > half then offset = offset - #DICE end
    if offset < -half then offset = offset + #DICE end
    return offset
end

function SpinCounter:changeSelection(direction)
    self.selected = wrap(self.selected + direction)
end

function SpinCounter:startRoll(impulse)
    self.rolling = true
    self.rollVelocity = math.max(.32, math.abs(impulse or 0) * .018)
    self.rollFrames = 0
    self.stopRequested = false
    self.rollValue = math.random(1, self:getSelectedSides())
    self.dieX, self.dieY = self.width * .5, self.height * .5
    local direction = math.random() * math.pi * 2
    local speed = 2.2 + math.random() * 1.8
    self.dieVX, self.dieVY = math.cos(direction) * speed, math.sin(direction) * speed
    self.dieAngle = math.random() * math.pi * 2
end

function SpinCounter:handlePrimaryAction()
    if not self.dieScreen then
        -- Lock the centered die into its dedicated roller before any roll.
        self.dieScreen = true
        self.rolling = false
        self.rollValue = self:getSelectedSides()
        return
    end
    if not self.rolling then
        self:startRoll(0)
    else
        -- The next generated value becomes the held result.
        self.stopRequested = true
    end
end

function SpinCounter:getShapeSegments(sides)
    if sides == 2 then return 0 end
    if sides <= 3 then return 3 end
    if sides <= 6 then return 4 end
    if sides <= 8 then return 8 end
    if sides <= 10 then return 5 end
    if sides <= 12 then return 6 end
    if sides <= 20 then return 8 end
    return 12
end

function SpinCounter:drawDieShape(sides, x, y, radius, angle)
    if sides == 2 then
        gfx.drawEllipseInRect(x - radius, y - radius * .62, radius * 2, radius * 1.24)
        return
    end
    local segments = self:getShapeSegments(sides)
    local previousX, previousY = nil, nil
    for index = 0, segments do
        local pointAngle = (angle or 0) - math.pi * .5 + ((index % segments) / segments) * math.pi * 2
        local pointX = x + math.cos(pointAngle) * radius
        local pointY = y + math.sin(pointAngle) * radius
        if previousX ~= nil then gfx.drawLine(previousX, previousY, pointX, pointY) end
        previousX, previousY = pointX, pointY
    end
end

function SpinCounter:updateAmbientDice()
    for _, die in ipairs(self.ambientDice) do
        die.x, die.y = die.x + die.vx, die.y + die.vy
        die.angle = die.angle + die.spin
        if die.x < die.radius or die.x > self.width - die.radius then
            die.x = math.max(die.radius, math.min(self.width - die.radius, die.x))
            die.vx = -die.vx
        end
        if die.y < die.radius or die.y > self.height - die.radius then
            die.y = math.max(die.radius, math.min(self.height - die.radius, die.y))
            die.vy = -die.vy
        end
    end
end

function SpinCounter:updateRollingDie()
    local radius = 34
    self.dieX, self.dieY = self.dieX + self.dieVX, self.dieY + self.dieVY
    self.dieAngle = self.dieAngle + ((self.dieVX + self.dieVY) * .055)
    if self.dieX < radius or self.dieX > self.width - radius then
        self.dieX = math.max(radius, math.min(self.width - radius, self.dieX))
        self.dieVX = -self.dieVX
    end
    if self.dieY < radius + 22 or self.dieY > self.height - radius - 18 then
        self.dieY = math.max(radius + 22, math.min(self.height - radius - 18, self.dieY))
        self.dieVY = -self.dieVY
    end
end

function SpinCounter:handleBack()
    if not self.dieScreen then return false end
    self.dieScreen = false
    self.rolling, self.rollVelocity = false, 0
    return true
end

function SpinCounter:handleDirectionalInput(left, right, up, down)
    if self.dieScreen then return end
    if up then self:changeSelection(-1) elseif down then self:changeSelection(1) end
end

function SpinCounter:applyCrank(change, acceleratedChange)
    if self.preview then return end
    if self.dieScreen then return end
    self.crankAccumulator = self.crankAccumulator + (change or 0)
    while self.crankAccumulator >= CRANK_DETENT do
        self:changeSelection(1)
        self.crankAccumulator = self.crankAccumulator - CRANK_DETENT
    end
    while self.crankAccumulator <= -CRANK_DETENT do
        self:changeSelection(-1)
        self.crankAccumulator = self.crankAccumulator + CRANK_DETENT
    end
end

function SpinCounter:update()
    self:updateAmbientDice()
    if not self.dieScreen and self.rollFrames % 5 == 0 then
        self.ambientValue = AMBIENT_DICE[math.random(1, #AMBIENT_DICE)]
    end
    if not self.dieScreen then
        local delta = self.selected - self.displayPosition
        if delta > (#DICE * .5) then delta = delta - #DICE end
        if delta < -(#DICE * .5) then delta = delta + #DICE end
        self.displayPosition = self.displayPosition + (delta * .25)
    end
    if not self.rolling then return end
    self.rollFrames = self.rollFrames + 1
    self:updateRollingDie()
    if self.rollFrames % 3 == 0 then
        self.rollValue = math.random(1, self:getSelectedSides())
    end
    if self.stopRequested and self.rollFrames > 1 then
        self.rolling = false
        self.rollValue = math.random(1, self:getSelectedSides())
        self.rollTotal = self.rollTotal + 1
    end
end

function SpinCounter:drawCentered(text, y, font)
    gfx.setFont(font or gfx.getSystemFont())
    gfx.drawTextAligned(text, self.width * .5, y, kTextAlignment.center)
end

function SpinCounter:drawDiePicker()
    for _, die in ipairs(self.ambientDice) do
        gfx.setColor(gfx.kColorWhite)
        self:drawDieShape(die.sides, die.x, die.y, die.radius, die.angle)
        gfx.setFont(self.farFont)
        gfx.drawTextAligned(tostring(die.sides), die.x, die.y - 5, kTextAlignment.center)
    end
    self:drawCentered("SPIN COUNTER", 12, self.titleFont)
    self:drawCentered(tostring(self.ambientValue), 39, self.centerFont)
    for index, sides in ipairs(DICE) do
        local offset = self:getWrappedOffset(index)
        local absoluteOffset = math.abs(offset)
        if absoluteOffset <= 2.15 then
            local y = 112 + (offset * 39)
            local font = absoluteOffset < .35 and self.centerFont
                or (absoluteOffset <= 1.15 and self.nearFont or self.farFont)
            self:drawCentered("D" .. sides, y, font)
            if absoluteOffset < .35 then
                gfx.drawLine(138, y + 29, 262, y + 29)
            end
        end
    end
    self:drawCentered("A: select die    B: Utilities", 213, self.farFont)
end

function SpinCounter:drawRollScreen()
    local sides = self:getSelectedSides()
    self:drawCentered("D" .. sides, 16, self.titleFont)
    if self.rolling then
        self:drawDieShape(sides, self.dieX, self.dieY, 34, self.dieAngle)
        gfx.setFont(self.centerFont)
        gfx.drawTextAligned(tostring(self.rollValue), self.dieX, self.dieY - 11, kTextAlignment.center)
        self:drawCentered("A: stop on next number", 205, self.nearFont)
    else
        -- A completed die fills 120% of the display height, capped to 90%
        -- of the width, while leaving the final bold number readable on top.
        local resultRadius = math.min(self.height * .6, self.width * .45)
        self:drawDieShape(sides, self.width * .5, self.height * .5, resultRadius, 0)
        self:drawCentered(tostring(self.rollValue), 103, self.centerFont)
        self:drawCentered("Result", 139, self.nearFont)
    end
    self:drawCentered("Rolls: " .. self.rollTotal, 151, self.farFont)
    if not self.rolling then self:drawCentered("A: roll again    B: dice", 213, self.farFont) end
end

function SpinCounter:draw()
    gfx.clear(gfx.kColorBlack)
    gfx.setColor(gfx.kColorWhite)
    if self.dieScreen then
        self:drawRollScreen()
        return
    end
    self:drawDiePicker()
end
