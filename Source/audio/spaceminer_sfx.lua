local pd <const> = playdate
local snd <const> = pd.sound

SpaceMinerSFX = {}
SpaceMinerSFX.__index = SpaceMinerSFX

local function safePlaySample(player)
    if player == nil or player.play == nil then
        return false
    end
    local ok = pcall(function()
        player:play()
    end)
    return ok
end

function SpaceMinerSFX.new(options)
    local self = setmetatable({}, SpaceMinerSFX)
    options = options or {}
    self.enabled = options.enabled ~= false
    self.sampleRoot = options.sampleRoot or "audio/spaceminer"
    self.samples = {}
    self.frame = 0
    self.thrusterTimer = 0
    self.ambientTimer = 0
    self:initializeSynths()
    self:initializeSamples()
    return self
end

function SpaceMinerSFX:initializeSynths()
    self.uiClickSynth = snd.synth.new(snd.kWaveTriangle)
    self.uiClickSynth:setADSR(0.0, 0.03, 0.0, 0.05)

    self.laserSynth = snd.synth.new(snd.kWaveTriangle)
    self.laserSynth:setADSR(0.0, 0.02, 0.0, 0.08)

    self.missileSynth = snd.synth.new(snd.kWaveTriangle)
    self.missileSynth:setADSR(0.0, 0.04, 0.0, 0.16)

    self.impactSynth = snd.synth.new(snd.kWaveNoise)
    self.impactSynth:setADSR(0.0, 0.02, 0.0, 0.08)

    self.ambientSynth = snd.synth.new(snd.kWaveTriangle)
    self.ambientSynth:setADSR(0.02, 0.18, 0.12, 0.4)

    self.thrusterSynth = snd.synth.new(snd.kWaveSine)
    self.thrusterSynth:setADSR(0.01, 0.08, 0.0, 0.1)

    self.asteroidSynth = snd.synth.new(snd.kWaveNoise)
    self.asteroidSynth:setADSR(0.0, 0.03, 0.0, 0.12)
end

function SpaceMinerSFX:initializeSamples()
    local samplePaths = {
        uiClick = self.sampleRoot .. "/ui-click.mp3",
        laser = self.sampleRoot .. "/laser.mp3",
        missile = self.sampleRoot .. "/missile.mp3",
        explosion = self.sampleRoot .. "/explosion.mp3",
        thruster = self.sampleRoot .. "/thruster.mp3",
        ambient = self.sampleRoot .. "/ambient.mp3",
        asteroid = self.sampleRoot .. "/asteroid-break.mp3",
        ship = self.sampleRoot .. "/ship-ambience.mp3"
    }

    for key, path in pairs(samplePaths) do
        local player = nil
        pcall(function()
            player = snd.sampleplayer.new(path)
        end)
        if player ~= nil then
            self.samples[key] = player
        end
    end
end

function SpaceMinerSFX:setEnabled(enabled)
    self.enabled = enabled == true
end

function SpaceMinerSFX:isEnabled()
    return self.enabled == true
end

function SpaceMinerSFX:playSampleOrSynth(sampleKey, synth, note, volume, length)
    if not self:isEnabled() then
        return
    end
    local sample = self.samples[sampleKey]
    if safePlaySample(sample) then
        return
    end
    if synth ~= nil and synth.playNote ~= nil then
        synth:playNote(note or 96, volume or 0.08, length or 0.1)
    end
end

function SpaceMinerSFX:playUiClick()
    self:playSampleOrSynth("uiClick", self.uiClickSynth, 290 + math.random(0, 80), 0.08, 0.06)
end

function SpaceMinerSFX:playMenuOpen()
    self:playUiClick()
end

function SpaceMinerSFX:playMenuBack()
    self:playSampleOrSynth("uiClick", self.uiClickSynth, 180 + math.random(0, 40), 0.06, 0.08)
end

function SpaceMinerSFX:playLaser()
    self:playSampleOrSynth("laser", self.laserSynth, 860 + math.random(0, 120), 0.06, 0.05)
end

function SpaceMinerSFX:playMissile()
    self:playSampleOrSynth("missile", self.missileSynth, 240 + math.random(0, 100), 0.12, 0.12)
end

function SpaceMinerSFX:playExplosion()
    self:playSampleOrSynth("explosion", self.impactSynth, 120 + math.random(0, 60), 0.15, 0.1)
end

function SpaceMinerSFX:playAsteroidBreak(stage)
    local stageIndex = math.max(0, math.floor(tonumber(stage) or 0))
    local notes = { 82, 112, 152, 205 }
    local note = notes[stageIndex + 1] or 205
    self:playSampleOrSynth("asteroid", self.asteroidSynth, note, 0.12, 0.09)
end

function SpaceMinerSFX:playShipAmbience()
    self:playSampleOrSynth("ship", self.ambientSynth, 72 + math.random(0, 20), 0.03, 0.25)
end

function SpaceMinerSFX:playThrusters(thrustAmount)
    if not self:isEnabled() then
        return
    end
    local sample = self.samples.thruster
    if sample ~= nil and sample.play ~= nil and thrustAmount ~= nil and thrustAmount > 0.15 then
        safePlaySample(sample)
        return
    end
    local note = 64 + math.floor((thrustAmount or 0.5) * 28)
    self.thrusterSynth:playNote(note, 0.04 + ((thrustAmount or 0.5) * 0.06), 0.08)
end

function SpaceMinerSFX:update(isThrusting)
    if not self:isEnabled() then
        return
    end
    self.frame = self.frame + 1
    if self.frame % 75 == 0 then
        self:playShipAmbience()
    end
    if isThrusting then
        self.thrusterTimer = self.thrusterTimer + 1
        if self.thrusterTimer >= 10 then
            self.thrusterTimer = 0
            self:playThrusters(0.65)
        end
    else
        self.thrusterTimer = 0
    end
    if self.ambientTimer > 0 then
        self.ambientTimer = self.ambientTimer - 1
    end
end
