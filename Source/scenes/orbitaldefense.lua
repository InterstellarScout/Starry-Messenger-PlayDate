import "gameconfig"
import "systems/multiplayer"

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
local MISSILE_SPEED <const> = ORBITAL_CONFIG.missileSpeed or 3.8
local MISSILE_DAMAGE <const> = ORBITAL_CONFIG.missileDamage or 6
local MISSILE_BLAST_RADIUS <const> = ORBITAL_CONFIG.missileBlastRadius or 18
local MISSILE_LIFE_FRAMES <const> = ORBITAL_CONFIG.missileLifeFrames or 90
local ENEMY_BASE_SPEED <const> = ORBITAL_CONFIG.enemyBaseSpeed or 0.58
local ENEMY_SPAWN_FRAMES <const> = ORBITAL_CONFIG.enemySpawnFrames or 16
local MATCH_DURATION_FRAMES <const> = ORBITAL_CONFIG.matchDurationFrames or (30 * 90)
local SNAPSHOT_INTERVAL_FRAMES <const> = ORBITAL_CONFIG.snapshotIntervalFrames or 3

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

OrbitalDefenseScene = {}
OrbitalDefenseScene.__index = OrbitalDefenseScene

function OrbitalDefenseScene.new(config)
    local self = setmetatable({}, OrbitalDefenseScene)
    self.onReturnToTitle = config.onReturnToTitle
    self.preview = config.preview == true
    self.multiplayer = config.multiplayer == true
    self.portalService = config.portalService
    self.networked = self.multiplayer and self.portalService ~= nil
    self.playerCount = self.multiplayer and MultiplayerConfig.clampPlayerCount(config.playerCount, 2, 4, 2) or 1
    self.localSlot = 1
    self.players = {}
    self.enemies = {}
    self.explosions = {}
    self.frame = 0
    self.spawnTimer = ENEMY_SPAWN_FRAMES
    self.earthHealth = 24
    self.ringHealth = 80
    self.remainingFrames = MATCH_DURATION_FRAMES
    self.gameOver = false
    self.mode = self.networked and "lobby" or "game"
    self.remoteState = nil
    self.statusMessage = self.networked and "Open pdportal in the browser and connect the selected beings." or "Single-player orbital defense."
    self.smallFont = gfx.getSystemFont()
    self.lastSentAngle = 0
    self.lastSentOrbitAngle = PLAYER_ANCHORS[1].orbitAngle
    self.lastSentLaser = false

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
    self.earthHealth = 24
    self.ringHealth = 80
    self.remainingFrames = MATCH_DURATION_FRAMES
    self.gameOver = false
    self.localSlot = localSlot or 1

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
            score = 0
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

function OrbitalDefenseScene:addExplosion(x, y, radius, life)
    self.explosions[#self.explosions + 1] = {
        x = x,
        y = y,
        radius = radius or 8,
        life = life or 8
    }
end

function OrbitalDefenseScene:spawnEnemy()
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
        hp = 5 + math.random(0, 2),
        speed = ENEMY_BASE_SPEED + (math.random() * 0.28),
        size = 6 + math.random(0, 2)
    }
end

function OrbitalDefenseScene:readLocalControls()
    local player = self.players[self.localSlot]
    if player == nil then
        return
    end

    local aimInput = 0
    local moveInput = 0
    if pd.buttonIsPressed(pd.kButtonLeft) then
        aimInput = aimInput - 1
    end
    if pd.buttonIsPressed(pd.kButtonRight) then
        aimInput = aimInput + 1
    end
    if pd.buttonIsPressed(pd.kButtonUp) then
        moveInput = moveInput + 1
    end
    if pd.buttonIsPressed(pd.kButtonDown) then
        moveInput = moveInput - 1
    end

    local crankChange = pd.getCrankChange()
    player.angle = normalizeAngle(player.angle + (aimInput * PLAYER_AIM_SPEED) + (crankChange * 0.8))
    -- Up and down advance the turret around the shield so the player can reposition along the ring.
    player.orbitAngle = normalizeAngle((player.orbitAngle or PLAYER_ANCHORS[self.localSlot].orbitAngle) + (moveInput * PLAYER_ORBIT_SPEED))
    player.laserOn = pd.buttonIsPressed(pd.kButtonA)
    player.pendingMissileTrigger = pd.buttonJustPressed(pd.kButtonB)
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
            score = 0
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

function OrbitalDefenseScene:updateEnemies()
    self.spawnTimer = self.spawnTimer - 1
    if self.spawnTimer <= 0 then
        self.spawnTimer = ENEMY_SPAWN_FRAMES
        self:spawnEnemy()
    end

    for enemyIndex = #self.enemies, 1, -1 do
        local enemy = self.enemies[enemyIndex]
        local dx = PLANET_X - enemy.x
        local dy = PLANET_Y - enemy.y
        local distance = math.max(1, math.sqrt((dx * dx) + (dy * dy)))
        enemy.x = enemy.x + ((dx / distance) * enemy.speed)
        enemy.y = enemy.y + ((dy / distance) * enemy.speed)

        -- Enemy ships now burst on shield impact instead of lingering on the ring and draining it every frame.
        if distance <= (RING_RADIUS + enemy.size) and self.ringHealth > 0 then
            self.ringHealth = math.max(0, self.ringHealth - 1)
            self:addExplosion(enemy.x, enemy.y, 10, 7)
            table.remove(self.enemies, enemyIndex)
        elseif distance <= PLANET_RADIUS + 4 then
            self.earthHealth = math.max(0, self.earthHealth - 1)
            self:addExplosion(enemy.x, enemy.y, 10, 7)
            table.remove(self.enemies, enemyIndex)
        end
    end
