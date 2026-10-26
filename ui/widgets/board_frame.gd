## 棋盘外框（227：全游戏每一块棋盘都有外框和格线 —— 作者 2026-10-21 17:25「所有的棋盘都要显示（包括格子）」）。
## 一个 PanelContainer，九宫格外框图做底、[InventoryView] 是唯一的子节点，格子缩进 = 切图的 `cells_offset`。
## 浅框是 `assets/ui/board/` 的 `pieces`（皮带 player、藤编 search、生皮 corpse、素框 plain……），框里的浅灰内垫画在图上，
## 格缝照 `cell_seams`；深框（铜面板三屏，UI替换美术 bronze3 `frames_dark`，作者 2026-10-21 16:15）是 `assets/ui/bronze/frame_<kind>_dark.png`，
## 内垫深色半透明（铜面板透出来），格缝照 [method dark_seams]；深色素框 `plain_dark` 在 board 的 `pieces` 里。没图 = 空框只留边距。
##
## 自己画外框的几块（搜刮 / 战利品屏、背包窗、结算带回的棋盘：外框是另摆的一张 NinePatchRect）用 [method mark] 登记，
## 守门测试（`test_boards_framed_227`）认这两种
class_name BoardFrame
extends PanelContainer

const DIR := "res://assets/ui/bronze/"
const LAYOUT := "bronze/layout"
const LIGHT_DIR := "res://assets/ui/board/"
const LIGHT_LAYOUT := "board/layout"
## [method mark] 写在视图上的 meta：外框是屏自己摆的那张图
const FRAMED_META := &"board_framed_by"

## 实际用上的框（[member dark] 时是深色那套）
var kind := ""
var dark := false
## 255：沿格子轮廓走的框（作战棋盘有缺格时）—— 不画九宫格图，按 [BoardContour] 的拼件规则拼：能用的格垫浅灰底，
## 直边 → 凹角 → 凸角；缺格什么都不画（透空见底板）。拼件图在 `board/mask/<name>.png`（美术定稿后交来），没图画占位皮带
var contour: GridInventory = null
## 拼件图的目录（[member UiTheme.asset_root] 下）
const MASK_DIR := "board/mask/"
## 没图时占位皮带的颜色
const CONTOUR_FILL := Color("6b4a2e")
const CONTOUR_EDGE := Color("2a1a0e")


## 227：把 [param view] 套进外框 —— [param kind] 空 = 棋盘（`requires_bag`）用皮带 `player`、别的（槽、出售区、祭品台、保险箱……）用素框 `plain`；
## [param p_dark] 选铜面板屏那套深色框。原来在哪个父节点、第几个，框就放在那儿；视图的格缝跟着内垫换（深内垫深缝、浅内垫浅缝）
static func wrap(view: Control, p_kind: String = "", p_dark: bool = false) -> BoardFrame:
	var k := p_kind
	if k == "":
		var inv: GridInventory = (view as InventoryView).inventory if view is InventoryView else null
		k = "player" if inv != null and inv.requires_bag else "plain"
	var f := BoardFrame.new()
	f.name = "BoardFrame"
	f.kind = k
	f.dark = p_dark
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	f.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var inv0: GridInventory = (view as InventoryView).inventory if view is InventoryView else null
	if inv0 != null and inv0.requires_bag and inv0.blocked_count() > 0:
		f.contour = inv0     # 255：有缺格的作战棋盘 —— 框沿轮廓走（作者 11:10：边上的缺格收边、中间的缺格透空）
		var empty := StyleBoxEmpty.new()
		empty.set_content_margin_all(box(k, p_dark).content_margin_left)
		f.add_theme_stylebox_override("panel", empty)
	else:
		f.add_theme_stylebox_override("panel", box(k, p_dark))
	UiTheme.set_tone(f, UiTheme.TONE_DARK if p_dark else UiTheme.TONE_LIGHT)
	var parent := view.get_parent()
	if parent != null:
		var at := view.get_index()
		parent.remove_child(view)
		parent.add_child(f)
		parent.move_child(f, at)
	f.add_child(view)
	if view is InventoryView:     # 铜面板的深框内垫是深色半透明；board 那套（含 `plain_dark`）内垫是浅灰
		(view as InventoryView).seams = dark_seams() if String(piece(k, p_dark).get("dir", "")) == DIR else light_seams()
	return f


## 255：轮廓框 —— 能用的格垫底（浅灰内垫色），再按 [BoardContour.pieces] 摆拼件（按格边长缩放）
func _draw() -> void:
	if contour == null:
		return
	var view := get_child(0) as InventoryView if get_child_count() > 0 else null
	var cell := view.cell_px if view != null else InventoryView.CELL
	var o := Vector2.ONE * inset()
	var k := cell / BoardContour.CELL
	var pad := Color(String(light_seams().get("base", "#c9c7c2")))
	var usable := func(c: Vector2i) -> bool: return not contour.is_blocked(c)
	for y in contour.size.y:
		for x in contour.size.x:
			if usable.call(Vector2i(x, y)):
				draw_rect(Rect2(o + Vector2(x, y) * cell, Vector2(cell, cell)), pad)
	for pc in BoardContour.pieces(contour.size, usable):
		var r: Rect2 = pc["rect"]
		r = Rect2(o + r.position * k, r.size * k)
		var tex := UiTheme.art_cached(MASK_DIR + String(pc["name"]))
		if tex != null:
			draw_texture_rect(tex, r, false)
		else:
			draw_rect(r, CONTOUR_FILL)
			draw_rect(r, CONTOUR_EDGE, false, 1.0)


