## 一切物品容器的根。
##
## 抽出来是因为容器分成了**两类**，而拖拽层要同时对付它们：
##
## [codeblock]
## ItemContainer
##   GridInventory  空间容器：棋盘、敌人尸体、商店货架 —— 摆在哪儿是有意义的
##   ItemStash      列表容器：地上 —— 只是「先放着」，位置不承载任何信息
## [endcodeblock]
##
## 基类只收两样东西：**变更通知**与**按 uid 取放**。空间语义（占格、旋转、包体覆盖）
## 全在 [GridInventory] 里，列表容器一个字都不认识 —— 硬凑一个「格子数为 1」的
## 空间容器来表示列表，等于逼着每一处调用都去处理一堆没有意义的坐标。
##
## 本类是纯 [RefCounted]，不进场景树。表现层连 [signal changed] 后
## [b]从状态完整重建视图[/b]，不要做增量猜测。
@abstract
class_name ItemContainer
extends RefCounted

## 内容发生任何变化时发出。批量操作期间会被合并成一次。
signal changed

var id: int = 0

var _batch_depth: int = 0
var _dirty: bool = false


#region 批量操作
## 成对使用，把区间内的多次改动合并成一次 [signal changed]。
## 跨容器移动必须用它包起来，否则 UI 会看到「已从源移除、尚未放入目标」的中间态。
func begin_batch() -> void:
	_batch_depth += 1


func end_batch() -> void:
	_batch_depth = maxi(0, _batch_depth - 1)
	if _batch_depth == 0 and _dirty:
		_dirty = false
		changed.emit()


## 175：容器里某件的 `state` 改了（附魔）：发一次 [signal changed]，界面与编译跟着刷新
func touch() -> void:
	_notify_changed()


func _notify_changed() -> void:
	if _batch_depth > 0:
		_dirty = true
	else:
		changed.emit()
#endregion


#region 子类必须实现
@abstract func get_item(uid: int) -> ItemInstance

@abstract func has_item(uid: int) -> bool

## 全部物品。顺序必须稳定 —— 战斗编译结果、存档、界面重建都以它为输入。
@abstract func items() -> Array

@abstract func item_count() -> int

## 移除并返回该实例；不存在或拒绝移除时返回 null。
@abstract func remove(uid: int) -> ItemInstance

## 「随便给它找个地方放下」。空间容器会去扫空位，列表容器直接追加。
##
## 这是跨容器搬运唯一需要的共同动作：调用方说不出网格坐标，
## 也不该为了塞一件东西去了解目标容器的空间规则。
@abstract func admit(inst: ItemInstance) -> bool

## [method admit] 会不会成功，**不改任何状态**。
##
## 搬运必须先问这一句再动手：先 remove 再发现目标收不下，就得把东西塞回源容器，
## 而「塞回原位」在空间容器里未必还办得到（刚腾出来的格子可能已经被别的东西用了）。
## 先问后动，源容器连碰都不用碰。
@abstract func can_admit(def: ItemDef) -> bool
#endregion
