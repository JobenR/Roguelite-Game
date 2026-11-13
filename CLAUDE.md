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
- Controls: left stick moves. Right thumb: hold FIRE for the main weapon (auto-aim at
  nearest enemy), a secondary weapon that recharges over time and from kills, and
  the pulse, charged by XP and kills.
- Modes: Survival (bounded arena about 3x3 screens, endless) and Burning Page
  (arena shrinks; your swallowed ink stays walkable and locked in, everything
  else swallowed is impassable for everyone; each swallowed strip pays out by
  the share you owned).

## Milestones

1. Foundation: movement, auto-aim, hold-to-fire, Walker, health, death/restart, debug overlay, arena, camera. (done)
2. Ink: ink grid, kill splats, footsteps, enemy trails, loops, pulse, ink bomb secondary, ownership percent. (done)
3. Progression: wave timeline, XP gems, level-up cards, 15 upgrades, 4 synergies, pause. (done)
4. Horde: Runner, Brute, Corruptor, mini-boss, spawn director tuning.
5. Burning Page mode: shrink, dead ground, flow field, strip payouts.
6. Mobile: touch polish, iOS export, performance pass (60fps with 300+ enemies).
7. Meta: currency, unlocks, JSON save, menus, audio, haptics.

Commit after each milestone and tell the user exactly what to test and report.

## Layout

- `data/` JSON content: enemies, weapons, player, modes, waves, pulses, upgrades,
  progression. Loaded by `DataDB`.
- `autoload/` `Events` (signal bus), `DataDB`, `GameState` (run clock, XP, level),
  `Upgrades` (run-scoped stat modifiers).
- `core/` engine-agnostic helpers: `SpatialGrid`, `ObjectPool`, `InkGrid`.
- `entities/` one folder per entity: state script + scene. `entities/visuals/` holds visual components.
- `systems/` managers that own and update entities: `EnemyManager`, `BulletManager`, `SpawnDirector`,
  `InkSystem`, `PulseSystem`, `SecondarySystem`, `GemManager`, `Effects`.
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
- **Actions:** `move_left/right/up/down`, `fire`, `secondary`, `pulse`, `pause`,
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
  ricochet, explosive, explosive_size, ink_regen, ink_burn, trail_radius,
  pulse_radius, splat_size, splat_damage, ink_speed, pulse_heal`.
- Pausing uses `get_tree().paused`. UI that must run while paused
  (level-up cards, pause menu) sets `PROCESS_MODE_ALWAYS`. Never kill enemies
  while iterating `EnemyManager.active`; collect and apply after the loop.

## Ink rules (as implemented)

- `InkGrid`: 16px cells, one byte each (`NEUTRAL`, `INK`, `SMUDGE`), plus an RGBA
  buffer uploaded as one texture and drawn by `entities/ground/ink.gdshader`.
- Player footsteps paint a circle of `trail_radius`; kills paint `splat_radius`.
- Enemies drop a smudge every `trail_interval` seconds (dotted on purpose, so a
  thick ink wall survives a few crossings). Lower interval = better loop cutter.
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
