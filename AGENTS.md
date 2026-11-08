# AGENTS.md

Guidance for any AI agent (Claude, Codex, Gemini, Copilot, Cursor, …) working in this repository. This file is the single source of truth — `CODEBUDDY.md` only points here. Section numbers are referenced from other docs — keep them stable.

## 0. What this repo is

`Night5449791/InhalerV4ForRoblox` — a fork of Vape V4, a Roblox combat/utility script. The runtime is **Luau inside an executor** (Synapse-like), not standard Lua and not Node. `src/` is the only editable source; an external bundler flattens it into `Night5449791/InhalerCompiled`, which the loader downloads at injection time. The fork is CC BY 4.0, upstream CC0 1.0.

Rules for agents:

- Read a file before changing it. Never replace code you have not read.
- Change only what was asked. No drive-by refactors, no new tooling (there is no lint/formatter/test suite and one must not be added unless asked).
- Match the surrounding style: tabs, no semicolons, no collapsed multi-argument calls.
- After changing any Inhaler file, append an `UPDATES.md` entry (§11).

## 1. Commands

The Vape build happens only in CI. `.github/workflows/build.yaml` triggers on push to `main` only (`on.push.branches`, no `pull_request`, no `workflow_dispatch`) and has a single `build` job — there is **no** `verify` job and no `needs:` gate. It clones this repo, `InhalerCompiled` and `InhalerBundler`; moves `.github/workflows/workflowConfig.json` to `InhalerBundler/config.json` (`SRC_PATH=./src`, `PROD_PATH=./InhalerCompiled`, `DEV_PATH=""`); runs `npm i`; runs `node ./InhalerBundler/index.js prod` (Node 24.15.0); then commits and pushes the output. Bundling rules live in InhalerBundler, not here.

There is no lint, formatter or test suite (no selene/stylua config, no `package.json`, no Makefile). The only check available is a syntax-only parse of one file — rewrite Luau-only spellings, then parse with Lua 5.4:

```bash
sed -E -e 's/[[:space:]]+continue([[:space:]]|$)/ break\1/g' \
       -e 's/([A-Za-z_][A-Za-z0-9_.]*) ([+-])= /\1 = \1 \2 /g' FILE.lua > /tmp/check.lua \
  && luac -p /tmp/check.lua && echo "syntax OK"
```

Running the script needs a Roblox executor. Mirror `src/` into its workspace so paths match runtime `newvape/...`, then:

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

`src/libraries/` — standalone chunks returning a table, fetched as `newvape/libraries/<name>.lua`: `entity.lua` (`entitylib`), `hash.lua` (`sha`), `prediction.lua`, `vm.lua` (Fiu VM; jailbreak), `drawing.lua` (Actor bridge; frontlines, redliner), `webhook.lua` (Discord poster, loaded through `pcall`), `backend.lua` (Inhaler worker transport, see below; loaded only by the universal base, never by `main.lua`).

`backend.lua` is a **factory**: `loadstring(downloadFile('newvape/libraries/backend.lua'), 'backend')()` returns a constructor which the universal base calls with `{vape, whitelist, lplr, httpService, isfile, entitylib}` (`universal - base/base.lua:1009`). The resulting table exposes `start`, `stop`, `beat`. It owns everything that talks to the Cloudflare worker `inhalerbackendworker.itsrealnight1983.workers.dev` (`InhalerBackendWorker` in this workspace): `/api/activity/session` mints the session key (an older worker without that route falls back to a locally generated secret so an un-updated worker does not brick an updated client), `/api/activity/beat` is the heartbeat, a websocket replaces the beat when the executor has one (worker-owned retry budget `wsAttempts`/`wsDelay`, close code 4401 means the key went stale and `refreshKey` is forced), `/api/activity/chat` relays chat and `;execute`, `/api/activity/skidlist` mirrors the owner's cheater list read-only. Command implementations stay in the universal base; `vape:Clean` calls `backend:stop()` and clears `whitelist.commands`/`whitelist.data`. The file header states it "shouldn't appear from any of Inhaler's forks" and that removing it stops Inhaler working — treat it as required infrastructure, not an optional library.

`src/guis/new/` — the only GUI. `base.lua` defines `vape` and every `vape:*` method but is not self-contained: the bundler inlines files at three markers — `--Libraries` (:67, `guis/new/libraries/*` as globals), `--Init` (:574, the body of `vape:LoadGUI()`, i.e. `init.lua`), `--Components` (:772, `components/*` plus `overlays/*` wrapped as `components.<Name> = function(props, children, api)`). It ends with `return vape`. `init.lua` builds the ScreenGui, the six categories, Friends/Targets/Profiles lists, `LegitWindow`, `SearchBar`, `OverlayBar`, and the General/Modules/GUI/Notifications panes.

