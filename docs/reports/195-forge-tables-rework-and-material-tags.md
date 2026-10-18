# 195 铸炉三表重做：材质标签补全、十种材质各有一行、攻守两式、五档稀有度

> 2026-10-18 晚，架构设计。承 194 §3.6 的六个方向，作者原话：「铸牌的几个方向都可以做，尤其是第五项，需要让标签对应道具更加繁多，撑起世界观」。
> 本篇是**可直接照抄的数据 + 一小块代码改动**：§2 给 97 件道具每件一个材质标签（三种新标签），§3 按「撑起世界观」补一批候选道具，§4 三张表逐行重写，§5 稀有度五档，§6 代码与测试，§7 待定，§8 派工。
> 本线程只写方案，不改代码；派给「架构方案执行」落数据与代码、「美术设计」出三枚新标签图标。

## 0. 结论先行

| 194 §3.6 的方向 | 本篇怎么做 |
| --- | --- |
| 甲 来源标签兜底行 | 三张表的材质列最后各加 `nature` / `crafted` / `magic` 三行（镜像木 / 金属 / 宝石），放在十个材质行之后、`default` 之前。§2 做完后现有道具一件也落不到它们，是给以后忘打材质标签的道具兜底的 |
| 乙 用途列要有意义 | 时机表：用途除了方向，再乘一个**节奏系数**（武器 ×0.75、盾 ×1、防具 ×1.25）。效果表：用途不再改「给谁」（那会让盾进效果槽变成打自己），改成选**攻式 / 守式**两套效果（武器与其它 = 攻，盾与防具 = 守）。数值表：盾 ×1、防具 ×1.5 |
| 丙 三阶各不相同 | 每个材质行攻守各写满 基础 / 升阶 / 附带 三句，**升阶是加一句不是换一句**（§4.2 规矩），再没有「升阶：没有变化」 |
| 丁 盾与防具不同 | 时机：防具更慢（×1.25）；数值：防具更大（×1.5）；效果：同为守式。盾快而小，防具慢而大 |
| 戊 木 / 血肉行填满、每个标签下道具繁多 | §2：97 件全部挂材质标签，木 11 件、血肉 5 件起；新增织物 / 草药 / 陶瓷三种材质；§3 再补 16 件候选道具把石材、陶瓷、血肉撑到 7 件以上 |
| 己 稀有度分档 | 时机 0–5 六档冷却，效果 0/1 基础、2 升阶、3 升阶 + 附带、4 再 ×1.5、5 再 ×2，数值 0–5 六档 |

## 1. 现状（194 §3 的数字，复述一行）

97 件可用道具里 50 件没有材质标签，全部落到 `default` 行；三张表 7 个材质行里木、血肉两行没有任何道具能到；升阶字段 8 行里 7 行是空的；用途列对多数时机没意义，对效果槽甚至有害（盾进效果槽 = 效果给自己，金属行就成了打自己 3 点）。

## 2. 道具 → 材质标签（97 件，每件恰好一个）

**规矩**：
- 材质类标签（`category: material`）从 7 种加到 **10 种**：金属 `metal`、宝石 `gem`、皮革 `leather`、骨制品 `bone`、石材 `stone`、木制 `wood`、血肉 `flesh`、**织物 `cloth`**、**草药 `herb`**、**陶瓷 `clay`**（三种新标签的 json 在 2.2）。
- **每件道具恰好一个材质标签**。查表按表的行序取道具标签里第一个命中的，两个材质会让结果取决于行序，所以不许两个。
- 来源标签（自然 / 工艺 / 魔法）不动（2026-10-03 的规矩：材料三选一，魔法相关永远是魔法）。
- 「都行」`douxing` 是彩蛋，不挂材质，继续落 `default` 行。
- 封存品（`sealed` 13 件）与铸牌不在池子里，不挂。

### 2.1 分配表

加粗 = 这次新挂（或改挂）的；括号里是稀有度。

