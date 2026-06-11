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
- If quantity is greater than 1, spawns alternate between the requested degree and
  its opposite degree. Example: quantity 6 at 90 degrees yields 3 at 90 and 3 at 270.
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
				{ timestamp = "2:20:00", entityType = "seeker", quantity = 2, entryDegrees = 270 }
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
