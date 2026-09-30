# 093 · 信仰流派：作者表格的落地方案与实施

作者上传了《信仰流派一览》（四位神：蛮神 / 日神 / 自然之神 / 大地之神；每位两条增长条件 + 一类献祭品；1～5 级效果与经验值）与附表（稀有度换算 2^rarity；体积按格子数分五档）。作者要的是：**先说打算怎么设计并落实「全局计数器、经验累积、效果应用」这三块**，确认之后再动手。下面是方案；已有的信力系统（081 / 082）能接住大半，标出哪些沿用、哪些要新造。

## 〇、和已有东西的对照

| 表里的概念 | 现在已有的 | 处置 |
|---|---|---|
| 信仰名称、神 | `FaithDef`（内容种类 `faiths`，id / 名字 / 阵营 / 神 / 说明） | 沿用。四位神各一份 JSON：`brute`（蛮神）、`sun`（日神）、`nature`、`earth`。现有 `violence` / `sunfire` 与蛮神 / 日神重合，**建议合并改名**（道具标签跟着改），别留两套 |
| 经验值 → 1～5 级 | `FaithDef.thresholds`（非递减）+ `FaithPower.tier_of` | 沿用：`thresholds = [30, 100, 200, 400]`（蛮神）就是 1～4 级；表里 5 级空着的就四道阈值 |
| 增长方式（条件 1 / 2） | `FaithDeed` 构件（`battle / travel / earn_money / explore / event_choice / place_item / spend_money`） | 表里的条件大半是**新事件**：造成 / 受到伤害、失去体力、火焰伤害、道具成功循环、恢复生命、触发自然道具、触发中体积道具、进入空白节点。加 6 种 deed（下面二） |
| 献祭品 | 没有 | **新机制**：休息点 / 事件里的「献祭」选项，把棋盘或暂存区里符合条件的道具销毁换经验（下面三） |
| 效果应用 | `ItemDef.faith_bonuses`（写在**道具**上，按阶给属性修饰 / 规则） | 表里的效果是**信仰级的、不属于某件道具**（全体伤害乘区、休息处多一个选项、开战预备界面多一个选项、掉落保底……）。要新造 **`FaithPerk`**（写在信仰上，按阶生效）—— 道具上的 `faith_bonuses` 保留，两层都在（下面四） |

## 一、全局计数器：怎么记、记在哪

- **一个信仰一个池子**（`FaithPower.points`，已有，跟存档）。只有**此刻激活的信仰**收点 —— 激活规则不变（最后置入的信仰道具决定，3.8）。
- 表里「伤害 × 1」「失去量 × 50」「恢复量 × 1」这类是**按量累计**：deed 的 `gain` 返回 `round(量 × 系数)`。已有 `EarnMoneyDeed.per_amount` 就是这种写法，新 deed 照它写：`multiplier`（浮点）+ 可选 `cap_per_event`（一次最多给多少，防止一场战斗一口气冲两级 —— 蛮神「伤害 × 1」在 60 秒的战斗里轻松几百点，**建议每场战斗对伤害类 deed 设上限**，数由作者定，默认不限）。
- 战斗里的量从哪来：战斗是离线回放（`BattleSim.run` 出一份 `BattleResult`），事件流里有 `DAMAGE`（含伤害类型、双方）、`RESOURCE_CHANGED`（heal）、`ITEM_FIRED`、`DISPATCH_OVERFLOW`（因资源不足跳过）。打完一场，`RunState._wire_events` 里现在只喂 `battle {won}`；改成**打完把这一场的账汇总一次喂进去**：`{won, dealt, taken, fire_dealt, healed, fired: {uid: 次数}, skipped: {uid: 次数}, nature_triggers, mid_triggers}` —— 一次 `credit(&"battle", 汇总)`，每个 deed 只挑自己认的字段。这样不用给 `FaithPower` 加战斗内回调，也不改回放。
- 地图上的量（失去体力、进入空白节点）已有信号：`Vitality.changed(delta < 0)`、`travel.moved(first_visit)`。「空白节点」= 用过的（visited）点或岔路 —— 表里写「首次进入 +20，非首次 +1」，我理解**空白节点 = 岔路（junction）和用过的点**；如果作者指的是别的，说一声。
- 界面：HUD 已有「信力 12 / 30（第 1 阶）」，改成「蛮神 Lv.1　120 / 200」；浮窗（`FaithTooltip`）列出这个信仰的增长方式、献祭品、各级效果与当前进度。