| 材质 | 件数 | 道具 |
| --- | --- | --- |
| 金属 `metal` | 29 | 腐蚀香炉(2) 放血刀(2) 黄铜齿轮(2) 剁刀(1) 铜锭(1) 铜矿石(0) 溃烂之刃(3) 鎏金酒杯(3) 铁矿石(1) 匕首(0) 长剑(1) 秘银附魔长剑(3) 铁钉桶(1) 铜油灯(1) 板甲(2) 涂毒匕首(3) 铆钉盒(2) 圆盾(1) 弯刀(1) 制式短剑(1) 银锭(2) 银矿石(2) 钢锭(2) 塔盾(1) 战锤(1) **望远镜(2) 技巧之神的护符(3) 技巧之神赐福的盾牌(3) 灰白色的金属碎片(4，由 gem 改 metal，名字就是金属)** |
| 宝石 `gem` | 8 | 火焰魔晶石(1) 冰霜魔晶石(1) 闪电魔晶石(1) 果果之心(5) 水晶簇(1) 琥珀原石(2) 异化黑曜石(3) **日神的护符(3)** |
| 皮革 `leather` | 8 | 皮革包(1) 生兽皮(1) 嗜血护腕(2) 毒匠手套(2) 细毛皮(2) 皮甲(1) 熟皮革(1) **药水带(2)** |
| 骨制品 `bone` | 8 | 鹿角(1) 碎骨串(2) 骨骰子(3) 蛮神的护符(3) 胫骨大棒(1) **蛮族的项链(0) 猎血者的符号(2) 狩猎之神的护符(3)** |
| 石材 `stone` | 4 | 燧石(0) 粗盐块(0) **创口盐(1) 大地之神的护符(3)** |
| 木制 `wood` | 11 | **橡木原木(0) 铁木枝(2) 硬木板(2) 长弓(2) 短弓(1) 狩猎之神赐福的长弓(3) 箭矢(0) 毒箭(1) 锯齿箭(1) 魔法杖(1) 自然之神的护符(3)** |
| 血肉 `flesh` | 5 | **腌肉干(1) 口粮(0) 行军军粮(2) 蝰蛇毒腺(3) 蜂蜡块(1)** |
| 织物 `cloth` 新 | 12 | **亚麻布卷(0) 丝绸卷(3) 羊毛呢(1) 挂毯(3) 纱布(0) 绷带卷(1) 止血敷料(2) 贴身内甲(1) 麻绳卷(0) 长条包(1) 小背包(0) 护身符(2)** |
| 草药 `herb` 新 | 8 | **干草药束(0) 苦艮根(1) 伤药(1) 浓缩伤药(2) 治愈药剂(3) 解毒包(1) 解毒药囊(2) 万灵药(3)** |
| 陶瓷 `clay` 新 | 3 | **陶罐(0) 彩釉瓷瓶(2) 毒药瓶(1)** |
| 不挂 | 1 | 都行(5) |

合计 29+8+8+8+4+11+5+12+8+3+1 = 97。改动落在 **52 件**道具 json 的 `tags`（51 件加一个标签，灰白色的金属碎片换一个）。

几处取舍：护符六枚按神的性情分（蛮神骨、大地石、狩猎骨、自然木、技巧金、日神宝石），护身符与猎血者的符号这类「符」按材料分（布符、骨刻）。箭矢三种归木（箭杆），不归金属。蜂蜡算血肉（蜂产的，不是植物）。毒药瓶归陶瓷（瓶），毒腺归血肉（腺）。

### 2.2 三种新标签

`data/authoring/tags/cloth.json` / `herb.json` / `clay.json`，字段同 `stone.json`（`tip: false`，`category: material`，`icon` 留空 = 用 id）：

