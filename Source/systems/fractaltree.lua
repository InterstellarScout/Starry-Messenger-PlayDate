--[[
Fractal tree crank toy.

The tree deliberately grows in clear, sparse generations: a 20-pixel trunk,
then three half-length branches at 2/4, 3/4 and 4/4 of every completed line.
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

FractalTree = {}
FractalTree.__index = FractalTree

local ROOT_LENGTH <const> = 120
local MIN_CHILD_LENGTH <const> = 4
local MAX_GENERATION <const> = 6
local PARTICLE_COUNT <const> = 144
local MAX_BRANCHES_PER_FRAME <const> = 300

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function generationStart(generation)
    -- The next generation begins only after its parent has reached full size:
    -- 0, 20, 30, 35, ... pixels of accumulated crank growth.
    if generation <= 0 then
        return 0
    end
    return ROOT_LENGTH * (2 - (0.5 ^ (generation - 1)))
end

function FractalTree.new(width, height, options)
    options = options or {}
    local self = setmetatable({}, FractalTree)
    self.width = width
    self.height = height
    self.preview = options.preview == true
    self.growth = 0
    self.phase = 0
    self.particles = {}
    for index = 1, PARTICLE_COUNT do
        self.particles[index] = {
            orbitX = math.random() * width,
            orbitY = math.random() * height,
            radiusX = 8 + math.random() * 82,
            radiusY = 5 + math.random() * 52,
            angle = math.random() * math.pi * 2,
            speed = (0.006 + math.random() * 0.021) * (math.random() < 0.5 and -1 or 1),
            phase = math.random() * math.pi * 2
        }
    end
    return self
end

function FractalTree:setPreview(isPreview)
    self.preview = isPreview == true
end

function FractalTree:applyCrank(change, acceleratedChange)
    -- Use the physical crank delta so every new line grows at a predictable
    -- rate instead of inheriting the old accelerated recursive fan behavior.
    local delta = change or acceleratedChange or 0
    if math.abs(delta) <= 0.01 then
        return
    end
    self.growth = math.max(0, self.growth + (delta * 0.25))
end

function FractalTree:update()
    self.phase = (self.phase + 0.025) % (math.pi * 2)
    for _, particle in ipairs(self.particles) do
        particle.angle = (particle.angle + particle.speed) % (math.pi * 2)
    end
end

function FractalTree:drawBranch(x1, y1, length, angle, generation, branchIndex)
    if self.branchBudget <= 0 then
        return
    end

    local progress = clamp(((self.growth or 0) - generationStart(generation)) / length, 0, 1)
    if progress <= 0 and generation ~= 0 and (self.growth or 0) < generationStart(generation) then
        return
    end

    self.branchBudget = self.branchBudget - 1
    local visibleLength = length * progress
    -- A new branch starts as the requested 0x1 line, then extends smoothly.
    if visibleLength < 1 then
        visibleLength = 1
    end
    local x2 = x1 + (math.cos(angle) * visibleLength)
    local y2 = y1 + (math.sin(angle) * visibleLength)
    gfx.drawLine(math.floor(x1), math.floor(y1), math.floor(x2), math.floor(y2))

    if progress < 1 then
        return
    end

    if generation >= MAX_GENERATION then return end
    local childLength = math.max(MIN_CHILD_LENGTH, length * 0.5)

    local positions = { 0.5, 0.75, 1.0 }
    local offsets = { -0.62, 0.48, -0.30 }
    for index, along in ipairs(positions) do
        local childX = x1 + (math.cos(angle) * length * along)
        local childY = y1 + (math.sin(angle) * length * along)
        local sway = math.sin(self.phase + branchIndex + index) * 0.045
        self:drawBranch(
            childX,
            childY,
            childLength,
            angle + offsets[index] + sway,
            generation + 1,
            (branchIndex * 3) + index
        )
    end
end

function FractalTree:drawParticles()
    for _, particle in ipairs(self.particles) do
        local wobble = math.sin(self.phase + particle.phase)
        local x = particle.orbitX + math.cos(particle.angle) * (particle.radiusX + wobble * 4)
        local y = particle.orbitY + math.sin(particle.angle) * (particle.radiusY + wobble * 3)
        local size = math.sin((self.phase * 2) + particle.phase) > 0.72 and 2 or 1
        gfx.fillRect(math.floor(x), math.floor(y), size, size)
    end
end

function FractalTree:drawCanopyHints()
    -- Keep the former glowing canopy effect, but make it intentionally light
    -- so the newly legible branch structure remains the focus.
    local count = math.min(20, math.max(3, math.floor(self.growth * 0.45)))
    for index = 1, count do
        local angle = (index * 2.399) + self.phase
        local radius = 24 + ((index * 13) % 58)
        local x = self.width * 0.5 + math.cos(angle) * radius
        local y = self.height * 0.34 + math.sin(angle * 0.82) * (radius * 0.42)
        if index % 3 == 0 then
            gfx.drawCircleAtPoint(math.floor(x), math.floor(y), 2)
        else
            gfx.fillCircleAtPoint(math.floor(x), math.floor(y), 1)
        end
    end
end

function FractalTree:draw()
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, self.width, self.height)
    gfx.setColor(gfx.kColorWhite)

    self.branchBudget = MAX_BRANCHES_PER_FRAME
    self:drawParticles()
    self:drawBranch(self.width * 0.5, self.height - 6, ROOT_LENGTH, -math.pi * 0.5, 0, 1)
    self:drawCanopyHints()
    gfx.setLineWidth(1)

    if not UIState or UIState.isShown() then
        gfx.drawText(string.format("Growth %d px", math.floor(self.growth)), 8, 8)
    end
end
