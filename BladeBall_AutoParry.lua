-- Blade Ball FINAL — Rise autoparry + anti-kick + GUI
-- Вставь в Delta: loadstring(readfile("чистый скрипт/BladeBall_AutoParry_FINAL.lua"))()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- загружаем модуль
local AutoParry = (function()
-- autoparry.lua | deobfuscated from stage_5.lua (Rise / Blade Ball)
-- Connect-ready module: require() it from your script, then :Start()
-- Exposes (signed remote fire + target/whitelist trigger + distance window)
-- AntiKick (namecall hook that swallows :Kick on LocalPlayer)
-- Source notes (deobf)/fireSpamParry -> rem:FireServer(signHash, signKey, s1(signKey), parryArgs(parryPayload(crv)))
-- signer injected via rawget table: signHolder/signKey/sgn/s1/signHash/rem/byname(name). trigger: ball target attr + CollisionWhitelist.
-- window: dist <= parryWindow(speed), far reject dist > window*2.5, per-ball 0.2s + global 0.06s throttle, max 7 fires / 0.5s.
-- antikick [123]: guarded once-flag closure calling LocalPlayer:Kick(msg) x9 loop. No __namecall guard in source, so we add one.

local AutoParry = {}
AutoParry.__index = AutoParry

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer



local function defaultParryWindow(speed)
	-- deobf of parryWindow usage: window grows with speed; source clamps via math.clamp elsewhere.
	-- Tuned so 100 speed ~= 8 studs, 600 speed ~= 50 studs, never below 6.
	return math.clamp(speed / 12, 6, 60)
end

function AutoParry.new(optsOptions?)
	local self = setmetatable({}, AutoParry)
	opts = opts or ({})
	self.Enabled = if (opts).Enabled == nil then true else (opts).Enabled
	self.Signer = (opts).Signer
	self.ParryPayload = (opts).ParryPayload
	self.ParryArgs = (opts).ParryArgs
	self.ParryFallback = (opts).ParryFallback
	self.AnyParry = (opts).AnyParry or function() return true end
	self.IsAlive = (opts).IsAlive or function()
		local c = LocalPlayer.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		return h ~= nil and h.Health > 0
	end
	self.KeyParry = (opts).KeyParry
	self.CurveValue = (opts).CurveValue or function() return 0 end
	self.MaxFires = (opts).MaxFiresPerWindow or 7
	self.ExtraWindow = (opts).ExtraWindow or 0
	self.MinDelay = (opts).MinDelay or 0.06
	self.PerBallDelay = (opts).PerBallDelay or 0.2
	self.ParryWindowFn = (opts).ParryWindow or defaultParryWindow
	self.GetBallOverride = (opts).GetBall
	-- AutoSpam (deobf: autospam flag + spamTick caller [13993], manspam E-toggle [5958], gate [14246]):
	-- source spamTick body is VM-buried, honest shape = repeat Fire() on a tight loop
	-- while the spam flag is on. Same signed FireServer path, same 7-per-0.5s cap.
	self.AutoSpam = (opts).AutoSpam or false
	self.SpamInterval = (opts).SpamInterval or 0.05
	self.ManualSpamKey = (opts).ManualSpamKey -- Enum.KeyCode, default E like source
	self._spamOn = false
	self._spamThread = nil
	self._fires = 0
	self._lastFire = 0
	self._ballState = {}, parried } }
	self._conns = {}
	self._running = false
	return (self)
end

function AutoParry.SetSigner(self, signer)
	-- signer shape (from source): { rem, sgn: fn, s1: fn, signHolder: {}, signHash(36), signKey: fn->string, byname: fn, ensure: fn? }
	self.Signer = signer
end

function AutoParry._decFire(self)
	self._fires = math.max(0, self._fires - 1)
end

-- Real extracted fire path (deobfuscated fireParry, [14361]):
-- if keyparry -> keyparry()
-- elseif rem+sgn+holder+hash -> rem:FireServer(signHash, signKey(), s1(signKey()), parryArgs(parryPayload(crv)))
-- else -> ensure(); parryfallback(); return false
-- throttle: max 7 fires per 0.5s sliding window
function AutoParry.Fire(self)
	if not (self.AnyParry)() then return false end
	if not (self.IsAlive)() then return false end
	if self.KeyParry then
		(self.KeyParry)()
	elseif self.Signer and (self.Signer).rem and (self.Signer).sgn
		and (self.Signer).signHolder and (self.Signer).signHash then
		local s = self.Signer
		if not self.ParryPayload or not self.ParryArgs then
			if s.ensure then s.ensure() end
			if self.ParryFallback then (self.ParryFallback)() end
			return false
		end
		local payload = (self.ParryPayload)((self.CurveValue)())
		local key = (s.signKey)()
		local sig = key and (s.s1)(key)
		if not sig then
			if self.ParryFallback then (self.ParryFallback)() end
			return false
		end
		(s.rem)(s.signHash, key, sig, (self.ParryArgs)(payload));
	else
		local s = (self.Signer)
		if s and s.ensure then s.ensure() end
		if self.ParryFallback then (self.ParryFallback)() end
		return false
	end
	if self._fires >= self.MaxFires then return false end
	self._fires += 1
	task.delay(0.5, function() self:_decFire() end)
	return true
