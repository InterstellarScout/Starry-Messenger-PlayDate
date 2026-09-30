--[[ Ping Pong with escalating tilted and mountain walls. ]]
local gfx <const> = playdate.graphics

PingPong = {}
PingPong.__index = PingPong

local PADDLE_W <const> = 7
local PADDLE_H <const> = 38
local BALL_R <const> = 4
local PLAYER_SPEED <const> = 3.3

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

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
function PingPong:handleDirectionalInput(_left, _right, up, down)
    self.playerInput = (down and 1 or 0) - (up and 1 or 0)
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
        self.ball.vx = toward * math.min(6.5, math.abs(self.ball.vx) + .14)
        self.ball.vy = clamp(self.ball.vy + ((y - paddleY) / PADDLE_H) * 2.5, -5.5, 5.5)
        return true
    end
    return false
end

function PingPong:updateBall()
    local ball = self.ball
    ball.x, ball.y = ball.x + ball.vx, ball.y + ball.vy
    local top, bottom = self:getWallY(ball.x, true), self:getWallY(ball.x, false)
    if ball.y - BALL_R <= top then ball.y, ball.vy = top + BALL_R, math.abs(ball.vy) end
    if ball.y + BALL_R >= bottom then ball.y, ball.vy = bottom - BALL_R, -math.abs(ball.vy) end
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
