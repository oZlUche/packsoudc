## 150：货币
extends HudWidget


func title() -> String:
	return "货币"


func watch() -> Array[Signal]:
	return [run.wallet.changed] as Array[Signal]


func text_of() -> String:
	return "货币 %d" % run.wallet.balance
