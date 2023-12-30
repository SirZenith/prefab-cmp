local treesitter = vim.treesitter

local INDENT = "    "
local NEW_LINE = "\n"

-- ----------------------------------------------------------------------------

---@enum prefab-cmp.ScopeType
local ScopeType = {
    abstract_class = "abstract_class",
    class = "class",
    for_block = "for block",
    for_in_block = "for-in block",
    if_block = "if block",
    method = "method",
    program = "program",
    namespace = "namespace",
}

-- ----------------------------------------------------------------------------

---@class prefab-cmp.Scope
--
---@field bufnr number
---@field root TSNode
---@field id number
---@field type prefab-cmp.ScopeType
---@field name? string
---@field range prefab-cmp.ScopeRange
--
---@field parent? prefab-cmp.Scope
---@field children prefab-cmp.Scope[]
---@field child_name_map table<string, prefab-cmp.Scope>
---@field identifiers prefab-cmp.IdentInfo[]
---@field ident_name_map table<string, prefab-cmp.IdentInfo>
--
---@field lazy_nodes? TSNode[]
---@field handler prefab-cmp.ScopeHandlerMap
---@field hook_obj? any
---@field hook_map? prefab-cmp.ScopeHookMap
local Scope = {}
Scope.__index = Scope
Scope._id = 0

-- Creates a scope directly from given buffer.
---@param bufnr number
---@param root TSNode
---@param handler_map prefab-cmp.ScopeHandlerMap
---@param hook? { obj: any, map: prefab-cmp.ScopeHookMap }
---@return prefab-cmp.Scope
function Scope:load(bufnr, root, handler_map, hook)
    local scope = self:new(nil, "root", root:type(), root)

    scope.bufnr = bufnr
    scope.handler = handler_map

    if hook then
        scope.hook_obj = hook.obj
        scope.hook_map = hook.map
    end

    scope:load_named_node_child(root)

    return scope
end

-- Creates a new scope with the same buffer number, handler map, hook object,
-- hook map as source passed in.
---@param source? prefab-cmp.Scope
---@param name string
---@param type prefab-cmp.ScopeType
---@param root TSNode
---@return prefab-cmp.Scope
function Scope:new(source, name, type, root)
    local obj = setmetatable({}, self)

    local new_id = self._id + 1
    self._id = new_id

    if source then
        obj:mimic(source)
    end
    obj.id = new_id
    obj.name = name
    obj.root = root
    obj.type = type

    local st_row, st_col, st_byte, ed_row, ed_col, ed_byte = root:range(true);
    obj.range = {
        st = { row = st_row, col = st_col, byte = st_byte },
        ed = { row = ed_row, col = ed_col, byte = ed_byte },
    }

    obj.parent = nil
    obj.children = {}
    obj.child_name_map = {}
    obj.identifiers = {}
    obj.ident_name_map = {}

    return obj
end

-- Like Scope:new(), but new scope object can remember TSNode it contains. This
-- allow unnecessary traverse postpon until `self:finalize_lazy()` is called.
---@param source prefab-cmp.Scope
---@param name string
---@param type prefab-cmp.ScopeType
---@param root TSNode
---@param ... TSNode
---@return prefab-cmp.Scope
function Scope:new_lazy(source, name, type, root, ...)
    local scope = Scope:new(source, name, type, root)
    scope:add_lazy_node(root)
    for _, node in ipairs({ ... }) do
        scope:add_lazy_node(node)
    end
    return scope
end

-- Copy handler, hook object, hook map from another scope.
---@param other prefab-cmp.Scope
function Scope:mimic(other)
    self.bufnr = other.bufnr
    self.handler = other.handler
    self.hook_obj = other.hook_obj
    self.hook_map = other.hook_map
end

-- ----------------------------------------------------------------------------

-- Dispatch one node to handler, add result symbol to current scope.
---@param node TSNode
function Scope:load_node(node)
    local result = self:dispatch_to_handler(node)
    if not result then return end

    if result.ident then
        self:add_ident(result.ident)
    end

    if result.ident_list then
        for _, ident in ipairs(result.ident_list) do
            self:add_ident(ident)
        end
    end

    if result.scope then
        self:add_child(result.scope)
    end

    if result.scope_list then
        for _, child in ipairs(result.scope_list) do
            table.insert(self.identifiers, child)
        end
    end
end

-- Iterate though all named child of given node, add symbol encountered into
--  current scope.
---@param node TSNode
function Scope:load_named_node_child(node)
    for child in node:iter_children() do
        if child:named() then
            self:load_node(child)
        end
    end
end

-- ----------------------------------------------------------------------------

---@param node TSNode
function Scope:add_lazy_node(node)
    local lazy_nodes = self.lazy_nodes
    if not lazy_nodes then
        lazy_nodes = {}
        self.lazy_nodes = lazy_nodes
    end

    table.insert(lazy_nodes, node)
end

function Scope:finalize_lazy()
    if not self.lazy_nodes then
        return
    end

    for _, node in ipairs(self.lazy_nodes) do
        self:load_node(node)
    end

    self.lazy_nodes = nil
end

-- ----------------------------------------------------------------------------

---@param root TSNode
function Scope:update(root)
    if not self.root:has_changes() then
        return
    end
end

-- ----------------------------------------------------------------------------

function Scope:__tostring()
    local buffer = {}
    self:format(buffer, 0)
    return table.concat(buffer)
end

---@param buffer string[]
---@param ... string | integer
local function write(buffer, ...)
    local contents = { ... }
    for _, value in ipairs(contents) do
        local value_t = type(value)

        if value_t == "number" then
            for _ = 1, value do
                table.insert(buffer, INDENT)
            end
        elseif value_t == "string" then
            table.insert(buffer, value)
        end
    end
