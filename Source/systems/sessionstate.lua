--[[
Simple session-state container for menu flow.

Purpose:
- tracks whether the app is in single-player or multiplayer mode
- stores the current player count and active catalog
- keeps scene transitions lightweight by centralizing shared menu state
]]
import "systems/multiplayer"

SessionState = {}
SessionState.__index = SessionState

function SessionState.new()
    local self = setmetatable({}, SessionState)
    self.playerCount = 1
    self.catalog = "single"
    return self
end

function SessionState:setCatalog(catalog)
    self.catalog = catalog or "single"
end

function SessionState:setPlayerCount(playerCount)
    self.playerCount = MultiplayerConfig.clampPlayerCount(playerCount, 1, 4, 1)
    if self.playerCount > 1 then
        self.catalog = "multi"
    elseif self.catalog == "multi" then
        self.catalog = "single"
    end
end

function SessionState:isMultiplayer()
    return self.playerCount > 1
end
