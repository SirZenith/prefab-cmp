local M = {}

---@class TSNode
---@field field fun(self, name: string): TSNode[]

---@enum NodeType
local NodeType = {
    accessibility_modifier = "accessibility_modifier",
    arguments = "arguments",
    call_expression = "call_expression",
    class_declaration = "class_declaration",
    decorator = "decorator",
    import_clause = "import_clause",
    named_imports = "named_imports",
    import_specifier = "import_specifier",
    import_statement = "import_statement",
    object = "object",
    pair = "pair",
    string_fragment = "string_fragment",
    variable_declarator = "variable_declarator",
}
M.NodeType = NodeType

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

return M
