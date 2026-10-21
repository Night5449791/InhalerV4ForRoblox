# CODEBUDDY.md This file provides guidance to CodeBuddy when working with code in this repository.

> `Night5449791/InhalerV4ForRoblox` — a fork of Vape V4, a Roblox combat/utility script. The runtime is **Luau inside an executor**, not standard Lua and not Node. `src/` is the only editable source; an external bundler flattens it into `Night5449791/InhalerCompiled`, which the loader downloads at injection time. Fork is CC BY 4.0, upstream CC0 1.0.
> `AGENTS.md` is the condensed version of this file. Section numbers (`§9`, `§11`) are referenced from other docs — keep them stable.

## 1. Commands

Build happens only in CI. `.github/workflows/build.yaml` on push to `main`: clone this repo, `InhalerCompiled` and `InhalerBundler`; move `.github/workflows/workflowConfig.json` to `InhalerBundler/config.json` (`SRC_PATH=./src`, `PROD_PATH=./InhalerCompiled`); `npm i`; `node ./InhalerBundler/index.js prod` (Node 24.15.0); commit and push the output. Bundling rules live in InhalerBundler, not here.

There is no lint, formatter or test suite (no selene/stylua config, no `package.json`, no Makefile). Do not add tooling unless asked. Syntax-only check of one file — rewrite Luau-only spellings, then parse with Lua 5.4:

```bash
sed -E -e 's/[[:space:]]+continue([[:space:]]|$)/ break\1/g' \
       -e 's/([A-Za-z_][A-Za-z0-9_.]*) ([+-])= /\1 = \1 \2 /g' FILE.lua > /tmp/check.lua \
  && luac -p /tmp/check.lua && echo "syntax OK"
```

Development needs a Roblox executor. Mirror `src/` into its workspace so paths match runtime `newvape/...`, then:

```lua
shared.VapeDeveloper = true
loadstring(game:HttpGet('https://raw.githubusercontent.com/Night5449791/InhalerV4ForRoblox/main/NewMainScript.lua', true))()
```

`VapeDeveloper` skips the remote sha lookup and cache wipe and reads `newvape/loader.lua` from disk, so re-executing picks up edits. `VapeIndependent` skips universal/game injection and exports `vape.Init` instead; `VapeCustomProfile` names the save profile; `vapereload` marks a post-teleport reload. Game products only exist as compiled chunks, so testing one module means running InhalerBundler or hand-appending the file body to `newvape/games/<PlaceId>.lua` and re-running. The Python update tool is local-only: `python3 -m py_compile inhaler_send_update.py` (delete `__pycache__/` afterwards).

## 2. Boot chain

1. Root `loadstring` (one line) fetches `NewMainScript.lua`, byte-identical to `src/loader.lua`.
2. `src/loader.lua` only bootstraps the filesystem: executor fallbacks (`isfile`, `delfile`), `downloadFile(path)` caching from `raw.githubusercontent.com/Night5449791/InhalerCompiled/<commit>/<path>`, folder creation, commit sha scraped from `currentOid` into `newvape/profiles/commit.txt`, then `loadstring(downloadFile('newvape/main.lua'), 'main')()`. Every downloaded `.lua` gets the watermark `--This watermark is used to delete the file if its cached, ...`; `wipeFolder()` deletes files still carrying it (never `loader`). Keep that contract.
3. `src/main.lua` waits for `game:IsLoaded()`, calls `shared.vape:Uninject()` on reload, loads `newvape/guis/new.lua` into `shared.vape` (GUI name hardcoded `'new'`), then `newvape/games/universal.lua` unconditionally, then `newvape/games/<PlaceId>.lua` if present, then `finishLoading()`. `finishLoading()` clears `vape.Init`, runs `vape:Load()`, starts a 10-second `vape:Save()` loop, and `queue_on_teleport`s a re-injection script carrying the three flags.

`shared.vape` is the single global anchor; downstream files open with `local vape = shared.vape`.

## 3. Bundling model

Three layers, each loaded as an independent chunk; `require` appears only on game-owned ModuleScripts.

`src/libraries/` — standalone chunks returning a table, fetched as `newvape/libraries/<name>.lua`: `entity.lua` (`entitylib`), `hash.lua` (`sha`), `prediction.lua`, `vm.lua` (Fiu VM; jailbreak), `drawing.lua` (Actor bridge; frontlines, redliner), `webhook.lua` (Discord poster, loaded through `pcall`).

