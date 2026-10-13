-- Blade Ball Auto Parry V3 FIX HSH-2 — 1 Remote + анти-детект
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    Enabled = true,
    DistanceMulti = 1.15, -- чуть ниже 1.25 чтобы не палиться
    SpamEnabled = false, -- выкл спам по умолчанию (палит HSH-2)
    SpamMulti = 1.05,
    Prediction = true,
    Cooldown = 0.22, -- увеличь задержку между парри
    Visualize = true,
}

-- ТОЧЕЧНЫЙ поиск: только Parry, не 845 штук
local function findParryRemote()
    local best = nil
    -- 1) ищем точно ParryButtonPress / ParryAttempt в Remotes
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if remotesFolder then
        for _,o in ipairs(remotesFolder:GetChildren()) do
            if o:IsA("RemoteEvent") then
                local n=o.Name:lower()
                if n:find("parry") or n:find("block") then
                    return o -- нашли точный
                end
                if not best then best=o end
            end
        end
        -- если точного нет, берем первый из Remotes (но не все 845)
        if remotesFolder:FindFirstChild("ParryButtonPress") then return remotesFolder.ParryButtonPress end
        if remotesFolder:FindFirstChild("ParryAttempt") then return remotesFolder.ParryAttempt end
    end
    -- 2) sleitnick_net — не берём все 845, берём только 1-2 с хешем 11227bc... (твой лог показал он активный)
    local net = ReplicatedStorage:FindFirstChild("Packages")
    if net then net=net:FindFirstChild("_Index") end
    if net then net=net:FindFirstChild("sleitnick_net@0.1.0") end
    if net then net=net:FindFirstChild("net") end
    if net then
        -- ищем RE с нужным хешем (из твоего лога)
        for _,o in ipairs(net:GetDescendants()) do
            if o:IsA("RemoteEvent") and o.Name=="11227bc656333a49c1c375b0456820de4a76d33b1048faff2de040f8b30eb6cf" then
                return o
            end
        end
        -- fallback: первый RemoteEvent в net
        for _,o in ipairs(net:GetDescendants()) do
            if o:IsA("RemoteEvent") then return o end
        end
    end
    return best
end

local parryRemote = findParryRemote()
print("[AutoParry V3] Remote:", parryRemote and parryRemote:GetFullName() or "НЕ НАЙДЕН")
if not parryRemote then
    warn("Parry Remote не найден — открой ReplicatedStorage.Remotes и скинь скрин")
end

local function fireParry()
    if not parryRemote then return end
    -- один выстрел, не спам 845
    pcall(function() parryRemote:FireServer() end)
    -- анти-детект: небольшая рандом задержка уже в Cooldown, не шлём второй раз
end

local function getBall()
    local balls = Workspace:FindFirstChild("Balls")
    if balls and #balls:GetChildren()>0 then
        local best, bestDist = nil, math.huge
        for _,b in ipairs(balls:GetChildren()) do
            if b:IsA("BasePart") then
                local d = (b.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                if d < bestDist then best, bestDist = b, d end
            end
        end
        return best
    end
    return nil
end

-- GUI V3
local gui = Instance.new("ScreenGui")
gui.Name="BladeParryGUI_V3"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=9999
pcall(function() gui.Parent=LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent=game:GetService("CoreGui") end
local frame=Instance.new("Frame",gui)
frame.Size=UDim2.fromOffset(360,340)
frame.Position=UDim2.fromScale(0.02,0.35)
frame.BackgroundColor3=Color3.fromRGB(14,14,18)
frame.BorderSizePixel=0
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,14)
local stroke=Instance.new("UIStroke",frame)
stroke.Color=Color3.fromRGB(80,255,120) stroke.Thickness=1.2
local title=Instance.new("TextLabel",frame)
title.Size=UDim2.new(1,-40,0,28) title.Position=UDim2.fromOffset(14,8) title.BackgroundTransparency=1
title.Text="BLADE BALL / FIX HSH-2" title.TextColor3=Color3.fromRGB(80,255,120) title.Font=Enum.Font.GothamBold title.TextSize=12 title.TextXAlignment=Enum.TextXAlignment.Left
local closeBtn=Instance.new("TextButton",frame)
closeBtn.Size=UDim2.fromOffset(26,26) closeBtn.Position=UDim2.new(1,-32,0,6) closeBtn.Text="x" closeBtn.Font=Enum.Font.GothamBold closeBtn.TextSize=14 closeBtn.TextColor3=Color3.fromRGB(200,200,200) closeBtn.BackgroundColor3=Color3.fromRGB(35,35,40)
Instance.new("UICorner",closeBtn).CornerRadius=UDim.new(0,8)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)
local dragging,dragStart,startPos
frame.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true dragStart=input.Position startPos=frame.Position input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end) end end)
frame.InputChanged:Connect(function(input) if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then local d=input.Position-dragStart frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)
local statusLbl=Instance.new("TextLabel",frame)
statusLbl.Size=UDim2.new(1,-20,0,20) statusLbl.Position=UDim2.fromOffset(10,36) statusLbl.BackgroundTransparency=1
statusLbl.Text=parryRemote and ("● 1 Remote: "..parryRemote.Name) or "● Remote не найден"
statusLbl.TextColor3=parryRemote and Color3.fromRGB(80,255,120) or Color3.fromRGB(255,90,90)
statusLbl.Font=Enum.Font.Gotham statusLbl.TextSize=10 statusLbl.TextXAlignment=Enum.TextXAlignment.Left

