-- Blade Ball Remote Inspector V2.1 — FIX hook nil + FFJ config reader
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ROOT = "BladeBall_Inspector"
local SAVE_FILE = ROOT .. "/parry_log.txt"
local SAVE_JSON = ROOT .. "/parry_log.json"

local function ensureFolder(path)
    if type(makefolder) ~= "function" then return end
    local cur=""
    for part in path:gmatch("[^/]+") do
        cur = cur=="" and part or cur.."/"..part
        local ok=false
        if type(isfolder)=="function" then pcall(function() ok=isfolder(cur) end) end
        if not ok then pcall(makefolder, cur) end
    end
end
local function write(path, text)
    if type(writefile)~="function" then return end
    ensureFolder(path:match("^(.*)/[^/]+$") or ROOT)
    pcall(writefile, path, text)
end
local function append(path, text)
    ensureFolder(path:match("^(.*)/[^/]+$") or ROOT)
    if type(appendfile)=="function" then return pcall(appendfile, path, text) end
    if type(writefile)~="function" then return end
    local old=""
    if type(isfile)=="function" and type(readfile)=="function" then
        local ex=false pcall(function() ex=isfile(path) end)
        if ex then pcall(function() old=readfile(path) end) end
    end
    pcall(writefile, path, old..text)
end
ensureFolder(ROOT)

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "BladeBallInspectorV21"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=9999
pcall(function()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    gui.Parent = pg or game:GetService("CoreGui")
end)
if not gui.Parent then gui.Parent = game:GetService("CoreGui") end

local frame = Instance.new("Frame", gui)
frame.Size=UDim2.fromOffset(440,400)
frame.Position=UDim2.fromScale(0.5,0.5)
frame.AnchorPoint=Vector2.new(0.5,0.5)
frame.BackgroundColor3=Color3.fromRGB(14,14,18)
frame.BorderSizePixel=0
Instance.new("UICorner", frame).CornerRadius=UDim.new(0,14)
local stroke=Instance.new("UIStroke", frame)
stroke.Color=Color3.fromRGB(80,255,120)
stroke.Thickness=1.5

local title=Instance.new("TextLabel", frame)
title.Size=UDim2.new(1,-40,0,28)
title.Position=UDim2.fromOffset(14,8)
title.BackgroundTransparency=1
title.Text="BLADE BALL / INSPECTOR V2.1 — FIX"
title.TextColor3=Color3.fromRGB(80,255,120)
title.Font=Enum.Font.GothamBold
title.TextSize=11
title.TextXAlignment=Enum.TextXAlignment.Left

local closeBtn=Instance.new("TextButton", frame)
closeBtn.Size=UDim2.fromOffset(26,26)
closeBtn.Position=UDim2.new(1,-32,0,6)
closeBtn.Text="x"
closeBtn.Font=Enum.Font.GothamBold
closeBtn.TextSize=14
closeBtn.TextColor3=Color3.fromRGB(200,200,200)
closeBtn.BackgroundColor3=Color3.fromRGB(35,35,40)
Instance.new("UICorner", closeBtn).CornerRadius=UDim.new(0,8)
closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)

local function mkBtn(text, pos, color, tc)
    local b=Instance.new("TextButton", frame)
    b.Size=UDim2.fromOffset(132,30)
    b.Position=pos
    b.Text=text
    b.Font=Enum.Font.GothamBold
    b.TextSize=11
    b.TextColor3=tc or Color3.fromRGB(14,14,18)
    b.BackgroundColor3=color
    Instance.new("UICorner", b).CornerRadius=UDim.new(0,10)
    return b
end
local btnRecord=mkBtn("● ЗАПИСЬ 3с", UDim2.fromOffset(14,42), Color3.fromRGB(80,255,120))
local btnClear=mkBtn("CLEAR", UDim2.fromOffset(154,42), Color3.fromRGB(45,45,50), Color3.fromRGB(220,220,220))
btnClear.Size=UDim2.fromOffset(70,30)
local btnSave=mkBtn("SAVE", UDim2.fromOffset(232,42), Color3.fromRGB(45,45,50), Color3.fromRGB(220,220,220))
btnSave.Size=UDim2.fromOffset(70,30)
local btnOpen=mkBtn("OPEN", UDim2.fromOffset(310,42), Color3.fromRGB(45,45,50), Color3.fromRGB(220,220,220))
btnOpen.Size=UDim2.fromOffset(70,30)

