assert(loadfile("tests/decay_spec.lua"))()
assert(loadfile("Permissions.lua"))()
local A=GDKPCredit
local n=0
local function check(label,a,b) assert(a==b,label..": "..tostring(a).." != "..tostring(b)); n=n+1 end
local rank=0
GetGuildInfo=function() return "Gnome Pest Control","Rank",rank end
GetNumGuildMembers=function() return 4 end
local roster={{"Master-Realm","Master",0},{"Officer-Realm","Accountant",2},{"Beta-Realm","Member",3},{"Other-Elsewhere","Accountant",2}}
GetGuildRosterInfo=function(i) return unpack(roster[i]) end
GuildControlGetNumRanks=function() return 4 end
GuildControlGetRankName=function(i) return ({"Master","Officer","Accountant","Member"})[i] end
C_GuildInfo.IsGuildOfficer=function() return true end
C_GuildInfo.GuildControlGetRankFlags=function(i) return {[8]=i==3} end
A.db.adminPoliciesByGuild={}
local outgoing
A.SendRaw=function(_,msg) outgoing=msg end
check("GM saves rank policy",A:SaveAdminPolicy("ranks",{Accountant=true}),true)
check("policy broadcast",outgoing:match("^PERM|")~=nil,true)
check("GM retains access",A:IsOfficer(),true)
rank=2
check("selected self",A:IsOfficer(),true)
check("selected remote",A:IsOfficer("Officer-Realm"),true)
check("unselected remote",A:IsOfficer("Beta-Realm"),false)
check("realm impostor denied",A:IsOfficer("Officer-Elsewhere"),false)
check("non GM cannot save",A:SaveAdminPolicy("officer",{}),false)
check("non GM cannot send policy",A:ReceiveAdminPolicy(outgoing,"Officer-Realm"),false)
check("GM policy received",A:ReceiveAdminPolicy(outgoing,"Master-Realm"),true)
check("foreign GM rejected",A:ReceiveAdminPolicy(outgoing,"Master-Elsewhere"),false)
local guild=A:TrackingGuildKey()
check("stale policy rejected",A:ReceiveAdminPolicy("PERM|"..guild.."|0|officer|","Master-Realm"),false)
check("crossguild rejected",A:ReceiveAdminPolicy("PERM|other|999999999|officer|","Master-Realm"),false)
check("invalid mode rejected",A:ReceiveAdminPolicy("PERM|"..guild.."|999999999|bad|","Master-Realm"),false)
rank=0
check("kick mode saves",A:SaveAdminPolicy("kick",{}),true)
rank=2
check("kick self allowed",A:IsOfficer(),true)
check("kick remote allowed",A:IsOfficer("Officer-Realm"),true)
check("non kicker denied",A:IsOfficer("Beta-Realm"),false)
C_GuildInfo.GuildControlGetRankFlags=nil
check("missing API fails closed",A:IsOfficer(),false)
rank=0
check("empty custom policy saves",A:SaveAdminPolicy("ranks",{}),true)
check("empty policy keeps GM",A:IsOfficer(),true)
rank=2
check("empty policy denies officer",A:IsOfficer(),false)
rank=0
check("unknown rank rejected",A:SaveAdminPolicy("ranks",{Fake=true}),false)
A:ShowAdminPermissions()
check("GM settings opens",A.permissionsFrame.shown,true)
print("PASS: "..n.." Guild Master policy, rank, kick permission, realm, and synchronization checks (".._VERSION..")")
