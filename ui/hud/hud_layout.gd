## 150：一屏的读数摆法 —— 每件一条 `{id, anchor, offset, line, tier, visible, debug_only}`。
##
## - `anchor`：九宫锚点（[constant ANCHORS]），`offset` 相对锚点（像素）。
## - 锚点与偏移都一样的几件是**一组**：按 `line` 分行（同一行按列表顺序横排，行与行往下排），整组按锚点对齐 ——
##   「倒计时在最上一行、读数一排在它下面」就是同一组的第 0 行与第 1 行；没内容的行收起来，下面的往上补。
##   拖开的一件拿到自己的偏移，就自成一组。
## - `debug_only`（150 补 2）：只在调试模式（[member GameSettings.debug_mode]）下造；关着时宿主跳过它（不造、不占地上）。
##   文件里没写就按默认布局里这件的值（日志是 true）。
## - 文件：`data/authoring/ui_layouts/<屏>.json`（开发版「保存布局」写这里，作者提交）；导出版写 `user://ui_layouts/<屏>.json`，先读它。
##   都没有 = [method default_for] 里写死的默认（就是 150 之前的样子）。不走内容管线：这份文件是游戏自己写的，存了立刻生效
class_name HudLayout
extends RefCounted

## 锚点 → 在宿主里的相对位置（也是组对齐的支点：左上对齐左上、居中对齐中心、右下对齐右下）
const ANCHORS := {
	"top_left": Vector2(0, 0), "top": Vector2(0.5, 0), "top_right": Vector2(1, 0),
	"left": Vector2(0, 0.5), "center": Vector2(0.5, 0.5), "right": Vector2(1, 0.5),
	"bottom_left": Vector2(0, 1), "bottom": Vector2(0.5, 1), "bottom_right": Vector2(1, 1),
}
const TIERS := {"large": HudWidget.Tier.LARGE, "small": HudWidget.Tier.SMALL, "double": HudWidget.Tier.DOUBLE}
## 布局文件的版本：默认布局改了就加一，旧版本存的那份不用（回默认）。2 = 作者 2026-10-12：提示行进调试台、去掉行动点与距离、顶栏 200%；
## 3 = 160：腰带挪到右下角
const VERSION := 3
## 「摆读数」松手时吸附的网格
const GRID := 8
const DEV_DIR := "res://data/authoring/ui_layouts"
const USER_DIR := "user://ui_layouts"

var screen: String = "map"
## 每件一条（顺序 = 同一组里的排列顺序）
var entries: Array[Dictionary] = []


## 150 之前地图屏的样子：倒计时顶上居中一行大字，下面一排读数；
## 150 补 1：原来右栏里的东西（背包 / 回到这个点 / 撤离按钮、技能、回主菜单、路线、腰带）按原来的顺序竖排贴在右上，
## 日志贴在右下（只在调试模式）
static func default_for(p_screen: String) -> HudLayout:
	var l := HudLayout.new()
	l.screen = p_screen
	if p_screen == "map":
		l.entries.append(entry(&"countdown", "top", Vector2(0, 0), 0, "large"))
		# 作者 2026-10-12：行动点与距离没有意义 —— 默认藏起来（条目与组件留着，摆读数时右键能放出来）；剩下的放大到 200%
		for id in [&"action_points", &"distances", &"vitality", &"wallet", &"ground_count", &"encumbrance", &"faith", &"buffs", &"erosion"]:
			l.entries.append(entry(id, "top", Vector2(0, 0), 1, "double", not (id in HIDDEN_BY_DEFAULT)))
		var line := 0
		for id in COLUMN:
			l.entries.append(entry(id, "top_right", COLUMN_OFFSET, line))
			line += 1
		l.entries.append(entry(&"belt", "bottom_right", BELT_OFFSET))     # 160：腰带常驻右下角
		l.entries.append(entry(&"log", "bottom_right", LOG_OFFSET, 0, "small", true, true))
	return l


## 默认布局里右上那一列（自上而下）与它离右上角的偏移（右上角是 DevNav 的按钮），日志离右下角的偏移
## 作者 2026-10-12：提示行挪进调试台（地图屏自己放，不再是部件）
const COLUMN: Array[StringName] = [&"dev_drawer", &"bag_button", &"reopen_button", &"extract_button",
	&"skills", &"menu_button", &"routes"]
const COLUMN_OFFSET := Vector2(-8, 32)
## 默认布局里藏着的读数
const HIDDEN_BY_DEFAULT: Array[StringName] = [&"action_points", &"distances"]
## 160：腰带在右下角，日志（只在调试模式）在它上面
const BELT_OFFSET := Vector2(-8, -8)
const LOG_OFFSET := Vector2(-8, -96)


