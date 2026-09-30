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
local LOG_LENGTH <const> = 42
local HUT_LOGS_REQUIRED <const> = 6
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function d2(ax, ay, bx, by) local x, y = ax - bx, ay - by return x * x + y * y end

function BeaverBuilder.new(width, height, options)
    local self = setmetatable({}, BeaverBuilder)
    self.width, self.height = width or 400, height or 240
    self.preview = options and options.preview == true
    self.frame, self.riverSeed = 0, math.random() * math.pi * 2
    self.player = { x = self.width * .5, y = 68, dx = 1, dy = 0, inputX = 0, inputY = 0 }
    self.trees, self.logs, self.grass, self.branches, self.draggedLog = {}, {}, {}, {}, nil
    self.breached, self.hut = false, nil
    self.status = "A: chew a tree   Hold A: drag or place logs"
    self:seedTerrain()
    return self
end
function BeaverBuilder:setPreview(enabled) self.preview = enabled == true end
function BeaverBuilder:riverCenterAt(x)
    return self.height * .5 + math.sin(x * .031 + self.riverSeed) * 14 + math.sin(x * .071 + self.riverSeed * 2) * 7
end
function BeaverBuilder:riverHalfHeightAt(x)
    local h = self.breached and 7 or 24
    for _, log in ipairs(self.logs) do
        if log.dammed then local upstream = log.x - x; if upstream >= 0 and upstream < 135 and not self.breached then h = h + (1 - upstream / 135) * 16 end end
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
    for _ = 1, TREE_COUNT do local x, y = self:randomLandPoint(); self.trees[#self.trees + 1] = { x = x, y = y, health = TREE_HEALTH, foliage = 4, shake = 0, seed = math.random() * math.pi * 2 } end
    for _ = 1, GRASS_COUNT do local x, y = self:randomLandPoint(); self.grass[#self.grass + 1] = { x = x, y = y, h = math.random(3, 8), seed = math.random() * math.pi * 2 } end
end
function BeaverBuilder:handleDirectionalInput(left, right, up, down)
    self.player.inputX, self.player.inputY = (right and 1 or 0) - (left and 1 or 0), (down and 1 or 0) - (up and 1 or 0)
end
function BeaverBuilder:getNearbyTree()
    for _, tree in ipairs(self.trees) do if d2(self.player.x, self.player.y, tree.x, tree.y) < 625 then return tree end end
end
function BeaverBuilder:getNearbyLog()
    local closest, best = nil, 961
    for _, log in ipairs(self.logs) do
        if not log.inHut then
            local distance = d2(self.player.x, self.player.y, log.x, log.y)
            if distance < best then closest, best = log, distance end
        end
    end
    return closest
end
function BeaverBuilder:handlePrimaryAction()
    local tree = self:getNearbyTree()
    if not tree then return end
    tree.health, tree.shake = tree.health - 1, 12
    if tree.foliage > 0 then
        local branchIndex = tree.foliage
        local branchOffsets = { { 0, -14 }, { -8, -8 }, { 8, -8 }, { 0, -4 } }
        local branch = branchOffsets[branchIndex]
        self.branches[#self.branches + 1] = {
            x = tree.x + branch[1], y = tree.y + branch[2], vx = (branch[1] == 0 and (math.random() - .5) * 2 or branch[1] * .12), vy = -1.5,
            seed = tree.seed + branchIndex, life = 80
        }
        tree.foliage = tree.foliage - 1
    end
    self.status = "Chewing... " .. math.max(0, tree.health) .. "/5 bark left"
    if tree.health <= 0 then
        self.logs[#self.logs + 1] = { x = tree.x, y = tree.y, vx = 0, vy = 0, seed = tree.seed, angle = 0, dammed = false, homePiece = false }
        for i, candidate in ipairs(self.trees) do if candidate == tree then table.remove(self.trees, i); break end end
        self.status = "Timber! Push the log into the river."
    end
end
function BeaverBuilder:releaseLog(log)
    local center, edgeDistance = self:riverCenterAt(log.x), math.abs(log.y - self:riverCenterAt(log.x))
    if self:isRiverAt(log.x, log.y, 0) then
        log.vx, log.vy = 0, 0
        if edgeDistance < 11 then
            -- A dam runs across the current, so snap the longer log perpendicular to it.
            log.y, log.angle, log.dammed, log.homePiece = center, math.pi * .5, true, false
            self.breached = false
            self.status = "Dam sealed. The pond is filling back up!"
        else
            log.dammed, log.homePiece = false, true
            self.status = "A water blob forms around the home log."
            self:tryBuildHut()
        end
    else
        log.dammed, log.homePiece = false, false
    end
end
function BeaverBuilder:tryBuildHut()
    local pieces = {}
    for _, log in ipairs(self.logs) do if log.homePiece and not log.inHut then pieces[#pieces + 1] = log end end
    if #pieces < HUT_LOGS_REQUIRED then return end
    local x, y = 0, 0
    for i = 1, HUT_LOGS_REQUIRED do x, y = x + pieces[i].x, y + pieces[i].y end
    x, y = x / HUT_LOGS_REQUIRED, y / HUT_LOGS_REQUIRED
    for i = 1, HUT_LOGS_REQUIRED do
        local log, angle = pieces[i], ((i - 1) / HUT_LOGS_REQUIRED) * math.pi * 2 - math.pi * .5
        log.x, log.y, log.angle, log.inHut, log.homePiece = x + math.cos(angle) * 19, y + math.sin(angle) * 15, angle + math.pi * .5, true, false
    end
    self.hut, self.status = { x = x, y = y }, "Home built! A six-log beaver hut stands."
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
    if holding and not self.draggedLog then
        self.draggedLog = self:getNearbyLog()
        if self.draggedLog and self.draggedLog.dammed then
            self.draggedLog.dammed, self.breached = false, true
            self.status = "The dam has a breach! Put the log back in the water."
        end
    end
    if not holding and self.draggedLog then self:releaseLog(self.draggedLog); self.draggedLog = nil end
    for _, log in ipairs(self.logs) do
        if log == self.draggedLog then
            log.x, log.y, log.vx, log.vy = self.player.x - self.player.dx * 16, self.player.y - self.player.dy * 16, 0, 0
        elseif not log.dammed and not log.inHut then
            if d2(self.player.x, self.player.y, log.x, log.y) < 400 then log.vx, log.vy = log.vx + self.player.dx * .55, log.vy + self.player.dy * .55 end
            log.x, log.y = clamp(log.x + log.vx, 8, self.width - 8), clamp(log.y + log.vy, 45, self.height - 24)
            log.vx, log.vy = log.vx * LOG_FRICTION, log.vy * LOG_FRICTION
        end
    end
end
function BeaverBuilder:updateBranches()
    for index = #self.branches, 1, -1 do
        local branch = self.branches[index]
        branch.x, branch.y, branch.vy, branch.life = branch.x + branch.vx, branch.y + branch.vy, branch.vy + .16, branch.life - 1
        if branch.y > self.height - 29 or branch.life <= 0 then table.remove(self.branches, index) end
    end
    for _, tree in ipairs(self.trees) do tree.shake = math.max(0, tree.shake - 1) end
end
function BeaverBuilder:update()
    self.frame = self.frame + 1
    if self.preview then self.player.inputX, self.player.inputY = math.cos(self.frame * .035), math.sin(self.frame * .025) end
    self:updatePlayer(); self:updateLogs(); self:updateBranches()
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
    local shake = tree.shake > 0 and math.sin(self.frame * 2.6) * (tree.shake / 3) or 0
    local x, y = tree.x + shake, tree.y
    local bushes = { { 0, -14, 8 }, { -8, -8, 6 }, { 8, -8, 6 }, { 0, -4, 7 } }
    gfx.setColor(gfx.kColorBlack); gfx.fillRect(x - 2, y - 3, 5, 15)
    for i = 1, tree.foliage do
        local bush = bushes[i]
        gfx.drawLine(x, y - 5, x + bush[1], y + bush[2] + 2)
        gfx.drawCircleAtPoint(x + bush[1], y + bush[2], bush[3])
    end
    for bark = 1, tree.health do gfx.drawLine(x - 4, y + bark, x + 4, y + bark) end
end
function BeaverBuilder:drawFallenBranches()
    gfx.setColor(gfx.kColorBlack)
    for _, branch in ipairs(self.branches) do
        gfx.drawLine(branch.x - 5, branch.y + 3, branch.x + 5, branch.y - 3)
        gfx.drawLine(branch.x, branch.y, branch.x + 3, branch.y + 4)
        gfx.drawCircleAtPoint(branch.x - 4, branch.y + 3, 3)
    end
end
function BeaverBuilder:drawLog(log)
    local angle, dx, dy = log.angle or 0, math.cos(log.angle or 0) * LOG_LENGTH * .5, math.sin(log.angle or 0) * LOG_LENGTH * .5
    gfx.setColor(gfx.kColorBlack); gfx.setLineWidth(8); gfx.drawLine(log.x - dx, log.y - dy, log.x + dx, log.y + dy); gfx.setLineWidth(1)
    gfx.setColor(gfx.kColorWhite); gfx.drawLine(log.x - dx * .7, log.y - dy * .7, log.x + dx * .7, log.y + dy * .7); gfx.setColor(gfx.kColorBlack)
    if log.dammed then gfx.drawText("+", log.x - 3, log.y - 17) end
    if log.homePiece then gfx.setDitherPattern(.45, gfx.image.kDitherTypeBayer8x8); gfx.fillCircleAtPoint(log.x, log.y, 13); gfx.setDitherPattern(1, gfx.image.kDitherTypeBayer8x8) end
end
function BeaverBuilder:drawHut()
    if not self.hut then return end
    gfx.setColor(gfx.kColorWhite); gfx.fillPolygon(self.hut.x, self.hut.y - 16, self.hut.x + 17, self.hut.y - 4, self.hut.x + 11, self.hut.y + 15, self.hut.x - 11, self.hut.y + 15, self.hut.x - 17, self.hut.y - 4)
    gfx.setColor(gfx.kColorBlack); gfx.drawPolygon(self.hut.x, self.hut.y - 16, self.hut.x + 17, self.hut.y - 4, self.hut.x + 11, self.hut.y + 15, self.hut.x - 11, self.hut.y + 15, self.hut.x - 17, self.hut.y - 4)
    gfx.fillCircleAtPoint(self.hut.x, self.hut.y + 5, 4)
end
function BeaverBuilder:drawBeaver()
    local p, x, y = self.player, math.floor(self.player.x + .5), math.floor(self.player.y + .5)
    gfx.setColor(gfx.kColorWhite); gfx.fillEllipseInRect(x - 10, y - 7, 20, 14); gfx.fillCircleAtPoint(x + p.dx * 7, y - 5, 6)
    local px, py = -p.dy, p.dx
    gfx.setColor(gfx.kColorBlack); gfx.drawEllipseInRect(x - 10, y - 7, 20, 14); gfx.drawCircleAtPoint(x + p.dx * 7, y - 5, 6); gfx.fillRect(x - p.dx * 14, y - 2, 7, 6); gfx.drawLine(x + p.dx * 10, y - 4, x + p.dx * 14, y - 4)
    -- Two small triangular teeth sit at the mouth, opposite the broad tail.
    local mouthX, mouthY = x + p.dx * 12, y + p.dy * 3
    gfx.fillPolygon(mouthX + px * 3, mouthY + py * 3, mouthX + px * 1, mouthY + py * 1, mouthX + p.dx * 5 + px * 2, mouthY + p.dy * 5 + py * 2)
    gfx.fillPolygon(mouthX - px * 3, mouthY - py * 3, mouthX - px, mouthY - py, mouthX + p.dx * 5 - px * 2, mouthY + p.dy * 5 - py * 2)
end
function BeaverBuilder:draw()
    gfx.clear(gfx.kColorWhite); self:drawGrass(); self:drawRiver()
    for _, tree in ipairs(self.trees) do self:drawTree(tree) end
    self:drawFallenBranches()
    for _, log in ipairs(self.logs) do self:drawLog(log) end
    self:drawHut()
    self:drawBeaver()
    if not self.preview and (not UIState or UIState.isShown()) then
        gfx.setColor(gfx.kColorBlack); gfx.drawTextAligned("BEAVER BUILDER", self.width * .5, 8, kTextAlignment.center); gfx.drawText("Trees " .. #self.trees .. "  Logs " .. #self.logs, 10, 24); gfx.drawTextAligned(self.status, self.width * .5, 214, kTextAlignment.center); gfx.drawTextAligned("D-pad move   A chew / hold drag", self.width * .5, 228, kTextAlignment.center)
    end
end
