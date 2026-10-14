-- MINIMAL Blade Ball Auto Parry — без getgc/newcclosure, без HSH, 1 Remote
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local LocalPlayer=Players.LocalPlayer
local rem=nil
pcall(function()
    local r=ReplicatedStorage:FindFirstChild("Remotes")
    if r then rem=r:FindFirstChild("ParryButtonPress") or r:FindFirstChild("ParryAttempt") end
    if not rem then
        for _,o in ipairs(ReplicatedStorage:GetDescendants()) do
            if o:IsA("RemoteEvent") and o.Name:lower():find("parry") then rem=o break end
        end
    end
end)
if not rem then
    warn("Parry Remote не найден, пробую VirtualInput")
end
local function fire()
    if rem then pcall(function() rem:FireServer() end)
    else
        pcall(function() game:GetService("VirtualInputManager"):SendKeyEvent(true,Enum.KeyCode.F,false,game) task.wait() game:GetService("VirtualInputManager"):SendKeyEvent(false,Enum.KeyCode.F,false,game) end)
    end
end
local function getBall()
    local f=Workspace:FindFirstChild("Balls")
    if f and #f:GetChildren()>0 then
        local best,dist=nil,1e9
        for _,b in ipairs(f:GetChildren()) do
            if b:IsA("BasePart") then
                local d=(b.Position-LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                if d<dist then best,dist=b,d end
            end
        end
        return best
    end
    return nil
end
-- GUI
local gui=Instance.new("ScreenGui") gui.Name="MIN" gui.ResetOnSpawn=false gui.Parent=LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")
local fr=Instance.new("Frame",gui) fr.Size=UDim2.fromOffset(260,140) fr.Position=UDim2.fromScale(0.02,0.35) fr.BackgroundColor3=Color3.fromRGB(14,14,18) Instance.new("UICorner",fr).CornerRadius=UDim.new(0,12)
local t=Instance.new("TextLabel",fr) t.Size=UDim2.new(1,-20,0,24) t.Position=UDim2.fromOffset(10,10) t.BackgroundTransparency=1 t.Text="MINIMAL AUTO PARRY" t.TextColor3=Color3.fromRGB(80,255,120) t.Font=Enum.Font.GothamBold t.TextSize=12 t.TextXAlignment=Enum.TextXAlignment.Left
local st=Instance.new("TextLabel",fr) st.Size=UDim2.new(1,-20,0,20) st.Position=UDim2.fromOffset(10,36) st.BackgroundTransparency=1 st.Text=rem and ("Remote: "..rem.Name) or "Virtual F" st.TextColor3=Color3.fromRGB(180,180,185) st.Font=Enum.Font.Gotham st.TextSize=10 st.TextXAlignment=Enum.TextXAlignment.Left
local en=true
local btn=Instance.new("TextButton",fr) btn.Size=UDim2.new(1,-20,0,30) btn.Position=UDim2.fromOffset(10,62) btn.Text="ON" btn.BackgroundColor3=Color3.fromRGB(80,255,120) btn.Font=Enum.Font.GothamBold Instance.new("UICorner",btn).CornerRadius=UDim.new(0,8)
btn.MouseButton1Click:Connect(function() en=not en btn.Text=en and "ON" or "OFF" btn.BackgroundColor3=en and Color3.fromRGB(80,255,120) or Color3.fromRGB(45,45,50) end)
local test=Instance.new("TextButton",fr) test.Size=UDim2.new(1,-20,0,28) test.Position=UDim2.fromOffset(10,98) test.Text="TEST" test.BackgroundColor3=Color3.fromRGB(45,45,50) test.TextColor3=Color3.fromRGB(220,220,220) test.Font=Enum.Font.GothamBold Instance.new("UICorner",test).CornerRadius=UDim.new(0,8)
test.MouseButton1Click:Connect(function() fire() st.Text="TEST" end)
local close=Instance.new("TextButton",fr) close.Size=UDim2.fromOffset(24,24) close.Position=UDim2.new(1,-30,0,6) close.Text="x" close.BackgroundColor3=Color3.fromRGB(35,35,40) Instance.new("UICorner",close).CornerRadius=UDim.new(0,7) close.MouseButton1Click:Connect(function() gui:Destroy() en=false end)
-- drag
local drag,ds,sp
fr.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=true ds=i.Position sp=fr.Position i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then drag=false end end) end end)
fr.InputChanged:Connect(function(i) if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then local d=i.Position-ds fr.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end)
local last=0
RunService.Heartbeat:Connect(function()
    if not en then return end
    if tick()-last<0.22 then return end
    local ch=LocalPlayer.Character if not ch or not ch:FindFirstChild("HumanoidRootPart") then return end
    local ball=getBall() if not ball then st.Text="ищу мяч..." return end
    local hrp=ch.HumanoidRootPart
    local dist=(ball.Position-hrp.Position).Magnitude
    local speed=ball.Velocity.Magnitude
    if speed<20 then return end
    local tth=dist/speed
    local ping=0 pcall(function() ping=game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()/1000 end)
    tth=tth-ping
    if tth<0.25 and tth>0 then
        local dot=(hrp.Position-ball.Position).Unit:Dot(ball.Velocity.Unit)
        local target=ball:GetAttribute("Target")
        if dot>0.2 and (not target or target==LocalPlayer.Name) then
            last=tick() fire() st.Text=string.format("PARRY d=%.1f",dist)
        end
    else
        st.Text=string.format("d=%.1f t=%.3f",dist,tth)
    end
end)
print("MINIMAL loaded")
