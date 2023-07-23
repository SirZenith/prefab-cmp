
---@class GameObject
---@field name string
---@field children GameObject[]
---@field child_map table<string, GameObject>
local GameObject = {}
GameObject.__index = GameObject

---@param name string
---@return GameObject
function GameObject:new(name)
    local obj = setmetatable({}, self)

    obj.name = name or "unnamed"
    obj.children = {}
    obj.child_map = {}

    return obj
end

-- ----------------------------------------------------------------------------

---@return string
function GameObject:__tostring()
    return table.concat(self:format({}, ''))
end

---@param buffer string[]
---@param indent string
---@return string[] buffer
function GameObject:format(buffer, indent)
    table.insert(buffer, self.name)

    local len = #self.children

    local child_indent = indent .. '│   '
    local last_indent = indent .. '    '
    for i = 1, len do
        local is_last = i == len
        local child = self.children[i]

        if child then
            table.insert(buffer, "\n")
            table.insert(buffer, indent)

            local prefix = is_last and '└── ' or '├── '
            table.insert(buffer, prefix)

            local new_indent = is_last and last_indent or child_indent
            child:format(buffer, new_indent)
        end
    end

    return buffer
end

-- ----------------------------------------------------------------------------

---@param path string
---@return GameObject | nil
function GameObject:get_child(path)
    local walker = self
    local st, len = 1, #path

    for i = 1, len do
        local char = path:sub(i, i)
        if char == "/" then
            if i - 1 >= st then
                local segment = path:sub(st, i - 1)
                walker = walker.child_map[segment]
            end

            st = i + 1
        end

        if not walker then break end
    end

    if walker and st < len then
        local segment = path:sub(st, len)
        walker = walker.child_map[segment]
    end

    return walker
end

-- ----------------------------------------------------------------------------

return {
    GameObject = GameObject,
}
