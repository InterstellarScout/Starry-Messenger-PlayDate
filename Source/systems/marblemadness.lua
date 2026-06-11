import "gameconfig"

--[[
Marble Madness particle toy.

Purpose:
- ports the local Processing MarbleMadness example into a Playdate-friendly view
- keeps mixed-size marble spawning, collision response, chaos bursts, and gravity wells
- maps mouse/hotkey interactions to D-pad, crank, and A-button controls
]]
local pd <const> = playdate
local gfx <const> = pd.graphics
local MARBLE_CONFIG <const> = GameConfig and GameConfig.marbleMadness or {}

MarbleMadness = {}
MarbleMadness.__index = MarbleMadness

local SMALL_COUNT <const> = MARBLE_CONFIG.smallCount or 34
local MEDIUM_COUNT <const> = MARBLE_CONFIG.mediumCount or 8
local LARGE_COUNT <const> = MARBLE_CONFIG.largeCount or 4
local SMALL_DIAMETER <const> = MARBLE_CONFIG.smallDiameter or 10
local MEDIUM_DIAMETER <const> = MARBLE_CONFIG.mediumDiameter or 18
local LARGE_DIAMETER <const> = MARBLE_CONFIG.largeDiameter or 28
local RESTITUTION <const> = 1 + ((MARBLE_CONFIG.bounce or 0) * 0.1)
local FRICTION <const> = MARBLE_CONFIG.zeroG and 1.0 or (MARBLE_CONFIG.friction or 0.99)
local START_WITH_ENERGY <const> = MARBLE_CONFIG.startWithEnergy ~= false
local CHAOS_MODE <const> = MARBLE_CONFIG.behaviorMode == "chaos"
local CURSOR_SPEED <const> = MARBLE_CONFIG.cursorSpeed or 3.2
local GRAVITY_MIN <const> = MARBLE_CONFIG.gravityMin or 1200
local GRAVITY_MAX <const> = MARBLE_CONFIG.gravityMax or 9000
local GRAVITY_STEP <const> = MARBLE_CONFIG.gravityCrankStep or 18
local GRAVITY_DEFAULT <const> = MARBLE_CONFIG.gravityStrength or 5000
local BURST_MIN <const> = MARBLE_CONFIG.burstVelocityMin or 2.2
local BURST_MAX <const> = MARBLE_CONFIG.burstVelocityMax or 8

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function randomRange(minValue, maxValue)
    return minValue + (math.random() * (maxValue - minValue))
end

local function magnitude(x, y)
    return math.sqrt((x * x) + (y * y))
end

local function buildGridPositions(width, height, total)
    local positions = {}
    if total <= 0 then
        return positions
    end

    local columns = math.ceil(math.sqrt(total))
    local rows = math.ceil(total / columns)
    local xStep = width / (columns + 1)
    local yStep = height / (rows + 1)

    for index = 0, total - 1 do
        local column = index % columns
        local row = math.floor(index / columns)
        positions[#positions + 1] = {
            x = (column + 1) * xStep,
            y = (row + 1) * yStep
        }
    end

    for index = #positions, 2, -1 do
        local swapIndex = math.random(index)
        positions[index], positions[swapIndex] = positions[swapIndex], positions[index]
    end

    return positions
end

function MarbleMadness.new(width, height, options)
    local self = setmetatable({}, MarbleMadness)
    options = options or {}
    self.width = width
    self.height = height
    self.preview = options.preview == true
    self.marbles = {}
    self.cursorX = width * 0.5
    self.cursorY = height * 0.5
    self.gravityStrength = GRAVITY_DEFAULT
    self.tempWellActive = false
    self.frame = 0
    self:seedMarbles()
    if START_WITH_ENERGY then
        self:burstAll()
    end
    return self
end

function MarbleMadness:setPreview(isPreview)
    self.preview = isPreview == true
end

function MarbleMadness:addMarble(x, y, diameter)
    local radius = diameter * 0.5
    self.marbles[#self.marbles + 1] = {
        x = clamp(x, radius, self.width - radius),
        y = clamp(y, radius, self.height - radius),
        vx = 0,
        vy = 0,
        ax = 0,
        ay = 0,
        radius = radius,
        mass = radius * radius,
        pattern = math.random(0, 3)
    }
end

