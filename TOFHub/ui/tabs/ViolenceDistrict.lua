-- Tab Violence District: Auto Skill Check + Speed Boost + Fast Vaulting.
local Hub = ...
Hub.use("features/AutoSkillCheck")
local FV = Hub.use("features/FastVault")
local Scheduler = Hub.use("core/Scheduler")
local Window = Hub.use("ui/Window")
local Page = Hub.use("ui/Controls")

local page = Page.new("Violence District")

page:Header("Violence District", "Skill check, speed boost, dan fast vault")
page:Section("Generator / Skill Check")
page:Toggle("Auto Skill Check", "VDAutoSkillCheck")
page:Choice("Mode Skill Check", "VDSkillMode", { "Perfect", "Normal", "Instant" })
page:Section("Movement")
page:Toggle("Speed Boost", "VDSpeedBoost")
page:Slider("Boost Multiplier", "VDSpeedMultiplier", 0, 2, 0.05, "x")
page:Toggle("Speed Safe Mode", "VDSpeedSafeMode")
page:Section("Vault (jendela)")
page:Toggle("Fast Vaulting", "VDFastVault")
page:Toggle("Paksa vault fast (tanpa syarat lari)", "VDVaultForce")
page:Choice("Metode", "VDVaultMode", { "Atribut", "Animasi" })
page:Slider("Kecepatan vault", "VDVaultMult", 1, 2.5, 0.25, "x")
page:Input("Kata kunci animasi (metode Animasi)", "VDVaultKeys", "vault", FV.rebuild)
local infoVault = page:Info("...")
page:Button("Bersihkan daftar animasi", function()
    FV.clearRecent()
    Window.toast("Daftar animasi dibersihkan")
end)
page:Info("Atribut: mengalikan atribut karakter vaultspeed (cara bawaan game). Animasi: mempercepat animasi vault langsung (kata kunci default \"vault\" cocok dengan RunningVaultAnimation). Bila satu metode tidak terasa, coba yang lain. Server tetap menerima sinyal vault lebih cepat dari biasanya, jadi pakai 1.5x dulu (server membatasi kecepatan vault ~30 stud/dtk). Paksa vault fast: argumen tier di VaultEvent diganti \"fast\" walau kamu tidak sedang lari; bila server menolak/macet, matikan.")
Scheduler.add("Info vault", 0.5, function()
    local recent = #FV.recent > 0 and table.concat(FV.recent, ", ") or "-"
    infoVault.Text = "Status: " .. FV.status .. "\nHook tier: " .. (FV.hooked and ("aktif, dipaksa " .. FV.forced .. "x") or "tidak didukung executor") .. "\nAnimasi terakhir (sekali putar): " .. recent
end)
page:Section("Catatan")
page:Info("Safe Mode menjeda boost saat kondisi aksi/terbatas terdeteksi atau HP <= 50. Jangan aktifkan bersamaan dengan Speed di tab Gerak. WalkSpeed dapat ditimpa server.")

return { page = page }
