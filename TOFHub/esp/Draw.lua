-- Helper gambar ESP bersama: label (BillboardGui) + bar progres + chams (Highlight).
-- Setiap objek ESP memegang "rec" ({ bb, tl, bar, hl, ... }); helper ini yang membuat/memindah/menghapusnya.
-- Draw.label menghormati saklar utama Cfg.ShowLabels: bila mati, SEMUA teks label (pemain, zombie, objek) hilang.
-- Bar progres berdiri sendiri: tetap tampil walau teks label mati (text = nil), selama `bar` diberikan.
local Hub = ...
local Cfg = Hub.use("config/Config").Cfg
local Kit = Hub.use("ui/Kit")
local new, corner, tween = Kit.new, Kit.corner, Kit.tween
local espFolder = Hub.use("ui/Root").espFolder
local Scheduler = Hub.use("core/Scheduler")

local Draw = { bars = {} }

local BAR_W, BAR_H = 96, 9
local RED, YEL, GRN = Color3.fromRGB(235, 70, 60), Color3.fromRGB(255, 205, 55), Color3.fromRGB(80, 225, 110)
local INK = Color3.fromRGB(14, 10, 10)

local function barColor(p)
    if p < 0.5 then return RED:Lerp(YEL, p * 2) end
    return YEL:Lerp(GRN, (p - 0.5) * 2)
end

function Draw.dropBar(rec)
    if rec.bar then
        Draw.bars[rec] = nil
        pcall(function() rec.bar.track:Destroy() end)
        rec.bar = nil
    end
end
function Draw.dropBB(rec)
    Draw.bars[rec] = nil
    rec.bar = nil
    if rec.bb then pcall(function() rec.bb:Destroy() end) rec.bb, rec.tl = nil, nil end
end
function Draw.dropHL(rec)
    if rec.hl then pcall(function() rec.hl:Destroy() end) rec.hl = nil end
end
function Draw.dropGui(rec) Draw.dropBB(rec) Draw.dropHL(rec) end

local function ensureBB(rec, w, h, off)
    if not rec.bb then
        rec.bb = new("BillboardGui", {
            Name = "TOFTag", Size = UDim2.fromOffset(w, h), StudsOffset = Vector3.new(0, off, 0),
            AlwaysOnTop = true, ResetOnSpawn = false,
        })
        rec.tl = new("TextLabel", {
            Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold, TextSize = 12, TextStrokeTransparency = 0.4,
        }, rec.bb)
    end
    rec.tl.Size = UDim2.new(1, 0, 0, h)
end

-- bar progres kecil di bawah teks: isi bergeser warna merah -> kuning -> hijau, ada kilau berjalan
local function ensureBar(rec)
    if rec.bar then return end
    local track = new("Frame", {
        Name = "Bar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3),
        Size = UDim2.fromOffset(BAR_W, BAR_H), BackgroundColor3 = Color3.fromRGB(30, 26, 24), BorderSizePixel = 0,
    }, rec.bb)
    corner(track, 4)
    new("UIStroke", { Color = INK, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, track)
    local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0, BackgroundColor3 = RED }, track)
    corner(fill, 4)
    local grad = new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(185, 185, 185)),
            ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(185, 185, 185)),
        }),
    }, fill)
    -- garis pembagi 25% / 50% / 75%
    for _, x in ipairs({ 0.25, 0.5, 0.75 }) do
        new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(x, 0, 0, 0), Size = UDim2.new(0, 1, 1, 0),
            BackgroundColor3 = INK, BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 2,
        }, track)
    end
    rec.bar = { track = track, fill = fill, grad = grad }
    Draw.bars[rec] = true
end

local function placeBB(rec, part)
    rec.bb.Adornee = part
    local want = (Cfg.ESPMode == "Workspace") and part or espFolder
    if rec.bb.Parent ~= want then rec.bb.Parent = want end
end

local function ensureHL(rec)
    if not rec.hl then
        rec.hl = new("Highlight", { Name = "TOFHL", DepthMode = Enum.HighlightDepthMode.AlwaysOnTop })
    end
end

local function placeHL(rec, adornee)
    rec.hl.Adornee = adornee
    local want = (Cfg.ESPMode == "Workspace") and adornee or espFolder
    if rec.hl.Parent ~= want then rec.hl.Parent = want end
end

-- label di atas `part` (ukuran w x h px, naik `off` stud).
--   text = nil          -> tanpa teks (hanya bar, bila ada)
--   bar  = 0..1 (opsional) -> bar progres (di bawah teks, atau sendirian bila tanpa teks)
-- Saklar utama Cfg.ShowLabels = mati menghapus TEKS semua ESP; bar tidak ikut mati.
function Draw.label(rec, w, h, off, col, text, part, bar)
    if not Cfg.ShowLabels then text = nil end
    if text == nil and bar == nil then Draw.dropBB(rec) return end
    ensureBB(rec, w, h, off)
    local hasText = text ~= nil
    rec.tl.Visible = hasText
    if hasText then
        rec.tl.TextColor3 = col
        rec.tl.TextSize = Cfg.TextSize
        rec.tl.Text = text
    end
    local th = hasText and h or 0
    if bar ~= nil then
        ensureBar(rec)
        bar = math.clamp(bar, 0, 1)
        rec.bar.track.Position = UDim2.new(0.5, 0, 0, hasText and (h + 3) or 3)
        rec.bb.Size = UDim2.fromOffset(w, th + BAR_H + 6)
        tween(rec.bar.fill, { Size = UDim2.new(bar, 0, 1, 0), BackgroundColor3 = barColor(bar) }, 0.3)
    else
        if rec.bar then Draw.dropBar(rec) end
        rec.bb.Size = UDim2.fromOffset(w, th)
    end
    placeBB(rec, part)
end

-- chams (outline + isi) pada `adornee`
function Draw.chams(rec, adornee, col, fillT)
    ensureHL(rec)
    rec.hl.FillColor, rec.hl.OutlineColor = col, col
    rec.hl.FillTransparency = fillT
    placeHL(rec, adornee)
end

-- kilau yang berjalan di semua bar yang sedang tampil
Scheduler.add("ESP bar anim", 0.05, function()
    if not Kit.animOn() then return end
    local o = ((os.clock() * 0.7) % 2) - 1
    for rec in pairs(Draw.bars) do
        local b = rec.bar
        if b and b.grad.Parent then
            b.grad.Offset = Vector2.new(o, 0)
        else
            Draw.bars[rec] = nil
        end
    end
end)

return Draw
