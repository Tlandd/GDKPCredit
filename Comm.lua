GDKPCredit = GDKPCredit or {}
local A = GDKPCredit

local incoming = {}

local function esc(s)
  s = tostring(s or "")
  s = s:gsub("%%","%%25"):gsub("\t","%%09"):gsub("\n","%%0A"):gsub("|","%%7C")
  return s
end
local function unesc(s)
  s = tostring(s or "")
  s = s:gsub("%%7C","|"):gsub("%%0A","\n"):gsub("%%09","\t"):gsub("%%25","%%")
  return s
end

function A:SerializeSnapshot(includePrivate)
  local lines = {}
  if self.TrackingGuildKey and self:TrackingGuildKey() then table.insert(lines,"GUILD\t"..esc(self:TrackingGuildKey())) end
  table.insert(lines, table.concat({"META", tostring(self.db.version or 0), tostring(self.db.treasury or 0), tostring(self.db.reserve or 0)}, "\t"))
  for player,p in pairs(self.db.players) do
    table.insert(lines, table.concat({"P",esc(player),esc(p.main),esc(p.role),tostring(p.dkp or 0),esc(table.concat(p.alts or {},",")),esc(p.displayName or "")},"\t"))
  end
  for char,player in pairs(self.db.characterMap) do
    table.insert(lines, table.concat({"C",esc(char),esc(player)},"\t"))
  end
  for _,raid in ipairs(self.CLASSIC_RAIDS or {}) do
    local rules=self:GetRaidProfile(raid.id)
    local fields={"RP",raid.id}
    for _,key in ipairs(self.RAID_RULE_FIELDS) do fields[#fields+1]=tostring(rules[key]) end
    table.insert(lines,table.concat(fields,"\t"))
  end
  if self.TrackingGuildKey then
    local names=self:TrackingExceptions()
    table.insert(lines,table.concat({"TRACK",esc(self:TrackingGuildKey() or "")},"\t"))
    for _,name in ipairs(names) do table.insert(lines,"TM\t"..esc(name)) end
  end
  if self.AccountLinkTables then
    local profiles=self:AccountLinkTables()
    if profiles then
      table.insert(lines,"AP\t"..esc(self:TrackingGuildKey()))
      for id,player in pairs(profiles) do table.insert(lines,table.concat({"AC",id,esc(player)},"\t")) end
      if includePrivate and self:IsOfficer() and self.AccountCredentials then
        for id,code in pairs(self:AccountCredentials()) do
          if profiles[id] and self:ValidLinkCode(code) then table.insert(lines,"AK\t"..id.."\t"..code) end
        end
      end
    end
  end
  if self.DecaySettings then
    local s=self:DecaySettings(); local guild=self:TrackingGuildKey()
    if guild then
      table.insert(lines,table.concat({"DECAY",esc(guild),s.enabled and "1" or "0",s.inactivityDays,s.intervalDays,s.amount,s.enabledAt or 0},"\t"))
      for player,info in pairs(self.db.players) do
        local state=info.decayProgress and info.decayProgress[guild] or {}
        table.insert(lines,table.concat({"DT",esc(player),info.gainTimes and info.gainTimes[guild] or 0,state.anchor or 0,state.cycles or 0},"\t"))
      end
    end
  end
  local r=self.db.activeRaid
  if r then
    table.insert(lines, table.concat({"R",esc(r.id),esc(r.name),tostring(r.start or 0),r.locked and "1" or "0",esc(r.raidType or "")},"\t"))
    if self.GetRaidRules then
      local fields={"RULES"}; local rules=self:GetRaidRules(r)
      for _,key in ipairs(self.RAID_RULE_FIELDS) do fields[#fields+1]=tostring(rules[key]) end
      table.insert(lines,table.concat(fields,"\t"))
    end
    for player,e in pairs(r.players or {}) do
      table.insert(lines, table.concat({"E",esc(player),esc(e.char),e.presentStart and "1" or "0",e.attendanceBroken and "1" or "0",e.attendance and "1" or "0",e.wb and "1" or "0",e.consumes and "1" or "0",tostring(e.wbCount or 0),tostring(e.consumeCount or 0),tostring(e.dkpAwarded or 0),e.attendanceOverride and "1" or "0"},"\t"))
    end
  end
  return table.concat(lines,"\n")
end

function A:ApplySnapshot(text, sender)
  if sender and not self:IsOfficer(sender) then return false end
  local new = {players={},characterMap={},history=self.db.history or {},raids=self.db.raids or {},settings=self.db.settings or {},raidProfiles=self.DeepCopy(self.db.raidProfiles or {}),additionalMembersByGuild=self.DeepCopy(self.db.additionalMembersByGuild or {})}
  local snapshotGuild
  local decayGuild,decaySettings
  local decayTimes={}
  local active=nil
  local membershipGuild, membershipNames
  local accountGuild, accountProfiles, accountCodes
  accountCodes={}
  for line in tostring(text):gmatch("[^\n]+") do
    local f={}
    for part in (line.."\t"):gmatch("(.-)\t") do table.insert(f,part) end
    if f[1]=="META" then
      new.version=tonumber(f[2]) or 0; new.treasury=tonumber(f[3]) or 0; new.reserve=tonumber(f[4]) or 0
    elseif f[1]=="P" then
      local alts={}
      local altText=unesc(f[6] or "")
      for a in altText:gmatch("[^,]+") do table.insert(alts,a) end
      local previous=self.db.players[unesc(f[2])] or {}
      local displayName=unesc(f[7] or "")
      if self.ValidateDisplayName and not self:ValidateDisplayName(displayName) then return false end
      new.players[unesc(f[2])]={gainTimes=self.DeepCopy(previous.gainTimes),decayProgress=self.DeepCopy(previous.decayProgress),displayName=displayName~="" and displayName or nil,main=unesc(f[3]),role=unesc(f[4]),dkp=tonumber(f[5]) or 0,alts=alts}
    elseif f[1]=="GUILD" then
      if snapshotGuild or unesc(f[2])~=self:TrackingGuildKey() then return false end
      snapshotGuild=unesc(f[2])
    elseif f[1]=="C" then
      new.characterMap[unesc(f[2])]=unesc(f[3])
    elseif f[1]=="DECAY" and self.ValidateDecaySettings then
      if decayGuild or unesc(f[2])~=self:TrackingGuildKey() or (f[3]~="0" and f[3]~="1") then return false end
      local settings=self:ValidateDecaySettings({enabled=f[3]=="1",inactivityDays=f[4],intervalDays=f[5],amount=f[6]})
      local stamp=tonumber(f[7])
      if not settings or not stamp or stamp<0 or stamp>=math.huge or stamp~=math.floor(stamp) then return false end
      decayGuild=unesc(f[2]); decaySettings=settings; decaySettings.enabledAt=stamp
    elseif f[1]=="DT" and self.ValidateDecaySettings then
      local player=unesc(f[2]); local gain,anchor,cycles=tonumber(f[3]),tonumber(f[4]),tonumber(f[5])
      if not decayGuild or decayTimes[player] then return false end
      for _,value in ipairs({gain or -1,anchor or -1,cycles or -1}) do
        if value<0 or value>=math.huge or value~=math.floor(value) then return false end
      end
      decayTimes[player]={gain=gain,anchor=anchor,cycles=cycles}
    elseif f[1]=="AP" and self.AccountLinkTables then
      if accountGuild or unesc(f[2])~=self:TrackingGuildKey() then return false end
      accountGuild=unesc(f[2]); accountProfiles={}
    elseif f[1]=="AC" and self.AccountLinkTables then
      local id=f[2]
      if not accountGuild or not id or #id<4 or #id>80 or not id:match("^[%w%-]+$") or accountProfiles[id] then return false end
      accountProfiles[id]=unesc(f[3])
    elseif f[1]=="AK" and self.AccountCredentials then
      if not accountGuild or not self:IsOfficer() or not self:ValidLinkCode(f[3]) or accountCodes[f[2]] then return false end
      accountCodes[f[2]]=f[3]
    elseif f[1]=="TRACK" and self.ValidateTrackingExceptions then
      local guild=unesc(f[2])
      if guild~=self:TrackingGuildKey() then return false end
      local names=self:ValidateTrackingExceptions({unesc(f[3]),unesc(f[4])})
      if not names then return false end
      if membershipGuild then return false end
      membershipGuild=guild; membershipNames=names
    elseif f[1]=="TM" and self.ValidateTrackingExceptions then
      if not membershipGuild then return false end
      local name=unesc(f[2])
      if name=="" then return false end
      membershipNames[#membershipNames+1]=name
    elseif f[1]=="RP" and self.ValidateRaidRules then
      if not self:ClassicRaid(f[2]) then return false end
      local values={}
      for i,key in ipairs(self.RAID_RULE_FIELDS) do values[key]=f[i+2] end
      local rules=self:ValidateRaidRules(values)
      if not rules then return false end
      new.raidProfiles[f[2]]=rules
    elseif f[1]=="RULES" and self.ValidateRaidRules then
      if not active then return false end
      local values={}
      for i,key in ipairs(self.RAID_RULE_FIELDS) do values[key]=f[i+1] end
      local rules=self:ValidateRaidRules(values)
      if not rules then return false end
      active.rules=rules
    elseif f[1]=="R" then
      active={id=unesc(f[2]),name=unesc(f[3]),start=tonumber(f[4]) or 0,locked=f[5]=="1",players={}}
      if f[6] and f[6]~="" then
        active.raidType=unesc(f[6])
        if self.ClassicRaid and not self:ClassicRaid(active.raidType) then return false end
      end
      new.activeRaid=active
    elseif f[1]=="E" and active then
      active.players[unesc(f[2])]={char=unesc(f[3]),presentStart=f[4]=="1",attendanceBroken=f[5]=="1",attendance=f[6]=="1",wb=f[7]=="1",consumes=f[8]=="1",wbCount=tonumber(f[9]) or 0,consumeCount=tonumber(f[10]) or 0,dkpAwarded=tonumber(f[11]) or 0,attendanceOverride=f[12]=="1"}
    end
  end
  if membershipGuild then
    local valid=self:ValidateTrackingExceptions(membershipNames)
    if not valid then return false end
    new.additionalMembersByGuild[membershipGuild]=valid
  end
  if accountGuild then
    for _,player in pairs(accountProfiles) do if not new.players[player] then return false end end
    for id in pairs(accountCodes) do if not accountProfiles[id] then return false end end
  end
  if decayGuild then
    for player,state in pairs(decayTimes) do
      local info=new.players[player]; if not info then return false end
      info.gainTimes=info.gainTimes or {}; info.gainTimes[decayGuild]=state.gain
      info.decayProgress=info.decayProgress or {}; info.decayProgress[decayGuild]={anchor=state.anchor,cycles=state.cycles}
    end
  end
  if self.strictGuildSnapshots and not snapshotGuild then return false end
  if not new.version or new.version < (self.db.version or 0) then return false end
  if accountGuild then
    self.db.accountProfilesByGuild=self.db.accountProfilesByGuild or {}
    self.db.accountProfilesByGuild[accountGuild]=accountProfiles
    if self.AccountCredentials then
      local credentials=self:AccountCredentials()
      for id,code in pairs(accountCodes) do credentials[id]=code end
    end
  end
  if decayGuild then
    self.db.decaySettingsByGuild=self.db.decaySettingsByGuild or {}
    self.db.decaySettingsByGuild[decayGuild]=decaySettings
  end
  self.db.version=new.version
  self.db.treasury=new.treasury
  self.db.reserve=new.reserve
  self.db.players=new.players
  self.db.characterMap=new.characterMap
  if new.activeRaid and not new.activeRaid.rules and self.DefaultRaidRules then
    new.activeRaid.rules=self:DefaultRaidRules()
  end
  self.db.additionalMembersByGuild=new.additionalMembersByGuild
  self.db.trackingExceptions=nil
  self.db.raidProfiles=new.raidProfiles
  self.db.activeRaid=new.activeRaid
  if self.RefreshUI then self:RefreshUI() end
  return true
end

function A:SendRaw(message, channel, target)
  if not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return end
  C_ChatInfo.SendAddonMessage(self.PREFIX, message, channel or "GUILD", target)
end

function A:SendSnapshot(target)
  if not target or target=="" or not self:IsOfficer() then return end
  local guild=self.TrackingGuildKey and self:TrackingGuildKey()
  local private=self:IsOfficer(target)
  local data=self:SerializeSnapshot(private)
  local max=180
  local total=math.max(1,math.ceil(#data/max))
  local id=tostring((GetServerTime and GetServerTime()) or time())..tostring(math.random(100,999))
  for i=1,total do
    local chunk=data:sub((i-1)*max+1,i*max)
    C_Timer.After((i-1)*0.12,function()
      if guild and guild~=A:TrackingGuildKey() then return end
      if not A:IsOfficer() or (private and not A:IsOfficer(target)) then return end
      A:SendRaw(table.concat({"S",id,tostring(i),tostring(total),chunk},"|"),"WHISPER",target)
    end)
  end
end

function A:RequestSync(target)
  if not IsInGuild() then return end
  if target and target~="" then
    self:SendRaw("Q|"..tostring(self.db.version or 0),"WHISPER",target)
  else
    self:SendRaw("Q|"..tostring(self.db.version or 0),"GUILD")
  end
end

function A:BroadcastVersion()
  if not IsInGuild() or not self:IsOfficer() then return end
  self:SendRaw("V|"..tostring(self.db.version or 0),"GUILD")
end

function A:OnAddonMessage(prefix,msg,channel,sender)
  if prefix~=self.PREFIX then return end
  -- Preserve the realm for all permission checks and snapshot assembly.
  if type(sender) ~= "string" or sender == "" or type(msg)~="string" then return end
  local now=(GetServerTime and GetServerTime()) or (time and time()) or 0
  for id,transfer in pairs(incoming) do if transfer.expires and transfer.expires<now then incoming[id]=nil end end
  local kind=msg:match("^([^|]+)")
  if kind=="PERMQ" and self.SendAdminPolicy then self:SendAdminPolicy(sender); return end
  if kind=="PERM" and self.ReceiveAdminPolicy then self:ReceiveAdminPolicy(msg,sender); return end
  if kind=="H" then
    local id=msg:match("^H|([%w%-]+)$")
    if id and self.ReceiveAccountHello then self:ReceiveAccountHello(sender,id) end
  elseif kind=="O" then
    local id=msg:match("^O|([%w%-]+)$")
    if id and self.ReplyToAccountOfficer then self:ReplyToAccountOfficer(sender,id,channel) end
  elseif kind=="K" then
    local id,code,main=msg:match("^K|([%w%-]+)|([0-9a-f]+)|([^|]+)$")
    if id and self.ReceivePrivateAccountLink then self:ReceivePrivateAccountLink(sender,id,code,main,channel) end
  elseif kind=="D" then
    local id,code,name=msg:match("^D|([%w%-]+)|([0-9a-f]+)|(.*)$")
    if id and self.ReceiveDisplayName then self:ReceiveDisplayName(sender,id,code,name,channel) end
  elseif kind=="L" then
    local id,main=msg:match("^L|([%w%-]+)|([^|]+)$")
    if id and self.ReceiveAccountLink then self:ReceiveAccountLink(sender,id,main) end
  elseif kind=="Q" then
    if self:IsOfficer() and (not self.IsTrackedCharacter or self:IsTrackedCharacter(sender)) then self:SendSnapshot(sender) end
  elseif kind=="V" then
    if not self:IsOfficer(sender) then return end
    local ver=tonumber(msg:match("^V|(%d+)$") or 0) or 0
    if ver>(self.db.version or 0) then self:RequestSync(sender) end
  elseif kind=="S" then
    if not self:IsOfficer(sender) then return end
    local _,_,id,idx,total,chunk=msg:find("^S|([^|]+)|(%d+)|(%d+)|(.*)$")
    idx=tonumber(idx); total=tonumber(total)
    if not id or #id>64 or not idx or not total or idx<1 or total<1 or idx>total or total>20000 then return end
    incoming[id]=incoming[id] or {sender=sender,total=total,parts={},expires=now+300,guild=self.TrackingGuildKey and self:TrackingGuildKey()}
    local t=incoming[id]
    if t.sender~=sender or t.total~=total or (t.guild and t.guild~=self:TrackingGuildKey()) then return end
    t.parts[idx]=chunk
    local count=0
    for i=1,total do if t.parts[i] then count=count+1 end end
    if count==total then
      local text=table.concat(t.parts,"")
      incoming[id]=nil
      self:ApplySnapshot(text,sender)
    end
  end
end

function A:InitComm()
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(self.PREFIX) end
  if self.commFrame then return end
  local f=CreateFrame("Frame")
  self.commFrame=f
  f:RegisterEvent("CHAT_MSG_ADDON")
  f:SetScript("OnEvent",function(_,_,prefix,msg,channel,sender) A:OnAddonMessage(prefix,msg,channel,sender) end)
end
