# 208 魔晶石的消耗看得见：耐久其实在扣，差的是棋盘上的表现 —— 实例变体图（阶段贴图）+ 剩余次数角标 + 破碎处理

> 架构设计 thread · 2026-10-19 · 提案（作者 21:30 夜间六条之二：「魔晶石的消耗好像还没做，也缺少不同阶段对应的贴图？」）。待定按推荐派执行；贴图需求随本篇派美术。

## 0 一句话

消耗**做了**（148，`WearModule`，每场战斗结束、真的供给了法杖的魔晶石 −1 次，归零破碎不再供给、卖价两成五；测试 `test_crystal_148.gd` 绿），但玩家**看不到**：名字前缀「明亮的 / 闪烁的 / 黯淡的 / 破碎的」只在悬浮窗里，棋盘画的是同一张图。本篇定一条通用的**实例变体图**规则（`assets/items/<id>@<变体>.png`，按实例状态选图，没有就画本图），魔晶石按剩余次数换图、没图时画次数角标；再把破碎的处理补齐。207 的生长阶段图走同一条规则。

## 1 现状（核过）

| 事 | 现在 | 结论 |
|---|---|---|
| 扣耐久 | `WearModule._on_battle_finished`：`CombatantSpec.fed_uids`（这一场站在法杖装载格上、真的供给了的晶石）各 `spend_charge(1)`；秒杀不扣；没点亮的不扣 | 已做，规则是作者 148 定的「每供给一场 −1」 |
| 存档 | `ItemInstance.state.charges`，JSON 往返有测试；老档没记按满算 | 已做 |
| 破碎 | `is_broken()` → 编译器 `_apply_adjacency` 不让它供给；`ItemValue.of_inst` 打折 0.25；名字「破碎的」 | 已做；但破碎的晶石**还占着装载格**，玩家不拔它法杖就少一颗 |
| 表现 | 名字前缀只在悬浮窗（`Names.of_item`）；悬浮窗有「耐久 2 / 3」一行；棋盘 `InventoryView` 画 `ItemPainter.draw_art(def…)`，**不认实例** | 这就是「好像没做」的原因 |
| 道具图 | `assets/items/<id>.png` + `@2x/`；`manifest.json {"cell", "items": [id…]}`；`tools/sync_item_art.sh` 只收两套都有的 id；测试：清单里的每个 id 有 ItemDef、目录里的每张 png 在清单里、尺寸 = 形状包围盒 × 60 / 160 | 变体图要进同一条管线，清单与测试都得认 `@` |
| 画图的口 | `draw_art(canvas, def, rot, anchor, cell, modulate, base)`，8 处调用，其中 7 处手上有 `ItemInstance`（棋盘 / 拖拽 / 地上 / 收获行），图鉴那一处只有 def | 加一个按实例选变体的入口，图鉴永远画本图 |

## 2 规则

### 2.1 耐久规则不改

- 仍是「每供给一场 −1」（148 作者定）。不改成每发一次扣一次（那样 3 次只够一场的前三下，魔晶石就成了消耗品而不是弹药；要改数先改 `max_charges`）。
- 新加一条：**破碎的晶石自动变成「碎晶」**（`crystal_shards`，1×1，`material` + `magic` + `gem`，价值 = 原晶石 × 0.25 取整至少 1，无战斗效果）—— 战斗结束 `WearModule` 发现归零，就地换成碎晶（同一格、同一包，形状 1×2 → 1×1 占原点那一格）。这样装载格空出来，玩家一眼知道该换颗；碎晶可以卖、以后可以进锻造 / 合成（不在本篇）。老档里已经破碎的晶石在读档 `SaveReconcile` 时同样换掉（173 的口）。

### 2.2 实例变体图：一条通用规则

- 文件：`assets/items/<id>@<变体>.png`（60 px / 格）与 `assets/items/@2x/<id>@<变体>.png`（160）。画布规则同 201 §2.1（rot 0 包围盒）。变体名是小写字母 + 数字，不含点和空格。
- 清单：`manifest.json` 加 `"variants": {"fire_crystal": ["c2", "c1", "c0"], …}`；`items` 仍只列本图 id。`sync_item_art.sh` 按文件名里的 `@` 分拣：`<id>@<v>.png` 进 variants（同样只收两套都有的）；`<id>` 没有本图却有变体 → 报出来不收。
- 选图：`ItemPainter.variant_of(inst) -> StringName`：
  - 有 `wear` 且 `charges < max_charges`：`c<charges>`（满的时候画本图；`c0` 一般不会出现在棋盘上 —— 已换成碎晶 —— 留给读档瞬间与测试）；
  - 207 的 `growth` 且 `growth_stage > 0`：`s<stage>`；
  - 两样都有（现在没有）：耐久优先；
  - 否则空。
- `art_of(def, cell_px, variant := &"")`：清单里有这个变体就取 `<id>@<v>`，没有回落本图（赐福版照旧回落 `blessed_of` 的图，再回落它的变体：`blessed_of@<v>`）。
- `draw_art` 加一个 `variant` 参数（默认空），7 处有实例的调用传 `ItemPainter.variant_of(inst)`；图鉴、剪影、拖拽残影不传。

