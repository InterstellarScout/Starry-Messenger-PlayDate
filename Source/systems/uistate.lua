-- Shared in-view UI visibility flag.
UIState = {}
local pd <const> = playdate
local SAVE_KEY <const> = "starry-ui-settings-v1"
local saved = pd.datastore and pd.datastore.read and pd.datastore.read(SAVE_KEY) or nil
UIState.showUI = not (type(saved) == "table" and saved.showUI == false)

function UIState.isShown()
    return UIState.showUI == true
end

function UIState.setShown(shown)
    UIState.showUI = shown == true
    if pd.datastore and pd.datastore.write then
        pd.datastore.write({ showUI = UIState.showUI }, SAVE_KEY)
    end
end
