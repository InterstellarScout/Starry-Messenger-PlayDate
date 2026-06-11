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
SmokeBloom.MODE_BILLOWING = "billowing"
SmokeBloom.MODE_RAISING = "raising"

local TAU <const> = math.pi * 2
local WISP_COUNT <const> = 72
local CENTER_SPEED <const> = 2.2
local RAISING_BOTTOM_WISP_COUNT <const> = 48

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

function SmokeBloom.getModeLabel(modeId)
    if modeId == SmokeBloom.MODE_RAISING then
        return "Raising Smoke"
    end
    return "Billowing Smoke"
end

function SmokeBloom.new(width, height, options)
    options = options or {}
    local self = setmetatable({}, SmokeBloom)
    self.width = width
    self.height = height
    self.modeId = options.modeId or SmokeBloom.MODE_BILLOWING
    self.preview = options.preview == true
    self.centerX = width * 0.5
    self.centerY = height * 0.5
    self.bottomSourceX = math.random(28, width - 28)
    self.bottomSourceY = height - 4
    self.phase = 0
    self.spin = 0.018
    self.riseBoost = 1
    self.wisps = {}
    for index = 1, WISP_COUNT do
        self:resetWisp(index, true)
    end
    return self
end

function SmokeBloom:resetWisp(index, randomizeRadius)
    if self.modeId == SmokeBloom.MODE_RAISING then
        local fromPlayer = index > RAISING_BOTTOM_WISP_COUNT
        local sourceX = fromPlayer and self.centerX or self.bottomSourceX
        local sourceY = fromPlayer and self.centerY or self.bottomSourceY
        local spread = randomizeRadius and math.random() * 36 or math.random() * 6
        local angle = (-math.pi * 0.5) + ((math.random() - 0.5) * (fromPlayer and 0.8 or 0.48))
        self.wisps[index] = {
            x = sourceX + ((math.random() - 0.5) * 10),
            y = sourceY - spread,
            vx = math.cos(angle) * (0.2 + math.random() * 0.6),
            vy = math.sin(angle) * (0.5 + math.random() * 1.2),
            age = randomizeRadius and math.random(0, 80) or 0,
            life = 70 + math.random(0, 70),
            length = 7 + (math.random() * 26),
            bend = -0.2 + (math.random() * 0.4),
            fromPlayer = fromPlayer,
            push = 0
        }
        return
    end

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
        if self.modeId == SmokeBloom.MODE_RAISING then
            self.riseBoost = clamp((self.riseBoost or 1) + (math.abs(change) * 0.012), 1, 5.8)
        else
            self.spin = clamp(self.spin + (change * 0.0008), -0.08, 0.08)
        end
    end
end

function SmokeBloom:handlePrimaryAction()
    if self.modeId == SmokeBloom.MODE_RAISING then
        self.bottomSourceX = math.random(28, self.width - 28)
    end
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
    if self.modeId == SmokeBloom.MODE_RAISING then
        self.riseBoost = 1 + (((self.riseBoost or 1) - 1) * 0.94)
        for index, wisp in ipairs(self.wisps) do
            wisp.age = (wisp.age or 0) + 1
            local sway = math.sin(self.phase + index * 0.37 + wisp.age * 0.05) * 0.22
            wisp.x = wisp.x + (wisp.vx or 0) + sway + ((wisp.push or 0) * 0.02)
            wisp.y = wisp.y + ((wisp.vy or -1) * (self.riseBoost or 1))
            wisp.vx = (wisp.vx or 0) * 0.988
            wisp.vy = (wisp.vy or -1) - 0.006
            wisp.push = (wisp.push or 0) * 0.86
            if wisp.age > wisp.life or wisp.y < -20 or wisp.x < -24 or wisp.x > self.width + 24 then
                self:resetWisp(index, false)
            end
        end
        return
    end

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
        local angle = (wisp.angle or -math.pi * 0.5) + self.phase
        local x = wisp.x or (self.centerX + (math.cos(angle) * wisp.radius))
        local y = wisp.y or (self.centerY + (math.sin(angle) * wisp.radius))
        local tangent = angle + (math.pi * 0.5) + (wisp.bend * math.sin(self.phase + (wisp.radius or wisp.age or 0) * 0.04))
        local half = wisp.length * 0.5
        gfx.drawLine(
            roundToInt(x - (math.cos(tangent) * half)),
            roundToInt(y - (math.sin(tangent) * half)),
            roundToInt(x + (math.cos(tangent) * half)),
            roundToInt(y + (math.sin(tangent) * half))
        )
    end
    gfx.fillCircleAtPoint(roundToInt(self.centerX), roundToInt(self.centerY), 3)
    if self.modeId == SmokeBloom.MODE_RAISING then
        gfx.drawLine(roundToInt(self.bottomSourceX - 7), self.height - 4, roundToInt(self.bottomSourceX + 7), self.height - 4)
    end
end
