---@enum ScopeType
local ScopeType = {
    class = "class",
}

---@class ScopeTree

---@class IdentInfo
---@field type string
---@field at_line number

---@class Scope
---@field id number
---@field type ScopeType
---@field parent? Scope
---@field children ScopeTree
---@field identifier { [string]: IdentInfo }
local Scope = {}
Scope.__index = Scope
Scope._id = 0

---@param type ScopeType
---@return Scope
function Scope:new(type)
    local obj = setmetatable({}, self)

    local new_id = self._id + 1
    self._id = new_id

    obj.id = new_id
    obj.type = type

    return obj
end

-- Checks if current scope is an ancestor of scope passed in.
---@param target Scope
---@return boolean
function Scope:is_ancestor_of(target)
    local walker = target

    while walker do
        if walker == self then
            return true
        end
        walker = walker.parent
    end

    return false
end

-- Checks if current scope is a child of scope passed in.
---@param target Scope
---@return boolean
function Scope:is_child_of(target)
    return target:is_ancestor_of(self)
end

---@param child Scope
function Scope:add_child(child)
    if (child:is_ancestor_of(self)) then
        local msg = (
            "trying to add ancestor of scope-%d as its child: scope-%d"
        ):format(self.id, child.id)
        error(msg)
    end

    child.parent = self
    -- TODO add child to scope tree
end

return {
    ScopeType = ScopeType,
    Scope = Scope,
}
