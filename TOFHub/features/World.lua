-- Dunia: fullbright, tanpa kabut, matikan PostEffect, kunci jam, dan mode HD grafis.
-- World.apply() tiap frame; World.fxScan() & World.applyHD() tiap 0.5 detik.
-- Nilai asli dipulihkan saat fitur dimatikan. Semua efek hanya di sisi klien (visual).
-- "Shader" = paket post-processing Roblox (ColorCorrection tint/exposure, DepthOfField, Atmosphere,
-- vignette) — Roblox tidak mengizinkan shader GLSL/HLSL kustom, jadi ini yang paling dekat.
local Hub = ...
local Lighting = game:GetService("Lighting")
local Config = Hub.use("config/Config")
local Cfg = Config.Cfg
local Scheduler = Hub.use("core/Scheduler")
local Util = Hub.use("core/Util")

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
        if e:IsA("Atmosphere") and Cfg.NoFog and not (Cfg.HD and Cfg.HDAtmo) then
            -- saat Atmosfer HD aktif, HD yang mengatur Atmosphere (NoFog dilewati)
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
--------------------------------------------------------
-- Preset "shader": satu tap mengisi semua nilai HD sekaligus (tetap bisa diubah per slider)
--------------------------------------------------------
local HD_KEYS = {
    "HD", "HDContrast", "HDSaturation", "HDBloom", "HDSun", "HDShadows", "HDQuality", "HDMesh", "HDFuture",
    "HDShader", "HDTint", "HDBrightness", "HDExposure", "HDShadowSoft", "HDVignette",
    "HDDoF", "HDDoFDist", "HDDoFRadius", "HDDoFFar", "HDDoFNear",
    "HDAtmo", "HDAtmoDensity", "HDAtmoHaze", "HDAtmoGlare", "HDAtmoColor", "HDAtmoDecay",
}
World.SHADERS = {
    Realistic = {
        HDContrast = 10, HDSaturation = 6, HDBloom = 15, HDSun = 5, HDTint = Color3.fromRGB(255, 255, 255), HDBrightness = 0, HDExposure = 0.1,
        HDShadows = true, HDShadowSoft = 20, HDVignette = 15, HDDoF = false,
        HDAtmo = true, HDAtmoDensity = 25, HDAtmoHaze = 15, HDAtmoGlare = 10, HDAtmoColor = Color3.fromRGB(199, 199, 199), HDAtmoDecay = Color3.fromRGB(106, 112, 125),
    },
    Cinematic = {
        HDContrast = 18, HDSaturation = 4, HDBloom = 30, HDSun = 10, HDTint = Color3.fromRGB(255, 240, 225), HDBrightness = -3, HDExposure = -0.1,
        HDShadows = true, HDShadowSoft = 15, HDVignette = 45,
        HDDoF = true, HDDoFDist = 40, HDDoFRadius = 15, HDDoFFar = 40, HDDoFNear = 0,
        HDAtmo = true, HDAtmoDensity = 30, HDAtmoHaze = 20, HDAtmoGlare = 30, HDAtmoColor = Color3.fromRGB(210, 200, 190), HDAtmoDecay = Color3.fromRGB(120, 100, 90),
    },
    Vibrant = {
        HDContrast = 14, HDSaturation = 30, HDBloom = 35, HDSun = 8, HDTint = Color3.fromRGB(255, 255, 255), HDBrightness = 3, HDExposure = 0.2,
        HDShadows = true, HDShadowSoft = 10, HDVignette = 10, HDDoF = false, HDAtmo = false,
    },
    Dark = {
        HDContrast = 25, HDSaturation = 0, HDBloom = 20, HDSun = 0, HDTint = Color3.fromRGB(215, 225, 255), HDBrightness = -8, HDExposure = -0.5,
        HDShadows = true, HDShadowSoft = 5, HDVignette = 60, HDDoF = false,
        HDAtmo = true, HDAtmoDensity = 40, HDAtmoHaze = 10, HDAtmoGlare = 0, HDAtmoColor = Color3.fromRGB(90, 95, 110), HDAtmoDecay = Color3.fromRGB(40, 45, 60),
    },
    Warm = {
        HDContrast = 10, HDSaturation = 12, HDBloom = 25, HDSun = 10, HDTint = Color3.fromRGB(255, 225, 190), HDBrightness = 2, HDExposure = 0.15,
        HDShadows = true, HDShadowSoft = 25, HDVignette = 20, HDDoF = false,
        HDAtmo = true, HDAtmoDensity = 25, HDAtmoHaze = 10, HDAtmoGlare = 20, HDAtmoColor = Color3.fromRGB(230, 200, 160), HDAtmoDecay = Color3.fromRGB(150, 110, 80),
    },
    Cold = {
        HDContrast = 12, HDSaturation = 8, HDBloom = 20, HDSun = 3, HDTint = Color3.fromRGB(200, 220, 255), HDBrightness = 0, HDExposure = 0,
        HDShadows = true, HDShadowSoft = 15, HDVignette = 20, HDDoF = false,
        HDAtmo = true, HDAtmoDensity = 30, HDAtmoHaze = 15, HDAtmoGlare = 5, HDAtmoColor = Color3.fromRGB(180, 200, 230), HDAtmoDecay = Color3.fromRGB(80, 100, 140),
    },
    Noir = {
        HDContrast = 30, HDSaturation = -100, HDBloom = 15, HDSun = 0, HDTint = Color3.fromRGB(255, 255, 255), HDBrightness = -2, HDExposure = -0.2,
        HDShadows = true, HDShadowSoft = 10, HDVignette = 70, HDDoF = false,
        HDAtmo = true, HDAtmoDensity = 35, HDAtmoHaze = 20, HDAtmoGlare = 0, HDAtmoColor = Color3.fromRGB(150, 150, 150), HDAtmoDecay = Color3.fromRGB(60, 60, 60),
    },
}
World.SHADER_NAMES = { "Realistic", "Cinematic", "Vibrant", "Dark", "Warm", "Cold", "Noir", "Reset" }

