-- ESP zombie (NPC berhumanoid selain pemain).
-- Dugaan dari log: "scp2" = zombie SCP-049-2 milik killer Cure. Kata kunci diatur lewat Cfg.KeyZombie.
local Hub = ...
local Players = game:GetService("Players")
local Cfg = Hub.use("config/Config").Cfg
local CAT = Hub.use("config/Categories").byId
local Util = Hub.use("core/Util")
local Roles = Hub.use("core/Roles")
local Draw = Hub.use("esp/Draw")
local Scheduler = Hub.use("core/Scheduler")

local Zom = { tracked = {}, keys = {}, shown = 0 }

function Zom.rebuild() Zom.keys = Util.splitKeys(Cfg.KeyZombie) end
Zom.rebuild()

function Zom.matches(model)
    local nl = model.Name:lower()
    for _, k in ipairs(Zom.keys) do
        if nl:find(k, 1, true) then return true end
    end
    return false
end

function Zom.untrack(model)
    local rec = Zom.tracked[model]
    if rec then Draw.dropGui(rec) Zom.tracked[model] = nil end
end

function Zom.consider(model)
    if not model or Zom.tracked[model] or not model:IsA("Model") then return end
    if not model:IsDescendantOf(workspace) then return end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if Players:GetPlayerFromCharacter(model) then return end
    if model.Name == "cutscenecam" or Util.SKIP_TOP[Util.topName(model)] then return end
    Zom.tracked[model] = { model = model, hum = hum }
end

-- scan awal (dicicil supaya tidak membekukan game) + pantau yang baru muncul
task.spawn(function()
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        if Hub.Dead then return end
        if d:IsA("Humanoid") then Zom.consider(d.Parent) end
        n += 1
        if n % 2000 == 0 then task.wait() end
    end
end)
Hub.track(workspace.DescendantAdded:Connect(function(d)
    if d:IsA("Humanoid") then
        task.defer(function() if not Hub.Dead and d.Parent then Zom.consider(d.Parent) end end)
    end
end))

function Zom.update()
    local cat = CAT.Zombie
    local myRoot = Roles.myRoot()
    local list = {}
    for model, rec in pairs(Zom.tracked) do
        local hum = rec.hum
        if not model.Parent or not hum or not hum.Parent then
            Zom.untrack(model)
        else
            local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
            local dist = (root and myRoot) and (root.Position - myRoot.Position).Magnitude or 0
            if Cfg[cat.on] and hum.Health > 0 and root and dist <= Cfg[cat.dist]
                and (Cfg.ZomAll or Zom.matches(model)) then
                rec.root, rec.dist = root, dist
                list[#list + 1] = rec
            else
                Draw.dropGui(rec)
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    local col = Cfg[cat.col]
    for i, rec in ipairs(list) do
        local ok = pcall(function()
            if Cfg[cat.label] then
                local info = {}
                if Cfg.ShowDist then info[#info + 1] = math.floor(rec.dist) .. "m" end
                if Cfg.ShowHP then info[#info + 1] = math.floor(rec.hum.Health) .. " HP" end
                local text = "ZOMBIE" .. (#info > 0 and ("\n" .. table.concat(info, " | ")) or "")
                Draw.label(rec, 180, 44, 3, col, text, rec.model:FindFirstChild("Head") or rec.root)
            else
                Draw.dropBB(rec)
            end
            if Cfg[cat.chams] and i <= 8 then
                Draw.chams(rec, rec.model, col, Cfg.FillT / 100)
            else
                Draw.dropHL(rec)
            end
        end)
        if not ok then Draw.dropGui(rec) end
    end
    Zom.shown = #list
end

function Zom.clearAll()
    for m in pairs(Zom.tracked) do Zom.untrack(m) end
end

Scheduler.add("ESP zombie", 0.2, Zom.update)
Hub.onUnload(Zom.clearAll)

return Zom
