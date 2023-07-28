local ident_info = require "prefab-cmp.ident_info"
local scope = require "prefab-cmp.scope"
local util = require "prefab-cmp.util"

local NodeType = require "prefab-cmp.node-type.typescript"

local IdentType = ident_info.IdentType
local IdentInfo = ident_info.IdentInfo
local Scope = scope.Scope
local ScopeType = scope.ScopeType


---@type ScopeHandlerMap
local handler_map = {
    abstract_class_declaration = function(self, node)
        local name_node = node:field("name")[1]
        local name = self:get_node_text(name_node)

        -- class scope
        local body_node = node:field("body")[1]
        local child_scope = Scope:new_lazy(self, name, ScopeType.abstract_class, body_node)

        -- `this` symbol
        local row, col, byte = node:start()
        local this = IdentInfo:new_raw(IdentType.variable, "this", {
            row = row, col = col, byte = byte,
        })
        child_scope:add_ident(this)

        -- class as a symbol
        local ident = IdentInfo:new(IdentType.class, self.bufnr, name_node)

        return {
            ident = ident,
            scope = child_scope,
        }
    end,

    arrow_function = function(self, node)
        local name = "anonymous function"
        local parent = node:parent()
        if parent and parent:type() == "variable_declarator" then
            local name_node = parent:field("name")[1]
            name = self:get_node_text(name_node)
        end

        local param_node = node:field("parameters")[1]
        local body_node = node:field("body")[1]

        local child_scope = Scope:new_lazy(self, name, ScopeType.method, body_node)
        child_scope:load_node(param_node)

        local row, col, byte
        if parent then
            row, col, byte = parent:start()
        else
            row, col, byte = node:start()
        end

        local ident = IdentInfo:new_raw(IdentType["function"], name, {
            row = row, col = col, byte = byte,
        })

        return {
            scope = child_scope,
            ident = ident,
        }
    end,

    class_body = function(self, node)
        self:load_named_node_child(node)
    end,

    class_declaration = function(self, node)
        local name_node = node:field("name")[1]
        local name = self:get_node_text(name_node)

        -- class scope
        local body_node = node:field("body")[1]
        local child_scope = Scope:new_lazy(self, name, ScopeType.class, body_node)

        -- `this` symbol
        local row, col, byte = node:start()
        local this = IdentInfo:new_raw(IdentType.variable, "this", {
            row = row, col = col, byte = byte,
        })
        child_scope:add_ident(this)

        -- class as a symbol
        local ident = IdentInfo:new(IdentType.class, self.bufnr, name_node)

        return {
            ident = ident,
            scope = child_scope,
        }
    end,

    comment = true,

    enum_declaration = true,

    ERROR = true,

    export_statement = function(self, node)
        local decl_node = node:field("declaration")[1]
        return self:dispatch_to_handler(decl_node)
    end,

    expression_statement = true,

    formal_parameters = function(self, node)
        self:load_named_node_child(node)
    end,

    for_in_statement = function(self, node)
        -- loop body
        local body_node = node:field("body")[1]
        local child_scope = Scope:new_lazy(self, "for-in", ScopeType.for_in_block, body_node)
        child_scope:mimic(self)

        -- iterate variable
        local modifier_node = node:field("kind")[1]
        local modifier = self:get_node_text(modifier_node)

        local name_node = node:field("left")[1]
        local ident = IdentInfo:new(IdentType.variable, self.bufnr, name_node)
        ident.modifier[modifier] = true

        child_scope:add_ident(ident)

        return {
            scope = child_scope,
        }
    end,

    for_statement = function(self, node)
        local init_node = node:field("initializer")[1]
        local body_node = node:field("body")[1]
        local child_scope = Scope:new_lazy(self, "for", ScopeType.for_block, body_node, init_node)
        child_scope:mimic(self)
        return {
            scope = child_scope,
        }
    end,

    ["function"] = function(self, node)
        local name = "anonymous function"
        local name_node = node:field("name")[1]
        local range_node = node
        if not name_node then
            local parent = node:parent()
            if parent and parent:type() == "variable_declarator" then
                range_node = parent
                name_node = parent:field("name")[1]
            end
        end

        if name_node then
            name = self:get_node_text(name_node)
        end

        local param_node = node:field("parameters")[1]
        local body_node = node:field("body")[1]

        local child_scope = Scope:new_lazy(self, name, ScopeType.method, body_node)
        child_scope:load_node(param_node)

        local row, col, byte = range_node:start()

        local ident = IdentInfo:new_raw(IdentType["function"], name, {
            row = row, col = col, byte = byte
        })

        return {
            ident = ident,
            scope = child_scope,
        }
    end,

    if_statement = function(self, node)
        local body_node = node:field("consequence")[1]
        local child_scope = Scope:new_lazy(self, "if", ScopeType.if_block, body_node)
        return {
            scope = child_scope,
        }
    end,

    identifier = function(self, node)
        return {
            ident = IdentInfo:new(IdentType.variable, self.bufnr, node),
        }
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

        return {
            ident_list = result,
        }
    end,

    interface_declaration = true,

    internal_module = function(self, node)
        local name_node = node:field("name")[1]
        local body_node = node:field("body")[1]
        if not (name_node and body_node) then return end

        -- namespace scope
        local name = self:get_node_text(name_node)
        local child_scope = Scope:new(self, name, ScopeType.namespace, body_node)
        child_scope:load_node(body_node)

        -- namespace as symbol
        local row, col, byte = node:start()
        local ident = IdentInfo:new_raw(IdentType.namespace, name, {
            row = row, col = col, byte = byte
        })

        return {
            ident = ident,
            scope = child_scope,
        }
    end,

    lexical_declaration = function(self, node)
        local kind_node = node:field("kind")[1]
        local kind = self:get_node_text(kind_node)

        local result = self:dispatch_to_handler(node:named_child(0))
        if not result then return end

        if result.ident then
            result.ident.modifier[kind] = true
        end

        if result.ident_list then
            for _, ident in ipairs(result.ident_list) do
                ident.modifier[kind] = true
            end
        end

        return result
    end,

    method_definition = function(self, node)
        local modifier_node = util.get_child(node, NodeType.accessibility_modifier)
        local modifier = modifier_node and self:get_node_text(modifier_node)

        local name_node = node:field("name")[1]
        local name = self:get_node_text(name_node)

        -- method scope
        local param_node = node:field("parameters")[1]
        local body_node = node:field("body")[1]

        local child_scope = Scope:new_lazy(self, name, ScopeType.method, body_node)
        child_scope:load_node(param_node)

        -- method as a symbol
        local ident = IdentInfo:new(IdentType.method, self.bufnr, name_node)
        if modifier then
            ident.modifier[modifier] = true
        end

        return {
            ident = ident,
            scope = child_scope,
        }
    end,

    object_pattern = function(self, node)
        self:load_named_node_child(node)
    end,

    optional_parameter = function(self, node)
        local name_node = node:field("pattern")[1]
        return {
            ident = IdentInfo:new(IdentType.parameter, self.bufnr, name_node),
        }
    end,

    pair_pattern = function(self, node)
        local name_node = node:field("value")[1]
        if name_node:type() ~= "identifier" then
            return
        end
        return {
            ident = IdentInfo:new(IdentType.variable, self.bufnr, name_node),
        }
    end,

    public_field_definition = function(self, node)
        local modifier_node = util.get_child(node, NodeType.accessibility_modifier)
        local modifier = modifier_node and self:get_node_text(modifier_node)

        local name_node = node:field("name")[1]

        local ident = IdentInfo:new(IdentType.field, self.bufnr, name_node)
        if modifier then
            ident.modifier[modifier] = true
        end

        return {
            ident = ident,
        }
    end,

    required_parameter = function(self, node)
        local name_node = node:field("pattern")[1]
        return {
            ident = IdentInfo:new(IdentType.parameter, self.bufnr, name_node),
        }
    end,

    return_statement = true,

    shorthand_property_identifier_pattern = function(self, node)
        return {
            ident = IdentInfo:new(IdentType.variable, self.bufnr, node),
        }
    end,

    type_alias_declaration = true,

    variable_declarator = function(self, node)
        local value_node = node:field("value")[1]
        local name_node = node:field("name")[1]

        local value_type = value_node and value_node:type()

        local result
        if value_type == "arrow_function" or value_type == "function" then
            result = self:dispatch_to_handler(value_node)
        else
            result = self:dispatch_to_handler(name_node)
        end

        return result
    end,

    statement_block = function(self, node)
        self:load_named_node_child(node)
    end,
}

return handler_map
