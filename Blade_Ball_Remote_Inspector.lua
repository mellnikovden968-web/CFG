-- Blade Ball Remote Inspector — standalone для Delta (не требует Overdrive H)
-- Логирует все RemoteEvent/RemoteFunction, подсветит Parry
-- Использование: loadstring(game:HttpGet("https://raw.githubusercontent.com/.../Blade_Ball_Remote_Inspector.lua"))() или вставь в Delta

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "BladeBallInspector"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 9999
pcall(function()
    local pg = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then gui.Parent = pg else gui.Parent = game:GetService("CoreGui") end
end)
if not gui.Parent then gui.Parent = game:GetService("CoreGui") end

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(420, 320)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.BackgroundColor3 = Color3.fromRGB(18,18,22)
frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke", frame)
stroke.Color = Color3.fromRGB(80,255,120)
stroke.Thickness = 1.5
stroke.Transparency = 0.3

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, -40, 0, 32)
title.Position = UDim2.fromOffset(14, 8)
title.BackgroundTransparency = 1
title.Text = "BLADE BALL / REMOTE INSPECTOR"
title.TextColor3 = Color3.fromRGB(80,255,120)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 12

local closeBtn = Instance.new("TextButton", frame)
closeBtn.Size = UDim2.fromOffset(26, 26)
closeBtn.Position = UDim2.new(1, -32, 0, 6)
closeBtn.Text = "x"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.fromRGB(200,200,200)
closeBtn.BackgroundColor3 = Color3.fromRGB(35,35,40)
closeBtn.AutoButtonColor = false
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- Drag
local dragging, dragStart, startPos
frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
frame.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local btnClear = Instance.new("TextButton", frame)
btnClear.Size = UDim2.fromOffset(70, 24)
btnClear.Position = UDim2.fromOffset(14, 42)
btnClear.Text = "CLEAR"
btnClear.Font = Enum.Font.GothamBold
btnClear.TextSize = 10
btnClear.TextColor3 = Color3.fromRGB(18,18,22)
btnClear.BackgroundColor3 = Color3.fromRGB(80,255,120)
Instance.new("UICorner", btnClear).CornerRadius = UDim.new(0, 8)

local btnCopy = Instance.new("TextButton", frame)
btnCopy.Size = UDim2.fromOffset(90, 24)
btnCopy.Position = UDim2.fromOffset(92, 42)
btnCopy.Text = "COPY LAST"
btnCopy.Font = Enum.Font.GothamBold
btnCopy.TextSize = 10
btnCopy.TextColor3 = Color3.fromRGB(200,255,210)
btnCopy.BackgroundColor3 = Color3.fromRGB(35,35,40)
Instance.new("UICorner", btnCopy).CornerRadius = UDim.new(0, 8)

local hint = Instance.new("TextLabel", frame)
hint.Size = UDim2.new(1, -20, 0, 16)
hint.Position = UDim2.fromOffset(10, 68)
hint.BackgroundTransparency = 1
hint.Text = "1) Нажми PARRY в игре  2) Смотри сюда — зелёным подсветит удачный Remote"
hint.TextColor3 = Color3.fromRGB(140,140,145)
hint.Font = Enum.Font.Gotham
hint.TextSize = 10
hint.TextXAlignment = Enum.TextXAlignment.Left

local scroll = Instance.new("ScrollingFrame", frame)
scroll.Size = UDim2.new(1, -20, 1, -92)
scroll.Position = UDim2.fromOffset(10, 86)
scroll.BackgroundColor3 = Color3.fromRGB(26,26,30)
scroll.BorderSizePixel = 0
scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.ScrollBarThickness = 4
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 10)
local pad = Instance.new("UIPadding", scroll)
pad.PaddingTop = UDim.new(0,6)
pad.PaddingBottom = UDim.new(0,6)
pad.PaddingLeft = UDim.new(0,6)
pad.PaddingRight = UDim.new(0,6)
local layout = Instance.new("UIListLayout", scroll)
layout.Padding = UDim.new(0,6)
layout.SortOrder = Enum.SortOrder.LayoutOrder

local lastRemotePath = nil
local logCount = 0

