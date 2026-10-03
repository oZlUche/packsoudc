# 方案：武器附加效果的统一接口 —— 邻居附加（毒箭）与日神附魔走同一条路（108）

> 架构 thread，2026-10-03。作者的想法：「可以让武器拥有额外效果，比如新道具【毒箭】放到弓旁边可以让弓的每次攻击附带一层【中毒】，设计一个接口，日神附魔也走这个接口。」
> 本文只写方案，不实现。前提沿用 106 §八（直接 / 非直接看来源）与 107 的作者纠正（毒、流血只有 buff 形态，武器顶多给对手上【中毒 / 流血】）。

## 一、现状：接口其实已经有一半了

日神附魔今天就是「往一把武器身上**挂一条规则**」：

| 步骤 | 在哪 |
|---|---|
| perk 只往 `CompileInput.scoped` 放一条 `ScopedMod{tags:[weapon], require_active, pick:3, rules:[附火规则]}` | `core/run/faith/perks/enchant_weapons_perk.gd` |
| 编译第 7 步筛命中件、按种子挑 | `BattleCompiler._apply_scoped` |
| 把规则 `duplicate(true)` 后追加到那件的 `CompiledItem.rules`，规则里的 `OnItemFired` 被绑成**只听自己**（`include_self = true`、`source_uids = [宿主 uid]`） | `BattleCompiler._apply_scope_to`（`compiler.gd:178`） |
| 战斗里规则以**宿主**为 `source_uid` 跑：`ctx.item_stat(DAMAGE)` 读的是**那把武器**的伤害，伤害包的来源是武器 → 直接伤害 | `FireEnchant.apply`、`RuleContext.item_stat` |

这就是作者要的「武器拥有额外效果」的本体：**一条附加到宿主身上、随宿主出手触发、以宿主身份结算的规则**。缺的是：

1. 它没有名字，只是 `_apply_scope_to` 里的一段循环；
2. 只有信仰 perk 能走到这里 —— **邻接**（毒箭挨着弓）今天只能给邻居加 `StatModifier`（`AdjacencyProfile.grant_mods`），**不能挂规则**；
3. 挂上去之后没人记得它从哪来 —— 弓的悬浮窗里显示不出「这一条是毒箭 / 日神给的」。

### 为什么不用现成的 `OnItemFired.LINKED`

今天「配件跟着武器一起触发」的写法是配件自己带一条规则、触发器 `source = LINKED`（听连结的邻居出手）。它表达的是**配件自己的反应**，不是武器的附加效果：

| | `LINKED`（配件听武器） | 附加（规则挂到武器身上） |
|---|---|---|
| 规则以谁的身份跑 | 配件（`source_uid` = 毒箭） | 武器（`source_uid` = 弓） |
| `item_stat(DAMAGE)` 读谁 | 毒箭自己的（它没有伤害） | 弓的 —— 「附带 30% 武器伤害的火焰」这类才算得出来 |
| 悬浮窗显示在谁身上 | 毒箭 | 弓（「出手时施加中毒 ← 毒箭」） |
| 听哪些邻居 | 所有连结件（除非自己再筛） | 只听宿主自己 |
| 信仰能不能复用 | 不能（perk 不是道具，没有邻居） | 能，日神附魔已经在用 |

两者都留：`LINKED` 继续给「箭袋：连结的武器出手时自己攒一层」这类配件反应；**「武器出手时附带 X」统一走附加**。

## 二、方案

### 2.1 一个名字：附加规则 `attach`

编译器里把 `_apply_scope_to` 的挂规则那段抽成**唯一入口**：

```gdscript
## 把 rule 附加到宿主 item 上：复制、把 OnItemFired 绑成只听宿主、记来源。
## 邻接增益格（2.2）和 ScopedMod（信仰）都从这里进，以后局内 buff / 套装也是。
static func _attach(item: CompiledItem, rule: AbilityRule, origin: StringName) -> void
```

`CompiledItem` 加一张来源表（规则本身仍平铺在 `rules` 里，战斗层不用改）：

```gdscript
## 附加规则的来源，与 rules 的下标对齐；自己写的规则没有条目。
## origin：道具 def_id（邻居给的）或 faith:<id>（信仰给的）
var attached: Array[Dictionary] = []   # {rule_index, origin}
```

`ScopedMod` 那边只是改成调 `_attach(item, rule, &"faith:sun")`（来源由 perk 填进 `ScopedMod.origin`，新字段，默认空）。**日神附魔的编译结果一字不变**，金样不用重录。

### 2.2 邻接多一条通道：`grant_rules`

`AdjacencyProfile` 在 `grant_mods` 旁边加：

```gdscript
## 我给站在增益格上的邻居挂的规则（每个点亮的邻居各挂一份，规则里的 OnItemFired 绑成只听那个邻居）
@export var grant_rules: Array[AbilityRule] = []
```

编译第 5 步 `_apply_adjacency` 里，对每个 `receivers` 中的 `other`，除了 `grant_mods.apply_to(stats[other])`，再对每条 `grant_rules` 调 `_attach(spec.item_of(other), rule, holder.def.id)`。两个 `has_grant()` 的判定改成「有格 **且**（有加成 **或** 有规则）」。

`receive_rules`（「邻居给我挂规则」的反向）**这次不加**：作者的例子和日神都是「给邻居 / 给武器」方向；反向等有内容要再加一行，形状一样。

### 2.3 附加规则只许一种时机（校验）

附加规则的意义是「宿主出手时附带」，所以：