end

function OrbitalDefenseScene:explodeMissile(player, impactX, impactY)
    self:addExplosion(impactX, impactY, MISSILE_BLAST_RADIUS, 9)
    for enemyIndex = #self.enemies, 1, -1 do
        local enemy = self.enemies[enemyIndex]
        local hitRadius = MISSILE_BLAST_RADIUS + enemy.size
        if distanceSquared(impactX, impactY, enemy.x, enemy.y) <= (hitRadius * hitRadius) then
            enemy.hp = enemy.hp - MISSILE_DAMAGE
            if enemy.hp <= 0 then
                player.score = player.score + 1
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
            for enemyIndex = #self.enemies, 1, -1 do
                local enemy = self.enemies[enemyIndex]
                local hitDistanceSquared = linePointDistanceSquared(enemy.x, enemy.y, originX, originY, endX, endY)
                local hitRadius = enemy.size + LASER_WIDTH
                if hitDistanceSquared <= (hitRadius * hitRadius) then
                    enemy.hp = enemy.hp - LASER_DAMAGE
                    if enemy.hp <= 0 then
                        player.score = player.score + 1
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
            score = player.score
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
        earthHealth = self.earthHealth,
        ringHealth = self.ringHealth,
        remainingFrames = self.remainingFrames,
        gameOver = self.gameOver,
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

function OrbitalDefenseScene:updateLocalGame()
    self.frame = self.frame + 1
    if not self.gameOver then
        self.remainingFrames = math.max(0, self.remainingFrames - 1)
        self:readLocalControls()
        self:updateAIPlayers()
        self:updateEnemies()
        self:applyLasers()
        self:updateMissiles()
        self:updateExplosions()
        if self.earthHealth <= 0 or self.remainingFrames <= 0 then
            self.gameOver = true
        end
    end
end

function OrbitalDefenseScene:drawBackground(frame)
    gfx.clear(gfx.kColorBlack)
    for index = 0, 10 do
        local x = (index * 37 + 9 + math.floor(frame * 0.2)) % SCREEN_WIDTH
        local y = (index * 17 + 13 + math.floor(frame * 0.1)) % 150
        gfx.fillRect(x, y, 1, 1)
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
    gfx.drawCircleAtPoint(PLANET_X, PLANET_Y, PLANET_RADIUS)
    if (state.ringHealth or 0) > 0 then
        gfx.drawCircleAtPoint(PLANET_X, PLANET_Y, RING_RADIUS)
        gfx.drawCircleAtPoint(PLANET_X, PLANET_Y, RING_RADIUS + 2)
    end

    for index, player in ipairs(state.players or {}) do
        local originX, originY = self:getPlayerOrigin(index, player)
        gfx.drawCircleAtPoint(originX, originY, 5)
        local beamRadians = math.rad(player.angle)
        local tipX = originX + (math.cos(beamRadians) * 24)
        local tipY = originY + (math.sin(beamRadians) * 24)
        gfx.drawLine(originX, originY, tipX, tipY)
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
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    local title = self.multiplayer and ("Orbital Defense  " .. tostring(self.playerCount) .. "P") or "Orbital Defense"
    gfx.drawText(title, 10, 8)
    gfx.drawText(string.format("Earth %d  Ring %d  Time %d", state.earthHealth or 0, math.ceil(state.ringHealth or 0), math.ceil((state.remainingFrames or 0) / 30)), 10, 24)

    local scoreLine = {}
    for index, player in ipairs(state.players or {}) do
        scoreLine[#scoreLine + 1] = string.format("%s %d", PLAYER_ANCHORS[index].label, player.score or 0)
    end
    gfx.drawText(table.concat(scoreLine, "   "), 10, 40)
    gfx.drawText(self.networked and "Crank/Left/Right aim  Up/Down orbit  Hold A laser  B missile  pdportal live" or "Crank/Left/Right aim  Up/Down orbit  Hold A laser  B missile", 10, 220)

    if state.gameOver then
        gfx.drawTextAligned("Defense run complete. Press B to return.", 200, 108, kTextAlignment.center)
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function OrbitalDefenseScene:drawGameState(state)
    self:drawBackground(state.frame or 0)
    self:drawWorld(state)
    self:drawHud(state)
    ControlHelp.drawOverlay("orbital", nil)
end

function OrbitalDefenseScene:draw()
    self:drawGameState(self:getRenderState())
end

function OrbitalDefenseScene:update()
    if self.preview then
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

    self:updateLocalGame()
    if self.networked and self.portalService:isHost() and (self.frame % SNAPSHOT_INTERVAL_FRAMES == 0) then
        self.portalService:broadcast({
            type = "snapshot",
            state = self:serializeState()
        })
    end
    self:draw()
end
