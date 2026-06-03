import "CoreLibs/graphics"
import "data/photos"

local pd <const> = playdate
local gfx <const> = pd.graphics

PhotoViewerEffect = {}
PhotoViewerEffect.__index = PhotoViewerEffect

local PHOTO_ADVANCE_CRANK_STEP <const> = 20
local PHOTO_PREVIEW_ADVANCE_FRAMES <const> = 80
local PHOTO_AUTO_ADVANCE_FRAMES <const> = 120
local PHOTO_VIEW_MODE_FILL <const> = 1
local PHOTO_VIEW_MODE_FIT <const> = 2
local PHOTO_VIEW_MODE_INVERT <const> = 3

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    elseif value > maxValue then
        return maxValue
    end
    return value
end

local function wrapIndex(index, count)
    if count <= 0 then
        return 1
    end
    while index < 1 do
        index = index + count
    end
    while index > count do
        index = index - count
    end
    return index
end

function PhotoViewerEffect.getModeLabel()
    return "Photo Viewer"
end

function PhotoViewerEffect.new(width, height, options)
    local self = setmetatable({}, PhotoViewerEffect)
    options = options or {}
    self.width = width or 400
    self.height = height or 240
    self.preview = options.preview == true
    self.catalog = PHOTO_CATALOG or {}
    self.index = clamp(options.photoIndex or 1, 1, math.max(1, #self.catalog))
    self.currentImage = nil
    self.currentPath = nil
    self.crankAccumulator = 0
    self.autoPlay = self.preview
    self.autoAdvanceFrames = self.preview and PHOTO_PREVIEW_ADVANCE_FRAMES or PHOTO_AUTO_ADVANCE_FRAMES
    self.frame = 0
    self.showInfo = false
    self.viewMode = PHOTO_VIEW_MODE_FILL
    self.statusMessage = nil
    self.statusFrames = 0
    self:loadCurrentImage()
    return self
end

function PhotoViewerEffect:setPreview(preview)
    self.preview = preview == true
    self.autoPlay = self.preview or self.autoPlay
    self.autoAdvanceFrames = self.preview and PHOTO_PREVIEW_ADVANCE_FRAMES or PHOTO_AUTO_ADVANCE_FRAMES
end

function PhotoViewerEffect:activate()
end

function PhotoViewerEffect:shutdown()
end

function PhotoViewerEffect:getCurrentPhoto()
    return self.catalog[self.index]
end

function PhotoViewerEffect:getCurrentPhotoPath()
    local photo = self:getCurrentPhoto()
    if photo == nil then
        return nil
    end

    if self.viewMode == PHOTO_VIEW_MODE_FIT then
        return photo.fitPath or photo.path or photo.fillPath
    end

    return photo.fillPath or photo.path or photo.fitPath
end

function PhotoViewerEffect:loadCurrentImage()
    local path = self:getCurrentPhotoPath()
    self.currentImage = nil
    self.currentPath = nil
    if path == nil then
        return
    end

    self.currentPath = path
    self.currentImage = gfx.image.new(path)
end

function PhotoViewerEffect:setStatus(message)
    self.statusMessage = message
    self.statusFrames = 75
end

function PhotoViewerEffect:setIndex(index)
    local count = #self.catalog
    if count <= 0 then
        return
    end

    local nextIndex = wrapIndex(index, count)
    if nextIndex == self.index and self.currentImage ~= nil then
        return
    end

    self.index = nextIndex
    self:loadCurrentImage()
end

function PhotoViewerEffect:stepPhoto(direction)
    if direction == 0 then
        return
    end
    self:setIndex(self.index + direction)
end

function PhotoViewerEffect:applyCrank(change, acceleratedChange)
    if self.preview or math.abs(acceleratedChange or 0) <= 0.01 then
        return
    end

    self.crankAccumulator = self.crankAccumulator + acceleratedChange
    while self.crankAccumulator >= PHOTO_ADVANCE_CRANK_STEP do
        self:stepPhoto(1)
        self.crankAccumulator = self.crankAccumulator - PHOTO_ADVANCE_CRANK_STEP
    end
    while self.crankAccumulator <= -PHOTO_ADVANCE_CRANK_STEP do
        self:stepPhoto(-1)
        self.crankAccumulator = self.crankAccumulator + PHOTO_ADVANCE_CRANK_STEP
    end
end

function PhotoViewerEffect:handlePrimaryAction()
    self.autoPlay = not self.autoPlay
    self:setStatus(self.autoPlay and "Autoplay on" or "Autoplay off")
end

function PhotoViewerEffect:handleUp()
    self.showInfo = not self.showInfo
    self:setStatus(self.showInfo and "Info on" or "Info off")
end

function PhotoViewerEffect:getViewModeLabel()
    if self.viewMode == PHOTO_VIEW_MODE_FIT then
        return "Fit to screen"
    elseif self.viewMode == PHOTO_VIEW_MODE_INVERT then
        return "Inverted"
    end
    return "Full screen"
end

function PhotoViewerEffect:handleDown()
    self.viewMode = self.viewMode + 1
    if self.viewMode > PHOTO_VIEW_MODE_INVERT then
        self.viewMode = PHOTO_VIEW_MODE_FILL
    end
    self:loadCurrentImage()
    self:setStatus(self:getViewModeLabel())
end

function PhotoViewerEffect:update()
    self.frame = self.frame + 1
    if self.autoPlay and #self.catalog > 1 and (self.frame % self.autoAdvanceFrames) == 0 then
        self:stepPhoto(1)
    end

    if self.statusFrames > 0 then
        self.statusFrames = self.statusFrames - 1
        if self.statusFrames <= 0 then
            self.statusMessage = nil
        end
    end
end

function PhotoViewerEffect:drawBackdrop()
    gfx.setColor(gfx.kColorWhite)
    gfx.setDitherPattern(0.25, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRoundRect(4, 4, 392, 232, 12)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(4, 4, 392, 232, 12)
end

function PhotoViewerEffect:drawImage()
    if self.currentImage == nil then
        gfx.drawTextAligned("No photos found.", 200, 112, kTextAlignment.center)
        return
    end

    gfx.setImageDrawMode(self.viewMode == PHOTO_VIEW_MODE_INVERT and gfx.kDrawModeInverted or gfx.kDrawModeCopy)
    self.currentImage:draw(0, 0)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function PhotoViewerEffect:drawInfo()
    if not self.showInfo then
        return
    end

    local photo = self:getCurrentPhoto()
    local title = photo and photo.label or "Untitled"
    local photographer = photo and photo.photographer or "NASA"

    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(12, 168, 138, 56, 10)
    gfx.setDitherPattern(0.65, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRoundRect(158, 176, 230, 52, 10)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawTextInRect(title, 20, 178, 122, 18)
    gfx.drawTextInRect(photographer, 20, 196, 122, 16)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawTextAligned(string.format("%d / %d", self.index, math.max(1, #self.catalog)), 376, 184, kTextAlignment.right)
    gfx.drawTextInRect("A autoplay  Up info  Down view  B back", 166, 184, 202, 16)
    gfx.drawTextInRect("Crank or Left/Right browse", 166, 202, 202, 16)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function PhotoViewerEffect:drawStatus()
    if self.statusMessage == nil then
        return
    end
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawTextAligned(self.statusMessage, 200, 12, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function PhotoViewerEffect:draw()
    self:drawBackdrop()
    self:drawImage()
    self:drawInfo()
    self:drawStatus()
end
