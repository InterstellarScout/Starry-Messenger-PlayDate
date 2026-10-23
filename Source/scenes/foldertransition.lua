import "gameconfig"

local pd <const> = playdate
local gfx <const> = pd.graphics
FolderTransitionScene = {}
FolderTransitionScene.__index = FolderTransitionScene

local function makeTransitionPreview(startSpeed)
    local preview = VibesEffect.new(400, 240, {
        modeId = "smoothsailing",
        selectionLocked = true,
        preview = true
    })
    preview.smoothSpeed = startSpeed or 1
    preview.smoothTargetSpeed = preview.smoothSpeed
    return preview
end

function FolderTransitionScene.new(config)
    local self = setmetatable({}, FolderTransitionScene)
    config = config or {}
    self.preview = makeTransitionPreview(config.startSpeed or 1)
    self.startSpeed = config.startSpeed or 1
    self.targetSpeed = config.targetSpeed or 100
    self.accelerationFrames = math.max(1, config.accelerationFrames or 30)
    -- At 30 fps, each eight-frame black curtain stage lasts about .25 seconds.
    self.blackPullFrames = math.max(1, config.blackPullFrames or config.flashFrames or 8)
    self.blackReleaseFrames = math.max(1, config.blackReleaseFrames or config.settleFrames or 8)
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
        -- Smooth Sailing owns its own easing curve; feed it a target rather
        -- than forcing a Warp-style speed step each frame.
        self.preview.smoothTargetSpeed = self.startSpeed + ((self.targetSpeed - self.startSpeed) * progress)
    end

    local pullStartFrame = self.accelerationFrames
    local releaseStartFrame = pullStartFrame + self.blackPullFrames
    local finishFrame = releaseStartFrame + self.blackReleaseFrames
    if self.frame > releaseStartFrame then
        -- Once the black field begins to leave, ease the star stream back down
        -- behind it instead of cutting its movement on the destination frame.
        local settle = math.min(1, (self.frame - releaseStartFrame) / self.blackReleaseFrames)
        self.preview.smoothTargetSpeed = self.targetSpeed + ((self.startSpeed - self.targetSpeed) * settle)
    end

    -- The stars are drawn from frame one; the curtain only arrives after the
    -- viewer has seen the launch movement.
    self.preview:update()
    self.preview:draw()

    if self.frame > pullStartFrame then
        if not self.flashSceneBuilt and self.onFlashBuildScene then
            self.flashSceneBuilt = true
            self.flashScene = self.onFlashBuildScene()
        end
        if self.flashScene and self.flashScene.update then
            self.flashScene:update()
        end
        local blackProgress
        if self.frame <= releaseStartFrame then
            blackProgress = math.min(1, (self.frame - pullStartFrame) / self.blackPullFrames)
        else
            blackProgress = math.max(0, 1 - ((self.frame - releaseStartFrame) / self.blackReleaseFrames))
        end
        gfx.setColor(gfx.kColorBlack)
        gfx.setDitherPattern(blackProgress, gfx.image.kDitherTypeBayer8x8)
        gfx.fillRect(0, 0, 400, 240)
        gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    end

    if self.frame >= finishFrame and self.onComplete then
        local callback = self.onComplete
        self.onComplete = nil
        callback(self.flashScene)
    end
end
