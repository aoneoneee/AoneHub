-- ==================================================================
-- SERVICES & REQUIREMENTS
-- ==================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Services untuk Auto Leveling
local DataService = require(ReplicatedStorage.Modules.DataService)
local PetsService = require(ReplicatedStorage.Modules.PetServices.PetsService)
local PetShardService_RE = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetShardService_RE")

-- Constants
local MAX_PET_SLOTS = 8
local BASE_WEIGHT_NORMAL = 3.5
local BASE_WEIGHT_RAINBOW = 5.5
local LEVEL_TARGET_NORMAL = 50
local LEVEL_TARGET_RAINBOW = 40

-- Colors
local C = {
    bg = Color3.fromRGB(28, 28, 35),
    sidebar = Color3.fromRGB(22, 22, 28),
    accent = Color3.fromRGB(80, 120, 200),
    text = Color3.fromRGB(240, 240, 240),
    textDim = Color3.fromRGB(150, 150, 160),
    success = Color3.fromRGB(50, 180, 50),
    danger = Color3.fromRGB(200, 50, 50),
    warning = Color3.fromRGB(255, 200, 0),
}

-- ==================================================================
-- CONFIG
-- ==================================================================
local function getConfigPath()
    local basePath = "AoneHub"
    pcall(function() makefolder(basePath) end)
    return basePath .. "/AoneHub_AutoLeveling.json"
end

local SAVE_FILE = getConfigPath()

local config = {
    teamPresets = {},
    weightPresets = {},
    mutationPresets = {},
    advancedPresets = {},
    targetLevel = 50,
    advancedTargetLevel = 500,
    rainbowMode = false,
    unwantedMutations = {},
    selectedTeamPreset = nil,
    selectedWeightPreset = nil,
    selectedMutationPreset = nil,
    selectedAdvancedPreset = nil,
    isAutoWeight = false,
    isAutoMutation = false,
    isAdvancedLeveling = false,
    selectedPetTypes = {},
    antiAfkToggle = false,
}

local function loadConfig()
    local s, d = pcall(readfile, SAVE_FILE)
    if s and d then
        local s2, loaded = pcall(HttpService.JSONDecode, HttpService, d)
        if s2 and loaded then
            for k, v in pairs(loaded) do 
                config[k] = v 
            end
            
            if config.teamPresets == nil then config.teamPresets = {} end
            if config.weightPresets == nil then config.weightPresets = {} end
            if config.mutationPresets == nil then config.mutationPresets = {} end
            if config.advancedPresets == nil then config.advancedPresets = {} end
            if config.targetLevel == nil then config.targetLevel = 50 end
            if config.advancedTargetLevel == nil then config.advancedTargetLevel = 500 end
            if config.rainbowMode == nil then config.rainbowMode = false end
            if config.unwantedMutations == nil then config.unwantedMutations = {} end
            if config.isAutoWeight == nil then config.isAutoWeight = false end
            if config.isAutoMutation == nil then config.isAutoMutation = false end
            if config.isAdvancedLeveling == nil then config.isAdvancedLeveling = false end
            if config.selectedPetTypes == nil then config.selectedPetTypes = {} end
            if config.antiAfkToggle == nil then config.antiAfkToggle = false end
            
            return true
        end
    end
    return false
end

local function saveConfig()
    local s, json = pcall(HttpService.JSONEncode, HttpService, config)
    if s then 
        pcall(writefile, SAVE_FILE, json) 
    end
end

loadConfig()

local function safeRequire(path)
    local s, r = pcall(function() 
        return require(path) 
    end)
    if s then return r end
    return nil
end

-- ==================================================================
-- AUTO LEVELING STATE
-- ==================================================================
local selectedTeamPreset = config.selectedTeamPreset
local selectedWeightPreset = config.selectedWeightPreset
local selectedAdvancedPreset = config.selectedAdvancedPreset
local selectedMutationPreset = config.selectedMutationPreset
local selectedPetTypes = config.selectedPetTypes or {}
local queuedPets = {}
local allSelectedPets = {}
local equippedTargetPets = {}
local targetLevel = config.targetLevel or 50
local advancedTargetLevel = config.advancedTargetLevel or 500
local isLeveling = false
local isAutoWeight = config.isAutoWeight or false
local isAdvancedLeveling = config.isAdvancedLeveling or false
local isAutoMutation = config.isAutoMutation or false
local rainbowMode = config.rainbowMode or false
local targetSearchText = ""
local petSearchText = ""
local mutationSearchText = ""
local tempPresetPets = {}
local unwantedMutations = config.unwantedMutations or {}
local availableMutations = {}
local editingPresetName = nil
local isGuiDestroyed = false  -- ⭐ TAMBAHKAN INI

-- Forward declarations
local StatusLabel
local updateStatus
local rainbowTask = nil

-- ⭐ Helper function untuk cek apakah masih alive
local function isAlive()
    return not isGuiDestroyed and isLeveling
end

-- Warna yang digunakan
local A = {
    warning = Color3.fromRGB(255, 200, 0),
    danger = Color3.fromRGB(255, 60, 60),
}

-- Daftar warna rainbow
local rainbowColors = {
    Color3.fromRGB(255, 60, 60),   -- 🔴 Merah
    Color3.fromRGB(255, 200, 0),   -- 🟡 Kuning
    Color3.fromRGB(60, 200, 80),   -- 🟢 Hijau
    Color3.fromRGB(30, 100, 220),  -- 🔵 Biru
    Color3.fromRGB(150, 60, 220),  -- 🟣 Ungu
}

local colorIndex = 1
    
-- ==================================================================
-- PET DATA FUNCTIONS
-- ==================================================================
local function getPlayerPetData()
    local playerData = DataService:GetData()
    if playerData and playerData.PetsData then
        return playerData.PetsData
    end
    return nil
end

local function getPetType(petUUID)
    local petsData = getPlayerPetData()
    if not petsData then return "Unknown" end
    
    local petData = petsData.PetInventory.Data[petUUID]
    if petData then
        if petData.PetType then
            return petData.PetType
        elseif petData.PetData then
            return petData.PetData.PetType or petData.PetData.Type or "Unknown"
        elseif petData.Type then
            return petData.Type
        end
    end
    return "Unknown"
end

local function getPetLevel(petUUID)
    local petsData = getPlayerPetData()
    if not petsData then return 0 end
    
    local petData = petsData.PetInventory.Data[petUUID]
    if petData then
        if petData.Level then
            return petData.Level
        elseif petData.PetData then
            return petData.PetData.Level or petData.PetData.CurrentLevel or 0
        end
    end
    return 0
end

local function getPetMutationName(petUUID)
    local petsData = getPlayerPetData()
    if not petsData then return nil end
    
    local petData = petsData.PetInventory.Data[petUUID]
    if not petData then return nil end
    
    local mutationType = nil
    if petData.PetData then
        mutationType = petData.PetData.MutationType
    end
    if not mutationType then
        mutationType = petData.MutationType
    end
    
    if mutationType and mutationType ~= "None" and mutationType ~= "Normal" and mutationType ~= "m" then
        local registry = safeRequire(ReplicatedStorage.Data.PetRegistry.PetMutationRegistry)
        if registry and registry.EnumToPetMutation then
            local mutationName = registry.EnumToPetMutation[mutationType]
            if mutationName then
                return mutationName
            end
        end
        return mutationType
    end
    return nil
end

local function getPetDisplayName(petUUID)
    local petType = getPetType(petUUID)
    local mutation = getPetMutationName(petUUID)
    if mutation then
        return string.format("%s %s", mutation, petType)
    end
    return petType
end

local function getPetWeight(petUUID)
    local petsData = getPlayerPetData()
    if not petsData then return 0 end
    
    local petData = petsData.PetInventory.Data[petUUID]
    if petData then
        if petData.BaseWeight then
            return petData.BaseWeight
        elseif petData.PetData and petData.PetData.BaseWeight then
            return petData.PetData.BaseWeight
        elseif petData.Weight then
            return petData.Weight
        elseif petData.PetData and petData.PetData.Weight then
            return petData.PetData.Weight
        end
    end
    return 0
end

local function getEquippedPets()
    local petsData = getPlayerPetData()
    if not petsData then return {} end
    return petsData.EquippedPets or {}
end

local function isPetValid(petUUID)
    if not petUUID then return false end
    
    local petsData = getPlayerPetData()
    if not petsData then return false end
    
    local inventory = petsData.PetInventory.Data
    if not inventory then return false end
    
    return inventory[petUUID] ~= nil
end

local function cleanupInvalidPets()
    local removedCount = 0
    
    for i = #allSelectedPets, 1, -1 do
        if not isPetValid(allSelectedPets[i]) then
            table.remove(allSelectedPets, i)
            removedCount = removedCount + 1
        end
    end
    
    for i = #queuedPets, 1, -1 do
        if not isPetValid(queuedPets[i]) then
            table.remove(queuedPets, i)
        end
    end
    
    for i = #equippedTargetPets, 1, -1 do
        if not isPetValid(equippedTargetPets[i]) then
            table.remove(equippedTargetPets, i)
        end
    end
    
    if removedCount > 0 and StatusLabel then
        StatusLabel.Text = string.format("⚠️ %d pet hilang, dihapus", removedCount)
    end
    
    return removedCount
end

local function equipPet(petUUID)
    if not isPetValid(petUUID) then
        return false, "Pet tidak valid/hilang"
    end
    
    local success, err = pcall(function()
        PetsService:EquipPet(petUUID, CFrame.new(0, 10, 0))
    end)
    
    if not success then
        return false, tostring(err)
    end
    
    wait(0.5)
    local equipped = getEquippedPets()
    if not table.find(equipped, petUUID) then
        return false, "Pet tidak ter-equip"
    end
    
    return true, nil
end

local function unequipPet(petUUID)
    local success = pcall(function()
        PetsService:UnequipPet(petUUID)
    end)
    return success
end

local function getMutationStatus(petUUID)
    local petsData = getPlayerPetData()
    if not petsData then return "none" end
    
    local petData = petsData.PetInventory.Data[petUUID]
    if not petData then return "none" end
    
    local mutationType = nil
    if petData.PetData then
        mutationType = petData.PetData.MutationType
    end
    if not mutationType then
        mutationType = petData.MutationType
    end
    
    if not mutationType or mutationType == "None" or mutationType == "Normal" or mutationType == "m" then
        return "none"
    end
    
    local mutationName = mutationType
    local registry = safeRequire(ReplicatedStorage.Data.PetRegistry.PetMutationRegistry)
    if registry and registry.EnumToPetMutation then
        mutationName = registry.EnumToPetMutation[mutationType] or mutationType
    end
    
    for _, unwanted in ipairs(unwantedMutations) do
        if unwanted == mutationName then
            return "unwanted", mutationName
        end
    end
    
    return "desired", mutationName
end

local function findPetModelByUUID(petUUID)
    local petsPhysical = workspace:FindFirstChild("PetsPhysical")
    if not petsPhysical then return nil end
    
    for _, child in ipairs(petsPhysical:GetChildren()) do
        if child.Name == "PetMover" then
            local petModel = child:FindFirstChild(petUUID)
            if petModel then
                return petModel
            end
        end
    end
    
    for _, descendant in ipairs(petsPhysical:GetDescendants()) do
        if descendant:IsA("Model") and descendant.Name == petUUID then
            return descendant
        end
    end
    
    return nil
end

local function isCleansingShard(tool)
    if not tool:IsA("Tool") then return false end
    
    local shardType = tool:GetAttribute("u")
    if shardType then
        return tostring(shardType) == "Cleansing Pet Shard"
    end
    
    local nameLower = string.lower(tool.Name)
    return string.find(nameLower, "cleansing") ~= nil
end

local function useCleansingShard(petUUID)
    if not isPetValid(petUUID) then
        return false, "Pet sudah tidak ada"
    end
    
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then 
        return false, "Backpack tidak ditemukan"
    end
    
    local cleansingTool = nil
    for _, tool in ipairs(backpack:GetChildren()) do
        if isCleansingShard(tool) then
            cleansingTool = tool
            break
        end
    end
    
    if not cleansingTool then
        return false, "Tidak ada Cleansing Shard"
    end
    
    local petModel = findPetModelByUUID(petUUID)
    if not petModel then
        for i = 1, 10 do
            wait(0.5)
            petModel = findPetModelByUUID(petUUID)
            if petModel then break end
        end
        
        if not petModel then
            return false, "Pet model tidak ditemukan"
        end
    end
    
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return false, "Humanoid tidak ditemukan"
    end
    
    local equipOk = pcall(function()
        humanoid:EquipTool(cleansingTool)
    end)
    
    if not equipOk then
        return false, "Gagal equip tool"
    end
    
    wait(0.5)
    
    local fireOk, fireErr = pcall(function()
        PetShardService_RE:FireServer("ApplyShard", petModel)
    end)
    
    if not fireOk then
        return false, "FireServer error: " .. tostring(fireErr)
    end
    
    wait(2)
    
    pcall(function()
        humanoid:UnequipTools()
    end)
    
    wait(0.5)
    
    return true, nil
