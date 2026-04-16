--[[
Per-view audio playlist helper.

Purpose:
- discovers optional audio files for each Starry Messenger view
- starts, stops, and advances looping background tracks
- keeps music switching centralized instead of spreading it across scenes
]]
local pd <const> = playdate
local snd <const> = pd.sound

ViewAudio = {}

ViewAudio.currentTracks = nil
ViewAudio.currentIndex = 0
ViewAudio.currentPlayer = nil
ViewAudio.currentViewId = nil

local SHARED_AUDIO_FOLDERS <const> = {
    warp = {
        "audio/shared-audio"
    },
    fall = {
        "audio/shared-audio"
    },
    gifplayer = {
        "audio/shared-ambiance/AirplaneAmbiance"
    },
    crttv = {
        "audio/shared-ambiance/AirplaneAmbiance"
    },
    orbital = {
        "audio/shared-ambiance/AirplaneAmbiance"
    }
}

local function appendTracksFromFolder(tracks, folder)
    local entries = pd.file.listFiles(folder) or {}
    table.sort(entries)
    for _, entry in ipairs(entries) do
        local normalized = string.gsub(entry, "\\", "/")
        local lower = string.lower(normalized)
        if string.match(lower, "%.mp3$") then
            tracks[#tracks + 1] = folder .. "/" .. normalized
        end
    end
end

local function buildTrackList(viewId)
    local folderViewId = viewId == "fishidle" and "fishpond" or viewId
    local folders = {
        "audio/" .. folderViewId
    }
    local sharedFolders = SHARED_AUDIO_FOLDERS[viewId]
    if sharedFolders ~= nil then
        for _, folder in ipairs(sharedFolders) do
            folders[#folders + 1] = folder
        end
    end

    local tracks = {}
    for _, folder in ipairs(folders) do
        appendTracksFromFolder(tracks, folder)
    end

    return tracks
end

function ViewAudio.stop()
    if ViewAudio.currentPlayer then
        ViewAudio.currentPlayer:stop()
    end

    ViewAudio.currentTracks = nil
    ViewAudio.currentIndex = 0
    ViewAudio.currentPlayer = nil
    ViewAudio.currentViewId = nil
end

function ViewAudio.playCurrentTrack()
    if not ViewAudio.currentTracks or #ViewAudio.currentTracks == 0 then
        return
    end

    local path = ViewAudio.currentTracks[ViewAudio.currentIndex]
    local player = snd.fileplayer.new(path)
    if not player then
        StarryLog.error("audio player failed to initialize: %s", path)
        return
    end

    player:setFinishCallback(function(finishedPlayer)
        if ViewAudio.currentPlayer ~= finishedPlayer or not ViewAudio.currentTracks then
            return
        end

        ViewAudio.currentIndex = ViewAudio.currentIndex + 1
        if ViewAudio.currentIndex > #ViewAudio.currentTracks then
            ViewAudio.currentIndex = 1
        end

        ViewAudio.playCurrentTrack()
    end)

    local ok, errorMessage = player:play()
    if not ok then
        StarryLog.error("audio playback failed for %s: %s", path, errorMessage or "unknown error")
        return
    end

    ViewAudio.currentPlayer = player
    StarryLog.info("audio playing: %s", path)
end

function ViewAudio.playForView(viewId)
    ViewAudio.stop()

    local tracks = buildTrackList(viewId)
    if #tracks == 0 then
        StarryLog.info("no audio found for view: %s", viewId)
        return
    end

    ViewAudio.currentTracks = tracks
    ViewAudio.currentIndex = 1
    ViewAudio.currentViewId = viewId
    ViewAudio.playCurrentTrack()
end
