#!/usr/bin/env python3
"""Module relations as a stock-and-flow thinking map (visual-thinking skill, monochrome theme).

Action chosen from the skill's structure-selection card: 检查积累与回流 (stock, inflow, outflow, return).
Not a preset skeleton (the skill ships none for stock-and-flow); drawn independently.
Usage: python3 module_flows.py out.svg
"""
import math
import sys

BG, INK, MUTED, FAINT = "#191A18", "#EFEEE7", "#B0B2A8", "#686E63"
FONT = '"PingFang SC","Noto Sans CJK SC","Source Han Sans SC","Microsoft YaHei","WenQuanYi Zen Hei",sans-serif'
W, H = 2400, 1880
out = []


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def text(x, y, s, size=20, fill=MUTED, anchor="start", weight=400, extra=""):
    out.append(f'<text x="{x:.0f}" y="{y:.0f}" font-size="{size}" fill="{fill}" text-anchor="{anchor}" font-weight="{weight}"{extra}>{esc(s)}</text>')


def circle(nid, cx, cy, r, title, subs=(), dashed=False, tsize=24, width=1.6):
    dash = ' stroke-dasharray="6 6"' if dashed else ""
    out.append(f'<circle id="{nid}" data-node="" cx="{cx}" cy="{cy}" r="{r}" fill="{BG}" stroke="{INK}" stroke-width="{width}"{dash}/>')
    total = tsize + len(subs) * 27
    ty = cy - total / 2 + tsize - 4
    text(cx, ty, title, tsize, INK, "middle", 500, f' data-in-node="{nid}" data-padding="4"')
    for i, s in enumerate(subs):
        text(cx, ty + 30 + i * 26, s, 18, MUTED, "middle", 400, f' data-in-node="{nid}" data-padding="4"')


def path_d(pts, r=12):
    d = f"M{pts[0][0]:.1f} {pts[0][1]:.1f}"
    for i in range(1, len(pts) - 1):
        (ax, ay), (bx, by), (cx, cy) = pts[i - 1], pts[i], pts[i + 1]
        ux, uy = (bx > ax) - (bx < ax), (by > ay) - (by < ay)
        vx, vy = (cx > bx) - (cx < bx), (cy > by) - (cy < by)
        sweep = 1 if (ux * vy - uy * vx) > 0 else 0
        d += f"L{bx - ux * r:.1f} {by - uy * r:.1f}A{r} {r} 0 0 {sweep} {bx + vx * r:.1f} {by + vy * r:.1f}"
    return d + f"L{pts[-1][0]:.1f} {pts[-1][1]:.1f}"


def edge(eid, frm, to, pts, both=False, dashed=False, width=1.8, color=INK, arrow=True):
    extra = ' marker-end="url(#arr)"' if arrow else ""
    if both:
        extra += ' marker-start="url(#arr)"'
    if dashed:
        extra += ' stroke-dasharray="6 7"'
    ann = f' data-edge="" data-from="{frm}" data-to="{to}"' if frm and to else ""
    out.append(f'<path id="{eid}"{ann} d="{path_d(pts)}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round"{extra}/>')


def on_circle(cx, cy, r, axis, value, side):
    """Point on a circle where a horizontal (axis='y') or vertical (axis='x') line meets it."""
    if axis == "y":
        return (cx + side * math.sqrt(r * r - (value - cy) ** 2), value)
    return (value, cy + side * math.sqrt(r * r - (value - cx) ** 2))


def dot(x, y):
    out.append(f'<circle data-decoration="junction" cx="{x}" cy="{y}" r="5" fill="{INK}"/>')


# ---------------- header ----------------
out.append(f'<rect data-decoration="background" width="{W}" height="{H}" fill="{BG}"/>')
text(90, 112, "这一局带回的，怎样变成下一局的起点", 46, INK, "start", 600)
text(90, 162, "What a run brings home, and how it becomes the next run's start", 25, MUTED)

