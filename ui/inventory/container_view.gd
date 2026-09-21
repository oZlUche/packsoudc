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


@abstract func container() -> ItemContainer


## 擦掉落点预览。拖拽层会对**所有**已注册视图调用它，所以不能假设自己正在显示预览。
func clear_preview() -> void:
	pass