function MarbleMadness:seedMarbles()
    self.marbles = {}
    local total = SMALL_COUNT + MEDIUM_COUNT + LARGE_COUNT
    local positions = buildGridPositions(self.width, self.height, total)
    local cursor = 1

    for _ = 1, SMALL_COUNT do
        local point = positions[cursor]
        cursor = cursor + 1
        self:addMarble(point.x, point.y, SMALL_DIAMETER)
    end
    for _ = 1, MEDIUM_COUNT do
        local point = positions[cursor]
        cursor = cursor + 1
        self:addMarble(point.x, point.y, MEDIUM_DIAMETER)
    end
    for _ = 1, LARGE_COUNT do
        local point = positions[cursor]
        cursor = cursor + 1
        self:addMarble(point.x, point.y, LARGE_DIAMETER)
    end
end

function MarbleMadness:burstAll()
    for _, marble in ipairs(self.marbles) do
        local angle = math.random() * math.pi * 2
        local speed = randomRange(BURST_MIN, BURST_MAX)
        marble.vx = math.cos(angle) * speed
        marble.vy = math.sin(angle) * speed
    end
end

function MarbleMadness:applyForce(marble, fx, fy)
    marble.ax = marble.ax + (fx / marble.mass)
    marble.ay = marble.ay + (fy / marble.mass)
end

function MarbleMadness:applyGravityWell(x, y)
    for _, marble in ipairs(self.marbles) do
        local dx = x - marble.x
        local dy = y - marble.y
        local distance = magnitude(dx, dy)
        if distance < marble.radius then
            marble.x = x
            marble.y = y
            marble.vx = 0
            marble.vy = 0
            marble.ax = 0
            marble.ay = 0
        else
            distance = math.max(1, distance)
            local pull = self.gravityStrength / (distance * distance)
            self:applyForce(marble, (dx / distance) * pull * marble.mass, (dy / distance) * pull * marble.mass)
        end
    end
end

function MarbleMadness:handleDirectionalInput(leftHeld, rightHeld, upHeld, downHeld)
    local dx = (rightHeld and 1 or 0) - (leftHeld and 1 or 0)
    local dy = (downHeld and 1 or 0) - (upHeld and 1 or 0)
    if dx == 0 and dy == 0 then
        return
    end

    self.cursorX = clamp(self.cursorX + (dx * CURSOR_SPEED), 8, self.width - 8)
    self.cursorY = clamp(self.cursorY + (dy * CURSOR_SPEED), 8, self.height - 8)
end

function MarbleMadness:updateActionInput(aHeld)
    self.tempWellActive = aHeld == true
end

function MarbleMadness:applyCrank(change)
    if math.abs(change or 0) <= 0.01 then
        return
    end
    self.gravityStrength = clamp(self.gravityStrength + ((change or 0) * GRAVITY_STEP), GRAVITY_MIN, GRAVITY_MAX)
end

function MarbleMadness:updateMarble(marble)
    marble.vx = (marble.vx + marble.ax) * FRICTION
    marble.vy = (marble.vy + marble.ay) * FRICTION
    marble.x = marble.x + marble.vx
    marble.y = marble.y + marble.vy
    marble.ax = 0
    marble.ay = 0

    local hit = false
    if marble.x < marble.radius then
        marble.x = marble.radius
        marble.vx = -marble.vx * RESTITUTION
        hit = true
    elseif marble.x > self.width - marble.radius then
        marble.x = self.width - marble.radius
        marble.vx = -marble.vx * RESTITUTION
        hit = true
    end
    if marble.y < marble.radius then
        marble.y = marble.radius
        marble.vy = -marble.vy * RESTITUTION
        hit = true
    elseif marble.y > self.height - marble.radius then
        marble.y = self.height - marble.radius
        marble.vy = -marble.vy * RESTITUTION
        hit = true
    end

    if hit and CHAOS_MODE then
        marble.pattern = math.random(0, 3)
    end
end

