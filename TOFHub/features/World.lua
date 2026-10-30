-- Dunia: fullbright, tanpa kabut, matikan PostEffect, kunci jam, dan mode HD grafis.
-- World.apply() tiap frame; World.fxScan() & World.applyHD() tiap 0.5 detik.
-- Nilai asli dipulihkan saat fitur dimatikan. Semua efek hanya di sisi klien (visual).
local Hub = ...
local Lighting = game:GetService("Lighting")
local Config = Hub.use("config/Config")
local Cfg = Config.Cfg
local Scheduler = Hub.use("core/Scheduler")

local World = { saved = nil, fx = {} }

local function restoreFx(onlyKind)
    for inst, d in pairs(World.fx) do
        if not onlyKind or d.kind == onlyKind then
            if inst.Parent then
                pcall(function()
                    if d.kind == "atm" then inst.Density, inst.Haze = d.Density, d.Haze
                    else inst.Enabled = d.Enabled end
                end)
            end
            World.fx[inst] = nil
        end
    end
end

function World.apply()
    if not Cfg.Fullbright then
        if World.saved then
            for k, v in pairs(World.saved) do pcall(function() Lighting[k] = v end) end
            World.saved = nil
            restoreFx()
        end
        return
    end
    if not World.saved then
        World.saved = {
            Brightness = Lighting.Brightness, Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient, ClockTime = Lighting.ClockTime,
            FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
        }
    end
    Lighting.Brightness = Cfg.Bright
    Lighting.Ambient = Cfg.AmbientColor
    Lighting.OutdoorAmbient = Cfg.AmbientColor
    if Cfg.ForceTime then Lighting.ClockTime = Cfg.Time end
    if Cfg.NoFog then Lighting.FogEnd, Lighting.FogStart = 1e6, 1e5 end
end

function World.fxScan()
    if not Cfg.Fullbright then return end
    if not Cfg.NoFog then restoreFx("atm") end
    if not Cfg.NoFx then restoreFx("fx") end
    for _, e in ipairs(Lighting:GetChildren()) do
        if e:IsA("Atmosphere") and Cfg.NoFog then
            if not World.fx[e] then World.fx[e] = { kind = "atm", Density = e.Density, Haze = e.Haze } end
            e.Density, e.Haze = 0, 0
        elseif e:IsA("PostEffect") and Cfg.NoFx and e.Name:sub(1, 5) ~= "TOFHD" then
            -- efek milik mode HD (nama "TOFHD_*") tidak ikut dimatikan
            if not World.fx[e] then World.fx[e] = { kind = "fx", Enabled = e.Enabled } end
            e.Enabled = false
        end
    end
end

--------------------------------------------------------
-- Mode HD: koreksi warna (kontras/saturasi), bloom, sun rays, bayangan tajam,
-- kualitas render maksimum, detail mesh maksimum, dan (opsional) Future lighting.
--------------------------------------------------------
World.PRESETS = {
    Sedang = { HDContrast = 6, HDSaturation = 8, HDBloom = 15 },
    Tinggi = { HDContrast = 12, HDSaturation = 14, HDBloom = 25 },
    Ultra = { HDContrast = 20, HDSaturation = 20, HDBloom = 40 },
}
World.PRESET_NAMES = { "Sedang", "Tinggi", "Ultra" }
local SUN = { Sedang = 0, Tinggi = 0.05, Ultra = 0.1 }

function World.applyPreset(name)
    local p = World.PRESETS[name]
    if not p then return end
    for k, v in pairs(p) do Config.set(k, v) end
end

local HD = {
    saved = nil, meshOn = false, futureOn = false, scanTok = 0,
    mesh = setmetatable({}, { __mode = "k" }), -- MeshPart -> RenderFidelity asli
}
World.hd = HD
local LIGHT_PROPS = { "GlobalShadows", "ShadowSoftness", "EnvironmentSpecularScale", "EnvironmentDiffuseScale" }

local function ensureFx(class, name)
    local o = Lighting:FindFirstChild(name)
    if o and not o:IsA(class) then o:Destroy() o = nil end
    if not o then
        o = Instance.new(class)
        o.Name = name
        o.Parent = Lighting
    end
    return o
end

local function rendering()
    local ok, r = pcall(function() return settings().Rendering end)
    return ok and r or nil
end

local function meshHD(d)
    if HD.mesh[d] == nil then
        local ok, v = pcall(function() return d.RenderFidelity end)
        if not ok then return end
        HD.mesh[d] = v
    end
    pcall(function() d.RenderFidelity = Enum.RenderFidelity.Precise end)
end

