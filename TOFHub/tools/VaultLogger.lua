--========================================================
-- VAULT LOGGER | skrip mandiri (tidak butuh TOFHub)
-- Hanya MEREKAM, tidak mengubah apa pun di game.
--
-- Jalankan:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/teneobot-lab/VIDEY/main/TOFHub/tools/VaultLogger.lua"))()
--
-- Pakai: atur durasi -> "Mulai" -> vault jendela beberapa kali -> hasil otomatis disalin ke clipboard
-- dan disimpan ke file VaultLog.txt (bila executor mendukung). Kirim isinya untuk dianalisis.
--
-- Yang dicatat (berurutan menurut waktu):
--   ANIM   animasi dimainkan/berhenti (nama, id, panjang, kecepatan, prioritas) + KEY marker keyframe
--   ATTR   atribut karakter/player berubah        STATE  state Humanoid & properti (WalkSpeed, dll)
--   MOVE   lonjakan posisi (teleport/tween) dan kecepatan tinggi
--   PART   CanCollide / Anchored bagian karakter  ADD/DEL objek masuk/keluar karakter
--   TAG    tag karakter berubah                   INPUT  tombol yang kamu tekan
--   C>S    remote yang DIKIRIM client             S>C    remote yang DITERIMA client
--   PROMPT ProximityPrompt (tahan/trigger)        WINDOW detail jendela terdekat
--========================================================
if getgenv and getgenv().VaultLoggerUnload then pcall(getgenv().VaultLoggerUnload) end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CS = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local FILE = "VaultLog.txt"
local MAX_EVENTS = 600
-- remote yang dikirim terus-menerus: hanya DIHITUNG (tidak dicatat satu-satu) supaya log tidak penuh
local NOISY = {
    UpdateCharacterLook = true, ReplicateCharacterLook = true, PushRemote = true,
    GetPing = true, TimeUpdateEvent = true,
}
local noise = {}
local dead = false
local cleanups = {}

--------------------------------------------------------
-- util
--------------------------------------------------------
local function clip(s, n) s = tostring(s) if #s > n then return s:sub(1, n - 3) .. "..." end return s end

local function pathOf(i)
    local ok, r = pcall(function() return i:GetFullName() end)
    return ok and r or tostring(i)
end

local function fmtArg(v)
    local t = typeof(v)
    if t == "Instance" then return "Instance:" .. clip(pathOf(v), 70) end
    if t == "table" then
        local n = 0
        for _ in pairs(v) do n += 1 end
        return "table#" .. n
    end
    return t .. ":" .. clip(v, 40)
end

