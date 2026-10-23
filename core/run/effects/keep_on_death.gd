## 2026-10-22（作者定）：战败时保住钱包里剩的钱的百分之几 —— 行囊科技用它。
##
## 原来是 [StartingFundsBonus]「开局白送一笔钱」，钱改成玩家自己带之后那条水源断了，
## 于是换成风险减免：带得多回得多，但行囊让你亏得少一点。不造钱 —— 退的还是你自己带进来的那笔。
##
## 口径：按**战败那一刻 wallet 里剩的**算（不是带进来的原始金额）。中途在商店花掉的钱已经花掉了，
## 按原始金额退等于把花掉的也退回来，那是凭空造钱。
class_name KeepOnDeath
extends RunEffect

## 保住几成（20 = 20%）
@export var percent: int = 0


func modify(ctx: RunContext) -> void:
	ctx.death_refund_percent = maxi(ctx.death_refund_percent, percent)     # 多个来源取最高的那档，不叠加


func describe() -> String:
	return UiText.t("bonus.keep_on_death") % percent
