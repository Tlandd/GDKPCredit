import sys
from pathlib import Path
sys.path.insert(0,sys.argv[1]) if len(sys.argv)>1 else None
from lupa.lua51 import LuaRuntime
r=Path(__file__).resolve().parents[1];l=LuaRuntime()
for p in r.glob('*.lua'):
 assert not isinstance(l.eval('loadstring')(p.read_text(encoding='utf-8')),tuple),p.name
l.execute('''GDKPCredit={PREFIX='TEST'}; now=0; timers={}; sent={}; guild='guild'; officer=true; tracked=true
C_Timer={After=function(delay,fn) timers[#timers+1]={at=now+delay,fn=fn} end}
IsInGuild=function() return true end; GetServerTime=function() return 100 end
C_ChatInfo={SendAddonMessage=function(prefix,message,channel,target) sent[#sent+1]={at=now,message=message,target=target} end}
function tick() local t=table.remove(timers,1); assert(t); now=t.at; t.fn() end
local A=GDKPCredit
A.TrackingGuildKey=function() return guild end; A.IsOfficer=function(self,target) return officer end
A.IsTrackedCharacter=function() return tracked end
A.SerializeSnapshot=function() return string.rep('x',1000) end
''')
l.execute((r/'Comm.lua').read_text(encoding='utf-8'))
l.execute('''local A=GDKPCredit;A.SerializeSnapshot=function() return string.rep('x',1000) end;local n=0
local function check(v,label) assert(v,label);n=n+1 end
for i=1,40 do A:SendSnapshot('Member'..i) end
check(#timers==1,'one timer for 40 recipients')
A:SendSnapshot('Member1');check(#A.outgoingSnapshotOrder==40,'repeat does not duplicate transfer')
for i=1,30 do A:SendRaw('V|'..i,'GUILD') end
check(#A.outgoingMessages==1,'version coalesced')
for i=1,81 do tick() end
check(#sent==81,'bounded send work')
for i=2,#sent do check(sent[i].at-sent[i-1].at>=0.5,'global two packets per second') end
check(sent[1].message=='V|30','latest version delivered')
for i=2,41 do check(sent[i].target=='Member'..(i-1),'round robin fair recipients') end
for _,m in ipairs(sent) do check(#m.message<=250,'wire payload bounded') end
local before=#sent;officer=false;while #timers>0 do tick() end
check(#sent==before,'officer revocation stops queued snapshots')
officer=true;A:SendSnapshot('Member1');guild='other';while #timers>0 do tick() end
check(#sent==before,'guild switch stops queued snapshots')
guild='guild';A:SendSnapshot('Member1');tracked=false;while #timers>0 do tick() end
check(#sent==before,'tracking revoked stops send')
tracked=true;A:SendSnapshot('Member1');local old=A.outgoingSnapshots.Member1.id
A.SerializeSnapshot=function() return 'updated' end;A:SendSnapshot('Member1')
check(#A.outgoingSnapshotOrder==1 and A.outgoingSnapshots.Member1.id~=old,'new snapshot replaces old pending transfer')
while #timers>0 do tick() end
check(sent[#sent].message:find('updated',1,true)~=nil,'updated snapshot sent')
print('PASS: '..n..' pacing, coalescing, fairness, bounded payload and permission checks')
''')

