assert(loadfile("tests/auto_account_spec.lua"))()
local A=GDKPCredit
local checks=0
local function check(label,actual,expected)
  assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
  checks=checks+1
end
A.db.activeRaid=nil
C_GuildInfo.IsGuildOfficer=function() return true end
local code=string.rep("a",48)
local profiles=A:AccountLinkTables()
profiles.autoOne="Alpha"; A:AccountCredentials().autoOne=code
A.db.players.Alpha={main="Alpha",alts={"Joiner-Realm"},dkp=35}
A.db.characterMap.Alpha="Alpha"; A.db.characterMap["Alpha-Realm"]="Alpha"
A.db.characterMap["Joiner-Realm"]="Alpha"; A.db.characterMap.Joiner="Alpha"
check("default display name",A:PlayerDisplayName("Alpha"),"Alpha")
check("authenticated name change",A:ReceiveDisplayName("Alpha-Realm","autoOne",code," Tyler ","WHISPER"),true)
check("trimmed name stored",A:PlayerDisplayName("Alpha"),"Tyler")
check("ledger key unchanged",A.db.players.Tyler,nil)
check("DKP unchanged",A.db.players.Alpha.dkp,35)
check("main unchanged",A.db.players.Alpha.main,"Alpha")
check("mapping unchanged",A:GetPlayerForCharacter("Joiner"),"Alpha")
check("new name searchable",A:GuildView("tyler")[1],"Alpha")
A:RefreshGuildTab()
A.guildPanel.search:SetText("Tyler")
check("guild player column uses display name",A.guildPanel.rows[1].cells[1].text,"Tyler")
check("guild main column preserves character",A.guildPanel.rows[1].cells[2].text,"Alpha")
check("copied ID wrong code rejected",A:ReceiveDisplayName("Alpha-Realm","autoOne",string.rep("b",48),"Stolen","WHISPER"),false)
check("unlinked sender rejected",A:ReceiveDisplayName("Beta-Realm","autoOne",code,"Stolen","WHISPER"),false)
check("unknown sender rejected",A:ReceiveDisplayName("Outsider-Realm","autoOne",code,"Stolen","WHISPER"),false)
check("guild-broadcast name update rejected",A:ReceiveDisplayName("Alpha-Realm","autoOne",code,"Bad","GUILD"),false)
check("markup rejected",A:ValidateDisplayName("|cffff0000Bad"),nil)
check("control characters rejected",A:ValidateDisplayName("Bad\nName"),nil)
check("overlong name rejected",A:ValidateDisplayName(string.rep("A",33)),nil)
check("32-character name accepted",A:ValidateDisplayName(string.rep("A",32)),string.rep("A",32))
check("invalid changes preserve name",A:PlayerDisplayName("Alpha"),"Tyler")
check("linked alt can update shared name",A:ReceiveDisplayName("Joiner-Realm","autoOne",code,"Tyler Account","WHISPER"),true)
local snapshot=A:SerializeSnapshot()
A.db.players.Alpha.displayName=nil
check("name snapshot accepted",A:ApplySnapshot(snapshot,"Officer-Realm"),true)
check("display name synchronized",A:PlayerDisplayName("Alpha"),"Tyler Account")
check("blank name resets",A:ReceiveDisplayName("Alpha-Realm","autoOne",code,"","WHISPER"),true)
check("default name restored",A:PlayerDisplayName("Alpha"),"Alpha")
C_GuildInfo.IsGuildOfficer=function() return false end
check("member cannot directly change authority name",A:ReceiveDisplayName("Alpha-Realm","autoOne",code,"No","WHISPER"),false)
check("member can save own preference",A:SetMyDisplayName("My Name"),true)
local localProfile=A:LearnAccountCharacter()
check("local name preference saved",localProfile.displayName,"My Name")
check("member preference cannot mutate authoritative ledger",A:PlayerDisplayName("Alpha"),"Alpha")
A:ShowMemberProfile()
check("name form shows saved preference",A.memberProfileFrame.displayName:GetText(),"My Name")
A.memberProfileFrame.displayName:SetText("Another Name")
A.memberProfileFrame.saveName.scripts.OnClick()
check("save name button persists preference",localProfile.displayName,"Another Name")
local outgoing
A.SendRaw=function(_,msg,channel,target) outgoing={msg=msg,channel=channel,target=target} end
A:SendMyDisplayName("Officer-Realm")
check("name preference sent privately",outgoing.channel,"WHISPER")
check("name payload contains account proof",outgoing.msg:match("^D|")~=nil,true)
check("name goes only to officer target",outgoing.target,"Officer-Realm")
print("PASS: "..checks.." display-name UI, authorization, reset, search, and synchronization checks (".._VERSION..")")
