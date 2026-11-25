# 测试 v8.88：选牌卡长名字折行

- 日期：2026-11-25
- 对象：v8.88（PR #959，main e0c99a4）。
  - 选牌卡的牌名能折行了。之前在英文大字号下，长牌名会把卡里那一栏横向撑出卡边（上一轮报告的问题）。
  - 清掉了一条静态警告。
- 结论：
  - **全量有 1 项没过（v8.88 新加的测试引入）：** 断言 48097 项都过了，但日志里出现 10 条意料之外的 ERROR，`tools/test.sh` 判为失败，EXIT 1。
    - 报错是：`Error calling deferred method: 'VBoxContainer(level_pick_panel.gd)::_fit_body': Cannot convert argument 1 from Object to Object.`
    - 出处：v8.88 在 `tests/run/test_level_372.gd` 的 `frame_pick_cards` 里新加的循环。它对每张牌调 `panel._card(9, cid)`，查完宽度马上 `c.free()`。
    - `_card` 里用 `_fit_body.call_deferred(body, title)` 安排了缩字号。等延迟调用执行时，这张卡已经被释放了，参数变成了已释放的对象，所以报这条错。
    - 修法二选一：测试里改用 `queue_free()`；或者 `_fit_body` 的参数不写类型，先用 `is_instance_valid` 判断一下。
    - 这只是测试的写法问题。走查里两套语言的日志都没有这条报错。
  - **溢出已修好：**
    - 英文大字号下，【Break Momentum】【Bare-Handed Master】【Work at Sunrise】的牌名都折成两到三行，名字和说明都在卡里。
    - 中文常规照旧。
  - 场景检查 EXIT 0。静态警告 0 条。

## 全量测试与场景检查

| 提交 | `tools/test.sh` | `check_balance_scenarios --allow-dropped` | `tools/warnings.sh` |
|---|---|---|---|
| e0c99a4（v8.88） | 48097 项断言全过，但有 10 条意料之外的 ERROR，EXIT 1 | EXIT 0 | 0 条 |

- 上一个提交 3883a90（v8.86）的全量没有这条 ERROR，EXIT 0。

## 选牌卡复测（`cv956`，英文大字号、中文常规）

用上一轮的走查脚本 `cv956` 再走一遍：

- 奉技巧之神开局，开局质变是一批。
- 升到 6 级，在神坛改奉日神，之后的 7 批改信重选。

| 检查项 | 英文大字号 | 中文常规 |
|---|---|---|
| 开局质变（技巧之神） | 【Stance】【Bare-Handed Master】【Break Momentum】：长名字折成 2～3 行，说明在卡里 | 【大巧若拙】【以攻待守】【锋芒】，不溢出 |
| 改信重选第 1 批（日神） | 【Afterglow】【Sunbathing】【Work at Sunrise】：「Work at Sunrise」折成两行，说明 5 行都在卡里 | 不溢出 |
| 7 批改信重选 | 标题「Conversion repick: 7 left」→ 1 left，每批排版检查都没有溢出 | 「改信重选：还剩 7 次」→ 1 次 |
| 地图左上委托栏 | 「The Temple Comp…　5 / 20」整行能看见 | 不截断 |

- 截图：`en_large-cv956_06_opening_qual.png`、`en_large-cv956_09_repick_1.png`。上一轮同样的位置是横向撑出卡边的。

## 观察（低优先级，不算问题）

- **【Afterglow】的英文写成「The first 1 seconds of Night also count as Day」。** 数是 1 时，「seconds」应该是单数。
- **【Bare-Handed Master】在连字符处折开，**名字占了三行。放得下，只是看着比别的卡高。

## 测试工具问题

- 无。

## 截图与证据

- 截图在共享文件夹 `/mnt/project-files/testing/2026-11-25-v888/`，其中 `*-cv956_06` 到 `*-cv956_12` 是选牌窗。
- 日志和脚本在 [evidence/2026-11-25-v888/](evidence/2026-11-25-v888/)：
  - `cv956-*.log`、`_cv956.body`：走查。脚本的其余部分见上一轮的 [evidence/2026-11-25-v885-v886/](evidence/2026-11-25-v885-v886/)。
  - `suite-e0c99a4-tail.log`：全量，含那 10 条 ERROR。
  - `balance-e0c99a4.log`、`warnings-e0c99a4.log`。