## 二、经验累积：新的 6 种行为构件（`FaithDeed` 子类，注册表各一行）

| type | 字段 | 认的事 | 表里对应 |
|---|---|---|---|
| `damage_dealt_taken` | `multiplier`(1.0) `damage_type`(空 = 全部) `taken`(bool 也算受到的) `cap` | `battle` 汇总里的 `dealt / taken`（可按伤害类型筛：日神只认 `fire`） | 蛮神条件 1、日神条件 1 |
| `vitality_lost` | `multiplier`(50) | `vitality_change {delta}`，delta < 0 | 蛮神条件 2 |
| `item_cycle` | `amount`(2) | 汇总里的 `fired` 总次数（**成功**出手；因耐力 / 资源不足跳过的不算 —— `DISPATCH_OVERFLOW` / 消耗付不起的那次不计） | 日神条件 2 |
| `heal` | `multiplier`(1) | 汇总里的 `healed`（战斗内回血）+ 地图上的 `vitality_change delta > 0`？—— 表写「恢复生命值」，我按**战斗内生命恢复**理解，体力不算；要算体力说一声 | 自然条件 2 |
| `item_triggered` | `amount` `tag`（如 `nature`）`min_cells`（如 5 = 中体积起） | 汇总里的 `fired`，按道具的标签 / 体积筛 | 自然条件 1（`tag: nature`, 3 点）、大地条件 1（`min_cells: 5`, 8 点） |
| `enter_node` | `first_amount`(20) `again_amount`(1) `node_types`（空 = 空白节点） | `travel {first_visit, node_type}` | 大地条件 2 |

体积分档写成一个静态表 `ItemVolume.of(def) → 极小 / 小 / 中 / 大 / 极大`（格子数 1 / 2～4 / 5～8 / 9～12 / 13+，附表），献祭与效果都用它。

## 三、献祭品：新机制

- **入口**：休息点事件（`rest_default`）多一个选项「献祭」，条件构件 `faith_active`（激活了某信仰）；也可以做成信仰专属事件。选了打开**献祭屏**（复用容器屏的壳：左边一个「祭坛」容器，右边棋盘 + 暂存区）：把道具拖进祭坛，屏上实时算「这些能换多少经验」，按「献祭」销毁并加点。
- **换算**（表 + 附表）：`2^rarity × 系数`，「每满足一个条件结算一次」= 一件道具同时是骨制品 + 大体积 + 武器就算三次。蛮神 `×3`、日神 / 自然 `×2`、大地 `× 格子数`（大地只认大体积）。条件用**标签**与**体积**表达：`bone / flesh / metal / fire / gem / nature / food / armor / weapon` + `min_cells / exact_volume`。现有道具库里 `bone / flesh / metal / gem / nature / food` 这些标签一个都没有 —— 要**给道具补标签**（附表 Sheet1 已经开始了：一根胫骨 = 蛮神 / 武器 / 骨），这是内容工作，我可以先按名字猜一轮标签让作者改。
- 数据：`FaithDef.offerings: Array[OfferingRule]`（`tags / min_cells / exact_cells / multiplier / per_cell`），献祭屏按它算。**献祭掉的道具没了**（不进暂存区、不进结算）。

## 四、效果应用：`FaithPerk` 构件（写在信仰上，按阶生效）

道具上的 `faith_bonuses` 是「这件赐福之物到几阶多出什么」，保留。表里的效果是**信仰本身给的**，另加 `FaithDef.perks: Array[FaithPerk]`，每条 `tier`（几级起）+ 一个效果构件。按落点分四类，各自接在已有的口子上：

