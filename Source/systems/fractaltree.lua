--[[
Fractal tree crank toy.

Purpose:
- crank grows and retracts a recursive tree
- keeps recursion bounded while allowing the growth value to continue forever
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

FractalTree = {}
FractalTree.__index = FractalTree

local MAX_DEPTH <const> = 11
local MIN_LENGTH <const> = 3
local MAX_BRANCHES_PER_FRAME <const> = 1800
local PARTICLE_COUNT <const> = 72

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

function FractalTree.new(width, height, options)
    options = options or {}
    local self = setmetatable({}, FractalTree)
    self.width = width
    self.height = height
    self.preview = options.preview == true
    self.growth = 2.5
    self.phase = 0
    self.particles = {}
    for index = 1, PARTICLE_COUNT do
        self.particles[index] = {
            orbitX = math.random() * width,
            orbitY = math.random() * height,
            radiusX = 8 + math.random() * 58,
            radiusY = 5 + math.random() * 34,
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
    local delta = acceleratedChange or change or 0
    if math.abs(delta) <= 0.01 then
        return
    end
    self.growth = math.max(0.15, self.growth + (delta * 0.014))
end

function FractalTree:update()
    self.phase = (self.phase + 0.025) % (math.pi * 2)
    for _, particle in ipairs(self.particles) do
        particle.angle = (particle.angle + particle.speed) % (math.pi * 2)
    end
end

function FractalTree:drawBranch(x1, y1, length, angle, generation, branchIndex)
    if length < (self.minBranchLength or MIN_LENGTH) or self.branchBudget <= 0 then
        return
    end

    -- Each generation takes one growth step to extend from zero to twice its
    -- seed length.  Only then do its four evenly spaced offshoots begin at
    -- zero, eliminating the old abrupt full-size branch pop-in.
    local progress = clamp((self.growth or 0) - generation, 0, 1)
    if progress <= 0 then
        return
    end
    self.branchBudget = self.branchBudget - 1

    local visibleLength = length * 2 * progress
    local x2 = x1 + (math.cos(angle) * visibleLength)
    local y2 = y1 + (math.sin(angle) * visibleLength)
    local lineWidth = clamp(4 - math.floor(generation * 0.32), 1, 4)
    gfx.setLineWidth(lineWidth)
    gfx.drawLine(math.floor(x1), math.floor(y1), math.floor(x2), math.floor(y2))

    if progress >= 1 then
        local childLength = length * (self.branchLengthFactor or 0.5)
        for point = 1, 4 do
            local along = point / 5
            local childX = x1 + (math.cos(angle) * visibleLength * along)
            local childY = y1 + (math.sin(angle) * visibleLength * along)
            local sway = math.sin(self.phase + branchIndex + point) * 0.07
            local side = point % 2 == 0 and 1 or -1
            local split = 0.32 + (point * 0.08)
            self:drawBranch(childX, childY, childLength, angle + (side * split) + sway, generation + 1, (branchIndex * 4) + point)
        end
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

function FractalTree:drawCanopyHints(depth)
    local count = math.min(40, math.floor(depth * 3 + self.growth))
    for index = 1, count do
        local angle = (index * 2.399) + self.phase
        local radius = 28 + ((index * 13) % 72) + ((self.growth % 3) * 4)
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

    -- Growth depth is intentionally not capped. A draw budget keeps the
    -- Playdate safe while every new generation grows in smoothly.
    local depth = clamp(math.floor(self.growth) + 1, 1, MAX_DEPTH + 18)
    local excessDepth = math.max(0, depth - MAX_DEPTH)
    local treeScale = math.max(0.3, 1 - (excessDepth * 0.03))
    local trunkLength = 42 * treeScale
    local rootX = self.width * 0.5
    local rootY = self.height - 6

    self.branchBudget = MAX_BRANCHES_PER_FRAME
    self.minBranchLength = math.max(0.7, MIN_LENGTH - (excessDepth * 0.14))
    self.branchLengthFactor = math.max(0.34, 0.5 - (excessDepth * 0.006))
    self:drawParticles()
    self:drawBranch(rootX, rootY, trunkLength, -math.pi * 0.5, 0, 1)
    self:drawCanopyHints(depth)
    gfx.setLineWidth(1)

    if not UIState or UIState.isShown() then
        gfx.drawText(string.format("Growth %.1f", self.growth), 8, 8)
    end
end
