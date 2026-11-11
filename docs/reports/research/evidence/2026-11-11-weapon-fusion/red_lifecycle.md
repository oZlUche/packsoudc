# 高阶武器（金 / 红）获取渠道与红武唯一性生命周期 —— 只读调查

仓库根目录，commit `254f084c`（detached，main 最新）。全程只读，没跑 Godot，结论全部来自静态阅读；跑不了的情况给了复现步骤（§六）。

状态标记：
- **【已实现·可达】**：代码和数据都接通了，正常游戏里走得到
- **【配置在·未接通】**：数据或代码在，但缺一环，正常玩走不到
- **【仅设计】**：只在 docs 里，代码和数据都没有
- **【测试专用】**：只有测试 / 校准工具走得到
- **【无法确认】**：静态阅读定不了

---

## 一、稀有度与颜色

| rarity | 名称 | 颜色 | 证据 |
|---|---|---|---|
| 0 | 普通 | 白 `d8dce3` | `ui/inventory/item_painter.gd:7-14` `RARITY_COLORS`；名称 `ui/inventory/item_tooltip.gd:14` `RARITY_NAMES` |
| 1 | 优良 | 绿 | 同上 |
| 2 | 稀有 | 蓝 | 同上 |
| 3 | 史诗 | 紫 | 同上 |
| **4** | **传说** | **金 `e0b040`**（报告 279/281 里叫「橙档」） | `item_painter.gd:12` |
| **5** | **神话** | **红 `d9453f`** | `item_painter.gd:13` |

文字色另走模板 `data/authoring/ui/text_colors.json` 的 `rarity`（六档），由 `ui/ui_palette.gd:98-101,204-218` `UiPalette.rarity_color` 读取。

**怎样算武器**：带 `weapon` 标签。依据：`RedSources.class_of` 用 `def.tags.has(&"weapon")` 判断（`core/run/red_sources.gd:48-56`）；`Forge.accepts` 同样看 `weapon` 标签（`core/forge/forge.gd:139`）；敌人武器上限 `enemy_placer.gd:793` 也是 `d.tags.has(&"weapon")`。下表里 rarity≥4 的武器都同时有 `combat`。

---

## 二、rarity 4 / 5 的武器清单与全部来源

### 2.1 红档（rarity 5）—— 8 把本体（`unique`）+ 8 把劣化版（`lesser`）

