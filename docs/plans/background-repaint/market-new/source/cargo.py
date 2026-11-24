# Local axes: the shafts point down the lane, the axle crosses the body.
def make_market_cargo():
    from math import sin, cos, pi
    from mathutils import Vector, Matrix

    wood = mat("Wagon | oiled oak", "#805138", "wood")
    alternate = mat("Wagon | weathered oak", "#a17047", "wood")
    endgrain = mat("Wagon | exposed end grain", "#b18459", "wood")
    darkwood = mat("Wagon | walnut frame", "#513729", "wood")
    iron = mat("Wagon | forged tires and straps", "#444744", "metal")
    polished = mat("Amber worn hand grip", "#d8aa71", "wood")
    polished.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value = 0.30
    chipped = mat("Exposed dry wood at impact", "#c79962", "wood")
    grey = mat("Weathered lower crate", "#746450", "wood")
    rope = mat("Cargo | hemp line", "#a4895c", "cloth")
    linen = mat("Cargo | oat sacking", "#bda474", "cloth")
    olive = mat("Cargo | sage sacking", "#858263", "cloth")
    ceramic = mat("Cargo | fired red clay", "#ae6246", "clay")
    glaze = mat("Cargo | dark green slip", "#596b60", "clay")
    inside = mat("Cargo | jar interior", "#372e27")
    origin = Vector((-6.0, -7.0, 0))
    axis = Vector((0.49, 0.87172, 0)).normalized()
    fore = Vector((axis.y, -axis.x, 0))

    def world(p):
        return origin + axis * p[0] + fore * p[1] + Vector((0, 0, p[2]))

    def plank(label, p, size, m):
        obj = box(label, world(p), size, m)
        obj.rotation_euler.z = math.atan2(axis.y, axis.x)
        return obj

    def bar(label, a, b, width, m):
        return beam(label, world(a), world(b), width, m)

    def ring(label, x, r, width, thick, m):
        vs, fs = [], []
        n = 32
        for side, radius in ((-1, r), (1, r), (1, r - thick), (-1, r - thick)):
            for j in range(n):
                t = 2 * pi * j / n
                vs.append(world((x + side * width / 2, radius * cos(t), 0.83 + radius * sin(t))))
        for k in range(4):
            for j in range(n):
                fs.append(
                    (
                        k * n + j,
                        k * n + (j + 1) % n,
                        ((k + 1) % 4) * n + (j + 1) % n,
                        ((k + 1) % 4) * n + j,
                    )
                )
        return mesh(label, vs, fs, m)

    def turned(label, c, profile, m, n=20, flute=0, phase=0):
        vs, fs = [], []
        for k, (z, rx, ry, dx, dy) in enumerate(profile):
            for j in range(n):
                t = 2 * pi * j / n
                # A continuous fabric fold rises from the compressed seat to the throat.
                skew = 1 + flute * (
                    0.60 * cos(7 * t + phase + 0.9 * z) + 0.4 * sin(5 * t - phase - 1.2 * z)
                )
                vs.append(
                    (c[0] + dx + rx * skew * cos(t), c[1] + dy + ry * skew * sin(t), c[2] + z)
                )
        fs.append(tuple(reversed(range(n))))
        for k in range(len(profile) - 1):
            for j in range(n):
                fs.append(
                    (k * n + j, k * n + (j + 1) % n, (k + 1) * n + (j + 1) % n, (k + 1) * n + j)
                )
        fs.append(tuple(range(len(vs) - n, len(vs))))
        obj = mesh(label, vs, fs, m)
        return obj

    def ribbon(label, points, radius, m):
        data = bpy.data.curves.new(label, "CURVE")
        data.dimensions = "3D"
        data.bevel_depth = radius
        data.bevel_resolution = 1
        spl = data.splines.new("POLY")
        spl.points.add(len(points) - 1)
        for pt, co in zip(spl.points, points):
            pt.co = (*co, 1)
        ob = bpy.data.objects.new(label, data)
        bpy.context.collection.objects.link(ob)
        data.materials.append(m)

    wagon_sacks = []

    def sack(c, scale, m, phase):
        silhouette = [
            (0, 0.66, 0),
            (0.07, 0.94, 0),
            (0.27, 1, 0),
            (0.52, 0.91, 0.05),
            (0.72, 0.55, 0.11),
            (0.79, 0.18, 0.16),
            (0.84, 0.16, 0.16),
            (0.92, 0.27, 0.13),
        ]
        profile = [
            (h * scale, r * 0.46 * scale, r * 0.37 * scale, d * scale, 0) for h, r, d in silhouette
        ]
        obj = turned("Gathered grain sack", c, profile, m, 32, 0.105, phase)
        if c[2] > 1:
            wagon_sacks.append(obj)
        if STAGE >= 8:
            # Seam follows actual fabric profile; knot tails hang from the collar.
            j = 24
            seam = [
                obj.data.vertices[i * 32 + j].co + Vector((0, -0.006, 0))
                for i in range(len(profile) - 1)
            ]
            ribbon("Linen sack hem", seam, 0.009, rope)
            knot = Vector((c[0] + 0.16 * scale, c[1] - 0.075 * scale, c[2] + 0.81 * scale))
            ribbon(
                "Hemp knot tail",
                [knot, knot + Vector((0.03, -0.025, -0.04)), knot + Vector((0.085, -0.095, -0.14))],
                0.012,
                rope,
            )
        for face in obj.data.polygons:
            face.use_smooth = True
        if STAGE >= 7:
            p = [
                (
                    c[0] + scale * (0.16 + 0.085 * cos(t * pi / 12)),
                    c[1] + scale * 0.068 * sin(t * pi / 12),
                    c[2] + scale * (0.797 + 0.018 * t / 24),
                )
                for t in range(49)
            ]
            ribbon("Twice-wound sack tie", p, 0.011, rope)

    def barrel(c, h, r):
        outline = [
            (0, 0.83),
            (0.035, 0.86),
            (0.23, 0.95),
            (0.5, 1),
            (0.77, 0.95),
            (0.965, 0.86),
            (1, 0.83),
        ]
        turned(
            "Coopered barrel", c, [(z * h, a * r, a * r, 0, 0) for z, a in outline], alternate, 20
        )
        for h0, a in ((0.10, 0.90), (0.30, 0.978), (0.70, 0.978), (0.90, 0.90)):
            turned(
                "Barrel iron hoop",
                c,
                [
                    (h * h0 - 0.022, a * r + 0.012, a * r + 0.012, 0, 0),
                    (h * h0 + 0.022, a * r + 0.013, a * r + 0.013, 0, 0),
                ],
                iron,
                20,
            )
        if STAGE >= 7:
            for j in range(20):
                t = j * pi / 10
                ribbon(
                    "Stave joint",
                    [
                        (
                            c[0] + (a * r + 0.001) * cos(t),
                            c[1] + (a * r + 0.001) * sin(t),
                            c[2] + h * z,
                        )
                        for z, a in outline
                    ],
                    0.006,
                    darkwood,
                )
            for j in (-0.55, -0.18, 0.21, 0.58):
                a = r * math.sqrt(0.83**2 - j * j)
                ribbon(
                    "Barrel head seam",
                    [
                        (c[0] + j * r, c[1] - a, c[2] + h + 0.002),
                        (c[0] + j * r, c[1] + a, c[2] + h + 0.002),
                    ],
                    0.006,
                    darkwood,
                )

    def jar(c, h, r, m):
        outline = [
            (0, 0.57),
            (0.05, 0.66),
            (0.24, 0.9),
            (0.49, 1),
            (0.64, 0.94),
            (0.8, 0.58),
            (0.83, 0.39),
            (0.93, 0.37),
            (0.95, 0.45),
            (1, 0.45),
            (1, 0.34),
            (0.91, 0.32),
            (0.84, 0.30),
        ]
        obj = turned(
            "Open storage jar", c, [(z * h, a * r, a * r, 0, 0) for z, a in outline], m, 28
        )
        obj.data.materials.append(inside)
        obj.data.polygons[-1].material_index = len(obj.data.materials) - 1
        for f in obj.data.polygons:
            f.use_smooth = True

    # Axle, floor joists, tenoned shafts and wheel blocks bear the load.
    bar("Cross axle", (-1.08, 0, 0.83), (1.08, 0, 0.83), 0.19, darkwood)
    for s in (-1, 1):
        x = s * 0.93
        ring("Ash wheel felloe", x, 0.804, 0.136, 0.095, alternate)
        ring("Iron wheel tire", x, 0.83, 0.151, 0.035, iron)
        ring("Turned hub", x, 0.169, 0.32, 0.166, darkwood)
        spokes = 8 if STAGE == 3 else 10
        for j in range(spokes):
            t = j * 2 * pi / spokes
            bar(
                "Radial oak spoke",
                (x, 0, 0.83),
                (x, 0.735 * cos(t), 0.83 + 0.735 * sin(t)),
                0.075,
                alternate,
            )
        if STAGE >= 7:
            ring("Axle end cap", x + s * 0.165, 0.106, 0.03, 0.104, iron)
        end = 2.44 if STAGE >= 8 else 2.95
        z = 1.02 - 0.46 * (end + 1.52) / 4.47
        bar("Continuous shaft", (s * 0.52, -1.52, 1.02), (s * 0.52, end, z), 0.145, darkwood)
        if STAGE >= 8:
            verts = []
            faces = []
            for y, r in [(2.44, 0.078), (2.57, 0.069), (2.86, 0.057), (2.95, 0.06)]:
                for j in range(8):
                    t = 2 * pi * j / 8 + pi / 8
                    verts.append(
                        world(
                            (s * 0.52 + r * cos(t), y, 1.02 - 0.46 * (y + 1.52) / 4.47 + r * sin(t))
                        )
                    )
            for k in range(3):
                for j in range(8):
                    faces.append(
                        (8 * k + j, 8 * k + (j + 1) % 8, 8 * k + (j + 1) % 8 + 8, 8 * k + j + 8)
                    )
            faces.append(tuple(range(24, 32)))
            handle = mesh("Hand-worn tapered grip", verts, faces, alternate)
            handle.data.materials.append(polished)
            for f in handle.data.polygons[8:24]:
                if f.index % 8 in (0, 1, 2, 3, 7):
                    f.material_index = 1
        bar("Parking trestle", (s * 0.53, 1.15, 0.85), (s * 0.59, 1.27, 0.07), 0.115, wood)
        plank("Trestle foot", (s * 0.59, 1.27, 0.075), (0.19, 0.25, 0.15), wood)
    if STAGE >= 8:
        bar(
            "Transverse parking stand brace",
            (-0.57, 1.24, 0.25),
            (0.57, 1.24, 0.25),
            0.077,
            darkwood,
        )
    for track in (-0.58, 0.58):
        bar("Wheel chock", (-1.07, track, 0.10), (-0.79, track, 0.10), 0.20, wood)
    for y in (-1.25, 0.02, 1.06):
        plank("Wagon floor bearer", (0, y, 1.08), (1.58, 0.16, 0.17), darkwood)
    boards = 3 if STAGE == 3 else 7
    board_width = 1.465 / boards
    for j in range(boards):
        plank(
            "Bed floorboard",
            ((j - (boards - 1) / 2) * board_width, -0.10, 1.205),
            (board_width - 0.007, 2.78, 0.105),
            wood if j % 3 else alternate,
        )
    for s in (-1, 1):
        for j in range(3):
            plank(
                "Wagon sideboard",
                (s * 0.755, -0.12, 1.34 + j * 0.18),
                (0.085, 2.84, 0.163),
                alternate if j == 1 else wood,
            )
        for y in (-1.39, -0.28, 1.14):
            plank("Side stake", (s * 0.817, y, 1.46), (0.102, 0.11, 0.79), darkwood)
            if STAGE >= 7:
                for z in (1.34, 1.69):
                    plank("Stake rivet", (s * 0.873, y, z), (0.018, 0.047, 0.047), iron)
    for y, rows in ((-1.52, 3), (1.27, 2)):
        for j in range(rows):
            plank("Wagon end board", (0, y, 1.34 + j * 0.18), (1.49, 0.089, 0.163), alternate)
    for p, sc, m, f in (
        ((-0.26, -0.91, 1.26), 0.95, linen, 0.6),
        ((0.28, -0.37, 1.26), 1.05, olive, 0.2),
        ((-0.28, 0.15, 1.26), 1.07, linen, 0.8),
        ((0.2, 0.69, 1.26), 0.85, linen, 0.3),
    ):
        sack(world(p), sc, m, f)
    if STAGE >= 8:
        from mathutils.bvhtree import BVHTree

        trees = [
            BVHTree.FromPolygons(
                [v.co for v in ob.data.vertices], [list(f.vertices) for f in ob.data.polygons]
            )
            for ob in wagon_sacks
        ]
        for y in (-0.88, 0.2):
            points = [(-0.83, 1.75)]
            for j in range(73):
                x = -0.73 + j * 1.46 / 72
                hits = [tree.ray_cast(world((x, y, 3.1)), Vector((0, 0, -1)))[0] for tree in trees]
                z = max([1.65] + [hit.z + 0.014 for hit in hits if hit is not None])
                points.append((x, z))
            points.append((0.83, 1.75))
            envelope = []
            for pt in points:
                while len(envelope) > 1:
                    a, b = envelope[-2:]
                    if (b[1] - a[1]) * (pt[0] - b[0]) > (pt[1] - b[1]) * (b[0] - a[0]):
                        break
                    envelope.pop()
                envelope.append(pt)
            route = [(-0.85, 1.37)] + envelope + [(0.85, 1.37)]
            ribbon("Taut load rope", [world((x, y, z)) for x, z in route], 0.017, rope)
    elif STAGE >= 7:
        for y in (-0.88, 0.2):
            ribbon(
                "Cargo lash over sacks",
                [
                    world(p)
                    for p in (
                        (-0.83, y, 1.24),
                        (-0.84, y, 1.77),
                        (-0.44, y, 1.99),
                        (-0.21, y, 2.10),
                        (0.12, y, 2.12),
                        (0.43, y, 2.03),
                        (0.82, y, 1.78),
                        (0.83, y, 1.26),
                    )
                ],
                0.019,
                rope,
            )

    def crate(c, d, yaw):
        rot = Matrix.Rotation(yaw, 3, "Z")

        def block(label, p, size, m):
            obj = box(label, Vector(c) + rot @ Vector(p), size, m)
            obj.rotation_euler.z = yaw

        w, l, h = d
        if STAGE >= 8:
            block("Crate base", (0, 0, 0.035), (w - 0.04, l - 0.04, 0.07), wood)
        for j in range(4):
            z = (j + 0.5) * h / 4
            for side in (-1, 1):
                block(
                    "Deal crate slat",
                    (0, side * (l / 2 - 0.035), z),
                    (w, 0.072, h / 4 - 0.009),
                    (grey if STAGE >= 8 and c[2] < 0.1 else alternate) if j in (1, 2) else wood,
                )
                block(
                    "Crate end slat",
                    (side * (w / 2 - 0.035), 0, z),
                    (0.071, l - 0.14, h / 4 - 0.009),
                    wood,
                )
        for j in range(5):
            block("Crate lid plank", ((j - 2) * w / 5, 0, h), (w / 5 - 0.008, l, 0.06), alternate)
        for s in (-1, 1):
            for a in (-1, 1):
                block(
                    "Crate corner cleat",
                    (s * (w / 2 - 0.075), a * l / 2, h / 2),
                    (0.125, 0.095, h),
                    endgrain,
                )
            block(
                "Crate top batten",
                (s * (w / 2 - 0.075), 0, h + 0.047),
                (0.125, l + 0.08, 0.055),
                endgrain,
            )
        if STAGE >= 8 and c[2] > 0.5:
            # Splintered near-facing top corner, with exposed short end grain.
            x = -w / 2 + 0.076
            yf = -l / 2 - 0.049
            verts = [
                (x - 0.061, yf, h - 0.006),
                (x + 0.064, yf, h - 0.006),
                (x + 0.022, yf, h - 0.089),
                (x + 0.003, yf, h - 0.074),
                (x - 0.036, yf, h - 0.152),
                (x - 0.046, yf, h - 0.066),
            ]
            mesh(
                "Pale chipped arris",
                [Vector(c) + rot @ Vector(v) for v in verts],
                [(0, 1, 2, 3, 4, 5)],
                chipped,
            )
            for dx, depth in [(-0.025, 0.085), (0.021, 0.058)]:
                verts = [
                    (x + dx, yf - 0.001, h - 0.045),
                    (x + dx + 0.008, yf - 0.001, h - 0.043),
                    (x + dx - 0.011, yf - 0.001, h - depth),
                ]
                mesh(
                    "Exposed fissure",
                    [Vector(c) + rot @ Vector(v) for v in verts],
                    [(0, 1, 2)],
                    darkwood,
                )
        if STAGE >= 7:
            beam(
                "Diagonal crate batten",
                Vector(c) + rot @ Vector((-w * 0.41, -l / 2 - 0.048, h * 0.14)),
                Vector(c) + rot @ Vector((w * 0.41, -l / 2 - 0.048, h * 0.86)),
                0.08,
                alternate,
            )

    crate((7.55, -7.7, 0), (1.55, 1.01, 0.91), -0.14)
    if STAGE >= 8:
        for rx in (-0.38, 0.38):
            center = Vector((7.55, -7.7, 0.9625)) + Matrix.Rotation(-0.14, 3, "Z") @ Vector(
                (rx, 0, 0)
            )
            sill = box("Packing dunnage", center, (0.12, 0.84, 0.045), wood)
            sill.rotation_euler.z = -0.14
    crate((7.67, -7.64, 0.985 if STAGE >= 8 else 0.99), (1.15, 0.82, 0.70), 0.08)
    barrel((6.40, -7.23, 0), 1.35, 0.52)
    barrel((8.47, -6.83, 0), 1.15, 0.47)
    sack((6.77, -8.13, 0), 0.94, olive, 0.8)
    sack((7.75, -8.58, 0), 0.84, linen, 0.4)
    jar((-6.92, -8.36, 0), 0.88, 0.39, ceramic)
    jar((-7.48, -8.02, 0), 1.10, 0.44, glaze)
    sack((-7.86, -7.93, 0), 0.78, linen, 0.3)


make_market_cargo()
