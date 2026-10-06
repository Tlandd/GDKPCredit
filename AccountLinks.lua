GDKPCredit = GDKPCredit or {}
local A = GDKPCredit

local function validID(id)
  return type(id)=="string" and #id>=4 and #id<=80 and id:match("^[%w%-]+$")~=nil
end

function A:InitAccountLinks()
  self.db.localAccount = self.db.localAccount or {guilds={}}
  local account = self.db.localAccount
  account.guilds = account.guilds or {}
  if not validID(account.id) then
    account.id = tostring(UnitGUID and UnitGUID("player") or "Player").."-"..
      tostring((GetServerTime and GetServerTime()) or time()).."-"..tostring(math.random(100000,999999))
  end
  self.db.accountProfilesByGuild = self.db.accountProfilesByGuild or {}
  self.db.pendingAccountLinksByGuild = self.db.pendingAccountLinksByGuild or {}
end

function A:AccountLinkTables()
  local guild=self:TrackingGuildKey()
  if not guild then return nil end
  self:InitAccountLinks()
  local profiles=self.db.accountProfilesByGuild
  local pending=self.db.pendingAccountLinksByGuild
  profiles[guild]=profiles[guild] or {}; pending[guild]=pending[guild] or {}
  return profiles[guild],pending[guild]
end

function A:AnnounceAccountCharacter()
  return self:SubmitMyCharacter()
end

function A:ReceiveAccountLink(sender,id,main)
  if not self:IsOfficer() or not validID(id) then return false end
  if type(main)~="string" or #main>100 or not self:GuildIdentity(main) then return false end
  if not self:IsTrackedCharacter(sender) then return false end
  local profiles,pending=self:AccountLinkTables(); if not profiles then return false end
  local character=sender
  if self:IsLocalGuildPlayer(sender) then character=self:TrackingCharacter("player") end
  local identity=self:GuildIdentity(sender)
  local target=profiles[id]
  if target and self.db.characterMap[character]==target then pending[identity]=nil; return true end
  pending[identity]={character=character,accountID=id,main=main}
  if self.RefreshAccountLinks then self:RefreshAccountLinks() end
  return true
end

function A:AccountLinkStatus(request)
  local profiles=self:AccountLinkTables()
  if not profiles then return nil,"Guild unavailable" end
  local target=profiles[request.accountID]
  local source=self:TrackingPlayer(request.character)
  local balance=tonumber(self.db.players[source] and self.db.players[source].dkp) or 0
  if target then return target,request.reason or "Review alt link",false,balance end
  if self:GuildIdentity(request.main)~=self:GuildIdentity(request.character) then
    return nil,"Waiting for first character",false,balance
  end
  for _,owner in pairs(profiles) do
    if owner==source then return source,"Existing profile: review",false,balance end
  end
  return source,balance>0 and "Existing balance: review" or "New account",balance==0,balance
end

