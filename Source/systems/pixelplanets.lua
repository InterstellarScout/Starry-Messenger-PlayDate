import "CoreLibs/graphics"

PixelPlanetsAssets = PixelPlanetsAssets or {}

local gfx <const> = playdate.graphics
local assets = PixelPlanetsAssets

local function loadFrames(prefix, frameCount)
    local frames = {}
    for frame = 0, frameCount - 1 do
        local path = string.format("images/pixelplanets/%s_%02d", prefix, frame)
        frames[#frames + 1] = gfx.image.new(path)
    end
    return frames
end

function assets.load()
    if assets.loaded then
        return
    end
    assets.asteroids = {
        small = loadFrames("asteroid_small", 8),
        medium = loadFrames("asteroid_medium", 8),
        large = loadFrames("asteroid_large", 8)
    }
    assets.blackHole = loadFrames("black_hole", 12)
    assets.loaded = true
end

function assets.asteroidFrame(size, frame)
    assets.load()
    local frames = assets.asteroids[size]
    if frames == nil or #frames == 0 then
        return nil
    end
    return frames[(math.floor(frame or 0) % #frames) + 1]
end

function assets.blackHoleFrame(frame)
    assets.load()
    if assets.blackHole == nil or #assets.blackHole == 0 then
        return nil
    end
    return assets.blackHole[(math.floor(frame or 0) % #assets.blackHole) + 1]
end
