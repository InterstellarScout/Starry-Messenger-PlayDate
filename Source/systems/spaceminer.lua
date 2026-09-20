import "gameconfig"
import "data/spaceminerwaves"
import "data/spaceminerwaves_oreminer"

import "CoreLibs/graphics"
import "CoreLibs/keyboard"
import "audio/spaceminer_sfx"

local pd <const> = playdate
local gfx <const> = pd.graphics
local SPACE_MINER_CONFIG <const> = GameConfig and GameConfig.spaceMiner or {}
local STORY_CONFIG <const> = SPACE_MINER_CONFIG.story or SpaceMinerWaveConfig or {}
local OREMINER_CONFIG <const> = SPACE_MINER_CONFIG.oreMiner or SPACE_MINER_CONFIG.ore or SpaceMinerOreMinerWaveConfig or {}
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
SpaceMiner.MODE_CONTINUE_STORY = "continue-story"
SpaceMiner.MODE_NEW_SAVE = "new-save"
SpaceMiner.MODE_OREMINER = "endless-ore"
-- Keep the current title catalog's established mode name compatible with the
-- richer former implementation.
SpaceMiner.MODE_ENDLESS = SpaceMiner.MODE_OREMINER
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
local CARGO_UNLOAD_PROGRESS_PER_FRAME <const> = 1.4
local MENU_BACKGROUND_STAR_COUNT <const> = SPACE_MINER_CONFIG.menuBackgroundStarCount or 900
local ORE_SALE_PRICE_MULTIPLIER <const> = SPACE_MINER_CONFIG.oreSalePriceMultiplier or 1
local UPGRADE_COST_MULTIPLIER <const> = SPACE_MINER_CONFIG.upgradeCostMultiplier or 1
local HOME_BASE_MENU_RADIUS <const> = SPACE_MINER_CONFIG.homeBaseMenuRadius or 20
local ENTITY_LOG_INTERVAL_FRAMES_RAW <const> = SPACE_MINER_CONFIG.entityLogIntervalFrames or 180
local ENTITY_LOG_INTERVAL_FRAMES <const> = math.max(30, ENTITY_LOG_INTERVAL_FRAMES_RAW)
local SHIP_REPAIR_SHIELD_PER_SECOND <const> = SPACE_MINER_CONFIG.shipRepairShieldPercentPerSecond or 0.10
local SHIP_REPAIR_HULL_STEP_FRAMES <const> = SPACE_MINER_CONFIG.shipRepairHullStepFrames or 30
local AUTO_MISSILE_SHOTS_PER_SECOND <const> = SPACE_MINER_CONFIG.autoMissileShotsPerSecond or 12
local MENU_AUTO_NAVIGATE_ENABLED <const> = SPACE_MINER_CONFIG.menuAutoNavigateEnabled ~= false
local MENU_AUTO_NAVIGATE_RADIUS <const> = SPACE_MINER_CONFIG.menuAutoNavigateRadius or 180
local MENU_AUTO_NAVIGATE_ACCELERATION <const> = SPACE_MINER_CONFIG.menuAutoNavigateAcceleration or 0.026
local MENU_AUTO_NAVIGATE_MAX_SPEED <const> = SPACE_MINER_CONFIG.menuAutoNavigateMaxSpeed or 1.1
local MENU_CRANK_STEP <const> = SPACE_MINER_CONFIG.menuCrankStep or 45
local MENU_DPAD_HOLD_SPIN_FRAMES <const> = SPACE_MINER_CONFIG.menuDpadHoldSpinFrames or 14
local MENU_DPAD_STEP_VELOCITY <const> = SPACE_MINER_CONFIG.menuDpadStepVelocity or 0.72
local MENU_DPAD_STEP_IMPULSE <const> = SPACE_MINER_CONFIG.menuDpadStepImpulse or 0.4
local MENU_KEYBOARD_DPAD_HOLD_DELAY_FRAMES <const> = SPACE_MINER_CONFIG.keyboardDpadHoldDelayFrames or 30
local MENU_KEYBOARD_DPAD_REPEAT_INTERVAL_FRAMES <const> = SPACE_MINER_CONFIG.keyboardDpadRepeatIntervalFrames or 4
local PLAYER_AUTO_LASER_RANGE <const> = SPACE_MINER_CONFIG.playerAutoLaserRange or 150
local PLAYER_AUTO_LASER_DAMAGE <const> = SPACE_MINER_CONFIG.playerAutoLaserDamage or 3
local PLAYER_AUTO_LASER_COOLDOWN_FRAMES <const> = SPACE_MINER_CONFIG.playerAutoLaserCooldownFrames or 12
local BASE_MINING_LASER_RANGE_MULTIPLIER <const> = SPACE_MINER_CONFIG.baseMiningLaserRangeMultiplier or 4
local BASE_MINING_LASER_COOLDOWN_FRAMES <const> = SPACE_MINER_CONFIG.baseMiningLaserCooldownFrames or 18
local BASE_MINING_LASER_ASTEROID_DAMAGE <const> = SPACE_MINER_CONFIG.baseMiningLaserAsteroidDamage or 999
local BASE_MINING_LASER_ENEMY_DAMAGE <const> = SPACE_MINER_CONFIG.baseMiningLaserEnemyDamage or 2
local BASE_MINING_LASER_ENEMY_DAMAGE_MULTIPLIER <const> = SPACE_MINER_CONFIG.baseMiningLaserEnemyDamageMultiplier or 0.5
local MAX_ACTIVE_ENTITIES <const> = SPACE_MINER_CONFIG.maxActiveEntities or 54
local ASTEROID_FRAGMENT_ENTITY_LIMIT <const> = SPACE_MINER_CONFIG.asteroidFragmentEntityLimit or math.floor(MAX_ACTIVE_ENTITIES * 1.25)
local ASTEROID_LAYER_COLLISION_LIMIT_PER_FRAME <const> = SPACE_MINER_CONFIG.asteroidLayerCollisionLimitPerFrame or 6
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
local STORY_SAVE_KEY <const> = "spaceminer-story-v2-save"
local STORY_SAVE_SLOT_PREFIX <const> = "spaceminer-story-v2-save-"
local STORY_SAVE_INDEX_KEY <const> = "spaceminer-story-v2-save-index"
local STORY_SAVE_SLOT_COUNT <const> = 3
local STORY_SAVE_EMPTY_SLOT_NAME <const> = "(New Save)"
local SPACE_MINER_FORCE_CLEAR_STORY_SAVES <const> = true
local STORY_NAME_KEYBOARD_ROWS <const> = {
    { "q", "w", "e", "r", "t", "y", "u", "i", "o", "p" },
    { "a", "s", "d", "f", "g", "h", "j", "k", "l" },
    { "z", "x", "c", "v", "b", "n", "m" },
    { "Shift", "Caps", "Space", "Del", "Enter" }
}
local OREMINER_SAVE_KEY <const> = "spaceminer-oreminer-save"
local MINIMAP_X <const> = 336
local MINIMAP_Y <const> = 12
local MINIMAP_WIDTH <const> = 54
local MINIMAP_HEIGHT <const> = 38
local MINIMAP_RANGE <const> = 520
local CARGO_BAR_X <const> = MINIMAP_X
local CARGO_BAR_Y <const> = MINIMAP_Y + MINIMAP_HEIGHT + 3
local CARGO_BAR_WIDTH <const> = MINIMAP_WIDTH
local CARGO_BAR_HEIGHT <const> = 11
local HOME_MENU_SCOUT_BACKDROP_DITHER <const> = SPACE_MINER_CONFIG.homeMenuScoutBackdropDither or 0.90
local MINER_MENU_ROW_HEIGHT <const> = 18
local COMMUNICATION_LINE_CHAR_LIMIT <const> = SPACE_MINER_CONFIG.communicationLineCharLimit or 22
local COMMUNICATION_MAX_LINES <const> = SPACE_MINER_CONFIG.communicationMaxLines or 8
local COMMUNICATION_LINE_SPACING <const> = SPACE_MINER_CONFIG.communicationLineSpacing or 15
local COMMUNICATION_BOX_PADDING <const> = SPACE_MINER_CONFIG.communicationBoxPadding or 28
local COMMUNICATION_WIDTH <const> = SPACE_MINER_CONFIG.communicationWidth or math.floor(SCREEN_WIDTH * 0.5) - 14
local COMMUNICATION_MIN_FRAMES <const> = SPACE_MINER_CONFIG.communicationMinFrames or 90
local COMMUNICATION_FRAMES_PER_CHAR <const> = SPACE_MINER_CONFIG.communicationFramesPerChar or 2.2
local BASE_SHIELD_RADIUS <const> = BASE_CONFIG.shieldRadius or 56
local BASE_DRAW_MARGIN <const> = BASE_SHIELD_RADIUS + 18
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
local WORLD_UNITS_PER_GRID_KM <const> = (ASTEROID_STAGE_CONFIG[0].radius * 2) / BASE_LARGE_ASTEROID_KM

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
    },
    misc = {
        screen = "misc",
        title = "Misc Upgrades",
        configKey = "miscUpgrades",
        ownedKey = "ownedMiscUpgrades",
        activeKey = "activeMiscUpgrade",
        defaultId = "no-misc"
    },
    base = {
        screen = "base",
        title = "Base Upgrades",
        configKey = "baseUpgrades",
        ownedKey = "ownedBaseUpgrades",
        activeKey = "activeBaseUpgrade",
        defaultId = "base-standard"
    }
}

