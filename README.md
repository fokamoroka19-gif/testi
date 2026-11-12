# New Football Star — Stage 1: the shot

Playable prototype of the SHOT mini-game (GDD §5, roadmap v0.1): fixed camera, goal, ball,
goalkeeper, aim marker, power meter, and GOAL / SAVE / POST / MISS results. Works with mouse and touch.

**Client draws, server decides.** The client only sends `{episodeId, aimX, aimY, power}`.
The server checks types, ranges, the current episode, repeats and request rate, then computes
the outcome with its own random seed. A client cannot report a goal.

## Files → Roblox Studio

| File | Studio location | Type |
|---|---|---|
| `src/shared/ShotConfig.lua` | `ReplicatedStorage/Shared/ShotConfig` | ModuleScript |
| `src/shared/ShotPhysics.lua` | `ReplicatedStorage/Shared/ShotPhysics` | ModuleScript |
| `src/server/Main.server.lua` | `ServerScriptService/Main` | Script |
| `src/server/SceneBuilder.lua` | `ServerScriptService/SceneBuilder` | ModuleScript |
| `src/server/Services/EpisodeService.lua` | `ServerScriptService/Services/EpisodeService` | ModuleScript |
| `src/server/Services/ShotResolver.lua` | `ServerScriptService/Services/ShotResolver` | ModuleScript |
| `src/client/ShotClient/init.client.lua` | `StarterPlayer/StarterPlayerScripts/ShotClient` | LocalScript |
| `src/client/ShotClient/InputController.lua` | `.../ShotClient/InputController` (child of the LocalScript) | ModuleScript |
| `src/client/ShotClient/ShotVisuals.lua` | `.../ShotClient/ShotVisuals` (child of the LocalScript) | ModuleScript |

**With Rojo:** `rojo serve` and connect from the Studio plugin (`default.project.json` maps the folders above).

**By hand:** create `Shared` (Folder) in ReplicatedStorage and `Services` (Folder) in
ServerScriptService, create each object from the table with the exact name and type, and paste the file contents.
You don't need to create the pitch, goal, or remotes: the server builds `Workspace/FootballScene` and
`ReplicatedStorage/Remotes` when the game starts.

## Controls

Press on the goal to place the aim marker. Hold to charge the power meter (it goes up and down),
then release to shoot. On PC the marker follows the mouse before you click. While you hold,
the dotted line shows the planned path without random error.

- Aiming close to a post or the bar beats the keeper but risks POST or MISS.
- Weak shots are slow and easy to save. Shots near the centre always get saved.
- Power in the red band is less accurate and tends to go over the bar.

## Testing

1. **PC:** press Play. The Output window should show:
   `[Main] Stage 1 shot prototype ready`, `[ShotClient] ready`,
   `[EpisodeService] <you>: episode #1 started (SHOT, seed …)`, and after each shot
   `[EpisodeService] <you>: episode #1 aim=(0.72, 0.55) power=0.64 -> GOAL (1/1 goals)`.
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

## Tuning

All numbers are in `ShotConfig`: goal size, distance, ball speed, gravity, shooting accuracy,
overpower, goalkeeper skill/reaction/dive speed (`Goalkeeper.Enabled = false` gives the
"no keeper" variant), and camera. `DefaultShooting = 42` stands in for the player's stat until careers exist (Stage 4).
