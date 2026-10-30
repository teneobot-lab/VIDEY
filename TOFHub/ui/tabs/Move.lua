-- Tab Gerak: speed, noclip, fly.
local Hub = ...
local Scheduler = Hub.use("core/Scheduler")
local Move = Hub.use("features/Movement")
local Page = Hub.use("ui/Controls")

local page = Page.new("Gerak")

page:Header("Gerak", "Risiko tinggi, pakai akun alt")
page:Section("Speed")
page:Toggle("Speed", "Speed")
page:Slider("Kecepatan jalan (bisa diketik)", "SpeedVal", 1, 100, 1, "")
page:Toggle("Tahan otomatis saat knockdown/digendong/digantung", "SpeedSafe")
local infoSpeed = page:Info("Status: -")
page:Section("Lainnya")
page:Toggle("Noclip", "Noclip")
page:Toggle("Terbang (Fly)", "Fly")
page:Slider("Kecepatan terbang (bisa diketik)", "FlySpeed", 10, 200, 5, "")
page:Info("Server melihat posisi karakter, jadi speed/noclip/fly bisa ditandai atau dikembalikan. Mulai dari nilai kecil.")

Scheduler.add("Info gerak", 0.5, function()
    infoSpeed.Text = "Status speed: " .. Move.status
end)

return { page = page }
