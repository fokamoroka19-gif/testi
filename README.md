# New Football Star — Stages 1–2: the shot and the pass

Playable prototype of the SHOT and PASS mini-games (GDD §5–6, roadmap v0.1–v0.2): stadium, goal,
goalkeeper, a shot training (finger hint, then 5 goals) followed by a pass training (finger hint,
then 5 good passes past a defender), and free shooting after that. Works with mouse and touch.

**Client draws, server decides.** The client only sends `{episodeId, aimX, aimY, power}`.
The server checks types, ranges, the current episode, repeats and request rate, then computes
the outcome with its own random seed. A client cannot report a goal.

## Setup

**Easiest:** download `places/NewFootballStar_Stage1.rbxlx`, open it in Studio (File → Open from File),
and press Play. Everything is already in the right place. The stadium, goal, crowd and remotes are
built by the server when the game starts, so the place looks empty in edit mode. That's expected.
To rebuild the file after changing code, run `rojo build -o places/NewFootballStar_Stage1.rbxlx`.

**With Rojo:** `rojo serve` and connect from the Studio plugin (`default.project.json` maps the folders below).

**By hand:** create the objects below with these exact names and types, and paste in the file contents.
Don't drag `.lua` files into Studio. That keeps suffixes like `.server` and `.client` in the names.
The server modules can be anywhere under ServerScriptService (next to `Main` or inside `Services`).

| File | Studio location | Type |
|---|---|---|
| `src/shared/ShotConfig.lua` | `ReplicatedStorage/Shared/ShotConfig` | ModuleScript |
| `src/shared/ShotPhysics.lua` | `ReplicatedStorage/Shared/ShotPhysics` | ModuleScript |
| `src/shared/PassConfig.lua` | `ReplicatedStorage/Shared/PassConfig` | ModuleScript |
| `src/shared/PassPhysics.lua` | `ReplicatedStorage/Shared/PassPhysics` | ModuleScript |
| `src/shared/FigureBuilder.lua` | `ReplicatedStorage/Shared/FigureBuilder` | ModuleScript |
| `src/shared/Images/Logo.lua`, `Banners.lua`, `Keeper.lua`, `Ui.lua` | `ReplicatedStorage/Shared/Images/Logo`, `Banners`, `Keeper`, `Ui` (inside a Folder named `Images`) | ModuleScript |
| `src/server/Main.server.lua` | `ServerScriptService/Main` | Script |
| `src/server/SceneBuilder.lua` | `ServerScriptService/SceneBuilder` | ModuleScript |
| `src/server/KeeperBuilder.lua` | `ServerScriptService/KeeperBuilder` | ModuleScript |
| `src/server/Services/EpisodeService.lua` | `ServerScriptService/Services/EpisodeService` | ModuleScript |
| `src/server/Services/ShotResolver.lua` | `ServerScriptService/Services/ShotResolver` | ModuleScript |
| `src/server/Services/PassResolver.lua` | `ServerScriptService/Services/PassResolver` | ModuleScript |
| `src/client/ShotClient/init.client.lua` | `StarterPlayer/StarterPlayerScripts/ShotClient` | LocalScript |
| `src/client/ShotClient/InputController.lua` | `.../ShotClient/InputController` (child of the LocalScript) | ModuleScript |
| `src/client/ShotClient/ShotVisuals.lua` | `.../ShotClient/ShotVisuals` (child of the LocalScript) | ModuleScript |
| `src/client/ShotClient/ShotHud.lua` | `.../ShotClient/ShotHud` (child of the LocalScript) | ModuleScript |
| `src/client/ShotClient/KeeperAnimator.lua` | `.../ShotClient/KeeperAnimator` (child of the LocalScript) | ModuleScript |
| `src/client/ShotClient/ImageLoader.lua` | `.../ShotClient/ImageLoader` (child of the LocalScript) | ModuleScript |
| `src/client/ShotClient/TutorialHint.lua` | `.../ShotClient/TutorialHint` (child of the LocalScript) | ModuleScript |
| `src/client/ShotClient/PassVisuals.lua` | `.../ShotClient/PassVisuals` (child of the LocalScript) | ModuleScript |
| `src/client/ShotClient/FigureAnimator.lua` | `.../ShotClient/FigureAnimator` (child of the LocalScript) | ModuleScript |

