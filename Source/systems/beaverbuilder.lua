--[[ Beaver Builder: a procedural river-and-dam game. ]]
local pd <const> = playdate
local gfx <const> = pd.graphics
BeaverBuilder = {}
BeaverBuilder.__index = BeaverBuilder
local TREE_COUNT <const> = 14
local GRASS_COUNT <const> = 110
local TREE_HEALTH <const> = 5
local PLAYER_SPEED <const> = 2.1
local LOG_FRICTION <const> = 0.91
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function d2(ax, ay, bx, by) local x, y = ax - bx, ay - by return x * x + y * y end

function BeaverBuilder.new(width, height, options)
    local self = setmetatable({}, BeaverBuilder)
    self.width, self.height = width or 400, height or 240
    self.preview = options and options.preview == true
    self.frame, self.riverSeed = 0, math.random() * math.pi * 2
    self.player = { x = self.width * .5, y = 68, dx = 1, dy = 0, inputX = 0, inputY = 0 }
    self.trees, self.logs, self.grass, self.draggedLog = {}, {}, {}, nil
    self.status = "A: chew a tree   Hold A: drag a log"
    self:seedTerrain()
    return self
end
function BeaverBuilder:setPreview(enabled) self.preview = enabled == true end
function BeaverBuilder:riverCenterAt(x)
    return self.height * .5 + math.sin(x * .031 + self.riverSeed) * 14 + math.sin(x * .071 + self.riverSeed * 2) * 7
end
function BeaverBuilder:riverHalfHeightAt(x)
    local h = 24
    for _, log in ipairs(self.logs) do
        if log.dammed then local upstream = log.x - x; if upstream >= 0 and upstream < 135 then h = h + (1 - upstream / 135) * 16 end end
    end
    return h
end
function BeaverBuilder:isRiverAt(x, y, extra) return math.abs(y - self:riverCenterAt(x)) <= self:riverHalfHeightAt(x) + (extra or 0) end
function BeaverBuilder:randomLandPoint()
    for _ = 1, 80 do
        local x, y = 18 + math.random() * (self.width - 36), 49 + math.random() * (self.height - 82)
        if not self:isRiverAt(x, y, 18) then return x, y end
    end
    return 30, 55
