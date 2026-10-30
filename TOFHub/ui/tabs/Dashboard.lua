-- Tab Dashboard: statistik langsung, role pemain, kontrol cepat, perbaikan, diagnostik.
-- update() dijalankan Scheduler tiap 0.5 detik.
local Hub = ...
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local LP = Players.LocalPlayer
local Config = Hub.use("config/Config")
local Cfg, reg, setCfg = Config.Cfg, Config.reg, Config.set
local Util = Hub.use("core/Util")
local Scheduler = Hub.use("core/Scheduler")
local Roles = Hub.use("core/Roles")
local Aim = Hub.use("features/Aim")
local SkillScan = Hub.use("features/SkillScan")
local Move = Hub.use("features/Movement")
local ESP = Hub.use("esp/Players")
local Zom = Hub.use("esp/Zombies")
local Window = Hub.use("ui/Window")
local T = Hub.use("ui/Kit").T
local Page = Hub.use("ui/Controls")

local page = Page.new("Dashboard")

page:Header("Dashboard", "Ringkasan permainan")
local tiles = page:Tiles({ { "fps", "FPS" }, { "ping", "PING" }, { "players", "PEMAIN" }, { "killer", "KILLER" } })
page:Section("Role pemain")
local infoRole = page:Info("...", true)
page:Section("Kontrol cepat")
page:Toggle("Aimlock", "Aimlock")
page:Toggle("Silent Aim", "Silent")
page:Toggle("ESP Killer", "ESPKiller")
page:Toggle("ESP Survivor", "ESPSurv")
page:Toggle("ESP Zombie", "ESPZombie")
page:Toggle("Label semua ESP", "ShowLabels")
page:Toggle("Terang (Fullbright)", "Fullbright")
page:Toggle("Mode HD", "HD")
page:Section("Perbaikan")
page:Button("Reset pose (tubuh macet angkat pistol)", Aim.unstick)
local manualBtn
manualBtn = page:Button("Killer: Auto  (tap untuk ganti manual)", function()
    local names = { "" }
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then names[#names + 1] = p.Name end
    end
    local idx = table.find(names, Cfg.ManualKiller) or 1
    setCfg("ManualKiller", names[idx % #names + 1])
    pcall(Roles.detect)
end)
reg("ManualKiller", function()
    manualBtn.Text = "Killer: " .. (Cfg.ManualKiller == "" and "Auto" or Cfg.ManualKiller) .. "  (tap untuk ganti)"
end)
page:Button("Salin data deteksi role", function()
    if setclipboard then
        setclipboard(Roles.dump())
        Window.toast("Data deteksi disalin")
    else
        Window.toast("setclipboard tidak didukung")
    end
end)
page:Button("Scan skill check (15 dtk, salin hasil)", function()
    if not setclipboard then Window.toast("setclipboard tidak didukung") return end
    Window.toast("Scan 15 dtk: picu skill check lalu tekan seperti biasa")
    SkillScan.start(15, function(txt)
        setclipboard(txt)
        Window.toast("Hasil scan disalin")
    end)
end)
page:Section("Twist of Fate")
local infoTOF = page:Info("...")
page:Section("Diagnostik")
local infoDiag = page:Info("...")

--------------------------------------------------------
-- Pembaruan berkala (dipecah per bagian)
--------------------------------------------------------
local function updateTiles(ping)
    local fps = Scheduler.fps
    tiles.fps.Text = tostring(math.floor(fps))
    tiles.ping.Text = ping .. " ms"
    tiles.players.Text = tostring(#Players:GetPlayers())
    local k1 = Roles.killers[1]
    tiles.killer.Text = k1 and k1.DisplayName or "-"
    tiles.killer.TextColor3 = k1 and Cfg.KillerColor or T.muted
    Window.statLbl.Text = ("%d fps · %s ms"):format(math.floor(fps), ping)
end

local function updateRoles()
    local lines = {}
    local kc, sc = "#" .. Util.hex(Cfg.KillerColor), "#" .. Util.hex(Cfg.SurvColor)
    for i, e in ipairs(Roles.info) do
        if i > 8 then lines[#lines + 1] = "..." break end
        local me = e.p == LP and " <font color=\"#8A8E9E\">(kamu)</font>" or ""
        if e.killer then
            lines[#lines + 1] = ("<font color=\"%s\"><b>KILLER</b></font>  %s%s"):format(kc, Util.esc(e.p.DisplayName), me)
        else
            lines[#lines + 1] = ("<font color=\"%s\">Survivor</font>  %s%s"):format(sc, Util.esc(e.p.DisplayName), me)
        end
    end
    if #lines == 0 then lines[1] = "Belum ada data pemain" end
    local foot = #Roles.killers > 0 and ("Target aim: " .. Util.esc(Aim.targetName or "-"))
        or "<font color=\"#8A8E9E\">Killer belum terdeteksi (muncul saat match mulai, atau pilih manual)</font>"
    infoRole.Text = table.concat(lines, "\n") .. "\n" .. foot
end

local function updateTOF()
    local total = Aim.shoot + Aim.fail
    infoTOF.Text = ("Peluru: %d    Gagal: %d%s"):format(
        Aim.shoot, Aim.fail, total > 0 and ("    (" .. math.floor(Aim.shoot / total * 100) .. "% peluru)") or "")
end

local function updateDiag()
    local zc, zt = 0, 0
    for model in pairs(Zom.tracked) do
        zt += 1
        if Cfg.ZomAll or Zom.matches(model) then zc += 1 end
    end
    local diag = {
        ("ESP pemain tampil: Killer %d, Survivor %d"):format(ESP.shown.Killer or 0, ESP.shown.Surv or 0),
        ("Zombie: %d cocok dari %d NPC, tampil %d"):format(zc, zt, Zom.shown),
        "Mode ESP: " .. Cfg.ESPMode,
    }
    local errs = {}
    for name, e in pairs(Hub.Err) do errs[#errs + 1] = name .. ": " .. e:sub(1, 70) end
    diag[#diag + 1] = #errs > 0 and ("Error:\n" .. table.concat(errs, "\n")) or "Error: tidak ada"
    infoDiag.Text = table.concat(diag, "\n")
end

local function update()
    local ping = "-"
    pcall(function() ping = tostring(math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())) end)
    updateTiles(ping)
    updateRoles()
    updateTOF()
    updateDiag()
end

Scheduler.add("Dashboard", 0.5, update)

return { page = page }
