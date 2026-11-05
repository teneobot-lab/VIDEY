-- Tab Dunia: pencahayaan + HD grafis.
local Hub = ...
local World = Hub.use("features/World")
local Page = Hub.use("ui/Controls")

local page = Page.new("Dunia")

page:Header("Dunia", "Pencahayaan dan grafis HD")

page:Section("HD grafis")
page:Toggle("Mode HD", "HD")
page:Choice("Preset shader (tap untuk ganti)", "HDShader", World.SHADER_NAMES, World.applyShader)
page:Choice("Preset intensitas", "HDPreset", World.PRESET_NAMES, World.applyPreset)
page:Info("Preset shader mengisi semua nilai di bawah sekaligus (Realistic, Cinematic, Vibrant, Dark, Warm, Cold, Noir). Pilih Reset untuk kembali ke default. Semua hanya mengubah tampilan di layarmu (client).")

page:Section("Warna & cahaya")
page:Slider("Kontras", "HDContrast", 0, 60, 1, "%")
page:Slider("Saturasi warna", "HDSaturation", -100, 60, 2, "%")
page:Slider("Kecerahan", "HDBrightness", -20, 20, 1, "%")
page:Slider("Exposure", "HDExposure", -2, 2, 0.1, "")
page:Slider("Bloom (cahaya lembut)", "HDBloom", 0, 100, 5, "%")
page:Color("Tint (warna filter)", "HDTint")

page:Section("Lensa")
page:Toggle("Depth of Field (blur latar)", "HDDoF")
page:Slider("Jarak fokus", "HDDoFDist", 0, 200, 5, " stud")
page:Slider("Radius fokus", "HDDoFRadius", 0, 100, 5, " stud")
page:Slider("Blur jauh", "HDDoFFar", 0, 100, 5, "%")
page:Slider("Blur dekat", "HDDoFNear", 0, 100, 5, "%")
page:Slider("Vignette (gelap di tepi)", "HDVignette", 0, 100, 5, "%")

page:Section("Atmosfer")
page:Toggle("Atmosfer kustom", "HDAtmo")
page:Slider("Kepadatan", "HDAtmoDensity", 0, 100, 5, "%")
page:Slider("Kabut (haze)", "HDAtmoHaze", 0, 100, 5, "")
page:Slider("Silau matahari (glare)", "HDAtmoGlare", 0, 100, 5, "")
page:Color("Warna atmosfer", "HDAtmoColor")
page:Color("Warna peluruhan (decay)", "HDAtmoDecay")
page:Info("Jika game sudah punya Atmosphere, nilainya yang dipakai lalu dipulihkan saat dimatikan. Saat Atmosfer kustom aktif, opsi Hilangkan kabut tidak menyentuh Atmosphere.")

page:Section("Render")
page:Toggle("Bayangan", "HDShadows")
page:Slider("Kelembutan bayangan", "HDShadowSoft", 0, 100, 5, "%")
page:Toggle("Kualitas render maksimum", "HDQuality")
page:Toggle("Detail mesh maksimum (berat)", "HDMesh")
page:Toggle("Future lighting (jika executor mendukung)", "HDFuture")
page:Info("Mesh maksimum, Future lighting, dan Depth of Field bisa berat di HP/PC lemah; matikan bila FPS turun.")

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
