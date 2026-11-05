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
2. Symlink `ForeverSkillManager/` into `World of Warcraft/_forever_/Interface/AddOns/` (see the README).
3. Edit, then `/reload` in game to pick up changes.

The addon can't be run outside the game, so test changes in the client and say what you tested in your pull request. CI runs [luacheck](https://github.com/lunarmodules/luacheck) on `ForeverSkillManager/`; if you use a new WoW API global, add it to `read_globals` in `.luacheckrc`.

## Code style

- Match the surrounding code: tabs for indentation, comments only where the reason isn't obvious.
- Keep everything in `ForeverSkillManager.lua` unless a file would clearly be easier to read split out. If you add a file, list it in `ForeverSkillManager.toc`.
- Wrap values returned by Blizzard APIs in `Val()` before comparing them, because Midnight-era APIs can return secret values.
- Changes to action bars must not run in combat. Defer them, as `Update()` does.
- Per-character data lives in `ForeverSkillManagerCharDB`; give new settings a default in `DEFAULTS`.

## Commits and pull requests

- Use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`.
- Keep a pull request to one change.
- Update `CHANGELOG.md` under "Unreleased" and the README if behaviour or commands change.
- Describe what you tested in the client.

## Releasing

Releases are cut by pushing a version tag, for example `git tag v0.2.0 && git push origin v0.2.0`. The Release workflow then:

1. Builds `ForeverSkillManager-<version>-forever.zip` with the TOC version filled in. The `-forever` suffix is how WowUp matches the asset to the Forever client.
2. Publishes a GitHub release with generated notes. A tag with a hyphen (`v0.2.0-alpha.1`) is a pre-release.
3. Uploads the same zip to CurseForge, if configured. Wago is notified by a GitHub webhook on release and reads the game version from the `-forever.zip` name.

The game patch is derived from the TOC `## Interface` line (`16001` becomes `1.60.1`). CurseForge must already list that Forever patch, or the upload fails.

To enable the CurseForge upload, add these in the repo's Settings > Secrets and variables > Actions. The step is skipped until both are set.

| Secret | Variable |
|--------|----------|
| `CF_API_TOKEN` | `CF_PROJECT_ID` |

Wago needs no secrets here. The Wago addon is linked to this repo with a webhook (Settings > Webhooks) that sends release events to `https://addons.wago.io/api/github/webhook`.

## Licence

By contributing you agree your work is released under the [MIT licence](LICENSE).
