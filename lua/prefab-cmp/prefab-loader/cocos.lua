local config = require "prefab-cmp.config"
local game_object = require "prefab-cmp.game-object"

local GameObject = game_object.GameObject

local INVALID_ID = -1
local INVALID_TYPE = "NULL"

---@type table<string, fun(go: prefab-cmp.GameObject, value: any)>
local OVERRIDE_HANDLER_MAP = {
    _name = function(go, value)
        go.name = value
    end,
}

local M = {}

---@type nil | (fun(path: string, uuid: string): string?)
M._uuid_to_path_func = nil

---@param path string
---@return prefab-loader.cocos.Prefab
---@return string | nil err
function M.load_raw_prefab_with_path(path)
    local file, err = io.open(path, "r")
    if not file then
        return {}, err
    end

    local content = file:read("a")
    local prefab = vim.json.decode(content)

    return prefab
end

---@param func fun(path: string, uuid: string): string? # a function that converts UUID to file path
function M.set_uuid_convertor(func)
    if type(func) ~= "function" then
        local msg = "UUID convertor only accepts function value, get: " .. type(func)
        vim.notify(msg, vim.log.levels.ERROR)
        return
    end

    M._uuid_to_path_func = func
end

-- ----------------------------------------------------------------------------

---@param prefab prefab-loader.cocos.Prefab
---@param id integer
---@return prefab-loader.cocos.PrefabEntry | nil
local function get_obj(prefab, id)
    return prefab[id + 1]
end

---@param go prefab-cmp.GameObject
---@param file_id string
---@return prefab-cmp.GameObject | nil child
local function get_child_by_file_id(go, file_id)
    local extra_info = go.extra_info
    if not extra_info then return end

    if extra_info.file_id == file_id then
        return go
    end

    local child_file_id = extra_info.child_file_id
    return child_file_id and child_file_id[file_id]
end

---@param prefab prefab-loader.cocos.Prefab
---@param go prefab-cmp.GameObject
---@param override_info prefab-cmp.prefab-loader.cocos.IDInfo
local function prefab_prop_override_single(prefab, go, override_info)
    local override_id = override_info.__id__
    local override_json = get_obj(prefab, override_id)
    if not override_json then return end

    local override_target = override_json.targetInfo --[[@as prefab-cmp.prefab-loader.cocos.IDInfo]]
    if not override_target then return end

    local target_id = override_target.__id__
    local target_json = get_obj(prefab, target_id)
    local target_list = target_json and target_json.localID or {}

    local prop_names = override_json.propertyPath --[[@as string[] ]]
    local value = override_json.value --[[@as any]]

    for _, file_id in ipairs(target_list) do
        local child = get_child_by_file_id(go, file_id)
        if child then
            for _, prop_name in ipairs(prop_names) do
                local handler = OVERRIDE_HANDLER_MAP[prop_name]
                if handler then
                    handler(go, value)
                end
            end
        end
    end
end

---@param prefab prefab-loader.cocos.Prefab
---@param go prefab-cmp.GameObject
---@param override_list prefab-cmp.prefab-loader.cocos.IDInfo[]
local function prefab_prop_override(prefab, go, override_list)
    for _, id_info in ipairs(override_list) do
        prefab_prop_override_single(prefab, go, id_info)
    end
end

-- Try to find actual file for a referenced prefab and loaded it.
---@param path string # prefab file path
---@param prefab prefab-loader.cocos.Prefab
---@param go_json prefab-cmp.prefab-loader.cocos.GameObjectJson
---@param id integer # object id in prefab
---@return prefab-cmp.GameObject
function M.wrap_prefab_reference(path, prefab, go_json, id)
    local ref_id_info = go_json._prefab
    local ref_id = ref_id_info and ref_id_info.__id__ or INVALID_ID
    local prefab_info = get_obj(prefab, ref_id)
    if not prefab_info then
        local msg = ("can't find prefab reference info for node-#%d in %s"):format(id, path)
        vim.notify(msg, vim.log.levels.WARN)
        return GameObject:new("")
    end

    local asset_info = prefab_info.asset
    local uuid = asset_info and asset_info.__uuid__
    local go, uuid_err = M.load_prefab_with_uuid(path, uuid)
    if uuid_err then
        vim.notify(uuid_err, vim.log.levels.WARN)
        return GameObject:new("")
    end

    local instance_info = prefab_info.instance
    local instance_id = instance_info and instance_info.__id__
    local instance_json = get_obj(prefab, instance_id)
    local override_info = instance_json and instance_json.propertyOverrides or
    {} --[[@as prefab-cmp.prefab-loader.cocos.IDInfo]]
    prefab_prop_override(prefab, go, override_info)

    return go
