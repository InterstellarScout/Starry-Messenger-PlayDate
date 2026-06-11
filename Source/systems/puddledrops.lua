--[[
Puddle drop toy.

Purpose:
- renders looping ripple-drop scenes as a dedicated gameplay view
- supports autonomous and player-triggered drops from one shared wave pool
- keeps a rolling cap on active drops so the scene stays lightweight
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

PuddleDrops = {}
PuddleDrops.__index = PuddleDrops

PuddleDrops.MODE_STANDARD = "standard"
PuddleDrops.MODE_INVERSE = "inverse"
PuddleDrops.MODE_AUTO = PuddleDrops.MODE_INVERSE

local DROP_LIMIT <const> = 9
local AUTO_DROP_LIMIT <const> = 8
local RANDOM_DROP_INTERVAL_MIN_FRAMES <const> = 15
local RANDOM_DROP_INTERVAL_MAX_FRAMES <const> = 150
local DEBRIS_LIMIT <const> = 3
local DEBRIS_INTERVAL_MIN_FRAMES <const> = 90
local DEBRIS_INTERVAL_MAX_FRAMES <const> = 300

local function roundToInt(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

function PuddleDrops.getModeLabel(modeId)
    if modeId == PuddleDrops.MODE_STANDARD then
        return "Drop Waves"
    end
    return "Inverse Drops"
end

function PuddleDrops.new(width, height, options)
    local self = setmetatable({}, PuddleDrops)
    options = options or {}
    self.width = width
    self.height = height
    self.modeId = options.modeId or PuddleDrops.MODE_AUTO
    self.preview = options.preview == true
    self.speed = self.preview and 0.8 or 0
    self.dropWaves = {}
    self.debris = {}
    self.pendingDebrisTimer = 0
    self.playerX = width * 0.5
    self.playerY = height * 0.5
    self.playerPulseCooldown = 0
    self.randomDropTimer = 0
    self.waveCapReached = false
    self:resetRandomDropTimer()
    self:resetDebrisTimer()
    return self
end

function PuddleDrops:setPreview(isPreview)
    self.preview = isPreview == true
end

function PuddleDrops:stepSpeed(direction)
    if direction == 0 then
        return
    end

    if self.speed > 1 then
        self.speed = self.speed + direction
    elseif self.speed < -1 then
        self.speed = self.speed + direction
    else
        local nextSpeed
        if self.speed >= 0 then
            nextSpeed = math.floor(((self.speed + (direction * 0.1)) * 10) + 0.5) / 10
        else
            nextSpeed = math.ceil(((self.speed + (direction * 0.1)) * 10) - 0.5) / 10
        end

        if nextSpeed > 1 then
            self.speed = 2
        elseif nextSpeed < -1 then
            self.speed = -2
        else
            self.speed = nextSpeed
        end
    end
end

function PuddleDrops:getTravelSpeed()
    local magnitude = math.abs(self.speed or 0)
    if magnitude <= 1 then
        return self.speed * 0.35
    end
    return ((self.speed >= 0) and 1 or -1) * (0.6 + (math.log(magnitude + 1) * 1.8))
end

function PuddleDrops:resetRandomDropTimer()
    self.randomDropTimer = math.random(RANDOM_DROP_INTERVAL_MIN_FRAMES, RANDOM_DROP_INTERVAL_MAX_FRAMES)
end

function PuddleDrops:resetDebrisTimer()
    self.pendingDebrisTimer = math.random(DEBRIS_INTERVAL_MIN_FRAMES, DEBRIS_INTERVAL_MAX_FRAMES)
end

function PuddleDrops:getAutoDropCount()
    local count = 0
    for _, wave in ipairs(self.dropWaves) do
        if not wave.fromPlayer then
            count = count + 1
        end
    end
    return count
end

function PuddleDrops:spawnDropWave(fromPlayer)
    if #self.dropWaves >= DROP_LIMIT then
        self.waveCapReached = true
        return false
    end
    if not fromPlayer and self:getAutoDropCount() >= AUTO_DROP_LIMIT then
        self.waveCapReached = true
        return false
    end

    local wave = {
        x = fromPlayer and self.playerX or (math.random() * self.width),
        y = fromPlayer and self.playerY or (math.random() * self.height),
        baseRadius = 0,
        speed = 0.8 + (math.random() * 1.4),
        thresholds = { 0, 4, 8, 14, 22 },
        fromPlayer = fromPlayer == true
    }

    self.dropWaves[#self.dropWaves + 1] = wave
    self.waveCapReached = #self.dropWaves >= DROP_LIMIT
    return true
end

function PuddleDrops:seedDropWaves()
    self.dropWaves = {}
    self.waveCapReached = false
    self:resetRandomDropTimer()
    self.debris = {}
    self:resetDebrisTimer()
end

function PuddleDrops:handlePrimaryAction()
    if self.preview then
        return
    end
    if self.playerPulseCooldown > 0 then
        return
    end
    self.playerPulseCooldown = 6
    self:spawnDropWave(true)
end

function PuddleDrops:handleDirectionalInput(leftHeld, rightHeld, upHeld, downHeld)
    if self.preview then
        return
    end

    local moveAmount = 3 + math.min(7, math.abs(self.speed or 0) * 0.1)
    if leftHeld then
        self.playerX = math.max(8, self.playerX - moveAmount)
    end
    if rightHeld then
        self.playerX = math.min(self.width - 8, self.playerX + moveAmount)
    end
    if upHeld then
        self.playerY = math.max(8, self.playerY - moveAmount)
    end
    if downHeld then
        self.playerY = math.min(self.height - 8, self.playerY + moveAmount)
    end
end

function PuddleDrops:updateDropWaves()
    local speedScale = 0.55 + math.min(4.5, math.abs(self:getTravelSpeed()) * 0.03)
    if self.playerPulseCooldown > 0 then
        self.playerPulseCooldown = self.playerPulseCooldown - 1
    end

    for index = #self.dropWaves, 1, -1 do
        local wave = self.dropWaves[index]
        wave.baseRadius = wave.baseRadius + (speedScale * wave.speed)

        local maxRadius = wave.baseRadius + wave.thresholds[#wave.thresholds]
        if maxRadius > (math.max(self.width, self.height) + 28) then
            table.remove(self.dropWaves, index)
        end
    end

    self.waveCapReached = #self.dropWaves >= DROP_LIMIT

    if #self.dropWaves < DROP_LIMIT then
        self.randomDropTimer = self.randomDropTimer - 1
        if self.randomDropTimer <= 0 then
            self:spawnDropWave(false)
            self:resetRandomDropTimer()
        end
    else
        self.randomDropTimer = 0
    end
end

function PuddleDrops:spawnDebris()
    if #self.debris >= DEBRIS_LIMIT then
        return
    end
    self.debris[#self.debris + 1] = {
        x = math.random() * self.width,
        y = math.random() * self.height,
        vx = (math.random() - 0.5) * 0.24,
        vy = (math.random() - 0.5) * 0.24,
        angle = math.random() * math.pi * 2,
        angularVelocity = (math.random() - 0.5) * 0.025,
        length = 10 + math.random() * 18,
        kind = math.random() < 0.5 and "line" or "stick",
        alpha = 0,
        phase = math.random() * math.pi * 2
    }
end

function PuddleDrops:updateDebris()
    if #self.debris < DEBRIS_LIMIT then
        self.pendingDebrisTimer = self.pendingDebrisTimer - 1
        if self.pendingDebrisTimer <= 0 then
            self:spawnDebris()
            self:resetDebrisTimer()
        end
    end

    for index = #self.debris, 1, -1 do
        local debris = self.debris[index]
        debris.alpha = math.min(1, (debris.alpha or 0) + 0.035)
        local pushX = 0
        local pushY = 0
        for _, wave in ipairs(self.dropWaves) do
            local radius = wave.baseRadius or 0
            local dx = debris.x - wave.x
            local dy = debris.y - wave.y
            local distance = math.sqrt((dx * dx) + (dy * dy))
            if distance > 0.001 and math.abs(distance - radius) < 18 then
                local force = (1 - (math.abs(distance - radius) / 18)) * 0.28
                pushX = pushX + (dx / distance) * force
                pushY = pushY + (dy / distance) * force
            end
        end
        debris.phase = debris.phase + 0.04
        debris.vx = (debris.vx + pushX + (math.sin(debris.phase) * 0.012)) * 0.985
        debris.vy = (debris.vy + pushY + (math.cos(debris.phase * 0.7) * 0.01)) * 0.985
        debris.x = debris.x + debris.vx
        debris.y = debris.y + debris.vy
        debris.angle = debris.angle + debris.angularVelocity + (pushX * 0.015)
        if debris.x < -30 or debris.x > self.width + 30 or debris.y < -30 or debris.y > self.height + 30 then
            table.remove(self.debris, index)
        end
    end
end

function PuddleDrops:update()
    self:updateDropWaves()
    self:updateDebris()
end

function PuddleDrops:drawHud()
    if self.preview or (UIState and not UIState.isShown()) then
        return
    end

    gfx.setColor(gfx.kColorWhite)
    gfx.setDitherPattern(0.15, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRoundRect(8, 8, 172, 34, 6)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText(PuddleDrops.getModeLabel(self.modeId), 14, 12)
    gfx.drawText(string.format("Speed %.1f", self.speed or 0), 14, 26)
    gfx.drawText(string.format("Waves %d/%d", #self.dropWaves, DROP_LIMIT), 98, 26)
end

function PuddleDrops:drawDropWaves()
    for _, wave in ipairs(self.dropWaves) do
        for _, threshold in ipairs(wave.thresholds) do
            local radius = wave.baseRadius - threshold
            if radius > 0 then
                gfx.drawCircleAtPoint(roundToInt(wave.x), roundToInt(wave.y), roundToInt(radius))
            end
        end
    end
end

function PuddleDrops:drawPlayerMarker()
    if #self.dropWaves >= DROP_LIMIT then
        return
    end

    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(roundToInt(self.playerX), roundToInt(self.playerY), 5)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawCircleAtPoint(roundToInt(self.playerX), roundToInt(self.playerY), 5)
end

function PuddleDrops:drawDebris()
    for _, debris in ipairs(self.debris) do
        if (debris.alpha or 0) >= 0.35 or math.floor((debris.alpha or 0) * 10) % 2 == 1 then
            local half = debris.length * 0.5
            local cosA = math.cos(debris.angle)
            local sinA = math.sin(debris.angle)
            local x1 = roundToInt(debris.x - (cosA * half))
            local y1 = roundToInt(debris.y - (sinA * half))
            local x2 = roundToInt(debris.x + (cosA * half))
            local y2 = roundToInt(debris.y + (sinA * half))
            gfx.drawLine(x1, y1, x2, y2)
            if debris.kind == "stick" and (debris.alpha or 0) > 0.7 then
                gfx.drawLine(x1 - roundToInt(sinA * 2), y1 + roundToInt(cosA * 2), x2 - roundToInt(sinA * 2), y2 + roundToInt(cosA * 2))
            end
        end
    end
end

function PuddleDrops:draw()
    local inverse = self.modeId ~= PuddleDrops.MODE_STANDARD
    gfx.setColor(inverse and gfx.kColorWhite or gfx.kColorBlack)
    gfx.fillRect(0, 0, self.width, self.height)
    gfx.setColor(inverse and gfx.kColorBlack or gfx.kColorWhite)
    self:drawDropWaves()
    self:drawDebris()
    self:drawPlayerMarker()
    if self.waveCapReached then
        gfx.drawRect(1, 1, self.width - 2, self.height - 2)
    end
    self:drawHud()
end
