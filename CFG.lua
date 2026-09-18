local shared = odh_shared_plugins

if not shared then
    warn("[Omega] odh_shared_plugins is unavailable in this plugin context.")
    return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then
    warn("[Omega] Run this plugin on the client.")
    return
end

local previousRuntime = _G.OmegaAutoRevertRuntime
if type(previousRuntime) == "table" and type(previousRuntime.Cleanup) == "function" then
    local ok, restored = pcall(previousRuntime.Cleanup)
    if not ok or restored == false then
        warn("[Omega] Previous instance could not clean up. Reload cancelled.")
        return
    end
end

local ui = type(previousRuntime) == "table" and previousRuntime.ui
local reuseUI = type(ui) == "table" and ui.owner == shared and ui.complete ~= false
if not reuseUI then
    local ok, section = pcall(function()
        return shared.AddSection("Omega Auto Revert")
    end)
    if not ok or not section then
        warn("[Omega] odh_shared_plugins.AddSection failed: " .. tostring(section))
        return
    end
    ui = { owner = shared, section = section, complete = false }
end
local values = reuseUI and previousRuntime.values or {
    ["Auto Revert"] = false,
    ["Adaptive Engine"] = true,
    ["Lock Config"] = false,
    ["Upgrade Mode"] = false,
    ["Monitor"] = false,
    ["FPS Boost"] = false,
}
local runtime = { alive = true, ui = ui, values = values, handlers = {} }
_G.OmegaAutoRevertRuntime = runtime

local SAMPLE_INTERVAL = 0.4
local MONITOR_INTERVAL = 0.25
local STALE_INTERVAL = 5
local HYSTERESIS = 4

local enabled = values["Auto Revert"]
local adaptiveEngine = values["Adaptive Engine"]
local monitorEnabled = false
local fpsBoost = false
local locked = values["Lock Config"]
local upgrade = values["Upgrade Mode"]
local currentProfile = ""
local applyHealthy = true
local lastApplied = {}
local lastSetters = {}
local activePreset
local upgradeTarget
local lastUpgrade
local workerToken
local updateConnection
local monitorGui
local graphicsSnapshot = {}
local warnings = {}

local rawPing = 60
local smoothedPing = 60
local jitter = 0
local pingSource = "Fallback"
local lastAttempt = -math.huge
local lastGoodSample = -math.huge

local function WarnOnce(key, message)
    if not warnings[key] then
        warnings[key] = true
        warn("[Omega] " .. message)
    end
end

