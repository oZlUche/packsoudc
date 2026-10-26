## 255：一件【随身之物】（[member CharacterDef.fixed_items]）—— 角色开局就带、钉在棋盘上的道具：哪件、左上角摆哪、什么朝向。
## 它自带底板（不要包）、拿不下、丢不掉、不进仓库，每局开局重发（[method CharacterDef.shape_board]）
class_name FixedItem
extends Resource

@export var id: StringName = &""
@export var origin: Vector2i = Vector2i.ZERO
@export_range(0, 3) var rot: int = 0
## 256（马库斯的军功牌）：**可以动、不能丢** —— 一局里能在自己的棋盘上挪（含压在包上），但不离开棋盘
## （地上、卖、保险箱、仓库、天平托盘都不行）；开局与开局屏照旧钉在 [member origin]。false = 255 的钉死不动
@export var movable: bool = false