local HOME_MENU_SCREENS <const> = {
    { id = "laser", label = "Laser Upgrades" },
    { id = "missile", label = "Missile Upgrades" },
    { id = "shield", label = "Shield Upgrades" },
    { id = "thruster", label = "Thruster Upgrades" },
    { id = "cargo", label = "Cargo Space" },
    { id = "misc", label = "Misc Upgrades" },
    { id = "base", label = "Base Upgrades" },
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

local function normalizeButtonList(rawButtons)
    local buttons = {}
    local seen = {}
    local source = rawButtons
    if type(source) == "string" then
        source = { source }
    end
    if type(source) ~= "table" then
        return buttons
    end
    for _, rawButton in ipairs(source) do
        local button = tostring(rawButton or ""):upper()
        if button ~= "" and not seen[button] then
            seen[button] = true
            buttons[#buttons + 1] = button
        end
    end
    return buttons
end

local function isButtonDisabled(buttons, buttonName)
    local target = tostring(buttonName or ""):upper()
    for _, button in ipairs(buttons or {}) do
        if button == target then
            return true
        end
    end
    return false
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
            alertText = rawStage.alertText or DEFAULT_ALERT_TEXT,
            continueAfterCompleted = rawStage.continueAfterCompleted == true
        }
        stage.entries = {}
        stage.actions = {}
        stage.communications = {}
        stage.communicationBlockEntries = {}

        if stage.kind == "mining" then
            stage.durationFrames = parseFrameCount(rawStage.durationFrames or rawStage.duration or 0)
        elseif stage.kind == "communication-block" then
            stage.durationFrames = 0
        elseif stage.kind == "objective" or stage.kind == "wave" then
            local rawTrigger = rawStage.trigger or {}
            stage.trigger = {
                type = rawTrigger.type or "after_stage_clear",
                timestampFrames = parseFrameCount(rawTrigger.timestampFrames or rawTrigger.timestamp or rawTrigger.offset or rawTrigger.offsetFrames or 0),
                delayFrames = parseFrameCount(rawTrigger.delayFrames or rawTrigger.delay or 0)
            }
            local rawObjective = rawStage.objective or {}
            stage.objective = {
                ore = math.max(0, math.floor(tonumber(rawObjective.ore or rawObjective.minedOre or rawStage.collectOre or rawStage.ore or 0) or 0)),
                enemies = math.max(0, math.floor(tonumber(rawObjective.enemies or rawObjective.destroyEnemies or rawStage.destroyEnemies or rawStage.enemies or 0) or 0))
            }
            if stage.objective.ore <= 0 and stage.objective.enemies <= 0 then
                stage.objective = nil
            end
        else
            local rawTrigger = rawStage.trigger or {}
            stage.trigger = {
                type = rawTrigger.type or "after_stage_clear",
                timestampFrames = parseFrameCount(rawTrigger.timestampFrames or rawTrigger.timestamp or rawTrigger.offset or rawTrigger.offsetFrames or 0),
                delayFrames = parseFrameCount(rawTrigger.delayFrames or rawTrigger.delay or 0)
            }
        end

        for entryIndex, rawEntry in ipairs(rawStage.entries or {}) do
            local isCommunicationEntry = rawEntry.text ~= nil or rawEntry.message ~= nil or rawEntry.kind == "communication" or rawEntry.type == "communication"
            if isCommunicationEntry then
                local text = rawEntry.text or rawEntry.message or ""
                local durationFrames = parseFrameCount(rawEntry.durationFrames or rawEntry.duration or "0:03:00")
                local readableFrames = math.max(COMMUNICATION_MIN_FRAMES, math.floor(#text * COMMUNICATION_FRAMES_PER_CHAR))
                local message = {
                    id = rawEntry.id or string.format("%s-message-%d", stage.id, entryIndex),
                    timestampFrames = rawEntry.timestamp ~= nil and parseFrameCount(rawEntry.timestamp) or rawEntry.timestampFrames,
                    offsetFrames = rawEntry.offset ~= nil and parseFrameCount(rawEntry.offset) or parseFrameCount(rawEntry.offsetFrames or 0),
                    durationFrames = math.max(1, durationFrames, readableFrames),
                    text = text,
                    x = rawEntry.x or 8,
                    y = rawEntry.y or 8,
                    width = rawEntry.width or COMMUNICATION_WIDTH,
                    requiredButton = string.upper(tostring(rawEntry.requiredButton or rawEntry["required-button"] or rawEntry.button or "A")),
                    disableButtons = normalizeButtonList(rawEntry.disableButtons or rawEntry.disableButton or rawEntry["disable-button"])
                }
                if stage.kind == "communication-block" then
                    stage.communicationBlockEntries[#stage.communicationBlockEntries + 1] = message
                else
                    stage.communications[#stage.communications + 1] = message
                end
            elseif rawEntry.action ~= nil then
                stage.actions[#stage.actions + 1] = {
                    id = rawEntry.id or string.format("%s-action-%d", stage.id, entryIndex),
                    action = rawEntry.action,
                    entity = rawEntry.entity or rawEntry.target or rawEntry.name,
                    destination = rawEntry.destination or rawEntry.coordinates or rawEntry.coordinate,
                    speed = rawEntry.speed,
                    mode = rawEntry.mode or rawEntry.baseMode or rawEntry.targetMode,
                    timestampFrames = rawEntry.timestamp ~= nil and parseFrameCount(rawEntry.timestamp) or rawEntry.timestampFrames,
                    offsetFrames = rawEntry.offset ~= nil and parseFrameCount(rawEntry.offset) or parseFrameCount(rawEntry.offsetFrames or 0)
                }
            elseif stage.kind ~= "mining" then
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
        end

        if stage.kind ~= "mining" and stage.kind ~= "communication-block" then
            table.sort(stage.entries, function(left, right)
                local leftTime = left.timestampFrames or left.offsetFrames or 0
                local rightTime = right.timestampFrames or right.offsetFrames or 0
                if leftTime == rightTime then
                    return left.id < right.id
                end
                return leftTime < rightTime
            end)

            if stage.trigger and stage.trigger.type == "time" then
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
        table.sort(stage.communications, function(left, right)
            local leftTime = left.timestampFrames or left.offsetFrames or 0
            local rightTime = right.timestampFrames or right.offsetFrames or 0
            if leftTime == rightTime then
                return left.id < right.id
            end
            return leftTime < rightTime
        end)
        table.sort(stage.actions, function(left, right)
            local leftTime = left.timestampFrames or left.offsetFrames or 0
            local rightTime = right.timestampFrames or right.offsetFrames or 0
            if leftTime == rightTime then
                return left.id < right.id
            end
            return leftTime < rightTime
        end)

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
            action = rawEntry.action,
            mode = rawEntry.mode or rawEntry.baseMode or rawEntry.targetMode,
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

local STORY_STAGE_SCHEDULE <const> = normalizeWaveSchedule(STORY_CONFIG)
local OREMINER_STAGE_SCHEDULE <const> = normalizeWaveSchedule(OREMINER_CONFIG)
local OREMINER_COMMUNICATION_SCHEDULE <const> = normalizeCommunicationSchedule(OREMINER_CONFIG.communications or {})
local BASE_TIMELINE <const> = normalizeBaseTimeline(BASE_CONFIG.timeline)
local SETTINGS_TIMELINE <const> = normalizeSettingsTimeline(STORY_CONFIG.settingsTimeline)
local BASE_MODES <const> = BASE_CONFIG.modes or {}
local BASE_MODE_TRANSITION_FRAMES <const> = BASE_CONFIG.modeTransitionFrames or 60

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

local function lerpAngle(startAngle, endAngle, t)
    return normalizeAngle(startAngle + (shortestAngleDelta(startAngle, endAngle) * clamp(t, 0, 1)))
end

local function velocityToScreenDegrees(vx, vy)
    if math.abs(vx) < 0.0001 and math.abs(vy) < 0.0001 then
        return nil
    end
    return normalizeAngle(math.deg(math.atan(vy, vx)) + 90)
end

local function makeMenuBackgroundStar(size, x, y, depth, kind, extra)
    return {
        x = x,
        y = y,
        size = size,
        depth = depth,
        kind = kind or "star",
        extra = extra
    }
end

local function createMenuBackgroundStars()
    local stars = {}
    local function addStar(x, y, size, depth, kind, extra)
        stars[#stars + 1] = makeMenuBackgroundStar(size, x, y, depth, kind, extra)
    end

    local clusterCount = 18
    local galaxyCount = 6
    local clusterSize = 6
    local galaxyStarCount = 12
    local fieldBudget = math.max(0, MENU_BACKGROUND_STAR_COUNT - (clusterCount * clusterSize) - (galaxyCount * galaxyStarCount))

    for _ = 1, fieldBudget do
        local depth = math.random()
        local size = depth < 0.25 and 1 or (depth < 0.75 and 2 or 3)
        addStar(
            math.random(2, SCREEN_WIDTH - 2),
            math.random(2, SCREEN_HEIGHT - 2),
            size,
            depth,
            "star"
        )
    end

    for _ = 1, clusterCount do
        local centerX = math.random(24, SCREEN_WIDTH - 24)
        local centerY = math.random(24, SCREEN_HEIGHT - 24)
        for index = 1, clusterSize do
            local angle = (index / clusterSize) * math.pi * 2
            local radius = math.random(2, 11)
            local depth = 0.65 + (math.random() * 0.3)
            addStar(
                centerX + (math.cos(angle) * radius) + math.random(-2, 2),
                centerY + (math.sin(angle) * radius) + math.random(-2, 2),
                depth > 0.82 and 3 or 2,
                depth,
                "cluster",
                { centerX = centerX, centerY = centerY }
            )
        end
    end

    for _ = 1, galaxyCount do
        local centerX = math.random(48, SCREEN_WIDTH - 48)
        local centerY = math.random(34, SCREEN_HEIGHT - 34)
        local spiralDirection = math.random() < 0.5 and 1 or -1
        for index = 1, galaxyStarCount do
            local progress = index / galaxyStarCount
            local angle = (progress * math.pi * 2.4 * spiralDirection) + (math.random() * 0.45)
            local radius = 8 + (progress * math.random(10, 22))
            addStar(
                centerX + (math.cos(angle) * radius),
                centerY + (math.sin(angle) * radius),
                progress > 0.6 and 2 or 1,
                0.85 + (progress * 0.12),
                "galaxy",
                { centerX = centerX, centerY = centerY, spiralDirection = spiralDirection }
            )
        end
    end

    return stars
end

local function buildMenuBackgroundImage(stars)
    local image = gfx.image.new(SCREEN_WIDTH, SCREEN_HEIGHT, gfx.kColorBlack)
    gfx.pushContext(image)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    gfx.setColor(gfx.kColorWhite)
    for _, star in ipairs(stars or {}) do
        local size = star.size or 1
        if star.kind == "galaxy" then
            local extra = star.extra or {}
            local centerX = extra.centerX or star.x
            local centerY = extra.centerY or star.y
            local dx = star.x - centerX
            local dy = star.y - centerY
            gfx.drawLine(centerX, centerY, centerX + (dx * 0.75), centerY + (dy * 0.75))
            gfx.fillCircleAtPoint(star.x, star.y, size)
        elseif star.kind == "cluster" then
            local extra = star.extra or {}
            local centerX = extra.centerX or star.x
            local centerY = extra.centerY or star.y
            gfx.drawLine(centerX - 1, centerY, centerX + 1, centerY)
            gfx.drawLine(centerX, centerY - 1, centerX, centerY + 1)
            gfx.fillCircleAtPoint(star.x, star.y, size)
        elseif size >= 3 then
            gfx.fillCircleAtPoint(star.x, star.y, 1)
            gfx.drawCircleAtPoint(star.x, star.y, 1)
        elseif size == 2 then
            gfx.drawRect(star.x, star.y, 2, 2)
        else
            gfx.fillRect(star.x, star.y, 1, 1)
        end
    end
    gfx.popContext()
    return image
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
    if modeId == SpaceMiner.MODE_OREMINER then
        return "Endless Ore Mining"
    elseif modeId == SpaceMiner.MODE_CONTINUE then
        return "Continue Mining"
    elseif modeId == SpaceMiner.MODE_CONTINUE_STORY then
        return "Continue Story Mode"
    elseif modeId == SpaceMiner.MODE_NEW_SAVE then
        return "New Story Mode"
    end
    return "Story Mode"
end

function SpaceMiner.getStorySlotKey(slot)
    return STORY_SAVE_SLOT_PREFIX .. tostring(clamp(math.floor(tonumber(slot) or 1), 1, STORY_SAVE_SLOT_COUNT))
end

function SpaceMiner.readStorySaveIndex()
    local ok, index = pcall(function()
        return pd.datastore.read(STORY_SAVE_INDEX_KEY)
    end)
    if ok and type(index) == "table" then
        index.slots = type(index.slots) == "table" and index.slots or {}
        index.sequence = tonumber(index.sequence) or 0
        return index
    end
    return { slots = {}, sequence = 0, latestSlot = nil }
end

function SpaceMiner.writeStorySaveIndex(index)
    pcall(function()
        pd.datastore.write(index, STORY_SAVE_INDEX_KEY)
    end)
end

function SpaceMiner.readStorySlot(slot)
    local ok, data = pcall(function()
        return pd.datastore.read(SpaceMiner.getStorySlotKey(slot))
    end)
    if ok and type(data) == "table" and data.cleared ~= true and type(data.player) == "table" then
        return data
    end
    return nil
end

function SpaceMiner.getStorySlots()
    local index = SpaceMiner.readStorySaveIndex()
    local slots = {}
    for slot = 1, STORY_SAVE_SLOT_COUNT do
        local meta = index.slots[slot] or index.slots[tostring(slot)] or nil
        if type(meta) == "table" then
            slots[#slots + 1] = {
                slot = slot,
                name = meta.name or STORY_SAVE_EMPTY_SLOT_NAME,
                sequence = tonumber(meta.sequence) or 0
            }
        end
    end
    return slots
end

function SpaceMiner.hasAnyStorySave()
    return #SpaceMiner.getStorySlots() > 0
end

function SpaceMiner.getStoryTitleModes()
    return {
        SpaceMiner.MODE_STORY,
        SpaceMiner.MODE_CONTINUE_STORY,
        SpaceMiner.MODE_NEW_SAVE
    }
end

function SpaceMiner.getLatestStorySlot()
    local slots = SpaceMiner.getStorySlots()
    local latestSlot = nil
    local latestSequence = -1
    for _, slotInfo in ipairs(slots) do
        if slotInfo.sequence >= latestSequence then
            latestSlot = slotInfo.slot
            latestSequence = slotInfo.sequence
        end
    end
    return latestSlot
end

function SpaceMiner.chooseNewStorySlot()
    local index = SpaceMiner.readStorySaveIndex()
    for slot = 1, STORY_SAVE_SLOT_COUNT do
        if type(index.slots[slot] or index.slots[tostring(slot)]) ~= "table" then
            return slot
        end
    end
    local oldestSlot = 1
    local oldestSequence = math.huge
    for _, slotInfo in ipairs(SpaceMiner.getStorySlots()) do
        if slotInfo.sequence < oldestSequence then
            oldestSlot = slotInfo.slot
            oldestSequence = slotInfo.sequence
        end
    end
    return oldestSlot
end

function SpaceMiner.markStorySlotSaved(slot, name)
    local index = SpaceMiner.readStorySaveIndex()
    index.sequence = (tonumber(index.sequence) or 0) + 1
    index.latestSlot = slot
    index.slots[slot] = {
        name = name or STORY_SAVE_EMPTY_SLOT_NAME,
        sequence = index.sequence
    }
    SpaceMiner.writeStorySaveIndex(index)
    return index.sequence
end

function SpaceMiner.deleteStorySlot(slot)
    local slotNumber = tonumber(slot)
    if slotNumber == nil then
        return false
    end
    slotNumber = clamp(math.floor(slotNumber), 1, STORY_SAVE_SLOT_COUNT)
    local slotKey = SpaceMiner.getStorySlotKey(slotNumber)
    local index = SpaceMiner.readStorySaveIndex()
    local hadSlot = index.slots[slotNumber] ~= nil or index.slots[tostring(slotNumber)] ~= nil
    index.slots[slotNumber] = nil
    index.slots[tostring(slotNumber)] = nil
    if index.latestSlot == slotNumber then
        index.latestSlot = nil
    end
    SpaceMiner.writeStorySaveIndex(index)
    pcall(function()
        if pd.datastore.delete then
            pd.datastore.delete(slotKey)
        else
            pd.datastore.write({ cleared = true }, slotKey)
        end
    end)
    return hadSlot
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
            pd.datastore.delete(STORY_SAVE_INDEX_KEY)
            for slot = 1, STORY_SAVE_SLOT_COUNT do
                pd.datastore.delete(SpaceMiner.getStorySlotKey(slot))
            end
        else
            pd.datastore.write({ cleared = true }, STORY_SAVE_KEY)
            pd.datastore.write({ cleared = true }, STORY_SAVE_INDEX_KEY)
            for slot = 1, STORY_SAVE_SLOT_COUNT do
                pd.datastore.write({ cleared = true }, SpaceMiner.getStorySlotKey(slot))
            end
        end
    end)
end

function SpaceMiner.clearAllStorySaves()
    SpaceMiner.clearStorySave()
end

function SpaceMiner:hasStorySave()
    return SpaceMiner.hasAnyStorySave()
end

function SpaceMiner:getSaveKey()
    if self:isOreMinerMode() then
        return OREMINER_SAVE_KEY
    end
    return SpaceMiner.getStorySlotKey(self.storySaveSlot or SpaceMiner.getLatestStorySlot() or 1)
end

function SpaceMiner:isOreMinerMode()
    return self.playMode == SpaceMiner.MODE_OREMINER
end

function SpaceMiner:isStoryMode()
    return self.playMode == SpaceMiner.MODE_STORY
end

function SpaceMiner:getModeStageSchedule()
    return self.stageSchedule or STORY_STAGE_SCHEDULE
end

function SpaceMiner:getModeCommunicationSchedule()
    return self.communicationSchedule or {}
end

function SpaceMiner:getModeStageCount()
    return #(self:getModeStageSchedule() or {})
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
    if not self.preview and SPACE_MINER_FORCE_CLEAR_STORY_SAVES and not SpaceMiner._cleanStorySavesDone and (
        self.playMode == SpaceMiner.MODE_STORY or
        self.playMode == SpaceMiner.MODE_CONTINUE_STORY or
        self.playMode == SpaceMiner.MODE_NEW_SAVE
    ) then
        SpaceMiner.clearAllStorySaves()
        SpaceMiner._cleanStorySavesDone = true
    end
    local requestedMode = self.playMode
    self.continueRequested = false
    self.storySaveSlot = nil
    self.storySaveName = nil
    self.playerName = nil
    self.nameEntryOpen = false
    self.storyNameKeyboardPending = false
    self.storyNameKeyboardShown = false
    self.storyNameKeyboardRows = nil
    self.storyNameKeyboardRow = 1
    self.storyNameKeyboardCol = 1
    self.storyNameKeyboardIndex = 1
    self.storyNameKeyboardCrankAccumulator = 0
    self.storyNameKeyboardShift = false
    self.storyNameKeyboardCapsLock = false
    self.storyNameKeyboardText = nil
    self.storyNameKeyboardDpadHoldDirection = 0
    self.storyNameKeyboardDpadHoldFrames = 0
    self.storyNameActionHandledFrame = -1
    self.storySlotSelectorOpen = false
    self.storySlotSelectorIndex = 1
    self.storySlotSelectorCrankAccumulator = 0
    self.storySlotSelectorMode = nil
    self.storySlotSelectorDeleteMode = false
    self.storyNameEntryIndex = 1
    self.storyNameEntryCrankAccumulator = 0
    self.deferredStoryLoadMode = nil
    self.deferredStoryLoadFrames = 0
    if requestedMode == SpaceMiner.MODE_STORY and not self.preview then
        self.deferredStoryLoadMode = SpaceMiner.MODE_STORY
    elseif requestedMode == SpaceMiner.MODE_CONTINUE_STORY and not self.preview then
        self.deferredStoryLoadMode = SpaceMiner.MODE_CONTINUE_STORY
        self.playMode = SpaceMiner.MODE_STORY
    elseif requestedMode == SpaceMiner.MODE_NEW_SAVE and not self.preview then
        self.deferredStoryLoadMode = SpaceMiner.MODE_NEW_SAVE
        self.playMode = SpaceMiner.MODE_STORY
    elseif requestedMode == SpaceMiner.MODE_CONTINUE then
        self.continueRequested = not self.preview
        self.playMode = SpaceMiner.MODE_OREMINER
    end
    self.modeId = self.playMode
    if self:isOreMinerMode() then
        self.stageSchedule = OREMINER_STAGE_SCHEDULE
        self.communicationSchedule = OREMINER_COMMUNICATION_SCHEDULE
    else
        self.stageSchedule = STORY_STAGE_SCHEDULE
        self.communicationSchedule = nil
    end
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
    self.lootPackages = {}
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
    local initialStageSchedule = self:getModeStageSchedule()
    self.stageLabel = (#initialStageSchedule > 0 and initialStageSchedule[1].label) or "Open Mining"
    self.stageRuntime = nil
    self.menuOpen = false
    self.menuType = "ship"
    self.homeMenuScreen = "directory"
    self.menuIndex = 1
    self.menuInputIgnoreFrames = 0
    self.menuCrankAccumulator = 0
    self.menuRotaryVelocity = 0
    self.menuRotaryFreeSpin = false
    self.menuDpadHoldDirection = 0
    self.menuDpadHoldFrames = 0
    self.homeDirectoryIndex = 1
    self.communicationHistoryCursorIndex = 1
    self.communicationHistoryScrollY = 0
    self.communicationHistoryCrankAccumulator = 0
    self.menuOpenedAtX = 0
    self.menuOpenedAtY = 0
    self.homeMenuMessage = nil
    self.homeMenuScoutHidden = false
    self.homeMenuAutoCloseFrames = nil
    self.shipMenuScreen = "directory"
    self.shipMenuPreviousScreenForCommunication = nil
    self.shipDirectoryIndex = 1
    self.rightButtonMode = "missile"
    self.rightTurboBoostFrames = 0
    self.homeBaseAutopilot = nil
    self.homeBaseVisitGreetingShown = false
    self.wasInHomeBaseShield = false
    self.wasCollidingHomeBase = false
    self.contextCommunication = nil
    self.dismissedCommunications = {}
    self.baseCollisionCooldownFrames = 0
    self.scoutToleranceCount = 0
    self.scoutToleranceTimer = 0
    self.scoutToleranceWindowFrames = 30 * 10
    self.weaponsDisabled = false
    self.blockedWeaponButtons = {}
    self.communicationHistory = {}
    self.communicationHistoryKeys = {}
    self.homeBaseEnemyAroundSuppressionLogged = false
    self.baseMiningLaserComplaintSuppressionLogged = false
    self.destroyedQuoteQueue = nil
    self.destroyedQuoteIndex = 1
    self.hullRepairFrames = 0
    self.autoMissileAccumulator = 0
    self.baseLaserCooldownFrames = 0
    self.playerAutoLaserCooldownFrames = 0
    self.laserSoundCooldownFrames = 0
    self.laserCircleModeFrames = 0
    self.menuScrollOffset = 1
    self.baseLaserBeams = {}
    self.playerAutoLaserBeams = {}
    self.enemyLaserBeams = {}
    self.supernovaFlashFrames = 0
    self.materialMarkerToggles = {}
    self.ownedLaserUpgrades = {}
    self.ownedMissileUpgrades = {}
    self.ownedShieldUpgrades = {}
    self.ownedThrusterUpgrades = {}
    self.ownedCargoUpgrades = {}
    self.ownedMiscUpgrades = {}
    self.ownedBaseUpgrades = {}
    self.activeLaserUpgrade = nil
    self.activeMissileUpgrade = nil
    self.activeShieldUpgrade = nil
    self.activeThrusterUpgrade = nil
    self.activeCargoUpgrade = nil
    self.activeMiscUpgrade = nil
    self.activeBaseUpgrade = nil
    self:initializeUpgradeState()
    self.spaceMinerSoundEnabled = SPACE_MINER_CONFIG.spaceMinerSoundEnabled ~= false
    self.sfx = SpaceMinerSFX.new({
        enabled = self.spaceMinerSoundEnabled
    })
    self.enemySerial = 0
    self.playerShieldHits = self.playerShieldMax
    self.playerHullHits = HULL_HITS
    self.baseModeId = BASE_CONFIG.mode or "home-base"
    self.previousBaseModeId = nil
    self.baseModeTransitionFrame = BASE_MODE_TRANSITION_FRAMES
    self.baseName = self:getBaseModeName(self.baseModeId)
    self.baseWorldX = BASE_WORLD_X
    self.baseWorldY = BASE_WORLD_Y
    self.entityMoves = {}
    self.pointsOfInterest = {}
    self.baseShieldHits = BASE_SHIELD_MAX
    self.baseShieldFlashFrames = 0
    self.baseFramesSinceDamage = SHIELD_RECHARGE_DELAY_FRAMES
    self.baseShieldRechargeFrames = 0
    self.baseHealthBarEnabled = BASE_CONFIG.healthBarEnabled ~= false
    self.baseTimelineIndex = 1
    self.miniMapEnabled = true
    self.settingsTimelineIndex = 1
    self.baseUnderAttackFrames = 0
    self.baseUnderAttackStartFrame = nil
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
    self.menuBackgroundStars = nil
    self.menuBackgroundImage = nil
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
    if not self.preview and self.deferredStoryLoadMode == nil and #self:getModeStageSchedule() > 0 then
        self:beginStage(1)
    end
    return self
end

function SpaceMiner:resolveDeferredStoryLoad()
    if self.preview or self.deferredStoryLoadMode == nil then
        return
    end
    self.deferredStoryLoadFrames = (self.deferredStoryLoadFrames or 0) + 1
    if self.deferredStoryLoadFrames < 3 then
        return
    end

    local requestedMode = self.deferredStoryLoadMode
    self.deferredStoryLoadMode = nil
    self.storySlotSelectorMode = requestedMode
    self.storySlotSelectorDeleteMode = false
    if requestedMode == SpaceMiner.MODE_STORY then
        local hasExistingSaves = SpaceMiner.hasAnyStorySave()
        local latestSlot = SpaceMiner.getLatestStorySlot()
        if latestSlot ~= nil then
            self.storySaveSlot = latestSlot
            local latestSave = SpaceMiner.readStorySlot(latestSlot)
            self.storySaveName = latestSave and latestSave.saveName or STORY_SAVE_EMPTY_SLOT_NAME
            local loaded = self:loadModeSave()
            if not loaded then
                self.storySlotSelectorMode = SpaceMiner.MODE_NEW_SAVE
                self.storySlotSelectorOpen = true
                self.storySlotSelectorIndex = 1
                self.storySlotSelectorCrankAccumulator = 0
                self.storySlotSelectorDeleteMode = false
            end
        elseif hasExistingSaves then
            self.storySlotSelectorMode = SpaceMiner.MODE_STORY
            self.storySlotSelectorOpen = true
            self.storySlotSelectorIndex = 1
            self.storySlotSelectorCrankAccumulator = 0
            self.storySlotSelectorDeleteMode = false
        else
            self.storySlotSelectorMode = SpaceMiner.MODE_NEW_SAVE
            self.storySlotSelectorOpen = true
            self.storySlotSelectorIndex = 1
            self.storySlotSelectorCrankAccumulator = 0
            self.storySlotSelectorDeleteMode = false
        end
    elseif requestedMode == SpaceMiner.MODE_CONTINUE_STORY then
        local hasExistingSaves = SpaceMiner.hasAnyStorySave()
        if hasExistingSaves then
            self.storySlotSelectorMode = SpaceMiner.MODE_CONTINUE_STORY
            self.storySlotSelectorOpen = true
            self.storySlotSelectorIndex = 1
            self.storySlotSelectorCrankAccumulator = 0
            self.storySlotSelectorDeleteMode = false
        else
            self.storySlotSelectorMode = SpaceMiner.MODE_NEW_SAVE
            self.storySlotSelectorOpen = true
            self.storySlotSelectorIndex = 1
            self.storySlotSelectorCrankAccumulator = 0
            self.storySlotSelectorDeleteMode = false
        end
    elseif requestedMode == SpaceMiner.MODE_NEW_SAVE then
        self.storySlotSelectorMode = SpaceMiner.MODE_NEW_SAVE
        self.storySlotSelectorOpen = true
        self.storySlotSelectorIndex = 1
        self.storySlotSelectorCrankAccumulator = 0
        self.storySlotSelectorDeleteMode = false
    end
end
function SpaceMiner:setPreview(isPreview)
    self.preview = isPreview == true
    if not self.preview then
        self.titleStandby = false
    end
end

function SpaceMiner:setTitleStandby(enabled)
    self.titleStandby = enabled == true
end

function SpaceMiner:refreshSettings()
    self:applyTurnModeSetting()
end

function SpaceMiner:isSoundEnabled()
    return self.spaceMinerSoundEnabled ~= false
end

function SpaceMiner:setSoundEnabled(enabled)
    self.spaceMinerSoundEnabled = enabled == true
    if self.sfx ~= nil and self.sfx.setEnabled ~= nil then
        self.sfx:setEnabled(self.spaceMinerSoundEnabled)
    end
end

function SpaceMiner:playUiClick()
    if self.sfx ~= nil and self.sfx.playUiClick ~= nil then
        self.sfx:playUiClick()
    end
end

function SpaceMiner:playMenuOpenSound()
    if self.sfx ~= nil and self.sfx.playMenuOpen ~= nil then
        self.sfx:playMenuOpen()
    end
end

function SpaceMiner:playMenuBackSound()
    if self.sfx ~= nil and self.sfx.playMenuBack ~= nil then
        self.sfx:playMenuBack()
    end
end

function SpaceMiner:playLaserSound()
    if (self.laserSoundCooldownFrames or 0) > 0 then
        return
    end
    if self.sfx ~= nil and self.sfx.playLaser ~= nil then
        self.sfx:playLaser()
    end
    self.laserSoundCooldownFrames = 6
end

function SpaceMiner:playMissileSound()
    if self.sfx ~= nil and self.sfx.playMissile ~= nil then
        self.sfx:playMissile()
    end
end

function SpaceMiner:playExplosionSound()
    if self.sfx ~= nil and self.sfx.playExplosion ~= nil then
        self.sfx:playExplosion()
    end
end

function SpaceMiner:playAsteroidBreakSound(stage)
    if self.sfx ~= nil and self.sfx.playAsteroidBreak ~= nil then
        self.sfx:playAsteroidBreak(stage)
    end
end

function SpaceMiner:playThrusterSound(thrustAmount)
    if self.sfx ~= nil and self.sfx.playThrusters ~= nil then
        self.sfx:playThrusters(thrustAmount)
    end
end

function SpaceMiner:updateAudio()
    if (self.laserSoundCooldownFrames or 0) > 0 then
        self.laserSoundCooldownFrames = self.laserSoundCooldownFrames - 1
    end
    if (self.rightTurboBoostFrames or 0) > 0 then
        self.rightTurboBoostFrames = self.rightTurboBoostFrames - 1
    end
    self:updateScoutToleranceTimer()
    if self.sfx ~= nil and self.sfx.update ~= nil then
        self.sfx:update((self.input.thrust or 0) > 0 or (self.input.reverse or 0) > 0)
    end
end

function SpaceMiner:activate()
end

function SpaceMiner:shutdown()
end

function SpaceMiner:getStorySaveData()
    local communicationHistory = {}
    local sourceHistory = self.communicationHistory or {}
    local startIndex = math.max(1, #sourceHistory - 49)
    for index = startIndex, #sourceHistory do
        communicationHistory[#communicationHistory + 1] = sourceHistory[index]
    end
    local normalizedRuntime = self:normalizeSavedStageRuntime(self.stageRuntime)
    return {
        saveSlot = self.storySaveSlot,
        saveName = self.storySaveName,
        playerName = self.playerName,
        saveSequence = self.storySaveSequence or 0,
        frame = self.frame,
        stageIndex = self.stageIndex,
        stageFrame = self.stageFrame,
        stageFrameOffset = self.stageFrame,
        stageStatus = self.stageStatus,
        stageLabel = self.stageLabel,
        stageRuntime = normalizedRuntime,
        storyRuntime = normalizedRuntime,
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
        ownedMiscUpgrades = self.ownedMiscUpgrades,
        ownedBaseUpgrades = self.ownedBaseUpgrades,
        activeLaserUpgrade = self.activeLaserUpgrade,
        activeMissileUpgrade = self.activeMissileUpgrade,
        activeShieldUpgrade = self.activeShieldUpgrade,
        activeThrusterUpgrade = self.activeThrusterUpgrade,
        activeCargoUpgrade = self.activeCargoUpgrade,
        activeMiscUpgrade = self.activeMiscUpgrade,
        activeBaseUpgrade = self.activeBaseUpgrade,
        shieldLevel = self.shieldLevel,
        playerShieldMax = self.playerShieldMax,
        playerShieldHits = self.playerShieldHits,
        playerHullHits = self.playerHullHits,
        baseName = self.baseName,
        baseModeId = self.baseModeId,
        previousBaseModeId = self.previousBaseModeId,
        baseModeTransitionFrame = self.baseModeTransitionFrame,
        baseWorldX = self.baseWorldX,
        baseWorldY = self.baseWorldY,
        pointsOfInterest = self.pointsOfInterest,
        baseShieldHits = self.baseShieldHits,
        baseHealthBarEnabled = self.baseHealthBarEnabled,
        baseTimelineIndex = self.baseTimelineIndex,
        materialMarkerToggles = self.materialMarkerToggles,
        spaceMinerSoundEnabled = self.spaceMinerSoundEnabled == true,
        scoutToleranceCount = self.scoutToleranceCount or 0,
        scoutToleranceTimer = self.scoutToleranceTimer or 0,
        weaponsDisabled = self.weaponsDisabled == true,
        blockedWeaponButtons = self.blockedWeaponButtons,
        communicationHistory = communicationHistory,
        rightButtonMode = self.rightButtonMode or "missile"
    }
end

function SpaceMiner:saveModeState()
    if self.preview or not (self:isStoryMode() or self:isOreMinerMode()) then
        return
    end
    if self:isStoryMode() then
        self.storySaveSlot = self.storySaveSlot or SpaceMiner.chooseNewStorySlot()
        self.storySaveName = self.storySaveName or STORY_SAVE_EMPTY_SLOT_NAME
        self.storySaveSequence = SpaceMiner.markStorySlotSaved(self.storySaveSlot, self.storySaveName)
    end
    local ok, errorMessage = pcall(function()
        pd.datastore.write(self:getStorySaveData(), self:getSaveKey())
    end)
    if not ok then
        StarryLog.error("space miner save failed: %s", tostring(errorMessage))
    end
end

function SpaceMiner:loadModeSave()
    if self.preview or not (self:isStoryMode() or self:isOreMinerMode()) then
        return false
    end
    local ok, data = pcall(function()
        return pd.datastore.read(self:getSaveKey())
    end)
    if not ok or type(data) ~= "table" or data.cleared == true or type(data.player) ~= "table" then
        return false
    end

    if self:isStoryMode() then
        self.storySaveSlot = tonumber(data.saveSlot) or self.storySaveSlot
        self.storySaveName = data.saveName or self.storySaveName or STORY_SAVE_EMPTY_SLOT_NAME
        self.playerName = data.playerName or self.playerName or self.storySaveName
        self.storySaveSequence = tonumber(data.saveSequence) or self.storySaveSequence or 0
    end
    self.frame = tonumber(data.frame) or self.frame
    local modeStageCount = self:getModeStageCount()
    self.stageIndex = clamp(tonumber(data.stageIndex) or self.stageIndex, 1, math.max(1, modeStageCount))
    if modeStageCount > 0 then
        self:beginStage(self.stageIndex)
    end
    self.stageFrame = tonumber(data.stageFrame) or self.stageFrame
    self.stageStatus = data.stageStatus or self.stageStatus
    self.stageLabel = data.stageLabel or self.stageLabel
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
    local runtimeSource = data.stageRuntime
    if type(runtimeSource) ~= "table" and type(data.storyRuntime) == "table" then
        runtimeSource = data.storyRuntime
    end
    self.stageRuntime = self:normalizeSavedStageRuntime(runtimeSource)
    local activeStage = self:getCurrentStage()
    if type(self.stageRuntime) == "table"
        and activeStage ~= nil
        and (activeStage.kind == "wave" or activeStage.kind == "objective")
        and self.stageRuntime.alertStarted == true
        and self.stageRuntime.waveStartFrame == nil then
        local stageOffset = tonumber(data.stageFrameOffset)
        if stageOffset == nil then
            stageOffset = tonumber(data.stageFrame)
        end
        local frameOffset = tonumber(self.frame) or 0
        if stageOffset ~= nil and frameOffset >= 0 then
            self.stageRuntime.waveStartFrame = frameOffset - math.max(0, stageOffset)
        end
    end
    self.testModeEnabled = data.testModeEnabled == true
    self:loadOwnedUpgradeState("laser", data.ownedLaserUpgrades, data.activeLaserUpgrade)
    self:loadOwnedUpgradeState("missile", data.ownedMissileUpgrades, data.activeMissileUpgrade)
    self:loadOwnedUpgradeState("shield", data.ownedShieldUpgrades, data.activeShieldUpgrade)
    self:loadOwnedUpgradeState("thruster", data.ownedThrusterUpgrades, data.activeThrusterUpgrade)
    self:loadOwnedUpgradeState("cargo", data.ownedCargoUpgrades, data.activeCargoUpgrade)
    self:loadOwnedUpgradeState("misc", data.ownedMiscUpgrades, data.activeMiscUpgrade)
    self:loadOwnedUpgradeState("base", data.ownedBaseUpgrades, data.activeBaseUpgrade)
    self.cargoCapacityTarget = math.max(CARGO_INITIAL_CAPACITY, tonumber(data.cargoCapacityTarget) or self:getCargoCapacityTarget(), self:getCargoUpgradeCapacity())
    self.cargoCapacity = math.max(CARGO_INITIAL_CAPACITY, tonumber(data.cargoCapacity) or self.cargoCapacityTarget)
    self:applyShieldUpgradeLevel(tonumber(data.shieldLevel) or self.shieldLevel or 1)
    self.playerShieldMax = tonumber(data.playerShieldMax) or self.playerShieldMax
    self.playerShieldHits = tonumber(data.playerShieldHits) or self.playerShieldHits
    self.playerHullHits = tonumber(data.playerHullHits) or self.playerHullHits
    self.baseName = data.baseName or self.baseName
    self.baseModeId = data.baseModeId or self.baseModeId
    self.previousBaseModeId = data.previousBaseModeId
    self.baseModeTransitionFrame = tonumber(data.baseModeTransitionFrame) or self.baseModeTransitionFrame
    self.baseWorldX = tonumber(data.baseWorldX) or self.baseWorldX
    self.baseWorldY = tonumber(data.baseWorldY) or self.baseWorldY
    if type(data.pointsOfInterest) == "table" then
        self.pointsOfInterest = data.pointsOfInterest
    end
    self.baseShieldHits = tonumber(data.baseShieldHits) or self.baseShieldHits
    if data.baseHealthBarEnabled ~= nil then
        self.baseHealthBarEnabled = data.baseHealthBarEnabled == true
    end
    if data.spaceMinerSoundEnabled ~= nil then
        self:setSoundEnabled(data.spaceMinerSoundEnabled == true)
    end
    self.scoutToleranceCount = math.max(0, math.floor(tonumber(data.scoutToleranceCount) or self.scoutToleranceCount or 0))
    self.scoutToleranceTimer = math.max(0, math.floor(tonumber(data.scoutToleranceTimer) or self.scoutToleranceTimer or 0))
    self.weaponsDisabled = data.weaponsDisabled == true
    self.rightButtonMode = data.rightButtonMode == "turbo-boost" and "turbo-boost" or "missile"
    self.baseTimelineIndex = tonumber(data.baseTimelineIndex) or self.baseTimelineIndex
    if type(data.blockedWeaponButtons) == "table" then
        self.blockedWeaponButtons = {}
        for key, value in pairs(data.blockedWeaponButtons) do
            self.blockedWeaponButtons[tostring(key)] = value == true
        end
    end
    local rawCommunicationHistory = data.communicationHistory
    if type(rawCommunicationHistory) ~= "table" then
        rawCommunicationHistory = data.communications or data.communicationLog or data.communicationHistoryLog or data.history
    end
    self:loadCommunicationHistoryFromSave(rawCommunicationHistory)
    if type(data.materialMarkerToggles) == "table" then
        for key, value in pairs(data.materialMarkerToggles) do
            self.materialMarkerToggles[key] = value == true
        end
    end
    return true
end

function SpaceMiner:getStorySlotSelectorItems()
    local items = {}
    local slots = {}
    for _, slotInfo in ipairs(SpaceMiner.getStorySlots()) do
        local slot = clamp(math.floor(tonumber(slotInfo.slot) or 1), 1, STORY_SAVE_SLOT_COUNT)
        slots[slot] = slotInfo
    end
    local selectorMode = self.storySlotSelectorMode or SpaceMiner.MODE_STORY
    items[#items + 1] = {
        action = "delete-toggle",
        label = "Delete Save: " .. (self.storySlotSelectorDeleteMode and "ON" or "OFF")
    }
    for slot = 1, STORY_SAVE_SLOT_COUNT do
        local slotInfo = slots[slot]
        local slotName = STORY_SAVE_EMPTY_SLOT_NAME
        if slotInfo ~= nil then
            local action = selectorMode == SpaceMiner.MODE_NEW_SAVE and "new" or "load"
            local actionLabel = action == "new" and "Overwrite" or "Load"
            slotName = slotInfo.name or STORY_SAVE_EMPTY_SLOT_NAME
            items[#items + 1] = {
                action = action,
                slot = slot,
                label = string.format("%s Save %d: %s", actionLabel, slot, slotName)
            }
            items[#items + 1] = {
                action = "delete-slot",
                slot = slot,
                label = string.format("Delete Save %d", slot)
            }
        else
            local actionLabel = selectorMode == SpaceMiner.MODE_NEW_SAVE and "Create" or "Load"
            items[#items + 1] = {
                action = "new",
                slot = slot,
                label = string.format("%s Save %d: %s", actionLabel, slot, slotName)
            }
        end
    end
    items[#items + 1] = { action = "back", label = "Back" }
    return items
end

function SpaceMiner:startStoryNameKeyboard()
    if self.preview or self.storyNameKeyboardShown then
        return
    end
    local seedName = tostring(self.playerName or self.storySaveName or "")
    if seedName == STORY_SAVE_EMPTY_SLOT_NAME then
        seedName = ""
    end
    self.storyNameKeyboardShown = true
    self.storyNameKeyboardClosed = false
    self.storyNameAccepted = false
    self.storyNameKeyboardPending = true
    self.input.thrust = 0
    self.input.reverse = 0
    self.input.laser = false
    self.player.laserOn = false
    self.storyNameKeyboardRows = STORY_NAME_KEYBOARD_ROWS
    self.storyNameKeyboardRow = 1
    self.storyNameKeyboardCol = 1
    self.storyNameKeyboardIndex = 1
    self.storyNameKeyboardCrankAccumulator = 0
    self.storyNameKeyboardShift = false
    self.storyNameKeyboardCapsLock = false
    self.storyNameKeyboardDpadHoldDirection = 0
    self.storyNameKeyboardDpadHoldFrames = 0
    self.storyNameKeyboardText = seedName
end

function SpaceMiner:handleStoryNameEntryAction()
    if self.storyNameKeyboardShown then
        self:applyStoryNameKeyboardAction()
        return
    end
    self.storyNameEntryIndex = clamp(self.storyNameEntryIndex or 1, 1, 2)
    if self.storyNameEntryIndex == 1 then
        self:startStoryNameKeyboard()
    else
        self:acceptStoryNameEntry()
    end
end

function SpaceMiner:getStoryNameKeyboardRows()
    return self.storyNameKeyboardRows or STORY_NAME_KEYBOARD_ROWS
end

function SpaceMiner:getStoryNameKeyboardTotalKeys(rows)
    local list = rows or self:getStoryNameKeyboardRows()
    local total = 0
    for _, row in ipairs(list) do
        total = total + #row
    end
    return total
end

function SpaceMiner:getStoryNameKeyboardCursorIndex(rows)
    local list = rows or self:getStoryNameKeyboardRows()
    local index = 0
    local row = math.max(1, self.storyNameKeyboardRow or 1)
    local col = math.max(1, self.storyNameKeyboardCol or 1)
    for r = 1, #list do
        if r == row then
            col = clamp(col, 1, #list[r])
            return index + col
        end
        index = index + #list[r]
    end
    if #list > 0 and col <= #list[1] then
        return col
    end
    return 1
end

function SpaceMiner:setStoryNameKeyboardCursorByIndex(index)
    local list = self:getStoryNameKeyboardRows()
    local total = self:getStoryNameKeyboardTotalKeys(list)
    if total <= 0 then
        self.storyNameKeyboardRow = 1
        self.storyNameKeyboardCol = 1
        self.storyNameKeyboardIndex = 1
        return
    end
    index = clamp(math.floor(index), 1, total)
    local cursor = 0
    for r = 1, #list do
        local row = list[r]
        if index <= cursor + #row then
            self.storyNameKeyboardRow = r
            self.storyNameKeyboardCol = index - cursor
            self.storyNameKeyboardIndex = index
            return
        end
        cursor = cursor + #row
    end
    self.storyNameKeyboardRow = 1
    self.storyNameKeyboardCol = 1
    self.storyNameKeyboardIndex = 1
end

function SpaceMiner:setStoryNameKeyboardCursorDeltaRow(delta)
    local rows = self:getStoryNameKeyboardRows()
    if #rows == 0 then
        return
    end
    local nextRow = self.storyNameKeyboardRow + delta
    if nextRow < 1 then
        nextRow = #rows
    elseif nextRow > #rows then
        nextRow = 1
    end
    local prevCol = clamp(self.storyNameKeyboardCol or 1, 1, #rows[self.storyNameKeyboardRow] or 1)
    local nextRowWidth = #rows[nextRow]
    if nextRowWidth <= 0 then
        return
    end
    self.storyNameKeyboardRow = nextRow
    self.storyNameKeyboardCol = clamp(prevCol, 1, nextRowWidth)
    self.storyNameKeyboardIndex = self:getStoryNameKeyboardCursorIndex(rows)
end

function SpaceMiner:setStoryNameKeyboardCursorDeltaCol(delta)
    local rows = self:getStoryNameKeyboardRows()
    local currentRow = clamp(self.storyNameKeyboardRow or 1, 1, #rows)
    local row = rows[currentRow]
    if row == nil or #row == 0 then
        return
    end
    local nextCol = self.storyNameKeyboardCol + delta
    if nextCol < 1 then
        nextCol = #row
    elseif nextCol > #row then
        nextCol = 1
    end
    self.storyNameKeyboardCol = nextCol
    self.storyNameKeyboardIndex = self:getStoryNameKeyboardCursorIndex(rows)
end

function SpaceMiner:getStoryNameKeyboardCurrentKey()
    local rows = self:getStoryNameKeyboardRows()
    local row = rows[clamp(self.storyNameKeyboardRow or 1, 1, #rows)]
    if row == nil then
        return nil
    end
    return row[clamp(self.storyNameKeyboardCol or 1, 1, #row)]
end

function SpaceMiner:getStoryNameKeyboardUpperState()
    return (self.storyNameKeyboardCapsLock == true) or false
end

function SpaceMiner:getStoryNameKeyboardDisplayKey(key, selected)
    if key == nil then
        return ""
    end
    local output = key
    local upper = self:getStoryNameKeyboardUpperState() or self.storyNameKeyboardShift == true
    if #key == 1 and key:match("[A-Za-z]") then
        if upper then
            output = key:upper()
        else
            output = key:lower()
        end
    end
    return output
end

function SpaceMiner:getStoryNameKeyboardInsertKey(key)
    if key == nil then
        return nil
    end
    if #key == 1 and key:match("[A-Za-z]") then
        local upper = self:getStoryNameKeyboardUpperState() or self.storyNameKeyboardShift == true
        if upper then
            return key:upper()
        end
        return key:lower()
    end
    if key == "Space" then
        return " "
    end
    return key
end

function SpaceMiner:advanceStoryNameKeyboardCursorStep(step)
    local total = self:getStoryNameKeyboardTotalKeys()
    if total <= 0 then
        return
    end
    local index = self:getStoryNameKeyboardCursorIndex()
    index = index + step
    if index < 1 then
        index = total
    elseif index > total then
        index = 1
    end
    self:setStoryNameKeyboardCursorByIndex(index)
end

function SpaceMiner:handleStoryNameKeyboardDpadInput(upPressed, downPressed, leftPressed, rightPressed)
    local direction = 0
    if upPressed then
        direction = -1
    elseif downPressed then
        direction = 1
    end
    if direction == 0 then
        self.storyNameKeyboardDpadHoldDirection = 0
        self.storyNameKeyboardDpadHoldFrames = 0
    else
        if self.storyNameKeyboardDpadHoldDirection ~= direction then
            self.storyNameKeyboardDpadHoldDirection = direction
            self.storyNameKeyboardDpadHoldFrames = 1
            self:setStoryNameKeyboardCursorDeltaRow(direction)
        else
            self.storyNameKeyboardDpadHoldFrames = (self.storyNameKeyboardDpadHoldFrames or 0) + 1
            if self.storyNameKeyboardDpadHoldFrames > MENU_KEYBOARD_DPAD_HOLD_DELAY_FRAMES then
                if ((self.storyNameKeyboardDpadHoldFrames - MENU_KEYBOARD_DPAD_HOLD_DELAY_FRAMES) % MENU_KEYBOARD_DPAD_REPEAT_INTERVAL_FRAMES) == 0 then
                    self:setStoryNameKeyboardCursorDeltaRow(direction)
                end
            end
        end
    end

    if leftPressed then
        self:setStoryNameKeyboardCursorDeltaCol(-1)
    elseif rightPressed then
        self:setStoryNameKeyboardCursorDeltaCol(1)
    end
end

function SpaceMiner:applyStoryNameKeyboardAction()
    local key = self:getStoryNameKeyboardCurrentKey()
    if key == nil then
        return
    end
    if key == "Shift" then
        self.storyNameKeyboardShift = true
        return
    end
    if key == "Caps" then
        self.storyNameKeyboardCapsLock = not (self.storyNameKeyboardCapsLock == true)
        return
    end
    if key == "Del" then
        local current = tostring(self.storyNameKeyboardText or "")
        if current ~= "" then
            current = current:sub(1, #current - 1)
        end
        self.storyNameKeyboardText = current
        return
    end
    if key == "Enter" then
        local enteredName = tostring(self.storyNameKeyboardText or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if enteredName == "" then
            enteredName = self.storySaveName or STORY_SAVE_EMPTY_SLOT_NAME
        end
        self.playerName = enteredName
        self.storySaveName = enteredName
        self.storyNameKeyboardPending = false
        self.storyNameKeyboardShown = false
        self.storyNameKeyboardClosed = true
        self.storyNameKeyboardText = nil
        self:acceptStoryNameEntry()
        return
    end

    local character = self:getStoryNameKeyboardInsertKey(key)
    if character ~= nil and character ~= "" then
        local currentName = tostring(self.storyNameKeyboardText or "")
        if #currentName < 24 then
            self.storyNameKeyboardText = currentName .. character
        end
    end
    if self.storyNameKeyboardShift then
        self.storyNameKeyboardShift = false
    end
end

function SpaceMiner:acceptStoryNameEntry()
    if not self.nameEntryOpen or self.storyNameKeyboardShown then
        return
    end
    if self.storyNameKeyboardText ~= nil then
        self.storyNameKeyboardText = tostring(self.storyNameKeyboardText or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if self.storyNameKeyboardText ~= "" then
            self.playerName = self.storyNameKeyboardText
            self.storySaveName = self.storyNameKeyboardText
        end
        self.storyNameKeyboardText = nil
    end
    self.playerName = self.playerName or self.storySaveName or STORY_SAVE_EMPTY_SLOT_NAME
    self.storySaveName = self.playerName
    self.nameEntryOpen = false
    self.storyNameEntryCrankAccumulator = 0
    self.storyNameEntryIndex = 1
    self.storyNameKeyboardPending = false
    self.storyNameKeyboardShown = false
    self.storyNameKeyboardClosed = false
    self.storyNameKeyboardDpadHoldDirection = 0
    self.storyNameKeyboardDpadHoldFrames = 0
    self.storyNameAccepted = true
    self.storyNameActionHandledFrame = self.frame or 0
    if self.stageRuntime == nil and #self:getModeStageSchedule() > 0 then
        self:beginStage(1)
    end
    self:saveModeState()
    self.storySlotSelectorMode = nil
    StarryLog.info("miner story save named slot=%d name=%s", self.storySaveSlot or 1, tostring(self.storySaveName))
end

function SpaceMiner:prepareNewStorySaveState()
    self.frame = 0
    self.stageIndex = 1
    self.stageFrame = 0
    self.stageStatus = "active"
    local initialStageSchedule = self:getModeStageSchedule()
    self.stageLabel = (#initialStageSchedule > 0 and initialStageSchedule[1].label) or "Open Mining"
    self.stageRuntime = nil
    self.score = 0
    self.cash = 0
    self.minedChunks = 0
    self.cargoOre = 0
    self.cargoValue = 0
    self.cargoLoads = {}
    self.destroyedEnemies = 0
    self.player.vx = 0
    self.player.vy = 0
    self.player.laserOn = false
    self.player.missile = nil
    self.player.missiles = {}
    self.player.pendingMissileTrigger = false
    self:positionPlayerNearBase()
    self.playerShieldHits = self.playerShieldMax
    self.playerHullHits = HULL_HITS
    self.communicationHistory = {}
    self.communicationHistoryKeys = {}
    self.communicationHistoryCursorIndex = 1
    self.communicationHistoryScrollY = 0
    self.communicationHistoryCrankAccumulator = 0
end

function SpaceMiner:openNewStorySlot(slotOverride)
    local slotChoice = tonumber(slotOverride)
    if slotChoice == nil then
        slotChoice = SpaceMiner.chooseNewStorySlot()
    else
        slotChoice = clamp(math.floor(slotChoice), 1, STORY_SAVE_SLOT_COUNT)
    end
    self.storySaveSlot = slotChoice
    self.storySaveName = STORY_SAVE_EMPTY_SLOT_NAME
    self.playerName = self.storySaveName
    self.storySaveSequence = 0
    self:prepareNewStorySaveState()
    self.storySlotSelectorOpen = false
    self.storySlotSelectorCrankAccumulator = 0
    self.storyNameEntryIndex = 1
    self.storyNameEntryCrankAccumulator = 0
    self.storyNameKeyboardRows = STORY_NAME_KEYBOARD_ROWS
    self.storyNameKeyboardRow = 1
    self.storyNameKeyboardCol = 1
    self.storyNameKeyboardIndex = 1
    self.storyNameKeyboardCrankAccumulator = 0
    self.storyNameKeyboardShown = false
    self.storyNameKeyboardClosed = false
    self.storyNameKeyboardPending = false
    self.storyNameKeyboardShift = false
    self.storyNameKeyboardCapsLock = false
    self.storyNameKeyboardDpadHoldDirection = 0
    self.storyNameKeyboardDpadHoldFrames = 0
    self.storyNameKeyboardText = nil
    self.storyNameAccepted = false
    self.storySlotSelectorMode = nil
    self.nameEntryOpen = true
end

function SpaceMiner:normalizeSavedStageRuntime(rawRuntime)
    local schedule = self:getModeStageSchedule()
    local stage = schedule[self.stageIndex]
    local default = {
        alertStarted = false,
        alertStartFrame = nil,
        waveStartFrame = stage and stage.waveStartFrame or nil,
        spawnedEntries = {},
        communicationBlockIndex = 1,
        objectiveStartMinedChunks = self.minedChunks or 0,
        objectiveStartDestroyedEnemies = self.destroyedEnemies or 0,
        objectiveComplete = false,
        completedActions = {}
    }

    local normalized = {}
    for key, value in pairs(default) do
        normalized[key] = value
    end

    if type(rawRuntime) ~= "table" then
        return normalized
    end

    for key, value in pairs(rawRuntime) do
        if key == "alertStartFrame" then
            local alertFrame = tonumber(value)
            if alertFrame ~= nil then
                normalized[key] = alertFrame
            end
        elseif key == "waveStartFrame" then
            local waveFrame = tonumber(value)
            if waveFrame ~= nil then
                normalized[key] = waveFrame
            end
        elseif key == "spawnedEntries" then
            if type(value) == "table" then
                local migratedSpawnedEntries = {}
                local hasNormalizedEntries = false
                for spawnedKey, count in pairs(value) do
                    if type(spawnedKey) == "string" and spawnedKey ~= "" then
                        hasNormalizedEntries = true
                        migratedSpawnedEntries[spawnedKey] = tonumber(count) or 0
                    elseif type(spawnedKey) == "number" and value[spawnedKey] ~= nil then
                        local entry = stage and stage.entries and stage.entries[spawnedKey]
                        if type(entry) == "table" and entry.id ~= nil then
                            hasNormalizedEntries = true
                            migratedSpawnedEntries[tostring(entry.id)] = tonumber(value[spawnedKey]) or 0
                        end
                    end
                end
                if hasNormalizedEntries then
                    normalized[key] = migratedSpawnedEntries
                end
            end
        elseif key == "communicationBlockIndex" then
            local index = tonumber(value)
            if index == nil then
                normalized[key] = 1
            else
                local maxIndex = 1
                if stage ~= nil and type(stage.communicationBlockEntries) == "table" then
                    maxIndex = math.max(1, #stage.communicationBlockEntries)
                end
                normalized[key] = clamp(math.floor(index), 1, maxIndex)
            end
        elseif key == "objectiveStartMinedChunks" then
            normalized[key] = math.max(0, math.floor(tonumber(value) or default[key]))
        elseif key == "objectiveStartDestroyedEnemies" then
            normalized[key] = math.max(0, math.floor(tonumber(value) or default[key]))
        elseif key == "alertStarted" then
            normalized[key] = value == true
        elseif key == "objectiveComplete" then
            normalized[key] = value == true
        elseif key == "completedActions" then
            if type(value) == "table" then
                normalized[key] = value
            end
        elseif normalized[key] == nil then
            normalized[key] = value
        end
    end

    if type(normalized.spawnedEntries) ~= "table" then
        normalized.spawnedEntries = {}
    end
    if type(normalized.completedActions) ~= "table" then
        normalized.completedActions = {}
    end

    return normalized
end

function SpaceMiner:loadCommunicationHistoryFromSave(rawHistory)
    self.communicationHistory = {}
    self.communicationHistoryKeys = {}
    local loadedCount = 0
    if type(rawHistory) ~= "table" then
        self.communicationHistoryCursorIndex = 1
        self.communicationHistoryScrollY = 0
        self.communicationHistoryCrankAccumulator = 0
        return
    end

    for _, entry in ipairs(rawHistory) do
        local cleanEntry
        if type(entry) == "table" then
            cleanEntry = {
                id = tostring(entry.id or "communication"),
                timestamp = entry.timestamp or entry.time,
                text = tostring(entry.text or ""),
                source = tostring(entry.source or "Scout"),
                frame = tonumber(entry.frame) or (self.frame or 0)
            }
        elseif type(entry) == "string" then
            cleanEntry = {
                id = "legacy-communication",
                source = "Scout",
                text = tostring(entry),
                frame = self.frame or 0
            }
        end

        if cleanEntry ~= nil and cleanEntry.text ~= "" then
            local historyKey = string.format("%s|%s|%s|%d", tostring(cleanEntry.id or ""), tostring(cleanEntry.timestamp or ""), tostring(cleanEntry.text or ""), tonumber(cleanEntry.frame) or 0)
            if self.communicationHistoryKeys[historyKey] ~= true then
                self.communicationHistory[#self.communicationHistory + 1] = cleanEntry
                self.communicationHistoryKeys[historyKey] = true
                loadedCount = loadedCount + 1
                if loadedCount >= 200 then
                    break
                end
            end
        end
    end

    self.communicationHistoryCursorIndex = 1
    self.communicationHistoryScrollY = 0
    self.communicationHistoryCrankAccumulator = 0
    self:trimCommunicationHistory(80)
end

function SpaceMiner:handleStorySlotSelector(upPressed, downPressed, primaryJustPressed)
    local items = self:getStorySlotSelectorItems()
    if #items == 0 then
        return true
    end
    self.storySlotSelectorIndex = clamp(self.storySlotSelectorIndex or 1, 1, #items)
    if upPressed then
        self.storySlotSelectorIndex = ((self.storySlotSelectorIndex - 2) % #items) + 1
        self.storySlotSelectorCrankAccumulator = 0
    elseif downPressed then
        self.storySlotSelectorIndex = (self.storySlotSelectorIndex % #items) + 1
        self.storySlotSelectorCrankAccumulator = 0
    elseif primaryJustPressed then
        local selected = items[self.storySlotSelectorIndex] or items[1]
        if selected.action == "delete-toggle" then
            self.storySlotSelectorDeleteMode = not (self.storySlotSelectorDeleteMode == true)
        elseif selected.action == "load" then
            if self.storySlotSelectorDeleteMode then
                local deleted = SpaceMiner.deleteStorySlot(selected.slot)
                StarryLog.info("miner story save deleted slot=%d result=%s", selected.slot, tostring(deleted))
                if deleted then
                    if self.storySaveSlot == selected.slot then
                        self.storySaveSlot = nil
                    end
                    if self.storySlotSelectorMode == SpaceMiner.MODE_CONTINUE_STORY and not SpaceMiner.hasAnyStorySave() then
                        self.storySlotSelectorMode = SpaceMiner.MODE_NEW_SAVE
                        self.storySlotSelectorIndex = 1
                    end
                end
                return true
            end
            self.storySaveSlot = selected.slot
            local data = SpaceMiner.readStorySlot(selected.slot)
            self.storySaveName = data and data.saveName or selected.label
            self.storySlotSelectorOpen = false
            self.storySlotSelectorCrankAccumulator = 0
            self.storySlotSelectorMode = nil
            local loaded = self:loadModeSave()
            if not loaded then
                self:openNewStorySlot(selected.slot)
                self.storySlotSelectorMode = nil
            end
            StarryLog.info("miner story save selected slot=%d name=%s", selected.slot, tostring(self.storySaveName))
        elseif selected.action == "new" then
            if self.storySlotSelectorDeleteMode then
                local deleted = SpaceMiner.deleteStorySlot(selected.slot)
                StarryLog.info("miner story save deleted slot=%d result=%s", selected.slot, tostring(deleted))
                if deleted then
                    if self.storySaveSlot == selected.slot then
                        self.storySaveSlot = nil
                    end
                    if self.storySlotSelectorMode == SpaceMiner.MODE_CONTINUE_STORY and not SpaceMiner.hasAnyStorySave() then
                        self.storySlotSelectorMode = SpaceMiner.MODE_NEW_SAVE
                        self.storySlotSelectorIndex = 1
                    end
                end
            else
                self:openNewStorySlot(selected.slot)
            end
        elseif selected.action == "delete-slot" then
            local deleted = SpaceMiner.deleteStorySlot(selected.slot)
            StarryLog.info("miner story save deleted slot=%d result=%s", selected.slot, tostring(deleted))
            if deleted and self.storySaveSlot == selected.slot then
                self.storySaveSlot = nil
            end
            if self.storySlotSelectorMode == SpaceMiner.MODE_CONTINUE_STORY and not SpaceMiner.hasAnyStorySave() then
                self.storySlotSelectorMode = SpaceMiner.MODE_NEW_SAVE
                self.storySlotSelectorIndex = 1
            end
        elseif selected.action == "back" then
            self.storySlotSelectorOpen = false
            self.storySlotSelectorCrankAccumulator = 0
            self.storySlotSelectorMode = nil
            self.storySlotSelectorDeleteMode = false
        end
    end
    return true
end

function SpaceMiner:drawStorySlotSelector()
    if not self.storySlotSelectorOpen then
        return
    end
    local items = self:getStorySlotSelectorItems()
    local boxX = 28
    local boxY = 24
    local boxWidth = 344
    local rowHeight = 30
    local rowGap = 4
    local boxHeight = 58 + (#items * (rowHeight + rowGap))
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.55, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(boxX, boxY, boxWidth, boxHeight, 6)
    gfx.setColor(gfx.kColorBlack)
    local title = "Story Mode"
    if self.storySlotSelectorMode == SpaceMiner.MODE_NEW_SAVE then
        title = "New Story Mode"
    elseif self.storySlotSelectorMode == SpaceMiner.MODE_CONTINUE_STORY then
        title = "Continue Story Mode"
    end
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawTextAligned(title, SCREEN_WIDTH * 0.5, boxY + 10, kTextAlignment.center)
    gfx.drawLine(boxX + 12, boxY + 34, boxX + boxWidth - 12, boxY + 34)
    for index, item in ipairs(items) do
        local rowY = boxY + 38 + ((index - 1) * (rowHeight + rowGap))
        local selected = index == self.storySlotSelectorIndex
        self:drawModernMenuButton({ label = tostring(item.label or "") }, boxX + 10, rowY, boxWidth - 20, rowHeight, selected)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
end

function SpaceMiner:drawNameEntryPage()
    if not self.nameEntryOpen then
        return
    end
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.72, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    self:drawCommunicationBox({
        text = "What is your name?",
        startFrame = self.frame,
        endFrame = self.frame + 120,
        x = 74,
        y = self.storyNameKeyboardShown and 12 or 58,
        width = 252,
        blocking = true,
        requiredButton = "A"
    }, true)
    local boxX = 40
    local boxY = self.storyNameKeyboardShown and 52 or 78
    local boxWidth = SCREEN_WIDTH - (boxX * 2)
    local optionHeight = self.storyNameKeyboardShown and 24 or 28
    local options = {
        "Name: " .. tostring(self.storyNameKeyboardText or self.playerName or self.storySaveName or STORY_SAVE_EMPTY_SLOT_NAME),
        "Submit"
    }
    local selectIndex = clamp(self.storyNameEntryIndex or 1, 1, 2)
    for index, option in ipairs(options) do
        local rowY = boxY + ((index - 1) * (optionHeight + 2))
        local selected = index == selectIndex
        local label = option
        if index == 1 then
            label = "Name"
        end
        self:drawModernMenuButton({ label = label }, boxX, rowY, boxWidth, optionHeight, selected)
        if index == 1 then
            if selected then
                gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
            else
                gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
            end
            gfx.drawTextInRect(
                tostring(self.storyNameKeyboardText or self.playerName or self.storySaveName or STORY_SAVE_EMPTY_SLOT_NAME),
                boxX + 10,
                rowY + 2,
                boxWidth - 20,
                optionHeight - 4,
                nil,
                nil,
                kTextAlignment.left,
                nil
            )
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
        end
    end
    local statusY = boxY + (optionHeight * 2) + 8
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawTextAligned(self.storyNameKeyboardShown and "Use A to press keys. Enter to continue." or "Use A to select", SCREEN_WIDTH * 0.5, statusY, kTextAlignment.center)

    if self.storyNameKeyboardShown then
        local keyboardY = SCREEN_HEIGHT * 0.5
        local keyboardRows = self:getStoryNameKeyboardRows()
        local keyboardWidth = SCREEN_WIDTH - 16
        local rowGap = 6
        local rowCount = #keyboardRows
        local rowHeight = math.floor((SCREEN_HEIGHT - math.floor(keyboardY) - 12 - (rowGap * (rowCount - 1))) / rowCount)
        local firstRowY = math.floor(keyboardY) + 6
        for rowIndex, row in ipairs(keyboardRows) do
            if #row > 0 then
                local rowLength = #row
                local keyGap = 4
                local keyWidth = math.floor((keyboardWidth - (keyGap * (rowLength - 1))) / rowLength)
                local rowY = firstRowY + ((rowIndex - 1) * (rowHeight + rowGap))
                local keyX = 8
                for colIndex, key in ipairs(row) do
                    local selected = rowIndex == clamp(self.storyNameKeyboardRow or 1, 1, #keyboardRows) and colIndex == clamp(self.storyNameKeyboardCol or 1, 1, rowLength)
                    local isSelected = selected
                    local displayKey = self:getStoryNameKeyboardDisplayKey(key, isSelected)
                    if key == "Space" then
                        displayKey = "Spc"
                    elseif key == "Caps" then
                        if self.storyNameKeyboardCapsLock then
                            displayKey = "CAPS"
                        end
                    elseif key == "Shift" then
                        if self.storyNameKeyboardShift then
                            displayKey = "SHIFT"
                        end
                    elseif key == "Del" then
                        displayKey = "DEL"
                    elseif key == "Enter" then
                        displayKey = "ENT"
                    end
                    self:drawModernMenuButton({ label = displayKey }, keyX, rowY, keyWidth, rowHeight, selected)
                    keyX = keyX + keyWidth + keyGap
                end
            end
        end
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function SpaceMiner:handlePrimaryAction()
    if self.preview then
        return
    end
    if self.storyNameActionHandledFrame == self.frame then
        return
    end
    if self.storySlotSelectorOpen then
        self:handleStorySlotSelector(false, false, true)
        return
    end
    if self.nameEntryOpen then
        return
    end
    if not self.gameOver then
        if self:acknowledgeCommunicationBlock("A") then
            self.communicationBlockAckFrame = self.frame
            return
        end
        if self:dismissActiveCommunication() then
            return
        end
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
    return distanceSquared(self.player.x, self.player.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y)) <= (radius * radius)
end

function SpaceMiner:openShipMenu()
    self.menuOpen = true
    self.menuType = "ship"
    self.homeMenuScreen = "directory"
    self.shipMenuScreen = "directory"
    self.shipMenuPreviousScreenForCommunication = "directory"
    self.shipDirectoryIndex = 1
    self.menuScrollOffset = 1
    self.menuIndex = 1
    self.menuCrankAccumulator = 0
    self.menuRotaryVelocity = 0
    self.menuRotaryFreeSpin = false
    self.menuDpadHoldDirection = 0
    self.menuDpadHoldFrames = 0
    self.menuInputIgnoreFrames = 1
    self.menuOpenedAtX = self.player.x
    self.menuOpenedAtY = self.player.y
    self.homeMenuAutoCloseFrames = nil
    self:playMenuOpenSound()
end

function SpaceMiner:openHomeBaseMenu()
    self.menuOpen = true
    self.menuType = "home"
    self.homeMenuScreen = self.weaponsDisabled and "apology" or "directory"
    self.menuScrollOffset = 1
    self.menuIndex = 1
    self.menuCrankAccumulator = 0
    self.menuRotaryVelocity = 0
    self.menuRotaryFreeSpin = false
    self.menuDpadHoldDirection = 0
    self.menuDpadHoldFrames = 0
    self.homeDirectoryIndex = 1
    self.menuInputIgnoreFrames = 1
    self.menuOpenedAtX = self.player.x
    self.menuOpenedAtY = self.player.y
    self.homeMenuMessage = self.weaponsDisabled and nil or self:getHomeBaseMenuMessage()
    self.homeMenuScoutHidden = false
    self.homeMenuAutoCloseFrames = (#self.enemyShips > 0 or #self.enemyMissiles > 0) and 120 or nil
    self:playMenuOpenSound()
end

function SpaceMiner:getLocalTimestampText()
    local function formatParts(parts)
        if type(parts) ~= "table" then
            return nil
        end
        local months = {
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        }
        local year = tonumber(parts.year)
        local month = tonumber(parts.month or parts.mon)
        local day = tonumber(parts.day or parts.mday)
        local hour = tonumber(parts.hour)
        local minute = tonumber(parts.minute or parts.min)
        if year == nil or month == nil or day == nil or hour == nil or minute == nil then
            return nil
        end
        local suffix = "th"
        if day % 100 < 11 or day % 100 > 13 then
            local digit = day % 10
            if digit == 1 then
                suffix = "st"
            elseif digit == 2 then
                suffix = "nd"
            elseif digit == 3 then
                suffix = "rd"
            end
        end
        local period = hour >= 12 and "PM" or "AM"
        local hour12 = hour % 12
        if hour12 == 0 then
            hour12 = 12
        end
        return string.format("%s %d%s, %d %02d:%02d %s", months[month] or "January", day, suffix, year, hour12, minute, period)
    end

    if pd.getTime ~= nil then
        local ok, timestamp = pcall(function()
            return formatParts(pd.getTime())
        end)
        if ok and type(timestamp) == "string" and timestamp ~= "" then
            return timestamp
        end
    end
    local ok, timestamp = pcall(function()
        return formatParts(os.date("*t"))
    end)
    if ok and type(timestamp) == "string" and timestamp ~= "" then
        return timestamp
    end
    return "June 25th, 2026 12:00 PM"
end

function SpaceMiner:recordCommunicationHistory(id, text, source, startFrame)
    if text == nil or text == "" then
        return
    end

    self.communicationHistory = self.communicationHistory or {}
    self.communicationHistoryKeys = self.communicationHistoryKeys or {}
    local entryId = tostring(id or source or "communication")
    local timestamp = self:getLocalTimestampText()
    local sourceFrame = tonumber(startFrame) or self.frame or 0
    local key = string.format("%s|%s|%d", entryId, tostring(text), sourceFrame)
    if self.communicationHistoryKeys[key] == true then
        return
    end

    self.communicationHistory[#self.communicationHistory + 1] = {
        id = entryId,
        timestamp = timestamp,
        text = text,
        source = source,
        frame = sourceFrame
    }
    self.communicationHistoryKeys[key] = true
    self:trimCommunicationHistory(80)
end

function SpaceMiner:getCommunicationHistoryTimestamp(entry)
    local timestamp = tostring((entry or {}).timestamp or "")
    if timestamp == "" or string.sub(timestamp, 1, 5) == "Frame" then
        return self:getLocalTimestampText()
    end
    return timestamp
end

function SpaceMiner:getCommunicationHistorySpeaker(entry)
    local source = string.lower(tostring((entry or {}).source or ""))
    local id = string.lower(tostring((entry or {}).id or ""))
    local text = tostring((entry or {}).text or "")
    if source == "console" or source == "system" or string.find(id, "console", 1, true) ~= nil then
        return "Console"
    end
    if string.find(text, "Mission:", 1, true) ~= nil or string.find(text, "Warning:", 1, true) ~= nil then
        return "Console"
    end
    return "Scout"
end

function SpaceMiner:wrapHistoryText(text, maxWidth)
    local lines = {}
    for paragraph in string.gmatch(tostring(text or "") .. "\n", "([^\n]*)\n") do
        if paragraph == "" then
            lines[#lines + 1] = ""
        else
            local current = ""
            for word in string.gmatch(paragraph, "%S+") do
                local candidate = current == "" and word or (current .. " " .. word)
                if gfx.getTextSize(candidate) <= maxWidth then
                    current = candidate
                else
                    if current ~= "" then
                        lines[#lines + 1] = current
                    end
                    current = word
                end
            end
            if current ~= "" then
                lines[#lines + 1] = current
            end
        end
    end
    return lines
end

function SpaceMiner:getCommunicationHistoryReaderLines()
    local lines = {}
    local y = 0
    local lineHeight = 15
    local textWidth = SCREEN_WIDTH - 44
    local function addLine(text, kind)
        lines[#lines + 1] = {
            text = tostring(text or ""),
            kind = kind or "body",
            y = y,
            height = lineHeight
        }
        y = y + lineHeight
    end

    if #(self.communicationHistory or {}) == 0 then
        addLine("Console: " .. self:getLocalTimestampText(), "header")
        addLine("No communications logged yet.", "body")
        return lines, y
    end

    for index, entry in ipairs(self.communicationHistory or {}) do
        addLine(self:getCommunicationHistorySpeaker(entry) .. ": " .. self:getCommunicationHistoryTimestamp(entry), "header")
        for _, line in ipairs(self:wrapHistoryText(entry.text, textWidth)) do
            addLine(line, "body")
        end
        if index < #self.communicationHistory then
            addLine("", "blank")
        end
    end
    return lines, y
end

function SpaceMiner:moveCommunicationHistoryCursor(direction)
    local lines = self:getCommunicationHistoryReaderLines()
    if #lines <= 0 then
        return
    end
    self.communicationHistoryCursorIndex = clamp((self.communicationHistoryCursorIndex or 1) + direction, 1, #lines)
    local cursorLine = lines[self.communicationHistoryCursorIndex]
    local contentTop = 38
    local contentBottom = SCREEN_HEIGHT - 14
    local cursorY = contentTop + cursorLine.y - (self.communicationHistoryScrollY or 0)
    if cursorY < contentTop then
        self.communicationHistoryScrollY = math.max(0, cursorLine.y)
    elseif cursorY + cursorLine.height > contentBottom then
        self.communicationHistoryScrollY = math.max(0, cursorLine.y - (contentBottom - contentTop - cursorLine.height))
    end
end

function SpaceMiner:updateCommunicationHistoryReaderInput(upPressed, downPressed, leftPressed)
    if leftPressed then
        self:handleBack()
        return
    end
    if upPressed then
        self:moveCommunicationHistoryCursor(-1)
    elseif downPressed then
        self:moveCommunicationHistoryCursor(1)
    end
end

function SpaceMiner:trimCommunicationHistory(maxEntries)
    self.communicationHistory = self.communicationHistory or {}
    maxEntries = maxEntries or 80
    while #self.communicationHistory > maxEntries do
        table.remove(self.communicationHistory, 1)
    end
    self.communicationHistoryKeys = {}
    for _, entry in ipairs(self.communicationHistory) do
        local entryId = tostring(entry.id or entry.source or "communication")
        local sourceFrame = tonumber(entry.frame) or 0
        local key = string.format("%s|%s|%d", entryId, tostring(entry.text or ""), sourceFrame)
        self.communicationHistoryKeys[key] = true
    end
end

function SpaceMiner:rememberCommunicationSeenKey(key)
    if key == nil or key == "" then
        return
    end
    self.communicationSeenKeys = self.communicationSeenKeys or {}
    self.communicationSeenOrder = self.communicationSeenOrder or {}
    if self.communicationSeenKeys[key] == true then
        return
    end
    self.communicationSeenKeys[key] = true
    self.communicationSeenOrder[#self.communicationSeenOrder + 1] = key
    while #self.communicationSeenOrder > 120 do
        local oldKey = table.remove(self.communicationSeenOrder, 1)
        if oldKey ~= nil then
            self.communicationSeenKeys[oldKey] = nil
        end
    end
end

function SpaceMiner:pruneCommunicationCachesIfNeeded()
    if self.preview or self.titleStandby or ((self.frame or 0) % 300) ~= 0 then
        return
    end
    for key, untilFrame in pairs(self.dismissedCommunications or {}) do
        if tonumber(untilFrame) == nil or self.frame >= untilFrame then
            self.dismissedCommunications[key] = nil
        end
    end
    self:trimCommunicationHistory(80)
    if collectgarbage ~= nil and ((self.frame or 0) % 900) == 0 then
        collectgarbage("step", 80)
    end
end

function SpaceMiner:getCommunicationHistoryMenuItems()
    local items = {}
    for _, entry in ipairs(self.communicationHistory or {}) do
        items[#items + 1] = {
            id = string.format("%s-%d", tostring(entry.id or "communication"), tonumber(entry.frame) or 0),
            label = tostring(entry.timestamp or "Unknown time"),
            value = tostring(entry.text or ""),
            kind = "button",
            action = "history-line",
            enabled = true
        }
    end

    if #items == 0 then
        items[#items + 1] = {
            id = "history-empty",
            label = "No communications logged yet.",
            value = "",
            kind = "button",
            action = "history-line",
            enabled = true
        }
    end

    items[#items + 1] = {
        id = "history-back",
        label = "Back",
        kind = "button",
        action = "back"
    }
    return items
end

function SpaceMiner:getTriggerEventMenuItems()
    local items = {}
    local stageSchedule = self:getModeStageSchedule()
    if #stageSchedule == 0 then
        items[#items + 1] = {
            id = "no-events",
            label = "No events available.",
            kind = "header"
        }
    else
        for index, stage in ipairs(stageSchedule) do
            items[#items + 1] = {
                id = stage.id or string.format("stage-%d", index),
                label = stage.id or string.format("stage-%d", index),
                value = stage.label or stage.kind or "",
                kind = "button",
                action = "trigger-specific-event",
                stageIndex = index,
                enabled = true
            }
        end
    end

    items[#items + 1] = {
        id = "trigger-event-back",
        label = "Back",
        kind = "button",
        action = "back"
    }
    return items
end

function SpaceMiner:closeMenu()
    if self.menuOpen and self:isStoryMode() then
        self:saveModeState()
    end
    self.menuOpen = false
    self.homeMenuAutoCloseFrames = nil
    self.menuScrollOffset = 1
    self.shipMenuPreviousScreenForCommunication = nil
    self.player.laserOn = false
    self.input.laser = false
    self:playMenuBackSound()
end

function SpaceMiner:getMenuItems()
    if self.menuType == "home" then
        return self:getHomeMenuItems()
    end
    return self:getShipMenuItems()
end

function SpaceMiner:getShipMenuItems()
    local items = {}
    if self.shipMenuScreen == "communications" then
        return {
            {
                id = "communication-history-reader",
                label = "Communication History",
                kind = "button",
                action = "history-reader"
            }
        }
    end
    local function addCommunicationHistoryShortcut(menuItems)
        for _, item in ipairs(menuItems) do
            if item.id == "ship-communication-history" then
                return false
            end
        end
        menuItems[#menuItems + 1] = {
            id = "ship-communication-history",
            label = "Communication History",
            kind = "button",
            action = "open-screen",
            value = "Open",
            targetScreen = "communications"
        }
        return true
    end
    if self.shipMenuScreen == "trigger-event" then
        items = self:getTriggerEventMenuItems()
        addCommunicationHistoryShortcut(items)
        return items
    end
    if self.shipMenuScreen == "auto-pilot" then
        items[#items + 1] = {
            id = "auto-pilot-home-base",
            label = "Home Base",
            kind = "button",
            action = "auto-home-base"
        }
        items[#items + 1] = {
            id = "auto-pilot-auto-miner",
            label = "Auto Miner",
            kind = "button",
            action = "auto-miner"
        }
        items[#items + 1] = {
            id = "auto-pilot-grid-100-100",
            label = "Grid 100,100",
            kind = "button",
            action = "auto-coordinate",
            destination = "100,100"
        }
        items[#items + 1] = {
            id = "auto-pilot-back",
            label = "Back",
            kind = "button",
            action = "back"
        }
        addCommunicationHistoryShortcut(items)
        return items
    end
    if self.shipMenuScreen == "right-button" then
        items[#items + 1] = {
            id = "right-button-missile",
            label = "Missile Launch",
            kind = "button",
            value = self.rightButtonMode == "missile",
            action = "set-right-button-mode",
            mode = "missile"
        }
        items[#items + 1] = {
            id = "right-button-turbo",
            label = "Turbo Boost",
            kind = "button",
            value = self.rightButtonMode == "turbo-boost",
            action = "set-right-button-mode",
            mode = "turbo-boost"
        }
        items[#items + 1] = {
            id = "right-button-back",
            label = "Back",
            kind = "button",
            action = "back"
        }
        addCommunicationHistoryShortcut(items)
        return items
    end

    items[#items + 1] = {
        id = "ship-auto-pilot-menu",
        label = "Auto Pilot",
        kind = "button",
        value = self.homeBaseAutopilot ~= nil and (self.homeBaseAutopilot.label or "On") or "Off",
        action = "open-screen",
        targetScreen = "auto-pilot"
    }
    items[#items + 1] = {
        id = "right-button-menu",
        label = "Right D Pad Mapping",
        kind = "button",
        value = self.rightButtonMode == "turbo-boost" and "Turbo Boost" or "Missile Launch",
        action = "open-screen",
        targetScreen = "right-button"
    }
    items[#items + 1] = {
        id = "trigger-next-event",
        label = "Trigger Next Event",
        kind = "button",
        value = (self:getCurrentStage() ~= nil and self:getCurrentStage().id) or ">",
        action = "open-screen",
        targetScreen = "trigger-event"
    }
    items[#items + 1] = {
        id = "sound-effects",
        label = "Sound Effects",
        value = self:isSoundEnabled(),
        action = "toggle-sound",
        kind = "toggle"
    }
    addCommunicationHistoryShortcut(items)
    return items
end

function SpaceMiner:getPointAngleDegrees(x, y, targetX, targetY)
    return normalizeAngle(math.deg(math.atan(targetY - y, targetX - x)))
end

function SpaceMiner:cancelHomeBaseAutopilot()
    if self.homeBaseAutopilot == nil then
        return
    end

    self.homeBaseAutopilot.phase = "cancel"
    self.homeBaseAutopilot.phaseFrames = 0
    self.homeBaseAutopilot.stopThreshold = self.homeBaseAutopilot.stopThreshold or 0.15
    self:closeMenu()
    self.menuInputIgnoreFrames = 0
    self.virtualCrankAngle = self.player.angle
    StarryLog.info("miner auto pilot home base cancel requested")
end

function SpaceMiner:startHomeBaseAutopilot()
    if self.preview or self.gameOver then
        return
    end

    if self.homeBaseAutopilot ~= nil then
        self:cancelHomeBaseAutopilot()
        return
    end

    self:startCoordinateAutopilot(self.baseWorldX or BASE_WORLD_X, self.baseWorldY or BASE_WORLD_Y, {
        mode = "home-base",
        label = "Home Base",
        settleRadius = BASE_SHIELD_RADIUS + 8,
        stopThreshold = 0.2,
        snapToTarget = true
    })
end

function SpaceMiner:startGridCoordinateAutopilot(destination)
    local gridX, gridY = self:parseGridDestination(destination)
    local targetX, targetY = self:gridToWorld(gridX, gridY)
    self:startCoordinateAutopilot(targetX, targetY, {
        mode = "coordinate",
        label = string.format("Grid %d,%d", gridX, gridY),
        settleRadius = 18,
        stopThreshold = 0.2,
        snapToTarget = false
    })
end

function SpaceMiner:startCoordinateAutopilot(targetX, targetY, options)
    if self.preview or self.gameOver then
        return
    end
    options = options or {}
    local baseDistance = math.sqrt(distanceSquared(self.player.x, self.player.y, targetX, targetY))
    self.homeBaseAutopilot = {
        mode = options.mode or "coordinate",
        label = options.label or "Coordinate",
        phase = "homing",
        phaseFrames = 0,
        targetX = targetX,
        targetY = targetY,
        lastDistance = baseDistance,
        divergingFrames = 0,
        startDistance = baseDistance,
        settleRadius = options.settleRadius or 18,
        brakeRadius = options.brakeRadius or math.max(36, baseDistance * 0.45),
        stopThreshold = options.stopThreshold or 0.2,
        snapToTarget = options.snapToTarget == true
    }
    self.player.pendingMissileTrigger = false
    self.player.laserOn = false
    self.input.laser = false
    self.input.thrust = 0
    self.input.reverse = 0
    self.rightTurboBoostFrames = 0
    self:closeMenu()
    StarryLog.info("miner auto pilot coordinate engaged mode=%s target=%.1f,%.1f distance=%.1f", tostring(self.homeBaseAutopilot.mode), targetX, targetY, baseDistance)
end

function SpaceMiner:startAutoMinerAutopilot()
    if self.preview or self.gameOver then
        return
    end

    if self.homeBaseAutopilot ~= nil and self.homeBaseAutopilot.mode == "auto-miner" then
        self:cancelHomeBaseAutopilot()
        return
    end

    self.homeBaseAutopilot = {
        mode = "auto-miner",
        label = "Auto Miner",
        phase = "mine",
        phaseFrames = 0,
        targetAsteroidId = nil,
        settleRadius = BASE_SHIELD_RADIUS + 8,
        brakeRadius = BASE_SHIELD_RADIUS + 36,
        stopThreshold = 0.2
    }
    self.player.pendingMissileTrigger = false
    self.player.laserOn = false
    self.input.laser = false
    self.input.thrust = 0
    self.input.reverse = 0
    self.rightTurboBoostFrames = 0
    self:closeMenu()
    StarryLog.info("miner auto pilot auto miner engaged")
end

function SpaceMiner:getAutoMinerTargetAsteroid()
    local autopilot = self.homeBaseAutopilot or {}
    local nearest = nil
    local nearestDistanceSq = math.huge
    for _, asteroid in ipairs(self.asteroids or {}) do
        local distanceSq = distanceSquared(self.player.x, self.player.y, asteroid.x, asteroid.y)
        if autopilot.targetAsteroidId ~= nil and asteroid.id == autopilot.targetAsteroidId then
            return asteroid
        end
        if distanceSq < nearestDistanceSq then
            nearest = asteroid
            nearestDistanceSq = distanceSq
        end
    end
    if nearest ~= nil then
        autopilot.targetAsteroidId = nearest.id
    end
    return nearest
end

function SpaceMiner:steerAutopilotToward(targetX, targetY, options)
    options = options or {}
    local autopilot = options.autopilot
    local targetAngle = self:getPointAngleDegrees(self.player.x, self.player.y, targetX, targetY)
    local distance = math.sqrt(distanceSquared(self.player.x, self.player.y, targetX, targetY))
    local speed = magnitude(self.player.vx, self.player.vy)
    local velocityAngle = velocityToScreenDegrees(self.player.vx, self.player.vy)
    local settleRadius = options.settleRadius or 18
    local stopThreshold = options.stopThreshold or 0.2
    local ux, uy = unitVector(targetX - self.player.x, targetY - self.player.y)
    local closingSpeed = (self.player.vx * ux) + (self.player.vy * uy)
    local approachDistance = math.max(0, distance - settleRadius)
    local brakingAcceleration = math.max(0.01, PLAYER_THRUST * self:getThrusterAccelerationMultiplier() * 0.82)
    local stoppingDistance = closingSpeed > 0 and ((closingSpeed * closingSpeed) / (2 * brakingAcceleration)) or 0
    local plannedSpeed = math.max(stopThreshold, math.sqrt(math.max(0, approachDistance) * brakingAcceleration * 1.35))
    local shouldBrake = false
    if autopilot ~= nil then
        local lastDistance = autopilot.lastDistance or distance
        local diverging = distance > (lastDistance + 0.4)
        autopilot.divergingFrames = diverging and ((autopilot.divergingFrames or 0) + 1) or 0
        autopilot.lastDistance = distance
        shouldBrake = (autopilot.divergingFrames or 0) > 8 and speed > stopThreshold
    end

    if closingSpeed > plannedSpeed or stoppingDistance >= approachDistance then
        shouldBrake = speed > stopThreshold
    end

    local desiredAngle = targetAngle
    if shouldBrake and velocityAngle ~= nil then
        desiredAngle = normalizeAngle(velocityAngle + 180)
    elseif closingSpeed < -0.05 then
        desiredAngle = targetAngle
    end

    self.player.angle = lerpAngle(self.player.angle, desiredAngle, shouldBrake and 0.36 or 0.22)
    local angleError = math.abs(shortestAngleDelta(self.player.angle, desiredAngle))
    self.input.thrust = angleError <= 70 and (approachDistance > 0 or speed > stopThreshold) and 1 or 0
    self.input.reverse = 0
    return distance, targetAngle, speed
end

function SpaceMiner:updateCoordinateAutopilot(autopilot)
    local targetX = autopilot.targetX or (self.baseWorldX or BASE_WORLD_X)
    local targetY = autopilot.targetY or (self.baseWorldY or BASE_WORLD_Y)
    local distance, targetAngle, speed = self:steerAutopilotToward(targetX, targetY, {
        autopilot = autopilot,
        brakeRadius = autopilot.brakeRadius or 44,
        settleRadius = autopilot.settleRadius or 18,
        stopThreshold = autopilot.stopThreshold or 0.2
    })
    self.input.laser = false
    self.player.laserOn = false
    if distance <= (autopilot.settleRadius or 18) and speed <= (autopilot.stopThreshold or 0.2) then
        if autopilot.snapToTarget then
            self.player.x = targetX
            self.player.y = targetY
        end
        self.player.vx = 0
        self.player.vy = 0
        self.player.angle = targetAngle
        self.homeBaseAutopilot = nil
        self.input.thrust = 0
        self.input.reverse = 0
        self.menuInputIgnoreFrames = 0
        self.virtualCrankAngle = self.player.angle
        StarryLog.info("miner auto pilot coordinate arrived mode=%s distance=%.1f", tostring(autopilot.mode), distance)
        return true
    end
    return false
end

function SpaceMiner:updateAutoMinerAutopilot(autopilot)
    if (self.cargoOre or 0) > 0 then
        autopilot.phase = "return"
        autopilot.targetAsteroidId = nil
        local distanceToBase, targetAngle, speed = self:steerAutopilotToward((self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y), {
            autopilot = autopilot,
            brakeRadius = BASE_SHIELD_RADIUS + 38,
            settleRadius = BASE_SHIELD_RADIUS + 8,
            stopThreshold = autopilot.stopThreshold or 0.2
        })
        self.input.laser = false
        self.player.laserOn = false
        if distanceToBase <= BASE_SHIELD_RADIUS and (self.cargoOre or 0) <= 0 then
            autopilot.phase = "mine"
            autopilot.phaseFrames = 0
            self.input.thrust = 0
            self.player.angle = targetAngle
            self.virtualCrankAngle = self.player.angle
            StarryLog.info("miner auto pilot auto miner unloaded speed=%.2f", speed)
        end
        return
    end

    if (self.cargoOre or 0) > 0 and #self.asteroids == 0 then
        autopilot.phase = "return"
        return
    end

    local asteroid = self:getAutoMinerTargetAsteroid()
    if asteroid == nil then
        self.input.thrust = 0
        self.input.reverse = 0
        self.input.laser = false
        self.player.laserOn = false
        return
    end

    local distanceToAsteroid = math.sqrt(distanceSquared(self.player.x, self.player.y, asteroid.x, asteroid.y))
    local targetAngle = self:getPointAngleDegrees(self.player.x, self.player.y, asteroid.x, asteroid.y)
    if distanceToAsteroid > (LASER_RANGE * 0.72) then
        distanceToAsteroid, targetAngle = self:steerAutopilotToward(asteroid.x, asteroid.y, {
            autopilot = autopilot,
            brakeRadius = math.max(LASER_RANGE * 0.58, asteroid.radius + 42),
            settleRadius = LASER_RANGE * 0.62,
            stopThreshold = 0.24
        })
    else
        self.player.angle = lerpAngle(self.player.angle, targetAngle, 0.32)
        self.input.thrust = 0
        self.input.reverse = 0
        self.player.vx = self.player.vx * 0.94
        self.player.vy = self.player.vy * 0.94
    end
    local aimDelta = math.abs(shortestAngleDelta(self.player.angle, targetAngle))
    local canFire = distanceToAsteroid <= LASER_RANGE and aimDelta <= 18 and not self:isCargoFull()
    self.input.laser = canFire
    self.player.laserOn = canFire
    if canFire then
        autopilot.phase = "mine"
        autopilot.lastDistance = nil
        autopilot.divergingFrames = 0
    end
end

function SpaceMiner:updateHomeBaseAutopilot()
    local autopilot = self.homeBaseAutopilot
    if autopilot == nil or self.preview or self.gameOver then
        return
    end

    autopilot.phaseFrames = (autopilot.phaseFrames or 0) + 1

    if autopilot.phase == "cancel" then
        self.input.thrust = 0
        self.input.reverse = 0
        self.input.laser = false
        self.player.laserOn = false
        self.player.pendingMissileTrigger = false
        self.player.vx = self.player.vx * 0.9
        self.player.vy = self.player.vy * 0.9
        if magnitude(self.player.vx, self.player.vy) <= (autopilot.stopThreshold or 0.15) then
            self.player.vx = 0
            self.player.vy = 0
            self.homeBaseAutopilot = nil
            self.menuInputIgnoreFrames = 0
            self.virtualCrankAngle = self.player.angle
            StarryLog.info("miner auto pilot home base cancelled and stopped")
        end
        return
    end

    if autopilot.mode == "auto-miner" then
        self:updateAutoMinerAutopilot(autopilot)
        return
    end

    self:updateCoordinateAutopilot(autopilot)
end

function SpaceMiner:getHomeMenuItems()
    local items = {}
    if self.homeMenuScreen == "apology" then
        items[#items + 1] = {
            id = "apologize",
            label = "Apologize",
            kind = "button",
            action = "apologize"
        }
        return items
    end
    if self.homeMenuScreen == "communications" then
        return {
            {
                id = "communication-history-reader",
                label = "Communication History",
                kind = "button",
                action = "history-reader"
            }
        }
    end
    if self.homeMenuScreen == "trigger-event" then
        return self:getTriggerEventMenuItems()
    end
    if self.homeMenuScreen == "directory" then
        return self:getHomeDirectoryMenuItems()
    end

    if self.homeMenuScreen == "settings" then
        return self:getShipSettingsMenuItems()
    end

    if self.homeMenuScreen == "resources" then
        local items = {}
        for _, material in ipairs(ASTEROID_MATERIALS) do
            items[#items + 1] = {
                id = material.id,
                label = material.label,
                value = self.materialMarkerToggles[material.id] == true,
                action = "toggle-material",
                kind = "toggle"
            }
        end
        return items
    end

    local category = self:getUpgradeCategoryForScreen(self.homeMenuScreen)
    if category == nil then
        return items
    end
    for _, upgrade in ipairs(self:getUpgradeList(category)) do
        local owned = self:isUpgradeOwned(category, upgrade.id)
        local active = category == "base" and owned or self:getActiveUpgradeId(category) == upgrade.id
        local cost = self:getUpgradeCost(upgrade)
        items[#items + 1] = {
            id = upgrade.id,
            label = upgrade.name or upgrade.id,
            cost = cost,
            value = active,
            action = (category == "base" and owned) and "owned-upgrade" or ((owned or self.testModeEnabled) and "equip-upgrade" or "buy-upgrade"),
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
            kind = "button",
            value = (self:getCurrentStage() ~= nil and self:getCurrentStage().id) or ">",
            action = "open-screen",
            targetScreen = "trigger-event"
        },
        {
            id = "test-mode",
            label = "Test Mode",
            value = self.testModeEnabled == true,
            action = "toggle-test-mode",
            kind = "toggle"
        },
        {
            id = "sound-effects",
            label = "Sound Effects",
            value = self:isSoundEnabled(),
            action = "toggle-sound",
            kind = "toggle"
        },
        {
            id = "communication-history",
            label = "Communication History",
            kind = "button",
            action = "open-screen",
            targetScreen = "communications"
        },
        {
            id = "resource-settings",
            label = "Ore Resources",
            kind = "button",
            action = "open-screen",
            targetScreen = "resources"
        }
    }
    return items
end

function SpaceMiner:toggleMenuSelection()
    local item = self:getMenuItems()[self.menuIndex]
    if item == nil then
        return
    end
    local shouldPersist = false
    if item.kind == "header" then
        return
    end
    if item.action == "apologize" then
        self.weaponsDisabled = false
        self.blockedWeaponButtons = {}
        self.scoutToleranceCount = 0
        self.scoutToleranceTimer = 0
        self.playerShieldHits = self.playerShieldMax or SHIELD_MAX
        self.playerHullHits = HULL_HITS
        self.player.pendingMissileTrigger = false
        self.player.laserOn = false
        self.input.laser = false
        self.homeMenuScreen = "directory"
        self:closeMenu()
        return
    end
    if item.action == "open-screen" then
        if self.menuType == "home" then
            self.homeDirectoryIndex = self.menuIndex
            self.homeMenuScreen = item.targetScreen or item.id
            if self.homeMenuScreen == "communications" then
                self.communicationHistoryCursorIndex = 1
                self.communicationHistoryScrollY = 0
                self.communicationHistoryCrankAccumulator = 0
            end
        else
            local previousScreen = self.shipMenuScreen or "directory"
            if self.shipMenuScreen == "directory" then
                self.shipDirectoryIndex = self.menuIndex
            end
            self.shipMenuScreen = item.targetScreen or item.id
            if self.shipMenuScreen == "communications" then
                self.communicationHistoryCursorIndex = 1
                self.communicationHistoryScrollY = 0
                self.communicationHistoryCrankAccumulator = 0
                self.shipMenuPreviousScreenForCommunication = previousScreen
            end
        end
        self.menuIndex = 1
        self.menuScrollOffset = 1
    elseif item.action == "auto-home-base" then
        self:startHomeBaseAutopilot()
        return
    elseif item.action == "auto-miner" then
        self:startAutoMinerAutopilot()
        return
    elseif item.action == "auto-coordinate" then
        self:startGridCoordinateAutopilot(item.destination or "0,0")
        return
    elseif item.action == "back" then
        self:handleBack()
        return
    elseif item.action == "history-reader" then
        if self.menuType == "home" then
            self.homeMenuScreen = "communications"
        else
            local previousScreen = self.shipMenuScreen or "directory"
            if self.shipMenuScreen == "directory" then
                self.shipDirectoryIndex = self.menuIndex
            end
            self.shipMenuScreen = "communications"
            self.shipMenuPreviousScreenForCommunication = previousScreen
        end
        self.communicationHistoryCursorIndex = 1
        self.communicationHistoryScrollY = 0
        self.communicationHistoryCrankAccumulator = 0
        self.menuIndex = 1
        self.menuScrollOffset = 1
        return
    elseif item.action == "buy-upgrade" or item.action == "equip-upgrade" then
        self:purchaseOrEquipUpgrade(item.category, item.id)
        shouldPersist = true
    elseif item.action == "owned-upgrade" then
        return
    elseif item.action == "toggle-test-mode" then
        self.testModeEnabled = not self.testModeEnabled
        shouldPersist = true
    elseif item.action == "trigger-specific-event" then
        self:closeMenu()
        self:triggerSpecificStage(item.stageIndex)
        return
    elseif item.action == "history-line" then
        return
    elseif item.action == "toggle-sound" then
        self:setSoundEnabled(not self:isSoundEnabled())
        shouldPersist = true
    elseif item.action == "set-right-button-mode" then
        self.rightButtonMode = item.mode or "missile"
        shouldPersist = true
    else
        self.materialMarkerToggles[item.id] = not self.materialMarkerToggles[item.id]
        shouldPersist = true
    end
    if shouldPersist and self:isStoryMode() then
        self:saveModeState()
    end
    self:playUiClick()
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

function SpaceMiner:isMenuItemSelectable(item)
    return item ~= nil and item.kind ~= "header"
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
        local cost = self:getUpgradeCost(upgrade)
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

function SpaceMiner:getOwnedBaseUpgradeValue(field, fallback, reducer)
    local value = fallback
    for _, upgrade in ipairs(self:getUpgradeList("base")) do
        if self:isUpgradeOwned("base", upgrade.id) and upgrade[field] ~= nil then
            if reducer == "max" then
                value = math.max(value or upgrade[field], upgrade[field])
            elseif reducer == "sum" then
                value = (value or 0) + upgrade[field]
            else
                value = upgrade[field]
            end
        end
    end
    return value
end

function SpaceMiner:getBaseLaserCount()
    return math.max(1, self:getOwnedBaseUpgradeValue("laserCount", 1, "max") or 1)
end

function SpaceMiner:getBaseLaserEnemyDamageMultiplier()
    return self:getOwnedBaseUpgradeValue("enemyDamageMultiplier", BASE_MINING_LASER_ENEMY_DAMAGE_MULTIPLIER, "max")
end

function SpaceMiner:canBaseFireWithShieldUp()
    return self:getOwnedBaseUpgradeValue("fireWithShieldUp", false) == true
end

function SpaceMiner:getBaseShieldRechargeAmount()
    return SHIELD_RECHARGE_AMOUNT + (self:getOwnedBaseUpgradeValue("shieldRechargeBonus", 0, "sum") or 0)
end

function SpaceMiner:getShipRepairShieldPerSecond()
    return SHIP_REPAIR_SHIELD_PER_SECOND + (self:getOwnedBaseUpgradeValue("shipShieldRepairBonus", 0, "sum") or 0)
end

function SpaceMiner:getShipRepairHullStepFrames()
    local reduction = self:getOwnedBaseUpgradeValue("hullRepairStepReduction", 0, "sum") or 0
    return math.max(6, SHIP_REPAIR_HULL_STEP_FRAMES - reduction)
end

function SpaceMiner:applyShieldUpgradeLevel(level)
    self.shieldLevel = level
    self.playerShieldMax = SHIELD_MAX
    self.playerShieldHits = math.min(self.playerShieldHits or self.playerShieldMax, self.playerShieldMax)
end

function SpaceMiner:getHomeDirectoryScrollOrder(itemCount)
    if itemCount >= 8 then
        return { 1, 3, 5, 7, 8, 2, 4, 6, 7, 8 }
    end
    local order = {}
    for index = 1, itemCount do
        order[#order + 1] = index
    end
    return order
end

function SpaceMiner:stepMenuSelection(direction)
    local itemCount = #self:getMenuItems()
    if itemCount <= 0 then
        return
    end
    if self.menuType == "home" and self.homeMenuScreen == "directory" then
        local order = self:getHomeDirectoryScrollOrder(itemCount)
        local orderIndex = 1
        if self.homeDirectoryOrderCursor ~= nil and order[self.homeDirectoryOrderCursor] == self.menuIndex then
            orderIndex = self.homeDirectoryOrderCursor
        else
            for index, value in ipairs(order) do
                if value == self.menuIndex then
                    orderIndex = index
                    break
                end
            end
        end
        orderIndex = orderIndex + direction
        if orderIndex < 1 then
            orderIndex = #order
        elseif orderIndex > #order then
            orderIndex = 1
        end
        local maxIterations = #order
        while maxIterations > 0 do
            local candidate = order[orderIndex]
            if self:isMenuItemSelectable(self:getMenuItems()[candidate]) then
                self.menuIndex = candidate
                self.homeDirectoryOrderCursor = orderIndex
                break
            end
            orderIndex = orderIndex + direction
            if orderIndex < 1 then
                orderIndex = #order
            elseif orderIndex > #order then
                orderIndex = 1
            end
            maxIterations = maxIterations - 1
        end
        self:playUiClick()
        return
    end

    local nextIndex = self.menuIndex
    local iterations = itemCount
    repeat
        nextIndex = nextIndex + direction
        if nextIndex < 1 then
            nextIndex = itemCount
        elseif nextIndex > itemCount then
            nextIndex = 1
        end
        iterations = iterations - 1
    until self:isMenuItemSelectable(self:getMenuItems()[nextIndex]) or iterations <= 0
    if self:isMenuItemSelectable(self:getMenuItems()[nextIndex]) then
        self.menuIndex = nextIndex
    end
    self:playUiClick()
end

function SpaceMiner:startRotaryMenuSpin(direction, strength)
    if direction == nil or direction == 0 then
        return
    end
    self.menuRotaryVelocity = clamp((self.menuRotaryVelocity or 0) + (direction * (strength or 0.55)), -3.6, 3.6)
    self.menuRotaryFreeSpin = math.abs(self.menuRotaryVelocity or 0) >= 1.2
end

function SpaceMiner:startMenuDpadSpin(direction)
    if direction == nil or direction == 0 then
        return
    end
    self.menuCrankAccumulator = direction * MENU_DPAD_STEP_IMPULSE
    self.menuRotaryVelocity = direction * MENU_DPAD_STEP_VELOCITY
    self.menuRotaryFreeSpin = false
end

function SpaceMiner:updateRotaryMenuSpin()
    if not self.menuOpen
        or (self.menuType == "home" and self.homeMenuScreen == "communications")
        or (self.menuType == "ship" and self.shipMenuScreen == "communications") then
        return
    end
    local velocity = self.menuRotaryVelocity or 0
    local fractionalOffset = self.menuCrankAccumulator or 0
    if math.abs(velocity) < 0.02 and math.abs(fractionalOffset) < 0.02 then
        self.menuRotaryVelocity = 0
        self.menuCrankAccumulator = 0
        self.menuRotaryFreeSpin = false
        return
    end
    self.menuCrankAccumulator = fractionalOffset + velocity
    while self.menuCrankAccumulator >= 1 do
        self:stepMenuSelection(1)
        self.menuCrankAccumulator = self.menuCrankAccumulator - 1
    end
    while self.menuCrankAccumulator <= -1 do
        self:stepMenuSelection(-1)
        self.menuCrankAccumulator = self.menuCrankAccumulator + 1
    end
    if math.abs(velocity) < 0.02 then
        self.menuCrankAccumulator = self.menuCrankAccumulator * 0.72
    end
    self.menuRotaryVelocity = velocity * 0.88
end

function SpaceMiner:handleMenuVerticalInput(upPressed, downPressed)
    local direction = 0
    if upPressed then
        direction = -1
    elseif downPressed then
        direction = 1
    end
    if direction == 0 then
        self.menuDpadHoldDirection = 0
        self.menuDpadHoldFrames = 0
        return false
    end
    if self.menuDpadHoldDirection ~= direction then
        self.menuDpadHoldDirection = direction
        self.menuDpadHoldFrames = 1
        -- A fresh tap while the carousel is coasting catches the current
        -- selection instead of adding another impulse.  A held direction
        -- then builds speed again through the normal inertial path.
        if math.abs(self.menuRotaryVelocity or 0) >= 0.02 or math.abs(self.menuCrankAccumulator or 0) >= 0.02 then
            self.menuRotaryVelocity = 0
            self.menuCrankAccumulator = 0
            self.menuRotaryFreeSpin = false
            return true
        end
        self:startMenuDpadSpin(direction)
        return true
    end
    self.menuDpadHoldFrames = (self.menuDpadHoldFrames or 0) + 1
    if self.menuDpadHoldFrames > MENU_DPAD_HOLD_SPIN_FRAMES then
        self:startRotaryMenuSpin(direction, 0.32)
    end
    return true
end

function SpaceMiner:handleBack()
    if self.menuOpen and self.menuType == "home" and self.homeMenuScreen == "apology" then
        return true
    end
    if self.menuOpen and self.menuType == "home" and (self.homeMenuScreen == "communications" or self.homeMenuScreen == "trigger-event" or self.homeMenuScreen == "resources") then
        self.homeMenuScreen = "settings"
        self.menuIndex = self.homeDirectoryIndex or 1
        self.menuScrollOffset = 1
        self:playMenuBackSound()
        return true
    end
    if self.menuOpen and self.menuType == "ship" and self.shipMenuScreen == "auto-pilot" then
        self.shipMenuScreen = "directory"
        self.menuIndex = 1
        self.menuScrollOffset = 1
        self:playMenuBackSound()
        return true
    end
    if self.menuOpen and self.menuType == "ship" and self.shipMenuScreen == "right-button" then
        self.shipMenuScreen = "directory"
        self.menuIndex = 2
        self.menuScrollOffset = 1
        self:playMenuBackSound()
        return true
    end
    if self.menuOpen and self.menuType == "ship" and self.shipMenuScreen == "trigger-event" then
        self.shipMenuScreen = "directory"
        self.menuIndex = self.shipDirectoryIndex or 1
        self.menuScrollOffset = 1
        self:playMenuBackSound()
        return true
    end
    if self.menuOpen and self.menuType == "ship" and self.shipMenuScreen == "communications" then
        self.shipMenuScreen = self.shipMenuPreviousScreenForCommunication or "directory"
        self.shipMenuPreviousScreenForCommunication = nil
        if self.shipMenuScreen == "directory" then
            self.menuIndex = self.shipDirectoryIndex or 1
        else
            self.menuIndex = 1
        end
        self.menuScrollOffset = 1
        self:playMenuBackSound()
        return true
    end
    if self.menuOpen and self.menuType == "home" and self.homeMenuScreen == "resources" then
        self.homeMenuScreen = "settings"
        self.menuIndex = 1
        self.menuScrollOffset = 1
        self:playMenuBackSound()
        return true
    end
    if self.menuOpen and self.menuType == "home" and self.homeMenuScreen ~= "directory" then
        self.homeMenuScreen = "directory"
        self.menuIndex = self.homeDirectoryIndex or 1
        self.menuScrollOffset = 1
        self:playMenuBackSound()
        return true
    end
    return false
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
    if aPressed
        and self.menuType == "home"
        and not self.homeMenuScoutHidden
        and self.homeMenuMessage ~= nil
        and self.homeMenuMessage ~= "" then
        self.homeMenuScoutHidden = true
        return
    end
    if (self.menuType == "home" and self.homeMenuScreen == "communications")
        or (self.menuType == "ship" and self.shipMenuScreen == "communications") then
        self:updateCommunicationHistoryReaderInput(upPressed, downPressed, leftPressed)
        return
    end
    local itemCount = #self:getMenuItems()
    if itemCount <= 0 then
        return
    end
    if self:handleMenuVerticalInput(upPressed, downPressed) then
        return
    elseif leftPressed and self.menuType == "home" and self.homeMenuScreen ~= "directory" then
        if not self:handleBack() then
            self.homeMenuScreen = "directory"
            self.menuIndex = self.homeDirectoryIndex or 1
        end
    elseif leftPressed and self.menuType == "ship" and self.shipMenuScreen ~= "directory" then
        if not self:handleBack() then
            self.shipMenuScreen = "directory"
            self.menuIndex = 2
        end
    elseif self.menuType == "home" and self.homeMenuScreen == "directory" and (leftPressed or rightPressed) then
        if leftPressed and self.menuIndex >= 2 and self.menuIndex <= 6 and (self.menuIndex % 2) == 0 then
            self.menuIndex = self.menuIndex - 1
            self.homeDirectoryOrderCursor = nil
        elseif rightPressed and self.menuIndex >= 1 and self.menuIndex <= 5 and (self.menuIndex % 2) == 1 then
            self.menuIndex = self.menuIndex + 1
            self.homeDirectoryOrderCursor = nil
        else
            self:stepMenuSelection(rightPressed and 1 or -1)
        end
    elseif leftPressed or rightPressed or aPressed then
        self:toggleMenuSelection()
    end
end

local HOME_BASE_MENU_MESSAGE_RULES <const> = {
    {
        id = "enemy-around",
        matches = function(self)
            return (#self.enemyShips > 0 or #self.enemyMissiles > 0)
        end,
        message = function(self)
            if not self:shouldSuppressDockingComplaints() then
                return BASE_CONFIG.homeBaseEnemyAround or "Scout: Get back out there!"
            end
            if not self.homeBaseEnemyAroundSuppressionLogged then
                StarryLog.info("miner home base enemy-around complaint suppressed by ship self-defense upgrade")
                self.homeBaseEnemyAroundSuppressionLogged = true
            end
            return nil
        end
    },
    {
        id = "critical-health",
        matches = function(self)
            local hullRatio = clamp((self.playerHullHits or HULL_HITS) / HULL_HITS, 0, 1)
            return hullRatio < 0.10
        end,
        message = function()
            return BASE_CONFIG.homeBaseCriticalHealth or "Scout: How are you still alive?"
        end
    },
    {
        id = "below-half-health",
        matches = function(self)
            local hullRatio = clamp((self.playerHullHits or HULL_HITS) / HULL_HITS, 0, 1)
            return hullRatio < 0.50
        end,
        message = function()
            return BASE_CONFIG.homeBaseBelowHalfHealth or "Scout: That damage isn't cheap."
        end
    },
    {
        id = "above-half-health",
        matches = function(self)
            local hullRatio = clamp((self.playerHullHits or HULL_HITS) / HULL_HITS, 0, 1)
            return hullRatio < 1
        end,
        message = function()
            return BASE_CONFIG.homeBaseAboveHalfHealth or "Scout: You're paying for that, right?"
        end
    },
    {
        id = "greeting",
        matches = function(self)
            return self.homeBaseVisitGreetingShown ~= true
        end,
        message = function(self)
            self.homeBaseVisitGreetingShown = true
            local greetings = BASE_CONFIG.homeBaseGreetings or {}
            if #greetings > 0 then
                return greetings[math.random(1, #greetings)]
            end
            return "Scout: Welcome home."
        end
    }
}

function SpaceMiner:getHomeBaseMenuMessage()
    for _, rule in ipairs(HOME_BASE_MENU_MESSAGE_RULES) do
        if rule.matches(self) then
            local message = rule.message(self)
            if message ~= nil and message ~= "" then
                return message
            end
        end
    end
    return nil
end

function SpaceMiner:updateHomeBaseVisitState()
    if not self:isStoryMode() and not self:isOreMinerMode() then
        return
    end
    local enterRadius = BASE_SHIELD_RADIUS
    local exitRadius = BASE_SHIELD_RADIUS + 10
    local distanceSq = distanceSquared(self.player.x, self.player.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y))
    local wasInside = self.wasInHomeBaseShield == true
    local inside = self.wasInHomeBaseShield
        and distanceSq <= (exitRadius * exitRadius)
        or distanceSq <= (enterRadius * enterRadius)
    if inside and not wasInside then
        StarryLog.info("miner home base shield entered frame=%d distanceSq=%d", self.frame, distanceSq)
    elseif not inside and wasInside then
        StarryLog.info("miner home base shield left frame=%d distanceSq=%d", self.frame, distanceSq)
    end
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
    return math.max(0, math.floor((material.cashPerTiny or 1) * tinyScale * ORE_SALE_PRICE_MULTIPLIER))
end

function SpaceMiner:getUpgradeCost(upgrade)
    if upgrade == nil then
        return 0
    end
    return math.max(0, math.floor(((upgrade.cost or 0) * UPGRADE_COST_MULTIPLIER) + 0.5))
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
    if self:isOreMinerMode() then
        return false
    end
    return (self.cargoOre or 0) >= math.floor((self.cargoCapacity or CARGO_INITIAL_CAPACITY) + 0.0001)
end

function SpaceMiner:addCargoFromAsteroid(asteroid)
    if self:isCargoFull() then
        return false
    end

    if self:isOreMinerMode() then
        self.cargoOre = (self.cargoOre or 0) + 1
        self.cargoCapacity = math.max(self.cargoCapacity or CARGO_INITIAL_CAPACITY, self.cargoOre)
        self.cargoCapacityTarget = self.cargoCapacity
    else
        self.cargoOre = math.min(self.cargoOre + 1, math.floor(self.cargoCapacity or CARGO_INITIAL_CAPACITY))
    end
    local cargoCashValue = self:getAsteroidCashValue(asteroid)
    self.cargoValue = (self.cargoValue or 0) + cargoCashValue
    self.cargoLoads[#self.cargoLoads + 1] = cargoCashValue
    self.minedChunks = self.minedChunks + 1
    if not self:isOreMinerMode() then
        self.cargoCapacityTarget = self:getCargoCapacityTarget()
    end
    return true
end

function SpaceMiner:isWithinHomeBaseServiceRange()
    return self:isStoryMode()
        and distanceSquared(self.player.x, self.player.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y)) <= (BASE_SHIELD_RADIUS * BASE_SHIELD_RADIUS)
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

    self.cargoUnloadFrames = (self.cargoUnloadFrames or 0) + CARGO_UNLOAD_PROGRESS_PER_FRAME
    while self.cargoUnloadFrames >= CARGO_UNLOAD_STEP_FRAMES and (self.cargoOre or 0) > 0 do
        self.cargoUnloadFrames = self.cargoUnloadFrames - CARGO_UNLOAD_STEP_FRAMES
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
        local shieldPerFrame = ((self.playerShieldMax or SHIELD_MAX) * self:getShipRepairShieldPerSecond()) / 30
        self.playerShieldHits = math.min(self.playerShieldMax or SHIELD_MAX, (self.playerShieldHits or 0) + shieldPerFrame)
    end

    if (self.playerHullHits or 0) < HULL_HITS then
        self.hullRepairFrames = (self.hullRepairFrames or 0) + 1
        if self.hullRepairFrames >= self:getShipRepairHullStepFrames() then
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

function SpaceMiner:getLaserAsteroidPenetrationPower()
    local upgrade = self:getActiveUpgrade("laser") or {}
    return math.max(1, math.floor(tonumber(upgrade.penetrationPower) or 1))
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

function SpaceMiner:getTractorBeamStats()
    local upgrade = self:getActiveUpgrade("misc") or {}
    local radius = tonumber(upgrade.tractorRadius) or 0
    if radius <= 0 then
        return 0, 0
    end
    return radius, tonumber(upgrade.tractorPull) or 0.2
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

function SpaceMiner:getBaseModeConfig(modeId)
    return BASE_MODES[modeId or ""] or BASE_MODES[BASE_CONFIG.mode or "home-base"] or {
        name = BASE_CONFIG.name or "Home Base",
        shapeMode = BASE_CONFIG.shapeMode or "international-space-station"
    }
end

function SpaceMiner:getBaseModeName(modeId)
    local config = self:getBaseModeConfig(modeId)
    return config.name or BASE_CONFIG.name or "Home Base"
end

function SpaceMiner:getBaseModeShape(modeId)
    local config = self:getBaseModeConfig(modeId)
    return config.shapeMode or BASE_CONFIG.shapeMode or "international-space-station"
end

function SpaceMiner:setBaseMode(modeId, transition)
    local nextModeId = modeId or BASE_CONFIG.mode or "home-base"
    if self.baseModeId == nextModeId then
        self.baseName = self:getBaseModeName(nextModeId)
        return
    end
    self.previousBaseModeId = self.baseModeId
    self.baseModeId = nextModeId
    self.baseModeTransitionFrame = transition == false and BASE_MODE_TRANSITION_FRAMES or 0
    self.baseName = self:getBaseModeName(nextModeId)
    self:buildBaseImage()
end

function SpaceMiner:buildInternationalSpaceStationImage()
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
    return image
end

function SpaceMiner:buildWatcherBaseImage()
    local config = self:getBaseModeConfig("the-watcher")
    if config.imagePath ~= nil then
        local loadedImage = gfx.image.new(config.imagePath)
        if loadedImage ~= nil then
            return loadedImage
        end
    end

    local image = gfx.image.new(92, 54, gfx.kColorClear)
    gfx.pushContext(image)
    gfx.setColor(gfx.kColorWhite)
    local cx, cy = 46, 27
    gfx.drawRoundRect(cx - 30, cy - 13, 60, 26, 6)
    gfx.drawLine(cx - 30, cy - 13, cx - 42, cy - 5)
    gfx.drawLine(cx - 30, cy + 13, cx - 42, cy + 5)
    gfx.drawLine(cx + 30, cy - 13, cx + 40, cy - 7)
    gfx.drawLine(cx + 30, cy + 13, cx + 40, cy + 7)
    local cockpitX = cx
    local cockpitY = cy - 12
    gfx.drawCircleAtPoint(cockpitX, cockpitY, 10)
    gfx.drawCircleAtPoint(cockpitX, cockpitY, 6)
    gfx.drawRect(cx - 39, cy - 8, 9, 5)
    gfx.drawRect(cx - 39, cy + 3, 9, 5)
    local plume = 4 + ((self.frame or 0) % 6)
    gfx.drawLine(cx - 42, cy - 6, cx - 42 - plume, cy - 9)
    gfx.drawLine(cx - 42, cy + 6, cx - 42 - plume, cy + 9)
    gfx.drawLine(cx - 42, cy, cx - 42 - plume - 4, cy)
    gfx.popContext()
    return image
end

function SpaceMiner:buildBaseImage()
    self.baseImage = nil
    self.baseImages = {}
    for modeId, _ in pairs(BASE_MODES) do
        local shapeMode = self:getBaseModeShape(modeId)
        if shapeMode == "the-watcher" then
            self.baseImages[modeId] = self:buildWatcherBaseImage()
        elseif shapeMode == "international-space-station" then
            self.baseImages[modeId] = self:buildInternationalSpaceStationImage()
        end
    end
    if next(self.baseImages) == nil then
        local shapeMode = BASE_CONFIG.shapeMode or "international-space-station"
        if shapeMode == "the-watcher" then
            self.baseImage = self:buildWatcherBaseImage()
        elseif shapeMode == "international-space-station" then
            self.baseImage = self:buildInternationalSpaceStationImage()
        end
    else
        self.baseImage = self.baseImages[self.baseModeId]
    end
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
    x, y = self:movePointOutsideBaseSpawnExclusion(x, y, config.radius, angle)
    x, y = self:pushPointFullyOffScreen(x, y, config.radius, angle)

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

function SpaceMiner:getBaseSpawnExclusionRadius(entityRadius)
    return BASE_SHIELD_RADIUS + (entityRadius or 0) + 38
end

function SpaceMiner:movePointOutsideBaseSpawnExclusion(x, y, entityRadius, fallbackAngle)
    if not self:isStoryMode() then
        return x, y
    end

    local exclusionRadius = self:getBaseSpawnExclusionRadius(entityRadius)
    if distanceSquared(x, y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y)) > (exclusionRadius * exclusionRadius) then
        return x, y
    end

    local dx = x - (self.baseWorldX or BASE_WORLD_X)
    local dy = y - (self.baseWorldY or BASE_WORLD_Y)
    local length = magnitude(dx, dy)
    if length < 0.001 then
        local angle = fallbackAngle or (math.random() * math.pi * 2)
        dx = math.cos(angle)
        dy = math.sin(angle)
        length = 1
    end

    return (self.baseWorldX or BASE_WORLD_X) + (dx / length) * exclusionRadius,
        (self.baseWorldY or BASE_WORLD_Y) + (dy / length) * exclusionRadius
end

function SpaceMiner:spawnWaveAsteroid(entry)
    local x, y = self:getWaveSpawnPoint(entry.entryDegrees, ASTEROID_SAFE_RADIUS + 40, ASTEROID_SAFE_RADIUS + 220)
    self:spawnAsteroid(entry.asteroidStage or 0, x, y)
end

function SpaceMiner:isPointFullyOffScreen(x, y, radius)
    local drawX, drawY = worldToScreen(self.player.x, self.player.y, x, y)
    local margin = radius or 0
    return drawX <= -margin
        or drawX >= SCREEN_WIDTH + margin
        or drawY <= -margin
        or drawY >= SCREEN_HEIGHT + margin
end

function SpaceMiner:pushPointFullyOffScreen(x, y, radius, angle)
    local moveAngle = angle or self:getPointAngleDegrees(self.player.x, self.player.y, x, y)
    local radians = math.rad(moveAngle)
    local distance = math.sqrt(distanceSquared(self.player.x, self.player.y, x, y))
    local step = math.max((radius or 0) * 0.75, 48)
    local attempts = 0
    while attempts < 18 and not self:isPointFullyOffScreen(x, y, radius or 0) do
        distance = distance + step
        x = self.player.x + math.cos(radians) * distance
        y = self.player.y + math.sin(radians) * distance
        x, y = self:movePointOutsideBaseSpawnExclusion(x, y, radius or 0, moveAngle)
        attempts = attempts + 1
    end
    return x, y
end

function SpaceMiner:spawnFragments(asteroid, options)
    if self:getActiveEntityCount() >= ASTEROID_FRAGMENT_ENTITY_LIMIT then
        return
    end

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
        if self:getActiveEntityCount() >= ASTEROID_FRAGMENT_ENTITY_LIMIT then
            return
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
        return (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y)
    end
    return self.player.x, self.player.y
end

function SpaceMiner:getTargetVelocity(target)
    if normalizeTarget(target) == "base" then
        return 0, 0
    end
    return self.player.vx, self.player.vy
end

function SpaceMiner:shipCanDefendItself()
    local miscUpgrade = self:getActiveUpgrade("misc") or {}
    return self:isUpgradeOwned("misc", "auto-mining-lasers") or miscUpgrade.id == "auto-mining-lasers"
end

function SpaceMiner:grantShipSelfDefense(stageId)
    local owned = self:getOwnedUpgradeTable("misc")
    if owned ~= nil then
        owned["auto-mining-lasers"] = true
    end
    self:setActiveUpgradeId("misc", "auto-mining-lasers")
    StarryLog.info(
        "miner ship self-defense enabled stage=%s owned=%s active=%s",
        tostring(stageId),
        tostring(self:isUpgradeOwned("misc", "auto-mining-lasers")),
        tostring(self:getActiveUpgradeId("misc"))
    )
    self:saveModeState()
end

function SpaceMiner:shouldSuppressDockingComplaints()
    return BASE_CONFIG.selfDefenseSuppressesDockingComplaints == true and self:shipCanDefendItself()
end

function SpaceMiner:isEnemyNearBase()
    local radiusSq = BASE_SHIELD_ENEMY_KEEP_ALIVE_RADIUS * BASE_SHIELD_ENEMY_KEEP_ALIVE_RADIUS
    for _, enemy in ipairs(self.enemyShips) do
        if distanceSquared(enemy.x, enemy.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y)) <= radiusSq then
            return true
        end
    end
    for _, missile in ipairs(self.enemyMissiles) do
        if distanceSquared(missile.x, missile.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y)) <= radiusSq then
            return true
        end
    end
    return false
end

function SpaceMiner:isBaseShieldSuppressedByPlayer()
    if (self.baseShieldHits or 0) <= 0 then
        return false
    end
    local playerDocked = distanceSquared(self.player.x, self.player.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y)) <= (BASE_SHIELD_PLAYER_DOCK_SUPPRESS_RADIUS * BASE_SHIELD_PLAYER_DOCK_SUPPRESS_RADIUS)
    return playerDocked and not self:isEnemyNearBase()
end

function SpaceMiner:isBaseShieldActive()
    if (self.baseShieldHits or 0) <= 0 then
        return false
    end
    return not self:isBaseShieldSuppressedByPlayer()
end

function SpaceMiner:isBaseShieldBlockingDamage()
    if (self.baseShieldHits or 0) <= 0 then
        return false
    end
    return not self:isBaseShieldSuppressedByPlayer()
end

function SpaceMiner:getFilteredBaseMiningLaserQuotes()
    local quotes = BASE_CONFIG.baseMiningLaserDockedQuotes or {}
    if not self:shouldSuppressDockingComplaints() then
        return quotes
    end

    local filtered = {}
    for _, quote in ipairs(quotes) do
        if string.find(string.lower(quote), "clear the area", 1, true) == nil then
            filtered[#filtered + 1] = quote
        end
    end

    if #filtered > 0 then
        if not self.baseMiningLaserComplaintSuppressionLogged then
            StarryLog.info("miner docked complaint suppressed by ship self-defense upgrade")
            self.baseMiningLaserComplaintSuppressionLogged = true
        end
        return filtered
    end
    if not self.baseMiningLaserComplaintSuppressionLogged then
        StarryLog.info("miner docked complaint suppressed by ship self-defense upgrade")
        self.baseMiningLaserComplaintSuppressionLogged = true
    end
    return { "Scout: I got it." }
end

function SpaceMiner:noteScoutToleranceBreach(text, buttonName)
    if (self.scoutToleranceTimer or 0) > 0 then
        return
    end

    self.scoutToleranceCount = (self.scoutToleranceCount or 0) + 1
    self.scoutToleranceTimer = self.scoutToleranceWindowFrames or (30 * 10)

    local blockedButton = string.upper(tostring(buttonName or ""))
    local message
    if self.scoutToleranceCount == 1 then
        message = "Scout: Hey! Dude! The fuck! Fire at them. I pay you too much for this treatment."
    elseif self.scoutToleranceCount == 2 then
        message = "Scout: If you do that one more time, I'm gonna cry. Please stop."
    else
        message = "Scout: There.\nWeapons disabled."
        self.weaponsDisabled = true
        self.blockedWeaponButtons = self.blockedWeaponButtons or {}
        if blockedButton == "LEFT" or blockedButton == "RIGHT" then
            self.blockedWeaponButtons[blockedButton] = true
        end
        if blockedButton == "LEFT" then
            self.player.laserOn = false
            self.input.laser = false
        elseif blockedButton == "RIGHT" then
            self.player.pendingMissileTrigger = false
        end
        self.homeMenuScreen = "apology"
    end

    self:startContextCommunication("scout-tolerance", message, 150)
    StarryLog.info("miner scout tolerance breach count=%d frame=%d", self.scoutToleranceCount, self.frame)
end

function SpaceMiner:updateScoutToleranceTimer()
    if (self.scoutToleranceTimer or 0) > 0 then
        self.scoutToleranceTimer = self.scoutToleranceTimer - 1
    end
end

local function lineIntersectsCircle(x1, y1, x2, y2, circleX, circleY, circleRadius)
    return linePointDistanceSquared(circleX, circleY, x1, y1, x2, y2) <= (circleRadius * circleRadius)
end

local function lineCircleHitParameter(x1, y1, x2, y2, circleX, circleY, circleRadius)
    local abx = x2 - x1
    local aby = y2 - y1
    local abLengthSq = (abx * abx) + (aby * aby)
    if abLengthSq <= 0.0001 then
        return nil
    end
    local t = (((circleX - x1) * abx) + ((circleY - y1) * aby)) / abLengthSq
    if t < 0 or t > 1 then
        return nil
    end
    local closestX = x1 + (abx * t)
    local closestY = y1 + (aby * t)
    if distanceSquared(circleX, circleY, closestX, closestY) <= (circleRadius * circleRadius) then
        return t
    end
    return nil
end

function SpaceMiner:checkPlayerLaserShieldViolation()
    if not self:isStoryMode() or not self:isBaseShieldActive() then
        return false
    end
    if distanceSquared(self.player.x, self.player.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y)) <= (BASE_SHIELD_RADIUS * BASE_SHIELD_RADIUS) then
        return false
    end
    local angleToBase = math.deg(math.atan((self.baseWorldY or BASE_WORLD_Y) - self.player.y, (self.baseWorldX or BASE_WORLD_X) - self.player.x))
    local angleDelta = math.abs(((self.player.angle - angleToBase + 180) % 360) - 180)
    if angleDelta > 12 then
        return false
    end
    local radians = math.rad(self.player.angle)
    local endX = self.player.x + (math.cos(radians) * LASER_RANGE)
    local endY = self.player.y + (math.sin(radians) * LASER_RANGE)
    if lineIntersectsCircle(self.player.x, self.player.y, endX, endY, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y), BASE_SHIELD_RADIUS) then
        if (self.blockedWeaponButtons or {})["LEFT"] ~= true then
            self:noteScoutToleranceBreach("laser", "LEFT")
        end
        return true
    end
    return false
end

function SpaceMiner:checkPlayerMissileShieldViolation(missile)
    if missile == nil or not self:isStoryMode() or not self:isBaseShieldActive() then
        return false
    end
    if distanceSquared(self.player.x, self.player.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y)) <= (BASE_SHIELD_RADIUS * BASE_SHIELD_RADIUS) then
        return false
    end
    local missileAngle = math.deg(math.atan(missile.vy, missile.vx))
    local angleToBase = math.deg(math.atan((self.baseWorldY or BASE_WORLD_Y) - missile.y, (self.baseWorldX or BASE_WORLD_X) - missile.x))
    local angleDelta = math.abs(((missileAngle - angleToBase + 180) % 360) - 180)
    if angleDelta > 18 then
        return false
    end
    local radius = BASE_SHIELD_RADIUS + 2
    local nextX = missile.x + missile.vx
    local nextY = missile.y + missile.vy
    if distanceSquared(nextX, nextY, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y)) <= (radius * radius) then
        if (self.blockedWeaponButtons or {})["RIGHT"] ~= true then
            self:noteScoutToleranceBreach("missile", "RIGHT")
        end
        self:removePlayerMissile(missile)
        return true
    end
    return false
end

function SpaceMiner:damageBase(reason)
    if self.baseShieldFlashFrames > 0 then
        return
    end
    local damage = BASE_SHIELD_DAMAGE
    if reason == "asteroid" then
        damage = BASE_SHIELD_ASTEROID_DAMAGE
    elseif reason == "enemy-missile" or reason == "enemy-laser" then
        damage = BASE_SHIELD_ENEMY_WEAPON_DAMAGE
    elseif reason == "enemy-ship" then
        damage = BASE_SHIELD_ENEMY_SHIP_DAMAGE
    end
    self.baseShieldHits = math.max(0, (self.baseShieldHits or BASE_SHIELD_MAX) - damage)
    self.baseShieldFlashFrames = SHIELD_FLASH_FRAMES
    if reason ~= "asteroid" then
        self.baseUnderAttackFrames = 45
        self.baseUnderAttackStartFrame = self.frame
    end
    self.baseFramesSinceDamage = 0
    self.baseShieldRechargeFrames = 0
    self:addExplosion((self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y), 18, 10)
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
        self.baseShieldHits = math.min(BASE_SHIELD_MAX, self.baseShieldHits + self:getBaseShieldRechargeAmount())
        self.baseShieldRechargeFrames = 0
    end
end

function SpaceMiner:updateBaseTimeline()
    while self.baseTimelineIndex <= #BASE_TIMELINE do
        local entry = BASE_TIMELINE[self.baseTimelineIndex]
        if entry.frame > self.frame then
            break
        end
        if tostring(entry.action or ""):lower() == "ship mode" and entry.mode ~= nil then
            self:setBaseMode(entry.mode, true)
            StarryLog.info("miner base ship mode changed mode=%s frame=%d", tostring(entry.mode), self.frame)
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
        missileCooldown = STRIKER_MISSILE_COOLDOWN,
        laserRange = 152,
        laserCooldown = 52,
        laserDamage = 1,
        orbitSpeed = 0.045,
        playerAttackRange = 520,
        baseAttackRange = 220
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
    elseif enemyType == "laserEnemy" then
        defaults.health = 8
        defaults.acceleration = 0.058
        defaults.maxSpeed = 3.1
        defaults.size = 8
        defaults.laserRange = 152
        defaults.laserCooldown = 52
        defaults.laserDamage = 1
        defaults.orbitSpeed = 0.045
    end
    return {
        health = configured.health or configured.hp or defaults.health,
        acceleration = configured.acceleration or defaults.acceleration,
        maxSpeed = configured.maxSpeed or defaults.maxSpeed,
        size = configured.size or defaults.size,
        avoidAsteroids = configured.avoidAsteroids ~= false,
        missileCooldown = configured.missileCooldown or defaults.missileCooldown,
        laserRange = configured.laserRange or defaults.laserRange,
        laserCooldown = configured.laserCooldown or defaults.laserCooldown,
        laserDamage = configured.laserDamage or defaults.laserDamage,
        orbitSpeed = configured.orbitSpeed or defaults.orbitSpeed,
        playerAttackRange = configured.playerAttackRange or defaults.playerAttackRange,
        baseAttackRange = configured.baseAttackRange or defaults.baseAttackRange
    }
end

function SpaceMiner:spawnEnemy(enemyType, entryDegrees, target)
    self.enemySerial = self.enemySerial + 1
    local minDistance = 340
    local maxDistance = 460
    if enemyType == "escaper" then
        minDistance = ESCAPER_LINGER_TARGET_RADIUS
        maxDistance = ESCAPER_LINGER_TARGET_RADIUS + 34
    elseif enemyType == "laserEnemy" then
        minDistance = 300
        maxDistance = 500
    end
    local x, y, angle = self:getWaveSpawnPoint(entryDegrees, minDistance, maxDistance)
    local stats = self:getEnemyStats(enemyType)
    x, y = self:movePointOutsideBaseSpawnExclusion(x, y, stats.size, angle)

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
        missileCooldown = stats.missileCooldown + math.random(0, 40),
        laserRange = stats.laserRange,
        laserCooldown = stats.laserCooldown + math.random(0, 18),
        laserCooldownReset = stats.laserCooldown,
        laserDamage = stats.laserDamage,
        playerAttackRange = stats.playerAttackRange,
        baseAttackRange = stats.baseAttackRange,
        orbitSpeed = stats.orbitSpeed,
        orbitDirection = math.random(0, 1) == 0 and -1 or 1
    }
end

function SpaceMiner:beginStage(index)
    local stageSchedule = self:getModeStageSchedule()
    local stageCount = #stageSchedule
    if stageCount <= 0 then
        self.stageIndex = 1
        self.stageRuntime = {
            alertStarted = false,
            alertStartFrame = nil,
            waveStartFrame = nil,
            spawnedEntries = {},
            communicationBlockIndex = 1,
            objectiveStartMinedChunks = self.minedChunks or 0,
            objectiveStartDestroyedEnemies = self.destroyedEnemies or 0,
            objectiveComplete = false
        }
        self.stageLabel = "Open Mining"
        return
    end
    self.stageIndex = clamp(index, 1, stageCount)
    self.stageFrame = 0
    local stage = stageSchedule[self.stageIndex]
    self.stageLabel = stage.label
    self.stageRuntime = {
        alertStarted = false,
        alertStartFrame = nil,
        waveStartFrame = stage.waveStartFrame,
        spawnedEntries = {},
        communicationBlockIndex = 1,
        objectiveStartMinedChunks = self.minedChunks or 0,
        objectiveStartDestroyedEnemies = self.destroyedEnemies or 0,
        objectiveComplete = false
    }
    StarryLog.info("miner stage begin %s", stage.id)
    if stage.enableShipAutoDefense == true then
        self:grantShipSelfDefense(stage.id)
    end
end

function SpaceMiner:startSupernovaFlash()
    self.supernovaFlashFrames = 24
end

function SpaceMiner:advanceStage()
    local stageSchedule = self:getModeStageSchedule()
    if self.stageIndex < #stageSchedule then
        self:beginStage(self.stageIndex + 1)
        self:saveModeState()
    else
        self:beginStage(1)
        self:startSupernovaFlash()
        self:saveModeState()
    end
end

function SpaceMiner:triggerNextWaveEvent()
    local stageSchedule = self:getModeStageSchedule()
    if self.preview or #stageSchedule == 0 then
        return
    end
    local stage = self:getCurrentStage()
    if stage ~= nil and (stage.kind == "wave" or stage.kind == "objective") then
        local runtime = self.stageRuntime
        if runtime ~= nil then
            runtime.alertStarted = true
            runtime.alertStartFrame = self.frame - ALERT_TOTAL_FRAMES
            runtime.waveStartFrame = self.frame
            self.stageFrame = math.max(self.stageFrame, stage.trigger and (stage.trigger.delayFrames or 0) or 0)
        end
        return
    end
    for offset = 1, #stageSchedule do
        local index = ((self.stageIndex - 1 + offset) % #stageSchedule) + 1
        if stageSchedule[index].kind == "wave" or stageSchedule[index].kind == "objective" then
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
            self:saveModeState()
            return
        end
    end
end

function SpaceMiner:triggerSpecificStage(index)
    local stageSchedule = self:getModeStageSchedule()
    if self.preview or #stageSchedule == 0 then
        return
    end

    local stageIndex = clamp(math.floor(tonumber(index) or 0), 1, #stageSchedule)
    self:beginStage(stageIndex)
    local stage = stageSchedule[stageIndex]
    local runtime = self.stageRuntime
    if stage ~= nil and runtime ~= nil and (stage.kind == "wave" or stage.kind == "objective") then
        runtime.alertStarted = true
        runtime.alertStartFrame = self.frame - ALERT_TOTAL_FRAMES
        runtime.waveStartFrame = self.frame
    end
    self:saveModeState()
end

function SpaceMiner:getCurrentStage()
    local stageSchedule = self:getModeStageSchedule()
    return stageSchedule[self.stageIndex]
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
    if self:isOreMinerMode() then
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
        local nextStage = self:getModeStageSchedule()[self.stageIndex + 1]
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
        local message = {
            id = "base-under-attack",
            startFrame = self.baseUnderAttackStartFrame or self.frame,
            endFrame = self.frame + self.baseUnderAttackFrames,
            text = SPACE_MINER_CONFIG.baseUnderAttackMessage or "Base under attack",
            x = 8,
            y = 8,
            width = COMMUNICATION_WIDTH,
            urgent = true
        }
        if not self:isCommunicationDismissed(message) then
            return message
        end
    end

    local blockMessage = self:getActiveCommunicationBlock()
    if blockMessage ~= nil then
        return blockMessage
    end

    for _, message in ipairs(self:getModeCommunicationSchedule()) do
        if self.frame >= message.startFrame and self.frame < message.endFrame then
            if not self:isCommunicationDismissed(message) then
                return message
            end
        end
    end
    local stageMessage = self:getActiveStageCommunication()
    if stageMessage ~= nil then
        if not self:isCommunicationDismissed(stageMessage) then
            return stageMessage
        end
    end
    return nil
end

function SpaceMiner:recordVisibleCommunication(message)
    if message == nil or message.text == nil or message.text == "" then
        return
    end
    self.communicationSeenKeys = self.communicationSeenKeys or {}
    local key = self:getCommunicationDismissKey(message)
    if key == nil then
        key = string.format("%s|%d|%s", tostring(message.id or "message"), tonumber(message.startFrame) or self.frame or 0, tostring(message.text or ""))
    end
    if self.communicationSeenKeys[key] == true then
        return
    end
    self:rememberCommunicationSeenKey(key)
    self:recordCommunicationHistory(message.id, message.text, message.source or "scout", message.startFrame or self.frame)
end

function SpaceMiner:getCommunicationDismissKey(message)
    if message == nil then
        return nil
    end
    return string.format("%s|%d|%s", tostring(message.id or "message"), tonumber(message.startFrame) or 0, tostring(message.text or ""))
end

function SpaceMiner:isCommunicationDismissed(message)
    local key = self:getCommunicationDismissKey(message)
    if key == nil then
        return false
    end
    local untilFrame = (self.dismissedCommunications or {})[key]
    if untilFrame == nil then
        return false
    end
    if self.frame >= untilFrame then
        self.dismissedCommunications[key] = nil
        return false
    end
    return true
end

function SpaceMiner:dismissActiveCommunication()
    local message = self:getActiveCommunication()
    if message == nil or message.blocking then
        return false
    end
    if self.contextCommunication == message then
        self.contextCommunication = nil
    elseif message.id == "base-under-attack" then
        self.baseUnderAttackFrames = 0
        self.baseUnderAttackStartFrame = nil
    else
        self.dismissedCommunications = self.dismissedCommunications or {}
        local key = self:getCommunicationDismissKey(message)
        if key ~= nil then
            self.dismissedCommunications[key] = message.endFrame or self.frame + 1
        end
    end
    self:playUiClick()
    return true
end

function SpaceMiner:hasScheduledOrUrgentCommunication()
    if (self.baseUnderAttackFrames or 0) > 0 then
        return true
    end
    if self:getActiveCommunicationBlock() ~= nil then
        return true
    end
    for _, message in ipairs(self:getModeCommunicationSchedule()) do
        if self.frame >= message.startFrame and self.frame < message.endFrame then
            return true
        end
    end
    if self:getActiveStageCommunication() ~= nil then
        return true
    end
    return false
end

function SpaceMiner:getActiveCommunicationBlock()
    if self.menuOpen and self.menuType == "home" then
        return nil
    end
    local stage = self:getCurrentStage()
    local runtime = self.stageRuntime
    if stage == nil or runtime == nil or stage.kind ~= "communication-block" then
        return nil
    end
    local entries = stage.communicationBlockEntries or {}
    local index = clamp(math.floor(runtime.communicationBlockIndex or 1), 1, math.max(1, #entries))
    local entry = entries[index]
    if entry == nil then
        return nil
    end
    return {
        id = entry.id,
        startFrame = self.frame - 1,
        endFrame = self.frame + 30,
        text = entry.text,
        x = entry.x or 8,
        y = entry.y or 8,
        width = entry.width or COMMUNICATION_WIDTH,
        requiredButton = entry.requiredButton or "A",
        disableButtons = entry.disableButtons or {},
        blocking = true
    }
end

function SpaceMiner:acknowledgeCommunicationBlock(buttonName)
    local stage = self:getCurrentStage()
    local runtime = self.stageRuntime
    if stage == nil or runtime == nil or stage.kind ~= "communication-block" then
        return false
    end
    local entries = stage.communicationBlockEntries or {}
    local index = clamp(math.floor(runtime.communicationBlockIndex or 1), 1, math.max(1, #entries))
    local entry = entries[index]
    if entry == nil then
        self:advanceStage()
        return true
    end
    local requiredButton = string.upper(tostring(entry.requiredButton or "A"))
    if string.upper(tostring(buttonName or "")) ~= requiredButton then
        return false
    end
    runtime.communicationBlockIndex = index + 1
    if runtime.communicationBlockIndex > #entries then
        self:advanceStage()
    end
    return true
end

function SpaceMiner:getActiveStageCommunication()
    if self.menuOpen and self.menuType == "home" then
        return nil
    end
    local stage = self:getCurrentStage()
    if stage == nil then
        return nil
    end
    for _, message in ipairs(stage.communications or {}) do
        local startFrame
        if message.timestampFrames ~= nil then
            startFrame = message.timestampFrames
        else
            startFrame = self.frame - self.stageFrame + (message.offsetFrames or 0)
        end
        local endFrame = startFrame + (message.durationFrames or 1)
        if self.frame >= startFrame and self.frame < endFrame then
            return {
                id = message.id,
                startFrame = startFrame,
                endFrame = endFrame,
                text = message.text,
                x = message.x or 8,
                y = message.y or 8,
                width = message.width or COMMUNICATION_WIDTH
            }
        end
    end
    return nil
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
    self:recordCommunicationHistory(id, text, "context", self.frame)
end

function SpaceMiner:updateBaseCollisionCommunication()
    if self.preview or self.gameOver or (not self:isStoryMode() and not self:isOreMinerMode()) then
        return
    end
    if (self.baseCollisionCooldownFrames or 0) > 0 then
        self.baseCollisionCooldownFrames = self.baseCollisionCooldownFrames - 1
    end
    local collisionRadius = PLAYER_RADIUS + 22
    local colliding = distanceSquared(self.player.x, self.player.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y)) <= (collisionRadius * collisionRadius)
    if not colliding then
        if self.wasCollidingHomeBase then
            StarryLog.info("miner base collision left frame=%d", self.frame)
        end
        self.wasCollidingHomeBase = false
        return
    end
    if self.wasCollidingHomeBase or (self.baseCollisionCooldownFrames or 0) > 0 then
        return
    end
    self.wasCollidingHomeBase = true
    StarryLog.info("miner base collision entered frame=%d distanceSq=%d", self.frame, distanceSquared(self.player.x, self.player.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y)))
    if self.contextCommunication ~= nil or self:hasScheduledOrUrgentCommunication() then
        return
    end
    local quotes = BASE_CONFIG.baseCollisionContext or BASE_CONFIG["base-collision-context"] or {}
    if #quotes <= 0 then
        return
    end
    local quoteIndex = math.random(1, #quotes)
    local quote = quotes[quoteIndex]
    self:startContextCommunication("base-collision-context", quote, 105)
    StarryLog.info("miner base collision communication triggered frame=%d quote=%s", self.frame, tostring(quoteIndex))
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

function SpaceMiner:gridToWorld(gridX, gridY)
    return BASE_WORLD_X + ((tonumber(gridX) or 0) * WORLD_UNITS_PER_GRID_KM),
        BASE_WORLD_Y + ((tonumber(gridY) or 0) * WORLD_UNITS_PER_GRID_KM)
end

function SpaceMiner:parseGridDestination(destination)
    if type(destination) == "table" then
        return tonumber(destination.x or destination[1]) or 0, tonumber(destination.y or destination[2]) or 0
    end
    local xText, yText = tostring(destination or "0,0"):match("^%s*([^,]+)%s*,%s*([^,]+)%s*$")
    return tonumber(xText) or 0, tonumber(yText) or 0
end

function SpaceMiner:getMoveSpeed(speed)
    local mode = string.lower(tostring(speed or "jump"))
    if mode == "slow" then
        return PLAYER_MAX_SPEED
    elseif mode == "medium" then
        return PLAYER_MAX_SPEED * 2
    elseif mode == "fast" then
        return PLAYER_MAX_SPEED * 4
    end
    return nil
end

function SpaceMiner:getMovableEntityPosition(entity)
    local target = string.lower(tostring(entity or "home-base"))
    if target == "player" then
        return self.player.x, self.player.y
    end
    if target == "home-base" or target == "home base" or target == "base" then
        return self.baseWorldX or BASE_WORLD_X, self.baseWorldY or BASE_WORLD_Y
    end
    local poi = self.pointsOfInterest and self.pointsOfInterest[target]
    if poi ~= nil then
        return poi.x, poi.y
    end
    return nil, nil
end

function SpaceMiner:setMovableEntityPosition(entity, x, y)
    local target = string.lower(tostring(entity or "home-base"))
    if target == "player" then
        self.player.x = x
        self.player.y = y
        self.player.vx = 0
        self.player.vy = 0
        return true
    end
    if target == "home-base" or target == "home base" or target == "base" then
        self.baseWorldX = x
        self.baseWorldY = y
        return true
    end
    self.pointsOfInterest = self.pointsOfInterest or {}
    self.pointsOfInterest[target] = self.pointsOfInterest[target] or {}
    self.pointsOfInterest[target].x = x
    self.pointsOfInterest[target].y = y
    return true
end

function SpaceMiner:startMoveEntityAction(action)
    local gridX, gridY = self:parseGridDestination(action.destination)
    local targetX, targetY = self:gridToWorld(gridX, gridY)
    local entity = action.entity or "home-base"
    local speed = self:getMoveSpeed(action.speed)
    if speed == nil then
        self:setMovableEntityPosition(entity, targetX, targetY)
        StarryLog.info("miner move entity jumped entity=%s destination=%.1f,%.1f grid=%.1f,%.1f", tostring(entity), targetX, targetY, gridX, gridY)
        return
    end
    self.entityMoves = self.entityMoves or {}
    self.entityMoves[tostring(entity)] = {
        entity = entity,
        targetX = targetX,
        targetY = targetY,
        speed = speed
    }
    StarryLog.info("miner move entity started entity=%s speed=%s destination=%.1f,%.1f grid=%.1f,%.1f", tostring(entity), tostring(action.speed), targetX, targetY, gridX, gridY)
end

function SpaceMiner:updateEntityMoves()
    self.entityMoves = self.entityMoves or {}
    for key, move in pairs(self.entityMoves) do
        local x, y = self:getMovableEntityPosition(move.entity)
        if x == nil then
            self.entityMoves[key] = nil
        else
            local dx = move.targetX - x
            local dy = move.targetY - y
            local distance = math.sqrt((dx * dx) + (dy * dy))
            if distance <= (move.speed or PLAYER_MAX_SPEED) then
                self:setMovableEntityPosition(move.entity, move.targetX, move.targetY)
                self.entityMoves[key] = nil
            else
                local ux, uy = dx / distance, dy / distance
                self:setMovableEntityPosition(move.entity, x + (ux * move.speed), y + (uy * move.speed))
            end
        end
    end
end

function SpaceMiner:updateStageActions(stage)
    local runtime = self.stageRuntime
    if runtime == nil then
        return
    end
    runtime.completedActions = runtime.completedActions or {}
    for _, action in ipairs(stage.actions or {}) do
        if runtime.completedActions[action.id] ~= true then
            local dueFrame = action.timestampFrames or (action.offsetFrames or 0)
            if self.stageFrame >= dueFrame then
                if tostring(action.action or ""):lower() == "ship mode" and action.mode ~= nil then
                    self:setBaseMode(action.mode, true)
                    StarryLog.info("miner stage ship mode action stage=%s mode=%s frame=%d", tostring(stage.id), tostring(action.mode), self.frame)
                elseif tostring(action.action or ""):lower() == "move entity" then
                    self:startMoveEntityAction(action)
                end
                runtime.completedActions[action.id] = true
            end
        end
    end
end

function SpaceMiner:updateStage()
    if self.preview or self.menuOpen then
        return
    end

    local stage = self:getCurrentStage()
    if stage == nil then
        return
    end

    self.stageFrame = self.stageFrame + 1
    self:updateStageActions(stage)
    if stage.kind == "mining" then
        if self.stageFrame >= stage.durationFrames then
            self:advanceStage()
        end
        return
    elseif stage.kind == "communication-block" then
        local runtime = self.stageRuntime
        local entries = stage.communicationBlockEntries or {}
        if runtime == nil or #entries == 0 then
            self:advanceStage()
        end
        return
    end

    local runtime = self.stageRuntime
    if runtime == nil then
        return
    end

    local objective = stage.objective
    local objectiveComplete = false
    local trigger = stage.trigger or {}
    if objective ~= nil then
        local minedOre = (self.minedChunks or 0) - (runtime.objectiveStartMinedChunks or 0)
        local destroyedEnemies = (self.destroyedEnemies or 0) - (runtime.objectiveStartDestroyedEnemies or 0)
        objectiveComplete = (objective.ore <= 0 or minedOre >= objective.ore)
            and (objective.enemies <= 0 or destroyedEnemies >= objective.enemies)
        if objectiveComplete then
            runtime.objectiveComplete = true
        end
    end

    if not runtime.alertStarted then
        if trigger.type == "time" then
            if self.frame >= (stage.alertStartFrame or 0) then
                runtime.alertStarted = true
                runtime.alertStartFrame = stage.alertStartFrame or self.frame
                runtime.waveStartFrame = stage.waveStartFrame or self.frame
            end
        elseif self.stageFrame >= (trigger.delayFrames or 0) then
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
            if trigger.type == "time" then
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

    if objectiveComplete then
        if not stage.continueAfterCompleted or (self:stageEntriesFullySpawned(stage) and #self.enemyShips == 0 and #self.enemyMissiles == 0) then
            self:advanceStage()
        end
        return
    end

    if (stage.kind == "wave" or stage.kind == "objective")
        and self:stageEntriesFullySpawned(stage)
        and #self.enemyShips == 0
        and #self.enemyMissiles == 0 then
        self:advanceStage()
    end
end

function SpaceMiner:applyCrank(change)
    local systemKeyboardVisible = pd.keyboard.isVisible ~= nil and pd.keyboard.isVisible()
    if self.storyNameKeyboardPending and not self.storyNameKeyboardShown and systemKeyboardVisible then
        return
    end
    if self.storySlotSelectorOpen then
        local input = change or 0
        if math.abs(input) <= 0.001 then
            return
        end
        local items = self:getStorySlotSelectorItems()
        if #items <= 0 then
            return
        end
        self.storySlotSelectorCrankAccumulator = (self.storySlotSelectorCrankAccumulator or 0) + input
        while self.storySlotSelectorCrankAccumulator >= MENU_CRANK_STEP do
            self.storySlotSelectorIndex = (clamp(self.storySlotSelectorIndex or 1, 1, #items) % #items) + 1
            self.storySlotSelectorCrankAccumulator = self.storySlotSelectorCrankAccumulator - MENU_CRANK_STEP
        end
        while self.storySlotSelectorCrankAccumulator <= -MENU_CRANK_STEP do
            self.storySlotSelectorIndex = ((clamp(self.storySlotSelectorIndex or 1, 1, #items) - 2) % #items) + 1
            self.storySlotSelectorCrankAccumulator = self.storySlotSelectorCrankAccumulator + MENU_CRANK_STEP
        end
        return
    end
    if self.nameEntryOpen then
        local input = change or 0
        if math.abs(input) <= 0.001 then
            return
        end
        if self.storyNameKeyboardShown then
            self.storyNameKeyboardCrankAccumulator = (self.storyNameKeyboardCrankAccumulator or 0) + input
            while self.storyNameKeyboardCrankAccumulator >= MENU_CRANK_STEP do
                self:advanceStoryNameKeyboardCursorStep(1)
                self.storyNameKeyboardCrankAccumulator = self.storyNameKeyboardCrankAccumulator - MENU_CRANK_STEP
            end
            while self.storyNameKeyboardCrankAccumulator <= -MENU_CRANK_STEP do
                self:advanceStoryNameKeyboardCursorStep(-1)
                self.storyNameKeyboardCrankAccumulator = self.storyNameKeyboardCrankAccumulator + MENU_CRANK_STEP
            end
            return
        end
        self.storyNameEntryCrankAccumulator = (self.storyNameEntryCrankAccumulator or 0) + input
        while self.storyNameEntryCrankAccumulator >= MENU_CRANK_STEP do
            self.storyNameEntryIndex = (clamp(self.storyNameEntryIndex or 1, 1, 2) % 2) + 1
            self.storyNameEntryCrankAccumulator = self.storyNameEntryCrankAccumulator - MENU_CRANK_STEP
        end
        while self.storyNameEntryCrankAccumulator <= -MENU_CRANK_STEP do
            self.storyNameEntryIndex = ((clamp(self.storyNameEntryIndex or 1, 1, 2) - 2) % 2) + 1
            self.storyNameEntryCrankAccumulator = self.storyNameEntryCrankAccumulator + MENU_CRANK_STEP
        end
        return
    end
    if self.menuOpen then
        local input = change or 0
        if math.abs(input) <= 0.001 then
            return
        end
        if self.menuType == "home" and self.homeMenuScreen == "communications" then
            self.communicationHistoryCrankAccumulator = (self.communicationHistoryCrankAccumulator or 0) + input
            while self.communicationHistoryCrankAccumulator >= MENU_CRANK_STEP do
                self:moveCommunicationHistoryCursor(1)
                self.communicationHistoryCrankAccumulator = self.communicationHistoryCrankAccumulator - MENU_CRANK_STEP
            end
            while self.communicationHistoryCrankAccumulator <= -MENU_CRANK_STEP do
                self:moveCommunicationHistoryCursor(-1)
                self.communicationHistoryCrankAccumulator = self.communicationHistoryCrankAccumulator + MENU_CRANK_STEP
            end
            return
        end
        self:startRotaryMenuSpin(input > 0 and 1 or -1, math.min(1.1, math.abs(input) / MENU_CRANK_STEP) * 0.5)
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
    local systemKeyboardVisible = pd.keyboard.isVisible ~= nil and pd.keyboard.isVisible()
    if self.storyNameKeyboardPending and not self.storyNameKeyboardShown and systemKeyboardVisible then
        self.input.thrust = 0
        self.input.reverse = 0
        self.input.laser = false
        self.player.laserOn = false
        self.player.pendingMissileTrigger = false
        return
    end
    if self.nameEntryOpen then
        self.input.thrust = 0
        self.input.reverse = 0
        self.input.laser = false
        self.player.laserOn = false
        self.player.pendingMissileTrigger = false
        if self.storyNameKeyboardShown then
            self:handleStoryNameKeyboardDpadInput(upPressed, downPressed, leftPressed, rightJustPressed)
            if primaryJustPressed then
                self:applyStoryNameKeyboardAction()
            end
            return
        end
        if upPressed then
            self.storyNameEntryIndex = 1
            self.storyNameEntryCrankAccumulator = 0
        elseif downPressed then
            self.storyNameEntryIndex = 2
            self.storyNameEntryCrankAccumulator = 0
        end
        if primaryJustPressed and not self.storyNameKeyboardShown then
            self:handleStoryNameEntryAction()
        end
        return
    end
    if self.storySlotSelectorOpen then
        self.input.thrust = 0
        self.input.reverse = 0
        self.input.laser = false
        self.player.laserOn = false
        self.player.pendingMissileTrigger = false
        self:handleStorySlotSelector(upPressed, downPressed, primaryJustPressed)
        return
    end

    local reopenMenuWhileAutopilot = self.homeBaseAutopilot ~= nil and primaryJustPressed == true
    if reopenMenuWhileAutopilot then
        self:openShipMenu()
        self.menuInputIgnoreFrames = 1
        self.homeMenuAutoCloseFrames = nil
        primaryJustPressed = false
    end

    local activeCommunicationBlock = self:getActiveCommunicationBlock()
    if activeCommunicationBlock ~= nil then
        local disabledButtons = activeCommunicationBlock.disableButtons or {}
        if isButtonDisabled(disabledButtons, "UP") then
            upPressed = false
        end
        if isButtonDisabled(disabledButtons, "DOWN") then
            downPressed = false
        end
        if isButtonDisabled(disabledButtons, "LEFT") then
            leftPressed = false
        end
        if isButtonDisabled(disabledButtons, "RIGHT") then
            rightJustPressed = false
        end
        if isButtonDisabled(disabledButtons, "A") then
            primaryJustPressed = false
        end
    end

    if primaryJustPressed and self.communicationBlockAckFrame ~= self.frame and self:acknowledgeCommunicationBlock("A") then
        self.communicationBlockAckFrame = self.frame
        primaryJustPressed = false
    end
    if upPressed or downPressed or leftPressed or rightJustPressed or primaryJustPressed then
        self:noteInteraction()
    end

    if self.homeBaseAutopilot ~= nil then
        self.input.thrust = 0
        self.input.reverse = 0
        self.input.laser = false
        self.player.laserOn = false
        self.player.pendingMissileTrigger = false
        return
    end

    self.input.thrust = (upPressed and not self.gameOver) and 1 or 0
    self.input.reverse = (downPressed and not self.gameOver) and 1 or 0
    self.input.laser = leftPressed == true and not self.gameOver and not ((self.blockedWeaponButtons or {})["LEFT"] == true)
    self.player.laserOn = self.input.laser
    if not self.gameOver then
        if rightJustPressed then
            if (self.blockedWeaponButtons or {})["RIGHT"] == true then
                self.player.pendingMissileTrigger = false
            elseif self.rightButtonMode == "turbo-boost" then
                self.rightTurboBoostFrames = 30 * 5
                self.player.pendingMissileTrigger = false
                StarryLog.info("miner turbo boost triggered frames=%d", self.rightTurboBoostFrames)
            else
                self.player.pendingMissileTrigger = true
            end
        elseif self.rightButtonMode ~= "turbo-boost" and (self:getActiveUpgrade("missile") or {}).autoLaunch and pd.buttonIsPressed(pd.kButtonRight) and (self.blockedWeaponButtons or {})["RIGHT"] ~= true then
            self.player.pendingMissileTrigger = true
        end
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
    local boostMultiplier = (self.rightTurboBoostFrames or 0) > 0 and 10 or 1
    local velocityAngle = velocityToScreenDegrees(self.player.vx, self.player.vy)
    if self.input.thrust > 0 then
        local accel = PLAYER_THRUST * thrustMultiplier * boostMultiplier
        if velocityAngle ~= nil and math.abs(shortestAngleDelta(velocityAngle, self.player.angle)) >= 179 then
            accel = accel * 1.5
        end
        applyAcceleration(self.player, math.cos(radians) * accel, math.sin(radians) * accel, PLAYER_MAX_SPEED)
    end
    if self.input.reverse > 0 then
        local accel = PLAYER_REVERSE_THRUST * thrustMultiplier * boostMultiplier
        local reverseAngle = normalizeAngle(self.player.angle + 180)
        if velocityAngle ~= nil and math.abs(shortestAngleDelta(velocityAngle, reverseAngle)) >= 179 then
            accel = accel * 1.5
        end
        applyAcceleration(self.player, -math.cos(radians) * accel, -math.sin(radians) * accel, PLAYER_MAX_SPEED)
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
    if self.player.pendingMissileTrigger ~= true or (self.blockedWeaponButtons or {})["RIGHT"] == true then
        self.player.pendingMissileTrigger = false
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
            self:playMissileSound()
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
        self:playMissileSound()
        self.player.pendingMissileTrigger = false
        return
    end

    self:spawnPlayerMissile(upgrade)
    self:playMissileSound()
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
        blastCollector = upgrade and upgrade.blastCollector == true,
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

    if options.lootPackage == true then
        self:spawnLootPackageFromAsteroid(asteroid)
    elseif not options.skipRewards and not self:isOreMinerMode() then
        self.score = self.score + minedScore
    end
    if isOreChunk and not options.skipRewards and options.lootPackage ~= true then
        self:addCargoFromAsteroid(asteroid)
    end
    self:addExplosion(asteroid.x, asteroid.y, asteroid.radius + 4, 9)
    self:playAsteroidBreakSound(asteroid.stage)
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
    self:spawnLootPackage(enemy.x, enemy.y, {
        kind = "cash",
        cash = 25,
        label = "$25"
    })
    self:addExplosion(enemy.x, enemy.y, enemy.size + 6, 10)
    self:playExplosionSound()
    table.remove(self.enemyShips, index)
end

function SpaceMiner:spawnLootPackageFromAsteroid(asteroid)
    if asteroid == nil then
        return
    end
    local material = asteroid.material or ASTEROID_MATERIALS[1]
    local units = 2 ^ math.max(0, 3 - (asteroid.stage or 3))
    local unitValue = math.max(0, math.floor(((material.cashPerTiny or 1) * ORE_SALE_PRICE_MULTIPLIER) + 0.5))
    self:spawnLootPackage(asteroid.x, asteroid.y, {
        kind = "ore",
        cargoUnits = units,
        cargoUnitValue = unitValue,
        label = material.label or "Ore"
    })
end

function SpaceMiner:spawnLootPackage(x, y, options)
    options = options or {}
    self.lootPackages = self.lootPackages or {}
    self.lootPackages[#self.lootPackages + 1] = {
        x = x,
        y = y,
        vx = (math.random() - 0.5) * 0.18,
        vy = (math.random() - 0.5) * 0.18,
        kind = options.kind or "ore",
        cash = options.cash or 0,
        cargoUnits = options.cargoUnits or 0,
        cargoUnitValue = options.cargoUnitValue or 0,
        label = options.label,
        life = 30 * 45
    }
end

function SpaceMiner:collectLootPackage(package)
    if package.kind == "cash" then
        self.cash = (self.cash or 0) + (package.cash or 0)
        return true
    end
    local capacity = math.floor((self.cargoCapacity or CARGO_INITIAL_CAPACITY) + 0.0001)
    local available = math.max(0, capacity - (self.cargoOre or 0))
    if available <= 0 then
        return false
    end
    local loaded = math.min(available, package.cargoUnits or 0)
    if loaded <= 0 then
        return true
    end
    for _ = 1, loaded do
        self.cargoLoads[#self.cargoLoads + 1] = package.cargoUnitValue or 0
    end
    self.cargoOre = (self.cargoOre or 0) + loaded
    self.cargoValue = (self.cargoValue or 0) + (loaded * (package.cargoUnitValue or 0))
    self.minedChunks = (self.minedChunks or 0) + loaded
    self.cargoCapacityTarget = self:getCargoCapacityTarget()
    package.cargoUnits = (package.cargoUnits or 0) - loaded
    return (package.cargoUnits or 0) <= 0
end

function SpaceMiner:addLaserBeam(collection, sourceX, sourceY, targetX, targetY, life, beamIndex)
    collection[#collection + 1] = {
        sourceX = sourceX,
        sourceY = sourceY,
        targetX = targetX,
        targetY = targetY,
        life = life or 6,
        maxLife = life or 6,
        beamIndex = beamIndex or 1
    }
end

function SpaceMiner:removeEnemyMissile(index, explosionRadius, explosionLife)
    local missile = self.enemyMissiles[index]
    if missile == nil then
        return false
    end
    self:addExplosion(missile.x, missile.y, explosionRadius or 8, explosionLife or 7)
    table.remove(self.enemyMissiles, index)
    return true
end

function SpaceMiner:interceptEnemyMissilesAtPoint(x, y, radius)
    local intercepted = false
    local radiusSq = radius * radius
    for index = #self.enemyMissiles, 1, -1 do
        local missile = self.enemyMissiles[index]
        local missileRadius = missile.radius or 4
        local hitRadius = radius + missileRadius
        if distanceSquared(x, y, missile.x, missile.y) <= (hitRadius * hitRadius) and radiusSq > 0 then
            self:removeEnemyMissile(index, 8, 7)
            intercepted = true
        end
    end
    return intercepted
end

function SpaceMiner:interceptEnemyMissilesAlongLaser(x1, y1, x2, y2)
    local intercepted = false
    for index = #self.enemyMissiles, 1, -1 do
        local missile = self.enemyMissiles[index]
        local hitRadius = (missile.radius or 4) + LASER_WIDTH
        if linePointDistanceSquared(missile.x, missile.y, x1, y1, x2, y2) <= (hitRadius * hitRadius) then
            self:removeEnemyMissile(index, 7, 6)
            intercepted = true
        end
    end
    return intercepted
end

function SpaceMiner:updateLaserBeams(collection)
    for index = #collection, 1, -1 do
        collection[index].life = collection[index].life - 1
        if collection[index].life <= 0 then
            table.remove(collection, index)
        end
    end
end

function SpaceMiner:findNearestAsteroidIndex(sourceX, sourceY, range)
    local nearestIndex = nil
    local nearestDistanceSq = range * range
    for index, asteroid in ipairs(self.asteroids) do
        local distanceSq = distanceSquared(sourceX, sourceY, asteroid.x, asteroid.y)
        if distanceSq <= nearestDistanceSq then
            nearestIndex = index
            nearestDistanceSq = distanceSq
        end
    end
    return nearestIndex
end

function SpaceMiner:findNearestEnemyIndex(sourceX, sourceY, range)
    local nearestIndex = nil
    local nearestDistanceSq = range * range
    for index, enemy in ipairs(self.enemyShips) do
        local distanceSq = distanceSquared(sourceX, sourceY, enemy.x, enemy.y)
        if distanceSq <= nearestDistanceSq then
            nearestIndex = index
            nearestDistanceSq = distanceSq
        end
    end
    return nearestIndex
end

function SpaceMiner:updateBaseMiningLasers()
    if self.preview or not self:isStoryMode() or self.gameOver then
        return
    end
    self.baseLaserCooldownFrames = math.max(0, (self.baseLaserCooldownFrames or 0) - 1)
    if self.baseLaserCooldownFrames > 0 then
        return
    end

    local shieldDown = not self:isBaseShieldBlockingDamage()
    if not shieldDown and not self:canBaseFireWithShieldUp() then
        return
    end

    local fired = 0
    local firedAtAsteroid = false
    local maxBeams = self:getBaseLaserCount()
    local range = BASE_SHIELD_RADIUS * BASE_MINING_LASER_RANGE_MULTIPLIER
    while fired < maxBeams do
        local asteroidIndex = self:findNearestAsteroidIndex((self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y), range)
        if asteroidIndex ~= nil then
            local asteroid = self.asteroids[asteroidIndex]
            self:addLaserBeam(self.baseLaserBeams, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y), asteroid.x, asteroid.y, 7, fired + 1)
            self:damageAsteroid(asteroidIndex, BASE_MINING_LASER_ASTEROID_DAMAGE, {
                skipRewards = true,
                removalReason = "base-laser"
            })
            fired = fired + 1
            firedAtAsteroid = true
        else
            break
        end
    end

    while fired < maxBeams do
        local enemyIndex = self:findNearestEnemyIndex((self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y), range)
        if enemyIndex ~= nil then
            local enemy = self.enemyShips[enemyIndex]
            self:addLaserBeam(self.baseLaserBeams, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y), enemy.x, enemy.y, 7, fired + 1)
            self:damageEnemy(enemyIndex, BASE_MINING_LASER_ENEMY_DAMAGE * self:getBaseLaserEnemyDamageMultiplier())
            fired = fired + 1
        else
            break
        end
    end

    if fired > 0 then
        self.baseLaserCooldownFrames = BASE_MINING_LASER_COOLDOWN_FRAMES
        self:playLaserSound()
        if firedAtAsteroid and self:isWithinHomeBaseServiceRange() and self:getActiveCommunication() == nil and not self:hasScheduledOrUrgentCommunication() then
            local quotes = self:getFilteredBaseMiningLaserQuotes()
            self:startContextCommunication("base-mining-laser-docked", quotes[math.random(1, math.max(1, #quotes))] or "Scout: I got it.", 90)
        end
    end
end

function SpaceMiner:updatePlayerAutoLasers()
    if self.preview or self.gameOver then
        return
    end
    local upgrade = self:getActiveUpgrade("misc") or {}
    if upgrade.id ~= "auto-mining-lasers" then
        return
    end
    self.playerAutoLaserCooldownFrames = math.max(0, (self.playerAutoLaserCooldownFrames or 0) - 1)
    if self.playerAutoLaserCooldownFrames > 0 then
        return
    end

    local fired = 0
    local maxBeams = upgrade.beams or 3
    while fired < maxBeams do
        local asteroidIndex = self:findNearestAsteroidIndex(self.player.x, self.player.y, PLAYER_AUTO_LASER_RANGE)
        if asteroidIndex ~= nil then
            local asteroid = self.asteroids[asteroidIndex]
            self:addLaserBeam(self.playerAutoLaserBeams, self.player.x, self.player.y, asteroid.x, asteroid.y, 5, fired + 1)
            self:damageAsteroid(asteroidIndex, PLAYER_AUTO_LASER_DAMAGE, {
                removalReason = "auto-laser"
            })
            fired = fired + 1
        else
            break
        end
    end

    while fired < maxBeams and self:isStoryMode() do
        local enemyIndex = self:findNearestEnemyIndex(self.player.x, self.player.y, PLAYER_AUTO_LASER_RANGE)
        if enemyIndex ~= nil then
            local enemy = self.enemyShips[enemyIndex]
            self:addLaserBeam(self.playerAutoLaserBeams, self.player.x, self.player.y, enemy.x, enemy.y, 5, fired + 1)
            self:damageEnemy(enemyIndex, PLAYER_AUTO_LASER_DAMAGE)
            fired = fired + 1
        else
            break
        end
    end

    if fired > 0 then
        self.playerAutoLaserCooldownFrames = PLAYER_AUTO_LASER_COOLDOWN_FRAMES
        self:playLaserSound()
    end
end

function SpaceMiner:explodePlayerMissile(x, y, missile, manualTrigger)
    self:addExplosion(x, y, MISSILE_BLAST_RADIUS, 9)
    self:playExplosionSound()
    local missileDamage = (missile and missile.damage) or self:getMissileDamage()

    self:interceptEnemyMissilesAtPoint(x, y, MISSILE_BLAST_RADIUS + 4)

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
            if missile ~= nil and missile.blastCollector == true then
                self:damageAsteroid(asteroidIndex, 9999, {
                    lootPackage = true,
                    skipRewards = true,
                    spawnFragments = false,
                    removalReason = "missile"
                })
            else
                self:damageAsteroid(asteroidIndex, missileDamage, {
                    missileCascade = true,
                    removalReason = "missile"
                })
            end
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
    if missile ~= nil and missile.blastCollector == true then
        for _, asteroid in ipairs(self.asteroids) do
            local candidateDistanceSq = distanceSquared(missile.x, missile.y, asteroid.x, asteroid.y)
            if candidateDistanceSq < nearestDistanceSq then
                nearest = asteroid
                nearestDistanceSq = candidateDistanceSq
            end
        end
        if nearest ~= nil then
            return nearest.x, nearest.y
        end
    end
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

        if self:checkPlayerMissileShieldViolation(missile) then
            goto continue
        end

        for enemyMissileIndex = #self.enemyMissiles, 1, -1 do
            local enemyMissile = self.enemyMissiles[enemyMissileIndex]
            local hitRadius = (enemyMissile.radius or 4) + 4
            if distanceSquared(missile.x, missile.y, enemyMissile.x, enemyMissile.y) <= (hitRadius * hitRadius) then
                self:explodePlayerMissile(missile.x, missile.y, missile)
                goto continue
            end
        end

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
            and self:isBaseShieldBlockingDamage()
            and distanceSquared(missile.x, missile.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y)) <= (BASE_SHIELD_RADIUS * BASE_SHIELD_RADIUS) then
            self:addExplosion(missile.x, missile.y, 16, 8)
            self:damageBase("enemy-missile")
            table.remove(self.enemyMissiles, missileIndex)
        elseif distanceSquared(missile.x, missile.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y)) <= (28 * 28) then
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
    if not self.player.laserOn or self.gameOver or (self.blockedWeaponButtons or {})["LEFT"] == true then
        self.playerLaserDrawRange = nil
        return
    end

    if self:checkPlayerLaserShieldViolation() then
        self.playerLaserDrawRange = nil
        return
    end

    local radians = math.rad(self.player.angle)
    local endX = self.player.x + (math.cos(radians) * LASER_RANGE)
    local endY = self.player.y + (math.sin(radians) * LASER_RANGE)
    self.playerLaserDrawRange = LASER_RANGE

    local enemyHits = 0
    local hitSomething = false
    for enemyIndex = #self.enemyShips, 1, -1 do
        local enemy = self.enemyShips[enemyIndex]
        local hitDistanceSq = linePointDistanceSquared(enemy.x, enemy.y, self.player.x, self.player.y, endX, endY)
        local hitRadius = enemy.size + LASER_WIDTH
        if hitDistanceSq <= (hitRadius * hitRadius) then
            self:damageEnemy(enemyIndex, self:getLaserDamagePerFrame())
            enemyHits = enemyHits + 1
            hitSomething = true
            if enemyHits >= self:getLaserEnemyPenetrationLimit() then
                break
            end
        end
    end

    local asteroidCandidates = {}
    for asteroidIndex, asteroid in ipairs(self.asteroids) do
        local hitRadius = asteroid.radius + LASER_WIDTH
        local hitT = lineCircleHitParameter(self.player.x, self.player.y, endX, endY, asteroid.x, asteroid.y, hitRadius)
        if hitT ~= nil then
            asteroidCandidates[#asteroidCandidates + 1] = {
                index = asteroidIndex,
                asteroid = asteroid,
                t = hitT
            }
        end
    end
    table.sort(asteroidCandidates, function(a, b)
        return a.t > b.t
    end)

    local asteroidHits = 0
    local hitAsteroids = {}
    local closestStopRange = nil
    local asteroidPenetrationPower = self:getLaserAsteroidPenetrationPower()
    for candidateIndex = #asteroidCandidates, 1, -1 do
        if asteroidHits >= asteroidPenetrationPower then
            break
        end
        local candidate = asteroidCandidates[candidateIndex]
        local asteroid = candidate.asteroid
        if asteroid ~= nil and self.asteroids[candidate.index] == asteroid then
            asteroidHits = asteroidHits + 1
            hitAsteroids[#hitAsteroids + 1] = candidate
            local centerRange = math.sqrt(distanceSquared(self.player.x, self.player.y, asteroid.x, asteroid.y))
            local edgeRange = clamp(centerRange - asteroid.radius, 0, LASER_RANGE)
            closestStopRange = edgeRange
        end
    end
    if closestStopRange ~= nil then
        self.playerLaserDrawRange = closestStopRange
    end

    table.sort(hitAsteroids, function(a, b)
        return a.index > b.index
    end)
    for _, candidate in ipairs(hitAsteroids) do
        local asteroidIndex = candidate.index
        local asteroid = self.asteroids[asteroidIndex]
        if asteroid == candidate.asteroid then
            self:damageAsteroid(asteroidIndex, self:getLaserDamagePerFrame(), {
                removalReason = "laser"
            })
            hitSomething = true
        end
    end
    if self:interceptEnemyMissilesAlongLaser(self.player.x, self.player.y, endX, endY) then
        hitSomething = true
    end
    if hitSomething then
        self:playLaserSound()
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
            and self:isBaseShieldBlockingDamage()
            and distanceSquared(asteroid.x, asteroid.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y)) <= ((asteroid.radius + BASE_SHIELD_RADIUS) * (asteroid.radius + BASE_SHIELD_RADIUS)) then
            self:addExplosion(asteroid.x, asteroid.y, asteroid.radius + 6, 9)
            table.remove(self.asteroids, asteroidIndex)
        elseif self:isStoryMode()
            and not self:isBaseShieldBlockingDamage()
            and distanceSquared(asteroid.x, asteroid.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y)) <= ((asteroid.radius + 24) * (asteroid.radius + 24)) then
            self:addExplosion(asteroid.x, asteroid.y, asteroid.radius + 6, 9)
            self:damageBase("asteroid")
            self:spawnFragments(asteroid)
            table.remove(self.asteroids, asteroidIndex)
        end
    end

    self:resolveAsteroidLayerCollisions()
    self:pruneOffscreenAsteroidsForEntityPressure()
    self:pruneAsteroidsForMemoryPressure()
    self:seedAsteroids(self.preview and PREVIEW_ASTEROID_COUNT or TARGET_ASTEROID_COUNT)
end

function SpaceMiner:resolveAsteroidLayerCollisions()
    local removed = {}
    local collisionsResolved = 0
    for leftIndex = 1, #self.asteroids - 1 do
        if collisionsResolved >= ASTEROID_LAYER_COLLISION_LIMIT_PER_FRAME then
            break
        end
        local left = self.asteroids[leftIndex]
        if type(left) == "table" and not removed[leftIndex] then
            for rightIndex = leftIndex + 1, #self.asteroids do
                local right = self.asteroids[rightIndex]
                if type(right) == "table"
                    and not removed[rightIndex]
                    and left.layer == right.layer
                    and distanceSquared(left.x, left.y, right.x, right.y) <= ((left.radius + right.radius) * (left.radius + right.radius)) then
                    self:addExplosion((left.x + right.x) * 0.5, (left.y + right.y) * 0.5, math.max(left.radius, right.radius) + 3, 8)
                    if self:getActiveEntityCount() < ASTEROID_FRAGMENT_ENTITY_LIMIT then
                        self:spawnFragments(left, { missileCascade = false })
                        self:spawnFragments(right, { missileCascade = false })
                    end
                    removed[leftIndex] = true
                    removed[rightIndex] = true
                    collisionsResolved = collisionsResolved + 1
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
    local count = #self.asteroids + #self.enemyShips + #self.enemyMissiles + #self.explosions + #(self.lootPackages or {})
    count = count + #(self.player.missiles or {})
    return count
end

function SpaceMiner:pruneAsteroidsForMemoryPressure()
    if self.preview then
        return
    end
    local asteroidHardLimit = math.max(TARGET_ASTEROID_COUNT + 18, math.floor(MAX_ACTIVE_ENTITIES * 0.75))
    local activeEntities = self:getActiveEntityCount()
    if #self.asteroids <= asteroidHardLimit and activeEntities < MAX_ACTIVE_ENTITIES then
        return
    end

    local candidates = {}
    for asteroidIndex = #self.asteroids, 1, -1 do
        local asteroid = self.asteroids[asteroidIndex]
        if type(asteroid) ~= "table" then
            table.remove(self.asteroids, asteroidIndex)
        else
            local _, _, visible = self:getAsteroidScreenState(asteroid)
            candidates[#candidates + 1] = {
                asteroid = asteroid,
                visible = visible,
                radius = asteroid.radius or 0,
                age = asteroid.ageFrames or 0,
                lastVisibleFrame = asteroid.lastVisibleFrame or -99999
            }
        end
    end

    table.sort(candidates, function(left, right)
        if left.visible ~= right.visible then
            return not left.visible
        end
        if left.age ~= right.age then
            return left.age > right.age
        end
        return left.radius < right.radius
    end)

    local removedAsteroids = {}
    local removedCount = 0
    activeEntities = self:getActiveEntityCount()
    for _, candidate in ipairs(candidates) do
        if #self.asteroids - removedCount <= asteroidHardLimit and activeEntities - removedCount < MAX_ACTIVE_ENTITIES then
            break
        end
        if candidate.visible and (#self.asteroids - removedCount) <= asteroidHardLimit + 8 then
            goto continue
        end
        if candidate.age < ASTEROID_PRUNE_PROTECTION_FRAMES and (#self.asteroids - removedCount) <= asteroidHardLimit + 8 then
            goto continue
        end
        removedAsteroids[candidate.asteroid] = true
        removedCount = removedCount + 1
        ::continue::
    end

    if removedCount <= 0 then
        return
    end
    for asteroidIndex = #self.asteroids, 1, -1 do
        if removedAsteroids[self.asteroids[asteroidIndex]] then
            table.remove(self.asteroids, asteroidIndex)
        end
    end
    local luaKb = 0
    if collectgarbage ~= nil then
        luaKb = collectgarbage("count") or 0
    end
    StarryLog.forceDebug(
        "miner memory prune asteroids removed=%d asteroids=%d hardLimit=%d active=%d luaKB=%.0f",
        removedCount,
        #self.asteroids,
        asteroidHardLimit,
        self:getActiveEntityCount(),
        luaKb
    )
end

function SpaceMiner:countTableKeys(source)
    local count = 0
    for _ in pairs(source or {}) do
        count = count + 1
    end
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
        if distanceSquared(enemy.x, enemy.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y)) <= baseRadiusSq then
            nearBaseEnemies = nearBaseEnemies + 1
        end
    end
    local luaKb = 0
    if collectgarbage ~= nil then
        luaKb = collectgarbage("count") or 0
    end
    local beamCount = #(self.baseLaserBeams or {}) + #(self.playerAutoLaserBeams or {}) + #(self.enemyLaserBeams or {})
    StarryLog.forceDebug(
        "miner entities frame=%d stage=%d/%d total=%d asteroids=%d enemies=%d offscreenEnemies=%d nearBaseEnemies=%d enemyMissiles=%d playerMissiles=%d lootPackages=%d explosions=%d beams=%d cargo=%d/%d baseShield=%d menu=%s gameOver=%s luaKB=%.0f history=%d seen=%d dismissed=%d decor=%d",
        self.frame,
        self.stageIndex or 0,
        self:getModeStageCount(),
        self:getActiveEntityCount(),
        #self.asteroids,
        #self.enemyShips,
        offscreenEnemies,
        nearBaseEnemies,
        #self.enemyMissiles,
        #(self.player.missiles or {}),
        #(self.lootPackages or {}),
        #self.explosions,
        beamCount,
        self.cargoOre or 0,
        math.floor((self.cargoCapacity or CARGO_INITIAL_CAPACITY) + 0.0001),
        self.baseShieldHits or 0,
        tostring(self.menuOpen == true),
        tostring(self.gameOver == true),
        luaKb,
        #(self.communicationHistory or {}),
        self:countTableKeys(self.communicationSeenKeys),
        self:countTableKeys(self.dismissedCommunications),
        #(self.decor or {})
    )
end

function SpaceMiner:pruneOffscreenAsteroidsForEntityPressure()
    local activeEntities = self:getActiveEntityCount()
    if activeEntities <= MAX_ACTIVE_ENTITIES then
        return
    end

    self.asteroidDiagnostics.pressureChecks = self.asteroidDiagnostics.pressureChecks + 1
    local removable = {}
    for asteroidIndex = #self.asteroids, 1, -1 do
        local asteroid = self.asteroids[asteroidIndex]
        if type(asteroid) ~= "table" then
            table.remove(self.asteroids, asteroidIndex)
            activeEntities = activeEntities - 1
        else
            local drawX, drawY, visible = self:getAsteroidScreenState(asteroid)
            if not visible then
                removable[#removable + 1] = {
                    asteroid = asteroid,
                    radius = asteroid.radius or 0,
                    drawX = drawX,
                    drawY = drawY
                }
            else
                asteroid.lastVisibleFrame = self.frame
            end
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
    local x, y, angle = self:getWaveSpawnPoint(entryDegrees, 260, 360)
    x, y = self:movePointOutsideBaseSpawnExclusion(x, y, 6, angle)
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
    local attackRange = normalizeTarget(enemy.target) == "player" and (enemy.playerAttackRange or 520) or (enemy.baseAttackRange or 220)
    if enemy.missileCooldown <= 0 and distance < attackRange then
        self:spawnEnemyMissile(enemy)
        enemy.missileCooldown = STRIKER_MISSILE_COOLDOWN + math.random(0, 35)
    end
end

function SpaceMiner:updateLaserEnemy(enemy)
    local targetX, targetY = self:getTargetPosition(enemy.target)
    local targetVx, targetVy = self:getTargetVelocity(enemy.target)
    local desiredDistance = enemy.laserRange or 152
    local orbitSpeed = enemy.orbitSpeed or 0.045

    if enemy.orbitAngle == nil then
        enemy.orbitAngle = math.atan(enemy.y - targetY, enemy.x - targetX)
    end
    enemy.orbitAngle = enemy.orbitAngle + (orbitSpeed * (enemy.orbitDirection or 1))

    local orbitX = targetX + math.cos(enemy.orbitAngle) * desiredDistance + (targetVx * ENEMY_PREDICTION_FRAMES * 0.25)
    local orbitY = targetY + math.sin(enemy.orbitAngle) * desiredDistance + (targetVy * ENEMY_PREDICTION_FRAMES * 0.25)
    local avoidX, avoidY = self:getAsteroidAvoidance(enemy, 110, 52)
    orbitX = orbitX + avoidX
    orbitY = orbitY + avoidY

    local steerX, steerY = steerBodyToward(enemy, orbitX, orbitY, enemy.maxSpeed, enemy.acceleration * 1.1, desiredDistance * 0.8)
    if math.abs(steerX) > 0.0001 or math.abs(steerY) > 0.0001 then
        enemy.angle = normalizeAngle(math.deg(math.atan(steerY, steerX)))
    end

    enemy.laserCooldown = enemy.laserCooldown - 1
    local distance = magnitude(targetX - enemy.x, targetY - enemy.y)
    local targetKind = normalizeTarget(enemy.target)
    local attackRange = targetKind == "player" and (enemy.playerAttackRange or 520) or (enemy.baseAttackRange or desiredDistance + 40)
    if enemy.laserCooldown <= 0 and distance <= attackRange then
        self:addLaserBeam(self.enemyLaserBeams, enemy.x, enemy.y, targetX, targetY, 8, 1)
        local bursts = math.max(1, enemy.laserDamage or 1)
        for _ = 1, bursts do
            if targetKind == "base" then
                self:damageBase("enemy-laser")
            else
                self:damagePlayer("enemy-laser")
            end
        end
        self:playLaserSound()
        enemy.laserCooldown = (enemy.laserCooldownReset or 52) + math.random(0, 18)
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
            elseif enemy.type == "laserEnemy" then
                self:updateLaserEnemy(enemy)
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
                and self:isBaseShieldBlockingDamage()
                and distanceSquared(enemy.x, enemy.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y)) <= ((enemy.size + BASE_SHIELD_RADIUS) * (enemy.size + BASE_SHIELD_RADIUS)) then
                self:addExplosion(enemy.x, enemy.y, enemy.size + 8, 9)
                self:damageBase("enemy-ship")
                table.remove(self.enemyShips, enemyIndex)
            elseif distanceSquared(enemy.x, enemy.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y)) <= ((enemy.size + 24) * (enemy.size + 24)) then
                self:addExplosion(enemy.x, enemy.y, enemy.size + 8, 9)
                self:damageBase("enemy-ship")
                table.remove(self.enemyShips, enemyIndex)
            end
        end
    end
end

function SpaceMiner:updateLootPackages()
    self.lootPackages = self.lootPackages or {}
    local tractorRadius, tractorPull = self:getTractorBeamStats()
    local tractorRadiusSq = tractorRadius * tractorRadius
    for index = #self.lootPackages, 1, -1 do
        local package = self.lootPackages[index]
        if tractorRadius > 0 then
            local dx = self.player.x - package.x
            local dy = self.player.y - package.y
            local distanceSqToPlayer = (dx * dx) + (dy * dy)
            if distanceSqToPlayer <= tractorRadiusSq and distanceSqToPlayer > 0.0001 then
                local ux, uy = unitVector(dx, dy)
                package.vx = (package.vx or 0) + (ux * tractorPull)
                package.vy = (package.vy or 0) + (uy * tractorPull)
                local speed = magnitude(package.vx or 0, package.vy or 0)
                local maxSpeed = 3.2
                if speed > maxSpeed then
                    package.vx = (package.vx / speed) * maxSpeed
                    package.vy = (package.vy / speed) * maxSpeed
                end
            end
        end
        package.x = package.x + (package.vx or 0)
        package.y = package.y + (package.vy or 0)
        package.life = (package.life or 1) - 1
        if package.life <= 0 then
            table.remove(self.lootPackages, index)
        elseif distanceSquared(package.x, package.y, self.player.x, self.player.y) <= (18 * 18) then
            if self:collectLootPackage(package) then
                table.remove(self.lootPackages, index)
                self:playUiClick()
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
    if self.titleStandby then
        return
    end
    self.previewFrameCounter = self.previewFrameCounter + 1
    self.player.angle = normalizeAngle(self.player.angle + 1.4)
    self.previewDriftAngle = self.previewDriftAngle + 0.01
    applyAcceleration(self.player, math.cos(self.previewDriftAngle) * 0.01, math.sin(self.previewDriftAngle) * 0.01, 0.9)
    self:updatePlayerPosition()
    self:updateDecor()
    self:updateAsteroids()
    self:updateExplosions()
end

function SpaceMiner:updateTitleStandby()
    self.previewFrameCounter = (self.previewFrameCounter or 0) + 1
    self:updateDecor()
    self:updateExplosions()
    self:updateLaserBeams(self.baseLaserBeams)
    self:updateLaserBeams(self.playerAutoLaserBeams)
    self:updateLaserBeams(self.enemyLaserBeams)
end

function SpaceMiner:update()
    if self.preview then
        self:updatePreview()
        return
    end
    if self.titleStandby then
        self:updateTitleStandby()
        return
    end

    self:resolveDeferredStoryLoad()

    if self.storySlotSelectorOpen then
        self.input.thrust = 0
        self.input.reverse = 0
        self.input.laser = false
        self.player.laserOn = false
        self.player.pendingMissileTrigger = false
        self.previewFrameCounter = (self.previewFrameCounter or 0) + 1
        self:updateDecor()
        self:updateExplosions()
        self:updateLaserBeams(self.baseLaserBeams)
        self:updateLaserBeams(self.playerAutoLaserBeams)
        self:updateLaserBeams(self.enemyLaserBeams)
        self:updateAudio()
        return
    end

    if self.nameEntryOpen then
        self.input.thrust = 0
        self.input.reverse = 0
        self.input.laser = false
        self.player.laserOn = false
        self.player.pendingMissileTrigger = false
        self:updateAudio()
        return
    end

    self:updateInstructionOverlay()
    self:updateDashboardIndicator()

    if not self.menuOpen then
        self.frame = self.frame + 1
    end
    if self:isStoryMode() or self:isOreMinerMode() then
        self:updateHomeBaseVisitState()
        self:updateBaseCollisionCommunication()
        if self:isStoryMode() then
            self:updateBaseTimeline()
            self:updateSettingsTimeline()
            self:updateDestroyedCommunications()
        end
    end
    if self.baseUnderAttackFrames > 0 and not (self.menuOpen and self.menuType == "home") then
        self.baseUnderAttackFrames = self.baseUnderAttackFrames - 1
    end
    if (self.supernovaFlashFrames or 0) > 0 then
        self.supernovaFlashFrames = self.supernovaFlashFrames - 1
    end
    if (self.baseModeTransitionFrame or BASE_MODE_TRANSITION_FRAMES) < BASE_MODE_TRANSITION_FRAMES then
        self.baseModeTransitionFrame = math.min(BASE_MODE_TRANSITION_FRAMES, (self.baseModeTransitionFrame or 0) + 1)
        if self.baseModeTransitionFrame >= BASE_MODE_TRANSITION_FRAMES then
            self.previousBaseModeId = nil
        end
    end
    self:updateStage()
    self:updateEntityMoves()
    self:updateCargo()
    self:updateHomeBaseRepairs()
    if self.menuOpen then
        self.input.thrust = 0
        self.input.reverse = 0
        self.input.laser = false
        self.player.laserOn = false
        self:updateMenuAutoNavigate()
        self:updateRotaryMenuSpin()
    end
    self:updateHomeBaseAutopilot()
    self:applyPlayerThrust()
    self:updateAudio()
    self:updatePlayerPosition()
    self:updateDecor()
    self:updatePlayerMissile()
    self:applyLaser()
    if self:isStoryMode() then
        self:updateEnemyMissiles()
    end
    if self:isStoryMode() then
        self:updateEnemies()
    end
    self:updateBaseMiningLasers()
    self:updatePlayerAutoLasers()
    self:updateLaserBeams(self.baseLaserBeams)
    self:updateLaserBeams(self.playerAutoLaserBeams)
    self:updateLaserBeams(self.enemyLaserBeams)
    self:updateLootPackages()
    self:updateAsteroids()
    self:updateExplosions()
    self:pruneCommunicationCachesIfNeeded()
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
    local frame = self.titleStandby and (self.previewFrameCounter or 0) or (self.frame or 0)
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
        self:drawMiniMapMarker((self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y), "base")
    end
    for _, enemy in ipairs(self.enemyShips) do
        self:drawMiniMapMarker(enemy.x, enemy.y, "enemy")
    end
end

function SpaceMiner:drawCargoSpaceBar()
    if self:isOreMinerMode() then
        return
    end
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

function SpaceMiner:getMenuValueText(item)
    if item.action == "open-screen" and item.value ~= nil then
        return tostring(item.value)
    elseif item.kind == "button" or item.action == "trigger-next-event" then
        return ">"
    elseif item.action == "trigger-specific-event" then
        return item.value ~= nil and tostring(item.value) or ">"
    elseif item.action == "history-line" then
        return item.value ~= nil and tostring(item.value) or ""
    elseif item.action == "buy-upgrade" then
        return item.cost ~= nil and string.format("$%d", item.cost) or ""
    elseif item.action == "owned-upgrade" then
        return "On"
    elseif item.action == "equip-upgrade" then
        return item.value and "On" or "Equip"
    elseif item.action == "open-screen" then
        return item.value ~= nil and tostring(item.value) or ">"
    end
    return item.value and "On" or "Off"
end

function SpaceMiner:drawClippedMenuText(text, x, y, width, drawMode)
    gfx.setImageDrawMode(drawMode or gfx.kDrawModeFillWhite)
    gfx.setClipRect(x, y, width, MINER_MENU_ROW_HEIGHT)
    gfx.drawText(tostring(text or ""), x, y)
    gfx.clearClipRect()
end

function SpaceMiner:drawModernMenuButton(item, x, y, width, height, selected)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    if selected then
        x = x - 2
        y = y - 2
        width = width + 4
        height = height + 4
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRoundRect(x, y, width, height, 5)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRoundRect(x, y, width, height, 5)
        local textY = y + math.floor((height - 14) * 0.5)
        gfx.setClipRect(x + 4, y + 1, width - 8, height - 2)
        gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
        gfx.drawTextAligned(tostring(item.label or ""), x + (width * 0.5), textY, kTextAlignment.center)
        gfx.drawTextAligned(tostring(item.label or ""), x + (width * 0.5) + 1, textY, kTextAlignment.center)
        gfx.clearClipRect()
    else
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRoundRect(x, y, width, height, 5)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawRoundRect(x, y, width, height, 5)
        local textY = y + math.floor((height - 14) * 0.5)
        gfx.setClipRect(x + 4, y + 1, width - 8, height - 2)
        gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        gfx.drawTextAligned(tostring(item.label or ""), x + (width * 0.5), textY, kTextAlignment.center)
        gfx.clearClipRect()
    end
end

function SpaceMiner:drawModernMenuRowButton(item, x, y, width, height, selected, valueText, flashError)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    local drawX = x
    local drawY = y
    local drawWidth = width
    local drawHeight = height
    if selected then
        drawX = drawX - 2
        drawY = drawY - 2
        drawWidth = drawWidth + 4
        drawHeight = drawHeight + 4
    end

    if selected then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRoundRect(drawX, drawY, drawWidth, drawHeight, 5)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRoundRect(drawX, drawY, drawWidth, drawHeight, 5)
        gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
    else
        gfx.setColor(flashError and gfx.kColorWhite or gfx.kColorBlack)
        gfx.fillRoundRect(drawX, drawY, drawWidth, drawHeight, 5)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawRoundRect(drawX, drawY, drawWidth, drawHeight, 5)
        gfx.setImageDrawMode(flashError and gfx.kDrawModeFillBlack or gfx.kDrawModeFillWhite)
    end

    if item.action == "history-line" then
        local labelY = drawY + 4
        local textY = drawY + 17
        gfx.setClipRect(drawX + 10, drawY + 2, drawWidth - 20, drawHeight - 4)
        gfx.setImageDrawMode(selected and gfx.kDrawModeFillBlack or gfx.kDrawModeFillWhite)
        gfx.drawText(tostring(item.label or ""), drawX + 10, labelY)
        gfx.drawText(tostring(item.value or ""), drawX + 10, textY)
        gfx.clearClipRect()
        return
    end

    local labelY = drawY + math.floor((drawHeight - 14) * 0.5)
    local labelWidth = drawWidth - 90
    self:drawClippedMenuText(item.label, drawX + 10, labelY, labelWidth, selected and gfx.kDrawModeFillBlack or (flashError and gfx.kDrawModeFillBlack or gfx.kDrawModeFillWhite))
    if selected then
        self:drawClippedMenuText(item.label, drawX + 11, labelY, labelWidth, gfx.kDrawModeFillBlack)
    end

    if valueText ~= nil and valueText ~= "" then
        gfx.setImageDrawMode(selected and gfx.kDrawModeFillBlack or (flashError and gfx.kDrawModeFillBlack or gfx.kDrawModeFillWhite))
        gfx.drawTextAligned(tostring(valueText), drawX + drawWidth - 10, labelY, kTextAlignment.right)
        if selected then
            gfx.drawTextAligned(tostring(valueText), drawX + drawWidth - 9, labelY, kTextAlignment.right)
        end
    end
end

function SpaceMiner:drawModernMenuHeader(title)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawText(title, 18, 13)
    gfx.drawText(title, 19, 13)
    gfx.drawTextAligned(string.format("$%d", self.cash or 0), SCREEN_WIDTH - 18, 13, kTextAlignment.right)
    gfx.drawLine(18, 33, SCREEN_WIDTH - 18, 33)
end

function SpaceMiner:drawModernHomeDirectoryMenu(items, selectedIndex)
    local activeIndex = selectedIndex or self.menuIndex
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    self:drawModernMenuHeader("Home Base")

    local positions = {
        { x = 18, y = 38 }, { x = 208, y = 38 },
        { x = 18, y = 80 }, { x = 208, y = 80 },
        { x = 18, y = 122 }, { x = 208, y = 122 }
    }
    for index = 1, math.min(6, #items) do
        local pos = positions[index]
        self:drawModernMenuButton(items[index], pos.x, pos.y, 174, 30, index == activeIndex)
    end
    if items[7] ~= nil then
        self:drawModernMenuButton(items[7], 113, 166, 174, 30, activeIndex == 7)
    end
    if items[8] ~= nil then
        self:drawModernMenuButton(items[8], 113, 205, 174, 30, activeIndex == 8)
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorWhite)
end

function SpaceMiner:drawScrollTriangle(direction, centerX, centerY)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorWhite)
    local halfWidth = 14
    local height = 5
    if direction == "up" then
        gfx.fillTriangle(centerX - halfWidth, centerY + height, centerX + halfWidth, centerY + height, centerX, centerY - height)
    else
        gfx.fillTriangle(centerX - halfWidth, centerY - height, centerX + halfWidth, centerY - height, centerX, centerY + height)
    end
end

function SpaceMiner:getHomeDirectoryMenuItems()
    local items = {}
    for _, screen in ipairs(HOME_MENU_SCREENS) do
        items[#items + 1] = {
            id = screen.id,
            label = screen.label,
            action = "open-screen"
        }
    end
    return items
end

function SpaceMiner:drawModernListMenu(items)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    local screen = self.menuType == "home" and self.homeMenuScreen or self.shipMenuScreen
    local title = "Ship Menu"
    if self.menuType == "home" then
        if screen == "directory" then
            title = "Home Base"
        elseif screen == "resources" then
            title = "Ore Resources"
        elseif screen == "communications" then
            title = "Communication History"
        elseif screen == "trigger-event" then
            title = "Trigger Next Event"
        elseif screen == "apology" then
            title = "Scout Apology"
        else
            title = (UPGRADE_CATEGORY_CONFIG[self:getUpgradeCategoryForScreen(screen)] or {}).title or "Game Settings"
        end
    elseif screen == "auto-pilot" then
        title = "Auto Pilot"
    elseif screen == "right-button" then
        title = "Right D Pad Mapping"
    elseif screen == "trigger-event" then
        title = "Trigger Next Event"
    end
    self:drawModernMenuHeader(title)
    if #items <= 0 then
        return
    end
    self.menuIndex = clamp(self.menuIndex or 1, 1, #items)
    local slotFrames = {
        [-3] = { y = 36, width = 190, height = 18 },
        [-2] = { y = 52, width = 252, height = 23 },
        [-1] = { y = 82, width = 312, height = 28 },
        [0] = { y = 119, width = 354, height = 36 },
        [1] = { y = 164, width = 312, height = 28 },
        [2] = { y = 198, width = 252, height = 23 },
        [3] = { y = 219, width = 190, height = 18 }
    }
    local fractionalOffset = self.menuCrankAccumulator or 0
    local drawn = {}
    for offset = -3, 3 do
        local visualOffset = offset - fractionalOffset
        local lowerOffset = math.floor(visualOffset)
        local upperOffset = lowerOffset + 1
        local lowerFrame = slotFrames[lowerOffset]
        local upperFrame = slotFrames[upperOffset]
        local frame = nil
        if lowerFrame ~= nil and upperFrame ~= nil then
            local t = visualOffset - lowerOffset
            frame = {
                y = lowerFrame.y + ((upperFrame.y - lowerFrame.y) * t),
                width = lowerFrame.width + ((upperFrame.width - lowerFrame.width) * t),
                height = lowerFrame.height + ((upperFrame.height - lowerFrame.height) * t)
            }
        elseif slotFrames[visualOffset] ~= nil then
            frame = slotFrames[visualOffset]
        end
        local itemIndex = ((self.menuIndex + offset - 1) % #items) + 1
        local shouldDraw = true
        if frame == nil then
            shouldDraw = false
        elseif #items < 7 and math.abs(offset) > math.floor(#items / 2) then
            shouldDraw = false
        elseif drawn[itemIndex] then
            shouldDraw = false
        end
        if shouldDraw then
            drawn[itemIndex] = true
            local item = items[itemIndex]
            local selected = offset == 0
            local unaffordable = item.action == "buy-upgrade" and item.enabled == false
            local flashError = unaffordable and (math.floor((self.frame or 0) / 8) % 2 == 0)
            local valueText = self:getMenuValueText(item)
            local buttonWidth = math.floor(frame.width + 0.5)
            local buttonX = math.floor((SCREEN_WIDTH - buttonWidth) * 0.5)
            self:drawModernMenuRowButton(item, buttonX, math.floor(frame.y + 0.5), buttonWidth, math.floor(frame.height + 0.5), selected, valueText, flashError)
        end
    end
    if #items > 7 then
        self:drawScrollTriangle("up", SCREEN_WIDTH * 0.5, 38)
        self:drawScrollTriangle("down", SCREEN_WIDTH * 0.5, SCREEN_HEIGHT - 7)
    end
    if self.menuRotaryFreeSpin then
        gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        gfx.drawTextAligned("FREE SPIN", SCREEN_WIDTH - 58, 215, kTextAlignment.center)
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorWhite)
end

function SpaceMiner:drawCommunicationHistoryReader()
    local lines, contentHeight = self:getCommunicationHistoryReaderLines()
    local contentTop = 38
    local contentBottom = SCREEN_HEIGHT - 14
    local contentHeightAvailable = contentBottom - contentTop
    local maxScrollY = math.max(0, (contentHeight or 0) - contentHeightAvailable)
    self.communicationHistoryScrollY = clamp(self.communicationHistoryScrollY or 0, 0, maxScrollY)
    self.communicationHistoryCursorIndex = clamp(self.communicationHistoryCursorIndex or 1, 1, math.max(1, #lines))

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    gfx.setColor(gfx.kColorWhite)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawText("Communication History", 16, 12)
    gfx.drawTextAligned(string.format("%d%%", math.floor(((self.communicationHistoryScrollY or 0) / math.max(1, maxScrollY)) * 100)), SCREEN_WIDTH - 16, 12, kTextAlignment.right)
    gfx.drawLine(14, 34, SCREEN_WIDTH - 14, 34)

    gfx.setClipRect(14, contentTop, SCREEN_WIDTH - 28, contentHeightAvailable)
    local yOffset = contentTop - (self.communicationHistoryScrollY or 0)
    for _, line in ipairs(lines) do
        local y = yOffset + line.y
        if y + line.height >= contentTop and y <= contentBottom then
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
            gfx.drawText(line.text, 22, y)
            if line.kind == "header" then
                gfx.drawText(line.text, 23, y)
            end
        end
    end

    local cursorLine = lines[self.communicationHistoryCursorIndex]
    if cursorLine ~= nil and (math.floor((self.frame or 0) / 12) % 2) == 0 then
        local cursorY = yOffset + cursorLine.y
        if cursorY + cursorLine.height >= contentTop and cursorY <= contentBottom then
            local bounce = math.floor(math.sin((self.frame or 0) * 0.22) * 4 + 0.5)
            local cursorX = 20 + bounce
            local cursorHeight = math.max(10, cursorLine.height - 2)
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRect(cursorX, cursorY, 9, cursorHeight)
            gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
            if cursorLine.text ~= "" then
                gfx.drawText(string.sub(cursorLine.text, 1, 1), cursorX + 2, cursorY)
            end
        end
    end
    gfx.clearClipRect()

    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawText("Up/Down/Crank scroll   Left/B back", 16, SCREEN_HEIGHT - 12)
    if self.communicationHistoryScrollY > 0 then
        self:drawScrollTriangle("up", SCREEN_WIDTH * 0.5, contentTop - 9)
    end
    if self.communicationHistoryScrollY < maxScrollY then
        self:drawScrollTriangle("down", SCREEN_WIDTH * 0.5, contentBottom - 8)
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorWhite)
end

function SpaceMiner:isModernSubmenuScreen()
    if self.menuType == "home" then
        return self.homeMenuScreen ~= "directory"
    end
    if self.menuType == "ship" then
        return self.shipMenuScreen ~= "directory"
    end
    return false
end

local function makeMenuBackdropStar(size, x, y, depth, kind, extra)
    return {
        x = x,
        y = y,
        size = size,
        depth = depth,
        kind = kind or "star",
        extra = extra
    }
end

local function createMenuBackdropStars()
    local stars = {}
    local function addStar(x, y, size, depth, kind, extra)
        stars[#stars + 1] = makeMenuBackdropStar(size, x, y, depth, kind, extra)
    end

    local clusterCount = 18
    local galaxyCount = 6
    local clusterSize = 6
    local galaxyStarCount = 12
    local fieldBudget = math.max(0, MENU_BACKGROUND_STAR_COUNT - (clusterCount * clusterSize) - (galaxyCount * galaxyStarCount))

    for _ = 1, fieldBudget do
        local depth = math.random()
        local size = depth < 0.25 and 1 or (depth < 0.75 and 2 or 3)
        addStar(
            math.random(2, SCREEN_WIDTH - 2),
            math.random(2, SCREEN_HEIGHT - 2),
            size,
            depth,
            "star"
        )
    end

    for _ = 1, clusterCount do
        local centerX = math.random(24, SCREEN_WIDTH - 24)
        local centerY = math.random(24, SCREEN_HEIGHT - 24)
        for index = 1, clusterSize do
            local angle = (index / clusterSize) * math.pi * 2
            local radius = math.random(2, 11)
            local depth = 0.65 + (math.random() * 0.3)
            addStar(
                centerX + (math.cos(angle) * radius) + math.random(-2, 2),
                centerY + (math.sin(angle) * radius) + math.random(-2, 2),
                depth > 0.82 and 3 or 2,
                depth,
                "cluster",
                { centerX = centerX, centerY = centerY }
            )
        end
    end

    for _ = 1, galaxyCount do
        local centerX = math.random(48, SCREEN_WIDTH - 48)
        local centerY = math.random(34, SCREEN_HEIGHT - 34)
        local armCount = galaxyStarCount
        local spiralDirection = math.random() < 0.5 and 1 or -1
        for index = 1, armCount do
            local progress = index / armCount
            local angle = (progress * math.pi * 2.4 * spiralDirection) + (math.random() * 0.45)
            local radius = 8 + (progress * math.random(10, 22))
            addStar(
                centerX + (math.cos(angle) * radius),
                centerY + (math.sin(angle) * radius),
                progress > 0.6 and 2 or 1,
                0.85 + (progress * 0.12),
                "galaxy",
                { centerX = centerX, centerY = centerY, spiralDirection = spiralDirection }
            )
        end
    end

    return stars
end

local function drawMenuBackdropStars(stars)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    gfx.setColor(gfx.kColorWhite)
    for _, star in ipairs(stars or {}) do
        local size = star.size or 1
        if star.kind == "galaxy" then
            local extra = star.extra or {}
            local centerX = extra.centerX or star.x
            local centerY = extra.centerY or star.y
            local dx = star.x - centerX
            local dy = star.y - centerY
            gfx.drawLine(centerX, centerY, centerX + (dx * 0.75), centerY + (dy * 0.75))
            gfx.fillCircleAtPoint(star.x, star.y, size)
        elseif star.kind == "cluster" then
            local extra = star.extra or {}
            local centerX = extra.centerX or star.x
            local centerY = extra.centerY or star.y
            gfx.drawLine(centerX - 1, centerY, centerX + 1, centerY)
            gfx.drawLine(centerX, centerY - 1, centerX, centerY + 1)
            gfx.fillCircleAtPoint(star.x, star.y, size)
        elseif size >= 3 then
            gfx.fillCircleAtPoint(star.x, star.y, 1)
            gfx.drawCircleAtPoint(star.x, star.y, 1)
        elseif size == 2 then
            gfx.drawRect(star.x, star.y, 2, 2)
        else
            gfx.fillRect(star.x, star.y, 1, 1)
        end
    end
end

function SpaceMiner:drawMenuBackground()
    if self.menuBackgroundImage ~= nil then
        self.menuBackgroundImage:draw(0, 0)
        return
    end

    if self.menuBackgroundStars == nil then
        self.menuBackgroundStars = createMenuBackdropStars()
    end
    drawMenuBackdropStars(self.menuBackgroundStars)
end

function SpaceMiner:drawMenuOverlay()
    if not self.menuOpen then
        return
    end

    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
end

function SpaceMiner:drawMenu()
    if not self.menuOpen then
        return
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    if self.menuType ~= "home" and self.menuType ~= "ship" then
        return
    end
    if (self.menuType == "home" and self.homeMenuScreen == "communications")
        or (self.menuType == "ship" and self.shipMenuScreen == "communications") then
        self:drawCommunicationHistoryReader()
        return
    end
    local items = self:getMenuItems()
    if self.menuType == "home" and self.homeMenuScreen == "directory" then
        self:drawModernHomeDirectoryMenu(items)
    else
        self:drawModernListMenu(items)
    end
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
    local function drawShipRect(forward, side, rectWidth, rectHeight)
        local halfW = rectWidth * 0.5
        local halfH = rectHeight * 0.5
        local corners = {
            { forward - halfH, side - halfW },
            { forward + halfH, side - halfW },
            { forward + halfH, side + halfW },
            { forward - halfH, side + halfW }
        }
        for index = 1, 4 do
            local nextIndex = (index % 4) + 1
            local ax, ay = pointForwardSide(corners[index][1], corners[index][2])
            local bx, by = pointForwardSide(corners[nextIndex][1], corners[nextIndex][2])
            gfx.drawLine(ax, ay, bx, by)
        end
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
        drawShipRect(-2, 7, 3, 8)
    end

    local miscUpgrade = self:getActiveUpgrade("misc") or {}
    if miscUpgrade.id == "auto-mining-lasers" then
        for side = -1, 1 do
            drawShipRect(-1, side * 6, 4, 4)
        end
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
    local drawX, drawY = worldToScreen(self.player.x, self.player.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y))
    if drawX < -BASE_DRAW_MARGIN
        or drawX > SCREEN_WIDTH + BASE_DRAW_MARGIN
        or drawY < -BASE_DRAW_MARGIN
        or drawY > DASHBOARD_Y + BASE_DRAW_MARGIN then
        return
    end

    gfx.setColor(gfx.kColorWhite)
    self:drawBaseEntity(drawX, drawY)

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

    if distanceSquared(self.player.x, self.player.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y)) <= (BASE_PROXIMITY_RADIUS * BASE_PROXIMITY_RADIUS) then
        gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        gfx.drawTextAligned(self.baseName or "Home Base", drawX, drawY - 56, kTextAlignment.center)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
end

function SpaceMiner:drawBaseEntityImage(modeId, drawX, drawY, dither)
    gfx.setColor(gfx.kColorWhite)
    if dither ~= nil and dither < 0.99 then
        gfx.setDitherPattern(clamp(dither, 0.05, 0.95), gfx.image.kDitherTypeBayer8x8)
    end
    local image = (self.baseImages or {})[modeId] or self.baseImage
    if image ~= nil then
        image:drawCentered(drawX, drawY)
    else
        gfx.drawCircleAtPoint(drawX, drawY, 21)
        gfx.drawCircleAtPoint(drawX, drawY, 13)
        gfx.drawRect(drawX - 8, drawY - 8, 16, 16)
        gfx.drawLine(drawX - 27, drawY, drawX - 14, drawY)
        gfx.drawLine(drawX + 14, drawY, drawX + 27, drawY)
        gfx.drawLine(drawX, drawY - 27, drawX, drawY - 14)
        gfx.drawLine(drawX, drawY + 14, drawX, drawY + 27)
    end
    if dither ~= nil and dither < 0.99 then
        gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    end
end

function SpaceMiner:drawBaseEntity(drawX, drawY)
    local transitionFrame = self.baseModeTransitionFrame or BASE_MODE_TRANSITION_FRAMES
    if self.previousBaseModeId ~= nil and transitionFrame < BASE_MODE_TRANSITION_FRAMES then
        local progress = clamp(transitionFrame / BASE_MODE_TRANSITION_FRAMES, 0, 1)
        self:drawBaseEntityImage(self.previousBaseModeId, drawX, drawY, 1 - progress)
        self:drawBaseEntityImage(self.baseModeId, drawX, drawY, progress)
    else
        self:drawBaseEntityImage(self.baseModeId, drawX, drawY, 1)
    end
end

function SpaceMiner:drawHomeBaseCargoBeam()
    if not self:isWithinHomeBaseServiceRange() then
        return
    end

    local baseX, baseY = worldToScreen(self.player.x, self.player.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y))
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
    local drawX, drawY = worldToScreen(self.player.x, self.player.y, (self.baseWorldX or BASE_WORLD_X), (self.baseWorldY or BASE_WORLD_Y))
    if drawX >= 0 and drawX <= SCREEN_WIDTH and drawY >= 0 and drawY <= DASHBOARD_Y then
        return
    end

    local dx = (self.baseWorldX or BASE_WORLD_X) - self.player.x
    local dy = (self.baseWorldY or BASE_WORLD_Y) - self.player.y
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
        if missile.visual == "blast-collector" then
            gfx.drawCircleAtPoint(drawX, drawY, 4)
            gfx.drawLine(tailX, tailY, drawX, drawY)
        elseif missile.visual == "advanced-guided" then
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

function SpaceMiner:drawLootPackages()
    gfx.setColor(gfx.kColorWhite)
    for _, package in ipairs(self.lootPackages or {}) do
        local drawX, drawY = worldToScreen(self.player.x, self.player.y, package.x, package.y)
        if drawX >= -10 and drawX <= SCREEN_WIDTH + 10 and drawY >= -10 and drawY <= DASHBOARD_Y + 10 then
            if package.kind == "cash" then
                gfx.drawRect(drawX - 4, drawY - 3, 8, 6)
                gfx.drawLine(drawX - 2, drawY, drawX + 2, drawY)
            else
                gfx.drawRect(drawX - 5, drawY - 5, 10, 10)
                gfx.drawLine(drawX - 5, drawY - 5, drawX + 5, drawY + 5)
                gfx.drawLine(drawX + 5, drawY - 5, drawX - 5, drawY + 5)
            end
        end
    end
end

function SpaceMiner:drawLaser()
    if not self.player.laserOn then
        return
    end

    gfx.setColor(gfx.kColorWhite)
    local radians = math.rad(self.player.angle)
    local drawRange = clamp(self.playerLaserDrawRange or LASER_RANGE, 0, LASER_RANGE)
    local endX = CENTER_X + (math.cos(radians) * drawRange)
    local endY = CENTER_Y + (math.sin(radians) * drawRange)
    gfx.drawLine(CENTER_X, CENTER_Y, endX, endY)
    local upgrade = self:getActiveUpgrade("laser") or {}
    if upgrade.id == "advanced-laser" or upgrade.id == "standard-splaser" or upgrade.id == "advanced-splaser" or upgrade.id == "splaster-blaser" then
        local nx = math.cos(radians + math.pi * 0.5)
        local ny = math.sin(radians + math.pi * 0.5)
        gfx.drawLine(CENTER_X + nx, CENTER_Y + ny, endX + nx, endY + ny)
        gfx.drawLine(CENTER_X - nx, CENTER_Y - ny, endX - nx, endY - ny)
        if upgrade.id == "splaster-blaser" then
            gfx.drawLine(CENTER_X + nx * 2, CENTER_Y + ny * 2, endX + nx * 2, endY + ny * 2)
            gfx.drawLine(CENTER_X - nx * 2, CENTER_Y - ny * 2, endX - nx * 2, endY - ny * 2)
        end
    end
end

function SpaceMiner:drawLaserBeamCollection(collection, sourceAtPlayer)
    gfx.setColor(gfx.kColorWhite)
    local radians = math.rad(self.player.angle)
    local sideX = math.cos(radians + math.pi * 0.5)
    local sideY = math.sin(radians + math.pi * 0.5)
    for _, beam in ipairs(collection or {}) do
        local sourceX = beam.sourceX
        local sourceY = beam.sourceY
        if sourceAtPlayer then
            local side = ((beam.beamIndex or 1) - 2) * 6
            sourceX = self.player.x + sideX * side
            sourceY = self.player.y + sideY * side
        end
        local drawSourceX, drawSourceY = worldToScreen(self.player.x, self.player.y, sourceX, sourceY)
        local drawTargetX, drawTargetY = worldToScreen(self.player.x, self.player.y, beam.targetX, beam.targetY)
        gfx.drawLine(drawSourceX, drawSourceY, drawTargetX, drawTargetY)
        if (beam.beamIndex or 1) > 1 then
            gfx.drawLine(drawSourceX + 1, drawSourceY, drawTargetX + 1, drawTargetY)
        end
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
        if self:isOreMinerMode() then
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

function SpaceMiner:drawTurboBoostBar()
    local frames = self.rightTurboBoostFrames or 0
    if frames <= 0 then
        return
    end
    local ratio = clamp(frames / (30 * 5), 0, 1)
    local barHeight = 20
    local barY = DASHBOARD_Y - barHeight
    local fillWidth = math.floor(SCREEN_WIDTH * ratio + 0.5)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, barY, SCREEN_WIDTH, barHeight)
    if fillWidth < SCREEN_WIDTH then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(fillWidth, barY, SCREEN_WIDTH - fillWidth, barHeight)
    end
    gfx.setColor(gfx.kColorWhite)
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
    self:drawTurboBoostBar()

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
    gfx.drawTextInRect("Crank turns the ship. Up/Down thrust. Hold Left to mine. Right uses the selected ship action.", 58, 84, 284, 38, nil, nil, kTextAlignment.center)
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
    local function appendLine(lineText, bold)
        lines[#lines + 1] = {
            text = lineText,
            bold = bold == true
        }
    end

    local function appendWrapped(rawLine, bold)
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
                appendLine(current, bold)
                current = word
            end
        end
        if current ~= "" then
            if string.sub(current, -1) == ":" then
                error(string.format("Space Miner communication prefix cannot stand alone: %s", current))
            end
            appendLine(current, bold)
        end
    end

    local source = self:resolveCommunicationText(text)
    local prefix, remainder = source:match("^%s*([Ss]cout):%s*(.*)$")
    if prefix == nil then
        prefix, remainder = source:match("^%s*([Mm]ission):%s*(.*)$")
    end
    if prefix ~= nil then
        appendLine(prefix, true)
        source = remainder or ""
    end

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
        if #lines == 0 then
            appendLine("", false)
        end
    end
    if #lines > COMMUNICATION_MAX_LINES then
        error(string.format("Space Miner communication too long: %d lines exceeds %d", #lines, COMMUNICATION_MAX_LINES))
    end
    return lines
end

function SpaceMiner:resolveCommunicationText(text)
    local source = tostring(text or "")
    source = source:gsub("\\r\\n", "\n"):gsub("\\n", "\n")
    source = source:gsub("{{playerName}}", tostring(self.playerName or self.storySaveName or "Pilot"))
    source = source:gsub("{{saveName}}", tostring(self.storySaveName or self.playerName or "Save"))
    source = source:gsub("%$Name", tostring(self.storySaveName or self.playerName or "Save"))
    source = source:gsub("%$name", tostring(self.storySaveName or self.playerName or "Save"))
    return source
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
    local forceSolidHomeBaseMessage = self.menuOpen
        and self.menuType == "home"
        and self.homeMenuScreen ~= "apology"
        and message.text ~= nil
        and message.text == self.homeMenuMessage
    local ok, linesOrError = pcall(function()
        return self:wrapCommunicationText(message.text)
    end)
    local lines = ok and linesOrError or { "COMM TEXT ERROR", tostring(linesOrError or "") }
    if not ok and StarryLog and StarryLog.error then
        StarryLog.error("%s", tostring(linesOrError))
    end
    local promptHeight = message.blocking and 15 or 0
    local height = math.min(DASHBOARD_Y - y - 4, COMMUNICATION_BOX_PADDING + (#lines * COMMUNICATION_LINE_SPACING) + promptHeight)
    local backdropDither = message.backdropDither or 0.48
    if message.speedFade ~= nil then
        local speedFade = clamp(message.speedFade, 0, 1)
        backdropDither = backdropDither + ((1.0 - backdropDither) * speedFade)
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorBlack)
    if filled or forceSolidHomeBaseMessage then
        gfx.fillRoundRect(x - 2, y - 2, width + 4, height + 4, 5)
    else
        gfx.setDitherPattern(backdropDither, gfx.image.kDitherTypeBayer8x8)
        gfx.fillRoundRect(x - 2, y - 2, width + 4, height + 4, 5)
        gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    end
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(x, y, width, height, 4)
    gfx.drawLine(x + 6, y + 13, x + width - 6, y + 13)
    self:drawTinyConsoleText("SYS-COM", x + 7, y + 4)
    gfx.setDitherPattern(math.max(0.12, fade), gfx.image.kDitherTypeBayer8x8)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    for index, line in ipairs(lines) do
        local lineText = type(line) == "table" and line.text or tostring(line or "")
        local lineY = y + 18 + ((index - 1) * COMMUNICATION_LINE_SPACING)
        if lineY < y + height - 8 - promptHeight then
            gfx.drawText(lineText, x + 7, lineY)
            if type(line) == "table" and line.bold then
                gfx.drawText(lineText, x + 8, lineY)
            end
        end
    end
    if message.blocking then
        self:drawTinyConsoleText(string.format("%s TO CONTINUE", tostring(message.requiredButton or "A")), x + 7, y + height - 11)
    end
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function SpaceMiner:drawCommunication()
    local communication = self:getActiveCommunication()
    if communication == nil then
        return
    end
    communication.speedFade = self:getCommunicationSpeedFade()
    self:recordVisibleCommunication(communication)
    self:drawCommunicationBox(communication, false)
end

function SpaceMiner:getCommunicationSpeedFade()
    local speed = magnitude(self.player.vx or 0, self.player.vy or 0)
    local fadeStartSpeed = 1.8
    local fadeStopSpeed = 0.2
    if speed >= fadeStartSpeed then
        return 0
    end
    if speed <= fadeStopSpeed then
        return 1
    end
    return clamp((fadeStartSpeed - speed) / (fadeStartSpeed - fadeStopSpeed), 0, 1)
end

function SpaceMiner:drawHomeMenuScoutCommunication()
    if not (self.menuOpen and self.menuType == "home") or self.homeMenuScoutHidden or self.homeMenuScreen == "apology" or self.homeMenuScreen == "communications" then
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
        width = COMMUNICATION_WIDTH,
        backdropDither = HOME_MENU_SCOUT_BACKDROP_DITHER
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
    self:drawLootPackages()
    self:drawShip()
    self:drawMissiles()
    self:drawExplosions()
    self:drawLaser()
    self:drawLaserBeamCollection(self.baseLaserBeams, false)
    self:drawLaserBeamCollection(self.playerAutoLaserBeams, true)
    self:drawLaserBeamCollection(self.enemyLaserBeams, false)
    if self:isStoryMode() then
        self:drawAlert()
    end
    self:drawDecorLayer("front")
    self:drawMaterialMiniMap()
    self:drawCargoSpaceBar()
    self:drawHud()
    self:drawInstructionOverlay()
    if not self.preview and not self.titleStandby and (self:isStoryMode() or self:isOreMinerMode()) then
        self:drawCommunication()
    end
    self:drawMenuOverlay()
    self:drawMenu()
    self:drawHomeMenuScoutCommunication()
    self:drawStorySlotSelector()
    self:drawNameEntryPage()
    if (self.supernovaFlashFrames or 0) > 0 then
        gfx.setColor(gfx.kColorWhite)
        gfx.setDitherPattern(clamp(self.supernovaFlashFrames / 24, 0.1, 1), gfx.image.kDitherTypeBayer8x8)
        gfx.fillRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
        gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    end
end
