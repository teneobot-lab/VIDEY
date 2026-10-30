-- Kategori ESP (data-driven). Tambah kategori/objek baru = tambah satu baris di CATS.
--   kind  : "role" (pemain) | "npc" | "obj" (objek map, dicari lewat kata kunci nama)
--   on    : kunci Cfg untuk toggle tampil     col : kunci Cfg untuk warna
--   keyCfg/keyDef : (khusus obj) kunci Cfg kata kunci nama + nilai awalnya
-- Kunci turunan otomatis: chams = "Chams_<id>", label = "Label_<id>", dist = "Dist_<id>"
local CATS = {
    { id = "Killer", name = "Killer", kind = "role", on = "ESPKiller", col = "KillerColor", def = Color3.fromRGB(235, 50, 50) },
    { id = "Surv", name = "Survivor", kind = "role", on = "ESPSurv", col = "SurvColor", def = Color3.fromRGB(80, 220, 110) },
    { id = "Zombie", name = "Zombie", kind = "npc", on = "ESPZombie", col = "ZombieColor", def = Color3.fromRGB(150, 255, 60) },
    { id = "Gen", name = "Generator", kind = "obj", on = "ObjGen", col = "ColGen", def = Color3.fromRGB(255, 220, 60), keyCfg = "KeyGen", keyDef = "generator" },
    { id = "Hook", name = "Hook", kind = "obj", on = "ObjHook", col = "ColHook", def = Color3.fromRGB(255, 140, 40), keyCfg = "KeyHook", keyDef = "hook" },
    { id = "Gate", name = "Gate", kind = "obj", on = "ObjGate", col = "ColGate", def = Color3.fromRGB(60, 210, 230), keyCfg = "KeyGate", keyDef = "gate" },
    { id = "Pallet", name = "Pallet", kind = "obj", on = "ObjPallet", col = "ColPallet", def = Color3.fromRGB(190, 90, 255), keyCfg = "KeyPallet", keyDef = "pallet" },
    { id = "Window", name = "Window", kind = "obj", on = "ObjWindow", col = "ColWindow", def = Color3.fromRGB(80, 130, 255), keyCfg = "KeyWindow", keyDef = "window" },
}

local byId, objGroups = {}, {}
for _, c in ipairs(CATS) do
    byId[c.id] = c
    c.chams, c.label, c.dist = "Chams_" .. c.id, "Label_" .. c.id, "Dist_" .. c.id
    if c.kind == "obj" then objGroups[#objGroups + 1] = c end
end

return { list = CATS, byId = byId, objGroups = objGroups }
