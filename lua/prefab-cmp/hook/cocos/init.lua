local id_info = require "prefab-cmp.ident_info"
local NodeType = require "prefab-cmp.node-type.typescript"
local extract_path = require "prefab-cmp.hook.cocos.extract-prefab-path"

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

    ident:add_extra_info("parent_object", object_name)
    ident:add_extra_info("game_object_path", path)
end

-- ----------------------------------------------------------------------------

---@type ScopeHookMap
local hook_map = {
    arrow_function = function(_, scope, node, result)
        extract_path.from_function_comment(scope, node, result)
    end,

    class_declaration = function(_, scope, node, result)
        extract_path.from_class_comment(scope, node, result)
        extract_path.from_decorator(scope, node, result)
    end,

    method_definition = function(_, scope, node, result)
        extract_path.from_method_comment(scope, node, result)
    end,

    variable_declarator = function(_, scope, node, result)
        get_gameobject_path(scope, node, result)
    end,
}

return hook_map
