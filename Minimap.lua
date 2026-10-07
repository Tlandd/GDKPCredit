GDKPCredit=GDKPCredit or {}
local A=GDKPCredit
local ICON="Interface\\AddOns\\GDKPCredit\\Textures\\AddonIcon"

function A:UpdateMinimapButton()
  local button=self.minimapButton
  if not button or not Minimap then return end
  local settings=self.charDB.minimap
  local angle=tonumber(settings.angle) or 225
  local radians=math.rad(angle)
  local radius=(Minimap:GetWidth() or 140)/2+8
  button:ClearAllPoints()
  button:SetPoint("CENTER",Minimap,"CENTER",math.cos(radians)*radius,math.sin(radians)*radius)
  button:SetShown(not settings.hidden)
end

function A:InitMinimapButton()
  if not Minimap or not self.charDB then return end
  self.charDB.minimap=self.charDB.minimap or {angle=225,hidden=false}
  if self.minimapButton then self:UpdateMinimapButton(); return end
  local button=CreateFrame("Button","GDKPCreditMinimapButton",Minimap)
  self.minimapButton=button
  button:SetSize(32,32); button:SetFrameStrata("MEDIUM"); button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp"); button:RegisterForDrag("LeftButton")
  button:SetMovable(true); button:EnableMouse(true)
  local icon=button:CreateTexture(nil,"ARTWORK")
  icon:SetTexture(ICON); icon:SetSize(24,24); icon:SetPoint("CENTER",0,0)
  if button.CreateMaskTexture and icon.AddMaskTexture then
    local mask=button:CreateMaskTexture(nil,"ARTWORK")
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    mask:SetAllPoints(icon); icon:AddMaskTexture(mask)
  end
  local border=button:CreateTexture(nil,"OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(54,54); border:SetPoint("TOPLEFT",0,0)
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  button:SetScript("OnClick",function()
    if button.dragging or (button.dragStopped and GetTime and GetTime()-button.dragStopped<0.1) then return end
    A:ToggleUI()
  end)
  button:SetScript("OnEnter",function()
    if not GameTooltip then return end
    GameTooltip:SetOwner(button,"ANCHOR_LEFT")
    GameTooltip:AddLine("GDKP Credit",1,0.82,0)
    GameTooltip:AddLine("Click to open or close.",1,1,1)
    GameTooltip:AddLine("Drag to move around the minimap.",1,1,1)
    GameTooltip:AddLine("/gdkpc minimap to hide or show.",0.7,0.7,0.7)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
  button:SetScript("OnDragStart",function()
    button.dragging=true
    if GameTooltip then GameTooltip:Hide() end
    button:SetScript("OnUpdate",function()
      local x,y=GetCursorPosition()
      local scale=Minimap:GetEffectiveScale()
      local centerX,centerY=Minimap:GetCenter()
      if not centerX or not centerY or not scale or scale<=0 then return end
      A.charDB.minimap.angle=math.deg(math.atan2(y/scale-centerY,x/scale-centerX))
      A:UpdateMinimapButton()
    end)
  end)
  button:SetScript("OnDragStop",function()
    button.dragging=false; button.dragStopped=GetTime and GetTime() or nil
    button:SetScript("OnUpdate",nil); A:UpdateMinimapButton()
  end)
  self:UpdateMinimapButton()
end

function A:ToggleMinimapButton()
  self:InitMinimapButton()
  if not self.minimapButton then return end
  self.charDB.minimap.hidden=not self.charDB.minimap.hidden
  self:UpdateMinimapButton()
  self:Print(self.charDB.minimap.hidden and "Minimap icon hidden. Use /gdkpc minimap to show it." or "Minimap icon shown.")
end
