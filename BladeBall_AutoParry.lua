-- Blade Ball FINAL — Rise autoparry + anti-kick + GUI
-- Вставь в Delta: loadstring(readfile("чистый скрипт/BladeBall_AutoParry_FINAL.lua"))()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- загружаем модуль
local AutoParry = loadstring(readfile("чистый скрипт/BladeBall_AutoParry_Rise.lua"))()
-- если readfile не доступен, то как модуль уже в памяти
if not AutoParry then error("AutoParry_Rise.lua не найден") end

-- Анти-кик сразу
local disconnectKick = AutoParry.EnableAntiKick(function(msg)
    warn("[AntiKick] blocked: "..tostring(msg))
    game:GetService("StarterGui"):SetCore("SendNotification", {Title="AntiKick", Text="Kick blocked: "..tostring(msg):sub(1,80), Duration=5})
end)
print("[AntiKick] armed")

-- Авто-поиск Signer (как в host script)
local function findSigner()
    -- Пробуем getgc
    if type(getgc)=="function" then
        for _,v in ipairs(getgc(true)) do
            if type(v)=="table" then
                local ok, rem = pcall(function() return rawget(v, "rem") end)
                if ok and rem and typeof(rem)=="Instance" and rem:IsA("RemoteEvent") then
                    local hash = rawget(v, "signHash")
                    local s1 = rawget(v, "s1")
                    local sgn = rawget(v, "sgn")
                    if type(hash)=="string" and #hash>=30 and type(s1)=="function" then
                        print("[Signer] found via getgc:", rem:GetFullName(), hash:sub(1,8))
                        return v
                    end
                end
            end
        end
    end
    -- Fallback: ищем в ReplicatedStorage Remotes + signer таблица в _G
    if type(getgenv)=="function" then
        local g=getgenv()
        for k,v in pairs(g) do
            if type(v)=="table" and rawget(v,"rem") and rawget(v,"signHash") then
                print("[Signer] found via getgenv."..tostring(k))
                return v
            end
        end
    end
    return nil
end

local signer = findSigner()
if not signer then
    warn("[AutoParry] Signer не найден — попробуй запустить FFJ сначала, или подожди 5с и перезапусти")
    -- попробуем подождать и снова
    task.wait(2)
    signer = findSigner()
end

if signer then
    print("[Signer] OK", signer.rem:GetFullName())
else
    error("Signer не найден — Blade Ball обновил защиту. Скинь вывод getgc в лс")
end

-- Настройки как в FFJ 1.25 / 1.05
local ap = AutoParry.new({
    Signer = signer,
    Enabled = true,
    AutoSpam = true,
    SpamInterval = 0.05,
    ExtraWindow = 0,
    MinDelay = 0.06,
    PerBallDelay = 0.2,
    MaxFiresPerWindow = 7,
    -- CurveValue / ParryPayload / ParryArgs берём из signer если есть
    CurveValue = function() return 0 end,
    ParryPayload = function(curv) 
        -- дефолт как в Rise: payload = curv
        if signer and rawget(signer,"parryPayload") then return signer.parryPayload(curv) end
        return curv
    end,
    ParryArgs = function(payload)
        if signer and rawget(signer,"parryArgs") then return signer.parryArgs(payload) end
        return payload
    end,
})

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name="RiseGUI"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=9999
pcall(function() gui.Parent=LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent=game:GetService("CoreGui") end
local frame=Instance.new("Frame",gui)
frame.Size=UDim2.fromOffset(360,380)
frame.Position=UDim2.fromScale(0.02,0.3)
frame.BackgroundColor3=Color3.fromRGB(14,14,18)
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,14)
local stroke=Instance.new("UIStroke",frame) stroke.Color=Color3.fromRGB(80,255,120) stroke.Thickness=1.2
local title=Instance.new("TextLabel",frame) title.Size=UDim2.new(1,-40,0,28) title.Position=UDim2.fromOffset(14,8) title.BackgroundTransparency=1 title.Text="RISE / AUTO PARRY" title.TextColor3=Color3.fromRGB(80,255,120) title.Font=Enum.Font.GothamBold title.TextSize=12 title.TextXAlignment=Enum.TextXAlignment.Left
local close=Instance.new("TextButton",frame) close.Size=UDim2.fromOffset(26,26) close.Position=UDim2.new(1,-32,0,6) close.Text="x" close.BackgroundColor3=Color3.fromRGB(35,35,40) Instance.new("UICorner",close).CornerRadius=UDim.new(0,8) close.MouseButton1Click:Connect(function() gui:Destroy() ap:Stop() end)
local dragging,dragStart,startPos
frame.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true dragStart=i.Position startPos=frame.Position i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end) end end)
frame.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then local d=i.Position-dragStart frame.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end end)

