local command = require "prefab-cmp.command"
local source = require "prefab-cmp.source"
local flavor = require "prefab-cmp.flavor"

local cmp = require "cmp"
cmp.register_source(source.name, source)

local M = {
    name = source.name,
}

function M.setup(option)
    option = option or {}

    command.setup()

    if option.flavor then
        flavor.set_flavor(source, option.flavor)
    end

    source.prefab_path_map_func = option.path_map_func

    local augroup = vim.api.nvim_create_augroup("prefab-completion", { clear = true })
    vim.api.nvim_create_autocmd({ "BufRead", "BufEnter" }, {
        group = augroup,
        callback = function()
            local bufnr = vim.fn.bufnr()
            source:load_buf(bufnr)
        end,
    })
end

return M
