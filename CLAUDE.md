# Inkbound (working title)

Top-down roguelite horde-survival shooter. Godot 4.7 (the user runs 4.7.2), GDScript,
2D only. Compatibility renderer (OpenGL), the most widely supported one for 2D.
Primary target: iPhone landscape. Secondary: PC (Windows/Mac).

## The game

You are a drop of living ink on a blank page; the horde is a grey smudge.

- Kills splat your ink on the ground, sized by enemy. You also leave a thin trail.
- Every enemy leaves a smudge trail that overwrites ink. Corruptor enemies smudge large areas.
- A charged pulse fills any shape fully enclosed by your ink inside its radius.
  A loop cut by an enemy trail does not fill.
- Own-ink gives a small base speed bonus; upgrade cards add the real ground effects.
- Controls: left stick moves. Right thumb: hold FIRE for the main weapon and drag
  it to aim (it is a fire-stick). With no aim input, shots go the way you move.
  Auto-aim is NOT default: it is a temporary power from a pickup. Also a
  secondary weapon (ink bomb) that recharges over time and from kills, and the
  pulse, charged by XP and kills.
- PC keys: WASD move, arrow keys aim, Space fire, E bomb, Q pulse, Esc pause.
- Modes: Survival (bounded arena about 3x3 screens, endless) and Burning Page
  (arena shrinks; your swallowed ink stays walkable and locked in, everything
  else swallowed is impassable for everyone; each swallowed strip pays out by
  the share you owned).

## Milestones

1. Foundation: movement, auto-aim, hold-to-fire, Walker, health, death/restart, debug overlay, arena, camera. (done)
2. Ink: ink grid, kill splats, footsteps, enemy trails, loops, pulse, ink bomb secondary, ownership percent. (done)
3. Progression: wave timeline, XP gems, level-up cards, 15 upgrades, 4 synergies, pause. (done)
   Feedback pass after 3 (done): thin trail on an 8px ink grid, directional splats,
   manual aim with Auto-Aim pickup, illustrated cards, outlined enemies with eyes,
   wave warnings, more sensitive stick, Twin Nib/Scatter/Ink Jet/Orbiting Blots.
   `docs/powerup_ideas.md` lists 100 candidates awaiting the user's approval.
4. Horde: Runner, Brute, Corruptor, mini-boss, spawn director tuning.
5. Burning Page mode: shrink, dead ground, flow field, strip payouts.
6. Mobile: touch polish, iOS export, performance pass (60fps with 300+ enemies).
7. Meta: currency, unlocks, JSON save, menus, audio, haptics.

Commit after each milestone and tell the user exactly what to test and report.

## Layout

- `data/` JSON content: enemies, weapons, player, modes, waves, pulses, upgrades,
  progression, pickups. Loaded by `DataDB`.
- `autoload/` `Events` (signal bus), `DataDB`, `GameState` (run clock, XP, level),
  `Upgrades` (run-scoped stat modifiers).
- `core/` engine-agnostic helpers: `SpatialGrid`, `ObjectPool`, `InkGrid`.
- `entities/` one folder per entity: state script + scene. `entities/visuals/` holds visual components.
- `systems/` managers that own and update entities: `EnemyManager`, `BulletManager`, `SpawnDirector`,
  `InkSystem`, `PulseSystem`, `SecondarySystem`, `AuxWeapons` (laser, orbit),
  `PickupManager` (temporary powers), `GemManager`, `Effects`.
- `ui/` HUD, touch controls, level-up cards, pause menu, run summary, debug overlay, safe area.
- `modes/` one root scene per game mode; the root script wires systems together.
- `tools/` headless scripts: `setup_input_map.gd`, `smoke_test.gd`, `ink_test.gd`,
  `restart_test.gd`.

## Conventions

- **Input:** gameplay reads InputMap actions only, and polls them
  (`Input.is_action_pressed`, `is_action_just_pressed`, `get_vector`). Never read
  actions from `_input` events: the touch UI feeds actions with
  `Input.action_press()`, which generates no events. Raw touch events are allowed
  only in `ui/touch/`.
