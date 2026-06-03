--[[
Starry Messenger application entry point.

Purpose:
- boots shared systems and scene routing
- defines the single-player and multiplayer title catalogs
- owns scene transitions, system menu actions, and fatal-error rendering
]]
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "gameconfig"
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
import "systems/dimensionalsplit"
import "systems/rccararena"
import "systems/tiltballs"
import "systems/photoviewer"
import "systems/trailblazer"
import "systems/marblemadness"
import "systems/vibes"
import "systems/puddledrops"
import "systems/dropper"
import "systems/controlhelp"
import "systems/multiplayer"
import "systems/sessionstate"
import "systems/starryportal"
import "systems/viewaudio"
import "scenes/splash"
import "scenes/title"
import "scenes/view"
import "scenes/foldertransition"
import "scenes/loadingstill"
import "scenes/lifeloading"
import "scenes/duckgame"
import "scenes/orbitaldefense"

local pd <const> = playdate
local gfx <const> = pd.graphics
local APP_NAME <const> = "Starry Messenger"
local APP_VERSION <const> = "0.1.0"
local TITLE_CONFIG <const> = GameConfig and GameConfig.title or {}

StarryMessengerAppVersion = APP_VERSION

local app = {
    fatalError = nil,
    fatalContext = nil,
    session = SessionState.new(),
    portalService = StarryPortalService.new()
}
local buildGameTitleScene
local buildVibesTitleScene
local buildSplashScene

local function buildVibesViewItems()
    local items = {
        {
            id = "crttv",
            label = "CRT TV",
            openViewId = "crttv",
            controlViewId = "crttv"
        }
    }

    for _, item in ipairs(VibesEffect.getCatalogItems()) do
        items[#items + 1] = item
    end

    return items
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
        getModeLabel = MultiplayerConfig.getBeingCountLabel
    },
    { id = "vibes", label = "Vibes" },
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
    {
        id = "puddledrops",
        label = "Puddle Drops",
        modes = {
            PuddleDrops.MODE_AUTO,
            PuddleDrops.MODE_PLAYER
        },
        modeId = PuddleDrops.MODE_AUTO,
        getModeLabel = PuddleDrops.getModeLabel
    },
    { id = "dropper", label = "Dropper" },
    { id = "tiltballs", label = "Bouncy Balls" },
    { id = "wacky", label = "Wacky" },
    { id = "dimensionalsplit", label = "Dimensional Split" },
    {
        id = "spaceminer",
        label = "Space Miner"
    },
    {
        id = "trailblazer",
        label = "Trail Blazer",
        modes = {
            TrailBlazer.MODE_FLOW,
            TrailBlazer.MODE_DRIVE
        },
        modeId = TrailBlazer.MODE_FLOW,
        getModeLabel = TrailBlazer.getModeLabel
    },
    { id = "marblemadness", label = "Marble Madness" },
    { id = "photoviewer", label = "Photo Viewer" },
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
            RCCarArena.MODE_HOCKEY,
            RCCarArena.MODE_CHASE,
            RCCarArena.MODE_VERSUS
        },
        modeId = RCCarArena.MODE_HOCKEY,
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

local VIBES_VIEW_ITEMS <const> = buildVibesViewItems()

local function getCatalogViewItems(catalog)
    if catalog == "multi" then
        return MULTIPLAYER_VIEW_ITEMS
    elseif catalog == "vibes" then
        return VIBES_VIEW_ITEMS
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
    if catalog == "multi" then
        setScene(buildGameTitleScene(catalog, {
            selectedIndex = getViewIndex(viewItems, returnedViewId),
            previewEffect = options and options.previewEffect or nil,
            previewViewId = returnedViewId,
            previewModeId = options and options.previewModeId or nil
        }))
        return
    elseif catalog == "vibes" then
        setScene(buildVibesTitleScene({
            selectedIndex = getViewIndex(viewItems, returnedViewId),
            previewEffect = options and options.previewEffect or nil,
            previewViewId = returnedViewId,
            previewModeId = options and options.previewModeId or nil
        }))
        return
    end

    setScene(buildGameTitleScene("single", {
        selectedIndex = getViewIndex(viewItems, returnedViewId),
        previewEffect = options and options.previewEffect or nil,
        previewViewId = returnedViewId,
        previewModeId = options and options.previewModeId or nil
    }))
end

local function startVibesFolderEnterTransition(onComplete)
    setScene(FolderTransitionScene.new({
        startSpeed = TITLE_CONFIG and TITLE_CONFIG.warpPreviewSpeed or 1,
        targetSpeed = 100,
        accelerationFrames = 8,
        flashFrames = 7,
        flashColor = gfx.kColorWhite,
        onFlashBuildScene = function()
            return buildVibesTitleScene({
                selectedIndex = 1
            })
        end,
        onComplete = onComplete
    }))
end