The default Baseplate and SpawnLocation are removed automatically during play (they would cover the pitch and goal).

## Artwork (logo, stadium banners, goalkeeper kit)

The HUD logo is the supplied `tools/assets/source/logo.png`, unchanged apart from trimming the empty
border. The LED boards and balcony ribbon show the five supplied logo variants
(`tools/assets/source/banner_logos.jpg`, cut out as they are and laid on dark purple boards), and the
goalkeeper is a blocky R15 rig in the proportions of the character sheet (`tools/assets/source/keeper_sheet.png`)
with the sheet's face, hair, kit, number 10 and gloves painted on. Previews of every image are in `assets/generated/`.

Roblox can't load local PNGs, so the pixels are embedded in the `Images` modules and drawn on the client
with `EditableImage` (no upload needed). Studio Play should work as is. **In a published game (or if the Output shows an `[ImageLoader]` warning), turn on
Game Settings → Security → Allow Mesh / Image APIs**, otherwise the game still runs but shows the
fallbacks: the text logo, plain LED boards and a keeper in plain kit colours (the Output explains why).
If you upload the logo to Roblox yourself, put its id in `LOGO_IMAGE` at the top of `ShotHud`.

The tutorial finger is the supplied icon `tools/assets/source/finger.png`, used as drawn (only the
white page around it is made transparent, see `tools/assets/finger.py`).

To change the art, edit `tools/assets/build_images.py` and run `python3 tools/assets/build_images.py`
(needs Pillow), then rebuild the place file.

## Shot training

1. **Guided shot.** A pulsing ring on the goal shows where to press, and a finger demonstrates it:
   press, hold while the power bar fills to the green **ЗОНА УДАРА**, release. The first press away
   from the ring is ignored (the finger shakes and points at it again). This shot always scores: the
   server keeps the aim and power in a safe range, takes away the random error and makes the keeper late.
   The ring, finger and callout are a BillboardGui anchored at the target point, so they line up with
   the shot on any screen.
2. **Task.** Score 5 goals against the training keeper, in as many shots as it takes. Misses and saves
   don't reset anything. The goals panel shows the task and one dot per goal.
3. **Completed.** After the 5th goal a **ТРЕНИРОВКА ПРОЙДЕНА!** menu appears (goals and shots taken,
   fastest goal, stage 1 done) with two buttons: **ЕЩЁ РАЗ** replays the task, **ДАЛЕЕ** opens the
   pass training.

## Pass training (stage 2)

The camera rises behind our player. Two teammates (gold) wait upfield, one defender (red) walks
back and forth on a short route. Press anywhere, drag to where the ball should go and let go: the
dotted line shows the path, the drag length is the power (the ball rolls a little past the release
point, so it reaches the teammate with some pace). Lilac rings show where a teammate can take the
ball, the red circle shows the defender's reach.

The server simulates the pass: the defender reacts after ~0.3 s and runs at the ball, teammates step
up to 4 studs to meet it. Results: **ТОЧНЫЙ ПАС** (received), **ПЕРЕХВАТ** (the defender got there
first), **СЛИШКОМ СИЛЬНО** (too fast for the teammate to control), **НЕ ДОШЁЛ** / **МИМО**.
A teammate the defender isn't near is safe; one he is patrolling towards needs the right moment.

1. **Guided pass.** The target teammate's ring pulses and the finger shows it: press at the ball,
   drag to the teammate, let go. This pass always arrives.
2. **Task.** 5 good passes in any number of attempts, in random situations (`PassConfig.Layouts`).
3. **Completed.** The menu again: **ЕЩЁ РАЗ** replays the task, **ДАЛЕЕ** opens free play
   (unlimited shots against the normal keeper) until the next stage (a full match) exists.