# ---------------- stocks ----------------
WX, WY, WR = 900, 900, 150          # warehouse
circle("stock", WX, WY, WR, "仓库", ["存量：下一局能带的", "都先在这里"], tsize=40, width=2.4)
FX, FY, FR = 900, 1290, 72          # camp funds
circle("funds", FX, FY, FR, "营地资金", ["钱"], tsize=22, width=2.0)

# ---------------- camp converters ----------------
circle("smithy", 470, 640, 66, "铁匠铺", ["按配方打造"])
circle("alchemy", 470, 900, 74, "炼金", ["化成万物之尘"], dashed=True)
circle("market", 620, 1290, 62, "集市", ["买 · 卖"])

# warehouse -> alchemy
edge("e-st-al", "stock", "alchemy", [(WX - WR, 900), (544, 900)])
text(641, 885, "丢道具", 19, MUTED, "middle")
# alchemy -> smithy
edge("e-al-sm", "alchemy", "smithy", [(470, 826), (470, 706)])
text(486, 780, "尘补缺料", 19, MUTED)
# smithy <-> warehouse
p_top = on_circle(WX, WY, WR, "x", 800, -1)
edge("e-sm-st", "smithy", "stock", [(536, 640), (800, 640), p_top], both=True)
text(668, 626, "素材进 · 成品出", 19, MUTED, "middle")
# market <-> funds, market <-> warehouse
edge("e-mk-fu", "market", "funds", [(682, 1290), (FX - FR, 1290)], both=True)
text(755, 1276, "钱", 19, MUTED, "middle")
p_ml = on_circle(WX, WY, WR, "y", 1000, -1)
edge("e-mk-st", "market", "stock", [(620, 1228), (620, 1000), p_ml], both=True)
text(636, 1110, "道具", 19, MUTED)

# ---------------- run loop ----------------
RX, RY, RR, NR = 1950, 900, 220, 62
out.append(f'<circle data-decoration="run-ring" cx="{RX}" cy="{RY}" r="{RR}" fill="none" stroke="{FAINT}" stroke-width="1.2"/>')
nodes = [("walk", -90, "走地图", ["选路线"]), ("fight", 0, "遭遇战", ["自动对打"]),
         ("loot", 90, "搜刮", ["揭开掉落"]), ("bag", 180, "背包取舍", ["装不下就扔"])]
pos = {}
for nid, ang, t, subs in nodes:
    x = RX + RR * math.cos(math.radians(ang))
    y = RY + RR * math.sin(math.radians(ang))
    pos[nid] = (round(x), round(y))
off = math.degrees(math.asin((NR + 10) / RR))
arc_labels = ["遇敌", "打赢", "捡进来", "继续深入"]
for i in range(4):
    a0 = -90 + 90 * i + off
    a1 = -90 + 90 * (i + 1) - off
    x0, y0 = RX + RR * math.cos(math.radians(a0)), RY + RR * math.sin(math.radians(a0))
    x1, y1 = RX + RR * math.cos(math.radians(a1)), RY + RR * math.sin(math.radians(a1))
    frm, to = nodes[i][0], nodes[(i + 1) % 4][0]
    out.append(f'<path id="arc-{i}" data-edge="" data-from="{frm}" data-to="{to}" d="M{x0:.1f} {y0:.1f}A{RR} {RR} 0 0 1 {x1:.1f} {y1:.1f}" '
               f'fill="none" stroke="{INK}" stroke-width="1.8" marker-end="url(#arr)"/>')
    am = math.radians(-45 + 90 * i)
    lx, ly = RX + (RR - 58) * math.cos(am), RY + (RR - 58) * math.sin(am) + 7
    text(lx, ly, arc_labels[i], 19, MUTED, "middle")
for nid, ang, t, subs in nodes:
    circle(nid, pos[nid][0], pos[nid][1], NR, t, subs, tsize=23)
