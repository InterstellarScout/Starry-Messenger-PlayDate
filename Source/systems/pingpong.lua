--[[ Ping Pong with escalating tilted and mountain walls. ]]
local gfx <const> = playdate.graphics

PingPong = {}
PingPong.__index = PingPong

PingPong.MODE_SOLO = "solo"
PingPong.MODE_TWO_PADDLE = "two-paddle"

function PingPong.getModeLabel(modeId)
    return modeId == PingPong.MODE_TWO_PADDLE and "Two Paddle" or "Solo"
end

local PADDLE_W <const> = 7
local PADDLE_H <const> = 38
local BALL_R <const> = 4
local PLAYER_SPEED <const> = 3.3
local PLAYER_CRANK_SCALE <const> = 0.55
local BALL_SPEED_STEP <const> = 0.06
local BALL_SPEED_HOLD_DELAY_FRAMES <const> = 60
local PADDLE_MAX_BOUNCE_ANGLE <const> = math.rad(78)
local MAX_COLLISION_STEP <const> = 4

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function vectorLength(x, y) return math.sqrt((x * x) + (y * y)) end

function PingPong.new(width, height, options)
    local self = setmetatable({}, PingPong)
    self.width, self.height = width or 400, height or 240
    self.preview = options and options.preview == true
    self.modeId = options and options.modeId or PingPong.MODE_SOLO
    self.playerY, self.aiY = self.height * .5, self.height * .5
    self.playerInput = 0
    self.speedInput, self.speedInputFrames = 0, 0
    self.leftRightMode, self.mountainSideHeight = "speed", 0
    self.playerScore, self.aiScore, self.frame = 0, 0, 0
    self.status = "First to the next five changes the court"
    self:serve(math.random() < .5 and 1 or -1)
    return self
end

function PingPong:setPreview(enabled) self.preview = enabled == true end
function PingPong:handleDirectionalInput(left, right, up, down)
    self.playerInput = (down and 1 or 0) - (up and 1 or 0)
    local horizontalInput = (right and 1 or 0) - (left and 1 or 0)
    if self.leftRightMode == "mountains" then
        self.speedInput, self.speedInputFrames = 0, 0
        if horizontalInput ~= 0 then
            self.mountainSideHeight = clamp(self.mountainSideHeight + horizontalInput, 0, 74)
        end
    else
        self.speedInput = horizontalInput
        if horizontalInput == 0 then
            self.speedInputFrames = 0
        elseif horizontalInput ~= self.previousSpeedInput then
            self.speedInputFrames = 0
        end
        self.previousSpeedInput = horizontalInput
    end
end

function PingPong:applyCrank(change)
    if self.preview or math.abs(change) <= 0.01 then
        return
    end
    if self.modeId == PingPong.MODE_TWO_PADDLE then
        self.aiY = clamp(self.aiY - (change * PLAYER_CRANK_SCALE), 42, self.height - 42)
    else
        self.playerY = clamp(self.playerY - (change * PLAYER_CRANK_SCALE), 42, self.height - 42)
    end
end

function PingPong:adjustBallSpeed(amount)
    local ball = self.ball
    if ball == nil then
        return
    end
    -- Signed and unbounded: zero pauses the ball and crossing zero reverses it.
    ball.speedControl = (ball.speedControl or 1) + amount
end
function PingPong:handlePrimaryAction()
    self.leftRightMode = self.leftRightMode == "speed" and "mountains" or "speed"
    self.speedInput, self.speedInputFrames = 0, 0
    self.status = self.leftRightMode == "mountains" and "Left/Right shapes mountain edges" or "Left/Right controls signed ball speed"
end

function PingPong:getCourtLevel()
    return math.floor(math.max(self.playerScore, self.aiScore) / 5)
end
function PingPong:getMountainCount()
    return math.max(0, self:getCourtLevel() - 3) + (self.mountainSideHeight > 0 and 1 or 0)
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
    local edge = clamp((math.abs(normalized) - 0.24) / 0.76, 0, 1)
    y = y + (top and edge * self.mountainSideHeight or -edge * self.mountainSideHeight)
    return y
end

function PingPong:serve(direction)
    self.ball = { x = self.width * .5, y = self.height * .5, vx = direction * 3.1, vy = (math.random() - .5) * 2.2, speedControl = 1 }
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
    if self.modeId ~= PingPong.MODE_TWO_PADDLE then
        local aiTarget = self.ball.y
        self.aiY = self.aiY + clamp(aiTarget - self.aiY, -2.3, 2.3)
        self.aiY = clamp(self.aiY, 42, self.height - 42)
    end
end

