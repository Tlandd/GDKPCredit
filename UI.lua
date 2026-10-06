GDKPCredit = GDKPCredit or {}
local A = GDKPCredit

local function fmt(n,dec)
  n=tonumber(n) or 0
  if dec then return string.format("%.2f",n) end
  return tostring(math.floor(n+0.00001))
end

local function makeButton(parent,text,w,h)
  local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
  b:SetSize(w or 100,h or 24)
  b:SetText(text)
  return b
end

local function makeText(parent,size)
  local f=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
  if size=="large" then f:SetFontObject(GameFontNormalLarge) end
  f:SetJustifyH("LEFT")
  return f
end

local function makeEdit(parent,w,h)
  local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
  e:SetSize(w or 120,h or 24)
  e:SetAutoFocus(false)
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
    if not A:IsOfficer() then A:Print("Officer permission required.") return end
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
  f:SetSize(760,540); f:SetPoint("CENTER"); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart",f.StartMoving); f:SetScript("OnDragStop",f.StopMovingOrSizing)
  f:SetBackdrop({bgFile="Interface/DialogFrame/UI-DialogBox-Background",edgeFile="Interface/DialogFrame/UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
  f:Hide()

  local title=makeText(f,"large"); title:SetPoint("TOPLEFT",22,-18); title:SetText("GDKP Credit")
  local status=makeText(f); status:SetPoint("TOPRIGHT",-58,-22); self.statusText=status
  local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-4,-4)

  f.tabs={}
  for i,name in ipairs(self.TABS) do
    local b=makeButton(f,name,112,24); b:SetPoint("TOPLEFT",20+(i-1)*116,-52)
    b:SetScript("OnClick",function() A:ShowTab(i) end); f.tabs[i]=b
  end

  f.content=CreateFrame("Frame",nil,f); f.content:SetPoint("TOPLEFT",20,-86); f.content:SetPoint("BOTTOMRIGHT",-20,20)
  self:BuildMyTab(); self:BuildGuildTab(); self:BuildRaidTab(); self:BuildHistoryTab(); self:BuildAdminTab()
  self:ShowTab(1)
end

function A:BuildMyTab()
  local p=CreateFrame("Frame",nil,self.frame.content); p:SetAllPoints(); p:Hide(); self.myPanel=p
  local name=makeText(p,"large"); name:SetPoint("TOPLEFT",12,-8); p.name=name
  local lines={}
  local labels={"Main Character","Current DKP","Gold / DKP","Guild Credit","Treasury / Reserve","Last Sync"}
  for i,l in ipairs(labels) do
    local a=makeText(p); a:SetPoint("TOPLEFT",20,-52-(i-1)*32); a:SetText(l)
    local v=makeText(p,"large"); v:SetPoint("TOPLEFT",220,-49-(i-1)*32); lines[i]=v
  end
  p.lines=lines
  local hdr=makeText(p,"large"); hdr:SetPoint("TOPLEFT",12,-270); hdr:SetText("Current Raid")
  local raid=makeText(p); raid:SetPoint("TOPLEFT",20,-306); raid:SetWidth(650); raid:SetJustifyH("LEFT"); p.raid=raid
  local sync=makeButton(p,"Sync Now",100,24); sync:SetPoint("BOTTOMLEFT",12,12); sync:SetScript("OnClick",function() A:RequestSync() end)
end

function A:BuildGuildTab()
  local p=CreateFrame("Frame",nil,self.frame.content); p:SetAllPoints(); p:Hide(); self.guildPanel=p
  local hdr=makeText(p); hdr:SetPoint("TOPLEFT",8,-8); hdr:SetText("Player                         Main                         DKP      Credit")
  p.rows={}
  for i=1,18 do
    local row=makeText(p); row:SetPoint("TOPLEFT",8,-34-(i-1)*23); row:SetWidth(680); row:SetText(""); p.rows[i]=row
  end
  local prev=makeButton(p,"Prev",70,22); prev:SetPoint("BOTTOMLEFT",8,8)
  local nextb=makeButton(p,"Next",70,22); nextb:SetPoint("BOTTOMLEFT",84,8)
  p.page=1
  prev:SetScript("OnClick",function() p.page=math.max(1,(p.page or 1)-1); A:RefreshGuildTab() end)
  nextb:SetScript("OnClick",function() p.page=(p.page or 1)+1; A:RefreshGuildTab() end)
end

function A:BuildRaidTab()
  local p=CreateFrame("Frame",nil,self.frame.content); p:SetAllPoints(); p:Hide(); self.raidPanel=p
  local state=makeText(p,"large"); state:SetPoint("TOPLEFT",8,-6); p.state=state
  local start=makeButton(p,"Start Raid",90,24); start:SetPoint("TOPLEFT",8,-38); start:SetScript("OnClick",function() A:StartRaid() end)
  local check=makeButton(p,"WB + Consume Check",150,24); check:SetPoint("LEFT",start,"RIGHT",8,0); check:SetScript("OnClick",function() A:RunReadinessCheck() end)
  local lock=makeButton(p,"Lock Check",90,24); lock:SetPoint("LEFT",check,"RIGHT",8,0); lock:SetScript("OnClick",function() if A.db.activeRaid and A.db.activeRaid.locked then A:UnlockRaidCheck() else A:LockRaidCheck() end end); p.lock=lock
  local export=makeButton(p,"Export Raid",90,24); export:SetPoint("LEFT",lock,"RIGHT",8,0); export:SetScript("OnClick",function() A:ShowExport(A:RaidExportText()) end)

  local potLabel=makeText(p); potLabel:SetPoint("TOPLEFT",8,-76); potLabel:SetText("Gross GDKP Pot:")
  local pot=makeEdit(p,110,24); pot:SetPoint("LEFT",potLabel,"RIGHT",10,0); pot:SetNumeric(true); p.pot=pot
  local finish=makeButton(p,"End Raid + Award DKP",160,24); finish:SetPoint("LEFT",pot,"RIGHT",10,0); finish:SetScript("OnClick",function() A:EndRaid(pot:GetText()) end)

  local hdr=makeText(p); hdr:SetPoint("TOPLEFT",8,-112); hdr:SetText("Player                 Character              Att   WB     Cons   DKP")
  p.rows={}
  for i=1,13 do
    local row=CreateFrame("Button",nil,p); row:SetSize(690,23); row:SetPoint("TOPLEFT",8,-136-(i-1)*25)
    local txt=makeText(row); txt:SetAllPoints(); row.text=txt; p.rows[i]=row
    row:SetScript("OnClick",function(self)
      p.selected=self.player
      A:RefreshRaidTab()
    end)
  end
  local selected=makeText(p); selected:SetPoint("BOTTOMLEFT",8,42); selected:SetText("Selected: none"); p.selectedText=selected
  local wb=makeButton(p,"Pass WB",80,22); wb:SetPoint("BOTTOMLEFT",8,10); wb:SetScript("OnClick",function() if p.selected then A:SetRaidPass(p.selected,"wb") end end)
  local con=makeButton(p,"Pass Consumes",110,22); con:SetPoint("LEFT",wb,"RIGHT",6,0); con:SetScript("OnClick",function() if p.selected then A:SetRaidPass(p.selected,"consumes") end end)
  local att=makeButton(p,"Pass Attendance",120,22); att:SetPoint("LEFT",con,"RIGHT",6,0); att:SetScript("OnClick",function() if p.selected then A:SetRaidPass(p.selected,"attendance") end end)
  local recheck=makeButton(p,"Recheck Selected",120,22); recheck:SetPoint("LEFT",att,"RIGHT",6,0); recheck:SetScript("OnClick",function() if p.selected then A:RunReadinessCheck(p.selected) end end)
end

function A:BuildHistoryTab()
  local p=CreateFrame("Frame",nil,self.frame.content); p:SetAllPoints(); p:Hide(); self.historyPanel=p
  local hdr=makeText(p,"large"); hdr:SetPoint("TOPLEFT",8,-8); hdr:SetText("Recent DKP Activity")
  p.rows={}
  for i=1,17 do local row=makeText(p); row:SetPoint("TOPLEFT",8,-42-(i-1)*24); row:SetWidth(680); p.rows[i]=row end
end

function A:BuildAdminTab()
  local p=CreateFrame("Frame",nil,self.frame.content); p:SetAllPoints(); p:Hide(); self.adminPanel=p
  local title=makeText(p,"large"); title:SetPoint("TOPLEFT",8,-8); title:SetText("Officer / Admin Controls")

  local tLab=makeText(p); tLab:SetPoint("TOPLEFT",8,-48); tLab:SetText("Treasury")
  local treasury=makeEdit(p,100,24); treasury:SetPoint("LEFT",tLab,"RIGHT",18,0); treasury:SetNumeric(true); p.treasury=treasury
  local rLab=makeText(p); rLab:SetPoint("LEFT",treasury,"RIGHT",24,0); rLab:SetText("Reserve")
  local reserve=makeEdit(p,100,24); reserve:SetPoint("LEFT",rLab,"RIGHT",18,0); reserve:SetNumeric(true); p.reserve=reserve
  local save=makeButton(p,"Save",70,24); save:SetPoint("LEFT",reserve,"RIGHT",12,0)
  save:SetScript("OnClick",function()
    if not A:IsOfficer() then A:Print("Officer permission required.") return end
    A.db.treasury=tonumber(treasury:GetText()) or A.db.treasury
    A.db.reserve=tonumber(reserve:GetText()) or A.db.reserve
    A:AddHistory("TREASURY","",0,"Treasury/reserve updated")
    A:MarkChanged()
  end)

  local adjTitle=makeText(p,"large"); adjTitle:SetPoint("TOPLEFT",8,-100); adjTitle:SetText("Manual DKP Adjustment")
  local player=makeEdit(p,180,24); player:SetPoint("TOPLEFT",8,-132); p.adjustPlayer=player
  local delta=makeEdit(p,90,24); delta:SetPoint("LEFT",player,"RIGHT",10,0); p.adjustDelta=delta
  local note=makeEdit(p,250,24); note:SetPoint("LEFT",delta,"RIGHT",10,0); p.adjustNote=note
  local apply=makeButton(p,"Apply",80,24); apply:SetPoint("LEFT",note,"RIGHT",10,0)
  apply:SetScript("OnClick",function()
    local ok,err=A:AdjustDKP(player:GetText(),delta:GetText(),note:GetText())
    if not ok then A:Print(err) end
  end)

  local aliasTitle=makeText(p,"large"); aliasTitle:SetPoint("TOPLEFT",8,-184); aliasTitle:SetText("Character Alias / Mapping")
  local char=makeEdit(p,180,24); char:SetPoint("TOPLEFT",8,-216); p.aliasChar=char
  local owner=makeEdit(p,180,24); owner:SetPoint("LEFT",char,"RIGHT",10,0); p.aliasOwner=owner
  local map=makeButton(p,"Save Mapping",100,24); map:SetPoint("LEFT",owner,"RIGHT",10,0)
  map:SetScript("OnClick",function()
    if not A:IsOfficer() then A:Print("Officer permission required.") return end
    local c=A:ShortName(char:GetText()); local o=owner:GetText()
    if c=="" or o=="" then return end
    A.db.characterMap[c]=o; A:EnsurePlayer(o,c); A:AddHistory("MAP",o,0,c.." mapped to "..o); A:MarkChanged()
  end)

  local dataTitle=makeText(p,"large"); dataTitle:SetPoint("TOPLEFT",8,-272); dataTitle:SetText("Data")
  local snap=makeButton(p,"Export Full Snapshot",140,24); snap:SetPoint("TOPLEFT",8,-304); snap:SetScript("OnClick",function() A:ShowExport(A:SerializeSnapshot()) end)
  local raid=makeButton(p,"Export Last Raid",120,24); raid:SetPoint("LEFT",snap,"RIGHT",10,0); raid:SetScript("OnClick",function() A:ShowExport(A:RaidExportText(A.db.raids[1])) end)
  local sync=makeButton(p,"Broadcast Sync",110,24); sync:SetPoint("LEFT",raid,"RIGHT",10,0); sync:SetScript("OnClick",function() A:BroadcastVersion() end)

  local info=makeText(p); info:SetPoint("TOPLEFT",8,-352); info:SetWidth(650); info:SetText("Defaults: 3+ world buffs = 3 DKP, 2+ tracked consumes = 3 DKP, full attendance = 4 DKP. Readiness rechecks are upgrade-only: a prior pass can never be downgraded by a later check.")
end

function A:ShowTab(i)
  self.currentTab=i or 1
  local panels={self.myPanel,self.guildPanel,self.raidPanel,self.historyPanel,self.adminPanel}
  for n,p in ipairs(panels) do if n==self.currentTab then p:Show() else p:Hide() end end
  if self.frame and self.frame.tabs then
    for n,b in ipairs(self.frame.tabs) do b:SetEnabled(n~=self.currentTab) end
    self.frame.tabs[5]:SetShown(self:IsOfficer())
  end
  self:RefreshUI()
end

function A:RefreshMyTab()
  local p=self.myPanel; if not p then return end
  local player=self:GetMyPlayer(); local info=self.db.players[player]
  p.name:SetText(player or "Unknown Player")
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
  local names={}; for n in pairs(self.db.players) do table.insert(names,n) end
  table.sort(names,function(a,b) return string.lower(a)<string.lower(b) end)
  local page=math.max(1,p.page or 1); local start=(page-1)*18+1
  if start>#names and page>1 then p.page=page-1; return self:RefreshGuildTab() end
  for i,row in ipairs(p.rows) do
    local n=names[start+i-1]
    if n then
      local inf=self.db.players[n]; row:SetText(string.format("%-28s %-28s %5d     %5dg",n,inf.main or "",tonumber(inf.dkp) or 0,self:GuildCredit(n)))
    else row:SetText("") end
  end
end

function A:RefreshRaidTab()
  local p=self.raidPanel; if not p then return end
  local r=self.db.activeRaid
  p.state:SetText(r and ((r.name or "Raid")..(r.locked and " — CHECK LOCKED" or " — ACTIVE")) or "No active raid")
  p.lock:SetText(r and r.locked and "Unlock Check" or "Lock Check")
  local names={}; if r then for n in pairs(r.players or {}) do table.insert(names,n) end end
  table.sort(names,function(a,b) return string.lower(a)<string.lower(b) end)
  for i,row in ipairs(p.rows) do
    local n=names[i]
    row.player=n
    if n then
      local e=r.players[n]
      local att=e.attendanceOverride and "YES" or (e.attendanceBroken and "NO" or "...")
      local wb=e.wb and "YES" or "NO"
      local con=e.consumes and "YES" or "NO"
      local d=(e.attendanceOverride and (self.db.settings.attendanceDKP or 4) or 0)+(e.wb and (self.db.settings.wbDKP or 3) or 0)+(e.consumes and (self.db.settings.consumeDKP or 3) or 0)
      row.text:SetText(string.format("%-22s %-22s %-5s %-6s %-6s %2d",n,e.char or "",att,wb.."("..(e.wbCount or 0)..")",con.."("..(e.consumeCount or 0)..")",d))
      if p.selected==n then row.text:SetText("> "..row.text:GetText()) end
    else row.text:SetText("") end
  end
  p.selectedText:SetText("Selected: "..tostring(p.selected or "none"))
end

function A:RefreshHistoryTab()
  local p=self.historyPanel; if not p then return end
  for i,row in ipairs(p.rows) do
    local h=self.db.history[i]
    if h then
      local t=date("%m/%d %H:%M",h.ts or time())
      local amt=(h.amount and h.amount~=0) and ((h.amount>0 and "+" or "")..tostring(h.amount).." DKP") or ""
      row:SetText(string.format("%s   %-10s %-20s %-9s %s",t,h.kind or "",h.player or "",amt,h.note or ""))
    else row:SetText("") end
  end
end

function A:RefreshAdminTab()
  local p=self.adminPanel; if not p then return end
  if not p.treasury:HasFocus() then p.treasury:SetText(fmt(self.db.treasury)) end
  if not p.reserve:HasFocus() then p.reserve:SetText(fmt(self.db.reserve)) end
end

function A:RefreshUI()
  if not self.frame then return end
  if self.statusText then self.statusText:SetText(string.format("Rate %.2fg/DKP",self:GoldPerDKP())) end
  self:RefreshMyTab(); self:RefreshGuildTab(); self:RefreshRaidTab(); self:RefreshHistoryTab(); self:RefreshAdminTab()
end

function A:ToggleUI()
  if not self.frame then self:InitUI() end
  if self.frame:IsShown() then self.frame:Hide() else self.frame:Show(); self:RefreshUI() end
end
