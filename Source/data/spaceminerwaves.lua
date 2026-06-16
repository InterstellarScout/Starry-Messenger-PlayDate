--[[
Space Miner wave and stage manifest.

Timestamps:
- `m:ss:ff` means minutes, seconds, frames at 30 fps.
- `s:ff` means seconds, frames.
- a bare number is treated as a frame count.

Trigger types:
- `time`: alert and wave start are driven from the stage's absolute `timestamp`.
- `after_stage_clear`: the previous stage must finish, then this stage waits for `delay`
  before it begins the alert countdown.

Wave spawn entries:
- `entityType`: which ship to spawn.
- `quantity`: how many ships to create for that entry.
- `entryDegrees`: 0/360 is top, 90 is right, 180 is bottom, 270 is left.
- `target`: optional attack target. Use `"player"` or `"base"`; defaults to player.
- If quantity is greater than 1, spawns in same-frame pairs: requested degree, then
  its opposite degree. Each next pair waits `spacing` before spawning.
- `spacing`/`Spacing`: optional time between pairs. Defaults to GameConfig.spaceMiner.waveEntrySpacing.
- For `time` stages, each entry may use an absolute `timestamp` or a relative `offset`.
- For `after_stage_clear` stages, each entry should use `offset`.

Configurable wave entities today:
- `seeker`: direct pursuit enemy ship
- `escaper`: evasive enemy ship
- `striker`: strafing enemy ship that fires missiles
- `asteroid`/`astroid`: asteroid chunk; optional `asteroidStage`/`stage` selects 0-3
- `enemyMissile`/`enemy-missile`/`missile`: direct enemy missile
- `heatSeekingEnemyMissile`/`homingMissile`: enemy missile that steers toward the player

Other Space Miner entities that exist in the view but are not directly wave-spawned here:
- player missile
- explosion rings
- decor stars/shapes
]]

