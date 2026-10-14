## 173（作者问「存档经常会在版本升级后失效……如何保证迁移成功率」，方案待定全按推荐）：
##
## - 原子写：`.tmp` → 改名，上一份留成 `.prev`；主文件坏了读 `.prev`，报告 `prev_used`；
## - 内容对账（[SaveReconcile]）：退役道具折钱 / 换件 / 丢掉，查不到的默认折钱且有记录，改过名的写成新名，`state` 键改名；
## - 原位放不回的：仓库换位 / 加页、带回的背包先背包后仓库、一局的棋盘 / 保险箱先本容器后地上，都记报告；
## - 一局档作废前打捞棋盘 / 地上 / 保险箱进仓库，钱包不动；修复报告写进存档位、界面读一次就删；
## - 一局档的冻结样本 `run_v4.json`；`tests/fixtures/saves/` 里每份存档读得回来、`dropped` 为空、折钱的和 `expected.json` 对得上
extends RefCounted

const FlowSupport := preload("res://tests/run/flow_support.gd")
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")
const FIXTURES := "res://tests/fixtures"
const SAVES := "res://tests/fixtures/saves"
const SLOT_ROOT := "user://test_173_slots"


static func _db() -> ItemDatabase:
	var db := ItemDatabase.new()
	db.load_dir()
	return db


static func _enemies() -> EnemyDatabase:
	var e := EnemyDatabase.new()
	e.load_all()
	return e


static func _raw_write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


static func _item(uid: int, def: String, origin: Array) -> Dictionary:
	return {"uid": uid, "def": def, "rot": 0, "origin": origin, "seq": uid, "state": {}}


static func _run_v4() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "/run_v4.json")) as Dictionary


static func run_atomic_write(t: TestCase) -> void:
	t.begin("173 · 原子写：先写 .tmp 再改名，上一份留成 .prev；残留的 .tmp 不影响读；删档连 .prev / .tmp 一起删")
	var path := "user://test_173_atomic.json"
	AtomicFile.remove(path)
	t.eq(AtomicFile.write(path, "A"), OK, "写第一份")
	t.check(not FileAccess.file_exists(AtomicFile.prev_path(path)), "第一次写没有上一份")
	t.eq(AtomicFile.write(path, "B"), OK, "写第二份")
	t.eq(FileAccess.get_file_as_string(path), "B", "主文件是新的")
	t.eq(FileAccess.get_file_as_string(AtomicFile.prev_path(path)), "A", "上一份留着")
	t.check(not FileAccess.file_exists(AtomicFile.tmp_path(path)), "不留 .tmp")
	_raw_write(AtomicFile.tmp_path(path), "{半截")     # 写完 .tmp 没来得及改名就断电
	t.eq(AtomicFile.read_text(path), "B", "残留 .tmp：读的还是完整的那份")
	AtomicFile.remove(path)
	t.check(not AtomicFile.exists(path) and not FileAccess.file_exists(AtomicFile.tmp_path(path)), "删档连上一份和 .tmp 一起删")


