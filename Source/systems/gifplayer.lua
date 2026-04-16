import "CoreLibs/graphics"
import "data/gifs"

local pd <const> = playdate
local gfx <const> = pd.graphics

GifPlayerEffect = {}
GifPlayerEffect.__index = GifPlayerEffect

GifPlayerEffect.MODE_GIF = "gif"
GifPlayerEffect.GIF_STATE_NORMAL = "normal"
GifPlayerEffect.GIF_STATE_INVERT = "invert"
GifPlayerEffect.GIF_STATE_SPIN = "spin"

local GIF_DEFAULT_SPIN_SPEED <const> = 0.45

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

function GifPlayerEffect.getModeLabel(modeId)
    return "GIF Player"
end

function GifPlayerEffect.new(width, height, options)
    local self = setmetatable({}, GifPlayerEffect)
    self.width = width
    self.height = height
    self.modeId = GifPlayerEffect.MODE_GIF
    self.preview = options and options.preview == true or false
    self.catalog = GIF_CATALOG or {}
    self.gifIndex = 1
    self.activeGif = nil
    self.activeFrames = nil
    self.activeFramePosition = 1
    self.gifInverted = false
    self.gifChooserOpen = not self.preview
    self.gifState = GifPlayerEffect.GIF_STATE_NORMAL
    self.gifPlaybackSpeed = GIF_DEFAULT_SPIN_SPEED
    self.gifSpeedAccumulator = 0
    self:loadGif(1)
    return self
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
    if self.gifChooserOpen then
        self.gifChooserOpen = false
        return
    end

    if self.gifState == GifPlayerEffect.GIF_STATE_NORMAL then
        self.gifState = GifPlayerEffect.GIF_STATE_INVERT
        self.gifInverted = true
    elseif self.gifState == GifPlayerEffect.GIF_STATE_INVERT then
        self.gifState = GifPlayerEffect.GIF_STATE_SPIN
        self.gifInverted = false
        if math.abs(self.gifPlaybackSpeed) < 0.05 then
            self.gifPlaybackSpeed = GIF_DEFAULT_SPIN_SPEED
        end
    else
        self.gifState = GifPlayerEffect.GIF_STATE_NORMAL
        self.gifInverted = false
    end
end

function GifPlayerEffect:handleBack()
    if self.gifChooserOpen then
        return false
    end

    self.gifChooserOpen = true
    self.gifState = GifPlayerEffect.GIF_STATE_NORMAL
    self.gifInverted = false
    return true
end

function GifPlayerEffect:stepSpeed(direction)
    if direction == 0 then
        return
    end

    if math.abs(self.gifPlaybackSpeed) >= 2 then
        self.gifPlaybackSpeed = self.gifPlaybackSpeed + direction
    else
        local nextSpeed = roundToTenth(self.gifPlaybackSpeed + (direction * 0.1))
        if nextSpeed > 1 then
            self.gifPlaybackSpeed = 2
        elseif nextSpeed < -1 then
            self.gifPlaybackSpeed = -2
        else
            self.gifPlaybackSpeed = nextSpeed
        end
    end
end

function GifPlayerEffect:applyCrank(change, acceleratedChange)
    if self.activeGif == nil or self.activeFrames == nil or self.gifChooserOpen then
        return
    end

    if self.gifState == GifPlayerEffect.GIF_STATE_SPIN then
        self.gifSpeedAccumulator = self.gifSpeedAccumulator + acceleratedChange
        while math.abs(self.gifSpeedAccumulator) >= 18 do
            local direction = self.gifSpeedAccumulator > 0 and 1 or -1
            self:stepSpeed(direction)
            self.gifSpeedAccumulator = self.gifSpeedAccumulator - (18 * direction)
        end
        return
    end

    if math.abs(change) <= 0.01 then
        return
    end

    self.activeFramePosition = self.activeFramePosition + (change * 0.12)
    self.activeFramePosition = wrapFrame(self.activeFramePosition, self.activeGif.frameCount)
end

function GifPlayerEffect:updateDirectionalInput(upPressed, downPressed, leftPressed, rightPressed)
    if self.gifChooserOpen then
        if upPressed then
            self:stepGifSelection(-1)
        elseif downPressed then
            self:stepGifSelection(1)
        end
        return
    end

    if self.gifState == GifPlayerEffect.GIF_STATE_SPIN then
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

function GifPlayerEffect:updateGif()
    if self.activeGif == nil then
        return
    end

    if self.preview or self.gifChooserOpen then
        self.activeFramePosition = wrapFrame(self.activeFramePosition + GIF_DEFAULT_SPIN_SPEED, self.activeGif.frameCount)
        return
    end

    if self.gifState == GifPlayerEffect.GIF_STATE_SPIN then
        self.activeFramePosition = wrapFrame(self.activeFramePosition + self.gifPlaybackSpeed, self.activeGif.frameCount)
    end
end

function GifPlayerEffect:update()
    self:updateGif()
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
    if self.preview or not self.gifChooserOpen then
        return
    end

    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, self.width, 14)
    gfx.fillRect(0, self.height - 16, self.width, 16)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)

    local label = self.activeGif and self.activeGif.label or "GIF PLAYER"
    local frameCount = self.activeGif and self.activeGif.frameCount or 0
    local frameIndex = frameCount > 0 and wrapFrame(math.floor(self.activeFramePosition + 0.5), frameCount) or 0
    gfx.drawText(label, 8, 2)
    gfx.drawText(string.format("Frame %d/%d", frameIndex, frameCount), 292, 2)
    gfx.drawText("Up/Down choose  A play  B back", 8, 226)

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function GifPlayerEffect:draw()
    self:drawGif()
    self:drawOverlay()
end
