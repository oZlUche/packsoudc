# 合成发现、图鉴、悬浮窗与存档 —— 真实调用链调查

仓库根目录，提交 254f084c（只读调查）。行号以该提交为准。
标记约定：**[已实现且可达]** / **[配置存在但未接通]** / **[仅设计文档]** / **[测试专用]** / **[无法确认]**。

---

## 0. 结论速览

- 局内拼接（相邻 + 小锤）完整可达，但**没有预览窗、没有确认步**：按下小锤立即合成（`ui/inventory/inventory_view.gd:434-438`）。
- 拼接 / 拖合成功后**只记** `RunState.tally["crafts"] += 1`（`core/run/modules/crafting_module.gd:90,136`），**不点亮图鉴、不记 recipe_id、不触发成就**。产物要等撤离（或进保险箱）时才由 `MetaState.absorb → _record_codex` 点亮。
- 营地砧 `GameFlow.anvil_strike` 与基地铁匠铺 `Smithy.forge` 会**立刻**调用 `meta.light_codex(out.def)` 点亮图鉴（`core/run/game_flow.gd:1121-1122`、`core/meta/smithy.gd:130`）。
- 全项目**没有**按配方记的「已发现配方」字段（run 存档、meta 存档、全局都没有）。图鉴只有 `MetaState.codex: {item_id → 件数}`（`core/meta/meta_state.gd:43`）。
- 悬浮窗「可拼为 / 可升为」以及配方子窗、`UpgradeCompare`、铁匠铺格子、拖合的「合成 → X」提示，**都不看图鉴**，会把未知产物的名字、图标、稀有度色和整段属性全部显示出来。只有百科「合成」页（`core/text/encyclopedia.gd:294-322`）和图鉴格（`ui/game/codex_tile.gd:55`）按图鉴遮名。

---

## 1. 局内相邻拼接（RecipeDef.adjacent = true）

### 1.1 调用链 [已实现且可达]

| 步骤 | 实际代码 |
|---|---|
| 配方装载 | `ui/game/game_director.gd:98` `flow.recipes = RecipeDef.load_all()` → `core/run/game_flow.gd:1606-1608` 把 `recipes` 交给 `CraftingModule.recipes`（模块注册在 `core/run/modules/run_modules.gd:12`）|
| 两件相邻 | `Fusion.pairs(board, recipes)`（`core/inventory/fusion.gd:12-38`）：遍历棋盘上每件的每格，看上下左右四个方向的邻格（`DIRS`，第 7 行），跳过包（`board.acts_as_bag`，第 19 行），每对 (a<b) 只算一次 |
| 配方匹配 | `RecipeDef.find(recipes, a.def.id, b.def.id, true)`（`fusion.gd:34`；`core/inventory/recipe_def.gd:40-45`：要求 `def.adjacent == fuse` 且 `matches()` 不分顺序）|
| 提示（小锤徽）| `InventoryPanel._refresh_fusions()`（`ui/game/inventory_panel.gd:70-73`）挂在 `_run.board.changed`（第 59 行）上，算出 `board_view.fusions = crafting.fusion_pairs()`；`InventoryView.fusions` 的 setter 重画（`ui/inventory/inventory_view.gd:122-125`），`_draw_fusion_fills` / `_draw_fusions`（657-690 附近）画并集描边和铜徽 `bag/fuse_badge`（126-128）|
| 预览 | **没有**。停在铜徽上反而**不弹**道具窗（`ui/inventory/hover_tip.gd:1272`，v5.43 起，见 279 §八「不另加『拼成 X』的字」）。唯一能看到产物的途径是事先停在某个输入件上读「可拼为」那一行（见 §4）|
| 确认 | **没有**。`InventoryView._gui_input` 鼠标左键**按下**（且不是双击）命中铜徽就 `fuse_requested.emit`（434-438）；注释写明「`_pressed` 留给『松开才合』，现在按下就合」（126）|
| 执行 | `inventory_panel.gd:120` `board_view.fuse_requested → crafting.fuse(a, b)` → `CraftingModule.fuse`（`crafting_module.gd:104-138`）：重新跑一遍 `Fusion.pairs` 来校验这一对（110-115）→ `Fusion.fuse(board, a, b, out_def)`（123）|
| 消耗与成品生成 | `Fusion.fuse`（`fusion.gd:84-106`）：`begin_batch` → 移除两件 → `ItemInstance.create(out_def, a.rotation)`（**新实例**）→ `landing()` 放进两件原占格的并集（56-79）→ 放不下就 `try_add` 到棋盘任意位置 → 还放不下就两件原样放回、返回 null |
| 落地上兜底 | `CraftingModule.fuse` 123-131：`Fusion.fuse` 返回 null 时新建一件 `admit` 进 `_run.storage`（地上），再移除两件；地上也放不下就 `failed`，棋盘不动 |
| 记录 | 只有 `_run.tally["crafts"] += 1`（136）和 `done.emit(detail)`（137）|
| 反馈 | `done` → `InventoryPanel._on_crafted`（282-285）发一句提示 `craft.done`（`core/text/ui_text.gd:797`）；`map_screen.gd:590-594` 写进地图日志 |
| 存档 | `fuse` **不调用** `GameFlow.save()`；棋盘变动要到下一个存档点才进 run 存档。`tally` 随 run 存档存（`core/run/run_state.gd:1207,1335`）|
| 结算与统计 | `RunResult.crafts = tally.crafts`（`core/run/run_result.gd:79`）→ 计分 `crafts * explore_points("craft")`（121）→ 写进对局历史行（157）→ 记录窗显示「搜索 / 合成」（`ui/game/run_records_window.gd:138`）|
| 图鉴 / 成就 / 配方知识 | **都没有**。`CraftingModule` 里没有 `meta` 引用；成就种类没有合成相关的（`core/meta/achievement_def.gd:11`）|