local function IsFinite(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

local function ReadDataPing()
    local network = Stats:FindFirstChild("Network")
    local serverStats = network and network:FindFirstChild("ServerStatsItem")
    local item = serverStats and serverStats:FindFirstChild("Data Ping")
    return item and item:GetValue()
end

local function ReadPerformancePing()
    local performance = Stats:FindFirstChild("PerformanceStats")
    local item = performance and performance:FindFirstChild("Ping")
    return item and item:GetValue()
end

local function ReadNetworkPing()
    local value = LocalPlayer:GetNetworkPing()
    if IsFinite(value) then
        return value * 1000
    end
end

local pingReaders = {
    { ReadDataPing, "Data Ping" },
    { ReadPerformancePing, "Performance" },
    { ReadNetworkPing, "Network" },
}

local function SamplePing()
    local now = os.clock()
    if now - lastAttempt < SAMPLE_INTERVAL then
        return
    end
    lastAttempt = now

    local value
    for _, reader in ipairs(pingReaders) do
        local ok, candidate = pcall(reader[1])
        if ok and IsFinite(candidate) and candidate > 0 then
            value = candidate
            pingSource = reader[2]
            break
        end
    end

    if not value then
        pingSource = lastGoodSample == -math.huge and "Fallback" or "Last known"
        return
    end

    local elapsed = now - lastGoodSample
    local nextRaw = math.clamp(math.floor(value + 0.5), 5, 1200)
    if elapsed > STALE_INTERVAL then
        smoothedPing = nextRaw
        jitter = 0
    else
        local weight = elapsed / SAMPLE_INTERVAL
        local jitterAlpha = 1 - 0.75 ^ weight
        jitter = jitter + (math.abs(nextRaw - rawPing) - jitter) * jitterAlpha
        if adaptiveEngine then
            local alpha = math.abs(nextRaw - smoothedPing) > 40 and 0.6 or 0.25
            alpha = 1 - (1 - alpha) ^ weight
            smoothedPing = smoothedPing + (nextRaw - smoothedPing) * alpha
        else
            smoothedPing = nextRaw
        end
    end
    rawPing = nextRaw
    lastGoodSample = now
end

local function GetPing()
    return math.floor(smoothedPing + 0.5)
end

local PingControlPoints = {
    { Ping = 20, Sim = 48, Interval = 70, H = 154, V = 144, X = -5, Y = -14, Z = 0 },
    { Ping = 50, Sim = 54, Interval = 66, H = 162, V = 152, X = -6, Y = -14, Z = 0 },
    { Ping = 100, Sim = 68, Interval = 60, H = 176, V = 166, X = -8, Y = -15, Z = 0 },
    { Ping = 150, Sim = 72, Interval = 64, H = 182, V = 170, X = -9, Y = -12, Z = 0 },
    { Ping = 200, Sim = 76, Interval = 70, H = 188, V = 174, X = -10, Y = -11, Z = 0 },
    { Ping = 300, Sim = 82, Interval = 76, H = 196, V = 180, X = -12, Y = -10, Z = 0 },
}
local ProfileNames = { "A", "B", "C", "D" }
local ProfileIndices = { A = 1, B = 2, C = 3, D = 4 }
local ProfileThresholds = { 50, 100, 150 }
local ConfigFields = {
    { name = "Sim", point = "Sim", slot = 4, scale = 1 },
    { name = "Interval", point = "Interval", slot = 5, scale = 1 },
    { name = "X", point = "X", slot = 7, scale = 10 },
    { name = "Y", point = "Y", slot = 8, scale = 10 },
    { name = "Z", point = "Z", slot = 9, scale = 10 },
    { name = "Horizontal", point = "H", slot = 10, scale = 1 },
    { name = "Vertical", point = "V", slot = 11, scale = 1 },
}

local function GetConfig(ping)
    local first
    local second
    local t = 0
    local name

    if adaptiveEngine then
        name = "Dynamic_" .. math.floor(ping)
        first = PingControlPoints[1]
        second = first
        if ping >= PingControlPoints[#PingControlPoints].Ping then
            first = PingControlPoints[#PingControlPoints]
            second = first
        elseif ping > first.Ping then
            for i = 1, #PingControlPoints - 1 do
                if ping <= PingControlPoints[i + 1].Ping then
                    first = PingControlPoints[i]
                    second = PingControlPoints[i + 1]
                    t = (ping - first.Ping) / (second.Ping - first.Ping)
                    t = t * t * (3 - 2 * t)
                    break
                end
            end
        end
    else
        local index = ProfileIndices[currentProfile]
        if index then
            while index < 4 and ping > ProfileThresholds[index] + HYSTERESIS do
                index = index + 1
            end
            while index > 1 and ping <= ProfileThresholds[index - 1] - HYSTERESIS do
                index = index - 1
            end
        else
            index = 1
            while index < 4 and ping > ProfileThresholds[index] do
                index = index + 1
            end
        end
        first = PingControlPoints[index + 1]
        second = first
        name = ProfileNames[index]
    end

    local cfg = { Name = name }
    for _, field in ipairs(ConfigFields) do
        local a = first[field.point]
        local b = second[field.point]
        cfg[field.name] = math.floor((a + (b - a) * t) * field.scale + 0.5) / field.scale
    end
    if upgrade then
        cfg.Vertical = cfg.Vertical + 2
        cfg.Horizontal = cfg.Horizontal + 2
        cfg.Sim = cfg.Sim + 1
    end
    return cfg
end

local function CallPreset(preset, slot, value, key)
    local readable, callback = pcall(function()
        return preset[slot]
    end)
    if not readable or not callback then
        local detail = readable and "missing callback" or tostring(callback)
        WarnOnce(slot, "MM2_GPL[" .. slot .. "] is unavailable: " .. detail)
        return false
    end
    if key and lastApplied[key] == value and lastSetters[key] == callback then
        warnings[slot] = nil
        return true
    end
    local ok, err = pcall(function()
        if value == nil then
            callback()
        else
            callback(value)
        end
    end)
    if not ok then
        WarnOnce(slot, "MM2_GPL[" .. slot .. "] failed: " .. tostring(err))
        return false
    end
    warnings[slot] = nil
    if key then
        lastApplied[key] = value
        lastSetters[key] = callback
    end
    return true
end

local function GetInternal()
    local internal = odh_internal_shared
    if not internal then
        WarnOnce("internal", "odh_internal_shared is unavailable; MM2 settings are waiting for this API.")
        return nil
    end
    warnings.internal = nil
    return internal
end

local function SyncUpgrade(internal)
    if not internal then
        return false
    end
    if upgradeTarget == internal and lastUpgrade == upgrade then
        return true
    end
    local ok, err = pcall(function()
        internal.__OMEGA_UPGRADE = upgrade
    end)
    if not ok then
        WarnOnce("upgrade", "Cannot write odh_internal_shared.__OMEGA_UPGRADE: " .. tostring(err))
        return false
    end
    warnings.upgrade = nil
    upgradeTarget = internal
    lastUpgrade = upgrade
    return true
end

local RequiredFlags = {
    { key = "RevertSettings_PrioritizeYourPing", slot = 1 },
    { key = "RevertSettings_PredictJump", slot = 2 },
    { key = "RevertSettings_PredictLag", slot = 3 },
}

local function Apply(cfg)
    local internal = GetInternal()
    if not internal then
        applyHealthy = false
        return
    end
    local ok = SyncUpgrade(internal)
    local readable, preset = pcall(function()
        return internal.MM2_GPL
    end)
    if not readable or not preset then
        local detail = readable and "missing value" or tostring(preset)
        WarnOnce("preset", "odh_internal_shared.MM2_GPL is unavailable: " .. detail)
        applyHealthy = false
        return
    end
    warnings.preset = nil
    if activePreset ~= preset then
        activePreset = preset
        lastApplied = {}
        lastSetters = {}
    end

    for _, flag in ipairs(RequiredFlags) do
        if flag.slot ~= 3 or not adaptiveEngine or smoothedPing > 110 then
            local flagOk, state = pcall(function()
                return internal[flag.key]
            end)
            if not flagOk then
                WarnOnce(flag.key, "Cannot read odh_internal_shared." .. flag.key .. ": " .. tostring(state))
                ok = false
            else
                warnings[flag.key] = nil
                if not state and not CallPreset(preset, flag.slot) then
                    ok = false
                end
            end
        end
    end

    for _, field in ipairs(ConfigFields) do
        if not CallPreset(preset, field.slot, cfg[field.name], field.name) then
            ok = false
        end
    end
    applyHealthy = ok
    if ok then
        currentProfile = cfg.Name
    end
end

local function Update()
    SamplePing()
    if enabled and not locked then
        Apply(GetConfig(GetPing()))
    end
end

local function NeedsUpdates()
    return monitorEnabled or (enabled and not locked)
end

local function SyncWorker()
    if not runtime.alive or not NeedsUpdates() then
        workerToken = nil
        return
    end
    if workerToken then
        return
    end
    local token = {}
    workerToken = token
    task.spawn(function()
        while runtime.alive and workerToken == token and NeedsUpdates() do
            task.wait(SAMPLE_INTERVAL)
            if runtime.alive and workerToken == token and NeedsUpdates() then
                Update()
            end
        end
    end)
end

local function RestoreGraphics()
    for i = #graphicsSnapshot, 1, -1 do
        local saved = graphicsSnapshot[i]
        local ok, err = pcall(function()
            saved.object[saved.property] = saved.value
        end)
        if ok then
            warnings[saved.property] = nil
            table.remove(graphicsSnapshot, i)
        else
            WarnOnce(saved.property, "Cannot restore " .. saved.property .. ": " .. tostring(err))
        end
    end
    return #graphicsSnapshot == 0
end

local function SaveAndSet(object, property, value)
    local ok, original = pcall(function()
        return object[property]
    end)
    if not ok then
        WarnOnce(property, "Cannot read " .. property .. ": " .. tostring(original))
        return
    end
    graphicsSnapshot[#graphicsSnapshot + 1] = { object = object, property = property, value = original }
    local applied, err = pcall(function()
        object[property] = value
    end)
    if not applied then
        WarnOnce(property, "Cannot set " .. property .. ": " .. tostring(err))
    end
end

local function SetFPSBoost(state)
    if not state then
        fpsBoost = false
        return RestoreGraphics()
    end
    if fpsBoost then
        return true
    end
    if not RestoreGraphics() then
        return false
    end

    fpsBoost = true
    SaveAndSet(Lighting, "GlobalShadows", false)
    SaveAndSet(Lighting, "OutdoorAmbient", Color3.fromRGB(128, 128, 128))
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        SaveAndSet(terrain, "WaterWaveSize", 0)
        SaveAndSet(terrain, "WaterWaveSpeed", 0)
        SaveAndSet(terrain, "WaterReflectance", 0)
        SaveAndSet(terrain, "WaterTransparency", 0)
    end
    return true
end

local function DestroyMonitor()
    if updateConnection then
        updateConnection:Disconnect()
        updateConnection = nil
    end
    if monitorGui then
        if _G.OmegaGui == monitorGui then
            _G.OmegaGui = nil
        end
        monitorGui:Destroy()
        monitorGui = nil
    end
end

local function SetText(label, text)
    if label.Text ~= text then
        label.Text = text
    end
end

local function CreateMonitor()
    DestroyMonitor()
    if _G.OmegaGui then
        pcall(function() _G.OmegaGui:Destroy() end)
        _G.OmegaGui = nil
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "Omega"
    gui.ResetOnSpawn = false
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
        pcall(function() gui.Parent = playerGui end)
    end
    if not gui.Parent then
        pcall(function() gui.Parent = game:GetService("CoreGui") end)
    end
    if not gui.Parent then
        gui:Destroy()
        monitorEnabled = false
        WarnOnce("gui", "Neither PlayerGui nor CoreGui is available for the monitor.")
        return
    end
    warnings.gui = nil
    monitorGui = gui
    _G.OmegaGui = gui

    local function MakeLabel(name, y)
        local label = Instance.new("TextLabel")
        label.Name = name
        label.AnchorPoint = Vector2.new(1, 0)
        label.Size = UDim2.new(1, -24, 0, 19)
        label.Position = UDim2.new(1, -12, 0, y)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Code
        label.TextXAlignment = Enum.TextXAlignment.Right
        label.TextSize = 14
        label.TextColor3 = Color3.fromRGB(240, 240, 240)
        label.TextStrokeTransparency = 0.4
        label.Text = ""
        label.Parent = gui
        return label
    end

    local pingLabel = MakeLabel("Ping", 40)
    local fpsLabel = MakeLabel("FPS", 59)
    local detailLabel = MakeLabel("Telemetry", 78)
    local statusLabel = MakeLabel("Status", 97)
    local elapsed = 0
    local frames = 0

    local function Refresh(fps)
        SetText(pingLabel, "Ping: " .. GetPing() .. " ms | Raw: " .. rawPing .. " ms")
        SetText(fpsLabel, "FPS: " .. (fps and tostring(fps) or "--"))
        SetText(detailLabel, "Jitter: " .. math.floor(jitter + 0.5) .. " ms | " .. pingSource)
        local status = not enabled and "OFF" or (locked and "LOCKED" or (applyHealthy and "ON" or "RETRY"))
        local profile = currentProfile ~= "" and currentProfile or "--"
        local mode = adaptiveEngine and "Adaptive" or "Classic"
        SetText(statusLabel, status .. " | " .. profile .. " | " .. mode .. (upgrade and " +Upgrade" or ""))
    end

    Refresh()
    updateConnection = RunService.RenderStepped:Connect(function(dt)
        if not runtime.alive or not monitorEnabled then
            return
        end
        if not IsFinite(dt) or dt <= 0 then
            return
        end
        frames = frames + 1
        elapsed = elapsed + dt
        if elapsed >= MONITOR_INTERVAL then
            Refresh(math.floor(frames / elapsed + 0.5))
            elapsed = 0
            frames = 0
        end
    end)
end

local function Reconfigure(invalidate)
    if invalidate then
        lastApplied = {}
        lastSetters = {}
    end
    if enabled and not locked then
        Update()
    end
    SyncWorker()
end

runtime.handlers["Auto Revert"] = function(v)
    enabled = v
    Reconfigure(v)
end

runtime.handlers["Adaptive Engine"] = function(v)
    if adaptiveEngine ~= v then
        adaptiveEngine = v
        smoothedPing = rawPing
        currentProfile = ""
    end
    Reconfigure(false)
end

runtime.handlers["Lock Config"] = function(v)
    locked = v
    Reconfigure(not v)
end

runtime.handlers["Upgrade Mode"] = function(v)
    upgrade = v
    SyncUpgrade(GetInternal())
    Reconfigure(false)
end

runtime.handlers["Monitor"] = function(v)
    monitorEnabled = v
    if v then
        SamplePing()
        CreateMonitor()
    else
        DestroyMonitor()
    end
    SyncWorker()
end

runtime.handlers["FPS Boost"] = SetFPSBoost

runtime.Cleanup = function()
    runtime.alive = false
    workerToken = nil
    DestroyMonitor()
    return SetFPSBoost(false)
end

ui.runtime = runtime
if not reuseUI then
    local function RegisterToggle(name)
        local ok, err = pcall(function()
            ui.section:AddToggle(name, function(value)
                local active = ui.runtime
                if active and active.alive then
                    local state = value == true
                    active.values[name] = state
                    active.handlers[name](state)
                end
            end)
        end)
        if not ok then
            runtime.Cleanup()
            warn("[Omega] AddToggle failed for " .. name .. ": " .. tostring(err))
        end
        return ok
    end

    local names = { "Auto Revert", "Adaptive Engine", "Lock Config", "Upgrade Mode", "Monitor", "FPS Boost" }
    for _, name in ipairs(names) do
        if not RegisterToggle(name) then
            return
        end
    end
    ui.complete = true
end

SyncUpgrade(odh_internal_shared)
if values["FPS Boost"] then
    SetFPSBoost(true)
end
if values["Monitor"] then
    runtime.handlers["Monitor"](true)
end
Reconfigure(false)
