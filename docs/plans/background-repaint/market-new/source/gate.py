# North perimeter and market standards. Dimensions are in metres.
def build_market_gate():
    from math import sin, cos, pi
    import random

    rng = random.Random(721)
    woods = [
        mat("Gate timber " + str(i), c, "wood")
        for i, c in enumerate(["#715337", "#856341", "#906e48", "#73593e", "#806047", "#977650"])
    ]
    endwood = mat("Sawn timber", "#a6845f", "wood")
    dark = mat("Shaded framing", "#5c4536", "wood")
    iron = mat("Gate strap iron", "#484944", "metal")
    roof = [
        mat("Watch roof " + str(i), c, "wood")
        for i, c in enumerate(
            (
                ["#8c4e35", "#a66042", "#99583f", "#874a37"]
                if STAGE >= 7
                else ["#514d44", "#61594b", "#726552", "#5b5142"]
            )
        )
    ]
    red = mat("Madder standards", "#a84332", "cloth")
    ochre = mat("Standard flax embroidery", "#e1b97a", "cloth")

    def timber(n, a, b, w, m=None):
        return beam(n, a, b, w, m or rng.choice(woods))

    # Hewn stockade uprights have irregular facets and a short axe-cut point.
    for left, right in [(-26, 1.88), (6.52, 26)]:
        count = round((right - left) / (0.49 if STAGE == 3 else 0.32))
        step = (right - left) / count
        for i in range(count):
            x = left + step * (i + 0.5)
            y = 11 + rng.uniform(-0.035, 0.035)
            h = rng.uniform(2.52, 2.78)
            w = step * 0.505
            v = [
                (x + w * cos(j * pi / 4 + pi / 8), y + 0.20 * sin(j * pi / 4 + pi / 8), z)
                for z in (-0.06, h - 0.24)
                for j in range(8)
            ]
            v.append((x + rng.uniform(-0.07, 0.07), y, h))
            f = [(j, (j + 1) % 8, (j + 1) % 8 + 8, j + 8) for j in range(8)]
            f += [(8 + j, 8 + (j + 1) % 8, 16) for j in range(8)]
            mesh("Split oak pale", v, f, rng.choice(woods))
        for z in (0.67, 1.81):
            box(
                "Continuous stockade rail",
                ((right + left) / 2, 10.81, z),
                (right - left, 0.18, 0.19),
                dark,
            )
    for x, sign in [(1.86, -1), (6.54, 1)]:
        box("Gate jamb", (x, 11, 1.92), (0.28, 0.42, 3.84), woods[1])
        # Both gate leaves stand fully open toward the far side.
        y0, y1 = 11.14, 13.25
        for j in range(8):
            box(
                "Open gate board",
                (x, y0 + (j + 0.5) * (y1 - y0) / 8, 1.24),
                (0.13, (y1 - y0) / 8 - 0.009, 2.38),
                woods[(j + 2) % 6],
            )
        for z in (0.48, 1.93):
            box("Gate ledge", (x - sign * 0.08, (y0 + y1) / 2, z), (0.10, 2.13, 0.15), dark)
        timber("Gate diagonal", (x - sign * 0.12, y0, 0.49), (x - sign * 0.12, y1, 1.93), 0.13)
        if STAGE >= 7:
            for z in (0.51, 1.94):
                box("Gate hinge band", (x, 10.775, z), (0.27, 0.035, 0.105), iron)
    for cx, side in [(-2.05, -1), (10.38, 1)]:
        cy = 12.05
        for sx in (-1, 1):
            for sy in (-1, 1):
                box(
                    "Watch post",
                    (cx + sx * 1.08, cy + sy * 0.92, 2.68),
                    (0.23, 0.23, 5.36),
                    woods[1],
                )
        for sy in (-1, 1):
            box("Deck ledger", (cx, cy + sy * 0.92, 3.52), (2.57, 0.21, 0.24), dark)
            timber(
                "Tower diagonal",
                (cx - 1.06, cy + sy * 0.92, 0.28),
                (cx + 1.06, cy + sy * 0.92, 3.45),
                0.16,
            )
        for i in range(10):
            box(
                "Platform plank",
                (cx - 1.2 + (i + 0.5) * 0.24, cy, 3.68),
                (0.232, 2.32, 0.14),
                woods[i % 6],
            )
        for sy in (-1, 1):
            # Front guardrail leaves a clear ladder landing on the outside corner.
            a, b = -1.08, 1.08
            if sy == -1:
                if side == -1:
                    a = -0.13
                else:
                    b = 0.13
            for z in (4.14, 4.60):
                box(
                    "Watch gallery rail",
                    (cx + (a + b) * 0.5, cy + sy * 0.94, z),
                    (b - a, 0.13, 0.115),
                    woods[1],
                )
            if sy == -1:
                box(
                    "Landing newel",
                    (cx + (a if side == -1 else b), cy - 0.94, 4.15),
                    (0.13, 0.13, 0.95),
                    woods[2],
                )
        for sx in (-1, 1):
            for z in (4.14, 4.60):
                box("Gallery end rail", (cx + sx * 1.08, cy, z), (0.14, 1.9, 0.12), woods[2])
        # One boarded roof plane on each side, with visible eaves and ridge.
        for slope in (-1, 1):
            board_count = 6 if STAGE == 3 else 12
            for i in range(board_count):
                a = cx - 1.58 + i * 3.16 / board_count
                b = a + 3.16 / board_count - 0.005
                v = [
                    (a, cy, 6.14),
                    (b, cy, 6.14),
                    (b, cy + slope * 1.41, 5.34),
                    (a, cy + slope * 1.41, 5.34),
                ]
                mesh(
                    "Gallery roof board",
                    v + [(x, y, z - 0.09) for x, y, z in v],
                    [
                        (0, 1, 2, 3),
                        (4, 7, 6, 5),
                        (0, 4, 5, 1),
                        (1, 5, 6, 2),
                        (2, 6, 7, 3),
                        (3, 7, 4, 0),
                    ],
                    roof[(i * 3 + i // 4) % 4],
                )
            box("Roof fascia", (cx, cy + slope * 1.39, 5.28), (3.19, 0.13, 0.16), dark)
        box("Ridge cap", (cx, cy, 6.14), (3.24, 0.18, 0.13), roof[0])
        lx = cx + side * 0.62
        start_y, end_y = 8.96, cy - 1.20
        for dx in (-0.29, 0.29):
            timber(
                "Ladder stile",
                (lx + dx, start_y, 0),
                (lx + dx, end_y + 0.28, 4.27),
                0.092,
                woods[3],
            )
        for j in range(12):
            z = 0.23 + j * 0.308
            y = start_y + (end_y + 0.28 - start_y) * z / 4.27
            timber("Ladder rung", (lx - 0.292, y, z), (lx + 0.292, y, z), 0.079, woods[2])
        if STAGE >= 7:
            for sx in (-1, 1):
                for sy in (-1, 1):
                    timber(
                        "Eave knee",
                        (cx + sx * 1.08, cy + sy * 0.92, 4.77),
                        (cx + sx * 0.61, cy + sy * 0.92, 5.31),
                        0.105,
                        dark,
                    )
        if STAGE >= 8:
            for sx in (-1, 1):
                for z in (3.50, 4.60):
                    box(
                        "Square peg head",
                        (cx + sx * 1.08, cy - 1.045, z),
                        (0.071, 0.030, 0.071),
                        endwood,
                    )

    def standard(x, y, h, wide, length, direction):
        box("Standard staff", (x, y, h / 2), (0.115, 0.115, h), woods[3])
        bar = h - 0.23
        timber(
            "Banner spar",
            (x - direction * 0.15, y, bar),
            (x + direction * (wide + 0.20), y, bar),
            0.081,
            woods[2],
        )

        def fabric(u, v, front=0):
            return (
                x + direction * (0.08 + wide * u + 0.11 * v * v),
                y - 0.06 - 0.09 * sin(2 * pi * u + 0.85 * v) * (0.28 + v) - 0.12 * v - front,
                bar
                - 0.07
                - length * v
                - 0.068 * sin(pi * u) * (1 - 0.25 * v)
                + 0.045 * v * sin(2 * pi * u),
            )

        def panel(name, ua, ub, va, vb, nx, ny, m, offset=0):
            verts = [
                fabric(ua + (ub - ua) * i / nx, va + (vb - va) * j / ny, offset)
                for j in range(ny + 1)
                for i in range(nx + 1)
            ]
            faces = [
                (
                    j * (nx + 1) + i,
                    j * (nx + 1) + i + 1,
                    (j + 1) * (nx + 1) + i + 1,
                    (j + 1) * (nx + 1) + i,
                )
                for j in range(ny)
                for i in range(nx)
            ]
            mesh(name, verts, faces, m)

        panel("Woven standard", 0, 1, 0, 1, 16, 12, red)
        # Embroidery is sampled from the same cloth map and follows each fold.
        for ua, ub, va, vb in [(0, 1, 0.85, 0.874)]:
            panel("Woven ochre motif", ua, ub, va, vb, 16, 8, ochre, 0.007)
        if STAGE >= 6:
            # A circular brass-coloured sun device, tessellated on the same cloth.
            v = [fabric(0.5, 0.46, 0.012)]
            for r in range(1, 5):
                for i in range(40):
                    t = 2 * pi * i / 40
                    v.append(
                        fabric(
                            0.5 + 0.265 * r / 4 * cos(t),
                            0.46 + 0.265 * wide / length * r / 4 * sin(t),
                            0.012,
                        )
                    )
            faces = [(0, 1 + i, 1 + (i + 1) % 40) for i in range(40)]
            faces.extend(
                (
                    1 + (r - 1) * 40 + i,
                    1 + (r - 1) * 40 + (i + 1) % 40,
                    1 + r * 40 + (i + 1) % 40,
                    1 + r * 40 + i,
                )
                for r in range(1, 4)
                for i in range(40)
            )
            mesh("Embroidered solar disc", v, faces, ochre)
        else:
            for ua, ub, va, vb in [(0.45, 0.55, 0.24, 0.67), (0.30, 0.70, 0.43, 0.49)]:
                panel("Device registration", ua, ub, va, vb, 16, 8, ochre, 0.007)
        if STAGE >= 7:
            for u in (0.04, 0.48, 0.94):
                X, Y, Z = fabric(u, 0)
                timber("Banner tie", (X, Y, Z - 0.04), (X, y, bar + 0.05), 0.028, ochre)

    standard(1.55, 10.69, 4.57, 0.90, 1.58, -1)
    standard(6.83, 10.69, 4.57, 0.90, 1.58, 1)
    before = set(bpy.context.scene.objects)
    standard(7.6, -1.65, 3.8, 1.09, 1.94, -1)
    for ob in set(bpy.context.scene.objects) - before:
        ob["near_standard"] = True


build_market_gate()
