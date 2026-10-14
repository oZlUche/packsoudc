# 173 · 存档的形式，与「升级后存档失效」的治法

> 作者 2026-10-14 19:08：「存档经常会在版本升级后失效，当前存档是什么形式？如何保证迁移成功率」。性质：架构 · 实施。前半是答问（§1–2），后半是方案（§3 起），待定按推荐。关联 098（迁移链 / 备份不覆盖 / 改名表）、101（存档位）、120（仓库容量算出来再装）、143 / 155 / 160 / 163（改内容没升版的几次）、159（一局里的地）。

## 1. 现在的存档长什么样

| 文件 | 内容 | 版本 | 读不出来时 |
|---|---|---|---|
| `user://slots/<n>/meta.json` | 局外：钱、仓库、带回的棋盘、图鉴、解锁、科技、战绩、历史 | `MetaState.SAVE_VERSION = 3` | 备份成 `meta.json.<时间>.bak`，从零开始 |
| `user://slots/<n>/run.json` | 一局：图、位置、体力、钱包、棋盘、暂存区、模块（保险箱 / 祭坛 / 倒计时……）、事件、猎手、信力 | `RunState.SAVE_VERSION = 4` | 备份后这一局作废（局外不受影响） |
| `user://settings.json` | 偏好（语言、倍速、改键、光标……） | `GameSettings.SAVE_VERSION = 1` | 用默认值 |

- 三个存档位，全是**明文 JSON**，没有压缩、没有校验和。
- 道具只写 `{uid, def(id 字符串), rot, origin, seq, state}`，不写资源路径（架构文档 3.1）；读回来按 id 查 `ItemDatabase`，查不到再查改名表 `IdAliases`（道具 / 标签 / 信仰 / 章节四张表）。
- 读档顺序：JSON → 版本链（`MetaMigrations` / `RunMigrations`，字典层逐级 n→n+1）→ 版本号仍不等于当前 → `null`（备份、从零）；比本版本**新**的档只读锁住、不碰。缺键一律 `d.get(key, 默认)` 兜底。
- 写档：`FileAccess.open(path, WRITE)` 直接覆写，没有临时文件。
- 测试 `tests/run/test_save_migration.gd`：局外每一版有迁移步和冻结样本（`meta_v1/v2.json`）；一局的链只用测试里手写的小字典验，**没有一局档的冻结样本**；改名表的新 id 必须存在、旧 id 不许再被内容引用。

## 2. 为什么「经常失效」—— 失效分三类，版本链只管第一类

**第一类：格式变了。** 版本链管这一类，局外升过两次、一局升过三次，测试守着每级都有迁移。这一类其实很少出事。

**第二类：内容变了、格式没变（最常见，现在没人管）。** 版本号不动，老档照样读，读出来东西却少了、位置错了：

- **道具被删**：10 月以来删了 7 个道具 json（`aid_pack`、`smoke_bomb`、`smg`、`sniper`、`mana_crystal`、`mana_shard`、`strength_sigil`），只有 `strength_sigil` 进了改名表。仓库里那一件读回来 `ItemInstance.from_dict` 一句 `push_warning` 就**静默丢弃**，玩家只看到东西没了。
- **道具形状 / 尺寸变了**（143 把短剑挪位 + 改成 T 形）：`GridInventory.from_dict` 按原位 `place` 失败 → 丢弃（120 后只有仓库会找空位；棋盘、保险箱、地上不会）。敌人预设棋盘里的那件被 `EnemyKit.board_of` 跳过（上周序章二药剂师的 bug 就是它）。
- **道具 `state` 键 / 子系统搬家**：153 `armor → block`、160 腰带技能从道具库搬走、163 仓库分页，都靠 `from_dict` 兜底或各自写了特判，没有统一的入口，漏一处就是一次「失效」。
- **章节 / 敌人 / 事件内容变**：一局档读回来和现行内容对不上。098 定了一局档允许作废，但开发期几乎每次更新都中，玩家感知就是「更新 = 这一局没了」。

**第三类：文件本身坏了。** 非原子写：存盘途中崩溃 / 断电留下半截 JSON → 当坏档 → 备份、从零。

