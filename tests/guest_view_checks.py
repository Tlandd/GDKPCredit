import sys
from pathlib import Path
sys.path.insert(0,sys.argv[1]) if len(sys.argv)>1 else None
from lupa.lua51 import LuaRuntime
r=Path(__file__).resolve().parents[1]
def client(officer):
 l=LuaRuntime(unpack_returned_tuples=True)
 l.execute('''CreateFrame=function() return {RegisterEvent=function() end,SetScript=function() end} end;SlashCmdList={};DEFAULT_CHAT_FRAME={AddMessage=function() end};clock=1000;GetServerTime=function() return clock end;time=GetServerTime
 GetNormalizedRealmName=function() return 'Realm' end;GetRealmName=GetNormalizedRealmName
 IsInRaid=function() return false end;IsInGroup=function() return true end;GetNumSubgroupMembers=function() return 1 end
 UnitExists=function(u) return u=='player' or u=='party1' end
 timers={};packets={};C_Timer={After=function(delay,fn) timers[#timers+1]=fn end};C_ChatInfo={SendAddonMessage=function(prefix,message,channel,target) packets[#packets+1]={message=message,channel=channel,target=target} end}
 function drain() while #timers>0 do table.remove(timers,1)() end end
 ''')
 l.globals().officer=officer
 l.execute('''UnitFullName=function(u) return u=='player' and (officer and 'Officer' or 'Guest') or (officer and 'Guest' or 'Officer'),'Realm' end
 UnitName=UnitFullName
 IsInGuild=function() return officer end
 GetGuildInfo=function(u) if (u=='player' and officer) or (u=='party1' and not officer) then return 'Guild','Officer',1 end end
 ''')
 for n in ['Core.lua','Membership.lua','Comm.lua','GuestView.lua']:l.execute((r/n).read_text(encoding='utf-8'))
 l.execute('''local A=GDKPCredit;A.IsOfficer=function() return officer end;A.Print=function() end
 A.charDB={};A.db={players={Guest={main='Guest',dkp=25,displayName='Guest display'}},characterMap={Guest='Guest'},treasury=1000,reserve=0,version=99,history={},raids={},additionalMembersByGuild={['guild-realm']={'Guest-Realm'}}}
 A.PlayerDisplayName=function(self,p) return self.db.players[p].displayName end
 ''')
 return l
o,g=client(True),client(False)
g.execute("assert(GDKPCredit:RequestGuestDKP());drain();assert(#packets==1);assert(packets[1].channel=='PARTY')")
q=g.globals().packets[1]['message']
o.globals().query=q
o.execute("GDKPCredit:OnAddonMessage('GDKPCredit',query,'PARTY','Guest-Realm');drain();assert(#packets==1);assert(packets[1].channel=='WHISPER' and packets[1].target=='Guest-Realm')")
reply=o.globals().packets[1]['message'];g.globals().reply=reply
checks='''local A=GDKPCredit;local original=A.db;local oldVersion=A.db.version
 A:OnAddonMessage('GDKPCredit',reply,'WHISPER','Stranger-Realm');assert(not A.charDB.guestViews,'ungrouped sender rejected')
 A:OnAddonMessage('GDKPCredit',reply,'RAID','Officer-Realm');assert(not A.charDB.guestViews,'broadcast reply rejected')
 A:OnAddonMessage('GDKPCredit',reply:gsub('GR|[^|]+','GR|wrong',1),'WHISPER','Officer-Realm');assert(not A.charDB.guestViews,'wrong nonce rejected')
 A:OnAddonMessage('GDKPCredit',reply:gsub('guest%-realm','other-realm'),'WHISPER','Officer-Realm');assert(not A.charDB.guestViews,'wrong character rejected')
 A:OnAddonMessage('GDKPCredit',reply,'WHISPER','Officer-Realm');local key=next(A.charDB.guestViews);assert(key,'unguilded guest receives own view')
 assert(A.charDB.guestViews[key].dkp==25 and A.charDB.guestViews[key].credit==1000,'DKP and credit correct')
 assert(A.db==original and A.db.version==oldVersion,'guild ledger unchanged')
 assert(not A:IsOfficer(),'guest not promoted')
 assert(A:GuestDKPText():find('Reported by Officer',1,true),'source shown')
 assert(not A:RequestGuestDKP(),'repeated queries throttled')
 A.charDB.guestViews=nil;clock=1061;A:OnAddonMessage('GDKPCredit',reply,'WHISPER','Officer-Realm');assert(not A.charDB.guestViews,'expired query rejected')
 '''
g.execute(checks)
o.execute("GDKPCredit.db.additionalMembersByGuild={};packets={};clock=1020;GDKPCredit:OnAddonMessage('GDKPCredit',query,'PARTY','Guest-Realm');drain();assert(#packets==0,'unlisted guest receives no balance')")
# Guests belonging to another guild also receive reports without switching ledgers.
h=client(False);h.execute("local old=GetGuildInfo;GetGuildInfo=function(u) if u=='player' then return 'Other Guild','Member',5 end return old(u) end;IsInGuild=function() return true end;assert(GDKPCredit:RequestGuestDKP());drain()")
o.globals().query=h.globals().packets[1]['message'];o.execute("GDKPCredit.db.additionalMembersByGuild={['guild-realm']={'Guest-Realm'}};packets={};clock=1040;GDKPCredit:OnAddonMessage('GDKPCredit',query,'PARTY','Guest-Realm');drain()")
h.globals().reply=o.globals().packets[1]['message'];h.execute("local key=GDKPCredit:TrackingGuildKey();GDKPCredit:OnAddonMessage('GDKPCredit',reply,'WHISPER','Officer-Realm');assert(GDKPCredit.charDB.guestViews);assert(GDKPCredit:TrackingGuildKey()==key and key=='other guild-realm','other guild scope unchanged')")
print('PASS: unguilded and other-guild guest balances, nonce/identity/channel/group/expiry checks, eligibility, source attribution and ledger isolation')

