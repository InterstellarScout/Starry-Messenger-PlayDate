import "gameconfig"

--[[
Fireworks show system.

Purpose:
- simulates automatic and player-fired fireworks with several burst styles
- handles launcher movement, shell spawning, spark lifetimes, and preview mode
- provides the compact fireworks toy used by the title and gameplay scenes
]]
local gfx <const> = playdate.graphics
local FIREWORKS_CONFIG <const> = GameConfig and GameConfig.fireworks or {}

FireworksShow = {}
FireworksShow.__index = FireworksShow

-- Development tuning limits. Raise carefully on hardware.
local MAX_ACTIVE_SPARKS <const> = FIREWORKS_CONFIG.maxActiveSparks or 200
local MAX_SPARKS_PER_FIREWORK <const> = FIREWORKS_CONFIG.maxSparksPerFirework or 56
local SPARK_LIFESPAN_MIN <const> = FIREWORKS_CONFIG.sparkLifespanMin or 18
local SPARK_LIFESPAN_MAX <const> = FIREWORKS_CONFIG.sparkLifespanMax or 34
local AUTO_LAUNCH_INTERVAL_MIN <const> = FIREWORKS_CONFIG.autoLaunchIntervalMin or 3
local AUTO_LAUNCH_INTERVAL_MAX <const> = FIREWORKS_CONFIG.autoLaunchIntervalMax or 10
local MAX_EXPLOSION_HEIGHT_PERCENT <const> = FIREWORKS_CONFIG.maxExplosionHeightPercent or 0.95
local MIN_EXPLOSION_HEIGHT_PERCENT <const> = FIREWORKS_CONFIG.minExplosionHeightPercent or 0.58
local BACKGROUND_STAR_COUNT <const> = FIREWORKS_CONFIG.backgroundStarCount or 20

local GRAVITY <const> = FIREWORKS_CONFIG.gravity or 0.16
local TAU <const> = math.pi * 2

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function lerp(a, b, t)
    return a + ((b - a) * t)
end

local function randomRange(minValue, maxValue)
    return minValue + (math.random() * (maxValue - minValue))
end

local function wrapHorizontal(value, width, margin)
    if value < -margin then
        return width + margin
    elseif value > width + margin then
        return -margin
    end

    return value
end

local function addTrailPoint(entity)
    entity.trail[#entity.trail + 1] = {
        x = entity.x,
        y = entity.y
    }

    if #entity.trail > entity.trailLimit then
        table.remove(entity.trail, 1)
    end
end

function FireworksShow.new(width, height, options)
    local self = setmetatable({}, FireworksShow)
    self.width = width
    self.height = height
    self.preview = options and options.preview or false
    self.launcherX = width / 2
    self.shells = {}
    self.sparks = {}
    self.autoLaunchTimer = 0
    self.backgroundPhase = math.random() * TAU
    self.styleOrder = { "standard", "willow", "grasser" }
    self.selectedStyleIndex = 1
    self.backgroundStars = {}
    for index = 1, BACKGROUND_STAR_COUNT do
        self.backgroundStars[index] = {
            x = randomRange(8, width - 8),
            y = randomRange(10, math.floor(height * 0.34)),
            drift = randomRange(2, 11),
            phase = math.random() * TAU,
            size = math.random() < 0.18 and 2 or 1
        }
    end
    self:resetAutoLaunchTimer()
    return self
end

function FireworksShow:setPreview(isPreview)
    self.preview = isPreview and true or false
end

function FireworksShow:resetAutoLaunchTimer()
    self.autoLaunchTimer = randomRange(AUTO_LAUNCH_INTERVAL_MIN, AUTO_LAUNCH_INTERVAL_MAX)
end

function FireworksShow:moveLauncher(delta)
    self.launcherX = wrapHorizontal(self.launcherX + (delta * 1.9), self.width, 12)
end

function FireworksShow:getWrappedLauncherX()
    if self.launcherX < 0 then
        return self.launcherX + self.width
    elseif self.launcherX > self.width then
        return self.launcherX - self.width
    end

    return self.launcherX
end

function FireworksShow:getSelectedStyle()
    return self.styleOrder[self.selectedStyleIndex]
end

function FireworksShow:stepSelectedStyle(direction)
    if direction == 0 then
        return
    end

    self.selectedStyleIndex = self.selectedStyleIndex + direction
    if self.selectedStyleIndex < 1 then
        self.selectedStyleIndex = #self.styleOrder
    elseif self.selectedStyleIndex > #self.styleOrder then
        self.selectedStyleIndex = 1
    end
end

