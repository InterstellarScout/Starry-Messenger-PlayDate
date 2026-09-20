--[[
Space Miner wave and stage manifest.

This file is the editable chronological timeline for Story Mode: timed settings,
communications, wave stages, and entity wave descriptions. The main Space Miner
config remains in Source/data/spaceminerconfig.lua for tuning, purchases, and UI text.

Timestamps:
- `m:ss:ff` means minutes, seconds, frames at 30 fps.
- `s:ff` means seconds, frames.
- a bare number is treated as a frame count.

Trigger types:
- `time`: alert and wave start are driven from the stage's `offset`.
- `after_stage_clear`: the previous stage must finish, then this stage waits for `delay`
  before it begins the alert countdown.
- `communication-block`: blocking tutorial/story stage. Each entry shows until its
  `requiredButton`/`required-button` is pressed, then the next entry appears.
- `objective`: a stage that can end from gameplay progress checks such as collected ore
  or destroyed enemies. Use `objective.ore`, `objective.enemies`, and
  `continueAfterCompleted` for side quests that should wait for existing entries to finish.

Communication-block example:
{
    id = "communication-block-1",
    kind = "communication-block",
    label = "Player Introduction Tutorial",
    entries = {
        {
            ["required-button"] = "A",
            ["disable-button"] = { "B", "Up", "Down", "Left", "Right" },
            text = "Welcome, dude. I'm glad you showed up to help. As a reminder, use \"A\" to open your ship's menu."
        },
        {
            ["required-button"] = "A",
            ["disable-button"] = { "B", "Up", "Down", "Left", "Right" },
            text = "Use the crank to turn the ship, and press Up and Down on the D pad to move back and forth."
        }
    }
}

Wave spawn entries:
- `entityType`: which ship to spawn.
- `quantity`: how many ships to create for that entry.
- `entryDegrees`: 0/360 is top, 90 is right, 180 is bottom, 270 is left.
- `target`: optional attack target. Use `"player"` or `"base"`; defaults to player.
- If quantity is greater than 1, spawns in same-frame pairs: requested degree, then
  its opposite degree. Each next pair waits `spacing` before spawning.
- `spacing`/`Spacing`: optional time between pairs. Defaults to GameConfig.spaceMiner.waveEntrySpacing.
- For `time` stages, each entry should use a relative `offset`.
- For `after_stage_clear` stages, each entry should use `offset`.

Configurable wave entities today:
- `seeker`: direct pursuit enemy ship
- `escaper`: evasive enemy ship
- `striker`: strafing enemy ship that fires missiles
- `laserEnemy`: orbiting laser ship that keeps beam distance around its target
- `asteroid`/`astroid`: asteroid chunk; optional `asteroidStage`/`stage` selects 0-3
- `enemyMissile`/`enemy-missile`/`missile`: direct enemy missile
- `heatSeekingEnemyMissile`/`homingMissile`: enemy missile that steers toward the player

Other Space Miner entities that exist in the view but are not directly wave-spawned here:
- player missile
- explosion rings
- decor stars/shapes

Stage actions:
- `action = "Ship Mode", mode = "the-watcher"` swaps the Home Base entity mode.
- `action = "Move entity", destination = "100,100", speed = "jump"` moves an entity on the kilometer grid.
- `entity`: optional target name; omitted defaults to Home Base. Current built-ins are `"home-base"`/`"base"` and `"player"`.
- `destination`: grid coordinate string, where Home Base starts at `"0,0"` and units match the in-game km distance display.
- `speed`: `"jump"` teleports, `"slow"` uses player max travel speed, `"medium"` is 2x, and `"fast"` is 4x.
]]

