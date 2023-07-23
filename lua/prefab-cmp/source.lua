local scope = require "prefab-cmp.scope"

local Scope = scope.Scope
local bufoption = vim.bo
local treesitter = vim.treesitter

---@alias PrefabLoader { load_prefab: fun(path: string): GameObject, string | nil }

-- ----------------------------------------------------------------------------

---@class prefab-cmp.Source : cmp.Source
---@field filetype? string
---@field handler_map? ScopeHandlerMap
---@field hook_map? ScopeHookMap
--
---@field prefab_path_map_func? fun(path: string): string
---@field prefab_loader? PrefabLoader
---@field prefab_map table<string, GameObject>
--
---@field active_bufnr? number
---@field active_prefab? GameObject
---@field active_node? TSNode
---@field active_scope? Scope
local Source = {}
Source.name = "prefab-completion"
Source.__index = Source

---@return prefab-cmp.Source
function Source:new()
    local obj = setmetatable({}, self)

    obj.prefab_map = {}

    return obj
end

---@param bufnr number
function Source:load_buf(bufnr)
    if bufoption[bufnr].filetype ~= self.filetype then
        self.active_bufnr = nil
        self.active_node = nil
        self.active_prefab = nil
        self.active_scope = nil
        return
    end

    if not self.handler_map then return end

    local parser = treesitter.get_parser(bufnr, self.filetype)
    local tree = parser:parse()[1] ---@type TSTree | nil
    if not tree then
        return
    end

    local root = tree:root()
    self.active_bufnr = bufnr
    self.active_node = root
    self.active_scope = Scope:load(bufnr, root, self.handler_map, {
        obj = self, map = self.hook_map
    })
end

---@param node TSNode
---@return string
function Source:get_node_text(node)
    if not self.active_bufnr then return "" end
    return treesitter.get_node_text(node, self.active_bufnr)
end

-- ----------------------------------------------------------------------------

function Source:_load_prefab(path)
    local gameobject, err = self.prefab_loader.load_prefab(path)
    if err then
        vim.notify(err, vim.log.levels.WARN)
        return
    end
    self.prefab_map[path] = gameobject
end

---@param path string
function Source:set_active_prefab(path)
    local map = self.prefab_path_map_func
    path = map and map(path) or path

    if not self.prefab_map[path] then
        self:_load_prefab(path)
    end

    self.active_prefab = self.prefab_map[path]
end

-- ----------------------------------------------------------------------------

---@param row integer # 0-base index
---@param col integer # 0-base index
---@return TSNode?
function Source:get_node_for_pos(row, col)
    if not self.active_node then
        return nil
    end

    return self.active_node:named_descendant_for_range(row, col, row, col + 1)
end

-- Returns TSNode pointing to the object which getGameObject gets call on, returns
-- nil if there is no call to getGameObject method wrapping the node passed in.
---@param node TSNode
---@return TSNode?
function Source:is_get_gameobject_call(node)
    local call_node = node

    while call_node do
        if call_node:type() == "call_expression" then
            break
        end
        call_node = call_node:parent()
    end
    if not call_node then return end

    local function_node = call_node:field("function")[1]
    if function_node:type() ~= "member_expression" then
        return
    end

    local object_node = function_node:field("object")[1]
    local property_node = function_node:field("property")[1]
    if not (object_node and property_node) then
        return
    end

    local property_name = self:get_node_text(property_node)
    if property_name ~= "getGameObject" then
        return
    end

    return object_node
end

---@param node TSNode # node pointing to getGameObject gets called on
---@return string | nil
function Source:get_gameobject_path(node)
    local name = self:get_node_text(node)
    local st_row, st_col, ed_row, ed_col = node:range()
    local range = {
        st = { row = st_row, col = st_col },
        ed = { row = ed_row, col = ed_col },
    }

    local s = self.active_scope:find_min_wrapper(range)
    if not s then return end

    local buffer = {}
    local ident = s:resolve_symbol(name)
    while ident do
        local extra_info = ident.extra_info
        local path = extra_info and extra_info.path
        if not path then break end

        table.insert(buffer, path)

        local parent = ident.extra_info.parent
        if not parent then break end

        ident = s:resolve_symbol(parent)
    end

    local len = #buffer
    for i = 1, math.floor(len / 2) do
        local j = len - i + 1
        local temp = buffer[i]
        buffer[i] = buffer[j]
        buffer[j] = temp
    end

    return table.concat(buffer, '/')
end

---@param buffer string[]
---@param target GameObject
---@param base_path string
---@return string[] buffer
function Source:get_all_child_path(buffer, target, base_path)
    for _, child in ipairs(target.children) do
        local name = child.name
        local path = base_path == "" and name or (base_path .. "/" .. name)
        table.insert(buffer, path)

        self:get_all_child_path(buffer, child, path)
    end

    return buffer
end

---@param node TSNode # node pointing to getGameObject gets called on
---@param input_path string # path string that has been inputed
---@return lsp.CompletionItem[] | nil
function Source:gen_completion(node, input_path)
    local go = self.active_prefab
    if not go then return end

    local path = self:get_gameobject_path(node)
    if not path then return end

    local target = go:get_child(path)
    target = target and target:get_child(input_path)
    if not target then return end

    local result = {}
    for _, child_path in ipairs(self:get_all_child_path({}, target, "")) do
        table.insert(result, {
            label = child_path,
            kind = vim.lsp.protocol.CompletionItemKind.Value,
        })
    end

    return result
end

-- ----------------------------------------------------------------------------

---@return boolean
function Source:is_available()
    if not (self.handler_map and self.prefab_loader) then
        return false
    end

    if not (
            self.active_bufnr
            and self.active_node
            and self.active_prefab
            and self.active_scope
        ) then
        return false
    end

    return true
end

---@return string[]
function Source:get_trigget_characters()
    return { "'", "\"", "/" }
end

---@param param cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse | nil)
function Source:complete(param, callback)
    local bufnr = vim.fn.bufnr()
    if bufoption[bufnr].filetype ~= self.filetype then
        callback(nil)
        return
    end

    self:load_buf(bufnr)

    local pos = param.context.cursor
    local node = self:get_node_for_pos(pos.line, pos.character)
    if not node then
        callback(nil)
        return
    end

    local input_path = self:get_node_text(node)
    local fist_char = input_path:sub(1, 1)
    local len = #input_path
    local last_char = input_path:sub(len, len)
    if last_char == "\"" or last_char == "'" then
        input_path = input_path:sub(1, len - 1)
    end
    if fist_char == "\"" or fist_char == "'" then
        input_path = input_path:sub(2)
    end

    local object_node = self:is_get_gameobject_call(node)
    if not object_node then
        callback(nil)
        return
    end

    local items = self:gen_completion(object_node, input_path)
    if not items then
        callback(nil)
        return
    end

    callback {
        items = items,
        isIncomplete = false,
    }
end

-- ----------------------------------------------------------------------------

local source = Source:new()

return source
