---@alias IDInfo { __id__: number }

---@alias Prefab GameObjectJson[]

---@param path string
---@return Prefab
---@return string | nil err
local function load_prefab(path)
    local file, err = io.open(path, "r")
    if not file then
        return {}, err
    end

    local content = file:read("a")
    local prefab = vim.json.decode(content)

    return prefab
end

---@class GameObjectJson
---@field _name string
---@field data IDInfo
---@field _children? IDInfo[]
---@field _components? IDInfo[]

---@class GameObject
---@field name string
---@field children GameObject[]
---@field child_map table<string, GameObject>
local GameObject = {}
GameObject.__index = GameObject

function GameObject:__tostring()
    return table.concat(self:format({}, ''))
end

---@param prefab Prefab
---@param index number
---@return GameObject
function GameObject.wrap(prefab, index)
    local go_json = prefab[index]
    if not go_json then
        local msg = ("index out of range: %d of %d"):format(index, #prefab)
        error(msg)
    end

    local obj = setmetatable({}, GameObject)
    local children = {}
    local child_map = {}
    local json_children = go_json._children or {} --[[@as IDInfo[] ]]

    for _, info in ipairs(json_children) do
        local child_index = (info.__id__ or -1) + 1

        if prefab[child_index] then
            local child = GameObject.wrap(prefab, child_index)
            table.insert(children, child)
            child_map[child.name] = child
        end
    end

    obj.name = go_json._name or ("unnamed-" .. tostring(index))
    obj.children = children
    obj.child_map = child_map

    return obj
end

---@param path string
function GameObject.from_prefab(path)
    local prefab = load_prefab(path)
    local info = prefab[1]
    local id = info.data.__id__
    return GameObject.wrap(prefab, id + 1)
end

---@param buffer string[]
---@param indent string
---@return string[] buffer
function GameObject:format(buffer, indent)
    table.insert(buffer, self.name)

    local len = #self.children

    local child_indent = indent .. '│   '
    local last_indent = indent .. '    '
    for i = 1, len do
        local is_last = i == len
        local child = self.children[i]

        if child then
            table.insert(buffer, "\n")
            table.insert(buffer, indent)

            local prefix = is_last and '└── ' or '├── '
            table.insert(buffer, prefix)

            local new_indent = is_last and last_indent or child_indent
            child:format(buffer, new_indent)
        end
    end

    return buffer
end

---@param path string
function GameObject:get_child(path)
    local walker = self
    local st, len = 1, #path

    for i = 1, len do
        local char = path:sub(i, i)
        if char == "/" then
            if i - 1 >= st then
                local segment = path:sub(st, i - 1)
                walker = walker.child_map[segment]
            end

            st = i + 1
        end

        if not walker then break end
    end

    if walker and st < len then
        local segment = path:sub(st, len)
        walker = walker.child_map[segment]
    end

    return walker
end

return GameObject
