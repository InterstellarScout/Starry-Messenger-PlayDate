--[[
Starry Messenger application entry point.

Purpose:
- boots shared systems and scene routing
- defines the single-player and multiplayer title catalogs
- owns scene transitions, system menu actions, and fatal-error rendering
]]
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "systems/log"
import "systems/starfield"
import "systems/gameoflife"
import "systems/lavalamp"
import "systems/fireworks"
import "systems/fishpond"
import "systems/gifplayer"
import "systems/crttv"
import "systems/wacky"
import "systems/spaceminer"
import "systems/rccararena"
import "systems/tiltballs"
import "systems/controlhelp"
import "systems/sessionstate"
import "systems/starryportal"
import "systems/viewaudio"
import "scenes/splash"
import "scenes/title"
import "scenes/view"
import "scenes/duckgame"
import "scenes/orbitaldefense"

local pd <const> = playdate
local gfx <const> = pd.graphics

local app = {
    fatalError = nil,
    fatalContext = nil,
    session = SessionState.new(),
    portalService = StarryPortalService.new()
}
local buildGameTitleScene
local buildSplashScene

local function getBeingCountLabel(playerCount)
    local count = math.max(2, math.floor(playerCount or 2))
    if count == 2 then
        return "Two Beings"
    elseif count == 3 then
        return "Three Beings"
    end
    return "Four Beings"
end

local SINGLE_VIEW_ITEMS <const> = {
    {
        id = "fall",
        label = "Star Fall",
        modes = {
            Starfield.MODE_STANDARD,
            Starfield.MODE_INVERSE
        },
        modeId = Starfield.MODE_STANDARD,
        getModeLabel = function(modeId)
            return Starfield.getModeLabel(modeId, "fall")
        end
    },
    {
        id = "warp",
        label = "Warp Speed",
        modes = {
            Starfield.MODE_STANDARD,
            Starfield.MODE_INVERSE
        },
        modeId = Starfield.MODE_STANDARD,
        getModeLabel = function(modeId)
            return Starfield.getModeLabel(modeId, "warp")
        end
    },
    {
        id = "multiplayer",
        label = "Multiplayer",
        modes = { 2, 3, 4 },
        modeId = 2,
        getModeLabel = getBeingCountLabel
    },
    {
        id = "life",
        label = "Game of Life",
        modes = {
            GameOfLife.MODE_STANDARD,
            GameOfLife.MODE_ENDLESS,
            GameOfLife.MODE_RECORD,
            GameOfLife.MODE_REVIEW
        },
        modeId = GameOfLife.MODE_STANDARD,
        getModeLabel = GameOfLife.getModeLabel
    },
    { id = "fireworks", label = "Fireworks" },
    { id = "crttv", label = "CRT TV" },
    { id = "tiltballs", label = "Bouncy Balls" },
    { id = "wacky", label = "Wacky" },
    {
        id = "spaceminer",
        label = "Space Miner"
    },
    { id = "gifplayer", label = "Gif Player" },
    {
        id = "fishpond",
        label = "Fishy Pond",
        modes = {
            FishPond.MODE_POND,
            FishPond.MODE_BUBBLES,
            FishPond.MODE_TANK
        },
        modeId = FishPond.MODE_POND,
        getModeLabel = FishPond.getModeLabel
    },
    {
        id = "duck",
        label = "Duck Game",
        modes = {
            DuckGameScene.MODE_SOLO_CENTER,
            DuckGameScene.MODE_SOLO_2,
            DuckGameScene.MODE_SOLO_3,
            DuckGameScene.MODE_SOLO_4
        },
        modeId = DuckGameScene.MODE_SOLO_CENTER,
        getModeLabel = DuckGameScene.getModeLabel
    },
    { id = "orbital", label = "Orbital Defense" },
    {
        id = "rccar",
        label = "RC Arena",
        modes = {
            RCCarArena.MODE_CHASE,
            RCCarArena.MODE_VERSUS,
            RCCarArena.MODE_HOCKEY
        },
        modeId = RCCarArena.MODE_CHASE,
        getModeLabel = RCCarArena.getModeLabel
    },
    {
        id = "lava",
        label = "Lava Lamp",
        modes = {
            LavaLamp.MODE_STANDARD,
            LavaLamp.MODE_INVERSE
        },
        modeId = LavaLamp.MODE_STANDARD,
        getModeLabel = LavaLamp.getModeLabel
    }
}

local function getRCCarMultiplayerModeLabel(modeId)
    if modeId == RCCarArena.MODE_HOCKEY then
        return "RC Hockey"
    end
    return "Crash Racing"
