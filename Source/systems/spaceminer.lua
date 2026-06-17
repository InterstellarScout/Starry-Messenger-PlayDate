import "gameconfig"
import "data/spaceminerwaves"

import "CoreLibs/graphics"

local pd <const> = playdate
local gfx <const> = pd.graphics
local SPACE_MINER_CONFIG <const> = GameConfig and GameConfig.spaceMiner or {}
local BASE_CONFIG <const> = SPACE_MINER_CONFIG.base or {}
local ENEMY_TYPE_CONFIG <const> = SPACE_MINER_CONFIG.enemyTypes or {}
local PROGRESSION_CONFIG <const> = SPACE_MINER_CONFIG.playerProgression or {}

SpaceMiner = {}
SpaceMiner.__index = SpaceMiner

SpaceMiner.MODE_FULL = "full"
SpaceMiner.MODE_HALF = "half"
SpaceMiner.MODE_QUARTER = "quarter"
SpaceMiner.MODE_STORY = "story"
SpaceMiner.MODE_CONTINUE = "continue"
SpaceMiner.MODE_NEW_SAVE = "new-save"
SpaceMiner.MODE_ENDLESS = "endless-ore"
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
local ENEMY_IDLE_DRAG <const> = SPACE_MINER_CONFIG.enemyIdleDrag or 0.992
local ENEMY_ARRIVAL_RADIUS <const> = SPACE_MINER_CONFIG.enemyArrivalRadius or 92
local ENEMY_PREDICTION_FRAMES <const> = SPACE_MINER_CONFIG.enemyPredictionFrames or 14
local ESCAPER_LINGER_MIN_RADIUS <const> = SPACE_MINER_CONFIG.escaperLingerMinRadius or 175
local ESCAPER_LINGER_MAX_RADIUS <const> = SPACE_MINER_CONFIG.escaperLingerMaxRadius or 250
local ESCAPER_LINGER_TARGET_RADIUS <const> = SPACE_MINER_CONFIG.escaperLingerTargetRadius or 214
local LASER_RANGE <const> = SPACE_MINER_CONFIG.laserRange or 170
local LASER_WIDTH <const> = 4
local LASER_DAMAGE <const> = SPACE_MINER_CONFIG.laserDamage or 0.34
local LASER_ENEMY_PENETRATION_LIMIT <const> = SPACE_MINER_CONFIG.laserEnemyPenetrationLimit or 4
local MISSILE_SPEED <const> = SPACE_MINER_CONFIG.missileSpeed or 4.4
local ENEMY_HEAT_MISSILE_TURN_ACCELERATION <const> = SPACE_MINER_CONFIG.enemyHeatMissileTurnAcceleration or 0.16
local ENEMY_HEAT_MISSILE_MAX_SPEED <const> = SPACE_MINER_CONFIG.enemyHeatMissileMaxSpeed or (MISSILE_SPEED * 1.05)
local MISSILE_DAMAGE <const> = SPACE_MINER_CONFIG.missileDamage or 99
local MISSILE_BLAST_RADIUS <const> = SPACE_MINER_CONFIG.missileBlastRadius or 34
local MISSILE_LIFE_FRAMES <const> = SPACE_MINER_CONFIG.missileLifeFrames or 110
local PLAYER_MISSILE_DRAW_RADIUS <const> = SPACE_MINER_CONFIG.playerMissileDrawRadius or 5
local PLAYER_MISSILE_DRAW_LENGTH <const> = SPACE_MINER_CONFIG.playerMissileDrawLength or 10
local CARGO_INITIAL_CAPACITY <const> = SPACE_MINER_CONFIG.cargoInitialCapacity or 50
local CARGO_CAPACITY_ORE_STEP <const> = SPACE_MINER_CONFIG.cargoCapacityOreStep or 50
local CARGO_CAPACITY_INCREASE <const> = SPACE_MINER_CONFIG.cargoCapacityIncrease or 10
local CARGO_CAPACITY_GROW_RATE <const> = SPACE_MINER_CONFIG.cargoCapacityGrowRate or 0.04
local CARGO_UNLOAD_STEP_FRAMES <const> = SPACE_MINER_CONFIG.cargoUnloadStepFrames or 4
local HOME_BASE_MENU_RADIUS <const> = SPACE_MINER_CONFIG.homeBaseMenuRadius or 20
local ENTITY_LOG_INTERVAL_FRAMES <const> = SPACE_MINER_CONFIG.entityLogIntervalFrames or 180
local SHIP_REPAIR_SHIELD_PER_SECOND <const> = SPACE_MINER_CONFIG.shipRepairShieldPercentPerSecond or 0.10
local SHIP_REPAIR_HULL_STEP_FRAMES <const> = SPACE_MINER_CONFIG.shipRepairHullStepFrames or 30
local AUTO_MISSILE_SHOTS_PER_SECOND <const> = SPACE_MINER_CONFIG.autoMissileShotsPerSecond or 12
local MENU_AUTO_NAVIGATE_ENABLED <const> = SPACE_MINER_CONFIG.menuAutoNavigateEnabled ~= false
local MENU_AUTO_NAVIGATE_RADIUS <const> = SPACE_MINER_CONFIG.menuAutoNavigateRadius or 180
local MENU_AUTO_NAVIGATE_ACCELERATION <const> = SPACE_MINER_CONFIG.menuAutoNavigateAcceleration or 0.026
local MENU_AUTO_NAVIGATE_MAX_SPEED <const> = SPACE_MINER_CONFIG.menuAutoNavigateMaxSpeed or 1.1
local MAX_ACTIVE_ENTITIES <const> = SPACE_MINER_CONFIG.maxActiveEntities or 54
local TARGET_ASTEROID_COUNT <const> = SPACE_MINER_CONFIG.targetAsteroidCount or 24
local PREVIEW_ASTEROID_COUNT <const> = SPACE_MINER_CONFIG.previewAsteroidCount or 16
local DECOR_ITEM_COUNT <const> = SPACE_MINER_CONFIG.decorItemCount or 120
local BACKGROUND_STARS_ENABLED <const> = SPACE_MINER_CONFIG.backgroundStarsEnabled ~= false
local BACKGROUND_GALAXY_ENABLED <const> = SPACE_MINER_CONFIG.backgroundGalaxyEnabled ~= false
local BACKGROUND_STAR_COUNT <const> = SPACE_MINER_CONFIG.backgroundStarCount or 120
local BACKGROUND_GALAXY_STAR_COUNT <const> = SPACE_MINER_CONFIG.backgroundGalaxyStarCount or 90
local MEDIUM_ASTEROID_TEXTURE_ENABLED <const> = SPACE_MINER_CONFIG.mediumAsteroidTextureEnabled ~= false
local MEDIUM_ASTEROID_GRAY_DITHER <const> = SPACE_MINER_CONFIG.mediumAsteroidGrayDither or 0.48
local MEDIUM_ASTEROID_BLOTCH_COUNT_MIN <const> = SPACE_MINER_CONFIG.mediumAsteroidBlotchCountMin or 3
local MEDIUM_ASTEROID_BLOTCH_COUNT_MAX <const> = SPACE_MINER_CONFIG.mediumAsteroidBlotchCountMax or 6
local MEDIUM_ASTEROID_BLOTCH_RADIUS_MIN <const> = SPACE_MINER_CONFIG.mediumAsteroidBlotchRadiusMin or 1
local MEDIUM_ASTEROID_BLOTCH_RADIUS_MAX <const> = SPACE_MINER_CONFIG.mediumAsteroidBlotchRadiusMax or 3
local SHIELD_MAX <const> = SPACE_MINER_CONFIG.playerShieldMax or SPACE_MINER_CONFIG.shieldMax or SPACE_MINER_CONFIG.shieldHits or 100
local ASTEROID_SHIELD_DAMAGE <const> = SPACE_MINER_CONFIG.asteroidShieldDamage or 5
local ENEMY_SHIELD_DAMAGE <const> = SPACE_MINER_CONFIG.enemyShieldDamage or 10
local BASE_SHIELD_MAX <const> = BASE_CONFIG.shieldMax or SHIELD_MAX
local BASE_SHIELD_DAMAGE <const> = BASE_CONFIG.shieldDamage or ENEMY_SHIELD_DAMAGE
local BASE_PROXIMITY_RADIUS <const> = BASE_CONFIG.proximityRadius or 44
local BASE_LARGE_ASTEROID_KM <const> = BASE_CONFIG.largeAsteroidKm or 20
local BASE_WORLD_X <const> = BASE_CONFIG.x or 0
local BASE_WORLD_Y <const> = BASE_CONFIG.y or 0
local SHIELD_RECHARGE_AMOUNT <const> = SPACE_MINER_CONFIG.shieldRechargeAmount or 5
local HULL_HITS <const> = SPACE_MINER_CONFIG.playerHullHits or SPACE_MINER_CONFIG.hullHits or 10
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
local INSTRUCTION_OVERLAY_FRAMES <const> = 0
local DASHBOARD_HEIGHT <const> = 23
local DASHBOARD_Y <const> = SCREEN_HEIGHT - DASHBOARD_HEIGHT
local DASHBOARD_CENTER_X <const> = 200
local DASHBOARD_CENTER_Y <const> = DASHBOARD_Y + math.floor(DASHBOARD_HEIGHT * 0.5)
local DASHBOARD_CENTER_WIDTH <const> = 42
local DASHBOARD_SHIELD_LABEL_X <const> = 6
local DASHBOARD_SHIELD_BAR_X <const> = 50
local DASHBOARD_SHIELD_BAR_Y <const> = DASHBOARD_Y + 8
local DASHBOARD_SHIELD_BAR_WIDTH <const> = 68
local DASHBOARD_SHIELD_BAR_HEIGHT <const> = 7
local DASHBOARD_ORE_X <const> = 128
local DASHBOARD_ENEMY_X <const> = 226
local DASHBOARD_HULL_BLOCK_COUNT <const> = 10
local DASHBOARD_HULL_BLOCK_WIDTH <const> = 8
local DASHBOARD_HULL_BLOCK_HEIGHT <const> = 11
local DASHBOARD_HULL_BLOCK_GAP <const> = 1
local DASHBOARD_HULL_X <const> = 306
local DASHBOARD_HULL_Y <const> = DASHBOARD_Y + 6
local DASHBOARD_TEXT_Y <const> = DASHBOARD_Y + 5
local STORY_SAVE_KEY <const> = "spaceminer-story-save"
local MINIMAP_X <const> = 336
local MINIMAP_Y <const> = 12
local MINIMAP_WIDTH <const> = 54
local MINIMAP_HEIGHT <const> = 38
local MINIMAP_RANGE <const> = 520
local CARGO_BAR_X <const> = MINIMAP_X
local CARGO_BAR_Y <const> = MINIMAP_Y + MINIMAP_HEIGHT + 3
local CARGO_BAR_WIDTH <const> = MINIMAP_WIDTH
local CARGO_BAR_HEIGHT <const> = 11
local MINER_MENU_X <const> = 198
local MINER_MENU_Y <const> = 12
local MINER_MENU_WIDTH <const> = 190
local HOME_BASE_MENU_WIDTH <const> = SPACE_MINER_CONFIG.homeBaseMenuWidth or 240
local MINER_MENU_ROW_HEIGHT <const> = 18
local COMMUNICATION_LINE_CHAR_LIMIT <const> = SPACE_MINER_CONFIG.communicationLineCharLimit or 22
local COMMUNICATION_MAX_LINES <const> = SPACE_MINER_CONFIG.communicationMaxLines or 8
local COMMUNICATION_LINE_SPACING <const> = SPACE_MINER_CONFIG.communicationLineSpacing or 15
local COMMUNICATION_BOX_PADDING <const> = SPACE_MINER_CONFIG.communicationBoxPadding or 28
local COMMUNICATION_WIDTH <const> = SPACE_MINER_CONFIG.communicationWidth or math.floor(SCREEN_WIDTH * 0.5) - 14
local COMMUNICATION_MIN_FRAMES <const> = SPACE_MINER_CONFIG.communicationMinFrames or 90
local COMMUNICATION_FRAMES_PER_CHAR <const> = SPACE_MINER_CONFIG.communicationFramesPerChar or 2.2
local BASE_SHIELD_RADIUS <const> = BASE_CONFIG.shieldRadius or 56
local BASE_SHIELD_ASTEROID_DAMAGE <const> = BASE_CONFIG.shieldAsteroidDamage or 6
local BASE_SHIELD_ENEMY_WEAPON_DAMAGE <const> = BASE_CONFIG.shieldEnemyWeaponDamage or 28
local BASE_SHIELD_ENEMY_SHIP_DAMAGE <const> = BASE_CONFIG.shieldEnemyShipDamage or 18
local BASE_SHIELD_PLAYER_DOCK_SUPPRESS_RADIUS <const> = BASE_CONFIG.shieldPlayerDockSuppressRadius or BASE_SHIELD_RADIUS
local BASE_SHIELD_ENEMY_KEEP_ALIVE_RADIUS <const> = BASE_CONFIG.shieldEnemyKeepAliveRadius or 190

local ASTEROID_STAGE_CONFIG <const> = {
    [0] = { radius = 30, hp = 7, speed = 0.28, fragments = 2, score = 20 },
    [1] = { radius = 18, hp = 4, speed = 0.45, fragments = 2, score = 10 },
    [2] = { radius = 11, hp = 2, speed = 0.68, fragments = 2, score = 6 },
    [3] = { radius = 6, hp = 1, speed = 0.95, fragments = 0, score = 3 }
}