| id | 中文名 | tags（类别） | 来源（全部）| 状态 | 进出局 / 出售 |
|---|---|---|---|---|---|
| `jimie` | 寂灭 | weapon,melee,staff,magic,**unique** | **唯一来源**：神坛献祭。`data/authoring/events/rest_default.json:81-90`（`jimie_ready` → `jimie_sacrifice` → `event_jimie_god`）→ `JimiePath.sacrifice`（`core/run/jimie_path.gd:106-128`）。前置条件：全黑法杖（法杖实例进出局 ≥50 次，`item_instance.gd:76-95`）加四颗元素之核，且信仰没有激活（`events/conditions/jimie_ready.gd:7`）。元素之核只能从试炼拿（`jimie_path.gd:33-92`），而试炼表 `TRIALS`（`jimie_path.gd:14`）只配了 `free_mode`（魔法废墟）= 火、`clockwork_hourglass` = 雷。**冰之核、毒之核没有任何来源**，所以献祭条件在现有内容下凑不齐 | **【配置在·未接通】**：链条代码完整，缺两章的数据；`docs/status.md:18` 写的是「寂灭来路已做完」，但它自己也说要等以后两章（281 §十一 12:10 行：「眼下还走不到献祭」）。测试里靠 `RunState.start(...layout)` 直接摆四颗核（`tests/run/test_jimie_altar_281.gd:8-17`）=【测试专用】 | 能带进带出（没有任何携带限制）；不能卖（`meta_state.gd:587`、`item_actions.gd:75,96`、`shop_session.gd:146`） |
| `poxiao` | 破晓 | weapon,ranged,burst,**unique** | **没有任何来源**。只有起点：铁匠铺 3 级时点铁匠，专属对话 `poxiao_start` 给出 `poxiao_token`（「破晓的信物」，valuable+unique），见 `data/authoring/npcs/blacksmith.json` 的 `specials[0]`（`facility_at_least smithy 3` + `owned_nowhere [poxiao, poxiao_token]`，`give: poxiao_token`）。信物换成破晓这一步在代码和数据里都找不到（grep `poxiao` 只命中 npc、items、tests） | 破晓本体 **【仅设计 / 留白】**（281 §四.3 破晓行、282 §2.3：「其后的流程留白」）；信物 **【已实现·可达】** | 信物不能卖（unique）；能不能带进局：没看到限制 |
| `chana` | 刹那 | weapon,melee,rapid,dagger,bleed,unique | 无 | **【仅设计】**：作者 11:37 给了原文，281 §四.3 / status A1 写着「暂只记录」 | — |
| `duanshui` | 断水 | weapon,melee,burst,one_hand,unique | 无 | **【仅设计】**（同上） | — |
| `shuangsheng` | 双生 | weapon,melee,rapid,dual,unique | 无 | **作废**（作者 15:37：「其他武器的任务链不要实装」，281 §四.3） | — |
| `guanri` | 贯日 | weapon,melee,burst,polearm,unique | 无 | 作废（同上） | — |
| `bengshan` | 崩山 | weapon,melee,burst,two_hand,heavy,unique | 无 | 作废（同上） | — |
| `zhuixing` | 坠星 | weapon,ranged,rapid,unique | 无 | 作废（同上） | — |
| `<上面 8 个>_lesser` | 同名两字（压暗图） | 同本体，`unique` 换成 `lesser` | **BOSS / 猎手持有，打赢后掉落**：`RedSources.arm`（`red_sources.gd:71-117`）和 `roll_drop`（`:121-132`）。持有率 = `min(5%, 1%×(1+进阶级))`，掉落率 = `20%+10%×进阶级`（`:8-12,39-44`）。入口一：核心点 BOSS，`node_events.gd:548-549`（`type == &"core"`），并且点的档位 ≥3，或者没有档位时不是序章（`red_sources.gd:21-32`）。入口二：猎手，`hunters/hunter_system.gd:371`。掉落挂在 `node_events.gd:970` 的 `red_drop` hook 上，接线在 `run_state.gd:1016-1020`。按对手手里的同类武器替换；魔兽和机关手里没有能配的武器类，永远不持有（281 §十一 12:25） | **【已实现·可达】** | 不是独一的；能卖；不附魔（`forge.gd:140`）、不赐福（`blessings.gd:13`）；常规掉落跳过（`drop_resolver.gd:97,113,121`）；随机池拦掉（`item_database.gd:93`） |

非武器但同属红武链条的 `unique` 道具：`jimie_core_fire / _ice / _lightning / _poison`（material,magic,unique，材质 gem，1×1）和 `poxiao_token`（valuable,unique，材质 metal，1×1）。

### 2.2 金档（rarity 4）武器