end

local MULTIPLAYER_VIEW_ITEMS <const> = {
    { id = "duck", label = "Multiplayer Duck Game" },
    { id = "orbital", label = "Multiplayer Orbital Defense" },
    {
        id = "rccar_multi",
        label = "Crash Racing",
        modes = {
            RCCarArena.MODE_VERSUS,
            RCCarArena.MODE_HOCKEY
        },
        modeId = RCCarArena.MODE_VERSUS,
        getModeLabel = getRCCarMultiplayerModeLabel
    }
}

local function getCatalogViewItems(catalog)
    if catalog == "multi" then
        return MULTIPLAYER_VIEW_ITEMS
    end
    return SINGLE_VIEW_ITEMS
end

local function getViewIndex(viewItems, viewId)
    for index, item in ipairs(viewItems) do
        if item.id == viewId then
            return index
        end
    end

    return 1
end

local function setScene(scene)
    StarryLog.info("setScene %s -> %s", tostring(app.scene), tostring(scene))
    if app.scene and app.scene.shutdown then
        app.scene:shutdown()
    end

    app.scene = scene

    if app.scene and app.scene.activate then
        app.scene:activate()
    end
end

local function recordFatalError(context, err)
    app.fatalContext = context
    app.fatalError = tostring(err)
    StarryLog.error("fatal error in %s: %s", context, app.fatalError)
end

local function safeCall(context, callback)
    local ok, result = pcall(callback)
    if not ok then
        recordFatalError(context, result)
        return nil, false
    end

    return result, true
end

local function drawFatalError()
    gfx.setColor(gfx.kColorWhite)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.drawTextInRect("Starry Messenger encountered an error.", 16, 24, 368, 28)
    if app.fatalContext then
        gfx.drawTextInRect("Context: " .. tostring(app.fatalContext), 16, 58, 368, 18)
    end
    if app.fatalError then
        gfx.drawTextInRect(tostring(app.fatalError), 16, 84, 368, 132)
    end
end

local function logModeSelection(source, viewId)
    StarryLog.info("mode selected via %s: %s", source, viewId)
end

local function refreshActiveSceneAudio()
    if not ViewAudio.isEnabled() then
        ViewAudio.stop()
        return
    end

    if app.scene == nil then
        return
    end

    if app.scene.viewId ~= nil then
        ViewAudio.playForView(app.scene.viewId)
        return
    end

    ViewAudio.stop()
end

local function returnToCurrentTitle(returnedViewId, options)
    local catalog = app.session.catalog
    local viewItems = getCatalogViewItems(catalog)
    ViewAudio.stop()
    setScene(buildGameTitleScene(catalog, {
        selectedIndex = getViewIndex(viewItems, returnedViewId),
        previewEffect = options and options.previewEffect or nil,
        previewViewId = returnedViewId,
        previewModeId = options and options.previewModeId or nil
    }))
end

local function showView(viewId, options)
    options = options or {}
    logModeSelection("app", viewId)
    if viewId == "multiplayer" then
        app.session:setPlayerCount(options.modeId or 2)
        ViewAudio.stop()
        setScene(buildGameTitleScene("multi"))
        return
    end
    if viewId == "duck" then
        ViewAudio.stop()
        setScene(DuckGameScene.new({
            multiplayer = app.session:isMultiplayer(),
            modeId = options.modeId,
            playerCount = app.session.playerCount,
            portalService = app.portalService,
            onReturnToTitle = function(returnedViewId)
                StarryLog.info("returning to title")
                returnToCurrentTitle(returnedViewId or viewId)
            end
        }))
        return
    elseif viewId == "orbital" then
        ViewAudio.stop()
        setScene(OrbitalDefenseScene.new({
            multiplayer = app.session:isMultiplayer(),
            playerCount = app.session.playerCount,
            portalService = app.portalService,
            onReturnToTitle = function(returnedViewId)
                StarryLog.info("returning to title")
                returnToCurrentTitle(returnedViewId or viewId)
            end
        }))
        return
    end

    local actualViewId = viewId == "rccar_multi" and "rccar" or viewId
    if viewId == "life" and options.modeId == GameOfLife.MODE_REVIEW then
        options.effect = nil
    end
    if viewId == "rccar_multi" then
        options.effect = nil
    end
    ViewAudio.playForView(actualViewId)
    setScene(ViewScene.new({
        viewId = actualViewId,
        modeId = options.modeId,
        effect = options.effect,
        session = app.session,
        onReturnToTitle = function(returnedViewId, effect)
            StarryLog.info("returning to title")
            returnToCurrentTitle(viewId, {
                previewEffect = effect,
                previewModeId = effect and effect.modeId or options.modeId
            })
        end
    }))
