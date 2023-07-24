local util = require "prefab-cmp.util"
local id_info = require "prefab-cmp.ident_info"
local NodeType = require "prefab-cmp.node-type.typescript"

local treesitter = vim.treesitter
local IdentInfo = id_info.IdentInfo

---@param scope Scope
---@param node TSNode
---@param result? DispatchResult
local function get_gameobject_path(scope, node, result)
    local ident = result and result.ident
    if not ident then return end

    local value_node = node:field("value")[1]
    if not value_node then return end

    if value_node:type() ~= "call_expression" then
        return
    end

    -- --------------------------------------------------------------------

    local arguments_node = value_node:field("arguments")[1]
    if not arguments_node then return end

    local first_arg_node = arguments_node:named_child(0)
    if not first_arg_node or first_arg_node:type() ~= "string" then return end

    local path_value_node = first_arg_node:named_child(0) or first_arg_node
    local path = scope:get_node_text(path_value_node)

    -- --------------------------------------------------------------------

    local function_node = value_node:field("function")[1]
    if not function_node then return end

    if function_node:type() ~= "member_expression" then
        return
    end

    local object_node = function_node:field("object")[1]
    local property_node = function_node:field("property")[1]
    if not (object_node and property_node) then return end

    local property_name = scope:get_node_text(property_node)
    if property_name ~= "getGameObject" then return end

    local object_name = scope:get_node_text(object_node)

    -- --------------------------------------------------------------------

    if object_name ~= "this" then
        ident:add_extra_info("parent", object_name)
    end
    ident:add_extra_info("path", path)
end

---@param buffer table<string, string>
---@param comment string
local function extract_prefab_path_from_comment(buffer, comment)
    for name, path in comment:gmatch("prefab: ([%w_]+) %- (.+%.prefab)") do
        buffer[name] = path
    end
end

---@param source prefab-cmp.Source
---@param scope Scope
---@param node TSNode
---@param result? DispatchResult
local function get_prefab_path_comment_for_function(source, scope, node, result)
    local func_scope = result and result.scope
    if not func_scope then return end

    local walker = node:parent()
    if not walker then return end

    if walker:type() == NodeType.variable_declarator then
        walker = walker:parent()
        if not walker then return end
    end

    local prefab_path_map = {} ---@type table<string, string>
    walker = walker:prev_sibling()

    while walker and walker:type() == NodeType.comment do
        local comment = scope:get_node_text(walker)
        extract_prefab_path_from_comment(prefab_path_map, comment)

        walker = walker:prev_sibling()
    end

    for name, path in pairs(prefab_path_map) do
        -- TODO make source able to multiplexing between different prefab
        source:set_active_prefab(path)

        local ident = func_scope:get_ident(name)
        if ident then
            ident:add_extra_info("prefab_path", path)
        end
    end
end

---@type ScopeHookMap
local hook_map = {
    [NodeType.arrow_function] = function(source, scope, node, result)
        get_prefab_path_comment_for_function(source, scope, node, result)
    end,

    [NodeType.class_declaration] = function(source, scope, node, _)
        local bufnr = scope.bufnr

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

        source:set_active_prefab(path)
    end,

    [NodeType.variable_declarator] = function(_, scope, node, result)
        get_gameobject_path(scope, node, result)
    end,
}

return hook_map
