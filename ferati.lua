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
local LP = Players.LocalPlayer
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
    while task.wait(1) do 
        if NICK.Hide then applyNickHide() end 
    end
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
        print("🚀 Instant Pickup активирован — ищем ближайшую вещь...")
        -- Здесь можно добавить полноценную логику подбора
    end
end)

-- ==================== FATILITY MENU ====================
local Window = Fatality.new({ Name = "Fatality", Expire = "never" })

local ItemsMenu = Window:AddMenu({ Name = "ITEMS", Icon = "package" })
local EspMenu = Window:AddMenu({ Name = "ESP", Icon = "eye" })
local InfoMenu = Window:AddMenu({ Name = "INFO", Icon = "info" })

local CatSec = ItemsMenu:AddSection({Name = "Categories", Position = "left"})
CatSec:AddToggle({Name = "Clothing", Default = true})
CatSec:AddToggle({Name = "Accessories", Default = true})
CatSec:AddToggle({Name = "iPhones", Default = true})

CatSec:AddDropdown({Name = "Rarity", Values = {"Common","Uncommon","Rare","Epic","Legendary"}, Multi = true})
CatSec:AddDropdown({Name = "Economy Profile", Values = {"safe","normal","risky","trap","jackpot"}, Multi = true})

local EspSec = EspMenu:AddSection({Name = "ESP", Position = "left"})
EspSec:AddToggle({Name = "Enable ESP", Default = false})

local SettingsSec = InfoMenu:AddSection({Name = "Settings"})
SettingsSec:AddKeybind({Name = "Hide Menu", Default = "RightShift"})

print("Fatality TSUM — Полная база загружена (" .. #ITEM_DB .. " предметов)")

by erafox
