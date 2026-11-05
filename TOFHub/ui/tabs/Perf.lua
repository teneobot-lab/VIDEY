-- Tab Performa: statistik FPS/ping, HUD, FPS Booster, batas FPS.
local Hub = ...
local Config = Hub.use("config/Config")
local Scheduler = Hub.use("core/Scheduler")
local Perf = Hub.use("features/Perf")
local Page = Hub.use("ui/Controls")

local page = Page.new("Performa")

page:Header("Performa", "FPS, ping, dan booster")
local tiles = page:Tiles({ { "fps", "FPS" }, { "min", "FPS MIN (5 dtk)" }, { "ping", "PING" }, { "mem", "MEMORI" } })
page:Toggle("Tampilkan FPS & ping di layar (HUD)", "ShowStats")

page:Section("FPS Booster")
page:Toggle("FPS Booster", "Boost")
page:Choice("Level (tap untuk ganti)", "BoostLevel", Perf.LEVEL_NAMES, Perf.applyLevel)
local infoBoost = page:Info("...")
page:Info("Ringan: kualitas render turun, bayangan & partikel mati. Sedang: + efek layar, terrain, mesh sederhana. Maks: + semua material jadi polos dan tekstur/decal disembunyikan. Semua dipulihkan saat dimatikan. Booster dan Mode HD saling mematikan.")

page:Section("Detail booster")
page:Toggle("Turunkan kualitas render", "BoostQuality")
page:Slider("Level kualitas (1 = paling ringan)", "BoostQualityLevel", 1, 10, 1, "")
page:Toggle("Matikan bayangan", "BoostShadows")
page:Toggle("Matikan efek layar (blur/bloom/dll)", "BoostFx")
page:Toggle("Matikan partikel/asap/api/trail", "BoostParticles")
page:Toggle("Sederhanakan terrain & air", "BoostTerrain")
page:Toggle("Mesh detail rendah", "BoostMesh")
page:Toggle("Material polos (SmoothPlastic)", "BoostMaterials")
page:Toggle("Sembunyikan tekstur & decal", "BoostTextures")

page:Section("Batas FPS")
if Perf.capSupported then
    page:Slider("Batas FPS (0 = ikut Roblox)", "FpsCap", 0, 240, 10, "")
    page:Info("Menaikkan batas di atas 60 memakai setfpscap milik executor. Batas rendah (30) bisa menghemat baterai/panas di HP.")
else
    page:Info("Executor ini tidak punya setfpscap, batas FPS tidak bisa diubah.")
end

Scheduler.add("Info performa", 0.5, function()
    tiles.fps.Text = tostring(math.floor(Perf.fps))
    tiles.min.Text = tostring(math.floor(Perf.minFps))
    tiles.ping.Text = Perf.ping .. " ms"
    tiles.mem.Text = Perf.mem .. " MB"
    if Config.Cfg.Boost then
        infoBoost.Text = ("Status: %s · %d objek disederhanakan"):format(Perf.status, Perf.count)
    else
        infoBoost.Text = "Status: mati"
    end
end)

return { page = page }
