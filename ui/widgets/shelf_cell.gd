## 261 补充一（作者 16:37）：书架一格里的物件按进度分五档，越往后越满 —— 一条规则管所有格（图鉴 / 对局记录 / 特殊道具 / 成就 / 科技）。
## 图名 `home/shelf/<格>_t<档>`（340 × 300，UI替换美术 切件时写进 shelf/layout.json），缺图退 t0，再缺由调用方退占位
class_name ShelfCell
extends RefCounted

const ART := "home/shelf/"
const TIERS := 5


## 进度 → 档：clampi(floori(done × 5 / total), 0, 4)；total 为 0 时 t0
static func tier_of(done: int, total: int) -> int:
	if total <= 0:
		return 0
	return clampi(floori(float(done) * TIERS / float(total)), 0, TIERS - 1)


## 这一格这一档的图：`<格>_t<档>`，没有退 `<格>_t0`；都没有 null
static func art_for(key: String, tier: int) -> Texture2D:
	var t := UiTheme.art_cached("%s%s_t%d" % [ART, key, tier])
	if t == null:
		t = UiTheme.art_cached("%s%s_t0" % [ART, key])
	return t