```json
{"id": "cloth", "display_name": "织物", "display_names": {"en": "Cloth"},
 "description": "布、绳、绷带这类织出来的东西。", "descriptions": {"en": "Woven things: cloth, rope, bandages."},
 "tip": false, "category": "material"}
{"id": "herb", "display_name": "草药", "display_names": {"en": "Herb"},
 "description": "草药与用草药配的药。自然之神看重它。", "descriptions": {"en": "Herbs and the remedies made from them. Favoured by the nature god."},
 "tip": false, "category": "material"}
{"id": "clay", "display_name": "陶瓷", "display_names": {"en": "Ceramic"},
 "description": "烧出来的土：陶罐、瓷瓶。", "descriptions": {"en": "Fired earth: pots and vases."},
 "tip": false, "category": "material"}
```

`tests/content/test_tags_171.gd` 若断言材质类标签的列表（`by_category("material")`），要补这三个。三个标签要在标签制作器里登记（171 的规矩），图标派美术（§8）。

## 3. 戊：把薄的标签撑起来（候选道具，作者勾选）

§2 之后石材 4、陶瓷 3、血肉 5 还是薄。下面 16 件候选都是**材料 / 吃食 / 小摆件**，没有战斗规则，照 `oak_log.json` / `salted_meat.json` 的样子写（形状、重量、稀有度、标签、价值走经济表），导入即可。写法「名字 · 稀有度 · 形状 · 标签 · 一句描述」。

**石材 `stone`（4 → 8）**
- 磨刀石 · 1 · `1x2` · material crafted stone supply · 「磨过的刀，刃上一道亮。」
- 花岗石臼 · 1 · `2x2` 重 7 · material crafted stone · 「捣药捣盐都用它，就是沉。」
- 石雕小像 · 2 · `1x1` · material crafted stone treasure · 「不知哪座神的像，手艺倒细。」
- 墓碑碎块 · 0 · `1x1` 重 4 · material nature stone · 「刻字磨平了的半块石碑。」

**陶瓷 `clay`（3 → 7）**
- 陶碗一摞 · 0 · `1x2` · material crafted clay supply · 「五只粗陶碗，缺了一只口。」
- 封泥酒坛 · 1 · `2x2` 重 6 · material crafted clay food · 「泥封还没开，摇一摇还有半坛。」
- 陶俑 · 2 · `1x2` · material crafted clay treasure · 「随葬的小人，表情认真。」
- 釉彩砚 · 3 · `1x1` · material crafted clay treasure · 「文士的物件，釉色像雨后天。」

**血肉 `flesh`（5 → 9）**
- 熏鱼 · 0 · `1x2` · nature food flesh · 「熏得发黑，咬着咸香。」（吃食可照腌肉干给一点耐力）
- 蜂蜜罐 · 1 · `1x1` · material nature flesh · 「蜂蜡挤出来的那点甜。」
- 狼心 · 2 · `1x1` · reagent material nature flesh · 「还温着时取下来的，巫医出高价。」
- 巨兽獠牙根 · 2 · `1x2` 重 3 · material nature flesh trophy · 「带着牙髓的一截，没剔干净。」

**木制 `wood`（11 → 13）** 与 **草药 `herb`（8 → 10）**（已经不薄，各补两件撑气氛）
- 松脂块 · 0 · `1x1` · material nature wood · 「黏手，点火引子。」
- 木雕神像 · 2 · `1x3` · material crafted wood treasure · 「路边小庙里请出来的。」
- 薄荷叶束 · 0 · `1x1` · material nature herb · 「嚼着凉，提神。」
- 曼陀罗花 · 2 · `1x1` · reagent material nature herb poison · 「好看，别闻久。」

这 16 件只是候选：作者勾哪些做哪些，不勾就只做 §2。做的那批进 `IdAliases` 不需要（是新增不是改名），但要跑 `bash tools/snapshot_content.sh`。

## 4. 三张表（逐行，可照抄进 json）

通用：行序即优先级，十个材质行 → 三个来源兜底行 → `default`。规则里的 `"@xxx"` 是 `data/authoring/rule_parts/` 的构件；没有构件的内联写。

### 4.1 时机表 `timing.json`

