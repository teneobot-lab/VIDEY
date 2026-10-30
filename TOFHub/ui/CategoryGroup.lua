-- Grup pengaturan standar untuk satu kategori ESP (dipakai tab ESP untuk semua kategori):
-- Tampilkan, Chams, Label, Jarak maksimal, Warna, (+ kata kunci nama untuk objek).
--   CategoryGroup(page, kategori, extra?)   extra(g) = tambahan kontrol khusus
-- Catatan: toggle "Label" hanya berlaku bila saklar utama "Label semua ESP" aktif.
local Hub = ...
local Objects = Hub.use("esp/Objects")

return function(page, c, extra)
    local g = page:Group(c.name, c.col, c.on)
    g:Toggle("Tampilkan", c.on)
    g:Toggle("Chams (outline + isi)", c.chams)
    g:Toggle("Label", c.label)
    g:Slider("Jarak maksimal", c.dist, 50, 5000, 50, " m")
    g:Color("Warna", c.col)
    if c.keyCfg then g:Input("Kata kunci nama", c.keyCfg, c.keyDef, Objects.rescan) end
    if extra then extra(g) end
end
