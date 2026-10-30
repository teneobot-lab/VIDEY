-- Tombol melayang berbentuk blok "?" Mario: tanda tanya melayang naik-turun, membal saat disentuh.
-- Tap = buka/tutup window, geser = pindah.
local Hub = ...
local Config = Hub.use("config/Config")
local Cfg = Config.Cfg
local Kit = Hub.use("ui/Kit")
local Root = Hub.use("ui/Root")
local Window = Hub.use("ui/Window")
local new, corner, lbl = Kit.new, Kit.corner, Kit.lbl
local Drag = Kit.Drag

local GOLD = Color3.fromRGB(252, 190, 40)
local BROWN = Color3.fromRGB(122, 66, 14)

local float = new("TextButton", {
    Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, 12, 0.5, -20),
    BackgroundColor3 = GOLD, BorderSizePixel = 0, AutoButtonColor = false, Text = "",
}, Root.gui)
corner(float, 6)
new("UIStroke", { Color = BROWN, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, float)

-- paku di empat sudut
for _, p in ipairs({ { 4, 4 }, { 32, 4 }, { 4, 32 }, { 32, 32 } }) do
    corner(new("Frame", { Position = UDim2.fromOffset(p[1], p[2]), Size = UDim2.fromOffset(4, 4), BackgroundColor3 = BROWN, BorderSizePixel = 0 }, float), 2)
end

local q = lbl(float, "?", 24, BROWN, Kit.FONT, Enum.TextXAlignment.Center)
q.Size = UDim2.fromScale(1, 1)
q.TextYAlignment = Enum.TextYAlignment.Center
Kit.loop(q, { Position = UDim2.fromOffset(0, -3) }, 0.55)

local sc = Kit.scaleOf(float)
float.MouseEnter:Connect(function() Kit.spring(sc, { Scale = 1.14 }, 0.25) end)
float.MouseLeave:Connect(function() Kit.spring(sc, { Scale = 1 }, 0.25) end)
float.Visible = Cfg.ShowFloat
Config.reg("ShowFloat", function()
    float.Visible = Cfg.ShowFloat
    if Cfg.ShowFloat then Kit.pop(float, 0.5) end
end)

float.InputBegan:Connect(function(i)
    if not Kit.isPress(i) then return end
    local sp, st, moved = i.Position, float.Position, 0
    Drag.fn = function(pos)
        local d = pos - sp
        moved = math.max(moved, d.Magnitude)
        float.Position = UDim2.new(st.X.Scale, st.X.Offset + d.X, st.Y.Scale, st.Y.Offset + d.Y)
    end
    Drag.done = function()
        if moved < 6 then
            Kit.pop(float, 0.7)
            Window.toggle()
        end
    end
end)

return float
