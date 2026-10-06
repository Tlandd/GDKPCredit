assert(loadfile("tests/storage_spec.lua"))()
local A=GDKPCredit
local checks=0
local function check(label,a,b) assert(a==b,label..": "..tostring(a).." != "..tostring(b)); checks=checks+1 end
local rank=2; local character="Accountant"
GetGuildInfo=function() return "Role Test","Rank",rank end
UnitName=function() return character end
UnitFullName=function() return character,"Realm" end
local rows={{"Master-Realm","Master",0},{"Accountant-Realm","Accountant",2},{"Otherofficer-Realm","Officer",1},{"Beta-Realm","Member",3}}
GetNumGuildMembers=function() return #rows end
GetGuildRosterInfo=function(i) return unpack(rows[i]) end
GuildControlGetNumRanks=function() return 4 end
GuildControlGetRankName=function(i) return ({"Master","Officer","Accountant","Member"})[i] end
C_GuildInfo.IsGuildOfficer=function() return false end
C_GuildInfo.GuildControlGetRankFlags=function(i) return {[8]=i==2 or i==3} end
A:ActivateGuildLedger(); A:InitDB()
check("default is kick permission",A:PermissionPolicy().mode,"kick")
check("Accountant default access",A:IsOfficer(),true)
check("second kick rank default access",A:IsOfficer("Otherofficer-Realm"),true)
check("member denied",A:IsOfficer("Beta-Realm"),false)
check("wrong realm denied",A:IsOfficer("Accountant-Elsewhere"),false)
A:EnsurePlayer("Beta","Beta")
check("Accountant edits",A:AdjustDKP("Beta",5),true)
check("non GM cannot override",A:SaveAdminPolicy("ranks",{}),false)
character="Master"; rank=0
check("GM saves revocation",A:SaveAdminPolicy("ranks",{Officer=true}),true)
check("GM always allowed",A:IsOfficer(),true)
check("revoked kick rank denied",A:IsOfficer("Accountant-Realm"),false)
check("enabled rank allowed",A:IsOfficer("Otherofficer-Realm"),true)
character="Accountant"; rank=2
check("revoked self denied",A:IsOfficer(),false)
check("revoked edit blocked",A:AdjustDKP("Beta",5),false)
check("no unwanted edit",A.db.players.Beta.dkp,5)
character="Master"; rank=0
check("grant normally non kick rank",A:SaveAdminPolicy("ranks",{Member=true,Accountant=true}),true)
check("custom member rank granted",A:IsOfficer("Beta-Realm"),true)
check("Accountant reenabled",A:IsOfficer("Accountant-Realm"),true)
check("unselected officer denied",A:IsOfficer("Otherofficer-Realm"),false)
local policy
A.SendRaw=function(_,msg) policy=msg end
A:SendAdminPolicy()
check("GM policy accepted",A:ReceiveAdminPolicy(policy,"Master-Realm"),true)
check("admin cannot impersonate GM",A:ReceiveAdminPolicy(policy,"Accountant-Realm"),false)
check("unknown writer field cannot affect access",A:ReceiveAdminPolicy(policy.."|Otherofficer-Realm","Master-Realm"),false)
check("reset to default",A:SaveAdminPolicy("kick",{}),true)
C_GuildInfo.GuildControlGetRankFlags=nil
character="Accountant"; rank=2
check("missing permission API fails closed",A:IsOfficer(),false)
print("PASS: "..checks.." default kick permissions, multiple admins, GM overrides and sender checks (".._VERSION..")")
