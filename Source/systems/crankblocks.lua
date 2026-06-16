--[[
Crank Blocks.

Purpose:
- Tetris-inspired falling block toy
- crank moves the active piece up and down, D-pad moves sideways, A hard-drops
]]
import "gameconfig"
local pd <const> = playdate
local gfx <const> = pd.graphics
local CRANK_BLOCKS_CONFIG <const> = GameConfig and GameConfig.crankBlocks or {}

CrankBlocks = {}
CrankBlocks.__index = CrankBlocks

local COLS <const> = 10
local ROWS <const> = 18
local CELL <const> = 10
local BOARD_X <const> = 150
local BOARD_Y <const> = 28
local CRANK_STEP <const> = 18
local ALLOW_UP_MOVE <const> = CRANK_BLOCKS_CONFIG.allowUpMove ~= false
local SAVE_KEY <const> = "crankblocks_stats"

local SHAPES <const> = {
    { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } },
    { { -1, 0 }, { 0, 0 }, { 1, 0 }, { 2, 0 } },
    { { -1, 0 }, { 0, 0 }, { 1, 0 }, { 0, 1 } },
    { { -1, 0 }, { 0, 0 }, { 0, 1 }, { 1, 1 } },
    { { 1, 0 }, { 0, 0 }, { 0, 1 }, { -1, 1 } }
}

local function newGrid()
    local grid = {}
    for y = 1, ROWS do
        grid[y] = {}
    end
    return grid
end

function CrankBlocks.new(width, height, options)
    options = options or {}
    local self = setmetatable({}, CrankBlocks)
    self.width = width
    self.height = height
    self.preview = options.preview == true
    self.grid = newGrid()
    self.current = nil
    self.crankAccumulator = 0
    self.gravityTimer = 0
    self.lines = 0
    self.totalLines = 0
    self.sessionLines = 0
    self.totalBlocksDropped = 0
    self.sessionBlocksDropped = 0
    self.statusMessage = nil
    self.statusFrames = 0
    self:loadStats()
    self:spawnPiece()
    return self
end

function CrankBlocks:loadStats()
    local ok, data = pcall(function()
        return pd.datastore.read(SAVE_KEY)
    end)
    if ok and type(data) == "table" then
        self.totalLines = tonumber(data.totalLines) or 0
        self.totalBlocksDropped = tonumber(data.totalBlocksDropped) or 0
    end
end

function CrankBlocks:saveStats()
    pcall(function()
        pd.datastore.write({
            totalLines = self.totalLines or 0,
            totalBlocksDropped = self.totalBlocksDropped or 0
        }, SAVE_KEY)
    end)
end

function CrankBlocks:setPreview(isPreview)
    self.preview = isPreview == true
end

