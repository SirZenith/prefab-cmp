---@meta

---@class prefab-cmp.Completor
local Completor = {}

-- ----------------------------------------------------------------------------

-- trim single & double quote from both ends of string.
---@param str string
---@return string
function Completor.trim_quote(str) end

-- ----------------------------------------------------------------------------

-- find node stande for getGameObject call at give cursor position
---@param bufnr integer
---@param pos { line: integer, character: integer }
---@return TSNode? path_node # node under cursor, which should also be the node pointing to path passed to getGameObject
---@return TSNode? object_node # node of the object that getGameObject gets called on.
function Completor.get_gameobject_call_at(bufnr, pos) end

-- get path of GameObject in its prefab.
---@param scope prefab-cmp.Scope
---@param symbol_name string
---@return string? game_object_path
---@return string? prefab_path
function Completor.get_parent_path(scope, symbol_name) end

---@param go prefab-cmp.GameObject
---@param input_path string # path string that has been inputed
---@return string[]? # all child paths of the GameObject `input_path` pointing to.
function Completor.get_all_child_path(go, input_path) end
