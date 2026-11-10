## 平衡检测方案（2026-11-10）§5.1：按诊断包（`.diag.tres`，[BattleDiagPack]）重跑一场，比对胜方、时长、规范化事件和最终资源。
##
##     godot --headless --path . --script res://tools/reproduce_battle.gd -- <诊断包> [--allow-build-mismatch]
##
## 只调 [BattleSim]：不结算、不碰存档、不发奖励。构建对不上默认拒绝（规则改了随机数的调用次数就变，逐条对不上不说明什么）；
## 加 `--allow-build-mismatch` 照跑，结论只作参考。回放存档（`.replay.json`）不带双方编译结果，只能播放，不能精确复现。
## 退出码：0 一致；1 不一致（打印第一处不同）；3 包坏了 / 缺资源 / 不是诊断包；4 构建对不上；2 工具自己崩了
extends CliTool

const EXIT_SAME := 0
const EXIT_DIFF := 1
const EXIT_BAD := 3
const EXIT_BUILD := 4


func run() -> void:
	var args := OS.get_cmdline_user_args()
	var paths: Array[String] = []
	for a in args:
		if not a.begins_with("--"):
			paths.append(a)
	if paths.is_empty():
		printerr("用法：reproduce_battle.gd -- <诊断包.diag.tres> [--allow-build-mismatch]")
		finish(EXIT_BAD)
		return
	var path := paths[0]
	if path.ends_with(BattleArchive.REPLAY_EXT):
		printerr("这是回放存档：只存了结果、不带双方编译结果，不能精确复现（可以在开发工具的「战斗回放」里播放）")
		finish(EXIT_BAD)
		return
	var pack := BattleDiagnostics.load_pack(path)
	if pack == null:
		printerr("读不出诊断包：", path, "（文件坏了、引用的资源没了，或不是诊断包）")
		finish(EXIT_BAD)
		return
	var problems := pack.problems()
	if not problems.is_empty():
		printerr("诊断包不完整：", "；".join(problems))
		finish(EXIT_BAD)
		return
	var want_build := String(pack.meta.get("build", ""))
	var here := BuildInfo.id()
	var mismatch := want_build != here
	print("诊断包：", path)
	print("  构建 %s（现在 %s）%s" % [want_build, here, "  ← 对不上" if mismatch else ""])
	print("  战斗 %s，种子 %d，时限 %.0f 秒" % [String(pack.meta.get("battle_id", "")), pack.rng_seed, pack.time_limit])
	if mismatch and not args.has("--allow-build-mismatch"):
		printerr("构建对不上，不重跑（加 --allow-build-mismatch 照跑，结论只作参考）")
		finish(EXIT_BUILD)
		return
	var got := BattleDiagPack.summary(pack.rerun())
	var diff := BattleDiagPack.compare(pack.expected, got)
	if diff.is_empty():
		print("一致：胜方 %d，时长 %d，%d 条事件，摘要 %s" % [got["winner"], got["duration"], got["events"], got["digest"]])
		finish(EXIT_SAME)
		return
	print("不一致：%s" % diff["field"])
	if diff.has("index"):
		print("  第 %d 条事件" % int(diff["index"]))
	print("  原来：", diff["want"])
	print("  现在：", diff["got"])
	if mismatch:
		print("  （构建不同，规则改了随机数的调用次数就会这样；看多种子分布，不看逐条）")
	finish(EXIT_DIFF)
