--[[
Generic single-view gameplay scene.

Purpose:
- hosts the shared effect-driven views such as Warp Speed, Star Fall, Life, and Lava Lamp
- maps Playdate input into each system's control scheme
- returns active effects back to the title scene for preview handoff when appropriate
]]
local pd <const> = playdate
local FIREWORK_HOLD_REPEAT_FRAMES <const> = 5
local LIFE_CRANK_RELEASE_ANGLE_TOLERANCE <const> = 3

ViewScene = {}
ViewScene.__index = ViewScene

local function sign(value)
    if value < 0 then
        return -1
    elseif value > 0 then
        return 1
    end
    return 0
end

function ViewScene.new(config)
    local self = setmetatable({}, ViewScene)
    self.viewId = config.viewId or "warp"
    self.modeId = config.modeId
    self.onReturnToTitle = config.onReturnToTitle
    self.crankAccumulator = 0
    self.rotationAccumulator = 0
    self.crankMode = "speed"
    self.rotateVelocity = 0
    self.lifeScrubResumeDelay = 30
    self.lifeScrubIdleFrames = self.lifeScrubResumeDelay
    self.fireworkHoldFrames = 0

    if config.effect then
        self.effect = config.effect
    elseif self.viewId == "fall" then
        self.effect = Starfield.newStarFall(400, 240, 420, {
            modeId = self.modeId
        })
    elseif self.viewId == "life" then
        self.effect = GameOfLife.new(400, 240, 5, 0.28, {
            modeId = self.modeId
        })
    elseif self.viewId == "fireworks" then
        self.effect = FireworksShow.new(400, 240)
    elseif self.viewId == "gifplayer" then
        self.effect = GifPlayerEffect.new(400, 240, {
            modeId = self.modeId
        })
    elseif self.viewId == "antfarm" then
        self.effect = AntFarm.new(400, 240)
    elseif self.viewId == "fishpond" then
        self.effect = FishPond.new(400, 240, self.modeId or FishPond.MODE_POND)
    elseif self.viewId == "rccar" then
        self.effect = RCCarArena.new(400, 240, self.modeId or RCCarArena.MODE_CHASE, {
            playerCount = config.session and config.session.playerCount or 2
        })
    elseif self.viewId == "lava" then
        self.effect = LavaLamp.new(400, 240, 60, {
            modeId = self.modeId
        })
    else
        self.effect = Starfield.newWarpSpeed(400, 240, 360, {
            modeId = self.modeId
        })
    end

    if self.effect and self.effect.setPreview then
        self.effect:setPreview(false)
    end

    StarryLog.info(
        "view initialized: mode=%s speed=%.2f direction=%.2f screen=%.2f crankMode=%s",
        self.viewId,
        self.effect.speed or 0,
        self.effect.directionAngle or 0,
        self.effect.screenAngle or 0,
        self.crankMode
    )

    return self
end

function ViewScene:isLifeScrubbing()
    return self.viewId == "life" and self.lifeScrubIdleFrames < self.lifeScrubResumeDelay
end

function ViewScene:isLifeReviewMode()
    return self.viewId == "life"
        and self.effect ~= nil
        and self.effect.isReviewMode ~= nil
        and self.effect:isReviewMode()
end

function ViewScene:usesPersistentSpinControl()
    return self.viewId == "warp" or self.viewId == "fall"
end

function ViewScene:applySpeedStep(direction)
    self.effect:stepSpeed(direction)
end

function ViewScene:updateSpeedFromCrank(acceleratedChange)
    if acceleratedChange == 0 then
        return
    end

    self.crankAccumulator = self.crankAccumulator + acceleratedChange

    while math.abs(self.crankAccumulator) >= 18 do
        local direction = sign(self.crankAccumulator)
        self:applySpeedStep(direction)
        self.crankAccumulator = self.crankAccumulator - (18 * direction)
    end
end

