local flavor = require "prefab-cmp.flavor"
local source = require "prefab-cmp.source"

local commands = {
    {
        "PrefabCmpFlavor",
        function(params)
            local name = params.args
            flavor.set_flavor(source, name)
        end,
        desc = "set prefab completion flavor",
        nargs = 1,
    },
    {
        "PrefabCmpPrintPrefab",
        function()
            print(source.active_prefab or "no active prefab")
        end,
        desc = "print current active prefab",
    },
    {
        "PrefabCmpStatus",
        function()
            vim.print(source)
        end,
        desc = "print current source status"
    },
}

return {
    setup = function()
        for _, cmd in ipairs(commands) do
            local options = {}
            for k, v in pairs(cmd) do
                options[k] = v
            end
            options[1] = nil
            options[2] = nil

            vim.api.nvim_create_user_command(cmd[1], cmd[2], options)
        end
    end,
}
