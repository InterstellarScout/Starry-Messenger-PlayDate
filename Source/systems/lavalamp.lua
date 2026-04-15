--[[
Lava Lamp particle system.

Purpose:
- simulates wall-bound and traveling monochrome bubbles that react to device tilt
- coordinates linger timers, settle phases, collisions, orbit interactions, and wall flips
- powers both the title preview and the full Lava Lamp view
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

LavaLamp = {}
LavaLamp.__index = LavaLamp

LavaLamp.MODE_STANDARD = "standard"
LavaLamp.MODE_INVERSE = "inverse"

local BOTTOM_LINGER_FRAMES <const> = 165
local TOP_LINGER_VALUE_MIN <const> = 6
local TOP_LINGER_VALUE_MAX <const> = 20
local TOP_LINGER_UNIT_FRAMES <const> = 6
local FLOW_SMOOTHING <const> = 0.06
local ORIENTATION_RETARGET_DOT_THRESHOLD <const> = 0.972
local ACTIVE_DRAG <const> = 0.9
local ACTIVE_MAX_ACCELERATION <const> = 0.09
local ACTIVE_COLLISION_DISTANCE_SCALE <const> = 0.9
local ACTIVE_COLLISION_SQUEEZE_SCALE <const> = 0.2
local ACTIVE_COLLISION_BOUNCE_SCALE <const> = 0.34
local ACTIVE_COLLISION_DAMPING <const> = 0.92
local ACTIVE_COLLISION_SLIDE_DAMPING <const> = 0.18
local ACTIVE_MAX_SPEED_PADDING <const> = 0.95
local WALL_SETTLE_FRAMES <const> = 18
local SETTLING_COLLISION_DISTANCE_SCALE <const> = 0.9
local SETTLING_COLLISION_SQUEEZE_SCALE <const> = 0.08
local SETTLING_COLLISION_SLIDE_SCALE <const> = 0.12
local INITIAL_SPAWN_PADDING <const> = 4
local INITIAL_SPAWN_ATTEMPTS <const> = 80
local ANCHOR_ATTACH_SPEED_SCALE <const> = 0.32
local ANCHOR_SLIDE_SPEED_SCALE <const> = 0.58
local ANCHOR_SPREAD_MARGIN <const> = 10
local EDGE_MARGIN <const> = 1
local BUBBLE_TRAVEL_SPEED_MIN <const> = 0.38
local BUBBLE_TRAVEL_SPEED_MAX <const> = 0.72
local TRAVEL_TIME_MULTIPLIER_MIN <const> = 1
local TRAVEL_TIME_MULTIPLIER_MAX <const> = 3
local OPPOSING_CONTACT_DISTANCE_SCALE <const> = 0.18
local ORBIT_DURATION_MIN_FRAMES <const> = 30
local ORBIT_DURATION_MAX_FRAMES <const> = 60
local ORBIT_RADIUS_SQUEEZE_SCALE <const> = 0.12
local ORBIT_CENTER_DRIFT_SCALE <const> = 0.78
local TIMER_SYNC_WINDOW_FRAMES <const> = 60
local TIMER_RESHUFFLE_MIN_CLUSTER <const> = 4
local TIMER_RESHUFFLE_COOLDOWN_FRAMES <const> = 45
local WALL_FLIP_DOT_THRESHOLD <const> = -0.94
local WALL_FLIP_COOLDOWN_FRAMES <const> = 18
local CONTACT_FILL_DISTANCE_SCALE <const> = 0.8

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function lerp(a, b, t)
    return a + ((b - a) * t)
end

local function easeInOutSine(t)
    return 0.5 - (0.5 * math.cos(math.pi * clamp(t, 0, 1)))
end

local function randomRange(minValue, maxValue)
    return minValue + (math.random() * (maxValue - minValue))
end

local function normalizeVector(x, y, defaultX, defaultY)
    local length = math.sqrt((x * x) + (y * y))
    if length < 0.0001 then
        return defaultX, defaultY
    end

    return x / length, y / length
end

local function clampMagnitude(x, y, maxMagnitude)
    local magnitudeSquared = (x * x) + (y * y)
    if magnitudeSquared <= (maxMagnitude * maxMagnitude) then
        return x, y
    end

    local magnitude = math.sqrt(math.max(0.0001, magnitudeSquared))
    local scale = maxMagnitude / magnitude
    return x * scale, y * scale
end

local function projectOffset(x, y, axisX, axisY)
    return (x * axisX) + (y * axisY)
end

function LavaLamp.new(width, height, bubbleCount, options)
    local self = setmetatable({}, LavaLamp)
    self.width = width
    self.height = height
    self.centerX = width / 2
    self.centerY = height / 2
    self.speed = 1
    self.directionAngle = 0
    self.screenAngle = 0
    self.flowX = 0
    self.flowY = -1
    self.targetBubbleCount = bubbleCount or 18
    self.modeId = nil
    self.inverse = false
    self.bubbles = {}
    self.frameNumber = 0
    self.lastTimerReshuffleFrame = -TIMER_RESHUFFLE_COOLDOWN_FRAMES
    self.lastWallFlipFrame = -WALL_FLIP_COOLDOWN_FRAMES
    self:applyOptions(options)

    for index = 1, self.targetBubbleCount do
        self.bubbles[index] = self:createBubble(index)
    end
    self:positionInitialBubbles()

    return self
end

function LavaLamp.getModeLabel(modeId)
    if modeId == LavaLamp.MODE_INVERSE then
        return "Inverse Lava"
    end
    return "Lava Lamp"
end

function LavaLamp:applyOptions(options)
    self.modeId = options and options.modeId or LavaLamp.MODE_STANDARD
    self.inverse = self.modeId == LavaLamp.MODE_INVERSE
end

function LavaLamp:createBubble(index)
    local initialDelay = ((index - 1) % 5) * math.floor(BOTTOM_LINGER_FRAMES / 6)
    local radius = randomRange(10, 18)
    return {
        x = randomRange(radius + 6, self.width - radius - 6),
        y = randomRange(radius + 6, self.height - radius - 6),
        vx = 0,
        vy = 0,
        radius = radius,
        travelSpeed = randomRange(BUBBLE_TRAVEL_SPEED_MIN, BUBBLE_TRAVEL_SPEED_MAX),
        state = "bottom",
        lingerValue = math.random(TOP_LINGER_VALUE_MIN, TOP_LINGER_VALUE_MAX),
        lingerFrames = initialDelay,
        targetSide = "top",
        settleFrames = 0,
        travelFrames = 0,
        travelFrameLimit = 0,
        orbitPartner = nil,
        orbitLeader = false,
        orbitElapsedFrames = 0,
        orbitDurationFrames = 0,
        orbitDirection = 1,
        orbitCenterX = 0,
        orbitCenterY = 0,
        orbitCenterVx = 0,
        orbitCenterVy = 0,
        orbitStartAngle = 0,
        orbitRadius = 0,
        orbitResumeState = nil
    }
end

function LavaLamp:positionInitialBubbles()
    for index, bubble in ipairs(self.bubbles) do
        local placed = false
        for _ = 1, INITIAL_SPAWN_ATTEMPTS do
            local candidateX = randomRange(bubble.radius + 6, self.width - bubble.radius - 6)
            local candidateY = randomRange(bubble.radius + 6, self.height - bubble.radius - 6)
            local overlaps = false

            for otherIndex = 1, index - 1 do
                local other = self.bubbles[otherIndex]
                local dx = candidateX - other.x
                local dy = candidateY - other.y
                local minDistance = bubble.radius + other.radius + INITIAL_SPAWN_PADDING
                if ((dx * dx) + (dy * dy)) < (minDistance * minDistance) then
                    overlaps = true
                    break
                end
            end

            if not overlaps then
                bubble.x = candidateX
                bubble.y = candidateY
                placed = true
                break
            end
        end

        if not placed then
            bubble.x = randomRange(bubble.radius + 6, self.width - bubble.radius - 6)
            bubble.y = randomRange(bubble.radius + 6, self.height - bubble.radius - 6)
        end
    end
end

function LavaLamp:activate()
    if not pd.accelerometerIsRunning() then
        pd.startAccelerometer()
    end
end

function LavaLamp:shutdown()
    if pd.accelerometerIsRunning() then
        pd.stopAccelerometer()
    end
end

function LavaLamp:stepSpeed(direction)
    if direction == 0 then
        return
    end

    self.speed = clamp(self.speed + (direction * 0.1), 0.5, 1.8)
end

function LavaLamp:rotateDirection(_deltaDegrees)
end

function LavaLamp:movePerspective(_deltaX, _deltaY)
end

function LavaLamp:rotateScreen(deltaDegrees)
    self.screenAngle = self.screenAngle + deltaDegrees
end

function LavaLamp:getFlowBasis()
    local flowX, flowY = normalizeVector(self.flowX, self.flowY, 0, -1)
    return flowX, flowY, -flowY, flowX
end

function LavaLamp:getBoundsAlong(flowX, flowY)
    local corners = {
        { x = 0, y = 0 },
        { x = self.width, y = 0 },
        { x = 0, y = self.height },
        { x = self.width, y = self.height }
    }

    local topAlong = -math.huge
    local bottomAlong = math.huge

    for _, corner in ipairs(corners) do
        local along = projectOffset(corner.x - self.centerX, corner.y - self.centerY, flowX, flowY)
        if along > topAlong then
            topAlong = along
        end
        if along < bottomAlong then
            bottomAlong = along
        end
    end

    return topAlong, bottomAlong
end

function LavaLamp:getBoundsPerp(perpX, perpY)
    local corners = {
        { x = 0, y = 0 },
        { x = self.width, y = 0 },
        { x = 0, y = self.height },
        { x = self.width, y = self.height }
    }

    local minPerp = math.huge
    local maxPerp = -math.huge

    for _, corner in ipairs(corners) do
        local perp = projectOffset(corner.x - self.centerX, corner.y - self.centerY, perpX, perpY)
        if perp < minPerp then
            minPerp = perp
        end
        if perp > maxPerp then
            maxPerp = perp
        end
    end

    return minPerp, maxPerp
end

function LavaLamp:projectBubble(bubble, flowX, flowY, perpX, perpY)
    local dx = bubble.x - self.centerX
    local dy = bubble.y - self.centerY
    return projectOffset(dx, dy, flowX, flowY), projectOffset(dx, dy, perpX, perpY)
end

function LavaLamp:pointFromAlongPerp(along, perp, flowX, flowY, perpX, perpY)
    return self.centerX + (flowX * along) + (perpX * perp), self.centerY + (flowY * along) + (perpY * perp)
end

function LavaLamp:getTargetAlong(side, boundaryAlong, bubble)
    if side == "top" then
        return boundaryAlong - bubble.radius - EDGE_MARGIN
    end

    return boundaryAlong + bubble.radius + EDGE_MARGIN
end

function LavaLamp:clampBubbleToScreen(bubble)
    bubble.x = clamp(bubble.x, bubble.radius, self.width - bubble.radius)
    bubble.y = clamp(bubble.y, bubble.radius, self.height - bubble.radius)
end

function LavaLamp:getTopLingerFrames(bubble)
    return bubble.lingerValue * TOP_LINGER_UNIT_FRAMES
end

function LavaLamp:assignNextTopLinger(bubble)
    bubble.lingerValue = math.random(TOP_LINGER_VALUE_MIN, TOP_LINGER_VALUE_MAX)
end

function LavaLamp:getBaseLingerFrames(side, bubble)
    if side == "top" then
        return self:getTopLingerFrames(bubble)
    end

    return BOTTOM_LINGER_FRAMES
end

function LavaLamp:getRandomTravelFrameLimit(side, bubble)
    local baseFrames = self:getBaseLingerFrames(side, bubble)
    return math.random(
        math.max(WALL_SETTLE_FRAMES, baseFrames * TRAVEL_TIME_MULTIPLIER_MIN),
        math.max(WALL_SETTLE_FRAMES + 1, baseFrames * TRAVEL_TIME_MULTIPLIER_MAX)
    )
end

function LavaLamp:getBubbleSideState(bubble)
    if bubble.state == "top" or bubble.state == "settling_top" then
        return "top"
    elseif bubble.state == "bottom" or bubble.state == "settling_bottom" then
        return "bottom"
    end
    return nil
end

function LavaLamp:isBubbleTraveling(bubble)
    return bubble.state == "rising" or bubble.state == "falling"
end

function LavaLamp:getBubbleMaxSpeed(bubble)
    return (bubble.travelSpeed * self.speed) + ACTIVE_MAX_SPEED_PADDING
end

function LavaLamp:getBackgroundColor()
    if self.inverse then
        return gfx.kColorWhite
    end
    return gfx.kColorBlack
end

function LavaLamp:getForegroundColor()
    if self.inverse then
        return gfx.kColorBlack
    end
    return gfx.kColorWhite
end

function LavaLamp:clearOrbitState(bubble, preserveState)
    bubble.orbitPartner = nil
    bubble.orbitLeader = false
    bubble.orbitElapsedFrames = 0
    bubble.orbitDurationFrames = 0
    bubble.orbitCenterVx = 0
    bubble.orbitCenterVy = 0
    bubble.orbitRadius = 0
    if not preserveState then
        bubble.orbitResumeState = nil
    end
end

function LavaLamp:getAnchoredSlideLimit(bubble)
    local travelLimit = math.min(bubble.travelSpeed * self.speed, BUBBLE_TRAVEL_SPEED_MAX * self.speed)
    return math.max(0.2, travelLimit * ANCHOR_SLIDE_SPEED_SCALE)
end

function LavaLamp:getAnchoredAttachLimit(bubble)
    return math.max(0.14, bubble.travelSpeed * self.speed * ANCHOR_ATTACH_SPEED_SCALE)
end

function LavaLamp:updateAnchoredSpreadTargets(flowX, flowY, perpX, perpY)
    local minPerp, maxPerp = self:getBoundsPerp(perpX, perpY)
    local sides = { "top", "bottom" }

    for _, side in ipairs(sides) do
        local anchored = {}
        local maxRadius = 0

        for _, bubble in ipairs(self.bubbles) do
            if bubble.state == side or bubble.state == ("settling_" .. side) then
                local _, perp = self:projectBubble(bubble, flowX, flowY, perpX, perpY)
                anchored[#anchored + 1] = { bubble = bubble, perp = perp }
                if bubble.radius > maxRadius then
                    maxRadius = bubble.radius
                end
            end
        end

        table.sort(anchored, function(a, b)
            return a.perp < b.perp
        end)

        local edgePadding = maxRadius + ANCHOR_SPREAD_MARGIN
        local startPerp = minPerp + edgePadding
        local endPerp = maxPerp - edgePadding

        if #anchored == 1 then
            anchored[1].bubble.anchorPerp = 0
        elseif #anchored > 1 then
            if startPerp > endPerp then
                local midpoint = (minPerp + maxPerp) * 0.5
                startPerp = midpoint
                endPerp = midpoint
            end

            for index, item in ipairs(anchored) do
                local t = (index - 1) / (#anchored - 1)
                item.bubble.anchorPerp = lerp(startPerp, endPerp, t)
            end
        end
    end
end

function LavaLamp:beginSettling(bubble, targetSide)
    bubble.state = targetSide == "top" and "settling_top" or "settling_bottom"
    bubble.targetSide = targetSide
    bubble.settleFrames = math.max(WALL_SETTLE_FRAMES, math.floor((bubble.travelFrameLimit or WALL_SETTLE_FRAMES) * 0.3))
    bubble.vx = bubble.vx * 0.35
    bubble.vy = bubble.vy * 0.35
end

function LavaLamp:anchorBubble(bubble, side, flowX, flowY, perpX, perpY, instant)
    local topAlong, bottomAlong = self:getBoundsAlong(flowX, flowY)
    local along, perp = self:projectBubble(bubble, flowX, flowY, perpX, perpY)
    local boundaryAlong = side == "top" and topAlong or bottomAlong
    local targetAlong = self:getTargetAlong(side, boundaryAlong, bubble)
    local targetPerp = bubble.anchorPerp or perp

    if instant then
        local targetX, targetY = self:pointFromAlongPerp(targetAlong, targetPerp, flowX, flowY, perpX, perpY)
        bubble.x = targetX
        bubble.y = targetY
    else
        local nextAlong = along + clamp(targetAlong - along, -self:getAnchoredAttachLimit(bubble), self:getAnchoredAttachLimit(bubble))
        local nextPerp = perp + clamp(targetPerp - perp, -self:getAnchoredSlideLimit(bubble), self:getAnchoredSlideLimit(bubble))
        bubble.x, bubble.y = self:pointFromAlongPerp(nextAlong, nextPerp, flowX, flowY, perpX, perpY)
    end

    bubble.vx = 0
    bubble.vy = 0
    self:clampBubbleToScreen(bubble)
end

function LavaLamp:startTravel(bubble, targetSide)
    local flowX, flowY = self:getFlowBasis()
    local directionSign = targetSide == "top" and 1 or -1
    bubble.state = targetSide == "top" and "rising" or "falling"
    bubble.targetSide = targetSide
    bubble.travelFrames = 0
    bubble.vx = flowX * bubble.travelSpeed * directionSign * 2.4
    bubble.vy = flowY * bubble.travelSpeed * directionSign * 2.4
    if targetSide == "top" then
        self:assignNextTopLinger(bubble)
    end
    bubble.travelFrameLimit = self:getRandomTravelFrameLimit(targetSide, bubble)
    self:clearOrbitState(bubble)
end

function LavaLamp:updateFlow()
    local gravityX, gravityY = pd.readAccelerometer()
    if gravityX == nil or gravityY == nil then
        gravityX = 0
        gravityY = 1
    end

    local riseX, riseY = normalizeVector(-gravityX, -gravityY, 0, -1)
    local currentX, currentY = normalizeVector(self.flowX, self.flowY, 0, -1)
    local dot = clamp((currentX * riseX) + (currentY * riseY), -1, 1)
    if dot <= WALL_FLIP_DOT_THRESHOLD and (self.frameNumber - self.lastWallFlipFrame) >= WALL_FLIP_COOLDOWN_FRAMES then
        self:handleWallFlip()
        self.lastWallFlipFrame = self.frameNumber
    end
    if dot > ORIENTATION_RETARGET_DOT_THRESHOLD then
        riseX = currentX
        riseY = currentY
    end
    local smoothedX = (currentX * (1 - FLOW_SMOOTHING)) + (riseX * FLOW_SMOOTHING)
    local smoothedY = (currentY * (1 - FLOW_SMOOTHING)) + (riseY * FLOW_SMOOTHING)
    self.flowX, self.flowY = normalizeVector(smoothedX, smoothedY, 0, -1)
end

function LavaLamp:handleWallFlip()
    for _, bubble in ipairs(self.bubbles) do
        if bubble.state == "top" then
            bubble.state = "bottom"
            bubble.targetSide = "top"
        elseif bubble.state == "bottom" then
            bubble.state = "top"
            bubble.targetSide = "bottom"
        elseif bubble.state == "settling_top" then
            bubble.state = "settling_bottom"
            bubble.targetSide = "bottom"
        elseif bubble.state == "settling_bottom" then
            bubble.state = "settling_top"
            bubble.targetSide = "top"
        end
    end
end

function LavaLamp:updateAnchoredBubble(bubble, flowX, flowY, perpX, perpY)
    if bubble.state == "top" then
        self:anchorBubble(bubble, "top", flowX, flowY, perpX, perpY, false)
        bubble.lingerFrames = math.max(0, bubble.lingerFrames - 1)
        if bubble.lingerFrames <= 0 then
            self:startTravel(bubble, "bottom")
        end
    elseif bubble.state == "bottom" then
        self:anchorBubble(bubble, "bottom", flowX, flowY, perpX, perpY, false)
        bubble.lingerFrames = math.max(0, bubble.lingerFrames - 1)
        if bubble.lingerFrames <= 0 then
            self:startTravel(bubble, "top")
        end
    end
end

function LavaLamp:updateSettlingBubble(bubble, flowX, flowY, perpX, perpY)
    local side = bubble.state == "settling_top" and "top" or "bottom"
    self:anchorBubble(bubble, side, flowX, flowY, perpX, perpY, false)
    bubble.settleFrames = math.max(0, (bubble.settleFrames or 0) - 1)

    if bubble.settleFrames <= 0 then
        bubble.state = side
        bubble.vx = 0
        bubble.vy = 0
        bubble.travelFrames = 0
        bubble.travelFrameLimit = 0
        self:clearOrbitState(bubble)
        if side == "top" then
            bubble.lingerFrames = self:getTopLingerFrames(bubble)
        else
            bubble.lingerFrames = BOTTOM_LINGER_FRAMES
        end
    end
end

function LavaLamp:canOrbitPair(bubbleA, bubbleB)
    if bubbleA == bubbleB then
        return false
    end

    if bubbleA.orbitPartner ~= nil or bubbleB.orbitPartner ~= nil then
        return false
    end

    local sideA = self:getBubbleSideState(bubbleA)
    local sideB = self:getBubbleSideState(bubbleB)

    if bubbleA.state == "falling" and sideB == "top" then
        return true
    elseif bubbleB.state == "falling" and sideA == "top" then
        return true
    elseif bubbleA.state == "rising" and sideB == "bottom" then
        return true
    elseif bubbleB.state == "rising" and sideA == "bottom" then
        return true
    end

    return false
end

function LavaLamp:getOrbitDirection()
    if math.abs(self.flowY) >= math.abs(self.flowX) then
        if self.flowY <= 0 then
            return 1
        end
        return -1
    end

    if self.flowX >= 0 then
        return 1
    end
    return -1
end

function LavaLamp:beginOrbit(bubbleA, bubbleB)
    local dx = bubbleB.x - bubbleA.x
    local dy = bubbleB.y - bubbleA.y
    local distance = math.sqrt(math.max(0.0001, (dx * dx) + (dy * dy)))
    local midpointX = (bubbleA.x + bubbleB.x) * 0.5
    local midpointY = (bubbleA.y + bubbleB.y) * 0.5
    local durationFrames = math.random(ORBIT_DURATION_MIN_FRAMES, ORBIT_DURATION_MAX_FRAMES)
    local direction = self:getOrbitDirection()
    local maxSpeedA = self:getBubbleMaxSpeed(bubbleA)
    local maxSpeedB = self:getBubbleMaxSpeed(bubbleB)

    bubbleA.orbitPartner = bubbleB
    bubbleB.orbitPartner = bubbleA
    bubbleA.orbitLeader = true
    bubbleB.orbitLeader = false
    bubbleA.orbitElapsedFrames = 0
    bubbleB.orbitElapsedFrames = 0
    bubbleA.orbitDurationFrames = durationFrames
    bubbleB.orbitDurationFrames = durationFrames
    bubbleA.orbitDirection = direction
    bubbleB.orbitDirection = direction
    bubbleA.orbitCenterX = midpointX
    bubbleB.orbitCenterX = midpointX
    bubbleA.orbitCenterY = midpointY
    bubbleB.orbitCenterY = midpointY
    bubbleA.orbitCenterVx = clamp(((bubbleA.vx + bubbleB.vx) * 0.5) * ORBIT_CENTER_DRIFT_SCALE, -maxSpeedA, maxSpeedA)
    bubbleB.orbitCenterVx = bubbleA.orbitCenterVx
    bubbleA.orbitCenterVy = clamp(((bubbleA.vy + bubbleB.vy) * 0.5) * ORBIT_CENTER_DRIFT_SCALE, -maxSpeedA, maxSpeedA)
    bubbleB.orbitCenterVy = bubbleA.orbitCenterVy
    bubbleA.orbitStartAngle = math.atan(bubbleA.y - midpointY, bubbleA.x - midpointX)
    bubbleB.orbitStartAngle = math.atan(bubbleB.y - midpointY, bubbleB.x - midpointX)
    bubbleA.orbitRadius = math.max(1, distance * 0.5)
    bubbleB.orbitRadius = bubbleA.orbitRadius
    bubbleA.orbitResumeState = bubbleA.state
    bubbleB.orbitResumeState = bubbleB.state
    bubbleA.state = "orbiting"
    bubbleB.state = "orbiting"
end

function LavaLamp:updateOrbitPair(leader)
    local partner = leader.orbitPartner
    if partner == nil or partner.orbitPartner ~= leader then
        self:clearOrbitState(leader)
        return
    end

    local durationFrames = math.max(1, leader.orbitDurationFrames or ORBIT_DURATION_MIN_FRAMES)
    local nextElapsed = math.min(durationFrames, (leader.orbitElapsedFrames or 0) + 1)
    local t = nextElapsed / durationFrames
    local easedT = easeInOutSine(t)
    local angleStep = leader.orbitDirection * math.pi * easedT
    local orbitRadius = math.max(1, leader.orbitRadius * (1 - (ORBIT_RADIUS_SQUEEZE_SCALE * math.sin(math.pi * easedT))))
    local centerX = leader.orbitCenterX + leader.orbitCenterVx
    local centerY = leader.orbitCenterY + leader.orbitCenterVy
    local nextAX = centerX + (math.cos(leader.orbitStartAngle + angleStep) * orbitRadius)
    local nextAY = centerY + (math.sin(leader.orbitStartAngle + angleStep) * orbitRadius)
    local nextBX = centerX + (math.cos(partner.orbitStartAngle + angleStep) * orbitRadius)
    local nextBY = centerY + (math.sin(partner.orbitStartAngle + angleStep) * orbitRadius)
    local maxSpeedA = self:getBubbleMaxSpeed(leader)
    local maxSpeedB = self:getBubbleMaxSpeed(partner)

    local deltaAX = nextAX - leader.x
    local deltaAY = nextAY - leader.y
    local deltaBX = nextBX - partner.x
    local deltaBY = nextBY - partner.y
    deltaAX, deltaAY = clampMagnitude(deltaAX, deltaAY, maxSpeedA)
    deltaBX, deltaBY = clampMagnitude(deltaBX, deltaBY, maxSpeedB)

    leader.x = leader.x + deltaAX
    leader.y = leader.y + deltaAY
    partner.x = partner.x + deltaBX
    partner.y = partner.y + deltaBY
    leader.vx = deltaAX
    leader.vy = deltaAY
    partner.vx = deltaBX
    partner.vy = deltaBY
    self:clampBubbleToScreen(leader)
    self:clampBubbleToScreen(partner)

    leader.orbitCenterX = centerX
    partner.orbitCenterX = centerX
    leader.orbitCenterY = centerY
    partner.orbitCenterY = centerY
    leader.orbitElapsedFrames = nextElapsed
    partner.orbitElapsedFrames = nextElapsed

    if nextElapsed >= durationFrames then
        local resumeStateA = leader.orbitResumeState or "rising"
        local resumeStateB = partner.orbitResumeState or "falling"
        self:clearOrbitState(leader)
        self:clearOrbitState(partner)
        leader.state = resumeStateA
        partner.state = resumeStateB
    end
end

function LavaLamp:resolveOpposingOrbitContacts()
    for index = 1, #self.bubbles - 1 do
        local bubbleA = self.bubbles[index]
        if bubbleA.state ~= "orbiting" then
            for otherIndex = index + 1, #self.bubbles do
                local bubbleB = self.bubbles[otherIndex]
                if bubbleB.state ~= "orbiting" and self:canOrbitPair(bubbleA, bubbleB) then
                    local dx = bubbleB.x - bubbleA.x
                    local dy = bubbleB.y - bubbleA.y
                    local triggerDistance = (bubbleA.radius + bubbleB.radius) * OPPOSING_CONTACT_DISTANCE_SCALE
                    if ((dx * dx) + (dy * dy)) <= (triggerDistance * triggerDistance) then
                        self:beginOrbit(bubbleA, bubbleB)
                        break
                    end
                end
            end
        end
    end
end

function LavaLamp:updateTravelingBubble(bubble, flowX, flowY, perpX, perpY)
    local topAlong, bottomAlong = self:getBoundsAlong(flowX, flowY)
    local targetSide = bubble.targetSide or (bubble.state == "rising" and "top" or "bottom")
    local boundaryAlong = targetSide == "top" and topAlong or bottomAlong
    local along = self:projectBubble(bubble, flowX, flowY, perpX, perpY)
    local targetAlong = self:getTargetAlong(targetSide, boundaryAlong, bubble)
    local deltaAlong = targetAlong - along
    local directionSign = deltaAlong >= 0 and 1 or -1
    local desiredSpeed = bubble.travelSpeed * self.speed * directionSign
    local desiredVx = flowX * desiredSpeed
    local desiredVy = flowY * desiredSpeed
    local accelX = clamp(desiredVx - bubble.vx, -ACTIVE_MAX_ACCELERATION, ACTIVE_MAX_ACCELERATION)
    local accelY = clamp(desiredVy - bubble.vy, -ACTIVE_MAX_ACCELERATION, ACTIVE_MAX_ACCELERATION)
    local currentVx = bubble.vx + accelX
    local currentVy = bubble.vy + accelY
    local maxSpeed = self:getBubbleMaxSpeed(bubble)

    currentVx = currentVx * ACTIVE_DRAG
    currentVy = currentVy * ACTIVE_DRAG
    currentVx, currentVy = clampMagnitude(currentVx, currentVy, maxSpeed)
    bubble.travelFrames = (bubble.travelFrames or 0) + 1

    if math.abs(deltaAlong) <= math.max(1.1, math.abs(projectOffset(currentVx, currentVy, flowX, flowY)) + 0.35) then
        bubble.vx = currentVx
        bubble.vy = currentVy
        bubble.x = bubble.x + bubble.vx
        bubble.y = bubble.y + bubble.vy
        self:clampBubbleToScreen(bubble)
        self:beginSettling(bubble, targetSide)
    else
        bubble.vx = currentVx
        bubble.vy = currentVy
        bubble.x = bubble.x + bubble.vx
        bubble.y = bubble.y + bubble.vy
        self:clampBubbleToScreen(bubble)
        if bubble.travelFrameLimit > 0 and bubble.travelFrames >= bubble.travelFrameLimit then
            self:beginSettling(bubble, targetSide)
        end
    end
end

function LavaLamp:resolveActiveCollisions()
    for index = 1, #self.bubbles - 1 do
        local bubbleA = self.bubbles[index]
        if bubbleA.state == "rising" or bubbleA.state == "falling" then
            for otherIndex = index + 1, #self.bubbles do
                local bubbleB = self.bubbles[otherIndex]
                if bubbleB.state == "rising" or bubbleB.state == "falling" then
                    local dx = bubbleB.x - bubbleA.x
                    local dy = bubbleB.y - bubbleA.y
                    local distanceSquared = (dx * dx) + (dy * dy)
                    local targetDistance = (bubbleA.radius + bubbleB.radius) * ACTIVE_COLLISION_DISTANCE_SCALE

                    if distanceSquared < (targetDistance * targetDistance) then
                        local distance = math.sqrt(math.max(0.0001, distanceSquared))
                        local normalX = dx / distance
                        local normalY = dy / distance
                        local tangentX = -normalY
                        local tangentY = normalX
                        local overlap = targetDistance - distance
                        local squeezeDistance = overlap * ACTIVE_COLLISION_SQUEEZE_SCALE
                        local relativeNormalVelocity = ((bubbleB.vx - bubbleA.vx) * normalX) + ((bubbleB.vy - bubbleA.vy) * normalY)
                        local relativeTangentVelocity = ((bubbleB.vx - bubbleA.vx) * tangentX) + ((bubbleB.vy - bubbleA.vy) * tangentY)

                        bubbleA.x = bubbleA.x - (normalX * squeezeDistance * 0.5)
                        bubbleA.y = bubbleA.y - (normalY * squeezeDistance * 0.5)
                        bubbleB.x = bubbleB.x + (normalX * squeezeDistance * 0.5)
                        bubbleB.y = bubbleB.y + (normalY * squeezeDistance * 0.5)

                        if relativeNormalVelocity < 0 then
                            local bounceImpulse = -relativeNormalVelocity * ACTIVE_COLLISION_BOUNCE_SCALE
                            bubbleA.vx = bubbleA.vx - (normalX * bounceImpulse * 0.5)
                            bubbleA.vy = bubbleA.vy - (normalY * bounceImpulse * 0.5)
                            bubbleB.vx = bubbleB.vx + (normalX * bounceImpulse * 0.5)
                            bubbleB.vy = bubbleB.vy + (normalY * bounceImpulse * 0.5)
                        end

                        local slideCorrection = relativeTangentVelocity * ACTIVE_COLLISION_SLIDE_DAMPING
                        bubbleA.vx = (bubbleA.vx + (tangentX * slideCorrection * 0.5)) * ACTIVE_COLLISION_DAMPING
                        bubbleA.vy = (bubbleA.vy + (tangentY * slideCorrection * 0.5)) * ACTIVE_COLLISION_DAMPING
                        bubbleB.vx = (bubbleB.vx - (tangentX * slideCorrection * 0.5)) * ACTIVE_COLLISION_DAMPING
                        bubbleB.vy = (bubbleB.vy - (tangentY * slideCorrection * 0.5)) * ACTIVE_COLLISION_DAMPING
                        self:clampBubbleToScreen(bubbleA)
                        self:clampBubbleToScreen(bubbleB)
                    end
                end
            end
        end
    end
end

function LavaLamp:resolveSettlingCollisions()
    for index = 1, #self.bubbles - 1 do
        local bubbleA = self.bubbles[index]
        local sideA = bubbleA.state == "top" and "top"
            or (bubbleA.state == "bottom" and "bottom")
            or (bubbleA.state == "settling_top" and "top")
            or (bubbleA.state == "settling_bottom" and "bottom")

        if sideA ~= nil then
            for otherIndex = index + 1, #self.bubbles do
                local bubbleB = self.bubbles[otherIndex]
                local sideB = bubbleB.state == "top" and "top"
                    or (bubbleB.state == "bottom" and "bottom")
                    or (bubbleB.state == "settling_top" and "top")
                    or (bubbleB.state == "settling_bottom" and "bottom")

                if sideA == sideB then
                    local dx = bubbleB.x - bubbleA.x
                    local dy = bubbleB.y - bubbleA.y
                    local distanceSquared = (dx * dx) + (dy * dy)
                    local targetDistance = (bubbleA.radius + bubbleB.radius) * SETTLING_COLLISION_DISTANCE_SCALE

                    if distanceSquared < (targetDistance * targetDistance) then
                        local distance = math.sqrt(math.max(0.0001, distanceSquared))
                        local normalX = dx / distance
                        local normalY = dy / distance
                        local tangentX = -normalY
                        local tangentY = normalX
                        local overlap = targetDistance - distance
                        local squeezeDistance = overlap * SETTLING_COLLISION_SQUEEZE_SCALE

                        bubbleA.x = bubbleA.x - (normalX * squeezeDistance * 0.5)
                        bubbleA.y = bubbleA.y - (normalY * squeezeDistance * 0.5)
                        bubbleB.x = bubbleB.x + (normalX * squeezeDistance * 0.5)
                        bubbleB.y = bubbleB.y + (normalY * squeezeDistance * 0.5)

                        local slideDirection = ((bubbleB.anchorPerp or bubbleB.x) - (bubbleA.anchorPerp or bubbleA.x)) >= 0 and 1 or -1
                        local slideAmount = overlap * SETTLING_COLLISION_SLIDE_SCALE * slideDirection
                        if bubbleA.state == "settling_top" or bubbleA.state == "settling_bottom" then
                            bubbleA.anchorPerp = (bubbleA.anchorPerp or 0) - slideAmount
                        end
                        if bubbleB.state == "settling_top" or bubbleB.state == "settling_bottom" then
                            bubbleB.anchorPerp = (bubbleB.anchorPerp or 0) + slideAmount
                        end

                        self:clampBubbleToScreen(bubbleA)
                        self:clampBubbleToScreen(bubbleB)
                    end
                end
            end
        end
    end
end

function LavaLamp:getNearFlipAnchoredBubbles(side)
    local nearFlip = {}
    local total = 0

    for _, bubble in ipairs(self.bubbles) do
        if bubble.state == side then
            total = total + 1
            if (bubble.lingerFrames or 0) <= TIMER_SYNC_WINDOW_FRAMES then
                nearFlip[#nearFlip + 1] = bubble
            end
        end
    end

    return nearFlip, total
end

function LavaLamp:assignReshuffledLingerFrames(side, bubble, offsetIndex)
    if side == "top" then
        self:assignNextTopLinger(bubble)
        local baseFrames = self:getTopLingerFrames(bubble)
        bubble.lingerFrames = math.random(TIMER_SYNC_WINDOW_FRAMES + 12, math.max(TIMER_SYNC_WINDOW_FRAMES + 18, baseFrames))
    else
        bubble.lingerFrames = math.random(TIMER_SYNC_WINDOW_FRAMES + 12, BOTTOM_LINGER_FRAMES)
    end

    bubble.lingerFrames = bubble.lingerFrames + ((offsetIndex - 1) * 4)
end

function LavaLamp:reshuffleCrowdedFlipTimers()
    if (self.frameNumber - self.lastTimerReshuffleFrame) < TIMER_RESHUFFLE_COOLDOWN_FRAMES then
        return
    end

    local topNearFlip, topTotal = self:getNearFlipAnchoredBubbles("top")
    local bottomNearFlip, bottomTotal = self:getNearFlipAnchoredBubbles("bottom")

    if topTotal > 0 and #topNearFlip == topTotal and #bottomNearFlip >= TIMER_RESHUFFLE_MIN_CLUSTER then
        for index, bubble in ipairs(bottomNearFlip) do
            self:assignReshuffledLingerFrames("bottom", bubble, index)
        end
        self.lastTimerReshuffleFrame = self.frameNumber
    elseif bottomTotal > 0 and #bottomNearFlip == bottomTotal and #topNearFlip >= TIMER_RESHUFFLE_MIN_CLUSTER then
        for index, bubble in ipairs(topNearFlip) do
            self:assignReshuffledLingerFrames("top", bubble, index)
        end
        self.lastTimerReshuffleFrame = self.frameNumber
    end
end

function LavaLamp:applyCrank(change)
    if math.abs(change) <= 0.01 then
        return
    end

    local flowX, flowY = self:getFlowBasis()
    local impulse = clamp(change * 0.018, -1.8, 1.8)

    for _, bubble in ipairs(self.bubbles) do
        if bubble.state == "rising" or bubble.state == "falling" then
            bubble.x = bubble.x + (flowX * impulse)
            bubble.y = bubble.y + (flowY * impulse)
            self:clampBubbleToScreen(bubble)
        end
    end
end

function LavaLamp:update()
    self.frameNumber = self.frameNumber + 1
    self:updateFlow()

    local flowX, flowY, perpX, perpY = self:getFlowBasis()
    self:updateAnchoredSpreadTargets(flowX, flowY, perpX, perpY)

    for _, bubble in ipairs(self.bubbles) do
        if bubble.state == "top" or bubble.state == "bottom" then
            self:updateAnchoredBubble(bubble, flowX, flowY, perpX, perpY)
        elseif bubble.state == "settling_top" or bubble.state == "settling_bottom" then
            self:updateSettlingBubble(bubble, flowX, flowY, perpX, perpY)
        elseif bubble.state == "orbiting" then
            if bubble.orbitLeader then
                self:updateOrbitPair(bubble)
            end
        else
            self:updateTravelingBubble(bubble, flowX, flowY, perpX, perpY)
        end
    end

    self:resolveActiveCollisions()
    self:resolveOpposingOrbitContacts()
    self:resolveSettlingCollisions()
    self:reshuffleCrowdedFlipTimers()
end

function LavaLamp:getBubbleRenderRadius(index)
    local bubble = self.bubbles[index]
    local renderRadius = bubble.radius
    local touchingCount = 0
    local mergeGroup = bubble.state == "top" and "top"
        or (bubble.state == "bottom" and "bottom")
        or (bubble.state == "settling_top" and "top")
        or (bubble.state == "settling_bottom" and "bottom")
        or nil

    if mergeGroup == nil then
        return renderRadius
    end

    for otherIndex, otherBubble in ipairs(self.bubbles) do
        if otherIndex ~= index and otherBubble.state == mergeGroup then
            local dx = otherBubble.x - bubble.x
            local dy = otherBubble.y - bubble.y
            local touchDistance = (bubble.radius + otherBubble.radius) * 0.72
            if ((dx * dx) + (dy * dy)) <= (touchDistance * touchDistance) then
                touchingCount = touchingCount + 1
            end
        end
    end

    if touchingCount > 0 then
        renderRadius = renderRadius * (1 + math.min(0.2, touchingCount * 0.06))
    end

    return renderRadius
end

function LavaLamp:getBubbleContactGroup(bubble)
    return bubble.state == "top" and "top"
        or (bubble.state == "bottom" and "bottom")
        or (bubble.state == "settling_top" and "top")
        or (bubble.state == "settling_bottom" and "bottom")
        or nil
end

function LavaLamp:getContactFillClusters()
    local clusters = {}
    local visited = {}

    for index, bubble in ipairs(self.bubbles) do
        if not visited[index] then
            local group = self:getBubbleContactGroup(bubble)
            if group ~= nil then
                local stack = { index }
                local cluster = {}
                visited[index] = true

                while #stack > 0 do
                    local currentIndex = table.remove(stack)
                    cluster[#cluster + 1] = currentIndex
                    local currentBubble = self.bubbles[currentIndex]

                    for otherIndex, otherBubble in ipairs(self.bubbles) do
                        if not visited[otherIndex] and self:getBubbleContactGroup(otherBubble) == group then
                            local dx = otherBubble.x - currentBubble.x
                            local dy = otherBubble.y - currentBubble.y
                            local touchDistance = (currentBubble.radius + otherBubble.radius) * CONTACT_FILL_DISTANCE_SCALE
                            if ((dx * dx) + (dy * dy)) <= (touchDistance * touchDistance) then
                                visited[otherIndex] = true
                                stack[#stack + 1] = otherIndex
                            end
                        end
                    end
                end

                if #cluster >= 4 then
                    clusters[#clusters + 1] = cluster
                end
            end
        end
    end

    return clusters
end

function LavaLamp:drawContactFillCluster(cluster)
    local centerX = 0
    local centerY = 0
    local points = {}

    for _, bubbleIndex in ipairs(cluster) do
        local bubble = self.bubbles[bubbleIndex]
        centerX = centerX + bubble.x
        centerY = centerY + bubble.y
    end

    centerX = centerX / #cluster
    centerY = centerY / #cluster

    for _, bubbleIndex in ipairs(cluster) do
        local bubble = self.bubbles[bubbleIndex]
        points[#points + 1] = {
            x = bubble.x,
            y = bubble.y,
            angle = math.atan(bubble.y - centerY, bubble.x - centerX)
        }
    end

    table.sort(points, function(a, b)
        return a.angle < b.angle
    end)

    for index = 1, #points do
        local current = points[index]
        local nextPoint = points[(index % #points) + 1]
        gfx.fillTriangle(centerX, centerY, current.x, current.y, nextPoint.x, nextPoint.y)
    end
end

function LavaLamp:drawBubble(index)
    local bubble = self.bubbles[index]
    local renderRadius = self:getBubbleRenderRadius(index)
    local diameter = renderRadius * 2
    gfx.fillEllipseInRect(bubble.x - renderRadius, bubble.y - renderRadius, diameter, diameter)
end

function LavaLamp:draw()
    if self.inverse then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(0, 0, self.width, self.height)
    end

    gfx.setColor(self:getForegroundColor())

    local fillClusters = self:getContactFillClusters()
    for _, cluster in ipairs(fillClusters) do
        self:drawContactFillCluster(cluster)
    end

    for index = 1, #self.bubbles do
        self:drawBubble(index)
    end
end
