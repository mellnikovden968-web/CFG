-- Blade Ball Auto Parry + GUI ползунки (как в FFJ V3)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local TweenService = game:GetService("TweenService")

local CONFIG = {
    Enabled = true,
    DistanceMulti = 1.25,
    SpamEnabled = true,
    SpamMulti = 1.05,
    Prediction = true,
    Cooldown = 0.15,
    SpamCooldown = 0.05,
    Visualize = true,
}

-- найти Remote кандидаты
local function findParryRemote()
    local candidates = {}
    local seen = {}
    local function add(r)
        if not seen[r] then seen[r]=true table.insert(candidates, r) end
    end
    for _,o in ipairs(ReplicatedStorage:GetDescendants()) do
        if o:IsA("RemoteEvent") and o.Name:lower():find("parry") then add(o) end
    end
    -- sleitnick_net
    local net = ReplicatedStorage:FindFirstChild("Packages")
    if net then net = net:FindFirstChild("_Index") end
    if net then net = net:FindFirstChild("sleitnick_net@0.1.0") end
    if net then net = net:FindFirstChild("net") end
    if net then
        for _,o in ipairs(net:GetDescendants()) do
            if o:IsA("RemoteEvent") then add(o) end
        end
    end
    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
    if remotesFolder then
        for _,o in ipairs(remotesFolder:GetChildren()) do
            if o:IsA("RemoteEvent") then add(o) end
        end
    end
    -- fallback: возьмём те два из лога если не нашли
    if #candidates==0 then
        for _,o in ipairs(ReplicatedStorage:GetDescendants()) do
            if o:IsA("RemoteEvent") and o:GetFullName():find("sleitnick_net") then add(o) end
        end
    end
    return candidates
end

local parryRemotes = findParryRemote()
print("[AutoParry] candidates:", #parryRemotes)
for i,r in ipairs(parryRemotes) do print(i, r:GetFullName()) end

local function fireParry()
    for _,r in ipairs(parryRemotes) do pcall(function() r:FireServer() end) end
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
    for _,o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("BasePart") and o.Name:lower():find("ball") and o.Velocity.Magnitude > 50 then return o end
    end
    return nil
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "BladeParryGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 9999
pcall(function() gui.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = game:GetService("CoreGui") end

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(360, 320)
frame.Position = UDim2.fromScale(0.02, 0.35)
frame.BackgroundColor3 = Color3.fromRGB(14,14,18)
frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke", frame)
stroke.Color = Color3.fromRGB(80,255,120)
stroke.Thickness = 1.2

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, -40, 0, 28)
title.Position = UDim2.fromOffset(14, 8)
title.BackgroundTransparency = 1
title.Text = "BLADE BALL / AUTO PARRY"
title.TextColor3 = Color3.fromRGB(80,255,120)
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", frame)
closeBtn.Size = UDim2.fromOffset(26,26)
closeBtn.Position = UDim2.new(1, -32, 0, 6)
closeBtn.Text = "x"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.fromRGB(200,200,200)
closeBtn.BackgroundColor3 = Color3.fromRGB(35,35,40)
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,8)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- drag
local dragging, dragStart, startPos
frame.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        dragging=true dragStart=input.Position startPos=frame.Position
        input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end)
    end
end)
frame.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
        local d=input.Position-dragStart
        frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)

local statusLbl = Instance.new("TextLabel", frame)
statusLbl.Size = UDim2.new(1, -20, 0, 20)
statusLbl.Position = UDim2.fromOffset(10, 36)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "● ВКЛ — ждёт мяч"
statusLbl.TextColor3 = Color3.fromRGB(80,255,120)
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextSize = 11
statusLbl.TextXAlignment = Enum.TextXAlignment.Left

local function createToggle(text, y, default, callback)
    local row = Instance.new("Frame", frame)
    row.Size = UDim2.new(1, -20, 0, 28)
    row.Position = UDim2.fromOffset(10, y)
    row.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -56, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(220,220,220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.fromOffset(48, 22)
    btn.Position = UDim2.new(1, -48, 0.5, -11)
    btn.Text = default and "ON" or "OFF"
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.TextColor3 = default and Color3.fromRGB(14,14,18) or Color3.fromRGB(180,180,180)
    btn.BackgroundColor3 = default and Color3.fromRGB(80,255,120) or Color3.fromRGB(45,45,50)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    local on = default
    btn.MouseButton1Click:Connect(function()
        on = not on
        btn.Text = on and "ON" or "OFF"
        btn.BackgroundColor3 = on and Color3.fromRGB(80,255,120) or Color3.fromRGB(45,45,50)
        btn.TextColor3 = on and Color3.fromRGB(14,14,18) or Color3.fromRGB(180,180,180)
        callback(on)
    end)
    return btn
end

local function createSlider(text, y, min, max, default, step, callback)
    local row = Instance.new("Frame", frame)
    row.Size = UDim2.new(1, -20, 0, 40)
    row.Position = UDim2.fromOffset(10, y)
    row.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Text = text.." : "..string.format("%.2f", default)
    lbl.TextColor3 = Color3.fromRGB(220,220,220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local bar = Instance.new("Frame", row)
    bar.Size = UDim2.new(1, 0, 0, 8)
    bar.Position = UDim2.fromOffset(0, 20)
    bar.BackgroundColor3 = Color3.fromRGB(35,35,40)
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0,4)
    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(80,255,120)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0,4)
    local knob = Instance.new("Frame", fill)
    knob.Size = UDim2.fromOffset(14,14)
    knob.Position = UDim2.new(1, -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(220,255,220)
    Instance.new("UICorner", knob).CornerRadius = UDim.new(0,7)
    local draggingSlider = false
    local function update(input)
        local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X)/bar.AbsoluteSize.X, 0, 1)
        local val = min + rel*(max-min)
        val = math.floor(val/step+0.5)*step
        rel = (val-min)/(max-min)
        fill.Size = UDim2.new(rel,0,1,0)
        lbl.Text = text.." : "..string.format("%.2f", val)
        callback(val)
    end
    bar.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
            draggingSlider=true
            update(input)
        end
    end)
    bar.InputEnded:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then draggingSlider=false end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if draggingSlider and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            update(input)
        end
    end)
    return row