end

---@param buffer string[]
---@param ... string | number
local function writeln(buffer, ...)
    write(buffer, ...)
    table.insert(buffer, NEW_LINE)
end

---@param buffer string[]
---@param indent number
function Scope:format(buffer, indent)
    write(buffer, indent)

    if (self.name) then
        write(buffer, self.name, ": ")
    elseif self.type == ScopeType.for_block then
        write(buffer, "for: ")
    elseif self.type == ScopeType.for_in_block then
        write(buffer, "for-in: ")
    elseif self.type == ScopeType.if_block then
        write(buffer, "if: ")
    else
        write(buffer, indent)
    end

    write(buffer, "{")

    if self:is_empty() then
        writeln(buffer, "}")
        return
    end

    write(buffer, NEW_LINE)

    local child_indent = indent + 1

    for _, ident in ipairs(self.identifiers) do
        write(
            buffer, child_indent, ident.name, ": ", ident.type,
            " (", tostring(ident.st_pos.row), ", ", tostring(ident.st_pos.col), ")"
        )

        local extra_info = ident.extra_info
        if extra_info then
            local info_indent = child_indent + 1
            writeln(buffer, " {")
            for k, v in pairs(extra_info) do
                writeln(buffer, info_indent, k, ": ", tostring(v))
            end
            writeln(buffer, child_indent, "}")
        end

        writeln(buffer)
    end

    for _, s in ipairs(self.children) do
        writeln(buffer)
        s:finalize_lazy()
        s:format(buffer, child_indent)
    end

    writeln(
        buffer, indent, "} ",
        "(", tostring(self.range.st.row), ",", tostring(self.range.st.col), ")",
        " -> ",
        "(", tostring(self.range.ed.row), ",", tostring(self.range.ed.col), ")"
    )
end

-- ----------------------------------------------------------------------------

-- Checks if current scope is an ancestor of scope passed in.
---@param target prefab-cmp.Scope
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
---@param target prefab-cmp.Scope
---@return boolean
function Scope:is_child_of(target)
    return target:is_ancestor_of(self)
end

-- ----------------------------------------------------------------------------

---@param child prefab-cmp.Scope
function Scope:add_child(child)
    if (child:is_ancestor_of(self)) then
        local msg = (
            "trying to add ancestor of scope-%d as its child: scope-%d"
        ):format(self.id, child.id)
        error(msg)
    end

    child.parent = self
    table.insert(self.children, child)

    local name = child.name
    if name then
        self.child_name_map[name] = child
    end
end

---@param name string
---@return prefab-cmp.Scope?
function Scope:get_child(name)
    return self.child_name_map[name]
end

---@param ident prefab-cmp.IdentInfo
function Scope:add_ident(ident)
    local old_ident = self.ident_name_map[ident.name]

    if old_ident then
        vim.tbl_extend("force", old_ident, ident)
    else
        self.ident_name_map[ident.name] = ident
        table.insert(self.identifiers, ident)
    end
end

---@param name string
---@return prefab-cmp.IdentInfo?
function Scope:get_ident(name)
    return self.ident_name_map[name]
end

---@param name string
---@return prefab-cmp.IdentInfo | nil
function Scope:resolve_symbol(name)
    self:finalize_lazy()

    local result = self.ident_name_map[name] ---@type prefab-cmp.IdentInfo?

    local parent = self.parent
    if not result and parent then
        result = parent:resolve_symbol(name)
    end

    return result
end

-- ----------------------------------------------------------------------------

---@param outter prefab-cmp.ScopeRange
---@param inner prefab-cmp.ScopeRange
---@return boolean
local function contains_range(outter, inner)
    if outter.st.row > inner.st.row or outter.ed.row < inner.ed.row then
        return false
    end

    if outter.st.row == inner.st.row and outter.st.col > inner.st.col then
        return false
    end

    if outter.ed.row == inner.ed.row and outter.ed.col < inner.ed.col then
        return false
    end

    return true
end

---@param range { st: prefab-cmp.Position, ed: prefab-cmp.Position }
function Scope:find_min_wrapper(range)
    if not contains_range(self.range, range) then
        return nil
    end

    self:finalize_lazy()

    local result
    for _, child in ipairs(self.children) do
        result = child:find_min_wrapper(range)
        if result then
            break
        end
    end

    return result or self
end

---@param node? TSNode
function Scope:get_node_text(node)
    if not node then return "" end

    return treesitter.get_node_text(node, self.bufnr)
end

---@return boolean
function Scope:is_empty()
    return #self.identifiers == 0 and #self.children == 0
end

-- ----------------------------------------------------------------------------

---@class DispatchResult
---@field ident? prefab-cmp.IdentInfo
---@field ident_list? prefab-cmp.IdentInfo[]
---@field scope? prefab-cmp.Scope
---@field scope_list? prefab-cmp.Scope[]

---@param node TSNode?
---@return DispatchResult?
function Scope:dispatch_to_handler(node)
    if not node then return end

    local type_name = node:type()

    local handler = self.handler[type_name]

    local result
    if not handler then
        vim.notify("no handler for " .. type_name, vim.log.levels.WARN)
    elseif type(handler) == "function" then
        result = handler(self, node)
    end

    local hook_map = self.hook_map
    local hook_func = hook_map and hook_map[type_name]
    if result and hook_func then
        hook_func(self.hook_obj, self, node, result)
    end

    return result
end

-- ----------------------------------------------------------------------------

return {
    ScopeType = ScopeType,
    Scope = Scope,
}
