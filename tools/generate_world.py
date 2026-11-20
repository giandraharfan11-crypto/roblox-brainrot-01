#!/usr/bin/env python3
"""generate_world.py -- bake the Brainrot Dino static world into world.rbxmx.

Emits a Roblox XML model whose single root is a Folder named "DinoWorld"
containing exactly the static world that src/server/WorldBuilder.luau used
to build at runtime: zone grounds, river + bridges, ponds, volcano + lava,
edge cliffs, decorative scatter, the camp (spawn / campfire / hatch pad /
fences / signs) and the gather Nodes folder.

Layout, names, colors, sizes and scatter ranges mirror WorldBuilder.luau
and DinoData.luau (zone rects / ground colors). Scatter positions use a
seeded Python random (seed 20261120, the same seed the Luau builder used);
exact positions need not match the Luau version, the layout rules do.

Attributes note: instance attributes (NodeType / IsLava / IsCampfire) are
NOT serialized here -- AttributesSerialize is a binary blob in rbxmx.
Instead Survival.luau discovers world objects attribute-first with a
name-based fallback (BerryBush* / WoodTree* / StoneRock* / DinoNest* /
HatchPad / LavaPool / Campfire), which matches the names emitted here.

Run:  python3 tools/generate_world.py [output-path]   (default: world.rbxmx
      next to the repo root, i.e. ../world.rbxmx relative to this file)
Prints the total instance count and the file size.
"""

import os
import random
import sys
from xml.sax.saxutils import escape

SEED = 20261120

# Enum.Material token values (standard Roblox values).
MAT_PLASTIC = 512
MAT_SMOOTH_PLASTIC = 272
MAT_WOOD = 528
MAT_GRASS = 1280
MAT_ROCK = 1376
MAT_NEON = 288

# Enum.PartType token values.
SHAPE_BALL = 0
SHAPE_BLOCK = 1
SHAPE_CYLINDER = 2

IDENTITY = (1, 0, 0, 0, 1, 0, 0, 0, 1)
# Rotation of the volcano cone: Orientation (0, 0, 90) == Rz(+90 degrees).
ROT_Z90 = (0, -1, 0, 1, 0, 0, 0, 0, 1)

# DinoData.Zones: name -> (rect (minX, maxX, minZ, maxZ), ground RGB).
ZONES = {
    "Jungle": ((-500, -60, -500, -60), (70, 140, 60)),
    "Desert": ((60, 500, -500, -60), (215, 190, 130)),
    "Swamp": ((-500, -60, 60, 500), (55, 95, 55)),
    "Volcano": ((60, 500, 60, 500), (80, 70, 75)),
    "Camp": ((-60, 60, -60, 60), (120, 170, 90)),
}
WILD_ZONES = ["Jungle", "Desert", "Swamp", "Volcano"]


def fnum(v):
    """Format a number the way Roblox XML likes it (no trailing .0)."""
    f = float(v)
    if f == int(f) and abs(f) < 1e15:
        return str(int(f))
    return repr(f)


def color_uint8(rgb):
    r, g, b = rgb
    return str((int(r) << 16) | (int(g) << 8) | int(b))


class Node:
    """One Roblox instance: class, name, ordered properties, children."""

    def __init__(self, class_name, name):
        self.class_name = class_name
        self.name = name
        self.props = []  # list of raw XML strings inside <Properties>
        self.children = []
        self.props.append('<string name="Name">%s</string>' % escape(name))

    def add(self, child):
        self.children.append(child)
        return child

    def prop_bool(self, name, value):
        self.props.append(
            '<bool name="%s">%s</bool>' % (name, "true" if value else "false")
        )

    def prop_float(self, name, value):
        self.props.append('<float name="%s">%s</float>' % (name, fnum(value)))

    def prop_token(self, name, value):
        self.props.append('<token name="%s">%d</token>' % (name, int(value)))

    def prop_string(self, name, value):
        self.props.append(
            '<string name="%s">%s</string>' % (name, escape(value))
        )

    def prop_color3_float(self, name, rgb):
        r, g, b = (c / 255.0 for c in rgb)
        self.props.append(
            '<Color3 name="%s"><R>%s</R><G>%s</G><B>%s</B></Color3>'
            % (name, fnum(r), fnum(g), fnum(b))
        )

    def prop_udim2(self, name, xs, xo, ys, yo):
        self.props.append(
            '<UDim2 name="%s"><XS>%s</XS><XO>%s</XO>'
            "<YS>%s</YS><YO>%s</YO></UDim2>"
            % (name, fnum(xs), fnum(xo), fnum(ys), fnum(yo))
        )


