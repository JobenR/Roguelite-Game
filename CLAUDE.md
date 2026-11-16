# Blotline

Top-down roguelite horde-survival shooter. Godot 4.7 (the user runs 4.7.2), GDScript,
2D only. Compatibility renderer (OpenGL), the most widely supported one for 2D.
Primary target: iPhone landscape. Secondary: PC (Windows/Mac).

## The game

You are a drop of living ink on a blank page; the horde is a grey smudge.

**Look (chosen by the user from drawn mock-ups): Sumi-e, with glow only as a
reward.** The user picked mock-up A plus E and rejected a first attempt that
"looked like a recoloured version of the last one", so hold to this closely:

- Rice paper with fibres, a brushed black frame, a red seal. No notebook lines.
- The player's ink is luminous and coloured by the chosen ink, blue by
  default (trail, splats, shots, blasts, extra weapons); the horde is black.
  Never hard-code the ink colour: use `GameState.ink_color` and
  `GameState.ink_light`. The user tried all-black ink and asked for
  blue back. Ink has dry-brush edges, bristle streaks, and a soft bleed halo
  where it soaked into the paper. Splats throw streaks and many droplets.
- Enemies are ragged black brush shapes with a pooled shade underneath, told
  apart only by a small glowing core colour. The player is a blue drop with a
  white square seal.
- Shots are blue tapered brush flicks. Ordinary blasts (`Effects.ink_burst`)
  are blue strokes flung outward with a broken pale ring. Red is for danger
  and the UI seal.
- Glow is rare and earned (`Effects.big_moment`, and ink marked with
  `InkGrid.set_glow`): pulse-filled ground shines brighter, near white; glyphs burst gold,
  bosses burst in their core colour, Legendary cards shimmer.
- UI takes every colour, font and panel style from `ui/common/sumi.gd`
  (`Sumi`): paper panels, ink borders, seal red, Kaushan Script titles.

- Kills splat your ink on the ground, sized by enemy. You also leave a thin trail.
- Every enemy leaves a smudge trail that overwrites ink. Corruptor enemies smudge large areas.
- The third button is the Deluge, an Ultimate that charges slowly from kills
  and XP: a wave that damages and throws back everything near the player and
  floods the ground with glowing ink. (`PulseSystem`; the action is still
  named `pulse`.) It replaced the loop-filling pulse and the glyphs, which the
  user barely used under pressure. Loops, glyphs and their code are gone.
- Saved items (`ItemSystem`, the `item` action): the Lasso ropes up to 45
  enemies into a knot for six seconds; Page Wipe clears the screen. Found as
  pickups or bought in the store.
- Own-ink gives a small base speed bonus; upgrade cards add the real ground effects.
- Ink milestones: the first time the player's share reaches each threshold
  (5%, 10%, 15%...) a one-time reward is paid: heal, pulse charge, or bonus card.
- Controls: left stick moves. Right thumb: hold FIRE for the main weapon and drag
  it to aim (it is a fire-stick). With no aim input, shots go the way you move.
  Aim assist snaps to the nearest enemy inside a cone (`aim_assist_deg` in
  player.json); the last stick aim is held for `aim_hold_seconds`.
  Auto-aim is NOT default: it is a temporary power from a pickup. Also a
  secondary weapon (ink bomb) that recharges over time and from kills, and the
  pulse, charged by XP and kills.
- PC keys: WASD move, arrow keys aim, Space fire, E bomb, Q pulse, Shift dash
  (once the Dash upgrade is owned), Esc pause.
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
   `docs/powerup_ideas.md` lists 100 candidates. Built from it so far: 3, 21, 33, 38,
   45, 53, 58, 60, 71, 84, 90, 91, 99 (30 upgrade cards, 3 pickups).
   Second feedback pass (done): slower XP curve, rarer pickups, smaller per-level
   upgrade steps with more levels, comet-style shots. The user wants gradual
   power growth: keep new upgrades to small steps over many levels.
   Glyphs and ink milestones (done): the user chose free-hand glyphs and
   one-time milestone rewards. Offered but not chosen: panels, a capped peak-ink
   currency multiplier, a finish-the-page boss, stencils that teach glyphs.