**材质 → 什么时候**（十种各不同；金属、骨、皮革、石材、血肉沿用现在的，木制保留「施加状态时」，宝石从「受伤前」改成「暴击时」—— 受伤前只对改伤害的三种效果有意义）：

| 行 | 什么时候 | trigger | 备注 |
| --- | --- | --- | --- |
| `metal` 金属 | 这把武器出手时 | `"@on_item_fired"` | 不动（测试依赖） |
| `bone` 骨 | 造成 / 受到伤害时 | `{"type": "on_damage"}` | 方向由用途定 |
| `leather` 皮革 | 开战时 | `"@on_battle_start"` + `fixed_cadence: "@always"` | 不动 |
| `stone` 石材 | 按节拍 | `"@on_schedule"` | 不动 |
| `wood` 木制 | 自己施加状态时 | `{"type": "on_status_applied"}` | by_self 默认 true；弓箭、法杖都是施加者 |
| `gem` 宝石 | 暴击时（造成 / 受到） | `{"type": "on_damage", "crit_only": true}` | 新：吃锐目 / 致命轴 |
| `flesh` 血肉 | 生命低于 40% 时 | `"@on_resource_below_40"` | 不动 |
| `cloth` 织物 新 | 自己中招时（对手给自己施加状态） | `{"type": "on_status_applied", "on_self": true, "by_self": false}` | 和木制成对 |
| `herb` 草药 新 | 自己生命不低于 70% 时 | `{"type": "on_resource_below", "resource_key": "hp", "percent": 70, "direction": "ABOVE"}` | 和血肉成对；资源一变就问，靠冷却限频 |
| `clay` 陶瓷 新 | 造成 / 受到 6 点以上伤害时 | `{"type": "on_damage", "min_amount": 6.0}` | 重击；方向由用途定 |
| `nature` 兜底 | 同木制 | 同 `wood` 行 | 甲 |
| `crafted` 兜底 | 同金属 | `"@on_item_fired"` | 甲 |
| `magic` 兜底 | 同宝石 | 同 `gem` 行 | 甲 |
| `default` | 这把武器出手时 | `"@on_item_fired"` | 不动 |

**用途 → 方向 + 节奏系数**（乙 / 丁；`cadence_mult` 是新字段，见 §6）：

```json
"purpose": [
  {"key": "weapon", "trigger_props": {"direction": "DEALT"}, "cadence_mult": 0.75},
  {"key": "shield", "trigger_props": {"direction": "TAKEN"}, "cadence_mult": 1.0},
  {"key": "armor",  "trigger_props": {"direction": "TAKEN"}, "cadence_mult": 1.25},
  {"key": "default", "cadence_mult": 1.0}
]
```

方向只写到有 `direction` 的扳机上（受伤 / 造成伤害两类），别的扳机照旧忽略。节奏系数乘在冷却秒数上（`@always` 与开战时不乘）：武器进时机槽 = 快、盾 = 中、防具 = 慢。

**稀有度 → 多久一次**（己，六档，全部写成冷却，4 以上才给「每次」）：

```json
"rarity": [
  {"key": "0", "cadence": {"type": "cooldown", "seconds": 6.0}},
  {"key": "1", "cadence": {"type": "cooldown", "seconds": 4.0}},
  {"key": "2", "cadence": {"type": "cooldown", "seconds": 3.0}},
  {"key": "3", "cadence": {"type": "cooldown", "seconds": 2.0}},
  {"key": "4", "cadence": "@always"},
  {"key": "5", "cadence": "@always"},
  {"key": "default", "cadence": {"type": "cooldown", "seconds": 6.0}}
]
```

（「每次」落到不许的时机上仍换成 1 秒冷却，`Forge.MIN_COOLDOWN` 不动。）

### 4.2 效果表 `effect.json`

