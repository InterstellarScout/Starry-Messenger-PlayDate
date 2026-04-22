# Starry-Messenger-PlayDate
This is a collection of vibe-coded games for the Play.Date console based on personal programming projects over the years. Experience stars, mini games (some multiplayer), procedural toys, and much more.

Current single-player views include Warp Speed, Star Fall, Game of Life, Fireworks, Ant Farm, CRT TV, Wacky, Space Miner, Gif Player, Fishy Pond, RC Arena, Lava Lamp, and the shared title-preview variants of those systems.

`Wacky` is a procedural inflatable tube-man scene. Its title preview starts fully extended, then slumps into a floppy idle pose. In the live view, turning the crank pumps the body upright, while stopping the crank lets it sag and flop over again.

`Space Miner` is a new ship-combat and asteroid-mining view. The ship stays centered while the world moves around it, the crank rotates the ship, `Up` and `Down` add forward or reverse thrust with persistent space momentum, `Left` holds a laser drill, and `Right` launches or detonates a missile using the same single-active-missile rhythm as Orbital Defense.

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