可达范围：所有挂 `InventoryPanel` 的屏都能用（地图背包窗 `ui/game/bag_window.gd:14`、商店、搜索 / 容器、神坛、铸炉、求饶、保险箱、战前，见 `game_screen.gd:180`、`prebattle_screen.gd:99` 等）。只在 `board_view`（玩家棋盘）上；勾选模式下不画、也不响应（`inventory_view.gd:605-613, 674`）。

### 1.2 配方数据

`data/authoring/recipes/` 共 23 张。其中 **14 张 `adjacent: true`**（全是 `fuse_*.json`）：
knife+knife→twin_blades、shortsword+shortsword→greatsword、hand_axe+hand_axe→twin_axes、club+club→great_club、hand_axe+whetstone→battle_axe、shortsword+whetstone→broadsword、felling_axe+whetstone→great_axe、knife+whetstone→quenched_dagger、wooden_stick+shortsword→long_spear、wooden_stick+hand_axe→pole_axe、wooden_stick+knife→short_spear、wooden_stick+flint→stone_maul、hand_crossbow+wooden_stick→light_crossbow、crude_bow+tanned_leather→shortbow。

### 1.3 旧的拖上去合（adjacent = false，`CraftingModule.craft`）[已实现且可达]

- 接线：`inventory_panel.gd:110-119` 给 `DragLayer` 配 `craft` / `craft_grid = _run.board` / `craft_drop → crafting.craft(a, b_uid)` / `craft_note`。拖动时 `DragLayer._craft_target`（`ui/inventory/drag_layer.gd:887-900`）判断能不能合，残影下方写「合成 → 产物名」（`bag.craft`，`drag_layer.gd:925-929`，`ui_text.gd:403`）加作者写的 `note`；松手时调 `craft_drop`（795-797）。
- `CraftingModule.craft`（`crafting_module.gd:60-92`）：b 拆下，新实例落在 b 原来的位置和朝向；放不下就 `try_add`，再不行就进地上；都不行就 b 放回、返回 failed。记账同样只有 `tally.crafts`（90）。
- 用这条路的 9 张配方：antidote_satchel、bandage_roll、field_rations、healing_draught、panacea、poisoned_knife（knife+poison_vial）、salted_meat、strong_salve、styptic_dressing（基本都是消耗品阶梯，124 号报告；测试 `tests/content/test_upgrade_tiers.gd`「粗盐块压到口粮上 → 腌肉干」）。
- 两条路互不相通：`RecipeDef.find(..., fuse)` 只返回 `adjacent == fuse` 的配方（`recipe_def.gd:43`）。测试 `test_fusion_279.gd` run_pairs 断言「涂毒匕首是拖上去合的，贴着不出锤」。
- 悬浮窗「可拼为」**只列 adjacent 配方**（`ItemTooltip.fuse_recipes`，`ui/inventory/item_tooltip.gd:451-457`），拖合配方在道具悬浮窗里没有任何关系行；只出现在百科「合成」页（encyclopedia 的 `recipes` 是全部 RecipeDef，`game_flow.gd:905`）。

