--[[
Fishy Pond gameplay and ambient pond simulation.

Purpose:
- runs the pond, bubbles, tank, and idle variants
- manages fish steering, bubble spawning, upgrades, and player interactions
- provides the shared effect used by both previews and active gameplay
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

FishPond = {}
FishPond.__index = FishPond

FishPond.MODE_POND = "pond"
FishPond.MODE_BUBBLES = "bubbles"
FishPond.MODE_TANK = "tank"
FishPond.MODE_IDLE = "idle"
FishPond.spawnModeEnabled = false
FishPond.idleCurrency = 0
FishPond.idleProgressLoaded = false
FishPond.IDLE_SAVE_KEY = "fishy-pond-idle"

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function lerp(a, b, t)
    return a + ((b - a) * t)
end

local function sign(value)
    if value < 0 then
        return -1
    elseif value > 0 then
        return 1
    end
    return 0
end

local function length(x, y)
    return math.sqrt((x * x) + (y * y))
end

local function limit(x, y, maxLength)
    local currentLength = length(x, y)
    if currentLength == 0 or currentLength <= maxLength then
        return x, y
    end

    local scale = maxLength / currentLength
    return x * scale, y * scale
end

local function wrapAngle(value)
    local tau = math.pi * 2
    while value < 0 do
        value = value + tau
    end
    while value >= tau do
        value = value - tau
    end
    return value
end

local function rotateLocalPoint(x, y, angle)
    local cosine = math.cos(angle)
    local sine = math.sin(angle)
    return (x * cosine) - (y * sine), (x * sine) + (y * cosine)
end

local function wrapHorizontal(value, width, margin)
    if value < -margin then
        return width + margin
    elseif value > width + margin then
        return -margin
    end

    return value
end

local WATER_TOP <const> = 18
local FLOOR_HEIGHT <const> = 26
local BUBBLE_MAKER_Y_OFFSET <const> = 12
local MAX_SCHOOL_FISH <const> = 14
local TANK_FISH_COUNT <const> = 20
local TANK_PANIC_DURATION <const> = 1.0
local TANK_SHAKE_THRESHOLD <const> = 0.55
local PLAYER_FISH_SIZE <const> = 9
local TANK_CURRENT_IMPULSE_SCALE <const> = 0.06
local BUBBLE_HOLD_REPEAT_FRAMES <const> = 5
local BUBBLE_MAKER_IDLE_DELAY <const> = 0.85
local BUBBLE_MAKER_HUNT_WINDOW <const> = 1.35
local NEW_FISH_SCHOOL_DELAY <const> = 3.5
local IDLE_BUBBLE_REWARD <const> = 1
local BUBBLE_VENT_RISE_TIME <const> = 0.18
local BUBBLE_VENT_POP_TIME <const> = 0.08
local RANDOM_MUD_BUBBLE_MIN_DELAY <const> = 1.9
local RANDOM_MUD_BUBBLE_MAX_DELAY <const> = 3.4
local PLAYER_FISH_CHASE_SPEED <const> = 92
local PLAYER_FISH_CHASE_MIN_SPEED <const> = 34
local PLAYER_FISH_CHASE_LEAD_TIME <const> = 0.16
local PLAYER_FISH_FREE_SWIM_SPEED_X <const> = 72
local PLAYER_FISH_FREE_SWIM_SPEED_Y <const> = 60

local function loadIdleProgress()
    if FishPond.idleProgressLoaded then
        return
    end

    local savedProgress = nil
    if pd.datastore and pd.datastore.read then
        savedProgress = pd.datastore.read(FishPond.IDLE_SAVE_KEY)
    end

    FishPond.idleCurrency = math.max(0, math.floor((savedProgress and tonumber(savedProgress.currency)) or 0))
    FishPond.idleProgressLoaded = true
end

local function saveIdleProgress()
    if not FishPond.idleProgressLoaded then
        return
    end

    if pd.datastore and pd.datastore.write then
        pd.datastore.write({
            currency = FishPond.idleCurrency
        }, FishPond.IDLE_SAVE_KEY)
    end
end

local function nextRandomMudBubbleDelay()
    return RANDOM_MUD_BUBBLE_MIN_DELAY + (math.random() * (RANDOM_MUD_BUBBLE_MAX_DELAY - RANDOM_MUD_BUBBLE_MIN_DELAY))
end

function FishPond.setSpawnModeEnabled(isEnabled)
    FishPond.spawnModeEnabled = isEnabled and true or false
end

function FishPond.isSpawnModeEnabled()
    return FishPond.spawnModeEnabled == true
end

function FishPond.getIdleCurrency()
    loadIdleProgress()
    return FishPond.idleCurrency
end

function FishPond.getModeLabel(modeId)
    if modeId == FishPond.MODE_BUBBLES then
        return "Fishy Bubbles"
    elseif modeId == FishPond.MODE_TANK then
        return "Fishy Tank"
    elseif modeId == FishPond.MODE_IDLE then
        return "Fishy Pond Idle"
    end

    return "Fishy Pond"
end

function FishPond.new(width, height, modeId, options)
    local self = setmetatable({}, FishPond)
    self.width = width
    self.height = height
    self.preview = options and options.preview or false
    self.modeId = modeId or FishPond.MODE_POND
    self.idleMode = self.modeId == FishPond.MODE_IDLE
    self.time = 0
    self.fishes = {}
    self.bubbles = {}
    self.playerFish = nil
    self.playerInputX = 0
    self.playerInputY = 0
    self.bubbleMakerX = width / 2
    self.bubbleMakerAutoPhase = math.random() * math.pi * 2
    self.bubbleMakerIdleTimer = 0
    self.bubbleMakerHuntTimer = 0
    self.previewBubbleTimer = 0.6
    self.randomBubbleTimer = nextRandomMudBubbleDelay()
    self.actionRepeatFrames = 0
    self.pendingSpawnBubble = nil
    self.bubbleVents = {}
    self.lastSpawnModeEnabled = FishPond.isSpawnModeEnabled()
    self.currentStrength = 0
    self.panicTimer = 0
    self.lastAccelX = nil
    self.lastAccelY = nil
    self.lastAccelZ = nil
    loadIdleProgress()
    self:reset(self.modeId)
    return self
end

function FishPond:setPreview(isPreview)
    self.preview = isPreview and true or false
end

function FishPond:reset(modeId)
    self.modeId = modeId or self.modeId
    self.idleMode = self.modeId == FishPond.MODE_IDLE
    self.time = 0
    self.fishes = {}
    self.bubbles = {}
    self.playerFish = nil
    self.playerInputX = 0
    self.playerInputY = 0
    self.bubbleMakerX = self.width / 2
    self.bubbleMakerAutoPhase = math.random() * math.pi * 2
    self.bubbleMakerIdleTimer = 0
    self.bubbleMakerHuntTimer = 0
    self.previewBubbleTimer = 0.5
    self.randomBubbleTimer = nextRandomMudBubbleDelay()
    self.actionRepeatFrames = 0
    self.pendingSpawnBubble = nil
    self.bubbleVents = {}
    self.lastSpawnModeEnabled = FishPond.isSpawnModeEnabled()
    self.currentStrength = 0
    self.panicTimer = 0
    self.lastAccelX = nil
    self.lastAccelY = nil
    self.lastAccelZ = nil

    if self.modeId == FishPond.MODE_TANK then
        for _ = 1, TANK_FISH_COUNT do
            self:addFish(false, true)
        end
    elseif self.idleMode then
        self:addFish(false, false)
    else
        self:addFish(true, false)
    end
end

function FishPond:addFish(isPlayer, randomDepth, schoolDelay)
    local size = isPlayer and PLAYER_FISH_SIZE or (6 + math.random() * 6)
    local margin = size * 2.4
    local fish = {
        x = margin + (math.random() * math.max(1, self.width - (margin * 2))),
        y = WATER_TOP + size + (math.random() * math.max(1, self.height - FLOOR_HEIGHT - WATER_TOP - (size * 2))),
        vx = (math.random() * 28) - 14,
        vy = (math.random() * 18) - 9,
        size = size,
        player = isPlayer,
        heading = math.random() * math.pi * 2,
        swaySeed = math.random() * math.pi * 2,
        turnBias = (math.random() * 2) - 1,
        cruise = isPlayer and 52 or (18 + math.random() * 18),
        schoolDelay = isPlayer and 0 or (schoolDelay or 0),
        panicVX = 0,
        panicVY = 0
    }

    if not randomDepth then
        fish.y = self.height * 0.58
    end

    self.fishes[#self.fishes + 1] = fish
    if isPlayer then
        self.playerFish = fish
    end
end

function FishPond:activate()
    if self.modeId == FishPond.MODE_TANK and not pd.accelerometerIsRunning() then
        pd.startAccelerometer()
    end
end

function FishPond:shutdown()
    if pd.accelerometerIsRunning() then
        pd.stopAccelerometer()
    end
end

function FishPond:setPlayerInput(dx, dy)
    self.playerInputX = dx or 0
    self.playerInputY = dy or 0
end

function FishPond:moveBubbleMaker(delta)
    if self.modeId == FishPond.MODE_TANK then
        return
    end

    self.bubbleMakerX = wrapHorizontal(self.bubbleMakerX + (delta * 2.1), self.width, 18)
    self.bubbleMakerIdleTimer = BUBBLE_MAKER_IDLE_DELAY
    self.bubbleMakerHuntTimer = BUBBLE_MAKER_HUNT_WINDOW
end

function FishPond:getWrappedBubbleMakerX()
    if self.bubbleMakerX < 0 then
        return self.bubbleMakerX + self.width
    elseif self.bubbleMakerX > self.width then
        return self.bubbleMakerX - self.width
    end

    return self.bubbleMakerX
end

function FishPond:spawnPlayerBubble(options)
    if self.modeId == FishPond.MODE_TANK then
        return nil
    end

    local floorTop = self.height - FLOOR_HEIGHT
    local bubble = {
        x = self:getWrappedBubbleMakerX(),
        y = floorTop - 8,
        radius = 5 + (math.random() * 4),
        speed = 24 + (math.random() * 16),
        swaySeed = math.random() * math.pi * 2,
        swaySpeed = 1.1 + (math.random() * 1.3),
        popTimer = 0,
        spawnFishOnPop = options and options.spawnFishOnPop or false
    }
    return self:queueBubbleVent(bubble.x, bubble)
end

function FishPond:queueBubbleVent(x, bubble, isRandomMudBubble)
    local vent = {
        x = x,
        bubble = bubble,
        phase = "rise",
        timer = BUBBLE_VENT_RISE_TIME,
        isRandomMudBubble = isRandomMudBubble == true
    }
    self.bubbleVents[#self.bubbleVents + 1] = vent
    return vent
end

function FishPond:spawnRandomMudBubble()
    if self.modeId == FishPond.MODE_TANK then
        return
    end

    local floorTop = self.height - FLOOR_HEIGHT
    local bubble = {
        x = 22 + (math.random() * (self.width - 44)),
        y = floorTop - 8,
        radius = 4 + (math.random() * 3),
        speed = 20 + (math.random() * 12),
        swaySeed = math.random() * math.pi * 2,
        swaySpeed = 0.9 + (math.random() * 1.0),
        popTimer = 0,
        spawnFishOnPop = false
    }
    self:queueBubbleVent(bubble.x, bubble, true)
end

function FishPond:activateVentBubble(vent)
    if vent.bubbleActivated then
        return
    end

    local floorTop = self.height - FLOOR_HEIGHT
    vent.bubble.y = floorTop - 4 - vent.bubble.radius
    self.bubbles[#self.bubbles + 1] = vent.bubble
    if self.pendingSpawnBubble == vent then
        self.pendingSpawnBubble = vent.bubble
    end
    vent.bubbleActivated = true
end

function FishPond:updateBubbleVents(dt)
    for index = #self.bubbleVents, 1, -1 do
        local vent = self.bubbleVents[index]
        vent.timer = vent.timer - dt
        if vent.timer <= 0 then
            if vent.phase == "rise" then
                vent.phase = "pop"
                vent.timer = BUBBLE_VENT_POP_TIME
                self:activateVentBubble(vent)
            else
                table.remove(self.bubbleVents, index)
            end
        end
    end
end

function FishPond:updateActionInput(justPressed, held)
    if self.preview or self.modeId == FishPond.MODE_TANK then
        self.actionRepeatFrames = 0
        return
    end

    if FishPond.isSpawnModeEnabled() and not self.idleMode then
        self.actionRepeatFrames = 0
        if justPressed then
            self:handleSpawnModeAction()
        end
        return
    end

    if not held then
        self.actionRepeatFrames = 0
        return
    end

    if justPressed then
        self:spawnPlayerBubble()
        self.actionRepeatFrames = 0
        return
    end

    self.actionRepeatFrames = self.actionRepeatFrames + 1
    if self.actionRepeatFrames >= BUBBLE_HOLD_REPEAT_FRAMES then
        self:spawnPlayerBubble()
        self.actionRepeatFrames = 0
    end
end

function FishPond:adjustTankCurrent(delta)
    if self.modeId ~= FishPond.MODE_TANK then
        return
    end

    self.currentStrength = clamp(self.currentStrength + (delta * TANK_CURRENT_IMPULSE_SCALE), -1.6, 1.6)
end

function FishPond:triggerPanic()
    if self.modeId ~= FishPond.MODE_TANK then
        return
    end

    self.panicTimer = TANK_PANIC_DURATION
    for _, fish in ipairs(self.fishes) do
        local angle = math.random() * math.pi * 2
        local speed = 56 + (math.random() * 48)
        fish.panicVX = math.cos(angle) * speed
        fish.panicVY = math.sin(angle) * speed
    end
end

function FishPond:updateShake()
    if self.modeId ~= FishPond.MODE_TANK or not pd.accelerometerIsRunning() then
        return
    end

    local accelX, accelY, accelZ = pd.readAccelerometer()
    if accelX == nil then
        return
    end

    if self.lastAccelX ~= nil then
        local change = math.abs(accelX - self.lastAccelX)
            + math.abs(accelY - self.lastAccelY)
            + math.abs(accelZ - self.lastAccelZ)

        if change >= TANK_SHAKE_THRESHOLD and self.panicTimer <= 0 then
            self:triggerPanic()
        end
    end

    self.lastAccelX = accelX
    self.lastAccelY = accelY
    self.lastAccelZ = accelZ
end

function FishPond:updatePreviewBehavior(dt)
    if not self.preview then
        return
    end

    if self.modeId == FishPond.MODE_TANK then
        return
    end

    self.bubbleMakerX = (self.width / 2) + (math.sin(self.time * 0.8) * (self.width * 0.24))
    self.previewBubbleTimer = self.previewBubbleTimer - dt
    if self.previewBubbleTimer <= 0 then
        self:spawnPlayerBubble()
        self.previewBubbleTimer = 0.65 + (math.random() * 0.5)
    end

    self.randomBubbleTimer = self.randomBubbleTimer - dt
    if self.randomBubbleTimer <= 0 then
        self:spawnRandomMudBubble()
        self.randomBubbleTimer = nextRandomMudBubbleDelay()
    end
end

function FishPond:syncSpawnModeState()
    if self.idleMode then
        self.pendingSpawnBubble = nil
        self.lastSpawnModeEnabled = FishPond.isSpawnModeEnabled()
        return
    end

    local spawnModeEnabled = FishPond.isSpawnModeEnabled()
    if self.lastSpawnModeEnabled and not spawnModeEnabled and self.pendingSpawnBubble then
        if self.pendingSpawnBubble.bubble then
            self.pendingSpawnBubble.bubble.spawnFishOnPop = false
        else
            self.pendingSpawnBubble.spawnFishOnPop = false
        end
        self.pendingSpawnBubble = nil
    end
    self.lastSpawnModeEnabled = spawnModeEnabled
end

function FishPond:updateIdleBubbleMaker(dt)
    if self.preview or self.modeId == FishPond.MODE_TANK then
        return
    end

    if self.bubbleMakerIdleTimer > 0 then
        self.bubbleMakerIdleTimer = math.max(0, self.bubbleMakerIdleTimer - dt)
    end

    if self.bubbleMakerHuntTimer > 0 then
        self.bubbleMakerHuntTimer = math.max(0, self.bubbleMakerHuntTimer - dt)
    end

    self.randomBubbleTimer = self.randomBubbleTimer - dt
    if self.randomBubbleTimer <= 0 then
        self:spawnRandomMudBubble()
        self.randomBubbleTimer = nextRandomMudBubbleDelay()
    end
end

function FishPond:getClosestActiveBubble(x, y)
    local closestBubble = nil
    local closestDistanceSquared = math.huge

    for _, bubble in ipairs(self.bubbles) do
        if bubble.popTimer <= 0 then
            local dx = bubble.x - x
            local dy = bubble.y - y
            local distanceSquared = (dx * dx) + (dy * dy)
            if distanceSquared < closestDistanceSquared then
                closestDistanceSquared = distanceSquared
                closestBubble = bubble
            end
        end
    end

    return closestBubble, closestDistanceSquared
end

function FishPond:spawnSchoolFish()
    if #self.fishes >= MAX_SCHOOL_FISH then
        return false
    end

    self:addFish(false, true, NEW_FISH_SCHOOL_DELAY)
    return true
end

function FishPond:findBubbleIndex(targetBubble)
    for index, bubble in ipairs(self.bubbles) do
        if bubble == targetBubble then
            return index
        end
    end

    return nil
end

function FishPond:handleSpawnModeAction()
    if self.pendingSpawnBubble then
        if self.pendingSpawnBubble.bubble then
            return
        end
        local bubbleIndex = self:findBubbleIndex(self.pendingSpawnBubble)
        if bubbleIndex ~= nil and self.pendingSpawnBubble.popTimer <= 0 then
            self:popBubble(bubbleIndex, false, true)
            self.pendingSpawnBubble = nil
            return
        end
        self.pendingSpawnBubble = nil
    end

    self.pendingSpawnBubble = self:spawnPlayerBubble({
        spawnFishOnPop = true
    })
end

function FishPond:updateBubbles(dt)
    for index = #self.bubbles, 1, -1 do
        local bubble = self.bubbles[index]
        if bubble.popTimer > 0 then
            bubble.popTimer = bubble.popTimer - dt
            if bubble.popTimer <= 0 then
                if self.pendingSpawnBubble == bubble then
                    self.pendingSpawnBubble = nil
                end
                table.remove(self.bubbles, index)
            end
        else
            bubble.y = bubble.y - (bubble.speed * dt)
            bubble.x = bubble.x + (math.sin((self.time * bubble.swaySpeed) + bubble.swaySeed) * 10 * dt)
            if bubble.y < WATER_TOP + bubble.radius then
                if self.pendingSpawnBubble == bubble then
                    self.pendingSpawnBubble = nil
                end
                table.remove(self.bubbles, index)
            end
        end
    end
end

function FishPond:popBubble(index, byPlayer, spawnFishOverride)
    local bubble = self.bubbles[index]
    if not bubble or bubble.popTimer > 0 then
        return false
    end

    bubble.popTimer = 0.14
    if self.pendingSpawnBubble == bubble then
        self.pendingSpawnBubble = nil
    end

    if self.idleMode and not self.preview and not byPlayer then
        FishPond.idleCurrency = FishPond.getIdleCurrency() + IDLE_BUBBLE_REWARD
        saveIdleProgress()
    end

    if (spawnFishOverride or bubble.spawnFishOnPop) and #self.fishes < MAX_SCHOOL_FISH then
        self:spawnSchoolFish()
    elseif self.modeId == FishPond.MODE_BUBBLES and byPlayer and #self.fishes < MAX_SCHOOL_FISH then
        self:spawnSchoolFish()
    end

    bubble.spawnFishOnPop = false
    return true
end

function FishPond:updateBubbleCollisions()
    if FishPond.isSpawnModeEnabled() and not self.idleMode then
        return
    end

    for index = #self.bubbles, 1, -1 do
        local bubble = self.bubbles[index]
        if bubble.popTimer <= 0 then
            for _, fish in ipairs(self.fishes) do
                local dx = fish.x - bubble.x
                local dy = fish.y - bubble.y
                local touchRadius = (fish.size * 1.2) + bubble.radius
                if (dx * dx) + (dy * dy) <= (touchRadius * touchRadius) then
                    self:popBubble(index, fish.player)
                    break
                end
            end
        end
    end
end

function FishPond:updateFish(dt)
    local schoolingEnabled = self.modeId == FishPond.MODE_TANK or #self.fishes > 1
    local waterBottom = self.height - FLOOR_HEIGHT - 6

    for _, fish in ipairs(self.fishes) do
        local steerX = 0
        local steerY = 0

        if fish.schoolDelay and fish.schoolDelay > 0 then
            fish.schoolDelay = math.max(0, fish.schoolDelay - dt)
        end

        if self.panicTimer > 0 then
            fish.vx = lerp(fish.vx, fish.panicVX, 0.08)
            fish.vy = lerp(fish.vy, fish.panicVY, 0.08)
        elseif fish.player and self.modeId ~= FishPond.MODE_TANK then
            local targetBubble = nil
            if self.modeId == FishPond.MODE_POND and self.bubbleMakerHuntTimer > 0 and not FishPond.isSpawnModeEnabled() then
                targetBubble = self:getClosestActiveBubble(fish.x, fish.y)
            end

            local desiredVX
            local desiredVY
            if targetBubble then
                local leadX = targetBubble.x + (math.cos((self.time * targetBubble.swaySpeed) + targetBubble.swaySeed) * 6 * PLAYER_FISH_CHASE_LEAD_TIME)
                local leadY = targetBubble.y - (targetBubble.speed * PLAYER_FISH_CHASE_LEAD_TIME)
                local dx = leadX - fish.x
                local dy = leadY - fish.y
                local distance = length(dx, dy)
                local nx, ny = limit(dx, dy, PLAYER_FISH_CHASE_SPEED)
                local chaseVX = nx
                local chaseVY = ny

                if distance > 0.001 and distance < PLAYER_FISH_CHASE_MIN_SPEED then
                    local dirX = dx / distance
                    local dirY = dy / distance
                    chaseVX = dirX * PLAYER_FISH_CHASE_MIN_SPEED
                    chaseVY = dirY * PLAYER_FISH_CHASE_MIN_SPEED
                end

                desiredVX = chaseVX
                desiredVY = chaseVY
            else
                local wanderX = math.cos((self.time * 1.2) + fish.swaySeed + (fish.turnBias * 0.8))
                local wanderY = math.sin((self.time * 0.7) + fish.swaySeed)
                desiredVX = (self.playerInputX * PLAYER_FISH_FREE_SWIM_SPEED_X) + (wanderX * 10)
                desiredVY = (self.playerInputY * PLAYER_FISH_FREE_SWIM_SPEED_Y) + (wanderY * 7)
            end
            fish.vx = lerp(fish.vx, desiredVX, 0.22)
            fish.vy = lerp(fish.vy, desiredVY, 0.22)
        else
            local wanderX = math.cos((self.time * 0.65) + fish.swaySeed + (fish.turnBias * 1.4))
            local wanderY = math.sin((self.time * 0.45) + (fish.swaySeed * 1.3))
            steerX = steerX + (wanderX * 11)
            steerY = steerY + (wanderY * 8)

            if schoolingEnabled and fish.schoolDelay <= 0 then
                local cohesionX = 0
                local cohesionY = 0
                local alignX = 0
                local alignY = 0
                local separationX = 0
                local separationY = 0
                local neighbors = 0

                for _, other in ipairs(self.fishes) do
                    if other ~= fish then
                        local dx = other.x - fish.x
                        local dy = other.y - fish.y
                        local distSquared = (dx * dx) + (dy * dy)

                        if distSquared < (80 * 80) then
                            neighbors = neighbors + 1
                            cohesionX = cohesionX + other.x
                            cohesionY = cohesionY + other.y
                            alignX = alignX + other.vx
                            alignY = alignY + other.vy

                            if distSquared < (18 * 18) and distSquared > 0.001 then
                                separationX = separationX - (dx / distSquared) * 180
                                separationY = separationY - (dy / distSquared) * 180
                            end
                        end
                    end
                end

                if neighbors > 0 then
                    cohesionX = ((cohesionX / neighbors) - fish.x) * 0.09
                    cohesionY = ((cohesionY / neighbors) - fish.y) * 0.09
                    alignX = ((alignX / neighbors) - fish.vx) * 0.04
                    alignY = ((alignY / neighbors) - fish.vy) * 0.04
                    steerX = steerX + cohesionX + alignX + separationX
                    steerY = steerY + cohesionY + alignY + separationY
                end
            end

            if self.playerFish and self.modeId == FishPond.MODE_BUBBLES then
                steerX = steerX + ((self.playerFish.x - fish.x) * 0.03)
                steerY = steerY + ((self.playerFish.y - fish.y) * 0.03)
            end

            if self.idleMode and fish.schoolDelay <= 0 then
                local targetBubble = self:getClosestActiveBubble(fish.x, fish.y)
                if targetBubble then
                    local dx = targetBubble.x - fish.x
                    local dy = targetBubble.y - fish.y
                    local pullX, pullY = limit(dx, dy, 28)
                    steerX = steerX + (pullX * 1.15)
                    steerY = steerY + (pullY * 1.15)
                end
            elseif not FishPond.isSpawnModeEnabled() and fish.schoolDelay <= 0 then
                local targetBubble, bubbleDistanceSquared = self:getClosestActiveBubble(fish.x, fish.y)
                if targetBubble and bubbleDistanceSquared <= (140 * 140) then
                    local dx = targetBubble.x - fish.x
                    local dy = targetBubble.y - fish.y
                    local pullX, pullY = limit(dx, dy, 22)
                    steerX = steerX + pullX
                    steerY = steerY + pullY
                end
            end

            if self.modeId == FishPond.MODE_TANK then
                steerY = steerY + (self.currentStrength * 16)
            end

            fish.vx = fish.vx + (steerX * dt)
            fish.vy = fish.vy + (steerY * dt)
        end

        local maxSpeed = fish.player and 94 or (fish.cruise + 4)
        fish.vx, fish.vy = limit(fish.vx, fish.vy, maxSpeed)
        fish.x = fish.x + (fish.vx * dt)
        fish.y = fish.y + (fish.vy * dt)

        local margin = fish.size * 1.6
        if fish.x < -margin then
            fish.x = self.width + margin
        elseif fish.x > self.width + margin then
            fish.x = -margin
        end

        if fish.y < WATER_TOP + margin then
            fish.y = WATER_TOP + margin
            fish.vy = math.abs(fish.vy) * 0.8
        elseif fish.y > waterBottom - margin then
            fish.y = waterBottom - margin
            fish.vy = -math.abs(fish.vy) * 0.8
        end

        if math.abs(fish.vx) > 0.1 or math.abs(fish.vy) > 0.1 then
            fish.heading = wrapAngle(math.atan(fish.vy, fish.vx))
        end
    end
end

function FishPond:update()
    local dt = 1 / 30
    self.time = self.time + dt
    self:syncSpawnModeState()
    self.currentStrength = lerp(self.currentStrength, 0, 0.08)
    self:updatePreviewBehavior(dt)
    self:updateIdleBubbleMaker(dt)
    self:updateShake()

    if self.panicTimer > 0 then
        self.panicTimer = math.max(0, self.panicTimer - dt)
        if self.panicTimer == 0 then
            for _, fish in ipairs(self.fishes) do
                fish.panicVX = 0
                fish.panicVY = 0
            end
        end
    end

    self:updateBubbleVents(dt)
    self:updateBubbles(dt)
    self:updateFish(dt)
    self:updateBubbleCollisions()
end

function FishPond:drawBackground()
    local floorTop = self.height - FLOOR_HEIGHT

    gfx.setColor(gfx.kColorWhite)
    for band = 0, 7 do
        local y = WATER_TOP + (band * 22)
        local offset = math.sin((self.time * 1.2) + band) * 10
        gfx.drawLine(0, y + offset, self.width, y - offset)
    end

    gfx.fillRect(0, floorTop, self.width, FLOOR_HEIGHT)
    gfx.setColor(gfx.kColorBlack)
    for index = 0, 10 do
        local stoneX = (index * 42) + (math.sin(self.time + index) * 6)
        local stoneW = 18 + ((index % 3) * 8)
        local stoneH = 5 + ((index % 4) * 2)
        gfx.fillEllipseInRect(stoneX, floorTop + 10 + (index % 3), stoneW, stoneH)
    end
    gfx.setColor(gfx.kColorWhite)
end

function FishPond:drawBubbleMakerAt(x)
    local floorTop = self.height - FLOOR_HEIGHT
    local peakHeight = 6 + math.floor(math.abs(math.sin((self.time * 2.1) + (x * 0.04))) * 3)
    local peakY = floorTop - peakHeight

    for row = 0, peakHeight do
        local width = math.max(1, 12 - (row * 2))
        gfx.drawLine(x - width, floorTop - row, x + width, floorTop - row)
    end

    gfx.drawLine(x - 12, floorTop, x, peakY)
    gfx.drawLine(x, peakY, x + 12, floorTop)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(x, peakY + 1, 1)
    gfx.setColor(gfx.kColorWhite)
end

function FishPond:drawBubbleVent(vent)
    local floorTop = self.height - FLOOR_HEIGHT
    if vent.phase == "rise" then
        local progress = 1 - math.max(0, vent.timer / BUBBLE_VENT_RISE_TIME)
        local peakHeight = 2 + math.floor(progress * 6)
        local baseWidth = 4 + math.floor(progress * 6)
        for row = 0, peakHeight do
            local width = math.max(1, baseWidth - row)
            gfx.drawLine(vent.x - width, floorTop - row, vent.x + width, floorTop - row)
        end
        return
    end

    local popProgress = 1 - math.max(0, vent.timer / BUBBLE_VENT_POP_TIME)
    local popRadius = 2 + (popProgress * 5)
    gfx.drawCircleAtPoint(vent.x, floorTop - 4 - popProgress, popRadius)
    gfx.drawCircleAtPoint(vent.x - 2, floorTop - 3 - popProgress, math.max(1, popRadius * 0.35))
end

function FishPond:drawBubbleMaker()
    if self.modeId == FishPond.MODE_TANK then
        return
    end

    local x = self.bubbleMakerX
    self:drawBubbleMakerAt(x)

    if x < 18 then
        self:drawBubbleMakerAt(x + self.width + 18)
    elseif x > self.width - 18 then
        self:drawBubbleMakerAt(x - self.width - 18)
    end
end

function FishPond:drawBubble(bubble)
    local radius = bubble.radius
    if bubble.popTimer > 0 then
        radius = radius + ((0.14 - bubble.popTimer) * 28)
        gfx.drawCircleAtPoint(bubble.x, bubble.y, radius)
        return
    end

    gfx.drawCircleAtPoint(bubble.x, bubble.y, radius)
    gfx.drawCircleAtPoint(bubble.x - (radius * 0.25), bubble.y - (radius * 0.25), math.max(1, radius * 0.22))
end

function FishPond:drawFish(fish)
    local heading = fish.heading or 0

    local function point(localX, localY)
        local rx, ry = rotateLocalPoint(localX, localY, heading)
        return fish.x + rx, fish.y + ry
    end

    local spineFrontX, spineFrontY = point(fish.size * 1.05, 0)
    local spineMidX, spineMidY = point(0, 0)
    local tailBaseX, tailBaseY = point(-fish.size * 0.95, 0)
    local tailTopX, tailTopY = point(-fish.size * 1.55, fish.size * 0.68)
    local tailBottomX, tailBottomY = point(-fish.size * 1.55, -fish.size * 0.68)
    local dorsalStartX, dorsalStartY = point(-fish.size * 0.15, fish.size * 0.25)
    local dorsalEndX, dorsalEndY = point(fish.size * 0.4, fish.size * 0.72)
    local bellyStartX, bellyStartY = point(-fish.size * 0.1, -fish.size * 0.2)
    local bellyEndX, bellyEndY = point(fish.size * 0.38, -fish.size * 0.62)
    local noseX, noseY = point(fish.size * 1.35, 0)
    local eyeX, eyeY = point(fish.size * 0.65, fish.size * 0.24)

    for step = 0, 6 do
        local t = step / 6
        local fillX = tailTopX + ((tailBottomX - tailTopX) * t)
        local fillY = tailTopY + ((tailBottomY - tailTopY) * t)
        gfx.drawLine(tailBaseX, tailBaseY, fillX, fillY)
    end
    gfx.drawLine(tailTopX, tailTopY, tailBaseX, tailBaseY)
    gfx.drawLine(tailBottomX, tailBottomY, tailBaseX, tailBaseY)
    gfx.drawLine(tailTopX, tailTopY, tailBottomX, tailBottomY)
    gfx.fillCircleAtPoint(spineMidX, spineMidY, math.max(2, fish.size * 0.62))
    gfx.fillCircleAtPoint(spineFrontX, spineFrontY, math.max(1, fish.size * 0.48))
    gfx.drawLine(spineMidX, spineMidY, noseX, noseY)
    gfx.drawLine(dorsalStartX, dorsalStartY, dorsalEndX, dorsalEndY)
    gfx.drawLine(bellyStartX, bellyStartY, bellyEndX, bellyEndY)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(eyeX, eyeY, 1)
    gfx.setColor(gfx.kColorWhite)
end

function FishPond:drawHud()
    if self.preview then
        return
    end

    local modeLabel = FishPond.getModeLabel(self.modeId)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawText(modeLabel, 10, 8)

    if self.modeId == FishPond.MODE_TANK then
        gfx.drawText(string.format("Current %.1f", self.currentStrength), 10, 24)
    elseif self.idleMode then
        gfx.drawText(string.format("Currency %d", FishPond.getIdleCurrency()), 10, 24)
        gfx.drawText(string.format("Fish %d  Bubbles %d", #self.fishes, #self.bubbles), 10, 40)
    else
        gfx.drawText(string.format("Fish %d  Bubbles %d", #self.fishes, #self.bubbles), 10, 24)
        local spawnModeLabel = FishPond.isSpawnModeEnabled() and "Spawn Mode On" or "Spawn Mode Off"
        gfx.drawText(spawnModeLabel, 10, 40)
    end

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function FishPond:draw()
    self:drawBackground()

    for _, bubble in ipairs(self.bubbles) do
        self:drawBubble(bubble)
    end

    self:drawBubbleMaker()

    for _, vent in ipairs(self.bubbleVents) do
        self:drawBubbleVent(vent)
    end

    for _, fish in ipairs(self.fishes) do
        self:drawFish(fish)
    end

    self:drawHud()
end
