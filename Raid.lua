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
  local members, ready = self:GuildTrackingRoster()
  local function add(unit)
    if not UnitExists(unit) then return end
    local character = self:TrackingCharacter(unit)
    if character and self:IsTrackedCharacter(character, members) then roster[character] = unit end
  end
  if IsInRaid() then
    for i=1,GetNumGroupMembers() do add("raid"..i) end
  elseif IsInGroup() then
    add("player")
    for i=1,GetNumSubgroupMembers() do add("party"..i) end
  else add("player") end
  return roster, ready
end

function A:StartRaid(raidType)
  if not self:IsOfficer() then return false, "Your guild rank does not have addon admin access." end
  if self.db.activeRaid then return false, "A raid is already active." end
  local template = self:ClassicRaid(raidType)
  if not template then return false, "Choose a Classic raid before starting." end
  local roster, ready = self:CurrentRoster()
  if ready == false then return false, "Guild roster is loading. Try again in a moment." end
  if not next(roster) then return false, "No eligible guild members or exceptions are in the group." end
  local rules, err = self:ValidateRaidRules(self:GetRaidProfile(raidType))
  if not rules then return false, err end
  local r = {
    id = tostring((GetServerTime and GetServerTime()) or time()),
    name = template.name,
    raidType = raidType,
    rules = rules,
    start = (GetServerTime and GetServerTime()) or time(),
    players = {},
    locked = false,
    grossPot = 0,
    guildCut = 0,
  }
  for char,_ in pairs(roster) do
    local player = self:TrackingPlayer(char)
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
  return true
end

function A:OnRosterUpdate()
  local r = self.db and self.db.activeRaid
  if not r or r.ended or not self:IsOfficer() then return end
  local roster, ready = self:CurrentRoster()
  if ready == false then return end
  local presentPlayers = {}
  for char,_ in pairs(roster) do
    local player = self:TrackingPlayer(char)
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
  if not self:IsOfficer() then self:Print("Your guild rank does not have addon admin access.") return end
  local r = self.db.activeRaid
  if not r then self:Print("Start a raid first.") return end
  if r.locked then self:Print("Raid check is locked.") return end

  local roster, ready = self:CurrentRoster()
  if ready == false then self:Print("Guild roster is loading. Try the check again shortly.") return end
  local rules = self:GetRaidRules(r)
  local checked = 0
  for char,unit in pairs(roster) do
    local player = self:TrackingPlayer(char)
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
      if wbCount >= (rules.wbThreshold or 3) then e.wb = true end
      if conCount >= (rules.consumeThreshold or 2) then e.consumes = true end
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
  if not self:IsTrackedCharacter(e.char) then self:Print("This character is not eligible for guild tracking.") return end
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
  if not self:IsOfficer() then self:Print("Your guild rank does not have addon admin access.") return end
  local r = self.db.activeRaid
  if not r then self:Print("No active raid.") return end

  if self.ApplyDKPDecay then self:ApplyDKPDecay() end
  local preview, err = self:RaidAwardPreview(grossPot)
  if not preview then self:Print(err) return end
  r.grossPot = preview.grossPot
  r.guildCut = preview.guildCut
  self.db.treasury = (tonumber(self.db.treasury) or 0) + r.guildCut

  local awarded = 0
  for player,e in pairs(r.players) do
    local award = preview.players[player]
    e.attendance = award.attendance
    e.dkpAwarded = award.actual
    if award.actual > 0 and player ~= "Non Guild" then
      local p = self:EnsurePlayer(player, e.char)
      p.dkp = award.after
      if self.RecordDKPGain then self:RecordDKPGain(player,award.actual) end
      awarded = awarded + award.actual
      self:AddHistory("RAID_DKP", player, award.actual, r.name)
    end
  end

  r.ended = (GetServerTime and GetServerTime()) or time()
  table.insert(self.db.raids, 1, r)
  while #self.db.raids > 50 do table.remove(self.db.raids) end
  self.db.activeRaid = nil
  self:AddHistory("RAID", "", awarded, "Ended "..r.name.."; guild cut "..r.guildCut.."g")
  self:MarkChanged()
  if self.ProcessAutomaticAccountLinks then self:ProcessAutomaticAccountLinks() end
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
