## 把校准快照（真实对局里每步记的玩家配置）按步数分段、每段生成一个木桩（报告 073）。
##
##     godot --headless --path . --script res://tools/build_dummies.gd -- [快照路径=user://calibration/snapshots.jsonl] [段长=5 或 难度 id（按它的段位表分段）] [输出=res://data/authoring/calibration/dummies.json]
##
## 没有快照文件时退回「开局装备当第 0 段」（只够把工具跑通，不是真的平均玩家）。
extends CliTool


## 第二个参数是难度 id 时，用它的猎手机制里的段位表
static func _brackets_of(seg: String) -> Array[int]:
	var out: Array[int] = []
	if seg.is_valid_int():
		return out
	var path := ContentPaths.asset_file("difficulties", seg)
	if not ResourceLoader.exists(path):
		return out
	var diff := load(path) as DifficultyDef
	if diff == null:
		return out
	for m in diff.mechanics:
		if m is HunterMechanic:
			return (m as HunterMechanic).bracket_steps.duplicate()
	return out


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var src: String = args[0] if args.size() > 0 else CalibrationRecorder.DEFAULT_PATH
	var seg: String = args[1] if args.size() > 1 else "5"
	var out_path: String = args[2] if args.size() > 2 else DummyBuilder.DEFAULT_PATH
	var items := ItemDatabase.new()
	items.load_dir()
	var snaps := CalibrationRecorder.read_all(src)
	if snaps.is_empty():
		print("没有快照（%s），退回开局装备当第 0 段" % src)
		snaps = DummyBuilder.from_loadouts(GameFlow.load_loadouts(), items, CombatantBaseline.with_hp(60.0))
	var brackets := _brackets_of(seg)
	var dummies := DummyBuilder.build_by_brackets(snaps, items, brackets) if not brackets.is_empty() else DummyBuilder.build(snaps, items, maxi(1, int(seg)))
	if not brackets.is_empty():
		print("按难度 %s 的段位表分段：%s" % [seg, str(brackets)])
	if dummies.is_empty():
		print("一份都没有")
		finish(1)
		return
	if DummyBuilder.save(dummies, out_path) != OK:
		print("写不了 " + out_path)
		finish(1)
		return
	var keys: Array = dummies.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
	for k in keys:
		var d: Dictionary = dummies[k]
		print("第 %s～%s 步：%d 份样本，平均生命 %.0f / DPS %.1f，木桩生命 %.0f / DPS %.1f，%d 件" % [
			(d["steps"] as Array)[0], (d["steps"] as Array)[1], int(d["samples"]), float(d["avg_hp"]), float(d["avg_dps"]),
			float(d["hp"]), float(d["dps"]), (d["layout"] as Array).size()])
	print("写入 %s（%d 段，快照 %d 份）" % [out_path, dummies.size(), snaps.size()])
	finish(0)
