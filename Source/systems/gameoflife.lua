--[[
Game of Life simulation, recorder, and playback system.

Purpose:
- runs the standard and Endless Life cellular automata modes
- records compact sparse-frame sessions and replays them in Review Life
- manages warm caches, title previews, standby instances, and scrub history
]]
local pd <const> = playdate
local gfx <const> = pd.graphics

GameOfLife = {}
GameOfLife.__index = GameOfLife

GameOfLife.MODE_STANDARD = "standard"
GameOfLife.MODE_ENDLESS = "endless"
GameOfLife.MODE_RECORD = "record"
GameOfLife.MODE_REVIEW = "review"

local PREVIEW_FRAME_COUNT <const> = 10
local WARM_FRAME_COUNT <const> = 50
local ENDLESS_MAX_LIVE_CELL_RATIO <const> = 0.34

local LIFE_RECORDINGS_DIR <const> = "exports/life-recordings"
local LIFE_RECORDING_EXTENSION <const> = ".slif"
local LIFE_RECORDINGS_META_KEY <const> = "life-recordings-meta"
local LIFE_REVIEW_META_KEY <const> = "life-review-meta"
local LIFE_RECORDING_MAGIC <const> = "SLIF"
local LIFE_RECORDING_VERSION <const> = 1
local LIFE_RECORDING_FRAME_TAG <const> = "FRM1"

local LIFE_REASON_CODES <const> = {
    ["initial"] = 1,
    ["generation"] = 2,
    ["inject"] = 3,
    ["history-forward"] = 4,
    ["scrub-forward"] = 5,
    ["scrub-history-forward"] = 6,
    ["scrub-rewind"] = 7,
    ["preview-handoff"] = 8,
    ["unknown"] = 255
}

local LIFE_REASON_NAMES <const> = {
    [1] = "initial",
    [2] = "generation",
    [3] = "inject",
    [4] = "history-forward",
    [5] = "scrub-forward",
    [6] = "scrub-history-forward",
    [7] = "scrub-rewind",
    [8] = "preview-handoff",
    [255] = "unknown"
}

GameOfLife._warmCaches = GameOfLife._warmCaches or {}
GameOfLife._standbyInstances = GameOfLife._standbyInstances or {}
GameOfLife._prewarmQueue = GameOfLife._prewarmQueue or nil
local LIFE_FORCE_DEBUG_LOGGING <const> = true

local function lifeLog(message, ...)
    if LIFE_FORCE_DEBUG_LOGGING then
        StarryLog.forceDebug("life " .. tostring(message), ...)
    else
        StarryLog.debug("life " .. tostring(message), ...)
    end
end

local function lifeLogError(message, ...)
    StarryLog.forceError("life " .. tostring(message), ...)
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function roundToTenth(value)
    if value >= 0 then
        return math.floor((value * 10) + 0.5) / 10
    end
    return math.ceil((value * 10) - 0.5) / 10
end

local function degreesToRadians(value)
    return value * math.pi / 180
end

local function rotatePoint(x, y, angleDegrees)
    if angleDegrees == 0 then
        return x, y
    end

    local radians = degreesToRadians(angleDegrees)
    local cosine = math.cos(radians)
    local sine = math.sin(radians)
    return (x * cosine) - (y * sine), (x * sine) + (y * cosine)
end

local function encodeU16(value)
    local clamped = clamp(math.floor(tonumber(value) or 0), 0, 65535)
    local low = clamped % 256
    local high = math.floor(clamped / 256) % 256
    return string.char(low, high)
end

local function encodeU32(value)
    local clamped = math.max(0, math.floor(tonumber(value) or 0))
    local b1 = clamped % 256
    local b2 = math.floor(clamped / 256) % 256
    local b3 = math.floor(clamped / 65536) % 256
    local b4 = math.floor(clamped / 16777216) % 256
    return string.char(b1, b2, b3, b4)
end

local function decodeU16(bytes, startIndex)
    local first = bytes:byte(startIndex, startIndex) or 0
    local second = bytes:byte(startIndex + 1, startIndex + 1) or 0
    return first + (second * 256)
end

local function decodeU32(bytes, startIndex)
    local b1 = bytes:byte(startIndex, startIndex) or 0
    local b2 = bytes:byte(startIndex + 1, startIndex + 1) or 0
    local b3 = bytes:byte(startIndex + 2, startIndex + 2) or 0
    local b4 = bytes:byte(startIndex + 3, startIndex + 3) or 0
    return b1 + (b2 * 256) + (b3 * 65536) + (b4 * 16777216)
end

local function readExact(file, byteCount)
    if not file or not file.read or byteCount <= 0 then
        return nil
    end

    local chunk = file:read(byteCount)
    if chunk == nil or #chunk ~= byteCount then
        return nil
    end
    return chunk
end

local function getReasonCode(reason)
    return LIFE_REASON_CODES[reason or "unknown"] or LIFE_REASON_CODES.unknown
end

local function getReasonName(reasonCode)
    return LIFE_REASON_NAMES[reasonCode] or LIFE_REASON_NAMES[LIFE_REASON_CODES.unknown]
end

local function buildRecordingHeader(width, height, cellSize, rows, columns)
    return table.concat({
        LIFE_RECORDING_MAGIC,
        string.char(LIFE_RECORDING_VERSION),
        encodeU16(width),
        encodeU16(height),
        string.char(clamp(cellSize, 0, 255)),
        string.char(clamp(rows, 0, 255)),
        string.char(clamp(columns, 0, 255))
    })
end

local function parseRecordingHeader(file)
    local header = readExact(file, 12)
    if header == nil or header:sub(1, 4) ~= LIFE_RECORDING_MAGIC then
        return nil
    end

    return {
        version = header:byte(5, 5) or 0,
        width = decodeU16(header, 6),
        height = decodeU16(header, 8),
        cellSize = header:byte(10, 10) or 0,
        rows = header:byte(11, 11) or 0,
        columns = header:byte(12, 12) or 0
    }
end

local function isBinaryRecordingPath(path)
    return path ~= nil and path:match("%.slif$") ~= nil
end

local function getReviewMeta()
    local meta = nil
    if pd.datastore and pd.datastore.read then
        meta = pd.datastore.read(LIFE_REVIEW_META_KEY)
    end
    meta = meta or {}
    meta.favorites = meta.favorites or {}
    return meta
end

local function saveReviewMeta(meta)
    if pd.datastore and pd.datastore.write then
        pd.datastore.write(meta, LIFE_REVIEW_META_KEY)
    end
end

