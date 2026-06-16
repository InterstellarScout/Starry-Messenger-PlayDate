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
end

function FractalTree:drawBranch(x1, y1, length, angle, depth, branchIndex)
    if depth <= 0 or length < MIN_LENGTH then
        return
    end

    local x2 = x1 + (math.cos(angle) * length)
    local y2 = y1 + (math.sin(angle) * length)
    local lineWidth = clamp(math.floor(depth * 0.42), 1, 4)
    gfx.setLineWidth(lineWidth)
    gfx.drawLine(math.floor(x1), math.floor(y1), math.floor(x2), math.floor(y2))

    local sway = math.sin(self.phase + branchIndex * 0.7) * 0.08
    local split = 0.42 + ((self.growth % 1) * 0.1)
    local sideLength = length * (0.64 + (math.sin(self.growth + depth) * 0.035))
    local centerLength = length * 0.58
    self:drawBranch(x2, y2, sideLength, angle - split + sway, depth - 1, branchIndex + 1)
    self:drawBranch(x2, y2, sideLength, angle + split + sway, depth - 1, branchIndex + 2)

    if depth > 3 and (depth + branchIndex) % 2 == 0 then
        self:drawBranch(x2, y2, centerLength, angle + (sway * 0.5), depth - 2, branchIndex + 3)
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

    local depth = clamp(math.floor(3 + self.growth), 3, MAX_DEPTH)
    local trunkLength = clamp(32 + (self.growth * 10), 36, 86)
    local rootX = self.width * 0.5
    local rootY = self.height - 6

    self:drawBranch(rootX, rootY, trunkLength, -math.pi * 0.5, depth, 1)
    self:drawCanopyHints(depth)
    gfx.setLineWidth(1)

    if not UIState or UIState.isShown() then
        gfx.drawText(string.format("Growth %.1f", self.growth), 8, 8)
    end
end
