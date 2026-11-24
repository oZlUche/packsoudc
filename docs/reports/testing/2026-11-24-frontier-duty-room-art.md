# 边堡值房美术稿 · 基地界面预览

本次为美术稿验证。Godot 4.6.3 使用原游戏控件，通过进程内预览纹理查看候选图。复现时打开基地，分别进入仓库和书架页，核实 backdrop_name 为 home/bg_home 后载入候选稿，待一帧绘制完成后截取视口。

| 页面 | 视口 | 实际结果 |
|---|---|---|
| 仓库 | 1280 × 800 | 侧栏与格盘间有火床、陶罐和石铺面，下缘露出织毯。[美术预览](../../plans/background-repaint/base-hall/ui-preview.jpg) |
| 书架 | 1280 × 720 | 陈列面板遮盖画面中部，左右各有帘布和支架露出，原有标签仍可读。[美术预览](../../plans/background-repaint/base-hall/ui-preview-shelf.jpg) |

这两个状态中未观察到由新图引起的控件可读性问题。截图脚本退出清理时 Godot 报告 GLES3 纹理及资源仍被引用，日志发生在截图成功写出之后。未执行负向用例、全量回归、其他语言或字号走查。完整证据随独立画稿交付。[审查记录](../../plans/background-repaint/base-hall/reviews.md)
