# 206 音效第二批接入：背包 / 战利品 / 战斗（37 个 cue）

> 架构设计 thread · 2026-10-19 · 提案（作者 18:57 在「音效」线程「开始做下一组音效，全做，并给我几个备用选项」；协调者转来要接入方案）
> 承 204（`Audio` 自动加载、cue 表、`AudioHub.play`）。素材：`/mnt/project-files/art/audio/sfx2/`（`cues.json` 37 个 cue，每个 3 版：v1 推荐 / v2 轻亮 / v3 厚重；另加 19:18 的 `battle.start`，见 §2.4；作者挑完，「音效」线程把定稿放进 `sfx2/final/`，文件名 = cue 名点换下划线，如 `bag_pick_cloth.ogg`）。

## 0 一句话

挂点不多：拖拽层 4 处、地面落地 1 处、战利品 3 处、战斗事件表 1 处，全部一行 `AudioHub.play(cue)`。
cue 的「按什么选」全放进表与一个小的纯类：材质 → `SfxMaterial.of(def)`（布 / 皮 / 金属三类，按标签），稀有度 → cue 名拼 `r<rarity>`，伤害类型 / 反应 → cue 表的 **alias** 字段（`battle.hit.drain` → `battle.hit.physical`，十个反应 → 四个声），倍速 → cue 表的 **max_per_sec** + 4× 时只留暴击 / 反应 / 倒下 / 胜负。
素材挑哪版不影响接法：文件名固定，先用 v1 落地，定稿到了同名覆盖。

## 1 现状（核过）

| 挂点 | 在哪 | 现在有什么 |
|---|---|---|
| 拿起 | `DragLayer` `drag_started.emit` 两处（190、220） | `_inst` 在手，def 可取 |
| 放下 / 放不下 | `DragLayer.drop_at`：`dropped` 为真进了容器；为假 `_restore()` 退回源容器 | 两条路径清楚；Esc 取消走 951 另一处 `drag_finished(false)` |
| 旋转 | `DragLayer.rotate_dragged()`（KEY_R） | 一处 |
| 顶出 | `DragLayer` `items_displaced.emit` 两处（866、868），一次一批 | 顶出的件随后到地上或上手 |
| 落到地上 | `GroundLayer.advance_landing`：到时的 uid 收进 `landed`，再 `wake_bumps` | `land_profile(def)["sink"]`（密度 ≥ `LAND_SINK_DENSITY`）= 重的 |
| 翻牌 | `LootView` `item_revealed.emit`（110 快速搜索全亮、173 逐张）；`reveal_finished` | 173 那条有 `_current` → def.rarity（0～5） |
| 全部拾取 | `ContainerScreen.take_all()`（先 `reveal_all` 再 `transfer_all_prefer`） | 按钮本身会响 `ui.press`（204 钩子） |
| 战斗 | `BattleView._apply(e)` 的 match：DAMAGE → `_on_damage`（amount、type、crit）、STATUS_STACKED 首层 → `pop`、EFFECT_RESOLVED 反应 → `_on_reaction`、DIED、`_finish()` 有 `_result.winner` | 跳转 / 拖进度时 `_suppress_popups` 为真，弹字已经不弹 |
| 倍速 | `speed()`，`_feedback_scale()` 在 ≥ 4× 时缩小反馈 | 4× 回放一秒几十条 DAMAGE |
| buff 正负 | `BuffDef.is_debuff` | 现成 |
| 伤害类型 | `data/authoring/damage_types/`：physical / fire / ice / lightning / poison / bleed / drain / reflect | 素材只有前六种 |
| 反应 | 10 种（燃血 淬裂 过载 爆燃 冻疮 超导 凝毒 激荡 电解 菌血） | 素材 4 声：爆燃 / 蒸汽 / 碎裂 / 电涌 |
| cue 表 | `CueTable` 字段 files / volume_db / pitch_var / cooldown | 加 alias、max_per_sec |

## 2 规则

### 2.1 cue 表新字段

| 字段 | 意思 |
|---|---|
| `alias` | 这个 cue 名只是另一个 cue 的别名（一层，不链）：`{"alias": "battle.hit.physical"}`。查表时先解别名再取文件。别名条目不许再带 files |
| `max_per_sec` | 这个 cue 一秒最多响几次（滑动窗口），超了静默丢弃；默认 0 = 不限。和 cooldown 并存：cooldown 挡同帧重复，max_per_sec 挡高倍速洪水 |

### 2.2 按什么选

