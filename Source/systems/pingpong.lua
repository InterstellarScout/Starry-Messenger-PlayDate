--[[ Ping Pong with escalating tilted and mountain walls. ]]
local gfx <const> = playdate.graphics

PingPong = {}
PingPong.__index = PingPong

local PADDLE_W <const> = 7
local PADDLE_H <const> = 38
local BALL_R <const> = 4
local PLAYER_SPEED <const> = 3.3
local PLAYER_CRANK_SCALE <const> = 0.55
local BALL_SPEED_MIN <const> = 2.1
local BALL_SPEED_MAX <const> = 7.4
local BALL_SPEED_STEP <const> = 0.06
local PADDLE_MAX_BOUNCE_ANGLE <const> = math.rad(62)

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function vectorLength(x, y) return math.sqrt((x * x) + (y * y)) end

function PingPong.new(width, height, options)
    local self = setmetatable({}, PingPong)
    self.width, self.height = width or 400, height or 240
    self.preview = options and options.preview == true
    self.playerY, self.aiY = self.height * .5, self.height * .5
    self.playerInput = 0
    self.playerScore, self.aiScore, self.frame = 0, 0, 0
    self.status = "First to the next five changes the court"
    self:serve(math.random() < .5 and 1 or -1)
    return self
end

function PingPong:setPreview(enabled) self.preview = enabled == true end
function PingPong:handleDirectionalInput(left, right, up, down)
    self.playerInput = (down and 1 or 0) - (up and 1 or 0)
    local speedChange = (right and 1 or 0) - (left and 1 or 0)
    if speedChange ~= 0 then
        self:adjustBallSpeed(speedChange * BALL_SPEED_STEP)
    end
end

function PingPong:applyCrank(change)
    if self.preview or math.abs(change) <= 0.01 then
        return
    end
    self.playerY = clamp(self.playerY + (change * PLAYER_CRANK_SCALE), 42, self.height - 42)
end

function PingPong:adjustBallSpeed(amount)
    local ball = self.ball
    if ball == nil then
        return
    end
    local speed = vectorLength(ball.vx, ball.vy)
    if speed <= 0.001 then
        ball.vx, ball.vy = BALL_SPEED_MIN, 0
        return
    end
    local adjustedSpeed = clamp(speed + amount, BALL_SPEED_MIN, BALL_SPEED_MAX)
    local scale = adjustedSpeed / speed
    ball.vx, ball.vy = ball.vx * scale, ball.vy * scale
end
function PingPong:handlePrimaryAction()
    self:serve(self.ball and (self.ball.vx >= 0 and -1 or 1) or 1)
end

function PingPong:getCourtLevel()
    return math.floor(math.max(self.playerScore, self.aiScore) / 5)
end
function PingPong:getMountainCount()
    return math.max(0, self:getCourtLevel() - 3)
end
function PingPong:getWallY(x, top)
    local level = self:getCourtLevel()
    local tilt = level > 0 and math.min(18, level * 3) or 0
    local normalized = (x / self.width) - .5
    local base = top and 18 or self.height - 18
    local y = base + (top and tilt * normalized or -tilt * normalized)
    local peaks = self:getMountainCount()
    if peaks > 0 then
        local mountain = math.max(0, math.sin((x / self.width) * math.pi * peaks)) * math.min(20, 7 + peaks * 3)
        y = y + (top and mountain or -mountain)
    end
    return y
end

function PingPong:serve(direction)
    self.ball = { x = self.width * .5, y = self.height * .5, vx = direction * 3.1, vy = (math.random() - .5) * 2.2 }
end

function PingPong:score(player)
    if player then self.playerScore = self.playerScore + 1 else self.aiScore = self.aiScore + 1 end
    local level = self:getCourtLevel()
    if level >= 4 then
        self.status = "Mountains rise! Peak level " .. tostring(self:getMountainCount())
    elseif level > 0 then
        self.status = "The walls tilt steeper!"
    else
        self.status = "Keep the ball in play."
    end
    self:serve(player and -1 or 1)
end

function PingPong:updatePaddles()
    if self.preview then self.playerInput = math.sin(self.frame * .06) > 0 and 1 or -1 end
    self.playerY = clamp(self.playerY + self.playerInput * PLAYER_SPEED, 42, self.height - 42)
    local aiTarget = self.ball.y
    self.aiY = self.aiY + clamp(aiTarget - self.aiY, -2.3, 2.3)
    self.aiY = clamp(self.aiY, 42, self.height - 42)
