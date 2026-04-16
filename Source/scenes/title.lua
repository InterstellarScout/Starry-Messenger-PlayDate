--[[
Title carousel scene.

Purpose:
- displays the current game catalog over a live animated preview
- handles view selection, per-view mode rotation, and preview handoff
- draws the shared title banners and bottom instruction band
]]
local pd <const> = playdate
local gfx <const> = pd.graphics
local TITLE_BAND_TOP <const> = 127
local TITLE_BAND_HEIGHT <const> = 52
local TITLE_TEXT_MAX_WIDTH <const> = 360
local TITLE_TEXT_MAX_HEIGHT <const> = 34
local TITLE_CENTER_SCALE <const> = 1.5
local TITLE_SIDE_SCALE <const> = 0.75
local PREVIEW_RESUME_DELAY_FRAMES <const> = 15

local function roundNearest(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function drawVisibilityBand(topY, height, color, ditherAmount)
    gfx.setColor(color or gfx.kColorBlack)
    gfx.setDitherPattern(ditherAmount or 0.5, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(0, topY, 400, height)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
end

TitleScene = {}
TitleScene.__index = TitleScene

function TitleScene.new(config)
    local self = setmetatable({}, TitleScene)
    self.viewItems = config.viewItems
    self.onSelectView = config.onSelectView
    self.onBack = config.onBack
    self.catalog = config.catalog or "single"
    self.playerCount = config.playerCount or 1
    self.selected = config.selectedIndex or 1
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
    if not self.preview then
        self:setPreview()
    end
    self:syncModeDisplayPosition(true)
    return self
end

function TitleScene:getSelectedView()
    return self.viewItems[self.selected]
end

function TitleScene:getSelectedModeId()
    local selectedView = self:getSelectedView()
    return selectedView and selectedView.modeId or nil
end

function TitleScene:usesDarkTextForView(view)
    if view == nil then
        return false
    end

    if view.id == "duck" or view.id == "antfarm" then
        return true
    end

    if (view.id == "warp" or view.id == "fall") and view.modeId == Starfield.MODE_INVERSE then
        return true
    end

    if view.id == "lava" and view.modeId == LavaLamp.MODE_INVERSE then
        return true
    end

    return false
end

function TitleScene:usesDarkText()
    return self:usesDarkTextForView(self:getSelectedView())
end

function TitleScene:usesInvertedTextForView(view)
    return false
end

function TitleScene:usesInvertedText()
    return self:usesInvertedTextForView(self:getSelectedView())
end

function TitleScene:usesLightVisibilityBand(view)
    return view ~= nil and view.id == "antfarm"
end

function TitleScene:getTextColorForView(view)
    if self:usesDarkTextForView(view) then
        return gfx.kColorBlack
    end
    return gfx.kColorWhite
end

function TitleScene:getTextColor()
    return self:getTextColorForView(self:getSelectedView())
end

function TitleScene:getTextDrawModeForView(view)
    if self:usesInvertedTextForView(view) then
        return gfx.kDrawModeInverted
    end
    if self:usesDarkTextForView(view) then
        return gfx.kDrawModeFillBlack
    end
    return gfx.kDrawModeFillWhite
end

function TitleScene:getTextDrawMode()
    return self:getTextDrawModeForView(self:getSelectedView())
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

function TitleScene:drawScaledText(text, font, keyPrefix, centerX, centerY, scale, view)
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
    gfx.setImageDrawMode(self:getTextDrawModeForView(view or self:getSelectedView()))
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
    return Starfield.newWarpSpeed(400, 240, 320)
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

    if selectedView.id == "duck" or selectedView.id == "orbital" or selectedView.id == "rccar_multi" then
        return false
    end

    if selectedView.id == "life" and selectedView.modeId == GameOfLife.MODE_REVIEW then
        return false
    end

    return true
end

function TitleScene:setPreview(forceFresh)
    local selectedView = self:getSelectedView()
    if selectedView and selectedView.id == "life" then
        self.pendingPreviewRequest = {
            modeId = selectedView.modeId,
            forceFresh = forceFresh == true
        }
        self.previewLoading = true
        if self.preview == nil then
            self.preview = self:makeFallbackPreview()
            self.previewViewId = "warp"
            self.previewModeId = nil
            self:activatePreview(self.preview)
        end
        return
    end

    self.pendingPreviewRequest = nil
    self.previewLoading = false
    local previousPreview = self.preview
    if previousPreview and previousPreview.shutdown then
        previousPreview:shutdown()
    end
    self.preview = nil
    if collectgarbage then
        collectgarbage("collect")
    end
    local ok, nextPreview = pcall(function()
        if selectedView.id == "fall" then
            return Starfield.newStarFall(400, 240, 360, {
                modeId = selectedView.modeId
            })
        elseif selectedView.id == "life" then
            return GameOfLife.new(400, 240, 6, 0.3, {
                modeId = selectedView.modeId,
                preview = true,
                forceFresh = forceFresh == true
            })
        elseif selectedView.id == "fireworks" then
            return FireworksShow.new(400, 240, {
                preview = true
            })
        elseif selectedView.id == "gifplayer" then
            return GifPlayerEffect.new(400, 240, {
                modeId = selectedView.modeId,
                preview = true
            })
        elseif selectedView.id == "antfarm" then
            return AntFarm.new(400, 240, {
                preview = true
            })
        elseif selectedView.id == "fishpond" then
            return FishPond.new(400, 240, selectedView.modeId, {
                preview = true
            })
        elseif selectedView.id == "duck" then
            return DuckGameScene.new({
                preview = true,
                multiplayer = self:isMultiplayerCatalog(),
                playerCount = self.playerCount,
                modeId = selectedView.modeId
            })
        elseif selectedView.id == "orbital" then
            return OrbitalDefenseScene.new({
                preview = true,
                multiplayer = self:isMultiplayerCatalog(),
                playerCount = self.playerCount
            })
        elseif selectedView.id == "rccar" or selectedView.id == "rccar_multi" then
            return RCCarArena.new(400, 240, selectedView.modeId, {
                preview = true
            })
        elseif selectedView.id == "lava" then
            return LavaLamp.new(400, 240, 36, {
                modeId = selectedView.modeId
            })
        end

        return Starfield.newWarpSpeed(400, 240, 320, {
            modeId = selectedView.modeId
        })
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

    self.pendingPreviewRequest = nil
    self.previewLoading = false

    local previousPreview = self.preview
    if previousPreview and previousPreview.shutdown then
        previousPreview:shutdown()
    end
    self.preview = nil
    if collectgarbage then
        collectgarbage("collect")
    end

    local ok, nextPreview = pcall(function()
        return GameOfLife.new(400, 240, 6, 0.3, {
            modeId = request.modeId,
            preview = true,
            forceFresh = request.forceFresh
        })
    end)

    if not ok then
        self:replacePreviewWithFallback("processPendingPreview:life", nextPreview)
        return
    end

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

function TitleScene:updateCrank(acceleratedChange)
    if math.abs(acceleratedChange or 0) > 0.01 then
        self.previewPauseFrames = PREVIEW_RESUME_DELAY_FRAMES
    elseif self.previewPauseFrames > 0 then
        self.previewPauseFrames = self.previewPauseFrames - 1
    end

    self.crankAccumulator = self.crankAccumulator + acceleratedChange

    while self.crankAccumulator >= 14 do
        self:updateSelection(1)
        self.crankAccumulator = self.crankAccumulator - 14
    end

    while self.crankAccumulator <= -14 do
        self:updateSelection(-1)
        self.crankAccumulator = self.crankAccumulator + 14
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
    local spec = selectedView and ControlHelp.getEntrySpec(selectedView.id, selectedView.modeId) or nil
    local topY = 206

    gfx.setFont(self.smallFont)
    gfx.setImageDrawMode(self:getTextDrawModeForView(selectedView))
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

function TitleScene:drawMenu()
    local selectedView = self:getSelectedView()
    gfx.setFont(self.smallFont)
    gfx.setImageDrawMode(self:getTextDrawModeForView(selectedView))
    gfx.drawTextAligned(self.headerTitle, 200, 20, kTextAlignment.center)
    gfx.drawTextAligned(self.headerSubtitle, 200, 40, kTextAlignment.center)

    local hasModes = selectedView and selectedView.modes ~= nil
    local centerY = TITLE_BAND_TOP + math.floor(TITLE_BAND_HEIGHT * 0.5) - 1
    local spacing = 56
    local visibilityRange = 1.35

    if self:usesLightVisibilityBand(selectedView) then
        drawVisibilityBand(TITLE_BAND_TOP, TITLE_BAND_HEIGHT, gfx.kColorWhite, 0.15)
    else
        drawVisibilityBand(TITLE_BAND_TOP, TITLE_BAND_HEIGHT, gfx.kColorBlack, 0.5)
    end

    for index, item in ipairs(self.viewItems) do
        local offset = self:getWrappedOffset(index)
        if math.abs(offset) <= visibilityRange then
            local y = centerY + (offset * spacing)
            local label = item.label

            if math.abs(offset) < 0.35 then
                local centerScale = hasModes and 1.18 or TITLE_CENTER_SCALE
                self:drawScaledText(item.label, self.largeFont or self.smallFont, "view", 200, y + (hasModes and 1 or 8), centerScale, item)
            else
                local emphasis = math.max(0, 1 - math.min(1, math.abs(offset)))
                local scale = TITLE_SIDE_SCALE + ((TITLE_CENTER_SCALE - TITLE_SIDE_SCALE) * emphasis)
                self:drawScaledText(label, self.largeFont or self.smallFont, "view", 200, y + 8, scale, item)
            end
        end
    end

    if hasModes then
        local modeLabel = self:getSelectedModeLabel()
        if modeLabel ~= nil then
            gfx.setFont(self.smallFont)
            gfx.setImageDrawMode(self:getTextDrawModeForView(selectedView))
            gfx.drawTextAligned(modeLabel, 200, centerY + 16, kTextAlignment.center)
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
        end
    end

    self:drawBottomInstructions()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function TitleScene:update()
    local _, acceleratedChange = pd.getCrankChange()
    self:updateCrank(acceleratedChange)
    self:updateDisplayPosition()
    self:updateModeDisplayPosition()
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
        elseif self.onBack then
            self.onBack()
        end
    elseif pd.buttonJustPressed(pd.kButtonA) then
        self.previewPauseFrames = 0
        local selectedView = self:getSelectedView()
        local selectedModeId = selectedView.modeId
        local effect = self.preview
        if effect and effect.setPreview then
            effect:setPreview(false)
        end
        self.handoffPreview = self:shouldHandoffPreview(selectedView) and effect or nil
        self.onSelectView(selectedView.id, effect, selectedModeId)
    end

    self:drawMenu()
    self:processPendingPreview()
end

function TitleScene:activate()
    if self.preview and self.preview.activate then
        self.preview:activate()
    end
end

function TitleScene:shutdown()
    if self.preview and self.preview ~= self.handoffPreview and self.preview.shutdown then
        self.preview:shutdown()
    end
end
