# CODEBUDDY.md This file provides guidance to CodeBuddy when working with code in this repository.

> Repo: `Night5449791/InhalerV4ForRoblox` — a fork of Vape V4, a Roblox combat/utility script GUI.
> Runtime target is **Luau inside a Roblox exploit executor** (not standard Lua, not Node).
> `src/` is the human-maintainable source tree; an external bundler flattens it into `Night5449791/InhalerCompiled`, which the runtime downloads at injection time.
> Licensing: this fork CC BY 4.0, upstream Vape V4 CC0 1.0 (see `README.md` / `LICENSE`).
>
> Section numbers are referenced elsewhere (e.g. "§11"), so keep them stable when editing.

---

## 1. Commands

### Build

There is **no local build command**. Builds happen only in CI: `.github/workflows/build.yaml` triggers on push to `main`, clones the external `Night5449791/VapeBundler` (not in this repo), copies `.github/workflows/workflowConfig.json` → `VapeBundler/config.json` (`SRC_PATH=./src`, `PROD_PATH=./InhalerCompiled`), runs `node ./VapeBundler/index.js prod` (Node 24.15.0), and pushes the flattened output to `InhalerCompiled`. Changing bundling behavior requires editing VapeBundler.

### Lint / Test

**None exist.** No selene/stylua/luacheck config, no `package.json`, no Makefile, no test suite anywhere in the repo. Do not invent or add one unless asked. Validate changes by review against §10 plus, for syntax only, the two checks below.

Static syntax check of one Luau file — there is no Lua compiler for Luau, so the Luau-only spellings are rewritten mechanically first, then parsed with the system Lua 5.4 (`luac -p`). This catches syntax errors only, never semantics or types:

```bash
sed -E -e 's/[[:space:]]+continue([[:space:]]|$)/ break\1/g' \
       -e 's/([A-Za-z_][A-Za-z0-9_.]*) ([+-])= /\1 = \1 \2 /g' FILE.lua > /tmp/check.lua \
  && luac -p /tmp/check.lua && echo "syntax OK"
```

The update tool is Python, so `python3 -m py_compile inhaler_send_update.py` (then delete `__pycache__/`) is its equivalent.

### Run / develop locally

Copy files from `src/` into the executor's workspace so they mirror runtime paths, then execute:

```lua
shared.VapeDeveloper = true
loadstring(game:HttpGet("https://raw.githubusercontent.com/Night5449791/InhalerV4ForRoblox/main/NewMainScript.lua", true))()
```

