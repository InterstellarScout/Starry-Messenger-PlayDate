--[[
Crank brick building game.

Purpose:
- crank raises and lowers a swinging block
- A or lowering into the target drops the block onto the tower
- poor alignment adds lean until the tower tips
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

BrickBuilder = {}
BrickBuilder.__index = BrickBuilder

local BLOCK_W <const> = 38
local BLOCK_H <const> = 13
local BASE_Y <const> = 222
local HOIST_TOP <const> = 24
local DROP_SPEED <const> = 12

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

function BrickBuilder.new(width, height, options)
    options = options or {}
    local self = setmetatable({}, BrickBuilder)
    self.width = width
    self.height = height
    self.preview = options.preview == true
    self.blocks = {
        { x = width * 0.5, y = BASE_Y, offset = 0 }
    }
    self.hoistY = 68
    self.swingPhase = 0
    self.currentX = width * 0.5
    self.dropY = self.hoistY
    self.dropX = self.currentX
    self.dropping = false
    self.lean = 0
    self.leanVelocity = 0
    self.tipped = false
    self.tipAngle = 0
    self.statusMessage = "Stack the bricks"
    self.statusFrames = 80
    return self
end

function BrickBuilder:setPreview(isPreview)
    self.preview = isPreview == true
end

function BrickBuilder:getStackTop()
    local top = BASE_Y - BLOCK_H
    for _, block in ipairs(self.blocks) do
        top = math.min(top, block.y - BLOCK_H)
    end
    return top
end

function BrickBuilder:prepareNextBrick()
    self.hoistY = clamp(self:getStackTop() - 92, HOIST_TOP, BASE_Y - 40)
    self.dropY = self.hoistY
    self.dropping = false
end

function BrickBuilder:dropCurrent()
    if self.dropping or self.tipped then
        return
    end
    self.dropping = true
    self.dropY = self.hoistY
    self.dropX = self.currentX
end

function BrickBuilder:handlePrimaryAction()
    if self.tipped then
        self.blocks = {
            { x = self.width * 0.5, y = BASE_Y, offset = 0 }
        }
        self.lean = 0
        self.leanVelocity = 0
        self.tipped = false
        self.tipAngle = 0
        self.statusMessage = "Reset"
        self.statusFrames = 45
        self:prepareNextBrick()
        return
    end
    self:dropCurrent()
end

function BrickBuilder:applyCrank(change)
    if self.tipped then
        return
    end
    if math.abs(change or 0) <= 0.01 then
        return
    end
    self.hoistY = clamp(self.hoistY + ((change or 0) * 0.32), HOIST_TOP, BASE_Y - 20)
    if not self.dropping then
        self.dropY = self.hoistY
    end
    if change > 0 and self.hoistY >= self:getStackTop() - (BLOCK_H * 1.6) then
        self:dropCurrent()
    end
end

function BrickBuilder:update()
    if self.statusFrames > 0 then
        self.statusFrames = self.statusFrames - 1
        if self.statusFrames <= 0 then
            self.statusMessage = nil
        end
    end

    if not self.dropping then
        self.swingPhase = self.swingPhase + 0.08 + math.min(0.08, #self.blocks * 0.004)
        local swingRadius = clamp(58 - (#self.blocks * 0.8), 24, 58)
        self.currentX = (self.width * 0.5) + math.sin(self.swingPhase) * swingRadius
        self.dropX = self.currentX
    end

    if self.tipped then
        self.tipAngle = clamp(self.tipAngle + 0.04, 0, 1.5)
        return
    end

    self.leanVelocity = self.leanVelocity + (self.lean * 0.0009)
    self.leanVelocity = self.leanVelocity * 0.985
    self.lean = self.lean + self.leanVelocity
    if math.abs(self.lean) > 1.15 then
        self.tipped = true
        self.statusMessage = "Tower tipped"
        self.statusFrames = 90
        return
    end

    if self.dropping then
        self.dropY = self.dropY + DROP_SPEED
        local targetY = self:getStackTop()
        if self.dropY >= targetY then
            local lastBlock = self.blocks[#self.blocks]
            local landingX = self.dropX or self.currentX
            local offset = landingX - lastBlock.x
            self.blocks[#self.blocks + 1] = {
                x = landingX,
                y = targetY,
                offset = offset
            }
            self.leanVelocity = self.leanVelocity + (offset * 0.0008)
            if math.abs(offset) > BLOCK_W * 0.58 then
                self.leanVelocity = self.leanVelocity + (offset * 0.0016)
                self.statusMessage = "Bad aim"
                self.statusFrames = 45
            else
                self.statusMessage = "Placed"
                self.statusFrames = 20
            end
            self:prepareNextBrick()
        end
    end
end

function BrickBuilder:drawBlock(cx, y, leanOffset, filled)
    local x = math.floor(cx - BLOCK_W * 0.5 + leanOffset)
    local top = math.floor(y - BLOCK_H)
    if filled then
        gfx.fillRect(x, top, BLOCK_W, BLOCK_H)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawLine(x + 5, top + 3, x + BLOCK_W - 5, top + 3)
        gfx.drawLine(x + 7, top + 9, x + BLOCK_W - 7, top + 9)
        gfx.setColor(gfx.kColorWhite)
    else
        gfx.drawRect(x, top, BLOCK_W, BLOCK_H)
    end
end

function BrickBuilder:draw()
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, self.width, self.height)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(0, BASE_Y + 1, self.width, BASE_Y + 1)
    gfx.fillRect(142, BASE_Y + 2, 116, 8)

    local towerLean = self.lean
    if self.tipped then
        towerLean = towerLean + (self.lean >= 0 and self.tipAngle or -self.tipAngle)
    end
    for index, block in ipairs(self.blocks) do
        local heightFactor = (#self.blocks - index) + 1
        self:drawBlock(block.x, block.y, towerLean * heightFactor * 6, true)
    end

    if not self.tipped then
        local activeX = self.dropping and (self.dropX or self.currentX) or self.currentX
        local hookX = math.floor(activeX)
        gfx.drawLine(hookX, 0, hookX, math.floor(self.hoistY - BLOCK_H))
        self:drawBlock(activeX, self.dropping and self.dropY or self.hoistY, 0, false)
    end

    if not UIState or UIState.isShown() then
        gfx.drawText(string.format("Blocks %d  Lean %.2f", math.max(0, #self.blocks - 1), self.lean), 8, 8)
        if self.statusMessage then
            gfx.drawTextAligned(self.statusMessage, self.width * 0.5, 24, kTextAlignment.center)
        end
    end
end
