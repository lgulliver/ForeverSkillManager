# Changelog

All notable changes to ForeverSkillManager. Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

## [0.1.0] - 2026-11-05

First release.

### Added
- Newly learned spells are placed in the first empty slot of a visible action bar, with a chat message when no slot is free.
- Action bar spells are swapped for the highest rank you know.
- Bar changes are deferred until combat ends.
- Works with the default Blizzard action bars and Bartender4 (enabled, visible bars, respecting each bar's button count).
- `/fsm` (also `/fskills` and `/fskill`) opens the settings panel. `/fsm sync`, `/fsm debug` and `/fsm reset` are also available.
- Settings panel: placement and upgrade toggles, chat verbosity, per-bar enable, fill order, and an ignored spells list.
- Addon list icon.
- Release workflow: builds the `-forever` zip, publishes a GitHub release and uploads to CurseForge. Wago imports releases through a GitHub webhook.
- luacheck lint workflow.
