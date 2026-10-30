-- Scanner skill check: rekam GUI yang muncul, rotasi yang berubah (jarum), input yang kamu tekan,
-- dan remote yang dikirim selama beberapa detik. Hasil disalin ke clipboard untuk dianalisis.
--   SkillScan.start(detik, callback(teks))
local Hub = ...
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer
local Util = Hub.use("core/Util")

local Scan = { active = false }
local remoteLog = nil -- diisi saat scan aktif
local hooked = false

local function shownChain(d)
    local p = d
    while p and not p:IsA("PlayerGui") do
        if p:IsA("GuiObject") and not p.Visible then return false end
        if p:IsA("ScreenGui") and not p.Enabled then return false end
        p = p.Parent
    end
    return true
end

local function hookRemotes()
    if hooked or not (hookmetamethod and newcclosure and getnamecallmethod) then return end
    hooked = true
    local old
    old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if remoteLog and not Hub.Dead and (m == "FireServer" or m == "InvokeServer") then
            local args = table.pack(...)
            local parts = {}
            for i = 1, math.min(args.n, 6) do parts[#parts + 1] = typeof(args[i]) .. ":" .. tostring(args[i]):sub(1, 30) end
            remoteLog[#remoteLog + 1] = ("%s:%s(%s)"):format(Util.pathOf(self), m, table.concat(parts, ", "))
        end
        return old(self, ...)
    end))
end

function Scan.start(seconds, done)
    if Scan.active then return end
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if not pg then done("PlayerGui tidak ditemukan") return end
    Scan.active = true
    hookRemotes()
    remoteLog = {}

    -- snapshot: GUI yang SUDAH tampil sebelum scan tidak dilaporkan
    local before = {}
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiObject") and shownChain(d) then before[d] = true end
    end

    local seen, inputs = {}, {}
    local t0 = os.clock()
    local inConn = UIS.InputBegan:Connect(function(i, gpe)
        inputs[#inputs + 1] = ("%.2fs %s %s gpe=%s"):format(os.clock() - t0, tostring(i.UserInputType.Name), tostring(i.KeyCode.Name), tostring(gpe))
    end)

    local acc = 0
    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        if Hub.Dead then conn:Disconnect() inConn:Disconnect() Scan.active = false return end
        acc += dt
        if acc < 0.05 then return end
        acc = 0
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("GuiObject") and not before[d] and shownChain(d) then
                local r = seen[d]
                if not r then
                    r = { t = os.clock() - t0, rot = d.Rotation, rotMin = d.Rotation, rotMax = d.Rotation, changes = 0 }
                    seen[d] = r
                end
                if math.abs(d.Rotation - r.rot) > 0.01 then
                    r.changes += 1
                    r.rot = d.Rotation
                    r.rotMin, r.rotMax = math.min(r.rotMin, d.Rotation), math.max(r.rotMax, d.Rotation)
                end
            end
        end
        if os.clock() - t0 >= seconds then
            conn:Disconnect()
            inConn:Disconnect()
            Scan.active = false

            local out = { ("== SKILLCHECK SCAN (%ds) =="):format(seconds), "-- GUI baru yang tampil --" }
            local list = {}
            for d, r in pairs(seen) do list[#list + 1] = { d = d, r = r } end
            table.sort(list, function(a, b) return a.r.t < b.r.t end)
            for i, e in ipairs(list) do
                if i > 60 then out[#out + 1] = "..." break end
                local d, r = e.d, e.r
                local extra = ""
                if d:IsA("ImageLabel") or d:IsA("ImageButton") then extra = " img=" .. tostring(d.Image):sub(1, 40) end
                if d:IsA("TextLabel") or d:IsA("TextButton") then extra = " text=" .. tostring(d.Text):sub(1, 30) end
                local attrs = {}
                for k, v in pairs(d:GetAttributes()) do attrs[#attrs + 1] = k .. "=" .. tostring(v) end
                out[#out + 1] = ("[%.2fs] %s <%s> pos=(%d,%d) size=(%d,%d) rot=%.1f rotRange=%.1f..%.1f rotChanges=%d bg=%s%s%s"):format(
                    r.t, Util.pathOf(d), d.ClassName, d.AbsolutePosition.X, d.AbsolutePosition.Y,
                    d.AbsoluteSize.X, d.AbsoluteSize.Y, d.Rotation, r.rotMin, r.rotMax, r.changes,
                    Util.hex(d.BackgroundColor3), extra, #attrs > 0 and (" attrs{" .. table.concat(attrs, ",") .. "}") or "")
            end
            if #list == 0 then out[#out + 1] = "(tidak ada GUI baru; skill check mungkin tidak muncul selama scan)" end
            out[#out + 1] = "-- Input yang kamu tekan --"
            for _, s in ipairs(inputs) do out[#out + 1] = s end
            if #inputs == 0 then out[#out + 1] = "(tidak ada)" end
            out[#out + 1] = "-- Remote dikirim --"
            for i, s in ipairs(remoteLog or {}) do
                if i > 40 then out[#out + 1] = "..." break end
                out[#out + 1] = s
            end
            if not hooked then out[#out + 1] = "(hook remote tidak didukung executor)" end
            remoteLog = nil
            done(table.concat(out, "\n"))
        end
    end)
end

return Scan
