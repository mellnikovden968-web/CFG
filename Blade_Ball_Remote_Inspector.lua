-- Blade Ball Remote Inspector V2 — Delta
-- Фикс: запись по кнопке 3 сек + сохранение в файл + фильтр спама + только OUT
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local ROOT = "BladeBall_Inspector"
local SAVE_FILE = ROOT .. "/parry_log.txt"
local SAVE_JSON = ROOT .. "/parry_log.json"

local function ensureFolder(path)
    if type(makefolder) ~= "function" then return false end
    local cur = ""
    for part in path:gmatch("[^/]+") do
        cur = cur == "" and part or cur.."/"..part
        local ok = false
        if type(isfolder) == "function" then pcall(function() ok = isfolder(cur) end) end
        if not ok then pcall(makefolder, cur) end
    end
    return true
end
local function write(path, text)
    if type(writefile) ~= "function" then return false end
    ensureFolder(path:match("^(.*)/[^/]+$") or ROOT)
    return pcall(writefile, path, text)
end
local function append(path, text)
    ensureFolder(path:match("^(.*)/[^/]+$") or ROOT)
    if type(appendfile) == "function" then return pcall(appendfile, path, text) end
    if type(writefile) ~= "function" then return false end
    local old = ""
    if type(isfile)=="function" and type(readfile)=="function" then
        local ex=false pcall(function() ex=isfile(path) end)
        if ex then pcall(function() old=readfile(path) end) end
    end
    return pcall(writefile, path, old..text)
end
ensureFolder(ROOT)

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "BladeBallInspectorV2"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 9999
pcall(function()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    gui.Parent = pg or game:GetService("CoreGui")
end)
if not gui.Parent then gui.Parent = game:GetService("CoreGui") end

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.fromOffset(440, 380)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.AnchorPoint = Vector2.new(0.5,0.5)
frame.BackgroundColor3 = Color3.fromRGB(14,14,18)
frame.BorderSizePixel = 0
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,14)
local stroke = Instance.new("UIStroke", frame)
stroke.Color = Color3.fromRGB(80,255,120)
stroke.Thickness = 1.5

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1,-40,0,28)
title.Position = UDim2.fromOffset(14,8)
title.BackgroundTransparency = 1
title.Text = "BLADE BALL / INSPECTOR V2 — запись по кнопке"
title.TextColor3 = Color3.fromRGB(80,255,120)
title.Font = Enum.Font.GothamBold
title.TextSize = 11
title.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", frame)
closeBtn.Size = UDim2.fromOffset(26,26)
closeBtn.Position = UDim2.new(1,-32,0,6)
closeBtn.Text = "x"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = Color3.fromRGB(200,200,200)
closeBtn.BackgroundColor3 = Color3.fromRGB(35,35,40)
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,8)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

-- buttons row 1
local function mkBtn(text, pos, color, textColor)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.fromOffset(130, 30)
    b.Position = pos
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.TextColor3 = textColor or Color3.fromRGB(14,14,18)
    b.BackgroundColor3 = color
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,10)
    return b
end

local btnRecord = mkBtn("● ЗАПИСЬ PARRY (3с)", UDim2.fromOffset(14,42), Color3.fromRGB(80,255,120))
local btnClear = mkBtn("CLEAR", UDim2.fromOffset(154,42), Color3.fromRGB(45,45,50), Color3.fromRGB(220,220,220))
btnClear.Size = UDim2.fromOffset(70,30)
local btnSave = mkBtn("SAVE", UDim2.fromOffset(232,42), Color3.fromRGB(45,45,50), Color3.fromRGB(220,220,220))
btnSave.Size = UDim2.fromOffset(70,30)
local btnOpen = mkBtn("OPEN FILE", UDim2.fromOffset(310,42), Color3.fromRGB(45,45,50), Color3.fromRGB(220,220,220))
btnOpen.Size = UDim2.fromOffset(86,30)

local statusLbl = Instance.new("TextLabel", frame)
statusLbl.Size = UDim2.new(1,-20,0,18)
statusLbl.Position = UDim2.fromOffset(10,76)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "Готов. Нажми ЗАПИСЬ → сразу жми PARRY (F) в игре"
statusLbl.TextColor3 = Color3.fromRGB(180,180,185)
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextSize = 11
statusLbl.TextXAlignment = Enum.TextXAlignment.Left

