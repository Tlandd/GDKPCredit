GDKPCredit = GDKPCredit or {}
local A = GDKPCredit
local DAY = 86400

function A:DecaySettings()
  local guild=self:TrackingGuildKey()
  local saved=self.db.decaySettingsByGuild or {}
  return saved[guild] or {enabled=false,inactivityDays=30,intervalDays=7,amount=15,enabledAt=0}
end

function A:ValidateDecaySettings(values)
  if type(values)~="table" or type(values.enabled)~="boolean" then return nil,"Invalid decay settings." end
  local result={enabled=values.enabled}
  for _,key in ipairs({"inactivityDays","intervalDays","amount"}) do
    local value=tonumber(values[key])
    local maximum=key=="amount" and 1000000 or 3650
    if not value or value~=value or value<1 or value>maximum or value~=math.floor(value) then
      return nil,key.." must be a whole number between 1 and "..maximum.."."
    end
    result[key]=value
  end
  return result
end

function A:SaveDecaySettings(values)
  if not self:IsOfficer() then return false,"Your guild rank does not have addon admin access." end
  local guild=self:TrackingGuildKey(); if not guild then return false,"Guild information unavailable." end
  local valid,err=self:ValidateDecaySettings(values); if not valid then return false,err end
  local old=self:DecaySettings()
  if old.enabled==valid.enabled and old.inactivityDays==valid.inactivityDays and
    old.intervalDays==valid.intervalDays and old.amount==valid.amount then return true,"Settings unchanged." end
  valid.enabledAt=(GetServerTime and GetServerTime()) or time()
  self.db.decaySettingsByGuild=self.db.decaySettingsByGuild or {}
  self.db.decaySettingsByGuild[guild]=valid
  for _,info in pairs(self.db.players) do
    if info.decayProgress then info.decayProgress[guild]=nil end
  end
  self:AddHistory("DECAY_RULES","",0,valid.enabled and
    ("Decay: "..valid.amount.." DKP every "..valid.intervalDays.." days after "..valid.inactivityDays.." days without gains") or "Inactivity decay disabled")
  self:MarkChanged()
  return true,"Saved. The inactivity period restarts now; no past decay is charged."
end

function A:RecordDKPGain(player,amount,now)
  if not amount or amount<=0 then return end
  local guild=self:TrackingGuildKey(); local info=self.db.players[player]
  if not guild or not info then return end
  info.gainTimes=info.gainTimes or {}
  info.gainTimes[guild]=now or ((GetServerTime and GetServerTime()) or time())
  info.decayProgress=info.decayProgress or {}; info.decayProgress[guild]=nil
end

function A:DecayPlan(now)
  now=now or ((GetServerTime and GetServerTime()) or time())
  local settings=self:DecaySettings(); local guild=self:TrackingGuildKey()
  local rows={}
  if not settings.enabled or not guild then return rows end
  local members,ready=self:GuildTrackingRoster(); if not ready then return rows end
  for player,info in pairs(self.db.players) do
    if self:IsTrackedPlayer(player,info,members) then
      local gain=info.gainTimes and info.gainTimes[guild] or 0
      local anchor=math.max(gain,settings.enabledAt or now)
      local state=info.decayProgress and info.decayProgress[guild]
      local applied=state and state.anchor==anchor and state.cycles or 0
      local first=anchor+settings.inactivityDays*DAY
      local cycles=now>=first and math.floor((now-first)/(settings.intervalDays*DAY))+1 or 0
      local due=math.max(0,cycles-applied)
      if due>0 then
        local balance=math.max(0,tonumber(info.dkp) or 0)
        rows[#rows+1]={player=player,anchor=anchor,cycles=cycles,due=due,
          loss=math.min(balance,due*settings.amount),after=math.max(0,balance-due*settings.amount)}
      end
    end
  end
  return rows
end

function A:ApplyDKPDecay(now)
  if not self:IsOfficer() then return false,"Your guild rank does not have addon admin access." end
  local plan=self:DecayPlan(now); local guild=self:TrackingGuildKey()
  if #plan==0 then return true,0 end
  local total=0
  for _,row in ipairs(plan) do
    local info=self.db.players[row.player]
    info.dkp=row.after; info.decayProgress=info.decayProgress or {}
    info.decayProgress[guild]={anchor=row.anchor,cycles=row.cycles}
    if row.loss>0 then
      self:AddHistory("DECAY",row.player,-row.loss,"Inactivity decay ("..row.due.." scheduled period(s))")
      total=total+row.loss
    end
  end
  self:MarkChanged()
  return true,total
end

function A:StartDecayTimer()
  if self.decayTimerStarted or not C_Timer or not C_Timer.After then return end
  self.decayTimerStarted=true
  local function tick()
    if self.db and self:IsOfficer() then self:ApplyDKPDecay() end
    C_Timer.After(60,tick)
  end
  C_Timer.After(5,tick)
end
