assert(loadfile("tests/member_profile_spec.lua"))()
local A=GDKPCredit
local checks=0
local function check(label,actual,expected)
  assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
  checks=checks+1
end
IsInGuild=function() return true end
GetGuildInfo=function() return "Gnome Pest Control","Accountant",2 end
local current="Alpha"
UnitName=function() return current end
UnitFullName=function() return current,"Realm" end
local guild={"Alpha-Realm","Beta-Realm","Joiner-Realm","Officer-Realm"}
GetNumGuildMembers=function() return #guild end
GetGuildRosterInfo=function(i) return guild[i],"Rank",guild[i]=="Officer-Realm" and 0 or 2 end
C_GuildInfo.IsGuildOfficer=function() return true end
C_GuildInfo.GuildControlGetRankFlags=function(order) return {[3]=order==1} end
A.db.players={}; A.db.characterMap={}; A.db.activeRaid=nil
A.db.accountProfilesByGuild={}; A.db.pendingAccountLinksByGuild={}; A.db.accountCredentialsByGuild={}
local code=string.rep("a",48); local wrong=string.rep("b",48)
local sent={}
A.SendRaw=function(_,msg,channel,target) sent[#sent+1]={msg=msg,channel=channel,target=target} end
check("valid private code",A:ValidLinkCode(code),true)
check("short code rejected",A:ValidLinkCode("abc"),false)
check("guild-broadcast proof rejected",A:ReceivePrivateAccountLink("Alpha-Realm","autoOne",code,"Alpha","GUILD"),false)
check("unknown sender proof rejected",A:ReceivePrivateAccountLink("Outsider-Realm","autoOne",code,"Outsider","WHISPER"),false)
check("first character registers automatically",A:ReceivePrivateAccountLink("Alpha-Realm","autoOne",code,"Beta","WHISPER"),true)
local profiles,pending=A:AccountLinkTables()
check("first registration uses authenticated sender",profiles.autoOne,"Alpha")
check("first registration does not claim suggested main",A.db.characterMap.Beta,nil)
check("code stored only on authority",A:AccountCredentials().autoOne,code)
check("automatic registration leaves no pending approval",pending["alpha-realm"],nil)
check("matching-code alt links automatically",A:ReceivePrivateAccountLink("Beta-Realm","autoOne",code,"Alpha","WHISPER"),true)
check("alt shares ledger",A:GetPlayerForCharacter("Beta"),"Alpha")
check("alt leaves no pending approval",pending["beta-realm"],nil)
local stableVersion=A.db.version
check("repeat proof accepted",A:ReceivePrivateAccountLink("Beta-Realm","autoOne",code,"Alpha","WHISPER"),true)
check("repeat proof does not mutate ledger version",A.db.version,stableVersion)
check("copied ID with wrong code cannot auto link",A:ReceivePrivateAccountLink("Joiner-Realm","autoOne",wrong,"Alpha","WHISPER"),true)
check("wrong code leaves mapping untouched",A.db.characterMap["Joiner-Realm"],nil)
check("wrong code flagged for review",pending["joiner-realm"].credentialConflict,true)
check("plain approval cannot rotate mismatched code",A:ApproveAccountLink("joiner-realm",false),false)
check("original code preserved",A:AccountCredentials().autoOne,code)
A.db.players.Joiner={main="Joiner",dkp=25}; A.db.players.Alpha.dkp=10
check("matching code with balance goes to review",A:ReceivePrivateAccountLink("Joiner-Realm","autoOne",code,"Alpha","WHISPER"),true)
check("existing balance not moved automatically",A.db.players.Joiner.dkp,25)
check("target balance unchanged",A.db.players.Alpha.dkp,10)
check("explicit merge still works",A:ApproveAccountLink("joiner-realm",true),true)
check("reviewed balances combined",A.db.players.Alpha.dkp,35)
local normal=A:SerializeSnapshot()
check("member snapshot contains no private code",normal:find(code,1,true),nil)
local private=A:SerializeSnapshot(true)
check("officer snapshot contains credential",private:find("AK\tautoOne\t"..code,1,true)~=nil,true)
A:AccountCredentials().autoOne=nil
check("officer accepts private snapshot",A:ApplySnapshot(private,"Officer-Realm"),true)
check("officer credentials synchronized",A:AccountCredentials().autoOne,code)
C_GuildInfo.IsGuildOfficer=function() return false end
check("member refuses private snapshot",A:ApplySnapshot(private,"Officer-Realm"),false)
check("nonofficer serialization excludes credentials",A:SerializeSnapshot(true):find(code,1,true),nil)
check("member accepts public snapshot",A:ApplySnapshot(normal,"Officer-Realm"),true)
A:InitAccountLinks()
local id=A.db.localAccount.id
check("nonofficer cannot elicit code",A:ReplyToAccountOfficer("Beta-Realm",id,"WHISPER"),false)
check("officer broadcast does not elicit code",A:ReplyToAccountOfficer("Officer-Realm",id,"GUILD"),false)
check("verified officer whisper handshake",A:ReplyToAccountOfficer("Officer-Realm",id,"WHISPER"),true)
check("proof sent privately",sent[#sent].channel,"WHISPER")
check("proof targets verified officer",sent[#sent].target,"Officer-Realm")
check("proof is never a guild broadcast",sent[#sent].msg:match("^K|")~=nil,true)
C_GuildInfo.IsGuildOfficer=function() return true end
-- Existing single-character balances can enroll without a merge.
A.db.players.Beta={main="Beta",dkp=15}; A.db.characterMap.Beta="Beta"; A.db.characterMap["Beta-Realm"]="Beta"
A.db.activeRaid={id="live"}
check("new registration defers during raid",A:ReceivePrivateAccountLink("Beta-Realm","autoTwo",wrong,"Beta","WHISPER"),true)
check("no profile mutation during raid",profiles.autoTwo,nil)
check("deferred request is retained",pending["beta-realm"].automatic,true)
A.db.activeRaid=nil
A:ProcessAutomaticAccountLinks()
profiles,pending=A:AccountLinkTables()
check("deferred registration processes after raid",profiles.autoTwo,"Beta")
check("own initial balance preserved",A.db.players.Beta.dkp,15)
check("different registered account cannot be moved",A:ReceivePrivateAccountLink("Beta-Realm","autoOne",code,"Alpha","WHISPER"),true)
check("conflicting account retains balance",A.db.players.Beta.dkp,15)
check("conflicting account flagged",pending["beta-realm"].credentialConflict,true)
check("different profile remains authoritative",profiles.autoTwo,"Beta")
print("PASS: "..checks.." automatic registration, private-code security, snapshots, conflicts, and deferred-link checks (".._VERSION..")")
