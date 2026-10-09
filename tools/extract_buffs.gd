## 146：一次性迁移 —— 把作者数据里内联的 buff 抽成独立文件、把重复出现的规则构件抽进构件库。
##
##     godot --headless --path . --script res://tools/extract_buffs.gd [-- buffs|parts]
##
## 第一步（buffs）：扫全部作者 JSON 里 `"buff": {…}` 的内联 buff，同 id 的内容完全一样 → 写 `buffs/<id>.json`，
## 原处改成 `"buff": "<id>"`；同 id 内容不一样的不动，列出来让作者定。
## 第二步（parts）：扫全部规则（不含 buff 自己的规则）里的扳机 / 节奏 / 消耗 / 效果，**完全相同且出现 ≥ 3 次**的
## 抽成 `rule_parts/<id>.json`（id 按类型 + 关键参数生成，名字用预览句，作者可改），原处改成 `"@<id>"`。
##
## 写出来的 JSON 不是导出器格式：跑完接着 import_content → normalize_content → import_content。
extends CliTool

const MIN_REPEAT := 3
## 规则里的四个槽 → 构件的字段名
const SLOT_FIELD := {"trigger": "trigger", "cadence": "cadence", "costs": "cost", "effects": "effect"}

## 路径 → 改过的作者数据（最后一起写）
var _files: Dictionary = {}


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var do_buffs := args.is_empty() or args.has("buffs")
	var do_parts := args.is_empty() or args.has("parts")
	_load_files()
	if do_buffs:
		_extract_buffs()
	if do_parts:
		_extract_parts()
	for kind in ["buffs", "rule_parts"]:
		DirAccess.make_dir_recursive_absolute(ContentPaths.dirs_of(kind)[0])
	var n := write_json_if_changed(_files)
	if n < 0:
		return
	print("写了 %d 份。接着跑 import_content → normalize_content → import_content" % n)
	finish(0)


func _load_files() -> void:
	for kind in ContentPaths.ORDER:
		if kind == "buffs" or kind == "rule_parts":
			continue
		var dir: String = ContentPaths.KINDS[kind][0]
		for id in ContentPaths.ids_in(dir):
			var path := "%s/%s.json" % [dir, id]
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				_files[path] = parsed


#region 第一步：buff
func _extract_buffs() -> void:
	var found := {}     # id → [[容器, 键], …]
	for path in _files:
		_find_buffs(_files[path], found)
	var ids: Array = found.keys()
	ids.sort()
	for bid in ids:
		var spots: Array = found[bid]
		var first: Dictionary = spots[0][0][spots[0][1]]
		var same := true
		for s in spots:
			same = same and _canon(s[0][s[1]]) == _canon(first)
		var out_path := ContentPaths.authoring_file("buffs", String(bid))
		if FileAccess.file_exists(out_path):
			var existing = JSON.parse_string(FileAccess.get_file_as_string(out_path))
			same = same and existing is Dictionary and _canon(existing) == _canon(first)
		if not same:
			print("buff %s：各处内容不一样，没动（%d 处）" % [bid, spots.size()])
			continue
		_files[out_path] = first.duplicate(true)
		for s in spots:
			s[0][s[1]] = String(bid)
		print("buff %s：%d 处改成引用" % [bid, spots.size()])


## 只找最外层的内联 buff（buff 里面再套的 buff 跟着外层一起走）
func _find_buffs(node: Variant, found: Dictionary) -> void:
	if node is Dictionary:
		for k in node:
			var v = node[k]
			if _is_buff_slot(node, k) and v is Dictionary and String(v.get("id", "")) != "":
				var bid := String(v["id"])
				if not found.has(bid):
					found[bid] = []
				found[bid].append([node, k])
				continue
			_find_buffs(v, found)
	elif node is Array:
		for x in node:
			_find_buffs(x, found)
#endregion