---

## 2. 营地砧与基地铁匠铺

### 2.1 营地砧 [已实现且可达]

| 步骤 | 实际代码 |
|---|---|
| 入口 | 休息屏「铁炉」→ 铸炉屏（`ui/game/forge_screen.gd`），左上压一块 `AnvilColumn`（`forge_screen.gd:151-156`）；286 v5.34 落地 |
| 能不能锤 | `GameFlow.anvil_open(node)`（`game_flow.gd:1103-1104`）：run 没结束、`NodeEvents.effective_type(node) == &"rest"`、`not Anvil.used(node)` |
| 一营一次 | `Anvil.USED_KEY = "used_anvil"` 写进 `node.content`（`core/run/anvil.gd:7, 71-78`）；`MapNode.content` 跟 run 存档走（`core/map/map_node.gd:42,65`）|
| 放件 | 武器槽 / 材料槽是两个独立的临时 `GridInventory`（`anvil_column.gd:168-171`），**不属于 RunState**；drop_filter 拒收玩家锁定的件、一槽一件、出件槽只出不进（152-161）；双击 / 右键快速放 `quick_slot`（241-248），同样拒收锁定件 |
| 配方匹配 | `Anvil.upgrades_for`（`anvil.gd:19-29`，`is_upgrade`：一件输入 + `material_inputs` 不空，第 33-34 行）→ `recipe_for`（38-45，按配方 id 排序后取**第一张**配得上的）→ `material_fits`（`core/meta/smith_recipe_def.gd:60-66`）|
| 预览 | `AnvilColumn.preview()` = `Anvil.result(...)`（`anvil_column.gd:219-222`；`anvil.gd:58-68`）：出件槽淡影 + `compare.show_pair(w, made)`（`anvil_column.gd:300-303`）；便条列出这把能升成的每一把（`upgrade_line`，331-339）；配不上则材料槽红框 + `need_line`（305-307, 322-326）|
| 确认 | 锤键 `strike_key.pressed → strike()`（196, 225-236）；键可用条件 `open and made != null and out 空`（314）。这一下就是确认，没有二次确认 |
| 执行 | `GameFlow.anvil_strike`（`game_flow.gd:1109-1124`）：`anvil_open`、两件都没被玩家锁定 → `Anvil.result` → 两件从各自容器移除 → `Anvil.use(node)` → `meta.light_codex(out.def)` → `save()`（只存 run）|
| 出件去向 | 回到 `AnvilColumn.strike`：`out.try_add(made)`，放不下就进地上（232-234）|
| 费用 | **免费**：`anvil_strike` 不读 `recipe.funds`，也不检查 `recipe.level` 或 `tech`。82 张升级配方（含 3 级的升橙）在营地砧上**全部可用**（这是按代码读出来的结论，设计上是否本该如此 [无法确认]；279 §二.2 只写了「休息点砧免费、每个休息点一次」）|
| 记录 | 只有图鉴点亮。**没有** `tally`、没有成就、没有日志；没有 recipe_id 记录。图鉴写在内存里的 `MetaState`，要等下一次 `save_meta()` / 结算 `MetaSave.write`（`game_flow.gd:1329`）才落盘 |

### 2.2 基地铁匠铺 [已实现且可达]

