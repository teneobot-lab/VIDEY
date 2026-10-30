-- Window utama: panel, title bar (koin berputar, minimize/tutup), sidebar tab, area konten, resize, toast, keybind.
-- Animasi ala Mario: window "muncul membal", koin berputar, garis bintang (star power) berjalan, toast membal.
--   Window.sidebar / Window.content   wadah yang diisi ui/Page
--   Window.toast(msg)  Window.toggle()  Window.setVisible(on)  Window.resetSize()  Window.statLbl
local Hub = ...
local UIS = game:GetService("UserInputService")
local Config = Hub.use("config/Config")
local Cfg = Config.Cfg
local Kit = Hub.use("ui/Kit")
local Root = Hub.use("ui/Root")
local T, new, corner, lbl = Kit.T, Kit.new, Kit.corner, Kit.lbl
local tween, isPress, onAccent, Drag = Kit.tween, Kit.isPress, Kit.onAccent, Kit.Drag

local Theme = Hub.use("ui/Theme")

local TITLE_H = 36
local MINW, MINH = 320, 220
local COIN = Color3.fromRGB(252, 196, 44)
local COIN_EDGE = Color3.fromRGB(150, 98, 12)

local function clampSize(w, h)
    local v = workspace.CurrentCamera.ViewportSize
    return math.clamp(w, MINW, math.max(MINW, v.X - 20)), math.clamp(h, MINH, math.max(MINH, v.Y - 20))
end
local fullW, fullH = clampSize(Cfg.W, Cfg.H)
local minimized = false

local win = new("Frame", {
    Size = UDim2.fromOffset(fullW, fullH), Position = UDim2.new(0.5, -fullW / 2, 0.5, -fullH / 2),
    BackgroundTransparency = 1, Active = true,
}, Root.gui)
local winScale = new("UIScale", { Scale = 1 }, win)
new("ImageLabel", {
    Image = "rbxassetid://6015897843", ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 0.55,
    ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49, 49, 450, 450),
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 4),
    Size = UDim2.new(1, 44, 1, 44), BackgroundTransparency = 1, ZIndex = 0,
}, win)
local panel = new("Frame", {
    Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.bg, BorderSizePixel = 0,
    ClipsDescendants = true, ZIndex = 1,
}, win)
corner(panel, 3)
new("UIStroke", { Color = T.outline, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, panel)

--------------------------------------------------------
-- Title bar
--------------------------------------------------------
local titleBar = new("Frame", { Size = UDim2.new(1, 0, 0, TITLE_H), BackgroundColor3 = T.top, BorderSizePixel = 0 }, panel)

-- koin berputar: lebar mengecil-membesar bolak-balik
local coin = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(22, TITLE_H / 2),
    Size = UDim2.fromOffset(20, 20), BackgroundColor3 = COIN, BorderSizePixel = 0, ClipsDescendants = true,
}, titleBar)
corner(coin, 10)
new("UIStroke", { Color = COIN_EDGE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, coin)
local coinT = lbl(coin, "P", 12, COIN_EDGE, Kit.FONT, Enum.TextXAlignment.Center)
coinT.AnchorPoint, coinT.Position, coinT.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(20, 20)
Kit.loop(coin, { Size = UDim2.fromOffset(6, 20) }, 0.55)

local title = lbl(titleBar, "PIDI MARIO", 15, T.topText, Kit.FONT)
title.Position, title.Size = UDim2.fromOffset(40, 0), UDim2.fromOffset(110, TITLE_H)

local statLbl = lbl(titleBar, "", 10, T.topText, Enum.Font.Code, Enum.TextXAlignment.Right)
statLbl.AnchorPoint, statLbl.Position, statLbl.Size = Vector2.new(1, 0), UDim2.new(1, -64, 0, 0), UDim2.fromOffset(110, TITLE_H)
statLbl.TextTransparency = 0.25

local function titleBtn(txt, xoff, hoverCol)
    local b = new("TextButton", {
        Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, xoff, 0, 6),
        BackgroundColor3 = T.steel, BackgroundTransparency = 1, AutoButtonColor = false,
        Text = txt, TextSize = 15, Font = Enum.Font.GothamBold, TextColor3 = T.topText,
    }, titleBar)
    corner(b, 6)
    Kit.pressFx(b)
    b.MouseEnter:Connect(function()
        tween(b, { BackgroundTransparency = 0, BackgroundColor3 = hoverCol or T.steel })
    end)
    b.MouseLeave:Connect(function()
        tween(b, { BackgroundTransparency = 1 })
    end)
    return b
