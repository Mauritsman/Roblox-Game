#!/usr/bin/env python3
"""Convert a Roblox level dump (level.json + mesh*.json) to a single .glb for a Blender preview.

Roblox and glTF are both right-handed with +Y up, so world coordinates map 1:1 (1 stud = 1 unit).
Usage: python3 -I to_gltf.py <data_dir> <out.glb>
"""
import glob
import json
import math
import os
import struct
import sys

DATA, OUT = sys.argv[1], sys.argv[2]

level = json.load(open(os.path.join(DATA, "level.json")))
meshes = {}
for path in glob.glob(os.path.join(DATA, "mesh*.json")):
    m = json.load(open(path))
    meshes[m["id"]] = m


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lin(rgb):
    return tuple(srgb_to_linear(c) for c in rgb)


def xform(cf, p):
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf
    px, py, pz = p
    return (
        x + r00 * px + r01 * py + r02 * pz,
        y + r10 * px + r11 * py + r12 * pz,
        z + r20 * px + r21 * py + r22 * pz,
    )


def box_tris(s):
    hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
    c = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz), (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]
    quads = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (3, 7, 6, 2), (0, 4, 7, 3), (1, 2, 6, 5)]
    tris = []
    for a, b, cc, d in quads:
        tris.append((c[a], c[b], c[cc]))
        tris.append((c[a], c[cc], c[d]))
    return tris


def wedge_tris(s):
    hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
    # bottom: 4 corners; top edge at back (+z)
    b0, b1, b2, b3 = (-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz)
    t2, t3 = (hx, hy, hz), (-hx, hy, hz)
    return [
        (b0, b2, b1), (b0, b3, b2),  # bottom
        (b3, t2, b2), (b3, t3, t2),  # back
        (b0, b1, t2), (b0, t2, t3),  # slope
        (b0, t3, b3),  # left
        (b1, b2, t2),  # right
    ]


def cyl_tris(s, seg=16):
    # axis along local X
    h = s[0] / 2
    r = min(s[1], s[2]) / 2
    tris = []
    for i in range(seg):
        a0 = 2 * math.pi * i / seg
        a1 = 2 * math.pi * (i + 1) / seg
        p0 = (math.cos(a0) * r, math.sin(a0) * r)
        p1 = (math.cos(a1) * r, math.sin(a1) * r)
        l0, l1 = (-h, p0[0], p0[1]), (-h, p1[0], p1[1])
        r0, r1 = (h, p0[0], p0[1]), (h, p1[0], p1[1])
        tris.append((l0, r0, r1))
        tris.append((l0, r1, l1))
        tris.append(((-h, 0, 0), l1, l0))
        tris.append(((h, 0, 0), r0, r1))
    return tris


def ball_tris(s, seg=12, rings=8):
    r = min(s) / 2
    tris = []
    for j in range(rings):
        t0 = math.pi * j / rings
        t1 = math.pi * (j + 1) / rings
        for i in range(seg):
            p0 = 2 * math.pi * i / seg
            p1 = 2 * math.pi * (i + 1) / seg

            def pt(t, p):
                return (r * math.sin(t) * math.cos(p), r * math.cos(t), r * math.sin(t) * math.sin(p))

            a, b, c, d = pt(t0, p0), pt(t0, p1), pt(t1, p1), pt(t1, p0)
            tris.append((a, c, b))
            tris.append((a, d, c))
    return tris


# Material groups: key -> dict(positions, normals, colors)
groups = {}


def group(key):
    if key not in groups:
        groups[key] = {"pos": [], "nrm": [], "col": []}
    return groups[key]


def add_tri(g, a, b, c, col):
    ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
    nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    ln = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
    n = (nx / ln, ny / ln, nz / ln)
    for i, p in enumerate((a, b, c)):
        g["pos"].extend(p)
        g["nrm"].extend(n)
        cc = col[i] if isinstance(col, list) else col
        g["col"].extend((cc[0], cc[1], cc[2], 1.0))


