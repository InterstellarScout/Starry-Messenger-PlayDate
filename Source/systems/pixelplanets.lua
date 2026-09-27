import "CoreLibs/graphics"

PixelPlanetsAssets = PixelPlanetsAssets or {}

local gfx <const> = playdate.graphics
local assets = PixelPlanetsAssets

local MAX_CACHED_FRAMES_PER_SET <const> = 12

assets.frameCaches = assets.frameCaches or {}

local function loadFrame(prefix, frameCount, frame)
    local index = math.floor(frame or 0) % frameCount
    local cache = assets.frameCaches[prefix]
    if cache == nil then
        cache = { frames = {}, order = {} }
        assets.frameCaches[prefix] = cache
    end

    local image = cache.frames[index]
    if image ~= nil then
        return image
    end

    -- Loading all 652 exported PNGs in a draw call stalls the hardware long
    -- enough for the watchdog to reset. Decode only the requested frame and
    -- retain a short rolling cache for nearby animation frames.
    local path = string.format("images/pixelplanets/%s_%02d", prefix, index)
    image = gfx.image.new(path)
    if image == nil then
        return nil
    end
    cache.frames[index] = image
    cache.order[#cache.order + 1] = index
    if #cache.order > MAX_CACHED_FRAMES_PER_SET then
        local evictedIndex = table.remove(cache.order, 1)
        cache.frames[evictedIndex] = nil
    end
    return image
end

-- Compatibility entry point retained for callers from earlier builds. Assets
-- now load lazily, so this deliberately performs no bulk disk work.
function assets.load()
    assets.loaded = true
end

function assets.asteroidFrame(size, frame)
    local prefix = "asteroid_" .. tostring(size or "small")
    return loadFrame(prefix, 160, frame)
end

function assets.blackHoleFrame(frame)
    return loadFrame("black_hole", 12, frame)
end

function assets.earthFrame(frame)
    return loadFrame("earth", 160, frame)
end
