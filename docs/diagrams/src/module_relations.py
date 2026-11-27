#!/usr/bin/env python3
"""Generate the module-relationship sample SVG (monochrome theme of visual-thinking)."""
import sys

BG, INK, MUTED, SURF, FRAME = "#191A18", "#EFEEE7", "#B0B2A8", "#272925", "#686E63"
FONT = '"PingFang SC","Noto Sans CJK SC","Source Han Sans SC","Microsoft YaHei","WenQuanYi Zen Hei",sans-serif'
W, H = 2400, 1720
out = []


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def text(x, y, s, size=19, fill=MUTED, anchor="start", weight=400, extra=""):
    out.append(f'<text x="{x}" y="{y}" font-size="{size}" fill="{fill}" text-anchor="{anchor}" font-weight="{weight}"{extra}>{esc(s)}</text>')


def grid_icon(x, y):
    # small 3x3 board mark: "this is a board"
    out.append(f'<g data-decoration="board-mark"><rect x="{x}" y="{y}" width="27" height="27" fill="none" stroke="{MUTED}" stroke-width="1.2"/>'
               f'<path d="M{x+9} {y}V{y+27}M{x+18} {y}V{y+27}M{x} {y+9}H{x+27}M{x} {y+18}H{x+27}" stroke="{MUTED}" stroke-width="1"/></g>')


def box(nid, x1, y1, x2, y2, title, subs=(), dashed=False, board=False, tsize=27):
    dash = ' stroke-dasharray="7 6"' if dashed else ""
    out.append(f'<rect id="{nid}" data-node="" x="{x1}" y="{y1}" width="{x2-x1}" height="{y2-y1}" rx="12" fill="{SURF}" stroke="{INK}" stroke-width="1.6"{dash}/>')
    cx = (x1 + x2) / 2
    n = len(subs)
    total = tsize + n * 30
    ty = (y1 + y2) / 2 - total / 2 + tsize - 3
    text(cx, round(ty), title, tsize, INK, "middle", 500, f' data-in-node="{nid}" data-padding="6"')
    for i, s in enumerate(subs):
        text(cx, round(ty + 32 + i * 29), s, 19, MUTED, "middle", 400, f' data-in-node="{nid}" data-padding="6"')
    if board:
        grid_icon(x2 - 39, y1 + 12)


def path_d(pts, r=12):
    d = f"M{pts[0][0]} {pts[0][1]}"
    for i in range(1, len(pts) - 1):
        (ax, ay), (bx, by), (cx, cy) = pts[i - 1], pts[i], pts[i + 1]
        ux, uy = (bx > ax) - (bx < ax), (by > ay) - (by < ay)
        vx, vy = (cx > bx) - (cx < bx), (cy > by) - (cy < by)
        p1 = (bx - ux * r, by - uy * r)
        p2 = (bx + vx * r, by + vy * r)
        sweep = 1 if (ux * vy - uy * vx) > 0 else 0
        d += f"L{p1[0]} {p1[1]}A{r} {r} 0 0 {sweep} {p2[0]} {p2[1]}"
    d += f"L{pts[-1][0]} {pts[-1][1]}"
    return d


def edge(eid, frm, to, pts, both=False, width=2.0, color=INK):
    start = ' marker-start="url(#arr)"' if both else ""
    ann = f' data-edge="" data-from="{frm}" data-to="{to}"' if to != "camp" else ""
    out.append(f'<path id="{eid}"{ann} d="{path_d(pts)}" fill="none" stroke="{color}" '
               f'stroke-width="{width}" stroke-linecap="round" marker-end="url(#arr)"{start}/>')


def region(x1, y1, x2, y2, label, note=None):
    out.append(f'<rect data-decoration="region" x="{x1}" y="{y1}" width="{x2-x1}" height="{y2-y1}" rx="12" fill="none" stroke="{FRAME}" stroke-width="1.2"/>')
    text(x1 + 34, y1 + 54, label, 34, INK, "start", 500)
    if note:
        text(x1 + 34, y1 + 92, note, 19, MUTED)


# ---------- header ----------
out.append(f'<rect data-decoration="background" width="{W}" height="{H}" fill="{BG}"/>')
text(90, 110, "背包搜打撤：各系统怎样互相喂养", 46, INK, "start", 600)
text(90, 160, "How the camp, the departure and the run feed one another", 25, MUTED)
out.append(f'<path data-decoration="rule" d="M90 195H1300" fill="none" stroke="{FRAME}" stroke-width="1.2"/>')