SpaceMinerWaveConfig = {
    -- settingsTimeline: time-indexed game mode toggles loaded by stage scheduler.
    settingsTimeline = {
        -- offset: relative time this setting change enters the active schedule.
        -- miniMapEnabled: runtime toggle consumed by render + radar code for minimap visibility.
        { offset = "0:00:00", miniMapEnabled = true }
    },
    -- entityTypes: descriptive map for wave editor/UI readability; keys are looked up by spawn entries.
    entityTypes = {
        -- seeker: used for `entityType = "seeker"` in wave entries.
        seeker = "Direct pursuit ship that accelerates straight toward the player.",
        -- escaper: used for `entityType = "escaper"` in wave entries.
        escaper = "Evasive ship that lingers near the edge of the player view while avoiding threats.",
        -- striker: used for `entityType = "striker"` in wave entries.
        striker = "Fast strafing ship that tracks the player and fires missiles.",
        -- laserEnemy: used for `entityType = "laserEnemy"` in wave entries.
        laserEnemy = "Orbiting laser ship that keeps a fixed beam-distance around its target and fires from a rotating matrix.",
        -- asteroid: used for `entityType = "asteroid"` in wave entries.
        asteroid = "Asteroid chunk. Optional asteroidStage/stage controls breakup stage 0-3.",
        -- enemyMissile: used for missile entities spawned directly from entry list.
        enemyMissile = "Direct enemy missile spawned from the entry side.",
        -- heatSeekingEnemyMissile: used for homing enemy missile entries.
        heatSeekingEnemyMissile = "Enemy missile spawned from the entry side that steers toward the player."
    },
    -- stages: ordered game timeline. updateStage() consumes `kind`, `trigger`, `entries`, and `duration`.
    stages = {
        {
            -- id: unique key for this stage used in save-state and debug logging.
            id = "communication-block-1",
            -- kind: scheduler selector (`communication-block`, `mining`, `wave`, or `objective`).
            kind = "communication-block",
            -- label: UI label for diagnostics and menu/transition displays.
            label = "Player Introduction Tutorial",
            -- entries: ordered communication blocks and optional inline messages/spawn rows.
            entries = {
                {
                    -- required-button: button identifier required to close this communication step.
                    ["required-button"] = "A",
                    -- disable-button: buttons suspended while this step is visible.
                    ["disable-button"] = { "B", "Up", "Down", "Left", "Right" },
                    text = [[Welcome $Name.\nWelcome, dude. I'm glad you showed up to help. As a reminder, use "A" to open your ship's menu.]]
                },
                {
                    -- required-button: button identifier required to close this communication step.
                    ["required-button"] = "A",
                    -- disable-button: buttons suspended while this step is visible.
                    ["disable-button"] = { "B", "Up", "Down", "Left", "Right" },
                    text = "Use the crank to turn the ship, and press Up and Down on the D pad to move back and forth."
                },
                {
                    -- required-button: button identifier required to close this communication step.
                    ["required-button"] = "A",
                    -- disable-button: buttons suspended while this step is visible.
                    ["disable-button"] = { "B", "Up", "Down", "Left", "Right" },
                    text = "Finally, you use left and right on the D pad to use the mining laser and missile systems."
                },
                {
                    -- required-button: button identifier required to close this communication step.
                    ["required-button"] = "A",
                    -- disable-button: buttons suspended while this step is visible.
                    ["disable-button"] = { "B", "Up", "Down", "Left", "Right" },
                    text = "So uhh... Yeah, go mine some stuff."
                },
                {
                    -- required-button: button identifier required to close this communication step.
                    ["required-button"] = "A",
                    -- disable-button: buttons suspended while this step is visible.
                    ["disable-button"] = { "B", "Up", "Down", "Left", "Right" },
                    text = "Mission: Mine Ore.\nWarning: Reports of Base Invaders have been recorded in the System. Be on the look out for threats."
                }
            }
        },
        {
            -- id: stage key for first timed mining window.
            id = "mining-1",
            -- kind: sets mining gameplay and uses duration countdown.
            kind = "mining",
            -- label: UI label shown for this stage.
            label = "Mining Window",
            -- duration: mining stage length in stage time format.
            duration = "2:00:00",
			entries = {
                -- offset: relative stage time where this comm message appears.
                -- duration: how long the communication stays active.
                -- text: mission text shown while no enemies are required for this stage.
				{ offset = "0:40:00", duration = "0:02:00", text = "Communication from home base... Caller: Scout" },
				{ offset = "0:42:00", duration = "0:02:00", text = "Accepted.. Connecting." },
				{ offset = "0:44:00", duration = "0:02:00", text = "Success." },
				{ offset = "0:46:00", duration = "0:02:00", text = "Scout: Hey, dude. Nice job on those asteroids." },
				{ offset = "0:48:00", duration = "0:02:00", text = "Scout: You're really giving these shields a run for their money." },
				{ offset = "0:50:00", duration = "0:02:00", text = "Scout: Scout: But that's why we got that upgrade last week!" },
				{ offset = "0:52:00", duration = "0:02:00", text = "Scout: Keep on mining, but I've got some bad news..." },
				{ offset = "0:54:00", duration = "0:02:00", text = "Scout: We got word of raiders in the neighboring system.." },
				{ offset = "0:56:00", duration = "0:02:00", text = "Scout: They said they're coming this way." },
				{ offset = "0:58:00", duration = "0:02:00", text = "Scout: Hopefully not foreshadowing." },
				{ offset = "1:00:00", duration = "0:02:00", text = "Scout: Heh..." },
				{ offset = "1:02:00", duration = "0:02:00", text = "Scout: Keep up the great work. Scout Out." },
				{ offset = "1:40:00", duration = "0:05:00", text = "Scout: Enemies Detected Entering System. Their vectors are straight at you!" },
				{ offset = "1:50:00", duration = "0:02:00", text = "Scout: Enemies 1000 km and closing..." },
				{ offset = "1:53:00", duration = "0:05:00", text = "Scout: 500 km and closing fast. We're alone out here, dude. Good luck, for both of us!" },
				{ offset = "1:59:00", duration = "0:01:00", text = "Attack Imminent! Kick their ASS!!" }
			}
        },
        {
            -- id: first seeker wave after initial mining stage.
            id = "seekers-1",
            -- kind: wave scheduler branch with spawn tables.
            kind = "wave",
            -- wave: user-visible wave number for scoring/logging counters.
            wave = 1,
            -- label: UI stage label.
            label = "Seeker Wave 1",
            -- trigger: controls when this stage starts; type can be `time` or `after_stage_clear`.
            trigger = {
                -- type: schedule mode (time-based start).
                -- offset: stage-start time for `type = "time"`.
                type = "time",
                offset = "0:00:00"
            },
            -- entries: spawn and communication entries; keys here are parsed as time or offset based.
            entries = {
                -- offset: relative stage clock for this spawn entry when `type = "time"`.
                -- entityType: lookup into `entityTypes` and spawn switch.
                -- quantity: number of units to spawn.
                -- entryDegrees: spawn heading in degrees.
                -- spacing: delay between pair groups.
                { offset = "2:00:00", entityType = "seeker", quantity = 2, entryDegrees = 0, spacing = "0:00:01" },
				{ offset = "2:00:00", entityType = "seeker", quantity = 2, entryDegrees = 90, spacing = "0:00:01" },
				{ offset = "2:00:00", entityType = "seeker", quantity = 2, entryDegrees = 180, spacing = "0:00:01" },
				{ offset = "2:00:00", entityType = "seeker", quantity = 2, entryDegrees = 270, spacing = "0:00:01" },
				{ offset = "2:15:00", duration = "0:03:00", text = "Scout: Another wave incoming!" },
				{ offset = "2:20:00", entityType = "seeker", quantity = 2, entryDegrees = 0, spacing = "0:00:01" },
				{ offset = "2:20:00", entityType = "seeker", quantity = 2, entryDegrees = 90, spacing = "0:00:01" },
				{ offset = "2:20:00", entityType = "seeker", quantity = 2, entryDegrees = 180, spacing = "0:00:01" },
				{ offset = "2:20:00", entityType = "seeker", quantity = 2, entryDegrees = 270, spacing = "0:00:01" },
				{ offset = "2:15:00", duration = "0:03:00", text = "Scout: Hold up.. a squad of them are veering off..." },
				{ offset = "2:19:00", duration = "0:02:00", text = "Scout: Uhhhhhhhh..." },
				{ offset = "2:21:00", duration = "0:03:00", text = "Scout: They're coming at ME!" },
                { offset = "2:25:00", entityType = "seeker", quantity = 2, entryDegrees = 45, target = "base", spacing = "0:00:06" },
				{ offset = "2:25:00", duration = "0:03:00", text = "Scout: Help!" },
                { offset = "2:25:00", entityType = "striker", quantity = 2, entryDegrees = 225, target = "base", spacing = "0:00:12" }
            }
        },
        {
            -- id: timed/mini mining break used to let players recover.
            id = "mining-2",
            kind = "mining",
            label = "Mining Break",
            duration = "2:00:00",
			entries = {
                { offset = "0:00:00", action = "Ship Mode", mode = "the-watcher" },
                -- offset: seconds offset relative to stage start when this mining comm should run.
                -- duration: comm visibility window for each message.
                -- text: support text during mining-only stage.
				{ offset = "0:00:00", duration = "0:02:00", text = "Scout: You did it!" },
				{ offset = "0:02:00", duration = "0:02:00", text = "Scout: Great Job!" },
				{ offset = "0:04:00", duration = "0:02:00", text = "Scout: Now, keep looking for that artifac-" },
				{ offset = "0:06:00", duration = "0:02:00", text = "Scout: Mining. Keep mining." },
				{ offset = "0:08:00", duration = "0:02:00", text = "Scout: Okay, i'll be here if you need anything." }
            }
        },
        {
            -- id: chain of seekers after mining-2.
            id = "seekers-2",
            kind = "wave",
            -- wave: sequence counter used by wave HUD and stage completion checks.
            wave = 2,
            label = "Seeker Wave 2",
            trigger = {
                -- type: start only after previous stage clears.
                -- delay: delay between stage clear and this stage start.
                type = "after_stage_clear",
                delay = "0:00:00"
            },
            -- entries: offset + optional target fields for each spawned batch.
            entries = {
                { offset = "0:00:00", entityType = "seeker", quantity = 4, entryDegrees = 0, spacing = "0:00:01" },
				{ offset = "0:05:00", entityType = "seeker", quantity = 4, entryDegrees = 90, spacing = "0:00:01" },
				{ offset = "0:05:00", entityType = "seeker", quantity = 4, entryDegrees = 0, spacing = "0:00:01" },
				{ offset = "0:05:00", entityType = "seeker", quantity = 4, entryDegrees = 90, spacing = "0:00:01" },
				{ offset = "0:05:00", entityType = "seeker", quantity = 4, entryDegrees = 0, spacing = "0:00:01" },
				{ offset = "0:05:00", entityType = "seeker", quantity = 4, entryDegrees = 90, spacing = "0:00:01" },
				{ offset = "0:10:00", entityType = "escaper", quantity = 2, entryDegrees = 0 },
				{ offset = "0:10:00", entityType = "escaper", quantity = 2, entryDegrees = 180 },
				{ offset = "0:15:00", entityType = "striker", quantity = 2, entryDegrees = 225, target = "base", spacing = "0:00:05" },
				{ offset = "0:15:00", entityType = "striker", quantity = 2, entryDegrees = 225, target = "base", spacing = "0:00:05" }
            }
        },
        {
            -- id: late game seeker swarm challenge.
            id = "seekers-3",
            kind = "wave",
            wave = 3,
            label = "Seeker Wave 3",
            trigger = {
                -- type: chained stage progression.
                -- delay: no delay after prior stage clear.
                type = "after_stage_clear",
                delay = "0:00:00"
            },
            entries = {
                { offset = "0:00:00", entityType = "seeker", quantity = 16, entryDegrees = 0 },
				{ offset = "0:20:00", entityType = "seeker", quantity = 16, entryDegrees = 90 }
            }
        },
        {
            -- id: quiet mining window before enemy mix continues.
            id = "mining-3",
            kind = "mining",
            label = "Mining Break",
            -- duration: mining window length before next wave trigger.
            duration = "2:00:00",
            entries = {
                { offset = "0:00:00", action = "Ship Mode", mode = "home-base" }
            }
        },
        {
            -- id: first escaper-only wave.
            id = "escapers-1",
            kind = "wave",
            -- wave: wave counter for progression metrics.
            wave = 4,
            label = "Escaper Wave 1",
            trigger = {
                type = "after_stage_clear",
                delay = "0:00:00"
            },
            -- entries: `offset` + `entityType` + `quantity` + `entryDegrees`.
            entries = {
                { offset = "0:00:00", entityType = "escaper", quantity = 2, entryDegrees = 0 }
            }
        },
        {
            -- id: second escaper-only wave.
            id = "escapers-2",
            kind = "wave",
            wave = 5,
            label = "Escaper Wave 2",
            trigger = {
                type = "after_stage_clear",
                delay = "0:00:00"
            },
            -- entries: wave batch definition for escaper spawns.
            entries = {
                { offset = "0:00:00", entityType = "escaper", quantity = 4, entryDegrees = 0 }
            }
        },
        {
            -- id: final striker encounter in the default story timeline.
            id = "strikers",
            kind = "wave",
            wave = 6,
            label = "Striker Assault",
            trigger = {
                type = "after_stage_clear",
                delay = "0:00:00"
            },
            -- entries: striker wave spawn rows; `target` omitted defaults to player in current wave parser.
            entries = {
                { offset = "0:00:00", entityType = "striker", quantity = 3, entryDegrees = 0 }
            }
        },
        {
            -- id: sensor briefing that sets up the laser-matrix enemy reveal and grants the ship's self-defense turret.
            id = "laser-matrix-briefing",
            kind = "mining",
            label = "Sensor Briefing",
            duration = "1:00:00",
            enableShipAutoDefense = true,
            entries = {
                { offset = "0:00:00", duration = "0:06:00", text = "Scout: Uh... sensors just coughed up a new contact pattern, and it is not pretty." },
                { offset = "0:06:00", duration = "0:06:00", text = "Scout: Those hulls are stacked like chrome vertebrae with a grudge." },
                { offset = "0:12:00", duration = "0:06:00", text = "Scout: I'm seeing a rotating laser matrix in the middle. It looks like a cathedral built by a very angry toaster." },
                { offset = "0:18:00", duration = "0:06:00", text = "Scout: Their emitters are tuning like a choir of razor blades. Great. Space opera, but mean." },
                { offset = "0:24:00", duration = "0:06:00", text = "Scout: They are not charging straight in. They are orbiting. That is somehow both smarter and more annoying." },
                { offset = "0:30:00", duration = "0:06:00", text = "Scout: Half of them are sniffing around you, half are drifting toward the base. Real considerate villains." },
                { offset = "0:36:00", duration = "0:06:00", text = "Scout: Their laser lattice is building a geometric crime against physics." },
                { offset = "0:42:00", duration = "0:06:00", text = "Scout: If that beam matrix locks, it's going to paint the sector in regret." },
                { offset = "0:48:00", duration = "0:06:00", text = "Scout: Oh! My ship's torrents are back online. I'm enabling the auto turret now, so maybe I can stop nagging you for five seconds." },
                { offset = "0:54:00", duration = "0:06:00", text = "Scout: There they are. Keep your head on a swivel. Laser matrix assault, incoming." }
            }
        },
        {
            -- id: laser-matrix assault wave that follows the briefing once the comm stream ends.
            id = "laser-matrix-assault",
            kind = "wave",
            wave = 7,
            label = "Laser Matrix Assault",
            trigger = {
                type = "after_stage_clear",
                delay = "0:00:00"
            },
            entries = {
                { offset = "0:00:00", entityType = "laserEnemy", quantity = 2, entryDegrees = 0 },
                { offset = "0:00:00", entityType = "laserEnemy", quantity = 2, entryDegrees = 90 },
                { offset = "0:00:00", entityType = "laserEnemy", quantity = 2, entryDegrees = 180, target = "base" },
                { offset = "0:00:00", entityType = "laserEnemy", quantity = 2, entryDegrees = 270, target = "base" }
            }
        }
    }
}