end

-- Spam variant (deobfuscated fireSpamParry, [12992]) fire, no sessparry counter.
function AutoParry.FireSpam(self)
	return (self)()
end

local function ballSpeed(ball)
	local z = ball:FindFirstChild("zoomies")
	if z and z:IsA("VectorVelocity") then return z.VectorVelocity.Magnitude end
	local a = ball:GetAttribute("Velocity")
	if typeof(a) == "Vector3" then return (a).Magnitude end
	local b = ball:FindFirstChild("Body")
	if b and b:IsA("BasePart") then return b.AssemblyLinearVelocity.Magnitude end
	if ball:IsA("BasePart") then return ball.AssemblyLinearVelocity.Magnitude end
	return 0
end

local function ballPos(ball)?
	if ball:IsA("BasePart") then return ball.Position end
	local b = ball:FindFirstChild("Body")
	if b and b:IsA("BasePart") then return b.Position end
	return nil
end

local function ballTarget(ball)?
	local t = ball:GetAttribute("target")
	if typeof(t) == "string" then return t end
	return nil
end

function AutoParry._pickBall(self)?
	if self.GetBallOverride then return (self.GetBallOverride)() end
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local folder = workspace:FindFirstChild("Balls")
	if not folder then return nil end
	local best? = nil
	local bestD = math.huge
	for _, b in ipairs(folder:GetChildren()) do
		if b:IsA("BasePart") and b.Parent ~= nil then
			local p = ballPos(b)
			if p then
				local d = ((hrp).Position - p).Magnitude
				if d < bestD then bestD = d; best = b end
			end
		end
	end
	return best
end

function AutoParry._state(self, ball)
	local st = self._ballState[ball]
	if not st then
		st = { lastParry = 0, parried = false }
		self._ballState[ball] = st
	end
	return st
end

-- Real extracted trigger (deobfuscated [8123] autoparry loop):
-- hook per-ball: target attr change resets parried; whitelist change resets parried
-- only when target == LocalPlayer.Name and not parried:
-- dist = |hrp - ball|, window = parryWindow(speed)
-- reject if dist > window*2.5; fire if dist <= window, per-ball 0.2s, global 0.06s
function AutoParry._tryBall(self, ball)
	if not self.Enabled then return end
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local pos = ballPos(ball)
	if not pos then return end
	if ballTarget(ball) ~= LocalPlayer.Name then return end
	local st = self:_state(ball)
	if st.parried then return end
	local speed = ballSpeed(ball)
	local now = os.clock()
	if now - st.lastParry <= self.PerBallDelay then return end
	if now - self._lastFire <= self.MinDelay then return end
	local window = (self.ParryWindowFn)(speed) + self.ExtraWindow
	local dist = ((hrp).Position - pos).Magnitude
	if dist > window * 2.5 then return end
	if dist <= window then
		if (self)() then
			self._lastFire = now
			st.lastParry = now
			st.parried = true
			task.delay(0.6, function() st.parried = false end)
		end
	end
end

function AutoParry._hookBall(self, ball)
	if self._ballState[ball] and (self._ballState[ball]).hooked then return end
	local st = self:_state(ball)
	if (st).hooked then return end
	(st).hooked = true
	local conns = {}
	conns[#conns + 1] = ball:GetAttributeChangedSignal("target")(function()
		st.parried = false
		self:_tryBall(ball)
	end)
	local function hookWL(wl?)
		if wl and wl:IsA("ObjectValue") then
			conns[#conns + 1] = (wl).Changed:Connect(function()
				st.parried = false
				self:_tryBall(ball)
			end)
		end
	end
	hookWL(ball:FindFirstChild("CollisionWhitelist"))
	conns[#conns + 1] = ball.ChildAdded:Connect(function(c)
		if c.Name == "CollisionWhitelist" then hookWL(c); self:_tryBall(ball) end
	end)
	conns[#conns + 1] = ball.Destroying:Once(function()
		for _, c in ipairs(conns) do c:Disconnect() end
		self._ballState[ball] = nil
	end)
	(st).conns = conns