1. **战斗编译期**（开战时并入玩家的战斗单位）：`BattleCompiler.compile` 已经吃 `faith_tiers`，再吃一份「信仰级修饰」——
   - 蛮神 1：所有伤害独立乘区，按当前生命百分比越低越高 → 一条新的 `StatModifier` 乘区 `FAITH`（乘区表加一档）+ 规则「每 tick 按 hp% 刷层」：做成 `CombatEffect` `LowHpEmpower`（`max_percent` 上限、线性）。
   - 日神 1 / 3：开战随机三把 / 全部武器火焰附魔 → 编译期给武器加一条 `on_hit` 规则 `DealDamage(fire, max(固定值, 武器伤害 × 百分比))`：新效果 `Enchant`（编译期构件），日神 3 再给所有武器 `stamina_cost` 修饰。
   - 自然 1：开战回血加成 → `regen_hp` 修饰；自然 3：按食物数量 × 稀有度给 `max_shield`；大地 1：`max_stamina` 修饰；自然 4：食物效果翻倍 → 食物道具的 `CombatProfile` 数值 ×2（编译期对带 `food` 标签的道具乘一遍）。
2. **休息处选项**（在休息点事件里多一个选项，条件 `faith_tier_at_least`）：蛮神 2 献祭生命上限换耐力上限与攻速（后果 `faith_ritual`：改这一局的角色基线，进存档）；日神 2 祈祷换局内永久火焰加成（非线性：第 n 次 +f(n)，写成表）；自然 2 献祭食物回体力（每个休息处一次 → 节点内容记旗标）；大地 2 锻炼 +1 行棋盘（`GridInventory` 扩行，已有 `LootPacker` 扩行的先例）。这四条就是**事件后果构件**，各一个脚本 + 注册表一行，事件编辑器自动认。
3. **地图 / 流程**：蛮神 3 消耗 1 体力秒杀精英 → 战前准备屏多一个按钮（条件：精英、信仰 ≥ 3、体力 ≥ 1）；日神 4 敌人必掉额外道具按档位稀有度 → `LootEffect`（掉落上下文已有构件口，`DropResolver` 加一条「保底额外一件 ≥ 稀有度」）；大地 3 进任意节点给对应类型道具 → 听 `travel.moved`，按类型表 `give_random_item`；大地 4 每局三次把当前空白节点改成别的类型 → 已有 `change_node_type` 后果 + `RunSkill`（地图上的技能按钮就是 082 的 `RunSkills`，`uses: 3`）；自然 5 平局算胜 → `BattleSim` 收尾时读上下文的一个开关。
4. **战斗规则**：蛮神 4 生命归零后坚持 10 秒、耐力无限、伤害照记 → `DIED` 事件前插一手：`Undying` 效果给 10 秒 buff（`max_stamina` 无限 = 消耗归零），到期真死。这一条改到结算内核，单独做、单独测。

每一条效果都是**独立构件**（脚本 + 注册表一行），信仰文件里写 `{"tier": 1, "type": "low_hp_empower", "max_percent": 50}`，编辑器与导入器自动认，作者改数不改代码。

## 五、顺序与工期（作者点头后）

1. 骨架（半天）：`ItemVolume`、6 种 deed、战斗汇总喂 `credit`、`FaithPerk` 容器与 `faith_tier_at_least` 条件、HUD / 浮窗改版、四份信仰 JSON（先只写增长与阈值）。
2. 献祭（半天）：`OfferingRule`、献祭屏、休息点选项、道具补标签一轮。
3. 效果（按神分四批，各半天到一天）：编译期类最快（蛮神 1 / 日神 1、3 / 自然 1、3 / 大地 1），休息处四条其次，流程类（蛮神 3 / 日神 4 / 大地 3、4 / 自然 5）再次，蛮神 4「不死 10 秒」最后。
4. 每一批：测试 + 报告一节 + 占位数表。

## 六、要作者拍板的

1. 「空白节点」指什么？（我按「岔路 + 用过的点」理解）
2. 自然之神「恢复生命值」只算战斗内回血，还是体力也算？
3. 伤害类 deed 要不要每场上限？（蛮神一场就几百点，阈值 30 / 100 一战就过两级）
4. 现有 `violence` / `sunfire` 与新的蛮神 / 日神合并改名，可以吗？（道具标签 `faith:violence` 跟着改）
5. 献祭在休息点做，还是也允许在任意事件 / 地图上随时献祭？
6. 表里 5 级大多空着：先按四道阈值做，5 级留位。


## 七、作者拍板（同日）

