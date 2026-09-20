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

function Tutorials.updateScroll(scroll, viewId, modeId, crankChange, upPressed, downPressed)
    local spec = ControlHelp.getEntrySpec(viewId, modeId) or { lines = {} }
    local maxScroll = math.max(0, #(spec.lines or {}) - 7)
    local direction = 0
    if upPressed then direction = -1 elseif downPressed then direction = 1
    elseif math.abs(crankChange or 0) >= 12 then direction = crankChange > 0 and 1 or -1 end
    return math.max(0, math.min(maxScroll, (scroll or 0) + direction))
end

function Tutorials.draw(viewId, modeId, scroll)
    local spec = ControlHelp.getEntrySpec(viewId, modeId) or { title = "How to Play", lines = { "Use the crank and D-pad to explore.", "B returns to the title menu." } }
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(18, 18, 364, 204, 9)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(18, 18, 364, 204, 9)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawTextAligned(spec.title or "How to Play", 200, 30, kTextAlignment.center)
    local y = 54
    local first = (scroll or 0) + 1
    local last = math.min(#(spec.lines or {}), first + 6)
    for index = first, last do
        local line = spec.lines[index]
        gfx.drawTextInRect(line, 36, y, 328, 24)
        y = y + 20
    end
    if #(spec.lines or {}) > 7 then gfx.drawTextAligned("Crank or Up/Down: scroll", 200, 176, kTextAlignment.center) end
    gfx.drawTextAligned("A: begin   B: back", 200, 196, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end
