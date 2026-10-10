## 141：内容编辑器（道具 / 事件 / buff / 套装）共用的一段 —— 列表、草稿、判脏、打开、存盘、另存、套用 JSON、放弃、重扫、状态文本。
##
## 四个编辑器以前各写一份，只有种类、导出 / 导入的那一对函数、表单和提示语不同；各写一份的代价是漂移
## （套装编辑器多处理了「草稿里有、盘上没有」，别的三个没有）。现在那段只在这里，四个编辑器一样：
##
## - 列表 = 盘上的 id + 还没存过盘的草稿；改 id 时旧名字下那份草稿撤掉，盘上也没有就从列表里消失
## - 草稿只在内存里（关掉编辑器就没了），按「打开时的 id」记；和盘上那份规范化 JSON 一样就不算草稿
## - 存盘 = 导出成 JSON、经导入器建资产（与命令行一致），有错不写；同时写 `.json` 与 `.tres`
##
## 子类要给：[member _kind]（`_init` 里填，[ContentPaths] 的种类）、[method _export]、[method _import]、[method _new_def]，
## 界面那几样（[member _list]、[member _status]、[member _json]）在 `_build_ui` 里造；按需覆盖 [method _on_bound]、
## [method _collect]、[method _on_refreshed]、[method _t]、[method _saved_text]。测试直接碰的私有名字（`_def`、`_ids`、`_drafts`……）都在这里
class_name AuthoringEditor
extends Control

## 状态栏的默认提示语（道具 / 事件编辑器用的这一套）；子类 [method _t] 换自己的
const TEXTS := {
	"ok": "✓ 没有问题",
	"unreadable": "读不出 %s.json",
	"err_id": "id 不能为空",
	"err_save": "有错误，没有保存",
	"err_write": "作者数据写入失败",
	"warn_asset": "JSON 存了，但资产写入失败 —— 跑一次 import_content",
	"err_json": "JSON 语法错误",
}

## [ContentPaths] 的种类（"items" / "events" / "buffs" / "sets"）
var _kind: String = ""
var _font: Font
## 列表里的 id：盘上的 + 没存过盘的草稿，按 id 排
var _ids: Array[String] = []
## 当前这件打开时的 id（新建的为空）
var _current_id: String = ""
## 正在编辑的对象
var _def = null
## 改过但还没存盘的：列表键 → 正在编辑的对象。**切走不丢改动**
var _drafts: Dictionary = {}
## 列表键 → 盘上那份的规范化 JSON（读进来再导出一遍），判脏用：手改过格式的文件不会一打开就算改过
var _baseline: Dictionary = {}
var _ctx: ContentImporter.Context = null
## 往表单里回填时为真：这时候的 changed 信号不算编辑
var _syncing: bool = false

var _list: ItemList
var _status: RichTextLabel
## JSON 预览（能直接改了套用）
var _json: TextEdit
## 145：铺满编辑器的弹窗层（规则浮窗挂在这里）。平时不挡鼠标，浮窗开着时接住「点外面」
var _popup_layer: Control = null

const PropertyFormScript := preload("res://ui/editor/property_form.gd")


#region 子类实现
## 对象 → 作者数据（JSON 那份字典）
func _export(_d) -> Dictionary:
	return {}


## 作者数据 → 对象（走导入器）
func _import(_data: Dictionary, _report: ImportReport) -> Resource:
	return null


## 新建的那一件
func _new_def() -> Resource:
	return null


## 对象接上界面之后：回填字段、重建表单
func _on_bound() -> void:
	pass


## 刷新之前：把界面上不走信号的东西（道具的形状画板）收回对象里
func _collect() -> void:
	pass


## 刷新的其余部分（摘要、预览、DPS……）
func _on_refreshed() -> void:
	pass


## 状态栏提示语
func _t(key: String) -> String:
	return String(TEXTS.get(key, key))


## 存好之后的那一句
func _saved_text(id: String) -> String:
	return "已保存 %s.json，并生成 %s.tres" % [id, id]
#endregion


#region 列表与草稿
## 开场：读列表，打开第一件；一件都没有就新建一件
func _start() -> void:
	_reload_list()
	# 146：从别的编辑器「去库里改」过来的，直接打开那一份
	var focus := PropertyFormScript.library_focus
	PropertyFormScript.library_focus = ""
	if _ids.is_empty():
		_new_entry()
	elif _ids.has(focus):
		_open(focus)
	else:
		_open(_ids[0])


