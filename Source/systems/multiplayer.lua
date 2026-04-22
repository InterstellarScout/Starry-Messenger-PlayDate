MultiplayerConfig = MultiplayerConfig or {}

function MultiplayerConfig.clampPlayerCount(playerCount, minPlayers, maxPlayers, defaultPlayers)
    local minimum = math.floor(minPlayers or 2)
    local maximum = math.floor(maxPlayers or 4)
    local fallback = math.floor(defaultPlayers or minimum)
    local count = math.floor(tonumber(playerCount) or fallback)
    if count < minimum then
        return minimum
    end
    if count > maximum then
        return maximum
    end
    return count
end

function MultiplayerConfig.getBeingCountLabel(playerCount)
    local count = MultiplayerConfig.clampPlayerCount(playerCount, 2, 4, 2)
    if count == 2 then
        return "Two Beings"
    elseif count == 3 then
        return "Three Beings"
    end
    return "Four Beings"
end
