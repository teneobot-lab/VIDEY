-- Konfigurasi: nilai awal, simpan/muat JSON, dan sinkronisasi ke komponen UI.
--   Config.Cfg          tabel nilai aktif (baca langsung: Cfg.FOV)
--   Config.Default      salinan nilai awal
--   Config.set(k,v[,s]) ubah nilai + segarkan UI + simpan otomatis (s = true: jangan tandai berubah)
--   Config.reg(k,f[,first]) daftarkan fungsi yang dipanggil tiap Cfg[k] berubah lewat set() (first: jalan paling awal)
--   Config.save()       simpan SEKARANG ke file          -> ok, pesan
--   Config.load()       muat dari file + segarkan UI     -> ok, pesan
--   Config.reset()      kembalikan semua ke default
--   Config.delete()     hapus file config                -> ok, pesan
--   Config.serialize()  config sebagai string JSON (untuk disalin)
--   Config.flush()      simpan sekarang bila ada perubahan tertunda (dipanggil saat unload/teleport)
--   Config.dirty        true bila ada perubahan yang belum tersimpan ke file
--   Config.loadInfo     hasil muat otomatis saat start: { ok, msg, n } (n = jumlah opsi yang dimuat)
-- Simpan otomatis: tiap perubahan lewat set() -> markDirty() -> tersimpan 1 detik setelah perubahan terakhir
--   (bila Cfg.AutoSave). Muat otomatis: file dibaca saat modul ini dimuat (sebelum UI dibuat); versi lama
--   tetap dimuat untuk kunci yang masih ada (migrasi), kunci baru memakai default.
-- Opsi baru: tambah di tabel Cfg di bawah (kelompokkan per fitur).
local Hub = ...
local Http = game:GetService("HttpService")
local Util = Hub.use("core/Util")
local Cats = Hub.use("config/Categories")

local FILE = "TOFHub_config.json"

local Cfg = {
    Ver = 4,
    -- Aim
    Aimlock = false, Silent = false, WallCheck = false, ShowFOV = true,
    FOV = 200, Lock = 100, Predict = 0, Part = "HumanoidRootPart", AutoUnstick = true,
    FOVColor = Color3.fromRGB(240, 240, 245),
    -- Deteksi role
    KillerCount = 1, ManualKiller = "",
    -- ESP umum
    ShowLabels = true, -- saklar utama: mati = SEMUA label ESP (pemain, zombie, objek) hilang
    ShowName = true, ShowDist = true, ShowHP = true, ShowRole = true,
    GenBar = true, -- bar progres generator: tampil otomatis di generator yang sedang diperbaiki, tanpa perlu label
    GenHideDone = true, -- ESP generator mati otomatis saat progres penuh (100%)
    FillT = 65, TextSize = 12, ESPMode = "CoreGui",
    ZomAll = false, KeyZombie = "scp2, zombie",
    -- Dunia (lighting)
    Fullbright = false, Bright = 2, AmbientColor = Color3.fromRGB(210, 210, 210),
    ForceTime = false, Time = 14, NoFog = true, NoFx = false,
    -- Dunia (HD grafis)
    HD = false, HDContrast = 12, HDSaturation = 14, HDBloom = 25, HDSun = 5,
    HDShadows = true, HDQuality = true, HDMesh = false, HDFuture = false,
    -- Dunia (shader ala post-processing: hanya visual di klien)
    HDShader = "Realistic", HDTint = Color3.fromRGB(255, 255, 255), HDBrightness = 0, HDExposure = 0,
    HDShadowSoft = 10, HDVignette = 0,
    HDDoF = false, HDDoFDist = 40, HDDoFRadius = 15, HDDoFFar = 30, HDDoFNear = 0,
    HDAtmo = false, HDAtmoDensity = 30, HDAtmoHaze = 15, HDAtmoGlare = 10,
    HDAtmoColor = Color3.fromRGB(199, 199, 199), HDAtmoDecay = Color3.fromRGB(106, 112, 125),
    -- Performa (statistik + FPS booster, hanya sisi klien)
    ShowStats = false, Boost = false, BoostLevel = "Sedang",
    BoostQuality = true, BoostQualityLevel = 3, BoostShadows = true, BoostFx = true, BoostParticles = true,
    BoostTerrain = true, BoostMesh = true, BoostMaterials = false, BoostTextures = false, FpsCap = 0,
    -- Gerak
    Speed = false, SpeedVal = 24, SpeedSafe = true, Noclip = false, Fly = false, FlySpeed = 50,
    -- Violence District
    VDAutoSkillCheck = false, VDSkillMode = "Perfect",
    VDSpeedBoost = false, VDSpeedMultiplier = 0.30, VDSpeedSafeMode = true,
    VDFastVault = false, VDVaultMult = 1.5, VDVaultForce = true, VDVaultAnim = true, VDVaultMode = "Atribut", VDVaultKeys = "vault",
    -- GUI
    Accent = Color3.fromRGB(124, 106, 255), Theme = "Overworld", ShowFloat = true, W = 420, H = 320,
    UIAnim = true, ShowSplash = true, -- ShowSplash: layar loading saat script pertama dijalankan
    -- Config
    AutoSave = true,
}
-- kunci per kategori ESP (dibangkitkan dari config/Categories)
for _, c in ipairs(Cats.list) do
    Cfg[c.on] = true
    Cfg[c.col] = c.def
    Cfg[c.chams] = (c.kind ~= "obj") -- objek: label saja (hemat batas Highlight Roblox)
    Cfg[c.label] = true
    Cfg[c.dist] = 2000
    if c.keyCfg then Cfg[c.keyCfg] = c.keyDef end