func _reload_list() -> void:
	_ids = ContentPaths.ids_in(ContentPaths.dirs_of(_kind)[0])
	# 草稿里可能有还没存过盘的新条目，它们不在目录里但得看得见
	for key in _drafts:
		if not _ids.has(key):
			_ids.append(key)
	_ids.sort()
	_on_list_reloaded()
	_repaint_list()


## 列表重读之后、重画之前（道具编辑器在这儿读标签）
func _on_list_reloaded() -> void:
	pass


## 有未保存改动的条目前面加一个点
func _repaint_list() -> void:
	_list.clear()
	for id in _ids:
		_list.add_item(("● " if _drafts.has(id) else "") + id)


func _select_in_list(id: String) -> void:
	var i := _ids.find(id)
	if i >= 0 and i < _list.item_count:
		_list.select(i)


func _on_rescan() -> void:
	_stash_current()
	_reload_list()
	_select_in_list(_draft_key())


## 丢掉当前这件的草稿，从盘上重读。**只影响当前这一件**（一键清空所有草稿太容易误点）。盘上没有的（新建没存过）：重读列表、再新建一件
func _on_discard() -> void:
	var key := _draft_key()
	_drafts.erase(key)
	_baseline.erase(key)
	# 先清掉当前状态再重读：否则 _open 认出「点的就是当前这件」直接返回，_stash_current 又把它标成脏的
	_def = null
	_current_id = ""
	if key != "" and FileAccess.file_exists(_file_of(key)):
		_open(key)
		_select_in_list(key)
	else:
		_reload_list()
		_new_entry()


## 当前这件在草稿表里的键：**打开时的那个 id**，不是输入框里的当前值（否则边改 id 边切走，草稿散在一堆半成品名字下）。新建的用当前 id
func _draft_key() -> String:
	if _current_id != "":
		return _current_id
	return String(_def.id) if _def != null else ""


func _dump() -> String:
	return ContentExporter.to_json(_export(_def))


## 当前内容与盘上不一致时收进草稿；一致就撤掉（比的是规范化 JSON，改了又改回去不留假脏标记）
func _stash_current() -> void:
	if _def == null:
		return
	var key := _draft_key()
	if key == "":
		return
	if _baseline.has(key) and _baseline[key] == _dump():
		_drafts.erase(key)
	else:
		_drafts[key] = _def


func _track_draft() -> void:
	var key := _draft_key()
	if key == "":
		return
	var was := _drafts.has(key)
	var dirty := false
	# 新建的还没存盘时草稿键就是它的 id；作者边敲边改 id，旧键下那份是同一个对象，不能留成孤儿 ——
	# 否则每敲一个字列表里就多一条。盘上没有的旧名字也从列表里撤掉
	for k in _drafts.keys():
		if k != key and _drafts[k] == _def:
			_drafts.erase(k)
			if not _baseline.has(k) and not FileAccess.file_exists(_file_of(k)):
				_ids.erase(k)
			dirty = true
	if _baseline.has(key) and _baseline[key] == _dump():
		_drafts.erase(key)
	else:
		_drafts[key] = _def
		if not _ids.has(key):
			_ids.append(key)
			_ids.sort()
			dirty = true
	if dirty or was != _drafts.has(key):
		_repaint_list()


func _open(id: String) -> void:
	if id == _draft_key() and _def != null:
		return     # 点的就是当前这件
	_stash_current()
	# 有草稿就接着改那一份，不从盘上覆盖回去
	if _drafts.has(id):
		_bind(_drafts[id], id)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_file_of(id)))
	if not (parsed is Dictionary):
		_status.text = "[color=#d9534f]%s[/color]" % (_t("unreadable") % id)
		return
	var report := ImportReport.new()
	report.source = id
	var def := _import(parsed, report)
	# 基准必须在 _bind 之前写好：_bind 会刷新一次，没有基准就当作改过了 —— 刚打开就被标成脏。只有【从盘上读】才刷新基准
	_baseline[id] = ContentExporter.to_json(_export(def))
	_bind(def, id)


## 套用一份作者数据（JSON 预览改了套用）。算一次编辑，不刷新基准
func _load_dict(data: Dictionary, id: String) -> void:
	var report := ImportReport.new()
	report.source = id
	_bind(_import(data, report), id)


