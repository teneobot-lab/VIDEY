-- Tab ESP (satu tempat untuk semua ESP): pengaturan umum + label master,
-- grup per kategori (pemain, zombie, objek map) dan info objek terdeteksi.
local Hub = ...
local Config = Hub.use("config/Config")
local Cats = Hub.use("config/Categories")
local Scheduler = Hub.use("core/Scheduler")
local Zom = Hub.use("esp/Zombies")
local Obj = Hub.use("esp/Objects")
local Window = Hub.use("ui/Window")
local Page = Hub.use("ui/Controls")
local CategoryGroup = Hub.use("ui/CategoryGroup")

local CAT = Cats.byId
local OBJ_GROUPS = Cats.objGroups
local page = Page.new("ESP")

page:Header("ESP", "Pemain, zombie, dan objek map")

page:Section("Label")
page:Toggle("Label semua ESP", "ShowLabels")
page:Toggle("Tag [KILLER]", "ShowRole")
page:Toggle("Nama", "ShowName")
page:Toggle("Jarak", "ShowDist")
page:Toggle("HP", "ShowHP")
page:Toggle("Generator: bar progres otomatis (tanpa label)", "GenBar")
page:Toggle("Generator penuh: ESP mati otomatis", "GenHideDone")
page:Slider("Ukuran teks", "TextSize", 9, 22, 1, "")

page:Section("Tampilan")
page:Slider("Transparansi isi chams", "FillT", 0, 100, 5, "%")
page:Choice("Mode ESP", "ESPMode", { "CoreGui", "Workspace" })
page:Button("Aktifkan semua ESP", function()
    for _, c in ipairs(Cats.list) do Config.set(c.on, true) end
    Window.toast("Semua ESP aktif")
end, "accent")
page:Button("Matikan semua ESP", function()
    for _, c in ipairs(Cats.list) do Config.set(c.on, false) end
    Window.toast("Semua ESP mati")
end)
page:Button("Scan ulang objek", function() Obj.rescan() Window.toast("Scan ulang dimulai") end)

page:Section("Pemain (tap untuk buka)")
CategoryGroup(page, CAT.Killer)
CategoryGroup(page, CAT.Surv)

page:Section("Zombie")
CategoryGroup(page, CAT.Zombie, function(g)
    g:Input("Kata kunci zombie", "KeyZombie", "scp2, zombie", Zom.rebuild)
    g:Toggle("Semua NPC bernyawa", "ZomAll")
end)

page:Section("Objek map")
for _, c in ipairs(OBJ_GROUPS) do CategoryGroup(page, c) end

page:Section("Objek terdeteksi")
local infoObj = page:Info("...")

Scheduler.add("Info objek", 0.5, function()
    local counts = {}
    for _, g in ipairs(OBJ_GROUPS) do counts[g.id] = 0 end
    for _, rec in pairs(Obj.tracked) do counts[rec.g.id] += 1 end
    local parts = {}
    for _, g in ipairs(OBJ_GROUPS) do
        parts[#parts + 1] = ("%s: %d terdeteksi / %d tampil"):format(g.name, counts[g.id], Obj.shown[g.id] or 0)
    end
    infoObj.Text = table.concat(parts, "\n") .. "\n0 terdeteksi = nama di game berbeda, ubah kata kunci di grup objeknya"
end)

return { page = page }
