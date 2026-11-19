#!/usr/bin/env python3
"""Writes data/levels.json: the ten Reclaim levels. Edit here and re-run; it
also checks that the player and every spawner can reach each other."""
import json
from collections import deque

T = 56  # wall thickness in pixels


def rect(x, y, w, h):
    return {"rect": [x, y, w, h]}


def circle(x, y, r):
    return {"circle": [x, y, r]}


def hwall(y, x0, x1, gaps=()):
    """A horizontal wall from x0 to x1 with gaps (start, end) cut out."""
    parts, cur = [], x0
    for g0, g1 in sorted(gaps):
        if g0 > cur:
            parts.append(rect(cur, y, g0 - cur, T))
        cur = g1
    if cur < x1:
        parts.append(rect(cur, y, x1 - cur, T))
    return parts


def vwall(x, y0, y1, gaps=()):
    parts, cur = [], y0
    for g0, g1 in sorted(gaps):
        if g0 > cur:
            parts.append(rect(x, cur, T, g0 - cur))
        cur = g1
    if cur < y1:
        parts.append(rect(x, cur, T, y1 - cur))
    return parts


def box(x0, y0, x1, y1, gaps_top=(), gaps_bottom=(), gaps_left=(), gaps_right=()):
    return (hwall(y0, x0, x1, gaps_top) + hwall(y1 - T, x0, x1, gaps_bottom)
            + vwall(x0, y0 + T, y1 - T, gaps_left) + vwall(x1 - T, y0 + T, y1 - T, gaps_right))


A, B, C = (2560, 1440), (3200, 1800), (3840, 2160)
L = []


def level(name, blurb, arena, player, spawners, walls=(), seed=1, creep=7.0, win=0.9, par=300,
          intensity=1.0, offset=0.0, boss=None):
    L.append({
        "name": name, "blurb": blurb, "arena": list(arena), "player": list(player),
        "spawners": [{"pos": list(p), "hp": hp} for p, hp in spawners],
        "walls": list(walls), "enemy_start_radius": 170.0 * seed, "creep_speed": creep,
        "win_share": win, "par_seconds": par, "intensity": intensity, "time_offset": offset,
        **({"boss": boss} if boss else {}),
    })


level("Open Field", "One source of ink on open paper. Learn to scrub.", A, (400, 720),
      [((2260, 720), 420)], creep=6.0, par=300, intensity=0.7)

level("The Pillar", "A single pillar to dodge round, and two sources.", A, (300, 720),
      [((2260, 330), 460), ((2260, 1110), 460)], [circle(1280, 720, 170)], creep=6.5, par=330, intensity=0.8, offset=20)

level("Four Pillars", "Cover to fight from, and a source above and below.", A, (300, 720),
      [((1280, 170), 480), ((1280, 1270), 480)],
      [circle(800, 450, 120), circle(1760, 450, 120), circle(800, 990, 120), circle(1760, 990, 120)],
      creep=7.0, par=330, intensity=0.9, offset=45)

level("The Long Wall", "Two walls make a slow zigzag. Three sources.", A, (260, 720),
      [((2300, 300), 520), ((2300, 1150), 520), ((1560, 720), 520)],
      vwall(1100, 0, 1000) + vwall(1800, 440, 1440), creep=7.0, par=360, intensity=1.0, offset=70)

level("Crossroads", "Four rooms joined by narrow doors. The Eraser guards the middle.", B, (300, 300),
      [((2900, 260), 560), ((2900, 1540), 560), ((300, 1540), 560)],
      vwall(1572, 0, 1800, [(700, 1100)]) + hwall(872, 0, 3200, [(1300, 1700)]),
      creep=7.5, par=420, intensity=1.1, offset=100, boss={"enemy": "eraser", "at_share": 0.45})

level("Ring Road", "A walled ring with a source at its heart.", B, (400, 300),
      [((1600, 900), 640), ((2900, 300), 560), ((300, 1500), 560)],
      box(1000, 500, 2200, 1300, [(1450, 1750)], [(1450, 1750)], [(800, 1000)], [(800, 1000)]),
      creep=7.5, par=420, intensity=1.15, offset=140)