| id | 中文名 | tags | 来源 | 状态 | 进出局 |
|---|---|---|---|---|---|
| `flame_berserker_twin_axes` 焰纹狂战双斧、`flame_bonesteel_broadsword` 焰纹骨钢阔剑、`flame_bonesteel_spear` 焰纹骨钢矛、`flame_composite_bow` 焰纹复合弓、`flame_execution_blade` 焰纹处刑巨刃、`flame_executioner_axe` 焰纹刽子手巨斧、`flame_fang` 焰牙、`flame_meteor_maul` 焰纹陨铁大锤、`frost_bloodoath_axe` 霜纹血誓斧、`frost_bonesteel_greatsword` 霜纹骨钢双手剑、`frost_dragoon_lance` 霜纹龙骑枪、`frost_fang` 霜牙、`thunder_bloodthirst_twin_blades` 雷纹噬血双刀、`thunder_boneiron_club` 雷纹骨铁大棒、`thunder_heavy_crossbow` 雷纹重弩、`thunder_horse_halberd` 雷纹斩马戟、`thunder_siege_spear` 雷纹破城矛（共 17 把） | weapon + 类别 + 元素（fire/ice/lightning）+ **forged_only** | **只有升级配方**：`data/authoring/smith_recipes/anvil_<id>.json`，一件紫档原武器加 `material_inputs {"crystal:<fire/frost/lightning>": 3}`，200 金，`level 3`。两个入口：(a) 局内休息点的砧，`GameFlow.anvil_strike`（`core/run/game_flow.gd:1107-1123`）→ `Anvil.result`（`core/run/anvil.gd`）。**砧不查铁匠铺级数**，`anvil_open` 只看休息点和这座砧有没有用过（`game_flow.gd:1102-1103`）。(b) 基地铁匠铺 `Smithy.forge`，要求铁匠铺 ≥3 级（`smithy.gd:84`）。其他来源都没有：搜索、掉落、商店、敌人都被 `ItemDatabase.ids()` 的 `is_forged_only` 拦掉（`item_database.gd:93`） | **【已实现·可达】** | 没有携带限制；能卖 |
| `imperial_sword` 帝国佩剑 | weapon,melee,burst,one_hand,imperial,forged_only | `anvil_imperial_sword.json`：`mithril_sword` 加 `material_inputs {"metal": 4}` | 【已实现·可达】 | 同上 |
| `grand_magus_staff` 大魔导杖 | weapon,melee,staff,magic（**不是 forged_only**） | ① 铁匠铺配方 `smith_grand_magus_staff.json`：`fire_crystal_high`×1 + `magus_staff`×1 + `mithril_ingot`×2，400 金，铁匠铺 3 级，科技 `staffcraft` 3 级。② 敌人 `grand_magus` 的招牌装备（`data/authoring/enemies/grand_magus.json` `signature`），这个敌人在 `enemy_pools/standard_ruins.json` 里权重 0.6，kinds 是 core_ring/inner，节点 elite/core，只在 `free_mode`（魔法废墟）出现；掉落按 `standard` 规则，base 是 `base_chance[4]=0.05`，加上难度×0.05（DropRule 默认值）、幸运×0.02（`drop_rule.gd:17-23`、`drop_resolver.gd:17-24`），`min_drops 1` 时也可能被补抽中（`drop_resolver.gd:117-126`）。③ 随机池：它在 `ids()` 里，所以进得了局内商店（`economy_rules/standard.json` 的 `shop_rarity_weights[4]=2.0`）、集市散货摊（`base_rules/market.json` 的 `loose_rarity_weights`，金档 = 5）、搜索（`node_rules/*` 的 `search.rarity_weights[4]=1`，另受点上 rarity_cap 限制）、大地 3 级「头一回踩点送一件」（`faiths/earth.json` 的 `gift_on_enter`，battle 点给 weapon，没写 rarity_cap，`gift_on_enter_perk.gd`），还有敌人随机装备（受 `weapon_cap` 限制，`enemy_placer.gd:793`）。BOSS 保底金档优先从 treasure 标签的件里抽（`drop_resolver.gd:149-162`），rarity 4 有 `pale_shard`，所以抽不到法杖 | 【已实现·可达】（具体概率取决于点档位和上限，没有逐一算出） | 普通道具，能带能卖 |

**查过但没有命中的来源**（rarity≥4 的武器 id 都不在里面）：`drop_rules`（只有掉率表，没有点名件）、`reward_pools`、`bag_pools`、`market_stalls`（固定摊按级上限 0/1/2，`base_rules/market.json` 的 `rarity_cap_per_level`）、`hunters`、`loadouts`、`characters`、`techs`、`events`、`recipes`（23 条，相邻合成全是低档：`fuse_*` 输出 battle_axe、greatsword 等）。

---

## 三、`UniqueItems` / `RedSources` 机制

### 3.1 唯一性的键

- **按 item_id（`ItemDef.id`）**，不看实例 uid，不看显示名，也不看任务旗标。`UniqueItems.owned_ids` 返回 `{def.id: true}`（`core/run/unique_items.gd:9-44,56-60,86-91`）。判断「是不是独一」只看标签：`ItemDef.is_unique() = tags.has(&"unique")`（`core/inventory/item_def.gd:119-120`）。
- 劣化版是另一个 id，而且不带 unique，所以本体和劣化版互不影响（281 §四.4，`item_def.gd:55-56`）。
- 例外：NPC 专属对话额外有**永久旗标** `meta.npc_done[special_id]`（`npc_chatter.gd:51,56-57,128`），见 §四.4。

### 3.2 闸放在哪里（调用方，全部来自 grep）

