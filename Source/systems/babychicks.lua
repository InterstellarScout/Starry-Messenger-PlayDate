--[[
Baby Chicks mini-game.

Purpose:
- hatch mystery eggs through small, deliberate interactions
- let the player care for chicks with a freely moved hand
- grow a persistent garden of chicks, one hatch at a time
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

BabyChicks = {}
BabyChicks.__index = BabyChicks

local SAVE_KEY <const> = "baby-chicks-garden"
local SCREEN_WIDTH <const> = 400
local SCREEN_HEIGHT <const> = 240
local EGG_X <const> = 200
local EGG_Y <const> = 126
local HATCH_INTERACTIONS <const> = 4
local CARE_FOR_NEXT_EGG <const> = 8
local HAND_SPEED <const> = 3

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function BabyChicks.new(width, height, options)
    options = options or {}
    local self = setmetatable({}, BabyChicks)
    self.width = width or SCREEN_WIDTH
    self.height = height or SCREEN_HEIGHT
    self.preview = options.preview == true
    self.handX = EGG_X
    self.handY = 184
    self.eggProgress = 0
    self.careProgress = 0
    self.petCooldown = 0
    self.frame = 0
    self.chicks = {}
    self.state = "egg"
    self.status = "I wonder what's inside?"

    if self.preview then
        self:addChick(132, 144)
        self:addChick(200, 118)
        self:addChick(268, 150)
        self.state = "garden"
        self.status = "Garden of Chicks"
    else
        self:loadGarden()
    end
    return self
end

function BabyChicks:setPreview(enabled)
    self.preview = enabled == true
end

function BabyChicks:addChick(x, y)
    local index = #self.chicks + 1
    self.chicks[index] = {
        x = x or (65 + math.random() * 270),
        y = y or (85 + math.random() * 105),
        homeX = x or 200,
        homeY = y or 140,
        seed = math.random() * math.pi * 2,
        affection = 0,
        hop = math.random() * math.pi * 2
    }
end

function BabyChicks:loadGarden()
    local saved = pd.datastore and pd.datastore.read and pd.datastore.read(SAVE_KEY) or nil
    if type(saved) == "table" and type(saved.chicks) == "table" then
        for _, chick in ipairs(saved.chicks) do
            if type(chick) == "table" then
                self:addChick(clamp(tonumber(chick.x) or EGG_X, 20, 380), clamp(tonumber(chick.y) or EGG_Y, 54, 215))
            end
        end
    end

    if #self.chicks > 0 then
        self.state = "garden"
        self.status = "Pet your chicks to find another egg."
    end
end

function BabyChicks:saveGarden()
    if self.preview or not pd.datastore or not pd.datastore.write then
        return
    end
    local chicks = {}
    for index, chick in ipairs(self.chicks) do
        chicks[index] = { x = chick.x, y = chick.y }
    end
    pd.datastore.write({ chicks = chicks }, SAVE_KEY)
end

function BabyChicks:shutdown()
    self:saveGarden()
end

function BabyChicks:beginEgg()
    self.state = "egg"
    self.eggProgress = 0
    self.status = "I wonder what's inside?"
end

function BabyChicks:hatchEgg()
    self:addChick(EGG_X, EGG_Y + 4)
    self.state = "garden"
    self.careProgress = 0
    self.status = "A baby chick! Give it a pet."
    self:saveGarden()
end

function BabyChicks:interactWithEgg()
    if self.state ~= "egg" then
        return
    end
    self.eggProgress = self.eggProgress + 1
    if self.eggProgress >= HATCH_INTERACTIONS then
        self:hatchEgg()
    else
        self.status = "The egg is wiggling..."
    end
end

function BabyChicks:handlePrimaryAction()
    if self.state == "egg" then
        self:interactWithEgg()
    elseif self.careProgress >= CARE_FOR_NEXT_EGG then
        self:beginEgg()
    end
end

function BabyChicks:handleDirectionalInput(leftHeld, rightHeld, upHeld, downHeld)
    local dx = (rightHeld and 1 or 0) - (leftHeld and 1 or 0)
    local dy = (downHeld and 1 or 0) - (upHeld and 1 or 0)
    self.handX = clamp(self.handX + (dx * HAND_SPEED), 10, self.width - 10)
    self.handY = clamp(self.handY + (dy * HAND_SPEED), 42, self.height - 10)
end

function BabyChicks:applyCrank(change)
    if math.abs(change or 0) > 0.01 then
        self.handX = clamp(self.handX + change, 10, self.width - 10)
    end
end

function BabyChicks:isHandTouching(x, y, radius)
    local dx = self.handX - x
    local dy = self.handY - y
    return (dx * dx) + (dy * dy) <= (radius * radius)
end

function BabyChicks:update()
    self.frame = self.frame + 1
    if self.petCooldown > 0 then
        self.petCooldown = self.petCooldown - 1
    end

    if self.state == "egg" and self:isHandTouching(EGG_X, EGG_Y, 22) and self.petCooldown <= 0 then
        self:interactWithEgg()
        self.petCooldown = 18
    end

    for _, chick in ipairs(self.chicks) do
        chick.hop = chick.hop + 0.10
        chick.x = clamp(chick.x + math.cos((self.frame * 0.025) + chick.seed) * 0.35, 18, self.width - 18)
        chick.y = clamp(chick.y + math.sin((self.frame * 0.022) + chick.seed) * 0.25, 55, self.height - 16)
        if self.state == "garden" and self.petCooldown <= 0 and self:isHandTouching(chick.x, chick.y, 20) then
            chick.affection = chick.affection + 1
            self.careProgress = self.careProgress + 1
            self.petCooldown = 16
            if self.careProgress >= CARE_FOR_NEXT_EGG then
                self.status = "A new mystery egg is ready! Press A."
            else
                self.status = "Peep! Your chick feels loved."
            end
        end
    end
end

function BabyChicks:drawNest()
    gfx.setColor(gfx.kColorBlack)
    for index = 0, 6 do
        local y = EGG_Y + 15 + (index * 2)
        gfx.drawLine(EGG_X - 24 + (index % 2), y, EGG_X + 24 - (index % 2), y + 3)
    end
end

function BabyChicks:drawEgg()
    self:drawNest()
    local wobble = math.sin(self.frame * 0.18) * (self.eggProgress * 0.45)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillEllipseInRect(EGG_X - 13 + wobble, EGG_Y - 18, 26, 35)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawEllipseInRect(EGG_X - 13 + wobble, EGG_Y - 18, 26, 35)
    for crack = 1, self.eggProgress - 1 do
        gfx.drawLine(EGG_X - 5 + (crack * 3) + wobble, EGG_Y - 6 + (crack * 3), EGG_X + 2 + (crack * 2) + wobble, EGG_Y - 2 + (crack * 3))
    end
end

function BabyChicks:drawChick(chick)
    local bob = math.sin(chick.hop) * 2
    local x = math.floor(chick.x + 0.5)
    local y = math.floor(chick.y + bob + 0.5)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(x, y + 3, 9)
    gfx.fillCircleAtPoint(x + 4, y - 5, 6)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawCircleAtPoint(x, y + 3, 9)
    gfx.drawCircleAtPoint(x + 4, y - 5, 6)
    gfx.fillCircleAtPoint(x + 6, y - 6, 1)
    gfx.fillTriangle(x + 10, y - 4, x + 15, y - 2, x + 10, y)
    if chick.affection > 0 then
        gfx.drawText("*", x - 2, y - 20)
    end
end

function BabyChicks:drawHand()
    local x = math.floor(self.handX + 0.5)
    local y = math.floor(self.handY + 0.5)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(x, y, 7)
    gfx.fillRect(x - 4, y + 5, 8, 12)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawCircleAtPoint(x, y, 7)
    gfx.drawLine(x - 4, y + 4, x - 4, y + 16)
    gfx.drawLine(x + 4, y + 4, x + 4, y + 16)
    gfx.drawLine(x - 4, y + 16, x + 4, y + 16)
end

function BabyChicks:draw()
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, self.width, self.height)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(0, 39, self.width, 39)
    gfx.drawTextAligned("GARDEN OF CHICKS", self.width * 0.5, 10, kTextAlignment.center)
    gfx.drawTextAligned(string.format("Chicks %d", #self.chicks), 12, 25, kTextAlignment.left)

    if self.state == "egg" then
        self:drawEgg()
    end
    for _, chick in ipairs(self.chicks) do
        self:drawChick(chick)
    end
    self:drawHand()

    gfx.setColor(gfx.kColorBlack)
    gfx.drawTextAligned(self.status, self.width * 0.5, 211, kTextAlignment.center)
    if self.state == "egg" then
        gfx.drawTextAligned("A or pet the egg", self.width * 0.5, 225, kTextAlignment.center)
    elseif self.careProgress >= CARE_FOR_NEXT_EGG then
        gfx.drawTextAligned("A: hatch another", self.width * 0.5, 225, kTextAlignment.center)
    else
        gfx.drawTextAligned("Move the hand to pet", self.width * 0.5, 225, kTextAlignment.center)
    end
end