end

local Default = {}
for k, v in pairs(Cfg) do Default[k] = v end

local Config = { Cfg = Cfg, Default = Default, FILE = FILE, dirty = false, lastSave = nil, loadInfo = nil }
local Refresh = {}

--------------------------------------------------------
-- Simpan / muat
--------------------------------------------------------
local function serialize()
    local out = {}
    for k, v in pairs(Cfg) do
        if k ~= "ManualKiller" then
            if typeof(v) == "Color3" then out[k] = "#" .. Util.hex(v) else out[k] = v end
        end
    end
    return Http:JSONEncode(out)
end
Config.serialize = serialize

function Config.supported()
    return writefile ~= nil and readfile ~= nil and isfile ~= nil
end

function Config.exists()
    if not (readfile and isfile) then return false end
    local ok, r = pcall(isfile, FILE)
    return ok and r == true
end

function Config.save()
    if not writefile then return false, "Executor tidak punya writefile" end
    local ok, e = pcall(writefile, FILE, serialize())
    if not ok then return false, "Gagal menyimpan: " .. tostring(e) end
    Config.dirty = false
    Config.lastSave = os.time()
    return true, "Config disimpan"
end

-- simpan otomatis 1 detik setelah perubahan terakhir (bila AutoSave aktif)
local saveToken = 0
function Config.markDirty()
    Config.dirty = true
    if not (writefile and Cfg.AutoSave) then return end
    saveToken += 1
    local t = saveToken
    task.delay(1, function()
        if t ~= saveToken or Hub.Dead then return end
        Config.save()
    end)
end

-- simpan sekarang bila masih ada perubahan tertunda (tanpa menunggu debounce)
function Config.flush()
    if not (Config.dirty and Cfg.AutoSave and writefile) then return false end
    saveToken += 1
    local ok = pcall(Config.save)
    return ok
end

local function readData()
    if not Config.exists() then return nil, "file config belum ada" end
    local ok, data = pcall(function() return Http:JSONDecode(readfile(FILE)) end)
    if not (ok and type(data) == "table") then return nil, "file config rusak" end
    -- versi lama tetap dimuat: applyData hanya mengambil kunci yang masih ada dan bertipe sama,
    -- kunci baru memakai default, lalu file ditulis ulang dengan Ver sekarang
    if data.Ver ~= Cfg.Ver then data._migrated = tostring(data.Ver) end
    return data
end

-- salin nilai dari tabel hasil JSON ke Cfg. silent = true: tanpa menyegarkan UI (saat startup)
local function applyData(data, silent)
    local n = 0
    for k, v in pairs(data) do
        if Cfg[k] ~= nil and k ~= "ManualKiller" and k ~= "Ver" and k ~= "_migrated" then
            local nv
            if typeof(Cfg[k]) == "Color3" then
                nv = Util.parseHex(v)
            elseif type(v) == type(Cfg[k]) then
                nv = v
            end
            if nv ~= nil then
                if silent then Cfg[k] = nv else Config.set(k, nv, true) end
                n += 1
            end
        end
    end
    return n
end

function Config.load()
    local data, err = readData()
    if not data then return false, "Gagal memuat: " .. err end
    local n = applyData(data, false)
    Config.dirty = false
    return true, ("Config dimuat (%d opsi)"):format(n)
end

function Config.reset()
    for k, v in pairs(Default) do
        if k ~= "Ver" and k ~= "ManualKiller" then Config.set(k, v, true) end
    end
    Config.markDirty()
end

function Config.delete()
    if not delfile then return false, "Executor tidak punya delfile" end
    if not Config.exists() then return false, "File config belum ada" end
    local ok, e = pcall(delfile, FILE)
    if not ok then return false, "Gagal menghapus: " .. tostring(e) end
    Config.dirty = true
    return true, "File config dihapus"
end

--------------------------------------------------------
-- Sinkronisasi UI
--------------------------------------------------------
function Config.reg(key, fn, first)
    Refresh[key] = Refresh[key] or {}
    if first then table.insert(Refresh[key], 1, fn) else table.insert(Refresh[key], fn) end
end

function Config.set(key, v, silent)
    Cfg[key] = v
    for _, fn in ipairs(Refresh[key] or {}) do pcall(fn) end
    if not silent then Config.markDirty() end
end

-- muat otomatis saat startup (UI belum dibuat, jadi tanpa refresh)
do
    local data, err = readData()
    if data then
        local n = applyData(data, true)
        local msg = ("Config dimuat (%d opsi)"):format(n)
        if data._migrated then
            msg = msg .. (", dimigrasi dari versi %s"):format(data._migrated)
            Config.markDirty() -- tulis ulang dengan Ver sekarang + kunci baru
        end
        Config.loadInfo = { ok = true, msg = msg, n = n }
    else
        Config.loadInfo = { ok = false, msg = err, n = 0 }
    end
    print("[TOFHub] " .. Config.loadInfo.msg)
end

-- saat AutoSave dinyalakan kembali, langsung simpan perubahan yang tertunda
Config.reg("AutoSave", function()
    if Cfg.AutoSave and Config.dirty then Config.save() end
end)

-- simpan perubahan yang tertunda saat script di-unload atau sebelum teleport antar server
Hub.onUnload(function()
    if Config.dirty and Cfg.AutoSave then pcall(Config.save) end
end)
do
    local plr = game:GetService("Players").LocalPlayer
    if plr then
        Hub.track(plr.OnTeleport:Connect(function() Config.flush() end))
    end
end

return Config