所以作者说的「失效」多半是第二类：**版本号没变，东西却没了**。补迁移链解决不了它，要在版本链之后再加一层「内容对账」，并把「改内容忘了交代」变成红测试。

## 3. 方案

### 3.1 写档原子化（第三类）

`MetaSave.write` / `RunSave.write` / `GameSettings.save_to` 改成：写 `<file>.tmp` → 把现有 `<file>` 改名成 `<file>.prev` → `.tmp` 改名成 `<file>`（`DirAccess.rename_absolute`，同目录改名在 Windows / Linux 都是原子的）。读档失败先试 `.prev`（上一份好的），再走备份从零。`.prev` 不算存档（`SaveSlots.exists / remove` 不看它，`remove` 时一起删）。

### 3.2 内容对账层 `SaveReconcile`（第二类的主治）

新 `core/save/save_reconcile.gd`，**在版本链之后、`from_dict` 之前**，仍在字典层做，`MetaSave.from_text` / `RunSave.from_text` 各调一次，返回 `{dict, report}`：

1. **道具 id**：真名 → `IdAliases.ITEMS` → 新表 `IdAliases.RETIRED_ITEMS`（id → 处置：`{"refund": true}` 折钱 / `{"replace": "<id>"}` 换成另一件 / `{"drop": true}`）→ 三处都没有：默认 **折钱**（`ItemValue` 按最后一次已知价值：退役表里写 `value`，没写按 0）并记进报告（待定 1）。折的钱加进 `funds`；一局档里加进 `wallet`。
2. **放不回**：所有容器的 `from_dict` 不再在原地 `push_warning` 丢弃，而是统一返回 `homeless` 列表给调用方；调用方按容器类型安置：仓库 → 本页找空位 → 后页 → 临时加页（120 已有）；一局的棋盘 / 暂存区 / 保险箱 → 先本容器 `try_add`，再落到当前节点的**地上**（159 的地，没有节点就暂存区），都不行才折钱。安置了的记进报告。
3. **`state` 键改名**：新表 `IdAliases.STATE_KEYS`（旧键 → 新键），对账时统一改；未知键保留不删（现状）。
4. **一局档的内容对不上**（章节 / 敌人 / 事件 id 查不到）：照 098 允许作废，但作废前**打捞**（待定 2）：棋盘 + 暂存区 + 保险箱里的道具按 `MetaState.keeps` 过滤并进仓库（走 2 的安置），钱包不动，报告写明「这一局因版本更新作废，带的东西已放回仓库」。
5. **报告** `SaveReport {refunded: [{id, value}], rehomed: [{id, from, to}], dropped: [...], salvaged: bool, prev_used: bool, backup: path}` 写到 `user://slots/<n>/last_repair.json`，读取存档屏显示一次（「存档修复：N 件道具已随版本更新折算为 X 钱，M 件换了位置」，看过即删），主菜单和 098 的备份提示同一行（待定 4）。**没有一次丢东西是静默的。**

### 3.3 内容快照测试：把「改了内容忘了交代」变成红测试

`tests/fixtures/content_snapshot.json`：冻结每个道具的 `id`、格数、尺寸、形状、是否包，以及标签、信仰、章节、敌人的 id 表。新测试 `tests/content/test_content_snapshot.gd`：

- 快照里有、库里没有的道具 id → 必须出现在 `IdAliases.ITEMS` 或 `RETIRED_ITEMS` 里，否则红；
- 快照里有、形状 / 尺寸 / 是否包变了的 → 必须出现在 `IdAliases.RESHAPED`（只是登记，提醒对账层会重摆；同时提醒执行线程看一眼预设棋盘 `at`），否则红；
- 库里新增的 → 不管；
- 标签 / 信仰 / 章节 / 敌人 id 消失 → 同样要有改名或退役记录。

改内容的 PR 要么同时更新快照（跑 `tools/snapshot_content.sh` 重生成）并补表，要么就过不去。这是整套里**最关键的一条**：成本最低、挡的正是第二类。

### 3.4 真实存档回归