- **材质**（拿起 / 放下）：`core/audio/sfx_material.gd`（RefCounted）`of(def) -> &"metal" | &"leather" | &"cloth"`，按标签从上到下第一个命中：
  - 金属：`heavy`、`metal`、`gem`、`stone`（和 `ItemWeight` 的重档同一组标签）；
  - 皮 / 硬物：`leather`、`hide`、`fur`、`wood`、`bone`、`horn`、`ceramic`、`glass`（执行按 `data/authoring/tags/` 核实 id，没有的删）；
  - 其余（布、纸、草药、食物、药、箭……）：布。包（`is_bag`）按皮。
  cue 名 = `bag.pick.` + 材质 / `bag.place.` + 材质。
- **稀有度**：`loot.flip.r%d` % clampi(def.rarity, 0, 5)。
- **伤害类型**：`battle.hit.` + type；表里 `battle.hit.drain`、`battle.hit.reflect` 是 `battle.hit.physical` 的 alias。新加伤害类型没声就静默记 `missing`（204 规则），不崩。
- **反应**：`battle.reaction.` + 反应 id，表里全部是 alias：爆燃 fire_poison、燃血 fire_bleed、过载 fire_lightning → `battle.reaction.1`（爆燃）；淬裂 fire_ice → `.2`（蒸汽）；冻疮 ice_bleed、凝毒 ice_poison、菌血 poison_bleed → `.3`（碎裂）；超导 ice_lightning、激荡 lightning_bleed、电解 lightning_poison → `.4`（电涌）。以后给某个反应单独配声 = 把它的 alias 换成 files。
- **增益 / 减益**：`BuffDef.is_debuff` → `battle.buff_down` / `battle.buff_up`。
- **轻 / 重落地**：`GroundLayer.land_profile(def)["sink"]` → `bag.land.heavy` / `bag.land.light`。

### 2.3 挂点与时机

| cue | 哪里 | 条件 |
|---|---|---|
| bag.pick.* | `DragLayer` 两处 `drag_started.emit` 之前 | 每次上手 |
| bag.place.* | `drop_at`：`dropped` 为真且目标是容器棋盘（grid_view / 别的面板） | 放到地上不响这个：落地那一声在后面 |
| bag.invalid | `drop_at`：`dropped` 为假走 `_restore()` | Esc 取消（951）不响：那不是放不下 |
| bag.rotate | `rotate_dragged()` | 每按一次 |
| bag.bump | 两处 `items_displaced.emit` | 一批一声 |
| bag.land.light / heavy | `advance_landing` 的 `landed` 非空时，按**最重的那件**响一声 | 一帧落几件只响一声（cooldown 0.08 兜底）；198 的碰撞、翻倒不响（§5） |
| loot.flip.r* | `LootView` 173 逐张揭开 | 快速搜索（110，一次全亮）**不逐张响**，只响一声 `loot.flip_done` |
| loot.flip_done | `reveal_finished` | 这次至少亮了一张才响；快速搜索也走这里 |
| loot.take_all | `ContainerScreen.take_all()` 搬完之后，至少搬走一件才响 | 「全部拾取」按钮 `set_meta("sfx", &"")`，不叠 `ui.press` |
| battle.hit.* | `_on_damage`：amount > 0 | `_suppress_popups` 为真时全部战斗 cue 都不响（和弹字同一开关） |
| battle.crit | `_on_damage`：`crit` 为真，**叠在** hit 上 | 两声一起 |
| battle.block | 这一下被格挡层减了伤 | DAMAGE 的 payload 若已有原始 / 实际两数与格挡减量，直接用；没有标明「减的是格挡」的字段就在 `CombatantRuntime` 结算处补一个 `blocked` 数（core，一行） |
| battle.armor_break | 护甲从 > 0 掉到 0 | `RESOURCE_CHANGED` key = armor、current = 0 且面板上一次 > 0（面板已有 `set_resource`，在那里比） |
| battle.reaction.* | `_on_reaction` | 同反应弹字 |
| battle.buff_up / down | STATUS_STACKED 的 `first`（和 `pop` 同一条件） | 续层不响 |
| battle.fall | DIED | 每方一次 |
| battle.win / lose | `_finish()`：`_result.winner` 是玩家一方 → win，否则 lose；平局不响 | 回放到结尾同样响 |
| battle.start（19:18 补）| `_apply` 收到 `BATTLE_START`（`BattleSim` 开场发一次，`battle_sim.gd:54`）| 走同一个 `_sfx`：`seek` / `skip_to_end` 重演时 `_suppress_popups` 为真，自然不响；任何倍速都放行；按「重播」从头放会再响一次（就是开场，合理） |

