-- Konfigurasi: nilai awal, simpan/muat JSON, dan sinkronisasi ke komponen UI.
--   Config.Cfg          tabel nilai aktif (baca langsung: Cfg.FOV)
--   Config.Default      salinan nilai awal
--   Config.set(k,v[,s]) ubah nilai + segarkan UI + simpan otomatis (s = true: jangan tandai berubah)
--   Config.reg(k,f)     daftarkan fungsi yang dipanggil tiap Cfg[k] berubah lewat set()
--   Config.save()       simpan SEKARANG ke file          -> ok, pesan
--   Config.load()       muat dari file + segarkan UI     -> ok, pesan
--   Config.reset()      kembalikan semua ke default
--   Config.delete()     hapus file config                -> ok, pesan
--   Config.serialize()  config sebagai string JSON (untuk disalin)
--   Config.dirty        true bila ada perubahan yang belum tersimpan ke file
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
    HD = false, HDPreset = "Tinggi", HDContrast = 12, HDSaturation = 14, HDBloom = 25,
    HDShadows = true, HDQuality = true, HDMesh = false, HDFuture = false,
    -- Gerak
    Speed = false, SpeedVal = 24, SpeedSafe = true, Noclip = false, Fly = false, FlySpeed = 50,
    -- Violence District
    VDAutoSkillCheck = false, VDSkillMode = "Perfect",
    VDSpeedBoost = false, VDSpeedMultiplier = 0.30, VDSpeedSafeMode = true,
    VDFastVault = false, VDVaultMult = 1.5, VDVaultForce = true, VDVaultMode = "Atribut", VDVaultKeys = "vault",
    -- GUI
    Accent = Color3.fromRGB(124, 106, 255), Theme = "Overworld", ShowFloat = true, W = 420, H = 320,
    UIAnim = true,
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

local Config = { Cfg = Cfg, Default = Default, FILE = FILE, dirty = false, lastSave = nil }
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

local function readData()
    if not Config.exists() then return nil, "file config belum ada" end
    local ok, data = pcall(function() return Http:JSONDecode(readfile(FILE)) end)
    if not (ok and type(data) == "table") then return nil, "file config rusak" end
    -- config versi lama dilewati supaya default baru terpakai
    if data.Ver ~= Cfg.Ver then return nil, "versi config berbeda" end
    return data
end

-- salin nilai dari tabel hasil JSON ke Cfg. silent = true: tanpa menyegarkan UI (saat startup)
local function applyData(data, silent)
    local n = 0
    for k, v in pairs(data) do
        if Cfg[k] ~= nil and k ~= "ManualKiller" and k ~= "Ver" then
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
function Config.reg(key, fn)
    Refresh[key] = Refresh[key] or {}
    table.insert(Refresh[key], fn)
end

function Config.set(key, v, silent)
    Cfg[key] = v
    for _, fn in ipairs(Refresh[key] or {}) do pcall(fn) end
    if not silent then Config.markDirty() end
end

-- muat saat startup (UI belum dibuat, jadi tanpa refresh)
do
    local data = readData()
    if data then applyData(data, true) end
end

-- simpan perubahan yang tertunda saat script di-unload
Hub.onUnload(function()
    if Config.dirty and Cfg.AutoSave then pcall(Config.save) end
end)

return Config
