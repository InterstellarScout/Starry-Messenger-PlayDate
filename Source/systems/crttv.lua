local pd <const> = playdate
local gfx <const> = pd.graphics

CRTTVEffect = {}
CRTTVEffect.__index = CRTTVEffect

local STATIC_NOISE_STEP_X <const> = 4
local STATIC_NOISE_STEP_Y <const> = 2
local STATIC_PREVIEW_FRAME_DURATION <const> = 12
local STATIC_PREVIEW_PHASES <const> = { 3.5, 19.25 }
local STATIC_FRAME_COUNT <const> = 8
local BAR_PATTERN_LARGE <const> = { 0x11, 0x22, 0x44, 0x88, 0x11, 0x22, 0x44, 0x88 }
local BAR_PATTERN_SMALL <const> = { 0x88, 0xcc, 0x66, 0x33, 0x11, 0x33, 0x66, 0xcc }
local CRANK_RELEASE_ANGLE_TOLERANCE <const> = 3
local CRANK_RELEASE_IDLE_FRAMES <const> = 60
local LARGE_BAR_BASE_SPEED <const> = 0.9
local LARGE_BAR_HEIGHT <const> = 40
local SMALL_BAR_HEIGHT <const> = 12
local STATIC_FRAME_PHASE_STEP <const> = 7.25
local PREVIEW_FRAME_COUNT <const> = 12
local MANUAL_BAR_SPEED_SCALE <const> = 0.2
local MANUAL_BAR_IDLE_FALL_SPEED <const> = 1.4
local MANUAL_BAR_MAX_EXTRA_HEIGHT <const> = 20

CRTTVEffect._noiseFrames = nil
CRTTVEffect._previewFrames = nil

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

local function buildNoiseFrame(width, height, phase)
    local image = gfx.image.new(width, height, gfx.kColorWhite)
    gfx.pushContext(image)
        gfx.setColor(gfx.kColorBlack)
        for y = 0, height - 1, STATIC_NOISE_STEP_Y do
            local rowOffset = math.floor(staticNoise(0, y, phase * 11) * 12)
            for x = -rowOffset, width - 1, STATIC_NOISE_STEP_X do
                if staticNoise(x, y, phase) < 0.44 then
                    gfx.fillRect(x, y, 2, STATIC_NOISE_STEP_Y)
                end
            end

            if y % 6 == 0 or staticNoise(200, y, phase * 0.5) < 0.08 then
                gfx.drawLine(0, y, width, y)
            end
        end
    gfx.popContext()
    return image
end

local function ensureNoiseFrames(width, height)
    if CRTTVEffect._noiseFrames ~= nil then
        return CRTTVEffect._noiseFrames
    end

    local frames = {}
    for index = 1, STATIC_FRAME_COUNT do
        frames[index] = buildNoiseFrame(width, height, index * STATIC_FRAME_PHASE_STEP)
    end
    CRTTVEffect._noiseFrames = frames
    return frames
end

local function makeBar(y, height, speed)
    return {
        y = y,
        height = height,
        baseSpeed = speed,
        speed = speed
    }
end

local function randomManualBarHeight()
    return math.random(SMALL_BAR_HEIGHT, LARGE_BAR_HEIGHT + MANUAL_BAR_MAX_EXTRA_HEIGHT)
end

local function drawNoiseBands(width, height, phase)
    local rollingBandY = ((phase * 3.2) % (height + 52)) - 26
    local slowBandY = ((phase * 1.1) % (height + 72)) - 36

    for y = 0, height - 1, 6 do
        local bandDistance = math.abs(y - rollingBandY)
        local secondaryDistance = math.abs(y - slowBandY)
        local densityBoost = 0

        if bandDistance < 18 then
            densityBoost = 0.22
        elseif secondaryDistance < 28 then
            densityBoost = 0.12
        end

        if densityBoost > 0 then
            local shade = clamp(0.75 - densityBoost, 0.35, 0.78)
            gfx.setDitherPattern(shade, gfx.image.kDitherTypeBayer8x8)
            gfx.fillRect(0, y - 3, width, 6)
            gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
        end

        gfx.drawLine(0, y, width, y)
    end
end

