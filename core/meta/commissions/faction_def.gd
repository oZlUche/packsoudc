## 336（阵营与委托 W0，报告 335 第三节）：营地委托簿里的一方（军团接应队、协会考据所、灰灯互助会、元老院使团、北境猎盟）。
## 声望四级（陌生 / 熟面 / 受托 / 代言）的名字五方相同，在字表里（`commission.tier_<n>`）；这里只放每方自己的东西。
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
## 四级的声望门槛（陌生、熟面、受托、代言），从小到大、第一个是 0
@export var thresholds: Array[int] = [0, 2, 5, 9]
## 每级开放的服务：服务 id → 第几级（0 起）。服务随各方结案批次做，W0 只记表
@export var services: Dictionary = {}
## 联系人 NPC（可空）
@export var contact: StringName = &""
