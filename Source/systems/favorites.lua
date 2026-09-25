Favorites = {}
local pd <const> = playdate
local KEY <const> = "starry-favorites-v1"
local saved = pd.datastore and pd.datastore.read and pd.datastore.read(KEY) or nil
Favorites.ids = type(saved) == "table" and type(saved.ids) == "table" and saved.ids or {}
local function save()
    if pd.datastore and pd.datastore.write then pd.datastore.write({ ids = Favorites.ids }, KEY) end
end
function Favorites.has(id)
    for _, value in ipairs(Favorites.ids) do if value == id then return true end end
    return false
end
function Favorites.toggle(id)
    for index, value in ipairs(Favorites.ids) do
        if value == id then table.remove(Favorites.ids, index); save(); return false end
    end
    Favorites.ids[#Favorites.ids + 1] = id
    save()
    return true
end