- 界面 `ui/game/smithy_panel.gd`：列出 `flow.sorted_smith_recipes()` 的**全部**配方（`game_flow.gd:787-797`；`smithy_panel.gd:145-176`），每格显示产物图和名字；打不了的格子压暗（`cell_.lit = why == ""`），悬停 tooltip 写原因（172-173）。不按图鉴过滤，也不按科技隐藏。
- 打造：`GameFlow.forge(id)`（`game_flow.gd:806-813`）→ `Smithy.can_forge`（`smithy.gd:79-97`：科技 `knows` → 铺子级数 `recipe.level > level(meta)` → 素材 → 钱 → 仓库放得下）→ `Smithy.forge`（101-132）：扣材料类（稀有度最低的先用，`material_picks` 56-75）、扣点名素材（按仓库顺序，跳过锁定件）、扣 `funds`、产物 `meta.allocate_uid()` 进仓库、`meta.light_codex(out.def)`、`changed.emit()` → `save_meta()`。
- 费用（数据）：升蓝配方 60、升紫 120（铺子 2 级）、升橙 200（铺子 3 级）；普通配方 20–400（`data/authoring/smith_recipes/*.json`）。279 §二.2 写的「60 / 150 / 300」与数据不一致，数据以 279 §八 v5.11 的「120 / 200」为准 [仅设计文档：60/150/300]。
- 升级类配方的预览：`Smithy.preview`（`smithy.gd:137-156`）→ `SmithyPanel._show_compare`（`smithy_panel.gd:210-221`）；仓库里没有那把就左窗按品质 0、整窗压暗。

### 2.3 品质继承

- `ItemInstance.quality()` / `set_quality()`，键 `state["quality"]`，0–2（`core/inventory/item_instance.gd:59-74`）。
- 砧：`Anvil.quality_of`（`anvil.gd:49-55`）= max(原武器品质, 材料稀有度 − 配方要求)，夹到 `QUALITY_MAX = 2`，不累加。
- 铁匠铺：`Smithy.forge` 108-123：材料类取超出的档数，点名输入取各自的 `quality()`，所有值取 max。
- 拼接 / 拖合：`ItemInstance.create` 生成新件，**不继承**品质（`fusion.gd:93`、`crafting_module.gd:73`）。

### 2.4 ItemInstance 上实际存在的字段，以及合成 / 升级后是保留还是重置

`ItemInstance` 的成员：`uid`、`def`、`rotation`、`origin`、`container_id`、`placed_seq`、`state`（`item_instance.gd:12-33`）。`state` 里出现的键：`charges`（`WearProfile.CHARGES_KEY`）、`quality`、`runs` / `run_in`（法杖进出局计数）、`locked`、`benched`、`pinned` / `pin_moves`、`growth_ticks` / `growth_stage` / `growth_bonus` / `honor`（`core/inventory/growth_profile.gd:14-18`）、`enchant`（武器附魔，`core/forge/forge.gd:12`，写入见 `inventory_service.gd` 约 305 行），以及铸牌自己的 `enchant` / `value`。
**没有** ammo / loaded 字段：弓弩的箭是棋盘上装载格里的另一件道具，不是实例状态。

四条路的产物全都是 `ItemInstance.create(...)` 新建的，所以一律**新 uid、`state` 清空**。之后只有：
- `charges` 补满（`create` 第 39-40 行）。
- 砧 / 铁匠铺另外写 `quality`。
- 朝向：拼接取 a 的朝向（否则试别的）；拖合取 b 的朝向；砧和铁匠铺是 0。

因此**附魔 `enchant`、生长、法杖 `runs`、`benched` 全部丢失**；`locked` 不会传过去，因为砧和铁匠铺本来就拒收锁定件。`UpgradeCompare` 左窗画的是真实例（带附魔），右窗是新件，所以「附魔会掉」这件事能从两窗对比里看出来。但金线只标右窗新增或改动的行，**不标左窗被删掉的行**（`upgrade_compare.gd:66` `differing(_lines(left), _lines(right))`）。

---

## 3. 图鉴 / 配方知识 / 铁匠铺权限

### 3.1 图鉴字段与写入点

- 字段：`MetaState.codex: Dictionary`，道具 id 字符串 → 累计件数，点亮条件是 > 0（`meta_state.gd:42-43`；`codex_lit` / `codex_count` 在 536-541）。存档键 `"codex"`（738），读回在 834-836。meta 存档文件 `user://meta.json`（`meta_save.gd:10`）。作用域：**全局（跨局、按存档位）**。
- 写入点（全部调用方）：
  1. **撤离时带出的件**：`MetaState.absorb` → `_record_codex(inst, got)`，对 `result.carried` 每件记一次（262-263）[已实现且可达]。
  2. **保险箱 / 托付的件**（撤离和战败都算）：`absorb` 307-308 [已实现且可达]。
  3. **基地铁匠铺打出**：`Smithy.forge` → `light_codex`（`smithy.gd:130`）[已实现且可达]。
  4. **营地砧锤出**：`GameFlow.anvil_strike` → `light_codex`（`game_flow.gd:1122`），在局内立即点亮、和之后撤不撤离无关 [已实现且可达]。
  5. 铸牌不进图鉴（`meta_state.gd:384-385, 394`）。