function ViewScene:stepRotateVelocity(direction)
    if direction == 0 then
        return
    end

    if self.viewId == "warp" then
        if self.rotateVelocity > 1 then
            self.rotateVelocity = self.rotateVelocity + (direction * 0.5)
        elseif self.rotateVelocity < -1 then
            self.rotateVelocity = self.rotateVelocity + (direction * 0.5)
        else
            self.rotateVelocity = self.rotateVelocity + (direction * 0.1)
        end
    elseif self.rotateVelocity > 1 then
        self.rotateVelocity = math.min(8, self.rotateVelocity + (direction * 0.5))
    elseif self.rotateVelocity < -1 then
        self.rotateVelocity = math.max(-8, self.rotateVelocity + (direction * 0.5))
    else
        self.rotateVelocity = math.max(-8, math.min(8, self.rotateVelocity + (direction * 0.1)))
    end
end

function ViewScene:updateRotationVelocityFromCrank(acceleratedChange)
    if acceleratedChange == 0 then
        return
    end

    self.rotationAccumulator = self.rotationAccumulator + acceleratedChange

    while math.abs(self.rotationAccumulator) >= 18 do
        local direction = sign(self.rotationAccumulator)
        self:stepRotateVelocity(direction)
        self.rotationAccumulator = self.rotationAccumulator - (18 * direction)
    end
end

function ViewScene:updateLifeCrank(acceleratedChange)
    local magnitude = math.abs(acceleratedChange)

    if magnitude > 0.01 then
        self.lifeScrubIdleFrames = 0

        local steps = math.max(1, math.floor((magnitude / 10) + 0.5))
        if acceleratedChange > 0 then
            self.effect:stepGenerations(steps)
        else
            self.effect:rewindGenerations(steps)
        end

        return
    end

    local crankPosition = pd.getCrankPosition and pd.getCrankPosition() or nil
    local crankDocked = pd.isCrankDocked and pd.isCrankDocked() or false
    if crankDocked
        or (crankPosition ~= nil and (
            crankPosition <= LIFE_CRANK_RELEASE_ANGLE_TOLERANCE
            or crankPosition >= (360 - LIFE_CRANK_RELEASE_ANGLE_TOLERANCE)
            or math.abs(crankPosition - 180) <= LIFE_CRANK_RELEASE_ANGLE_TOLERANCE
        )) then
        self.lifeScrubIdleFrames = self.lifeScrubResumeDelay
        return
    end

    if self.lifeScrubIdleFrames < self.lifeScrubResumeDelay then
        self.lifeScrubIdleFrames = self.lifeScrubIdleFrames + 1
    end
end

function ViewScene:updateStarfieldDirection()
    local inputX = 0
    local inputY = 0

    if pd.buttonIsPressed(pd.kButtonUp) then
        inputY = inputY - 1
    end
    if pd.buttonIsPressed(pd.kButtonDown) then
        inputY = inputY + 1
    end
    if pd.buttonIsPressed(pd.kButtonLeft) then
        inputX = inputX - 1
    end
    if pd.buttonIsPressed(pd.kButtonRight) then
        inputX = inputX + 1
    end

    if inputX == 0 and inputY == 0 then
        return
    end

    local steerStep = math.min(12, math.max(2.5, 2.5 + (math.abs(self.effect.speed or 0) * 1.5)))
    self.effect:steerDirectionToward(inputX, inputY, steerStep)
end

function ViewScene:updatePersistentSpin()
    if self:usesPersistentSpinControl() and self.rotateVelocity ~= 0 then
        self.effect:rotateField(self.rotateVelocity)
    end
end

