## 336（W0，报告 335 第三节）：一份具名委托或一种可重复模板。
##
## 档位（[member tier]）定接取要几级声望、给多少声望（[method Commissions.required_tier]、[method Commissions.default_reputation]）：
## 入门 +1（陌生就能接）、调查 +2（熟面）、结案 +3（受托，且前置齐备）；模板（告示栏纸条）最多把一方推到信赖。
##
## 走内容管线：`data/authoring/commissions/*.json` → `data/commissions/*.tres`（[method Commissions.defs]）
class_name CommissionDef
extends Resource

const INTRO := &"intro"
const INQUIRY := &"inquiry"
const FINALE := &"finale"
const TEMPLATE := &"template"
const TIERS: Array[StringName] = [INTRO, INQUIRY, FINALE, TEMPLATE]

@export var id: StringName = &""
## 委托名（方案里的书名号里那几个字）
@export var display_name: String = ""
@export var display_names: Dictionary = {}
## 所属阵营（[FactionDef] 的 id）
@export var faction: StringName = &""
## 同一方里的先后（小的在上）
@export var order: int = 0
## intro / inquiry / finale / template
@export var tier: StringName = INTRO
## 完成给几点声望（0 = 按档位默认，[method Commissions.reputation_of]）
@export var reputation: int = 0
## 接取要几级（-1 = 按档位，[method Commissions.required_tier]）。原型期《两条回路》提前到陌生可接（同方入门单 W2 才有）
@export var min_tier: int = -1
## 要先完成的委托 id（同一方）
@export var requires: Array[StringName] = []
## 能在哪几章做（空 = 正式版的常规章都行）
@export var chapters: Array[StringName] = []
## 步骤，按顺序
@export var stages: Array[CommissionStage] = []
## 完成时的酬金（金币）与实物（道具 id → 件数）。数值是候选
@export var funds: int = 0
@export var items: Dictionary = {}
## 342 B2：办成后开放的基地设施（`smithy` / `tech` / `market`；342 B3 加 `bias` / `nursery`；空 = 不开）。剧情委托（[member tier] 不是模板）才用
@export var opens: StringName = &""
## 互斥组：同组只能有一份结案（空 = 不互斥）
@export var mutex: StringName = &""
## 委托人原话（方案里加了引号的原样用）
@export var quote: String = ""
@export var quotes: Dictionary = {}
## 「替谁办」那一栏（候选文本）
@export var client: String = ""
@export var clients: Dictionary = {}