- **不会**点亮的情况：看见、捡起、进背包、商店里看到、拼接 / 拖合产出、战斗掉落但没带出。
- 点亮的使用者：百科遮名（`game_flow.gd:908`）、图鉴格（`ui/game/meta_screen.gd:888-896`）、成就 `codex_count`（`achievement_def.gd:55-58`）、计分里的 `lit`（`meta_state.gd:322`）、书架与记录碑计数（`meta_screen.gd:1033`、`ui/widgets/records_stele.gd:86`）。
- 设置里「名字全显」`settings.reveal_names`（`game_flow.gd:915-916`）会让百科和图鉴不再遮名。

### 3.2 配方知识

**不存在**任何按配方记的记录。在 core/ 和 ui/ 里搜 `recipe_seen|known_recipes|recipes_known|recipe_known|discovered`，结果为零；`MetaState.to_dict`（734-760）和 `RunState.to_dict` 里也没有配方相关的键。测试 `test_tutorial2.gd:271` 甚至断言 run 存档里「没有配对表」（`pending_crafts`，087 时代遗留的配对表已删除）。

### 3.3 铁匠铺配方权限

- 铺子级数：`Smithy.level = meta.facility_level(&"smithy")`（`smithy.gd:11-12`），由科技「高级配方」（id 是 smithy）决定；配方字段 `SmithRecipeDef.level` 1–3（`smith_recipe_def.gd:24`）。
- 科技：`SmithRecipeDef.tech` / `tech_level`（26-27），用 `Smithy.knows` → `TechService.level` 判断（`smithy.gd:16-17`）；目前用到的科技只有 `staffcraft`、`mithril_smelting`（四张法杖、两张秘银）。
- `requires_unlock` 是 **ItemDef** 的字段（`core/inventory/item_def.gd:209`），用于成就解锁道具池（`item_database.gd:11-28`、`achievements.gd:61-86`），`SmithRecipeDef` **没有**这个字段。
- 这些权限和图鉴**不共用字段**：铺子级数和科技都在 MetaState 的科技 / 设施进度里，图鉴是单独的 `codex`。
- 营地砧完全不看级数和科技（见 2.1）。

---

## 4. 悬浮窗的关系行与泄露

### 4.1 现在显示什么 [已实现且可达]

- 道具悬浮窗正文（`ItemTooltip`，`ui/inventory/item_tooltip.gd:222-229`）：敌方棋盘（`wild`，130 行）以外，
  - `fusions_line(def)`（461-475）：「可拼为：+ 搭档 → 出件　+ …」（`tip.fuses_to` / `tip.fuse_pair`，`ui_text.gd:285-286`）。搭档是道具词 `[url=item:<id>]`（`item_word`，443-444），出件是配方词 `[url=recipe:<fuse_id>]`（`recipe_word`，438-439），都按稀有度上色。两个输入件的悬浮窗都写；**产物那边不反写**「由 X 拼成」（298 待定 2）。
  - `upgrades_line(def)`（417-428）：只对 weapon 标签生效，「可升为：A / B」。同一个产物有几张配方时只写一次（`seen[r.output]`，422）。数据源是 `Anvil.recipes()` 全表，不看铺子级数和科技。
- 停在配方词上：`HoverTip`（`hover_tip.gd:699-700, 1129-1131`）→ `ItemTooltip.recipe_full`（505-526）：产物的**整段悬浮窗**（品质 0）+ 同一产物、同一输入的每张砧配方各写一行「要」+ 品质说明 + 「休息点的砧 / 基地铁匠铺（金币）」。拼接配方走 `_fuse_full`（480-497）：产物整段 + 「要　甲 + 乙」。
- 停在道具词上：`hover_tip.gd:692-697` 打开该道具的整段悬浮窗。子窗可以一路往下开，深度上限 `MAX_DEPTH` 3（286 / 298）。

### 4.2 未知产物会不会泄露

