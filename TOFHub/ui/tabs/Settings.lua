-- Tab Settings: tampilan, config (simpan/muat), deteksi role, info, unload.
local Hub = ...
local Config = Hub.use("config/Config")
local Scheduler = Hub.use("core/Scheduler")
local Window = Hub.use("ui/Window")
local Page = Hub.use("ui/Controls")
local Theme = Hub.use("ui/Theme")
local Root = Hub.use("ui/Root")

local page = Page.new("Settings")

page:Header("Settings", "Tampilan, config, dan deteksi")

page:Section("Tampilan")
page:Choice("Tema Mario", "Theme", Theme.names)
Config.reg("Theme", function()
    Theme.apply(Config.Cfg.Theme, Root.gui)
end)
page:Color("Warna aksen UI", "Accent")
page:Toggle("Animasi UI", "UIAnim")
page:Toggle("Tombol melayang", "ShowFloat")
page:Button("Reset ukuran window", function()
    Window.resetSize()
    Window.toast("Ukuran direset")
end)
page:Button("Reset semua warna", function()
    for k, v in pairs(Config.Default) do
        if typeof(v) == "Color3" then Config.set(k, v) end
    end
    Window.toast("Warna direset")
end)

page:Section("Config")
page:Toggle("Simpan otomatis", "AutoSave")
local infoCfg = page:Info("...")
page:Button("Simpan config sekarang", function()
    local ok, msg = Config.save()
    Window.toast(msg)
end, "accent")
page:Button("Muat config", function()
    local ok, msg = Config.load()
    Window.toast(msg)
end)
page:Button("Reset semua ke default", function()
    Config.reset()
    Window.toast("Semua pengaturan dikembalikan ke default")
end)
page:Button("Salin config (JSON)", function()
    if setclipboard then
        setclipboard(Config.serialize())
        Window.toast("Config disalin ke clipboard")
    else
        Window.toast("setclipboard tidak didukung")
    end
end)
page:Button("Hapus file config", function()
    local ok, msg = Config.delete()
    Window.toast(msg)
end, "danger")

Scheduler.add("Info config", 0.5, function()
    local lines = { "File: " .. Config.FILE }
    if not Config.supported() then
        lines[#lines + 1] = "Executor tidak mendukung baca/tulis file, config tidak bisa disimpan"
    else
        lines[#lines + 1] = Config.exists() and "File config: ada" or "File config: belum dibuat"
        lines[#lines + 1] = Config.dirty and "Status: ada perubahan belum tersimpan" or "Status: tersimpan"
        if Config.lastSave then
            lines[#lines + 1] = ("Terakhir disimpan: %d detik lalu"):format(os.time() - Config.lastSave)
        end
    end
    infoCfg.Text = table.concat(lines, "\n")
end)

page:Section("Deteksi role")
page:Slider("Jumlah killer", "KillerCount", 1, 3, 1, "")
page:Section("Info")
page:Info("RightShift: tampil/sembunyi window\nTombol ? melayang: tap buka/tutup, geser untuk pindah\nTombol – : minimize | ◢ : ubah ukuran\nAngka di slider bisa diketik\nSimpan otomatis aktif: perubahan tersimpan 1 detik setelah diubah. Matikan bila ingin menyimpan manual.")
page:Section("Script")
page:Button("Unload", function() Hub.unload() end, "danger")

return { page = page }
