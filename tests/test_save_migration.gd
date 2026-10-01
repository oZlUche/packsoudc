## 存档版本迁移链与内容 id 改名表（098，架构文档 7.2）：
##
## - 每一版留一份**冻结的 JSON 样本**（`tests/fixtures/meta_v<n>.json`），断言升到当前版本后读得回来、关键字段没走形；
##   升版时必须加新样本，否则链上有洞这里立刻红；
## - 升不上去的版本（未来版本、缺这一级）不猜：`from_text` 返回 null，调用方**备份后从零开始**，绝不静默覆盖；
## - 改名表（[IdAliases]）：新 id 必须存在、旧 id 不许再被内容引用；老存档里的旧 id 查得回定义，旧信仰的信力并进新池子。
extends RefCounted

const FIXTURES := "res://tests/fixtures"
const SLOT_ROOT := "user://test_098_slots"


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _fixture(v: int) -> String:
	return "%s/meta_v%d.json" % [FIXTURES, v]


static func run_meta_chain(t: TestCase) -> void:
	t.begin("098 · 局外存档迁移链：每一版有冻结样本，升到当前版本后读得回来、字段没走形")
	# 链上每一级都得有一步迁移和一份样本 —— 这两条守着「升版忘了写迁移」
	for v in range(1, MetaState.SAVE_VERSION):
		t.check(MetaMigrations.STEPS.has(v), "有 v%d → v%d 的迁移" % [v, v + 1])
		t.check(FileAccess.file_exists(_fixture(v)), "有 v%d 的冻结样本 %s" % [v, _fixture(v)])

	var text := FileAccess.get_file_as_string(_fixture(1))
	t.check(text != "", "读到 v1 样本")
	var raw: Variant = JSON.parse_string(text)
	t.check(raw is Dictionary and int((raw as Dictionary)["version"]) == 1, "样本确实是 v1")
	var d := MetaMigrations.upgrade(raw as Dictionary)
	t.eq(int(d["version"]), MetaState.SAVE_VERSION, "升到了当前版本")
	t.eq(int((raw as Dictionary)["version"]), 1, "upgrade 不改入参（深拷一份）")

	var db := _db()
	var meta := MetaSave.from_text(text, db)
	t.not_null(meta, "v1 的档经迁移链读得回来")
	if meta == null:
		return
	t.eq(meta.funds, 120, "钱")
	t.eq(meta.score, 340, "累计价值")
	t.eq(meta.runs, 3, "局数")
	t.eq(meta.extractions, 2, "撤离次数")
	t.eq(meta.deaths, 1, "战败次数")
	t.eq(meta.battles_won, 5, "打赢的场数")
	t.eq(int(meta.codex.get("knife", 0)), 2, "图鉴计数")
	t.check(meta.has_unlock(&"tutorial_01"), "解锁还在")
	t.eq(meta.warehouse.item_count(), 1, "仓库里那一件还在")
	var first := meta.warehouse.items()[0] as ItemInstance
	t.eq(first.def.id, &"knife", "还是同一件（按 id 读回定义）")


static func run_unknown_versions(t: TestCase) -> void:
	t.begin("098 · 升不上去就不猜：未来版本、缺这一级的旧版本都返回 null（调用方备份后从零开始）")
	var db := _db()
	var future := {"version": MetaState.SAVE_VERSION + 7, "funds": 9}
	var up := MetaMigrations.upgrade(future)
	t.eq(int(up["version"]), MetaState.SAVE_VERSION + 7, "未来版本原样返回（不往下降）")
	t.is_null(MetaSave.from_text(JSON.stringify(future), db), "未来版本的档：读不回来")
	var ancient := {"version": 0, "funds": 9}
	t.eq(int(MetaMigrations.upgrade(ancient)["version"]), 0, "缺 v0 → v1 的迁移：停在 v0")
	t.is_null(MetaSave.from_text(JSON.stringify(ancient), db), "缺这一级的档：读不回来")
	t.is_null(MetaSave.from_text("不是 JSON", db), "坏文件：读不回来")
	# 当前版本原样过链
	var now := MetaState.new().to_dict()
	t.eq(int(MetaMigrations.upgrade(now)["version"]), MetaState.SAVE_VERSION, "当前版本过链不变")
	t.not_null(MetaSave.from_text(JSON.stringify(now), db), "当前版本照旧读得回来")