function CrankBlocks:spawnPiece()
    self.current = {
        shape = SHAPES[math.random(1, #SHAPES)],
        x = math.floor(COLS * 0.5),
        y = 1
    }
    if self:collides(self.current.x, self.current.y) then
        self.grid = newGrid()
        self.lines = 0
        self.statusMessage = "Reset"
        self.statusFrames = 50
    end
end

function CrankBlocks:collides(x, y)
    if self.current == nil then
        return true
    end
    for _, cell in ipairs(self.current.shape) do
        local cx = x + cell[1]
        local cy = y + cell[2]
        if cx < 1 or cx > COLS or cy > ROWS then
            return true
        end
        if cy >= 1 and self.grid[cy][cx] then
            return true
        end
    end
    return false
end

function CrankBlocks:lockPiece()
    if self.current == nil then
        return
    end
    for _, cell in ipairs(self.current.shape) do
        local cx = self.current.x + cell[1]
        local cy = self.current.y + cell[2]
        if cy >= 1 and cy <= ROWS and cx >= 1 and cx <= COLS then
            self.grid[cy][cx] = true
        end
    end
    self:clearLines()
    self.totalBlocksDropped = self.totalBlocksDropped + 1
    self.sessionBlocksDropped = self.sessionBlocksDropped + 1
    self:saveStats()
    self:spawnPiece()
end

function CrankBlocks:clearLines()
    local y = ROWS
    while y >= 1 do
        local full = true
        for x = 1, COLS do
            if not self.grid[y][x] then
                full = false
                break
            end
        end
        if full then
            table.remove(self.grid, y)
            table.insert(self.grid, 1, {})
            self.lines = self.lines + 1
            self.totalLines = self.totalLines + 1
            self.sessionLines = self.sessionLines + 1
        else
            y = y - 1
        end
    end
end

function CrankBlocks:rotatePiece(direction)
    if self.current == nil then
        return
    end
    local rotated = {}
    for index, cell in ipairs(self.current.shape) do
        local x, y = cell[1], cell[2]
        if direction >= 0 then
            rotated[index] = { -y, x }
        else
            rotated[index] = { y, -x }
        end
    end
    local previous = self.current.shape
    self.current.shape = rotated
    if self:collides(self.current.x, self.current.y) then
        self.current.shape = previous
    end
end

function CrankBlocks:move(dx, dy)
    if self.current == nil then
        return false
    end
    local nextX = self.current.x + dx
    local nextY = self.current.y + dy
    if self:collides(nextX, nextY) then
        if dy > 0 then
            self:lockPiece()
        end
        return false
    end
    self.current.x = nextX
    self.current.y = nextY
    return true
end

function CrankBlocks:handlePrimaryAction()
    self:rotatePiece(1)
end

function CrankBlocks:applyCrank(change)
    self.crankAccumulator = self.crankAccumulator + (change or 0)
    while math.abs(self.crankAccumulator) >= CRANK_STEP do
        local direction = self.crankAccumulator > 0 and 1 or -1
        self:rotatePiece(direction)
        self.crankAccumulator = self.crankAccumulator - (CRANK_STEP * direction)
    end
end

function CrankBlocks:handleDirectionalInput(leftPressed, rightPressed, upPressed, downPressed)
    if leftPressed then
        self:move(-1, 0)
    elseif rightPressed then
        self:move(1, 0)
    end
    if upPressed and ALLOW_UP_MOVE then
        self:move(0, -1)
    elseif downPressed then
        self:move(0, 1)
    end
end

function CrankBlocks:update()
    if self.statusFrames > 0 then
        self.statusFrames = self.statusFrames - 1
        if self.statusFrames <= 0 then
            self.statusMessage = nil
        end
    end
    self.gravityTimer = self.gravityTimer + 1
    if self.gravityTimer >= 24 then
        self.gravityTimer = 0
        self:move(0, 1)
    end
end

function CrankBlocks:drawCell(x, y, filled)
    local px = BOARD_X + ((x - 1) * CELL)
    local py = BOARD_Y + ((y - 1) * CELL)
    if filled then
        gfx.fillRect(px + 1, py + 1, CELL - 2, CELL - 2)
    else
        gfx.drawRect(px + 1, py + 1, CELL - 2, CELL - 2)
    end
end

function CrankBlocks:draw()
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, self.width, self.height)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(BOARD_X - 2, BOARD_Y - 2, COLS * CELL + 4, ROWS * CELL + 4)

    for y = 1, ROWS do
        for x = 1, COLS do
            if self.grid[y][x] then
                self:drawCell(x, y, true)
            end
        end
    end

    if self.current ~= nil then
        for _, cell in ipairs(self.current.shape) do
            local x = self.current.x + cell[1]
            local y = self.current.y + cell[2]
            if y >= 1 then
                self:drawCell(x, y, false)
            end
        end
    end

    if not UIState or UIState.isShown() then
        gfx.drawText("Crank Blocks", 8, 8)
        gfx.drawText("Rows " .. tostring(self.lines), 8, 26)
        gfx.drawText("Total Rows " .. tostring(self.totalLines), 252, 60)
        gfx.drawText("Total Blocks " .. tostring(self.totalBlocksDropped), 252, 78)
        gfx.drawText("Session Rows " .. tostring(self.sessionLines), 252, 106)
        gfx.drawText("Session Blocks " .. tostring(self.sessionBlocksDropped), 252, 124)
        if self.statusMessage then
            gfx.drawText(self.statusMessage, 8, 44)
        end
    end
end