def base_part(class_name, name, size, pos, rgb, material, collide,
              shape=None, rotation=IDENTITY, transparency=None):
    """A Part / SpawnLocation with the WorldBuilder.part() defaults:
    Anchored = true, CanCollide as given, SmoothPlastic unless overridden."""
    node = Node(class_name, name)
    node.prop_bool("Anchored", True)
    rot = rotation
    node.props.append(
        '<CoordinateFrame name="CFrame">'
        "<X>%s</X><Y>%s</Y><Z>%s</Z>"
        "<R00>%s</R00><R01>%s</R01><R02>%s</R02>"
        "<R10>%s</R10><R11>%s</R11><R12>%s</R12>"
        "<R20>%s</R20><R21>%s</R21><R22>%s</R22>"
        "</CoordinateFrame>"
        % tuple([fnum(v) for v in pos] + [fnum(v) for v in rot])
    )
    node.prop_bool("CanCollide", collide)
    node.props.append(
        '<Color3uint8 name="Color3uint8">%s</Color3uint8>' % color_uint8(rgb)
    )
    node.prop_token("Material", material)
    if shape is not None:
        node.prop_token("shape", shape)
    node.props.append(
        '<Vector3 name="size"><X>%s</X><Y>%s</Y><Z>%s</Z></Vector3>'
        % tuple(fnum(v) for v in size)
    )
    if transparency is not None:
        node.prop_float("Transparency", transparency)
    return node


def part(parent, name, size, pos, rgb, material=MAT_SMOOTH_PLASTIC,
         collide=False, **kw):
    node = base_part("Part", name, size, pos, rgb, material, collide, **kw)
    parent.add(node)
    return node


def tree(parent, pos, rng, leaf_rgb):
    height = rng.uniform(9, 14)
    x, y, z = pos
    part(parent, "Trunk", (2, height, 2), (x, y + height / 2, z),
         (110, 75, 45), MAT_WOOD, True)
    part(parent, "Leaves", (9, 7, 9), (x, y + height + 3, z),
         leaf_rgb, MAT_SMOOTH_PLASTIC, False)
    part(parent, "LeavesTop", (6, 4, 6), (x, y + height + 7, z),
         leaf_rgb, MAT_SMOOTH_PLASTIC, False)


def sign(parent, pos, text, text_rgb):
    x, y, z = pos
    part(parent, "SignPost", (1, 7, 1), (x, y + 3.5, z),
         (110, 75, 45), MAT_WOOD, False)
    board = part(parent, "SignBoard", (14, 4, 0.6), (x, y + 8, z),
                 (140, 100, 60), MAT_WOOD, False)
    gui = Node("BillboardGui", "BillboardGui")
    gui.prop_bool("AlwaysOnTop", False)
    gui.prop_float("MaxDistance", 170)
    gui.prop_udim2("Size", 20, 0, 5, 0)
    board.add(gui)
    label = Node("TextLabel", "TextLabel")
    label.prop_float("BackgroundTransparency", 1)
    label.prop_udim2("Size", 1, 0, 1, 0)
    label.prop_string("Text", text)
    label.prop_color3_float("TextColor3", text_rgb)
    label.prop_bool("TextScaled", True)
    label.prop_float("TextStrokeTransparency", 0.3)
    gui.add(label)