end

---@param path string # prefab file path
---@param prefab prefab-loader.cocos.Prefab
---@param go_json prefab-cmp.prefab-loader.cocos.GameObjectJson
---@param id integer # object id in prefab
---@return prefab-cmp.GameObject
function M.wrap_plain_gojson(path, prefab, go_json, id)
    local json_children = go_json._children or {} --[[@as prefab-cmp.prefab-loader.cocos.IDInfo[] ]]

    local name = go_json._name or ("unnamed-" .. tostring(id))
    local go = GameObject:new(name)

    local children = {}
    local child_map = {}
    local extra_info = go.extra_info or {}
    local child_file_id_map = extra_info.child_file_id or {}
    for _, info in ipairs(json_children) do
        local child_id = info.__id__ or INVALID_ID

        if prefab[child_id] then
            local child = M.wrap(path, prefab, child_id)
            table.insert(children, child)
            child_map[child.name] = child

            local child_exinfo = child.extra_info
            if child_exinfo and child_exinfo.file_id then
                child_file_id_map[child_exinfo.file_id] = child
            end
        end
    end

    extra_info.child_file_id = child_file_id_map
    go.extra_info = extra_info
    go.children = children
    go.child_map = child_map

    return go
end

-- Wrap a game object json in to a GameObject.
---@param path string # prefab file path
---@param prefab prefab-loader.cocos.Prefab
---@param id integer # object id in prefab
---@return prefab-cmp.GameObject
function M.wrap(path, prefab, id)
    local go_json = get_obj(prefab, id)
    local node_type = go_json and go_json.__type__ or INVALID_ID
    local err
    if not go_json then
        err = ("prefab index out of range: %d of %d"):format(id, #prefab)
    elseif node_type ~= "cc.Node" then
        err = ("invalid node type for prefab-loader.cocos.wrap: " .. type)
    end

    if err then
        vim.notify(err, vim.log.levels.WARN)
        return GameObject:new("")
    end

    go_json = go_json --[[@as prefab-cmp.prefab-loader.cocos.GameObjectJson]]
    local go
    if go_json._children then
        go = M.wrap_plain_gojson(path, prefab, go_json, id)
    else
        go = M.wrap_prefab_reference(path, prefab, go_json, id)
    end

    local prefab_info = go_json._prefab
    local prefab_id = prefab_info and prefab_info.__id__
    if prefab_id then
        local info_json = get_obj(prefab, prefab_id)
        local file_id = info_json and info_json.fileId --[[@as string?]]
        if file_id then
            local extra_info = go.extra_info or {}
            extra_info.file_id = file_id
            go.extra_info = extra_info
        end
    end

    return go
end

-- ----------------------------------------------------------------------------

---@param path string
---@return prefab-cmp.GameObject
---@return string | nil err
function M.load_prefab(path)
    local prefab, err = M.load_raw_prefab_with_path(path)
    if err then
        return GameObject:new(""), ("while loading prefab: %q"):format(err)
    end

    local info = prefab[1]
    local root_data = info and info.data
    local id = root_data and root_data.__id__
    if not id then
        return GameObject:new(""), "can't find root node in prefab: " .. path
    end

    return M.wrap(path, prefab, id)
end

---@param path string # path of prefab which depends on the prefab to be load
---@param uuid string
---@return prefab-cmp.GameObject
---@return string | nil err
function M.load_prefab_with_uuid(path, uuid)
    local to_path = M._uuid_to_path_func
    if type(to_path) ~= "function" then
        return GameObject:new(""), "no UUID covertor functon provided"
    end

    local prefab_path = to_path(path, uuid)
    if not prefab_path then
        return GameObject:new(""), "failed to convert UUID: " .. uuid
    end

    return M.load_prefab(prefab_path)
end

-- ----------------------------------------------------------------------------

function M.setup()
    M.set_uuid_convertor(config.prefab_loader.cocos.uuid_convertor)
end

return M
