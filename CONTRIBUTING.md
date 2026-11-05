# Contributing

Thanks for helping out. This is a small project, so the process is light.

## Reporting a bug

Open an issue and include:

- What you expected and what happened
- The output of `/fskills debug`
- Any Lua error text (install a tool such as BugSack if errors are hidden)
- If you saw "interface action failed because of an addon": run `/console taintLog 2`, reproduce it, and attach `Logs/taint.log` from the `_forever_` folder

## Development setup

There is no build step. The addon is plain Lua.

1. Clone the repo.
2. Symlink `ForeverSkills/` into `World of Warcraft/_forever_/Interface/AddOns/` (see the README).
3. Edit, then `/reload` in game to pick up changes.

The addon can't be run outside the game, so test changes in the client and say what you tested in your pull request. CI runs [luacheck](https://github.com/lunarmodules/luacheck) on `ForeverSkills/`; if you use a new WoW API global, add it to `read_globals` in `.luacheckrc`.

## Code style

- Match the surrounding code: tabs for indentation, comments only where the reason isn't obvious.
- Keep everything in `ForeverSkills.lua` unless a file would clearly be easier to read split out. If you add a file, list it in `ForeverSkills.toc`.
- Wrap values returned by Blizzard APIs in `Val()` before comparing them, because Midnight-era APIs can return secret values.
- Changes to action bars must not run in combat. Defer them, as `Update()` does.
- Per-character data lives in `ForeverSkillsCharDB`; give new settings a default in `DEFAULTS`.

## Commits and pull requests

- Use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`.
- Keep a pull request to one change.
- Update `CHANGELOG.md` under "Unreleased" and the README if behaviour or commands change.
- Describe what you tested in the client.

## Licence

By contributing you agree your work is released under the [MIT licence](LICENSE).
