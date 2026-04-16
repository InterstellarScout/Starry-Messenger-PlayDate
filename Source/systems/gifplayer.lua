import "CoreLibs/graphics"
import "data/gifs"

local pd <const> = playdate
local gfx <const> = pd.graphics

GifPlayerEffect = {}
GifPlayerEffect.__index = GifPlayerEffect

GifPlayerEffect.MODE_STATIC = "static"
GifPlayerEffect.MODE_GIF = "gif"

local STATIC_NOISE_STEP_X <const> = 4
local STATIC_NOISE_STEP_Y <const> = 2
local STATIC_PREVIEW_FRAME_DURATION <const> = 12
local STATIC_PREVIEW_PHASES <const> = { 3.5, 19.25 }
local BAR_PATTERN_LARGE <const> = { 0x11, 0x22, 0x44, 0x88, 0x11, 0x22, 0x44, 0x88 }
local BAR_PATTERN_SMALL <const> = { 0x88, 0xcc, 0x66, 0x33, 0x11, 0x33, 0x66, 0xcc }

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

local function wrapFrame(frame, frameCount)
    if frameCount <= 0 then
        return 1
    end

    while frame < 1 do
        frame = frame + frameCount
    end

    while frame > frameCount do
        frame = frame - frameCount
    end

    return frame
end

local function makeBar(y, height, speed)
    return {
        y = y,
        height = height,
        baseSpeed = speed,
        speed = speed
    }
end

local function randomSmallBarSpeed()
    return 0.5 + (math.random() * 2.3)
end

function GifPlayerEffect.getModeLabel(modeId)
    if modeId == GifPlayerEffect.MODE_GIF then
        return "GIF Player"
    end
    return "CRT Static"
end

function GifPlayerEffect.new(width, height, options)
    local self = setmetatable({}, GifPlayerEffect)
    self.width = width
    self.height = height
    self.modeId = options and options.modeId or GifPlayerEffect.MODE_STATIC
    self.preview = options and options.preview == true or false
    self.catalog = GIF_CATALOG or {}
    self.gifIndex = 1
    self.activeGif = nil
    self.activeFrames = nil
    self.activeFramePosition = 1
    self.gifInverted = false
    self.staticPhase = 0
    self.staticPreviewFrame = 1
    self.staticPreviewTimer = STATIC_PREVIEW_FRAME_DURATION
    self.staticBarsActive = false
    self.bars = {
        large = makeBar(-48, 40, 0.9),
        small = makeBar(-18, 12, randomSmallBarSpeed())
    }
    self:loadGif(1)
    return self
end

function GifPlayerEffect:resetBars()
    self.bars.large = makeBar(-48, 40, 0.9)
    self.bars.small = makeBar(-18, 12, randomSmallBarSpeed())
end

function GifPlayerEffect:setPreview(isPreview)
    self.preview = isPreview == true
end

function GifPlayerEffect:activate()
end

function GifPlayerEffect:shutdown()
    self.activeFrames = nil
end

