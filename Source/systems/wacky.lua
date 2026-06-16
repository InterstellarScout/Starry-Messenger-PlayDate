import "gameconfig"

local pd <const> = playdate
local gfx <const> = pd.graphics
local WACKY_CONFIG <const> = GameConfig and GameConfig.wacky or {}

WackyInflatable = {}
WackyInflatable.__index = WackyInflatable
WackyInflatable.MODE_STANDARD = "standard"
WackyInflatable.MODE_CRAZY_FAMILY = "crazyfamily"

local SEGMENT_COUNT <const> = WACKY_CONFIG.segmentCount or 10
local BODY_LENGTH <const> = WACKY_CONFIG.bodyLength or 116
local TUBE_WIDTH <const> = WACKY_CONFIG.tubeWidth or 22
local HEAD_RADIUS <const> = WACKY_CONFIG.headRadius or 17
local ARM_LENGTH <const> = WACKY_CONFIG.armLength or 34
local ARM_SEGMENT_LENGTHS <const> = {
    ARM_LENGTH * 0.58,
    ARM_LENGTH * 0.42,
    ARM_LENGTH * 0.34
}
local PREVIEW_EXTENDED_FRAMES <const> = WACKY_CONFIG.previewExtendedFrames or 30
local PREVIEW_SETTLE_INFLATION <const> = WACKY_CONFIG.previewSettleInflation or 0.12
local PREVIEW_AUTO_CRANK_FRAMES <const> = 15
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
local AUTO_CRANK_IDLE_FRAMES <const> = WACKY_CONFIG.autoCrankIdleFrames or 150
local AUTO_CRANK_DELAY_MIN_FRAMES <const> = WACKY_CONFIG.autoCrankDelayMinFrames or 6
local AUTO_CRANK_DELAY_MAX_FRAMES <const> = WACKY_CONFIG.autoCrankDelayMaxFrames or 30
local AUTO_CRANK_QUARTER_TURN <const> = WACKY_CONFIG.autoCrankQuarterTurn or 90
local REVERSE_GRAVITY_SCALE <const> = WACKY_CONFIG.reverseGravityScale or 2.6
local GRAVITY_BOOST_DECAY <const> = WACKY_CONFIG.gravityBoostDecay or 0.08
local FALLING_SURPRISE_SPEED <const> = WACKY_CONFIG.fallingSurpriseSpeed or 1.35
local PARTY_TRIGGER_MOVES <const> = WACKY_CONFIG.partyTriggerMoves or 5
local PARTY_RAPID_WINDOW_FRAMES <const> = WACKY_CONFIG.partyRapidWindowFrames or 18
local PARTY_IDLE_FRAMES <const> = WACKY_CONFIG.partyIdleFrames or 30
local PARTY_MIN_CRANK_STRENGTH <const> = WACKY_CONFIG.partyMinCrankStrength or 2.5
local PARTY_DISCO_HIDDEN_Y <const> = -28
local PARTY_DISCO_VISIBLE_Y <const> = 32
local PARTY_DISCO_RADIUS <const> = 17
local PARTY_BACKGROUND_DITHER <const> = 0.12
local REACH_TRIGGER_FRAMES <const> = WACKY_CONFIG.reachTriggerFrames or 150
local REACH_UPWARD_GAP_FRAMES <const> = WACKY_CONFIG.reachUpwardGapFrames or 4
local REACH_DARKEN_DITHER <const> = WACKY_CONFIG.reachDarkenDither or 0.3
local REACH_STAR_COUNT <const> = WACKY_CONFIG.reachStarCount or 44
local REACH_MIN_CRANK_STRENGTH <const> = WACKY_CONFIG.reachMinCrankStrength or 1.2
local WORM_TRIGGER_FRAMES <const> = WACKY_CONFIG.wormTriggerFrames or 150
local WORM_DIRECTION_GAP_FRAMES <const> = WACKY_CONFIG.wormDirectionGapFrames or 4
local WORM_MIN_CRANK_STRENGTH <const> = WACKY_CONFIG.wormMinCrankStrength or 1.2
local WORM_HORIZON_Y_RATIO <const> = WACKY_CONFIG.wormHorizonYRatio or 0.25
local HAT_GROUND_DRAG <const> = WACKY_CONFIG.hatGroundDrag or 0.988
local HAT_GROUND_ROLL_DRAG <const> = WACKY_CONFIG.hatGroundRollDrag or 0.982
local HAT_BOUNCE <const> = WACKY_CONFIG.hatBounce or 0.16
local FAMILY_CONSTRAINT_PASSES <const> = 5
local MOM_HAIR_COUNT <const> = 13
local MOM_HAIR_JOINTS <const> = 5
local MOM_HAIR_CONSTRAINT_PASSES <const> = 3

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function WackyInflatable.getModeLabel(modeId)
    if modeId == WackyInflatable.MODE_CRAZY_FAMILY then
        return "Wacky Family"
    end
    return "Wacky Classic"
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

local function wrapPhase(value)
    local tau = math.pi * 2
    while value < 0 do
        value = value + tau
    end
    while value >= tau do
        value = value - tau
    end
    return value
end

local function makeArm(direction)
    return {
        direction = direction,
        shoulderAngle = 0,
        shoulderVelocity = 0,
        elbowAngle = 0,
        elbowVelocity = 0,
        wristAngle = 0,
        wristVelocity = 0
    }
end

local function makeFamilyPoint(x, y)
    return {
        x = x,
        y = y,
        prevX = x,
        prevY = y
    }
end