function MarbleMadness:handleCollisions()
    for first = 1, #self.marbles - 1 do
        local a = self.marbles[first]
        for second = first + 1, #self.marbles do
            local b = self.marbles[second]
            local dx = b.x - a.x
            local dy = b.y - a.y
            local distance = magnitude(dx, dy)
            local minDistance = a.radius + b.radius
            if distance > 0.0001 and distance < minDistance then
                local normalX = dx / distance
                local normalY = dy / distance
                local overlap = minDistance - distance
                a.x = a.x - (normalX * overlap * 0.5)
                a.y = a.y - (normalY * overlap * 0.5)
                b.x = b.x + (normalX * overlap * 0.5)
                b.y = b.y + (normalY * overlap * 0.5)

                local v1 = (a.vx * normalX) + (a.vy * normalY)
                local v2 = (b.vx * normalX) + (b.vy * normalY)
                local newV1 = ((v1 * (a.mass - b.mass)) + (2 * b.mass * v2)) / (a.mass + b.mass)
                local newV2 = ((v2 * (b.mass - a.mass)) + (2 * a.mass * v1)) / (a.mass + b.mass)

                a.vx = normalX * newV1 * RESTITUTION
                a.vy = normalY * newV1 * RESTITUTION
                b.vx = normalX * newV2 * RESTITUTION
                b.vy = normalY * newV2 * RESTITUTION

                if CHAOS_MODE then
                    local angleA = math.random() * math.pi * 2
                    local angleB = math.random() * math.pi * 2
                    local speedA = randomRange(BURST_MIN, BURST_MAX)
                    local speedB = randomRange(BURST_MIN, BURST_MAX)
                    a.vx = a.vx + (math.cos(angleA) * speedA)
                    a.vy = a.vy + (math.sin(angleA) * speedA)
                    b.vx = b.vx + (math.cos(angleB) * speedB)
                    b.vy = b.vy + (math.sin(angleB) * speedB)
                    a.pattern = math.random(0, 3)
                    b.pattern = math.random(0, 3)
                end
            end
        end
    end
end

function MarbleMadness:update()
    self.frame = self.frame + 1
    if self.preview and self.frame % 90 == 0 then
        self:burstAll()
    end
    if self.tempWellActive then
        self:applyGravityWell(self.cursorX, self.cursorY)
    end
    for _, marble in ipairs(self.marbles) do
        self:updateMarble(marble)
    end
    self:handleCollisions()
end

function MarbleMadness:drawWell()
    gfx.drawLine(self.cursorX - 8, self.cursorY - 8, self.cursorX + 8, self.cursorY + 8)
    gfx.drawLine(self.cursorX + 8, self.cursorY - 8, self.cursorX - 8, self.cursorY + 8)
    if self.tempWellActive then
        gfx.drawCircleAtPoint(self.cursorX, self.cursorY, 12)
    end
end

function MarbleMadness:drawMarble(marble)
    local x = math.floor(marble.x + 0.5)
    local y = math.floor(marble.y + 0.5)
    local radius = math.max(2, math.floor(marble.radius + 0.5))

    if marble.pattern == 0 then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(x, y, radius)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawCircleAtPoint(x, y, radius)
    elseif marble.pattern == 1 then
        gfx.setColor(gfx.kColorWhite)
        gfx.drawCircleAtPoint(x, y, radius)
        gfx.drawCircleAtPoint(x, y, math.max(1, radius - 3))
    elseif marble.pattern == 2 then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(x, y, radius)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(x - math.floor(radius * 0.25), y - math.floor(radius * 0.25), math.max(1, math.floor(radius * 0.35)))
    else
        gfx.setColor(gfx.kColorWhite)
        gfx.setDitherPattern(0.45, gfx.image.kDitherTypeBayer8x8)
        gfx.fillCircleAtPoint(x, y, radius)
        gfx.setDitherPattern(1, gfx.image.kDitherTypeBayer8x8)
        gfx.drawCircleAtPoint(x, y, radius)
    end
end

function MarbleMadness:drawHud()
    if self.preview or (UIState and not UIState.isShown()) then
        return
    end
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawText(string.format("Marbles %d  Gravity %d", #self.marbles, math.floor(self.gravityStrength + 0.5)), 8, 8)
    gfx.drawText("D-pad well  Hold A pull  Crank gravity  B title", 8, 222)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function MarbleMadness:draw()
    gfx.clear(gfx.kColorBlack)
    gfx.setColor(gfx.kColorWhite)
    self:drawWell()
    for _, marble in ipairs(self.marbles) do
        self:drawMarble(marble)
    end
    gfx.setDitherPattern(1, gfx.image.kDitherTypeBayer8x8)
    gfx.setColor(gfx.kColorWhite)
    self:drawHud()
end
