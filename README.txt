GDKP Credit — v0.1.0 Beta
=========================

GDKP Credit adds a persistent DKP and gold-backed guild-credit layer on top of a normal GDKP raid system.

INSTALL
1. Install with the CurseForge app, or place the entire GDKPCredit folder in:
   World of Warcraft/_classic_era_/Interface/AddOns/
2. Launch WoW and enable "GDKP Credit".
3. Type /gdkpcredit or /gdkpc to open the interface.

COMPATIBILITY
- WoW Classic Era 1.15.9
- Interface 11509

DEFAULT RULES
- Full attendance: 4 DKP
- 3+ tracked world buffs: 3 DKP
- 2+ tracked consume buffs: 3 DKP
- Maximum prepared-raid award: 10 DKP
- DKP cap: 200
- Guild cut: 10% of gross GDKP pot
- Guild Credit = floor(Current DKP x Gold/DKP)
- Gold/DKP = (Treasury - Reserve) / total outstanding DKP

READINESS CHECKS
The WB + Consume Check is manual. An officer can run it when the raid is expected to be unbooned rather than at zone-in.

Readiness is upgrade-only for the entire raid:
- No -> Yes is allowed.
- Yes -> No is never applied by an automatic recheck.

A player who passes the world-buff check and later dies will keep that pass.

OFFICER / MEMBER SYNC
- Members are read-only.
- Guild rank 0 and 1 are treated as officer/admin by default.
- Officers hold the authoritative data and broadcast data-version changes.
- Members request and cache a full snapshot through Blizzard addon messages.
- Offline members retain their last synchronized data.

FIRST-TIME SETUP FOR A NEW GUILD
1. An officer opens Admin.
2. Set Treasury and Reserve.
3. Use Character Alias / Mapping to map each raid character to its player identity.
   Saving a new mapping also creates that player if needed.
4. Use Manual DKP Adjustment to enter starting DKP balances.
5. Other members install the addon and press Sync Now.

RAID FLOW
1. Officer presses Start Raid.
2. Raid normally; players may remain booned.
3. When the raid is expected to unboon, press WB + Consume Check.
4. Recheck later if needed. Existing passes cannot be downgraded.
5. Use the selected-player controls only when an officer needs to correct a missed check.
6. Enter the gross GDKP pot.
7. Press End Raid + Award DKP.
8. The addon awards DKP and adds the configured guild cut to Treasury.

NAME MAPPING
Character-to-player mappings allow mains, alts, alternate spellings, and special-character aliases to share one person-based DKP balance.

CONSUME DETECTION
The addon can only count aura/buff states exposed by the WoW API for raid units. The default list includes common flasks, elixirs, food buffs, Jujus, Firewater, and Blasted Lands buffs. Instant-use potions and some temporary weapon enchants are not reliably visible on other raid members and are not counted by the automatic 2+ check.

DATA / BACKUPS
Officer data is stored locally in SavedVariables and synchronized to members through addon communication. Keep periodic Full Snapshot exports as a backup.

UPGRADING FROM THE OLD GPCDKP BETA
If the original GPCDKP build was installed previously, GDKP Credit will automatically migrate its saved database on first load.

SLASH COMMANDS
/gdkpcredit          Open/close the main interface
/gdkpc               Same as above
/gdkpcredit sync     Request a guild sync
/gdkpcredit version  Show addon/data version
