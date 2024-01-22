local M = {
    -- Prefab handling flavor to use.
    ---@type string
    flavor = "",

    -- A function that maps path string extracted from code to actual prefab path
    -- in file system.
    ---@type fun(path: string): string
    path_map_func = function(path)
        return path
    end,

    prefab_loader = {
        cocos = {
            -- Function that converts a resource UUID into actual resource path.
            -- `nil` return value indicates a failure in UUID conversion.
            ---@type fun(path: string, uuid: string): string?
            uuid_convertor = function() end,
        },
    }
}

return M