| 调用点 | 时机 | 检查范围 | 证据 |
|---|---|---|---|
| 事件给物 `event_resolved` | 事件结算，东西落地前 | meta + 本局全部 | `run_state.gd:1043-1052` `UniqueItems.can_give(d, meta, self)` |
| NPC 专属对话的触发条件 `owned_nowhere` | 判条件 | **只看 meta**（run 传了 null） | `events/conditions/owned_nowhere.gd:9` |
| NPC 给物 `_give` | 给之前 | meta，加上调用方传进来的 run | `npc_chatter.gd:136-143` |
| 寂灭试炼要不要种 `JimiePath.plant` | 开局（局外状态接上之后） | meta + 本局 | `jimie_path.gd:40`，调用处 `game_flow.gd:990` |
| 试炼打赢给核 `JimiePath.reward` | 进尸体之前 | meta + 本局 | `jimie_path.gd:86` |
| 献祭条件 `JimiePath.sacrifice_ready` | 神坛判条件 | **只看背包棋盘 + meta**（`UniqueItems.owned(RED, meta)`，没传 run） | `jimie_path.gd:96-102` |
| 随机生成（搜索 / 掉落 / 商店 / 敌人 / 集市 / 送物） | 生成时 | 不判「有没有」，**直接把 unique 整类排除** | `item_database.gd:93`；`drop_resolver.gd:97,113,121` |
| 出售 / 上桌 / 附魔 / 赐福 / 事件扣物 | 操作时 | 禁止对 unique 做这些 | `meta_state.gd:587`、`item_actions.gd:75,96`、`shop_session.gd:146`、`forge.gd:140`、`blessings.gd:13`、`event_context.gd:101-102`（`takeable`） |
| 导入校验 | 导入数据时 | 专属对话 `give` 必须是 unique | `content_importer.gd:1033-1034` |
| 校准木桩 | 工具 | 同一个 unique 摆两件就报 `UNIQUE_REPEAT` | `calibration/scenario_check.gd:71` 【测试/工具】 |

**放进仓库（warehouse）时不判**：`Warehouse.try_add` 和 `rescue` 里没有 unique 检查（`meta/warehouse.gd:111-118`），撤离带回 meta.board 时也不判。唯一性完全靠「来源处把关 + 不能卖 / 复制」来维持，没有任何「入库时去重」的逻辑。

### 3.3 一件道具可能待的位置，`owned_ids` 看不看得到

| 位置 | 看得到？ | 证据 |
|---|---|---|
| 仓库各页 `meta.warehouse` | 看得到 | `unique_items.gd:16-17` |
| 带回来还没收的棋盘 `meta.board` | 看得到 | `:18-19` |
| 集市货架 `meta.market_stock` | 看得到（按 id，**不管 `sold`**；unique 本来就进不了货架，所以没影响） | `:20-21` |
| 本局背包棋盘 `run.board` | 看得到 | `:23` → `run_state.gd:1139-1148` `_owned_now` |
| 当前点的地上 `run.storage` | 看得到 | 同上 |
| 保险箱 / 托付 `SafeModule.inventory`（287 起叫「托付」，含已交出的 sealed 件） | 看得到 | 同上 `:1145-1147`；`modules/safe_module.gd:1-24` |
| 各点暂存的地上 `NodeStorageModule.nodes` | 看得到 | `unique_items.gd:24-27` |
| 待拾取的战利品（尸体）`run.pending_loot` | 看得到 | `:28-29` |
| 搜索收获箱 `events.current_search.haul_box` | 看得到 | `:32-33` |
| 正在开的商店棋盘（含「回购」：卖给商人的东西摆在他棋盘上，`shop_session.gd:12,64`） | 看得到 | `:34-35,64-65` |
| 存在节点里的商店棋盘 `node.content["shop"]["board"]` | 看得到 | `:43,68-74` |
| 等着开打的一场 `events.pending_battle.content` | 看得到 | `:36-37` |
| 地图每个点上敌人带的 `node.content.items` | 看得到 | `:38-42,77-83` |
| 包架 `meta.rack` | **看不到**（只放包，没影响） | `meta_state.gd:39` |
| 「照上回带」`meta.last_carry` | 看不到（只记 id 和位置，不是实例，`setup_screen.gd:427-450` 从仓库搬实例） | — |
| 寂灭试炼点的奖励键 `content["jimie_reward"]` | **看不到**（不在 items 列表里） | `jimie_path.gd:62` |
| 猎手身上（`HunterSystem`）| **看不到** | `hunter_system.gd:363-371`（每场现造 content）。猎手只拿劣化版，现在没影响 |
| 还没结算的事件 / 待发奖励 | 看不到（结算时才过闸） | `run_state.gd:1043-1052` |
| 结算屏、历史 `meta.history` | 不是容器 | — |