end
local minBtn = titleBtn("–", -58)
local closeBtn = titleBtn("×", -32, T.danger)

-- garis "star power": pelangi yang bergeser terus di bawah title bar
local accentLine = new("Frame", { Position = UDim2.fromOffset(0, TITLE_H), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, panel)
local rainbow = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 60, 60)),
    ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 40)),
    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 220, 110)),
    ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 190, 240)),
    ColorSequenceKeypoint.new(0.8, Color3.fromRGB(170, 100, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 60, 60)),
})
local accentGrad = new("UIGradient", { Color = rainbow, Offset = Vector2.new(-0.5, 0) }, accentLine)
Kit.loop(accentGrad, { Offset = Vector2.new(0.5, 0) }, 2.2, Enum.EasingStyle.Linear)

--------------------------------------------------------
-- Body: sidebar + konten
--------------------------------------------------------
local body = new("Frame", { Position = UDim2.fromOffset(0, TITLE_H + 3), Size = UDim2.new(1, 0, 1, -(TITLE_H + 3)), BackgroundTransparency = 1 }, panel)

local sidebar = new("ScrollingFrame", {
    Position = UDim2.fromOffset(7, 7), Size = UDim2.new(0, 92, 1, -14),
    BackgroundColor3 = T.side, BorderSizePixel = 0, ScrollBarThickness = 0,
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, body)
corner(sidebar, 3)
new("UIStroke", { Color = T.outline, Thickness = 2 }, sidebar)
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, sidebar)
new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, sidebar)

local content = new("Frame", {
    Position = UDim2.fromOffset(108, 7), Size = UDim2.new(1, -115, 1, -14), BackgroundTransparency = 1,
    ClipsDescendants = true,
}, body)

local grip = new("TextButton", {
    AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -3), Size = UDim2.fromOffset(18, 18),
    BackgroundTransparency = 1, Text = "◢", TextSize = 11, TextColor3 = T.muted, ZIndex = 10,
}, panel)
grip.MouseEnter:Connect(function() tween(grip, { TextColor3 = T.steelEdge }) end)
grip.MouseLeave:Connect(function() tween(grip, { TextColor3 = T.muted }) end)

local function sizeTarget()
    if minimized then return UDim2.fromOffset(math.min(fullW, 240), TITLE_H) end
    return UDim2.fromOffset(fullW, fullH)
end

-- animate = true: ukuran berubah membal (dipakai minimize); resize lewat grip tetap langsung
local function applySize(animate)
    minBtn.Text = minimized and "+" or "–"
    if animate and Kit.animOn() then
        if not minimized then
            body.Visible, accentLine.Visible, grip.Visible = true, true, true
        end
        local tw = Kit.spring(win, { Size = sizeTarget() }, 0.34)
        if minimized and tw then
            tw.Completed:Connect(function()
                if minimized then body.Visible, accentLine.Visible, grip.Visible = false, false, false end
            end)
        end
        return
    end
    win.Size = sizeTarget()
    body.Visible = not minimized
    accentLine.Visible = not minimized
    grip.Visible = not minimized
end
minBtn.Activated:Connect(function() minimized = not minimized applySize(true) end)

titleBar.InputBegan:Connect(function(i)
    if isPress(i) then
        local sp, st = i.Position, win.Position
        Drag.fn = function(pos)
            local d = pos - sp
            win.Position = UDim2.new(st.X.Scale, st.X.Offset + d.X, st.Y.Scale, st.Y.Offset + d.Y)
        end
    end
end)

