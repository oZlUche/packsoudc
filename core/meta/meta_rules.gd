## 局外的规则（058 第 4 / 6 条）：仓库多大。作者说仓库也是局外成长的一部分，所以大小是数据，成长系统落地时改它。
##
## 走内容管线：`data/authoring/meta_rules/*.json` → `data/meta_rules/*.tres`。现在一份 `standard`，`GameFlow` 按 id 取。
class_name MetaRules
extends Resource

## 没有规则时的仓库大小（测试、没导入资产的时候）
const DEFAULT_SIZE := Vector2i(10, 8)

@export var id: StringName = &""
@export var display_name: String = ""
## 仓库的格子。占位 10×8；将来随局外成长变
@export var warehouse_size: Vector2i = DEFAULT_SIZE
## 仓库空的第一局带什么（058 第六节）：一套开局装备（[LoadoutDef] 的 id）的非包道具发进仓库，开局屏再从仓库往包里拖。
## 占位：正式游戏由新手教程关发第一套（第 8 阶段）；空串 = 不发
@export var first_kit: StringName = &""
