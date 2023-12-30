local util = require "prefab-cmp.util"
local NodeType = require "prefab-cmp.node-type.typescript"
local ident_info = require "prefab-cmp.ident_info"

local IdentType = ident_info.IdentType
local IdentInfo = ident_info.IdentInfo

local treesitter = vim.treesitter

local M = {}

---@param buffer table<string, string>
---@param comment string
local function extract_from_comment(buffer, comment)
    for name, path in comment:gmatch("prefab: ([%w_]+) %- (.+%.prefab)") do
        buffer[name] = path
    end
end

---@param buffer table<string, string>
---@param walker TSNode
---@param scope prefab-cmp.Scope
local function walk_though_comment(buffer, walker, scope)
    while walker and walker:type() == NodeType.comment do
        local comment = scope:get_node_text(walker)
        extract_from_comment(buffer, comment)
        walker = walker:prev_named_sibling()
    end
end

---@param buffer table<string, string>
---@param scope prefab-cmp.Scope
local function update_scope_ident(buffer, scope)
    for name, path in pairs(buffer) do
        local ident = scope:get_ident(name)
        if ident then
            ident:add_extra_info("prefab_path", path)
        else
            ident = IdentInfo:new_raw(IdentType.variable, name, { row = 0, col = 0, byte = 0 })
            ident:add_extra_info("prefab_path", path)
            scope:add_ident(ident)
        end
    end
end

-- ----------------------------------------------------------------------------

---@param scope prefab-cmp.Scope
---@param node TSNode
---@param result? DispatchResult
function M.from_function_comment(scope, node, result)
    local func_scope = result and result.scope
    if not func_scope then return end

    local walker = node:parent()
    if not walker then return end

    if walker:type() == NodeType.variable_declarator then
        walker = walker:parent()
        if not walker then return end
    end

    local parent = walker:parent();
    if parent and parent:type() == NodeType.export_statement then
        walker = parent:prev_named_sibling();
    else
        walker = node:prev_named_sibling();
    end

    local prefab_path_map = {} ---@type table<string, string>
    walk_though_comment(prefab_path_map, walker, scope)

    update_scope_ident(prefab_path_map, func_scope)
end

---@param scope prefab-cmp.Scope
---@param node TSNode
---@param result? DispatchResult
function M.from_method_comment(scope, node, result)
    local method_scope = result and result.scope
    if not method_scope then return end

    local prefab_path_map = {} ---@type table<string, string>
    local walker = node:prev_named_sibling()
    walk_though_comment(prefab_path_map, walker, scope)

    update_scope_ident(prefab_path_map, method_scope)
end

---@param scope prefab-cmp.Scope
---@param node TSNode
---@param result DispatchResult
---@return string? path
function M.from_decorator(scope, node, result)
    local bufnr = scope.bufnr
    local class_scope = result.scope
    if not class_scope then return end

    local parent = node:parent()
    if parent and parent:type() == NodeType.export_statement then
        node = parent
    end

    local metainfo = util.get_child(
        node,
        NodeType.decorator,
        NodeType.call_expression,
        NodeType.arguments,
        NodeType.object
    )
    if not metainfo then return end

    local value
    local meta_entries = util.filter_children(metainfo, NodeType.pair)
    for _, entry in ipairs(meta_entries) do
        local key = entry:field("key")[1]
        local key_name = treesitter.get_node_text(key, bufnr)
        if key_name == "prefabPath" then
            value = entry:field("value")[1]
            break
        end
    end
    if not value then return end

    local str = util.get_child(value, NodeType.string_fragment)
    if not str then return end

    local path = treesitter.get_node_text(str, bufnr)

    update_scope_ident({ this = path }, class_scope)
end

---@param scope prefab-cmp.Scope
---@param node TSNode
---@param result DispatchResult
function M.from_class_comment(scope, node, result)
    local class_scope = result.scope
    if not class_scope then return end

    local name_node = node:field("name")[1]
    if not name_node then return end

    local prefab_path_map = {} ---@type table<string, string>

    local walker = name_node:prev_named_sibling()
    walk_though_comment(prefab_path_map, walker, scope)

    local parent = node:parent();
    if parent and parent:type() == NodeType.export_statement then
        walker = parent:prev_named_sibling();
    else
        walker = node:prev_named_sibling();
    end
    walk_though_comment(prefab_path_map, walker, scope)

    update_scope_ident(prefab_path_map, class_scope)
end

return M