`owned_ids` 的源码注释（`unique_items.gd:3-5`）和上面这张表一致。

---

## 四、具体问题

### 4.1 同一把红武能不能从两个来源各拿一次？

- **按设计**：每把红武只有一个来源，而现在能真正拿到的只有寂灭和各颗核（破晓本体没有来源）。
- **核**：同一局最多种一个试炼点（`plant` 只换一个点，`jimie_path.gd:42-63`），打赢时 `reward` 还会再判一次 `can_give`（`:86`）。拿了两次第二次不给，测试 `tests/run/test_jimie_trial_281.gd:83`（「已经有了就不给」）覆盖了。
- **寂灭：静态看有一个漏洞（现在因为缺两颗核走不到）**。`sacrifice_ready` 只看背包棋盘和 meta（`jimie_path.gd:102`）。如果玩家把已经有的寂灭带进局，再挪到地上 / 保险箱 / 别的点暂存，`_first(board, RED)` 是 null，meta 里也已经没有它（带进局时实例从仓库搬走了），条件就会成立。再凑齐全黑法杖和四颗核（`plant` 只判核、不判寂灭，`:40`），就能献出**第二把寂灭**。另外 `jimie_sacrifice.gd:8` 也不过 `can_give`。现在这条路被「冰 / 毒之核没有来源」挡住了，属于**【无法确认 / 潜在】**，复现方法见 §六 R1。
- **事件给物**：同一个结算里给两次刹那只落地一件（`test_unique_281.gd:64-68`）。

### 4.2 没领的奖励占不占唯一性？

| 情况 | 占不占 | 证据 |
|---|---|---|
| 尸体里没拿的（pending_loot） | 占 | `unique_items.gd:28-29` |
| 走开后落到地上的（`discard_loot` → storage → NodeStorage） | 占（本局内） | `run_state.gd:369-377`；`unique_items.gd:24-27` |
| 种下但还没打的试炼点（奖励键） | **不占** | `jimie_path.gd:62`。打赢时 `reward` 再判一次，所以不会重复 |
| 搜索收获箱 | 占 | `:32-33` |
| 局结束时地上的东西 | 撤离不带走地上的（`node_storage_module.gd:1-3`），局结束就消失，自然释放 | — |

### 4.3 卖掉再回购能复制吗？

不能。unique 在所有出售入口都被拒：仓库单卖 `meta_state.gd:587`、批量卖 `sell_selected` 走同一个 `sell_item`、按钮 `item_actions.gd:75,96`、商店上桌 `shop_session.gd:146`。回购只认「这次卖给商人的」（`shop_session.gd:12,64`），unique 根本上不了桌，所以没有回购这条路。测试：`test_unique_281.gd:33`（`run_unsellable`）、`test_shop_barter_290.gd:252`。另外事件「失去道具」也不拿 unique（`event_context.gd:101-102`，报告 303）。

### 4.4 红武没了之后，限制在哪里解除？有没有永久旗标挡住重拿？

- **没有显式「解除」逻辑**。唯一性每次都现算：`owned_ids` 扫一遍所有容器（`unique_items.gd:9-44`）。实例不在任何容器里了（比如战败时连包一起丢、局结束时还在地上），下次检查自然就是「没有」。设计原意见 281 §四 ⑤：「丢了就不再拥有，任务可以重来」。
- **寂灭 / 核**：没有永久旗标。献祭消耗了全黑法杖和四颗核（`jimie_path.gd:120-122`），要重拿得重新养一把法杖（≥50 次进出局）再打四场试炼。所以**理论上可以重拿**，只是现在缺冰 / 毒两章，走不到。
- **破晓的信物：有永久旗标**。`talk()` 先写 `meta.npc_done["poxiao_start"]=true` 再给物（`npc_chatter.gd:127-129`），之后 `special_for` 只要 `done()` 就跳过（`:51`）。信物丢了以后（比如带进局后战败），`owned_nowhere` 会重新成立，但 `npc_done` 挡住，**没有任何重拿途径**。测试 `test_npc_chatter_282.gd:151` 的「以后没了破晓还能触发」只覆盖了「还没做过、因为已有而没触发」这种情况，没覆盖「做过之后丢了」。再加上破晓后续留白，这是设计上的空白（**【无法确认】**作者是不是有意为之）。
  - 小风险：`npc_done` 在 `_give` 之前写。仓库塞不下时最多加 4 页（`warehouse.gd:13,111-118`），还是失败就返回空，旗标却已经立了，信物从此拿不到。对 1×1 的信物几乎不会发生。

