## 236 ⑦：启动预热 —— 主菜单亮起来的那几帧把第一次走到战前 / 战斗要付的账付掉：字体建好、裁切着色器建好、斗技场底图进缓存；
## 打完一场战斗屏把底图放掉（236 ⑤ release_art）
extends RefCounted

const GAME := "res://ui/game/game.tscn"
const Support := preload("res://tests/run/flow_support.gd")


static func frame_warm_up(t: TestCase, root: Window) -> void:
	t.begin("236 · 启动预热：五种字体 + 两种系统字体建好、裁切着色器建好、斗技场底图在缓存里；预热那块画完就放；release_art 按前缀踢掉")
	Support.cleanup("warm236")
	UiTheme.release_art(UiTheme.ART_BATTLE_BG)
	var game = (load(GAME) as PackedScene).instantiate()
	game.save_path = String(Support.paths("warm236")["run"])
	game.meta_path = String(Support.paths("warm236")["meta"])
	game.settings_path = String(Support.paths("warm236")["settings"])
	root.add_child(game)
	game.warm_now()
	for key in ["body", "bold", "title", "display", "numeral", "system", "system_bold"]:
		t.check(UiPalette._fonts.has(key), "字体 %s 建好了" % key)
	t.check(UiMotion.is_warm(), "裁切着色器建好了")
	t.check(UiTheme.art_is_cached(UiTheme.ART_BATTLE_BG), "斗技场底图在缓存里")
	t.check(game._warm == null, "预热那块画完就放掉")
	t.eq(UiTheme.release_art("battle/"), 1, "release_art：按前缀踢掉一张")
	t.check(not UiTheme.art_is_cached(UiTheme.ART_BATTLE_BG), "踢掉之后不在缓存里")
	t.eq(UiTheme.release_art("battle/"), 0, "再踢：没有了")
	game.queue_free()
	Support.cleanup("warm236")
