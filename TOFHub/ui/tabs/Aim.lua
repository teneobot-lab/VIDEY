-- Tab Aim: aimlock, silent aim, FOV.
local Hub = ...
local Page = Hub.use("ui/Controls")

local page = Page.new("Aim")

page:Header("Aim", "Aimlock dan silent aim ke Killer")
page:Section("Mode")
page:Toggle("Aimlock (tahan bidik)", "Aimlock")
page:Toggle("Silent Aim", "Silent")
page:Toggle("Wall Check", "WallCheck")
page:Section("Pengaturan")
page:Slider("FOV", "FOV", 30, 800, 10, " px")
page:Slider("Kekuatan kunci", "Lock", 5, 100, 5, "%")
page:Slider("Prediksi", "Predict", 0, 30, 1, "")
page:Choice("Bagian target", "Part", { "HumanoidRootPart", "Head", "Torso" })
page:Toggle("Auto reset pose (PC)", "AutoUnstick")
page:Section("Lingkaran FOV")
page:Toggle("Tampilkan FOV", "ShowFOV")
page:Color("Warna FOV", "FOVColor")

return { page = page }