-- terapkan preset shader; "Reset" = semua nilai HD kembali ke default (Mode HD tetap menyala)
function World.applyShader(name)
    if name == "Reset" then
        for _, k in ipairs(HD_KEYS) do
            if k ~= "HD" and k ~= "HDShader" then Config.set(k, Config.Default[k], true) end
        end
        Config.markDirty()
    else
        local p = World.SHADERS[name]
        if not p then return end
        for k, v in pairs(p) do Config.set(k, v, true) end
        Config.markDirty()
    end
    if not Cfg.HD then Config.set("HD", true) else World.applyHD() end
end

local HD = {
    saved = nil, meshOn = false, futureOn = false, scanTok = 0,
    mesh = setmetatable({}, { __mode = "k" }), -- MeshPart -> RenderFidelity asli
    atmo = nil, -- Atmosphere milik game yang nilainya kita ubah (+ nilai aslinya)
    vignette = nil,
}
World.hd = HD
local LIGHT_PROPS = { "GlobalShadows", "ShadowSoftness", "EnvironmentSpecularScale", "EnvironmentDiffuseScale", "ExposureCompensation" }
local ATMO_PROPS = { "Density", "Offset", "Color", "Decay", "Glare", "Haze" }
local HD_FX = { "TOFHD_CC", "TOFHD_Bloom", "TOFHD_Sun", "TOFHD_DoF" }

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
        Util.eachDescendant(workspace, function(d)
            if d:IsA("MeshPart") then meshHD(d) end
        end, function() return tok == HD.scanTok and not Hub.Dead end)
    else
        for part, fid in pairs(HD.mesh) do
            pcall(function() if part.Parent then part.RenderFidelity = fid end end)
            HD.mesh[part] = nil
        end
    end
end

--------------------------------------------------------
-- Atmosfer: pakai Atmosphere milik game bila ada (Roblox hanya memakai satu), kalau tidak buat sendiri
--------------------------------------------------------
local function atmoOff()
    local a = HD.atmo
    HD.atmo = nil
    if not a then return end
    if a.own then
        pcall(function() a.inst:Destroy() end)
    elseif a.inst.Parent then
        for k, v in pairs(a.saved) do pcall(function() a.inst[k] = v end) end
    end
end

local function applyAtmo()
    if not Cfg.HDAtmo then
        if HD.atmo then atmoOff() end
        return
    end
    local a = HD.atmo
    if a and (not a.inst.Parent) then atmoOff() a = nil end
    if not a then
        local existing
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("Atmosphere") and e.Name ~= "TOFHD_Atmo" then existing = e break end
        end
        if existing then
            local saved = {}
            for _, k in ipairs(ATMO_PROPS) do pcall(function() saved[k] = existing[k] end) end
            -- bila NoFog sudah menolkan Density/Haze, pakai nilai asli yang disimpan fxScan
            local fx = World.fx[existing]
            if fx and fx.kind == "atm" then saved.Density, saved.Haze = fx.Density, fx.Haze end
            a = { inst = existing, saved = saved, own = false }
        else
            local inst = Instance.new("Atmosphere")
            inst.Name = "TOFHD_Atmo"
            inst.Parent = Lighting
            a = { inst = inst, saved = {}, own = true }
        end
        HD.atmo = a
    end
    pcall(function()
        a.inst.Density = Cfg.HDAtmoDensity / 100
        a.inst.Haze = Cfg.HDAtmoHaze / 10
        a.inst.Glare = Cfg.HDAtmoGlare / 50
        a.inst.Color = Cfg.HDAtmoColor
        a.inst.Decay = Cfg.HDAtmoDecay
        a.inst.Offset = 0.25
    end)
