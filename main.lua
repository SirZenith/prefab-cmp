local api = vim.api
local bufoption = vim.bo

local filetype = "typescript"

---@class TSNode
---@field field fun(self, name: string): TSNode[]

---@enum NodeType
local NodeType = {
    arguments = "arguments",
    call_expression = "call_expression",
    class_declaration = "class_declaration",
    decorator = "decorator",
    object = "object",
    pair = "pair",
    string_fragment = "string_fragment",
}

local M = {}

---@param node TSNode
---@param ... NodeType
---@return TSNode | nil
function M.get_child(node, ...)
    local types = { ... }
    if #types == 0 then return end

    local walker = node

    for _, type in ipairs(types) do
        if not walker then break end

        local next_step
        for child in walker:iter_children() do
            if child:type() == type then
                next_step = child
                break
            end
        end
        walker = next_step
    end

    return walker
end

---@param node TSNode
---@param type NodeType
---@return TSNode[]
function M.filter_children(node, type)
    local result = {}
    for child in node:iter_children() do
        if child:type() == type then
            table.insert(result, child)
        end
    end
    return result
end

---@param bufnr number
---@param class_decl TSNode
---@return string | nil prefab_path
function M.get_prefab_path(bufnr, class_decl)
    local metainfo = M.get_child(
        class_decl,
        NodeType.decorator,
        NodeType.call_expression,
        NodeType.arguments,
        NodeType.object
    )
    if not metainfo then return end

    local value
    local meta_entries = M.filter_children(metainfo, NodeType.pair)
    for _, entry in ipairs(meta_entries) do
        local key = entry:field("key")[1]
        local key_name = vim.treesitter.get_node_text(key, bufnr)
        if key_name == "prefabPath" then
            value = entry:field("value")[1]
            break
        end
    end
    if not value then return end

    local str = M.get_child(value, NodeType.string_fragment)
    if not str then return end

    local path = vim.treesitter.get_node_text(str, bufnr)

    return path
end

---@param bufnr number
---@param class_decl TSNode
function M.load_class_data(bufnr, class_decl)
    local name = class_decl:field("name")[1]
end

---@param bufnr number
function M.init_buf(bufnr)
    local parser = vim.treesitter.get_parser(bufnr, filetype)
    local tree = parser:parse()[1] ---@type TSTree | nil
    if not tree then
        return
    end

    local root = tree:root()
    local class_decl = M.get_child(root, NodeType.class_declaration)
    if not class_decl then return end

    local prefab_path = M.get_prefab_path(bufnr, class_decl)
    vim.print(prefab_path)
end

local bufs = api.nvim_list_bufs()
local target
for _, buf in ipairs(bufs) do
    if bufoption[buf].filetype == filetype then
        target = buf
    end
end

if not target then
    vim.print("target not found")
    return
end

M.init_buf(target)
