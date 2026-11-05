# forever-skills

Addons for [World of Warcraft: Forever](https://worldofwarcraft.blizzard.com/). Currently one addon:

## ForeverSkills

Action bar upkeep, the way retail does it by default.

- **New spells are placed for you.** When you learn a spell, it goes into the first empty slot of a visible default action bar. If every visible slot is full, you get a chat message instead.
- **Ranks stay current.** When you learn a higher rank of a spell on your bars (Holy Light rank 1 to rank 2), the old rank is swapped for the new one in the same slot. Macros, items and other spells are never touched.
- **Combat-safe.** Blizzard blocks action bar changes in combat, so anything learned mid-fight is applied when combat ends.

### Install

Requires the WoW Forever client (interface `16001`).

1. Copy or symlink the `ForeverSkills` folder into
   `World of Warcraft/_forever_/Interface/AddOns/`.
2. Start the game, or `/reload` if it's already running.

For development, a symlink means edits in this repo show up in the game folder immediately:

```sh
ln -s "$PWD/ForeverSkills" "/path/to/World of Warcraft/_forever_/Interface/AddOns/ForeverSkills"
```

### Usage

| Command | What it does |
|---------|--------------|
| `/fskills` | Open the settings panel (not available in combat) |
| `/fskills sync` | Catch up now: upgrade ranks and place every known spell that isn't on a bar |
| `/fskills debug` | Print visible bars, fill order, first empty slot and spell counts |
| `/fskills reset` | Clear the recorded spell baseline |

`/fskill` works as an alias.

On a character's first login the addon only records what you already know and places nothing. Run `/fskills sync` once if you want your existing spells placed.

### Settings

Esc > Options > AddOns > ForeverSkills. All settings are saved per character.

- Place new spells and upgrade spell ranks, each on or off
- Chat messages: everything, warnings only, or silent
- Which bars may receive new spells, and the fill order (by screen position, or a fixed order)
- An ignore list of spells that are never placed or upgraded

Rank upgrades happen on any bar, including ones you've excluded from placement.

### Limitations

- Built for the **default Blizzard action bars**. Bar addons such as Bartender, Dominos or ElvUI aren't supported.
- The main bar is treated as page 1 (slots 1 to 12). On another bar page or in a stance, a new spell can land on a page you can't see.
- Passive, off-spec and level-locked spells are skipped.
- Early release. Placement on level-up and rank swaps have had limited testing in the live client.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports are welcome; `/fskills debug` output makes them much easier to act on.

## Licence

[MIT](LICENSE)
