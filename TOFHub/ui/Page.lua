-- Sistem halaman/tab + komponen tata letak (Header, Section, Info, Tiles, Button).
-- Kontrol interaktif (Toggle, Slider, Choice, Input, Color, Group) ada di ui/Controls.
--   local page = Page.new("Nama")   -> tombol tab di sidebar + ScrollingFrame
--   Page.select(page)               -> tampilkan halaman
local Hub = ...
local Cfg = Hub.use("config/Config").Cfg
local Kit = Hub.use("ui/Kit")
local Window = Hub.use("ui/Window")
local T, new, corner, lbl, tween, hoverFx, onAccent = Kit.T, Kit.new, Kit.corner, Kit.lbl, Kit.tween, Kit.hoverFx, Kit.onAccent
local spring = Kit.spring

local Page = {}
Page.__index = Page
Page.list = {}
local tabButtons = {}

function Page.select(p)
    for _, q in ipairs(Page.list) do
        if q == p then
            if not q.sf.Visible then
                -- halaman baru naik membal dari bawah
                q.sf.Position = UDim2.fromOffset(0, 16)
                q.sf.Visible = true
                spring(q.sf, { Position = UDim2.fromOffset(0, 0) }, 0.38)
            end
        else
            q.sf.Visible = false
        end
    end
    for q, tb in pairs(tabButtons) do
        local on = (q == p)
        local changed = (tb.on ~= on)
        tb.on = on
        tween(tb.btn, { BackgroundTransparency = on and 0.05 or 1, BackgroundColor3 = T.steel })
        tb.lbl.TextColor3 = on and T.text or T.muted
        if on and changed then
            tb.ind.Visible = true
            tb.ind.Size = UDim2.fromOffset(3, 0)
            spring(tb.ind, { Size = UDim2.fromOffset(3, 16) }, 0.4)
            Kit.pop(tb.btn, 0.9)
        elseif not on then
            tb.ind.Visible = false
        end
    end
end

function Page.new(name)
    local sf = new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 2, ScrollBarImageColor3 = T.steelEdge,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false,
    }, Window.content)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
    new("UIPadding", { PaddingRight = UDim.new(0, 5), PaddingBottom = UDim.new(0, 6) }, sf)
    local p = setmetatable({ sf = sf, n = 0 }, Page)
    Page.list[#Page.list + 1] = p

    local b = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = T.steel, BackgroundTransparency = 1,
        AutoButtonColor = false, Text = "", LayoutOrder = #Page.list,
    }, Window.sidebar)
    corner(b, 2)
    local ind = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(3, 16), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Cfg.Accent, BorderSizePixel = 0, Visible = false }, b)
    corner(ind, 2)
    onAccent(function() ind.BackgroundColor3 = Cfg.Accent end)
    local l = lbl(b, name, 13, T.muted, Kit.FONT)
    l.Position, l.Size = UDim2.fromOffset(12, 0), UDim2.new(1, -14, 1, 0)
    l.TextScaled = true -- nama panjang (mis. "Violence District") tetap muat
    new("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }, l)
    local tb = { btn = b, ind = ind, lbl = l, on = false }
    tabButtons[p] = tb
    b.MouseEnter:Connect(function()
        if not tb.on then
            tween(b, { BackgroundTransparency = 0.45 })
            tween(l, { TextColor3 = T.text })
        end
    end)
    b.MouseLeave:Connect(function()
        if not tb.on then
            tween(b, { BackgroundTransparency = 1 })
            tween(l, { TextColor3 = T.muted })
        end
    end)
    Kit.pressFx(b)
    b.Activated:Connect(function() Page.select(p) end)
    return p
end

function Page:next() self.n += 1 return self.n end
function Page:base() return self.bg or T.surface end
function Page:inner() return (self.bg == T.raised) and T.surface or T.raised end

function Page:card(h)
    local f = new("Frame", {
        Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = self:base(), BorderSizePixel = 0, LayoutOrder = self:next(),
    }, self.sf)
    corner(f, 4)
    new("UIStroke", { Color = T.outline, Thickness = 2 }, f)
    return f
end

function Page:Header(txt, sub)
    local f = new("Frame", { Size = UDim2.new(1, 0, 0, sub and 40 or 26), BackgroundTransparency = 1, LayoutOrder = self:next() }, self.sf)
    local t = lbl(f, txt, 19, T.text, Kit.FONT)
    t.Size = UDim2.new(1, 0, 0, 22)
    if sub then
        local s = lbl(f, sub, 11, T.muted)
        s.Position, s.Size = UDim2.fromOffset(0, 22), UDim2.new(1, 0, 0, 14)
    end
end

function Page:Section(txt)
    local f = new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = self:next() }, self.sf)
    local bar = new("Frame", { Size = UDim2.fromOffset(3, 10), Position = UDim2.fromOffset(0, 8), BackgroundColor3 = Cfg.Accent, BorderSizePixel = 0 }, f)
    corner(bar, 2)
    onAccent(function() bar.BackgroundColor3 = Cfg.Accent end)
    local l = lbl(f, string.upper(txt), 10, T.muted, Enum.Font.GothamBold)
    l.Position, l.Size = UDim2.fromOffset(10, 3), UDim2.new(1, -10, 0, 16)
