# AGENTS.md

Guidance for AI coding agents working in this repository.

## What this is

Friday Night Funkin': Shadow Engine — a heavily modified Psych Engine 0.7.3 fork, written in Haxe on Lime/OpenFL/HaxeFlixel and compiled to native C++ via hxcpp. Targets Windows, macOS, Linux (including ARM), Android, and iOS. Nearly every framework library (lime, openfl, flixel, hxcpp, SScript/ShadowScript, hxluau, hxvlc, flixel-animate) is a ShadowEngineTeam fork pinned by commit in `hmm.json`.

## Setup

```bash
git submodule update --init          # assets/ is a submodule (ShadowEngineTeam/FNF-SE-Assets)
haxelib git hmm https://github.com/ShadowEngineTeam/hmm --skip-dependencies
haxelib run hmm install              # installs pinned deps into the local .haxelib/
```

CI pins Haxe 4.3.7. Dependencies live in a project-local `.haxelib/` repository, not the global one.

## Build, run, verify

```bash
lime build windows -D ASTC           # build (this IS the type check — see below)
lime test windows -D ASTC            # build + run
lime test windows -D ASTC -debug     # debug build
```

- **Every `lime` command needs a texture-format define: `-D ASTC` or `-D BC`.** In this repo, use `-D ASTC`. The define selects which compressed-texture asset set (`assets/images-astc`, `images-bc`, or `images-png` fallback) gets bundled; CI uses BC for x86 desktop and ASTC for ARM/mobile targets.
- **There is no test suite and no separate lint step.** Verification is a full `lime build windows -D ASTC`: Haxe type/null-safety errors abort in the early compiler phase (fast); only a clean pass reaches the long C++ codegen. Run it in the background and keep working. Do not use `lime display`-based typecheck shortcuts.
- Output lands in `export/release/<target>/bin/` (or `export/debug/` for `-debug` builds).
- Other targets: `linux`, `mac`, `android`, `ios` (see `.github/workflows/main.yml` for the exact per-platform flags).

## Project configuration: project.hxp

The build is defined by `project.hxp` (an hxp `HXProject` subclass), **not** a project.xml. It holds the version/build number, window setup, asset wiring, and the compile-flag system:

- Features are `CompileFlag`s: `FEATURE_MODS`, `FEATURE_HSCRIPT`, `FEATURE_LUA`, `FEATURE_VIDEOS`, `FEATURE_DISCORD_RPC`, `FEATURE_MOBILE_CONTROLS`, `FEATURE_TRACY`, `FEATURE_FUNKIN_CONTENT`, `EMBED_ASSETS`, `FEATURE_DCE`. Each has a `NO_` inversion — pass `-D NO_FEATURE_LUA` to force-disable, `-D FEATURE_TRACY` to force-enable. Guard optional code with `#if FEATURE_X`.
- DCE is off and `macros.KeepMacro.keepClasses()` keeps every class, so Lua/HScript mods can reflect into anything. Don't assume unused code gets stripped.
- `project.hxp` verifies installed lib versions against `hmm.json` at build start and warns on mismatch (`hmm reinstall <lib>` fixes it).

## Source layout

Source roots are `source/engine`, `source/haxe_std_shadows`, and `source/library_shadows/compatibility`. **The package root is `source/engine`** — packages are `backend`, `states`, `objects`, `psychlua`, `mobile`, `options`, `substates`, `cutscenes`, `shaders`, `effects`, `debug`, `macros` (no `engine.` prefix; main class is `backend.Main`).

- `source/engine/import.hx` — global imports injected into every module (FlxG, Paths, ClientPrefs, ShadowUI components, `using backend.Funkin`, ...). Check it before adding imports.
- `source/haxe_std_shadows/` — files that shadow the Haxe standard library (`StringTools`, `haxe.Json`, Tracy glue).
- `source/library_shadows/compatibility/` — files that shadow individual haxelib classes (e.g. `flixel.input.mouse.FlxMouse`, `hscript.SScript`). **Prefer adding a shadow here over editing a lib inside `.haxelib/`** — `.haxelib/` edits are local-only and CI will not see them; real lib changes must land in the ShadowEngineTeam fork and get the `hmm.json` ref bumped.
- `assets/` — git submodule; per-format image sets (`images-png`/`images-astc`/`images-bc`), `funkin_resources/` (base-game content behind `FEATURE_FUNKIN_CONTENT`), `mobile/`.
- `gpu_texture_generator/` — Python scripts (astcenc/compressonator) that produce the ASTC/BC compressed texture sets from PNGs.
- **Never search or edit `export/`** — it's build output plus locally installed mods (thousands of JSONs that pollute searches). Search `.haxelib/` only when investigating framework internals.

## Architecture

**Boot:** `backend.Main` (installs `ShadowCameraFrontEnd` over FlxG.cameras, crash handler, Codename-style framerate counter) → `states.InitState` (mods, prefs, controls, `GlobalScript`/`ScriptSignalCalls`, Discord) → menus → `states.PlayState`.

**States & scripting:** `backend.MusicBeatState` / `MusicBeatSubstate` (implementing `backend.IMusicState`) are the base for every state. Each owns a `backend.scripting.ScriptManager` holding a `luaArray` (`psychlua.FunkinLua`, via hxluau, `.lua`/`.luau`) and an `hscriptArray` (`psychlua.HScript`, via ShadowScript/SScript API, `.hx`/`.hscript`/`.hxs`/`.hxc`). Script calls return `backend.scripting.ScriptResult` values (`Continue` / `StopLua` / `StopAll`) that control event propagation. States themselves are scriptable/replaceable: `psychlua.ScriptedState`/`ScriptedSubState` and `backend.scripting.ModsStateRedirect` let mods redirect or define whole states; `GlobalScript` runs engine-wide scripts.

**Lua API:** `psychlua/` splits the mod-facing Lua API into function modules (`LuaSpriteFunctions`, `ShaderFunctions`, `TweenFunctions`, `ReflectionFunctions`, etc.) registered onto each `FunkinLua` instance. New Lua callbacks go in the matching module, not inline in PlayState.

**Assets & mods:** `backend.Paths` resolves every asset, checking mod folders (`backend.Mods`) before bundled assets; `backend.io.File`/`FileSystem` wrap native vs OpenFL filesystem access (mobile uses native FS). Data-driven content is JSON: characters, stages (`backend.StageData` + `states/stages/`), weeks (`backend.WeekData`), songs/charts (`backend.Song`, `backend.Section`).

**Rendering & UI:** `backend.rendering.ShadowCamera`/`PsychCamera` replace stock flixel cameras (blend-mode fixes). `backend/ui/` is ShadowUI (PsychUI-alike: `ShadowButton`, `ShadowTabMenu`, ...) used by the editors in `states/editors/` (ChartingState, CharacterEditorState, ...).

**Mobile:** `mobile/` contains touch controls (`TouchPad`, `Hitbox`, `MobileControls`), storage handling, and mobile options — all behind `FEATURE_MOBILE_CONTROLS` / `#if mobile`.

## Code style

- Tabs for indentation (4-wide); Allman-style braces per `hxformat.json`.
- Every local `var`/`final` gets an explicit type annotation (`var x:Int = 0`, never `var x = 0`).
- Null safety is being adopted incrementally; bare `@:nullSafety` means Loose mode. When fixing null-safety errors: no blanket `@:nullSafety(Off)`, no throwaway narrowing locals, never `cast null` or casts that erase nullability. Beware casting arguments that rely on implicit `@:from` conversions — the cast bypasses them.
- Debug shortcuts: Shift+F4 ejects to main menu, Shift+F5 resets the current state.
