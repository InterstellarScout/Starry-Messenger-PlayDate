import "CoreLibs/graphics"
import "data/gifs"
import "gameconfig"

local pd <const> = playdate
local gfx <const> = pd.graphics
local snd <const> = pd.sound
local GIF_PLAYER_CONFIG <const> = GameConfig and GameConfig.gifPlayer or {}

GifPlayerEffect = {}
GifPlayerEffect.__index = GifPlayerEffect

GifPlayerEffect.MODE_GIF = "gif"
GifPlayerEffect.GIF_STATE_NORMAL = "normal"
GifPlayerEffect.GIF_STATE_INVERT = "invert"
GifPlayerEffect.GIF_STATE_SPIN = "spin"

local GIF_DEFAULT_SPIN_SPEED <const> = GIF_PLAYER_CONFIG.defaultSpinSpeed or 0.45
local GIF_AUDIO_ROOT <const> = "audio/gifplayer"
local GIF_DEFAULT_SOURCE_FPS <const> = GIF_PLAYER_CONFIG.defaultSourceFps or 25
local GIF_AUDIO_SEEK_TOLERANCE <const> = GIF_PLAYER_CONFIG.audioSeekTolerance or 0.05
local CATEGORY_CRANK_STEP <const> = GIF_PLAYER_CONFIG.categoryCrankStep or 18
local CATEGORY_TEXT_MAX_WIDTH <const> = GIF_PLAYER_CONFIG.categoryTextMaxWidth or 360
local CATEGORY_TEXT_MAX_HEIGHT <const> = GIF_PLAYER_CONFIG.categoryTextMaxHeight or 34
local CATEGORY_CENTER_SCALE <const> = GIF_PLAYER_CONFIG.categoryCenterScale or 1.5
local CATEGORY_SIDE_SCALE <const> = GIF_PLAYER_CONFIG.categorySideScale or 0.75
local GIF_AUDIO_EXTENSIONS <const> = {
    ".mp3",
    ".wav",
    ".aif",
    ".aac",
    ".m4a"
}

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

local function displayInteger(value)
    local numericValue = tonumber(value) or 0
    if numericValue >= 0 then
        return tostring(math.floor(numericValue + 0.00001))
    end
    return tostring(math.ceil(numericValue - 0.00001))
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

local function toHex32(value)
    local digits = "0123456789abcdef"
    local remainder = math.floor(tonumber(value) or 0) % 4294967296
    local output = {}
    for index = 8, 1, -1 do
        local digit = math.floor((remainder % 16) + 1)
        output[index] = string.sub(digits, digit, digit)
        remainder = math.floor(remainder / 16)
    end
    return table.concat(output)
end

local function hashText(text)
    local hash = 5381
    for index = 1, #text do
        hash = math.floor(((hash * 33) + string.byte(text, index)) % 4294967296)
    end
    return toHex32(hash)
end