def build_world():
    rng = random.Random(SEED)
    world = Node("Folder", "DinoWorld")

    part(world, "GroundBase", (1012, 2, 1012), (0, -1.1, 0),
         (86, 148, 70), MAT_GRASS, True)

    # Zone grounds (top surface at Y=0).
    for zone_name in WILD_ZONES:
        rect, ground = ZONES[zone_name]
        cx = (rect[0] + rect[1]) / 2
        cz = (rect[2] + rect[3]) / 2
        part(world, "Ground_" + zone_name,
             (rect[1] - rect[0], 2, rect[3] - rect[2]), (cx, -1, cz),
             ground, MAT_GRASS, True)
    # Camp clearing on top of the middle.
    part(world, "Ground_Camp", (130, 2.4, 130), (0, -1, 0),
         ZONES["Camp"][1], MAT_GRASS, True)

    # River strip running north-south between the west and east zones.
    part(world, "River", (46, 1, 1000), (0, 0.15, 0),
         (60, 140, 220), MAT_SMOOTH_PLASTIC, False, transparency=0.25)
    # Wooden bridges over the river at camp height.
    part(world, "BridgeW", (60, 1, 14), (0, 0.6, -120),
         (140, 100, 60), MAT_WOOD, True)
    part(world, "BridgeE", (60, 1, 14), (0, 0.6, 120),
         (140, 100, 60), MAT_WOOD, True)

    # Ponds in the swamp.
    for _ in range(4):
        x = rng.uniform(-460, -120)
        z = rng.uniform(120, 460)
        sx = rng.uniform(30, 55)
        sz = rng.uniform(30, 55)
        part(world, "Pond", (sx, 1, sz), (x, 0.2, z),
             (50, 90, 70), MAT_SMOOTH_PLASTIC, False, transparency=0.2)

    # Volcano cone + lava pools (found by name "LavaPool" for damage).
    part(world, "VolcanoCone", (120, 55, 120), (330, 24, 330),
         (70, 60, 65), MAT_ROCK, True,
         shape=SHAPE_CYLINDER, rotation=ROT_Z90)
    for i in range(1, 4):
        x = 240 + i * 55
        z = 150 + (i % 2) * 90
        part(world, "LavaPool", (34, 1.2, 34), (x, 0.4, z),
             (255, 110, 20), MAT_NEON, False)
    part(world, "LavaPool", (44, 2, 44), (330, 52, 330),
         (255, 130, 25), MAT_NEON, False)

    # Edge cliffs so players stay inside the world.
    cliff = (95, 85, 80)
    part(world, "CliffN", (1040, 26, 12), (0, 11, -506), cliff, MAT_ROCK, True)
    part(world, "CliffS", (1040, 26, 12), (0, 11, 506), cliff, MAT_ROCK, True)
    part(world, "CliffW", (12, 26, 1040), (-506, 11, 0), cliff, MAT_ROCK, True)
    part(world, "CliffE", (12, 26, 1040), (506, 11, 0), cliff, MAT_ROCK, True)

    # Scatter decorative trees per zone.
    for _ in range(42):  # jungle
        pos = (rng.uniform(-480, -90), 0, rng.uniform(-480, -90))
        tree(world, pos, rng, (45, 130, 50))
    for _ in range(20):  # swamp
        pos = (rng.uniform(-480, -90), 0, rng.uniform(90, 480))
        tree(world, pos, rng, (40, 90, 45))
    for _ in range(8):  # desert cacti
        x = rng.uniform(90, 480)
        z = rng.uniform(-480, -90)
        part(world, "Cactus", (2.5, 11, 2.5), (x, 5.5, z),
             (60, 150, 70), MAT_SMOOTH_PLASTIC, True)
    for _ in range(10):  # desert bones (pairs)
        x = rng.uniform(90, 480)
        z = rng.uniform(-480, -90)
        part(world, "Bone", (10, 1.2, 1.2), (x, 0.8, z),
             (240, 235, 215), MAT_SMOOTH_PLASTIC, False)
        part(world, "Bone", (1.2, 1.2, 6), (x + 3, 0.8, z + 2),
             (240, 235, 215), MAT_SMOOTH_PLASTIC, False)
    for _ in range(12):  # volcanic rocks
        x = rng.uniform(90, 480)
        z = rng.uniform(90, 480)
        dx = x - 330
        dz = z - 330
        if (dx * dx + dz * dz) ** 0.5 > 90:
            size = (rng.uniform(4, 9), rng.uniform(3, 7), rng.uniform(4, 9))
            part(world, "Rock", size, (x, 2, z),
                 (85, 75, 80), MAT_ROCK, True)

    # ===== CAMP =====
    camp = world.add(Node("Folder", "Camp"))

    spawn = base_part("SpawnLocation", "DinoSpawn", (16, 1, 16), (0, 1.2, 0),
                      (255, 200, 80), MAT_SMOOTH_PLASTIC, True)
    spawn.prop_bool("Neutral", True)
    camp.add(spawn)
    part(camp, "CampPad", (50, 0.6, 50), (0, 0.4, 0),
         (190, 160, 110), MAT_WOOD, True)

    # Campfire: heals nearby players (found by name "Campfire").
    part(camp, "Campfire", (6, 1.5, 6), (12, 1, 10),
         (90, 60, 40), MAT_WOOD, False, shape=SHAPE_CYLINDER)
    flame = part(camp, "Flame", (3.4, 4.5, 3.4), (12, 3.5, 10),
                 (255, 140, 30), MAT_NEON, False)
    fire = Node("Fire", "Fire")
    fire.prop_float("Heat", 12)
    fire.prop_float("Size", 7)
    flame.add(fire)
    light = Node("PointLight", "PointLight")
    light.prop_float("Brightness", 2)
    light.prop_color3_float("Color", (255, 170, 80))
    light.prop_float("Range", 34)
    flame.add(light)

    # Hatch pad at camp (found by name "HatchPad").
    part(camp, "HatchPad", (10, 1, 10), (-14, 0.8, 12),
         (255, 170, 220), MAT_SMOOTH_PLASTIC, True, shape=SHAPE_CYLINDER)

    # Camp fences.
    for size, pos in (
        ((56, 3, 2), (0, 1.8, -28)),
        ((56, 3, 2), (0, 1.8, 28)),
        ((2, 3, 56), (-28, 1.8, 0)),
        ((2, 3, 56), (28, 1.8, 0)),
    ):
        part(camp, "Fence", size, pos, (130, 90, 55), MAT_WOOD, True)

    sign(camp, (0, 0, -34), "🏕️ KAMP DINO", (255, 230, 150))
    sign(world, (-90, 0, -90), "🌴 HUTAN RIMBA", (170, 255, 170))
    sign(world, (90, 0, -90), "🦴 GURUN TULANG", (255, 235, 180))
    sign(world, (-90, 0, 90), "🐸 RAWA GELAP", (170, 255, 210))
    sign(world, (90, 0, 90), "🌋 GUNUNG BERAPI — AWAS T-REX!", (255, 160, 120))

    # ===== GATHER NODES =====
    nodes = world.add(Node("Folder", "Nodes"))

    def scatter_pos(zone_name):
        rect = ZONES[zone_name][0]
        return (rng.uniform(rect[0] + 25, rect[1] - 25), 0,
                rng.uniform(rect[2] + 25, rect[3] - 25))

    def node_model(name):
        model = Node("Model", name)
        nodes.add(model)
        return model

    for i in range(1, 15):  # 14 BerryBush (NodeType Berry)
        pos = scatter_pos(WILD_ZONES[i % 4])
        m = node_model("BerryBush%d" % i)
        part(m, "Bush", (5, 3.5, 5), (pos[0], 1.7, pos[2]),
             (50, 140, 60), MAT_SMOOTH_PLASTIC, False)
        for _ in range(4):
            bp = (pos[0] + rng.uniform(-2, 2), rng.uniform(1.5, 3.4),
                  pos[2] + rng.uniform(-2, 2))
            part(m, "Berry", (0.9, 0.9, 0.9), bp,
                 (230, 60, 90), MAT_SMOOTH_PLASTIC, False, shape=SHAPE_BALL)
    for i in range(1, 15):  # 14 WoodTree (NodeType Wood)
        pos = scatter_pos(WILD_ZONES[(i + 1) % 4])
        m = node_model("WoodTree%d" % i)
        part(m, "Trunk", (2.6, 12, 2.6), (pos[0], 6, pos[2]),
             (120, 80, 45), MAT_WOOD, True)
        part(m, "Leaves", (10, 8, 10), (pos[0], 15, pos[2]),
             (60, 150, 65), MAT_SMOOTH_PLASTIC, False)
    for i in range(1, 13):  # 12 StoneRock (NodeType Stone)
        pos = scatter_pos(WILD_ZONES[(i + 2) % 4])
        m = node_model("StoneRock%d" % i)
        part(m, "Rock", (5, 3.5, 4.5), (pos[0], 1.6, pos[2]),
             (140, 140, 145), MAT_ROCK, True)
        part(m, "RockTop", (3, 2, 3), (pos[0] + 0.5, 4, pos[2]),
             (160, 160, 165), MAT_ROCK, False)
    for i in range(1, 9):  # 8 DinoNest (NodeType Nest)
        pos = scatter_pos(WILD_ZONES[(i + 3) % 4])
        m = node_model("DinoNest%d" % i)
        part(m, "Nest", (7, 1.6, 7), (pos[0], 0.8, pos[2]),
             (150, 110, 60), MAT_WOOD, False, shape=SHAPE_CYLINDER)
        for e in range(1, 4):
            ep = (pos[0] + (e - 2) * 1.8, 2.2, pos[2] + rng.uniform(-1, 1))
            part(m, "Egg", (1.6, 2, 1.6), ep,
                 (245, 240, 220), MAT_SMOOTH_PLASTIC, False, shape=SHAPE_BALL)

    return world


def render(root):
    lines = ['<roblox version="4">']
    counter = [0]

    def emit(node, depth):
        referent = counter[0]
        counter[0] += 1
        indent = "  " * depth
        lines.append('%s<Item class="%s" referent="%d">'
                     % (indent, node.class_name, referent))
        lines.append("%s  <Properties>" % indent)
        for prop in node.props:
            lines.append("%s    %s" % (indent, prop))
        lines.append("%s  </Properties>" % indent)
        for child in node.children:
            emit(child, depth + 1)
        lines.append("%s</Item>" % indent)

    emit(root, 1)
    lines.append("</roblox>")
    return "\n".join(lines) + "\n", counter[0]


def main():
    if len(sys.argv) > 1:
        out_path = sys.argv[1]
    else:
        repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        out_path = os.path.join(repo_root, "world.rbxmx")
    world = build_world()
    xml, count = render(world)
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write(xml)
    size = os.path.getsize(out_path)
    print("Wrote %s" % out_path)
    print("Total instances: %d" % count)
    print("File size: %d bytes" % size)


if __name__ == "__main__":
    main()
