import "gameconfig"

--[[
Title carousel scene.

Purpose:
- displays the current game catalog over a live animated preview
- handles view selection, per-view mode rotation, and preview handoff
- draws the shared title overlay and bottom instruction band
]]
local pd <const> = playdate
local gfx <const> = pd.graphics
local TITLE_TEXT_MAX_WIDTH <const> = 360
local TITLE_TEXT_MAX_HEIGHT <const> = 34
local TITLE_CENTER_SCALE <const> = 1.5
local TITLE_SIDE_SCALE <const> = 0.75
local PREVIEW_RESUME_DELAY_FRAMES <const> = 15
local TITLE_FIREWORK_MIN_DELAY_FRAMES <const> = 30
local TITLE_FIREWORK_MAX_DELAY_FRAMES <const> = 120
local TITLE_FIREWORK_GRAVITY <const> = 0.07
local TITLE_CONFIG <const> = GameConfig and GameConfig.title or {}
local TITLE_FREE_SPIN_TRIGGER_DEGREES <const> = TITLE_CONFIG.freeSpinTriggerDegrees or 3600
local TITLE_FREE_SPIN_WINDOW_FRAMES <const> = TITLE_CONFIG.freeSpinWindowFrames or 219
local TITLE_FREE_SPIN_IMMEDIATE_CHANGE <const> = TITLE_CONFIG.freeSpinImmediateChange or 56
local TITLE_FREE_SPIN_ACCELERATION_SCALE <const> = TITLE_CONFIG.freeSpinAccelerationScale or 0.0042
local TITLE_FREE_SPIN_DECAY <const> = TITLE_CONFIG.freeSpinDecay or 0.94
local TITLE_FREE_SPIN_STOP_VELOCITY <const> = TITLE_CONFIG.freeSpinStopVelocity or 0.018
local TITLE_FREE_SPIN_STAR_FADE_STEP <const> = TITLE_CONFIG.freeSpinStarFadeStep or 0.12
local TITLE_FREE_SPIN_STAR_COUNT <const> = TITLE_CONFIG.freeSpinStarCount or 140
local TITLE_FREE_SPIN_STAR_SPEED_SCALE <const> = TITLE_CONFIG.freeSpinStarSpeedScale or 48
local TITLE_FREE_SPIN_STAR_MIN_SPEED <const> = TITLE_CONFIG.freeSpinStarMinSpeed or 1.2
local TITLE_FIDGET_WARP_THRESHOLD <const> = TITLE_CONFIG.fidgetWarpThreshold or 600
local TITLE_FIDGET_WARP_BUILD_SCALE <const> = TITLE_CONFIG.fidgetWarpBuildScale or (1 / 30)
local TITLE_FIDGET_WARP_VISUAL_DIVISOR <const> = TITLE_CONFIG.fidgetWarpVisualDivisor or 120
local TITLE_FIDGET_WARP_VISUAL_MIN_SPEED <const> = TITLE_CONFIG.fidgetWarpVisualMinSpeed or 0.4
local TITLE_FIDGET_WARP_VISUAL_MAX_SPEED <const> = TITLE_CONFIG.fidgetWarpVisualMaxSpeed or 20
local TITLE_FIDGET_WARP_STAR_TIER_THRESHOLD <const> = TITLE_CONFIG.fidgetWarpStarTierThreshold or 3000
local TITLE_FIDGET_WARP_STAR_TIER_STEP <const> = TITLE_CONFIG.fidgetWarpStarTierStep or 1000
local TITLE_FIDGET_WARP_STAR_SIZE_PERCENT_STEP <const> = TITLE_CONFIG.fidgetWarpStarSizePercentStep or 35
local TITLE_FIDGET_FALL_SPEED_MODIFIER <const> = TITLE_CONFIG.fidgetFallSpeedModifier or -0.5
local TITLE_FIDGET_WARP_SPEED_MODIFIER <const> = TITLE_CONFIG.fidgetWarpSpeedModifier or -0.5
local TITLE_CRANK_BUMP_THRESHOLD <const> = TITLE_CONFIG.crankBumpThreshold or 8
local TITLE_SLOW_CRANK_SCALE <const> = TITLE_CONFIG.slowCrankScale or 1.5
local WARP_CONFIG <const> = GameConfig and GameConfig.warp or {}
local STAR_FALL_CONFIG <const> = GameConfig and GameConfig.starFall or {}
local LIFE_CONFIG <const> = GameConfig and GameConfig.life or {}
local LAVA_CONFIG <const> = GameConfig and GameConfig.lavaLamp or {}
local CRTTV_TITLE_STILL_PATH <const> = "images/loading/crttv-loading-still"
local LIFE_TITLE_STILL_PATH <const> = "images/loading/gameoflife-loading-still"
local freeSpinSessionHighScoreValue = 0

