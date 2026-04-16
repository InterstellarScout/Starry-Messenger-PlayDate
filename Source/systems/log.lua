--[[
Shared application logging.

Purpose:
- centralizes Starry Messenger log filtering
- defaults runtime output to errors only
- preserves the existing Starry Messenger log prefix
]]
local LOG_LEVELS <const> = {
    debug = 1,
    info = 2,
    error = 3
}

StarryLog = StarryLog or {}
StarryLog.level = StarryLog.level or LOG_LEVELS.error

local function resolveLevel(level)
    return LOG_LEVELS[level] or LOG_LEVELS.error
end

function StarryLog.setLevel(level)
    StarryLog.level = resolveLevel(level)
end

function StarryLog.shouldLog(level)
    return resolveLevel(level) >= (StarryLog.level or LOG_LEVELS.error)
end

function StarryLog.write(level, message, ...)
    if not StarryLog.shouldLog(level) then
        return
    end

    if select("#", ...) > 0 then
        print(string.format("[StarryMessenger] " .. tostring(message), ...))
    else
        print("[StarryMessenger] " .. tostring(message))
    end
end

function StarryLog.debug(message, ...)
    StarryLog.write("debug", message, ...)
end

function StarryLog.info(message, ...)
    StarryLog.write("info", message, ...)
end

function StarryLog.error(message, ...)
    StarryLog.write("error", message, ...)
end