1. 空白节点 = 岔路 + 用过的点。2. 恢复生命只算战斗内回血。3. 蛮神的转换倍率与阈值可调、不写死；理想节奏：前两场战斗到 1 级、4～6 个战斗节点到 2 级、小图一般升不到最高级、中图最后升到最高级；单场上限由我取舍。
4. 暴力之神 / 太阳与火之神合并改名为蛮神 / 日神，标签跟着改。5. 献祭只在休息点的神坛做，休息点数量略提；神坛只在激活信仰时是休息处的选项；神坛界面看得到当前等级与信力；解锁特殊操作前只有献祭与返回；祭品台至少满足一条就亮「献祭」并预览；常规献祭不限次数；特殊操作和常规献祭共享这一次机会；大地之神的改造节点只在神坛用、不限次数。6. 5 级留空占位。

## 八、实施（做了什么）

### 8.1 计数器与经验（骨架）

- 四份信仰文件 `data/authoring/faiths/{brute,sun,nature,earth}.json`（`violence` / `sunfire` 删掉，力量的符号改 `faith:brute`）。阈值按表；行为、献祭规矩、效果全是构件字段。
- 6 种按量累计的行为（`core/run/faith/deeds/`，注册表 `FAITH_DEEDS`）：`damage`（倍率 / 伤害类型 / 算造成 / 算受到 / 每场上限）、`vitality_lost`、`item_cycle`（成功出手才算：因资源不足跳过的那次不发 ITEM_FIRED）、`heal`（只算战斗内我方回血）、`item_triggered`（标签 / 最少格子数）、`enter_node`（头一回踩岔路 +20、再踩用过的点 +1）。
- **一场战斗的账**：`RunState.battle_summary(result, won, board)` 从回放日志汇总 {造成 / 受到按类型、回血、每件出手几次与它的标签 / 格子数}，打完一次 `credit(&"battle", 账)`；地图上 `vitality.changed`（掉体力）与 `travel.moved`（首踩 / 类型）也喂。`ItemVolume`（`core/inventory/item_volume.gd`）按附表把格子数分五档。
- **校准**（默认角色 + 标准套，12 个种子的前两场）：一场造成 + 受到中位数 117、范围 54～127。蛮神 `damage` 倍率 **0.2**、每场上限 30 → 一场约 23：第 2 场到 1 级（30）、第 5 场到 2 级（100）、3 级 200 约 9 场、4 级 400 约 17 场 —— 小图（36 步）升不到顶，中图（60 步）末段到顶。失去体力 × 50 按表（输一场掉 1 体力 = 50 点，比 1 级阈值还高，作者留意）。日神：火焰只在附魔后才有，前几场靠「成功循环 × 2（每场上限 30）」；自然：回血 × 1（上限 30）、自然道具出手 +3；大地：中体积出手 +8、岔路 +20。**倍率、上限、阈值全在 JSON**。
- HUD：「蛮神 Lv.1　74 / 100」（`FaithPower.line`）；浮窗（`FaithTooltip`）加献祭品一行与各级效果（到了的绿、没到的灰）。

### 8.2 神坛（献祭）

- 休息点事件 `rest_default` 多一项「神坛（献祭 / 特殊操作）」：条件 `faith_active`（新构件，没信仰**藏起来**），后果 `proceed` + `open_altar`（新构件）—— 先照常休息回体力，再开神坛。第一章各环休息点配额 `[0, 2] → [1, 2]`、覆盖 4 → 3（略多几个休息点）。
- `RunState.altar_node / altar_used / altar_open()`：神坛只在这个点上开着（走开就关），做过特殊操作的点记下来 —— **和常规献祭共享这一次机会**。
- 神坛屏 `ui/game/altar_screen.gd`（`Screen.ALTAR` 叠层）：抬头「神坛　蛮神　蛮神 Lv.1　74 / 100」；祭品台（4×4）只收至少满足一条献祭规矩的道具（拖拽过滤 + 双击 + `put_on_table`）；台上有东西「献祭」就亮，预览「献祭 n 件：信力 +x（Lv.a → Lv.b）」；`offer()` 销毁祭品、`FaithPower.add_points`、存档；常规献祭不限次数。特殊操作一列按等级刷出来（升级当场多出来），有的要先挑一项（大地改造此点挑类型）；做了 `altar_special` → `altar_used` → 神坛关、屏关、这个休息处不能再开。「返回」把台上的东西退回背包再回地图；站着没用过特殊操作还能再开（`reopen_node`）。
- `OfferingRule`（`core/run/faith/offering_rule.gd`）：标签任一 / 最少格子 / 体积恰好某档 / 倍率 / 乘格子数；`FaithDef.offering_value` 每满足一条结算一次（短剑对蛮神 = 2^1 × 3 = 6；口粮对自然 = 自然 2 + 食物 2）。

