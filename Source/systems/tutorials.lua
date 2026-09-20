import "systems/controlhelp"

Tutorials = {}
local pd <const> = playdate
local gfx <const> = pd.graphics
local SAVE_KEY <const> = "starry-tutorials-v1"
local saved = pd.datastore and pd.datastore.read and pd.datastore.read(SAVE_KEY) or nil
Tutorials.seen = type(saved) == "table" and type(saved.seen) == "table" and saved.seen or {}

function Tutorials.key(viewId, modeId)
    return tostring(viewId or "unknown") .. ":" .. tostring(modeId or "default")
end

function Tutorials.shouldShow(viewId, modeId)
    return UIState and UIState.isShown() and Tutorials.seen[Tutorials.key(viewId, modeId)] ~= true
end

function Tutorials.markSeen(viewId, modeId)
    Tutorials.seen[Tutorials.key(viewId, modeId)] = true
    if pd.datastore and pd.datastore.write then
        pd.datastore.write({ seen = Tutorials.seen }, SAVE_KEY)
    end
end

function Tutorials.reset()
    Tutorials.seen = {}
    if pd.datastore and pd.datastore.write then
        pd.datastore.write({ seen = Tutorials.seen }, SAVE_KEY)
    end
end

function Tutorials.draw(viewId, modeId)
    local spec = ControlHelp.getEntrySpec(viewId, modeId) or { title = "How to Play", lines = { "Use the crank and D-pad to explore.", "B returns to the title menu." } }
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(18, 18, 364, 204, 9)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(18, 18, 364, 204, 9)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawTextAligned(spec.title or "How to Play", 200, 30, kTextAlignment.center)
    local y = 54
    for index, line in ipairs(spec.lines or {}) do
        if index > 8 then break end
        gfx.drawTextInRect(line, 36, y, 328, 24)
        y = y + 20
    end
    gfx.drawTextAligned("A or B: begin", 200, 196, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end
