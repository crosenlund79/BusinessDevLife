# Business as Usual — Prototype 001: *Welcome to the Company*

A workplace comedy about people, projects, progress, profit, and a bit of chaos.
Built in **Godot 4.3+ (GDScript)**, Forward+ renderer.

You are **Alex**, a brand-new junior consultant at **Northbound Consulting**
("We go where the requirements take us"). Your first day goes like this: you meet the team, sit through a
meeting about reducing meetings, get an URGENT email that says nothing, find out what the client actually
wants, write the handover, test it, deploy it… and then the biscuits arrive.

Roughly 10–15 minutes of play, with one complete story and several branches.

---

## Running it

1. Install **Godot 4.3** or newer (standard build, not .NET).
2. *Import* → select this folder's `project.godot` → **Edit**.
   The first open imports the generated audio (a few seconds).
3. Press **F5** (or ▶ Play).

> Open the project in the **editor** at least once before running it from the command line. That first
> open builds Godot's class cache (the scripts use `class_name`) and imports the audio. Without it the
> game reports "Identifier not declared" and plays no sound. Running `godot --headless --import` also works.

No downloads, add-ons or external assets are needed. Every mesh, material, face, chart and sound is generated
by the code in this repository or by `tools/gen_audio.py`.

### Controls
| Action | Input |
|---|---|
| Walk | Left-click the floor |
| Talk / interact | Left-click a person or object (yellow ring + tooltip on hover) |
| Zoom | Mouse wheel |
| Continue dialogue | Click, Space or Enter |
| Pick a dialogue choice | Click, or keys 1–4 |
| Skip dialogue | **Skip ▸▸** button or Tab |
| Menu, settings, audio volume | Esc |

The bouncing yellow marker always points at the next story objective. The objective card (top left) says
what to do. Everything else in the office can be clicked for extra jokes.

---

## What's in the prototype

- **A 3D office.** Reception with a wood-slat logo wall, open-plan desk clusters, kitchen and cake
  table, glass-walled meeting room, project **war room** with readable charts, the Director's office
  (trophy, putting green, yacht photo), the server nook, and a city skyline through floor-to-ceiling windows.