end

-- ==================================================================
-- PRESET FUNCTIONS
-- ==================================================================
local function saveTeamPreset(presetName, petList)
    local petsWithInfo = {}
    for _, petUUID in ipairs(petList) do
        local mutation = getPetMutationName(petUUID)
        table.insert(petsWithInfo, {
            UUID = petUUID,
            PetType = getPetType(petUUID),
            Mutation = mutation,
            Level = getPetLevel(petUUID)
        })
    end
    
    config.teamPresets[presetName] = {
        name = presetName,
        pets = petsWithInfo,
        savedAt = os.time()
    }
    
    saveConfig()
end

local function loadTeamPresets()
    return config.teamPresets or {}
end

local function getPresetUUIDs(presetName)
    local preset = config.teamPresets[presetName]
    if preset then
        local uuids = {}
        for _, petInfo in ipairs(preset.pets) do
            if isPetValid(petInfo.UUID) then
                table.insert(uuids, petInfo.UUID)
            end
        end
        return uuids
    end
    return {}
end

local function deletePreset(presetName)
    if not presetName then return false end
    
    if config.teamPresets[presetName] then
        config.teamPresets[presetName] = nil
        saveConfig()
        return true
    end
    return false
end

local function getWeightTarget()
    return rainbowMode and BASE_WEIGHT_RAINBOW or BASE_WEIGHT_NORMAL
end

local function getLevelTargetForWeight()
    return rainbowMode and LEVEL_TARGET_RAINBOW or LEVEL_TARGET_NORMAL
end

local function getPetsForWeight()
    local weightTarget = getWeightTarget()
    local result = {}
    
    for _, petUUID in ipairs(allSelectedPets) do
        if isPetValid(petUUID) then
            local petWeight = getPetWeight(petUUID)
            if petWeight < weightTarget then
                table.insert(result, petUUID)
            end
        end
    end
    
    return result
end

local function getPetsForMutation()
    local result = {}
    
    for _, petUUID in ipairs(allSelectedPets) do
        if isPetValid(petUUID) then
            local status = getMutationStatus(petUUID)
            if status == "none" or status == "unwanted" then
                table.insert(result, petUUID)
            end
        end
    end
    
    return result
end

local function getPetsForAdvanced()
    local result = {}
    
    for _, petUUID in ipairs(allSelectedPets) do
        if isPetValid(petUUID) then
            local petLevel = getPetLevel(petUUID)
            if petLevel < advancedTargetLevel then
                table.insert(result, petUUID)
            end
        end
    end
    
    return result
end

local function getPetsForNormalLeveling()
    local result = {}
    
    for _, petUUID in ipairs(allSelectedPets) do
        if isPetValid(petUUID) then
            local petLevel = getPetLevel(petUUID)
            if petLevel < targetLevel then
                table.insert(result, petUUID)
            end
        end
    end
    
    return result
end

-- ==================================================================
-- GUI SKELETON
-- ==================================================================
local oldGui = playerGui:FindFirstChild("AoneHub")

if oldGui then
    oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AoneHub"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false

screenGui.Destroying:Connect(function()
    isGuiDestroyed = true
    isLeveling = false
    config.selectedTeamPreset = selectedTeamPreset
    config.selectedWeightPreset = selectedWeightPreset
    config.selectedAdvancedPreset = selectedAdvancedPreset
    config.selectedMutationPreset = selectedMutationPreset
    config.targetLevel = targetLevel
    config.advancedTargetLevel = advancedTargetLevel
    config.rainbowMode = rainbowMode
    config.unwantedMutations = unwantedMutations
    config.isAutoWeight = isAutoWeight
    config.isAutoMutation = isAutoMutation
    config.isAdvancedLeveling = isAdvancedLeveling
    config.selectedPetTypes = selectedPetTypes
    saveConfig()
end)

local minimizedCircle = Instance.new("ImageButton")
minimizedCircle.Size = UDim2.new(0, 50, 0, 50)
minimizedCircle.Position = UDim2.new(0.5, -25, 0.5, -25)
minimizedCircle.Image = "rbxassetid://78929291660435"
minimizedCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
minimizedCircle.BackgroundTransparency = 1
minimizedCircle.BorderSizePixel = 0
minimizedCircle.Visible = false
minimizedCircle.AutoButtonColor = false
minimizedCircle.Parent = screenGui
Instance.new("UICorner", minimizedCircle).CornerRadius = UDim.new(0, 15)

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 580, 0, 320)
mainFrame.Position = UDim2.new(0.5, -290, 0.5, -160)
mainFrame.BackgroundColor3 = C.bg
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Active = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 28)
titleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local titleFill = Instance.new("Frame")
titleFill.Size = UDim2.new(1, 0, 0.5, 0)
titleFill.Position = UDim2.new(0, 0, 0.5, 0)
titleFill.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
titleFill.BorderSizePixel = 0
titleFill.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0.6, 0, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.Text = "AoneHub"
titleLabel.TextColor3 = C.text
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 11
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.BackgroundTransparency = 1
titleLabel.Parent = titleBar

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 22, 0, 22)
minimizeBtn.Position = UDim2.new(1, -50, 0, 3)
minimizeBtn.Text = "–"
minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 14
minimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
minimizeBtn.BorderSizePixel = 0
minimizeBtn.AutoButtonColor = false
minimizeBtn.Parent = titleBar
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 4)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 22, 0, 22)
closeBtn.Position = UDim2.new(1, -25, 0, 3)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 11
closeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = false
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)

--==================================================
-- MINIMIZE / RESTORE
--==================================================

local lastMainPosition = mainFrame.Position
local circlePosition = nil

minimizeBtn.MouseButton1Click:Connect(function()

    -- Simpan posisi MainFrame
    lastMainPosition = mainFrame.Position

    -- Jika circle belum pernah diposisikan,
    -- letakkan di posisi MainFrame
    if not circlePosition then
        circlePosition = UDim2.new(
            0,
            mainFrame.AbsolutePosition.X,
            0,
            mainFrame.AbsolutePosition.Y
        )
    end

    minimizedCircle.Position = circlePosition

    mainFrame.Visible = false
    minimizedCircle.Visible = true
end)

minimizedCircle.MouseButton1Click:Connect(function()

    -- Simpan posisi circle setelah kemungkinan digeser
    circlePosition = minimizedCircle.Position

    -- Kembalikan MainFrame ke posisi terakhir
    mainFrame.Position = lastMainPosition

    minimizedCircle.Visible = false
    mainFrame.Visible = true
end)

closeBtn.MouseButton1Click:Connect(function()
    isGuiDestroyed = true
    isLeveling = false
    screenGui:Destroy()
end)

--==================================================
-- DRAG FUNCTION
--==================================================

local function makeDraggable(handle, target)
    local dragging = false
    local dragStart
    local startPos
    local dragInput

    handle.Active = true

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            dragging = true
            dragStart = input.Position
            startPos = target.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then

            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart

            target.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,

                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0.2, 0, 1, -28)
sidebar.Position = UDim2.new(0, 0, 0, 28)
sidebar.BackgroundColor3 = C.sidebar
sidebar.BorderSizePixel = 0
sidebar.Parent = mainFrame
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 10)

local sidebarFill = Instance.new("Frame")
sidebarFill.Size = UDim2.new(1, 0, 0.3, 0)
sidebarFill.Position = UDim2.new(0, 0, 0.85, 0)
sidebarFill.BackgroundColor3 = C.sidebar
sidebarFill.BorderSizePixel = 0
sidebarFill.Parent = sidebar

local menuLabel = Instance.new("TextLabel")
menuLabel.Size = UDim2.new(1, 0, 0, 16)
menuLabel.Position = UDim2.new(0, 0, 0, 6)
menuLabel.Text = "MENU"
menuLabel.TextColor3 = Color3.fromRGB(120, 120, 130)
menuLabel.Font = Enum.Font.GothamBold
menuLabel.TextSize = 9
menuLabel.TextXAlignment = Enum.TextXAlignment.Center
menuLabel.BackgroundTransparency = 1
menuLabel.Parent = sidebar

local sep = Instance.new("Frame")
sep.Size = UDim2.new(0.7, 0, 0, 1)
sep.Position = UDim2.new(0.15, 0, 0, 26)
sep.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
sep.BorderSizePixel = 0
sep.Parent = sidebar

local tabs = {
    {name="Farm", label="🌾 Farm"},
    {name="Weight", label="🐘 Weight"},
    {name="Mutation", label="🧬 Mutation"},
    {name="Event", label="🔥 Event"},
    {name="Tools", label="🔧 Tools"},
    {name="AutoBuy", label="🛒 Buy"},
    {name="AutoSell", label="💰 Sell"},
    {name="Trade", label="📧 Trade"},
    {name="Ekstra", label="⚙️ Extra"}
}

local tabBtns = {}
local activeTab = nil

for i, tab in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.82, 0, 0, 22)
    btn.Position = UDim2.new(0.09, 0, 0, 30 + (i-1)*27)
    btn.Text = tab.label
    btn.TextColor3 = C.textDim
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 8
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    
    btn.MouseEnter:Connect(function()
        if activeTab ~= tab.name then
            btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
        end
    end)
    
    btn.MouseLeave:Connect(function()
        if activeTab ~= tab.name then
            btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
        end
    end)
    
    tabBtns[tab.name] = btn
end

local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(0.8, -8, 1, -34)
contentArea.Position = UDim2.new(0.2, 4, 0, 32)
contentArea.BackgroundTransparency = 1
contentArea.ClipsDescendants = true
contentArea.Parent = mainFrame

local defaultView = Instance.new("Frame")
defaultView.Size = UDim2.new(1, 0, 1, 0)
defaultView.BackgroundTransparency = 1
defaultView.Parent = contentArea

local logoLabel = Instance.new("TextLabel")
logoLabel.Size = UDim2.new(1, 0, 0, 32)
logoLabel.Position = UDim2.new(0, 0, 0.35, -16)
logoLabel.Text = "AoneHub"
logoLabel.TextColor3 = C.accent
logoLabel.Font = Enum.Font.GothamBlack
logoLabel.TextSize = 24
logoLabel.BackgroundTransparency = 1
logoLabel.Parent = defaultView

local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(1, 0, 0, 14)
subLabel.Position = UDim2.new(0, 0, 0.5, 0)
subLabel.Text = "Pilih menu di samping"
subLabel.TextColor3 = C.textDim
subLabel.Font = Enum.Font.Gotham
subLabel.TextSize = 10
subLabel.BackgroundTransparency = 1
subLabel.Parent = defaultView

makeDraggable(titleBar, mainFrame)
makeDraggable(minimizedCircle, minimizedCircle)

local tabFrames = {}
for _, tab in ipairs(tabs) do
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = false
    f.Parent = contentArea
    tabFrames[tab.name] = f
end

-- ==================================================================
-- WEIGHT TAB
-- ==================================================================
local weightTab = tabFrames["Weight"]

local weightScroll = Instance.new("ScrollingFrame")
weightScroll.Size = UDim2.new(1, -10, 1, -10)
weightScroll.Position = UDim2.new(0, 5, 0, 5)
weightScroll.BackgroundTransparency = 1
weightScroll.BorderSizePixel = 0
weightScroll.ScrollBarThickness = 4
weightScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
weightScroll.CanvasSize = UDim2.new(0, 0, 0, 2000)
weightScroll.Parent = weightTab

local weightLayout = Instance.new("UIListLayout")
weightLayout.Padding = UDim.new(0, 6)
weightLayout.SortOrder = Enum.SortOrder.LayoutOrder
weightLayout.Parent = weightScroll

-- ==================================================================
-- UI HELPERS
-- ==================================================================
local function createSection(parent, title)
    local SectionFrame = Instance.new("Frame")
    SectionFrame.Size = UDim2.new(1, -10, 0, 200)
    SectionFrame.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
    SectionFrame.BorderSizePixel = 0
    SectionFrame.Parent = parent

    local UICornerSection = Instance.new("UICorner")
    UICornerSection.CornerRadius = UDim.new(0, 6)
    UICornerSection.Parent = SectionFrame

    local SectionTitle

    -- Buat header hanya jika title diberikan
    if title then
        SectionTitle = Instance.new("TextLabel")
        SectionTitle.Size = UDim2.new(1, -20, 0, 22)
        SectionTitle.Position = UDim2.new(0, 10, 0, 3)
        SectionTitle.BackgroundTransparency = 1
        SectionTitle.Font = Enum.Font.GothamBold
        SectionTitle.Text = title
        SectionTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
        SectionTitle.TextSize = 11
        SectionTitle.TextXAlignment = Enum.TextXAlignment.Left
        SectionTitle.Parent = SectionFrame
    end

    return SectionFrame, SectionTitle
end

