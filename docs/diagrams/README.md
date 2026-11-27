# 关系图

用 [visual-thinking skill](../../.claude/skills/visual-thinking/SOURCE.md) 画的图。SVG 是可编辑原件，PNG 是渲染结果，`src/` 是生成脚本。

| 日期 | 图 | 说明 |
|---|---|---|
| 2026-11-27 | [模块关系](2026-11-27-module-relations.png)（[SVG](2026-11-27-module-relations.svg)） | 样张：营地各设施、出征三屏、局内循环、结算之间东西和流程怎么走（v9.20） |
| 2026-11-27 | [一局如何结算](2026-11-27-run-settlement.png)（[SVG](2026-11-27-run-settlement.svg)） | 展开总览的「结算」节点，沿代码追踪撤离、战败、保险箱和局外存档。总览中的战败损失描述适用于作战区，保险箱规则见本图。 |
| 2026-11-27 | [局内循环](2026-11-27-in-run-loop.png)（[SVG](2026-11-27-in-run-loop.svg)） | 展开总览的「局内」部分，追踪走图、搜刮、战斗、背包与撤离，标出体力、倒计时和侵蚀的触发位置。 |
| 2026-11-27 | [存量与回流](2026-11-27-module-flows.png)（[SVG](2026-11-27-module-flows.svg)） | 按 skill 完整流程重画的模块关系：选「检查积累与回流」，仓库是存量，出征是关口，一局是循环，撤离回流、战败流失；四个提问对着成型速度。生成脚本 `src/module_flows.py` |
| 2026-11-27 | [基地与跨局成长](2026-11-27-camp-progression.png)（[SVG](2026-11-27-camp-progression.svg)） | 展开总览的基地部分。从结算追踪仓库、委托、科技和后勤，再接回出征准备。 |

总览可用 `python3 docs/diagrams/src/module_relations.py out.svg` 重画。其余三张图直接编辑 SVG。各图都可用 skill 的 `scripts/render-svg.cjs` 渲染 PNG。

结算图依据 [RunState](../../core/run/run_state.gd#L518) 的结束条件、[RunResult](../../core/run/run_result.gd#L80) 的盘点规则、[MetaState](../../core/meta/meta_state.gd#L357) 的入账规则，以及 [GameFlow](../../core/run/game_flow.gd#L2089) 的记账和写档顺序。

局内循环图依据 [RunState](../../core/run/run_state.gd#L330)、[MapTravel](../../core/run/map_travel.gd#L87)、[NodeEvents](../../core/run/node_events.gd#L178)、[SearchSession](../../core/run/search_session.gd#L94)、[GameFlow](../../core/run/game_flow.gd#L2527)、[CountdownModule](../../core/run/modules/countdown_module.gd#L44) 和 [ErosionField](../../core/run/erosion/erosion_field.gd#L81)。图展开常规路线，事件、猎手、逃跑与求饶的细分支留在对应实现中。本局结束后的入账见上表「一局如何结算」。

基地与跨局成长图依据 [结算与存档操作](../../core/run/game_flow.gd#L2089)、[基地入账](../../core/meta/meta_state.gd#L357)、[委托完成与跨局合并](../../core/meta/commissions/commissions.gd#L628)、[科技升级](../../core/meta/tech_service.gd#L195)、[集市](../../core/meta/market.gd)、[铁匠铺](../../core/meta/smithy.gd)、[炼金](../../core/meta/alchemy.gd)、[苗圃](../../core/meta/nursery.gd)、[食堂](../../core/meta/canteen.gd)、[万神院](../../core/meta/pantheon.gd) 与 [出征输入](../../core/run/game_flow.gd#L1634)。从「出征准备」接读局内循环，从「回营结算」接读结算图。
