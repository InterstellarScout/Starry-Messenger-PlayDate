--[[
Player-count selection scene.

Purpose:
- lets the player choose between one, two, three, or four beings
- reuses the title-style carousel presentation on top of a warp preview
- routes the app into the single-player or multiplayer catalog flow
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

local TITLE_BAND_TOP <const> = 96
local TITLE_BAND_HEIGHT <const> = 52
local TITLE_TEXT_MAX_WIDTH <const> = 360
local TITLE_TEXT_MAX_HEIGHT <const> = 34
local TITLE_CENTER_SCALE <const> = 1.5
local TITLE_SIDE_SCALE <const> = 0.75
local PREVIEW_DEFAULT_SPEED <const> = 1
local PREVIEW_SINGLE_SPEED <const> = -1

local function drawVisibilityBand(topY, height)
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(0, topY, 400, height)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
end

PlayerCountScene = {}
PlayerCountScene.__index = PlayerCountScene

function PlayerCountScene.new(config)
    local self = setmetatable({}, PlayerCountScene)
    self.onSelectCount = config.onSelectCount
    self.onBack = config.onBack
    self.preview = Starfield.newWarpSpeed(400, 240, 320)
    self.items = {
        {
            count = 1,
            label = "One Consciousness",
            help = "Single-player journey. Games with rivals use one NPC opponent."
        },
        {
            count = 2,
            label = "Two Beings",
            help = "Multiplayer catalog with exactly two active beings."
        },
        {
            count = 3,
            label = "Three Beings",
            help = "Multiplayer catalog with exactly three active beings."
        },
        {
            count = 4,
            label = "Four Beings",
            help = "Multiplayer catalog with exactly four active beings."
        }
    }
    self.selected = 1
    self.displayPosition = 1
    self.crankAccumulator = 0
    self.largeFont = gfx.font.new("/System/Fonts/Roobert-20-Medium")
    self.smallFont = gfx.getSystemFont()
    self.textImageCache = {}
    self:updatePreviewSpeed()
    return self
end

function PlayerCountScene:activate()
    if self.preview and self.preview.activate then
        self.preview:activate()
    end
end

function PlayerCountScene:shutdown()
    if self.preview and self.preview.shutdown then
        self.preview:shutdown()
    end
end

function PlayerCountScene:getScaledTextImage(text, font)
    local cacheKey = tostring(text)
    local cached = self.textImageCache[cacheKey]
    if cached ~= nil then
        return cached
    end

    gfx.setFont(font)
    local width, height = gfx.getTextSize(text)
    width = math.max(1, math.ceil(width))
    height = math.max(1, math.ceil(height))
    local image = gfx.image.new(width, height)
    gfx.pushContext(image)
        gfx.clear(gfx.kColorBlack)
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

function PlayerCountScene:drawScaledText(text, centerX, centerY, scale)
    local cached = self:getScaledTextImage(text, self.largeFont or self.smallFont)
    local constrainedScale = scale
    constrainedScale = math.min(constrainedScale, TITLE_TEXT_MAX_WIDTH / cached.width)
    constrainedScale = math.min(constrainedScale, TITLE_TEXT_MAX_HEIGHT / cached.height)
    local drawX = centerX - ((cached.width * constrainedScale) * 0.5)
    local drawY = centerY - ((cached.height * constrainedScale) * 0.5)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    cached.image:drawScaled(drawX, drawY, constrainedScale)
end

function PlayerCountScene:getWrappedOffset(index)
    local count = #self.items
    local offset = index - self.displayPosition

    if offset > (count / 2) then
        offset = offset - count
    elseif offset < -(count / 2) then
        offset = offset + count
    end

    return offset
end

function PlayerCountScene:updateSelection(delta)
    self.selected = self.selected + delta
    if self.selected < 1 then
        self.selected = #self.items
    elseif self.selected > #self.items then
        self.selected = 1
    end
    self:updatePreviewSpeed()
end

function PlayerCountScene:updatePreviewSpeed()
    if self.preview == nil then
        return
    end

    if self.selected == 1 then
        self.preview.speed = PREVIEW_SINGLE_SPEED
    else
        self.preview.speed = PREVIEW_DEFAULT_SPEED
    end
end

function PlayerCountScene:updateDisplayPosition()
    local count = #self.items
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

function PlayerCountScene:updateCrank(acceleratedChange)
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

function PlayerCountScene:drawInstructions()
    local selectedItem = self.items[self.selected]
    local topY = 194
    drawVisibilityBand(topY, 46)
    gfx.setFont(self.smallFont)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawTextInRect("Crank or Up/Down browse. A choose. B back.", 16, topY + 7, 368, 14, nil, nil, kTextAlignment.center)
    gfx.drawTextInRect(selectedItem.help, 16, topY + 22, 368, 14, nil, nil, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function PlayerCountScene:drawMenu()
    gfx.setColor(gfx.kColorWhite)
    gfx.setFont(self.smallFont)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawTextAligned("STARRY MESSENGER", 200, 20, kTextAlignment.center)
    gfx.drawTextAligned("Choose how many beings awaken", 200, 40, kTextAlignment.center)

    local centerY = 122
    local spacing = 56
    local visibilityRange = 1.35

    drawVisibilityBand(TITLE_BAND_TOP, TITLE_BAND_HEIGHT)

    for index, item in ipairs(self.items) do
        local offset = self:getWrappedOffset(index)
        if math.abs(offset) <= visibilityRange then
            local y = centerY + (offset * spacing)
            local emphasis = math.max(0, 1 - math.min(1, math.abs(offset)))
            local scale = TITLE_SIDE_SCALE + ((TITLE_CENTER_SCALE - TITLE_SIDE_SCALE) * emphasis)
            self:drawScaledText(item.label, 200, y + 8, scale)
        end
    end

    self:drawInstructions()
end

function PlayerCountScene:update()
    local _, acceleratedChange = pd.getCrankChange()
    self:updateCrank(acceleratedChange)
    self:updateDisplayPosition()
    self:updatePreviewSpeed()
    self.preview:update()
    self.preview:draw()

    if pd.buttonJustPressed(pd.kButtonUp) then
        self:updateSelection(-1)
    elseif pd.buttonJustPressed(pd.kButtonDown) then
        self:updateSelection(1)
    elseif pd.buttonJustPressed(pd.kButtonB) then
        if self.onBack then
            self.onBack()
            return
        end
    elseif pd.buttonJustPressed(pd.kButtonA) then
        if self.onSelectCount then
            self.onSelectCount(self.items[self.selected].count)
            return
        end
    end

    self:drawMenu()
end