local function makeDetachedPiece(kind, x, y, side, scale)
    return {
        kind = kind,
        x = x,
        y = y,
        prevX = x - ((side or 1) * 0.5),
        prevY = y - 0.8,
        rotation = 0,
        angularVelocity = (side or 1) * 0.06,
        side = side or 1,
        scale = scale or 1,
        attached = true
    }
end

local function getMomHairRoot(member, hair, headCenterX, headCenterY)
    local radius = HEAD_RADIUS * member.scale * 0.92
    return headCenterX + (math.cos(hair.rootAngle) * radius),
        headCenterY + (math.sin(hair.rootAngle) * radius)
end

local function makeCrazyFamilyMember(role, baseX, baseY, scale, hangDirection)
    hangDirection = hangDirection or -1
    local segmentCount = SEGMENT_COUNT
    local segmentLength = (BODY_LENGTH * scale) / segmentCount
    local member = {
        role = role,
        baseX = baseX,
        baseY = baseY,
        scale = scale,
        segmentCount = segmentCount,
        segmentLength = segmentLength,
        phase = math.random() * math.pi * 2,
        lift = 0.2,
        reverseGravityBoost = 0,
        isFalling = false,
        flopSide = role == "mom" and -1 or 1,
        points = {},
        hairAttached = true,
        accessories = {}
    }

    for index = 1, segmentCount + 1 do
        local y = baseY + (hangDirection * (index - 1) * segmentLength)
        local x = baseX + (math.sin(index * 0.45) * 2 * scale)
        member.points[index] = makeFamilyPoint(x, y)
    end

    if role == "mom" then
        member.hair = {}
        local headCenterX = baseX
        local headCenterY = baseY + (hangDirection * BODY_LENGTH * scale) - (10 * scale)
        for index = 1, MOM_HAIR_COUNT do
            local t = (index - 1) / math.max(1, MOM_HAIR_COUNT - 1)
            local rootAngle = math.pi + (math.pi * t)
            local side = t < 0.5 and -1 or 1
            local length = (18 + (math.sin(t * math.pi) * 24) + (math.random() * 8)) * scale
            local rootX = headCenterX + (math.cos(rootAngle) * HEAD_RADIUS * scale * 0.92)
            local rootY = headCenterY + (math.sin(rootAngle) * HEAD_RADIUS * scale * 0.92)
            local hangAngle = rootAngle + (side * 0.55)
            local hair = {
                side = side,
                length = length,
                rootAngle = rootAngle,
                phase = math.random() * math.pi * 2,
                segmentLength = length / math.max(1, MOM_HAIR_JOINTS - 1),
                points = {}
            }
            for jointIndex = 1, MOM_HAIR_JOINTS do
                local jointT = (jointIndex - 1) / math.max(1, MOM_HAIR_JOINTS - 1)
                local x = rootX + (math.cos(hangAngle) * length * jointT * 0.55)
                local y = rootY + math.max(0, math.sin(hangAngle) * length * jointT)
                hair.points[jointIndex] = makeFamilyPoint(x, y)
            end
            hair.x = hair.points[#hair.points].x
            hair.y = hair.points[#hair.points].y
            member.hair[index] = hair
        end
    elseif role == "girl" then
        local headBaseY = baseY + (hangDirection * BODY_LENGTH * scale)
        member.accessories[#member.accessories + 1] = makeDetachedPiece("pigtail", baseX - (14 * scale), headBaseY, -1, scale)
        member.accessories[#member.accessories + 1] = makeDetachedPiece("pigtail", baseX + (14 * scale), headBaseY, 1, scale)
        member.accessories[#member.accessories + 1] = makeDetachedPiece("bow", baseX - ((HEAD_RADIUS + 8) * scale), headBaseY - (6 * scale), -1, scale)
        member.accessories[#member.accessories + 1] = makeDetachedPiece("bow", baseX + ((HEAD_RADIUS + 8) * scale), headBaseY - (6 * scale), 1, scale)
    end

    return member
end

function WackyInflatable.new(width, height, options)
    local self = setmetatable({}, WackyInflatable)
    self.width = width
    self.height = height
    self.preview = options and options.preview == true or false
    self.modeId = options and options.modeId or WackyInflatable.MODE_STANDARD
    self.baseX = math.floor(width * 0.5)
    self.normalBaseY = height - 18
    self.wormBaseY = math.floor(height * WORM_HORIZON_Y_RATIO)
    self.baseY = self.normalBaseY
    self.segmentLength = BODY_LENGTH / SEGMENT_COUNT
    self.inflation = 1
    self.targetInflation = self.preview and 1 or 0.16
    self.flopSide = 1
    self.wobblePhase = math.random() * math.pi * 2
    self.frame = 0
    self.crankLift = 0
    self.reverseGravityBoost = 0
    self.crankIdleFrames = CRANK_IDLE_FRAMES
    self.lastUserCrankFrame = -AUTO_CRANK_IDLE_FRAMES
    self.nextAutoCrankFrame = nil
    self.autoCrankEnabled = false
    self.autoCrankDirection = 1
    self.lastCrankDirection = 1
    self.collapseMode = false
    self.isFalling = false
    self.partyMode = false
    self.partyVisualAmount = 0
    self.partyMotionCount = 0
    self.partyLastDirection = 0
    self.partyLastMotionFrame = -PARTY_IDLE_FRAMES
    self.partyRayPhase = 0
    self.reachForStarsMode = false
    self.reachVisualAmount = 0
    self.reachUpwardFrames = 0
    self.reachLastUpwardFrame = -REACH_UPWARD_GAP_FRAMES
    self.reachStars = self:makeReachStars()
    self.wormMode = false
    self.wormVisualAmount = 0
    self.wormDownwardFrames = 0
    self.wormUpwardFrames = 0
    self.wormLastDownwardFrame = -WORM_DIRECTION_GAP_FRAMES
    self.wormLastUpwardFrame = -WORM_DIRECTION_GAP_FRAMES
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
    self.familyMembers = {}
    self:resetBodyPose(true)
    self:resetCrazyFamily()
    return self
end

function WackyInflatable:setPreview(isPreview)
    self.preview = isPreview == true
    if self.preview then
        self.frame = 0
        self.inflation = 1
        self.targetInflation = 1
        self:resetBodyPose(true)
        self:resetCrazyFamily()
    end
end

function WackyInflatable:activate()
end

function WackyInflatable:shutdown()
    self.partyMode = false
    self.reachForStarsMode = false
end

function WackyInflatable:resetBodyPose(fullyExtended)
    self.bodyPoints = {}
    local wormDirection = self.wormVisualAmount > 0.5 and 1 or -1
    for index = 1, SEGMENT_COUNT + 1 do
        local y = self.baseY + (wormDirection * (index - 1) * self.segmentLength)
        local x = self.baseX
        if not fullyExtended then
            local collapseT = (index - 1) / SEGMENT_COUNT
            x = x + (self.flopSide * collapseT * 36)
            y = y - (wormDirection * collapseT * collapseT * 24)
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

function WackyInflatable:resetCrazyFamily()
    local hangDirection = self.wormVisualAmount > 0.5 and 1 or -1
    self.familyMembers = {
        makeCrazyFamilyMember("mom", self.baseX - 118, self.baseY, 0.75, hangDirection),
        makeCrazyFamilyMember("girl", self.baseX + 92, self.baseY, 0.5, hangDirection)
    }
end

function WackyInflatable:isCrazyFamilyMode()
    return self.modeId == WackyInflatable.MODE_CRAZY_FAMILY
end

function WackyInflatable:setWormMode(enabled)
    self.wormMode = enabled == true
    self.wormVisualAmount = self.wormMode and 1 or 0
    self.baseY = self.wormMode and self.wormBaseY or self.normalBaseY
    self.wormDownwardFrames = 0
    self.wormUpwardFrames = 0
    self.reachForStarsMode = false
    self.reachVisualAmount = 0
    self.reachUpwardFrames = 0
    self:resetBodyPose(true)
    self:resetCrazyFamily()
end

function WackyInflatable:makeReachStars()
    local stars = {}
    for index = 1, REACH_STAR_COUNT do
        stars[index] = {
            x = math.random(8, math.max(8, self.width - 8)),
            y = math.random(8, math.max(8, self.height - 28)),
            phase = math.random() * math.pi * 2,
            speed = 0.09 + (math.random() * 0.08),
            size = math.random(1, 3)
        }
    end
    return stars
end

function WackyInflatable:scheduleNextAutoCrank()
    self.nextAutoCrankFrame = self.frame + math.random(AUTO_CRANK_DELAY_MIN_FRAMES, AUTO_CRANK_DELAY_MAX_FRAMES)
end

function WackyInflatable:updatePartyTrigger(direction, strength, automated)
    if automated or self.preview or direction == 0 or strength < PARTY_MIN_CRANK_STRENGTH then
        return
    end

    local framesSinceMotion = self.frame - (self.partyLastMotionFrame or -PARTY_IDLE_FRAMES)
    if framesSinceMotion > PARTY_RAPID_WINDOW_FRAMES or self.partyLastDirection == 0 then
        self.partyMotionCount = 1
    elseif direction ~= self.partyLastDirection then
        self.partyMotionCount = (self.partyMotionCount or 1) + 1
    end

    self.partyLastDirection = direction
    self.partyLastMotionFrame = self.frame

    if self.partyMotionCount >= PARTY_TRIGGER_MOVES then
        self.partyMode = true
    end
end

function WackyInflatable:updateReachTrigger(direction, strength, automated)
    if automated or self.preview or self.wormMode then
        return
    end

    if direction > 0 and strength >= REACH_MIN_CRANK_STRENGTH then
        local framesSinceUpward = self.frame - (self.reachLastUpwardFrame or -REACH_UPWARD_GAP_FRAMES)
        if framesSinceUpward <= REACH_UPWARD_GAP_FRAMES then
            self.reachUpwardFrames = (self.reachUpwardFrames or 0) + 1
        else
            self.reachUpwardFrames = 1
        end
        self.reachLastUpwardFrame = self.frame

        if self.reachUpwardFrames >= REACH_TRIGGER_FRAMES then
            self.reachForStarsMode = true
        end
    else
        self.reachUpwardFrames = 0
    end
end

function WackyInflatable:updateWormTrigger(direction, strength, automated)
    if automated or self.preview or direction == 0 or strength < WORM_MIN_CRANK_STRENGTH then
        return
    end

    if direction < 0 and not self.wormMode then
        local framesSinceDownward = self.frame - (self.wormLastDownwardFrame or -WORM_DIRECTION_GAP_FRAMES)
        if framesSinceDownward <= WORM_DIRECTION_GAP_FRAMES then
            self.wormDownwardFrames = (self.wormDownwardFrames or 0) + 1
        else
            self.wormDownwardFrames = 1
        end
        self.wormLastDownwardFrame = self.frame
        self.wormUpwardFrames = 0

        if self.wormDownwardFrames >= WORM_TRIGGER_FRAMES then
            self:setWormMode(true)
        end
        return
    end

    if direction > 0 and self.wormMode then
        local framesSinceUpward = self.frame - (self.wormLastUpwardFrame or -WORM_DIRECTION_GAP_FRAMES)
        if framesSinceUpward <= WORM_DIRECTION_GAP_FRAMES then
            self.wormUpwardFrames = (self.wormUpwardFrames or 0) + 1
        else
            self.wormUpwardFrames = 1
        end
        self.wormLastUpwardFrame = self.frame

        if self.wormUpwardFrames >= WORM_TRIGGER_FRAMES then
            self:setWormMode(false)
            self.reachUpwardFrames = 0
            self.reachLastUpwardFrame = self.frame
        end
        return
    end

    if direction > 0 then
        self.wormDownwardFrames = 0
    elseif direction < 0 then
        self.wormUpwardFrames = 0
    end
end

function WackyInflatable:applyCrank(change, acceleratedChange, automated)
    local strength = math.abs(acceleratedChange or 0) + (math.abs(change or 0) * 0.8)
    if strength <= 0.01 then
        return
    end
    automated = automated == true

    if not self.hat.attached then
        self.hat.attached = true
        self.hat.angularVelocity = 0
    end

    local direction = sign((acceleratedChange ~= 0 and acceleratedChange) or change)
    if direction ~= 0 then
        self.lastCrankDirection = direction
        self.flopSide = direction
    end
    if not automated and not self.preview then
        self.lastUserCrankFrame = self.frame
        self.nextAutoCrankFrame = nil
    end
    self:updatePartyTrigger(direction, strength, automated)
    self:updateWormTrigger(direction, strength, automated)
    self:updateReachTrigger(direction, strength, automated)
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

    if self:isCrazyFamilyMode() then
        self:applyCrazyFamilyImpulse(direction, impulse)
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

function WackyInflatable:applyCrazyFamilyImpulse(direction, impulse)
    for _, member in ipairs(self.familyMembers or {}) do
        member.flopSide = direction
        if direction < 0 then
            member.lift = math.max(0, (member.lift or 0) - (impulse * 0.08))
            member.reverseGravityBoost = clamp((member.reverseGravityBoost or 0) + (impulse * 0.16), 0, REVERSE_GRAVITY_SCALE)
        else
            member.lift = clamp((member.lift or 0) + (impulse * 0.1), 0, 1.1)
            member.reverseGravityBoost = math.max(0, (member.reverseGravityBoost or 0) - (impulse * 0.05))
        end
        for index = 2, #member.points do
            local point = member.points[index]
            local heightFactor = (index - 1) / member.segmentCount
            local pairDirection = index % 2 == 0 and -1 or 1
            local verticalDirection = direction < 0 and -0.65 or 1
            local verticalScale = 0.75 + (member.scale * 0.25)
            point.prevY = point.prevY + (impulse * CRANK_FLAIL_VERTICAL_SCALE * heightFactor * verticalDirection * verticalScale)
            point.prevX = point.prevX - (direction * pairDirection * impulse * CRANK_FLAIL_HORIZONTAL_SCALE * heightFactor * member.scale * 1.25)
        end
        if member.role == "mom" and member.hairAttached then
            for _, hair in ipairs(member.hair or {}) do
                for jointIndex = 2, #(hair.points or {}) do
                    local joint = hair.points[jointIndex]
                    local jointT = (jointIndex - 1) / math.max(1, #hair.points - 1)
                    joint.prevX = joint.prevX - (direction * impulse * hair.side * jointT * 0.9)
                    joint.prevY = joint.prevY + (impulse * jointT * (direction < 0 and -0.6 or 1.0))
                end
            end
        elseif member.role == "girl" then
            for _, piece in ipairs(member.accessories or {}) do
                if piece.kind == "bow" and not piece.attached then
                    piece.attached = true
                    piece.angularVelocity = 0
                end
            end
        end
    end
end

function WackyInflatable:updateDetachedPiece(piece, groundY)
    local velocityX = (piece.x - piece.prevX) * HAT_GROUND_DRAG
    local velocityY = (piece.y - piece.prevY) * HAT_GROUND_DRAG
    piece.prevX = piece.x
    piece.prevY = piece.y
    piece.x = piece.x + velocityX
    piece.y = piece.y + velocityY + (BODY_GRAVITY * 0.85)
    piece.rotation = (piece.rotation or 0) + (piece.angularVelocity or 0)
    piece.angularVelocity = (piece.angularVelocity or 0) * 0.99

    if piece.y > groundY then
        piece.y = groundY
        piece.prevY = piece.y + (velocityY * HAT_BOUNCE)
        piece.prevX = piece.x - (velocityX * HAT_GROUND_ROLL_DRAG)
        piece.angularVelocity = (piece.angularVelocity or 0) + (velocityX * 0.012)
    end
    piece.x = clamp(piece.x, 8, self.width - 8)
end

function WackyInflatable:updateCrazyFamilyMember(member)
    member.phase = wrapPhase(member.phase + 0.08)
    member.lift = math.max(0.05, (member.lift or 0) - 0.02)
    member.reverseGravityBoost = math.max(0, (member.reverseGravityBoost or 0) - GRAVITY_BOOST_DECAY)
    local sway = math.sin(member.phase) * BODY_SWAY_SCALE * member.scale * 1.8
    local gravityScale = 1 + (member.reverseGravityBoost or 0)

    for index = 2, #member.points do
        local point = member.points[index]
        local velocityX = (point.x - point.prevX) * BODY_DRAG
        local velocityY = (point.y - point.prevY) * BODY_DRAG
        local normalizedIndex = (index - 1) / member.segmentCount
        point.prevX = point.x
        point.prevY = point.y
        point.x = point.x + velocityX + (sway * normalizedIndex)
        point.y = point.y + velocityY + (BODY_GRAVITY * gravityScale * (1.08 - (member.scale * 0.18))) - ((member.lift or 0) * BODY_LIFT_SCALE * normalizedIndex)
    end

    for _ = 1, FAMILY_CONSTRAINT_PASSES do
        local base = member.points[1]
        base.x = member.baseX
        base.y = member.baseY
        base.prevX = member.baseX
        base.prevY = member.baseY
        for index = 1, #member.points - 1 do
            local a = member.points[index]
            local b = member.points[index + 1]
            local dx = b.x - a.x
            local dy = b.y - a.y
            local distance = math.max(0.0001, math.sqrt((dx * dx) + (dy * dy)))
            local difference = (distance - member.segmentLength) / distance
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

        for index = 2, #member.points do
            local point = member.points[index]
            point.x = clamp(point.x, member.baseX - (BODY_SWEEP_LIMIT * member.scale), member.baseX + (BODY_SWEEP_LIMIT * member.scale))
            if self.wormVisualAmount > 0.5 then
                if point.y < member.baseY + 2 then
                    point.y = member.baseY + 2
                    point.prevY = point.y - ((point.prevY - point.y) * COLLAPSE_GROUND_BOUNCE)
                end
            elseif point.y > member.baseY - 2 then
                point.y = member.baseY - 2
                point.prevY = point.y + ((point.y - point.prevY) * COLLAPSE_GROUND_BOUNCE)
            end
        end
    end

    local topPoint = member.points[#member.points]
    local headRadius = HEAD_RADIUS * member.scale
    local headCenterY = topPoint.y - (10 * member.scale)
    member.isFalling = (topPoint.y - topPoint.prevY) > (FALLING_SURPRISE_SPEED * math.max(0.45, member.scale))
    local headHitGround = self.wormVisualAmount <= 0.5 and (headCenterY + headRadius) >= (member.baseY - 2)
    if headHitGround and member.role == "girl" then
        for _, piece in ipairs(member.accessories or {}) do
            if piece.kind == "bow" and piece.attached then
                piece.attached = false
                piece.prevX = piece.x - ((topPoint.x - topPoint.prevX) * 1.2)
                piece.prevY = piece.y - ((topPoint.y - topPoint.prevY) * 1.2)
                piece.angularVelocity = piece.side * 0.15
            end
        end
    end

    self:updateCrazyFamilyAccessories(member)
end

function WackyInflatable:updateCrazyFamilyAccessories(member)
    local topPoint = member.points[#member.points]
    local scale = member.scale
    local headCenterX = topPoint.x
    local headCenterY = topPoint.y - (10 * scale)
    if member.role == "mom" then
        for _, hair in ipairs(member.hair or {}) do
            local rootX, rootY = getMomHairRoot(member, hair, headCenterX, headCenterY)
            local phase = (member.phase or 0) + hair.phase
            local points = hair.points or {}
            if points[1] ~= nil then
                points[1].x = rootX
                points[1].y = rootY
                points[1].prevX = rootX
                points[1].prevY = rootY
            end

            for jointIndex = 2, #points do
                local joint = points[jointIndex]
                local jointT = (jointIndex - 1) / math.max(1, #points - 1)
                local velocityX = (joint.x - joint.prevX) * 0.94
                local velocityY = (joint.y - joint.prevY) * 0.94
                joint.prevX = joint.x
                joint.prevY = joint.y
                joint.x = joint.x + velocityX + (math.sin((phase * 1.9) + jointIndex) * 0.9 * scale * jointT)
                joint.y = joint.y + velocityY + (BODY_GRAVITY * 0.46 * scale) + (math.cos((phase * 1.15) + jointIndex) * 0.45 * scale * jointT)
            end

            for _ = 1, MOM_HAIR_CONSTRAINT_PASSES do
                if points[1] ~= nil then
                    points[1].x = rootX
                    points[1].y = rootY
                end
                for jointIndex = 1, #points - 1 do
                    local a = points[jointIndex]
                    local b = points[jointIndex + 1]
                    local dx = b.x - a.x
                    local dy = b.y - a.y
                    local distance = math.max(0.001, math.sqrt((dx * dx) + (dy * dy)))
                    local difference = (distance - hair.segmentLength) / distance
                    if jointIndex == 1 then
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
            end

            local tip = points[#points]
            if tip ~= nil then
                hair.x = tip.x
                hair.y = tip.y
            end
        end
        return
    end

    for _, piece in ipairs(member.accessories or {}) do
        if piece.attached then
            piece.prevX = piece.x
            piece.prevY = piece.y
            if piece.kind == "pigtail" then
                piece.x = headCenterX + (piece.side * 12 * scale)
                piece.y = headCenterY - (3 * scale) + (math.sin((member.phase or 0) * 2.2 + piece.side) * 3 * scale)
            else
                piece.x = headCenterX + (piece.side * (HEAD_RADIUS + 7) * scale)
                piece.y = headCenterY - (9 * scale)
            end
        else
            self:updateDetachedPiece(piece, member.baseY - 3)
        end
    end
end

function WackyInflatable:updateCrazyFamily()
    if not self:isCrazyFamilyMode() then
        return
    end

    for _, member in ipairs(self.familyMembers or {}) do
        self:updateCrazyFamilyMember(member)
    end
end

function WackyInflatable:updateFamilyHorizons()
    for _, member in ipairs(self.familyMembers or {}) do
        member.baseY = self.baseY
    end
end

function WackyInflatable:translateByY(deltaY)
    if math.abs(deltaY) < 0.001 then
        return
    end

    for _, point in ipairs(self.bodyPoints or {}) do
        point.y = point.y + deltaY
        point.prevY = point.prevY + deltaY
    end

    self.hat.y = self.hat.y + deltaY
    self.hat.prevY = self.hat.prevY + deltaY

    for _, member in ipairs(self.familyMembers or {}) do
        for _, point in ipairs(member.points or {}) do
            point.y = point.y + deltaY
            point.prevY = point.prevY + deltaY
        end
        for _, hair in ipairs(member.hair or {}) do
            for _, point in ipairs(hair.points or {}) do
                point.y = point.y + deltaY
                point.prevY = point.prevY + deltaY
            end
        end
        for _, piece in ipairs(member.accessories or {}) do
            piece.y = piece.y + deltaY
            piece.prevY = piece.prevY + deltaY
        end
    end
end

function WackyInflatable:updatePartyMode()
    if self.partyMode and (self.frame - (self.partyLastMotionFrame or 0)) > PARTY_IDLE_FRAMES then
        self.partyMode = false
        self.partyMotionCount = 0
        self.partyLastDirection = 0
    end

    local targetAmount = self.partyMode and 1 or 0
    self.partyVisualAmount = self.partyVisualAmount + ((targetAmount - self.partyVisualAmount) * 0.18)
    if self.partyVisualAmount < 0.01 then
        self.partyVisualAmount = 0
    end
    self.partyRayPhase = wrapPhase((self.partyRayPhase or 0) + (0.11 + (self.partyVisualAmount * 0.12)))
end

function WackyInflatable:updateReachForStarsMode()
    if self.reachForStarsMode and (self.frame - (self.reachLastUpwardFrame or 0)) > PARTY_IDLE_FRAMES then
        self.reachForStarsMode = false
        self.reachUpwardFrames = 0
    end

    if self.wormMode then
        self.reachForStarsMode = false
        self.reachUpwardFrames = 0
    end

    local targetAmount = self.reachForStarsMode and 1 or 0
    self.reachVisualAmount = self.reachVisualAmount + ((targetAmount - self.reachVisualAmount) * 0.14)
    if self.reachVisualAmount < 0.01 then
        self.reachVisualAmount = 0
    end
end

function WackyInflatable:updateWormMode()
    local targetAmount = self.wormMode and 1 or 0
    self.wormVisualAmount = self.wormVisualAmount + ((targetAmount - self.wormVisualAmount) * 0.055)
    if self.wormVisualAmount < 0.01 then
        self.wormVisualAmount = 0
    elseif self.wormVisualAmount > 0.99 then
        self.wormVisualAmount = 1
    end
    local previousBaseY = self.baseY
    self.baseY = lerp(self.normalBaseY, self.wormBaseY, self.wormVisualAmount)
    self:translateByY(self.baseY - previousBaseY)
    self:updateFamilyHorizons()
end

function WackyInflatable:updateAutoCrank()
    if self.preview or not self.autoCrankEnabled then
        return
    end

    if (self.frame - (self.lastUserCrankFrame or 0)) < AUTO_CRANK_IDLE_FRAMES then
        self.nextAutoCrankFrame = nil
        return
    end

    if self.nextAutoCrankFrame == nil then
        self:scheduleNextAutoCrank()
        return
    end

    if self.frame < self.nextAutoCrankFrame then
        return
    end

    self.autoCrankDirection = -(self.autoCrankDirection or 1)
    self:applyCrank(AUTO_CRANK_QUARTER_TURN * self.autoCrankDirection, AUTO_CRANK_QUARTER_TURN * self.autoCrankDirection, true)
    self:scheduleNextAutoCrank()
end

function WackyInflatable:handlePrimaryAction()
    self.autoCrankEnabled = true
    self.lastUserCrankFrame = self.frame
    self.nextAutoCrankFrame = nil
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
            if self.wormVisualAmount > 0.5 then
                if point.y < (self.baseY + 2) then
                    local penetration = (self.baseY + 2) - point.y
                    point.y = self.baseY + 2
                    local bounce = allowCollapse and COLLAPSE_GROUND_BOUNCE or BODY_GROUND_BOUNCE
                    point.prevY = point.y - (penetration * bounce)
                end
            elseif point.y > (self.baseY - 2) then
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
        local elbowTarget = (arm.direction * (0.48 + (flopBias * 0.22))) + (bodySwing * 0.5)
        local wristTarget = (arm.direction * (0.26 + (flopBias * 0.28))) + (bodySwing * 0.36)

        arm.shoulderVelocity = (arm.shoulderVelocity + ((shoulderTarget - arm.shoulderAngle) * 0.18)) * 0.78
        arm.elbowVelocity = (arm.elbowVelocity + ((elbowTarget - arm.elbowAngle) * 0.22)) * 0.74
        arm.wristVelocity = (arm.wristVelocity + ((wristTarget - arm.wristAngle) * 0.24)) * 0.72

        arm.shoulderAngle = arm.shoulderAngle + arm.shoulderVelocity
        arm.elbowAngle = arm.elbowAngle + arm.elbowVelocity
        arm.wristAngle = arm.wristAngle + arm.wristVelocity
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
    local elbowX = shoulderX + (math.cos(upperAngle) * ARM_SEGMENT_LENGTHS[1])
    local elbowY = shoulderY + (math.sin(upperAngle) * ARM_SEGMENT_LENGTHS[1])
    local foreAngle = upperAngle + arm.elbowAngle
    local wristX = elbowX + (math.cos(foreAngle) * ARM_SEGMENT_LENGTHS[2])
    local wristY = elbowY + (math.sin(foreAngle) * ARM_SEGMENT_LENGTHS[2])
    local handAngle = foreAngle + arm.wristAngle
    local handX = wristX + (math.cos(handAngle) * ARM_SEGMENT_LENGTHS[3])
    local handY = wristY + (math.sin(handAngle) * ARM_SEGMENT_LENGTHS[3])

    gfx.drawLine(shoulderX, shoulderY, elbowX, elbowY)
    gfx.drawLine(elbowX, elbowY, wristX, wristY)
    gfx.drawLine(wristX, wristY, handX, handY)
    gfx.fillCircleAtPoint(elbowX, elbowY, 1)
    gfx.fillCircleAtPoint(wristX, wristY, 1)
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

function WackyInflatable:drawFamilyTube(member)
    for index = 1, #member.points - 1 do
        local a = member.points[index]
        local b = member.points[index + 1]
        local width = math.max(2, TUBE_WIDTH * member.scale * (0.55 + (0.3 * (index / #member.points))))
        gfx.drawLine(a.x - (width * 0.5), a.y, b.x - (width * 0.5), b.y)
        gfx.drawLine(a.x + (width * 0.5), a.y, b.x + (width * 0.5), b.y)
        if index % 2 == 0 then
            gfx.drawLine(a.x - (width * 0.5), a.y, a.x + (width * 0.5), a.y)
        end
    end
end

function WackyInflatable:drawDetachedPiece(piece)
    local scale = piece.scale or 1
    if piece.kind == "bow" then
        local size = math.max(2, 8 * scale)
        gfx.drawLine(piece.x, piece.y, piece.x - (piece.side * size), piece.y - size)
        gfx.drawLine(piece.x, piece.y, piece.x - (piece.side * size), piece.y + size)
        gfx.drawLine(piece.x, piece.y, piece.x + (piece.side * size), piece.y - size)
        gfx.drawLine(piece.x, piece.y, piece.x + (piece.side * size), piece.y + size)
    else
        local radius = math.max(2, 9 * scale)
        gfx.drawCircleAtPoint(piece.x, piece.y, radius)
        gfx.drawLine(piece.x, piece.y - radius, piece.x + (piece.side * radius), piece.y + radius)
    end
end

function WackyInflatable:drawFamilyHair(member, headCenterX, headCenterY)
    if member.role == "mom" then
        for _, hair in ipairs(member.hair or {}) do
            local points = hair.points or {}
            for jointIndex = 1, #points - 1 do
                local a = points[jointIndex]
                local b = points[jointIndex + 1]
                gfx.drawLine(a.x, a.y, b.x, b.y)
                if jointIndex % 2 == 1 then
                    gfx.drawLine(a.x + (hair.side * 1.2), a.y + 1, b.x + (hair.side * 2.2), b.y + (1.5 * member.scale))
                end
            end
        end
        return
    end

    for _, piece in ipairs(member.accessories or {}) do
        self:drawDetachedPiece(piece)
    end
end

function WackyInflatable:drawFamilyMember(member)
    local topPoint = member.points[#member.points]
    local shoulderPoint = member.points[math.max(2, math.floor(#member.points * 0.62))]
    local scale = member.scale
    local headCenterX = topPoint.x
    local headCenterY = topPoint.y - (10 * scale)
    local headRadius = math.max(4, HEAD_RADIUS * scale)

    self:drawHorizonAnchor(member.baseX, member.baseY, 10 * scale, 8 * scale)
    self:drawFamilyTube(member)

    local armLength = ARM_LENGTH * scale
    for _, side in ipairs({ -1, 1 }) do
        local phase = (member.phase or 0) + side
        local handX = shoulderPoint.x + (side * armLength * 0.75) + (math.sin(phase * 1.8) * armLength * 0.35)
        local handY = shoulderPoint.y + (math.cos(phase) * armLength * 0.5)
        gfx.drawLine(shoulderPoint.x, shoulderPoint.y, handX, handY)
        gfx.fillCircleAtPoint(handX, handY, math.max(1, 3 * scale))
    end

    self:drawFamilyHair(member, headCenterX, headCenterY)
    gfx.drawCircleAtPoint(headCenterX, headCenterY, headRadius)
    gfx.fillCircleAtPoint(headCenterX - (5 * scale), headCenterY - (3 * scale), math.max(1, 2 * scale))
    gfx.fillCircleAtPoint(headCenterX + (5 * scale), headCenterY - (3 * scale), math.max(1, 2 * scale))

    if member.isFalling then
        local mouthRadius = math.max(2, 4 * scale)
        gfx.drawCircleAtPoint(headCenterX, headCenterY + (6 * scale), mouthRadius)
        gfx.fillCircleAtPoint(headCenterX, headCenterY + (6 * scale), math.max(1, mouthRadius * 0.45))
    else
        gfx.drawLine(headCenterX - (5 * scale), headCenterY + (4 * scale), headCenterX, headCenterY + (6 * scale))
        gfx.drawLine(headCenterX, headCenterY + (6 * scale), headCenterX + (5 * scale), headCenterY + (4 * scale))
    end
end

function WackyInflatable:drawCrazyFamily()
    if not self:isCrazyFamilyMode() then
        return
    end

    for _, member in ipairs(self.familyMembers or {}) do
        self:drawFamilyMember(member)
    end
end

function WackyInflatable:drawHorizonAnchor(x, y, halfWidth, supportLength)
    local angle = math.pi * (self.wormVisualAmount or 0)
    local dx = math.cos(angle) * halfWidth
    local dy = math.sin(angle) * halfWidth
    local supportX = -math.sin(angle) * supportLength
    local supportY = math.cos(angle) * supportLength
    gfx.drawLine(x - dx, y - dy, x + dx, y + dy)
    gfx.drawLine(x, y, x + supportX, y + supportY)
end

function WackyInflatable:drawWormHorizon()
    if (self.wormVisualAmount or 0) <= 0 then
        return
    end

    gfx.setDitherPattern(0.45, gfx.image.kDitherTypeBayer8x8)
    gfx.drawLine(0, self.baseY, self.width, self.baseY)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
end

function WackyInflatable:drawPartyBackground()
    if (self.partyVisualAmount or 0) <= 0 and (self.reachVisualAmount or 0) <= 0 then
        gfx.clear(gfx.kColorWhite)
        return
    end

    local greyFlash = math.floor(self.frame / 6) % 2 == 0
    gfx.clear(gfx.kColorWhite)
    local reachAmount = self.reachVisualAmount or 0
    if reachAmount > 0 then
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(REACH_DARKEN_DITHER * reachAmount, gfx.image.kDitherTypeBayer8x8)
        gfx.fillRect(0, 0, self.width, self.height)
        gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    end
    if greyFlash then
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(PARTY_BACKGROUND_DITHER, gfx.image.kDitherTypeBayer8x8)
        gfx.fillRect(0, 0, self.width, self.height)
        gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    end
end

function WackyInflatable:drawReachStars()
    local amount = self.reachVisualAmount or 0
    if amount <= 0 then
        return
    end

    gfx.setColor(gfx.kColorBlack)
    for _, star in ipairs(self.reachStars or {}) do
        local twinkle = (math.sin((self.frame * star.speed) + star.phase) + 1) * 0.5
        if twinkle > (1 - (0.82 * amount)) then
            local x = star.x
            local y = star.y
            local size = star.size
            gfx.drawLine(x - size, y, x + size, y)
            gfx.drawLine(x, y - size, x, y + size)
            if twinkle > 0.82 then
                gfx.fillRect(x, y, 1, 1)
            end
        end
    end
end

function WackyInflatable:drawDiscoParty()
    local amount = self.partyVisualAmount or 0
    if amount <= 0 then
        return
    end

    local centerX = math.floor(self.width * 0.5)
    local centerY = lerp(PARTY_DISCO_HIDDEN_Y, PARTY_DISCO_VISIBLE_Y, amount)
    local phase = self.partyRayPhase or 0
    local rayLength = 210 * amount

    gfx.setColor(gfx.kColorBlack)
    for index = 1, 12 do
        local angle = phase + ((index - 1) * math.pi / 6)
        local endX = centerX + (math.cos(angle) * rayLength)
        local endY = centerY + (math.sin(angle) * rayLength)
        if index % 2 == 0 then
            gfx.setDitherPattern(0.35, gfx.image.kDitherTypeBayer8x8)
            gfx.setLineWidth(3)
        else
            gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
            gfx.setLineWidth(1)
        end
        gfx.drawLine(centerX, centerY, endX, endY)
    end

    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    gfx.setLineWidth(1)
    gfx.fillCircleAtPoint(centerX, centerY, PARTY_DISCO_RADIUS)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(centerX - PARTY_DISCO_RADIUS + 3, centerY - 5, centerX + PARTY_DISCO_RADIUS - 3, centerY - 5)
    gfx.drawLine(centerX - PARTY_DISCO_RADIUS + 2, centerY + 4, centerX + PARTY_DISCO_RADIUS - 2, centerY + 4)
    gfx.drawLine(centerX - 6, centerY - PARTY_DISCO_RADIUS + 2, centerX - 6, centerY + PARTY_DISCO_RADIUS - 2)
    gfx.drawLine(centerX + 6, centerY - PARTY_DISCO_RADIUS + 2, centerX + 6, centerY + PARTY_DISCO_RADIUS - 2)
    gfx.fillCircleAtPoint(centerX - 6, centerY - 5, 2)
    gfx.fillCircleAtPoint(centerX + 7, centerY + 4, 2)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(centerX, 0, centerX, centerY - PARTY_DISCO_RADIUS)
end

function WackyInflatable:update()
    self.frame = self.frame + 1
    if self.preview and self.frame % PREVIEW_AUTO_CRANK_FRAMES == 1 then
        self:applyCrank(18, 18)
    end
    self:updateAutoCrank()
    self:updateWormMode()
    self:updateBodyPhysics()
    self:updateArmPhysics()
    self:updateHat(self.bodyPoints[#self.bodyPoints])
    self:updateCrazyFamily()
    self:updatePartyMode()
    self:updateReachForStarsMode()
end

function WackyInflatable:draw()
    local points = self:getBodyPoints()
    local topPoint = points[#points]
    local shoulderPoint = points[math.max(3, math.floor(#points * 0.62))]

    self:drawPartyBackground()
    gfx.setColor(gfx.kColorBlack)
    self:drawReachStars()
    self:drawDiscoParty()
    self:drawWormHorizon()

    self:drawHorizonAnchor(self.baseX, self.baseY, 12, 8)

    self:drawCrazyFamily()
    self:drawTube(points)
    self:drawArm(shoulderPoint.x, shoulderPoint.y, shoulderPoint.angle - 1.2, self.arms[1])
    self:drawArm(shoulderPoint.x, shoulderPoint.y, shoulderPoint.angle + 1.2, self.arms[2])
    self:drawHat()
    self:drawHead(topPoint)
end