local function fmtArgs(args, n)
    local parts = {}
    for i = 1, math.min(n, 6) do parts[#parts + 1] = fmtArg(args[i]) end
    return table.concat(parts, ", ")
end

local function describeInst(inst)
    local out = { ("%s <%s>"):format(pathOf(inst), inst.ClassName) }
    local attrs = {}
    for k, v in pairs(inst:GetAttributes()) do attrs[#attrs + 1] = k .. "=" .. tostring(v) end
    if #attrs > 0 then out[#out + 1] = " attrs{" .. table.concat(attrs, ",") .. "}" end
    local tags = CS:GetTags(inst)
    if #tags > 0 then out[#out + 1] = " tags{" .. table.concat(tags, ",") .. "}" end
    local kids, prompts, n = {}, {}, 0
    for _, d in ipairs(inst:GetDescendants()) do
        n += 1
        if #kids < 22 then kids[#kids + 1] = d.Name .. "<" .. d.ClassName .. ">" end
        if d:IsA("ProximityPrompt") then
            prompts[#prompts + 1] = ("%s action=%q hold=%.2f maxDist=%.1f enabled=%s"):format(
                d.Name, d.ActionText, d.HoldDuration, d.MaxActivationDistance, tostring(d.Enabled))
        end
    end
    out[#out + 1] = (" descendants=%d [%s]"):format(n, table.concat(kids, ", "))
    if #prompts > 0 then out[#out + 1] = " prompts{" .. table.concat(prompts, " | ") .. "}" end
    return table.concat(out)
end

--------------------------------------------------------
-- hook remote client -> server (sekali, aktif hanya saat merekam)
--------------------------------------------------------
local outbound = nil
local hooked = false
local function hookRemotes()
    if hooked or not (hookmetamethod and newcclosure and getnamecallmethod) then return end
    hooked = true
    local old
    old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if outbound and not dead and (m == "FireServer" or m == "InvokeServer") then
            local nm = tostring(self.Name)
            if NOISY[nm] then
                noise["C>S " .. nm] = (noise["C>S " .. nm] or 0) + 1
            else
                local args = table.pack(...)
                pcall(outbound, ("%s:%s(%s)"):format(pathOf(self), m, fmtArgs(args, args.n)))
            end
        end
        return old(self, ...)
    end))
end

--------------------------------------------------------
-- daftar jendela di map (dipindai sekali, dicicil supaya tidak membekukan game)
--------------------------------------------------------
local windows = {}
local scanned = false
local function scanWindows()
    if scanned then return end
    scanned = true
    task.spawn(function()
        local map = workspace:FindFirstChild("Map")
        local root = map or workspace
        local n = 0
        for _, d in ipairs(root:GetDescendants()) do
            if dead then return end
            if (d:IsA("Model") or d:IsA("BasePart")) and d.Name:lower():find("window", 1, true)
                and not d:FindFirstChildOfClass("Humanoid") then
                -- lewati bagian dari jendela yang sudah tercatat
                local p, nested = d.Parent, false
                while p and p ~= root do
                    if p:IsA("Model") and p.Name:lower():find("window", 1, true) then nested = true break end
                    p = p.Parent
                end
                if not nested and not (d:IsA("BasePart") and d.Parent and d.Parent:FindFirstChildOfClass("Humanoid")) then
                    windows[#windows + 1] = d
                end
            end
            n += 1
            if n % 2500 == 0 then task.wait() end
        end
    end)
end

--------------------------------------------------------
-- sesi perekaman
--------------------------------------------------------
local Logger = { active = false, remaining = 0 }

function Logger.stop()
    if Logger.stopFn then Logger.stopFn() end
end

function Logger.start(seconds, done)
    if Logger.active or dead then return end
    seconds = math.clamp(tonumber(seconds) or 20, 3, 120)
    Logger.active = true
    hookRemotes()
    scanWindows()

    local t0 = os.clock()
    noise = {}
    local ev, counts, dropped = {}, {}, 0
    local conns, charConns = {}, {}
    local seenLoop, seenWin, seenPart = {}, {}, {}
    local remoteCount = {}
    local curChar, lastPos, lastTags = nil, nil, {}
    local fast, finished, tagAcc = false, false, 0
    local loopConn

    local function add(kind, msg)
        counts[kind] = (counts[kind] or 0) + 1
        if #ev >= MAX_EVENTS then dropped += 1 return end
        ev[#ev + 1] = ("[%6.2fs] %-6s %s"):format(os.clock() - t0, kind, clip(msg, 260))
    end
    local function track(c) conns[#conns + 1] = c return c end
    local function trackChar(c) charConns[#charConns + 1] = c return c end
    outbound = function(msg) add("C>S", msg) end

    local function myRoot()
        local ch = LP.Character
        return ch and ch:FindFirstChild("HumanoidRootPart")
    end

    local function logNearestWindow(why)
        local root = myRoot()
        if not root then return end
        local best, bd
        for _, w in ipairs(windows) do
            if w.Parent then
                local part = w:IsA("BasePart") and w or w:FindFirstChildWhichIsA("BasePart", true)
                if part then
                    local d = (part.Position - root.Position).Magnitude
                    if not bd or d < bd then best, bd = w, d end
                end
            end
        end
        if best and not seenWin[best] then
            seenWin[best] = true
            add("WINDOW", ("(%s) jarak %.1f stud: %s"):format(why, bd, describeInst(best)))
        end
    end

    ----------------------------------------------------
    -- hook per karakter (diulang tiap respawn)
    ----------------------------------------------------
    local HUM_PROPS = { "WalkSpeed", "JumpPower", "JumpHeight", "AutoRotate", "PlatformStand", "Sit", "HipHeight" }
    local function hookChar(ch)
        for _, c in ipairs(charConns) do pcall(function() c:Disconnect() end) end
        charConns = {}
        curChar, lastPos = ch, nil
        if not ch then return end
        add("STATE", "karakter terpasang: " .. pathOf(ch))
        trackChar(ch.AttributeChanged:Connect(function(name)
            add("ATTR", ("char.%s = %s"):format(name, tostring(ch:GetAttribute(name))))
        end))
        for k, v in pairs(ch:GetAttributes()) do add("ATTR", ("char.%s (awal) = %s"):format(k, tostring(v))) end

        local hum = ch:FindFirstChildOfClass("Humanoid")
        if hum then
            trackChar(hum.StateChanged:Connect(function(old, new)
                add("STATE", ("humanoid state %s -> %s"):format(tostring(old), tostring(new)))
            end))
            for _, p in ipairs(HUM_PROPS) do
                pcall(function()
                    trackChar(hum:GetPropertyChangedSignal(p):Connect(function()
                        add("STATE", ("humanoid.%s = %s"):format(p, tostring(hum[p])))
                    end))
                end)
            end
            local animator = hum:FindFirstChildOfClass("Animator")
            if animator then
                for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
                    add("ANIM", ("(sudah main) %s id=%s"):format(tr.Name, tostring(tr.Animation and tr.Animation.AnimationId)))
                end
                trackChar(animator.AnimationPlayed:Connect(function(tr)
                    local id = tr.Animation and tr.Animation.AnimationId or "?"
                    if tr.Looped then
                        if seenLoop[tr.Name] then return end
                        seenLoop[tr.Name] = true
                    end
                    add("ANIM", ("play %s id=%s len=%.2f speed=%.2f prio=%s looped=%s"):format(
                        tr.Name, tostring(id), tr.Length, tr.Speed, tostring(tr.Priority), tostring(tr.Looped)))
                    if not tr.Looped then
                        local started = os.clock()
                        trackChar(tr.Stopped:Connect(function()
                            add("ANIM", ("stop %s setelah %.2fs (len=%.2f)"):format(tr.Name, os.clock() - started, tr.Length))
                        end))
                        pcall(function()
                            trackChar(tr.KeyframeReached:Connect(function(k)
                                add("KEY", ("%s marker %s"):format(tr.Name, tostring(k)))
                            end))
                        end)
                        logNearestWindow("saat animasi " .. tr.Name)
                    end
                end))
            end
        end

        local n = 0
        for _, part in ipairs(ch:GetDescendants()) do
            if part:IsA("BasePart") and n < 25 then
                n += 1
                trackChar(part:GetPropertyChangedSignal("CanCollide"):Connect(function()
                    local key = part.Name .. ".c"
                    if seenPart[key] ~= part.CanCollide then
                        seenPart[key] = part.CanCollide
                        add("PART", ("%s.CanCollide = %s"):format(part.Name, tostring(part.CanCollide)))
                    end
                end))
                trackChar(part:GetPropertyChangedSignal("Anchored"):Connect(function()
                    add("PART", ("%s.Anchored = %s"):format(part.Name, tostring(part.Anchored)))
                end))
            end
        end
        trackChar(ch.DescendantAdded:Connect(function(d)
            add("ADD", ("%s <%s>"):format(d.Name, d.ClassName))
        end))
        trackChar(ch.DescendantRemoving:Connect(function(d)
            local c = d.ClassName
            if c:find("Body") or c:find("Velocity") or c:find("Align") or c:find("Force") or c:find("Tool") then
                add("DEL", ("%s <%s>"):format(d.Name, c))
            end
        end))
    end

    ----------------------------------------------------
    -- hook global
    ----------------------------------------------------
    track(LP.AttributeChanged:Connect(function(name)
        add("ATTR", ("player.%s = %s"):format(name, tostring(LP:GetAttribute(name))))
    end))
    do -- atribut awal player terlalu banyak (settings/inventory): cukup dihitung, perubahannya tetap dicatat
        local n = 0
        for _ in pairs(LP:GetAttributes()) do n += 1 end
        add("ATTR", ("player: %d atribut awal (tidak diperinci)"):format(n))
    end

    track(UIS.InputBegan:Connect(function(i, gpe)
        add("INPUT", ("%s %s gpe=%s"):format(tostring(i.UserInputType.Name), tostring(i.KeyCode.Name), tostring(gpe)))
    end))

    -- remote yang DITERIMA client (tiap remote dicatat 6 kali pertama, sisanya hanya dihitung)
    for _, d in ipairs(RS:GetDescendants()) do
        if d:IsA("RemoteEvent") then
            pcall(function()
                track(d.OnClientEvent:Connect(function(...)
                    local key = pathOf(d)
                    remoteCount[key] = (remoteCount[key] or 0) + 1
                    if NOISY[d.Name] then
                        noise["S>C " .. d.Name] = (noise["S>C " .. d.Name] or 0) + 1
                    elseif remoteCount[key] <= 6 then
                        local args = table.pack(...)
                        add("S>C", ("%s(%s)"):format(key, fmtArgs(args, args.n)))
                    end
                end))
            end)
        end
    end

    pcall(function()
        local PPS = game:GetService("ProximityPromptService")
        track(PPS.PromptButtonHoldBegan:Connect(function(p)
            add("PROMPT", ("tahan mulai: %s action=%q hold=%.2f parent=%s"):format(p.Name, p.ActionText, p.HoldDuration, pathOf(p.Parent)))
            local par = p.Parent
            while par and par ~= workspace do
                if par:IsA("Model") and par.Name:lower():find("window", 1, true) then
                    if not seenWin[par] then seenWin[par] = true add("WINDOW", "(dari prompt) " .. describeInst(par)) end
                    break
                end
                par = par.Parent
            end
        end))
        track(PPS.PromptButtonHoldEnded:Connect(function(p) add("PROMPT", "tahan selesai/dibatalkan: " .. p.Name) end))
        track(PPS.PromptTriggered:Connect(function(p) add("PROMPT", "TRIGGERED: " .. pathOf(p)) end))
    end)

    ----------------------------------------------------
    -- selesai: susun teks, salin, simpan
    ----------------------------------------------------
    local function finish()
        if finished then return end
        finished = true
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        for _, c in ipairs(charConns) do pcall(function() c:Disconnect() end) end
        if loopConn then pcall(function() loopConn:Disconnect() end) end
        outbound = nil
        Logger.active, Logger.remaining, Logger.stopFn = false, 0, nil

        local out = { ("== VAULT LOG (%.1f dtk) | PlaceId %s =="):format(os.clock() - t0, tostring(game.PlaceId)) }
        local sum = {}
        for k, v in pairs(counts) do sum[#sum + 1] = k .. "=" .. v end
        table.sort(sum)
        out[#out + 1] = "ringkasan: " .. (#sum > 0 and table.concat(sum, " ") or "(kosong)")
        out[#out + 1] = ("jendela terdeteksi di map: %d"):format(#windows)
        out[#out + 1] = "-- timeline --"
        for _, line in ipairs(ev) do out[#out + 1] = line end
        if dropped > 0 then out[#out + 1] = ("(+%d kejadian dibuang, batas %d)"):format(dropped, MAX_EVENTS) end
        if not hooked then out[#out + 1] = "(hook remote client->server tidak didukung executor)" end
        local rc = {}
        for k, v in pairs(remoteCount) do if v > 6 and not NOISY[k:match("[^.]+$") or ""] then rc[#rc + 1] = ("%s x%d"):format(k, v) end end
        for k, v in pairs(noise) do rc[#rc + 1] = ("%s x%d (hanya dihitung)"):format(k, v) end
        if #rc > 0 then
            table.sort(rc)
            out[#out + 1] = "-- remote yang sering muncul --"
            for _, s in ipairs(rc) do out[#out + 1] = s end
        end
        local text = table.concat(out, "\n")
        local copied = false
        if setclipboard then copied = pcall(setclipboard, text) end
        local saved = false
        if writefile then saved = pcall(writefile, FILE, text) end
        Logger.lastText = text
        Logger.lastMsg = (copied and "disalin ke clipboard" or "clipboard tidak didukung")
            .. (saved and (", disimpan ke " .. FILE) or "")
        if done then pcall(done, text) end
    end
    Logger.stopFn = finish

    logNearestWindow("awal scan")

    loopConn = RunService.Heartbeat:Connect(function(dt)
        if finished then return end
        if dead then finish() return end
        local now = os.clock()
        Logger.remaining = math.max(0, seconds - (now - t0))
        if now - t0 >= seconds then finish() return end

        local ch = LP.Character
        if ch ~= curChar then pcall(hookChar, ch) end

        local root = myRoot()
        if root then
            local pos = root.Position
            if lastPos and dt > 0 then
                local d = (pos - lastPos).Magnitude
                local speed = d / dt
                if d > 6 and dt < 0.25 then
                    add("MOVE", ("lonjakan posisi %.1f stud dalam %.3fs"):format(d, dt))
                end
                local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                local ws = hum and hum.WalkSpeed or 16
                if speed > ws * 1.6 and d <= 6 then
                    if not fast then fast = true add("MOVE", ("kecepatan tinggi mulai %.1f stud/dtk (WalkSpeed %.1f)"):format(speed, ws)) end
                elseif fast and speed <= ws * 1.2 then
                    fast = false
                    add("MOVE", "kecepatan kembali normal")
                end
            end
            lastPos = pos
        end

        tagAcc += dt
        if tagAcc >= 0.1 and ch then
            tagAcc = 0
            local cur = {}
            for _, t in ipairs(CS:GetTags(ch)) do
                cur[t] = true
                if not lastTags[t] then add("TAG", "+" .. t) end
            end
            for t in pairs(lastTags) do
                if not cur[t] then add("TAG", "-" .. t) end
            end
            lastTags = cur
        end
    end)
end

--------------------------------------------------------
-- UI kecil (geser lewat judul)
--------------------------------------------------------
local container = (gethui and gethui()) or game:GetService("CoreGui")
local gui = Instance.new("ScreenGui")
gui.Name = "VaultLogger"
gui.ResetOnSpawn = false
gui.Parent = container

local function make(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end

local BG, PANEL, TXT, MUTED, ACC = Color3.fromRGB(26, 28, 36), Color3.fromRGB(38, 41, 52), Color3.fromRGB(235, 238, 246), Color3.fromRGB(150, 156, 175), Color3.fromRGB(80, 170, 255)

local frame = make("Frame", {
    Size = UDim2.fromOffset(230, 150), Position = UDim2.new(0.5, -115, 0.2, 0),
    BackgroundColor3 = BG, BorderSizePixel = 0, Active = true,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, frame)
make("UIStroke", { Color = Color3.fromRGB(10, 10, 14), Thickness = 2 }, frame)

local titleBar = make("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = PANEL, BorderSizePixel = 0 }, frame)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, titleBar)
make("TextLabel", {
    Size = UDim2.new(1, -34, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1,
    Text = "VAULT LOGGER", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = TXT,
    TextXAlignment = Enum.TextXAlignment.Left,
}, titleBar)
local closeBtn = make("TextButton", {
    Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -25, 0, 3), BackgroundTransparency = 1,
    Text = "×", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = MUTED,
}, titleBar)

local status = make("TextLabel", {
    Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 34), BackgroundTransparency = 1,
    Text = "Siap. Tekan Mulai, lalu vault jendela.", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = MUTED,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
}, frame)

make("TextLabel", {
    Size = UDim2.fromOffset(70, 22), Position = UDim2.fromOffset(10, 74), BackgroundTransparency = 1,
    Text = "Durasi (dtk)", Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = TXT, TextXAlignment = Enum.TextXAlignment.Left,
}, frame)
local box = make("TextBox", {
    Size = UDim2.fromOffset(60, 22), Position = UDim2.fromOffset(84, 74), BackgroundColor3 = PANEL, BorderSizePixel = 0,
    Text = "20", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = TXT, ClearTextOnFocus = false,
}, frame)
make("UICorner", { CornerRadius = UDim.new(0, 5) }, box)

local function button(text, x, w, color)
    local b = make("TextButton", {
        Size = UDim2.fromOffset(w, 28), Position = UDim2.fromOffset(x, 108), BackgroundColor3 = color, BorderSizePixel = 0,
        Text = text, Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = true,
    }, frame)
    make("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
    return b
end
local startBtn = button("Mulai", 10, 100, ACC)
local stopBtn = button("Stop + salin", 120, 100, Color3.fromRGB(90, 96, 120))

startBtn.Activated:Connect(function()
    if Logger.active then return end
    Logger.start(tonumber(box.Text) or 20)
end)
stopBtn.Activated:Connect(function() Logger.stop() end)

-- geser window
local dragging, sp, st
titleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging, sp, st = true, i.Position, frame.Position
    end
end)
cleanups[#cleanups + 1] = UIS.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - sp
        frame.Position = UDim2.new(st.X.Scale, st.X.Offset + d.X, st.Y.Scale, st.Y.Offset + d.Y)
    end
end)
cleanups[#cleanups + 1] = UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

-- status tiap 0.25 dtk
local acc = 0
cleanups[#cleanups + 1] = RunService.Heartbeat:Connect(function(dt)
    acc += dt
    if acc < 0.25 then return end
    acc = 0
    if Logger.active then
        status.Text = ("MEREKAM, sisa %d dtk. Vault jendela sekarang."):format(math.ceil(Logger.remaining))
        status.TextColor3 = Color3.fromRGB(255, 190, 70)
    elseif Logger.lastMsg then
        status.Text = "Selesai: " .. Logger.lastMsg
        status.TextColor3 = Color3.fromRGB(110, 220, 130)
    end
end)

local function unload()
    dead = true
    Logger.stop()
    for _, c in ipairs(cleanups) do pcall(function() c:Disconnect() end) end
    pcall(function() gui:Destroy() end)
    if getgenv then getgenv().VaultLoggerUnload, getgenv().VaultLogger = nil, nil end
end
closeBtn.Activated:Connect(unload)

if getgenv then
    getgenv().VaultLoggerUnload = unload
    getgenv().VaultLogger = Logger -- untuk dipanggil manual: VaultLogger.start(20)
end

return Logger
