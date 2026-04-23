import "gameconfig"

local pd <const> = playdate
local gfx <const> = pd.graphics
local WACKY_CONFIG <const> = GameConfig and GameConfig.wacky or {}

WackyInflatable = {}
WackyInflatable.__index = WackyInflatable

local SEGMENT_COUNT <const> = WACKY_CONFIG.segmentCount or 10
local BODY_LENGTH <const> = WACKY_CONFIG.bodyLength or 116
local TUBE_WIDTH <const> = WACKY_CONFIG.tubeWidth or 22
local HEAD_RADIUS <const> = WACKY_CONFIG.headRadius or 17
local ARM_LENGTH <const> = WACKY_CONFIG.armLength or 34
local PREVIEW_EXTENDED_FRAMES <const> = WACKY_CONFIG.previewExtendedFrames or 30
local PREVIEW_SETTLE_INFLATION <const> = WACKY_CONFIG.previewSettleInflation or 0.12
local MAX_CRANK_BOOST <const> = WACKY_CONFIG.maxCrankBoost or 1.3
local BODY_GRAVITY <const> = WACKY_CONFIG.bodyGravity or 0.52
local BODY_DRAG <const> = WACKY_CONFIG.bodyDrag or 0.992
local BODY_LIFT_SCALE <const> = WACKY_CONFIG.bodyLiftScale or 0.62
local BODY_SWAY_SCALE <const> = WACKY_CONFIG.bodySwayScale or 0.16
local BODY_CONSTRAINT_PASSES <const> = WACKY_CONFIG.bodyConstraintPasses or 8
local BODY_SELF_AVOID_RADIUS <const> = WACKY_CONFIG.bodySelfAvoidRadius or 18
local BODY_GROUND_BOUNCE <const> = WACKY_CONFIG.bodyGroundBounce or 0.18
local COLLAPSE_GROUND_BOUNCE <const> = WACKY_CONFIG.collapseGroundBounce or 0.05
local CRANK_FLAIL_VERTICAL_SCALE <const> = WACKY_CONFIG.crankFlailVerticalScale or 1.85
local CRANK_FLAIL_HORIZONTAL_SCALE <const> = WACKY_CONFIG.crankFlailHorizontalScale or 1.25
local BODY_SWEEP_LIMIT <const> = WACKY_CONFIG.bodySweepLimit or 170
local CRANK_IDLE_FRAMES <const> = WACKY_CONFIG.crankIdleFrames or 7
local REVERSE_GRAVITY_SCALE <const> = WACKY_CONFIG.reverseGravityScale or 2.6
local GRAVITY_BOOST_DECAY <const> = WACKY_CONFIG.gravityBoostDecay or 0.08
local FALLING_SURPRISE_SPEED <const> = WACKY_CONFIG.fallingSurpriseSpeed or 1.35
local HAT_GROUND_DRAG <const> = WACKY_CONFIG.hatGroundDrag or 0.988
local HAT_GROUND_ROLL_DRAG <const> = WACKY_CONFIG.hatGroundRollDrag or 0.982
local HAT_BOUNCE <const> = WACKY_CONFIG.hatBounce or 0.16

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function sign(value)
    if value < 0 then
        return -1
    elseif value > 0 then
        return 1
    end
    return 0
end

local function lerp(a, b, t)
    return a + ((b - a) * t)
end

local function normalize(x, y)
    local magnitude = math.sqrt((x * x) + (y * y))
    if magnitude <= 0.0001 then
        return 0, -1
    end
    return x / magnitude, y / magnitude
end

local function pointDistance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt((dx * dx) + (dy * dy))
end

local function makeArm(direction)
    return {
        direction = direction,
        shoulderAngle = 0,
        shoulderVelocity = 0,
        elbowAngle = 0,
        elbowVelocity = 0
    }
end

