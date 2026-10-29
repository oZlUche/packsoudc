## 265（作者 2026-10-29 16:43）：道具收藏 —— 收藏的是**种类**（道具 id），存在局外 [member MetaState.favorites]；
## 画角标的（[method ItemPainter.draw_favorite]）、悬浮窗右上角的丝带（[HoverTip]）、出售跳过的都从这里问。
## 局外状态由 [GameFlow] 换档时挂上来（[method attach]）；没挂（单独造视图的测试）= 没有收藏，丝带也不画
class_name ItemFavorites
extends RefCounted

## 画收藏角标的控件进这个组：收藏一变整组重画
const GROUP := &"fav_badges"

static var _meta: WeakRef = null


static func attach(meta: MetaState) -> void:
	_meta = weakref(meta) if meta != null else null


static func source() -> MetaState:
	return _meta.get_ref() as MetaState if _meta != null else null


## 有没有局外状态可记（没有 = 丝带不画、角标不画）
static func available() -> bool:
	return source() != null


static func has(id: StringName) -> bool:
	var m := source()
	return m != null and m.is_favorite(id)


## 切一下；返回切完是不是收藏着。画角标的都重画
static func toggle(id: StringName) -> bool:
	var m := source()
	if m == null:
		return false
	var on := m.toggle_favorite(id)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.call_group(GROUP, "queue_redraw")
	return on