### 4.5 一次性任务红武有没有重拿途径？

- 寂灭：有（见上，没有旗标，要重做整条链），**现在走不到**。
- 破晓（信物）：**没有**（`npc_done` 永久）。
- 其余 6 把：本来就没有来源。

### 4.6 不同名的红武能不能同时拥有？

能。唯一性按 id 分开算，没有「全局只许一把红武」的规则。测试 `test_unique_281.gd:52-72`：仓库里有寂灭时照样能给刹那。281 §四 ⑤ 的原意也是「只会出现一把**同名**红武」。

### 4.7 老存档里有重复实例怎么办？

- **没有去重**。`run_migrations.gd`（v1→v4）和 `meta_migrations.gd`（v1→v4，`:36-58`）没有任何 unique 相关步骤。`SaveReconcile`（`core/save/save_reconcile.gd`）只处理删除 / 改名的道具、附魔、碎晶，`IdAliases`（`core/authoring/id_aliases.gd`）里也没有红武条目。`MetaState.from_dict` 读档时同样不查 unique。
- 后果：如果存档里已经有两件同 id 的 unique，读回来两件都在。`owned_ids` 只会显示「已有」，阻止以后再给，但不会删掉多出来的那件。
- 来源评估：红武在 281（v5.20）才加入，之前的老档不可能有。目前能产生重复的只有 §4.1 那个潜在漏洞，或者测试 / 校准工具（`RunState.start(...layout)`、`calibration/archetype_builder.gd`），属于**【测试专用】**。没有开发者「给物」的作弊入口（grep `func dev_` 只找到 `dev_set_tech_level`，`game_flow.gd:866`）。

### 4.8 其他附带发现

- `jimie_lesser` 是法杖、又不是 unique，所以也会记进出局次数，能变成「全黑法杖」（`item_instance.gd:85-95` 的 `tracks_runs` 只排除了 unique）。没有坏处，只是一个细节。
- `Anvil` 和 `Smithy` 的 `material_fits`（`smith_recipe_def.gd:60-65`）不排除 unique。元素之核是 `material` 标签、材质 `gem`、rarity 5，以后如果有配方的 `material_inputs` 写了 `gem`，核会被当成材料吃掉（基地铁匠铺优先挑稀有度最低的那件，`smithy.gd:70`；局内砧由玩家自己放）。**现在没有 `gem` 配方**（扫过 101 条 smith_recipes），属于潜在风险。

---

## 五、文档里的设计与实际落地（报告编号）

| 报告 | 设计 | 落地情况 |
|---|---|---|
| **281** §四 ⑤ | 全局一件：仓库、携带、本局各容器、已生成未拾取的，任一处有就不刷、不持有、不掉；接口拟名 `ItemDatabase.unique_owned`；三处闸（掉落 / `give_item` / BOSS 装备） | 实际做成 `UniqueItems`（v5.20 PR #468）。掉落和敌人装备是「整类排除」而不是「查有没有」；事件给物有闸；NPC 给物和试炼有闸 |
| 281 §四 ⑥ / §四.3 | 来路 A：每把一条任务链 | 寂灭（v5.22 / v5.23 / v5.24，PR #475/#478/#479）代码已全，但冰 / 毒两章没有，**走不通**；刹那 / 断水只记录了原文；双生 / 贯日 / 崩山 / 坠星被作者 15:37 作废 |
| 281 §四.4 | 来路 B：BOSS / 猎手持有劣化版，概率受难度影响 | v5.21 PR #471、v5.25 PR #484 落地（腾地方最多拿掉 3 件） |
| 281 §四.4 | 「黎明首领拿本体、固定掉」 | 被 282 作废（破晓改成从铁匠起步），代码里没有 |
| **282** §2.3 | 破晓起点：铁匠铺 3 级给 `poxiao_token`，之后留白（记在 `/mnt/project-files/reference/待做-系统.md`，本次没读） | v5.29 PR #492 落地起点；后续 **【仅设计 / 留白】** |
| 287 | 保险箱并进免费撤离点，叫「托付」；寂灭计数改成「经托付回家」 | 托付容器 `SafeModule` 在唯一性检查范围内 |
| 290 | 红武不能上商店的桌；回购只限本次 | 已落地，测试 `test_shop_barter_290.gd:252,312` |
| 292 §174 / 294 | 校表工具要排除 unique / lesser；校准木桩查「独一不重复」 | `scenario_check.gd:71` 已有 |
| 303 §2.6 | 事件拿得走的（takeable）不含 unique | `event_context.gd:101-102` |
| `docs/status.md:18,64,124` | 8 把红武的独有机制**没做**；独一共 13 件；A1 待定：刹那 / 断水开不开做 | — |
| `docs/plans/2026-11-09-claude-next-execution.md:178-180`、`2026-11-11-events-and-ui-comprehension.md:43` | 不能擅自补完破晓 / 寂灭任务 | — |