`shared.VapeDeveloper = true` (set before load) skips fetching the remote commit sha, skips wiping cached files, and makes the loader read `newvape/loader.lua` from disk instead of downloading — so edits take effect on re-execute. Related globals: `shared.VapeIndependent` (don't auto-inject; `vape.Init` is exported so you call `finishLoading` yourself), `shared.VapeCustomProfile` (profile name), `shared.vapereload` (auto-reload after teleport).

To test a single module, edit under `src/games/<game>/...`, then either run the bundler or hand-append the file's body to the matching compiled chunk `newvape/games/<PlaceId>.lua`, and re-run the loader. Sending an update to Discord is §11.

---

## 2. Boot chain

1. **`NewMainScript.lua` / `loadstring`** — one-line user entry; HTTP GETs the loader and runs it. Byte-identical to `src/loader.lua`.
2. **`src/loader.lua`** (68 lines) — filesystem bootstrap only. Defines `isfile`/`delfile` fallbacks and `downloadFile(path, func)`, which caches from `raw.githubusercontent.com/Night5449791/InhalerCompiled/<commit>/<path>`. Creates `newvape/{games,profiles,assets,libraries,guis}`. Resolves the remote commit by parsing `currentOid` off the GitHub page into `newvape/profiles/commit.txt`. Ends with `loadstring(downloadFile('newvape/main.lua'), 'main')()`.
   **Cache watermark:** every downloaded `.lua` is prefixed with `--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.` `wipeFolder()` deletes cached files still carrying it (except `loader`). Preserve this when touching loader logic.
3. **`src/main.lua`** (111 lines) — the assembler: `repeat task.wait() until game:IsLoaded()` → `shared.vape:Uninject()` if reloading → load `newvape/guis/<gui>.lua` into `shared.vape` (gui name is hardcoded `'new'` at `main.lua:87`) → load `newvape/games/universal.lua` unconditionally → load `newvape/games/<game.PlaceId>.lua` if present → `finishLoading()`.
   `finishLoading()` clears `vape.Init`, runs `vape:Load()`, spawns a 10-second `vape:Save()` loop, and hooks `OnTeleport` to `queue_on_teleport` a re-injection script (carrying `VapeDeveloper`/`VapeCustomProfile`/`vapereload`).

**`shared.vape` is the single global anchor** — every downstream file starts with `local vape = shared.vape`.

---

## 3. Source layout and the bundler model

Three layers under `src/`, all loaded at runtime as independent chunks (no `require` anywhere except on game-owned ModuleScripts):

### `src/libraries/` — 6 standalone chunks, each `return <table>`

Loaded via `loadstring(downloadFile('newvape/libraries/<name>.lua'), ...)()`.

| File | Returns | Loaded by |
|---|---|---|
| `entity.lua` | `entitylib` — player/NPC tracking | universal (always) |
| `hash.lua` | `sha` — MD5/SHA1/SHA2/SHA3/HMAC | universal |
| `prediction.lua` | projectile ballistics (`SolveTrajectory`) | universal |
| `drawing.lua` | host id / `'1'` — Actor comm-channel Drawing bridge | frontlines, redliner |
| `vm.lua` | Fiu Luau bytecode VM | jailbreak |
| `json.lua` | `{write, read, encode, decode}` — minimal JSON file I/O (prefers executor `jsonEncode/jsonDecode`, falls back to `HttpService`; uses `writefile/readfile/isfile/isfolder/makefolder`) | on demand |

### `src/guis/new/` — the single GUI

`base.lua` (~795 lines) defines the root `vape` table and every `vape:*` method. **It is not self-contained** — the bundler inlines other files at three marker comments:

| Marker | Line | Injected content |
|---|---|---|
| `--Libraries` | `base.lua:67` | `guis/new/libraries/*.lua` (`uipallet`, `color`, `tween`, `getfontbounds`, `getvapeasset`) emitted as **global** assignments |
| `--Init` | `base.lua:574` (empty body of `vape:LoadGUI()`) | `init.lua` in full — which is why `self`/`vape` works inside it |
| `--Components` | `base.lua:772` | `components/*.lua` (26) + `overlays/*.lua` (2), each wrapped as `components.<Name> = function(props, children, api)` |

So `newvape/guis/new.lua` = base + libraries + components + overlays + init, ending in `return vape`. All GUI upvalues (`gui`, `clickgui`, `scaledgui`, `notifications`, `tooltip`, `toolblur`, `scale`, `components`, `TextGUI`) are assigned inside `init.lua`.

`init.lua` builds the ScreenGui (`components.GUI({})` creates the `Main` category), registers the 6 module categories (**Combat, Blatant, Render, Utility, World, Inventory**), then Friends/Targets/Profiles `CategoryList`s, `LegitWindow`, `SearchBar`, `OverlayBar`, and 4 settings panes (**General, Modules, GUI, Notifications**) plus the theme `GUISlider` and `vape.GUIBind`.

### `src/games/` — the actual modules

**Naming convention:** in `games/<game>/<PlaceId> - <description>/`, the text before the first ` - ` is the compiled product filename (`universal - base/` → `universal.lua`; `bedwars/6872274481 - game/` → `6872274481.lua`). A product folder is `base.lua` plus per-category subfolders (`Combat/`, `Blatant/`, `Render/`, `Utility/`, `World/`, `Legit/`, `Inventory/`). **The bundler concatenates them into one chunk**, so module files deliberately have no `require` and no `local vape =` — they reuse `base.lua`'s locals, and **everything in one product shares one scope** (§10.5): a new top-level local name must be unique across that whole product, or it silently shadows another file's.

Order inside the chunk is `base.lua` first, then the category files, so a base's top-level code runs *before* its own modules exist — see the `vape:Remove` note in §9.

Current products (module counts are `CreateModule` call sites):

| Product | Modules |
|---|---|
| `universal - base/` → `universal.lua` (always loaded) | 55 (Blatant 16, Combat 5, Render 11, Utility 8, World 1, Legit 14) |
| `bedwars/6872274481 - game` | 69 · `6872265039 - lobby` 2 · 2 redirects |
| `prison life/155615604 - main` | 38 · 1 redirect |
| `jailbreak/606849621 - main` | 24 · 2 redirects |
| `skywars voxel/8768229691 - skywars game` | 16 · 5 redirects |
| `frontlines/5938036553 - game` | 15 · 3 redirects |
| `1.8arena/77790193039862 - game` | 15 · 1 redirect |
| `blocktales/16483433878` | 14 · 1 redirect |
| `bridge duel/139566161526375 - game` | 13 |
| `redliner/115875349872417 - game` | 12 · 2 redirects |
| `132768098780837 - blockwars` | 11 |
| `893973440 - flee the facility` | 7 |

---

## 4. Core `vape` object

Root table (`base.lua:1-22`): `ActiveBinds`, `Categories`, `GUIColor`, `HeldKeybinds`, `Loaded`, `Libraries`, `Modules`, `Place`, `Profile`, `RainbowSliders`, `Settings`, `SettingToggleNotifications`, `ThreadFix`, `ToggleNotifications`, `Version = '4.22'`, `Windows`.

Runtime-added: `vape.gui`, `vape.holder`, `vape.Connections`, `vape.Blur`, `vape.Notifications`, `vape.GUIBind`, `vape.Overlays`, `vape.Legit`, `vape.ProfileLabel`, `vape.Init`, `vape.SearchBar`, `vape.RainbowMode/Speed/UpdateSpeed`.

- **`vape.Loaded` is a three-state sentinel:** `false` → set to `canSave` at end of `Load` → set to **`nil`** by `Uninject`. Modules use `repeat … until vape.Loaded == nil` as the uninject exit condition and `repeat task.wait() until vape.Loaded` to wait for load.
- **`vape.Place`** defaults to `game.PlaceId`; subplace redirect files overwrite it with the parent PlaceId so one save file spans subplaces.
- **`vape.ThreadFix`** — when true, any core-GUI / Instance creation must be preceded by `setthreadidentity(8)`.

`vape:Remove(obj)` looks the name up in `self.Modules`, then `self.Legit.Modules`, then `self.Categories`, and destroys whatever it finds — it never registers a "removed" flag, so it only affects objects that exist at call time.

Methods (`base.lua`): `BlurCheck` :331 · `CreateCategory` :338 · `CreateCategoryList` :342 · `CreateNotification(title, text, duration, 'info'|'warning'|'alert')` :346 · `CreateOverlay` :444 · `Load(skipgui, profile)` :448 · `LoadOptions(obj, data)` :563 · `LoadGUI()` :573 (empty; replaced by init) · `Remove(name)` :577 · `Save(newProfile)` :608 · `SaveOptions(obj)` :642 · `SortCategories` :655 · `Uninject` :675 · `UpdateGUI` :721 · `UpdateGUIQueue(h,s,v)` :735 · `Clean(x)` via `addMaid` :166 (accepts connection / Instance / thread / function).

Defined elsewhere: `vape:UpdateTextGUI(afterload)` (`overlays/TextGUI.lua:322`), `vape:Color(h)`, `vape:TextColor(h,s,v)` (`guis/new/libraries/color.lua`).

Unexported `base.lua` helpers: `run(func)` :24 · `addBlur` :69 · `addCorner` :91 · `addCloseButton` :99 · `addDragHandler` :130 · `addMaid` :166 · `addTooltip` :195 · `createSignal()` :245 · `checkKeybinds` :272 · `getPlayerFromText` :288 · `getTableSize` :298 · `loopClean` :307 · `randomString` :317 · `removeTags` :326 · `loadJson` :59.

Line numbers are from the state this file was written in (`guis/new/base.lua` and `libraries/entity.lua` have not been touched since); re-check before trusting one.

---

## 5. Component system

Bundled form: `components.<Name> = function(props, children, api)` — `props` is the `Create<Name>{...}` table, `children` is the parent GuiObject, `api` is the host (module/category/pane/overlay).

Every container (`Module`, `Category`, `CategoryList`, `GUI`, `SettingsPane`, `Overlay`, `OverlayBar`, `LegitModule`, `LegitWindow`) ends with the same registration block:

```lua
for index, comp in components do
	component['Create'..index] = function(_, props)
		return comp(props, children, component)
	end
end
```

Runtime extension (`base.lua:774-792`): the `vape.Components` metatable retroactively `rawset`s a new `CreateX` onto every *already existing* `vape.Modules` / `vape.Legit.Modules` entry when `components.X` is written.

### Module object (`components/Module.lua:1-10`)

`{Category, Enabled = false, ExtraText, Index, Name, Options = {}, Visible = true}` plus `.Object` (220×40 button), `.Children`, `.Edit`, `.Bind`, `.Connections`. `Module.lua:1` calls `vape:Remove(props.Name)` first, so re-running a chunk hot-reloads cleanly.

props: `Name` (unique = save key), `Function(enabled)` (`task.spawn`ed — never spawn your own thread), `Tooltip`, `ExtraText()`.
methods: `Toggle(multiple)` (flips `Enabled`; on disable disconnects and clears `Connections`, then `task.spawn(props.Function, self.Enabled)`), `SetVisible`, `Load`, `Save`, `Color`, `Destroy`, `Clean`.

### Option components

`<Module>:CreateXxx({...})` returns an option object stored in `module.Options[props.Name]` (exceptions noted).

| Component | Key props | Saved shape |
|---|---|---|
| `CreateTargets` | `Players`, `NPCs`, `Invisible`, `Walls`, `Function` | **hardcoded key `"Targets"`** (ignores `Name`) |
| `CreateToggle` | `Name`, `Default`, `Function`, `Darker`, `Visible` | `{Enabled}` (+ optional `Bind`) |
| `CreateSlider` | `Min`, `Max`, `Default`, `Decimal` (def. 1), `Suffix`, `Function(val, released)` | `{Value, Max}` |
| `CreateTwoSlider` | `Min`, `Max`, `DefaultMin/Max`, `Decimal` | `{ValueMin, ValueMax}` |
| `CreateDropdown` | `List` (**required**), `Default`, `Function(val, isClick)` | `{Value}`; `.Change(list)` hot-swaps |
| `CreateTextBox` | `Default`, `Placeholder`, `Player`, `Function(enter)` | `{Value}` |
| `CreateTextList` | `Default`, `Placeholder`, `Player`, `Color`, `Function(list)` | `{List, ListEnabled}` — logic reads `ListEnabled` |
| `CreateColorSlider` | `DefaultHue/Sat/Value/Opacity`, `Function(h,s,v,o)` | `{Hue, Sat, Value, Opacity, Rainbow}` |
| `CreateBind` | `Hold`, `Default` (e.g. `{'RightShift'}`), `Module`, `Cover`, `NoRemove` | `{Keys, Mobile, Hold}`; module-level bind saves under **`"Bind"`** |
| `CreateFont` / `CreateGUISlider` / `CreateImageToggle` | font picker / theme slider / overlay-bar icon toggle | see component file |
| `CreateButton` / `CreateDivider` | `Name`, `Function` / `Text` | **none — return nil**, not stored |

Option visibility: `<Option>.Object.Visible = bool`. `Visible` is **never saved**, so a sub-option that must appear when a parent is already enabled has to reapply it on module enable too (see `KickExploit`'s Kick Mode / `CheaterDetector`'s Automatic Add children).

**Legit modules** differ only in entry point: `vape.Legit:CreateModule({...})` (43 call sites), extra `Size = UDim2` prop, custom UI parented to `Module.Children`.

**Overlays** (`vape:CreateOverlay({Name, Icon, Size, Position, CategorySize, Function})` → `components/Overlay.lua`) expose `.Button` (OverlayBar ImageToggle), `.Object`, `.Children`, `.Options`, `.Pinned`, `.Expand`, `.Pin`, `.Update`. They live in `vape.Categories` but because `Type == 'Overlay'` they are saved into the **profile** file, not the layout file.

---

## 6. Persistence

Two JSON files, both `v = 1`, written by `vape:Save` (`base.lua:638-639`):

- `newvape/profiles/<game.GameId>.gui.txt` → `{Categories, Profile, v}` — non-overlay category layout/positions.
- `newvape/profiles/<Profile><Place>.txt` → `{Modules, Categories, Legit, v}` — module state + overlay categories. (Plain concatenation, no separator.)

Module entry (`Module.lua:145` + `Bind.lua:176`):

```json
"KillAura": {
  "Enabled": true, "Visible": true,
  "Bind": { "Keys": ["G"], "Mobile": null, "Hold": false },
  "Options": {
    "Mode": { "Value": "Single" },
    "Range": { "Value": 14, "Max": 18 },
    "CPS": { "ValueMin": 8, "ValueMax": 12 },
    "ESP Color": { "Hue": 0.44, "Sat": 1, "Value": 1, "Opacity": 1, "Rainbow": false },
    "Blacklist": { "List": ["a"], "ListEnabled": ["a"] }
  }
}
```

Migration: `v ~= 1` drops `guiData.Categories.Main` and converts legacy single-key binds (`data.Bind = {Keys = data.Bind}; data.Visible = true`). Corrupt JSON degrades to an empty table, fires an `'alert'` notification, and sets `canSave = false`. Options whose module or name no longer exists are ignored on load and drop out of the next save.

Other files: `commit.txt` (pinned remote sha), `asset.txt` (`'1'`), `gui.txt` (`'new'`), `whitelist.json`, `cheaters.json` (per-product cheater list, §9-adjacent), `color.txt` (`{Main, Text, Font}` theme override read by `guis/new/libraries/uipallet.lua`).

---

## 7. `entitylib` and shared libraries

### `src/libraries/entity.lua`

Top-level: `isAlive`, `character` (local entity — **not** in `List`), `List`, `Connections`, `PlayerConnections`, `EntityThreads`, `Running`, `Events`, `IgnoreObject`.

`Events` is a self-creating bus (`__index` lazily builds `{Connections, Connect, Fire, Destroy}`); only **five** events ever fire: `LocalAdded`, `LocalRemoved`, `EntityAdded`, `EntityRemoved`, `EntityUpdated`.

Entity: `Character`, `Humanoid`, `RootPart`, `Head`, `Health`, `MaxHealth`, `HipHeight`, `NPC`, `Player`, `SpawnTime`, `TeamCheck`, `Targetable`, `Connections`. `Friend`/`Target` are **not** set by the library — universal injects them by overriding `getUpdateConnections`.

Overridable hooks: `targetCheck(entity)`, `getUpdateConnections(entity)`, `getEntityColor(entity)`, `isVulnerable(entity)`.
Selectors: `EntityMouse(settings)`, `EntityPosition(settings)`, `AllPosition(settings)`; helpers `Wallcheck(origin, position, ignoreobject)` (**non-nil = blocked**), `getEntity(char)`, `addEntity`, `removeEntity`, `refreshEntity`, `addPlayer`, `removePlayer`, `start`, `stop`, `refresh`, `kill`.

`settings`: `Part` (required, e.g. `'RootPart'`), `Range` (required), `Players`, `NPCs`, `Origin`, `MouseOrigin` (EntityMouse), `Wallcheck`, `Sort`, `Limit` (AllPosition). Flow: skip non-`Targetable` → distance → `isVulnerable` → `Magnitude = entity.Target and -1 or mag` → sort → wallcheck.

**Gotchas:** the settings table is `table.clear`ed before returning — build a fresh table per call. The library auto-calls `start()` at load (`entity.lua:477`), so after overriding hooks you must call `entitylib.start()` again (every game base ends with it). `entity.Targetable` is computed **once per spawn** from `targetCheck(entity)`, so it goes stale until `refreshEntity` runs.

**Per-product hook overrides are the normal extension point** — a game base may widen the signatures and add extra settings keys, and modules then pass them:

- prison life's `base.lua` overrides `AllPosition` and threads a `SkipTeam` setting through it: inclusion becomes `entity.Targetable or (SkipTeam and targetCheck(entity, true))`, and `isVulnerable(entity, attackCheck, skipCheck)` receives the same flag. `targetCheck`'s team branch stays in force for guards, while `skipCheck` drops the guard/inmate protections at the end of `isVulnerable` — that pair is what lets a whitelisted-style "attack teammates" option work per role.
- Guards' innocent-inmate protection, the `Trespassing`/`Hostile` requirement and the `attackCheck` arguments all live in that same overridden `isVulnerable`; read the product's `base.lua` before assuming the library's behaviour.

### How libraries reach modules

universal registers `vape.Libraries.entity/whitelist/prediction/hash/auraanims` (`universal - base/base.lua:242-277`); `overlays/TargetInfo.lua:254` registers `targetinfo`; `Render/SessionInfo.lua:179` registers `sessioninfo`. The GUI-side libraries are globals at the `--Libraries` marker and are also read through `vape.Libraries` (`tween`, `uipallet`, `color`, `getfontbounds`, `getvapeasset`). Game bases therefore open with:

```lua
local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local whitelist = vape.Libraries.whitelist
```

Other library notes:
- `prediction.SolveTrajectory(origin, projectileSpeed, gravity, targetPos, targetVelocity, playerGravity, playerHeight, playerJump, params)` → **aim point `Vector3` or nil** (not a direction).
- `hash`: `sha.md5/sha1/sha224/sha256/sha384/sha512*/sha3_*/shake128/shake256/hmac/hex_to_bin/base64_to_bin/bin_to_base64`, lowercase hex.
- `drawing.lua`: guard `if not get_comm_channel then return '1' end`; otherwise installs `getgenv().Drawing` inside an Actor — always check the return value.
- `getvapeasset(path)`: desktop + `getcustomasset` downloads and caches the png; otherwise falls back to a hardcoded inline table of ~60 `rbxassetid://` entries keyed by `newvape/assets/new/<file>.png`, returning `''` on miss. Assets live in `src/guis/new/assets/` (63 pngs).
- `whitelist:get(plr)` returns `(level, attackable, tags)`; the **second** value is what `targetCheck` reads, and for anyone not on the whitelist it is `true`. `whitelist` is a chunk-local provided by each product's base, so module files may use it directly.

---

## 8. Authoring game modules

A game `base.lua` follows this order: file-top shims → `cloneref` service locals + `gameCamera`/`lplr` → `local vape = shared.vape` + `vape.Libraries.*` → build a `store` state table → wait for the game framework (`require` / `debug.getupvalue` / `getgc`) inside `run(function() … end)` → override `entitylib.*` hooks → grab/hook remotes → `sessioninfo:AddItem(...)` → `vape:Clean(...)` restore functions → `entitylib.start()` → `for _, v in {'Reach', 'Disabler', …} do vape:Remove(v) end` to drop inapplicable universal modules (this works because universal is already loaded; the base's own module files are not yet — see §9).

Module files have **no `require` and no `local vape =`**; they reuse the base chunk's locals (`vape`, `entitylib`, `lplr`, `runService`, `inputService`, `gameCamera`, `store`, `notif`, `getTool`, …).

Canonical structure (`universal - base/Combat/Reach.lua`):

```lua
local Reach
local Targets
local Mode
local Value
local Chance

Reach = vape.Categories.Combat:CreateModule({
	Name = 'Reach',
	Function = function(callback)
		if callback then
			repeat
				-- work; use entitylib.List / entity.Targetable
				task.wait()
			until not Reach.Enabled
		else
			-- restore
		end
	end,
	Tooltip = 'Extends tool attack reach'
})
Targets = Reach:CreateTargets({Players = true})
Mode = Reach:CreateDropdown({Name = 'Mode', List = {'TouchInterest', 'Resize'},
	Function = function(val) Chance.Object.Visible = val == 'TouchInterest' end})
Value = Reach:CreateSlider({Name = 'Range', Min = 0, Max = 2, Decimal = 10})
Chance = Reach:CreateSlider({Name = 'Chance', Min = 0, Max = 100, Default = 100, Suffix = '%'})
```

Large files are easier to navigate when the helper functions and the command/option tables are marked with banner comments (`-- === functions ===` / `-- === commands ===`), which the two `Utility/ChatCommand.lua` copies now do.

### Compatibility shims

Every file re-declares fallbacks for executor-dependent globals, because each file loads as an independent chunk:

```lua
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local isfile = isfile or function(file) ... end
local queue_on_teleport = queue_on_teleport or function() end
local cloneref = cloneref or function(obj) return obj end
```

### Subplace redirect files

Set `vape.Place` to the parent PlaceId, then loadstring that chunk (`bedwars/8444591321 - mega.lua` is the whole file):

```lua
vape.Place = 6872274481
if isfile('newvape/games/'..vape.Place..'.lua') then
	loadstring(readfile('newvape/games/'..vape.Place..'.lua'), 'bedwars')()
else
	if not shared.VapeDeveloper then
		local success, result = pcall(downloadFile, 'newvape/games/'..vape.Place..'.lua')
		if success and result then loadstring(result, 'bedwars')() end
	end
end
```

Some games forward varargs: `loadstring(..., 'frontlines')(...)`. `skywars voxel/8542259458 - skywars lobby.lua` is **not** a redirect — it is a mini base that only registers `sessioninfo` items.

### universal `base.lua` (~925 lines) — what it provides

Shared helpers: `addBlur`, `calculateMoveVector`, `isFriend(plr, recolor)`, `isTarget(plr)`, `canClick()`, `getTableSize`, `getTool()`, `notif(...)`, `removeTags`, `serverHop(pointer, filter)`, `updateVelocity()`, `motorMove(target, cf)`, plus the `SpeedMethods` table (`Velocity`, `Impulse`, `CFrame`, `TP`, `WalkSpeed`, `Pulse`) and `SpeedMethodList`.

Two `run(function() … end)` blocks: (1) `:330+` overrides `entitylib.getUpdateConnections` (injecting `Friend`/`Target`), `targetCheck`, `getEntityColor`, then wires `vape:Clean` for `entitylib.kill()`, Friends/Targets `Update`, `LocalAdded`, camera changes; (2) `:385-925` builds the whitelist system (`whitelist:get/isingame/tag/getplayer/playeradded/process/newchat/oldchat/hook/announce/update` + `whitelist.commands`: `crash`, `deletemap`, `chat`, `framerate`, `gravity`, `jump`, `kick`, `kill`, `reveal`, `shutdown`, `toggle`, `trip`, `uninject`, `void`) with a 10-second poll loop. The file's last line is `entitylib.start()`. universal never calls `vape:Remove` — it is the provider; game bases do.

---

## 9. Known pitfalls

- `base.lua:560` — `vape:Load` ends with `return toggleData`, but `toggleData` is never defined (returns `nil`).
- `base.lua:609` — `Save` early-returns when `not self.Loaded`, so the `self:Save()` inside `Load` on first run is a no-op; the first real write comes from the 10-second loop.
- Module objects have **no `Type` field**, so `vape:Remove`'s `isModule` check (`base.lua:581`) is false for them and `SortCategories` isn't re-run.
- `Targets` options always serialize under the literal key `"Targets"`, ignoring `props.Name`.
- `TwoSlider`'s `props.Function` is never invoked from `SetValue`.
- `entitylib.Events.EntityRemoving` is never fired — use `EntityRemoved`.
- `drawing.lua` returns the string `'1'` when unsupported; `prediction.SolveTrajectory` returns an aim point, `nil` on no solution.
- `bedwars/6872274481 - game/base.lua:33-36` kicks the player on load — BedWars is retired.
- MAKE CHATCOMMAND APPLY BOTH CHATCOMMAND UNLESS ITS A GAME SPECIFIC COMMAND
- **`vape:Remove` timing:** a product's `base.lua` top-level runs before its own category files exist, so a removal written there can only drop modules that a *previously loaded* chunk created (universal for game bases, nothing for universal itself). To drop a module a product defines itself, call it from the module file (or defer it) instead.
- **`Dropdown:SetValue`/profile loads are silent:** a value that is not in `List` falls back to `List[1]` with no error, so a renamed option value quietly becomes the first entry (this is what a stale chat-command alias hits).
- **Always-true `and`/`or` fallbacks:** `Enabled and nil or true` evaluates to `true` in both branches. When a boolean is passed down to a hook, pass the boolean itself.
- **Bundled scope:** every file in a product shares one scope, so two files declaring the same top-level local name silently overwrite each other (and a module file assigning without `local` writes the base's variable — which some base/module pairs rely on).

---

## 10. Code conventions

From `CONTRIBUTING.md` plus observed style:

1. **Tab indentation**, no semicolons.
2. Don't cram multi-arg calls onto one line (except a plain `return`); put arguments on their own lines.
3. Localize aggressively — never index the same field or call the same function twice inside a loop; hoist per-frame constants (vectors, animation ids, tables) to the top of the file.
4. Reproduce the file-top shim block when a new file needs `isfile`/`cloneref`/`queue_on_teleport`/`loadstring`.
5. New modules go in `src/games/<game>/<PlaceId> - <desc>/<Category>/<Name>.lua`, with no `require`, relying on `base.lua` locals — and with a top-level name that is unique inside that product (§9).
6. **Route all cleanup through `vape:Clean(...)` / `<Module>:Clean(...)`**, never raw `:Connect()`.
7. Idioms: `run(function() … end)` for immediately-invoked scoped blocks; module `Function` uses `repeat … task.wait() until not <Module>.Enabled` (the framework already `task.spawn`s it); target filtering chains `Targets.Players.Enabled` / `entity.Targetable` / `entitylib.targetCheck`; `isFriend(plr, recolor)` and `isTarget(plr)` read `vape.Categories.Friends/Targets.ListEnabled`; notifications via `vape:CreateNotification(title, text, duration, 'info'|'warning'|'alert')` (shortcut `notif(...)` inside bases).
8. Option-change hot restart: `if Module.Enabled then Module:Toggle(); Module:Toggle() end`.
9. Cross-file forward declarations: base declares `local Reach = {}` / `local Spider = {Enabled = false}`; the module file assigns **without** `local` (`Reach = vape.Categories.Combat:CreateModule({...})`).
10. Add a heavy, cacheable cross-game library under `src/libraries/` (returns a table, loaded via `downloadFile`); GUI-internal helpers go in `src/guis/new/libraries/` as global assignments.
11. In executor-facing code prefer guarded/type-checked paths (`typeof(x) == 'function'`, `pcall`) over raw calls with live game objects: `pl`-style tables are rebuilt from live closures on re-injection and can hand an executor a number where a function is expected, which takes the whole module down.
12. When asked to optimize, touch **only the code the assistant itself wrote** in that file; the maintainer's and upstream's code stays as-is unless they ask for it explicitly.

---

## 11. Updates thru Discord webhook

1. The tool is `inhaler_send_update.py` (repo root, listed in `.gitignore` — it is a local tool, re-create it if a clone is missing it).
2. Updates are collected in `UPDATES.md`. Running the script converts the file into a JSON embed payload and posts it; **on success the file is deleted**. Do **not** commit `UPDATES.md` — it is generated, consumed and removed.
3. Follow the format in step 4 exactly.
4. Once any inhaler file has been changed, write the changes into `UPDATES.md`:
```md
[%GAMENAME%]
```diff
+ [%CHANGEDFILENAME%] %UPDATE MESSAGE_MODULE/FUNCTIONS/OPTIONS ADDED%
- [%CHANGEDFILENAME%] %UPDATE MESSAGE_MODULE/FUNCTIONS/OPTIONS REMOVED%
~ [%CHANGEDFILENAME%] %UPDATE MESSAGE_MODULE/FUNCTIONS/OPTIONS CHANGED%
```
[%GAMENAME%]
```diff
+ [%CHANGEDFILENAME%] %UPDATE MESSAGE_MODULE/FUNCTIONS/OPTIONS ADDED%
- [%CHANGEDFILENAME%] %UPDATE MESSAGE_MODULE/FUNCTIONS/OPTIONS REMOVED%
~ [%CHANGEDFILENAME%] %UPDATE MESSAGE_MODULE/FUNCTIONS/OPTIONS CHANGED%
```
```
   Entries are **short and meaningful** — one line per changed file saying what actually changed for the user; no long explanations, no restating error text or internal mechanics, no multiple lines per file, get them into 1 line.
5. If it is a Universal update, write it down as `[Universal]` and the update message.
6. If anything is overridden, override the old update message (if there is one) and write the final update message.

Script behaviour worth knowing: `./inhaler_send_update.py <WebhookURL>` (or `WEBHOOK_URL=…`); it looks for `UPDATES.md` in the cwd first, then next to the script (`UPDATES_FILE=…` overrides); `PROXY` defaults to `http://127.0.0.1:7890` (`off`/`none`/empty disables); a block over Discord's 1024-char field limit is split into `Name` / `Name (2)`; a failed send **keeps** the file so it can be sent again, and a successful one removes it; with no `UPDATES.md` it asks for the fields on the terminal (Enter ends a value, shift+enter or a trailing backslash adds a line). Do not post the webhook yourself unless asked — the maintainer normally runs it.
