-- Violence District: Auto Skill Check + Speed Boost (porting dari violence_district.lua).
-- Mode skill check: Perfect | Normal | Instant. Dijalankan Scheduler tiap 0.05 detik.
-- Catatan: Speed Boost memakai WalkSpeed juga seperti features/Movement; jangan aktifkan keduanya bersamaan.
local Hub = ...
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local LP = Players.LocalPlayer
local Cfg = Hub.use("config/Config").Cfg
local Scheduler = Hub.use("core/Scheduler")

local VIM
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local VD = {}
local playerGui
local lastGoalRotation
local lastPress = 0
local speedRecords = {}
local cachedAction

local function getPlayerGui()
    playerGui = LP:FindFirstChildOfClass("PlayerGui") or playerGui
    return playerGui
end

local function findSkillCheck()
    local pg = getPlayerGui()
    if not pg then return nil, nil end
    for _, name in ipairs({ "SkillCheckPromptGui", "SkillCheckPromptGui-con" }) do
        local gui = pg:FindFirstChild(name, true)
        if gui then
            local check = gui:FindFirstChild("Check", true)
            if check and check.Visible then
                return check:FindFirstChild("Line", true), check:FindFirstChild("Goal", true)
            end
        end
    end
    return nil, nil
end

local function findActionButton()
    local pg = getPlayerGui()
    if not pg then return nil end
    if cachedAction and cachedAction.Parent and cachedAction:IsA("GuiButton") then
        return cachedAction
    end
    cachedAction = nil
    local mobile = pg:FindFirstChild("Survivor-mob", true)
    local controls = mobile and mobile:FindFirstChild("Controls", true)
    if not controls then return nil end
    for _, name in ipairs({ "action", "Gui-mob" }) do
        local b = controls:FindFirstChild(name, true)
        if b and b:IsA("GuiButton") then
            cachedAction = b
            return b
        end
    end
    return nil
end

local function pressSkillCheck()
    local button = findActionButton()
    if button and type(firesignal) == "function" then
        local ok = pcall(function()
            firesignal(button.MouseButton1Down)
            task.delay(0.04, function()
                if button and button.Parent then
                    pcall(function() firesignal(button.MouseButton1Up) end)
                    pcall(function() firesignal(button.MouseButton1Click) end)
                end
            end)
        end)
        if ok then return true end
    end

    if not VIM then return false end

    local pg = getPlayerGui()
    local check = pg and (pg:FindFirstChild("Check", true) or pg:FindFirstChild("check", true))
    if check and check:IsA("GuiObject") and check.Visible then
        local ok = pcall(function()
            local pos, size = check.AbsolutePosition, check.AbsoluteSize
            local inset = GuiService:GetGuiInset()
            local x, y = pos.X + size.X / 2 + inset.X, pos.Y + size.Y / 2 + inset.Y
            VIM:SendMouseButtonEvent(x, y, 0, true, game, 1)
            task.wait(0.02)
            VIM:SendMouseButtonEvent(x, y, 0, false, game, 1)
        end)
        if ok then return true end
    end

    return pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.wait(0.03)
        VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end)
end

function VD.skillCheckStep()
    if not Cfg.VDAutoSkillCheck then
        lastGoalRotation = nil
        return
    end
    local line, goal = findSkillCheck()
    if not (line and goal) then
        lastGoalRotation = nil
        return
    end
    local goalRotation = goal.Rotation
    local lineRotation = line.Rotation
    local now = os.clock()
    if now - lastPress < 0.10 then return end

    local offset = (lineRotation - goalRotation) % 360
    local mode = Cfg.VDSkillMode
    local low, high
    if mode == "Normal" then
        low, high = 116, 159
    elseif mode == "Instant" then
        -- posisikan jarum di zona sukses, lalu tekan
        pcall(function() line.Rotation = goalRotation + 109 end)
        low, high = 102, 116
    else
        low, high = 102, 116
    end

    if goalRotation ~= lastGoalRotation and mode == "Instant" then
        pcall(function() line.Rotation = goalRotation + 109 end)
        offset = 109
    end
    if offset >= low and offset <= high then
        if pressSkillCheck() then
            lastPress = now
            lastGoalRotation = goalRotation
        end
    end
end

local function restoreSpeed(hum)
    local rec = speedRecords[hum]
    if not rec then return end
    pcall(function()
        -- kembalikan hanya bila nilai kita masih terpasang
        if hum and hum.Parent and rec.applied
            and math.abs(hum.WalkSpeed - rec.applied) < 0.05 then
            hum.WalkSpeed = rec.original
        end
    end)
    speedRecords[hum] = nil
end

local BLOCKED_ATTRS = {
    "IsHooked", "IsCarried", "Crouching", "IsInteracting",
    "IsRepairing", "IsHealing", "IsVaulting", "DoingAction",
}

local function isSafeMovementState(char, hum)
    if not Cfg.VDSpeedSafeMode then return false end
    if not char or not hum or hum.Health <= 0 then return true end
    for _, attributeName in ipairs(BLOCKED_ATTRS) do
        if char:GetAttribute(attributeName) == true then return true end
        if hum:GetAttribute(attributeName) == true then return true end
    end
    if hum.Health <= 50 then return true end
    return false
end

function VD.speedStep()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if not Cfg.VDSpeedBoost or isSafeMovementState(char, hum) then
        restoreSpeed(hum)
        return
    end

    local rec = speedRecords[hum]
    if not rec then
        rec = { original = hum.WalkSpeed, applied = nil }
        speedRecords[hum] = rec
    end
    local multiplier = math.clamp(tonumber(Cfg.VDSpeedMultiplier) or 0.30, 0, 2)
    local target = rec.original * (1 + multiplier)
    rec.applied = target
    if math.abs(hum.WalkSpeed - target) > 0.05 then
        pcall(function() hum.WalkSpeed = target end)
    end
end

Scheduler.add("VD skillcheck", 0.05, VD.skillCheckStep)
Scheduler.add("VD speed", 0.05, VD.speedStep)

Hub.onUnload(function()
    Cfg.VDAutoSkillCheck, Cfg.VDSpeedBoost = false, false
    for hum in pairs(speedRecords) do restoreSpeed(hum) end
    table.clear(speedRecords)
end)

return VD
