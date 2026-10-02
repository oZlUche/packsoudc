## 开局装备（架构文档 8 节，M6）：开一局时带的一套道具。
##
## 只是一张清单，不写位置：包先上棋盘，其余按顺序往包里放、放不下的进暂存区（`RunState._give_kit`）——
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
