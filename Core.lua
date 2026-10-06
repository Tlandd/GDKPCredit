local ADDON_NAME = ...
GDKPCredit = GDKPCredit or {}
local A = GDKPCredit

A.PREFIX = "GDKPCredit"
A.VERSION = "0.1.4-beta"
A.TABS = {"My DKP", "Guild DKP", "Raid", "History", "Admin"}

local function deepcopy(src)
  if type(src) ~= "table" then return src end
  local t = {}
  for k,v in pairs(src) do t[deepcopy(k)] = deepcopy(v) end
  return t
end
A.DeepCopy = deepcopy

function A:ShortName(name)
  if not name then return "" end
  return (name:match("^[^-]+") or name)
end

function A:Norm(name)
  return string.lower(self:ShortName(name or ""))
end

function A:NowVersion()
  local now = (GetServerTime and GetServerTime()) or time()
  self.db.version = math.max((self.db.version or 0) + 1, now)
  return self.db.version
end

function A:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffd200GDKP Credit:|r " .. tostring(msg))
end

function A:InitDB()
  -- One-time migration from the original guild-only GPCDKP beta.
  if GDKPCreditDB == nil and type(GPCDKP_DB) == "table" then
    GDKPCreditDB = deepcopy(GPCDKP_DB)
    GDKPCreditDB.migratedFromGPCDKP = true
  end
  if GDKPCreditCharDB == nil and type(GPCDKP_CharDB) == "table" then
    GDKPCreditCharDB = deepcopy(GPCDKP_CharDB)
  end

  GDKPCreditDB = GDKPCreditDB or {}
  GDKPCreditCharDB = GDKPCreditCharDB or {}
  self.db = GDKPCreditDB
  self.charDB = GDKPCreditCharDB

  if not self.db.initialized then
    local b = self.BOOTSTRAP or {}
    self.db.initialized = true
    self.db.version = b.version or 1
    self.db.treasury = b.treasury or 0
    self.db.reserve = b.reserve or 0
    self.db.players = deepcopy(b.players or {})
    self.db.characterMap = deepcopy(b.characterMap or {})
    self.db.history = {}
    self.db.raids = {}
    self.db.activeRaid = nil
    self.db.settings = {
      wbThreshold = 3,
      consumeThreshold = 2,
      attendanceDKP = 4,
      wbDKP = 3,
      consumeDKP = 3,
      officerRankMax = 1,
      guildCut = 0.10,
      dkpCap = 200,
    }
  end

  self.db.players = self.db.players or {}
  self.db.characterMap = self.db.characterMap or {}
  self.db.history = self.db.history or {}
  self.db.raids = self.db.raids or {}
  self.db.settings = self.db.settings or {}
  local s = self.db.settings
  if s.wbThreshold == nil then s.wbThreshold = 3 end
  if s.consumeThreshold == nil then s.consumeThreshold = 2 end
  if s.attendanceDKP == nil then s.attendanceDKP = 4 end
  if s.wbDKP == nil then s.wbDKP = 3 end
  if s.consumeDKP == nil then s.consumeDKP = 3 end
  if s.officerRankMax == nil then s.officerRankMax = 1 end
  if s.guildCut == nil then s.guildCut = 0.10 end
  if s.dkpCap == nil then s.dkpCap = 200 end
end

function A:GetPlayerForCharacter(character)
  if not character or character == "" then return nil end
  local short = self:ShortName(character)
  if self.db.characterMap[short] then return self.db.characterMap[short] end
  local n = self:Norm(short)
  for c,p in pairs(self.db.characterMap) do
    if self:Norm(c) == n then return p end
  end
  for player, info in pairs(self.db.players) do
    if self:Norm(player) == n or self:Norm(info.main) == n then return player end
    for _,alt in ipairs(info.alts or {}) do
      if self:Norm(alt) == n then return player end
    end
  end
  return nil
end

function A:GetMyPlayer()
  return self:GetPlayerForCharacter(UnitName("player")) or self:ShortName(UnitName("player"))
end

function A:TotalDKP()
  local total = 0
  for _,p in pairs(self.db.players) do
    total = total + math.max(0, tonumber(p.dkp) or 0)
  end
  return total
end

