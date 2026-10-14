-- Spin Counter: a crank-driven dice chooser and roller.
local pd <const> = playdate
local gfx <const> = pd.graphics

SpinCounter = {}
SpinCounter.__index = SpinCounter

local DICE <const> = { 20, 100, 1000, 12, 10, 8, 6, 4, 3, 2 }
local CRANK_DETENT <const> = 20

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
    self.rolling, self.rollVelocity, self.rollFrames = false, 0, 0
    self.rollValue, self.rollTotal = 1, 0
    self.titleFont = gfx.font.new("/System/Fonts/Roobert-20-Medium")
    self.resultFont = gfx.font.new("/System/Fonts/Roobert-24-Medium")
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
end

function SpinCounter:handlePrimaryAction()
    self.rollValue = math.random(1, self:getSelectedSides())
    self:startRoll(0)
end

function SpinCounter:handleBack()
    if not self.rolling then return false end
    self.rolling, self.rollVelocity = false, 0
    return true
end

function SpinCounter:handleDirectionalInput(left, right, up, down)
    if self.rolling then return end
    if up then self:changeSelection(-1) elseif down then self:changeSelection(1) end
end

function SpinCounter:applyCrank(change, acceleratedChange)
    if self.preview then return end
    if self.rolling then
        if math.abs(acceleratedChange or 0) > .01 then
            self.rollVelocity = math.min(2.8, self.rollVelocity + math.abs(acceleratedChange) * .018)
        end
        return
    end
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
    self.displayPosition = self.displayPosition + ((self.selected - self.displayPosition) * .25)
    if not self.rolling then return end
    self.rollVelocity = self.rollVelocity * .94
    self.rollFrames = self.rollFrames + 1
    if self.rollFrames % math.max(1, math.floor(5 - (self.rollVelocity * 1.5))) == 0 then
        self.rollValue = math.random(1, self:getSelectedSides())
    end
    if self.rollFrames > 20 and self.rollVelocity < .08 then
        self.rolling = false
        self.rollValue = math.random(1, self:getSelectedSides())
        self.rollTotal = self.rollTotal + 1
    end
end

function SpinCounter:drawCentered(text, y, font)
    gfx.setFont(font or gfx.getSystemFont())
    gfx.drawTextAligned(text, self.width * .5, y, kTextAlignment.center)
end

function SpinCounter:draw()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    if self.rolling then
        self:drawCentered("D" .. self:getSelectedSides(), 18, self.titleFont)
        self:drawCentered(tostring(self.rollValue), 70, self.resultFont)
        self:drawCentered("Spin the crank to keep rolling", 128)
        self:drawCentered("Rolls: " .. self.rollTotal, 151)
        self:drawCentered("A: roll again    B: dice menu", 213)
        return
    end

    self:drawCentered("SPIN COUNTER", 14, self.titleFont)
    self:drawCentered("Crank or Up/Down to choose a die", 45)
    for index, sides in ipairs(DICE) do
        local offset = self:getWrappedOffset(index)
        if math.abs(offset) <= 2.2 then
            local y = 128 + (offset * 42)
            gfx.setFont(offset == 0 and self.titleFont or gfx.getSystemFont())
            gfx.drawTextAligned("D" .. sides, self.width * .5, y, kTextAlignment.center)
            if math.abs(offset) < .35 then gfx.drawRect(154, y - 4, 92, 31) end
        end
    end
    self:drawCentered("A: spin counter    B: title", 213)
end
