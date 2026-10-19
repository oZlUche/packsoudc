## 197 补充一 §5：主菜单的整屏背景 —— 几张画轮换，每张带一段慢镜头（Ken Burns：慢慢平移 + 推 / 拉）。
##
## 两层 [TextureRect] 叠着（按比例铺满、多的裁掉，中心为轴）：新的一张在上层由透明淡进来，淡完下层就成了下一次换上来的那层。
## 每层比屏幕四边各大 [constant BLEED]，镜头在出血里走，怎么推都不露边。全部用 [Tween]，不改渲染管线；
## 离开菜单（出树）全停，窗口失焦暂停。
class_name MenuBackdrop
extends Control

## 每张停留（含交叉淡化）
const STAY := 14.0
## 交叉淡化
const FADE := 1.5
## 一张里镜头最多走屏宽的这么多
const DRIFT := 0.03
## 推拉的两头
const ZOOM_NEAR := 1.06
const ZOOM_FAR := 1.0
## 每层四边各多出屏宽的这么多（> DRIFT，平移不露边）
const BLEED := 0.05
## 启动屏把第一张压暗到这个亮度；菜单第一次打开从这里亮起来，亮完才开镜头
const BOOT_DIM := 0.4
const BRIGHTEN := 0.8

## 轮换的画（[member UiTheme.asset_root] 下的名字；没图的跳过）
var art_names: Array[String] = []
## 现在是第几张（[member art_names] 里的下标）
var index := 0
## 下一次是推近（1.00 → 1.06）还是拉远（1.06 → 1.00）
var push := true
## 测试看：最近一次的镜头 —— 起止位移（相对屏宽）、起止缩放
var last_move := {}
var _layers: Array[TextureRect] = []
var _textures: Array[Texture2D] = []
var _tweens: Array[Tween] = []
## 每张画上一次平移的方向（同一张再出现时不走回头路）
var _last_dir := {}
var _rng := RandomNumberGenerator.new()
var _running := false


func _init() -> void:
	name = "MenuBackdrop"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 2:
		var pic := TextureRect.new()
		pic.name = "Layer%d" % i
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pic)
		_layers.append(pic)
	resized.connect(_fit_layers)


## 装上画并从第一张开始。[param brighten] = 刚从启动屏过来：先从启动屏那档暗亮起来再开镜头
func start(names: Array[String], brighten: bool = false) -> void:
	art_names.clear()
	_textures.clear()
	for n in names:
		var tex := UiTheme.art(n)
		if tex != null:
			art_names.append(n)
			_textures.append(tex)
	stop()
	index = 0
	if _textures.is_empty():
		return
	_running = true
	_fit_layers()
	var top := _layers[1]
	top.texture = _textures[0]
	top.modulate.a = 1.0
	_layers[0].texture = null
	_reset(top)
	if brighten:
		modulate = Color(BOOT_DIM, BOOT_DIM, BOOT_DIM)
		var tw := _tween()
		tw.tween_property(self, "modulate", Color.WHITE, BRIGHTEN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(_shoot.bind(top))
	else:
		_shoot(top)


## 全停（出树也会调）
func stop() -> void:
	for tw in _tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_tweens.clear()
	_running = false
	modulate = Color.WHITE


## 现在这张的名字（测试看）；没图 ""
func current_name() -> String:
	return art_names[index] if index < art_names.size() else ""


## 在跑的镜头 / 淡化有几段（测试看：出树后是 0）
func live_tweens() -> int:
	return _tweens.filter(func(tw): return tw != null and tw.is_valid() and tw.is_running()).size()


## 立刻换下一张（测试用；正常由每张的镜头到点自己换）
func advance() -> void:
	if not _running or _textures.size() < 2:
		return
	index = (index + 1) % _textures.size()
	var top := _layers[0]     # 下层拿上来
	move_child(top, -1)
	_layers.reverse()
	top.texture = _textures[index]
	top.modulate.a = 0.0
	_reset(top)
	_shoot(top)
	var fade := _tween()
	fade.tween_property(top, "modulate:a", 1.0, FADE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 一张画的一段镜头：起点在中间，走到一个随机终点（不超过屏宽 [constant DRIFT]），推拉交替；
## 走到 [constant STAY] − [constant FADE] 时换下一张（下一张淡进来的那 1.5 s 里这张还在走）
func _shoot(layer: TextureRect) -> void:
	var dir := Vector2.from_angle(_rng.randf() * TAU)
	var last: Vector2 = _last_dir.get(index, Vector2.ZERO)
	if dir.dot(last) < 0.0:
		dir = -dir     # 同一张再出现：不走回头路
	_last_dir[index] = dir
	var drift := dir * size.x * DRIFT
	var from_zoom := ZOOM_FAR if push else ZOOM_NEAR
	var to_zoom := ZOOM_NEAR if push else ZOOM_FAR
	push = not push
	var home := layer.position
	layer.scale = Vector2.ONE * from_zoom
	last_move = {"from": Vector2.ZERO, "to": drift / maxf(size.x, 1.0), "zoom_from": from_zoom, "zoom_to": to_zoom, "art": current_name()}
	var tw := _tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(layer, "position", home + drift, STAY)
	tw.tween_property(layer, "scale", Vector2.ONE * to_zoom, STAY)
	if _textures.size() > 1:
		var next := _tween()
		next.tween_interval(STAY - FADE)
		next.tween_callback(advance)


## 一层摆回起点：比屏幕四边各大 [constant BLEED]，以中心为轴
func _reset(layer: TextureRect) -> void:
	var m := size.x * BLEED
	layer.position = Vector2(-m, -m)
	layer.size = size + Vector2(m, m) * 2.0
	layer.pivot_offset = layer.size * 0.5
	layer.scale = Vector2.ONE


func _fit_layers() -> void:
	var m := size.x * BLEED
	for layer in _layers:
		layer.size = size + Vector2(m, m) * 2.0
		layer.pivot_offset = layer.size * 0.5


func _tween() -> Tween:
	_tweens = _tweens.filter(func(tw): return tw != null and tw.is_valid())
	var tw := create_tween()
	_tweens.append(tw)
	return tw


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EXIT_TREE:
			stop()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			for tw in _tweens:
				if tw != null and tw.is_valid():
					tw.pause()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			for tw in _tweens:
				if tw != null and tw.is_valid():
					tw.play()
