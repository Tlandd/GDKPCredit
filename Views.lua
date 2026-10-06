GDKPCredit = GDKPCredit or {}
local A = GDKPCredit

local function matches(value, query)
  return string.lower(tostring(value or "")):find(query, 1, true) ~= nil
end

function A:GuildView(query, sortKey, descending)
  query = string.lower(query or "")
  local rows = {}
  local members = self:GuildTrackingRoster()
  for name, player in pairs(self.db.players) do
    local found = matches(name, query) or matches(player.displayName, query) or matches(player.main, query)
    for _, alt in ipairs(player.alts or {}) do found = found or matches(alt, query) end
    if found and self:IsTrackedPlayer(name, player, members) then rows[#rows+1] = name end
  end
  table.sort(rows, function(a, b)
    local av, bv
    if sortKey == "dkp" then
      av, bv = tonumber(self.db.players[a].dkp) or 0, tonumber(self.db.players[b].dkp) or 0
    elseif sortKey == "credit" then
      av, bv = self:GuildCredit(a), self:GuildCredit(b)
    elseif sortKey == "main" then
      av, bv = string.lower(self.db.players[a].main or ""), string.lower(self.db.players[b].main or "")
    else av, bv = string.lower(self:PlayerDisplayName(a)), string.lower(self:PlayerDisplayName(b)) end
    if av == bv then return string.lower(a) < string.lower(b) end
    if descending then return av > bv end
    return av < bv
  end)
  return rows
end

function A:HistoryView(query)
  query = string.lower(query or "")
  local rows = {}
  for _, entry in ipairs(self.db.history) do
    if matches(entry.player, query) or matches(self:PlayerDisplayName(entry.player), query) or matches(entry.note, query) or matches(entry.kind, query) then
      rows[#rows+1] = entry
    end
  end
  return rows
end

function A:RaidView(query, missingOnly)
  query = string.lower(query or "")
  local rows, summary = {}, {total=0, wb=0, consumes=0, attendance=0}
  local raid = self.db.activeRaid
  if not raid then return rows, summary end
  local members = self:GuildTrackingRoster()
  for name, entry in pairs(raid.players or {}) do
    if self:IsTrackedCharacter(entry.char, members) then
    summary.total = summary.total + 1
    if entry.wb then summary.wb = summary.wb + 1 end
    if entry.consumes then summary.consumes = summary.consumes + 1 end
    if entry.attendanceOverride or (entry.presentStart and not entry.attendanceBroken) then
      summary.attendance = summary.attendance + 1
    end
    if (matches(name, query) or matches(self:PlayerDisplayName(name), query) or matches(entry.char, query)) and
      (not missingOnly or not entry.wb or not entry.consumes) then rows[#rows+1] = name end
    end
  end
  table.sort(rows, function(a,b) return string.lower(a) < string.lower(b) end)
  return rows, summary
end

-- This preview uses the exact award computation that EndRaid commits.
function A:RaidAwardPreview(grossPot)
  local raid = self.db.activeRaid
  if not raid then return nil, "No active raid." end
  local pot = tonumber(grossPot)
  if not pot or pot < 0 or pot ~= pot or pot == math.huge then
    return nil, "Enter a valid, non-negative gross pot. Use 0 for a raid without gold."
  end
  local roster, ready = self:CurrentRoster()
  if ready == false then return nil, "Guild roster is loading. Try again shortly." end
  local present = {}
  for character in pairs(roster) do present[self:TrackingPlayer(character)] = true end
  local members = self:GuildTrackingRoster()
  local s = self:GetRaidRules(raid)
  local preview = {id=raid.id, name=raid.name, grossPot=pot,
    guildCut=math.floor(pot * (tonumber(s.guildCut) or 0.10)), total=0, capped=0, players={}}
  for name, entry in pairs(raid.players or {}) do
    local attendance = entry.attendanceOverride == true or
      (entry.presentStart == true and not entry.attendanceBroken and present[name] == true)
    local earned = (attendance and (s.attendanceDKP or 4) or 0) +
      (entry.wb and (s.wbDKP or 3) or 0) + (entry.consumes and (s.consumeDKP or 3) or 0)
    local before = tonumber(self.db.players[name] and self.db.players[name].dkp) or 0
    local after = math.max(before, math.min(tonumber(s.dkpCap) or 200, before + earned))
    local eligible = self:IsTrackedCharacter(entry.char, members)
    local actual = eligible and name ~= "Non Guild" and math.max(0, after - before) or 0
    preview.players[name] = {attendance=attendance, earned=earned, actual=actual, after=after}
    preview.total = preview.total + actual
    if eligible and name ~= "Non Guild" and actual < earned then preview.capped = preview.capped + 1 end
  end
  return preview
end
