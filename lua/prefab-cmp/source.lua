local scope = require "prefab-cmp.scope"

local Scope = scope.Scope
local bufoption = vim.bo
local treesitter = vim.treesitter

---@alias PrefabLoader { load_prefab: fun(path: string): prefab-cmp.GameObject, string | nil }

-- ----------------------------------------------------------------------------

---@class prefab-cmp.Source : cmp.Source
---@field filetype? string
---@field handler_map? prefab-cmp.ScopeHandlerMap
---@field hook_map? prefab-cmp.ScopeHookMap
---@field completor? prefab-cmp.Completor
--
---@field prefab_path_map_func? fun(path: string): string
---@field prefab_loader? PrefabLoader
---@field prefab_map table<string, prefab-cmp.GameObject>
--
---@field active_bufnr? number
---@field active_node? TSNode
---@field active_scope? prefab-cmp.Scope
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
    if not self.handler_map then return end

    local parser = treesitter.get_parser(bufnr, self.filetype)
    local tree = parser:parse()[1] ---@type TSTree | nil
    if not tree then return end

    local root = tree:root()
    if not root then return end

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

---@param path string
function Source:_load_prefab(path)
    local gameobject, err = self.prefab_loader.load_prefab(path)
    if err then
        vim.notify(err, vim.log.levels.WARN)
    end
    self.prefab_map[path] = gameobject
end

---@param prefab_path string
---@return prefab-cmp.GameObject?
function Source:get_gameobject(prefab_path)
    local map = self.prefab_path_map_func
    prefab_path = map and map(prefab_path) or prefab_path

    if not self.prefab_map[prefab_path] then
        self:_load_prefab(prefab_path)
    end

    return self.prefab_map[prefab_path]
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

---@param object_node TSNode
---@return prefab-cmp.GameObject?
function Source:get_parent_object(object_node)
    local completor = self.completor
    if not completor then return end

    local st_row, st_col, ed_row, ed_col = object_node:range()
    local range = {
        st = { row = st_row, col = st_col },
        ed = { row = ed_row, col = ed_col },
    }
    local wrapper_scope = self.active_scope:find_min_wrapper(range)
    if not wrapper_scope then return end

    local object_name = self:get_node_text(object_node)
    local parent_path, prefab_path = completor.get_parent_path(wrapper_scope, object_name)
    if not (parent_path and prefab_path) then return end

    local go = self:get_gameobject(prefab_path)
    if not go then return end

    local parent_go = go:get_child(parent_path)

    return parent_go
end

---@param parent_go prefab-cmp.GameObject
---@param path_node TSNode
---@return lsp.CompletionItem[]?
function Source:get_all_child_path(parent_go, path_node)
    local completor = self.completor
    if not completor then return end

    local input_path = self:get_node_text(path_node)
    input_path = self.completor.trim_quote(input_path)

    local children_paths = completor.get_all_child_path(parent_go, input_path)
    if not children_paths then return end

    local items = {}
    for _, child_path in ipairs(children_paths) do
        table.insert(items, {
            label = child_path,
            kind = vim.lsp.protocol.CompletionItemKind.Value,
        })
    end

    return items
end

---@param cursor_pos { line: integer, character: integer }
---@return lsp.CompletionResponse | nil
function Source:gen_completion(cursor_pos)
    if bufoption.filetype ~= self.filetype then return end

    local completor = self.completor
    if not completor then return end

    local bufnr = vim.fn.bufnr()
    local path_node, object_node = completor.get_gameobject_call_at(bufnr, cursor_pos)
    if not (path_node and object_node) then return end

    self:load_buf(bufnr)

    local parent_go = self:get_parent_object(object_node)
    if not parent_go then return end

    local items = self:get_all_child_path(parent_go, path_node)
    if not items then return end

    return {
        items = items,
        isIncomplete = false,
    }
end

-- ----------------------------------------------------------------------------

---@return boolean
function Source:is_available()
    if not (self.handler_map and self.prefab_loader) then
        return false
    end

    return true
end

---@return string[]
function Source:get_trigget_characters()
    return { "'", "\"" }
end

---@param param cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse | nil)
function Source:complete(param, callback)
    local result = self:gen_completion(param.context.cursor)
    callback(result)
end

-- ----------------------------------------------------------------------------

local source = Source:new()

return source