The defender's position is the same on both sides: the client sends the time at which it played the
pass, and the server only accepts times within 0.6 s behind its own clock.

The flow is decided on the server (`EpisodeService`), so a client can't skip a task. Numbers are in
`ShotConfig.Training` (shot) and `PassConfig` (pass). To test the pass stage without replaying the
shot training, set `ShotConfig.Training.StartStage = "PASS"`.

On phones (short side under 500 px) the HUD is drawn up to 1.7× larger than the plain fit (the logo a bit less), as far as
the power panel and the completion menu still fit the screen (`PHONE_*` at the top of `ShotHud`).

## Controls

Press on the goal to place the crosshair. Hold to charge power (the bar at the bottom goes up and down),
then release to shoot. On PC the crosshair follows the mouse before you click. While you hold,
the dotted line shows the planned path without random error. After each shot a result card appears.
Press its button (or Space / Enter / gamepad A) to continue.

- Aiming close to a post or the bar beats the keeper but risks POST or MISS.
- Weak shots are slow and easy to save. Shots near the centre always get saved.
- Power above 85% (the marker on the bar) is less accurate and tends to go over the bar.

All on-screen text is in the `TEXT` table at the top of `ShotHud`.

## Testing

1. **PC:** press Play. The Output window should show:
   `[SceneBuilder] Stadium built (… objects)`, `[KeeperBuilder] Goalkeeper ready (R15 blocks, … studs tall)`, `[Main] Shot and pass training ready`, `[ShotClient] ready`,
   `[EpisodeService] <you>: episode #1 started (SHOT TUTORIAL, seed …)`, and after each shot a line like
   `[EpisodeService] <you>: episode #2 SHOT TASK aim=(0.72, 0.55) power=0.64 -> GOAL/GOAL, 98 km/h, CONTINUE (1 of 1)`;
   in the pass stage `... PASS TASK dir=(-0.62, -0.78) power=0.52 t=2.31 -> GOOD/GOOD, 37 km/h, CONTINUE (1 of 1)`.
   There should be no red errors.
2. **Phone layout:** Test → Device emulator, choose a phone in landscape, and repeat.
   The HUD respects screen notches, and no thumbstick or jump button appears.
3. **Real phone:** publish to a private test place and play it from the Roblox app.
4. **Cheat check:** in Play mode, from the client command bar run
   `game.ReplicatedStorage.Remotes.SubmitEpisodeInput:FireServer(999, 5, 5, 5)`.
   The Output should show an orange `rejected input … (unknown or already finished episode)`
   warning and the score should not change. Sending the same episode twice is rejected the same way.
5. **Reproduce a result:** the seed and mode are printed for every episode. Passing the same seed,
   input and options (guided for TUTORIAL, `keeperDelay` for TASK) to `ShotResolver.resolve` always
   gives the same outcome.

## Physics

The server simulates every shot step by step (1/240 s): gravity, air drag, and spin. Shots aimed
towards a post curl back towards the middle, and hard shots get top spin and dip. The ball
collides with the keeper, posts, crossbar, net (back, sides, roof, side netting), the boards
behind the goal and the ground (bounces, then rolls). The keeper reacts after a short delay,
moves at a skill-based speed and, if he gets there, catches comfortable shots or parries the
rest wide or over the bar. The result comes from what actually happens: a shot can go in off
the post or be parried onto the frame. The client replays the exact path the server sent.

## Tuning

All numbers are in `ShotConfig`: goal size, distance, ball speed, physics (drag, curl, dip,
bounciness), shooting accuracy, overpower, goalkeeper skill/reaction/dive speed/catching
(`Goalkeeper.Enabled = false` gives the "no keeper" variant), the shot training (`Training`), and camera.
`DefaultShooting = 42` stands in for the player's stat until careers exist (Stage 4).
