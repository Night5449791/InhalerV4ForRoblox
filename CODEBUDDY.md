# CODEBUDDY.md This file provides guidance to CodeBuddy when working with code in this repository.

> Repo: `Night5449791/VapeV4ForRoblox` — a fork of Vape V4, a Roblox combat/utility script GUI.
> Runtime target is **Luau inside a Roblox exploit executor** (not standard Lua, not Node).
> `src/` is the human-maintainable source tree; an external bundler flattens it into `Night5449791/VapeCompiled`, which the runtime downloads at injection time.

---

## 1. Commands

### Build

There is **no local build command**. Builds happen only in CI: `.github/workflows/build.yaml` triggers on push to `main`, clones the external `Night5449791/VapeBundler` (not in this repo), copies `.github/workflows/workflowConfig.json` → `VapeBundler/config.json` (`SRC_PATH=./src`, `PROD_PATH=./VapeCompiled`), runs `node ./VapeBundler/index.js prod`, and pushes the flattened output to `VapeCompiled`. Changing bundling behavior requires editing VapeBundler.

### Lint / Test

**None exist.** No selene/stylua/luacheck config, no `package.json`, no Makefile, no test suite anywhere in the repo. Do not invent or add one unless asked. Validate changes by review against the conventions in §12.

### Run / develop locally

Copy files from `src/` into the executor's workspace so they mirror runtime paths, then execute:

```lua
shared.VapeDeveloper = true
loadstring(game:HttpGet("https://raw.githubusercontent.com/Night5449791/VapeV4ForRoblox/main/NewMainScript.lua", true))()
```