### 8.3 效果（`FaithPerk` 构件，注册表 `FAITH_PERKS`，写在信仰的 `perks` 里、按 `tier` 生效）

| 神 | 级 | 构件 | 落点 |
|---|---|---|---|
| 蛮神 | 1 | `low_hp_empower`（10%～50%，血越少越高） | 编译期挂一条「本方造成伤害前 · 一直 · 低血增伤」规则（新效果 `LowHpEmpower`，独立于乘区，按当前血量算） |
| 蛮神 | 2 | `altar_sacrifice_hp`（−5 生命上限 → +10 耐力上限、+5% 急速，可多次） | 神坛特殊操作；账在 `faith_stat_bonus / faith_rituals`，编译期给所有道具急速 |
| 蛮神 | 3 | `smite`（耗 1 体力秒杀精英） | 战前准备屏多一个按钮 → `GameFlow.smite` → `NodeEvents.smite_pending_battle`（不模拟，按赢了收尾：掉落、进账、空回放） |
| 蛮神 | 4 | `undying`（10 秒） | 结算内核：`CombatantRuntime.undying_sec`（从 `spec.flags` 读）—— 血归零 `mark_dead` 不倒、进坚持期（回放里一条 `undying`）；期间耐力花了立刻补（无限）、受到的伤害**照记**（`DamageResolver` 血停在 0 也记真实伤害，喂信力）；`settle_undying` 到期血还是 0 才发 DIED，被治回来就活；一场只一次。到期时刻算进 `next_expiry`，`BattleSim` 每个时刻先判它 |
| 日神 | 1 / 3 | `enchant_weapons`（随机 3 把 / 全部；每击附带火焰 max(3, 30% 武器伤害)；3 级武器耐力消耗 −20%） | 编译期给武器挂「自己出手 · 一直 · 火焰附魔」（新效果 `FireEnchant`） |
| 日神 | 2 | `altar_pray_fire` | 神坛特殊操作：次数 n → 火焰加成 10 × n^0.7 %（非线性；附魔读它） |
| 日神 | 4 | `extra_drop_by_node`（普通 3 紫 / 精英 4 金 / BOSS 5 红） | 掉落上下文 `extra_drop_rarity` → `DropResolver.rarity_guarantee`（和 BOSS 保底同一条路） |
| 自然 | 1 | `stat_mod`（基线 regen_hp +1） | 编译期 |
| 自然 | 2 | `altar_food_vitality`（每件 +1 体力，每个休息处最多 3、一次） | 献祭之后的钩子 `on_offered` |
| 自然 | 3 | `food_shield`（每件食物 2 + 2 × 稀有度 护盾） | 编译期 |
| 自然 | 4 | `food_double`（食物道具战斗数值 ×2；献祭食物回体力也 ×2） | 编译期 + flags |
| 自然 | 5 | `draw_is_win` | `CombatantSpec.flags` → `BattleSim.run` 收尾：平局判我方赢 |
| 大地 | 1 | `stat_mod`（基线 max_stamina +20） | 编译期 |
| 大地 | 2 | `altar_train_board`（棋盘 +1 行） | 神坛特殊操作；`GridInventory.grow_rows` 原地加行 |
| 大地 | 3 | `gift_on_enter`（战斗-武器 / 精英-防具 / 事件-饰品 / 撤离点-随机 / BOSS-珍宝，进暂存区） | 踩上点的钩子 `on_node_entered` |
| 大地 | 4 | `altar_reshape_node`（挑一种类型改造当前点；作者定：只在神坛、不限次数） | 神坛特殊操作 → `NodeEvents.retype`（清旧事件、造敌人、当没踩过），关神坛立刻发生 |

编译期效果统一在 `RunState.compile_player()` 之后套（`FaithPerk.modify_spec`），`BattleCompiler` 仍是纯函数。