## 九宫格框套在太窄 / 太矮的棋盘上会被裁掉一边（游戏测试 v4.39：铁匠铺 1×4 的长剑，格子区 14 px 宽时右边框没了；实测 ≥ 18 px 才完整）
const MIN_SIDE := 20.0


## 小件按格子边长 [param cell] 画时，棋盘至少要几格才不裁框：宽 / 高不足 [constant MIN_SIDE] 的一边补空格
static func padded_size(cells: Vector2i, cell: float) -> Vector2i:
	var need := ceili(MIN_SIDE / maxf(cell, 1.0))
	return Vector2i(maxi(cells.x, need), maxi(cells.y, need))


## 铜面板三屏的深色框（[method wrap] 的深色那一支；战前 / 战斗 / 战利品沿用这个名字）
static func around(view: Control, p_kind: String) -> BoardFrame:
	return BoardFrame.wrap(view, p_kind, true)     # 不写类名会叫成全局的 wrap(值, 下限, 上限)


## 227：外框是屏自己摆的一张图（搜刮屏、背包窗、结算带回的棋盘）—— 登记一下，守门测试认它；[param seams] 空 = 浅色格缝
static func mark(view: InventoryView, frame: Node, seams: Dictionary = {}) -> void:
	view.set_meta(FRAMED_META, frame)
	view.seams = seams if not seams.is_empty() else light_seams()


## 这个视图有没有外框：祖先里有 [BoardFrame]，或屏自己摆了框（[method mark]）
static func framed(view: Control) -> bool:
	if view.has_meta(FRAMED_META):
		return true
	var n := view.get_parent()
	while n != null:
		if n is BoardFrame:
			return true
		n = n.get_parent()
	return false


## 一块切片的参数：深色先找铜面板的 `frames_dark`、没有再找 board 的 `<kind>_dark`；浅色是 board 的 `pieces`
static func piece(p_kind: String, p_dark: bool) -> Dictionary:
	if p_dark:
		var bronze: Dictionary = (layout().get("frames_dark", {}) as Dictionary).get(p_kind, {})
		if not bronze.is_empty():
			return bronze.merged({"dir": DIR})
		var board: Dictionary = (light_layout().get("pieces", {}) as Dictionary).get(p_kind + "_dark", {})
		return board.merged({"dir": LIGHT_DIR, "file": board.get("file", "frame_%s_dark.png" % p_kind)})
	var light: Dictionary = (light_layout().get("pieces", {}) as Dictionary).get(p_kind, {})
	return light.merged({"dir": LIGHT_DIR, "file": light.get("file", "frame_%s.png" % p_kind)})


static func box(p_kind: String, p_dark: bool = true) -> StyleBox:
	var p := piece(p_kind, p_dark)
	var path := String(p.get("dir", DIR)) + String(p.get("file", "frame_%s_dark.png" % p_kind))
	var tex := EventImage.load_texture(path) if ResourceLoader.exists(path) else null
	var out: StyleBox
	if tex != null:
		var sbt := StyleBoxTexture.new()
		sbt.texture = tex
		sbt.set_texture_margin_all(float(p.get("margin", 70)))
		sbt.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		sbt.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		out = sbt
	else:
		out = StyleBoxEmpty.new()
	out.set_content_margin_all(float(p.get("cells_offset", 40)))
	return out


## 格子离框外沿多远（切图的 `cells_offset`）—— 摆在底图固定位置上的槽（铸炉）把框往外挪这么多，格子不动
func inset() -> float:
	return get_theme_stylebox("panel").content_margin_left


## 铜面板三屏的排版（UI替换美术 bronze3 `layout.json`）
static func layout() -> Dictionary:
	return UiTheme.art_meta(LAYOUT)


## 浅色棋盘的排版（`assets/ui/board/layout.json`：`pieces`、`cell_seams`）
static func light_layout() -> Dictionary:
	return UiTheme.art_meta(LIGHT_LAYOUT)


## 深色内垫上的格缝（黑缝 40%、亮线 30%，两端缩 3）—— [member InventoryView.seams] 认的键
static func dark_seams() -> Dictionary:
	return ((layout().get("boards_dark", {}) as Dictionary).get("cell_seams", {}) as Dictionary).duplicate()


## 浅灰内垫上的格缝（深线 + 右 / 下错开 1.4 的亮线）
static func light_seams() -> Dictionary:
	return (light_layout().get("cell_seams", {}) as Dictionary).duplicate()