**两条新规矩**（都要改代码，§6）：
1. **攻式 / 守式**：每个材质行写两套效果 —— `effect / upgraded / bonus`（攻式，前缀 `prefix`）和 `guard_effect / guard_upgraded / guard_bonus`（守式，前缀 `guard_prefix`）。效果槽里放的道具用途是盾或防具 → 守式，否则 → 攻式。用途行只写 `stance`，不再写 `target`。效果的「给谁」由效果自己写（攻式给对手、守式给自己），再也不会出现打自己。
2. **升阶是加一句**：阶 ≥1 时在基础句之后**追加** `upgraded`，阶 ≥2 再追加 `bonus`（现在是 `upgraded` 替换基础句）。三句都写在同一条规则里。数值 N 只写进基础句（`amount_field`），升阶与附带的数自己写死（表里给的是「一档」的值，不随数值槽变 —— 见 §7 待定 1）。

元素行（宝石）的 `by_element` / `applies` 照旧，只对攻式生效。

下面每行写「基础 → 升阶 → 附带」，N = 数值槽算出的 magnitude，括号里是 json。目标写明：对手 = `"target": 0`，自己 = `"target": 1`。

| 行 | 攻式（前缀） | 守式（前缀） |
| --- | --- | --- |
| `metal` 金属 | **锋利的** 对对手造成 N 物理伤害 (`deal_damage amount N damage_stat ""`) → 再造成 3 真伤 (`deal_damage damage_type "bleed" amount 3`) → 对手破绽 +1 (`shift_axis target 0 axis "block" delta -1`) | **铁壁的** 自己护甲 +N (`change_resource target 1 resource_key "armor" amount N`) → 自己加固 +1 (`shift_axis target 1 axis "block" delta 1`) → 自己弹开 (`apply_status target 1 buff "deflect"`) |
| `bone` 骨 | **嗜血的** 对手流血 N 层 (`apply_status buff "bleed" stacks N`，amount_field `stacks`) → 对手流血保底 2 层 (`guard_status target 0 buff "bleed" stacks 2`) → 再造成 2 真伤 (`deal_damage damage_type "bleed" amount 2`) | **蛮勇的** 自己去掉 N 层流血 (`remove_status target 1 buff_id "bleed" stacks N`) → 自己生命 +2 (`change_resource target 1 amount 2`) → 自己血怒 (`apply_status target 1 buff "blood_rage"`) |
| `flesh` 血肉 | **淬毒的** 对手中毒 N 层 (`apply_status buff "poison" stacks N`，`stacks`) → 对手剧毒 1 层 (`apply_status buff "virulent" stacks 1`) → 对手菌血 1 层 (`apply_status buff "fungal_blood" stacks 1`) | **厚皮的** 自己生命 +N (`change_resource target 1 amount N`) → 自己去掉全部中毒 (`remove_status target 1 buff_id "poison" stacks 0`) → 自己坚韧 (`apply_status target 1 buff "hardy_guard"`) |
| `gem` 宝石 | **燃烧的 / 霜冻的 / 雷鸣的** 对手 N 元素伤害 + 按阶施加元素（现有 `by_element`，不动）→ 再造成 3 元素伤害 (`deal_damage amount 3`，伤害类型随 by_element) → 对手易伤 +1 (`shift_axis target 0 axis "damage_taken" delta 1`) | **璨光的** 自己法力 +N (`change_resource target 1 resource_key "mana" amount N`) → 自己锐目 +1 (`shift_axis target 1 axis "crit_chance" delta 1`) → 自己护符结界 (`apply_status target 1 buff "ward"`) |
| `leather` 皮革 | **束缚的** 对手减速 N (`shift_axis target 0 axis "attack_speed" delta -N`，amount_field `delta`) → 对手笨拙 +1 (`shift_axis target 0 axis "stamina_cost" delta -1`) → 对手标记 (`apply_status buff "marked"`) | **坚壁的** 自己护甲 +N (`change_resource target 1 resource_key "armor" amount N`) → 自己坚韧 (`apply_status target 1 buff "hardy_guard"`) → 自己生命 +2 (`change_resource target 1 amount 2`) |
| `wood` 木制 | **荆棘的** 对手 N 物理伤害 (`deal_damage amount N damage_stat ""`) → 对手流血 1 层 (`apply_status buff "bleed" stacks 1`) → 自己加速 +1 (`shift_axis target 1 axis "attack_speed" delta 1`) | **回春的** 自己生命 +N (`change_resource target 1 amount N`) → 自己回春 +1 (`shift_axis target 1 axis "regen_hp" delta 1`) → 自己法力 +2 (`change_resource target 1 resource_key "mana" amount 2`) |
| `stone` 石材 | **碎岩的** 对手 N 物理伤害，基数 4 (`deal_damage amount N damage_stat ""`) → 对手减速 1 (`shift_axis target 0 axis "attack_speed" delta -1`) → 对手麻痹 1 层 (`apply_status buff "numb" stacks 1`) | **坚固的** 自己弹开 (`apply_status target 1 buff "deflect"`，不可叠，N 不用) → 自己久弹 (`apply_status target 1 buff "deflect_long"`) → 自己加固 +1 (`shift_axis target 1 axis "block" delta 1`) |
| `cloth` 织物 新 | **缠绕的** 对手笨拙 N (`shift_axis target 0 axis "stamina_cost" delta -N`，`delta`) → 对手去掉 1 层增益 (`remove_status target 0 all_buffs true stacks 1`) → 对手标记 (`apply_status buff "marked"`) | **裹伤的** 自己去掉 N 层流血 (`remove_status target 1 buff_id "bleed" stacks N`) → 自己护甲 +2 (`change_resource target 1 resource_key "armor" amount 2`) → 自己坚韧 (`apply_status target 1 buff "hardy_guard"`) |
| `herb` 草药 新 | **苦涩的** 对手中毒 N 层 (`apply_status buff "poison" stacks N`，`stacks`) → 对手腐蚀 +1 (`shift_axis target 0 axis "regen_hp_pct" delta -1`) → 对手去掉 1 层增益 (`remove_status target 0 all_buffs true stacks 1`) | **药香的** 自己去掉 N 层减益 (`remove_status target 1 all_debuffs true stacks N`) → 自己生命 +2 (`change_resource target 1 amount 2`) → 自己回春 +1 (`shift_axis target 1 axis "regen_hp" delta 1`) |
| `clay` 陶瓷 新 | **碎瓷的** 对手 N 物理伤害 (`deal_damage amount N damage_stat ""`) → 对手流血 1 层 (`apply_status buff "bleed" stacks 1`) → 对手破绽 +1 (`shift_axis target 0 axis "block" delta -1`) | **釉彩的** 自己法力 +N (`change_resource target 1 resource_key "mana" amount N`) → 自己护符结界 (`apply_status target 1 buff "ward"`) → 自己生长 +1 (`shift_axis target 1 axis "max_hp" delta 1`) |
| `nature` 兜底 | 同木制 | 同木制 |
| `crafted` 兜底 | 同金属 | 同金属 |
| `magic` 兜底 | 同宝石 | 同宝石 |
| `default` | **附魔的** 对手 N 物理伤害，基数 2（不动，只有基础句） | **护身的** 自己护甲 +N，基数 2 |

