# 204 音频接入第一批：界面音效（按钮、开关窗口）

> 架构设计 thread · 2026-10-19 · 提案（作者 2026-10-19「按推荐来吧 … 先加一些最常规最不容易出错的按钮点击、窗口关闭/打开音效」）
> 承 [203 讨论稿](203-audio-plan-discussion.md)：挂点已是信号、后插不麻烦、音效走 CC0 包、配乐等风格定了再买或定制。本篇把 203 的推荐写成能派的方案，第一批只做界面音效。

## 0 一句话

一个自动加载 `Audio`（`ui/audio.gd`）+ 一张 cue 表 `data/authoring/audio/cues.json` + `GameSettings` 两个音量；
按钮音**不逐个挂**：`Audio` 监听场景树 `node_added`，凡 `BaseButton` 进树就接它的 `pressed`，44 处 `Button.new()` 一处都不改；
窗口开 / 关只在两处挂：`GameDirector._switch_screen`（叠层）与 `FloatingWindow`（浮窗）。
第一批 3 个 cue：`ui.press`、`ui.open`、`ui.close`。素材由 美术设计 从 CC0 包挑；代码与素材两条线并行，先落空表。

## 1 现状（本篇写时核过）

| 项 | 现状 | 对本篇的意思 |
|---|---|---|
| 音频 | 0 个音频文件，0 处 `AudioStreamPlayer` / `AudioServer`，没有音量设置（202 §5） | 从零起，没有旧东西要迁 |
| 自动加载 | 只有 `DevNav`（`project.godot [autoload]`） | 加第二个；176 启动图测试扫 `game.tscn + DevNav`，要把 `Audio` 也放进根 |
| 按钮造法 | `UiTheme.make_button / make_home_button / make_menu_line / make_menu_link / make_difficulty_plate`，加 **44 处**直接 `Button.new()`（编辑器、浮窗关闭键、设置屏、`IconButton` 等） | 在工厂里挂只覆盖一半，所以用全局钩子（§2.2） |
| 叠层 | `GameDirector._switch_screen`：`GameFlow.is_overlay(screen)` 分支造叠层并 `_fade_in`；`restore` 恢复最小化；`minimized` 藏起；`_drop_overlay` 撤 | 开 / 关各一处 |
| 浮窗 | `FloatingWindow.setup(key, title, on_close)`，关闭键在标题栏 | 进树 = 开，出树 = 关 |
| 设置屏 | 172 的「显示」一节 `_build_display`；布尔项都是 `_toggle` 按钮；改完 `flow.save_settings()` + `_refresh()` | 「声音」一节照这个样子加 |
| 设置存取 | `GameSettings.to_dict / from_dict`，`user://settings.json`，缺键用默认 | 加两个字段即可 |
| 无头 | 测试 `--headless`，Godot 用 Dummy 音频驱动，播放静默无报错 | 不用专门 no-op；测试看 `Audio.recent` |
| 分层 | `core/` 不许 `extends Node`（1.1）、不许认 `ui/`（`tests/test_layering.gd`） | 自动加载是 Node，住 `ui/`；cue 表的纯类住 `core/audio/` |

## 2 规则

### 2.1 cue 表 `data/authoring/audio/cues.json`

手写 JSON，直接读（同 169 的 `text_colors.json`，不走内容管线、不进快照）。键 = cue 名（`组.名`），值：

```json
{
  "ui.press": {"files": ["sfx/ui_press_1.ogg", "sfx/ui_press_2.ogg"], "volume_db": -6, "pitch_var": 0.04, "cooldown": 0.04},
  "ui.open":  {"files": ["sfx/ui_open.ogg"],  "volume_db": -4},
  "ui.close": {"files": ["sfx/ui_close.ogg"], "volume_db": -4}
}
```

| 字段 | 意思 | 默认 |
|---|---|---|
| `files` | 相对 `res://assets/audio/`，多个 = 随机挑一个（连续两次不挑同一个） | 必填，≥ 1 |
| `volume_db` | 这个 cue 的基准音量 | 0 |
| `pitch_var` | 每次播放 `pitch_scale` 在 1 ± 它 之间随机 | 0 |
| `cooldown` | 同一 cue 两次播放最短间隔（秒），挡住同帧重复 | 0.04 |

cue 名不在表里：静默，`Audio.missing` 记一次（测试与开发台看，玩家什么也不见）。这样代码可以先落、素材后到。

### 2.2 按钮音：一处钩子，不逐个挂

`Audio._ready` 接 `get_tree().node_added`；进树的节点是 `BaseButton` 就 `pressed.connect(_on_button.bind(b))`。
`_on_button(b)` 播 `b.get_meta("sfx", &"ui.press")`：