end

buildGameTitleScene = function(catalog, options)
    options = options or {}
    ViewAudio.stop()
    local viewItems = getCatalogViewItems(catalog)
    local subtitle = catalog == "multi"
        and string.format("Multiplayer Games  %d Beings", app.session.playerCount)
        or "Single Player"
    safeCall("buildSystemMenu", function()
        buildSystemMenu(viewItems)
    end)
    return TitleScene.new({
        viewItems = viewItems,
        catalog = catalog,
        playerCount = app.session.playerCount,
        selectedIndex = options.selectedIndex,
        previewEffect = options.previewEffect,
        previewViewId = options.previewViewId,
        previewModeId = options.previewModeId,
        headerTitle = "STARRY MESSENGER",
        headerSubtitle = subtitle,
        onBack = function()
            if catalog == "multi" then
                app.session:setPlayerCount(1)
                setScene(buildGameTitleScene("single"))
                return
            end
            setScene(buildSplashScene())
        end,
        onSelectView = function(viewId, effect, modeId)
            logModeSelection("title", viewId)
            showView(viewId, {
                effect = effect,
                modeId = modeId
            })
        end
    })
end

buildSplashScene = function()
    ViewAudio.stop()
    StarryLog.info("buildSplashScene")
    return SplashScene.new({
        onContinue = function()
            app.session:setPlayerCount(1)
            StarryLog.info("splash requested title scene")
            setScene(buildGameTitleScene("single"))
        end
    })
end

function buildSystemMenu(viewItems)
    local menu = pd.getSystemMenu()
    menu:removeAllMenuItems()

    menu:addMenuItem("Title Menu", function()
        ViewAudio.stop()
        setScene(buildGameTitleScene(app.session.catalog))
    end)

    menu:addCheckmarkMenuItem("Sound", ViewAudio.isEnabled(), function(value)
        ViewAudio.setEnabled(value)
        refreshActiveSceneAudio()
    end)

    menu:addCheckmarkMenuItem("Show Controls", ControlHelp.isOverlayEnabled(), function(value)
        ControlHelp.setOverlayEnabled(value)
    end)

    menu:addCheckmarkMenuItem("Fish Spawn Mode", FishPond.isSpawnModeEnabled(), function(value)
        FishPond.setSpawnModeEnabled(value)
    end)

    menu:addCheckmarkMenuItem("Duck Turn Mode", DuckGameScene.isTurnModeEnabled(), function(value)
        DuckGameScene.setTurnModeEnabled(value)
    end)

    menu:addCheckmarkMenuItem("RC Auto Brake", RCCarArena.isAutoBrakeEnabled(), function(value)
        RCCarArena.setAutoBrakeEnabled(value)
    end)

    menu:addCheckmarkMenuItem("Space Miner Compact Turn", SpaceMiner.isCompactTurnEnabled(), function(value)
        SpaceMiner.setCompactTurnEnabled(value)
        if app.scene and app.scene.viewId == "spaceminer" and app.scene.effect and app.scene.effect.refreshSettings then
            app.scene.effect:refreshSettings()
        end
    end)
end

function pd.update()
    gfx.clear(gfx.kColorBlack)
    gfx.setColor(gfx.kColorWhite)

    if app.fatalError then
        drawFatalError()
        return
    end

    if app.portalService and app.portalService.update then
        local _, ok = safeCall("portal.update", function()
            app.portalService:update()
        end)
        if not ok then
            drawFatalError()
            return
        end
    end

    if app.scene and app.scene.update then
        local _, ok = safeCall("scene.update", function()
            app.scene:update()
        end)
        if not ok then
            drawFatalError()
        end
    end
end

pd.display.setRefreshRate(30)
StarryLog.info("boot begin")
safeCall("buildSystemMenu", function()
    StarryLog.info("building initial system menu")
    buildSystemMenu(SINGLE_VIEW_ITEMS)
end)

local initialScene = safeCall("buildSplashScene", function()
    StarryLog.info("requesting initial splash scene")
    return buildSplashScene()
end)

if initialScene then
    local _, ok = safeCall("setScene(initialScene)", function()
        StarryLog.info("activating initial scene")
        setScene(initialScene)
    end)
    if not ok then
        app.scene = nil
    end
end
