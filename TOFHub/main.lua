--========================================================
-- TOF HUB v4 | main.lua
-- Entry point: loader modul + siklus hidup (start / unload)
--
-- Tiga cara menjalankan (pilih salah satu):
--   1. Folder lokal : taruh folder TOFHub/ di workspace executor, jalankan main.lua
--   2. Online       : isi BASE_URL dengan URL folder (harus diakhiri "/")
--   3. Bundle       : TOFHub_bundle.lua (hasil build.py, semua modul jadi satu file)
--
-- Aturan modul: tiap file diawali `local Hub = ...` dan diakhiri `return <tabel/fungsi>`.
-- Ambil dependensi lewat Hub.use("folder/Nama"); hasilnya di-cache.
--========================================================
if getgenv and getgenv().TOFHubUnload then pcall(getgenv().TOFHubUnload) end

local ROOT = "TOFHub" -- nama folder di workspace executor (mode lokal)
local BASE_URL = nil  -- contoh: "https://raw.githubusercontent.com/user/repo/main/TOFHub/"

local BUNDLE -- @bundle (baris ini diganti otomatis oleh build.py)

local Hub = { Dead = false, Err = {}, conns = {}, cleanups = {}, cache = {}, loading = {} }

--------------------------------------------------------
-- Utilitas inti yang dipakai semua modul
--------------------------------------------------------
-- sambungkan event supaya otomatis diputus saat unload
function Hub.track(c)
    Hub.conns[#Hub.conns + 1] = c
    return c
end

-- jalankan fungsi aman; error disimpan dan tampil di Dashboard > Diagnostik
function Hub.safe(name, fn, ...)
    local ok, e = pcall(fn, ...)
    if ok then
        Hub.Err[name] = nil
    else
        e = tostring(e)
        if Hub.Err[name] ~= e then warn("[TOFHub] " .. name .. ": " .. e) end
        Hub.Err[name] = e
    end
end

-- daftarkan pembersih; dijalankan terbalik (daftar terakhir = jalan pertama) saat unload
function Hub.onUnload(fn)
    Hub.cleanups[#Hub.cleanups + 1] = fn
end

--------------------------------------------------------
-- Loader modul
--------------------------------------------------------
local function readSource(name)
    local path = name .. ".lua"
    if BASE_URL then
        local stamp = tostring(os.time()) .. tostring(math.floor(os.clock() * 1000))
        return game:HttpGet(BASE_URL .. path .. "?v=" .. stamp)
    end
    return readfile(ROOT .. "/" .. path)
end

function Hub.use(name)
    local cached = Hub.cache[name]
    if cached ~= nil then return cached end
    if Hub.loading[name] then error("dependensi melingkar: " .. name, 0) end
    Hub.loading[name] = true

    local chunk
    if BUNDLE then
        chunk = BUNDLE[name]
        if not chunk then error("modul tidak ada di bundle: " .. name, 0) end
    else
        local f, e = loadstring(readSource(name), "=" .. name)
        if not f then error("sintaks " .. name .. ": " .. tostring(e), 0) end
        chunk = f
    end

    local ok, res = pcall(chunk, Hub)
    Hub.loading[name] = nil
    if not ok then error("modul " .. name .. ": " .. tostring(res), 0) end
    if res == nil then res = true end
    Hub.cache[name] = res
    return res
end

-- daftarkan fungsi yang dijalankan saat semua modul selesai dimuat (setelah layar loading hilang)
Hub.readyFns = {}
function Hub.onReady(fn)
    if Hub.isReady then task.defer(fn) else Hub.readyFns[#Hub.readyFns + 1] = fn end
end
function Hub.ready()
    if Hub.isReady or Hub.Dead then return end
    Hub.isReady = true
    for _, fn in ipairs(Hub.readyFns) do Hub.safe("ready", fn) end
end

function Hub.unload()
    if Hub.Dead then return end
    Hub.Dead = true
    for i = #Hub.cleanups, 1, -1 do pcall(Hub.cleanups[i]) end
    for _, c in ipairs(Hub.conns) do pcall(function() c:Disconnect() end) end
end
if getgenv then getgenv().TOFHubUnload = Hub.unload end

--------------------------------------------------------
-- Daftar modul yang dijalankan (urutan tab = urutan di sini)
--------------------------------------------------------
local BOOT = {
    -- logika
    "core/Roles", "features/Aim", "features/World", "features/Movement",
    "esp/Players", "esp/Zombies", "esp/Objects",
    -- UI dasar
    "ui/Window", "ui/FovCircle",
    -- tab (urutan = urutan di sidebar; tambah tab baru = tambah satu baris)
    "ui/tabs/Dashboard", "ui/tabs/Aim", "ui/tabs/ESP",
    "ui/tabs/World", "ui/tabs/Move", "ui/tabs/ViolenceDistrict", "ui/tabs/Settings",
    "ui/FloatButton",
}

-- layar loading (ui/Splash) tampil lebih dulu; bar progres bergerak tiap modul dimuat
local Splash = nil
if Hub.use("config/Config").Cfg.ShowSplash ~= false then
    local okS, res = pcall(Hub.use, "ui/Splash")
    if okS then Splash = res else warn("[TOFHub] Splash dilewati: " .. tostring(res)) end
end

local ok, err = pcall(function()
    for i, name in ipairs(BOOT) do
        if Splash then
            Splash.step(i, #BOOT, name)
            task.wait() -- beri satu frame supaya progres sempat digambar
        end
        Hub.use(name)
    end
    local Page = Hub.use("ui/Page")
    Page.select(Page.list[1])
    if Splash then Splash.finish() else Hub.ready() end
end)
if not ok then
    warn("[TOFHub] gagal start: " .. tostring(err))
    if Splash then pcall(Splash.fail, err) end
    Hub.unload()
end
