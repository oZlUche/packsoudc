## 255：选角色屏条目行左端的 52 图标槽 —— 技能（`assets/ui/skills/<icon 或 id>.png`，没图画一枚通用的月桂纹样占位）、
## 随身之物（道具本体缩进来 + 右上角小钉）、短板（裂纹纹样占位）。三类条目同一种行，靠它和名字颜色分（作者 2026-10-26 11:07 选甲）
class_name EntryIcon
extends Control

const SIDE := 52.0
const SKILL_DIR := "res://assets/ui/skills/"
const SKILL := &"skill"
const ITEM := &"item"
const FLAW := &"flaw"
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
	return EntryIcon._make(FLAW)


static func _make(p_kind: StringName) -> EntryIcon:
	var e := EntryIcon.new()
	e.kind = p_kind
	e.custom_minimum_size = Vector2(SIDE, SIDE)
	e.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return e


## 技能图标的图（美术没出 = null，画占位）
static func texture_for(sk: RunSkill) -> Texture2D:
	var path := SKILL_DIR + (sk.icon if sk.icon != "" else String(sk.id)) + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


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
	var c := r.get_center()
	var brass := UiPalette.BTN_PRIMARY_HOVER.darkened(0.25)
	draw_arc(c, 16.0, deg_to_rad(110), deg_to_rad(250), 12, brass, 2.0)     # 月桂两枝
	draw_arc(c, 16.0, deg_to_rad(-70), deg_to_rad(70), 12, brass, 2.0)
	for i in 4:
		var a := deg_to_rad(130 + i * 30)
		draw_circle(c + Vector2(cos(a), sin(a)) * 16.0, 2.5, brass)
		draw_circle(c + Vector2(-cos(a), sin(a)) * 16.0, 2.5, brass)
	draw_circle(c, 5.0, brass)


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
	draw_rect(r, Color("15171b"))
	draw_rect(r.grow(-0.5), Color("3a3e45"), false, 1.0)
	var crack := Color("6b7178")
	var pts := PackedVector2Array([Vector2(26, 4), Vector2(22, 16), Vector2(30, 24), Vector2(20, 34), Vector2(27, 48)])
	draw_polyline(pts, crack, 2.0)
	draw_line(Vector2(30, 24), Vector2(42, 30), crack, 1.5)
	draw_line(Vector2(22, 16), Vector2(12, 12), crack, 1.5)
