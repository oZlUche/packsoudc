## 信仰机制的战斗记录（`faith_mechanic` 的 key → `log.<key>`）：战斗代码里发的每一个 key 都有字，占位数对得上
## （v8.51 测试报告：自然之神四个 key 没有字，记录里直接露出 log.xxx）
extends RefCounted

## 拼出来的 key（代码里不是字面量）
const BUILT: Array[String] = ["nature_heal", "nature_wither", "hunt_stage1", "hunt_stage2", "earth_ram", "earth_heavy", "earth_jade"]


static func _scan(dir: String, out: Dictionary) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if not f.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string(dir.path_join(f))
		for line in text.split("\n"):
			if not line.contains("SkillMomentum.MECHANIC"):
				continue
			var re := RegEx.create_from_string("\"key\": \"([a-z_0-9]+)\"")
			var m := re.search(line)
			if m != null:
				out[m.get_string(1)] = line.contains("\"count\"")
	for sub in d.get_directories():
		_scan(dir.path_join(sub), out)


static func run_keys(t: TestCase) -> void:
	t.begin("信仰机制的战斗记录：每个 key 都有中英文字，带数的写了 %d")
	var keys := {}
	_scan("res://core/battle", keys)
	for k in BUILT:
		keys[k] = false
	t.check(keys.size() >= 15, "扫到 %d 个 key" % keys.size())
	for k in keys:
		var id := "log." + String(k)
		var row: Dictionary = UiText.TEXT.get(id, {})
		t.check(String(row.get("zh", "")) != "" and String(row.get("en", "")) != "", "%s 有中英文" % id)
		for lang in ["zh", "en"]:
			var body := String(row.get(lang, ""))
			t.check(body.count("%s") >= 1, "%s（%s）写了 %%s：是谁" % [id, lang])
			if body.contains("%d"):
				t.check(bool(keys[k]), "%s（%s）写了数，发的时候带 count" % [id, lang])