function PingPong:collidePaddle(x, y, paddleX, paddleY, toward, speedControl)
    if math.abs(x - paddleX) <= PADDLE_W + BALL_R and math.abs(y - paddleY) <= (PADDLE_H * .5) + BALL_R then
        self.ball.x = paddleX + (toward * (PADDLE_W + BALL_R + 1))
        local hitOffset = clamp((y - paddleY) / (PADDLE_H * .5), -1, 1)
        local bounceAngle = hitOffset * PADDLE_MAX_BOUNCE_ANGLE
        local bounceSpeed = vectorLength(self.ball.vx * speedControl, self.ball.vy * speedControl) + 0.14 + (math.abs(hitOffset) * 0.52)
        -- A center hit travels nearly straight across; edge hits bend sharply
        -- toward the matching side of the court.
        self.ball.vx = (toward * math.cos(bounceAngle) * bounceSpeed) / speedControl
        self.ball.vy = (math.sin(bounceAngle) * bounceSpeed) / speedControl
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

function PingPong:bounceOffWall(top, wallY, speedControl)
    local ball = self.ball
    local slope = self:getWallSlope(ball.x, top)
    -- Normals point into the playable court, so reflection follows the new
    -- wall's local tilt or mountain face instead of only flipping vertical speed.
    local normalX, normalY = top and -slope or slope, top and 1 or -1
    local normalLength = vectorLength(normalX, normalY)
    normalX, normalY = normalX / normalLength, normalY / normalLength
    local velocityX, velocityY = ball.vx * speedControl, ball.vy * speedControl
    local normalVelocity = (velocityX * normalX) + (velocityY * normalY)
    if normalVelocity < 0 then
        velocityX = velocityX - (2 * normalVelocity * normalX)
        velocityY = velocityY - (2 * normalVelocity * normalY)
        ball.vx, ball.vy = velocityX / speedControl, velocityY / speedControl
    end
    ball.y = wallY + (top and BALL_R or -BALL_R)
end

function PingPong:updateBallStep()
    local ball = self.ball
    local speedControl = ball.speedControl or 1
    if math.abs(speedControl) < 0.0001 then return end
    local velocityX, velocityY = ball.vx * speedControl, ball.vy * speedControl
    ball.x, ball.y = ball.x + velocityX, ball.y + velocityY
    local top, bottom = self:getWallY(ball.x, true), self:getWallY(ball.x, false)
    if ball.y - BALL_R <= top then self:bounceOffWall(true, top, speedControl) end
    if ball.y + BALL_R >= bottom then self:bounceOffWall(false, bottom, speedControl) end
    -- Paddle side follows the actual signed motion, including reversed speed.
    if velocityX < 0 then self:collidePaddle(ball.x, ball.y, 22, self.playerY, 1, speedControl) else self:collidePaddle(ball.x, ball.y, self.width - 22, self.aiY, -1, speedControl) end
    if ball.x < -BALL_R then self:score(false) elseif ball.x > self.width + BALL_R then self:score(true) end
end

function PingPong:updateBall()
    local ball = self.ball
    local travel = vectorLength(ball.vx, ball.vy) * math.abs(ball.speedControl or 1)
    local steps = math.max(1, math.ceil(travel / MAX_COLLISION_STEP))
    local originalSpeed = ball.speedControl or 1
    -- Divide the signed multiplier for substeps; this keeps fast and reversed
    -- balls from tunnelling through steep mountain sides or paddle edges.
    ball.speedControl = originalSpeed / steps
    for _ = 1, steps do
        self:updateBallStep()
        if self.ball ~= ball then break end
    end
    if self.ball == ball then ball.speedControl = originalSpeed end
end

function PingPong:update()
    self.frame = self.frame + 1
    if self.speedInput ~= 0 and self.leftRightMode == "speed" then
        self.speedInputFrames = self.speedInputFrames + 1
        local heldFrames = math.max(0, self.speedInputFrames - BALL_SPEED_HOLD_DELAY_FRAMES)
        local acceleration = BALL_SPEED_STEP * (heldFrames > 0 and math.exp(heldFrames / 180) or 1)
        self:adjustBallSpeed(self.speedInput * acceleration)
    end
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
        gfx.drawText("YOU " .. tostring(self.playerScore), 8, 8)
        gfx.drawTextAligned("RIVAL " .. tostring(self.aiScore), self.width - 8, 8, kTextAlignment.right)
        gfx.drawTextAligned(string.format("YOU %d    %d RIVAL", self.playerScore, self.aiScore), self.width * .5, self.height - 34, kTextAlignment.center)
        gfx.drawTextAligned(self.status, self.width * .5, self.height - 18, kTextAlignment.center)
    end
end
