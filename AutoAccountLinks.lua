GDKPCredit = GDKPCredit or {}
local A = GDKPCredit

function A:ValidLinkCode(code)
  return type(code)=="string" and #code==48 and code:match("^[0-9a-f]+$")~=nil
end

function A:LocalLinkCode()
  self:InitAccountLinks()
  local account=self.db.localAccount
  if not self:ValidLinkCode(account.linkCode) then
    local parts={}
    for i=1,12 do parts[i]=string.format("%04x",math.random(0,65535)) end
    account.linkCode=table.concat(parts)
  end
  return account.linkCode
end

function A:AccountCredentials()
  local guild=self:TrackingGuildKey(); if not guild then return nil end
  self.db.accountCredentialsByGuild=self.db.accountCredentialsByGuild or {}
  local saved=self.db.accountCredentialsByGuild
  saved[guild]=saved[guild] or {}
  return saved[guild]
end

function A:ReceiveAccountHello(sender,id)
  if not self:IsOfficer() or type(id)~="string" or #id<4 or #id>80 or not id:match("^[%w%-]+$") then return false end
  if not self:IsTrackedCharacter(sender) then return false end
  self:SendRaw("O|"..id,"WHISPER",sender)
  return true
end

function A:ReplyToAccountOfficer(sender,id,channel)
  if channel~="WHISPER" or id~=self.db.localAccount.id or not self:IsOfficer(sender) then return false end
  local profile=self:LearnAccountCharacter(); if not profile then return false end
  -- Account codes only travel by whisper to verified guild officers.
  self:SendRaw("K|"..id.."|"..self:LocalLinkCode().."|"..profile.main,"WHISPER",sender)
  if self.SendMyDisplayName then self:SendMyDisplayName(sender) end
  return true
end

function A:ReceivePrivateAccountLink(sender,id,code,main,channel)
  if channel~="WHISPER" or not self:IsOfficer() or not self:ValidLinkCode(code) then return false end
  if not self:ReceiveAccountLink(sender,id,main) then return false end
  local profiles,pending=self:AccountLinkTables()
  local identity=self:GuildIdentity(sender)
  -- ReceiveAccountLink can recognize an existing mapping without queueing it.
  local request=pending[identity]
  if not request then
    request={character=self:IsLocalGuildPlayer(sender) and self:TrackingCharacter("player") or sender,accountID=id,main=main}
    pending[identity]=request
  end
  local credentials=self:AccountCredentials()
  local source=self:TrackingPlayer(request.character)
  local target=profiles[id]
  local bootstrapped=false
  request.linkCode=code
  if target then
    -- Upgrade an existing approved group's credential only from a character
    -- already mapped to that group, never from a new claimed alt.
    if not credentials[id] and source==target and
      (self.db.characterMap[request.character]==target or self:GuildIdentity(target)==identity) then
      credentials[id]=code; bootstrapped=true
    end
    if not credentials[id] or credentials[id]~=code then
      request.credentialConflict=true
      request.reason=credentials[id] and "Code mismatch: recovery review" or "Existing profile: verify ownership"
      if self.RefreshAccountLinks then self:RefreshAccountLinks() end
      return true
    end
    if source==target and (self.db.characterMap[request.character]==target or self:GuildIdentity(target)==identity) then
      pending[identity]=nil
      if bootstrapped then self:MarkChanged() end
      self:SendRaw("V|"..tostring(self.db.version or 0),"WHISPER",sender)
      return true
    end
    for otherID,owner in pairs(profiles) do
      if owner==source and owner~=target and otherID~=id then
        request.credentialConflict=true; request.reason="Character already linked elsewhere"; return true
      end
    end
    local exact=self.db.characterMap[request.character]
    if exact and exact~=target and self:GuildIdentity(exact)~=identity then
      request.credentialConflict=true; request.reason="Existing character link: review"; return true
    end
    if source~=target and (tonumber(self.db.players[source] and self.db.players[source].dkp) or 0)>0 then
      request.reason="Existing DKP: merge review"; return true
    end
  else
    request.main=request.character
    -- A new account registers only the authenticated sender, never the suggested main.
    for _,owner in pairs(profiles) do
      if owner==source then
        request.credentialConflict=true; request.reason="Character already linked: recovery review"; return true
      end
    end
    if self:GuildIdentity(source)~=identity then
      request.credentialConflict=true; request.reason="Existing character link: review"; return true
    end
    request.main=request.character
  end
  request.automatic=true
  if self.db.activeRaid then request.reason="Deferred until raid ends"; return true end
  local ok,err=self:ApproveAccountLink(identity,false)
  if not ok then request.reason=err end
  return true
end

function A:ProcessAutomaticAccountLinks()
  if not self:IsOfficer() or self.db.activeRaid then return end
  local _,pending=self:AccountLinkTables(); local requests={}
  for _,request in pairs(pending or {}) do
    if request.automatic and not request.credentialConflict then requests[#requests+1]=self.DeepCopy(request) end
  end
  for _,request in ipairs(requests) do
    self:ReceivePrivateAccountLink(request.character,request.accountID,request.linkCode,request.main,"WHISPER")
  end
end
