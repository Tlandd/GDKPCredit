assert(loadfile("tests/account_links_spec.lua"))()
local A=GDKPCredit
local checks=0
local function check(label,actual,expected)
  assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
  checks=checks+1
end
local current="Alpha"
UnitFullName=function() return current,"Realm" end
UnitName=function() return current end
GetGuildInfo=function() return "Gnome Pest Control","Member",3 end
C_GuildInfo.IsGuildOfficer=function() return false end
A.db.localAccount.guilds={}; A.db.activeRaid=nil
local profiles=A:AccountLinkTables()
profiles[A.db.localAccount.id]=nil
local sent
A.SendRaw=function(_,message) sent=message end
local accountID=A.db.localAccount.id
A:ShowMemberProfile()
check("nonofficer profile opens",A.memberProfileFrame.shown,true)
local rows,main,target=A:MemberProfileView()
check("first character discovered",#rows,1)
check("first preferred main",main,"Alpha")
check("initial status not submitted",rows[1].status,"Not submitted")
check("unseen main rejected",A:SetMyPreferredMain("Unseen"),false)
check("member can submit current character",A:SubmitMyCharacter(),true)
check("request uses persistent account ID",sent:find("H|"..accountID,1,true)~=nil,true)
rows=A:MemberProfileView()
check("sent request status pending",rows[1].status,"Waiting for sync / review")
current="Beta"
A:LearnAccountCharacter()
rows=A:MemberProfileView()
check("alt discovered automatically",#rows,2)
check("same account identity on alt",A.db.localAccount.id,accountID)
check("choose discovered alt as preferred main",A:SetMyPreferredMain("Beta"),true)
rows,main=A:MemberProfileView()
check("preferred main saved",main,"Beta")
check("chosen main ordered first",rows[1].name,"Beta")
check("changing main does not change approved ledger",A.db.players.Alpha.dkp,190)
A:SubmitMyCharacter()
check("request sends preferred main",sent:find("H|"..accountID,1,true)~=nil,true)
profiles[accountID]="Alpha"
A.db.characterMap.Beta="Alpha"; A.db.characterMap["Beta-Realm"]="Alpha"
A:RefreshMemberProfile()
rows,main,target=A:MemberProfileView()
check("approved account target shown",target,"Alpha")
check("approved linked character status",rows[1].status,"Linked")
check("local preferred main remains independent",main,"Beta")
check("UI approved row updated",A.memberProfileFrame.rows[1].status.text,"Linked")
local guildProfile=A.db.localAccount.guilds[A:TrackingGuildKey()]
for i=1,20 do
  local name="Alt"..string.char(65+i).."-Realm"
  guildProfile.characters[A:GuildIdentity(name)]={name=name}
end
A:RefreshMemberProfile()
check("profile pagination enabled",A.memberProfileFrame.next.enabled,true)
A.memberProfileFrame.next.scripts.OnClick()
check("profile next page",A.memberProfileFrame.page,2)
local row=A.memberProfileFrame.rows[1]
local chosen=row.character
row.choose.scripts.OnClick()
check("row button selects main",guildProfile.main,chosen)
check("selecting main still preserves DKP",A.db.players.Alpha.dkp,190)
local snapshot=A:SerializeSnapshot()
profiles[accountID]=nil
C_GuildInfo.GuildControlGetRankFlags=function() return {[3]=true} end
check("officer snapshot accepted by member",A:ApplySnapshot(snapshot,"Alpha-Realm"),true)
rows,main,target=A:MemberProfileView()
check("approved target restored by synchronization",target,"Alpha")
check("local discovered characters survive snapshot",#rows,22)
check("preferred main survives synchronization",main,chosen)
check("local account ID survives snapshot",A.db.localAccount.id,accountID)
GetGuildInfo=function() return "Other Guild","Member",3 end
rows,main=A:MemberProfileView()
check("other guild discovery separate",#rows,1)
check("other guild defaults to current character",main,"Beta")
GetGuildInfo=function() return "Gnome Pest Control","Member",3 end
rows,main=A:MemberProfileView()
check("original guild characters preserved",#rows,22)
check("original guild preference preserved",main,chosen)
IsInGuild=function() return false end
GetGuildInfo=function() return nil end
A:RefreshMemberProfile()
check("manual submit control removed",A.memberProfileFrame.submit,nil)
check("unguilded submission refused",A:SubmitMyCharacter(),false)
print("PASS: "..checks.." member profile discovery, UI, main selection, request status, and synchronization checks (".._VERSION..")")
