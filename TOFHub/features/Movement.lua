-- Gerak: Speed, Noclip, Fly.
-- Speed otomatis ditahan (kembali ke nilai default game) saat knockdown / digendong / digantung / mati.
local Hub = ...
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer
local Cfg = Hub.use("config/Config").Cfg
local Scheduler = Hub.use("core/Scheduler")

local Move = { ws = nil, applied = nil, bv = nil, bg = nil, parts = {}, t = 0, status = "Mati" }

local function myHum()
    return LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
end

function Move.blockedReason()
    local ch, h = LP.Character, myHum()
    if not ch or not h or h.Health <= 0 then return "mati" end
    for _, obj in ipairs({ ch, LP }) do
        if obj:GetAttribute("Knocked") == true then return "knockdown" end
        if obj:GetAttribute("IsCarried") == true then return "digendong" end
        if obj:GetAttribute("IsHooked") == true then return "digantung" end
        if obj:GetAttribute("IsDead") == true then return "mati" end
    end
    return nil
end

function Move.stopFly()
    if Move.bv then Move.bv:Destroy() Move.bv = nil end
    if Move.bg then Move.bg:Destroy() Move.bg = nil end
    local h = myHum()
    if h then h.PlatformStand = false end
end

function Move.releaseSpeed(h)
    if Move.applied then
        -- kalau game sudah menulis nilainya sendiri (beda dari nilai kita), biarkan; kalau tidak, kembalikan default terakhir
        if h and math.abs(h.WalkSpeed - Move.applied) <= 0.05 and Move.ws then
            h.WalkSpeed = Move.ws
        end
        Move.applied = nil
    end
end

function Move.stopAll()
    Cfg.Speed, Cfg.Noclip, Cfg.Fly = false, false, false
    Move.stopFly()
    Move.releaseSpeed(myHum())
end

function Move.tick()
    local ch, h = LP.Character, myHum()
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if not (h and root) then return end
    local reason = Cfg.SpeedSafe and Move.blockedReason() or nil

    -- SPEED
    if Cfg.Speed and not reason then
        if not Move.applied then
            Move.ws = h.WalkSpeed
        elseif math.abs(h.WalkSpeed - Move.applied) > 0.05 then
            Move.ws = h.WalkSpeed -- game menulis nilai baru: itu jadi "default" terbaru
        end
        Move.applied = Cfg.SpeedVal
        h.WalkSpeed = Cfg.SpeedVal
        Move.status = "Aktif (" .. Cfg.SpeedVal .. ")"
    else
        Move.releaseSpeed(h)
        Move.status = Cfg.Speed and ("Ditahan: " .. (reason or "-") .. " (speed default)") or "Mati"
    end

    -- FLY
    if Cfg.Fly and not reason then
        if not (Move.bv and Move.bv.Parent) then
            Move.bv = Instance.new("BodyVelocity")
            Move.bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            Move.bv.Velocity = Vector3.zero
            Move.bv.Parent = root
            Move.bg = Instance.new("BodyGyro")
            Move.bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
            Move.bg.P = 1e4
            Move.bg.Parent = root
        end
        h.PlatformStand = true
        local cam = workspace.CurrentCamera
        local md = h.MoveDirection
        local vel = md * Cfg.FlySpeed
        if md.Magnitude > 0 then
            local flat = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
            if flat.Magnitude > 0 then
                local fwd = md:Dot(flat.Unit)
                vel += Vector3.new(0, cam.CFrame.LookVector.Y * Cfg.FlySpeed * math.max(fwd, 0), 0)
            end
        end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then vel += Vector3.new(0, Cfg.FlySpeed, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then vel -= Vector3.new(0, Cfg.FlySpeed, 0) end
        Move.bv.Velocity = vel
        Move.bg.CFrame = cam.CFrame
    elseif Move.bv then
        Move.stopFly()
    end
end

-- noclip: matikan CanCollide seluruh bagian karakter (daftar bagian di-refresh tiap 0.5 detik)
Hub.track(RunService.Stepped:Connect(function(_, dt)
    if Hub.Dead then return end
    local ch = LP.Character
    if not ch or not (Cfg.Noclip or Cfg.Fly) then return end
    Move.t += dt
    if Move.t >= 0.5 or #Move.parts == 0 then
        Move.t = 0
        Move.parts = {}
        for _, d in ipairs(ch:GetDescendants()) do
            if d:IsA("BasePart") then Move.parts[#Move.parts + 1] = d end
        end
    end
    for _, p in ipairs(Move.parts) do
        if p.Parent and p.CanCollide then p.CanCollide = false end
    end
end))

Scheduler.add("Gerak", 0, Move.tick)
Hub.onUnload(Move.stopAll)

return Move
