## 176：启动屏，项目的主场景。第一帧只画游戏名和一条进度；正式游戏 `game.tscn`（连同它引用到的几百个脚本）
## 在后台线程载入，好了再切过去。原来脚本全量编译挡在第一帧之前，窗口「无响应」两三秒（Windows 更久）；
## 总时长不变，但窗口一直在刷新。`game_director._ready` 里的内容加载仍在主线程（176 待定 2 选 A）。
##
## **不引用任何全局类**（自己不写 class_name，不碰 UiPalette 等）：引用一个，那个类的整张引用图就又回到第一帧之前。
## 颜色写死（与 UiPalette 同值），字体按路径 load()。`tests/tools/test_startup_graph.gd` 守着这条
##
## 197 补充一：底画主菜单第一张画（营地）压暗到 40 %、游戏名同菜单那样写（补充三：居中在上方，思源宋体 Bold 描边）；
## 补充二 §12：有字标图（`menu/title_boot.png`，1×）就画图（同菜单位置、也压暗 40 %），没有才写字。
## 菜单打开时那张画从 40 % 亮起来 —— 启动到菜单是「同一张画亮起来」，不换画面。画按路径 load()，不碰 UiTheme
extends Control

const TARGET := "res://ui/game/game.tscn"
## 与 UiPalette.BG / FG / DIM 同值（不能引用它）
const BG := Color("101216")
const FG := Color("dfe3ea")
const DIM := Color("8b93a1")
const TITLE_FONT := "res://assets/fonts/serif_bold.otf"
## 与主菜单第一张画、[constant UiTheme.HERO_TITLE_COLOR] 等同值（不能引用它们）
const BACKDROP := "res://assets/ui/menu/bg_camp.png"
const BACKDROP_DIM := 0.4
const BACKDROP_BLEED := 0.05
const LOGO := "res://assets/ui/menu/title_boot.png"
const LOGO_WIDTH := 1116.0
const LOGO_TOP := 90.0
## 221: the words on this screen by language (the boot screen can't use UiText; same text as `game.title`)
const WORDS := {
	"zh": {"title": "背包搜打撤", "loading": "载入中……", "failed": "载入失败，请重启游戏", "size": 128},
	"en": {"title": "Pack & Extract", "loading": "Loading…", "failed": "Loading failed. Please restart the game.", "size": 96},
}
## same file as GameSettings.DEFAULT_PATH (can't reference it)
const SETTINGS := "user://settings.json"
const TITLE_COLOR := Color("f0e2c4")
const TITLE_OUTLINE_COLOR := Color("1a1410")
const TITLE_OUTLINE := 6
const TITLE_SPACING := 6
const TITLE_TOP := 90.0
const DESIGN_HEIGHT := 1080.0
const BODY_FONT := "res://assets/fonts/serif_regular.otf"
const BAR_W := 360.0
const BAR_H := 4.0

## 载好之后自己切过去（测试关掉，只看载没载好）
var auto_switch := true
## 0–1
var progress := 0.0
var failed := false
## 载好的主场景（切之前）
var scene: PackedScene = null
var _title_font: Font = null
var _body_font: Font = null
var _backdrop: Texture2D = null
var _logo: Texture2D = null
## "zh" / "en", read from the settings file
var lang := "zh"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	lang = read_lang()
	_title_font = _font(TITLE_FONT)
	_body_font = _font(BODY_FONT)
	_backdrop = load(BACKDROP) as Texture2D if ResourceLoader.exists(BACKDROP) else null
	_logo = load(LOGO) as Texture2D if ResourceLoader.exists(LOGO) else null
	start()


func start() -> void:
	failed = ResourceLoader.load_threaded_request(TARGET) != OK


func _process(_delta: float) -> void:
	if scene == null and not failed:
		poll()
		queue_redraw()