function A:UsableTreasury()
  return math.max(0, (tonumber(self.db.treasury) or 0) - (tonumber(self.db.reserve) or 0))
end

function A:GoldPerDKP()
  local total = self:TotalDKP()
  if total <= 0 then return 0 end
  return self:UsableTreasury() / total
end

function A:GuildCredit(player)
  local p = self.db.players[player]
  if not p then return 0 end
  return math.floor((tonumber(p.dkp) or 0) * self:GoldPerDKP())
end

function A:EnsurePlayer(player, character)
  if not player or player == "" or player == "Non Guild" then return nil end
  if not self.db.players[player] then
    self.db.players[player] = {main=character or player, alts={}, role="", dkp=0}
  end
  if character and character ~= "" then
    self.db.characterMap[character] = player
    if not self.db.players[player].main or self.db.players[player].main == "" then
      self.db.players[player].main = character
    end
  end
  return self.db.players[player]
end

function A:AddHistory(kind, player, amount, note)
  local h = self.db.history
  table.insert(h, 1, {
    ts = (GetServerTime and GetServerTime()) or time(),
    kind = kind or "INFO",
    player = player or "",
    amount = tonumber(amount) or 0,
    note = note or "",
  })
  while #h > 250 do table.remove(h) end
end

function A:AdjustDKP(player, delta, note)
  if not self:IsOfficer() then return false, "Officer permission required." end
  local p = self.db.players[player]
  if not p then return false, "Unknown player." end
  delta = tonumber(delta)
  if not delta then return false, "Invalid amount." end
  local cap = tonumber(self.db.settings.dkpCap) or 200
  p.dkp = math.max(0, math.min(cap, (tonumber(p.dkp) or 0) + delta))
  self:AddHistory("ADJUST", player, delta, note or "Manual adjustment")
  self:MarkChanged()
  return true
end

function A:GuildRankIndex(name)
  local short = self:Norm(name)
  if short == "" then return nil end
  if not IsInGuild() then return nil end
  if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end
  local n = GetNumGuildMembers and GetNumGuildMembers() or 0
  for i=1,n do
    local memberName, _, rankIndex = GetGuildRosterInfo(i)
    if memberName and self:Norm(memberName) == short then return rankIndex end
  end
  return nil
end

function A:IsOfficer(name)
  name = name or UnitName("player")
  local idx = self:GuildRankIndex(name)
  if idx == nil and self:Norm(name) == self:Norm(UnitName("player")) then
    local _,_,myIdx = GetGuildInfo("player")
    idx = myIdx
  end
  return idx ~= nil and idx <= (tonumber(self.db.settings.officerRankMax) or 1)
end

function A:IsAdmin(name)
  name = name or UnitName("player")
  local idx = self:GuildRankIndex(name)
  if idx == nil and self:Norm(name) == self:Norm(UnitName("player")) then
    local _,_,myIdx = GetGuildInfo("player")
    idx = myIdx
  end
  return idx == 0
end

function A:MarkChanged()
  self:NowVersion()
  if self.BroadcastVersion then self:BroadcastVersion() end
  if self.RefreshUI then self:RefreshUI() end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    local addon = ...
    if addon == ADDON_NAME then A:InitDB() end
  elseif event == "PLAYER_LOGIN" then
    if not A.db then A:InitDB() end
    if A.InitComm then A:InitComm() end
    if A.InitUI then A:InitUI() end
    if A.RequestSync then C_Timer.After(2, function() A:RequestSync() end) end
  elseif event == "GROUP_ROSTER_UPDATE" then
    if A.OnRosterUpdate then A:OnRosterUpdate() end
  elseif event == "GUILD_ROSTER_UPDATE" then
    if A.RefreshUI then A:RefreshUI() end
  end
end)

SLASH_GDKPCREDIT1 = "/gdkpcredit"
SLASH_GDKPCREDIT2 = "/gdkpc"
SlashCmdList.GDKPCREDIT = function(msg)
  msg = string.lower(msg or "")
  if msg == "sync" then
    A:RequestSync()
  elseif msg == "version" then
    A:Print("v"..A.VERSION.." data version "..tostring(A.db.version or 0))
  else
    A:ToggleUI()
  end
end
