# Starry Messenger

Starry Messenger is a Playdate collection of small games, visual toys, procedural effects, and experiments built around the crank, D-pad, accelerometer, and short-session play. The app opens with an animated intro screen that shows the app version in the bottom-right corner before entering the live title carousel. Use the crank or `Up`/`Down` to browse, `Left`/`Right` to change a view's mode when it has one, `A` to open the selected view, and `B` to go back.

The project is still in active development. The packaged app metadata is:

- Name: `Starry Messenger`
- Bundle ID: `com.deansheldon.starrymessenger.playdate`
- Version: `0.1.98`
- Build number: `98`

## Install

This repository expects the Playdate SDK to be installed one directory above this workspace, or available through `PLAYDATE_SDK_PATH`. The project-local script resolves the compiler, simulator, and device tools automatically.

Build the app:

```powershell
.\build.ps1
```

Run in the Playdate Simulator:

```powershell
.\build.ps1 -RunSimulator
```

Install and launch on a connected, unlocked Playdate over USB:

```powershell
.\build.ps1 -InstallDevice
```

Install through Data Disk mode as a fallback:

```powershell
.\build.ps1 -InstallDataDisk
```

Retry a data-disk install without rebuilding when the current `StarryMessenger.pdx` bundle is already built:

```powershell
.\build.ps1 -SkipBuild -InstallDataDisk
```

The supported generated app bundle is `StarryMessenger.pdx` in this project root. Stale test bundles such as `StarryMessenger-test.pdx` are not valid launch targets.

## Mini Games And Views