4. Horde (done): Walker, Runner, Spitter, Brute, Splitter (into Mites), Corruptor,
   and The Eraser mini-boss; a new type about every 60 seconds; enemy health grows
   with a squared term. Power curve pass: faster early levels, steeper later ones,
   and selected upgrades count double at level 1.
   Power-up overhaul (done): all 100 ideas from `docs/powerup_ideas.md` are built:
   112 upgrade cards, 8 pickups, 20 pair synergies, 8 set bonuses, card rarities,
   reroll and banish. The user found the old card screen boring: card picks must
   feel exciting, with visible rarity and something each pick builds toward.
   Decided by the user, not yet built: (a) next milestone is menus, sound and
   saved progress; (b) a run is won by beating a final boss at 15 minutes, after
   which the player may continue endlessly; (c) art stays code-drawn.
   Combat and look pass (done): stackable rear shots, an enemy cap that ramps
   from 30, Spotter (aimed bomb in slow motion), Piercing Core, Bomb Rain,
   slowing mines, Wet Ink Wall, enemies that flank and weave, and the Sumi-e
   with glow restyle.
   Also done: mines are planted by standing still (not on a timer); the inks
   marble where they meet; the end screen frames the whole page as a titled
   painting with ink, smudge and bare-paper shares; the camera zooms in on touch
   devices (`camera_zoom_touch` in modes.json) because the phone view looked
   far less detailed than the laptop one.
   Inks (done): five inks chosen before a run, each a colour and a play style
   (`data/inks.json`): Blue, Crimson, Emerald, Violet, Gold. All are available
   now; unlocking them with currency belongs to the meta milestone. The user
   chose to keep ink-blending visual only, the 30% touch zoom, and 3-second mines.
5. Burning Page mode (done): `BurnSystem` burns the page inward a strip at a
   time; the player's ink in a strip survives as `LOCKED`, the rest becomes
   `DEAD` (impassable, unpaintable); each strip pays XP and healing by the share
   owned, and a bonus card at 90%+. `FlowField` routes enemies round burnt paper.
   Chosen on the title screen (`GameState.mode_id`); both modes share
   `modes/survival.tscn`.
   On-device feedback pass (done): the user now tests on a real iPhone. They
   disliked the generated metal (music is now calm plus three faster "pressure"
   versions of the same plucked theme, one tier per boss met); found the first
   boss far too tanky (boss and tough-enemy health cut hard); found cards too
   wordy (each has a `short` line of a few bold words; keep new cards to that)
   and wanted richer card art (rarity splash, rays, sparks, shine).
6. Mobile (in progress): the iOS preset exports a clean Xcode project once an
   App Store Team ID is set (verified by exporting on Linux with a placeholder
   ID; the build itself has not been run on a device). The user has a Mac and
   has it running on their iPhone through Xcode with a free Apple ID. To see an
   update on the phone they must download the project again, re-export from
   Godot and press Play in Xcode. Still open: frame rate on the phone.
   Later feedback: the metal was "too thin" (now four rhythm guitars, harder
   clipping, double kick, louder master); Burning Page payouts were too weak
   (doubled, card at 70%, pulse charge at 35%, Seals per strip); difficulty
   after the balance pass felt about right.
7. Meta (done): title screen (`menus/title.tscn`, the main scene) with ink
   unlocks, permanent boosts and settings; Seals currency paid at run end; JSON
   save (`SaveData`, `user://blotline_save.json`); generated sound and music
   (`Audio`, `tools/gen_audio.py`); vibration; a final boss at 15:00 whose death
   wins the run, after which the player may keep going.
   Sounds are generated in code and have NOT been heard by anyone but the
   user. Their feedback so far: effects were too repetitive (now several
   variants each, and gems climb a scale), and they want heavy metal riffs
   when the larger enemies arrive. Music is therefore two synced tracks, a calm
   koto line and a metal version of the same melody; `Audio` fades to metal
   while any `heavy` enemy is alive (`Events.heavy_presence`).
   The user also found Seals too fast: earnings were cut and prices raised.
   Balance pass (done by simulation, not by play): `tools/balance_sim.gd` showed
   the page filling to the enemy cap by minute two and levelling stalling, so
   spawn pace, enemy health growth and the XP curve were eased. Treat balance
   as provisional until the user reports from real runs.

Commit after each milestone and tell the user exactly what to test and report.

**Asking the user anything: always use multiple-choice selections** (the
AskUserQuestion tool), never open questions in prose. The user asked for this
explicitly. This includes end-of-update feedback questions: offer choices.

## Layout

- `data/` JSON content: enemies, weapons, player, modes, waves, pulses, upgrades,
  progression, pickups, milestones, inks, skills, store, meta, arsenal (numbers for upgrade
  effects, read with `DataDB.arsenal_num(id, key, default)`). Loaded by `DataDB`.