local function normalizeAsteroidMaterials(rawMaterials)
    local materials = {}
    local totalRarity = 0
    for index, raw in ipairs(rawMaterials or {}) do
        local rarity = math.max(0, tonumber(raw.rarity) or 0)
        if rarity > 0 then
            local material = {
                id = raw.id or string.format("material-%d", index),
                label = raw.label or raw.name or raw.id or string.format("Material %d", index),
                rarity = rarity,
                cashPerTiny = tonumber(raw.cashPerTiny or raw.cashValue or raw.value) or 1,
                markOnMiniMap = raw.markOnMiniMap == true
            }
            totalRarity = totalRarity + rarity
            material.threshold = totalRarity
            materials[#materials + 1] = material
        end
    end
    if #materials == 0 then
        materials[1] = {
            id = "stone",
            label = "Stone",
            rarity = 1,
            cashPerTiny = 1,
            markOnMiniMap = false,
            threshold = 1
        }
        totalRarity = 1
    end
    return materials, totalRarity
end

local function normalizeAsteroidSizeLayers(rawLayers)
    local layers = {}
    for stage, config in pairs(ASTEROID_STAGE_CONFIG) do
        layers[stage] = {
            density = 1,
            quantity = stage == 0 and TARGET_ASTEROID_COUNT or 0
        }
    end
    for _, raw in ipairs(rawLayers or {}) do
        local stage = math.max(0, math.floor(raw.stage or raw.size or 0))
        if ASTEROID_STAGE_CONFIG[stage] ~= nil then
            layers[stage] = {
                density = tonumber(raw.density) or layers[stage].density or 1,
                quantity = math.max(0, math.floor(raw.quantity or layers[stage].quantity or 0))
            }
        end
    end
    return layers
end

local ASTEROID_MATERIALS, ASTEROID_MATERIAL_RARITY_TOTAL = normalizeAsteroidMaterials(SPACE_MINER_CONFIG.asteroidMaterials)
local ASTEROID_SIZE_LAYERS <const> = normalizeAsteroidSizeLayers(SPACE_MINER_CONFIG.asteroidSizeLayers)

local UPGRADE_CATEGORY_CONFIG <const> = {
    laser = {
        screen = "laser",
        title = "Laser Upgrades",
        configKey = "laserUpgrades",
        ownedKey = "ownedLaserUpgrades",
        activeKey = "activeLaserUpgrade",
        defaultId = "standard-laser"
    },
    missile = {
        screen = "missile",
        title = "Missile Upgrades",
        configKey = "missileUpgrades",
        ownedKey = "ownedMissileUpgrades",
        activeKey = "activeMissileUpgrade",
        defaultId = "standard-unguided"
    },
    shield = {
        screen = "shield",
        title = "Shield Upgrades",
        configKey = "shieldUpgrades",
        ownedKey = "ownedShieldUpgrades",
        activeKey = "activeShieldUpgrade",
        defaultId = "standard-shields"
    },
    thruster = {
        screen = "thruster",
        title = "Thruster Upgrades",
        configKey = "thrusterUpgrades",
        ownedKey = "ownedThrusterUpgrades",
        activeKey = "activeThrusterUpgrade",
        defaultId = "standard-thrusters"
    },
    cargo = {
        screen = "cargo",
        title = "Cargo Space",
        configKey = "cargoUpgrades",
        ownedKey = "ownedCargoUpgrades",
        activeKey = "activeCargoUpgrade",
        defaultId = "cargo-50"
    }
}

local HOME_MENU_SCREENS <const> = {
    { id = "laser", label = "Laser Upgrades" },
    { id = "missile", label = "Missile Upgrades" },
    { id = "shield", label = "Shield Upgrades" },
    { id = "thruster", label = "Thruster Upgrades" },
    { id = "cargo", label = "Cargo Space" },
    { id = "settings", label = "Game Settings" }
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

local function normalizeTarget(value)
    local target = tostring(value or "player"):lower()
    if target == "base" or target == "homebase" or target == "home-base" then
        return "base"
    end
    return "player"
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
                    target = normalizeTarget(rawEntry.target or rawEntry.Target),
                    asteroidStage = math.max(0, math.floor(rawEntry.asteroidStage or rawEntry.stage or 0)),
                    heatSeeking = rawEntry.heatSeeking == true or rawEntry.homing == true,
                    timestampFrames = rawEntry.timestamp ~= nil and parseFrameCount(rawEntry.timestamp) or rawEntry.timestampFrames,
                    offsetFrames = rawEntry.offset ~= nil and parseFrameCount(rawEntry.offset) or parseFrameCount(rawEntry.offsetFrames or 0),
                    spacingFrames = (rawEntry.spacing ~= nil or rawEntry.Spacing ~= nil) and parseFrameCount(rawEntry.spacing or rawEntry.Spacing)
                        or parseFrameCount(rawEntry.spacingFrames or SPACE_MINER_CONFIG.waveEntrySpacingFrames or SPACE_MINER_CONFIG.waveEntrySpacing or "0:00:06")
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

local function normalizeCommunicationSchedule(rawMessages)
    local schedule = {}
    for index, rawMessage in ipairs(rawMessages or {}) do
        local startFrame = parseFrameCount(rawMessage.timestampFrames or rawMessage.timestamp or rawMessage.start or 0)
        local durationFrames = parseFrameCount(rawMessage.durationFrames or rawMessage.duration or "0:03:00")
        local text = rawMessage.text or rawMessage.message or ""
        local readableFrames = math.max(COMMUNICATION_MIN_FRAMES, math.floor(#text * COMMUNICATION_FRAMES_PER_CHAR))
        schedule[#schedule + 1] = {
            id = rawMessage.id or string.format("message-%d", index),
            startFrame = startFrame,
            endFrame = startFrame + math.max(1, durationFrames, readableFrames),
            text = text,
            x = rawMessage.x or 8,
            y = rawMessage.y or 8,
            width = rawMessage.width or COMMUNICATION_WIDTH
        }
    end
    table.sort(schedule, function(left, right)
        return left.startFrame < right.startFrame
    end)
    return schedule
end

local function normalizeBaseTimeline(rawTimeline)
    local timeline = {}
    for index, rawEntry in ipairs(rawTimeline or {}) do
        timeline[#timeline + 1] = {
            id = rawEntry.id or string.format("base-update-%d", index),
            frame = parseFrameCount(rawEntry.timestampFrames or rawEntry.timestamp or rawEntry.time or 0),
            name = rawEntry.name,
            healthBarEnabled = rawEntry.healthBarEnabled
        }
    end
    table.sort(timeline, function(left, right)
        return left.frame < right.frame
    end)
    return timeline
end

local function normalizeSettingsTimeline(rawTimeline)
    local timeline = {}
    for index, rawEntry in ipairs(rawTimeline or {}) do
        timeline[#timeline + 1] = {
            id = rawEntry.id or string.format("settings-update-%d", index),
            frame = parseFrameCount(rawEntry.timestampFrames or rawEntry.timestamp or rawEntry.time or 0),
            miniMapEnabled = rawEntry.miniMapEnabled
        }
    end
    table.sort(timeline, function(left, right)
        return left.frame < right.frame
    end)
    return timeline
end

local STAGE_SCHEDULE <const> = normalizeWaveSchedule(SpaceMinerWaveConfig)
local COMMUNICATION_SCHEDULE <const> = normalizeCommunicationSchedule((SpaceMinerWaveConfig and SpaceMinerWaveConfig.communications) or SPACE_MINER_CONFIG.communications)
local BASE_TIMELINE <const> = normalizeBaseTimeline(BASE_CONFIG.timeline)
local SETTINGS_TIMELINE <const> = normalizeSettingsTimeline(SpaceMinerWaveConfig and SpaceMinerWaveConfig.settingsTimeline)

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

local function steerBodyToward(body, targetX, targetY, maxSpeed, acceleration, arrivalRadius)
    local dx = targetX - body.x
    local dy = targetY - body.y
    local ux, uy, distance = unitVector(dx, dy)
    if distance <= 0.0001 then
        body.vx = body.vx * ENEMY_IDLE_DRAG
        body.vy = body.vy * ENEMY_IDLE_DRAG
        return 0, 0, distance
    end

    local arrival = arrivalRadius or ENEMY_ARRIVAL_RADIUS
    local speedScale = clamp(distance / arrival, 0.18, 1)
    local desiredVx = ux * maxSpeed * speedScale
    local desiredVy = uy * maxSpeed * speedScale
    local steerX = desiredVx - body.vx
    local steerY = desiredVy - body.vy
    local steerUx, steerUy, steerDistance = unitVector(steerX, steerY)

    body.vx = body.vx * ENEMY_IDLE_DRAG
    body.vy = body.vy * ENEMY_IDLE_DRAG
    if steerDistance > 0.0001 then
        applyAcceleration(body, steerUx * acceleration, steerUy * acceleration, maxSpeed)
    end

    return steerUx, steerUy, distance
end

function SpaceMiner.getModeLabel(modeId)
    if modeId == SpaceMiner.MODE_ENDLESS then
        return "Ore Mining"
    elseif modeId == SpaceMiner.MODE_CONTINUE then
        return "Continue Mining"
    elseif modeId == SpaceMiner.MODE_NEW_SAVE then
        return "New Save"
    end
    return "Story Mode"
end

function SpaceMiner.isCompactTurnEnabled()
    return SpaceMiner.compactTurnEnabled == true
end

function SpaceMiner.setCompactTurnEnabled(enabled)
    SpaceMiner.compactTurnEnabled = enabled == true
end

function SpaceMiner.clearStorySave()
    pcall(function()
        if pd.datastore.delete then
            pd.datastore.delete(STORY_SAVE_KEY)
        else
            pd.datastore.write({ cleared = true }, STORY_SAVE_KEY)
        end
    end)
end

function SpaceMiner:hasStorySave()
    local ok, data = pcall(function()
        return pd.datastore.read(STORY_SAVE_KEY)
    end)
    return ok and type(data) == "table" and data.cleared ~= true and type(data.player) == "table"
end

function SpaceMiner:isEndlessMode()
    return self.playMode == SpaceMiner.MODE_ENDLESS
end

function SpaceMiner:isStoryMode()
    return self.playMode == SpaceMiner.MODE_STORY
end

function SpaceMiner:applyTurnModeSetting()
    self.turnMode = SpaceMiner.isCompactTurnEnabled() and SpaceMiner.MODE_HALF or SpaceMiner.MODE_FULL
    self.turnWindow = TURN_WINDOW_DEGREES[self.turnMode] or 360
    self.turnScale = 360 / self.turnWindow
end

function SpaceMiner:positionPlayerNearBase()
    if self.preview or not self:isStoryMode() then
        return
    end
    local directions = {
        { x = 0, y = -1, angle = 90 },
        { x = 1, y = 0, angle = 180 },
        { x = 0, y = 1, angle = 270 },
        { x = -1, y = 0, angle = 0 }
    }
    local direction = directions[math.random(1, #directions)]
    local distance = BASE_SHIELD_RADIUS + 20
    self.player.x = BASE_WORLD_X + (direction.x * distance)
    self.player.y = BASE_WORLD_Y + (direction.y * distance)
    self.player.angle = direction.angle
end

function SpaceMiner.new(width, height, options)
    local self = setmetatable({}, SpaceMiner)
    options = options or {}
    self.width = width
    self.height = height
    self.preview = options.preview == true
    self.playMode = options.modeId or SpaceMiner.MODE_STORY
    self.continueRequested = self.playMode == SpaceMiner.MODE_CONTINUE and not self.preview
    if self.playMode == SpaceMiner.MODE_NEW_SAVE and not self.preview then
        SpaceMiner.clearStorySave()
        self.playMode = SpaceMiner.MODE_STORY
    elseif self.playMode == SpaceMiner.MODE_CONTINUE then
        self.playMode = SpaceMiner.MODE_STORY
    end
    self.modeId = self.playMode
    self.turnMode = SpaceMiner.MODE_FULL
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
        missiles = {},
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
    self.cash = 0
    self.minedChunks = 0
    self.cargoOre = 0
    self.cargoValue = 0
    self.cargoLoads = {}
    self.cargoUnloadFrames = 0
    self.cargoCapacity = CARGO_INITIAL_CAPACITY
    self.cargoCapacityTarget = CARGO_INITIAL_CAPACITY
    self.destroyedEnemies = 0
    self.testModeEnabled = false
    self.shieldLevel = 1
    self.playerShieldMax = SHIELD_MAX
    self.frame = 0
    self.stageIndex = 1
    self.stageFrame = 0
    self.stageStatus = "active"
    self.stageLabel = (#STAGE_SCHEDULE > 0 and STAGE_SCHEDULE[1].label) or "Open Mining"
    self.stageRuntime = nil
    self.menuOpen = false
    self.menuType = "ship"
    self.homeMenuScreen = "directory"
    self.menuIndex = 1
    self.menuInputIgnoreFrames = 0
    self.homeDirectoryIndex = 1
    self.menuOpenedAtX = 0
    self.menuOpenedAtY = 0
    self.homeMenuMessage = nil
    self.homeMenuScoutHidden = false
    self.homeMenuAutoCloseFrames = nil
    self.homeBaseVisitGreetingShown = false
    self.wasInHomeBaseShield = false
    self.wasCollidingHomeBase = false
    self.contextCommunication = nil
    self.baseCollisionCooldownFrames = 0
    self.destroyedQuoteQueue = nil
    self.destroyedQuoteIndex = 1
    self.hullRepairFrames = 0
    self.autoMissileAccumulator = 0
    self.supernovaFlashFrames = 0
    self.materialMarkerToggles = {}
    self.ownedLaserUpgrades = {}
    self.ownedMissileUpgrades = {}
    self.ownedShieldUpgrades = {}
    self.ownedThrusterUpgrades = {}
    self.ownedCargoUpgrades = {}
    self.activeLaserUpgrade = nil
    self.activeMissileUpgrade = nil
    self.activeShieldUpgrade = nil
    self.activeThrusterUpgrade = nil
    self.activeCargoUpgrade = nil
    self:initializeUpgradeState()
    self.enemySerial = 0
    self.playerShieldHits = self.playerShieldMax
    self.playerHullHits = HULL_HITS
    self.baseName = BASE_CONFIG.name or "Home Base"
    self.baseShieldHits = BASE_SHIELD_MAX
    self.baseShieldFlashFrames = 0
    self.baseFramesSinceDamage = SHIELD_RECHARGE_DELAY_FRAMES
    self.baseShieldRechargeFrames = 0
    self.baseHealthBarEnabled = BASE_CONFIG.healthBarEnabled ~= false
    self.baseTimelineIndex = 1
    self.miniMapEnabled = true
    self.settingsTimelineIndex = 1
    self.baseUnderAttackFrames = 0
    self.shieldFlashFrames = 0
    self.framesSincePlayerDamage = SHIELD_RECHARGE_DELAY_FRAMES
    self.shieldRechargeFrames = 0
    self.gameOver = false
    self.previewDriftAngle = 0
    self.previewFrameCounter = 0
    self.instructionOverlayFrames = self.preview and 0 or INSTRUCTION_OVERLAY_FRAMES
    self.dashboardStickOffset = 0
    self.dashboardShieldRatio = 1
    self.decor = {}
    self.backgroundStars = {}
    self.asteroidSerial = 0
    self.asteroidDiagnostics = nil
    self:resetAsteroidDiagnostics()
    self:resetMaterialMarkerToggles()
    self:applyTurnModeSetting()
    self:positionPlayerNearBase()
    self:seedBackgroundStars()
    self:buildBackgroundImage()
    self:buildBaseImage()
    self:seedDecor()
    self:seedAsteroids(self.preview and PREVIEW_ASTEROID_COUNT or TARGET_ASTEROID_COUNT)
    if #STAGE_SCHEDULE > 0 and not self:isEndlessMode() then
        self:beginStage(1)
    end
    if self.continueRequested then
        self:loadStorySave()
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

function SpaceMiner:getStorySaveData()
    return {
        frame = self.frame,
        stageIndex = self.stageIndex,
        stageFrame = self.stageFrame,
        stageStatus = self.stageStatus,
        stageLabel = self.stageLabel,
        stageRuntime = self.stageRuntime,
        player = {
            x = self.player.x,
            y = self.player.y,
            vx = self.player.vx,
            vy = self.player.vy,
            angle = self.player.angle
        },
        score = self.score,
        cash = self.cash,
        minedChunks = self.minedChunks,
        cargoOre = self.cargoOre,
        cargoValue = self.cargoValue,
        cargoLoads = self.cargoLoads,
        cargoCapacity = self.cargoCapacity,
        cargoCapacityTarget = self.cargoCapacityTarget,
        destroyedEnemies = self.destroyedEnemies,
        testModeEnabled = self.testModeEnabled,
        ownedLaserUpgrades = self.ownedLaserUpgrades,
        ownedMissileUpgrades = self.ownedMissileUpgrades,
        ownedShieldUpgrades = self.ownedShieldUpgrades,
        ownedThrusterUpgrades = self.ownedThrusterUpgrades,
        ownedCargoUpgrades = self.ownedCargoUpgrades,
        activeLaserUpgrade = self.activeLaserUpgrade,
        activeMissileUpgrade = self.activeMissileUpgrade,
        activeShieldUpgrade = self.activeShieldUpgrade,
        activeThrusterUpgrade = self.activeThrusterUpgrade,
        activeCargoUpgrade = self.activeCargoUpgrade,
        shieldLevel = self.shieldLevel,
        playerShieldMax = self.playerShieldMax,
        playerShieldHits = self.playerShieldHits,
        playerHullHits = self.playerHullHits,
        baseName = self.baseName,
        baseShieldHits = self.baseShieldHits,
        baseHealthBarEnabled = self.baseHealthBarEnabled,
        baseTimelineIndex = self.baseTimelineIndex,
        materialMarkerToggles = self.materialMarkerToggles
    }
end

function SpaceMiner:saveStoryState()
    if self.preview or not self:isStoryMode() then
        return
    end
    local ok, errorMessage = pcall(function()
        pd.datastore.write(self:getStorySaveData(), STORY_SAVE_KEY)
    end)
    if not ok then
        StarryLog.error("space miner save failed: %s", tostring(errorMessage))
    end
end

function SpaceMiner:loadStorySave()
    if self.preview or not self:isStoryMode() then
        return false
    end
    local ok, data = pcall(function()
        return pd.datastore.read(STORY_SAVE_KEY)
    end)
    if not ok or type(data) ~= "table" or data.cleared == true or type(data.player) ~= "table" then
        return false
    end

    self.frame = tonumber(data.frame) or self.frame
    self.stageIndex = clamp(tonumber(data.stageIndex) or self.stageIndex, 1, math.max(1, #STAGE_SCHEDULE))
    if #STAGE_SCHEDULE > 0 then
        self:beginStage(self.stageIndex)
    end
    self.stageFrame = tonumber(data.stageFrame) or self.stageFrame
    self.stageStatus = data.stageStatus or self.stageStatus
    self.stageLabel = data.stageLabel or self.stageLabel
    if type(data.stageRuntime) == "table" then
        self.stageRuntime = data.stageRuntime
    end
    if type(data.player) == "table" then
        self.player.x = tonumber(data.player.x) or self.player.x
        self.player.y = tonumber(data.player.y) or self.player.y
        self.player.vx = tonumber(data.player.vx) or 0
        self.player.vy = tonumber(data.player.vy) or 0
        self.player.angle = tonumber(data.player.angle) or self.player.angle
    end
    self.player.missiles = {}
    self.player.missile = nil
    self.score = tonumber(data.score) or self.score
    self.cash = tonumber(data.cash) or self.cash
    self.minedChunks = tonumber(data.minedChunks) or self.minedChunks
    self.cargoOre = tonumber(data.cargoOre) or self.cargoOre
    self.cargoValue = tonumber(data.cargoValue) or self.cargoValue
    if type(data.cargoLoads) == "table" then
        self.cargoLoads = data.cargoLoads
    elseif self.cargoOre > 0 then
        self.cargoLoads = {}
        local averageValue = math.floor(((self.cargoValue or 0) / self.cargoOre) + 0.5)
        for _ = 1, self.cargoOre do
            self.cargoLoads[#self.cargoLoads + 1] = averageValue
        end
    end
    self.destroyedEnemies = tonumber(data.destroyedEnemies) or self.destroyedEnemies
    self.testModeEnabled = data.testModeEnabled == true
    self:loadOwnedUpgradeState("laser", data.ownedLaserUpgrades, data.activeLaserUpgrade)
    self:loadOwnedUpgradeState("missile", data.ownedMissileUpgrades, data.activeMissileUpgrade)
    self:loadOwnedUpgradeState("shield", data.ownedShieldUpgrades, data.activeShieldUpgrade)
    self:loadOwnedUpgradeState("thruster", data.ownedThrusterUpgrades, data.activeThrusterUpgrade)
    self:loadOwnedUpgradeState("cargo", data.ownedCargoUpgrades, data.activeCargoUpgrade)
    self.cargoCapacityTarget = math.max(CARGO_INITIAL_CAPACITY, tonumber(data.cargoCapacityTarget) or self:getCargoCapacityTarget(), self:getCargoUpgradeCapacity())
    self.cargoCapacity = math.max(CARGO_INITIAL_CAPACITY, tonumber(data.cargoCapacity) or self.cargoCapacityTarget)
    self:applyShieldUpgradeLevel(tonumber(data.shieldLevel) or self.shieldLevel or 1)
    self.playerShieldMax = tonumber(data.playerShieldMax) or self.playerShieldMax
    self.playerShieldHits = tonumber(data.playerShieldHits) or self.playerShieldHits
    self.playerHullHits = tonumber(data.playerHullHits) or self.playerHullHits
    self.baseName = data.baseName or self.baseName
    self.baseShieldHits = tonumber(data.baseShieldHits) or self.baseShieldHits
    if data.baseHealthBarEnabled ~= nil then
        self.baseHealthBarEnabled = data.baseHealthBarEnabled == true
    end
    self.baseTimelineIndex = tonumber(data.baseTimelineIndex) or self.baseTimelineIndex
    if type(data.materialMarkerToggles) == "table" then
        for key, value in pairs(data.materialMarkerToggles) do
            self.materialMarkerToggles[key] = value == true
        end
    end
    return true
end

function SpaceMiner:handlePrimaryAction()
    if self.preview then
        return
    end
    if not self.gameOver then
        if self:tryAntiGravBlink() then
            return
        end
        if self:isWithinHomeMenuRange() then
            self:openHomeBaseMenu()
        else
            self:openShipMenu()
        end
        return
    end

    local width = self.width
    local height = self.height
    local modeId = self.playMode
    local fresh = SpaceMiner.new(width, height, {
        modeId = modeId,
        preview = false
    })
    for key, value in pairs(fresh) do
        self[key] = value
    end
end

function SpaceMiner:tryAntiGravBlink()
    local upgrade = self:getActiveUpgrade("thruster") or {}
    if upgrade.blinkDistance == nil then
        return false
    end

    local inputX = 0
    local inputY = 0
    if pd.buttonIsPressed(pd.kButtonLeft) then
        inputX = inputX - 1
    end
    if pd.buttonIsPressed(pd.kButtonRight) then
        inputX = inputX + 1
    end
    if pd.buttonIsPressed(pd.kButtonUp) then
        inputY = inputY - 1
    end
    if pd.buttonIsPressed(pd.kButtonDown) then
        inputY = inputY + 1
    end
    if inputX == 0 and inputY == 0 then
        return false
    end

    local ux, uy = unitVector(inputX, inputY)
    local targetX = self.player.x + (ux * upgrade.blinkDistance)
    local targetY = self.player.y + (uy * upgrade.blinkDistance)
    local landingRadius = PLAYER_RADIUS + 12
    for _, enemy in ipairs(self.enemyShips) do
        if distanceSquared(targetX, targetY, enemy.x, enemy.y) <= ((landingRadius + enemy.size) * (landingRadius + enemy.size)) then
            targetX = enemy.x - (ux * (landingRadius + enemy.size + 4))
            targetY = enemy.y - (uy * (landingRadius + enemy.size + 4))
        end
    end
    for _, asteroid in ipairs(self.asteroids) do
        if distanceSquared(targetX, targetY, asteroid.x, asteroid.y) <= ((landingRadius + asteroid.radius) * (landingRadius + asteroid.radius)) then
            targetX = asteroid.x - (ux * (landingRadius + asteroid.radius + 4))
            targetY = asteroid.y - (uy * (landingRadius + asteroid.radius + 4))
        end
    end

    self:addExplosion(self.player.x, self.player.y, 16, 8)
    self.player.x = targetX
    self.player.y = targetY
    self.player.vx = self.player.vx * 0.35
    self.player.vy = self.player.vy * 0.35
    self:addExplosion(self.player.x, self.player.y, 16, 8)
    return true
end

function SpaceMiner:isMenuOpen()
    return self.menuOpen == true
end

function SpaceMiner:isWithinHomeMenuRange()
    if not self:isStoryMode() then
        return false
    end
    local radius = math.max(HOME_BASE_MENU_RADIUS, BASE_SHIELD_RADIUS)
    return distanceSquared(self.player.x, self.player.y, BASE_WORLD_X, BASE_WORLD_Y) <= (radius * radius)
end

function SpaceMiner:openShipMenu()
    self.menuOpen = true
    self.menuType = "ship"
    self.homeMenuScreen = "directory"
    self.menuIndex = 1
    self.menuInputIgnoreFrames = 1
    self.menuOpenedAtX = self.player.x
    self.menuOpenedAtY = self.player.y
    self.homeMenuAutoCloseFrames = nil
end

function SpaceMiner:openHomeBaseMenu()
    self.menuOpen = true
    self.menuType = "home"
    self.homeMenuScreen = "directory"
    self.menuIndex = 1
    self.homeDirectoryIndex = 1
    self.menuInputIgnoreFrames = 1
    self.menuOpenedAtX = self.player.x
    self.menuOpenedAtY = self.player.y
    self.homeMenuMessage = self:getHomeBaseMenuMessage()
    self.homeMenuScoutHidden = false
    self.homeMenuAutoCloseFrames = (#self.enemyShips > 0 or #self.enemyMissiles > 0) and 120 or nil
end

function SpaceMiner:closeMenu()
    if self.menuOpen and self:isStoryMode() then
        self:saveStoryState()
    end
    self.menuOpen = false
    self.homeMenuAutoCloseFrames = nil
    self.player.laserOn = false
    self.input.laser = false
end

function SpaceMiner:getMenuItems()
    if self.menuType == "home" then
        return self:getHomeMenuItems()
    end

    local items = {
        {
            id = "trigger-next-event",
            label = "Trigger Next Event",
            value = false,
            action = "trigger-next-event"
        }
    }
    for _, material in ipairs(ASTEROID_MATERIALS) do
        items[#items + 1] = {
            id = material.id,
            label = material.label,
            value = self.materialMarkerToggles[material.id] == true
        }
    end
    return items
end

function SpaceMiner:getHomeMenuItems()
    local items = {}
    if self.homeMenuScreen == "directory" then
        for _, screen in ipairs(HOME_MENU_SCREENS) do
            items[#items + 1] = {
                id = screen.id,
                label = screen.label,
                action = "open-screen"
            }
        end
        return items
    end

    if self.homeMenuScreen == "settings" then
        return self:getShipSettingsMenuItems()
    end

    local category = self:getUpgradeCategoryForScreen(self.homeMenuScreen)
    if category == nil then
        return items
    end
    for _, upgrade in ipairs(self:getUpgradeList(category)) do
        local owned = self:isUpgradeOwned(category, upgrade.id)
        local active = self:getActiveUpgradeId(category) == upgrade.id
        local cost = upgrade.cost or 0
        items[#items + 1] = {
            id = upgrade.id,
            label = upgrade.name or upgrade.id,
            cost = cost,
            value = active,
            action = (owned or self.testModeEnabled) and "equip-upgrade" or "buy-upgrade",
            category = category,
            enabled = self.testModeEnabled or owned or (self.cash or 0) >= cost
        }
    end
    return items
end

function SpaceMiner:getShipSettingsMenuItems()
    local items = {
        {
            id = "trigger-next-event",
            label = "Trigger Next Event",
            value = false,
            action = "trigger-next-event"
        },
        {
            id = "test-mode",
            label = "Test Mode",
            value = self.testModeEnabled == true,
            action = "toggle-test-mode"
        }
    }
    for _, material in ipairs(ASTEROID_MATERIALS) do
        items[#items + 1] = {
            id = material.id,
            label = material.label,
            value = self.materialMarkerToggles[material.id] == true,
            action = "toggle-material"
        }
    end
    return items
end

function SpaceMiner:toggleMenuSelection()
    local item = self:getMenuItems()[self.menuIndex]
    if item == nil then
        return
    end
    if item.action == "open-screen" then
        self.homeDirectoryIndex = self.menuIndex
        self.homeMenuScreen = item.id
        self.menuIndex = 1
    elseif item.action == "buy-upgrade" or item.action == "equip-upgrade" then
        self:purchaseOrEquipUpgrade(item.category, item.id)
    elseif item.action == "toggle-test-mode" then
        self.testModeEnabled = not self.testModeEnabled
    elseif item.action == "trigger-next-event" then
        self:triggerNextWaveEvent()
    else
        self.materialMarkerToggles[item.id] = not self.materialMarkerToggles[item.id]
    end
end

function SpaceMiner:getUpgradeCategoryForScreen(screen)
    for category, config in pairs(UPGRADE_CATEGORY_CONFIG) do
        if config.screen == screen then
            return category
        end
    end
    return nil
end

function SpaceMiner:getUpgradeList(category)
    local config = UPGRADE_CATEGORY_CONFIG[category]
    return config and (PROGRESSION_CONFIG[config.configKey] or {}) or {}
end

function SpaceMiner:getUpgradeById(category, id)
    for _, upgrade in ipairs(self:getUpgradeList(category)) do
        if upgrade.id == id then
            return upgrade
        end
    end
    return nil
end

function SpaceMiner:getOwnedUpgradeTable(category)
    local config = UPGRADE_CATEGORY_CONFIG[category]
    return config and self[config.ownedKey] or nil
end

function SpaceMiner:getActiveUpgradeId(category)
    local config = UPGRADE_CATEGORY_CONFIG[category]
    return config and self[config.activeKey] or nil
end

function SpaceMiner:setActiveUpgradeId(category, id)
    local config = UPGRADE_CATEGORY_CONFIG[category]
    if config ~= nil then
        self[config.activeKey] = id
    end
end

function SpaceMiner:isUpgradeOwned(category, id)
    local owned = self:getOwnedUpgradeTable(category)
    return owned ~= nil and owned[id] == true
end

function SpaceMiner:initializeUpgradeState()
    for category, config in pairs(UPGRADE_CATEGORY_CONFIG) do
        local owned = self:getOwnedUpgradeTable(category)
        if owned ~= nil then
            owned[config.defaultId] = true
            self:setActiveUpgradeId(category, self:getActiveUpgradeId(category) or config.defaultId)
        end
    end
end

function SpaceMiner:loadOwnedUpgradeState(category, ownedState, activeId)
    local owned = self:getOwnedUpgradeTable(category)
    if owned == nil then
        return
    end
    if type(ownedState) == "table" then
        for id, value in pairs(ownedState) do
            owned[id] = value == true
        end
    end
    local config = UPGRADE_CATEGORY_CONFIG[category]
    owned[config.defaultId] = true
    if activeId ~= nil and owned[activeId] == true then
        self:setActiveUpgradeId(category, activeId)
    end
end

function SpaceMiner:purchaseOrEquipUpgrade(category, id)
    if category == nil or id == nil then
        return
    end
    local upgrade = self:getUpgradeById(category, id)
    local owned = self:getOwnedUpgradeTable(category)
    if upgrade == nil or owned == nil then
        return
    end
    if self.testModeEnabled then
        owned[id] = true
    elseif owned[id] ~= true then
        local cost = upgrade.cost or 0
        if (self.cash or 0) < cost then
            return
        end
        self.cash = self.cash - cost
        owned[id] = true
    end
    self:setActiveUpgradeId(category, id)
end

function SpaceMiner:getActiveUpgrade(category)
    return self:getUpgradeById(category, self:getActiveUpgradeId(category)) or self:getUpgradeById(category, UPGRADE_CATEGORY_CONFIG[category].defaultId)
end

function SpaceMiner:applyShieldUpgradeLevel(level)
    self.shieldLevel = level
    self.playerShieldMax = SHIELD_MAX
    self.playerShieldHits = math.min(self.playerShieldHits or self.playerShieldMax, self.playerShieldMax)
end

function SpaceMiner:updateMenuInput(upPressed, downPressed, leftPressed, rightPressed, aPressed)
    if not self.menuOpen then
        return
    end
    if (self.menuInputIgnoreFrames or 0) > 0 then
        self.menuInputIgnoreFrames = self.menuInputIgnoreFrames - 1
        return
    end
    if self.homeMenuAutoCloseFrames ~= nil then
        self.homeMenuAutoCloseFrames = self.homeMenuAutoCloseFrames - 1
        if self.homeMenuAutoCloseFrames <= 0 then
            self:closeMenu()
            return
        end
    end
    local itemCount = #self:getMenuItems()
    if itemCount <= 0 then
        return
    end
    if upPressed then
        self.menuIndex = self.menuIndex - 1
        if self.menuIndex < 1 then
            self.menuIndex = itemCount
        end
    elseif downPressed then
        self.menuIndex = self.menuIndex + 1
        if self.menuIndex > itemCount then
            self.menuIndex = 1
        end
    elseif leftPressed and self.menuType == "home" and self.homeMenuScreen ~= "directory" then
        self.homeMenuScreen = "directory"
        self.menuIndex = self.homeDirectoryIndex or 1
    elseif leftPressed or rightPressed or aPressed then
        if aPressed and self.menuType == "home" then
            self.homeMenuScoutHidden = true
        end
        self:toggleMenuSelection()
    end
end

function SpaceMiner:getHomeBaseMenuMessage()
    if #self.enemyShips > 0 or #self.enemyMissiles > 0 then
        return BASE_CONFIG.homeBaseEnemyAround or "Scout: Get back out there!"
    end

    local hullRatio = clamp((self.playerHullHits or HULL_HITS) / HULL_HITS, 0, 1)
    if hullRatio < 0.10 then
        return BASE_CONFIG.homeBaseCriticalHealth or "Scout: How are you still alive?"
    elseif hullRatio < 0.50 then
        return BASE_CONFIG.homeBaseBelowHalfHealth or "Scout: That damage isn't cheap."
    elseif hullRatio < 1 then
        return BASE_CONFIG.homeBaseAboveHalfHealth or "Scout: You're paying for that, right?"
    end

    if self.homeBaseVisitGreetingShown then
        return self.baseName or "Home Base"
    end
    self.homeBaseVisitGreetingShown = true
    local greetings = BASE_CONFIG.homeBaseGreetings or {}
    if #greetings > 0 then
        return greetings[math.random(1, #greetings)]
    end
    return "Scout: Welcome home."
end

function SpaceMiner:updateHomeBaseVisitState()
    if not self:isStoryMode() then
        return
    end
    local enterRadius = BASE_SHIELD_RADIUS
    local exitRadius = BASE_SHIELD_RADIUS + 10
    local distanceSq = distanceSquared(self.player.x, self.player.y, BASE_WORLD_X, BASE_WORLD_Y)
    local inside = self.wasInHomeBaseShield
        and distanceSq <= (exitRadius * exitRadius)
        or distanceSq <= (enterRadius * enterRadius)
    if not inside and self.wasInHomeBaseShield then
        self.homeBaseVisitGreetingShown = false
    end
    self.wasInHomeBaseShield = inside
end

function SpaceMiner:updateMenuAutoNavigate()
    if not self.menuOpen or not MENU_AUTO_NAVIGATE_ENABLED or self.gameOver then
        return
    end

    local steerX = 0
    local steerY = 0
    for _, enemy in ipairs(self.enemyShips) do
        local dx = self.player.x - enemy.x
        local dy = self.player.y - enemy.y
        local ux, uy, distance = unitVector(dx, dy)
        if distance < 95 then
            local strength = 1 - clamp(distance / 95, 0, 1)
            steerX = steerX + ux * strength
            steerY = steerY + uy * strength
        end
    end
    for _, missile in ipairs(self.enemyMissiles) do
        local dx = self.player.x - missile.x
        local dy = self.player.y - missile.y
        local ux, uy, distance = unitVector(dx, dy)
        if distance < 80 then
            local strength = 1 - clamp(distance / 80, 0, 1)
            steerX = steerX + ux * strength * 1.35
            steerY = steerY + uy * strength * 1.35
        end
    end

    local homeX = self.menuOpenedAtX or self.player.x
    local homeY = self.menuOpenedAtY or self.player.y
    local dxHome = homeX - self.player.x
    local dyHome = homeY - self.player.y
    local homeUx, homeUy, homeDistance = unitVector(dxHome, dyHome)
    if homeDistance > MENU_AUTO_NAVIGATE_RADIUS then
        steerX = steerX + homeUx * 2
        steerY = steerY + homeUy * 2
    elseif homeDistance > MENU_AUTO_NAVIGATE_RADIUS * 0.55 then
        steerX = steerX + homeUx * 0.55
        steerY = steerY + homeUy * 0.55
    end

    if math.abs(steerX) > 0.0001 or math.abs(steerY) > 0.0001 then
        local ux, uy = unitVector(steerX, steerY)
        applyAcceleration(self.player, ux * MENU_AUTO_NAVIGATE_ACCELERATION, uy * MENU_AUTO_NAVIGATE_ACCELERATION, MENU_AUTO_NAVIGATE_MAX_SPEED)
    else
        self.player.vx = self.player.vx * 0.96
        self.player.vy = self.player.vy * 0.96
    end
end

function SpaceMiner:dismissInstructionOverlay()
    self.instructionOverlayFrames = 0
end

function SpaceMiner:noteInteraction()
    if self.preview then
        return
    end
    self:dismissInstructionOverlay()
end

function SpaceMiner:resetMaterialMarkerToggles()
    self.materialMarkerToggles = {}
    for _, material in ipairs(ASTEROID_MATERIALS) do
        self.materialMarkerToggles[material.id] = material.markOnMiniMap == true
    end
end

function SpaceMiner:chooseAsteroidMaterial()
    local roll = math.random() * ASTEROID_MATERIAL_RARITY_TOTAL
    for _, material in ipairs(ASTEROID_MATERIALS) do
        if roll <= material.threshold then
            return material
        end
    end
    return ASTEROID_MATERIALS[#ASTEROID_MATERIALS]
end

function SpaceMiner:getAsteroidLayerConfig(stage)
    return ASTEROID_SIZE_LAYERS[stage] or { density = 1, quantity = 0 }
end

function SpaceMiner:getAsteroidCashValue(asteroid)
    local material = asteroid.material or ASTEROID_MATERIALS[1]
    local tinyScale = 2 ^ math.max(0, 3 - (asteroid.stage or 3))
    return math.max(0, math.floor((material.cashPerTiny or 1) * tinyScale))
end

function SpaceMiner:getCargoCapacityTarget()
    local oreStep = math.max(1, CARGO_CAPACITY_ORE_STEP)
    local upgradeCount = math.floor((self.minedChunks or 0) / oreStep)
    return math.max(self:getCargoUpgradeCapacity(), CARGO_INITIAL_CAPACITY + (upgradeCount * CARGO_CAPACITY_INCREASE))
end

function SpaceMiner:getCargoUpgradeCapacity()
    local upgrade = self:getActiveUpgrade("cargo") or {}
    return upgrade.capacity or CARGO_INITIAL_CAPACITY
end

function SpaceMiner:isCargoFull()
    return (self.cargoOre or 0) >= math.floor((self.cargoCapacity or CARGO_INITIAL_CAPACITY) + 0.0001)
end

function SpaceMiner:addCargoFromAsteroid(asteroid)
    if self:isCargoFull() then
        return false
    end

    self.cargoOre = math.min(self.cargoOre + 1, math.floor(self.cargoCapacity or CARGO_INITIAL_CAPACITY))
    local cargoCashValue = self:getAsteroidCashValue(asteroid)
    self.cargoValue = (self.cargoValue or 0) + cargoCashValue
    self.cargoLoads[#self.cargoLoads + 1] = cargoCashValue
    self.minedChunks = self.minedChunks + 1
    self.cargoCapacityTarget = self:getCargoCapacityTarget()
    return true
end

function SpaceMiner:isWithinHomeBaseServiceRange()
    return self:isStoryMode()
        and distanceSquared(self.player.x, self.player.y, BASE_WORLD_X, BASE_WORLD_Y) <= (BASE_SHIELD_RADIUS * BASE_SHIELD_RADIUS)
end

function SpaceMiner:updateCargo()
    local targetCapacity = self:getCargoCapacityTarget()
    self.cargoCapacityTarget = math.max(self.cargoCapacityTarget or CARGO_INITIAL_CAPACITY, targetCapacity)
    if (self.cargoCapacity or CARGO_INITIAL_CAPACITY) < self.cargoCapacityTarget then
        self.cargoCapacity = math.min(self.cargoCapacityTarget, self.cargoCapacity + CARGO_CAPACITY_GROW_RATE)
    end

    if not self:isWithinHomeBaseServiceRange() or (self.cargoOre or 0) <= 0 then
        self.cargoUnloadFrames = 0
        return
    end

    self.cargoUnloadFrames = (self.cargoUnloadFrames or 0) + 1
    if self.cargoUnloadFrames >= CARGO_UNLOAD_STEP_FRAMES then
        self.cargoUnloadFrames = 0
        local loadValue = table.remove(self.cargoLoads, 1) or 0
        self.cargoOre = math.max(0, self.cargoOre - 1)
        self.cargoValue = math.max(0, (self.cargoValue or 0) - loadValue)
        self.cash = (self.cash or 0) + loadValue
    end
end

function SpaceMiner:updateHomeBaseRepairs()
    if not self:isWithinHomeBaseServiceRange() or self.gameOver then
        self.hullRepairFrames = 0
        return
    end

    if (self.playerShieldHits or 0) < (self.playerShieldMax or SHIELD_MAX) then
        local shieldPerFrame = ((self.playerShieldMax or SHIELD_MAX) * SHIP_REPAIR_SHIELD_PER_SECOND) / 30
        self.playerShieldHits = math.min(self.playerShieldMax or SHIELD_MAX, (self.playerShieldHits or 0) + shieldPerFrame)
    end

    if (self.playerHullHits or 0) < HULL_HITS then
        self.hullRepairFrames = (self.hullRepairFrames or 0) + 1
        if self.hullRepairFrames >= SHIP_REPAIR_HULL_STEP_FRAMES then
            self.hullRepairFrames = 0
            self.playerHullHits = math.min(HULL_HITS, (self.playerHullHits or 0) + 1)
        end
    else
        self.hullRepairFrames = 0
    end
end

function SpaceMiner:isRepairBeamActive()
    return self:isWithinHomeBaseServiceRange()
        and ((self.playerShieldHits or 0) < (self.playerShieldMax or SHIELD_MAX) or (self.playerHullHits or 0) < HULL_HITS)
end

function SpaceMiner:getLaserDamagePerFrame()
    local upgrade = self:getActiveUpgrade("laser") or {}
    local baseDps = LASER_DAMAGE * 30
    return (baseDps + (upgrade.dpsBonus or 0)) / 30
end

function SpaceMiner:getLaserEnemyPenetrationLimit()
    local upgrade = self:getActiveUpgrade("laser") or {}
    return upgrade.maxEnemyHits or LASER_ENEMY_PENETRATION_LIMIT
end

function SpaceMiner:getMissileDamage()
    local upgrade = self:getActiveUpgrade("missile") or {}
    return MISSILE_DAMAGE + (upgrade.damageBonus or 0)
end

function SpaceMiner:getShieldDamageReduction()
    local upgrade = self:getActiveUpgrade("shield") or {}
    return clamp(upgrade.damageReduction or 0, 0, 0.9)
end

function SpaceMiner:getThrusterAccelerationMultiplier()
    local upgrade = self:getActiveUpgrade("thruster") or {}
    return 1 + (upgrade.accelerationBonus or 0)
end

function SpaceMiner:getThrusterHandlingMultiplier()
    local upgrade = self:getActiveUpgrade("thruster") or {}
    return 1 + (upgrade.handlingBonus or 0)
end

function SpaceMiner:seedAsteroids(targetCount)
    if SPACE_MINER_CONFIG.asteroidSizeLayers ~= nil then
        local counts = {}
        for _, asteroid in ipairs(self.asteroids) do
            counts[asteroid.stage] = (counts[asteroid.stage] or 0) + 1
        end
        for stage, layerConfig in pairs(ASTEROID_SIZE_LAYERS) do
            while (counts[stage] or 0) < (layerConfig.quantity or 0) do
                self:spawnAsteroid(stage, nil, nil)
                counts[stage] = (counts[stage] or 0) + 1
            end
        end
    else
        while #self.asteroids < targetCount do
            self:spawnAsteroid(0, nil, nil)
        end
    end
end

function SpaceMiner:randomDecorKind()
    local roll = math.random()
    if roll <= 0.58 then
        return "dot"
    elseif roll <= 0.76 then
        return "cross"
    elseif roll <= 0.92 then
        return "square"
    else
        return "shard"
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

    if kind == "cross" then
        item.radius = 1
    elseif kind == "square" then
        item.radius = 1
    elseif kind == "shard" then
        item.radius = math.random(2, 4)
        item.angle = math.random() * math.pi * 2
    else
        item.radius = 0
    end

    self.decor[#self.decor + 1] = item
end

function SpaceMiner:seedBackgroundStars()
    self.backgroundStars = {}
    if BACKGROUND_STARS_ENABLED then
        for _ = 1, BACKGROUND_STAR_COUNT do
            self.backgroundStars[#self.backgroundStars + 1] = {
                kind = "star",
                x = math.random(0, SCREEN_WIDTH - 1),
                y = math.random(0, DASHBOARD_Y - 1),
                bright = math.random() < 0.18
            }
        end
    end
    if BACKGROUND_GALAXY_ENABLED then
        for _ = 1, BACKGROUND_GALAXY_STAR_COUNT do
            local along = (math.random() - 0.5) * SCREEN_WIDTH * 1.15
            local band = (math.random() - 0.5) * 56
            local rotatedX = (along * 0.7071) + (band * 0.7071)
            local rotatedY = (-along * 0.7071) + (band * 0.7071)
            self.backgroundStars[#self.backgroundStars + 1] = {
                kind = "galaxy",
                x = CENTER_X + rotatedX,
                y = (DASHBOARD_Y * 0.5) + rotatedY + (math.sin(along * 0.03) * 18),
                bright = math.random() < 0.28
            }
        end
    end
end

function SpaceMiner:buildBackgroundImage()
    self.backgroundImage = nil
    if #self.backgroundStars == 0 then
        return
    end

    local image = gfx.image.new(SCREEN_WIDTH, DASHBOARD_Y, gfx.kColorClear)
    gfx.pushContext(image)
    gfx.setColor(gfx.kColorWhite)
    for _, star in ipairs(self.backgroundStars) do
        local drawX, drawY = star.x, star.y
        if drawX >= -4 and drawX <= SCREEN_WIDTH + 4 and drawY >= -4 and drawY <= DASHBOARD_Y + 4 then
            if star.kind == "galaxy" then
                if star.bright then
                    gfx.fillRect(drawX, drawY, 2, 1)
                else
                    gfx.fillRect(drawX, drawY, 1, 1)
                end
            elseif star.bright then
                gfx.drawLine(drawX - 1, drawY, drawX + 1, drawY)
                gfx.drawLine(drawX, drawY - 1, drawX, drawY + 1)
            else
                gfx.fillRect(drawX, drawY, 1, 1)
            end
        end
    end
    gfx.popContext()
    self.backgroundImage = image
end

function SpaceMiner:buildBaseImage()
    self.baseImage = nil
    if BASE_CONFIG.shapeMode ~= "international-space-station" then
        return
    end

    local image = gfx.image.new(82, 44, gfx.kColorClear)
    gfx.pushContext(image)
    gfx.setColor(gfx.kColorWhite)
    local cx, cy = 41, 22
    gfx.drawLine(cx - 36, cy, cx + 36, cy)
    gfx.drawLine(cx - 8, cy - 9, cx + 8, cy + 9)
    gfx.drawCircleAtPoint(cx - 7, cy, 5)
    gfx.drawCircleAtPoint(cx + 4, cy, 7)
    gfx.drawRect(cx + 10, cy - 4, 11, 8)
    gfx.drawRect(cx - 22, cy - 4, 10, 8)
    gfx.drawRect(cx - 38, cy - 12, 16, 8)
    gfx.drawRect(cx - 38, cy + 4, 16, 8)
    gfx.drawRect(cx + 22, cy - 12, 16, 8)
    gfx.drawRect(cx + 22, cy + 4, 16, 8)
    for offset = -34, 30, 8 do
        gfx.drawLine(cx + offset, cy - 12, cx + offset, cy - 4)
        gfx.drawLine(cx + offset, cy + 4, cx + offset, cy + 12)
    end
    gfx.popContext()
    self.baseImage = image
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

function SpaceMiner:generateAsteroidBlotches(stage, radius)
    if stage ~= 1 or not MEDIUM_ASTEROID_TEXTURE_ENABLED then
        return nil
    end

    local blotches = {}
    local minCount = math.max(0, MEDIUM_ASTEROID_BLOTCH_COUNT_MIN)
    local maxCount = math.max(minCount, MEDIUM_ASTEROID_BLOTCH_COUNT_MAX)
    local count = math.random(minCount, maxCount)
    for _ = 1, count do
        local angle = math.random() * math.pi * 2
        local distance = math.random() * radius * 0.62
        blotches[#blotches + 1] = {
            x = math.cos(angle) * distance,
            y = math.sin(angle) * distance,
            radius = math.random(MEDIUM_ASTEROID_BLOTCH_RADIUS_MIN, MEDIUM_ASTEROID_BLOTCH_RADIUS_MAX)
        }
    end
    return blotches
end

function SpaceMiner:spawnAsteroid(stage, originX, originY)
    local config = ASTEROID_STAGE_CONFIG[stage] or ASTEROID_STAGE_CONFIG[0]
    local layerConfig = self:getAsteroidLayerConfig(stage)
    local material = self:chooseAsteroidMaterial()
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
        layer = math.random(1, 5),
        material = material,
        radius = config.radius,
        hp = math.max(1, math.floor((config.hp * (layerConfig.density or 1)) + 0.5)),
        blotches = self:generateAsteroidBlotches(stage, config.radius),
        ageFrames = 0,
        lastVisibleFrame = -99999
    }, "spawn")
end

function SpaceMiner:getWaveSpawnPoint(entryDegrees, minDistance, maxDistance)
    local angle = entryDegrees ~= nil and screenDegreesToRadians(entryDegrees) or (math.random() * math.pi * 2)
    local distance = (minDistance or 280) + math.random(0, math.max(0, (maxDistance or 460) - (minDistance or 280)))
    return self.player.x + (math.cos(angle) * distance),
        self.player.y + (math.sin(angle) * distance),
        angle,
        distance
end

function SpaceMiner:spawnWaveAsteroid(entry)
    local x, y = self:getWaveSpawnPoint(entry.entryDegrees, ASTEROID_SAFE_RADIUS + 40, ASTEROID_SAFE_RADIUS + 220)
    self:spawnAsteroid(entry.asteroidStage or 0, x, y)
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
        local layerConfig = self:getAsteroidLayerConfig(nextStage)
        self:addAsteroid({
            x = asteroid.x + math.cos(angle) * nextConfig.radius,
            y = asteroid.y + math.sin(angle) * nextConfig.radius,
            vx = asteroid.vx * 0.55 + math.cos(angle) * speed,
            vy = asteroid.vy * 0.55 + math.sin(angle) * speed,
            stage = nextStage,
            layer = math.random(1, 5),
            material = asteroid.material or self:chooseAsteroidMaterial(),
            radius = nextConfig.radius,
            hp = math.max(1, math.floor((nextConfig.hp * (layerConfig.density or 1)) + 0.5)),
            blotches = self:generateAsteroidBlotches(nextStage, nextConfig.radius),
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

function SpaceMiner:getShieldDamageForReason(reason)
    local reduction = self:getShieldDamageReduction()
    local damage
    if reason == "asteroid" then
        damage = ASTEROID_SHIELD_DAMAGE
    else
        damage = ENEMY_SHIELD_DAMAGE
    end
    return math.max(1, math.floor((damage * (1 - reduction)) + 0.5))
end

function SpaceMiner:damagePlayer(reason)
    if self.shieldFlashFrames > 0 then
        return
    end

    if self.playerShieldHits > 0 then
        self.playerShieldHits = math.max(0, self.playerShieldHits - self:getShieldDamageForReason(reason))
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
        self.input.thrust = 0
        self.input.reverse = 0
        self.input.laser = false
        self.player.laserOn = false
        self.player.pendingMissileTrigger = false
        self.player.missile = nil
        self.player.missiles = {}
        self.player.vx = 0
        self.player.vy = 0
        self:startDestroyedCommunications()
    end
end

function SpaceMiner:updateShieldRecharge()
    if self.preview or self.gameOver then
        return
    end

    self.framesSincePlayerDamage = self.framesSincePlayerDamage + 1
    local shieldMax = self.playerShieldMax or SHIELD_MAX
    if self.playerShieldHits >= shieldMax or self.framesSincePlayerDamage < SHIELD_RECHARGE_DELAY_FRAMES then
        self.shieldRechargeFrames = 0
        return
    end

    self.shieldRechargeFrames = self.shieldRechargeFrames + 1
    if self.shieldRechargeFrames >= SHIELD_RECHARGE_STEP_FRAMES then
        self.playerShieldHits = math.min(shieldMax, self.playerShieldHits + SHIELD_RECHARGE_AMOUNT)
        self.shieldRechargeFrames = 0
    end
end

function SpaceMiner:getTargetPosition(target)
    if normalizeTarget(target) == "base" then
        return BASE_WORLD_X, BASE_WORLD_Y
    end
    return self.player.x, self.player.y
end

function SpaceMiner:getTargetVelocity(target)
    if normalizeTarget(target) == "base" then
        return 0, 0
    end
    return self.player.vx, self.player.vy
end

function SpaceMiner:isEnemyNearBase()
    local radiusSq = BASE_SHIELD_ENEMY_KEEP_ALIVE_RADIUS * BASE_SHIELD_ENEMY_KEEP_ALIVE_RADIUS
    for _, enemy in ipairs(self.enemyShips) do
        if distanceSquared(enemy.x, enemy.y, BASE_WORLD_X, BASE_WORLD_Y) <= radiusSq then
            return true
        end
    end
    for _, missile in ipairs(self.enemyMissiles) do
        if distanceSquared(missile.x, missile.y, BASE_WORLD_X, BASE_WORLD_Y) <= radiusSq then
            return true
        end
    end
    return false
end

function SpaceMiner:isBaseShieldActive()
    if (self.baseShieldHits or 0) <= 0 then
        return false
    end
    local playerDocked = distanceSquared(self.player.x, self.player.y, BASE_WORLD_X, BASE_WORLD_Y) <= (BASE_SHIELD_PLAYER_DOCK_SUPPRESS_RADIUS * BASE_SHIELD_PLAYER_DOCK_SUPPRESS_RADIUS)
    return not playerDocked or self:isEnemyNearBase()
end

function SpaceMiner:damageBase(reason)
    if self.baseShieldFlashFrames > 0 then
        return
    end
    local damage = BASE_SHIELD_DAMAGE
    if reason == "asteroid" then
        damage = BASE_SHIELD_ASTEROID_DAMAGE
    elseif reason == "enemy-missile" then
        damage = BASE_SHIELD_ENEMY_WEAPON_DAMAGE
    elseif reason == "enemy-ship" then
        damage = BASE_SHIELD_ENEMY_SHIP_DAMAGE
    end
    self.baseShieldHits = math.max(0, (self.baseShieldHits or BASE_SHIELD_MAX) - damage)
    self.baseShieldFlashFrames = SHIELD_FLASH_FRAMES
    if reason ~= "asteroid" then
        self.baseUnderAttackFrames = 45
    end
    self.baseFramesSinceDamage = 0
    self.baseShieldRechargeFrames = 0
    self:addExplosion(BASE_WORLD_X, BASE_WORLD_Y, 18, 10)
    StarryLog.info("miner base hit reason=%s shield=%d", tostring(reason), self.baseShieldHits)
end

function SpaceMiner:updateBaseShieldRecharge()
    if self.preview then
        return
    end
    if self.baseShieldFlashFrames > 0 then
        self.baseShieldFlashFrames = self.baseShieldFlashFrames - 1
    end
    self.baseFramesSinceDamage = self.baseFramesSinceDamage + 1
    if self.baseShieldHits >= BASE_SHIELD_MAX or self.baseFramesSinceDamage < SHIELD_RECHARGE_DELAY_FRAMES then
        self.baseShieldRechargeFrames = 0
        return
    end
    self.baseShieldRechargeFrames = self.baseShieldRechargeFrames + 1
    if self.baseShieldRechargeFrames >= SHIELD_RECHARGE_STEP_FRAMES then
        self.baseShieldHits = math.min(BASE_SHIELD_MAX, self.baseShieldHits + SHIELD_RECHARGE_AMOUNT)
        self.baseShieldRechargeFrames = 0
    end
end

function SpaceMiner:updateBaseTimeline()
    while self.baseTimelineIndex <= #BASE_TIMELINE do
        local entry = BASE_TIMELINE[self.baseTimelineIndex]
        if entry.frame > self.frame then
            break
        end
        if entry.name ~= nil then
            self.baseName = entry.name
        end
        if entry.healthBarEnabled ~= nil then
            self.baseHealthBarEnabled = entry.healthBarEnabled == true
        end
        self.baseTimelineIndex = self.baseTimelineIndex + 1
    end
end

function SpaceMiner:updateSettingsTimeline()
    while self.settingsTimelineIndex <= #SETTINGS_TIMELINE do
        local entry = SETTINGS_TIMELINE[self.settingsTimelineIndex]
        if entry.frame > self.frame then
            break
        end
        if entry.miniMapEnabled ~= nil then
            self.miniMapEnabled = entry.miniMapEnabled == true
        end
        self.settingsTimelineIndex = self.settingsTimelineIndex + 1
    end
end

function SpaceMiner:getEnemyStats(enemyType)
    local configured = ENEMY_TYPE_CONFIG[enemyType] or {}
    local defaults = {
        health = 4,
        acceleration = ENEMY_BASE_ACCELERATION,
        maxSpeed = ENEMY_MAX_SPEED,
        size = 7,
        avoidAsteroids = true,
        missileCooldown = STRIKER_MISSILE_COOLDOWN
    }
    if enemyType == "escaper" then
        defaults.health = 5
        defaults.acceleration = ENEMY_ESCAPER_ACCELERATION
        defaults.maxSpeed = ENEMY_MAX_SPEED + 0.35
        defaults.size = 6
    elseif enemyType == "striker" then
        defaults.health = 4
        defaults.acceleration = ENEMY_STRIKER_ACCELERATION
        defaults.maxSpeed = ENEMY_MAX_SPEED + 0.9
        defaults.size = 5
    end
    return {
        health = configured.health or configured.hp or defaults.health,
        acceleration = configured.acceleration or defaults.acceleration,
        maxSpeed = configured.maxSpeed or defaults.maxSpeed,
        size = configured.size or defaults.size,
        avoidAsteroids = configured.avoidAsteroids ~= false,
        missileCooldown = configured.missileCooldown or defaults.missileCooldown
    }
end

function SpaceMiner:spawnEnemy(enemyType, entryDegrees, target)
    self.enemySerial = self.enemySerial + 1
    local minDistance = enemyType == "escaper" and ESCAPER_LINGER_TARGET_RADIUS or 340
    local maxDistance = enemyType == "escaper" and (ESCAPER_LINGER_TARGET_RADIUS + 34) or 460
    local x, y, angle = self:getWaveSpawnPoint(entryDegrees, minDistance, maxDistance)
    local stats = self:getEnemyStats(enemyType)

    self.enemyShips[#self.enemyShips + 1] = {
        id = self.enemySerial,
        type = enemyType,
        target = normalizeTarget(target),
        x = x,
        y = y,
        vx = 0,
        vy = 0,
        angle = math.deg(angle + math.pi),
        hp = stats.health,
        size = stats.size,
        acceleration = stats.acceleration,
        maxSpeed = stats.maxSpeed,
        avoidAsteroids = stats.avoidAsteroids,
        missileCooldown = stats.missileCooldown + math.random(0, 40)
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

function SpaceMiner:startSupernovaFlash()
    self.supernovaFlashFrames = 24
end

function SpaceMiner:advanceStage()
    if self.stageIndex < #STAGE_SCHEDULE then
        self:beginStage(self.stageIndex + 1)
        self:saveStoryState()
    else
        self:beginStage(1)
        self:startSupernovaFlash()
        self:saveStoryState()
    end
end

function SpaceMiner:triggerNextWaveEvent()
    if self.preview or self:isEndlessMode() or #STAGE_SCHEDULE == 0 then
        return
    end
    local stage = self:getCurrentStage()
    if stage ~= nil and stage.kind == "wave" then
        local runtime = self.stageRuntime
        if runtime ~= nil then
            runtime.alertStarted = true
            runtime.alertStartFrame = self.frame - ALERT_TOTAL_FRAMES
            runtime.waveStartFrame = self.frame
            self.stageFrame = math.max(self.stageFrame, stage.trigger and (stage.trigger.delayFrames or 0) or 0)
        end
        return
    end
    for offset = 1, #STAGE_SCHEDULE do
        local index = ((self.stageIndex - 1 + offset) % #STAGE_SCHEDULE) + 1
        if STAGE_SCHEDULE[index].kind == "wave" then
            if index <= self.stageIndex then
                self:startSupernovaFlash()
            end
            self:beginStage(index)
            local runtime = self.stageRuntime
            if runtime ~= nil then
                runtime.alertStarted = true
                runtime.alertStartFrame = self.frame - ALERT_TOTAL_FRAMES
                runtime.waveStartFrame = self.frame
            end
            self:saveStoryState()
            return
        end
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
    if self:isEndlessMode() then
        return nil
    end

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

function SpaceMiner:getActiveCommunication()
    if self:isEndlessMode() then
        return nil
    end
    if self.menuOpen and self.menuType == "home" then
        return nil
    end

    if self.contextCommunication ~= nil then
        if self.frame < self.contextCommunication.endFrame then
            return self.contextCommunication
        end
        self.contextCommunication = nil
    end

    if (self.baseUnderAttackFrames or 0) > 0 then
        return {
            id = "base-under-attack",
            startFrame = self.frame - 1,
            endFrame = self.frame + self.baseUnderAttackFrames,
            text = SPACE_MINER_CONFIG.baseUnderAttackMessage or "Base under attack",
            x = 8,
            y = 8,
            width = COMMUNICATION_WIDTH,
            urgent = true
        }
    end

    for _, message in ipairs(COMMUNICATION_SCHEDULE) do
        if self.frame >= message.startFrame and self.frame < message.endFrame then
            return message
        end
    end
    return nil
end

function SpaceMiner:hasScheduledOrUrgentCommunication()
    if (self.baseUnderAttackFrames or 0) > 0 then
        return true
    end
    for _, message in ipairs(COMMUNICATION_SCHEDULE) do
        if self.frame >= message.startFrame and self.frame < message.endFrame then
            return true
        end
    end
    return false
end

function SpaceMiner:startContextCommunication(id, text, durationFrames)
    if text == nil or text == "" then
        return
    end
    local readableFrames = math.max(COMMUNICATION_MIN_FRAMES, math.floor(#text * COMMUNICATION_FRAMES_PER_CHAR))
    self.contextCommunication = {
        id = id,
        startFrame = self.frame,
        endFrame = self.frame + math.max(durationFrames or 120, readableFrames),
        text = text,
        x = 8,
        y = 8,
        width = COMMUNICATION_WIDTH
    }
end

function SpaceMiner:updateBaseCollisionCommunication()
    if self.preview or not self:isStoryMode() or self.gameOver then
        return
    end
    if (self.baseCollisionCooldownFrames or 0) > 0 then
        self.baseCollisionCooldownFrames = self.baseCollisionCooldownFrames - 1
    end
    local collisionRadius = PLAYER_RADIUS + 22
    local colliding = distanceSquared(self.player.x, self.player.y, BASE_WORLD_X, BASE_WORLD_Y) <= (collisionRadius * collisionRadius)
    if not colliding then
        self.wasCollidingHomeBase = false
        return
    end
    if self.wasCollidingHomeBase or (self.baseCollisionCooldownFrames or 0) > 0 then
        return
    end
    self.wasCollidingHomeBase = true
    if self.contextCommunication ~= nil or self:hasScheduledOrUrgentCommunication() then
        return
    end
    local quotes = BASE_CONFIG.baseCollisionContext or BASE_CONFIG["base-collision-context"] or {}
    if #quotes <= 0 then
        return
    end
    self:startContextCommunication("base-collision-context", quotes[math.random(1, #quotes)], 105)
    self.baseCollisionCooldownFrames = 180
end

function SpaceMiner:startDestroyedCommunications()
    local quotes = BASE_CONFIG.destroyedPcQuotes or BASE_CONFIG["destroyed-pc-quotes"] or {}
    self.destroyedQuoteQueue = quotes
    self.destroyedQuoteIndex = 1
    self.contextCommunication = nil
end

function SpaceMiner:updateDestroyedCommunications()
    if not self.gameOver or self.destroyedQuoteQueue == nil then
        return
    end
    if self.contextCommunication ~= nil and self.frame < self.contextCommunication.endFrame then
        return
    end
    if self.contextCommunication ~= nil and self.frame >= self.contextCommunication.endFrame then
        self.contextCommunication = nil
    end
    if self.destroyedQuoteIndex > #self.destroyedQuoteQueue then
        return
    end
    local text = self.destroyedQuoteQueue[self.destroyedQuoteIndex]
    self.destroyedQuoteIndex = self.destroyedQuoteIndex + 1
    self:startContextCommunication("destroyed-pc-quote", text, 120)
end

function SpaceMiner:getCommunicationFade(message)
    local fadeFrames = 15
    return clamp((message.endFrame - self.frame) / fadeFrames, 0, 1)
end

function SpaceMiner:spawnWaveEntity(entry, spawnIndex)
    local oppositeDegrees = normalizeAngle(entry.entryDegrees + 180)
    local spawnDegrees = ((spawnIndex % 2) == 1) and entry.entryDegrees or oppositeDegrees
    local entityType = string.lower(tostring(entry.entityType or "seeker"))
    if entityType == "asteroid" or entityType == "asteroids" or entityType == "astroid" or entityType == "astroids" then
        local asteroidEntry = {
            entryDegrees = spawnDegrees,
            asteroidStage = entry.asteroidStage
        }
        self:spawnWaveAsteroid(asteroidEntry)
    elseif entityType == "enemymissile" or entityType == "enemy-missile" or entityType == "missile" then
        self:spawnWaveEnemyMissile(spawnDegrees, false, entry.target)
    elseif entityType == "heatseekingenemymissile"
        or entityType == "heat-seeking-enemy-missile"
        or entityType == "heatseekingmissile"
        or entityType == "homingmissile"
        or entityType == "homing-missile" then
        self:spawnWaveEnemyMissile(spawnDegrees, true, entry.target)
    else
        self:spawnEnemy(entry.entityType, spawnDegrees, entry.target)
    end
end

function SpaceMiner:stageEntriesFullySpawned(stage)
    local runtime = self.stageRuntime
    if runtime == nil then
        return false
    end

    for _, entry in ipairs(stage.entries or {}) do
        if (runtime.spawnedEntries[entry.id] or 0) < entry.quantity then
            return false
        end
    end

    return true
end

function SpaceMiner:updateStage()
    if self.preview or self:isEndlessMode() or self.menuOpen then
        return
    end

    local stage = self:getCurrentStage()
    if stage == nil then
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
        local spawnedCount = runtime.spawnedEntries[entry.id] or 0
        if spawnedCount < entry.quantity then
            local baseDueFrame
            if stage.trigger.type == "time" then
                baseDueFrame = entry.timestampFrames or ((stage.waveStartFrame or runtime.waveStartFrame) + (entry.offsetFrames or 0))
            else
                baseDueFrame = runtime.waveStartFrame + (entry.offsetFrames or 0)
            end

            while spawnedCount < entry.quantity do
                local pairIndex = math.floor(spawnedCount / 2)
                local dueFrame = baseDueFrame + (pairIndex * (entry.spacingFrames or 0))
                if self.frame < dueFrame then
                    break
                end
                spawnedCount = spawnedCount + 1
                self:spawnWaveEntity(entry, spawnedCount)
                runtime.spawnedEntries[entry.id] = spawnedCount
            end
        end
    end

    if self:stageEntriesFullySpawned(stage) and #self.enemyShips == 0 and #self.enemyMissiles == 0 then
        self:advanceStage()
    end
end

function SpaceMiner:applyCrank(change)
    if self.menuOpen then
        return
    end
    if math.abs(change) <= 0.001 then
        return
    end

    self:noteInteraction()
    if self.gameOver then
        return
    end

    self.virtualCrankAngle = self.virtualCrankAngle + change
    self.player.angle = normalizeAngle(self.player.angle + (change * self.turnScale * self:getThrusterHandlingMultiplier()))
end

function SpaceMiner:updateInput(upPressed, downPressed, leftPressed, rightJustPressed, primaryJustPressed)
    if upPressed or downPressed or leftPressed or rightJustPressed or primaryJustPressed then
        self:noteInteraction()
    end

    self.input.thrust = (upPressed and not self.gameOver) and 1 or 0
    self.input.reverse = (downPressed and not self.gameOver) and 1 or 0
    self.input.laser = leftPressed == true and not self.gameOver
    self.player.laserOn = self.input.laser
    if (rightJustPressed or (self:getActiveUpgrade("missile") or {}).autoLaunch and pd.buttonIsPressed(pd.kButtonRight)) and not self.gameOver then
        self.player.pendingMissileTrigger = true
    end
end

function SpaceMiner:updateInstructionOverlay()
    if self.preview or self.instructionOverlayFrames <= 0 then
        return
    end
    self.instructionOverlayFrames = self.instructionOverlayFrames - 1
end

function SpaceMiner:updateDashboardIndicator()
    local targetOffset = 0
    if self.input.thrust > 0 then
        targetOffset = 3.5
    elseif self.input.reverse > 0 then
        targetOffset = -2
    end
    self.dashboardStickOffset = self.dashboardStickOffset + ((targetOffset - self.dashboardStickOffset) * 0.28)

    local targetShieldRatio = self:getShieldMeterRatio()
    self.dashboardShieldRatio = self.dashboardShieldRatio + ((targetShieldRatio - self.dashboardShieldRatio) * 0.08)
end

function SpaceMiner:applyPlayerThrust()
    if self.gameOver then
        return
    end

    local radians = math.rad(self.player.angle)
    local thrustMultiplier = self:getThrusterAccelerationMultiplier()
    if self.input.thrust > 0 then
        applyAcceleration(self.player, math.cos(radians) * PLAYER_THRUST * thrustMultiplier, math.sin(radians) * PLAYER_THRUST * thrustMultiplier, PLAYER_MAX_SPEED)
    end
    if self.input.reverse > 0 then
        applyAcceleration(self.player, -math.cos(radians) * PLAYER_REVERSE_THRUST * thrustMultiplier, -math.sin(radians) * PLAYER_REVERSE_THRUST * thrustMultiplier, PLAYER_MAX_SPEED)
    end
end

function SpaceMiner:updatePlayerPosition()
    if not self.preview
        and self.turnMode == SpaceMiner.MODE_FULL
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
    self:updateBaseShieldRecharge()
end

function SpaceMiner:handleMissileTrigger()
    if self.player.pendingMissileTrigger ~= true then
        return
    end

    local upgrade = self:getActiveUpgrade("missile") or {}
    if upgrade.autoLaunch then
        self.autoMissileAccumulator = (self.autoMissileAccumulator or 0) + (AUTO_MISSILE_SHOTS_PER_SECOND / 30)
        local shotCost = upgrade.shotCost or 5
        while self.autoMissileAccumulator >= 1 and (self.cash or 0) >= shotCost do
            self.autoMissileAccumulator = self.autoMissileAccumulator - 1
            self.cash = self.cash - shotCost
            self:spawnPlayerMissile(upgrade)
        end
        self.player.pendingMissileTrigger = false
        return
    end
    self.autoMissileAccumulator = 0

    if self.player.missile ~= nil then
        if not upgrade.manualDetonate then
            self.player.pendingMissileTrigger = false
            return
        end
        self:explodePlayerMissile(self.player.missile.x, self.player.missile.y, self.player.missile, true)
        self.player.pendingMissileTrigger = false
        return
    end

    self:spawnPlayerMissile(upgrade)
    self.player.pendingMissileTrigger = false
end

function SpaceMiner:spawnPlayerMissile(upgrade)
    local radians = math.rad(self.player.angle)
    local missile = {
        x = self.player.x,
        y = self.player.y,
        vx = math.cos(radians) * MISSILE_SPEED + self.player.vx,
        vy = math.sin(radians) * MISSILE_SPEED + self.player.vy,
        life = MISSILE_LIFE_FRAMES,
        guided = upgrade and upgrade.guided or false,
        damage = MISSILE_DAMAGE + ((upgrade and upgrade.damageBonus) or 0),
        autoLaunch = upgrade and upgrade.autoLaunch == true,
        visual = upgrade and upgrade.id,
        survivesManualDetonation = upgrade and upgrade.survivesManualDetonation == true,
        maxManualDetonations = upgrade and upgrade.maxManualDetonations or 1,
        manualDetonations = 0
    }
    self.player.missiles[#self.player.missiles + 1] = missile
    if not missile.autoLaunch then
        self.player.missile = missile
    end
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
    local minedScore = config and config.score or 1
    local nextConfig = ASTEROID_STAGE_CONFIG[(asteroid.stage or 0) + 1]
    local isOreChunk = nextConfig == nil
    if isOreChunk and self:isCargoFull() and not options.skipRewards and options.removalReason ~= "missile" then
        asteroid.hp = math.max(1, config and config.hp or 1)
        return
    end

    if not options.skipRewards and not self:isEndlessMode() then
        self.score = self.score + minedScore
    end
    if isOreChunk and not options.skipRewards then
        self:addCargoFromAsteroid(asteroid)
    end
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
    self.destroyedEnemies = (self.destroyedEnemies or 0) + 1
    self:addExplosion(enemy.x, enemy.y, enemy.size + 6, 10)
    table.remove(self.enemyShips, index)
end

function SpaceMiner:explodePlayerMissile(x, y, missile, manualTrigger)
    self:addExplosion(x, y, MISSILE_BLAST_RADIUS, 9)
    local missileDamage = (missile and missile.damage) or self:getMissileDamage()

    for enemyIndex = #self.enemyShips, 1, -1 do
        local enemy = self.enemyShips[enemyIndex]
        local hitRadius = MISSILE_BLAST_RADIUS + enemy.size
        if distanceSquared(x, y, enemy.x, enemy.y) <= (hitRadius * hitRadius) then
            self:damageEnemy(enemyIndex, missileDamage)
        end
    end

    for asteroidIndex = #self.asteroids, 1, -1 do
        local asteroid = self.asteroids[asteroidIndex]
        local hitRadius = MISSILE_BLAST_RADIUS + asteroid.radius
        if distanceSquared(x, y, asteroid.x, asteroid.y) <= (hitRadius * hitRadius) then
            self:damageAsteroid(asteroidIndex, missileDamage, {
                missileCascade = true,
                removalReason = "missile"
            })
        end
    end

    if manualTrigger and missile ~= nil and missile.survivesManualDetonation then
        missile.manualDetonations = (missile.manualDetonations or 0) + 1
        if missile.manualDetonations < (missile.maxManualDetonations or 5) then
            return
        end
    end
    self:removePlayerMissile(missile)
end

function SpaceMiner:removePlayerMissile(missile)
    if missile == nil then
        self.player.missile = nil
        return
    end
    for index = #self.player.missiles, 1, -1 do
        if self.player.missiles[index] == missile then
            table.remove(self.player.missiles, index)
            break
        end
    end
    if self.player.missile == missile then
        self.player.missile = nil
    end
end

function SpaceMiner:getAutoMissileTarget(missile)
    local nearest = nil
    local nearestDistanceSq = math.huge
    for _, enemy in ipairs(self.enemyShips) do
        local candidateDistanceSq = distanceSquared(missile.x, missile.y, enemy.x, enemy.y)
        if candidateDistanceSq < nearestDistanceSq then
            nearest = enemy
            nearestDistanceSq = candidateDistanceSq
        end
    end
    if nearest ~= nil then
        return nearest.x, nearest.y
    end

    local threat = nil
    local threatDistanceSq = math.huge
    for _, asteroid in ipairs(self.asteroids) do
        local playerDistanceSq = distanceSquared(self.player.x, self.player.y, asteroid.x, asteroid.y)
        if playerDistanceSq <= (30 * 30) and playerDistanceSq < threatDistanceSq then
            threat = asteroid
            threatDistanceSq = playerDistanceSq
        end
    end
    if threat ~= nil then
        return threat.x, threat.y
    end

    local largest = nil
    for _, asteroid in ipairs(self.asteroids) do
        if largest == nil or asteroid.radius > largest.radius then
            largest = asteroid
        end
    end
    if largest ~= nil then
        return largest.x, largest.y
    end
    return nil, nil
end

function SpaceMiner:getAutoMissileEnemyTarget()
    if not ((self:getActiveUpgrade("missile") or {}).autoLaunch) then
        return nil
    end
    local nearest = nil
    local nearestDistanceSq = math.huge
    for _, enemy in ipairs(self.enemyShips) do
        local candidateDistanceSq = distanceSquared(self.player.x, self.player.y, enemy.x, enemy.y)
        if candidateDistanceSq < nearestDistanceSq then
            nearest = enemy
            nearestDistanceSq = candidateDistanceSq
        end
    end
    return nearest
end

function SpaceMiner:updatePlayerMissileGuidance(missile)
    if missile.guided == "player" then
        local radians = math.rad(self.player.angle)
        local targetVx = math.cos(radians) * MISSILE_SPEED
        local targetVy = math.sin(radians) * MISSILE_SPEED
        missile.vx = missile.vx + ((targetVx - missile.vx) * 0.16)
        missile.vy = missile.vy + ((targetVy - missile.vy) * 0.16)
    elseif missile.guided == "auto" then
        local targetX, targetY = self:getAutoMissileTarget(missile)
        if targetX ~= nil then
            local ux, uy = unitVector(targetX - missile.x, targetY - missile.y)
            missile.vx = missile.vx + (ux * 0.18)
            missile.vy = missile.vy + (uy * 0.18)
            local speed = magnitude(missile.vx, missile.vy)
            if speed > MISSILE_SPEED * 1.15 then
                missile.vx = (missile.vx / speed) * MISSILE_SPEED * 1.15
                missile.vy = (missile.vy / speed) * MISSILE_SPEED * 1.15
            end
        end
    end
end

function SpaceMiner:updatePlayerMissile()
    self:handleMissileTrigger()

    if #self.player.missiles == 0 then
        return
    end

    for missileIndex = #self.player.missiles, 1, -1 do
        local missile = self.player.missiles[missileIndex]
        self:updatePlayerMissileGuidance(missile)
        missile.x = missile.x + missile.vx
        missile.y = missile.y + missile.vy
        missile.life = missile.life - 1

        for enemyIndex, enemy in ipairs(self.enemyShips) do
            local hitRadius = enemy.size + 3
            if distanceSquared(missile.x, missile.y, enemy.x, enemy.y) <= (hitRadius * hitRadius) then
                self:explodePlayerMissile(missile.x, missile.y, missile)
                goto continue
            end
        end

        for asteroidIndex, asteroid in ipairs(self.asteroids) do
            local hitRadius = asteroid.radius + 2
            if distanceSquared(missile.x, missile.y, asteroid.x, asteroid.y) <= (hitRadius * hitRadius) then
                self:explodePlayerMissile(missile.x, missile.y, missile)
                goto continue
            end
        end

        if missile.life <= 0 then
            self:explodePlayerMissile(missile.x, missile.y, missile)
        end
        ::continue::
    end
end

function SpaceMiner:updateEnemyMissiles()
    for missileIndex = #self.enemyMissiles, 1, -1 do
        local missile = self.enemyMissiles[missileIndex]
        if missile.heatSeeking then
            local targetX, targetY = self:getTargetPosition(missile.target)
            local dx = targetX - missile.x
            local dy = targetY - missile.y
            local ux, uy = unitVector(dx, dy)
            missile.vx = missile.vx + (ux * ENEMY_HEAT_MISSILE_TURN_ACCELERATION)
            missile.vy = missile.vy + (uy * ENEMY_HEAT_MISSILE_TURN_ACCELERATION)
            local speed = magnitude(missile.vx, missile.vy)
            if speed > ENEMY_HEAT_MISSILE_MAX_SPEED then
                missile.vx = (missile.vx / speed) * ENEMY_HEAT_MISSILE_MAX_SPEED
                missile.vy = (missile.vy / speed) * ENEMY_HEAT_MISSILE_MAX_SPEED
            end
        end
        missile.x = missile.x + missile.vx
        missile.y = missile.y + missile.vy
        missile.life = missile.life - 1

        local shieldRadius = PLAYER_RADIUS + 3 + ((self.playerShieldHits or 0) > 0 and 2 or 0)
        local detonationRadius = shieldRadius * 2
        if not self.gameOver and distanceSquared(missile.x, missile.y, self.player.x, self.player.y) <= (detonationRadius * detonationRadius) then
            self:addExplosion(missile.x, missile.y, detonationRadius * 0.55, 8)
            self:damagePlayer("enemy-missile")
            table.remove(self.enemyMissiles, missileIndex)
        elseif self:isStoryMode()
            and self:isBaseShieldActive()
            and distanceSquared(missile.x, missile.y, BASE_WORLD_X, BASE_WORLD_Y) <= (BASE_SHIELD_RADIUS * BASE_SHIELD_RADIUS) then
            self:addExplosion(missile.x, missile.y, 16, 8)
            self:damageBase("enemy-missile")
            table.remove(self.enemyMissiles, missileIndex)
        elseif distanceSquared(missile.x, missile.y, BASE_WORLD_X, BASE_WORLD_Y) <= (28 * 28) then
            self:addExplosion(missile.x, missile.y, 14, 8)
            self:damageBase("enemy-missile")
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

    local enemyHits = 0
    for enemyIndex = #self.enemyShips, 1, -1 do
        local enemy = self.enemyShips[enemyIndex]
        local hitDistanceSq = linePointDistanceSquared(enemy.x, enemy.y, self.player.x, self.player.y, endX, endY)
        local hitRadius = enemy.size + LASER_WIDTH
        if hitDistanceSq <= (hitRadius * hitRadius) then
            self:damageEnemy(enemyIndex, self:getLaserDamagePerFrame())
            enemyHits = enemyHits + 1
            if enemyHits >= self:getLaserEnemyPenetrationLimit() then
                break
            end
        end
    end

    for asteroidIndex = #self.asteroids, 1, -1 do
        local asteroid = self.asteroids[asteroidIndex]
        local hitDistanceSq = linePointDistanceSquared(asteroid.x, asteroid.y, self.player.x, self.player.y, endX, endY)
        local hitRadius = asteroid.radius + LASER_WIDTH
        if hitDistanceSq <= (hitRadius * hitRadius) then
            self:damageAsteroid(asteroidIndex, self:getLaserDamagePerFrame(), {
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
        if not self.gameOver and distanceSquared(asteroid.x, asteroid.y, self.player.x, self.player.y) <= (hitRadius * hitRadius) then
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
        elseif self:isStoryMode()
            and self:isBaseShieldActive()
            and distanceSquared(asteroid.x, asteroid.y, BASE_WORLD_X, BASE_WORLD_Y) <= ((asteroid.radius + BASE_SHIELD_RADIUS) * (asteroid.radius + BASE_SHIELD_RADIUS)) then
            self:addExplosion(asteroid.x, asteroid.y, asteroid.radius + 6, 9)
            self:spawnFragments(asteroid)
            table.remove(self.asteroids, asteroidIndex)
        elseif self:isStoryMode()
            and not self:isBaseShieldActive()
            and distanceSquared(asteroid.x, asteroid.y, BASE_WORLD_X, BASE_WORLD_Y) <= ((asteroid.radius + 24) * (asteroid.radius + 24)) then
            self:addExplosion(asteroid.x, asteroid.y, asteroid.radius + 6, 9)
            self:damageBase("asteroid")
            self:spawnFragments(asteroid)
            table.remove(self.asteroids, asteroidIndex)
        end
    end

    self:resolveAsteroidLayerCollisions()
    self:pruneOffscreenAsteroidsForEntityPressure()
    self:seedAsteroids(self.preview and PREVIEW_ASTEROID_COUNT or TARGET_ASTEROID_COUNT)
end

function SpaceMiner:resolveAsteroidLayerCollisions()
    local removed = {}
    for leftIndex = 1, #self.asteroids - 1 do
        local left = self.asteroids[leftIndex]
        if left ~= nil and not removed[leftIndex] then
            for rightIndex = leftIndex + 1, #self.asteroids do
                local right = self.asteroids[rightIndex]
                if right ~= nil
                    and not removed[rightIndex]
                    and left.layer == right.layer
                    and distanceSquared(left.x, left.y, right.x, right.y) <= ((left.radius + right.radius) * (left.radius + right.radius)) then
                    self:addExplosion((left.x + right.x) * 0.5, (left.y + right.y) * 0.5, math.max(left.radius, right.radius) + 3, 8)
                    self:spawnFragments(left, { missileCascade = false })
                    self:spawnFragments(right, { missileCascade = false })
                    removed[leftIndex] = true
                    removed[rightIndex] = true
                    break
                end
            end
        end
    end

    for index = #self.asteroids, 1, -1 do
        if removed[index] then
            table.remove(self.asteroids, index)
        end
    end
end

function SpaceMiner:getActiveEntityCount()
    local count = #self.asteroids + #self.enemyShips + #self.enemyMissiles + #self.explosions
    count = count + #(self.player.missiles or {})
    return count
end

function SpaceMiner:logEntityCountsIfNeeded()
    if self.preview or ENTITY_LOG_INTERVAL_FRAMES <= 0 or (self.frame % ENTITY_LOG_INTERVAL_FRAMES) ~= 0 then
        return
    end
    local offscreenEnemies = 0
    local nearBaseEnemies = 0
    local baseRadiusSq = BASE_SHIELD_ENEMY_KEEP_ALIVE_RADIUS * BASE_SHIELD_ENEMY_KEEP_ALIVE_RADIUS
    for _, enemy in ipairs(self.enemyShips) do
        local drawX, drawY = worldToScreen(self.player.x, self.player.y, enemy.x, enemy.y)
        if drawX < -20 or drawX > SCREEN_WIDTH + 20 or drawY < -20 or drawY > SCREEN_HEIGHT + 20 then
            offscreenEnemies = offscreenEnemies + 1
        end
        if distanceSquared(enemy.x, enemy.y, BASE_WORLD_X, BASE_WORLD_Y) <= baseRadiusSq then
            nearBaseEnemies = nearBaseEnemies + 1
        end
    end
    StarryLog.forceDebug(
        "miner entities frame=%d stage=%d/%d total=%d asteroids=%d enemies=%d offscreenEnemies=%d nearBaseEnemies=%d enemyMissiles=%d playerMissiles=%d explosions=%d cargo=%d/%d baseShield=%d menu=%s gameOver=%s",
        self.frame,
        self.stageIndex or 0,
        #STAGE_SCHEDULE,
        self:getActiveEntityCount(),
        #self.asteroids,
        #self.enemyShips,
        offscreenEnemies,
        nearBaseEnemies,
        #self.enemyMissiles,
        #(self.player.missiles or {}),
        #self.explosions,
        self.cargoOre or 0,
        math.floor((self.cargoCapacity or CARGO_INITIAL_CAPACITY) + 0.0001),
        self.baseShieldHits or 0,
        tostring(self.menuOpen == true),
        tostring(self.gameOver == true)
    )
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
    local nearest = nil
    local nearestDistanceSq = 140 * 140
    for _, missile in ipairs(self.player.missiles or {}) do
        local candidateDistanceSq = distanceSquared(enemy.x, enemy.y, missile.x, missile.y)
        if candidateDistanceSq <= nearestDistanceSq then
            nearest = missile
            nearestDistanceSq = candidateDistanceSq
        end
    end
    return nearest
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

function SpaceMiner:getAsteroidAvoidance(enemy, radius, force)
    if enemy.avoidAsteroids == false then
        return 0, 0
    end
    local asteroid, asteroidDistanceSq = self:getNearestAsteroidThreat(enemy)
    if asteroid == nil or asteroidDistanceSq > ((radius or 95) * (radius or 95)) then
        return 0, 0
    end
    local ux, uy = unitVector(asteroid.x - enemy.x, asteroid.y - enemy.y)
    local strength = (force or 1) * (1 - clamp(math.sqrt(asteroidDistanceSq) / (radius or 95), 0, 1))
    return -ux * strength, -uy * strength
end

function SpaceMiner:updateSeekers(enemy)
    local targetX, targetY = self:getTargetPosition(enemy.target)
    local targetVx, targetVy = self:getTargetVelocity(enemy.target)
    targetX = targetX + (targetVx * ENEMY_PREDICTION_FRAMES)
    targetY = targetY + (targetVy * ENEMY_PREDICTION_FRAMES)
    local avoidX, avoidY = self:getAsteroidAvoidance(enemy, 115, 54)
    targetX = targetX + avoidX
    targetY = targetY + avoidY
    local steerX, steerY = steerBodyToward(enemy, targetX, targetY, enemy.maxSpeed, enemy.acceleration * 1.35, ENEMY_ARRIVAL_RADIUS)
    if math.abs(steerX) > 0.0001 or math.abs(steerY) > 0.0001 then
        enemy.angle = normalizeAngle(math.deg(math.atan(steerY, steerX)))
    end
end

function SpaceMiner:updateEscaper(enemy)
    local awayX = 0
    local awayY = 0
    local playerDx = self.player.x - enemy.x
    local playerDy = self.player.y - enemy.y
    local playerUx, playerUy, playerDistance = unitVector(playerDx, playerDy)
    local escapingPlayer = playerDistance < ESCAPER_LINGER_MIN_RADIUS
    local returningToScreenEdge = playerDistance > ESCAPER_LINGER_MAX_RADIUS

    if escapingPlayer then
        awayX = awayX - playerUx * 1.6
        awayY = awayY - playerUy * 1.6
    elseif returningToScreenEdge then
        awayX = awayX + playerUx * 1.1
        awayY = awayY + playerUy * 1.1
    else
        local tangentX = -playerUy
        local tangentY = playerUx
        enemy.lingerDirection = enemy.lingerDirection or (math.random(0, 1) == 0 and -1 or 1)
        local radiusError = (playerDistance - ESCAPER_LINGER_TARGET_RADIUS) / ESCAPER_LINGER_TARGET_RADIUS
        awayX = (tangentX * enemy.lingerDirection * 0.75) + (playerUx * clamp(radiusError, -0.75, 0.75))
        awayY = (tangentY * enemy.lingerDirection * 0.75) + (playerUy * clamp(radiusError, -0.75, 0.75))

        local avoidX, avoidY = self:getAsteroidAvoidance(enemy, 110, 1.2)
        awayX = awayX + avoidX
        awayY = awayY + avoidY

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
    enemy.vx = enemy.vx * ENEMY_IDLE_DRAG
    enemy.vy = enemy.vy * ENEMY_IDLE_DRAG
    enemy.angle = normalizeAngle(math.deg(math.atan(uy, ux)))
end

function SpaceMiner:spawnEnemyMissile(enemy)
    local targetX, targetY = self:getTargetPosition(enemy.target)
    local dx = targetX - enemy.x
    local dy = targetY - enemy.y
    local ux, uy = unitVector(dx, dy)
    self.enemyMissiles[#self.enemyMissiles + 1] = {
        x = enemy.x,
        y = enemy.y,
        vx = ux * (MISSILE_SPEED * 0.9),
        vy = uy * (MISSILE_SPEED * 0.9),
        life = MISSILE_LIFE_FRAMES,
        heatSeeking = false,
        target = enemy.target
    }
end

function SpaceMiner:spawnWaveEnemyMissile(entryDegrees, heatSeeking, target)
    local x, y = self:getWaveSpawnPoint(entryDegrees, 260, 360)
    local targetX, targetY = self:getTargetPosition(target)
    local dx = targetX - x
    local dy = targetY - y
    local ux, uy = unitVector(dx, dy)
    local speed = heatSeeking and (MISSILE_SPEED * 0.72) or (MISSILE_SPEED * 0.92)
    self.enemyMissiles[#self.enemyMissiles + 1] = {
        x = x,
        y = y,
        vx = ux * speed,
        vy = uy * speed,
        life = heatSeeking and math.floor(MISSILE_LIFE_FRAMES * 1.35) or MISSILE_LIFE_FRAMES,
        heatSeeking = heatSeeking == true,
        target = normalizeTarget(target)
    }
end

function SpaceMiner:updateStriker(enemy)
    local targetBaseX, targetBaseY = self:getTargetPosition(enemy.target)
    local targetVx, targetVy = self:getTargetVelocity(enemy.target)
    local toPlayerX = targetBaseX - enemy.x
    local toPlayerY = targetBaseY - enemy.y
    local ux, uy, distance = unitVector(toPlayerX, toPlayerY)
    local targetX
    local targetY
    if distance > 118 then
        targetX = targetBaseX + (targetVx * ENEMY_PREDICTION_FRAMES)
        targetY = targetBaseY + (targetVy * ENEMY_PREDICTION_FRAMES)
    else
        targetX = targetBaseX - (uy * 88)
        targetY = targetBaseY + (ux * 88)
    end
    local avoidX, avoidY = self:getAsteroidAvoidance(enemy, 105, 48)
    targetX = targetX + avoidX
    targetY = targetY + avoidY

    local steerX, steerY = steerBodyToward(enemy, targetX, targetY, enemy.maxSpeed, enemy.acceleration * 1.25, ENEMY_ARRIVAL_RADIUS * 0.85)
    if math.abs(steerX) > 0.0001 or math.abs(steerY) > 0.0001 then
        enemy.angle = normalizeAngle(math.deg(math.atan(steerY, steerX)))
    end

    enemy.missileCooldown = enemy.missileCooldown - 1
    if enemy.missileCooldown <= 0 and distance < 220 then
        self:spawnEnemyMissile(enemy)
        enemy.missileCooldown = STRIKER_MISSILE_COOLDOWN + math.random(0, 35)
    end
end

function SpaceMiner:updatePostDeathEnemy(enemy)
    local targetAsteroid = nil
    local targetAsteroidIndex = nil
    local nearestDistanceSq = math.huge
    for asteroidIndex, asteroid in ipairs(self.asteroids) do
        local candidateDistanceSq = distanceSquared(enemy.x, enemy.y, asteroid.x, asteroid.y)
        if candidateDistanceSq < nearestDistanceSq then
            nearestDistanceSq = candidateDistanceSq
            targetAsteroid = asteroid
            targetAsteroidIndex = asteroidIndex
        end
    end

    if targetAsteroid ~= nil and nearestDistanceSq <= (260 * 260) then
        local steerX, steerY = steerBodyToward(enemy, targetAsteroid.x, targetAsteroid.y, enemy.maxSpeed, enemy.acceleration * 1.4, 28)
        if math.abs(steerX) > 0.0001 or math.abs(steerY) > 0.0001 then
            enemy.angle = normalizeAngle(math.deg(math.atan(steerY, steerX)))
        end
        if nearestDistanceSq <= ((enemy.size + targetAsteroid.radius + 4) * (enemy.size + targetAsteroid.radius + 4)) then
            self:addExplosion(targetAsteroid.x, targetAsteroid.y, targetAsteroid.radius + 5, 8)
            self:damageAsteroid(targetAsteroidIndex, 999, {
                skipRewards = true,
                removalReason = "enemy"
            })
        end
    else
        if enemy.fleeAngle == nil then
            enemy.fleeAngle = math.atan(enemy.y - self.player.y, enemy.x - self.player.x) + ((math.random() - 0.5) * 0.7)
        end
        applyAcceleration(enemy, math.cos(enemy.fleeAngle) * enemy.acceleration, math.sin(enemy.fleeAngle) * enemy.acceleration, enemy.maxSpeed)
        enemy.angle = normalizeAngle(math.deg(enemy.fleeAngle))
    end

    enemy.x = wrapCoordinate(self.player.x, enemy.x + enemy.vx)
    enemy.y = wrapCoordinate(self.player.y, enemy.y + enemy.vy)
    local drawX, drawY = worldToScreen(self.player.x, self.player.y, enemy.x, enemy.y)
    return drawX < -80 or drawX > SCREEN_WIDTH + 80 or drawY < -80 or drawY > SCREEN_HEIGHT + 80
end

function SpaceMiner:updateEnemies()
    for enemyIndex = #self.enemyShips, 1, -1 do
        local enemy = self.enemyShips[enemyIndex]
        if self.gameOver then
            if self:updatePostDeathEnemy(enemy) then
                table.remove(self.enemyShips, enemyIndex)
            end
        else
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
            elseif self:isStoryMode()
                and self:isBaseShieldActive()
                and distanceSquared(enemy.x, enemy.y, BASE_WORLD_X, BASE_WORLD_Y) <= ((enemy.size + BASE_SHIELD_RADIUS) * (enemy.size + BASE_SHIELD_RADIUS)) then
                self:addExplosion(enemy.x, enemy.y, enemy.size + 8, 9)
                self:damageBase("enemy-ship")
                table.remove(self.enemyShips, enemyIndex)
            elseif distanceSquared(enemy.x, enemy.y, BASE_WORLD_X, BASE_WORLD_Y) <= ((enemy.size + 24) * (enemy.size + 24)) then
                self:addExplosion(enemy.x, enemy.y, enemy.size + 8, 9)
                self:damageBase("enemy-ship")
                table.remove(self.enemyShips, enemyIndex)
            end
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

    self:updateInstructionOverlay()
    self:updateDashboardIndicator()

    if not self.menuOpen then
        self.frame = self.frame + 1
    end
    if self:isStoryMode() then
        self:updateHomeBaseVisitState()
        self:updateBaseTimeline()
        self:updateSettingsTimeline()
        self:updateBaseCollisionCommunication()
        self:updateDestroyedCommunications()
    end
    if self.baseUnderAttackFrames > 0 and not (self.menuOpen and self.menuType == "home") then
        self.baseUnderAttackFrames = self.baseUnderAttackFrames - 1
    end
    if (self.supernovaFlashFrames or 0) > 0 then
        self.supernovaFlashFrames = self.supernovaFlashFrames - 1
    end
    self:updateStage()
    self:updateCargo()
    self:updateHomeBaseRepairs()
    if self.menuOpen then
        self.input.thrust = 0
        self.input.reverse = 0
        self.input.laser = false
        self.player.laserOn = false
        self:updateMenuAutoNavigate()
    end
    self:applyPlayerThrust()
    self:updatePlayerPosition()
    self:updateDecor()
    self:updatePlayerMissile()
    if self:isStoryMode() then
        self:updateEnemyMissiles()
    end
    self:applyLaser()
    if self:isStoryMode() then
        self:updateEnemies()
    end
    self:updateAsteroids()
    self:updateExplosions()
    self:logEntityCountsIfNeeded()
    self:logAsteroidDiagnosticsIfNeeded()
end

function SpaceMiner:drawDecorLayer(layer)
    gfx.setColor(gfx.kColorWhite)
    for _, item in ipairs(self.decor) do
        if item.layer == layer then
            local drawX, drawY = parallaxWorldToScreen(self.player.x, self.player.y, item.x, item.y, item.parallax)
            local padding = 8
            if drawX >= -padding and drawX <= (SCREEN_WIDTH + padding) and drawY >= -padding and drawY <= (SCREEN_HEIGHT + padding) then
                if item.kind == "dot" then
                    gfx.fillRect(drawX, drawY, 1, 1)
                elseif item.kind == "cross" then
                    gfx.drawLine(drawX - 1, drawY, drawX + 1, drawY)
                    gfx.drawLine(drawX, drawY - 1, drawX, drawY + 1)
                elseif item.kind == "square" then
                    gfx.fillRect(drawX - 1, drawY - 1, 2, 2)
                elseif item.kind == "shard" then
                    local dx = math.cos(item.angle or 0) * item.radius
                    local dy = math.sin(item.angle or 0) * item.radius
                    gfx.drawLine(drawX - dx, drawY - dy, drawX + dx, drawY + dy)
                end
            end
        end
    end
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    gfx.setColor(gfx.kColorWhite)
end

function SpaceMiner:drawBackgroundStars()
    if self.backgroundImage ~= nil then
        self.backgroundImage:draw(0, 0)
    end
end

function SpaceMiner:drawDistantStar()
    local x = 300
    local y = 52
    local frame = self.frame or 0
    gfx.setColor(gfx.kColorWhite)

    for index = 1, 10 do
        local radius = 2 + index
        local direction = (index % 2 == 0) and -1 or 1
        local spin = (frame * (1.2 + index * 0.18) * direction) % 360
        local arcLength = 128 + (index % 3) * 28
        local gapOffset = 42 + (index * 11)
        gfx.drawArc(x, y, radius, spin, spin + arcLength)
        gfx.drawArc(x, y, radius, spin + arcLength + gapOffset, spin + 350)
    end
end

function SpaceMiner:drawMiniMapMarker(worldX, worldY, kind)
    local relX = clamp((worldX - self.player.x) / MINIMAP_RANGE, -1, 1)
    local relY = clamp((worldY - self.player.y) / MINIMAP_RANGE, -1, 1)
    local markerX = MINIMAP_X + (MINIMAP_WIDTH * 0.5) + (relX * (MINIMAP_WIDTH * 0.5 - 4))
    local markerY = MINIMAP_Y + (MINIMAP_HEIGHT * 0.5) + (relY * (MINIMAP_HEIGHT * 0.5 - 4))
    if kind == "player" then
        gfx.fillRect(markerX - 1, markerY - 1, 3, 3)
    elseif kind == "base" then
        gfx.drawRect(markerX - 2, markerY - 2, 5, 5)
    else
        gfx.drawLine(markerX - 2, markerY, markerX + 2, markerY)
        gfx.drawLine(markerX, markerY - 2, markerX, markerY + 2)
    end
end

function SpaceMiner:drawMaterialMiniMap()
    if self.miniMapEnabled ~= true then
        return
    end

    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(MINIMAP_X, MINIMAP_Y, MINIMAP_WIDTH, MINIMAP_HEIGHT)
    self:drawMiniMapMarker(self.player.x, self.player.y, "player")
    if self:isStoryMode() then
        self:drawMiniMapMarker(BASE_WORLD_X, BASE_WORLD_Y, "base")
    end
    for _, enemy in ipairs(self.enemyShips) do
        self:drawMiniMapMarker(enemy.x, enemy.y, "enemy")
    end
end

function SpaceMiner:drawCargoSpaceBar()
    local capacity = math.max(1, math.floor((self.cargoCapacity or CARGO_INITIAL_CAPACITY) + 0.0001))
    local ratio = clamp((self.cargoOre or 0) / capacity, 0, 1)
    local fillWidth = math.floor((CARGO_BAR_WIDTH - 2) * ratio + 0.5)
    local isFull = ratio >= 1
    local fullFlashWhite = isFull and (math.floor((self.frame or 0) / 8) % 2 == 0)

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(CARGO_BAR_X, CARGO_BAR_Y, CARGO_BAR_WIDTH, CARGO_BAR_HEIGHT)
    if fillWidth > 0 then
        gfx.setColor((not isFull or fullFlashWhite) and gfx.kColorWhite or gfx.kColorBlack)
        gfx.fillRect(CARGO_BAR_X + 1, CARGO_BAR_Y + 1, fillWidth, CARGO_BAR_HEIGHT - 2)
    end

    local fillRight = CARGO_BAR_X + fillWidth
    self:drawTinyConsoleText("CARGO SPACE", CARGO_BAR_X + 1, CARGO_BAR_Y + 3, function(charX)
        if charX <= fillRight and (not isFull or fullFlashWhite) then
            return gfx.kColorBlack
        end
        return gfx.kColorWhite
    end)
    gfx.setColor(gfx.kColorWhite)
end

function SpaceMiner:drawMenu()
    if not self.menuOpen then
        return
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    local items = self:getMenuItems()
    local isHome = self.menuType == "home"
    local menuWidth = isHome and HOME_BASE_MENU_WIDTH or MINER_MENU_WIDTH
    local menuX = isHome and math.floor((SCREEN_WIDTH - menuWidth) * 0.5) or MINER_MENU_X
    local messageHeight = 0
    local height = 52 + messageHeight + (#items * MINER_MENU_ROW_HEIGHT)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(menuX, MINER_MENU_Y, menuWidth, height, 6)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(menuX, MINER_MENU_Y, menuWidth, height, 6)
    local title = "Ship Menu"
    if isHome then
        title = self.homeMenuScreen == "directory" and "Home Base" or ((UPGRADE_CATEGORY_CONFIG[self:getUpgradeCategoryForScreen(self.homeMenuScreen)] or {}).title or "Game Settings")
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText(title, menuX + 10, MINER_MENU_Y + 8)
    gfx.drawText(string.format("Defended: %d", self.destroyedEnemies or 0), menuX + 10, MINER_MENU_Y + 25)
    for index, item in ipairs(items) do
        local rowY = MINER_MENU_Y + 46 + messageHeight + ((index - 1) * MINER_MENU_ROW_HEIGHT)
        local unaffordable = item.action == "buy-upgrade" and item.enabled == false
        local flashError = unaffordable and (math.floor((self.frame or 0) / 8) % 2 == 0)
        local invertRow = index == self.menuIndex or flashError
        if invertRow then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(menuX + 6, rowY - 1, menuWidth - 12, MINER_MENU_ROW_HEIGHT)
            gfx.setImageDrawMode(gfx.kDrawModeInverted)
        else
            gfx.setColor(gfx.kColorBlack)
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
        end
        local label = tostring(item.label or "")
        local maxLabelLength = isHome and 52 or 18
        if #label > maxLabelLength then
            label = string.sub(label, 1, maxLabelLength - 1) .. "."
        end
        local valueText = ""
        if item.action == "buy-upgrade" then
            valueText = item.cost ~= nil and string.format("$%d", item.cost) or ""
        elseif item.action == "equip-upgrade" then
            valueText = item.value and "On" or "Equip"
        elseif item.action == "open-screen" then
            valueText = ">"
        else
            valueText = item.value and "On" or "Off"
        end
        local valueReserve = isHome and 70 or 48
        local labelWidth = menuWidth - valueReserve - 22
        gfx.drawTextInRect(label, menuX + 12, rowY + 1, labelWidth, MINER_MENU_ROW_HEIGHT)
        gfx.drawTextAligned(valueText, menuX + menuWidth - 12, rowY + 1, kTextAlignment.right)
        if invertRow then
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
            gfx.setColor(gfx.kColorBlack)
        end
    end
    gfx.setColor(gfx.kColorWhite)
end

function SpaceMiner:drawShip()
    if self.gameOver then
        return
    end

    gfx.setColor(gfx.kColorWhite)
    local radians = math.rad(self.player.angle)
    local laserUpgrade = self:getActiveUpgrade("laser") or {}
    local shieldUpgrade = self:getActiveUpgrade("shield") or {}
    local thrusterUpgrade = self:getActiveUpgrade("thruster") or {}
    local tipX = CENTER_X + (math.cos(radians) * 10)
    local tipY = CENTER_Y + (math.sin(radians) * 10)
    local leftX = CENTER_X + (math.cos(radians + 2.55) * 8)
    local leftY = CENTER_Y + (math.sin(radians + 2.55) * 8)
    local rightX = CENTER_X + (math.cos(radians - 2.55) * 8)
    local rightY = CENTER_Y + (math.sin(radians - 2.55) * 8)
    local function pointForwardSide(forward, side)
        return CENTER_X + (math.cos(radians) * forward) + (math.cos(radians + math.pi * 0.5) * side),
            CENTER_Y + (math.sin(radians) * forward) + (math.sin(radians + math.pi * 0.5) * side)
    end
    if shieldUpgrade.id == "dyson-shielding" then
        gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer8x8)
        gfx.fillTriangle(tipX, tipY, leftX, leftY, rightX, rightY)
        gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
        gfx.setColor(gfx.kColorWhite)
    end
    gfx.drawLine(tipX, tipY, leftX, leftY)
    gfx.drawLine(tipX, tipY, rightX, rightY)
    gfx.drawLine(leftX, leftY, rightX, rightY)

    if laserUpgrade.id == "standard-splaser" or laserUpgrade.id == "advanced-splaser" then
        local sideX = CENTER_X + math.cos(radians + 2.55) * 4
        local sideY = CENTER_Y + math.sin(radians + 2.55) * 4
        local sideNx = math.cos(radians + math.pi * 0.5)
        local sideNy = math.sin(radians + math.pi * 0.5)
        gfx.drawRect(sideX + sideNx * 3 - 1, sideY + sideNy * 3 - 4, 3, 8)
    end

    if thrusterUpgrade.id == "lightening-rcs-v1" or thrusterUpgrade.id == "lightening-rcs-v2" or thrusterUpgrade.id == "nuclear-rcs" then
        local tailX = CENTER_X - (math.cos(radians) * 9)
        local tailY = CENTER_Y - (math.sin(radians) * 9)
        gfx.drawCircleAtPoint(tailX, tailY, 3)
    elseif thrusterUpgrade.id == "anti-grav-drive" then
        local tailX, tailY = pointForwardSide(-8, 5)
        gfx.drawCircleAtPoint(tailX, tailY, 4)
    elseif thrusterUpgrade.id == "experimental-anti-momentum" then
        local aX, aY = pointForwardSide(-2, -5)
        local bX, bY = pointForwardSide(-12, -9)
        local cX, cY = pointForwardSide(-8, -1)
        gfx.drawTriangle(aX, aY, bX, bY, cX, cY)
        aX, aY = pointForwardSide(-2, 5)
        bX, bY = pointForwardSide(-12, 9)
        cX, cY = pointForwardSide(-8, 1)
        gfx.drawTriangle(aX, aY, bX, bY, cX, cY)
    end

    if self.input.thrust > 0 and not self.preview then
        local exhaustX = CENTER_X - (math.cos(radians) * 8)
        local exhaustY = CENTER_Y - (math.sin(radians) * 8)
        local flameLength = 6
        if thrusterUpgrade.id == "lightening-rcs-v2" then
            flameLength = 10
        elseif thrusterUpgrade.id == "nuclear-rcs" then
            flameLength = 13
        elseif thrusterUpgrade.id == "experimental-anti-momentum" then
            flameLength = 16
        end
        gfx.drawLine(exhaustX, exhaustY, exhaustX - (math.cos(radians) * flameLength), exhaustY - (math.sin(radians) * flameLength))
    end

    local shieldRadius = PLAYER_RADIUS + 3 + (self.playerShieldHits > 0 and 2 or 0)
    if self.playerShieldHits > 0 then
        if shieldUpgrade.id == "rotating-frequency" then
            local spin = math.rad((self.frame or 0) * 8)
            gfx.drawEllipseInRect(CENTER_X - shieldRadius - 4 + math.cos(spin) * 2, CENTER_Y - shieldRadius + math.sin(spin) * 2, (shieldRadius + 4) * 2, shieldRadius * 2)
        elseif shieldUpgrade.id == "dyson-shielding" then
            gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer8x8)
            gfx.fillCircleAtPoint(CENTER_X, CENTER_Y, shieldRadius + 1)
            gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
            gfx.drawCircleAtPoint(CENTER_X, CENTER_Y, shieldRadius + 1)
        else
            gfx.drawCircleAtPoint(CENTER_X, CENTER_Y, shieldRadius)
            if shieldUpgrade.id == "photonic-emitters" then
                gfx.drawCircleAtPoint(CENTER_X, CENTER_Y, shieldRadius + 2)
            end
        end
    end
end

function SpaceMiner:drawMiningBase()
    local drawX, drawY = worldToScreen(self.player.x, self.player.y, BASE_WORLD_X, BASE_WORLD_Y)
    if drawX < -42 or drawX > SCREEN_WIDTH + 42 or drawY < -42 or drawY > DASHBOARD_Y + 42 then
        return
    end

    gfx.setColor(gfx.kColorWhite)
    if self.baseImage ~= nil then
        self.baseImage:drawCentered(drawX, drawY)
    else
        gfx.drawCircleAtPoint(drawX, drawY, 21)
        gfx.drawCircleAtPoint(drawX, drawY, 13)
        gfx.drawRect(drawX - 8, drawY - 8, 16, 16)
        gfx.drawLine(drawX - 27, drawY, drawX - 14, drawY)
        gfx.drawLine(drawX + 14, drawY, drawX + 27, drawY)
        gfx.drawLine(drawX, drawY - 27, drawX, drawY - 14)
        gfx.drawLine(drawX, drawY + 14, drawX, drawY + 27)
    end

    if self:isBaseShieldActive() then
        local shieldRatio = clamp((self.baseShieldHits or BASE_SHIELD_MAX) / BASE_SHIELD_MAX, 0, 1)
        if self.baseShieldFlashFrames > 0 and (math.floor(self.baseShieldFlashFrames / 3) % 2 == 0) then
            gfx.setDitherPattern(0.45, gfx.image.kDitherTypeBayer8x8)
            gfx.fillCircleAtPoint(drawX, drawY, BASE_SHIELD_RADIUS)
            gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
        end
        gfx.drawCircleAtPoint(drawX, drawY, BASE_SHIELD_RADIUS)
        if shieldRatio > 0.66 then
            gfx.drawCircleAtPoint(drawX, drawY, BASE_SHIELD_RADIUS - 2)
        elseif shieldRatio > 0.33 then
            gfx.drawArc(drawX, drawY, BASE_SHIELD_RADIUS - 2, -80, 200)
        else
            gfx.drawArc(drawX, drawY, BASE_SHIELD_RADIUS - 2, -45, 90)
        end
    end

    if self.baseHealthBarEnabled then
        local barWidth = 48
        local barY = drawY - 40
        local ratio = clamp((self.baseShieldHits or BASE_SHIELD_MAX) / BASE_SHIELD_MAX, 0, 1)
        gfx.drawRect(drawX - barWidth * 0.5, barY, barWidth, 6)
        if ratio > 0 then
            gfx.fillRect(drawX - barWidth * 0.5 + 1, barY + 1, math.floor((barWidth - 2) * ratio), 4)
        end
    end

    if distanceSquared(self.player.x, self.player.y, BASE_WORLD_X, BASE_WORLD_Y) <= (BASE_PROXIMITY_RADIUS * BASE_PROXIMITY_RADIUS) then
        gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        gfx.drawTextAligned(self.baseName or "Home Base", drawX, drawY - 56, kTextAlignment.center)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
end

function SpaceMiner:drawHomeBaseCargoBeam()
    if not self:isWithinHomeBaseServiceRange() then
        return
    end

    local baseX, baseY = worldToScreen(self.player.x, self.player.y, BASE_WORLD_X, BASE_WORLD_Y)
    if baseX < -60 or baseX > SCREEN_WIDTH + 60 or baseY < -60 or baseY > DASHBOARD_Y + 60 then
        return
    end

    local pulse = math.floor((self.frame or 0) / 4) % 2
    local sourceX = baseX
    local sourceY = baseY
    local targetX = CENTER_X
    local targetY = CENTER_Y
    local dx = targetX - sourceX
    local dy = targetY - sourceY
    local nx, ny = unitVector(-dy, dx)
    local halfWidth = ((self.cargoOre or 0) > 0) and 3 or 1

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(sourceX, sourceY, targetX, targetY)
    if halfWidth > 1 then
        gfx.drawLine(sourceX + nx * halfWidth, sourceY + ny * halfWidth, targetX + nx * halfWidth, targetY + ny * halfWidth)
        gfx.drawLine(sourceX - nx * halfWidth, sourceY - ny * halfWidth, targetX - nx * halfWidth, targetY - ny * halfWidth)
    end
    if pulse == 0 and (self.cargoOre or 0) > 0 then
        gfx.setColor(gfx.kColorBlack)
        local midX = (sourceX + targetX) * 0.5
        local midY = (sourceY + targetY) * 0.5
        gfx.drawLine(midX - nx * halfWidth, midY - ny * halfWidth, midX + nx * halfWidth, midY + ny * halfWidth)
        gfx.setColor(gfx.kColorWhite)
    end
    if self:isRepairBeamActive() then
        local segments = 6
        local offsetSign = (math.floor((self.frame or 0) / 3) % 2 == 0) and 1 or -1
        for line = -1, 1, 2 do
            local lastX = sourceX + nx * line * 5
            local lastY = sourceY + ny * line * 5
            for index = 1, segments do
                local t = index / segments
                local jitter = ((index % 2 == 0) and 5 or -5) * offsetSign
                local nextX = sourceX + (dx * t) + (nx * line * 5) + (nx * jitter)
                local nextY = sourceY + (dy * t) + (ny * line * 5) + (ny * jitter)
                if index == segments then
                    nextX = targetX + nx * line * 5
                    nextY = targetY + ny * line * 5
                end
                gfx.drawLine(lastX, lastY, nextX, nextY)
                lastX = nextX
                lastY = nextY
            end
        end
    end
end

function SpaceMiner:drawBasePointer()
    local drawX, drawY = worldToScreen(self.player.x, self.player.y, BASE_WORLD_X, BASE_WORLD_Y)
    if drawX >= 0 and drawX <= SCREEN_WIDTH and drawY >= 0 and drawY <= DASHBOARD_Y then
        return
    end

    local dx = BASE_WORLD_X - self.player.x
    local dy = BASE_WORLD_Y - self.player.y
    local angle = math.atan(dy, dx)
    local edgeX = CENTER_X + math.cos(angle) * (SCREEN_WIDTH * 0.5 - 18)
    local edgeY = CENTER_Y + math.sin(angle) * (DASHBOARD_Y * 0.5 - 18)
    edgeY = clamp(edgeY, 14, DASHBOARD_Y - 14)
    local tipX = edgeX + math.cos(angle) * 8
    local tipY = edgeY + math.sin(angle) * 8
    local leftX = edgeX + math.cos(angle + 2.45) * 6
    local leftY = edgeY + math.sin(angle + 2.45) * 6
    local rightX = edgeX + math.cos(angle - 2.45) * 6
    local rightY = edgeY + math.sin(angle - 2.45) * 6
    local km = math.floor((math.sqrt((dx * dx) + (dy * dy)) / (ASTEROID_STAGE_CONFIG[0].radius * 2)) * BASE_LARGE_ASTEROID_KM + 0.5)

    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(tipX, tipY, leftX, leftY)
    gfx.drawLine(tipX, tipY, rightX, rightY)
    gfx.drawLine(leftX, leftY, rightX, rightY)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawTextAligned(tostring(km) .. "km", edgeX, edgeY + 9, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
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
                local dither = lateStageGhostMediumAsteroids and math.max(0.35, MEDIUM_ASTEROID_GRAY_DITHER - 0.12) or MEDIUM_ASTEROID_GRAY_DITHER
                gfx.setDitherPattern(clamp(dither, 0.1, 0.9), gfx.image.kDitherTypeBayer8x8)
                gfx.fillCircleAtPoint(drawX, drawY, asteroid.radius)
                gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
                if MEDIUM_ASTEROID_TEXTURE_ENABLED and asteroid.blotches ~= nil then
                    gfx.setColor(gfx.kColorWhite)
                    for _, blotch in ipairs(asteroid.blotches) do
                        gfx.fillCircleAtPoint(drawX + blotch.x, drawY + blotch.y, blotch.radius)
                    end
                end
            else
                gfx.fillCircleAtPoint(drawX, drawY, asteroid.radius)
                gfx.setColor(gfx.kColorBlack)
                gfx.fillCircleAtPoint(drawX + 1, drawY - 1, math.max(1, asteroid.radius - 8))
                gfx.drawLine(drawX - asteroid.radius * 0.35, drawY + asteroid.radius * 0.2, drawX + asteroid.radius * 0.5, drawY - asteroid.radius * 0.18)
                gfx.setColor(gfx.kColorWhite)
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
    local autoTarget = self:getAutoMissileEnemyTarget()
    for _, enemy in ipairs(self.enemyShips) do
        local drawX, drawY = worldToScreen(self.player.x, self.player.y, enemy.x, enemy.y)
        local half = enemy.size
        if enemy.type == "striker" then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillTriangle(drawX - half + 1, drawY + half - 1, drawX, drawY - half, drawX + half - 1, drawY + half - 1)
            gfx.setColor(gfx.kColorWhite)
            gfx.drawLine(drawX - half, drawY + half, drawX, drawY - half - 2)
            gfx.drawLine(drawX, drawY - half - 2, drawX + half, drawY + half)
            gfx.drawLine(drawX - half, drawY + half, drawX + half, drawY + half)
        else
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(drawX - half + 1, drawY - half + 1, (half * 2) - 2, (half * 2) - 2)
            gfx.setColor(gfx.kColorWhite)
            gfx.drawRect(drawX - half, drawY - half, half * 2, half * 2)
        end
        if enemy == autoTarget then
            gfx.drawRect(drawX - half - 4, drawY - half - 4, (half * 2) + 8, (half * 2) + 8)
        end
    end
end

function SpaceMiner:drawMissiles()
    gfx.setColor(gfx.kColorWhite)
    for _, missile in ipairs(self.player.missiles or {}) do
        local drawX, drawY = worldToScreen(self.player.x, self.player.y, missile.x, missile.y)
        local radians = math.atan(missile.vy, missile.vx)
        local tailX = drawX - (math.cos(radians) * PLAYER_MISSILE_DRAW_LENGTH)
        local tailY = drawY - (math.sin(radians) * PLAYER_MISSILE_DRAW_LENGTH)
        if missile.visual == "advanced-guided" then
            gfx.drawRect(drawX - 3, drawY - 2, 7, 4)
            gfx.drawLine(tailX - math.cos(radians) * 5, tailY - math.sin(radians) * 5, drawX, drawY)
        else
            gfx.drawLine(tailX, tailY, drawX, drawY)
            gfx.fillCircleAtPoint(drawX, drawY, PLAYER_MISSILE_DRAW_RADIUS)
        end
    end

    for _, missile in ipairs(self.enemyMissiles) do
        local drawX, drawY = worldToScreen(self.player.x, self.player.y, missile.x, missile.y)
        if missile.heatSeeking then
            gfx.drawCircleAtPoint(drawX, drawY, 3)
            gfx.fillCircleAtPoint(drawX, drawY, 1)
        else
            gfx.drawCircleAtPoint(drawX, drawY, 2)
        end
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
    local upgrade = self:getActiveUpgrade("laser") or {}
    if upgrade.id == "advanced-laser" or upgrade.id == "advanced-splaser" then
        local nx = math.cos(radians + math.pi * 0.5)
        local ny = math.sin(radians + math.pi * 0.5)
        gfx.drawLine(CENTER_X + nx, CENTER_Y + ny, endX + nx, endY + ny)
        gfx.drawLine(CENTER_X - nx, CENTER_Y - ny, endX - nx, endY - ny)
    end
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
    local showHud = not UIState or UIState.isShown()

    if showHud then
        gfx.setColor(gfx.kColorWhite)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        if self:isEndlessMode() then
            gfx.drawText("Ore Mining", 8, 8)
            gfx.drawText(string.format("Asteroids %d", self.minedChunks or 0), 8, 24)
            gfx.drawText(string.format("Cash $%d", self.cash or 0), 8, 40)
        else
            gfx.drawText("Space Miner", 8, 8)
            gfx.drawText(self.stageLabel, 8, 24)
            gfx.drawText(string.format("Score %d", self.score), 8, 40)
            gfx.drawText(string.format("Cash $%d", self.cash or 0), 8, 56)
            gfx.drawText(string.format("Shield %d%%  Hull %d", self.playerShieldHits, self.playerHullHits), 8, 72)
            gfx.drawText(string.format("Vel %.1f", magnitude(self.player.vx, self.player.vy)), 8, 88)
        end
    end

    self:drawBottomBlockUi()

    if self.gameOver then
        gfx.setColor(gfx.kColorWhite)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        gfx.drawTextAligned("Ship Disabled", 200, 92, kTextAlignment.center)
        gfx.drawTextAligned("Ship Disabled", 201, 92, kTextAlignment.center)
        gfx.drawTextAligned("Ship Disabled", 200, 93, kTextAlignment.center)
        gfx.drawTextAligned("Press A to restart", 200, 116, kTextAlignment.center)
        gfx.drawTextAligned("Press B to return.", 200, 132, kTextAlignment.center)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
end

function SpaceMiner:drawDashboardShip()
    local radians = math.rad(self.player.angle)
    local offset = self.dashboardStickOffset or 0
    local centerX = DASHBOARD_CENTER_X + (math.cos(radians) * offset)
    local centerY = DASHBOARD_CENTER_Y + (math.sin(radians) * offset)
    local noseX = centerX + (math.cos(radians) * 6)
    local noseY = centerY + (math.sin(radians) * 6)
    local leftX = centerX + (math.cos(radians + 2.45) * 5)
    local leftY = centerY + (math.sin(radians + 2.45) * 5)
    local rightX = centerX + (math.cos(radians - 2.45) * 5)
    local rightY = centerY + (math.sin(radians - 2.45) * 5)

    gfx.setColor(gfx.kColorWhite)
    gfx.drawCircleAtPoint(DASHBOARD_CENTER_X, DASHBOARD_CENTER_Y, 6)
    gfx.fillCircleAtPoint(centerX, centerY, 2)
    gfx.drawLine(noseX, noseY, leftX, leftY)
    gfx.drawLine(noseX, noseY, rightX, rightY)
    gfx.drawLine(leftX, leftY, rightX, rightY)
end

function SpaceMiner:getShieldMeterRatio()
    local shieldMax = self.playerShieldMax or SHIELD_MAX
    local shield = clamp(self.playerShieldHits or 0, 0, shieldMax)
    local recharge = 0
    if SHIELD_RECHARGE_STEP_FRAMES > 0
        and self.framesSincePlayerDamage >= SHIELD_RECHARGE_DELAY_FRAMES
        and shield < shieldMax then
        recharge = clamp((self.shieldRechargeFrames or 0) / SHIELD_RECHARGE_STEP_FRAMES, 0, 1) * SHIELD_RECHARGE_AMOUNT
    end
    return clamp((shield + recharge) / shieldMax, 0, 1)
end

function SpaceMiner:drawDashboardShield()
    local ratio = clamp(self.dashboardShieldRatio or self:getShieldMeterRatio(), 0, 1)
    local fillWidth = math.floor((DASHBOARD_SHIELD_BAR_WIDTH - 2) * ratio + 0.5)

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(DASHBOARD_SHIELD_BAR_X, DASHBOARD_SHIELD_BAR_Y, DASHBOARD_SHIELD_BAR_WIDTH, DASHBOARD_SHIELD_BAR_HEIGHT)
    if fillWidth > 0 then
        gfx.fillRect(DASHBOARD_SHIELD_BAR_X + 1, DASHBOARD_SHIELD_BAR_Y + 1, fillWidth, DASHBOARD_SHIELD_BAR_HEIGHT - 2)
    end
end

function SpaceMiner:drawDashboardHull()
    local hull = clamp(self.playerHullHits or 0, 0, DASHBOARD_HULL_BLOCK_COUNT)
    gfx.setColor(gfx.kColorWhite)
    for index = 1, DASHBOARD_HULL_BLOCK_COUNT do
        local x = DASHBOARD_HULL_X + ((index - 1) * (DASHBOARD_HULL_BLOCK_WIDTH + DASHBOARD_HULL_BLOCK_GAP))
        local active = index <= hull
        if active then
            gfx.drawRect(x, DASHBOARD_HULL_Y, DASHBOARD_HULL_BLOCK_WIDTH, DASHBOARD_HULL_BLOCK_HEIGHT)
            gfx.drawLine(x + 2, DASHBOARD_HULL_Y + 5, x + DASHBOARD_HULL_BLOCK_WIDTH - 3, DASHBOARD_HULL_Y + 5)
            gfx.drawLine(x + 4, DASHBOARD_HULL_Y + 2, x + 4, DASHBOARD_HULL_Y + DASHBOARD_HULL_BLOCK_HEIGHT - 3)
        else
            gfx.drawRect(x, DASHBOARD_HULL_Y, DASHBOARD_HULL_BLOCK_WIDTH, DASHBOARD_HULL_BLOCK_HEIGHT)
        end
    end
end

function SpaceMiner:drawDashboardText()
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawText("Shield", DASHBOARD_SHIELD_LABEL_X, DASHBOARD_TEXT_Y)
    gfx.drawText(string.format("O:%d", self.minedChunks or 0), DASHBOARD_ORE_X, DASHBOARD_TEXT_Y)
    gfx.drawText(string.format("E:%d", self.destroyedEnemies or 0), DASHBOARD_ENEMY_X, DASHBOARD_TEXT_Y)
    gfx.drawText(string.format("$%d", self.cash or 0), DASHBOARD_ENEMY_X + 38, DASHBOARD_TEXT_Y)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function SpaceMiner:drawBottomBlockUi()
    if self.preview then
        return
    end

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, DASHBOARD_Y, SCREEN_WIDTH, DASHBOARD_HEIGHT)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(0, DASHBOARD_Y, SCREEN_WIDTH, DASHBOARD_Y)
    gfx.drawLine(DASHBOARD_CENTER_X - (DASHBOARD_CENTER_WIDTH * 0.5), DASHBOARD_Y + 1, DASHBOARD_CENTER_X - (DASHBOARD_CENTER_WIDTH * 0.5), SCREEN_HEIGHT - 1)
    gfx.drawLine(DASHBOARD_CENTER_X + (DASHBOARD_CENTER_WIDTH * 0.5), DASHBOARD_Y + 1, DASHBOARD_CENTER_X + (DASHBOARD_CENTER_WIDTH * 0.5), SCREEN_HEIGHT - 1)

    self:drawDashboardShield()
    self:drawDashboardShip()
    self:drawDashboardHull()
    self:drawDashboardText()
    gfx.setColor(gfx.kColorWhite)
end

function SpaceMiner:drawInstructionOverlay()
    if self.preview or self.instructionOverlayFrames <= 0 then
        return
    end

    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(38, 48, 324, 104, 8)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawTextAligned("Space Miner", 200, 61, kTextAlignment.center)
    gfx.drawTextInRect("Crank turns the ship. Up/Down thrust. Hold Left to mine. Right launches or detonates a missile.", 58, 84, 284, 38, nil, nil, kTextAlignment.center)
    gfx.drawTextAligned("Mine asteroids for ore and score.", 200, 126, kTextAlignment.center)
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

function SpaceMiner:drawTinyConsoleText(text, x, y, colorProvider)
    local cursorX = x
    local upper = string.upper(tostring(text or ""))
    for index = 1, #upper do
        local char = string.sub(upper, index, index)
        if type(colorProvider) == "function" then
            gfx.setColor(colorProvider(cursorX, char) or gfx.kColorWhite)
        else
            gfx.setColor(colorProvider or gfx.kColorWhite)
        end
        if char == "-" then
            gfx.drawLine(cursorX, y + 2, cursorX + 2, y + 2)
            cursorX = cursorX + 4
        elseif char == " " then
            cursorX = cursorX + 3
        else
            gfx.drawRect(cursorX, y, 3, 5)
            if char == "Y" or char == "S" then
                gfx.drawLine(cursorX, y + 2, cursorX + 2, y + 2)
            end
            cursorX = cursorX + 5
        end
    end
end

function SpaceMiner:wrapCommunicationText(text)
    local lines = {}
    local function appendWrapped(rawLine)
        local current = ""
        for word in string.gmatch(tostring(rawLine or ""), "%S+") do
            if #word > COMMUNICATION_LINE_CHAR_LIMIT then
                error(string.format("Space Miner communication word too long: %s", word))
            end

            local candidate = current == "" and word or (current .. " " .. word)
            if #candidate <= COMMUNICATION_LINE_CHAR_LIMIT then
                current = candidate
            else
                if string.sub(current, -1) == ":" then
                    error(string.format("Space Miner communication prefix cannot stand alone: %s", current))
                end
                lines[#lines + 1] = current
                current = word
            end
        end
        if current ~= "" then
            if string.sub(current, -1) == ":" then
                error(string.format("Space Miner communication prefix cannot stand alone: %s", current))
            end
            lines[#lines + 1] = current
        end
    end

    local source = tostring(text or "")
    local startIndex = 1
    while startIndex <= #source do
        local newline = string.find(source, "\n", startIndex, true)
        if newline == nil then
            appendWrapped(string.sub(source, startIndex))
            break
        end
        appendWrapped(string.sub(source, startIndex, newline - 1))
        startIndex = newline + 1
    end
    if #source == 0 then
        lines[1] = ""
    end
    if #lines > COMMUNICATION_MAX_LINES then
        error(string.format("Space Miner communication too long: %d lines exceeds %d", #lines, COMMUNICATION_MAX_LINES))
    end
    return lines
end

function SpaceMiner:drawCommunicationBox(message, filled)
    if message == nil then
        return
    end

    local fade = self:getCommunicationFade(message)
    if fade <= 0 then
        return
    end

    local x = message.x or 8
    local y = message.y or 8
    local width = message.width or COMMUNICATION_WIDTH
    local ok, linesOrError = pcall(function()
        return self:wrapCommunicationText(message.text)
    end)
    local lines = ok and linesOrError or { "COMM TEXT ERROR", tostring(linesOrError or "") }
    if not ok and StarryLog and StarryLog.error then
        StarryLog.error("%s", tostring(linesOrError))
    end
    local height = math.min(DASHBOARD_Y - y - 4, COMMUNICATION_BOX_PADDING + (#lines * COMMUNICATION_LINE_SPACING))
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(filled and 0.72 or 0.48, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRoundRect(x - 2, y - 2, width + 4, height + 4, 5)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(x, y, width, height, 4)
    gfx.drawLine(x + 6, y + 13, x + width - 6, y + 13)
    self:drawTinyConsoleText("SYS-COM", x + 7, y + 4)
    gfx.setDitherPattern(math.max(0.12, fade), gfx.image.kDitherTypeBayer8x8)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    for index, line in ipairs(lines) do
        local lineY = y + 18 + ((index - 1) * COMMUNICATION_LINE_SPACING)
        if lineY < y + height - 8 then
            gfx.drawText(line, x + 7, lineY)
        end
    end
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function SpaceMiner:drawCommunication()
    self:drawCommunicationBox(self:getActiveCommunication(), false)
end

function SpaceMiner:drawHomeMenuScoutCommunication()
    if not (self.menuOpen and self.menuType == "home") or self.homeMenuScoutHidden then
        return
    end
    if self.homeMenuMessage == nil or self.homeMenuMessage == "" then
        return
    end

    self:drawCommunicationBox({
        text = self.homeMenuMessage,
        startFrame = self.frame,
        endFrame = self.frame + 120,
        x = SCREEN_WIDTH - COMMUNICATION_WIDTH - 8,
        y = 8,
        width = COMMUNICATION_WIDTH
    }, true)
end

function SpaceMiner:draw()
    gfx.clear(gfx.kColorBlack)
    gfx.setColor(gfx.kColorWhite)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    self:drawBackgroundStars()
    self:drawDistantStar()
    self:drawDecorLayer("back")
    if self:isStoryMode() then
        self:drawMiningBase()
        self:drawHomeBaseCargoBeam()
        self:drawBasePointer()
    end
    self:drawAsteroids()
    self:drawEnemies()
    self:drawShip()
    self:drawMissiles()
    self:drawExplosions()
    self:drawLaser()
    if self:isStoryMode() then
        self:drawAlert()
    end
    self:drawDecorLayer("front")
    self:drawMaterialMiniMap()
    self:drawCargoSpaceBar()
    self:drawHud()
    self:drawInstructionOverlay()
    if self:isStoryMode() then
        self:drawCommunication()
    end
    self:drawMenu()
    self:drawHomeMenuScoutCommunication()
    if (self.supernovaFlashFrames or 0) > 0 then
        gfx.setColor(gfx.kColorWhite)
        gfx.setDitherPattern(clamp(self.supernovaFlashFrames / 24, 0.1, 1), gfx.image.kDitherTypeBayer8x8)
        gfx.fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
        gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    end
end
