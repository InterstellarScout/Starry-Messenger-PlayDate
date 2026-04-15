--[[
Ant Farm effect.

Purpose:
- renders a hand-controlled ant farm with persistent tunnel carving
- lets the player drop ants into the soil while preview mode can auto-seed activity
- drives autonomous ant digging with a mild preference for connecting nearby tunnels
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

AntFarm = {}
AntFarm.__index = AntFarm

local FARM_TOP_RATIO <const> = 0.2
local HAND_SPEED <const> = 3.0
local HAND_CRANK_SCALE <const> = 0.18
local ANT_SPEED_MIN <const> = 1.0
local ANT_SPEED_MAX <const> = 1.7
local MAX_ANTS <const> = 18
local AUTO_DROP_FRAMES <const> = 70
local CONNECTION_RADIUS <const> = 12
local CONNECTION_ATTRACT_RADIUS <const> = 26
local CONNECTION_HOLD_MIN <const> = 18
local CONNECTION_HOLD_MAX <const> = 42
local TUNNEL_SAMPLE_GAP <const> = 4
local COURSE_FRAMES_MIN <const> = 8
local COURSE_FRAMES_MAX <const> = 18
local TUNNEL_BURST_FRAMES_MIN <const> = 18
local TUNNEL_BURST_FRAMES_MAX <const> = 44
local TUNNEL_COOLDOWN_MIN <const> = 16
local TUNNEL_COOLDOWN_MAX <const> = 42

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
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

local function lerp(a, b, t)
    return a + ((b - a) * t)
end

function AntFarm.new(width, height, options)
    local self = setmetatable({}, AntFarm)
    self.width = width
    self.height = height
    self.preview = options and options.preview == true or false
    self.farmTop = math.floor(height * FARM_TOP_RATIO)
    self.handX = width * 0.5
    self.handY = self.farmTop - 10
    self.inputX = 0
    self.inputY = 0
    self.ants = {}
    self.tunnelSamples = {}
    self.autoDropTimer = self.preview and 8 or AUTO_DROP_FRAMES
    self.tunnelImage = gfx.image.new(width, height, gfx.kColorClear)
    self.soilPattern = gfx.image.new(8, 8, gfx.kColorWhite)
    gfx.pushContext(self.soilPattern)
        gfx.clear(gfx.kColorWhite)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, 0, 8, 8)
        gfx.setDitherPattern(0.75, gfx.image.kDitherTypeBayer8x8)
        gfx.fillRect(0, 0, 8, 8)
        gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    gfx.popContext()

    if self.preview then
        for index = 1, 4 do
            local x = lerp(72, width - 72, (index - 0.5) / 4)
            self:dropAntAt(x, self.farmTop + 2)
        end
    end

    return self
end

local function pickCourseFrames()
    return COURSE_FRAMES_MIN + math.random(COURSE_FRAMES_MAX - COURSE_FRAMES_MIN)
end

local function pickTunnelCooldown()
    return TUNNEL_COOLDOWN_MIN + math.random(TUNNEL_COOLDOWN_MAX - TUNNEL_COOLDOWN_MIN)
end

local function pickTunnelBurstFrames()
    return TUNNEL_BURST_FRAMES_MIN + math.random(TUNNEL_BURST_FRAMES_MAX - TUNNEL_BURST_FRAMES_MIN)
end

function AntFarm:setPreview(isPreview)
    self.preview = isPreview == true
    self.autoDropTimer = self.preview and math.min(self.autoDropTimer, 12) or AUTO_DROP_FRAMES
end

function AntFarm:activate()
end

function AntFarm:shutdown()
    self.tunnelImage = nil
    self.soilPattern = nil
end

function AntFarm:setHandInput(inputX, inputY)
    self.inputX = inputX or 0
    self.inputY = inputY or 0
end

function AntFarm:moveHandByCrank(change)
    if math.abs(change or 0) < 0.01 then
        return
    end
    self.handX = clamp(self.handX + (change * HAND_CRANK_SCALE), 12, self.width - 12)
end

function AntFarm:dropAnt()
    self:dropAntAt(self.handX, self.farmTop + 2)
end

function AntFarm:dropAntAt(x, y)
    if #self.ants >= MAX_ANTS then
        return false
    end

    local directionX = (math.random() * 1.2) - 0.6
    local directionY = 1
    directionX, directionY = normalize(directionX, directionY)
    self.ants[#self.ants + 1] = {
        x = clamp(x, 10, self.width - 10),
        y = clamp(y, self.farmTop + 2, self.height - 6),
        dirX = directionX,
        dirY = directionY,
        speed = ANT_SPEED_MIN + (math.random() * (ANT_SPEED_MAX - ANT_SPEED_MIN)),
        tunnelCooldown = 4 + math.random(10),
        courseFrames = 2 + math.random(3),
        tunnelFrames = 0,
        state = "dig",
        holdTimer = 0,
        freshFrames = 36,
        targetX = x,
        targetY = y
    }
    return true
end

function AntFarm:recordTunnelSegment(x1, y1, x2, y2)
    if self.tunnelImage == nil then
        return
    end

    gfx.pushContext(self.tunnelImage)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawLine(x1, y1, x2, y2)
        gfx.fillRect(math.floor(x2 - 1), math.floor(y2 - 1), 3, 3)
    gfx.popContext()

    local dx = x2 - x1
    local dy = y2 - y1
    local segmentLength = math.max(1, length(dx, dy))
    local steps = math.max(1, math.floor(segmentLength / TUNNEL_SAMPLE_GAP))
    for step = 0, steps do
        local t = step / steps
        self.tunnelSamples[#self.tunnelSamples + 1] = {
            x = lerp(x1, x2, t),
            y = lerp(y1, y2, t)
        }
    end

    local maxSamples = 1800
    while #self.tunnelSamples > maxSamples do
        table.remove(self.tunnelSamples, 1)
    end
end

function AntFarm:pickDigDirection(ant, biasDownward)
    local directionX = (math.random() * 1.8) - 0.9
    local directionY
    if biasDownward then
        directionY = 0.55 + (math.random() * 0.95)
    else
        directionY = -0.35 + (math.random() * 1.25)
    end
    ant.dirX, ant.dirY = normalize(directionX, directionY)
    ant.courseFrames = pickCourseFrames()
end

function AntFarm:startTunnelBurst(ant)
    ant.state = "tunnel"
    ant.tunnelFrames = pickTunnelBurstFrames()
    ant.tunnelCooldown = pickTunnelCooldown()
    ant.targetX = clamp(ant.x + ((math.random() * 70) - 35), 8, self.width - 8)
    ant.targetY = clamp(ant.y + 14 + math.random(34), self.farmTop + 4, self.height - 6)
    if ant.y > (self.height - 28) then
        ant.targetY = clamp(ant.y - (10 + math.random(18)), self.farmTop + 4, self.height - 6)
    end
    local towardX, towardY = normalize(ant.targetX - ant.x, ant.targetY - ant.y)
    ant.dirX = towardX
    ant.dirY = towardY
end

function AntFarm:getNearestTunnelBelow(x, y)
    local bestSample = nil
    local bestDistanceSquared = math.huge
    for _, sample in ipairs(self.tunnelSamples) do
        if sample.y >= (y - 6) then
            local dx = sample.x - x
            local dy = sample.y - y
            local distanceSquared = (dx * dx) + (dy * dy)
            if distanceSquared < bestDistanceSquared then
                bestDistanceSquared = distanceSquared
                bestSample = sample
            end
        end
    end
    return bestSample, bestDistanceSquared
end

function AntFarm:updateHand()
    if self.preview then
        return
    end

    self.handX = clamp(self.handX + (self.inputX * HAND_SPEED), 12, self.width - 12)
    self.handY = clamp(self.handY + (self.inputY * HAND_SPEED), 8, self.farmTop - 6)
end

function AntFarm:updatePreviewAutoDrop()
    if not self.preview then
        return
    end
    self.autoDropTimer = self.autoDropTimer - 1
    if self.autoDropTimer <= 0 then
        self.autoDropTimer = AUTO_DROP_FRAMES + math.random(0, 35)
        self:dropAntAt(26 + math.random(self.width - 52), self.farmTop + 2)
    end
end

function AntFarm:updateAnt(ant)
    if ant.freshFrames ~= nil and ant.freshFrames > 0 then
        ant.freshFrames = ant.freshFrames - 1
    end

    if ant.state == "hold" then
        ant.holdTimer = ant.holdTimer - 1
        if ant.holdTimer <= 0 then
            ant.state = "dig"
            ant.tunnelCooldown = pickTunnelCooldown()
            self:pickDigDirection(ant, true)
        end
        return
    end

    local previousX = ant.x
    local previousY = ant.y

    if ant.tunnelCooldown > 0 then
        ant.tunnelCooldown = ant.tunnelCooldown - 1
    end

    ant.courseFrames = ant.courseFrames - 1
    if ant.state == "dig" and ant.courseFrames <= 0 then
        if ant.tunnelCooldown <= 0 and math.random() < 0.35 then
            self:startTunnelBurst(ant)
        else
            self:pickDigDirection(ant, true)
        end
    elseif ant.state == "dig" and ant.freshFrames ~= nil and ant.freshFrames > 0 and ant.tunnelCooldown <= 0 and math.random() < 0.18 then
        self:startTunnelBurst(ant)
    end

    local speedMultiplier = 1.0
    local wanderX
    local wanderY
    if ant.state == "tunnel" then
        ant.tunnelFrames = ant.tunnelFrames - 1
        local towardX, towardY = normalize(ant.targetX - ant.x, ant.targetY - ant.y)
        wanderX = lerp(ant.dirX, towardX, 0.72) + ((math.random() * 0.08) - 0.04)
        wanderY = lerp(ant.dirY, towardY, 0.72) + ((math.random() * 0.08) - 0.04)
        speedMultiplier = 1.28
        local distanceToGoal = length(ant.targetX - ant.x, ant.targetY - ant.y)
        if ant.tunnelFrames <= 0 or distanceToGoal <= 4 then
            ant.state = "dig"
            ant.tunnelFrames = 0
            self:pickDigDirection(ant, true)
        end
    else
        wanderX = ant.dirX + ((math.random() * 0.24) - 0.12)
        wanderY = ant.dirY + (0.08 + (math.random() * 0.08))
    end

    if ant.freshFrames ~= nil and ant.freshFrames > 0 then
        speedMultiplier = speedMultiplier + 0.35
    end

    local preferredX = wanderX
    local preferredY = wanderY
    local nearestTunnel, distanceSquared = self:getNearestTunnelBelow(ant.x, ant.y)
    if nearestTunnel ~= nil and distanceSquared <= (CONNECTION_ATTRACT_RADIUS * CONNECTION_ATTRACT_RADIUS) then
        local towardX, towardY = normalize(nearestTunnel.x - ant.x, nearestTunnel.y - ant.y)
        preferredX = lerp(wanderX, towardX, 0.32)
        preferredY = lerp(wanderY, towardY, 0.32)
        if distanceSquared <= (CONNECTION_RADIUS * CONNECTION_RADIUS) then
            ant.state = "hold"
            ant.holdTimer = CONNECTION_HOLD_MIN + math.random(CONNECTION_HOLD_MAX - CONNECTION_HOLD_MIN)
            ant.targetX = nearestTunnel.x
            ant.targetY = nearestTunnel.y
            ant.x = nearestTunnel.x
            ant.y = nearestTunnel.y
            self:recordTunnelSegment(previousX, previousY, ant.x, ant.y)
            return
        end
    end

    ant.dirX, ant.dirY = normalize(preferredX, preferredY)
    ant.x = clamp(ant.x + (ant.dirX * ant.speed * speedMultiplier), 6, self.width - 6)
    ant.y = clamp(ant.y + (ant.dirY * ant.speed * speedMultiplier), self.farmTop + 2, self.height - 6)

    if ant.y >= (self.height - 6) then
        ant.state = "dig"
        self:pickDigDirection(ant, false)
    elseif ant.x <= 6 or ant.x >= (self.width - 6) then
        ant.dirX = -ant.dirX
        ant.courseFrames = math.max(ant.courseFrames, 4)
    end

    self:recordTunnelSegment(previousX, previousY, ant.x, ant.y)
end

function AntFarm:update()
    self:updateHand()
    self:updatePreviewAutoDrop()
    for _, ant in ipairs(self.ants) do
        self:updateAnt(ant)
    end
end

function AntFarm:drawHand()
    if self.preview then
        return
    end

    local handX = math.floor(self.handX + 0.5)
    local handY = math.floor(self.handY + 0.5)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(handX - 6, handY - 4, 12, 8)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(handX - 6, handY - 4, 12, 8)
    gfx.drawLine(handX - 2, handY + 4, handX - 1, self.farmTop + 1)
    gfx.drawLine(handX + 2, handY + 4, handX + 1, self.farmTop + 1)
end

function AntFarm:drawAnts()
    for _, ant in ipairs(self.ants) do
        local antX = math.floor(ant.x + 0.5)
        local antY = math.floor(ant.y + 0.5)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(antX - 1, antY, 3, 1)
        gfx.fillRect(antX, antY - 1, 1, 3)
        if ant.freshFrames ~= nil and ant.freshFrames > 0 then
            gfx.fillRect(antX - 2, antY, 5, 1)
            gfx.fillRect(antX, antY - 2, 1, 5)
        end
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(antX, antY, 1, 1)
        if ant.state == "hold" then
            gfx.fillRect(antX - 1, antY - 1, 1, 1)
            gfx.fillRect(antX + 1, antY + 1, 1, 1)
        elseif ant.state == "tunnel" then
            gfx.fillRect(antX + 1, antY, 1, 1)
        end
    end
end

function AntFarm:draw()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(0, self.farmTop, self.width, self.farmTop)
    if self.soilPattern ~= nil then
        self.soilPattern:drawTiled(0, self.farmTop, self.width, self.height - self.farmTop)
    else
        gfx.setDitherPattern(0.75, gfx.image.kDitherTypeBayer8x8)
        gfx.fillRect(0, self.farmTop, self.width, self.height - self.farmTop)
        gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    end

    if self.tunnelImage ~= nil then
        self.tunnelImage:draw(0, 0)
    end

    self:drawAnts()
    self:drawHand()
end