### 8.4 道具标签（第一轮，作者改）

给道具补了 `metal`（剑 / 刀 / 锤 / 撬棍 / 板甲 / 盾 / 枪 / 弹匣 / 装甲板）、`gem`（魔晶石 / 碎片 / 黑曜石 / 灰白碎片）、`nature`（弓 / 箭 / 皮甲 / 伤药 / 纱布 / 口粮）、`food`（口粮）；`bone / flesh / fire` 现在一件都没有（表的 Sheet1「一根胫骨」还没做成道具）。词典 `Glossary.TAG_NAMES` 给标签中文。

### 8.5 测试与留给作者的

`tests/test_author_093.gd`：信仰文件与体积档与献祭换算；六种行为与账汇总；效果各落点（低血增伤规则、献祭生命上限改基线与急速、秒杀只对精英、附魔挂规则、祈祷非线性、自然回血 / 护盾 / 平局算胜、大地锻炼加行 / 赐物 / 改造此点）、献祭换信力不占机会、特殊操作占机会与存档；神坛屏帧测试（没信仰藏选项、有信仰进神坛、抬头、祭品台过滤、预览与献祭、返回再开、升级刷出按钮、做了就关）。全套 **68 个套件、11758 项断言**通过。

### 8.6 蛮神 4 级「不死 10 秒」（作者：也做了）

`UndyingPerk`（`perks/undying_perk.gd`，`seconds` 可调）只在编译后的单位上立旗 `undying_sec`；机制全在结算内核：`CombatantRuntime.mark_dead` 有旗且没用过 → 不死、记到期时刻、发一条 `EFFECT_RESOLVED undying`；`_on_resource_changed` 里耐力的负变动立刻补回（无限）；`DamageResolver` 血停在 0 时事件里的 amount 仍是真实伤害（作者：受到伤害依旧累计，所以蛮神的信力照涨）；`settle_undying(now)` 在 `BattleSim._resolve_instant` 的到期一步先判：到期血 > 0 活着继续、否则 `dead` 并发 DIED；一场只一次（再归零当场倒下）。测试 `run_undying`。

### 8.7 「触发信仰」事件与护符（作者追加）

- **护符**四枚（`items/charm_{brute,sun,nature,earth}.json`）：1 格、稀有度 3、值 200；标签 `treasure` + `faith` + `faith:<神>` + 流派标签（蛮神 `bone`、日神 `fire`、自然 `nature`；大地没有额外标签，但 `is_bag: true` —— 一只 1 格的空心石匣，能当包装一件小东西）。没有战斗定义、没有按阶功能：只用来激发流派。`MetaState.keeps` 给信仰包开了例外（大地的护符也留在局外）。
- **事件链**：`faith_call`（触发信仰）：「废墟深处立着一座祭坛」→「靠近」（后果 `next_event_random`：四位神各权重 1，随机数是这个点的，同一局同一点永远同一位）/「离开」；`faith_call_{神}`：那位神的一幕 →「接过 / 拿起 / 取下 / 取出」（`give_item` 护符 + 一句）/「不拿，离开」。
- **随机出现、每张图最多一位神、偏前期**：`NodeRules.event_groups`（新字段）—— `{"faith_call": {"max_per_map": 1, "early": true, "chance": 1.0, "events": {"faith_call": 1}}}`；`EventPlacer.fill_groups` 在铺普通事件之前、在事件点里挑 `max_per_map` 个（early：权重 (1 − 深度)² + 0.05）、写进节点并记 `event_group`；`chance` 是这张图有没有它的概率（1.0 = 必有一位）。导入器校验组里的事件存在；事件编辑器的「现在挂在」也列组。`next_event_random` 是新的通用后果，别的分岔事件也能用。
- 测试 `run_faith_call`（护符 / 事件链 / 八个种子恰好一个且平均深度 < 0.5 / 走一遍：靠近 → 某位神 → 拿 → 护符进暂存区 → 上棋盘激活）。

留给作者：日神 5 级 / 大地 5 级 / 蛮神 5 级空着；`bone / flesh / fire` 标签的道具；数值全在 JSON 里调（倍率、每场上限、阈值、献祭倍率、各效果的数）。