# ---------- regions ----------
region(90, 250, 1010, 1150, "营地 · 局外")
region(1440, 250, 2330, 1150, "一局 · 局内（核心）")
text(1100, 515, "出征 · 三屏", 30, INK, "start", 500)

# camp: commissions band
box("rep", 130, 350, 970, 450, "委托与声望", ["办委托涨各方声望；虚线框的设施靠声望开放"], tsize=26)
# top row
box("nursery", 130, 600, 330, 690, "苗圃", ["每局长一格"], dashed=True, board=True)
box("canteen", 430, 600, 670, 690, "食堂", ["食材摆一锅"], dashed=True, board=True)
box("pantheon", 770, 600, 970, 690, "万神院", ["选这局的神"], dashed=True)
# middle row
box("tech", 130, 780, 330, 890, "科技", ["永久提升", "设施升级"])
box("warehouse", 430, 780, 670, 890, "仓库", ["局外的全部家底"], board=True)
# bottom row
box("market", 130, 1000, 330, 1090, "集市", ["钱 ⇄ 道具"])
box("alchemy", 430, 1000, 670, 1090, "炼金", ["道具化成万物之尘"], dashed=True)
box("smithy", 770, 1000, 970, 1090, "铁匠铺", ["按配方打造"])

# departure
box("d1", 1100, 540, 1340, 700, "① 角色·食物·信仰", ["吃掉这一锅", "奉哪位神"], tsize=24)
box("d2", 1100, 760, 1340, 860, "② 带入装备", ["从仓库挑"], tsize=24)
box("d3", 1100, 960, 1340, 1060, "③ 地图·难度", ["选图 · 选 A 级"], tsize=24)

# run
box("growth", 1960, 330, 2260, 420, "升级选牌", ["通用牌 + 神恩牌"])
box("walk", 1500, 560, 1760, 680, "走地图", ["选路线", "越深越险，也越肥"])
box("fight", 1960, 560, 2260, 680, "遭遇战", ["背包编译成战斗力", "双方自动对打"])
box("loot", 1960, 820, 2260, 920, "搜刮", ["尸体·宝箱·搜索点"])
box("bag", 1500, 820, 1760, 920, "背包取舍", ["格子有限：留什么、扔什么"], board=True)
box("exit", 1500, 1040, 1760, 1120, "撤离点", ["活着出去才算数"])
box("pressure", 1960, 1040, 2260, 1120, "压力", ["体力·倒计时·侵蚀·猎手"])

# settlement
box("settle", 1100, 1230, 1760, 1370, "结算", ["撤离：所得进仓库 · 委托算数 · 苗圃长一格", "战败：带入的与捡到的全丢"])

# ---------- edges (camp) ----------
edge("e-n-c", "nursery", "canteen", [(330, 645), (430, 645)])
text(380, 632, "食材", 19, MUTED, "middle")
edge("e-w-t", "warehouse", "tech", [(430, 835), (330, 835)])
text(380, 822, "上交", 19, MUTED, "middle")
edge("e-w-al", "warehouse", "alchemy", [(550, 890), (550, 1000)])
text(565, 952, "丢道具", 19, MUTED)
edge("e-al-s", "alchemy", "smithy", [(670, 1045), (770, 1045)])
text(720, 1032, "尘补料", 19, MUTED, "middle")
edge("e-s-w", "smithy", "warehouse", [(870, 1000), (870, 860), (670, 860)], both=True)
text(885, 940, "素材进", 19, MUTED)
text(885, 968, "成品出", 19, MUTED)
edge("e-m-w", "market", "warehouse", [(300, 1000), (300, 945), (470, 945), (470, 890)], both=True)
text(318, 985, "买 · 卖", 19, MUTED)

# camp -> departure
edge("e-c-d1", "canteen", "d1", [(550, 600), (550, 560), (1100, 560)])
text(1000, 547, "这一锅", 19, MUTED, "middle")
edge("e-p-d1", "pantheon", "d1", [(970, 645), (1100, 645)])
text(1035, 632, "信仰", 19, MUTED, "middle")
edge("e-w-d2", "warehouse", "d2", [(670, 810), (1100, 810)])
text(1000, 797, "带入", 19, MUTED, "middle")
edge("e-d1-d2", "d1", "d2", [(1220, 700), (1220, 760)])
edge("e-d2-d3", "d2", "d3", [(1220, 860), (1220, 960)])

