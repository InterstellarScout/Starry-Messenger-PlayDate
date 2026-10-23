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
local CRANK_TRAVERSE_DEGREES <const> = 720 -- two full turns from one edge to the other
local RESPAWN_FLASH_FRAMES <const> = 60 -- five flashes over two seconds at 30 fps
local LAUNCH_FRAMES <const> = 15 -- half a second of on-screen spin

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
    self.playerState = self.playerState or "active"
    self.playerAngle = tonumber(self.playerAngle) or 0
    self.respawnFrames = tonumber(self.respawnFrames) or 0
    self.launchFrames = tonumber(self.launchFrames) or 0
    self.launchStartX = tonumber(self.launchStartX) or self.playerX
    self.launchStartY = tonumber(self.launchStartY) or self.playerY
    self.launchTargetX = tonumber(self.launchTargetX) or self.playerX
    self.launchTargetY = tonumber(self.launchTargetY) or self.playerY
    self.previousSwingX = tonumber(self.previousSwingX)
    self.previousSwingY = tonumber(self.previousSwingY)
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
    self.playerState = "active"
    self.playerAngle = 0
    self.respawnFrames = 0
    self.launchFrames = 0
    self.previousSwingX, self.previousSwingY = nil, nil
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
    self.playerState, self.playerAngle = "active", 0
    self.respawnFrames, self.launchFrames = 0, 0
    self.status = "Fresh start. Dodge the marked path!"
end

function DontHitMe:handleDirectionalInput(leftHeld, rightHeld, upHeld, downHeld)
    self:ensureState()
    if self.playerState ~= "active" then return end
    local dx = (rightHeld and 1 or 0) - (leftHeld and 1 or 0)
    local dy = (downHeld and 1 or 0) - (upHeld and 1 or 0)
    self.playerX = clamp(self.playerX + (dx * PLAYER_SPEED), 14, self.width - 14)
    self.playerY = clamp(self.playerY + (dy * PLAYER_SPEED), 72, self.height - 18)
end

function DontHitMe:applyCrank(change)
    self:ensureState()
    if self.playerState ~= "active" then return end
    -- A complete 720 degree traversal maps exactly from one playable edge to the other.
    local pixelsPerDegree = (self.width - 28) / CRANK_TRAVERSE_DEGREES
    self.playerX = clamp(self.playerX + (change or 0) * pixelsPerDegree, 14, self.width - 14)
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
    local swingVX = self.previousSwingX and (swingX - self.previousSwingX) or 0
    local swingVY = self.previousSwingY and (swingY - self.previousSwingY) or 0
    self.previousSwingX, self.previousSwingY = swingX, swingY

    if self.playerState == "launched" then
        self.launchFrames = self.launchFrames - 1
        local progress = 1 - (self.launchFrames / LAUNCH_FRAMES)
        self.playerX = self.launchStartX + (self.launchTargetX - self.launchStartX) * progress
        self.playerY = self.launchStartY + (self.launchTargetY - self.launchStartY) * progress
        self.playerAngle = progress * math.pi * 4
        if self.launchFrames <= 0 then
            self.playerState = "respawning"
            self.playerX, self.playerY = PIVOT_X, self.height - 18
            self.playerAngle, self.respawnFrames = 0, RESPAWN_FLASH_FRAMES
            self.status = "Back at the bottom. Get ready..."
        end
        return
    elseif self.playerState == "respawning" then
        self.respawnFrames = self.respawnFrames - 1
        if self.respawnFrames <= 0 then
            self.playerState = "active"
            self.status = "Ready! Dodge the marked swing path."
        end
        return
    end

    local passingThroughZone = swingY > 126

    if passingThroughZone and not self.activePass then
        self.activePass = true
        local dx = self.playerX - swingX
        local dy = self.playerY - swingY
        if (dx * dx) + (dy * dy) < (34 * 34) then
            self.hits = self.hits + 1
            -- The swing keeps moving; its current travel direction determines
            -- the launch side while the player spins twice before exiting.
            local side = swingVX < 0 and -1 or 1
            if math.abs(swingVX) < .1 then side = self.playerX < swingX and -1 or 1 end
            self.playerState, self.launchFrames = "launched", LAUNCH_FRAMES
            self.launchStartX, self.launchStartY = self.playerX, self.playerY
            self.launchTargetX = side < 0 and -24 or self.width + 24
            self.launchTargetY = clamp(self.playerY + swingVY * 3, -24, self.height + 24)
            self.status = "Swing impact!"
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
    -- Offset rear supports and thick front rails give the frame a simple
    -- 3D playground-bar silhouette.
    gfx.setDitherPattern(.45, gfx.image.kDitherTypeBayer8x8); gfx.setLineWidth(4)
    gfx.drawLine(PIVOT_X - 40, PIVOT_Y - 14, PIVOT_X + 5, PIVOT_Y + 6)
    gfx.drawLine(PIVOT_X + 56, PIVOT_Y - 14, PIVOT_X + 5, PIVOT_Y + 6)
    gfx.drawLine(PIVOT_X - 40, PIVOT_Y - 14, PIVOT_X - 52, 202)
    gfx.drawLine(PIVOT_X + 56, PIVOT_Y - 14, PIVOT_X + 72, 202)
    gfx.setDitherPattern(1, gfx.image.kDitherTypeBayer8x8)
    gfx.setLineWidth(4)
    gfx.drawLine(PIVOT_X - 48, PIVOT_Y - 20, PIVOT_X, PIVOT_Y)
    gfx.drawLine(PIVOT_X + 48, PIVOT_Y - 20, PIVOT_X, PIVOT_Y)
    gfx.drawLine(PIVOT_X - 48, PIVOT_Y - 20, PIVOT_X - 65, 202)
    gfx.drawLine(PIVOT_X + 48, PIVOT_Y - 20, PIVOT_X + 65, 202)
    gfx.drawLine(PIVOT_X - 48, PIVOT_Y - 20, PIVOT_X + 48, PIVOT_Y - 20)
    gfx.setLineWidth(1)
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
    if self.playerState == "respawning" and math.floor(self.respawnFrames / 6) % 2 == 0 then return end
    local x = math.floor(self.playerX + 0.5)
    local y = math.floor(self.playerY + 0.5)
    local angle = self.playerAngle or 0
    local c, s = math.cos(angle), math.sin(angle)
    local function point(dx, dy) return x + dx * c - dy * s, y + dx * s + dy * c end
    local hx, hy = point(0, -8)
    local aX, aY = point(-5, -1)
    local bX, bY = point(5, -1)
    local cX, cY = point(5, 14)
    local dX, dY = point(-5, 14)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(hx, hy, 6)
    gfx.fillPolygon(aX, aY, bX, bY, cX, cY, dX, dY)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawCircleAtPoint(hx, hy, 6)
    gfx.drawPolygon(aX, aY, bX, bY, cX, cY, dX, dY)
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
    gfx.drawTextAligned("Crank: side-to-side   D-pad: move   A: reset", PIVOT_X, 231, kTextAlignment.center)
end
