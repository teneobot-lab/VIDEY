-- Kontrol interaktif yang terhubung ke Cfg: Toggle, Slider, Choice, Input, Color, Group.
-- Menambah method ke kelas Page; tab cukup `local Page = Hub.use("ui/Controls")`.
-- Kontrol baru = tambah satu `function Page:NamaBaru(...)` di sini.
local Hub = ...
local Config = Hub.use("config/Config")
local Cfg, reg, setCfg = Config.Cfg, Config.reg, Config.set
local Util = Hub.use("core/Util")
local Kit = Hub.use("ui/Kit")
local Page = Hub.use("ui/Page")
local T, new, corner, lbl, tween = Kit.T, Kit.new, Kit.corner, Kit.lbl, Kit.tween
local hoverFx, onAccent, isPress, Drag = Kit.hoverFx, Kit.onAccent, Kit.isPress, Kit.Drag
local spring = Kit.spring

--------------------------------------------------------
-- Toggle
--------------------------------------------------------
function Page:Toggle(label, key)
    local f = self:card(34)
    local base = self:base()
    local l = lbl(f, label, 12, T.text)
    l.Position, l.Size = UDim2.fromOffset(12, 0), UDim2.new(1, -66, 1, 0)
    local pill = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(36, 20), BackgroundColor3 = T.track, BorderSizePixel = 0,
    }, f)
    corner(pill, 10)
    local dot = new("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(14, 14), BackgroundColor3 = T.muted, BorderSizePixel = 0,
    }, pill)
    corner(dot, 7)
    local btn = new("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" }, f)
    local function paint()
        local on = Cfg[key]
        -- bulatan membal melewati ujung lalu kembali (ala blok Mario)
        spring(dot, { Position = on and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, 0.34)
        tween(dot, { BackgroundColor3 = on and T.text or T.muted })
        tween(pill, { BackgroundColor3 = on and Cfg.Accent or T.track })
    end
    reg(key, paint)
    onAccent(paint)
    hoverFx(f, btn, base)
    btn.Activated:Connect(function()
        Kit.pop(pill, 0.86)
        setCfg(key, not Cfg[key])
    end)
end

--------------------------------------------------------
-- Slider (nilai bisa diketik) — juga dipakai oleh Color
--------------------------------------------------------
local function makeSlider(parent, order, label, min, max, step, value, suffix, onSet, bg)
    local base = bg or T.surface
    local f = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = base, BorderSizePixel = 0, LayoutOrder = order }, parent)
    corner(f, 8)
    local l = lbl(f, label, 12, T.text)
    l.Position, l.Size = UDim2.fromOffset(12, 6), UDim2.new(0.55, -12, 0, 18)
    -- nilai bisa DIKETIK dengan keyboard (tap angka, ketik, Enter)
    local v = new("TextBox", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 5), Size = UDim2.fromOffset(78, 20),
        BackgroundColor3 = T.track, BackgroundTransparency = 0.5, BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = T.text, Text = "",
        ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Center,
    }, f)
    corner(v, 5)
    local tr = new("Frame", { Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 4), BackgroundColor3 = T.track, BorderSizePixel = 0 }, f)
    corner(tr, 2)
    local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Cfg.Accent, BorderSizePixel = 0 }, tr)
    corner(fill, 2)
    local knob = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(12, 12), BackgroundColor3 = T.text, BorderSizePixel = 0, ZIndex = 2,
    }, tr)
    corner(knob, 6)
    onAccent(function() fill.BackgroundColor3 = Cfg.Accent end)
    local hit = new("TextButton", { Position = UDim2.fromOffset(6, 22), Size = UDim2.new(1, -12, 0, 22), BackgroundTransparency = 1, Text = "" }, f)

    local S = { value = value }
    local function display() v.Text = ("%g"):format(S.value) .. (suffix or "") end
    function S.set(x, silent)
        x = math.clamp(x, min, max)
        x = math.clamp(min + math.floor((x - min) / step + 0.5) * step, min, max)
        S.value = x
        local a = (x - min) / (max - min)
        fill.Size = UDim2.new(a, 0, 1, 0)
        knob.Position = UDim2.new(a, 0, 0.5, 0)
        if not v:IsFocused() then display() end
        if not silent and onSet then onSet(x) end
    end

    v.Focused:Connect(function()
        v.Text = ("%g"):format(S.value)
        tween(v, { BackgroundTransparency = 0, BackgroundColor3 = T.steel })
    end)
    v.FocusLost:Connect(function()
        tween(v, { BackgroundTransparency = 0.5, BackgroundColor3 = T.track })
        local raw = v.Text:gsub(",", "."):gsub("[^%d%.%-]", "")
        local n = tonumber(raw)
        if n then S.set(n) else display() end
        display()
    end)

    hoverFx(f, f, base)
    hit.MouseEnter:Connect(function() spring(knob, { Size = UDim2.fromOffset(16, 16) }, 0.25) end)
    hit.MouseLeave:Connect(function() if not Drag.fn then spring(knob, { Size = UDim2.fromOffset(12, 12) }, 0.25) end end)
    hit.InputBegan:Connect(function(i)
        if not isPress(i) then return end
        local sf = f:FindFirstAncestorOfClass("ScrollingFrame")
        if sf then sf.ScrollingEnabled = false end
        local function upd(pos)
            local a = math.clamp((pos.X - tr.AbsolutePosition.X) / math.max(tr.AbsoluteSize.X, 1), 0, 1)
            S.set(min + a * (max - min))
        end
        upd(i.Position)
        Drag.fn = upd
        Drag.done = function()
            if sf then sf.ScrollingEnabled = true end
            spring(knob, { Size = UDim2.fromOffset(12, 12) }, 0.3)
        end
    end)
    S.set(value, true)
    display()
    return S
