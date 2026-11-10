## 两座天平（256 求饶的 [BalanceScale]、290 商店的 [ShopScale]）同一套拆法与版式键：横梁绕 pivot 转，两只盘只平移、挂在梁的钩上，一枚金币按摞堆。
## 这里是两边一样的那几样（版式里的框、钩与盘的位置、一只盘画几枚金币）；倾角怎么算、画什么各管各的
class_name PanScale
extends Control

var _lay: Dictionary = {}


## 底座上某个控件的框（`controls` 里的名字：title / status / subtitle / stepper / deal / refuse / hint）
func control_rect(p_name: String) -> Rect2:
	return _rect((_lay.get("controls", {}) as Dictionary).get(p_name, [0, 0, 0, 0]))


## 横梁斜几度（正 = 左盘低）：两座天平各算各的
func tilt_degrees() -> float:
	return 0.0


## 两只钩（梁两端）在舞台上的位置：[左, 右]。美术的倾角正 = 右盘沉，所以这里取 tilt_degrees 的反号
func hooks() -> Array[Vector2]:
	var pivot := _v(_lay["pivot"])
	var a := deg_to_rad(-tilt_degrees())
	var arm := float(_lay["arm"])
	var dy := float(_lay["hook_dy"])
	return [pivot + Vector2(-arm, dy).rotated(a), pivot + Vector2(arm, dy).rotated(a)] as Array[Vector2]


## 盘层左上角：[左, 右]
func pan_origins() -> Array[Vector2]:
	var h := hooks()
	var hook_in := _v(_lay["hook_in_pan"])
	return [h[0] - hook_in, h[1] - hook_in] as Array[Vector2]


## 一只盘里画几枚金币：ceil(一摞摞堆满的枚数 × 金币 / 总价)，放了钱就至少 1 枚，封顶 order 的长度（每摞堆满）
func _pile(coins: int, total: int) -> int:
	var pile: Dictionary = _lay.get("coin_pile", {})
	if coins <= 0 or pile.is_empty():
		return 0
	var full := 0
	for h in pile["full"]:
		full += int(h)
	return clampi(ceili(float(full) * coins / float(maxi(1, total))), 1, (pile["order"] as Array).size())


static func _v(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


## json 里的框是 [左, 上, 右, 下]
static func _rect(a) -> Rect2:
	return Rect2(float(a[0]), float(a[1]), float(a[2]) - float(a[0]), float(a[3]) - float(a[1]))
