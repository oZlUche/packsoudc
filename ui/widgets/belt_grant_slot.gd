## 科技每局发的随身技能：一圈深色槽、技能图标、右下角数量（字画在槽上，不是散字）；悬停写技能名。
## 383：原在基地出征页的「军需」木牌上（264），军需牌删了以后挪到开局第二屏配道具，摆在棋盘那块板里
class_name BeltGrantSlot
extends Control

const SLOT := 56.0
const BADGE_FONT := 14
const INK_SLOT := Color("5a4433")

var def: BeltSkillDef = null
var count := 0
var _icon: Texture2D = null


func _init(p_def: BeltSkillDef = null, p_count: int = 0) -> void:
	def = p_def
	count = p_count
	_icon = def.icon() if def != null else null     # 留住引用（184）
	custom_minimum_size = Vector2.ONE * SLOT
	tooltip_text = Names.of(def) if def != null else ""
	mouse_filter = Control.MOUSE_FILTER_PASS


func icon() -> Texture2D:
	return _icon


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	draw_circle(c, r, INK_SLOT)
	draw_circle(c, r - 3.0, Color("e9dcc0"))
	if _icon != null:
		var s := (r - 6.0) * 2.0
		draw_texture_rect(_icon, Rect2(c - Vector2.ONE * s * 0.5, Vector2.ONE * s), false)
	var font := UiPalette.cjk_font_bold()
	var px := UiTheme.sz(BADGE_FONT)
	var text := "×%d" % count     # 右下角一枚小签：深底浅字
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var tag := Rect2(size.x - w - 8.0, size.y - px - 4.0, w + 8.0, px + 4.0)
	draw_rect(tag, INK_SLOT)
	draw_string(font, Vector2(tag.position.x + 4.0, tag.end.y - 4.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("f1ece2"))


## 局外这份存档每局发的随身技能 [[id, 个数], …]（按 id 排、0 个的不列）
static func grants_of(meta: MetaState) -> Array:
	var out: Array = []
	if meta == null:
		return out
	var ids := meta.belt_grants.keys()
	ids.sort()
	for id in ids:
		if int(meta.belt_grants[id]) > 0:
			out.append([StringName(String(id)), int(meta.belt_grants[id])])
	return out
