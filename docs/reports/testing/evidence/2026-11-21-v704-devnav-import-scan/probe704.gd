extends SceneTree
## 游戏测试 v7.04（PR #756）：DevNav 素材导入检查挪到工作线程、只在 Git 提交号变了才扫。
## 不进游戏场景，只看 DevNav 自动加载：每帧记扫描任务号、扫出来几件、后台导入进程、提交号戳
const ImportCheck := preload("res://tools/import_check.gd")
var _f := 0
var _t0 := 0
var _scan_frames := 0
var _done_at := -1
var _seen_task := false
var _logged_pid := false


func L(s: String) -> void:
	print("P704 " + s)


func _stamp() -> String:
	return FileAccess.get_file_as_string(ImportCheck.STAMP).strip_edges() if FileAccess.file_exists(ImportCheck.STAMP) else "（没有）"


func _initialize() -> void:
	_t0 = Time.get_ticks_msec()
	L("启动：Git 提交号 %s；戳 %s；要扫 %s" % [ImportCheck.git_head(), _stamp(), str(ImportCheck.needs_scan())])


func _process(_d: float) -> bool:
	_f += 1
	var nav := root.get_node_or_null("DevNav")
	if nav == null:
		if _f == 1: L("没有 DevNav 自动加载")
		if _f > 30: quit(1); return true
		return false
	var task: int = nav.get("_asset_scan_task")
	var pid: int = nav.get("_asset_import_pid")
	if task >= 0:
		_seen_task = true
		_scan_frames += 1
	elif _done_at < 0 and _f > 1:
		_done_at = _f
		L("第 %d 帧（%d ms）扫描结束：扫描期间主线程照常走了 %d 帧；扫出没导入 %d 件 %s；后台导入进程 %d；戳 %s" % [_f, Time.get_ticks_msec() - _t0, _scan_frames, (nav.get("_asset_todo") as Array).size(), str((nav.get("_asset_todo") as Array).slice(0, 3)), pid, _stamp()])
		var note = nav.get("_asset_note")
		L("　　右上角小字：%s" % ((note as Label).text if note != null else "（没有）"))
	if _done_at > 0 and pid > 0 and not _logged_pid:
		_logged_pid = true
		L("后台导入在跑（pid %d）" % pid)
	if _done_at > 0 and pid <= 0 and _f > _done_at + 10:
		if _logged_pid: L("后台导入跑完（第 %d 帧，%d ms）；小字 %s；戳 %s" % [_f, Time.get_ticks_msec() - _t0, "还在" if nav.get("_asset_note") != null else "撤了", _stamp()])
		quit(0); return true
	if _f > 20000:
		L("超时"); quit(1); return true
	return false
