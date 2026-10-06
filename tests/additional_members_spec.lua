assert(loadfile("tests/membership_spec.lua"))()
local A=GDKPCredit
local checks=0
local function check(label,actual,expected)
  assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
  checks=checks+1
end
C_GuildInfo.IsGuildOfficer=function() return true end
A.db.activeRaid=nil
A.db.additionalMembersByGuild=nil
A.db.trackingExceptions={guild=A:TrackingGuildKey(),names={"Guest-Realm","Visitor-Other"}}
A:InitAdditionalMembers()
check("legacy entries migrated",#A:TrackingExceptions(),2)
check("legacy first preserved",A:TrackingExceptions()[1],"Guest-Realm")
check("legacy storage retired",A.db.trackingExceptions,nil)
check("add a third member",A:AddAdditionalMember("Third"),true)
check("third included",A:IsTrackedCharacter("Third-Realm"),true)
check("duplicate add rejected",A:AddAdditionalMember("third-Realm"),false)
check("blank add rejected",A:AddAdditionalMember("  "),false)
check("empty realm rejected",A:AddAdditionalMember("Bad-"),false)
check("remove individual member",A:RemoveAdditionalMember("third-Realm"),true)
check("removed member excluded",A:IsTrackedCharacter("Third"),false)
check("remove missing member",A:RemoveAdditionalMember("Missing"),false)
check("other entries retained",#A:TrackingExceptions(),2)
local names={}
for i=1,135 do names[i]="Member"..string.char(65+math.floor((i-1)/26))..string.char(65+(i-1)%26).."-Realm" end
check("long list accepted",A:SaveTrackingExceptions(names),true)
check("long list size",#A:TrackingExceptions(),135)
check("last member eligible",A:IsTrackedCharacter(names[135]),true)
check("additional member not officer",A:IsOfficer(names[135]),false)
check("search literal brackets",#A:AdditionalMembersView("["),0)
check("case insensitive search",#A:AdditionalMembersView("memberaa"),1)
check("list sorted",A:AdditionalMembersView("")[1],names[1])
A:ShowAdditionalMembers()
local f=A.membersFrame
check("manager opens",f.shown,true)
check("first row displayed",f.rows[1].character,names[1])
check("next page available",f.next.enabled,true)
f.next.scripts.OnClick()
check("next page works",f.page,2)
check("next page content",f.rows[1].character,names[11])
f.search:SetText("memberfe")
check("search resets page",f.page,1)
check("search displays correct member",f.rows[1].character,names[135])
check("single result disables next",f.next.enabled,false)
f.rows[1].remove.scripts.OnClick()
check("remove control updates eligibility",A:IsTrackedCharacter(names[135]),false)
check("remove preserves remaining list",#A:TrackingExceptions(),134)
f.input:SetText("Newcomer-Other")
f.add.scripts.OnClick()
check("add control updates eligibility",A:IsTrackedCharacter("Newcomer-Other"),true)
check("add input cleared",f.input:GetText(),"")
check("search cleared after add",f.search:GetText(),"")
C_GuildInfo.IsGuildOfficer=function() return false end
A:RefreshAdditionalMembers()
check("nonofficer add disabled",f.add.enabled,false)
check("nonofficer remove disabled",f.rows[1].remove.enabled,false)
check("nonofficer add API denied",A:AddAdditionalMember("Unauthorized"),false)
check("nonofficer remove API denied",A:RemoveAdditionalMember(names[1]),false)
C_GuildInfo.IsGuildOfficer=function() return true end
local snapshot=A:SerializeSnapshot()
local guild=A:TrackingGuildKey()
A.db.additionalMembersByGuild[guild]={}
check("long list sync accepted",A:ApplySnapshot(snapshot,"Alpha-Realm"),true)
check("long list all entries restored",#A:TrackingExceptions(),135)
check("synced newest member",A:IsTrackedCharacter("Newcomer-Other"),true)
check("duplicate synced member rejected",A:ApplySnapshot(snapshot.."\nTM\t"..names[1],"Alpha-Realm"),false)
check("invalid sync preserves list",#A:TrackingExceptions(),135)
check("legacy two-name snapshot accepted",A:ApplySnapshot("META\t"..A.db.version.."\t0\t0\nTRACK\t"..guild.."\tGuest-Realm\tVisitor-Other","Alpha-Realm"),true)
check("legacy snapshot restores both",#A:TrackingExceptions(),2)
GetGuildInfo=function() return "Other Guild","Officer",2 end
A.db.adminPoliciesByGuild[A:TrackingGuildKey()]={mode="officer",ranks={},revision=0}
check("other guild starts with empty list",#A:TrackingExceptions(),0)
check("other guild can add its own member",A:AddAdditionalMember("OtherMember"),true)
GetGuildInfo=function() return "Gnome Pest Control","Accountant",2 end
check("original guild list preserved",#A:TrackingExceptions(),2)
check("other guild member excluded",A:IsTrackedCharacter("OtherMember"),false)
GetGuildInfo=function() return "Other Guild","Officer",2 end
A.db.adminPoliciesByGuild[A:TrackingGuildKey()]={mode="officer",ranks={},revision=0}
check("second guild list preserved",A:TrackingExceptions()[1],"OtherMember-Realm")
check("remove final member",A:RemoveAdditionalMember("OtherMember"),true)
local emptySnapshot=A:SerializeSnapshot()
check("empty list sync accepted",A:ApplySnapshot(emptySnapshot,"Alpha-Realm"),true)
check("empty list remains empty",#A:TrackingExceptions(),0)
print("PASS: "..checks.." Additional Members UI, migration, long-list sync, guild separation, and permission checks (".._VERSION..")")