function WackyInflatable.new(width, height, options)
    local self = setmetatable({}, WackyInflatable)
    self.width = width
    self.height = height
    self.preview = options and options.preview == true or false
    self.baseX = math.floor(width * 0.5)
    self.baseY = height - 18
    self.segmentLength = BODY_LENGTH / SEGMENT_COUNT
    self.inflation = 1
    self.targetInflation = self.preview and 1 or 0.16
    self.flopSide = 1
    self.wobblePhase = math.random() * math.pi * 2
    self.frame = 0
    self.crankLift = 0
    self.reverseGravityBoost = 0
    self.crankIdleFrames = CRANK_IDLE_FRAMES
    self.lastCrankDirection = 1
    self.collapseMode = false
    self.isFalling = false
    self.hat = {
        attached = true,
        x = self.baseX,
        y = self.baseY - BODY_LENGTH,
        prevX = self.baseX,
        prevY = self.baseY - BODY_LENGTH,
        rotation = 0,
        angularVelocity = 0
    }
    self.bodyPoints = {}
    self.arms = {
        makeArm(-1),
        makeArm(1)
    }
    self:resetBodyPose(true)
    return self
end

function WackyInflatable:setPreview(isPreview)
    self.preview = isPreview == true
    if self.preview then
        self.frame = 0
        self.inflation = 1
        self.targetInflation = 1
        self:resetBodyPose(true)
    end
end

function WackyInflatable:activate()
end

function WackyInflatable:shutdown()
end