基数 `base`：伤害类 3（石材 4、default 与木制 2），层数 / 资源类 2，轴类 1。英文前缀照现有写法（`prefixes.en`）由执行补：Keen / Bulwark、Bloodthirsty / Brutish、Venomous / Thick-hided、（元素三个不动）/ Gleaming、Binding / Bulwark→改 Hardened、Thorned / Verdant、Crushing / Sturdy、Tangling / Dressed、Bitter / Fragrant、Shattering / Glazed、Enchanted / Warded。

**用途 → 攻守**：

```json
"purpose": [
  {"key": "weapon", "stance": "attack"},
  {"key": "shield", "stance": "guard"},
  {"key": "armor",  "stance": "guard"},
  {"key": "default", "stance": "attack"}
]
```

**稀有度 → 几阶**（己；`main_mult` 是新字段，乘在基础句的数上）：

```json
"rarity": [
  {"key": "0", "tier": 0},
  {"key": "1", "tier": 0},
  {"key": "2", "tier": 1},
  {"key": "3", "tier": 2},
  {"key": "4", "tier": 2, "main_mult": 1.5},
  {"key": "5", "tier": 2, "main_mult": 2.0},
  {"key": "default", "tier": 0}
]
```

### 4.3 数值表 `value.json`

材质十行各有系数（宝石最贵、织物 / 木 / 陶最便宜）；用途按丁；稀有度六档。

