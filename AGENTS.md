# AGENTS.md

Fork of Vape V4: a Roblox executor script written in **Luau**, not standard Lua and not Node. `src/` is the maintainable source; nothing here executes directly. CI flattens it into the separate `Night5449791/InhalerCompiled` repo, which the loader downloads at injection time.

`CODEBUDDY.md` is the deep reference (architecture, component/option API, save format, pitfall list). Its `§` numbers are referenced elsewhere, so keep them stable. If the two disagree, trust `build.yaml` and the code.

## Commands

- **No local build, lint, or test suite.** No `package.json`, Makefile, or selene/stylua config. Don't add tooling unless asked.
- Build is push-only: `.github/workflows/build.yaml` runs on `main`, clones `InhalerBundler` + `InhalerCompiled`, copies `workflowConfig.json` to the bundler's `config.json`, runs `node ./InhalerBundler/index.js prod`, and pushes the output. Bundling behavior lives in InhalerBundler, not this repo.
- The Obsidian target is **not** in CI and is not part of InhalerBundler: it lives in the separate `InhalerBundlerObsidian` folder/repo and is built locally. Its output (`InhalerObsidianCompiled`) is never pushed.
- Syntax-check one file (no Luau compiler installed; rewrite Luau-only syntax first, then parse with Lua 5.4):
  ```bash
  sed -E -e 's/[[:space:]]+continue([[:space:]]|$)/ break\1/g' \
         -e 's/([A-Za-z_][A-Za-z0-9_.]*) ([+-])= /\1 = \1 \2 /g' FILE.lua > /tmp/check.lua \
    && luac -p /tmp/check.lua && echo "syntax OK"
  ```
  Catches syntax only, never semantics.
- `python3 -m py_compile inhaler_send_update.py` for the update tool, then delete `__pycache__/`.

## Runtime and bundling model

- `src/loader.lua` is byte-identical to root `NewMainScript.lua`; root `loadstring` is the one-line user entry. Change both together or they diverge.
- `src/main.lua` loads `newvape/guis/new.lua` (GUI name hardcoded `'new'`), then `games/universal.lua` always, then `games/<PlaceId>.lua` if present, then `finishLoading()`.
- Product folder `src/games/<game>/<PlaceId> - <desc>/` compiles to `newvape/games/<PlaceId>.lua`; the text before the first ` - ` is the filename. `base.lua` plus its category files are **concatenated into one chunk**, and the scope depends on the file — the biggest footgun:
  - no `require` of repo files (only game-owned ModuleScripts), and no `local vape =` in module files; reuse the base's locals (`vape`, `entitylib`, `lplr`, `store`, `notif`, …)
  - the bundler wraps each category file in `run(function() ... end)` unless its text contains `run(`; a wrapped file's top-level locals are private to it, while a file that contains `run(` (`Blatant/Fly.lua` is the usual one) is spliced into `base.lua`'s scope, where its top-level names must stay unique
  - `Reach = ...` without `local` links to `local Reach = {}` in the base; don't add `local`
- A product's `base.lua` top-level runs before its own category files exist, so `vape:Remove` there only drops modules loaded earlier (universal, for game products). Remove a product's own module from that module file.
- Subplace files (`<game>/<PlaceId> - <desc>.lua`) are standalone redirects: set `vape.Place` to the parent PlaceId, then loadstring the parent product. Some forward varargs.
- `src/guis/new/base.lua` is not self-contained: the bundler inlines libraries at `--Libraries`, `init.lua` at `--Init`, components/overlays at `--Components`. Put UI files in those folders instead of loading them yourself.
- Dev loop needs a Roblox executor and a rebuilt product chunk (run InhalerBundler locally, or hand-merge the file body into the matching compiled chunk). Copy it into `newvape/**`, then re-run with `shared.VapeDeveloper = true` set beforehand. That skips the remote commit check and cache wipe; without it the loader replaces cached files from `InhalerCompiled`.

## Conventions

- Tabs, no semicolons; don't collapse multi-arg calls onto one line (`CONTRIBUTING.md`).
- Each standalone chunk re-declares the executor shims it uses (`isfile`, `cloneref`, `queue_on_teleport`, `loadstring` wrapper); copy the file-top block rather than assuming globals.
- Module `Function` is already `task.spawn`ed by the framework; loop with `repeat ... task.wait() until not Module.Enabled` and don't spawn another thread for it.
- Clean up through `vape:Clean(...)` / `<Module>:Clean(...)`; raw `:Connect()` leaks across reinjection.
- `entitylib` selectors `table.clear` the settings table before returning — pass a fresh table per call. `entity.Targetable` is cached at spawn; call `entitylib.start()` again after overriding hooks.
- Chat commands go into **both** `universal - base/Utility/ChatCommand.lua` and `prison life/155615604 - main/Utility/ChatCommand.lua`, unless the command is game-specific.
- When optimizing, touch only code the assistant wrote in that file; leave upstream/maintainer code alone unless explicitly asked (`CODEBUDDY.md` §10.9).

## Changelog

- `UPDATES.md` is gitignored and generated; never commit it. After changing Inhaler files, append user-visible entries in the strict format from `CODEBUDDY.md` §11: `[GameName]` header plus a fenced `diff` block, one line per changed file with `+` / `-` / `~`.
- `inhaler_send_update.py` (also gitignored, local-only) posts `UPDATES.md` to Discord and deletes it only on success. Don't run it or post the webhook unless asked.
