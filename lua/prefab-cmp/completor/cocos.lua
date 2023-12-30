local treesitter = vim.treesitter

local M = {}

local FILE_TYPE = "typescript"

-- ----------------------------------------------------------------------------

-- trim single & double quote from both ends of string.
---@param str string
---@return string
function M.trim_quote(str)
    local fist_char = str:sub(1, 1)
    local len = #str
    local last_char = str:sub(len, len)

    if last_char == "\"" or last_char == "'" or last_char == "`" then
        str = str:sub(1, len - 1)
    end
    if fist_char == "\"" or fist_char == "'" or fist_char == "`" then
        str = str:sub(2)
    end

    return str
end

-- ----------------------------------------------------------------------------

-- Returns TSNode pointing to the object which getGameObject gets call on, returns
-- nil if no getGameObject call is found around node passed in.
---@param bufnr integer
---@param node TSNode
---@return TSNode?
function M.is_get_gameobject_call(bufnr, node)
    local call_node = node

    while call_node do
        if call_node:type() == "call_expression" then
            break
        end
        call_node = call_node:parent()
    end
    if not call_node then return end

    local function_node = call_node:field("function")[1]
    if function_node:type() ~= "member_expression" then return end

    local object_node = function_node:field("object")[1]
    local property_node = function_node:field("property")[1]
    if not (object_node and property_node) then return end

    local property_name = treesitter.get_node_text(property_node, bufnr)
    if property_name ~= "getGameObject" then return end

    return object_node
end

-- find node stande for getGameObject call at give cursor position
---@param bufnr integer
---@param pos { line: integer, character: integer }
---@return TSNode? path_node # node under cursor, which should also be the node pointing to path passed to getGameObject
---@return TSNode? object_node # node of the object that getGameObject gets called on.
function M.get_gameobject_call_at(bufnr, pos)
    local parser = treesitter.get_parser(bufnr, FILE_TYPE)
    if not parser then return end

    local tree = parser:parse()[1] ---@type TSTree | nil
    if not tree then return end

    local root = tree:root();
    if not root then return end

    local row = pos.line
    local col = pos.character
    local path_node = root:named_descendant_for_range(row, col, row, col + 1)
    if not path_node then return end

    local node_type = path_node:type()
    if node_type ~= "string" and node_type ~= "template_string" then return end

    local object_node = M.is_get_gameobject_call(bufnr, path_node)
    if not object_node then return end

    return path_node, object_node
end

-- ----------------------------------------------------------------------------

-- get path of GameObject in its prefab.
---@param scope prefab-cmp.Scope
---@param symbol_name string
---@return string? game_object_path
---@return string? prefab_path
function M.get_parent_path(scope, symbol_name)
    local prefab_path
    local buffer = {}
    local ident = scope:resolve_symbol(symbol_name)
    while ident do
        prefab_path = ident:get_extra_info("prefab_path")
        if prefab_path then break end

        local path = ident:get_extra_info("game_object_path")
        if not path then break end

        table.insert(buffer, path)

        local parent = ident:get_extra_info("parent_object")
        if not parent then break end

        ident = scope:resolve_symbol(parent)
    end

    local len = #buffer
    for i = 1, math.floor(len / 2) do
        local j = len - i + 1
        local temp = buffer[i]
        buffer[i] = buffer[j]
        buffer[j] = temp
    end

    return table.concat(buffer, '/'), prefab_path
end

---@param target prefab-cmp.GameObject
---@param base_path string
---@param buffer string[] # result buffer
---@return string[] buffer
function M.get_all_child_path_of(target, base_path, buffer)
    for _, child in ipairs(target.children) do
        local name = child.name
        local path = base_path == "" and name or (base_path .. "/" .. name)
        table.insert(buffer, path)

        M.get_all_child_path_of(child, path, buffer)
    end

    return buffer
end

---@param go prefab-cmp.GameObject
---@param input_path string # path string that has been inputed
---@return string[]? # all child paths of the GameObject `input_path` pointing to.
function M.get_all_child_path(go, input_path)
    local target_path = input_path:gsub("/[^/]-$", "")
    local target = go:get_child(target_path);
    if not target then return end

    return M.get_all_child_path_of(target, "", {})
end

return M
