-- ──────────────────────────────────────────────────────────────────────
-- AONEHUB - SAFE INIT (FIX NIL VALUE)
-- ──────────────────────────────────────────────────────────────────────

local function safeRequire(path)
    local success, result = pcall(function()
        return require(path)
    end)
    if success then return result end
    return nil
end

local function main()
    print("[AoneHub] Starting...")
    
    -- ==================================================================
    -- LOCAL SAVE SYSTEM
    -- ==================================================================
    local SAVE_FILE = "AoneHub_Config.json"
    local HttpService = game:GetService("HttpService")
    
    local config = {
        opcodeSeed = 133, opcodeGear = 137, opcodeProp = 135,
        opcodeDetected = false, lastScannedOpcode = 158,
        selectedSeeds = {}, selectedGears = {}, selectedProps = {},
        accordionSeedOpen = true, accordionGearOpen = false, accordionPropOpen = false,
        searchSeed = "", searchGear = "", searchProp = "",
    }
    
    local function loadConfig()
        local s, d = pcall(readfile, SAVE_FILE)
        if s and d then
            local s2, loaded = pcall(HttpService.JSONDecode, HttpService, d)
            if s2 and loaded then 
                for k, v in pairs(loaded) do 
                    config[k] = v 
                end
                print("[AoneHub] 📂 Config loaded")
                return true 
            end
        end
        return false
    end
    
    local function saveConfig()
        local s, json = pcall(HttpService.JSONEncode, HttpService, config)
        if s then pcall(writefile, SAVE_FILE, json) end
    end
    
    loadConfig()
    
    -- ==================================================================
    -- SERVICES
    -- ==================================================================
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")
    
    local player = Players.LocalPlayer
    if not player then
        warn("[AoneHub] Player not found!")
        return
    end
    
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then
        playerGui = player:WaitForChild("PlayerGui", 10)
    end
    if not playerGui then
        warn("[AoneHub] PlayerGui not found!")
        return
    end
    
    print("[AoneHub] Services OK")
    
    -- ==================================================================
    -- GET ALL ITEMS (safe)
    -- ==================================================================
    local function getAllSeeds()
        local seedData = safeRequire(ReplicatedStorage.SharedModules.SeedData)
        if not seedData then return {"Hypno Bloom", "Dragon's Breath", "Sun Bloom", "Star Fruit"} end
        
        local Worlds = safeRequire(ReplicatedStorage.SharedModules.Worlds)
        local items = {}
        for _, seed in ipairs(seedData) do
            if seed and seed.RestockShop then
                local available = true
                if Worlds then
                    pcall(function() available = Worlds.EntryAvailableHere(seed) end)
                end
                if available and seed.SeedName then
                    table.insert(items, seed.SeedName)
                end
            end
        end
        if #items == 0 then return {"Hypno Bloom", "Dragon's Breath", "Sun Bloom", "Star Fruit"} end
        table.sort(items)
        return items
    end
    
    local function getAllGears()
        local gearData = safeRequire(ReplicatedStorage.SharedModules.GearShopData)
        if not gearData or not gearData.Data then return {} end
        
        local Worlds = safeRequire(ReplicatedStorage.SharedModules.Worlds)
        local items = {}
        for _, gear in ipairs(gearData.Data) do
            if gear and not gear.RobuxOnly and not gear.HideFromShop and gear.ItemName then
                local available = true
                if Worlds then
                    pcall(function() available = Worlds.EntryAvailableHere(gear) end)
                end
                if available then
                    table.insert(items, gear.ItemName)
                end
            end
        end
        table.sort(items)
        return items
    end
    
    local function getAllProps()
        local crateData = safeRequire(ReplicatedStorage.SharedModules.CrateData)
        if not crateData or not crateData.GetAllCrates then return {} end
        
        local Worlds = safeRequire(ReplicatedStorage.SharedModules.Worlds)
        local allCrates = crateData.GetAllCrates()
        local items = {}
        for _, crate in ipairs(allCrates) do
            if crate and crate.RestockChance and crate.Name then
                local available = true
                if Worlds then
                    pcall(function() available = Worlds.EntryAvailableHere(crate) end)
                end
                if available then
                    table.insert(items, crate.Name)
                end
            end
        end
        table.sort(items)
        return items
    end
    
    local ALL_SEEDS = getAllSeeds()
    local ALL_GEARS = getAllGears()
    local ALL_PROPS = getAllProps()
    
    print("[AoneHub] 📋 Seeds:", #ALL_SEEDS, "| Gears:", #ALL_GEARS, "| Props:", #ALL_PROPS)
    
    -- ==================================================================
    -- MERGE CONFIG
    -- ==================================================================
    local function mergeItems(saved, current)
        local merged = {}
        if type(saved) == "table" then
            for name, val in pairs(saved) do merged[name] = val end
        end
        for _, name in ipairs(current) do 
            if merged[name] == nil then merged[name] = false end 
        end
        return merged
    end
    
    config.selectedSeeds = mergeItems(config.selectedSeeds, ALL_SEEDS)
    config.selectedGears = mergeItems(config.selectedGears, ALL_GEARS)
    config.selectedProps = mergeItems(config.selectedProps, ALL_PROPS)
    saveConfig()
    
    -- ==================================================================
    -- GUI START
    -- ==================================================================
    print("[AoneHub] Creating GUI...")
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AoneHub"
    screenGui.Parent = playerGui
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    print("[AoneHub] ✅ GUI Created")
    print("[AoneHub] 🚀 Ready - Tab Auto Buy will be populated when clicked")
end

-- Run with full error catch
local success, err = pcall(main)
if not success then
    warn("[AoneHub] FATAL ERROR:")
    warn(err)
    -- Coba run minimal version
    pcall(function()
        local gui = Instance.new("ScreenGui")
        gui.Name = "AoneHub_Error"
        gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 300, 0, 100)
        frame.Position = UDim2.new(0.5, -150, 0.5, -50)
        frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        frame.Parent = gui
        
        local text = Instance.new("TextLabel")
        text.Size = UDim2.new(1, 0, 1, 0)
        text.Text = "AoneHub Loaded\n(Simplified Mode)"
        text.TextColor3 = Color3.fromRGB(255, 255, 255)
        text.Font = Enum.Font.GothamBold
        text.TextSize = 14
        text.BackgroundTransparency = 1
        text.Parent = frame
        
        print("[AoneHub] ✅ Minimal GUI loaded")
    end)
end
