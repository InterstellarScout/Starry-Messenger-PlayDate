# Starry-Messenger-PlayDate
This is a collection of vibe-coded games for the Play.Date console based on personal programming projects over the years. Experience stars, mini games (some multiplayer), procedural toys, and much more.

Build the project with `.\build.ps1`. For feature and bug-fix hardware validation, connect and unlock the Playdate, then use `.\build.ps1 -InstallDevice` to compile, upload, and launch the current build over USB with `pdutil`. If direct USB deployment is unavailable, reboot the Playdate into Data Disk mode and use `.\build.ps1 -InstallDataDisk` as a fallback. The only supported generated app bundle in this project root is `StarryMessenger.pdx`; stale test bundles such as `StarryMessenger-test.pdx` are not valid launch targets.

Current single-player views include Warp Speed, Star Fall, Multiplayer, Vibes, Game of Life, Fireworks, Puddle Drops, Dropper, Bouncy Balls, Wacky, Dimensional Split, Space Miner, Trail Blazer, Marble Madness, Photo Viewer, Gif Player, Fishy Pond, RC Arena, Orbital Defense, and Lava Lamp, plus the shared title-preview variants of those systems.

The main `Star Fall` title entry now offers two modes again: `Star Fall` and `Inverted Star Fall`. Both use the clean-loop prototype behavior where stars seed once from a random starting layout, preserve those starting positions, and wrap back to their original coordinates instead of being freshly respawned.

`CRT TV` now lives inside the `Vibes` folder and still enters through a title-specific loading handoff. Pressing `A` on that menu item removes the title scene immediately, holds on a captured CRT still, then swaps into the live CRT view once that mode finishes initializing. While `CRT TV` is merely highlighted on the Vibes menu, that same captured still is used as the preview so the real CRT effect does not start loading until `A` is pressed.

`Vibes` is now a dedicated title-menu folder directly under `Multiplayer` for lightweight procedural effects. Choosing `Vibes` from the main title runs a shorter warp-speed folder transition, flashes white, and loads the `Vibes` submenu during that flash so the menu is ready as the transition clears. Pressing `B` from that submenu runs the reverse negative-speed transition, flashes black, and returns to the main title with `Vibes` selected again. Returning from a live vibe effect also restores the Vibes title over the view you just left, matching the main title-screen preview handoff behavior. Inside the folder, each item opens one locked effect directly instead of dropping into a free-cycling browser.

The current `Vibes` folder entries are `CRT TV`, `Spiral`, `Tunnel Bars`, `Fractal Spiral`, `Line Bloom`, `Shape Pile-Up`, `Loop Fall`, `Polygon Storm`, `Micro Rotate`, `Cloud Bubbles`, and `Bubble Pop`. They stay code-drawn rather than GIF-backed so the crank can drive one shared signed speed model cleanly across every sub-effect. `Loop Fall` in `Vibes` remains the clean-loop Star Fall prototype built from preserved random starting positions that wrap back to their original distribution instead of respawning, while the main title `Star Fall` entry now exposes both normal and inverted variants of that same effect. `Spiral` is one massive geometric spiral centered on-screen and extending beyond the display width, `Fractal Spiral` draws a much denser field, `Micro Rotate` fills the full screen width, and `Line Bloom` has three crank-driven modes that cycle with `A`: in-place spin, full-screen orbit, and off-screen respawn drift. Live Vibes HUD text is hidden by default and can be restored with the Home-menu `View Stats` toggle.

`Puddle Drops` is now a separate dedicated view with two title modes: `Drop Waves` and `Player Pulse`. `Drop Waves` continuously spawns layered ripple circles from random points with a rolling active cap of `10`, while `Player Pulse` puts a movable marker on-screen so pressing `A` can fire a leading pulse from the player's current point before the layered puddle rings spread outward. That player marker now moves with the full D-pad again, and the pressed-`A` droplet now grows from a tiny point to a random size between `3` and `25` before it becomes ripples.