local function ensureLifeRecordingsDirectory()
    if pd.file and pd.file.mkdir then
        local ok, err = pcall(function()
            pd.file.mkdir(LIFE_RECORDINGS_DIR)
        end)
        if not ok then
            lifeLog("recordings dir mkdir skipped path=%s err=%s", LIFE_RECORDINGS_DIR, tostring(err))
        end
    end
end

local function safeListLifeRecordingFiles()
    if not pd.file or not pd.file.listFiles then
        return {}
    end

    ensureLifeRecordingsDirectory()
    local ok, entriesOrErr = pcall(function()
        return pd.file.listFiles(LIFE_RECORDINGS_DIR) or {}
    end)
    if not ok then
        lifeLogError("recordings dir list failed path=%s err=%s", LIFE_RECORDINGS_DIR, tostring(entriesOrErr))
        return {}
    end

    return entriesOrErr or {}
end

function GameOfLife.getModeLabel(modeId)
    if modeId == GameOfLife.MODE_ENDLESS then
        return "Endless Life"
    elseif modeId == GameOfLife.MODE_RECORD then
        return "Life Recorder"
    elseif modeId == GameOfLife.MODE_REVIEW then
        return "Review Life"
    end

    return "Game of Life"
end

function GameOfLife.getConfigKey(width, height, cellSize, seedChance)
    return table.concat({
        tostring(width or 0),
        tostring(height or 0),
        tostring(cellSize or 0),
        string.format("%.4f", tonumber(seedChance) or 0)
    }, "|")
end

function GameOfLife.getStandbyKey(width, height, cellSize, seedChance, modeId)
    return GameOfLife.getConfigKey(width, height, cellSize, seedChance) .. "|" .. tostring(modeId or GameOfLife.MODE_STANDARD)
end

function GameOfLife.resetStandby(width, height, cellSize, seedChance, modeId)
    local standbyKey = GameOfLife.getStandbyKey(width, height, cellSize, seedChance, modeId)
    GameOfLife._standbyInstances[standbyKey] = nil
    lifeLog("standby reset: %s", standbyKey)
end

