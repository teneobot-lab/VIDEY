-- Tab Violence District: Auto Skill Check + Speed Boost.
local Hub = ...
Hub.use("features/AutoSkillCheck")
local Page = Hub.use("ui/Controls")

local page = Page.new("Violence District")

page:Header("Violence District", "Skill check dan speed boost")
page:Section("Generator / Skill Check")
page:Toggle("Auto Skill Check", "VDAutoSkillCheck")
page:Choice("Mode Skill Check", "VDSkillMode", { "Perfect", "Normal", "Instant" })
page:Section("Movement")
page:Toggle("Speed Boost", "VDSpeedBoost")
page:Slider("Boost Multiplier", "VDSpeedMultiplier", 0, 2, 0.05, "x")
page:Toggle("Speed Safe Mode", "VDSpeedSafeMode")
page:Info("Safe Mode menjeda boost saat kondisi aksi/terbatas terdeteksi atau HP <= 50. Jangan aktifkan bersamaan dengan Speed di tab Gerak. WalkSpeed dapat ditimpa server.")

return { page = page }