`src/games/<game>/<PlaceId> - <desc>/` compiles to `newvape/games/<PlaceId>.lua`; the text before the first ` - ` is the filename. A product is `base.lua` plus category folders (`Combat/`, `Blatant/`, `Render/`, `Utility/`, `World/`, `Legit/`, `Inventory/`), concatenated into one chunk with `base.lua` first, and `processGame.js` appends every category file **wrapped in `run(function() ... end)` unless the file text contains the literal `run(`**. Scope is therefore per file: a wrapped module's top-level locals are private and it only reaches out for the base's locals (`vape`, `entitylib`, …), while an unwrapped file — `Blatant/Fly.lua` in most products, `Combat/SilentAim.lua` in a few — is spliced into the chunk scope next to `base.lua` and can shadow it (§9). Either way module files have no `require` and no `local vape =`.

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
| `72169370437173 - tribes3v3` | 12 |
| `893973440 - flee the facility` | 7 |
| `redwood prison/10456235914 - game` | 5 · 4 redirects |
| `life sentence/13083893317 - game` | 4 · 3 redirects |
| `bloxstrikes/114234929420007 - game` | 2 |
| `fling things and people/6961824067 - game` | 6 |
| `girls and boys vs zombies/796267492 - main` | 1 · 5 redirects |

A redirect is a standalone `<PlaceId> - <desc>.lua` at the game-folder root: set `vape.Place` to the parent PlaceId, then `loadstring` that parent chunk (some forward `...`). `skywars voxel/8542259458 - skywars lobby.lua` is not a redirect — it is a mini-base that only registers `sessioninfo` items. `life sentence/13083893317 - game` holds `AutoArrest`, `AutoReset`, `AutoStomp` (Blatant) and `DownedESP` (Render), with redirects `112593144270962 - new player`, `128630665408026 - vc`, `137771527695895 - console`; its base reads `<player>.Backpack.Stats` (transient flags) and `ReplicatedStorage.PlayerStats.<name>` (persistent stats) instead of attributes, uses the real `Teams` service, and keeps every remote in `ReplicatedStorage.Events`.

## 4. Core `vape` object

Root table (`base.lua:1-22`): `ActiveBinds`, `Categories`, `GUIColor`, `HeldKeybinds`, `Loaded`, `Libraries`, `Modules`, `Place` (= `game.PlaceId`), `Profile` (= `'default'`), `RainbowSliders`, `Settings`, `SettingToggleNotifications`, `ThreadFix` (= `setthreadidentity and true`), `ToggleNotifications`, `Version = '4.22'`, `Windows`.

- `vape.Loaded` is a three-state sentinel: `false` → `canSave` at the end of `Load` (:537) → `nil` in `Uninject`. Modules use `repeat ... until vape.Loaded == nil` to exit and `repeat task.wait() until vape.Loaded` to wait.
- `vape.ThreadFix` requires `setthreadidentity(8)` before any core-GUI or Instance creation.
- `vape:Remove(name)` searches `self.Modules`, `self.Legit.Modules`, then `self.Categories` and destroys the first hit; it records no "removed" flag, so it only affects objects alive at call time.
- Redirects overwrite `vape.Place` with the parent id so one profile spans subplaces.

Methods: `CreateCategory` :338 · `CreateCategoryList` :342 · `CreateNotification(title, text, duration, 'info'|'warning'|'alert')` :346 · `CreateOverlay` :444 · `Load(skipgui, profile)` :448 · `LoadOptions` :563 · `LoadGUI()` :573 (empty, filled by `--Init`) · `Remove` :577 · `Save` :608 · `SaveOptions` :642 · `SortCategories` :655 · `Uninject` :675 · `UpdateGUI` :721 · `UpdateGUIQueue` :735 · `Clean(x)` (`addMaid` :166; accepts connection, Instance, thread or function). Also `UpdateTextGUI` (`overlays/TextGUI.lua:322`) and `Color`/`TextColor` (`libraries/color.lua`); private helpers sit in `base.lua:24-330`. Line numbers were accurate when written; re-check before trusting one.

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