end

function Page:Slider(label, key, min, max, step, suffix)
    local S
    S = makeSlider(self.sf, self:next(), label, min, max, step, Cfg[key], suffix, function(x) setCfg(key, x) end, self:base())
    reg(key, function() S.set(Cfg[key], true) end)
end

--------------------------------------------------------
-- Choice (tap untuk ganti opsi berikutnya)
--------------------------------------------------------
function Page:Choice(label, key, options, onSet)
    local f = self:card(34)
    local l = lbl(f, label, 12, T.text)
    l.Position, l.Size = UDim2.fromOffset(12, 0), UDim2.new(0.45, -12, 1, 0)
    local inner = self:inner()
    local b = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.55, -14, 0, 24),
        BackgroundColor3 = inner, BorderSizePixel = 0, AutoButtonColor = false,
        Text = "", TextSize = 11, Font = Enum.Font.GothamBold, TextColor3 = T.text,
    }, f)
    corner(b, 6)
    hoverFx(b, b, inner)
    local function paint() b.Text = tostring(Cfg[key]) end
    reg(key, paint)
    paint()
    b.Activated:Connect(function()
        local idx = table.find(options, Cfg[key]) or 0
        setCfg(key, options[idx % #options + 1])
        Kit.pop(b, 0.9)
        if onSet then onSet(Cfg[key]) end
    end)
end

--------------------------------------------------------
-- Input teks
--------------------------------------------------------
function Page:Input(label, key, placeholder, onSet)
    local f = self:card(34)
    local l = lbl(f, label, 12, T.text)
    l.Position, l.Size = UDim2.fromOffset(12, 0), UDim2.new(0.35, -12, 1, 0)
    local inner = self:inner()
    local tb = new("TextBox", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.65, -14, 0, 24),
        BackgroundColor3 = inner, BorderSizePixel = 0, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = T.text,
        PlaceholderText = placeholder or "", PlaceholderColor3 = T.muted, ClearTextOnFocus = false,
        Text = tostring(Cfg[key]), TextTruncate = Enum.TextTruncate.AtEnd,
    }, f)
    corner(tb, 6)
    hoverFx(tb, tb, inner)
    reg(key, function() tb.Text = tostring(Cfg[key]) end)
    tb.FocusLost:Connect(function()
        setCfg(key, tb.Text)
        if onSet then onSet() end
    end)
end

--------------------------------------------------------
-- Color picker (slider RGB + hex + preset)
--------------------------------------------------------
local PRESETS = {
    Color3.fromRGB(235, 50, 50), Color3.fromRGB(255, 150, 40), Color3.fromRGB(255, 220, 60),
    Color3.fromRGB(80, 220, 110), Color3.fromRGB(60, 210, 230), Color3.fromRGB(110, 130, 255),
    Color3.fromRGB(124, 106, 255), Color3.fromRGB(255, 110, 190), Color3.fromRGB(255, 255, 255),
}