local function startVibesFolderExitTransition(onComplete)
    setScene(FolderTransitionScene.new({
        startSpeed = -(TITLE_CONFIG and TITLE_CONFIG.warpPreviewSpeed or 1),
        targetSpeed = -100,
        accelerationFrames = 8,
        flashFrames = 7,
        flashColor = gfx.kColorBlack,
        onFlashBuildScene = function()
            app.session:setCatalog("single")
            return buildGameTitleScene("single", {
                selectedIndex = getViewIndex(SINGLE_VIEW_ITEMS, "vibes")
            })
        end,
        onComplete = onComplete
    }))
end

local function showView(viewId, options)
    options = options or {}
    local returnViewId = options.returnViewId or viewId
    logModeSelection("app", viewId)
    if viewId == "multiplayer" then
        app.session:setPlayerCount(options.modeId or 2)
        ViewAudio.stop()
        safeCall("buildSystemMenu", function()
            buildSystemMenu(MULTIPLAYER_VIEW_ITEMS, nil, nil)
        end)
        setScene(buildGameTitleScene("multi"))
        return
    end
    if viewId == "duck" then
        ViewAudio.stop()
        safeCall("buildSystemMenu", function()
            buildSystemMenu(getCatalogViewItems(app.session.catalog), "duck", returnViewId)
        end)
        setScene(DuckGameScene.new({
            multiplayer = app.session:isMultiplayer(),
            modeId = options.modeId,
            playerCount = app.session.playerCount,
            portalService = app.portalService,
            onReturnToTitle = function(returnedViewId)
                StarryLog.info("returning to title")
                returnToCurrentTitle(returnedViewId or returnViewId)
            end
        }))
        return
    elseif viewId == "orbital" then
        ViewAudio.stop()
        safeCall("buildSystemMenu", function()
            buildSystemMenu(getCatalogViewItems(app.session.catalog), "orbital", returnViewId)
        end)
        setScene(OrbitalDefenseScene.new({
            multiplayer = app.session:isMultiplayer(),
            playerCount = app.session.playerCount,
            portalService = app.portalService,
            onReturnToTitle = function(returnedViewId)
                StarryLog.info("returning to title")
                returnToCurrentTitle(returnedViewId or returnViewId)
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
    safeCall("buildSystemMenu", function()
        buildSystemMenu(getCatalogViewItems(app.session.catalog), actualViewId, returnViewId)
    end)
    if actualViewId == "life" then
        setScene(LifeLoadingScene.new({
            imagePath = "images/loading/gameoflife-loading-still",
            modeId = options.modeId,
            session = app.session,
            onReturnToTitle = function(returnedViewId, effect)
                StarryLog.info("returning to title")
                returnToCurrentTitle(returnedViewId or returnViewId, {
                    previewEffect = effect,
                    previewModeId = effect and effect.modeId or options.modeId
                })
            end,
            onReady = function(nextScene)
                setScene(nextScene)
            end
        }))
        return
    end
    if actualViewId == "crttv" then
        local loadingImagePath = actualViewId == "crttv"
            and "images/loading/crttv-loading-still"
            or "images/loading/gameoflife-loading-still"
        setScene(LoadingStillScene.new({
            imagePath = loadingImagePath,
            buildScene = function()
                return ViewScene.new({
                    viewId = actualViewId,
                    modeId = options.modeId,
                    effect = options.effect,
                    session = app.session,
                    onReturnToTitle = function(returnedViewId, effect)
                        StarryLog.info("returning to title")
                        returnToCurrentTitle(returnedViewId or returnViewId, {
                            previewEffect = effect,
                            previewModeId = effect and effect.modeId or options.modeId
                        })
                    end
                })
            end,
            onReady = function(nextScene)
                setScene(nextScene)
            end
        }))
        return
    end
    setScene(ViewScene.new({
        viewId = actualViewId,
        modeId = options.modeId,
        effect = options.effect,
        session = app.session,
        onReturnToTitle = function(returnedViewId, effect)
            StarryLog.info("returning to title")
            returnToCurrentTitle(returnedViewId or returnViewId, {
                previewEffect = effect,
                previewModeId = effect and effect.modeId or options.modeId
            })
        end
    }))
end

buildGameTitleScene = function(catalog, options)
    options = options or {}
    app.session:setCatalog(catalog or "single")
    ViewAudio.stop()
    local viewItems = getCatalogViewItems(catalog)
    local subtitle = catalog == "multi"
        and string.format("Multiplayer Games  %d Beings", app.session.playerCount)
        or "Single Player"
    safeCall("buildSystemMenu", function()
        buildSystemMenu(viewItems, nil, nil)
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
                app.session:setCatalog("single")
                setScene(buildGameTitleScene("single", {
                    selectedIndex = getViewIndex(SINGLE_VIEW_ITEMS, "multiplayer")
                }))
                return
            end
            setScene(buildSplashScene())
        end,
        onResetSelection = function()
            return false
        end,
        onSelectView = function(viewId, effect, modeId, selectedItemId)
            if viewId == "vibes" then
                app.session:setCatalog("vibes")
                startVibesFolderEnterTransition(function(nextScene)
                    setScene(nextScene or buildVibesTitleScene({
                        selectedIndex = 1
                    }))
                end)
                return
            end
            logModeSelection("title", viewId)
            showView(viewId, {
                effect = effect,
                modeId = modeId,
                returnViewId = selectedItemId or viewId
            })
        end
    })
end

buildVibesTitleScene = function(options)
    options = options or {}
    app.session:setCatalog("vibes")
    ViewAudio.stop()
    safeCall("buildSystemMenu", function()
        buildSystemMenu(VIBES_VIEW_ITEMS, nil, nil)
    end)
    return TitleScene.new({
        viewItems = VIBES_VIEW_ITEMS,
        catalog = "vibes",
        playerCount = app.session.playerCount,
        selectedIndex = options.selectedIndex or 1,
        previewEffect = options.previewEffect,
        previewViewId = options.previewViewId,
        previewModeId = options.previewModeId,
        headerTitle = "STARRY MESSENGER",
        headerSubtitle = "Vibes",
        onBack = function()
            startVibesFolderExitTransition(function(nextScene)
                app.session:setCatalog("single")
                setScene(nextScene or buildGameTitleScene("single", {
                    selectedIndex = getViewIndex(SINGLE_VIEW_ITEMS, "vibes")
                }))
            end)
        end,
        onResetSelection = function()
            return false
        end,
        onSelectView = function(viewId, effect, modeId, selectedItemId)
            logModeSelection("vibes-folder", tostring(modeId))
            showView(viewId, {
                effect = effect,
                modeId = modeId,
                returnViewId = selectedItemId or viewId
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

function buildSystemMenu(viewItems, activeViewId, titleReturnViewId)
    local menu = pd.getSystemMenu()
    menu:removeAllMenuItems()

    menu:addMenuItem("Title Menu", function()
        ViewAudio.stop()
        local selectedIndex = titleReturnViewId ~= nil and getViewIndex(viewItems, titleReturnViewId) or nil
        if app.session.catalog == "multi" then
            setScene(buildGameTitleScene("multi", {
                selectedIndex = selectedIndex
            }))
        elseif app.session.catalog == "vibes" then
            setScene(buildVibesTitleScene({
                selectedIndex = selectedIndex
            }))
        else
            setScene(buildGameTitleScene("single", {
                selectedIndex = selectedIndex
            }))
        end
    end)

    menu:addCheckmarkMenuItem("Sound", ViewAudio.isEnabled(), function(value)
        ViewAudio.setEnabled(value)
        refreshActiveSceneAudio()
    end)

    if activeViewId == "fishpond" then
        menu:addCheckmarkMenuItem("Fish Spawn Mode", FishPond.isSpawnModeEnabled(), function(value)
            FishPond.setSpawnModeEnabled(value)
        end)
    end

    if activeViewId == "duck" then
        menu:addCheckmarkMenuItem("Duck Turn Mode", DuckGameScene.isTurnModeEnabled(), function(value)
            DuckGameScene.setTurnModeEnabled(value)
        end)
    end

    if activeViewId == "rccar" then
        menu:addCheckmarkMenuItem("RC Auto Brake", RCCarArena.isAutoBrakeEnabled(), function(value)
            RCCarArena.setAutoBrakeEnabled(value)
        end)
    end

    if app.session.catalog == "vibes" then
        menu:addCheckmarkMenuItem("View Stats", VibesEffect.isViewStatsEnabled(), function(value)
            VibesEffect.setViewStatsEnabled(value)
        end)
    end

    if activeViewId == "trailblazer" then
        menu:addCheckmarkMenuItem("Trailblazer Controls", TrailBlazer.isControlsHintEnabled(), function(value)
            TrailBlazer.setControlsHintEnabled(value)
            if app.scene and app.scene.viewId == "trailblazer" and app.scene.effect and app.scene.effect.refreshMenuSettings then
                app.scene.effect:refreshMenuSettings()
            end
        end)
    end

    if activeViewId == "spaceminer" then
        menu:addCheckmarkMenuItem("Space Miner Compact Turn", SpaceMiner.isCompactTurnEnabled(), function(value)
            SpaceMiner.setCompactTurnEnabled(value)
            if app.scene and app.scene.viewId == "spaceminer" and app.scene.effect and app.scene.effect.refreshSettings then
                app.scene.effect:refreshSettings()
            end
        end)
    end
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

function pd.gameWillPause()
    if app.scene and app.scene.onWillPause then
        local _, ok = safeCall("scene.onWillPause", function()
            app.scene:onWillPause()
        end)
        if not ok then
            drawFatalError()
        end
    end
end

function pd.gameWillResume()
    if app.scene and app.scene.onDidResume then
        local _, ok = safeCall("scene.onDidResume", function()
            app.scene:onDidResume()
        end)
        if not ok then
            drawFatalError()
        end
    end
end

pd.display.setRefreshRate(30)
StarryLog.forceWrite("info", "%s v%s", APP_NAME, APP_VERSION)
StarryLog.info("boot begin")
safeCall("buildSystemMenu", function()
    StarryLog.info("building initial system menu")
    buildSystemMenu(SINGLE_VIEW_ITEMS, nil)
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
