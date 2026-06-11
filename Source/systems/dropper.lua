--[[
Dropper game view.

Purpose:
- turns the puddle ripple toy into a darker leak-plugging game loop
- spawns bubble leaks that burst into ripples unless the player flashes them first
- keeps a persistent cumulative "depth" total of plugged leaks across runs
]]
local pd <const> = playdate
local gfx <const> = pd.graphics
local snd <const> = pd.sound

Dropper = {}
Dropper.__index = Dropper

local RIPPLE_LIMIT <const> = 10
local BUBBLE_LIMIT <const> = 10
local FLASH_COOLDOWN_FRAMES <const> = 5
local BUBBLE_MIN_RADIUS <const> = 1
local BUBBLE_MAX_RADIUS <const> = 5
local FLASH_MIN_RADIUS <const> = 3
local FLASH_MAX_RADIUS <const> = 25
local LEAK_CLUSTER_RADIUS <const> = 10
local SAVE_KEY <const> = "dropper-progress"

local function roundToInt(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function distanceSquared(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return (dx * dx) + (dy * dy)
end

function Dropper.new(width, height, options)
    local self = setmetatable({}, Dropper)
    options = options or {}
    self.width = width
    self.height = height
    self.preview = options.preview == true
    self.speed = self.preview and 0.8 or 0
    self.rippleWaves = {}
    self.bubbles = {}
    self.playerX = width * 0.5
    self.playerY = height * 0.5
    self.flashCooldown = 0
    self.currentRunScore = 0
    self.bestRunScore = 0
    self.totalLeaksPlugged = 0
    self.progressDirty = false
    self.bubbleSpawnTimer = 0
    self.ambientTimer = 0
    self.surfaceTimer = 0
    self.audioInitialized = false
    self.ambientSynth = nil
    self.surfaceSynth = nil
    self.dripSynth = nil
    self.burstSynth = nil
    self:loadProgress()
    self:resetBubbleSpawnTimer()
    if self.preview then
        self:seedPreviewLeaks()
    end
    return self
end

function Dropper:stepSpeed(direction)
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

function Dropper:getTravelSpeed()
    local magnitude = math.abs(self.speed or 0)
    if magnitude <= 1 then
        return self.speed * 0.35
    end
    return ((self.speed >= 0) and 1 or -1) * (0.6 + (math.log(magnitude + 1) * 1.8))
end

function Dropper:isSoundEnabled()
    return not self.preview
        and ViewAudio ~= nil
        and ViewAudio.isEnabled ~= nil
        and ViewAudio.isEnabled()
end

function Dropper:initializeAudio()
    if self.audioInitialized then
        return
    end

    self.ambientSynth = snd.synth.new(snd.kWaveTriangle)
    self.ambientSynth:setADSR(0.01, 0.18, 0.12, 0.35)

    self.surfaceSynth = snd.synth.new(snd.kWaveSine)
    self.surfaceSynth:setADSR(0.0, 0.08, 0.0, 0.15)

    self.dripSynth = snd.synth.new(snd.kWaveSine)
    self.dripSynth:setADSR(0.0, 0.06, 0.0, 0.1)

    self.burstSynth = snd.synth.new(snd.kWaveNoise)
    self.burstSynth:setADSR(0.0, 0.03, 0.0, 0.08)

    self.audioInitialized = true
end

function Dropper:stopAudio()
    if self.ambientSynth then
        self.ambientSynth:stop()
    end
    if self.surfaceSynth then
        self.surfaceSynth:stop()
    end
    if self.dripSynth then
        self.dripSynth:stop()
    end
    if self.burstSynth then
        self.burstSynth:stop()
    end
end

function Dropper:playAmbientSound()
    if not self:isSoundEnabled() then
        self:stopAudio()
        return
    end

    self:initializeAudio()
    self.ambientTimer = self.ambientTimer - 1
    self.surfaceTimer = self.surfaceTimer - 1

    if self.ambientTimer <= 0 then
        self.ambientSynth:playNote(84 + (math.random() * 18), 0.07, 0.42)
        self.ambientTimer = math.random(16, 28)
    end

    if self.surfaceTimer <= 0 then
        self.surfaceSynth:playNote(240 + (math.random() * 80), 0.04, 0.18)
        self.surfaceTimer = math.random(22, 44)
    end
end

function Dropper:playDripSound()
    if not self:isSoundEnabled() then
        return
    end

    self:initializeAudio()
    self.dripSynth:playNote(180 + (math.random() * 40), 0.12, 0.12)
end

function Dropper:playPlugSound()
    if not self:isSoundEnabled() then
        return
    end

    self:initializeAudio()
    self.surfaceSynth:playNote(420 + (math.random() * 120), 0.16, 0.14)
end

function Dropper:playBurstSound()
    if not self:isSoundEnabled() then
        return
    end

    self:initializeAudio()
    self.burstSynth:playNote(110 + (math.random() * 60), 0.14, 0.09)
end

function Dropper:loadProgress()
    if pd.datastore == nil or pd.datastore.read == nil then
        return
    end

    local progress = pd.datastore.read(SAVE_KEY)
    if type(progress) ~= "table" then
        return
    end

    self.totalLeaksPlugged = tonumber(progress.totalLeaksPlugged) or 0
    self.bestRunScore = tonumber(progress.bestRunScore) or 0
end

function Dropper:saveProgress()
    if not self.progressDirty or pd.datastore == nil or pd.datastore.write == nil then
        return
    end

    pd.datastore.write({
        totalLeaksPlugged = self.totalLeaksPlugged,
        bestRunScore = self.bestRunScore
    }, SAVE_KEY)
    self.progressDirty = false
end

function Dropper:resetBubbleSpawnTimer()
    if self.preview then
        self.bubbleSpawnTimer = math.random(18, 32)
        return
    end
    self.bubbleSpawnTimer = math.random(24, 40)
end

function Dropper:getMoveAmount()
    return self.preview and 0 or 4
end

function Dropper:handleDirectionalInput(leftHeld, rightHeld, upHeld, downHeld)
    if self.preview then
        return
    end

    local moveAmount = self:getMoveAmount()
    if leftHeld then
        self.playerX = clamp(self.playerX - moveAmount, 8, self.width - 8)
    end
    if rightHeld then
        self.playerX = clamp(self.playerX + moveAmount, 8, self.width - 8)
    end
    if upHeld then
        self.playerY = clamp(self.playerY - moveAmount, 52, self.height - 8)
    end
    if downHeld then
        self.playerY = clamp(self.playerY + moveAmount, 52, self.height - 8)
    end
end

function Dropper:randomFlashRadius()
    return math.random(FLASH_MIN_RADIUS, FLASH_MAX_RADIUS)
end

function Dropper:addRippleWave(x, y, options)
    options = options or {}
    if #self.rippleWaves >= RIPPLE_LIMIT then
        return false
    end

    self.rippleWaves[#self.rippleWaves + 1] = {
        x = x,
        y = y,
        baseRadius = 0,
        speed = options.speed or (0.9 + (math.random() * 1.2)),
        thresholds = options.thresholds or { 0, 4, 9, 15, 22 },
        prePulseRadius = options.prePulseRadius,
        prePulseMax = options.prePulseMax,
        flashWave = options.flashWave == true
    }
    return true
end

function Dropper:spawnFlashWave()
    self:addRippleWave(self.playerX, self.playerY, {
        prePulseRadius = 1,
        prePulseMax = self:randomFlashRadius(),
        flashWave = true,
        speed = 1.4 + (math.random() * 0.9),
        thresholds = { 0, 5, 10, 16, 24 }
    })
end

function Dropper:handlePrimaryAction()
    if self.preview or self.flashCooldown > 0 then
        return
    end

    self.flashCooldown = FLASH_COOLDOWN_FRAMES
    self:spawnFlashWave()
    self:playPlugSound()
end

function Dropper:createLeakBubble(x, y)
    self.bubbles[#self.bubbles + 1] = {
        x = x,
        y = y,
        radius = BUBBLE_MIN_RADIUS,
        growth = 0.17 + (math.random() * 0.14),
        maxRadius = BUBBLE_MAX_RADIUS,
        life = math.random(20, 38)
    }

    while #self.bubbles > BUBBLE_LIMIT do
        table.remove(self.bubbles, 1)
    end
end

function Dropper:spawnLeakCluster()
    local centerX = math.random(24, self.width - 24)
    local centerY = math.random(56, self.height - 20)
    local leakCount = self.preview and math.random(1, 2) or math.random(2, 4)

    for _ = 1, leakCount do
        local angle = math.random() * (math.pi * 2)
        local distance = math.random() * LEAK_CLUSTER_RADIUS
        self:createLeakBubble(
            centerX + (math.cos(angle) * distance),
            centerY + (math.sin(angle) * distance)
        )
    end

    self:playDripSound()
end

function Dropper:seedPreviewLeaks()
    for _ = 1, 4 do
        self:spawnLeakCluster()
    end
end

function Dropper:updateRippleWaves()
    local rippleSpeedScale = 0.6 + math.min(4.6, math.abs(self:getTravelSpeed()) * 0.03)
    local rippleDirection = (self.speed or 0) < 0 and -1 or 1
    if self.flashCooldown > 0 then
        self.flashCooldown = self.flashCooldown - 1
    end

    for index = #self.rippleWaves, 1, -1 do
        local wave = self.rippleWaves[index]
        if wave.prePulseRadius ~= nil then
            wave.prePulseRadius = wave.prePulseRadius + (rippleSpeedScale * 2.1)
            if wave.prePulseRadius >= wave.prePulseMax then
                wave.prePulseRadius = nil
                wave.baseRadius = 0
            end
        else
            wave.baseRadius = wave.baseRadius + (wave.speed * rippleSpeedScale * rippleDirection)
        end

        local maxRadius = wave.baseRadius + wave.thresholds[#wave.thresholds]
        if maxRadius > (math.max(self.width, self.height) + 28) or maxRadius < -28 then
            table.remove(self.rippleWaves, index)
        end
    end
end

function Dropper:getWaveHitRadius(wave)
    if wave.prePulseRadius ~= nil then
        return wave.prePulseRadius
    end

    return wave.baseRadius + 4
end

function Dropper:isBubblePlugged(bubble)
    for _, wave in ipairs(self.rippleWaves) do
        if wave.flashWave then
            local hitRadius = self:getWaveHitRadius(wave) + bubble.radius
            if distanceSquared(wave.x, wave.y, bubble.x, bubble.y) <= (hitRadius * hitRadius) then
                return true
            end
        end
    end

    return false
end

function Dropper:addBurstRipples(x, y)
    local burstCount = math.random(3, 6)
    for index = 1, burstCount do
        local angle = ((index - 1) / burstCount) * (math.pi * 2)
        local distance = math.random(2, 10)
        self:addRippleWave(
            x + (math.cos(angle) * distance),
            y + (math.sin(angle) * distance),
            {
                speed = 1.1 + (math.random() * 0.7),
                thresholds = { 0, 3, 7, 12, 18 }
            }
        )
    end
end

function Dropper:registerPlug()
    self.currentRunScore = self.currentRunScore + 1
    self.totalLeaksPlugged = self.totalLeaksPlugged + 1
    if self.currentRunScore > self.bestRunScore then
        self.bestRunScore = self.currentRunScore
    end
    self.progressDirty = true
    self:saveProgress()
end

function Dropper:updateBubbles()
    local flowScale = 0.45 + math.min(2.8, math.abs(self:getTravelSpeed()) * 0.02)
    self.bubbleSpawnTimer = self.bubbleSpawnTimer - 1
    if self.bubbleSpawnTimer <= 0 then
        self:spawnLeakCluster()
        self:resetBubbleSpawnTimer()
    end

    for index = #self.bubbles, 1, -1 do
        local bubble = self.bubbles[index]
        bubble.life = bubble.life - 1
        bubble.radius = math.min(bubble.maxRadius, bubble.radius + (bubble.growth * flowScale))

        if self:isBubblePlugged(bubble) then
            self:addRippleWave(bubble.x, bubble.y, {
                speed = 1.3 + (math.random() * 0.5),
                thresholds = { 0, 3, 6, 10 }
            })
            table.remove(self.bubbles, index)
            self:registerPlug()
            self:playPlugSound()
        elseif bubble.radius >= bubble.maxRadius or bubble.life <= 0 then
            self:addBurstRipples(bubble.x, bubble.y)
            table.remove(self.bubbles, index)
            self:playBurstSound()
        end
    end
end

function Dropper:update()
    self:updateRippleWaves()
    self:updateBubbles()
    self:playAmbientSound()
end

function Dropper:drawRippleWaves()
    for _, wave in ipairs(self.rippleWaves) do
        if wave.prePulseRadius ~= nil then
            gfx.fillCircleAtPoint(roundToInt(wave.x), roundToInt(wave.y), roundToInt(wave.prePulseRadius))
        else
            for _, threshold in ipairs(wave.thresholds) do
                local radius = wave.baseRadius - threshold
                if radius > 0 then
                    gfx.drawCircleAtPoint(roundToInt(wave.x), roundToInt(wave.y), roundToInt(radius))
                end
            end
        end
    end
end

function Dropper:drawBubbles()
    for _, bubble in ipairs(self.bubbles) do
        gfx.fillCircleAtPoint(roundToInt(bubble.x), roundToInt(bubble.y), roundToInt(bubble.radius))
        if bubble.radius >= 2 then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillCircleAtPoint(roundToInt(bubble.x - 1), roundToInt(bubble.y - 1), 1)
            gfx.setColor(gfx.kColorWhite)
        end
    end
end

function Dropper:drawPlayerMarker()
    if self.preview then
        return
    end

    gfx.fillCircleAtPoint(roundToInt(self.playerX), roundToInt(self.playerY), 5)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillCircleAtPoint(roundToInt(self.playerX), roundToInt(self.playerY), 2)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawCircleAtPoint(roundToInt(self.playerX), roundToInt(self.playerY), 7)
end

function Dropper:drawHud()
    if self.preview or (UIState and not UIState.isShown()) then
        return
    end

    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(8, 8, 176, 38, 6)
    gfx.drawText(string.format("Run %d", self.currentRunScore), 14, 12)
    gfx.drawText(string.format("Depth %d", self.totalLeaksPlugged), 84, 12)
    gfx.drawText(string.format("Best %d", self.bestRunScore), 14, 27)
    gfx.drawText(string.format("Leaks %d", #self.bubbles), 84, 27)
    gfx.drawText(string.format("Speed %.1f", self.speed), 278, 12)
    if #self.rippleWaves >= RIPPLE_LIMIT then
        gfx.drawRect(1, 1, self.width - 2, self.height - 2)
    end
end

function Dropper:draw()
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, self.width, self.height)
    gfx.setColor(gfx.kColorWhite)
    self:drawRippleWaves()
    self:drawBubbles()
    self:drawPlayerMarker()
    self:drawHud()
end

function Dropper:shutdown()
    self:saveProgress()
    self:stopAudio()
end