- **The cast.** The 3D characters below are built from soft primitives. They have expressive eyes,
  brows and painted mouths, a walk cycle, sitting, typing, blinking, lip-flap, and 15 comedic gestures:
  - **Maggie Fairweather**, Head of People & Happiness (the Feel-Good Manager, with cake)
  - **Tobias Grant**, Senior Functional Consultant (overworked, perpetually on a call with Henrik)
  - **Sanne de Vries**, Developer (would like to finish one thing, ever)
  - **Bogdan Kowalski**, Infrastructure (it's not the network)
  - **Chad Pemberton-Vance**, Director of Strategic Transformation (Project SYNERGIA)
  - Background colleagues: Kevin (Finance), Pia (Sales), and Olu (a PM who patrols the office).
  - Clients: **Gerald Pettigrew**, who is confidently wrong and shouts in capitals, and **Dagmar Holm**,
    who knows everything and is "mildly impressed" at most.
- **Fictional workplace software.** NorthOS laptop with *Pigeon* (email), *Natter* (chat) and *TaskPile*
  (tickets). The client's ERP is *Monolith ERP 11 (Cloud Edition, Mostly)*.
- **The work, made playable.** The full consultancy workflow as light interactions: an unclear request →
  find the real requirement → write the handover (choose which notes go in the spec) → the developer
  builds exactly what you wrote → test it (read the warnings!) → client "acceptance test" → deploy (lift
  the safety cover, press the big red button) → the business lives with the consequences.
- **Comedy set pieces.** The meeting about meetings, the escalation phone that glows and throws embers,
  a 2.4-tonne biscuit avalanche through the front door, a cartoon dust-cloud brawl in the war room (KPI!
  ROI?! a stapler), the cake that ends it, and a twist.
- **Progression.** Your choices feed a reputation score and an animated **First-Day Performance Review**:
  spec grade, testing, risk flagged, client mood, biscuits received, and the amount billed.
- **Currency.** All money is in **Bix (¤)**.
- **Audio.** An original fallback score and 22 sound effects, synthesised by `tools/gen_audio.py`. The
  licensed tracks drop in by file name; see `audio/music/README.md`.
- **Settings.** Music, SFX and text-speed sliders, voice blips, and fullscreen. Dialogue can be skipped.

### Branches worth replaying
- Write the spec yourself, or let Tobias do it in four seconds ("Make button green.").
- Put "Make it POP", "Add AI" or "SYNERGIA" in the spec and see how Sanne implements them.
- In the test environment, open the warning and flag the FloorLink risk (or don't).
- Tell Chad that SYNERGIA should "replace management".
- During the brawl: shout STOP, fetch Maggie, or take minutes.

---

## Project structure

```
project.godot            Godot 4 project (autoloads: Loc, Game, Audio)
scenes/main.tscn          Entry scene (everything else is assembled in code)
scripts/
  main.gd                 Boots World → UIRoot → StoryDirector
  autoload/
    loc.gd                String tables (localisation-ready)
    game_state.gd         Flags, stats, objective, settings, currency formatting
    audio.gd              Music cross-fades, SFX pool, licensed-track override
  world/
    world.gd              Environment, lighting, characters, point-and-click, markers, ambient life
    office_builder.gd     The office layout, furniture, signage, screens (data → geometry)
    character.gd          Procedural stylised character: rig, faces, walk/sit/type, gestures
    face_art.gd           Painted mouth textures (expressions)
    mesh_lib.gd           Rounded boxes, stars, cached primitives
    mats.gd               Art-directed palette, materials and shaders (wood floor, skyline, LEDs)
    nav_grid.gd           A* walkability grid (furniture registers its footprint)
    camera_rig.gd         Follow / zoom / conversation focus / shake
    screen_content.gd     2D charts & slides rendered onto in-world screens
    interactable.gd       Clickable objects
    brawl_cloud.gd        The cartoon dust-cloud fight
    biscuit_flood.gd      The biscuit avalanche (MultiMesh particles with growing piles)
  ui/
    ui_root.gd            HUD, phone, toasts, video call, captions, title, settings, pause
    dialogue_box.gd       Data-driven dialogue: typewriter, live 3D portraits, choices, events
    desktop.gd            NorthOS: Pigeon mail, Natter chat, TaskPile board
    work_panels.gd        Spec builder, ERP test, deploy button, performance review
    portrait_studio.gd    Private 3D "photo studio" for portraits and video calls
    ui_kit.gd             Theme, fonts, styled widgets
  story/
    story_director.gd     Day 1 sequencing, stage logic, story events
data/
  characters.json         Cast: names, roles, colours, appearance parameters
  text/en.json            ALL player-facing text: UI, dialogue, emails, chats, signage, review
audio/generated/          Synthesised score + SFX (regenerate with tools/gen_audio.py)
audio/music/              Drop-in slot for the licensed reference tracks
art/reference/            The approved "The Office" concept image
tools/gen_audio.py        Original audio synthesiser (numpy)
docs/DESIGN.md            Design notes, humour principles and next steps
```

### Extending
- **New dialogue.** Add a conversation to `data/text/en.json → dialogue`. Lines support `s` (speaker),
  `t` (text), `e` (expression), `g` (gesture), `emote`, `shake`, `if` (flag / `!flag`), `set`, `stat`,
  `sfx`, `event`, and `choice` with nested `then`. Any object or person automatically uses
  `flavor_<id>` / `chat_<id>`, or the stage-specific `chat_<id>_<stage>`.
- **New characters.** Add them to `data/characters.json`. Hair styles: `tousled, bun, bob, slick, buzz,
  curly, ponytail, long, bald_sides, short`. Accessories: `glasses, tie, lanyard, headphones, headset,
  pearls, earrings, pocket_square, pen`. Facial hair: `full, moustache, stubble`.
- **Localisation.** Copy `en.json` to `da.json`, `nl_BE.json` or `fr_BE.json` and translate it, then
  call `Loc.set_language("da")`. No game logic contains player-facing text.
- **Exporting.** Add `*.json` to *Export → Resources → Filters to export non-resource files* so the
  text tables are included.

---

## Verification status (please read)

This prototype was written in a cloud container where **Godot could not be installed**: downloading the
engine binary was blocked. So:

**Verified**
- All 23 GDScript files parse without syntax errors, checked with `gdtoolkit` 4.5 (`gdparse`).
- `data/text/en.json` and `data/characters.json` are valid JSON.
- Every literal text key used in the code exists in `en.json`, and every story event in the JSON has a handler.
- The audio generator runs and produces all music and SFX files.
- Layout maths was checked by hand: navigation-grid door gaps, approach points, and signage sizes.

**Not verified (never run in Godot)**
- Runtime behaviour, type checks that only Godot's analyser performs, visuals, lighting, performance, UI
  layout and pacing. Expect a short round of fixes on first launch: typically a mistyped property or a
  value that needs tuning. The code is organised so each fix stays local.
- Mesh winding is set for Godot's clockwise front faces. If rounded furniture looks inside-out, flip the
  `ccw_is_out` branch in `mesh_lib.gd`.

### Known visual limitations
- All art is procedural (primitives, rounded boxes, shaders and painted mouths). It aims for the
  concept's warm, stylised look, but it is not sculpted, rigged, hand-made art. Characters have no
  fingers, clothing folds or hair strands. Faces are expressive but simple.
- No baked global illumination. The look relies on SSAO, SSIL, soft shadows, filmic tonemapping and
  warm fill lights.
- Fonts use the system's best available rounded sans-serif (Nunito/Fredoka if installed, then
  Segoe/Arial/DejaVu). Bundling a licensed display font is a recommended next step.
- The music is an original synthesised placeholder until the licensed tracks are added.