end

--------------------------------------------------------
-- Vignette: empat strip gradien hitam di tepi layar (ScreenGui sendiri, di bawah UI hub)
--------------------------------------------------------
local function ensureVignette()
    if HD.vignette and HD.vignette.Parent then return HD.vignette end
    local container = (gethui and gethui()) or game:GetService("CoreGui")
    local gui = Instance.new("ScreenGui")
    gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset, gui.DisplayOrder = "TOFHD_Vignette", false, true, -5
    local seq = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1) })
    local strips = {}
    for i, d in ipairs({
        { Vector2.new(0, 0), UDim2.fromScale(1, 0.35), 90 },  -- atas
        { Vector2.new(0, 1), UDim2.fromScale(1, 0.35), -90 }, -- bawah
        { Vector2.new(0, 0), UDim2.fromScale(0.3, 1), 0 },    -- kiri
        { Vector2.new(1, 0), UDim2.fromScale(0.3, 1), 180 },  -- kanan
    }) do
        local f = Instance.new("Frame")
        f.AnchorPoint, f.Size, f.BorderSizePixel = d[1], d[2], 0
        f.Position = UDim2.fromScale(d[1].X, d[1].Y)
        f.BackgroundColor3 = Color3.new(0, 0, 0)
        local g = Instance.new("UIGradient")
        g.Transparency, g.Rotation = seq, d[3]
        g.Parent = f
        f.Parent = gui
        strips[i] = f
    end
    gui.Parent = container
    HD.vignette = gui
    HD.vignetteStrips = strips
    return gui
end

local function applyVignette()
    local v = Cfg.HDVignette or 0
    if v <= 0 then
        if HD.vignette then pcall(function() HD.vignette:Destroy() end) HD.vignette = nil end
        return
    end
    ensureVignette()
    for _, f in ipairs(HD.vignetteStrips) do f.BackgroundTransparency = 1 - v / 100 end
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
    for _, name in ipairs(HD_FX) do
        local o = Lighting:FindFirstChild(name)
        if o then pcall(function() o:Destroy() end) end
    end
    atmoOff()
    if HD.vignette then pcall(function() HD.vignette:Destroy() end) HD.vignette = nil end
    if HD.meshOn then setMesh(false) end
    if HD.futureOn then setFuture(false) end
    if s then
        for _, k in ipairs(LIGHT_PROPS) do
            if s[k] ~= nil then pcall(function() Lighting[k] = s[k] end) end
        end
        local r = Util.rendering()
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
        local r = Util.rendering()
        if r then pcall(function() s.Quality = r.QualityLevel end) end
        if gethiddenproperty then pcall(function() s.Tech = gethiddenproperty(Lighting, "Technology") end) end
        HD.saved = s
    end

    -- koreksi warna + bloom + sun rays (dibuat ulang bila game menghapusnya)
    local cc = ensureFx("ColorCorrectionEffect", "TOFHD_CC")
    cc.Contrast = Cfg.HDContrast / 100
    cc.Saturation = Cfg.HDSaturation / 100
    cc.Brightness = Cfg.HDBrightness / 100
    cc.TintColor = Cfg.HDTint
    local bloom = ensureFx("BloomEffect", "TOFHD_Bloom")
    bloom.Intensity = Cfg.HDBloom / 100
    bloom.Size = 20
    bloom.Threshold = 1.1
    local sun = ensureFx("SunRaysEffect", "TOFHD_Sun")
    sun.Enabled = Cfg.HDSun > 0
    sun.Intensity, sun.Spread = Cfg.HDSun / 100, 0.6

    -- lensa: depth of field (blur latar seperti kamera)
    local dof = ensureFx("DepthOfFieldEffect", "TOFHD_DoF")
    dof.Enabled = Cfg.HDDoF
    dof.FocusDistance = Cfg.HDDoFDist
    dof.InFocusRadius = Cfg.HDDoFRadius
    dof.FarIntensity = Cfg.HDDoFFar / 100
    dof.NearIntensity = Cfg.HDDoFNear / 100

    applyAtmo()
    applyVignette()

    -- bayangan + pantulan lingkungan penuh + exposure
    pcall(function()
        Lighting.GlobalShadows = Cfg.HDShadows
        Lighting.ShadowSoftness = Cfg.HDShadowSoft / 100
        Lighting.EnvironmentSpecularScale = 1
        Lighting.EnvironmentDiffuseScale = 1
        Lighting.ExposureCompensation = Cfg.HDExposure
    end)

    -- kualitas render
    local r = Util.rendering()
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
for _, k in ipairs(HD_KEYS) do
    if k ~= "HDShader" then Config.reg(k, function() World.applyHD() end) end
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
