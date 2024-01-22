local command = require "prefab-cmp.command"
local config = require "prefab-cmp.config"
local source = require "prefab-cmp.source"
local flavor = require "prefab-cmp.flavor"
local prefab_loader = require "prefab-cmp.prefab-loader"

local cmp = require "cmp"
cmp.register_source(source.name, source)

local M = {
    name = source.name,
    source = source,
}

---@param dst table
---@param src? table
local function merge_config(dst, src)
    if not src then return end

    for k, v in pairs(src) do
        local old_value = dst[k]
        if type(old_value) == "table" and type(v) == "table" then
            merge_config(old_value, v)
        else
            dst[k] = vim.deepcopy(v)
        end
    end
end

---@param option? table<string, any>
function M.setup(option)
    merge_config(config, option)

    command.setup()
    flavor.set_flavor(source, config.flavor)
    source:setup_prefab_path_map_func()

    local loader_path = prefab_loader.loader_path_map[config.flavor]
    if loader_path then
        require(loader_path).setup()
    end
end

return M
