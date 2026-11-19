# 329 信仰重构 A 批：显式选择信仰、三态、同源快照

- 来源：作者 2026-11-19 要求按 `handoff/2026-11-19-faith-system-implementation.md`（PR #663）实施信仰系统重构，分 A–E 五批。本文是 A 批（方案 §2、§7、§8.2、§9 A）。
- 版本：v6.45
- 范围：只改「谁是当前信仰」这条规则，以及所有读它的地方。六神的数值与效果一个都没动（方案 §9 A：「不改六神数值与现有效果」）。

## 1. 现在的规则

| 状态 | 条件 | 顶端栏 | 信力 | 神赐与赐福 |
|---|---|---|---|---|
| 不奉神 | 没选 | 空槽 | 不记 | 全部停用，凡物与通用效果照常 |
| 联系正常 | 选了，棋盘上有这位神的有效信物 | 徽记 + 阶 + 信力 | 只记这位神 | 这位神生效 |
| 联系中断 | 选了，棋盘上没有这位神的有效信物 | 徽记压暗 +「联系中断」，悬浮窗写原因 | 不记 | 全部停用，**不自动换神** |

- 只有一条路改信：信物说明窗的「奉为主信仰」。已经奉了这位神，同一个键变成「不再奉神」。
- 拾取、移动、旋转、整理、整包挪、交易、合成、从地上拿回来都不改信。原来「在棋盘里把信物重新落下 = 改信」（099）删了。
- 选择按神 id 存，不按信物 uid：同神几件只维持一份联系；换一件、毁一件不会断。
- 新局默认不奉神。开局屏可以在自己的棋盘上点「奉为主信仰」，出发时交给这一局；没点就不奉，不按带入顺序猜。
- 改信免费、不加冷却（方案 §9 A）。不能改信的时候：还没站上出生点、这一局结束了、商店桌上有没成交的东西。

## 2. 代码

### 2.1 改造前的调用图（按方案 §7 全仓检索 `FaithState` `active_faith` `reseat_anchor` `spend_points` `faith_power` `dormant`）

```
棋盘（GridInventory）── placed_seq ──► FaithState.active_tag（最后置入）
   ├─ BattleCompiler.compile 第 1 步（休眠）、_lit_neighbors（邻接里的休眠）     ← 编译器自己扫棋盘
   ├─ SetTracker.recount（套装不计休眠）
   ├─ InventoryView（画灰）、FaithTooltip（几件休眠）、GrowthModule（休眠不长）
   └─ RunState.active_faith / active_faith_id
         ├─ FaithPower.credit（只记激活的）、FaithPerk / AltarModule / 四个神坛 perk、BattlePassives
         ├─ 事件条件 faith_active、后果 bless_item（经 RunHooks.active_faith_id）
         ├─ CraftingModule → FusionResolve._pick（赐福合成择神，报告 312）
         ├─ TextTemplate（{faith} {faith_tier}）、GameFlow 调试信息
         └─ HUD FaithWidget、AltarScreen、RestCampScreen
改信入口：ItemActions.is_main_anchor（自己又写了一遍「最后置入」）→ setup_screen / inventory_panel.reseat_anchor → GridInventory.reseat；
         DragLayer：棋盘内落下信物 → reseat
敌人 / 台架：EnemyKit.spec_of、CalibrationRecorder、compile_board → 编译器内部扫棋盘
spend_points：AltarBlessPerk、SmitePerk（B 批处理）
```

### 2.2 改造后

```
RunState.selected_faith（唯一可写处：select_faith / choose_starting_faith / 读档）
   └─ _sync_faith_selection → GridInventory.select_faith（棋盘元数据 FaithState.SELECTED_META，给只拿着棋盘的读者）
FaithState（道具层，纯查询）
   connection(棋盘, 神) → none / ok / benched / missing
   active_tag = 选了且 ok；board_tag = 记了选择按选择，没记（敌人、台架）按 assembled_tag
   legacy_last_placed_tag：只给旧档迁移
RunState.faith_context() → FaithContext{selected, effective, connection, tier, points}
编译：CompileInput.faith（显式）→ BattleCompiler 第 1 步与邻接都只读它 → CombatantSpec.faith（这一场的快照）
   玩家：compile_player 填有效信仰；敌人：EnemyKit 填 assembled_tag；台架：compile_board / CalibrationRecorder 填 assembled_tag
战后信力：battle_finished 读 last_battle.player.faith，记给开战那一刻的信仰（FaithPower.credit 加了快照参数）
套装 / 画灰 / 悬浮窗 / 生长：FaithState.board_tag(棋盘)，和编译同一份
```

- `ItemActions.is_main_anchor` 不再自己判定，读棋盘上记着的选择（按神算，同神几件都是主信仰）。
- `GridInventory.reseat` 留着（只盖置入序号，晶石压着两把法杖时给后来者还读它），不再改信。
- 赐福合成（报告 312）：`CraftingModule` 传的本来就是 `active_faith_id()`，现在它就是有效信仰；合成也不再可能改信（没有任何置入会改 selected）。
- 敌人：一个敌人只信一个神（`EnemyPlacer`），所以 `assembled_tag` 与原来的结果一样；魔兽照旧不跑信仰。正式编译器缺了 `faith` 就是不奉神，不会退回「最后置入」。

