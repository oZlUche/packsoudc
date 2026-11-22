## 264 §二（作者 16:43「按推荐来」= 线框 1-A）：基地「出征」页碑右边那一列 —— 「上回出征」木牌（角色肖像小框 + 名、地图 · 规模、难度）、
## 右下【开始探索】主档木牌（原左下「再来一局」）。383（作者 2026-11-22 22:57）：「军需」木牌删了 —— 随身技能挪到开局第二屏配道具，
## 局外加成并进第一屏角色卡的数字；选神也不在这里跳，改成开局第一屏的信仰横条。
## 木牌定稿（UI替换美术 plaque264）：大木牌 [constant UiTheme.PANEL_HOME_PLAQUE]，标题是挂牌 [method HeaderTag.hanging] 挂在木牌左上（x + 18、高出 34）；
## 局外加成与难度写在平的浅羊皮小签上（[constant UiTheme.PANEL_HOME_CHIP]）。不做「沿用上回直接出发」（待定 2）
class_name ExpeditionBoard
extends VBoxContainer

const WIDTH := 560.0
const LAST_H := 200.0
const START := Vector2(360, 96)
const START_FONT := 30
const PORTRAIT := 72
const NAME_FONT := 22
const LINE_FONT := 17
## 挂牌摆法：左边让多少、高出木牌上沿多少（挂牌 46 高，压进木牌 12）
const TAG_X := 18
const TAG_RISE := 34.0
const CHIP_FONT := 15

## 统一教程 D（方案 §8.1 / §8.2）：教程还没全通时点了「跳过剩余教程」（基地弹确认页，[method MetaScreen.show_skip_tutorial]）
signal skip_asked()

var flow: GameFlow = null
var start_btn: Button = null
var last_plate: PanelContainer = null
## 教程木牌（教程还没全通才有，顶替「上回出征」）
var tutorial_plate: PanelContainer = null
var skip_btn: Button = null
## 「上回出征」三行写的字（测试看）；没出征过是空
var _last_lines: Array[String] = []


func setup(p_flow: GameFlow) -> ExpeditionBoard:
	flow = p_flow
	add_theme_constant_override("separation", 18)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var nxt := flow.tutorial_gate()
	if nxt != null:
		tutorial_plate = _plate(LAST_H, "meta.tutorial")
		_fill_tutorial(_col(tutorial_plate), nxt)
	else:
		last_plate = _plate(LAST_H, "meta.last_expedition")
		_fill_last(_col(last_plate))
		if flow.legacy_tutorial() != null:
			_fill_try(_col(last_plate))
	start_btn = UiTheme.make_home_button(UiText.t("meta.new_run"), flow.new_run, true, START, START_FONT)
	start_btn.name = "StartButton"
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_child(start_btn)
	return self


## 一块大木牌连它的挂牌：挂牌在上（画在木牌上面），木牌往上收 12 压住挂牌下沿；返回木牌，[method _col] 取里面那一列
func _plate(h: float, title_key: String) -> PanelContainer:
	var wrap_ := UiTheme.vbox(-int(HeaderTag.HANG_HEIGHT - TAG_RISE))
	add_child(wrap_)
	var hold := MarginContainer.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hold.add_theme_constant_override("margin_left", TAG_X)
	hold.z_index = 1     # 挂牌压在木牌框上
	hold.add_child(HeaderTag.hanging(UiText.t(title_key)))
	wrap_.add_child(hold)
	var p := UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_HOME_PLAQUE)
	p.custom_minimum_size = Vector2(WIDTH, h)
	wrap_.add_child(p)
	p.add_child(UiTheme.vbox(10))
	return p


static func _col(p: PanelContainer) -> VBoxContainer:
	return p.get_child(0)


## 平的浅羊皮小签：一行墨字
func _chip(text: String) -> PanelContainer:
	var chip := UiTheme.panel(PanelContainer.new(), -1, UiTheme.PANEL_HOME_CHIP)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.add_child(UiTheme.make_label(text, CHIP_FONT, UiTheme.INK))
	return chip