`tests/fixtures/saves/<日期>/{meta,run}.json`：作者的真实存档（待定 3，匿名、无隐私，几 KB），每次升版或每月放一份。测试把每份读一遍，断言：读得回来、报告里 `dropped` 为空、`refunded` 要么为空要么和同目录的 `expected.json` 白名单一致。另给作者一个本机检查 `tools/check_saves.sh`（只读）：对 `%APPDATA%\Godot\app_userdata\<游戏>\slots\*` 跑同一套读档 + 对账，打印报告不写文件，合并前自己跑一下就知道这次更新会不会动到自己的档。

### 3.5 升版规矩补两条

- 改 `state` 键名、改容器尺寸的**语义**（不是算出来的容量）、改模块键 → **升版**并加迁移步（现在只写了「改语义或改 id 才升版」，这三种常被当成「加字段」）。
- 存档头加 `content_stamp`（内容库全部 id 排序后的哈希，`ContentPaths` 启动时算一次）。只作诊断：报告与日志里写「这份档存于内容版本 X，现为 Y」，不参与判断。

### 3.6 不做

二进制 / 压缩 / 加密 / 校验和 / 云同步。明文 JSON 是优点：作者和玩家都能手修、能发来排查。

## 4. 测试

- 原子写：模拟 `.tmp` 写完未改名（残留）→ 读的是旧 `<file>`；`<file>` 坏 + `.prev` 好 → 读 `.prev`、报告 `prev_used`。
- 对账：退役道具按三种处置各一例；查不到的默认折钱且报告有记录；仓库 / 棋盘 / 保险箱各一例「原位放不下」→ 安置到预期位置；`STATE_KEYS` 改名；一局档章节查不到 → 打捞进仓库、钱包不动、报告 `salvaged`。
- 快照：人为从测试库删一个 id → 红；加进 `RETIRED_ITEMS` → 绿；改一件形状 → 红；登记 `RESHAPED` → 绿。
- 回归：`tests/fixtures/saves/` 每份读得回来、`dropped` 为空。
- 原有 098 测试照跑；补一份一局档的冻结样本 `run_v4.json`。

## 5. 待定（默认按推荐）

| # | 问题 | 选项 | 推荐 |
|---|---|---|---|
| 1 | 查不到定义的道具默认怎么办 | A 折钱进钱 / 钱包并报告；B 丢弃但报告；C 换成一件「遗失的包裹」占位道具 | **A**：玩家不白丢，又不用养占位道具 |
| 2 | 一局档作废时 | A 打捞棋盘 / 暂存区 / 保险箱进仓库（钱包不动）；B 直接作废（现状） | **A**：作废只会因版本更新发生，玩家无法利用；丢一局的东西最伤 |
| 3 | 真实存档回归样本 | A 作者定期交一份进 `tests/fixtures/saves/`；B 不做，只靠快照 | **A**：几 KB，挡住的都是真事故 |
| 4 | 修复报告给谁看 | A 读取存档屏一次 + 主菜单一行（和 098 备份提示同位）；B 只写日志 | **A**：没有一次丢东西是静默的 |

## 6. 改动范围

新：`core/save/save_reconcile.gd`、`core/save/save_report.gd`、`tests/content/test_content_snapshot.gd`、`tests/fixtures/content_snapshot.json`、`tests/fixtures/run_v4.json`、`tests/fixtures/saves/`、`tools/snapshot_content.sh`、`tools/check_saves.sh`。改：`MetaSave` / `RunSave` / `GameSettings`（原子写、`.prev`、调对账）、`IdAliases`（`RETIRED_ITEMS` / `RESHAPED` / `STATE_KEYS`）、`GridInventory` / `Warehouse` / `ItemStash.from_dict`（返回 `homeless` 不丢）、`MetaState.from_dict` / `RunState.from_dict`（安置 + 打捞）、`SaveSlots`（`.prev`、`last_repair.json`）、`slots_screen` / `main_menu`（报告一句）、`docs/architecture.md` 7.2 补规矩。先把 7 个已删道具和 143 的短剑补进退役表 / `RESHAPED`，作者手上的档就能回来一部分。