## 3. 存档

- 一局档 v4 → v5（`RunMigrations._v4_to_v5`）。迁移这一步看不到道具定义，只标 `faith_selection.derive`；`RunState.from_dict` 在棋盘恢复、内容对账之后按旧规则（最后置入的有效信物，平局 uid 大的，不参战不算）推一次，下一次存档写成真正的选择。
- 新档存 `faith_selection.selected_id`，不存有效信仰（读档后由棋盘重建）。存「不奉神」的新档读回来不会再按旧规则猜。
- 神 id 先过 `IdAliases.faith`；不认识的 id 读回来是选了但查不到定义，等于不奉神。
- 切片的独立存档目录走同一个 `RunSave` / `RunMigrations`，同样覆盖。
- 回放：回放与诊断包存的是编译好的战斗单位，信仰已经折进去了；`CombatantSpec.faith` 进了 `BattleInputCodec`（老诊断包没有这一键 = 空，只是说明，结算内核不读）。A 批没有改任何战斗机制，所以老回放照旧复现，不需要兼容提示；C、D 批改机制时再按方案 §8.3 加版本识别。

## 4. 文本

- 帮助页 `anchor_activation`、`anchor_and_right_click`、`switch_and_dormant`：删掉「最后置入的信物说了算」「拿起来再放下」，改写成显式选择、联系中断、不自动换神。
- 序章三：`tut3_faith_call`（放进包里，再奉为主信仰）、`tut3_faith_call_sun`（放进包里不会自动换神）、`tut3_search_done`、两场战斗锁着时的提示（`tut3_battle_1` `tut3_battle_2`）。守卫条件本身没改：两场都还是要求 `faith_active`（第二场要蛮神），读的是有效信仰。
- 新界面字（「不再奉神」「现在不能改信」「这位神的信物不在棋盘上」「联系中断」「信物不在棋盘上」等）都在已有字表里。三态显示与按钮是占位版式，正式样张走 UI设计（新）。

## 5. 测试

见文末「测试记录」。改了预期的旧测试与原因：

| 测试 | 原预期 | 新预期 |
|---|---|---|
| `test_faith` 激活 | 最后置入说了算、挪到地上再挪回 = 切换 | 显式选择；拾取 / 挪动 / 顶替 / 挪包不改信；主信物离开 = 联系中断、回来恢复；同神留一件不断 |
| `test_faith` 编译 | `compile_board` 按最后置入 | `CompileInput.faith` 显式；`compile_board` 按组装结果 |
| `test_faith` 一局 | 开局按带入顺序定信仰 | 新局不奉神；显式奉神；存档往返选择；v4 旧档按旧规则推一次、重复读写一致 |
| `test_faith_power` | 置入信物即激活并记置入 | 置入不改信，记给当时的有效信仰；改信本身不给信力 |
| `test_faith_reseat` | 落下信物 = 改信、右键 reseat | 落下不改信；按钮走 `select_faith`；主信仰的键是「不再奉神」；地上的信物灰着；联系中断不回退 |
| `test_prologue3` | 放进包里就信了 | 放进包里还不信，点「奉为主信仰」；事件开着也能改 |

## 6. 与方案的差异

- 改信锁：方案说「事件结果、献祭、交易提交中禁用改信」。这几样都是同步结算，结算中间界面插不进来，所以只锁了「不在图上」和「商店桌上有没成交的东西」；看着事件选项时可以改（序章三就靠这个：战斗选项锁着时打开背包奉蛮神）。信力按事务开始时的快照记（战斗读 `CombatantSpec.faith`）。
- 「不参战」的信物：信物本来就不能标不参战（`InventoryPanel.can_bench`），`benched` 这一态只会出现在老档里，照规则算联系中断。
- 首次取得信物的「可以奉为主信仰」提示：A 批只做到按钮可点、帮助页与序章三文本写明，没有另弹提示（避免多一层弹窗）；要不要弹交给 UI 样张。

## 7. 没做的（后面几批）

- 信力 / 祈愿拆分、扣费迁移、神坛共享预算、基础层与赐福层清单：B 批。
- 改信前展示「启用 / 停用的赐福、能力、属性变化」的预览：B 批跟着效果归属清单一起做（A 批的改信只是切换休眠，悬浮窗已经写着各自的效果）。
- 六神新机制：C、D 批。

## 测试记录

- `bash tools/test.sh`（云端容器，Godot 4.7.1 无头）：通过 41208 项断言，331 个套件，退出码 0；导入、脚本检查、内容一致性、未登记 ERROR、SCRIPT ERROR 都过。
- `bash tools/warnings.sh`：共 0 条，退出码 0。
- 迁移样本：`test_faith` 里用真实格式的一局档（降回 v4、删掉 `faith_selection`）读回来推出蛮神，再存再读一致；存「不奉神」的新档读回来不按旧规则猜。冻结样本 `tests/fixtures/run_v4.json` 照旧读得回来（`test_save_reliability_173`）。
- 没覆盖：真实界面走查（三态徽记、按钮文字、序章三的新提示）交游戏测试；占位版式等 UI设计（新）出样张。
