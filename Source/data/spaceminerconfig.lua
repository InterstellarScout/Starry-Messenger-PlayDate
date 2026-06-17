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
    communicationLineCharLimit = 26,
    communicationMaxLines = 8,
    communicationLineSpacing = 17,
    communicationBoxPadding = 34,
    communicationWidth = 238,
    communicationMinFrames = 90,
    communicationFramesPerChar = 2.2,
    missileSpeed = 4.4,
    missileDamage = 99,
    missileBlastRadius = 34,
    missileLifeFrames = 110,
    playerMissileDrawRadius = 5,
    playerMissileDrawLength = 10,
    cargoInitialCapacity = 50,
    cargoCapacityOreStep = 50,
    cargoCapacityIncrease = 10,
    cargoCapacityGrowRate = 0.04,
    cargoUnloadStepFrames = 4,
    homeBaseMenuRadius = 56,
    homeBaseMenuWidth = 374,
    entityLogIntervalFrames = 30,
    menuAutoNavigateEnabled = true,
    menuAutoNavigateRadius = 180,
    menuAutoNavigateAcceleration = 0.026,
    menuAutoNavigateMaxSpeed = 1.1,
    maxActiveEntities = 72,
    targetAsteroidCount = 36,
    previewAsteroidCount = 16,
    decorItemCount = 95,
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
        shieldRadius = 56,
        shieldAsteroidDamage = 6,
        shieldEnemyWeaponDamage = 28,
        shieldEnemyShipDamage = 18,
        shieldPlayerDockSuppressRadius = 56,
        shieldEnemyKeepAliveRadius = 190,
        healthBarEnabled = true,
        proximityRadius = 44,
        largeAsteroidKm = 20,
        timeline = {
            { timestamp = "3:30:00", name = "Home Base", healthBarEnabled = true }
        },
        homeBaseGreetings = {
            "Scout: Welcome home! I got some native wine from the Fallopian System to try.",
            "Scout: Have you seen any ancient artifacts out there? Maybe whoever simulated this reality will add that someday."
        },
        homeBaseEnemyAround = "Scout: What the hell are you doing here? Get back out there and save this place!",
        homeBaseAboveHalfHealth = "Scout: You're paying for that, right?",
        homeBaseBelowHalfHealth = "Scout: Hot damn! I hope cargo is full cause that damage isn't gonna be cheap!",
        homeBaseCriticalHealth = "Scout: How the hell are you still alive? The auto-repair modules have their job made!",
        ["base-collision-context"] = {
            "Scout: Hey! Don't scratch the paint!",
            "Scout: Getting a little close, aren't ya?",
            "Scout: Welcome home, but try to only touch the docking port, aye?"
        },
        ["destroyed-pc-quotes"] = {
            "Scout: See you in the afterlife, meh dude!",
            "Scout: Noooo!!! I'm gonna be so alone! Why did you program me like this!!",
            "Scout: Ahhhhh!!! I hope you escaped!",
            "Scout: Hello? Helllo!!!",
            "Scout: Shit! Glad we have insurance.",
            "Scout: You thought death was the end? Nope! You're a clone. Shocker.",
            "Scout: Let's try again. There's an end... probably, but it's not now!"
        }
    },
    playerProgression = {
        laserUpgrades = {
            { id = "standard-laser", name = "Standard Laser Cannon", maxEnemyHits = 2, dpsBonus = 0, cost = 0 },
            { id = "advanced-laser", name = "Advanced Laser Cannon", maxEnemyHits = 4, dpsBonus = 30, cost = 150 },
            { id = "standard-splaser", name = "Standard Splaser Cannon", maxEnemyHits = 6, dpsBonus = 40, cost = 300 },
            { id = "advanced-splaser", name = "Advanced Splaser Cannon", maxEnemyHits = 8, dpsBonus = 50, cost = 600 }
        },
        missileUpgrades = {
            { id = "standard-unguided", name = "Standard Unguided Missile", damageBonus = 0, cost = 0, manualDetonate = false, guided = false },
            { id = "advanced-unguided", name = "Advanced Unguided Missile", damageBonus = 200, cost = 300, manualDetonate = true, guided = false },
            { id = "standard-guided", name = "Standard Guided Missile", damageBonus = 300, cost = 600, manualDetonate = true, guided = "player" },
            { id = "advanced-guided", name = "Advanced Guided Missile", damageBonus = 400, cost = 1000, manualDetonate = true, guided = "auto" },
            { id = "firework", name = "Firework Missile", damageBonus = 260, cost = 800, manualDetonate = true, guided = false, survivesManualDetonation = true, maxManualDetonations = 5 },
            { id = "auto-launch", name = "Auto Missile Launch", damageBonus = 200, cost = 1000, shotCost = 5, autoLaunch = true }
        },
        shieldUpgrades = {
            { id = "standard-shields", name = "Standard Shields", damageReduction = 0, cost = 0 },
            { id = "photonic-emitters", name = "Photonic Emitters", damageReduction = 0.05, cost = 500 },
            { id = "rotating-frequency", name = "Rotating Frequency Shielding", damageReduction = 0.10, cost = 1000 },
            { id = "dyson-shielding", name = "Dyson Shielding", damageReduction = 0.20, cost = 2000 }
        },
        thrusterUpgrades = {
            { id = "standard-thrusters", name = "Standard Thrusters", accelerationBonus = 0, handlingBonus = 0, cost = 0 },
            { id = "lightening-rcs-v1", name = "Lightening RCS Thrusters V1", accelerationBonus = 0.10, handlingBonus = 0, cost = 100 },
            { id = "lightening-rcs-v2", name = "Lightening RCS Thrusters V2", accelerationBonus = 0.20, handlingBonus = 0, cost = 200 },
            { id = "nuclear-rcs", name = "Nuclear RCS Thrusters", accelerationBonus = 0.40, handlingBonus = 0, cost = 400 },
            { id = "anti-grav-drive", name = "Anti-Grav Drive", accelerationBonus = 0, handlingBonus = 0, blinkDistance = 400, cost = 5000 },
            { id = "experimental-anti-momentum", name = "Experimental Anti-Momentum Thrusters", accelerationBonus = 1.00, handlingBonus = 1.00, cost = 10000 }
        },
        cargoUpgrades = {
            { id = "cargo-50", name = "Cargo Bay 50", capacity = 50, cost = 0 },
            { id = "cargo-100", name = "Cargo Bay 100", capacity = 100, cost = 250 },
            { id = "cargo-150", name = "Cargo Bay 150", capacity = 150, cost = 500 },
            { id = "cargo-200", name = "Cargo Bay 200", capacity = 200, cost = 900 },
            { id = "cargo-250", name = "Cargo Bay 250", capacity = 250, cost = 1400 },
            { id = "cargo-300", name = "Cargo Bay 300", capacity = 300, cost = 2000 }
        }
    },
    enemyTypes = {
        seeker = { health = 3, size = 7, acceleration = 0.045, maxSpeed = 3.2, avoidAsteroids = true },
        escaper = { health = 2, size = 6, acceleration = 0.055, maxSpeed = 3.2, avoidAsteroids = true },
        striker = { health = 5, size = 8, acceleration = 0.072, maxSpeed = 3.2, avoidAsteroids = true, missileCooldown = 70 }
    },
    asteroidPruneProtectionFrames = 45,
    asteroidVisiblePruneGraceFrames = 120,
    asteroidDiagnosticsEnabled = false,
    asteroidDiagnosticIntervalFrames = 150,
    asteroidDiagnosticEventLimit = 6,
    alertGapFrames = 12,
    firstMiningStageFrames = 3600,
    intermissionStageFrames = 3600,
    strikerMissileCooldown = 70,
    waveEntrySpacing = "0:00:06"
}
