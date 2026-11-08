## Contributing
All contributions must be held to a certain standard of quality, mainly keeping the original code style in check.
1. Tab formatting
2. Unless its a return, please do not use 1 line for most function calls.
3. Localize variables when possible, most of the time the code should never have to index a variable, or call a function twice in a loop.

Here is the provided [documentation](https://github.com/7GrandDadPGN/VapeV4ForRoblox/wiki) for if you want to contribute. 

### Vape Code Style (extracted by Inhaler, for everyone.)

These rules come from measuring upstream `7GrandDadPGN/VapeV4ForRoblox` (402 of 410 Lua files indent with tabs) and from the three points above. When in doubt, open an upstream file and match it.

#### Layout

1. **Tabs**, one level per block. Never spaces.
2. **No semicolons** as statement terminators. The only `;` in the whole tree is in `libraries/vm.lua`, a VM port inherited from upstream — never add one.
3. **Single quotes** for strings: `'Killaura'` (6845 single vs 282 double upstream, about 96%). Double quotes survive only in inherited code (`vm.lua`, `Spotify.lua`, older lines of `guis/new/init.lua`) — leave those alone.
4. **Operators are spaced**: `x = y`, `a == b`. String concat is the exception — `..` has no surrounding spaces: `'...'..readfile(...)..'/'..select(...)`.
5. **Comments** start with `--` and one space.
6. **Table literals** put one field per line. Every field except the **last** carries a comma, and the last one does not (upstream: plain tables 144:8, component arguments 1212:6 — both overwhelmingly omit the final comma). This includes the `CreateModule({...})` / `CreateXxx({...})` arguments.
7. **No compound assignment**: `+=`, `-=`, `*=` appear zero times upstream. Write `x = x + y`.
8. **Files end with a newline**, not directly after the final `end`.
9. **Do not collapse multi-argument calls onto one line** (point 2 above) — except a bare `return`, which stays on one line.

#### Naming

10. **camelCase** for locals and fields: `local suc, res`, `local gameCamera`, `readfile`, `cloneref`. snake_case is rare and only in inherited code.
11. **Business constants are camelCase** (`settleTimeout`, `maxRemembered`, `tpOffset`). Upstream reserves SCREAMING_SNAKE_CASE for VM and bytecode work (`TWO_POW_*`, `LUA_*`). Roblox enum strings such as `'INVITE_BROWSER'` are values, not names — leave them.
12. **Service locals** are `cloneref(game:GetService('X'))` at the top of a base, named after the service in lowerCamel with the `Service` suffix kept: `playersService`, `replicatedStorage`, `runService`, `inputService`, `tweenService`.
13. **Shim blocks** are re-declared at the top of a chunk (`local loadstring = function(...)`, `local isfile = isfile or function(file)`, `local run = function(func)`, `local queue_on_teleport = queue_on_teleport or function() end`, `local cloneref = cloneref or function(obj)`). No blank lines inside the block, one blank line after it.
14. **Helpers** are `local function name(...)` (486 upstream). `local name = function()` is for shims and closures such as `run`.

#### Module shape

15. **Forward declarations**: a module file declares every module and option as `local Name` at the top, one per line with no blank lines between them, then a blank line, then shared locals, then `Name = vape.Categories.X:CreateModule({ ... })`. Options are created after the module (`Targets = Killaura:CreateTargets({...})`). Category files never write `local vape = shared.vape`.
16. **Option callback parameter names** follow upstream: `Function = function(callback)` for modules (454 upstream), `(val)` for colour sliders and sliders (104), `()` for dropdowns, `(enter)` / `(args)` for buttons.
17. **Module loops** are `if callback then` → `repeat` → body → `task.wait()` → `until not Module.Enabled` → `end`. The framework already spawns `Function`, so never spawn another thread.
18. **Single-statement early returns** stay on one line: `if not isfolder(path) then return end` (224 upstream vs 25 multi-line).
19. **Instances shared across functions** (`Folder`, `Part`, `Highlight`) are declared at file scope with `Instance.new`, and get their properties and `Parent` set there, not scattered through functions.
20. **`continue` is a last resort**; filter with `if ... then ... end` or an early `return` instead.

#### Practice

21. **Localize aggressively** (point 3 above): never index a field or call a function twice in a loop; hoist per-frame constants above the loop.
22. **Route all cleanup through** `vape:Clean(...)` / `<Module>:Clean(...)` (422 upstream). Raw `:Connect()` leaks across reinjection.
23. **Cross-file forward declarations**: the base declares `local Reach = {}`, the module assigns without `local`.
24. **Hot restart an option change**: `if Module.Enabled then Module:Toggle(); Module:Toggle() end`.
25. **Prefer guarded executor calls** (`typeof(x) == 'function'`, `pcall`) over raw calls with live game objects.
26. **New modules** go in `src/games/<game>/<PlaceId> - <desc>/<Category>/<Name>.lua` with no `require` and the base's locals.

#### Example

```lua
local Reach
local Targets
Reach = vape.Categories.Combat:CreateModule({
	Name = 'Reach',
	Function = function(callback)
		if not callback then return end

		repeat
			local entities = entitylib.AllPosition({
				Range = Targets.Range.Value,
				Part = 'RootPart',
				Players = Targets.Players.Enabled,
				NPCs = Targets.NPCs.Enabled
			})

			for _, entity in entities do
				local distance = (entity.RootPart.Position - entitylib.character.RootPart.Position).Magnitude
				if distance <= Targets.Range.Value then
					-- work
				end
			end

			task.wait()
		until not Reach.Enabled
	end
})
Targets = Reach:CreateTargets({Players = true})
```

Note what the example shows: tabs, single quotes, `..` with no spaces, the last table entry without a comma, camelCase locals, `local function` helpers, and the `repeat ... until not Module.Enabled` loop body. The full rules and the reasoning behind each measured number live in `AGENTS.md` §10.
