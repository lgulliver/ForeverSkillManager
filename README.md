# ForeverSkillManager

An addon for [World of Warcraft: Forever](https://worldofwarcraft.blizzard.com/) that handles action bar upkeep the way retail does by default. Works with the default Blizzard bars and Bartender4.

- **New spells are placed for you.** When you learn a spell, it goes into the first empty slot of a visible default action bar. If every visible slot is full, you get a chat message instead.
- **Ranks stay current.** When you learn a higher rank of a spell on your bars (Holy Light rank 1 to rank 2), the old rank is swapped for the new one in the same slot. Macros, items and other spells are never touched.
- **Combat-safe.** Blizzard blocks action bar changes in combat, so anything learned mid-fight is applied when combat ends.

## Install

Requires the WoW Forever client (interface `16001`).

1. Download this repo (Code > Download ZIP, or `git clone`), then copy or symlink the `ForeverSkillManager` folder into
   `World of Warcraft/_forever_/Interface/AddOns/`.
2. Start the game, or `/reload` if it's already running.

For development, a symlink means edits in this repo show up in the game folder immediately:

```sh
ln -s "$PWD/ForeverSkillManager" "/path/to/World of Warcraft/_forever_/Interface/AddOns/ForeverSkillManager"
```

## Usage

| Command | What it does |
|---------|--------------|
| `/fskills` | Open the settings panel (not available in combat) |
| `/fskills sync` | Catch up now: upgrade ranks and place every known spell that isn't on a bar |
| `/fskills debug` | Print visible bars, fill order, first empty slot and spell counts |
| `/fskills reset` | Clear the recorded spell baseline |

`/fsm` and `/fskill` work as aliases.

On a character's first login the addon only records what you already know and places nothing. Run `/fskills sync` once if you want your existing spells placed.

## Bartender4

If Bartender4 is loaded, ForeverSkillManager reads its bars instead of the Blizzard ones: enabled bars that are currently shown (so bars hidden by a visibility rule are skipped) and only the buttons each bar actually has. Without Bartender4 nothing changes. `/fskills debug` shows which bar source is in use.

## Settings

Esc > Options > AddOns > ForeverSkillManager. All settings are saved per character.

- Place new spells and upgrade spell ranks, each on or off
- Chat messages: everything, warnings only, or silent
- Which bars may receive new spells, and the fill order (by screen position, or a fixed order)
  - With Bartender4 loaded, the list shows the Bartender bars you have enabled (a bar you enable later appears after a `/reload`). Only currently visible bars are filled, and a bar with fewer than 12 buttons only uses the buttons it has.
- An ignore list of spells that are never placed or upgraded

Rank upgrades happen on any bar, including ones you've excluded from placement.

## Limitations

- Works with the **default Blizzard action bars** and **Bartender4**. Other bar addons (Dominos, ElvUI and so on) aren't supported.
- On the default bars, the main bar is treated as page 1 (slots 1 to 12). On another bar page or in a stance, a new spell can land on a page you can't see.
- Passive, off-spec and level-locked spells are skipped.
- Early release. `/fskills sync`, the settings panel and Bartender4 support have been tested in the live client. Automatic placement the moment you learn a spell has had less testing, so run `/fskills sync` if a spell is ever missed.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports are welcome; `/fskills debug` output makes them much easier to act on.

## Licence

[MIT](LICENSE)
