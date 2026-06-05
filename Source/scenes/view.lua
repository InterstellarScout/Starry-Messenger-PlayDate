import "gameconfig"

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
local TILTBALLS_ENTRY_OVERLAY_FRAMES <const> = 30 * 5
local TILTBALLS_ENTRY_LINE_ONE <const> = "Turn the Play Date upside down"
local TILTBALLS_ENTRY_LINE_TWO <const> = "and watch the ball fall to your feet!"
local WARP_MENU_X <const> = 218
local WARP_MENU_Y <const> = 10
local WARP_MENU_WIDTH <const> = 172
local WARP_MENU_ROW_HEIGHT <const> = 20
local WARP_STATUS_X <const> = 10
local WARP_STATUS_Y <const> = 10
local WARP_CONFIG <const> = GameConfig and GameConfig.warp or {}
local STAR_FALL_CONFIG <const> = GameConfig and GameConfig.starFall or {}
local LIFE_CONFIG <const> = GameConfig and GameConfig.life or {}
local LAVA_CONFIG <const> = GameConfig and GameConfig.lavaLamp or {}

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
    self.returnViewId = config.returnViewId or self.viewId
    self.onReturnToTitle = config.onReturnToTitle
    self.crankAccumulator = 0
    self.rotationAccumulator = 0
    self.crankMode = "speed"
    self.rotateVelocity = 0
    self.lifeScrubResumeDelay = 30
    self.lifeScrubIdleFrames = self.lifeScrubResumeDelay
    self.fireworkHoldFrames = 0
    self.warpMenuOpen = false
    self.warpMenuIndex = 1
    self.starryTunnelDirectionLocked = false
    self.entryOverlayFrames = 0

    if config.effect then
        self.effect = config.effect
    elseif self.viewId == "fall" then
        self.effect = Starfield.newStarFall(400, 240, STAR_FALL_CONFIG.liveStarCount or 420, {
            modeId = self.modeId
        })
    elseif self.viewId == "life" then
        self.effect = GameOfLife.new(400, 240, LIFE_CONFIG.liveCellSize or 5, LIFE_CONFIG.liveSeedChance or 0.28, {
            modeId = self.modeId
        })
    elseif self.viewId == "fireworks" then
        self.effect = FireworksShow.new(400, 240)
    elseif self.viewId == "crttv" then
        self.effect = CRTTVEffect.new(400, 240)
    elseif self.viewId == "vibes" then
        self.effect = VibesEffect.new(400, 240, {
            modeId = self.modeId,
            selectionLocked = self.modeId ~= nil
        })
    elseif self.viewId == "puddledrops" then
        self.effect = PuddleDrops.new(400, 240, {
            modeId = self.modeId
        })
    elseif self.viewId == "dropper" then
        self.effect = Dropper.new(400, 240, {
            preview = false
        })
    elseif self.viewId == "tiltballs" then
        self.effect = TiltBalls.new(400, 240)
    elseif self.viewId == "wacky" then
        self.effect = WackyInflatable.new(400, 240)
    elseif self.viewId == "dimensionalsplit" then
        self.effect = DimensionalSplit.new(400, 240, {
            preview = false
        })
    elseif self.viewId == "spaceminer" then
        self.effect = SpaceMiner.new(400, 240, {
            modeId = self.modeId
        })
    elseif self.viewId == "trailblazer" then
        self.effect = TrailBlazer.new(400, 240, {
            modeId = self.modeId
        })
    elseif self.viewId == "marblemadness" then
        self.effect = MarbleMadness.new(400, 240)
    elseif self.viewId == "snake" then
        self.effect = SnakeGame.new(400, 240)
    elseif self.viewId == "smokebloom" then
        self.effect = SmokeBloom.new(400, 240)
    elseif self.viewId == "photoviewer" then
        self.effect = PhotoViewerEffect.new(400, 240)
    elseif self.viewId == "gifplayer" then
        self.effect = GifPlayerEffect.new(400, 240, {
            modeId = self.modeId
        })
    elseif self.viewId == "fishpond" then
        self.effect = FishPond.new(400, 240, self.modeId or FishPond.MODE_POND)
    elseif self.viewId == "rccar" then
        self.effect = RCCarArena.new(400, 240, self.modeId or RCCarArena.MODE_CHASE, {
            playerCount = config.session and config.session.playerCount or 2
        })
    elseif self.viewId == "lava" then
        self.effect = LavaLamp.new(400, 240, LAVA_CONFIG.liveBubbleCount or 60, {
            modeId = self.modeId
        })
    else
        self.effect = Starfield.newWarpSpeed(400, 240, WARP_CONFIG.liveStarCount or 180, {
            modeId = self.modeId
        })
    end

    if self.effect and self.effect.setPreview then
        self.effect:setPreview(false)
    end

    if self.viewId == "tiltballs" then
        self.entryOverlayFrames = TILTBALLS_ENTRY_OVERLAY_FRAMES
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

