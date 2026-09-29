--[[
Don't Hit Me mini-game.

Purpose:
- an entirely on-screen playground-swing dodge game
- teaches the player to leave a clearly marked imaginary swing zone
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

DontHitMe = {}
DontHitMe.__index = DontHitMe

local SCREEN_WIDTH <const> = 400
local SCREEN_HEIGHT <const> = 240
local PLAYER_SPEED <const> = 3
local PIVOT_X <const> = 200
local PIVOT_Y <const> = 32
local ROPE_LENGTH <const> = 112
local SWING_WIDTH <const> = 106

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

-- Views can be suspended and restored by the system menu. Keep every field
-- used by the frame loop valid so a partially restored mini-game never turns
-- a missing value into a runtime error.
function DontHitMe:ensureState()
    self.width = tonumber(self.width) or SCREEN_WIDTH
    self.height = tonumber(self.height) or SCREEN_HEIGHT
    self.frame = tonumber(self.frame) or 0
    self.playerX = tonumber(self.playerX) or PIVOT_X
    self.playerY = tonumber(self.playerY) or 181
    self.dodges = tonumber(self.dodges) or 0
    self.hits = tonumber(self.hits) or 0
    self.activePass = self.activePass == true
    self.status = type(self.status) == "string" and self.status or "Move out of the marked swing path!"
end

function DontHitMe.new(width, height, options)
    options = options or {}
    local self = setmetatable({}, DontHitMe)
    self.width = width or SCREEN_WIDTH
    self.height = height or SCREEN_HEIGHT
    self.preview = options.preview == true
    self.frame = self.preview and 36 or 0
    self.playerX = self.preview and 290 or PIVOT_X
    self.playerY = 181
    self.dodges = 0
    self.hits = 0
    self.activePass = false
    self.status = self.preview and "Dodge the marked path" or "Move out of the marked swing path!"
    return self
end

function DontHitMe:setPreview(enabled)
    self:ensureState()
    self.preview = enabled == true
end

function DontHitMe:handlePrimaryAction()
    self:ensureState()
    self.playerX = PIVOT_X
    self.playerY = 181
    self.dodges = 0
    self.hits = 0
    self.status = "Fresh start. Dodge the marked path!"
end

function DontHitMe:handleDirectionalInput(leftHeld, rightHeld, upHeld, downHeld)
    self:ensureState()
    local dx = (rightHeld and 1 or 0) - (leftHeld and 1 or 0)
    local dy = (downHeld and 1 or 0) - (upHeld and 1 or 0)
    self.playerX = clamp(self.playerX + (dx * PLAYER_SPEED), 14, self.width - 14)
    self.playerY = clamp(self.playerY + (dy * PLAYER_SPEED), 72, self.height - 18)
end

function DontHitMe:getSwingPosition()
    self:ensureState()
    local angle = math.sin(self.frame * 0.075) * 0.94
    return PIVOT_X + (math.sin(angle) * ROPE_LENGTH), PIVOT_Y + (math.cos(angle) * ROPE_LENGTH), angle
end

function DontHitMe:update()
    self:ensureState()
    self.frame = self.frame + 1
    local swingX, swingY = self:getSwingPosition()
    local passingThroughZone = swingY > 126

    if passingThroughZone and not self.activePass then
        self.activePass = true
        local dx = self.playerX - swingX
        local dy = self.playerY - swingY
        if (dx * dx) + (dy * dy) < (34 * 34) then
            self.hits = self.hits + 1
            self.status = "Too close! Step beyond the marked zone."
            self.playerX = self.playerX < PIVOT_X and 86 or 314
        else
            self.dodges = self.dodges + 1
            self.status = self.dodges >= 10 and "Great awareness! Keep playing safely." or "Safe dodge!"
        end
    elseif not passingThroughZone then
        self.activePass = false
    end
end

function DontHitMe:drawSwing(swingX, swingY)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(PIVOT_X - 48, PIVOT_Y - 20, PIVOT_X, PIVOT_Y)
    gfx.drawLine(PIVOT_X + 48, PIVOT_Y - 20, PIVOT_X, PIVOT_Y)
    gfx.drawLine(PIVOT_X - 48, PIVOT_Y - 20, PIVOT_X - 65, 202)
    gfx.drawLine(PIVOT_X + 48, PIVOT_Y - 20, PIVOT_X + 65, 202)
    gfx.drawLine(PIVOT_X, PIVOT_Y, swingX, swingY)
    gfx.drawLine(swingX - 9, swingY + 3, swingX + 9, swingY + 3)
    gfx.fillCircleAtPoint(swingX, swingY - 5, 6)
    gfx.drawLine(swingX - 4, swingY + 1, swingX - 7, swingY + 14)
    gfx.drawLine(swingX + 4, swingY + 1, swingX + 7, swingY + 14)
end

function DontHitMe:drawMarkedZone()
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)
    for x = 145, 255, 12 do
        gfx.drawLine(x, 166, x + 6, 166)
        gfx.drawLine(x, 197, x + 6, 197)
    end
    gfx.drawLine(145, 166, 145, 197)
    gfx.drawLine(255, 166, 255, 197)
    gfx.drawTextAligned("IMAGINARY SWING PATH", PIVOT_X, 201, kTextAlignment.center)
end

function DontHitMe:drawPlayer()
    local x = math.floor(self.playerX + 0.5)
    local y = math.floor(self.playerY + 0.5)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(x, y - 8, 6)
    gfx.fillRect(x - 5, y - 1, 10, 15)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawCircleAtPoint(x, y - 8, 6)
    gfx.drawLine(x - 5, y - 1, x - 5, y + 14)
    gfx.drawLine(x + 5, y - 1, x + 5, y + 14)
    gfx.drawLine(x - 5, y + 14, x + 5, y + 14)
end

function DontHitMe:draw()
    self:ensureState()
    local swingX, swingY = self:getSwingPosition()
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, self.width, self.height)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawTextAligned("DON'T HIT ME", PIVOT_X, 8, kTextAlignment.center)
    gfx.drawText("Safe dodges " .. tostring(self.dodges), 10, 25)
    gfx.drawTextAligned("Too close " .. tostring(self.hits), 390, 25, kTextAlignment.right)
    gfx.drawLine(0, 43, self.width, 43)
    self:drawMarkedZone()
    self:drawSwing(swingX, swingY)
    self:drawPlayer()
    gfx.drawTextAligned(self.status, PIVOT_X, 218, kTextAlignment.center)
    gfx.drawTextAligned("D-pad: move   A: reset", PIVOT_X, 231, kTextAlignment.center)
end
