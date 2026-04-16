--[[
Human-readable control text catalog.

Purpose:
- returns per-view instruction strings for the title menu help band
- adapts help text to the currently selected mode where needed
- keeps input documentation separate from scene logic
]]
ControlHelp = {}

local function buildSpec(title, lines)
    return {
        title = title,
        lines = lines
    }
end

function ControlHelp.getEntrySpec(viewId, modeId)
    if viewId == "warp" then
        return buildSpec("Warp Speed Controls", {
            "Crank: change star speed.",
            "D-pad: steer the starfield direction.",
            "Left/Right on the title wheel: switch between Warp Speed and Inverse Warp.",
            "A: start. In game, toggle between speed control and spin control.",
            "Spin control: the crank sets a persistent rotation speed that keeps going.",
            "Speed control: the crank changes star speed while spin keeps running.",
            "B: return to title. Warp speed resets to 9 on exit."
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
            lines[#lines + 1] = "Recorder mode writes each shown board state to a CSV."
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
    elseif viewId == "gifplayer" then
        if modeId == GifPlayerEffect.MODE_GIF then
            return buildSpec("GIF Player Controls", {
                "Crank: scrub the current GIF forward and backward frame by frame.",
                "D-pad Up/Down: switch to another converted GIF in the local catalog.",
                "D-pad Left/Right: step one frame at a time.",
                "A: invert the GIF colors.",
                "B: return to title.",
                "Run tools/gif_adapter.py from the project files to add more GIFs."
            })
        end

        return buildSpec("CRT Static Controls", {
            "Full-screen static now runs on its own with no crank scrubbing.",
            "A: toggle the rolling transparent bars.",
            "The title preview flips between two static frames instead of rolling continuously.",
            "B: return to title."
        })
    elseif viewId == "antfarm" then
        return buildSpec("Ant Farm Controls", {
            "D-pad: move the hand around the top of the ant farm.",
            "Crank: nudge the hand left and right more precisely.",
            "A: drop a new ant into the soil.",
            "Dropped ants now show up brighter against the dark soil so their movement reads clearly.",
            "Ants dig light tunnels through the dark soil, then periodically kick into faster tunnel-burst runs.",
            "When an ant nears an existing tunnel, it tends to connect briefly before wandering off again.",
            "B: return to title."
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
            "D-pad: set the lead duck's travel direction.",
            "Crank: drive the duck forward in that chosen direction without adding extra speed.",
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
            "Use the Home menu for Title Menu, Warp Speed, or Star Fall exits mid-run.",
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
                "Push pucks into the opponent's net and keep them out of yours.",
                "In crank speed mode, the crank changes the shared max speed in both directions, such as +7 and -7 or +90 and -90.",
                "B: return to title."
            })
        end

        return buildSpec("RC Block Chase Controls", {
            "Crank: rotate the car.",
            "A: toggle the crank between steering and max-speed control.",
            "D-pad Left/Right: fine steering.",
            "D-pad Up/Down: accelerate forward or reverse within the current signed max speed.",
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
