local pd <const> = playdate
local gfx <const> = pd.graphics

CRTTVEffect = {}
CRTTVEffect.__index = CRTTVEffect

local STATIC_NOISE_STEP_X <const> = 4
local STATIC_NOISE_STEP_Y <const> = 2
local STATIC_PREVIEW_FRAME_DURATION <const> = 12
local STATIC_PREVIEW_PHASES <const> = { 3.5, 19.25 }
local BAR_PATTERN_LARGE <const> = { 0x11, 0x22, 0x44, 0x88, 0x11, 0x22, 0x44, 0x88 }
local BAR_PATTERN_SMALL <const> = { 0x88, 0xcc, 0x66, 0x33, 0x11, 0x33, 0x66, 0xcc }
local CRANK_RELEASE_ANGLE_TOLERANCE <const> = 3
local CRANK_RELEASE_IDLE_FRAMES <const> = 60
local LARGE_BAR_BASE_SPEED <const> = 0.9
local LARGE_BAR_HEIGHT <const> = 40
local SMALL_BAR_HEIGHT <const> = 12

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function fract(value)
    return value - math.floor(value)
end

local function staticNoise(x, y, phase)
    local seed = (x * 0.173) + (y * 0.619) + (phase * 0.097)
    return fract(math.sin(seed) * 43758.5453)
end

local function randomSmallBarSpeed()
    return 0.5 + (math.random() * 2.3)
end

local function makeBar(y, height, speed)
    return {
        y = y,
        height = height,
        baseSpeed = speed,
        speed = speed
    }
end

function CRTTVEffect.new(width, height, options)
    local self = setmetatable({}, CRTTVEffect)
    self.width = width
    self.height = height
    self.preview = options and options.preview == true or false
    self.staticPhase = 0
    self.staticPreviewFrame = 1
    self.staticPreviewTimer = STATIC_PREVIEW_FRAME_DURATION
    self.barsActive = false
    self.barSpeedScale = 1
    self.barSpeedIdleFrames = CRANK_RELEASE_IDLE_FRAMES
    self.bars = {
        large = makeBar(-48, LARGE_BAR_HEIGHT, LARGE_BAR_BASE_SPEED),
        small = makeBar(-18, SMALL_BAR_HEIGHT, randomSmallBarSpeed())
    }
    return self
end

function CRTTVEffect:setPreview(isPreview)
    self.preview = isPreview == true
end

function CRTTVEffect:activate()
end

function CRTTVEffect:shutdown()
end

function CRTTVEffect:resetBars()
    self.bars.large = makeBar(-48, LARGE_BAR_HEIGHT, LARGE_BAR_BASE_SPEED)
    self.bars.small = makeBar(-18, SMALL_BAR_HEIGHT, randomSmallBarSpeed())
    self.barSpeedScale = 1
    self.barSpeedIdleFrames = CRANK_RELEASE_IDLE_FRAMES
end

function CRTTVEffect:handlePrimaryAction()
    self.barsActive = not self.barsActive
    if self.barsActive then
        self:resetBars()
    end
end

function CRTTVEffect:shouldReleaseCrankControl()
    local crankPosition = pd.getCrankPosition and pd.getCrankPosition() or nil
    local crankDocked = pd.isCrankDocked and pd.isCrankDocked() or false
    return crankDocked
        or (crankPosition ~= nil and (
            crankPosition <= CRANK_RELEASE_ANGLE_TOLERANCE
            or crankPosition >= (360 - CRANK_RELEASE_ANGLE_TOLERANCE)
            or math.abs(crankPosition - 180) <= CRANK_RELEASE_ANGLE_TOLERANCE
        ))
end

