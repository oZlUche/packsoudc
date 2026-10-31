## 悬停小提示 B（作者 2026-10-31 16:05）：控件自带的 tooltip_text 不再挂在鼠标右下（会盖住下一行的数），
## 而是出在被悬停的那块正上方、居中；上面放不下就放正下方；左右顶到屏边就贴边。
## 大块的控件（高过 [constant BIG_H]，比如铁匠铺整块台面）对着鼠标：鼠标正上方居中。
## 引擎每次弹提示都新建一个 TooltipPanel 窗，挂在提示的主人（有 tooltip_text 的那个控件）底下 —— 这里接住它、等它摆好再挪。
## 不是自动加载：[GameDirector] 装主题时 [method install] 一次（接到树的 node_added 上）。
## 道具 / 节点的大悬浮窗是游戏自己的面板（[constant UiTheme.PANEL_TOOLTIP]），不经过这里。
class_name TipAnchor
extends RefCounted

## 小牌和被悬停那块之间留的缝（设计像素）
const GAP := 4.0
## 比这还高的控件按鼠标摆（不然小牌离鼠标太远）
const BIG_H := 240.0


## 接到 [param tree] 上（重复调用不重复接）
static func install(tree: SceneTree) -> void:
	if tree != null and not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


static func installed(tree: SceneTree) -> bool:
	return tree != null and tree.node_added.is_connected(_on_node_added)


static func _on_node_added(n: Node) -> void:
	var w := n as Window
	if w == null or w.theme_type_variation != &"TooltipPanel":
		return
	w.visibility_changed.connect(_place.bind(w))


## 被悬停那块在嵌窗的视口里的框（和提示窗的 position 同一套坐标：设计像素，带 CanvasLayer 偏移）
static func owner_rect(c: Control) -> Rect2:
	return c.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, c.size)


## 小牌该摆在哪（左上角）：[param r] 被悬停那块，[param size] 小牌大小，[param vr] 能摆的范围，[param mouse] 鼠标（大块控件用）
static func spot(r: Rect2, size: Vector2, vr: Rect2, mouse: Vector2) -> Vector2:
	if r.size.y > BIG_H:
		r = Rect2(mouse, Vector2.ZERO)
	var p := Vector2(r.get_center().x - size.x * 0.5, r.position.y - size.y - GAP)
	if p.y < vr.position.y:
		p.y = r.end.y + GAP
	p.x = clampf(p.x, vr.position.x, maxf(vr.position.x, vr.end.x - size.x))
	p.y = clampf(p.y, vr.position.y, maxf(vr.position.y, vr.end.y - size.y))
	return p


static func _place(w: Window) -> void:
	if not is_instance_valid(w) or not w.visible:
		return
	var c := w.get_parent() as Control
	if c == null or not w.is_embedded():
		return
	var vp := c.get_viewport()
	var p := spot(owner_rect(c), Vector2(w.size), vp.get_visible_rect(), vp.get_mouse_position())
	w.position = Vector2i(p.round())
