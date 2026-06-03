# On-Screen Text Worksheet

Use the final column to specify how each view's live on-screen text should work.

## Shared Text Infrastructure

| Area | Current Behavior | Desired Behavior |
| --- | --- | --- |
| Title-menu help band | Uses the shared `ControlHelp` catalog and shows one contextual instruction line at the bottom of the title menu. | |
| Global live controls overlay | `ControlHelp.drawOverlay()` exists, but it is not currently called by live views. | |
| Home-menu controls toggle | The older global `Show Controls` toggle is not currently exposed. | |
| Live HUD layout | Most view-specific HUDs use the top-left area, but spacing and visibility rules are not standardized. | |
| Timed prompts and modal overlays | Implemented independently by each view. | |

## View Text Audit

| View | Current Live Text | Pop-Up Screens Or Overlays | Desired On-Screen Text Behavior |
| --- | --- | --- | --- |
| Warp Speed | Speed and rotation values. | `A` opens the Warp Settings menu. | |
| Star Fall | No persistent HUD. | None. | |
| Game of Life | `REC` counter in recording mode. Review Life shows browser and scrub instructions. | Loading screen before live play. Review Life browser and missing-playback messages. | |
| Fireworks | Title, active shells, sparks, and selected firework type. | None. | |
| CRT TV | No persistent HUD. | None. | |
| Vibes | Optional effect and speed HUD through the Home-menu `View Stats` toggle. | None. | |
| Puddle Drops | Mode, speed, and wave count. | None. | |
| Dropper | Run score, total depth, best score, leaks, and speed. | None. | |
| Bouncy Balls | Ball count, slowdown, and control instructions. | Five-second entry prompt, dismissible with `A`. | |
| Wacky | No HUD. Occasional `!` expression. | None. | |
| Dimensional Split | No persistent HUD. | None. | |
| Space Miner | Stage, ore, score, shield, hull, velocity, and controls. | Flashing `ALERT` before enemy waves. Destroyed-ship message. | |
| Trail Blazer | Mode, speed, trail state, and ball count. Text can be hidden. | Startup controls hint. `A` opens Flow Settings. | |
| Marble Madness | Marble count, gravity strength, and controls. | None. | |
| Photo Viewer | Optional info plaque with photo details, image index, and controls. | Empty-library and temporary status messages. | |
| GIF Player | Category, item, playback, frame, audio, and control text. | Category browser, GIF browser, and empty-library message. | |
| Fishy Pond | Mode, current or currency, fish count, and bubble count. | None. | |
| RC Arena | Mode, speed, crank mode, and mode-specific score. | None. | |
| Orbital Defense | Title, health, tier, scores, and controls. | Multiplayer lobby and waiting-for-host screen. | |
| Lava Lamp | No persistent HUD. | None. | |
| Duck Game | Current chicks, lifetime total, and mode objective. | Five-second tilt hint, winner overlay, and multiplayer lobby. | |

## Standardization Questions

| Question | Decision |
| --- | --- |
| Should live statistics use one shared top-left HUD style? | |
| Should control directions appear by default, only on entry, or only when toggled from the Home menu? | |
| Should all timed prompts use one shared modal-card style? | |
| Should all live text be hideable through one global Home-menu toggle? | |
| Should view-specific toggles such as `View Stats` and `Trailblazer Controls` remain separate? | |
| Should warnings such as Space Miner `ALERT` remain always visible even when HUD text is hidden? | |
| Should multiplayer lobbies and error messages ignore HUD visibility settings? | |
