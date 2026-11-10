## 套装编辑器（091，作者定）：给作者做套装 —— id、名字、计数方式、各档位（集齐几件生效什么：属性修饰 / 规则 / 别的作用域的效果）。
##
## 和道具 / 事件 / buff 编辑器同一条原则：**不是另一条通路，只是同一条通路的另一个入口。** 存的是 `data/authoring/sets/<id>.json`，
## 校验走导入器（`import_set`），档位与效果构件由 [PropertyForm] 反射生成（字段中文 + 悬浮说明走 [FieldText]）；保存同时产出 `.tres`。
## 哪些道具属于这套看右边的「成员」：道具的 `set_id` 写这个 id 就算（在道具编辑器里改）。列表 / 草稿 / 存盘在 [AuthoringEditor]（141）。
extends AuthoringEditor

const KIND := "sets"

var _items: ItemDatabase = null

var _summary: Label
var _members: Label


func _init() -> void:
	_kind = KIND
	_texts = LIBRARY_TEXTS


func _before_build() -> void:
	_items = ItemDatabase.new()
	_items.load_dir()


#region 界面
func _build_ui() -> void:
	UiTheme.prepare_root(self, false)     # 121：装上界面主题、铺底色（设置在 _ready 里已经读过、apply 过）
	# 左：列表
	var left := _left_column(220)
	_list_block(left, "套装")

	# 中：字段
	var mid := _mid_column(left)
	mid.add_child(_id_row())
	var body := _scroll_body(mid)

	body.add_child(_name_row())
	body.add_child(UiTheme.make_wrapped("档位按件数升序、**累加**生效：4 件套同享 2 件档与 4 件档；要互斥就把高档写成增量。每档三个列表：属性修饰（编译期并入）、规则（要扳机）、别的作用域的效果（激活即生效）。", 12, UiPalette.DIM, 520))
	body.add_child(HSeparator.new())
	_form_host = VBoxContainer.new()
	_form_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_form_host)

	# 右：摘要 / 成员 / 校验 / 代码
	var side := _side_column(mid, 380)
	_summary = UiTheme.make_wrapped("", 13, UiPalette.FG, 360)
	side.add_child(_summary)
	side.add_child(UiTheme.make_label("成员（道具的 set_id 写这个 id；在道具编辑器里改）", 13, UiPalette.DIM))
	_members = UiTheme.make_wrapped("", 12, UiPalette.FG, 360)
	side.add_child(_members)
	_status_block(side)
	_json_block(side)

#endregion


#region 公开（测试直接调）
func def() -> ItemSetDef:
	return _def


## 属于这套的道具 id（道具的 set_id == 当前 id）
func members() -> Array[String]:
	var out: Array[String] = []
	if _def == null or _items == null:
		return out
	for id in _items.all_ids():
		if _items.get_def(id).set_id == _def.id:
			out.append(String(id))
	out.sort()
	return out


func summary_text() -> String:
	if _def == null:
		return ""
	var parts: Array[String] = []
	for t in _def.tiers:
		var tier := t as SetTier
		if tier != null:
			parts.append("%d 件：%d 修饰 / %d 规则 / %d 效果" % [tier.pieces, tier.mods.size(), tier.rules.size(), tier.effects.size()])
	var mode: String = "同一定义只算一次" if _def.count_mode == ItemSetDef.CountMode.DISTINCT_DEFS else "每件实例算一件"
	return "%s（%s）　%s\n%s" % [_def.display_name, _def.id, mode, "　".join(parts) if not parts.is_empty() else "（还没有档位）"]


## 加一档（集齐 [param pieces] 件）；测试与「新建」用
func add_tier(pieces: int) -> SetTier:
	var tier := SetTier.new()
	tier.pieces = pieces
	_def.tiers.append(tier)
	_def.tiers.sort_custom(func(a: SetTier, b: SetTier) -> bool: return a.pieces < b.pieces)
	_rebuild_form()
	_refresh()
	return tier
#endregion


#region 列表与草稿（公共的在 AuthoringEditor）
func _export(d) -> Dictionary:
	return ContentExporter.dump(d)


func _import(data: Dictionary, report: ImportReport) -> Resource:
	return ContentImporter.import_set(data, _ctx, report)


func _new_def() -> Resource:
	var def_ := ItemSetDef.new()
	def_.id = &"new_set"
	def_.display_name = "新套装"
	var tier := SetTier.new()
	tier.pieces = 2
	def_.tiers.append(tier)
	return def_


func _form_skip() -> Dictionary:
	return {"ItemSetDef": ["id", "display_name"]}
#endregion


#region 刷新
func _on_refreshed() -> void:
	_summary.text = summary_text()
	var who := members()
	_members.text = "、".join(who) if not who.is_empty() else "（还没有道具的 set_id 写着这个 id）"
#endregion