static func run_prev_fallback(t: TestCase) -> void:
	t.begin("173 · 主文件坏了读上一份：局外、一局、设置都一样；报告记 prev_used；只剩 .prev（两次改名之间断电）也读得回来")
	var db := _db()
	var mp := "user://test_173_meta.json"
	MetaSave.remove(mp)
	var m := MetaState.new()
	m.funds = 11
	MetaSave.write(m, mp)
	m.funds = 22
	MetaSave.write(m, mp)
	_raw_write(mp, "{\"version\": 3, \"warehouse\": ")
	var r := SaveReport.new()
	var back := MetaSave.read(db, mp, null, [], r)
	t.not_null(back, "局外：主文件坏了，读回了上一份")
	if back != null:
		t.eq(back.funds, 11, "是上一份的内容")
	t.check(r.prev_used and r.summary().contains("上一份"), "报告写了「已从上一份恢复」：%s" % r.summary())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(mp))
	t.check(MetaSave.exists(mp), "只剩 .prev 也算有档")
	t.not_null(MetaSave.read(db, mp), "只剩 .prev 也读得回来")
	MetaSave.remove(mp)
	t.check(not MetaSave.exists(mp), "删干净了")
	# 一局
	var rp := "user://test_173_run.json"
	RunSave.remove(rp)
	_raw_write(rp, JSON.stringify(_run_v4()))
	AtomicFile.write(rp, "{坏")     # 现在主文件坏、上一份是样本
	var rr := SaveReport.new()
	var run := RunSave.read(db, _enemies(), null, rp, rr)
	t.not_null(run, "一局：主文件坏了，读回了上一份")
	t.check(rr.prev_used, "报告记了")
	RunSave.remove(rp)
	# 设置
	var sp := "user://test_173_settings.json"
	GameSettings.remove(sp)
	var s := GameSettings.new()
	s.battle_speed = 2.0
	s.save_to(sp)
	s.battle_speed = 4.0
	s.save_to(sp)
	_raw_write(sp, "{")
	t.eq(GameSettings.load_from(sp).battle_speed, 2.0, "设置：主文件坏了用上一份")
	GameSettings.remove(sp)


static func run_reconcile_items(t: TestCase) -> void:
	t.begin("173 · 内容对账：退役表三种处置（折钱 / 换件 / 丢掉）、查不到的默认折钱并报告、改过名的写成新名、state 键改名")
	var db := _db()
	var report := SaveReport.new()
	var sniper := _item(1, "sniper", [0, 0])
	t.eq(SaveReconcile.item(sniper, db, report, "warehouse"), 300, "退役表里的狙击枪：折 300")
	t.eq(String(sniper["def"]), "", "清空 def（原地留壳，落点数组不错位）")
	t.is_null(ItemInstance.from_dict(sniper, db), "清空的读回来是 null（不告警）")
	var swap := _item(2, "old_blade", [0, 0])
	SaveReconcile.item(swap, db, report, "board", {&"old_blade": {"replace": "knife"}})
	t.eq(String(swap["def"]), "knife", "退役表写了换件：换成小刀")
	var gone := _item(3, "old_trash", [0, 0])
	t.eq(SaveReconcile.item(gone, db, report, "board", {&"old_trash": {"drop": true}}), 0, "退役表写了丢掉：不折钱")
	t.eq(String(gone["def"]), "", "丢掉的也清空")
	var unknown := _item(4, "never_registered", [0, 0])
	t.eq(SaveReconcile.item(unknown, db, report, "storage"), 0, "哪都查不到：按 0 折")
	var renamed := _item(5, "strength_sigil", [0, 0])
	SaveReconcile.item(renamed, db, report, "warehouse")
	t.eq(String(renamed["def"]), "charm_brute", "改过名的写成新名")
	var ids: Array = report.refunded.map(func(row): return String(row["id"]))
	t.eq(ids, ["sniper", "never_registered"], "折钱的两件都有记录（查不到的也记）")
	t.eq(report.refund_total(), 300, "合计")
	t.eq(report.replaced.size(), 1, "换件有记录")
	t.eq(report.dropped.size(), 1, "丢掉有记录")
	var keyed := _item(6, "knife", [0, 0])
	keyed["state"] = {"armor_left": 3, "other": 1}
	SaveReconcile.item(keyed, db, null, "", IdAliases.RETIRED_ITEMS, {"armor_left": "block_left"})
	t.eq(keyed["state"], {"block_left": 3, "other": 1}, "state 键改名，未知键原样留着")
	t.check(report.summary().contains("折算为 300 钱"), "报告那一句：%s" % report.summary())