local function normalizeAudioFolderName(item)
    local slug = item and item.audioKey or nil
    if slug == nil then
        local path = item and item.path or ""
        slug = string.match(path, "([^/]+)$") or "gif"
    end

    if #slug > 40 then
        StarryLog.forceError(
            "gif audio slug truncate label="
                .. tostring(item and item.label or nil)
                .. " path="
                .. tostring(item and item.path or nil)
                .. " len="
                .. tostring(#slug)
        )
        slug = string.sub(slug, 1, 40) .. "-" .. hashText(slug)
    end

    return slug
end

local function hasAudioExtension(name)
    local lower = string.lower(name)
    for _, extension in ipairs(GIF_AUDIO_EXTENSIONS) do
        if string.sub(lower, -#extension) == extension then
            return true
        end
    end
    return false
end

local function clampAudioRate(rate)
    if rate < 0.05 then
        return 0.05
    end
    if rate > 4 then
        return 4
    end
    return rate
end

local function getItemCategory(item)
    if item and item.category ~= nil then
        return item.category
    end

    local path = item and item.path or ""
    local category = string.match(path, "^gifs/([^/]+)/")
    return category or "Unsorted"
end

function GifPlayerEffect.getModeLabel(modeId)
    return "GIF Player"
end

function GifPlayerEffect.new(width, height, options)
    local self = setmetatable({}, GifPlayerEffect)
    options = options or {}
    self.width = width
    self.height = height
    self.modeId = GifPlayerEffect.MODE_GIF
    self.preview = options.preview == true
    self.previewItemPath = options.previewItemPath
    self.allCatalog = GIF_CATALOG or {}
    self.categories = self:buildCategories(self.allCatalog)
    self.categoryIndex = 1
    self.activeCategory = nil
    self.catalog = {}
    self.gifIndex = 1
    self.activeGif = nil
    self.activeFrames = nil
    self.activeFramePosition = 1
    self.gifInverted = false
    self.categoryChooserOpen = not self.preview
    self.gifChooserOpen = false
    self.gifState = GifPlayerEffect.GIF_STATE_NORMAL
    self.gifPlaybackSpeed = GIF_DEFAULT_SPIN_SPEED
    self.gifSpeedAccumulator = 0
    self.categoryCrankAccumulator = 0
    self.refreshRate = pd.display.getRefreshRate() or 30
    self.lastUpdateTimeMs = pd.getCurrentTimeMilliseconds()
    self.audioFolderName = nil
    self.audioPath = nil
    self.audioPlayer = nil
    self.audioLength = nil
    self.audioReverseMuted = false
    self.largeFont = gfx.font.new("/System/Fonts/Roobert-20-Medium")
    self.selectedFont = gfx.font.new("/System/Fonts/Roobert-24-Medium")
    self.smallFont = gfx.getSystemFont()
    self.textImageCache = {}
    if self.preview and self.previewItemPath ~= nil then
        if not self:selectGifByPath(self.previewItemPath) then
            StarryLog.error("gif preview item path not found: %s", tostring(self.previewItemPath))
            self:selectCategory(1, true)
        end
    else
        self:selectCategory(1, true)
    end
    return self
end

function GifPlayerEffect:buildCategories(catalog)
    local grouped = {}
    for _, item in ipairs(catalog) do
        local categoryName = getItemCategory(item)
        local bucket = grouped[categoryName]
        if bucket == nil then
            bucket = {
                name = categoryName,
                items = {}
            }
            grouped[categoryName] = bucket
        end
        bucket.items[#bucket.items + 1] = item
    end

    local categories = {}
    for _, category in pairs(grouped) do
        table.sort(category.items, function(left, right)
            return tostring(left.label):lower() < tostring(right.label):lower()
        end)
        categories[#categories + 1] = category
    end

    table.sort(categories, function(left, right)
        return tostring(left.name):lower() < tostring(right.name):lower()
    end)
    return categories
end

function GifPlayerEffect:setPreview(isPreview)
    local wasPreview = self.preview
    self.preview = isPreview == true
    if self.preview then
        self.categoryChooserOpen = false
        self.gifChooserOpen = false
    elseif wasPreview then
        self.categoryChooserOpen = true
        self.gifChooserOpen = false
        self.gifState = GifPlayerEffect.GIF_STATE_NORMAL
        self.gifInverted = false
    end
end

function GifPlayerEffect:getScaledTextImage(text, font, keyPrefix)
    local cacheKey = (keyPrefix or "text") .. "|" .. text
    local cached = self.textImageCache[cacheKey]
    if cached ~= nil then
        return cached
    end

    gfx.setFont(font)
    local width, height = gfx.getTextSize(text)
    width = math.max(1, math.ceil(width))
    height = math.max(1, math.ceil(height))
    local image = gfx.image.new(width, height, gfx.kColorClear)
    gfx.pushContext(image)
        gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        gfx.setFont(font)
        gfx.drawText(text, 0, 0)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.popContext()

    cached = {
        image = image,
        width = width,
        height = height
    }
    self.textImageCache[cacheKey] = cached
    return cached
end

function GifPlayerEffect:drawScaledText(text, font, keyPrefix, centerX, centerY, scale)
    local cached = self:getScaledTextImage(text, font, keyPrefix)
    local constrainedScale = scale
    constrainedScale = math.min(constrainedScale, CATEGORY_TEXT_MAX_WIDTH / cached.width)
    constrainedScale = math.min(constrainedScale, CATEGORY_TEXT_MAX_HEIGHT / cached.height)
    local drawX = centerX - ((cached.width * constrainedScale) * 0.5)
    local drawY = centerY - ((cached.height * constrainedScale) * 0.5)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    cached.image:drawScaled(drawX, drawY, constrainedScale)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function GifPlayerEffect:activate()
    self.lastUpdateTimeMs = pd.getCurrentTimeMilliseconds()
    self:syncAudioToCurrentState(true)
end

function GifPlayerEffect:shutdown()
    self:stopAudio(true)
    self.activeFrames = nil
end

function GifPlayerEffect:getGifDurationSeconds()
    if self.audioLength and self.audioLength > 0 then
        return self.audioLength
    end

    if self.activeGif == nil or self.activeGif.frameCount <= 0 then
        return 0
    end

    local sourceFps = self.activeGif.fps or GIF_DEFAULT_SOURCE_FPS
    return self.activeGif.frameCount / sourceFps
end

function GifPlayerEffect:getCurrentFrameTimeSeconds()
    if self.activeGif == nil or self.activeGif.frameCount <= 0 then
        return 0
    end

    local duration = self:getGifDurationSeconds()
    if duration <= 0 then
        return 0
    end

    local wrappedFrame = wrapFrame(self.activeFramePosition, self.activeGif.frameCount)
    return ((wrappedFrame - 1) / self.activeGif.frameCount) * duration
end

function GifPlayerEffect:getAudioPlaybackRate()
    if self.activeGif == nil or self.activeGif.frameCount <= 0 then
        return 1
    end

    local duration = self:getGifDurationSeconds()
    if duration <= 0 then
        return clampAudioRate(math.abs(self.gifPlaybackSpeed))
    end

    local sourceFps = self.activeGif.frameCount / duration
    if sourceFps <= 0 then
        sourceFps = GIF_DEFAULT_SOURCE_FPS
    end

    local visualFramesPerSecond = math.abs(self.gifPlaybackSpeed) * self.refreshRate
    return clampAudioRate(visualFramesPerSecond / sourceFps)
end

function GifPlayerEffect:findAudioPathForItem(item)
    if item == nil then
        return nil, nil
    end

    local folderName = normalizeAudioFolderName(item)
    local folderPath = GIF_AUDIO_ROOT .. "/" .. folderName
    local entries = pd.file.listFiles(folderPath) or {}
    StarryLog.forceError(
        "gif audio lookup label="
            .. tostring(item.label)
            .. " path="
            .. tostring(item.path)
            .. " folder="
            .. tostring(folderName)
            .. " entries="
            .. tostring(#entries)
    )
    table.sort(entries)
    for _, entry in ipairs(entries) do
        local normalized = string.gsub(entry, "\\", "/")
        if hasAudioExtension(normalized) then
            return folderPath .. "/" .. normalized, folderName
        end
    end

    return nil, folderName
end

function GifPlayerEffect:stopAudio(fullReset)
    if self.audioPlayer ~= nil then
        self.audioPlayer:stop()
    end

    if fullReset == true then
        self.audioPlayer = nil
        self.audioPath = nil
        self.audioLength = nil
        self.audioFolderName = nil
        self.audioReverseMuted = false
    end
end

function GifPlayerEffect:pauseAudioAtCurrentFrame()
    if self.audioPlayer == nil then
        return
    end

    if self.audioPlayer:isPlaying() then
        self.audioPlayer:pause()
    end

    local targetOffset = self:getCurrentFrameTimeSeconds()
    local currentOffset = self.audioPlayer:getOffset()
    if currentOffset == nil or math.abs(currentOffset - targetOffset) > GIF_AUDIO_SEEK_TOLERANCE then
        self.audioPlayer:setOffset(targetOffset)
    end
end

function GifPlayerEffect:loadAudioForActiveGif()
    self:stopAudio(true)

    if self.activeGif == nil then
        return
    end

    local audioPath, folderName = self:findAudioPathForItem(self.activeGif)
    self.audioFolderName = folderName
    if audioPath == nil then
        return
    end

    local player = snd.fileplayer.new(audioPath, 0.2)
    if player == nil then
        StarryLog.error("gif audio player failed to initialize: %s", audioPath)
        return
    end

    local ok, errorMessage = player:setBufferSize(0.2)
    if not ok then
        StarryLog.error("gif audio buffer failed to initialize for %s: %s", audioPath, errorMessage or "unknown error")
        return
    end

    player:setVolume(1)
    player:setStopOnUnderrun(true)

    self.audioPlayer = player
    self.audioPath = audioPath
    self.audioLength = player:getLength()
    self.audioReverseMuted = false
end

function GifPlayerEffect:syncAudioToCurrentState(forceSeek)
    if self.audioPlayer == nil then
        self.audioReverseMuted = false
        return
    end

    if self.preview or self.categoryChooserOpen or self.gifChooserOpen then
        self:stopAudio(false)
        self.audioReverseMuted = false
        return
    end

    if self.gifState ~= GifPlayerEffect.GIF_STATE_SPIN then
        self:pauseAudioAtCurrentFrame()
        self.audioReverseMuted = false
        return
    end

    if self.gifPlaybackSpeed <= 0 then
        self:pauseAudioAtCurrentFrame()
        self.audioReverseMuted = self.gifPlaybackSpeed < 0
        return
    end

    local targetOffset = self:getCurrentFrameTimeSeconds()
    local targetRate = self:getAudioPlaybackRate()
    self.audioPlayer:setRate(targetRate)

    if self.audioPlayer:isPlaying() then
        local currentOffset = self.audioPlayer:getOffset()
        if forceSeek == true or currentOffset == nil or math.abs(currentOffset - targetOffset) > GIF_AUDIO_SEEK_TOLERANCE then
            self.audioPlayer:setOffset(targetOffset)
        end
    else
        self.audioPlayer:setOffset(targetOffset)
        local ok, errorMessage = self.audioPlayer:play(0)
        if not ok then
            StarryLog.error("gif audio playback failed for %s: %s", self.audioPath or "unknown", errorMessage or "unknown error")
        end
    end

    self.audioReverseMuted = false
end

function GifPlayerEffect:loadGif(index)
    if #self.catalog == 0 then
        self.gifIndex = 1
        self.activeGif = nil
        self.activeFrames = nil
        self.activeFramePosition = 1
        self:stopAudio(true)
        return false
    end

    self.gifIndex = clamp(index, 1, #self.catalog)
    local item = self.catalog[self.gifIndex]
    StarryLog.debug("gif load attempt category=%s index=%d path=%s", tostring(self.activeCategory and self.activeCategory.name or nil), self.gifIndex, tostring(item and item.path or nil))
    local frames = gfx.imagetable.new(item.path)
    if frames == nil then
        StarryLog.error("gif load failed path=%s category=%s index=%d", tostring(item and item.path or nil), tostring(self.activeCategory and self.activeCategory.name or nil), self.gifIndex)
        self.activeGif = nil
        self.activeFrames = nil
        self.activeFramePosition = 1
        self:stopAudio(true)
        return false
    end

    self.activeGif = item
    self.activeFrames = frames
    self.activeFramePosition = 1
    self.lastUpdateTimeMs = pd.getCurrentTimeMilliseconds()
    self:loadAudioForActiveGif()
    self:syncAudioToCurrentState(true)
    return true
end

function GifPlayerEffect:selectGifByPath(path)
    for categoryIndex, category in ipairs(self.categories) do
        for gifIndex, item in ipairs(category.items) do
            if item.path == path then
                self.categoryIndex = categoryIndex
                self.activeCategory = category
                self.catalog = category.items
                self.gifIndex = gifIndex
                StarryLog.debug("gif preview path matched category=%s gif=%s", tostring(category.name), tostring(item.label))
                return self:loadGif(self.gifIndex)
            end
        end
    end

    return false
end

function GifPlayerEffect:selectCategory(index, resetGifIndex)
    if #self.categories == 0 then
        StarryLog.forceError("gif category select skipped because no categories are available")
        self.categoryIndex = 1
        self.activeCategory = nil
        self.catalog = {}
        self.activeGif = nil
        self.activeFrames = nil
        self:stopAudio(true)
        return false
    end

    self.categoryIndex = clamp(index, 1, #self.categories)
    self.activeCategory = self.categories[self.categoryIndex]
    self.catalog = self.activeCategory.items
    StarryLog.forceError(
        "gif category select resolved requested="
            .. tostring(index)
            .. " actual="
            .. tostring(self.categoryIndex)
            .. " name="
            .. tostring(self.activeCategory and self.activeCategory.name or nil)
            .. " items="
            .. tostring(#self.catalog)
            .. " resetGifIndex="
            .. tostring(resetGifIndex ~= false)
    )

    if resetGifIndex ~= false then
        self.gifIndex = 1
    else
        self.gifIndex = clamp(self.gifIndex, 1, #self.catalog)
    end

    return self:loadGif(self.gifIndex)
end

function GifPlayerEffect:stepCategorySelection(delta)
    if #self.categories == 0 then
        StarryLog.forceError("gif category step skipped because no categories are available")
        return
    end

    local nextIndex = self.categoryIndex + delta
    if nextIndex < 1 then
        nextIndex = #self.categories
    elseif nextIndex > #self.categories then
        nextIndex = 1
    end
    StarryLog.forceError(
        "gif category step delta="
            .. tostring(delta)
            .. " current="
            .. tostring(self.categoryIndex)
            .. " next="
            .. tostring(nextIndex)
            .. " total="
            .. tostring(#self.categories)
    )

    self:selectCategory(nextIndex, true)
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
    if self.categoryChooserOpen then
        self.categoryChooserOpen = false
        self.gifChooserOpen = true
        self.gifState = GifPlayerEffect.GIF_STATE_NORMAL
        self.gifInverted = false
        self.lastUpdateTimeMs = pd.getCurrentTimeMilliseconds()
        self:syncAudioToCurrentState(true)
        return
    end

    if self.gifChooserOpen then
        self.gifChooserOpen = false
        self.lastUpdateTimeMs = pd.getCurrentTimeMilliseconds()
        self:syncAudioToCurrentState(true)
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

    self.lastUpdateTimeMs = pd.getCurrentTimeMilliseconds()
    self:syncAudioToCurrentState(true)
end

function GifPlayerEffect:handleBack()
    if self.categoryChooserOpen then
        return false
    end

    if self.gifChooserOpen then
        self.categoryChooserOpen = true
        self.gifChooserOpen = false
        self.gifState = GifPlayerEffect.GIF_STATE_NORMAL
        self.gifInverted = false
        self:syncAudioToCurrentState(true)
        return true
    end

    self.gifChooserOpen = true
    self.gifState = GifPlayerEffect.GIF_STATE_NORMAL
    self.gifInverted = false
    self:syncAudioToCurrentState(true)
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
    if self.categoryChooserOpen then
        self.categoryCrankAccumulator = self.categoryCrankAccumulator + acceleratedChange
        while math.abs(self.categoryCrankAccumulator) >= CATEGORY_CRANK_STEP do
            local direction = self.categoryCrankAccumulator > 0 and 1 or -1
            self:stepCategorySelection(direction)
            self.categoryCrankAccumulator = self.categoryCrankAccumulator - (CATEGORY_CRANK_STEP * direction)
        end
        return
    end

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
        self:syncAudioToCurrentState(true)
        return
    end

    if math.abs(change) <= 0.01 then
        return
    end

    self.activeFramePosition = self.activeFramePosition + (change * 0.12)
    self.activeFramePosition = wrapFrame(self.activeFramePosition, self.activeGif.frameCount)
    self:syncAudioToCurrentState(false)
end

function GifPlayerEffect:updateDirectionalInput(upPressed, downPressed, leftPressed, rightPressed)
    if self.categoryChooserOpen then
        if upPressed or leftPressed then
            self:stepCategorySelection(-1)
        elseif downPressed or rightPressed then
            self:stepCategorySelection(1)
        end
        return
    end

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
        self:syncAudioToCurrentState(false)
    elseif rightPressed and self.activeGif then
        self.activeFramePosition = wrapFrame(self.activeFramePosition + 1, self.activeGif.frameCount)
        self:syncAudioToCurrentState(false)
    end
end

function GifPlayerEffect:updateGif()
    if self.activeGif == nil then
        return
    end

    local now = pd.getCurrentTimeMilliseconds()
    local deltaSeconds = math.max(0, now - (self.lastUpdateTimeMs or now)) / 1000
    self.lastUpdateTimeMs = now
    local frameDeltaScale = self.refreshRate * deltaSeconds

    if self.preview or self.categoryChooserOpen or self.gifChooserOpen then
        self.activeFramePosition = wrapFrame(self.activeFramePosition + (GIF_DEFAULT_SPIN_SPEED * frameDeltaScale), self.activeGif.frameCount)
        return
    end

    if self.gifState == GifPlayerEffect.GIF_STATE_SPIN then
        self.activeFramePosition = wrapFrame(self.activeFramePosition + (self.gifPlaybackSpeed * frameDeltaScale), self.activeGif.frameCount)
    end
end

function GifPlayerEffect:update()
    self:updateGif()
    self:syncAudioToCurrentState(false)
end

function GifPlayerEffect:drawGif()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)

    if self.activeGif == nil or self.activeFrames == nil then
        gfx.drawTextAligned("No converted GIFs found.", 200, 112, kTextAlignment.center)
        gfx.drawTextAligned("Add frame sets under Source/gifs/<Category>.", 200, 128, kTextAlignment.center)
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

function GifPlayerEffect:drawCategoryOverlay()
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, self.width, 18)
    gfx.fillRect(0, self.height - 22, self.width, 22)

    local categoryCount = #self.categories
    local activeCategoryName = self.activeCategory and self.activeCategory.name or "No Categories"
    local prevIndex = categoryCount > 0 and (self.categoryIndex == 1 and categoryCount or self.categoryIndex - 1) or 0
    local nextIndex = categoryCount > 0 and (self.categoryIndex == categoryCount and 1 or self.categoryIndex + 1) or 0

    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawText("GIF Categories", 8, 4)
    gfx.drawText(displayInteger(self.categoryIndex) .. "/" .. displayInteger(categoryCount), 350, 4)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)

    self:drawScaledText(activeCategoryName, self.selectedFont or self.smallFont, "category-selected", 200, 88, CATEGORY_CENTER_SCALE)
    if prevIndex > 0 and prevIndex ~= self.categoryIndex then
        self:drawScaledText(self.categories[prevIndex].name, self.largeFont or self.smallFont, "category-prev", 200, 62, CATEGORY_SIDE_SCALE)
    end
    if nextIndex > 0 and nextIndex ~= self.categoryIndex then
        self:drawScaledText(self.categories[nextIndex].name, self.largeFont or self.smallFont, "category-next", 200, 114, CATEGORY_SIDE_SCALE)
    end

    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    if self.activeCategory ~= nil then
        gfx.drawTextAligned(displayInteger(#self.activeCategory.items) .. " GIFs", 200, 138, kTextAlignment.center)
    end
    gfx.drawText("Crank/Up/Down choose category  A open  B title", 8, 228)

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function GifPlayerEffect:drawGifChooserOverlay()
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, self.width, 18)
    gfx.fillRect(0, self.height - 22, self.width, 22)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)

    local categoryName = self.activeCategory and self.activeCategory.name or "GIF PLAYER"
    local label = self.activeGif and self.activeGif.label or "No GIFs"
    local count = #self.catalog
    gfx.drawText(categoryName, 8, 4)
    gfx.drawText(displayInteger(self.gifIndex) .. "/" .. displayInteger(math.max(1, count)), 350, 4)
    gfx.drawTextAligned(label, 200, 212, kTextAlignment.center)
    gfx.drawText("Up/Down choose gif  A play  B categories", 8, 228)

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function GifPlayerEffect:drawPlaybackOverlay()
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, self.width, 14)
    gfx.fillRect(0, self.height - 16, self.width, 16)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)

    local categoryName = self.activeCategory and self.activeCategory.name or "GIF PLAYER"
    local label = self.activeGif and self.activeGif.label or "GIF PLAYER"
    local frameCount = self.activeGif and self.activeGif.frameCount or 0
    local frameIndex = frameCount > 0 and wrapFrame(math.floor(self.activeFramePosition + 0.5), frameCount) or 0
    gfx.drawText(categoryName .. ": " .. label, 8, 2)
    gfx.drawText("Frame " .. displayInteger(frameIndex) .. "/" .. displayInteger(frameCount), 292, 2)

    local audioLine = "Audio: none"
    if self.audioPath ~= nil then
        if self.audioReverseMuted then
            audioLine = "Audio: reverse spin muted"
        elseif self.gifState == GifPlayerEffect.GIF_STATE_SPIN and self.gifPlaybackSpeed > 0 then
            audioLine = "Audio: synced"
        else
            audioLine = "Audio: scrub sync"
        end
    end
    gfx.drawText(audioLine, 8, 212)
    gfx.drawText("Up/Down choose  Left/Right step  A mode  B browser", 8, 226)

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function GifPlayerEffect:drawOverlay()
    if self.preview then
        return
    end

    if self.categoryChooserOpen then
        self:drawCategoryOverlay()
        return
    end

    if self.gifChooserOpen then
        self:drawGifChooserOverlay()
        return
    end

    self:drawPlaybackOverlay()
end

function GifPlayerEffect:draw()
    self:drawGif()
    self:drawOverlay()
end