`src/guis/new/` — the only GUI. `base.lua` defines `vape` and every `vape:*` method but is not self-contained: the bundler inlines files at three markers — `--Libraries` (:67, `guis/new/libraries/*` as globals), `--Init` (:574, the body of `vape:LoadGUI()`, i.e. `init.lua`), `--Components` (:772, `components/*` plus `overlays/*` wrapped as `components.<Name> = function(props, children, api)`). It ends with `return vape`. `init.lua` builds the ScreenGui, the six categories, Friends/Targets/Profiles lists, `LegitWindow`, `SearchBar`, `OverlayBar`, and the General/Modules/GUI/Notifications panes.

`src/games/<game>/<PlaceId> - <desc>/` compiles to `newvape/games/<PlaceId>.lua`; the text before the first ` - ` is the filename. A product is `base.lua` plus category folders (`Combat/`, `Blatant/`, `Render/`, `Utility/`, `World/`, `Legit/`, `Inventory/`), concatenated into one chunk with `base.lua` first. Module files therefore have no `require` and no `local vape =`; they reuse the base's locals, and every top-level name must be unique across the product or it silently shadows another file (§9).

Products and module counts:

| Product | Modules |
|---|---|
| `universal - base` → `universal.lua` (always loaded) | 55 |
| `bedwars/6872274481 - game` (retired) / `6872265039 - lobby` | 69 / 2 · 2 redirects |
| `prison life/155615604 - main` | 40 · 1 redirect |
| `jailbreak/606849621 - main` | 26 · 2 redirects |
| `skywars voxel/8768229691 - skywars game` | 16 · 5 redirects |
| `frontlines/5938036553 - game` | 15 · 3 redirects |
| `1.8arena/77790193039862 - game` | 15 · 1 redirect |
| `blocktales/16483433878 - blocktales` | 14 · 1 redirect |
| `bridge duel/139566161526375 - game` | 13 |
| `redliner/115875349872417 - game` | 12 · 2 redirects |
| `132768098780837 - blockwars` | 11 |
| `72169370437173 - tribes3v3` | 10 |
| `893973440 - flee the facility` | 7 |
| `redwood prison/10456235914 - game` | 5 · 4 redirects |
| `bloxstrikes/114234929420007 - game` | 1 |
| `girls and boys vs zombies/796267492 - main` | 1 · 5 redirects |
| `futuretops/5169051062 - lobby` | 0 (registers `sessioninfo` items only) |

A redirect is a standalone `<PlaceId> - <desc>.lua` at the game-folder root: set `vape.Place` to the parent PlaceId, then `loadstring` that parent chunk (some forward `...`). `skywars voxel/8542259458 - skywars lobby.lua` is not a redirect — it is a mini-base that only registers `sessioninfo` items.

## 4. Core `vape` object

Root table (`base.lua:1-22`): `ActiveBinds`, `Categories`, `GUIColor`, `HeldKeybinds`, `Loaded`, `Libraries`, `Modules`, `Place` (= `game.PlaceId`), `Profile` (= `'default'`), `RainbowSliders`, `Settings`, `SettingToggleNotifications`, `ThreadFix` (= `setthreadidentity and true`), `ToggleNotifications`, `Version = '4.22'`, `Windows`.

- `vape.Loaded` is a three-state sentinel: `false` → `canSave` at the end of `Load` (:537) → `nil` in `Uninject`. Modules use `repeat ... until vape.Loaded == nil` to exit and `repeat task.wait() until vape.Loaded` to wait.
- `vape.ThreadFix` requires `setthreadidentity(8)` before any core-GUI or Instance creation.
- `vape:Remove(name)` searches `self.Modules`, `self.Legit.Modules`, then `self.Categories` and destroys the first hit; it records no "removed" flag, so it only affects objects alive at call time.
- Redirects overwrite `vape.Place` with the parent id so one profile spans subplaces.

Methods: `CreateCategory` :338 · `CreateCategoryList` :342 · `CreateNotification(title, text, duration, 'info'|'warning'|'alert')` :346 · `CreateOverlay` :444 · `Load(skipgui, profile)` :448 · `LoadOptions` :563 · `LoadGUI()` :573 (empty, filled by `--Init`) · `Remove` :577 · `Save` :608 · `SaveOptions` :642 · `SortCategories` :655 · `Uninject` :675 · `UpdateGUI` :721 · `UpdateGUIQueue` :735 · `Clean(x)` (`addMaid` :166; accepts connection, Instance, thread or function). Also `UpdateTextGUI` (`overlays/TextGUI.lua:322`) and `Color`/`TextColor` (`libraries/color.lua`); private helpers sit in `base.lua:24-330`.

Line numbers were accurate when written; re-check before trusting one.

## 5. Components and options

