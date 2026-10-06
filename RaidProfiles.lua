GDKPCredit = GDKPCredit or {}
local A = GDKPCredit

A.CLASSIC_RAIDS = {
  {id="mc", name="Molten Core", size=40},
  {id="onyxia", name="Onyxia's Lair", size=40},
  {id="bwl", name="Blackwing Lair", size=40},
  {id="zg", name="Zul'Gurub", size=20},
  {id="aq20", name="Ruins of Ahn'Qiraj", size=20},
  {id="aq40", name="Temple of Ahn'Qiraj", size=40},
  {id="naxx", name="Naxxramas", size=40},
}
A.RAID_RULE_FIELDS = {"attendanceDKP", "wbDKP", "consumeDKP", "wbThreshold", "consumeThreshold", "dkpCap", "guildCut"}
local defaults = {attendanceDKP=4, wbDKP=3, consumeDKP=3, wbThreshold=3, consumeThreshold=2, dkpCap=200, guildCut=0.10}

function A:ClassicRaid(id)
  for _, raid in ipairs(self.CLASSIC_RAIDS) do if raid.id == id then return raid end end
end

function A:DefaultRaidRules()
  local rules = {}
  local saved = self.db and self.db.settings or {}
  for _, key in ipairs(self.RAID_RULE_FIELDS) do rules[key] = saved[key] or defaults[key] end
  return rules
end

function A:ValidateRaidRules(values)
  if type(values) ~= "table" then return nil, "Missing raid settings." end
  local rules = {}
  for _, key in ipairs(self.RAID_RULE_FIELDS) do
    local value = tonumber(values[key])
    if not value or value ~= value or value == math.huge or value < 0 then
      return nil, "Invalid value for "..key..". Use a non-negative number."
    end
    if key == "guildCut" then
      if value > 1 then return nil, "Guild cut must be between 0% and 100%." end
    elseif value ~= math.floor(value) or value > 1000000 then
      return nil, key.." must be a whole number between 0 and 1000000."
    end
    if (key == "wbThreshold" or key == "consumeThreshold") and value > 80 then
      return nil, "Buff and consume thresholds cannot exceed 80."
    end
    rules[key] = value
  end
  return rules
end

function A:InitRaidProfiles()
  self.db.raidProfiles = self.db.raidProfiles or {}
  for _, raid in ipairs(self.CLASSIC_RAIDS) do
    local valid = self:ValidateRaidRules(self.db.raidProfiles[raid.id])
    self.db.raidProfiles[raid.id] = valid or self:DefaultRaidRules()
  end
  -- Preserve existing active raids when upgrading; pin their previous global rules.
  if self.db.activeRaid and not self.db.activeRaid.rules then
    self.db.activeRaid.rules = self.DeepCopy(self:DefaultRaidRules())
  end
end

function A:GetRaidProfile(id)
  if not self:ClassicRaid(id) then return nil end
  local profiles = self.db.raidProfiles or {}
  return self.DeepCopy(profiles[id] or self:DefaultRaidRules())
end

function A:CanEditRaidSettings()
  return self:IsOfficer()
end

function A:SaveRaidProfile(id, values)
  if not self:CanEditRaidSettings() then return false, "Your guild rank does not have addon admin access." end
  local raid = self:ClassicRaid(id)
  if not raid then return false, "Choose a Classic raid." end
  local rules, err = self:ValidateRaidRules(values)
  if not rules then return false, err end
  self.db.raidProfiles = self.db.raidProfiles or {}
  self.db.raidProfiles[id] = rules
  self:AddHistory("RAID_RULES", "", 0, "Updated awards for "..raid.name)
  self:MarkChanged()
  return true
end

function A:GetRaidRules(raid)
  raid = raid or self.db.activeRaid
  return raid and raid.rules or self.db.settings
end
