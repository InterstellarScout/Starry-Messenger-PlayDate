import "systems/controlhelp"

Tutorials = {}
local pd <const> = playdate
local gfx <const> = pd.graphics
local SAVE_KEY <const> = "starry-tutorials-v1"
local saved = pd.datastore and pd.datastore.read and pd.datastore.read(SAVE_KEY) or nil
Tutorials.seen = type(saved) == "table" and type(saved.seen) == "table" and saved.seen or {}
Tutorials.enabled = not (type(saved) == "table" and saved.enabled == false)

local function save()
    if pd.datastore and pd.datastore.write then
        pd.datastore.write({ seen = Tutorials.seen, enabled = Tutorials.enabled }, SAVE_KEY)
    end
end

local function getInstructionLines(spec)
    local lines = {}
    for _, line in ipairs((spec and spec.lines) or {}) do
        local text = tostring(line)
        -- Tutorials are a control reference, not a game-design changelog.
        -- Keep direct input instructions and omit descriptive/status prose.
        if string.find(text, ":", 1, true) ~= nil
            or string.find(text, "Tilt ", 1, true) == 1
            or string.find(text, "Hold ", 1, true) == 1
            or string.find(text, "Tap ", 1, true) == 1
            or string.find(text, "Press ", 1, true) == 1 then
            lines[#lines + 1] = text
        end
    end
    return lines
end

function Tutorials.key(viewId, modeId)
    return tostring(viewId or "unknown") .. ":" .. tostring(modeId or "default")
end

function Tutorials.shouldShow(viewId, modeId)
    return Tutorials.enabled and UIState and UIState.isShown() and Tutorials.seen[Tutorials.key(viewId, modeId)] ~= true
end

function Tutorials.markSeen(viewId, modeId)
    Tutorials.seen[Tutorials.key(viewId, modeId)] = true
    save()
end

function Tutorials.reset()
    Tutorials.seen = {}
    save()
end

function Tutorials.isEnabled()
    return Tutorials.enabled == true
end

function Tutorials.setEnabled(enabled)
    Tutorials.enabled = enabled == true
    save()
end

function Tutorials.updateScroll(scroll, viewId, modeId, crankChange, upPressed, downPressed)
    local spec = ControlHelp.getEntrySpec(viewId, modeId) or { lines = {} }
    local maxScroll = math.max(0, #getInstructionLines(spec) - 6)
    local direction = 0
    if upPressed then direction = -1 elseif downPressed then direction = 1
    elseif math.abs(crankChange or 0) >= 12 then direction = crankChange > 0 and 1 or -1 end
    return math.max(0, math.min(maxScroll, (scroll or 0) + direction))
end

function Tutorials.draw(viewId, modeId, scroll)
    local spec = ControlHelp.getEntrySpec(viewId, modeId) or { title = "How to Play", lines = { "Use the crank and D-pad to explore.", "B returns to the title menu." } }
    local lines = getInstructionLines(spec)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(18, 18, 364, 204, 9)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(18, 18, 364, 204, 9)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawTextAligned(spec.title or "How to Play", 200, 30, kTextAlignment.center)
    local y = 54
    local first = (scroll or 0) + 1
    local last = math.min(#lines, first + 5)
    for index = first, last do
        local line = lines[index]
        gfx.drawTextInRect(line, 36, y, 328, 24)
        y = y + 20
    end
    if #lines > 6 then gfx.drawTextAligned("Crank or Up/Down: scroll", 200, 176, kTextAlignment.center) end
    gfx.drawTextAligned("A: begin   B: back", 200, 196, kTextAlignment.center)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end
