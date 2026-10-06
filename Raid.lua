GDKPCredit = GDKPCredit or {}
local A = GDKPCredit

local function auraSpellID(unit, index)
  if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    local data = C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")
    if not data then return nil end
    return data.spellId, data.name
  end
  if UnitBuff then
    local name, _, _, _, _, _, _, _, _, spellId = UnitBuff(unit, index)
    return spellId, name
  end
end

function A:CountTrackedAuras(unit)
  local wb, con = 0, 0
  local seenWB, seenCon = {}, {}
  for i=1,80 do
    local spellId = auraSpellID(unit, i)
    if not spellId then break end
    if self.WORLD_BUFFS[spellId] and not seenWB[spellId] then
      seenWB[spellId] = true
      wb = wb + 1
    end
    if self.CONSUMES[spellId] and not seenCon[spellId] then
      seenCon[spellId] = true
      con = con + 1
    end
  end
  return wb, con
end

function A:CurrentRoster()
  local roster = {}
  if IsInRaid() then
    for i=1,GetNumGroupMembers() do
      local unit = "raid"..i
      if UnitExists(unit) then
        local char = self:ShortName(UnitName(unit))
        if char and char ~= "" then roster[char] = unit end
      end
    end
  elseif IsInGroup() then
    roster[self:ShortName(UnitName("player"))] = "player"
    for i=1,GetNumSubgroupMembers() do
      local unit = "party"..i
      if UnitExists(unit) then roster[self:ShortName(UnitName(unit))] = unit end
    end
  else
    roster[self:ShortName(UnitName("player"))] = "player"
  end
  return roster
end

function A:StartRaid()
  if not self:IsOfficer() then self:Print("Officer permission required.") return end
  if self.db.activeRaid then self:Print("A raid is already active.") return end
  local instance = GetInstanceInfo() or "Raid"
  local r = {
    id = tostring((GetServerTime and GetServerTime()) or time()),
    name = instance ~= "" and instance or "Raid",
    start = (GetServerTime and GetServerTime()) or time(),
    players = {},
    locked = false,
    grossPot = 0,
    guildCut = 0,
  }
  local roster = self:CurrentRoster()
  for char,_ in pairs(roster) do
    local player = self:GetPlayerForCharacter(char) or char
    if player ~= "Non Guild" then
      self:EnsurePlayer(player, char)
      r.players[player] = {
        char = char,
        presentStart = true,
        attendanceBroken = false,
        attendance = false,
        wb = false,
        consumes = false,
        wbCount = 0,
        consumeCount = 0,
      }
    end
  end
  self.db.activeRaid = r
  self:AddHistory("RAID", "", 0, "Started "..r.name)
  self:MarkChanged()
  self:Print("Raid started: "..r.name)
end

function A:OnRosterUpdate()
  local r = self.db and self.db.activeRaid
  if not r or r.ended then return end
  local roster = self:CurrentRoster()
  local presentPlayers = {}
  for char,_ in pairs(roster) do
    local player = self:GetPlayerForCharacter(char) or char
    if player ~= "Non Guild" then
      presentPlayers[player] = char
      if not r.players[player] then
        self:EnsurePlayer(player, char)
        r.players[player] = {
          char = char, presentStart = false, attendanceBroken = true,
          attendance = false, wb = false, consumes = false, wbCount = 0, consumeCount = 0,
        }
      else
        r.players[player].char = char
      end
    end
  end
  for player,e in pairs(r.players) do
    if e.presentStart and not presentPlayers[player] then e.attendanceBroken = true end
  end
  if self.RefreshUI then self:RefreshUI() end
end

function A:RunReadinessCheck(targetPlayer)
  if not self:IsOfficer() then self:Print("Officer permission required.") return end
  local r = self.db.activeRaid
  if not r then self:Print("Start a raid first.") return end
  if r.locked then self:Print("Raid check is locked.") return end

  local roster = self:CurrentRoster()
  local checked = 0
  for char,unit in pairs(roster) do
    local player = self:GetPlayerForCharacter(char) or char
    if player ~= "Non Guild" and (not targetPlayer or player == targetPlayer) then
      self:EnsurePlayer(player, char)
      local e = r.players[player]
      if not e then
        e = {char=char,presentStart=false,attendanceBroken=true,attendance=false,wb=false,consumes=false,wbCount=0,consumeCount=0}
        r.players[player] = e
      end
      local wbCount, conCount = self:CountTrackedAuras(unit)
      e.wbCount = math.max(e.wbCount or 0, wbCount)
      e.consumeCount = math.max(e.consumeCount or 0, conCount)
      -- Upgrade only: once a player passes a criterion, later death/rechecks cannot remove it.
      if wbCount >= (self.db.settings.wbThreshold or 3) then e.wb = true end
      if conCount >= (self.db.settings.consumeThreshold or 2) then e.consumes = true end
      checked = checked + 1
    end
  end
  self:MarkChanged()
  self:Print("Readiness checked for "..checked.." raid member(s). Existing passes were preserved.")
