## 一切容器视图的根，让 [DragLayer] 能同时对付网格与列表。
##
## 拖拽层只需要三件事：**谁被按下了**、**背后是哪个容器**、**把预览擦掉**。
## 落点长什么样（网格是一片染色的格子，列表是一条插入线）由各自的子类决定 ——
## 硬把两种预览统一成一个签名，只会得到一个两边都用不顺的参数表。
@abstract
class_name ContainerView
extends Control

## 某件物品被按下，请求开始拖拽。[param local_pos] 为本控件内的像素坐标。
signal grab_requested(view: ContainerView, uid: int, local_pos: Vector2)
## 084：双击了一件（快速置入：棋盘 ⇄ 容器 / 地上，由持有这个视图的屏决定去哪）。双击时不发 grab_requested
signal item_double_clicked(view: ContainerView, uid: int)
## 099：右键按在一件上（没在拖的时候）。230：悬浮窗接它 —— 立刻钉住这件的窗、展开按钮（信物奉为主信仰改成按钮）
signal item_context(view: ContainerView, uid: int)

## 230：这一屏在这块视图上给道具的操作按钮 `func(uid) -> Array[ItemActions.Action]`（[HoverTip] 画在脚注下面）；没设 = 没按钮
var actions_for: Callable = Callable()


## 087（作者定）：**道具这个实体本身就有悬浮窗** —— 任何容器视图进树之后自己找（或造）一个 [HoverTip] 登记上去：
## 仓库、结算屏、开局屏、商店栏位……停在道具上都能看属性。关掉就自己管（false）
@export var auto_tooltip: bool = true


func _ready() -> void:
	if auto_tooltip:
		# 等祖先都进了树再找。用具名方法而非 lambda：视图若在下一帧前被 free，引擎会直接丢掉这次延迟调用；
		# lambda 捕获的 self 在对象释放后可能指向别的对象（全量测试里曾收到 CombatProfile）
		_attach_tooltip.call_deferred()


func _attach_tooltip() -> void:
	if is_inside_tree():
		HoverTip.ensure_for(self)


@abstract func container() -> ItemContainer


## 一件画在哪（本控件内像素的外框）；作者 10-26：悬浮窗贴着它摆。给不出 = 空（悬浮窗照鼠标摆）
func item_rect(_uid: int) -> Rect2:
	return Rect2()


## 擦掉落点预览。拖拽层会对**所有**已注册视图调用它，所以不能假设自己正在显示预览。
func clear_preview() -> void:
	pass
