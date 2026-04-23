import "gameconfig"

--[[
Tilt-driven bouncy ball playground.

Purpose:
- rolls and bounces balls around the screen using device tilt as gravity
- lets the player spawn more balls and tune slowdown live with the crank
- provides a low-cost animated preview for the title menu
]]
local pd <const> = playdate
local gfx <const> = pd.graphics
local TILT_BALLS_CONFIG <const> = GameConfig and GameConfig.tiltBalls or {}

TiltBalls = {}
TiltBalls.__index = TiltBalls

local SCREEN_PADDING <const> = 4
local MIN_RADIUS <const> = TILT_BALLS_CONFIG.minRadius or 7
local MAX_RADIUS <const> = TILT_BALLS_CONFIG.maxRadius or 16
local MAX_BALLS <const> = TILT_BALLS_CONFIG.maxBalls or 18
local GRAVITY_STRENGTH <const> = TILT_BALLS_CONFIG.gravityStrength or 0.55
local WALL_BOUNCE <const> = TILT_BALLS_CONFIG.wallBounce or 0.84
local BALL_BOUNCE <const> = TILT_BALLS_CONFIG.ballBounce or 0.92
local MIN_SLOWDOWN <const> = TILT_BALLS_CONFIG.minSlowdown or 0.90
local MAX_SLOWDOWN <const> = TILT_BALLS_CONFIG.maxSlowdown or 0.995
local CRANK_SLOWDOWN_STEP <const> = TILT_BALLS_CONFIG.crankSlowdownStep or 0.0025
local PREVIEW_SPAWN_COUNT <const> = TILT_BALLS_CONFIG.previewSpawnCount or 4

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function magnitude(x, y)
    return math.sqrt((x * x) + (y * y))
end

local function normalize(x, y)
    local length = magnitude(x, y)
    if length <= 0.0001 then
        return 0, 1
    end
    return x / length, y / length
end

local function roundToHundredths(value)
    return math.floor((value * 100) + 0.5) / 100
end

function TiltBalls.new(width, height, options)
    options = options or {}
    local self = setmetatable({}, TiltBalls)
    self.width = width
    self.height = height
    self.preview = options.preview == true
    self.balls = {}
    self.frame = 0
    self.slowdown = options.slowdown or TILT_BALLS_CONFIG.defaultSlowdown or 0.972
    self.previewAngle = 0
    self.previewPulse = 0

    local initialCount = self.preview and PREVIEW_SPAWN_COUNT or 1
    for _ = 1, initialCount do
        self:spawnBall()
    end

    return self
end

function TiltBalls:setPreview(preview)
    self.preview = preview == true
end

function TiltBalls:activate()
    if not self.preview and not pd.accelerometerIsRunning() then
        pd.startAccelerometer()
    end
end

function TiltBalls:shutdown()
    if not self.preview and pd.accelerometerIsRunning() then
        pd.stopAccelerometer()
    end
end

function TiltBalls:handlePrimaryAction()
    self:spawnBall()
end

function TiltBalls:applyCrank(change)
    if math.abs(change) < 0.01 then
        return
    end

    self.slowdown = clamp(
        self.slowdown + ((change > 0 and 1 or -1) * CRANK_SLOWDOWN_STEP),
        MIN_SLOWDOWN,
        MAX_SLOWDOWN
    )
end