`Dropper` is a darker game-sized branch of that puddle idea and lives in the main `Views` folder, not under `Vibes`. It flips the scene to black water with white ripples and a white player stone. Bubble leaks now rise in random `20x20` clusters about once a second; if they finish swelling from a pixel to radius `5`, they burst into more ripple rings. Pressing `A` sends out a bright expanding flash from the player's stone, again starting tiny and growing to a random size between `3` and `25`, and any leaks caught inside that flash count toward the run score. Its crank speed now uses the same Warp Speed-style ladder as the other shared speed-driven views. The view also keeps a persistent cumulative `Depth` total of all plugged leaks across runs and drives a lightweight procedural watery soundscape when the system `Sound` toggle is enabled.

`Game of Life` now follows the same pattern. Its title tile uses a static captured still instead of building the live simulation preview, and the actual Life view is only constructed after selection. On entry it now uses a dedicated loading card that incrementally prewarms the live Life state and lets the player press `A` to interrupt and jump in immediately with whatever warm data has finished so far, instead of blocking for one long startup stall. Whether the prewarm completes on its own or the player presses `A` early, the live session now starts from the first warmed frame instead of dropping in on the last cached one.

The title wheel now has a free-spin state: when you crank hard enough to throw the menu, the normal background preview is unloaded, a temporary uniform `Star Fall` field fades in behind the spinner, and those stars move together in the crank direction at the wheel's spin speed until the menu settles and fades back to the selected preview. The normal title menu also shows the current app version from `pdxinfo` in the lower-right corner above the instruction band. That title-only fidget background now has separate `Star Fall` and `Warp Speed` response modifiers, both currently set to `-0.5`, so the temporary stars need roughly twice as much crank speed before they streak as aggressively as before. Once fidget speed crosses `600`, the temporary background swaps into `Warp Speed`, and after warp metric `3000` it keeps the same star count but scales up warp-star size every additional `1000` of speed for a progressive whiteout effect without the earlier star-count lag spike. That temporary spin state also drops the usual title-screen gray overlay and hides the menu header and subtitle, including folder headers such as `Vibes`, until menu previews can load again. Pressing `A` during the spin now brings up a live counter that keeps tracking the crank, shows the current session-high speed for the title fidget mode, and toggles between live and locked display states on repeated `A` presses without stopping the spinner itself.

The Home-menu `Title Menu` command returns to the title catalog and item for the app that was left. For example, using it during `Orbital Defense` returns to the title menu with `Orbital Defense` selected, and multiplayer or Vibes entries return to their matching folder title instead of falling back to a stale catalog.

The live `Warp Speed` view and the title and splash warp previews now all run from a `200`-star pool. Warp star screen coordinates are quantized once into the per-frame cache before drawing, which reduces shimmer from sub-pixel line and head placement and trims redundant work in the draw path. At higher speeds, a regulator now steadily reduces the active star count over time instead of letting the full pool hammer the frame rate indefinitely. Warp also emits periodic debug lines with active star count, total pool size, regulator target, visible star count, spawn count during the interval, and Lua memory usage including delta and peak values so long runs can be profiled on hardware for suspected memory leaks.

`Trail Blazer` is a line-and-drop toy with two title labels, `Flow` and `Drive 3.2`, that now share the same live controls. The crank steers the player circle, `Up` and `Down` move it forward and backward at a fixed speed of `3.2`, `Right` only draws while held, and `Left` drops the currently loaded ball onto the board. On entry it now shows a controls overlay that auto-hides on the first button press or crank move; that same first interaction clears the demo drawing and recenters the player before live play starts. Pressing `A` now opens an in-scene menu with `Clear Screen` and a `Hide Text` checkbox instead of clearing immediately. Tilt still influences released balls while they fall and roll, dropped balls are still capped at `3` active balls on-screen, and the Home menu now includes a `Trailblazer Controls` toggle for that startup overlay.

`Marble Madness` ports the local Processing marble toy into a Playdate view with mixed-size bouncing marbles, chaos collision impulses, edge bounces, and startup burst energy. The D-pad moves a gravity-well cursor, holding `A` pulls marbles toward that cursor, and the crank adjusts gravity strength.

