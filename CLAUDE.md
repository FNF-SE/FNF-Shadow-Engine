# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

The full repository guide lives in AGENTS.md and is imported here:

@AGENTS.md

## Claude-specific notes

- Verification is a full build: run `lime build windows -D ASTC` (in the background is fine) — Haxe type errors abort fast, before the long C++ codegen. There is no test suite.
- Use the Grep/Glob tools scoped to `source/` — `export/` and `.haxelib/` contain thousands of files that drown out results.