-- ==================================================================
-- DYNAMIC DROPDOWN (FIXED - AUTO REPOSITION)
-- ==================================================================
local function createDynamicDropdown(parent, position, placeholder, parentSection, baseSectionHeight, parentScroll)
    local width = 1
    local offsetX = -20
    local itemHeight = 22
    local maxListHeight = 100
    
    local originalSectionHeight = baseSectionHeight or 120
    
    -- Container
    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(width, offsetX, 0, 28)
    Container.Position = position
    Container.BackgroundTransparency = 1
    Container.ClipsDescendants = true
    Container.ZIndex = 10
    Container.Parent = parent
    
    -- Header
    local HeaderFrame = Instance.new("Frame")
    HeaderFrame.Size = UDim2.new(1, 0, 0, 28)
    HeaderFrame.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    HeaderFrame.BorderSizePixel = 0
    HeaderFrame.ZIndex = 10
    HeaderFrame.Parent = Container
    
    local UICornerHeader = Instance.new("UICorner")
    UICornerHeader.CornerRadius = UDim.new(0, 4)
    UICornerHeader.Parent = HeaderFrame
    
    local HeaderButton = Instance.new("TextButton")
    HeaderButton.Size = UDim2.new(1, -20, 1, 0)
    HeaderButton.BackgroundTransparency = 1
    HeaderButton.Font = Enum.Font.Gotham
    HeaderButton.Text = placeholder
    HeaderButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    HeaderButton.TextSize = 9
    HeaderButton.TextXAlignment = Enum.TextXAlignment.Left
    HeaderButton.ZIndex = 11
    HeaderButton.Parent = HeaderFrame
    
    local HeaderPadding = Instance.new("UIPadding")
    HeaderPadding.PaddingLeft = UDim.new(0, 8)
    HeaderPadding.Parent = HeaderButton
    
    local ArrowLabel = Instance.new("TextLabel")
    ArrowLabel.Size = UDim2.new(0, 15, 0, 20)
    ArrowLabel.Position = UDim2.new(1, -18, 0, 4)
    ArrowLabel.BackgroundTransparency = 1
    ArrowLabel.Font = Enum.Font.GothamBold
    ArrowLabel.Text = "▼"
    ArrowLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
    ArrowLabel.TextSize = 10
    ArrowLabel.ZIndex = 11
    ArrowLabel.Parent = HeaderFrame
    
    -- List Container
    local ListContainer = Instance.new("Frame")
    ListContainer.Size = UDim2.new(1, 0, 0, 0)
    ListContainer.Position = UDim2.new(0, 0, 0, 30)
    ListContainer.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
    ListContainer.BorderSizePixel = 0
    ListContainer.Visible = false
    ListContainer.ZIndex = 10
    ListContainer.Parent = Container
    
    local UICornerList = Instance.new("UICorner")
    UICornerList.CornerRadius = UDim.new(0, 4)
    UICornerList.Parent = ListContainer
    
    -- List Scroll
    local ListScroll = Instance.new("ScrollingFrame")
    ListScroll.Size = UDim2.new(1, -4, 1, -4)
    ListScroll.Position = UDim2.new(0, 2, 0, 2)
    ListScroll.BackgroundTransparency = 1
    ListScroll.BorderSizePixel = 0
    ListScroll.ScrollBarThickness = 3
    ListScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    ListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    ListScroll.ZIndex = 11
    ListScroll.Parent = ListContainer
    
    local ListLayout = Instance.new("UIListLayout")
    ListLayout.Padding = UDim.new(0, 2)
    ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ListLayout.Parent = ListScroll
    
    local isOpen = false
    
    local function getItemCount()
        local count = 0
        for _, child in pairs(ListScroll:GetChildren()) do
            if child:IsA("TextButton") then
                count = count + 1
            end
        end
        return count
    end
    
    -- ⭐ KUNCI PERBAIKAN: Update semua section & canvas size
    local function updateAll()
        local itemCount = getItemCount()
        local contentHeight = itemCount * (itemHeight + 2) + 2
        local listHeight = math.min(contentHeight, maxListHeight)
        
        -- Update ListContainer
        ListContainer.Size = UDim2.new(1, 0, 0, listHeight)
        ListScroll.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
        
        -- Update Container
        if isOpen then
            Container.Size = UDim2.new(width, offsetX, 0, 30 + listHeight + 2)
        else
            Container.Size = UDim2.new(width, offsetX, 0, 28)
        end
        
        -- ⭐ Update parent section (yang berisi dropdown)
        if parentSection then
            local extraHeight = 0
            if isOpen then
                extraHeight = listHeight + 2
            end
            
            parentSection.Size = UDim2.new(
                parentSection.Size.X.Scale,
                parentSection.Size.X.Offset,
                0,
                originalSectionHeight + extraHeight
            )
        end
        
        -- ⭐ Update CanvasSize dari parent ScrollingFrame
        if parentScroll then
            -- Hitung total height dari semua section
            local totalHeight = 0
            local layout = parentScroll:FindFirstChildOfClass("UIListLayout")
            local padding = layout and layout.Padding.Offset or 6
            
            for _, child in pairs(parentScroll:GetChildren()) do
                if child:IsA("Frame") and child ~= ListContainer then
                    totalHeight = totalHeight + child.Size.Y.Offset + padding
                end
            end
            
            parentScroll.CanvasSize = UDim2.new(0, 0, 0, math.max(totalHeight + 20, 500))
        end
    end
    
    local function close()
        if isOpen then
            isOpen = false
            ListContainer.Visible = false
            ArrowLabel.Text = "▼"
            updateAll()
        end
    end
    
    local function toggle()
        isOpen = not isOpen
        
        if isOpen then
            ListContainer.Visible = true
            ArrowLabel.Text = "▲"
        else
            ListContainer.Visible = false
            ArrowLabel.Text = "▼"
        end
        updateAll()
    end
    
    HeaderButton.MouseButton1Click:Connect(toggle)
    
    return {
        Container = Container,
        HeaderButton = HeaderButton,
        ListContainer = ListContainer,
        ListScroll = ListScroll,
        ItemHeight = itemHeight,
        UpdateSize = updateAll,
        Close = close,
        Toggle = toggle,
        IsOpen = function() return isOpen end,
        GetItemCount = getItemCount,
        ParentSection = parentSection,
        BaseHeight = originalSectionHeight,
    }
end

-- ==================================================================
-- SECTION: BUAT/EDIT PRESET (DROPDOWN DINAMIS)
-- ==================================================================
local CreatePresetSection = createSection(weightScroll, "💾 Buat/Edit Preset")
CreatePresetSection.LayoutOrder = 1
CreatePresetSection.Size = UDim2.new(1, -10, 0, 185)

local PresetNameInput = Instance.new("TextBox")
PresetNameInput.Size = UDim2.new(1, -20, 0, 22)
PresetNameInput.Position = UDim2.new(0, 10, 0, 28)
PresetNameInput.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
PresetNameInput.BorderSizePixel = 0
PresetNameInput.Font = Enum.Font.Gotham
PresetNameInput.PlaceholderText = "Nama preset tim..."
PresetNameInput.Text = ""
PresetNameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
PresetNameInput.TextSize = 9
PresetNameInput.Parent = CreatePresetSection

local UICornerPresetName = Instance.new("UICorner")
UICornerPresetName.CornerRadius = UDim.new(0, 4)
UICornerPresetName.Parent = PresetNameInput

local PetSearchBox = Instance.new("TextBox")
PetSearchBox.Size = UDim2.new(1, -20, 0, 22)
PetSearchBox.Position = UDim2.new(0, 10, 0, 55)
PetSearchBox.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
PetSearchBox.BorderSizePixel = 0
PetSearchBox.Font = Enum.Font.Gotham
PetSearchBox.PlaceholderText = "🔍 Cari pet..."
PetSearchBox.Text = ""
PetSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
PetSearchBox.TextSize = 9
PetSearchBox.Parent = CreatePresetSection

local UICornerPetSearch = Instance.new("UICorner")
UICornerPetSearch.CornerRadius = UDim.new(0, 4)
UICornerPetSearch.Parent = PetSearchBox

local PetListFrame = Instance.new("ScrollingFrame")
PetListFrame.Size = UDim2.new(1, -20, 0, 60)
PetListFrame.Position = UDim2.new(0, 10, 0, 82)
PetListFrame.BackgroundTransparency = 1
PetListFrame.BorderSizePixel = 0
PetListFrame.ScrollBarThickness = 3
PetListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
PetListFrame.CanvasSize = UDim2.new(0, 0, 0, 60)
PetListFrame.Parent = CreatePresetSection

local PetListLayout = Instance.new("UIListLayout")
PetListLayout.Padding = UDim.new(0, 2)
PetListLayout.Parent = PetListFrame

-- Dropdown untuk Edit Preset
local EditPresetDropdown = createDynamicDropdown(
    CreatePresetSection,
    UDim2.new(0, 10, 0, 147),
    "📂 Pilih Preset untuk Diedit/Dihapus",
    CreatePresetSection,
    185,
    weightScroll
)

local CreatePresetButtonSection = createSection(weightScroll)
CreatePresetButtonSection.LayoutOrder = 2
CreatePresetButtonSection.Size = UDim2.new(1, -10, 0, 69)

local SavePresetButton = Instance.new("TextButton")
SavePresetButton.Size = UDim2.new(1, -20, 0, 22)
SavePresetButton.Position = UDim2.new(0, 10, 0, 10)
SavePresetButton.BackgroundColor3 = C.success
SavePresetButton.BorderSizePixel = 0
SavePresetButton.Font = Enum.Font.GothamBold
SavePresetButton.Text = "💾 Simpan Preset"
SavePresetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SavePresetButton.TextSize = 9
SavePresetButton.Parent = CreatePresetButtonSection

local UICornerSave = Instance.new("UICorner")
UICornerSave.CornerRadius = UDim.new(0, 4)
UICornerSave.Parent = SavePresetButton

local DeletePresetButton = Instance.new("TextButton")
DeletePresetButton.Size = UDim2.new(1, -20, 0, 22)
DeletePresetButton.Position = UDim2.new(0, 10, 0, 37)
DeletePresetButton.BackgroundColor3 = C.danger
DeletePresetButton.BorderSizePixel = 0
DeletePresetButton.Font = Enum.Font.GothamBold
DeletePresetButton.Text = "🗑️ Hapus Preset"
DeletePresetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
DeletePresetButton.TextSize = 9
DeletePresetButton.Parent = CreatePresetButtonSection

local UICornerDelete = Instance.new("UICorner")
UICornerDelete.CornerRadius = UDim.new(0, 4)
UICornerDelete.Parent = DeletePresetButton

-- ==================================================================
-- SECTION: PILIH TIM (DROPDOWN DINAMIS)
-- ==================================================================
local TeamSelectSection = createSection(weightScroll, "📈 Auto Leveling")
TeamSelectSection.LayoutOrder = 3
TeamSelectSection.Size = UDim2.new(1, -10, 0, 93)

local LevelInput = Instance.new("TextBox")
LevelInput.Size = UDim2.new(1, -20, 0, 22)
LevelInput.Position = UDim2.new(0, 10, 0, 28)
LevelInput.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
LevelInput.BorderSizePixel = 0
LevelInput.Font = Enum.Font.Gotham
LevelInput.PlaceholderText = "Target Level"
LevelInput.Text = tostring(targetLevel)
LevelInput.TextColor3 = Color3.fromRGB(255, 255, 255)
LevelInput.TextSize = 9
LevelInput.Parent = TeamSelectSection

local UICornerLevelInput = Instance.new("UICorner")
UICornerLevelInput.CornerRadius = UDim.new(0, 4)
UICornerLevelInput.Parent = TeamSelectSection

LevelInput.FocusLost:Connect(function()
    local newLevel = tonumber(LevelInput.Text)
    if newLevel and newLevel > 0 then
        targetLevel = newLevel
        config.targetLevel = newLevel
        saveConfig()
    else
        LevelInput.Text = tostring(targetLevel)
    end
end)

-- Dropdown Tim Leveling
local TeamPresetDropdown = createDynamicDropdown(
    TeamSelectSection,
    UDim2.new(0, 10, 0, 55),
    selectedTeamPreset and string.format("📂 %s", selectedTeamPreset) or "📂 Pilih Preset Tim Leveling",
    TeamSelectSection,
    93,
    weightScroll
)

-- ==================================================================
-- SECTION: PET TARGET
-- ==================================================================
local TargetSection = createSection(weightScroll, "🎯 Pet Target")
TargetSection.LayoutOrder = 4
TargetSection.Size = UDim2.new(1, -10, 0, 172)

local TargetSearchBox = Instance.new("TextBox")
TargetSearchBox.Size = UDim2.new(1, -20, 0, 22)
TargetSearchBox.Position = UDim2.new(0, 10, 0, 28)
TargetSearchBox.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
TargetSearchBox.BorderSizePixel = 0
TargetSearchBox.Font = Enum.Font.Gotham
TargetSearchBox.PlaceholderText = "🔍 Cari pet target..."
TargetSearchBox.Text = ""
TargetSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TargetSearchBox.TextSize = 9
TargetSearchBox.Parent = TargetSection

local UICornerTargetSearch = Instance.new("UICorner")
UICornerTargetSearch.CornerRadius = UDim.new(0, 4)
UICornerTargetSearch.Parent = TargetSearchBox