## 查一次后台载入的进度；载好了记下场景（[member auto_switch] 时下一帧切过去）。返回 [enum ResourceLoader.ThreadLoadStatus]
func poll() -> int:
	var p: Array = []
	var status := ResourceLoader.load_threaded_get_status(TARGET, p)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		progress = maxf(progress, float(p[0]) if not p.is_empty() else 0.0)
	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		progress = 1.0
		scene = ResourceLoader.load_threaded_get(TARGET) as PackedScene
		failed = scene == null
		if not failed and auto_switch:
			get_tree().change_scene_to_packed.call_deferred(scene)
	else:
		failed = true
	return status


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	if _backdrop != null:
		draw_texture_rect(_backdrop, cover_rect(_backdrop.get_size(), size), false, Color(BACKDROP_DIM, BACKDROP_DIM, BACKDROP_DIM))
	var mid := size * 0.5
	if _logo != null and size.y > 0.0:
		var k := size.y / DESIGN_HEIGHT
		var wide := LOGO_WIDTH * k
		var dim := Color(BACKDROP_DIM, BACKDROP_DIM, BACKDROP_DIM)
		draw_texture_rect(_logo, Rect2(Vector2((size.x - wide) * 0.5, LOGO_TOP * k), Vector2(wide, wide * _logo.get_height() / maxf(_logo.get_width(), 1.0))), false, dim)
	elif _title_font != null and size.y > 0.0:
		var s := size.y / DESIGN_HEIGHT
		var title := String(WORDS[lang]["title"])
		var font_size := int(round(int(WORDS[lang]["size"]) * s))
		var widths: Array[float] = []
		var total := 0.0
		for ch in title:     # 字距：一个字一个字往右排（Font 没有字距参数），整排居中
			widths.append(_title_font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
			total += widths.back() + TITLE_SPACING
		var at := Vector2((size.x - total + TITLE_SPACING) * 0.5, TITLE_TOP * s + _title_font.get_ascent(font_size))
		var spots: Array[Vector2] = []
		for wd in widths:
			spots.append(at)
			at.x += wd + TITLE_SPACING
		for i in title.length():     # 先整排描边、再整排填字（后一个字的描边不压前一个字）
			draw_string_outline(_title_font, spots[i], title[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TITLE_OUTLINE, TITLE_OUTLINE_COLOR)
		for i in title.length():
			draw_string(_title_font, spots[i], title[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TITLE_COLOR)
	var bar := Rect2(mid.x - BAR_W * 0.5, mid.y + 20, BAR_W, BAR_H)
	draw_rect(bar, Color(DIM, 0.35))
	draw_rect(Rect2(bar.position, Vector2(BAR_W * progress, BAR_H)), FG)
	if _body_font != null:
		var note := String(WORDS[lang]["failed"] if failed else WORDS[lang]["loading"])
		draw_string(_body_font, Vector2(0, bar.end.y + 30), note, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, DIM)


## 画铺满屏幕、四边各多出屏宽 [constant BACKDROP_BLEED]（同主菜单那层的起点），按比例、多的裁到屏外
static func cover_rect(tex_size: Vector2, screen: Vector2) -> Rect2:
	var m := screen.x * BACKDROP_BLEED
	var box := Rect2(-m, -m, screen.x + 2.0 * m, screen.y + 2.0 * m)
	var k := maxf(box.size.x / tex_size.x, box.size.y / tex_size.y)
	var drawn := tex_size * k
	return Rect2(box.get_center() - drawn * 0.5, drawn)


## 打包的字体；不在就用引擎默认（不崩）
## the language saved in the settings file; anything unreadable is "zh"
static func read_lang(path: String = SETTINGS) -> String:
	if not FileAccess.file_exists(path):
		return "zh"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var l := String((data as Dictionary).get("language", "zh")) if data is Dictionary else "zh"
	return l if WORDS.has(l) else "zh"


static func _font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path) as Font
	return ThemeDB.fallback_font
