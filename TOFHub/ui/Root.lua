-- Wadah GUI tingkat atas: ScreenGui utama, overlay (FOV), dan folder ESP.
-- PENTING: ESP (Highlight/BillboardGui) diparenti langsung ke container, BUKAN ke ScreenGui
-- (BillboardGui di dalam ScreenGui tidak tampil).
local Hub = ...
local new = Hub.use("ui/Kit").new

local container = (gethui and gethui()) or game:GetService("CoreGui")

local Root = {
    container = container,
    gui = new("ScreenGui", { Name = "TOFHub", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, container),
    overlay = new("ScreenGui", { Name = "TOFHubOverlay", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5 }, container),
    espFolder = new("Folder", { Name = "TOFESP" }, container),
}

Hub.onUnload(function()
    pcall(function() Root.espFolder:Destroy() end)
    Root.gui:Destroy()
    Root.overlay:Destroy()
end)

return Root
