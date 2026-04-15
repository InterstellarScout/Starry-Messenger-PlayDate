--[[
RC Arena gameplay system.

Purpose:
- runs the Block Chase, Crash Arena, and Puck Ring variants
- handles shared RC car movement, puck or block interactions, and AI rivals
- provides the title-preview and live-view behavior for the RC modes
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

RCCarArena = {}
RCCarArena.__index = RCCarArena

RCCarArena.MODE_CHASE = "chase"
RCCarArena.MODE_VERSUS = "versus"
RCCarArena.MODE_HOCKEY = "hockey"

local CAR_LENGTH <const> = 18
local CAR_WIDTH <const> = 10
local CAR_SPEED_RESPONSE <const> = 0.2
local CAR_BRAKE_RESPONSE <const> = 0.28
local CAR_BUTTON_SPEED_STEP <const> = 0.18
local CAR_BUTTON_TURN_STEP <const> = 0.08
local CAR_AI_TURN_STEP <const> = 0.06
local CAR_CRANK_ROTATE_SCALE <const> = math.pi / 160
local CAR_CRANK_SPEED_SCALE <const> = 0.12
local CAR_DEFAULT_MAX_SPEED <const> = 7
local CAR_PREVIEW_SPEED_MIN <const> = 1.8
local CAR_PREVIEW_SPEED_VARIATION <const> = 2.1
local CAR_BUMP_RECOIL <const> = 0.28
local CAR_WRAP_MARGIN <const> = CAR_LENGTH
local BLOCK_COUNT <const> = 6
local BLOCK_SIZE <const> = 10
local BLOCK_SLIDE_FRICTION <const> = 0.965
local BLOCK_PUSH_IMPULSE <const> = 0.42
local BLOCK_RESPAWN_FRAMES <const> = 12
local HOCKEY_PUCK_COUNT <const> = 5
local HOCKEY_NET_HALF_HEIGHT <const> = 28

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function sign(value)
    if value < 0 then
        return -1
    elseif value > 0 then
        return 1
    end
    return 0
end

local function vectorLength(x, y)
    return math.sqrt((x * x) + (y * y))
end

local function limitVector(x, y, maxLength)
    local currentLength = vectorLength(x, y)
    if currentLength == 0 or currentLength <= maxLength then
        return x, y
    end

    local scale = maxLength / currentLength
    return x * scale, y * scale
end

local function normalizeAngle(angle)
    local tau = math.pi * 2
    while angle <= -math.pi do
        angle = angle + tau
    end
    while angle > math.pi do
        angle = angle - tau
    end
    return angle
end

local function steerAngleToward(currentAngle, targetAngle, step)
    local delta = normalizeAngle(targetAngle - currentAngle)
    if math.abs(delta) <= step then
        return targetAngle
    end
    return currentAngle + (step * sign(delta))
end

local function rotateLocalPoint(x, y, angle)
    local cosine = math.cos(angle)
    local sine = math.sin(angle)
    return (x * cosine) - (y * sine), (x * sine) + (y * cosine)
end

function RCCarArena.getModeLabel(modeId)
    if modeId == RCCarArena.MODE_VERSUS then
        return "Crash Arena"
    elseif modeId == RCCarArena.MODE_HOCKEY then
        return "Puck Ring"
    end

    return "Block Chase"
end

function RCCarArena.new(width, height, modeId, options)
    local self = setmetatable({}, RCCarArena)
    self.width = width
    self.height = height
    self.modeId = modeId or RCCarArena.MODE_CHASE
    self.preview = options and options.preview or false
    self.playerCount = math.max(2, math.floor(options and options.playerCount or 2))
    self.time = 0
    self.cars = {}
    self.objects = {}
    self.playerCar = nil
    self.playerInputX = 0
    self.playerInputY = 0
    self.playerTargetSpeed = 0
    self.playerMaxSpeed = CAR_DEFAULT_MAX_SPEED
    self.crankMode = "rotate"
    self.playerKnockouts = 0
    self.opponentKnockouts = 0
    self.leftNetCount = 0
    self.rightNetCount = 0
    self:reset(self.modeId)
    return self
end

function RCCarArena:setPreview(isPreview)
    self.preview = isPreview and true or false
end

function RCCarArena:activate()
end

function RCCarArena:shutdown()
end

function RCCarArena:setCarSpawn(car, side)
    local margin = CAR_WRAP_MARGIN
    if side == "left" then
        car.x = -margin
        car.y = 36 + math.random() * (self.height - 72)
    elseif side == "right" then
        car.x = self.width + margin
        car.y = 36 + math.random() * (self.height - 72)
    elseif side == "top" then
        car.x = 36 + math.random() * (self.width - 72)
        car.y = -margin
    else
        car.x = 36 + math.random() * (self.width - 72)
        car.y = self.height + margin
    end

    if side == "left" then
        car.heading = 0
    elseif side == "right" then
        car.heading = math.pi
    elseif side == "top" then
        car.heading = math.pi * 0.5
    else
        car.heading = -math.pi * 0.5
    end
end

function RCCarArena:addCar(isPlayer, side)
    local car = {
        x = 0,
        y = 0,
        vx = 0,
        vy = 0,
        heading = 0,
        driveSpeed = 0,
        targetSpeed = 0,
        player = isPlayer,
        ai = (not isPlayer) or self.preview,
        side = side or (isPlayer and "left" or "right")
    }

    self:setCarSpawn(car, car.side)
    self.cars[#self.cars + 1] = car
    if isPlayer then
        self.playerCar = car
    end
end

function RCCarArena:spawnObject(object)
    local side = math.random(1, 4)
    object.size = BLOCK_SIZE
    object.spawnTimer = BLOCK_RESPAWN_FRAMES
    object.lastTouchedBy = nil

    if side == 1 then
        object.x = -object.size
        object.y = 30 + math.random() * (self.height - 60)
        object.vx = 2 + math.random() * 2
        object.vy = (math.random() * 2) - 1
    elseif side == 2 then
        object.x = self.width + object.size
        object.y = 30 + math.random() * (self.height - 60)
        object.vx = -2 - (math.random() * 2)
        object.vy = (math.random() * 2) - 1
    elseif side == 3 then
        object.x = 30 + math.random() * (self.width - 60)
        object.y = -object.size
        object.vx = (math.random() * 2) - 1
        object.vy = 2 + math.random() * 2
    else
        object.x = 30 + math.random() * (self.width - 60)
        object.y = self.height + object.size
        object.vx = (math.random() * 2) - 1
        object.vy = -2 - (math.random() * 2)
    end
end

function RCCarArena:addObject()
    local object = {
        x = self.width / 2,
        y = self.height / 2,
        vx = 0,
        vy = 0,
        size = BLOCK_SIZE,
        spawnTimer = 0,
        lastTouchedBy = nil
    }
    self:spawnObject(object)
    self.objects[#self.objects + 1] = object
end

function RCCarArena:reset(modeId)
    self.modeId = modeId or self.modeId
    self.time = 0
    self.cars = {}
    self.objects = {}
    self.playerCar = nil
    self.playerInputX = 0
    self.playerInputY = 0
    self.playerTargetSpeed = 0
    self.playerMaxSpeed = CAR_DEFAULT_MAX_SPEED
    self.crankMode = "rotate"
    self.playerKnockouts = 0
    self.opponentKnockouts = 0
    self.leftNetCount = 0
    self.rightNetCount = 0

    self:addCar(true, "left")
    if self.modeId == RCCarArena.MODE_VERSUS or self.modeId == RCCarArena.MODE_HOCKEY then
        local sides = { "right", "top", "bottom" }
        local opponentCount = self.preview and 1 or math.max(1, self.playerCount - 1)
        for index = 1, opponentCount do
            self:addCar(false, sides[index] or "right")
        end
    end

    local objectCount = self.modeId == RCCarArena.MODE_HOCKEY and HOCKEY_PUCK_COUNT or BLOCK_COUNT
    for _ = 1, objectCount do
        self:addObject()
    end
end

function RCCarArena:applyCrankInput(change)
    if self.preview or not self.playerCar or math.abs(change) <= 0.01 then
        return
    end

    if self.crankMode == "speed" then
        self.playerMaxSpeed = math.max(0, self.playerMaxSpeed + (change * CAR_CRANK_SPEED_SCALE))
        self.playerTargetSpeed = clamp(self.playerTargetSpeed, -self.playerMaxSpeed, self.playerMaxSpeed)
    else
        self.playerCar.heading = self.playerCar.heading + (change * CAR_CRANK_ROTATE_SCALE)
    end
end

function RCCarArena:toggleCrankMode()
    if self.preview then
        return
    end

    self.crankMode = self.crankMode == "rotate" and "speed" or "rotate"
end

function RCCarArena:updatePlayerInput(leftPressed, rightPressed, upPressed, downPressed)
    self.playerInputX = 0
    if leftPressed then
        self.playerInputX = self.playerInputX - 1
    end
    if rightPressed then
        self.playerInputX = self.playerInputX + 1
    end

    self.playerInputY = 0
    if upPressed then
        self.playerInputY = self.playerInputY + 1
    end
    if downPressed then
        self.playerInputY = self.playerInputY - 1
    end
end

function RCCarArena:getNearestObject(x, y)
    local nearestObject = nil
    local nearestDistanceSquared = math.huge

    for _, object in ipairs(self.objects) do
        local dx = object.x - x
        local dy = object.y - y
        local distanceSquared = (dx * dx) + (dy * dy)
        if distanceSquared < nearestDistanceSquared then
            nearestDistanceSquared = distanceSquared
            nearestObject = object
        end
    end

    return nearestObject
end

function RCCarArena:getAITarget(car)
    local targetObject = self:getNearestObject(car.x, car.y)
    if not targetObject then
        return self.width / 2, self.height / 2
    end

    local targetX = targetObject.x
    local targetY = targetObject.y

    if self.modeId == RCCarArena.MODE_HOCKEY and not car.player then
        targetX = targetX + 18
    elseif self.modeId == RCCarArena.MODE_HOCKEY and car.player then
        targetX = targetX - 18
    end

    return targetX, targetY
end

function RCCarArena:updateCars()
    local previewSpeed = CAR_PREVIEW_SPEED_MIN + (math.abs(math.sin(self.time * 1.2)) * CAR_PREVIEW_SPEED_VARIATION)

    if not self.preview then
        self.playerTargetSpeed = clamp(
            self.playerTargetSpeed + (self.playerInputY * CAR_BUTTON_SPEED_STEP),
            -self.playerMaxSpeed,
            self.playerMaxSpeed
        )
    end

    for _, car in ipairs(self.cars) do
        if car.player and not self.preview then
            if self.playerInputX ~= 0 then
                car.heading = car.heading + (self.playerInputX * CAR_BUTTON_TURN_STEP)
            end
            car.targetSpeed = self.playerTargetSpeed
        else
            local targetX, targetY = self:getAITarget(car)
            local desiredHeading = math.atan(targetY - car.y, targetX - car.x)
            car.heading = steerAngleToward(car.heading, desiredHeading, CAR_AI_TURN_STEP)

            if self.preview then
                car.targetSpeed = previewSpeed
            elseif (self.modeId == RCCarArena.MODE_VERSUS or self.modeId == RCCarArena.MODE_HOCKEY) and self.playerCar then
                car.targetSpeed = self.playerCar.driveSpeed
            else
                if self.playerTargetSpeed == 0 then
                    car.targetSpeed = 0
                else
                    local minimumMagnitude = math.min(0.8, math.abs(self.playerTargetSpeed))
                    car.targetSpeed = sign(self.playerTargetSpeed) * math.max(minimumMagnitude, math.abs(self.playerTargetSpeed))
                end
            end
        end

        car.heading = normalizeAngle(car.heading)
        local speedResponse = car.targetSpeed >= car.driveSpeed and CAR_SPEED_RESPONSE or CAR_BRAKE_RESPONSE
        car.driveSpeed = car.driveSpeed + ((car.targetSpeed - car.driveSpeed) * speedResponse)
        car.vx = math.cos(car.heading) * car.driveSpeed
        car.vy = math.sin(car.heading) * car.driveSpeed
        car.x = car.x + car.vx
        car.y = car.y + car.vy

        if self.modeId == RCCarArena.MODE_HOCKEY then
            local topLimit = 20 + CAR_WIDTH
            local bottomLimit = self.height - 20 - CAR_WIDTH
            car.x = clamp(car.x, 12 + CAR_LENGTH, self.width - 12 - CAR_LENGTH)
            car.y = clamp(car.y, topLimit, bottomLimit)
            if car.x == 12 + CAR_LENGTH or car.x == self.width - 12 - CAR_LENGTH then
                car.vx = -car.vx * 0.4
            end
            if car.y == topLimit or car.y == bottomLimit then
                car.vy = -car.vy * 0.4
            end
        else
            if car.x < -CAR_WRAP_MARGIN then
                car.x = self.width + CAR_WRAP_MARGIN
            elseif car.x > self.width + CAR_WRAP_MARGIN then
                car.x = -CAR_WRAP_MARGIN
            end
            if car.y < -CAR_WRAP_MARGIN then
                car.y = self.height + CAR_WRAP_MARGIN
            elseif car.y > self.height + CAR_WRAP_MARGIN then
                car.y = -CAR_WRAP_MARGIN
            end
        end

    end
end

function RCCarArena:respawnObjectForScore(object)
    if self.modeId == RCCarArena.MODE_CHASE then
        if object.lastTouchedBy == "player" then
            self.playerKnockouts = self.playerKnockouts + 1
        end
    elseif self.modeId == RCCarArena.MODE_VERSUS then
        if object.lastTouchedBy == "player" then
            self.playerKnockouts = self.playerKnockouts + 1
        elseif object.lastTouchedBy == "opponent" then
            self.opponentKnockouts = self.opponentKnockouts + 1
        end
    end

    self:spawnObject(object)
end

function RCCarArena:updateObjects()
    for _, object in ipairs(self.objects) do
        object.x = object.x + object.vx
        object.y = object.y + object.vy
        object.vx = object.vx * BLOCK_SLIDE_FRICTION
        object.vy = object.vy * BLOCK_SLIDE_FRICTION

        if object.spawnTimer > 0 then
            object.spawnTimer = object.spawnTimer - 1
        end

        if self.modeId == RCCarArena.MODE_HOCKEY then
            local inNetLane = math.abs(object.y - (self.height / 2)) <= HOCKEY_NET_HALF_HEIGHT
            if object.x < -object.size and inNetLane then
                self.leftNetCount = self.leftNetCount + 1
                self:spawnObject(object)
            elseif object.x > self.width + object.size and inNetLane then
                self.rightNetCount = self.rightNetCount + 1
                self:spawnObject(object)
            else
                if object.x < object.size and not inNetLane then
                    object.x = object.size
                    object.vx = math.abs(object.vx) * 0.85
                elseif object.x > self.width - object.size and not inNetLane then
                    object.x = self.width - object.size
                    object.vx = -math.abs(object.vx) * 0.85
                end

                if object.y < 20 + object.size then
                    object.y = 20 + object.size
                    object.vy = math.abs(object.vy) * 0.85
                elseif object.y > self.height - 20 - object.size then
                    object.y = self.height - 20 - object.size
                    object.vy = -math.abs(object.vy) * 0.85
                end
            end
        else
            if object.x < (-object.size * 2)
                or object.x > self.width + (object.size * 2)
                or object.y < (-object.size * 2)
                or object.y > self.height + (object.size * 2) then
                self:respawnObjectForScore(object)
            end
        end
    end
end

function RCCarArena:handleCarObjectCollisions()
    for _, car in ipairs(self.cars) do
        for _, object in ipairs(self.objects) do
            local dx = object.x - car.x
            local dy = object.y - car.y
            local distance = vectorLength(dx, dy)
            local minimumDistance = (CAR_WIDTH * 0.8) + object.size

            if distance < minimumDistance then
                local normalX = distance > 0 and (dx / distance) or math.cos(car.heading)
                local normalY = distance > 0 and (dy / distance) or math.sin(car.heading)
                local impulse = 6 + (vectorLength(car.vx, car.vy) * BLOCK_PUSH_IMPULSE)

                object.vx = object.vx + (normalX * impulse)
                object.vy = object.vy + (normalY * impulse)
                object.lastTouchedBy = car.player and "player" or "opponent"
                car.vx = car.vx - (normalX * impulse * CAR_BUMP_RECOIL)
                car.vy = car.vy - (normalY * impulse * CAR_BUMP_RECOIL)

                local pushOut = minimumDistance - distance
                object.x = object.x + (normalX * pushOut)
                object.y = object.y + (normalY * pushOut)
            end
        end
    end
end

function RCCarArena:handleCarCollisions()
    if #self.cars < 2 then
        return
    end

    for carAIndex = 1, #self.cars - 1 do
        for carBIndex = carAIndex + 1, #self.cars do
            local carA = self.cars[carAIndex]
            local carB = self.cars[carBIndex]
            local dx = carB.x - carA.x
            local dy = carB.y - carA.y
            local distance = vectorLength(dx, dy)
            local minimumDistance = CAR_LENGTH * 0.95

            if distance < minimumDistance and distance > 0 then
                local normalX = dx / distance
                local normalY = dy / distance
                local overlap = (minimumDistance - distance) / 2

                carA.x = carA.x - (normalX * overlap)
                carA.y = carA.y - (normalY * overlap)
                carB.x = carB.x + (normalX * overlap)
                carB.y = carB.y + (normalY * overlap)

                local mixVX = (carA.vx + carB.vx) * 0.5
                local mixVY = (carA.vy + carB.vy) * 0.5
                carA.vx = mixVX - (normalX * 4)
                carA.vy = mixVY - (normalY * 4)
                carB.vx = mixVX + (normalX * 4)
                carB.vy = mixVY + (normalY * 4)
            end
        end
    end
end

function RCCarArena:update()
    self.time = self.time + (1 / 30)
    self:updateCars()
    self:handleCarCollisions()
    self:handleCarObjectCollisions()
    self:updateObjects()
end

function RCCarArena:drawFloor()
    if self.modeId == RCCarArena.MODE_HOCKEY then
        local centerY = self.height / 2
        gfx.drawRoundRect(12, 20, self.width - 24, self.height - 40, 18)
        gfx.drawCircleAtPoint(self.width / 2, centerY, 28)
        gfx.drawLine(self.width / 2, 20, self.width / 2, self.height - 20)
        gfx.drawLine(0, centerY - HOCKEY_NET_HALF_HEIGHT, 12, centerY - HOCKEY_NET_HALF_HEIGHT)
        gfx.drawLine(0, centerY + HOCKEY_NET_HALF_HEIGHT, 12, centerY + HOCKEY_NET_HALF_HEIGHT)
        gfx.drawLine(self.width - 12, centerY - HOCKEY_NET_HALF_HEIGHT, self.width, centerY - HOCKEY_NET_HALF_HEIGHT)
        gfx.drawLine(self.width - 12, centerY + HOCKEY_NET_HALF_HEIGHT, self.width, centerY + HOCKEY_NET_HALF_HEIGHT)
    end
end

function RCCarArena:drawObject(object)
    local scale = 1
    local jumpOffset = 0
    if object.spawnTimer > 0 then
        local progress = 1 - (object.spawnTimer / BLOCK_RESPAWN_FRAMES)
        scale = 0.45 + (progress * 0.55)
        jumpOffset = (1 - progress) * 8
    end

    local size = math.max(3, object.size * scale)
    local x = object.x - (size / 2)
    local y = object.y - (size / 2) - jumpOffset

    if self.modeId == RCCarArena.MODE_HOCKEY then
        gfx.drawCircleAtPoint(object.x, object.y - jumpOffset, size * 0.5)
        gfx.drawCircleAtPoint(object.x, object.y - jumpOffset, math.max(2, size * 0.22))
    else
        gfx.drawRect(x, y, size, size)
        gfx.drawLine(x, y, x + size, y + size)
        gfx.drawLine(x + size, y, x, y + size)
    end
end

function RCCarArena:drawCar(car)
    local heading = car.heading or 0

    local function point(localX, localY)
        local rx, ry = rotateLocalPoint(localX, localY, heading)
        return car.x + rx, car.y + ry
    end

    local frontLeftX, frontLeftY = point(CAR_LENGTH * 0.5, CAR_WIDTH * 0.5)
    local frontRightX, frontRightY = point(CAR_LENGTH * 0.5, -CAR_WIDTH * 0.5)
    local rearLeftX, rearLeftY = point(-CAR_LENGTH * 0.5, CAR_WIDTH * 0.5)
    local rearRightX, rearRightY = point(-CAR_LENGTH * 0.5, -CAR_WIDTH * 0.5)
    local windshieldLeftX, windshieldLeftY = point(CAR_LENGTH * 0.1, CAR_WIDTH * 0.35)
    local windshieldRightX, windshieldRightY = point(CAR_LENGTH * 0.1, -CAR_WIDTH * 0.35)
    local noseX, noseY = point(CAR_LENGTH * 0.72, 0)
    local wheelFrontLeftX, wheelFrontLeftY = point(CAR_LENGTH * 0.22, CAR_WIDTH * 0.7)
    local wheelFrontRightX, wheelFrontRightY = point(CAR_LENGTH * 0.22, -CAR_WIDTH * 0.7)
    local wheelRearLeftX, wheelRearLeftY = point(-CAR_LENGTH * 0.22, CAR_WIDTH * 0.7)
    local wheelRearRightX, wheelRearRightY = point(-CAR_LENGTH * 0.22, -CAR_WIDTH * 0.7)

    gfx.drawLine(frontLeftX, frontLeftY, frontRightX, frontRightY)
    gfx.drawLine(frontRightX, frontRightY, rearRightX, rearRightY)
    gfx.drawLine(rearRightX, rearRightY, rearLeftX, rearLeftY)
    gfx.drawLine(rearLeftX, rearLeftY, frontLeftX, frontLeftY)
    gfx.drawLine(windshieldLeftX, windshieldLeftY, windshieldRightX, windshieldRightY)
    gfx.drawLine(frontLeftX, frontLeftY, noseX, noseY)
    gfx.drawLine(frontRightX, frontRightY, noseX, noseY)
    gfx.drawLine(wheelFrontLeftX, wheelFrontLeftY, wheelRearLeftX, wheelRearLeftY)
    gfx.drawLine(wheelFrontRightX, wheelFrontRightY, wheelRearRightX, wheelRearRightY)
    if car.player then
        gfx.fillCircleAtPoint(car.x, car.y, 2)
    else
        gfx.drawCircleAtPoint(car.x, car.y, 2)
    end
end

function RCCarArena:drawHud()
    if self.preview then
        return
    end

    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawText(RCCarArena.getModeLabel(self.modeId), 10, 8)
    gfx.drawText(string.format("Speed %.1f/%.1f  Crank %s", self.playerTargetSpeed, self.playerMaxSpeed, self.crankMode), 10, 24)

    if self.modeId == RCCarArena.MODE_CHASE then
        gfx.drawText(string.format("Cleared %d", self.playerKnockouts), 10, 40)
    elseif self.modeId == RCCarArena.MODE_VERSUS then
        gfx.drawText(string.format("You %d  Rival %d", self.playerKnockouts, self.opponentKnockouts), 10, 40)
    else
        gfx.drawText(string.format("Left net %d  Right net %d", self.leftNetCount, self.rightNetCount), 10, 40)
    end

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function RCCarArena:draw()
    self:drawFloor()

    for _, object in ipairs(self.objects) do
        self:drawObject(object)
    end

    for _, car in ipairs(self.cars) do
        self:drawCar(car)
    end

    self:drawHud()
end