Universal registers `vape.Libraries.entity/whitelist/prediction/hash/webhook/auraanims`; `overlays/TargetInfo.lua:254` registers `targetinfo`; `Render/SessionInfo.lua` registers `sessioninfo`. `libraries/backend.lua` is **not** in `vape.Libraries` — the universal base loads it directly through `downloadFile`/`loadstring` and holds the only handle (`backend:start()` at :1017, `backend:stop()` in `vape:Clean` at :1020), so nothing else can reach `beat`/`refreshKey`; a module needing worker state must be wired through the base. GUI libraries (`tween`, `uipallet`, `color`, `getfontbounds`, `getvapeasset`) are globals from `--Libraries`. `prediction.SolveTrajectory(...)` returns an aim point or nil. `whitelist:get(plr)` returns `(level, attackable, tags)`; the second value is what `targetCheck` reads, level 0 is the public tier, `whitelist.localprio` holds the local player's own level, and the whitelist JSON is fetched after injection, so `get` reads 0 until `whitelist.loaded` becomes true. `getvapeasset` caches downloads on desktop and otherwise falls back to an inline `rbxassetid://` table, returning `''` on a miss.

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

`base.lua` and the root `<PlaceId> - <desc>.lua` files re-declare the shims they use (`isfile`, `cloneref`, `queue_on_teleport`, notifying `loadstring`) because each can run as its own chunk (`main.lua` loads a redirect through `loadstring`); category module files inherit them as upvalues and declare nothing. Universal's base also provides shared helpers (`isFriend`, `isTarget`, `canClick`, `getTool`, `notif`, `serverHop`, `updateVelocity`, `motorMove`), the `SpeedMethods` table, and the whitelist command set (`kill`, `kick`, `chat`, `toggle`, `uninject`, …).

Prison Life's `Utility/ChatCommand.lua` keeps a shared path next to the local `lplr.Chatted` one: names in the `.wl` list (`vape.Categories.Friends.ListEnabled`) may run dot commands on the client while `ShareCommand` is enabled, and any whitelist level above 0 (private members) may always. Its CommandBox accepts a command with or without the leading dot. The prison life base ends with a watcher that polls up to 60s for `whitelist.loaded` before connecting `PlayerAdded` and rescanning `GetPlayers()`, then queues `MEMBER_LINES` chat lines for every private member that joins; a single worker drains the queue a second apart, and the block stays silent when `whitelist.localprio ~= 0`, when the player is `lplr`, or when the `UserId` was already announced.

## 9. Known pitfalls

- `base.lua:560` — `vape:Load` ends with `return toggleData`, but `toggleData` is undefined.
- `base.lua:524` — `Save` inside `Load` early-returns (`not self.Loaded`); the first real write comes from the 10-second loop.
- Module objects have no `Type` field, so `Remove`'s `isModule` check never re-sorts categories.
- `CreateTargets` always saves under `"Targets"`, ignoring `Name`.
- `TwoSlider` never calls `props.Function` from `SetValue`.
- `vape:Remove` only affects modules that already exist: a product base runs before its own category files, so it can only drop universal's modules there. Remove a product's own module from that module file.
- `Dropdown:SetValue` silently falls back to `List[1]` when the value is missing, so a renamed value or stale profile quietly becomes the first entry.
- `Enabled and nil or true` is always `true`; pass booleans through unchanged.
- Two scopes per product: `base.lua` shares one with the unwrapped files (any file whose text contains `run(`), where a duplicated top-level local silently overwrites the other's; wrapped files are isolated. An assignment without `local` reaches the base's variable or a global from either scope (some pairs rely on that), and a top-level `return` is only legal in a wrapped module, where it just ends that file.
- `bedwars/6872274481 - game/base.lua:33` kicks the player — BedWars is retired.

## 10. Conventions

Measured against upstream `7GrandDadPGN/VapeV4ForRoblox` (402 of 410 Lua files use tabs). Match upstream, not personal taste.

**Layout**

