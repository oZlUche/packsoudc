## 离开一个点时暂存区里的东西要不要提醒（3.4 / 058 第 3 条）：按 [GameSettings] 的档位挑出值得提的那些。
##
## 提示不是挽留：这里只回答「提不提、提哪些」，走不走是玩家的事。纯逻辑，界面拿结果画面板。
class_name StorageWarning
extends RefCounted


## 值得提醒的那些；空 = 不用提
static func at_risk(items: Array, s: GameSettings) -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	if s == null:
		s = GameSettings.new()
	for inst in items:
		var item := inst as ItemInstance
		if item == null or item.def == null:
			continue
		match s.storage_warn_mode:
			&"never":
				pass
			&"rarity":
				if item.def.rarity >= s.storage_warn_rarity:
					out.append(item)
			&"value":
				if ItemValue.of(item.def) >= s.storage_warn_value:
					out.append(item)
			_:
				out.append(item)
	return out


static func should_warn(items: Array, s: GameSettings) -> bool:
	return not at_risk(items, s).is_empty()


## 一句话：几件、值多少、几件稀有以上
static func describe(items: Array) -> String:
	var value := 0
	var rare := 0
	for inst in items:
		var item := inst as ItemInstance
		if item == null or item.def == null:
			continue
		value += ItemValue.of(item.def)
		if item.def.rarity >= 2:
			rare += 1
	return "%d 件，值 %d 币%s" % [items.size(), value, "，其中 %d 件稀有以上" % rare if rare > 0 else ""]