local function createToggle(text,y,default,cb)
    local row=Instance.new("Frame",frame) row.Size=UDim2.new(1,-20,0,28) row.Position=UDim2.fromOffset(10,y) row.BackgroundTransparency=1
    local lbl=Instance.new("TextLabel",row) lbl.Size=UDim2.new(1,-56,1,0) lbl.BackgroundTransparency=1 lbl.Text=text lbl.TextColor3=Color3.fromRGB(220,220,220) lbl.Font=Enum.Font.Gotham lbl.TextSize=11 lbl.TextXAlignment=Enum.TextXAlignment.Left
    local btn=Instance.new("TextButton",row) btn.Size=UDim2.fromOffset(48,22) btn.Position=UDim2.new(1,-48,0.5,-11) btn.Text=default and "ON" or "OFF" btn.Font=Enum.Font.GothamBold btn.TextSize=10 btn.TextColor3=default and Color3.fromRGB(14,14,18) or Color3.fromRGB(180,180,180) btn.BackgroundColor3=default and Color3.fromRGB(80,255,120) or Color3.fromRGB(45,45,50) Instance.new("UICorner",btn).CornerRadius=UDim.new(0,8)
    local on=default
    btn.MouseButton1Click:Connect(function() on=not on btn.Text=on and "ON" or "OFF" btn.BackgroundColor3=on and Color3.fromRGB(80,255,120) or Color3.fromRGB(45,45,50) btn.TextColor3=on and Color3.fromRGB(14,14,18) or Color3.fromRGB(180,180,180) cb(on) end)
    return btn
end
local function createSlider(text,y,min,max,default,step,cb)
    local row=Instance.new("Frame",frame) row.Size=UDim2.new(1,-20,0,40) row.Position=UDim2.fromOffset(10,y) row.BackgroundTransparency=1
    local lbl=Instance.new("TextLabel",row) lbl.Size=UDim2.new(1,0,0,16) lbl.BackgroundTransparency=1 lbl.Text=text.." : "..string.format("%.2f",default) lbl.TextColor3=Color3.fromRGB(220,220,220) lbl.Font=Enum.Font.Gotham lbl.TextSize=11 lbl.TextXAlignment=Enum.TextXAlignment.Left
    local bar=Instance.new("Frame",row) bar.Size=UDim2.new(1,0,0,8) bar.Position=UDim2.fromOffset(0,20) bar.BackgroundColor3=Color3.fromRGB(35,35,40) Instance.new("UICorner",bar).CornerRadius=UDim.new(0,4)
    local fill=Instance.new("Frame",bar) fill.Size=UDim2.new((default-min)/(max-min),0,1,0) fill.BackgroundColor3=Color3.fromRGB(80,255,120) Instance.new("UICorner",fill).CornerRadius=UDim.new(0,4)
    local knob=Instance.new("Frame",fill) knob.Size=UDim2.fromOffset(14,14) knob.Position=UDim2.new(1,-7,0.5,-7) knob.BackgroundColor3=Color3.fromRGB(220,255,220) Instance.new("UICorner",knob).CornerRadius=UDim.new(0,7)
    local draggingSlider=false
    local function update(input)
        local rel=math.clamp((input.Position.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1)
        local val=min+rel*(max-min) val=math.floor(val/step+0.5)*step rel=(val-min)/(max-min) fill.Size=UDim2.new(rel,0,1,0) lbl.Text=text.." : "..string.format("%.2f",val) cb(val)
    end
    bar.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then draggingSlider=true update(input) end end)
    bar.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then draggingSlider=false end end)
    game:GetService("UserInputService").InputChanged:Connect(function(input) if draggingSlider and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then update(input) end end)
    return row