static func run_meta_rehome(t: TestCase) -> void:
	t.begin("173 · 局外：仓库里原位放不回的换位、带回的背包先背包后仓库；退役的折进 funds；全都记进报告")
	var db := _db()
	var m := MetaState.new()
	m.funds = 5
	m.grant([db.get_def(&"knife")])
	var d := m.to_dict()
	var page: Dictionary = (d["warehouse"]["pages"] as Array)[0]
	(page["items"] as Array).append(_item(40, "longsword", [0, 0]))     # 压在小刀上
	(page["items"] as Array).append(_item(41, "sniper", [5, 0]))
	d["board"] = {"id": MetaState.BOARD_ID, "size": [4, 4], "requires_bag": false, "blocked": [],
		"items": [_item(42, "round_shield", [0, 0]), _item(43, "knife", [0, 0])], "place_seq": 0}
	var r := SaveReport.new()
	var back := MetaSave.from_text(JSON.stringify(d), db, null, [], r)
	t.not_null(back, "读得回来")
	if back == null:
		return
	t.eq(back.funds, 305, "退役的狙击枪折进 funds（5 + 300）")
	t.eq(back.warehouse.item_count(), 2, "长剑没丢：仓库里换了位置")
	t.eq(back.board.item_count(), 2, "带回的背包：小刀在背包里换了个空位")
	var moves: Array = r.rehomed.map(func(row): return "%s:%s→%s" % [row["id"], row["from"], row["to"]])
	t.check(moves.has("longsword:warehouse→warehouse.page1") and moves.has("knife:board→board"), "挪位都有记录：%s" % str(moves))
	t.check(r.dropped.is_empty(), "没有丢的")


static func run_run_rehome(t: TestCase) -> void:
	t.begin("173 · 一局：棋盘原位放不回先盘里找空位、再落到地上；保险箱同理；地上的落点不因删了一件而错位；退役的折进钱包")
	var db := _db()
	var d := _run_v4()
	var board_items: Array = d["board"]["items"]
	board_items.append(_item(9100, "longsword", [0, 0]))     # 和包里的小刀抢格子
	var storage: Dictionary = d["storage"]
	var spot_before: Array = (storage["spots"] as Array)[0]
	(storage["items"] as Array).insert(0, _item(9101, "sniper", [0, 0]))
	(storage["spots"] as Array).insert(0, [0.5, 0.5])
	var safe_inv: Dictionary = d["modules"]["safe"]["inventory"]
	safe_inv["items"] = [_item(9102, "knife", [0, 0]), _item(9103, "knife", [0, 0])]
	var r := SaveReport.new()
	var run := RunSave.from_text(JSON.stringify(d), db, _enemies(), null, r)
	t.not_null(run, "读得回来")
	if run == null:
		return
	t.eq(run.wallet.balance, 20 + 300, "退役的狙击枪折进钱包")
	var longsword_home := "board" if run.board.has_item(9100) else ("storage" if run.storage.has_item(9100) else "丢了")
	t.check(longsword_home != "丢了", "长剑没丢（%s）" % longsword_home)
	t.check(run.storage.has_item(9004), "地上原来的绷带还在")
	var spot := run.storage.spot_of(9004)
	t.eq([snappedf(spot.x, 0.001), snappedf(spot.y, 0.001)], [snappedf(float(spot_before[0]), 0.001), snappedf(float(spot_before[1]), 0.001)],
		"绷带的落点没错位（删掉的那件留了空壳）")
	var safe := run.module(&"safe") as SafeModule
	t.check(safe != null and safe.inventory.has_item(9102) and safe.inventory.has_item(9103), "保险箱：抢格子的那把小刀在箱里换了空位")
	var froms: Array = r.rehomed.map(func(row): return String(row["from"]))
	t.check(froms.has("board") and froms.has("modules.safe"), "挪位都有记录：%s" % str(r.rehomed))
	t.check(r.refunded.size() == 1 and String(r.refunded[0]["from"]) == "storage", "折钱有记录")