local TargetListFrame = Instance.new("ScrollingFrame")
TargetListFrame.Size = UDim2.new(1, -20, 0, 80)
TargetListFrame.Position = UDim2.new(0, 10, 0, 55)
TargetListFrame.BackgroundTransparency = 1
TargetListFrame.BorderSizePixel = 0
TargetListFrame.ScrollBarThickness = 3
TargetListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
TargetListFrame.CanvasSize = UDim2.new(0, 0, 0, 80)
TargetListFrame.Parent = TargetSection

local TargetListLayout = Instance.new("UIListLayout")
TargetListLayout.Padding = UDim.new(0, 2)
TargetListLayout.Parent = TargetListFrame

local ScanButton = Instance.new("TextButton")
ScanButton.Size = UDim2.new(1, -20, 0, 22)
ScanButton.Position = UDim2.new(0, 10, 0, 140)
ScanButton.BackgroundColor3 = C.accent
ScanButton.BorderSizePixel = 0
ScanButton.Font = Enum.Font.GothamBold
ScanButton.Text = "🔍 Refresh List"
ScanButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ScanButton.TextSize = 9
ScanButton.Parent = TargetSection

local UICornerScan = Instance.new("UICorner")
UICornerScan.CornerRadius = UDim.new(0, 4)
UICornerScan.Parent = ScanButton

-- ==================================================================
-- SECTION: AUTO WEIGHT (DROPDOWN DINAMIS)
-- ==================================================================
local WeightSection = createSection(weightScroll, "⚖️ Auto Weight")
WeightSection.LayoutOrder = 5
WeightSection.Size = UDim2.new(1, -10, 0, 129)

local WeightToggleButton = Instance.new("TextButton")
WeightToggleButton.Size = UDim2.new(1, -20, 0, 28)
WeightToggleButton.Position = UDim2.new(0, 10, 0, 28)
WeightToggleButton.BackgroundColor3 = isAutoWeight and C.success or Color3.fromRGB(70, 70, 85)
WeightToggleButton.BorderSizePixel = 0
WeightToggleButton.Font = Enum.Font.GothamBold
WeightToggleButton.Text = isAutoWeight and "⚖️ Auto Weight: ON" or "⚖️ Auto Weight: OFF"
WeightToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
WeightToggleButton.TextSize = 10
WeightToggleButton.Parent = WeightSection

local UICornerWeightToggle = Instance.new("UICorner")
UICornerWeightToggle.CornerRadius = UDim.new(0, 5)
UICornerWeightToggle.Parent = WeightToggleButton

local RainbowModeButton = Instance.new("TextButton")
RainbowModeButton.Size = UDim2.new(1, -20, 0, 25)
RainbowModeButton.Position = UDim2.new(0, 10, 0, 61)
RainbowModeButton.BackgroundColor3 = rainbowMode and A.warning or Color3.fromRGB(60, 60, 75)
RainbowModeButton.BorderSizePixel = 0
RainbowModeButton.Font = Enum.Font.Gotham
RainbowModeButton.Text = rainbowMode and "☑ Rainbow Elephant" or "☐ Rainbow Elephant"
RainbowModeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
RainbowModeButton.TextSize = 9
RainbowModeButton.Parent = WeightSection

local UICornerRainbow = Instance.new("UICorner")
UICornerRainbow.CornerRadius = UDim.new(0, 4)
UICornerRainbow.Parent = RainbowModeButton

-- Dropdown Weight Preset
local WeightPresetDropdown = createDynamicDropdown(
    WeightSection,
    UDim2.new(0, 10, 0, 91),
    selectedWeightPreset and string.format("📂 %s", selectedWeightPreset) or "📂 Pilih Preset Auto Weight",
    WeightSection,
    129,
    weightScroll
)

-- Semua GUI yang ingin mengikuti warna rainbow
local rainbowTargets = {
    RainbowModeButton,
}

-- ==================================================================
-- SECTION: AUTO MUTATION (DROPDOWN DINAMIS)
-- ==================================================================
local MutationSection = createSection(weightScroll, "🧬 Auto Mutation")
MutationSection.LayoutOrder = 6
MutationSection.Size = UDim2.new(1, -10, 0, 99)

local MutationToggleButton = Instance.new("TextButton")
MutationToggleButton.Size = UDim2.new(1, -20, 0, 28)
MutationToggleButton.Position = UDim2.new(0, 10, 0, 28)
MutationToggleButton.BackgroundColor3 = isAutoMutation and C.success or Color3.fromRGB(70, 70, 85)
MutationToggleButton.BorderSizePixel = 0
MutationToggleButton.Font = Enum.Font.GothamBold
MutationToggleButton.Text = isAutoMutation and "🧬 Auto Mutation: ON" or "🧬 Auto Mutation: OFF"
MutationToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MutationToggleButton.TextSize = 10
MutationToggleButton.Parent = MutationSection

local UICornerMutationToggle = Instance.new("UICorner")
UICornerMutationToggle.CornerRadius = UDim.new(0, 5)
UICornerMutationToggle.Parent = MutationToggleButton

-- Dropdown Mutation Preset
local MutationPresetDropdown = createDynamicDropdown(
    MutationSection,
    UDim2.new(0, 10, 0, 61),
    selectedMutationPreset and string.format("📂 %s", selectedMutationPreset) or "📂 Pilih Preset Tim Mutation",
    MutationSection,
    99,
    weightScroll
)

local MutationListSection = createSection(weightScroll, "❌ Mutasi yg tidak diinginkan:")
MutationListSection.LayoutOrder = 7
MutationListSection.Size = UDim2.new(1, -10, 0, 185)

local MutationSearchBox = Instance.new("TextBox")
MutationSearchBox.Size = UDim2.new(1, -20, 0, 22)
MutationSearchBox.Position = UDim2.new(0, 10, 0, 28)
MutationSearchBox.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
MutationSearchBox.BorderSizePixel = 0
MutationSearchBox.Font = Enum.Font.Gotham
MutationSearchBox.PlaceholderText = "🔍 Cari mutasi..."
MutationSearchBox.Text = ""
MutationSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
MutationSearchBox.TextSize = 9
MutationSearchBox.Parent = MutationListSection

local UICornerMutationSearch = Instance.new("UICorner")
UICornerMutationSearch.CornerRadius = UDim.new(0, 4)
UICornerMutationSearch.Parent = MutationSearchBox

local MutationListFrame = Instance.new("ScrollingFrame")
MutationListFrame.Size = UDim2.new(1, -20, 0, 120)
MutationListFrame.Position = UDim2.new(0, 10, 0, 55)
MutationListFrame.BackgroundTransparency = 1
MutationListFrame.BorderSizePixel = 0
MutationListFrame.ScrollBarThickness = 3
MutationListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
MutationListFrame.CanvasSize = UDim2.new(0, 0, 0, 120)
MutationListFrame.Parent = MutationListSection

local MutationListLayout = Instance.new("UIListLayout")
MutationListLayout.Padding = UDim.new(0, 2)
MutationListLayout.Parent = MutationListFrame

-- ==================================================================
-- SECTION: ADVANCED (DROPDOWN DINAMIS)
-- ==================================================================
local AdvancedSection = createSection(weightScroll, "🚀 Advanced")
AdvancedSection.LayoutOrder = 8
AdvancedSection.Size = UDim2.new(1, -10, 0, 123)

local AdvancedToggleButton = Instance.new("TextButton")
AdvancedToggleButton.Size = UDim2.new(1, -20, 0, 25)
AdvancedToggleButton.Position = UDim2.new(0, 10, 0, 28)
AdvancedToggleButton.BackgroundColor3 = isAdvancedLeveling and C.success or Color3.fromRGB(70, 70, 85)
AdvancedToggleButton.BorderSizePixel = 0
AdvancedToggleButton.Font = Enum.Font.GothamBold
AdvancedToggleButton.Text = isAdvancedLeveling and "🚀 Advanced: ON" or "🚀 Advanced: OFF"
AdvancedToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
AdvancedToggleButton.TextSize = 9
AdvancedToggleButton.Parent = AdvancedSection

local UICornerAdvancedToggle = Instance.new("UICorner")
UICornerAdvancedToggle.CornerRadius = UDim.new(0, 4)
UICornerAdvancedToggle.Parent = AdvancedToggleButton

local AdvancedLevelInput = Instance.new("TextBox")
AdvancedLevelInput.Size = UDim2.new(1, -20, 0, 22)
AdvancedLevelInput.Position = UDim2.new(0, 10, 0, 58)
AdvancedLevelInput.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
AdvancedLevelInput.BorderSizePixel = 0
AdvancedLevelInput.Font = Enum.Font.Gotham
AdvancedLevelInput.PlaceholderText = "Advanced Target Level"
AdvancedLevelInput.Text = tostring(advancedTargetLevel)
AdvancedLevelInput.TextColor3 = Color3.fromRGB(255, 255, 255)
AdvancedLevelInput.TextSize = 9
AdvancedLevelInput.Parent = AdvancedSection

local UICornerAdvancedLevel = Instance.new("UICorner")
UICornerAdvancedLevel.CornerRadius = UDim.new(0, 4)
UICornerAdvancedLevel.Parent = AdvancedLevelInput

AdvancedLevelInput.FocusLost:Connect(function()
    local newLevel = tonumber(AdvancedLevelInput.Text)
    if newLevel and newLevel > 0 then
        advancedTargetLevel = newLevel
        config.advancedTargetLevel = newLevel
        saveConfig()
    else
        AdvancedLevelInput.Text = tostring(advancedTargetLevel)
    end
end)

-- Dropdown Advanced Preset
local AdvancedPresetDropdown = createDynamicDropdown(
    AdvancedSection,
    UDim2.new(0, 10, 0, 85),
    selectedAdvancedPreset and string.format("📂 %s", selectedAdvancedPreset) or "📂 Pilih Preset Advanced",
    AdvancedSection,
    123,
    weightScroll
)

-- ==================================================================
-- SECTION: KONTROL
-- ==================================================================
local ButtonSection = createSection(weightScroll)
ButtonSection.LayoutOrder = 9
ButtonSection.Size = UDim2.new(1, -10, 0, 69)

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(1, -20, 0, 30)
ToggleButton.Position = UDim2.new(0, 10, 0, 10)
ToggleButton.BackgroundColor3 = C.success
ToggleButton.BorderSizePixel = 0
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Text = "▶️ Mulai"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 10
ToggleButton.Parent = ButtonSection

local UICornerToggle = Instance.new("UICorner")
UICornerToggle.CornerRadius = UDim.new(0, 5)
UICornerToggle.Parent = ToggleButton

StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 14)
StatusLabel.Position = UDim2.new(0, 10, 0, 45)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "Status: Idle"
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.TextSize = 8
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = ButtonSection

-- ==================================================================
-- POPULATE FUNCTIONS
-- ==================================================================
updateStatus = function()
    -- Hitung equipped pets (slot yang terpakai)
    local equippedPets = getEquippedPets()
    local equippedCount = #equippedPets
    
    -- Hitung total pet target yang masih perlu diproses
    local totalPending = 0
    if isAutoWeight then
        totalPending = #getPetsForWeight()
    elseif isAutoMutation then
        totalPending = #getPetsForMutation()
    elseif isAdvancedLeveling then
        totalPending = #getPetsForAdvanced()
    else
        totalPending = #getPetsForNormalLeveling()
    end
    
    -- Mode text
    local modeText = rainbowMode and "🌈" or "📊"
    
    -- Format status baru
    StatusLabel.Text = string.format(
        "%s Slot: %d/%d | Antrian: %d | Weight:%s Advanced:%s Mutation:%s",
        modeText,
        equippedCount,
        MAX_PET_SLOTS,
        totalPending,
        isAutoWeight and "✓" or "x",
        isAdvancedLeveling and "✓" or "x",
        isAutoMutation and "✓" or "x"
    )
end

