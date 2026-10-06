GDKPCredit = GDKPCredit or {}
local A = GDKPCredit

function A:TrackingGuildKey()
  local guild = GetGuildInfo("player")
  local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName())
  if not guild or not realm then return nil end
  return string.lower(guild.."-"..realm:gsub("%s", ""))
end

function A:InitAdditionalMembers()
  self.db.additionalMembersByGuild = self.db.additionalMembersByGuild or {}
  local legacy = self.db.trackingExceptions
  if type(legacy) == "table" and legacy.guild and not self.db.additionalMembersByGuild[legacy.guild] then
    local names = self:ValidateTrackingExceptions(legacy.names or {})
    if names then self.db.additionalMembersByGuild[legacy.guild] = names end
  end
  self.db.trackingExceptions = nil
end

function A:TrackingExceptions()
  local guild = self:TrackingGuildKey()
  local saved = self.db.additionalMembersByGuild or {}
  if guild and saved[guild] then return saved[guild] end
  local legacy = self.db.trackingExceptions
  if legacy and guild and legacy.guild == guild then return legacy.names or {} end
  return {}
end

function A:ValidateTrackingExceptions(names)
  if type(names) ~= "table" then return nil, "Enter a list of character names." end
  local result, seen = {}, {}
  for _, value in ipairs(names) do
    if type(value) ~= "string" then return nil, "Invalid character name." end
    value = value:match("^%s*(.-)%s*$")
    if value ~= "" then
      local character, realm = value:match("^([^%-]+)%-(.+)$")
      character = character or value
      if character:find("[%s%c%d%p]") or (realm and realm:find("[%c|]")) then
        return nil, "Use Character or Character-Realm, without numbers or special symbols in the character name."
      end
      realm = realm or (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName())
      if not realm or realm == "" then return nil, "Realm information is unavailable." end
      value = character.."-"..realm:gsub("%s", "")
      local identity = self:GuildIdentity(value)
      if not identity then return nil, "Invalid character identity." end
      if seen[identity] then return nil, "Each member must have a unique character identity." end
      seen[identity] = true; result[#result+1] = value
    end
  end
  return result
end

function A:SaveTrackingExceptions(names, note)
  if not self:IsOfficer() then return false, "Only the designated ledger officer can edit guild data." end
  local guild = self:TrackingGuildKey()
  if not guild then return false, "Guild information is unavailable." end
  local valid, err = self:ValidateTrackingExceptions(names)
  if not valid then return false, err end
  self.db.additionalMembersByGuild = self.db.additionalMembersByGuild or {}
  self.db.additionalMembersByGuild[guild] = valid
  self.db.trackingExceptions = nil
  self:AddHistory("MEMBERS", "", 0, note or ("Updated Additional Members: "..#valid.." characters"))
  if self.OnRosterUpdate then self:OnRosterUpdate() end
  self:MarkChanged()
  return true
end

function A:GuildTrackingRoster()
  local members = {}
  if not IsInGuild() then return members, false end
  local n = GetNumGuildMembers and GetNumGuildMembers() or 0
  if GetGuildRosterInfo then
    for i=1,n do
      local name = GetGuildRosterInfo(i)
      local identity = self:GuildIdentity(name)
      if identity then members[identity] = true end
    end
  end
  local ready = next(members) ~= nil
  if not ready then
    if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end
  end
  return members, ready
end

-- Eligibility grants tracking and awards only. Officer validation never reads this list.
function A:IsTrackedCharacter(name, members)
  local identity = self:GuildIdentity(name)
  if not identity then return false end
  for _, exception in ipairs(self:TrackingExceptions()) do
    if self:GuildIdentity(exception) == identity then return true end
  end
  if not members then members = self:GuildTrackingRoster() end
  return members[identity] == true
end

function A:TrackingCharacter(unit)
  local name, realm
  if UnitFullName then name, realm = UnitFullName(unit) end
  if not name then name, realm = UnitName(unit) end
  if not name or name == "" then return nil end
  if name:find("-", 1, true) then return name end
  local localRealm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName())
  if realm and realm ~= "" and string.lower(realm:gsub("%s", "")) ~= string.lower(localRealm or "") then
    return name.."-"..realm:gsub("%s", "")
  end
  return name
end

function A:TrackingPlayer(character)
  -- Cross-realm guests need a separate identity from a same-name local character.
  local _, realm = character:match("^([^%-]+)%-(.+)$")
  local localRealm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName())
  if realm and string.lower(realm:gsub("%s", "")) ~= string.lower(localRealm or "") then
    return self.db.characterMap[character] or character
  end
  return self:GetPlayerForCharacter(character) or self:ShortName(character)
end

function A:IsTrackedPlayer(name, info, members)
  if self:IsTrackedCharacter(name, members) or self:IsTrackedCharacter(info.main, members) then return true end
  for _, character in ipairs(info.alts or {}) do
    if self:IsTrackedCharacter(character, members) then return true end
  end
  for character, owner in pairs(self.db.characterMap) do
    if owner == name and self:IsTrackedCharacter(character, members) then return true end
  end
  return false
end

function A:AddAdditionalMember(name)
  local valid, err = self:ValidateTrackingExceptions({name})
  if not valid then return false, err end
  if #valid == 0 then return false, "Enter Character or Character-Realm." end
  local names = self.DeepCopy(self:TrackingExceptions())
  names[#names+1] = valid[1]
  return self:SaveTrackingExceptions(names, "Added member "..valid[1])
end

function A:RemoveAdditionalMember(name)
  local identity = self:GuildIdentity(name)
  local names, found = {}, false
  for _, member in ipairs(self:TrackingExceptions()) do
    if self:GuildIdentity(member) == identity then found = true else names[#names+1] = member end
  end
  if not found then return false, "Member is no longer in this list." end
  return self:SaveTrackingExceptions(names, "Removed member "..tostring(name))
end

function A:AdditionalMembersView(query)
  local names = {}
  query = string.lower(query or "")
  for _, name in ipairs(self:TrackingExceptions()) do
    if string.lower(name):find(query,1,true) then names[#names+1] = name end
  end
  table.sort(names,function(a,b) return string.lower(a)<string.lower(b) end)
  return names
end