static func run_salvage(t: TestCase) -> void:
	t.begin("173（待定 2 A）· 一局档作废前打捞：棋盘 / 地上 / 保险箱的道具进仓库（包不带回、钱包不动），文件挪成 .bak，存档位里留一句修复报告，界面读一次就删")
	var c = NodeScreens._content()
	FlowSupport.cleanup("s173")
	var f := FlowSupport.flow(c, "s173")
	var d := _run_v4()
	d["chapter"] = "no_such_chapter"
	var report := SaveReport.new()
	t.is_null(RunSave.from_text(JSON.stringify(d), c.items, c.enemies, null, report), "章节查不到：这一局作废")
	t.eq(report.salvage.size(), 4, "捞出棋盘 3 件 + 地上 1 件")
	_raw_write(f.save_path, JSON.stringify(d))
	var funds := f.meta.funds
	f.continue_run()
	var ids: Array = f.meta.warehouse.items().map(func(i): return String((i as ItemInstance).def.id))
	ids.sort()
	t.eq(ids, ["bandage", "knife", "round_shield"], "进了仓库（皮包是包，不带回）")
	t.eq(f.meta.funds, funds, "钱包随这一局作废，局外的钱不动")
	t.check(not RunSave.exists(f.save_path), "作废的那一局挪成了 .bak，下次「继续」不会再捞一遍")
	t.not_null(MetaSave.read(c.items, f.meta_path), "局外存了盘")
	# 存档位：修复报告写进 last_repair.json，读一次就删
	var slots := SaveSlots.new(SLOT_ROOT)
	slots.remove(1)
	f.slots = slots
	f.use_slot(1)
	_raw_write(f.save_path, JSON.stringify(d))
	f.continue_run()
	t.check(FileAccess.file_exists(slots.repair_path(1)), "存档位里写了修复报告")
	var notice := f.repair_notice()
	t.check(notice.contains("放回仓库"), "那一句：%s" % notice)
	t.check(not FileAccess.file_exists(slots.repair_path(1)), "读过就删了")
	t.eq(f.repair_notice(), notice, "这次进程里还留着（读取存档屏和主菜单都能显示）")
	for p in DirAccess.get_files_at(SLOT_ROOT + "/1"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SLOT_ROOT + "/1/" + p))
	slots.remove(1)
	FlowSupport.cleanup("s173")
	for p in DirAccess.get_files_at("user://"):
		if p.begins_with("test_s173_run.json."):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + p))


static func run_slot_report(t: TestCase) -> void:
	t.begin("173 · 切存档位时局外对账过：修复报告写进这一位；删档把 .prev 和报告一起删；备份时 .prev 跟着备份")
	var db := _db()
	var slots := SaveSlots.new(SLOT_ROOT)
	slots.remove(2)
	slots.ensure_dir(2)
	var m := MetaState.new()
	m.grant([db.get_def(&"knife")])
	var d := m.to_dict()
	((d["warehouse"]["pages"] as Array)[0]["items"] as Array).append(_item(30, "mana_crystal", [5, 5]))
	_raw_write(slots.meta_path(2), JSON.stringify(d))
	var opened := slots.open(2, db)
	t.not_null(opened["meta"], "读得回来")
	var r := SaveReport.read(slots.repair_path(2))
	t.check(r != null and r.refunded.size() == 1 and String(r.refunded[0]["id"]) == "mana_crystal", "报告写进了这一位")
	MetaSave.write(opened["meta"] as MetaState, slots.meta_path(2))
	MetaSave.write(opened["meta"] as MetaState, slots.meta_path(2))
	t.check(FileAccess.file_exists(AtomicFile.prev_path(slots.meta_path(2))), "存过两次：有上一份")
	t.check(slots.exists(2), "这一位有档")
	slots.remove(2)
	t.check(not FileAccess.file_exists(AtomicFile.prev_path(slots.meta_path(2))) and not FileAccess.file_exists(slots.repair_path(2)),
		"删档：上一份和报告一起删")
	# 备份：.prev 跟着走
	slots.ensure_dir(2)
	_raw_write(slots.run_path(2), "{坏")
	_raw_write(AtomicFile.prev_path(slots.run_path(2)), "{也坏")
	var bak := slots.backup(2, "run")
	t.check(bak != "" and FileAccess.file_exists(bak) and FileAccess.file_exists(bak + AtomicFile.PREV), "备份时上一份跟着备份")
	t.check(not RunSave.exists(slots.run_path(2)), "备份完不再算有一局（不会每次「继续」撞同一面墙）")
	for p in DirAccess.get_files_at(SLOT_ROOT + "/2"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SLOT_ROOT + "/2/" + p))