---

## 六、静态定不了的情况：最小复现步骤

**R1 第二把寂灭（§4.1）**：写一个 GDScript 测试，仿照 `tests/run/test_jimie_altar_281.gd:8-17`：
1. 用 `_run()` 造一局：背包里有 `magic_staff(runs=50)` 和四颗核。
2. `run.storage.admit(ItemInstance.create(items.get_def(&"jimie")))`，也可以放进 `SafeModule.of(run).inventory`。
3. 断言 `JimiePath.sacrifice_ready(run.board, run.meta)`。预期（按静态阅读）是 **true**，然后 `JimiePath.sacrifice(...)` 会造出第二把，`UniqueItems.owned_ids` 里 jimie 只记一次，但实例有两件。
4. 对照：把 jimie 放进 `run.meta.warehouse`，结果应为 false（现有测试 `:34-36` 就是这种情况）。

**R2 信物丢了不能重拿（§4.4）**：仿照 `test_npc_chatter_282.gd:133-152`：
1. 铁匠铺设 3 级，`talk` 拿到信物。
2. 从仓库删掉信物（`meta.warehouse.remove(uid)`，模拟带进局后战败丢失）。
3. 再 `talk`。预期 `special` 为空（被 `npc_done` 挡住），`OwnedNowhere` 却是 true。

**R3 冰 / 毒核能不能拿到**：对 `JimiePath.element_of(chapter)` 依次遍历 `data/authoring/chapters/*.json`，只有 free_mode→fire、clockwork_hourglass→lightning，没有章节对应 ice / poison（`jimie_path.gd:14`）。

**R4 劣化版实际持有率**：跑 `tests/run/test_red_sources_281.gd`。核心点的档位到底是不是 ≥3 静态定不了（要看地图生成），需要在魔法废墟和机关沙漏里各开一局，检查 core 点的 `content["strength"]`。【无法确认】

---

## 七、测试覆盖

| 测试 | 覆盖内容 |
|---|---|
| `tests/inventory/test_unique_281.gd` `run_reds` / `run_unsellable` / `run_owned` | 8 把红武是 5 档、带 unique，不进随机池；不能卖（仓库、批量、商店、铸牌）；仓库或地上有就算已有，事件不重复给，不同名照给 |
| `tests/run/test_red_sources_281.gd` | 持有率、掉落率、武器类映射；替换后真的摆上棋盘、记过就不再掷；腾地方；常规掉落不掉劣化版 |
| `tests/run/test_jimie_trial_281.gd` | 单元素受伤；开局种试炼（要求核哪儿都没有）；核是独一、不能卖，已有就不给 |
| `tests/run/test_jimie_altar_281.gd` | 献祭条件（**只测了寂灭在仓库的情况**）、献祭、流程、黑洞动画 |
| `tests/meta/test_npc_chatter_282.gd` `run_poxiao_start` / `run_save` | 3 级给信物；已有破晓不触发也不记旗标；`npc_done` 跟着存档走 |
| `tests/run/test_shop_barter_290.gd:252,312` | 红武不能上桌；回购 |
| `tests/inventory/test_sealed_items.gd`、`tests/battle/test_balance_statistics.gd` | grep 命中了 unique / lesser 相关字样，内容没细看 |
| **没有覆盖的** | 寂灭在地上 / 保险箱 / 别的点暂存时献祭（R1）；信物丢了以后重拿（R2）；老档里有重复 unique 怎么读；`pending_battle`、各点商店存档、地图节点这些容器的 owned_ids 检查 |
