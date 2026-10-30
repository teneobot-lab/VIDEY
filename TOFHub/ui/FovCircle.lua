-- Lingkaran FOV aim (digambar di overlay, diperbarui tiap RenderStep).
local Hub = ...
local RunService = game:GetService("RunService")
local Cfg = Hub.use("config/Config").Cfg
local Kit = Hub.use("ui/Kit")
local Root = Hub.use("ui/Root")

local circle = Kit.new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
    BackgroundTransparency = 1, Visible = false,
}, Root.overlay)
Kit.corner(circle, 9999)
local stroke = Kit.new("UIStroke", { Thickness = 1, Color = Cfg.FOVColor, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, circle)

local function update()
    local show = Cfg.ShowFOV and (Cfg.Aimlock or Cfg.Silent)
    circle.Visible = show
    if show then
        circle.Size = UDim2.fromOffset(Cfg.FOV * 2, Cfg.FOV * 2)
        stroke.Color = Cfg.FOVColor
    end
end

RunService:BindToRenderStep("TOFHubFOV", Enum.RenderPriority.Last.Value, update)
Hub.onUnload(function()
    pcall(function() RunService:UnbindFromRenderStep("TOFHubFOV") end)
end)

return { circle = circle }