Bundled form: `components.<Name> = function(props, children, api)`. Every container (`Module`, `Category`, `CategoryList`, `GUI`, `SettingsPane`, `Overlay`, `OverlayBar`, `LegitModule`, `LegitWindow`) ends with a loop installing `Create<Name>` onto itself. `vape.Components` (`base.lua:774`) is a metatable that retro-installs a new `CreateX` on every existing module when `components.X` is written.

Module (`components/Module.lua`): `{Category, Enabled = false, ExtraText, Index, Name, Options, Visible}`, `.Object` (220×40), `.Children`, `.Edit`, `.Bind`, `.Connections`; line 1 calls `vape:Remove(props.Name)`, so re-running a chunk hot-reloads. `Function(enabled)` is spawned by `Toggle` (:199) — never spawn your own thread — and `Toggle` disconnects and clears `Connections` on disable.

Options, `<Module>:CreateXxx({...})`, are stored in `module.Options[Name]` and save through their own `Save`:

| Component | Saved shape |
|---|---|
| `CreateTargets` | hardcoded key `"Targets"` |
| `CreateToggle` | `{Enabled}` |
| `CreateSlider` | `{Value, Max}` |
| `CreateTwoSlider` | `{ValueMin, ValueMax}` |
| `CreateDropdown` | `{Value}`; `.Change(list)` swaps the list |
| `CreateTextBox` / `CreateTextList` | `{Value}` / `{List, ListEnabled}` |
| `CreateColorSlider` | `{Hue, Sat, Value, Opacity, Rainbow}` |
| `CreateBind` | `{Keys, Mobile, Hold}`; module bind uses key `"Bind"` |
| `CreateButton` / `CreateDivider` | nothing (returns nil) |

`Visible` (on `<Option>.Object`) is never saved, so a sub-option under an already-enabled parent must be re-applied on enable. Legit modules come from `vape.Legit:CreateModule` (44 call sites), accept `Size`, and build their UI in `Module.Children`. Overlays (`vape:CreateOverlay` → `components/Overlay.lua`) expose `.Button`, `.Pin`, `.Expand`, `.Update` and save into the profile, not the layout.

## 6. Persistence

`vape:Save` writes two JSON files (`v = 1`): `newvape/profiles/<game.GameId>.gui.txt` (`{Categories, Profile, v}` — layout of non-overlay categories) and `newvape/profiles/<Profile><Place>.txt` (`{Modules, Categories, Legit, v}` — module state plus overlay categories). Module entries look like `{Enabled, Visible, Bind = {Keys, Mobile, Hold}, Options = {...}}` using the shapes above. `v ~= 1` drops `guiData.Categories.Main` and migrates legacy single-key binds. Corrupt JSON degrades to `{Categories = {}}`, raises an `alert` notification and sets `canSave = false`. Unknown module/option names are ignored on load and vanish on the next save. Other profile files: `commit.txt`, `asset.txt`, `gui.txt`, `whitelist.json`, `cheaters.json`, `color.txt` (theme override read by `libraries/uipallet.lua`).

## 7. Libraries and `entitylib`

`src/libraries/entity.lua` returns `entitylib`: `isAlive`, `character` (local entity, not in `List`), `List`, `Events`, plus `start`/`stop`/`refresh`/`kill`. Only five events fire: `LocalAdded`, `LocalRemoved`, `EntityAdded`, `EntityRemoved`, `EntityUpdated` (`EntityRemoving` is never fired). Entities expose `Character`, `Humanoid`, `RootPart`, `Head`, `Health`, `NPC`, `Player`, `SpawnTime`, `Targetable`, `TeamCheck`, `Connections`; `Friend`/`Target` are injected by universal, not by the library.

Overridable hooks: `targetCheck`, `getUpdateConnections`, `getEntityColor`, `isVulnerable`. Selectors `EntityMouse`, `EntityPosition`, `AllPosition` take a settings table that the library `table.clear`s before returning — pass a fresh table every call. `Wallcheck(origin, position, ignore)` is non-nil when blocked. The library calls `entitylib.start()` on load, so after overriding hooks call `start()` again (every game base ends that way); `Targetable` is computed once per spawn and stays stale until `refreshEntity`.

Universal registers `vape.Libraries.entity/whitelist/prediction/hash/webhook/auraanims`; `overlays/TargetInfo.lua:254` registers `targetinfo`; `Render/SessionInfo.lua` registers `sessioninfo`. GUI libraries (`tween`, `uipallet`, `color`, `getfontbounds`, `getvapeasset`) are globals from `--Libraries`. `prediction.SolveTrajectory(...)` returns an aim point or nil. `whitelist:get(plr)` returns `(level, attackable, tags)`; the second value is what `targetCheck` reads. `getvapeasset` caches downloads on desktop and otherwise falls back to an inline `rbxassetid://` table, returning `''` on a miss.

