-- Layar loading saat script pertama kali dijalankan (gaya Mario): blok "?" melompat, judul,
-- bar progres bata pelangi yang terisi tiap modul selesai dimuat, lalu memudar dan memanggil Hub.ready().
--   Splash.step(i, n, name)  perbarui progres sebelum modul ke-i dimuat (dipanggil main.lua)
--   Splash.finish()          isi penuh -> "Siap!" -> tutup, lalu Hub.ready() (window utama muncul)
--   Splash.fail(err)         tampilkan error lalu tutup sendiri beberapa detik kemudian
-- Mengikuti Cfg.UIAnim (tanpa animasi = tampil statis, langsung hilang saat selesai).
local Hub = ...
local Kit = Hub.use("ui/Kit")
local Root = Hub.use("ui/Root")
local T, new, corner, lbl, tween = Kit.T, Kit.new, Kit.corner, Kit.lbl, Kit.tween

local GOLD = Color3.fromRGB(252, 190, 40)
local BROWN = Color3.fromRGB(122, 66, 14)
local MIN_SHOW = 0.9 -- detik minimal tampil supaya tidak berkedip saat modul dimuat sangat cepat
local W, H = 300, 160

local gui = new("ScreenGui", { Name = "TOFHubSplash", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50 }, Root.container)
local dim = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0 }, gui)

-- CanvasGroup supaya seluruh kartu bisa memudar sekaligus; cadangan Frame bila tidak didukung
local okCG, card = pcall(function()
    return new("CanvasGroup", { GroupTransparency = 0 })
end)
if not okCG then card = new("Frame") end
card.AnchorPoint, card.Position, card.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(W, H)
card.BackgroundColor3, card.BorderSizePixel, card.Parent = T.bg, 0, gui
corner(card, 3)
new("UIStroke", { Color = T.outline, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
local scale = Kit.scaleOf(card)

-- blok "?" melompat
local block = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.fromOffset(44, 44),
    BackgroundColor3 = GOLD, BorderSizePixel = 0,
}, card)
corner(block, 6)
new("UIStroke", { Color = BROWN, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, block)
for _, p in ipairs({ { 5, 5 }, { 35, 5 }, { 5, 35 }, { 35, 35 } }) do
    corner(new("Frame", { Position = UDim2.fromOffset(p[1], p[2]), Size = UDim2.fromOffset(4, 4), BackgroundColor3 = BROWN, BorderSizePixel = 0 }, block), 2)
end
local q = lbl(block, "?", 26, BROWN, Kit.FONT, Enum.TextXAlignment.Center)
q.Size, q.TextYAlignment = UDim2.fromScale(1, 1), Enum.TextYAlignment.Center
Kit.loop(block, { Position = UDim2.new(0.5, 0, 0, 8) }, 0.42, Enum.EasingStyle.Quad)

local title = lbl(card, "PIDI MARIO", 17, T.text, Kit.FONT, Enum.TextXAlignment.Center)
title.Position, title.Size = UDim2.fromOffset(0, 66), UDim2.new(1, 0, 0, 22)

local status = lbl(card, "Menyiapkan...", 11, T.muted, Enum.Font.GothamMedium)
status.Position, status.Size = UDim2.fromOffset(18, 92), UDim2.new(1, -80, 0, 16)
status.TextTruncate = Enum.TextTruncate.AtEnd

local pct = lbl(card, "0%", 11, T.muted, Enum.Font.Code, Enum.TextXAlignment.Right)
pct.AnchorPoint, pct.Position, pct.Size = Vector2.new(1, 0), UDim2.new(1, -18, 0, 92), UDim2.fromOffset(50, 16)

-- bar progres: track + isi pelangi (gradien bergeser) + garis bata
local track = new("Frame", {
    Position = UDim2.fromOffset(18, 118), Size = UDim2.new(1, -36, 0, 14),
    BackgroundColor3 = T.track, BorderSizePixel = 0, ClipsDescendants = true,
}, card)
corner(track, 4)
new("UIStroke", { Color = T.outline, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, track)
local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, track)
local grad = new("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 60, 60)),
        ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 40)),
        ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 220, 110)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 190, 240)),
        ColorSequenceKeypoint.new(0.8, Color3.fromRGB(170, 100, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 60, 60)),
    }),
    Offset = Vector2.new(-0.5, 0),
}, fill)
Kit.loop(grad, { Offset = Vector2.new(0.5, 0) }, 1.6, Enum.EasingStyle.Linear)
for i = 1, 9 do
    new("Frame", {
        Position = UDim2.new(i / 10, -1, 0, 0), Size = UDim2.new(0, 2, 1, 0),
        BackgroundColor3 = T.outline, BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 2,
    }, track)
end

--------------------------------------------------------
-- Logika
--------------------------------------------------------
local Splash = { done = false, failing = false }
local t0 = os.clock()

local function setProgress(p)
    p = math.clamp(p, 0, 1)
    pct.Text = ("%d%%"):format(math.floor(p * 100 + 0.5))
    tween(fill, { Size = UDim2.new(p, 0, 1, 0) }, 0.18)
end

-- muncul: latar menggelap, kartu membal dari kecil
if Kit.animOn() then
    scale.Scale = 0.6
    tween(dim, { BackgroundTransparency = 0.45 }, 0.25)
    Kit.spring(scale, { Scale = 1 }, 0.4)
else
    dim.BackgroundTransparency = 0.45
end

local function close(after)
    if Splash.done then return end
    Splash.done = true
    local function destroy()
        pcall(function() gui:Destroy() end)
        if after then after() end
    end
    if not Kit.animOn() then destroy() return end
    tween(dim, { BackgroundTransparency = 1 }, 0.25)
    if okCG then tween(card, { GroupTransparency = 1 }, 0.22) end
    local tw = tween(scale, { Scale = 0.7 }, 0.26, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    if tw then tw.Completed:Connect(destroy) else destroy() end
end

function Splash.step(i, n, name)
    if Splash.done or Splash.failing then return end
    status.Text = "Memuat " .. tostring(name)
    setProgress((i - 1) / math.max(n, 1))
end

function Splash.finish()
    if Splash.done or Splash.failing then return end
    status.Text = "Siap!"
    status.TextColor3 = T.text
    setProgress(1)
    Kit.pop(block, 1.3)
    local hold = math.max(0, MIN_SHOW - (os.clock() - t0)) + (Kit.animOn() and 0.4 or 0)
    task.delay(hold, function()
        if Hub.Dead then return end
        close(Hub.ready)
    end)
end

function Splash.fail(err)
    if Splash.done then return end
    Splash.failing = true
    status.Text = "Gagal: " .. tostring(err)
    status.TextColor3 = T.danger
    fill.BackgroundColor3 = T.danger
    grad.Enabled = false
    pct.Text = "!"
    task.delay(4, function() close() end)
end

-- unload saat splash masih tampil (bukan karena gagal): langsung hilang
Hub.onUnload(function()
    if not Splash.failing then close() end
end)

return Splash
