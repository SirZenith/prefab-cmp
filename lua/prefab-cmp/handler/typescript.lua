local ident_info = require "prefab-cmp.ident_info"
local scope = require "prefab-cmp.scope"
local util = require "prefab-cmp.util"

local IdentType = ident_info.IdentType
local IdentInfo = ident_info.IdentInfo
local Scope = scope.Scope
local ScopeType = scope.ScopeType
local NodeType = util.NodeType

---@type ScopeHandlerMap
local handler_map = {

    class_body = function(self, node)
        self:load_named_node_child(node)
    end,

    class_declaration = function(self, node)
        local name_node = node:field("name")[1]
        local name = self:get_node_text(name_node)

        local body_node = node:field("body")[1]
        local child_scope = Scope:new_lazy(self.bufnr, ScopeType.class, body_node)
        child_scope.name = name
        self:add_child(child_scope)

        local row, col, byte = node:start()
        local this = IdentInfo:dummy(IdentType.variable, "this", {
            row = row, col = col, byte = byte,
        })
        table.insert(child_scope.identifiers, this)

        local ident = IdentInfo:new(IdentType.class, self.bufnr, name_node)

        return ident
    end,

    comment = true,

    expression_statement = true,

    formal_parameters = function(self, node)
        self:load_named_node_child(node)
    end,

    for_in_statement = function(self, node)
        local body_node = node:field("body")[1]
        local child_scope = Scope:new_lazy(self.bufnr, ScopeType.for_in_block, body_node)

        local modifier_node = node:field("kind")[1]
        local modifier = self:get_node_text(modifier_node)

        local name_node = node:field("left")[1]
        local ident = IdentInfo:new(IdentType.variable, self.bufnr, name_node)
        ident.modifier[modifier] = true

        table.insert(child_scope.identifiers, ident)
    end,

    for_statement = function(self, node)
        local init_node = node:field("initializer")[1]
        local body_node = node:field("body")[1]
        local child_scope = Scope:new_lazy(self.bufnr, ScopeType.for_block, body_node, init_node)
        self:add_child(child_scope)
    end,

    if_statement = function(self, node)
        local body_node = node:field("consequence")[1]
        local child_scope = Scope:new_lazy(self.bufnr, ScopeType.if_block, body_node)
        self:add_child(child_scope)
    end,

    identifier = function(self, node)
        return IdentInfo:new(IdentType.variable, self.bufnr, node)
    end,

    import_statement = function(self, node)
        local named_import = util.get_child(node, NodeType.import_clause, NodeType.named_imports)
        if not named_import then return end

        local specifiers = util.filter_children(named_import, NodeType.import_specifier)
        local result = {}
        for _, spec in ipairs(specifiers) do
            local name_node = spec:field("name")[1]
            local ident = IdentInfo:new(IdentType.external, self.bufnr, name_node)
            table.insert(result, ident)
        end

        return result
    end,

    lexical_declaration = function(self, node)
        local kind_node = node:field("kind")[1]
        local kind = self:get_node_text(kind_node)

        local result = self:dispatch_to_handler(node:named_child(0))
        if not result then
            -- pass
        elseif getmetatable(result) == IdentInfo then
            result.modifier[kind] = true
        else
            for _, info in ipairs(result) do
                info.modifier[kind_node] = true
            end
        end

        return result
    end,

    method_definition = function(self, node)
        local modifier_node = util.get_child(node, NodeType.accessibility_modifier)
        local modifier = modifier_node and self:get_node_text(modifier_node)

        local name_node = node:field("name")[1]
        local name = self:get_node_text(name_node)

        local param_node = node:field("parameters")[1]
        local body_node = node:field("body")[1]

        local child_scope = Scope:new_lazy(self.bufnr, ScopeType.method, body_node, param_node)
        child_scope.name = name
        self:add_child(child_scope)

        local ident = IdentInfo:new(IdentType.method, self.bufnr, name_node)
        if modifier then
            ident.modifier[modifier] = true
        end

        return ident
    end,

    object_pattern = function(self, node)
        self:load_named_node_child(node)
    end,

    optional_parameter = function(self, node)
        local name_node = node:field("pattern")[1]
        return IdentInfo:new(IdentType.parameter, self.bufnr, name_node)
    end,

    pair_pattern = function(self, node)
        local name_node = node:field("value")[1]
        if name_node:type() ~= "identifier" then
            return
        end
        return IdentInfo:new(IdentType.variable, self.bufnr, name_node)
    end,

    public_field_definition = function(self, node)
        local modifier_node = util.get_child(node, NodeType.accessibility_modifier)
        local modifier = modifier_node and self:get_node_text(modifier_node)

        local name_node = node:field("name")[1]

        local ident = IdentInfo:new(IdentType.field, self.bufnr, name_node)
        if modifier then
            ident.modifier[modifier] = true
        end

        return ident
    end,

    required_parameter = function(self, node)
        local name_node = node:field("pattern")[1]
        return IdentInfo:new(IdentType.parameter, self.bufnr, name_node)
    end,

    return_statement = true,

    shorthand_property_identifier_pattern = function(self, node)
        return IdentInfo:new(IdentType.variable, self.bufnr, node)
    end,

    variable_declarator = function(self, node)
        local name_node = node:field("name")[1]
        local result = self:dispatch_to_handler(name_node)

        return result
    end,

    statement_block = function(self, node)
        self:load_named_node_child(node)
    end,

}

return handler_map