grip.InputBegan:Connect(function(i)
    if isPress(i) then
        local sp, sw, sh = i.Position, fullW, fullH
        Drag.fn = function(pos)
            fullW, fullH = clampSize(sw + (pos.X - sp.X), sh + (pos.Y - sp.Y))
            Cfg.W, Cfg.H = fullW, fullH
            win.Size = sizeTarget()
            Config.markDirty()
        end
    end
end)

-- ukuran berubah dari luar (muat config / reset): ikuti nilai Cfg.W / Cfg.H
local function followCfgSize()
    fullW, fullH = clampSize(Cfg.W, Cfg.H)
    applySize(false)
end
Config.reg("W", followCfgSize)
Config.reg("H", followCfgSize)

--------------------------------------------------------
-- Toast (membal masuk dari bawah)
--------------------------------------------------------
local toastLbl = new("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 40), Size = UDim2.fromOffset(0, 26),
    AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.steel, BorderSizePixel = 0,
    Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = T.text, Text = "", Visible = false, ZIndex = 30,
}, panel)
corner(toastLbl, 8)
new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, toastLbl)
new("UIStroke", { Color = T.steelEdge, Transparency = 0.2, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, toastLbl)
local toastTok = 0
local TOAST_UP, TOAST_DOWN = UDim2.new(0.5, 0, 1, -12), UDim2.new(0.5, 0, 1, 40)

--------------------------------------------------------
-- API publik
--------------------------------------------------------
local Window = {
    win = win, panel = panel, sidebar = sidebar, content = content,
    statLbl = statLbl, closeBtn = closeBtn,
}

function Window.toast(msg)
    toastTok += 1
    local t = toastTok
    toastLbl.Text = "★ " .. msg
    if not toastLbl.Visible then toastLbl.Position = TOAST_DOWN end
    toastLbl.Visible = true
    Kit.spring(toastLbl, { Position = TOAST_UP }, 0.38)
    task.delay(2.2, function()
        if t ~= toastTok then return end
        local tw = tween(toastLbl, { Position = TOAST_DOWN }, 0.2)
        if tw then
            tw.Completed:Connect(function() if t == toastTok then toastLbl.Visible = false end end)
        else
            toastLbl.Visible = false
        end
    end)
end

-- tampil/sembunyi dengan animasi skala membal; posisi dijaga supaya window membesar dari tengahnya
local shown = true
local animTok = 0
local basePos = win.Position
local function setScale(s)
    s = math.max(s, 0.01)
    winScale.Scale = s
    local sx, sy = win.Size.X.Offset, win.Size.Y.Offset
    win.Position = UDim2.new(basePos.X.Scale, basePos.X.Offset + sx * (1 - s) / 2, basePos.Y.Scale, basePos.Y.Offset + sy * (1 - s) / 2)
end

function Window.setVisible(on)
    if on == shown then return end
    shown = on
    animTok += 1
    local tok = animTok
    basePos = win.Position
    if not Kit.animOn() then
        winScale.Scale = 1
        win.Visible = on
        return
    end
    if on then
        win.Visible = true
        local tw = Kit.drive(0.55, 1, 0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out, setScale)
        if tw then
            tw.Completed:Connect(function()
                if tok == animTok then winScale.Scale = 1 win.Position = basePos end
            end)
        end
    else
        local tw = Kit.drive(1, 0.05, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In, setScale)
        if tw then
            tw.Completed:Connect(function()
                if tok == animTok then
                    win.Visible = false
                    winScale.Scale = 1
                    win.Position = basePos
                end
            end)
        end
    end
end

function Window.toggle() Window.setVisible(not shown) end

function Window.resetSize()
    fullW, fullH = clampSize(Config.Default.W, Config.Default.H)
    Cfg.W, Cfg.H = fullW, fullH
    minimized = false
    applySize(true)
    Config.markDirty()
end

closeBtn.Activated:Connect(function() Hub.unload() end)

Hub.track(UIS.InputBegan:Connect(function(i, gpe)
    if not gpe and i.KeyCode == Enum.KeyCode.RightShift then Window.toggle() end
end))

-- muncul pertama kali: dimulai tersembunyi lalu "pop" setelah semua tab selesai dibuat
shown = false
win.Visible = false
task.defer(function()
    if not Hub.Dead then Window.setVisible(true) end
end)

return Window