local function ensurePreviewFrames(width, height)
    if CRTTVEffect._previewFrames ~= nil then
        return CRTTVEffect._previewFrames
    end

    local noiseFrames = ensureNoiseFrames(width, height)
    local frames = {}
    for index = 1, PREVIEW_FRAME_COUNT do
        local phase = index * STATIC_FRAME_PHASE_STEP
        local frame = gfx.image.new(width, height, gfx.kColorWhite)
        gfx.pushContext(frame)
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRect(0, 0, width, height)
            gfx.setColor(gfx.kColorBlack)
            local baseFrame = noiseFrames[((index - 1) % #noiseFrames) + 1]
            if baseFrame then
                baseFrame:draw(0, 0)
            end
            drawNoiseBands(width, height, phase)
        gfx.popContext()
        frames[index] = frame
    end

    CRTTVEffect._previewFrames = frames
    return frames
end

function CRTTVEffect.new(width, height, options)
    local self = setmetatable({}, CRTTVEffect)
    self.width = width
    self.height = height
    self.preview = options and options.preview == true or false
    self.staticPhase = 0
    self.staticPreviewFrame = 1
    self.staticPreviewTimer = STATIC_PREVIEW_FRAME_DURATION
    self.noiseFrames = ensureNoiseFrames(width, height)
    self.previewFrames = ensurePreviewFrames(width, height)
    self.noiseFrameIndex = 1
    self.frameCounter = 0
    self.barsActive = false
    self.barSpeedScale = 1
    self.barSpeedIdleFrames = CRANK_RELEASE_IDLE_FRAMES
    self.bars = {
        large = makeBar(-48, LARGE_BAR_HEIGHT, LARGE_BAR_BASE_SPEED),
        small = makeBar(-18, SMALL_BAR_HEIGHT, randomSmallBarSpeed())
    }
    self.manualBar = nil
    self.manualBarIdleFrames = CRANK_RELEASE_IDLE_FRAMES
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

function CRTTVEffect.prewarmTitleFrames(width, height)
    ensureNoiseFrames(width, height)
    ensurePreviewFrames(width, height)
end

function CRTTVEffect:spawnManualBar(direction)
    local height = randomManualBarHeight()
    self.manualBar = {
        y = direction >= 0 and -height or self.height,
        height = height,
        direction = direction >= 0 and 1 or -1
    }
    self.manualBarIdleFrames = 0
end

function CRTTVEffect:respawnManualBar(direction)
    local height = randomManualBarHeight()
    if self.manualBar == nil then
        self.manualBar = {}
    end
    self.manualBar.height = height
    self.manualBar.direction = direction >= 0 and 1 or -1
    if direction >= 0 then
        self.manualBar.y = -height
    else
        self.manualBar.y = self.height
    end
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
    if math.abs(change or 0) > 0.01 or math.abs(acceleratedChange or 0) > 0.01 then
        local crankDelta = acceleratedChange or change or 0
        local direction = crankDelta >= 0 and -1 or 1
        if self.manualBar == nil then
            self:spawnManualBar(direction)
        end

        self.manualBar.direction = direction
        self.manualBar.y = self.manualBar.y + (crankDelta * MANUAL_BAR_SPEED_SCALE)
        if self.manualBar.y >= self.height then
            self:respawnManualBar(-1)
        elseif (self.manualBar.y + self.manualBar.height) <= 0 then
            self:respawnManualBar(1)
        end
        self.manualBarIdleFrames = 0

        if self.barsActive then
            self.barSpeedScale = clamp(self.barSpeedScale + (crankDelta * 0.015), 0.15, 4.5)
            self.barSpeedIdleFrames = 0
        end
        return
    end

    if self.barsActive and self:shouldReleaseCrankControl() then
        self.barSpeedScale = 1
        self.barSpeedIdleFrames = CRANK_RELEASE_IDLE_FRAMES
    elseif self.barsActive and self.barSpeedIdleFrames < CRANK_RELEASE_IDLE_FRAMES then
        self.barSpeedIdleFrames = self.barSpeedIdleFrames + 1
        if self.barSpeedIdleFrames >= CRANK_RELEASE_IDLE_FRAMES then
            self.barSpeedScale = 1
        end
    end

    if self.manualBar ~= nil then
        self.manualBarIdleFrames = self.manualBarIdleFrames + 1
    end
end

function CRTTVEffect:updateStaticPhase()
    self.frameCounter = self.frameCounter + 1
    if self.preview then
        self.staticPreviewTimer = self.staticPreviewTimer - 1
        if self.staticPreviewTimer <= 0 then
            self.staticPreviewFrame = self.staticPreviewFrame + 1
            if self.staticPreviewFrame > PREVIEW_FRAME_COUNT then
                self.staticPreviewFrame = 1
            end
            self.staticPreviewTimer = STATIC_PREVIEW_FRAME_DURATION
        end
        self.staticPhase = self.staticPreviewFrame * STATIC_FRAME_PHASE_STEP
        self.noiseFrameIndex = ((self.staticPreviewFrame - 1) % #self.noiseFrames) + 1
    else
        self.staticPhase = self.staticPhase + 1.35
        if self.frameCounter % 2 == 0 then
            self.noiseFrameIndex = self.noiseFrameIndex + 1
            if self.noiseFrameIndex > #self.noiseFrames then
                self.noiseFrameIndex = 1
            end
        end
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

function CRTTVEffect:updateManualBar()
    if self.manualBar == nil then
        return
    end

    if self.manualBarIdleFrames > 0 then
        self.manualBar.y = self.manualBar.y + MANUAL_BAR_IDLE_FALL_SPEED
        if self.manualBar.y >= self.height then
            self.manualBar = nil
        end
    end
end

function CRTTVEffect:update()
    self:updateStaticPhase()
    self:updateBars()
    self:updateManualBar()
end

function CRTTVEffect:drawNoise()
    if self.preview and self.previewFrames and self.previewFrames[self.staticPreviewFrame] then
        self.previewFrames[self.staticPreviewFrame]:draw(0, 0)
        return
    end

    local frame = self.noiseFrames and self.noiseFrames[self.noiseFrameIndex]
    if frame then
        frame:draw(0, 0)
    end

    drawNoiseBands(self.width, self.height, self.staticPhase)
end

function CRTTVEffect:drawBars()
    if not self.barsActive then
        if self.manualBar == nil then
            return
        end
    end

    if self.barsActive then
        gfx.setImageDrawMode(gfx.kDrawModeXOR)
        gfx.setPattern(BAR_PATTERN_LARGE)
        gfx.fillRect(0, math.floor(self.bars.large.y), self.width, self.bars.large.height)
        gfx.setPattern(BAR_PATTERN_SMALL)
        gfx.fillRect(0, math.floor(self.bars.small.y), self.width, self.bars.small.height)
    end
    if self.manualBar ~= nil then
        gfx.setImageDrawMode(gfx.kDrawModeXOR)
        gfx.setPattern(BAR_PATTERN_LARGE)
        gfx.fillRect(0, math.floor(self.manualBar.y), self.width, self.manualBar.height)
    end
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
        gfx.drawText("CRT TV  A: auto bars  Crank: spawn/move bar  B: menu", 8, 2)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
end
