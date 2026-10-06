GDKPCredit = GDKPCredit or {}
local A = GDKPCredit

function A:ValidateDisplayName(name)
  if type(name)~="string" or name:find("[%c|]") or #name>128 then
    return nil,"Use a plain name without chat formatting or control characters."
  end
  name=name:match("^%s*(.-)%s*$")
  local _,characters=name:gsub("[^\128-\191]","")
  if characters>32 then return nil,"Player names can contain up to 32 characters." end
  return name
end

function A:PlayerDisplayName(player)
  local info=self.db.players[player]
  return info and info.displayName and info.displayName~="" and info.displayName or player or ""
end

function A:SetMyDisplayName(name)
  local valid,err=self:ValidateDisplayName(name)
  if not valid then return false,err end
  local profile=self:LearnAccountCharacter()
  if not profile then return false,"Join a guild to customize your player profile." end
  profile.displayName=valid
  -- The local preference never changes the authoritative ledger or its keys.
  self:SubmitMyCharacter()
  if self.RefreshMemberProfile then self:RefreshMemberProfile() end
  return true,"Player name saved. It will synchronize when an officer is online. Blank restores the default name."
end

function A:SendMyDisplayName(officer)
  local profile=self:LearnAccountCharacter()
  if not profile or profile.displayName==nil then return end
  self:SendRaw("D|"..self.db.localAccount.id.."|"..self:LocalLinkCode().."|"..profile.displayName,"WHISPER",officer)
end

function A:ReceiveDisplayName(sender,id,code,name,channel)
  if channel~="WHISPER" or not self:IsOfficer() or not self:ValidLinkCode(code) then return false end
  if not self:IsTrackedCharacter(sender) then return false end
  local profiles=self:AccountLinkTables()
  local target=profiles and profiles[id]
  if not target or self:AccountCredentials()[id]~=code or self:TrackingPlayer(sender)~=target then return false end
  local valid=self:ValidateDisplayName(name)
  if not valid then return false end
  local player=self.db.players[target]; if not player then return false end
  if (player.displayName or "")==valid then return true end
  player.displayName=valid~="" and valid or nil
  self:AddHistory("PROFILE",target,0,"Player display name updated")
  self:MarkChanged()
  return true
end