function FireworksShow:getStyleLabel(style)
    if style == "willow" then
        return "Willow"
    elseif style == "grasser" then
        return "Grasser"
    end

    return "Standard"
end

function FireworksShow:getRandomStyle()
    return self.styleOrder[math.random(1, #self.styleOrder)]
end

function FireworksShow:spawnShell(x, style)
    local shellStyle = style or self:getRandomStyle()
    local horizontalScale = shellStyle == "willow" and 0.85 or (shellStyle == "grasser" and 1.1 or 0.65)
    local shell = {
        x = x,
        y = self.height - 10,
        vx = randomRange(-1.2, 1.2) * horizontalScale,
        vy = -randomRange(4.8, 7.6),
        size = randomRange(3.5, 5.5),
        style = shellStyle,
        popY = self.height * (1 - randomRange(MIN_EXPLOSION_HEIGHT_PERCENT, MAX_EXPLOSION_HEIGHT_PERCENT)),
        trail = {},
        trailLimit = shellStyle == "willow" and 18 or 12
    }

    self.shells[#self.shells + 1] = shell
end

function FireworksShow:launchFromLauncher()
    self:spawnShell(self:getWrappedLauncherX(), self:getSelectedStyle())
end

function FireworksShow:spawnAutoFirework()
    self:spawnShell(randomRange(10, self.width - 10), self:getRandomStyle())
end

function FireworksShow:spawnSpark(shell, angle, speed, life, gravityScale, trailLimit)
    if #self.sparks >= MAX_ACTIVE_SPARKS then
        return false
    end

    self.sparks[#self.sparks + 1] = {
        x = shell.x,
        y = shell.y,
        vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed,
        life = life,
        defaultLife = life,
        gravity = gravityScale,
        style = shell.style,
        size = randomRange(1.6, 2.8),
        trail = {},
        trailLimit = trailLimit
    }

    return true
end

function FireworksShow:makeRoomForSparks(requiredSlots)
    local overflow = (#self.sparks + requiredSlots) - MAX_ACTIVE_SPARKS

    while overflow > 0 and #self.sparks > 0 do
        table.remove(self.sparks, math.random(1, #self.sparks))
        overflow = overflow - 1
    end
end

function FireworksShow:explodeShell(shell)
    local sparkCount
    local sparkLifeMin = SPARK_LIFESPAN_MIN
    local sparkLifeMax = SPARK_LIFESPAN_MAX
    local trailLimit = 9

    if shell.style == "willow" then
        sparkCount = math.random(24, math.min(MAX_SPARKS_PER_FIREWORK, 48))
        sparkLifeMin = SPARK_LIFESPAN_MIN + 10
        sparkLifeMax = SPARK_LIFESPAN_MAX + 14
        trailLimit = 16
    elseif shell.style == "grasser" then
        sparkCount = math.random(18, math.min(MAX_SPARKS_PER_FIREWORK, 40))
        sparkLifeMin = SPARK_LIFESPAN_MIN + 4
        sparkLifeMax = SPARK_LIFESPAN_MAX + 6
        trailLimit = 12
    else
        sparkCount = math.random(24, MAX_SPARKS_PER_FIREWORK)
    end

    sparkCount = math.min(sparkCount, MAX_ACTIVE_SPARKS)
    self:makeRoomForSparks(sparkCount)

    for index = 1, sparkCount do
        local angle = ((index - 1) / math.max(1, sparkCount)) * TAU
        angle = angle + randomRange(-0.18, 0.18)
        local speed
        local gravityScale

        if shell.style == "willow" then
            speed = randomRange(0.8, 2.1)
            gravityScale = GRAVITY * randomRange(1.3, 1.8)
        elseif shell.style == "grasser" then
            speed = randomRange(1.1, 2.5)
            gravityScale = GRAVITY * randomRange(1.8, 2.4)
        else
            speed = randomRange(1.2, 3.1)
            gravityScale = GRAVITY * randomRange(0.8, 1.2)
        end

        local life = math.random(sparkLifeMin, sparkLifeMax)
        if shell.style == "grasser" then
            local horizontalBoost = math.cos(angle) * speed * 1.2
            local upwardBias = (math.sin(angle) * speed * 0.45) - randomRange(0.2, 0.7)
            if not self:spawnSpark(shell, 0, 0, life, gravityScale, trailLimit) then
                break
            end
            local spark = self.sparks[#self.sparks]
            spark.vx = horizontalBoost
            spark.vy = upwardBias
        else
            if not self:spawnSpark(shell, angle, speed, life, gravityScale, trailLimit) then
                break
            end

            if shell.style == "willow" then
                local spark = self.sparks[#self.sparks]
                spark.vx = spark.vx * 0.8
                spark.vy = (spark.vy * 0.6) - 0.3
            end
        end
    end
end

function FireworksShow:updateShells()
    for index = #self.shells, 1, -1 do
        local shell = self.shells[index]
        addTrailPoint(shell)
        shell.x = shell.x + shell.vx
        shell.y = shell.y + shell.vy
        shell.vy = shell.vy + GRAVITY

        if shell.vy >= 0 or shell.y <= shell.popY then
            self:explodeShell(shell)
            table.remove(self.shells, index)
        elseif shell.x < -12 or shell.x > self.width + 12 or shell.y < -12 then
            table.remove(self.shells, index)
        end
    end
end

function FireworksShow:updateSparks()
    for index = #self.sparks, 1, -1 do
        local spark = self.sparks[index]
        addTrailPoint(spark)
        spark.x = spark.x + spark.vx
        spark.y = spark.y + spark.vy
        spark.vy = spark.vy + spark.gravity
        spark.life = spark.life - 1
        spark.size = math.max(0.8, spark.size * 0.985)

        if spark.style == "willow" then
            spark.vx = spark.vx * 0.985
        elseif spark.style == "grasser" then
            spark.vx = spark.vx * 0.992
        end

        if spark.life <= 0 or spark.x < -18 or spark.x > self.width + 18 or spark.y > self.height + 18 then
            table.remove(self.sparks, index)
        end
    end
end

function FireworksShow:update()
    self.backgroundPhase = self.backgroundPhase + 0.02
    self.autoLaunchTimer = self.autoLaunchTimer - (1 / 30)

    if self.autoLaunchTimer <= 0 then
        self:spawnAutoFirework()
        self:resetAutoLaunchTimer()
    end

    self:updateShells()
    self:updateSparks()
end

function FireworksShow:drawCircle(x, y, radius, filled)
    local size = radius * 2
    if filled then
        gfx.fillEllipseInRect(x - radius, y - radius, size, size)
    else
        gfx.drawEllipseInRect(x - radius, y - radius, size, size)
    end
end

function FireworksShow:drawShell(shell)
    for index = 2, #shell.trail do
        local previous = shell.trail[index - 1]
        local point = shell.trail[index]
        gfx.drawLine(previous.x, previous.y, point.x, point.y)
    end

    self:drawCircle(shell.x, shell.y, shell.size * 1.8, false)
    self:drawCircle(shell.x, shell.y, shell.size, true)
end

function FireworksShow:drawSpark(spark)
    for index = 2, #spark.trail do
        local previous = spark.trail[index - 1]
        local point = spark.trail[index]
        if spark.style == "willow" then
            gfx.drawLine(previous.x, previous.y, point.x, point.y)
        elseif index % 2 == 0 then
            gfx.drawLine(previous.x, previous.y, point.x, point.y)
        end
    end

    self:drawCircle(spark.x, spark.y, spark.size * 0.6, true)
end

function FireworksShow:drawLauncherAt(x)
    local baseY = self.height - 8
    gfx.fillRect(x - 5, baseY - 8, 10, 8)
    gfx.drawLine(x, baseY - 8, x, baseY - 14)
end

function FireworksShow:drawLauncher()
    local x = self.launcherX
    gfx.drawLine(0, self.height - 4, self.width, self.height - 4)
    self:drawLauncherAt(x)

    if x < 12 then
        self:drawLauncherAt(x + self.width + 12)
    elseif x > self.width - 12 then
        self:drawLauncherAt(x - self.width - 12)
    end
end

function FireworksShow:drawSky()
    for _, star in ipairs(self.backgroundStars) do
        local x = star.x + (math.sin(self.backgroundPhase + star.phase) * star.drift)
        gfx.fillRect(x, star.y, star.size, star.size)
    end
end

function FireworksShow:drawHud()
    if self.preview then
        return
    end

    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawText("Fireworks", 10, 8)
    gfx.drawText(string.format("Shells %d  Sparks %d/%d", #self.shells, #self.sparks, MAX_ACTIVE_SPARKS), 10, 24)
    gfx.drawText("Type: " .. self:getStyleLabel(self:getSelectedStyle()), 10, 40)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function FireworksShow:draw()
    self:drawSky()

    for _, shell in ipairs(self.shells) do
        self:drawShell(shell)
    end

    for _, spark in ipairs(self.sparks) do
        self:drawSpark(spark)
    end

    self:drawLauncher()
    self:drawHud()
end