function TiltBalls:spawnBall()
    if #self.balls >= MAX_BALLS then
        return false
    end

    local radius = math.random(MIN_RADIUS, MAX_RADIUS)
    local ball = {
        radius = radius,
        x = self.width * 0.5,
        y = self.height * 0.5,
        vx = (math.random() * 2.2) - 1.1,
        vy = (math.random() * 2.2) - 1.1,
        spin = (math.random() * 24) - 12
    }

    local placed = false
    for _ = 1, 36 do
        local candidateX = math.random(radius + SCREEN_PADDING, self.width - radius - SCREEN_PADDING)
        local candidateY = math.random(radius + SCREEN_PADDING, self.height - radius - SCREEN_PADDING)
        local overlaps = false
        for _, other in ipairs(self.balls) do
            local dx = candidateX - other.x
            local dy = candidateY - other.y
            local minDistance = radius + other.radius + 3
            if (dx * dx) + (dy * dy) < (minDistance * minDistance) then
                overlaps = true
                break
            end
        end

        if not overlaps then
            ball.x = candidateX
            ball.y = candidateY
            placed = true
            break
        end
    end

    if not placed then
        ball.x = clamp(ball.x, radius + SCREEN_PADDING, self.width - radius - SCREEN_PADDING)
        ball.y = clamp(ball.y, radius + SCREEN_PADDING, self.height - radius - SCREEN_PADDING)
    end

    self.balls[#self.balls + 1] = ball
    return true
end

function TiltBalls:getGravity()
    if not self.preview and pd.accelerometerIsRunning() then
        local ax, ay = pd.readAccelerometer()
        if ax ~= nil and ay ~= nil then
            local gx, gy = normalize(ax, ay)
            return gx, gy
        end
    end

    self.previewAngle = self.previewAngle + 0.03
    self.previewPulse = self.previewPulse + 0.017
    local gx = math.cos(self.previewAngle) * 0.85
    local gy = math.sin(self.previewPulse) * 0.6 + 0.45
    return normalize(gx, gy)
end

function TiltBalls:resolveBallCollisions()
    for index = 1, #self.balls do
        local a = self.balls[index]
        for otherIndex = index + 1, #self.balls do
            local b = self.balls[otherIndex]
            local dx = b.x - a.x
            local dy = b.y - a.y
            local distance = magnitude(dx, dy)
            local minDistance = a.radius + b.radius

            if distance > 0 and distance < minDistance then
                local nx = dx / distance
                local ny = dy / distance
                local overlap = minDistance - distance
                local separation = overlap * 0.5
                a.x = a.x - (nx * separation)
                a.y = a.y - (ny * separation)
                b.x = b.x + (nx * separation)
                b.y = b.y + (ny * separation)

                local relativeVelocityX = b.vx - a.vx
                local relativeVelocityY = b.vy - a.vy
                local closingSpeed = (relativeVelocityX * nx) + (relativeVelocityY * ny)
                if closingSpeed < 0 then
                    local impulse = -closingSpeed * BALL_BOUNCE
                    a.vx = a.vx - (nx * impulse)
                    a.vy = a.vy - (ny * impulse)
                    b.vx = b.vx + (nx * impulse)
                    b.vy = b.vy + (ny * impulse)
                end
            elseif distance <= 0.0001 then
                b.x = b.x + 0.5
                b.y = b.y + 0.5
            end
        end
    end
end

function TiltBalls:update()
    self.frame = self.frame + 1
    local gravityX, gravityY = self:getGravity()

    for _, ball in ipairs(self.balls) do
        ball.vx = (ball.vx + (gravityX * GRAVITY_STRENGTH)) * self.slowdown
        ball.vy = (ball.vy + (gravityY * GRAVITY_STRENGTH)) * self.slowdown
        ball.x = ball.x + ball.vx
        ball.y = ball.y + ball.vy
        ball.spin = ball.spin + ((ball.vx * 0.18) + (ball.vy * 0.08))

        local minX = ball.radius + SCREEN_PADDING
        local maxX = self.width - ball.radius - SCREEN_PADDING
        local minY = ball.radius + SCREEN_PADDING
        local maxY = self.height - ball.radius - SCREEN_PADDING

        if ball.x < minX then
            ball.x = minX
            ball.vx = math.abs(ball.vx) * WALL_BOUNCE
        elseif ball.x > maxX then
            ball.x = maxX
            ball.vx = -math.abs(ball.vx) * WALL_BOUNCE
        end

        if ball.y < minY then
            ball.y = minY
            ball.vy = math.abs(ball.vy) * WALL_BOUNCE
        elseif ball.y > maxY then
            ball.y = maxY
            ball.vy = -math.abs(ball.vy) * WALL_BOUNCE
            ball.vx = ball.vx * 0.985
        end
    end

    self:resolveBallCollisions()
end

function TiltBalls:drawBall(ball)
    gfx.drawCircleAtPoint(ball.x, ball.y, ball.radius)
    gfx.drawCircleAtPoint(ball.x, ball.y, math.max(1, ball.radius - 2))

    local angle = math.rad(ball.spin)
    local lineRadius = math.max(2, ball.radius - 3)
    local tipX = ball.x + (math.cos(angle) * lineRadius)
    local tipY = ball.y + (math.sin(angle) * lineRadius)
    local tailX = ball.x - (math.cos(angle) * lineRadius * 0.55)
    local tailY = ball.y - (math.sin(angle) * lineRadius * 0.55)
    gfx.drawLine(tailX, tailY, tipX, tipY)
end

function TiltBalls:draw()
    gfx.clear(gfx.kColorBlack)
    gfx.setColor(gfx.kColorWhite)

    for _, ball in ipairs(self.balls) do
        self:drawBall(ball)
    end

    if not self.preview then
        gfx.setImageDrawMode(gfx.kDrawModeInverted)
        gfx.drawText(string.format("Balls %d  Slow %.2f", #self.balls, roundToHundredths(self.slowdown)), 10, 8)
        gfx.drawText("Tilt to roll  Crank slowdown  A add ball  B back", 10, 220)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
end