- 默认每颗按钮按下都是 `ui.press`（含 `IconButton`、`toggle_mode` 的开关、编辑器里的按钮）；
- 以后某颗要专属声（翻牌、开启挑战……）：造它的地方 `b.set_meta("sfx", &"loot.flip")`，不加新钩子；
- 要静音：`set_meta("sfx", &"")`。

用 `pressed`（默认在松开时发，和动作同时）而不是 `button_down`：按下去又拖出去不算点，就不该响（待定 §4.1）。
键盘 / 手柄按确认键同样走 `pressed`，不用另接。

### 2.3 窗口开 / 关：两处

| 哪里 | 开（`ui.open`） | 关（`ui.close`） |
|---|---|---|
| `GameDirector._switch_screen` 叠层分支 | 新造叠层、`restore` 恢复最小化 | `minimized` 藏起；换回底屏时 `_drop_overlay` 撤掉了一个非空叠层 |
| `FloatingWindow` | `_ready`（第一次进树） | `tree_exiting`（关闭键、换屏撤掉都算） |

叠层换叠层（撤一个马上造一个）只响 `ui.open`，不响 `ui.close`：`_drop_overlay(silent := false)` 加个参数，叠层分支传 `true`。
底屏换底屏（主菜单 → 设置、地图 → 结算）第一批**不响**：那不是窗口，等以后要「换屏」音再加 cue（§6）。

### 2.4 音量与总线

`Audio._ready` 用 `AudioServer.add_bus` 造 `SFX`、`Music` 两条总线送 `Master`（不手写 `default_bus_layout.tres`）。
`GameSettings` 加 `sfx_volume: float = 0.8`、`music_volume: float = 0.6`（0～1，`from_dict` 夹到范围），`Audio.apply(settings)` 设 `set_bus_volume_db(idx, linear_to_db(v))`，0 = `set_bus_mute`。
调用点同 `UiText.apply`：`GameDirector._ready`、设置屏改完；编辑器 / 启动器不调（用默认）。

### 2.5 播放

`Audio` 下挂 8 个 `AudioStreamPlayer`（SFX 总线）轮用；`play(cue: StringName)` 找空闲的（都忙就抢最早那个），按表挑文件、设音量与音高。
`music(track: StringName, fade := 0.8)`：一个循环的 `AudioStreamPlayer`（Music 总线），换曲交叉淡入淡出；表 `data/authoring/audio/music.json` 第一批**是空的**，API 先在，等曲子（203 §4）。
`Audio.recent: Array[StringName]`（最近 32 个，测试看）；`Audio.enabled`（测试可关）。

## 3 改动

| 文件 | 改什么 |
|---|---|
| `project.godot` | `[autoload] Audio="*res://ui/audio.gd"` |
| `ui/audio.gd`（新） | 自动加载：总线、播放器池、`play / music / apply`、`node_added` 按钮钩子、`recent / missing / enabled` |
| `core/audio/cue_table.gd`（新，RefCounted） | 读 `cues.json` / `music.json`，校字段，`cue(name) → Dictionary`，`files_of(name)`；不认识 Node |
| `data/authoring/audio/cues.json`、`music.json`（新） | 第一批 3 个 cue；素材到了填 `files`；`music.json` = `{}` |
| `assets/audio/sfx/`（新） | 素材；`assets/audio/CREDITS.md` 每个文件一行：来源、作者、许可（CC0 也写，Steam 页与片尾用） |
| `core/settings/game_settings.gd` | `sfx_volume / music_volume` + `to_dict / from_dict` |
| `ui/game/game_director.gd` | `_ready` 调 `Audio.apply`；`_switch_screen` 按 §2.3 播；`_drop_overlay(silent)` |
| `ui/game/floating_window.gd` | `_ready` 播 `ui.open`，`tree_exiting` 播 `ui.close` |
| `ui/game/settings_screen.gd` | 「声音」一节放「显示」下面：一行「音效 80%」+ `−` / `+`（步 10%，按它本身就是 `ui.press`，当场听到新音量）；「音乐」行先不显示（§4.2） |
| `tools/sync_audio.sh`（新） | 照 `sync_item_art.sh`：把美术目录的 `*.ogg` 拷进 `assets/audio/sfx/`，拷 `CREDITS.md`，跑一次 `--headless --import`；**不**生成清单（cue 表手写） |
| `tests/tools/test_startup_graph.gd` | 176 的根加 `res://ui/audio.gd` |
| `tests/ui/test_audio_204.gd`（新） | 见 §5 |
| `docs/architecture.md` | 新小节「音频」：自动加载、cue 表、按钮钩子、meta `sfx` 约定、素材与许可 |

