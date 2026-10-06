-- Run from the addon root with Lua 5.1: lua tests/officer_spec.lua
local inGuild, selfRank, selfOfficer = true, 2, true
local rows = {{"Accountant-Realm", "Accountant", 2}, {"Member-Realm", "Member", 1},
  {"Master-Realm", "Guild Master", 0}, {"Remote-Realm", "Accountant", 2}}
local permissions, lastOrder = {}, nil
for i=1,13 do permissions[i] = false end
permissions[11] = true
local function flags(order)
  lastOrder = order
  local result = {}
  for i=1,13 do result[i] = false end
  if order == 3 then return permissions end
  return result
end
IsInGuild = function() return inGuild end
UnitName = function() return "Accountant" end
UnitFullName = function() return "Accountant", "Realm" end
GetNormalizedRealmName = function() return "Realm" end
GetGuildInfo = function() if inGuild then return "Gnome Pest Control", "Accountant", selfRank end end
GetNumGuildMembers = function() return #rows end
GetGuildRosterInfo = function(i) return unpack(rows[i]) end
C_GuildInfo = {IsGuildOfficer=function() return selfOfficer end,
  GuildControlGetRankFlags=flags, GuildRoster=function() end}
CreateFrame = function() return {RegisterEvent=function() end, SetScript=function() end} end
SlashCmdList = {}
DEFAULT_CHAT_FRAME = {AddMessage=function() end}
assert(loadfile("Core.lua"))("GDKPCredit")
assert(loadfile("Comm.lua"))()
local A = GDKPCredit
A:InitDB()
local checks = 0
local function check(label, actual, expected)
  assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  checks = checks + 1
end
check("Accountant self API", A:IsOfficer(), true)
check("explicit self", A:IsOfficer("Accountant-Realm"), true)
selfOfficer = false
check("self API false is authoritative", A:IsOfficer(), false)
selfRank = 0
check("GM overrides self API", A:IsOfficer(), true)
check("self GM admin", A:IsAdmin(), true)
selfRank = 2
check("Accountant not admin", A:IsAdmin(), false)
selfOfficer = true
check("remote Accountant permissions", A:IsOfficer("Remote-Realm"), true)
check("one-based rank order", lastOrder, 3)
check("remote nonofficer despite local officer", A:IsOfficer("Member-Realm"), false)
check("remote GM", A:IsOfficer("Master-Realm"), true)
check("unknown sender", A:IsOfficer("Unknown-Realm"), false)
check("foreign realm same officer name", A:IsOfficer("Remote-Other"), false)
check("foreign realm same self name", A:IsOfficer("Accountant-Other"), false)
check("foreign realm GM admin", A:IsAdmin("Master-Other"), false)
check("short local realm officer", A:IsOfficer("Remote"), true)
for _,index in ipairs({3,4,11,12}) do
  for i=1,13 do permissions[i] = false end
  permissions[index] = true
  check("officer flag " .. index, A:IsOfficer("Remote-Realm"), true)
end
for i=1,13 do permissions[i] = false end
permissions[7] = true
check("invite permission insufficient", A:IsOfficer("Remote-Realm"), false)
A.db.settings.officerRankMax = 9
check("negative permissions beat saved threshold", A:IsOfficer("Member-Realm"), false)
C_GuildInfo.GuildControlGetRankFlags = function() error("not ready") end
check("API errors fail closed", A:IsOfficer("Remote-Realm"), false)
C_GuildInfo.GuildControlGetRankFlags = function() return nil end
check("missing flag data fails closed", A:IsOfficer("Remote-Realm"), false)
C_GuildInfo.IsGuildOfficer = function() error("not ready") end
check("self API errors fail closed", A:IsOfficer(), false)
C_GuildInfo.IsGuildOfficer = nil
C_GuildInfo.GuildControlGetRankFlags = flags
permissions[11] = true
check("self rank flags when self API absent", A:IsOfficer(), true)
C_GuildInfo.GuildControlGetRankFlags = nil
A.db.settings.officerRankMax = 1
check("legacy rank 1 allowed", A:IsOfficer("Member-Realm"), true)
check("legacy rank 2 denied", A:IsOfficer("Remote-Realm"), false)
A.db.settings.officerRankMax = 2
check("legacy saved threshold", A:IsOfficer("Remote-Realm"), true)
check("legacy unknown sender denied", A:IsOfficer("Unknown-Realm"), false)
C_GuildInfo.GuildControlGetRankFlags = flags
C_GuildInfo.IsGuildOfficer = function() return true end
inGuild = false
check("unguilded self", A:IsOfficer(), false)
check("unguilded remote", A:IsOfficer("Remote-Realm"), false)
check("unguilded admin", A:IsAdmin(), false)
inGuild = true
local requested
A.RequestSync = function(_, sender) requested = sender end
A:OnAddonMessage(A.PREFIX, "V|999", "WHISPER", "Remote-Other")
check("foreign realm version rejected", requested, nil)
A:OnAddonMessage(A.PREFIX, "V|999", "GUILD", "Member-Realm")
check("nonofficer version rejected", requested, nil)
A:OnAddonMessage(A.PREFIX, "V|999", "GUILD", "Remote-Realm")
check("officer version accepted with realm", requested, "Remote-Realm")
local snapshot = "META\t999\t123\t4"
A:OnAddonMessage(A.PREFIX, "S|bad|1|1|" .. snapshot, "WHISPER", "Remote-Other")
check("foreign realm snapshot rejected", A.db.version, 1)
A:OnAddonMessage(A.PREFIX, "S|bad|1|1|" .. snapshot, "WHISPER", "Member-Realm")
check("nonofficer snapshot rejected", A.db.version, 1)
check("direct snapshot validation", A:ApplySnapshot(snapshot, "Remote-Other"), false)
A:OnAddonMessage(A.PREFIX, "S|good|1|1|" .. snapshot, "WHISPER", "Remote-Realm")
check("officer snapshot accepted", A.db.version, 999)
check("officer snapshot applied", A.db.treasury, 123)
rows = {}
check("uncached sender fails closed", A:IsOfficer("Remote-Realm"), false)
SlashCmdList.GDKPCREDIT("officer")
print("PASS: " .. checks .. " officer and sender validation checks (" .. _VERSION .. ")")
