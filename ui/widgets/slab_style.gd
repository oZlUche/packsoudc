## 157 补充三（作者定：「让每个界面（框）在一块完整的石板上显示」）：一整块石板的底，两层画 ——
## 下层板身（`slab_body.png`，**平铺**，纹理不随板的大小被拉花），上层板边（`slab_edge.png`，九宫格、中心透明：手凿的外轮廓、受光的棱、
## 底边投影、顶上一道刻线当标题线）。一个 StyleBox 画两层，叠层框、底屏的大板按主题变体挂它；顶端栏（166）换一张专用的长条板边 `slab_bar.png`（顶上贴屏幕、没有标题刻线），板身同一张，各处不用自己叠子节点
class_name SlabStyle
extends StyleBox

## 板身（平铺的纹）
var body: StyleBoxTexture = null
## 板边（九宫格，四角原样、四边拉伸）
var edge: StyleBoxTexture = null
## 板身比外框往里缩多少 [左, 上, 右, 下]（板边轮廓外沿的缺口透出底下的暗处，不透板身；板边 json 的 `body_inset`，
## 一个数 = 四边一样，四个数 = 各边分开 —— 顶端栏那条板顶上贴着屏幕，顶边不缩）
var body_inset: Array = [0.0, 0.0, 0.0, 0.0]


## json 里的 `body_inset`：数 → 四边一样；[左, 上, 右, 下] → 各边；别的当 0
static func inset_of(v: Variant) -> Array:
	if v is float or v is int:
		return [float(v), float(v), float(v), float(v)]
	if v is Array and (v as Array).size() == 4:
		return (v as Array).map(func(x: Variant) -> float: return float(x))
	return [0.0, 0.0, 0.0, 0.0]


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if body != null:
		body.draw(to_canvas_item, rect.grow_individual(-body_inset[0], -body_inset[1], -body_inset[2], -body_inset[3]))
	if edge != null:
		edge.draw(to_canvas_item, rect)
