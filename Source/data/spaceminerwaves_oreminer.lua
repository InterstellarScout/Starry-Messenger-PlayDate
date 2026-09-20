--[=[
Space Miner ore mining mode wave configuration.

This config is intentionally focused:
- One-time intro communication-block
- Repeating mining sessions (no enemy waves)
- Optional short status comms for ore mode
]=]

SpaceMinerOreMinerWaveConfig = {
    -- settingsTimeline: active-mode-only toggles for ore-miner sequence.
    settingsTimeline = {
        -- timestamp: absolute stage time when minimap visibility is set.
        -- miniMapEnabled: passed into the scheduler and read by render/radar systems.
        { timestamp = "0:00:00", miniMapEnabled = true }
    },
    -- communications: dedicated ore-mode comms that run independent of stage progression.
    communications = {
        {
            -- timestamp: absolute time for starting this optional intro comm.
            -- duration: how many frames/seconds this text remains visible.
            -- text: short HUD communication body.
            timestamp = "0:00:12",
            duration = "0:00:08",
            text = "Scout: The new Space Compression Matrix (SCM) can be upgraded with the neural accelerator node to expend jumping speeds. We'll soon reach Andromedia in one jump. All we need is a few thousand tons of ore to refine for that missing 2 oz of crystalline Yellow Crystal Gem shards."
        }
    },
    -- stages: ore mode keeps only tutorial + mining sessions as requested.
    stages = {
        {
            -- id: unique stage key used in progression and save-state transitions.
            id = "ore-intro",
            -- kind: tutorial mode; blocks until required button inputs are acknowledged.
            kind = "communication-block",
            -- label: friendly UI label for this stage.
            label = "Ore Mining Tutorial",
            -- entries: required-button checkpoints that gate advancement.
            entries = {
                {
                    -- required-button: required input to close this intro step.
                    ["required-button"] = "A",
                    text = "Welcome, pilot. Your mission is to mine ore in endless runs."
                },
                {
                    -- required-button: required input to close this intro step.
                    ["required-button"] = "A",
                    text = "Use Left/Right to fire mining laser and missiles."
                },
                {
                    -- required-button: required input to close this intro step.
                    ["required-button"] = "A",
                    text = "Scout: Dock at the base after each run to unload ore and upgrade later."
                },
                {
                    -- required-button: required input to close this intro step.
                    ["required-button"] = "A",
                    text = "Scout: The SCM side quest is simple - collect ore until the portal generator has enough fuel."
                }
            }
        },
        {
            -- id: side quest objective stage for SCM upgrades.
            id = "ore-objective-scm",
            -- kind: objective stage that completes once the ore quota is met.
            kind = "objective",
            -- label: friendly UI label for the ore objective.
            label = "SCM Ore Objective",
            -- continueAfterCompleted: keep the timeline flowing once the entries are done.
            continueAfterCompleted = true,
            -- objective: completion conditions that can end the stage.
            objective = {
                ore = 300
            },
            -- entries: optional scout reminder while the objective is active.
            entries = {
                {
                    -- offset: start immediately once this stage becomes active.
                    -- duration: short reminder while ore is being collected.
                    -- text: quest reminder tied to the new objective.
                    offset = "0:00:00",
                    duration = "0:00:08",
                    text = "Scout: Keep mining. The portal generator upgrade needs that ore."
                }
            }
        },
        {
            -- id: first mining loop block in ore mode.
            id = "ore-mining-session-1",
            -- kind: mining-only session with no enemy spawn entries.
            kind = "mining",
            -- label: session title.
            label = "Mining Session 1",
            -- duration: session length in stage timeline syntax.
            duration = "5:00:00",
            -- entries: optional messages shown inside this mining phase.
            entries = {
                {
                    -- offset: seconds offset from session start.
                    -- duration: per-message visibility window.
                    -- text: scout cue for ore loop pacing.
                    offset = "0:00:00",
                    duration = "0:00:08",
                    text = "Scout: Ore stream clear. Mine at your pace."
                }
            }
        },
        {
            -- id: second mining loop block in ore mode.
            id = "ore-mining-session-2",
            -- kind: second continuous mining session.
            kind = "mining",
            -- label: session title.
            label = "Mining Session 2",
            -- duration: session length in stage timeline syntax.
            duration = "5:00:00",
            -- entries: optional comms that keep context during long loops.
            entries = {
                {
                    -- offset: seconds offset from session start.
                    -- duration: message visibility window.
                    -- text: safety-first mining reminder for players.
                    offset = "0:00:00",
                    duration = "0:00:08",
                    text = "Scout: Stay safe. Keep moving and mine more ore."
                }
            }
        }
    }
}