end

createToggle("Auto Parry", 60, CONFIG.Enabled, function(v) CONFIG.Enabled=v statusLbl.Text=v and "● ВКЛ — ждёт мяч" or "○ ВЫКЛ" statusLbl.TextColor3=v and Color3.fromRGB(80,255,120) or Color3.fromRGB(180,180,185) end)
createToggle("Prediction (пинг)", 92, CONFIG.Prediction, function(v) CONFIG.Prediction=v end)
createToggle("Spam (добивание)", 124, CONFIG.SpamEnabled, function(v) CONFIG.SpamEnabled=v end)
createSlider("Дистанция", 160, 0.5, 2.0, CONFIG.DistanceMulti, 0.05, function(v) CONFIG.DistanceMulti=v end)
createSlider("Spam дистанция", 204, 0.5, 1.5, CONFIG.SpamMulti, 0.05, function(v) CONFIG.SpamMulti=v end)

local testBtn = Instance.new("TextButton", frame)
testBtn.Size = UDim2.new(1, -20, 0, 28)
testBtn.Position = UDim2.fromOffset(10, 252)
testBtn.Text = "TEST PARRY"
testBtn.Font = Enum.Font.GothamBold
testBtn.TextSize = 11
testBtn.TextColor3 = Color3.fromRGB(14,14,18)
testBtn.BackgroundColor3 = Color3.fromRGB(80,255,120)
Instance.new("UICorner", testBtn).CornerRadius = UDim.new(0,10)
testBtn.MouseButton1Click:Connect(function()
    fireParry()
    statusLbl.Text = "TEST отправлен ("..#parryRemotes.." remotes)"
end)

local info = Instance.new("TextLabel", frame)
info.Size = UDim2.new(1, -20, 0, 28)
info.Position = UDim2.fromOffset(10, 284)
info.BackgroundTransparency = 1
info.Text = #parryRemotes.." remotes найдено • FFJ 1.25 / 1.05"
info.TextColor3 = Color3.fromRGB(120,120,130)
info.Font = Enum.Font.Gotham
info.TextSize = 9
info.TextXAlignment = Enum.TextXAlignment.Center

-- auto parry loop
local lastParry = 0
RunService.Heartbeat:Connect(function()
    if not CONFIG.Enabled then return end
    if tick() - lastParry < CONFIG.Cooldown then return end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local ball = getBall()
    if not ball then
        statusLbl.Text = "ищу мяч..."
        return
    end
    local hrp = char.HumanoidRootPart
    local dist = (ball.Position - hrp.Position).Magnitude
    local speed = ball.Velocity.Magnitude
    if speed < 20 then return end
    local timeToHit = dist / speed
    local ping = 0
    pcall(function() ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()/1000 end)
    if CONFIG.Prediction then timeToHit = timeToHit - ping end
    local threshold = 0.22 * CONFIG.DistanceMulti
    if timeToHit < threshold and timeToHit > 0 then
        local dirToPlayer = (hrp.Position - ball.Position).Unit
        local ballDir = ball.Velocity.Unit
        local dot = dirToPlayer:Dot(ballDir)
        if dot > 0.1 then
            lastParry = tick()
            fireParry()
            statusLbl.Text = string.format("PARRY! d=%.1f t=%.3f", dist, timeToHit)
            print(string.format("[Parry] d=%.1f v=%.1f t=%.3f", dist, speed, timeToHit))
        end
    elseif CONFIG.SpamEnabled and timeToHit < threshold*CONFIG.SpamMulti and timeToHit>0 then
        if tick() - lastParry > CONFIG.SpamCooldown then
            lastParry = tick()
            fireParry()
        end
    else
        statusLbl.Text = string.format("● ВКЛ d=%.1f t=%.3f", dist, timeToHit)
    end
end)

getgenv().BladeAutoParry = {Config=CONFIG, Fire=fireParry, GetBall=getBall, Remotes=parryRemotes, GUI=gui}
print("[AutoParry GUI] loaded")
