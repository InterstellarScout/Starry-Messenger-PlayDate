--[[
Opening splash scene.

Purpose:
- shows the animated Starry Messenger splash before the menu flow begins
- advances after a short hold or an A-button press
- performs incremental Game of Life warmup work during the splash
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

local PREWARM_BUDGET_MS <const> = 4

local function drawMutedTitleOverlay()
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(0, 0, 400, 240)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
end

SplashScene = {}
SplashScene.__index = SplashScene

function SplashScene.new(config)
    local self = setmetatable({}, SplashScene)
    StarryLog.info("SplashScene.new start")
    self.onContinue = config.onContinue
    self.preview = Starfield.newWarpSpeed(400, 240, 320)
    self.preview.speed = 1
    for _, star in ipairs(self.preview.stars) do
        star.size = star.size * 2
        if star.px ~= nil and star.py ~= nil then
            star.px = star.x
            star.py = star.y
        end
        if self.preview.updateWarpStarScreenCache then
            self.preview:updateWarpStarScreenCache(star)
        end
    end
    self.titleFont = gfx.font.new("/System/Fonts/Roobert-24-Medium")
    self.smallFont = gfx.getSystemFont()
    self.prewarmComplete = false
    GameOfLife.beginPrewarmStarryMessenger()
    StarryLog.info("SplashScene.new ready")
    return self
end

function SplashScene:activate()
    StarryLog.info("SplashScene.activate")
    if self.preview and self.preview.activate then
        self.preview:activate()
    end
end

function SplashScene:shutdown()
    if self.preview and self.preview.shutdown then
        self.preview:shutdown()
    end
end

function SplashScene:continue()
    StarryLog.info("SplashScene.continue")
    if self.onContinue then
        self.onContinue()
    end
end

function SplashScene:update()
    if self.prewarmComplete then
        self.preview:update()
    end
    self.preview:draw()
    local prewarmFinished = GameOfLife.updatePrewarm(PREWARM_BUDGET_MS)
    if prewarmFinished and not self.prewarmComplete then
        self.prewarmComplete = true
    end

    drawMutedTitleOverlay()

    gfx.setFont(self.titleFont or self.smallFont)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawTextAligned("Starry Messenger", 200, 105, kTextAlignment.center)
    gfx.setFont(self.smallFont)
    if self.prewarmComplete then
        gfx.drawTextAligned("Interact to show consiousness", 200, 198, kTextAlignment.center)
        gfx.drawTextAligned("and flow beyond.", 200, 214, kTextAlignment.center)
    else
        gfx.drawTextAligned("Loading Game of Life...", 200, 204, kTextAlignment.center)
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)

    local buttonPressed = pd.buttonJustPressed(pd.kButtonA)
        or pd.buttonJustPressed(pd.kButtonB)
        or pd.buttonJustPressed(pd.kButtonUp)
        or pd.buttonJustPressed(pd.kButtonDown)
        or pd.buttonJustPressed(pd.kButtonLeft)
        or pd.buttonJustPressed(pd.kButtonRight)
    if self.prewarmComplete and buttonPressed then
        self:continue()
        return
    end

    if not self.prewarmComplete then
        return
    end
end
