local util = require "prefab-cmp.util"
local NodeType = require "prefab-cmp.node-type.typescript"

local treesitter = vim.treesitter

---@type ScopeHookMap<prefab-cmp.typescript.NodeType>
local hook_map = {
    [NodeType.class_declaration] = function(source, scope, node)
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
    [NodeType.variable_declarator] = function(_, scope, node)
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

        return {
            parent = object_name ~= "this" and object_name or nil,
            path = path,
        }
    end,
}

return hook_map