local infoLbl = Instance.new("TextLabel", frame)
infoLbl.Size = UDim2.new(1,-20,0,14)
infoLbl.Position = UDim2.fromOffset(10,94)
infoLbl.BackgroundTransparency = 1
infoLbl.Text = "Файл: "..SAVE_JSON.."  (показывает только OUT — синий спам скрыт)"
infoLbl.TextColor3 = Color3.fromRGB(120,120,130)
infoLbl.Font = Enum.Font.Gotham
infoLbl.TextSize = 9
infoLbl.TextXAlignment = Enum.TextXAlignment.Left

-- drag
local dragging, dragStart, startPos
frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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

local scroll = Instance.new("ScrollingFrame", frame)
scroll.Size = UDim2.new(1,-20,1,-118)
scroll.Position = UDim2.fromOffset(10,112)
scroll.BackgroundColor3 = Color3.fromRGB(22,22,26)
scroll.BorderSizePixel=0
scroll.CanvasSize=UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
scroll.ScrollBarThickness=4
Instance.new("UICorner", scroll).CornerRadius=UDim.new(0,10)
local pad=Instance.new("UIPadding", scroll)
pad.PaddingTop=UDim.new(0,6) pad.PaddingBottom=UDim.new(0,6) pad.PaddingLeft=UDim.new(0,6) pad.PaddingRight=UDim.new(0,6)
local layout=Instance.new("UIListLayout", scroll)
layout.Padding=UDim.new(0,6)

local isRecording = false
local recordBuffer = {}
local lastOutPath = nil

