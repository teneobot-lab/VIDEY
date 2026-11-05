-- HUD kecil FPS · ping · memori di pojok layar (toggle Cfg.ShowStats). Bisa digeser.
local Hub = ...
local Config = Hub.use("config/Config")
local Cfg = Config.Cfg
local Kit = Hub.use("ui/Kit")
local Root = Hub.use("ui/Root")
local Scheduler = Hub.use("core/Scheduler")
local Perf = Hub.use("features/Perf")
local new, corner, lbl = Kit.new, Kit.corner, Kit.lbl
local Drag = Kit.Drag

local GOOD = Color3.fromRGB(96, 214, 120)
local WARN = Color3.fromRGB(250, 200, 70)
local BAD = Color3.fromRGB(240, 90, 90)

local hud = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(170, 26),
    BackgroundColor3 = Color3.fromRGB(14, 15, 20), BackgroundTransparency = 0.25, BorderSizePixel = 0,
    AutoButtonColor = false, Text = "", Visible = Cfg.ShowStats == true, AutomaticSize = Enum.AutomaticSize.X,
}, Root.gui)
corner(hud, 6)
new("UIStroke", { Color = Color3.fromRGB(60, 64, 80), Thickness = 1, Transparency = 0.3 }, hud)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, hud)
local txt = lbl(hud, "", 12, Color3.fromRGB(240, 240, 245), Enum.Font.Code)
txt.Size, txt.AutomaticSize = UDim2.new(0, 0, 1, 0), Enum.AutomaticSize.X
txt.TextYAlignment = Enum.TextYAlignment.Center
txt.RichText = true

local function hex(c) return ("#%02X%02X%02X"):format(math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
local function col(v, good, warn, invert)
    if invert then
        return v <= good and GOOD or v <= warn and WARN or BAD
    end
    return v >= good and GOOD or v >= warn and WARN or BAD
end

Scheduler.add("StatsHud", 0.5, function()
    if not hud.Visible then return end
    local fps, ping = math.floor(Perf.fps), Perf.ping
    txt.Text = ("<font color=\"%s\">%d fps</font> · <font color=\"%s\">%d ms</font> · %d MB"):format(
        hex(col(fps, 50, 30)), fps, hex(col(ping, 80, 150, true)), ping, Perf.mem)
end)

Config.reg("ShowStats", function()
    hud.Visible = Cfg.ShowStats == true
    if hud.Visible then Kit.pop(hud, 0.6) end
end)

hud.InputBegan:Connect(function(i)
    if not Kit.isPress(i) then return end
    local sp, st = i.Position, hud.Position
    Drag.fn = function(pos)
        local d = pos - sp
        hud.Position = UDim2.new(st.X.Scale, st.X.Offset + d.X, st.Y.Scale, st.Y.Offset + d.Y)
    end
end)

return hud