**倍速**：`BattleView` 里一个 `_sfx(cue)`：`speed() >= 4.0` 时只放行 start / crit / reaction / fall / win / lose（203 §3 的约定，start 是 19:18 加的），其余战斗 cue 不发；2× 全放，靠表里 `max_per_sec` 限：hit 8、block 6、buff 4、crit 4、reaction 4。

### 2.4 素材与文件名

- `assets/audio/sfx/<cue 点换下划线>.ogg`，每个 cue **一个**文件（三版是风格备选，不是随机变体），`pitch_var` 0.05 给变化。
- 表里 `volume_db` 起点：背包组 −6，翻牌 r0～r5 −8 → −3 渐强（素材已按此做，表里写 0），战斗命中 −5、暴击 / 反应 / 倒下 −3、胜负 0。
- `tools/sync_audio.sh <目录> [--variant v1]`：目录下有 `ogg/` 且给了 `--variant` 就把 `ogg/<cue>_v1.ogg` 拷成 `sfx/<cue>.ogg`；目录下是定稿（`final/`，已是最终名）就照旧整体拷。CREDITS 照旧并入 `assets/audio/CREDITS.md`。
- 落地顺序：执行现在用 `--variant v1` 落（37 个文件齐、测试「文件都在」绿）；作者挑完、「音效」线程放好 `final/`，执行再跑一次 sync（同名覆盖）、合并，不改代码不改表。
- **`battle.start`（19:18 补）**：作者听第二轮时定了「胜利的号角」（`round2/battle_win_b3.ogg`）当战斗开场；「音效」线程已复制为 `sfx2/round3/battle_start.ogg`。它**不在** `ogg/` 的 37 个里，`--variant v1` 扫不到，执行从 `round3/battle_start.ogg` 单独拷成 `assets/audio/sfx/battle_start.ogg`（或 sync 顺手支持「`<cue>.ogg` 已是最终名就照拷」）。`volume_db` 0、`pitch_var` 0（开场一声，不要飘）。
- 作者对 37 个的版本选择记在 `/mnt/project-files/art/audio/sfx2/picks.md`（厚重版 4 个、推荐版 21 个、12 个在重做，第三轮文件 `round3/<cue>_c1..3`）。挑哪版只换文件，**挂点、表、测试都不受影响**；`battle.win` 本身仍另有定稿，不是号角那一版。

**与 UI替换美术 的容器界面定稿（19:02）对齐**：容器 / 搜索界面正在换美术（/mnt/project-files/art/ui/board/README.md）：「快速搜索」按钮去掉，「全部拾取」换成火漆按钮。所以上表里「快速搜索不逐张响」只对 `LootView.skip()` 还在的路径生效；`loot.take_all` 的静音 meta 要挂在新的火漆按钮上（它仍是 BaseButton，204 的钩子照样接）。两件事都在执行手里，挂点以新控件为准。

## 3 改动

| 文件 | 改什么 |
|---|---|
| `core/audio/cue_table.gd` | `alias`、`max_per_sec` 字段与校验（别名目标要存在、别名不带 files、不链） |
| `ui/audio.gd` | 解别名；`max_per_sec` 滑动窗口（每 cue 记最近 N 次时间戳）；`_sfx` 不变 |
| `core/audio/sfx_material.gd`（新） | §2.2 材质三类 |
| `data/authoring/audio/cues.json` | 38 条（37 + `battle.start`）+ 别名条（2 个伤害类型、10 个反应） |
| `ui/inventory/drag_layer.gd` | 拿起、放下 / 放不下、旋转、顶出 |
| `ui/inventory/ground_layer.gd` | `advance_landing` 落地轻 / 重 |
| `ui/game/loot_view.gd`、`ui/game/container_screen.gd` | 翻牌 / 翻完 / 全部拾取；按钮 meta 静音 |
| `ui/battle/battle_view.gd` | `_sfx(cue)`（suppress + 倍速门）；`BATTLE_START` 开场、`_on_damage`、`_on_reaction`、STATUS_STACKED、DIED、`_finish`、`set_resource` 护甲碎、格挡 |
| `core/battle/combatant_runtime.gd` | 仅当 DAMAGE 没带格挡减量时补 `blocked` 字段 |
| `tools/sync_audio.sh` | `--variant` 与 `ogg/` 目录 |
| `tests/ui/test_audio_206.gd`（新） | 见 §4 |
| `docs/architecture.md` 8.11 | 加 alias / max_per_sec / 挂点清单 |

## 4 测试