`Photo Viewer` packages the converted Artemis stills from `Source/images/adapted/` and the generated `Source/data/photos.lua` manifest into a monochrome Playdate slideshow. The title preview cycles the collection automatically. In the live view, the crank or `Left` and `Right` move photo-by-photo, `A` toggles autoplay, `Up` hides or shows the info plaque, and `Down` cycles between fullscreen fill, fit-to-screen, and inverted fullscreen image modes. The live viewer now opens with the plaque hidden by default and swaps between pre-rendered fit and fill image variants instead of scaling one shared asset at runtime. The still-image converter also regenerates `Source/launcher.png` by choosing a random photo background and compositing a splash-style `Starry Messenger` title and star field for the Playdate launcher icon.

Photo credits for the Artemis stills are now preserved in `Source/data/photos.lua` and shown in the live viewer info plaque. Those credits are derived from the original NASA source image metadata and shoot notes that came with the downloaded originals. When the original files name an individual crew photographer such as Christina Koch, Victor Glover, Reid Wiseman, Jeremy Hansen, or Robert Markowitz, that name is used. When the source only identifies a NASA batch, PAO set, survey set, or mixed crew batch, the credit remains at the source level such as `NASA` or `Artemis II crew` rather than inventing a more specific attribution.

`Duck Game` now defaults to crank-turning controls on entry, so the crank steers the duck and `Up`/`Down` drive it forward and backward unless you toggle back out of that mode. It also now opens with a centered two-line tilt hint for up to `5` seconds, or until you press `A`, before getting out of the way.

`Bouncy Balls` now opens with a centered two-line prompt for up to `5` seconds, or until you press `A`: `Turn the Play Date upside down` and `and watch the ball fall to your feet!`

`Dimensional Split` is a standalone grid-blink view, not part of the `Vibes` folder. It fills the screen with black and white squares that each blink independently on random intervals between `0.1` and `5` seconds. Turning the crank now removes the old subdivision floor and ceiling, so the field can collapse to one flashing box or subdivide all the way down toward pixel-sized cells, while pressing `A` randomizes every square's starting color and blink timing again.

The single-player RC car entry now opens on `Puck Ring` first. Its former `Eject the Bad Thoughts!` mode is still present, but its title-screen mode label is now `Box Slider`.

`Wacky` is a procedural inflatable tube-man scene. Its title preview starts fully extended, then slumps into a floppy idle pose. In the live view, turning the crank pumps the body upright, while stopping the crank lets it sag and flop over again. Its arms now use a multi-jointed spring chain, so the old bend direction is still there but it bounces through several joints instead of folding at one elbow.

`Space Miner` is a ship-combat and asteroid-mining view. The ship stays centered while the world moves around it, the crank rotates the ship, `Up` and `Down` add forward or reverse thrust with persistent space momentum, `Left` holds a laser drill, and `Right` launches or detonates a missile using the same single-active-missile rhythm as Orbital Defense. After the shield has taken damage, avoiding further hits for `5` seconds now starts a slow shield refill, depleted shields no longer keep drawing after the last block is gone, and each combat wave flashes a bold white on-screen `ALERT` warning three times before the first enemies spawn with a clean gap before the actual wave entry. Large asteroids also get extra off-screen prune protection so newly arrived rocks do not disappear immediately under entity-pressure cleanup. Asteroid lifecycle diagnostics emit a bounded hardware log summary every `150` frames plus limited event lines for visibility exits, world wraps, player collisions, and entity-pressure prunes so disappearing rocks can be traced without restoring noisy global logging.

`Space Miner` supports three crank-turn modes from the title screen:
- `Turn 360`: one full crank rotation equals one full ship rotation.
- `Turn 180`: half a crank window maps to a full ship rotation, so crank motion is more sensitive.
- `Turn 90`: a quarter-turn crank window maps to a full ship rotation for the most sensitive steering.

`Space Miner` asteroid mining flow:
- Large asteroids split into two smaller chunks when destroyed.
- Each of those chunks can split again, for three total breakup generations after the starting rock.
- Smaller fragments move faster, so the mining field gets busier as the player drills deeper into a cluster.

`Space Miner` wave entities and other live entities:
- Configurable wave-spawn entities: `seeker`, `escaper`, and `striker`.
- Other entities active in the view include asteroid chunks across four breakup stages, enemy missiles, the player's missile, explosion rings, and decorative starfield items.