## 8. Authoring a game module

A base runs in this order: shims → service locals (`cloneref`) plus `gameCamera`/`lplr` → `local vape = shared.vape` and `vape.Libraries.*` → a state table → waiting for the game framework (`require`, `debug.getupvalue`, `getgc`) inside `run(function() ... end)` → overriding `entitylib` hooks → grabbing remotes → `sessioninfo:AddItem` → `vape:Clean` restores → `entitylib.start()` → `for _, v in {...} do vape:Remove(v) end` to drop inapplicable universal modules.

Module files reuse the base locals and keep a fixed shape:

```lua
local Reach
local Targets
Reach = vape.Categories.Combat:CreateModule({
	Name = 'Reach',
	Function = function(callback)
		if callback then
			repeat
				-- work
				task.wait()
			until not Reach.Enabled
		end
	end
})
Targets = Reach:CreateTargets({Players = true})
```

Each file re-declares the shims it uses (`isfile`, `cloneref`, `queue_on_teleport`, notifying `loadstring`) because chunks load alone. Universal's base also provides shared helpers (`isFriend`, `isTarget`, `canClick`, `getTool`, `notif`, `serverHop`, `updateVelocity`, `motorMove`), the `SpeedMethods` table, and the whitelist command set (`kill`, `kick`, `chat`, `toggle`, `uninject`, …).

## 9. Known pitfalls

- `base.lua:560` — `vape:Load` ends with `return toggleData`, but `toggleData` is undefined.
- `base.lua:524` — `Save` inside `Load` early-returns (`not self.Loaded`); the first real write comes from the 10-second loop.
- Module objects have no `Type` field, so `Remove`'s `isModule` check never re-sorts categories.
- `CreateTargets` always saves under `"Targets"`, ignoring `Name`.
- `TwoSlider` never calls `props.Function` from `SetValue`.
- `vape:Remove` only affects modules that already exist: a product base runs before its own category files, so it can only drop universal's modules there. Remove a product's own module from that module file.
- `Dropdown:SetValue` silently falls back to `List[1]` when the value is missing, so a renamed value or stale profile quietly becomes the first entry.
- `Enabled and nil or true` is always `true`; pass booleans through unchanged.
- One product equals one scope: a duplicated top-level local silently overwrites another file's, and an assignment without `local` writes the base's variable (some pairs rely on that).
- `bedwars/6872274481 - game/base.lua:33` kicks the player — BedWars is retired.

## 10. Conventions

1. Tabs, no semicolons; don't collapse multi-argument calls onto one line (`CONTRIBUTING.md`).
2. Localize aggressively — never index a field or call a function twice in a loop; hoist per-frame constants.
3. New modules go in `src/games/<game>/<PlaceId> - <desc>/<Category>/<Name>.lua` with no `require`, unique top-level names and the base's locals.
4. Route all cleanup through `vape:Clean(...)` / `<Module>:Clean(...)`; raw `:Connect()` leaks across reinjection.
5. Module loops: `repeat ... task.wait() until not Module.Enabled`; the framework already spawns `Function`.
6. Cross-file forward declarations: the base declares `local Reach = {}`, the module assigns without `local`.
7. Hot restart an option change: `if Module.Enabled then Module:Toggle(); Module:Toggle() end`.
8. Prefer guarded executor calls (`typeof(x) == 'function'`, `pcall`) over raw calls with live game objects.
9. When asked to optimize, touch only code the assistant wrote in that file; upstream and maintainer code stays unless explicitly requested.

## 11. Changelog via Discord webhook

`UPDATES.md` and `inhaler_send_update.py` are gitignored, and `UPDATES.md` is generated — never commit it. After changing any Inhaler file, append user-visible entries in this exact shape:

````md
[Universal]
```diff
~ [Killaura.lua] target sorting now prefers the closest entity
```
````

One line per changed file, `+` added / `-` removed / `~` changed; no mechanics, no multiple lines per file. Universal changes use `[Universal]`; rerunning replaces the earlier message. The script (`./inhaler_send_update.py <WebhookURL>`, or `WEBHOOK_URL`/`UPDATES_FILE`/`PROXY`, proxy default `127.0.0.1:7890`, `off` disables) posts the file, splits entries past Discord's 1024-character field limit into `Name (2)`, keeps the file when sending fails and deletes it on success. Don't run it or post the webhook unless asked.
