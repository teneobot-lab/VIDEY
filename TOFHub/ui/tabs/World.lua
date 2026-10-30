-- Tab Dunia: pencahayaan + HD grafis.
local Hub = ...
local World = Hub.use("features/World")
local Page = Hub.use("ui/Controls")

local page = Page.new("Dunia")

page:Header("Dunia", "Pencahayaan dan grafis HD")

page:Section("HD grafis")
page:Toggle("Mode HD", "HD")
page:Choice("Preset HD", "HDPreset", World.PRESET_NAMES, World.applyPreset)
page:Slider("Kontras", "HDContrast", 0, 40, 1, "%")
page:Slider("Saturasi warna", "HDSaturation", 0, 40, 1, "%")
page:Slider("Bloom (cahaya lembut)", "HDBloom", 0, 100, 5, "%")
page:Toggle("Bayangan tajam", "HDShadows")
page:Toggle("Kualitas render maksimum", "HDQuality")
page:Toggle("Detail mesh maksimum (berat)", "HDMesh")
page:Toggle("Future lighting (jika executor mendukung)", "HDFuture")
page:Info("HD hanya mengubah tampilan di layarmu (client). Mesh maksimum dan Future lighting bisa berat di HP/PC lemah; matikan bila FPS turun.")

page:Section("Pencahayaan")
page:Toggle("Fullbright", "Fullbright")
page:Slider("Kecerahan", "Bright", 0, 6, 0.5, "")
page:Color("Warna ambient (tema)", "AmbientColor")
page:Section("Tambahan")
page:Toggle("Hilangkan kabut", "NoFog")
page:Toggle("Matikan efek gelap (blur/bloom/dll)", "NoFx")
page:Toggle("Kunci waktu (jam)", "ForceTime")
page:Slider("Jam", "Time", 0, 24, 0.5, "")

return { page = page }