function ViewScene:onWillPause()
    if self.viewId == "trailblazer"
        and self.effect
        and self.effect.setPauseHudHidden then
        self.effect:setPauseHudHidden(true)
        local pauseImage = pd.graphics.image.new(400, 240)
        if pauseImage ~= nil then
            pd.graphics.pushContext(pauseImage)
            self.effect:draw()
            pd.graphics.popContext()
            pd.setMenuImage(pauseImage, 0)
        else
            self.effect:draw()
        end
    end
end

function ViewScene:onDidResume()
    if self.viewId == "trailblazer"
        and self.effect
        and self.effect.setPauseHudHidden then
        self.effect:setPauseHudHidden(false)
        pd.setMenuImage(nil)
    end
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

function ViewScene:getWarpMenuItems()
    return {
        {
            id = "spinControl",
            label = "Spin Mode",
            checked = self.crankMode == "spin",
            kind = "toggle"
        },
        {
            id = "persistentSpin",
            label = "Persistent Spin",
            checked = (self.rotateVelocity or 0) ~= 0,
            kind = "toggle"
        },
        {
            id = "stopSpin",
            label = "Stop Spin",
            kind = "button"
        },
        {
            id = "playerSpeed",
            label = "Player Speed",
            value = self.effect and self.effect.speed or 0,
            minValue = WARP_CONFIG.menuSpeedMin or -20,
            maxValue = WARP_CONFIG.menuSpeedMax or 20,
            displayFormat = "%.1f",
            kind = "slider"
        },
        {
            id = "rotationSpeed",
            label = "Rotation Speed",
            value = self.rotateVelocity or 0,
            minValue = WARP_CONFIG.menuRotationMin or -6,
            maxValue = WARP_CONFIG.menuRotationMax or 6,
            displayFormat = "%.2f",
            kind = "slider"
        },
        {
            id = "starSize",
            label = "Star Size",
            value = self.effect and self.effect.getWarpStarSizePercent and self.effect:getWarpStarSizePercent() or 0,
            minValue = WARP_CONFIG.starSizePercentMin or -80,
            maxValue = WARP_CONFIG.starSizePercentMax or 200,
            displayFormat = "%+d%%",
            kind = "slider"
        },
        {
            id = "differentSizes",
            label = "Different Sizes",
            checked = self.effect and self.effect.isWarpStyleEnabled and self.effect:isWarpStyleEnabled("differentSizes"),
            kind = "toggle"
        },
        {
            id = "smoothEngine",
            label = "Smooth Engine",
            checked = self.effect and self.effect.isWarpStyleEnabled and self.effect:isWarpStyleEnabled("smoothEngine"),
            kind = "toggle"
        },
        {
            id = "starryTunnel",
            label = "Starry Tunnel",
            checked = self.effect and self.effect.isWarpStyleEnabled and self.effect:isWarpStyleEnabled("starryTunnel"),
            kind = "toggle"
        }
    }
end

