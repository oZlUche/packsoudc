## 开局装备（架构文档 8 节，M6）：开一局时带的一套道具。
##
## 只是一张清单，不写位置：包先上棋盘，其余按顺序往包里放、放不下的到地上（`RunState.give_kit`）——
## 摆法是玩家在出发前自己定的，清单只管「带什么」。
##
## 作者数据走内容管线：`data/authoring/loadouts/*.json` → `data/loadouts/*.tres`。导入器不认识它，反射填字段；
## 校验比引擎严格：每件道具得存在，且至少带一个包 —— 棋盘上只有包里的东西参战（3.2），没有包一格都用不了。
class_name LoadoutDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## 别的语言的名字，`{"en": "Assault"}`；界面用 [method Names.of] 取
@export var display_names: Dictionary = {}
## 给选装备的界面看的一句话：这一套的打法
@export var description: String = ""
## 别的语言的说明
@export var descriptions: Dictionary = {}
## 096（作者定）：开局屏可选的**预设套** —— 挑了角色后免费放到初始包里（不占带入预算、不从仓库拿、出发时带着走）。
## 预设套不用带包（角色的初始包装它）；`false` 的是老路 / 仓库空的第一套用的整套装备
@export var preset: bool = false
## 道具 id，可以重复（两个包就写两遍）
@export var items: Array[StringName] = []
## 285（作者 2026-11-07）：预设分三档 —— `free` 免费（新造、不付、不算带入预算，094 的底线）；
## `paid` 收费（新造，出发时付清单定价之和 × 集市倍数，算带入预算）；`advanced` 高级（新造，出发时从仓库消耗一张 [member ticket]，不算带入预算）
@export var tier: StringName = TIER_FREE
## 285 第二版（作者 14:56「类似新兵券、制式券之类的」）：高级预设要的券（道具 id，带 `ticket` 标签）；免费 / 收费不写
@export var ticket: StringName = &""
## 切片 v6.14 B02：只给在 [member ChapterDef.presets] 里点名它的章节用，别的章不列（切片专用的两套）
@export var chapter_only: bool = false

const TIER_FREE := &"free"
const TIER_PAID := &"paid"
const TIER_ADVANCED := &"advanced"
const TIERS: Array[StringName] = [TIER_FREE, TIER_PAID, TIER_ADVANCED]


func is_paid() -> bool:
	return tier == TIER_PAID


func is_advanced() -> bool:
	return tier == TIER_ADVANCED