local function roundNearest(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function stepPreviewGarbageCollector()
    if collectgarbage == nil then
        return
    end

    pcall(function()
        collectgarbage("step", 64)
    end)
end

local function drawMutedTitleOverlay(ditherAmount)
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(ditherAmount or 0.5, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(0, 0, 400, 240)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
end

local function getDefaultSelectedIndex(viewItems)
    for index, item in ipairs(viewItems or {}) do
        if item.id == "warp" then
            return index
        end
    end

    return 1
end

local function getAppVersionLabel()
    local version = StarryMessengerAppVersion
    if version ~= nil and version ~= "" then
        return "v" .. tostring(version)
    end

    local metadata = pd.metadata or {}
    version = metadata.version
    if version == nil or version == "" then
        return nil
    end

    return "v" .. tostring(version)
end

local function makeWarpPreview(speed)
    local preview = Starfield.newWarpSpeed(400, 240, WARP_CONFIG.previewStarCount or 320)
    preview.speed = speed or 1
    return preview
end

local function makeStaticImagePreview(path)
    local image = gfx.image.new(path)
    return {
        setPreview = function()
        end,
        activate = function()
        end,
        shutdown = function()
        end,
        update = function()
        end,
        draw = function()
            if image ~= nil then
                image:draw(0, 0)
            end
        end
    }
end

local function randomTitleFireworkDelay()
    return math.random(TITLE_FIREWORK_MIN_DELAY_FRAMES, TITLE_FIREWORK_MAX_DELAY_FRAMES)
end

TitleScene = {}
TitleScene.__index = TitleScene

function TitleScene.new(config)
    local self = setmetatable({}, TitleScene)
    self.viewItems = config.viewItems
    self.onSelectView = config.onSelectView
    self.onBack = config.onBack
    self.onResetSelection = config.onResetSelection
    self.catalog = config.catalog or "single"
    self.playerCount = config.playerCount or 1
    self.selected = config.selectedIndex or getDefaultSelectedIndex(config.viewItems)
    self.displayPosition = self.selected
    self.crankAccumulator = 0
    self.headerTitle = config.headerTitle or "STARRY MESSENGER"
    self.headerSubtitle = config.headerSubtitle or "Choose a view"
    self.largeFont = gfx.font.new("/System/Fonts/Roobert-20-Medium")
    self.selectedFont = gfx.font.new("/System/Fonts/Roobert-24-Medium")
    self.smallFont = gfx.getSystemFont()
    self.preview = config.previewEffect
    self.handoffPreview = nil
    self.previewViewId = config.previewViewId
    self.previewModeId = config.previewModeId
    self.previewLocked = self.preview ~= nil
    self.pendingPreviewRequest = nil
    self.previewLoading = false
    self.previewPauseFrames = 0
    self.modeDisplayPosition = 1
    self.modeTargetPosition = 1
    self.textImageCache = {}
    self.titleFireworkBursts = {}
    self.titleFireworkTimer = randomTitleFireworkDelay()
    self.frame = 0
    self.freeSpinActive = false
    self.freeSpinVelocity = 0
    self.freeSpinSettling = false
    self.freeSpinStarPreview = nil
    self.freeSpinStarFade = 0
    self.freeSpinStarFadeDirection = 0
    self.freeSpinSpeedOverlayEnabled = false
    self.freeSpinSpeedOverlayLocked = false
    self.freeSpinLockedOverlayLabel = nil
    self.freeSpinLockedOverlayValue = nil
    self.freeSpinEffectMode = "fidget"
    self.freeSpinWarpMetric = nil
    self.crankBurstSamples = {}
    self.crankBurstDegrees = 0
    if not self.preview then
        self:setPreview()
    end
    self:syncModeDisplayPosition(true)
    return self
end

function TitleScene:getSelectedView()
    return self.viewItems[self.selected]
end

function TitleScene:getSelectedActualViewId()
    local selectedView = self:getSelectedView()
    if selectedView == nil then
        return nil
    end
    return selectedView.openViewId or selectedView.id
end

function TitleScene:getSelectedControlViewId()
    local selectedView = self:getSelectedView()
    if selectedView == nil then
        return nil
    end
    return selectedView.controlViewId or selectedView.openViewId or selectedView.id
end

function TitleScene:getSelectedModeId()
    local selectedView = self:getSelectedView()
    return selectedView and selectedView.modeId or nil
end

function TitleScene:usesDarkText()
    local selectedView = self:getSelectedView()
    if selectedView == nil then
        return false
    end

    if selectedView.id == "duck" then
        return true
    end

    if (selectedView.id == "warp" or selectedView.id == "fall") and selectedView.modeId == Starfield.MODE_INVERSE then
        return true
    end

    if selectedView.id == "lava" and selectedView.modeId == LavaLamp.MODE_INVERSE then
        return true
    end

    return false
end

function TitleScene:usesInvertedText()
    return false
end

function TitleScene:createFreeSpinStarPreview()
    local preview = Starfield.newStarFall(400, 240, TITLE_FREE_SPIN_STAR_COUNT, {
        uniformMotion = true,
        uniformStarSize = 2,
        uniformStarSpeed = 1,
        disableLargeStar = true
    })
    preview.speed = TITLE_FREE_SPIN_STAR_MIN_SPEED
    preview.directionAngle = -90
    return preview
end

function TitleScene:getFreeSpinWarpStarSizePercent(warpMetric)
    if warpMetric == nil or warpMetric < TITLE_FIDGET_WARP_STAR_TIER_THRESHOLD then
        return 0
    end

    local tierIndex = math.floor((warpMetric - TITLE_FIDGET_WARP_STAR_TIER_THRESHOLD) / TITLE_FIDGET_WARP_STAR_TIER_STEP) + 1
    return tierIndex * TITLE_FIDGET_WARP_STAR_SIZE_PERCENT_STEP
end

function TitleScene:getCurrentFreeSpinOverlayMetric()
    local speedLabel = "Speed"
    local speedValue = self:getFreeSpinFidgetMetric()
    if self.freeSpinEffectMode == "warp" and self.freeSpinWarpMetric ~= nil then
        speedLabel = "Warp Speed"
        speedValue = self.freeSpinWarpMetric
    end

    return speedLabel, speedValue
end

function TitleScene:recordFreeSpinHighScore()
    local _, speedValue = self:getCurrentFreeSpinOverlayMetric()
    freeSpinSessionHighScoreValue = math.max(freeSpinSessionHighScoreValue, speedValue or 0)
end

function TitleScene.resetSessionFreeSpinHighScore()
    freeSpinSessionHighScoreValue = 0
end

function TitleScene:resetFreeSpinHighScore()
    TitleScene.resetSessionFreeSpinHighScore()
end

function TitleScene:createFreeSpinWarpPreview()
    local preview = Starfield.newWarpSpeed(400, 240, WARP_CONFIG.previewStarCount or 320, {
        modeId = Starfield.MODE_STANDARD
    })
    preview.speed = 0
    return preview
end

function TitleScene:getFreeSpinFidgetMetric()
    return math.max(
        TITLE_FREE_SPIN_STAR_MIN_SPEED,
        math.abs(self.freeSpinVelocity) * TITLE_FREE_SPIN_STAR_SPEED_SCALE
    )
end

function TitleScene:getFreeSpinResponseScale(modifier)
    return math.max(0.05, 1 + (tonumber(modifier) or 0))
end

function TitleScene:getFreeSpinFallVisualSpeed(fidgetMetric)
    return math.max(
        TITLE_FREE_SPIN_STAR_MIN_SPEED,
        fidgetMetric * self:getFreeSpinResponseScale(TITLE_FIDGET_FALL_SPEED_MODIFIER)
    )
end

function TitleScene:getFreeSpinWarpVisualMetric(fidgetMetric)
    return fidgetMetric * self:getFreeSpinResponseScale(TITLE_FIDGET_WARP_SPEED_MODIFIER)
end

function TitleScene:switchFreeSpinEffect(mode)
    if self.freeSpinStarPreview and self.freeSpinStarPreview.shutdown then
        self.freeSpinStarPreview:shutdown()
    end

    self.freeSpinEffectMode = mode or "fidget"
    if self.freeSpinEffectMode == "warp" then
        self.freeSpinStarPreview = self:createFreeSpinWarpPreview()
        self.freeSpinWarpMetric = 0
    else
        self.freeSpinStarPreview = self:createFreeSpinStarPreview()
        self.freeSpinWarpMetric = nil
    end
end

function TitleScene:shutdownFreeSpinStarPreview()
    if self.freeSpinStarPreview and self.freeSpinStarPreview.shutdown then
        self.freeSpinStarPreview:shutdown()
    end
    self.freeSpinStarPreview = nil
    self.freeSpinStarFade = 0
    self.freeSpinStarFadeDirection = 0
    self.freeSpinSpeedOverlayEnabled = false
    self.freeSpinSpeedOverlayLocked = false
    self.freeSpinLockedOverlayLabel = nil
    self.freeSpinLockedOverlayValue = nil
    self.freeSpinEffectMode = "fidget"
    self.freeSpinWarpMetric = nil
end

function TitleScene:updateFreeSpinStarPreview(acceleratedChange)
    if self.freeSpinStarPreview == nil then
        return
    end

    local fidgetMetric = self:getFreeSpinFidgetMetric()
    if self.freeSpinEffectMode == "warp" then
        if fidgetMetric < TITLE_FIDGET_WARP_THRESHOLD then
            self:switchFreeSpinEffect("fidget")
        end
    elseif fidgetMetric >= TITLE_FIDGET_WARP_THRESHOLD then
        self:switchFreeSpinEffect("warp")
    end

    local visualChange = acceleratedChange or 0
    if math.abs(visualChange) <= 0.01 then
        visualChange = self.freeSpinVelocity
    end

    if self.freeSpinEffectMode == "warp" then
        if self.freeSpinWarpMetric == nil then
            self.freeSpinWarpMetric = 0
        end
        self.freeSpinWarpMetric = self.freeSpinWarpMetric + (self:getFreeSpinWarpVisualMetric(fidgetMetric) * TITLE_FIDGET_WARP_BUILD_SCALE)
        self.freeSpinStarPreview:setWarpStarSizePercent(self:getFreeSpinWarpStarSizePercent(self.freeSpinWarpMetric))
        self.freeSpinStarPreview.speed = math.max(
            TITLE_FIDGET_WARP_VISUAL_MIN_SPEED,
            math.min(TITLE_FIDGET_WARP_VISUAL_MAX_SPEED, self.freeSpinWarpMetric / TITLE_FIDGET_WARP_VISUAL_DIVISOR)
        )
    else
        if visualChange > 0.01 then
            self.freeSpinStarPreview.directionAngle = -90
        elseif visualChange < -0.01 then
            self.freeSpinStarPreview.directionAngle = 90
        end

        self.freeSpinStarPreview.speed = self:getFreeSpinFallVisualSpeed(fidgetMetric)
    end
    self.freeSpinStarPreview:update()

    if self.freeSpinStarFadeDirection ~= 0 then
        self.freeSpinStarFade = math.max(
            0,
            math.min(1, self.freeSpinStarFade + (self.freeSpinStarFadeDirection * TITLE_FREE_SPIN_STAR_FADE_STEP))
        )
        if self.freeSpinStarFade >= 1 and self.freeSpinStarFadeDirection > 0 then
            self.freeSpinStarFadeDirection = 0
        elseif self.freeSpinStarFade <= 0 and self.freeSpinStarFadeDirection < 0 then
            self.freeSpinStarFadeDirection = 0
            self:shutdownFreeSpinStarPreview()
            if self.freeSpinSettling then
                self.freeSpinSettling = false
                self:setPreview()
            end
        end
    end
end

function TitleScene:drawFreeSpinStarPreview()
    if self.freeSpinStarPreview == nil or self.freeSpinStarFade <= 0 then
        return
    end

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, 400, 240)
    self.freeSpinStarPreview:draw()
    if self.freeSpinStarFade < 1 then
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(1 - self.freeSpinStarFade, gfx.image.kDitherTypeBayer8x8)
        gfx.fillRect(0, 0, 400, 240)
        gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    end
end

function TitleScene:enableFreeSpinSpeedOverlay()
    self.freeSpinSpeedOverlayEnabled = true
    self.freeSpinSpeedOverlayLocked = false
    self.freeSpinLockedOverlayLabel = nil
    self.freeSpinLockedOverlayValue = nil
end

function TitleScene:toggleFreeSpinSpeedOverlay()
    if not self.freeSpinSpeedOverlayEnabled then
        self:enableFreeSpinSpeedOverlay()
        return
    end

    if self.freeSpinSpeedOverlayLocked then
        self.freeSpinSpeedOverlayLocked = false
        self.freeSpinLockedOverlayLabel = nil
        self.freeSpinLockedOverlayValue = nil
        return
    end

    self.freeSpinLockedOverlayLabel, self.freeSpinLockedOverlayValue = self:getCurrentFreeSpinOverlayMetric()
    self.freeSpinSpeedOverlayLocked = true
end

function TitleScene:drawFreeSpinSpeedOverlay()
    if not self.freeSpinActive or not self.freeSpinSpeedOverlayEnabled then
        return
    end

    local speedLabel, speedValue = self:getCurrentFreeSpinOverlayMetric()
    if self.freeSpinSpeedOverlayLocked then
        speedLabel = self.freeSpinLockedOverlayLabel or speedLabel
        speedValue = self.freeSpinLockedOverlayValue or speedValue
    end

    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawTextAligned(
        string.format(
            "High %.2f - %s %.2f%s",
            freeSpinSessionHighScoreValue,
            speedLabel,
            speedValue,
            self.freeSpinSpeedOverlayLocked and " [LOCK]" or ""
        ),
        200,
        56,
        kTextAlignment.center
    )
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function TitleScene:updateSelectedIndexFromDisplayPosition()
    local count = #self.viewItems
    local roundedIndex = roundNearest(self.displayPosition)
    while roundedIndex < 1 do
        roundedIndex = roundedIndex + count
    end
    while roundedIndex > count do
        roundedIndex = roundedIndex - count
    end
    self.selected = roundedIndex
end

function TitleScene:getTextColor()
    if self:usesDarkText() then
        return gfx.kColorBlack
    end
    return gfx.kColorWhite
end

function TitleScene:getTextDrawMode()
    if self:usesInvertedText() then
        return gfx.kDrawModeInverted
    end
    if self:usesDarkText() then
        return gfx.kDrawModeFillBlack
    end
    return gfx.kDrawModeFillWhite
end

function TitleScene:getScaledTextImage(text, font, keyPrefix)
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

function TitleScene:drawScaledText(text, font, keyPrefix, centerX, centerY, scale)
    local cached = self:getScaledTextImage(text, font, keyPrefix)
    local constrainedScale = scale
    if TITLE_TEXT_MAX_WIDTH > 0 then
        constrainedScale = math.min(constrainedScale, TITLE_TEXT_MAX_WIDTH / cached.width)
    end
    if TITLE_TEXT_MAX_HEIGHT > 0 then
        constrainedScale = math.min(constrainedScale, TITLE_TEXT_MAX_HEIGHT / cached.height)
    end

    local drawX = centerX - ((cached.width * constrainedScale) * 0.5)
    local drawY = centerY - ((cached.height * constrainedScale) * 0.5)
    gfx.setImageDrawMode(self:getTextDrawMode())
    cached.image:drawScaled(drawX, drawY, constrainedScale)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function TitleScene:getSelectedModeLabel()
    local selectedView = self:getSelectedView()
    if not selectedView or not selectedView.modes or #selectedView.modes == 0 then
        return nil
    end

    if selectedView.getModeLabel then
        return selectedView.getModeLabel(selectedView.modeId)
    end

    return tostring(selectedView.modeId)
end

function TitleScene:getModeIndexForView(view)
    if not view or not view.modes or #view.modes == 0 then
        return 1
    end

    for index, modeId in ipairs(view.modes) do
        if modeId == view.modeId then
            return index
        end
    end

    return 1
end

function TitleScene:syncModeDisplayPosition(force)
    local selectedView = self:getSelectedView()
    local targetIndex = self:getModeIndexForView(selectedView)
    if force or not selectedView or not selectedView.modes or #selectedView.modes == 0 then
        self.modeDisplayPosition = targetIndex
        self.modeTargetPosition = targetIndex
    elseif self.modeDisplayPosition == nil then
        self.modeDisplayPosition = targetIndex
        self.modeTargetPosition = targetIndex
    elseif self.modeTargetPosition == nil then
        self.modeTargetPosition = targetIndex
    end
end

function TitleScene:activatePreview(preview)
    if preview and preview.setPreview then
        preview:setPreview(true)
    end
    if preview and preview.activate then
        preview:activate()
    end
end

function TitleScene:makeFallbackPreview()
    return makeWarpPreview(1)
end

function TitleScene:replacePreviewWithFallback(context, err)
    StarryLog.error("title preview fallback: %s error=%s", tostring(context), tostring(err))

    if self.preview and self.preview.shutdown then
        self.preview:shutdown()
    end

    self.preview = self:makeFallbackPreview()
    self.previewLocked = false
    self.previewViewId = "warp"
    self.previewModeId = nil
    self:activatePreview(self.preview)
end

function TitleScene:shouldPersistLockedPreview(selectedView)
    if not self.previewLocked or not self.preview then
        return false
    end

    if not selectedView or selectedView.id ~= self.previewViewId then
        return false
    end

    if selectedView.modeId ~= nil then
        return selectedView.modeId == self.previewModeId
    end

    return true
end

function TitleScene:isMultiplayerCatalog()
    return self.catalog == "multi"
end

function TitleScene:shouldHandoffPreview(selectedView)
    if self.preview == nil or selectedView == nil then
        return false
    end

    local actualViewId = selectedView.openViewId or selectedView.id
    if actualViewId == "duck" or actualViewId == "orbital" or selectedView.id == "rccar_multi" or actualViewId == "multiplayer" or actualViewId == "crttv" or actualViewId == "life" then
        return false
    end

    if actualViewId == "life" and selectedView.modeId == GameOfLife.MODE_REVIEW then
        return false
    end

    return true
end

function TitleScene:setPreview(forceFresh)
    local selectedView = self:getSelectedView()
    local actualViewId = selectedView and (selectedView.openViewId or selectedView.id) or nil
    StarryLog.debug(
        "title setPreview view=%s mode=%s forceFresh=%s locked=%s",
        tostring(actualViewId),
        tostring(selectedView and selectedView.modeId or nil),
        tostring(forceFresh == true),
        tostring(self.previewLocked)
    )
    self.pendingPreviewRequest = nil
    self.previewLoading = false
    local previousPreview = self.preview
    if previousPreview and previousPreview.shutdown then
        previousPreview:shutdown()
    end
    self.preview = nil
    stepPreviewGarbageCollector()
    local ok, nextPreview = pcall(function()
        if actualViewId == "fall" then
            return Starfield.newStarFall(400, 240, STAR_FALL_CONFIG.previewStarCount or 360, {
                modeId = selectedView.modeId
            })
        elseif actualViewId == "multiplayer" then
            return makeWarpPreview(TITLE_CONFIG.multiplayerPreviewSpeed or 2)
        elseif actualViewId == "life" then
            return makeStaticImagePreview(LIFE_TITLE_STILL_PATH)
        elseif actualViewId == "fireworks" then
            return FireworksShow.new(400, 240, {
                preview = true
            })
        elseif actualViewId == "crttv" then
            return makeStaticImagePreview(CRTTV_TITLE_STILL_PATH)
        elseif actualViewId == "vibes" then
            return VibesEffect.new(400, 240, {
                preview = true,
                modeId = selectedView.modeId,
                selectionLocked = selectedView.openViewId == "vibes"
            })
        elseif actualViewId == "puddledrops" then
            return PuddleDrops.new(400, 240, {
                modeId = selectedView.modeId,
                preview = true
            })
        elseif actualViewId == "dropper" then
            return Dropper.new(400, 240, {
                preview = true
            })
        elseif actualViewId == "tiltballs" then
            return TiltBalls.new(400, 240, {
                preview = true
            })
        elseif actualViewId == "wacky" then
            return WackyInflatable.new(400, 240, {
                preview = true
            })
        elseif actualViewId == "dimensionalsplit" then
            return DimensionalSplit.new(400, 240, {
                preview = true
            })
        elseif actualViewId == "spaceminer" then
            return SpaceMiner.new(400, 240, {
                modeId = selectedView.modeId,
                preview = true
            })
        elseif actualViewId == "trailblazer" then
            return TrailBlazer.new(400, 240, {
                modeId = selectedView.modeId,
                preview = true
            })
        elseif actualViewId == "marblemadness" then
            return MarbleMadness.new(400, 240, {
                preview = true
            })
        elseif actualViewId == "photoviewer" then
            return PhotoViewerEffect.new(400, 240, {
                preview = true
            })
        elseif actualViewId == "gifplayer" then
            return GifPlayerEffect.new(400, 240, {
                modeId = selectedView.modeId,
                preview = true,
                previewItemPath = "gifs/Spinning/seal-spinning-spinning-spinning-gif-spinning-seal-water"
            })
        elseif actualViewId == "fishpond" then
            return FishPond.new(400, 240, selectedView.modeId, {
                preview = true
            })
        elseif actualViewId == "duck" then
            return DuckGameScene.new({
                preview = true,
                multiplayer = self:isMultiplayerCatalog(),
                playerCount = self.playerCount,
                modeId = selectedView.modeId
            })
        elseif actualViewId == "orbital" then
            return OrbitalDefenseScene.new({
                preview = true,
                multiplayer = self:isMultiplayerCatalog(),
                playerCount = self.playerCount
            })
        elseif actualViewId == "rccar" or selectedView.id == "rccar_multi" then
            return RCCarArena.new(400, 240, selectedView.modeId, {
                preview = true
            })
        elseif actualViewId == "lava" then
            return LavaLamp.new(400, 240, LAVA_CONFIG.previewBubbleCount or 36, {
                modeId = selectedView.modeId
            })
        end

        local preview = Starfield.newWarpSpeed(400, 240, WARP_CONFIG.previewStarCount or 320, {
            modeId = selectedView.modeId
        })
        preview.speed = TITLE_CONFIG.warpPreviewSpeed or 1
        return preview
    end)

    if not ok then
        self.preview = nil
        self:replacePreviewWithFallback("setPreview:" .. tostring(selectedView and selectedView.id), nextPreview)
        return
    end

    self.preview = nextPreview
    self.previewLocked = false
    self.previewViewId = selectedView.id
    self.previewModeId = selectedView.modeId

    self:activatePreview(self.preview)
end

function TitleScene:processPendingPreview()
    local request = self.pendingPreviewRequest
    local selectedView = self:getSelectedView()
    if request == nil or selectedView == nil or selectedView.id ~= "life" or selectedView.modeId ~= request.modeId then
        return
    end

    StarryLog.forceDebug(
        "title processPendingPreview life mode=%s forceFresh=%s pause=%s",
        tostring(request.modeId),
        tostring(request.forceFresh == true),
        tostring(self.previewPauseFrames)
    )

    self.pendingPreviewRequest = nil
    self.previewLoading = false

    local previousPreview = self.preview
    if previousPreview and previousPreview.shutdown then
        previousPreview:shutdown()
    end
    self.preview = nil
    stepPreviewGarbageCollector()

    local ok, nextPreview = pcall(function()
        return GameOfLife.new(400, 240, LIFE_CONFIG.previewCellSize or 6, LIFE_CONFIG.previewSeedChance or 0.3, {
            modeId = request.modeId,
            preview = true,
            forceFresh = request.forceFresh
        })
    end)

    if not ok then
        StarryLog.forceError("title life preview construction failed mode=%s err=%s", tostring(request.modeId), tostring(nextPreview))
        self:replacePreviewWithFallback("processPendingPreview:life", nextPreview)
        return
    end

    StarryLog.forceDebug("title life preview ready mode=%s", tostring(request.modeId))

    self.preview = nextPreview
    self.previewLocked = false
    self.previewViewId = selectedView.id
    self.previewModeId = selectedView.modeId
    self:activatePreview(self.preview)
end

function TitleScene:updateSelection(delta)
    self.selected = self.selected + delta
    if self.selected < 1 then
        self.selected = #self.viewItems
    elseif self.selected > #self.viewItems then
        self.selected = 1
    end
    self:syncModeDisplayPosition(true)
    self.previewPauseFrames = PREVIEW_RESUME_DELAY_FRAMES
    StarryLog.info("title selection changed: index=%d label=%s", self.selected, self.viewItems[self.selected].label)
    if not self:shouldPersistLockedPreview(self:getSelectedView()) then
        self:setPreview()
    end
end

function TitleScene:changeSelectedMode(delta)
    local selectedView = self:getSelectedView()
    if not selectedView or not selectedView.modes or #selectedView.modes == 0 then
        return false
    end

    if #selectedView.modes == 1 then
        selectedView.modeId = selectedView.modes[1]
        self.modeDisplayPosition = 1
        self.modeTargetPosition = 1
        return false
    end

    local currentIndex = self:getModeIndexForView(selectedView)

    local nextIndex = currentIndex + delta
    if nextIndex < 1 then
        nextIndex = #selectedView.modes
    elseif nextIndex > #selectedView.modes then
        nextIndex = 1
    end

    selectedView.modeId = selectedView.modes[nextIndex]
    self.modeTargetPosition = (self.modeTargetPosition or currentIndex) + (delta < 0 and -1 or 1)
    self.previewPauseFrames = PREVIEW_RESUME_DELAY_FRAMES
    StarryLog.info(
        "title mode changed: view=%s mode=%s",
        selectedView.id,
        tostring(selectedView.modeId)
    )

    if not self:shouldPersistLockedPreview(selectedView) then
        self:setPreview()
    end

    return true
end

function TitleScene:getWrappedOffset(index)
    local count = #self.viewItems
    local offset = index - self.displayPosition

    if offset > (count / 2) then
        offset = offset - count
    elseif offset < -(count / 2) then
        offset = offset + count
    end

    return offset
end

function TitleScene:updateDisplayPosition()
    local count = #self.viewItems
    local delta = self.selected - self.displayPosition

    if delta > (count / 2) then
        delta = delta - count
    elseif delta < -(count / 2) then
        delta = delta + count
    end

    if math.abs(delta) < 0.001 then
        self.displayPosition = self.selected
        return
    end

    self.displayPosition = self.displayPosition + (delta * 0.28)

    if self.displayPosition < 1 then
        self.displayPosition = self.displayPosition + count
    elseif self.displayPosition > count then
        self.displayPosition = self.displayPosition - count
    end
end

function TitleScene:updateModeDisplayPosition()
    local selectedView = self:getSelectedView()
    if not selectedView or not selectedView.modes or #selectedView.modes == 0 then
        self.modeDisplayPosition = 1
        self.modeTargetPosition = 1
        return
    end

    local targetPosition = self.modeTargetPosition or self:getModeIndexForView(selectedView)
    local delta = targetPosition - self.modeDisplayPosition

    if math.abs(delta) < 0.001 then
        self.modeDisplayPosition = targetPosition
        return
    end

    self.modeDisplayPosition = self.modeDisplayPosition + (delta * 0.28)
    if math.abs(targetPosition - self.modeDisplayPosition) < 0.001 then
        self.modeDisplayPosition = targetPosition
    end
end

function TitleScene:recordCrankBurst(acceleratedChange)
    local amount = math.abs(acceleratedChange or 0)
    self.crankBurstSamples[#self.crankBurstSamples + 1] = {
        frame = self.frame,
        amount = amount
    }
    self.crankBurstDegrees = self.crankBurstDegrees + amount

    while #self.crankBurstSamples > 0 do
        local sample = self.crankBurstSamples[1]
        if (self.frame - sample.frame) <= TITLE_FREE_SPIN_WINDOW_FRAMES then
            break
        end
        self.crankBurstDegrees = self.crankBurstDegrees - sample.amount
        table.remove(self.crankBurstSamples, 1)
    end
end

function TitleScene:activateFreeSpin(acceleratedChange)
    if self.preview and self.preview.shutdown then
        self.preview:shutdown()
    end
    self.preview = nil
    self.pendingPreviewRequest = nil
    self.previewLoading = false
    stepPreviewGarbageCollector()
    self.freeSpinActive = true
    self.freeSpinSettling = false
    self.freeSpinVelocity = self.freeSpinVelocity + ((acceleratedChange or 0) * TITLE_FREE_SPIN_ACCELERATION_SCALE)
    self.freeSpinEffectMode = "fidget"
    self.freeSpinWarpMetric = nil
    self:switchFreeSpinEffect("fidget")
    self.freeSpinStarFade = 0
    self.freeSpinStarFadeDirection = 1
    self.freeSpinSpeedOverlayEnabled = false
    self.freeSpinSpeedOverlayLocked = false
    self.freeSpinLockedOverlayLabel = nil
    self.freeSpinLockedOverlayValue = nil
    self.previewPauseFrames = PREVIEW_RESUME_DELAY_FRAMES
    self.crankAccumulator = 0
    self:recordFreeSpinHighScore()
    StarryLog.info("title free spin activated velocity=%.3f", self.freeSpinVelocity)
end

function TitleScene:finishFreeSpin()
    self.freeSpinActive = false
    self.freeSpinVelocity = 0
    self.freeSpinSpeedOverlayEnabled = false
    self.freeSpinSpeedOverlayLocked = false
    self.freeSpinLockedOverlayLabel = nil
    self.freeSpinLockedOverlayValue = nil
    self:updateSelectedIndexFromDisplayPosition()
    self:syncModeDisplayPosition(true)
    if self.preview == nil or not self:shouldPersistLockedPreview(self:getSelectedView()) then
        self.freeSpinSettling = true
        if self.freeSpinStarPreview ~= nil then
            self.freeSpinStarFadeDirection = -1
        else
            self.freeSpinSettling = false
            self:setPreview()
        end
    end
    StarryLog.info("title free spin settled index=%d label=%s", self.selected, self.viewItems[self.selected].label)
end

function TitleScene:updateFreeSpin(acceleratedChange)
    local count = #self.viewItems
    if math.abs(acceleratedChange or 0) > 0.01 then
        self.freeSpinVelocity = self.freeSpinVelocity + ((acceleratedChange or 0) * TITLE_FREE_SPIN_ACCELERATION_SCALE)
        self.previewPauseFrames = PREVIEW_RESUME_DELAY_FRAMES
    else
        self.freeSpinVelocity = self.freeSpinVelocity * TITLE_FREE_SPIN_DECAY
    end

    self.displayPosition = self.displayPosition + self.freeSpinVelocity
    while self.displayPosition < 1 do
        self.displayPosition = self.displayPosition + count
    end
    while self.displayPosition > count do
        self.displayPosition = self.displayPosition - count
    end

    self:updateSelectedIndexFromDisplayPosition()
    self:syncModeDisplayPosition(true)
    self:updateFreeSpinStarPreview(acceleratedChange)
    self:recordFreeSpinHighScore()

    if self.previewPauseFrames > 0 then
        self.previewPauseFrames = self.previewPauseFrames - 1
    end

    if math.abs(self.freeSpinVelocity) <= TITLE_FREE_SPIN_STOP_VELOCITY and math.abs(acceleratedChange or 0) <= 0.01 then
        self:finishFreeSpin()
    end
end

function TitleScene:updateCrank(change, acceleratedChange)
    local effectiveChange = acceleratedChange
    if math.abs(change or 0) > math.abs(effectiveChange or 0) then
        effectiveChange = (change or 0) * TITLE_SLOW_CRANK_SCALE
    end

    self:recordCrankBurst(acceleratedChange)

    if self.freeSpinActive then
        self:updateFreeSpin(acceleratedChange)
        return
    end

    if math.abs(acceleratedChange or 0) > 0.01 then
        self.previewPauseFrames = PREVIEW_RESUME_DELAY_FRAMES
    elseif self.previewPauseFrames > 0 then
        self.previewPauseFrames = self.previewPauseFrames - 1
    end

    if math.abs(acceleratedChange or 0) >= TITLE_FREE_SPIN_IMMEDIATE_CHANGE
        or self.crankBurstDegrees >= TITLE_FREE_SPIN_TRIGGER_DEGREES then
        self:activateFreeSpin(acceleratedChange)
        return
    end

    self.crankAccumulator = self.crankAccumulator + effectiveChange

    while self.crankAccumulator >= TITLE_CRANK_BUMP_THRESHOLD do
        self:updateSelection(1)
        self.crankAccumulator = self.crankAccumulator - TITLE_CRANK_BUMP_THRESHOLD
    end

    while self.crankAccumulator <= -TITLE_CRANK_BUMP_THRESHOLD do
        self:updateSelection(-1)
        self.crankAccumulator = self.crankAccumulator + TITLE_CRANK_BUMP_THRESHOLD
    end
end

function TitleScene:spawnTitleFireworkBurst(originX, originY)
    local sparks = {}
    local sparkCount = math.random(10, 14)
    for index = 1, sparkCount do
        local angle = (-math.pi * 0.92) + (((index - 1) / math.max(1, sparkCount - 1)) * (math.pi * 0.84))
        local speed = 1.2 + (math.random() * 1.6)
        sparks[index] = {
            x = originX,
            y = originY,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = 12 + math.random(0, 8),
            size = math.random() < 0.2 and 2 or 1
        }
    end

    self.titleFireworkBursts[#self.titleFireworkBursts + 1] = {
        sparks = sparks
    }
end

function TitleScene:updateTitleFireworks()
    self.titleFireworkTimer = self.titleFireworkTimer - 1
    if self.titleFireworkTimer <= 0 then
        local groundY = 220
        self:spawnTitleFireworkBurst(100, groundY)
        self:spawnTitleFireworkBurst(300, groundY)
        self.titleFireworkTimer = randomTitleFireworkDelay()
    end

    for burstIndex = #self.titleFireworkBursts, 1, -1 do
        local burst = self.titleFireworkBursts[burstIndex]
        for sparkIndex = #burst.sparks, 1, -1 do
            local spark = burst.sparks[sparkIndex]
            spark.x = spark.x + spark.vx
            spark.y = spark.y + spark.vy
            spark.vy = spark.vy + TITLE_FIREWORK_GRAVITY
            spark.life = spark.life - 1
            if spark.life <= 0 then
                table.remove(burst.sparks, sparkIndex)
            end
        end

        if #burst.sparks == 0 then
            table.remove(self.titleFireworkBursts, burstIndex)
        end
    end
end

function TitleScene:drawModeCarousel(selectedView, centerY)
    if not selectedView or not selectedView.modes or #selectedView.modes == 0 then
        return
    end

    local modeCount = #selectedView.modes
    local spacing = 164
    local visibilityRange = 1.1
    local entries = {}

    for index, modeId in ipairs(selectedView.modes) do
        for wrap = -1, 1 do
            local offset = (index + (wrap * modeCount)) - (self.modeDisplayPosition or index)
            if math.abs(offset) <= visibilityRange then
                local label = selectedView.getModeLabel and selectedView.getModeLabel(modeId) or tostring(modeId)
                local x = 200 + (offset * spacing)
                local emphasis = math.max(0, 1 - math.min(1, math.abs(offset)))
                local scale = TITLE_SIDE_SCALE + ((TITLE_CENTER_SCALE - TITLE_SIDE_SCALE) * emphasis)
                entries[#entries + 1] = {
                    label = label,
                    x = x,
                    centerY = centerY + 8,
                    scale = scale,
                    offset = offset
                }
            end
        end
    end

    table.sort(entries, function(a, b)
        return math.abs(a.offset) > math.abs(b.offset)
    end)

    for _, entry in ipairs(entries) do
        self:drawScaledText(entry.label, self.largeFont or self.smallFont, "mode", entry.x, entry.centerY, entry.scale)
    end
end

function TitleScene:drawBottomInstructions()
    local selectedView = self:getSelectedView()
    local spec = selectedView and ControlHelp.getEntrySpec(self:getSelectedControlViewId(), selectedView.modeId) or nil
    local topY = 206

    gfx.setFont(self.smallFont)
    gfx.setImageDrawMode(self:getTextDrawMode())
    local titleLine = "Crank or Up/Down browse. Left/Right mode. A open. B back."
    if self.previewLocked then
        titleLine = "Crank or Up/Down browse. Left/Right mode. A open. B reset preview."
    elseif self.previewLoading then
        titleLine = "Game of Life loading. Up/Down can move away before it opens."
    end
    gfx.drawTextInRect(titleLine, 16, topY, 368, 14, nil, nil, kTextAlignment.center)

    local modeLine = spec and spec.lines and spec.lines[1] or "B: return to title."
    gfx.drawTextInRect(modeLine, 16, topY + 15, 368, 14, nil, nil, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function TitleScene:drawAppVersion()
    if self.freeSpinActive or self.freeSpinSettling or self.freeSpinStarPreview ~= nil then
        return
    end

    local versionLabel = getAppVersionLabel()
    if versionLabel == nil then
        return
    end

    gfx.setFont(self.smallFont)
    gfx.setImageDrawMode(self:getTextDrawMode())
    gfx.drawTextAligned(versionLabel, 392, 224, kTextAlignment.right)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function TitleScene:drawTitleFireworks()
    gfx.setColor(gfx.kColorBlack)
    for _, burst in ipairs(self.titleFireworkBursts) do
        for _, spark in ipairs(burst.sparks) do
            gfx.fillRect(spark.x, spark.y, spark.size, spark.size)
        end
    end
end

function TitleScene:drawMenu()
    gfx.setFont(self.smallFont)
    if not self.freeSpinActive and self.freeSpinStarPreview == nil then
        drawMutedTitleOverlay(TITLE_CONFIG.overlayDither or 0.5)
    end
    local selectedView = self:getSelectedView()
    gfx.setImageDrawMode(self:getTextDrawMode())
    if not self.freeSpinActive and not self.freeSpinSettling and self.freeSpinStarPreview == nil then
        gfx.drawTextAligned(self.headerTitle, 200, 20, kTextAlignment.center)
        gfx.drawTextAligned(self.headerSubtitle, 200, 40, kTextAlignment.center)
    end

    local hasModes = selectedView and selectedView.modes ~= nil
    local centerY = 146
    local spacing = 56
    local visibilityRange = 1.35

    for index, item in ipairs(self.viewItems) do
        local offset = self:getWrappedOffset(index)
        if math.abs(offset) <= visibilityRange then
            local y = centerY + (offset * spacing)
            local label = item.label

            if math.abs(offset) < 0.35 then
                if hasModes then
                    self:drawModeCarousel(selectedView, y)
                else
                    self:drawScaledText(item.label, self.largeFont or self.smallFont, "view", 200, y + 8, TITLE_CENTER_SCALE)
                end
            else
                local emphasis = math.max(0, 1 - math.min(1, math.abs(offset)))
                local scale = TITLE_SIDE_SCALE + ((TITLE_CENTER_SCALE - TITLE_SIDE_SCALE) * emphasis)
                self:drawScaledText(label, self.largeFont or self.smallFont, "view", 200, y + 8, scale)
            end
        end
    end

    self:drawAppVersion()
    self:drawBottomInstructions()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function TitleScene:shouldShowTitleFireworks()
    return false
end

function TitleScene:clearTitleFireworks()
    self.titleFireworkBursts = {}
    self.titleFireworkTimer = randomTitleFireworkDelay()
end

function TitleScene:update()
    self.frame = self.frame + 1
    local change, acceleratedChange = pd.getCrankChange()
    self:updateCrank(change, acceleratedChange)
    self:updateDisplayPosition()
    self:updateModeDisplayPosition()
    if not self.freeSpinActive and self.freeSpinStarPreview ~= nil then
        self:updateFreeSpinStarPreview(0)
    end
    if not self.freeSpinActive and self.preview ~= nil then
        if self:shouldShowTitleFireworks() then
            self:updateTitleFireworks()
        else
            self:clearTitleFireworks()
        end
        local ok, previewError = pcall(function()
            if self.previewPauseFrames <= 0 then
                self.preview:update()
            end
            self.preview:draw()
        end)
        if not ok then
            self:replacePreviewWithFallback("preview.updateDraw", previewError)
            if self.previewPauseFrames <= 0 then
                self.preview:update()
            end
            self.preview:draw()
        end
    end
    if self.freeSpinActive or self.freeSpinStarPreview ~= nil then
        self:drawFreeSpinStarPreview()
    end

    if pd.buttonJustPressed(pd.kButtonUp) then
        self:updateSelection(-1)
    elseif pd.buttonJustPressed(pd.kButtonDown) then
        self:updateSelection(1)
    elseif pd.buttonJustPressed(pd.kButtonLeft) then
        self:changeSelectedMode(-1)
    elseif pd.buttonJustPressed(pd.kButtonRight) then
        self:changeSelectedMode(1)
    elseif pd.buttonJustPressed(pd.kButtonB) then
        if self.previewLocked then
            if self:getSelectedView() and self:getSelectedView().id == "life" then
                GameOfLife.resetStandby(400, 240, 6, 0.3, self:getSelectedModeId())
                self:setPreview(true)
            else
                self:setPreview()
            end
        elseif self.onResetSelection and self.onResetSelection(self:getSelectedView()) then
            self:setPreview(true)
        elseif self.onBack then
            self.onBack()
        end
    elseif pd.buttonJustPressed(pd.kButtonA) then
        if self.freeSpinActive or self.freeSpinSettling or self.freeSpinStarPreview ~= nil then
            self:toggleFreeSpinSpeedOverlay()
            return
        end
        self.previewPauseFrames = 0
        local selectedView = self:getSelectedView()
        local selectedModeId = selectedView.modeId
        local canHandoffPreview = self:shouldHandoffPreview(selectedView)
        local effect = canHandoffPreview and self.preview or nil
        if effect and effect.setPreview then
            effect:setPreview(false)
        end
        self.handoffPreview = canHandoffPreview and effect or nil
        self.onSelectView(selectedView.openViewId or selectedView.id, effect, selectedModeId, selectedView.id)
    end

    if not self.freeSpinActive and self:shouldShowTitleFireworks() then
        self:drawTitleFireworks()
    end
    self:drawMenu()
    self:drawFreeSpinSpeedOverlay()
    if not self.freeSpinActive and not self.freeSpinSettling then
        self:processPendingPreview()
    end
end

function TitleScene:activate()
    if self.preview and self.preview.activate then
        self.preview:activate()
    end
end

function TitleScene:shutdown()
    self:shutdownFreeSpinStarPreview()
    if self.preview and self.preview ~= self.handoffPreview and self.preview.shutdown then
        self.preview:shutdown()
    end
end