function WackyInflatable:resetBodyPose(fullyExtended)
    self.bodyPoints = {}
    for index = 1, SEGMENT_COUNT + 1 do
        local y = self.baseY - ((index - 1) * self.segmentLength)
        local x = self.baseX
        if not fullyExtended then
            local collapseT = (index - 1) / SEGMENT_COUNT
            x = x + (self.flopSide * collapseT * 36)
            y = y + (collapseT * collapseT * 24)
        end
        self.bodyPoints[index] = {
            x = x,
            y = y,
            prevX = x,
            prevY = y
        }
    end

    local topPoint = self.bodyPoints[#self.bodyPoints]
    local headCenterX = topPoint.x
    local headCenterY = topPoint.y - 10
    self.hat.attached = true
    self.hat.x = headCenterX
    self.hat.y = headCenterY - 23
    self.hat.prevX = self.hat.x
    self.hat.prevY = self.hat.y
    self.hat.rotation = 0
    self.hat.angularVelocity = 0
end

function WackyInflatable:applyCrank(change, acceleratedChange)
    local strength = math.abs(acceleratedChange or 0) + (math.abs(change or 0) * 0.8)
    if strength <= 0.01 then
        return
    end

    if not self.hat.attached then
        self.hat.attached = true
        self.hat.angularVelocity = 0
    end

    local direction = sign((acceleratedChange ~= 0 and acceleratedChange) or change)
    if direction ~= 0 then
        self.lastCrankDirection = direction
        self.flopSide = direction
    end
    self.crankIdleFrames = 0

    local boost = clamp(strength * 0.03, 0.08, MAX_CRANK_BOOST)
    self.crankLift = clamp(self.crankLift + boost, 0, 1.2)
    self.targetInflation = clamp(0.2 + (self.crankLift * 0.85), 0.2, 1)

    if direction < 0 then
        self.reverseGravityBoost = clamp(self.reverseGravityBoost + (strength * 0.02), 0, REVERSE_GRAVITY_SCALE)
    else
        self.reverseGravityBoost = math.max(0, self.reverseGravityBoost - (strength * 0.01))
    end

    local impulse = clamp(strength * 0.055, 0.7, 6.2)
    for index = 2, #self.bodyPoints do
        local point = self.bodyPoints[index]
        local pairDirection = index % 2 == 0 and 1 or -1
        local heightFactor = 0.65 + ((index - 1) / SEGMENT_COUNT)
        local verticalDirection = direction < 0 and -0.65 or 1
        point.prevY = point.prevY + (impulse * CRANK_FLAIL_VERTICAL_SCALE * heightFactor * verticalDirection)
        point.prevX = point.prevX - (direction * pairDirection * impulse * CRANK_FLAIL_HORIZONTAL_SCALE * heightFactor)
    end
end

function WackyInflatable:updateHat(topPoint)
    local headCenterX = topPoint.x
    local headCenterY = topPoint.y - 10
    local headVelocityX = topPoint.x - topPoint.prevX
    local headVelocityY = topPoint.y - topPoint.prevY
    local hatAnchorY = headCenterY - 23
    local headBottomY = headCenterY + HEAD_RADIUS
    local groundContactY = self.baseY - 2
    local headGroundDistance = groundContactY - headBottomY

    if self.hat.attached then
        self.hat.prevX = self.hat.x
        self.hat.prevY = self.hat.y
        self.hat.x = headCenterX
        self.hat.y = hatAnchorY
        self.hat.rotation = clamp(headVelocityX * 0.08, -0.35, 0.35)

        if headGroundDistance <= 5 then
            self.hat.attached = false
            self.hat.prevX = self.hat.x - headVelocityX
            self.hat.prevY = self.hat.y - headVelocityY
            self.hat.angularVelocity = clamp(headVelocityX * 0.025, -0.22, 0.22)
        end
        return
    end

    local velocityX = (self.hat.x - self.hat.prevX) * HAT_GROUND_DRAG
    local velocityY = (self.hat.y - self.hat.prevY) * HAT_GROUND_DRAG
    self.hat.prevX = self.hat.x
    self.hat.prevY = self.hat.y
    self.hat.x = self.hat.x + velocityX
    self.hat.y = self.hat.y + velocityY + BODY_GRAVITY
    self.hat.angularVelocity = self.hat.angularVelocity * 0.992
    self.hat.rotation = self.hat.rotation + self.hat.angularVelocity

    if self.hat.y > (self.baseY - 3) then
        self.hat.y = self.baseY - 3
        self.hat.prevY = self.hat.y + (velocityY * HAT_BOUNCE)
        self.hat.prevX = self.hat.x - (velocityX * HAT_GROUND_ROLL_DRAG)
        self.hat.angularVelocity = self.hat.angularVelocity + (velocityX * 0.01)
    end

    self.hat.x = clamp(self.hat.x, 10, self.width - 10)
    if self.hat.x <= 10 or self.hat.x >= (self.width - 10) then
        self.hat.prevX = self.hat.x + (velocityX * HAT_BOUNCE)
        self.hat.angularVelocity = -self.hat.angularVelocity * 0.7
    end
end

function WackyInflatable:handlePrimaryAction()
    self.collapseMode = not self.collapseMode
end

function WackyInflatable:updatePreviewTarget()
    if not self.preview then
        return
    end

    if self.frame < PREVIEW_EXTENDED_FRAMES then
        self.targetInflation = 1
        return
    end

    self.targetInflation = PREVIEW_SETTLE_INFLATION
end

function WackyInflatable:integrateBodyPoints()
    local lift = self.inflation * BODY_LIFT_SCALE
    local sway = math.sin(self.wobblePhase) * BODY_SWAY_SCALE * (0.25 + self.inflation)
    local gravityScale = 1 + self.reverseGravityBoost

    for index = 2, #self.bodyPoints do
        local point = self.bodyPoints[index]
        local velocityX = (point.x - point.prevX) * BODY_DRAG
        local velocityY = (point.y - point.prevY) * BODY_DRAG
        local normalizedIndex = (index - 1) / SEGMENT_COUNT

        point.prevX = point.x
        point.prevY = point.y
        point.x = point.x + velocityX + (sway * normalizedIndex)
        point.y = point.y + velocityY + (BODY_GRAVITY * gravityScale) - (lift * normalizedIndex)
    end
end

function WackyInflatable:constrainBodyLengths()
    local base = self.bodyPoints[1]
    base.x = self.baseX
    base.y = self.baseY
    base.prevX = self.baseX
    base.prevY = self.baseY

    for _ = 1, BODY_CONSTRAINT_PASSES do
        self.bodyPoints[1].x = self.baseX
        self.bodyPoints[1].y = self.baseY

        for index = 1, #self.bodyPoints - 1 do
            local a = self.bodyPoints[index]
            local b = self.bodyPoints[index + 1]
            local dx = b.x - a.x
            local dy = b.y - a.y
            local distance = math.sqrt((dx * dx) + (dy * dy))
            if distance <= 0.0001 then
                distance = 0.0001
                dx = 0
                dy = -1
            end

            local difference = (distance - self.segmentLength) / distance
            if index == 1 then
                b.x = b.x - (dx * difference)
                b.y = b.y - (dy * difference)
            else
                local adjustX = dx * difference * 0.5
                local adjustY = dy * difference * 0.5
                a.x = a.x + adjustX
                a.y = a.y + adjustY
                b.x = b.x - adjustX
                b.y = b.y - adjustY
            end
        end

        local allowCollapse = self.collapseMode and self.crankIdleFrames >= CRANK_IDLE_FRAMES

        for index = 2, #self.bodyPoints do
            local point = self.bodyPoints[index]
            if not allowCollapse then
                for otherIndex = 1, index - 2 do
                    local other = self.bodyPoints[otherIndex]
                    local dx = point.x - other.x
                    local dy = point.y - other.y
                    local distance = math.sqrt((dx * dx) + (dy * dy))
                    if distance < BODY_SELF_AVOID_RADIUS and distance > 0.0001 then
                        local push = (BODY_SELF_AVOID_RADIUS - distance) / distance
                        point.x = point.x + (dx * push * 0.35)
                        point.y = point.y + (dy * push * 0.35)
                    end
                end
            end

            point.x = clamp(point.x, self.baseX - BODY_SWEEP_LIMIT, self.baseX + BODY_SWEEP_LIMIT)
            if point.y > (self.baseY - 2) then
                local penetration = point.y - (self.baseY - 2)
                point.y = self.baseY - 2
                local bounce = allowCollapse and COLLAPSE_GROUND_BOUNCE or BODY_GROUND_BOUNCE
                point.prevY = point.y + (penetration * bounce)
            end
        end
    end
end

function WackyInflatable:updateBodyPhysics()
    self:updatePreviewTarget()

    if not self.preview then
        self.crankIdleFrames = math.min(CRANK_IDLE_FRAMES, self.crankIdleFrames + 1)
        self.crankLift = math.max(0, self.crankLift - 0.035)
        self.targetInflation = math.max(0.12, self.targetInflation - 0.022)
        self.reverseGravityBoost = math.max(0, self.reverseGravityBoost - GRAVITY_BOOST_DECAY)
    end

    self.inflation = self.inflation + ((self.targetInflation - self.inflation) * 0.16)
    self:integrateBodyPoints()
    self:constrainBodyLengths()

    local topPoint = self.bodyPoints[#self.bodyPoints]
    local leanOffset = topPoint.x - self.baseX
    if math.abs(leanOffset) > 6 then
        self.flopSide = sign(leanOffset)
    end

    self.isFalling = (topPoint.y - topPoint.prevY) > FALLING_SURPRISE_SPEED
    self.wobblePhase = self.wobblePhase + lerp(0.05, 0.14, 1 - self.inflation)
end

function WackyInflatable:updateArmPhysics()
    local shoulderPoint = self.bodyPoints[math.max(3, math.floor(#self.bodyPoints * 0.62))]
    local nextPoint = self.bodyPoints[math.min(#self.bodyPoints, math.max(4, math.floor(#self.bodyPoints * 0.62) + 1))]
    local bodyAngle = math.atan2(nextPoint.y - shoulderPoint.y, nextPoint.x - shoulderPoint.x)
    local flopBias = 1 - self.inflation
    local bodySwing = (shoulderPoint.x - shoulderPoint.prevX) * 0.18

    for _, arm in ipairs(self.arms) do
        local shoulderTarget = bodyAngle + (arm.direction * (0.95 + (flopBias * 0.6))) - bodySwing
        local elbowTarget = (arm.direction * 0.65) + (bodySwing * 0.45)

        arm.shoulderVelocity = (arm.shoulderVelocity + ((shoulderTarget - arm.shoulderAngle) * 0.18)) * 0.78
        arm.elbowVelocity = (arm.elbowVelocity + ((elbowTarget - arm.elbowAngle) * 0.2)) * 0.76

        arm.shoulderAngle = arm.shoulderAngle + arm.shoulderVelocity
        arm.elbowAngle = arm.elbowAngle + arm.elbowVelocity
    end
end

function WackyInflatable:getBodyPoints()
    local points = {}
    for index, point in ipairs(self.bodyPoints) do
        local nextPoint = self.bodyPoints[math.min(#self.bodyPoints, index + 1)]
        local angle = 0
        if nextPoint ~= nil and nextPoint ~= point then
            angle = math.atan2(nextPoint.y - point.y, nextPoint.x - point.x) - (math.pi * 0.5)
        elseif index > 1 then
            local prevPoint = self.bodyPoints[index - 1]
            angle = math.atan2(point.y - prevPoint.y, point.x - prevPoint.x) - (math.pi * 0.5)
        end
        points[#points + 1] = { x = point.x, y = point.y, angle = angle }
    end

    return points
end

function WackyInflatable:drawTube(points)
    local leftPoints = {}
    local rightPoints = {}

    for index, point in ipairs(points) do
        local prevPoint = points[math.max(1, index - 1)]
        local nextPoint = points[math.min(#points, index + 1)]
        local tangentX, tangentY = normalize(nextPoint.x - prevPoint.x, nextPoint.y - prevPoint.y)
        local normalX = -tangentY
        local normalY = tangentX
        local radius = (TUBE_WIDTH * (0.68 + (0.22 * (index / #points)))) * 0.5 * lerp(0.72, 1, self.inflation)
        leftPoints[index] = {
            x = point.x + (normalX * radius),
            y = point.y + (normalY * radius)
        }
        rightPoints[index] = {
            x = point.x - (normalX * radius),
            y = point.y - (normalY * radius)
        }
    end

    for index = 1, #leftPoints - 1 do
        gfx.drawLine(leftPoints[index].x, leftPoints[index].y, leftPoints[index + 1].x, leftPoints[index + 1].y)
        gfx.drawLine(rightPoints[index].x, rightPoints[index].y, rightPoints[index + 1].x, rightPoints[index + 1].y)
    end

    for index = 2, #points - 1 do
        gfx.drawLine(leftPoints[index].x, leftPoints[index].y, rightPoints[index].x, rightPoints[index].y)
    end

    return leftPoints, rightPoints
end

function WackyInflatable:drawArm(shoulderX, shoulderY, bodyAngle, arm)
    local upperAngle = bodyAngle + arm.shoulderAngle
    local elbowX = shoulderX + (math.cos(upperAngle) * ARM_LENGTH)
    local elbowY = shoulderY + (math.sin(upperAngle) * ARM_LENGTH)
    local foreAngle = upperAngle + arm.elbowAngle
    local handX = elbowX + (math.cos(foreAngle) * (ARM_LENGTH * 0.75))
    local handY = elbowY + (math.sin(foreAngle) * (ARM_LENGTH * 0.75))

    gfx.drawLine(shoulderX, shoulderY, elbowX, elbowY)
    gfx.drawLine(elbowX, elbowY, handX, handY)
    gfx.fillCircleAtPoint(handX, handY, 3)
end

function WackyInflatable:drawHat()
    local brimHalfWidth = 10
    local brimHalfHeight = 1.5
    local crownHalfWidth = 6
    local crownHeight = 14
    local cosine = math.cos(self.hat.rotation)
    local sine = math.sin(self.hat.rotation)

    local function rotateOffset(offsetX, offsetY)
        return self.hat.x + ((offsetX * cosine) - (offsetY * sine)), self.hat.y + ((offsetX * sine) + (offsetY * cosine))
    end

    local brimLeftX, brimLeftY = rotateOffset(-brimHalfWidth, 0)
    local brimRightX, brimRightY = rotateOffset(brimHalfWidth, 0)
    local brimBottomLeftX, brimBottomLeftY = rotateOffset(-brimHalfWidth, brimHalfHeight)
    local brimBottomRightX, brimBottomRightY = rotateOffset(brimHalfWidth, brimHalfHeight)
    local crownTopLeftX, crownTopLeftY = rotateOffset(-crownHalfWidth, -crownHeight)
    local crownTopRightX, crownTopRightY = rotateOffset(crownHalfWidth, -crownHeight)
    local crownBottomLeftX, crownBottomLeftY = rotateOffset(-crownHalfWidth, 0)
    local crownBottomRightX, crownBottomRightY = rotateOffset(crownHalfWidth, 0)

    gfx.drawLine(brimLeftX, brimLeftY, brimRightX, brimRightY)
    gfx.drawLine(brimBottomLeftX, brimBottomLeftY, brimBottomRightX, brimBottomRightY)
    gfx.drawLine(crownTopLeftX, crownTopLeftY, crownTopRightX, crownTopRightY)
    gfx.drawLine(crownTopLeftX, crownTopLeftY, crownBottomLeftX, crownBottomLeftY)
    gfx.drawLine(crownTopRightX, crownTopRightY, crownBottomRightX, crownBottomRightY)
    gfx.drawLine(crownBottomLeftX, crownBottomLeftY, crownBottomRightX, crownBottomRightY)
end

function WackyInflatable:drawHead(topPoint)
    local headCenterX = topPoint.x
    local headCenterY = topPoint.y - 10

    gfx.drawCircleAtPoint(headCenterX, headCenterY, HEAD_RADIUS)
    gfx.fillCircleAtPoint(headCenterX - 5, headCenterY - 3, 2)
    gfx.fillCircleAtPoint(headCenterX + 5, headCenterY - 2, 2)
    if self.isFalling then
        gfx.drawCircleAtPoint(headCenterX, headCenterY + 7, 4)
        gfx.fillCircleAtPoint(headCenterX, headCenterY + 7, 2)
        gfx.drawText("!", headCenterX + 8, headCenterY - 16)
    else
        gfx.drawLine(headCenterX - 7, headCenterY + 4, headCenterX - 3, headCenterY + 8)
        gfx.drawLine(headCenterX - 3, headCenterY + 8, headCenterX + 2, headCenterY + 9)
        gfx.drawLine(headCenterX + 2, headCenterY + 9, headCenterX + 7, headCenterY + 5)
    end
    gfx.drawLine(headCenterX + 9, headCenterY - 10, headCenterX + 14, headCenterY - 16)
    gfx.drawLine(headCenterX + 14, headCenterY - 16, headCenterX + 10, headCenterY - 16)
end

function WackyInflatable:update()
    self.frame = self.frame + 1
    self:updateBodyPhysics()
    self:updateArmPhysics()
    self:updateHat(self.bodyPoints[#self.bodyPoints])
end

function WackyInflatable:draw()
    local points = self:getBodyPoints()
    local topPoint = points[#points]
    local shoulderPoint = points[math.max(3, math.floor(#points * 0.62))]

    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)

    gfx.drawLine(self.baseX - 12, self.baseY + 4, self.baseX + 12, self.baseY + 4)
    gfx.drawLine(self.baseX, self.baseY, self.baseX, self.baseY + 8)

    self:drawTube(points)
    self:drawArm(shoulderPoint.x, shoulderPoint.y, shoulderPoint.angle - 1.2, self.arms[1])
    self:drawArm(shoulderPoint.x, shoulderPoint.y, shoulderPoint.angle + 1.2, self.arms[2])
    self:drawHat()
    self:drawHead(topPoint)
end
