## 一块凹进铜板的深槽（`bronze/tag_inlay` 九宫拉开，缺图 = 半透明深底），里面放浅色字。
## 战斗回放的战报垫在它上面，不直接写在斗技场图上（复测 v3.79 裸字）
class_name InlayPlate
extends PanelContainer

const ART := "bronze/tag_inlay"
## 图里槽身那一块（上下有留白）与九宫边
const REGION := Rect2(0, 8, 90, 42)
const SLICE := 10.0
const PAD := Vector2(14, 8)


func _init() -> void:
	add_theme_stylebox_override("panel", box())
	UiTheme.set_tone(self, UiTheme.TONE_DARK)


static func box() -> StyleBox:
	var tex := UiTheme.art_cached(ART)
	var b: StyleBox
	if tex == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color("2a1c0e", 0.85)
		flat.set_corner_radius_all(6)
		b = flat
	else:
		var t := StyleBoxTexture.new()
		t.texture = tex
		t.region_rect = REGION
		t.set_texture_margin_all(SLICE)
		b = t
	b.content_margin_left = PAD.x
	b.content_margin_right = PAD.x
	b.content_margin_top = PAD.y
	b.content_margin_bottom = PAD.y
	return b
