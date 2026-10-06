GDKPCredit=GDKPCredit or {}
local A=GDKPCredit
if A.permissionsLoaded then return end
A.permissionsLoaded=true
local original=A.IsOfficer
function A:PermissionPolicy()
  local policies=self.db.adminPoliciesByGuild or {}
  return policies[self:TrackingGuildKey()] or {mode="kick",ranks={},revision=0}
end
function A:GuildRankName(index)
  if type(index)~="number" then return nil end
  if GuildControlGetRankName then return GuildControlGetRankName(index+1) end
  for i=1,GetNumGuildMembers() do
    local _,rank,idx=GetGuildRosterInfo(i)
    if idx==index then return rank end
  end
end
function A:AvailableAdminRanks()
  local ranks={}; local seen={}
  local count=GuildControlGetNumRanks and GuildControlGetNumRanks() or 10
  for i=0,count-1 do
    local name=self:GuildRankName(i)
    if name and not seen[name] then ranks[#ranks+1]=name; seen[name]=true end
  end
  return ranks
end
function A:HasAdminRank(name)
  if not IsInGuild() then return false,"not in guild" end
  local idx
  if name==nil or self:IsLocalGuildPlayer(name) then
    local guild,rankName; guild,rankName,idx=GetGuildInfo("player")
    if not guild then return false,"guild info unavailable" end
  else idx=self:GuildRankIndex(name) end
  if idx==0 then return true,"Guild Master" end
  if type(idx)~="number" or idx<0 or idx~=math.floor(idx) then return false,"guild rank unavailable" end
  local policy=self:PermissionPolicy()
  if policy.mode=="officer" then return original(self,name) end
  if policy.mode=="ranks" then
    local rank=self:GuildRankName(idx)
    return rank~=nil and policy.ranks[rank]==true,"Guild Master selected ranks"
  end
  if policy.mode=="kick" then
    local api=C_GuildInfo and C_GuildInfo.GuildControlGetRankFlags
    if type(api)~="function" then return false,"guild permissions unavailable" end
    local ok,flags=pcall(api,idx+1)
    return ok and type(flags)=="table" and flags[8]==true,"Remove Member guild permission"
  end
  return false,"invalid permission policy"
end
function A:IsOfficer(name)
  return self:HasAdminRank(name)
end
function A:SaveAdminPolicy(mode,ranks)
  if not self:IsAdmin() then return false,"Only the Guild Master can change admin access." end
  if mode~="officer" and mode~="kick" and mode~="ranks" then return false,"Invalid access mode." end
  local allowed={}; for _,rank in ipairs(self:AvailableAdminRanks()) do allowed[rank]=true end
  local selected={}
  for rank,value in pairs(ranks or {}) do
    if value then
      if not allowed[rank] or rank:find("[|,%c]") then return false,"Guild rank unavailable." end
      selected[rank]=true
    end
  end
  local guild=self:TrackingGuildKey(); if not guild then return false,"Guild unavailable." end
  local old=self:PermissionPolicy()
  self.db.adminPoliciesByGuild=self.db.adminPoliciesByGuild or {}
  self.db.adminPoliciesByGuild[guild]={mode=mode,ranks=selected,revision=math.max(old.revision+1,(GetServerTime and GetServerTime()) or time())}
  if self.RefreshUI then self:RefreshUI() end; self:SendAdminPolicy()
  return true,"Guild admin permissions saved."
end
function A:SendAdminPolicy(target)
  if not self:IsAdmin() then return end
  local p=self:PermissionPolicy(); local names={}
  for name,value in pairs(p.ranks) do if value then names[#names+1]=name end end
  table.sort(names)
  self:SendRaw("PERM|"..self:TrackingGuildKey().."|"..p.revision.."|"..p.mode.."|"..table.concat(names,","),target and "WHISPER" or "GUILD",target)
end
function A:ReceiveAdminPolicy(msg,sender)
  if not self:IsAdmin(sender) then return false end
  local guild,revision,mode,names=msg:match("^PERM|([^|]+)|(%d+)|([^|]+)|([^|]*)$")
  if guild~=self:TrackingGuildKey() or (mode~="officer" and mode~="kick" and mode~="ranks") then return false end
  revision=tonumber(revision)
  if not revision or revision>=math.huge or revision<self:PermissionPolicy().revision then return false end
  local ranks={}
  for name in names:gmatch("[^,]+") do
    if name:find("[|%c]") then return false end
    ranks[name]=true
  end
  self.db.adminPoliciesByGuild=self.db.adminPoliciesByGuild or {}
  self.db.adminPoliciesByGuild[guild]={mode=mode,ranks=ranks,revision=revision}
  if self.RefreshUI then self:RefreshUI() end
  return true
end