local statusLbl=Instance.new("TextLabel", frame)
statusLbl.Size=UDim2.new(1,-20,0,18)
statusLbl.Position=UDim2.fromOffset(10,76)
statusLbl.BackgroundTransparency=1
statusLbl.Text="Готов. Нажми ЗАПИСЬ → жми F"
statusLbl.TextColor3=Color3.fromRGB(180,180,185)
statusLbl.Font=Enum.Font.Gotham
statusLbl.TextSize=11
statusLbl.TextXAlignment=Enum.TextXAlignment.Left

local infoLbl=Instance.new("TextLabel", frame)
infoLbl.Size=UDim2.new(1,-20,0,28)
infoLbl.Position=UDim2.fromOffset(10,94)
infoLbl.BackgroundTransparency=1
infoLbl.Text="Файл: BladeBall_Inspector/parry_log.txt | Если зелёной нет — Blade Ball использует защиту"
infoLbl.TextColor3=Color3.fromRGB(120,120,130)
infoLbl.Font=Enum.Font.Gotham
infoLbl.TextSize=9
infoLbl.TextXAlignment=Enum.TextXAlignment.Left
infoLbl.TextWrapped=true

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

local scroll=Instance.new("ScrollingFrame", frame)
scroll.Size=UDim2.new(1,-20,1,-132)
scroll.Position=UDim2.fromOffset(10,126)
scroll.BackgroundColor3=Color3.fromRGB(22,22,26)
scroll.BorderSizePixel=0
scroll.CanvasSize=UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
scroll.ScrollBarThickness=4
Instance.new("UICorner", scroll).CornerRadius=UDim.new(0,10)
local pad=Instance.new("UIPadding", scroll)
pad.PaddingTop=UDim.new(0,6) pad.PaddingBottom=UDim.new(0,6) pad.PaddingLeft=UDim.new(0,6) pad.PaddingRight=UDim.new(0,6)
local layout=Instance.new("UIListLayout", scroll)
layout.Padding=UDim.new(0,6)

local isRecording=false
local recordBuffer={}
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
    if isParry then local s=Instance.new("UIStroke",lbl) s.Color=Color3.fromRGB(80,255,120) s.Thickness=1 end
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
local parryKeys={"parry","block","deflect","sword","ability","click","hit"}
local function isParryLike(name)
    name=name:lower()
    for _,k in ipairs(parryKeys) do if name:find(k) then return true end end
    return false
end

-- SAFE HOOK — проверяем наличие hookmetamethod
local hookOk = false
local oldNamecall
if type(hookmetamethod)=="function" and type(getnamecallmethod)=="function" then
    local ok, err = pcall(function()
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if (method=="FireServer" or method=="InvokeServer") and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
                local path = fullName(self)
                local isParry = isParryLike(self.Name) or isParryLike(path)
                local txt = "["..method.."] "..path.." "..argsToStr(...)
                if isRecording then
                    table.insert(recordBuffer, {method=method, path=path, args=argsToStr(...)})
                    pcall(function() append(SAVE_JSON, game:GetService("HttpService"):JSONEncode({method=method, path=path, args={...}}).."\n") end)
                    pcall(function() append(SAVE_FILE, txt.."\n") end)
                end
                if isRecording or isParry then
                    local col = isParry and Color3.fromRGB(80,255,120) or Color3.fromRGB(255,220,120)
                    local tag = isParry and " ★ PARRY?" or " ● REC"
                    addLine("["..method..tag.."] "..path.." "..argsToStr(...), col, isParry)
                    if isParry then
                        addLine("→ Код: :FireServer(...)", Color3.fromRGB(160,255,170), false)
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
    end)
    hookOk = ok
    if not ok then
        addLine("hookmetamethod ошибка: "..tostring(err).." — перехожу на прямой хук", Color3.fromRGB(255,120,120), false)
    else
        addLine("hookmetamethod OK — ловлю FireServer", Color3.fromRGB(80,255,120), false)
    end
else
    addLine("hookmetamethod нет в этом Delta — использую прямой хук FireServer", Color3.fromRGB(255,180,120), false)
end

-- Fallback: прямой хук RemoteEvent.FireServer если metamethod нет
if not hookOk then
    for _,r in ipairs(game:GetDescendants()) do
        if r:IsA("RemoteEvent") and type(hookfunction)=="function" then
            pcall(function()
                local old
                old = hookfunction(r.FireServer, function(self, ...)
                    local path=fullName(self)
                    local isParry=isParryLike(self.Name)
                    local txt="[FireServer] "..path.." "..argsToStr(...)
                    if isRecording then
                        table.insert(recordBuffer, {method="FireServer", path=path, args=argsToStr(...)})
                        pcall(function() append(SAVE_FILE, txt.."\n") end)
                    end
                    if isRecording or isParry then
                        addLine(txt, isParry and Color3.fromRGB(80,255,120) or Color3.fromRGB(255,220,120), isParry)
                    end
                    return old(self, ...)
                end)
            end)
        end
    end
    -- слушаем новые
    game.DescendantAdded:Connect(function(o)
        if o:IsA("RemoteEvent") and type(hookfunction)=="function" then
            pcall(function()
                local old
                old = hookfunction(o.FireServer, function(self, ...)
                    local path=fullName(self)
                    addLine("[FireServer] "..path.." "..argsToStr(...), Color3.fromRGB(255,220,120), false)
                    return old(self, ...)
                end)
            end)
        end
    end)