text(RX, RY - 14, "一局", 34, INK, "middle", 500)
text(RX, RY + 22, "体力 · 倒计时 · 侵蚀 · 猎手", 18, MUTED, "middle")
text(RX, RY + 48, "一直逼你往外走", 18, MUTED, "middle")

# in-run growth (does not go home)
fx, fy = pos["fight"]
circle("grow", fx, 590, 62, "升级选牌", ["通用 + 神恩"], tsize=21)
edge("e-fi-gr", "fight", "grow", [(fx, fy - NR), (fx, 652)])
text(fx + 14, 770, "经验值", 19, MUTED)
text(fx + 66, 590, "局内成长", 19, MUTED)
text(fx + 66, 616, "带不回营地", 19, MUTED)

# ---------------- departure: one gate on the trunk ----------------
bx, by = pos["bag"]
TY = 900
GX = 1560
edge("e-st-bag", "stock", "bag", [(WX + WR, TY), (bx - NR, TY)], width=2.4)
out.append(f'<path data-decoration="gate" d="M{GX - 6} {TY - 46}V{TY + 46}M{GX + 6} {TY - 46}V{TY + 46}" stroke="{INK}" stroke-width="2.4"/>')
text(GX, TY + 80, "出征", 26, INK, "middle", 500)
text(GX, TY + 110, "角色 · 一锅 · 信仰", 18, MUTED, "middle")
text(GX, TY + 135, "带入 · 地图 · 难度", 18, MUTED, "middle")
text(1110, TY - 16, "带入装备", 19, MUTED)

# feeders from above, merging into the trunk before the gate
circle("tech", 1200, 640, 58, "科技", ["永久加成"])
circle("nursery", 1350, 430, 58, "苗圃", ["种食材"], dashed=True)
circle("canteen", 1350, 640, 58, "食堂", ["摆一锅"], dashed=True)
circle("pantheon", 1490, 640, 58, "万神院", ["奉哪位神"], dashed=True)
p_tr = on_circle(WX, WY, WR, "x", 1000, -1)
edge("e-st-te", "stock", "tech", [p_tr, (1000, 640), (1142, 640)])
text(1014, 715, "上交", 19, MUTED)
edge("e-nu-ca", "nursery", "canteen", [(1350, 488), (1350, 582)])
text(1364, 542, "食材", 19, MUTED)
for nid, x in (("tech", 1200), ("canteen", 1350), ("pantheon", 1490)):
    edge(f"e-{nid}-trunk", nid, None, [(x, 698), (x, TY)], arrow=False)
    dot(x, TY)

# ---------------- outflows ----------------
# extract -> home
EX, EY = bx, 1290
circle("exit", EX, EY, 58, "撤离", ["活着出去"])
edge("e-bag-ex", "bag", "exit", [(bx, by + NR), (bx, EY - 58)])
text(bx - 14, 1080, "见好就收", 19, MUTED, "end")
JX = 1150
edge("e-ex-fu", "exit", "funds", [(EX - 58, EY), (FX + FR, EY)], width=2.4)
dot(JX, EY)
p_rs = on_circle(WX, WY, WR, "y", 1000, 1)
edge("e-ex-st", "exit", "stock", [(JX, EY), (JX, 1000), p_rs], width=2.4)
text(JX + 14, 1150, "带出来的东西", 19, MUTED)
text(1290, EY - 14, "钱包余额", 19, MUTED, "middle")
text(1290, EY + 40, "同时：委托记进度，苗圃长一格", 18, MUTED, "middle")

# defeat leak
lx, ly = pos["fight"][0], 1290
circle("lost", lx, ly, 58, "丢失", ["作战区"], dashed=True)
edge("e-fi-lo", "fight", "lost", [(fx, fy + NR), (lx, ly - 58)], dashed=True)
text(fx + 14, 1080, "战败", 19, MUTED)
text(lx, ly + 92, "托付进保险箱的、局外奖励", 18, MUTED, "middle")
text(lx, ly + 118, "战败也照样入账", 18, MUTED, "middle")

