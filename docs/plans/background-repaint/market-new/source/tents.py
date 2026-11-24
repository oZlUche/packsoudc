"""Canvas stores and two open-sided traders' stalls, built in metres."""


def build_market_stores():
    flax = mat("Warm flax canvas", "#c5a87a", "cloth")
    faded = mat("Sun-bleached ridge panels", "#deca9f", "cloth")
    hem = mat("Canvas binding", "#9c7952", "cloth")
    lining = mat("Tent interior shadow", "#b49d79", "cloth")
    ochre = mat("Ochre dyed linen", "#b89a61", "cloth")
    red = mat("Madder dyed linen", "#9e503e", "cloth")
    wood = mat("Unpeeled tent poles", "#806043", "wood")
    pine = mat("Stall boards", "#a47a4e", "wood")
    rope = mat("Hemp cord", "#ad9874", "cloth")
    greens = mat("Rolled army blanket", "#65745e", "cloth")
    tin = mat("Pewter cup", "#808484", "metal")
    fine = STAGE >= 7

    def shelter(label, cx, cy, angle, width, depth, height, cloth):
        # The ridge runs along the depth axis. All frame and cloth pieces
        # use the same transform, including the parted entrance curtains.
        c, s = math.cos(angle), math.sin(angle)

        def p(x, y, z):
            return (cx + c * x - s * y, cy + s * x + c * y, z)

        h, d, e = width / 2, depth / 2, 0.63

        def pole(name, a, b, size, material):
            return beam(label + " " + name, p(*a), p(*b), size, material)

        def skin(name, verts, faces, material):
            return mesh(label + " " + name, [p(*v) for v in verts], faces, material)

        def top(x, y):
            t = abs(x) / h
            longitudinal = math.cos(math.pi * y / depth)
            return (
                height
                - (height - e) * t
                - 0.10 * math.sin(math.pi * t)
                - 0.08 * longitudinal * (1 - t)
            )

        nx, ny = (6, 12) if fine else (3, 4)
        for side in (-1, 1):
            verts = []
            for j in range(ny + 1):
                y = depth * j / ny - d
                for i in range(nx + 1):
                    x = side * h * i / nx
                    ripple = 0.027 * math.sin(j * 1.85) * math.sin(math.pi * i / nx) if fine else 0
                    verts.append((x, y, top(x, y) + ripple))
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
            skin("pitched roof", verts, faces, cloth)
            skin(
                "low sidewall",
                [(side * h, -d, 0.03), (side * h, d, 0.03), (side * h, d, e), (side * h, -d, e)],
                [(0, 1, 2, 3)],
                cloth,
            )
            # The opening narrows toward the ridge and widens below a tie.
            verts = []
            for j in range(9):
                v = j / 8
                for i in range(7):
                    u = i / 6
                    outer = h
                    inner = h * (0.40 * (1 - v) + 0.22 * math.sin(math.pi * v))
                    x = side * (inner + (outer - inner) * u)
                    y = -d - 0.048 * math.cos(u * math.pi * 7 + v * 2) * (1 - 0.5 * v)
                    if STAGE >= 8:
                        y -= (
                            0.12
                            * math.sin(u * 3 * math.pi + 0.6 * v + 0.4 * side)
                            * math.sin(math.pi * v) ** 0.7
                            * (0.65 + 0.35 * (1 - u))
                        )
                    verts.append((x, y, 0.035 + v * (top(x, -d) - 0.035)))
            faces = [
                (j * 7 + i, j * 7 + i + 1, (j + 1) * 7 + i + 1, (j + 1) * 7 + i)
                for j in range(8)
                for i in range(6)
            ]
            skin("hanging door cloth", verts, faces, cloth)
            for y in (-d, d):
                pole("edge binding", (0, y, height), (side * h, y, e), 0.044, hem)
                if STAGE >= 5:
                    anchor = (side * (h + 0.55), y + (0.22 if y > 0 else -0.22), 0.08)
                    pole("guy", (side * h, y, e), anchor, 0.021, rope)
                    pole("peg", anchor, (anchor[0] + side * 0.045, anchor[1], 0.23), 0.05, wood)
            if fine:
                for y in (-d * 0.48, 0, d * 0.48):
                    for i in range(nx):
                        x0, x1 = side * h * i / nx, side * h * (i + 1) / nx
                        pole(
                            "felled seam",
                            (x0, y, top(x0, y) + 0.012),
                            (x1, y, top(x1, y) + 0.012),
                            0.012,
                            hem,
                        )
        skin(
            "rear canvas",
            [(-h, d, 0), (h, d, 0), (h, d, e), (0, d, height), (-h, d, e)],
            [(0, 1, 2, 3, 4)],
            lining,
        )
        for y in (-d + 0.11, d - 0.11):
            pole(
                "upright", (0, y, -0.006 if STAGE >= 8 else 0.02), (0, y, height + 0.08), 0.09, wood
            )
        pole("ridgepole", (0, -d - 0.11, height), (0, d + 0.11, height), 0.095, wood)
        if STAGE >= 5:
            for j in range(2):
                ctr = p(-0.55 + j * 0.57, -d + 0.55, 0.23)
                ob = box(label + " stores", ctr, (0.54, 0.62, 0.46), wood)
                ob.rotation_euler.z = angle

    shelter("West delivery tent", -10, 0, 0.22, 5.5, 4.1, 3.72, flax)
    shelter("West reserve tent", -8.0, 5.05, 0.15, 3.95, 3.3, 3.2, faded)
    shelter("East depot", 11, 2, -0.28, 5.35, 4.7, 3.65, flax)

    def stall(label, x, y, canopy):
        w, d = 3.5, 2.15

        def stick(name, a, b, r, m):
            return beam(
                label + " " + name, (x + a[0], y + a[1], a[2]), (x + b[0], y + b[1], b[2]), r, m
            )

        def board(name, xx, yy, z, dims, m):
            return box(label + " " + name, (x + xx, y + yy, z), dims, m)

        for yy, ht in ((-d / 2, 2.29), (d / 2, 2.73)):
            stick("cross rail", (-w / 2, yy, ht), (w / 2, yy, ht), 0.085, wood)
            for xx in (-w / 2, w / 2):
                stick("post", (xx, yy, 0.0), (xx, yy, ht + 0.09), 0.105, wood)
                if fine:
                    stick(
                        "knee brace", (xx, yy, ht - 0.47), (xx * 0.72, yy, ht - 0.01), 0.065, wood
                    )
        bands = 7 if STAGE >= 5 else 3
        if STAGE >= 5 and label == "Dry goods":
            # Stock sits on the shoulder, across the edge of the awning shadow.
            board("delivery case", 2.04, 0.42, 0.39, (0.99, 0.88, 0.78), pine)
            board("case lid", 2.04, 0.42, 0.805, (1.02, 0.91, 0.05), wood)
        for k in range(bands):
            a = -(w + 0.38) / 2 + (w + 0.38) * k / bands
            b = a + (w + 0.38) / bands
            verts = []
            for j in range(6):
                t = j / 5
                for xx in (a, b):
                    yy = -d / 2 - 0.19 + t * (d + 0.38)
                    z = (
                        2.30
                        + 0.44 * t
                        - 0.10 * math.sin(t * math.pi)
                        - 0.025 * math.cos(xx * math.pi / w)
                    )
                    verts.append((x + xx, y + yy, z))
            if STAGE >= 8:
                # The eave is tensioned at its posts; short radial folds die
                # into the quieter centre. Adjacent panels share their edges.
                verts = []
                faces = []
                nx, ny = 7, 15
                for j in range(ny + 1):
                    t = j / ny
                    for i in range(nx + 1):
                        xx = a + (b - a) * i / nx
                        edge = w / 2 + 0.19 - abs(xx)
                        u = math.hypot(edge, t * 2.7)
                        fold = (
                            0.073
                            * math.sin(math.atan2(t * 2.7, edge + 0.001) * 15 + 0.8)
                            * math.exp(-u * 1.8)
                            * min(1, u * 7)
                        )
                        z = (
                            2.30
                            + 0.44 * t
                            - 0.13 * math.sin(t * math.pi)
                            - 0.08 * math.cos(xx * math.pi / w)
                            + fold
                        )
                        verts.append((x + xx, y - d / 2 - 0.19 + t * (d + 0.38), z))
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
                mesh(label + " tensioned canopy", verts, faces, canopy if k % 2 == 0 else faded)
                a0, b0 = verts[0], verts[nx]
            else:
                mesh(
                    label + " canopy panel",
                    verts,
                    [(j * 2, j * 2 + 1, j * 2 + 3, j * 2 + 2) for j in range(5)],
                    canopy if k % 2 == 0 else faded,
                )
                a0, b0 = verts[:2]
            mesh(
                label + " scalloped valance",
                [
                    a0,
                    b0,
                    (b0[0], b0[1], b0[2] - 0.17),
                    ((a0[0] + b0[0]) * 0.5, a0[1], (a0[2] + b0[2]) * 0.5 - 0.21),
                    (a0[0], a0[1], a0[2] - 0.17),
                ],
                [(0, 1, 2, 3, 4)],
                canopy if k % 2 == 0 else faded,
            )
        for xx in (-1.35, 1.35):
            for yy in (-0.78, -0.10):
                board("counter leg", xx, yy, 0.43, (0.11, 0.11, 0.86), wood)
        board("counter", 0, -0.44, 0.90, (3.13, 1.01, 0.12), pine)
        if STAGE >= 5:
            board("counter backboard", 0, -0.02, 0.54, (2.85, 0.08, 0.67), wood)
        if STAGE >= 3:
            board("folded blanket", -0.86, -0.45, 1.04, (0.85, 0.61, 0.16), greens)
            board("folded cloth", -0.89, -0.45, 1.18, (0.72, 0.55, 0.12), ochre)
            for j in range(3 if fine else 2):
                xx = 0.33 + j * 0.37
                bpy.ops.mesh.primitive_cylinder_add(
                    vertices=12, radius=0.12, depth=0.24, location=(x + xx, y - 0.46, 1.08)
                )
                cup = bpy.context.object
                cup.name = label + " supply tin"
                cup.data.materials.append(tin)
            if STAGE >= 8:
                for k in range(3):
                    board(
                        "binding on parcel",
                        -1.1 + k * 0.25,
                        -0.45,
                        1.246,
                        (0.025, 0.55, 0.013),
                        rope,
                    )
                board("stretcher", 0, -0.75, 0.3, (2.7, 0.07, 0.10), wood)

    from mathutils import Matrix

    x, y = -4.1, 3.0
    before = set(bpy.context.scene.objects)
    stall("Dry goods", x, y, red)
    bpy.context.view_layer.update()
    rot = (
        Matrix.Translation((x, y, 0))
        @ Matrix.Rotation(0.34, 4, "Z")
        @ Matrix.Translation((-x, -y, 0))
    )
    for obj in set(bpy.context.scene.objects) - before:
        obj.matrix_world = rot @ obj.matrix_world
    stall("Outfitter", 7.55, 6.9, ochre)


build_market_stores()
