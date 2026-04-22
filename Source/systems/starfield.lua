import "gameconfig"

--[[
Warp Speed and Star Fall background effect system.

Purpose:
- simulates forward warp tunnels and directional falling-star fields
- supports standard and inverse palette modes
- exposes speed, steering, and rotation controls for previews and live views
]]
local gfx <const> = playdate.graphics
local WARP_CONFIG <const> = GameConfig and GameConfig.warp or {}
local STAR_FALL_CONFIG <const> = GameConfig and GameConfig.starFall or {}

Starfield = {}
Starfield.__index = Starfield

Starfield.MODE_STANDARD = "standard"
Starfield.MODE_INVERSE = "inverse"

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function roundToTenth(value)
    if value >= 0 then
        return math.floor((value * 10) + 0.5) / 10
    end
    return math.ceil((value * 10) - 0.5) / 10
end

local function degreesToRadians(value)
    return value * math.pi / 180
end

local function normalizeAngleDegrees(value)
    while value <= -180 do
        value = value + 360
    end
    while value > 180 do
        value = value - 360
    end
    return value
end

local function vectorFromAngle(angleDegrees)
    local radians = degreesToRadians(angleDegrees)
    return math.cos(radians), math.sin(radians)
end

local function rotatePoint(x, y, angleDegrees)
    if angleDegrees == 0 then
        return x, y
    end

    local radians = degreesToRadians(angleDegrees)
    local cosine = math.cos(radians)
    local sine = math.sin(radians)
    return (x * cosine) - (y * sine), (x * sine) + (y * cosine)
end

local function rotatePointWithTrig(x, y, cosine, sine)
    return (x * cosine) - (y * sine), (x * sine) + (y * cosine)
end

local function rotateAroundPoint(x, y, centerX, centerY, cosine, sine)
    local rx, ry = rotatePointWithTrig(x - centerX, y - centerY, cosine, sine)
    return centerX + rx, centerY + ry
end

