import "systems/tutorials"

SettingsScene = {}
SettingsScene.__index = SettingsScene
local pd <const> = playdate
local gfx <const> = pd.graphics

function SettingsScene.new(config)
    local self = setmetatable({}, SettingsScene)
    self.onReturn = config.onReturn
    self.index = 1
    self.message = nil
    return self
end

function SettingsScene:getItems()
    return {
        "Show UI: " .. (UIState.isShown() and "ON" or "OFF"),
        "Reset Tutorials",
        "Attributions",
        "Back"
    }
end

function SettingsScene:update()
    local items = self:getItems()
    if pd.buttonJustPressed(pd.kButtonUp) then self.index = ((self.index - 2) % #items) + 1 end
    if pd.buttonJustPressed(pd.kButtonDown) then self.index = (self.index % #items) + 1 end
    if pd.buttonJustPressed(pd.kButtonB) then self.onReturn() return end
    if pd.buttonJustPressed(pd.kButtonA) then
        if self.index == 1 then UIState.setShown(not UIState.isShown())
        elseif self.index == 2 then Tutorials.reset(); self.message = "Tutorials reset."
        elseif self.index == 3 then self.message = "Starry Messenger - Dean Sheldon\nBuilt with the Playdate SDK.\nOpen-source libraries and media retain\ntheir respective creator attributions."
        else self.onReturn() return end
    end
    gfx.clear(gfx.kColorBlack)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawTextAligned("Settings", 200, 24, kTextAlignment.center)
    for index, item in ipairs(items) do
        local y = 62 + ((index - 1) * 28)
        if index == self.index then gfx.fillRoundRect(52, y - 3, 296, 22, 5); gfx.setImageDrawMode(gfx.kDrawModeFillBlack) end
        gfx.drawTextAligned(item, 200, y, kTextAlignment.center)
        gfx.setImageDrawMode(gfx.kDrawModeInverted)
    end
    if self.message then gfx.drawTextInRect(self.message, 48, 184, 304, 45, nil, nil, kTextAlignment.center) else gfx.drawTextAligned("A select  B back", 200, 210, kTextAlignment.center) end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end