end

function A:SetRaidPass(player, criterion)
  if not self:IsOfficer() then return end
  local r = self.db.activeRaid
  if not r or not r.players[player] then return end
  local e = r.players[player]
  if criterion == "wb" then e.wb = true
  elseif criterion == "consumes" then e.consumes = true
  elseif criterion == "attendance" then e.attendance = true; e.attendanceOverride = true end
  self:MarkChanged()
end

function A:LockRaidCheck()
  if not self:IsOfficer() or not self.db.activeRaid then return end
  self.db.activeRaid.locked = true
  self:MarkChanged()
  self:Print("WB + consume results locked for this raid.")
end

function A:UnlockRaidCheck()
  if not self:IsOfficer() or not self.db.activeRaid then return end
  self.db.activeRaid.locked = false
  self:MarkChanged()
end

function A:EndRaid(grossPot)
  if not self:IsOfficer() then self:Print("Officer permission required.") return end
  local r = self.db.activeRaid
  if not r then self:Print("No active raid.") return end

  grossPot = tonumber(grossPot) or 0
  r.grossPot = math.max(0, grossPot)
  r.guildCut = math.floor(r.grossPot * (tonumber(self.db.settings.guildCut) or 0.10))
  self.db.treasury = (tonumber(self.db.treasury) or 0) + r.guildCut

  local roster = self:CurrentRoster()
  local presentPlayers = {}
  for char,_ in pairs(roster) do
    local p = self:GetPlayerForCharacter(char) or char
    presentPlayers[p] = true
  end

  local awarded = 0
  for player,e in pairs(r.players) do
    if e.attendanceOverride then
      e.attendance = true
    else
      e.attendance = e.presentStart and not e.attendanceBroken and presentPlayers[player] == true
    end
    local dkp = 0
    if e.attendance then dkp = dkp + (self.db.settings.attendanceDKP or 4) end
    if e.wb then dkp = dkp + (self.db.settings.wbDKP or 3) end
    if e.consumes then dkp = dkp + (self.db.settings.consumeDKP or 3) end
    e.dkpAwarded = dkp
    if dkp > 0 and player ~= "Non Guild" then
      local p = self:EnsurePlayer(player, e.char)
      local cap = tonumber(self.db.settings.dkpCap) or 200
      p.dkp = math.min(cap, (tonumber(p.dkp) or 0) + dkp)
      awarded = awarded + dkp
      self:AddHistory("RAID_DKP", player, dkp, r.name)
    end
  end

  r.ended = (GetServerTime and GetServerTime()) or time()
  table.insert(self.db.raids, 1, r)
  while #self.db.raids > 50 do table.remove(self.db.raids) end
  self.db.activeRaid = nil
  self:AddHistory("RAID", "", awarded, "Ended "..r.name.."; guild cut "..r.guildCut.."g")
  self:MarkChanged()
  self:Print("Raid ended. Awarded "..awarded.." total DKP; treasury +"..r.guildCut.."g.")
end

function A:RaidExportText(raid)
  raid = raid or self.db.activeRaid or self.db.raids[1]
  if not raid then return "No raid data." end
  local lines = {}
  table.insert(lines, "GDKPCREDIT_RAID\t"..tostring(raid.id or "").."\t"..tostring(raid.name or "Raid").."\t"..tostring(raid.grossPot or 0).."\t"..tostring(raid.guildCut or 0))
  table.insert(lines, "Player\tCharacter\tAttendance\tWorldBuffs\tConsumes\tDKP")
  local names = {}
  for p in pairs(raid.players or {}) do table.insert(names,p) end
  table.sort(names, function(a,b) return string.lower(a)<string.lower(b) end)
  for _,p in ipairs(names) do
    local e=raid.players[p]
    table.insert(lines, table.concat({p,e.char or "",e.attendance and "Yes" or "No",e.wb and "Yes" or "No",e.consumes and "Yes" or "No",tostring(e.dkpAwarded or 0)},"\t"))
  end
  return table.concat(lines,"\n")
end