local function distanceSquaredToSegment(px, py, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local lengthSquared = (dx * dx) + (dy * dy)

    if lengthSquared <= 0.0001 then
        local offsetX = px - x1
        local offsetY = py - y1
        return (offsetX * offsetX) + (offsetY * offsetY)
    end

    local projection = ((px - x1) * dx) + ((py - y1) * dy)
    local t = clamp(projection / lengthSquared, 0, 1)
    local closestX = x1 + (dx * t)
    local closestY = y1 + (dy * t)
    local offsetX = px - closestX
    local offsetY = py - closestY
    return (offsetX * offsetX) + (offsetY * offsetY)
end

local STAR_FALL_BOUNDARY_RADIUS <const> = STAR_FALL_CONFIG.boundaryRadius or 467
local STAR_FALL_LARGE_STAR_MIN_DELAY_FRAMES <const> = STAR_FALL_CONFIG.largeStarMinDelayFrames or 300
local STAR_FALL_LARGE_STAR_MAX_DELAY_FRAMES <const> = STAR_FALL_CONFIG.largeStarMaxDelayFrames or 1800
local STAR_FALL_LARGE_STAR_MIN_RADIUS <const> = STAR_FALL_CONFIG.largeStarMinRadius or 10
local STAR_FALL_LARGE_STAR_MAX_RADIUS <const> = STAR_FALL_CONFIG.largeStarMaxRadius or 16
local WARP_SPAWN_RADIUS <const> = WARP_CONFIG.spawnRadius or 467
local WARP_VISIBLE_RADIUS <const> = WARP_CONFIG.visibleRadius or 234
local WARP_OFFSCREEN_RADIUS <const> = WARP_VISIBLE_RADIUS + 40
local WARP_OFFSCREEN_RADIUS_SQUARED <const> = WARP_OFFSCREEN_RADIUS * WARP_OFFSCREEN_RADIUS
local WARP_CENTER_DESPAWN_RADIUS <const> = WARP_CONFIG.centerDespawnRadius or 10
local WARP_SPAWN_FADE_IN_FRAMES <const> = WARP_CONFIG.spawnFadeFrames or 8
local WARP_INWARD_DESPAWN_START_RADIUS_MIN <const> = WARP_CONFIG.inwardDespawnStartRadiusMin or 2
local WARP_INWARD_DESPAWN_START_RADIUS_MAX <const> = WARP_CONFIG.inwardDespawnStartRadiusMax or 5
local WARP_INWARD_DESPAWN_GROWTH_MIN <const> = WARP_CONFIG.inwardDespawnGrowthMin or 0.08
local WARP_INWARD_DESPAWN_GROWTH_MAX <const> = WARP_CONFIG.inwardDespawnGrowthMax or 0.22
local WARP_FADE_DEBUG_INTERVAL_FRAMES <const> = WARP_CONFIG.fadeDebugIntervalFrames or 45
local WARP_TRAIL_DOT_MAX_STEPS <const> = WARP_CONFIG.trailDotMaxSteps or 5
local WARP_TAPER_HIDE_SPEED_START <const> = WARP_CONFIG.taperHideSpeedStart or 1.2
local WARP_TAPER_HIDE_SPEED_END <const> = WARP_CONFIG.taperHideSpeedEnd or 3.2
local WARP_STAR_SIZE_PERCENT_MIN <const> = WARP_CONFIG.starSizePercentMin or -80
local WARP_STAR_SIZE_PERCENT_MAX <const> = WARP_CONFIG.starSizePercentMax or 200
local WARP_STAR_SIZE_PERCENT_STEP <const> = WARP_CONFIG.starSizePercentStep or 10

local function randomLargeStarDelayFrames()
    return math.random(STAR_FALL_LARGE_STAR_MIN_DELAY_FRAMES, STAR_FALL_LARGE_STAR_MAX_DELAY_FRAMES)
end

function Starfield.getModeLabel(modeId, kind)
    if kind == "fall" then
        if modeId == Starfield.MODE_INVERSE then
            return "Inverse Fall"
        end
        return "Star Fall"
    end

    if modeId == Starfield.MODE_INVERSE then
        return "Inverse Warp"
    end
    return "Warp Speed"
end

local function applyOptions(self, options)
    self.modeId = options and options.modeId or Starfield.MODE_STANDARD
    self.inverse = self.modeId == Starfield.MODE_INVERSE
    self.warpStyleStarTrail = options and options.warpStyleStarTrail == true or false
    self.warpStyleTaper = options and options.warpStyleTaper == true or false
    self.warpStyleStarFall = options and options.warpStyleStarFall == true or false
end

function Starfield.newStarFall(width, height, count, options)
    local self = setmetatable({}, Starfield)
    self.kind = "fall"
    applyOptions(self, options)
    self.width = width
    self.height = height
    self.centerX = width / 2
    self.centerY = height / 2
    self.playerCenterX = self.centerX
    self.playerCenterY = self.centerY
    self.directionAngle = 90
    self.screenAngle = 0
    self.screenAngleRadians = 0
    self.screenCos = 1
    self.screenSin = 0
    self.speed = 1.0
    self.stars = {}
    self.largeFallStar = nil
    self.largeFallStarTimer = randomLargeStarDelayFrames()

    for i = 1, count do
        self.stars[i] = {
            x = 0,
            y = 0,
            px = 0,
            py = 0,
            size = math.random(2, 5),
            speed = 0.4 + math.random() * 1.4
        }
        self:spawnFallStar(self.stars[i], true)
    end

    return self
end

function Starfield.newWarpSpeed(width, height, count, options)
    local self = setmetatable({}, Starfield)
    self.kind = "warp"
    applyOptions(self, options)
    self.width = width
    self.height = height
    self.centerX = width / 2
    self.centerY = height / 2
    self.playerCenterX = self.centerX
    self.playerCenterY = self.centerY
    self.directionAngle = 0
    self.screenAngle = 0
    self.screenAngleRadians = 0
    self.screenCos = 1
    self.screenSin = 0
    self.speed = 1.0
    self.lastSpeed = self.speed
    self.stars = {}
    self.debugFadeFrameCounter = 0
    self.starSizePercent = options and options.starSizePercent or 0

    for i = 1, count do
        self.stars[i] = {
            x = 0,
            y = 0,
            px = 0,
            py = 0,
            despawnRadius = 0,
            despawnGrowth = 0,
            spawnFadeFrames = WARP_SPAWN_FADE_IN_FRAMES,
            speed = 0.3 + math.random() * 0.9,
            size = math.random(1, 2)
        }
        self:seedWarpStar(self.stars[i], i, count)
    end

    return self
end

function Starfield:getBackgroundColor()
    if self.inverse then
        return gfx.kColorWhite
    end
    return gfx.kColorBlack
end

function Starfield:getForegroundColor()
    if self.inverse then
        return gfx.kColorBlack
    end
    return gfx.kColorWhite
end

function Starfield:isWarpStyleEnabled(optionId)
    if optionId == "trailDots" then
        return self.warpStyleStarTrail == true
    elseif optionId == "triangleTaper" then
        return self.warpStyleTaper == true
    elseif optionId == "starFallStyle" then
        return self.warpStyleStarFall == true
    end
    return false
end

function Starfield:setWarpStyleEnabled(optionId, enabled)
    local value = enabled == true
    if optionId == "trailDots" then
        self.warpStyleStarTrail = value
    elseif optionId == "triangleTaper" then
        self.warpStyleTaper = value
    elseif optionId == "starFallStyle" then
        self.warpStyleStarFall = value
    end
end

function Starfield:toggleWarpStyle(optionId)
    self:setWarpStyleEnabled(optionId, not self:isWarpStyleEnabled(optionId))
end

function Starfield:getWarpStarSizePercent()
    return self.starSizePercent or 0
end

function Starfield:getWarpDisplayedSize(baseSize)
    local scale = 1 + ((self:getWarpStarSizePercent()) / 100)
    return math.max(1, math.floor((baseSize * scale) + 0.5))
end

function Starfield:refreshWarpStarSizes()
    if self.kind ~= "warp" then
        return
    end

    for _, star in ipairs(self.stars) do
        local baseSize = star.baseSize or star.size or 1
        star.baseSize = baseSize
        star.size = self:getWarpDisplayedSize(baseSize)
    end
end

function Starfield:stepWarpStarSizePercent(direction)
    if self.kind ~= "warp" or direction == 0 then
        return
    end

    self.starSizePercent = clamp(
        (self.starSizePercent or 0) + (direction * WARP_STAR_SIZE_PERCENT_STEP),
        WARP_STAR_SIZE_PERCENT_MIN,
        WARP_STAR_SIZE_PERCENT_MAX
    )
    self:refreshWarpStarSizes()
    StarryLog.info("warp star size percent changed: %d", self.starSizePercent)
end

function Starfield:assignWarpStarVisuals(star)
    star.speed = 0.25 + (math.random() * 1.15)
    local normalizedSpeed = clamp((star.speed - 0.25) / 1.15, 0, 1)
    star.baseSize = 1 + math.floor(normalizedSpeed * 3.2)
    star.size = self:getWarpDisplayedSize(star.baseSize)
end

function Starfield:stepSpeed(direction)
    if direction == 0 then
        return
    end

    if self.speed > 1 then
        self.speed = self.speed + direction
    elseif self.speed < -1 then
        self.speed = self.speed + direction
    else
        local nextSpeed = roundToTenth(self.speed + (direction * 0.1))
        if nextSpeed > 1 then
            self.speed = 2
        elseif nextSpeed < -1 then
            self.speed = -2
        else
            self.speed = nextSpeed
        end
    end

    StarryLog.info("%s speed changed: %.2f", self.kind, self.speed)
end

function Starfield:adjustDirection(deltaDegrees, logChange)
    if deltaDegrees == 0 then
        return
    end

    self.directionAngle = self.directionAngle + deltaDegrees
    if logChange ~= false then
        StarryLog.info("%s direction changed: %.2f", self.kind, self.directionAngle)
    end
end

function Starfield:rotateDirection(deltaDegrees)
    self:adjustDirection(deltaDegrees, true)
end

function Starfield:steerDirectionToward(deltaX, deltaY, maxStepDegrees)
    if (deltaX == 0 and deltaY == 0) or maxStepDegrees <= 0 then
        return false
    end

    local targetAngle = math.deg(math.atan(deltaY, deltaX))
    local angleDelta = normalizeAngleDegrees(targetAngle - self.directionAngle)
    if math.abs(angleDelta) <= 0.01 then
        return false
    end

    local appliedStep = clamp(angleDelta, -maxStepDegrees, maxStepDegrees)
    self:adjustDirection(appliedStep, false)
    return true
end

function Starfield:rotateScreen(deltaDegrees)
    self.screenAngle = self.screenAngle + deltaDegrees
    self.screenAngleRadians = degreesToRadians(self.screenAngle)
    self.screenCos = math.cos(self.screenAngleRadians)
    self.screenSin = math.sin(self.screenAngleRadians)
    StarryLog.info("%s screen rotation changed: %.2f", self.kind, self.screenAngle)
end

function Starfield:rotateField(deltaDegrees)
    if deltaDegrees == 0 then
        return
    end

    local radians = degreesToRadians(deltaDegrees)
    local cosine = math.cos(radians)
    local sine = math.sin(radians)
    local oldPlayerCenterX = self.playerCenterX
    local oldPlayerCenterY = self.playerCenterY

    self.playerCenterX, self.playerCenterY = rotateAroundPoint(
        oldPlayerCenterX,
        oldPlayerCenterY,
        self.centerX,
        self.centerY,
        cosine,
        sine
    )

    for _, star in ipairs(self.stars) do
        if self.kind == "warp" then
            local worldX = oldPlayerCenterX + star.x
            local worldY = oldPlayerCenterY + star.y
            local prevWorldX = oldPlayerCenterX + star.px
            local prevWorldY = oldPlayerCenterY + star.py

            worldX, worldY = rotateAroundPoint(worldX, worldY, self.centerX, self.centerY, cosine, sine)
            prevWorldX, prevWorldY = rotateAroundPoint(prevWorldX, prevWorldY, self.centerX, self.centerY, cosine, sine)

            star.x = worldX - self.playerCenterX
            star.y = worldY - self.playerCenterY
            star.px = prevWorldX - self.playerCenterX
            star.py = prevWorldY - self.playerCenterY
        else
            star.x, star.y = rotateAroundPoint(star.x, star.y, self.centerX, self.centerY, cosine, sine)
            star.px, star.py = rotateAroundPoint(star.px, star.py, self.centerX, self.centerY, cosine, sine)
        end
    end

    self:adjustDirection(deltaDegrees, false)
    StarryLog.info("%s field rotation changed: %.2f", self.kind, self.directionAngle)
end

function Starfield:movePerspective(deltaX, deltaY)
    self.playerCenterX = clamp(self.playerCenterX + deltaX, -100, self.width + 100)
    self.playerCenterY = clamp(self.playerCenterY + deltaY, -100, self.height + 100)
end

function Starfield:spawnFallStar(star, randomizeInsideScreen)
    star.size = math.random(2, 5)
    star.speed = 0.4 + math.random() * 1.4

    if randomizeInsideScreen then
        local angle = math.random() * (math.pi * 2)
        local radius = math.sqrt(math.random()) * STAR_FALL_BOUNDARY_RADIUS
        local screenX = self.centerX + (math.cos(angle) * radius)
        local screenY = self.centerY + (math.sin(angle) * radius)
        local worldX, worldY = self:screenToWorld(screenX, screenY)
        star.x = worldX
        star.y = worldY
        star.px = worldX
        star.py = worldY
        return
    end

    local dx, dy = vectorFromAngle(self.directionAngle)
    local speedSign = self.speed < 0 and -1 or 1
    local screenDx, screenDy = rotatePointWithTrig(dx * speedSign, dy * speedSign, self.screenCos, self.screenSin)
    local baseAngle = math.atan(screenDy, screenDx) + math.pi
    local angle = baseAngle - (math.pi / 2) + (math.random() * math.pi)
    local screenX = self.centerX + (math.cos(angle) * STAR_FALL_BOUNDARY_RADIUS)
    local screenY = self.centerY + (math.sin(angle) * STAR_FALL_BOUNDARY_RADIUS)

    local worldX, worldY = self:screenToWorld(screenX, screenY)
    star.x = worldX
    star.y = worldY
    star.px = worldX
    star.py = worldY
end

function Starfield:spawnLargeFallStar(randomizeInsideScreen)
    local star = self.largeFallStar or {}
    star.size = math.random(STAR_FALL_LARGE_STAR_MIN_RADIUS, STAR_FALL_LARGE_STAR_MAX_RADIUS)
    star.speed = 0.18 + (math.random() * 0.35)

    if randomizeInsideScreen then
        local angle = math.random() * (math.pi * 2)
        local radius = math.sqrt(math.random()) * STAR_FALL_BOUNDARY_RADIUS
        local screenX = self.centerX + (math.cos(angle) * radius)
        local screenY = self.centerY + (math.sin(angle) * radius)
        local worldX, worldY = self:screenToWorld(screenX, screenY)
        star.x = worldX
        star.y = worldY
        star.px = worldX
        star.py = worldY
        self.largeFallStar = star
        return
    end

    local dx, dy = vectorFromAngle(self.directionAngle)
    local speedSign = self.speed < 0 and -1 or 1
    local screenDx, screenDy = rotatePointWithTrig(dx * speedSign, dy * speedSign, self.screenCos, self.screenSin)
    local baseAngle = math.atan(screenDy, screenDx) + math.pi
    local angle = baseAngle - (math.pi / 2) + (math.random() * math.pi)
    local screenX = self.centerX + (math.cos(angle) * STAR_FALL_BOUNDARY_RADIUS)
    local screenY = self.centerY + (math.sin(angle) * STAR_FALL_BOUNDARY_RADIUS)
    local worldX, worldY = self:screenToWorld(screenX, screenY)
    star.x = worldX
    star.y = worldY
    star.px = worldX
    star.py = worldY
    self.largeFallStar = star
end

function Starfield:spawnWarpStar(star, spawnAtEdge)
    self:assignWarpStarVisuals(star)
    star.despawnGrowth = WARP_INWARD_DESPAWN_GROWTH_MIN + (math.random() * (WARP_INWARD_DESPAWN_GROWTH_MAX - WARP_INWARD_DESPAWN_GROWTH_MIN))
    star.spawnFadeFrames = WARP_SPAWN_FADE_IN_FRAMES

    if spawnAtEdge then
        if self.speed < 0 then
            local angle = math.random() * (math.pi * 2)
            local useCircumference = math.random() < 0.75
            local radius = useCircumference and WARP_SPAWN_RADIUS or (math.sqrt(math.random()) * WARP_SPAWN_RADIUS)
            local screenX = self.centerX + (math.cos(angle) * radius)
            local screenY = self.centerY + (math.sin(angle) * radius)
            local worldX, worldY = self:screenToWorld(screenX, screenY)
            star.x = worldX - self.playerCenterX
            star.y = worldY - self.playerCenterY
            star.despawnRadius = WARP_INWARD_DESPAWN_START_RADIUS_MIN + (math.random() * (WARP_INWARD_DESPAWN_START_RADIUS_MAX - WARP_INWARD_DESPAWN_START_RADIUS_MIN))
        else
            star.x = (math.random() * self.width) - self.playerCenterX
            star.y = (math.random() * self.height) - self.playerCenterY
            star.despawnRadius = 0
        end
    else
        if self.speed < 0 then
            star.x = (math.random() * 18) - 9
            star.y = (math.random() * 18) - 9
            star.despawnRadius = WARP_INWARD_DESPAWN_START_RADIUS_MIN + (math.random() * (WARP_INWARD_DESPAWN_START_RADIUS_MAX - WARP_INWARD_DESPAWN_START_RADIUS_MIN))
        else
            star.x = (math.random() * self.width) - self.playerCenterX
            star.y = (math.random() * self.height) - self.playerCenterY
            star.despawnRadius = 0
        end
    end

    star.px = star.x
    star.py = star.y
    self:updateWarpStarScreenCache(star)
end

function Starfield:refreshWarpFieldForDirection()
    if self.kind ~= "warp" then
        return
    end

    for _, star in ipairs(self.stars) do
        if self.speed < 0 then
            self:spawnWarpStar(star, true)
        else
            self:spawnWarpStar(star, false)
        end
    end

    StarryLog.info("warp field refreshed for speed %.2f", self.speed)
end

function Starfield:seedWarpStar(star, index, totalCount)
    self:assignWarpStarVisuals(star)
    star.despawnRadius = 0
    star.despawnGrowth = 0
    star.spawnFadeFrames = WARP_SPAWN_FADE_IN_FRAMES
    local columns = math.max(1, math.floor(math.sqrt(totalCount * (self.width / self.height))))
    local rows = math.max(1, math.ceil(totalCount / columns))
    local cellWidth = self.width / columns
    local cellHeight = self.height / rows
    local slot = index - 1
    local column = slot % columns
    local row = math.floor(slot / columns)
    local x = (column * cellWidth) + (math.random() * cellWidth)
    local y = (row * cellHeight) + (math.random() * cellHeight)
    star.x = x - self.playerCenterX
    star.y = y - self.playerCenterY

    star.px = star.x
    star.py = star.y
    self:updateWarpStarScreenCache(star)
end

function Starfield:transformPoint(x, y)
    local rx, ry = rotatePointWithTrig(x - self.centerX, y - self.centerY, self.screenCos, self.screenSin)
    return self.centerX + rx, self.centerY + ry
end

function Starfield:screenToWorld(x, y)
    local rx, ry = rotatePointWithTrig(x - self.centerX, y - self.centerY, self.screenCos, -self.screenSin)
    return self.centerX + rx, self.centerY + ry
end

function Starfield:isOutsideScreen(x, y, margin)
    return x < -margin or x > self.width + margin or y < -margin or y > self.height + margin
end

function Starfield:warpStarTouchesCenterZone(star)
    local zoneRadius = WARP_CENTER_DESPAWN_RADIUS
    if self.speed < 0 and star.despawnRadius > 0 then
        zoneRadius = star.despawnRadius
    end
    local effectiveRadius = zoneRadius + math.max(1, star.size)
    local effectiveRadiusSquared = effectiveRadius * effectiveRadius
    local x1 = (self.playerCenterX + star.px) - self.centerX
    local y1 = (self.playerCenterY + star.py) - self.centerY
    local x2 = (self.playerCenterX + star.x) - self.centerX
    local y2 = (self.playerCenterY + star.y) - self.centerY

    local currentDistanceSquared = (x2 * x2) + (y2 * y2)
    if currentDistanceSquared <= effectiveRadiusSquared then
        return true
    end

    local previousDistanceSquared = (x1 * x1) + (y1 * y1)
    if previousDistanceSquared <= effectiveRadiusSquared then
        return true
    end

    if (x1 > effectiveRadius and x2 > effectiveRadius)
        or (x1 < -effectiveRadius and x2 < -effectiveRadius)
        or (y1 > effectiveRadius and y2 > effectiveRadius)
        or (y1 < -effectiveRadius and y2 < -effectiveRadius) then
        return false
    end

    local distanceSquared = distanceSquaredToSegment(0, 0, x1, y1, x2, y2)
    return distanceSquared <= effectiveRadiusSquared
end

function Starfield:updateWarpStarScreenCache(star)
    local prevWorldX = self.playerCenterX + star.px
    local prevWorldY = self.playerCenterY + star.py
    local worldX = self.playerCenterX + star.x
    local worldY = self.playerCenterY + star.y

    if self.screenAngle == 0 then
        star.sx1 = prevWorldX
        star.sy1 = prevWorldY
        star.sx2 = worldX
        star.sy2 = worldY
        return
    end

    local px = prevWorldX - self.centerX
    local py = prevWorldY - self.centerY
    local x = worldX - self.centerX
    local y = worldY - self.centerY
    local prevX, prevY = rotatePointWithTrig(px, py, self.screenCos, self.screenSin)
    local nextX, nextY = rotatePointWithTrig(x, y, self.screenCos, self.screenSin)

    star.sx1 = self.centerX + prevX
    star.sy1 = self.centerY + prevY
    star.sx2 = self.centerX + nextX
    star.sy2 = self.centerY + nextY
end

function Starfield:getWarpStarFade(star)
    if star.spawnFadeFrames and star.spawnFadeFrames > 0 then
        local spawnFade = 1 - (star.spawnFadeFrames / WARP_SPAWN_FADE_IN_FRAMES)
        return clamp(spawnFade, 0, 1)
    end

    return 1
end

function Starfield:drawMotionStarShape(x1, y1, x2, y2, size)
    local dx = x2 - x1
    local dy = y2 - y1
    local absDx = math.abs(dx)
    local absDy = math.abs(dy)
    local lengthApprox = absDx + absDy
    local isHorizontal = absDx >= absDy

    if lengthApprox <= size then
        gfx.fillRect(x2 - math.floor(size / 2), y2 - math.floor(size / 2), size, size)
    elseif size <= 1 then
        gfx.drawLine(x1, y1, x2, y2)
        gfx.fillRect(x2, y2, 1, 1)
    elseif size == 2 then
        if isHorizontal then
            gfx.drawLine(x1, y1, x2, y2)
            gfx.drawLine(x1, y1 + 1, x2, y2 + 1)
        else
            gfx.drawLine(x1, y1, x2, y2)
            gfx.drawLine(x1 + 1, y1, x2 + 1, y2)
        end
        gfx.fillRect(x2 - 1, y2 - 1, 2, 2)
    else
        if isHorizontal then
            gfx.drawLine(x1, y1 - 1, x2, y2 - 1)
            gfx.drawLine(x1, y1, x2, y2)
            gfx.drawLine(x1, y1 + 1, x2, y2 + 1)
        else
            gfx.drawLine(x1 - 1, y1, x2 - 1, y2)
            gfx.drawLine(x1, y1, x2, y2)
            gfx.drawLine(x1 + 1, y1, x2 + 1, y2)
        end
        gfx.fillRect(x2 - 1, y2 - 1, 3, 3)
    end
end

function Starfield:drawWarpTrailDots(star, unitX, unitY, length)
    if length <= 0.5 then
        return
    end

    local speedFactor = clamp((math.abs(self.speed or 0) - 1) / 4, 0, 1)
    if speedFactor <= 0 then
        return
    end

    local steps = math.max(1, math.min(WARP_TRAIL_DOT_MAX_STEPS, math.floor((length / 4) + (speedFactor * 3))))
    local stepDistance = math.max(2, (length / steps))

    for i = 1, steps do
        local trailScale = 1 - (i / (steps + 1))
        local dotSize = math.max(1, math.floor((star.size * trailScale) + 0.5))
        local trailDistance = stepDistance * i
        local x = star.sx2 - (unitX * trailDistance)
        local y = star.sy2 - (unitY * trailDistance)
        gfx.fillRect(
            math.floor(x - (dotSize / 2)),
            math.floor(y - (dotSize / 2)),
            dotSize,
            dotSize
        )
    end
end

function Starfield:drawWarpTriangleTaper(star, unitX, unitY, length)
    if length <= 0.5 then
        return
    end

    local absSpeed = math.abs(self.speed or 0)
    local visibility = 1
    if absSpeed > WARP_TAPER_HIDE_SPEED_START then
        visibility = 1 - ((absSpeed - WARP_TAPER_HIDE_SPEED_START) / (WARP_TAPER_HIDE_SPEED_END - WARP_TAPER_HIDE_SPEED_START))
    end
    visibility = clamp(visibility, 0, 1)
    if visibility <= 0 then
        return
    end

    local taperLength = math.max(2, length * (0.55 + visibility))
    local tailX = star.sx2 - (unitX * (taperLength + star.size))
    local tailY = star.sy2 - (unitY * (taperLength + star.size))
    local normalX = -unitY
    local normalY = unitX
    local baseHalfWidth = math.max(1, (star.size * 0.5) + (2 * visibility))
    local leftX = star.sx2 + (normalX * baseHalfWidth)
    local leftY = star.sy2 + (normalY * baseHalfWidth)
    local rightX = star.sx2 - (normalX * baseHalfWidth)
    local rightY = star.sy2 - (normalY * baseHalfWidth)

    gfx.fillTriangle(leftX, leftY, rightX, rightY, tailX, tailY)
end

function Starfield:drawWarpHead(star)
    if self.warpStyleStarFall then
        self:drawMotionStarShape(star.sx1, star.sy1, star.sx2, star.sy2, star.size)
        return
    end

    if self.warpStyleTaper then
        gfx.fillCircleAtPoint(star.sx2, star.sy2, math.max(1, math.floor(star.size * 0.5)))
        return
    end

    gfx.fillRect(star.sx2, star.sy2, star.size, star.size)
end

function Starfield:drawWarpHeadScaled(star, scale)
    local visibleSize = math.max(1, math.floor((star.size * scale) + 0.5))
    local offset = math.floor(visibleSize * 0.5)

    if self.warpStyleStarFall then
        self:drawMotionStarShape(star.sx1, star.sy1, star.sx2, star.sy2, visibleSize)
        return
    end

    if self.warpStyleTaper then
        gfx.fillCircleAtPoint(star.sx2, star.sy2, math.max(1, math.floor(visibleSize * 0.5)))
        return
    end

    gfx.fillRect(star.sx2 - offset, star.sy2 - offset, visibleSize, visibleSize)
end

function Starfield:drawWarpStreak(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local horizontalBias = math.abs(dx) >= math.abs(dy)
    local streakThickness = 2

    if math.abs(self.speed or 0) >= 12 then
        streakThickness = 3
    end

    if streakThickness == 2 then
        if horizontalBias then
            gfx.drawLine(x1, y1, x2, y2)
            gfx.drawLine(x1, y1 + 1, x2, y2 + 1)
        else
            gfx.drawLine(x1, y1, x2, y2)
            gfx.drawLine(x1 + 1, y1, x2 + 1, y2)
        end
        return
    end

    if horizontalBias then
        gfx.drawLine(x1, y1 - 1, x2, y2 - 1)
        gfx.drawLine(x1, y1, x2, y2)
        gfx.drawLine(x1, y1 + 1, x2, y2 + 1)
    else
        gfx.drawLine(x1 - 1, y1, x2 - 1, y2)
        gfx.drawLine(x1, y1, x2, y2)
        gfx.drawLine(x1 + 1, y1, x2 + 1, y2)
    end
end

function Starfield:updateStarFall()
    local dx, dy = vectorFromAngle(self.directionAngle)
    local scale = self.speed * 1.3
    local screenCos = self.screenCos
    local screenSin = self.screenSin
    local speedSign = self.speed < 0 and -1 or 1
    local screenDx, screenDy = rotatePointWithTrig(dx * speedSign, dy * speedSign, screenCos, screenSin)
    local boundarySquared = STAR_FALL_BOUNDARY_RADIUS * STAR_FALL_BOUNDARY_RADIUS
    local failBoundary = STAR_FALL_BOUNDARY_RADIUS * 1.35
    local failBoundarySquared = failBoundary * failBoundary

    for _, star in ipairs(self.stars) do
        star.px = star.x
        star.py = star.y
        star.x = star.x + (dx * scale * star.speed)
        star.y = star.y + (dy * scale * star.speed)

        local rx, ry = rotatePointWithTrig(star.x - self.playerCenterX, star.y - self.playerCenterY, screenCos, screenSin)
        local screenX = self.playerCenterX + rx
        local screenY = self.playerCenterY + ry
        local offsetX = screenX - self.playerCenterX
        local offsetY = screenY - self.playerCenterY
        local radiusSquared = (offsetX * offsetX) + (offsetY * offsetY)
        local forwardProjection = (offsetX * screenDx) + (offsetY * screenDy)

        if radiusSquared >= boundarySquared and forwardProjection > 0 then
            self:spawnFallStar(star, false)
        elseif radiusSquared >= failBoundarySquared then
            self:spawnFallStar(star, false)
        end
    end

    if self.largeFallStar ~= nil then
        local star = self.largeFallStar
        star.px = star.x
        star.py = star.y
        star.x = star.x + (dx * scale * star.speed)
        star.y = star.y + (dy * scale * star.speed)

        local rx, ry = rotatePointWithTrig(star.x - self.playerCenterX, star.y - self.playerCenterY, screenCos, screenSin)
        local screenX = self.playerCenterX + rx
        local screenY = self.playerCenterY + ry
        local offsetX = screenX - self.playerCenterX
        local offsetY = screenY - self.playerCenterY
        local radiusSquared = (offsetX * offsetX) + (offsetY * offsetY)
        local forwardProjection = (offsetX * screenDx) + (offsetY * screenDy)
        local largeBoundary = (STAR_FALL_BOUNDARY_RADIUS + 48)
        local largeBoundarySquared = largeBoundary * largeBoundary

        if (radiusSquared >= boundarySquared and forwardProjection > 0) or radiusSquared >= largeBoundarySquared then
            self.largeFallStar = nil
            self.largeFallStarTimer = randomLargeStarDelayFrames()
        end
    else
        self.largeFallStarTimer = self.largeFallStarTimer - 1
        if self.largeFallStarTimer <= 0 then
            self:spawnLargeFallStar(false)
        end
    end
end

function Starfield:drawStarFall()
    gfx.setColor(self:getForegroundColor())
    local screenCos = self.screenCos
    local screenSin = self.screenSin

    if self.largeFallStar ~= nil then
        local star = self.largeFallStar
        local xr, yr = rotatePointWithTrig(star.x - self.playerCenterX, star.y - self.playerCenterY, screenCos, screenSin)
        local x2 = self.playerCenterX + xr
        local y2 = self.playerCenterY + yr
        gfx.fillCircleAtPoint(x2, y2, star.size)
    end

    for _, star in ipairs(self.stars) do
        local pxr, pyr = rotatePointWithTrig(star.px - self.playerCenterX, star.py - self.playerCenterY, screenCos, screenSin)
        local xr, yr = rotatePointWithTrig(star.x - self.playerCenterX, star.y - self.playerCenterY, screenCos, screenSin)
        local x1 = self.playerCenterX + pxr
        local y1 = self.playerCenterY + pyr
        local x2 = self.playerCenterX + xr
        local y2 = self.playerCenterY + yr
        self:drawMotionStarShape(x1, y1, x2, y2, star.size)
    end
end

function Starfield:updateWarpSpeed()
    local driftX, driftY = vectorFromAngle(self.directionAngle)
    local signedSpeed = self.speed
    local biasX = driftX * signedSpeed * 0.08
    local biasY = driftY * signedSpeed * 0.08
    local shouldRefreshReverseField = self.lastSpeed > 0 and signedSpeed < -1

    if shouldRefreshReverseField or (self.lastSpeed < 0 and signedSpeed > 0) then
        self:refreshWarpFieldForDirection()
    end

    for _, star in ipairs(self.stars) do
        star.px = star.x
        star.py = star.y

        if signedSpeed ~= 0 then
            local scaleFactor = clamp(1 + (signedSpeed * 0.03 * star.speed), 0.05, 8)
            star.x = (star.x * scaleFactor) + biasX
            star.y = (star.y * scaleFactor) + biasY

            if signedSpeed < 0 and star.despawnRadius > 0 then
                local growthStep = star.despawnGrowth * math.max(1, math.abs(signedSpeed))
                star.despawnRadius = math.min(WARP_CENTER_DESPAWN_RADIUS, star.despawnRadius + growthStep)
            end

            if self:warpStarTouchesCenterZone(star) then
                self:spawnWarpStar(star, signedSpeed < 0)
            else
                local worldX = (self.playerCenterX + star.x) - self.centerX
                local worldY = (self.playerCenterY + star.y) - self.centerY
                local distanceSquared = (worldX * worldX) + (worldY * worldY)

                if distanceSquared >= WARP_OFFSCREEN_RADIUS_SQUARED then
                    self:spawnWarpStar(star, signedSpeed < 0)
                end
            end
        end

        if star.spawnFadeFrames and star.spawnFadeFrames > 0 then
            star.spawnFadeFrames = star.spawnFadeFrames - 1
        end

        self:updateWarpStarScreenCache(star)
    end

    self.lastSpeed = signedSpeed
end

function Starfield:drawWarpSpeed()
    gfx.setColor(self:getForegroundColor())
    local activeFadeCount = 0
    local unexpectedFadeCount = 0
    for _, star in ipairs(self.stars) do
        local fade = self:getWarpStarFade(star)
        if fade < 1 then
            activeFadeCount = activeFadeCount + 1
            if not (star.spawnFadeFrames and star.spawnFadeFrames > 0) then
                unexpectedFadeCount = unexpectedFadeCount + 1
            end
        end
        local dx = star.sx2 - star.sx1
        local dy = star.sy2 - star.sy1
        local lengthSquared = (dx * dx) + (dy * dy)
        if fade >= 0.35 and lengthSquared > 4 and not self.warpStyleStarFall then
            self:drawWarpStreak(star.sx1, star.sy1, star.sx2, star.sy2)
        end
        if self.warpStyleStarTrail or self.warpStyleTaper then
            local length = math.sqrt(lengthSquared)
            if length > 0.01 then
                local unitX = dx / length
                local unitY = dy / length
                if self.warpStyleStarTrail then
                    self:drawWarpTrailDots(star, unitX, unitY, length)
                end
                if self.warpStyleTaper then
                    self:drawWarpTriangleTaper(star, unitX, unitY, length)
                end
            end
        end
        self:drawWarpHeadScaled(star, math.max(0.35, fade))
    end

    self.debugFadeFrameCounter = self.debugFadeFrameCounter + 1
    if self.debugFadeFrameCounter >= WARP_FADE_DEBUG_INTERVAL_FRAMES then
        self.debugFadeFrameCounter = 0
        StarryLog.forceDebug(
            "warp fade debug stars=%d speed=%.2f active=%d unexpected=%d spawnOnly=%s",
            #self.stars,
            self.speed or 0,
            activeFadeCount,
            unexpectedFadeCount,
            tostring(unexpectedFadeCount == 0)
        )
    end
end

function Starfield:update()
    if self.kind == "fall" then
        self:updateStarFall()
    else
        self:updateWarpSpeed()
    end
end

function Starfield:draw()
    if self.inverse then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, 0, self.width, self.height)
    end

    if self.kind == "fall" then
        self:drawStarFall()
    else
        self:drawWarpSpeed()
    end
end