```json
"material": [
  {"key": "gem", "mult": 1.5}, {"key": "metal", "mult": 1.25}, {"key": "stone", "mult": 1.25},
  {"key": "bone", "mult": 1.0}, {"key": "leather", "mult": 1.0}, {"key": "flesh", "mult": 1.0}, {"key": "herb", "mult": 1.0},
  {"key": "wood", "mult": 0.75}, {"key": "cloth", "mult": 0.75}, {"key": "clay", "mult": 0.75},
  {"key": "nature", "mult": 0.75}, {"key": "crafted", "mult": 1.25}, {"key": "magic", "mult": 1.5},
  {"key": "default", "mult": 1.0}
],
"purpose": [
  {"key": "weapon", "mult": 1.2}, {"key": "shield", "mult": 1.0}, {"key": "armor", "mult": 1.5}, {"key": "default", "mult": 1.0}
],
"rarity": [
  {"key": "0", "size": 1.0}, {"key": "1", "size": 1.5}, {"key": "2", "size": 2.0},
  {"key": "3", "size": 3.0}, {"key": "4", "size": 4.0}, {"key": "5", "size": 5.0}, {"key": "default", "size": 1.0}
]
```

### 4.4 三张表合起来的例子

- 匕首（金属武器 r0）进时机 + 鹿角（骨 r1）进效果 + 匕首进数值：出手时（6 × 0.75 = 4.5 秒一次）对手流血 N 层，N = 2 × 1 × 1.25 × 1.2 ≈ 3。「嗜血的匕首」，和今天一样（测试不变）。
- 塔盾（金属盾 r1）进时机 + 圆盾（金属盾 r1）进效果 + 板甲（金属防具 r2）进数值：受到伤害时（4 秒一次）自己护甲 +N，N = 2 × 2 × 1.25 × 1.5 ≈ 8。「铁壁的」—— 今天这组合是「受伤时对自己造成 3 点伤害」。
- 长弓（木武器 r2）进时机 + 万灵药（草药 r3）进效果 + 果果之心（宝石 r5）进数值：自己施加状态时（3 × 0.75 ≈ 2.3 秒一次）对手中毒 N 层并腐蚀 +1、去 1 层增益，N = 2 × 5 × 1.5 × 1 = 15。「苦涩的」。

## 5. 稀有度六档一览（己）

| 稀有度 | 时机：多久一次 | 效果：几阶 | 数值：几档 |
| --- | --- | --- | --- |
| 0 | 6 秒 | 基础 | ×1 |
| 1 | 4 秒 | 基础 | ×1.5 |
| 2 | 3 秒 | 基础 + 升阶 | ×2 |
| 3 | 2 秒 | 基础 + 升阶 + 附带 | ×3 |
| 4 | 每次 | 全部，基础句 ×1.5 | ×4 |
| 5 | 每次 | 全部，基础句 ×2 | ×5 |

稀有度 5 今天落 `default` 行（导入器只许 0–4），果果之心与都行是 5；放开到 0–5。

## 6. 代码改动（小，全在 `core/forge/` 与导入器）

