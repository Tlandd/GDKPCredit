-- Run from addon root: lua tests/workflow_spec.lua
local checks=0
local function check(label, actual, expected)
  assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
  checks=checks+1
end
local frames={}
local function frame()
  local f={scripts={},shown=false,text="",enabled=true}
  frames[#frames+1]=f
  local noop=function() end
  setmetatable(f,{__index=function(_,key) if key:match("^[A-Z]") then return noop end end})
  function f:SetScript(event,callback) self.scripts[event]=callback end
  function f:CreateFontString() return frame() end
  function f:SetText(text) self.text=text; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
  function f:GetText() return self.text end
  function f:SetEnabled(enabled) self.enabled=enabled end
  function f:SetShown(shown) self.shown=shown end
  function f:Show() self.shown=true end
  function f:Hide() self.shown=false end
  function f:IsShown() return self.shown end
  function f:HasFocus() return false end
  function f:SetSize(w,h) self.width=w; self.height=h end
  function f:SetPoint(...) self.point={...} end
  function f:GetPoint() return "CENTER",UIParent,"CENTER",10,20 end
  return f
end
CreateFrame=function() return frame() end
UIParent=frame(); SlashCmdList={}; DEFAULT_CHAT_FRAME={AddMessage=function() end}
UnitName=function() return "Alpha" end
UnitFullName=function() return "Alpha","Realm" end
GetNormalizedRealmName=function() return "Realm" end
local guildNames={"Alpha-Realm","Beta-Realm","Gamma-Realm","Over-Realm"}
for i=1,40 do guildNames[#guildNames+1]="Player"..i.."-Realm" end
GetNumGuildMembers=function() return #guildNames end
GetGuildRosterInfo=function(i) return guildNames[i],"Member",2 end
IsInGuild=function() return true end
GetGuildInfo=function() return "Gnome Pest Control","Accountant",2 end
C_GuildInfo={IsGuildOfficer=function() return true end}
GetServerTime=function() return 1000 end
time=GetServerTime; date=function() return "10/06 20:00" end
assert(loadfile("Core.lua"))("GDKPCredit")
assert(loadfile("Membership.lua"))()
assert(loadfile("Permissions.lua"))()
assert(loadfile("AccountLinks.lua"))()
assert(loadfile("AutoAccountLinks.lua"))()
assert(loadfile("PlayerNames.lua"))()
assert(loadfile("Decay.lua"))()
assert(loadfile("RaidProfiles.lua"))()
assert(loadfile("Views.lua"))()
assert(loadfile("Raid.lua"))()
assert(loadfile("UI.lua"))()
local A=GDKPCredit
A:InitDB()
A.db.players={Alpha={main="Alpha",alts={"Needle"},dkp=195}, Beta={main="Zed",dkp=50},
  Gamma={main="Gamma",dkp=200}, Over={main="Over",dkp=210}}
A.db.treasury=1000
A.db.activeRaid={id="r1",name="Test Raid",players={
  Alpha={char="Alpha",presentStart=true,wb=true,consumes=true},
  Beta={char="Beta",presentStart=true,attendanceBroken=true,wb=true},
  Gamma={char="Gamma",attendanceOverride=true,consumes=true},
  Over={char="Over",attendanceOverride=true,wb=true,consumes=true}}}
A.CurrentRoster=function() return {Alpha="raid1",Beta="raid2",Over="raid3"} end
check("alt search",A:GuildView("needle")[1],"Alpha")
check("main search",A:GuildView("zed")[1],"Beta")
check("case insensitive search",A:GuildView("ALPHA")[1],"Alpha")
check("plain literal query",#A:GuildView("["),0)
check("DKP ascending",A:GuildView("","dkp",false)[1],"Beta")
check("DKP descending",A:GuildView("","dkp",true)[1],"Over")
check("credit sorting",A:GuildView("","credit",true)[1],"Over")
local names,summary=A:RaidView("",true)
check("missing readiness filter",#names,2)
check("summary total",summary.total,4)
check("summary world buffs",summary.wb,3)
check("summary consumes",summary.consumes,3)
check("summary attendance",summary.attendance,3)
check("raid search",A:RaidView("beta",false)[1],"Beta")
check("negative pot rejected",A:RaidAwardPreview(-1),nil)
check("empty pot rejected",A:RaidAwardPreview(""),nil)
check("infinite pot rejected",A:RaidAwardPreview(math.huge),nil)
check("NaN pot rejected",A:RaidAwardPreview(0/0),nil)
local preview=A:RaidAwardPreview(1000)
check("guild cut preview",preview.guildCut,100)
check("actual cap award",preview.players.Alpha.actual,5)
check("full earned award",preview.players.Alpha.earned,10)
check("broken attendance",preview.players.Beta.attendance,false)
check("attendance override",preview.players.Gamma.attendance,true)
check("cap total",preview.total,8)
check("cap count",preview.capped,3)
check("overcap balance preserved",preview.players.Over.after,210)
check("zero pot allowed",A:RaidAwardPreview(0).grossPot,0)
for i=1,40 do A.db.players["Player"..i]={main="Player"..i,dkp=i} end
for i=1,40 do A.db.history[i]={kind="ADJUST",player="Player"..i,note="Test note "..i,ts=1000,amount=i} end
check("history text search",#A:HistoryView("test note"),40)
check("history literal search",#A:HistoryView("["),0)
A:InitUI()
check("main width",A.frame.width,900)
check("raid projected DKP respects cap",A.raidPanel.rows[1].cells[6].text,"5")
check("guild first page",A.guildPanel.page,1)
A.guildPanel.next.scripts.OnClick()
check("guild next page",A.guildPanel.page,2)
A.guildPanel.search:SetText("needle")
check("guild query resets page",A.guildPanel.page,1)
check("guild query visible result",A.guildPanel.rows[1].player,"Alpha")
check("guild next disabled for single result",A.guildPanel.next.enabled,false)
A.historyPanel.next.scripts.OnClick()
check("history next page",A.historyPanel.page,2)
A.historyPanel.search:SetText("note 40")
check("history search result",A.historyPanel.rows[1].entry.player,"Player40")
check("history resets page",A.historyPanel.page,1)
A.raidPanel.filter.scripts.OnClick()
check("UI missing filter",A.raidPanel.missingOnly,true)
check("filtered raid row",A.raidPanel.rows[1].player,"Beta")
A.raidPanel.rows[1].scripts.OnClick(A.raidPanel.rows[1])
check("selection enabled",A.raidPanel.selectionControls[1].enabled,true)
A:ShowAwardPreview(1000)
check("preview opens",A.awardFrame.shown,true)
check("preview does not award",A.db.players.Alpha.dkp,195)
local confirm
for _,f in ipairs(frames) do if f.text=="Confirm & End Raid" then confirm=f end end
assert(confirm,"confirmation button exists")
A.db.version=A.db.version+1
confirm.scripts.OnClick()
check("changed data dismisses confirmation",A.awardFrame.shown,false)
check("changed data preserves raid",A.db.activeRaid.id,"r1")
A:ShowAwardPreview(1000)
A.CurrentRoster=function() return {Beta="raid2",Over="raid3"} end
confirm.scripts.OnClick()
check("changed roster dismisses confirmation",A.awardFrame.shown,false)
check("changed roster preserves balances",A.db.players.Alpha.dkp,195)
A.CurrentRoster=function() return {Alpha="raid1",Beta="raid2",Over="raid3"} end
C_GuildInfo.IsGuildOfficer=function() return false end
A:RefreshRaidTab()
check("member end action disabled",A.raidPanel.controls[4].enabled,false)
A:EndRaid(1000)
check("member cannot end raid",A.db.activeRaid.id,"r1")
C_GuildInfo.IsGuildOfficer=function() return true end
A:RefreshRaidTab()
A.frame.scripts.OnDragStop(A.frame)
check("window position saved",A.charDB.window.x,10)
A:EndRaid(-1)
check("invalid pot preserves raid",A.db.activeRaid.id,"r1")
check("invalid pot preserves treasury",A.db.treasury,1000)
A:ShowAwardPreview(1000)
confirm.scripts.OnClick()
check("raid archived",A.db.activeRaid,nil)
check("treasury matches preview",A.db.treasury,1100)
check("balance matches preview",A.db.players.Alpha.dkp,200)
check("uncapped balance",A.db.players.Beta.dkp,53)
check("overcap balance stays intact",A.db.players.Over.dkp,210)
check("archive records actual",A.db.raids[1].players.Alpha.dkpAwarded,5)
check("cap archive records zero",A.db.raids[1].players.Gamma.dkpAwarded,0)
check("summary history actual DKP",A.db.history[1].amount,8)
A:RefreshUI()
check("selection cleared after end",A.raidPanel.selected,nil)
check("end action disabled",A.raidPanel.controls[4].enabled,false)
print("PASS: "..checks.." view, UI workflow, and award checks (".._VERSION..")")
