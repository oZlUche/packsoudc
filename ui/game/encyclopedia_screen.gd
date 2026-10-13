## 百科屏（114，作者定）：左栏搜索框 + 按分类的目录，右栏一页。页里认得的词是**链接**（点开跳页，比悬浮稳），
## 顶上「← 上一页」记一条浏览栈。数据是 [Encyclopedia]（[method GameFlow.encyclopedia]），这里只画。
##
## 两个入口：主菜单（独立一屏，「返回」回主菜单）、地图的暂停菜单（嵌进遮罩，[member back] 回暂停菜单，Esc 先关它）。
## 打开时 `payload = {"page": id}` 直接定位（将来悬浮窗「右键 → 百科」用它）
extends GameScreen

const TOC_WIDTH := 300.0
const PAGE_WIDTH := 760.0

## 嵌在暂停菜单里时的「返回」；空 = 独立的一屏，回主菜单
var back: Callable = Callable()

var book: Encyclopedia = null
var _ctx: Dictionary = {}
var _current: String = ""
var _history: Array[String] = []
var _query: String = ""

var _search: LineEdit
var _toc: VBoxContainer
var _title: Label
var _body: RichTextLabel
var _prev_btn: Button


func open(payload: Dictionary) -> void:
	book = flow.encyclopedia()
	_ctx = TextTemplate.context_for(flow.run) if flow.run != null else {"_items": flow.items, "_faiths": flow.faith_defs}
	_backdrop(Color(0.04, 0.05, 0.07, 0.96))
	var panel := _centered_panel(Vector2(TOC_WIDTH + PAGE_WIDTH + 80, 820), 20)
	var row := _hbox(20)
	panel.add_child(row)

	var left := _vbox(8)
	left.custom_minimum_size.x = TOC_WIDTH
	row.add_child(left)
	_frame_title("百科")     # 157：标题在石板框的标题条上
	_search = LineEdit.new()
	_search.placeholder_text = "搜索标题或正文"
	_search.text_changed.connect(set_query)
	left.add_child(_search)
	var toc_scroll := ScrollContainer.new()
	toc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	toc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(toc_scroll)
	_toc = _vbox(2)
	_toc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toc_scroll.add_child(_toc)
	left.add_child(_button("返回" if back.is_valid() else "回主菜单", go_back, 14))

	var right := _vbox(10)
	right.custom_minimum_size.x = PAGE_WIDTH
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	_prev_btn = _button("← 上一页", go_previous, 13, UiPalette.Tier.MINOR)
	_prev_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	right.add_child(_prev_btn)
	_title = _label("", 24, UiPalette.FG)
	right.add_child(_title)
	right.add_child(HSeparator.new())
	var page_scroll := ScrollContainer.new()
	page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(page_scroll)
	_body = UiTheme.rich_block(PAGE_WIDTH - 20, UiTheme.RICH_BODY_SIZE)     # 121：正文档（现 20 号、行距 8）
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.meta_clicked.connect(func(meta: Variant): open_page(String(meta)))
	page_scroll.add_child(_body)

	_fill_toc()
	var first := String(payload.get("page", ""))
	if not book.has_page(first):
		first = book.ids()[0] if not book.ids().is_empty() else ""
	open_page(first, false)


#region 公开动作（测试与输入都走这里）
## 翻到一页；[param remember] 为真时把当前页压进浏览栈（「← 上一页」回得去）。页不存在返回 false
func open_page(id: String, remember: bool = true) -> bool:
	if book == null or not book.has_page(id):
		return false
	if remember and _current != "" and _current != id:
		_history.append(_current)
	_current = id
	_title.text = String(book.page(id)["title"])
	_body.text = UiTheme.slab_bbcode(UiPalette.resolve_styles(book.render(id, _ctx)))
	_prev_btn.disabled = _history.is_empty()
	return true


## 回到上一页（浏览栈弹一页）。没有上一页返回 false
func go_previous() -> bool:
	if _history.is_empty():
		return false
	var id: String = _history.pop_back()
	open_page(id, false)
	return true


## 搜索：空 = 全目录；有字 = 只列命中的页
func set_query(q: String) -> void:
	_query = q
	_fill_toc()


func current_page() -> String:
	return _current


## 目录里现在列着的页 id（测试看）
func listed() -> Array[String]:
	var out: Array[String] = []
	for c in _toc.get_children():
		if c is Button and c.has_meta("page"):
			out.append(String(c.get_meta("page")))
	return out


func go_back() -> void:
	if back.is_valid():
		back.call()
	else:
		flow.to_main_menu()


func escape() -> bool:
	go_back()
	return true
#endregion


func _fill_toc() -> void:
	UiTheme.clear_children(_toc)
	if _query.strip_edges() != "":
		var hits := book.search(_query, _ctx)
		_toc.add_child(_label("找到 %d 页" % hits.size(), 13, UiPalette.DIM))
		for id in hits:
			_toc.add_child(_page_button(id))
		return
	for cat in book.toc():
		_toc.add_child(_label(String(cat["name"]), 16, UiPalette.FG))
		for g in cat["groups"]:
			if String(g["name"]) != "":
				_toc.add_child(_label("　" + String(g["name"]), 13, UiPalette.DIM))
			for id in g["ids"]:
				_toc.add_child(_page_button(id))


func _page_button(id: String) -> Button:
	var b := _button(String(book.page(id)["title"]), func(): open_page(id), 13, UiPalette.Tier.MINOR)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.set_meta("page", id)
	return b