ROUGH = {
    "Glass": "glass",
    "Neon": "neon",
    "Foil": "metal",
    "Metal": "metal",
    "DiamondPlate": "metal",
    "CorrodedMetal": "metal",
}

for p in level["parts"]:
    kind, s, cf = p["k"], p["s"], p["cf"]
    rgb = hex_rgb(p["c"])
    mat = p["m"]
    t = p["t"]
    if mat == "Neon":
        key = "neon:" + p["c"]
    elif t > 0.05 or mat == "Glass":
        key = "alpha:%.2f" % max(t, 0.3)
    else:
        key = ROUGH.get(mat, "matte")
    g = group(key)
    col = lin(rgb)
    if kind == "mesh":
        m = meshes.get(p["id"])
        if not m:
            tris = box_tris(s)
            for a, b, c in tris:
                add_tri(g, xform(cf, a), xform(cf, b), xform(cf, c), col)
            continue
        msize = m["size"]
        sx, sy, sz = (s[0] / msize[0], s[1] / msize[1], s[2] / msize[2])
        v, f, cols = m["v"], m["f"], m["col"]
        gm = group("matte")
        for ti in range(0, len(f), 3):
            pts = []
            for k in range(3):
                vi = f[ti + k]
                local = (v[vi * 3] * sx, v[vi * 3 + 1] * sy, v[vi * 3 + 2] * sz)
                pts.append(xform(cf, local))
            if cols:
                cc = [lin(hex_rgb(cols[ti + k])) for k in range(3)]
            else:
                cc = col
            add_tri(gm, pts[0], pts[1], pts[2], cc)
        continue
    if kind == "Cylinder":
        tris = cyl_tris(s)
    elif kind == "Ball":
        tris = ball_tris(s)
    elif kind == "Wedge":
        tris = wedge_tris(s)
    else:
        tris = box_tris(s)
    for a, b, c in tris:
        add_tri(g, xform(cf, a), xform(cf, b), xform(cf, c), col)

# Canal water plane (Terrain water: x -72..-54, surface y -3).
gw = group("water")
for a, b, c in box_tris((18, 0.2, 260)):
    off = lambda q: (q[0] - 63, q[1] - 3.1, q[2])
    add_tri(gw, off(a), off(b), off(c), lin(hex_rgb("1c363e")))

# ---- write glb ----
bin_chunks = bytearray()
accessors, buffer_views, meshes_out, materials, nodes = [], [], [], [], []


def add_view(data, target=34962):
    while len(bin_chunks) % 4:
        bin_chunks.append(0)
    off = len(bin_chunks)
    bin_chunks.extend(data)
    buffer_views.append({"buffer": 0, "byteOffset": off, "byteLength": len(data), "target": target})
    return len(buffer_views) - 1


