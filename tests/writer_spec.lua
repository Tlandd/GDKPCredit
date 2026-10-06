assert(loadfile("tests/storage_spec.lua"))()
local A=GDKPCredit
local n=0
local function check(label,a,b) assert(a==b,label..": "..tostring(a).." != "..tostring(b)); n=n+1 end
local guild="Writer Test"
local rank=0
local character="Master"
GetGuildInfo=function() return guild,"Rank",rank end
UnitFullName=function() return character,"Realm" end
UnitName=function() return character end
local rows={{"Master-Realm","Master",0},{"Officer-Realm","Accountant",2},{"Beta-Realm","Member",3}}
GetNumGuildMembers=function() return #rows end
GetGuildRosterInfo=function(i) return unpack(rows[i]) end
GuildControlGetRankName=function(i) return ({"Master","Officer","Accountant","Member"})[i] end
C_GuildInfo.GuildControlGetRankFlags=function(i) return {[8]=i==3,[11]=i==3} end
C_GuildInfo.IsGuildOfficer=function() return rank==2 end
A:ActivateGuildLedger(); A:InitDB()
check("GM is default writer",A:IsOfficer(),true)
check("other officer denied by default",A:IsOfficer("Officer-Realm"),false)
check("choose writer",A:SaveAdminPolicy("ranks",{Accountant=true},"Officer-Realm"),true)
check("GM no parallel ledger writes",A:IsOfficer(),false)
check("GM keeps policy control",A:IsAdmin(),true)
check("selected writer remote allowed",A:IsOfficer("Officer-Realm"),true)
check("member cannot write",A:IsOfficer("Beta-Realm"),false)
check("writer realm mismatch denied",A:IsOfficer("Officer-Elsewhere"),false)
character="Officer"; rank=2
check("selected writer self allowed",A:IsOfficer(),true)
A:EnsurePlayer("Beta","Beta")
check("writer adjustment succeeds",A:AdjustDKP("Beta",5),true)
character="Master"; rank=0
check("GM adjustment blocked",A:AdjustDKP("Beta",5),false)
check("blocked edit retains balance",A.db.players.Beta.dkp,5)
check("ineligible writer rejected",A:SaveAdminPolicy("ranks",{Accountant=true},"Beta-Realm"),false)
check("unknown writer rejected",A:SaveAdminPolicy("ranks",{Accountant=true},"Fake-Realm"),false)
check("return writer to GM",A:SaveAdminPolicy("ranks",{Accountant=true},"Master-Realm"),true)
check("GM writes restored",A:IsOfficer(),true)
check("old writer revoked",A:IsOfficer("Officer-Realm"),false)
local old=A.db
guild=nil; A:ActivateGuildLedger(); A:InitDB()
check("unguilded ledger empty",next(A.db.players),nil)
guild="Writer Test"; A:ActivateGuildLedger(); A:InitDB()
check("guild data survives leaving",A.db.players.Beta.dkp,5)
check("account identity retained",A.db.localAccount,old.localAccount)
A.activeLedgerKey=nil; A:InitDB()
check("reload picks stored guild",A.db.players.Beta.dkp,5)
check("writer policy persists reload",A:LedgerOfficer(),"master-realm")
check("identity persists reload",A.db.localAccount,old.localAccount)
print("PASS: "..n.." single writer, handover, rejected edits and unguilded storage checks (".._VERSION..")")
