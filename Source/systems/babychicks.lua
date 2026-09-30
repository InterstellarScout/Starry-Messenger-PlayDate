--[[
Baby Chicks mini-game and garden simulation.

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
local HATCH_INTERACTIONS <const> = 4
local CARE_FOR_NEXT_EGG <const> = 8
local HAND_SPEED <const> = 3
local FLOWER_SPAWN_FRAMES <const> = 150
local FLOWER_EAT_FRAMES <const> = 30
local FLOWER_START_COUNT <const> = 5
local GRASS_BLADE_COUNT <const> = 120

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function distanceSquared(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return (dx * dx) + (dy * dy)
end

local function moveToward(chick, targetX, targetY, speed)
    local dx = targetX - chick.x
    local dy = targetY - chick.y
    local length = math.sqrt((dx * dx) + (dy * dy))
    if length > 0.01 then
        chick.x = chick.x + ((dx / length) * speed)
        chick.y = chick.y + ((dy / length) * speed)
    end
end

function BabyChicks.new(width, height, options)
    options = options or {}
    local self = setmetatable({}, BabyChicks)
    self.width = width or SCREEN_WIDTH
    self.height = height or SCREEN_HEIGHT
    self.preview = options.preview == true
    self.handX = self.width * 0.5
    self.handY = 184
    self.handActionFrames = 0
    self.eggProgress = 0
    self.careProgress = 0
    self.petCooldown = 0
    self.frame = 0
    self.chicks = {}
    self.flowers = {}
    self.grass = {}
    self.flowerSpawnFrames = FLOWER_SPAWN_FRAMES
    self.eggX = self.width * 0.5
    self.eggY = 126
    self.eggTargetY = nil
    self.state = "egg"
    self.status = "I wonder what's inside?"

    for _ = 1, FLOWER_START_COUNT do
        self:spawnFlower()
    end
    self:seedGrass()

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
        seed = math.random() * math.pi * 2,
        affection = 0,
        hop = math.random() * math.pi * 2,
        eatFrames = 0,
        behavior = "wander"
    }
end

function BabyChicks:spawnFlower()
    self.flowers[#self.flowers + 1] = {
        x = 25 + math.random() * (self.width - 50),
        y = 73 + math.random() * 118,
        age = math.random(0, 75),
        health = 5,
        fallingFrames = 0,
        wind = math.random() * math.pi * 2
    }
end

function BabyChicks:seedGrass()
    for _ = 1, GRASS_BLADE_COUNT do
        self.grass[#self.grass + 1] = {
            x = 4 + math.random() * (self.width - 8),
            y = 52 + math.random() * (self.height - 91),
            height = math.random(3, 8),
            phase = math.random() * math.pi * 2,
            lean = math.random() < 0.5 and -1 or 1
        }
    end
end

function BabyChicks:loadGarden()
    local saved = pd.datastore and pd.datastore.read and pd.datastore.read(SAVE_KEY) or nil
    if type(saved) == "table" and type(saved.chicks) == "table" then
        for _, chick in ipairs(saved.chicks) do
            if type(chick) == "table" then
                self:addChick(clamp(tonumber(chick.x) or (self.width * 0.5), 20, 380), clamp(tonumber(chick.y) or 126, 54, 215))
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

function BabyChicks:beginEgg(dropX, dropY)
    self.state = "egg"
    self.eggProgress = 0
    self.eggX = clamp(dropX or self.handX, 18, self.width - 18)
    local handY = dropY or self.handY
    -- Reserve the lower status area, while ensuring a newly dropped egg lands
    -- below the hand rather than returning to the center of the garden.
    self.eggTargetY = clamp(handY + 28, 71, self.height - 54)
    self.eggY = math.max(61, self.eggTargetY - 18)
    self.status = "A mystery egg drops below your hand."
end

function BabyChicks:hatchEgg()
    self:addChick(self.eggX, self.eggY + 4)
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
    self.handActionFrames = 10
    local chick = self:getNearbyChick(28)
    if chick then
        self:petChick(chick)
    elseif self.state == "egg" and self:isHandTouching(self.eggX, self.eggY, 28) then
        self:interactWithEgg()
    elseif self.careProgress >= CARE_FOR_NEXT_EGG then
        self:beginEgg(self.handX, self.handY)
    elseif self.state == "egg" then
        self.status = "Move your hand to the egg."
    else
        self.status = "Find a chick to pet."
    end
end

function BabyChicks:handleDirectionalInput(leftHeld, rightHeld, upHeld, downHeld)
    local dx = (rightHeld and 1 or 0) - (leftHeld and 1 or 0)
    local dy = (downHeld and 1 or 0) - (upHeld and 1 or 0)
    self.handX = clamp(self.handX + (dx * HAND_SPEED), 10, self.width - 10)
    self.handY = clamp(self.handY + (dy * HAND_SPEED), 42, self.height - 75)
end

function BabyChicks:applyCrank(change)
    if math.abs(change or 0) > 0.01 then
        self.handX = clamp(self.handX + change, 10, self.width - 10)
    end
end

function BabyChicks:isHandTouching(x, y, radius)
    return distanceSquared(self.handX, self.handY, x, y) <= (radius * radius)
end

function BabyChicks:getNearbyChick(radius)
    local nearest, nearestDistance = nil, radius * radius
    for _, chick in ipairs(self.chicks) do
        local d2 = distanceSquared(self.handX, self.handY, chick.x, chick.y)
        if d2 <= nearestDistance then
            nearest, nearestDistance = chick, d2
        end
    end
    return nearest
end

function BabyChicks:petChick(chick)
    chick.affection = chick.affection + 1
    chick.hop = chick.hop + 1.5
    self.careProgress = self.careProgress + 1
    if self.careProgress >= CARE_FOR_NEXT_EGG then
        self.status = "A new mystery egg is ready! Press A."
    else
        self.status = "Peep! Your chick feels loved."
    end
end

function BabyChicks:getNearestFlower(chick)
    local nearest, nearestDistance = nil, math.huge
    for _, flower in ipairs(self.flowers) do
        if flower.health > 0 and flower.age >= 75 then
            local d2 = distanceSquared(chick.x, chick.y, flower.x, flower.y)
            if d2 < nearestDistance then nearest, nearestDistance = flower, d2 end
        end
    end
    return nearest, nearestDistance
end

function BabyChicks:getNearbyFriend(chick)
    for _, other in ipairs(self.chicks) do
        if other ~= chick and distanceSquared(chick.x, chick.y, other.x, other.y) < (42 * 42) then
            return other
        end
    end
    return nil
end

function BabyChicks:updateChick(chick)
    chick.hop = chick.hop + 0.10
    -- A nearby hand is more important than food, wandering, or play.
    if self:isHandTouching(chick.x, chick.y, 48) then
        chick.behavior = "hand"
        chick.eatFrames = 0
        moveToward(chick, self.handX, self.handY - 8, 0.55)
        return
    end
    local flower, flowerDistance = self:getNearestFlower(chick)
    if flower then
        if flowerDistance > (15 * 15) then
            chick.behavior = "flower"
            chick.eatFrames = 0
            moveToward(chick, flower.x, flower.y + 4, 0.6)
        else
            chick.behavior = "eating"
            chick.eatFrames = (chick.eatFrames or 0) + 1
            chick.hop = chick.hop + 0.16
            if chick.eatFrames >= FLOWER_EAT_FRAMES and flower.health > 0 then
                chick.eatFrames = 0
                flower.health = flower.health - 1
                self.status = "A chick nibbles a flower petal."
                if flower.health <= 0 then flower.fallingFrames = 1 end
            end
        end
        return
    end
    local friend = self:getNearbyFriend(chick)
    if friend then
        chick.behavior = "friend"
        if distanceSquared(chick.x, chick.y, friend.x, friend.y) > (18 * 18) then
            moveToward(chick, friend.x, friend.y, 0.45)
        else
            chick.hop = chick.hop + 0.25
        end
        return
    end
    chick.behavior = "wander"
    chick.eatFrames = 0
    chick.x = clamp(chick.x + math.cos((self.frame * 0.025) + chick.seed) * 0.35, 18, self.width - 18)
    chick.y = clamp(chick.y + math.sin((self.frame * 0.022) + chick.seed) * 0.25, 55, self.height - 25)
end

function BabyChicks:updateFlowers()
    self.flowerSpawnFrames = self.flowerSpawnFrames - 1
    if self.flowerSpawnFrames <= 0 then
        self:spawnFlower()
        self.flowerSpawnFrames = FLOWER_SPAWN_FRAMES
    end
    for index = #self.flowers, 1, -1 do
        local flower = self.flowers[index]
        if flower.health > 0 then
            flower.age = flower.age + 1
        else
            flower.fallingFrames = flower.fallingFrames + 1
            if flower.fallingFrames > 45 then table.remove(self.flowers, index) end
        end
    end
end

function BabyChicks:update()
    self.frame = self.frame + 1
    if self.handActionFrames > 0 then self.handActionFrames = self.handActionFrames - 1 end
    if self.eggTargetY ~= nil and self.eggY < self.eggTargetY then
        self.eggY = math.min(self.eggTargetY, self.eggY + 3)
        if self.eggY >= self.eggTargetY then self.eggTargetY = nil end
    end
    self:updateFlowers()
    for _, chick in ipairs(self.chicks) do self:updateChick(chick) end
end

function BabyChicks:drawGrass()
    gfx.setColor(gfx.kColorBlack)
    for _, blade in ipairs(self.grass) do
        local sway = math.sin((self.frame * 0.07) + blade.phase) * blade.lean * 1.8
        gfx.drawLine(blade.x, blade.y, blade.x + sway, blade.y - blade.height)
        if blade.height >= 6 then
            gfx.drawLine(blade.x + sway, blade.y - blade.height + 2, blade.x + sway + blade.lean * 2, blade.y - blade.height + 4)
        end
    end
end

function BabyChicks:drawNest()
    gfx.setColor(gfx.kColorBlack)
    for index = 0, 6 do
        local y = self.eggY + 15 + (index * 2)
        gfx.drawLine(self.eggX - 24 + (index % 2), y, self.eggX + 24 - (index % 2), y + 3)
    end
end

function BabyChicks:drawEgg()
    self:drawNest()
    local wobble = math.sin(self.frame * 0.18) * (self.eggProgress * 0.45)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillEllipseInRect(self.eggX - 13 + wobble, self.eggY - 18, 26, 35)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawEllipseInRect(self.eggX - 13 + wobble, self.eggY - 18, 26, 35)
    for crack = 1, self.eggProgress - 1 do
        gfx.drawLine(self.eggX - 5 + (crack * 3) + wobble, self.eggY - 6 + (crack * 3), self.eggX + 2 + (crack * 2) + wobble, self.eggY - 2 + (crack * 3))
    end
end

function BabyChicks:drawFlower(flower)
    local x, y = math.floor(flower.x + 0.5), math.floor(flower.y + 0.5)
    if flower.health <= 0 then
        if flower.fallingFrames < 34 then
            gfx.setColor(gfx.kColorBlack)
            gfx.drawLine(x - 3, y + 7, x + 11, y + 15)
            gfx.drawLine(x + 5, y + 10, x + 1, y + 14)
        end
        return
    end
    local sway = math.sin((self.frame * 0.08) + flower.wind) * 3
    gfx.setColor(gfx.kColorBlack)
    if flower.age < 25 then
        gfx.fillCircleAtPoint(x, y + 4, 2) -- bud
    elseif flower.age < 50 then
        gfx.drawLine(x, y + 8, x + sway, y - 3) -- sprout
        gfx.fillCircleAtPoint(x + sway, y - 4, 3)
    else
        gfx.drawLine(x, y + 9, x + sway, y - 7) -- grown stem waving in the wind
        gfx.drawLine(x + sway, y, x - 4, y - 2)
        gfx.drawLine(x + sway, y + 3, x + 5, y + 1)
        if flower.age < 75 then
            gfx.fillCircleAtPoint(x + sway, y - 8, 4)
        else
            for petal = 1, flower.health do
                local angle = ((petal - 1) / 5) * math.pi * 2 + (self.frame * 0.015)
                gfx.fillCircleAtPoint(x + sway + math.cos(angle) * 5, y - 8 + math.sin(angle) * 5, 3)
            end
            gfx.setColor(gfx.kColorWhite)
            gfx.fillCircleAtPoint(x + sway, y - 8, 2)
            gfx.setColor(gfx.kColorBlack)
            gfx.drawCircleAtPoint(x + sway, y - 8, 2)
        end
    end
end

function BabyChicks:drawChick(chick)
    local bob = math.sin(chick.hop) * (chick.behavior == "friend" and 5 or 2)
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
    if chick.affection > 0 or chick.behavior == "friend" then
        gfx.drawText("*", x - 2, y - 20)
    end
    if chick.behavior == "hand" then gfx.drawText("!", x - 2, y - 20) end
end

function BabyChicks:drawHand()
    local x = math.floor(self.handX + 0.5)
    local y = math.floor(self.handY + 0.5)
    gfx.setColor(gfx.kColorWhite)
    local closing = self.handActionFrames > 0 and (self.handActionFrames % 4 < 2)
    -- Palm, wrist, thumb, and articulated fingers give the cursor a clear
    -- hand silhouette rather than a round glove.
    gfx.fillRoundRect(x - 8, y - 1, 17, 18, 6)
    gfx.fillRoundRect(x - 4, y + 14, 10, 11, 3)
    gfx.fillRoundRect(x - 14, y + 2, 8, 10, 4)
    if closing then
        for finger = -5, 5, 4 do gfx.fillRoundRect(x + finger - 1, y - 7, 3, 8, 2) end
    else
        for finger = -5, 5, 4 do gfx.fillRoundRect(x + finger - 1, y - 13, 3, 14, 2) end
    end
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(x - 8, y - 1, 17, 18, 6)
    gfx.drawRoundRect(x - 4, y + 14, 10, 11, 3)
    gfx.drawRoundRect(x - 14, y + 2, 8, 10, 4)
    if closing then
        for finger = -5, 5, 4 do gfx.drawLine(x + finger - 1, y - 7, x + finger - 1, y) end
    else
        for finger = -5, 5, 4 do gfx.drawLine(x + finger - 1, y - 13, x + finger - 1, y - 1) end
    end
end

function BabyChicks:draw()
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, self.width, self.height)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(0, 39, self.width, 39)
    gfx.drawTextAligned("GARDEN OF CHICKS", self.width * 0.5, 10, kTextAlignment.center)
    gfx.drawTextAligned(string.format("Chicks %d", #self.chicks), 12, 25, kTextAlignment.left)

    self:drawGrass()
    for _, flower in ipairs(self.flowers) do self:drawFlower(flower) end
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
        gfx.drawTextAligned("Move to egg, then A", self.width * 0.5, 225, kTextAlignment.center)
    elseif self.careProgress >= CARE_FOR_NEXT_EGG then
        gfx.drawTextAligned("A: drop another egg", self.width * 0.5, 225, kTextAlignment.center)
    else
        gfx.drawTextAligned("Move hand near a chick, then A", self.width * 0.5, 225, kTextAlignment.center)
    end
end