**全部泄露，没有任何地方按图鉴遮挡。** `item_tooltip.gd` 里没有 `codex` 或 `meta` 的引用（只 grep 到 `@tip_meta` 这样的颜色名）。泄露清单：
1. 「可拼为」「可升为」直接写出产物名和稀有度色。
2. 配方子窗显示产物的**完整**说明（名字、图标所在头部、稀有度、全部数值和句子）。
3. 营地砧的便条（`upgrade_line`：名字 + 稀有度色 + 材料类）、出件槽淡影（产物图）、`UpgradeCompare` 右窗（产物全部属性）。
4. 铁匠铺的全部配方格（产物图和名字，`smithy_panel.gd:169-171`）、配方卷轴、`UpgradeCompare`。
5. 拖合时的「合成 → 产物名」（`drag_layer.gd:928`）。
6. 基地图鉴里**已点亮**道具的悬浮窗（`meta_screen.gd:975-976` `show_kind`）照样带「可拼为 / 可升为」，可以点进**未点亮**产物的完整子窗。图鉴格本身对未点亮的件只写「？」（`codex_tile.gd:55`，悬浮窗 `meta.codex_unseen_tip`，983 行）。

真正按图鉴遮挡的只有两处：百科「合成」页（`encyclopedia.gd:294-322`：三件里有任何一件没点亮就写「？」、不写 note）和图鉴格 / 百科「相关道具」（`_item_name`，316-322）。

---

## 5. 边界情况

| 情况 | 代码行为 |
|---|---|
| 同一对两件对应多张配方 | `RecipeDef.find` 取第一张（`load_all` 按文件名排序，`recipe_def.gd:33-36, 40-45`）。目前的数据里没有同一对输入对应两张 adjacent 配方的情况 |
| 一件同时和几件相邻、各自都能拼 | 每一对各出一枚铜徽（`fusion.gd:29-37`），例如小刀同时贴着小刀和磨刀石。合掉一对后 `board.changed` → `_refresh_fusions` 重新计算，另一枚铜徽消失 |
| 砧上一把武器配多张配方 | `recipe_for` 按 id 排序取第一张能配上的（`anvil.gd:38-45`）。现有数据里不同配方要的材料类不同，所以实际不会冲突 |
| 棋盘满 | `Fusion.fuse`：并集 → `try_add` → 两件原样放回、返回 null（`fusion.gd:94-104`）；然后 `CraftingModule.fuse` 改放地上（123-131）；地上也满就 failed、棋盘不动。拖合同理（`crafting_module.gd:77-84`）。砧：出件进出件槽，放不下进地上（`anvil_column.gd:232-234`）|
| 玩家锁定 / 随身之物 / 扎根 | **拼接和拖合都不检查**：`Fusion.pairs` 只跳过包（`fusion.gd:19`），`Fusion.fuse` / `GridInventory.remove`（`grid_inventory.gd:421-436`，注释写明核心层 remove 不看锁）。所以玩家锁定的件也能被拼掉，这和 `item_instance.gd:113` 的「锁住的……不进铸炉」精神不一致。目前没有随身之物或会扎根的道具在拼接配方里（marcus 的 `legion_phalera` 不在配方里），属于潜在风险。砧和铁匠铺**会**检查锁定（`game_flow.gd:1110`、`anvil_column.gd:158, 242`、`smithy.gd:46, 68, 119, 145`）。`core/run/lock_hold.gd` 是宝箱长按开锁的状态机，和这里无关 |
| 取消 | 拼接没有取消的概念（按下就合）。拖合：拖拽中按右键取消（`inventory_view.gd:446-447` 注释）。砧：把件拖回或双击收回（`take_back`，`anvil_column.gd:251-256`），离开时 `release()` 把三个槽里的东西送回背包或地上（259-268，`forge_screen.gd:358-360`）|
| 重复点击 | 双击的第二下被 `not mb.double_click` 过滤（`inventory_view.gd:433`）。陈旧的铜徽会因 `CraftingModule.fuse` 重新校验 `Fusion.pairs` 而返回 failed（110-115）。砧：锤过以后 `anvil_open` 为假、出件槽有东西，锤键禁用（314），`anvil_strike` 再次校验（1110）|
| 合成过程中切屏 | 拼接和拖合都是同步的一次调用，没有动画或中间状态，不存在「半合成」。砧：`anvil_strike` 先 `save()`（1123），之后才把出件放进出件槽（`anvil_column.gd:232`），而三个槽本身不在 RunState 里。正常离开会走 `to_map → release()`，东西会回背包；但如果锤完后不经 `to_map` 直接关掉程序，run 存档里两件输入已经扣掉、出件却不在档里，存在**丢件风险** [无法确认：需要验证关窗时的处理；`save_and_quit` 只在地图暂停菜单里，`map_screen.gd:380`]。图鉴点亮在内存里，同样要等下一次 meta 写盘 |

