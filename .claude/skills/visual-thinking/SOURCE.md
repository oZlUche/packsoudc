# 来源（本项目加的说明，不是上游文件）

- 上游：https://github.com/gaoyiiiii/visual-thinking
- 版本：commit `2161af823651bef2270bf6b8b77ee49e53c2b742`（2026-11-23）
- 许可：MIT（见同目录 [LICENSE](LICENSE)，版权 Visual Thinking contributors）；外部方法的署名见 [ATTRIBUTION.md](ATTRIBUTION.md)。
- 2026-11-27 装进本仓库，用来画游戏各系统 / 模块的关系图。

## 和上游的差别

- **删掉了全部 `.png` 预览图**（约 21 MB，仓库本来就大）。SVG 原件都在，文档里指向 `.png` 的链接会断；要看哪张就渲染：
  `node scripts/render-svg.cjs <图>.svg <输出>.png`（需要 Node.js 和 Playwright）。
- 加了 `.gdignore`，让 Godot 不扫这个目录。
- 加了本文件。其余文件逐字未改。

## 安全审阅（2026-11-27）

四个脚本都只读写本地文件，没有联网、没有执行外部命令：
`render-svg.cjs`（用 Playwright 把 SVG 渲染成 PNG，拒绝带脚本 / 外部资源的 SVG，并屏蔽所有网络请求）、
`inspect-svg.cjs`（排版诊断）、`apply-theme.cjs`（换主题色）、`export-public.py`（上游自己打包发布用，本项目用不到）。

## 本项目的样张

[docs/diagrams/](../../../docs/diagrams/README.md)