1. Tabs, one level per block. Never spaces.
2. No semicolons as statement terminators. The only `;` in the tree sits in `libraries/vm.lua` (VM port inherited from upstream) — never add one.
3. Single quotes for strings: `'Killaura'` (6845 single vs 282 double upstream, ~96%). Double quotes survive only in inherited code (`vm.lua`, `Spotify.lua`, `guis/new/init.lua`'s older lines) — leave those alone.
4. Assignment and comparison operators are spaced: `x = y`, `a == b`. String concat is the exception — `..` has no surrounding spaces: `'...'..readfile(...)..'/'..select(...)`.
5. Comments start with `--` plus one space.
6. Table literals put one field per line, every field except the **last** carries a comma, and the last one does not (upstream: plain tables 144:8, component arguments 1212:6 — both overwhelmingly omit the final comma). Never collapse a multi-argument call onto one line (`CONTRIBUTING.md`).
7. No compound assignment: `+=`, `-=`, `*=` appear zero times upstream. Write `x = x + y`.
8. Files end with a newline; do not stop at the final `end` without one.

**Naming**

9. camelCase for locals and fields: `local suc, res`, `local gameCamera`, `readfile`, `cloneref`. snake_case is rare and only in inherited code.
10. Business constants are camelCase (`settleTimeout`, `maxRemembered`, `tpOffset`). Upstream reserves SCREAMING_SNAKE_CASE for VM and bytecode work (`TWO_POW_*`, `LUA_*`). Roblox enum strings such as `'INVITE_BROWSER'` are values, not names — leave them.
11. Service locals are `cloneref(game:GetService('X'))` at the top of a base, named after the service in lowerCamel with the `Service` suffix kept (`playersService`, `replicatedStorage`, `runService`, `inputService`, `tweenService`).
12. Shim blocks are re-declared at the top of a chunk (`local loadstring = function(...)`, `local isfile = isfile or function(file)`, `local run = function(func)`, `local queue_on_teleport = queue_on_teleport or function() end`, `local cloneref = cloneref or function(obj)`); no blank lines inside the block, one blank line after it.
13. Helpers are `local function name(...)` (486 upstream); `local name = function()` is for shims and closures such as `run`.

**Module shape**

14. A module file forward-declares every module and option as `local Name` at the top, one per line with no blank lines between them, then a blank line, then shared locals, then `Name = vape.Categories.X:CreateModule({ ... })`. Options are created after the module (`Targets = Killaura:CreateTargets({...})`). Category files never write `local vape = shared.vape`.
15. Option callbacks keep upstream's parameter names: `Function = function(callback)` for modules (454 upstream), `(val)` for colour sliders and sliders (104), `()` for dropdowns, `(enter)` / `(args)` for buttons.
16. Module loops are `if callback then` → `repeat` → body → `task.wait()` → `until not Module.Enabled` → `end`; the framework already spawns `Function`, so never spawn another thread.
17. Single-statement early returns stay on one line: `if not isfolder(path) then return end` (224 upstream vs 25 multi-line).
18. Instances shared across functions (`Folder`, `Part`, `Highlight`) are declared at file scope with `Instance.new` and get their properties and `Parent` set there, not scattered through functions.
19. `continue` is a last resort; filter with `if ... then ... end` or an early `return` instead.

**Practice**

20. Localize aggressively — never index a field or call a function twice in a loop; hoist per-frame constants above the loop (`CONTRIBUTING.md`).
21. Route all cleanup through `vape:Clean(...)` / `<Module>:Clean(...)` (422 upstream); raw `:Connect()` leaks across reinjection.
22. Cross-file forward declarations: the base declares `local Reach = {}`, the module assigns without `local`.
23. Hot restart an option change: `if Module.Enabled then Module:Toggle(); Module:Toggle() end`.
24. Prefer guarded executor calls (`typeof(x) == 'function'`, `pcall`) over raw calls with live game objects.
25. New modules go in `src/games/<game>/<PlaceId> - <desc>/<Category>/<Name>.lua` with no `require` and the base's locals; top-level names only have to be unique against `base.lua` and the other unwrapped files, since a wrapped file keeps its own scope (§9).
26. When asked to optimize, touch only code the assistant wrote in that file; upstream and maintainer code stays unless explicitly requested.

**Change boundary**

- Restyle only code Inhaler added or rewrote. Lines identical to upstream stay byte-for-byte, never reformatted.
- Pure branding replacements (`VapeCompiled` → `InhalerCompiled`, `vape` → `inhaler` in the watermark) count as no code change — leave them alone.
- Verify with the Lua 5.4 syntax check in §1 after editing.

## 11. Changelog via Discord webhook

`UPDATES.md` and `inhaler_send_update.py` are gitignored, and `UPDATES.md` is generated — never commit it. After changing any Inhaler file, append user-visible entries in this exact shape:

````md
[Universal]
```diff
~ [Killaura.lua] target sorting now prefers the closest entity
```
````

One line per changed file, `+` added / `-` removed / `~` changed; no mechanics, no multiple lines per file. Universal changes use `[Universal]`; rerunning replaces the earlier message. The script (`./inhaler_send_update.py <WebhookURL>`, or `WEBHOOK_URL`/`UPDATES_FILE`/`PROXY`, proxy default `127.0.0.1:7890`, `off` disables) posts the file, splits entries past Discord's 1024-character field limit into `Name (2)`, keeps the file when sending fails and deletes it on success. Don't run it or post the webhook unless asked.
