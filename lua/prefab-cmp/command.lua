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
            local paths = {}
            for k in pairs(source.prefab_map) do
                table.insert(paths, k)
            end

            if #paths == 0 then
                vim.notify("no prefab loaded")
                return
            end

            local buffer = { "Loaded prefab list:" }
            for i, path in ipairs(paths) do
                table.insert(buffer, ("%d. %s"):format(i, path))
            end
            table.insert(buffer, "Choose a prefab to print: ")
            local prompt = table.concat(buffer, "\n")
            local index = tonumber(vim.fn.input(prompt)) or 0

            local path = paths[index]
            if not path then
                vim.notify("invalid index")
            end

            local go = source.prefab_map[path]
            if not go then
                vim.notify("failed to get prefab")
            else
                vim.notify("\n\n" .. tostring(go))
            end
        end,
        desc = "print current active prefab",
    },
    {
        "PrefabCmpPrintScope",
        function()
            print(source.active_scope or "no active scope")
        end,
        desc = "print current active scope",
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