-- Populate dropdown generic
local function populateDynamicDropdown(dropdown, selectedPreset, onSelect)
    -- Clear
    for _, child in pairs(dropdown.ListScroll:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    local presets = loadTeamPresets()
    local presetNames = {}
    for name in pairs(presets) do
        table.insert(presetNames, name)
    end
    table.sort(presetNames)
    
    for i, presetName in ipairs(presetNames) do
        local preset = presets[presetName]
        
        local validCount = 0
        for _, petInfo in ipairs(preset.pets) do
            if isPetValid(petInfo.UUID) then
                validCount = validCount + 1
            end
        end
        
        local PresetButton = Instance.new("TextButton")
        PresetButton.Size = UDim2.new(1, -4, 0, dropdown.ItemHeight)
        PresetButton.BackgroundColor3 = selectedPreset == presetName and C.success or Color3.fromRGB(65, 65, 80)
        PresetButton.BorderSizePixel = 0
        PresetButton.Font = Enum.Font.Gotham
        PresetButton.Text = string.format("📁 %s (%d/%d)", presetName, validCount, #preset.pets)
        PresetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        PresetButton.TextSize = 8
        PresetButton.TextXAlignment = Enum.TextXAlignment.Left
        PresetButton.LayoutOrder = i
        PresetButton.ZIndex = 12
        PresetButton.Parent = dropdown.ListScroll
        
        local UICornerPreset = Instance.new("UICorner")
        UICornerPreset.CornerRadius = UDim.new(0, 3)
        UICornerPreset.Parent = PresetButton
        
        local Padding = Instance.new("UIPadding")
        Padding.PaddingLeft = UDim.new(0, 6)
        Padding.Parent = PresetButton
        
        PresetButton.MouseButton1Click:Connect(function()
            onSelect(presetName)
            dropdown.Close()
            updateStatus()
        end)
    end
    
    dropdown.UpdateSize()
end

-- Populate team preset dropdown
local function populateTeamPresetDropdown()
    populateDynamicDropdown(TeamPresetDropdown, selectedTeamPreset, function(name)
        selectedTeamPreset = name
        config.selectedTeamPreset = name
        saveConfig()
        TeamPresetDropdown.HeaderButton.Text = string.format("📂 %s", name)
    end)
end

-- Populate weight preset dropdown
local function populateWeightPresetDropdown()
    populateDynamicDropdown(WeightPresetDropdown, selectedWeightPreset, function(name)
        selectedWeightPreset = name
        config.selectedWeightPreset = name
        saveConfig()
        WeightPresetDropdown.HeaderButton.Text = string.format("📂 %s", name)
    end)
end

-- Populate mutation preset dropdown
local function populateMutationPresetDropdown()
    populateDynamicDropdown(MutationPresetDropdown, selectedMutationPreset, function(name)
        selectedMutationPreset = name
        config.selectedMutationPreset = name
        saveConfig()
        MutationPresetDropdown.HeaderButton.Text = string.format("📂 %s", name)
    end)
end

-- Populate advanced preset dropdown
local function populateAdvancedPresetDropdown()
    populateDynamicDropdown(AdvancedPresetDropdown, selectedAdvancedPreset, function(name)
        selectedAdvancedPreset = name
        config.selectedAdvancedPreset = name
        saveConfig()
        AdvancedPresetDropdown.HeaderButton.Text = string.format("📂 %s", name)
    end)
end

-- Populate pet list (untuk preset editor)
local function populatePetList()
    for _, child in pairs(PetListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    local petsData = getPlayerPetData()
    if not petsData then return end
    
    local inventory = petsData.PetInventory.Data or {}
    local allPets = {}
    
    for petUUID, _ in pairs(inventory) do
        local displayName = getPetDisplayName(petUUID)
        local petLevel = getPetLevel(petUUID)
        local isSelected = table.find(tempPresetPets, petUUID) ~= nil
        
        if petSearchText == "" or displayName:lower():find(petSearchText:lower()) then
            table.insert(allPets, {
                UUID = petUUID,
                DisplayName = displayName,
                Level = petLevel,
                IsSelected = isSelected
            })
        end
    end
    
    table.sort(allPets, function(a, b)
        if a.IsSelected ~= b.IsSelected then return a.IsSelected
        else return a.DisplayName < b.DisplayName end
    end)
    
    for i, petInfo in ipairs(allPets) do
        local PetButton = Instance.new("TextButton")
        PetButton.Size = UDim2.new(1, 0, 0, 20)
        PetButton.BackgroundColor3 = petInfo.IsSelected and C.success or Color3.fromRGB(65, 65, 80)
        PetButton.BorderSizePixel = 0
        PetButton.Font = Enum.Font.Gotham
        PetButton.Text = petInfo.IsSelected and string.format("✓ %s (Lv.%d)", petInfo.DisplayName, petInfo.Level) or string.format("%s (Lv.%d)", petInfo.DisplayName, petInfo.Level)
        PetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        PetButton.TextSize = 8
        PetButton.Parent = PetListFrame
        
        local UICornerPet = Instance.new("UICorner")
        UICornerPet.CornerRadius = UDim.new(0, 3)
        UICornerPet.Parent = PetButton
        
        PetButton.MouseButton1Click:Connect(function()
            local index = table.find(tempPresetPets, petInfo.UUID)
            if index then
                table.remove(tempPresetPets, index)
            else
                if #tempPresetPets < MAX_PET_SLOTS then
                    table.insert(tempPresetPets, petInfo.UUID)
                end
            end
            populatePetList()
        end)
    end
    
    local count = 0
    for _, child in pairs(PetListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            count = count + 1
        end
    end
    PetListFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(count * 22, 50))
end

-- Populate edit preset dropdown - DENGAN TOGGLE UN-SELECT
local function populateEditPresetDropdown()
    for _, child in pairs(EditPresetDropdown.ListScroll:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    local presets = loadTeamPresets()
    local presetNames = {}
    for name in pairs(presets) do
        table.insert(presetNames, name)
    end
    table.sort(presetNames)
    
    for i, presetName in ipairs(presetNames) do
        local preset = presets[presetName]
        
        local validCount = 0
        for _, petInfo in ipairs(preset.pets) do
            if isPetValid(petInfo.UUID) then
                validCount = validCount + 1
            end
        end
        
        local PresetButton = Instance.new("TextButton")
        PresetButton.Size = UDim2.new(1, -4, 0, EditPresetDropdown.ItemHeight)
        PresetButton.BackgroundColor3 = editingPresetName == presetName and C.success or Color3.fromRGB(65, 65, 80)
        PresetButton.BorderSizePixel = 0
        PresetButton.Font = Enum.Font.Gotham
        PresetButton.Text = string.format("📁 %s (%d pet)", presetName, validCount)
        PresetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        PresetButton.TextSize = 8
        PresetButton.TextXAlignment = Enum.TextXAlignment.Left
        PresetButton.LayoutOrder = i
        PresetButton.ZIndex = 12
        PresetButton.Parent = EditPresetDropdown.ListScroll
        
        local UICornerPreset = Instance.new("UICorner")
        UICornerPreset.CornerRadius = UDim.new(0, 3)
        UICornerPreset.Parent = PresetButton
        
        local Padding = Instance.new("UIPadding")
        Padding.PaddingLeft = UDim.new(0, 6)
        Padding.Parent = PresetButton
        
        PresetButton.MouseButton1Click:Connect(function()
            -- ⭐ CEK: Jika preset yang sama diklik lagi → UNSELECT
            if editingPresetName == presetName then
                -- Unselect
                editingPresetName = nil
                tempPresetPets = {}
                PresetNameInput.Text = ""
                EditPresetDropdown.HeaderButton.Text = "📂 Pilih Preset untuk Diedit/Dihapus"
                
                -- Refresh pet list (hapus semua centang)
                populatePetList()
                
                -- Update status
                StatusLabel.Text = "✏️ Preset unselected"
                
                -- Update button appearance
                PresetButton.BackgroundColor3 = Color3.fromRGB(65, 65, 80)
                
                -- Auto close dropdown
                EditPresetDropdown.Close()
            else
                -- Select preset
                editingPresetName = presetName
                PresetNameInput.Text = presetName
                
                -- Load pets dari preset
                tempPresetPets = {}
                for _, petInfo in ipairs(preset.pets) do
                    if isPetValid(petInfo.UUID) then
                        table.insert(tempPresetPets, petInfo.UUID)
                    end
                end
                
                -- Refresh pet list dengan pet yang sudah dipilih
                populatePetList()
                
                -- Update header text
                EditPresetDropdown.HeaderButton.Text = string.format("📂 %s", presetName)
                
                -- Update status
                StatusLabel.Text = string.format("✏️ Preset '%s' dimuat (%d pet)", presetName, #tempPresetPets)
                
                -- Update button appearance
                PresetButton.BackgroundColor3 = C.success
                
                -- Auto close dropdown
                EditPresetDropdown.Close()
            end
        end)
    end
    
    EditPresetDropdown.UpdateSize()
end

-- Populate mutation list - DENGAN SELECTED DI ATAS + AUTO CLEAR SEARCH
local function populateMutationList()
    for _, child in pairs(MutationListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- ⭐ Kumpulkan mutations dalam 2 kategori
    local selectedMutations = {}
    local unselectedMutations = {}
    
    for _, mutationName in ipairs(availableMutations) do
        -- Filter berdasarkan search text
        if mutationSearchText == "" or mutationName:lower():find(mutationSearchText:lower()) then
            local isSelected = table.find(unwantedMutations, mutationName) ~= nil
            
            if isSelected then
                table.insert(selectedMutations, mutationName)
            else
                table.insert(unselectedMutations, mutationName)
            end
        end
    end
    
    -- ⭐ Sort masing-masing kategori alphabetically
    table.sort(selectedMutations)
    table.sort(unselectedMutations)
    
    -- ⭐ Gabungkan: selected dulu, lalu unselected
    local allMutations = {}
    for _, name in ipairs(selectedMutations) do
        table.insert(allMutations, {Name = name, IsSelected = true})
    end
    for _, name in ipairs(unselectedMutations) do
        table.insert(allMutations, {Name = name, IsSelected = false})
    end
    
    -- Buat button untuk setiap mutation
    for i, mutationInfo in ipairs(allMutations) do
        local mutationName = mutationInfo.Name
        local isSelected = mutationInfo.IsSelected
        
        local MutationButton = Instance.new("TextButton")
        MutationButton.Size = UDim2.new(1, 0, 0, 20)
        MutationButton.BackgroundColor3 = isSelected and C.danger or Color3.fromRGB(65, 65, 80)
        MutationButton.BorderSizePixel = 0
        MutationButton.Font = Enum.Font.Gotham
        MutationButton.Text = mutationName
        MutationButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        MutationButton.TextSize = 8
        MutationButton.TextXAlignment = Enum.TextXAlignment.Center
        MutationButton.LayoutOrder = i
        MutationButton.Parent = MutationListFrame
        
        local UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = UDim.new(0, 3)
        UICorner.Parent = MutationButton
                
        MutationButton.MouseButton1Click:Connect(function()
            local idx = table.find(unwantedMutations, mutationName)
            if idx then
                table.remove(unwantedMutations, idx)
            else
                table.insert(unwantedMutations, mutationName)
            end
            config.unwantedMutations = unwantedMutations
            saveConfig()
            
            -- ⭐ AUTO CLEAR SEARCH BAR
            mutationSearchText = ""
            MutationSearchBox.Text = ""
            
            -- ⭐ Refresh list (selected akan naik ke atas)
            populateMutationList()
        end)
    end
    
    -- Update canvas
    local count = #allMutations
    MutationListFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(count * 22, 50))
end

-- Scan target pets
local function scanTargetPets()
    local petsData = getPlayerPetData()
    if not petsData then return {} end
    
    local inventory = petsData.PetInventory.Data or {}
    local petTypes = {}
    
    for petUUID, _ in pairs(inventory) do
        local petType = getPetType(petUUID)
        
        if not petTypes[petType] then
            petTypes[petType] = {}
        end
        
        table.insert(petTypes[petType], {
            UUID = petUUID,
            Level = getPetLevel(petUUID),
            Weight = getPetWeight(petUUID),
            MutationStatus = getMutationStatus(petUUID)
        })
    end
    
    return petTypes
end

-- Populate target dropdown (pet target)
local function populateTargetDropdown()
    for _, child in pairs(TargetListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    local petTypes = scanTargetPets()
    local allPetTypes = {}
    
    for petType, petInstances in pairs(petTypes) do
        if targetSearchText == "" or petType:lower():find(targetSearchText:lower()) then
            local isSelected = table.find(selectedPetTypes, petType) ~= nil
            table.insert(allPetTypes, {PetType = petType, Instances = petInstances, Count = #petInstances, IsSelected = isSelected})
        end
    end
    
    table.sort(allPetTypes, function(a, b)
        if a.IsSelected ~= b.IsSelected then return a.IsSelected
        else return a.PetType < b.PetType end
    end)
    
    for i, petInfo in ipairs(allPetTypes) do
        local PetButton = Instance.new("TextButton")
        PetButton.Size = UDim2.new(1, 0, 0, 20)
        PetButton.BackgroundColor3 = petInfo.IsSelected and C.success or Color3.fromRGB(65, 65, 80)
        PetButton.BorderSizePixel = 0
        PetButton.Font = Enum.Font.Gotham
        PetButton.Text = petInfo.IsSelected and string.format("✓ %s (x%d)", petInfo.PetType, petInfo.Count) or string.format("%s (x%d)", petInfo.PetType, petInfo.Count)
        PetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        PetButton.TextSize = 8
        PetButton.Parent = TargetListFrame
        
        local UICornerTarget = Instance.new("UICorner")
        UICornerTarget.CornerRadius = UDim.new(0, 3)
        UICornerTarget.Parent = PetButton
        
        PetButton.MouseButton1Click:Connect(function()
            local typeIndex = table.find(selectedPetTypes, petInfo.PetType)
            
            if typeIndex then
                table.remove(selectedPetTypes, typeIndex)
                for j = #allSelectedPets, 1, -1 do
                    if getPetType(allSelectedPets[j]) == petInfo.PetType then
                        table.remove(allSelectedPets, j)
                    end
                end
            else
                table.insert(selectedPetTypes, petInfo.PetType)
                for _, petInstance in ipairs(petInfo.Instances) do
                    if not table.find(allSelectedPets, petInstance.UUID) then
                        table.insert(allSelectedPets, petInstance.UUID)
                    end
                end
            end
            
            config.selectedPetTypes = selectedPetTypes
            saveConfig()
            
            populateTargetDropdown()
            updateStatus()
        end)
    end
    
    local count = 0
    for _, child in pairs(TargetListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            count = count + 1
        end
    end
    TargetListFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(count * 22, 50))
end

-- Fungsi untuk menerapkan warna ke semua target
local function updateRainbowTargets()
    for _, target in ipairs(rainbowTargets) do
        if target and target:IsA("GuiObject") then
            target.BackgroundColor3 = A.warning
        end
    end
end

-- Memulai rainbow
local function startRainbowUpdate()
    if rainbowTask then return end

    rainbowTask = task.spawn(function()
        while rainbowMode do
            -- Ambil warna berikutnya
            A.warning = rainbowColors[colorIndex]

            -- Terapkan ke semua GUI
            updateRainbowTargets()

            -- Ke warna berikutnya
            colorIndex = colorIndex + 1

            if colorIndex > #rainbowColors then
                colorIndex = 1
            end

            -- Ganti warna setiap 1 detik
            task.wait(1)
        end

        rainbowTask = nil
    end)
end

-- ==================================================================
-- HOOK DROPDOWN TOGGLE UNTUK POPULATE
-- ==================================================================
local teamDropdownOriginalToggle = TeamPresetDropdown.Toggle
local function teamToggleWrapper()
    if not TeamPresetDropdown.IsOpen() then
        populateTeamPresetDropdown()
    end
end
TeamPresetDropdown.HeaderButton.MouseButton1Click:Connect(teamToggleWrapper)

local weightDropdownOriginalToggle = WeightPresetDropdown.Toggle
WeightPresetDropdown.HeaderButton.MouseButton1Click:Connect(function()
    if not WeightPresetDropdown.IsOpen() then
        populateWeightPresetDropdown()
    end
end)

local mutationDropdownToggle = MutationPresetDropdown.Toggle
MutationPresetDropdown.HeaderButton.MouseButton1Click:Connect(function()
    if not MutationPresetDropdown.IsOpen() then
        populateMutationPresetDropdown()
    end
end)

local advancedDropdownToggle = AdvancedPresetDropdown.Toggle
AdvancedPresetDropdown.HeaderButton.MouseButton1Click:Connect(function()
    if not AdvancedPresetDropdown.IsOpen() then
        populateAdvancedPresetDropdown()
    end
end)

local editDropdownToggle = EditPresetDropdown.Toggle
EditPresetDropdown.HeaderButton.MouseButton1Click:Connect(function()
    if not EditPresetDropdown.IsOpen() then
        populateEditPresetDropdown()
    end
end)

-- ==================================================================
-- EVENT HANDLERS
-- ==================================================================
SavePresetButton.MouseButton1Click:Connect(function()
    local presetName = PresetNameInput.Text
    
    if presetName == "" then 
        StatusLabel.Text = "⚠️ Masukkan nama preset!" 
        return 
    end
    
    if #tempPresetPets == 0 then 
        StatusLabel.Text = "⚠️ Pilih minimal 1 pet!" 
        return 
    end
    
    if editingPresetName and editingPresetName ~= presetName then
        deletePreset(editingPresetName)
    end
    
    saveTeamPreset(presetName, tempPresetPets)
    
    if editingPresetName then
        StatusLabel.Text = string.format("✅ Preset '%s' diupdate!", presetName)
    else
        StatusLabel.Text = string.format("✅ Preset '%s' disimpan!", presetName)
    end
    
    editingPresetName = nil
    PresetNameInput.Text = ""
    tempPresetPets = {}
    EditPresetDropdown.HeaderButton.Text = "📂 Pilih Preset untuk Diedit/Dihapus"
    
    -- ⭐ Refresh pet list (hapus centang)
    populatePetList()
    
    -- ⭐ Refresh dropdown list agar preset baru muncul
    populateEditPresetDropdown()
end)

DeletePresetButton.MouseButton1Click:Connect(function()
    if not editingPresetName then
        StatusLabel.Text = "⚠️ Pilih preset dulu!"
        return
    end
    
    deletePreset(editingPresetName)
    StatusLabel.Text = string.format("🗑️ Preset '%s' dihapus!", editingPresetName)
    
    -- ⭐ Reset editor
    editingPresetName = nil
    tempPresetPets = {}
    PresetNameInput.Text = ""
    EditPresetDropdown.HeaderButton.Text = "📂 Pilih Preset untuk Diedit/Dihapus"
    
    -- ⭐ Refresh pet list (hapus semua centang)
    populatePetList()
end)

WeightToggleButton.MouseButton1Click:Connect(function()
    isAutoWeight = not isAutoWeight
    config.isAutoWeight = isAutoWeight
    saveConfig()
    
    if isAutoWeight then
        WeightToggleButton.Text = "⚖️ Auto Weight: ON"
        WeightToggleButton.BackgroundColor3 = C.success
    else
        WeightToggleButton.Text = "⚖️ Auto Weight: OFF"
        WeightToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
    end
    updateStatus()
end)

AdvancedToggleButton.MouseButton1Click:Connect(function()
    isAdvancedLeveling = not isAdvancedLeveling
    config.isAdvancedLeveling = isAdvancedLeveling
    saveConfig()
    
    if isAdvancedLeveling then
        AdvancedToggleButton.Text = "🚀 Advanced: ON"
        AdvancedToggleButton.BackgroundColor3 = C.success
    else
        AdvancedToggleButton.Text = "🚀 Advanced: OFF"
        AdvancedToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
    end
    updateStatus()
end)

MutationToggleButton.MouseButton1Click:Connect(function()
    isAutoMutation = not isAutoMutation
    config.isAutoMutation = isAutoMutation
    saveConfig()
    
    if isAutoMutation then
        MutationToggleButton.Text = "🧬 Auto Mutation: ON"
        MutationToggleButton.BackgroundColor3 = C.success
    else
        MutationToggleButton.Text = "🧬 Auto Mutation: OFF"
        MutationToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
    end
    updateStatus()
end)

-- Tombol Rainbow Mode
RainbowModeButton.MouseButton1Click:Connect(function()
    rainbowMode = not rainbowMode
    config.rainbowMode = rainbowMode
    saveConfig()

    if rainbowMode then
        RainbowModeButton.Text = "☑ Rainbow Elephant"

        -- Terapkan warna sekarang
        A.warning = rainbowColors[colorIndex]
        updateRainbowTargets()

        -- Mulai loop
        startRainbowUpdate()
    else
        RainbowModeButton.Text = "☐ Rainbow Elephant"

        -- Kembalikan warna semua target
        for _, target in ipairs(rainbowTargets) do
            if target and target:IsA("GuiObject") then
                target.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
            end
        end
    end

    updateStatus()
end)

-- Jika Rainbow Mode sudah aktif dari config saat script dijalankan
if rainbowMode then
    A.warning = rainbowColors[colorIndex]
    updateRainbowTargets()
    startRainbowUpdate()
end

PetSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    petSearchText = PetSearchBox.Text
    populatePetList()
end)

TargetSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    targetSearchText = TargetSearchBox.Text
    populateTargetDropdown()
end)

MutationSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    mutationSearchText = MutationSearchBox.Text
    populateMutationList()
end)

ScanButton.MouseButton1Click:Connect(function()
    StatusLabel.Text = "Refreshing..."
    wait(0.1)
    populateTargetDropdown()
    updateStatus()
end)

-- ==================================================================
-- MAIN LOGIC - AUTO LEVELING
-- ==================================================================
ToggleButton.MouseButton1Click:Connect(function()
    if isLeveling then
        isLeveling = false
        ToggleButton.Text = "▶️ Mulai"
        ToggleButton.BackgroundColor3 = C.success
        updateStatus()
        return
    end
    
    if not selectedTeamPreset then
        StatusLabel.Text = "⚠️ Pilih preset tim leveling!"
        return
    end
    
    if #allSelectedPets == 0 then
        StatusLabel.Text = "⚠️ Pilih pet target dulu!"
        return
    end
    
    if isAutoWeight and not selectedWeightPreset then
        StatusLabel.Text = "⚠️ Pilih preset auto weight!"
        return
    end
    
    if isAdvancedLeveling and not selectedAdvancedPreset then
        StatusLabel.Text = "⚠️ Pilih preset advanced!"
        return
    end
    
    if isAutoMutation and not selectedMutationPreset then
        StatusLabel.Text = "⚠️ Pilih preset mutation!"
        return
    end
    
    if isAutoMutation and #unwantedMutations == 0 then
        StatusLabel.Text = "⚠️ Pilih minimal 1 mutasi tidak diinginkan!"
        return
    end
    
    isLeveling = true
    ToggleButton.Text = "⏹️ Stop"
    ToggleButton.BackgroundColor3 = C.danger
    
    local function unequipAllPets()
        StatusLabel.Text = "🔄 Membersihkan semua slot..."
        local maxAttempts = 3
        local attempt = 0
    
        while attempt < maxAttempts and isAlive() do  -- ⭐ GANTI isLeveling → isAlive()
            local equippedPets = getEquippedPets()
        
            if #equippedPets == 0 then
                return true
            end
        
            for _, petUUID in ipairs(equippedPets) do
                -- ⭐ Cek sebelum unequip
                if not isAlive() then return false end
            
                pcall(function()
                    unequipPet(petUUID)
                end)
                wait(0.5)
            
                -- ⭐ Cek setelah unequip
                if not isAlive() then return false end
            end
        
            attempt = attempt + 1
            wait(2)
        end
    
        return #getEquippedPets() == 0
    end
    
    local function equipPetList(petList, label)
        for _, petUUID in ipairs(petList) do
            -- ⭐ Cek di setiap iterasi
            if not isAlive() then return end
        
            if isPetValid(petUUID) then
                equipPet(petUUID)
            end
            wait(0.3)
        end
    end
    
    spawn(function()
        unequipAllPets()
        wait(2)
    
        -- ⭐ Cek setelah wait
        if not isAlive() then return end
    
        cleanupInvalidPets()
        
        -- PRIORITAS 1: AUTO WEIGHT
        if isAutoWeight then
            local weightLoopActive = true
    
            while isAlive() and weightLoopActive do  -- ⭐ GANTI
                -- ⭐ Cek di awal loop
                if not isAlive() then return end
        
                cleanupInvalidPets()
                
                -- ⭐ Cek alive
                if not isAlive() then return end

                if #allSelectedPets == 0 then
                    StatusLabel.Text = "⚠️ Semua pet target hilang!"
                    break
                end
                
                local weightTarget = getWeightTarget()
                local levelTargetForWeight = getLevelTargetForWeight()
                
                local weightPets = getPetsForWeight()
                
                if #weightPets == 0 then
                    StatusLabel.Text = "✅ Semua base weight tercapai!"
                    isAutoWeight = false
                    config.isAutoWeight = false
                    saveConfig()
                    WeightToggleButton.Text = "⚖️ Auto Weight: OFF"
                    WeightToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
                    weightLoopActive = false
                    break
                end
                
                StatusLabel.Text = string.format("⚖️ %d pet butuh weight", #weightPets)
                
                local levelTargets = {}
                for _, petUUID in ipairs(weightPets) do
                    if getPetLevel(petUUID) < levelTargetForWeight then
                        table.insert(levelTargets, petUUID)
                    end
                end
                
                if #levelTargets > 0 then
                    unequipAllPets()
    
                    -- ⭐ Cek setelah unequip
                    if not isAlive() then return end
    
                    wait(1)
    
                    local teamUUIDs = getPresetUUIDs(selectedTeamPreset)
                    equipPetList(teamUUIDs, "Tim:")
                    wait(2)
                    
                    local availableSlots = MAX_PET_SLOTS - #teamUUIDs
                    local toEquip = math.min(availableSlots, #levelTargets)
                    
                    local levelingEquippedPets = {}
                    local pendingLevelTargets = {}
                    
                    for _, petUUID in ipairs(levelTargets) do
                        table.insert(pendingLevelTargets, petUUID)
                    end
                    
                    for i = 1, toEquip do
                        if #pendingLevelTargets > 0 then
                            local petUUID = pendingLevelTargets[1]
                            table.remove(pendingLevelTargets, 1)
                            if isPetValid(petUUID) then
                                equipPet(petUUID)
                                table.insert(levelingEquippedPets, petUUID)
                            end
                            wait(0.5)
                        end
                    end
                    
                    while isAlive() and #levelingEquippedPets > 0 do  -- ⭐ GANTI
                        for i = #levelingEquippedPets, 1, -1 do
                            -- ⭐ Cek di setiap iterasi for
                            if not isAlive() then return end
        
                            local petUUID = levelingEquippedPets[i]
                            
                            if not isPetValid(petUUID) then
                                table.remove(levelingEquippedPets, i)
                                continue
                            end
                            
                            if getPetLevel(petUUID) >= levelTargetForWeight then
                                pcall(function() unequipPet(petUUID) end)
                                table.remove(levelingEquippedPets, i)
                                
                                if #pendingLevelTargets > 0 then
                                    local nextPet = pendingLevelTargets[1]
                                    table.remove(pendingLevelTargets, 1)
                                    if isPetValid(nextPet) and getPetLevel(nextPet) < levelTargetForWeight then
                                        equipPet(nextPet)
                                        table.insert(levelingEquippedPets, nextPet)
                                        wait(0.5)
                                    end
                                end
                            end
                        end
                        
                        local allLeveled = true
                        for _, petUUID in ipairs(levelTargets) do
                            if isPetValid(petUUID) and getPetLevel(petUUID) < levelTargetForWeight then
                                allLeveled = false
                                break
                            end
                        end
                        
                        if allLeveled then break end
                        if #levelingEquippedPets == 0 and #pendingLevelTargets == 0 then break end
                        
                            -- ⭐ Cek sebelum update status
                        if not isAlive() then return end
    
                        updateStatus()
                        wait(5)
                    end
                end
                
                -- Proses Weight
                unequipAllPets()
                wait(1)
                
                local weightUUIDs = getPresetUUIDs(selectedWeightPreset)
                equipPetList(weightUUIDs, "Weight:")
                wait(2)
                
                local readyForWeight = {}
                for _, petUUID in ipairs(weightPets) do
                    if isPetValid(petUUID) and getPetLevel(petUUID) >= levelTargetForWeight then
                        table.insert(readyForWeight, petUUID)
                    end
                end
                
                if #readyForWeight > 0 then
                    local availableSlots = MAX_PET_SLOTS - #weightUUIDs
                    local toEquip = math.min(availableSlots, #readyForWeight)
                    
                    local weightEquippedPets = {}
                    local pendingWeightPets = {}
                    
                    for _, petUUID in ipairs(readyForWeight) do
                        table.insert(pendingWeightPets, petUUID)
                    end
                    
                    for i = 1, toEquip do
                        if #pendingWeightPets > 0 then
                            local petUUID = pendingWeightPets[1]
                            table.remove(pendingWeightPets, 1)
                            if isPetValid(petUUID) then
                                equipPet(petUUID)
                                table.insert(weightEquippedPets, petUUID)
                            end
                            wait(0.5)
                        end
                    end
                    
                    while isAlive() and #weightEquippedPets > 0 do  -- ⭐ GANTI
                        for i = #weightEquippedPets, 1, -1 do
                            -- ⭐ Cek
                            if not isAlive() then return end
                            local petUUID = weightEquippedPets[i]
                            
                            if not isPetValid(petUUID) then
                                table.remove(weightEquippedPets, i)
                                continue
                            end
                            
                            if getPetWeight(petUUID) >= weightTarget then
                                pcall(function() unequipPet(petUUID) end)
                                table.remove(weightEquippedPets, i)
                                
                                if #pendingWeightPets > 0 then
                                    local nextPet = pendingWeightPets[1]
                                    table.remove(pendingWeightPets, 1)
                                    if isPetValid(nextPet) and getPetLevel(nextPet) >= levelTargetForWeight then
                                        equipPet(nextPet)
                                        table.insert(weightEquippedPets, nextPet)
                                        wait(0.5)
                                    end
                                end
                            elseif getPetLevel(petUUID) < levelTargetForWeight then
                                pcall(function() unequipPet(petUUID) end)
                                table.remove(weightEquippedPets, i)
                                
                                if #pendingWeightPets > 0 then
                                    local nextPet = pendingWeightPets[1]
                                    table.remove(pendingWeightPets, 1)
                                    if isPetValid(nextPet) and getPetLevel(nextPet) >= levelTargetForWeight then
                                        equipPet(nextPet)
                                        table.insert(weightEquippedPets, nextPet)
                                        wait(0.5)
                                    end
                                end
                            end
                        end
                        
                        local allWeightDone = true
                        for _, petUUID in ipairs(weightPets) do
                            if isPetValid(petUUID) and getPetWeight(petUUID) < weightTarget then
                                allWeightDone = false
                                break
                            end
                        end
                        
                        if allWeightDone then
                            StatusLabel.Text = "✅ Semua base weight tercapai!"
                            isAutoWeight = false
                            config.isAutoWeight = false
                            saveConfig()
                            WeightToggleButton.Text = "⚖️ Auto Weight: OFF"
                            WeightToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
                            weightLoopActive = false
                            break
                        end
                        
                        if #weightEquippedPets == 0 and #pendingWeightPets == 0 then
                            break
                        end
                        
                        updateStatus()
                        wait(5)
                    end
                end
                
                wait(3)
            end
        end

        -- ⭐ Cek sebelum lanjut ke PRIORITAS 2
        if not isAlive() then return end

        -- PRIORITAS 2: AUTO MUTATION
        if isAutoMutation and isAlive() then  -- ⭐ GANTI
            local mutationLoopActive = true

            while isAlive() and mutationLoopActive do  -- ⭐ GANTI
                -- ⭐ Cek
                if not isAlive() then return end
    
                cleanupInvalidPets()
                
                if #allSelectedPets == 0 then
                    StatusLabel.Text = "⚠️ Semua pet target hilang!"
                    break
                end
                
                local mutationPets = getPetsForMutation()
                
                if #mutationPets == 0 then
                    StatusLabel.Text = "🎉 Semua pet target sudah bermutasi diinginkan!"
                    isAutoMutation = false
                    config.isAutoMutation = false
                    saveConfig()
                    MutationToggleButton.Text = "🧬 Auto Mutation: OFF"
                    MutationToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
                    mutationLoopActive = false
                    break
                end
                
                StatusLabel.Text = string.format("🧬 %d pet perlu mutasi", #mutationPets)
                
                unequipAllPets()
                wait(2)
                
                local mutationTeamUUIDs = getPresetUUIDs(selectedMutationPreset)
                equipPetList(mutationTeamUUIDs, "Mutation Team:")
                wait(3)
                
                local availableSlots = MAX_PET_SLOTS - #mutationTeamUUIDs
                local toEquip = math.min(availableSlots, #mutationPets)
                
                local equippedForMutation = {}
                local pendingMutationList = {}
                
                for _, petUUID in ipairs(mutationPets) do
                    table.insert(pendingMutationList, petUUID)
                end
                
                for i = 1, toEquip do
                    if #pendingMutationList > 0 then
                        local petUUID = pendingMutationList[1]
                        table.remove(pendingMutationList, 1)
                        if isPetValid(petUUID) then
                            equipPet(petUUID)
                            table.insert(equippedForMutation, petUUID)
                        end
                        wait(1)
                    end
                end
                
                wait(2)
                
                while isAlive() and #equippedForMutation > 0 do  -- ⭐ GANTI
                    for i = #equippedForMutation, 1, -1 do
                        -- ⭐ Cek
                        if not isAlive() then return end
                        local petUUID = equippedForMutation[i]
                        
                        if not isPetValid(petUUID) then
                            table.remove(equippedForMutation, i)
                            if #pendingMutationList > 0 then
                                local nextPet = pendingMutationList[1]
                                table.remove(pendingMutationList, 1)
                                if isPetValid(nextPet) then
                                    equipPet(nextPet)
                                    table.insert(equippedForMutation, nextPet)
                                end
                            end
                            continue
                        end
                        
                        local petType = getPetType(petUUID)
                        local status, mutationName = getMutationStatus(petUUID)
                        
                        if status == "desired" then
                            StatusLabel.Text = string.format("✅ %s dapat %s!", petType, mutationName)
                            pcall(function() unequipPet(petUUID) end)
                            table.remove(equippedForMutation, i)
                            wait(1)
                            
                            if #pendingMutationList > 0 then
                                local nextPet = pendingMutationList[1]
                                table.remove(pendingMutationList, 1)
                                if isPetValid(nextPet) then
                                    equipPet(nextPet)
                                    table.insert(equippedForMutation, nextPet)
                                end
                                wait(1)
                            end
                        elseif status == "unwanted" then
                            StatusLabel.Text = string.format("⚠️ %s dapat %s, cleansing...", petType, mutationName)
                            
                            local success, errMsg = false, nil
                            local ok, err = pcall(function()
                                success, errMsg = useCleansingShard(petUUID)
                            end)
                            
                            if not ok or not success then
                                StatusLabel.Text = string.format("⚠️ Gagal cleansing %s", petType)
                            else
                                StatusLabel.Text = string.format("✅ %s di-cleansing!", petType)
                            end
                            
                            wait(3)
                        end
                    end
                    
                    if #equippedForMutation == 0 and #pendingMutationList == 0 then
                        break
                    end
                    
                    updateStatus()
                    wait(5)
                end
                
                wait(3)
            end
        end

        -- ⭐ Cek sebelum lanjut ke PRIORITAS 3
        if not isAlive() then return end

        -- PRIORITAS 3: NORMAL LEVELING
        if isAlive() then  -- ⭐ GANTI
            cleanupInvalidPets()
            
            local normalPets = getPetsForNormalLeveling()
            
            if #normalPets > 0 then
                StatusLabel.Text = string.format("📈 Leveling normal (%d pet)...", #normalPets)
                
                unequipAllPets()
                wait(1)
                
                local teamUUIDs = getPresetUUIDs(selectedTeamPreset)
                equipPetList(teamUUIDs, "Tim:")
                wait(2)
                
                local availableSlots = MAX_PET_SLOTS - #teamUUIDs
                local toEquip = math.min(availableSlots, #normalPets)
                
                local normalEquippedPets = {}
                local pendingNormalList = {}
                
                for _, petUUID in ipairs(normalPets) do
                    table.insert(pendingNormalList, petUUID)
                end
                
                for i = 1, toEquip do
                    if #pendingNormalList > 0 then
                        local petUUID = pendingNormalList[1]
                        table.remove(pendingNormalList, 1)
                        if isPetValid(petUUID) then
                            equipPet(petUUID)
                            table.insert(normalEquippedPets, petUUID)
                        end
                        wait(0.5)
                    end
                end
                
                while isAlive() and #normalEquippedPets > 0 do  -- ⭐ GANTI
                    for i = #normalEquippedPets, 1, -1 do
                        -- ⭐ Cek
                        if not isAlive() then return end
                        local petUUID = normalEquippedPets[i]
                        
                        if not isPetValid(petUUID) then
                            table.remove(normalEquippedPets, i)
                            continue
                        end
                        
                        if getPetLevel(petUUID) >= targetLevel then
                            pcall(function() unequipPet(petUUID) end)
                            table.remove(normalEquippedPets, i)
                            
                            if #pendingNormalList > 0 then
                                local nextPet = pendingNormalList[1]
                                table.remove(pendingNormalList, 1)
                                if isPetValid(nextPet) and getPetLevel(nextPet) < targetLevel then
                                    equipPet(nextPet)
                                    table.insert(normalEquippedPets, nextPet)
                                    wait(0.5)
                                end
                            end
                        end
                    end
                    
                    local allNormalDone = true
                    for _, petUUID in ipairs(normalPets) do
                        if isPetValid(petUUID) and getPetLevel(petUUID) < targetLevel then
                            allNormalDone = false
                            break
                        end
                    end
                    
                    if allNormalDone then break end
                    if #normalEquippedPets == 0 and #pendingNormalList == 0 then break end
                    
                    updateStatus()
                    wait(3)
                end
            end
        end
        -- ⭐ Cek sebelum lanjut ke PRIORITAS 4
        if not isAlive() then return end

        -- PRIORITAS 4: ADVANCED LEVELING
        if isAdvancedLeveling and isAlive() then  -- ⭐ GANTI
            cleanupInvalidPets()
            
            local advancedPets = getPetsForAdvanced()
            
            if #advancedPets > 0 then
                StatusLabel.Text = string.format("🚀 Advanced leveling (%d pet)...", #advancedPets)
                
                unequipAllPets()
                if not isAlive() then return end

                wait(1)
                
                local advancedUUIDs = getPresetUUIDs(selectedAdvancedPreset)
                equipPetList(advancedUUIDs, "Advanced:")
                wait(3)
                
                local availableSlots = MAX_PET_SLOTS - #advancedUUIDs
                local toEquip = math.min(availableSlots, #advancedPets)
                
                local advancedEquippedPets = {}
                local pendingAdvancedList = {}
                
                for _, petUUID in ipairs(advancedPets) do
                    table.insert(pendingAdvancedList, petUUID)
                end
                
                for i = 1, toEquip do
                    if #pendingAdvancedList > 0 then
                        local petUUID = pendingAdvancedList[1]
                        table.remove(pendingAdvancedList, 1)
                        if isPetValid(petUUID) then
                            equipPet(petUUID)
                            table.insert(advancedEquippedPets, petUUID)
                        end
                        wait(0.5)
                    end
                end
                
                while isAlive() and #advancedEquippedPets > 0 do  -- ⭐ GANTI
                    for i = #advancedEquippedPets, 1, -1 do
                        -- ⭐ Cek
                        if not isAlive() then return end
                        local petUUID = advancedEquippedPets[i]
                        
                        if not isPetValid(petUUID) then
                            table.remove(advancedEquippedPets, i)
                            continue
                        end
                        
                        if getPetLevel(petUUID) >= advancedTargetLevel then
                            pcall(function() unequipPet(petUUID) end)
                            table.remove(advancedEquippedPets, i)
                            
                            if #pendingAdvancedList > 0 then
                                local nextPet = pendingAdvancedList[1]
                                table.remove(pendingAdvancedList, 1)
                                if isPetValid(nextPet) and getPetLevel(nextPet) < advancedTargetLevel then
                                    equipPet(nextPet)
                                    table.insert(advancedEquippedPets, nextPet)
                                    wait(0.5)
                                end
                            end
                        end
                    end
                    
                    local allAdvancedDone = true
                    for _, petUUID in ipairs(advancedPets) do
                        if isPetValid(petUUID) and getPetLevel(petUUID) < advancedTargetLevel then
                            allAdvancedDone = false
                            break
                        end
                    end
                    
                    if allAdvancedDone then break end
                    
                    if #advancedEquippedPets == 0 and #pendingAdvancedList == 0 then
                        local stillNeed = {}
                        for _, petUUID in ipairs(advancedPets) do
                            if isPetValid(petUUID) and getPetLevel(petUUID) < advancedTargetLevel then
                                table.insert(stillNeed, petUUID)
                            end
                        end
                        
                        if #stillNeed > 0 then
                            for _, petUUID in ipairs(stillNeed) do
                                table.insert(pendingAdvancedList, petUUID)
                            end
                            
                            local reEquip = math.min(availableSlots, #pendingAdvancedList)
                            for i = 1, reEquip do
                                if #pendingAdvancedList > 0 then
                                    local petUUID = pendingAdvancedList[1]
                                    table.remove(pendingAdvancedList, 1)
                                    if isPetValid(petUUID) then
                                        equipPet(petUUID)
                                        table.insert(advancedEquippedPets, petUUID)
                                    end
                                    wait(0.5)
                                end
                            end
                        else
                            break
                        end
                    end

                    if not isAlive() then return end
                            
                    updateStatus()
                    wait(5)
                end
            end
        end
        
        -- ⭐ Cek sebelum selesai (hanya jika GUI destroyed)
        if isGuiDestroyed then return end

        -- SELESAI
        StatusLabel.Text = "🎉 Semua proses selesai!"
        isLeveling = false
        ToggleButton.Text = "▶️ Mulai"
        ToggleButton.BackgroundColor3 = C.success
        updateStatus()
    end)
end)

-- ==================================================================
-- TAB SWITCHING
-- ==================================================================
local function switchTab(tabName)
    defaultView.Visible = false
    for _, f in pairs(tabFrames) do
        f.Visible = false
    end
    for _, btn in pairs(tabBtns) do
        btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
        btn.TextColor3 = C.textDim
    end
    
    if tabFrames[tabName] then
        tabFrames[tabName].Visible = true
        tabBtns[tabName].BackgroundColor3 = C.accent
        tabBtns[tabName].TextColor3 = C.text
        activeTab = tabName
    end
end

for _, tab in ipairs(tabs) do
    tabBtns[tab.name].MouseButton1Click:Connect(function()
        switchTab(tab.name)
    end)
end

-- ==================================================================
-- INITIAL SETUP
-- ==================================================================
local function loadAvailableMutations()
    local mutations = {}
    local registry = safeRequire(ReplicatedStorage.Data.PetRegistry.PetMutationRegistry)
    
    if registry and registry.PetMutationRegistry then
        for mutationName, _ in pairs(registry.PetMutationRegistry) do
            if mutationName ~= "Normal" and mutationName ~= "Rideable" then
                table.insert(mutations, mutationName)
            end
        end
    end
    
    table.sort(mutations)
    return mutations
end

availableMutations = loadAvailableMutations()

-- Populate UI
populatePetList()
populateMutationList()
populateTargetDropdown()
updateStatus()

-- Auto-load selected pet types dari config
if config.selectedPetTypes and #config.selectedPetTypes > 0 then
    for _, petType in ipairs(config.selectedPetTypes) do
        local petsData = getPlayerPetData()
        if petsData then
            local inventory = petsData.PetInventory.Data or {}
            for petUUID, _ in pairs(inventory) do
                if getPetType(petUUID) == petType then
                    if not table.find(allSelectedPets, petUUID) then
                        table.insert(allSelectedPets, petUUID)
                    end
                end
            end
        end
    end
end

-- Switch ke Weight tab default
switchTab("Weight")

print("✅ AoneHub Auto Leveling loaded! Config:", SAVE_FILE)

-- Setup Extra Tab dengan Scroll
local extraTab = tabFrames["Ekstra"]

local extraScroll = Instance.new("ScrollingFrame")
extraScroll.Size = UDim2.new(1, -10, 1, -10)
extraScroll.Position = UDim2.new(0, 5, 0, 5)
extraScroll.BackgroundTransparency = 1
extraScroll.BorderSizePixel = 0
extraScroll.ScrollBarThickness = 4
extraScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
extraScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
extraScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y  -- Auto size
extraScroll.Parent = extraTab

local extraLayout = Instance.new("UIListLayout")
extraLayout.Padding = UDim.new(0, 6)
extraLayout.SortOrder = Enum.SortOrder.LayoutOrder
extraLayout.Parent = extraScroll

-- ==================================================================
-- TOGGLE CREATOR (untuk Extra Tab)
-- ==================================================================
local function createToggle(title, description, configKey, layoutOrder, defaultColor)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -12, 0, 44)
    container.LayoutOrder = layoutOrder
    container.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    container.BorderSizePixel = 0
    container.Parent = extraScroll
    
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)
    
    -- Title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -50, 0, 16)
    titleLabel.Position = UDim2.new(0, 10, 0, 4)
    titleLabel.Text = title
    titleLabel.TextColor3 = C.text
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextSize = 10
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.BackgroundTransparency = 1
    titleLabel.Parent = container
    
    -- Description
    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -50, 0, 14)
    descLabel.Position = UDim2.new(0, 10, 0, 20)
    descLabel.Text = description
    descLabel.TextColor3 = C.textDim
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 8
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.BackgroundTransparency = 1
    descLabel.Parent = container
    
    -- Toggle Button
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 36, 0, 18)
    toggleBtn.Position = UDim2.new(1, -42, 0.5, -9)
    toggleBtn.Text = ""
    toggleBtn.BorderSizePixel = 0
    toggleBtn.AutoButtonColor = false
    toggleBtn.Parent = container
    
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)
    
    -- Toggle dot
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 12, 0, 12)
    dot.Position = UDim2.new(0, 3, 0.5, -6)
    dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    dot.BorderSizePixel = 0
    dot.Parent = toggleBtn
    
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    
    -- Status label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0, 34, 1, 0)
    statusLabel.Position = UDim2.new(1, -82, 0, 0)
    statusLabel.Text = config[configKey] and "ON" or "OFF"
    statusLabel.TextColor3 = config[configKey] and C.success or C.danger
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 7
    statusLabel.TextXAlignment = Enum.TextXAlignment.Right
    statusLabel.BackgroundTransparency = 1
    statusLabel.Parent = container
    
    -- Update function
    local function updateToggle()
        local isOn = config[configKey]
        
        if isOn then
            toggleBtn.BackgroundColor3 = C.success
            dot.Position = UDim2.new(1, -15, 0.5, -6)
            statusLabel.Text = "ON"
            statusLabel.TextColor3 = C.success
        else
            toggleBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 75)
            dot.Position = UDim2.new(0, 3, 0.5, -6)
            statusLabel.Text = "OFF"
            statusLabel.TextColor3 = C.danger
        end
    end
    
    toggleBtn.MouseButton1Click:Connect(function()
        config[configKey] = not config[configKey]
        saveConfig()
        updateToggle()
        
        if configKey == "antiAfkToggle" then
            if config[configKey] then
                print("[AoneHub] ⏳ Anti-AFK: Delay 15 menit sebelum aktif...")
            else
                print("[AoneHub] ❌ Anti-AFK: OFF")
            end
        end
    end)
    
    updateToggle()
    return container
end

-- ⭐ TAMBAHKAN TOGGLE ANTI-AFK DI SINI
createToggle("🛡️ Anti-AFK", "Tapi bikin bug gk bisa ganti item di hotbar", "antiAfkToggle", 2)

-- ==================================================================
-- ANTI-AFK SYSTEM
-- ==================================================================
do
    local antiAFKEnabled = config.antiAfkToggle
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local antiAFKActive = false
    local antiAFKDelayActive = false
    local antiAFKFirstRun = true
    
    -- Fungsi untuk menjalankan simulasi Anti-AFK
    local function PerformAntiAFKAction()
        -- Simulasi mouse movement
        pcall(function()
            VirtualInputManager:SendMouseMoveEvent(
                math.random(100, 500), 
                math.random(100, 500), 
                nil
            )
        end)
        
        -- Simulasi key press
        pcall(function()
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, nil)
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, nil)
        end)
        
        -- Gerakin karakter dikit
        pcall(function()
            local char = player.Character
            if char and char:FindFirstChild("Humanoid") then
                char.Humanoid:Move(Vector3.new(math.random(-5, 5), 0, math.random(-5, 5)))
            end
        end)
    end
    
    -- Fungsi untuk menjalankan Anti-AFK (dengan delay awal)
    local function StartAntiAFK()
        if antiAFKActive or antiAFKDelayActive then return end
        
        local initialDelay
        
        if antiAFKFirstRun then
            initialDelay = 600  -- 10 menit (auto-start awal)
            antiAFKFirstRun = false
            print("[AoneHub] ⏳ Anti-AFK: Delay 10 menit (auto-start awal)")
        else
            initialDelay = 900  -- 15 menit (manual)
            print("[AoneHub] ⏳ Anti-AFK: Delay 15 menit (di-on-kan manual)")
        end
        
        antiAFKDelayActive = true
        
        task.spawn(function()
            local remainingDelay = initialDelay
    
            while remainingDelay > 0 do
                -- ⭐ Cek GUI destroyed atau toggle OFF
                if isGuiDestroyed or not config.antiAfkToggle then
                    antiAFKDelayActive = false
                    print("[AoneHub] ❌ Anti-AFK: Dibatalkan (destroyed atau OFF)")
                    return
                end
                
                if remainingDelay % 60 == 0 or remainingDelay <= 10 then
                    local minutes = math.floor(remainingDelay / 60)
                    local seconds = remainingDelay % 60
                    if minutes > 0 then
                        print("[AoneHub] ⏳ Anti-AFK aktif dalam: " .. minutes .. " menit " .. seconds .. " detik")
                    else
                        print("[AoneHub] ⏳ Anti-AFK aktif dalam: " .. seconds .. " detik")
                    end
                end
                
                task.wait(1)
                remainingDelay = remainingDelay - 1
            end
            
            if config.antiAfkToggle and not isGuiDestroyed then
                antiAFKDelayActive = false
                antiAFKActive = true
                print("[AoneHub] ✅ Anti-AFK: AKTIF!")
    
                while antiAFKActive and config.antiAfkToggle and not isGuiDestroyed do  -- ⭐ GANTI
                    PerformAntiAFKAction()
        
                    local waitTime = 420 + math.random() * 180
                    local waited = 0
                    while waited < waitTime and antiAFKActive and config.antiAfkToggle and not isGuiDestroyed do  -- ⭐ GANTI
                        task.wait(1)
                        waited = waited + 1
                    end
                end
                
                antiAFKActive = false
            else
                antiAFKDelayActive = false
                print("[AoneHub] ❌ Anti-AFK: OFF (toggle dimatikan)")
            end
        end)
    end
    
    -- Fungsi untuk menghentikan Anti-AFK
    local function StopAntiAFK()
        antiAFKActive = false
        antiAFKDelayActive = false
        print("[AoneHub] ❌ Anti-AFK: OFF")
    end
    
    -- Monitor config.antiAfkToggle untuk perubahan
    task.spawn(function()
        local lastToggleState = config.antiAfkToggle
    
        while not isGuiDestroyed do  -- ⭐ GANTI
            task.wait(0.5)
        
            -- ⭐ Cek
            if isGuiDestroyed then break end
            
            if config.antiAfkToggle ~= lastToggleState then
                lastToggleState = config.antiAfkToggle
                
                if config.antiAfkToggle then
                    if not antiAFKActive and not antiAFKDelayActive then
                        antiAFKFirstRun = false
                        StartAntiAFK()
                    end
                else
                    StopAntiAFK()
                end
            end
        end
    end)
    
    -- Auto-start jika config true
    if config.antiAfkToggle then
        task.delay(1, function()
            if config.antiAfkToggle then
                StartAntiAFK()
                print("[AoneHub] ✅ Anti-AFK auto-started dengan delay 10 menit!")
            end
        end)
    end
end

