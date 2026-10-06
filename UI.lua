GDKPCredit = GDKPCredit or {}
local A = GDKPCredit

local function fmt(n,dec)
  n=tonumber(n) or 0
  if dec then return string.format("%.2f",n) end
  return tostring(math.floor(n+0.00001))
end

local function skin(frame, r, g, b)
  frame:SetBackdrop({bgFile="Interface/Buttons/WHITE8X8", edgeFile="Interface/Buttons/WHITE8X8",
    edgeSize=1, insets={left=1,right=1,top=1,bottom=1}})
  frame:SetBackdropColor(r or 0.055,g or 0.065,b or 0.085,0.98)
  frame:SetBackdropBorderColor(0.24,0.27,0.32,1)
end

local function makeButton(parent,text,w,h)
  local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
  b:SetSize(w or 100,h or 24)
  local label=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
  label:SetPoint("CENTER"); b:SetFontString(label)
  b:SetNormalFontObject(GameFontNormal)
  b:SetHighlightFontObject(GameFontHighlight)
  b:SetDisabledFontObject(GameFontDisable)
  b:SetText(text)
  skin(b,0.11,0.13,0.17)
  b:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(0.85,0.66,0.30,1) end)
  b:SetScript("OnLeave",function(self) self:SetBackdropBorderColor(0.24,0.27,0.32,1) end)
  return b
end

local function makeText(parent,size)
  local f=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
  if size=="large" then f:SetFontObject(GameFontNormalLarge) end
  f:SetJustifyH("LEFT")
  f:SetTextColor(0.86,0.89,0.94)
  return f
end

local function makeEdit(parent,w,h)
  local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
  e:SetSize(w or 120,h or 24)
  e:SetAutoFocus(false)
  e:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
  e:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
  e:SetTextInsets(6,6,0,0)
  return e
end

