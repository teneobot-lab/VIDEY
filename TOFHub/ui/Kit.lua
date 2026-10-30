-- Tema + helper UI kecil (pembuat instance, tween, hover, aksen, drag global, animasi ala Mario).
-- Semua animasi mengikuti Cfg.UIAnim: bila dimatikan, nilai langsung diterapkan tanpa tween.
local Hub = ...
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Config = Hub.use("config/Config")
local Cfg = Config.Cfg
local Theme = Hub.use("ui/Theme")

local Kit = {}
Kit.T = Theme.T
local T = Kit.T

-- font judul ala game (Fredoka); cadangan GothamBold bila tidak ada
local okF, fredoka = pcall(function() return Enum.Font.FredokaOne end)
Kit.FONT = okF and fredoka or Enum.Font.GothamBold

function Kit.new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end
local new = Kit.new

function Kit.corner(o, r) return new("UICorner", { CornerRadius = UDim.new(0, r) }, o) end

function Kit.lbl(parent, txt, size, color, font, align)
    return new("TextLabel", {
        BackgroundTransparency = 1, Text = txt, TextSize = size, TextColor3 = color,
        Font = font or Enum.Font.GothamMedium,
        TextXAlignment = align or Enum.TextXAlignment.Left,
    }, parent)
end

function Kit.isPress(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

--------------------------------------------------------
-- Animasi
--------------------------------------------------------
function Kit.animOn() return Cfg.UIAnim ~= false end

local function setNow(o, props)
    for k, v in pairs(props) do pcall(function() o[k] = v end) end
end

-- tween biasa (Quad Out). UIAnim mati -> langsung set nilai akhir, mengembalikan nil
function Kit.tween(o, props, t, style, dir)
    if not Kit.animOn() then setNow(o, props) return nil end
    local tw = TweenService:Create(o, TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end
local tween = Kit.tween

-- "membal": melewati target sedikit lalu kembali (Back Out) — kesan blok Mario
function Kit.spring(o, props, t)
    return tween(o, props, t or 0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

-- memantul seperti bola (Bounce Out)
function Kit.bounce(o, props, t)
    return tween(o, props, t or 0.45, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
end

function Kit.scaleOf(o)
    local s = o:FindFirstChildOfClass("UIScale")
    if not s then s = new("UIScale", { Scale = 1 }, o) end
    return s
end

-- kembung sebentar lalu membal ke ukuran normal (efek blok "dipukul" dari bawah)
function Kit.pop(o, from)
    local s = Kit.scaleOf(o)
    if not Kit.animOn() then s.Scale = 1 return end
    s.Scale = from or 0.88
    Kit.spring(s, { Scale = 1 }, 0.38)
end

-- tombol terasa ditekan: mengecil saat ditahan, membal saat dilepas
function Kit.pressFx(btn, target)
    local s = Kit.scaleOf(target or btn)
    btn.MouseButton1Down:Connect(function() tween(s, { Scale = 0.94 }, 0.07) end)
    btn.MouseButton1Up:Connect(function() Kit.spring(s, { Scale = 1 }, 0.32) end)
    btn.MouseLeave:Connect(function() tween(s, { Scale = 1 }, 0.12) end)
end

-- jalankan fn(nilai) dari `from` ke `to` dengan easing bebas (untuk animasi gabungan skala+posisi)
function Kit.drive(from, to, t, style, dir, fn)
    if not Kit.animOn() then fn(to) return nil end
    local nv = Instance.new("NumberValue")
    nv.Value = from
    local conn = nv.Changed:Connect(fn)
    local tw = TweenService:Create(nv, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), { Value = to })
    tw.Completed:Connect(function()
        conn:Disconnect()
        nv:Destroy()
        fn(to)
    end)
    fn(from)
    tw:Play()
    return tw
end

-- animasi berulang bolak-balik (koin berputar, tanda "?" melayang). Berhenti bila UIAnim dimatikan.
local loops = {}
function Kit.loop(o, props, t, style)
    local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), props)
    loops[#loops + 1] = tw
    if Kit.animOn() then tw:Play() end
    return tw
end
Config.reg("UIAnim", function()
    for _, tw in ipairs(loops) do
        pcall(function() if Kit.animOn() then tw:Play() else tw:Pause() end end)
    end
end)

-- hover manis: latar berubah ke steel blue + garis tepi lembut muncul
function Kit.hoverFx(target, trigger, base)
    base = base or T.surface
    local st = new("UIStroke", {
        Color = T.steelEdge, Thickness = 1, Transparency = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, target)
    trigger.MouseEnter:Connect(function()
        tween(target, { BackgroundColor3 = T.steel }, 0.16)
        tween(st, { Transparency = 0.45 }, 0.16)
    end)
    trigger.MouseLeave:Connect(function()
        tween(target, { BackgroundColor3 = base }, 0.22)
        tween(st, { Transparency = 1 }, 0.22)
    end)
end

-- warna aksen: daftarkan fungsi yang mengecat ulang saat Cfg.Accent berubah
local AccentFns = {}
function Kit.onAccent(fn)
    AccentFns[#AccentFns + 1] = fn
    pcall(fn)
end
Config.reg("Accent", function()
    for _, fn in ipairs(AccentFns) do pcall(fn) end
end)

-- drag global (window, resize, slider, tombol melayang): set Drag.fn / Drag.done saat tekan
local Drag = { fn = nil, done = nil }
Kit.Drag = Drag
Hub.track(UIS.InputChanged:Connect(function(i)
    if Drag.fn and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
        Drag.fn(i.Position)
    end
end))
Hub.track(UIS.InputEnded:Connect(function(i)
    if Drag.fn and Kit.isPress(i) then
        Drag.fn = nil
        if Drag.done then local d = Drag.done Drag.done = nil d() end
    end
end))

return Kit
