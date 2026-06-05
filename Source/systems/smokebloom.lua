--[[
Smoke Bloom line field.

Purpose:
- creates expanding flower-like clouds of line wisps from a movable center cursor
- uses cheap pairwise repulsion among nearby wisps to suggest bumping/disturbance
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

SmokeBloom = {}
SmokeBloom.__index = SmokeBloom

local TAU <const> = math.pi * 2
local WISP_COUNT <const> = 72
local CENTER_SPEED <const> = 2.2

local function roundToInt(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function SmokeBloom.new(width, height)
    local self = setmetatable({}, SmokeBloom)
    self.width = width
    self.height = height
    self.centerX = width * 0.5
    self.centerY = height * 0.5
    self.phase = 0
    self.spin = 0.018
    self.wisps = {}
    for index = 1, WISP_COUNT do
        self:resetWisp(index, true)
    end
    return self
end

function SmokeBloom:resetWisp(index, randomizeRadius)
    local symmetryIndex = (index - 1) % 12
    local ringIndex = math.floor((index - 1) / 12)
    self.wisps[index] = {
        angle = (symmetryIndex / 12) * TAU,
        radius = randomizeRadius and (math.random() * 104) or 2,
        speed = 0.65 + (ringIndex * 0.12) + (math.random() * 0.7),
        length = 8 + (math.random() * 28),
        bend = -0.18 + (math.random() * 0.36),
        push = 0
    }
end

function SmokeBloom:applyCrank(change)
    if math.abs(change or 0) > 0.01 then
        self.spin = clamp(self.spin + (change * 0.0008), -0.08, 0.08)
    end
end

function SmokeBloom:handlePrimaryAction()
    for index = 1, WISP_COUNT do
        self:resetWisp(index, false)
    end
end

function SmokeBloom:handleDirectionalInput(leftHeld, rightHeld, upHeld, downHeld)
    local dx = 0
    local dy = 0
    if leftHeld then
        dx = dx - CENTER_SPEED
    end
    if rightHeld then
        dx = dx + CENTER_SPEED
    end
    if upHeld then
        dy = dy - CENTER_SPEED
    end
    if downHeld then
        dy = dy + CENTER_SPEED
    end
    self.centerX = clamp(self.centerX + dx, 24, self.width - 24)
    self.centerY = clamp(self.centerY + dy, 24, self.height - 24)
end

function SmokeBloom:update()
    self.phase = self.phase + self.spin
    for index, wisp in ipairs(self.wisps) do
        wisp.radius = wisp.radius + wisp.speed
        wisp.angle = wisp.angle + self.spin + (wisp.bend * 0.01) + (wisp.push * 0.006)
        wisp.push = wisp.push * 0.88
        if wisp.radius > 148 then
            self:resetWisp(index, false)
        end
    end

    for index = 1, WISP_COUNT - 1 do
        local a = self.wisps[index]
        for otherIndex = index + 1, math.min(WISP_COUNT, index + 8) do
            local b = self.wisps[otherIndex]
            local radiusDelta = math.abs(a.radius - b.radius)
            local angleDelta = math.abs(a.angle - b.angle)
            if radiusDelta < 10 and angleDelta < 0.2 then
                local push = (10 - radiusDelta) * 0.015
                a.push = a.push - push
                b.push = b.push + push
            end
        end
    end
end

function SmokeBloom:draw()
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, self.width, self.height)
    gfx.setColor(gfx.kColorWhite)
    for _, wisp in ipairs(self.wisps) do
        local angle = wisp.angle + self.phase
        local x = self.centerX + (math.cos(angle) * wisp.radius)
        local y = self.centerY + (math.sin(angle) * wisp.radius)
        local tangent = angle + (math.pi * 0.5) + (wisp.bend * math.sin(self.phase + wisp.radius * 0.04))
        local half = wisp.length * 0.5
        gfx.drawLine(
            roundToInt(x - (math.cos(tangent) * half)),
            roundToInt(y - (math.sin(tangent) * half)),
            roundToInt(x + (math.cos(tangent) * half)),
            roundToInt(y + (math.sin(tangent) * half))
        )
    end
    gfx.fillCircleAtPoint(roundToInt(self.centerX), roundToInt(self.centerY), 3)
end
