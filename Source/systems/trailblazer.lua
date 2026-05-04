import "CoreLibs/graphics"

local pd <const> = playdate
local gfx <const> = pd.graphics

TrailBlazer = {}
TrailBlazer.__index = TrailBlazer

TrailBlazer.MODE_FLOW = "flow"
TrailBlazer.MODE_DRIVE = "drive"

local PLAYER_RADIUS <const> = 7
local PLAYER_DOT_RADIUS <const> = 2
local PLAYER_DRIVE_SPEED <const> = 3.2
local PLAYER_WRAP_MARGIN <const> = 10
local TRAIL_POINT_STEP <const> = 3
local BALL_RADIUS <const> = 6
local BALL_GRAVITY <const> = 0.12
local BALL_JERK_SCALE <const> = 0.28
local BALL_MAX_SPEED <const> = 6.2
local BALL_GROUND_FRICTION <const> = 0.96
local BALL_TRAIL_FRICTION <const> = 0.99
local BALL_NORMAL_BOUNCE <const> = 0.08
local BALL_SUBSTEPS <const> = 2
local FLOOR_Y_OFFSET <const> = 2
local BALL_RESPAWN_RADIUS <const> = 22
local MAX_ACTIVE_BALLS <const> = 3
local STATUS_FRAMES <const> = 60
local MENU_X <const> = 214
local MENU_Y <const> = 10
local MENU_WIDTH <const> = 176
local MENU_ROW_HEIGHT <const> = 20

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function distanceSquared(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return (dx * dx) + (dy * dy)
end

local function magnitude(x, y)
    return math.sqrt((x * x) + (y * y))
end

local function normalize(x, y, defaultX, defaultY)
    local length = magnitude(x, y)
    if length <= 0.0001 then
        return defaultX or 0, defaultY or 1
    end
    return x / length, y / length
end

local function closestPointOnSegment(px, py, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local lengthSquared = (dx * dx) + (dy * dy)
    if lengthSquared <= 0.0001 then
        return x1, y1, 0
    end

    local t = clamp((((px - x1) * dx) + ((py - y1) * dy)) / lengthSquared, 0, 1)
    return x1 + (dx * t), y1 + (dy * t), t
end

function TrailBlazer.new(width, height, options)
    options = options or {}
    local self = setmetatable({}, TrailBlazer)
    self.width = width or 400
    self.height = height or 240
    self.preview = options.preview == true
    self.modeId = options.modeId or TrailBlazer.MODE_FLOW
    self.player = {
        x = (width or 400) * 0.5,
        y = (height or 240) * 0.28,
        angle = -90,
        speed = PLAYER_DRIVE_SPEED
    }
    self.trailDrawing = self.preview
    self.trailPoints = {}
    self.trailSegments = {}
    self.balls = {}
    self.loadedBall = {
        radius = BALL_RADIUS
    }
    self.lastAccelX = 0
    self.lastAccelY = 1
    self.frame = 0
    self.previewPhase = 0
    self.statusMessage = nil
    self.statusFrames = 0
    self.driveDirection = 0
    self.showControlsHint = true
    self.pauseHudHidden = false
    self.hudHidden = false
    self.menuOpen = false
    self.menuIndex = 1
    self.instructionText = 'Hold Right D Pad to draw. Use Up/Down to move. Use Left D Pad to drop a ball.'
    self:resetLoadedBall()
    if self.trailDrawing then
        self:startTrailAtPlayer()
    end
    return self
end

function TrailBlazer:getCurrentModeLabel()
    return TrailBlazer.getModeLabel(self.modeId)
end

function TrailBlazer.getModeLabel(modeId)
    if modeId == TrailBlazer.MODE_DRIVE then
        return "Drive 3.2"
    end
    return "Flow"
end

function TrailBlazer:setPreview(preview)
    self.preview = preview == true
end

function TrailBlazer:isDriveMode()
    return self.modeId == TrailBlazer.MODE_DRIVE
end

function TrailBlazer:setPauseHudHidden(hidden)
    self.pauseHudHidden = hidden == true
end

function TrailBlazer:isMenuOpen()
    return self.menuOpen == true
end

function TrailBlazer:closeMenu()
    self.menuOpen = false
end

function TrailBlazer:getMenuItems()
    return {
        {
            id = "clear",
            label = "Clear Screen",
            kind = "action"
        },
        {
            id = "hideText",
            label = "Hide Text",
            kind = "toggle",
            checked = self.hudHidden == true
        }
    }
end

function TrailBlazer:activateMenuSelection()
    local items = self:getMenuItems()
    local item = items[self.menuIndex]
    if item == nil then
        return
    end

    if item.id == "clear" then
        self:clearTrail()
    elseif item.id == "hideText" then
        self.hudHidden = not self.hudHidden
        self:setStatus(self.hudHidden and "Text hidden" or "Text shown")
    end
end

function TrailBlazer:handlePrimaryAction()
    if self.menuOpen then
        self:activateMenuSelection()
        return
    end

    self.menuOpen = true
end

function TrailBlazer:updateMenuInput(upJustPressed, downJustPressed, leftJustPressed, rightJustPressed, confirmJustPressed)
    if not self.menuOpen then
        return
    end

    local items = self:getMenuItems()
    if upJustPressed then
        self.menuIndex = self.menuIndex - 1
        if self.menuIndex < 1 then
            self.menuIndex = #items
        end
    elseif downJustPressed then
        self.menuIndex = self.menuIndex + 1
        if self.menuIndex > #items then
            self.menuIndex = 1
        end
    end

    local selected = items[self.menuIndex]
    if selected ~= nil and selected.kind == "toggle" then
        if leftJustPressed or rightJustPressed or confirmJustPressed then
            self:activateMenuSelection()
        end
    elseif confirmJustPressed then
        self:activateMenuSelection()
    end
end

function TrailBlazer:activate()
    if not self.preview and not pd.accelerometerIsRunning() then
        pd.startAccelerometer()
    end
end

function TrailBlazer:shutdown()
    if not self.preview and pd.accelerometerIsRunning() then
        pd.stopAccelerometer()
    end
end

function TrailBlazer:setStatus(message)
    self.statusMessage = message
    self.statusFrames = STATUS_FRAMES
end

function TrailBlazer:startTrailAtPlayer()
    self.trailPoints[#self.trailPoints + 1] = {
        x = self.player.x,
        y = self.player.y
    }
end

function TrailBlazer:addTrailPoint(x, y)
    local lastPoint = self.trailPoints[#self.trailPoints]
    if lastPoint ~= nil and distanceSquared(lastPoint.x, lastPoint.y, x, y) < (TRAIL_POINT_STEP * TRAIL_POINT_STEP) then
        return
    end

    self.trailPoints[#self.trailPoints + 1] = {
        x = x,
        y = y
    }

    if #self.trailPoints >= 2 then
        local previous = self.trailPoints[#self.trailPoints - 1]
        self.trailSegments[#self.trailSegments + 1] = {
            x1 = previous.x,
            y1 = previous.y,
            x2 = x,
            y2 = y
        }
    end
end

function TrailBlazer:clearTrail()
    self.trailPoints = {}
    self.trailSegments = {}
    self:hideControlsHint()
    self:setStatus("Trail cleared")
    if self.trailDrawing then
        self:startTrailAtPlayer()
    end
end

function TrailBlazer:hideControlsHint()
    self.showControlsHint = false
end

function TrailBlazer:toggleTrailDrawing()
    self.trailDrawing = not self.trailDrawing
    if self.trailDrawing then
        self:startTrailAtPlayer()
    end
    self:hideControlsHint()
    self:setStatus(self.trailDrawing and "Trail on" or "Trail off")
end

function TrailBlazer:stepSpeed(direction)
    self.player.speed = PLAYER_DRIVE_SPEED
end

function TrailBlazer:updateSpeedInput(upHeld, downHeld)
    self.player.speed = PLAYER_DRIVE_SPEED
end

function TrailBlazer:applyCrank(change)
    if math.abs(change or 0) <= 0.01 then
        return
    end
    self.player.angle = self.player.angle + (change or 0)
end

function TrailBlazer:updateDriveInput(upHeld, downHeld, drawHeld)
    self.player.speed = PLAYER_DRIVE_SPEED
    if upHeld and not downHeld then
        self.driveDirection = 1
    elseif downHeld and not upHeld then
        self.driveDirection = -1
    else
        self.driveDirection = 0
    end

    local nextTrailDrawing = drawHeld == true
    if nextTrailDrawing and not self.trailDrawing then
        self.trailDrawing = true
        self:startTrailAtPlayer()
    elseif not nextTrailDrawing and self.trailDrawing then
        self.trailDrawing = false
        self.trailPoints = {}
    end
end

function TrailBlazer:resetLoadedBall()
    if self.loadedBall == nil then
        self.loadedBall = {
            radius = BALL_RADIUS
        }
    end
    self.loadedBall.x = self.player.x
    self.loadedBall.y = self.player.y
end

function TrailBlazer:getGravity()
    if self.preview then
        self.previewPhase = self.previewPhase + 0.02
        local gx = math.cos(self.previewPhase * 0.6) * 0.18
        local gy = 0.95 + (math.sin(self.previewPhase) * 0.2)
        return normalize(gx, gy, 0, 1)
    end

    local ax = 0
    local ay = 1
    if pd.accelerometerIsRunning() then
        local accelX, accelY = pd.readAccelerometer()
        if accelX ~= nil and accelY ~= nil then
            ax = accelX
            ay = accelY
        end
    end
    return normalize(ax, ay, 0, 1)
end

function TrailBlazer:getJerk(gravityX, gravityY)
    local jerkX = gravityX - self.lastAccelX
    local jerkY = gravityY - self.lastAccelY
    self.lastAccelX = gravityX
    self.lastAccelY = gravityY
    return jerkX, jerkY
end

function TrailBlazer:dropLoadedBall()
    if self.loadedBall == nil then
        return
    end
    if #self.balls >= MAX_ACTIVE_BALLS then
        self:setStatus("Ball limit reached")
        return
    end

    self.balls[#self.balls + 1] = {
        x = self.loadedBall.x,
        y = self.loadedBall.y,
        vx = 0,
        vy = 0,
        radius = self.loadedBall.radius,
        touchedBottom = false
    }
    self.loadedBall = nil
    self:hideControlsHint()
    self:setStatus("Ball dropped")
end

function TrailBlazer:handleDrop()
    if self.loadedBall == nil then
        return
    end
    self:dropLoadedBall()
end

function TrailBlazer:updatePlayer()
    local radians = math.rad(self.player.angle)
    local movementScale = self.preview and 1 or self.driveDirection
    self.player.x = self.player.x + (math.cos(radians) * self.player.speed * movementScale)
    self.player.y = self.player.y + (math.sin(radians) * self.player.speed * movementScale)

    if movementScale ~= 0 and self.player.x < -PLAYER_WRAP_MARGIN then
        self.player.x = self.width + PLAYER_WRAP_MARGIN
        if self.trailDrawing then
            self:startTrailAtPlayer()
        end
    elseif movementScale ~= 0 and self.player.x > self.width + PLAYER_WRAP_MARGIN then
        self.player.x = -PLAYER_WRAP_MARGIN
        if self.trailDrawing then
            self:startTrailAtPlayer()
        end
    end

    if movementScale ~= 0 and self.player.y < -PLAYER_WRAP_MARGIN then
        self.player.y = self.height + PLAYER_WRAP_MARGIN
        if self.trailDrawing then
            self:startTrailAtPlayer()
        end
    elseif movementScale ~= 0 and self.player.y > self.height + PLAYER_WRAP_MARGIN then
        self.player.y = -PLAYER_WRAP_MARGIN
        if self.trailDrawing then
            self:startTrailAtPlayer()
        end
    end

    if self.trailDrawing then
        self:addTrailPoint(self.player.x, self.player.y)
    end

    if self.loadedBall ~= nil then
        self.loadedBall.x = self.player.x
        self.loadedBall.y = self.player.y
    end
end

function TrailBlazer:resolveSegmentCollision(ball, gravityX, gravityY, segment)
    local closestX, closestY = closestPointOnSegment(ball.x, ball.y, segment.x1, segment.y1, segment.x2, segment.y2)
    local offsetX = ball.x - closestX
    local offsetY = ball.y - closestY
    local distance = magnitude(offsetX, offsetY)
    if distance >= ball.radius or distance <= 0.0001 then
        if distance > ball.radius then
            return false
        end
        offsetX = -gravityX
        offsetY = -gravityY
        distance = math.max(0.0001, magnitude(offsetX, offsetY))
    end

    local normalX = offsetX / distance
    local normalY = offsetY / distance
    local penetration = ball.radius - distance
    ball.x = ball.x + (normalX * penetration)
    ball.y = ball.y + (normalY * penetration)

    local tangentX = -normalY
    local tangentY = normalX
    local normalVelocity = (ball.vx * normalX) + (ball.vy * normalY)
    local tangentVelocity = (ball.vx * tangentX) + (ball.vy * tangentY)
    if normalVelocity < 0 then
        normalVelocity = -normalVelocity * BALL_NORMAL_BOUNCE
    else
        normalVelocity = math.min(normalVelocity, 0.2)
    end

    tangentVelocity = tangentVelocity * BALL_TRAIL_FRICTION
    ball.vx = (normalX * normalVelocity) + (tangentX * tangentVelocity)
    ball.vy = (normalY * normalVelocity) + (tangentY * tangentVelocity)
    return true
end

function TrailBlazer:resolveBottomCollision(ball)
    local floorY = self.height - ball.radius - FLOOR_Y_OFFSET
    if ball.y < floorY then
        return false
    end

    ball.y = floorY
    if ball.vy > 0 then
        ball.vy = 0
    end
    ball.vx = ball.vx * BALL_GROUND_FRICTION
    ball.touchedBottom = true
    return true
end

function TrailBlazer:canSpawnLoadedBall()
    if self.loadedBall ~= nil then
        return false
    end
    if #self.balls >= MAX_ACTIVE_BALLS then
        return false
    end

    local respawnRadiusSquared = BALL_RESPAWN_RADIUS * BALL_RESPAWN_RADIUS
    for _, ball in ipairs(self.balls) do
        if distanceSquared(ball.x, ball.y, self.player.x, self.player.y) <= respawnRadiusSquared then
            return false
        end
    end
    return true
end

function TrailBlazer:updateLoadedBallAvailability()
    if self:canSpawnLoadedBall() then
        self:resetLoadedBall()
        self:setStatus("New ball loaded")
    end
end

function TrailBlazer:updateBalls()
    local gravityX, gravityY = self:getGravity()
    local jerkX, jerkY = self:getJerk(gravityX, gravityY)

    for index = #self.balls, 1, -1 do
        local ball = self.balls[index]
        for _ = 1, BALL_SUBSTEPS do
            ball.vx = clamp(ball.vx + ((gravityX * BALL_GRAVITY) + (jerkX * BALL_JERK_SCALE)), -BALL_MAX_SPEED, BALL_MAX_SPEED)
            ball.vy = clamp(ball.vy + ((gravityY * BALL_GRAVITY) + (jerkY * BALL_JERK_SCALE)), -BALL_MAX_SPEED, BALL_MAX_SPEED)
            ball.x = ball.x + (ball.vx / BALL_SUBSTEPS)
            ball.y = ball.y + (ball.vy / BALL_SUBSTEPS)

            for _, segment in ipairs(self.trailSegments) do
                self:resolveSegmentCollision(ball, gravityX, gravityY, segment)
            end
            self:resolveBottomCollision(ball)
        end

        if ball.x < -ball.radius or ball.x > self.width + ball.radius then
            table.remove(self.balls, index)
        end
    end
end

function TrailBlazer:updatePreview()
    self.player.angle = self.player.angle + 1.6
    if self.frame % 150 == 0 then
        if not self.trailDrawing then
            self.trailDrawing = true
            self:startTrailAtPlayer()
        elseif self.loadedBall ~= nil then
            self:dropLoadedBall()
        end
    end
    if self.frame % 240 == 0 then
        self:clearTrail()
        self.trailDrawing = true
        self:startTrailAtPlayer()
    end
end

function TrailBlazer:update()
    self.frame = self.frame + 1

    if self.preview then
        self:updatePreview()
    end

    self:updatePlayer()
    self:updateBalls()
    if not self.preview then
        self:updateLoadedBallAvailability()
    end

    if self.statusFrames > 0 then
        self.statusFrames = self.statusFrames - 1
        if self.statusFrames <= 0 then
            self.statusMessage = nil
        end
    end
end

function TrailBlazer:drawTrail()
    for _, segment in ipairs(self.trailSegments) do
        gfx.drawLine(segment.x1, segment.y1, segment.x2, segment.y2)
    end
end

function TrailBlazer:drawBallShell(x, y, radius, withCenterDot)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(x, y, radius)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawCircleAtPoint(x, y, radius)
    if withCenterDot then
        gfx.fillCircleAtPoint(x, y, PLAYER_DOT_RADIUS)
    end
    gfx.setColor(gfx.kColorWhite)
end

function TrailBlazer:drawMenu()
    if not self.menuOpen or self.preview then
        return
    end

    local items = self:getMenuItems()
    local height = 22 + (#items * MENU_ROW_HEIGHT) + 8

    gfx.setColor(gfx.kColorWhite)
    gfx.setDitherPattern(0.15, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRoundRect(MENU_X, MENU_Y, MENU_WIDTH, height, 8)
    gfx.setDitherPattern(1, gfx.image.kDitherTypeBayer8x8)
    gfx.drawRoundRect(MENU_X, MENU_Y, MENU_WIDTH, height, 8)
    gfx.drawText("Flow Settings", MENU_X + 10, MENU_Y + 6)

    for index, item in ipairs(items) do
        local rowY = MENU_Y + 24 + ((index - 1) * MENU_ROW_HEIGHT)
        if index == self.menuIndex then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(MENU_X + 6, rowY - 1, MENU_WIDTH - 12, MENU_ROW_HEIGHT - 2)
            gfx.setColor(gfx.kColorWhite)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        else
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
        end

        if item.kind == "toggle" then
            local marker = item.checked and "[x]" or "[ ]"
            gfx.drawText(marker .. " " .. item.label, MENU_X + 12, rowY + 2)
        else
            gfx.drawText(item.label, MENU_X + 12, rowY + 2)
        end
    end

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function TrailBlazer:draw()
    gfx.clear(gfx.kColorBlack)
    gfx.setColor(gfx.kColorWhite)

    self:drawTrail()
    gfx.drawLine(0, self.height - FLOOR_Y_OFFSET, self.width, self.height - FLOOR_Y_OFFSET)

    for _, ball in ipairs(self.balls) do
        self:drawBallShell(ball.x, ball.y, ball.radius, false)
    end

    self:drawBallShell(self.player.x, self.player.y, PLAYER_RADIUS, true)
    if self.loadedBall ~= nil then
        self:drawBallShell(self.loadedBall.x, self.loadedBall.y, self.loadedBall.radius, true)
    end

    if not self.preview and not self.pauseHudHidden and not self.hudHidden then
        gfx.setImageDrawMode(gfx.kDrawModeInverted)
        gfx.drawText(
            string.format(
                "Mode %s  Speed %.1f  Trail %s  Balls %d/%d",
                TrailBlazer.getModeLabel(self.modeId),
                self.player.speed,
                self.trailDrawing and "on" or "off",
                #self.balls,
                MAX_ACTIVE_BALLS
            ),
            10,
            8
        )
        if self.showControlsHint then
            gfx.drawTextInRect(self.instructionText, 10, 206, 380, 28)
        end
        if self.statusMessage ~= nil then
            gfx.drawTextAligned(self.statusMessage, 200, 24, kTextAlignment.center)
        end
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end

    self:drawMenu()
end
