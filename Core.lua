local ADDON_NAME = ...
GDKPCredit = GDKPCredit or {}
local A = GDKPCredit

A.PREFIX = "GDKPCredit"
A.VERSION = "0.2.0-rc1"
A.TABS = {"My DKP", "Guild DKP", "Raid", "History", "Admin", "Raid Settings"}

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
  if self.activeLedgerKey and GDKPCreditDB.guildLedgers then self.db=GDKPCreditDB.guildLedgers[self.activeLedgerKey] end
  if self.ActivateGuildLedger then self:ActivateGuildLedger() end
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
  if self.InitAccountLinks then self:InitAccountLinks() end
  if self.InitAdditionalMembers then self:InitAdditionalMembers() end
  if self.InitRaidProfiles then self:InitRaidProfiles() end
  if self.activeLedgerKey then GDKPCreditDB.localAccount=self.db.localAccount end
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
  if not self:IsOfficer() then return false, "Only the designated ledger officer can edit guild data." end
  if self.ApplyDKPDecay then self:ApplyDKPDecay() end
  local p = self.db.players[player]
  if not p then return false, "Unknown player." end
  delta = tonumber(delta)
  if not delta or delta~=delta or delta==math.huge or delta==-math.huge then return false, "Invalid amount." end
  local cap = tonumber(self.db.settings.dkpCap) or 200
  local before=tonumber(p.dkp) or 0
  p.dkp = math.max(0, math.min(cap, before + delta))
  local actual=p.dkp-before
  if self.RecordDKPGain then self:RecordDKPGain(player,actual) end
  self:AddHistory("ADJUST", player, actual, note or "Manual adjustment")
  self:MarkChanged()
  return true
end

-- Permission identities retain realms; DKP aliases deliberately use ShortName elsewhere.
function A:GuildIdentity(name)
  if type(name) ~= "string" or name == "" then return nil end
  local character, realm = name:match("^([^%-]+)%-(.+)$")
  if not character then
    character = name
    realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or
      (GetRealmName and GetRealmName())
  end
  if not realm or realm == "" then return nil end
  realm = realm:gsub("%s", "")
  return string.lower(character .. "-" .. realm)
end

function A:IsLocalGuildPlayer(name)
  local player, realm
  if UnitFullName then player, realm = UnitFullName("player") end
  player = player or UnitName("player")
  local identity = self:GuildIdentity(realm and realm ~= "" and (player .. "-" .. realm) or player)
  return identity ~= nil and identity == self:GuildIdentity(name)
end

function A:GuildRankIndex(name)
  local identity = self:GuildIdentity(name)
  if not identity or not IsInGuild() then return nil end
  if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end
  local n = GetNumGuildMembers and GetNumGuildMembers() or 0
  if not GetGuildRosterInfo then return nil end
  for i=1,n do
    local memberName, _, rankIndex = GetGuildRosterInfo(i)
    if self:GuildIdentity(memberName) == identity then return rankIndex end
  end
  return nil
end

function A:IsOfficer(name)
  if not IsInGuild() then return false, "not in guild" end
  local isSelf = name == nil or self:IsLocalGuildPlayer(name)
  local idx
  if isSelf then
    local guild, rankName
    guild, rankName, idx = GetGuildInfo("player")
    if not guild then return false, "guild info unavailable" end
  else
    idx = self:GuildRankIndex(name)
  end
  if idx == 0 then return true, "Guild Master" end
  -- The self-only API must never authorize a remote sender.
  if isSelf and C_GuildInfo and type(C_GuildInfo.IsGuildOfficer) == "function" then
    local ok, officer = pcall(C_GuildInfo.IsGuildOfficer)
    return ok and officer == true, "Blizzard self officer API"
  end
  if type(idx) ~= "number" or idx < 0 or idx ~= math.floor(idx) then
    return false, "guild rank unavailable"
  end
  if C_GuildInfo and type(C_GuildInfo.GuildControlGetRankFlags) == "function" then
    -- Roster rankIndex is zero-based; the permission API rankOrder is one-based.
    local ok, flags = pcall(C_GuildInfo.GuildControlGetRankFlags, idx + 1)
    if not ok or type(flags) ~= "table" then return false, "guild permissions unavailable" end
    -- Blizzard GUILDCONTROL_OPTION3/4: officer chat; OPTION11/12: officer notes.
    return flags[3] == true or flags[4] == true or flags[11] == true or flags[12] == true,
      "guild rank permissions"
  end
  -- Only clients lacking the relevant permission API use the saved legacy threshold.
  local settings = self.db and self.db.settings or {}
  return idx <= (tonumber(settings.officerRankMax) or 1), "legacy rank fallback"
end

function A:IsAdmin(name)
  if not IsInGuild() then return false end
  local idx
  if name == nil or self:IsLocalGuildPlayer(name) then
    local guild, rankName
    guild, rankName, idx = GetGuildInfo("player")
    if not guild then return false end
  else
    idx = self:GuildRankIndex(name)
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
    if A.ActivateGuildLedger and A:ActivateGuildLedger() then A:InitDB() end
    if A.InitComm then A:InitComm() end
    if A.SendRaw then C_Timer.After(3,function() A:SendRaw("PERMQ","GUILD"); if A.SendAdminPolicy then A:SendAdminPolicy() end end) end
    if A.InitUI then A:InitUI() end
    if A.StartDecayTimer then A:StartDecayTimer() end
    if A.RequestSync then C_Timer.After(2, function() A:RequestSync(); if A.AnnounceAccountCharacter then A:AnnounceAccountCharacter() end end) end
  elseif event == "GROUP_ROSTER_UPDATE" then
    if A.OnRosterUpdate then A:OnRosterUpdate() end
  elseif event == "GUILD_ROSTER_UPDATE" then
    if A.ActivateGuildLedger and A:ActivateGuildLedger() then
      A:InitDB(); if A.RequestSync then A:RequestSync() end
      if A.SendRaw then A:SendRaw("PERMQ","GUILD") end
    end
    if A.AnnounceAccountCharacter then
      local now=(GetServerTime and GetServerTime()) or time()
      if not A.lastAccountAnnouncement or now-A.lastAccountAnnouncement>=60 then
        A.lastAccountAnnouncement=now; A:AnnounceAccountCharacter()
      end
    end
    if A.OnRosterUpdate then A:OnRosterUpdate() end
    if A.RefreshUI then A:RefreshUI() end
  end
end)

SLASH_GDKPCREDIT1 = "/gdkpcredit"
SLASH_GDKPCREDIT2 = "/gdkpc"
SlashCmdList.GDKPCREDIT = function(msg)
  msg = string.lower(msg or "")
  if msg == "sync" then
    A:RequestSync()
  elseif msg == "officer" then
    local guild, rank, idx = GetGuildInfo("player")
    local officer, source = A:IsOfficer()
    A:Print("Guild: "..tostring(guild).."; rank: "..tostring(rank).." ("..tostring(idx)..
      "); officer: "..tostring(officer).."; check: "..source)
  elseif msg == "version" then
    A:Print("v"..A.VERSION.." data version "..tostring(A.db.version or 0))
  else
    A:ToggleUI()
  end
end
