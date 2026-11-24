## 264 §二：基地「出征」页碑右边那一列 —— 「上回出征」与右下【开始探索】主键（原左下「再来一局」）。
## 383（作者 2026-11-22 22:57）：「军需」删了 —— 随身技能挪到开局第二屏，局外加成并进第一屏角色卡，选神改成第一屏的信仰横条。
## 作者 2026-11-23 18:02 选 B：换石刻（UI设计 基地例图 1）—— 浅石框里一枚浅石小签「上回出征」，下面一块深石板卡：
## 肖像 + 角色名、「地图 · 规模 · 难度」一行灰字；「结果」段：撤离 / 战败与带回价值、打赢几场、带回几件（读对局记录第一行）。
## 【开始探索】= 深石板金字主键，和框一样宽
class_name ExpeditionBoard
extends VBoxContainer

const WIDTH := 560.0
const LAST_H := 340.0
const START := Vector2(560, 96)
const START_FONT := 30
const PORTRAIT := 72
const NAME_FONT := 22
const LINE_FONT := 17
const SUB_FONT := 15

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
	add_theme_constant_override("separation", 22)
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
	start_btn = UiTheme.make_stone_button(UiText.t("meta.new_run"), flow.new_run, true, START, START_FONT)
	start_btn.name = "StartButton"
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_child(start_btn)
	return self


## 浅石框：左上一枚浅石小签，下面一块深石板卡；返回框，[method _col] 取卡里那一列
func _plate(h: float, title_key: String) -> PanelContainer:
	var p := StoneKit.frame(22)
	p.name = "Plate"
	p.custom_minimum_size = Vector2(WIDTH, h)
	add_child(p)
	var col := UiTheme.vbox(14)
	p.add_child(col)
	col.add_child(StoneKit.tag(UiText.t(title_key)))
	var card := StoneKit.slate(18)
	card.name = "Card"
	col.add_child(card)
	card.add_child(UiTheme.vbox(10))
	return p


static func _col(p: PanelContainer) -> VBoxContainer:
	return (p.get_child(0) as Control).get_node("Card").get_child(0)


## 统一教程 D：下一段是哪张图、第几段；右下一个「跳过剩余教程」（点了先弹确认页，不直接跳）
func _fill_tutorial(col: VBoxContainer, nxt: ChapterDef) -> void:
	col.add_child(UiTheme.make_label(Names.of(nxt), NAME_FONT, StoneKit.TEXT))
	col.add_child(UiTheme.make_label(UiText.t("meta.tutorial_step") % [flow.tutorial_number(nxt), flow.tutorial_chapters().size()], SUB_FONT, StoneKit.DIM))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	skip_btn = UiTheme.flat_key(UiText.t("meta.tutorial_skip"), Color(0, 0, 0, 0), StoneKit.DIM, SKIP_HOVER, StoneKit.TEXT, SKIP_SIZE, 15)
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
	try_btn = UiTheme.flat_key(UiText.t("meta.tutorial_try"), Color(0, 0, 0, 0), StoneKit.DIM, SKIP_HOVER, StoneKit.TEXT, SKIP_SIZE, 15)
	try_btn.name = "TryTutorial"
	try_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	try_btn.pressed.connect(func(): flow.try_tutorial())
	col.add_child(try_btn)


const SKIP_SIZE := Vector2(150, 32)
const SKIP_HOVER := Color(0.94, 0.9, 0.82, 0.12)


## 上回出征：开局屏出发时记下的角色（[member MetaState.last_character]）与图 / 规模 / 难度旗标（开局屏照这些预选）；
## 「结果」读对局记录第一行（[member MetaState.history]）
func _fill_last(col: VBoxContainer) -> void:
	var m := flow.meta
	var ch := flow.character_of(m.last_character) if m.last_character != &"" else null
	var chapter := _last_chapter()
	if ch == null and chapter == null:
		col.add_child(_line(UiText.t("meta.none_yet")))
		return
	var row := UiTheme.hbox(14)
	col.add_child(row)
	if ch != null:
		row.add_child(PortraitSlot.new(PORTRAIT, Nameplate.character_face(ch.id)))
	var who := UiTheme.vbox(2)
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(who)
	if ch != null:
		var name_ := UiTheme.make_label(Names.of(ch), NAME_FONT, StoneKit.TEXT)
		who.add_child(name_)
		_last_lines.append(name_.text)
	var bits: Array[String] = []
	if chapter != null:
		var map := Names.of(chapter) if chapter.display_name != "" else String(chapter.id)
		var scale_ := _last_scale(chapter)
		var where := map + (UiText.t("setup.sep") + scale_ if scale_ != "" else "")
		bits.append(where)
		_last_lines.append(where)
	var diff := _last_difficulty()
	if diff != null:
		var text := Names.of(diff)     # 难度名自己带级（「进阶一」）
		bits.append(text)
		_last_lines.append(text)
	if not bits.is_empty():
		who.add_child(UiTheme.make_label(UiText.t("setup.sep").join(bits), SUB_FONT, StoneKit.DIM))
	var h: Dictionary = m.history[0] if not m.history.is_empty() and m.history[0] is Dictionary else {}
	if h.is_empty():
		return
	col.add_child(StoneKit.head(UiText.t("meta.last_result")))
	var won := String(h.get("outcome", "")) == "extracted"
	col.add_child(StoneKit.row(UiText.t("records.outcome_extracted" if won else "records.outcome_defeated"),
		UiText.t("meta.last_value") % int(h.get("value", 0)), StoneKit.GOLD if won else StoneKit.DIM))
	col.add_child(StoneKit.row(UiText.t("meta.last_won"), UiText.t("meta.last_won_v") % int(h.get("battles_won", 0)), StoneKit.TEXT))
	var items: Array = h.get("items", []) if h.get("items", []) is Array else []
	col.add_child(StoneKit.row(UiText.t("meta.last_brought"), UiText.t("meta.last_brought_v") % items.size(), StoneKit.TEXT))


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
	return UiTheme.make_label(text, LINE_FONT, StoneKit.TEXT)


func last_lines() -> Array[String]:
	return _last_lines
