local command = require "prefab-cmp.command"
local source = require "prefab-cmp.source"
local flavor = require "prefab-cmp.flavor"
local prefab_loader = require "prefab-cmp.prefab-loader"

local cmp = require "cmp"
cmp.register_source(source.name, source)

local M = {
    name = source.name,
    source = source,
}

function M.setup(option)
    option = option or {}

    command.setup()

    if option.flavor then
        flavor.set_flavor(source, option.flavor)
    end

    source.prefab_path_map_func = option.path_map_func

    local loader_setting = option.prefab_loader
    local loader_map = prefab_loader.loader_path_map
    if type(loader_setting) == "table" then
        for name, loader_opt in pairs(loader_setting) do
            local loader_path = loader_map[name]
            if loader_path then
                require(loader_path).setup(loader_opt)
            end
        end
    end
end

return M
