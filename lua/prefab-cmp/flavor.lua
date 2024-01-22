local M = {}

M.flavor_dict = {
    cocos = {
        filetype = "typescript",
        handler_map = function()
            return require "prefab-cmp.handler.typescript"
        end,
        prefab_loader = function()
            return require "prefab-cmp.prefab-loader.cocos"
        end,
        hook_map = function()
            return require "prefab-cmp.hook.cocos"
        end,
        completor = function()
            return require "prefab-cmp.completor.cocos"
        end,
    },
}

---@param source prefab-cmp.Source
---@param name string
function M.set_flavor(source, name)
    local flavor = M.flavor_dict[name]
    if not flavor then
        vim.notify("invalid flavor: " .. name, vim.log.levels.ERROR)
        return
    end

    source.filetype = flavor.filetype
    source.handler_map = flavor.handler_map()
    source.prefab_loader = flavor.prefab_loader()
    source.hook_map = flavor.hook_map()
    source.completor = flavor.completor()
end

return M
