## 180 补三（作者 2026-10-17 11:22）：开局屏第三页的难度翻页计数器 —— 黑底白字的一块牌（外面那圈黄铜框是 [constant UiTheme.PANEL_FLIP_COUNTER]），
## 换数时翻一页：「＋」旧页从下往上翻过去，「−」从上往下。牌面以中线为轴拆成上下两半，各是一块裁边的 Control，
## 里面放同一个数字的整块 Label（下半那份往上挪半个牌高）；翻页只是两半依次 `scale.y`，不用着色器。
## 底下那层 [member label] 换数时立刻是新数（测试不用等）。
## 180 定稿：有图时牌面是一张翻页卡（`diff_flip_card`，在最下）、数字、中缝（`diff_flip_split`，盖在最上）；半页的底也是卡
class_name FlipCounter
extends Control

## 每半页翻多久（两段共 0.32 秒，按演示页）
const HALF_SEC := 0.16
## 牌面最窄多宽（Ⅷ 这种宽字也放得下，换数时牌不变宽窄）
const MIN_WIDTH := 120.0

## 牌面最小多大（难度块按外框图的窗口给；不给 = [constant MIN_WIDTH] × 字高）
var min_size := Vector2(MIN_WIDTH, 0.0):
	set(v):
		min_size = v
		_fit()
## 底层：现在的数
var label: Label = null
## 翻页卡与中缝（没图 null）
var _card: Control = null
var _split: Control = null
## 上一次往哪翻（+1 =「＋」从下往上，-1 =「−」从上往下，0 = 没翻过；测试看）
var last_dir: int = 0
var _tween: Tween = null
## 翻页时盖在上面的几块半页
var _leaves: Array[Control] = []


func _init() -> void:
	_card = _face()
	if _card != null:
		_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_card)
	label = UiTheme.make_variant_label("", UiTheme.LABEL_FLIP_NUM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(label)
	label.minimum_size_changed.connect(_fit)
	_split = _nine(UiTheme.ART_FLIP_SPLIT)
	if _split != null:
		_split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_split)
	_fit()


## 一张九宫格图（翻页卡、中缝同尺寸同拉伸，边距读 `diff_flip.json`）；没图 null
static func _nine(art_name: String) -> NinePatchRect:
	var tex := UiTheme.art(art_name)
	if tex == null:
		return null
	var m: Array = UiTheme.art_meta("setup/diff_flip").get("margin", [16, 16, 16, 16])
	var n := NinePatchRect.new()
	n.texture = tex
	n.patch_margin_left = int(m[0])
	n.patch_margin_top = int(m[1])
	n.patch_margin_right = int(m[2])
	n.patch_margin_bottom = int(m[3])
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n


## 翻页卡（没图 null）
static func _face() -> Control:
	return _nine(UiTheme.ART_FLIP_CARD)


func _fit() -> void:
	var m := label.get_combined_minimum_size()
	custom_minimum_size = Vector2(maxf(min_size.x, m.x), maxf(min_size.y, m.y))


## 换成 [param text]。[param dir]：+1 往上翻、-1 往下翻、0 不翻；[param animate] 假（换屏淡入关着、不在树里）就直接换
func set_value(text: String, dir: int = 0, animate: bool = true) -> void:
	if text == label.text:
		return
	var old := label.text
	label.text = text
	_clear_leaves()
	if dir == 0 or not animate or not is_inside_tree() or size.y <= 0.0:
		return
	last_dir = signi(dir)
	# 「＋」：上半旧页先盖着，下半旧页往上折到中线，再由上半新页从中线往上翻下来盖住旧的上半；「−」上下对调
	var up := dir > 0
	var stay := _leaf(old, up)
	var going := _leaf(old, not up)
	var coming := _leaf(text, up)
	coming.scale.y = 0.0
	_tween = create_tween()
	_tween.tween_property(going, ^"scale:y", 0.0, HALF_SEC).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(coming, ^"scale:y", 1.0, HALF_SEC).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_callback(_clear_leaves)
	_leaves = [stay, going, coming]


## 正在翻（测试看）
func flipping() -> bool:
	return not _leaves.is_empty()


## 半页：[param top] 真 = 上半。裁边的一块，轴在中线上
func _leaf(text: String, top: bool) -> Control:
	var half := Control.new()
	half.clip_contents = true
	half.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := size.y * 0.5
	half.position = Vector2(0.0, 0.0 if top else h)
	half.size = Vector2(size.x, h)
	half.pivot_offset = Vector2(size.x * 0.5, h if top else 0.0)
	var face := _face()     # 半页自己的底，翻的时候盖住底层：有卡图是整张卡（下半那份往上挪半个牌高），没有是平色黑
	if face != null:
		face.position = Vector2(0.0, 0.0 if top else -h)
		face.size = size
	else:
		var flat := ColorRect.new()
		flat.color = UiTheme.FLIP_FACE
		flat.size = half.size
		flat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face = flat
	half.add_child(face)
	var copy := UiTheme.make_variant_label(text, UiTheme.LABEL_FLIP_NUM)
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	copy.position = Vector2(0.0, 0.0 if top else -h)
	copy.size = size
	half.add_child(copy)
	add_child(half)
	if _split != null:
		move_child(_split, -1)     # 中缝永远在最上
	return half


func _clear_leaves() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	for leaf in _leaves:
		if is_instance_valid(leaf):
			leaf.queue_free()
	_leaves.clear()
