# Changelog

## 0.10.0 - Unreleased

- New framerate design (moveable, behind cursor)
- Overhauled custom classes/states support, added state redirect
- Per-animation flipX/flipY support for characters
- Added V-Slice character JSON detector
- Fixed memory leak caused by luaDebugCam
- Fixed FPS counter camera and desktop editor playstate
- Fixed iOS for real this time
- Fixed dragging issue
- Fixed error logs in hscript and addTextToDebug
- Fixed float imprecision
- Added Tracy profiler support
- Improved cleaning memory
- Improved hscript a bit
- Use Native File System for Mobile instead of relaying in OpenFL
- Added `startLuasNamed`
- Added TITLE_IOS
- Added iOS simulator building (main only)
- Enabled hxdiscord_rpc IO thread
- Updated some haxelib refs
- Updated gamemode config
- Updated touchpad assets
- Base Game has been added
- Enabled videos for the iOS simulator
- Sound extensions limited to ogg and mp3 for now
- HScript improvements a bit
- Fixed score popup memory leak
- `gf-empty` character replaces the transparent 1x1 girlfriend placeholder
- Fixed MemoryCounter build on MinGW

## 0.9.0 - 2026-05-20

- Switched hxluajit with hxluau (we are so roblox yes)
- Switched SScript with ShadowScript (hscript-improved fork)
- Overhauled flixel and openfl to use Funkin ones
- Updated V-Slice codes
- Fixed iOS (yet again) (maybe not?)
- Added scripted states for empty state shit idk
- Added ShadowCamera to fix blends
- Game now uses SDL3 (bugs for mobile mostly fixed and main loop is now nanoseconds delta time)
- New LuaAPI

## 0.7.0 - 2026-02-24

- Switched Scoring system fixed score to PBOT1
- Added Graphic null check and improved bitmap caching
- Made Sound Tray modable again
- Updated Haxelibs (mostly Lime fixes eg ANGLE)
- Erect song events (`events-erect.json`) support
- Added Play Animation to Chart Editor events
- Band-aid fix for ResultsScreen
- Removed V-Slice events for now
- Assets folder is a submodule now
- `forcePixelStage` renamed to `usePixelTextures`
- Removed HiDPI fixes for Windows
- Package name changed to `org.shadowengineteam.fnf`
- Save folder changed from `FNF-SE` to `ShadowEngineTeam`
- Switched S3TC to BPTC, supporting all BC GPU textures

## 0.6.0 - 2026-02-07

- HSV support (as an option) and pixel note splashes and hold splashes
- Mobile Controls under `MOBILE_CONTROLS_ALLOWED` compile flag
- IMusicState interface
- `openfl_dpi_aware` to fix mobile compatibility
- Emergency buttons (Shift + F4 for Main Menu, Shift + F5 for reset the state)
- Alternative file extension support for HScript files
- Undo, redo, and note skin preview in ChartingState
- Keystore keygen for Android
- GPU texture scripts and execution
- Downscale Game option for Android
- Alternative name for mobile
- Kade Engine clap and snap sounds in ChartingState
- Controller support improvements
- Game now uses ANGLE for rendering
- Renamed compile flags for more reasonable `#if` macros and `project.hxp`
- Refactored Editor UI and removed FNF-Modcharting-Tools
- Updated GPU texture handling (premultiply in GPU texture instead of shader)
- Split `library_shadows` for each work and updated references

## 0.4.5 - 2026-01-15

Several bug fixes. [Check tag differences from 0.4.4](https://github.com/FNF-SE/FNF-Shadow-Engine/compare/0.4.4...0.4.5).

## 0.4.4 - 2026-01-11

- Fixed Test Erect (forgot to add erect stage)
- Fixed Touch Here To Play
- Fixed SustainSplash for pixel
- Fixed CustomSubstate
- Reverted GC stuff
- Use alternative name for mobile
- Use Kade Engine clap and snap in ChartingState
- Added keystore keygen for Android
- Added alternative file extension support for hscript files
- Added emergency buttons (Shift + F4 for Main Menu, Shift + F5 for reset the state)
- Implemented undo, redo and note skin preview in ChartingState

## 0.4.0 - 2025-12-28

- Added `flixel-animate` with lua functions
- Added Erect and Nightmare difficulties
- Added 32-Bit's support globally
- Added NotesSubstate
- Fixed Video Cutscenes for lua, ControlsSubstate crash and iOS crash
- Removed ShadowBuildField due to our versioning system
- Unembedded Preloader and Soundtray assets for mods
- Rewrited Audio stuff with VS Camellia/CNE Audio stuff
- Some GC rewrite
- Sustain and SustainSplash rework
- SE Icon rework (mostly for mobile)
- FPS Counter rework
- FileSystem Overhaul (SE can check OpenFL assets in FileSystem codes, no more CopyState for mobile)

## 0.3.0 - 2025-11-11

- Removed more leftovers from GHR (Gacha Horror Recreation)
- Switched XML to HXP in the project file and added welcoming
- Added per-frame icon support (un-hardcoded icon splitting, winning icons supported)
- Added more V-Slice features
- Un-GPU'd texture pixel assets
- Fixed sRGB for S3TC
- Changed default note binds from WASD to DFJK
- Added state and substate scripting support
- Backwards compatibility fixes
- Rewrote Memory class to show exact game memory usage
- Switched from linc_luajit to hxluajit
- Improved shader handling (mostly for macOS)
- Slightly better mobile support

## 0.2.1 - 2025-10-19

- Remove leftovers from GHR (Gacha Horror Recreation)
- Added missing things from Psych
- Mobile Controls and Android changes (folder now at Android/data, see Options)
- Remove embedding code
- Some JSON formatting
- Added including all classes as possible macro
- Added our icon!!

## 0.2.0 - 2025-10-19

First release.