function GifPlayerEffect:loadGif(index)
    if #self.catalog == 0 then
        self.gifIndex = 1
        self.activeGif = nil
        self.activeFrames = nil
        self.activeFramePosition = 1
        return false
    end

    self.gifIndex = clamp(index, 1, #self.catalog)
    local item = self.catalog[self.gifIndex]
    local frames = gfx.imagetable.new(item.path)
    if frames == nil then
        self.activeGif = nil
        self.activeFrames = nil
        self.activeFramePosition = 1
        return false
    end

    self.activeGif = item
    self.activeFrames = frames
    self.activeFramePosition = 1
    return true
end

function GifPlayerEffect:stepGifSelection(delta)
    if #self.catalog == 0 then
        return
    end

    local nextIndex = self.gifIndex + delta
    if nextIndex < 1 then
        nextIndex = #self.catalog
    elseif nextIndex > #self.catalog then
        nextIndex = 1
    end
    self:loadGif(nextIndex)
end

function GifPlayerEffect:handlePrimaryAction()
    if self.modeId == GifPlayerEffect.MODE_STATIC then
        self.staticBarsActive = not self.staticBarsActive
        if self.staticBarsActive then
            self:resetBars()
        end
        return
    end

    self.gifInverted = not self.gifInverted
end

function GifPlayerEffect:applyCrank(change, acceleratedChange)
    if self.modeId == GifPlayerEffect.MODE_STATIC then
        return
    end

    if self.activeGif == nil or self.activeFrames == nil or math.abs(change) <= 0.01 then
        return
    end

    self.activeFramePosition = self.activeFramePosition + (change * 0.12)
    self.activeFramePosition = wrapFrame(self.activeFramePosition, self.activeGif.frameCount)
end

function GifPlayerEffect:updateDirectionalInput(upPressed, downPressed, leftPressed, rightPressed)
    if self.modeId ~= GifPlayerEffect.MODE_GIF then
        return
    end

    if upPressed then
        self:stepGifSelection(-1)
    elseif downPressed then
        self:stepGifSelection(1)
    elseif leftPressed and self.activeGif then
        self.activeFramePosition = wrapFrame(self.activeFramePosition - 1, self.activeGif.frameCount)
    elseif rightPressed and self.activeGif then
        self.activeFramePosition = wrapFrame(self.activeFramePosition + 1, self.activeGif.frameCount)
    end
end

function GifPlayerEffect:updateStatic()
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

    if not self.staticBarsActive then
        return
    end

    self.bars.large.y = self.bars.large.y + self.bars.large.baseSpeed
    self.bars.small.y = self.bars.small.y + self.bars.small.speed

    if self.bars.large.y >= self.height then
        self.bars.large.y = -self.bars.large.height
    end

    if self.bars.small.y >= self.height then
        self.bars.small.y = -self.bars.small.height
        self.bars.small.speed = randomSmallBarSpeed()
    end
end

function GifPlayerEffect:updateGif()
    if self.preview and self.activeGif ~= nil then
        self.activeFramePosition = wrapFrame(self.activeFramePosition + 0.45, self.activeGif.frameCount)
    end
end

function GifPlayerEffect:update()
    if self.modeId == GifPlayerEffect.MODE_STATIC then
        self:updateStatic()
    else
        self:updateGif()
    end
end

function GifPlayerEffect:drawStatic()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)

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

    if self.staticBarsActive then
        gfx.setImageDrawMode(gfx.kDrawModeXOR)
        gfx.setPattern(BAR_PATTERN_LARGE)
        gfx.fillRect(0, math.floor(self.bars.large.y), self.width, self.bars.large.height)
        gfx.setPattern(BAR_PATTERN_SMALL)
        gfx.fillRect(0, math.floor(self.bars.small.y), self.width, self.bars.small.height)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
end

function GifPlayerEffect:drawGif()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)

    if self.activeGif == nil or self.activeFrames == nil then
        gfx.drawTextAligned("No converted GIFs found.", 200, 112, kTextAlignment.center)
        gfx.drawTextAligned("Run gif_adapter.py from the project.", 200, 128, kTextAlignment.center)
        return
    end

    local frameIndex = wrapFrame(math.floor(self.activeFramePosition + 0.5), self.activeGif.frameCount)
    local frame = self.activeFrames:getImage(frameIndex)
    local drawX = math.floor((self.width - self.activeGif.width) / 2)
    local drawY = math.floor((self.height - self.activeGif.height) / 2)

    if self.gifInverted then
        gfx.setImageDrawMode(gfx.kDrawModeInverted)
    end
    frame:draw(drawX, drawY)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function GifPlayerEffect:drawOverlay()
    if self.preview then
        return
    end

    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, self.width, 14)
    gfx.fillRect(0, self.height - 16, self.width, 16)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)

    if self.modeId == GifPlayerEffect.MODE_STATIC then
        gfx.drawText("CRT STATIC  A: bars  B: menu", 8, 2)
    else
        local label = self.activeGif and self.activeGif.label or "GIF PLAYER"
        local frameCount = self.activeGif and self.activeGif.frameCount or 0
        local frameIndex = frameCount > 0 and wrapFrame(math.floor(self.activeFramePosition + 0.5), frameCount) or 0
        gfx.drawText(label, 8, 2)
        gfx.drawText(string.format("Frame %d/%d", frameIndex, frameCount), 292, 2)
        gfx.drawText("Up/Down gif  A invert  Crank frame  B back", 8, 226)
    end

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function GifPlayerEffect:draw()
    if self.modeId == GifPlayerEffect.MODE_STATIC then
        self:drawStatic()
    else
        self:drawGif()
    end
    if self.modeId ~= GifPlayerEffect.MODE_STATIC then
        self:drawOverlay()
    elseif not self.preview then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, 0, self.width, 14)
        gfx.setImageDrawMode(gfx.kDrawModeInverted)
        gfx.drawText("CRT STATIC  A: bars  B: menu", 8, 2)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
end
