---@alias prefab-cmp.prefab-loader.cocos.IDInfo { __id__: number }
---@alias prefab-cmp.prefab-loader.cocos.AssetInfo { __uuid__: string, __expectedType__: string }

---@class prefab-cmp.prefab-loader.cocos.GameObjectJson
---@field __type__ string
---@field _prefab? prefab-cmp.prefab-loader.cocos.IDInfo
---@field _name? string
---@field data prefab-cmp.prefab-loader.cocos.IDInfo # only the first json object in prefab has this field
---@field _children? prefab-cmp.prefab-loader.cocos.IDInfo[]
---@field _components? prefab-cmp.prefab-loader.cocos.IDInfo[]

---@class prefab-cmp.prefab-loader.cocos.PrefabReferenceJson
---@field __type__ string
---@field root prefab-cmp.prefab-loader.cocos.IDInfo
---@field asset prefab-cmp.prefab-loader.cocos.AssetInfo
---@field instance prefab-cmp.prefab-loader.cocos.IDInfo

---@alias prefab-loader.cocos.PrefabEntry (prefab-cmp.prefab-loader.cocos.GameObjectJson | prefab-cmp.prefab-loader.cocos.PrefabReferenceJson)

---@alias prefab-loader.cocos.Prefab prefab-loader.cocos.PrefabEntry[]
