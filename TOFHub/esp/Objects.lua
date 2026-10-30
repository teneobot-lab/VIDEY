-- ESP objek map (generator, hook, gate, pallet, window) lewat kata kunci nama di workspace.Map.
-- Grup objek diambil dari config/Categories (kind = "obj"). Teks label khusus per objek
-- ditambahkan lewat LABEL_HOOKS (kunci = id kategori), jadi menambah objek baru tidak perlu ubah update().
local Hub = ...
local CS = game:GetService("CollectionService")
local Cfg = Hub.use("config/Config").Cfg
local OBJ_GROUPS = Hub.use("config/Categories").objGroups
local Util = Hub.use("core/Util")
local Roles = Hub.use("core/Roles")
local Draw = Hub.use("esp/Draw")
local Scheduler = Hub.use("core/Scheduler")

local Obj = { tracked = {}, shown = {} }

function Obj.rebuildKeys()
    for _, g in ipairs(OBJ_GROUPS) do g.keys = Util.splitKeys(Cfg[g.keyCfg]) end
end
Obj.rebuildKeys()

local function groupOf(name)
    local l = name:lower()
    for _, g in ipairs(OBJ_GROUPS) do
        for _, k in ipairs(g.keys) do
            if l:find(k, 1, true) then return g, k end
        end
    end
end

local function insideCharacter(inst)
    local p = inst.Parent
    while p and p ~= workspace do
        if p:IsA("Model") and p:FindFirstChildOfClass("Humanoid") then return true end
        p = p.Parent
    end
    return false
end

local function hasTrackedAncestor(inst)
    local p = inst.Parent
    while p and p ~= workspace do
        if Obj.tracked[p] then return true end
        p = p.Parent
    end
    return false
end

local function isContainer(inst, key)
    if not inst:IsA("Model") then return false end
    if inst.Name:sub(-1):lower() ~= "s" then return false end
    for _, c in ipairs(inst:GetChildren()) do
        if c:IsA("Model") and c.Name:lower():find(key, 1, true) then return true end
    end
    return false
end

function Obj.untrack(inst)
    local rec = Obj.tracked[inst]
    if rec then
        Draw.dropGui(rec)
        pcall(function() rec.conn:Disconnect() end)
        Obj.tracked[inst] = nil
    end
end

function Obj.consider(inst)
    if Obj.tracked[inst] then return end
    if not (inst:IsA("Model") or inst:IsA("BasePart")) then return end
    local g, key = groupOf(inst.Name)
    if not g then return end
    -- hanya di dalam workspace.Map (membuang dekor Lobby); jika Map belum ada, abaikan Lobby/FakeCharacters
    local map = workspace:FindFirstChild("Map")
    if map then
        if not inst:IsDescendantOf(map) then return end
    elseif Util.SKIP_TOP[Util.topName(inst)] then
        return
    end
    if g.id == "Gate" and not inst:IsA("Model") then return end -- Part "gate" bertag gatespot = titik spawn
    if inst:FindFirstChildOfClass("Humanoid") then return end
    if hasTrackedAncestor(inst) or isContainer(inst, key) or insideCharacter(inst) then return end
    if inst:IsA("Model") then
        for other in pairs(Obj.tracked) do
            if other ~= inst and other:IsDescendantOf(inst) then Obj.untrack(other) end
        end
    end
    local rec = { inst = inst, g = g }
    rec.conn = inst.AncestryChanged:Connect(function()
        if not inst:IsDescendantOf(workspace) then Obj.untrack(inst) end
    end)
    Obj.tracked[inst] = rec
end

function Obj.rescan()
    Obj.rebuildKeys()
    for inst in pairs(Obj.tracked) do Obj.untrack(inst) end
    task.spawn(function()
        local n = 0
        for _, d in ipairs(workspace:GetDescendants()) do
            if Hub.Dead then return end
            Obj.consider(d)
            n += 1
            if n % 2000 == 0 then task.wait() end
        end
    end)
end
Hub.track(workspace.DescendantAdded:Connect(function(d)
    task.defer(function() if not Hub.Dead then Obj.consider(d) end end)
end))

local function progressOf(inst)
    for k, v in pairs(inst:GetAttributes()) do
        local kl = tostring(k):lower()
        if type(v) == "number" and (kl:find("progress") or kl:find("percent")) then
            return math.floor(v + 0.5) -- RepairProgress berskala 0..100
        end
    end
    for _, c in ipairs(inst:GetChildren()) do
        if c:IsA("NumberValue") or c:IsA("IntValue") then
            local nl = c.Name:lower()
            if nl:find("progress") or nl:find("percent") then return math.floor(c.Value + 0.5) end
        end
    end
end

-- teks tambahan per jenis objek: fn(rec, teksDasar) -> teksBaru, [bar 0..1]
-- Generator: progress tampil sebagai BAR di bawah label (bukan angka persen).
-- Cfg.GenBar dimatikan -> kembali ke teks persen.
local LABEL_HOOKS = {
    Gen = function(rec, txt)
        local pr = progressOf(rec.inst)
        if not pr then return txt end
        pr = math.clamp(pr, 0, 100)
        if not Cfg.GenBar then return txt .. " " .. pr .. "%" end
        if pr >= 100 then txt = txt .. " [SELESAI]" end
        return txt, pr / 100
    end,
    Hook = function(rec, txt)
        if not CS:HasTag(rec.inst, "Spike") then return txt .. " [TERISI]" end
        return txt
    end,
}

function Obj.update()
    local myRoot = Roles.myRoot()
    local list = {}
    for inst, rec in pairs(Obj.tracked) do
        local part = rec.part
        if not (part and part.Parent) then
            part = inst:IsA("BasePart") and inst or inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
            rec.part = part
        end
        local g = rec.g
        local dist = (part and myRoot) and (part.Position - myRoot.Position).Magnitude or 0
        if Cfg[g.on] and part and dist <= Cfg[g.dist] then
            rec.dist = dist
            list[#list + 1] = rec
        else
            Draw.dropGui(rec)
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    local shown, hlCount = {}, 0
    for _, g in ipairs(OBJ_GROUPS) do shown[g.id] = 0 end
    for _, rec in ipairs(list) do
        local g = rec.g
        local ok = pcall(function()
            local col = Cfg[g.col]
            -- label ikut saklar utama Cfg.ShowLabels (dicek di Draw.label) + saklar per objek
            if Cfg[g.label] then
                local txt, bar = g.name, nil
                local hook = LABEL_HOOKS[g.id]
                if hook then txt, bar = hook(rec, txt) end
                if Cfg.ShowDist then txt = txt .. "  " .. math.floor(rec.dist) .. "m" end
                Draw.label(rec, 200, 18, 2, col, txt, rec.part, bar)
            else
                Draw.dropBB(rec)
            end
            if Cfg[g.chams] and hlCount < 16 then
                hlCount += 1
                Draw.chams(rec, rec.inst, col, 0.75)
            else
                Draw.dropHL(rec)
            end
        end)
        if ok then shown[g.id] += 1 else Draw.dropGui(rec) end
    end
    Obj.shown = shown
end

function Obj.clearAll()
    for inst in pairs(Obj.tracked) do Obj.untrack(inst) end
end

Scheduler.add("ESP objek", 0.2, Obj.update)
Hub.onUnload(Obj.clearAll)
Obj.rescan()

return Obj
