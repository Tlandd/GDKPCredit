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

function A:SerializeSnapshot()
  local lines = {}
  table.insert(lines, table.concat({"META", tostring(self.db.version or 0), tostring(self.db.treasury or 0), tostring(self.db.reserve or 0)}, "\t"))
  for player,p in pairs(self.db.players) do
    table.insert(lines, table.concat({"P",esc(player),esc(p.main),esc(p.role),tostring(p.dkp or 0),esc(table.concat(p.alts or {},","))},"\t"))
  end
  for char,player in pairs(self.db.characterMap) do
    table.insert(lines, table.concat({"C",esc(char),esc(player)},"\t"))
  end
  local r=self.db.activeRaid
  if r then
    table.insert(lines, table.concat({"R",esc(r.id),esc(r.name),tostring(r.start or 0),r.locked and "1" or "0"},"\t"))
    for player,e in pairs(r.players or {}) do
      table.insert(lines, table.concat({"E",esc(player),esc(e.char),e.presentStart and "1" or "0",e.attendanceBroken and "1" or "0",e.attendance and "1" or "0",e.wb and "1" or "0",e.consumes and "1" or "0",tostring(e.wbCount or 0),tostring(e.consumeCount or 0),tostring(e.dkpAwarded or 0)},"\t"))
    end
  end
  return table.concat(lines,"\n")
end

function A:ApplySnapshot(text, sender)
  if sender and not self:IsOfficer(sender) then return false end
  local new = {players={},characterMap={},history=self.db.history or {},raids=self.db.raids or {},settings=self.db.settings or {}}
  local active=nil
  for line in tostring(text):gmatch("[^\n]+") do
    local f={}
    for part in (line.."\t"):gmatch("(.-)\t") do table.insert(f,part) end
    if f[1]=="META" then
      new.version=tonumber(f[2]) or 0; new.treasury=tonumber(f[3]) or 0; new.reserve=tonumber(f[4]) or 0
    elseif f[1]=="P" then
      local alts={}
      local altText=unesc(f[6] or "")
      for a in altText:gmatch("[^,]+") do table.insert(alts,a) end
      new.players[unesc(f[2])]={main=unesc(f[3]),role=unesc(f[4]),dkp=tonumber(f[5]) or 0,alts=alts}
    elseif f[1]=="C" then
      new.characterMap[unesc(f[2])]=unesc(f[3])
    elseif f[1]=="R" then
      active={id=unesc(f[2]),name=unesc(f[3]),start=tonumber(f[4]) or 0,locked=f[5]=="1",players={}}
      new.activeRaid=active
    elseif f[1]=="E" and active then
      active.players[unesc(f[2])]={char=unesc(f[3]),presentStart=f[4]=="1",attendanceBroken=f[5]=="1",attendance=f[6]=="1",wb=f[7]=="1",consumes=f[8]=="1",wbCount=tonumber(f[9]) or 0,consumeCount=tonumber(f[10]) or 0,dkpAwarded=tonumber(f[11]) or 0}
    end
  end
  if not new.version or new.version < (self.db.version or 0) then return false end
  self.db.version=new.version
  self.db.treasury=new.treasury
  self.db.reserve=new.reserve
  self.db.players=new.players
  self.db.characterMap=new.characterMap
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
  local data=self:SerializeSnapshot()
  local max=180
  local total=math.max(1,math.ceil(#data/max))
  local id=tostring((GetServerTime and GetServerTime()) or time())..tostring(math.random(100,999))
  for i=1,total do
    local chunk=data:sub((i-1)*max+1,i*max)
    C_Timer.After((i-1)*0.12,function()
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
  sender=self:ShortName(sender)
  local kind=msg:match("^([^|]+)")
  if kind=="Q" then
    if self:IsOfficer() then self:SendSnapshot(sender) end
  elseif kind=="V" then
    if not self:IsOfficer(sender) then return end
    local ver=tonumber(msg:match("^V|(%d+)$") or 0) or 0
    if ver>(self.db.version or 0) then self:RequestSync(sender) end
  elseif kind=="S" then
    if not self:IsOfficer(sender) then return end
    local _,_,id,idx,total,chunk=msg:find("^S|([^|]+)|(%d+)|(%d+)|(.*)$")
    idx=tonumber(idx); total=tonumber(total)
    if not id or not idx or not total then return end
    incoming[id]=incoming[id] or {sender=sender,total=total,parts={}}
    local t=incoming[id]
    if t.sender~=sender then return end
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