SpaceMinerWaveConfig = {
    settingsTimeline = {
        { timestamp = "0:00:00", miniMapEnabled = true }
    },
    communications = {
        {
            timestamp = "0:00:15",
            duration = "0:08:00",
            text = "Mission: Mine Ore.\nWarning: Reports of Base Invaders have been recorded in the System. Be on the look out for threats."
        },
        { timestamp = "0:40:00", duration = "0:01:15", text = "Communication from home base... Caller: Scout" },
        { timestamp = "0:41:15", duration = "0:01:00", text = "Accepted.. Connecting." },
        { timestamp = "0:42:15", duration = "0:01:00", text = "Success." },
        { timestamp = "0:43:15", duration = "0:01:20", text = "Hey, dude. Nice job on those asteroids." },
        { timestamp = "0:44:20", duration = "0:01:20", text = "You're really giving these shields a run for their money." },
        { timestamp = "0:45:25", duration = "0:01:20", text = "But that's why we got that upgrade last week!" },
        { timestamp = "0:46:25", duration = "0:01:30", text = "Keep on mining, but I've got some bad news..." },
        { timestamp = "0:47:25", duration = "0:01:30", text = "We got word of raiders in the neighboring system.." },
        { timestamp = "0:48:25", duration = "0:01:30", text = "They said they're coming this way." },
        { timestamp = "0:49:20", duration = "0:01:20", text = "Hopefully not foreshadowing." },
        { timestamp = "0:50:15", duration = "0:01:00", text = "Heh..." },
        { timestamp = "0:51:00", duration = "0:09:00", text = "Keep up the great work. Scout Out." },
        { timestamp = "1:40:00", duration = "0:10:00", text = "Scout: Enemies Detected Entering System. Their vectors are straight at you!" },
        { timestamp = "1:51:00", duration = "0:04:00", text = "Scout: Enemies 1000 km and closing..." },
        { timestamp = "1:56:00", duration = "0:02:00", text = "Scout: 500 km and closing fast. We're alone out here, dude. Good luck, for both of us!" },
        { timestamp = "1:59:00", duration = "0:01:00", text = "Attack Imminent!" }
    },
    entityTypes = {
        seeker = "Direct pursuit ship that accelerates straight toward the player.",
        escaper = "Evasive ship that lingers near the edge of the player view while avoiding threats.",
        striker = "Fast strafing ship that tracks the player and fires missiles.",
        asteroid = "Asteroid chunk. Optional asteroidStage/stage controls breakup stage 0-3.",
        enemyMissile = "Direct enemy missile spawned from the entry side.",
        heatSeekingEnemyMissile = "Enemy missile spawned from the entry side that steers toward the player."
    },
    stages = {
        {
            id = "mining-1",
            kind = "mining",
            label = "Mining Window",
            duration = "2:00:00"
        },
        {
            id = "seekers-1",
            kind = "wave",
            wave = 1,
            label = "Seeker Wave 1",
            trigger = {
                type = "time",
                timestamp = "2:00:00"
            },
            entries = {
                { timestamp = "2:00:00", entityType = "seeker", quantity = 2, entryDegrees = 0 },
				{ timestamp = "2:00:00", entityType = "seeker", quantity = 2, entryDegrees = 90 },
				{ timestamp = "2:00:00", entityType = "seeker", quantity = 2, entryDegrees = 180 },
				{ timestamp = "2:00:00", entityType = "seeker", quantity = 2, entryDegrees = 270 },
				{ timestamp = "2:20:00", entityType = "seeker", quantity = 2, entryDegrees = 0 },
				{ timestamp = "2:20:00", entityType = "seeker", quantity = 2, entryDegrees = 90 },
				{ timestamp = "2:20:00", entityType = "seeker", quantity = 2, entryDegrees = 180 },
				{ timestamp = "2:20:00", entityType = "seeker", quantity = 2, entryDegrees = 270 },
                { timestamp = "4:10:00", entityType = "seeker", quantity = 2, entryDegrees = 45, target = "base", spacing = "0:00:06" },
                { timestamp = "4:35:00", entityType = "striker", quantity = 2, entryDegrees = 225, target = "base", spacing = "0:00:12" }
            }
        },
        {
            id = "seekers-2",
            kind = "wave",
            wave = 2,
            label = "Seeker Wave 2",
            trigger = {
                type = "after_stage_clear",
                delay = "0:00:00"
            },
            entries = {
                { offset = "0:00:00", entityType = "seeker", quantity = 4, entryDegrees = 0 },
				{ offset = "0:05:00", entityType = "seeker", quantity = 4, entryDegrees = 90 },
				{ offset = "0:05:00", entityType = "seeker", quantity = 4, entryDegrees = 0 },
				{ offset = "0:05:00", entityType = "seeker", quantity = 4, entryDegrees = 90 },
				{ offset = "0:05:00", entityType = "seeker", quantity = 4, entryDegrees = 0 },
				{ offset = "0:05:00", entityType = "seeker", quantity = 4, entryDegrees = 90 }
            }
        },
        {
            id = "seekers-3",
            kind = "wave",
            wave = 3,
            label = "Seeker Wave 3",
            trigger = {
                type = "after_stage_clear",
                delay = "0:00:00"
            },
            entries = {
                { offset = "0:00:00", entityType = "seeker", quantity = 16, entryDegrees = 0 },
				{ offset = "0:20:00", entityType = "seeker", quantity = 16, entryDegrees = 90 }
            }
        },
        {
            id = "mining-2",
            kind = "mining",
            label = "Mining Break",
            duration = "2:00:00"
        },
        {
            id = "escapers-1",
            kind = "wave",
            wave = 4,
            label = "Escaper Wave 1",
            trigger = {
                type = "after_stage_clear",
                delay = "0:00:00"
            },
            entries = {
                { offset = "0:00:00", entityType = "escaper", quantity = 2, entryDegrees = 0 }
            }
        },
        {
            id = "escapers-2",
            kind = "wave",
            wave = 5,
            label = "Escaper Wave 2",
            trigger = {
                type = "after_stage_clear",
                delay = "0:00:00"
            },
            entries = {
                { offset = "0:00:00", entityType = "escaper", quantity = 4, entryDegrees = 0 }
            }
        },
        {
            id = "strikers",
            kind = "wave",
            wave = 6,
            label = "Striker Assault",
            trigger = {
                type = "after_stage_clear",
                delay = "0:00:00"
            },
            entries = {
                { offset = "0:00:00", entityType = "striker", quantity = 3, entryDegrees = 0 }
            }
        }
    }
}