- `autoload/` `Events` (signal bus), `DataDB`, `SaveData` (persistent save),
  `GameState` (run clock, XP, level, chosen ink, Seals earned), `Upgrades`
  (run-scoped stat modifiers), `Audio` (sound, music, vibration; listens to
  `Events`, and a few systems call `Audio.play(id)` directly).
- `menus/` the title screen. `assets/audio/` generated WAV files.
- `core/` engine-agnostic helpers: `SpatialGrid`, `ObjectPool`, `InkGrid`, `FlowField`,
  `Brush` (ragged blots and cores for anything drawn outside `ShapeVisual`).
- `entities/` one folder per entity: state script + scene. `entities/visuals/` holds visual components.
- `systems/` managers that own and update entities: `EnemyManager`, `BulletManager`, `SpawnDirector`,
  `InkSystem`, `PulseSystem`, `SecondarySystem`, `AuxWeapons` (laser, orbit,
  mortar), `Arsenal` (every other extra weapon and passive ink effect),
  `Hazards` (burn zones, black holes, mines), `EnemyShots`,
  `PickupManager` (temporary powers and item pickups), `ItemSystem`,
  `MilestoneSystem`,
  `GemManager`, `Effects`.
- `assets/fonts/` Kaushan Script (SIL Open Font License; licence file alongside).
- `ui/` `common/sumi.gd` (shared look), HUD, touch controls, level-up cards, pause menu, run summary, debug overlay, safe area.
- `modes/` one root scene per game mode; the root script wires systems together.
- `tools/` headless scripts: `setup_input_map.gd`, `smoke_test.gd`, `ink_test.gd`,
  `restart_test.gd`, `meta_test.gd` (final boss, victory, payout, unlocks),
  `burn_test.gd` (Burning Page), `progress_test.gd` (skills, store items,
  Lasso, Deluge), `balance_sim.gd` (a bot run
  that prints horde size and level per minute); and `gen_audio.py` (regenerates every sound; needs numpy).

## Conventions

- **Input:** gameplay reads InputMap actions only, and polls them
  (`Input.is_action_pressed`, `is_action_just_pressed`, `get_vector`). Never read
  actions from `_input` events: the touch UI feeds actions with
  `Input.action_press()`, which generates no events. Raw touch events are allowed
  only in `ui/touch/`.
- **Actions:** `move_left/right/up/down`, `aim_left/right/up/down`, `fire`, `secondary`, `pulse`, `dash`, `pause`,
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
- **Export:** `export_presets.cfg` has iOS and Web presets. JSON files are not
  Godot resources, so each preset lists `data/*.json` as an include filter; keep
  that on any new preset. The iOS preset needs the user's Apple team ID and a
  unique bundle identifier. `build/` is git-ignored.
- **Web build:** `.github/workflows/pages.yml` exports the Web preset and deploys
  it to GitHub Pages on every push to main (single-threaded build, so no special
  headers). The user tests on iPhone Safari through that link.
- **After every push, give the user a fresh Safari link.** Wait for the "Deploy web
  build" run for that commit to succeed (`gh api repos/JobenR/Roguelite-Game/actions/runs`),
  then give `https://jobenr.github.io/Roguelite-Game/?v=<short commit hash>`. The
  `?v=` part changes each time so Safari cannot show a cached old version. If the
  run fails, say so and do not give a link.

## Enemies

- Types and all their numbers live in `data/enemies.json`; the mix per wave and
  the mini-boss schedule live in `data/waves.json`.
- `behavior` picks the movement code in `EnemyManager`: `chase` (default),
  `charge` (Brute: wind up, then lunge), `ranged` (Spitter: holds distance and
  fires through `EnemyShots`), `boss` (The Eraser: erases ink around it, slams).
- Other keys: `heavy` (ignores knockback, pulls, ink slow), `boss`, `face_move`,
  `split_into` + `split_count`, `trail_*` and `ink_cut_chance` (Runners and
  Corruptors are the loop cutters).
- Visual keys: `sides` (shape), `core` (the glowing colour that identifies the
  type; its presence selects the brush-ink style), `ring` (bosses), `aura`,
  `streak`. Body `color` is ink black for every enemy.
- `flank` sets how widely a type curves in from the side; `max_enemies_start`
  and `max_enemies_per_minute` in waves.json cap the early horde.

## Upgrades and stats

- Every stat is `(base + add) * (1 + mult)`. Systems read stats on demand:
  `Upgrades.value(stat, base)`, `Upgrades.bonus(stat)` (base 0), `Upgrades.mult_of(stat)`.
- `data/upgrades.json` has `upgrades` (name, desc, max_level, effects) and
  `synergies` (requires two upgrade ids, effects). Effects are
  `{stat, add}` or `{stat, mult}`. A synergy unlocks automatically once every
  required upgrade is owned. `first_level_double` makes level 1 count twice.
