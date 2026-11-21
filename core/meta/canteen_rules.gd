## 355：灰灯食堂的规矩 —— 锅和食材仓库按灰灯声望档多大、每件食材管哪一类、给多少、带几点饱腹。
##
## 走内容管线：`data/authoring/base_rules/canteen.json` → `data/base_rules/canteen.tres`（[method Canteen.load_rules]）。
## 数都是建议初值（报告 355 第五节），作者改 json。道具本身只加「食材」标签（[constant Canteen.TAG]），不加字段
class_name CanteenRules
extends Resource

const ID := &"canteen"
## 四类，各管一种属性（报告 355 第二节第 4 条）
const STAPLE := &"staple"
const MEAT := &"meat"
const VEG := &"veg"
const FRUIT := &"fruit"
const CATEGORIES: Array[StringName] = [STAPLE, MEAT, VEG, FRUIT]

@export var id: StringName = &""
@export var display_name: String = ""
## 哪一方的声望档决定锅和仓库多大（灰灯互助会）
@export var faction: StringName = &"greylamp"
## 锅的边长（下标 = 那一方的声望档 0 初识 … 4 代言，表短按最后一项）：开放 4×4，信赖 5×5，代言 6×6
@export var pot_side: Array[int] = [4, 4, 4, 5, 6]
## 食材仓库的宽、高（同上）：开放 6×6，信赖 8×8，代言 10×8
@export var store_w: Array[int] = [6, 6, 6, 8, 10]
@export var store_h: Array[int] = [6, 6, 6, 8, 8]
## 饱腹度剩几点时提醒一次
@export var warn_at: int = 1
## 食材表：道具 id → {"category": 四类之一, "flat": 固定值, "pct": 百分数, "satiety": 饱腹值}。flat 与 pct 一件只写一样
@export var entries: Dictionary = {}


static func _pick(arr: Array[int], tier: int, fallback: int) -> int:
	if arr.is_empty():
		return fallback
	return arr[clampi(tier, 0, arr.size() - 1)]


func pot_size(tier: int) -> Vector2i:
	var s := _pick(pot_side, tier, 4)
	return Vector2i(s, s)


func store_size(tier: int) -> Vector2i:
	return Vector2i(_pick(store_w, tier, 6), _pick(store_h, tier, 6))


## 这件食材的那一条（不是食材 = 空）
func entry(item_id: StringName) -> Dictionary:
	var e: Variant = entries.get(String(item_id), null)
	return e as Dictionary if e is Dictionary else {}


func category_of(item_id: StringName) -> StringName:
	return StringName(String(entry(item_id).get("category", "")))
