# 140 方案：代码精简审查「移交协调者」的十六项 —— 逐项拍板

- 日期：2026-10-07
- 来源：代码审阅精简线程的清单 `/mnt/project-files/audits/2026-10-07-redundancy-review.md`「移交协调者」表（明细在同目录 `2026-10-07-redundancy/`）；协调者转来，请本线程出方案。
- 性质：架构 · 提议（本线程只写方案，不实现、不跑测试）。每项给一个决定；标「**作者拍板**」的三项（I-8 套装系统、M-19 删工具、U-27）按惯例默认走推荐，作者若有异议回一句即可。
- U-1（编辑器基类化）按协调者要求单独立项：[141](141-authoring-editor-base.md)。
- 执行顺序建议：先做「纯删」（第 1 组），再做「改行为」（第 2 组），最后做「架构约定」（第 3 组）；每组一个 PR，全套测试绿再合。

## 第 1 组：删（行为不变或只影响无人走的路径）

| 编号 | 决定 | 做法 | 配套 |
|---|---|---|---|
| I-8 `icon` | **删** | `ItemDef.icon` 字段去掉 | 导出 .tres 不受影响 |
| I-3 原地旋转与四邻 | **删**（审查倾向 a） | 删 `rotate_item` / `rotate_bag` / `neighbors_of` / `rotated_step` 与只测它们的用例 | `architecture.md` 3.3 的 API 清单与 305 行「原地转」那句删掉；14 节预留项改写成「将来要原地转 = `detach_bag + attach_bag_shedding` 一行」 |
| I-7b `accept_tags` | **删字段**（b） | 两个容器都去掉 `accept_tags` 与 `accepts()` 的标签分支；`ItemStash.accepts` 退化为 `def != null`；`to_dict` 不再写、`from_dict` 忽略该键 | 存档：现有存档里该键恒为空数组，读档无感；5 处测试赋值删掉。`architecture.md:228` 同步 |
| B-2b `Cost.describe` 全家 | **删**（a） | 基类 + 9 个子类的 `describe` 删掉 | 「悬浮窗显示消耗」若将来要做，是一条独立的 UI 需求，到时重写，不留现在这套贴错查表的实现 |
| B-10a `clear_axis` / `origin_of` | **删** | 两个函数与只调它们的测试删掉 | 悬浮窗的「← 毒箭」已由遍历 `compiled.attached` 实现；「净化轴」没有内容词汇对应，要做时随 `RemoveStatus.axis` 一起设计 |
| B-16 `OnResourceChanged` | **删** | 文件、`EffectRegistry.TRIGGERS` 一行、`Glossary.TRIGGER_NAMES` 一项、`architecture.md:849`、百科自动生成的扳机词条随之消失；两个测试改用 `OnDamage` | 内容词汇少一种；`data/authoring` 零使用，无迁移 |
| R-4 后半 无人接的信号 | **删** | `HunterSystem.spawned / moved / encounter / hunter_defeated / fled`、`MapTravel.arrival_held`、`GameFlow.run_started / run_ended`、`Vitality.depleted` 及发射行全删；测试改用状态断言（`is_depleted()`、`flow.run != null`） | 「界面画猎手走动」现在走 `hunters_changed`（R-23 之后是 `hunters.changed`），不需要 `moved` |
| M-19 三个工具脚本 | **删**（**作者拍板**，推荐删） | `tools/gen_sample_items.gd`、`gen_sample_combat.gd`、`export_content.gd` 删掉 | `architecture.md:3804-3806` 目录树同步；bootstrap 用 `normalize_content` / 编辑器 |
| U-27 开局屏「没有角色」老路 | **删**（**作者拍板**，推荐删） | 三处 UI 分支改成和「没有章节」一样的一条红字；core 的 `flow.begin` 老路保留给测试 | 作者数据有三个角色，没有角色不再是支持的内容形态 |

## 第 2 组：改行为（玩家可见但可接受）

| 编号 | 决定 | 做法 | 影响 |
|---|---|---|---|
| I-11 `LootPacker.pack` → `add` 委托 | **改** | `pack(ids, size, items)` = `add(GridInventory.new(size), ids, items, size.y)`；`board_of` 不动 | 极少数情况下尸体 / 收获容器的摆法从「重排」变「追加」；容器高度不变。`test_search_reveal.gd`、`test_search_session.gd:221` 若有位置断言改成按新摆法 |
| I-18 `expected_count` | **改成按 `roll` 蒙特卡洛** | `expected_count(content, ctx)` = 用固定种子的 `RandomNumberGenerator` 调 `roll` N = 64 次取均值，四舍五入；`carried_ids / carried_flags` 合成 `carried_entries(content)` 一次遍历 | 地图屏敌人预览的「预计掉 n 件」会变（现在就是错的：没算 087 保底与 093 额外掉落）；`test_drop_resolver.gd` 对它的断言改成区间或精确种子值。64 次 `roll` 对预览一行足够快（每次只是几次 `randf`） |
| B-12 空棋盘分支 | **并** | `board == null` 只跳过「收集参战物品」那段，删提前返回的 4 行 | 边界：空棋盘 + 把基线生命压成负数的修饰 → `max_hp` 从负数变 0。负生命本来就是坏数据，0 更对 |
| R-21 猎手 `loss_outcomes` 旧路径 | **删 + 报错 + 迁移** | 删 `loss_outcomes / _legacy / LEGACY_OPTION`；导入器遇到 `loss_outcomes` 报错「请改用 loss_options」；`RunMigrations` 加 v3 → v4：存档里 pending 的猎手遭遇若带 `_legacy` 选项，丢掉该选项（读档后按现行 `loss_options` 重新生成） | 旧作者文件被拒 —— 仓库里两份猎手 JSON 都已是新格式；两个测试改写 |
| M-25 两份加权抽样 | **合一但保序** | `MapRng.pick_weighted(weights, rng, order: Array, exclude, fallback)`：遍历顺序由调用方传（格阵传 `weights.keys()` 插入序，环形传 `_sorted_keys`）。`randf` 次数与扣减顺序都不变 → **同种子输出不变** | 变成纯重构；若执行线程证实两处输出逐种子一致，可和清单第 6 项（通用加权抽样）合成同一个函数 |