end

function PingPong:collidePaddle(x, y, paddleX, paddleY, toward)
    if math.abs(x - paddleX) <= PADDLE_W + BALL_R and math.abs(y - paddleY) <= (PADDLE_H * .5) + BALL_R then
        self.ball.x = paddleX + (toward * (PADDLE_W + BALL_R + 1))
        local hitOffset = clamp((y - paddleY) / (PADDLE_H * .5), -1, 1)
        local bounceAngle = hitOffset * PADDLE_MAX_BOUNCE_ANGLE
        local bounceSpeed = clamp(vectorLength(self.ball.vx, self.ball.vy) + 0.14, BALL_SPEED_MIN, BALL_SPEED_MAX)
        -- A center hit travels nearly straight across; edge hits bend sharply
        -- toward the matching side of the court.
        self.ball.vx = toward * math.cos(bounceAngle) * bounceSpeed
        self.ball.vy = math.sin(bounceAngle) * bounceSpeed
        return true
    end
    return false
end

function PingPong:getWallSlope(x, top)
    local sampleDistance = 2
    local leftX = clamp(x - sampleDistance, 0, self.width)
    local rightX = clamp(x + sampleDistance, 0, self.width)
    if rightX <= leftX then
        return 0
    end
    return (self:getWallY(rightX, top) - self:getWallY(leftX, top)) / (rightX - leftX)
end

function PingPong:bounceOffWall(top, wallY)
    local ball = self.ball
    local slope = self:getWallSlope(ball.x, top)
    -- Normals point into the playable court, so reflection follows the new
    -- wall's local tilt or mountain face instead of only flipping vertical speed.
    local normalX, normalY = top and -slope or slope, top and 1 or -1
    local normalLength = vectorLength(normalX, normalY)
    normalX, normalY = normalX / normalLength, normalY / normalLength
    local normalVelocity = (ball.vx * normalX) + (ball.vy * normalY)
    if normalVelocity < 0 then
        ball.vx = ball.vx - (2 * normalVelocity * normalX)
        ball.vy = ball.vy - (2 * normalVelocity * normalY)
    end
    ball.y = wallY + (top and BALL_R or -BALL_R)
end

function PingPong:updateBall()
    local ball = self.ball
    ball.x, ball.y = ball.x + ball.vx, ball.y + ball.vy
    local top, bottom = self:getWallY(ball.x, true), self:getWallY(ball.x, false)
    if ball.y - BALL_R <= top then self:bounceOffWall(true, top) end
    if ball.y + BALL_R >= bottom then self:bounceOffWall(false, bottom) end
    if ball.vx < 0 then self:collidePaddle(ball.x, ball.y, 22, self.playerY, 1) else self:collidePaddle(ball.x, ball.y, self.width - 22, self.aiY, -1) end
    if ball.x < -BALL_R then self:score(false) elseif ball.x > self.width + BALL_R then self:score(true) end
end

function PingPong:update()
    self.frame = self.frame + 1
    self:updatePaddles()
    self:updateBall()
end

function PingPong:drawCourt()
    gfx.setColor(gfx.kColorBlack)
    local previousTop, previousBottom = self:getWallY(0, true), self:getWallY(0, false)
    for x = 4, self.width, 4 do
        local top, bottom = self:getWallY(x, true), self:getWallY(x, false)
        gfx.drawLine(x - 4, previousTop, x, top)
        gfx.drawLine(x - 4, previousBottom, x, bottom)
        previousTop, previousBottom = top, bottom
    end
    if self:getMountainCount() > 0 then
        gfx.drawTextAligned("MOUNTAIN COURT", self.width * .5, 3, kTextAlignment.center)
    end
end

function PingPong:drawPaddle(x, y)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(x - PADDLE_W * .5, y - PADDLE_H * .5, PADDLE_W, PADDLE_H, 3)
end

function PingPong:draw()
    gfx.clear(gfx.kColorWhite)
    self:drawCourt()
    self:drawPaddle(22, self.playerY)
    self:drawPaddle(self.width - 22, self.aiY)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(self.ball.x, self.ball.y, BALL_R)
    if not self.preview and (not UIState or UIState.isShown()) then
        gfx.drawTextAligned(string.format("YOU %d    %d RIVAL", self.playerScore, self.aiScore), self.width * .5, self.height - 34, kTextAlignment.center)
        gfx.drawTextAligned(self.status, self.width * .5, self.height - 18, kTextAlignment.center)
    end
end
