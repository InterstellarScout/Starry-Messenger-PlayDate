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
    self.blackHoldFrames = math.max(1, config.blackHoldFrames or 8)
    self.blackReleaseFrames = math.max(1, config.blackReleaseFrames or config.settleFrames or 8)
    self.outgoingImage = config.outgoingImage
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
    local fullBlackFrame = pullStartFrame + self.blackPullFrames
    local releaseStartFrame = fullBlackFrame + self.blackHoldFrames
    local finishFrame = releaseStartFrame + self.blackReleaseFrames
    if self.frame > fullBlackFrame then
        -- Once the black field begins to leave, ease the star stream back down
        -- behind it instead of cutting its movement on the destination frame.
        local settle = math.min(1, (self.frame - fullBlackFrame) / (self.blackHoldFrames + self.blackReleaseFrames))
        self.preview.smoothTargetSpeed = self.targetSpeed + ((self.startSpeed - self.targetSpeed) * settle)
    end

    -- Keep the outgoing title visibly alive beneath the stars until the
    -- curtain is fully black. Smooth Sailing normally clears to black, so draw
    -- only its stars here instead of calling its opaque draw method.
    if self.frame < fullBlackFrame and self.outgoingImage ~= nil then
        self.outgoingImage:draw(0, 0)
    end
    self.preview:update()
    if self.frame < releaseStartFrame then
        gfx.setColor(gfx.kColorWhite)
        self.preview:drawSmoothSailing()
    end

    if self.frame >= fullBlackFrame then
        if not self.flashSceneBuilt and self.onFlashBuildScene then
            self.flashSceneBuilt = true
            self.flashScene = self.onFlashBuildScene()
        end
        if self.flashScene and self.flashScene.update then
            self.flashScene:update()
        end
        -- The incoming title runs at full star speed behind opaque black and
        -- is only drawn as the curtain opens near the end.
        if self.frame >= releaseStartFrame and self.flashScene and self.flashScene.draw then
            self.flashScene:draw()
        end
    end

    if self.frame > pullStartFrame then
        local blackProgress
        if self.frame <= fullBlackFrame then
            blackProgress = math.min(1, (self.frame - pullStartFrame) / self.blackPullFrames)
        elseif self.frame < releaseStartFrame then
            blackProgress = 1
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
        -- setScene() shuts this transition down; detach the incoming scene so
        -- it is not shut down again while becoming the active scene.
        local nextScene = self.flashScene
        self.flashScene = nil
        callback(nextScene)
    end
end
