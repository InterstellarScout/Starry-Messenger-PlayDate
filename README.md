# Starry-Messenger-PlayDate
This is a collection of vibe-coded games for the Play.Date console based on personal programming projects over the years. Experience stars, mini games (some multiplayer), procedural toys, and much more.

Current single-player views include Warp Speed, Star Fall, Game of Life, Fireworks, Ant Farm, CRT TV, Wacky, Space Miner, Sky Watch, Photo Viewer, Gif Player, Fishy Pond, RC Arena, Lava Lamp, and the shared title-preview variants of those systems.

`CRT TV` now enters through a title-specific loading handoff. Pressing `A` on that menu item removes the title scene immediately, holds on a captured CRT still, then swaps into the live CRT view once that mode finishes initializing. While `CRT TV` is merely highlighted on the title menu, that same captured still is used as the preview so the real CRT effect does not start loading until `A` is pressed.

`Game of Life` now follows the same pattern. Its title tile uses a static captured still instead of building the live simulation preview, and the actual Life view is only constructed after selection. On entry it now uses a dedicated loading card that incrementally prewarms the live Life state and lets the player press `A` to interrupt and jump in immediately with whatever warm data has finished so far, instead of blocking for one long startup stall. Whether the prewarm completes on its own or the player presses `A` early, the live session now starts from the first warmed frame instead of dropping in on the last cached one.

The title wheel now has a free-spin state: when you crank hard enough to throw the menu, the normal background preview is unloaded, a temporary uniform `Star Fall` field fades in behind the spinner, and those stars move together in the crank direction at the wheel's spin speed until the menu settles and fades back to the selected preview. That title-only fidget background now has separate `Star Fall` and `Warp Speed` response modifiers, both currently set to `-0.5`, so the temporary stars need roughly twice as much crank speed before they streak as aggressively as before. Once fidget speed crosses `600`, the temporary background swaps into `Warp Speed`, and after warp metric `3000` it keeps the same star count but scales up warp-star size every additional `1000` of speed for a progressive whiteout effect without the earlier star-count lag spike. That temporary spin state also drops the usual title-screen gray overlay until the menu settles again. Pressing `A` during the spin now brings up a live counter that keeps tracking the crank, shows the current session-high speed for the title fidget mode, and toggles between live and locked display states on repeated `A` presses without stopping the spinner itself.

`Trail Blazer` is a line-and-drop toy with two title labels, `Flow` and `Drive 3.2`, that now share the same live controls. The crank steers the player circle, `Up` and `Down` move it forward and backward at a fixed speed of `3.2`, `Right` only draws while held, and `Left` drops the currently loaded ball onto the board. Pressing `A` now opens an in-scene menu with `Clear Screen` and a `Hide Text` checkbox instead of clearing immediately. Tilt still influences released balls while they fall and roll, dropped balls are still capped at `3` active balls on-screen, and pressing Home in `Flow` now hides the gameplay text in the captured menu image for cleaner screenshots.

`Sky Watch` is a compact northern-hemisphere planetarium view. It asks for a timezone on first entry, remembers it, then uses the crank to set a signed simulation-rate value centered on `0`, with very slow motion near zero and effectively unlimited speed in either direction as you keep turning. The sky display now uses a full-dome northern sky map instead of a narrow forward slice, so the star field stays in a stable celestial layout while stars and planets move smoothly across it over simulated time. `Left` and `Right` pause time and step by the current signed-rate size, a brief hold jumps to the previous or next sunrise or sunset, `Up` and `Down` rotate the sky orientation through the eight cardinal/intercardinal headings, and `A` locks or unlocks crank speed changes. While `Sky Watch` is highlighted on the title menu, pressing `B` clears the saved timezone.

`Photo Viewer` packages the converted Artemis stills from `Source/images/adapted/` and the generated `Source/data/photos.lua` manifest into a monochrome Playdate slideshow. The title preview cycles the collection automatically. In the live view, the crank or `Left` and `Right` move photo-by-photo, `A` toggles autoplay, `Up` hides or shows the info plaque, and `Down` cycles between fullscreen fill, fit-to-screen, and inverted fullscreen image modes. The live viewer now opens with the plaque hidden by default and swaps between pre-rendered fit and fill image variants instead of scaling one shared asset at runtime. The still-image converter also regenerates `Source/launcher.png` by choosing a random photo background and overlaying the `Starry Messenger` title for the Playdate launcher icon.

