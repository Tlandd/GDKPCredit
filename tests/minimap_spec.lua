assert(loadfile("tests/role_access_spec.lua"))()
assert(loadfile("Minimap.lua"))()
local A=GDKPCredit
local n=0
local function check(label,a,b) assert(a==b,label..": "..tostring(a).." != "..tostring(b)); n=n+1 end
local made=0
local function texture()
  return {SetTexture=function(self,v) self.path=v end,SetSize=function() end,SetPoint=function() end,SetAllPoints=function() end,AddMaskTexture=function() end}
end
CreateFrame=function()
  made=made+1
  local f={scripts={}}
  setmetatable(f,{__index=function(_,k) if k:match("^[A-Z]") then return function() end end end})
  function f:SetScript(k,v) self.scripts[k]=v end
  function f:CreateTexture() return texture() end
  function f:CreateMaskTexture() return texture() end
  function f:SetPoint(...) self.point={...} end
  function f:SetShown(v) self.shown=v end
  return f
end
Minimap={GetWidth=function() return 140 end,GetEffectiveScale=function() return 2 end,GetCenter=function() return 100,100 end}
GetCursorPosition=function() return 400,200 end
local clock=10; GetTime=function() return clock end
local clicks=0; A.ToggleUI=function() clicks=clicks+1 end
A.minimapButton=nil; A.charDB.minimap=nil
A:InitMinimapButton()
local b=A.minimapButton
check("shown by default",b.shown,true)
check("default position saved",A.charDB.minimap.angle,225)
b.scripts.OnClick(); check("click opens addon",clicks,1)
b.scripts.OnDragStart(); b.scripts.OnUpdate()
check("drag saves correct scaled angle",A.charDB.minimap.angle,0)
check("drag moves around edge",b.point[4],78)
b.scripts.OnClick(); check("drag cannot open addon",clicks,1)
b.scripts.OnDragStop()
check("drag update stops",b.scripts.OnUpdate,nil)
b.scripts.OnClick(); check("release cannot open addon",clicks,1)
clock=clock+1; b.scripts.OnClick(); check("next click works",clicks,2)
A:ToggleMinimapButton(); check("hide command",b.shown,false)
check("visibility saved",A.charDB.minimap.hidden,true)
A:InitMinimapButton(); check("reinit preserves hidden",b.shown,false)
check("no duplicate button",made,1)
A:ToggleMinimapButton(); check("show command",b.shown,true)
check("position survives reinit",A.charDB.minimap.angle,0)
print("PASS: "..n.." minimap click, drag, scaling, saved position and visibility checks (".._VERSION..")")
