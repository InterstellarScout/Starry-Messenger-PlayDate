import "systems/starfield"

--[[
Starry Top view.

Purpose:
- presents a stripped-down star spinner without Warp Speed menus
- keeps one Warp Speed-style star field on screen while crank controls center rotation
- uses Up/Down for depth direction and Left/Right for depth speed
]]

StarryTop = {}
StarryTop.__index = StarryTop

local pd <const> = playdate
local gfx <const> = pd.graphics
local WARP_CONFIG <const> = GameConfig and GameConfig.warp or {}

local SPIN_CRANK_STEP_DEGREES <const> = 18
local DEFAULT_SPIN_SPEED <const> = 0
local WARP_SPEED_STEP <const> = 1
local CIRCULAR_SPAWN_MARGIN <const> = 8

local SPIN_SPEED_STEPS <const> = {
    3, 2, 1, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1,
    0,
    -0.1, -0.2, -0.3, -0.4, -0.5, -0.6, -0.7, -0.8, -0.9, -1, -2, -3
}
local SPIN_ZERO_INDEX <const> = 13

local function sign(value)
    if value < 0 then
        return -1
    elseif value > 0 then
        return 1
    end
    return 0
end

local function randomPointInCircle(centerX, centerY, radius)
    local angle = math.random() * (math.pi * 2)
    local distance = math.sqrt(math.random()) * radius
    return centerX + (math.cos(angle) * distance), centerY + (math.sin(angle) * distance)
end

function StarryTop.new(width, height, options)
    options = options or {}
    local self = setmetatable({}, StarryTop)
    self.width = width or 400
    self.height = height or 240
    self.preview = options.preview == true
    self.field = Starfield.newWarpSpeed(self.width, self.height, WARP_CONFIG.liveStarCount or 130, {
        modeId = Starfield.MODE_STANDARD
    })
    self:configureCircularSpawn()
    self.field.speed = 0
    self.spinSpeedIndex = self.preview and (SPIN_ZERO_INDEX + 7) or SPIN_ZERO_INDEX
    self.spinSpeed = SPIN_SPEED_STEPS[self.spinSpeedIndex] or DEFAULT_SPIN_SPEED
    self.warpSpeed = 0
    self.warpDirection = 0
    self.crankStepAccumulator = 0
    self.controlsLocked = false
    return self
end

function StarryTop:configureCircularSpawn()
    local halfWidth = self.width * 0.5
    local halfHeight = self.height * 0.5
    local radius = math.sqrt((halfWidth * halfWidth) + (halfHeight * halfHeight)) + CIRCULAR_SPAWN_MARGIN
    self.field.circularWarpSpawn = true
    self.field.circularWarpSpawnRadius = radius

    for _, star in ipairs(self.field.stars or {}) do
        local screenX, screenY = randomPointInCircle(self.field.centerX, self.field.centerY, radius)
        local worldX, worldY = self.field:screenToWorld(screenX, screenY)
        star.x = worldX - self.field.playerCenterX
        star.y = worldY - self.field.playerCenterY
        star.px = star.x
        star.py = star.y
        star.spawnFadeFrames = 0
        star.despawnRadius = 0
        if self.field.updateWarpStarScreenCache then
            self.field:updateWarpStarScreenCache(star)
        end
    end
end

function StarryTop:setPreview(preview)
    self.preview = preview == true
    if self.preview and (self.spinSpeed or 0) == 0 then
        self.spinSpeedIndex = SPIN_ZERO_INDEX + 7
        self.spinSpeed = SPIN_SPEED_STEPS[self.spinSpeedIndex] or 0.7
    end
end

function StarryTop:activate()
end

function StarryTop:shutdown()
end

function StarryTop:stepSpinSpeed(direction)
    if direction == 0 then
        return
    end

    local currentSpeed = self.spinSpeed or 0
    if currentSpeed > 3 or currentSpeed < -3 then
        self.spinSpeed = currentSpeed + direction
        return
    end

    local nextIndex = (self.spinSpeedIndex or SPIN_ZERO_INDEX) - direction
    if nextIndex < 1 then
        self.spinSpeedIndex = 1
        self.spinSpeed = (SPIN_SPEED_STEPS[1] or 3) + direction
    elseif nextIndex > #SPIN_SPEED_STEPS then
        self.spinSpeedIndex = #SPIN_SPEED_STEPS
        self.spinSpeed = (SPIN_SPEED_STEPS[#SPIN_SPEED_STEPS] or -3) + direction
    else
        self.spinSpeedIndex = nextIndex
        self.spinSpeed = SPIN_SPEED_STEPS[self.spinSpeedIndex] or 0
    end
end

function StarryTop:applyCrank(change, acceleratedChange)
    if self.controlsLocked or math.abs(change or 0) <= 0.01 then
        return
    end

    self.crankStepAccumulator = (self.crankStepAccumulator or 0) + (change or 0)
    while math.abs(self.crankStepAccumulator) >= SPIN_CRANK_STEP_DEGREES do
        local direction = sign(self.crankStepAccumulator)
        self:stepSpinSpeed(direction)
        self.crankStepAccumulator = self.crankStepAccumulator - (SPIN_CRANK_STEP_DEGREES * direction)
    end
end

function StarryTop:handlePrimaryAction()
    if self.preview then
        return
    end
    self.controlsLocked = not self.controlsLocked
end

function StarryTop:handleDirectionalInput(_leftHeld, _rightHeld, upHeld, downHeld, leftJustPressed, rightJustPressed)
    if self.preview or self.controlsLocked then
        return
    end

    if leftJustPressed then
        self.warpSpeed = math.max(0, (self.warpSpeed or 0) - WARP_SPEED_STEP)
    end
    if rightJustPressed then
        self.warpSpeed = (self.warpSpeed or 0) + WARP_SPEED_STEP
    end

    if upHeld and not downHeld then
        self.warpDirection = 1
    elseif downHeld and not upHeld then
        self.warpDirection = -1
    else
        self.warpDirection = 0
    end
end

function StarryTop:update()
    if self.preview then
        self.warpDirection = 0
    end

    self.field.speed = (self.warpSpeed or 0) * (self.warpDirection or 0)
    self.field.screenAngle = (self.field.screenAngle or 0) + (self.spinSpeed or 0)
    self.field.screenAngleRadians = math.rad(self.field.screenAngle)
    self.field.screenCos = math.cos(self.field.screenAngleRadians)
    self.field.screenSin = math.sin(self.field.screenAngleRadians)
    self.field:update()
end

function StarryTop:drawHud()
    if self.preview or (UIState and not UIState.isShown()) then
        return
    end

    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawText("Starry Top", 10, 8)
    gfx.drawText(string.format("Spin %.1f  Warp %d Dir %d%s", self.spinSpeed or 0, self.warpSpeed or 0, self.warpDirection or 0, self.controlsLocked and "  Locked" or ""), 10, 24)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function StarryTop:draw()
    gfx.clear(gfx.kColorBlack)
    self.field:draw()
    self:drawHud()
end
