-- Enam palet UI bergaya blok Mario. Hanya tampilan; tidak mengubah fitur game.
local Hub = ...
local Config = Hub.use("config/Config")
local Cfg = Config.Cfg

local Theme = {}
Theme.T = {
    bg=Color3.fromRGB(12,13,18), surface=Color3.fromRGB(20,22,29),
    raised=Color3.fromRGB(28,31,41), steel=Color3.fromRGB(35,50,74),
    steelEdge=Color3.fromRGB(92,130,186), track=Color3.fromRGB(48,54,72),
    stroke=Color3.fromRGB(42,47,62), text=Color3.fromRGB(236,239,247),
    muted=Color3.fromRGB(136,143,162), danger=Color3.fromRGB(240,80,90),
    top=Color3.fromRGB(35,116,196), topText=Color3.fromRGB(255,255,255),
    side=Color3.fromRGB(91,54,35), outline=Color3.fromRGB(31,24,21),
}
local T=Theme.T
local palettes = {
    Overworld={bg=Color3.fromRGB(244,225,180),surface=Color3.fromRGB(255,244,211),raised=Color3.fromRGB(235,211,160),steel=Color3.fromRGB(209,185,135),steelEdge=Color3.fromRGB(116,76,45),track=Color3.fromRGB(191,168,128),stroke=Color3.fromRGB(91,58,38),text=Color3.fromRGB(48,38,31),muted=Color3.fromRGB(116,91,68),danger=Color3.fromRGB(190,48,48),top=Color3.fromRGB(47,139,220),topText=Color3.fromRGB(255,255,255),side=Color3.fromRGB(117,70,43),outline=Color3.fromRGB(55,35,24)},
    Light={bg=Color3.fromRGB(239,231,211),surface=Color3.fromRGB(255,249,231),raised=Color3.fromRGB(229,216,188),steel=Color3.fromRGB(213,194,159),steelEdge=Color3.fromRGB(142,102,67),track=Color3.fromRGB(194,178,150),stroke=Color3.fromRGB(112,79,54),text=Color3.fromRGB(54,43,34),muted=Color3.fromRGB(127,108,88),danger=Color3.fromRGB(190,55,55),top=Color3.fromRGB(185,69,53),topText=Color3.fromRGB(255,255,255),side=Color3.fromRGB(126,88,59),outline=Color3.fromRGB(58,39,27)},
    Dark={bg=Color3.fromRGB(24,25,29),surface=Color3.fromRGB(35,37,43),raised=Color3.fromRGB(46,49,57),steel=Color3.fromRGB(58,62,72),steelEdge=Color3.fromRGB(125,132,148),track=Color3.fromRGB(68,72,83),stroke=Color3.fromRGB(15,16,19),text=Color3.fromRGB(242,243,246),muted=Color3.fromRGB(159,164,175),danger=Color3.fromRGB(244,79,85),top=Color3.fromRGB(48,51,59),topText=Color3.fromRGB(255,255,255),side=Color3.fromRGB(31,33,39),outline=Color3.fromRGB(8,9,11)},
    Underground={bg=Color3.fromRGB(14,25,43),surface=Color3.fromRGB(22,39,63),raised=Color3.fromRGB(30,51,79),steel=Color3.fromRGB(39,67,101),steelEdge=Color3.fromRGB(70,142,205),track=Color3.fromRGB(44,62,85),stroke=Color3.fromRGB(8,15,28),text=Color3.fromRGB(226,239,255),muted=Color3.fromRGB(139,166,195),danger=Color3.fromRGB(255,88,83),top=Color3.fromRGB(21,66,112),topText=Color3.fromRGB(255,255,255),side=Color3.fromRGB(12,24,42),outline=Color3.fromRGB(5,12,24)},
    Castle={bg=Color3.fromRGB(42,27,25),surface=Color3.fromRGB(59,38,34),raised=Color3.fromRGB(76,48,41),steel=Color3.fromRGB(94,56,45),steelEdge=Color3.fromRGB(177,105,62),track=Color3.fromRGB(87,61,53),stroke=Color3.fromRGB(22,13,12),text=Color3.fromRGB(255,231,211),muted=Color3.fromRGB(190,151,129),danger=Color3.fromRGB(239,76,62),top=Color3.fromRGB(133,47,37),topText=Color3.fromRGB(255,239,217),side=Color3.fromRGB(58,30,27),outline=Color3.fromRGB(18,10,9)},
    ["Star Road"]={bg=Color3.fromRGB(35,24,63),surface=Color3.fromRGB(49,34,83),raised=Color3.fromRGB(64,45,105),steel=Color3.fromRGB(82,56,128),steelEdge=Color3.fromRGB(177,132,255),track=Color3.fromRGB(75,60,105),stroke=Color3.fromRGB(18,12,36),text=Color3.fromRGB(247,235,255),muted=Color3.fromRGB(183,160,213),danger=Color3.fromRGB(255,91,139),top=Color3.fromRGB(91,53,150),topText=Color3.fromRGB(255,245,255),side=Color3.fromRGB(40,27,73),outline=Color3.fromRGB(15,9,30)},
}
Theme.names={"Overworld","Light","Dark","Underground","Castle","Star Road"}
local function recolor(root, old, new)
    if not root then return end
    local props={"BackgroundColor3","TextColor3","ImageColor3","BorderColor3","Color"}
    for _,obj in ipairs(root:GetDescendants()) do
        for _,prop in ipairs(props) do
            local ok,value=pcall(function() return obj[prop] end)
            if ok and typeof(value)=="Color3" then
                for key,oldColor in pairs(old) do
                    if value==oldColor then pcall(function() obj[prop]=new[key] end) break end
                end
            end
        end
    end
end
function Theme.apply(name, root)
    local p=palettes[name] or palettes.Overworld
    local old={}
    for k,v in pairs(T) do old[k]=v end
    for k,v in pairs(p) do T[k]=v end
    recolor(root,old,T)
    return name
end
function Theme.set(name, root)
    if not palettes[name] then return false end
    Theme.apply(name,root)
    Config.set("Theme",name)
    return true
end
Theme.apply(Cfg.Theme or "Overworld")
return Theme