## 145：四个编辑器的属性表单都从这里拿：规则表是列表 + 浮窗，改动走 [method _refresh]。
## 换了对象（表单重建）时开着的规则浮窗一起关掉 —— 它改的是旧对象里的规则
func _form_for(def, skip_map: Dictionary) -> PropertyForm:
	_close_popups()
	var form: PropertyForm = PropertyFormScript.create(def, _font, skip_map)
	form.popup_layer = _popups()
	form.changed.connect(_refresh)
	return form


func _popups() -> Control:
	if _popup_layer == null:
		_popup_layer = Control.new()
		_popup_layer.name = "Popups"
		_popup_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_popup_layer)
	return _popup_layer


func _close_popups() -> void:
	if _popup_layer == null:
		return
	for c in _popup_layer.get_children():
		if c.has_method("close"):
			c.close()
		else:
			c.queue_free()
	_popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE


## 把一个对象接到界面上
func _bind(def, id: String) -> void:
	_def = def
	_current_id = id
	_on_bound()
	_refresh()
	_repaint_list()


func _new_entry() -> void:
	_stash_current()
	_bind(_new_def(), "")


func _file_of(id: String) -> String:
	return ContentPaths.authoring_file(_kind, id)
#endregion


#region 刷新、保存与校验
func _refresh() -> void:
	if _def == null:
		return
	_collect()
	_track_draft()
	_json.text = _dump()
	_status.text = _status_text(_validate())
	_on_refreshed()


## 校验走的就是导入器本身（不另写一份规则，界面和命令行才不会给出不同的答案）
func _validate() -> ImportReport:
	var report := ImportReport.new()
	report.source = String(_def.id)
	_import(_export(_def), report)
	return report


## 状态栏的文字（[method ImportReport.bbcode]），「没有问题」那句按编辑器来。测试直接调
func _status_text(report: ImportReport) -> String:
	return report.bbcode(_t("ok"))


func _save() -> void:
	if _def == null:
		return
	var id := String(_def.id).strip_edges()
	if id == "":
		_status.text = "[color=#d9534f]%s[/color]" % _t("err_id")
		return
	# 校验顺带把资产也建出来：导出成 JSON 再导入回来，和命令行导入器完全一致
	var data := _export(_def)
	var report := ImportReport.new()
	report.source = id
	var built := _import(data, report)
	if not report.ok():
		# 有错就不写盘：半套内容比没内容更难查
		_status.text = "[color=#d9534f]%s[/color]\n" % _t("err_save") + _status_text(report)
		return
	var dirs := ContentPaths.dirs_of(_kind)
	DirAccess.make_dir_recursive_absolute(dirs[0])
	if ContentExporter.save(data, _file_of(id)) != OK:
		_status.text = "[color=#d9534f]%s[/color]" % _t("err_write")
		return
	# 顺手产出引擎资产，省掉「改完还要记得跑一次导入」（忘了跑的表现是改了没生效）
	DirAccess.make_dir_recursive_absolute(dirs[1])
	if ResourceSaver.save(built, ContentPaths.asset_file(_kind, id)) != OK:
		_status.text = "[color=#f0ad4e]%s[/color]" % _t("warn_asset")
		return
	# 146：库（buff / 规则构件）变了，下拉和导出器下次重读
	ContentLibrary.reset()
	# 存下去了，草稿没意义了；基准换成刚写出去的那份
	_drafts.erase(_draft_key())
	_drafts.erase(id)
	_baseline[id] = ContentExporter.to_json(data)
	_current_id = id
	_reload_list()
	_select_in_list(id)
	_refresh()
	_status.text = "[color=#5cb85c]%s[/color]\n" % _saved_text(id) + _status_text(report)


## 改了 id 再保存就是另一个文件；旧的留着，删不删由作者决定
func _save_as() -> void:
	_current_id = ""
	_save()


## 让作者直接改 JSON：界面覆盖不到的角落不该把人挡在外面
func _apply_json() -> void:
	var parsed = JSON.parse_string(_json.text)
	if not (parsed is Dictionary):
		_status.text = "[color=#d9534f]%s[/color]" % _t("err_json")
		return
	_load_dict(parsed, _current_id)


## [DevNav] 会问这一句再决定要不要拦一下返回（草稿只在内存里，切走场景就没了）
func has_unsaved_changes() -> bool:
	_stash_current()
	return not _drafts.is_empty()
#endregion