static func run_run_chain(t: TestCase) -> void:
	t.begin("098 · 一局档走同一条链，允许作废：升不上去返回 null，局外不受影响")
	for v in range(1, RunState.SAVE_VERSION):
		t.check(RunMigrations.STEPS.has(v), "有 v%d → v%d 的迁移" % [v, v + 1])
	var db := _db()
	var enemies := EnemyDatabase.new()
	enemies.load_all()
	var old := {"version": 0, "chapter": "chapter_01"}
	t.eq(int(RunMigrations.upgrade(old)["version"]), 0, "缺这一级：停在原版本")
	t.is_null(RunSave.from_text(JSON.stringify(old), db, enemies), "读不回来（这一局作废）")
	var future := {"version": RunState.SAVE_VERSION + 3, "chapter": "chapter_01"}
	t.is_null(RunSave.from_text(JSON.stringify(future), db, enemies), "未来版本也不猜")
	# 101：v1 → v2 把子系统的顶层键搬进 modules[id]（迁移链的第一个真实用例）
	var v1 := {"version": 1, "chapter": "chapter_01",
		"safe": {"id": 3, "size": [3, 3], "requires_bag": false, "accept_tags": [], "blocked": [], "items": [], "place_seq": 0},
		"safe_locked": true}
	var up := RunMigrations.upgrade(v1)
	t.eq(int(up["version"]), RunState.SAVE_VERSION, "升到了当前版本")
	t.check(not up.has("safe") and not up.has("safe_locked"), "旧的顶层键删掉了（不留两处）")
	var safe_mod: Dictionary = (up["modules"] as Dictionary)["safe"]
	t.check(safe_mod.has("inventory") and bool(safe_mod["locked"]), "保险箱的容器与锁搬进了 modules.safe")
	# 同一步还搬了按点暂存（每搬一个子系统这一步多几行）
	var v1b := {"version": 1, "chapter": "chapter_01", "node_storages": {"7": []}}
	var up_b := RunMigrations.upgrade(v1b)
	t.check(not up_b.has("node_storages"), "顶层 node_storages 删掉了")
	t.check(((up_b["modules"] as Dictionary)["node_storage"] as Dictionary).has("nodes"), "按点暂存搬进了 modules.node_storage")
	t.eq(int(v1["version"]), 1, "不改入参")


static func run_backup_instead_of_overwrite(t: TestCase) -> void:
	t.begin("098（作者定）· 读不出来先备份再从零开始：老文件改名成 .bak 留着，界面上写一句，不会被下一次存盘盖掉")
	var db := _db()
	var slots := SaveSlots.new(SLOT_ROOT)
	for n in range(1, SaveSlots.COUNT + 1):
		slots.remove(n)
	slots.ensure_dir(1)
	# 一份读不出来的局外存档（版本太老、链上没这一级）
	var f := FileAccess.open(slots.meta_path(1), FileAccess.WRITE)
	t.not_null(f, "写得出测试用的老存档")
	if f == null:
		return
	f.store_string(JSON.stringify({"version": 0, "funds": 777, "runs": 42}))
	f.close()

	var flow := GameFlow.new(db, EnemyDatabase.new(), SetDatabase.new())
	flow.slots = slots
	flow.use_slot(1)
	t.check(flow.meta_backup != "", "切到这一位时备份了：%s" % flow.meta_backup)
	t.check(FileAccess.file_exists(flow.meta_backup), "备份文件在硬盘上")
	t.check(not FileAccess.file_exists(slots.meta_path(1)), "原文件已改名（下一次存盘不会盖掉它）")
	t.eq(flow.meta.runs, 0, "局外从零开始")
	t.check(flow.backup_notice() != "", "界面上有一句：%s" % flow.backup_notice())
	t.check(flow.save_meta(), "存一份新的局外存档")
	t.check(FileAccess.file_exists(slots.meta_path(1)), "新文件落地")
	t.check(FileAccess.file_exists(flow.meta_backup), "备份还在（没被盖）")
	t.check(slots.exists(1), "这一位现在有存档")
	# .bak 不算存档：把新文件删掉，这一位就是空的
	DirAccess.remove_absolute(ProjectSettings.globalize_path(slots.meta_path(1)))
	t.check(not slots.exists(1), "只剩 .bak 的位算空位（exists / remove 都不看 .bak）")
	t.eq(slots.backup(1, "meta"), "", "没有文件可备份时返回空")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(flow.meta_backup))


