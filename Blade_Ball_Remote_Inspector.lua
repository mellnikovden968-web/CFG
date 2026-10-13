-- RAW Blade Ball Inspector — без обфускации, для Delta если __sb падает
local Players=game:GetService("Players")
local LocalPlayer=Players.LocalPlayer
local ROOT="BladeBall_Inspector"
local SAVE_FILE=ROOT.."/parry_log.txt"
if type(makefolder)=="function" then pcall(makefolder, ROOT) end
local gui=Instance.new("ScreenGui")
gui.Name="BBInspectorRAW"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=9999
pcall(function() gui.Parent=LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent=game:GetService("CoreGui") end
local frame=Instance.new("Frame",gui)
frame.Size=UDim2.fromOffset(440,340)
frame.Position=UDim2.fromScale(0.5,0.5)
frame.AnchorPoint=Vector2.new(0.5,0.5)
frame.BackgroundColor3=Color3.fromRGB(14,14,18)
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,14)
local s=Instance.new("UIStroke",frame)
s.Color=Color3.fromRGB(80,255,120) s.Thickness=1.5
local title=Instance.new("TextLabel",frame)
title.Size=UDim2.new(1,-40,0,28)
title.Position=UDim2.fromOffset(14,8)
title.BackgroundTransparency=1
title.Text="BLADE BALL / RAW (без обфускации)"
title.TextColor3=Color3.fromRGB(80,255,120)
title.Font=Enum.Font.GothamBold
title.TextSize=11
title.TextXAlignment=Enum.TextXAlignment.Left
local close=Instance.new("TextButton",frame)
close.Size=UDim2.fromOffset(26,26)
close.Position=UDim2.new(1,-32,0,6)
close.Text="x"
close.BackgroundColor3=Color3.fromRGB(35,35,40)
Instance.new("UICorner",close).CornerRadius=UDim.new(0,8)
close.MouseButton1Click:Connect(function() gui:Destroy() end)
local btn=Instance.new("TextButton",frame)
btn.Size=UDim2.fromOffset(160,32)
btn.Position=UDim2.fromOffset(14,42)
btn.Text="● ЗАПИСЬ 3с"
btn.BackgroundColor3=Color3.fromRGB(80,255,120)
btn.Font=Enum.Font.GothamBold
Instance.new("UICorner",btn).CornerRadius=UDim.new(0,10)
local status=Instance.new("TextLabel",frame)
status.Size=UDim2.new(1,-20,0,18)
status.Position=UDim2.fromOffset(10,80)
status.BackgroundTransparency=1
status.Text="Готов — жми ЗАПИСЬ → F"
status.TextColor3=Color3.fromRGB(180,180,185)
status.Font=Enum.Font.Gotham
status.TextSize=11
status.TextXAlignment=Enum.TextXAlignment.Left
local scroll=Instance.new("ScrollingFrame",frame)
scroll.Size=UDim2.new(1,-20,1,-108)
scroll.Position=UDim2.fromOffset(10,102)
scroll.BackgroundColor3=Color3.fromRGB(22,22,26)
scroll.BorderSizePixel=0
scroll.CanvasSize=UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
scroll.ScrollBarThickness=4
Instance.new("UICorner",scroll).CornerRadius=UDim.new(0,10)
local layout=Instance.new("UIListLayout",scroll)
layout.Padding=UDim.new(0,6)
local function add(t,c,p)
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-10,0,0)
    lbl.AutomaticSize=Enum.AutomaticSize.Y
    lbl.BackgroundColor3=p and Color3.fromRGB(24,60,30) or Color3.fromRGB(32,32,36)
    lbl.Text=t
    lbl.TextColor3=c
    lbl.Font=Enum.Font.Code
    lbl.TextSize=11
    lbl.TextWrapped=true
    lbl.TextXAlignment=Enum.TextXAlignment.Left
    Instance.new("UICorner",lbl).CornerRadius=UDim.new(0,8)
    Instance.new("UIPadding",lbl).PaddingTop=UDim.new(0,6)
    lbl.Parent=scroll
    if p then local st=Instance.new("UIStroke",lbl) st.Color=Color3.fromRGB(80,255,120) end
end
local function fullName(i) local ok,v=pcall(function() return i:GetFullName() end) return ok and v or i.Name end
local rec=false
local buf={}
if type(hookmetamethod)=="function" then
    local old
    old=hookmetamethod(game,"__namecall",function(self,...)
        local m=getnamecallmethod()
        if (m=="FireServer" or m=="InvokeServer") and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
            local path=fullName(self)
            if rec then
                table.insert(buf, path)
                if type(appendfile)=="function" then pcall(appendfile, SAVE_FILE, path.."\n") end
                add(path, Color3.fromRGB(80,255,120), true)
            end
        end
        return old(self,...)
    end)
    add("hookmetamethod OK", Color3.fromRGB(80,255,120), false)
else
    add("hookmetamethod НЕТ — ловлю напрямую, жми ЗАПИСЬ", Color3.fromRGB(255,180,120), false)
    for _,r in ipairs(game:GetDescendants()) do
        if r:IsA("RemoteEvent") then
            r.OnClientEvent:Connect(function() end)
        end
    end
end
btn.MouseButton1Click:Connect(function()
    rec=true buf={} status.Text="● ИДЁТ ЗАПИСЬ 3с — ЖМИ F!" status.TextColor3=Color3.fromRGB(255,90,90)
    if type(writefile)=="function" then pcall(writefile, SAVE_FILE, "-- log "..os.date().."\n") end
    add("— ЗАПИСЬ —", Color3.fromRGB(255,90,90), true)
    task.delay(3,function()
        rec=false status.Text="Готово: "..#buf.." → BladeBall_Inspector/parry_log.txt" status.TextColor3=Color3.fromRGB(80,255,120)
        if #buf==0 then add("0 событий — пробуй ещё раз", Color3.fromRGB(255,120,120), false) else add("Сохранено "..#buf, Color3.fromRGB(80,255,120), true) end
    end)
end)
add("RAW готов. Перезапусти Roblox и запускай ТОЛЬКО этот, без Noir лоадера", Color3.fromRGB(180,180,185), false)