local function mkToggle(text,y,def,cb)
    local row=Instance.new("Frame",frame) row.Size=UDim2.new(1,-20,0,28) row.Position=UDim2.fromOffset(10,y) row.BackgroundTransparency=1
    local lbl=Instance.new("TextLabel",row) lbl.Size=UDim2.new(1,-56,1,0) lbl.BackgroundTransparency=1 lbl.Text=text lbl.TextColor3=Color3.fromRGB(220,220,220) lbl.Font=Enum.Font.Gotham lbl.TextSize=11 lbl.TextXAlignment=Enum.TextXAlignment.Left
    local btn=Instance.new("TextButton",row) btn.Size=UDim2.fromOffset(50,22) btn.Position=UDim2.new(1,-50,0.5,-11) btn.Text=def and "ON" or "OFF" btn.Font=Enum.Font.GothamBold btn.TextSize=10 btn.TextColor3=def and Color3.fromRGB(14,14,18) or Color3.fromRGB(180,180,180) btn.BackgroundColor3=def and Color3.fromRGB(80,255,120) or Color3.fromRGB(45,45,50) Instance.new("UICorner",btn).CornerRadius=UDim.new(0,8)
    local on=def
    btn.MouseButton1Click:Connect(function() on=not on btn.Text=on and "ON" or "OFF" btn.BackgroundColor3=on and Color3.fromRGB(80,255,120) or Color3.fromRGB(45,45,50) btn.TextColor3=on and Color3.fromRGB(14,14,18) or Color3.fromRGB(180,180,180) cb(on) end)
    return btn
end

mkToggle("Auto Parry", 40, ap.Enabled, function(v) ap.Enabled=v end)
mkToggle("Auto Spam", 72, ap.AutoSpam, function(v) ap:SetSpam(v) end)
mkToggle("Anti-Kick", 104, true, function(v) if v then AutoParry.EnableAntiKick() else disconnectKick() end end)

local status=Instance.new("TextLabel",frame) status.Size=UDim2.new(1,-20,0,18) status.Position=UDim2.fromOffset(10,136) status.BackgroundTransparency=1 status.Text="Signer: "..(signer and signer.rem.Name or "nil") status.TextColor3=Color3.fromRGB(120,255,120) status.Font=Enum.Font.Code status.TextSize=10 status.TextXAlignment=Enum.TextXAlignment.Left

local testBtn=Instance.new("TextButton",frame) testBtn.Size=UDim2.new(1,-20,0,30) testBtn.Position=UDim2.fromOffset(10,160) testBtn.Text="TEST PARRY" testBtn.BackgroundColor3=Color3.fromRGB(80,255,120) testBtn.Font=Enum.Font.GothamBold Instance.new("UICorner",testBtn).CornerRadius=UDim.new(0,10) testBtn.MouseButton1Click:Connect(function() ap:Fire() status.Text="TEST → "..tostring(signer.rem.Name) end)

local spamBtn=Instance.new("TextButton",frame) spamBtn.Size=UDim2.new(1,-20,0,30) spamBtn.Position=UDim2.fromOffset(10,196) spamBtn.Text="TOGGLE SPAM (E)" spamBtn.BackgroundColor3=Color3.fromRGB(45,45,50) spamBtn.TextColor3=Color3.fromRGB(220,220,220) spamBtn.Font=Enum.Font.GothamBold Instance.new("UICorner",spamBtn).CornerRadius=UDim.new(0,10) spamBtn.MouseButton1Click:Connect(function() ap:ToggleSpam() status.Text="Spam: "..tostring(ap.AutoSpam) end)

local info=Instance.new("TextLabel",frame) info.Size=UDim2.new(1,-20,0,40) info.Position=UDim2.fromOffset(10,232) info.BackgroundTransparency=1 info.Text="E — спам вкл/выкл • Fire 7/0.5с • Window speed/12" info.TextColor3=Color3.fromRGB(120,120,130) info.Font=Enum.Font.Gotham info.TextSize=9 info.TextWrapped=true info.TextXAlignment=Enum.TextXAlignment.Center

ap:Start()
print("[Rise] started. E — toggle spam")
