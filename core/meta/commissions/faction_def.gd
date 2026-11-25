## 336（阵营与委托 W0，报告 335 第三节）：营地委托簿里的一方（军团接应队、协会考据所、灰灯互助会、元老院使团、北境猎盟）。
## 报告 389（作者 2026-11-24）：不再有五档，每一方一串自己的声望节点（[member nodes]）：声望到了那个数，触发那个效果。
##
## 走内容管线：`data/authoring/factions/*.json` → `data/factions/*.tres`（[method Commissions.factions]）
class_name FactionDef
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
## 别的语言的名字（`{"en": "..."}`，[Names]）
@export var display_names: Dictionary = {}
## 委托簿左列的先后（小的在上）
@export var order: int = 0
## 委托簿里列不列出来。首版只列军团、协会、灰灯，另两方等 W3（不放「待开放」）
@export var listed: bool = true
## 342 B3：什么时候来营地（空 = 一开始就在；`first_run` = 教程后第一次正式探索结算时，[method Commissions.arrive]）
@export var arrives: StringName = &""
## 377：`arrives` = `extractions` 时，教程之后第几次成功撤离（正式探索）结算时来
@export var arrive_after: int = 0
## 报告 389：声望节点，一个节点 = 一个声望数 + 一个效果（[method Commissions.nodes_of] 按声望排好）。每个节点：
## - `id`：这一方里不重复（通知按它记，[member CommissionBook.node_news]）
## - `rep`：要多少声望
## - `kind`：`open` 开放 / `boost` 提升
## - `effect`：效果 id（[constant Commissions.EFFECTS]），`value`：效果的参数（神 id、委托 id、尺寸、折损……）
## - `placeholder`：占位（刻度上看得见、显示「？？？？」，到了也不生效）；`hidden`：没到之前显示「？？？？」
@export var nodes: Array[Dictionary] = []
## 报告 389 第七节（作者 11-24 16:49「不要写死」）：这一方声望每攒多少，【赠礼】多一份（现在各方都写 25；0 = 这一方没有赠礼）
@export var gift_every: int = 0
## 报告 389 第八节（作者 11-25 19:02 选调高，数由架构定、可改）：这一方告示栏纸条每份给多少声望（各方现在写 3）
@export var note_rep: int = 1
## 报告 389 第七节：【赠礼】一份从这几样里随机给一样（作者 11-24 16:49）：每条 `{"funds": 金币}` 或 `{"item": 道具 id, "count": 件数}`。内容等作者挑，现在是占位
@export var gift_pool: Array[Dictionary] = []
## 342 B2：这一方的剧情开放哪些基地设施：设施 id（`smithy` / `tech` / `market`）→ 开它的那份剧情委托 id
@export var facilities: Dictionary = {}
## 联系人 NPC（可空）
@export var contact: StringName = &""
## 342 B2：许可单（办完它、又到了结案那个节点，常规委托才开；空 = 只看声望）
@export var permit: StringName = &""
## 342 B2：告示栏上这一方的数量模板 [{"goal", "params", "u": 单份酬值, "name": 纸条名, "text": 做什么（{n} = 件数）}]（[NoticeBoard]）
@export var regular: Array[Dictionary] = []
