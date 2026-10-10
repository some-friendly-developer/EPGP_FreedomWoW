# EPGP Freedom WoW

WoW 3.3.5a (interface 30300) EPGP pack for the guild Ghost of Azeroth on Freedom WoW. The interface is Ukrainian when the game language is Russian. An English client shows the English strings.

| Folder | Version | Who needs it |
| --- | --- | --- |
| `EPGP` | 5.6.0 | Everyone |
| `epgp_lootmaster` | 0.4.7 | Everyone who answers loot popups |
| `epgp_lootmaster_ml` | 0.4.7 | The master looter |
| `epgp_standin` | 1.0.0 | The master looter, when someone plays on another character's EP/GP |
| `epgp_battlegrounds` | 1.1.0 | Everyone who should take part in battleground EP |

## Install

1. Download this repository as a ZIP, or clone it.
2. Copy these folders into the game's `Interface\AddOns` directory:
   - `EPGP`
   - `epgp_lootmaster`
   - `epgp_lootmaster_ml`
   - `epgp_standin`
   - `epgp_battlegrounds`
3. Leave the folder names exactly as they are. WoW loads an addon only when `Interface\AddOns\<Folder>\<name>.toc` sits directly in `AddOns`. An extra `EPGP_FreedomWoW` folder around them keeps them from loading.
4. Restart the client. The addon list reads the version from the `.toc` file and keeps that cached until a full restart. `/reload` is enough for the Lua itself.
5. On the character screen, enable the addons from the table above. A raider who never master-loots can leave **EPGP LootMaster - ML** and **Stand-In** disabled.
6. Log in on a guild character. EPGP reads the guild roster and officer notes.

Settings and the EP/GP log are stored in `WTF\Account\<Account>\SavedVariables\`, not in this repository. Replacing the addon folders on an update leaves that data in place.

## EPGP

The standings window. Effort points and gear points live in guild officer notes, and priority is EP divided by GP.

- `/epgp` opens and closes the standings window.
- `/epgp config` opens the settings.
- The minimap button opens the standings on left click and the settings on right click. **Show minimap button** on the EPGP options page hides it.
- The search box filters the list to names that match. **Show everyone** includes guild members who are outside the current raid.

Officers with permission to edit officer notes can award EP, credit GP, and decay from the same window.

## EPGP LootMaster

Raid loot on top of EPGP. Install the core and the master looter module as two separate addons.

**Core** (`epgp_lootmaster`) is the raider side. When the master looter sends an item, a popup asks each player to answer with one of the configured buttons (main spec, off spec, and so on) or to pass. Open its settings with `/lm config`.

**Master looter** (`epgp_lootmaster_ml`) is the officer side. On entering a raid as raid leader it asks whether this raid should distribute loot by EP/GP. From then on it watches loot, lists each candidate with EP, GP, and priority, and writes GP to the officer note of the person who receives the item. The same `/lm` commands drive it:

- `/lm config` opens the settings.
- `/lm show` and `/lm hide` open and close the master looter window.
- `/lm raidinfo` shows raid lockouts.

Raiders who only need to answer popups can disable the ML addon. The master looter needs both.

## Stand-In

Maps a raider onto another character's EP/GP for the current raid. Typical case: an alt, or a recruit playing while the main's standings should be used.

When Arthas is standing in for Lichking:

- the master looter window still shows Arthas, labeled `Arthas (Lichking)`, so he can be whispered;
- EP, GP, priority, and minimum EP on that row are Lichking's, so sorting by priority ranks Arthas with Lichking's score;
- EP and GP written for Arthas are stored on Lichking's officer note.

The list is account-wide, so it survives logout. Only the master looter needs this addon installed. The hook sits on the master looter's EP/GP lookup.

- `/standin` opens the window.
- `/standin add <raider> <stand-in>` adds a mapping.
- `/standin remove <raider>` removes one.
- `/standin list` prints the list.
- `/standin on` and `/standin off` turn every mapping on or off without deleting them.
- `/standin clear` empties the list.

It requires EPGP LootMaster. Open the same page from the EPGP options window.

## Battlegrounds

After a battleground ends, the addon stores the final scoreboard. Once you are teleported out, one guild member is asked to hand out the EP. Everyone else gets a chat line naming that person.

Who hands it out:

- candidates are guild members on the scoreboard who match the rule in the settings: one exact guild rank, or a public-note tag such as `@pvp`;
- the alphabetically first of those candidates gets the reward window;
- sorting the scoreboard by healing, killing blows, or any other column does not change the choice;
- if that person never claims the job, the next candidate claims a few seconds later, so a disconnect does not leave the battleground unrewarded.

Who receives it is a second rule: a guild rank, a public-note tag, or every guild member on the scoreboard. The reward window lists the matches already ticked, and the distributor can untick people before confirming. The default amount is 150 EP. The reason written to the EPGP log is the text from the settings, `BG` unless you change it.

Every officer who might be the distributor needs the same rules and this addon. The claim travels as a guild addon message, so a client without the addon cannot take or yield the job. Set this under EPGP options, or with `/bgep`.

- `/bgep` opens the settings.
- `/bgep show` opens the reward window for the last scoreboard.
- `/bgep who` prints who would hand out the EP, and how many members would receive it.
- `/bgep on` and `/bgep off` enable or disable recording.
- `/bgep forget` discards the stored scoreboard.

## Credits

Ukrainian translation and the Stand-In and Battlegrounds plugins: Sixset, guild Ghost of Azeroth, server Freedom WoW.

EPGP was written by Alkis Evlogimenos. EPGP LootMaster was written by Bushmaster.