static func entry(id: StringName, anchor: String, offset: Vector2, line: int = 0, tier: String = "small", visible: bool = true,
		debug_only: bool = false) -> Dictionary:
	return {"id": id, "anchor": anchor, "offset": offset, "line": line, "tier": tier, "visible": visible, "debug_only": debug_only}


#region 文件
## 读一屏的布局：user 那份 → 仓库那份 → 默认。[param problems] 收坏掉的地方（坏文件整份不用，回默认）
static func load_for(p_screen: String, problems: Array[String] = []) -> HudLayout:
	for path in [user_path(p_screen), dev_path(p_screen)]:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and int((parsed as Dictionary).get("version", 1)) != VERSION:
			continue     # 旧版本存的：默认布局改过了，不用它
		var l := from_dict(parsed if parsed is Dictionary else {}, problems)
		if l != null and problems.is_empty():
			return l
		problems.append("%s 读不了，用默认布局" % path)
		break
	return default_for(p_screen)


static func dev_path(p_screen: String) -> String:
	return "%s/%s.json" % [DEV_DIR, p_screen]


static func user_path(p_screen: String) -> String:
	return "%s/%s.json" % [USER_DIR, p_screen]


## 「保存布局」写哪：开发版写仓库里那份（作者直接提交），导出版写 user
static func save_path(p_screen: String) -> String:
	return user_path(p_screen) if OS.has_feature("template") else dev_path(p_screen)


func save(path: String = "") -> bool:
	var p := path if path != "" else save_path(screen)
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "  ") + "\n")
	f.close()
	return true


## 「重置」：删掉保存的那份（回默认）
static func reset(p_screen: String) -> void:
	for p in [user_path(p_screen), save_path(p_screen)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
#endregion


#region 字典往返与校验
func to_dict() -> Dictionary:
	var out: Array = []
	for e in entries:
		var o: Vector2 = e["offset"]
		var d := {"id": String(e["id"]), "anchor": e["anchor"], "offset": [int(o.x), int(o.y)], "tier": e["tier"]}
		if int(e.get("line", 0)) != 0:
			d["line"] = int(e["line"])
		if not bool(e.get("visible", true)):
			d["visible"] = false
		if bool(e.get("debug_only", false)):
			d["debug_only"] = true
		out.append(d)
	return {"screen": screen, "version": VERSION, "widgets": out}


## 校验并读成布局；有错写进 [param problems] 并返回 null（只校验 id、锚点、档位、偏移的形状）
static func from_dict(d: Dictionary, problems: Array[String] = []) -> HudLayout:
	var before := problems.size()
	var l := HudLayout.new()
	l.screen = String(d.get("screen", "map"))
	var raw: Variant = d.get("widgets", null)
	if not (raw is Array):
		problems.append("widgets 得是一个列表")
		return null
	var seen := {}
	var fallback := default_for(l.screen)
	for i in (raw as Array).size():
		var w: Variant = raw[i]
		var at := "widgets[%d]" % i
		if not (w is Dictionary):
			problems.append(at + "：得是一个对象")
			continue
		var id := StringName(String(w.get("id", "")))
		if not HudWidgets.has(id):
			problems.append("%s：没有这种读数 '%s'（有：%s）" % [at, id, ", ".join(HudWidgets.KINDS.keys())])
		elif seen.has(id):
			problems.append("%s：'%s' 写了两次" % [at, id])
		seen[id] = true
		var anchor := String(w.get("anchor", "top_left"))
		if not ANCHORS.has(anchor):
			problems.append("%s：没有这个锚点 '%s'（九宫：%s）" % [at, anchor, ", ".join(ANCHORS.keys())])
		var tier := String(w.get("tier", "small"))
		if not TIERS.has(tier):
			problems.append("%s：档位只有 %s，写的是 '%s'" % [at, " / ".join(TIERS.keys()), tier])
		var off: Variant = w.get("offset", [0, 0])
		if not (off is Array and (off as Array).size() == 2 and (off[0] is float or off[0] is int) and (off[1] is float or off[1] is int)):
			problems.append("%s：offset 得是两个数 [x, y]" % at)
			off = [0, 0]
		var debug_default := bool(fallback.entry_of(id).get("debug_only", false))
		l.entries.append(entry(id, anchor, Vector2(float(off[0]), float(off[1])), int(w.get("line", 0)), tier, bool(w.get("visible", true)),
			bool(w.get("debug_only", debug_default))))
	return l if problems.size() == before else null


func entry_of(id: StringName) -> Dictionary:
	for e in entries:
		if StringName(e["id"]) == id:
			return e
	return {}
#endregion
