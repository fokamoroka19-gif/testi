# New Football Star

Roblox single-player football career game (see `New_Football_Star_MVP_GDD_and_Roadmap.md`).

## Layout

- `src/` – every script in the place, in Rojo layout (`Name.lua` = ModuleScript,
  `Name.server.lua` = Script, `Name.client.lua` = LocalScript, `Folder/init.client.lua` = a
  script with children). This is the source of truth.
- `place/NewFootballStar.rbxlx` – the place built from `src/`; open it in Roblox Studio.
  The stadium, goal and keeper are built at runtime, so the place holds only scripts.
- `tools/place.py` – keeps the two in sync:

```sh
python3 tools/place.py build             # src/ -> place/NewFootballStar.rbxlx
python3 tools/place.py export some.rbxlx # a place saved from Studio -> src/
python3 tools/place.py sourcemap         # sourcemap.json for luau-lsp
```

## Player flow

Main menu (New career / Continue / Settings) → club picker (8 clubs, 3 open) → player name and
shirt number with the 3D kit preview → signed contract → shot and pass training → back to the
career menu (the first match comes next).

Careers are saved in the `NfsCareer_v1` DataStore. In Studio, enable
*Game Settings → Security → Enable Studio Access to API Services* to test saving; without it the
career lasts for the session only and the main menu says so.
