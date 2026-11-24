## 355：灰灯食堂的规矩 —— 锅和食材仓库起始多大（389：变大写在灰灯的声望节点上，[method Canteen.sizes]）、每件食材管哪一类、给多少、带几点饱腹。
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
## 哪一方的声望节点让锅和仓库变大（灰灯互助会；节点效果 `canteen_pot` / `canteen_store`，参数 [宽, 高]）
@export var faction: StringName = &"greylamp"
## 开放时锅的边长
@export var pot_side: int = 4
## 开放时食材仓库的宽、高
@export var store_w: int = 6
@export var store_h: int = 6
## 饱腹度剩几点时提醒一次
@export var warn_at: int = 1
## 食材表：道具 id → {"category": 四类之一, "flat": 固定值, "pct": 百分数, "satiety": 饱腹值}。flat 与 pct 一件只写一样
@export var entries: Dictionary = {}


func pot_size() -> Vector2i:
	return Vector2i(pot_side, pot_side)


func store_size() -> Vector2i:
	return Vector2i(store_w, store_h)


## 这件食材的那一条（不是食材 = 空）
func entry(item_id: StringName) -> Dictionary:
	var e: Variant = entries.get(String(item_id), null)
	return e as Dictionary if e is Dictionary else {}


func category_of(item_id: StringName) -> StringName:
	return StringName(String(entry(item_id).get("category", "")))