function Page:Color(label, key)
    local base = self:base()
    local inner = self:inner()
    local wrap = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = base, BorderSizePixel = 0, LayoutOrder = self:next(),
    }, self.sf)
    corner(wrap, 8)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, wrap)

    local head = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = base, BorderSizePixel = 0, AutoButtonColor = false, Text = "", LayoutOrder = 1,
    }, wrap)
    corner(head, 8)
    hoverFx(head, head, base)
    local l = lbl(head, label, 12, T.text)
    l.Position, l.Size = UDim2.fromOffset(12, 0), UDim2.new(1, -112, 1, 0)
    local swatch = new("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(28, 18), BackgroundColor3 = Cfg[key], BorderSizePixel = 0,
    }, head)
    corner(swatch, 5)
    new("UIStroke", { Color = T.stroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, swatch)
    local hexLbl = lbl(head, "", 10, T.muted, Enum.Font.Code, Enum.TextXAlignment.Right)
    hexLbl.AnchorPoint, hexLbl.Position, hexLbl.Size = Vector2.new(1, 0.5), UDim2.new(1, -46, 0.5, 0), UDim2.fromOffset(60, 16)

    local panelF = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Visible = false, LayoutOrder = 2,
    }, wrap)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, panelF)
    new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8) }, panelF)

    local rS, gS, bS
    local function fromSliders() setCfg(key, Color3.fromRGB(rS.value, gS.value, bS.value)) end
    local c0 = Cfg[key]
    rS = makeSlider(panelF, 1, "Merah", 0, 255, 1, c0.R * 255, "", fromSliders, inner)
    gS = makeSlider(panelF, 2, "Hijau", 0, 255, 1, c0.G * 255, "", fromSliders, inner)
    bS = makeSlider(panelF, 3, "Biru", 0, 255, 1, c0.B * 255, "", fromSliders, inner)

    local hexBox = new("TextBox", {
        Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = inner, BorderSizePixel = 0, LayoutOrder = 4,
        Font = Enum.Font.Code, TextSize = 12, TextColor3 = T.text, PlaceholderText = "#RRGGBB",
        PlaceholderColor3 = T.muted, ClearTextOnFocus = false, Text = "",
    }, panelF)
    corner(hexBox, 6)
    hoverFx(hexBox, hexBox, inner)
    hexBox.FocusLost:Connect(function()
        local c = Util.parseHex(hexBox.Text)
        if c then setCfg(key, c) else hexBox.Text = Util.hex(Cfg[key]) end
    end)

    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 5 }, panelF)
    new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }, row)
    for _, pc in ipairs(PRESETS) do
        local pb = new("TextButton", { Size = UDim2.fromOffset(22, 22), BackgroundColor3 = pc, BorderSizePixel = 0, Text = "" }, row)
        corner(pb, 6)
        local ps = new("UIStroke", { Color = T.text, Thickness = 1.5, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, pb)
        pb.MouseEnter:Connect(function() tween(ps, { Transparency = 0.2 }) end)
        pb.MouseLeave:Connect(function() tween(ps, { Transparency = 1 }) end)
        pb.Activated:Connect(function() setCfg(key, pc) end)
    end

    local function paint()
        local c = Cfg[key]
        swatch.BackgroundColor3 = c
        hexLbl.Text = "#" .. Util.hex(c)
        hexBox.Text = Util.hex(c)
        rS.set(c.R * 255, true)
        gS.set(c.G * 255, true)
        bS.set(c.B * 255, true)
    end
    reg(key, paint)
    paint()
    head.Activated:Connect(function()
        panelF.Visible = not panelF.Visible
        if panelF.Visible then Kit.pop(panelF, 0.94) end
    end)
end

--------------------------------------------------------
-- Group: bagian yang bisa dilipat (titik warna + nama + status ON/OFF).
-- Mengembalikan "page" anak; panggil g:Toggle(...), g:Slider(...), dst.
--------------------------------------------------------
function Page:Group(title, colKey, onKey)
    local wrap = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = T.surface, BorderSizePixel = 0, LayoutOrder = self:next(),
    }, self.sf)
    corner(wrap, 8)
    new("UIStroke", { Color = T.outline, Thickness = 2 }, wrap)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, wrap)

    local head = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = T.surface, BorderSizePixel = 0,
        AutoButtonColor = false, Text = "", LayoutOrder = 1,
    }, wrap)
    corner(head, 8)
    hoverFx(head, head, T.surface)
    local dot = new("Frame", { Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = Cfg[colKey], BorderSizePixel = 0 }, head)
    corner(dot, 5)
    reg(colKey, function() dot.BackgroundColor3 = Cfg[colKey] end)
    local t = lbl(head, title, 12, T.text, Enum.Font.GothamBold)
    t.Position, t.Size = UDim2.fromOffset(32, 0), UDim2.new(1, -110, 1, 0)
    local st = lbl(head, "", 10, T.muted, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
    st.AnchorPoint, st.Position, st.Size = Vector2.new(1, 0), UDim2.new(1, -30, 0, 0), UDim2.fromOffset(50, 38)
    local chev = lbl(head, "▸", 12, T.muted, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    chev.TextYAlignment = Enum.TextYAlignment.Center
    chev.Position, chev.Size = UDim2.new(1, -26, 0, 0), UDim2.fromOffset(20, 38)
    local function paintStatus()
        st.Text = Cfg[onKey] and "ON" or "OFF"
        st.TextColor3 = Cfg[onKey] and Cfg.Accent or T.muted
    end
    reg(onKey, paintStatus)
    onAccent(paintStatus)

    local bodyF = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Visible = false, LayoutOrder = 2,
    }, wrap)
    new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, bodyF)
    new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8) }, bodyF)
    head.Activated:Connect(function()
        bodyF.Visible = not bodyF.Visible
        spring(chev, { Rotation = bodyF.Visible and 90 or 0 }, 0.3)
        if bodyF.Visible then Kit.pop(bodyF, 0.94) end
    end)
    return setmetatable({ sf = bodyF, n = 0, bg = T.raised }, Page)
end

return Page
