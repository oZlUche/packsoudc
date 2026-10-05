## `GameFlow` 的服务与接线（101 第 4 刀）：
##
## - **不许漏接**：一局（`RunState`）、节点事件（`NodeEvents`）与六个模块发出来的每个 signal，
##   在 `core/` 或 `ui/` 里都得有人接 —— 否则就是「发了没人听」，表现是某个屏永远不弹、某句提示永远不出现，
##   而测试与编译都不会红。新加一个 signal 忘了接线，这条当场抓住；确实只给测试或将来留的，写进白名单并写原因。
## - **服务各自独立可测**：成就与解锁（[Achievements]）、切存档位的文件层（[method SaveSlots.open]）、
##   卖地上与带回来的棋盘（[MetaState]）都不再长在 `GameFlow` 身上，不造一个 `GameFlow` 也能测。
extends RefCounted

const Support := preload("res://tests/support.gd")
const FlowSupport := preload("res://tests/run/flow_support.gd")
const NodeScreens := preload("res://tests/ui/test_node_screens.gd")

## 发了没人接、但有正当理由的（写清理由；这张表越短越好）
const NO_LISTENER_OK := {
	&"shop_closed": "GameFlow 走会话自己的 closed 往下走（_adopt 里 session.closed.connect(_flush)）；这条留给测试与将来的界面",
}

const SIGNAL_SOURCES := [
	"res://core/run/run_state.gd",
	"res://core/run/node_events.gd",
]
const MODULE_DIR := "res://core/run/modules"
## 在这两棵树里找「谁接了」
const LISTENER_DIRS := ["res://core", "res://ui"]


static func _scripts_under(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var path := "%s/%s" % [dir, name]
		if d.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_scripts_under(path))
		elif name.ends_with(".gd"):
			out.append(path)
		name = d.get_next()
	d.list_dir_end()
	out.sort()
	return out


