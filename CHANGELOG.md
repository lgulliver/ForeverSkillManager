# Changelog

All notable changes to ForeverSkillManager. Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- luacheck lint workflow and `.luacheckrc`.
- Tag-triggered release workflow: builds the `-forever` zip, publishes a GitHub release, and uploads to CurseForge when configured. Wago picks releases up through a GitHub webhook.
- Bartender4 support: fills Bartender's enabled, visible bars and respects each bar's button count.

### Changed
- Renamed the addon from ForeverSkills to ForeverSkillManager, because the old name was already taken on CurseForge. The folder, saved-variables name and zip name changed, so settings start fresh. `/fskills` and `/fskill` still work, and `/fsm` is new.
- With Bartender4, the settings panel lists only enabled bars, and the fill-order tooltip no longer refers to Blizzard bar names.

## [0.1.0]

### Added
- Newly learned spells are placed in the first empty slot of a visible default action bar, with a chat message when no slot is free.
- Action bar spells are swapped for the highest rank you know.
- Bar changes are deferred until combat ends.
- `/fskills sync`, `/fskills debug` and `/fskills reset` commands.
- Settings panel: placement and upgrade toggles, chat verbosity, per-bar enable, fill order, and an ignored spells list.
- Addon list icon.

### Fixed
- Opening the settings panel in combat no longer triggers an interface action error.