function A:ApproveAccountLink(identity, merge)
  if not self:IsOfficer() then return false,"Your guild rank does not have addon admin access." end
  if self.db.activeRaid then return false,"Finish the active raid before linking characters." end
  local profiles,pending=self:AccountLinkTables()
  local request=pending and pending[identity]
  if not request then return false,"Request is no longer pending." end
  if not self:IsTrackedCharacter(request.character) then return false,"Character is no longer eligible." end
  local target,_,_,balance=self:AccountLinkStatus(request)
  if not target then return false,"The first character must be approved first." end
  local source=self:TrackingPlayer(request.character)
  if request.credentialConflict and not merge then
    return false,"Confirm ownership using Review / Resolve before repairing this account link."
  end
  if source~=target and balance>0 and not merge then
    return false,"This character has "..balance.." DKP. Use Review & Merge after checking ownership."
  end
  local before=tonumber(self.db.players[target] and self.db.players[target].dkp) or 0
  local combined=before+(source~=target and balance or 0)
  if source~=target and combined>(tonumber(self.db.settings.dkpCap) or 200) then
    return false,"Combined balance exceeds the DKP cap. Adjust the balances before merging."
  end
  local player=self:EnsurePlayer(target)
  if source~=target and self.db.players[source] then
    local old=self.db.players[source]
    player.gainTimes=player.gainTimes or {}
    for guild,stamp in pairs(old.gainTimes or {}) do
      if stamp>(player.gainTimes[guild] or 0) then
        player.gainTimes[guild]=stamp
        if player.decayProgress then player.decayProgress[guild]=nil end
      end
    end
    for char,owner in pairs(self.db.characterMap) do if owner==source then self.db.characterMap[char]=target end end
    for _,alt in ipairs(old.alts or {}) do self.db.characterMap[alt]=target end
    if old.main then self.db.characterMap[old.main]=target end
    player.alts=player.alts or {}
    local all={}; if old.main then all[#all+1]=old.main end
    for _,alt in ipairs(old.alts or {}) do all[#all+1]=alt end
    for _,char in ipairs(all) do
      local found=player.main==char
      for _,alt in ipairs(player.alts) do if alt==char then found=true end end
      if not found then player.alts[#player.alts+1]=char end
    end
    for accountID,owner in pairs(profiles) do if owner==source then profiles[accountID]=target end end
    self.db.players[source]=nil
  end
  player.dkp=combined
  self.db.characterMap[request.character]=target
  local found=player.main==request.character
  for _,alt in ipairs(player.alts or {}) do if alt==request.character then found=true end end
  if not found then player.alts=player.alts or {}; player.alts[#player.alts+1]=request.character end
  profiles[request.accountID]=target
  if request.linkCode and self:ValidLinkCode(request.linkCode) then
    self:AccountCredentials()[request.accountID]=request.linkCode
  end
  pending[identity]=nil
  self:AddHistory("ACCOUNT",target,0,"Linked "..request.character..(merge and " (balance reviewed)" or ""))
  self:MarkChanged()
  return true
end

function A:ApproveNewAccounts()
  if not self:IsOfficer() then return false,"Your guild rank does not have addon admin access." end
  if self.db.activeRaid then return false,"Finish the active raid before linking characters." end
  local _,pending=self:AccountLinkTables(); if not pending then return false,"Guild unavailable." end
  local identities={}; for identity in pairs(pending) do identities[#identities+1]=identity end
  table.sort(identities)
  local approved=0
  for _,identity in ipairs(identities) do
    local request=pending[identity]
    if request then
      local _,_,safe=self:AccountLinkStatus(request)
      if safe and self:ApproveAccountLink(identity,false) then approved=approved+1 end
    end
  end
  return true,"Approved "..approved.." new accounts. Alt links and balances remain for review."
end

function A:ImportGuildPlayers()
  if not self:IsOfficer() then return false,"Your guild rank does not have addon admin access." end
  if self.db.activeRaid then return false,"Finish the active raid before importing." end
  local _,ready=self:GuildTrackingRoster(); if not ready then return false,"Guild roster is loading." end
  local added=0
  for i=1,GetNumGuildMembers() do
    local character=GetGuildRosterInfo(i)
    if character then
      local player=self:TrackingPlayer(character)
      if not self.db.players[player] then self:EnsurePlayer(player,character); added=added+1 end
    end
  end
  self:AddHistory("IMPORT","",0,"Imported "..added.." guild characters with zero DKP")
  self:MarkChanged()
  return true,"Imported "..added.." characters. Existing balances and links were preserved."
end

function A:AccountLinkView()
  local _,pending=self:AccountLinkTables(); local rows={}
  for identity,request in pairs(pending or {}) do rows[#rows+1]={identity=identity,request=request} end
  table.sort(rows,function(a,b) return a.identity<b.identity end)
  return rows
end

function A:LearnAccountCharacter()
  self:InitAccountLinks()
  local guild=self:TrackingGuildKey(); local name=self:TrackingCharacter("player")
  if not guild or not name then return nil end
  local saved=self.db.localAccount.guilds
  saved[guild]=saved[guild] or {main=name}
  local profile=saved[guild]
  profile.characters=profile.characters or {}
  -- The previous chosen main was learned on this account before this upgrade.
  local mainID=self:GuildIdentity(profile.main)
  if mainID and not profile.characters[mainID] then profile.characters[mainID]={name=profile.main} end
  local identity=self:GuildIdentity(name)
  if not identity then return nil end
  profile.characters[identity]=profile.characters[identity] or {name=name}
  profile.characters[identity].name=name
  return profile,name,identity
end

function A:SetMyPreferredMain(name)
  local profile=self:LearnAccountCharacter()
  if not profile then return false,"Join a guild to set up your profile." end
  local identity=self:GuildIdentity(name)
  local known=identity and profile.characters[identity]
  if not known then return false,"Log onto that character first so this account can discover it." end
  profile.main=known.name
  if self.RefreshMemberProfile then self:RefreshMemberProfile() end
  return true,"Preferred main saved. Log onto your alts to link them automatically. Existing linked balances stay unchanged."
end

function A:SubmitMyCharacter()
  if not IsInGuild() then return false,"Join a guild before submitting a linking request." end
  local profile,name,identity=self:LearnAccountCharacter()
  if not profile then return false,"Character or guild information is unavailable." end
  if not self.SendRaw then return false,"Addon messaging is unavailable." end
  self:LocalLinkCode()
  self:SendRaw("H|"..self.db.localAccount.id,"GUILD")
  profile.characters[identity].submitted=(GetServerTime and GetServerTime()) or time()
  if self.RefreshMemberProfile then self:RefreshMemberProfile() end
  return true,"Request sent for "..name..". An officer must be online. New accounts and matching-code alts link automatically; conflicts require review."
end

function A:MemberProfileView()
  local profile=self:LearnAccountCharacter()
  if not profile then return {},nil,nil end
  local profiles=self:AccountLinkTables()
  local target=profiles and profiles[self.db.localAccount.id]
  local rows={}
  for identity,character in pairs(profile.characters) do
    local approved=target~=nil and self:TrackingPlayer(character.name)==target
    rows[#rows+1]={identity=identity,name=character.name,
      main=identity==self:GuildIdentity(profile.main),
      status=approved and "Linked" or (character.submitted and "Waiting for sync / review" or "Not submitted")}
  end
  table.sort(rows,function(a,b) if a.main~=b.main then return a.main end return a.identity<b.identity end)
  return rows,profile.main,target
end