local function addLine(text, color, isParry)
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-10,0,0)
    lbl.AutomaticSize=Enum.AutomaticSize.Y
    lbl.BackgroundColor3=isParry and Color3.fromRGB(24,60,30) or Color3.fromRGB(32,32,36)
    lbl.BorderSizePixel=0
    lbl.Text=text
    lbl.TextColor3=color
    lbl.Font=Enum.Font.Code
    lbl.TextSize=11
    lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.TextWrapped=true
    Instance.new("UICorner",lbl).CornerRadius=UDim.new(0,8)
    local ip=Instance.new("UIPadding",lbl)
    ip.PaddingTop=UDim.new(0,6) ip.PaddingBottom=UDim.new(0,6) ip.PaddingLeft=UDim.new(0,8) ip.PaddingRight=UDim.new(0,8)
    lbl.Parent=scroll
    if isParry then
        local s=Instance.new("UIStroke",lbl) s.Color=Color3.fromRGB(80,255,120) s.Thickness=1
    end
    if #scroll:GetChildren()>80 then
        for _,c in ipairs(scroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() break end end
    end
end

local function fullName(inst)
    local ok,v=pcall(function() return inst:GetFullName() end)
    return ok and v or inst.Name
end
local function argsToStr(...)
    local n=select("#",...)
    if n==0 then return "()" end
    local parts={}
    for i=1,n do
        local v=select(i,...)
        local t=typeof(v)
        if t=="string" then parts[i]='"'..v..'"'
        elseif t=="Instance" then parts[i]=fullName(v)
        else parts[i]=tostring(v) end
    end
    return "("..table.concat(parts,", ")..")"
end

local parryKeys={"parry","block","deflect","sword","ability","click","hit","remote"}
local function isParryLike(name)
    name=name:lower()
    for _,k in ipairs(parryKeys) do if name:find(k) then return true end end
    return false
end

-- hook outgoing only — входящие скрываем чтобы не спамило
local oldNamecall
local function hook()
    local ok, err = pcall(function()
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if (method=="FireServer" or method=="InvokeServer") and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
                local path = fullName(self)
                local isParry = isParryLike(self.Name) or isParryLike(path)
                -- логируем всегда в файл если запись, на экран только если запись или parry
                local txt = "["..method.."] "..path.." "..argsToStr(...)
                lastOutPath = path
                -- пишем в буфер записи
                if isRecording then
                    table.insert(recordBuffer, {time=os.date("%H:%M:%S"), method=method, path=path, args=argsToStr(...)})
                    -- ещё в файл сразу
                    pcall(function()
                        append(SAVE_JSON, game:GetService("HttpService"):JSONEncode({method=method, path=path, args={...}}).."\n")
                        append(SAVE_FILE, txt.."\n")
                    end)
                end
                -- на экран: показываем только если запись идёт или это похоже на parry, иначе скрываем спам
                if isRecording or isParry then
                    local col = isParry and Color3.fromRGB(80,255,120) or Color3.fromRGB(255,220,120)
                    local tag = isParry and " ★ PARRY?" or (isRecording and " ● REC" or "")
                    addLine("["..method..tag.."] "..path.." "..argsToStr(...), col, isParry)
                    if isParry then
                        addLine("→ Код: game:GetService(\"ReplicatedStorage\"):FindFirstChild(\""..self.Name.."\",true):FireServer(...)", Color3.fromRGB(160,255,170), false)
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
    end)
    if not ok then
        addLine("hookmetamethod не сработал: "..tostring(err).." — пробую прямой хук", Color3.fromRGB(255,120,120), false)
        -- fallback: хук самих FireServer
        for _,r in ipairs(game:GetDescendants()) do
            if r:IsA("RemoteEvent") then
                local old; old = hookfunction(r.FireServer, function(self,...)
                    local path=fullName(self)
                    addLine("[FireServer] "..path.." "..argsToStr(...), Color3.fromRGB(255,220,120), false)
                    return old(self,...)
                end)
            end
        end
    end
end
hook()

-- также слушаем ReplicatedStorage на новые Remote (Blade Ball их создаёт динамически)
game.DescendantAdded:Connect(function(o)
    if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
        -- ничего, namecall уже ловит, но можем подсветить что появился
        -- addLine("[NEW] "..fullName(o), Color3.fromRGB(120,180,255), false)
    end
end)

local function startRecord()
    isRecording = true
    recordBuffer = {}
    statusLbl.Text = "● ЗАПИСЬ 3с — ЖМИ PARRY СЕЙЧАС!"
    statusLbl.TextColor3 = Color3.fromRGB(255,90,90)
    btnRecord.BackgroundColor3 = Color3.fromRGB(255,90,90)
    btnRecord.Text = "● ИДЁТ ЗАПИСЬ..."
    -- очистим файл
    write(SAVE_FILE, "-- Blade Ball parry log "..os.date().."\n")
    write(SAVE_JSON, "")
    addLine("— ЗАПИСЬ НАЧАТА (3 сек) — нажми F / клик для парирования!", Color3.fromRGB(255,90,90), true)
    task.delay(3, function()
        isRecording = false
        statusLbl.Text = "Запись окончена. Сохранено "..#recordBuffer.." событий в "..SAVE_JSON
        statusLbl.TextColor3 = Color3.fromRGB(80,255,120)
        btnRecord.BackgroundColor3 = Color3.fromRGB(80,255,120)
        btnRecord.Text = "● ЗАПИСЬ PARRY (3с)"
        if #recordBuffer==0 then
            addLine("Ничего не поймано — попробуй ещё раз, жми F быстрее. Может Blade Ball использует VirtualInput, а не Remote", Color3.fromRGB(255,180,120), false)
        else
            addLine("— СОХРАНЕНО "..#recordBuffer.." в "..SAVE_JSON.." — нажми OPEN FILE чтобы посмотреть", Color3.fromRGB(80,255,120), true)
        end
    end)
end

btnRecord.MouseButton1Click:Connect(startRecord)
btnClear.MouseButton1Click:Connect(function()
    for _,c in ipairs(scroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
end)
btnSave.MouseButton1Click:Connect(function()
    if #recordBuffer==0 then
        addLine("Буфер пуст — сначала ЗАПИСЬ", Color3.fromRGB(255,120,120), false)
        return
    end
    local txt = "-- PARRY LOG "..os.date().."\n"
    for i,v in ipairs(recordBuffer) do txt = txt .. i..". "..v.method.." "..v.path.." "..v.args.."\n" end
    write(SAVE_FILE, txt)
    statusLbl.Text = "Сохранено в "..SAVE_FILE
    addLine("Файл сохранён: "..SAVE_FILE.." и "..SAVE_JSON, Color3.fromRGB(80,255,120), false)
end)
btnOpen.MouseButton1Click:Connect(function()
    if type(readfile)=="function" and type(isfile)=="function" then
        local ok = false pcall(function() ok=isfile(SAVE_FILE) end)
        if ok then
            local content="" pcall(function() content=readfile(SAVE_FILE) end)
            addLine("— ФАЙЛ "..SAVE_FILE.." —\n"..content:sub(1,2000), Color3.fromRGB(160,200,255), false)
        else
            addLine("Файла ещё нет — сделай ЗАПИСЬ", Color3.fromRGB(255,120,120), false)
        end
    else
        addLine("Executor не поддерживает readfile — смотри Delta / Workspace / "..ROOT, Color3.fromRGB(255,180,120), false)
    end
end)

addLine("V2 готов. Инструкция: 1) Жми ЗАПИСЬ 2) Сразу жми PARRY в игре 3) Смотри зелёную строку + файл", Color3.fromRGB(180,180,185), false)
