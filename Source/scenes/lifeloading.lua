local pd <const> = playdate
local gfx <const> = pd.graphics
local LIFE_CONFIG <const> = GameConfig and GameConfig.life or {}

LifeLoadingScene = {}
LifeLoadingScene.__index = LifeLoadingScene

function LifeLoadingScene.new(config)
    local self = setmetatable({}, LifeLoadingScene)
    self.modeId = config.modeId or GameOfLife.MODE_STANDARD
    self.onReady = config.onReady
    self.onReturnToTitle = config.onReturnToTitle
    self.session = config.session
    self.frameCount = 0
    self.finished = false
    self.loadingImage = gfx.image.new(config.imagePath)
    self.titleFont = gfx.font.new("/System/Fonts/Roobert-20-Medium")
    self.smallFont = gfx.getSystemFont()
    self.liveCellSize = LIFE_CONFIG.liveCellSize or 5
    self.liveSeedChance = LIFE_CONFIG.liveSeedChance or 0.28
    self.frameTarget = LIFE_CONFIG.warmFrameCount or 50
    return self
end

function LifeLoadingScene:activate()
    if self.modeId ~= GameOfLife.MODE_REVIEW then
        GameOfLife.beginPrewarmForConfig(400, 240, self.liveCellSize, self.liveSeedChance, self.frameTarget)
    end
end

function LifeLoadingScene:shutdown()
end

function LifeLoadingScene:finish(allowPartial)
    if self.finished then
        return
    end

    self.finished = true
    local initialCache = nil
    if self.modeId ~= GameOfLife.MODE_REVIEW then
        initialCache = GameOfLife.getWarmCache(400, 240, self.liveCellSize, self.liveSeedChance, allowPartial == true)
        GameOfLife.cancelPrewarm()
    end

    local effect = GameOfLife.new(400, 240, self.liveCellSize, self.liveSeedChance, {
        modeId = self.modeId,
        initialCache = initialCache,
        startAtFirstFrame = true,
        forceFresh = true
    })

    if self.onReady then
        self.onReady(ViewScene.new({
            viewId = "life",
            modeId = self.modeId,
            effect = effect,
            session = self.session,
            onReturnToTitle = self.onReturnToTitle
        }))
    end
end

function LifeLoadingScene:drawOverlay()
    local status = GameOfLife.getPrewarmStatus()
    local percent = math.floor(((status.progress or 0) * 100) + 0.5)

    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.55, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRoundRect(22, 154, 356, 64, 8)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.setFont(self.titleFont or self.smallFont)
    gfx.drawTextAligned("Loading Game of Life", 200, 166, kTextAlignment.center)
    gfx.setFont(self.smallFont)
    gfx.drawTextAligned(string.format("%d%% ready. Press A to jump in now.", percent), 200, 190, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function LifeLoadingScene:update()
    if self.loadingImage then
        self.loadingImage:draw(0, 0)
    end

    self.frameCount = self.frameCount + 1

    if self.modeId == GameOfLife.MODE_REVIEW then
        if self.frameCount >= 2 then
            self:finish(false)
        end
        return
    end

    self:drawOverlay()

    if pd.buttonJustPressed(pd.kButtonA) then
        self:finish(true)
        return
    end

    GameOfLife.updatePrewarm(4)
    if GameOfLife.isPrewarmComplete() then
        self:finish(true)
    end
end
