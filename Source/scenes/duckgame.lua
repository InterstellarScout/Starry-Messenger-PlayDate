--[[
Duck Game scene.

Purpose:
- runs the single-player and multiplayer duck-and-chick collection modes
- manages nests, chick trails, stealing, scoring, and victory conditions
- handles pdportal lobby flow for multiplayer races
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

local DUCK_SPEED <const> = 82
local BOT_DUCK_SPEED <const> = 74
local CRANK_DRIVE_THRESHOLD <const> = 0.01
local COLLECT_RADIUS <const> = 12
local STEAL_RADIUS <const> = 11
local NEST_RADIUS <const> = 16
local TRAIL_HISTORY_STEP <const> = 5
local TRAIL_HISTORY_GAP <const> = 3
local WRAP_MARGIN <const> = 8
local DELIVERY_CHICK_SPEED <const> = 92
local TARGET_FREE_CHICKS <const> = 18
local MIN_FREE_CHICKS <const> = 12
local SNAPSHOT_INTERVAL_FRAMES <const> = 2
local WIN_SCORE <const> = 50

local PLAYFIELD_LEFT <const> = 16
local PLAYFIELD_TOP <const> = 18
local PLAYFIELD_RIGHT <const> = 384
local PLAYFIELD_BOTTOM <const> = 222
local POND_CENTER_X <const> = 200
local POND_CENTER_Y <const> = 120
local CENTER_NEST_X <const> = 200
local CENTER_NEST_Y <const> = 120

local SLOT_LAYOUT <const> = {
    [1] = { nestX = 42, nestY = 42, startX = 184, startY = 110, label = "P1" },
    [2] = { nestX = 358, nestY = 42, startX = 216, startY = 110, label = "P2" },
    [3] = { nestX = 42, nestY = 198, startX = 184, startY = 134, label = "P3" },
    [4] = { nestX = 358, nestY = 198, startX = 216, startY = 134, label = "P4" }
}

local NPC_TONE_BY_SLOT <const> = {
    [1] = 1.0,
    [2] = 0.85,
    [3] = 0.65,
    [4] = 0.45
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

local function squaredDistance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return (dx * dx) + (dy * dy)
end

local function length(x, y)
    return math.sqrt((x * x) + (y * y))
end

local function normalize(x, y)
    local magnitude = length(x, y)
    if magnitude <= 0.0001 then
        return 0, 0
    end
    return x / magnitude, y / magnitude
end

local function wrapAxis(value, minValue, maxValue, margin)
    local low = minValue - margin
    local high = maxValue + margin
    if value < low then
        return high, true
    elseif value > high then
        return low, true
    end
    return value, false
end

local function isPointInsidePlayfield(x, y)
    return x >= (PLAYFIELD_LEFT + 12)
        and x <= (PLAYFIELD_RIGHT - 12)
        and y >= (PLAYFIELD_TOP + 12)
        and y <= (PLAYFIELD_BOTTOM - 12)
end

local function isPointNearNest(x, y)
    for slot = 1, 4 do
        local nest = SLOT_LAYOUT[slot]
        if squaredDistance(x, y, nest.nestX, nest.nestY) <= ((NEST_RADIUS + 18) * (NEST_RADIUS + 18)) then
            return true
        end
    end
    return false
end

local function randomPondPoint()
    while true do
        local x = PLAYFIELD_LEFT + 14 + (math.random() * ((PLAYFIELD_RIGHT - PLAYFIELD_LEFT) - 28))
        local y = PLAYFIELD_TOP + 14 + (math.random() * ((PLAYFIELD_BOTTOM - PLAYFIELD_TOP) - 28))
        if isPointInsidePlayfield(x, y) and not isPointNearNest(x, y) then
            return x, y
        end
    end
end

local function createPlayer(slot, controlKind)
    local layout = SLOT_LAYOUT[slot]
    local facingX = (slot == 1 or slot == 3) and -1 or 1
    return {
        slot = slot,
        x = layout.startX,
        y = layout.startY,
        inputX = 0,
        inputY = 0,
        moving = false,
        facingX = facingX,
        facingY = 0,
        controlKind = controlKind or "remote",
        score = 0,
        chicks = {},
        trailHistory = {
            {
                x = layout.startX,
                y = layout.startY,
                wrapped = false
            }
        },
        botTargetX = layout.startX,
        botTargetY = layout.startY,
        botWanderTimer = 0
    }
end

DuckGameScene = {}
DuckGameScene.__index = DuckGameScene

DuckGameScene.MODE_SOLO_2 = "solo-2"
DuckGameScene.MODE_SOLO_3 = "solo-3"
DuckGameScene.MODE_SOLO_4 = "solo-4"
DuckGameScene.MODE_SOLO_CENTER = "solo-center"

function DuckGameScene.getModeLabel(modeId)
    if modeId == DuckGameScene.MODE_SOLO_CENTER then
        return "Duck Game"
    elseif modeId == DuckGameScene.MODE_SOLO_2 then
        return "Two Ducks"
    elseif modeId == DuckGameScene.MODE_SOLO_3 then
        return "Three Ducks"
    end
    return "Four Ducks"
end

function DuckGameScene.getSoloDuckCount(modeId)
    if modeId == DuckGameScene.MODE_SOLO_CENTER then
        return 1
    elseif modeId == DuckGameScene.MODE_SOLO_2 then
        return 2
    elseif modeId == DuckGameScene.MODE_SOLO_3 then
        return 3
    end
    return 4
end

function DuckGameScene.new(config)
    local self = setmetatable({}, DuckGameScene)
    self.onReturnToTitle = config.onReturnToTitle
    self.preview = config.preview == true
    self.multiplayer = config.multiplayer == true
    self.modeId = config.modeId or DuckGameScene.MODE_SOLO_4
    self.portalService = config.portalService
    self.networked = self.multiplayer and self.portalService ~= nil
    self.playerCount = self.multiplayer
        and clamp(config.playerCount or 2, 2, 4)
        or DuckGameScene.getSoloDuckCount(self.modeId)
    self.localSlot = 1
    self.mode = self.networked and "lobby" or "game"
    self.state = "playing"
    self.winnerSlot = nil
    self.winMessage = nil
    self.activeSlots = {}
    self.players = {}
    self.freeChicks = {}
    self.reeds = {}
    self.ripples = {}
    self.nestPixels = {}
    self.frame = 0
    self.remoteState = nil
    self.statusMessage = self.networked and "Open pdportal in the browser and connect the selected ducks." or "Race to 50 chicks."
    self.smallFont = gfx.getSystemFont()
    self.lastSentInputX = 0
    self.lastSentInputY = 0
    self.lastSentMoving = false
    self.winBackground = Starfield.newWarpSpeed(400, 240, 180)
    self.winBackground.speed = 9

    if self.preview then
        self:resetMatch(self.multiplayer and "networked" or "single", 1)
    elseif not self.networked then
        self:resetMatch("single", 1)
    end
    return self
end

function DuckGameScene:isCenterNestMode()
    return not self.multiplayer and self.modeId == DuckGameScene.MODE_SOLO_CENTER
end

function DuckGameScene:getTargetGoal()
    if self:isCenterNestMode() then
        return TARGET_FREE_CHICKS
    end
    return WIN_SCORE
end

function DuckGameScene:getNestPosition(slot)
    if self:isCenterNestMode() then
        return CENTER_NEST_X, CENTER_NEST_Y
    end

    local nest = SLOT_LAYOUT[slot]
    return nest.nestX, nest.nestY
end

function DuckGameScene:activate()
    if self.preview then
        return
    end

    if self.networked then
        self.portalService:beginLobby("duck", self.playerCount, self)
        self.statusMessage = "Open pdportal in the browser and connect the selected ducks."
    end
end

function DuckGameScene:shutdown()
    if self.networked and self.portalService ~= nil then
        self.portalService:endSession()
    end
end

function DuckGameScene:onPortalStatusChanged()
    if not self.networked then
        return
    end

    if not self.portalService.isSerialConnected then
        self.statusMessage = "Serial disconnected. Open pdportal and connect USB."
    elseif not self.portalService.isPeerOpen then
        self.statusMessage = "Serial live. Waiting for peer handshake."
    elseif self.portalService:isClient() and self.portalService.current and self.portalService.current.hostPeerId == nil then
        self.statusMessage = "Peer ready. Use pdportal to join the host."
    elseif self.mode == "lobby" and self.portalService:isHost() then
        self.statusMessage = string.format("Host ready. %d/%d ducks connected.", self.portalService:getConnectedCount(), self.playerCount)
    elseif self.mode == "lobby" then
        self.statusMessage = "Connected to host. Waiting for the race."
    end
end

function DuckGameScene:onPortalDisconnected()
    self.mode = "lobby"
    self.remoteState = nil
    self.statusMessage = "pdportal disconnected."
end

function DuckGameScene:onPortalPeerAssigned(_remotePeerId, slot)
    self.statusMessage = "Ducky " .. tostring(slot) .. " joined the pond."
end

function DuckGameScene:onPortalPeerDisconnected(_remotePeerId, slot)
    self.mode = "lobby"
    self.remoteState = nil
    self.statusMessage = "Ducky " .. tostring(slot) .. " disconnected."
end

function DuckGameScene:onPortalHostDisconnected(_remotePeerId)
    self.mode = "lobby"
    self.remoteState = nil
    self.statusMessage = "Host disconnected."
end

function DuckGameScene:onPortalMessage(remotePeerId, message)
    if message.type == "assigned" then
        self.localSlot = self.portalService:getAssignedSlot()
        self.statusMessage = "Joined as " .. SLOT_LAYOUT[self.localSlot].label .. ". Waiting for host."
    elseif message.type == "lobby" then
        self.localSlot = self.portalService:getAssignedSlot()
        self.statusMessage = string.format("Lobby synced. %d/%d ducks ready.", self.portalService:getConnectedCount(), self.playerCount)
    elseif message.type == "full" then
        self.statusMessage = "That pond is already full."
    elseif (message.type == "start" or message.type == "snapshot") and self.portalService:isClient() then
        self.remoteState = message.state
        self.mode = "game"
        self.state = message.state and message.state.state or "playing"
        self.winnerSlot = message.state and message.state.winnerSlot or nil
        self.statusMessage = "Client pond running."
    elseif message.type == "input" and self.portalService:isHost() then
        local slot = self.portalService:getSlotForPeer(remotePeerId)
        local player = slot and self.players[slot] or nil
        if player ~= nil then
            player.inputX = tonumber(message.dx) or 0
            player.inputY = tonumber(message.dy) or 0
            player.moving = message.moving == 1 or message.moving == true
        end
    end
end

function DuckGameScene:addRipple(x, y, radius)
    self.ripples[#self.ripples + 1] = {
        x = x,
        y = y,
        radius = radius or 4,
        age = 0
    }
end

function DuckGameScene:addNestPixel(slot)
    local nestX, nestY = self:getNestPosition(slot)
    self.nestPixels[slot] = self.nestPixels[slot] or {}
    self.nestPixels[slot][#self.nestPixels[slot] + 1] = {
        x = nestX + math.random(-10, 10),
        y = nestY + math.random(-10, 10)
    }
end

function DuckGameScene:addFreeChick(x, y)
    local chickX = x
    local chickY = y
    if chickX == nil or chickY == nil then
        chickX, chickY = randomPondPoint()
    end

    self.freeChicks[#self.freeChicks + 1] = {
        x = chickX,
        y = chickY,
        homeX = chickX,
        homeY = chickY,
        vx = 0,
        vy = 0,
        seed = math.random() * (math.pi * 2)
    }
    self:addRipple(chickX, chickY, 2)
end

function DuckGameScene:seedPondDecor()
    self.reeds = {}
    for index = 1, 8 do
        local x, y = randomPondPoint()
        self.reeds[index] = {
            x = x,
            y = y,
            height = 7 + math.random(0, 8),
            seed = math.random() * (math.pi * 2)
        }
    end
end

function DuckGameScene:resetMatch(modeId, localSlot)
    self.activeSlots = {}
    self.players = {}
    self.freeChicks = {}
    self.ripples = {}
    self.nestPixels = {}
    self.frame = 0
    self.state = "playing"
    self.winnerSlot = nil
    self.winMessage = nil
    self.localSlot = localSlot or 1

    local activeCount = modeId == "single" and DuckGameScene.getSoloDuckCount(self.modeId) or self.playerCount
    self.playerCount = activeCount
    self.statusMessage = self:isCenterNestMode() and "Keep bringing chicks to the center nest." or "Race to 50 chicks."

    for slot = 1, activeCount do
        self.activeSlots[#self.activeSlots + 1] = slot
        self.nestPixels[slot] = {}
        local controlKind = "remote"
        if modeId == "single" then
            controlKind = slot == self.localSlot and "local" or "bot"
        elseif slot == self.localSlot then
            controlKind = "local"
        end
        self.players[slot] = createPlayer(slot, controlKind)
    end

    self:seedPondDecor()
    for _ = 1, self:getTargetGoal() do
        self:addFreeChick()
    end
end

function DuckGameScene:pushTrailPoint(player, wrapped)
    local history = player.trailHistory
    local lastPoint = history[1]
    if lastPoint ~= nil and not wrapped then
        local dx = player.x - lastPoint.x
        local dy = player.y - lastPoint.y
        if ((dx * dx) + (dy * dy)) < (TRAIL_HISTORY_STEP * TRAIL_HISTORY_STEP) then
            return
        end
    end

    table.insert(history, 1, {
        x = player.x,
        y = player.y,
        wrapped = wrapped == true
    })

    local maxPoints = math.max(24, (#player.chicks + 2) * TRAIL_HISTORY_GAP)
    while #history > maxPoints do
        table.remove(history)
    end
end

function DuckGameScene:wrapPlayerPosition(player)
    local wrappedX
    local wrappedY
    local xWrapped
    local yWrapped

    wrappedX, xWrapped = wrapAxis(player.x, PLAYFIELD_LEFT + WRAP_MARGIN, PLAYFIELD_RIGHT - WRAP_MARGIN, WRAP_MARGIN)
    wrappedY, yWrapped = wrapAxis(player.y, PLAYFIELD_TOP + WRAP_MARGIN, PLAYFIELD_BOTTOM - WRAP_MARGIN, WRAP_MARGIN)
    player.x = wrappedX
    player.y = wrappedY

    if xWrapped or yWrapped then
        self:pushTrailPoint(player, true)
    end
end

function DuckGameScene:startHostMatch()
    self.mode = "game"
    self.remoteState = nil
    self:resetMatch("networked", 1)
    local state = self:serializeState()
    self.portalService:broadcast({
        type = "start",
        state = state
    })
    self.statusMessage = "Host pond running."
end

function DuckGameScene:updateBotInput(player)
    local targetX = nil
    local targetY = nil

    if #player.chicks > 0 then
        local nest = SLOT_LAYOUT[player.slot]
        targetX = nest.nestX
        targetY = nest.nestY
    else
        local nearestTrail = nil
        local nearestTrailDistanceSquared = math.huge
        for _, defenderSlot in ipairs(self.activeSlots) do
            if defenderSlot ~= player.slot then
                local defender = self.players[defenderSlot]
                if defender ~= nil then
                    for _, chick in ipairs(defender.chicks) do
                        local distanceSquared = squaredDistance(player.x, player.y, chick.x, chick.y)
                        if distanceSquared < nearestTrailDistanceSquared then
                            nearestTrailDistanceSquared = distanceSquared
                            nearestTrail = chick
                        end
                    end
                end
            end
        end

        if nearestTrail ~= nil and nearestTrailDistanceSquared < (80 * 80) then
            targetX = nearestTrail.x
            targetY = nearestTrail.y
        else
            local nearestChick = nil
            local nearestDistanceSquared = math.huge
            for _, chick in ipairs(self.freeChicks) do
                local distanceSquared = squaredDistance(player.x, player.y, chick.x, chick.y)
                if distanceSquared < nearestDistanceSquared then
                    nearestDistanceSquared = distanceSquared
                    nearestChick = chick
                end
            end

            if nearestChick ~= nil then
                targetX = nearestChick.x
                targetY = nearestChick.y
            else
                if player.botWanderTimer <= 0 then
                    player.botTargetX, player.botTargetY = randomPondPoint()
                    player.botWanderTimer = 20 + math.random(0, 30)
                end
                targetX = player.botTargetX
                targetY = player.botTargetY
            end
        end
    end

    player.botWanderTimer = math.max(0, player.botWanderTimer - 1)
    local inputX, inputY = normalize((targetX or player.x) - player.x, (targetY or player.y) - player.y)
    player.inputX = inputX
    player.inputY = inputY
    player.moving = true
end

function DuckGameScene:readCurrentInput()
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
    return inputX, inputY
end

function DuckGameScene:updateLocalInput()
    local player = self.players[self.localSlot]
    if player == nil then
        return
    end

    local _, acceleratedChange = pd.getCrankChange()
    local inputX, inputY = self:readCurrentInput()
    local normalizedX, normalizedY = normalize(inputX, inputY)
    local hasDirectionalInput = math.abs(normalizedX) > 0.001 or math.abs(normalizedY) > 0.001
    local crankDriving = math.abs(acceleratedChange) > CRANK_DRIVE_THRESHOLD

    if hasDirectionalInput then
        player.inputX = normalizedX
        player.inputY = normalizedY
        player.moving = true
    elseif crankDriving and (math.abs(player.inputX) > 0.001 or math.abs(player.inputY) > 0.001) then
        player.moving = true
    else
        player.moving = false
    end
end

function DuckGameScene:sendClientInput()
    if not self.networked or not self.portalService:isClient() or self.portalService.current == nil or self.portalService.current.hostPeerId == nil then
        return
    end

    self:updateLocalInput()
    local player = self.players[self.localSlot]
    if player == nil then
        return
    end

    if player.inputX ~= self.lastSentInputX or player.inputY ~= self.lastSentInputY or player.moving ~= self.lastSentMoving then
        self.lastSentInputX = player.inputX
        self.lastSentInputY = player.inputY
        self.lastSentMoving = player.moving
        self.portalService:sendPayload(self.portalService.current.hostPeerId, {
            type = "input",
            dx = player.inputX,
            dy = player.inputY,
            moving = player.moving and 1 or 0
        })
    end
end

function DuckGameScene:updatePlayerMovement(player, dt)
    local speed = player.controlKind == "bot" and BOT_DUCK_SPEED or DUCK_SPEED
    local inputX, inputY = normalize(player.inputX, player.inputY)
    local moveX = player.moving and inputX or 0
    local moveY = player.moving and inputY or 0
    player.x = player.x + (moveX * speed * dt)
    player.y = player.y + (moveY * speed * dt)

    if math.abs(inputX) > 0.001 or math.abs(inputY) > 0.001 then
        player.facingX = inputX
        player.facingY = inputY
    end

    self:wrapPlayerPosition(player)
    self:pushTrailPoint(player, false)
end

function DuckGameScene:updateFreeChicks(dt)
    for _, chick in ipairs(self.freeChicks) do
        local swayX = math.cos((self.frame * 0.03) + chick.seed) * 3.5
        local swayY = math.sin((self.frame * 0.02) + chick.seed) * 2.5
        local targetX = chick.homeX + swayX
        local targetY = chick.homeY + swayY
        chick.vx = (chick.vx + ((targetX - chick.x) * 2.0 * dt)) * 0.88
        chick.vy = (chick.vy + ((targetY - chick.y) * 2.0 * dt)) * 0.88
        chick.x = clamp(chick.x + chick.vx, PLAYFIELD_LEFT + 10, PLAYFIELD_RIGHT - 10)
        chick.y = clamp(chick.y + chick.vy, PLAYFIELD_TOP + 10, PLAYFIELD_BOTTOM - 10)
    end
end

function DuckGameScene:updateTrails()
    for _, slot in ipairs(self.activeSlots) do
        local player = self.players[slot]
        if player ~= nil then
            local history = player.trailHistory or {}
            for chickIndex, chick in ipairs(player.chicks) do
                if chick.state ~= "delivering" then
                    local historyIndex = math.min(#history, 1 + (chickIndex * TRAIL_HISTORY_GAP))
                    local targetPoint = history[historyIndex] or history[#history]
                    if targetPoint ~= nil then
                        if targetPoint.wrapped == true then
                            chick.x = targetPoint.x
                            chick.y = targetPoint.y
                        else
                            chick.x = chick.x + ((targetPoint.x - chick.x) * 0.24)
                            chick.y = chick.y + ((targetPoint.y - chick.y) * 0.24)
                        end
                    end
                end
            end
        end
    end
end

function DuckGameScene:updateDeliveringChicks(dt)
    for _, slot in ipairs(self.activeSlots) do
        local player = self.players[slot]
        if player ~= nil then
            local nestX, nestY = self:getNestPosition(slot)
            for chickIndex = #player.chicks, 1, -1 do
                local chick = player.chicks[chickIndex]
                if chick.state == "delivering" then
                    local directionX, directionY = normalize(nestX - chick.x, nestY - chick.y)
                    chick.x = chick.x + (directionX * DELIVERY_CHICK_SPEED * dt)
                    chick.y = chick.y + (directionY * DELIVERY_CHICK_SPEED * dt)

                    if squaredDistance(chick.x, chick.y, nestX, nestY) <= ((NEST_RADIUS - 3) * (NEST_RADIUS - 3)) then
                        table.remove(player.chicks, chickIndex)
                        player.score = player.score + 1
                        self:addNestPixel(slot)
                        self:addRipple(chick.x, chick.y, 2)

                        if not self:isCenterNestMode() and player.score >= self:getTargetGoal() and self.state ~= "finished" then
                            self.state = "finished"
                            self.winnerSlot = slot
                            self.winMessage = string.format("Ducky %d Wins!", slot)
                            self.statusMessage = string.format("Ducky %d wins.", slot)
                            return
                        end
                    end
                end
            end
        end
    end
end

function DuckGameScene:collectFreeChicks()
    for chickIndex = #self.freeChicks, 1, -1 do
        local chick = self.freeChicks[chickIndex]
        for _, slot in ipairs(self.activeSlots) do
            local player = self.players[slot]
            if player ~= nil and squaredDistance(player.x, player.y, chick.x, chick.y) <= (COLLECT_RADIUS * COLLECT_RADIUS) then
                player.chicks[#player.chicks + 1] = {
                    x = chick.x,
                    y = chick.y,
                    seed = chick.seed,
                    state = "trail"
                }
                self:addRipple(chick.x, chick.y, 3)
                table.remove(self.freeChicks, chickIndex)
                break
            end
        end
    end
end

function DuckGameScene:stealTrailSegments()
    for _, attackerSlot in ipairs(self.activeSlots) do
        local attacker = self.players[attackerSlot]
        if attacker ~= nil then
            for _, defenderSlot in ipairs(self.activeSlots) do
                if attackerSlot ~= defenderSlot then
                    local defender = self.players[defenderSlot]
                    if defender ~= nil and #defender.chicks > 0 then
                        for chickIndex = 1, #defender.chicks do
                            local chick = defender.chicks[chickIndex]
                            if chick.state ~= "delivering" and squaredDistance(attacker.x, attacker.y, chick.x, chick.y) <= (STEAL_RADIUS * STEAL_RADIUS) then
                                while #defender.chicks >= chickIndex do
                                    local stolenChick = table.remove(defender.chicks, chickIndex)
                                    stolenChick.state = "trail"
                                    attacker.chicks[#attacker.chicks + 1] = stolenChick
                                    self:addRipple(stolenChick.x, stolenChick.y, 4)
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end

function DuckGameScene:deliverChicks()
    for _, slot in ipairs(self.activeSlots) do
        local player = self.players[slot]
        local nestX, nestY = self:getNestPosition(slot)
        if player ~= nil and squaredDistance(player.x, player.y, nestX, nestY) <= (NEST_RADIUS * NEST_RADIUS) then
            local startedDelivery = false
            for _, chick in ipairs(player.chicks) do
                if chick.state ~= "delivering" then
                    chick.state = "delivering"
                    startedDelivery = true
                end
            end
            if startedDelivery then
                self:addRipple(nestX, nestY, 6)
            end
        end
    end
end

function DuckGameScene:updateRipples()
    for index = #self.ripples, 1, -1 do
        local ripple = self.ripples[index]
        ripple.age = ripple.age + 1
        ripple.radius = ripple.radius + 0.5
        if ripple.age > 18 then
            table.remove(self.ripples, index)
        end
    end
end

function DuckGameScene:serializeState()
    local players = {}
    for _, slot in ipairs(self.activeSlots) do
        local player = self.players[slot]
        if player ~= nil then
            local chicks = {}
            for chickIndex, chick in ipairs(player.chicks) do
                chicks[chickIndex] = {
                    x = chick.x,
                    y = chick.y,
                    seed = chick.seed,
                    state = chick.state
                }
            end
            players[#players + 1] = {
                slot = player.slot,
                x = player.x,
                y = player.y,
                facingX = player.facingX,
                facingY = player.facingY,
                score = player.score,
                chicks = chicks
            }
        end
    end

    local freeChicks = {}
    for chickIndex, chick in ipairs(self.freeChicks) do
        freeChicks[chickIndex] = {
            x = chick.x,
            y = chick.y,
            seed = chick.seed
        }
    end

    local ripples = {}
    for rippleIndex, ripple in ipairs(self.ripples) do
        ripples[rippleIndex] = {
            x = ripple.x,
            y = ripple.y,
            radius = ripple.radius,
            age = ripple.age
        }
    end

    local reeds = {}
    for reedIndex, reed in ipairs(self.reeds) do
        reeds[reedIndex] = {
            x = reed.x,
            y = reed.y,
            height = reed.height,
            seed = reed.seed
        }
    end

    local nestPixels = {}
    for slot, pixels in pairs(self.nestPixels or {}) do
        nestPixels[slot] = {}
        for pixelIndex, pixel in ipairs(pixels) do
            nestPixels[slot][pixelIndex] = {
                x = pixel.x,
                y = pixel.y
            }
        end
    end

    return {
        state = self.state,
        frame = self.frame,
        winnerSlot = self.winnerSlot,
        winMessage = self.winMessage,
        centerNestMode = self:isCenterNestMode(),
        players = players,
        freeChicks = freeChicks,
        ripples = ripples,
        reeds = reeds,
        nestPixels = nestPixels,
        targetScore = self:getTargetGoal()
    }
end

function DuckGameScene:getRenderState()
    if self.networked and self.portalService:isClient() then
        return self.remoteState
    end
    return self:serializeState()
end

function DuckGameScene:updateLocalGame()
    local dt = 1 / 30
    self.frame = self.frame + 1

    if self.state == "finished" then
        return
    end

    self:updateLocalInput()

    for _, slot in ipairs(self.activeSlots) do
        local player = self.players[slot]
        if player ~= nil and player.controlKind == "bot" then
            self:updateBotInput(player)
        end
        if player ~= nil then
            self:updatePlayerMovement(player, dt)
        end
    end

    self:updateFreeChicks(dt)
    self:updateTrails()
    self:collectFreeChicks()
    self:stealTrailSegments()
    self:deliverChicks()
    self:updateDeliveringChicks(dt)
    self:updateRipples()

    while self.state ~= "finished" and #self.freeChicks < MIN_FREE_CHICKS do
        self:addFreeChick()
    end
end

function DuckGameScene:drawNestPixels(pixels)
    for _, pixel in ipairs(pixels or {}) do
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(pixel.x, pixel.y, 1, 1)
        gfx.setImageDrawMode(gfx.kDrawModeNXOR)
        gfx.fillRect(pixel.x + 1, pixel.y, 1, 1)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end
end

function DuckGameScene:applyDitherFill(amount)
    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(amount, gfx.image.kDitherTypeBayer8x8)
end

function DuckGameScene:resetFillStyle()
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    gfx.setColor(gfx.kColorBlack)
end

function DuckGameScene:getDuckTone(slot)
    if slot == self.localSlot then
        return nil
    end
    return NPC_TONE_BY_SLOT[slot] or 0.6
end

function DuckGameScene:getDuckScale(player)
    if player.slot == self.localSlot then
        return 2.0
    end
    return 1.5
end

function DuckGameScene:drawPondBackdrop()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(PLAYFIELD_LEFT, PLAYFIELD_TOP, PLAYFIELD_RIGHT - PLAYFIELD_LEFT, PLAYFIELD_BOTTOM - PLAYFIELD_TOP)
    gfx.drawLine(PLAYFIELD_LEFT, PLAYFIELD_TOP, PLAYFIELD_RIGHT, PLAYFIELD_TOP)
    gfx.drawLine(PLAYFIELD_LEFT, PLAYFIELD_BOTTOM, PLAYFIELD_RIGHT, PLAYFIELD_BOTTOM)
end

function DuckGameScene:drawReeds(reeds, time)
    gfx.setColor(gfx.kColorBlack)
    for _, reed in ipairs(reeds or {}) do
        local sway = math.sin((time * 0.035) + reed.seed) * 1.4
        gfx.drawLine(reed.x - 2, reed.y + 3, reed.x + sway, reed.y - reed.height)
        gfx.drawLine(reed.x + 1, reed.y + 3, reed.x + sway + 1, reed.y - (reed.height - 3))
    end
end

function DuckGameScene:drawRipple(ripple)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawCircleAtPoint(ripple.x, ripple.y, ripple.radius)
end

function DuckGameScene:drawFreeChick(chick, time)
    local bob = math.sin((time * 0.05) + chick.seed) * 1.2
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(chick.x - 1, chick.y - 1 + bob, 3, 3)
end

function DuckGameScene:drawShadedRect(x, y, width, height, tone, outlined)
    if tone == nil then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(x, y, width, height)
    else
        self:applyDitherFill(tone)
        gfx.fillRect(x, y, width, height)
        self:resetFillStyle()
    end

    if outlined ~= false then
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(x, y, width, height)
    end
end

function DuckGameScene:drawDuck(player)
    local duckX = math.floor(player.x + 0.5)
    local duckY = math.floor(player.y + 0.5)
    local facingX = player.facingX
    local facingY = player.facingY
    if math.abs(facingX) < 0.01 and math.abs(facingY) < 0.01 then
        facingX = 1
        facingY = 0
    end

    local tone = self:getDuckTone(player.slot)
    local scale = self:getDuckScale(player)
    local bodyWidth = math.max(10, math.floor(10 * scale))
    local bodyHeight = math.max(8, math.floor(8 * scale))
    local headSize = math.max(5, math.floor(5 * scale))
    local tailSize = math.max(3, math.floor(3 * scale))
    local headOffsetX = facingX * math.floor(5 * scale)
    local headOffsetY = facingY * math.floor(5 * scale)
    local tailOffsetX = -facingX * math.floor(6 * scale)
    local tailOffsetY = -facingY * math.floor(6 * scale)

    self:drawShadedRect(duckX - math.floor(bodyWidth * 0.5), duckY - math.floor(bodyHeight * 0.5), bodyWidth, bodyHeight, tone, true)
    self:drawShadedRect(duckX + headOffsetX - math.floor(headSize * 0.5), duckY + headOffsetY - math.floor(headSize * 0.5), headSize, headSize, tone, true)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(duckX + tailOffsetX - math.floor(tailSize * 0.5), duckY + tailOffsetY - math.floor(tailSize * 0.5), tailSize, tailSize)
end

function DuckGameScene:drawTrail(chicks, slot, time)
    local tone = slot == self.localSlot and 0.2 or self:getDuckTone(slot)
    for index, chick in ipairs(chicks or {}) do
        local bob = math.sin((time * 0.06) + chick.seed + index) * 1
        self:drawShadedRect(chick.x - 2, chick.y - 2 + bob, 4, 4, tone, true)
    end
end

function DuckGameScene:drawNest(slot, score, pixels)
    local x, y = self:getNestPosition(slot)
    gfx.setColor(gfx.kColorBlack)
    for index = 0, 5 do
        local offset = -10 + (index * 4)
        gfx.drawLine(x - 10, y + offset, x + 10, y + offset + 2)
    end
    gfx.drawCircleAtPoint(x, y, NEST_RADIUS)
    gfx.drawCircleAtPoint(x, y, NEST_RADIUS - 4)
    gfx.fillCircleAtPoint(x - 6, y - 2, 2)
    gfx.fillCircleAtPoint(x + 2, y + 4, 2)
    gfx.fillCircleAtPoint(x + 7, y - 4, 2)
    self:drawNestPixels(pixels)
    gfx.setImageDrawMode(gfx.kDrawModeNXOR)
    gfx.drawTextAligned(tostring(score or 0), x, y - 6, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.drawTextAligned(self:isCenterNestMode() and "Nest" or tostring(slot), x, y + 12, kTextAlignment.center)
end

function DuckGameScene:drawLobby()
    gfx.clear(gfx.kColorBlack)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawTextAligned("Multiplayer Duck Game", 200, 22, kTextAlignment.center)
    gfx.drawTextAligned(string.format("Selected ducks: %d", self.playerCount), 200, 40, kTextAlignment.center)

    local serialText = self.portalService.isSerialConnected and "Serial: connected to pdportal" or "Serial: connect USB and open pdportal"
    local peerText = self.portalService.isPeerOpen and ("Peer ID: " .. tostring(self.portalService.peerId)) or "Peer ID: waiting for portal handshake"
    gfx.drawTextAligned(serialText, 200, 76, kTextAlignment.center)
    gfx.drawTextAligned(peerText, 200, 92, kTextAlignment.center)

    local lobbySlots = self.portalService:getLobbySlots()
    for slot = 1, self.playerCount do
        local label = SLOT_LAYOUT[slot].label .. "  waiting"
        if slot == self.portalService:getAssignedSlot() then
            label = SLOT_LAYOUT[slot].label .. "  you"
        elseif self.portalService:isHost() and slot == 1 then
            label = SLOT_LAYOUT[slot].label .. "  host"
        elseif lobbySlots[slot] then
            label = SLOT_LAYOUT[slot].label .. "  connected"
        end
        gfx.drawTextAligned(label, 200, 118 + ((slot - 1) * 16), kTextAlignment.center)
    end

    gfx.drawTextAligned(self.statusMessage or "", 200, 194, kTextAlignment.center)
    if self.portalService:isHost() then
        gfx.drawTextAligned("Press A to start when every selected duck is connected.", 200, 210, kTextAlignment.center)
    else
        gfx.drawTextAligned("Join the host from pdportal and wait for the start.", 200, 210, kTextAlignment.center)
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function DuckGameScene:drawHudFromState(state)
    gfx.setFont(self.smallFont)
    gfx.setColor(gfx.kColorBlack)
    if state.centerNestMode then
        gfx.drawTextAligned("Bring Birds Home", 200, 4, kTextAlignment.center)
    else
        gfx.drawTextAligned(string.format("First to %d", state.targetScore or WIN_SCORE), 200, 4, kTextAlignment.center)
    end
    if self.networked then
        gfx.drawText("pdportal live", 10, 4)
    end
end

function DuckGameScene:drawWinner(state)
    self.winBackground:update()
    self.winBackground:draw()

    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.55, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(26, 82, 348, 76)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawTextAligned(state.winMessage or string.format("Ducky %d Wins!", state.winnerSlot or 1), 200, 106, kTextAlignment.center)
    gfx.drawTextAligned("Press B to return to the title.", 200, 126, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function DuckGameScene:drawGameState(state)
    if state.state == "finished" then
        self:drawWinner(state)
        return
    end

    local time = state.frame or 0
    self:drawPondBackdrop()
    self:drawReeds(state.reeds or {}, time)

    local nestCount = state.centerNestMode and 1 or self.playerCount
    for slot = 1, nestCount do
        local score = 0
        for _, player in ipairs(state.players or {}) do
            if player.slot == slot then
                score = player.score
                break
            end
        end
        self:drawNest(slot, score, state.nestPixels and state.nestPixels[slot] or nil)
    end

    for _, chick in ipairs(state.freeChicks or {}) do
        self:drawFreeChick(chick, time)
    end

    for _, player in ipairs(state.players or {}) do
        self:drawTrail(player.chicks, player.slot, time)
    end

    for _, player in ipairs(state.players or {}) do
        self:drawDuck(player)
    end

    for _, ripple in ipairs(state.ripples or {}) do
        self:drawRipple(ripple)
    end

    self:drawHudFromState(state)
end

function DuckGameScene:draw()
    self:drawGameState(self:getRenderState())
end

function DuckGameScene:update()
    if self.preview then
        return
    end

    if pd.buttonJustPressed(pd.kButtonB) then
        if self.onReturnToTitle then
            self.onReturnToTitle("duck")
        end
        return
    end

    if self.networked then
        if self.mode == "lobby" then
            if pd.buttonJustPressed(pd.kButtonA) and self.portalService:isHost() then
                if self.portalService:isReadyToStart() then
                    self:startHostMatch()
                else
                    self.statusMessage = string.format("Waiting for %d ducks before launch.", self.playerCount)
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

    self:updateLocalGame()
    if self.networked and self.portalService:isHost() and (self.frame % SNAPSHOT_INTERVAL_FRAMES == 0) then
        self.portalService:broadcast({
            type = "snapshot",
            state = self:serializeState()
        })
    end
    self:draw()
end
