GDKP Credit â€” 0.2.0-rc1
=======================
Classic Era addon. This release candidate needs the live acceptance checklist before a stable release.

INSTALL
Extract GDKPCredit into World of Warcraft/_classic_era_/Interface/AddOns/.
All guild participants should install the same version. Open with /gdkpc.
Use /gdkpc version and /gdkpc officer for diagnostics.

FIRST SETUP
Open Admin: enter Guild Gold and Gold Held Back, then Save Gold.
Choose raid-specific awards on Raid Settings.
Members' characters register and link automatically as they log in with the addon.
Use Review Character Links for conflicts; manual links do not merge existing balances.
Add invited outsiders through Non-Guild Members. Guest status never grants admin access.
Only the Guild Master can open Who Can Manage DKP, choose eligible admin ranks,
and designate one ledger officer. By default the Guild Master is the ledger officer.
For an existing guild using an Accountant, choose that character before making new changes.
Other eligible admins can view the Admin page but its editing controls are disabled.

RAIDS
Choose a Classic raid before starting. Its award rules are fixed for that raid.
Run the world buff and consume check while the raid is unbooned.
The addon counts recognized active aura spell IDs, not bags or potion usage.
Default thresholds: 3 world buffs and 2 persistent consumes. Passing is preserved after death.
Default awards: attendance 4, world buffs 3, consumes 3; cap 200; guild cut 10%.
Review the final award preview before confirming the raid's completion.

INACTIVITY DECAY
Disabled by default. Enable under Admin -> Inactivity Decay.
Defaults: first deduction after 30 days without actual DKP gain; deduct 15 every 7 days.
Actual gains across linked characters reset the clock; capped zero gains do not.
Balances stop at zero; missed deductions catch up when an authorized admin is online.
Changed rules start a fresh inactivity period. Deductions are recorded in History.

STORAGE AND SYNCHRONIZATION
Balances, gold, history, raids and settings are separated by guild name and realm.
The account identity remains shared across characters. Leaving a guild does not delete its ledger.
The original pre-split ledger is preserved in SavedVariables; first guild activation migrates it.
Guild-scoped snapshots reject other guilds and unscoped older snapshots.
Permission policy is accepted only directly from the current Guild Master, who must be online to sync it.
Regular members cannot change guild balances, rules or admin permissions.
Only the designated ledger officer can change balances, run raids or apply decay.
Snapshots are accepted only from that officer. This prevents independent officer edits.
For handover: stop editing, sync the new officer from the old officer, then have the GM
change the designated character. The old officer must receive the updated policy before
resuming activity. Do not perform an offline handover: stale disconnected clients cannot
know a new designation until they receive it. Keep the GM online during initial setup.

BACKUP
Before upgrading, exit WoW and copy WTF/Account/<account>/SavedVariables/GDKPCredit.lua
and GDKPCredit.lua.bak if present. These files contain your balances and account-link credentials.
Admin -> Copy Guild Backup provides a copyable guild snapshot without private account codes.
For full recovery, use the SavedVariables backup while WoW is closed.