end

function Page:Info(txt, rich)
    local f = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = self:base(), BorderSizePixel = 0, LayoutOrder = self:next(),
    }, self.sf)
    corner(f, 3)
    new("UIStroke", { Color = T.outline, Thickness = 1 }, f)
    new("UIPadding", { PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, f)
    local l = lbl(f, txt, 11, T.text)
    l.Size, l.AutomaticSize = UDim2.new(1, 0, 0, 0), Enum.AutomaticSize.Y
    l.TextWrapped, l.TextYAlignment, l.RichText = true, Enum.TextYAlignment.Top, rich == true
    return l
end

-- defs = { {id, "LABEL"}, ... } -> tabel id -> TextLabel nilai
function Page:Tiles(defs)
    local rows = math.ceil(#defs / 2)
    local g = new("Frame", { Size = UDim2.new(1, 0, 0, rows * 52 + (rows - 1) * 6), BackgroundTransparency = 1, LayoutOrder = self:next() }, self.sf)
    new("UIGridLayout", { CellSize = UDim2.new(0.5, -3, 0, 52), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }, g)
    local vals = {}
    for i, d in ipairs(defs) do
        local c = new("Frame", { BackgroundColor3 = T.surface, BorderSizePixel = 0, LayoutOrder = i }, g)
        corner(c, 8)
        hoverFx(c, c, T.surface)
        local l = lbl(c, d[2], 9, T.muted, Enum.Font.GothamBold)
        l.Position, l.Size = UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 12)
        local v = lbl(c, "-", 16, T.text, Enum.Font.GothamBold)
        v.Position, v.Size = UDim2.fromOffset(12, 23), UDim2.new(1, -24, 0, 22)
        v.TextTruncate = Enum.TextTruncate.AtEnd
        vals[d[1]] = v
    end
    return vals
end

-- kind: nil | "accent" | "danger"
function Page:Button(txt, cb, kind)
    local b = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = self:base(), BorderSizePixel = 0, AutoButtonColor = false,
        Text = txt, TextSize = 12, Font = Enum.Font.GothamMedium, TextColor3 = T.text, LayoutOrder = self:next(),
    }, self.sf)
    corner(b, 8)
    if kind == "accent" then
        b.TextColor3, b.Font = T.bg, Enum.Font.GothamBold
        onAccent(function() b.BackgroundColor3 = Cfg.Accent end)
        b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = Cfg.Accent:Lerp(Color3.new(1, 1, 1), 0.2) }) end)
        b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = Cfg.Accent }) end)
    else
        if kind == "danger" then b.TextColor3 = T.danger end
        hoverFx(b, b, self:base())
    end
    Kit.pressFx(b)
    b.Activated:Connect(cb)
    return b
end

return Page