# ---------------- thinking prompts, placed on the relations ----------------
text(1190, 1000, "①", 22, INK)
text(1220, 1000, "下一局比这局强多少？", 20, INK)
text(1220, 1030, "看有几股汇进这道口", 20, MUTED)
text(1572, 560, "②", 22, INK)
text(1602, 560, "科技一次到手就永久", 20, INK)
text(1602, 590, "一锅、信仰、带入每局重喂", 20, INK)
text(1602, 620, "成型靠哪一种更快？", 20, MUTED)
text(1520, 1420, "③", 22, INK)
text(1550, 1420, "背包装得下多少，这局就存下多少：容量先卡住哪一类？", 20, INK)
text(390, 500, "④", 22, INK)
text(420, 500, "营地里转一圈不出门：同一份存量换个形状", 20, INK)
text(420, 530, "多绕一圈，带入会变强多少？", 20, MUTED)

# ---------------- footer ----------------
out.append(f'<path data-decoration="rule" d="M90 1560H2310" fill="none" stroke="{FAINT}" stroke-width="1"/>')
text(90, 1628, "成型速度卡在哪：试着截断一股回流", 32, INK, "start", 500)
text(90, 1672, "拿掉「带出来的东西」，仓库只靠集市和铁匠铺能长多快？拿掉科技，带入还剩哪几股？哪一股断了，下一局就停在原地？", 21, MUTED)
out.append(f'<circle data-decoration="legend" cx="104" cy="1736" r="14" fill="none" stroke="{INK}" stroke-width="1.4" stroke-dasharray="5 5"/>')
text(128, 1743, "虚线圈：靠委托声望开放", 18, MUTED)
out.append(f'<path data-decoration="legend" d="M380 1736H440" stroke="{INK}" stroke-width="1.8" stroke-dasharray="6 7"/>')
text(452, 1743, "虚线箭头：流失", 18, MUTED)
out.append(f'<path data-decoration="legend" d="M630 1736H690" stroke="{INK}" stroke-width="2.4"/>')
text(702, 1743, "粗线：存量进出的主干", 18, MUTED)
out.append(f'<path data-decoration="legend" d="M944 1716V1756M956 1716V1756" stroke="{INK}" stroke-width="2.4"/>')
text(972, 1743, "关口：出征三屏", 18, MUTED)
text(90, 1810, "示意，不编码数量：圈的大小、线的长短不代表多少。局内商店、事件、营火未画。"
     "依据 v9.25 的 docs/architecture.md §0、core/meta/*.gd 与 core/run/run_result.gd 头注释，及结算图 2026-11-27-run-settlement。", 17, MUTED)

title = "这一局带回的，怎样变成下一局的起点"
desc = ("存量与回流图。仓库是存量：粗线从仓库经出征关口带入一局，一局是走地图、遭遇战、搜刮、背包取舍的循环。"
        "撤离把带出来的东西送回仓库、钱包余额送进营地资金；战败时作战区的东西流失，托付和局外奖励照样入账。"
        "营地里，炼金把道具化成尘给铁匠铺补料，铁匠铺吃素材出成品，集市在钱和道具之间互换；科技吃上交、给永久加成；"
        "苗圃种食材给食堂，食堂、万神院、科技都在关口前汇入下一局。经验值和升级选牌只在局内。"
        "四个提问分别放在关口、永久与每局消耗的对比、背包容量和营地内循环处，底部提示截断一股回流来检查成型速度。")
svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" aria-labelledby="t" aria-describedby="d">'
       f'<title id="t">{esc(title)}</title><desc id="d">{esc(desc)}</desc>'
       f'<defs><marker id="arr" viewBox="0 0 12 12" refX="10" refY="6" markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
       f'<path d="M2 2L10 6L2 10" fill="none" stroke="{INK}" stroke-width="1.4"/></marker></defs>'
       f'<style>text{{font-family:{FONT}}}</style>' + "".join(out) + "</svg>\n")
open(sys.argv[1], "w", encoding="utf-8").write(svg)
