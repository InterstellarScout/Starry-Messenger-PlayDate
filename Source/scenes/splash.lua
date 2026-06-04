import "gameconfig"

--[[
Opening splash scene.

Purpose:
- shows the animated Starry Messenger splash before the menu flow begins
- advances after an input press
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

local SPLASH_CONFIG <const> = GameConfig and GameConfig.splash or {}

local function drawMutedTitleOverlay()
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(SPLASH_CONFIG.overlayDither or 0.5, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(0, 0, 400, 240)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
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

SplashScene = {}
SplashScene.__index = SplashScene

local function buildSplashWarpPreview()
    local preview = Starfield.newWarpSpeed(400, 240, GameConfig.warp.previewStarCount or 320)
    preview.speed = SPLASH_CONFIG.warpPreviewSpeed or 1
    for _, star in ipairs(preview.stars) do
        star.size = star.size * 2
        if star.baseSize ~= nil then
            star.baseSize = star.size
        end
        if star.px ~= nil and star.py ~= nil then
            star.px = star.x
            star.py = star.y
        end
        if preview.updateWarpStarScreenCache then
            preview:updateWarpStarScreenCache(star)
        end
    end
    return preview
end

function SplashScene.new(config)
    local self = setmetatable({}, SplashScene)
    StarryLog.info("SplashScene.new start")
    self.onContinue = config.onContinue
    self.preview = buildSplashWarpPreview()
    self.titleFont = gfx.font.new("/System/Fonts/Roobert-24-Medium")
    self.smallFont = gfx.getSystemFont()
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
    self.preview:update()
    self.preview:draw()

    drawMutedTitleOverlay()

    gfx.setFont(self.titleFont or self.smallFont)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawTextAligned("Starry Messenger", 200, 105, kTextAlignment.center)
    gfx.setFont(self.smallFont)
    gfx.drawTextAligned("Interact to show consiousness", 200, 198, kTextAlignment.center)
    gfx.drawTextAligned("and flow beyond.", 200, 214, kTextAlignment.center)
    local versionLabel = getAppVersionLabel()
    if versionLabel ~= nil then
        gfx.drawTextAligned(versionLabel, 392, 224, kTextAlignment.right)
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)

    local buttonPressed = pd.buttonJustPressed(pd.kButtonA)
        or pd.buttonJustPressed(pd.kButtonB)
        or pd.buttonJustPressed(pd.kButtonUp)
        or pd.buttonJustPressed(pd.kButtonDown)
        or pd.buttonJustPressed(pd.kButtonLeft)
        or pd.buttonJustPressed(pd.kButtonRight)
    if buttonPressed then
        self:continue()
        return
    end
end