static func run_frozen_run_v4(t: TestCase) -> void:
	t.begin("173 · 一局档的冻结样本 run_v4.json：读得回来、东西都在、不报修；存档头带内容版本戳")
	var db := _db()
	var r := SaveReport.new()
	var run := RunSave.from_text(FileAccess.get_file_as_string(FIXTURES + "/run_v4.json"), db, _enemies(), null, r)
	t.not_null(run, "读得回来")
	if run == null:
		return
	t.eq(run.board.item_count(), 3, "棋盘 3 件")
	t.eq(run.storage.item_count(), 1, "地上 1 件")
	t.eq(run.wallet.balance, 20, "钱包")
	t.check(r.is_empty(), "不报修：%s" % JSON.stringify(r.to_dict()))
	t.check(r.stamp_saved != "", "存档里有内容版本戳")
	var stamp := ContentPaths.content_stamp()
	t.eq(stamp.length(), 12, "内容版本戳 12 位")
	t.check(RunSave.to_text(run).contains("\"content_stamp\": \"%s\"" % stamp), "存的时候写进了现在的版本戳")
	t.eq(RunSave.to_text(RunSave.from_text(RunSave.to_text(run), db, _enemies())), RunSave.to_text(run), "写出再读回、再写出逐字一致")


static func run_real_saves(t: TestCase) -> void:
	t.begin("173（待定 3 A）· 存档回归：tests/fixtures/saves/ 里每份都读得回来、没有丢掉的、折钱的和 expected.json 对得上")
	var db := _db()
	var dirs := DirAccess.get_directories_at(SAVES)
	t.check(dirs.size() >= 1, "至少一份样本")
	for name in dirs:
		var dir := SAVES + "/" + name
		var expected: Dictionary = {}
		if FileAccess.file_exists(dir + "/expected.json"):
			expected = JSON.parse_string(FileAccess.get_file_as_string(dir + "/expected.json")) as Dictionary
		var want: Array = (expected.get("refunded", []) as Array).duplicate()
		want.sort()
		var got: Array = []
		if FileAccess.file_exists(dir + "/meta.json"):
			var r := SaveReport.new()
			var m := MetaSave.from_text(FileAccess.get_file_as_string(dir + "/meta.json"), db, null, [], r)
			t.not_null(m, "%s/meta.json 读得回来" % name)
			t.check(r.dropped.is_empty(), "%s/meta.json 没有丢掉的" % name)
			got.append_array(r.refunded.map(func(row): return String(row["id"])))
			if m != null and expected.has("funds_after"):
				t.eq(m.funds, int(expected["funds_after"]), "%s：折完的钱" % name)
		if FileAccess.file_exists(dir + "/run.json"):
			var rr := SaveReport.new()
			var run := RunSave.from_text(FileAccess.get_file_as_string(dir + "/run.json"), db, _enemies(), null, rr)
			t.not_null(run, "%s/run.json 读得回来" % name)
			t.check(rr.dropped.is_empty(), "%s/run.json 没有丢掉的" % name)
			got.append_array(rr.refunded.map(func(row): return String(row["id"])))
		got.sort()
		t.eq(got, want, "%s：折钱的道具和 expected.json 一致" % name)