## 第 3 组：架构约定

| 编号 | 决定 | 做法 | 影响 |
|---|---|---|---|
| R-22 `erosion` 鸭子接口 | **明确类型** | `MapTravel.erosion: ErosionField`；删 `move_penalty` 旧路径与 `has_method("to_dict")`；三个测试的假对象改成真的 `ErosionField`（或给它们补 `settle` / `to_dict`，推荐前者） | 架构 7.x「侵蚀是 `ErosionField`」写明；不再承诺鸭子接口 |
| R-23 `RunState` 的 9 个转发信号 | **删转发，界面接模块** | `map_screen` 改接 `run.hunters.sensed / changed / player_expelled`、`run.travel.erosion.warned / advanced / applied / total_reached`、`run.skills.changed`、`run.faith_power.changed`；两机制 `install` 的 lambda 转发删掉；`RunState` 信号表只剩生命周期（`leaving / arrived / stepped / phase`） | 按架构 7.4 来；读档时两机制复用已有对象，界面在 run 建好后接线即可；三个测试改接模块信号 |
| I-20 非矩形容器 `_blocked` | **留** | 不动代码；`docs/status.md` 登记「14 节预留、暂无生产用户、代价在 6 处 + 存档键」 | 139 仓库格子按宽度放大之后，仓库形状仍是矩形；真定了不做非矩形再一次清掉 |
| I-8 套装 / 道具跨域效果 / 包体加成 / 敌人 `loadout` | **留，标「已实现、暂无内容」**（**作者拍板**，推荐留） | `architecture.md` 9 节各小节开头与 `docs/status.md` 加一句「已实现、暂无内容；第一份内容待 流派 / 掉落 设计需要时再写」；代码、`set_editor`、`test_sets` 不动 | 砍掉约 1.2k 行是另一条路：套装与跨域效果是 9 节设计的扩展点，130 的流派件已经在往「几件配合」走，套装是它的自然下一步，现在砍了回头再写更贵。若作者定砍，范围 = `core/sets`、`set_editor`、`test_sets`、`ItemDef.set_id / effects / bag_mods`、`LootRegistry` 四种效果、`EnemyDef.loadout`、`RunState.tracker` 接线、面板 / 悬浮窗套装行 |

## 第 4 组：两条提醒

| 项 | 决定 | 做法 |
|---|---|---|
| `HunterMechanic.count_by_scale` 在 `ascension_1.json` 没填 | **留字段、登记** | 它是难度旋钮，「用默认」就是生效的规则；`docs/status.md`「内容未用的字段」表登记一行（和 I-9 的 `min_danger` / `treasure_modified` 同一张表）。不往 JSON 里补占位值 |
| `RecipeDef.note` 九份 JSON 都填了、没人读 | **显示出来** | 两处：①拖一件到可合成的搭档上时的绿色预览（114）旁边一行小字显示 `note`；②百科配方词条（若百科已有配方页就加一行，没有则加在道具词条的「可合成」段）。作者写了九句说明，是给玩家看的 |

## 测试

- 第 1 组：全套测试绿即可（删的都是零引用或只有测试引用的，连带删用例）；`check_scripts` 554 → 对应减少；`check_content` 23 种一致。
- I-11：造「先大后小」的两件，断言新摆法；I-18：固定种子下 `expected_count` 的值 = 手算均值；B-12：空棋盘 + 负修饰 → `max_hp == 0`；R-21：带 `_legacy` 的 v3 存档读进来 → 猎手选项按 `loss_options` 生成；M-25：两种生成器各取五个种子，合并前后 `type` 分配逐点相同；R-22 / R-23：改过的测试绿。
- `note`：拖到搭档上时预览文字含 `note`。

## 待定（都按推荐）

1. I-8 套装等扩展点：**留并标注**（砍是另一条路，上表写了范围）。
2. M-19 三个工具：**删**。
3. U-27 老路：**删**。
4. I-18 蒙特卡洛次数：**64**。
5. R-22 假对象：**换成真的 `ErosionField`**。
