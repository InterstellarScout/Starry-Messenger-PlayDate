import "gameconfig"
import "systems/multiplayer"
import "systems/tutorials"
import "systems/pixelplanets"

--[[
Orbital Defense scene.

Purpose:
- runs the single-player and multiplayer shield-defense gameplay
- tracks player turrets, enemy ships, lasers, missiles, and defense health
- synchronizes host/client state for pdportal multiplayer sessions
]]
local pd <const> = playdate
local gfx <const> = pd.graphics
local ORBITAL_CONFIG <const> = GameConfig and GameConfig.orbitalDefense or {}

local SCREEN_WIDTH <const> = ORBITAL_CONFIG.screenWidth or 400
local PLANET_X <const> = ORBITAL_CONFIG.planetX or 200
local PLANET_Y <const> = ORBITAL_CONFIG.planetY or 186
local PLANET_RADIUS <const> = ORBITAL_CONFIG.planetRadius or 38
local RING_RADIUS <const> = ORBITAL_CONFIG.ringRadius or 84
local MIN_DISTANCE <const> = ORBITAL_CONFIG.minDistance or 92
local MAX_DISTANCE <const> = ORBITAL_CONFIG.maxDistance or 130
local DEFAULT_DISTANCE <const> = ORBITAL_CONFIG.defaultDistance or 106
local PLAYER_AIM_SPEED <const> = ORBITAL_CONFIG.playerAimSpeed or 3.4
local PLAYER_ORBIT_SPEED <const> = ORBITAL_CONFIG.playerOrbitSpeed or 1.6
local AI_AIM_SPEED <const> = ORBITAL_CONFIG.aiAimSpeed or 2.8
local LASER_RANGE <const> = ORBITAL_CONFIG.laserRange or 190
local LASER_WIDTH <const> = ORBITAL_CONFIG.laserWidth or 4
local LASER_DAMAGE <const> = ORBITAL_CONFIG.laserDamage or 0.34
local LASER_DAMAGE_PER_LEVEL <const> = ORBITAL_CONFIG.laserDamagePerLevel or 0.18
local MISSILE_SPEED <const> = ORBITAL_CONFIG.missileSpeed or 3.8
local MISSILE_DAMAGE <const> = ORBITAL_CONFIG.missileDamage or 6
local MISSILE_BLAST_RADIUS <const> = ORBITAL_CONFIG.missileBlastRadius or 18
local MISSILE_BLAST_RADIUS_PER_LEVEL <const> = ORBITAL_CONFIG.missileBlastRadiusPerLevel or 4
local MISSILE_LIFE_FRAMES <const> = ORBITAL_CONFIG.missileLifeFrames or 90
local WEAPON_UPGRADE_COST <const> = ORBITAL_CONFIG.weaponUpgradeCost or 5
local ENEMY_BASE_SPEED <const> = ORBITAL_CONFIG.enemyBaseSpeed or 0.58
local ENEMY_SPAWN_FRAMES <const> = ORBITAL_CONFIG.enemySpawnFrames or 16
local EARTH_MAX_HEALTH <const> = ORBITAL_CONFIG.earthMaxHealth or 100
local SHIELD_MAX_HEALTH <const> = ORBITAL_CONFIG.shieldMaxHealth or 80
local MATCH_DURATION_FRAMES <const> = ORBITAL_CONFIG.matchDurationFrames or (30 * 90)
local SNAPSHOT_INTERVAL_FRAMES <const> = ORBITAL_CONFIG.snapshotIntervalFrames or 3
local LOCAL_IDLE_TIMEOUT_FRAMES <const> = ORBITAL_CONFIG.localIdleTimeoutFrames or (30 * 5)
local LOCAL_IDLE_CRANK_THRESHOLD <const> = ORBITAL_CONFIG.localIdleCrankThreshold or 0.5
local ENDLESS_TIER_FRAMES <const> = 30 * 30
local PLANNED_TIER_COUNT <const> = 6
local RESULTS_SAVE_KEY <const> = "orbital-defense-results-v1"
local cachedResults = nil

local PLAYER_ANCHORS <const> = {
    [1] = { orbitAngle = -60, defaultAngle = 18, label = "P1" },
    [2] = { orbitAngle = -20, defaultAngle = -12, label = "P2" },
    [3] = { orbitAngle = 20, defaultAngle = 12, label = "P3" },
    [4] = { orbitAngle = 60, defaultAngle = -18, label = "P4" }
}

local SINGLE_PLAYER_LOCAL_ANCHOR <const> = { orbitAngle = -120, defaultAngle = 162 }
local SINGLE_PLAYER_BOT_ANCHOR <const> = { orbitAngle = -60, defaultAngle = 18 }

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function normalizeAngle(angle)
    local normalized = angle % 360
    if normalized >= 180 then
        normalized = normalized - 360
    end
    return normalized
end

local function angleDelta(a, b)
    return normalizeAngle(a - b)
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

local function copyArray(source)
    local copy = {}
    for index, value in ipairs(source) do
        copy[index] = value
    end
    return copy
end

local function randomSign()
    return math.random() < 0.5 and -1 or 1
end

local function loadResults()
    if cachedResults ~= nil then
        return cachedResults
    end
    if pd.datastore and pd.datastore.read then
        local saved = pd.datastore.read(RESULTS_SAVE_KEY)
        if type(saved) == "table" then
            cachedResults = saved
            return saved
        end
    end
    cachedResults = { highScore = 0 }
    return cachedResults
end

local function saveResults(results)
    cachedResults = results
    if pd.datastore and pd.datastore.write then
        pd.datastore.write(results, RESULTS_SAVE_KEY)
    end
end

-- Keep the distant field deliberately quiet.  The defense ring, elevator,
-- and weapons are the visual focus; clustered stars read as foreground noise.
local ORBITAL_BACKGROUND_STAR_COUNT <const> = ORBITAL_CONFIG.backgroundStarCount or 86

local function makeOrbitalBackgroundStar(size, x, y, kind, extra)
    return {
        x = x,
        y = y,
        size = size,
        kind = kind or "star",
        extra = extra
    }
end

