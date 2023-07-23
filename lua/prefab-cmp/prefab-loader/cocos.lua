local game_object = require "prefab-cmp.game-object"

local GameObject = game_object.GameObject

---@alias prefab-loader.cocos.IDInfo { __id__: number }

---@class prefab-loader.cocos.GameObjectJson
---@field _name string
---@field data prefab-loader.cocos.IDInfo
---@field _children? prefab-loader.cocos.IDInfo[]
---@field _components? prefab-loader.cocos.IDInfo[]

---@alias prefab-loader.cocos.Prefab prefab-loader.cocos.GameObjectJson[]

---@param path string
---@return prefab-loader.cocos.Prefab
---@return string | nil err
local function load_raw_prefab(path)
    local file, err = io.open(path, "r")
    if not file then
        return {}, err
    end

    local content = file:read("a")
    local prefab = vim.json.decode(content)

    return prefab
end

---@param prefab prefab-loader.cocos.Prefab
---@param index number
---@return GameObject
local function wrap(prefab, index)
    local go_json = prefab[index]
    if not go_json then
        local msg = ("prefab index out of range: %d of %d"):format(index, #prefab)
        vim.notify(msg, vim.log.levels.WARN)
        return GameObject:new("")
    end

    local json_children = go_json._children or {} --[[@as prefab-loader.cocos.IDInfo[] ]]

    local name = go_json._name or ("unnamed-" .. tostring(index))
    local go = GameObject:new(name)

    local children = {}
    local child_map = {}
    for _, info in ipairs(json_children) do
        local child_index = (info.__id__ or -1) + 1

        if prefab[child_index] then
            local child = wrap(prefab, child_index)
            table.insert(children, child)
            child_map[child.name] = child
        end
    end

    go.children = children
    go.child_map = child_map

    return go
end

---@param path string
---@return GameObject
---@return string | nil err
local function load_prefab(path)
    local prefab, err = load_raw_prefab(path)
    if err then
        return GameObject:new("error"), ("while loading prefab: %q"):format(err)
    end

    local info = prefab[1]
    local id = info.data.__id__
    return wrap(prefab, id + 1)
end

return {
    load_prefab = load_prefab,
}