| Game Name | Game Type | Description | Play Instructions |
| --- | --- | --- | --- |
| Star Fall | Main | A falling starfield toy with normal and inverted modes. | Crank changes fall speed. D-pad steers the field. `A` opens the view and toggles speed/spin control in-game. `B` returns to the title. |
| Warp Speed | Main | A forward-flight starfield with normal and inverse warp styles, plus Smooth Engine, Starry Tunnel, and Different Sizes toggles in the settings menu. Smooth Engine and Starry Tunnel route through the Smooth Sailing-style depth star model. | Crank changes star speed. D-pad steers direction. In Starry Tunnel, D-pad bends the tunnel opposite the pressed direction and returns to neutral on release; hold D-pad and press `A` to lock or unlock that direction. `A` otherwise opens the warp settings menu. `B` returns to the title while preserving the current speed; press `B` again on the Warp title item to reset the preview. |
| Starry Top | Main | A stripped-down star spinner using a persistent Warp Speed-style field that rotates around the screen center. | Crank controls center rotation speed with the stepped scale around zero and no cap past `3` or `-3`. Tap `Left`/`Right` to decrease or increase the separate warp speed. Hold `Up`/`Down` to move forward or backward through the rotating stars at that warp speed. Press `A` to lock or unlock controls while the current motion continues. |
| Game of Life | Main | Conway-style cellular automata with standard, endless, recorder, and review modes. | Crank scrubs generations. `Up`/`Down` changes simulation speed. `Left`/`Right` injects cells. `A` injects a larger burst or opens selected recordings in Review mode. |
| Fireworks | Main | A player-controlled fireworks launcher with automatic background bursts and shooting-star bursts. | Crank or `Left`/`Right` moves the launcher. Hold `Up` to launch. Press `Down` for a shooting star that arcs through the upper sky and bursts. `A` changes firework type, including the default Auto mode, and the launcher shape changes with the selected type. Sparks are capped at 150. |
| Drip Drop | Main | Drop Waves and Inverse Drops ripple modes with queued debris and a player dropper. | `Left`/`Right` on the title changes modes. Auto drops queue every 0.5-5 seconds and stop at 8 so one player drop stays reserved. D-pad moves the player dropper, and `A` adds a player drip when the pool has space. |
| Bouncy Balls | Main | Accelerometer-driven bouncing balls with adjustable slowdown. | Tilt the Playdate to roll balls. `A` adds a ball. Crank changes slowdown so balls settle faster or keep momentum longer. |
| Wacky | Main | A crank-flung inflatable tube figure with Classic and Crazy Family modes. Crazy Family adds full-joint half-size girl and 3/4-size mom Wackys that fling, pull down, and drop like the main figure; the girl has reattaching bows and mom has jointed upper-head hair. Rapidly alternating the crank five times starts party mode with a lowering disco ball, spinning ray lights, and a white/light-grey flashing background. Spinning upward continuously for over five seconds starts Reach for the Stars mode, darkening the background by 30% and adding sparkling stars. Cranking downward continuously for over five seconds latches Worm Mode, flipping the horizon and sliding it near the top so the figures dangle from it; only five seconds of upward crank returns the horizon to normal and re-enables Reach for the Stars. Party and Reach for the Stars turn off after crank bouncing stops for over one second. | The title preview auto-bumps forward every half second. `Left`/`Right` changes Wacky modes. In live play, crank forward flings the figures upward; crank backward pulls them down faster. `A` toggles rigid and pile-up modes. Optional party audio is reserved at `Source/audio/wacky/partytrack.mp3`. |
| Space Miner | Main | Asteroid mining and ship combat with shields, missiles, enemy waves, a timed instruction popup, and a white-only bottom dashboard. | Crank turns the ship. `Up`/`Down` thrusts. Hold `Left` to drill. Press `Right` to launch or detonate a missile. The dashboard always shows Shields, ore as `O`, destroyed enemies as `E`, total score, ship indicator, and 10 hull blocks; Show UI only affects the top-left status text. Shields use a 0-100 meter where asteroid hits remove 5 and tier 1 enemy hits remove 10; once shields are empty, each collision removes 1 of 10 permanent hull blocks. When disabled, surrounding objects keep moving while the ship stops interacting; `A` restarts and `B` returns. Home menu can toggle compact turn. |
| Marble Run | Main | A drawing and ball-drop toy with steerable movement, a triangle facing pointer, and tilt-influenced dropped balls. | Marble Run opens by clearing the board and centering the player without pausing input. When Show UI is enabled, it shows a 5-second control popup that vanishes on first interaction. Crank steers. Hold `Up`/`Down` to move. Hold `Right` to draw. Press `Left` to drop a ball. `A` opens the Clear Screen/Hide Text menu. |
| Marble Madness | Main | A marble field with collisions, burst energy, and a movable gravity well. | D-pad moves the gravity cursor. Hold `A` to pull marbles toward it. Crank changes gravity strength. |
| Touching Grass | Main | A hand moves through simulated grass lines that repel around it while non-contact grass and occasional invisible wind waves share a 40-blades-per-second update budget. | D-pad moves the hand. `A` lifts or lowers the hand, and crank raises or lowers it gradually. Lifting the hand shrinks the affected grass radius; if the hand stays out of the grass for 5 seconds, it hides until input resumes. |
| Snake | Main | A forgiving snake game with Standard and Competitive modes, crank or D-pad steering, diagonal movement, food, and screen wrapping. | Crank turns when D-pad is not held. D-pad steers directly, including diagonals. Tap the direction you are already moving to bump forward. In Competitive, bumps drop food behind you when there is room, starts with 2 food, queues up to 3, and treats head-to-body collisions as losses. `A` resets. |
| Billowing Smoke / Raising Smoke | Vibes | Full-screen smoke-line effects inside the Vibes folder. Billowing Smoke expands from a movable cursor; Raising Smoke combines a random bottom source with a D-pad-controlled center source. | In Billowing, D-pad moves the cursor, crank changes billow rotation, and `A` restarts. In Raising, D-pad moves the center source, crank accelerates upward smoke motion, and `A` randomizes the bottom source. |
| Dropper | Vibes | A leak-plugging ripple game with capped active leaks and no more than 50 visible wave lines. | D-pad moves the white stone. `A` flashes outward to plug leaks. Crank changes ripple speed. |
| Photo Viewer | Main | A monochrome Artemis photo slideshow with fill, fit, and inverted display modes. | Crank or `Left`/`Right` changes photos. `A` toggles autoplay. `Up` hides or shows the info plaque. `Down` changes view mode. |
| Gif Player | Main | A category browser and fullscreen GIF player with frame scrubbing and optional synced audio. | Crank or D-pad chooses categories and GIFs. `A` opens, plays, or cycles playback modes. Crank scrubs frames or changes spin speed. `B` backs out one level. |
| Fishy Pond | Main | A fish-and-bubble toy with Pond, Bubbles, and Tank modes. | In Pond/Bubbles, crank moves the bubble maker, `Left`/`Right` moves the fish, hold `A` or `Up` to make bubbles, and press `Down` to add another fish. In Tank, crank creates current and shake triggers panic. |
| Duck Game | Main | A chick-collecting duck game with solo center-nest, Auto Ducky, and multi-duck variants. | Normal mode uses D-pad for direction and crank for forward movement. Auto Ducky collects loose chicks until D-pad input takes over, then resumes after five seconds. Collect chicks and bank them at nests. |
| Orbital Defense | Main | A shield-defense turret game with laser fire, missiles, bot assist, and multiplayer support. | Crank or `Left`/`Right` aims. `Up`/`Down` moves around the shield. Hold `A` for laser fire. `B` launches or detonates a missile. |
| RC Arena | Main | RC car modes for puck hockey, crash racing, and block sliding. | Crank rotates the car. `A` toggles crank steering/speed control. D-pad steers and accelerates. Home menu can enable auto brake. In Puck Ring, pucks that escape the ring more than 3 times respawn. |
| Lava Lamp | Main | A tilt-driven bubble simulation with merging, wall travel, and crank agitation. | Tilt sets the current top side. Crank agitates bubbles while moving. `Up`/`Down` changes overall bubble speed. |
| Multiplayer Duck Game | Main | Portal-enabled Duck Game for 2-4 players. | Choose player count from the Multiplayer title entry, then collect and steal chicks while banking them at player nests. |
| Multiplayer Orbital Defense | Main | Portal-enabled Orbital Defense for 2-4 turrets. | Choose player count from the Multiplayer title entry, then coordinate turret movement, laser fire, and missiles around the shared shield. |
| Crash Racing | Main | Multiplayer RC mode with crash racing and RC hockey options. | Pick the RC multiplayer mode from the title dial. Use crank and D-pad driving controls. `A` switches crank speed control. |
| CRT TV | Vibe | A procedural CRT rolling-bar effect with manual and automatic bars. | `A` toggles automatic transparent rolling bars. Crank spawns and drags a manual bar up or down; idle bars slide away. |
| Smooth Sailing | Vibe | The original Playdate-optimized black-background star tunnel inspired by Warp Speed, with unlimited crank speed, doubled star density, deliberate high-speed streaks, and center/depth-scaled star sizes. | Crank changes speed. Hold D-pad to steer the tunnel. `B` returns to the Vibes folder. |
| Spiral | Vibe | A large crank-driven geometric spiral. | Crank controls signed playback speed with reverse, near-stop, and fast-forward behavior. `B` returns to the Vibes folder. |
| Tunnel Bars | Vibe | A tunnel-like field of moving bars. | Crank controls signed playback speed. Use the Home menu `View Stats` toggle to show or hide Vibes stats. |
| Fractal Spiral | Vibe | A denser spiral pattern built for visual texture, with fractal arms added or removed one at a time by crank distance. | Every 45 degrees of crank adds one arm; cranking the opposite direction removes one. More arms continue to accelerate the spin. `B` returns to the Vibes folder. |
| Line Bloom | Vibe | A line-field effect with randomized 10-50 pixel line lengths and size-weighted spin where shorter lines rotate faster. | Crank sets and turns the line spin. `A` toggles automatic spin; idle crank input resumes auto-spin after five seconds. `B` returns to the Vibes folder. |
| Loop Fall | Vibe | A black-background clean-loop Star Fall variant that preserves each star's starting position. | Crank controls whole-number signed playback speed with no cap in either direction. `B` returns to the Vibes folder. |
| Polygon Storm | Vibe | A procedural polygon field with speed-driven motion. | Crank controls signed playback speed. `B` returns to the Vibes folder. |
| Micro Rotate | Vibe | A full-screen micro-rotation pattern. | Crank controls signed playback speed. `B` returns to the Vibes folder. |
| Dimensional Split | Vibe | A blinking grid of black and white cells with bounded crank subdivision. | Crank changes grid density without wrapping past the minimum or maximum size. `A` randomizes square colors and blink timing. |
| Cloud Bubbles | Vibe | A soft procedural bubble-cloud effect. | Crank controls signed playback speed. `B` returns to the Vibes folder. |
| Bubble Pop | Vibe | A bubble popping visual toy with delayed replacement bubbles, grow-in spawns, a D-pad player bubble, and pop burst animations. | Crank controls signed playback speed. D-pad moves the cursor and spawns the player bubble; after it pops, use D-pad again to create a new one. `B` returns to the Vibes folder. |

## Home Menu

The Playdate Home menu always includes `Title Menu` and `Sound`. Some views add extra toggles while active:

- `Show UI` for gameplay views with stationary HUD text, off by default.
- `Fish Spawn Mode` for Fishy Pond.
- `Duck Turn Mode` for Duck Game.
- `RC Auto Brake` for RC Arena.
- `View Stats` while inside the Vibes folder.
- `Marble Run Controls` for Marble Run.
- `Space Miner Compact Turn` for Space Miner.