- An upgrade that reuses an existing stat needs no code. An upgrade's stat
  name is in its `effects`; grep that name to find where it is read. Extra
  weapons use the stat as their level (`Upgrades.bonus("mines")`).
- Card offers: `Upgrades.roll_choices` weights by `rarity` (common, rare, epic,
  legendary) and favours cards already owned. `banished` cards never return.
- Sets: each upgrade has a `set`. Owning enough different cards of a set
  unlocks its tiers (`sets` in upgrades.json). Cards show set progress, the
  synergy they complete, or a partner card to look for.
- `GameState.damage_bonus` carries situational damage (on ink, moving, low
  health); every weapon multiplies by `1 + damage_bonus`.
- Enemy status effects (slow, stain, bleed) are fields on `Enemy`, applied in
  `BulletManager._resolve_hit` and ticked in `EnemyManager`.
- Each upgrade has a `category` (weapon/stat/ink: icon tint), a `rarity` (card
  border and banner), an `icon` id drawn in code by
  `ui/levelup/upgrade_icon.gd`, and an optional two-letter `badge` for cards
  that share a picture. An unknown icon id shows the default drop.
- Temporary powers live in `GameState.powers` (id -> seconds left), granted by
  pickups in `data/pickups.json` (one shared drop chance and pity timer, then a
  weighted pick among `types`). `<id>_duration` is the stat that extends one.
- Pausing uses `get_tree().paused`. UI that must run while paused
  (level-up cards, pause menu) sets `PROCESS_MODE_ALWAYS`. Never kill enemies
  while iterating `EnemyManager.active`; collect and apply after the loop.

## Ink rules (as implemented)

- `InkGrid`: 8px cells (`ink_cell_size` in modes.json), one byte each (`NEUTRAL`, `INK`, `SMUDGE`,
  `LOCKED` = permanent player ink that nothing overwrites; test ownership with
  `grid.is_ink(pos)`, never `== INK`), plus an RGBA
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
  finds nothing fizzles and keeps its charge (unless Shockwave is owned).
  `gap_cells` (Forgiving Pulse) thickens walls before the flood to plug small gaps.

## Character growth and the store

- Between runs the character has a level (`SaveData.char_level`, from
  character XP paid at run end) and one skill point per level, spent in
  `data/skills.json`: four branches (Force, Range, Speed, Ink) of five nodes
  bought in order. Node effects are ordinary stat effects, applied in
  `Upgrades.reset` along with the ink, boosts and VIP perk.
- The player's drop shows its growth (`ShapeVisual._draw_growth`): rings from
  level, and a mark per skill branch. Keep any new growth visible there.
- Two currencies. Seals are earned by playing (run payout, plus red seal
  stamps dropped by bosses and some tough enemies) and buy inks, boosts and
  most store items. Gold Leaf is the paid currency; a little is also earned
  from bosses and wins. The user chose "pay to speed up": everything that
  affects power must be earnable by play. Do not add paid-only power.
- `data/store.json`: Gold Leaf packs, a one-time VIP unlock, run items (Page
  Wipe, Second Life, Head Start, Lasso), boosters (double XP, double Seals),
  and looks (the seal shape on the drop).
- **Purchases are stand-ins.** `menus/title.gd` `_buy_pack` and `_buy_vip`
  grant the goods and charge nothing, and the store says so on screen. Real
  payments need Apple's StoreKit, a paid developer account and products set up
  in App Store Connect; none of that exists yet. Never present the store as
  taking real money until it does.

## Checking work

```bash
godot --headless --path . --import
godot --headless --path . --script res://tools/ink_test.gd
godot --headless --path . --fixed-fps 60 --script res://tools/smoke_test.gd
godot --headless --path . --fixed-fps 60 --script res://tools/restart_test.gd
godot --headless --path . --fixed-fps 60 --script res://tools/meta_test.gd
godot --headless --path . --fixed-fps 60 --script res://tools/burn_test.gd
godot --headless --path . --fixed-fps 60 --script res://tools/progress_test.gd
```

Always run these under `timeout` and pipe through `grep`/`head`: a tool script
that fails to compile never quits and prints the same error every frame. In a
tool script run with `--script`, do not type a variable as a class that uses
autoloads (`BurnSystem`, `Player`...): it is compiled before the autoloads
exist. Use `Node` and `get`/`call`.

The ink, meta, burn and progress tests must print ALL PASSED; the smoke test must print frame lines with
no script errors.
