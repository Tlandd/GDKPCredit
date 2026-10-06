assert(loadfile("tests/player_names_spec.lua"))()
local A=GDKPCredit
local n=0
local function check(label,a,b) assert(a==b,label..": "..tostring(a).." != "..tostring(b)); n=n+1 end
local day=86400
local now=1000000
GetServerTime=function() return now end
C_GuildInfo.IsGuildOfficer=function() return true end
A.db.activeRaid=nil
A.db.players={Alpha={main="Alpha",alts={"Joiner-Realm"},dkp=100},Beta={main="Beta",dkp=10},Outsider={main="Outsider",dkp=50}}
A.db.characterMap={Alpha="Alpha",Joiner="Alpha",["Joiner-Realm"]="Alpha",Beta="Beta"}
A.db.decaySettingsByGuild={}
local guild=A:TrackingGuildKey()
check("disabled default",A:DecaySettings().enabled,false)
check("default grace",A:DecaySettings().inactivityDays,30)
check("default interval",A:DecaySettings().intervalDays,7)
check("default amount",A:DecaySettings().amount,15)
check("bad interval",A:SaveDecaySettings({enabled=true,inactivityDays=30,intervalDays=0,amount=15}),false)
check("fraction rejected",A:ValidateDecaySettings({enabled=true,inactivityDays=1.5,intervalDays=7,amount=15}),nil)
check("enable",A:SaveDecaySettings({enabled=true,inactivityDays=30,intervalDays=7,amount=15}),true)
local start=now
A:ApplyDKPDecay()
check("no retroactive deduction",A.db.players.Alpha.dkp,100)
now=start+30*day-1; A:ApplyDKPDecay()
check("full grace",A.db.players.Alpha.dkp,100)
now=now+1; A:ApplyDKPDecay()
check("first day thirty",A.db.players.Alpha.dkp,85)
check("floor zero",A.db.players.Beta.dkp,0)
check("outsider excluded",A.db.players.Outsider.dkp,50)
local version=A.db.version
A:ApplyDKPDecay()
check("no duplicate deduction",A.db.players.Alpha.dkp,85)
check("no duplicate mutation",A.db.version,version)
now=start+37*day-1; A:ApplyDKPDecay()
check("between periods",A.db.players.Alpha.dkp,85)
now=now+1; A:ApplyDKPDecay()
check("weekly deduction",A.db.players.Alpha.dkp,70)
now=start+58*day; A:ApplyDKPDecay()
check("offline catchup",A.db.players.Alpha.dkp,25)
check("alt no separate balance",A.db.players.Joiner,nil)
A:AdjustDKP("Alpha",5)
check("real gain recorded",A.db.players.Alpha.gainTimes[guild],now)
check("gain clears progress",A.db.players.Alpha.decayProgress[guild],nil)
local gain=now
now=now+day; A:AdjustDKP("Alpha",-5)
check("spending does not reset",A.db.players.Alpha.gainTimes[guild],gain)
A.db.players.Alpha.dkp=A.db.settings.dkpCap
A:AdjustDKP("Alpha",5)
check("capped gain does not reset",A.db.players.Alpha.gainTimes[guild],gain)
A.db.players.Alpha.dkp=100
now=gain+30*day; A:ApplyDKPDecay()
check("gain restarts full grace",A.db.players.Alpha.dkp,85)
local snapshot=A:SerializeSnapshot()
check("snapshot accepted",A:ApplySnapshot(snapshot,"Officer-Realm"),true)
A:ApplyDKPDecay()
check("snapshot checkpoint prevents duplicate",A.db.players.Alpha.dkp,85)
check("snapshot preserves gain time",A.db.players.Alpha.gainTimes[guild],gain)
check("policy synced",A:DecaySettings().amount,15)
A:SaveDecaySettings({enabled=true,inactivityDays=30,intervalDays=7,amount=20})
check("changed policy clears progress",A.db.players.Alpha.decayProgress[guild],nil)
A:ApplyDKPDecay()
check("policy change fresh grace",A.db.players.Alpha.dkp,85)
now=now+30*day; A:ApplyDKPDecay()
check("new amount applied",A.db.players.Alpha.dkp,65)
A:SaveDecaySettings({enabled=false,inactivityDays=30,intervalDays=7,amount=20})
now=now+100*day; A:ApplyDKPDecay()
check("disabled stops decay",A.db.players.Alpha.dkp,65)
C_GuildInfo.IsGuildOfficer=function() return false end
check("member cannot save",A:SaveDecaySettings({enabled=true,inactivityDays=30,intervalDays=7,amount=15}),false)
check("member cannot deduct",A:ApplyDKPDecay(),false)
C_GuildInfo.IsGuildOfficer=function() return true end
A:ShowDecaySettings()
check("settings UI opens",A.decayFrame.shown,true)
print("PASS: "..n.." decay timing, gains, permissions, policy, and synchronization checks (".._VERSION..")")