local function createOrbitalBackgroundStars()
    local stars = {}
    local function addStar(x, y, size, kind, extra)
        stars[#stars + 1] = makeOrbitalBackgroundStar(size, x, y, kind, extra)
    end

    for _ = 1, ORBITAL_BACKGROUND_STAR_COUNT do
        local depth = math.random()
        local size = depth < 0.94 and 1 or 2
        addStar(
            math.random(2, SCREEN_WIDTH - 2),
            math.random(2, 208),
            size,
            "star"
        )
    end

    return stars
end

local function drawOrbitalBackgroundStars(stars)
    gfx.setColor(gfx.kColorWhite)
    for _, star in ipairs(stars or {}) do
        local size = star.size or 1
        if size >= 2 then
            gfx.drawRect(star.x, star.y, size, size)
        else
            gfx.fillRect(star.x, star.y, 1, 1)
        end
    end
end

OrbitalDefenseScene = {}
OrbitalDefenseScene.__index = OrbitalDefenseScene

function OrbitalDefenseScene.new(config)
    local self = setmetatable({}, OrbitalDefenseScene)
    self.onReturnToTitle = config.onReturnToTitle
    self.preview = config.preview == true
    self.tutorialOpen = not self.preview and Tutorials.shouldShow("orbital", config.multiplayer and "multi" or "single")
    self.tutorialScroll = 0
    self.multiplayer = config.multiplayer == true
    self.portalService = config.portalService
    self.networked = self.multiplayer and self.portalService ~= nil
    self.playerCount = self.multiplayer and MultiplayerConfig.clampPlayerCount(config.playerCount, 2, 4, 2) or 1
    self.localSlot = 1
    self.players = {}
    self.enemies = {}
    self.explosions = {}
    self.backgroundStars = createOrbitalBackgroundStars()
    self.frame = 0
    self.spawnTimer = ENEMY_SPAWN_FRAMES
    self.earthHealth = EARTH_MAX_HEALTH
    self.ringHealth = SHIELD_MAX_HEALTH
    self.remainingFrames = MATCH_DURATION_FRAMES
    self.elapsedFrames = 0
    self.gameOver = false
    self.mode = self.networked and "lobby" or "game"
    self.remoteState = nil
    self.statusMessage = self.networked and "Open pdportal in the browser and connect the selected beings." or "Single-player orbital defense."
    self.smallFont = gfx.getSystemFont()
    self.lastSentAngle = 0
    self.lastSentOrbitAngle = PLAYER_ANCHORS[1].orbitAngle
    self.lastSentLaser = false
    self.localIdleFrames = 0
    self.menuOpen = false
    self.menuIndex = 1
    self.menuStatusMessage = nil
    self.menuStatusFrames = 0

    if self.preview then
        self:resetMatch(self.multiplayer and "networked" or "single", 1)
    elseif not self.networked then
        self:resetMatch("single", 1)
    end
    return self
end

function OrbitalDefenseScene:activate()
    if self.preview then
        return
    end

    if self.networked then
        self.portalService:beginLobby("orbital", self.playerCount, self)
        self.statusMessage = "Open pdportal in the browser and connect the selected beings."
    end
end

function OrbitalDefenseScene:shutdown()
    if self.networked and self.portalService ~= nil then
        self.portalService:endSession()
    end
end

function OrbitalDefenseScene:onPortalStatusChanged()
    if not self.networked then
        return
    end

    if not self.portalService.isSerialConnected then
        self.statusMessage = "Serial disconnected. Open pdportal and connect USB."
    elseif not self.portalService.isPeerOpen then
        self.statusMessage = "Serial live. Waiting for peer handshake."
    elseif self.mode == "lobby" and self.portalService:isHost() then
        self.statusMessage = string.format("Host ready. %d/%d beings connected.", self.portalService:getConnectedCount(), self.playerCount)
    elseif self.mode == "lobby" then
        self.statusMessage = "Connected to host. Waiting for launch."
    end
end

function OrbitalDefenseScene:onPortalDisconnected()
    self.mode = "lobby"
    self.remoteState = nil
    self.statusMessage = "pdportal disconnected."
end

function OrbitalDefenseScene:onPortalPeerAssigned(_remotePeerId, slot)
    self.statusMessage = "Being " .. tostring(slot) .. " joined the defense."
end

function OrbitalDefenseScene:onPortalPeerDisconnected(_remotePeerId, slot)
    self.mode = "lobby"
    self.remoteState = nil
    self.statusMessage = "Being " .. tostring(slot) .. " disconnected."
end

function OrbitalDefenseScene:onPortalHostDisconnected(_remotePeerId)
    self.mode = "lobby"
    self.remoteState = nil
    self.statusMessage = "Host disconnected."
end

function OrbitalDefenseScene:onPortalMessage(remotePeerId, message)
    if message.type == "assigned" then
        self.localSlot = self.portalService:getAssignedSlot()
        self.statusMessage = "Joined as " .. PLAYER_ANCHORS[self.localSlot].label .. ". Waiting for host."
    elseif message.type == "lobby" then
        self.localSlot = self.portalService:getAssignedSlot()
        self.statusMessage = string.format("Lobby synced. %d/%d beings ready.", self.portalService:getConnectedCount(), self.playerCount)
    elseif message.type == "full" then
        self.statusMessage = "That defense ring is already full."
    elseif (message.type == "start" or message.type == "snapshot") and self.portalService:isClient() then
        self.remoteState = message.state
        self.mode = "game"
        self.gameOver = message.state and message.state.gameOver == true
    elseif message.type == "input" and self.portalService:isHost() then
        local slot = self.portalService:getSlotForPeer(remotePeerId)
        local player = slot and self.players[slot] or nil
        if player ~= nil then
            player.angle = normalizeAngle(tonumber(message.angle) or player.angle)
            player.orbitAngle = normalizeAngle(tonumber(message.orbitAngle) or player.orbitAngle or PLAYER_ANCHORS[slot].orbitAngle)
            player.laserOn = message.laser == true
            if message.missile == true then
                player.pendingMissileTrigger = true
            end
        end
    end
end

function OrbitalDefenseScene:resetMatch(modeId, localSlot)
    self.players = {}
    self.enemies = {}
    self.explosions = {}
    self.frame = 0
    self.spawnTimer = ENEMY_SPAWN_FRAMES
    self.earthHealth = EARTH_MAX_HEALTH
    self.ringHealth = SHIELD_MAX_HEALTH
    self.remainingFrames = MATCH_DURATION_FRAMES
    self.elapsedFrames = 0
    self.gameOver = false
    self.resultsRecorded = false
    self.matchResults = nil
    self.localSlot = localSlot or 1
    self.localIdleFrames = 0

    local activeCount = modeId == "single" and 2 or self.playerCount
    for index = 1, activeCount do
        local anchor = PLAYER_ANCHORS[index]
        local controlKind = "remote"
        if modeId == "single" then
            controlKind = index == self.localSlot and "local" or "bot"
            if controlKind == "local" then
                anchor = SINGLE_PLAYER_LOCAL_ANCHOR
            else
                anchor = SINGLE_PLAYER_BOT_ANCHOR
            end
        elseif index == self.localSlot then
            controlKind = "local"
        end
        self.players[index] = {
            id = index,
            angle = anchor.defaultAngle,
            orbitAngle = anchor.orbitAngle,
            distance = DEFAULT_DISTANCE,
            laserOn = false,
            missile = nil,
            pendingMissileTrigger = false,
            controlKind = controlKind,
            score = 0,
            kills = 0,
            laserLevel = 1,
            missileLevel = 1
        }
    end

    local localPlayer = self.players[self.localSlot]
    if localPlayer ~= nil then
        self.lastSentAngle = localPlayer.angle
        self.lastSentOrbitAngle = localPlayer.orbitAngle
        self.lastSentLaser = localPlayer.laserOn
    end
end

function OrbitalDefenseScene:startHostMatch()
    self.mode = "game"
    self.remoteState = nil
    self:resetMatch("networked", 1)
    self.portalService:broadcast({
        type = "start",
        state = self:serializeState()
    })
    self.statusMessage = "Host defense running."
end

function OrbitalDefenseScene:getPlayerOrigin(index, player)
    local anchor = PLAYER_ANCHORS[index]
    -- Players now slide around the defense ring instead of moving radially inward and outward.
    local orbitAngle = player.orbitAngle or anchor.orbitAngle
    local radians = math.rad(orbitAngle)
    local x = PLANET_X + (math.cos(radians) * DEFAULT_DISTANCE)
    local y = PLANET_Y + (math.sin(radians) * DEFAULT_DISTANCE)
    return x, y
end

function OrbitalDefenseScene:getLaserDamage(player)
    local level = math.max(1, tonumber(player and player.laserLevel) or 1)
    return LASER_DAMAGE + ((level - 1) * LASER_DAMAGE_PER_LEVEL)
end

function OrbitalDefenseScene:getMissileBlastRadius(player)
    local level = math.max(1, tonumber(player and player.missileLevel) or 1)
    return MISSILE_BLAST_RADIUS + ((level - 1) * MISSILE_BLAST_RADIUS_PER_LEVEL)
end

function OrbitalDefenseScene:getUpgradeMenuItems()
    local player = self.players[self.localSlot]
    if player == nil then
        return {}
    end

    local laserLevel = math.max(1, tonumber(player.laserLevel) or 1)
    local missileLevel = math.max(1, tonumber(player.missileLevel) or 1)
    return {
        {
            id = "laser",
            label = string.format("Laser booster  Lv %d", laserLevel),
            detail = string.format("Damage %.2f  Cost %d kills", self:getLaserDamage(player), WEAPON_UPGRADE_COST)
        },
        {
            id = "missile",
            label = string.format("Missile booster  Lv %d", missileLevel),
            detail = string.format("Blast radius %d  Cost %d kills", math.floor(self:getMissileBlastRadius(player) + 0.5), WEAPON_UPGRADE_COST)
        },
        {
            id = "unlimited",
            label = "Unlimited Weapons",
            detail = "No kill cost"
        }
    }
end

function OrbitalDefenseScene:openUpgradeMenu()
    if self.gameOver then
        return
    end

    self.menuOpen = true
    self.menuIndex = math.max(1, math.min(self.menuIndex or 1, math.max(1, #self:getUpgradeMenuItems())))
    self.menuStatusMessage = nil
    self.menuStatusFrames = 0
end

function OrbitalDefenseScene:closeUpgradeMenu()
    self.menuOpen = false
    self.menuStatusMessage = nil
    self.menuStatusFrames = 0
end

function OrbitalDefenseScene:purchaseUpgrade(item)
    local player = self.players[self.localSlot]
    if player == nil or item == nil then
        return
    end

    if item.id ~= "unlimited" and (player.score or 0) < WEAPON_UPGRADE_COST then
        self.menuStatusMessage = "Need more kills."
        self.menuStatusFrames = 90
        return
    end

    if item.id ~= "unlimited" then player.score = player.score - WEAPON_UPGRADE_COST end
    if item.id == "laser" then
        player.laserLevel = math.max(1, (tonumber(player.laserLevel) or 1) + 1)
        self.menuStatusMessage = "Laser upgraded."
    elseif item.id == "missile" then
        player.missileLevel = math.max(1, (tonumber(player.missileLevel) or 1) + 1)
        self.menuStatusMessage = "Missile upgraded."
    elseif item.id == "unlimited" then
        player.score = math.max(player.score or 0, 999999)
        player.laserLevel = math.max(8, tonumber(player.laserLevel) or 1)
        player.missileLevel = math.max(8, tonumber(player.missileLevel) or 1)
        self.menuStatusMessage = "Unlimited weapons enabled."
    end
    self.menuStatusFrames = 90
end

function OrbitalDefenseScene:addExplosion(x, y, radius, life)
    self.explosions[#self.explosions + 1] = {
        x = x,
        y = y,
        radius = radius or 8,
        life = life or 8
    }
end

function OrbitalDefenseScene:getEndlessDifficulty()
    local elapsedFrames = self.elapsedFrames or 0
    local tier = math.max(1, math.floor(elapsedFrames / ENDLESS_TIER_FRAMES) + 1)
    local plannedTier = math.min(PLANNED_TIER_COUNT, tier)
    local overflowTier = math.max(0, tier - PLANNED_TIER_COUNT)

    local spawnInterval = math.max(4, ENEMY_SPAWN_FRAMES - ((plannedTier - 1) * 2) - overflowTier)
    local hpBonus = (plannedTier - 1) + math.floor(overflowTier * 0.5)
    local speedBonus = ((plannedTier - 1) * 0.05) + (overflowTier * 0.035)
    local sizeBonus = math.min(4, math.floor((plannedTier - 1) / 2) + math.floor(overflowTier / 3))

    return {
        tier = tier,
        plannedTier = plannedTier,
        overflowTier = overflowTier,
        spawnInterval = spawnInterval,
        hpBonus = hpBonus,
        speedBonus = speedBonus,
        sizeBonus = sizeBonus
    }
end

function OrbitalDefenseScene:spawnEnemy()
    local difficulty = self:getEndlessDifficulty()
    local side = math.random(1, 3)
    local x = 0
    local y = 0
    if side == 1 then
        x = 24 + math.random(352)
        y = -8
    elseif side == 2 then
        x = -10
        y = 28 + math.random(110)
    else
        x = SCREEN_WIDTH + 10
        y = 28 + math.random(110)
    end

    self.enemies[#self.enemies + 1] = {
        x = x,
        y = y,
        hp = 5 + difficulty.hpBonus + math.random(0, 2 + math.min(3, difficulty.overflowTier)),
        speed = ENEMY_BASE_SPEED + difficulty.speedBonus + (math.random() * (0.28 + (difficulty.overflowTier * 0.015))),
        size = 6 + math.random(0, 2 + difficulty.sizeBonus)
    }

    if difficulty.overflowTier > 0 and math.random() < math.min(0.55, 0.16 + (difficulty.overflowTier * 0.05)) then
        local drift = 0.18 + (math.random() * (0.1 + (difficulty.overflowTier * 0.02)))
        self.enemies[#self.enemies].driftX = drift * randomSign()
        self.enemies[#self.enemies].driftY = drift * randomSign()
    end
end

function OrbitalDefenseScene:readLocalControls()
    local player = self.players[self.localSlot]
    if player == nil then
        return false
    end

    local moveInput = 0
    if pd.buttonIsPressed(pd.kButtonUp) then
        moveInput = moveInput + 1
    end
    if pd.buttonIsPressed(pd.kButtonDown) then
        moveInput = moveInput - 1
    end

    local crankChange = pd.getCrankChange()
    local laserOn = pd.buttonIsPressed(pd.kButtonLeft)
    local missileTriggered = pd.buttonJustPressed(pd.kButtonRight)
    local menuPressed = pd.buttonJustPressed(pd.kButtonA)
    local interacted = moveInput ~= 0
        or math.abs(crankChange) >= LOCAL_IDLE_CRANK_THRESHOLD
        or laserOn
        or missileTriggered
        or menuPressed

    player.angle = normalizeAngle(player.angle + (crankChange * 0.8))
    -- Up and down advance the turret around the shield so the player can reposition along the ring.
    player.orbitAngle = normalizeAngle((player.orbitAngle or PLAYER_ANCHORS[self.localSlot].orbitAngle) + (moveInput * PLAYER_ORBIT_SPEED))
    player.laserOn = laserOn
    player.pendingMissileTrigger = missileTriggered
    return interacted
end

function OrbitalDefenseScene:sendClientInput()
    if not self.networked or not self.portalService:isClient() or self.portalService.current == nil or self.portalService.current.hostPeerId == nil then
        return
    end

    local anchor = PLAYER_ANCHORS[self.localSlot]
    if self.players[self.localSlot] == nil then
        self.players[self.localSlot] = {
            id = self.localSlot,
            angle = anchor.defaultAngle,
            orbitAngle = anchor.orbitAngle,
            distance = DEFAULT_DISTANCE,
            laserOn = false,
            missile = nil,
            pendingMissileTrigger = false,
            controlKind = "local",
            score = 0,
            laserLevel = 1,
            missileLevel = 1
        }
    end

    self:readLocalControls()
    local player = self.players[self.localSlot]
    local missileTriggered = player.pendingMissileTrigger == true
    if math.abs(angleDelta(player.angle, self.lastSentAngle)) >= 0.5
        or math.abs(angleDelta(player.orbitAngle or anchor.orbitAngle, self.lastSentOrbitAngle)) >= 0.5
        or player.laserOn ~= self.lastSentLaser
        or missileTriggered then
        self.lastSentAngle = player.angle
        self.lastSentOrbitAngle = player.orbitAngle or anchor.orbitAngle
        self.lastSentLaser = player.laserOn
        self.portalService:sendPayload(self.portalService.current.hostPeerId, {
            type = "input",
            angle = player.angle,
            orbitAngle = player.orbitAngle,
            laser = player.laserOn,
            missile = missileTriggered
        })
    end
    player.pendingMissileTrigger = false
end

function OrbitalDefenseScene:getNearestEnemy(x, y)
    local nearestEnemy = nil
    local nearestDistanceSquared = math.huge
    for _, enemy in ipairs(self.enemies) do
        local candidateDistanceSquared = distanceSquared(x, y, enemy.x, enemy.y)
        if candidateDistanceSquared < nearestDistanceSquared then
            nearestDistanceSquared = candidateDistanceSquared
            nearestEnemy = enemy
        end
    end
    return nearestEnemy
end

function OrbitalDefenseScene:updateAIPlayers()
    for index, player in ipairs(self.players) do
        if player.controlKind == "bot" then
            local originX, originY = self:getPlayerOrigin(index, player)
            local nearestEnemy = self:getNearestEnemy(originX, originY)
            if nearestEnemy ~= nil then
                local desiredAngle = math.deg(math.atan(nearestEnemy.y - originY, nearestEnemy.x - originX))
                local delta = angleDelta(desiredAngle, player.angle)
                if delta > 0 then
                    player.angle = normalizeAngle(player.angle + math.min(AI_AIM_SPEED, delta))
                else
                    player.angle = normalizeAngle(player.angle - math.min(AI_AIM_SPEED, math.abs(delta)))
                end
                player.laserOn = math.abs(angleDelta(desiredAngle, player.angle)) <= 12
            else
                player.laserOn = false
            end
        end
    end
end

function OrbitalDefenseScene:updateSinglePlayerLocalControlState()
    if self.networked or self.preview then
        return
    end

    if #self.players < 2 then
        return
    end

    local player = self.players[self.localSlot]
    if player == nil then
        return
    end

    local interacted = self:readLocalControls()
    if interacted then
        self.localIdleFrames = 0
        if player.controlKind ~= "local" then
            player.controlKind = "local"
            player.laserOn = false
            player.pendingMissileTrigger = false
            StarryLog.forceDebug("orbital local control restored after input")
        end
        return
    end

    self.localIdleFrames = self.localIdleFrames + 1
    if self.localIdleFrames >= LOCAL_IDLE_TIMEOUT_FRAMES and player.controlKind ~= "bot" then
        player.controlKind = "bot"
        player.laserOn = false
        player.pendingMissileTrigger = false
        StarryLog.forceDebug("orbital local autopilot activated idleFrames=%d", self.localIdleFrames)
    end
end

function OrbitalDefenseScene:updateEnemies()
    local difficulty = self:getEndlessDifficulty()
    self.spawnTimer = self.spawnTimer - 1
    if self.spawnTimer <= 0 then
        self.spawnTimer = difficulty.spawnInterval
        self:spawnEnemy()
    end

    for enemyIndex = #self.enemies, 1, -1 do
        local enemy = self.enemies[enemyIndex]
        local dx = PLANET_X - enemy.x
        local dy = PLANET_Y - enemy.y
        local distance = math.max(1, math.sqrt((dx * dx) + (dy * dy)))
        enemy.x = enemy.x + ((dx / distance) * enemy.speed) + (enemy.driftX or 0)
        enemy.y = enemy.y + ((dy / distance) * enemy.speed) + (enemy.driftY or 0)

        -- Enemy ships now burst on shield impact instead of lingering on the ring and draining it every frame.
        if distance <= (RING_RADIUS + enemy.size) and self.ringHealth > 0 then
            self.ringHealth = math.max(0, self.ringHealth - 1)
            self:addExplosion(enemy.x, enemy.y, 10, 7)
            table.remove(self.enemies, enemyIndex)
        elseif distance <= PLANET_RADIUS + 4 then
            self.earthHealth = math.max(0, self.earthHealth - 1)
            self:addExplosion(enemy.x, enemy.y, 10, 7)
            table.remove(self.enemies, enemyIndex)
            if self.earthHealth <= 0 then
                self:finishMatch()
                return
            end
        end
    end
end

function OrbitalDefenseScene:explodeMissile(player, impactX, impactY)
    local blastRadius = self:getMissileBlastRadius(player)
    self:addExplosion(impactX, impactY, blastRadius, 9)
    for enemyIndex = #self.enemies, 1, -1 do
        local enemy = self.enemies[enemyIndex]
        local hitRadius = blastRadius + enemy.size
        if distanceSquared(impactX, impactY, enemy.x, enemy.y) <= (hitRadius * hitRadius) then
            enemy.hp = enemy.hp - MISSILE_DAMAGE
            if enemy.hp <= 0 then
                player.score = player.score + 1
                player.kills = (player.kills or 0) + 1
                table.remove(self.enemies, enemyIndex)
            end
        end
    end
    player.missile = nil
end

function OrbitalDefenseScene:handleMissileTrigger(index, player)
    if player.pendingMissileTrigger ~= true then
        return
    end

    if player.missile ~= nil then
        self:explodeMissile(player, player.missile.x, player.missile.y)
        player.pendingMissileTrigger = false
        return
    end

    local originX, originY = self:getPlayerOrigin(index, player)
    local radians = math.rad(player.angle)
    player.missile = {
        x = originX,
        y = originY,
        vx = math.cos(radians) * MISSILE_SPEED,
        vy = math.sin(radians) * MISSILE_SPEED,
        life = MISSILE_LIFE_FRAMES
    }
    player.pendingMissileTrigger = false
end

function OrbitalDefenseScene:updateMissiles()
    for index, player in ipairs(self.players) do
        if player.pendingMissileTrigger == true then
            self:handleMissileTrigger(index, player)
        end

        local missile = player.missile
        if missile ~= nil then
            missile.x = missile.x + missile.vx
            missile.y = missile.y + missile.vy
            missile.life = missile.life - 1

            local exploded = false
            for _, enemy in ipairs(self.enemies) do
                local hitRadius = enemy.size + 3
                if distanceSquared(missile.x, missile.y, enemy.x, enemy.y) <= (hitRadius * hitRadius) then
                    self:explodeMissile(player, missile.x, missile.y)
                    exploded = true
                    break
                end
            end

            if not exploded and (missile.life <= 0 or missile.x < -20 or missile.x > (SCREEN_WIDTH + 20) or missile.y < -20 or missile.y > 260) then
                self:explodeMissile(player, missile.x, missile.y)
            end
        end
    end
end

function OrbitalDefenseScene:applyLasers()
    for index, player in ipairs(self.players) do
        if player.laserOn then
            local originX, originY = self:getPlayerOrigin(index, player)
            local radians = math.rad(player.angle)
            local endX = originX + (math.cos(radians) * LASER_RANGE)
            local endY = originY + (math.sin(radians) * LASER_RANGE)
            local laserDamage = self:getLaserDamage(player)
            for enemyIndex = #self.enemies, 1, -1 do
                local enemy = self.enemies[enemyIndex]
                local hitDistanceSquared = linePointDistanceSquared(enemy.x, enemy.y, originX, originY, endX, endY)
                local hitRadius = enemy.size + LASER_WIDTH
                if hitDistanceSquared <= (hitRadius * hitRadius) then
                    enemy.hp = enemy.hp - laserDamage
                    if enemy.hp <= 0 then
                        player.score = player.score + 1
                        player.kills = (player.kills or 0) + 1
                        self:addExplosion(enemy.x, enemy.y, 12, 8)
                        table.remove(self.enemies, enemyIndex)
                    end
                end
            end
        end
    end
end

function OrbitalDefenseScene:updateExplosions()
    for index = #self.explosions, 1, -1 do
        local explosion = self.explosions[index]
        explosion.life = explosion.life - 1
        if explosion.life <= 0 then
            table.remove(self.explosions, index)
        end
    end
end

function OrbitalDefenseScene:serializeState()
    local players = {}
    for index, player in ipairs(self.players) do
        players[index] = {
            id = player.id,
            angle = player.angle,
            orbitAngle = player.orbitAngle,
            laserOn = player.laserOn,
            missile = player.missile and {
                x = player.missile.x,
                y = player.missile.y
            } or nil,
            score = player.score,
            kills = player.kills or 0,
            laserLevel = player.laserLevel,
            missileLevel = player.missileLevel
        }
    end

    local enemies = {}
    for index, enemy in ipairs(self.enemies) do
        enemies[index] = {
            x = enemy.x,
            y = enemy.y,
            hp = enemy.hp,
            size = enemy.size
        }
    end

    local explosions = {}
    for index, explosion in ipairs(self.explosions) do
        explosions[index] = {
            x = explosion.x,
            y = explosion.y,
            radius = explosion.radius,
            life = explosion.life
        }
    end

    return {
        frame = self.frame,
        elapsedFrames = self.elapsedFrames,
        earthHealth = self.earthHealth,
        ringHealth = self.ringHealth,
        remainingFrames = self.remainingFrames,
        gameOver = self.gameOver,
        matchResults = self.matchResults,
        players = players,
        enemies = enemies,
        explosions = explosions
    }
end

function OrbitalDefenseScene:getRenderState()
    if self.networked and self.portalService:isClient() then
        return self.remoteState
    end
    return self:serializeState()
end

function OrbitalDefenseScene:finishMatch()
    if self.gameOver then
        return
    end

    self.gameOver = true
    self.menuOpen = false
    local playerKills = {}
    local totalKills = 0
    for index, player in ipairs(self.players) do
        local kills = math.max(0, math.floor(tonumber(player.kills) or 0))
        playerKills[index] = kills
        totalKills = totalKills + kills
        player.laserOn = false
    end

    local saved = loadResults()
    local highScore = math.max(math.max(0, math.floor(tonumber(saved.highScore) or 0)), totalKills)
    self.matchResults = {
        totalKills = totalKills,
        playerKills = playerKills,
        highScore = highScore
    }
    self.resultsRecorded = true
    saveResults(self.matchResults)
end

function OrbitalDefenseScene.getLastMatchSummary()
    local saved = loadResults()
    local highScore = math.max(0, math.floor(tonumber(saved.highScore) or 0))
    if saved.totalKills == nil then
        return string.format("High score: %d enemies", highScore)
    end
    return string.format("Last: %d enemies  High: %d", math.max(0, math.floor(tonumber(saved.totalKills) or 0)), highScore)
end

function OrbitalDefenseScene:updateLocalGame()
    self.frame = self.frame + 1
    self.elapsedFrames = (self.elapsedFrames or 0) + 1
    if self.networked then
        self:readLocalControls()
    elseif #self.players >= 2 then
        self:updateSinglePlayerLocalControlState()
    else
        self:readLocalControls()
    end
    self:updateAIPlayers()
    self:updateEnemies()
    self:applyLasers()
    self:updateMissiles()
    self:updateExplosions()
end

function OrbitalDefenseScene:drawBackground(frame)
    gfx.clear(gfx.kColorBlack)
    drawOrbitalBackgroundStars(self.backgroundStars)
    local blackHole = PixelPlanetsAssets.blackHoleFrame(math.floor((frame or 0) / 3))
    if blackHole ~= nil then
        -- Cached PixelPlanets frames keep this animated background element cheap.
        blackHole:drawCentered(330, 64)
    end
end

function OrbitalDefenseScene:drawLobby()
    gfx.clear(gfx.kColorBlack)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawTextAligned("Multiplayer Orbital Defense", 200, 22, kTextAlignment.center)
    gfx.drawTextAligned(string.format("Selected beings: %d", self.playerCount), 200, 40, kTextAlignment.center)

    local serialText = self.portalService.isSerialConnected and "Serial: connected to pdportal" or "Serial: connect USB and open pdportal"
    local peerText = self.portalService.isPeerOpen and ("Peer ID: " .. tostring(self.portalService.peerId)) or "Peer ID: waiting for portal handshake"
    gfx.drawTextAligned(serialText, 200, 76, kTextAlignment.center)
    gfx.drawTextAligned(peerText, 200, 92, kTextAlignment.center)

    local lobbySlots = self.portalService:getLobbySlots()
    for slot = 1, self.playerCount do
        local label = PLAYER_ANCHORS[slot].label .. "  waiting"
        if slot == self.portalService:getAssignedSlot() then
            label = PLAYER_ANCHORS[slot].label .. "  you"
        elseif self.portalService:isHost() and slot == 1 then
            label = PLAYER_ANCHORS[slot].label .. "  host"
        elseif lobbySlots[slot] then
            label = PLAYER_ANCHORS[slot].label .. "  connected"
        end
        gfx.drawTextAligned(label, 200, 118 + ((slot - 1) * 16), kTextAlignment.center)
    end

    gfx.drawTextAligned(self.statusMessage or "", 200, 194, kTextAlignment.center)
    if self.portalService:isHost() then
        gfx.drawTextAligned("Press A to start when every selected being is connected.", 200, 210, kTextAlignment.center)
    else
        gfx.drawTextAligned("Join the host from pdportal and wait for the launch.", 200, 210, kTextAlignment.center)
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function OrbitalDefenseScene:drawWorld(state)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(PLANET_X, PLANET_Y, PLANET_RADIUS)
    gfx.drawCircleAtPoint(PLANET_X, PLANET_Y, PLANET_RADIUS)
    -- A solid Earth silhouette with a few dark surface marks reads much more
    -- clearly than a featureless disc at game speed.
    gfx.setColor(gfx.kColorBlack)
    gfx.drawCircleAtPoint(PLANET_X, PLANET_Y, PLANET_RADIUS - 5)
    gfx.fillRoundRect(PLANET_X - 25, PLANET_Y - 8, 16, 8, 3)
    gfx.fillRoundRect(PLANET_X + 8, PLANET_Y - 22, 13, 10, 3)
    gfx.fillRoundRect(PLANET_X + 14, PLANET_Y + 12, 18, 7, 3)
    gfx.fillRoundRect(PLANET_X - 30, PLANET_Y + 17, 14, 6, 3)
    gfx.drawLine(PLANET_X - 30, PLANET_Y + 2, PLANET_X + 31, PLANET_Y + 2)
    gfx.setColor(gfx.kColorWhite)
    -- The elevator rises out of the planet and terminates in a visible dock.
    gfx.fillRect(PLANET_X - 3, 126, 7, PLANET_Y - PLANET_RADIUS - 126)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(PLANET_X - 1, 128, 3, PLANET_Y - PLANET_RADIUS - 128)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(PLANET_X - 12, 114, 25, 10, 4)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(PLANET_X - 5, 117, 11, 3)
    gfx.setColor(gfx.kColorWhite)
    if (state.ringHealth or 0) > 0 then
        gfx.drawCircleAtPoint(PLANET_X, PLANET_Y, RING_RADIUS)
        gfx.drawCircleAtPoint(PLANET_X, PLANET_Y, RING_RADIUS + 2)
    end

    for index, player in ipairs(state.players or {}) do
        local originX, originY = self:getPlayerOrigin(index, player)
        gfx.fillCircleAtPoint(originX, originY, 8)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillCircleAtPoint(originX, originY, 4)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawCircleAtPoint(originX, originY, 8)
        local beamRadians = math.rad(player.angle)
        local tipX = originX + (math.cos(beamRadians) * 30)
        local tipY = originY + (math.sin(beamRadians) * 30)
        local sideX = math.cos(beamRadians + (math.pi * 0.5))
        local sideY = math.sin(beamRadians + (math.pi * 0.5))
        gfx.drawLine(originX + (sideX * 2), originY + (sideY * 2), tipX + (sideX * 2), tipY + (sideY * 2))
        gfx.drawLine(originX - (sideX * 2), originY - (sideY * 2), tipX - (sideX * 2), tipY - (sideY * 2))
        gfx.fillCircleAtPoint(tipX, tipY, 3)
        gfx.drawText(PLAYER_ANCHORS[index].label, originX - 8, originY + 8)
        if player.laserOn then
            local endX = originX + (math.cos(beamRadians) * LASER_RANGE)
            local endY = originY + (math.sin(beamRadians) * LASER_RANGE)
            gfx.drawLine(originX, originY, endX, endY)
        end
        if player.missile ~= nil then
            gfx.fillCircleAtPoint(player.missile.x, player.missile.y, 2)
        end
    end

    for _, enemy in ipairs(state.enemies or {}) do
        local size = enemy.size
        local half = math.floor(size * 0.5)
        gfx.drawRect(enemy.x - half, enemy.y - half, size, size)
    end

    for _, explosion in ipairs(state.explosions or {}) do
        gfx.drawCircleAtPoint(explosion.x, explosion.y, math.max(1, math.floor(explosion.radius * (explosion.life / 8))))
    end
end

function OrbitalDefenseScene:drawHud(state)
    if UIState and not UIState.isShown() then
        local shieldUp = (state.ringHealth or 0) > 0
        local value = shieldUp and (state.ringHealth or 0) or (EARTH_MAX_HEALTH - (state.earthHealth or 0))
        local maximum = shieldUp and SHIELD_MAX_HEALTH or EARTH_MAX_HEALTH
        local ratio = clamp(value / maximum, 0, 1)
        local barX, barY, barWidth, barHeight = 10, 224, 380, 14
        gfx.setColor(gfx.kColorWhite)
        gfx.drawRect(barX, barY, barWidth, barHeight)
        if ratio > 0 then
            gfx.fillRect(barX + 2, barY + 2, math.floor((barWidth - 4) * ratio), barHeight - 4)
        end
        local label = shieldUp and string.format("EARTH SHIELD  %d%%", math.ceil(ratio * 100)) or string.format("EARTH DAMAGE  %d%%", math.ceil(ratio * 100))
        gfx.setImageDrawMode(ratio > 0.5 and gfx.kDrawModeFillBlack or gfx.kDrawModeInverted)
        gfx.drawTextAligned(label, 200, 225, kTextAlignment.center)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        return
    end
    if self.menuOpen then
        return
    end

    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    local title = self.multiplayer and ("Orbital Defense  " .. tostring(self.playerCount) .. "P") or "Orbital Defense"
    local elapsedFrames = state.elapsedFrames or 0
    local difficultyTier = math.max(1, math.floor(elapsedFrames / ENDLESS_TIER_FRAMES) + 1)
    gfx.drawText(title, 10, 8)
    gfx.drawText(string.format("Tier %d  Endless", difficultyTier), 10, 24)

    local scoreLine = {}
    for index, player in ipairs(state.players or {}) do
        scoreLine[#scoreLine + 1] = string.format("%s %d", PLAYER_ANCHORS[index].label, player.kills or 0)
    end
    gfx.drawText(table.concat(scoreLine, "   "), 10, 40)
    local shieldUp = (state.ringHealth or 0) > 0
    local value = shieldUp and (state.ringHealth or 0) or (EARTH_MAX_HEALTH - (state.earthHealth or 0))
    local maximum = shieldUp and SHIELD_MAX_HEALTH or EARTH_MAX_HEALTH
    local ratio = clamp(value / maximum, 0, 1)
    local barX, barY, barWidth, barHeight = 10, 224, 380, 14
    gfx.drawRect(barX, barY, barWidth, barHeight)
    if ratio > 0 then
        gfx.fillRect(barX + 2, barY + 2, math.floor((barWidth - 4) * ratio), barHeight - 4)
    end
    local label = shieldUp and string.format("EARTH SHIELD  %d%%", math.ceil(ratio * 100)) or string.format("EARTH DAMAGE  %d%%", math.ceil(ratio * 100))
    gfx.setImageDrawMode(ratio > 0.5 and gfx.kDrawModeFillBlack or gfx.kDrawModeInverted)
    gfx.drawTextAligned(label, 200, 225, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawText("Crank aim  L laser  R missile  Up/Down orbit  A upgrades", 10, 194)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function OrbitalDefenseScene:drawGameOver(state)
    if not state.gameOver then
        return
    end
    local results = state.matchResults or self.matchResults or loadResults()
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(36, 72, 328, 112, 10)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(36, 72, 328, 112, 10)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawTextAligned("EARTH DESTROYED :(", 200, 86, kTextAlignment.center)
    local playerKills = results.playerKills or {}
    local scoreLine = {}
    for index, kills in ipairs(playerKills) do
        scoreLine[#scoreLine + 1] = string.format("%s: %d", PLAYER_ANCHORS[index].label, kills or 0)
    end
    gfx.drawTextAligned(table.concat(scoreLine, "   "), 200, 110, kTextAlignment.center)
    gfx.drawTextAligned(string.format("Enemies destroyed: %d", results.totalKills or 0), 200, 130, kTextAlignment.center)
    gfx.drawTextAligned(string.format("High score: %d", results.highScore or 0), 200, 148, kTextAlignment.center)
    gfx.drawTextAligned("B: return to title", 200, 168, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function OrbitalDefenseScene:updateUpgradeMenu()
    if not self.menuOpen then
        return
    end

    if self.menuStatusFrames > 0 then
        self.menuStatusFrames = self.menuStatusFrames - 1
    end

    if pd.buttonJustPressed(pd.kButtonB) then
        self:closeUpgradeMenu()
        return
    end

    local items = self:getUpgradeMenuItems()
    if #items <= 0 then
        return
    end

    if pd.buttonJustPressed(pd.kButtonUp) then
        self.menuIndex = self.menuIndex - 1
        if self.menuIndex < 1 then
            self.menuIndex = #items
        end
    elseif pd.buttonJustPressed(pd.kButtonDown) then
        self.menuIndex = self.menuIndex + 1
        if self.menuIndex > #items then
            self.menuIndex = 1
        end
    elseif pd.buttonJustPressed(pd.kButtonA) then
        self:purchaseUpgrade(items[self.menuIndex])
    end
end

function OrbitalDefenseScene:drawUpgradeMenu(state)
    if not self.menuOpen then
        return
    end

    local player = self.players[self.localSlot]
    if player == nil then
        return
    end

    local items = self:getUpgradeMenuItems()
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.45, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(0, 0, SCREEN_WIDTH, 240)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)

    local panelX = 48
    local panelY = 32
    local panelW = 304
    local panelH = 196
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(panelX, panelY, panelW, panelH, 8)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(panelX, panelY, panelW, panelH, 8)
    gfx.drawTextAligned("Weapon Tuning", 200, panelY + 8, kTextAlignment.center)
    gfx.drawLine(panelX + 12, panelY + 24, panelX + panelW - 12, panelY + 24)

    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawTextAligned(string.format("Kills available: %d", math.max(0, player.score or 0)), 200, panelY + 30, kTextAlignment.center)

    for index, item in ipairs(items) do
        local rowY = panelY + 50 + ((index - 1) * 34)
        local selected = self.menuIndex == index
        if selected then
            gfx.fillRoundRect(panelX + 14, rowY, panelW - 28, 28, 5)
            gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
        else
            gfx.drawRoundRect(panelX + 14, rowY, panelW - 28, 28, 5)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        end
        gfx.drawText(item.label, panelX + 26, rowY + 6)
        gfx.drawTextAligned(item.detail or "", panelX + panelW - 26, rowY + 6, kTextAlignment.right)
    end

    if self.menuStatusFrames > 0 and self.menuStatusMessage ~= nil then
        gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        gfx.drawTextAligned(self.menuStatusMessage, 200, panelY + panelH - 24, kTextAlignment.center)
    else
        gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        gfx.drawTextAligned("A buy   B close", 200, panelY + panelH - 24, kTextAlignment.center)
    end

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function OrbitalDefenseScene:drawGameState(state)
    self:drawBackground(state.frame or 0)
    self:drawWorld(state)
    self:drawHud(state)
    self:drawUpgradeMenu(state)
    self:drawGameOver(state)
end

function OrbitalDefenseScene:draw()
    self:drawGameState(self:getRenderState())
end

function OrbitalDefenseScene:update()
    if self.preview then
        return
    end

    if self.tutorialOpen then
        local tutorialMode = self.multiplayer and "multi" or "single"
        self.tutorialScroll = Tutorials.updateScroll(self.tutorialScroll, "orbital", tutorialMode, pd.getCrankChange(), pd.buttonJustPressed(pd.kButtonUp), pd.buttonJustPressed(pd.kButtonDown))
        self:draw()
        Tutorials.draw("orbital", tutorialMode, self.tutorialScroll)
        if pd.buttonJustPressed(pd.kButtonA) then
            Tutorials.markSeen("orbital", tutorialMode)
            self.tutorialOpen = false
        elseif pd.buttonJustPressed(pd.kButtonB) and self.onReturnToTitle then
            self.onReturnToTitle("orbital")
        end
        return
    end

    -- Keep B consistent with the rest of Starry Messenger: it returns to the
    -- title from play, while the tuning menu handles B locally to close itself.
    if not self.menuOpen and pd.buttonJustPressed(pd.kButtonB) and self.onReturnToTitle then
        self.onReturnToTitle("orbital")
        return
    end

    if self.networked then
        if self.mode == "lobby" then
            if pd.buttonJustPressed(pd.kButtonB) and self.onReturnToTitle then
                self.onReturnToTitle("orbital")
                return
            end
            if pd.buttonJustPressed(pd.kButtonA) and self.portalService:isHost() then
                if self.portalService:isReadyToStart() then
                    self:startHostMatch()
                else
                    self.statusMessage = string.format("Waiting for %d beings before launch.", self.playerCount)
                end
            end
            self:drawLobby()
            return
        end

        if self.menuOpen then
            self:updateUpgradeMenu()
            self:draw()
            return
        end

        if self.portalService:isClient() then
            self:sendClientInput()
            local state = self:getRenderState()
            if state ~= nil then
                self:drawGameState(state)
            else
                gfx.clear(gfx.kColorBlack)
                gfx.setImageDrawMode(gfx.kDrawModeInverted)
                gfx.drawTextAligned("Waiting for host snapshot...", 200, 120, kTextAlignment.center)
                gfx.setImageDrawMode(gfx.kDrawModeCopy)
            end
            return
        end
    end

    if self.gameOver and pd.buttonJustPressed(pd.kButtonB) then
        if self.onReturnToTitle then
            self.onReturnToTitle("orbital")
        end
        return
    end

    if self.gameOver then
        self:draw()
        return
    end

    if self.menuOpen then
        self:updateUpgradeMenu()
        self:draw()
        return
    end

    if pd.buttonJustPressed(pd.kButtonA) then
        self:openUpgradeMenu()
        self:draw()
        return
    end

    self:updateLocalGame()
    if self.networked and self.portalService:isHost() and (self.frame % SNAPSHOT_INTERVAL_FRAMES == 0) then
        self.portalService:broadcast({
            type = "snapshot",
            state = self:serializeState()
        })
    end
    self:draw()
end
