# 测试 v9.19：【锋芒】英文名

- 日期：2026-11-26
- 对象：v9.19（PR #992，main 26899cb）。技巧之神【锋芒】英文名改成「Cutting Edge」，升级版「Cutting Edge+」，帮助页同步。这是上一轮（[v9.17](2026-11-26-v917-card-names.md)）报的两对重名之一。
- 结论：**改好了。**
  - 全量 48219 项断言全过，362 个套件，EXIT 0。场景检查 EXIT 0。静态警告 0 条。
  - 通用牌【锋锐】还是「Keen Edge」，【锋芒】是「Cutting Edge」，分开了。
  - 技巧之神帮助页（编辑稿和游戏里用的那份）写的也是「Cutting Edge」，没有剩下「Keen Edge」。
  - 重跑 162 张牌的重名检查，英文没有重名了。
  - **还剩一对：** 中文【坚韧】，通用牌 `card_stamina_flat` 和自然之神基础牌 `god_nature_tough`。这一版没动它。

## 全量测试与场景检查

| 提交 | `tools/test.sh` | `check_balance_scenarios --allow-dropped` | `tools/warnings.sh` |
|---|---|---|---|
| 26899cb（v9.19） | 48219 项断言全过，362 个套件，EXIT 0 | EXIT 0（「有问题 1 份」和前几轮一样，没有挡住的） | 0 条 |

## 截图与证据

- 这一轮没有界面改动，没有截图。
- 日志在 [evidence/2026-11-26-v919/](evidence/2026-11-26-v919/)：
  - `tx990.log`：重名检查。脚本和上一轮一样，见 [evidence/2026-11-26-v917/tx990.gd](evidence/2026-11-26-v917/tx990.gd)。
  - `suite-26899cb-tail.log`、`balance-26899cb.log`、`warnings-26899cb.log`。
