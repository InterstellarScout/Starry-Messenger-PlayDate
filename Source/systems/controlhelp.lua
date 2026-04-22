--[[
Human-readable control text catalog.

Purpose:
- returns per-view instruction strings for the title menu help band
- adapts help text to the currently selected mode where needed
- keeps input documentation separate from scene logic
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

ControlHelp = {}
ControlHelp.overlayEnabled = false

local OVERLAY_PADDING <const> = 10
local OVERLAY_TITLE_Y <const> = 10
local OVERLAY_BODY_Y <const> = 30
local OVERLAY_LINE_HEIGHT <const> = 14

local function buildSpec(title, lines)
    return {
        title = title,
        lines = lines
    }
end

function ControlHelp.isOverlayEnabled()
    return ControlHelp.overlayEnabled == true
end

function ControlHelp.setOverlayEnabled(enabled)
    ControlHelp.overlayEnabled = enabled == true
end

function ControlHelp.getEntrySpec(viewId, modeId)
    if viewId == "warp" then
        return buildSpec("Warp Speed Controls", {
            "Crank: change star speed.",
            "D-pad: steer the starfield direction.",
            "Left/Right on the title wheel: switch between Warp Speed and Inverse Warp.",
            "A: open the Warp test menu. Toggle persistent spin, trailing stars, triangle taper, and Star Fall style there.",
            "Spin control: the crank sets a persistent rotation speed that keeps going.",
            "Speed control: the crank changes star speed while spin keeps running.",
            "B: close the Warp test menu first, then return to title. Warp speed resets to 9 on exit."
        })
    elseif viewId == "fall" then
        return buildSpec("Star Fall Controls", {
            "Crank: change falling speed.",
            "D-pad: steer the falling field direction.",
            "Left/Right on the title wheel: switch between Star Fall and Inverse Fall.",
            "A: start. In game, toggle between speed control and spin control.",
            "Spin control: the crank sets a persistent rotation speed that keeps going.",
            "Speed control: the crank changes fall speed while spin keeps running.",
            "B: return to title."
        })
    elseif viewId == "life" then
        local title = "Game of Life Controls"
        local lines = {
            "Crank: scrub forward and backward through generations.",
            "D-pad Up/Down: change simulation speed.",
            "D-pad Left/Right: inject live cells.",
            "A: inject a larger burst of live cells.",
            "B: return to title."
        }
        if modeId == GameOfLife.MODE_ENDLESS then
            title = "Endless Life Controls"
            lines[#lines + 1] = "Cells near death can sprout new neighbors until the live-cell cap is reached."
        elseif modeId == GameOfLife.MODE_RECORD then
            title = "Game of Life Recorder Controls"
            lines[#lines + 1] = "Recorder mode writes each shown board state to a compact replay file."
        elseif modeId == GameOfLife.MODE_REVIEW then
            title = "Review Life Controls"
            lines = {
                "A: open the selected recording or run the selected browser action.",
                "Crank: scrub a loaded playback backward and forward.",
                "D-pad Up/Down: choose a saved recording.",
                "D-pad Left/Right: choose a browser action or step playback frames.",
                "B: return to the browser, then return to title."
            }
        end
        return buildSpec(title, lines)
    elseif viewId == "fireworks" then
        return buildSpec("Fireworks Controls", {
            "Crank: move the launcher left and right.",
            "D-pad Left/Right: move the launcher left and right.",
            "D-pad Up/Down: change the player firework type.",
            "Hold A: repeatedly launch the selected firework.",
            "B: return to title.",
            "Random fireworks still launch automatically in the background."
        })
    elseif viewId == "crttv" then
        return buildSpec("CRT TV Controls", {
            "A: toggle the transparent automatic rolling bars on and off.",
            "Crank: spawn a random-sized manual bar and drag it upward or downward through the screen.",
            "If you crank the manual bar off-screen, it wraps to the opposite side as a freshly sized bar.",
            "If you stop cranking, the manual bar slides down the screen and disappears.",
            "The title preview now uses cached CRT playback frames that pre-render during startup.",
            "B: return to title."
        })
    elseif viewId == "tiltballs" then
        return buildSpec("Bouncy Balls Controls", {
            "Tilt the Playdate to roll the balls and bounce them off each other and the walls.",
            "A: add another ball to the playfield.",
            "Crank: raise or lower the slowdown rate so the balls carry momentum longer or settle faster.",
            "The slowdown readout appears in the scene while you play.",
            "B: return to title."
        })
    elseif viewId == "wacky" then
        return buildSpec("Wacky Controls", {
            "Crank forward to fling the tube figure upward. Crank backward to help gravity yank it back down faster.",
            "A: toggle between the normal rigid body mode and a pile-up mode that lets the limbs collapse over each other once the crank is idle.",
            "In pile-up mode, Wacky can heap on the ground instead of always falling as one stiff stack.",
            "The preview starts fully extended, then collapses into its idle wobble on purpose.",
            "B: return to title."
        })
    elseif viewId == "spaceminer" then
        return buildSpec("Space Miner Controls", {
            "Crank: turn the ship. Space Miner Compact Turn in the Home menu switches between full 360 steering and a tighter turn window.",
            "D-pad Up/Down: thrust forward or reverse. Momentum carries until you counter it with opposite thrust.",
            "Turn 360 now lightly brakes on its own and snaps to a stop once your drift falls under a low speed threshold.",
            "Hold Left: fire the laser drill straight ahead to mine asteroids or burn enemy ships.",
            "Press Right: launch a missile. Press Right again while one is active to detonate it early, like Orbital Defense.",
            "Asteroids split into two smaller chunks three times, so mining escalates into denser debris fields.",
            "The run opens with two minutes of mining, then three seeker waves at 4, 8, and 16 ships, then another two-minute mining break.",
            "Later waves add escaper ships that avoid the player and missiles, then agile striker ships that aim at you and fire missiles of their own.",
            "You can absorb 4 hits total: 2 shield blocks first, then 2 hull hits.",
            "B: return to title."
        })
    elseif viewId == "gifplayer" then
        return buildSpec("GIF Player Controls", {
            "On entry, crank or D-pad chooses a GIF category and A opens it.",
            "Inside a category, Up/Down chooses a GIF and A starts fullscreen playback.",
            "Crank: scrub frames and synced audio in normal mode, or change playback speed in spin mode.",
            "D-pad Left/Right: step one frame at a time outside spin mode.",
            "A: open the current category, start the current GIF, or cycle fullscreen playback between normal, inverted, and animation spin.",
            "If a GIF has audio in its matching Source/audio/gifplayer folder, forward playback stays synced and manual scrubbing seeks through it.",
            "Reverse spin remains visual-only because Playdate file streaming cannot play backwards.",
            "B: back out from playback to the GIF browser, then to categories, then to title.",
            "GIF frame sets now live under Source/gifs/<Category>/ as category folders."
        })
    elseif viewId == "duck" then
        local deliveryLine = "Collect loose chicks, steal trailing chicks, and deliver them to your corner nest."
        local modeLine = "Single-player Duck Game now rotates between Duck Game, Two Ducks, Three Ducks, and Four Ducks from the title menu."
        local winLine = "The first duck to bank 50 chicks wins the race."
        if modeId == DuckGameScene.MODE_SOLO_CENTER then
            deliveryLine = "Collect loose chicks and keep banking them into the center nest as new babies appear."
            winLine = "Center Nest is an endless solo collection run."
        end
        return buildSpec("Duck Game Controls", {
            "Normal mode: D-pad sets the lead duck's travel direction, and the crank drives the duck forward in that chosen direction.",
            "Press A in game, or use Duck Turn Mode in the Home menu: the crank turns the duck, while Up and Down move it forward and backward.",
            deliveryLine,
            modeLine,
            winLine,
            "B: return to title."
        })
    elseif viewId == "orbital" then
        return buildSpec("Orbital Defense Controls", {
            "Crank or D-pad Left/Right: aim the local turret.",
            "D-pad Up/Down: move the turret around the defense shield.",
            "Hold A: fire the laser.",
            "B: launch a missile, then press B again to detonate the current missile.",
            "Use the Home menu Title Menu entry to exit mid-run.",
            "Single-player uses one NPC wingmate; multiplayer uses pdportal host/client play with exactly the chosen 2-4 turrets."
        })
    elseif viewId == "fishpond" then
        if modeId == FishPond.MODE_TANK then
            return buildSpec("Fishy Tank Controls", {
                "Crank: apply a temporary current push; faster spins push harder.",
                "D-pad: no direct fish control in this mode.",
                "A: no action.",
                "B: return to title.",
                "Shake: trigger a short panic burst in the school."
            })
        elseif modeId == FishPond.MODE_BUBBLES then
            return buildSpec("Fishy Bubbles Controls", {
                "Crank: move the bubble maker across the bottom.",
                "D-pad: move the player fish.",
                "Hold A: create bubbles repeatedly.",
                "B: return to title.",
                "Fish Spawn Mode in the system menu alternates bubble and fish spawning.",
                "Popping a bubble adds another fish to the school."
            })
        end

        return buildSpec("Fishy Pond Controls", {
            "Crank: move the bubble maker across the bottom.",
            "D-pad: move the player fish.",
            "Hold A: create bubbles repeatedly.",
            "B: return to title.",
            "Fish Spawn Mode in the system menu alternates bubble and fish spawning.",
            "Pop bubbles by swimming into them while the rest of the school still feeds itself."
        })
    elseif viewId == "rccar" then
        if modeId == RCCarArena.MODE_VERSUS then
            return buildSpec("RC Crash Arena Controls", {
                "Crank: rotate the car.",
                "A: toggle the crank between steering and max-speed control.",
                "D-pad Left/Right: fine steering.",
                "D-pad Up/Down: accelerate forward or reverse within the current signed max speed.",
                "RC Auto Brake in the Home menu returns the target speed to zero when Up and Down are released.",
                "Crash into the rival and kick squares off the floor.",
                "In crank speed mode, the crank changes the shared max speed in both directions, such as +7 and -7 or +90 and -90.",
                "The rival matches your current speed while it steers itself.",
                "B: return to title."
            })
        elseif modeId == RCCarArena.MODE_HOCKEY then
            return buildSpec("RC Puck Ring Controls", {
                "Crank: rotate the car.",
                "A: toggle the crank between steering and max-speed control.",
                "D-pad Left/Right: fine steering.",
                "D-pad Up/Down: accelerate forward or reverse within the current signed max speed.",
                "RC Auto Brake in the Home menu returns the target speed to zero when Up and Down are released.",
                "Push pucks into the opponent's net and keep them out of yours.",
                "In crank speed mode, the crank changes the shared max speed in both directions, such as +7 and -7 or +90 and -90.",
                "B: return to title."
            })
        end

        return buildSpec("RC Arena Controls", {
            "Crank: rotate the car.",
            "A: toggle the crank between steering and max-speed control.",
            "D-pad Left/Right: fine steering.",
            "D-pad Up/Down: accelerate forward or reverse within the current signed max speed.",
            "RC Auto Brake in the Home menu returns the target speed to zero when Up and Down are released.",
            "Slam sliding blocks off the screen so new ones jump in.",
            "In crank speed mode, the crank changes the shared max speed in both directions, such as +7 and -7 or +90 and -90.",
            "B: return to title."
        })
    elseif viewId == "lava" then
        return buildSpec("Lava Lamp Controls", {
            "Tilt the Playdate to define which side is the current top.",
            "Bubble travel speed is currently tuned to about 0.38-0.72 pixels per frame before the global speed multiplier.",
            "Each bubble gets a new top-linger value from 6 to 20 whenever it starts rising.",
            "Each trip also gets a capped travel window between 1x and 3x that bubble's linger time before it settles to the wall.",
            "Opposing moving and wall-bound bubbles can hook together, rotate halfway around each other over about 1-2 seconds, then release.",
            "Traveling bubbles repel each other; only bubbles resting on the same side merge visually.",
            "When 4 or more touching bubbles collect on the same wall, the shared gap between them fills in white temporarily.",
            "If one whole wall is about to flip and 4+ bubbles on the other wall are also close, those other timers reshuffle to break the sync.",
            "A full 180-degree pickup flips wall-bound bubbles to the opposite wall while already traveling bubbles keep going.",
            "Crank: bump only the bubbles that are currently in motion.",
            "D-pad Up/Down: raise or lower the overall bubble speed.",
            "B: return to title.",
            "D-pad Left/Right and A: no action."
        })
    elseif viewId == "rccar_multi" then
        return buildSpec("RC Multiplayer Controls", {
            "Left/Right: rotate your current RC setup, then use A to switch the crank into speed control.",
            "Use the selected multiplayer RC mode from the title dial before opening.",
            "B: return to title."
        })
    end

    return buildSpec("Controls", {
        "B: return to title."
    })
end

function ControlHelp.drawOverlay(viewId, modeId)
    if not ControlHelp.isOverlayEnabled() then
        return
    end

    local spec = ControlHelp.getEntrySpec(viewId, modeId)
    if spec == nil then
        return
    end

    gfx.setColor(gfx.kColorBlack)
    gfx.setDitherPattern(0.7, gfx.image.kDitherTypeBayer8x8)
    gfx.fillRect(0, 0, 400, 240)
    gfx.setDitherPattern(1.0, gfx.image.kDitherTypeBayer8x8)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawTextAligned(spec.title or "Controls", 200, OVERLAY_TITLE_Y, kTextAlignment.center)

    local y = OVERLAY_BODY_Y
    for _, line in ipairs(spec.lines or {}) do
        gfx.drawTextInRect(line, OVERLAY_PADDING, y, 400 - (OVERLAY_PADDING * 2), OVERLAY_LINE_HEIGHT, nil, nil, kTextAlignment.left)
        y = y + OVERLAY_LINE_HEIGHT
        if y > 224 then
            break
        end
    end

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end