function CRTTVEffect:applyCrank(change, acceleratedChange)
    if not self.barsActive then
        return
    end

    if math.abs(change or 0) > 0.01 or math.abs(acceleratedChange or 0) > 0.01 then
        self.barSpeedScale = clamp(self.barSpeedScale + ((acceleratedChange or change or 0) * 0.015), 0.15, 4.5)
        self.barSpeedIdleFrames = 0
        return
    end

    if self:shouldReleaseCrankControl() then
        self.barSpeedScale = 1
        self.barSpeedIdleFrames = CRANK_RELEASE_IDLE_FRAMES
        return
    end

    if self.barSpeedIdleFrames < CRANK_RELEASE_IDLE_FRAMES then
        self.barSpeedIdleFrames = self.barSpeedIdleFrames + 1
        if self.barSpeedIdleFrames >= CRANK_RELEASE_IDLE_FRAMES then
            self.barSpeedScale = 1
        end
    end
end

function CRTTVEffect:updateStaticPhase()
    if self.preview then
        self.staticPreviewTimer = self.staticPreviewTimer - 1
        if self.staticPreviewTimer <= 0 then
            self.staticPreviewFrame = self.staticPreviewFrame == 1 and 2 or 1
            self.staticPreviewTimer = STATIC_PREVIEW_FRAME_DURATION
        end
        self.staticPhase = STATIC_PREVIEW_PHASES[self.staticPreviewFrame]
    else
        self.staticPhase = self.staticPhase + 1.35
    end
end

function CRTTVEffect:updateBars()
    if not self.barsActive then
        return
    end

    self.bars.large.y = self.bars.large.y + (self.bars.large.baseSpeed * self.barSpeedScale)
    self.bars.small.y = self.bars.small.y + (self.bars.small.speed * self.barSpeedScale)

    if self.bars.large.y >= self.height then
        self.bars.large.y = -self.bars.large.height
    end

    if self.bars.small.y >= self.height then
        self.bars.small.y = -self.bars.small.height
        self.bars.small.speed = randomSmallBarSpeed()
    end
end

function CRTTVEffect:update()
    self:updateStaticPhase()
    self:updateBars()
end

function CRTTVEffect:drawNoise()
    local phase = self.staticPhase
    local rollingBandY = ((phase * 3.2) % (self.height + 52)) - 26
    local slowBandY = ((phase * 1.1) % (self.height + 72)) - 36

    for y = 0, self.height - 1, STATIC_NOISE_STEP_Y do
        local rowOffset = math.floor(staticNoise(0, y, phase * 11) * 12)
        local bandDistance = math.abs(y - rollingBandY)
        local secondaryDistance = math.abs(y - slowBandY)
        local densityBoost = 0

        if bandDistance < 18 then
            densityBoost = 0.22
        elseif secondaryDistance < 28 then
            densityBoost = 0.12
        end

        for x = -rowOffset, self.width - 1, STATIC_NOISE_STEP_X do
            if staticNoise(x, y, phase) < (0.44 + densityBoost) then
                gfx.fillRect(x, y, 2, STATIC_NOISE_STEP_Y)
            end
        end

        if y % 6 == 0 or staticNoise(200, y, phase * 0.5) < 0.08 then
            gfx.drawLine(0, y, self.width, y)
        end
    end
end

function CRTTVEffect:drawBars()
    if not self.barsActive then
        return
    end

    gfx.setImageDrawMode(gfx.kDrawModeXOR)
    gfx.setPattern(BAR_PATTERN_LARGE)
    gfx.fillRect(0, math.floor(self.bars.large.y), self.width, self.bars.large.height)
    gfx.setPattern(BAR_PATTERN_SMALL)
    gfx.fillRect(0, math.floor(self.bars.small.y), self.width, self.bars.small.height)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function CRTTVEffect:draw()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    self:drawNoise()
    self:drawBars()

    if not self.preview then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, 0, self.width, 14)
        gfx.setImageDrawMode(gfx.kDrawModeInverted)
        gfx.drawText("CRT TV  A: bars  Crank: temporary speed  B: menu", 8, 2)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
end