---

## 6. 目标矩阵

| # | 目标 | 状态 | 依据 |
|---|---|---|---|
| a | 组合合法、产物未点亮 → 显示「可合成」、产物写 ???、仍显示会消耗什么 | **部分支持** | 「可合成」：铜徽 + 并集金虚线已有（`inventory_view.gd:657-690`），金虚线圈出两件，等于在说这两件都会被吃掉，但**没有文字**写消耗。产物 ???：**缺失**，所有关系行和子窗都显示真名和完整属性（§4.2）。铜徽本身没有悬浮窗（`hover_tip.gd:1272`）。也没有预览和确认步（`inventory_view.gd:434`）|
| b | 组合合法、产物以前拿到过 → 能看产物，但不会因此把所有含它的配方都标成已发现 | **部分支持（平凡成立）/ 待决策** | 现在不管拿没拿到过都能看产物（不看图鉴）。由于根本没有配方发现记录，「不会误标」是平凡成立的。要真正区分，得先有配方级记录（§3.2）|
| c | 第一次合成成功 → 记下 recipe_id，输入和产物的悬浮窗里出现链接 | **缺失** | 成功后只有 `tally.crafts += 1`（`crafting_module.gd:90,136`），不记 recipe_id，拼接也不点亮图鉴。悬浮窗的链接（配方词 / 道具词）**始终都在**，不受首次合成控制；产物那边没有反向链接（298 待定 2）|
| d | 只看到提示或中途取消 → 不记录 | **已有支持（平凡成立）** | 提示和预览不写任何状态。`Fusion.pairs`、`Anvil.result`、`Smithy.preview` 都是纯函数。唯一的写入点是成功执行时：砧和铁匠铺在执行那一下点亮图鉴（`game_flow.gd:1122`、`smithy.gd:130`），预览不点亮 |
| e | 一个产物有多张配方 → 区分「知道产物」和「发现了某张配方」 | **缺失 / 待决策** | 图鉴只按 item id 记。悬浮窗「可升为」按产物去重（`item_tooltip.gd:422`）；`recipe_full` 只把同一输入、同一产物的几张配方合在一起写（513-517）。数据里一个产物多张配方的例子：berserker_twin_axes、bloodbone_spike、bloodoath_axe、bonesteel_* 等 `_2` 双来路；longbow（anvil_longbow + smith_longbow）；shortbow（fuse_shortbow + smith_shortbow）；bloodletter（anvil + smith）；heavy_crossbow（同一把钢弩 + 木或骨）|

需要拍板的设计问题：
- 拼接产物要不要在合成那一下就点亮图鉴？现在砧会立刻点亮，拼接不会，两者不一致。
- 砧在局内点亮图鉴，算不算「带出」？
- 营地砧不看铺子级数和科技，这是有意的吗？
- 锁定件能被拼掉，要不要拦？
- 悬浮窗是否改成按图鉴 / 配方知识遮挡？`reveal_names` 开关可以复用。

---

## 7. 相关测试