function GameOfLife.prewarm(width, height, cellSize, seedChance, frameCount)
    local targetFrames = math.max(1, math.floor(frameCount or WARM_FRAME_COUNT))
    local configKey = GameOfLife.getConfigKey(width, height, cellSize, seedChance)
    local cached = GameOfLife._warmCaches[configKey]
    if cached and #cached.snapshots >= targetFrames then
        return cached
    end

    local temp = setmetatable({}, GameOfLife)
    temp.width = width
    temp.height = height
    temp.cellSize = cellSize or 5
    temp.columns = math.floor(width / temp.cellSize)
    temp.rows = math.floor(height / temp.cellSize)
    temp.seedChance = seedChance or 0.28
    temp.grid = {}
    temp.nextGrid = {}
    temp:seedRandomGrid()

    local snapshots = { temp:copyGrid(temp.grid) }
    while #snapshots < targetFrames do
        snapshots[#snapshots + 1] = temp:buildNextSnapshot(snapshots[#snapshots])
    end

    cached = {
        width = width,
        height = height,
        cellSize = temp.cellSize,
        seedChance = temp.seedChance,
        snapshots = snapshots
    }
    GameOfLife._warmCaches[configKey] = cached
    return cached
end

function GameOfLife.prewarmStarryMessenger()
    GameOfLife.prewarm(400, 240, 6, 0.3, WARM_FRAME_COUNT)
    GameOfLife.prewarm(400, 240, 5, 0.28, WARM_FRAME_COUNT)
end

function GameOfLife.beginPrewarmStarryMessenger()
    if GameOfLife._prewarmQueue ~= nil then
        return
    end

    lifeLog("prewarm queued")
    GameOfLife._prewarmQueue = {
        configs = {
            { width = 400, height = 240, cellSize = 6, seedChance = 0.3, frameCount = WARM_FRAME_COUNT },
            { width = 400, height = 240, cellSize = 5, seedChance = 0.28, frameCount = WARM_FRAME_COUNT }
        },
        configIndex = 1,
        snapshotIndex = 1,
        temp = nil
    }
end

function GameOfLife.isPrewarmComplete()
    return GameOfLife._prewarmQueue == nil
end

function GameOfLife.updatePrewarm(budgetMs)
    local queue = GameOfLife._prewarmQueue
    if queue == nil then
        return true
    end

    local startTime = pd.getCurrentTimeMilliseconds()
    local budget = math.max(1, math.floor(budgetMs or 4))

    while queue.configIndex <= #queue.configs do
        local config = queue.configs[queue.configIndex]
        local configKey = GameOfLife.getConfigKey(config.width, config.height, config.cellSize, config.seedChance)
        local cached = GameOfLife._warmCaches[configKey]
        if cached and #cached.snapshots >= config.frameCount then
            lifeLog("prewarm cache hit %s", configKey)
            queue.configIndex = queue.configIndex + 1
            queue.snapshotIndex = 1
            queue.temp = nil
        else
            if queue.temp == nil then
                local temp = setmetatable({}, GameOfLife)
                temp.width = config.width
                temp.height = config.height
                temp.cellSize = config.cellSize or 5
                temp.columns = math.floor(config.width / temp.cellSize)
                temp.rows = math.floor(config.height / temp.cellSize)
                temp.seedChance = config.seedChance or 0.28
                temp.grid = {}
                temp.nextGrid = {}
                temp:seedRandomGrid()
                queue.temp = {
                    configKey = configKey,
                    temp = temp,
                    snapshots = { temp:copyGrid(temp.grid) }
                }
                queue.snapshotIndex = 1
                lifeLog("prewarm start %s", configKey)
            end

            while #queue.temp.snapshots < config.frameCount do
                local source = queue.temp.snapshots[#queue.temp.snapshots]
                queue.temp.snapshots[#queue.temp.snapshots + 1] = queue.temp.temp:buildNextSnapshot(source)
                queue.snapshotIndex = #queue.temp.snapshots
                if (pd.getCurrentTimeMilliseconds() - startTime) >= budget then
                    lifeLog(
                        "prewarm progress %s %d/%d",
                        queue.temp.configKey,
                        queue.snapshotIndex,
                        config.frameCount
                    )
                    return false
                end
            end

            GameOfLife._warmCaches[queue.temp.configKey] = {
                width = config.width,
                height = config.height,
                cellSize = config.cellSize,
                seedChance = config.seedChance,
                snapshots = queue.temp.snapshots
            }
            lifeLog("prewarm complete %s", queue.temp.configKey)
            queue.configIndex = queue.configIndex + 1
            queue.snapshotIndex = 1
            queue.temp = nil
        end
    end

    GameOfLife._prewarmQueue = nil
    lifeLog("prewarm finished")
    return true
end

function GameOfLife.new(width, height, cellSize, seedChance, options)
    options = options or {}
    local modeId = options.modeId or GameOfLife.MODE_STANDARD
    local preview = options.preview and true or false
    local reviewMode = modeId == GameOfLife.MODE_REVIEW and not preview
    lifeLog(
        "new requested width=%s height=%s cellSize=%s seedChance=%s preview=%s mode=%s forceFresh=%s",
        tostring(width),
        tostring(height),
        tostring(cellSize),
        tostring(seedChance),
        tostring(preview),
        tostring(modeId),
        tostring(options.forceFresh == true)
    )
    if reviewMode then
        lifeLog("review mode requested; loading binary recordings only")
    end
    local forceFresh = options.forceFresh == true
    local standbyKey = GameOfLife.getStandbyKey(width, height, cellSize or 5, seedChance or 0.28, modeId)

    if not preview and not reviewMode and not forceFresh then
        local standby = GameOfLife._standbyInstances[standbyKey]
        if standby then
            lifeLog("reusing standby instance mode=%s preview=%s key=%s", tostring(modeId), tostring(preview), standbyKey)
            standby.modeId = modeId
            standby.recordingEnabled = standby.modeId == GameOfLife.MODE_RECORD
            standby.reviewMode = false
            standby.standbyKey = standbyKey
            standby:setPreview(preview)
            if standby.recordingEnabled and not standby.preview and not standby.recordingStarted then
                standby:beginRecordingSession()
                standby:markRecordingDirty("warm-standby")
            end
            return standby
        end
    end

    local self = setmetatable({}, GameOfLife)
    self.width = width
    self.height = height
    self.cellSize = cellSize or 5
    self.columns = math.floor(width / self.cellSize)
    self.rows = math.floor(height / self.cellSize)
    self.seedChance = seedChance or 0.28
    self.speed = 100
    self.directionAngle = 0
    self.screenAngle = 0
    self.accumulator = 0
    self.historyLimit = 180
    self.futureBufferLimit = 90
    self.prefetchBudgetMs = 2
    self.endlessMaxLiveCells = math.max(1, math.floor(self.columns * self.rows * ENDLESS_MAX_LIVE_CELL_RATIO))
    self.history = {}
    self.historyCursor = 0
    self.liveHistoryCount = 0
    self.futureBuffer = {}
    self.futureAdvanceArmed = false
    self.scrubLimitWarningFrames = 0
    self.scrubLimitPhase = 0
    self.grid = {}
    self.nextGrid = {}
    self.modeId = modeId
    self.preview = preview
    self.recordingEnabled = self.modeId == GameOfLife.MODE_RECORD
    self.reviewMode = reviewMode
    self.recordingStarted = false
    self.recordingPath = nil
    self.recordingSessionId = nil
    self.recordingFrame = 0
    self.recordDirty = false
    self.recordReason = "initial"
    self.reviewEntries = {}
    self.reviewSelection = 1
    self.reviewActionIndex = 1
    self.reviewActions = { "play", "favorite", "delete" }
    self.reviewState = self.reviewMode and "browser" or nil
    self.reviewFrames = nil
    self.reviewFrameOffsets = nil
    self.reviewFrameCount = 0
    self.reviewLoadedFrame = nil
    self.reviewFrameCursor = 1
    self.reviewLoadedEntry = nil
    self.reviewStatusMessage = nil
    self.reviewBlinkFrame = 0
    self.previewFrames = nil
    self.previewFrameIndex = 1
    self.previewDirection = 1
    self.previewBaseIndex = 1
    self.warmCacheKey = GameOfLife.getConfigKey(self.width, self.height, self.cellSize, self.seedChance)
    self.standbyKey = standbyKey
    self.previewUsedWarmSlice = false
    lifeLog(
        "new instance mode=%s preview=%s review=%s fresh=%s key=%s",
        tostring(self.modeId),
        tostring(self.preview),
        tostring(self.reviewMode),
        tostring(forceFresh),
        self.standbyKey
    )

    if not self.reviewMode and not forceFresh then
        self:applyWarmCache(GameOfLife.prewarm(self.width, self.height, self.cellSize, self.seedChance, WARM_FRAME_COUNT), self.preview)
    else
        self:seedRandomGrid()
        self:recordHistory()
        lifeLog("seeded fresh grid mode=%s review=%s", tostring(self.modeId), tostring(self.reviewMode))
    end

    if self.preview then
        self:buildPreviewFrames()
    end

    if self.recordingEnabled and not self.preview then
        self:beginRecordingSession()
        self:markRecordingDirty("session-start")
    end

    if self.reviewMode then
        self:refreshReviewEntries()
    end

    if not self.reviewMode then
        if not self.preview then
            GameOfLife._standbyInstances[self.standbyKey] = self
        else
            GameOfLife._standbyInstances[self.standbyKey] = nil
        end
    end

    return self
end

function GameOfLife:setPreview(isPreview)
    local wasPreview = self.preview
    self.preview = isPreview and true or false
    self.reviewMode = self.modeId == GameOfLife.MODE_REVIEW and not self.preview
    if wasPreview ~= self.preview then
        lifeLog("preview state changed: %s -> %s mode=%s", tostring(wasPreview), tostring(self.preview), tostring(self.modeId))
    end
    if self.preview and not wasPreview then
        self.previewBaseIndex = math.max(1, math.min(self.historyCursor > 0 and self.historyCursor or 1, math.max(1, #self.history - PREVIEW_FRAME_COUNT + 1)))
        self:buildPreviewFrames()
    elseif wasPreview and not self.preview then
        local resumedHistoryIndex = clamp((self.previewBaseIndex or 1) + ((self.previewFrameIndex or 1) - 1), 1, math.max(1, #self.history))
        if self.previewUsedWarmSlice then
            local warmCache = GameOfLife.prewarm(self.width, self.height, self.cellSize, self.seedChance, WARM_FRAME_COUNT)
            self:applyWarmCache(warmCache, false)
            resumedHistoryIndex = clamp((self.previewBaseIndex or 1) + ((self.previewFrameIndex or 1) - 1), 1, math.max(1, #self.history))
            lifeLog("expanded preview slice to full warm cache for gameplay handoff")
        end
        self.previewFrames = nil
        self.previewFrameIndex = 1
        self.previewDirection = 1
        self.previewBaseIndex = resumedHistoryIndex
        self.historyCursor = resumedHistoryIndex
        if self.history[self.historyCursor] then
            self:restoreGrid(self.history[self.historyCursor])
        else
            self.history = {}
            self.historyCursor = 0
            self.liveHistoryCount = 0
            self:recordHistory()
        end
        self.accumulator = 0
    end
    if self.recordingEnabled and not self.preview and not self.recordingStarted then
        self:beginRecordingSession()
        self:markRecordingDirty("preview-handoff")
    end
    if self.reviewMode then
        self.reviewState = "browser"
        self:refreshReviewEntries()
    end
end

function GameOfLife:seedRandomGrid()
    self.grid = {}
    self.nextGrid = {}
    for row = 1, self.rows do
        self.grid[row] = {}
        self.nextGrid[row] = {}
        for column = 1, self.columns do
            self.grid[row][column] = math.random() < self.seedChance and 1 or 0
            self.nextGrid[row][column] = 0
        end
    end
end

function GameOfLife:applyWarmCache(cache, preview)
    if not cache or not cache.snapshots or #cache.snapshots == 0 then
        lifeLog("warm cache missing; seeding fallback grid")
        self:seedRandomGrid()
        self:recordHistory()
        return
    end

    self.history = {}
    local lastFrame = #cache.snapshots
    if preview then
        lastFrame = math.min(lastFrame, PREVIEW_FRAME_COUNT)
        self.previewUsedWarmSlice = lastFrame < #cache.snapshots
    else
        self.previewUsedWarmSlice = false
    end

    for index = 1, lastFrame do
        local snapshot = cache.snapshots[index]
        self.history[index] = self:copyGrid(snapshot)
    end

    self.liveHistoryCount = #self.history
    self.historyCursor = preview and 1 or #self.history
    self.futureBuffer = {}
    self.futureAdvanceArmed = false
    self:restoreGrid(self.history[self.historyCursor])
    lifeLog(
        "warm cache applied: key=%s frames=%d preview=%s sliced=%s",
        self.warmCacheKey,
        #self.history,
        tostring(preview),
        tostring(self.previewUsedWarmSlice)
    )
end

function GameOfLife:copyGrid(source)
    local copy = {}
    for row = 1, self.rows do
        copy[row] = {}
        for column = 1, self.columns do
            copy[row][column] = source[row][column]
        end
    end
    return copy
end

function GameOfLife:buildPreviewFrames()
    if not self.preview or self.reviewMode then
        self.previewFrames = nil
        self.previewFrameIndex = 1
        self.previewDirection = 1
        lifeLog("buildPreviewFrames skipped preview=%s review=%s", tostring(self.preview), tostring(self.reviewMode))
        return
    end

    local startIndex = clamp(self.previewBaseIndex or 1, 1, math.max(1, #self.history))
    local endIndex = math.min(#self.history, startIndex + PREVIEW_FRAME_COUNT - 1)
    self.previewFrames = {}
    self.previewFrameIndex = 1
    self.previewDirection = 1

    if #self.history > 0 then
        for index = startIndex, endIndex do
            self.previewFrames[#self.previewFrames + 1] = self:copyGrid(self.history[index])
        end
    else
        self.previewFrames[1] = self:copyGrid(self.grid)
        local source = self.previewFrames[1]
        while #self.previewFrames < PREVIEW_FRAME_COUNT do
            local snapshot = self:buildNextSnapshot(source)
            self.previewFrames[#self.previewFrames + 1] = snapshot
            source = snapshot
        end
    end

    if self.previewFrames[1] then
        self:restoreGrid(self.previewFrames[1])
    end

    lifeLog(
        "preview frames built count=%d history=%d start=%d end=%d frameIndex=%d",
        #self.previewFrames,
        #self.history,
        startIndex,
        endIndex,
        self.previewFrameIndex
    )
end

function GameOfLife:restoreGrid(snapshot)
    for row = 1, self.rows do
        if self.grid[row] == nil then
            self.grid[row] = {}
        end
        if self.nextGrid[row] == nil then
            self.nextGrid[row] = {}
        end
        for column = 1, self.columns do
            self.grid[row][column] = snapshot[row][column]
            if self.nextGrid[row][column] == nil then
                self.nextGrid[row][column] = 0
            end
        end
    end
end

function GameOfLife:shutdown()
    self.previewFrames = nil
    self.futureBuffer = nil
    self.reviewFrames = nil
    self.reviewFrameOffsets = nil
    self.reviewLoadedFrame = nil

    if self.preview then
        self.history = nil
    end

    if self.preview and self.standbyKey and GameOfLife._standbyInstances[self.standbyKey] == self then
        GameOfLife._standbyInstances[self.standbyKey] = nil
    end
end

function GameOfLife:clearFutureBuffer()
    self.futureBuffer = {}
    self.futureAdvanceArmed = false
end

function GameOfLife:appendHistorySnapshot(snapshot, isLive)
    while #self.history > self.historyCursor do
        table.remove(self.history)
    end

    if self.liveHistoryCount > #self.history then
        self.liveHistoryCount = #self.history
    end

    self.history[#self.history + 1] = snapshot

    while #self.history > self.historyLimit do
        table.remove(self.history, 1)
        if self.liveHistoryCount > 0 then
            self.liveHistoryCount = self.liveHistoryCount - 1
        end
    end

    self.historyCursor = #self.history
    if isLive then
        self.liveHistoryCount = #self.history
    end
end

function GameOfLife:recordHistory()
    self:appendHistorySnapshot(self:copyGrid(self.grid), true)
end

function GameOfLife:beginRecordingSession()
    if not self.recordingEnabled or self.preview or self.recordingStarted then
        return
    end

    local meta = nil
    if pd.datastore and pd.datastore.read then
        meta = pd.datastore.read(LIFE_RECORDINGS_META_KEY)
    end
    meta = meta or {}

    local sessionIndex = math.max(1, math.floor(tonumber(meta.nextIndex) or 1))
    meta.nextIndex = sessionIndex + 1
    if pd.datastore and pd.datastore.write then
        pd.datastore.write(meta, LIFE_RECORDINGS_META_KEY)
    end

    if pd.file and pd.file.mkdir then
        pd.file.mkdir(LIFE_RECORDINGS_DIR)
    end

    self.recordingSessionId = string.format("life-%04d-%d", sessionIndex, pd.getSecondsSinceEpoch())
    self.recordingPath = string.format("%s/session-%04d%s", LIFE_RECORDINGS_DIR, sessionIndex, LIFE_RECORDING_EXTENSION)
    self.recordingFrame = 0
    self.recordingStarted = true

    local file = pd.file and pd.file.open and pd.file.open(self.recordingPath, pd.file.kFileWrite)
    if file then
        file:write(buildRecordingHeader(self.width, self.height, self.cellSize, self.rows, self.columns))
        file:close()
        lifeLog("recording started: %s", self.recordingPath)
    else
        lifeLog("recording failed to open file")
    end
end

function GameOfLife:markRecordingDirty(reason)
    if not self.recordingEnabled or self.preview then
        return
    end

    self.recordDirty = true
    self.recordReason = reason or "update"
end

function GameOfLife:flushRecording()
    if not self.recordDirty or not self.recordingEnabled or self.preview then
        return
    end

    if not self.recordingStarted then
        self:beginRecordingSession()
    end

    if not self.recordingPath then
        self.recordDirty = false
        return
    end

    local file = pd.file.open(self.recordingPath, pd.file.kFileAppend)
    if not file then
        lifeLog("recording append failed: %s", tostring(self.recordingPath))
        self.recordDirty = false
        return
    end

    local encodedCells = {}
    local wroteRows = 0
    for row = 1, self.rows do
        for column = 1, self.columns do
            if self.grid[row][column] == 1 then
                encodedCells[#encodedCells + 1] = string.char(
                    clamp(row, 0, 255),
                    clamp(column, 0, 255)
                )
                wroteRows = wroteRows + 1
            end
        end
    end

    file:write(LIFE_RECORDING_FRAME_TAG)
    file:write(encodeU32(self.recordingFrame))
    file:write(string.char(getReasonCode(self.recordReason)))
    file:write(encodeU16(wroteRows))
    if wroteRows > 0 then
        file:write(table.concat(encodedCells))
    end

    file:close()
    lifeLog("recording flushed frame=%d rows=%d reason=%s", self.recordingFrame, wroteRows, tostring(self.recordReason))
    self.recordingFrame = self.recordingFrame + 1
    self.recordDirty = false
end

function GameOfLife:loadReviewPlaybackBinary(entry)
    local file = pd.file and pd.file.open and pd.file.open(entry.path, pd.file.kFileRead)
    if not file then
        self.reviewStatusMessage = "Could not open " .. entry.name
        lifeLog("review playback open failed: %s", tostring(entry.path))
        return false
    end

    local header = parseRecordingHeader(file)
    if header == nil then
        file:close()
        self.reviewStatusMessage = "Unsupported file " .. entry.name
        lifeLog("review playback header invalid: %s", tostring(entry.path))
        return false
    end

    local frameOffsets = {}
    while true do
        local offset = file:tell()
        local tag = file:read(4)
        if tag == nil then
            break
        end
        if #tag ~= 4 or tag ~= LIFE_RECORDING_FRAME_TAG then
            file:close()
            self.reviewStatusMessage = "Corrupt file " .. entry.name
            lifeLog("review playback tag invalid: %s offset=%s tag=%s", tostring(entry.path), tostring(offset), tostring(tag))
            return false
        end

        local frameHeader = readExact(file, 7)
        if frameHeader == nil then
            break
        end

        local frameNumber = decodeU32(frameHeader, 1)
        local reasonCode = frameHeader:byte(5, 5) or LIFE_REASON_CODES.unknown
        local cellCount = decodeU16(frameHeader, 6)
        frameOffsets[#frameOffsets + 1] = {
            index = frameNumber,
            offset = offset,
            reasonCode = reasonCode,
            cellCount = cellCount,
            format = "slif"
        }

        local skipBytes = cellCount * 2
        file:seek(skipBytes, pd.file.kSeekCurrent)
    end
    file:close()

    if #frameOffsets == 0 then
        self.reviewStatusMessage = "No frames found in " .. entry.name
        lifeLog("review playback had no frames: %s", tostring(entry.path))
        return false
    end

    self.reviewFrames = nil
    self.reviewFrameOffsets = frameOffsets
    self.reviewFrameCount = #frameOffsets
    self.reviewLoadedEntry = entry
    self.reviewFrameCursor = 1
    self.reviewState = "playback"
    self.reviewStatusMessage = string.format("Indexed %d frames.", #frameOffsets)
    lifeLog("review playback indexed: %s frames=%d format=slif", tostring(entry.path), #frameOffsets)
    return self:loadReviewFrameAt(1)
end

function GameOfLife:isReviewMode()
    return self.reviewMode == true
end

function GameOfLife:getReviewActionLabel(action, entry)
    if action == "favorite" then
        return entry and entry.favorite and "Unfavorite" or "Favorite"
    elseif action == "delete" then
        return "Delete"
    end
    return "Play"
end

function GameOfLife:refreshReviewEntries()
    local previousPath = nil
    if #self.reviewEntries > 0 and self.reviewEntries[self.reviewSelection] then
        previousPath = self.reviewEntries[self.reviewSelection].path
    end

    local fileList = safeListLifeRecordingFiles()

    local meta = getReviewMeta()
    local entries = {}
    for _, fileName in ipairs(fileList or {}) do
        if fileName:match("%.slif$") then
            local path = string.format("%s/%s", LIFE_RECORDINGS_DIR, fileName)
            entries[#entries + 1] = {
                name = fileName,
                path = path,
                favorite = meta.favorites[path] == true
            }
        end
    end

    table.sort(entries, function(a, b)
        if a.favorite ~= b.favorite then
            return a.favorite and not b.favorite
        end
        return a.name > b.name
    end)

    self.reviewEntries = entries
    if #entries == 0 then
        self.reviewSelection = 1
        self.reviewStatusMessage = "No saved life recordings yet."
    else
        local restoredSelection = nil
        if previousPath ~= nil then
            for index, entry in ipairs(entries) do
                if entry.path == previousPath then
                    restoredSelection = index
                    break
                end
            end
        end
        self.reviewSelection = restoredSelection or clamp(self.reviewSelection, 1, #entries)
        self.reviewStatusMessage = nil
    end
    self.reviewActionIndex = clamp(self.reviewActionIndex, 1, #self.reviewActions)
    lifeLog("review entries refreshed: count=%d selection=%d", #self.reviewEntries, self.reviewSelection)
end

function GameOfLife:getSelectedReviewEntry()
    if #self.reviewEntries == 0 then
        return nil
    end
    return self.reviewEntries[self.reviewSelection]
end

function GameOfLife:toggleReviewFavorite()
    local entry = self:getSelectedReviewEntry()
    if not entry then
        return
    end

    local meta = getReviewMeta()
    entry.favorite = not entry.favorite
    meta.favorites[entry.path] = entry.favorite or nil
    saveReviewMeta(meta)
    self:refreshReviewEntries()
    self.reviewStatusMessage = entry.favorite and "Marked as favorite." or "Removed favorite."
    lifeLog("review favorite toggled: %s favorite=%s", tostring(entry.path), tostring(entry.favorite))
end

function GameOfLife:deleteSelectedReviewEntry()
    local entry = self:getSelectedReviewEntry()
    if not entry then
        return
    end

    if pd.file and pd.file.delete then
        pd.file.delete(entry.path)
    end

    local meta = getReviewMeta()
    meta.favorites[entry.path] = nil
    saveReviewMeta(meta)
    self.reviewFrames = nil
    self.reviewFrameOffsets = nil
    self.reviewLoadedFrame = nil
    self.reviewFrameCount = 0
    self.reviewLoadedEntry = nil
    self.reviewFrameCursor = 1
    self:refreshReviewEntries()
    self.reviewStatusMessage = "Deleted " .. entry.name
    lifeLog("review entry deleted: %s", tostring(entry.path))
end

function GameOfLife:loadReviewPlayback(entry)
    if not entry then
        return false
    end

    if not isBinaryRecordingPath(entry.path) then
        self.reviewStatusMessage = "Unsupported file " .. entry.name
        lifeLogError("review rejected non-binary recording: %s", tostring(entry.path))
        return false
    end

    return self:loadReviewPlaybackBinary(entry)
end

function GameOfLife:loadReviewFrameAt(frameCursor)
    if not self.reviewLoadedEntry or not self.reviewFrameOffsets or #self.reviewFrameOffsets == 0 then
        return false
    end

    local clampedCursor = clamp(frameCursor, 1, #self.reviewFrameOffsets)
    local frameInfo = self.reviewFrameOffsets[clampedCursor]
    local file = pd.file and pd.file.open and pd.file.open(self.reviewLoadedEntry.path, pd.file.kFileRead)
    if not file then
        self.reviewStatusMessage = "Could not open " .. self.reviewLoadedEntry.name
        return false
    end

    local header = parseRecordingHeader(file)
    if header == nil then
        file:close()
        self.reviewStatusMessage = "Unsupported file " .. self.reviewLoadedEntry.name
        return false
    end

    file:seek(frameInfo.offset, pd.file.kSeekSet)
    local tag = readExact(file, 4)
    local frameHeader = readExact(file, 7)
    if tag == nil or frameHeader == nil or tag ~= LIFE_RECORDING_FRAME_TAG then
        file:close()
        self.reviewStatusMessage = "Could not load frame."
        return false
    end

    local frame = {
        index = decodeU32(frameHeader, 1),
        reason = getReasonName(frameHeader:byte(5, 5) or LIFE_REASON_CODES.unknown),
        cells = {}
    }

    local cellCount = decodeU16(frameHeader, 6)
    local cellBytes = cellCount > 0 and readExact(file, cellCount * 2) or ""
    file:close()

    if cellCount > 0 and cellBytes == nil then
        self.reviewStatusMessage = "Could not load frame."
        return false
    end

    for byteIndex = 1, #cellBytes, 2 do
        frame.cells[#frame.cells + 1] = {
            row = cellBytes:byte(byteIndex, byteIndex),
            column = cellBytes:byte(byteIndex + 1, byteIndex + 1)
        }
    end

    self.reviewFrameCursor = clampedCursor
    self.reviewLoadedFrame = frame
    self.reviewStatusMessage = string.format("Loaded frame %d.", clampedCursor)
    return true
end

function GameOfLife:handleReviewPrimaryAction()
    local entry = self:getSelectedReviewEntry()
    local action = self.reviewActions[self.reviewActionIndex]
    lifeLog("review primary action: %s entry=%s", tostring(action), tostring(entry and entry.path or nil))
    if action == "favorite" then
        self:toggleReviewFavorite()
    elseif action == "delete" then
        self:deleteSelectedReviewEntry()
    else
        self:loadReviewPlayback(entry)
    end
end

function GameOfLife:handleReviewMenuInput(upPressed, downPressed, leftPressed, rightPressed)
    if self.reviewState == "playback" then
        if leftPressed then
            self:loadReviewFrameAt(self.reviewFrameCursor - 1)
        elseif rightPressed then
            self:loadReviewFrameAt(self.reviewFrameCursor + 1)
        end
        if leftPressed or rightPressed then
            lifeLog("review playback stepped to frame=%d", self.reviewFrameCursor)
        end
        return
    end

    if upPressed and #self.reviewEntries > 0 then
        self.reviewSelection = self.reviewSelection <= 1 and #self.reviewEntries or (self.reviewSelection - 1)
    elseif downPressed and #self.reviewEntries > 0 then
        self.reviewSelection = self.reviewSelection >= #self.reviewEntries and 1 or (self.reviewSelection + 1)
    elseif leftPressed then
        self.reviewActionIndex = self.reviewActionIndex <= 1 and #self.reviewActions or (self.reviewActionIndex - 1)
    elseif rightPressed then
        self.reviewActionIndex = self.reviewActionIndex >= #self.reviewActions and 1 or (self.reviewActionIndex + 1)
    end
    if upPressed or downPressed or leftPressed or rightPressed then
        lifeLog("review browser moved: selection=%d action=%s", self.reviewSelection, tostring(self.reviewActions[self.reviewActionIndex]))
    end
end

function GameOfLife:handleReviewCrank(acceleratedChange)
    if self.reviewState ~= "playback" or not self.reviewFrameOffsets or #self.reviewFrameOffsets == 0 then
        return
    end

    local magnitude = math.abs(acceleratedChange)
    if magnitude <= 0.01 then
        return
    end

    local steps = math.max(1, math.floor((magnitude / 10) + 0.5))
    if acceleratedChange > 0 then
        self:loadReviewFrameAt(self.reviewFrameCursor + steps)
    else
        self:loadReviewFrameAt(self.reviewFrameCursor - steps)
    end
    lifeLog("review crank scrub: frame=%d steps=%d delta=%.2f", self.reviewFrameCursor, steps, acceleratedChange)
end

function GameOfLife:handleReviewBack()
    if self.reviewState == "playback" then
        self.reviewState = "browser"
        self.reviewStatusMessage = "Returned to recording list."
        lifeLog("review playback exited to browser")
        return true
    end
    return false
end

function GameOfLife:stepSpeed(direction)
    if direction == 0 then
        return
    end

    self.speed = math.max(0, self.speed + direction)

    lifeLog("speed changed: %.2f", self.speed)
end

function GameOfLife:rotateDirection(_deltaDegrees)
end

function GameOfLife:rotateScreen(deltaDegrees)
    self.screenAngle = self.screenAngle + deltaDegrees
    lifeLog("screen rotation changed: %.2f", self.screenAngle)
end

function GameOfLife:getLivingCells()
    local living = {}
    for row = 1, self.rows do
        for column = 1, self.columns do
            if self.grid[row][column] == 1 then
                living[#living + 1] = { row = row, column = column }
            end
        end
    end
    return living
end

function GameOfLife:spawnInteractiveCells(count)
    local spawnCount = math.max(1, count or 8)
    local living = self:getLivingCells()

    for index = 1, spawnCount do
        local row
        local column
        local nearExisting = (#living > 0) and (index <= math.floor(spawnCount / 2))

        if nearExisting then
            local anchor = living[math.random(1, #living)]
            row = clamp(anchor.row + math.random(-2, 2), 1, self.rows)
            column = clamp(anchor.column + math.random(-2, 2), 1, self.columns)
        else
            row = math.random(1, self.rows)
            column = math.random(1, self.columns)
        end

        self.grid[row][column] = 1
    end

    self:clearFutureBuffer()
    self:recordHistory()
    self:markRecordingDirty("inject")
    lifeLog("inserted cells: %d", spawnCount)
end

function GameOfLife:countNeighbors(row, column)
    return self:countNeighborsInGrid(self.grid, row, column)
end

function GameOfLife:countNeighborsInGrid(grid, row, column)
    local total = 0
    for rowOffset = -1, 1 do
        for columnOffset = -1, 1 do
            if not (rowOffset == 0 and columnOffset == 0) then
                local testRow = row + rowOffset
                local testColumn = column + columnOffset
                if testRow >= 1 and testRow <= self.rows and testColumn >= 1 and testColumn <= self.columns then
                    total = total + grid[testRow][testColumn]
                end
            end
        end
    end
    return total
end

function GameOfLife:buildNextSnapshot(source)
    local living = 0
    local snapshot = {}
    local dyingCells = {}

    for row = 1, self.rows do
        snapshot[row] = {}
        for column = 1, self.columns do
            local neighbors = self:countNeighborsInGrid(source, row, column)
            local state = source[row][column]

            if state == 1 then
                if neighbors == 2 or neighbors == 3 then
                    snapshot[row][column] = 1
                    living = living + 1
                else
                    snapshot[row][column] = 0
                    dyingCells[#dyingCells + 1] = {
                        row = row,
                        column = column
                    }
                end
            else
                if neighbors == 3 then
                    snapshot[row][column] = 1
                    living = living + 1
                else
                    snapshot[row][column] = 0
                end
            end
        end
    end

    if self.modeId == GameOfLife.MODE_ENDLESS then
        living = self:applyEndlessReinforcement(snapshot, source, dyingCells, living)
    end

    if living == 0 then
        for row = 1, self.rows do
            for column = 1, self.columns do
                snapshot[row][column] = math.random() < self.seedChance and 1 or 0
            end
        end
        lifeLog("reseeded after extinction")
    end

    return snapshot
end

function GameOfLife:applyEndlessReinforcement(snapshot, source, dyingCells, living)
    if living >= self.endlessMaxLiveCells or #dyingCells == 0 then
        return living
    end

    local attempts = math.min(#dyingCells * 2, 28)
    for _ = 1, attempts do
        if living >= self.endlessMaxLiveCells then
            break
        end

        local dying = dyingCells[math.random(1, #dyingCells)]
        if math.random() < 0.55 then
            local spawnCount = 1 + math.random(0, 2)
            for _spawn = 1, spawnCount do
                if living >= self.endlessMaxLiveCells then
                    break
                end

                local spawnRow = clamp(dying.row + math.random(-1, 1), 1, self.rows)
                local spawnColumn = clamp(dying.column + math.random(-1, 1), 1, self.columns)
                if not (spawnRow == dying.row and spawnColumn == dying.column)
                    and snapshot[spawnRow][spawnColumn] == 0
                    and source[spawnRow][spawnColumn] == 0 then
                    snapshot[spawnRow][spawnColumn] = 1
                    living = living + 1
                end
            end
        end
    end

    return living
end

function GameOfLife:stepGeneration()
    local snapshot = self:buildNextSnapshot(self.grid)
    self:restoreGrid(snapshot)
    self:appendHistorySnapshot(snapshot, true)
    self:markRecordingDirty("generation")
end

function GameOfLife:advanceToSnapshot(snapshot)
    self:restoreGrid(snapshot)
    self:appendHistorySnapshot(snapshot, false)
    self:markRecordingDirty("scrub-forward")
end

function GameOfLife:advanceGeneration()
    if self.historyCursor < #self.history then
        self.historyCursor = self.historyCursor + 1
        self:restoreGrid(self.history[self.historyCursor])
        self:markRecordingDirty("history-forward")
        return
    end

    if #self.futureBuffer > 0 then
        local snapshot = table.remove(self.futureBuffer, 1)
        self:advanceToSnapshot(snapshot)
        return
    end

    self:stepGeneration()
end

function GameOfLife:triggerScrubLimitWarning()
    self.scrubLimitWarningFrames = 12
end

function GameOfLife:advanceScrubGeneration()
    if self.historyCursor < #self.history then
        self.historyCursor = self.historyCursor + 1
        self:restoreGrid(self.history[self.historyCursor])
        self:markRecordingDirty("scrub-history-forward")
        return true
    end

    if self.historyCursor == self.liveHistoryCount and not self.futureAdvanceArmed then
        self.futureAdvanceArmed = true
        self:triggerScrubLimitWarning()
        return false
    end

    if #self.futureBuffer > 0 then
        local snapshot = table.remove(self.futureBuffer, 1)
        self:advanceToSnapshot(snapshot)
        return true
    end

    self:triggerScrubLimitWarning()
    return false
end

function GameOfLife:stepGenerations(count)
    local steps = math.max(0, math.floor(count or 0))
    if steps > 0 then
        lifeLog("step generations requested: %d", steps)
    end
    for _ = 1, steps do
        if not self:advanceScrubGeneration() then
            break
        end
    end
    self.accumulator = 0
end

function GameOfLife:rewindGenerations(count)
    local steps = math.max(0, math.floor(count or 0))
    local changed = false
    if steps > 0 then
        lifeLog("rewind generations requested: %d", steps)
    end

    for _ = 1, steps do
        if self.historyCursor <= 1 then
            break
        end

        self.historyCursor = self.historyCursor - 1
        self:restoreGrid(self.history[self.historyCursor])
        changed = true
    end

    self.futureAdvanceArmed = false
    self.accumulator = 0
    if changed then
        self:markRecordingDirty("scrub-rewind")
    end
end

function GameOfLife:prefetchFutureFrames()
    if self.historyCursor ~= #self.history or self.futureBufferLimit <= 0 then
        return
    end

    local startTime = pd.getCurrentTimeMilliseconds()

    while #self.futureBuffer < self.futureBufferLimit do
        local source = self.grid
        if #self.futureBuffer > 0 then
            source = self.futureBuffer[#self.futureBuffer]
        end

        self.futureBuffer[#self.futureBuffer + 1] = self:buildNextSnapshot(source)

        if (pd.getCurrentTimeMilliseconds() - startTime) >= self.prefetchBudgetMs then
            break
        end
    end
end

function GameOfLife:updateBackground()
    if self.reviewMode then
        self.reviewBlinkFrame = self.reviewBlinkFrame + 1
        return
    end

    if self.preview then
        return
    end

    if self.scrubLimitWarningFrames > 0 then
        self.scrubLimitWarningFrames = self.scrubLimitWarningFrames - 1
        self.scrubLimitPhase = self.scrubLimitPhase + 1
    end

    self:prefetchFutureFrames()
end

function GameOfLife:update()
    if self.reviewMode then
        self:updateBackground()
        return
    end

    if self.preview then
        if not self.previewFrames or #self.previewFrames == 0 then
            lifeLog("preview update rebuilding frames history=%d", #self.history)
            self:buildPreviewFrames()
        end

        self.accumulator = self.accumulator + (self.speed / 100)
        while self.accumulator >= 1 do
            self.accumulator = self.accumulator - 1

            if self.previewFrames and #self.previewFrames > 1 then
                local nextIndex = self.previewFrameIndex + self.previewDirection
                if nextIndex > #self.previewFrames then
                    self.previewDirection = -1
                    nextIndex = #self.previewFrames - 1
                elseif nextIndex < 1 then
                    self.previewDirection = 1
                    nextIndex = 2
                end

                self.previewFrameIndex = clamp(nextIndex, 1, #self.previewFrames)
                self:restoreGrid(self.previewFrames[self.previewFrameIndex])
            end
        end

        if self.previewFrames == nil or #self.previewFrames == 0 then
            lifeLogError("preview update has no frames after rebuild mode=%s history=%d", tostring(self.modeId), #self.history)
        end

        self:updateBackground()
        return
    end

    self.futureAdvanceArmed = false
    self.accumulator = self.accumulator + (self.speed / 100)

    while self.accumulator >= 1 do
        self:advanceGeneration()
        self.accumulator = self.accumulator - 1
    end

    self:updateBackground()
end

function GameOfLife:drawReviewBrowser()
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawText("Review Life", 10, 8)
    gfx.drawText("Up/Down: pick  Left/Right: action  A: confirm  B: title", 10, 24)

    if #self.reviewEntries == 0 then
        gfx.drawTextInRect(self.reviewStatusMessage or "No recordings found.", 24, 90, 352, 40, nil, nil, kTextAlignment.center)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        return
    end

    local startIndex = math.max(1, self.reviewSelection - 2)
    local endIndex = math.min(#self.reviewEntries, startIndex + 4)
    if endIndex - startIndex < 4 then
        startIndex = math.max(1, endIndex - 4)
    end

    for index = startIndex, endIndex do
        local entry = self.reviewEntries[index]
        local y = 64 + ((index - startIndex) * 24)
        local label = (entry.favorite and "* " or "  ") .. entry.name
        if index == self.reviewSelection then
            gfx.fillRect(22, y - 2, 356, 18)
            gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
            gfx.drawText(label, 28, y)
            gfx.setImageDrawMode(gfx.kDrawModeInverted)
        else
            gfx.drawText(label, 28, y)
        end
    end

    local selectedEntry = self:getSelectedReviewEntry()
    local action = self.reviewActions[self.reviewActionIndex]
    gfx.drawText("Action: " .. self:getReviewActionLabel(action, selectedEntry), 10, 204)
    if self.reviewStatusMessage then
        gfx.drawTextInRect(self.reviewStatusMessage, 10, 220, 380, 16, nil, nil, kTextAlignment.center)
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function GameOfLife:drawReviewPlayback()
    local frame = self.reviewLoadedFrame
    if not frame then
        gfx.setImageDrawMode(gfx.kDrawModeInverted)
        gfx.drawTextInRect("Playback missing.", 24, 110, 352, 20, nil, nil, kTextAlignment.center)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        return
    end

    gfx.setColor(gfx.kColorWhite)
    local centerX = self.width / 2
    local centerY = self.height / 2
    local drawSize = math.max(1, self.cellSize - 1)

    for _, cell in ipairs(frame.cells) do
        local x = ((cell.column - 0.5) * self.cellSize)
        local y = ((cell.row - 0.5) * self.cellSize)
        local rx, ry = rotatePoint(x - centerX, y - centerY, self.screenAngle)
        gfx.fillRect((centerX + rx) - (drawSize / 2), (centerY + ry) - (drawSize / 2), drawSize, drawSize)
    end

    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawText("Review Life", 10, 8)
    gfx.drawText(string.format("%s  Frame %d/%d", self.reviewLoadedEntry and self.reviewLoadedEntry.name or "", self.reviewFrameCursor, self.reviewFrameCount or 0), 10, 24)
    gfx.drawText("Crank: scrub  Left/Right: step  B: browser", 10, 220)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function GameOfLife:drawScrubLimitWarning()
    if self.scrubLimitWarningFrames <= 0 then
        return
    end

    local phase = self.scrubLimitPhase
    gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer8x8, phase, phase)

    for x = 0, self.width - 1 do
        if ((x + phase) % 2) == 0 then
            gfx.fillRect(x, 0, 1, 2)
            gfx.fillRect(x, self.height - 2, 1, 2)
        end
    end

    for y = 2, self.height - 3 do
        if ((y + phase) % 2) == 0 then
            gfx.fillRect(0, y, 2, 1)
            gfx.fillRect(self.width - 2, y, 2, 1)
        end
    end

    gfx.setColor(gfx.kColorWhite)
end

function GameOfLife:draw()
    if self.reviewMode then
        if self.reviewState == "playback" then
            self:drawReviewPlayback()
        else
            self:drawReviewBrowser()
        end
        return
    end

    gfx.setColor(gfx.kColorWhite)
    local centerX = self.width / 2
    local centerY = self.height / 2
    local drawSize = math.max(1, self.cellSize - 1)

    for row = 1, self.rows do
        for column = 1, self.columns do
            if self.grid[row][column] == 1 then
                local x = ((column - 0.5) * self.cellSize)
                local y = ((row - 0.5) * self.cellSize)
                local rx, ry = rotatePoint(x - centerX, y - centerY, self.screenAngle)
                gfx.fillRect((centerX + rx) - (drawSize / 2), (centerY + ry) - (drawSize / 2), drawSize, drawSize)
            end
        end
    end

    self:drawScrubLimitWarning()

    if self.recordingEnabled and not self.preview then
        gfx.setImageDrawMode(gfx.kDrawModeInverted)
        gfx.drawText(string.format("REC %d", self.recordingFrame), 10, 8)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    end

    self:flushRecording()
end
