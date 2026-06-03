local pd <const> = playdate
local gfx <const> = pd.graphics

LoadingStillScene = {}
LoadingStillScene.__index = LoadingStillScene

function LoadingStillScene.new(config)
    local self = setmetatable({}, LoadingStillScene)
    self.buildScene = config.buildScene
    self.onReady = config.onReady
    self.frameCount = 0
    self.didStartLoad = false
    self.loadingImage = gfx.image.new(config.imagePath)
    return self
end

function LoadingStillScene:update()
    if self.loadingImage then
        self.loadingImage:draw(0, 0)
    end

    self.frameCount = self.frameCount + 1

    if self.didStartLoad or self.frameCount < 2 or self.buildScene == nil then
        return
    end

    self.didStartLoad = true
    local nextScene = self.buildScene()
    if nextScene and self.onReady then
        self.onReady(nextScene)
    end
end