static func _text_of(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


## 一个脚本里声明的 signal 名字
static func _signals_in(text: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for line in text.split("\n"):
		var s := (line as String).strip_edges()
		if not s.begins_with("signal "):
			continue
		var rest := s.substr(7).strip_edges()
		var cut := rest.find("(")
		out.append(StringName(rest.substr(0, cut).strip_edges() if cut > 0 else rest))
	return out


static func run_no_signal_left_unheard(t: TestCase) -> void:
	t.begin("接线 · 不许漏接（101 第 4 刀）：一局、节点事件与六个模块的每个 signal 在 core/ 或 ui/ 里都有人接，例外写进白名单")
	var sources: Array[String] = []
	sources.append_array(SIGNAL_SOURCES)
	for path in _scripts_under(MODULE_DIR):
		sources.append(path)
	t.check(sources.size() >= 8, "找到了发信号的那几个脚本：%d 个" % sources.size())
	# 谁接了：把两棵树的源码读成一份大文本，找 `<名字>.connect(`
	var listeners := ""
	for dir in LISTENER_DIRS:
		for path in _scripts_under(dir):
			listeners += _text_of(path)
	t.check(listeners.length() > 100000, "读到了 core/ 与 ui/ 的源码（%d 字）" % listeners.length())
	var checked := 0
	for path in sources:
		for sig in _signals_in(_text_of(path)):
			checked += 1
			if NO_LISTENER_OK.has(sig):
				t.check(not NO_LISTENER_OK[sig].is_empty(), "%s 在白名单里，写了原因" % sig)
				continue
			t.check(listeners.contains("%s.connect(" % sig), "%s（%s）有人接" % [sig, path.get_file()])
	t.check(checked >= 35, "一共查了 %d 个 signal" % checked)


static func run_achievements_service(t: TestCase) -> void:
	t.begin("服务 · 成就与解锁（101 第 4 刀）：纯逻辑，不造 GameFlow 也能测；「全部解锁」开着时成就不计、一切算解锁")
	var items := ItemDatabase.new()
	items.load_dir()
	var meta := MetaState.new()
	var ach := Achievements.new()
	ach.meta = meta
	ach.items = items
	ach.defs = GameFlow.load_achievements()
	ach.chapters = GameFlow.load_chapters()
	ach.difficulties = GameFlow.load_difficulties()
	t.check(not ach.defs.is_empty(), "装到了成就表：%d 枚" % ach.defs.size())
	t.check(not ach.locked_item_ids().is_empty(), "一份新存档里有锁着的道具")
	t.check(not ach.unlocked(&"ach_extract_3"), "没达成：没解锁")
	# 一份新存档什么都没做：没有成就
	t.check(ach.check().is_empty() and ach.notes.is_empty(), "什么都没做：没有新成就、没有通知")
	# 「全部解锁」开着：成就不计、一切算解锁、没有锁着的道具
	ach.unlock_all = true
	t.check(ach.unlocked(&"no_such_unlock") and ach.locked_item_ids().is_empty(), "全部解锁：什么都算解锁、没有锁着的道具")
	t.check(ach.check().is_empty(), "全部解锁开着：成就不计（作者定 10.2 第 4 条）")
	ach.unlock_all = false
	# 达成一枚：记进局外、给解锁、攒一句通知；再算不重复给
	var first: AchievementDef = null
	for def in ach.defs:
		if def != null and not def.grants.is_empty():
			first = def
			break
	if first == null:
		t.check(false, "成就表里有带解锁的成就")
		return
	meta.extractions = 99
	meta.runs = 99
	meta.boss_kills = 9
	meta.battles_won = 99
	meta.funds = 99999
	var got := ach.check()
	t.check(not got.is_empty(), "刷满局外数字：有成就达成了（%d 枚）" % got.size())
	t.eq(ach.notes.size(), got.size(), "每枚攒一句通知（持有方 take_notes 取走）")
	for def in got:
		t.check(meta.has_achievement(def.id), "记进局外：%s" % def.id)
		for g in def.grants:
			t.check(meta.has_unlock(g) and ach.unlocked(g), "给了它许诺的解锁：%s" % g)
			t.check(not ach.unlock_names(g).is_empty(), "%s 开的东西说得出来：%s" % [g, str(ach.unlock_names(g))])
			t.check(ach.granting(g) == def, "反查得到是哪枚成就给的")
	ach.notes.clear()
	t.check(ach.check().is_empty() and ach.notes.is_empty(), "再算一次不重复给")
	# 规则卡：看过之前 pending，看过之后不 pending；第二次标记返回 false（没变 = 不用存盘）
	var chapter: ChapterDef = null
	for c in ach.chapters:
		if c != null and not c.rules.is_empty():
			chapter = c
			break
	if chapter != null:
		t.check(ach.rules_card_pending(chapter), "有规则卡、没看过：该弹")
		t.check(ach.mark_rules_seen(chapter), "标记看过：局外变了（持有方据此存盘）")
		t.check(not ach.rules_card_pending(chapter), "看过了：不再弹")
		t.check(not ach.mark_rules_seen(chapter), "再标记一次：没变，不用存")


static func run_slot_open(t: TestCase) -> void:
	t.begin("服务 · 切存档位的文件层（101 第 4 刀）：SaveSlots.open 建目录、给两条路径、读局外；读不出来先备份再从零开始（098）")
	var items := ItemDatabase.new()
	items.load_dir()
	var root := "user://test_slot_open"
	var slots := SaveSlots.new(root)
	var empty := slots.open(1, items)
	t.eq([String(empty["run_path"]), String(empty["meta_path"])], ["%s/1/run.json" % root, "%s/1/meta.json" % root], "两条路径按位算")
	t.is_null(empty["meta"], "空位：没有局外")
	t.eq(String(empty["backup"]), "", "空位：没有备份")
	# 写一份好的：读得出来
	var meta := MetaState.new()
	meta.funds = 1234
	t.eq(MetaSave.write(meta, String(empty["meta_path"])), OK, "存一份局外")
	var good := slots.open(1, items)
	var back := good["meta"] as MetaState
	t.check(back != null and back.funds == 1234, "读回来了：钱还是 1234")
	t.eq(String(good["backup"]), "", "读得出来：不备份")
	# 写一份坏的：先备份，再交出 null（持有方从零开始，老档还在硬盘上）
	var f := FileAccess.open(String(empty["meta_path"]), FileAccess.WRITE)
	t.not_null(f, "能写坏文件")
	if f != null:
		f.store_string("{这不是 JSON")
		f.close()
	var bad := slots.open(1, items)
	t.is_null(bad["meta"], "读不出来：交出 null（持有方开一份新的）")
	var backup_path := String(bad["backup"])
	t.check(backup_path.ends_with(".bak") and FileAccess.file_exists(backup_path), "先备份了：%s" % backup_path)
	t.check(not FileAccess.file_exists(String(empty["meta_path"])), "老文件改名走了，不会被下一次存盘盖掉")
	t.check(not slots.exists(1), "备份不算存档（exists 不看 .bak）")
	# 收尾
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
	slots.remove(1)


static func run_meta_stash_and_sale(t: TestCase) -> void:
	t.begin("服务 · 卖地上与带回来的棋盘（101 第 4 刀）：账在 MetaState 里，开局屏与结算屏只管画")
	var items := ItemDatabase.new()
	items.load_dir()
	var meta := MetaState.new()
	var def := items.get_def(items.all_ids()[0])
	t.not_null(def, "拿到一件道具定义")
	# 带回来的棋盘 → 暂存那一栏 → 原样放回
	meta.board = GridInventory.new(RunState.BOARD_SIZE, MetaState.BOARD_ID, false)
	var inst := ItemInstance.create(def)
	inst.uid = meta.allocate_uid()
	t.check(meta.board.try_add(inst, true), "带回来的棋盘上有一件")
	var origin := inst.origin
	var stash := ItemStash.new(110, 0)
	var pending := meta.take_board_to_stash(stash)
	t.eq([stash.item_count(), meta.board == null or meta.board.item_count() == 0], [1, true], "挪进暂存那一栏，棋盘空了")
	t.check(pending.has(inst.uid) and pending[inst.uid]["origin"] == origin, "记住了原位")
	var lost := meta.return_stash(stash, pending)
	t.check(lost.is_empty(), "放得回去：没有丢的")
	t.eq(stash.item_count(), 0, "暂存那一栏清空")
	t.check(meta.board != null and meta.board.item_count() == 1, "回到带回来的棋盘上")
	var put_back := meta.board.items()[0] as ItemInstance
	t.eq(put_back.origin, origin, "按原位放回")
	# 地上没背出来的一键出售：只算 / 真卖 / 只卖一次
	var r := RunResult.new()
	r.outcome = &"extracted"
	var left: Array[ItemInstance] = [ItemInstance.create(def), ItemInstance.create(def)]
	r.left_items = left
	var ratio := 0.5
	var preview := MetaState.left_behind_preview(r, ratio)
	t.eq(int(preview["count"]), 2, "预览：两件")
	t.eq(int(preview["funds"]), 2 * MetaState.sell_price(def, ratio), "预览：卖价之和")
	t.eq(MetaState.left_behind_preview(r, ratio), preview, "只算不卖：再算一次一样")
	var funds0 := meta.funds
	var sold := meta.sell_left_behind(r, ratio)
	t.eq(sold, preview, "真卖：和预览一致")
	t.eq(meta.funds, funds0 + int(preview["funds"]), "钱进局外")
	t.check(r.left_items.is_empty(), "清单清掉")
	t.eq(int(meta.sell_left_behind(r, ratio)["count"]), 0, "只卖一次")
	# 没撤离出来的（战败）不卖
	var dead := RunResult.new()
	dead.outcome = &"defeated"
	dead.left_items = [ItemInstance.create(def)] as Array[ItemInstance]
	t.eq(int(MetaState.left_behind_preview(dead, ratio)["count"]), 0, "没撤离出来：地上的不卖（东西没带出来）")

## 101 第 5 刀：只属于一局的 UI 接线走信号，core 不认识 ui
static func run_run_changed_signal(t: TestCase) -> void:
	t.begin("接线 · 一局换了就发信号（101 第 5 刀）：悬浮窗的信仰探针由 GameDirector 在 run_changed 上接，GameFlow 不认识 ItemTooltip")
	var flow_src := FileAccess.get_file_as_string("res://core/run/game_flow.gd")
	t.check(flow_src.contains("signal run_changed("), "GameFlow 发 run_changed")
	t.check(flow_src.contains("func faith_status()"), "GameFlow 只交出数据（faith_status）")
	var director_src := FileAccess.get_file_as_string("res://ui/game/game_director.gd")
	t.check(director_src.contains("flow.run_changed.connect("), "GameDirector 接了这条信号")
	t.check(director_src.contains("ItemTooltip.faith_probe"), "探针在界面那侧设")
	# 空的一局外：没有信仰状态
	t.check(GameFlow.new().faith_status().is_empty(), "不在局里：没有信仰状态（主菜单的悬浮窗不按信仰上色）")
	# 真开一局：发了信号、问得出状态
	FlowSupport.cleanup("wire5")
	var flow := FlowSupport.flow(NodeScreens._content(), "wire5")
	var seen: Array = []
	flow.run_changed.connect(func(state: RunState): seen.append(state))
	var run := flow.begin_direct(flow.chapters[0] if not flow.chapters.is_empty() else null, 7)
	if run == null:
		t.check(false, "开局")
		FlowSupport.cleanup("wire5")
		return
	t.eq(seen.size(), 1, "开了一局：发了一次")
	t.check(seen[0] == run, "带着这一局")
	var status := flow.faith_status()
	t.check(status.has("active") and status.has("tier") and status.has("points"), "问得出激活的信仰、阶、信力：%s" % str(status))
	t.eq(StringName(String(status["active"])), run.active_faith_id(), "和这一局对得上")
	flow.to_main_menu()
	t.eq(seen.size(), 2, "回主菜单：又发了一次")
	t.is_null(seen[1], "带的是 null（界面据此摘掉探针）")
	t.check(flow.faith_status().is_empty(), "回主菜单之后又问不出信仰状态了")
	FlowSupport.cleanup("wire5")
