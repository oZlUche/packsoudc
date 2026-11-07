## 282（作者 2026-11-05 12:42）：局内商店的店主、集市散货摊的摊主、铁匠铺的铁匠 —— 点头像说一句闲话（[NpcChatter]）。
## 走内容管线：`data/authoring/npcs/*.json` → `data/npcs/*.tres`。名字与台词都留空给作者
class_name NpcDef
extends Resource

## 三处固定的 NPC
const SHOPKEEPER := &"shopkeeper"
const STALL_KEEPER := &"stall_keeper"
const BLACKSMITH := &"blacksmith"
const IDS: Array[StringName] = [SHOPKEEPER, STALL_KEEPER, BLACKSMITH]
## 284 §3.4：三位都会说的通用句（`npcs/common.json`，只有 `lines`）—— [NpcChatter] 并进上面三位各自的池子
const COMMON := &"common"
## 通用句的 id 前缀（和各人的句不撞）
const COMMON_PREFIX := "common_"

@export var id: StringName = &""
## 名字（作者填了才在纸条左上角写）
@export var display_name: String = ""
@export var display_names: Dictionary = {}
## 头像：`assets/portraits/npcs/<portrait>.png`
@export var portrait: StringName = &""
@export var lines: Array[NpcLine] = []
@export var specials: Array[NpcSpecial] = []
