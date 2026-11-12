# New Football Star — Stage 1: the shot

Playable prototype of the SHOT mini-game (GDD §5, roadmap v0.1): training ground, goal, ball,
goalkeeper, crosshair, power bar, 10-shot series and GOAL / SAVE / POST / MISS results. Works with mouse and touch.

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
| `src/server/Main.server.lua` | `ServerScriptService/Main` | Script |
| `src/server/SceneBuilder.lua` | `ServerScriptService/SceneBuilder` | ModuleScript |
| `src/server/KeeperBuilder.lua` | `ServerScriptService/KeeperBuilder` | ModuleScript |
| `src/server/Services/EpisodeService.lua` | `ServerScriptService/Services/EpisodeService` | ModuleScript |
| `src/server/Services/ShotResolver.lua` | `ServerScriptService/Services/ShotResolver` | ModuleScript |
| `src/client/ShotClient/init.client.lua` | `StarterPlayer/StarterPlayerScripts/ShotClient` | LocalScript |
| `src/client/ShotClient/InputController.lua` | `.../ShotClient/InputController` (child of the LocalScript) | ModuleScript |
| `src/client/ShotClient/ShotVisuals.lua` | `.../ShotClient/ShotVisuals` (child of the LocalScript) | ModuleScript |
| `src/client/ShotClient/ShotHud.lua` | `.../ShotClient/ShotHud` (child of the LocalScript) | ModuleScript |
| `src/client/ShotClient/KeeperAnimator.lua` | `.../ShotClient/KeeperAnimator` (child of the LocalScript) | ModuleScript |

The default Baseplate and SpawnLocation are removed automatically during play (they would cover the pitch and goal).

## Controls

Press on the goal to place the crosshair. Hold to charge power (the bar at the bottom goes up and down),
then release to shoot. On PC the crosshair follows the mouse before you click. While you hold,
the dotted line shows the planned path without random error. After each shot a result card appears.
Press **ЕЩЁ УДАР** (or Space / Enter / gamepad A) for the next shot. A series is 10 shots; the
dots under the goals counter show each result.

- Aiming close to a post or the bar beats the keeper but risks POST or MISS.
- Weak shots are slow and easy to save. Shots near the centre always get saved.
- Power above 85% (the marker on the bar) is less accurate and tends to go over the bar.

All on-screen text is in the `TEXT` table at the top of `ShotHud`.

## Testing

1. **PC:** press Play. The Output window should show:
   `[SceneBuilder] Stadium built (… objects)`, `[KeeperBuilder] Goalkeeper ready (R15, … studs tall)`, `[Main] Stage 1 shot prototype ready`, `[ShotClient] ready`,
   `[EpisodeService] <you>: episode #1 started (SHOT, seed …)`, and after each shot
   `[EpisodeService] <you>: episode #1 aim=(0.72, 0.55) power=0.64 -> GOAL/GOAL, 98 km/h (1 goals from 1/10 shots)`.
   There should be no red errors.
2. **Phone layout:** Test → Device emulator, choose a phone in landscape, and repeat.
   The HUD respects screen notches, and no thumbstick or jump button appears.
3. **Real phone:** publish to a private test place and play it from the Roblox app.
4. **Cheat check:** in Play mode, from the client command bar run
   `game.ReplicatedStorage.Remotes.SubmitEpisodeInput:FireServer(999, 5, 5, 5)`.
   The Output should show an orange `rejected input … (unknown or already finished episode)`
   warning and the score should not change. Sending the same episode twice is rejected the same way.
5. **Reproduce a result:** the seed is printed for every episode. Passing the same seed and input to
   `ShotResolver.resolve` always gives the same outcome.

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
(`Goalkeeper.Enabled = false` gives the "no keeper" variant), and camera.
`DefaultShooting = 42` stands in for the player's stat until careers exist (Stage 4).

To use the PNG logo instead of the text-built one, upload it to Roblox (Asset Manager → Images)
and put its id into `LOGO_IMAGE` at the top of `ShotHud`.
