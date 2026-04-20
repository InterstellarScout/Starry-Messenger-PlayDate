import "CoreLibs/graphics"

local pd <const> = playdate
local gfx <const> = pd.graphics

SpaceMiner = {}
SpaceMiner.__index = SpaceMiner

SpaceMiner.MODE_FULL = "full"
SpaceMiner.MODE_HALF = "half"
SpaceMiner.MODE_QUARTER = "quarter"

local SCREEN_WIDTH <const> = 400
local SCREEN_HEIGHT <const> = 240
local CENTER_X <const> = SCREEN_WIDTH * 0.5
local CENTER_Y <const> = SCREEN_HEIGHT * 0.5
local WORLD_WRAP_RADIUS <const> = 620
local ASTEROID_SAFE_RADIUS <const> = 140
local PLAYER_RADIUS <const> = 8
local DECOR_WRAP_RADIUS <const> = 720
local PLAYER_THRUST <const> = 0.08
local PLAYER_REVERSE_THRUST <const> = 0.05
local ENEMY_BASE_ACCELERATION <const> = 0.045
local ENEMY_ESCAPER_ACCELERATION <const> = 0.055
local ENEMY_STRIKER_ACCELERATION <const> = 0.072
local PLAYER_MAX_SPEED <const> = 3.8
local ENEMY_MAX_SPEED <const> = 3.2
local LASER_RANGE <const> = 170
local LASER_WIDTH <const> = 4
local LASER_DAMAGE <const> = 0.34
local MISSILE_SPEED <const> = 4.4
local MISSILE_DAMAGE <const> = 99
local MISSILE_BLAST_RADIUS <const> = 34
local MISSILE_LIFE_FRAMES <const> = 110
local PLAYER_MISSILE_DRAW_RADIUS <const> = 5
local PLAYER_MISSILE_DRAW_LENGTH <const> = 10
local MAX_ACTIVE_ENTITIES <const> = 54
local TARGET_ASTEROID_COUNT <const> = 12
local PREVIEW_ASTEROID_COUNT <const> = 8
local DECOR_ITEM_COUNT <const> = 120
local SHIELD_HITS <const> = 2
local HULL_HITS <const> = 2
local SHIELD_FLASH_FRAMES <const> = 18
local FIRST_MINING_STAGE_FRAMES <const> = 30 * 120
local INTERMISSION_STAGE_FRAMES <const> = 30 * 120
local STRIKER_MISSILE_COOLDOWN <const> = 70

local ASTEROID_STAGE_CONFIG <const> = {
    [0] = { radius = 40, hp = 7, speed = 0.28, fragments = 2, score = 20 },
    [1] = { radius = 24, hp = 4, speed = 0.45, fragments = 2, score = 10 },
    [2] = { radius = 14, hp = 2, speed = 0.68, fragments = 2, score = 6 },
    [3] = { radius = 8, hp = 1, speed = 0.95, fragments = 0, score = 3 }
}

local TURN_WINDOW_DEGREES <const> = {
    [SpaceMiner.MODE_FULL] = 360,
    [SpaceMiner.MODE_HALF] = 180,
    [SpaceMiner.MODE_QUARTER] = 90
}