end

function AutoParry.Start(self)
	if self._running then return end
	self._running = true
	-- heartbeat poll (source runs the [8123] body on a loop; Heartbeat kept as the poll clock)
	self._conns[#self._conns + 1] = RunService.Heartbeat:Connect(function()
		if not self.Enabled then return end
		local folder = workspace:FindFirstChild("Balls")
		if folder then
			for _, b in ipairs(folder:GetChildren()) do
				if b:IsA("BasePart") then
					self:_hookBall(b)
					self:_tryBall(b)
				end
			end
		end
		local tb = workspace:FindFirstChild("TrainingBalls")
		if tb then
			for _, b in ipairs(tb:GetChildren()) do
				if b:IsA("BasePart") then
					self:_hookBall(b)
					self:_tryBall(b)
				end
			end
		end
	end)
	-- manspam E-toggle (deobf [5958]) flips manual spam loop on/off
	local uis = game:GetService("UserInputService")
	local key = self.ManualSpamKey or Enum.KeyCode.E
	self._conns[#self._conns + 1] = uis.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == key then
			(self)()
		end
	end)
	if self.AutoSpam then
		(self)()
	end
end

function AutoParry.Stop(self)
	self._running = false
	(self)()
	for _, c in ipairs(self._conns) do c:Disconnect() end
	table.clear(self._conns)
end

-- AutoSpam: tight repeat-Fire loop over the same signed path.
-- Mirrors source: autospam flag drives spamTick [13993], E toggles manspam [5958],
-- anyparry gate [14246] stays inside Fire(). The 7-per-0.5s cap inside Fire() is the limiter.
function AutoParry.SetSpam(self, on)
	self.AutoSpam = on and true or false
	if on then
		(self)()
	else
		(self)()
	end
end

function AutoParry.StartSpam(self)
	if self._spamOn then return end
	self._spamOn = true
	self._spamThread = task.spawn(function()
		while self._spamOn do
			if self.Enabled and self.AutoSpam then
				(self)()
			end
			task.wait(self.SpamInterval)
		end
	end)
end

function AutoParry.StopSpam(self)
	self._spamOn = false
end

function AutoParry.ToggleSpam(self)
	(self)(not self.AutoSpam)
	return self.AutoSpam
end

-- Real extracted anti-kick (deobfuscated [123]):
-- source: once-flag closure -> LocalPlayer:Kick(msg); then 8 more :Kick in task.spawn loop.
-- AntiKick here hooks __namecall and swallows any :Kick aimed at LocalPlayer BEFORE it lands.
-- Returns the hook connection handle + disconnect fn. Safe to call once.
local _antiKickHook = nil
local _antiKickFired = false

function AutoParry.EnableAntiKick(onKickBlocked: ((msg?) -> ())?): () -> ()
	if _antiKickHook then
		return function() end -- already armed
	end
	local mt = getrawmetatable(game)
	local oldNC = mt.__namecall
	setreadonly(mt, false)
	_antiKickHook = newcclosure(function(self, ...)
		local method = getnamecallmethod()
		if method == "Kick" then
			local args = table.pack(...)
			-- only swallow kicks aimed at us (LocalPlayer or its Character)
			if self == LocalPlayer or (LocalPlayer.Character and self == LocalPlayer.Character) then
				_antiKickFired = true -- mirrors source once-flag i[1][7][i[1][6]]
				if onKickBlocked then
					task.spawn(onKickBlocked, if args.n > 0 then tostring(args[1]) else nil)
				end
				return nil -- swallow all 9 kicks from the [123] loop
			end
		end
		return oldNC(self, ...)
	end)
	mt.__namecall = _antiKickHook
	setreadonly(mt, true)
	return function()
		if _antiKickHook then
			local m2 = getrawmetatable(game)
			setreadonly(m2, false)
			m2.__namecall = oldNC
			setreadonly(m2, true)
			_antiKickHook = nil
		end
	end
end

function AutoParry.WasKickBlocked()
	return _antiKickFired
end

return AutoParry

return AutoParry
end)()
-- если readfile не доступен, то как модуль уже в памяти
if not AutoParry then error("AutoParry_Rise.lua не найден") end

-- Анти-кик сразу
local disconnectKick = AutoParry.EnableAntiKick(function(msg)
 warn("[AntiKick] blocked: "..tostring(msg))
 game:GetService("StarterGui")("SendNotification", {Title="AntiKick", Text="Kick blocked: "..tostring(msg)(1,80), Duration=5})
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
