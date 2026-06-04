--[[
Vibes effect browser.

Purpose:
- hosts lightweight code-drawn psychedelic toys under one shared view
- cycles sub-effects with A and uses signed crank speed for each effect
- prototypes clean-loop and shape-accumulation ideas before asset-heavy passes
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

VibesEffect = {}
VibesEffect.__index = VibesEffect
VibesEffect.viewStatsEnabled = false

local TAU <const> = math.pi * 2
local SPIRAL_SEGMENT_COUNT <const> = 320
local SPIRAL_TURN_COUNT <const> = 5.4
local LOOP_STAR_COUNT <const> = 180
local LINE_GROUP_COUNT <const> = 10
local LINES_PER_GROUP <const> = 50
local PILEUP_MAX_SHAPES <const> = 180
local POLYGON_COUNT <const> = 72
local TUNNEL_BAR_COUNT <const> = 18
local BUBBLE_MAX_COUNT <const> = 28
local SMOOTH_STAR_COUNT <const> = 192
local SMOOTH_MAX_STREAK_LENGTH_SQUARED <const> = 34 * 34
local SMOOTH_CENTER_SIZE_RADIUS_SQUARED <const> = 46 * 46
local BUBBLE_POP_RESPAWN_MIN_FRAMES <const> = 15
local BUBBLE_POP_RESPAWN_MAX_FRAMES <const> = 150
local BUBBLE_POP_GROW_FRAMES <const> = 18
local LINE_MODE_SPIN <const> = 1
local LINE_MODE_ORBIT <const> = 2
local LINE_MODE_DRIFT <const> = 3

local EFFECTS <const> = {
    { id = "smoothsailing", label = "Smooth Sailing" },
    { id = "spiral", label = "Spiral" },
    { id = "tunnelbars", label = "Tunnel Bars" },
    { id = "fractal", label = "Fractal Spiral" },
    { id = "lines", label = "Line Bloom" },
    { id = "pileup", label = "Shape Pile-Up" },
    { id = "loopfall", label = "Loop Fall" },
    { id = "polygonstorm", label = "Polygon Storm" },
    { id = "microrotate", label = "Micro Rotate" },
    { id = "bubblecloud", label = "Cloud Bubbles" },
    { id = "bubblepop", label = "Bubble Pop" }
}

local function buildCatalogItems()
    local items = {}
    for index, effect in ipairs(EFFECTS) do
        items[index] = {
            id = "vibes_" .. effect.id,
            label = effect.label,
            modeId = effect.id,
            openViewId = "vibes",
            controlViewId = "vibes"
        }
    end
    return items
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

local function roundToTenth(value)
    if value >= 0 then
        return math.floor((value * 10) + 0.5) / 10
    end
    return math.ceil((value * 10) - 0.5) / 10
end

local function roundToInt(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function wrapPhase(value)
    while value < 0 do
        value = value + TAU
    end
    while value >= TAU do
        value = value - TAU
    end
    return value
end

local function wrapAxis(value, limit)
    while value < 0 do
        value = value + limit
    end
    while value >= limit do
        value = value - limit
    end
    return value
end

local function chooseRandomDirectionSign()
    return math.random() > 0.5 and 1 or -1
end

local function speedToPhaseDelta(speed)
    local magnitude = math.abs(speed or 0)
    if magnitude <= 1 then
        return speed * 0.01
    end
    return ((speed >= 0) and 1 or -1) * (0.02 + (math.log(magnitude + 1) * 0.035))
end

local function rotateAroundCenter(x, y, centerX, centerY, angle)
    local dx = x - centerX
    local dy = y - centerY
    local cosine = math.cos(angle)
    local sine = math.sin(angle)
    return centerX + ((dx * cosine) - (dy * sine)), centerY + ((dx * sine) + (dy * cosine))
end

local function speedToTravelDelta(speed)
    local magnitude = math.abs(speed or 0)
    if magnitude <= 1 then
        return speed * 0.35
    end
    return ((speed >= 0) and 1 or -1) * (0.6 + (math.log(magnitude + 1) * 1.8))
end

function VibesEffect.getModeLabel(_modeId)
    return "Vibes"
end

function VibesEffect.getCatalogItems()
    return buildCatalogItems()
end

function VibesEffect.isViewStatsEnabled()
    return VibesEffect.viewStatsEnabled == true
end

function VibesEffect.setViewStatsEnabled(enabled)
    VibesEffect.viewStatsEnabled = enabled == true
end

function VibesEffect.getEffectLabelById(effectId)
    for _, effect in ipairs(EFFECTS) do
        if effect.id == effectId then
            return effect.label
        end
    end
    return "Vibes"
end

function VibesEffect.new(width, height, options)
    local self = setmetatable({}, VibesEffect)
    options = options or {}
    self.width = width
    self.height = height
    self.preview = options.preview == true
    self.selectionLocked = options.selectionLocked == true
    self.effectIndex = 1
    self.modeId = options.modeId
    self.speed = self.preview and 0.6 or 0
    self.frame = 0
    self.refreshRate = pd.display.getRefreshRate() or 30
    self.spiralPhase = 0
    self.spiralTwist = 0
    self.spiralPulse = 0
    self.barPhase = 0
    self.barDrift = 0
    self.fractalPhase = 0
    self.fractalPulse = 0
    self.lineMotionMode = LINE_MODE_SPIN
    self.lineCrankDelta = 0
    self.lineSpinRotation = 0
    self.lineOrbitAngle = 0
    self.lineOrbitDirection = chooseRandomDirectionSign()
    self.loopOffset = 0
    self.pileupPhase = 0
    self.pileupSpawnAccumulator = 0
    self.pileupShapeCursor = 1
    self.polygonStormPhase = 0
    self.microRotateAngle = 0
    self.hudBlink = 0
    self.lineEntries = {}
    self.loopStars = {}
    self.tunnelBars = {}
    self.pileupShapes = {}
    self.polygonEntries = {}
    self.microRotateImage = nil
    self.bubbles = {}
    self.pendingBubbles = {}
    self.smoothStars = {}
    self.smoothSpeed = self.preview and 1.2 or 0
    self.smoothTargetSpeed = self.smoothSpeed
    self.smoothDirectionX = 0
    self.smoothDirectionY = 0
    self.smoothDriftX = 0
    self.smoothDriftY = 0
    self:buildLineEntries()
    self:buildLoopStars()
    self:buildTunnelBars()
    self:buildPolygonEntries()
    self:buildMicroRotateImage()
    self:seedBubbleMode(false)
    self:buildSmoothStars()
    if self.modeId ~= nil then
        self:setEffectById(self.modeId)
    end
    return self
end

function VibesEffect:setPreview(isPreview)
    self.preview = isPreview == true
end

function VibesEffect:getEffect()
    return EFFECTS[self.effectIndex] or EFFECTS[1]
end

function VibesEffect:getEffectLabel()
    local effect = self:getEffect()
    return effect and effect.label or "Vibes"
end

function VibesEffect:setEffectById(effectId)
    for index, effect in ipairs(EFFECTS) do
        if effect.id == effectId then
            self.effectIndex = index
            self.modeId = effect.id
            return true
        end
    end
    return false
end

function VibesEffect:handlePrimaryAction()
    if self.selectionLocked then
        if self:getEffect().id == "lines" then
            self.lineMotionMode = self.lineMotionMode + 1
            if self.lineMotionMode > LINE_MODE_DRIFT then
                self.lineMotionMode = LINE_MODE_SPIN
            end
            if self.lineMotionMode == LINE_MODE_ORBIT then
                self.lineOrbitDirection = chooseRandomDirectionSign()
            end
        end
        return
    end
    self.effectIndex = self.effectIndex + 1
    if self.effectIndex > #EFFECTS then
        self.effectIndex = 1
    end
    self.modeId = self:getEffect().id
end

function VibesEffect:handleDirectionalInput(leftPressed, rightPressed, _upHeld, _downHeld)
    if self:getEffect().id == "smoothsailing" then
        local steerStep = 0.22
        if leftPressed then
            self.smoothDirectionX = clamp((self.smoothDirectionX or 0) - steerStep, -1.2, 1.2)
        elseif rightPressed then
            self.smoothDirectionX = clamp((self.smoothDirectionX or 0) + steerStep, -1.2, 1.2)
        end
        if _upHeld then
            self.smoothDirectionY = clamp((self.smoothDirectionY or 0) - 0.035, -1.2, 1.2)
        elseif _downHeld then
            self.smoothDirectionY = clamp((self.smoothDirectionY or 0) + 0.035, -1.2, 1.2)
        else
            self.smoothDirectionY = (self.smoothDirectionY or 0) * 0.94
        end
        return
    end

    if self.selectionLocked then
        return
    end
    if leftPressed then
        self.effectIndex = self.effectIndex - 1
        if self.effectIndex < 1 then
            self.effectIndex = #EFFECTS
        end
    elseif rightPressed then
        self.effectIndex = self.effectIndex + 1
        if self.effectIndex > #EFFECTS then
            self.effectIndex = 1
        end
    end
    self.modeId = self:getEffect().id
end

function VibesEffect:stepSpeed(direction)
    if direction == 0 then
        return
    end

    if self:getEffect().id == "smoothsailing" then
        self.smoothTargetSpeed = (self.smoothTargetSpeed or 0) + (direction * 0.25)
        self.speed = self.smoothTargetSpeed
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
end

function VibesEffect:buildLineEntries()
    self.lineEntries = {}
    local sequence = 0
    local centerX = self.width * 0.5
    local centerY = self.height * 0.5
    for groupIndex = 1, LINE_GROUP_COUNT do
        local baseSize = 1 + (((groupIndex - 1) / math.max(1, LINE_GROUP_COUNT - 1)) * 5)
        for _ = 1, LINES_PER_GROUP do
            sequence = sequence + 1
            local angle = math.random() * TAU
            local x = math.random() * self.width
            local y = math.random() * self.height
            local moveAngle = math.random() * TAU
            local dx = x - centerX
            local dy = y - centerY
            self.lineEntries[sequence] = {
                x = x,
                y = y,
                baseX = x,
                baseY = y,
                angle = angle,
                orbitRadius = math.sqrt((dx * dx) + (dy * dy)),
                orbitAngle = math.atan2(dy, dx),
                moveX = math.cos(moveAngle),
                moveY = math.sin(moveAngle),
                moveSpeed = 0.65 + (math.random() * 1.45),
                spinDirection = chooseRandomDirectionSign(),
                sizeBase = baseSize,
                length = 8 + (baseSize * 11)
            }
        end
    end
end

function VibesEffect:respawnLineEntry(entry)
    local margin = math.max(12, (entry.length or 16) * 0.65)
    if math.abs(entry.moveX) >= math.abs(entry.moveY) then
        entry.x = entry.moveX > 0 and -margin or self.width + margin
        entry.y = math.random() * self.height
    else
        entry.x = math.random() * self.width
        entry.y = entry.moveY > 0 and -margin or self.height + margin
    end
end

function VibesEffect:buildLoopStars()
    self.loopStars = {}
    for index = 1, LOOP_STAR_COUNT do
        self.loopStars[index] = {
            x = math.random() * self.width,
            y = math.random() * self.height,
            size = 1 + math.floor(math.random() * 3),
            depth = 0.25 + (math.random() * 1.75)
        }
    end
end

function VibesEffect:seedSmoothStar(star, randomizeDepth)
    local angle = math.random() * TAU
    local radius = math.sqrt(math.random()) * 1.18
    star.x = math.cos(angle) * radius
    star.y = math.sin(angle) * radius
    star.z = randomizeDepth and (0.2 + (math.random() * 0.98)) or 1.18
    star.depthSpeed = 0.65 + (math.random() * 0.85)
    star.baseSize = math.random() < 0.82 and 1 or 2
    star.size = star.baseSize
    star.prevScreenX = self.width * 0.5
    star.prevScreenY = self.height * 0.5
    star.screenX = star.prevScreenX
    star.screenY = star.prevScreenY
    star.trailVisible = false
end

function VibesEffect:buildSmoothStars()
    self.smoothStars = {}
    for index = 1, SMOOTH_STAR_COUNT do
        local star = {}
        self:seedSmoothStar(star, true)
        self.smoothStars[index] = star
    end
end

function VibesEffect:buildTunnelBars()
    self.tunnelBars = {}
    for index = 1, TUNNEL_BAR_COUNT do
        self.tunnelBars[index] = {
            offset = ((index - 1) / TUNNEL_BAR_COUNT) * self.height,
            height = 8 + ((index % 5) * 4),
            widthScale = 0.18 + ((index % 7) * 0.08),
            swaySeed = math.random() * TAU
        }
    end
end

function VibesEffect:buildPolygonEntries()
    self.polygonEntries = {}
    for index = 1, POLYGON_COUNT do
        self.polygonEntries[index] = {
            x = math.random() * self.width,
            y = math.random() * self.height,
            orbit = 8 + (math.random() * 54),
            sides = 3 + (index % 4),
            spinSeed = math.random() * TAU,
            travelSeed = math.random() * TAU,
            travelRate = 0.2 + (math.random() * 1.8),
            depth = 0.35 + (math.random() * 1.25)
        }
    end
end

function VibesEffect:buildMicroRotateImage()
    local imageSize = 400
    local imageCenter = imageSize * 0.5
    local image = gfx.image.new(imageSize, imageSize, gfx.kColorWhite)
    if image == nil then
        return
    end

    gfx.pushContext(image)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, 0, imageSize, imageSize)
        gfx.setColor(gfx.kColorBlack)
        for ring = 1, 20 do
            local radius = 8 + (ring * 9)
            if ring % 2 == 0 then
                gfx.drawCircleAtPoint(imageCenter, imageCenter, radius)
            else
                gfx.drawEllipseInRect(imageCenter - radius, imageCenter - math.floor(radius * 0.66), radius * 2, math.floor(radius * 1.32))
            end
        end
        for spoke = 1, 32 do
            local angle = ((spoke - 1) / 32) * TAU
            local inner = 16 + ((spoke % 4) * 7)
            local outer = 200
            gfx.drawLine(
                roundToInt(imageCenter + (math.cos(angle) * inner)),
                roundToInt(imageCenter + (math.sin(angle) * inner)),
                roundToInt(imageCenter + (math.cos(angle) * outer)),
                roundToInt(imageCenter + (math.sin(angle) * outer))
            )
        end
        gfx.fillCircleAtPoint(imageCenter, imageCenter, 8)
    gfx.popContext()

    self.microRotateImage = image
end

function VibesEffect:createBubble(popMode)
    local lifetime = 30 * (1 + math.random(0, 3))
    local radius = popMode and (5 + math.random() * 13) or (8 + math.random() * 18)
    return {
        x = math.random() * self.width,
        y = math.random() * self.height,
        vx = (-0.4 + (math.random() * 0.8)),
        vy = (-0.55 + (math.random() * 1.1)),
        radius = popMode and 1 or radius,
        startRadius = radius,
        targetRadius = 2 + math.random() * 5,
        lifetime = lifetime,
        age = 0,
        pulseSeed = math.random() * TAU,
        growFrames = popMode and BUBBLE_POP_GROW_FRAMES or 0,
        dead = false
    }
end

function VibesEffect:seedBubbleMode(popMode)
    self.bubbles = {}
    self.pendingBubbles = {}
    for index = 1, BUBBLE_MAX_COUNT do
        self.bubbles[index] = self:createBubble(popMode)
        if popMode then
            self.bubbles[index].radius = self.bubbles[index].startRadius
            self.bubbles[index].growFrames = 0
        end
    end
end

function VibesEffect:queueBubblePopRespawn()
    self.pendingBubbles[#self.pendingBubbles + 1] = {
        frames = math.random(BUBBLE_POP_RESPAWN_MIN_FRAMES, BUBBLE_POP_RESPAWN_MAX_FRAMES)
    }
end

function VibesEffect:updateSpiral()
    local phaseDelta = speedToPhaseDelta(self.speed)
    self.spiralPhase = wrapPhase(self.spiralPhase + phaseDelta)
    self.spiralTwist = wrapPhase(self.spiralTwist + (phaseDelta * 0.32))
    self.spiralPulse = wrapPhase(self.spiralPulse + 0.03 + (math.abs(phaseDelta) * 0.25))
end

function VibesEffect:updateTunnelBars()
    local travelDelta = speedToTravelDelta(self.speed)
    self.barPhase = wrapPhase(self.barPhase + (0.018 + (math.abs(travelDelta) * 0.002)))
    self.barDrift = self.barDrift + (travelDelta * 0.55)
end

function VibesEffect:updateFractal()
    local phaseDelta = speedToPhaseDelta(self.speed)
    self.fractalPhase = wrapPhase(self.fractalPhase + (phaseDelta * 0.85))
    self.fractalPulse = wrapPhase(self.fractalPulse + 0.024 + (math.abs(phaseDelta) * 0.18))
end

function VibesEffect:updateLines()
    if self.lineMotionMode ~= LINE_MODE_DRIFT then
        return
    end

    local movementScale = self.lineCrankDelta * 22
    if math.abs(movementScale) <= 0.0001 then
        return
    end

    for _, entry in ipairs(self.lineEntries) do
        entry.x = entry.x + (entry.moveX * entry.moveSpeed * movementScale)
        entry.y = entry.y + (entry.moveY * entry.moveSpeed * movementScale)
        local margin = math.max(12, (entry.length or 16) * 0.65)
        if entry.x < -margin or entry.x > self.width + margin or entry.y < -margin or entry.y > self.height + margin then
            self:respawnLineEntry(entry)
        end
    end
end

function VibesEffect:updateLoopFall()
    local travelDelta = speedToTravelDelta(self.speed)
    self.loopOffset = self.loopOffset + travelDelta
end

function VibesEffect:spawnPileupShape()
    self.pileupShapes[self.pileupShapeCursor] = {
        x = math.random() * self.width,
        y = math.random() * self.height,
        size = 14 + math.floor(math.random() * 44),
        shapeKind = ((self.pileupShapeCursor - 1) % 3) + 1,
        seed = math.random() * TAU
    }
    self.pileupShapeCursor = self.pileupShapeCursor + 1
    if self.pileupShapeCursor > PILEUP_MAX_SHAPES then
        self.pileupShapeCursor = 1
    end
end

function VibesEffect:updatePileup()
    local travelDelta = speedToTravelDelta(self.speed)
    self.pileupPhase = wrapPhase(self.pileupPhase + 0.02 + (math.abs(travelDelta) * 0.002))
    self.pileupSpawnAccumulator = self.pileupSpawnAccumulator + math.max(0.25, math.min(5.5, math.abs(travelDelta) * 0.12))
    while self.pileupSpawnAccumulator >= 1 do
        self:spawnPileupShape()
        self.pileupSpawnAccumulator = self.pileupSpawnAccumulator - 1
    end
end

function VibesEffect:updatePolygonStorm()
    local travelDelta = speedToTravelDelta(self.speed)
    self.polygonStormPhase = wrapPhase(self.polygonStormPhase + 0.018 + (math.abs(travelDelta) * 0.0025))
end

function VibesEffect:updateMicroRotate()
    local phaseDelta = speedToPhaseDelta(self.speed)
    self.microRotateAngle = self.microRotateAngle + (phaseDelta * 28)
end

function VibesEffect:updateBubbles(popMode)
    local speedScale = 0.2 + math.min(4.5, math.abs(speedToTravelDelta(self.speed)) * 0.05)
    for index = #self.bubbles, 1, -1 do
        local bubble = self.bubbles[index]
        bubble.age = bubble.age + 1
        bubble.x = wrapAxis(bubble.x + (bubble.vx * speedScale), self.width)
        bubble.y = wrapAxis(bubble.y + (bubble.vy * speedScale), self.height)

        if popMode then
            if (bubble.growFrames or 0) > 0 then
                local progress = 1 - ((bubble.growFrames or 0) / BUBBLE_POP_GROW_FRAMES)
                bubble.radius = 1 + (((bubble.startRadius or 8) - 1) * progress)
                bubble.growFrames = bubble.growFrames - 1
            else
                bubble.radius = (bubble.startRadius or 8) + (math.sin((bubble.age * 0.08) + bubble.pulseSeed) * 0.9)
            end
        else
            local progress = math.min(1, bubble.age / math.max(1, bubble.lifetime))
            bubble.radius = bubble.startRadius + ((bubble.targetRadius - bubble.startRadius) * progress)
            if bubble.age >= bubble.lifetime then
                self.bubbles[index] = self:createBubble(false)
            end
        end
    end

    for first = 1, #self.bubbles do
        local bubbleA = self.bubbles[first]
        for second = first + 1, #self.bubbles do
            local bubbleB = self.bubbles[second]
            local dx = bubbleB.x - bubbleA.x
            local dy = bubbleB.y - bubbleA.y
            local distanceSquared = (dx * dx) + (dy * dy)
            local minDistance = bubbleA.radius + bubbleB.radius
            if distanceSquared > 0 and distanceSquared < (minDistance * minDistance) then
                local distance = math.sqrt(distanceSquared)
                local overlap = minDistance - distance
                local nx = dx / distance
                local ny = dy / distance
                if popMode then
                    bubbleA.dead = true
                    bubbleB.dead = true
                else
                    bubbleA.x = wrapAxis(bubbleA.x - (nx * overlap * 0.5), self.width)
                    bubbleA.y = wrapAxis(bubbleA.y - (ny * overlap * 0.5), self.height)
                    bubbleB.x = wrapAxis(bubbleB.x + (nx * overlap * 0.5), self.width)
                    bubbleB.y = wrapAxis(bubbleB.y + (ny * overlap * 0.5), self.height)
                end
            end
        end
    end

    if popMode then
        for index = #self.bubbles, 1, -1 do
            if self.bubbles[index].dead then
                table.remove(self.bubbles, index)
                self:queueBubblePopRespawn()
            end
        end

        for index = #self.pendingBubbles, 1, -1 do
            local pending = self.pendingBubbles[index]
            pending.frames = pending.frames - 1
            if pending.frames <= 0 and #self.bubbles < BUBBLE_MAX_COUNT then
                self.bubbles[#self.bubbles + 1] = self:createBubble(true)
                table.remove(self.pendingBubbles, index)
            end
        end
    end
end

function VibesEffect:updateSmoothSailing()
    self.smoothSpeed = (self.smoothSpeed or 0) + (((self.smoothTargetSpeed or 0) - (self.smoothSpeed or 0)) * 0.18)
    self.smoothDriftX = ((self.smoothDriftX or 0) * 0.88) + ((self.smoothDirectionX or 0) * 0.12)
    self.smoothDriftY = ((self.smoothDriftY or 0) * 0.88) + ((self.smoothDirectionY or 0) * 0.12)
    self.smoothDirectionX = (self.smoothDirectionX or 0) * 0.965

    local centerX = self.width * 0.5
    local centerY = self.height * 0.5
    local speed = self.smoothSpeed or 0
    local travel = speed * 0.006

    for _, star in ipairs(self.smoothStars) do
        local previousScreenX = star.screenX or centerX
        local previousScreenY = star.screenY or centerY
        star.prevScreenX = star.screenX or centerX
        star.prevScreenY = star.screenY or centerY
        star.z = (star.z or 1) - (travel * (star.depthSpeed or 1))

        local respawned = false
        if star.z <= 0.08 or star.z > 1.26 then
            self:seedSmoothStar(star, speed < 0)
            respawned = true
        end

        local z = math.max(0.08, star.z or 1)
        local perspective = 1 / z
        local screenX = centerX + (((star.x or 0) + (self.smoothDriftX or 0)) * perspective * 118)
        local screenY = centerY + (((star.y or 0) + (self.smoothDriftY or 0)) * perspective * 86)

        if screenX < -8 or screenX > self.width + 8 or screenY < -8 or screenY > self.height + 8 then
            self:seedSmoothStar(star, speed < 0)
            respawned = true
            z = math.max(0.08, star.z or 1)
            perspective = 1 / z
            screenX = centerX + (((star.x or 0) + (self.smoothDriftX or 0)) * perspective * 118)
            screenY = centerY + (((star.y or 0) + (self.smoothDriftY or 0)) * perspective * 86)
        end

        local distanceX = screenX - centerX
        local distanceY = screenY - centerY
        local distanceSquared = (distanceX * distanceX) + (distanceY * distanceY)
        local depthSizeBoost = clamp((1.26 - z) / 1.18, 0, 1)
        local centerSizeBoost = clamp(1 - (distanceSquared / SMOOTH_CENTER_SIZE_RADIUS_SQUARED), 0, 1)
        local sizeBoost = speed < 0 and centerSizeBoost or math.max(depthSizeBoost, centerSizeBoost * 0.55)
        star.size = math.max(1, math.floor(((star.baseSize or 1) + (sizeBoost * 4)) + 0.5))

        if respawned then
            star.prevScreenX = screenX
            star.prevScreenY = screenY
            star.trailVisible = false
        else
            star.prevScreenX = previousScreenX
            star.prevScreenY = previousScreenY
            star.trailVisible = true
        end
        star.screenX = screenX
        star.screenY = screenY
    end
end

function VibesEffect:update()
    self.frame = self.frame + 1
    self.hudBlink = wrapPhase(self.hudBlink + 0.08)

    local effectId = self:getEffect().id
    if effectId == "smoothsailing" then
        self:updateSmoothSailing()
    elseif effectId == "spiral" then
        self:updateSpiral()
    elseif effectId == "tunnelbars" then
        self:updateTunnelBars()
    elseif effectId == "fractal" then
        self:updateFractal()
    elseif effectId == "lines" then
        self:updateLines()
    elseif effectId == "pileup" then
        self:updatePileup()
    elseif effectId == "loopfall" or effectId == "inversefall" then
        self:updateLoopFall()
    elseif effectId == "polygonstorm" then
        self:updatePolygonStorm()
    elseif effectId == "bubblecloud" then
        self:updateBubbles(false)
    elseif effectId == "bubblepop" then
        self:updateBubbles(true)
    else
        self:updateMicroRotate()
    end

    if self.preview and not self.selectionLocked and self.frame % (self.refreshRate * 4) == 0 then
        self:handlePrimaryAction()
    end
end

function VibesEffect:usesDirectCrank()
    local effectId = self:getEffect().id
    return effectId == "lines" or effectId == "smoothsailing"
end

function VibesEffect:usesHeldDirectionalInput()
    return self:getEffect().id == "smoothsailing"
end

function VibesEffect:applyCrank(change, _acceleratedChange)
    if not self:usesDirectCrank() then
        return
    end

    if self:getEffect().id == "smoothsailing" then
        self.smoothTargetSpeed = (self.smoothTargetSpeed or 0) + (change * 0.025)
        self.speed = self.smoothTargetSpeed
        return
    end

    local normalizedChange = math.rad(change)
    self.lineCrankDelta = normalizedChange
    self.lineSpinRotation = self.lineSpinRotation + normalizedChange
    if self.lineMotionMode == LINE_MODE_SPIN then
        return
    elseif self.lineMotionMode == LINE_MODE_ORBIT then
        self.lineOrbitAngle = self.lineOrbitAngle + (normalizedChange * self.lineOrbitDirection)
    end
end

function VibesEffect:getLineModeLabel()
    if self.lineMotionMode == LINE_MODE_ORBIT then
        return "Orbit"
    elseif self.lineMotionMode == LINE_MODE_DRIFT then
        return "Drift"
    end
    return "Spin"
end

function VibesEffect:drawBubbleSet(fillMode)
    for _, bubble in ipairs(self.bubbles) do
        local radius = math.max(1, roundToInt(bubble.radius))
        if fillMode then
            gfx.drawCircleAtPoint(roundToInt(bubble.x), roundToInt(bubble.y), radius)
            gfx.drawLine(
                roundToInt(bubble.x - radius),
                roundToInt(bubble.y),
                roundToInt(bubble.x + radius),
                roundToInt(bubble.y)
            )
        else
            gfx.drawCircleAtPoint(roundToInt(bubble.x), roundToInt(bubble.y), radius)
        end
    end
end

function VibesEffect:drawSpiral()
    local centerX = self.width * 0.5
    local centerY = self.height * 0.5
    local previousX = nil
    local previousY = nil
    for pointIndex = 0, SPIRAL_SEGMENT_COUNT do
        local t = pointIndex / SPIRAL_SEGMENT_COUNT
        local theta = (t * SPIRAL_TURN_COUNT * TAU) + self.spiralPhase
        local pulse = math.sin(self.spiralPulse + (t * 10))
        local radius = 4 + (t * self.width * 0.72) + (pulse * 7)
        local x = centerX + (math.cos(theta + (math.sin(self.spiralTwist + (t * 4)) * 0.12)) * radius)
        local y = centerY + (math.sin(theta) * radius)
        if previousX ~= nil then
            gfx.drawLine(roundToInt(previousX), roundToInt(previousY), roundToInt(x), roundToInt(y))
        end
        previousX = x
        previousY = y
    end
    gfx.fillCircleAtPoint(roundToInt(centerX), roundToInt(centerY), 3)
end

function VibesEffect:drawTunnelBars()
    local centerX = self.width * 0.5
    for _, bar in ipairs(self.tunnelBars) do
        local y = wrapAxis(bar.offset + self.barDrift, self.height)
        local sway = math.sin(self.barPhase + bar.swaySeed)
        local width = math.floor(self.width * bar.widthScale * (0.8 + (sway * 0.16)))
        local x = roundToInt(centerX - (width * 0.5) + (sway * 42))
        local height = bar.height
        gfx.fillRect(x, roundToInt(y), width, height)
        gfx.drawLine(0, roundToInt(y + (height * 0.5)), self.width, roundToInt(y + (height * 0.5)))
    end
end

function VibesEffect:getFractalArmCount()
    local magnitude = math.abs(self.speed or 0)
    if magnitude < 1 then
        return 12
    elseif magnitude < 3 then
        return 18
    elseif magnitude < 10 then
        return 24
    end
    return 30
end

function VibesEffect:drawFractal()
    local centerX = self.width * 0.5
    local centerY = self.height * 0.5
    local armCount = self:getFractalArmCount()
    local baseRadius = math.min(self.width, self.height) * 0.1

    for armIndex = 1, armCount do
        local armAngle = self.fractalPhase + (((armIndex - 1) / armCount) * TAU)
        local previousX = centerX
        local previousY = centerY
        local radius = baseRadius
        local angle = armAngle
        for step = 1, 6 do
            local pulse = math.sin(self.fractalPulse + step + armIndex)
            radius = radius * (1.45 + (pulse * 0.06))
            angle = angle + (0.42 * pulse)
            local x = centerX + (math.cos(angle) * radius)
            local y = centerY + (math.sin(angle) * radius)
            gfx.drawLine(roundToInt(previousX), roundToInt(previousY), roundToInt(x), roundToInt(y))
            local branchAngle = angle + ((step % 2 == 0) and 0.72 or -0.72)
            local branchRadius = radius * 0.46
            gfx.drawLine(
                roundToInt(x),
                roundToInt(y),
                roundToInt(x + (math.cos(branchAngle) * branchRadius)),
                roundToInt(y + (math.sin(branchAngle) * branchRadius))
            )
            previousX = x
            previousY = y
        end
    end
end

function VibesEffect:drawLines()
    local centerX = self.width * 0.5
    local centerY = self.height * 0.5
    for _, entry in ipairs(self.lineEntries) do
        local lineCenterX = entry.baseX
        local lineCenterY = entry.baseY
        local lineAngle = entry.angle

        if self.lineMotionMode == LINE_MODE_SPIN then
            lineAngle = entry.angle + self.lineSpinRotation
        elseif self.lineMotionMode == LINE_MODE_ORBIT then
            lineCenterX, lineCenterY = rotateAroundCenter(entry.baseX, entry.baseY, centerX, centerY, self.lineOrbitAngle)
            lineAngle = entry.angle + self.lineOrbitAngle
        else
            lineCenterX = entry.x
            lineCenterY = entry.y
        end

        local halfLengthX = math.cos(lineAngle) * entry.length * 0.5
        local halfLengthY = math.sin(lineAngle) * entry.length * 0.5
        gfx.drawLine(
            roundToInt(lineCenterX - halfLengthX),
            roundToInt(lineCenterY - halfLengthY),
            roundToInt(lineCenterX + halfLengthX),
            roundToInt(lineCenterY + halfLengthY)
        )
    end
end

function VibesEffect:drawPileup()
    local pulse = math.sin(self.pileupPhase)
    for _, shape in ipairs(self.pileupShapes) do
        if shape ~= nil then
            local wobble = math.sin(self.pileupPhase + shape.seed)
            local size = math.max(6, math.floor(shape.size * (0.86 + (pulse * 0.04) + (wobble * 0.08))))
            local x = roundToInt(shape.x + (math.cos(shape.seed + self.pileupPhase) * 6))
            local y = roundToInt(shape.y + (math.sin(shape.seed + self.pileupPhase) * 6))
            if shape.shapeKind == 1 then
                gfx.drawRect(x - math.floor(size * 0.5), y - math.floor(size * 0.5), size, size)
            elseif shape.shapeKind == 2 then
                gfx.drawCircleAtPoint(x, y, math.floor(size * 0.5))
            else
                local half = math.floor(size * 0.5)
                gfx.drawLine(x, y - half, x - half, y + half)
                gfx.drawLine(x - half, y + half, x + half, y + half)
                gfx.drawLine(x + half, y + half, x, y - half)
            end
        end
    end
end

function VibesEffect:drawLoopFall(directionMultiplier)
    directionMultiplier = directionMultiplier or 1
    for _, star in ipairs(self.loopStars) do
        local x = wrapAxis(star.x, self.width)
        local y = wrapAxis(star.y + ((self.loopOffset * star.depth) * directionMultiplier), self.height)
        local drawX = roundToInt(x)
        local drawY = roundToInt(y)
        gfx.fillRect(drawX, drawY, star.size, star.size)
    end
end

function VibesEffect:drawPolygonStorm()
    for _, entry in ipairs(self.polygonEntries) do
        local orbitPhase = self.polygonStormPhase * entry.travelRate
        local centerX = wrapAxis(entry.x + (math.cos(entry.travelSeed + orbitPhase) * entry.orbit * entry.depth), self.width)
        local centerY = wrapAxis(entry.y + (math.sin(entry.travelSeed - orbitPhase) * entry.orbit * entry.depth), self.height)
        local radius = 6 + (entry.depth * 10) + (math.sin(entry.spinSeed + orbitPhase) * 3)
        local rotation = entry.spinSeed + (orbitPhase * 1.2)
        local previousX = nil
        local previousY = nil
        local firstX = nil
        local firstY = nil
        for vertex = 1, entry.sides do
            local angle = rotation + (((vertex - 1) / entry.sides) * TAU)
            local x = centerX + (math.cos(angle) * radius)
            local y = centerY + (math.sin(angle) * radius)
            if previousX ~= nil then
                gfx.drawLine(roundToInt(previousX), roundToInt(previousY), roundToInt(x), roundToInt(y))
            else
                firstX = x
                firstY = y
            end
            previousX = x
            previousY = y
        end
        if previousX ~= nil and firstX ~= nil then
            gfx.drawLine(roundToInt(previousX), roundToInt(previousY), roundToInt(firstX), roundToInt(firstY))
        end
    end
end

function VibesEffect:drawMicroRotate()
    if self.microRotateImage == nil then
        return
    end

    local centerX = self.width * 0.5
    local centerY = self.height * 0.5
    self.microRotateImage:drawRotated(centerX, centerY, self.microRotateAngle, 1.0, 1.0)
    local accentAngle = math.rad(self.microRotateAngle * 0.6)
    local accentRadius = 176
    gfx.fillCircleAtPoint(
        roundToInt(centerX + (math.cos(accentAngle) * accentRadius)),
        roundToInt(centerY + (math.sin(accentAngle) * accentRadius)),
        4
    )
end

function VibesEffect:drawSmoothSailing()
    for _, star in ipairs(self.smoothStars) do
        local x = roundToInt(star.screenX or 0)
        local y = roundToInt(star.screenY or 0)
        local px = roundToInt(star.prevScreenX or x)
        local py = roundToInt(star.prevScreenY or y)
        local size = star.size or 1
        local dx = x - px
        local dy = y - py

        local distanceSquared = (dx * dx) + (dy * dy)
        if star.trailVisible and distanceSquared >= 4 and distanceSquared <= SMOOTH_MAX_STREAK_LENGTH_SQUARED then
            gfx.drawLine(px, py, x, y)
        end

        if size > 1 then
            gfx.fillRect(x - 1, y - 1, 2, 2)
        else
            gfx.fillRect(x, y, 1, 1)
        end
    end
end

function VibesEffect:drawHud()
    if self.preview or not VibesEffect.isViewStatsEnabled() then
        return
    end

    gfx.setColor(gfx.kColorWhite)
    gfx.setDitherPattern(0.15, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRoundRect(8, 8, 190, 34, 6)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText(self:getEffectLabel(), 14, 12)
    local status = string.format("Speed %.1f  %d/%d", self.speed or 0, self.effectIndex, #EFFECTS)
    if self:getEffect().id == "lines" then
        status = string.format("Mode %s  %d/%d", self:getLineModeLabel(), self.effectIndex, #EFFECTS)
    elseif self:getEffect().id == "smoothsailing" then
        status = string.format("Speed %.1f  %d/%d", self.smoothSpeed or 0, self.effectIndex, #EFFECTS)
    end
    gfx.drawText(status, 14, 26)
end

function VibesEffect:draw()
    local effectId = self:getEffect().id
    local useDarkBackground = effectId == "smoothsailing" or effectId == "loopfall"

    gfx.setColor(useDarkBackground and gfx.kColorBlack or gfx.kColorWhite)
    gfx.fillRect(0, 0, self.width, self.height)
    gfx.setColor(useDarkBackground and gfx.kColorWhite or gfx.kColorBlack)

    if effectId == "smoothsailing" then
        self:drawSmoothSailing()
    elseif effectId == "spiral" then
        self:drawSpiral()
    elseif effectId == "tunnelbars" then
        self:drawTunnelBars()
    elseif effectId == "fractal" then
        self:drawFractal()
    elseif effectId == "lines" then
        self:drawLines()
    elseif effectId == "pileup" then
        self:drawPileup()
    elseif effectId == "loopfall" then
        self:drawLoopFall(1)
    elseif effectId == "inversefall" then
        self:drawLoopFall(-1)
    elseif effectId == "polygonstorm" then
        self:drawPolygonStorm()
    elseif effectId == "bubblecloud" then
        self:drawBubbleSet(true)
    elseif effectId == "bubblepop" then
        self:drawBubbleSet(false)
    else
        self:drawMicroRotate()
    end

    self:drawHud()
end
