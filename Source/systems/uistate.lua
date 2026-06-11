-- Shared in-view UI visibility flag.
UIState = {}
UIState.showUI = false

function UIState.isShown()
    return UIState.showUI == true
end

function UIState.setShown(shown)
    UIState.showUI = shown == true
end
