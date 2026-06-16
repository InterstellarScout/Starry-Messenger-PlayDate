--[[
Space Miner view config.

Purpose:
- keeps Space Miner tuning close to the wave manifest
- isolates the large Space Miner config from the app-wide defaults
]]

SpaceMinerConfig = {
    worldWrapRadius = 620,
    asteroidSafeRadius = 140,
    playerRadius = 8,
    decorWrapRadius = 720,
    playerThrust = 0.08,
    playerReverseThrust = 0.05,
    playerFullModeIdleDrag = 0.982,
    playerFullModeAutoStopSpeed = 0.18,
    enemyBaseAcceleration = 0.045,
    enemyEscaperAcceleration = 0.055,
    enemyStrikerAcceleration = 0.072,
    playerMaxSpeed = 3.8,
    enemyMaxSpeed = 3.2,
    laserRange = 170,
    laserWidth = 4,
    laserDamage = 0.34,
    laserEnemyPenetrationLimit = 4,
    communicationLineCharLimit = 22,
    communicationMaxLines = 8,
    missileSpeed = 4.4,
    missileDamage = 99,
    missileBlastRadius = 34,
    missileLifeFrames = 110,
    playerMissileDrawRadius = 5,
    playerMissileDrawLength = 10,
    maxActiveEntities = 72,
    targetAsteroidCount = 36,
    previewAsteroidCount = 16,
    decorItemCount = 190,
    backgroundStarsEnabled = true,
    backgroundGalaxyEnabled = true,
    backgroundStarCount = 120,
    backgroundGalaxyStarCount = 90,
    baseUnderAttackMessage = "Base under attack",
    mediumAsteroidTextureEnabled = true,
    mediumAsteroidGrayDither = 0.48,
    mediumAsteroidBlotchCountMin = 3,
    mediumAsteroidBlotchCountMax = 6,
    mediumAsteroidBlotchRadiusMin = 1,
    mediumAsteroidBlotchRadiusMax = 3,
    asteroidMaterials = {
        { id = "stone", label = "Stone", rarity = 70, cashPerTiny = 1, markOnMiniMap = false },
        { id = "iron", label = "Iron", rarity = 20, cashPerTiny = 3, markOnMiniMap = false },
        { id = "gold", label = "Gold", rarity = 7, cashPerTiny = 8, markOnMiniMap = true },
        { id = "iridium", label = "Iridium", rarity = 2, cashPerTiny = 18, markOnMiniMap = true },
        { id = "void", label = "Void Ore", rarity = 1, cashPerTiny = 45, markOnMiniMap = true }
    },
    asteroidSizeLayers = {
        { stage = 0, density = 1.25, quantity = 18 },
        { stage = 1, density = 1.1, quantity = 10 },
        { stage = 2, density = 0.95, quantity = 6 },
        { stage = 3, density = 0.8, quantity = 2 }
    },
    playerShieldMax = 100,
    playerHullHits = 10,
    shieldMax = 100,
    asteroidShieldDamage = 5,
    enemyShieldDamage = 10,
    shieldRechargeAmount = 5,
    hullHits = 10,
    shieldFlashFrames = 18,
    shieldRechargeDelayFrames = 150,
    shieldRechargeStepFrames = 90,
    base = {
        name = "Home Base",
        shapeMode = "international-space-station",
        shieldMax = 100,
        shieldDamage = 10,
        healthBarEnabled = true,
        proximityRadius = 44,
        largeAsteroidKm = 20,
        timeline = {
            { timestamp = "3:30:00", name = "Home Base", healthBarEnabled = true }
        }
    },
    playerProgression = {
        shieldUpgrades = {
            { level = 1, maxShield = 100, cost = 0 },
            { level = 2, maxShield = 125, cost = 250 },
            { level = 3, maxShield = 150, cost = 650 },
            { level = 4, maxShield = 200, cost = 1400 }
        }
    },
    enemyTypes = {
        seeker = { health = 3, size = 7, acceleration = 0.045, maxSpeed = 3.2, avoidAsteroids = true },
        escaper = { health = 2, size = 6, acceleration = 0.055, maxSpeed = 3.2, avoidAsteroids = true },
        striker = { health = 5, size = 8, acceleration = 0.072, maxSpeed = 3.2, avoidAsteroids = true, missileCooldown = 70 }
    },
    asteroidPruneProtectionFrames = 45,
    asteroidVisiblePruneGraceFrames = 120,
    asteroidDiagnosticsEnabled = true,
    asteroidDiagnosticIntervalFrames = 150,
    asteroidDiagnosticEventLimit = 6,
    alertGapFrames = 12,
    firstMiningStageFrames = 3600,
    intermissionStageFrames = 3600,
    strikerMissileCooldown = 70,
    waveEntrySpacing = "0:00:06"
}