local function setMesh(on)
    HD.scanTok += 1
    local tok = HD.scanTok
    HD.meshOn = on
    if on then
        task.spawn(function()
            local n = 0
            for _, d in ipairs(workspace:GetDescendants()) do
                if tok ~= HD.scanTok or Hub.Dead then return end
                if d:IsA("MeshPart") then meshHD(d) end
                n += 1
                if n % 1500 == 0 then task.wait() end
            end
        end)
    else
        for part, fid in pairs(HD.mesh) do
            pcall(function() if part.Parent then part.RenderFidelity = fid end end)
            HD.mesh[part] = nil
        end
    end
end

local function setFuture(on)
    HD.futureOn = on
    if not sethiddenproperty then return end
    pcall(function()
        if on then
            sethiddenproperty(Lighting, "Technology", Enum.Technology.Future)
        elseif HD.saved and HD.saved.Tech ~= nil then
            sethiddenproperty(Lighting, "Technology", HD.saved.Tech)
        end
    end)
end

function World.hdOff()
    local s = HD.saved
    for _, name in ipairs({ "TOFHD_CC", "TOFHD_Bloom", "TOFHD_Sun" }) do
        local o = Lighting:FindFirstChild(name)
        if o then pcall(function() o:Destroy() end) end
    end
    if HD.meshOn then setMesh(false) end
    if HD.futureOn then setFuture(false) end
    if s then
        for _, k in ipairs(LIGHT_PROPS) do
            if s[k] ~= nil then pcall(function() Lighting[k] = s[k] end) end
        end
        local r = rendering()
        if r and s.Quality ~= nil then pcall(function() r.QualityLevel = s.Quality end) end
    end
    HD.saved = nil
end

function World.applyHD()
    if not Cfg.HD then
        if HD.saved then World.hdOff() end
        return
    end
    if not HD.saved then
        local s = {}
        for _, k in ipairs(LIGHT_PROPS) do pcall(function() s[k] = Lighting[k] end) end
        local r = rendering()
        if r then pcall(function() s.Quality = r.QualityLevel end) end
        if gethiddenproperty then pcall(function() s.Tech = gethiddenproperty(Lighting, "Technology") end) end
        HD.saved = s
    end

    -- koreksi warna + bloom + sun rays (dibuat ulang bila game menghapusnya)
    local cc = ensureFx("ColorCorrectionEffect", "TOFHD_CC")
    cc.Contrast = Cfg.HDContrast / 100
    cc.Saturation = Cfg.HDSaturation / 100
    local bloom = ensureFx("BloomEffect", "TOFHD_Bloom")
    bloom.Intensity = Cfg.HDBloom / 100
    bloom.Size = 20
    bloom.Threshold = 1.1
    local sunI = SUN[Cfg.HDPreset] or 0
    local sun = ensureFx("SunRaysEffect", "TOFHD_Sun")
    sun.Enabled = sunI > 0
    sun.Intensity, sun.Spread = sunI, 0.6

    -- bayangan tajam + pantulan lingkungan penuh
    pcall(function()
        Lighting.GlobalShadows = Cfg.HDShadows
        Lighting.ShadowSoftness = 0.1
        Lighting.EnvironmentSpecularScale = 1
        Lighting.EnvironmentDiffuseScale = 1
    end)

    -- kualitas render
    local r = rendering()
    if r and HD.saved.Quality ~= nil then
        pcall(function()
            local want = Cfg.HDQuality and Enum.QualityLevel.Level21 or HD.saved.Quality
            if r.QualityLevel ~= want then r.QualityLevel = want end
        end)
    end

    if Cfg.HDMesh ~= HD.meshOn then setMesh(Cfg.HDMesh) end
    if Cfg.HDFuture ~= HD.futureOn then setFuture(Cfg.HDFuture) end
end

-- MeshPart baru ikut detail maksimum selama opsinya aktif
Hub.track(workspace.DescendantAdded:Connect(function(d)
    if HD.meshOn and Cfg.HD and d:IsA("MeshPart") then meshHD(d) end
end))

-- respon instan saat slider/toggle HD diubah (selain tick 0.5 detik)
for _, k in ipairs({ "HD", "HDPreset", "HDContrast", "HDSaturation", "HDBloom", "HDShadows", "HDQuality", "HDMesh", "HDFuture" }) do
    Config.reg(k, function() World.applyHD() end)
end

Scheduler.add("Dunia fx", 0.5, World.fxScan)
Scheduler.add("Dunia HD", 0.5, World.applyHD)
Scheduler.add("Dunia", 0, World.apply)

Hub.onUnload(function()
    Cfg.Fullbright = false
    Cfg.HD = false
    pcall(World.apply)
    pcall(World.hdOff)
end)

return World
