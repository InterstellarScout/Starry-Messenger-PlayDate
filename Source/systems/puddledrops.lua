--[[
Puddle drop toy.

Purpose:
- renders looping ripple-drop scenes as a dedicated gameplay view
- supports both autonomous drop generation and a player-triggered pulse mode
- keeps a rolling cap on active drops so the scene stays lightweight
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

PuddleDrops = {}
PuddleDrops.__index = PuddleDrops

PuddleDrops.MODE_AUTO = "auto"
PuddleDrops.MODE_PLAYER = "player"

local DROP_LIMIT <const> = 10
local PLAYER_DROP_MIN_RADIUS <const> = 3
local PLAYER_DROP_MAX_RADIUS <const> = 25

local function roundToInt(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

function PuddleDrops.getModeLabel(modeId)
    if modeId == PuddleDrops.MODE_PLAYER then
        return "Player Pulse"
    end
    return "Drop Waves"
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
    self.playerX = width * 0.5
    self.playerY = height * 0.5
    self.playerPulseCooldown = 0
    self.waveCapReached = false
    self:seedDropWaves()
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

function PuddleDrops:spawnDropWave(fromPlayer)
    if #self.dropWaves >= DROP_LIMIT then
        self.waveCapReached = true
        return false
    end

    local wave = {
        x = fromPlayer and self.playerX or (math.random() * self.width),
        y = fromPlayer and self.playerY or (math.random() * self.height),
        baseRadius = 0,
        speed = 0.8 + (math.random() * 1.4),
        thresholds = { 0, 4, 8, 14, 22 },
        prePulseRadius = fromPlayer and 0 or nil,
        prePulseMax = fromPlayer and math.random(PLAYER_DROP_MIN_RADIUS, PLAYER_DROP_MAX_RADIUS) or nil
    }

    self.dropWaves[#self.dropWaves + 1] = wave
    self.waveCapReached = #self.dropWaves >= DROP_LIMIT
    return true
end

function PuddleDrops:seedDropWaves()
    self.dropWaves = {}
    self.waveCapReached = false
    if self.modeId == PuddleDrops.MODE_PLAYER then
        return
    end
    for _ = 1, DROP_LIMIT do
        self:spawnDropWave(false)
    end
end

function PuddleDrops:handlePrimaryAction()
    if self.modeId ~= PuddleDrops.MODE_PLAYER or self.preview then
        return
    end
    if self.playerPulseCooldown > 0 then
        return
    end
    self.playerPulseCooldown = 6
    self:spawnDropWave(true)
end

function PuddleDrops:handleDirectionalInput(leftHeld, rightHeld, upHeld, downHeld)
    if self.modeId ~= PuddleDrops.MODE_PLAYER or self.preview then
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
        if wave.prePulseRadius ~= nil then
            wave.prePulseRadius = wave.prePulseRadius + (speedScale * 2.4)
            if wave.prePulseRadius >= wave.prePulseMax then
                wave.prePulseRadius = nil
                wave.baseRadius = 0
            end
        else
            wave.baseRadius = wave.baseRadius + (speedScale * wave.speed)
        end

        local maxRadius = wave.baseRadius + wave.thresholds[#wave.thresholds]
        if maxRadius > (math.max(self.width, self.height) + 28) then
            table.remove(self.dropWaves, index)
            if self.modeId == PuddleDrops.MODE_AUTO then
                self:spawnDropWave(false)
            end
        end
    end

    self.waveCapReached = #self.dropWaves >= DROP_LIMIT

    if self.modeId == PuddleDrops.MODE_AUTO then
        while #self.dropWaves < DROP_LIMIT do
            self:spawnDropWave(false)
        end
    end
end

function PuddleDrops:update()
    self:updateDropWaves()
end

function PuddleDrops:drawHud()
    if self.preview then
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
        if wave.prePulseRadius ~= nil then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillCircleAtPoint(roundToInt(wave.x), roundToInt(wave.y), roundToInt(wave.prePulseRadius))
            gfx.setColor(gfx.kColorWhite)
            gfx.drawCircleAtPoint(roundToInt(wave.x), roundToInt(wave.y), roundToInt(wave.prePulseRadius))
            gfx.setColor(gfx.kColorBlack)
        end

        if wave.prePulseRadius == nil then
            for _, threshold in ipairs(wave.thresholds) do
                local radius = wave.baseRadius - threshold
                if radius > 0 then
                    gfx.drawCircleAtPoint(roundToInt(wave.x), roundToInt(wave.y), roundToInt(radius))
                end
            end
        end
    end
end

function PuddleDrops:drawPlayerMarker()
    if self.modeId ~= PuddleDrops.MODE_PLAYER then
        return
    end

    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(roundToInt(self.playerX), roundToInt(self.playerY), 5)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawCircleAtPoint(roundToInt(self.playerX), roundToInt(self.playerY), 5)
end

function PuddleDrops:draw()
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, self.width, self.height)
    gfx.setColor(gfx.kColorBlack)
    self:drawDropWaves()
    self:drawPlayerMarker()
    if self.waveCapReached then
        gfx.drawRect(1, 1, self.width - 2, self.height - 2)
    end
    self:drawHud()
end
