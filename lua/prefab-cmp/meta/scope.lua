---@alias prefab-cmp.Position { row: integer, col: integer, byte: integer }
---@alias prefab-cmp.ScopeRange { st: prefab-cmp.Position, ed: prefab-cmp.Position }

---@alias prefab-cmp.ScopeHookFunc fun(self: any, scope: prefab-cmp.Scope, node: TSNode, result: DispatchResult) | nil

---@alias prefab-cmp.ScopeHookMap table<string, prefab-cmp.ScopeHookFunc>

---@alias prefab-cmp.ScopeHandlerFunc fun(self: prefab-cmp.Scope, node: TSNode): DispatchResult?
---@alias prefab-cmp.ScopeHandlerMap table<string, boolean | prefab-cmp.ScopeHandlerFunc>
