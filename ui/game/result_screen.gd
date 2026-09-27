## 结算（M6，架构文档 8 节 / 8.2；058 第 7 条）：撤离了棋盘原样带回来，在这里拖或一键置入仓库；战败什么都没有。
## 账（图鉴、价值、钱）在进这一屏之前就记好了（`GameFlow` 一局结束时 absorb）；「继续」去局外。
extends GameScreen

const WarehousePanelScript := preload("res://ui/game/warehouse_panel.gd")

var _wh = null


func open(payload: Dictionary) -> void:
	var r: RunResult = payload.get("result", flow.result)
	_backdrop()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var col := _vbox(10)
	margin.add_child(col)
	if r == null:
		col.add_child(_label("没有可结算的一局", 18, UiPalette.FG))
		col.add_child(_button("回主菜单", flow.to_main_menu, 14))
		return
	var extracted := r.is_extracted()
	col.add_child(_label("撤离成功" if extracted else "战败", 28, UiPalette.HEAL if extracted else UiPalette.HP))
	col.add_child(_label("%s　种子 %d　%s" % [r.chapter_name, r.run_seed, _reason_text(r.reason)], 13, UiPalette.DIM))
	col.add_child(_label("行动点 %d　踩过 %d 个点　打赢 %d 场　打输 %d 场" % [r.steps, r.visited, r.battles_won, r.battles_lost], 14, UiPalette.FG))
	if extracted:
		col.add_child(_label("背出来 %d 件、值 %d 币、带出 %d 币；图鉴新点亮 %d 条%s" % [
			r.carried.size(), r.value, r.balance, int(flow.last_absorbed.get("lit", 0)),
			"；暂存区里的 %d 件（值 %d 币）留在了里面" % [r.left_behind, r.left_value] if r.left_behind > 0 else ""], 13, UiPalette.DIM))
		col.add_child(HSeparator.new())
		_wh = WarehousePanelScript.new()
		_wh.setup(flow, font)
		col.add_child(_wh)
	else:
		col.add_child(_wrapped("背包、暂存区、钱，全都留在了里面。", 14, UiPalette.FG, 600))
	var next := flow.next_chapter()
	if next != null:
		col.add_child(_wrapped("带回来的东西会进仓库。序章一张接一张：下面直接进「%s」。" % next.display_name, 13, UiPalette.DIM, 600))
		col.add_child(_button("进入下一张：%s" % next.display_name, proceed, 16, UiPalette.Tier.PRIMARY))
	else:
		col.add_child(_button("继续", proceed, 16, UiPalette.Tier.PRIMARY))


## 一键置入（测试直接调）
func store_all() -> Dictionary:
	return _wh.store_all() if _wh != null else {"moved": 0, "left": 0, "stuck": ""}


## 「继续」：有下一张教学图就直接进（085），否则去局外
func proceed() -> void:
	if flow.next_chapter() != null:
		flow.start_next_chapter()
	else:
		flow.finish_result()


func _reason_text(reason: StringName) -> String:
	match reason:
		&"extract":
			return "从撤离点出来"
		&"vitality_depleted":
			return "体力耗尽"
		&"boss_lost":
			return "核心一战失利"
		&"fatal_loss":
			return "输了一场不能输的仗"
		&"boss":
			return "击败了核心的 BOSS，直接撤离"
	return String(reason)
