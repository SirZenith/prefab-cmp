local source = require "prefab-cmp.source"

local Source = source.Source

local cmp_src = Source:new()

local M = {
    name = cmp_src.name,
}

local flavor_dict = {
    cocos = {
        filetype = "typescript",
        handler_map = require "prefab-cmp.handler.typescript",
        prefab_loader = require "prefab-cmp.prefab-loader.cocos",
        hook_map = require "prefab-cmp.hook.cocos",
    },
}

---@param name string
function M.set_flavor(name)
    local flavor = flavor_dict[name]
    if not flavor then
        vim.notify("invalid flavor: " .. name, vim.log.levels.ERROR)
        return
    end

    cmp_src.filetype = flavor.filetype
    cmp_src.handler_map = flavor.handler_map
    cmp_src.prefab_loader = flavor.prefab_loader
    cmp_src.hook_map = flavor.hook_map
end

function M.setup(option)
    option = option or {}

    local cmp = require "cmp"
    cmp.register_source(cmp_src.name, cmp_src)

    if option.flavor then
        M.set_flavor(option.flavor)
    end

    local augroup = vim.api.nvim_create_augroup("prefab-completion", { clear = true })
    vim.api.nvim_create_autocmd("BufEnter", {
        group = augroup,
        callback = function()
            vim.notify("prefab-cmp enter buf " .. tostring(os.clock()))
            local bufnr = vim.fn.bufnr()
            cmp_src:load_buf(bufnr)
        end,
    })
end

return M