`shared.VapeDeveloper = true` (set before load) skips fetching the remote commit sha, skips wiping cached files, and makes the loader read `newvape/loader.lua` from disk instead of downloading — so edits take effect on re-execute. Related globals: `shared.VapeIndependent` (don't auto-inject; `vape.Init` exported for manual `finishLoading`), `shared.VapeCustomProfile` (profile name), `shared.vapereload` (auto-reload after teleport). To test one module, edit under `src/games/<game>/...`, copy to the matching `newvape/games/...` path, re-run the loader.

---

## 2. Boot chain

1. **`NewMainScript.lua` / `loadstring`** — one-line user entry; HTTP GETs the loader and runs it. Byte-identical to `src/loader.lua`.
2. **`src/loader.lua`** (68 lines) — filesystem bootstrap only. Defines `isfile`/`delfile` fallbacks and `downloadFile(path, func)`, which caches from `raw.githubusercontent.com/Night5449791/VapeCompiled/<commit>/<path>`. Creates `newvape/{games,profiles,assets,libraries,guis}`. Resolves the remote commit by parsing `currentOid` off the GitHub page into `newvape/profiles/commit.txt`. Ends with `loadstring(downloadFile('newvape/main.lua'), 'main')()`.
   **Cache watermark:** every downloaded `.lua` is prefixed with `--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.` `wipeFolder()` deletes cached files still carrying it (except `loader`). Preserve this when touching loader logic.
3. **`src/main.lua`** (111 lines) — the assembler: `repeat task.wait() until game:IsLoaded()` → `shared.vape:Uninject()` if reloading → load `newvape/guis/<gui>.lua` into `shared.vape` (gui name is hardcoded `'new'`) → load `newvape/games/universal.lua` unconditionally → load `newvape/games/<game.PlaceId>.lua` if present → `finishLoading()`.
   `finishLoading()` runs `vape:Load()`, spawns a 10-second `vape:Save()` loop, and hooks `OnTeleport` to `queue_on_teleport` a re-injection script (carrying `VapeDeveloper`/`VapeCustomProfile`/`vapereload`).

**`shared.vape` is the single global anchor** — every downstream file starts with `local vape = shared.vape`.

---

## 3. Source layout and the bundler model

Three layers under `src/`, all loaded at runtime as independent chunks:

### `src/libraries/` — 5 standalone chunks, each `return <table>`

Loaded via `loadstring(downloadFile('newvape/libraries/<name>.lua'), ...)()` and usually registered into `vape.Libraries`.

| File | Returns | Used by |
|---|---|---|
| `entity.lua` | `entitylib` — player/NPC tracking | universal + most games |
| `hash.lua` | `sha` — MD5/SHA1/SHA2/SHA3/HMAC | universal, GetHash, Spotify |
| `prediction.lua` | `module` — projectile ballistics | SilentAim, ProjectileAimbot |
| `drawing.lua` | id / `'1'` / nil — Actor comm-channel Drawing bridge | frontlines, redliner |
| `vm.lua` | Fiu Luau bytecode VM | jailbreak |

### `src/guis/new/` — the single GUI

`base.lua` (796 lines) defines the root `vape` table and every `vape:*` method. **It is not self-contained** — the bundler inlines other files at three marker comments:

| Marker | Line | Injected content |
|---|---|---|
| `--Libraries` | `base.lua:67` | `libraries/*.lua`, emitted as **global** assignments (`uipallet = {...}`, `color`, `tween`, `getfontbounds`, `getvapeasset`) |
| `--Components` | `base.lua:772` | `components/*.lua` + `overlays/*.lua`, each wrapped as `components.<Name> = function(props, children, api)` |
| `--Init` | `base.lua:574` (empty body of `vape:LoadGUI()`) | `init.lua` in full — which is why `self`/`vape` works inside it |

So `newvape/guis/new.lua` = base + libraries + components + overlays + init. All GUI upvalues (`gui`, `clickgui`, `scaledgui`, `notifications`, `tooltip`, `toolblur`, `scale`, `components`, `TextGUI`) are assigned inside `init.lua`.

- `init.lua` builds the ScreenGui, registers the 6 categories, then Friends/Targets/Profiles lists, `LegitWindow`, `SearchBar`, `OverlayBar`, and 4 settings panels (General/Modules/GUI/Notifications).
- `components/` — 26 widget files. `overlays/` — `TargetInfo.lua`, `TextGUI.lua`. `assets/*.png` land at `newvape/assets/new/`.

### `src/games/` — 330 files of actual modules

**Naming convention:** in `games/<game>/<PlaceId> - <description>/`, the text before the first ` - ` is the compiled product filename (`universal - base/` → `universal.lua`; `bedwars/6872274481 - game/` → `6872274481.lua`).

A game folder is `base.lua` plus per-category subfolders (`Combat/`, `Blatant/`, `Render/`, `Utility/`, `World/`, `Legit/`, …). **The bundler concatenates them into one chunk**, so module files deliberately have no `require` and no `local vape =` — they reuse `base.lua`'s locals.

### Game → product mapping

| Game dir | Products |
|---|---|
| `universal - base/` | `universal.lua` (70 modules, always loaded) |
| `bedwars/` | `6872265039.lua` (lobby, 2), `6872274481.lua` (game, 69) + 2 subplace redirects |
| `jailbreak/` | `606849621.lua` (24) + 2 redirects |
| `prison life/` | `155615604.lua` (39) + 1 redirect |
| `frontlines/` | `5938036553.lua` (15) + 3 redirects |
| `blocktales/` | `16483433878.lua` (11) + 1 redirect |
| `skywars voxel/` | `8768229691.lua` (14) + 5 redirects |
| `1.8arena/` | `77790193039862.lua` (14) + 1 redirect |
| `bridge duel/` | `139566161526375.lua` (13) |
| `redliner/` | `115875349872417.lua` (11) + 2 redirects |
| `132768098780837 - blockwars/` | `132768098780837.lua` (11) — no subplace layer |
| `893973440 - flee the facility/` | `893973440.lua` (7) — no subplace layer |

**Duplicate module names across universal and a game are intentional**: `CreateModule` calls `vape:Remove(props.Name)` first, and `main.lua` loads `universal.lua` **before** `<PlaceId>.lua`, so a game file with the same `Name` silently replaces the universal one. Do not keep two copies of the same module name — move what is truly generic into `universal - base/` and detect game features at runtime (e.g. `vape.Modules.KickExploit`).

---

## 4. Core `vape` object

### Root table (`base.lua:1-22`)

```lua
local vape = {
	ActiveBinds = {}, Categories = {}, GUIColor = {Hue = 0.46, Sat = 0.96, Value = 0.52},
	HeldKeybinds = {}, Loaded = false, Libraries = {}, Modules = {}, Place = game.PlaceId,
	Profile = 'default', RainbowSliders = {}, Settings = {}, SettingToggleNotifications = {},
	ThreadFix = setthreadidentity and true or false, ToggleNotifications = {},
	Version = '4.22', Windows = {}
}
```

Runtime-added fields: `vape.gui`, `vape.holder`, `vape.Connections`, `vape.Blur`, `vape.Notifications`, `vape.GUIBind`, `vape.GUIColor` (overwritten by the theme GUISlider at `init.lua:545`), `vape.RainbowMode/Speed/UpdateSpeed`, `vape.Overlays`, `vape.Legit`, `vape.ProfileLabel`, `vape.Init`, `vape.SearchBar`.

**`vape.Loaded` is a three-state sentinel:** `false` (initial) → set to `canSave` at end of `Load` → set to **`nil`** by `Uninject`. Game scripts universally use `repeat … until vape.Loaded == nil` / `if vape.Loaded == nil then return end` as the uninject exit condition, and `repeat task.wait() until vape.Loaded` to wait for load completion.

**`vape.Place`** defaults to `game.PlaceId` but subplace redirect files overwrite it with the parent game's PlaceId, so one save file spans subplaces.

**`vape.ThreadFix`** — when true, every operation touching core GUI / Instance creation must be preceded by `setthreadidentity(8)`.

### Methods

| Method | Line | Notes |
|---|---|---|
| `vape:BlurCheck()` | 331 | Syncs core-GUI focus with `vape.Blur.Enabled` |
| `vape:CreateCategory(props)` | 338 | → `components.Category(props)` |
| `vape:CreateCategoryList(props)` | 342 | → `components.CategoryList(props)` (Friends/Targets/Profiles) |
| `vape:CreateNotification(title, text, duration, type)` | 346 | type ∈ `info`/`warning`/`alert`; no-op if `self.Notifications.Enabled` is false |
| `vape:CreateOverlay(props)` | 444 | → `components.Overlay(props)` |
| `vape:Load(skipgui, profile)` | 448 | Reads both profile files, loads Categories→Modules→Legit, `UpdateTextGUI(true)` |
| `vape:LoadOptions(obj, data)` | 563 | Dispatches saved data into `obj.Options[name]:Load()` |
| `vape:LoadGUI()` | 573 | Empty body — replaced by `init.lua` |
| `vape:Remove(name)` | 577 | Destroys a module/category/overlay by name; used for hot-reload and to drop inapplicable universal modules |
| `vape:Save(newProfile)` | 608 | Early-returns unless `self.Loaded`; writes both files |
| `vape:SaveOptions(obj)` | 642 | Collects `Save` from every entry in `obj.Options` |
| `vape:SortCategories()` | 655 | Alphabetical `LayoutOrder` per category, sets `module.Index` |
| `vape:Uninject()` | 675 | Save → `Loaded = nil` → disable all modules → disconnect all `Clean`ed connections → destroy GUI → clear `shared.*` |
| `vape:UpdateGUI()` | 721 | Per-frame debounced color refresh |
| `vape:UpdateGUIQueue(hue, sat, val)` | 735 | Broadcasts color to TextGUI → categories → modules → overlay options → settings panes → legit modules |
| `vape:Clean(x)` | via `addMaid` (`base.lua:166`) | Accepts `RBXScriptConnection`, `Instance`, `thread`, or function |

Other methods defined elsewhere: `vape:UpdateTextGUI(afterload)` (`overlays/TextGUI.lua:322`), `vape:Color(h)`, `vape:TextColor(h,s,v)` (`libraries/color.lua`).

### Helpers in `base.lua` (not exported)

`run(func)` `:24` immediate-invoke wrapper · `addBlur(parent, notif, old)` `:69` · `addCorner(parent, radius)` `:91` · `addCloseButton(parent, mini, offset)` `:99` · `addDragHandler(gui, window)` `:130` (drag from top 40px; Shift snaps to 3px grid) · `addMaid(obj)` `:166` · `addTooltip(gui, text, customText, visCheck)` `:195` · `createSignal()` `:245` (`Connect` returns `{Disconnect}`, `Fire` uses `task.spawn`) · `checkKeybinds(compare, target, key)` `:272` · `getPlayerFromText(text)` `:288` · `getTableSize(dict)` `:298` · `loopClean(obj)` `:307` · `randomString()` `:317` · `removeTags(text)` `:326`.

---

## 5. Component system

Bundled form: `components.<Name> = function(props, children, api)` where `props` is the `Create<Name>{...}` table, `children` is the parent GuiObject, and `api` is the host (module/category/pane/overlay).

**Container registration block** — identical in `Module`, `Category`, `CategoryList`, `GUI`, `SettingsPane`, `Overlay`, `OverlayBar`, `LegitModule`, `LegitWindow`:

```lua
for index, comp in components do
	component['Create'..index] = function(_, props)
		return comp(props, children, component)
	end
end
```

**Runtime extension** via `vape.Components` metatable (`base.lua:774-792`): writing a new `components.X` retroactively `rawset`s `CreateX` onto every *already existing* `vape.Modules` and `vape.Legit.Modules` entry.

### Module object (`components/Module.lua:2-10`)

```lua
local component = {
	Category = api.Name, Enabled = false, ExtraText = props.ExtraText,
	Index = getTableSize(vape.Modules), Name = props.Name, Options = {}, Visible = true
}
```
Later: `.Object` (220×40 button), `.Children` (option container), `.Edit`, `.Bind`, `.Connections`.

- props: `Name` (unique key = save key; `vape:Remove(props.Name)` runs first), `Function(enabled)` (`task.spawn`ed; defaults to `function() end`), `Tooltip`, `ExtraText()` (string shown greyed in Text GUI).
- methods: `Toggle(multiple)` (flips `Enabled`; when disabling, disconnects+clears `Connections`; then `task.spawn(props.Function, self.Enabled)`), `SetVisible(isVisible, isLoad)`, `Load(data)`, `Save(data)`, `Color(h,s,v,isRainbow)`, `Destroy()`, `Clean(callback)`.
- Left click toggles; right click / dots expands options. A module-level `Bind` is auto-created (`CreateBind({Module = true, Cover = true})`).
- Registers `vape.Modules[props.Name] = component` then `vape:SortCategories()` at `:348-349`.

### Option components

All are `<Module>:CreateXxx({...})`, return an option object registered into `module.Options[props.Name]`.

| Component | props | Saved shape | Notes |
|---|---|---|---|
| `CreateTargets` | `Players`, `NPCs`, `Invisible`, `Walls`, `Function` | **hardcoded key `"Targets"`** → `{Players, NPCs, Invisible, Walls}` | `.Players`/`.NPCs`/`.Invisible`/`.Walls` sub-objects |
| `CreateToggle` | `Name`, `Default`, `Function(enabled)`, `Tooltip`, `Darker`, `Visible` | `{Enabled}` | 30px; read `.Enabled` |
| `CreateSlider` | `Name`, `Min`, `Max`, `Default`, `Decimal` (default 1), `Suffix` (string or `function(val)`), `Function(val, released)` | `{Value, Max}` | 50px; `.Value`, `.SetValue()` |
| `CreateTwoSlider` | `Min`, `Max`, `DefaultMin`, `DefaultMax`, `Decimal` | `{ValueMin, ValueMax}` | `.ValueMin/.ValueMax`, `.GetRandomValue()` |
| `CreateDropdown` | `Name`, `List` (**required**), `Default`, `Function(val, isClick)` | `{Value}` | `.SetValue()` coerces invalid → `List[1]`; `.Change(list)` hot-swaps |
| `CreateTextBox` | `Name`, `Default`, `Placeholder`, `Player`, `Function(enter)` | `{Value}` | `enter` true only on `FocusLost` |
| `CreateTextList` | `Name`, `Default`, `Placeholder`, `Player`, `Color`, `TextFunction`, `Function(list)` | `{List, ListEnabled}` | `List` = all entries, `ListEnabled` = active ones (business logic reads `ListEnabled`) |
| `CreateColorSlider` | `Name`, `DefaultHue/Sat/Value/Opacity`, `Function(h,s,v,o)` | `{Hue, Sat, Value, Opacity, Rainbow}` | `.Hue/.Sat/.Value/.Opacity/.Rainbow`; double-click toggles rainbow |
| `CreateBind` | `Name`, `Hold`, `Default` (e.g. `{'RightShift'}`), `Module`, `Cover`, `NoRemove` | `{Keys, Mobile, Hold}`; module-level bind lands on key **`"Bind"`** | `.Triggered` signal, `.SetBind(keys, mouse)` |
| `CreateFont` | `Name`, `Default`, `Function(Font)` | via internal Dropdown | `.Value` is a Roblox `Font` |
| `CreateGUISlider` | `Name`, `Function(h,s,v)` | `{Hue, Sat, Value, Notch, CustomColor, Rainbow}` | Main theme control |
| `CreateImageToggle` | `Name`, `Icon`, `Size`, `Position`, `Default`, `Function` | none | 40px |
| `CreateButton` | `Name`, `Function` | none | **returns nil**, not stored |
| `CreateDivider` | `Text` | none | **returns nil** |
| `CreateSettingsPane` | `Name`, `Main` | `data[Name] = SaveOptions` | registers `vape.Settings[Name]` |
| `CreateOverlayBar` | — | — | registers `vape.Overlays` |

**Option visibility** is controlled with `<Option>.Object.Visible = bool`.

### Legit modules

Only the entry point and container differ: `vape.Legit:CreateModule({...})` instead of `vape.Categories.<X>:CreateModule`. They support an extra `Size = UDim2.fromOffset(w, h)` prop and custom UI is parented to `Module.Children`. Everything else (`Function`, `Tooltip`, all `CreateXxx` options) is identical. 43 call sites across universal, bedwars, jailbreak, prison life, frontlines, redliner, blockwars, skywars.

### Overlays

`vape:CreateOverlay({Name, Icon, Size, Position, CategorySize, Function})` → object with `.Button` (ImageToggle in the OverlayBar), `.Object`, `.Children` (custom UI parent, assigned at `Overlay.lua:241`), `.Options`, `.Pinned`, `.Expand(visCheck)`, `.Pin()`, `.Update()`, `.Load/.Save`. Overlays register into `vape.Categories` but because `Type == 'Overlay'` they are saved into the **profile** file, not the GUI-layout file.

---

## 6. Persistence

Two JSON files, both with `v = 1`:

- `newvape/profiles/<game.GameId>.gui.txt` → `{Categories = {}, Profile = <name>, v = 1}` — non-overlay category layout/positions.
- `newvape/profiles/<Profile><Place>.txt` → `{Modules = {}, Categories = {}, Legit = {}, v = 1}` — module state plus overlay categories. (Path is plain concatenation, no separator.)

Module entry shape (`Module.lua:145` + `Bind.lua:176`):

```json
"KillAura": {
  "Enabled": true, "Visible": true,
  "Bind": { "Keys": ["G"], "Mobile": null, "Hold": false },
  "Options": {
    "Mode":  { "Value": "Single" },
    "Range": { "Value": 14, "Max": 18 },
    "CPS":   { "ValueMin": 8, "ValueMax": 12 },
    "ESP Color": { "Hue": 0.44, "Sat": 1, "Value": 1, "Opacity": 1, "Rainbow": false },
    "Blacklist": { "List": ["a"], "ListEnabled": ["a"] }
  }
}
```

Migration: `v ~= 1` drops the old GUI layout and converts legacy single-key binds (`data.Bind = {Keys = data.Bind}; data.Visible = true`). Corrupt JSON degrades to an empty table, fires an `'alert'` notification, and sets `canSave = false`.

Other files: `newvape/profiles/commit.txt` (pinned remote sha), `asset.txt` (`'1'`), `gui.txt` (literal `'new'`), `whitelist.json`, `color.txt` (theme override `{Main, Text, Font}`).

---

## 7. `entitylib` API (`src/libraries/entity.lua`)

Top-level: `isAlive`, `character` (local player entity — **not** in `List`), `List` (all non-local entities), `Connections`, `PlayerConnections`, `EntityThreads`, `Running`, `Events`, `IgnoreObject`.

`entitylib.Events` is a self-creating event bus (`__index` lazily makes `{Connections, Connect, Fire, Destroy}`). Only **five** events ever fire: `LocalAdded`, `LocalRemoved`, `EntityAdded`, `EntityRemoved`, `EntityUpdated`. (`EntityRemoving` is used by some modules but never fired — a latent bug.)

Entity object shape: `Character`, `Humanoid`, `RootPart` (= `HumanoidRootPart`), `Head`, `Health`, `MaxHealth`, `HipHeight`, `NPC`, `Player`, `SpawnTime`, `TeamCheck`, `Targetable`, `Connections`. `Friend`/`Target` are **not** set by the library — games inject them by overriding `getUpdateConnections`.

Methods:

| Method | Signature | Purpose |
|---|---|---|
| `targetCheck` | `(entity) → bool` | Default team check; result written to `entity.Targetable` |
| `getUpdateConnections` | `(entity) → {signal...}` | Default: Health/MaxHealth changed signals; games override to add Friend/Target |
| `isVulnerable` | `(entity) → bool` | `Health > 0` and no ForceField |
| `getEntityColor` | `(entity) → Color3?` | Team colour or nil |
| `Wallcheck` | `(origin, position, ignoreobject) → RaycastResult?` | **non-nil = blocked**; `true` uses default ignore list, table appends, Instance is used as RaycastParams |
| `EntityMouse` | `(settings) → entity?` | Nearest by screen distance |
| `EntityPosition` | `(settings) → entity?` | Nearest by world distance |
| `AllPosition` | `(settings) → {entity...}` | Sorted list, honouring `Limit` |
| `getEntity` | `(char) → entity?, index?` | Accepts a Player or a Model |
| `addEntity` | `(char, plr, teamfunc, spawntime)` | Assembles entity in a thread |
| `removeEntity` | `(char, isLocal)` | |
| `refreshEntity` | `(char, plr, spawntime)` | Preserves `TeamCheck`; used on respawn/team change |
| `addPlayer` / `removePlayer` | `(plr)` | Wire CharacterAdded/Removing/Team |
| `start` / `stop` / `kill` / `refresh` | `()` | `kill()` destroys everything permanently |

`settings` table for the three selectors — `Part` (required, e.g. `'RootPart'`/`'Head'`), `Range` (required), `Players`, `NPCs`, `Origin`, `MouseOrigin` (EntityMouse only), `Wallcheck`, `Sort`, `Limit` (AllPosition only). Flow: skip non-Targetable → distance filter → `isVulnerable` → `Magnitude = entity.Target and -1 or mag` (targets always win) → sort → wallcheck → return.

**Gotchas:** the settings table is `table.clear`ed before returning, so build a fresh table every call; `entitylib` auto-calls `start()` at load (`entity.lua:477`), so after overriding hooks you must call `entitylib.start()` again (done at the end of every game base).

Typical usage (`universal - base/Combat/SilentAim.lua:50`):

```lua
local entity = entitylib['Entity'..Mode.Value]({
	Range = Range.Value,
	Wallcheck = Target.Walls.Enabled and (obj or true) or nil,
	Part = targetPart,
	Origin = origin,
	Players = Target.Players.Enabled,
	NPCs = Target.NPCs.Enabled
})
```

### Other libraries

- `prediction.SolveTrajectory(origin, projectileSpeed, gravity, targetPos, targetVelocity, playerGravity, playerHeight, playerJump, params)` → **aim point** `Vector3` or `nil` (not a direction). Also `solveQuartic`.
- `hash`: `sha.md5/sha1/sha224/sha256/sha512_224/sha512_256/sha384/sha512/sha3_*/shake128/shake256/hmac/hex_to_bin/base64_to_bin/bin_to_base64` — lowercase hex output.
- `drawing.lua`: guard `if not get_comm_channel then return '1' end`; returns a host id or installs `getgenv().Drawing` inside an Actor. Provides Base/Line/Text/Image/Circle/Square/Quad/Triangle.
- `vm.lua`: `{luau_newsettings, luau_validatesettings, luau_deserialize, luau_load}`.
- `json.lua`: `jsonlib.read(path)`, `jsonlib.write(path, content)`.

### Shared library access

universal registers `vape.Libraries.entity`, `.whitelist`, `.prediction`, `.hash`, `.auraanims`; GUI-side `uipallet`, `color`, `tween`, `getfontbounds`, `getvapeasset` are bundler globals also reachable via `vape.Libraries`. `targetinfo` comes from `overlays/TargetInfo.lua:254`, `sessioninfo` from `Render/SessionInfo.lua`. Game base files therefore open with:

```lua
local vape = shared.vape
local tween = vape.Libraries.tween
local targetinfo = vape.Libraries.targetinfo
local getvapeasset = vape.Libraries.getvapeasset
```

---

## 8. GUI library globals (from `--Libraries` injection)

- `uipallet` — `{Main, Text, Font, FontSemiBold, Tween}`, overridable from `newvape/profiles/color.txt`.
- `color` — `color.Dark(col, num)`, `color.Light(col, num)`, plus `vape:Color(h)` / `vape:TextColor(h,s,v)`.
- `tween` — `tween:Tween(instance, TweenInfo, goalTable, groupName?)`; group defaults to `'tweens'`; cancels the previous tween on the same object; applies the end value instantly if the object is invisible/unparented. `tween:Cancel(obj, index)`.
- `getfontbounds(text, size, font)` → `Vector2`.
- `getvapeasset(path)` — desktop with `getcustomasset`: downloads and caches the png then returns the custom asset; otherwise looks up a hardcoded inline table of 61 `rbxassetid://` entries keyed by `newvape/assets/new/<file>.png`, returning `''` on miss.

---

## 9. Authoring game modules

A game base follows: wait for the game framework (`require` / `debug.getupvalue` / `getgc`) → build a `store` state table → override `entitylib.*` hooks → grab/hook remotes → `sessioninfo:AddItem(...)` → `entitylib.start()` → `vape:Remove(...)` inapplicable universal modules → register `vape:Clean` restore functions.

A module file has **no `require` and no `local vape =`**; it reuses the base chunk's locals (`vape`, `entitylib`, `lplr`, `runService`, `inputService`, `gameCamera`, `store`, `notif`, `getTool`, …).

Canonical structure (`universal - base/Combat/Reach.lua`):

```lua
local Reach
local Targets
local Mode
local Value
local Chance
local Overlay = OverlapParams.new()
local modified = {}

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

Minimal module (`World/GetHash.lua`, full file):

```lua
local GetHash

GetHash = vape.Categories.World:CreateModule({
	Name = 'GetHash',
	Function = function(callback)
		if callback then
            local data = lplr.Name..lplr.UserId
			setclipboard(hash and hash.sha512(data..'SelfReport') or '')
		end
	end
})
```

### Subplace redirect files

Set `vape.Place` to the parent game's PlaceId, then loadstring that chunk:

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

Some games forward varargs: `loadstring(..., 'frontlines')(...)`. Note `skywars voxel/8542259458 - skywars lobby.lua` is **not** a redirect — it is a mini base that only registers `sessioninfo` items.

### universal `base.lua` (940 lines) — what it provides

Helpers shared by every universal module and every game: `addBlur`, `calculateMoveVector`, `isFriend(plr, recolor)`, `isTarget(plr)`, `canClick()`, `getTableSize`, `getTool()`, `notif(...)`, `removeTags`, `serverHop(pointer, filter)`, `updateVelocity()`, `motorMove(target, cf)`, plus the `SpeedMethods` table.

Two `run(function() … end)` blocks: (1) `:330-383` overrides `entitylib.getUpdateConnections` (injecting `Friend`/`Target`), `entitylib.targetCheck`, `entitylib.getEntityColor`, then wires `vape:Clean` for `entitylib.kill()`, Friends/Targets `Update` events, `LocalAdded`, and camera changes; (2) `:385-939` builds the whitelist system — `whitelist:get/isingame/tag/getplayer/playeradded/process/newchat/oldchat/hook/announce/update` and `whitelist.commands` (`crash`, `deletemap`, `framerate`, `gravity`, `jump`, `kick`, `kill`, `reveal`, `shutdown`, `toggle`, `trip`, `uninject`, `void`), with a 10-second poll loop. The file's last line is `entitylib.start()`.

Universal also ships `Utility/ChatCommand.lua` — the `.`-prefixed chat command module (`.tp`, `.follow`, `.unfollow`, `.view`, `.unview`, `.wl`, `.unwl`, `.target`, `.untarget`, `.team`, `.kick`, `.hop`, `.rj`, `.reload`, `.help`). Each command is gated by its own toggle option, and game-specific bridges are detected rather than assumed: `.kick` requires `vape.Modules.KickExploit`, `.team` requires a matching `Teams` child plus `ReplicatedStorage.Remotes.RequestTeamChange`. Keep it game-agnostic — anything that needs a game's own runtime table belongs in that game's folder.

universal never calls `vape:Remove` — it is the provider. Game bases do.

---

## 10. Compatibility shims

Every file re-declares fallbacks for executor-dependent globals because files load as independent chunks:

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
followed by `cloneref(game:GetService(...))` service locals, `gameCamera`, `lplr`.

---

## 11. Known pitfalls

- `base.lua:560` — `vape:Load()` ends with `return toggleData`, but `toggleData` is never defined; it returns `nil`.
- `base.lua:609` — `Save` early-returns when `not self.Loaded`, so the `self:Save()` call inside `Load` on first run is a no-op; the first real write comes from the 10-second loop in `main.lua`.
- Module objects have **no `Type` field**, so `vape:Remove`'s `isModule` check (`base.lua:581`) is false for them and `SortCategories` isn't re-run there.
- `Targets` options always serialize under the literal key `"Targets"`, ignoring `props.Name`.
- `TwoSlider`'s `props.Function` is never invoked from `SetValue`.
- `entitylib.Events.EntityRemoving` is never fired (use `EntityRemoved`).
- `drawing.lua` returns the string `'1'` when unsupported — callers must check the return value.
- Download URLs are inconsistent: `src/loader.lua`, `src/main.lua`, `src/guis/new/init.lua`, `getvapeasset.lua` and every game base use `raw.githubusercontent.com/7GrandDadPGN/VapeCompiled/...`, while `NewMainScript.lua` (the fork entry point) and the CI destination are `Night5449791/VapeCompiled`. A commit sha written by one is not guaranteed to resolve against the other — pick one origin for all files before relying on reinject/teleport reload.
- Inside a module's option callbacks, never assume a `module` local exists — only the module variable declared at the top of the file (or `vape.Modules.X`) resolves. This pattern caused two `attempt to index nil` crashes in `prison life/World/KickExploit.lua`.
- `prediction.SolveTrajectory` returns an aim point, and `nil` on no solution.
- `bedwars/6872274481 - game/base.lua:33-36` currently kicks the player — BedWars is retired.

---

## 12. Code conventions

From `CONTRIBUTING.md` plus observed style:

1. **Tab indentation**, no semicolons, no spaces-for-tabs.
2. Don't cram multi-arg calls onto one line (except a plain `return`); put arguments on their own lines.
3. Localize aggressively — never index the same field or call the same function twice inside a loop.
4. Reproduce the file-top shim block when a new file needs `isfile`/`cloneref`/`queue_on_teleport`/`loadstring`.
5. New modules go in `src/games/<game>/<PlaceId> - <desc>/<Category>/<Name>.lua`, with no `require`, relying on `base.lua` locals.
6. **Route all cleanup through `vape:Clean(...)` / `<Module>:Clean(...)`**, never raw `:Connect()`.
7. Idioms: `run(function() … end)` for immediately-invoked scoped blocks; module `Function` uses `repeat … task.wait() until not <Module>.Enabled` (the framework already `task.spawn`s it — do not spawn your own thread); target filtering chains `Targets.Players.Enabled` / `entity.Targetable` / `entitylib.targetCheck`; `isFriend(plr, recolor)` and `isTarget(plr)` read `vape.Categories.Friends/Targets.ListEnabled`; notifications via `vape:CreateNotification(title, text, duration, 'info'|'warning'|'alert')` (shortcut `notif(...)` inside universal and game bases).
8. Option-change hot restart: `if Module.Enabled then Module:Toggle(); Module:Toggle() end`.
9. Cross-file forward declarations: base declares `local Reach = {}` / `local Spider = {Enabled = false}`, and the module file assigns **without** `local` (`Reach = vape.Categories.Combat:CreateModule({...})`).
10. Add a heavy, cacheable cross-game library under `src/libraries/` (returns a table, loaded via `downloadFile`); GUI-internal helpers go in `src/guis/new/libraries/` as global assignments.

Vape V3-era APIs found in older forks — `runFunction`, `GuiLibrary.ObjectsThatCanBeSaved` — **do not exist here**. Use `vape.Categories` / `vape.Modules` / `run`.
