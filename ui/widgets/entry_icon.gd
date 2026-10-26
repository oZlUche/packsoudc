## 255：选角色屏条目行左端的 52 图标槽 —— 技能（`assets/ui/skills/<icon 或 id>.png`，没图用月桂环 `placeholder.png`）、
## 随身之物（道具本体缩进来 + 右上角小钉）、短板（`setup/charsel/flaw_crack` 铁灰裂纹章）。三类条目同一种行，靠它和名字颜色分（作者 2026-10-26 11:07 选甲）
class_name EntryIcon
extends Control

const SIDE := 52.0
const SKILL_DIR := "res://assets/ui/skills/"
const SKILL := &"skill"
const ITEM := &"item"
const FLAW := &"flaw"
## 没出图的技能用的月桂环
const PLACEHOLDER := "placeholder"
## 短板那一行的铁灰裂纹章（[member UiTheme.asset_root] 下）
const FLAW_ART := "setup/charsel/flaw_crack"
const SLOT := Color("1c1f27")
const SLOT_EDGE := Color("2c3140")

var kind: StringName = SKILL
var texture: Texture2D = null
var item: ItemDef = null


static func skill(sk: RunSkill) -> EntryIcon:
	var e := EntryIcon._make(SKILL)
	if sk != null:
		e.texture = texture_for(sk)
	return e


static func pinned(def: ItemDef) -> EntryIcon:
	var e := EntryIcon._make(ITEM)
	e.item = def
	return e


static func flaw() -> EntryIcon:
	var e := EntryIcon._make(FLAW)
	e.texture = UiTheme.art_cached(FLAW_ART)
	return e


static func _make(p_kind: StringName) -> EntryIcon:
	var e := EntryIcon.new()
	e.kind = p_kind
	e.custom_minimum_size = Vector2(SIDE, SIDE)
	e.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return e


## 技能图标的图；这个技能没出图用通用的月桂环 `placeholder.png`（美术 11:54）
static func texture_for(sk: RunSkill) -> Texture2D:
	for name in [sk.icon if sk.icon != "" else String(sk.id), PLACEHOLDER]:
		var path := SKILL_DIR + String(name) + ".png"
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


## 这个技能有没有自己的图（不算月桂环占位）
static func has_own_art(sk: RunSkill) -> bool:
	return ResourceLoader.exists(SKILL_DIR + (sk.icon if sk.icon != "" else String(sk.id)) + ".png")


## 有没有用上美术图（测试看）
func has_art() -> bool:
	return texture != null or (kind == ITEM and item != null and ItemPainter.art_of(item) != null)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, Vector2(SIDE, SIDE))
	match kind:
		ITEM:
			_draw_item(r)
		FLAW:
			_draw_flaw(r)
		_:
			_draw_skill(r)


func _draw_skill(r: Rect2) -> void:
	if texture != null:
		draw_texture_rect(texture, r, false)
		return
	draw_rect(r, SLOT)
	draw_rect(r.grow(-0.5), SLOT_EDGE, false, 1.0)


func _draw_item(r: Rect2) -> void:
	draw_rect(r, SLOT)
	if item != null and item.shape != null:
		var n := item.shape.size_rotated(0)
		var cell := minf((SIDE - 8.0) / n.x, (SIDE - 8.0) / n.y)
		var anchor := r.get_center() - Vector2(n) * cell * 0.5
		if not ItemPainter.draw_art(self, item, 0, anchor, cell):
			ItemPainter.draw_item(self, item.cells_rotated(0), anchor, cell, ItemPainter.body_color(item), ItemPainter.rarity_color(item))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	ItemPainter.draw_pin_badge(self, Rect2(Vector2(SIDE - 18.0, 2.0), Vector2(16, 16)))


func _draw_flaw(r: Rect2) -> void:
	_draw_skill(r)     # 铁灰章 + 裂纹（美术 11:54 定稿）；没图只剩空槽