- **Actions:** `move_left/right/up/down`, `aim_left/right/up/down`, `fire`, `secondary`, `pulse`, `pause`,
  `restart`, `debug_toggle` (F3), `debug_spawn` (F2). Defined in `project.godot`;
  regenerate with `tools/setup_input_map.gd`.
- **Performance:** no physics bodies and no per-entity `_process` for enemies,
  bullets, or gems. Entities are pooled nodes holding state; one manager loop
  updates them. Collisions are circle checks through `SpatialGrid`.
- **Visuals:** each entity has a `Visual` child implementing `setup(data, radius)`
  and `flash()`. Gameplay calls only those two methods, so a sprite scene can
  replace `ShapeVisual` without gameplay changes.
- **Data:** balance numbers and content live in `data/*.json`, never in scripts.
  Read with `.get(key, default)` and cast (`float()`, `int()`, `String()`).
- **Cross-system communication:** signals on `Events`. Direct references are
  injected by the mode root script through `setup()` methods.
- **Typing:** static types everywhere; no `:=` on untyped Variant values.
- **Display:** 1280x720 base, `canvas_items` stretch, `expand` aspect. All UI sits
  under `UI/SafeArea`, which applies iOS safe-area margins.
- **Export note:** JSON files are not Godot resources. Export presets must list
  `data/*.json` under non-resource include filters.

## Upgrades and stats

- Every stat is `(base + add) * (1 + mult)`. Systems read stats on demand:
  `Upgrades.value(stat, base)`, `Upgrades.bonus(stat)` (base 0), `Upgrades.mult_of(stat)`.
- `data/upgrades.json` has `upgrades` (name, desc, max_level, effects) and
  `synergies` (requires two upgrade ids, effects). Effects are
  `{stat, add}` or `{stat, mult}`. A synergy unlocks automatically once every
  required upgrade is owned.
- An upgrade that reuses an existing stat needs no code. Stats in use:
  `fire_rate, damage, move_speed, max_hp, pickup_radius, pierce, multishot,
  scatter, laser, orbit, ricochet, explosive, explosive_size, ink_regen,
  ink_burn, trail_radius, pulse_radius, splat_size, splat_damage, ink_speed,
  pulse_heal, auto_aim_duration`.
- Each upgrade has a `category` (weapon/stat/ink: card border colour) and an
  `icon` id drawn in code by `ui/levelup/upgrade_icon.gd`. A new upgrade needs a
  new `match` branch there or it shows the default drop.
- Temporary powers live in `GameState.powers` (id -> seconds left), granted by
  pickups in `data/pickups.json`. `<id>_duration` is the stat that extends one.
- Pausing uses `get_tree().paused`. UI that must run while paused
  (level-up cards, pause menu) sets `PROCESS_MODE_ALWAYS`. Never kill enemies
  while iterating `EnemyManager.active`; collect and apply after the loop.

## Ink rules (as implemented)

- `InkGrid`: 8px cells (`ink_cell_size` in modes.json), one byte each (`NEUTRAL`, `INK`, `SMUDGE`), plus an RGBA
  buffer uploaded as one texture and drawn by `entities/ground/ink.gdshader`.
- Player footsteps paint a thin line (`trail_radius`). Kills call
  `InkSystem.splat(pos, radius, dir)`: a lumpy core plus a streak and droplets
  thrown along the direction of the killing blow.
- Enemies drop a smudge every `trail_interval` seconds. Each smudge only
  overwrites ink with probability `ink_cut_chance`; otherwise it paints around
  it. These two numbers set how fragile loops are.
- Pulse (`InkGrid.find_enclosed`): flood-fills from the open sides of the pulse's
  square reach through non-ink cells. Whatever the flood cannot reach is
  enclosed and gets filled. Consequences: a shape must fit inside the reach, any
  gap in the outline voids it, and the page edge counts as a wall. A pulse that
  finds nothing fizzles and keeps its charge.

## Checking work

```bash
godot --headless --path . --import
godot --headless --path . --script res://tools/ink_test.gd
godot --headless --path . --fixed-fps 60 --script res://tools/smoke_test.gd
godot --headless --path . --fixed-fps 60 --script res://tools/restart_test.gd
```

The ink test must print ALL PASSED; the smoke test must print frame lines with
no script errors.
