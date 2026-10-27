## 261 补充一（作者 16:37）：书架一格里的物件按进度分五档，越往后越满 —— 一条规则管所有分档的格。
## 补充二（作者 17:09）：只有图鉴 / 成就 / 科技三格分档，图名在 `home/shelf/layout.json` 的 `tiers`（`<格>_t<档>`），缺图退 t0（[ShelfView]）
class_name ShelfCell
extends RefCounted

const TIERS := 5


## 进度 → 档：clampi(floori(done × 5 / total), 0, 4)；total 为 0 时 t0
static func tier_of(done: int, total: int) -> int:
	if total <= 0:
		return 0
	return clampi(floori(float(done) * TIERS / float(total)), 0, TIERS - 1)

