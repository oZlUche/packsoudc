## 150 补 1（作者定）：147 的腰带做成地图屏上的一件组件 —— 一条 1 × N 的格子，随布局摆。
##
## 双击里面一件 = 用掉（同背包里的腰带，走 [method GameFlow.use_belt]；用不了的原因写在提示行）。
## 自带一层拖拽：腰带里的拖出去放哪落在地上哪；背包没开时地上的东西也能拖进来（背包开着时地上归背包那层）。
## 这一局没装腰带模块 = 空着（布局里写了也不报错，平时藏着）
extends HudWidget

var view: InventoryView = null
var drag: DragLayer = null


func title() -> String:
	return "腰带"


func setup(p_run: RunState, p_screen: Control) -> void:
	var belt := BeltModule.of(p_run)
	if view == null and belt != null and belt.belt != null:
		_text.visible = false
		view = InventoryView.new()
		view.label_font = p_screen.get("font") if p_screen != null else null
		view.inventory = belt.belt
		view.show_adjacency = false
		add_child(view)
		view.item_double_clicked.connect(func(_v: ContainerView, uid: int): use(uid))
		drag = DragLayer.new()
		drag.label_font = view.label_font
		add_child(drag)
		drag.register_view(view)
		drag.stash = p_run.storage
		drag.drop_outside_to_stash = true
		var ground := GroundLayer.current()
		if ground != null and ground.stash == p_run.storage:
			drag.register_view(ground)
	super.setup(p_run, p_screen)


func has_content() -> bool:
	return view != null


func text_of() -> String:
	return "腰带" if view != null else ""


## 用掉腰带里的一件。返回用不了的原因（空串 = 用了）
func use(uid: int) -> String:
	var inst := view.inventory.get_item(uid) if view != null else null
	var name := Names.of_item(inst) if inst != null else ""
	var flow: Variant = screen.get("flow") if screen != null else null
	var why: String = flow.use_belt(uid) if flow != null else run.hooks.belt_use(uid)
	if screen != null and screen.has_method("say"):
		screen.call("say", "「%s」现在用不了：%s" % [name, why] if why != "" else "用了「%s」" % name)
	return why