local STAGE_SCHEDULE <const> = {
    { id = "mining-1", kind = "mining", durationFrames = FIRST_MINING_STAGE_FRAMES, label = "Mining Window" },
    { id = "seekers-1", kind = "wave", enemyType = "seeker", count = 4, label = "Seeker Wave 1" },
    { id = "seekers-2", kind = "wave", enemyType = "seeker", count = 8, label = "Seeker Wave 2" },
    { id = "seekers-3", kind = "wave", enemyType = "seeker", count = 16, label = "Seeker Wave 3" },
    { id = "mining-2", kind = "mining", durationFrames = INTERMISSION_STAGE_FRAMES, label = "Mining Break" },
    { id = "escapers-1", kind = "wave", enemyType = "escaper", count = 2, label = "Escaper Wave 1" },
    { id = "escapers-2", kind = "wave", enemyType = "escaper", count = 4, label = "Escaper Wave 2" },
    { id = "strikers", kind = "wave", enemyType = "striker", count = 3, label = "Striker Assault" }
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

local function normalizeAngle(angle)
    local normalized = angle % 360
    if normalized < 0 then
        normalized = normalized + 360
    end
    return normalized
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

function SpaceMiner.new(width, height, options)
    local self = setmetatable({}, SpaceMiner)
    options = options or {}
    self.width = width
    self.height = height
    self.modeId = options.modeId or SpaceMiner.MODE_FULL
    self.preview = options.preview == true
    self.turnWindow = TURN_WINDOW_DEGREES[self.modeId] or 360
    self.turnScale = 360 / self.turnWindow
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
    self.stageLabel = STAGE_SCHEDULE[1].label
    self.spawnedWave = false
    self.enemySerial = 0
    self.playerShieldHits = SHIELD_HITS
    self.playerHullHits = HULL_HITS
    self.shieldFlashFrames = 0
    self.gameOver = false
    self.previewDriftAngle = 0
    self.previewFrameCounter = 0
    self.decor = {}
    self:seedDecor()
    self:seedAsteroids(10)
    return self
end

function SpaceMiner:setPreview(isPreview)
    self.preview = isPreview == true
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
    elseif roll <= 0.97 then
        return "square"
    end
    return "circle"
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

    self.asteroids[#self.asteroids + 1] = {
        x = x,
        y = y,
        vx = math.cos(angle + math.pi * 0.5) * speed,
        vy = math.sin(angle + math.pi * 0.5) * speed,
        stage = stage,
        radius = config.radius,
        hp = config.hp
    }
end

function SpaceMiner:spawnFragments(asteroid)
    local nextStage = asteroid.stage + 1
    local nextConfig = ASTEROID_STAGE_CONFIG[nextStage]
    if nextConfig == nil then
        return
    end

    for index = 1, 2 do
        local angle = math.atan(asteroid.vy, asteroid.vx) + ((index == 1 and -0.8) or 0.8)
        local speed = nextConfig.speed * (0.8 + (math.random() * 0.7))
        self.asteroids[#self.asteroids + 1] = {
            x = asteroid.x + math.cos(angle) * nextConfig.radius,
            y = asteroid.y + math.sin(angle) * nextConfig.radius,
            vx = asteroid.vx * 0.55 + math.cos(angle) * speed,
            vy = asteroid.vy * 0.55 + math.sin(angle) * speed,
            stage = nextStage,
            radius = nextConfig.radius,
            hp = nextConfig.hp
        }
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
    self:addExplosion(self.player.x, self.player.y, 14, 10)
    StarryLog.info("miner player hit reason=%s shield=%d hull=%d", tostring(reason), self.playerShieldHits, self.playerHullHits)
    if self.playerHullHits <= 0 then
        self.gameOver = true
    end
end

function SpaceMiner:spawnEnemy(enemyType)
    self.enemySerial = self.enemySerial + 1
    local angle = math.random() * math.pi * 2
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
    self.spawnedWave = false
    local stage = STAGE_SCHEDULE[self.stageIndex]
    self.stageLabel = stage.label
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

function SpaceMiner:updateStage()
    if self.preview then
        return
    end

    local stage = STAGE_SCHEDULE[self.stageIndex]
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

    if not self.spawnedWave then
        for _ = 1, stage.count do
            self:spawnEnemy(stage.enemyType)
        end
        self.spawnedWave = true
    elseif #self.enemyShips == 0 and #self.enemyMissiles == 0 then
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
    self.player.x = self.player.x + self.player.vx
    self.player.y = self.player.y + self.player.vy
    if self.shieldFlashFrames > 0 then
        self.shieldFlashFrames = self.shieldFlashFrames - 1
    end
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
        self:spawnFragments(asteroid)
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
                spawnFragments = false
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
            self:damageAsteroid(asteroidIndex, LASER_DAMAGE)
        end
    end
end

function SpaceMiner:updateAsteroids()
    for asteroidIndex = #self.asteroids, 1, -1 do
        local asteroid = self.asteroids[asteroidIndex]
        asteroid.x = wrapCoordinate(self.player.x, asteroid.x + asteroid.vx)
        asteroid.y = wrapCoordinate(self.player.y, asteroid.y + asteroid.vy)

        local hitRadius = asteroid.radius + PLAYER_RADIUS
        if distanceSquared(asteroid.x, asteroid.y, self.player.x, self.player.y) <= (hitRadius * hitRadius) then
            self:addExplosion(asteroid.x, asteroid.y, asteroid.radius + 4, 8)
            self:damagePlayer("asteroid")
            self:spawnFragments(asteroid)
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

    local removable = {}
    for asteroidIndex, asteroid in ipairs(self.asteroids) do
        local drawX, drawY = worldToScreen(self.player.x, self.player.y, asteroid.x, asteroid.y)
        local visible = drawX >= -asteroid.radius
            and drawX <= (SCREEN_WIDTH + asteroid.radius)
            and drawY >= -asteroid.radius
            and drawY <= (SCREEN_HEIGHT + asteroid.radius)
        if not visible then
            removable[#removable + 1] = {
                asteroid = asteroid,
                radius = asteroid.radius
            }
        end
    end

    table.sort(removable, function(left, right)
        return left.radius < right.radius
    end)

    for _, candidate in ipairs(removable) do
        if activeEntities <= MAX_ACTIVE_ENTITIES then
            break
        end
        for asteroidIndex = #self.asteroids, 1, -1 do
            if self.asteroids[asteroidIndex] == candidate.asteroid then
                table.remove(self.asteroids, asteroidIndex)
                activeEntities = activeEntities - 1
                break
            end
        end
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
end

function SpaceMiner:drawDecorLayer(layer)
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
                    gfx.setDitherPattern(0.25, gfx.image.kDitherTypeBayer8x8)
                    gfx.setColor(gfx.kColorBlack)
                    gfx.fillCircleAtPoint(drawX, drawY, item.radius)
                    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
                    gfx.setColor(gfx.kColorWhite)
                    gfx.drawCircleAtPoint(drawX, drawY, item.radius)
                end
            end
        end
    end
end

function SpaceMiner:drawShip()
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
    if self.playerShieldHits > 0 or self.shieldFlashFrames > 0 then
        gfx.drawCircleAtPoint(CENTER_X, CENTER_Y, shieldRadius)
    end
end

function SpaceMiner:drawAsteroids()
    for _, asteroid in ipairs(self.asteroids) do
        local drawX, drawY = worldToScreen(self.player.x, self.player.y, asteroid.x, asteroid.y)
        if drawX >= -30 and drawX <= (SCREEN_WIDTH + 30) and drawY >= -30 and drawY <= (SCREEN_HEIGHT + 30) then
            gfx.drawCircleAtPoint(drawX, drawY, asteroid.radius)
            gfx.drawLine(drawX - asteroid.radius * 0.6, drawY, drawX + asteroid.radius * 0.6, drawY - asteroid.radius * 0.2)
        end
    end
end

function SpaceMiner:drawEnemies()
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

    local radians = math.rad(self.player.angle)
    local endX = CENTER_X + (math.cos(radians) * LASER_RANGE)
    local endY = CENTER_Y + (math.sin(radians) * LASER_RANGE)
    gfx.drawLine(CENTER_X, CENTER_Y, endX, endY)
end

function SpaceMiner:drawExplosions()
    for _, explosion in ipairs(self.explosions) do
        local drawX, drawY = worldToScreen(self.player.x, self.player.y, explosion.x, explosion.y)
        local radius = math.max(1, math.floor(explosion.radius * (explosion.life / explosion.maxLife)))
        gfx.drawCircleAtPoint(drawX, drawY, radius)
    end
end

function SpaceMiner:drawHud()
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawText("Space Miner", 8, 8)
    gfx.drawText(self.stageLabel, 8, 24)
    gfx.drawText(string.format("Ore %d  Score %d", self.minedChunks, self.score), 8, 40)
    gfx.drawText(string.format("Shield %d  Hull %d  Mode %s", self.playerShieldHits, self.playerHullHits, SpaceMiner.getModeLabel(self.modeId)), 8, 56)
    gfx.drawText(string.format("Vel %.1f", magnitude(self.player.vx, self.player.vy)), 8, 72)
    if not self.preview then
        gfx.drawText("Up/Down thrust  Left laser  Right missile  Crank turn", 8, 220)
    end
    if self.gameOver then
        gfx.drawTextAligned("Ship destroyed. Press B to return.", 200, 108, kTextAlignment.center)
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function SpaceMiner:draw()
    gfx.clear(gfx.kColorBlack)
    gfx.setColor(gfx.kColorWhite)
    self:drawDecorLayer("back")
    self:drawAsteroids()
    self:drawEnemies()
    self:drawMissiles()
    self:drawExplosions()
    self:drawLaser()
    self:drawShip()
    self:drawDecorLayer("front")
    self:drawHud()
end