1. `ForgeEntry`：时机槽用途行加 `cadence_mult: float = 1.0`；效果槽材质行加 `guard_effect / guard_upgraded / guard_bonus: CombatEffect`、`guard_prefix: String`、`guard_prefixes: Dictionary`、`guard_amount_field: StringName`（守式基础句的数写到哪一项，默认 `amount`；血肉 / 皮革 / 织物三行攻守两式的字段不同）；效果槽用途行加 `stance: StringName`（`attack` / `guard`，空 = attack），`target` 字段保留但表里不再写；效果槽稀有度行加 `main_mult: float = 1.0`。
2. `Forge._timing_rule`：`CooldownCadence.seconds *= tp.cadence_mult`（固定节奏、Always 不乘；乘完仍 ≥ `MIN_COOLDOWN`）。
3. `Forge.rule_of`：按 `ep.stance` 选攻式或守式三句；基础句数值 = magnitude × `er.main_mult`；阶 ≥1 **追加** upgraded，阶 ≥2 追加 bonus（不再替换）；去掉用途改 target 的两处（效果自带 target）。`_element_apply` 只在攻式时跑。
4. `Forge.prefix` / `sentence` / `slot_summary`：守式用 `guard_prefix`；`_effect_summary` 的「给谁」一行改成「攻式 / 守式（放盾或防具时换成守式）」，「阶」一行按追加语义写「基础；+升阶；+附带」。
5. `_shape_effect` 的 `amount_field`：攻式用 `amount_field`、守式用 `guard_amount_field`（`amount` / `stacks` / `delta`），导入器各校验基础句上有这一项。
6. 导入器 `import_forge_table`：稀有度行 key 放开到 0–5；效果材质行要么有 `effect`、要么有 `guard_effect`（两者都要）；用途行 `stance` 只许 attack / guard。
7. `EnchantDef` / 存档字典不变（仍记行 key），旧存档的 `target: "shield"` 这类值仍能查到行，只是语义变成守式 —— 对账不需要别名。
8. 测试：`test_forge_175.gd`（匕首 + 鹿角仍是「嗜血的」出手时流血；用途「给谁」一段改成攻守；`beat` 字典里 `rate: 4`）、`test_forge_194.gd`（§2 三行的文案）、`test_element_apply_175.gd`（元素行只在攻式）、`test_tags_171.gd`（材质列表 10 个）；新增 `test_forge_195.gd`：十个材质行各铸一次攻式一次守式都拼得出规则、盾进效果槽不打自己、追加语义、节奏系数、稀有度 5。跑完 `bash tools/snapshot_content.sh`。

## 7. 待定（默认按推荐）

1. 升阶 / 附带两句的数要不要也随数值槽变？推荐 **A 不变**（写死，表里一眼看出），B 乘 `main_mult`。
2. 用途 `default`（材料、吃食进效果槽）归攻式还是守式？推荐 **A 攻式**（今天的手感），B 按材质行各写一个默认式。
3. §3 的 16 件候选道具：推荐 **A 全做**，B 只做石材与陶瓷的 8 件，C 不做。
4. 元素三行守式的前缀同用「璨光的」还是按元素分三个？推荐 **A 同用**。

## 8. 改动清单与派工

**派「架构方案执行」**：§2.1 的 52 处 `tags`、§2.2 三个标签 json（登记进标签制作器）、§4 三张表、§6 代码与测试、`tools/import_content.gd` 导入、`bash tools/snapshot_content.sh`、全套测试；§3 候选按作者勾的做。版本号一档。
**派「美术设计」**：织物 / 草药 / 陶瓷三枚标签图标，风格同已交付的那套，交付 `/mnt/project-files/art/ui/tags/`，文件名 = 标签 id。—— 2026-10-18 21:30 美术已交付给执行：源图 48 px（@2x 96），游戏里按 193 补充二显示 32 px，与现有那套同规格。
**本篇不碰**：铸炉界面皮肤（待办 `/mnt/project-files/reference/待做-界面.md`）、铸牌只能附武器的规矩（175 待定 7 A）。
