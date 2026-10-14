import sys
from pathlib import Path
sys.path.insert(0,sys.argv[1]) if len(sys.argv)>1 else None
from lupa.lua51 import LuaRuntime
r=Path(__file__).resolve().parents[1]
l=LuaRuntime()
l.execute('CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end; SlashCmdList={}; GetNormalizedRealmName=function() return "Realm" end; GetRealmName=GetNormalizedRealmName; GetGuildInfo=function() return "Guild" end; IsInGuild=function() return true end; GetNumGuildMembers=function() return 2 end; GetGuildRosterInfo=function(i) return ({"Officer-Realm","Noaddon-Realm"})[i] end; IsInRaid=function() return true end; GetNumGroupMembers=function() return 3 end; UnitExists=function(u) return u=="raid1" or u=="raid2" or u=="raid3" end; UnitFullName=function(u) return ({raid1="Officer",raid2="Noaddon",raid3="Outsider"})[u],"Realm" end; GetServerTime=function() return 1000 end; time=GetServerTime')
for name in ['Core.lua','Membership.lua','RaidProfiles.lua','Views.lua','Raid.lua']: l.execute((r/name).read_text(encoding="utf-8"))
for f in r.glob('*.lua'):
 result=l.eval('loadstring')(f.read_text(encoding='utf-8'))
 assert not isinstance(result,tuple), (f.name,result)
l.execute("""local A=GDKPCredit
local n=0
local function check(v,label) assert(v,label); n=n+1 end
A.db={players={},characterMap={},settings={},raids={},history={},treasury=0}
A.IsOfficer=function() return true end; A.MarkChanged=function() end; A.Print=function() end
check(A:StartRaid('bwl'),'start')
check(A.db.activeRaid.players.Noaddon~=nil,'no addon member recorded')
check(A.db.activeRaid.players.Outsider==nil,'outsider excluded')
local raid=A.db.activeRaid
UnitExists=function(u) return u=='raid1' end
A:OnRosterUpdate()
check(not raid.players.Noaddon.attendanceBroken,'departure preserves attendance')
raid.players.Noaddon.attendanceBroken=true -- old saved active raid
GetNumGuildMembers=function() return 3 end
GetGuildRosterInfo=function(i) return ({'Officer-Realm','Noaddon-Realm','Late-Realm'})[i] end
UnitExists=function(u) return u=='raid1' or u=='raid2' end
UnitFullName=function(u) return u=='raid1' and 'Officer' or 'Late','Realm' end
A:OnRosterUpdate()
check(raid.players.Late.presentStart==false,'late arrival tracked')
local p=A:RaidAwardPreview(125.5)
check(p.players.Noaddon.actual==4,'old broken flag ignored')
check(p.players.Noaddon.attendance,'absent start member receives attendance')
check(p.players.Late.actual==0,'late arrival requires override')
local rows,summary=A:RaidView('',false)
check(summary.attendance==2,'summary agrees with preview')
A:SetRaidPass('Late','attendance')
check(A:RaidAwardPreview(0).players.Late.actual==4,'late override works')
raid.players.Outsider={char='Outsider',presentStart=true,attendanceOverride=true,wb=true,consumes=true}
check(A:RaidAwardPreview(0).players.Outsider.actual==0,'outsider override cannot bypass guild eligibility')
A:EndRaid(125.5)
check(A.db.players.Noaddon.dkp==4,'departure award committed')
check(A.db.players.Late.dkp==4,'override award committed')
check(A.db.treasury==125.5,'guild cut unchanged')
check(A.db.raids[1].players.Noaddon.attendance,'history records attendance')
A:EndRaid(125.5)
check(A.db.players.Noaddon.dkp==4 and A.db.treasury==125.5,'second closure no duplicate')
print('PASS: '..n..' departure, migration, late arrival, eligibility, preview and award checks; all Lua 5.1 syntax passed')
""")

l.execute("""local A=GDKPCredit
assert(A:StartRaid('bwl'))
local changes=0;A.MarkChanged=function() changes=changes+1 end
local clock=2000;GetTime=function() return clock end
A.CountTrackedAuras=function() return 10,10 end
A:RunReadinessCheck();assert(changes==1,'first changed result announced')
A:RunReadinessCheck();assert(changes==1,'immediate repeated check blocked')
clock=clock+6;A:RunReadinessCheck();assert(changes==1,'unchanged result does not sync')
A.CountTrackedAuras=function() return 0,0 end
clock=clock+6;A:RunReadinessCheck();assert(changes==1,'death preserves passes without syncing')
A.CountTrackedAuras=function() return 12,12 end
clock=clock+6;A:RunReadinessCheck();assert(changes==2,'new counts announce changes')
print('PASS: readiness cooldown, unchanged-result suppression, retained passes and updated counts')
""")
