## 界面共用的配色与字体。
##
## 抽出来是因为两个沙盒各自复制过一份 —— 复制出来的第二份迟早跟第一份长得不一样。
class_name UiPalette
extends RefCounted

const BG := Color("101216")
const PANEL := Color("171a20")
const FG := Color("dfe3ea")
const DIM := Color("8b93a1")
const LINE := Color("2a2f38")

const HP := Color("d9534f")
const SHIELD := Color("5bc0de")
const STAMINA := Color("f0ad4e")
const MANA := Color("7a8cf0")
const HEAL := Color("5cb85c")

## 邻接标记的两个方向。**按语义分色，不是按形状** ——
## 参照作品用星形／菱形区分，那只是两个任意符号；这里直接用颜色 + 文字。
const GRANT := Color("6fb3f0")    ## 增益：我给站在这儿的邻居加成
const RECEIVE := Color("f0a85c")  ## 受益：站在这儿的邻居给我加成

## 资源键 → 条的颜色。未登记的资源用 DIM，不至于看不见。
const RESOURCE_COLORS := {
	"hp": HP,
	"shield": SHIELD,
	"stamina": STAMINA,
	"mana": MANA,
}

## 伤害类型 → 数字的颜色
const DAMAGE_COLORS := {
	"physical": Color("ff8a7a"),
	"fire": Color("ff9d4d"),
	"poison": Color("8ed36b"),
	"bleed": Color("e05c7a"),
	"reflect": Color("c9a0ff"),
	"drain": Color("9aa3b2"),
}


static func resource_color(key: StringName) -> Color:
	return RESOURCE_COLORS.get(String(key), DIM)


static func damage_color(type: StringName) -> Color:
	return DAMAGE_COLORS.get(String(type), FG)


## Godot 内置字体不含 CJK 字形，中文会显示成方块
static func cjk_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(
		["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "SimHei", "sans-serif"]
	)
	return f
