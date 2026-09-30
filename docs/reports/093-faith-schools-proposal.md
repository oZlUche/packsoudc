# 093 · 信仰流派：作者表格的落地方案（提议，等作者拍板）

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