end
function BeaverBuilder:seedTerrain()
    for _ = 1, TREE_COUNT do local x, y = self:randomLandPoint(); self.trees[#self.trees + 1] = { x = x, y = y, health = TREE_HEALTH, seed = math.random() * math.pi * 2 } end
    for _ = 1, GRASS_COUNT do local x, y = self:randomLandPoint(); self.grass[#self.grass + 1] = { x = x, y = y, h = math.random(3, 8), seed = math.random() * math.pi * 2 } end
end
function BeaverBuilder:handleDirectionalInput(left, right, up, down)
    self.player.inputX, self.player.inputY = (right and 1 or 0) - (left and 1 or 0), (down and 1 or 0) - (up and 1 or 0)
end
function BeaverBuilder:getNearbyTree()
    for _, tree in ipairs(self.trees) do if d2(self.player.x, self.player.y, tree.x, tree.y) < 625 then return tree end end
end
function BeaverBuilder:getNearbyFreeLog()
    local closest, best = nil, 961
    for _, log in ipairs(self.logs) do if not log.dammed then local distance = d2(self.player.x, self.player.y, log.x, log.y); if distance < best then closest, best = log, distance end end end
    return closest
end
function BeaverBuilder:handlePrimaryAction()
    local tree = self:getNearbyTree()
    if not tree then return end
    tree.health = tree.health - 1; self.status = "Chewing... " .. math.max(0, tree.health) .. "/5 bark left"
    if tree.health <= 0 then
        self.logs[#self.logs + 1] = { x = tree.x, y = tree.y, vx = 0, vy = 0, seed = tree.seed, dammed = false }
        for i, candidate in ipairs(self.trees) do if candidate == tree then table.remove(self.trees, i); break end end
        self.status = "Timber! Push the log into the river."
    end
end
function BeaverBuilder:updatePlayer()
    local p, x, y = self.player, self.player.inputX or 0, self.player.inputY or 0
    local length = math.sqrt(x * x + y * y)
    if length > 0 then
        x, y = x / length, y / length; p.dx, p.dy = x, y
        p.x, p.y = clamp(p.x + x * PLAYER_SPEED, 10, self.width - 10), clamp(p.y + y * PLAYER_SPEED, 48, self.height - 28)
    end
end
function BeaverBuilder:updateLogs()
    local holding = not self.preview and pd.buttonIsPressed(pd.kButtonA)
    if holding and not self.draggedLog then self.draggedLog = self:getNearbyFreeLog() end
    if not holding then self.draggedLog = nil end
    for _, log in ipairs(self.logs) do
        if log == self.draggedLog and not log.dammed then
            log.x, log.y, log.vx, log.vy = self.player.x - self.player.dx * 16, self.player.y - self.player.dy * 16, 0, 0
        elseif not log.dammed then
            if d2(self.player.x, self.player.y, log.x, log.y) < 400 then log.vx, log.vy = log.vx + self.player.dx * .55, log.vy + self.player.dy * .55 end
            log.x, log.y = clamp(log.x + log.vx, 8, self.width - 8), clamp(log.y + log.vy, 45, self.height - 24)
            log.vx, log.vy = log.vx * LOG_FRICTION, log.vy * LOG_FRICTION
            if self:isRiverAt(log.x, log.y, 2) then log.dammed, log.vx, log.vy, self.draggedLog, self.status = true, 0, 0, nil, "The upstream pool is growing!" end
        end
    end
end
function BeaverBuilder:update()
    self.frame = self.frame + 1
    if self.preview then self.player.inputX, self.player.inputY = math.cos(self.frame * .035), math.sin(self.frame * .025) end
    self:updatePlayer(); self:updateLogs()
end
function BeaverBuilder:drawRiver()
    gfx.setColor(gfx.kColorBlack); gfx.setDitherPattern(.38, gfx.image.kDitherTypeBayer8x8)
    for x = 0, self.width, 3 do local c, h = self:riverCenterAt(x), self:riverHalfHeightAt(x); gfx.drawLine(x, c - h, x, c + h) end
    gfx.setDitherPattern(1, gfx.image.kDitherTypeBayer8x8)
end
function BeaverBuilder:drawGrass()
    gfx.setColor(gfx.kColorBlack)
    for _, blade in ipairs(self.grass) do local sway = math.sin(self.frame * .08 + blade.seed) * 1.5; gfx.drawLine(blade.x, blade.y, blade.x + sway, blade.y - blade.h) end
end
function BeaverBuilder:drawTree(tree)
    gfx.setColor(gfx.kColorBlack); gfx.fillRect(tree.x - 2, tree.y - 3, 5, 15); gfx.drawCircleAtPoint(tree.x, tree.y - 9, 9); gfx.drawCircleAtPoint(tree.x - 6, tree.y - 3, 6); gfx.drawCircleAtPoint(tree.x + 6, tree.y - 3, 6)
    for bark = 1, tree.health do gfx.drawLine(tree.x - 4, tree.y + bark, tree.x + 4, tree.y + bark) end
end
function BeaverBuilder:drawLog(log)
    gfx.setColor(gfx.kColorBlack); gfx.fillRoundRect(log.x - 14, log.y - 4, 28, 8, 4); gfx.setColor(gfx.kColorWhite); gfx.drawLine(log.x - 10, log.y, log.x + 10, log.y); gfx.setColor(gfx.kColorBlack)
    if log.dammed then gfx.drawText("+", log.x - 3, log.y - 17) end
end
function BeaverBuilder:drawBeaver()
    local p, x, y = self.player, math.floor(self.player.x + .5), math.floor(self.player.y + .5)
    gfx.setColor(gfx.kColorWhite); gfx.fillEllipseInRect(x - 10, y - 7, 20, 14); gfx.fillCircleAtPoint(x + p.dx * 7, y - 5, 6)
    gfx.setColor(gfx.kColorBlack); gfx.drawEllipseInRect(x - 10, y - 7, 20, 14); gfx.drawCircleAtPoint(x + p.dx * 7, y - 5, 6); gfx.fillRect(x - p.dx * 14, y - 2, 7, 6); gfx.drawLine(x + p.dx * 10, y - 4, x + p.dx * 14, y - 4)
end
function BeaverBuilder:draw()
    gfx.clear(gfx.kColorWhite); self:drawGrass(); self:drawRiver()
    for _, tree in ipairs(self.trees) do self:drawTree(tree) end
    for _, log in ipairs(self.logs) do self:drawLog(log) end
    self:drawBeaver()
    if not self.preview and (not UIState or UIState.isShown()) then
        gfx.setColor(gfx.kColorBlack); gfx.drawTextAligned("BEAVER BUILDER", self.width * .5, 8, kTextAlignment.center); gfx.drawText("Trees " .. #self.trees .. "  Dams " .. #self.logs, 10, 24); gfx.drawTextAligned(self.status, self.width * .5, 214, kTextAlignment.center); gfx.drawTextAligned("D-pad move   A chew / hold drag", self.width * .5, 228, kTextAlignment.center)
    end
end