local function addLine(text, color, isParry)
    logCount += 1
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -10, 0, 0)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.BackgroundColor3 = isParry and Color3.fromRGB(24, 60, 30) or Color3.fromRGB(32,32,36)
    lbl.BorderSizePixel = 0
    lbl.Text = text
    lbl.TextColor3 = color or Color3.fromRGB(220,220,220)
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Top
    lbl.TextWrapped = true
    lbl.ClipsDescendants = false
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 8)
    local ip = Instance.new("UIPadding", lbl)
    ip.PaddingTop = UDim.new(0,6)
    ip.PaddingBottom = UDim.new(0,6)
    ip.PaddingLeft = UDim.new(0,8)
    ip.PaddingRight = UDim.new(0,8)
    lbl.Parent = scroll
    lbl.LayoutOrder = -logCount
    if isParry then
        local s = Instance.new("UIStroke", lbl)
        s.Color = Color3.fromRGB(80,255,120)
        s.Thickness = 1
    end
    -- держим 80 строк
    if #scroll:GetChildren() > 90 then
        for _,c in ipairs(scroll:GetChildren()) do
            if c:IsA("TextLabel") and c.LayoutOrder > -10 then c:Destroy() break end
        end
    end
end

local function fullName(inst)
    local ok, v = pcall(function() return inst:GetFullName() end)
    return ok and v or inst.Name
end

local function argsToString(...)
    local n = select("#", ...)
    if n == 0 then return "()" end
    local parts = {}
    for i=1,n do
        local v = select(i, ...)
        local t = typeof(v)
        if t == "string" then parts[i] = '"'..v..'"'
        elseif t == "Instance" then parts[i] = fullName(v)
        else parts[i] = tostring(v) end
    end
    return "("..table.concat(parts, ", ")..")"
end

local parryKeywords = {"parry","block","deflect","sword","ability","click","hit"}

local function isLikelyParry(name)
    name = name:lower()
    for _,k in ipairs(parryKeywords) do
        if name:find(k) then return true end
    end
    return false
end

-- Hook outgoing: FireServer / InvokeServer
local function hookRemote(remote)
    if not (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then return end
    -- входящие
    if remote:IsA("RemoteEvent") then
        pcall(function()
            remote.OnClientEvent:Connect(function(...)
                local txt = "[IN] "..fullName(remote).." "..argsToString(...)
                addLine(txt, Color3.fromRGB(120,180,255), false)
            end)
        end)
    end
end

for _,o in ipairs(game:GetDescendants()) do hookRemote(o) end
game.DescendantAdded:Connect(hookRemote)

-- Перехват FireServer / InvokeServer через namecall (Delta поддерживает)
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if (method == "FireServer" or method == "InvokeServer") and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
        local path = fullName(self)
        lastRemotePath = path
        local isParry = isLikelyParry(self.Name) or isLikelyParry(path)
        local col = isParry and Color3.fromRGB(80,255,120) or Color3.fromRGB(255,220,120)
        local tag = isParry and " ★ PARRY?" or ""
        local txt = "["..method..tag.."] "..path.." "..argsToString(...)
        addLine(txt, col, isParry)
        if isParry then
            -- подсказка как вызывать
            addLine("→ Код: game:GetService(\"ReplicatedStorage\")."..path:gsub("^ReplicatedStorage%.","")..":FireServer(...)", Color3.fromRGB(160,255,170), false)
        end
    end
    return oldNamecall(self, ...)
end)

addLine("Инспектор запущен. Нажми PARRY (F / клик) — смотри зелёную строку.", Color3.fromRGB(160,160,165), false)
addLine("Подсказка: если ничего не ловит — Blade Ball прячет Remote, включи executor с hookmetamethod.", Color3.fromRGB(160,160,165), false)

btnClear.MouseButton1Click:Connect(function()
    for _,c in ipairs(scroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
end)

btnCopy.MouseButton1Click:Connect(function()
    if lastRemotePath and setclipboard then
        setclipboard(lastRemotePath)
        addLine("Скопировано: "..lastRemotePath, Color3.fromRGB(80,255,120), false)
    else
        addLine("Нет последнего Remote — сначала нажми Parry", Color3.fromRGB(255,120,120), false)
    end
end)
