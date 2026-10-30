-- Aimlock + Silent aim ke Killer, reset pose, dan hitung peluru "Twist of Fate".
--   Aim.step()     dipanggil tiap RenderStep (bind "TOFHubAim")
--   Aim.unstick()  paksa keluar dari pose bidik yang macet
local Hub = ...
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local LP = Players.LocalPlayer
local Cfg = Hub.use("config/Config").Cfg
local Roles = Hub.use("core/Roles")
local Scheduler = Hub.use("core/Scheduler")

local Aim = { targetName = nil, fireDir = nil, shoot = 0, fail = 0 }

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude

local function visible(part)
    if not Cfg.WallCheck then return true end
    local f = { part.Parent }
    if LP.Character then f[2] = LP.Character end
    rp.FilterDescendantsInstances = f
    local o = workspace.CurrentCamera.CFrame.Position
    return workspace:Raycast(o, part.Position - o, rp) == nil
end

function Aim.getTarget()
    local cam = workspace.CurrentCamera
    local center = cam.ViewportSize / 2
    local best, bestP, bd = nil, nil, Cfg.FOV
    for _, p in ipairs(Roles.killers) do
        local ch = p.Character
        if ch then
            local hum = ch:FindFirstChildOfClass("Humanoid")
            local part = ch:FindFirstChild(Cfg.Part) or ch:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and part then
                local pos, on = cam:WorldToViewportPoint(part.Position)
                if on then
                    local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if d < bd and visible(part) then best, bestP, bd = part, p, d end
                end
            end
        end
    end
    return best, bestP
end

function Aim.point(part)
    return part.Position + part.AssemblyLinearVelocity * (Cfg.Predict / 100)
end

function Aim.unstick()
    pcall(function()
        for _, n in ipairs({ "ShiftLock", "CameraTransition", "CameraDelay" }) do
            RunService:UnbindFromRenderStep(n)
        end
        local ch = LP.Character
        if not ch then return end
        ch:SetAttribute("Aiming", false)
        local hrp = ch:FindFirstChild("HumanoidRootPart")
        if hrp and CS:HasTag(hrp, "doing action") then CS:RemoveTag(hrp, "doing action") end
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.AutoRotate = true
            local animator = hum:FindFirstChildOfClass("Animator")
            if animator then
                for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
                    local v = tr.Priority.Value
                    if v >= 2 and v < 1000 then tr:Stop(0.1) end
                end
            end
        end
    end)
end

-- Silent aim: hook tidak memanggil method Roblox apa pun; arah dihitung di RenderStep
local function hookFire()
    local Fire
    pcall(function() Fire = RS.Remotes.Items["Twist of Fate"].Fire end)
    if not Fire then return end

    Hub.track(Fire.OnClientEvent:Connect(function(kind)
        if kind == "Shoot" then Aim.shoot += 1
        elseif kind == "SelfDamage" then Aim.fail += 1 end
    end))

    if hookmetamethod and newcclosure and getnamecallmethod then
        local old
        old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" and self == Fire and Cfg.Silent and not Hub.Dead then
                local dir = Aim.fireDir
                if dir then
                    local args = table.pack(...)
                    args[2] = dir
                    if setnamecallmethod then setnamecallmethod(method) end
                    return old(self, table.unpack(args, 1, args.n))
                end
            end
            return old(self, ...)
        end))
    end
end
hookFire()

function Aim.step()
    Aim.targetName, Aim.fireDir = nil, nil
    if not (Cfg.Aimlock or Cfg.Silent) then return end
    local cam = workspace.CurrentCamera
    local ok, t, p = pcall(Aim.getTarget)
    if not (ok and t) then return end
    Aim.targetName = p.DisplayName
    local pt = Aim.point(t)
    if Cfg.Silent then Aim.fireDir = (pt - cam.CFrame.Position).Unit end

    if Cfg.Aimlock then
        local ch = LP.Character
        if ch and ch:GetAttribute("Aiming") then
            local goal = CFrame.lookAt(cam.CFrame.Position, pt)
            cam.CFrame = cam.CFrame:Lerp(goal, Cfg.Lock / 100)
        end
    end
end
RunService:BindToRenderStep("TOFHubAim", Enum.RenderPriority.Last.Value, Aim.step)

-- watchdog: Aiming menyala padahal tombol bidik tidak ditahan (PC) -> reset pose
local stuckT = 0
local function watchdog(dt)
    if not (Cfg.AutoUnstick and UIS.KeyboardEnabled and UIS.MouseEnabled) then return end
    local ch = LP.Character
    if ch and ch:GetAttribute("Aiming") then
        local held = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
            or UIS:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL2)
        stuckT = held and 0 or (stuckT + dt)
        if stuckT > 0.8 then
            stuckT = 0
            Aim.unstick()
        end
    else
        stuckT = 0
    end
end
Scheduler.add("Aim watchdog", 0, watchdog)

Hub.onUnload(function()
    Cfg.Aimlock, Cfg.Silent = false, false
    pcall(function() RunService:UnbindFromRenderStep("TOFHubAim") end)
end)

return Aim
