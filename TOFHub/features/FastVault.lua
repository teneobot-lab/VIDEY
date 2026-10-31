-- Violence District: Fast Vaulting (percepat vault jendela).
-- Hasil logger: vault dijalankan CLIENT. Karakter punya atribut `vaultspeed` (default 1) yang dipakai game
-- untuk kecepatan animasi "RunningVaultAnimation"; gerakan vault ikut animasi lewat marker keyframe
-- "CFRAME;x,y,z", jadi animasi lebih cepat = vault lebih cepat.
-- Dua metode (Cfg.VDVaultMode):
--   Atribut  : atribut karakter `vaultspeed` dikali Cfg.VDVaultMult (cara bawaan game, nilai asli dipulihkan)
--   Animasi  : AnimationTrack yang namanya cocok kata kunci (Cfg.VDVaultKeys) dipercepat lewat AdjustSpeed
-- Dimatikan / unload -> nilai asli dipulihkan. Server tetap menerima remote VaultEvent/VaultComplete
-- lebih cepat dari biasanya; pakai kelipatan kecil dulu.
local Hub = ...
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local Config = Hub.use("config/Config")
local Cfg = Config.Cfg
local Util = Hub.use("core/Util")
local Scheduler = Hub.use("core/Scheduler")

local ATTR = "vaultspeed"
local FV = { keys = {}, recent = {}, boosted = 0, status = "Mati", attr = { char = nil, orig = nil, set = nil } }
local base = setmetatable({}, { __mode = "k" }) -- AnimationTrack -> kecepatan asli
local animator, conn

function FV.rebuild() FV.keys = Util.splitKeys(Cfg.VDVaultKeys) end
FV.rebuild()
Config.reg("VDVaultKeys", FV.rebuild)

function FV.matches(name)
    local l = tostring(name):lower()
    for _, k in ipairs(FV.keys) do
        if l:find(k, 1, true) then return true end
    end
    return false
end

-- catat nama animasi sekali-jalan (bukan loop) supaya tidak penuh idle/jalan
local function note(track)
    local ok, looped = pcall(function() return track.Looped end)
    if ok and looped then return end
    local n = tostring(track.Name)
    local idx = table.find(FV.recent, n)
    if idx then table.remove(FV.recent, idx) end
    table.insert(FV.recent, 1, n)
    while #FV.recent > 8 do table.remove(FV.recent) end
end

--------------------------------------------------------
-- metode Animasi
--------------------------------------------------------
function FV.boost(track)
    if base[track] == nil then base[track] = track.Speed end
    local want = base[track] * Cfg.VDVaultMult
    if math.abs(track.Speed - want) > 0.01 then track:AdjustSpeed(want) end
end

function FV.restoreAnim()
    for track, sp in pairs(base) do
        pcall(function() track:AdjustSpeed(sp) end)
        base[track] = nil
    end
    FV.boosted = 0
end

--------------------------------------------------------
-- metode Atribut (vaultspeed)
--------------------------------------------------------
-- dipanggil berkala; nilai asli diingat, perubahan dari game (mis. perk) ikut jadi nilai asli baru
function FV.attrStep(ch)
    local st = FV.attr
    if not ch then return "Menunggu karakter" end
    if st.char ~= ch then st.char, st.orig, st.set = ch, nil, nil end
    local cur = ch:GetAttribute(ATTR)
    if type(cur) ~= "number" then return "Atribut vaultspeed tidak ada di karakter" end
    if st.set == nil or math.abs(cur - st.set) > 1e-6 then st.orig = cur end
    local want = st.orig * Cfg.VDVaultMult
    if math.abs(cur - want) > 1e-6 then ch:SetAttribute(ATTR, want) end
    st.set = want
    return ("Aktif: vaultspeed %g -> %g"):format(st.orig, want)
end

function FV.restoreAttr()
    local st = FV.attr
    local ch = st.char
    if ch and st.orig ~= nil and st.set ~= nil then
        pcall(function()
            local cur = ch:GetAttribute(ATTR)
            if type(cur) == "number" and math.abs(cur - st.set) < 1e-6 then ch:SetAttribute(ATTR, st.orig) end
        end)
    end
    st.char, st.orig, st.set = nil, nil, nil
end

function FV.restore()
    FV.restoreAnim()
    FV.restoreAttr()
end

function FV.clearRecent() FV.recent = {} end

--------------------------------------------------------
-- pemantau animasi (daftar nama + metode Animasi)
--------------------------------------------------------
local function onPlayed(track)
    note(track)
    if Cfg.VDFastVault and Cfg.VDVaultMode == "Animasi" and FV.matches(track.Name) then pcall(FV.boost, track) end
end

-- sambungkan ke Animator karakter saat ini (otomatis ikut respawn)
local function hook()
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    local a = hum and hum:FindFirstChildOfClass("Animator")
    if a == animator then return end
    if conn then pcall(function() conn:Disconnect() end) conn = nil end
    animator = a
    if a then conn = Hub.track(a.AnimationPlayed:Connect(onPlayed)) end
end

function FV.step()
    hook()
    if not Cfg.VDFastVault then
        if next(base) or FV.attr.char then FV.restore() end
        FV.status = "Mati"
        return
    end
    local mode = Cfg.VDVaultMode
    if mode == "Animasi" then
        FV.restoreAttr()
        if not animator then FV.status = "Menunggu karakter" return end
        local n = 0
        -- terapkan ulang tiap 0.05 dtk: game kadang menulis ulang kecepatan track
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            if FV.matches(track.Name) then
                pcall(FV.boost, track)
                n += 1
            end
        end
        FV.boosted = n
        FV.status = n > 0 and ("Aktif: %d animasi dipercepat x%g"):format(n, Cfg.VDVaultMult) or "Siaga (menunggu vault)"
    else
        FV.restoreAnim()
        local ok, msg = pcall(FV.attrStep, LP.Character)
        FV.status = ok and msg or ("Error: " .. tostring(msg))
    end
end

Scheduler.add("Fast vault", 0.05, FV.step)
Hub.onUnload(FV.restore)

return FV