# departure -> run
edge("e-d3-walk", "d3", "walk", [(1340, 1010), (1400, 1010), (1400, 620), (1500, 620)])
text(1415, 820, "出发", 19, MUTED)
edge("e-d1-g", "d1", "growth", [(1300, 540), (1300, 375), (1960, 375)])
text(1620, 362, "奉的神决定神恩牌", 19, MUTED, "middle")

# run loop
edge("e-walk-fight", "walk", "fight", [(1760, 620), (1960, 620)])
text(1860, 607, "遇敌", 19, MUTED, "middle")
edge("e-fight-loot", "fight", "loot", [(2110, 680), (2110, 820)])
text(2125, 756, "打赢", 19, MUTED)
edge("e-fight-g", "fight", "growth", [(2110, 560), (2110, 420)])
text(2125, 497, "经验值", 19, MUTED)
edge("e-loot-bag", "loot", "bag", [(1960, 870), (1760, 870)])
text(1860, 857, "捡进来", 19, MUTED, "middle")
edge("e-bag-walk", "bag", "walk", [(1630, 820), (1630, 680)])
text(1645, 756, "继续深入", 19, MUTED)
edge("e-bag-exit", "bag", "exit", [(1630, 920), (1630, 1040)])
text(1645, 986, "见好就收", 19, MUTED)
edge("e-pr-exit", "pressure", "exit", [(1960, 1080), (1760, 1080)])
text(1860, 1067, "逼着撤", 19, MUTED, "middle")

# outcomes
edge("e-exit-settle", "exit", "settle", [(1630, 1120), (1630, 1230)])
edge("e-fight-settle", "fight", "settle", [(2260, 620), (2295, 620), (2295, 1300), (1760, 1300)])
text(2280, 1240, "战败", 19, MUTED, "end")
edge("e-settle-camp", "settle", "camp", [(1100, 1300), (550, 1300), (550, 1150)])
text(825, 1287, "回营地，开下一局", 19, MUTED, "middle")

# ---------- footer ----------
text(90, 1490, "成型速度卡在哪一条线上？", 30, INK, "start", 500)
text(90, 1532, "沿仓库往外的几支箭头各走一遍：哪一支最快让下一局的带入变强，又该让哪里成为它的代价？", 21, MUTED)
grid_icon(90, 1590)
text(130, 1612, "棋盘：位置和形状有意义", 19, MUTED)
out.append(f'<rect data-decoration="legend" x="400" y="1592" width="40" height="24" rx="6" fill="none" stroke="{INK}" stroke-width="1.4" stroke-dasharray="7 6"/>')
text(452, 1612, "靠委托声望开放", 19, MUTED)
text(640, 1612, "箭头：东西或流程往哪走；双头 = 两边都走", 19, MUTED)
text(90, 1660, "示意只画主干：局内商店、事件、营火、托付、猎手细节未画。依据 docs/architecture.md §0 §2 与 core/meta/*.gd 头注释（v9.20）。", 18, MUTED)

title = "背包搜打撤：各系统怎样互相喂养"
desc = ("左边营地：仓库居中，与集市互相买卖，上交给科技，丢给炼金化成万物之尘再给铁匠铺补料，铁匠铺吃素材出成品回仓库；"
        "苗圃种出食材给食堂摆一锅；苗圃、食堂、炼金、万神院靠委托声望开放。中间出征三屏：角色食物信仰、带入装备、地图难度。"
        "右边一局是循环：走地图、遭遇战、搜刮、背包取舍，再继续深入或去撤离点；压力逼着撤；战斗得经验值升级选牌，奉的神决定神恩牌。"
        "撤离或战败都进结算，再回营地开下一局。")
svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" aria-labelledby="t" aria-describedby="d">'
       f'<title id="t">{esc(title)}</title><desc id="d">{esc(desc)}</desc>'
       f'<defs><marker id="arr" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
       f'<path d="M2 2L10 6L2 10" fill="none" stroke="{INK}" stroke-width="1.4"/></marker></defs>'
       f'<style>text{{font-family:{FONT}}}</style>' + "".join(out) + "</svg>\n")
open(sys.argv[1], "w", encoding="utf-8").write(svg)