level("Corridors", "Long walls with alternating doors. Four sources.", B, (300, 900),
      [((3000, 250), 600), ((3000, 1550), 600), ((1250, 900), 600), ((1950, 900), 600)],
      vwall(800, 0, 1300) + vwall(1600, 500, 1800) + vwall(2400, 0, 1300),
      creep=8.0, par=480, intensity=1.25, offset=190)

blocks = []
for row, y in enumerate([480, 1000, 1520]):
    for x in [640 + (320 if row % 2 else 0) + 560 * i for i in range(5)]:
        blocks.append(rect(x, y, 170, 170))
level("Checkerboard", "A field of blocks. Four sources press from the edges.", C, (300, 1080),
      [((3500, 300), 640), ((3500, 1860), 640), ((1920, 190), 640), ((1920, 1970), 640)], blocks,
      creep=8.0, par=540, intensity=1.35, offset=240)

level("Fortress", "A walled fortress holds the strongest source.", C, (300, 300),
      [((1920, 1080), 760), ((3500, 300), 640), ((3500, 1860), 640), ((300, 1860), 640)],
      box(1360, 680, 2480, 1480, [(1760, 2080)], [(1760, 2080)], [(1000, 1160)], [(1000, 1160)])
      + [circle(900, 700, 110), circle(900, 1460, 110), circle(2900, 700, 110), circle(2900, 1460, 110)],
      creep=8.5, par=600, intensity=1.5, offset=290)

level("The Great Smudge", "The whole page, five sources, and the Great Eraser.", C, (300, 1080),
      [((3500, 260), 700), ((3500, 1900), 700), ((1920, 1080), 820), ((1100, 300), 640), ((1100, 1860), 640)],
      vwall(760, 0, 1500) + vwall(2900, 660, 2160) + box(1500, 760, 2340, 1400, [(1800, 2040)], [(1800, 2040)], [(900, 1260)], [(900, 1260)])
      + [circle(2400, 340, 120), circle(2400, 1820, 120), circle(1400, 1080, 100)],
      creep=9.0, par=660, intensity=1.7, offset=340, win=0.9, boss={"enemy": "great_eraser", "at_share": 0.55})


def blocked_grid(lv, size=40):
    w, h = lv["arena"]
    cols, rows = w // size, h // size
    grid = [[False] * cols for _ in range(rows)]
    for s in lv["walls"]:
        if "rect" in s:
            x, y, ww, hh = s["rect"]
            for cy in range(int(y // size), int((y + hh) // size) + 1):
                for cx in range(int(x // size), int((x + ww) // size) + 1):
                    if 0 <= cy < rows and 0 <= cx < cols:
                        grid[cy][cx] = True
        else:
            x, y, r = s["circle"]
            for cy in range(rows):
                for cx in range(cols):
                    if (cx * size + size / 2 - x) ** 2 + (cy * size + size / 2 - y) ** 2 <= (r + 20) ** 2:
                        grid[cy][cx] = True
    return grid, cols, rows, size


for n, lv in enumerate(L, 1):
    grid, cols, rows, size = blocked_grid(lv)

    def cell(p):
        return int(p[1] // size), int(p[0] // size)

    pts = [lv["player"]] + [s["pos"] for s in lv["spawners"]]
    for p in pts:
        r, c = cell(p)
        assert not grid[r][c], (n, lv["name"], "point inside a wall", p)
    seen = {cell(lv["player"])}
    q = deque(seen)
    while q:
        r, c = q.popleft()
        for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nr, nc = r + dr, c + dc
            if 0 <= nr < rows and 0 <= nc < cols and not grid[nr][nc] and (nr, nc) not in seen:
                seen.add((nr, nc))
                q.append((nr, nc))
    for p in pts:
        assert cell(p) in seen, (n, lv["name"], "unreachable", p)
    open_cells = sum(1 for r in range(rows) for c in range(cols) if not grid[r][c])
    unreachable = open_cells - len(seen)
    print(n, lv["name"], "open %.0f%%" % (100 * open_cells / (rows * cols)), "cut-off cells:", unreachable)

for i, lv in enumerate(L, 1):
    lv["id"] = i
json.dump({"levels": L}, open("data/levels.json", "w"), indent=1)
print("wrote", len(L), "levels")