## 统一教程 D：下一段是哪张图、第几段；右下一个「跳过剩余教程」（点了先弹确认页，不直接跳）
func _fill_tutorial(col: VBoxContainer, nxt: ChapterDef) -> void:
	col.add_child(UiTheme.make_label(Names.of(nxt), NAME_FONT, UiTheme.INK))
	col.add_child(_chip(UiText.t("meta.tutorial_step") % [flow.tutorial_number(nxt), flow.tutorial_chapters().size()]))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	skip_btn = UiTheme.flat_key(UiText.t("meta.tutorial_skip"), Color(0, 0, 0, 0), UiTheme.INK, SKIP_HOVER, UiTheme.INK, SKIP_SIZE, 15)
	skip_btn.name = "SkipTutorial"
	skip_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip_btn.pressed.connect(func(): skip_asked.emit())
	col.add_child(skip_btn)


## 统一教程 F：切片老档在「上回出征」右下多一个「体验统一教程」（[method GameFlow.try_tutorial]）
var try_btn: Button = null


func _fill_try(col: VBoxContainer) -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	try_btn = UiTheme.flat_key(UiText.t("meta.tutorial_try"), Color(0, 0, 0, 0), UiTheme.INK, SKIP_HOVER, UiTheme.INK, SKIP_SIZE, 15)
	try_btn.name = "TryTutorial"
	try_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	try_btn.pressed.connect(func(): flow.try_tutorial())
	col.add_child(try_btn)


const SKIP_SIZE := Vector2(150, 32)
const SKIP_HOVER := Color("8a5a2b")


## 上回出征：开局屏出发时记下的角色（[member MetaState.last_character]）与图 / 规模 / 难度旗标（开局屏照这些预选）
func _fill_last(col: VBoxContainer) -> void:
	var m := flow.meta
	var ch := flow.character_of(m.last_character) if m.last_character != &"" else null
	var chapter := _last_chapter()
	if ch == null and chapter == null:
		col.add_child(_line(UiText.t("meta.none_yet")))
		return
	if ch != null:
		var row := UiTheme.hbox(14)
		col.add_child(row)
		row.add_child(PortraitSlot.new(PORTRAIT, Nameplate.character_face(ch.id)))
		var name_ := UiTheme.make_label(Names.of(ch), NAME_FONT, UiTheme.INK)
		name_.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name_)
		_last_lines.append(name_.text)
	if chapter != null:
		var map := Names.of(chapter) if chapter.display_name != "" else String(chapter.id)
		var scale_ := _last_scale(chapter)
		var where := map + (UiText.t("setup.sep") + scale_ if scale_ != "" else "")
		col.add_child(_line(where))
		_last_lines.append(where)
	var diff := _last_difficulty()
	if diff != null:
		var text := Names.of(diff)     # 难度名自己带级（「进阶一」）
		col.add_child(_chip(text))
		_last_lines.append(text)


func _last_chapter() -> ChapterDef:
	var at := flow.meta.flag(&"last_map") - 1
	if at < 0:
		return null
	for c in flow.chapters:
		if c.order == at:
			return c
	return null


func _last_scale(c: ChapterDef) -> String:
	var at := flow.meta.flag(&"last_scale") - 1
	var opts: Array[Dictionary] = c.map_source.scale_options() if c.map_source != null else [] as Array[Dictionary]
	return String(opts[at]["display_name"]) if at >= 0 and at < opts.size() else ""


func _last_difficulty() -> DifficultyDef:
	var level := flow.meta.flag(&"last_difficulty")
	for d in flow.difficulties:
		if d.level == level:
			return d
	return null


func _line(text: String) -> Label:
	return UiTheme.make_label(text, LINE_FONT, UiTheme.INK)


func last_lines() -> Array[String]:
	return _last_lines
