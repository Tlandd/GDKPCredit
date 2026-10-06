assert(loadfile("tests/additional_members_spec.lua"))()
local A=GDKPCredit
local checks=0
local function check(label,actual,expected)
  assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
  checks=checks+1
end
GetGuildInfo=function() return "Gnome Pest Control","Accountant",2 end
C_GuildInfo.IsGuildOfficer=function() return true end
A.db.players={}; A.db.characterMap={}; A.db.activeRaid=nil
A.db.accountProfilesByGuild={}; A.db.pendingAccountLinksByGuild={}
A:InitAccountLinks()
local id=A.db.localAccount.id
local sent
A.SendRaw=function(_,msg) sent=msg end
A:AnnounceAccountCharacter()
check("login announces account claim",sent:match("^H|([^|]+)$")~=nil,true)
check("account ID persists",A.db.localAccount.id,id)
local roster={"Alpha-Realm","Beta-Realm","Joiner-Realm"}
GetNumGuildMembers=function() return #roster end
GetGuildRosterInfo=function(i) return roster[i],"Member",2 end
check("bulk guild import",A:ImportGuildPlayers(),true)
check("import creates zero balance",A.db.players.Beta.dkp,0)
A.db.players.Alpha.dkp=10
A:ImportGuildPlayers()
check("import preserves existing balance",A.db.players.Alpha.dkp,10)
A.db.players.Alpha.dkp=0
check("first request accepted",A:ReceiveAccountLink("Alpha-Realm","accountOne","Alpha"),true)
check("alt request accepted",A:ReceiveAccountLink("Beta-Realm","accountOne","Alpha"),true)
check("unknown sender rejected",A:ReceiveAccountLink("Unknown-Realm","accountTwo","Unknown"),false)
check("foreign same name rejected",A:ReceiveAccountLink("Alpha-Other","accountOne","Alpha"),false)
check("invalid account ID rejected",A:ReceiveAccountLink("Alpha-Realm","bad|id","Alpha"),false)
check("no automatic balance merge",A.db.characterMap["Beta-Realm"],"Beta")
check("bulk approve new account",A:ApproveNewAccounts(),true)
local profiles,pending=A:AccountLinkTables()
check("account target established",profiles.accountOne,"Alpha")
check("alt claim remains for review",pending["beta-realm"]~=nil,true)
check("reviewed zero-balance alt linked",A:ApproveAccountLink("beta-realm",false),true)
check("alt shares canonical balance",A:GetPlayerForCharacter("Beta"),"Alpha")
check("duplicate ledger removed",A.db.players.Beta,nil)
A.db.players.Alpha.dkp=10; A.db.players.Joiner.dkp=30
check("balanced character request",A:ReceiveAccountLink("Joiner-Realm","accountOne","Alpha"),true)
check("plain approval blocks balance merge",A:ApproveAccountLink("joiner-realm",false),false)
check("blocked merge preserves source",A.db.players.Joiner.dkp,30)
check("blocked merge preserves target",A.db.players.Alpha.dkp,10)
A:ShowAccountLinks()
check("approval queue opens",A.accountFrame.shown,true)
A:ShowAccountMergeReview("joiner-realm")
check("merge review opens",A.linkReviewFrame.shown,true)
check("merge review shows combined total",A.linkReviewFrame.text.text:find("Combined DKP: 40",1,true)~=nil,true)
check("explicit balance merge",A:ApproveAccountLink("joiner-realm",true),true)
check("combined balance correct",A.db.players.Alpha.dkp,40)
check("merged source removed",A.db.players.Joiner,nil)
check("merged alt maps to account",A:GetPlayerForCharacter("Joiner"),"Alpha")
check("merged account announced twice no new request",A:ReceiveAccountLink("Beta-Realm","accountOne","Alpha"),true)
check("already-approved claim does not queue",pending["beta-realm"],nil)
-- New claims cannot hijack an existing group through bulk approval.
A:ReceiveAccountLink("Beta-Realm","accountDifferent","Alpha")
local _,status,safe=A:AccountLinkStatus(pending["beta-realm"])
check("unapproved account cannot claim someone else's main",safe,false)
A:ApproveNewAccounts()
check("unverified main remains queued",pending["beta-realm"]~=nil,true)
A.db.activeRaid={id="active"}
check("linking blocked during raid",A:ApproveAccountLink("beta-realm",false),false)
check("import blocked during raid",A:ImportGuildPlayers(),false)
A.db.activeRaid=nil
C_GuildInfo.IsGuildOfficer=function() return false end
check("nonofficer receives no requests",A:ReceiveAccountLink("Alpha-Realm","accountOne","Alpha"),false)
check("nonofficer cannot approve",A:ApproveNewAccounts(),false)
check("nonofficer cannot import",A:ImportGuildPlayers(),false)
C_GuildInfo.IsGuildOfficer=function() return true end
A.db.players.Alpha.dkp=0
A:ReceiveAccountLink("Beta-Realm","accountAlternate","Beta")
local _,_,safeExisting=A:AccountLinkStatus(pending["beta-realm"])
check("linked alt cannot bulk re-register existing profile",safeExisting,false)
A.db.players.Alpha.dkp=190
A.db.players.Joiner={main="Joiner",dkp=30}
A.db.characterMap.Joiner="Joiner"; A.db.characterMap["Joiner-Realm"]="Joiner"
A:ReceiveAccountLink("Joiner-Realm","accountOne","Alpha")
check("over-cap merge rejected",A:ApproveAccountLink("joiner-realm",true),false)
check("over-cap source preserved",A.db.players.Joiner.dkp,30)
check("over-cap target preserved",A.db.players.Alpha.dkp,190)
local snapshot=A:SerializeSnapshot()
profiles.accountOne=nil
check("approved account profile sync",A:ApplySnapshot(snapshot,"Alpha-Realm"),true)
profiles=A:AccountLinkTables()
check("account profile restored",profiles.accountOne,"Alpha")
check("local account identity survives sync",A.db.localAccount.id,id)
check("bad account snapshot rejected",A:ApplySnapshot(snapshot.."\nAC\taccountBad\tMissingPlayer","Alpha-Realm"),false)
print("PASS: "..checks.." account discovery, bulk import, approval, merge, and security checks (".._VERSION..")")
