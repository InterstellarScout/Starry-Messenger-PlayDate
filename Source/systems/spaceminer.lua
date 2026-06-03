import "gameconfig"
import "data/spaceminerwaves"

import "CoreLibs/graphics"

local pd <const> = playdate
local gfx <const> = pd.graphics
local SPACE_MINER_CONFIG <const> = GameConfig and GameConfig.spaceMiner or {}

SpaceMiner = {}
SpaceMiner.__index = SpaceMiner

SpaceMiner.MODE_FULL = "full"
SpaceMiner.MODE_HALF = "half"
SpaceMiner.MODE_QUARTER = "quarter"
SpaceMiner.compactTurnEnabled = false

local SCREEN_WIDTH <const> = 400
local SCREEN_HEIGHT <const> = 240
local CENTER_X <const> = SCREEN_WIDTH * 0.5
local CENTER_Y <const> = SCREEN_HEIGHT * 0.5
local WORLD_WRAP_RADIUS <const> = SPACE_MINER_CONFIG.worldWrapRadius or 620
local ASTEROID_SAFE_RADIUS <const> = SPACE_MINER_CONFIG.asteroidSafeRadius or 140
local PLAYER_RADIUS <const> = SPACE_MINER_CONFIG.playerRadius or 8
local DECOR_WRAP_RADIUS <const> = SPACE_MINER_CONFIG.decorWrapRadius or 720
local PLAYER_THRUST <const> = SPACE_MINER_CONFIG.playerThrust or 0.08
local PLAYER_REVERSE_THRUST <const> = SPACE_MINER_CONFIG.playerReverseThrust or 0.05
local PLAYER_FULL_MODE_IDLE_DRAG <const> = SPACE_MINER_CONFIG.playerFullModeIdleDrag or 0.982
local PLAYER_FULL_MODE_AUTO_STOP_SPEED <const> = SPACE_MINER_CONFIG.playerFullModeAutoStopSpeed or 0.18
local ENEMY_BASE_ACCELERATION <const> = SPACE_MINER_CONFIG.enemyBaseAcceleration or 0.045
local ENEMY_ESCAPER_ACCELERATION <const> = SPACE_MINER_CONFIG.enemyEscaperAcceleration or 0.055
local ENEMY_STRIKER_ACCELERATION <const> = SPACE_MINER_CONFIG.enemyStrikerAcceleration or 0.072
local PLAYER_MAX_SPEED <const> = SPACE_MINER_CONFIG.playerMaxSpeed or 3.8
local ENEMY_MAX_SPEED <const> = SPACE_MINER_CONFIG.enemyMaxSpeed or 3.2
local LASER_RANGE <const> = SPACE_MINER_CONFIG.laserRange or 170
local LASER_WIDTH <const> = 4
local LASER_DAMAGE <const> = SPACE_MINER_CONFIG.laserDamage or 0.34
local MISSILE_SPEED <const> = SPACE_MINER_CONFIG.missileSpeed or 4.4
local MISSILE_DAMAGE <const> = SPACE_MINER_CONFIG.missileDamage or 99
local MISSILE_BLAST_RADIUS <const> = SPACE_MINER_CONFIG.missileBlastRadius or 34
local MISSILE_LIFE_FRAMES <const> = SPACE_MINER_CONFIG.missileLifeFrames or 110
local PLAYER_MISSILE_DRAW_RADIUS <const> = SPACE_MINER_CONFIG.playerMissileDrawRadius or 5
local PLAYER_MISSILE_DRAW_LENGTH <const> = SPACE_MINER_CONFIG.playerMissileDrawLength or 10
local MAX_ACTIVE_ENTITIES <const> = SPACE_MINER_CONFIG.maxActiveEntities or 54
local TARGET_ASTEROID_COUNT <const> = SPACE_MINER_CONFIG.targetAsteroidCount or 24
local PREVIEW_ASTEROID_COUNT <const> = SPACE_MINER_CONFIG.previewAsteroidCount or 16
local DECOR_ITEM_COUNT <const> = SPACE_MINER_CONFIG.decorItemCount or 120
local SHIELD_HITS <const> = SPACE_MINER_CONFIG.shieldHits or 2
local HULL_HITS <const> = SPACE_MINER_CONFIG.hullHits or 2
local SHIELD_FLASH_FRAMES <const> = SPACE_MINER_CONFIG.shieldFlashFrames or 18
local SHIELD_RECHARGE_DELAY_FRAMES <const> = SPACE_MINER_CONFIG.shieldRechargeDelayFrames or (30 * 5)
local SHIELD_RECHARGE_STEP_FRAMES <const> = SPACE_MINER_CONFIG.shieldRechargeStepFrames or 90
local ASTEROID_PRUNE_PROTECTION_FRAMES <const> = SPACE_MINER_CONFIG.asteroidPruneProtectionFrames or 45
local ASTEROID_VISIBLE_PRUNE_GRACE_FRAMES <const> = SPACE_MINER_CONFIG.asteroidVisiblePruneGraceFrames or 120
local ASTEROID_DIAGNOSTICS_ENABLED <const> = SPACE_MINER_CONFIG.asteroidDiagnosticsEnabled ~= false
local ASTEROID_DIAGNOSTIC_INTERVAL_FRAMES <const> = SPACE_MINER_CONFIG.asteroidDiagnosticIntervalFrames or 150
local ASTEROID_DIAGNOSTIC_EVENT_LIMIT <const> = SPACE_MINER_CONFIG.asteroidDiagnosticEventLimit or 6
local STRIKER_MISSILE_COOLDOWN <const> = SPACE_MINER_CONFIG.strikerMissileCooldown or 70
local ALERT_FLASH_FRAMES <const> = 15
local ALERT_FLASH_CYCLES <const> = 3
local ALERT_TOTAL_FRAMES <const> = ALERT_FLASH_FRAMES * 2 * ALERT_FLASH_CYCLES
local ALERT_GAP_FRAMES <const> = SPACE_MINER_CONFIG.alertGapFrames or 12
local DEFAULT_ALERT_TEXT <const> = "ALERT"

local ASTEROID_STAGE_CONFIG <const> = {
    [0] = { radius = 30, hp = 7, speed = 0.28, fragments = 2, score = 20 },
    [1] = { radius = 18, hp = 4, speed = 0.45, fragments = 2, score = 10 },
    [2] = { radius = 11, hp = 2, speed = 0.68, fragments = 2, score = 6 },
    [3] = { radius = 6, hp = 1, speed = 0.95, fragments = 0, score = 3 }
}

