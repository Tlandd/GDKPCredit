assert(loadfile("tests/raid_profiles_spec.lua"))()
local A=GDKPCredit
local checks=0
local function check(label,actual,expected)
  assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
  checks=checks+1
end
-- Restore the production roster function after earlier award simulations.
assert(loadfile("Raid.lua"))()
local roster={"Alpha-Realm","Beta-Realm"}
GetNumGuildMembers=function() return #roster end
GetGuildRosterInfo=function(i) return roster[i],"Member",2 end
local group={player={"Alpha","Realm"},raid1={"Alpha","Realm"},raid2={"Beta","Realm"},
  raid3={"Guest","Realm"},raid4={"Visitor","Other"},raid5={"Outsider","Realm"},
  raid6={"Guest","Other"},raid7={"Alpha","Other"}}
UnitExists=function(unit) return group[unit]~=nil end
UnitFullName=function(unit) local entry=group[unit]; if entry then return unpack(entry) end end
UnitName=function(unit) local entry=group[unit]; if entry then return unpack(entry) end end
local raidMode,partyMode=true,false
IsInRaid=function() return raidMode end
IsInGroup=function() return partyMode end
GetNumGroupMembers=function() return 7 end
GetNumSubgroupMembers=function() return 3 end
GetGuildInfo=function() return "Gnome Pest Control","Accountant",2 end
C_GuildInfo.IsGuildOfficer=function() return true end
A.db.activeRaid=nil; A.db.trackingExceptions=nil; A.db.additionalMembersByGuild=nil
check("guild character eligible",A:IsTrackedCharacter("Beta"),true)
check("unguilded character excluded",A:IsTrackedCharacter("Guest"),false)
check("same-name foreign guild member excluded",A:IsTrackedCharacter("Alpha-Other"),false)
check("no guest automatically tracked",A:CurrentRoster().Guest,nil)
check("guild group member tracked",A:CurrentRoster().Beta,"raid2")
check("save exactly two exceptions",A:SaveTrackingExceptions({" Guest ","Visitor-Other"}),true)
check("local exception expanded",A:TrackingExceptions()[1],"Guest-Realm")
check("local exception included",A:CurrentRoster().Guest,"raid3")
check("cross-realm exception included",A:CurrentRoster()["Visitor-Other"],"raid4")
check("other unguilded member excluded",A:CurrentRoster().Outsider,nil)
check("exception name on wrong realm excluded",A:CurrentRoster()["Guest-Other"],nil)
check("exception does not grant officer",A:IsOfficer("Guest-Realm"),false)
check("cross-realm exception does not grant officer",A:IsOfficer("Visitor-Other"),false)
check("more than two members supported",A:SaveTrackingExceptions({"One","Two","Three"}),true)
check("restore test members",A:SaveTrackingExceptions({"Guest","Visitor-Other"}),true)
check("duplicate exceptions rejected",A:SaveTrackingExceptions({"Guest","guest-Realm"}),false)
check("invalid name rejected",A:SaveTrackingExceptions({"bad|name"}),false)
check("invalid input preserves guest",A:TrackingExceptions()[1],"Guest-Realm")
C_GuildInfo.IsGuildOfficer=function() return false end
check("nonofficer cannot modify exceptions",A:SaveTrackingExceptions({"Outsider"}),false)
C_GuildInfo.IsGuildOfficer=function() return true end
A.db.players.Guest={main="Guest",dkp=10}
check("start filtered raid",A:StartRaid("mc"),true)
check("guild member entered raid",A.db.activeRaid.players.Beta~=nil,true)
check("guest entered raid",A.db.activeRaid.players.Guest~=nil,true)
check("visitor keeps realm identity",A.db.activeRaid.players["Visitor-Other"]~=nil,true)
check("outsider not entered raid",A.db.activeRaid.players.Outsider,nil)
check("outsider not auto-created",A.db.players.Outsider,nil)
group.raid5={"Joiner","Realm"}; roster[#roster+1]="Joiner-Realm"
A:OnRosterUpdate()
check("late guild joiner tracked",A.db.activeRaid.players.Joiner~=nil,true)
check("late joiner not full attendance",A.db.activeRaid.players.Joiner.attendanceBroken,true)
A.CountTrackedAuras=function() return 10,10 end
A:RunReadinessCheck()
check("guest gets readiness checks",A.db.activeRaid.players.Guest.wb,true)
check("visitor gets readiness checks",A.db.activeRaid.players["Visitor-Other"].consumes,true)
check("unrelated player never checked",A.db.activeRaid.players["Guest-Other"],nil)
-- Existing outsiders from older versions remain in history but receive no new awards.
A.db.activeRaid.players.LegacyOutsider={char="LegacyOutsider",presentStart=true,attendanceOverride=true,wb=true,consumes=true}
A.db.players.LegacyOutsider={main="LegacyOutsider",dkp=77}
local before=A.db.players.Guest.dkp
local preview=A:RaidAwardPreview(0)
check("legacy outsider gets no awards",preview.players.LegacyOutsider.actual,0)
check("eligible guest earns DKP",preview.players.Guest.actual>0,true)
local _,summary=A:RaidView("",false)
check("view excludes legacy outsider",summary.total,5)
local snapshot=A:SerializeSnapshot()
A.db.trackingExceptions=nil; A.db.additionalMembersByGuild=nil
check("exceptions snapshot accepted",A:ApplySnapshot(snapshot,"Alpha-Realm"),true)
check("exceptions sync restored",A:TrackingExceptions()[2],"Visitor-Other")
check("untrusted guest cannot send snapshot",A:ApplySnapshot(snapshot,"Guest-Realm"),false)
local otherGuild=snapshot:gsub("TRACK\tgnome pest control%-realm", "TRACK\tother guild-realm")
check("wrong-guild exception snapshot rejected",A:ApplySnapshot(otherGuild,"Alpha-Realm"),false)
check("revoke local guest",A:SaveTrackingExceptions({"","Visitor-Other"}),true)
check("revoked guest excluded from roster",A:CurrentRoster().Guest,nil)
check("revoked guest awards blocked",A:RaidAwardPreview(0).players.Guest.actual,0)
A:SetRaidPass("Guest","attendance")
check("revoked guest cannot get manual pass",A.db.activeRaid.players.Guest.attendanceOverride,false)
-- Loading the guild roster must not mark everyone absent or award from partial data.
roster={}
local oldBroken=A.db.activeRaid.players.Alpha.attendanceBroken
A:OnRosterUpdate()
check("unloaded roster does not break attendance",A.db.activeRaid.players.Alpha.attendanceBroken,oldBroken)
check("unloaded roster blocks awards",A:RaidAwardPreview(0),nil)
A:EndRaid(0)
check("unloaded roster cannot end raid",A.db.activeRaid~=nil,true)
roster={"Alpha-Realm","Beta-Realm","Joiner-Realm"}
A:EndRaid(0)
check("old outsider balance preserved",A.db.players.LegacyOutsider.dkp,77)
check("guild ledger hides outsiders",#A:GuildView("LegacyOutsider"),0)
check("guild ledger shows exception",#A:GuildView("Visitor"),1)
check("revoked guest balance preserved",A.db.players.Guest.dkp,before)
check("allowed visitor receives award",A.db.players["Visitor-Other"].dkp>0,true)
GetGuildInfo=function() return "Different Guild","Officer",1 end
check("exceptions do not carry across guilds",#A:TrackingExceptions(),0)
GetGuildInfo=function() return "Gnome Pest Control","Accountant",2 end
raidMode=false; partyMode=true
group.party1={"Beta","Realm"}; group.party2={"Guest","Realm"}; group.party3={"Visitor","Other"}
check("party guild member included",A:CurrentRoster().Beta,"party1")
check("party revoked guest excluded",A:CurrentRoster().Guest,nil)
check("party exception included",A:CurrentRoster()["Visitor-Other"],"party3")
partyMode=false
check("solo guild player included",A:CurrentRoster().Alpha,"player")
print("PASS: "..checks.." guild-only tracking, exception, realm, award, and security checks (".._VERSION..")")
