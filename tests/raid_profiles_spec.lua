-- Reuse the existing UI/award harness, then exercise raid-specific settings.
assert(loadfile("tests/workflow_spec.lua"))()
assert(loadfile("Comm.lua"))()
local A=GDKPCredit
local checks=0
local function check(label,actual,expected)
  assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
  checks=checks+1
end
GDKPCreditDB={initialized=true,version=1,settings={attendanceDKP=4,wbDKP=3,consumeDKP=3,
  wbThreshold=3,consumeThreshold=2,dkpCap=200,guildCut=0.10}}
A:InitDB()
A.CurrentRoster=function() return {Alpha="raid1"} end
check("seven Classic raids",#A.CLASSIC_RAIDS,7)
for _,raid in ipairs(A.CLASSIC_RAIDS) do
  check("profile initialized: "..raid.id,A:GetRaidProfile(raid.id).attendanceDKP,4)
end
local settings=A:GetRaidProfile("mc")
settings.attendanceDKP=8; settings.wbDKP=6; settings.consumeDKP=2
settings.wbThreshold=4; settings.consumeThreshold=3; settings.dkpCap=250; settings.guildCut=0.20
check("profile copy protects saved data",A:GetRaidProfile("mc").attendanceDKP,4)
check("officer saves MC profile",A:SaveRaidProfile("mc",settings),true)
check("MC saved",A:GetRaidProfile("mc").attendanceDKP,8)
check("BWL independent",A:GetRaidProfile("bwl").attendanceDKP,4)
C_GuildInfo.IsGuildOfficer=function() return false end
local denied=A:GetRaidProfile("mc"); denied.attendanceDKP=99
check("member cannot save profile",A:SaveRaidProfile("mc",denied),false)
check("denied save preserves values",A:GetRaidProfile("mc").attendanceDKP,8)
A:ShowTab(6)
check("member cannot open settings tab",A.currentTab,1)
check("member cannot start raid",A:StartRaid("mc"),false)
C_GuildInfo.IsGuildOfficer=function() return true end
A:ShowTab(6)
check("officer can open settings tab",A.currentTab,6)
check("unknown raid rejected",A:SaveRaidProfile("fake",settings),false)
check("start requires selection",A:StartRaid(),false)
check("unknown raid cannot start",A:StartRaid("fake"),false)
for _,pair in ipairs({{"attendanceDKP",-1},{"wbDKP",1.5},{"consumeDKP",math.huge},
  {"guildCut",1.01},{"wbThreshold",81},{"consumeThreshold",0/0},{"dkpCap","abc"}}) do
  local invalid=A:GetRaidProfile("mc"); invalid[pair[1]]=pair[2]
  check("invalid "..pair[1].." rejected",A:SaveRaidProfile("mc",invalid),false)
end
check("invalid edits preserve profile",A:GetRaidProfile("mc").guildCut,0.20)
A:ShowStartRaidDialog()
check("raid picker opens",A.startRaidFrame.shown,true)
check("no selection disables start",A.startRaidFrame.start.enabled,false)
A.startRaidFrame.picker.buttons[1].scripts.OnClick()
check("picker selects MC",A.startRaidFrame.selectedRaid,"mc")
check("picker previews custom awards",A.startRaidFrame.rulesText.text:find("Attendance: 8 DKP",1,true)~=nil,true)
A.startRaidFrame.start.scripts.OnClick()
check("picker starts selected raid",A.db.activeRaid.raidType,"mc")
check("raid name from selector",A.db.activeRaid.name,"Molten Core")
check("raid rule snapshot",A.db.activeRaid.rules.attendanceDKP,8)
check("duplicate start rejected",A:StartRaid("bwl"),false)
local changed=A:GetRaidProfile("mc"); changed.attendanceDKP=1; changed.wbThreshold=1; changed.guildCut=0.01
check("edit profile during raid",A:SaveRaidProfile("mc",changed),true)
check("active award rules remain pinned",A.db.activeRaid.rules.attendanceDKP,8)
local wb,con=3,2
A.CountTrackedAuras=function() return wb,con end
A:RunReadinessCheck()
check("pinned WB threshold",A.db.activeRaid.players.Alpha.wb,false)
check("pinned consume threshold",A.db.activeRaid.players.Alpha.consumes,false)
wb,con=4,3
A:RunReadinessCheck()
check("custom WB threshold passes",A.db.activeRaid.players.Alpha.wb,true)
check("custom consume threshold passes",A.db.activeRaid.players.Alpha.consumes,true)
wb,con=0,0
A:RunReadinessCheck()
check("later checks preserve pass",A.db.activeRaid.players.Alpha.wb,true)
local preview=A:RaidAwardPreview(1000)
check("custom raid award",preview.total,16)
check("pinned guild cut",preview.guildCut,200)
-- Profile UI accepts percentage input and saves a fraction.
A.raidSettingsPanel.picker.buttons[3].scripts.OnClick()
check("settings picker selects BWL",A.raidSettingsPanel.selectedRaid,"bwl")
A.raidSettingsPanel.fields.attendanceDKP:SetText("12")
A.raidSettingsPanel.fields.guildCut:SetText("12.5")
A.raidSettingsPanel.save.scripts.OnClick()
check("UI saves award",A:GetRaidProfile("bwl").attendanceDKP,12)
check("UI percent conversion",A:GetRaidProfile("bwl").guildCut,0.125)
check("UI separate profiles",A:GetRaidProfile("mc").attendanceDKP,1)
A.db.activeRaid.players.Alpha.attendanceOverride=true
local snapshot=A:SerializeSnapshot()
check("snapshot includes profiles",snapshot:find("RP\tbwl\t12",1,true)~=nil,true)
check("snapshot includes pinned rules",snapshot:find("RULES\t8\t6\t2\t4\t3\t250\t0.2",1,true)~=nil,true)
A.db.raidProfiles.bwl.attendanceDKP=999
A.db.activeRaid.rules.attendanceDKP=999
check("snapshot accepted",A:ApplySnapshot(snapshot,"Alpha-Realm"),true)
check("profile sync restored",A:GetRaidProfile("bwl").attendanceDKP,12)
check("pinned rule sync restored",A.db.activeRaid.rules.attendanceDKP,8)
check("raid type synchronized",A.db.activeRaid.raidType,"mc")
check("manual attendance override synchronized",A.db.activeRaid.players.Alpha.attendanceOverride,true)
local bad=snapshot:gsub("RP\tbwl\t12","RP\tbwl\t-12")
check("invalid synced profile rejected",A:ApplySnapshot(bad,"Alpha-Realm"),false)
check("invalid sync leaves profile intact",A:GetRaidProfile("bwl").attendanceDKP,12)
check("forged sender cannot sync profiles",A:ApplySnapshot(snapshot,"Alpha-Other"),false)
A:EndRaid(1000)
check("custom award applied",A.db.players.Alpha.dkp,16)
check("custom guild cut applied",A.db.treasury,200)
check("archived rules preserved",A.db.raids[1].rules.attendanceDKP,8)
check("next MC raid starts",A:StartRaid("mc"),true)
check("next raid uses edited award",A.db.activeRaid.rules.attendanceDKP,1)
check("next raid uses edited threshold",A.db.activeRaid.rules.wbThreshold,1)
check("next raid uses edited cut",A.db.activeRaid.rules.guildCut,0.01)
A.db.activeRaid=nil
for _,raid in ipairs(A.CLASSIC_RAIDS) do
  check("start Classic raid "..raid.id,A:StartRaid(raid.id),true)
  check("selected name "..raid.id,A.db.activeRaid.name,raid.name)
  A.db.activeRaid=nil
end
-- Legacy active raids pin the old global rules during upgrade.
A.db.activeRaid={id="legacy",name="Legacy Raid",players={}}
A:InitRaidProfiles()
check("legacy raid migration",A.db.activeRaid.rules.attendanceDKP,4)
print("PASS: "..checks.." raid profile, selector, permission, and synchronization checks (".._VERSION..")")
