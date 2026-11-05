# Changelog

All notable changes to ForeverSkills. Format follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added
- luacheck lint workflow and `.luacheckrc`.
- Bartender4 support: fills Bartender's enabled, visible bars and respects each bar's button count.

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
