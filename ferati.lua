local ok_ui, Fatality = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/4lpaca-pin/Fatality/refs/heads/main/src/source.luau"))()
end)
if not ok_ui or not Fatality then warn("[Fatality] UI failed"); return end

local Notifier; pcall(function() Notifier = Fatality:CreateNotifier() end)
pcall(function() Fatality:Loader({ Name = "Fatality", Duration = 2 }) end)

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local MPS = game:GetService("MarketplaceService")
local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local PG = LP:WaitForChild("PlayerGui")

-- ==================== NICKNAME PRIVACY ====================
local NICK = { Hide = true, FakeText = "Fatality User" }
local _origText = {}
local _nickConns = {}

local function _isNickLabel(c)
    if not (c:IsA("TextLabel") or c:IsA("TextButton")) then return false end
    local t = tostring(c.Text or "")
    if t == "" or t == NICK.FakeText then return false end
    local n, dn = LP.Name or "", LP.DisplayName or ""
    return (n ~= "" and (t == n or t:find(n,1,true))) or (dn ~= "" and (t == dn or t:find(dn,1,true)))
end

local function _patchLabel(c)
    if not _origText[c] then _origText[c] = c.Text end
    pcall(function() c.Text = NICK.FakeText end)
    if not _nickConns[c] then
        _nickConns[c] = c:GetPropertyChangedSignal("Text"):Connect(function()
            if not NICK.Hide then return end
            local cur = tostring(c.Text or "")
            if cur ~= NICK.FakeText and _isNickLabel(c) then
                _origText[c] = cur
                pcall(function() c.Text = NICK.FakeText end)
            end
        end)
    end
end

local function applyNickHide()
    if NICK.Hide then
        for _, root in {LP.Character, PG, workspace} do
            pcall(function()
                for _, d in root:GetDescendants() do
                    if _isNickLabel(d) then _patchLabel(d) end
                end
            end)
        end
    end
end

task.spawn(function()
    while task.wait(1) do if NICK.Hide then applyNickHide() end end
end)

-- ==================== ЗАГРУЗКА ITEM_DB С GITHUB ====================
local ITEM_DB_URL = "https://raw.githubusercontent.com/trapovv/babushkadeda/refs/heads/main/item_db.lua"
local ITEM_DB = {}
local success, err = pcall(function()
    ITEM_DB = loadstring(game:HttpGet(ITEM_DB_URL))()
end)
if not success or not ITEM_DB then
    warn("[Fatality] Ошибка загрузки Item DB: " .. tostring(err))
    ITEM_DB = {}
else
    print("✅ Fatality — Загружено " .. #ITEM_DB .. " предметов из GitHub")
end

-- ==================== INSTANT PICKUP (E) ====================
UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.E then
        print("🚀 Instant Pickup (E) активирован — ищем ближайшую легендарку...")
        -- Можно расширить позже
    end
end)

-- ==================== ТВОЙ ОРИГИНАЛЬНЫЙ КОД (ESP, HvH, HvH ESP и т.д.) ====================
-- (весь остальной код из твоего файла остаётся без изменений, только Fekality → Fatality)

local LEG_COLOR = Color3.new(1,0.705882,0)
local COLOR_TOL = 0.1
local function isLegColor(c)
    return math.abs(c.R-LEG_COLOR.R)<COLOR_TOL and math.abs(c.G-LEG_COLOR.G)<COLOR_TOL and math.abs(c.B-LEG_COLOR.B)<COLOR_TOL
end

local function looksLikeUuid(s)
    if not s or #s < 12 then return false end
    if s:match("^%x%x%x%x%x%x%x%x[%-_]%x%x%x%x[%-_]%x%x%x%x[%-_]%x%x%x%x[%-_]%x%x%x%x%x%x%x%x%x%x%x%x$") then return true end
    if s:match("^%x+[%-_]%x+[%-_]%x+[%-_]%x+[%-_]%x+$") then return true end
    if s:match("^%x+[%-_]%x+[%-_]%x+") and not s:match("[g-zG-Z]") then return true end
    return false
end

local S = {On=false,Chrome=true,FontSize=12,BoxWidth=130,MaxDist=180,MaxVisible=25,Transparency=0.45,Search="",MatchOnly=false,PickedColor=Color3.fromRGB(255,215,0),Color=Color3.fromRGB(255,215,0)}
local TAGS = {}
local CONNS = {}
local nameCache = {}
local pendingQueue = {}

local function extractId(t) if not t then return end return tonumber(tostring(t):match("(%d+)")) end
local function getId(model)
    if not model then return end
    local sh = model:FindFirstChildWhichIsA("Shirt",true)
    if sh then local id = extractId(sh.ShirtTemplate); if id then return id end end
    local pa = model:FindFirstChildWhichIsA("Pants",true)
    if pa then local id = extractId(pa.PantsTemplate); if id then return id end end
end

local resolverActive = 0
local function spawnResolver()
    if resolverActive >= 6 then return end
    resolverActive = resolverActive + 1
    task.spawn(function()
        while true do
            local id = table.remove(pendingQueue,1)
            if not id then break end
            local ok,info = pcall(function() return MPS:GetProductInfo(id,Enum.InfoType.Asset) end)
            if ok and info and info.Name and info.Name ~= "" and not looksLikeUuid(info.Name) then
                nameCache[id] = info.Name
            else nameCache[id] = false end
        end
        resolverActive = resolverActive - 1
    end)
end

local function queueResolve(id)
    if not id then return end
    if nameCache[id] ~= nil then return end
    local dbName = ITEM_DB[id]
    if dbName then nameCache[id] = dbName return end
    nameCache[id] = "PENDING"
    table.insert(pendingQueue,id)
    spawnResolver()
end

local function preloadAllNames()
    for _,zone in ipairs(Workspace:GetChildren()) do
        if zone.Name:match("^Shop_ShopZone_") then
            local items = zone:FindFirstChild("ItemSlots")
            if items then
                for _,slot in ipairs(items:GetChildren()) do
                    if slot.Name:match("^Slot_") then
                        queueResolve(getId