- 触发器**必须**是 `on_item_fired`（`grant_rules` 与 `ScopedMod.rules` 都查）；写成别的 → 导入 **error**：「附加规则听的是宿主出手；受伤 / 开战这类时机写在自己身上」。
- `cadence` 建议 `always`；写了冷却也允许（「每 3 秒最多附带一次」是合理的）。
- `costs` 禁止（宿主出手已经付过耐力，附带不再二次扣）→ error。
- 效果里 `deal_damage` 的 `damage_type` 若是 `poison` / `bleed` → error（107 的那条校验，这里同样适用：要上毒就 `apply_status`）。

### 2.4 毒箭（新道具，内容样例）

```json
{
  "id": "poison_arrows", "display_name": "毒箭", "tags": ["ammo", "poison", "nature"],
  "adjacency": {
    "grant_cells": [[0, -1]], "grant_filter": ["ranged"],
    "grant_rules": [{
      "trigger": {"type": "on_item_fired"}, "cadence": {"type": "always"},
      "effects": [{"type": "apply_status", "target": "OPPONENT", "stacks": 1, "buff": {"id": "poison", …同毒刀的中毒…}}]
    }]
  }
}
```

- 和现有【箭】（`arrows.json`：增益格 `(0,-1)`，筛 `ranged`，给 `SHARP +20%`）同一个形状，只是「给加成」换成「给规则」；两样都写也行（箭 +20% 且附毒），字段互不排斥。
- 两件毒箭同时点亮一把弓 → 挂两条 → 每箭两层。这是邻接「每个邻居各一份」的既有语义，不另做上限。
- 中毒的 `BuffDef` 现在是**内联在各道具里**的同 id 副本（毒刀、毒瓶各一份），`apply_buff` 按 `buff.id` 叠层，所以毒箭再内联一份也能和毒刀叠在一起。把 buff 抽成共享文件（`data/authoring/buffs/`）是另一件事，这里不做。

### 2.5 悬浮窗与描述

- **弓**：`ItemTooltip.describe_full` 走 `compiled_for(inst, board)`，已经拿得到挂上去的规则。按 `attached` 分组多画一行：「附加：出手时 施加中毒 ← 毒箭」「附加：出手时附带火焰伤害 ← 日神」。只在棋盘上（有 board）才有，这和邻接加成今天的显示一致。
- **毒箭**自己：说明文字按 104 §十的规矩由字段生成：「给相邻的远程武器附加：出手时施加中毒。」—— `AdjacencyProfile` 的描述函数在 `grant_mods` 之后追加 `grant_rules` 各条的 `describe()`。
- 词条：附加规则里 `apply_status` 的 buff 要进**弓**的侧窗（107：buff 词条照旧弹），`Glossary` 收 buff 词条时把 `attached` 的规则一起扫。
- 编辑器：道具的邻接页多一个「增益规则」列表，复用现有规则编辑控件。

### 2.6 预估与统计

`CompiledItem.estimated_dps` 已经把所有 `rules` 算进去（附火的 `estimated_damage` = 固定值；`apply_status` 为 0），拖动预估不用动。战斗账里的伤害来源是宿主 uid，所以「弓造成的伤害」会把附带的火算进弓 —— 这是今天附魔的既有口径，保持。

## 三、改动范围（约一天）

| 批 | 内容 | 文件 |
|---|---|---|
| ① 接口 | `_attach` 抽出；`CompiledItem.attached`；`ScopedMod.origin` | `core/battle/compiler.gd`、`compiled_item.gd`、`scoped_mod.gd`、`enchant_weapons_perk.gd`（填 origin） |
| ② 邻接 | `AdjacencyProfile.grant_rules`、`has_grant()` 改判、`_apply_adjacency` 调 `_attach`、描述函数 | `core/battle/adjacency_profile.gd`、`compiler.gd`、邻接描述所在处 |
| ③ 校验 | 2.3 的四条（时机、无 costs、无直接毒 / 流血伤害）；`grant_rules` 走现有规则校验 | `core/authoring/content_importer.gd` |
| ④ 内容 | `poison_arrows.json`；重导；掉落表 / 商店要不要出现由作者定（默认和【箭】同池） | `data/authoring/items/`、`tools/import_content.gd` |
| ⑤ 界面 | 弓的悬浮窗「附加」行；毒箭说明；编辑器邻接页 | `ui/inventory/item_tooltip.gd`、编辑器 |
| ⑥ 测试 | 毒箭贴弓：弓每出手对手 +1 层中毒、毒箭不挨着就没有、两件毒箭两层、挨着近战武器不生效（filter）；附加规则以弓为 source（`item_stat` 读弓）；日神金样不变；导入校验四条各一例 | `tests/battle/`、`tests/authoring/`、`tests/fixtures/compile_golden/`（应全绿不重录） |

## 四、与别的方案的关系

- **105**：`ScopedMod.rules` 是附加的信仰入口，不变；只是多记 `origin`。
- **106 §八**：附加规则以宿主为来源 → 其中的 `deal_damage`（附火）是直接伤害，吃防护；`apply_status` 上的【中毒】每秒掉血来自 buff → 非直接。和作者的规矩一致，不需要 `direct_override`。
- **107**：毒箭的标签 `毒` 不弹窗；弓侧窗里的【中毒】buff 词条弹。
- **架构文档 4.2**「邻接标记」一节落地后补一句：增益格除了加成还能挂规则；`socket` / 镶嵌仍留给宝石。

## 待作者定（不挡执行，按推荐先做）

1. `receive_rules` 反向通道：**推荐这次不加**，等内容需要。
2. 附加规则的时机限定为 `on_item_fired`：**推荐限定**（别的时机写在道具自己身上即可）。
3. 弓悬浮窗里附加行的写法：**推荐**「附加：出手时 施加中毒 ← 毒箭」，来源名放句尾。
4. 毒箭进哪些掉落池：**推荐**与【箭】同池、同稀有度 +1。