function ViewScene:toggleWarpMenuSelection(direction)
    local items = self:getWarpMenuItems()
    local item = items[self.warpMenuIndex]
    if item == nil then
        return
    end

    if item.kind == "slider" then
        if direction ~= nil and direction ~= 0 then
            if item.id == "playerSpeed" then
                local nextSpeed = (self.effect and self.effect.speed or 0) + (direction * (WARP_CONFIG.menuSpeedStep or 0.5))
                nextSpeed = math.max(item.minValue, math.min(item.maxValue, nextSpeed))
                if self.effect and self.effect.setSpeed then
                    self.effect:setSpeed(nextSpeed)
                elseif self.effect then
                    self.effect.speed = nextSpeed
                end
            elseif item.id == "rotationSpeed" then
                self.rotateVelocity = self.rotateVelocity + (direction * (WARP_CONFIG.menuRotationStep or 0.05))
                self.rotateVelocity = math.max(item.minValue, math.min(item.maxValue, self.rotateVelocity))
                StarryLog.info("warp rotation speed changed: %.2f", self.rotateVelocity)
            elseif self.effect and self.effect.stepWarpStarSizePercent then
                self.effect:stepWarpStarSizePercent(direction)
            end
        end
        return
    end

    if item.id == "spinControl" then
        self.crankMode = self.crankMode == "speed" and "spin" or "speed"
        self.crankAccumulator = 0
        self.rotationAccumulator = 0
        StarryLog.info("crank mode changed: %s", self.crankMode)
        return
    elseif item.id == "persistentSpin" then
        if (self.rotateVelocity or 0) == 0 then
            self.rotateVelocity = 0.35
        else
            self.rotateVelocity = 0
        end
        StarryLog.info("persistent spin changed: %.2f", self.rotateVelocity)
        return
    elseif item.id == "stopSpin" then
        self.rotateVelocity = 0
        StarryLog.info("warp spin stopped")
        return
    end

    if self.effect and self.effect.toggleWarpStyle then
        self.effect:toggleWarpStyle(item.id)
        StarryLog.info("warp test option changed: %s=%s", item.id, tostring(self.effect:isWarpStyleEnabled(item.id)))
    end
end

function ViewScene:updateWarpMenu()
    local items = self:getWarpMenuItems()
    local itemCount = #items

    if pd.buttonJustPressed(pd.kButtonUp) then
        self.warpMenuIndex = self.warpMenuIndex - 1
        if self.warpMenuIndex < 1 then
            self.warpMenuIndex = itemCount
        end
    elseif pd.buttonJustPressed(pd.kButtonDown) then
        self.warpMenuIndex = self.warpMenuIndex + 1
        if self.warpMenuIndex > itemCount then
            self.warpMenuIndex = 1
        end
    end

    local selectedItem = items[self.warpMenuIndex]
    if selectedItem and selectedItem.kind == "slider" then
        if pd.buttonJustPressed(pd.kButtonLeft) then
            self:toggleWarpMenuSelection(-1)
        elseif pd.buttonJustPressed(pd.kButtonRight) then
            self:toggleWarpMenuSelection(1)
        elseif pd.buttonJustPressed(pd.kButtonA) then
            self:toggleWarpMenuSelection(1)
        end
    elseif pd.buttonJustPressed(pd.kButtonLeft) or pd.buttonJustPressed(pd.kButtonRight) or pd.buttonJustPressed(pd.kButtonA) then
        self:toggleWarpMenuSelection(0)
    end
end

function ViewScene:drawWarpMenuStatus()
    local gfx <const> = pd.graphics
    gfx.setColor(gfx.kColorWhite)
    gfx.drawText(string.format("Star Speed %.1f", self.effect and self.effect.speed or 0), WARP_STATUS_X, WARP_STATUS_Y)
    gfx.drawText(string.format("Rotation %.2f", self.rotateVelocity or 0), WARP_STATUS_X, WARP_STATUS_Y + 16)
end

