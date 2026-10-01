## 读 .xlsx 的值（104：神明总表 `docs/gods.xlsx` 是信仰体系的核心配置，Godot 得能读它才守得住「表 ⇄ JSON」）。
##
## .xlsx 是一个 zip，里面是 XML：`xl/workbook.xml` 列工作表、`xl/_rels/workbook.xml.rels` 给每张表的文件、
## `xl/sharedStrings.xml` 是共享字符串（Excel / WPS 存的都用它；openpyxl 存的是行内字符串，两种都认）。
## **只读值**：公式取缓存的结果、样式与合并单元格不管。数字读成 float（整数值也是），布尔读成 bool，空格子是 null。
class_name XlsxReader
extends RefCounted


## 整本：表名 → 行（Array，每行是按列号排好的 Array，缺的格子补 null）。读不了返回空字典
static func read(path: String) -> Dictionary:
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		return {}
	var files := zip.get_files()
	var shared := _shared_strings(zip, files)
	var targets := _rel_targets(zip)
	var out := {}
	var wb := XMLParser.new()
	if wb.open_buffer(zip.read_file("xl/workbook.xml")) != OK:
		zip.close()
		return {}
	while wb.read() == OK:
		if wb.get_node_type() == XMLParser.NODE_ELEMENT and wb.get_node_name() == "sheet":
			var name := wb.get_named_attribute_value_safe("name")
			var rid := wb.get_named_attribute_value_safe("r:id")
			var file := String(targets.get(rid, ""))
			if file != "" and files.has(file):
				out[name] = _sheet_rows(zip.read_file(file), shared)
	zip.close()
	return out


## rId → zip 里的路径（Target 可能是 `/xl/worksheets/sheet1.xml` 也可能是相对的 `worksheets/sheet1.xml`）
static func _rel_targets(zip: ZIPReader) -> Dictionary:
	var out := {}
	var p := XMLParser.new()
	if p.open_buffer(zip.read_file("xl/_rels/workbook.xml.rels")) != OK:
		return out
	while p.read() == OK:
		if p.get_node_type() == XMLParser.NODE_ELEMENT and p.get_node_name() == "Relationship":
			var target := p.get_named_attribute_value_safe("Target")
			target = target.substr(1) if target.begins_with("/") else "xl/" + target
			out[p.get_named_attribute_value_safe("Id")] = target
	return out


static func _shared_strings(zip: ZIPReader, files: PackedStringArray) -> Array[String]:
	var out: Array[String] = []
	if not files.has("xl/sharedStrings.xml"):
		return out
	var p := XMLParser.new()
	if p.open_buffer(zip.read_file("xl/sharedStrings.xml")) != OK:
		return out
	var cur := ""
	var in_t := false
	while p.read() == OK:
		match p.get_node_type():
			XMLParser.NODE_ELEMENT:
				if p.get_node_name() == "si":
					cur = ""
				elif p.get_node_name() == "t":
					in_t = not p.is_empty()
			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				if in_t:
					cur += p.get_node_data()
			XMLParser.NODE_ELEMENT_END:
				if p.get_node_name() == "t":
					in_t = false
				elif p.get_node_name() == "si":
					out.append(cur)
	return out


static func _sheet_rows(buf: PackedByteArray, shared: Array[String]) -> Array:
	var rows := {}     # 行号（1 起）→ {列号（0 起）: 值}
	var max_row := 0
	var p := XMLParser.new()
	if p.open_buffer(buf) != OK:
		return []
	var col := -1
	var row := 0
	var kind := ""
	var text := ""
	var in_value := false
	while p.read() == OK:
		match p.get_node_type():
			XMLParser.NODE_ELEMENT:
				match p.get_node_name():
					"row":
						row = int(p.get_named_attribute_value_safe("r"))
					"c":
						var ref := p.get_named_attribute_value_safe("r")
						col = _col_of(ref)
						var r := _row_of(ref)
						if r > 0:
							row = r
						kind = p.get_named_attribute_value_safe("t")
						text = ""
						if p.is_empty():
							col = -1
					"v", "t":
						in_value = not p.is_empty()
			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				if in_value:
					text += p.get_node_data()
			XMLParser.NODE_ELEMENT_END:
				match p.get_node_name():
					"v", "t":
						in_value = false
					"c":
						if col >= 0:
							var v: Variant = _value(kind, text, shared)
							if v != null:
								if not rows.has(row):
									rows[row] = {}
								rows[row][col] = v
								max_row = maxi(max_row, row)
						col = -1
	var out: Array = []
	for r in range(1, max_row + 1):
		var cells: Dictionary = rows.get(r, {})
		var width := 0
		for c in cells:
			width = maxi(width, int(c) + 1)
		var line: Array = []
		line.resize(width)
		for c in cells:
			line[int(c)] = cells[c]
		out.append(line)
	return out


static func _value(kind: String, text: String, shared: Array[String]) -> Variant:
	match kind:
		"s":
			var i := int(text)
			return shared[i] if i >= 0 and i < shared.size() else null
		"inlineStr", "str":
			return text
		"b":
			return text == "1"
		"e":
			return null
		_:
			if text == "":
				return null
			return float(text)


## `AB12` → 27（列号 0 起）
static func _col_of(ref: String) -> int:
	var n := 0
	for ch in ref:
		var code := ch.unicode_at(0)
		if code < 65 or code > 90:
			break
		n = n * 26 + (code - 64)
	return n - 1


static func _row_of(ref: String) -> int:
	var digits := ""
	for ch in ref:
		if ch >= "0" and ch <= "9":
			digits += ch
	return int(digits) if digits != "" else 0
