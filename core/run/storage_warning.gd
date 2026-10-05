## 离开一个点时地上留下了什么，写成一句话（地图日志用）。
##
## 109（作者定）：087 起地上按点保留，离开不再弹提示；原来的提醒档位（有就提 / 稀有度 / 价值 / 从不）随之删掉，只留这句描述
class_name StorageWarning
extends RefCounted


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
