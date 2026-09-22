## 货币（架构文档 6.6，M4-5）：一局之内的钱。打赢了进账，商店、刷新、付费撤离点花它。
##
## 和 [Vitality] 一个做法：[b]本类不知道任何数值[/b]。赢一场给多少、一件卖多少、撤离收多少，
## 全由调用方从 [EconomyRules] 里拿了传进来。这里只管加、减、够不够，以及发信号。
class_name Wallet
extends RefCounted

## delta 是**实际**变化量
signal changed(balance: int, delta: int, reason: StringName)

var balance: int = 0


func _init(p_balance: int = 0) -> void:
	balance = maxi(0, p_balance)


func can_afford(amount: int) -> bool:
	return amount <= balance


## 进账。负数按 0
func earn(amount: int, reason: StringName = &"") -> int:
	var delta := maxi(0, amount)
	if delta == 0:
		return 0
	balance += delta
	changed.emit(balance, delta, reason)
	return delta


## 花钱。不够就一分不动、返回 false —— 没有「透支一部分」这回事
func spend(amount: int, reason: StringName = &"") -> bool:
	if amount < 0 or not can_afford(amount):
		return false
	if amount == 0:
		return true
	balance -= amount
	changed.emit(balance, -amount, reason)
	return true


func to_dict() -> Dictionary:
	return {"balance": balance}


static func from_dict(d: Dictionary) -> Wallet:
	return Wallet.new(int(d.get("balance", 0)))