end

-- Покажем найденные Remotes (без спама)
local found={}
for _,o in ipairs(game:GetDescendants()) do
    if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
        if isParryLike(o.Name) then
            table.insert(found, fullName(o))
        end
    end
end
if #found>0 then
    addLine("Найдены похожие на Parry: "..table.concat(found, ", "), Color3.fromRGB(80,255,120), true)
else
    addLine("Похожих на Parry не нашёл — жми ЗАПИСЬ и проверь", Color3.fromRGB(180,180,185), false)
end

-- Покажем твой FFJ конфиг если есть
if type(isfile)=="function" and type(readfile)=="function" then
    pcall(function()
        if isfile("FFJBladeBallV3.json") then
            local j=readfile("FFJBladeBallV3.json")
            addLine("Нашёл FFJBladeBallV3.json: "..j:sub(1,300), Color3.fromRGB(120,180,255), false)
        end
        if isfile("BladeBall_Inspector/parry_log.txt") then
            addLine("Старый лог есть — нажми OPEN", Color3.fromRGB(120,180,255), false)
        end
    end)
end

local function startRecord()
    isRecording=true
    recordBuffer={}
    statusLbl.Text="● ЗАПИСЬ 3с — ЖМИ F СЕЙЧАС!"
    statusLbl.TextColor3=Color3.fromRGB(255,90,90)
    btnRecord.BackgroundColor3=Color3.fromRGB(255,90,90)
    btnRecord.Text="● ИДЁТ..."
    write(SAVE_FILE, "-- Blade Ball log "..os.date().."\n")
    write(SAVE_JSON, "")
    addLine("— ЗАПИСЬ 3 сек — жми PARRY!", Color3.fromRGB(255,90,90), true)
    task.delay(3, function()
        isRecording=false
        statusLbl.Text="Готово: "..#recordBuffer.." событий → "..SAVE_JSON
        statusLbl.TextColor3=Color3.fromRGB(80,255,120)
        btnRecord.BackgroundColor3=Color3.fromRGB(80,255,120)
        btnRecord.Text="● ЗАПИСЬ 3с"
        if #recordBuffer==0 then
            addLine("0 событий — попробуй ещё раз, жми F в эти 3с. Если опять 0 — Blade Ball защита, делаем через мяч", Color3.fromRGB(255,180,120), false)
        else
            addLine("Сохранено "..#recordBuffer.." — жми OPEN или смотри файл", Color3.fromRGB(80,255,120), true)
        end
    end)
end
btnRecord.MouseButton1Click:Connect(startRecord)
btnClear.MouseButton1Click:Connect(function()
    for _,c in ipairs(scroll:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
end)
btnSave.MouseButton1Click:Connect(function()
    if #recordBuffer==0 then addLine("Буфер пуст — сначала ЗАПИСЬ", Color3.fromRGB(255,120,120), false) return end
    local txt="-- LOG "..os.date().."\n"
    for i,v in ipairs(recordBuffer) do txt=txt..i..". "..v.method.." "..v.path.." "..v.args.."\n" end
    write(SAVE_FILE, txt)
    addLine("Сохранено: "..SAVE_FILE, Color3.fromRGB(80,255,120), false)
end)
btnOpen.MouseButton1Click:Connect(function()
    if type(readfile)=="function" then
        local ok=false pcall(function() ok=isfile(SAVE_FILE) end)
        if ok then
            local c="" pcall(function() c=readfile(SAVE_FILE) end)
            addLine("— ФАЙЛ —\n"..c:sub(1,2500), Color3.fromRGB(160,200,255), false)
        else addLine("Файла нет — сделай ЗАПИСЬ", Color3.fromRGB(255,120,120), false) end
    else addLine("Нет readfile — смотри Workspace/BladeBall_Inspector", Color3.fromRGB(255,180,120), false) end
end)

addLine("V2.1 готов. Если Delta старая — работает без hookmetamethod", Color3.fromRGB(180,180,185), false)
