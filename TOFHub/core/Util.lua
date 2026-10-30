-- Fungsi kecil murni (tanpa state) yang dipakai banyak modul
local Util = {}

-- nama root di workspace yang diabaikan saat mencari NPC / objek
Util.SKIP_TOP = { Lobby = true, FakeCharacters = true, Clones = true, Terrain = true, Camera = true }

function Util.hex(c)
    return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

function Util.parseHex(s)
    s = tostring(s):gsub("#", ""):gsub("%s", "")
    if #s == 6 and s:match("^%x+$") then
        return Color3.fromRGB(tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16))
    end
end

function Util.pathOf(i)
    local ok, r = pcall(function() return i:GetFullName() end)
    return ok and r or tostring(i)
end

-- "a, b  c" -> { "a", "b", "c" } (huruf kecil)
function Util.splitKeys(s)
    local t = {}
    for w in tostring(s):gmatch("[^,%s]+") do t[#t + 1] = w:lower() end
    return t
end

-- nama anak workspace paling atas dari sebuah instance
function Util.topName(inst)
    local p = inst
    while p.Parent and p.Parent ~= workspace do p = p.Parent end
    return p.Name
end

-- escape untuk RichText
function Util.esc(s)
    s = tostring(s)
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    return s
end

return Util