local TURN_WINDOW_DEGREES <const> = {
    [SpaceMiner.MODE_FULL] = 360,
    [SpaceMiner.MODE_HALF] = 180,
    [SpaceMiner.MODE_QUARTER] = 90
}

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function parseFrameCount(value)
    if type(value) == "number" then
        return math.max(0, math.floor(value))
    end
    if type(value) ~= "string" then
        return 0
    end

    local parts = {}
    for segment in string.gmatch(value, "[^:]+") do
        parts[#parts + 1] = tonumber(segment) or 0
    end

    if #parts == 1 then
        return math.max(0, math.floor(parts[1]))
    elseif #parts == 2 then
        return math.max(0, math.floor((parts[1] * 30) + parts[2]))
    elseif #parts == 3 then
        return math.max(0, math.floor((parts[1] * 60 * 30) + (parts[2] * 30) + parts[3]))
    elseif #parts >= 4 then
        return math.max(0, math.floor((parts[1] * 60 * 60 * 30) + (parts[2] * 60 * 30) + (parts[3] * 30) + parts[4]))
    end

    return 0
end

local function normalizeConfigDegrees(value)
    local normalized = (tonumber(value) or 0) % 360
    if normalized < 0 then
        normalized = normalized + 360
    end
    return normalized
end

local function normalizeWaveSchedule(rawConfig)
    local schedule = {}
    local rawStages = rawConfig and rawConfig.stages or nil
    if rawStages == nil then
        return schedule
    end

    for index, rawStage in ipairs(rawStages) do
        local stage = {
            id = rawStage.id or string.format("stage-%d", index),
            kind = rawStage.kind or "mining",
            label = rawStage.label or rawStage.id or string.format("Stage %d", index),
            wave = rawStage.wave,
            alertText = rawStage.alertText or DEFAULT_ALERT_TEXT
        }

        if stage.kind == "mining" then
            stage.durationFrames = parseFrameCount(rawStage.durationFrames or rawStage.duration or 0)
        else
            local rawTrigger = rawStage.trigger or {}
            stage.trigger = {
                type = rawTrigger.type or "after_stage_clear",
                timestampFrames = parseFrameCount(rawTrigger.timestampFrames or rawTrigger.timestamp or 0),
                delayFrames = parseFrameCount(rawTrigger.delayFrames or rawTrigger.delay or 0)
            }
            stage.entries = {}

            for entryIndex, rawEntry in ipairs(rawStage.entries or {}) do
                local entry = {
                    id = rawEntry.id or string.format("%s-entry-%d", stage.id, entryIndex),
                    entityType = rawEntry.entityType or rawEntry.enemyType or "seeker",
                    quantity = math.max(1, math.floor(rawEntry.quantity or rawEntry.count or 1)),
                    entryDegrees = normalizeConfigDegrees(rawEntry.entryDegrees or rawEntry.entryLocation or 0),
                    timestampFrames = rawEntry.timestamp ~= nil and parseFrameCount(rawEntry.timestamp) or rawEntry.timestampFrames,
                    offsetFrames = rawEntry.offset ~= nil and parseFrameCount(rawEntry.offset) or parseFrameCount(rawEntry.offsetFrames or 0)
                }
                stage.entries[#stage.entries + 1] = entry
            end

            table.sort(stage.entries, function(left, right)
                local leftTime = left.timestampFrames or left.offsetFrames or 0
                local rightTime = right.timestampFrames or right.offsetFrames or 0
                if leftTime == rightTime then
                    return left.id < right.id
                end
                return leftTime < rightTime
            end)

            if stage.trigger.type == "time" then
                local firstSpawnFrame = stage.trigger.timestampFrames
                for _, entry in ipairs(stage.entries) do
                    if entry.timestampFrames ~= nil then
                        firstSpawnFrame = math.min(firstSpawnFrame, entry.timestampFrames)
                    end
                end
                stage.waveStartFrame = firstSpawnFrame
                stage.alertStartFrame = math.max(0, firstSpawnFrame - ALERT_TOTAL_FRAMES - ALERT_GAP_FRAMES)
            end
        end

        schedule[#schedule + 1] = stage
    end

    return schedule
end

local STAGE_SCHEDULE <const> = normalizeWaveSchedule(SpaceMinerWaveConfig)

local function normalizeAngle(angle)
    local normalized = angle % 360
    if normalized < 0 then
        normalized = normalized + 360
    end
    return normalized
end

local function screenDegreesToRadians(degrees)
    return math.rad(normalizeAngle(degrees) - 90)
end

local function shortestAngleDelta(current, target)
    local delta = (target - current + 540) % 360 - 180
    return delta
end

local function distanceSquared(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return (dx * dx) + (dy * dy)
end

local function linePointDistanceSquared(px, py, ax, ay, bx, by)
    local abx = bx - ax
    local aby = by - ay
    local apx = px - ax
    local apy = py - ay
    local abLengthSq = (abx * abx) + (aby * aby)
    if abLengthSq <= 0.0001 then
        return distanceSquared(px, py, ax, ay)
    end

    local t = ((apx * abx) + (apy * aby)) / abLengthSq
    t = clamp(t, 0, 1)
    local cx = ax + (abx * t)
    local cy = ay + (aby * t)
    return distanceSquared(px, py, cx, cy)
end

local function wrapCoordinate(origin, subject)
    local delta = subject - origin
    if delta > WORLD_WRAP_RADIUS then
        return subject - (WORLD_WRAP_RADIUS * 2)
    elseif delta < -WORLD_WRAP_RADIUS then
        return subject + (WORLD_WRAP_RADIUS * 2)
    end
    return subject
end

local function worldToScreen(cameraX, cameraY, worldX, worldY)
    return CENTER_X + (worldX - cameraX), CENTER_Y + (worldY - cameraY)
end

local function parallaxWorldToScreen(cameraX, cameraY, worldX, worldY, parallax)
    return CENTER_X + ((worldX - cameraX) * parallax), CENTER_Y + ((worldY - cameraY) * parallax)
end

local function applyAcceleration(body, ax, ay, maxSpeed)
    body.vx = body.vx + ax
    body.vy = body.vy + ay
    local speedSq = (body.vx * body.vx) + (body.vy * body.vy)
    local maxSq = maxSpeed * maxSpeed
    if speedSq > maxSq then
        local speed = math.sqrt(speedSq)
        body.vx = (body.vx / speed) * maxSpeed
        body.vy = (body.vy / speed) * maxSpeed
    end
end

local function magnitude(x, y)
    return math.sqrt((x * x) + (y * y))
end

local function unitVector(dx, dy)
    local length = magnitude(dx, dy)
    if length <= 0.0001 then
        return 0, 0, 0
    end
    return dx / length, dy / length, length
end

function SpaceMiner.getModeLabel(modeId)
    if modeId == SpaceMiner.MODE_HALF then
        return "Turn 180"
    elseif modeId == SpaceMiner.MODE_QUARTER then
        return "Turn 90"
    end
    return "Turn 360"
end

function SpaceMiner.isCompactTurnEnabled()
    return SpaceMiner.compactTurnEnabled == true
end

function SpaceMiner.setCompactTurnEnabled(enabled)
    SpaceMiner.compactTurnEnabled = enabled == true
end

function SpaceMiner:applyTurnModeSetting()
    self.modeId = SpaceMiner.isCompactTurnEnabled() and SpaceMiner.MODE_HALF or SpaceMiner.MODE_FULL
    self.turnWindow = TURN_WINDOW_DEGREES[self.modeId] or 360
    self.turnScale = 360 / self.turnWindow
end

function SpaceMiner.new(width, height, options)
    local self = setmetatable({}, SpaceMiner)
    options = options or {}
    self.width = width
    self.height = height
    self.modeId = options.modeId or SpaceMiner.MODE_FULL
    self.preview = options.preview == true
    self.turnWindow = 360
    self.turnScale = 1
    self.player = {
        x = 0,
        y = 0,
        vx = 0,
        vy = 0,
        angle = 270,
        laserOn = false,
        missile = nil,
        pendingMissileTrigger = false
    }
    self.input = {
        thrust = 0,
        reverse = 0,
        laser = false
    }
    self.virtualCrankAngle = 0
    self.asteroids = {}
    self.enemyShips = {}
    self.enemyMissiles = {}
    self.explosions = {}
    self.score = 0
    self.minedChunks = 0
    self.frame = 0
    self.stageIndex = 1
    self.stageFrame = 0
    self.stageStatus = "active"
    self.stageLabel = (#STAGE_SCHEDULE > 0 and STAGE_SCHEDULE[1].label) or "Open Mining"
    self.stageRuntime = nil
    self.enemySerial = 0
    self.playerShieldHits = SHIELD_HITS
    self.playerHullHits = HULL_HITS
    self.shieldFlashFrames = 0
    self.framesSincePlayerDamage = SHIELD_RECHARGE_DELAY_FRAMES
    self.shieldRechargeFrames = 0
    self.gameOver = false
    self.previewDriftAngle = 0
    self.previewFrameCounter = 0
    self.decor = {}
    self.asteroidSerial = 0
    self.asteroidDiagnostics = nil
    self:resetAsteroidDiagnostics()
    self:applyTurnModeSetting()
    self:seedDecor()
    self:seedAsteroids(10)
    if #STAGE_SCHEDULE > 0 then
        self:beginStage(1)
    end
    return self
end

function SpaceMiner:setPreview(isPreview)
    self.preview = isPreview == true
end

function SpaceMiner:refreshSettings()
    self:applyTurnModeSetting()
end

function SpaceMiner:activate()
end

function SpaceMiner:shutdown()
end

function SpaceMiner:seedAsteroids(targetCount)
    while #self.asteroids < targetCount do
        self:spawnAsteroid(0, nil, nil)
    end
end

function SpaceMiner:randomDecorKind()
    local roll = math.random()
    if roll <= 0.70 then
        return "dot"
    elseif roll <= 0.85 then
        return "cross"
    else
        return "square"
    end
end

function SpaceMiner:spawnDecorItem(layer)
    local kind = self:randomDecorKind()
    local frontLayer = layer == "front"
    local item = {
        layer = layer,
        kind = kind,
        x = self.player.x + math.random(-DECOR_WRAP_RADIUS, DECOR_WRAP_RADIUS),
        y = self.player.y + math.random(-DECOR_WRAP_RADIUS, DECOR_WRAP_RADIUS),
        parallax = frontLayer and (1.45 + (math.random() * 0.5)) or (0.32 + (math.random() * 0.4))
    }

    if kind == "circle" then
        item.radius = math.random(5, 7)
    elseif kind == "cross" then
        item.radius = 1
    elseif kind == "square" then
        item.radius = 1
    else
        item.radius = 0
    end

    self.decor[#self.decor + 1] = item
end

function SpaceMiner:seedDecor()
    self.decor = {}
    for index = 1, DECOR_ITEM_COUNT do
        local layer = index <= math.floor(DECOR_ITEM_COUNT * 0.82) and "back" or "front"
        self:spawnDecorItem(layer)
    end
end

function SpaceMiner:updateDecor()
    for _, item in ipairs(self.decor) do
        item.x = wrapCoordinate(self.player.x, item.x)
        item.y = wrapCoordinate(self.player.y, item.y)

        local dx = item.x - self.player.x
        local dy = item.y - self.player.y
        if math.abs(dx) > DECOR_WRAP_RADIUS or math.abs(dy) > DECOR_WRAP_RADIUS then
            item.x = self.player.x + math.random(-DECOR_WRAP_RADIUS, DECOR_WRAP_RADIUS)
            item.y = self.player.y + math.random(-DECOR_WRAP_RADIUS, DECOR_WRAP_RADIUS)
        end
    end
end

function SpaceMiner:resetAsteroidDiagnostics()
    self.asteroidDiagnostics = {
        spawned = 0,
        fragments = 0,
        minedLaser = 0,
        minedMissile = 0,
        playerCollisions = 0,
        pressureChecks = 0,
        pressureCandidates = 0,
        pressureBlockedAge = 0,
        pressureBlockedGrace = 0,
        pressurePruned = 0,
        visibilityEntries = 0,
        visibilityExits = 0,
        wrapsX = 0,
        wrapsY = 0,
        eventLines = 0
    }
end

function SpaceMiner:logAsteroidDiagnosticEvent(message, ...)
    if not ASTEROID_DIAGNOSTICS_ENABLED or self.preview then
        return
    end
    if self.asteroidDiagnostics.eventLines >= ASTEROID_DIAGNOSTIC_EVENT_LIMIT then
        return
    end

    self.asteroidDiagnostics.eventLines = self.asteroidDiagnostics.eventLines + 1
    StarryLog.forceDebug("miner asteroid " .. message, ...)
end

function SpaceMiner:addAsteroid(asteroid, source)
    self.asteroidSerial = self.asteroidSerial + 1
    asteroid.id = self.asteroidSerial
    asteroid.wasVisible = false
    self.asteroids[#self.asteroids + 1] = asteroid

    if source == "fragment" then
        self.asteroidDiagnostics.fragments = self.asteroidDiagnostics.fragments + 1
    else
        self.asteroidDiagnostics.spawned = self.asteroidDiagnostics.spawned + 1
    end
end

function SpaceMiner:getAsteroidScreenState(asteroid)
    local drawX, drawY = worldToScreen(self.player.x, self.player.y, asteroid.x, asteroid.y)
    local visible = drawX >= -asteroid.radius
        and drawX <= (SCREEN_WIDTH + asteroid.radius)
        and drawY >= -asteroid.radius
        and drawY <= (SCREEN_HEIGHT + asteroid.radius)
    return drawX, drawY, visible
end

function SpaceMiner:logAsteroidDiagnosticsIfNeeded()
    if not ASTEROID_DIAGNOSTICS_ENABLED or self.preview or self.frame % ASTEROID_DIAGNOSTIC_INTERVAL_FRAMES ~= 0 then
        return
    end

    local visible = 0
    local stages = { 0, 0, 0, 0 }
    for _, asteroid in ipairs(self.asteroids) do
        local _, _, asteroidVisible = self:getAsteroidScreenState(asteroid)
        if asteroidVisible then
            visible = visible + 1
        end
        stages[asteroid.stage + 1] = (stages[asteroid.stage + 1] or 0) + 1
    end

    local diagnostics = self.asteroidDiagnostics
    StarryLog.forceDebug(
        "miner asteroid summary frame=%d asteroids=%d visible=%d stages=%d/%d/%d/%d entities=%d spawned=%d fragments=%d minedLaser=%d minedMissile=%d collisions=%d visibilityEntries=%d visibilityExits=%d wraps=%d/%d pressureChecks=%d pressureCandidates=%d blockedAge=%d blockedGrace=%d pressurePruned=%d",
        self.frame,
        #self.asteroids,
        visible,
        stages[1],
        stages[2],
        stages[3],
        stages[4],
        self:getActiveEntityCount(),
        diagnostics.spawned,
        diagnostics.fragments,
        diagnostics.minedLaser,
        diagnostics.minedMissile,
        diagnostics.playerCollisions,
        diagnostics.visibilityEntries,
        diagnostics.visibilityExits,
        diagnostics.wrapsX,
        diagnostics.wrapsY,
        diagnostics.pressureChecks,
        diagnostics.pressureCandidates,
        diagnostics.pressureBlockedAge,
        diagnostics.pressureBlockedGrace,
        diagnostics.pressurePruned
    )
    self:resetAsteroidDiagnostics()
end

function SpaceMiner:spawnAsteroid(stage, originX, originY)
    local config = ASTEROID_STAGE_CONFIG[stage] or ASTEROID_STAGE_CONFIG[0]
    local angle = math.random() * math.pi * 2
    local speed = config.speed * (0.6 + (math.random() * 0.8))
    local distance = ASTEROID_SAFE_RADIUS + math.random(120, 360)
    local x = originX or (self.player.x + math.cos(angle) * distance)
    local y = originY or (self.player.y + math.sin(angle) * distance)
    if originX == nil then
        x = x + math.random(-80, 80)
        y = y + math.random(-80, 80)
    end

    self:addAsteroid({
        x = x,
        y = y,
        vx = math.cos(angle + math.pi * 0.5) * speed,
        vy = math.sin(angle + math.pi * 0.5) * speed,
        stage = stage,
        radius = config.radius,
        hp = config.hp,
        ageFrames = 0,
        lastVisibleFrame = -99999
    }, "spawn")
end

function SpaceMiner:spawnFragments(asteroid, options)
    local nextStage = asteroid.stage + 1
    local nextConfig = ASTEROID_STAGE_CONFIG[nextStage]
    if nextConfig == nil then
        return
    end

    options = options or {}
    local missileCascade = options.missileCascade == true

    for index = 1, 2 do
        if missileCascade and math.random() < 0.5 then
            goto continue
        end
        local angle = math.atan(asteroid.vy, asteroid.vx) + ((index == 1 and -0.8) or 0.8)
        local speed = nextConfig.speed * (0.8 + (math.random() * 0.7))
        self:addAsteroid({
            x = asteroid.x + math.cos(angle) * nextConfig.radius,
            y = asteroid.y + math.sin(angle) * nextConfig.radius,
            vx = asteroid.vx * 0.55 + math.cos(angle) * speed,
            vy = asteroid.vy * 0.55 + math.sin(angle) * speed,
            stage = nextStage,
            radius = nextConfig.radius,
            hp = nextConfig.hp,
            ageFrames = 0,
            lastVisibleFrame = self.frame or 0
        }, "fragment")
        ::continue::
    end
end

function SpaceMiner:addExplosion(x, y, radius, life)
    self.explosions[#self.explosions + 1] = {
        x = x,
        y = y,
        radius = radius or 10,
        life = life or 10,
        maxLife = life or 10
    }
end

function SpaceMiner:damagePlayer(reason)
    if self.shieldFlashFrames > 0 then
        return
    end

    if self.playerShieldHits > 0 then
        self.playerShieldHits = self.playerShieldHits - 1
    else
        self.playerHullHits = math.max(0, self.playerHullHits - 1)
    end

    self.shieldFlashFrames = SHIELD_FLASH_FRAMES
    self.framesSincePlayerDamage = 0
    self.shieldRechargeFrames = 0
    self:addExplosion(self.player.x, self.player.y, 14, 10)
    StarryLog.info("miner player hit reason=%s shield=%d hull=%d", tostring(reason), self.playerShieldHits, self.playerHullHits)
    if self.playerHullHits <= 0 then
        self.gameOver = true
    end
end

function SpaceMiner:updateShieldRecharge()
    if self.preview or self.gameOver then
        return
    end

    self.framesSincePlayerDamage = self.framesSincePlayerDamage + 1
    if self.playerShieldHits >= SHIELD_HITS or self.framesSincePlayerDamage < SHIELD_RECHARGE_DELAY_FRAMES then
        self.shieldRechargeFrames = 0
        return
    end

    self.shieldRechargeFrames = self.shieldRechargeFrames + 1
    if self.shieldRechargeFrames >= SHIELD_RECHARGE_STEP_FRAMES then
        self.playerShieldHits = math.min(SHIELD_HITS, self.playerShieldHits + 1)
        self.shieldRechargeFrames = 0
    end
end

function SpaceMiner:spawnEnemy(enemyType, entryDegrees)
    self.enemySerial = self.enemySerial + 1
    local angle
    if entryDegrees ~= nil then
        angle = screenDegreesToRadians(entryDegrees)
    else
        angle = math.random() * math.pi * 2
    end
    local distance = 280 + math.random(60, 180)
    local x = self.player.x + math.cos(angle) * distance
    local y = self.player.y + math.sin(angle) * distance
    local hp = 4
    local acceleration = ENEMY_BASE_ACCELERATION
    local maxSpeed = ENEMY_MAX_SPEED
    local size = 7
    if enemyType == "escaper" then
        hp = 5
        acceleration = ENEMY_ESCAPER_ACCELERATION
        maxSpeed = ENEMY_MAX_SPEED + 0.35
        size = 6
    elseif enemyType == "striker" then
        hp = 4
        acceleration = ENEMY_STRIKER_ACCELERATION
        maxSpeed = ENEMY_MAX_SPEED + 0.9
        size = 5
    end

    self.enemyShips[#self.enemyShips + 1] = {
        id = self.enemySerial,
        type = enemyType,
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        angle = math.deg(angle + math.pi),
        hp = hp,
        size = size,
        acceleration = acceleration,
        maxSpeed = maxSpeed,
        missileCooldown = STRIKER_MISSILE_COOLDOWN + math.random(0, 40)
    }
end

function SpaceMiner:beginStage(index)
    self.stageIndex = clamp(index, 1, #STAGE_SCHEDULE)
    self.stageFrame = 0
    local stage = STAGE_SCHEDULE[self.stageIndex]
    self.stageLabel = stage.label
    self.stageRuntime = {
        alertStarted = false,
        alertStartFrame = nil,
        waveStartFrame = stage.waveStartFrame,
        spawnedEntries = {}
    }
    StarryLog.info("miner stage begin %s", stage.id)
end

function SpaceMiner:advanceStage()
    if self.stageIndex < #STAGE_SCHEDULE then
        self:beginStage(self.stageIndex + 1)
    else
        self.stageLabel = "Open Mining"
        self.stageFrame = self.stageFrame + 1
    end
end

function SpaceMiner:getCurrentStage()
    return STAGE_SCHEDULE[self.stageIndex]
end

function SpaceMiner:hasWaveAlertAtFrame(alertStartFrame)
    if alertStartFrame == nil then
        return false
    end

    local elapsed = self.frame - alertStartFrame
    if elapsed < 0 or elapsed >= ALERT_TOTAL_FRAMES then
        return false
    end

    local phase = math.floor(elapsed / ALERT_FLASH_FRAMES)
    return (phase % 2) == 0
end

function SpaceMiner:getActiveAlertText()
    local stage = self:getCurrentStage()
    if stage == nil then
        return nil
    end

    local runtime = self.stageRuntime
    if stage.kind == "wave" and runtime ~= nil and runtime.alertStarted and self:hasWaveAlertAtFrame(runtime.alertStartFrame) then
        return stage.alertText or DEFAULT_ALERT_TEXT
    end

    if stage.kind == "mining" then
        local nextStage = STAGE_SCHEDULE[self.stageIndex + 1]
        if nextStage ~= nil
            and nextStage.kind == "wave"
            and nextStage.trigger ~= nil
            and nextStage.trigger.type == "time"
            and self:hasWaveAlertAtFrame(nextStage.alertStartFrame) then
            return nextStage.alertText or DEFAULT_ALERT_TEXT
        end
    end

    return nil
end

function SpaceMiner:spawnWaveEntry(entry)
    local oppositeDegrees = normalizeAngle(entry.entryDegrees + 180)
    for index = 1, entry.quantity do
        local spawnDegrees = ((index % 2) == 1) and entry.entryDegrees or oppositeDegrees
        self:spawnEnemy(entry.entityType, spawnDegrees)
    end
end

function SpaceMiner:stageEntriesFullySpawned(stage)
    local runtime = self.stageRuntime
    if runtime == nil then
        return false
    end

    for _, entry in ipairs(stage.entries or {}) do
        if runtime.spawnedEntries[entry.id] ~= true then
            return false
        end
    end

    return true
end

function SpaceMiner:updateStage()
    if self.preview then
        return
    end

    local stage = self:getCurrentStage()
    if stage == nil or self.gameOver then
        return
    end

    self.stageFrame = self.stageFrame + 1
    if stage.kind == "mining" then
        if self.stageFrame >= stage.durationFrames then
            self:advanceStage()
        end
        return
    end

    local runtime = self.stageRuntime
    if runtime == nil then
        return
    end

    if not runtime.alertStarted then
        if stage.trigger.type == "time" then
            if self.frame >= (stage.alertStartFrame or 0) then
                runtime.alertStarted = true
                runtime.alertStartFrame = stage.alertStartFrame or self.frame
                runtime.waveStartFrame = stage.waveStartFrame or self.frame
            end
        elseif self.stageFrame >= (stage.trigger.delayFrames or 0) then
            runtime.alertStarted = true
            runtime.alertStartFrame = self.frame
            runtime.waveStartFrame = self.frame + ALERT_TOTAL_FRAMES + ALERT_GAP_FRAMES
        end
    end

    if runtime.waveStartFrame == nil or self.frame < runtime.waveStartFrame then
        return
    end

    for _, entry in ipairs(stage.entries or {}) do
        if runtime.spawnedEntries[entry.id] ~= true then
            local dueFrame
            if stage.trigger.type == "time" then
                dueFrame = entry.timestampFrames or ((stage.waveStartFrame or runtime.waveStartFrame) + (entry.offsetFrames or 0))
            else
                dueFrame = runtime.waveStartFrame + (entry.offsetFrames or 0)
            end

            if self.frame >= dueFrame then
                self:spawnWaveEntry(entry)
                runtime.spawnedEntries[entry.id] = true
            end
        end
    end

    if self:stageEntriesFullySpawned(stage) and #self.enemyShips == 0 and #self.enemyMissiles == 0 then
        self:advanceStage()
    end
end

function SpaceMiner:applyCrank(change)
    if math.abs(change) <= 0.001 then
        return
    end

    self.virtualCrankAngle = self.virtualCrankAngle + change
    self.player.angle = normalizeAngle(self.player.angle + (change * self.turnScale))
end

function SpaceMiner:updateInput(upPressed, downPressed, leftPressed, rightJustPressed)
    self.input.thrust = upPressed and 1 or 0
    self.input.reverse = downPressed and 1 or 0
    self.input.laser = leftPressed == true
    self.player.laserOn = self.input.laser
    if rightJustPressed then
        self.player.pendingMissileTrigger = true
    end
end

function SpaceMiner:applyPlayerThrust()
    if self.gameOver then
        return
    end

    local radians = math.rad(self.player.angle)
    if self.input.thrust > 0 then
        applyAcceleration(self.player, math.cos(radians) * PLAYER_THRUST, math.sin(radians) * PLAYER_THRUST, PLAYER_MAX_SPEED)
    end
    if self.input.reverse > 0 then
        applyAcceleration(self.player, -math.cos(radians) * PLAYER_REVERSE_THRUST, -math.sin(radians) * PLAYER_REVERSE_THRUST, PLAYER_MAX_SPEED)
    end
end

function SpaceMiner:updatePlayerPosition()
    if not self.preview
        and self.modeId == SpaceMiner.MODE_FULL
        and self.input.thrust <= 0
        and self.input.reverse <= 0 then
        self.player.vx = self.player.vx * PLAYER_FULL_MODE_IDLE_DRAG
        self.player.vy = self.player.vy * PLAYER_FULL_MODE_IDLE_DRAG

        if magnitude(self.player.vx, self.player.vy) <= PLAYER_FULL_MODE_AUTO_STOP_SPEED then
            self.player.vx = 0
            self.player.vy = 0
        end
    end

    self.player.x = self.player.x + self.player.vx
    self.player.y = self.player.y + self.player.vy
    if self.shieldFlashFrames > 0 then
        self.shieldFlashFrames = self.shieldFlashFrames - 1
    end
    self:updateShieldRecharge()
end

function SpaceMiner:handleMissileTrigger()
    if self.player.pendingMissileTrigger ~= true then
        return
    end

    if self.player.missile ~= nil then
        self:explodePlayerMissile(self.player.missile.x, self.player.missile.y)
        self.player.pendingMissileTrigger = false
        return
    end

    local radians = math.rad(self.player.angle)
    self.player.missile = {
        x = self.player.x,
        y = self.player.y,
        vx = math.cos(radians) * MISSILE_SPEED + self.player.vx,
        vy = math.sin(radians) * MISSILE_SPEED + self.player.vy,
        life = MISSILE_LIFE_FRAMES
    }
    self.player.pendingMissileTrigger = false
end

function SpaceMiner:damageAsteroid(index, amount, options)
    local asteroid = self.asteroids[index]
    if asteroid == nil then
        return
    end

    options = options or {}
    asteroid.hp = asteroid.hp - amount
    if asteroid.hp > 0 then
        return
    end

    local config = ASTEROID_STAGE_CONFIG[asteroid.stage]
    self.score = self.score + (config and config.score or 1)
    self.minedChunks = self.minedChunks + 1
    self:addExplosion(asteroid.x, asteroid.y, asteroid.radius + 4, 9)
    if options.spawnFragments ~= false then
        self:spawnFragments(asteroid, {
            missileCascade = options.missileCascade == true
        })
    end
    if options.removalReason == "missile" then
        self.asteroidDiagnostics.minedMissile = self.asteroidDiagnostics.minedMissile + 1
    else
        self.asteroidDiagnostics.minedLaser = self.asteroidDiagnostics.minedLaser + 1
    end
    table.remove(self.asteroids, index)
end

function SpaceMiner:damageEnemy(index, amount)
    local enemy = self.enemyShips[index]
    if enemy == nil then
        return
    end

    enemy.hp = enemy.hp - amount
    if enemy.hp > 0 then
        return
    end

    self.score = self.score + 25
    self:addExplosion(enemy.x, enemy.y, enemy.size + 6, 10)
    table.remove(self.enemyShips, index)
end

function SpaceMiner:explodePlayerMissile(x, y)
    self:addExplosion(x, y, MISSILE_BLAST_RADIUS, 9)

    for enemyIndex = #self.enemyShips, 1, -1 do
        local enemy = self.enemyShips[enemyIndex]
        local hitRadius = MISSILE_BLAST_RADIUS + enemy.size
        if distanceSquared(x, y, enemy.x, enemy.y) <= (hitRadius * hitRadius) then
            self:damageEnemy(enemyIndex, MISSILE_DAMAGE)
        end
    end

    for asteroidIndex = #self.asteroids, 1, -1 do
        local asteroid = self.asteroids[asteroidIndex]
        local hitRadius = MISSILE_BLAST_RADIUS + asteroid.radius
        if distanceSquared(x, y, asteroid.x, asteroid.y) <= (hitRadius * hitRadius) then
            self:damageAsteroid(asteroidIndex, MISSILE_DAMAGE, {
                missileCascade = true,
                removalReason = "missile"
            })
        end
    end

    self.player.missile = nil
end

function SpaceMiner:updatePlayerMissile()
    self:handleMissileTrigger()

    local missile = self.player.missile
    if missile == nil then
        return
    end

    missile.x = missile.x + missile.vx
    missile.y = missile.y + missile.vy
    missile.life = missile.life - 1

    for enemyIndex, enemy in ipairs(self.enemyShips) do
        local hitRadius = enemy.size + 3
        if distanceSquared(missile.x, missile.y, enemy.x, enemy.y) <= (hitRadius * hitRadius) then
            self:explodePlayerMissile(missile.x, missile.y)
            return
        end
    end

    for asteroidIndex, asteroid in ipairs(self.asteroids) do
        local hitRadius = asteroid.radius + 2
        if distanceSquared(missile.x, missile.y, asteroid.x, asteroid.y) <= (hitRadius * hitRadius) then
            self:explodePlayerMissile(missile.x, missile.y)
            return
        end
    end

    if missile.life <= 0 then
        self:explodePlayerMissile(missile.x, missile.y)
    end
end

function SpaceMiner:updateEnemyMissiles()
    for missileIndex = #self.enemyMissiles, 1, -1 do
        local missile = self.enemyMissiles[missileIndex]
        missile.x = missile.x + missile.vx
        missile.y = missile.y + missile.vy
        missile.life = missile.life - 1

        if distanceSquared(missile.x, missile.y, self.player.x, self.player.y) <= ((PLAYER_RADIUS + 4) * (PLAYER_RADIUS + 4)) then
            self:addExplosion(missile.x, missile.y, 12, 8)
            self:damagePlayer("enemy-missile")
            table.remove(self.enemyMissiles, missileIndex)
        elseif missile.life <= 0 then
            self:addExplosion(missile.x, missile.y, 10, 7)
            table.remove(self.enemyMissiles, missileIndex)
        end
    end
end

function SpaceMiner:applyLaser()
    if not self.player.laserOn or self.gameOver then
        return
    end

    local radians = math.rad(self.player.angle)
    local endX = self.player.x + (math.cos(radians) * LASER_RANGE)
    local endY = self.player.y + (math.sin(radians) * LASER_RANGE)

    for enemyIndex = #self.enemyShips, 1, -1 do
        local enemy = self.enemyShips[enemyIndex]
        local hitDistanceSq = linePointDistanceSquared(enemy.x, enemy.y, self.player.x, self.player.y, endX, endY)
        local hitRadius = enemy.size + LASER_WIDTH
        if hitDistanceSq <= (hitRadius * hitRadius) then
            self:damageEnemy(enemyIndex, LASER_DAMAGE)
        end
    end

    for asteroidIndex = #self.asteroids, 1, -1 do
        local asteroid = self.asteroids[asteroidIndex]
        local hitDistanceSq = linePointDistanceSquared(asteroid.x, asteroid.y, self.player.x, self.player.y, endX, endY)
        local hitRadius = asteroid.radius + LASER_WIDTH
        if hitDistanceSq <= (hitRadius * hitRadius) then
            self:damageAsteroid(asteroidIndex, LASER_DAMAGE, {
                removalReason = "laser"
            })
        end
    end
end

function SpaceMiner:updateAsteroids()
    for asteroidIndex = #self.asteroids, 1, -1 do
        local asteroid = self.asteroids[asteroidIndex]
        asteroid.ageFrames = (asteroid.ageFrames or 0) + 1
        local nextX = asteroid.x + asteroid.vx
        local nextY = asteroid.y + asteroid.vy
        asteroid.x = wrapCoordinate(self.player.x, nextX)
        asteroid.y = wrapCoordinate(self.player.y, nextY)
        if asteroid.x ~= nextX then
            self.asteroidDiagnostics.wrapsX = self.asteroidDiagnostics.wrapsX + 1
            self:logAsteroidDiagnosticEvent(
                "wrap id=%d stage=%d axis=x age=%d world=%.1f,%.1f player=%.1f,%.1f",
                asteroid.id,
                asteroid.stage,
                asteroid.ageFrames,
                asteroid.x,
                asteroid.y,
                self.player.x,
                self.player.y
            )
        end
        if asteroid.y ~= nextY then
            self.asteroidDiagnostics.wrapsY = self.asteroidDiagnostics.wrapsY + 1
            self:logAsteroidDiagnosticEvent(
                "wrap id=%d stage=%d axis=y age=%d world=%.1f,%.1f player=%.1f,%.1f",
                asteroid.id,
                asteroid.stage,
                asteroid.ageFrames,
                asteroid.x,
                asteroid.y,
                self.player.x,
                self.player.y
            )
        end

        local drawX, drawY, visible = self:getAsteroidScreenState(asteroid)
        if visible then
            asteroid.lastVisibleFrame = self.frame
            if not asteroid.wasVisible then
                self.asteroidDiagnostics.visibilityEntries = self.asteroidDiagnostics.visibilityEntries + 1
            end
        elseif asteroid.wasVisible then
            self.asteroidDiagnostics.visibilityExits = self.asteroidDiagnostics.visibilityExits + 1
            self:logAsteroidDiagnosticEvent(
                "visibility-exit id=%d stage=%d age=%d screen=%.1f,%.1f velocity=%.2f,%.2f",
                asteroid.id,
                asteroid.stage,
                asteroid.ageFrames,
                drawX,
                drawY,
                asteroid.vx,
                asteroid.vy
            )
        end
        asteroid.wasVisible = visible

        local hitRadius = asteroid.radius + PLAYER_RADIUS
        if distanceSquared(asteroid.x, asteroid.y, self.player.x, self.player.y) <= (hitRadius * hitRadius) then
            self:addExplosion(asteroid.x, asteroid.y, asteroid.radius + 4, 8)
            self:damagePlayer("asteroid")
            self:spawnFragments(asteroid)
            self.asteroidDiagnostics.playerCollisions = self.asteroidDiagnostics.playerCollisions + 1
            self:logAsteroidDiagnosticEvent(
                "player-collision id=%d stage=%d age=%d screen=%.1f,%.1f",
                asteroid.id,
                asteroid.stage,
                asteroid.ageFrames,
                drawX,
                drawY
            )
            table.remove(self.asteroids, asteroidIndex)
        end
    end

    self:pruneOffscreenAsteroidsForEntityPressure()
    self:seedAsteroids(self.preview and PREVIEW_ASTEROID_COUNT or TARGET_ASTEROID_COUNT)
end

function SpaceMiner:getActiveEntityCount()
    local count = #self.asteroids + #self.enemyShips + #self.enemyMissiles + #self.explosions
    if self.player.missile ~= nil then
        count = count + 1
    end
    return count
end

function SpaceMiner:pruneOffscreenAsteroidsForEntityPressure()
    local activeEntities = self:getActiveEntityCount()
    if activeEntities <= MAX_ACTIVE_ENTITIES then
        return
    end

    self.asteroidDiagnostics.pressureChecks = self.asteroidDiagnostics.pressureChecks + 1
    local removable = {}
    for asteroidIndex, asteroid in ipairs(self.asteroids) do
        local drawX, drawY, visible = self:getAsteroidScreenState(asteroid)
        if not visible then
            removable[#removable + 1] = {
                asteroid = asteroid,
                radius = asteroid.radius,
                drawX = drawX,
                drawY = drawY
            }
        else
            asteroid.lastVisibleFrame = self.frame
        end
    end
    self.asteroidDiagnostics.pressureCandidates = self.asteroidDiagnostics.pressureCandidates + #removable

    table.sort(removable, function(left, right)
        return left.radius < right.radius
    end)

    for _, candidate in ipairs(removable) do
        if activeEntities <= MAX_ACTIVE_ENTITIES then
            break
        end
        if (candidate.asteroid.ageFrames or 0) < ASTEROID_PRUNE_PROTECTION_FRAMES then
            self.asteroidDiagnostics.pressureBlockedAge = self.asteroidDiagnostics.pressureBlockedAge + 1
            goto continue
        end
        if (self.frame - (candidate.asteroid.lastVisibleFrame or -99999)) <= ASTEROID_VISIBLE_PRUNE_GRACE_FRAMES then
            self.asteroidDiagnostics.pressureBlockedGrace = self.asteroidDiagnostics.pressureBlockedGrace + 1
            goto continue
        end
        for asteroidIndex = #self.asteroids, 1, -1 do
            if self.asteroids[asteroidIndex] == candidate.asteroid then
                self.asteroidDiagnostics.pressurePruned = self.asteroidDiagnostics.pressurePruned + 1
                self:logAsteroidDiagnosticEvent(
                    "pressure-prune id=%d stage=%d age=%d screen=%.1f,%.1f invisibleFrames=%d entitiesBefore=%d",
                    candidate.asteroid.id,
                    candidate.asteroid.stage,
                    candidate.asteroid.ageFrames or 0,
                    candidate.drawX,
                    candidate.drawY,
                    self.frame - (candidate.asteroid.lastVisibleFrame or -99999),
                    activeEntities
                )
                table.remove(self.asteroids, asteroidIndex)
                activeEntities = activeEntities - 1
                break
            end
        end
        ::continue::
    end
end

function SpaceMiner:getNearestPlayerMissile(enemy)
    if self.player.missile == nil then
        return nil
    end

    if distanceSquared(enemy.x, enemy.y, self.player.missile.x, self.player.missile.y) <= (140 * 140) then
        return self.player.missile
    end
    return nil
end

function SpaceMiner:getNearestAsteroidThreat(enemy)
    local nearest = nil
    local nearestDistanceSq = math.huge
    for _, asteroid in ipairs(self.asteroids) do
        local candidateDistanceSq = distanceSquared(enemy.x, enemy.y, asteroid.x, asteroid.y)
        if candidateDistanceSq < nearestDistanceSq then
            nearestDistanceSq = candidateDistanceSq
            nearest = asteroid
        end
    end
    return nearest, nearestDistanceSq
end

function SpaceMiner:updateSeekers(enemy)
    local dx = self.player.x - enemy.x
    local dy = self.player.y - enemy.y
    local ux, uy = unitVector(dx, dy)
    applyAcceleration(enemy, ux * enemy.acceleration, uy * enemy.acceleration, enemy.maxSpeed)
    enemy.angle = normalizeAngle(math.deg(math.atan(uy, ux)))
end

function SpaceMiner:updateEscaper(enemy)
    local awayX = 0
    local awayY = 0
    local playerDx = self.player.x - enemy.x
    local playerDy = self.player.y - enemy.y
    local playerUx, playerUy, playerDistance = unitVector(playerDx, playerDy)
    local escapingPlayer = playerDistance <= 100

    if escapingPlayer then
        awayX = awayX - playerUx * 1.6
        awayY = awayY - playerUy * 1.6
    else
        local asteroid, asteroidDistanceSq = self:getNearestAsteroidThreat(enemy)
        if asteroid ~= nil and asteroidDistanceSq <= (110 * 110) then
            local asteroidUx, asteroidUy = unitVector(asteroid.x - enemy.x, asteroid.y - enemy.y)
            awayX = awayX - asteroidUx * 1.2
            awayY = awayY - asteroidUy * 1.2
        end

        local missile = self:getNearestPlayerMissile(enemy)
        if missile ~= nil then
            local missileUx, missileUy = unitVector(missile.x - enemy.x, missile.y - enemy.y)
            awayX = awayX - missileUx * 1.4
            awayY = awayY - missileUy * 1.4
        end
    end

    if math.abs(awayX) < 0.001 and math.abs(awayY) < 0.001 then
        awayX = playerUx
        awayY = playerUy
    end

    local ux, uy = unitVector(awayX, awayY)
    applyAcceleration(enemy, ux * enemy.acceleration, uy * enemy.acceleration, enemy.maxSpeed)
    enemy.angle = normalizeAngle(math.deg(math.atan(uy, ux)))
end

function SpaceMiner:spawnEnemyMissile(enemy)
    local dx = self.player.x - enemy.x
    local dy = self.player.y - enemy.y
    local ux, uy = unitVector(dx, dy)
    self.enemyMissiles[#self.enemyMissiles + 1] = {
        x = enemy.x,
        y = enemy.y,
        vx = ux * (MISSILE_SPEED * 0.9),
        vy = uy * (MISSILE_SPEED * 0.9),
        life = MISSILE_LIFE_FRAMES
    }
end

function SpaceMiner:updateStriker(enemy)
    local desiredVx = 0
    local desiredVy = 0

    local toPlayerX = self.player.x - enemy.x
    local toPlayerY = self.player.y - enemy.y
    local ux, uy, distance = unitVector(toPlayerX, toPlayerY)
    if distance > 120 then
        desiredVx = ux * enemy.maxSpeed
        desiredVy = uy * enemy.maxSpeed
    else
        desiredVx = -uy * (enemy.maxSpeed * 0.8)
        desiredVy = ux * (enemy.maxSpeed * 0.8)
    end

    local ax = desiredVx - enemy.vx
    local ay = desiredVy - enemy.vy
    local uxAccel, uyAccel = unitVector(ax, ay)
    applyAcceleration(enemy, uxAccel * enemy.acceleration, uyAccel * enemy.acceleration, enemy.maxSpeed)
    enemy.angle = normalizeAngle(math.deg(math.atan(toPlayerY, toPlayerX)))

    enemy.missileCooldown = enemy.missileCooldown - 1
    if enemy.missileCooldown <= 0 and distance < 220 then
        self:spawnEnemyMissile(enemy)
        enemy.missileCooldown = STRIKER_MISSILE_COOLDOWN + math.random(0, 35)
    end
end

function SpaceMiner:updateEnemies()
    for enemyIndex = #self.enemyShips, 1, -1 do
        local enemy = self.enemyShips[enemyIndex]
        if enemy.type == "seeker" then
            self:updateSeekers(enemy)
        elseif enemy.type == "escaper" then
            self:updateEscaper(enemy)
        else
            self:updateStriker(enemy)
        end

        enemy.x = wrapCoordinate(self.player.x, enemy.x + enemy.vx)
        enemy.y = wrapCoordinate(self.player.y, enemy.y + enemy.vy)

        if distanceSquared(enemy.x, enemy.y, self.player.x, self.player.y) <= ((enemy.size + PLAYER_RADIUS + 1) * (enemy.size + PLAYER_RADIUS + 1)) then
            self:addExplosion(enemy.x, enemy.y, enemy.size + 6, 9)
            self:damagePlayer("enemy-ship")
            table.remove(self.enemyShips, enemyIndex)
        end
    end
end

function SpaceMiner:updateExplosions()
    for index = #self.explosions, 1, -1 do
        local explosion = self.explosions[index]
        explosion.life = explosion.life - 1
        if explosion.life <= 0 then
            table.remove(self.explosions, index)
        end
    end
end

function SpaceMiner:updatePreview()
    self.previewFrameCounter = self.previewFrameCounter + 1
    self.player.angle = normalizeAngle(self.player.angle + 1.4)
    self.previewDriftAngle = self.previewDriftAngle + 0.01
    applyAcceleration(self.player, math.cos(self.previewDriftAngle) * 0.01, math.sin(self.previewDriftAngle) * 0.01, 0.9)
    self:updatePlayerPosition()
    self:updateDecor()
    self:updateAsteroids()
    self:updateExplosions()
end

function SpaceMiner:update()
    if self.preview then
        self:updatePreview()
        return
    end

    if self.gameOver then
        self:updateExplosions()
        return
    end

    self.frame = self.frame + 1
    self:updateStage()
    self:applyPlayerThrust()
    self:updatePlayerPosition()
    self:updateDecor()
    self:updatePlayerMissile()
    self:updateEnemyMissiles()
    self:applyLaser()
    self:updateEnemies()
    self:updateAsteroids()
    self:updateExplosions()
    self:logAsteroidDiagnosticsIfNeeded()
end

function SpaceMiner:drawDecorLayer(layer)
    gfx.setColor(gfx.kColorWhite)
    for _, item in ipairs(self.decor) do
        if item.layer == layer then
            local drawX, drawY = parallaxWorldToScreen(self.player.x, self.player.y, item.x, item.y, item.parallax)
            local padding = item.kind == "circle" and 18 or 8
            if drawX >= -padding and drawX <= (SCREEN_WIDTH + padding) and drawY >= -padding and drawY <= (SCREEN_HEIGHT + padding) then
                if item.kind == "dot" then
                    gfx.fillRect(drawX, drawY, 1, 1)
                elseif item.kind == "cross" then
                    gfx.drawLine(drawX - 1, drawY, drawX + 1, drawY)
                    gfx.drawLine(drawX, drawY - 1, drawX, drawY + 1)
                elseif item.kind == "square" then
                    gfx.fillRect(drawX - 1, drawY - 1, 2, 2)
                else
                    if item.layer ~= "front" then
                        gfx.setDitherPattern(0.25, gfx.image.kDitherTypeBayer8x8)
                        gfx.setColor(gfx.kColorBlack)
                        gfx.fillCircleAtPoint(drawX, drawY, item.radius)
                        gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
                        gfx.setColor(gfx.kColorWhite)
                    end
                    gfx.drawCircleAtPoint(drawX, drawY, item.radius)
                end
            end
        end
    end
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    gfx.setColor(gfx.kColorWhite)
end

function SpaceMiner:drawShip()
    gfx.setColor(gfx.kColorWhite)
    local radians = math.rad(self.player.angle)
    local tipX = CENTER_X + (math.cos(radians) * 10)
    local tipY = CENTER_Y + (math.sin(radians) * 10)
    local leftX = CENTER_X + (math.cos(radians + 2.55) * 8)
    local leftY = CENTER_Y + (math.sin(radians + 2.55) * 8)
    local rightX = CENTER_X + (math.cos(radians - 2.55) * 8)
    local rightY = CENTER_Y + (math.sin(radians - 2.55) * 8)
    gfx.drawLine(tipX, tipY, leftX, leftY)
    gfx.drawLine(tipX, tipY, rightX, rightY)
    gfx.drawLine(leftX, leftY, rightX, rightY)

    if self.input.thrust > 0 and not self.preview then
        local exhaustX = CENTER_X - (math.cos(radians) * 8)
        local exhaustY = CENTER_Y - (math.sin(radians) * 8)
        gfx.drawLine(exhaustX, exhaustY, exhaustX - (math.cos(radians) * 6), exhaustY - (math.sin(radians) * 6))
    end

    local shieldRadius = PLAYER_RADIUS + 3 + (self.playerShieldHits > 0 and 2 or 0)
    if self.playerShieldHits > 0 then
        gfx.drawCircleAtPoint(CENTER_X, CENTER_Y, shieldRadius)
    end
end

function SpaceMiner:drawAsteroids()
    gfx.setColor(gfx.kColorWhite)
    local lateStageGhostMediumAsteroids = not self.preview and self.stageIndex >= 6
    for _, asteroid in ipairs(self.asteroids) do
        local drawX, drawY = worldToScreen(self.player.x, self.player.y, asteroid.x, asteroid.y)
        if drawX >= -30 and drawX <= (SCREEN_WIDTH + 30) and drawY >= -30 and drawY <= (SCREEN_HEIGHT + 30) then
            if asteroid.stage >= 2 then
                gfx.fillCircleAtPoint(drawX, drawY, asteroid.radius)
                gfx.setColor(gfx.kColorBlack)
                if asteroid.radius >= 5 then
                    gfx.fillCircleAtPoint(drawX + 1, drawY - 1, math.max(1, asteroid.radius - 4))
                end
                gfx.setColor(gfx.kColorWhite)
            elseif asteroid.stage == 1 then
                if lateStageGhostMediumAsteroids then
                    gfx.setDitherPattern(0.6, gfx.image.kDitherTypeBayer8x8)
                    gfx.fillCircleAtPoint(drawX, drawY, asteroid.radius)
                    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
                else
                    gfx.fillCircleAtPoint(drawX, drawY, asteroid.radius)
                    gfx.setColor(gfx.kColorBlack)
                    gfx.fillCircleAtPoint(drawX + 1, drawY - 1, math.max(1, asteroid.radius - 6))
                    gfx.setColor(gfx.kColorWhite)
                end
            else
                gfx.setDitherPattern(0.6, gfx.image.kDitherTypeBayer8x8)
                gfx.fillCircleAtPoint(drawX, drawY, asteroid.radius)
                gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
            end
            gfx.drawCircleAtPoint(drawX, drawY, asteroid.radius)
            if asteroid.stage <= 1 then
                gfx.drawLine(drawX - asteroid.radius * 0.6, drawY, drawX + asteroid.radius * 0.6, drawY - asteroid.radius * 0.2)
            else
                gfx.drawLine(drawX - asteroid.radius * 0.4, drawY, drawX + asteroid.radius * 0.4, drawY)
                gfx.drawLine(drawX, drawY - asteroid.radius * 0.4, drawX, drawY + asteroid.radius * 0.4)
            end
        end
    end
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    gfx.setColor(gfx.kColorWhite)
end

function SpaceMiner:drawEnemies()
    gfx.setColor(gfx.kColorWhite)
    for _, enemy in ipairs(self.enemyShips) do
        local drawX, drawY = worldToScreen(self.player.x, self.player.y, enemy.x, enemy.y)
        local half = enemy.size
        if enemy.type == "striker" then
            gfx.drawLine(drawX - half, drawY + half, drawX, drawY - half - 2)
            gfx.drawLine(drawX, drawY - half - 2, drawX + half, drawY + half)
            gfx.drawLine(drawX - half, drawY + half, drawX + half, drawY + half)
        else
            gfx.drawRect(drawX - half, drawY - half, half * 2, half * 2)
        end
    end
end

function SpaceMiner:drawMissiles()
    gfx.setColor(gfx.kColorWhite)
    if self.player.missile ~= nil then
        local drawX, drawY = worldToScreen(self.player.x, self.player.y, self.player.missile.x, self.player.missile.y)
        local radians = math.rad(self.player.angle)
        local tailX = drawX - (math.cos(radians) * PLAYER_MISSILE_DRAW_LENGTH)
        local tailY = drawY - (math.sin(radians) * PLAYER_MISSILE_DRAW_LENGTH)
        gfx.drawLine(tailX, tailY, drawX, drawY)
        gfx.fillCircleAtPoint(drawX, drawY, PLAYER_MISSILE_DRAW_RADIUS)
    end

    for _, missile in ipairs(self.enemyMissiles) do
        local drawX, drawY = worldToScreen(self.player.x, self.player.y, missile.x, missile.y)
        gfx.drawCircleAtPoint(drawX, drawY, 2)
    end
end

function SpaceMiner:drawLaser()
    if not self.player.laserOn then
        return
    end

    gfx.setColor(gfx.kColorWhite)
    local radians = math.rad(self.player.angle)
    local endX = CENTER_X + (math.cos(radians) * LASER_RANGE)
    local endY = CENTER_Y + (math.sin(radians) * LASER_RANGE)
    gfx.drawLine(CENTER_X, CENTER_Y, endX, endY)
end

function SpaceMiner:drawExplosions()
    gfx.setColor(gfx.kColorWhite)
    for _, explosion in ipairs(self.explosions) do
        local drawX, drawY = worldToScreen(self.player.x, self.player.y, explosion.x, explosion.y)
        local radius = math.max(1, math.floor(explosion.radius * (explosion.life / explosion.maxLife)))
        gfx.drawCircleAtPoint(drawX, drawY, radius)
    end
end

function SpaceMiner:drawHud()
    gfx.setColor(gfx.kColorWhite)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawText("Space Miner", 8, 8)
    gfx.drawText(self.stageLabel, 8, 24)
    gfx.drawText(string.format("Ore %d  Score %d", self.minedChunks, self.score), 8, 40)
    gfx.drawText(string.format("Shield %d  Hull %d", self.playerShieldHits, self.playerHullHits), 8, 56)
    gfx.drawText(string.format("Vel %.1f", magnitude(self.player.vx, self.player.vy)), 8, 72)
    if not self.preview then
        gfx.drawText("Up/Down thrust  Left laser  Right missile  Crank turn", 8, 220)
    end
    if self.gameOver then
        gfx.drawTextAligned("Ship destroyed. Press B to return.", 200, 108, kTextAlignment.center)
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function SpaceMiner:drawAlert()
    local alertText = self:getActiveAlertText()
    if alertText == nil then
        return
    end

    gfx.setColor(gfx.kColorWhite)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    local centerX = SCREEN_WIDTH * 0.5
    local centerY = 104
    gfx.drawTextAligned(alertText, centerX, centerY, kTextAlignment.center)
end

function SpaceMiner:draw()
    gfx.clear(gfx.kColorBlack)
    gfx.setColor(gfx.kColorWhite)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    self:drawDecorLayer("back")
    self:drawAsteroids()
    self:drawEnemies()
    self:drawShip()
    self:drawMissiles()
    self:drawExplosions()
    self:drawLaser()
    self:drawAlert()
    self:drawDecorLayer("front")
    self:drawHud()
end