`Space Miner` stage schedule defaults now live in `Source/data/spaceminerwaves.lua`:
- Stage 1: a two-minute mining window with only asteroids.
- Stage 2: seeker wave 1 with 4 heat-seeking ships, preceded by the three-flash `ALERT`.
- Stage 3: seeker wave 2 with 8 heat-seeking ships.
- Stage 4: seeker wave 3 with 16 heat-seeking ships.
- Stage 5: another two-minute mining break.
- Stage 6: escaper wave 1 with 2 ships that try to avoid nearby asteroids, the player, and incoming missiles.
- Stage 7: escaper wave 2 with 4 more evasive ships.
- Stage 8: striker assault with 3 narrow, agile ships that can accelerate independently while aiming at the player and firing missiles.

Each wave stage in that config can now define:
- a timed start or an `after_stage_clear` trigger,
- one or more spawn entries,
- the entity type,
- quantity,
- and an entry degree where `0/360` is top, `90` is right, `180` is bottom, and `270` is left.

If a spawn entry quantity is greater than `1`, enemies alternate between the requested degree and its opposite degree. For example, `6` at `90` degrees yields `3` spawns at `90` and `3` at `270`.

`Lava Lamp` crank input now temporarily agitates all bubbles at once with per-bubble random push strength scaled by crank speed, instead of only nudging bubbles already in motion along one shared direction. As soon as the crank stops moving, that extra agitation stops too. Every bubble also carries a random layer number from `1` to `3`: bubbles on the same layer retain the existing collision, orbit, settling, and merged-goop behavior, while bubbles on different layers pass through each other to simulate depth. A bubble rerolls its layer whenever it settles at the top or bottom. Initial lamp population is configurable and currently starts with `40%` anchored at the top, `20%` anchored at the bottom, and the remaining `40%` already traveling through the main spawn area.

`Orbital Defense` single-player now lets the local turret fall back to bot behavior after `5` seconds without player input. Any new intentional crank, D-pad, laser, or missile input immediately restores control to the player, so the local turret can idle like the NPC wingmate and then be reclaimed seamlessly. The crank input threshold ignores tiny physical jitter that previously kept resetting the idle timer.

`Duck Game` ducks now render with a rounder oval body while keeping the smaller round head, so the pond racers read more like compact cartoon ducks instead of blocky rectangles.

Newly collected or stolen `Duck Game` chicks now ease slowly toward the back of the trail first instead of snapping quickly into line, so they stay closer to the pickup spot until the lead duck has moved past and the trail naturally gathers them in.

`Duck Game` now shows the local duck's current carried chick count in the top-left corner and a persistent lifetime total of all chicks ever delivered in the top-right corner.

`Space Miner` combat and survivability rules:
- The player has 2 shield blocks first, then 2 hull hits after the shield is gone.
- Seeker ships chase the player directly with slower mass-heavy acceleration.
- Escaper ships run away when they enter the player's 100-pixel threat area, and otherwise try to dodge asteroids and missiles.
- Striker ships orbit and strafe, keep their noses pointed at the player, and periodically fire missiles that must be intercepted or dodged.

The GIF player now browses category folders under `Source/gifs/<Category>/`. It opens on a category selector first, then drops into the GIF browser for that folder, and finally into fullscreen playback for the selected GIF. Original downloaded media is kept under `assets/source_gifs/originals/`, while converted Playdate frame sets remain under `Source/gifs/`.

GIF-specific optional audio now lives under `Source/audio/gifplayer/<gif-audio-folder>/`. The GIF player looks for the first supported file in each folder and keeps it synced while scrubbing or during forward autoplay. Reverse autoplay remains silent because Playdate's streamed file playback cannot run backwards.

Large still images can be prepared with `python .\tools\image_adapter.py`. The script reads originals from `assets/source_images/originals/`, creates both fit-to-screen and fullscreen-cropped Playdate monochrome PNGs for each image, writes them to `Source/images/adapted/`, and regenerates the `Source/data/photos.lua` manifest used by `Photo Viewer`.