| 文件 | 覆盖 |
|---|---|
| `tests/inventory/test_fusion_279.gd` | run_pairs（只有相邻才算、斜角不算、一对只出一次、接缝位置；拖合配方和不相邻的不出锤）；run_fuse（两件消失、落在并集里、放不下找位、哪都放不下原样放回）；run_bag_board（包里的件能拼、包本身不参加）；frame_badge（铜徽画在接缝上、点击发 `fuse_requested`、勾选模式不响应）；run_help（说明页中英都写了小锤）；run_module（`fusion_pairs` / `fuse` 记 `tally.crafts`、发 `done`、不相邻的不合）。**没有**锁定件、地上兜底、图鉴的测试 |
| `tests/run/test_anvil_279.gd` | run_logic（`upgrades_for` / `recipe_for` / 品质取较高）；run_strike（两件被拿走、出件带品质、砧用掉、不能再锤、锁定的不让锤、**图鉴点亮** 第 62 行）；run_tooltip（「可升为」一行）；frame_camp_anvil（286：铁炉两栏屏、状态句、红框、锤完变灰；「这把没有可升的」）；run_orange（魔晶石升橙、只能锻造、图鉴照列）|
| `tests/meta/test_anvil_recipes_279.gd` | 内容：升蓝 30 / 升紫 32 / 升橙张数、工钱、级数；`material_fits`；铁匠铺打升级配方（最便宜的材料先用、跳过锁定件）；导入器；run_fusions（14 张拼接配方、只能按相邻查到、拖合查不到）|
| `tests/meta/test_smithy_251.gd` | 内容和科技；run_forge（级数不够、缺件、扣钱、进仓库、**图鉴点亮** 第 77 行、跳过锁定件）；仓库满时不打；导入器；分组；排序 |
| `tests/meta/test_recipe_techs_252.gd` | 科技门槛（秘银冶炼、法杖工艺）、科技卡上写的「会打」、打法师杖、导入器、集市 |
| `tests/ui/test_fusion_compare_298.gd` | 「可拼为」两边都写、道具词 / 配方词、拼接子窗写「要」；升级类配方识别、`Smithy.preview`（仓库没有时左边为空）；两窗并排和金线、左窗压暗；只在悬停时显示（0.2 秒后收起）|
| `tests/ui/test_recipe_tip_286.gd` | 「可升为」是配方词；配方子窗内容；钉住例外、子窗开到第 3 层为止 |
| `tests/ui/test_encyclopedia.gd` | 140：百科「合成」页列出全部配方，未点亮的遮名、不写 note；相关道具遮成「？」；「名字全显」设置 |
| `tests/content/test_upgrade_tiers.gd` | 124：八张拖合配方、百科合成页、一局里拖合（粗盐块 → 腌肉干）|
| `tests/run/test_run_modules.gd`、`tests/run/test_tutorial2.gd:271`、`tests/run/test_prologue.gd` | 合成模块的安装；run 存档里没有配对表 |
| `tests/ui/test_codex_link_220.gd` | 词条小窗「百科 >」链接（与配方无关）|
| `tests/run/test_score_269.gd:56`、`tests/ui/test_result_steps_177.gd:159` | `RunResult.crafts` 计分和结算显示 |

**没有任何测试**覆盖：悬浮窗按图鉴遮挡（因为功能本身不存在）、拼接后不点亮图鉴、锁定件被拼掉、砧锤完后切屏丢件。

---

## 8. 报告 279 / 286 / 298 的落地对照

- **279** `docs/reports/279-weapon-web-materials-fusion.md`
  - 已落地：拼接（v5.07）、材料类配方（v5.06）、品质（v5.08）、砧（v5.09）、紫 / 橙（v5.11），以及铜徽、铁砧定稿（v5.42）；停在铜徽上不弹窗（v5.43）。
  - 与文档不同：§二.1 写的配方表路径 `data/authoring/fusions/*.json` 实际是 `data/authoring/recipes/fuse_*.json` 加 `adjacent` 字段；§四.2 的 `GridInventory.fusion_pairs()` 实际是 `Fusion.pairs` / `CraftingModule.fusion_pairs`；§二.1「放不下进手里」实际是进地上（§八 v5.07 已注明）；§二.2 基地工钱 60/150/300 实际是 60/120/200；箭的砧配方作废（§八 21:15）。
  - 文档里**没有**任何关于图鉴或配方发现的设计。
- **286**：配方词、配方子窗、钉住例外、铁炉两栏屏、删除占位键，都已落地（v5.34 / v5.36，`tests/ui/test_recipe_tip_286.gd`）。RecipeCard 没有单独做成类，改由 `recipe_full` 实现。
- **298**：「可拼为」、`item:` 道具词、`UpgradeCompare` 都已落地（v5.66）；「常驻」改为只在悬停时显示（v5.71）；摆位修正（v5.74）。待定 2「产物上不反写由什么拼成」按推荐**没做** [仅设计文档：如果将来要加]。
- README 第 296 / 303 / 315 行与上面一致。三份报告都**没有提到**图鉴遮挡或配方知识，因此 §6 矩阵里的 a/c/e 目前**连设计文档都没有**。
