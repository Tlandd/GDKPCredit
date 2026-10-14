GDKPCredit=GDKPCredit or {}
local A=GDKPCredit
local function encode(v) return tostring(v or ""):gsub("%%","%%25"):gsub("|","%%7C"):gsub("\n"," "):gsub("\r"," ") end
local function decode(v) return (v:gsub("%%7C","|"):gsub("%%25","%%")) end
local function now() return (GetServerTime and GetServerTime()) or time() end
function A:GuestPeerUnit(sender)
  local identity=self:GuildIdentity(sender)
  if not identity or self:IsLocalGuildPlayer(sender) then return nil end
  local function matches(unit) return UnitExists(unit) and self:GuildIdentity(self:TrackingCharacter(unit))==identity end
  if IsInRaid() then
    for i=1,GetNumGroupMembers() do local u="raid"..i; if matches(u) then return u end end
  elseif IsInGroup() then
    for i=1,GetNumSubgroupMembers() do local u="party"..i; if matches(u) then return u end end
  end
end
function A:RequestGuestDKP()
  local channel=IsInRaid() and "RAID" or (IsInGroup() and "PARTY")
  if not channel then self:Print("Join a group with an addon admin from the guild that tracks you, then refresh the My DKP guild list.") return false end
  if self.guestQueryAt and now()-self.guestQueryAt<10 then return false end
  self.guestQueryAt=now()
  self.guestQuerySerial=(self.guestQuerySerial or 0)+1
  self.guestQuery={nonce=tostring(now()).."-"..tostring(math.random(100000,999999)).."-"..self.guestQuerySerial,expires=now()+60}
  self:SendRaw("GQ|"..self.guestQuery.nonce,channel)
  return true
end
function A:ReceiveGuestMessage(message,channel,sender)
  local unit=self:GuestPeerUnit(sender); if not unit then return end
  local nonce=message:match("^GQ|([%d%-]+)$")
  if nonce then
    if channel~="RAID" and channel~="PARTY" then return end
    if not self:IsOfficer() or not self:IsTrackedCharacter(sender) then return end
    self.guestReplyAt=self.guestReplyAt or {}; local identity=self:GuildIdentity(sender)
    if self.guestReplyAt[identity] and now()-self.guestReplyAt[identity]<10 then return end
    local player=self:TrackingPlayer(sender); local info=self.db.players[player]; if not info then return end
    self.guestReplyAt[identity]=now()
    local fields={"GR",nonce,"",encode(GetGuildInfo("player")),encode(self:GuildIdentity(sender)),encode(self:PlayerDisplayName(player)),tostring(tonumber(info.dkp) or 0),tostring(self:GoldPerDKP()),tostring(self:GuildCredit(player))}
    local text=table.concat(fields,"|")
    -- Bound text fields rather than truncating the wire protocol.
    if #text>250 then fields[6]=encode(self:ShortName(sender)); text=table.concat(fields,"|") end
    if #text<=250 then self:SendRaw(text,"WHISPER",sender) end
    return
  end
  if channel~="WHISPER" then return end
  local fields={}; for field in (message.."|"):gmatch("(.-)|") do fields[#fields+1]=field end
  local query=self.guestQuery
  if #fields~=9 or fields[1]~="GR" or not query or fields[2]~=query.nonce or now()>query.expires then return end
  if decode(fields[5])~=self:GuildIdentity(self:TrackingCharacter("player")) then return end
  local guildName=GetGuildInfo(unit)
  if not guildName or guildName~=decode(fields[4]) then return end
  local dkp,rate,credit=tonumber(fields[7]),tonumber(fields[8]),tonumber(fields[9])
  for _,v in ipairs({dkp or -1,rate or -1,credit or -1}) do if v<0 or v~=v or v==math.huge then return end end
  self.charDB.guestViews=self.charDB.guestViews or {}
  -- Personal reports are never passed to ApplySnapshot or written into a guild ledger.
  local key=decode(fields[4]).."/"..self:GuildIdentity(sender)
  self.charDB.guestViews[key]={guild=guildName,player=decode(fields[6]),character=self:GuildIdentity(self:TrackingCharacter("player")),dkp=dkp,rate=rate,credit=credit,sender=sender,received=now()}
  if self.RefreshGuestDKP then self:RefreshGuestDKP() end
end
function A:GuestDKPText()
  local rows={}; local identity=self:GuildIdentity(self:TrackingCharacter("player"))
  for _,view in pairs(self.charDB.guestViews or {}) do if view.character==identity then rows[#rows+1]=view end end
  table.sort(rows,function(a,b) return a.received>b.received end)
  local lines={"Personal balance reports from guild members in your group.","Read-only; these do not change your own guild's ledger.",""}
  for i,view in ipairs(rows) do
    if i>4 then break end
    lines[#lines+1]=view.guild.." / "..view.player
    lines[#lines+1]=tostring(view.dkp).." DKP  |  "..string.format("%.2f",view.rate).."g / DKP  |  "..tostring(view.credit).."g credit"
    lines[#lines+1]="Reported by "..view.sender.." ("..math.max(0,now()-view.received).."s ago)"
    lines[#lines+1]=""
  end
  if #rows==0 then lines[#lines+1]="No report received yet. You must be listed as an Additional Member, grouped with an online addon admin, and both use this version." end
  return table.concat(lines,"\n")
end

function A:GuildViewOptions()
  local options={{key="self",label=GetGuildInfo("player") or "Current character"}}
  local newest={}; local identity=self:GuildIdentity(self:TrackingCharacter("player"))
  for _,view in pairs(self.charDB.guestViews or {}) do
    if view.character==identity and (not newest[view.guild] or view.received>newest[view.guild].received) then newest[view.guild]=view end
  end
  local guilds={}; for guild in pairs(newest) do guilds[#guilds+1]=guild end
  table.sort(guilds)
  for _,guild in ipairs(guilds) do options[#options+1]={key="guest:"..guild,label=guild.." (guest)",report=newest[guild]} end
  return options
end
function A:SelectedGuildView()
  for _,option in ipairs(self:GuildViewOptions()) do if option.key==(self.charDB.viewingGuild or "self") then return option end end
  self.charDB.viewingGuild="self"
  return self:GuildViewOptions()[1]
end
function A:SelectGuildView(key)
  for _,option in ipairs(self:GuildViewOptions()) do
    if option.key==key then
      self.charDB.viewingGuild=key
      if self.myPanel and self.myPanel.guildMenu then self.myPanel.guildMenu:Hide() end
      if self.RefreshMyTab then self:RefreshMyTab() end
      return true
    end
  end
  return false
end