两条线并行：
1. **架构方案执行**：以上代码，`cues.json` 先写 3 个 cue、`files` 为空数组 → 全静默但一切接好；测试绿、合并。
2. **美术设计**：按 §5 挑素材放到 `/mnt/project-files/art/audio/ui/`，交给 执行；执行跑 `tools/sync_audio.sh`、填 `files`、第二个 PR。

## 4 待定（按推荐做，作者有意见再改）

| # | 事 | 推荐 | 另一选 |
|---|---|---|---|
| 4.1 | 按钮音在按下还是松开 | 松开（`pressed`，和动作同时；拖出去不响） | 按下（`button_down`，更跟手，但误触也响） |
| 4.2 | 「音乐」音量行 | 存设置但**先不显示**，第一首曲子落地时打开 | 现在就显示（调了没声音，玩家会以为坏了） |
| 4.3 | 开关（`toggle_mode`）与普通按钮同一声 | 同一声 `ui.press` | 另配 `ui.toggle`（第一批不加文件） |
| 4.4 | 底屏换屏 | 不响 | 加 `ui.screen`（以后随淡入 shader 一起定） |
| 4.5 | 音效默认 80%、音乐 60% | 如左 | 都 100% |
| 4.6 | 编辑器里的按钮也响 | 响（同一个钩子，不特判；DevGate 关着编辑器进不去） | 启动器 / 编辑器下 `Audio.enabled = false` |

## 5 给 美术设计 的素材要求

| 项 | 要求 |
|---|---|
| 来源 | CC0：Kenney「UI Audio」「Interface Sounds」优先；freesound 只拿 CC0 的；每个文件记来源 URL、作者、许可写进 `CREDITS.md` |
| 质感 | 风格 A 墨线平涂（`assets/style-guide.md`）：木、皮、纸的触感，**不要电子哔声、不要玻璃 / 塑料感**；开窗 = 轻的「掀 / 翻」，关窗 = 同一素材反过来或闷一点，两者成一对 |
| 数量 | `ui.press` 2～3 个变体（同一声音微差，避免机械感）；`ui.open`、`ui.close` 各 1 |
| 格式 | `.ogg`（Vorbis），44.1 kHz，单声道，不循环；文件名 `ui_press_1.ogg / ui_press_2.ogg / ui_open.ogg / ui_close.ogg` |
| 长度与响度 | 按钮 ≤ 120 ms，开 / 关 ≤ 300 ms；**头部不留静音**（留了就像延迟）；峰值统一到约 −3 dBFS，四个文件听感一致（细调由 cue 表 `volume_db`） |
| 交付 | `/mnt/project-files/art/audio/ui/` + 同目录 `CREDITS.md`；云端下载受限时作者下载到这里（203 §4） |

> 实际交付（美术设计 2026-10-19 16:45）：云端连不上 kenney.nl 与 freesound，美术没有等作者下载，先自己合成了原创音效（木块敲击、皮面接触、纸页摩擦，脚本 `/mnt/project-files/art/audio/ui/src/synth.py`），许可记为项目自有，已交给 执行。作者更想要 Kenney 的话，同名替换文件即可，cue 表与代码都不用改。

测试（`tests/ui/test_audio_204.gd`）：
- cue 表解析：三个 cue 都在、字段类型对、未知字段报错；`files` 里每个文件都存在且是 `.ogg`；
- `project.godot` 有 `Audio` 自动加载；176 启动图从 `audio.gd` 碰不到编辑器；分层测试照旧绿（`core/audio` 不认识 `ui/`）；
- 设置：`sfx_volume / music_volume` 存取往返，缺键用默认，越界夹住；`apply` 后总线分贝等于 `linear_to_db`，0 = 静音；
- 钩子：造一颗 `Button` 加进树、`emit_signal("pressed")` → `Audio.recent` 末尾是 `ui.press`；`set_meta("sfx", &"")` 的不记；同帧两次只记一次（cooldown）；
- 叠层：开背包 → `ui.open`；收起（minimized）→ `ui.close`；叠层换叠层只记一个 `ui.open`；
- 浮窗：`FloatingWindow` 进树 / 出树各记一次；
- 未知 cue：`play(&"nope")` 不报错，`missing` 里有它。

## 6 不做（这一批）

- 背包 / 战利品 / 战斗 / 地图 / 节点音效（203 §3 的其余组）：钩点都在，等第一批跑顺、作者听过效果再逐组派；战斗那组要加 `max_per_sec`（倍速回放限频），到时再加字段。
- 悬停音（`mouse_entered`）：最容易让人烦的一种，作者没要。
- 配乐：等风格定；`music()` 与 `music.json` 先空着。
- 环境声、混响、Godot 的 `AudioStreamRandomizer` 资源：JSON 表里的 `files` 数组够用。
- 声音编辑器：cue 表手写，三个 cue 不值得做界面。
