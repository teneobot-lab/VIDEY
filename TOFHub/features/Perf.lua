-- Performa: statistik FPS/ping/memori + FPS Booster (turunkan beban render di sisi klien).
--   Perf.fps / Perf.minFps / Perf.ping / Perf.mem   statistik, diperbarui tiap 0.5 detik
--   Perf.applyLevel(name)   isi semua toggle booster sekaligus (Ringan/Sedang/Maks) lalu nyalakan Boost
--   Perf.refresh()          terapkan ulang booster sesuai Cfg (dipanggil otomatis saat Cfg.Boost* berubah)
-- Semua nilai asli (material, partikel, bayangan, kualitas, terrain) disimpan dan dipulihkan saat
-- Boost dimatikan atau script di-unload. Boost dan Mode HD saling mematikan (tujuannya berlawanan).
local Hub = ...
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local Config = Hub.use("config/Config")
local Cfg = Config.Cfg
local Scheduler = Hub.use("core/Scheduler")
local Util = Hub.use("core/Util")

local Perf = { fps = 60, minFps = 60, ping = 0, mem = 0, count = 0, status = "mati" }

--------------------------------------------------------
-- Statistik
--------------------------------------------------------
local hist = {}
local function updateStats()
    Perf.fps = Scheduler.fps
    hist[#hist + 1] = Perf.fps
    if #hist > 10 then table.remove(hist, 1) end -- 5 detik terakhir
    local m = math.huge
    for _, v in ipairs(hist) do if v < m then m = v end end
    Perf.minFps = m
    pcall(function() Perf.ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
    pcall(function() Perf.mem = math.floor(Stats:GetTotalMemoryUsageMb()) end)
end

--------------------------------------------------------
-- FPS Booster
--------------------------------------------------------
Perf.LEVELS = {
    Ringan = { BoostQuality = true, BoostQualityLevel = 5, BoostShadows = true, BoostFx = false, BoostParticles = true, BoostTerrain = false, BoostMesh = false, BoostMaterials = false, BoostTextures = false },
    Sedang = { BoostQuality = true, BoostQualityLevel = 3, BoostShadows = true, BoostFx = true, BoostParticles = true, BoostTerrain = true, BoostMesh = true, BoostMaterials = false, BoostTextures = false },
    Maks = { BoostQuality = true, BoostQualityLevel = 1, BoostShadows = true, BoostFx = true, BoostParticles = true, BoostTerrain = true, BoostMesh = true, BoostMaterials = true, BoostTextures = true },
}
Perf.LEVEL_NAMES = { "Ringan", "Sedang", "Maks" }
local BOOST_KEYS = { "BoostQuality", "BoostQualityLevel", "BoostShadows", "BoostFx", "BoostParticles", "BoostTerrain", "BoostMesh", "BoostMaterials", "BoostTextures" }

local B = {
    on = false, saved = nil, tok = 0, conn = nil,
    inst = setmetatable({}, { __mode = "k" }), -- inst -> { prop = nilai asli }
}
Perf.boost = B
local LIGHT_PROPS = { "GlobalShadows" }
local TERRAIN_PROPS = { "Decoration", "WaterWaveSize", "WaterWaveSpeed", "WaterReflectance" }
local PARTICLES = { "ParticleEmitter", "Trail", "Beam", "Smoke", "Fire", "Sparkles" }

local function save(inst, prop)
    local d = B.inst[inst]
    if not d then d = {} B.inst[inst] = d end
    if d[prop] == nil then
        local ok, v = pcall(function() return inst[prop] end)
        if not ok then return false end
        d[prop] = v
    end
    return true
end

local function isParticle(d)
    for _, c in ipairs(PARTICLES) do if d:IsA(c) then return true end end
    return false
end

local function proc(d)
    if Cfg.BoostParticles and isParticle(d) then
        if save(d, "Enabled") then pcall(function() d.Enabled = false end) Perf.count += 1 end
    elseif d:IsA("BasePart") and not d:IsA("Terrain") then
        if Cfg.BoostMaterials then
            if save(d, "Material") and save(d, "Reflectance") then
                pcall(function() d.Material = Enum.Material.SmoothPlastic d.Reflectance = 0 end)
                Perf.count += 1
            end
        end
        if Cfg.BoostMesh and d:IsA("MeshPart") then
            if save(d, "RenderFidelity") then pcall(function() d.RenderFidelity = Enum.RenderFidelity.Performance end) end
        end
        if Cfg.BoostShadows then
            if save(d, "CastShadow") then pcall(function() d.CastShadow = false end) end
        end
    elseif Cfg.BoostTextures and (d:IsA("Decal") or d:IsA("Texture")) then
        if save(d, "Transparency") then pcall(function() d.Transparency = 1 end) Perf.count += 1 end
    end
end

-- Lighting/render/terrain ditegaskan ulang tiap 0.5 detik (game bisa mengubahnya kembali)
local function applyGlobals()
    local s = B.saved
    pcall(function() Lighting.GlobalShadows = not Cfg.BoostShadows and s.GlobalShadows or false end)
    local r = Util.rendering()
    if r then
        pcall(function()
            if Cfg.BoostQuality then
                r.QualityLevel = Enum.QualityLevel[("Level%02d"):format(math.clamp(Cfg.BoostQualityLevel, 1, 21))]
            elseif s.Quality ~= nil then
                r.QualityLevel = s.Quality
            end
        end)
        pcall(function()
            if Cfg.BoostMesh then r.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
            elseif s.MeshDetail ~= nil then r.MeshPartDetailLevel = s.MeshDetail end
        end)
    end
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if terrain and s.Terrain then
        pcall(function()
            if Cfg.BoostTerrain then
                terrain.Decoration = false
                terrain.WaterWaveSize, terrain.WaterWaveSpeed, terrain.WaterReflectance = 0, 0, 0
            else
                for k, v in pairs(s.Terrain) do terrain[k] = v end
            end
        end)
    end
    for _, e in ipairs(Lighting:GetChildren()) do
        if e:IsA("PostEffect") and e.Name:sub(1, 5) ~= "TOFHD" then
            if Cfg.BoostFx then
                if save(e, "Enabled") then pcall(function() e.Enabled = false end) end
            end
        end
    end
end

local function boostOff()
    B.tok += 1
    if B.conn then B.conn:Disconnect() B.conn = nil end
    local s = B.saved
    if s then
        for _, k in ipairs(LIGHT_PROPS) do
            if s[k] ~= nil then pcall(function() Lighting[k] = s[k] end) end
        end
        local r = Util.rendering()
        if r then
            if s.Quality ~= nil then pcall(function() r.QualityLevel = s.Quality end) end
            if s.MeshDetail ~= nil then pcall(function() r.MeshPartDetailLevel = s.MeshDetail end) end
        end
        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if terrain and s.Terrain then
            for k, v in pairs(s.Terrain) do pcall(function() terrain[k] = v end) end
        end
    end
    for inst, d in pairs(B.inst) do
        if inst.Parent then
            for k, v in pairs(d) do pcall(function() inst[k] = v end) end
        end
        B.inst[inst] = nil
    end
    B.saved = nil
    B.on = false
    Perf.count = 0
    Perf.status = "mati"
end

local function boostOn()
    local s = {}
    for _, k in ipairs(LIGHT_PROPS) do pcall(function() s[k] = Lighting[k] end) end
    local r = Util.rendering()
    if r then
        pcall(function() s.Quality = r.QualityLevel end)
        pcall(function() s.MeshDetail = r.MeshPartDetailLevel end)
    end
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        s.Terrain = {}
        for _, k in ipairs(TERRAIN_PROPS) do pcall(function() s.Terrain[k] = terrain[k] end) end
    end
    B.saved = s
    B.on = true
    Perf.count = 0
    applyGlobals()

    B.tok += 1
    local tok = B.tok
    Perf.status = "memindai..."
    B.conn = Hub.track(workspace.DescendantAdded:Connect(function(d)
        if B.on and not Hub.Dead then proc(d) end
    end))
    Util.eachDescendant(workspace, proc,
        function() return tok == B.tok and not Hub.Dead end,
        function() Perf.status = "aktif" end)
end

function Perf.refresh()
    if Cfg.Boost then
        if B.on then boostOff() end
        boostOn()
    elseif B.on then
        boostOff()
    end
end

function Perf.applyLevel(name)
    local p = Perf.LEVELS[name]
    if not p then return end
    for k, v in pairs(p) do Config.set(k, v, true) end
    Config.markDirty()
    if not Cfg.Boost then Config.set("Boost", true) else Perf.refresh() end
end

--------------------------------------------------------
-- Batas FPS (setfpscap milik executor; 0 = tidak diubah)
--------------------------------------------------------
Perf.capSupported = type(setfpscap) == "function"
local capChanged = false
local function applyCap()
    if not Perf.capSupported then return end
    local v = Cfg.FpsCap
    if v and v > 0 then
        pcall(setfpscap, v)
        capChanged = true
    elseif capChanged then
        pcall(setfpscap, 60)
        capChanged = false
    end
end

--------------------------------------------------------
-- Pendaftaran
--------------------------------------------------------
-- Boost dan HD saling mematikan; handler ini didaftarkan paling depan supaya pemulihan Boost
-- terjadi SEBELUM World.applyHD menyimpan keadaan Lighting (dan sebaliknya)
Config.reg("HD", function()
    if Cfg.HD and Cfg.Boost then Config.set("Boost", false) end
end, true)
Config.reg("Boost", function()
    if Cfg.Boost and Cfg.HD then Config.set("HD", false) end
end, true)
Config.reg("Boost", Perf.refresh)
for _, k in ipairs(BOOST_KEYS) do Config.reg(k, function() if Cfg.Boost then Perf.refresh() end end) end
Config.reg("FpsCap", applyCap)

Scheduler.add("Perf", 0.5, function()
    updateStats()
    if Cfg.Boost and B.on then applyGlobals() end
end)

task.defer(function()
    if Hub.Dead then return end
    if Cfg.Boost then Perf.refresh() end
    applyCap()
end)

Hub.onUnload(function()
    if B.on then boostOff() end
    if capChanged then pcall(setfpscap, 60) end
end)

return Perf