function ViewScene:drawWarpMenuSlider(item, x, y, width, selected)
    local gfx <const> = pd.graphics
    local percent = item.value or 0
    local minValue = item.minValue or -80
    local maxValue = item.maxValue or 200
    local lineY = y + 12
    local lineStartX = x + 86
    local lineEndX = x + width - 22
    local ratio = 0.5

    if maxValue > minValue then
        ratio = (percent - minValue) / (maxValue - minValue)
    end

    ratio = math.max(0, math.min(1, ratio))
    local dotX = math.floor(lineStartX + ((lineEndX - lineStartX) * ratio) + 0.5)
    gfx.drawText(item.label, x, y)
    gfx.drawLine(lineStartX, lineY, lineEndX, lineY)
    if selected then
        gfx.fillCircleAtPoint(dotX, lineY, 3)
    else
        gfx.drawCircleAtPoint(dotX, lineY, 3)
    end
    gfx.drawText(string.format(item.displayFormat or "%d", percent), x + width - 54, y)
end

function ViewScene:drawWarpMenu()
    if not self.warpMenuOpen or self.viewId ~= "warp" then
        return
    end

    local gfx <const> = pd.graphics
    local items = self:getWarpMenuItems()
    local height = 22 + (#items * WARP_MENU_ROW_HEIGHT) + 8

    gfx.setColor(gfx.kColorWhite)
    gfx.setDitherPattern(0.15, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRoundRect(WARP_MENU_X, WARP_MENU_Y, WARP_MENU_WIDTH, height, 8)
    gfx.setDitherPattern(1, gfx.image.kDitherTypeBayer8x8)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(WARP_MENU_X, WARP_MENU_Y, WARP_MENU_WIDTH, height, 8)
    self:drawWarpMenuStatus()
    gfx.drawText("Warp Settings", WARP_MENU_X + 10, WARP_MENU_Y + 6)

    for index, item in ipairs(items) do
        local rowY = WARP_MENU_Y + 24 + ((index - 1) * WARP_MENU_ROW_HEIGHT)
        if index == self.warpMenuIndex then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(WARP_MENU_X + 6, rowY - 1, WARP_MENU_WIDTH - 12, WARP_MENU_ROW_HEIGHT - 2)
            gfx.setColor(gfx.kColorWhite)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
        else
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
        end

        if item.kind == "slider" then
            self:drawWarpMenuSlider(item, WARP_MENU_X + 12, rowY + 2, WARP_MENU_WIDTH - 24, index == self.warpMenuIndex)
        elseif item.kind == "button" then
            gfx.drawText("> " .. item.label, WARP_MENU_X + 12, rowY + 2)
        else
            local marker = item.checked and "[x]" or "[ ]"
            gfx.drawText(marker .. " " .. item.label, WARP_MENU_X + 12, rowY + 2)
        end
    end

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
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
        self.rotateVelocity = self.rotateVelocity + (direction * 0.5)
    elseif self.rotateVelocity < -1 then
        self.rotateVelocity = self.rotateVelocity + (direction * 0.5)
    else
        self.rotateVelocity = self.rotateVelocity + (direction * 0.1)
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

    if self.viewId == "warp"
        and self.effect
        and self.effect.isWarpStyleEnabled
        and self.effect:isWarpStyleEnabled("starryTunnel")
        and self.effect.setStarryTunnelInput then
        if inputX == 0 and inputY == 0 then
            if not self.starryTunnelDirectionLocked then
                self.effect:setStarryTunnelInput(0, 0, false)
            end
        else
            self.effect:setStarryTunnelInput(inputX, inputY, self.starryTunnelDirectionLocked)
        end
        return
    end

    if inputX == 0 and inputY == 0 then
        return
    end

    local steerStep = math.min(12, math.max(2.5, 2.5 + (math.abs(self.effect.speed or 0) * 1.5)))
    self.effect:steerDirectionToward(inputX, inputY, steerStep)
end

function ViewScene:getWarpDpadInput()
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

    return inputX, inputY
end

function ViewScene:tryToggleStarryTunnelDirectionHold()
    if self.viewId ~= "warp"
        or self.effect == nil
        or self.effect.isWarpStyleEnabled == nil
        or not self.effect:isWarpStyleEnabled("starryTunnel")
        or self.effect.setStarryTunnelInput == nil then
        return false
    end

    local inputX, inputY = self:getWarpDpadInput()
    if inputX == 0 and inputY == 0 then
        return false
    end

    self.starryTunnelDirectionLocked = not self.starryTunnelDirectionLocked
    self.effect:setStarryTunnelInput(inputX, inputY, self.starryTunnelDirectionLocked)
    StarryLog.info("starry tunnel direction hold: %s", tostring(self.starryTunnelDirectionLocked))
    return true
end

function ViewScene:updatePersistentSpin()
    if self:usesPersistentSpinControl() and self.rotateVelocity ~= 0 then
        self.effect:rotateField(self.rotateVelocity)
    end
end

function ViewScene:hasEntryOverlay()
    return self.entryOverlayFrames ~= nil and self.entryOverlayFrames > 0
end

function ViewScene:updateEntryOverlay()
    if self:hasEntryOverlay() then
        self.entryOverlayFrames = self.entryOverlayFrames - 1
    end
end

function ViewScene:dismissEntryOverlay()
    self.entryOverlayFrames = 0
end

function ViewScene:drawEntryOverlay()
    if not self:hasEntryOverlay() then
        return
    end

    pd.graphics.setImageDrawMode(pd.graphics.kDrawModeInverted)
    pd.graphics.drawTextAligned(TILTBALLS_ENTRY_LINE_ONE, 200, 104, kTextAlignment.center)
    pd.graphics.drawTextAligned(TILTBALLS_ENTRY_LINE_TWO, 200, 120, kTextAlignment.center)
    pd.graphics.setImageDrawMode(pd.graphics.kDrawModeCopy)
end

function ViewScene:handleTrailblazerIntroInteraction(change, acceleratedChange)
    if self.viewId ~= "trailblazer" or self.effect == nil or self.effect.handleFirstInteraction == nil then
        return
    end

    if math.abs(change or 0) > 0.01
        or math.abs(acceleratedChange or 0) > 0.01
        or pd.buttonJustPressed(pd.kButtonA)
        or pd.buttonJustPressed(pd.kButtonLeft)
        or pd.buttonJustPressed(pd.kButtonRight)
        or pd.buttonJustPressed(pd.kButtonUp)
        or pd.buttonJustPressed(pd.kButtonDown) then
        self.effect:handleFirstInteraction()
    end
end

function ViewScene:update()
    local aJustPressed = pd.buttonJustPressed(pd.kButtonA)
    local change, acceleratedChange = pd.getCrankChange()

    self:handleTrailblazerIntroInteraction(change, acceleratedChange)

    if pd.buttonJustPressed(pd.kButtonB) then
        if self.warpMenuOpen then
            self.warpMenuOpen = false
            return
        end
        if self.viewId == "trailblazer" and self.effect and self.effect.isMenuOpen and self.effect:isMenuOpen() then
            self.effect:closeMenu()
            return
        end
        if self:isLifeReviewMode() and self.effect:handleReviewBack() then
            return
        end
        if self.viewId == "gifplayer" and self.effect and self.effect.handleBack and self.effect:handleBack() then
            return
        end
        if self.onReturnToTitle then
            local effect = self.effect
            local returnViewId = self.returnViewId or self.viewId
            if self.viewId == "vibes" and effect ~= nil and effect.modeId ~= nil then
                returnViewId = "vibes_" .. tostring(effect.modeId)
            end
            self.effect = nil
            self.onReturnToTitle(returnViewId, effect)
        end
        return
    end

    if self.viewId == "tiltballs" and self:hasEntryOverlay() then
        if aJustPressed then
            self:dismissEntryOverlay()
        else
            self:updateEntryOverlay()
        end
    end

    if self.viewId == "warp" and aJustPressed then
        if self:tryToggleStarryTunnelDirectionHold() then
        elseif self.warpMenuOpen then
            self:toggleWarpMenuSelection()
        else
            self.warpMenuOpen = true
        end
        self:updatePersistentSpin()
        self.effect:update()
        self.effect:draw()
        self:drawWarpMenu()
        self:drawEntryOverlay()
        return
    elseif aJustPressed and not (self.viewId == "tiltballs" and self:hasEntryOverlay()) then
        if self.viewId == "life" then
            if self:isLifeReviewMode() then
                self.effect:handleReviewPrimaryAction()
            else
                self.effect:spawnInteractiveCells(48)
                StarryLog.info("life repopulated via A button")
            end
        elseif self.viewId == "fireworks" then
            self.effect:launchFromLauncher()
        elseif self.viewId == "crttv" then
            self.effect:handlePrimaryAction()
        elseif self.viewId == "vibes" then
            self.effect:handlePrimaryAction()
        elseif self.viewId == "puddledrops" then
            self.effect:handlePrimaryAction()
        elseif self.viewId == "dropper" then
            self.effect:handlePrimaryAction()
        elseif self.viewId == "tiltballs" then
            self.effect:handlePrimaryAction()
        elseif self.viewId == "dimensionalsplit" then
            self.effect:handlePrimaryAction()
        elseif self.viewId == "gifplayer" then
            self.effect:handlePrimaryAction()
        elseif self.viewId == "photoviewer" then
            self.effect:handlePrimaryAction()
        elseif self.viewId == "wacky" then
            self.effect:handlePrimaryAction()
        elseif self.viewId == "spaceminer" then
        elseif self.viewId == "fishpond" then
        elseif self.viewId == "trailblazer" then
            self.effect:handlePrimaryAction()
        elseif self.viewId == "marblemadness" then
        elseif self.viewId == "snake" then
            self.effect:handlePrimaryAction()
        elseif self.viewId == "smokebloom" then
            self.effect:handlePrimaryAction()
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

    if self.warpMenuOpen then
        self:updateWarpMenu()
        self:updatePersistentSpin()
        self.effect:update()
        self.effect:draw()
        self:drawWarpMenu()
        self:drawEntryOverlay()
        return
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
    elseif self.viewId == "crttv" then
        self.effect:applyCrank(change, acceleratedChange)
        self.crankAccumulator = 0
    elseif self.viewId == "tiltballs" then
        self.effect:applyCrank(change)
        self.crankAccumulator = 0
    elseif self.viewId == "wacky" then
        self.effect:applyCrank(change, acceleratedChange)
        self.crankAccumulator = 0
    elseif self.viewId == "dimensionalsplit" then
        self.effect:applyCrank(change)
        self.crankAccumulator = 0
    elseif self.viewId == "spaceminer" then
        self.effect:applyCrank(change)
        self.crankAccumulator = 0
    elseif self.viewId == "gifplayer" then
        self.effect:applyCrank(change, acceleratedChange)
        self.crankAccumulator = 0
    elseif self.viewId == "trailblazer" then
        self.effect:applyCrank(change, acceleratedChange)
        self.crankAccumulator = 0
    elseif self.viewId == "marblemadness" then
        self.effect:applyCrank(change)
        self.crankAccumulator = 0
    elseif self.viewId == "snake" then
        self.effect:applyCrank(change)
        self.crankAccumulator = 0
    elseif self.viewId == "smokebloom" then
        self.effect:applyCrank(change)
        self.crankAccumulator = 0
    elseif self.viewId == "photoviewer" then
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
    elseif self.viewId == "vibes" and self.effect and self.effect.usesDirectCrank and self.effect:usesDirectCrank() then
        self.effect:applyCrank(change, acceleratedChange)
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
    elseif self.viewId == "gifplayer" then
        self.effect:updateDirectionalInput(
            pd.buttonJustPressed(pd.kButtonUp),
            pd.buttonJustPressed(pd.kButtonDown),
            pd.buttonJustPressed(pd.kButtonLeft),
            pd.buttonJustPressed(pd.kButtonRight)
        )
    elseif self.viewId == "vibes" then
        if self.effect and self.effect.handleDirectionalInput then
            local useHeldInput = self.effect.usesHeldDirectionalInput and self.effect:usesHeldDirectionalInput()
            self.effect:handleDirectionalInput(
                useHeldInput and pd.buttonIsPressed(pd.kButtonLeft) or pd.buttonJustPressed(pd.kButtonLeft),
                useHeldInput and pd.buttonIsPressed(pd.kButtonRight) or pd.buttonJustPressed(pd.kButtonRight),
                pd.buttonIsPressed(pd.kButtonUp),
                pd.buttonIsPressed(pd.kButtonDown)
            )
        end
    elseif self.viewId == "puddledrops" then
        if self.effect and self.effect.handleDirectionalInput then
            self.effect:handleDirectionalInput(
                pd.buttonIsPressed(pd.kButtonLeft),
                pd.buttonIsPressed(pd.kButtonRight),
                pd.buttonIsPressed(pd.kButtonUp),
                pd.buttonIsPressed(pd.kButtonDown)
            )
        end
    elseif self.viewId == "dropper" then
        if self.effect and self.effect.handleDirectionalInput then
            self.effect:handleDirectionalInput(
                pd.buttonIsPressed(pd.kButtonLeft),
                pd.buttonIsPressed(pd.kButtonRight),
                pd.buttonIsPressed(pd.kButtonUp),
                pd.buttonIsPressed(pd.kButtonDown)
            )
        end
    elseif self.viewId == "photoviewer" then
        if pd.buttonJustPressed(pd.kButtonLeft) then
            self.effect:stepPhoto(-1)
        elseif pd.buttonJustPressed(pd.kButtonRight) then
            self.effect:stepPhoto(1)
        end
        if pd.buttonJustPressed(pd.kButtonUp) then
            self.effect:handleUp()
        elseif pd.buttonJustPressed(pd.kButtonDown) then
            self.effect:handleDown()
        end
    elseif self.viewId == "trailblazer" then
        if self.effect.isMenuOpen and self.effect:isMenuOpen() then
            self.effect:updateMenuInput(
                pd.buttonJustPressed(pd.kButtonUp),
                pd.buttonJustPressed(pd.kButtonDown),
                pd.buttonJustPressed(pd.kButtonLeft),
                pd.buttonJustPressed(pd.kButtonRight),
                pd.buttonJustPressed(pd.kButtonA)
            )
        else
            self.effect:updateDriveInput(
                pd.buttonIsPressed(pd.kButtonUp),
                pd.buttonIsPressed(pd.kButtonDown),
                pd.buttonIsPressed(pd.kButtonRight)
            )
            if pd.buttonJustPressed(pd.kButtonLeft) then
                self.effect:handleDrop()
            end
        end
    elseif self.viewId == "marblemadness" then
        self.effect:handleDirectionalInput(
            pd.buttonIsPressed(pd.kButtonLeft),
            pd.buttonIsPressed(pd.kButtonRight),
            pd.buttonIsPressed(pd.kButtonUp),
            pd.buttonIsPressed(pd.kButtonDown)
        )
        self.effect:updateActionInput(pd.buttonIsPressed(pd.kButtonA))
    elseif self.viewId == "snake" then
        self.effect:handleDirectionalInput(
            false,
            false,
            pd.buttonJustPressed(pd.kButtonUp),
            pd.buttonJustPressed(pd.kButtonDown)
        )
    elseif self.viewId == "smokebloom" then
        self.effect:handleDirectionalInput(
            pd.buttonIsPressed(pd.kButtonLeft),
            pd.buttonIsPressed(pd.kButtonRight),
            pd.buttonIsPressed(pd.kButtonUp),
            pd.buttonIsPressed(pd.kButtonDown)
        )
    elseif self.viewId == "spaceminer" then
        self.effect:updateInput(
            pd.buttonIsPressed(pd.kButtonUp),
            pd.buttonIsPressed(pd.kButtonDown),
            pd.buttonIsPressed(pd.kButtonLeft),
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
    elseif self.viewId == "gifplayer" or self.viewId == "crttv" or self.viewId == "vibes" or self.viewId == "tiltballs" or self.viewId == "wacky" or self.viewId == "dimensionalsplit" or self.viewId == "dropper" or self.viewId == "spaceminer" then
    elseif self.viewId ~= "lava" then
        if self.effect and self.effect.steerDirectionToward then
            self:updateStarfieldDirection()
        elseif self.effect and self.effect.movePerspective then
            local moveAmount = math.max(1, math.abs(self.effect.speed or 0))
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
    self:drawWarpMenu()
    self:drawEntryOverlay()
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