#region 第二步：规则构件
func _extract_parts() -> void:
	var seen := {}     # 槽|规范 JSON → [[容器, 键或下标], …]
	var buff_dir: String = ContentPaths.dirs_of("buffs")[0]
	for path in _files:
		if not String(path).begins_with(buff_dir):
			_find_parts(_files[path], seen)
	var ctx := _buff_context()
	var used_ids := {}
	for id in ContentPaths.ids_in(ContentPaths.dirs_of("rule_parts")[0]):
		used_ids[id] = true
	var keys: Array = seen.keys()
	keys.sort()
	for key in keys:
		var spots: Array = seen[key]
		if spots.size() < MIN_REPEAT:
			continue
		var slot := String(key).get_slice("|", 0)
		var data: Dictionary = spots[0][0][spots[0][1]]
		var id := _part_id(data, used_ids)
		used_ids[id] = true
		var part := {"id": id, SLOT_FIELD[slot]: data.duplicate(true)}
		var def := ContentImporter.import_rule_part(part, ctx, ImportReport.new())
		var name := def.preview() if def != null else ""
		part["display_name"] = name if name != "" else id
		_files[ContentPaths.authoring_file("rule_parts", id)] = part
		for s in spots:
			s[0][s[1]] = "@" + id
		print("构件 %s（%s）：%d 处" % [id, part["display_name"], spots.size()])


func _find_parts(node: Variant, seen: Dictionary) -> void:
	if node is Dictionary:
		for k in node:
			var v = node[k]
			if _is_buff_slot(node, k):
				continue     # buff 自己的规则不用构件
			if String(k).ends_with("rules") and v is Array:
				for r in v:
					if r is Dictionary and (r.has("trigger") or r.has("effects")):
						_rule_parts(r, seen)
			_find_parts(v, seen)
	elif node is Array:
		for x in node:
			_find_parts(x, seen)


func _rule_parts(rule: Dictionary, seen: Dictionary) -> void:
	for slot in ["trigger", "cadence"]:
		if rule.get(slot) is Dictionary:
			_note(seen, slot, rule, slot)
	for slot in ["costs", "effects"]:
		var arr = rule.get(slot)
		if arr is Array:
			for i in arr.size():
				if arr[i] is Dictionary:
					_note(seen, slot, arr, i)


func _note(seen: Dictionary, slot: String, holder: Variant, at: Variant) -> void:
	var key := slot + "|" + _canon(holder[at])
	if not seen.has(key):
		seen[key] = []
	seen[key].append([holder, at])


## 类型 + 关键参数：cooldown_1s、on_status_applied_bleed、resource_5
func _part_id(data: Dictionary, used: Dictionary) -> String:
	var bits: Array[String] = [String(data.get("type", "part"))]
	var keys: Array = data.keys()
	keys.sort()
	for k in keys:
		if k == "type":
			continue
		var v = data[k]
		if v is bool:
			if v:
				bits.append(String(k))
		elif v is float or v is int:
			var f := float(v)
			var s := str(int(f)) if f == floorf(f) else str(f).replace(".", "_")
			bits.append(s + ("s" if k == "seconds" else ""))
		elif v is String:
			bits.append(String(v))
	var id := "_".join(bits).to_lower()
	var out := id
	var n := 2
	while used.has(out):
		out = "%s_%d" % [id, n]
		n += 1
	return out


## 构件里的施加状态按 id 引用 buff：先把这一步抽出来的 buff 登记进上下文，预览句才写得出状态名
func _buff_context() -> ContentImporter.Context:
	var ctx := ContentImporter.Context.new()
	for path in _files:
		if String(path).begins_with(ContentPaths.dirs_of("buffs")[0]):
			ContentImporter.import_buff(_files[path], ctx, ImportReport.new())
	for id in ContentPaths.ids_in(ContentPaths.dirs_of("buffs")[0]):
		var p := ContentPaths.authoring_file("buffs", id)
		if not _files.has(p):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
			if parsed is Dictionary:
				ContentImporter.import_buff(parsed, ctx, ImportReport.new())
	return ctx
#endregion


## 装 buff 的字段：施加状态的 `buff`、转化状态的 `to`
static func _is_buff_slot(holder: Dictionary, key: Variant) -> bool:
	return key == "buff" or (key == "to" and holder.get("type", "") == "convert_status")


## 比内容用：键排序、数字一律按浮点
static func _canon(v: Variant) -> String:
	return JSON.stringify(v, "", true, true)
