# 云端调试测试证据

对应报告：[2026-11-10-cloud-debug-0a91d60d.md](../../2026-11-10-cloud-debug-0a91d60d.md)。时间以 Europe/Rome 记，跨 11 月 9 日至 10 日。

| 文件 | 内容 |
|---|---|
| `suite-summary.log` / `full-tests.log` | 全量包装脚本摘要与未过滤原始日志 |
| `import.log` / `check-scripts.log` / `check-content.log` | 资源导入、脚本加载、内容一致性检查 |
| `game-debug.log` | 4.7.1 实际桌面游戏日志，包含休息点退出的空 Viewport 错误 |
| `repro-author087.log` | 独立筛选复现；断言通过但有非预期引擎错误 |
| `probe_notice.gd.txt` / `probe-notice.log` | 排除开卷动画误报的几何检查；运行前将脚本文本复制为 `.gd` |
| `*.png` | 实际游戏截图，未经布局修饰 |
| `saves/settings.json` / `saves/slots/` | 隔离的新建测试存档；存档 1 为序章路线，存档 2 为跳过教程的自由模式路线 |

存档快照用于检查，不应覆盖真实玩家数据。无需任何玩家凭据。Godot 4.6.3 的早期失败诊断另留在云工作区 `/workspace/test-evidence/2026-11-09-debug/`，没有混入 4.7.1 的通过计数。