function ViewScene:update()
    if pd.buttonJustPressed(pd.kButtonB) then
        if self:isLifeReviewMode() and self.effect:handleReviewBack() then
            return
        end
        if self.viewId == "gifplayer" and self.effect and self.effect.handleBack and self.effect:handleBack() then
            return
        end
        if self.onReturnToTitle then
            local effect = self.effect
            if self.viewId == "warp" and effect and effect.kind == "warp" then
                effect.speed = 9
            end
            self.effect = nil
            self.onReturnToTitle(self.viewId, effect)
        end
        return
    end

    local change, acceleratedChange = pd.getCrankChange()

    if pd.buttonJustPressed(pd.kButtonA) then
        if self.viewId == "life" then
            if self:isLifeReviewMode() then
                self.effect:handleReviewPrimaryAction()
            else
                self.effect:spawnInteractiveCells(48)
                StarryLog.info("life repopulated via A button")
            end
        elseif self.viewId == "fireworks" then
            self.effect:launchFromLauncher()
        elseif self.viewId == "gifplayer" then
            self.effect:handlePrimaryAction()
        elseif self.viewId == "antfarm" then
            self.effect:dropAnt()
        elseif self.viewId == "fishpond" then
        elseif self.viewId == "rccar" then
            if self.effect and self.effect.toggleCrankMode then
                self.effect:toggleCrankMode()
            end
        elseif self.viewId == "lava" then
        elseif self:usesPersistentSpinControl() then
            self.crankMode = self.crankMode == "speed" and "spin" or "speed"
            self.crankAccumulator = 0
            self.rotationAccumulator = 0
            StarryLog.info("crank mode changed: %s", self.crankMode)
        end
    end

    if self.viewId == "fireworks" then
        if math.abs(change) > 0.01 then
            self.effect:moveLauncher(change)
        end
        if pd.buttonIsPressed(pd.kButtonA) then
            if pd.buttonJustPressed(pd.kButtonA) then
                self.fireworkHoldFrames = 0
            else
                self.fireworkHoldFrames = self.fireworkHoldFrames + 1
                if self.fireworkHoldFrames >= FIREWORK_HOLD_REPEAT_FRAMES then
                    self.effect:launchFromLauncher()
                    self.fireworkHoldFrames = 0
                end
            end
        else
            self.fireworkHoldFrames = 0
        end
    elseif self.viewId == "antfarm" then
        self.effect:moveHandByCrank(change)
        self.crankAccumulator = 0
    elseif self.viewId == "gifplayer" then
        self.effect:applyCrank(change, acceleratedChange)
        self.crankAccumulator = 0
    elseif self.viewId == "fishpond" then
        if self.effect.modeId == FishPond.MODE_TANK then
            self.effect:adjustTankCurrent(change)
        elseif math.abs(change) > 0.01 then
            self.effect:moveBubbleMaker(change)
        end
        self.crankAccumulator = 0
    elseif self.viewId == "rccar" then
        self.effect:applyCrankInput(change)
    elseif self.viewId == "life" then
        if self:isLifeReviewMode() then
            self.effect:handleReviewCrank(acceleratedChange)
        else
            self:updateLifeCrank(acceleratedChange)
        end
    elseif self.viewId == "lava" then
        if self.effect and self.effect.applyCrank then
            self.effect:applyCrank(change)
        end
        self.crankAccumulator = 0
    elseif self:usesPersistentSpinControl() then
        if self.crankMode == "spin" then
            self:updateRotationVelocityFromCrank(acceleratedChange)
        else
            self:updateSpeedFromCrank(acceleratedChange)
        end
        self:updatePersistentSpin()
    else
        self:updateSpeedFromCrank(acceleratedChange)
    end

    if self.viewId == "fireworks" then
        if pd.buttonIsPressed(pd.kButtonLeft) then
            self.effect:moveLauncher(-2.5)
        end
        if pd.buttonIsPressed(pd.kButtonRight) then
            self.effect:moveLauncher(2.5)
        end
        if pd.buttonJustPressed(pd.kButtonUp) then
            self.effect:stepSelectedStyle(-1)
        elseif pd.buttonJustPressed(pd.kButtonDown) then
            self.effect:stepSelectedStyle(1)
        end
    elseif self.viewId == "antfarm" then
        local inputX = 0
        local inputY = 0
        if pd.buttonIsPressed(pd.kButtonLeft) then
            inputX = inputX - 1
        end
        if pd.buttonIsPressed(pd.kButtonRight) then
            inputX = inputX + 1
        end
        if pd.buttonIsPressed(pd.kButtonUp) then
            inputY = inputY - 1
        end
        if pd.buttonIsPressed(pd.kButtonDown) then
            inputY = inputY + 1
        end
        self.effect:setHandInput(inputX, inputY)
    elseif self.viewId == "gifplayer" then
        self.effect:updateDirectionalInput(
            pd.buttonJustPressed(pd.kButtonUp),
            pd.buttonJustPressed(pd.kButtonDown),
            pd.buttonJustPressed(pd.kButtonLeft),
            pd.buttonJustPressed(pd.kButtonRight)
        )
    elseif self.viewId == "fishpond" then
        local inputX = 0
        local inputY = 0
        self.effect:updateActionInput(pd.buttonJustPressed(pd.kButtonA), pd.buttonIsPressed(pd.kButtonA))
        if self.effect.modeId ~= FishPond.MODE_TANK then
            if pd.buttonIsPressed(pd.kButtonUp) then
                inputY = inputY - 1
            end
            if pd.buttonIsPressed(pd.kButtonDown) then
                inputY = inputY + 1
            end
            if pd.buttonIsPressed(pd.kButtonLeft) then
                inputX = inputX - 1
            end
            if pd.buttonIsPressed(pd.kButtonRight) then
                inputX = inputX + 1
            end
        end
        self.effect:setPlayerInput(inputX, inputY)
    elseif self.viewId == "rccar" then
        self.effect:updatePlayerInput(
            pd.buttonIsPressed(pd.kButtonLeft),
            pd.buttonIsPressed(pd.kButtonRight),
            pd.buttonIsPressed(pd.kButtonUp),
            pd.buttonIsPressed(pd.kButtonDown)
        )
    elseif self.viewId == "life" then
        if self:isLifeReviewMode() then
            self.effect:handleReviewMenuInput(
                pd.buttonJustPressed(pd.kButtonUp),
                pd.buttonJustPressed(pd.kButtonDown),
                pd.buttonJustPressed(pd.kButtonLeft),
                pd.buttonJustPressed(pd.kButtonRight)
            )
        else
            if pd.buttonJustPressed(pd.kButtonUp) then
                self:applySpeedStep(1)
            elseif pd.buttonJustPressed(pd.kButtonDown) then
                self:applySpeedStep(-1)
            end

            if pd.buttonJustPressed(pd.kButtonLeft) or pd.buttonJustPressed(pd.kButtonRight) then
                self.effect:spawnInteractiveCells(12)
            end
        end
    elseif self.viewId == "lava" then
        if pd.buttonJustPressed(pd.kButtonUp) then
            self:applySpeedStep(1)
        elseif pd.buttonJustPressed(pd.kButtonDown) then
            self:applySpeedStep(-1)
        end
    elseif self.viewId == "gifplayer" then
    elseif self.viewId ~= "lava" then
        if self.effect and self.effect.steerDirectionToward then
            self:updateStarfieldDirection()
        else
            local moveAmount = math.max(1, math.abs(self.effect.speed))
            if pd.buttonIsPressed(pd.kButtonUp) then
                self.effect:movePerspective(0, -moveAmount)
            end
            if pd.buttonIsPressed(pd.kButtonDown) then
                self.effect:movePerspective(0, moveAmount)
            end
            if pd.buttonIsPressed(pd.kButtonLeft) then
                self.effect:movePerspective(-moveAmount, 0)
            end
            if pd.buttonIsPressed(pd.kButtonRight) then
                self.effect:movePerspective(moveAmount, 0)
            end
        end
    end

    if self:isLifeReviewMode() then
        self.effect:update()
    elseif self.viewId == "life" and self:isLifeScrubbing() then
        if self.effect and self.effect.updateBackground then
            self.effect:updateBackground()
        end
    elseif not self:isLifeScrubbing() then
        self.effect:update()
    end
    self.effect:draw()
end

function ViewScene:activate()
    if self.effect and self.effect.activate then
        self.effect:activate()
    end
end

function ViewScene:shutdown()
    if self.effect and self.effect.shutdown then
        self.effect:shutdown()
    end
end
