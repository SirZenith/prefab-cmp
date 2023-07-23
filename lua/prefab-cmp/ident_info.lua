local treesitter = vim.treesitter

---@enum IdentType
local IdentType = {
    class = "class",
    external = "external",
    field = "field",
    ["function"] = "function",
    interface = "interface",
    method = "method",
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

---@class IdentInfo
---@field type IdentType
---@field name string
---@field st_pos Position
---@field modifier table<Modifier, boolean>
---@field extra_info? table<string, any>
local IdentInfo = {}
IdentInfo.__index = IdentInfo

---@param type IdentType
---@param node TSNode
---@return IdentInfo
function IdentInfo:new(type, bufnr, node)
    local obj = setmetatable({}, self) ---@type IdentInfo

    local name = treesitter.get_node_text(node, bufnr)
    local row, col, byte = node:start()

    obj.type = type
    obj.name = name
    obj.st_pos = { row = row, col = col, byte = byte }
    obj.modifier = {}

    return obj
end

---@param type IdentType
---@param name string
---@param pos Position
function IdentInfo:dummy(type, name, pos)
    local obj = setmetatable({}, self) ---@type IdentInfo

    obj.type = type
    obj.name = name
    obj.st_pos = pos
    obj.modifier = {}

    return obj
end

return {
    IdentType = IdentType,
    Modifier = Modifier,
    IdentInfo = IdentInfo,
}
