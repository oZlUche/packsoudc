## 173 §3.3：内容快照 —— 「改了内容忘了交代存档」在这里变红。
##
## 冻结的 `tests/fixtures/content_snapshot.json` 对现在的内容：删掉的道具要进改名表或退役表、改了形状的要登记，
## 标签 / 信仰 / 章节 / 敌人消失的要有改名或退役记录。补完表后 `bash tools/snapshot_content.sh` 重生成快照
extends RefCounted


static func run_current_content(t: TestCase) -> void:
	t.begin("173 · 内容快照：现在的内容对冻结快照，每一处删改都在 IdAliases 里交代过（没交代的列在下面；补表后跑 tools/snapshot_content.sh）")
	var frozen := ContentSnapshot.load_frozen()
	t.check(not frozen.is_empty() and (frozen.get("items", {}) as Dictionary).size() > 0, "有冻结的快照")
	var issues := ContentSnapshot.problems(frozen, ContentSnapshot.capture())
	t.eq(issues, [] as Array[String], "没有没交代的改动")
	# 退役表、改名表自己的规矩：退役的 id 不许还在库里（否则是两个东西撞名）
	var db := ItemDatabase.new()
	db.load_dir()
	for id in IdAliases.RETIRED_ITEMS:
		t.check(not db.has_exact(id), "退役的 %s 不在库里" % id)
		var rule: Dictionary = IdAliases.RETIRED_ITEMS[id]
		var to := String(rule.get("replace", ""))
		t.check(rule.has("refund") or rule.has("drop") or db.has_exact(StringName(to)), "%s 的处置写对了（换件的新 id 在库里）" % id)
	for id in IdAliases.RESHAPED:
		t.check(db.has_exact(id), "登记改过形状的 %s 在库里" % id)


static func run_rules(t: TestCase) -> void:
	t.begin("173 · 快照的规矩本身：删了道具不交代 → 红，进退役表 → 绿；改了形状不登记 → 红，登记 → 绿；敌人没了不交代 → 红，进退役 → 绿；新增不管")
	var knife := {"cells": 2, "size": [1, 2], "shape": [[0, 0], [0, 1]], "bag": false}
	var old := {"items": {"knife": knife, "old_gun": knife}, "enemies": ["raider", "ghost"], "tags": [], "faiths": [], "chapters": []}
	var now := {"items": {"knife": knife, "new_thing": knife}, "enemies": ["raider"], "tags": [], "faiths": [], "chapters": []}
	var none := {}
	var issues := ContentSnapshot.problems(old, now, none, none, none, {"enemies": []}, {})
	t.eq(issues.size(), 2, "道具删了、敌人没了，两条都红：%s" % str(issues))
	t.eq(ContentSnapshot.problems(old, now, none, {&"old_gun": {"refund": true, "value": 1}}, none, {"enemies": ["ghost"]}, {}).size(), 0,
		"进了退役表 → 绿（新增的 new_thing 不管）")
	t.eq(ContentSnapshot.problems(old, now, {&"old_gun": &"knife"}, none, none, {"enemies": ["ghost"]}, {}).size(), 0, "改名也算交代")
	var reshaped := {"items": {"knife": {"cells": 3, "size": [2, 2], "shape": [[0, 0], [0, 1], [1, 0]], "bag": false}}}
	var old2 := {"items": {"knife": knife}}
	t.eq(ContentSnapshot.problems(old2, reshaped, none, none, none, {}, {}).size(), 1, "改了形状不登记 → 红")
	t.eq(ContentSnapshot.problems(old2, reshaped, none, none, {&"knife": "测试"}, {}, {}).size(), 0, "登记了 → 绿")
	var as_json: Dictionary = JSON.parse_string(JSON.stringify(old2))
	t.eq(ContentSnapshot.problems(as_json, old2, none, none, none, {}, {}).size(), 0, "JSON 读回来的浮点数和整数不算改了形状")
