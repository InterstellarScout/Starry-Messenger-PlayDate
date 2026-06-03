import "gameconfig"

local pd <const> = playdate
local gfx <const> = pd.graphics
local WARP_CONFIG <const> = GameConfig and GameConfig.warp or {}

FolderTransitionScene = {}
FolderTransitionScene.__index = FolderTransitionScene

local function makeTransitionPreview(startSpeed)
    local preview = Starfield.newWarpSpeed(400, 240, WARP_CONFIG.previewStarCount or 320, {
        modeId = Starfield.MODE_STANDARD
    })
    preview.speed = startSpeed or 1
    return preview
end

function FolderTransitionScene.new(config)
    local self = setmetatable({}, FolderTransitionScene)
    config = config or {}
    self.preview = makeTransitionPreview(config.startSpeed or 1)
    self.startSpeed = config.startSpeed or 1
    self.targetSpeed = config.targetSpeed or 100
    self.accelerationFrames = math.max(1, config.accelerationFrames or 30)
    self.flashFrames = math.max(1, config.flashFrames or 15)
    self.flashColor = config.flashColor or gfx.kColorWhite
    self.onFlashBuildScene = config.onFlashBuildScene
    self.onComplete = config.onComplete
    self.frame = 0
    self.flashScene = nil
    self.flashSceneBuilt = false
    return self
end

function FolderTransitionScene:activate()
    if self.preview and self.preview.activate then
        self.preview:activate()
    end
end

function FolderTransitionScene:shutdown()
    if self.flashScene and self.flashScene.shutdown then
        self.flashScene:shutdown()
    end
    if self.preview and self.preview.shutdown then
        self.preview:shutdown()
    end
end

function FolderTransitionScene:update()
    self.frame = self.frame + 1

    if self.frame <= self.accelerationFrames then
        local progress = self.frame / self.accelerationFrames
        self.preview.speed = self.startSpeed + ((self.targetSpeed - self.startSpeed) * progress)
    end

    self.preview:update()
    self.preview:draw()

    if self.frame > self.accelerationFrames then
        if not self.flashSceneBuilt and self.onFlashBuildScene then
            self.flashSceneBuilt = true
            self.flashScene = self.onFlashBuildScene()
        end
        if self.flashScene and self.flashScene.update then
            self.flashScene:update()
        end
        local flashProgress = math.min(1, (self.frame - self.accelerationFrames) / self.flashFrames)
        gfx.setColor(self.flashColor)
        gfx.setDitherPattern(flashProgress, gfx.image.kDitherTypeBayer8x8)
        gfx.fillRect(0, 0, 400, 240)
        gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    end

    if self.frame >= (self.accelerationFrames + self.flashFrames) and self.onComplete then
        local callback = self.onComplete
        self.onComplete = nil
        callback(self.flashScene)
    end
end