static func run_id_aliases(t: TestCase) -> void:
	t.begin("098 · 改名表：新 id 必须存在、旧 id 不许再被内容引用；老 id 查得回定义，旧信仰的信力并进新池子")
	var db := _db()
	var faiths := FaithDef.load_all()
	for old in IdAliases.FAITHS:
		var new_id: StringName = IdAliases.FAITHS[old]
		t.check(faiths.has(new_id), "信仰改名 %s → %s：新的装得回来" % [old, new_id])
		t.check(not faiths.has(old), "旧信仰 %s 已经不在了（是改名，不是两个神）" % old)
		t.eq(IdAliases.faith(old), new_id, "faith() 查得到")
		t.check(IdAliases.renamed(IdAliases.FAITHS, old), "renamed() 认得出老名字")
	for old in IdAliases.TAGS:
		var new_tag: StringName = IdAliases.TAGS[old]
		t.eq(IdAliases.tag(old), new_tag, "标签改名 %s → %s" % [old, new_tag])
		var fid := FaithDef.id_of_tag(new_tag)
		t.check(fid == &"" or faiths.has(fid), "%s 指向登记过的信仰" % new_tag)
	for old in IdAliases.ITEMS:
		var new_item: StringName = IdAliases.ITEMS[old]
		t.not_null(db.get_def(new_item), "道具改名 %s → %s：新的在库里" % [old, new_item])
	t.eq(IdAliases.item(&"knife"), &"knife", "没改过名的原样返回")
	t.not_null(db.get_def(&"knife"), "照常查得到")
	t.is_null(db.get_def(&"根本没有这件东西"), "不存在的还是 null")

	# 旧 id 不许再被作者数据引用
	var stale := _grep_authoring(["\"violence\"", "\"sunfire\"", "\"faith:violence\"", "\"faith:sunfire\""])
	t.check(stale.is_empty(), "作者数据里没有旧 id 了%s" % ("" if stale.is_empty() else "：%s" % ", ".join(stale)))

	# 标签：登记一份新名字的标签，用旧名字也查得到
	var def := TagDef.new()
	def.id = &"faith:brute"
	def.display_name = "信仰：蛮神"
	TagRegistry.register(def)
	t.check(TagRegistry.get_def(&"faith:violence") == def, "老存档 / 老内容里的 faith:violence 查得回新标签")
	t.check(TagRegistry.has(&"faith:violence"), "has() 也认")
	TagRegistry.reset()

	# 信力：旧池子并进新池子（两边都有就加起来）
	var power := FaithPower.new()
	power.restore({"violence": 10, "brute": 5, "sun": 3})
	t.eq(power.points_of(&"brute"), 15, "violence 的 10 点并进 brute 的 5 点")
	t.eq(power.points_of(&"sun"), 3, "没改过名的照旧")
	t.eq(power.points_of(&"violence"), 0, "旧 id 下面不再留点数")


## 作者数据里有没有这些字面量；返回命中的「文件：字面量」
static func _grep_authoring(needles: Array) -> Array[String]:
	var hits: Array[String] = []
	for path in _json_files(ContentPaths.AUTHORING):
		var text := FileAccess.get_file_as_string(path)
		for n in needles:
			if text.find(String(n)) >= 0:
				hits.append("%s：%s" % [path.get_file(), n])
	return hits


## 一个目录下（含子目录）的全部 .json
static func _json_files(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".json"):
			out.append(root.path_join(f))
	for sub in dir.get_directories():
		out.append_array(_json_files(root.path_join(sub)))
	return out