Photo credits for the Artemis stills are now preserved in `Source/data/photos.lua` and shown in the live viewer info plaque. Those credits are derived from the original NASA source image metadata and shoot notes that came with the downloaded originals. When the original files name an individual crew photographer such as Christina Koch, Victor Glover, Reid Wiseman, Jeremy Hansen, or Robert Markowitz, that name is used. When the source only identifies a NASA batch, PAO set, survey set, or mixed crew batch, the credit remains at the source level such as `NASA` or `Artemis II crew` rather than inventing a more specific attribution.

`Duck Game` now defaults to crank-turning controls on entry, so the crank steers the duck and `Up`/`Down` drive it forward and backward unless you toggle back out of that mode.

The single-player RC car entry now opens on `Puck Ring` first. Its former `RC Arena` mode is still present, but its title-screen mode label is now `Eject the Bad Thoughts!`.

`Wacky` is a procedural inflatable tube-man scene. Its title preview starts fully extended, then slumps into a floppy idle pose. In the live view, turning the crank pumps the body upright, while stopping the crank lets it sag and flop over again. Its arms now use a multi-jointed spring chain, so the old bend direction is still there but it bounces through several joints instead of folding at one elbow.

`Space Miner` is a new ship-combat and asteroid-mining view. The ship stays centered while the world moves around it, the crank rotates the ship, `Up` and `Down` add forward or reverse thrust with persistent space momentum, `Left` holds a laser drill, and `Right` launches or detonates a missile using the same single-active-missile rhythm as Orbital Defense. After the shield has taken damage, avoiding further hits for `5` seconds now starts a slow shield refill, and the second-largest asteroid tier now renders as a solid, visible chunk instead of fading too close to the background.

`Space Miner` supports three crank-turn modes from the title screen:
- `Turn 360`: one full crank rotation equals one full ship rotation.
- `Turn 180`: half a crank window maps to a full ship rotation, so crank motion is more sensitive.
- `Turn 90`: a quarter-turn crank window maps to a full ship rotation for the most sensitive steering.

`Space Miner` asteroid mining flow:
- Large asteroids split into two smaller chunks when destroyed.
- Each of those chunks can split again, for three total breakup generations after the starting rock.
- Smaller fragments move faster, so the mining field gets busier as the player drills deeper into a cluster.

`Space Miner` stage schedule:
- Stage 1: a two-minute mining window with only asteroids.
- Stage 2: seeker wave 1 with 4 heat-seeking ships.
- Stage 3: seeker wave 2 with 8 heat-seeking ships.
- Stage 4: seeker wave 3 with 16 heat-seeking ships.
- Stage 5: another two-minute mining break.
- Stage 6: escaper wave 1 with 2 ships that try to avoid nearby asteroids, the player, and incoming missiles.
- Stage 7: escaper wave 2 with 4 more evasive ships.
- Stage 8: striker assault with 3 narrow, agile ships that can accelerate independently while aiming at the player and firing missiles.

`Space Miner` combat and survivability rules:
- The player has 2 shield blocks first, then 2 hull hits after the shield is gone.
- Seeker ships chase the player directly with slower mass-heavy acceleration.
- Escaper ships run away when they enter the player's 100-pixel threat area, and otherwise try to dodge asteroids and missiles.
- Striker ships orbit and strafe, keep their noses pointed at the player, and periodically fire missiles that must be intercepted or dodged.

The GIF player now browses category folders under `Source/gifs/<Category>/`. It opens on a category selector first, then drops into the GIF browser for that folder, and finally into fullscreen playback for the selected GIF. Original downloaded media is kept under `assets/source_gifs/originals/`, while converted Playdate frame sets remain under `Source/gifs/`.

GIF-specific optional audio now lives under `Source/audio/gifplayer/<gif-audio-folder>/`. The GIF player looks for the first supported file in each folder and keeps it synced while scrubbing or during forward autoplay. Reverse autoplay remains silent because Playdate's streamed file playback cannot run backwards.

Large still images can be prepared with `python .\tools\image_adapter.py`. The script reads originals from `assets/source_images/originals/`, creates both fit-to-screen and fullscreen-cropped Playdate monochrome PNGs for each image, writes them to `Source/images/adapted/`, and regenerates the `Source/data/photos.lua` manifest used by `Photo Viewer`.
