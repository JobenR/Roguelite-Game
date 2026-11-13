# Inkbound (working title)

Top-down roguelite horde-survival shooter. Godot 4.4, GDScript, 2D only.
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
2. Ink: ink grid, kill splats, footsteps, enemy trails, loops, pulse, secondary weapon, ownership percent.
3. Progression: waves, XP gems, level-up cards, about 14 upgrades with synergies, pause.
4. Horde: Runner, Brute, Corruptor, mini-boss, spawn director tuning.
5. Burning Page mode: shrink, dead ground, flow field, strip payouts.
6. Mobile: touch polish, iOS export, performance pass (60fps with 300+ enemies).
7. Meta: currency, unlocks, JSON save, menus, audio, haptics.

Commit after each milestone and tell the user exactly what to test and report.

## Layout

- `data/` JSON content: enemies, weapons, player, modes, waves. Loaded by `DataDB`.
- `autoload/` `Events` (signal bus), `DataDB`, `GameState` (run state).
- `core/` engine-agnostic helpers: `SpatialGrid`, `ObjectPool`.
- `entities/` one folder per entity: state script + scene. `entities/visuals/` holds visual components.
- `systems/` managers that own and update entities: `EnemyManager`, `BulletManager`, `SpawnDirector`.
- `ui/` HUD, touch controls, run summary, debug overlay, safe area.
- `modes/` one root scene per game mode; the root script wires systems together.
- `tools/` headless scripts: `setup_input_map.gd`, `smoke_test.gd`.

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

## Checking work

```bash
godot --headless --path . --import
godot --headless --path . --fixed-fps 60 --script res://tools/smoke_test.gd
```

The smoke test must print frame lines with no script errors.
