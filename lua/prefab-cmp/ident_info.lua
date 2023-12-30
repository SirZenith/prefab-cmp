local treesitter = vim.treesitter

---@enum prefab-cmp.IdentType
local IdentType = {
    class = "class",
    external = "external",
    field = "field",
    ["function"] = "function",
    interface = "interface",
    method = "method",
    namespace = "namespace",
    parameter = "parameter",
    ["type"] = "type",
    variable = "variable",
}

---@enum Modifier
local Modifier = {
    const = "const",
    var = "var",
    let = "let",
}

---@class prefab-cmp.IdentInfo
---@field type prefab-cmp.IdentType
---@field name string
---@field st_pos prefab-cmp.Position
---@field modifier table<Modifier, boolean>
---@field extra_info? table<string, any>
local IdentInfo = {}
IdentInfo.__index = IdentInfo

---@param type prefab-cmp.IdentType
---@param node TSNode
---@return prefab-cmp.IdentInfo
function IdentInfo:new(type, bufnr, node)
    local obj = setmetatable({}, self) ---@type prefab-cmp.IdentInfo

    local name = treesitter.get_node_text(node, bufnr)
    local row, col, byte = node:start()

    obj.type = type
    obj.name = name
    obj.st_pos = { row = row, col = col, byte = byte }
    obj.modifier = {}

    return obj
end

---@param type prefab-cmp.IdentType
---@param name string
---@param pos prefab-cmp.Position
function IdentInfo:new_raw(type, name, pos)
    local obj = setmetatable({}, self) ---@type prefab-cmp.IdentInfo

    obj.type = type
    obj.name = name
    obj.st_pos = pos
    obj.modifier = {}

    return obj
end

---@param key string
---@param value any
function IdentInfo:add_extra_info(key, value)
    if not self.extra_info then
        self.extra_info = {}
    end
    self.extra_info[key] = value
end

---@param key string
---@return any
function IdentInfo:get_extra_info(key)
    if not self.extra_info then return end
    return self.extra_info[key]
end

return {
    IdentType = IdentType,
    Modifier = Modifier,
    IdentInfo = IdentInfo,
}