end

createToggle("Auto Parry",60,CONFIG.Enabled,function(v) CONFIG.Enabled=v statusLbl.Text=v and "● ВКЛ" or "○ ВЫКЛ" end)
createToggle("Prediction",92,CONFIG.Prediction,function(v) CONFIG.Prediction=v end)
createToggle("Spam (риск HSH-2)",124,CONFIG.SpamEnabled,function(v) CONFIG.SpamEnabled=v end)
createSlider("Дистанция",160,0.5,2.0,CONFIG.DistanceMulti,0.05,function(v) CONFIG.DistanceMulti=v end)
createSlider("Кулдаун сек",204,0.1,0.5,CONFIG.Cooldown,0.02,function(v) CONFIG.Cooldown=v end)

local testBtn=Instance.new("TextButton",frame)
testBtn.Size=UDim2.new(1,-20,0,28) testBtn.Position=UDim2.fromOffset(10,252) testBtn.Text="TEST PARRY (1 раз)" testBtn.Font=Enum.Font.GothamBold testBtn.TextSize=11 testBtn.TextColor3=Color3.fromRGB(14,14,18) testBtn.BackgroundColor3=Color3.fromRGB(80,255,120) Instance.new("UICorner",testBtn).CornerRadius=UDim.new(0,10)
testBtn.MouseButton1Click:Connect(function() fireParry() statusLbl.Text="TEST → "..(parryRemote and parryRemote.Name or "nil") end)

local warnLbl=Instance.new("TextLabel",frame)
warnLbl.Size=UDim2.new(1,-20,0,30) warnLbl.Position=UDim2.fromOffset(10,284) warnLbl.BackgroundTransparency=1
warnLbl.Text="FIX: 1 Remote вместо 845 • Кулдаун 0.22с • Тестируй в TRAINING"
warnLbl.TextColor3=Color3.fromRGB(255,180,120) warnLbl.Font=Enum.Font.Gotham warnLbl.TextSize=9 warnLbl.TextWrapped=true warnLbl.TextXAlignment=Enum.TextXAlignment.Center

local lastParry=0
RunService.Heartbeat:Connect(function()
    if not CONFIG.Enabled or not parryRemote then return end
    if tick()-lastParry < CONFIG.Cooldown then return end
    local char=LocalPlayer.Character if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local ball=getBall() if not ball then statusLbl.Text="ищу мяч..." return end
    local hrp=char.HumanoidRootPart
    local dist=(ball.Position-hrp.Position).Magnitude
    local speed=ball.Velocity.Magnitude
    if speed<20 then return end
    local timeToHit=dist/speed
    local ping=0 pcall(function() ping=game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()/1000 end)
    if CONFIG.Prediction then timeToHit=timeToHit-ping end
    -- рандом +- 0.02с чтобы не палиться
    local threshold=0.22*CONFIG.DistanceMulti + (math.random()-0.5)*0.04
    if timeToHit < threshold and timeToHit > 0 then
        local dirToPlayer=(hrp.Position-ball.Position).Unit
        local ballDir=ball.Velocity.Unit
        local dot=dirToPlayer:Dot(ballDir)
        -- проверяем что мяч на нас (Attribute Target)
        local isTarget = true
        pcall(function()
            local t = ball:GetAttribute("Target")
            if t and t ~= LocalPlayer.Name then isTarget=false end
        end)
        if dot > 0.25 and isTarget then
            lastParry=tick()
            fireParry()
            statusLbl.Text=string.format("PARRY! d=%.1f",dist)
        end
    elseif CONFIG.SpamEnabled and timeToHit < threshold*CONFIG.SpamMulti then
        if tick()-lastParry > 0.18 then lastParry=tick() fireParry() end
    else
        statusLbl.Text=string.format("● d=%.1f t=%.3f",dist,timeToHit)
    end
end)

getgenv().BladeAutoParry={Config=CONFIG, Fire=fireParry, Remote=parryRemote, GUI=gui}
print("[V3 FIX] 1 Remote, cooldown "..CONFIG.Cooldown)
