# Starry Messenger

Starry Messenger is a Playdate collection of small games, visual toys, procedural effects, and experiments built around the crank, D-pad, accelerometer, and short-session play. The app opens with an animated intro screen that shows the app version in the bottom-right corner before entering the live title carousel. Use the crank or `Up`/`Down` to browse, `Left`/`Right` to change a view's mode when it has one, `A` to open the selected view, and `B` to go back.

The project is still in active development. The packaged app metadata is:

- Name: `Starry Messenger`
- Bundle ID: `com.deansheldon.starrymessenger.playdate`
- Version: `0.1.87`
- Build number: `87`

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
| Warp Speed | Main | A forward-flight starfield with normal and inverse warp styles, Star Fall Style enabled by default, plus experimental Smooth Engine, Starry Tunnel, and Different Sizes toggles in the settings menu. | Crank changes star speed. D-pad steers direction. `A` opens the warp settings menu for speed, spin, star size, and style toggles. `B` returns to the title while preserving the current speed; press `B` again on the Warp title item to reset the preview. |
| Game of Life | Main | Conway-style cellular automata with standard, endless, recorder, and review modes. | Crank scrubs generations. `Up`/`Down` changes simulation speed. `Left`/`Right` injects cells. `A` injects a larger burst or opens selected recordings in Review mode. |
| Fireworks | Main | A player-controlled fireworks launcher with automatic background bursts. | Crank or `Left`/`Right` moves the launcher. `Up`/`Down` changes firework type. Hold `A` to launch. |
| Drip Drop | Main | Ripple and leak-plugging modes that combine Drop Waves, Player Pulse, and Dropper under one title entry. | `Left`/`Right` on the title changes modes. Drop Waves/Player Pulse use crank speed and optional D-pad marker control; Dropper uses D-pad movement and `A` to plug leaks. |
| Bouncy Balls | Main | Accelerometer-driven bouncing balls with adjustable slowdown. | Tilt the Playdate to roll balls. `A` adds a ball. Crank changes slowdown so balls settle faster or keep momentum longer. |
| Wacky | Main | A crank-flung inflatable tube figure with springy limbs and pile-up behavior. | Crank forward flings the figure upward; crank backward pulls it down faster. `A` toggles rigid and pile-up modes. |
| Dimensional Split | Main | A blinking grid of black and white cells with variable subdivision. | Crank changes grid density and regenerates the pattern. `A` randomizes square colors and blink timing. |
| Space Miner | Main | Asteroid mining and ship combat with shields, missiles, enemy waves, and configurable steering. | Crank turns the ship. `Up`/`Down` thrusts. Hold `Left` to drill. Press `Right` to launch or detonate a missile. Home menu can toggle compact turn. |
| Trail Blazer | Main | A drawing and ball-drop toy with steerable movement and tilt-influenced dropped balls. | Crank steers. Hold `Up`/`Down` to move. Hold `Right` to draw. Press `Left` to drop a ball. `A` opens the Clear Screen/Hide Text menu. |
| Marble Madness | Main | A marble field with collisions, burst energy, and a movable gravity well. | D-pad moves the gravity cursor. Hold `A` to pull marbles toward it. Crank changes gravity strength. |
| Snake | Main | A forgiving snake game with crank turning, speed control, tail overlap, food, and screen wrapping. | Crank turns the snake. `Up`/`Down` changes speed. `A` resets. Running over the tail is allowed and going off-screen wraps to the opposite side. |
| Smoke Bloom | Main | Expanding smoke-like line wisps billow from a movable center cursor and push nearby symmetric wisps aside. | D-pad moves the cursor. Crank changes the billow rotation. `A` restarts the bloom from the cursor. |
| Photo Viewer | Main | A monochrome Artemis photo slideshow with fill, fit, and inverted display modes. | Crank or `Left`/`Right` changes photos. `A` toggles autoplay. `Up` hides or shows the info plaque. `Down` changes view mode. |
| Gif Player | Main | A category browser and fullscreen GIF player with frame scrubbing and optional synced audio. | Crank or D-pad chooses categories and GIFs. `A` opens, plays, or cycles playback modes. Crank scrubs frames or changes spin speed. `B` backs out one level. |
| Fishy Pond | Main | A fish-and-bubble toy with Pond, Bubbles, and Tank modes. | In Pond/Bubbles, crank moves the bubble maker, D-pad moves the fish, and hold `A` to make bubbles. In Tank, crank creates current and shake triggers panic. |
| Duck Game | Main | A chick-collecting duck game with solo center-nest, Auto Ducky, and multi-duck variants. | Normal mode uses D-pad for direction and crank for forward movement. Auto Ducky collects loose chicks until D-pad input takes over, then resumes after five seconds. Collect chicks and bank them at nests. |
| Orbital Defense | Main | A shield-defense turret game with laser fire, missiles, bot assist, and multiplayer support. | Crank or `Left`/`Right` aims. `Up`/`Down` moves around the shield. Hold `A` for laser fire. `B` launches or detonates a missile. |
| RC Arena | Main | RC car modes for puck hockey, crash racing, and block sliding. | Crank rotates the car. `A` toggles crank steering/speed control. D-pad steers and accelerates. Home menu can enable auto brake. |
| Lava Lamp | Main | A tilt-driven bubble simulation with merging, wall travel, and crank agitation. | Tilt sets the current top side. Crank agitates bubbles while moving. `Up`/`Down` changes overall bubble speed. |
| Multiplayer Duck Game | Main | Portal-enabled Duck Game for 2-4 players. | Choose player count from the Multiplayer title entry, then collect and steal chicks while banking them at player nests. |
| Multiplayer Orbital Defense | Main | Portal-enabled Orbital Defense for 2-4 turrets. | Choose player count from the Multiplayer title entry, then coordinate turret movement, laser fire, and missiles around the shared shield. |
| Crash Racing | Main | Multiplayer RC mode with crash racing and RC hockey options. | Pick the RC multiplayer mode from the title dial. Use crank and D-pad driving controls. `A` switches crank speed control. |
| CRT TV | Vibe | A procedural CRT rolling-bar effect with manual and automatic bars. | `A` toggles automatic transparent rolling bars. Crank spawns and drags a manual bar up or down; idle bars slide away. |
| Smooth Sailing | Vibe | The original Playdate-optimized black-background star tunnel inspired by Warp Speed, with unlimited crank speed, doubled star density, deliberate high-speed streaks, and center/depth-scaled star sizes. | Crank changes speed. Hold D-pad to steer the tunnel. `B` returns to the Vibes folder. |
| Spiral | Vibe | A large crank-driven geometric spiral. | Crank controls signed playback speed with reverse, near-stop, and fast-forward behavior. `B` returns to the Vibes folder. |
| Tunnel Bars | Vibe | A tunnel-like field of moving bars. | Crank controls signed playback speed. Use the Home menu `View Stats` toggle to show or hide Vibes stats. |
| Fractal Spiral | Vibe | A denser spiral pattern built for visual texture. | Crank controls signed playback speed. `B` returns to the Vibes folder. |
| Line Bloom | Vibe | A line-field effect with randomized 5-40 pixel line lengths and size-weighted spin where shorter lines rotate faster. | Crank sets and turns the line spin. `A` toggles automatic spin; idle crank input resumes auto-spin after five seconds. `B` returns to the Vibes folder. |
| Shape Pile-Up | Vibe | A code-drawn shape accumulation and motion effect. | Crank controls signed playback speed. `B` returns to the Vibes folder. |
| Loop Fall | Vibe | A black-background clean-loop Star Fall variant that preserves each star's starting position. | Crank controls signed playback speed. `B` returns to the Vibes folder. |
| Polygon Storm | Vibe | A procedural polygon field with speed-driven motion. | Crank controls signed playback speed. `B` returns to the Vibes folder. |
| Micro Rotate | Vibe | A full-screen micro-rotation pattern. | Crank controls signed playback speed. `B` returns to the Vibes folder. |
| Cloud Bubbles | Vibe | A soft procedural bubble-cloud effect. | Crank controls signed playback speed. `B` returns to the Vibes folder. |
| Bubble Pop | Vibe | A bubble popping visual toy with delayed replacement bubbles that grow in from tiny starts. | Crank controls signed playback speed. `B` returns to the Vibes folder. |

## Home Menu

The Playdate Home menu always includes `Title Menu` and `Sound`. Some views add extra toggles while active:

- `Fish Spawn Mode` for Fishy Pond.
- `Duck Turn Mode` for Duck Game.
- `RC Auto Brake` for RC Arena.
- `View Stats` while inside the Vibes folder.
- `Trailblazer Controls` for Trail Blazer.
- `Space Miner Compact Turn` for Space Miner.
