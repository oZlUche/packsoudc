## 宝箱屏的皮肤（154，作者定）：背景跟地图走、宝箱的纹路与材质随稀有度、锁孔在哪、三段动画用哪些帧。
##
## 走内容管线：`data/authoring/chest_skins/*.json` → `data/chest_skins/*.tres`。章节按 id 引用（[member ChapterDef.chest_skin]）。
## **缺的键、缺的图一律画占位**（深底 + 方块宝箱 + 圆锁孔），交互照样跑；导入器只对写了但找不到的图提醒。
## 美术线程的交付清单就是这些字段：一张背景、六张闭箱、六张开箱、锁孔坐标、三段序列帧。
class_name ChestSkinDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## 整屏背景（铺满裁切）
@export_file("*.png", "*.jpg", "*.webp") var background: String = ""
## 六档稀有度的闭箱图（下标 = 稀有度；不够六张的按最后一张）
@export var closed: Array[String] = []
## 六档稀有度的开箱图
@export var open: Array[String] = []
## 锁孔在宝箱图里的位置（像素，图的左上为原点）；占位时用箱体中下
@export var lock_offset: Vector2 = Vector2.ZERO
## 环形进度条的半径与粗细（像素）
@export var ring_radius: float = 56.0
@export var ring_width: float = 6.0
## 「开锁」：按下后锁孔处的序列帧
@export var unlock_frames: Array[String] = []
@export var unlock_fps: float = 8.0
## 「尝试开锁」：进度条走的过程中的序列帧
@export var trying_frames: Array[String] = []
@export var trying_fps: float = 6.0
## 宝箱打开的序列帧（播完弹出搜索界面）
@export var open_frames: Array[String] = []
@export var open_fps: float = 10.0


## 这一档的闭箱 / 开箱图路径（没有返回 ""）
func closed_for(rarity: int) -> String:
	return _pick(closed, rarity)


func open_for(rarity: int) -> String:
	return _pick(open, rarity)


## 背景图旁边的 json（作者 2026-10-17 交的四张）：`tone` 深 / 浅、`size` 原图大小、`chest_foot_y` 宝箱落地那条线（原图像素）。没图没 json = {}
func background_meta() -> Dictionary:
	if background == "":
		return {}
	var path := background.get_basename() + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


## 写了的全部图（导入器查在不在）
func all_paths() -> Array[String]:
	var out: Array[String] = []
	if background != "":
		out.append(background)
	for list in [closed, open, unlock_frames, trying_frames, open_frames]:
		for p in list:
			if String(p) != "":
				out.append(String(p))
	return out


static func _pick(list: Array[String], rarity: int) -> String:
	if list.is_empty():
		return ""
	return list[clampi(rarity, 0, list.size() - 1)]
