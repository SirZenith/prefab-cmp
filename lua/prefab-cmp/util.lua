local M = {}

---@class TSNode
---@field field fun(self, name: string): TSNode[]

---@class NodeType

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
