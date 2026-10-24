## 标签的定义（096，作者定）：道具 / 敌人身上的标签（`weapon` / `metal` / `fire`……）不再只是一个字符串 ——
## 它的名字、别的语言的名字和一句说明都是**数据**，走内容管线（`data/authoring/tags/*.json` → `data/tags/*.tres`）。
##
## 为什么是数据而不是 [Glossary] 里的一张表：标签是 MOD 作者随手加的东西（道具上写一个新词就有了），名字与说明得跟着内容走、
## 能在编辑器里改、能加语言（`display_names["en"]`，和道具名的 [Names.of] 同一条路）。代码里只剩 id。
## 171：道具上没登记的标签导入时报错（`faith:<id>` 这类动态标签除外），界面上显示原词。
class_name TagDef
extends Resource

## 标签本身（道具 `tags` 里写的那个词）。`faith:<id>` 这类动态标签不在这里登记
@export var id: StringName = &""
## 中文名（作者写的原文）
@export var display_name: String = ""
## 别的语言的名字，`{"en": "Weapon"}`；界面用 [method Names.of] 取
@export var display_names: Dictionary = {}
## 一句说明（悬浮窗的词条侧窗用）。空 = 没有词条
@export_multiline var description: String = ""
## 别的语言的说明，`{"en": "..."}`；[method Names.description_of] 取
@export var descriptions: Dictionary = {}
## 107（作者定）：要不要给这个标签在悬浮窗里**弹词条**。
##
## false = 不进侧窗、主文字里也不标色（标了色玩家就会去找解释，找不到比没有更糟）——
## 「近战」「武器」「材料」这类一看就懂的词都是 false。**说明文字照样保留**：
## 编辑器的词典、文档、将来的图鉴照用，标签行也照样列出名字。
@export var tip: bool = true
## 171（作者定 2026-10-14）：大类 —— 标签不是道具随手写的，得先在标签制作器里建、归一类。
## 250（作者定 2026-10-24）：四个给玩家看的轴 + 内部轴 ——
## 类别 kind（每件**恰好一个**，包免）/ 属性 element / 本源 source（工艺 · 自然 · 魔法）/ 归属 affiliation（`faith:<神>`、兽材、阵营）/ 内部 internal。
## 悬浮窗标签行每轴**最多列一个**（按道具里写的先后取第一个），内部不列。材质不是标签（[member ItemDef.material]）。空 = 没归类（导入器报错）
@export_enum("kind", "element", "source", "affiliation", "internal") var category: String = ""
## 107 后续（作者定 2026-10-03）：**内部标签** —— 只给内容逻辑用（敌人的流派 `schools`、身份标签 `item_tags` 按它圈武器），
## 玩家在哪儿都看不到：道具悬浮窗的标签行不列它、也不弹词条。快攻 / 重击 / 重型就是这种 ——
## 那是武器的特色，不该当标签给玩家看；但删了敌人就组不出装，所以留着、藏起来。编辑器照常显示
@export var internal: bool = false
## 193（作者「未来计划把标签文字换成图标」）：图标 —— `assets/ui/tags/` 下的文件名（不含扩展名）；空 = 用 id。
## 文件不在就没图（[method TagRegistry.icon_path] 给空串），界面照旧写字
@export var icon: String = ""
