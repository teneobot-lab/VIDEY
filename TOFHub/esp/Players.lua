-- ESP pemain (Killer / Survivor). ESP.update() dipanggil Scheduler tiap 0.2 detik.
local Hub = ...
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local Cfg = Hub.use("config/Config").Cfg
local CAT = Hub.use("config/Categories").byId
local Roles = Hub.use("core/Roles")
local Draw = Hub.use("esp/Draw")
local Scheduler = Hub.use("core/Scheduler")

local ESP = { rec = {}, shown = { Killer = 0, Surv = 0 } }

function ESP.clear(p)
    local r = ESP.rec[p]
    if r then Draw.dropGui(r) ESP.rec[p] = nil end
end
function ESP.clearAll()
    for p in pairs(ESP.rec) do ESP.clear(p) end
end

function ESP.update()
    local myRoot = Roles.myRoot()
    local shown = { Killer = 0, Surv = 0 }
    for _, p in ipairs(Players:GetPlayers()) do
        local ch = p.Character
        local drawn = false
        if p ~= LP and ch then
            local isK = Roles.killerMap[p] == true
            local cat = isK and CAT.Killer or CAT.Surv
            local hum = ch:FindFirstChildOfClass("Humanoid")
            local root = ch:FindFirstChild("HumanoidRootPart")
            if Cfg[cat.on] and hum and hum.Health > 0 and root then
                local dist = myRoot and (root.Position - myRoot.Position).Magnitude or 0
                if dist <= Cfg[cat.dist] then
                    local rec = ESP.rec[p] or {}
                    ESP.rec[p] = rec
                    local ok = pcall(function()
                        local col = Cfg[cat.col]
                        if Cfg[cat.chams] then
                            Draw.chams(rec, ch, col, Cfg.FillT / 100)
                        else
                            Draw.dropHL(rec)
                        end
                        local parts, head, info = {}, {}, {}
                        if Cfg.ShowRole and isK then head[#head + 1] = "[KILLER]" end
                        if Cfg.ShowName then head[#head + 1] = p.DisplayName end
                        if #head > 0 then parts[#parts + 1] = table.concat(head, " ") end
                        if Cfg.ShowDist then info[#info + 1] = math.floor(dist) .. "m" end
                        if Cfg.ShowHP then info[#info + 1] = math.floor(hum.Health) .. " HP" end
                        if #info > 0 then parts[#parts + 1] = table.concat(info, " | ") end
                        if Cfg[cat.label] and #parts > 0 then
                            Draw.label(rec, 220, 50, 3, col, table.concat(parts, "\n"), ch:FindFirstChild("Head") or root)
                        else
                            Draw.dropBB(rec)
                        end
                    end)
                    if ok then
                        drawn = true
                        shown[cat.id] += 1
                    else
                        Draw.dropGui(rec)
                    end
                end
            end
        end
        if not drawn then ESP.clear(p) end
    end
    ESP.shown = shown
end

Hub.track(Players.PlayerRemoving:Connect(ESP.clear))
Scheduler.add("ESP pemain", 0.2, ESP.update)
Hub.onUnload(ESP.clearAll)

return ESP