### 2.3 没有变体图时：次数角标

- 棋盘上画完本图后，`wear != null` 且不满时，在道具当前朝向的**左下**那个格（和 205 的信仰印记右下错开）画 `max_charges` 个小点，亮的 = 剩的（亮 = 道具稀有度色，暗 = 30% 白），点径 cell × 0.1，间距 cell × 0.14，内缩 cell × 0.08；满的不画（和「满 = 本图」一致）。
- **有变体图就不画角标**（图自己说话）。角标是兜底，不是正式表现；美术交图后它自然消失。
- 休眠 / 拖拽残影同色调（跟着 `modulate`）。

### 2.4 悬浮窗

- 「耐久 2 / 3：每供给一场少一次，用完碎成碎晶」—— 把 2.1 的新规则写进去（`item_tooltip.gd:479` 那句）。

### 2.5 给美术（随本篇派 美术设计）

| 件 | 变体 | 画什么 |
|---|---|---|
| `fire_crystal` / `ice_crystal` / `lightning_crystal`（1×2） | `c2` 闪烁 | 本图光芒收一半、内里出一道裂纹 |
| 同上 | `c1` 黯淡 | 几乎不发光、裂纹两三道、颜色灰下去 |
| 同上 | `c0` 破碎 | 裂成几块但还在原轮廓里（读档瞬间与测试用；棋盘上正常见不到） |
| `crystal_shards`（新，1×1） | 本图 | 一小堆碎晶，不分元素（三种晶石碎了都是它） |

共 3 × 3 变体 + 1 新图，各两套（60 / 160）。207 的三件种子各两张阶段图（`@s1` / `@s2`）也走这条，另见 207 §2.6。

## 3 改动

| 文件 | 改什么 |
|---|---|
| `ui/inventory/item_painter.gd` | `variant_of(inst)`、`art_of(def, cell, variant)`、`draw_art(…, variant)`、角标 `draw_charges(inst, rot, anchor, cell, modulate)` |
| 7 处 `draw_art` 调用（`inventory_view` ×2、`drag_layer` ×3、`ground_layer`、`harvest_row`） | 传变体；棋盘那处之后调角标 |
| `assets/items/manifest.json` 格式 + `tools/sync_item_art.sh` | `variants` 字典；按 `@` 分拣 |
| `tests/ui/test_board_art.gd` | 清单测试认 `@`：变体的 id 部分得有 ItemDef；变体 png 尺寸同本图 |
| `core/run/modules/wear_module.gd` | 归零 → 换成 `crystal_shards`（`board.remove` + `place` 原点，放不下进地上） |
| `core/save/save_reconcile.gd` | 读档遇到 `charges == 0` 的晶石换碎晶 |
| `data/authoring/items/crystal_shards.json`（新） | §2.1 |
| 三颗晶石的 `description` / `item_tooltip.gd:479` | 「用完碎成碎晶」 |
| `core/authoring/id_aliases.gd` + snapshot | 新道具 |
| `docs/architecture.md` 4.8 表现层 | 实例变体图一段 |

## 4 待定（按推荐派执行）

| # | 问题 | 推荐 |
|---|---|---|
| 4.1 | 消耗口径：每场一次（现状）还是每发一次 | **每场一次**（148 作者定，弹药不是消耗品） |
| 4.2 | 破碎后：留在格里（现状）还是换成碎晶 | **换成碎晶**（装载格空出来，玩家不用拔） |
| 4.3 | 角标常驻还是只在没变体图时 | **只在没变体图时**（兜底） |
| 4.4 | 变体文件名用 `@` | **用 `@`**（和 `@2x` 一个味；Windows / Godot 都认） |

## 5 测试

1. `variant_of`：满 → 空；2 次 → `c2`；0 次 → `c0`；无 wear → 空。
2. `art_of(def, 60, &"c2")`：清单有 → 变体图；清单没有 → 本图（不报错、缓存 null）。
3. 清单：`variants` 里的 id 都有 ItemDef；每张 `<id>@<v>.png` 尺寸 = 本图尺寸；`@2x` 同。
4. 碎晶：打一场（点亮）→ 2 次；连打到 0 → 原格变成 `crystal_shards`，装载格为空、法杖编译不再带那颗；放不下（不会，1×1 ⊂ 1×2 原点）兜底进地上。
5. 读档：老档里 `charges 0` 的晶石 → 碎晶，`SaveReport` 记一条。
6. 角标：UI 测试画一次不报错；有变体图时 `draw_charges` 不调（用 spy 计数）。

## 6 不做

- 不做每发扣一次；不做「修复晶石」。
- 碎晶的用途（锻造 / 合成）另起。
- 不做破碎动画 / 音效（挂点：`WearModule.worn` 已有，`AudioHub.play(&"bag.crystal_break")` 一行，等素材）。