def add_accessor(values, ncomp, typ):
    data = struct.pack("<%df" % len(values), *values)
    view = add_view(data)
    acc = {"bufferView": view, "componentType": 5126, "count": len(values) // ncomp, "type": typ}
    if typ == "VEC3":
        xs, ys, zs = values[0::3], values[1::3], values[2::3]
        acc["min"] = [min(xs), min(ys), min(zs)]
        acc["max"] = [max(xs), max(ys), max(zs)]
    accessors.append(acc)
    return len(accessors) - 1


def material_for(key):
    m = {"name": key, "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0, "roughnessFactor": 0.85}}
    if key.startswith("neon:"):
        rgb = lin(hex_rgb(key[5:]))
        m["pbrMetallicRoughness"]["baseColorFactor"] = [*rgb, 1]
        m["emissiveFactor"] = list(rgb)
        m["extensions"] = {"KHR_materials_emissive_strength": {"emissiveStrength": 4.0}}
    elif key.startswith("alpha:"):
        a = 1 - float(key[6:])
        m["pbrMetallicRoughness"]["baseColorFactor"] = [1, 1, 1, a]
        m["pbrMetallicRoughness"]["roughnessFactor"] = 0.1
        m["alphaMode"] = "BLEND"
    elif key == "metal":
        m["pbrMetallicRoughness"]["metallicFactor"] = 0.6
        m["pbrMetallicRoughness"]["roughnessFactor"] = 0.45
    elif key == "water":
        m["pbrMetallicRoughness"]["roughnessFactor"] = 0.05
    return m


for key, g in groups.items():
    if not g["pos"]:
        continue
    pa = add_accessor(g["pos"], 3, "VEC3")
    na = add_accessor(g["nrm"], 3, "VEC3")
    ca = add_accessor(g["col"], 4, "VEC4")
    materials.append(material_for(key))
    meshes_out.append({"name": key, "primitives": [{"attributes": {"POSITION": pa, "NORMAL": na, "COLOR_0": ca}, "material": len(materials) - 1}]})
    nodes.append({"name": key, "mesh": len(meshes_out) - 1})

# Lights (KHR_lights_punctual); intensities get tuned in Blender.
lights_out = []
for L in level["lights"]:
    if not L.get("on", True):
        continue
    rgb = lin(hex_rgb(L["c"]))
    entry = {"color": list(rgb), "intensity": L["b"] * L["range"] ** 2 * 0.6, "range": L["range"]}
    node = {"name": "%s_%d" % (L["type"], len(lights_out)), "translation": L["p"]}
    if L["type"] == "PointLight":
        entry["type"] = "point"
    else:
        entry["type"] = "spot"
        ang = math.radians(min(L.get("angle") or 90, 170) / 2)
        entry["spot"] = {"innerConeAngle": ang * 0.6, "outerConeAngle": ang}
        d = L["dir"]
        # glTF spot points down local -Z: build quaternion rotating (0,0,-1) to d
        fx, fy, fz = 0.0, 0.0, -1.0
        cx, cy, cz = fy * d[2] - fz * d[1], fz * d[0] - fx * d[2], fx * d[1] - fy * d[0]
        dot = fx * d[0] + fy * d[1] + fz * d[2]
        w = 1 + dot
        if w < 1e-6:
            q = [1.0, 0.0, 0.0, 0.0]
        else:
            ln = math.sqrt(cx * cx + cy * cy + cz * cz + w * w)
            q = [cx / ln, cy / ln, cz / ln, w / ln]
        node["rotation"] = q
        # surface lights shine a bit outside the glass
        node["translation"] = [L["p"][i] + d[i] * 0.4 for i in range(3)]
    lights_out.append(entry)
    node["extensions"] = {"KHR_lights_punctual": {"light": len(lights_out) - 1}}
    nodes.append(node)

gltf = {
    "asset": {"version": "2.0", "generator": "crowbar-crew-preview"},
    "extensionsUsed": ["KHR_lights_punctual", "KHR_materials_emissive_strength"],
    "extensions": {"KHR_lights_punctual": {"lights": lights_out}},
    "scene": 0,
    "scenes": [{"nodes": list(range(len(nodes)))}],
    "nodes": nodes,
    "meshes": meshes_out,
    "materials": materials,
    "accessors": accessors,
    "bufferViews": buffer_views,
    "buffers": [{"byteLength": len(bin_chunks)}],
}
js = json.dumps(gltf, separators=(",", ":")).encode()
while len(js) % 4:
    js += b" "
while len(bin_chunks) % 4:
    bin_chunks.append(0)
total = 12 + 8 + len(js) + 8 + len(bin_chunks)
with open(OUT, "wb") as f:
    f.write(struct.pack("<III", 0x46546C67, 2, total))
    f.write(struct.pack("<II", len(js), 0x4E4F534A))
    f.write(js)
    f.write(struct.pack("<II", len(bin_chunks), 0x004E4942))
    f.write(bin_chunks)
tri_count = sum(len(g["pos"]) // 9 for g in groups.values())
print("wrote", OUT, "groups", len(groups), "triangles", tri_count, "lights", len(lights_out), "bytes", total)
