## 157 补充三（作者定：「让每个界面（框）在一块完整的石板上显示」）：一整块石板的底，两层画 ——
## 下层板身（`slab_body.png`，**平铺**，纹理不随板的大小被拉花），上层板边（`slab_edge.png`，九宫格、中心透明：手凿的外轮廓、受光的棱、
## 底边投影、顶上一道刻线当标题线）。一个 StyleBox 画两层，叠层框、底屏的大板、顶端栏都按主题变体挂它，各处不用自己叠子节点
class_name SlabStyle
extends StyleBox

## 板身（平铺的纹）
var body: StyleBoxTexture = null
## 板边（九宫格，四角原样、四边拉伸）
var edge: StyleBoxTexture = null
## 板身比外框往里缩多少（板边轮廓外沿的缺口透出底下的暗处，不透板身；`slab_edge.json` 的 `body_inset`）
var body_inset: float = 0.0
## 顶边藏掉多少（板边往上画出去这么多）：贴着屏幕顶的顶端栏（166）不画顶棱与标题刻线，只露左右与底下的边
var top_cut: float = 0.0


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if body != null:
		var b := rect.grow(-body_inset)
		if top_cut > 0.0:
			b = Rect2(b.position.x, rect.position.y, b.size.x, b.end.y - rect.position.y)
		body.draw(to_canvas_item, b)
	if edge != null:
		edge.draw(to_canvas_item, Rect2(rect.position.x, rect.position.y - top_cut, rect.size.x, rect.size.y + top_cut))
