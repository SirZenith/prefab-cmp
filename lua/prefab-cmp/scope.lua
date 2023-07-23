local ident_info = require "prefab-cmp.ident_info"

local treesitter = vim.treesitter
local IdentInfo = ident_info.IdentInfo

local INDENT = "    "
local NEW_LINE = "\n"

-- ----------------------------------------------------------------------------

---@enum ScopeType
local ScopeType = {
    class = "class",
    for_block = "for block",
    for_in_block = "for-in block",
    if_block = "if block",
    method = "method",
    program = "program",
}

---@alias Position { row: integer, col: integer, byte: integer }
---@alias ScopeRange { st: Position, ed: Position }

---@alias ScopeHookFunc fun(self: any, scope: Scope, node: TSNode): table<string, any> | nil
---@alias ScopeHookMap table<NodeType, ScopeHookFunc>

---@alias ScopeHandlerFunc fun(self: Scope, node: TSNode): DispatchResult
---@alias ScopeHandlerMap table<string, boolean | ScopeHandlerFunc>

-- ----------------------------------------------------------------------------

---@class Scope
--
---@field bufnr number
---@field id number
---@field type ScopeType
---@field name? string
---@field range ScopeRange
--
---@field parent? Scope
---@field children Scope[]
---@field named_children { [string]: integer }
---@field child_index_to_name table<number, string>
---@field identifiers IdentInfo[]
--
---@field lazy_nodes? TSNode[]
---@field handler ScopeHandlerMap
---@field hook_obj? any
---@field hook_map? ScopeHookMap
local Scope = {}
Scope.__index = Scope
Scope._id = 0

---@param handler_map ScopeHandlerMap
function Scope:set_handler(handler_map)
    self.handler = handler_map
end

---@param bufnr integer
---@param type ScopeType
---@param root TSNode
---@return Scope
function Scope:new(bufnr, type, root)
    local obj = setmetatable({}, self)

    local new_id = self._id + 1
    self._id = new_id

    obj.bufnr = bufnr
    obj.id = new_id
    obj.type = type

    local st_row, st_col, st_byte, ed_row, ed_col, ed_byte = root:range(true);
    obj.range = {
        st = { row = st_row, col = st_col, byte = st_byte },
        ed = { row = ed_row, col = ed_col, byte = ed_byte },
    }

    obj.parent = nil
    obj.children = {}
    obj.named_children = {}
    obj.child_index_to_name = {}
    obj.identifiers = {}

    obj.hook = {}

    return obj
end

---@param bufnr integer
---@param type ScopeType
---@param root TSNode
---@param ... TSNode
---@return Scope
function Scope:new_lazy(bufnr, type, root, ...)
    local scope = Scope:new(bufnr, type, root)
    scope:add_lazy_node(root)
    for _, node in ipairs({ ... }) do
        scope:add_lazy_node(node)
    end
    return scope
end

---@param bufnr number
---@param root TSNode
---@param handler_map ScopeHandlerMap
---@param hook? { obj: any, map: ScopeHookMap }
---@return Scope
function Scope:load(bufnr, root, handler_map, hook)
    local scope = self:new(bufnr, root:type(), root)
    scope:set_handler(handler_map)

    if hook then
        scope.hook_obj = hook.obj
        scope.hook_map = hook.map
    end

    scope:load_named_node_child(root)

    return scope
end

---@param node TSNode
function Scope:load_node(node)
    local result = self:dispatch_to_handler(node)

    if getmetatable(result) == IdentInfo then
        table.insert(self.identifiers, result)
    elseif result then
        for _, info in ipairs(result) do
            table.insert(self.identifiers, info)
        end
    end
end

---@param node TSNode
function Scope:load_named_node_child(node)
    for child in node:iter_children() do
        if child:named() then
            self:load_node(child)
        end
    end
end

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
    child.handler = self.handler
    child.hook_obj = self.hook_obj
    child.hook_map = self.hook_map
    table.insert(self.children, child)

    local name = child.name
    if name then
        local len = #self.children
        self.named_children[name] = len
        self.child_index_to_name[len] = name
    end
end

---@param name string
---@return IdentInfo | nil
function Scope:resolve_symbol(name)
    self:finalize_lazy()

    local result

    local identifiers = self.identifiers
    for i = #identifiers, 1, -1 do
        local ident = identifiers[i]
        if ident.name == name then
            result = ident
            break
        end
    end

    local parent = self.parent
    if not result and parent then
        result = parent:resolve_symbol(name)
    end

    return result
end

---@param outter ScopeRange
---@param inner ScopeRange
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

---@param range { st: Position, ed: Position }
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

---@param node TSNode
function Scope:get_node_text(node)
    return treesitter.get_node_text(node, self.bufnr)
end

---@return boolean
function Scope:is_empty()
    return #self.identifiers == 0 and #self.children == 0
end

-- ----------------------------------------------------------------------------

---@alias DispatchResult (IdentInfo | IdentInfo[] | nil)

---@return IdentInfo | IdentInfo[] | nil
---@return DispatchResult
function Scope:dispatch_to_handler(node)
    local type_name = node:type()

    local extra_info
    local hook_map = self.hook_map
    local hook_func = hook_map and hook_map[type_name]
    if hook_func then
        extra_info = hook_func(self.hook_obj, self, node)
    end

    local handler = self.handler[type_name]

    local result
    if not handler then
        vim.notify("no handler for " .. type_name, vim.log.levels.WARN)
    elseif type(handler) == "function" then
        result = handler(self, node)
    end

    if not result then
        -- pass
    elseif not extra_info then
        -- pass
    elseif getmetatable(result) == IdentInfo then
        result.extra_info = extra_info
    else
        for _, info in ipairs(result) do
            info.extra_info = extra_info
        end
    end

    return result
end

-- ----------------------------------------------------------------------------

return {
    ScopeType = ScopeType,
    Scope = Scope,
}