1. 表：alias 解析；别名指向不存在的 cue、别名带 files、别名链 → errors；37 个 cue 文件都在。
2. 材质：秘银剑 → metal、皮甲 → leather、绷带 → cloth、包 → leather。
3. 拖拽：上手 → `bag.pick.*`；放进棋盘 → `bag.place.*`；放不下退回 → `bag.invalid`；Esc 取消 → 不记；旋转 → `bag.rotate`；顶出一批 → 一条 `bag.bump`。
4. 落地：两件同帧落稳，一重一轻 → 只记一条 `bag.land.heavy`。
5. 战利品：逐张揭 3 张（稀有度 0 / 3 / 5）→ `loot.flip.r0 / r3 / r5` + `loot.flip_done`；快速搜索 → 只有 `loot.flip_done`；全部拾取搬走 ≥ 1 件 → `loot.take_all`，空容器不响。
6. 战斗：喂一串事件给 `_apply`：`BATTLE_START` → `battle.start`（4× 也响；`seek(0)` 重演不响）；火伤 → `battle.hit.fire`；吸血（drain）→ `battle.hit.physical`；暴击 → hit + crit 两条；凝毒反应 → `battle.reaction.3`；减益首层 → `battle.buff_down`，续层不响；护甲 3 → 0 → `battle.armor_break`；DIED → `battle.fall`；玩家赢 → `battle.win`。
7. 门：`_suppress_popups` 为真时上面全部不记；`speed()` = 4 时火伤不记、暴击记；`max_per_sec` = 8 时 1 秒内 20 条火伤只记 8 条。

## 5 不做

- 198 地面碰撞、翻倒、滚动的声音（素材没有；以后 `bag.knock` 一条加在 `wake_bumps` 的接触上）。
- 地图 / 节点组（203 §3 的后两组）：等第三批素材。
- 每件道具专属声（素材按材质三类就够）。
- 反应 10 声各配：先 4 声别名，哪个想单独配再换 files。

## 6 落地（2026-10-19，架构方案执行，v3.48）

按 §2～§4 落了，37 个 cue 先用音效线程的 v1（`sync_audio.sh <round2> --variant v1`），作者挑完放进 `final/` 再跑一次 sync 同名覆盖，不改代码不改表。和方案不一样或方案没写死的地方：

1. **格挡不用补 core 字段**：DAMAGE 的 payload 里已有 `block`（格挡减掉的量；负数是破绽多吃的），`> 0` 就响 `battle.block`。整下都被格挡住（amount = 0）也响，在 amount 为 0 提前返回之前判。
2. **被顶出来自动上手也算上手**：顶出一件时那件自动到手上，走的是第二处 `drag_started.emit`（`grab_free`），所以这一下是 place + pick + bump 三声（方案表「两处 drag_started 之前」照字面落）。
3. **治疗不响**：amount 为负（受伤前效果反转成治疗）不响命中声，弹字照旧。
4. **胜负抽成静态 `BattleView.result_cue(result)`**：`_finish` 调它；测试直接喂 `BattleResult`。跳过（`skip_to_end`）先抽干日志再 `_finish`，所以跳过也响胜负；跳转到结尾同理。
5. **护甲打穿**在 `set_resource` 之前比面板上一次的 `armor_value()`：上一次 > 0、这次 ≤ 0 才响；本来就 0 再报 0 不响。
6. **快速搜索按钮已在容器屏换美术时去掉**，`LootView.skip()` 路径还在（只响 `loot.flip_done`），测试直接调它。
7. **测试拨钟**：`AudioHub.clock_override`（≥ 0 时代替真时钟），限频测试一秒里 20 下火伤只记 8 下、过一秒再记。测试 `tests/ui/test_audio_206.gd` 按 §4 七组。

> 架构设计注（19:40）：§6 落的是 37 个 cue；19:18 补的 `battle.start`（§2.3 / §2.4 / §3 / §4.6）不在 PR #206 里，已作为跟进落地，见 §6.1。

### 6.1 跟进落地：`battle.start`（2026-10-19，v3.49）

`round3/battle_start.ogg` 单独拷成 `assets/audio/sfx/battle_start.ogg`（CREDITS 里音效线程已写明是第二轮合成号角，没再追加）；cues.json 一条（音量 0、不变调）；`_apply` 收到 `BATTLE_START` 走 `_sfx`；4× 白名单加 start。测试：§4.6 加开场一例，§4.7 加「跳转时开场也不响」「4× 开场照响」。`seek(0)` 那一例用 `_suppress_popups` 为真代替（seek / skip_to_end 重演就是靠它压住，测的是同一个门）。`sync_audio.sh` 没改：定稿 `final/` 里已是最终名，整体拷时 `battle_start.ogg` 会一起覆盖。
