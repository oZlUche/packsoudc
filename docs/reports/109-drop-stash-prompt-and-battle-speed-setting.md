# 小改：去掉离开点时的暂存区提示；战斗倍速记成跨局字段（109）

> 架构 thread，2026-10-03。作者两句话：
> ① 「既然现在每个节点的暂存区都保留了，可以不用再跳出提示。」
> ② 「添加一个字段用于记录战斗倍速，这个字段应该跨局继承，也就是写入整体存档。」
> 两条都是小修，本文只写清楚删什么、加什么，交「游戏反馈小修」线程做即可，不必等别的方案。

## 一、去掉「走了暂存区留在这里」的提示

### 现状

提示是 058 第 3 条留下的：那时暂存区一走就**清空**，所以要问一句。087 改成**按点暂存**（东西留在那个点上、回来能拿，`NodeStorageModule`）之后，提示文案已经改成「走了它们就留在这个点上……回来还能拿」—— 它现在只是在复述一件没有损失的事，作者判断不值得打断。

| 在哪 | 现在做什么 |
|---|---|
| `ui/game/map_screen.gd:65-95` `step()` / `confirm_step()` / `cancel_step()` / `step_confirm_open()` / `_open_step_confirm()` | 要走时若 `run.will_clear_storage()` 且 `StorageWarning.should_warn(...)`，先弹面板 |
| `core/run/storage_warning.gd` | 按设置档位挑「值得提的」，`describe()` 拼一句话 |
| `core/settings/game_settings.gd` `storage_warn_mode / _rarity / _value`、`WARN_MODES`、`WARN_MODE_LABELS` | 提醒档位（有就提 / 稀有度 / 价值 / 从不）与两个阈值 |
| `ui/game/settings_screen.gd:25-52` | 设置屏的第一块：档位四个按钮 + 两个阈值 |
| `tests/run/test_node_storage.gd:300-335`、`tests/run/test_game_flow.gd:566` | 「先问一句 / 取消 / 照走 / 档位从不」的断言，流程测试里的「看过提示照走」 |

### 删法

- `map_screen.step()` 直接 `flow.step_to(to_id)`；删 `confirm_step / cancel_step / step_confirm_open / _open_step_confirm / _pending_step / _step_confirm`。
- **留** `StorageWarning.describe()`：`map_screen.gd:403` 离开点时的那行日志「暂存区里的 N 件留在了那里（回来能拿）」还在用，它是日志不是弹窗，保留。`at_risk / should_warn` 没人用了，删；类名可以留给 describe，或把 describe 搬去 `NodeStorageModule`，执行者定。
- `GameSettings` 删三个字段、两个常量；`to_dict / from_dict` 去掉对应行（旧 `settings.json` 里多出来的键 `from_dict` 本来就只按名取，**不用升版本**）。
- 设置屏删第一块（第 25～52 行与 `set_value_threshold` 等三个回调），其余四块不动。
- 测试：删「先问一句 / 取消 / 照走 / 从不」四条；`test_game_flow.gd:566` 那两行删掉；`test_node_storage.gd:104-122` 的 `will_clear_storage` 断言照留（它是模块逻辑，不是提示）。
- 架构文档 3.4 里提到「提醒档位」的一句同步删。

## 二、战斗倍速记成字段，跨局继承

### 现状

`ui/battle/battle_view.gd:21` `SPEEDS := [1.0, 2.0, 4.0]`，`_speed_idx` 是**视图的局部变量**，每进一场战斗都从 1× 开始（`battle_screen.gd` 每次 `BattleView.new()`）。回放是「移动游标」，倍速不影响任何结果，所以记下来没有正确性风险。

### 放哪：`GameSettings`（推荐），不是 `MetaState`

作者说的「整体存档」有两个候选，推荐前者：

| | `GameSettings`（`user://settings.json`） | `MetaState`（存档位里的 `meta.json`） |
|---|---|---|
| 性质 | 玩家偏好（语言、底色、自动关战利品屏…） | 进度（仓库、图鉴、成就、钱） |
| 跨局 | 是 | 是 |
| 跨存档位 | **是** —— 换个存档位倍速还是你习惯的 | 否，每个位各一份 |
| 加字段的代价 | `to_dict / from_dict` 各一行，不升版本 | 要走 `MetaMigrations` 升到 3 |

倍速和「拿走最后一件自动关闭」是一类东西：怎么看，不是玩到哪，所以归设置。若作者就是要它跟存档位走，改放 `MetaState` 也只是多一步迁移，形状一样。

### 加法

- `GameSettings.battle_speed: float = 1.0`，`to_dict / from_dict` 各一行；`from_dict` 只认 `BattleView.SPEEDS` 里有的值，认不出来回 1.0（别让旧文件里的怪数把回放拖成 0×）。
- `BattleView` 开场从 `flow.settings.battle_speed` 定 `_speed_idx`（`battle_screen` 建视图时传进去，或视图自己拿 `flow`）；`cycle_speed()` 切完写回 `flow.settings.battle_speed` 并 `flow.save_settings()`（和 `toggle_loot_auto_close` 同一个写法）。
- 设置屏**不加**按钮：倍速就在战斗里按，设置屏重复一份没必要（作者没要）。
- 测试：切到 2× → 新建一个 `GameFlow` 读同一份 settings → 新开一场战斗起手是 2×；`settings.json` 里写了 3.0 这种不在表里的值 → 回 1.0。

## 三、改动范围

| 批 | 文件 |
|---|---|
| ① 删提示 | `ui/game/map_screen.gd`、`core/run/storage_warning.gd`、`core/settings/game_settings.gd`、`ui/game/settings_screen.gd`、`tests/run/test_node_storage.gd`、`tests/run/test_game_flow.gd`、`docs/architecture.md` 3.4 |
| ② 倍速字段 | `core/settings/game_settings.gd`、`ui/battle/battle_view.gd`、`ui/game/battle_screen.gd`、`tests/ui/` 或 `tests/run/test_game_flow.gd` 加两条 |

两批合一个 PR 即可，半天以内。

## 待作者定（不挡执行，按推荐先做）

1. 倍速放 `GameSettings`（跨存档位，**推荐**）还是 `MetaState`（跟存档位）？
