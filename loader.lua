-- PIDI | GitHub raw loader untuk TOFHub (modular)
-- Pakai:  loadstring(game:HttpGet("https://raw.githubusercontent.com/USER/REPO/main/loader.lua"))()
-- Ganti USER / REPO / BRANCH di bawah (atau set getgenv().PIDI_REPO sebelum run).

local cfg = (getgenv and getgenv().PIDI_REPO) or {}
local USER   = cfg.user   or "teneobot-lab"
local REPO   = cfg.repo   or "VIDEY"
local BRANCH = cfg.branch or "main"

local BASE = ("https://raw.githubusercontent.com/%s/%s/%s/TOFHub/"):format(USER, REPO, BRANCH)

if type(loadstring) ~= "function" then
    return warn("[PIDI] loadstring() tidak tersedia di executor ini.")
end

local function fetch(url)
    -- cache-buster supaya tidak dapat versi lama dari CDN raw.githubusercontent
    local sep = url:find("?", 1, true) and "&" or "?"
    local stamp = tostring(os.time()) .. tostring(math.floor(os.clock() * 1000))
    return game:HttpGet(url .. sep .. "t=" .. stamp)
end

local okGet, src = pcall(fetch, BASE .. "main.lua")
if not okGet or type(src) ~= "string" or src == "" then
    return warn("[PIDI] Gagal download main.lua dari " .. BASE .. " -> " .. tostring(src))
end

-- aktifkan mode online di main.lua: isi BASE_URL (semua modul diambil dari GitHub)
local patched, n = src:gsub('local BASE_URL = nil[^\n]*', function()
    return 'local BASE_URL = "' .. BASE .. '"'
end, 1)
if n == 0 then
    return warn("[PIDI] Baris 'local BASE_URL = nil' tidak ditemukan di main.lua.")
end

local okCompile, chunk = pcall(loadstring, patched, "@PIDI/TOFHub/main.lua")
if not okCompile or type(chunk) ~= "function" then
    return warn("[PIDI] Gagal compile main.lua: " .. tostring(chunk))
end

local okRun, err = pcall(chunk)
if not okRun then
    warn("[PIDI] TOFHub gagal start: " .. tostring(err))
end
