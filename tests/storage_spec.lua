assert(loadfile("tests/permissions_spec.lua"))()
assert(loadfile("GuildStorage.lua"))()
local A=GDKPCredit
local n=0
local function check(label,a,b) assert(a==b,label..": "..tostring(a).." != "..tostring(b)); n=n+1 end
local guild="Gnome Pest Control"
GetGuildInfo=function() return guild,"Master",0 end
A.activeLedgerKey=nil
GDKPCreditDB=A.db
GDKPCreditDB.guildLedgers=nil; GDKPCreditDB.legacyLedgerGuild=nil
A.db.players.Alpha.dkp=77
A.db.treasury=321; A.db.reserve=21
A.db.localAccount={id="testaccount",guilds={}}
check("legacy activates",A:ActivateGuildLedger(),true)
A:InitDB()
check("legacy DKP retained",A.db.players.Alpha.dkp,77)
check("legacy treasury retained",A.db.treasury,321)
local first=A.db
check("original backup retained",GDKPCreditDB.players.Alpha.dkp,77)
guild="Other Guild"
check("other guild activates",A:ActivateGuildLedger(),true)
A:InitDB()
check("new guild empty",next(A.db.players),nil)
check("new treasury empty",A.db.treasury,0)
check("new reserve empty",A.db.reserve,0)
check("account identity shared",A.db.localAccount,first.localAccount)
A:EnsurePlayer("Beta","Beta"); A.db.players.Beta.dkp=99
local otherSnapshot=A:SerializeSnapshot()
guild="Gnome Pest Control"
check("return activates",A:ActivateGuildLedger(),true)
A:InitDB()
check("original DKP restored",A.db.players.Alpha.dkp,77)
check("new guild player excluded",A.db.players.Beta.dkp~=99,true)
check("foreign snapshot rejected",A:ApplySnapshot(otherSnapshot,"Master-Realm"),false)
local snapshot=A:SerializeSnapshot()
check("same guild snapshot accepted",A:ApplySnapshot(snapshot,"Master-Realm"),true)
check("unscoped snapshot rejected",A:ApplySnapshot(snapshot:gsub("GUILD[^\n]*\n",""),"Master-Realm"),false)
guild="Other Guild"; A:ActivateGuildLedger(); A:InitDB()
check("other guild DKP restored",A.db.players.Beta.dkp,99)
check("reload same ledger",A:ActivateGuildLedger(),false)
print("PASS: "..n.." guild ledger migration, switching, identity and snapshot checks (".._VERSION..")")
