GDKPCredit=GDKPCredit or {}
local A=GDKPCredit
local ROOT="Interface\\AddOns\\GDKPCredit\\Textures\\"
function A:GetTheme()
  return self.charDB and self.charDB.theme=="BART" and "BART" or "Default"
end
function A:ThemeDisplayName(theme)
  return (theme or self:GetTheme())=="BART" and "BART(SLOP)" or "Default"
end
function A:RegisterThemeSurface(frame,r,g,b)
  self.themeSurfaces=self.themeSurfaces or {}
  local surface={frame=frame,r=r or 0.055,g=g or 0.065,b=b or 0.085}
  self.themeSurfaces[#self.themeSurfaces+1]=surface
  if self:GetTheme()=="BART" then
    frame:SetBackdropColor(0.10,0.012,0.035,0.92)
    frame:SetBackdropBorderColor(0.72,0.035,0.13,1)
  end
end
function A:ApplyTheme()
  local bart=self:GetTheme()=="BART"
  for _,surface in ipairs(self.themeSurfaces or {}) do
    if bart then
      surface.frame:SetBackdropColor(0.10,0.012,0.035,0.92)
      surface.frame:SetBackdropBorderColor(0.72,0.035,0.13,1)
    else
      surface.frame:SetBackdropColor(surface.r,surface.g,surface.b,0.98)
      surface.frame:SetBackdropBorderColor(0.24,0.27,0.32,1)
    end
  end
  local f=self.frame
  if not f then return end
  if bart and not f.bartBackground then
    f.bartBackground=f:CreateTexture(nil,"BACKGROUND",nil,0)
    f.bartBackground:SetTexture(ROOT.."BARTBackground")
    f.bartBackground:SetAllPoints(f)
    f.bartBorder=f:CreateTexture(nil,"ARTWORK",nil,0)
    f.bartBorder:SetTexture(ROOT.."BARTBorder")
    f.bartBorder:SetPoint("TOPLEFT",f,"TOPLEFT",-34,34)
    f.bartBorder:SetPoint("BOTTOMRIGHT",f,"BOTTOMRIGHT",34,-34)
  end
  if f.bartBackground then f.bartBackground:SetShown(bart); f.bartBorder:SetShown(bart) end
  if f.themeButton then f.themeButton:SetText("Theme: "..self:ThemeDisplayName()) end
end
function A:SetTheme(theme)
  if theme~="Default" and theme~="BART" then return false end
  self.charDB.theme=theme
  self:ApplyTheme()
  if self.frame and self.frame.themeMenu then self.frame.themeMenu:Hide() end
  return true
end
