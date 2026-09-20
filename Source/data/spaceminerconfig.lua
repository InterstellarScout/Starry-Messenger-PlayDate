--[[
Space Miner view config.

Purpose:
- keeps Space Miner tuning close to the wave manifest
- isolates the large Space Miner config from the app-wide defaults
]]

SpaceMinerConfig = {
    -- worldWrapRadius: distance from center used by world wrap/spawn boundary checks in the Space Miner simulation loop.
    worldWrapRadius = 620,
    -- asteroidSafeRadius: minimum safe dock radius when evaluating asteroid spawn + movement near Home Base.
    asteroidSafeRadius = 140,
    -- playerRadius: collision radius used in asteroid/base/enemy hit checks for the player ship.
    playerRadius = 8,
    -- decorWrapRadius: offscreen cleanup buffer for decorative entities in the render/spawn loops.
    decorWrapRadius = 720,
    -- playerThrust: main forward acceleration applied when the player thrust input is active.
    playerThrust = 0.08,
    -- playerReverseThrust: reverse acceleration applied when thrusting backward in updatePlayerMotion.
    playerReverseThrust = 0.05,
    -- playerFullModeIdleDrag: drag multiplier used while coasting in full-mode movement.
    playerFullModeIdleDrag = 0.982,
    -- playerFullModeAutoStopSpeed: speed threshold used to auto-stop player drift in full-mode.
    playerFullModeAutoStopSpeed = 0.18,
    -- enemyBaseAcceleration: baseline acceleration shared by enemy ship movement toward targets.
    enemyBaseAcceleration = 0.045,
    -- enemyEscaperAcceleration: movement acceleration used by escaper enemy AI.
    enemyEscaperAcceleration = 0.055,
    -- enemyStrikerAcceleration: movement acceleration used by striker enemy AI.
    enemyStrikerAcceleration = 0.072,
    -- playerMaxSpeed: hard clamp on player velocity used in movement updates.
    playerMaxSpeed = 3.8,
    -- enemyMaxSpeed: hard clamp on enemy ship velocity in AI movement updates.
    enemyMaxSpeed = 3.2,
    -- laserRange: distance limit in draw/update checks for player laser beams.
    laserRange = 170,
    -- laserWidth: stroke width for player laser rendering and overlap/collision radius logic.
    laserWidth = 4,
    -- laserDamage: base damage per hit for player laser contacts.
    laserDamage = 0.34,
    -- laserEnemyPenetrationLimit: max enemy entities hit before laser despawn.
    laserEnemyPenetrationLimit = 4,
    -- communicationLineCharLimit: wraps communication text to avoid overflow in the comm panel.
    communicationLineCharLimit = 26,
    -- communicationMaxLines: max visible lines in active communication bubbles.
    communicationMaxLines = 8,
    -- communicationLineSpacing: pixel spacing between wrapped communication lines.
    communicationLineSpacing = 17,
    -- communicationBoxPadding: inner padding for message box rendering and layout.
    communicationBoxPadding = 34,
    -- communicationWidth: width of communication panel used by text layout.
    communicationWidth = 238,
    -- communicationMinFrames: minimum frames a message remains active regardless of queue state.
    communicationMinFrames = 90,
    -- communicationFramesPerChar: minimum frame budget per character for dialogue speed.
    communicationFramesPerChar = 2.2,
    -- homeMenuScoutBackdropDither: opacity-like blend for Scout backdrop graphics in home menu scenes.
    homeMenuScoutBackdropDither = 0.90,
    -- missileSpeed: update step speed for player-fired missiles.
    missileSpeed = 4.4,
    -- missileDamage: base impact damage value for missile hits.
    missileDamage = 99,
    -- missileBlastRadius: AoE radius for explosion checks when missile detonates.
    missileBlastRadius = 34,
    -- missileLifeFrames: lifetime cap for missiles before automatic removal.
    missileLifeFrames = 110,
    -- playerMissileDrawRadius: draw radius for missile sprite/head marker.
    playerMissileDrawRadius = 5,
    -- playerMissileDrawLength: visual trail/body length for missile rendering.
    playerMissileDrawLength = 10,
    -- cargoInitialCapacity: initial ore hold limit on new playthroughs.
    cargoInitialCapacity = 50,
    -- cargoCapacityOreStep: step size for random initial cargo composition / capacity growth logic.
    cargoCapacityOreStep = 50,
    -- cargoCapacityIncrease: per-level capacity added when using cargo upgrades.
    cargoCapacityIncrease = 10,
    -- cargoCapacityGrowRate: smoothing/increment rate when capacity scales with playtime/progress.
    cargoCapacityGrowRate = 0.04,
    -- cargoUnloadStepFrames: frame delay between ore unload ticks at home base.
    cargoUnloadStepFrames = 4,
    -- oreSalePriceMultiplier: scales ore cash payouts so home-base ore sales pay 60% more.
    oreSalePriceMultiplier = 1.6,
    -- upgradeCostMultiplier: scales all upgrade purchase prices so every upgrade costs 10% more.
    upgradeCostMultiplier = 1.1,
    -- homeBaseMenuRadius: radius for radial menu control hit area around home base.
    homeBaseMenuRadius = 56,
    -- entityLogIntervalFrames: cadence for entity debug logs when enabled.
    entityLogIntervalFrames = 30,
    -- menuAutoNavigateEnabled: enables automatic menu alignment when the ship is near home base.
    menuAutoNavigateEnabled = true,
    -- menuAutoNavigateRadius: radius where menu auto-navigation engages.
    menuAutoNavigateRadius = 180,
    -- menuAutoNavigateAcceleration: steering acceleration used by auto-nav behavior.
    menuAutoNavigateAcceleration = 0.026,
    -- menuAutoNavigateMaxSpeed: auto-nav speed clamp while snapping to menu controls.
    menuAutoNavigateMaxSpeed = 1.1,
    -- playerAutoLaserRange: range for auto-targeting laser checks when misc upgrade is active.
    playerAutoLaserRange = 150,
    -- playerAutoLaserDamage: damage value for auto-laser mode.
    playerAutoLaserDamage = 3,
    -- playerAutoLaserCooldownFrames: cooldown between auto-laser fires in frames.
    playerAutoLaserCooldownFrames = 12,
    -- baseMiningLaserRangeMultiplier: multiplier on normal range while docked to base and mining.
    baseMiningLaserRangeMultiplier = 2,
    -- baseMiningLaserCooldownFrames: mining-laser cooldown while docked.
    baseMiningLaserCooldownFrames = 18,
    -- baseMiningLaserAsteroidDamage: damage applied to asteroids by home-base mining laser.
    baseMiningLaserAsteroidDamage = 999,
    -- baseMiningLaserEnemyDamage: base damage dealt to enemies by docked mining laser.
    baseMiningLaserEnemyDamage = 2,
    -- baseMiningLaserEnemyDamageMultiplier: scaling for base mining laser damage against enemies.
    baseMiningLaserEnemyDamageMultiplier = 0.5,
    -- maxActiveEntities: global limit for active entity simulation budget.
    maxActiveEntities = 72,
    -- asteroidFragmentEntityLimit: cap for active asteroid fragments after explosion.
    asteroidFragmentEntityLimit = 90,
    -- asteroidLayerCollisionLimitPerFrame: collision pair limit for layer checks per frame.
    asteroidLayerCollisionLimitPerFrame = 6,
    -- targetAsteroidCount: desired active asteroid count outside mining sessions.
    targetAsteroidCount = 36,
    -- previewAsteroidCount: number of asteroids to render in non-active previews.
    previewAsteroidCount = 16,
    -- decorItemCount: quantity of background decorative objects in a play session.
    decorItemCount = 95,
    -- backgroundStarsEnabled: master toggle for background star particles in the Space Miner world.
    backgroundStarsEnabled = true,
    -- backgroundGalaxyEnabled: master toggle for galaxy layer rendering in the background.
    backgroundGalaxyEnabled = true,
    -- backgroundStarCount: number of standard star entities used in world background.
    backgroundStarCount = 120,
    -- backgroundGalaxyStarCount: number of stars used by galaxy-layer decoration.
    backgroundGalaxyStarCount = 90,
    -- baseUnderAttackMessage: short message when base HP drops while entering warning checks.
    baseUnderAttackMessage = "Base under attack",
    -- mediumAsteroidTextureEnabled: enables textured rendering path for medium asteroids.
    mediumAsteroidTextureEnabled = true,
    -- mediumAsteroidGrayDither: greyscale jitter for medium asteroid shader variation.
    mediumAsteroidGrayDither = 0.48,
    -- mediumAsteroidBlotchCountMin: minimum blotch count when generating medium asteroid texture.
    mediumAsteroidBlotchCountMin = 3,
    -- mediumAsteroidBlotchCountMax: maximum blotch count when generating medium asteroid texture.
    mediumAsteroidBlotchCountMax = 6,
    -- mediumAsteroidBlotchRadiusMin: min blob radius for medium texture variation.
    mediumAsteroidBlotchRadiusMin = 1,
    -- mediumAsteroidBlotchRadiusMax: max blob radius for medium texture variation.
    mediumAsteroidBlotchRadiusMax = 3,
    -- asteroidMaterials: material catalog used for ore spawn, payouts, minimap markers and ore settings menus.
    asteroidMaterials = {
        -- id: canonical material token used by asteroid spawn/equipment sale code.
        -- label: user-facing display name in resource and upgrade menus.
        -- rarity: weight used by material sampler in asteroid spawn setup.
        -- cashPerTiny: per-unit value in ore sale conversion.
        -- markOnMiniMap: shows this material on minimap when true.
        { id = "stone", label = "Stone", rarity = 70, cashPerTiny = 2, markOnMiniMap = false },
        { id = "iron", label = "Iron", rarity = 20, cashPerTiny = 5, markOnMiniMap = false },
        { id = "gold", label = "Gold", rarity = 7, cashPerTiny = 13, markOnMiniMap = true },
        { id = "iridium", label = "Iridium", rarity = 2, cashPerTiny = 29, markOnMiniMap = true },
        { id = "void", label = "Void Ore", rarity = 1, cashPerTiny = 72, markOnMiniMap = true }
    },
    -- asteroidSizeLayers: density and quantity profile for spawned asteroids by size stage.
    asteroidSizeLayers = {
        { stage = 0, density = 1.25, quantity = 18 },
        { stage = 1, density = 1.1, quantity = 10 },
        { stage = 2, density = 0.95, quantity = 6 },
        { stage = 3, density = 0.8, quantity = 2 }
    },
    -- playerShieldMax: maximum shield value for the player ship.
    playerShieldMax = 100,
    -- playerHullHits: hull hit points for the player ship.
    playerHullHits = 10,
    -- shieldMax: defensive cap for base/other entities that use shield logic.
    shieldMax = 100,
    -- asteroidShieldDamage: damage per asteroid collision against shields.
    asteroidShieldDamage = 5,
    -- enemyShieldDamage: damage per enemy hit against shields.
    enemyShieldDamage = 10,
    -- shieldRechargeAmount: per-step amount restored during shield recharge cycles.
    shieldRechargeAmount = 5,
    -- hullHits: standard hull hit capacity for generic entities.
    hullHits = 10,
    -- shieldFlashFrames: flicker duration for shield hit feedback.
    shieldFlashFrames = 18,
    -- shieldRechargeDelayFrames: delay between last damage and recharge start.
    shieldRechargeDelayFrames = 150,
    -- shieldRechargeStepFrames: interval between shield recharge ticks.
    shieldRechargeStepFrames = 90,
    -- base: aggregate configuration for home base behavior, HP, shield, and messaging.
    base = {
        -- name: label used in home base communication/title UI.
        name = "Home Base",
        -- mode: starting base entity mode id resolved through modes below.
        mode = "home-base",
        -- modeTransitionFrames: duration for base mode visual crossfades at 30 FPS.
        modeTransitionFrames = 60,
        -- modes: named base entity modes for Ship Mode transitions and visuals.
        modes = {
            ["home-base"] = {
                name = "Home Base",
                shapeMode = "international-space-station"
            },
            ["the-watcher"] = {
                name = "The Watcher",
                shapeMode = "the-watcher",
                imagePath = "images/TheWatcher",
                mobile = true
            }
        },
        -- shapeMode: visual style key for base rendering and shield shape calculations.
        shapeMode = "international-space-station",
        -- shieldMax: maximum shield value for the base.
        shieldMax = 100,
        -- shieldDamage: damage reduction factor used by base shield event logic.
        shieldDamage = 10,
        -- shieldRadius: collision and effect radius for base shield ring.
        shieldRadius = 56,
        -- shieldAsteroidDamage: base shield damage per asteroid impact.
        shieldAsteroidDamage = 6,
        -- shieldEnemyWeaponDamage: shield mitigation when enemy weapons hit base.
        shieldEnemyWeaponDamage = 28,
        -- shieldEnemyShipDamage: shield mitigation when enemy ships collide with base.
        shieldEnemyShipDamage = 18,
        -- shieldPlayerDockSuppressRadius: range where player docking affects base shield behavior.
        shieldPlayerDockSuppressRadius = 56,
        -- shieldEnemyKeepAliveRadius: keep-alive distance to keep some enemy AI around base.
        shieldEnemyKeepAliveRadius = 190,
        -- healthBarEnabled: toggles base health bar draw in home base HUD.
        healthBarEnabled = true,
        -- proximityRadius: range used for base proximity detection for menu/state transitions.
        proximityRadius = 44,
        -- largeAsteroidKm: threshold for marking very large asteroids near base.
        largeAsteroidKm = 20,
        -- timeline: scripted timeline entries for base campaign messaging/state.
        timeline = {
            { timestamp = "3:30:00", action = "Ship Mode", mode = "home-base", healthBarEnabled = true }
        },
        -- homeBaseGreetings: intro lines shown on successful dock.
        homeBaseGreetings = {
            "Scout: Welcome home! I got some native wine from the Fallopian System to try.",
            "Scout: Have you seen any ancient artifacts out there? Maybe whoever simulated this reality will add that someday."
        },
        -- base warning and greeting text blocks used by Base state checks and collision comms.
        homeBaseEnemyAround = "Scout: What the hell are you doing here? Get back out there and save this place!",
        -- selfDefenseSuppressesDockingComplaints: when the auto-mining-lasers turret is owned or active, suppress the old "clear the area" and "get back out there" complaints, including cases where the auto-mining beams clip the base while the ship can defend itself.
        selfDefenseSuppressesDockingComplaints = true,
        homeBaseAboveHalfHealth = "Scout: You're paying for that, right?",
        homeBaseBelowHalfHealth = "Scout: Hot damn! I hope cargo is full cause that damage isn't gonna be cheap!",
        homeBaseCriticalHealth = "Scout: How the hell are you still alive? The auto-repair modules have their job made!",
        baseMiningLaserDockedQuotes = {
            "Scout: I got it.",
            "Scout: You have lasers too, right?",
            "Scout: Next time clear the area before docking, aye? These upgrades don't build themselves."
        },
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
    -- playerProgression: all upgrade trees for ship/base and associated numeric costs/bonuses.
    playerProgression = {
        -- laserUpgrades: player primary weapon upgrade path keyed by id.
        laserUpgrades = {
            -- id: upgrade token used for persistence and UI selection.
            -- name: label used in ship settings menus.
            -- maxEnemyHits: hit count cap each laser shot can apply.
            -- dpsBonus: % style DPS modifier shown in progression math.
            -- cost: purchase cost deducted from player cash.
            { id = "standard-laser", name = "Standard Laser Cannon", maxEnemyHits = 2, penetrationPower = 1, dpsBonus = 0, cost = 0 },
            { id = "advanced-laser", name = "Advanced Laser Cannon", maxEnemyHits = 4, penetrationPower = 2, dpsBonus = 30, cost = 165 },
            { id = "standard-splaser", name = "Standard Splaser Cannon", maxEnemyHits = 6, penetrationPower = 4, dpsBonus = 40, cost = 330 },
            { id = "advanced-splaser", name = "Advanced Splaser Cannon", maxEnemyHits = 8, penetrationPower = 6, dpsBonus = 50, cost = 660 },
            { id = "splaster-blaser", name = "Splaster Blaser", maxEnemyHits = 999, penetrationPower = 999, dpsBonus = 100, cost = 1320 }
        },
        -- missileUpgrades: missile-type upgrades referenced by missile fire and detonation handlers.
        missileUpgrades = {
            { id = "standard-unguided", name = "Standard Unguided Missile", damageBonus = 0, cost = 0, manualDetonate = false, guided = false },
            { id = "advanced-unguided", name = "Advanced Unguided Missile", damageBonus = 200, cost = 330, manualDetonate = true, guided = false },
            { id = "standard-guided", name = "Standard Guided Missile", damageBonus = 300, cost = 660, manualDetonate = true, guided = "player" },
            { id = "advanced-guided", name = "Advanced Guided Missile", damageBonus = 400, cost = 1100, manualDetonate = true, guided = "auto" },
            { id = "blast-collector", name = "Blast Collector Missile", damageBonus = 9999, cost = 1760, manualDetonate = true, guided = "auto", blastCollector = true },
            { id = "firework", name = "Firework Missile", damageBonus = 260, cost = 880, manualDetonate = true, guided = false, survivesManualDetonation = true, maxManualDetonations = 5 },
            { id = "auto-launch", name = "Auto Missile Launch", damageBonus = 200, cost = 1100, shotCost = 5, autoLaunch = true }
        },
        -- shieldUpgrades: base values used by shield resistance modifiers.
        shieldUpgrades = {
            { id = "standard-shields", name = "Standard Shields", damageReduction = 0, cost = 0 },
            { id = "photonic-emitters", name = "Photonic Emitters", damageReduction = 0.05, cost = 550 },
            { id = "rotating-frequency", name = "Rotating Frequency Shielding", damageReduction = 0.10, cost = 1100 },
            { id = "dyson-shielding", name = "Dyson Shielding", damageReduction = 0.20, cost = 2200 }
        },
        -- thrusterUpgrades: movement tuning bonuses used in acceleration/handling calculations.
        thrusterUpgrades = {
            { id = "standard-thrusters", name = "Standard Thrusters", accelerationBonus = 0, handlingBonus = 0, cost = 0 },
            { id = "lightening-rcs-v1", name = "Lightening RCS Thrusters V1", accelerationBonus = 0.10, handlingBonus = 0, cost = 110 },
            { id = "lightening-rcs-v2", name = "Lightening RCS Thrusters V2", accelerationBonus = 0.20, handlingBonus = 0, cost = 220 },
            { id = "nuclear-rcs", name = "Nuclear RCS Thrusters", accelerationBonus = 0.40, handlingBonus = 0, cost = 440 },
            { id = "anti-grav-drive", name = "Anti-Grav Drive", accelerationBonus = 0, handlingBonus = 0, blinkDistance = 400, cost = 5500 },
            { id = "advanced-maneuvering-thrusters", name = "Advanced Maneuvering Thrusters", accelerationBonus = 0.25, handlingBonus = 0.25, cost = 8800 },
            { id = "experimental-anti-momentum", name = "Experimental Anti-Momentum Thrusters", accelerationBonus = 1.00, handlingBonus = 1.00, cost = 11000 }
        },
        -- cargoUpgrades: cargo size values used by mining hold capacities.
        cargoUpgrades = {
            { id = "cargo-50", name = "Cargo Bay 50", capacity = 50, cost = 0 },
            { id = "cargo-100", name = "Cargo Bay 100", capacity = 100, cost = 275 },
            { id = "cargo-150", name = "Cargo Bay 150", capacity = 150, cost = 550 },
            { id = "cargo-200", name = "Cargo Bay 200", capacity = 200, cost = 990 },
            { id = "cargo-250", name = "Cargo Bay 250", capacity = 250, cost = 1540 },
            { id = "cargo-300", name = "Cargo Bay 300", capacity = 300, cost = 2200 }
        },
        -- miscUpgrades: utility upgrades affecting automation and special behaviors.
        miscUpgrades = {
            { id = "no-misc", name = "No Misc Upgrade", cost = 0 },
            { id = "tractor-beam-v1", name = "Tractor Beam V1", cost = 1320, tractorRadius = 100, tractorPull = 0.18 },
            { id = "tractor-beam-v2", name = "Tractor Beam V2", cost = 2640, tractorRadius = 200, tractorPull = 0.24 },
            { id = "tractor-beam-v3", name = "Tractor Beam V3", cost = 5280, tractorRadius = 400, tractorPull = 0.30 },
            { id = "auto-mining-lasers", name = "Automatic Mining Lasers", cost = 11000, beams = 3 }
        },
        -- baseUpgrades: home base upgrades affecting shield regen, repair, weaponry and counters.
        baseUpgrades = {
            { id = "base-standard", name = "Standard Base Systems", cost = 0 },
            { id = "base-shield-recharge-v1", name = "Base Shield Recharge V1", cost = 825, shieldRechargeBonus = 2 },
            { id = "base-shield-recharge-v2", name = "Base Shield Recharge V2", cost = 1650, shieldRechargeBonus = 5 },
            { id = "base-auto-repair-v1", name = "Base Auto-Repair V1", cost = 1320, shipShieldRepairBonus = 0.05, hullRepairStepReduction = 8 },
            { id = "base-auto-repair-v2", name = "Base Auto-Repair V2", cost = 2640, shipShieldRepairBonus = 0.10, hullRepairStepReduction = 14 },
            { id = "base-enemy-laser-tuning", name = "Base Enemy Laser Tuning", cost = 1650, enemyDamageMultiplier = 0.75 },
            { id = "base-enemy-laser-overdrive", name = "Base Enemy Laser Overdrive", cost = 3300, enemyDamageMultiplier = 1.0 },
            { id = "base-shielded-defense", name = "Shielded Base Defense", cost = 2750, fireWithShieldUp = true },
            { id = "base-laser-array-2", name = "Base Laser Array 2", cost = 2420, laserCount = 2 },
            { id = "base-laser-array-3", name = "Base Laser Array 3", cost = 4620, laserCount = 3 }
        }
    },
    -- enemyTypes: base stats for enemy subclasses used during wave spawning and AI updates.
    enemyTypes = {
        -- seeker: close-range attacker config (health/size/accel/speed/AIs)
        seeker = { health = 3, size = 7, acceleration = 0.045, maxSpeed = 3.2, avoidAsteroids = true },
        -- escaper: evasive enemy config used by enemy AI update branches.
        escaper = { health = 2, size = 6, acceleration = 0.055, maxSpeed = 3.2, avoidAsteroids = true },
        -- striker: ranged attacker config with missile cooldown, max speed, and offscreen player engagement range.
        striker = { health = 5, size = 8, acceleration = 0.072, maxSpeed = 3.2, avoidAsteroids = true, missileCooldown = 70, playerAttackRange = 520, baseAttackRange = 220 },
        -- laserEnemy: harder orbiting enemy that holds a fixed laser standoff around the target and fires sustained beams.
        -- health: hits to destroy before the ship drops.
        -- size: collision radius used by beam and body hits.
        -- acceleration: steering responsiveness while it keeps orbit.
        -- maxSpeed: top travel speed while circling a target.
        -- avoidAsteroids: whether the AI nudges away from asteroid fields.
        -- laserRange: preferred orbit distance while it attacks.
        -- playerAttackRange: max player-target distance where offscreen beams can still fire.
        -- baseAttackRange: max base-target distance where beams can still fire.
        -- laserCooldown: frames between beam bursts once it is at range.
        -- laserDamage: number of damage applications per beam burst.
        -- orbitSpeed: angular drift used to keep the ship moving around the target.
        laserEnemy = {
            health = 8,
            size = 8,
            acceleration = 0.058,
            maxSpeed = 3.1,
            avoidAsteroids = true,
            laserRange = 152,
            playerAttackRange = 520,
            baseAttackRange = 190,
            laserCooldown = 52,
            laserDamage = 1,
            orbitSpeed = 0.045
        }
    },
    -- asteroidPruneProtectionFrames: grace period before spawned asteroids are eligible for prune.
    asteroidPruneProtectionFrames = 45,
    -- asteroidVisiblePruneGraceFrames: visible-only grace before forced despawn from view.
    asteroidVisiblePruneGraceFrames = 120,
    -- asteroidDiagnosticsEnabled: master switch for asteroids debug diagnostics in save logs.
    asteroidDiagnosticsEnabled = false,
    -- asteroidDiagnosticIntervalFrames: cadence for asteroids diagnostic sampling.
    asteroidDiagnosticIntervalFrames = 150,
    -- asteroidDiagnosticEventLimit: max diagnostics emitted per active session.
    asteroidDiagnosticEventLimit = 6,
    -- alertGapFrames: cooldown between repeated alert messages from base/enemy events.
    alertGapFrames = 12,
    -- firstMiningStageFrames: length of first mining stage in wave schedule-based game modes.
    firstMiningStageFrames = 3600,
    -- intermissionStageFrames: length of idle/intermission stage before next stage logic.
    intermissionStageFrames = 3600,
    -- strikerMissileCooldown: baseline cooldown for striker enemy firing timer.
    strikerMissileCooldown = 70,
    -- waveEntrySpacing: duration gap string parsed into wave stage delay.
    waveEntrySpacing = "0:00:06",
}
