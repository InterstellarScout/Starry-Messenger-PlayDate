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

function FractalTree:drawBranch(x1, y1, length, angle, depth, branchIndex)
    if depth <= 0 or length < (self.minBranchLength or MIN_LENGTH) or self.branchBudget <= 0 then
        return
    end
    self.branchBudget = self.branchBudget - 1

    local x2 = x1 + (math.cos(angle) * length)
    local y2 = y1 + (math.sin(angle) * length)
    local lineWidth = clamp(math.floor(depth * 0.42), 1, 4)
    gfx.setLineWidth(lineWidth)
    gfx.drawLine(math.floor(x1), math.floor(y1), math.floor(x2), math.floor(y2))

    local sway = math.sin(self.phase + branchIndex * 0.7) * 0.08
    local split = 0.42 + ((self.growth % 1) * 0.1)
    local sideLength = length * ((self.branchLengthFactor or 0.64) + (math.sin(self.growth + depth) * 0.02))
    local centerLength = length * ((self.branchLengthFactor or 0.64) - 0.06)
    self:drawBranch(x2, y2, sideLength, angle - split + sway, depth - 1, branchIndex + 1)
    self:drawBranch(x2, y2, sideLength, angle + split + sway, depth - 1, branchIndex + 2)

    if depth > 3 and (depth + branchIndex) % 2 == 0 then
        self:drawBranch(x2, y2, centerLength, angle + (sway * 0.5), depth - 2, branchIndex + 3)
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

    -- Growth depth is intentionally not capped.  A draw budget keeps the
    -- Playdate safe while the tree's finer upper branches keep extending.
    local depth = clamp(math.floor(3 + self.growth), 3, MAX_DEPTH + 18)
    local excessDepth = math.max(0, depth - MAX_DEPTH)
    local treeScale = math.max(0.38, 1 - (excessDepth * 0.035))
    local trunkLength = (36 + math.min(self.growth, 8) * 6) * treeScale
    local rootX = self.width * 0.5
    local rootY = self.height - 6

    self.branchBudget = MAX_BRANCHES_PER_FRAME
    self.minBranchLength = math.max(0.7, MIN_LENGTH - (excessDepth * 0.14))
    self.branchLengthFactor = math.min(0.82, 0.64 + (excessDepth * 0.014))
    self:drawParticles()
    self:drawBranch(rootX, rootY, trunkLength, -math.pi * 0.5, depth, 1)
    self:drawCanopyHints(depth)
    gfx.setLineWidth(1)

    if not UIState or UIState.isShown() then
        gfx.drawText(string.format("Growth %.1f", self.growth), 8, 8)
    end
end