function A:CreateExportPopup()
  if self.exportFrame then return self.exportFrame end
  local f=CreateFrame("Frame","GDKPCreditExportFrame",UIParent,"BackdropTemplate")
  f:SetSize(620,380); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
  f:SetBackdrop({bgFile="Interface/Tooltips/UI-Tooltip-Background",edgeFile="Interface/Tooltips/UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
  f:SetBackdropColor(0,0,0,0.95); f:Hide()
  local title=makeText(f,"large"); title:SetPoint("TOPLEFT",16,-14); title:SetText("GDKP Credit Export / Import")
  local close=makeButton(f,"Close",80,24); close:SetPoint("TOPRIGHT",-12,-10); close:SetScript("OnClick",function() f:Hide() end)
  local sf=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate"); sf:SetPoint("TOPLEFT",16,-48); sf:SetPoint("BOTTOMRIGHT",-34,48)
  local edit=CreateFrame("EditBox",nil,sf); edit:SetMultiLine(true); edit:SetFontObject(ChatFontNormal); edit:SetWidth(560); edit:SetAutoFocus(false); edit:SetTextInsets(4,4,4,4); sf:SetScrollChild(edit); f.edit=edit
  local apply=makeButton(f,"Import Snapshot",120,24); apply:SetPoint("BOTTOMLEFT",16,14)
  apply:SetScript("OnClick",function()
    if not A:IsOfficer() then A:Print("Your guild rank does not have addon admin access.") return end
    local ok=A:ApplySnapshot(edit:GetText(),UnitName("player"))
    if ok then A:MarkChanged(); A:Print("Snapshot imported.") else A:Print("Snapshot was not newer or was invalid.") end
  end)
  return f
end

function A:ShowExport(text)
  local f=self:CreateExportPopup(); f.edit:SetText(text or ""); f.edit:HighlightText(); f:Show(); f.edit:SetFocus()
end

function A:InitUI()
  if self.frame then return end
  local f=CreateFrame("Frame","GDKPCreditMainFrame",UIParent,"BackdropTemplate")
  self.frame=f
  f:SetSize(900,650); f:SetPoint("CENTER"); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  f:SetClampedToScreen(true)
  f:SetScript("OnDragStart",f.StartMoving)
  f:SetScript("OnDragStop",function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self:GetPoint()
    A.charDB.window = {point=point,relativePoint=relativePoint,x=x,y=y}
  end)
  local saved = self.charDB.window
  if saved and saved.point and saved.relativePoint then
    f:ClearAllPoints(); f:SetPoint(saved.point,UIParent,saved.relativePoint,saved.x or 0,saved.y or 0)
  end
  UISpecialFrames = UISpecialFrames or {}
  table.insert(UISpecialFrames,"GDKPCreditMainFrame")
  skin(f)
  f:Hide()

  local title=makeText(f,"large"); title:SetPoint("TOPLEFT",22,-18); title:SetText("GDKP CREDIT"); title:SetTextColor(0.93,0.74,0.37)
  local status=makeText(f); status:SetPoint("TOPRIGHT",-58,-22); self.statusText=status
  local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-4,-4)

  f.tabs={}
  for i,name in ipairs(self.TABS) do
    local b=makeButton(f,name,132,28); b:SetPoint("TOPLEFT",20+(i-1)*140,-56)
    b:SetScript("OnClick",function() A:ShowTab(i) end); f.tabs[i]=b
  end

  f.content=CreateFrame("Frame",nil,f); f.content:SetPoint("TOPLEFT",20,-100); f.content:SetPoint("BOTTOMRIGHT",-20,20)
  self:BuildMyTab(); self:BuildGuildTab(); self:BuildRaidTab(); self:BuildHistoryTab(); self:BuildAdminTab(); self:BuildRaidSettingsTab()
  self:ShowTab(1)
end

function A:BuildMyTab()
  local p=CreateFrame("Frame",nil,self.frame.content); p:SetAllPoints(); p:Hide(); self.myPanel=p
  local name=makeText(p,"large"); name:SetPoint("TOPLEFT",8,-8); p.name=name
  local labels={"MAIN CHARACTER","CURRENT DKP","GOLD / DKP","GUILD CREDIT","TREASURY / RESERVE","DATA VERSION"}
  p.lines={}
  for i,label in ipairs(labels) do
    local card=CreateFrame("Frame",nil,p,"BackdropTemplate"); skin(card,0.085,0.10,0.13)
    card:SetSize(268,96); card:SetPoint("TOPLEFT",8+((i-1)%3)*280,-44-math.floor((i-1)/3)*108)
    local title=makeText(card); title:SetPoint("TOPLEFT",14,-14); title:SetText(label); title:SetTextColor(0.59,0.65,0.74)
    local value=makeText(card,"large"); value:SetPoint("TOPLEFT",14,-46); value:SetWidth(242); value:SetWordWrap(false)
    p.lines[i]=value
  end
  local hdr=makeText(p,"large"); hdr:SetPoint("TOPLEFT",8,-288); hdr:SetText("Current Raid")
  local raid=makeText(p); raid:SetPoint("TOPLEFT",8,-326); raid:SetWidth(820); raid:SetJustifyH("LEFT"); p.raid=raid
  local profile=makeButton(p,"My Player Profile",170,28); profile:SetPoint("BOTTOMLEFT",8,12)
  profile:SetScript("OnClick",function() A:ShowMemberProfile() end)
end

function A:BuildGuildTab()
  local p=CreateFrame("Frame",nil,self.frame.content); p:SetAllPoints(); p:Hide(); self.guildPanel=p
  local label=makeText(p); label:SetPoint("TOPLEFT",8,-12); label:SetText("Search player / main / alt")
  p.search=makeEdit(p,240,24); p.search:SetPoint("TOPLEFT",190,-8)
  p.page=1; p.sortKey="name"; p.descending=false
  p.search:SetScript("OnTextChanged",function() p.page=1; A:RefreshGuildTab() end)
  local columns={{"Player","name",0,260},{"Main","main",270,260},{"DKP","dkp",540,110},{"Credit","credit",660,160}}
  p.headers={}
  for _,col in ipairs(columns) do
    local key=col[2]
    local button=makeButton(p,col[1],col[4],26); button:SetPoint("TOPLEFT",8+col[3],-48)
    p.headers[key]={button=button,label=col[1]}
    button:SetScript("OnClick",function()
      if p.sortKey==key then p.descending=not p.descending else p.sortKey=key; p.descending=key=="dkp" or key=="credit" end
      p.page=1; A:RefreshGuildTab()
    end)
  end
  p.rows={}
  for i=1,14 do
    local row=CreateFrame("Button",nil,p,"BackdropTemplate"); row:SetSize(820,28)
    row:SetPoint("TOPLEFT",8,-80-(i-1)*29); skin(row,i%2==0 and 0.085 or 0.065,0.085,0.11)
    row.cells={}
    for j,col in ipairs(columns) do
      local cell=makeText(row); cell:SetPoint("LEFT",col[3]+8,0); cell:SetSize(col[4]-16,28); cell:SetWordWrap(false)
      row.cells[j]=cell
    end
    row:SetScript("OnEnter",function(self)
      if not self.player then return end
      local info=A.db.players[self.player]
      GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(A:PlayerDisplayName(self.player)); GameTooltip:AddLine("Profile: "..self.player,1,1,1)
      GameTooltip:AddLine("Main: "..(info.main or ""),1,1,1)
      GameTooltip:AddLine("Alts: "..table.concat(info.alts or {},", "),1,1,1); GameTooltip:Show()
    end)
    row:SetScript("OnLeave",function() GameTooltip:Hide() end)
    p.rows[i]=row
  end
  p.prev=makeButton(p,"Previous",90,26); p.prev:SetPoint("BOTTOMLEFT",8,8)
  p.next=makeButton(p,"Next",90,26); p.next:SetPoint("LEFT",p.prev,"RIGHT",8,0)
  p.pageText=makeText(p); p.pageText:SetPoint("LEFT",p.next,"RIGHT",16,0)
  p.prev:SetScript("OnClick",function() p.page=p.page-1; A:RefreshGuildTab() end)
  p.next:SetScript("OnClick",function() p.page=p.page+1; A:RefreshGuildTab() end)
end

function A:BuildRaidTab()
  local p=CreateFrame("Frame",nil,self.frame.content); p:SetAllPoints(); p:Hide(); self.raidPanel=p
  local state=makeText(p,"large"); state:SetPoint("TOPLEFT",8,-6); p.state=state
  local summary=makeText(p); summary:SetPoint("TOPLEFT",8,-34); p.summary=summary
  local start=makeButton(p,"Start Raid",90,24); start:SetPoint("TOPLEFT",8,-62); start:SetScript("OnClick",function() A:ShowStartRaidDialog() end)
  local check=makeButton(p,"WB + Consume Check",150,24); check:SetPoint("LEFT",start,"RIGHT",8,0); check:SetScript("OnClick",function() A:RunReadinessCheck() end)
  local lock=makeButton(p,"Lock Check",90,24); lock:SetPoint("LEFT",check,"RIGHT",8,0); lock:SetScript("OnClick",function() if A.db.activeRaid and A.db.activeRaid.locked then A:UnlockRaidCheck() else A:LockRaidCheck() end end); p.lock=lock
  local export=makeButton(p,"Export Raid",90,24); export:SetPoint("LEFT",lock,"RIGHT",8,0); export:SetScript("OnClick",function() A:ShowExport(A:RaidExportText()) end)

  local potLabel=makeText(p); potLabel:SetPoint("TOPLEFT",8,-102); potLabel:SetText("Gross GDKP Pot:")
  local pot=makeEdit(p,110,24); pot:SetPoint("LEFT",potLabel,"RIGHT",10,0); pot:SetNumeric(true); p.pot=pot
  local finish=makeButton(p,"End Raid + Award DKP",160,24); finish:SetPoint("LEFT",pot,"RIGHT",10,0); finish:SetScript("OnClick",function() A:ShowAwardPreview(pot:GetText()) end)

  p.controls={start,check,lock,finish}
  p.selectionControls={}
  local searchLabel=makeText(p); searchLabel:SetPoint("TOPLEFT",8,-141); searchLabel:SetText("Search raider")
  p.search=makeEdit(p,220,24); p.search:SetPoint("TOPLEFT",114,-132)
  p.search:SetScript("OnTextChanged",function() p.page=1; A:RefreshRaidTab() end)
  local filter=makeButton(p,"Show: all raiders",180,24); filter:SetPoint("LEFT",p.search,"RIGHT",12,0); p.filter=filter
  filter:SetScript("OnClick",function() p.missingOnly=not p.missingOnly; p.page=1; A:RefreshRaidTab() end)
  -- Ten rows plus navigation and officer controls fit inside the larger window.
  local columns={{"Player",0,200},{"Character",204,200},{"Att",408,54},{"WB",466,80},{"Cons",550,90},{"DKP+",644,46}}
  for _,col in ipairs(columns) do
    local hdr=makeText(p); hdr:SetPoint("TOPLEFT",8+col[2],-172); hdr:SetWidth(col[3]); hdr:SetText(col[1])
  end
  p.rows={}; p.page=1
  for i=1,10 do
    local row=CreateFrame("Button",nil,p); row:SetSize(690,23); row:SetPoint("TOPLEFT",8,-196-(i-1)*24)
    row.cells={}
    for j,col in ipairs(columns) do
      local txt=makeText(row); txt:SetPoint("LEFT",col[2],0); txt:SetSize(col[3],23)
      txt:SetWordWrap(false); row.cells[j]=txt
    end
    row:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight")
    p.rows[i]=row
    row:SetScript("OnClick",function(self)
      if not self.player then return end
      p.selected=self.player
      A:RefreshRaidTab()
    end)
    row:SetScript("OnEnter",function(self)
      if not self.player then return end
      GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
      GameTooltip:SetText(A:PlayerDisplayName(self.player)); GameTooltip:AddLine("Profile: "..self.player,1,1,1)
      GameTooltip:AddLine(self.character or "",1,1,1)
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave",function() GameTooltip:Hide() end)
  end
  local prev=makeButton(p,"Prev",70,22); prev:SetPoint("BOTTOMLEFT",8,64); p.prev=prev
  local nextb=makeButton(p,"Next",70,22); nextb:SetPoint("LEFT",prev,"RIGHT",6,0); p.next=nextb
  local pageText=makeText(p); pageText:SetPoint("LEFT",nextb,"RIGHT",12,0); p.pageText=pageText
  prev:SetScript("OnClick",function() p.page=p.page-1; A:RefreshRaidTab() end)
  nextb:SetScript("OnClick",function() p.page=p.page+1; A:RefreshRaidTab() end)
  local selected=makeText(p); selected:SetPoint("BOTTOMLEFT",8,42); selected:SetWidth(690); selected:SetWordWrap(false); selected:SetText("Selected: none"); p.selectedText=selected
  local wb=makeButton(p,"Pass WB",80,22); wb:SetPoint("BOTTOMLEFT",8,10); wb:SetScript("OnClick",function() if p.selected then A:SetRaidPass(p.selected,"wb") end end)
  local con=makeButton(p,"Pass Consumes",110,22); con:SetPoint("LEFT",wb,"RIGHT",6,0); con:SetScript("OnClick",function() if p.selected then A:SetRaidPass(p.selected,"consumes") end end)
  local att=makeButton(p,"Pass Attendance",120,22); att:SetPoint("LEFT",con,"RIGHT",6,0); att:SetScript("OnClick",function() if p.selected then A:SetRaidPass(p.selected,"attendance") end end)
  local recheck=makeButton(p,"Recheck Selected",120,22); recheck:SetPoint("LEFT",att,"RIGHT",6,0); recheck:SetScript("OnClick",function() if p.selected then A:RunReadinessCheck(p.selected) end end)
  p.selectionControls={wb,con,att,recheck}
end

function A:BuildHistoryTab()
  local p=CreateFrame("Frame",nil,self.frame.content); p:SetAllPoints(); p:Hide(); self.historyPanel=p
  local hdr=makeText(p,"large"); hdr:SetPoint("TOPLEFT",8,-8); hdr:SetText("DKP Activity")
  local label=makeText(p); label:SetPoint("TOPLEFT",8,-48); label:SetText("Search player / action / note")
  p.search=makeEdit(p,250,24); p.search:SetPoint("TOPLEFT",215,-40); p.page=1
  p.search:SetScript("OnTextChanged",function() p.page=1; A:RefreshHistoryTab() end)
  local columns={{"Time",0,125},{"Action",130,110},{"Player",245,165},{"DKP",415,75},{"Note",495,325}}
  for _,col in ipairs(columns) do
    local title=makeText(p); title:SetPoint("TOPLEFT",8+col[2],-82); title:SetText(col[1]); title:SetTextColor(0.93,0.74,0.37)
  end
  p.rows={}
  for i=1,13 do
    local row=CreateFrame("Frame",nil,p,"BackdropTemplate"); row:SetSize(820,28); row:SetPoint("TOPLEFT",8,-106-(i-1)*29)
    skin(row,i%2==0 and 0.085 or 0.065,0.085,0.11); row:EnableMouse(true); row.cells={}
    for j,col in ipairs(columns) do
      local cell=makeText(row); cell:SetPoint("LEFT",col[2],0); cell:SetSize(col[3],28); cell:SetWordWrap(false); row.cells[j]=cell
    end
    row:SetScript("OnEnter",function(self)
      if not self.entry then return end
      GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(self.entry.kind or "Activity")
      GameTooltip:AddLine(self.entry.note or "",1,1,1,true); GameTooltip:Show()
    end)
    row:SetScript("OnLeave",function() GameTooltip:Hide() end)
    p.rows[i]=row
  end
  p.prev=makeButton(p,"Previous",90,26); p.prev:SetPoint("BOTTOMLEFT",8,8)
  p.next=makeButton(p,"Next",90,26); p.next:SetPoint("LEFT",p.prev,"RIGHT",8,0)
  p.pageText=makeText(p); p.pageText:SetPoint("LEFT",p.next,"RIGHT",16,0)
  p.prev:SetScript("OnClick",function() p.page=p.page-1; A:RefreshHistoryTab() end)
  p.next:SetScript("OnClick",function() p.page=p.page+1; A:RefreshHistoryTab() end)
end

function A:BuildAdminTab()
  local p=CreateFrame("Frame",nil,self.frame.content); p:SetAllPoints(); p:Hide(); self.adminPanel=p
  local title=makeText(p,"large"); title:SetPoint("TOPLEFT",8,-8); title:SetText("Manage Your Guild")

  local tLab=makeText(p); tLab:SetPoint("TOPLEFT",8,-48); tLab:SetText("Guild gold (g)")
  local treasury=makeEdit(p,100,24); treasury:SetPoint("LEFT",tLab,"RIGHT",18,0); treasury:SetNumeric(true); p.treasury=treasury
  local rLab=makeText(p); rLab:SetPoint("LEFT",treasury,"RIGHT",24,0); rLab:SetText("Gold held back (g)")
  local reserve=makeEdit(p,100,24); reserve:SetPoint("LEFT",rLab,"RIGHT",18,0); reserve:SetNumeric(true); p.reserve=reserve
  local save=makeButton(p,"Save Gold",100,24); save:SetPoint("LEFT",reserve,"RIGHT",12,0)
  save:SetScript("OnClick",function()
    if not A:IsOfficer() then A:Print("Your guild rank does not have addon admin access.") return end
    A.db.treasury=tonumber(treasury:GetText()) or A.db.treasury
    A.db.reserve=tonumber(reserve:GetText()) or A.db.reserve
    A:AddHistory("TREASURY","",0,"Treasury/reserve updated")
    A:MarkChanged()
  end)

  local goldHelp=makeText(p); goldHelp:SetPoint("TOPLEFT",8,-76); goldHelp:SetWidth(810)
  goldHelp:SetText("Enter total guild gold and the amount held back. The remaining gold determines the value of each DKP.")

  local adjTitle=makeText(p,"large"); adjTitle:SetPoint("TOPLEFT",8,-100); adjTitle:SetText("Add or Remove DKP")
  local playerLabel=makeText(p); playerLabel:SetPoint("TOPLEFT",8,-127); playerLabel:SetText("Player key (see Guild tooltip)")
  local amountLabel=makeText(p); amountLabel:SetPoint("TOPLEFT",198,-127); amountLabel:SetText("DKP change")
  local reasonLabel=makeText(p); reasonLabel:SetPoint("TOPLEFT",298,-127); reasonLabel:SetText("Reason (shown in history)")
  local player=makeEdit(p,180,24); player:SetPoint("TOPLEFT",8,-147); p.adjustPlayer=player
  local delta=makeEdit(p,90,24); delta:SetPoint("LEFT",player,"RIGHT",10,0); p.adjustDelta=delta
  local note=makeEdit(p,250,24); note:SetPoint("LEFT",delta,"RIGHT",10,0); p.adjustNote=note
  local apply=makeButton(p,"Apply Change",120,24); apply:SetPoint("LEFT",note,"RIGHT",10,0)
  apply:SetScript("OnClick",function()
    local ok,err=A:AdjustDKP(player:GetText(),delta:GetText(),note:GetText())
    if not ok then A:Print(err) end
  end)

  local adjustHelp=makeText(p); adjustHelp:SetPoint("TOPLEFT",8,-176); adjustHelp:SetWidth(810)
  adjustHelp:SetText("Use 10 to add DKP or -10 to remove it. Use the player key shown in the Guild row tooltip, not their display name.")

  local aliasTitle=makeText(p,"large"); aliasTitle:SetPoint("TOPLEFT",8,-210); aliasTitle:SetText("Manual Character Link (Advanced)")
  local charLabel=makeText(p); charLabel:SetPoint("TOPLEFT",8,-237); charLabel:SetText("Character to link")
  local ownerLabel=makeText(p); ownerLabel:SetPoint("TOPLEFT",198,-237); ownerLabel:SetText("Existing player key")
  local char=makeEdit(p,180,24); char:SetPoint("TOPLEFT",8,-257); p.aliasChar=char
  local owner=makeEdit(p,180,24); owner:SetPoint("LEFT",char,"RIGHT",10,0); p.aliasOwner=owner
  local map=makeButton(p,"Link Character",130,24); map:SetPoint("LEFT",owner,"RIGHT",10,0)
  map:SetScript("OnClick",function()
    if not A:IsOfficer() then A:Print("Your guild rank does not have addon admin access.") return end
    local c=A:ShortName(char:GetText()); local o=owner:GetText()
    if c=="" or o=="" then return end
    A.db.characterMap[c]=o; A:EnsurePlayer(o,c); A:AddHistory("MAP",o,0,c.." mapped to "..o); A:MarkChanged()
  end)

  local linkHelp=makeText(p); linkHelp:SetPoint("TOPLEFT",8,-286); linkHelp:SetWidth(810)
  linkHelp:SetText("Characters normally link automatically. This manual tool redirects future tracking; it does not merge existing balances.")

  local dataTitle=makeText(p,"large"); dataTitle:SetPoint("TOPLEFT",8,-320); dataTitle:SetText("Backup & Sharing")
  local snap=makeButton(p,"Copy Guild Backup",155,24); snap:SetPoint("TOPLEFT",8,-349); snap:SetScript("OnClick",function() A:ShowExport(A:SerializeSnapshot()) end)
  local raid=makeButton(p,"Copy Last Raid",140,24); raid:SetPoint("LEFT",snap,"RIGHT",10,0); raid:SetScript("OnClick",function() A:ShowExport(A:RaidExportText(A.db.raids[1])) end)
  local sync=makeButton(p,"Notify Members to Sync",185,24); sync:SetPoint("LEFT",raid,"RIGHT",10,0); sync:SetScript("OnClick",function() A:BroadcastVersion() end)

  local info=makeText(p); info:SetPoint("TOPLEFT",8,-381); info:SetWidth(810); info:SetText("Backups open text you can copy and save. Sync tells online members that newer guild data is available.")
  local memberTitle=makeText(p,"large"); memberTitle:SetPoint("TOPLEFT",8,-413)
  memberTitle:SetText("Members & Guild Rules")
  local manage=makeButton(p,"Non-Guild Members",180,30); manage:SetPoint("TOPLEFT",8,-442)
  manage:SetScript("OnClick",function() A:ShowAdditionalMembers() end)
  p.memberCount=makeText(p); p.memberCount:SetPoint("TOPLEFT",8,-480)
  local access=makeButton(p,"Who Can Manage DKP",205,28); access:SetPoint("TOPLEFT",625,-442)
  access:SetScript("OnClick",function() A:ShowAdminPermissions() end)
  p.adminAccess=access
  local decay=makeButton(p,"Inactivity Decay",160,30); decay:SetPoint("TOPLEFT",445,-442)
  decay:SetScript("OnClick",function() A:ShowDecaySettings() end)
  local accounts=makeButton(p,"Review Character Links",220,30); accounts:SetPoint("TOPLEFT",205,-442)
  accounts:SetScript("OnClick",function() A:ShowAccountLinks() end)
  p.adminControls={save,apply,map,manage,decay,accounts,sync}
  local memberHelp=makeText(p); memberHelp:SetPoint("TOPLEFT",8,-498); memberHelp:SetWidth(810)
  memberHelp:SetText("Add guests, resolve character links, or set inactivity deductions. Who Can Manage DKP is visible only to the Guild Master. Raid award amounts are on the Raid Settings tab.")

end

function A:ShowTab(i)
  self.currentTab=i or 1
  if (self.currentTab==5 and not (self:HasAdminRank() or self:IsAdmin())) or
    (self.currentTab==6 and not self:CanEditRaidSettings()) then self.currentTab=1 end
  if self.startRaidFrame then self.startRaidFrame.picker:Hide() end
  local panels={self.myPanel,self.guildPanel,self.raidPanel,self.historyPanel,self.adminPanel,self.raidSettingsPanel}
  for n,p in ipairs(panels) do if n==self.currentTab then p:Show() else p:Hide() end end
  if self.frame and self.frame.tabs then
    for n,b in ipairs(self.frame.tabs) do b:SetEnabled(n~=self.currentTab) end
    self.frame.tabs[5]:SetShown(self:HasAdminRank() or self:IsAdmin())
    self.frame.tabs[6]:SetShown(self:CanEditRaidSettings())
  end
  self:RefreshUI()
end

function A:RefreshMyTab()
  local p=self.myPanel; if not p then return end
  local player=self:GetMyPlayer(); local info=self.db.players[player]
  p.name:SetText(self:PlayerDisplayName(player))
  local dkp=info and (info.dkp or 0) or 0
  p.lines[1]:SetText(info and (info.main or "") or self:ShortName(UnitName("player")))
  p.lines[2]:SetText(fmt(dkp))
  p.lines[3]:SetText(fmt(self:GoldPerDKP(),true).."g")
  p.lines[4]:SetText(fmt(self:GuildCredit(player)).."g")
  p.lines[5]:SetText(fmt(self.db.treasury).."g / "..fmt(self.db.reserve).."g")
  p.lines[6]:SetText("Data v"..tostring(self.db.version or 0))
  local r=self.db.activeRaid
  if r and r.players[player] then
    local e=r.players[player]
    p.raid:SetText((r.name or "Raid").."\nAttendance: "..(e.attendanceOverride and "PASS" or (e.attendanceBroken and "NO" or "TRACKING")).."   World Buffs: "..(e.wb and "PASS" or "NO").." ("..(e.wbCount or 0)..")   Consumes: "..(e.consumes and "PASS" or "NO").." ("..(e.consumeCount or 0)..")")
  elseif r then p.raid:SetText((r.name or "Raid").." — you are not currently tracked in this raid.")
  else p.raid:SetText("No active raid.") end
end

function A:RefreshGuildTab()
  local p=self.guildPanel; if not p then return end
  local names=self:GuildView(p.search:GetText(),p.sortKey,p.descending)
  local pages=math.max(1,math.ceil(#names/#p.rows)); p.page=math.max(1,math.min(p.page or 1,pages))
  p.prev:SetEnabled(p.page>1); p.next:SetEnabled(p.page<pages)
  p.pageText:SetText(string.format("Page %d / %d  |  %d players",p.page,pages,#names))
  for key,header in pairs(p.headers) do
    header.button:SetText(header.label..(p.sortKey==key and (p.descending and "  v" or "  ^") or ""))
  end
  for i,row in ipairs(p.rows) do
    local n=names[(p.page-1)*#p.rows+i]; row.player=n; row:SetShown(n~=nil)
    if n then
      local info=self.db.players[n]
      local values={self:PlayerDisplayName(n),info.main or "",fmt(info.dkp),fmt(self:GuildCredit(n)).."g"}
      for j,cell in ipairs(row.cells) do cell:SetText(values[j]) end
    end
  end
end

function A:RefreshRaidTab()
  local p=self.raidPanel; if not p then return end
  local r=self.db.activeRaid
  p.state:SetText(r and ((r.name or "Raid")..(r.locked and " — CHECK LOCKED" or " — ACTIVE")) or "No active raid")
  p.lock:SetText(r and r.locked and "Unlock Check" or "Lock Check")
  local names,summary=self:RaidView(p.search:GetText(),p.missingOnly)
  local awardPreview=r and self:RaidAwardPreview(0)
  p.summary:SetText(string.format("%d raiders  |  WB %d/%d  |  Consumes %d/%d  |  Attendance eligible %d/%d",
    summary.total,summary.wb,summary.total,summary.consumes,summary.total,summary.attendance,summary.total))
  p.filter:SetText(p.missingOnly and "Show: missing readiness" or "Show: all raiders")
  local officer=self:IsOfficer()
  p.controls[1]:SetEnabled(officer and not r)
  p.controls[2]:SetEnabled(officer and r~=nil and not r.locked)
  p.controls[3]:SetEnabled(officer and r~=nil)
  p.controls[4]:SetEnabled(officer and r~=nil)
  local raidID=r and r.id
  if p.raidID~=raidID then p.page=1; p.selected=nil; p.raidID=raidID end
  if p.selected and (not r or not r.players or not r.players[p.selected]) then p.selected=nil end
  local pages=math.max(1,math.ceil(#names/#p.rows))
  p.page=math.max(1,math.min(p.page or 1,pages))
  local first=(p.page-1)*#p.rows+1
  p.prev:SetEnabled(p.page>1); p.next:SetEnabled(p.page<pages)
  p.pageText:SetText(string.format("Page %d / %d — %d raiders",p.page,pages,#names))
  for i,row in ipairs(p.rows) do
    local n=names[first+i-1]
    row.player=n; row.character=n and r.players[n].char or nil
    row:SetEnabled(n~=nil); row:SetShown(n~=nil)
    if n then
      local e=r.players[n]
      local att=e.attendanceOverride and "YES" or (e.attendanceBroken and "NO" or "...")
      local wb=e.wb and "YES" or "NO"
      local con=e.consumes and "YES" or "NO"
      local d=awardPreview and awardPreview.players[n] and awardPreview.players[n].actual or 0
      local values={self:PlayerDisplayName(n),e.char or "",att,wb.."("..(e.wbCount or 0)..")",con.."("..(e.consumeCount or 0)..")",tostring(d)}
      for j,cell in ipairs(row.cells) do
        cell:SetText(values[j])
        if p.selected==n then cell:SetTextColor(1,0.82,0.42)
        elseif j>=3 and j<=5 then
          local pass=(j==3 and e.attendanceOverride) or (j==4 and e.wb) or (j==5 and e.consumes)
          if pass then cell:SetTextColor(0.38,0.86,0.61) else cell:SetTextColor(0.88,0.61,0.40) end
        else cell:SetTextColor(0.86,0.89,0.94) end
      end
    else
      for _,cell in ipairs(row.cells) do cell:SetText("") end
    end
  end
  if p.selected and r and not self:IsTrackedCharacter(r.players[p.selected].char) then p.selected=nil end
  p.selectedText:SetText("Selected: "..(p.selected and self:PlayerDisplayName(p.selected) or "none"))
  for i,button in ipairs(p.selectionControls) do
    button:SetEnabled(officer and p.selected~=nil and r~=nil and (i~=4 or not r.locked))
  end
end

function A:RefreshHistoryTab()
  local p=self.historyPanel; if not p then return end
  local history=self:HistoryView(p.search:GetText())
  local pages=math.max(1,math.ceil(#history/#p.rows)); p.page=math.max(1,math.min(p.page or 1,pages))
  p.prev:SetEnabled(p.page>1); p.next:SetEnabled(p.page<pages)
  p.pageText:SetText(string.format("Page %d / %d  |  %d entries",p.page,pages,#history))
  for i,row in ipairs(p.rows) do
    local h=history[(p.page-1)*#p.rows+i]; row.entry=h; row:SetShown(h~=nil)
    if h then
      local amount=tonumber(h.amount) or 0
      local values={date("%m/%d %H:%M",h.ts or time()),h.kind or "",self:PlayerDisplayName(h.player),
        amount~=0 and ((amount>0 and "+" or "")..fmt(amount)) or "",h.note or ""}
      for j,cell in ipairs(row.cells) do cell:SetText(values[j]) end
      row.cells[4]:SetTextColor(amount<0 and 0.95 or 0.38,amount<0 and 0.48 or 0.86,0.61)
    end
  end
end

function A:RefreshAdminTab()
  local p=self.adminPanel; if not p then return end
  for _,control in ipairs(p.adminControls or {}) do control:SetEnabled(self:IsOfficer()) end
  if not p.treasury:HasFocus() then p.treasury:SetText(fmt(self.db.treasury)) end
  if not p.reserve:HasFocus() then p.reserve:SetText(fmt(self.db.reserve)) end
  if p.memberCount then p.memberCount:SetText(#self:TrackingExceptions().." additional members") end

end

function A:RefreshUI()
  if not self.frame then return end
  if self.statusText then self.statusText:SetText(string.format("%s  |  %.2fg / DKP",self:IsOfficer() and "GUILD ADMIN" or "MEMBER",self:GoldPerDKP())) end
  if self.adminPanel.adminAccess then self.adminPanel.adminAccess:SetShown(self:IsAdmin()) end
  self:RefreshMyTab(); self:RefreshGuildTab(); self:RefreshRaidTab(); self:RefreshHistoryTab(); self:RefreshAdminTab()
  if self.memberProfileFrame and self.memberProfileFrame:IsShown() then self:RefreshMemberProfile() end
  if self.accountFrame and self.accountFrame:IsShown() then self:RefreshAccountLinks() end
  if self.membersFrame and self.membersFrame:IsShown() then self:RefreshAdditionalMembers() end
  if self.raidSettingsPanel then self.raidSettingsPanel.save:SetEnabled(self:CanEditRaidSettings()) end
  if self.frame.tabs then self.frame.tabs[6]:SetShown(self:CanEditRaidSettings()) end
  if self.startRaidFrame and self.startRaidFrame:IsShown() then self:RefreshStartRaidDialog() end
end

function A:ToggleUI()
  if not self.frame then self:InitUI() end
  if self.frame:IsShown() then self.frame:Hide() else self.frame:Show(); self:RefreshUI() end
end

function A:ShowAwardPreview(grossPot)
  if not self:IsOfficer() then self:Print("Your guild rank does not have addon admin access.") return end
  if self.ApplyDKPDecay then self:ApplyDKPDecay() end
  local preview,err=self:RaidAwardPreview(grossPot)
  if not preview then self:Print(err) return end
  if not self.awardFrame then
    local f=CreateFrame("Frame","GDKPCreditAwardFrame",UIParent,"BackdropTemplate")
    f:SetSize(500,280); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); skin(f)
    f:EnableMouse(true); self.awardFrame=f
    table.insert(UISpecialFrames,"GDKPCreditAwardFrame")
    local title=makeText(f,"large"); title:SetPoint("TOPLEFT",20,-20); title:SetText("Review raid awards")
    f.text=makeText(f); f.text:SetPoint("TOPLEFT",20,-60); f.text:SetWidth(460)
    local cancel=makeButton(f,"Cancel",100,28); cancel:SetPoint("BOTTOMLEFT",20,20)
    cancel:SetScript("OnClick",function() f:Hide() end)
    local confirm=makeButton(f,"Confirm & End Raid",170,28); confirm:SetPoint("BOTTOMRIGHT",-20,20)
    confirm:SetScript("OnClick",function()
      if A.ApplyDKPDecay then A:ApplyDKPDecay() end
      if not A.db.activeRaid or A.db.activeRaid.id~=f.raidID or A.db.version~=f.version then
        f:Hide(); A:Print("Raid data changed. Review the awards again before confirming.") return
      end
      local current=A:RaidAwardPreview(f.grossPot)
      local changed=not current or current.total~=f.preview.total or current.guildCut~=f.preview.guildCut
      if current then
        for name,award in pairs(current.players) do
          local prior=f.preview.players[name]
          if not prior or prior.actual~=award.actual or prior.attendance~=award.attendance or prior.after~=award.after then changed=true end
        end
        for name in pairs(f.preview.players) do if not current.players[name] then changed=true end end
      end
      if changed then
        f:Hide(); A:Print("Roster or awards changed. Review the awards again before confirming.") return
      end
      f:Hide(); A:EndRaid(f.grossPot)
    end)
  end
  local f=self.awardFrame
  f.preview=preview
  f.raidID=preview.id; f.version=self.db.version; f.grossPot=preview.grossPot
  f.text:SetText(tostring(preview.name).."\n\nGross pot: "..fmt(preview.grossPot).."g"..
    "\nGuild treasury receives: "..fmt(preview.guildCut).."g"..
    "\nDKP added after caps: "..fmt(preview.total).."\nPlayers limited by cap: "..preview.capped..
    "\n\nThis ends the raid and records the awards.")
  f:Show()
end

function A:CreateRaidPicker(parent,onSelect)
  local picker=CreateFrame("Frame",nil,parent,"BackdropTemplate")
  picker:SetSize(290,36+#self.CLASSIC_RAIDS*32); picker:SetPoint("TOPLEFT",parent,"BOTTOMLEFT",0,-4)
  picker:SetFrameStrata("DIALOG"); picker:EnableMouse(true); skin(picker); picker:Hide()
  picker.buttons={}
  for i,raid in ipairs(self.CLASSIC_RAIDS) do
    local raidID=raid.id
    local button=makeButton(picker,raid.name.."  ("..raid.size..")",274,28)
    button:SetPoint("TOPLEFT",8,-8-(i-1)*32)
    picker.buttons[i]=button
    button:SetScript("OnClick",function() picker:Hide(); onSelect(raidID) end)
  end
  parent:SetScript("OnClick",function() picker:SetShown(not picker:IsShown()) end)
  return picker
end

function A:ShowStartRaidDialog()
  if not self:IsOfficer() then self:Print("Your guild rank does not have addon admin access.") return end
  if self.db.activeRaid then self:Print("A raid is already active.") return end
  if not self.startRaidFrame then
    local f=CreateFrame("Frame","GDKPCreditStartRaidFrame",UIParent,"BackdropTemplate")
    f:SetSize(500,350); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true); skin(f)
    self.startRaidFrame=f; table.insert(UISpecialFrames,"GDKPCreditStartRaidFrame")
    local title=makeText(f,"large"); title:SetPoint("TOPLEFT",20,-20); title:SetText("Choose your Classic raid")
    f.selector=makeButton(f,"Choose raid...",290,30); f.selector:SetPoint("TOPLEFT",20,-62)
    f.rulesText=makeText(f); f.rulesText:SetPoint("TOPLEFT",20,-115); f.rulesText:SetWidth(460)
    f.picker=self:CreateRaidPicker(f.selector,function(id)
      f.selectedRaid=id; A.charDB.lastRaidType=id; A:RefreshStartRaidDialog()
    end)
    local cancel=makeButton(f,"Cancel",100,28); cancel:SetPoint("BOTTOMLEFT",20,20)
    cancel:SetScript("OnClick",function() f:Hide(); f.picker:Hide() end)
    f.start=makeButton(f,"Start Raid",130,28); f.start:SetPoint("BOTTOMRIGHT",-20,20)
    f.start:SetScript("OnClick",function()
      local ok,err=A:StartRaid(f.selectedRaid)
      if ok then f:Hide(); f.picker:Hide() elseif err then A:Print(err) end
    end)
    f:SetScript("OnHide",function() f.picker:Hide() end)
  end
  local f=self.startRaidFrame
  f.selectedRaid=self:ClassicRaid(self.charDB.lastRaidType) and self.charDB.lastRaidType or nil
  self:RefreshStartRaidDialog(); f:Show()
end

function A:RefreshStartRaidDialog()
  local f=self.startRaidFrame; if not f then return end
  local raid=self:ClassicRaid(f.selectedRaid)
  local rules=raid and self:GetRaidProfile(raid.id)
  f.selector:SetText(raid and raid.name or "Choose raid...")
  f.start:SetEnabled(raid~=nil and self:IsOfficer() and not self.db.activeRaid)
  if not rules then f.rulesText:SetText("Select a raid to see its award settings.") return end
  f.rulesText:SetText("Attendance: "..rules.attendanceDKP.." DKP"..
    "\nWorld buffs: "..rules.wbDKP.." DKP ("..rules.wbThreshold.." required)"..
    "\nConsumes: "..rules.consumeDKP.." DKP ("..rules.consumeThreshold.." required)"..
    "\nDKP cap: "..rules.dkpCap.."  |  Guild cut: "..fmt(rules.guildCut*100,true).."%"..
    "\n\nThese settings are locked in when the raid starts.")
end

function A:BuildRaidSettingsTab()
  local p=CreateFrame("Frame",nil,self.frame.content); p:SetAllPoints(); p:Hide(); self.raidSettingsPanel=p
  local title=makeText(p,"large"); title:SetPoint("TOPLEFT",8,-8); title:SetText("Raid Award Settings")
  local help=makeText(p); help:SetPoint("TOPLEFT",8,-38); help:SetWidth(820)
  help:SetText("Set the awards for each Classic raid. Changes apply to future raids; active raids keep their starting rules.")
  p.selectedRaid=self.CLASSIC_RAIDS[1].id
  p.selector=makeButton(p,"",290,30); p.selector:SetPoint("TOPLEFT",8,-74)
  p.picker=self:CreateRaidPicker(p.selector,function(id)
    p.selectedRaid=id; A:LoadRaidSettingsForm()
  end)
  p.fields={}
  local fields={{"attendanceDKP","Full attendance DKP"},{"wbDKP","World buff award DKP"},
    {"consumeDKP","Consume award DKP"},{"wbThreshold","World buffs required"},
    {"consumeThreshold","Consumes required"},{"dkpCap","DKP balance cap"},{"guildCut","Guild cut (%)"}}
  for i,field in ipairs(fields) do
    local label=makeText(p); label:SetPoint("TOPLEFT",8,-126-(i-1)*40); label:SetText(field[2])
    local input=makeEdit(p,120,26); input:SetPoint("TOPLEFT",260,-118-(i-1)*40); p.fields[field[1]]=input
  end
  p.message=makeText(p); p.message:SetPoint("TOPLEFT",420,-126); p.message:SetWidth(395)
  local hint=makeText(p); hint:SetPoint("TOPLEFT",420,-222); hint:SetWidth(395)
  hint:SetText("Awards and thresholds use whole numbers. Set an award to 0 to disable it. Guild cut accepts decimals from 0 to 100.\n\nSettings are included in officer snapshots so the raid team shares the same profiles.")
  p.save=makeButton(p,"Save Raid Settings",170,30); p.save:SetPoint("BOTTOMLEFT",8,22)
  p.save:SetScript("OnClick",function()
    local values={}
    for key,input in pairs(p.fields) do values[key]=input:GetText() end
    values.guildCut=tonumber(values.guildCut) and tonumber(values.guildCut)/100 or nil
    local ok,err=A:SaveRaidProfile(p.selectedRaid,values)
    p.message:SetText(ok and "Saved. Future raids will use these awards." or err)
    if ok then A:LoadRaidSettingsForm(true) end
  end)
  local reset=makeButton(p,"Load Default Values",170,30); reset:SetPoint("LEFT",p.save,"RIGHT",10,0)
  reset:SetScript("OnClick",function()
    A:LoadRaidSettingsForm(false,A:DefaultRaidRules())
    p.message:SetText("Default values loaded. Click Save to apply them to this raid.")
  end)
  p:SetScript("OnHide",function() p.picker:Hide() end)
  p:SetScript("OnShow",function() A:LoadRaidSettingsForm() end)
  self:LoadRaidSettingsForm()
end

function A:LoadRaidSettingsForm(keepMessage,rules)
  local p=self.raidSettingsPanel; if not p then return end
  local raid=self:ClassicRaid(p.selectedRaid); if not raid then return end
  p.selector:SetText(raid.name.." ("..raid.size.." players)")
  rules=rules or self:GetRaidProfile(p.selectedRaid)
  for key,input in pairs(p.fields) do
    input:SetText(tostring(key=="guildCut" and rules[key]*100 or rules[key]))
  end
  if not keepMessage then p.message:SetText("") end
end

function A:ShowAdditionalMembers()
  if not self:IsOfficer() then self:Print("Your guild rank does not have addon admin access.") return end
  if not self.membersFrame then
    local f=CreateFrame("Frame","GDKPCreditMembersFrame",UIParent,"BackdropTemplate")
    f:SetSize(680,540); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true); skin(f)
    self.membersFrame=f; table.insert(UISpecialFrames,"GDKPCreditMembersFrame")
    local title=makeText(f,"large"); title:SetPoint("TOPLEFT",20,-20); title:SetText("Additional Members")
    local help=makeText(f); help:SetPoint("TOPLEFT",20,-54); help:SetWidth(640)
    help:SetText("Allow non-guild characters to earn raid awards. This list belongs to your guild and grants no officer permissions.")
    f.input=makeEdit(f,360,26); f.input:SetPoint("TOPLEFT",20,-94)
    local add=makeButton(f,"Add Member",130,28); add:SetPoint("LEFT",f.input,"RIGHT",12,0); f.add=add
    f.message=makeText(f); f.message:SetPoint("TOPLEFT",20,-130); f.message:SetWidth(640)
    local label=makeText(f); label:SetPoint("TOPLEFT",20,-167); label:SetText("Search")
    f.search=makeEdit(f,280,24); f.search:SetPoint("TOPLEFT",82,-158); f.page=1
    f.search:SetScript("OnTextChanged",function() f.page=1; A:RefreshAdditionalMembers() end)
    add:SetScript("OnClick",function()
      local ok,err=A:AddAdditionalMember(f.input:GetText())
      if ok then
        f.input:SetText(""); f.search:SetText(""); f.message:SetText("Member added. Enter Character or Character-Realm to add another.")
      else f.message:SetText(err) end
      A:RefreshAdditionalMembers()
    end)
    f.rows={}
    for i=1,10 do
      local row=CreateFrame("Frame",nil,f,"BackdropTemplate"); row:SetSize(640,27)
      row:SetPoint("TOPLEFT",20,-196-(i-1)*28); skin(row,0.085,0.10,0.13)
      row.name=makeText(row); row.name:SetPoint("LEFT",10,0); row.name:SetWidth(510); row.name:SetWordWrap(false)
      row.remove=makeButton(row,"Remove",90,23); row.remove:SetPoint("RIGHT",-6,0)
      row.remove:SetScript("OnClick",function()
        if not row.character then return end
        local name=row.character
        local ok,err=A:RemoveAdditionalMember(name)
        f.message:SetText(ok and ("Removed "..name.." from additional members.") or err)
        A:RefreshAdditionalMembers()
      end)
      f.rows[i]=row
    end
    f.prev=makeButton(f,"Previous",90,26); f.prev:SetPoint("BOTTOMLEFT",20,20)
    f.next=makeButton(f,"Next",90,26); f.next:SetPoint("LEFT",f.prev,"RIGHT",8,0)
    f.pageText=makeText(f); f.pageText:SetPoint("LEFT",f.next,"RIGHT",16,0)
    f.prev:SetScript("OnClick",function() f.page=f.page-1; A:RefreshAdditionalMembers() end)
    f.next:SetScript("OnClick",function() f.page=f.page+1; A:RefreshAdditionalMembers() end)
    local close=makeButton(f,"Close",90,26); close:SetPoint("BOTTOMRIGHT",-20,20)
    close:SetScript("OnClick",function() f:Hide() end)
  end
  self:RefreshAdditionalMembers(); self.membersFrame:Show()
end

function A:RefreshAdditionalMembers()
  local f=self.membersFrame; if not f then return end
  local names=self:AdditionalMembersView(f.search:GetText())
  local pages=math.max(1,math.ceil(#names/#f.rows)); f.page=math.max(1,math.min(f.page or 1,pages))
  local officer=self:IsOfficer()
  f.add:SetEnabled(officer); f.prev:SetEnabled(f.page>1); f.next:SetEnabled(f.page<pages)
  f.pageText:SetText(string.format("Page %d / %d | %d members",f.page,pages,#names))
  for i,row in ipairs(f.rows) do
    local name=names[(f.page-1)*#f.rows+i]; row.character=name; row:SetShown(name~=nil)
    if name then row.name:SetText(name); row.remove:SetEnabled(officer) end
  end
  if self.adminPanel and self.adminPanel.memberCount then
    self.adminPanel.memberCount:SetText(#self:TrackingExceptions().." additional members")
  end
end

function A:ShowAccountLinks()
  if not self:IsOfficer() then self:Print("Your guild rank does not have addon admin access.") return end
  if not self.accountFrame then
    local f=CreateFrame("Frame","GDKPCreditAccountFrame",UIParent,"BackdropTemplate")
    f:SetSize(860,520); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true); skin(f)
    self.accountFrame=f; table.insert(UISpecialFrames,"GDKPCreditAccountFrame")
    local title=makeText(f,"large"); title:SetPoint("TOPLEFT",20,-20); title:SetText("Review Character Links")
    local help=makeText(f); help:SetPoint("TOPLEFT",20,-54); help:SetWidth(820)
    help:SetText("Matching-code accounts link automatically. Review only conflicts, recovery requests, or existing DKP merges.")
    local bulk=makeButton(f,"Approve New Accounts",190,28); bulk:SetPoint("TOPLEFT",20,-94)
    bulk:SetScript("OnClick",function() local _,msg=A:ApproveNewAccounts(); f.message:SetText(msg); A:RefreshAccountLinks() end)
    local import=makeButton(f,"Import Guild Roster",170,28); import:SetPoint("LEFT",bulk,"RIGHT",12,0)
    import:SetScript("OnClick",function() local _,msg=A:ImportGuildPlayers(); f.message:SetText(msg) end)
    f.message=makeText(f); f.message:SetPoint("TOPLEFT",20,-132); f.message:SetWidth(820)
    f.rows={}; f.page=1
    for i=1,9 do
      local row=CreateFrame("Frame",nil,f,"BackdropTemplate"); row:SetSize(820,30); row:SetPoint("TOPLEFT",20,-174-(i-1)*32); skin(row,0.085,0.10,0.13)
      row.text=makeText(row); row.text:SetPoint("LEFT",8,0); row.text:SetWidth(510); row.text:SetWordWrap(false)
      row.approve=makeButton(row,"Approve",90,25); row.approve:SetPoint("RIGHT",-172,0)
      row.merge=makeButton(row,"Review / Resolve",150,25); row.merge:SetPoint("RIGHT",-8,0)
      row.approve:SetScript("OnClick",function()
        local _,msg=A:ApproveAccountLink(row.identity,false); f.message:SetText(msg or "Character linked."); A:RefreshAccountLinks()
      end)
      row.merge:SetScript("OnClick",function()
        A:ShowAccountMergeReview(row.identity)
      end)
      f.rows[i]=row
    end
    f.prev=makeButton(f,"Previous",90,26); f.prev:SetPoint("BOTTOMLEFT",20,20)
    f.next=makeButton(f,"Next",90,26); f.next:SetPoint("LEFT",f.prev,"RIGHT",8,0)
    f.pageText=makeText(f); f.pageText:SetPoint("LEFT",f.next,"RIGHT",16,0)
    f.prev:SetScript("OnClick",function() f.page=f.page-1; A:RefreshAccountLinks() end)
    f.next:SetScript("OnClick",function() f.page=f.page+1; A:RefreshAccountLinks() end)
    local close=makeButton(f,"Close",90,26); close:SetPoint("BOTTOMRIGHT",-20,20); close:SetScript("OnClick",function() f:Hide() end)
  end
  self:RefreshAccountLinks(); self.accountFrame:Show()
end

function A:RefreshAccountLinks()
  local f=self.accountFrame; if not f then return end
  local rows=self:AccountLinkView(); local pages=math.max(1,math.ceil(#rows/#f.rows))
  f.page=math.max(1,math.min(f.page or 1,pages)); f.prev:SetEnabled(f.page>1); f.next:SetEnabled(f.page<pages)
  f.pageText:SetText(string.format("Page %d / %d | %d requests",f.page,pages,#rows))
  for i,row in ipairs(f.rows) do
    local entry=rows[(f.page-1)*#f.rows+i]; row:SetShown(entry~=nil)
    if entry then
      row.identity=entry.identity
      local target,status,_,balance=self:AccountLinkStatus(entry.request)
      row.text:SetText(entry.request.character.." -> "..tostring(target or entry.request.main).." | "..status.." | "..balance.." DKP")
      row.approve:SetEnabled(self:IsOfficer() and target~=nil); row.merge:SetEnabled(self:IsOfficer() and target~=nil and (balance>0 or entry.request.credentialConflict))
    end
  end
end

function A:ShowAccountMergeReview(identity)
  local _,pending=self:AccountLinkTables(); local request=pending and pending[identity]; if not request then return end
  local target,_,_,balance=self:AccountLinkStatus(request); if not target then return end
  if not self.linkReviewFrame then
    local f=CreateFrame("Frame","GDKPCreditLinkReviewFrame",UIParent,"BackdropTemplate")
    f:SetSize(540,270); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG"); skin(f); f:EnableMouse(true)
    self.linkReviewFrame=f; table.insert(UISpecialFrames,"GDKPCreditLinkReviewFrame")
    f.text=makeText(f); f.text:SetPoint("TOPLEFT",20,-20); f.text:SetWidth(500)
    local cancel=makeButton(f,"Cancel",100,28); cancel:SetPoint("BOTTOMLEFT",20,20); cancel:SetScript("OnClick",function() f:Hide() end)
    local approve=makeButton(f,"Confirm Ownership & Merge",230,28); approve:SetPoint("BOTTOMRIGHT",-20,20)
    approve:SetScript("OnClick",function()
      f:Hide()
      if f.version~=A.db.version then A:Print("Data changed. Review the request again.") return end
      local _,msg=A:ApproveAccountLink(f.identity,true); A:Print(msg or "Character linked and balance merged."); A:RefreshAccountLinks()
    end)
  end
  local f=self.linkReviewFrame; f.identity=identity; f.version=self.db.version
  local existing=tonumber(self.db.players[target] and self.db.players[target].dkp) or 0
  f.text:SetText("Confirm that "..request.character.." belongs to "..target..".\n\nCharacter DKP: "..balance.."\nTarget DKP: "..existing.."\nCombined DKP: "..(existing+(self:TrackingPlayer(request.character)~=target and balance or 0)).."\n\nConfirm ownership before resolving this request. This may merge player records and replace the private linking code.")
  f:Show()
end

function A:ShowMemberProfile()
  if not self.memberProfileFrame then
    local f=CreateFrame("Frame","GDKPCreditMemberProfileFrame",UIParent,"BackdropTemplate")
    f:SetSize(720,620); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true); skin(f)
    self.memberProfileFrame=f; table.insert(UISpecialFrames,"GDKPCreditMemberProfileFrame")
    local title=makeText(f,"large"); title:SetPoint("TOPLEFT",20,-20); title:SetText("My Player Profile")
    local help=makeText(f); help:SetPoint("TOPLEFT",20,-54); help:SetWidth(680)
    help:SetText("Log onto each character to discover and link it automatically. Choose your preferred main here. Only conflicts and existing balance merges need officer review.")
    f.summary=makeText(f); f.summary:SetPoint("TOPLEFT",20,-100); f.summary:SetWidth(680)
    local automatic=makeText(f); automatic:SetPoint("TOPLEFT",20,-134); automatic:SetWidth(680)
    automatic:SetText("Linking and DKP synchronization run automatically when an officer is online.")
    local label=makeText(f); label:SetPoint("TOPLEFT",20,-181); label:SetText("Player display name")
    f.displayName=makeEdit(f,280,28); f.displayName:SetPoint("TOPLEFT",175,-170)
    f.saveName=makeButton(f,"Save Name",120,28); f.saveName:SetPoint("LEFT",f.displayName,"RIGHT",12,0)
    f.saveName:SetScript("OnClick",function()
      local _,msg=A:SetMyDisplayName(f.displayName:GetText()); f.message:SetText(msg)
    end)
    f.message=makeText(f); f.message:SetPoint("TOPLEFT",20,-220); f.message:SetWidth(680)
    f.page=1; f.rows={}
    for i=1,8 do
      local row=CreateFrame("Frame",nil,f,"BackdropTemplate"); row:SetSize(680,30); row:SetPoint("TOPLEFT",20,-300-(i-1)*32); skin(row,0.085,0.10,0.13)
      row.name=makeText(row); row.name:SetPoint("LEFT",8,0); row.name:SetWidth(265); row.name:SetWordWrap(false)
      row.status=makeText(row); row.status:SetPoint("LEFT",280,0); row.status:SetWidth(245); row.status:SetWordWrap(false)
      row.choose=makeButton(row,"Set as Main",130,26); row.choose:SetPoint("RIGHT",-8,0)
      row.choose:SetScript("OnClick",function()
        local _,msg=A:SetMyPreferredMain(row.character); f.message:SetText(msg); A:RefreshMemberProfile()
      end)
      f.rows[i]=row
    end
    f.prev=makeButton(f,"Previous",90,26); f.prev:SetPoint("BOTTOMLEFT",20,20)
    f.next=makeButton(f,"Next",90,26); f.next:SetPoint("LEFT",f.prev,"RIGHT",8,0)
    f.pageText=makeText(f); f.pageText:SetPoint("LEFT",f.next,"RIGHT",16,0)
    f.prev:SetScript("OnClick",function() f.page=f.page-1; A:RefreshMemberProfile() end)
    f.next:SetScript("OnClick",function() f.page=f.page+1; A:RefreshMemberProfile() end)
    local close=makeButton(f,"Close",90,26); close:SetPoint("BOTTOMRIGHT",-20,20); close:SetScript("OnClick",function() f:Hide() end)
  end
  self:RefreshMemberProfile(); self.memberProfileFrame:Show()
end

function A:RefreshMemberProfile()
  local f=self.memberProfileFrame; if not f then return end
  local rows,main,target=self:MemberProfileView()
  local localProfile=self:LearnAccountCharacter()
  f.saveName:SetEnabled(localProfile~=nil)
  if not f.displayName:HasFocus() then
    f.displayName:SetText(localProfile and localProfile.displayName or (target and self.db.players[target] and self.db.players[target].displayName) or "")
  end
  f.summary:SetText("Preferred main: "..tostring(main or "No guild").." | Shared DKP profile: "..tostring(target and self:PlayerDisplayName(target) or "Waiting for synchronization"))
  local pages=math.max(1,math.ceil(#rows/#f.rows)); f.page=math.max(1,math.min(f.page or 1,pages))
  f.prev:SetEnabled(f.page>1); f.next:SetEnabled(f.page<pages)
  f.pageText:SetText(string.format("Page %d / %d | %d characters",f.page,pages,#rows))
  for i,row in ipairs(f.rows) do
    local entry=rows[(f.page-1)*#f.rows+i]; row:SetShown(entry~=nil)
    if entry then
      row.character=entry.name; row.name:SetText(entry.name..(entry.main and " (main)" or "")); row.status:SetText(entry.status)
      row.choose:SetEnabled(not entry.main); row.status:SetTextColor(entry.status=="Linked" and 0.38 or 0.93,0.78,0.50)
    end
  end
end

function A:ShowDecaySettings()
  if not self:IsOfficer() then self:Print("Your guild rank does not have addon admin access.") return end
  if not self.decayFrame then
    local f=CreateFrame("Frame","GDKPCreditDecayFrame",UIParent,"BackdropTemplate")
    f:SetSize(620,400); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true); skin(f)
    self.decayFrame=f; table.insert(UISpecialFrames,"GDKPCreditDecayFrame")
    local title=makeText(f,"large"); title:SetPoint("TOPLEFT",20,-20); title:SetText("DKP Deductions for Inactive Players")
    f.toggle=makeButton(f,"",180,28); f.toggle:SetPoint("TOPLEFT",20,-66)
    f.toggle:SetScript("OnClick",function() f.enabled=not f.enabled; f.toggle:SetText(f.enabled and "Decay: Enabled" or "Decay: Disabled") end)
    f.fields={}
    local fields={{"inactivityDays","Days without gaining DKP"},{"intervalDays","Days between deductions"},{"amount","DKP deducted each period"}}
    for i,field in ipairs(fields) do
      local label=makeText(f); label:SetPoint("TOPLEFT",20,-121-(i-1)*38); label:SetText(field[2])
      local input=makeEdit(f,110,28); input:SetPoint("TOPLEFT",285,-110-(i-1)*38); f.fields[field[1]]=input
    end
    local help=makeText(f); help:SetPoint("TOPLEFT",20,-232); help:SetWidth(580)
    help:SetText("The first deduction occurs at the inactivity limit, then repeats at the interval. Gains on any linked character reset the clock. Balances stop at zero. Missed periods catch up when an officer is online. Saving changed rules starts a fresh inactivity period.")
    f.message=makeText(f); f.message:SetPoint("TOPLEFT",20,-304); f.message:SetWidth(580)
    f.save=makeButton(f,"Save Decay Settings",180,28); f.save:SetPoint("BOTTOMLEFT",20,20)
    f.save:SetScript("OnClick",function()
      local values={enabled=f.enabled}; for key,input in pairs(f.fields) do values[key]=input:GetText() end
      local _,msg=A:SaveDecaySettings(values); f.message:SetText(msg)
    end)
    local close=makeButton(f,"Close",90,28); close:SetPoint("BOTTOMRIGHT",-20,20); close:SetScript("OnClick",function() f:Hide() end)
  end
  local f=self.decayFrame; local settings=self:DecaySettings()
  f.enabled=settings.enabled; f.toggle:SetText(f.enabled and "Decay: Enabled" or "Decay: Disabled")
  for key,input in pairs(f.fields) do input:SetText(tostring(settings[key])) end
  f.message:SetText(""); f:Show()
end

function A:ShowAdminPermissions()
  if not self:IsAdmin() then self:Print("Only the Guild Master can change admin access.") return end
  if not self.permissionsFrame then
    local f=CreateFrame("Frame","GDKPCreditPermissionsFrame",UIParent,"BackdropTemplate")
    self.permissionsFrame=f; table.insert(UISpecialFrames,"GDKPCreditPermissionsFrame")
    f:SetSize(620,620); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true); skin(f)
    local title=makeText(f,"large"); title:SetPoint("TOPLEFT",20,-20); title:SetText("Guild Admin Permissions")
    f.modes={}
    for i,item in ipairs({{"officer","Blizzard officers"},{"kick","Can remove guild members"},{"ranks","Choose ranks below"}}) do
      local b=makeButton(f,item[2],185,30); b:SetPoint("TOPLEFT",20+(i-1)*195,-60)
      b:SetScript("OnClick",function() f.mode=item[1]; A:RefreshAdminPermissions() end)
      f.modes[item[1]]=b
    end
    f.rows={}
    for i=1,10 do
      local b=makeButton(f,"",580,28); b:SetPoint("TOPLEFT",20,-108-(i-1)*34)
      b:SetScript("OnClick",function() if b.rank then f.mode="ranks"; f.selected[b.rank]=not f.selected[b.rank]; A:RefreshAdminPermissions() end end)
      f.rows[i]=b
    end
    local help=makeText(f); help:SetPoint("TOPLEFT",20,-458); help:SetWidth(580)
    help:SetText("By default, ranks that can remove guild members get admin access. To grant or revoke access, choose ranks below and toggle them. All enabled ranks can edit settings and run raids. The Guild Master always retains access and alone controls these permissions.")
    f.message=makeText(f); f.message:SetPoint("TOPLEFT",20,-535)
    local save=makeButton(f,"Save Permissions",180,30); save:SetPoint("BOTTOMLEFT",20,20)
    save:SetScript("OnClick",function() local _,msg=A:SaveAdminPolicy(f.mode,f.selected); f.message:SetText(msg) end)
    local close=makeButton(f,"Close",90,30); close:SetPoint("BOTTOMRIGHT",-20,20); close:SetScript("OnClick",function() f:Hide() end)
  end
  local p=self:PermissionPolicy(); local f=self.permissionsFrame
  f.mode=p.mode; f.selected=self.DeepCopy(p.ranks); f.message:SetText("")
  if p.mode~="ranks" then
    for idx=0,9 do
      local name=self:GuildRankName(idx)
      if name then
        local allowed=idx==0
        local api=C_GuildInfo and C_GuildInfo.GuildControlGetRankFlags
        if api then
          local ok,flags=pcall(api,idx+1)
          if ok and type(flags)=="table" then
            if p.mode=="kick" then allowed=allowed or flags[8]==true
            else allowed=allowed or flags[3]==true or flags[4]==true or flags[11]==true or flags[12]==true end
          end
        end
        f.selected[name]=allowed
      end
    end
  end
  self:RefreshAdminPermissions(); f:Show()
end
function A:RefreshAdminPermissions()
  local f=self.permissionsFrame; local ranks=self:AvailableAdminRanks()
  for mode,b in pairs(f.modes) do b:SetEnabled(mode~=f.mode) end
  for i,b in ipairs(f.rows) do
    b.rank=ranks[i]; b:SetShown(b.rank~=nil); b:SetEnabled(true)
    if b.rank then b:SetText((f.selected[b.rank] and "[Enabled] " or "[Disabled] ")..b.rank) end
  end
end
