-- Auto Leveling System - Full Featured with Auto Mutation
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DataService = require(ReplicatedStorage.Modules.DataService)
local PetsService = require(ReplicatedStorage.Modules.PetServices.PetsService)

local MAX_PET_SLOTS = 8
local TARGET_LEVEL_DEFAULT = 100
local BASE_WEIGHT_NORMAL = 3.5
local BASE_WEIGHT_RAINBOW = 5.5
local LEVEL_TARGET_NORMAL = 50
local LEVEL_TARGET_RAINBOW = 40

if playerGui:FindFirstChild("AutoLevelGUI_Standalone") then
    playerGui:FindFirstChild("AutoLevelGUI_Standalone"):Destroy()
end

-- ==========================================
-- VARIABLES
-- ==========================================
local selectedTeamPreset = nil
local selectedWeightPreset = nil
local selectedAdvancedPreset = nil
local selectedMutationPreset = nil
local selectedPetTypes = {}
local queuedPets = {}
local allSelectedPets = {}
local equippedTargetPets = {}
local targetLevel = TARGET_LEVEL_DEFAULT
local advancedTargetLevel = 150
local isLeveling = false
local isAutoWeight = false
local isAdvancedLeveling = false
local isAutoMutation = false
local rainbowMode = false
local targetSearchText = ""
local petSearchText = ""
local mutationSearchText = ""
local tempPresetPets = {}
local unwantedMutations = {}
local availableMutations = {}

-- ==========================================
-- FUNCTIONS
-- ==========================================
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
        local success, registry = pcall(function()
            return require(ReplicatedStorage.Data.PetRegistry.PetMutationRegistry)
        end)
        
        if success and registry and registry.EnumToPetMutation then
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

local function equipPet(petUUID)
    local success = pcall(function()
        PetsService:EquipPet(petUUID, CFrame.new(0, 10, 0))
    end)
    return success
end

local function unequipPet(petUUID)
    local success = pcall(function()
        PetsService:UnequipPet(petUUID)
    end)
    return success
end

-- Cek status mutasi pet
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
    local success, registry = pcall(function()
        return require(ReplicatedStorage.Data.PetRegistry.PetMutationRegistry)
    end)
    
    if success and registry and registry.EnumToPetMutation then
        mutationName = registry.EnumToPetMutation[mutationType] or mutationType
    end
    
    for _, unwanted in ipairs(unwantedMutations) do
        if unwanted == mutationName then
            return "unwanted", mutationName
        end
    end
    
    return "desired", mutationName
end

-- Cari pet model di workspace
local function findPetModelByUUID(petUUID)
    local petsPhysical = workspace:FindFirstChild("PetsPhysical")
    if not petsPhysical then return nil end
    
    for _, model in ipairs(petsPhysical:GetChildren()) do
        if model:IsA("Model") then
            local uuid = model:GetAttribute("UUID")
            if uuid == petUUID then
                return model
            end
        end
    end
    return nil
end

-- Gunakan Cleansing Shard
local function useCleansingShard(petUUID)
    -- Cari Cleansing Shard di backpack
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then 
        StatusLabel.Text = "⚠️ Backpack tidak ditemukan"
        return false 
    end
    
    local cleansingTool = nil
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            local shardType = tool:GetAttribute("ShardType")
            local uses = tool:GetAttribute("Uses") or 0
            
            if shardType == "Cleansing Pet Shard" and uses > 0 then
                cleansingTool = tool
                break
            end
        end
    end
    
    if not cleansingTool then
        StatusLabel.Text = "⚠️ Tidak ada Cleansing Pet Shard!"
        return false
    end
    
    -- Pastikan pet model ada di workspace
    local petModel = findPetModelByUUID(petUUID)
    if not petModel then
        StatusLabel.Text = "⚠️ Pet model tidak ditemukan!"
        return false
    end
    
    -- Pastikan humanoid ada
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        StatusLabel.Text = "⚠️ Karakter tidak ditemukan!"
        return false
    end
    
    -- Equip tool
    local success = pcall(function()
        humanoid:EquipTool(cleansingTool)
    end)
    
    if not success then
        StatusLabel.Text = "⚠️ Gagal equip shard"
        return false
    end
    
    wait(1) -- Tunggu tool ter-equip
    
    -- Activate tool dengan pcall untuk handle error
    local activateSuccess = pcall(function()
        cleansingTool:Activate()
    end)
    
    if not activateSuccess then
        StatusLabel.Text = "⚠️ Gagal menggunakan shard"
        return false
    end
    
    wait(2) -- Tunggu proses cleansing
    
    -- Unequip tool
    pcall(function()
        humanoid:UnequipTools()
    end)
    
    wait(0.5)
    
    return true
end

-- Save/Load System
local function saveTeamPreset(presetName, petList)
    local saveFolder = workspace:FindFirstChild("AutoLevel_Presets_Standalone")
    if not saveFolder then
        saveFolder = Instance.new("Folder")
        saveFolder.Name = "AutoLevel_Presets_Standalone"
        saveFolder.Parent = workspace
    end
    
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
    
    local presetData = {
        name = presetName,
        pets = petsWithInfo,
        savedAt = os.time()
    }
    
    local existingPreset = saveFolder:FindFirstChild(presetName)
    if existingPreset then
        existingPreset:Destroy()
    end
    
    local stringValue = Instance.new("StringValue")
    stringValue.Name = presetName
    stringValue.Value = HttpService:JSONEncode(presetData)
    stringValue.Parent = saveFolder
end

local function loadTeamPresets()
    local presets = {}
    local saveFolder = workspace:FindFirstChild("AutoLevel_Presets_Standalone")
    if saveFolder then
        for _, child in pairs(saveFolder:GetChildren()) do
            if child:IsA("StringValue") then
                local success, decoded = pcall(function()
                    return HttpService:JSONDecode(child.Value)
                end)
                if success and decoded then
                    presets[child.Name] = decoded
                end
            end
        end
    end
    return presets
end

local function getPresetUUIDs(presetName)
    local presets = loadTeamPresets()
    local preset = presets[presetName]
    if preset then
        local uuids = {}
        for _, petInfo in ipairs(preset.pets) do
            table.insert(uuids, petInfo.UUID)
        end
        return uuids
    end
    return {}
end

-- ==========================================
-- MAIN GUI
-- ==========================================
local AutoLevelGUI = Instance.new("ScreenGui")
AutoLevelGUI.Name = "AutoLevelGUI_Standalone"
AutoLevelGUI.ResetOnSpawn = false
AutoLevelGUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 380, 0, 700)
MainFrame.Position = UDim2.new(1, -400, 0.5, -350)
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = AutoLevelGUI

local UICornerMain = Instance.new("UICorner")
UICornerMain.CornerRadius = UDim.new(0, 10)
UICornerMain.Parent = MainFrame

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local UICornerTitle = Instance.new("UICorner")
UICornerTitle.CornerRadius = UDim.new(0, 10)
UICornerTitle.Parent = TitleBar

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(0.6, 0, 1, 0)
TitleText.Position = UDim2.new(0, 10, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Font = Enum.Font.GothamBold
TitleText.Text = "🐾 Auto Leveling v3"
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.TextSize = 14
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Size = UDim2.new(0, 25, 0, 25)
MinimizeButton.Position = UDim2.new(1, -60, 0, 8)
MinimizeButton.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
MinimizeButton.BorderSizePixel = 0
MinimizeButton.Font = Enum.Font.GothamBold
MinimizeButton.Text = "—"
MinimizeButton.TextColor3 = Color3.fromRGB(0, 0, 0)
MinimizeButton.TextSize = 14
MinimizeButton.Parent = TitleBar

local UICornerMinimize = Instance.new("UICorner")
UICornerMinimize.CornerRadius = UDim.new(0, 5)
UICornerMinimize.Parent = MinimizeButton

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 25, 0, 25)
CloseButton.Position = UDim2.new(1, -30, 0, 8)
CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseButton.BorderSizePixel = 0
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 14
CloseButton.Parent = TitleBar

local UICornerClose = Instance.new("UICorner")
UICornerClose.CornerRadius = UDim.new(0, 5)
UICornerClose.Parent = CloseButton

CloseButton.MouseButton1Click:Connect(function()
    AutoLevelGUI:Destroy()
end)

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, 0, 1, -40)
ContentFrame.Position = UDim2.new(0, 0, 0, 40)
ContentFrame.BackgroundTransparency = 1
ContentFrame.BorderSizePixel = 0
ContentFrame.Parent = MainFrame

local isMinimized = false
MinimizeButton.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        MainFrame.Size = UDim2.new(0, 380, 0, 40)
        ContentFrame.Visible = false
        MinimizeButton.Text = "+"
    else
        MainFrame.Size = UDim2.new(0, 380, 0, 700)
        ContentFrame.Visible = true
        MinimizeButton.Text = "—"
    end
end)

local dragging = false
local dragInput = nil
local dragStart = nil
local startPos = nil

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -20, 1, -10)
ScrollFrame.Position = UDim2.new(0, 10, 0, 5)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 1500)
ScrollFrame.Parent = ContentFrame

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 8)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Parent = ScrollFrame

local function getWeightTarget()
    return rainbowMode and BASE_WEIGHT_RAINBOW or BASE_WEIGHT_NORMAL
end

local function getLevelTargetForWeight()
    return rainbowMode and LEVEL_TARGET_RAINBOW or LEVEL_TARGET_NORMAL
end

-- Load semua mutasi yang tersedia
local function loadAvailableMutations()
    local mutations = {}
    local success, registry = pcall(function()
        return require(ReplicatedStorage.Data.PetRegistry.PetMutationRegistry)
    end)
    
    if success and registry and registry.PetMutationRegistry then
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

-- ==========================================
-- UI HELPERS
-- ==========================================
local function createSection(parent, title)
    local SectionFrame = Instance.new("Frame")
    SectionFrame.Size = UDim2.new(1, -10, 0, 200)
    SectionFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    SectionFrame.BorderSizePixel = 0
    SectionFrame.Parent = parent
    
    local UICornerSection = Instance.new("UICorner")
    UICornerSection.CornerRadius = UDim.new(0, 6)
    UICornerSection.Parent = SectionFrame
    
    local SectionTitle = Instance.new("TextLabel")
    SectionTitle.Size = UDim2.new(1, -20, 0, 25)
    SectionTitle.Position = UDim2.new(0, 10, 0, 5)
    SectionTitle.BackgroundTransparency = 1
    SectionTitle.Font = Enum.Font.GothamBold
    SectionTitle.Text = title
    SectionTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    SectionTitle.TextSize = 13
    SectionTitle.TextXAlignment = Enum.TextXAlignment.Left
    SectionTitle.Parent = SectionFrame
    
    return SectionFrame, SectionTitle
end

local function createScrollableDropdown(parent, position, size, placeholder)
    local DropdownFrame = Instance.new("Frame")
    DropdownFrame.Size = size
    DropdownFrame.Position = position
    DropdownFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
    DropdownFrame.BorderSizePixel = 0
    DropdownFrame.Parent = parent
    
    local UICornerDropdown = Instance.new("UICorner")
    UICornerDropdown.CornerRadius = UDim.new(0, 4)
    UICornerDropdown.Parent = DropdownFrame
    
    local DropdownButton = Instance.new("TextButton")
    DropdownButton.Size = UDim2.new(1, 0, 1, 0)
    DropdownButton.BackgroundTransparency = 1
    DropdownButton.Font = Enum.Font.Gotham
    DropdownButton.Text = placeholder
    DropdownButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    DropdownButton.TextSize = 10
    DropdownButton.Parent = DropdownFrame
    
    return DropdownFrame, DropdownButton
end

-- ==========================================
-- SECTION: PILIH TIM
-- ==========================================
local TeamSelectSection = createSection(ScrollFrame, "👥 Pilih Tim Leveling")
TeamSelectSection.LayoutOrder = 1
TeamSelectSection.Size = UDim2.new(1, -10, 0, 120)

local SelectedTeamLabel = Instance.new("TextLabel")
SelectedTeamLabel.Size = UDim2.new(1, -20, 0, 35)
SelectedTeamLabel.Position = UDim2.new(0, 10, 0, 28)
SelectedTeamLabel.BackgroundColor3 = Color3.fromRGB(50, 80, 50)
SelectedTeamLabel.BorderSizePixel = 0
SelectedTeamLabel.Font = Enum.Font.GothamBold
SelectedTeamLabel.Text = "Tim Leveling: Belum dipilih"
SelectedTeamLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SelectedTeamLabel.TextSize = 9
SelectedTeamLabel.TextWrapped = true
SelectedTeamLabel.Parent = TeamSelectSection

local UICornerSelectedTeam = Instance.new("UICorner")
UICornerSelectedTeam.CornerRadius = UDim.new(0, 4)
UICornerSelectedTeam.Parent = SelectedTeamLabel

local PresetDropdown, PresetDropdownButton = createScrollableDropdown(
    TeamSelectSection,
    UDim2.new(0, 10, 0, 68),
    UDim2.new(1, -20, 0, 28),
    "📂 Pilih Preset Tim Leveling"
)

local PresetListFrame = Instance.new("ScrollingFrame")
PresetListFrame.Size = UDim2.new(1, -20, 0, 70)
PresetListFrame.Position = UDim2.new(0, 10, 0, 100)
PresetListFrame.BackgroundTransparency = 1
PresetListFrame.BorderSizePixel = 0
PresetListFrame.ScrollBarThickness = 3
PresetListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
PresetListFrame.CanvasSize = UDim2.new(0, 0, 0, 70)
PresetListFrame.Visible = false
PresetListFrame.Parent = TeamSelectSection

local PresetListLayout = Instance.new("UIListLayout")
PresetListLayout.Padding = UDim.new(0, 3)
PresetListLayout.Parent = PresetListFrame

-- ==========================================
-- SECTION: BUAT PRESET
-- ==========================================
local CreatePresetSection = createSection(ScrollFrame, "💾 Buat Preset Tim")
CreatePresetSection.LayoutOrder = 2
CreatePresetSection.Size = UDim2.new(1, -10, 0, 160)

local PresetNameInput = Instance.new("TextBox")
PresetNameInput.Size = UDim2.new(1, -20, 0, 25)
PresetNameInput.Position = UDim2.new(0, 10, 0, 28)
PresetNameInput.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
PresetNameInput.BorderSizePixel = 0
PresetNameInput.Font = Enum.Font.Gotham
PresetNameInput.PlaceholderText = "Nama preset tim..."
PresetNameInput.Text = ""
PresetNameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
PresetNameInput.TextSize = 10
PresetNameInput.Parent = CreatePresetSection

local UICornerPresetName = Instance.new("UICorner")
UICornerPresetName.CornerRadius = UDim.new(0, 4)
UICornerPresetName.Parent = PresetNameInput

local PetSearchBox = Instance.new("TextBox")
PetSearchBox.Size = UDim2.new(1, -20, 0, 22)
PetSearchBox.Position = UDim2.new(0, 10, 0, 56)
PetSearchBox.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
PetSearchBox.BorderSizePixel = 0
PetSearchBox.Font = Enum.Font.Gotham
PetSearchBox.PlaceholderText = "🔍 Cari pet..."
PetSearchBox.Text = ""
PetSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
PetSearchBox.TextSize = 10
PetSearchBox.Parent = CreatePresetSection

local UICornerPetSearch = Instance.new("UICorner")
UICornerPetSearch.CornerRadius = UDim.new(0, 4)
UICornerPetSearch.Parent = PetSearchBox

local PetListFrame = Instance.new("ScrollingFrame")
PetListFrame.Size = UDim2.new(1, -20, 0, 60)
PetListFrame.Position = UDim2.new(0, 10, 0, 80)
PetListFrame.BackgroundTransparency = 1
PetListFrame.BorderSizePixel = 0
PetListFrame.ScrollBarThickness = 3
PetListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
PetListFrame.CanvasSize = UDim2.new(0, 0, 0, 80)
PetListFrame.Parent = CreatePresetSection

local PetListLayout = Instance.new("UIListLayout")
PetListLayout.Padding = UDim.new(0, 2)
PetListLayout.Parent = PetListFrame

local SavePresetButton = Instance.new("TextButton")
SavePresetButton.Size = UDim2.new(1, -20, 0, 22)
SavePresetButton.Position = UDim2.new(0, 10, 0, 135)
SavePresetButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
SavePresetButton.BorderSizePixel = 0
SavePresetButton.Font = Enum.Font.GothamBold
SavePresetButton.Text = "💾 Simpan Preset"
SavePresetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SavePresetButton.TextSize = 10
SavePresetButton.Parent = CreatePresetSection

local UICornerSave = Instance.new("UICorner")
UICornerSave.CornerRadius = UDim.new(0, 4)
UICornerSave.Parent = SavePresetButton

-- ==========================================
-- SECTION: TARGET LEVEL
-- ==========================================
local LevelSection = createSection(ScrollFrame, "🎯 Target Level")
LevelSection.LayoutOrder = 3
LevelSection.Size = UDim2.new(1, -10, 0, 70)

local LevelInput = Instance.new("TextBox")
LevelInput.Size = UDim2.new(1, -20, 0, 25)
LevelInput.Position = UDim2.new(0, 10, 0, 28)
LevelInput.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
LevelInput.BorderSizePixel = 0
LevelInput.Font = Enum.Font.Gotham
LevelInput.PlaceholderText = "Target Level"
LevelInput.Text = tostring(TARGET_LEVEL_DEFAULT)
LevelInput.TextColor3 = Color3.fromRGB(255, 255, 255)
LevelInput.TextSize = 10
LevelInput.Parent = LevelSection

local UICornerLevelInput = Instance.new("UICorner")
UICornerLevelInput.CornerRadius = UDim.new(0, 4)
UICornerLevelInput.Parent = LevelInput

LevelInput.FocusLost:Connect(function()
    local newLevel = tonumber(LevelInput.Text)
    if newLevel and newLevel > 0 then
        targetLevel = newLevel
    else
        LevelInput.Text = tostring(targetLevel)
    end
end)

-- ==========================================
-- SECTION: PET TARGET
-- ==========================================
local TargetSection = createSection(ScrollFrame, "🎯 Pet Target")
TargetSection.LayoutOrder = 4
TargetSection.Size = UDim2.new(1, -10, 0, 160)

local TargetSearchBox = Instance.new("TextBox")
TargetSearchBox.Size = UDim2.new(1, -20, 0, 22)
TargetSearchBox.Position = UDim2.new(0, 10, 0, 28)
TargetSearchBox.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
TargetSearchBox.BorderSizePixel = 0
TargetSearchBox.Font = Enum.Font.Gotham
TargetSearchBox.PlaceholderText = "🔍 Cari pet target..."
TargetSearchBox.Text = ""
TargetSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TargetSearchBox.TextSize = 10
TargetSearchBox.Parent = TargetSection

local UICornerTargetSearch = Instance.new("UICorner")
UICornerTargetSearch.CornerRadius = UDim.new(0, 4)
UICornerTargetSearch.Parent = TargetSearchBox

local TargetListFrame = Instance.new("ScrollingFrame")
TargetListFrame.Size = UDim2.new(1, -20, 0, 80)
TargetListFrame.Position = UDim2.new(0, 10, 0, 52)
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
ScanButton.Position = UDim2.new(0, 10, 0, 135)
ScanButton.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
ScanButton.BorderSizePixel = 0
ScanButton.Font = Enum.Font.GothamBold
ScanButton.Text = "🔍 Scan Pet Target"
ScanButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ScanButton.TextSize = 10
ScanButton.Parent = TargetSection

local UICornerScan = Instance.new("UICorner")
UICornerScan.CornerRadius = UDim.new(0, 4)
UICornerScan.Parent = ScanButton

-- ==========================================
-- SECTION: AUTO WEIGHT
-- ==========================================
local WeightSection = createSection(ScrollFrame, "⚖️ Auto Weight")
WeightSection.LayoutOrder = 5
WeightSection.Size = UDim2.new(1, -10, 0, 160)

local WeightToggleButton = Instance.new("TextButton")
WeightToggleButton.Size = UDim2.new(1, -20, 0, 28)
WeightToggleButton.Position = UDim2.new(0, 10, 0, 28)
WeightToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
WeightToggleButton.BorderSizePixel = 0
WeightToggleButton.Font = Enum.Font.GothamBold
WeightToggleButton.Text = "⚖️ Auto Weight: OFF"
WeightToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
WeightToggleButton.TextSize = 11
WeightToggleButton.Parent = WeightSection

local UICornerWeightToggle = Instance.new("UICorner")
UICornerWeightToggle.CornerRadius = UDim.new(0, 5)
UICornerWeightToggle.Parent = WeightToggleButton

local RainbowModeButton = Instance.new("TextButton")
RainbowModeButton.Size = UDim2.new(1, -20, 0, 25)
RainbowModeButton.Position = UDim2.new(0, 10, 0, 60)
RainbowModeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
RainbowModeButton.BorderSizePixel = 0
RainbowModeButton.Font = Enum.Font.Gotham
RainbowModeButton.Text = "☐ Rainbow Mode (BW: 5.5, Lv: 40)"
RainbowModeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
RainbowModeButton.TextSize = 10
RainbowModeButton.Parent = WeightSection

local UICornerRainbow = Instance.new("UICorner")
UICornerRainbow.CornerRadius = UDim.new(0, 4)
UICornerRainbow.Parent = RainbowModeButton

local WeightPresetDropdown, WeightPresetButton = createScrollableDropdown(
    WeightSection,
    UDim2.new(0, 10, 0, 90),
    UDim2.new(1, -20, 0, 28),
    "📂 Pilih Preset Auto Weight"
)

local WeightPresetListFrame = Instance.new("ScrollingFrame")
WeightPresetListFrame.Size = UDim2.new(1, -20, 0, 60)
WeightPresetListFrame.Position = UDim2.new(0, 10, 0, 120)
WeightPresetListFrame.BackgroundTransparency = 1
WeightPresetListFrame.BorderSizePixel = 0
WeightPresetListFrame.ScrollBarThickness = 3
WeightPresetListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
WeightPresetListFrame.CanvasSize = UDim2.new(0, 0, 0, 60)
WeightPresetListFrame.Visible = false
WeightPresetListFrame.Parent = WeightSection

local WeightPresetLayout = Instance.new("UIListLayout")
WeightPresetLayout.Padding = UDim.new(0, 2)
WeightPresetLayout.Parent = WeightPresetListFrame

-- ==========================================
-- SECTION: AUTO MUTATION
-- ==========================================
local MutationSection = createSection(ScrollFrame, "🧬 Auto Mutation")
MutationSection.LayoutOrder = 6
MutationSection.Size = UDim2.new(1, -10, 0, 320)

local MutationToggleButton = Instance.new("TextButton")
MutationToggleButton.Size = UDim2.new(1, -20, 0, 28)
MutationToggleButton.Position = UDim2.new(0, 10, 0, 28)
MutationToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
MutationToggleButton.BorderSizePixel = 0
MutationToggleButton.Font = Enum.Font.GothamBold
MutationToggleButton.Text = "🧬 Auto Mutation: OFF"
MutationToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MutationToggleButton.TextSize = 11
MutationToggleButton.Parent = MutationSection

local UICornerMutationToggle = Instance.new("UICorner")
UICornerMutationToggle.CornerRadius = UDim.new(0, 5)
UICornerMutationToggle.Parent = MutationToggleButton

local MutationPresetDropdown, MutationPresetButton = createScrollableDropdown(
    MutationSection,
    UDim2.new(0, 10, 0, 62),
    UDim2.new(1, -20, 0, 28),
    "📂 Pilih Preset Tim Mutation"
)

local MutationPresetListFrame = Instance.new("ScrollingFrame")
MutationPresetListFrame.Size = UDim2.new(1, -20, 0, 60)
MutationPresetListFrame.Position = UDim2.new(0, 10, 0, 95)
MutationPresetListFrame.BackgroundTransparency = 1
MutationPresetListFrame.BorderSizePixel = 0
MutationPresetListFrame.ScrollBarThickness = 3
MutationPresetListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
MutationPresetListFrame.CanvasSize = UDim2.new(0, 0, 0, 60)
MutationPresetListFrame.Visible = false
MutationPresetListFrame.Parent = MutationSection

local MutationPresetLayout = Instance.new("UIListLayout")
MutationPresetLayout.Padding = UDim.new(0, 2)
MutationPresetLayout.Parent = MutationPresetListFrame

local MutationSearchBox = Instance.new("TextBox")
MutationSearchBox.Size = UDim2.new(1, -20, 0, 22)
MutationSearchBox.Position = UDim2.new(0, 10, 0, 128)
MutationSearchBox.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
MutationSearchBox.BorderSizePixel = 0
MutationSearchBox.Font = Enum.Font.Gotham
MutationSearchBox.PlaceholderText = "🔍 Cari mutasi..."
MutationSearchBox.Text = ""
MutationSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
MutationSearchBox.TextSize = 10
MutationSearchBox.Parent = MutationSection

local UICornerMutationSearch = Instance.new("UICorner")
UICornerMutationSearch.CornerRadius = UDim.new(0, 4)
UICornerMutationSearch.Parent = MutationSearchBox

local MutationListLabel = Instance.new("TextLabel")
MutationListLabel.Size = UDim2.new(1, -20, 0, 18)
MutationListLabel.Position = UDim2.new(0, 10, 0, 152)
MutationListLabel.BackgroundTransparency = 1
MutationListLabel.Font = Enum.Font.GothamBold
MutationListLabel.Text = "❌ Mutasi tidak diinginkan (klik untuk pilih):"
MutationListLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
MutationListLabel.TextSize = 9
MutationListLabel.TextXAlignment = Enum.TextXAlignment.Left
MutationListLabel.Parent = MutationSection

local MutationListFrame = Instance.new("ScrollingFrame")
MutationListFrame.Size = UDim2.new(1, -20, 0, 140)
MutationListFrame.Position = UDim2.new(0, 10, 0, 172)
MutationListFrame.BackgroundTransparency = 1
MutationListFrame.BorderSizePixel = 0
MutationListFrame.ScrollBarThickness = 3
MutationListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
MutationListFrame.CanvasSize = UDim2.new(0, 0, 0, 140)
MutationListFrame.Parent = MutationSection

local MutationListLayout = Instance.new("UIListLayout")
MutationListLayout.Padding = UDim.new(0, 2)
MutationListLayout.Parent = MutationListFrame

-- ==========================================
-- SECTION: ADVANCED
-- ==========================================
local AdvancedSection = createSection(ScrollFrame, "🚀 Advanced (Opsional)")
AdvancedSection.LayoutOrder = 7
AdvancedSection.Size = UDim2.new(1, -10, 0, 120)

local AdvancedToggleButton = Instance.new("TextButton")
AdvancedToggleButton.Size = UDim2.new(1, -20, 0, 25)
AdvancedToggleButton.Position = UDim2.new(0, 10, 0, 28)
AdvancedToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
AdvancedToggleButton.BorderSizePixel = 0
AdvancedToggleButton.Font = Enum.Font.GothamBold
AdvancedToggleButton.Text = "🚀 Advanced: OFF"
AdvancedToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
AdvancedToggleButton.TextSize = 10
AdvancedToggleButton.Parent = AdvancedSection

local UICornerAdvancedToggle = Instance.new("UICorner")
UICornerAdvancedToggle.CornerRadius = UDim.new(0, 4)
UICornerAdvancedToggle.Parent = AdvancedToggleButton

local AdvancedLevelInput = Instance.new("TextBox")
AdvancedLevelInput.Size = UDim2.new(1, -20, 0, 22)
AdvancedLevelInput.Position = UDim2.new(0, 10, 0, 56)
AdvancedLevelInput.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
AdvancedLevelInput.BorderSizePixel = 0
AdvancedLevelInput.Font = Enum.Font.Gotham
AdvancedLevelInput.PlaceholderText = "Advanced Target Level"
AdvancedLevelInput.Text = "150"
AdvancedLevelInput.TextColor3 = Color3.fromRGB(255, 255, 255)
AdvancedLevelInput.TextSize = 10
AdvancedLevelInput.Parent = AdvancedSection

local UICornerAdvancedLevel = Instance.new("UICorner")
UICornerAdvancedLevel.CornerRadius = UDim.new(0, 4)
UICornerAdvancedLevel.Parent = AdvancedLevelInput

AdvancedLevelInput.FocusLost:Connect(function()
    local newLevel = tonumber(AdvancedLevelInput.Text)
    if newLevel and newLevel > 0 then
        advancedTargetLevel = newLevel
    else
        AdvancedLevelInput.Text = tostring(advancedTargetLevel)
    end
end)

local AdvancedPresetDropdown, AdvancedPresetButton = createScrollableDropdown(
    AdvancedSection,
    UDim2.new(0, 10, 0, 82),
    UDim2.new(1, -20, 0, 25),
    "📂 Pilih Preset Advanced"
)

local AdvancedPresetListFrame = Instance.new("ScrollingFrame")
AdvancedPresetListFrame.Size = UDim2.new(1, -20, 0, 50)
AdvancedPresetListFrame.Position = UDim2.new(0, 10, 0, 110)
AdvancedPresetListFrame.BackgroundTransparency = 1
AdvancedPresetListFrame.BorderSizePixel = 0
AdvancedPresetListFrame.ScrollBarThickness = 3
AdvancedPresetListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
AdvancedPresetListFrame.CanvasSize = UDim2.new(0, 0, 0, 50)
AdvancedPresetListFrame.Visible = false
AdvancedPresetListFrame.Parent = AdvancedSection

local AdvancedPresetLayout = Instance.new("UIListLayout")
AdvancedPresetLayout.Padding = UDim.new(0, 2)
AdvancedPresetLayout.Parent = AdvancedPresetListFrame

-- ==========================================
-- SECTION: KONTROL
-- ==========================================
local ButtonSection = createSection(ScrollFrame, "⚙️ Kontrol")
ButtonSection.LayoutOrder = 8
ButtonSection.Size = UDim2.new(1, -10, 0, 80)

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(1, -20, 0, 30)
ToggleButton.Position = UDim2.new(0, 10, 0, 25)
ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
ToggleButton.BorderSizePixel = 0
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Text = "▶️ Mulai"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 11
ToggleButton.Parent = ButtonSection

local UICornerToggle = Instance.new("UICorner")
UICornerToggle.CornerRadius = UDim.new(0, 5)
UICornerToggle.Parent = ToggleButton

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 15)
StatusLabel.Position = UDim2.new(0, 10, 0, 58)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "Status: Idle"
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.TextSize = 9
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = ButtonSection

-- ==========================================
-- HELPER FUNCTIONS
-- ==========================================
local function clearDropdown(listFrame)
    for _, child in pairs(listFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
end

local function updateCanvasSize(scrollingFrame, itemHeight, padding)
    local totalItems = 0
    for _, child in pairs(scrollingFrame:GetChildren()) do
        if child:IsA("TextButton") then
            totalItems = totalItems + 1
        end
    end
    
    local totalHeight = totalItems * (itemHeight + padding) + padding
    scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(totalHeight, 50))
end

local function updateStatus()
    local teamCount = selectedTeamPreset and #getPresetUUIDs(selectedTeamPreset) or 0
    local modeText = rainbowMode and "🌈" or "📊"
    
    StatusLabel.Text = string.format(
        "%s T:%d | Q:%d | W:%s A:%s M:%s",
        modeText,
        teamCount,
        #queuedPets,
        isAutoWeight and "✓" or "✗",
        isAdvancedLeveling and "✓" or "✗",
        isAutoMutation and "✓" or "✗"
    )
end

-- Populate Preset Dropdown
local function populatePresetDropdown(listFrame, selectedPreset, onSelect)
    clearDropdown(listFrame)
    
    local presets = loadTeamPresets()
    local presetNames = {}
    for name in pairs(presets) do
        table.insert(presetNames, name)
    end
    table.sort(presetNames)
    
    for i, presetName in ipairs(presetNames) do
        local preset = presets[presetName]
        
        local PresetButton = Instance.new("TextButton")
        PresetButton.Size = UDim2.new(1, 0, 0, 25)
        PresetButton.BackgroundColor3 = selectedPreset == presetName and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(70, 70, 85)
        PresetButton.BorderSizePixel = 0
        PresetButton.Font = Enum.Font.Gotham
        PresetButton.Text = string.format("📁 %s (%d pet)", presetName, #preset.pets)
        PresetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        PresetButton.TextSize = 9
        PresetButton.Parent = listFrame
        
        local UICornerPreset = Instance.new("UICorner")
        UICornerPreset.CornerRadius = UDim.new(0, 3)
        UICornerPreset.Parent = PresetButton
        
        PresetButton.MouseButton1Click:Connect(function()
            onSelect(presetName)
            listFrame.Visible = false
            updateStatus()
        end)
    end
    
    updateCanvasSize(listFrame, 25, 3)
end

-- Populate Mutation List
local function populateMutationList()
    clearDropdown(MutationListFrame)
    
    for _, mutationName in ipairs(availableMutations) do
        if mutationSearchText == "" or mutationName:lower():find(mutationSearchText:lower()) then
            local isSelected = table.find(unwantedMutations, mutationName) ~= nil
            
            local MutationButton = Instance.new("TextButton")
            MutationButton.Size = UDim2.new(1, 0, 0, 22)
            MutationButton.BackgroundColor3 = isSelected and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(70, 70, 85)
            MutationButton.BorderSizePixel = 0
            MutationButton.Font = Enum.Font.Gotham
            MutationButton.Text = isSelected and string.format("❌ %s", mutationName) or string.format("☐ %s", mutationName)
            MutationButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            MutationButton.TextSize = 9
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
                populateMutationList()
            end)
        end
    end
    
    updateCanvasSize(MutationListFrame, 22, 2)
end

-- Populate Pet List
local function populatePetList()
    clearDropdown(PetListFrame)
    
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
        PetButton.Size = UDim2.new(1, 0, 0, 25)
        PetButton.BackgroundColor3 = petInfo.IsSelected and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(70, 70, 85)
        PetButton.BorderSizePixel = 0
        PetButton.Font = Enum.Font.Gotham
        PetButton.Text = petInfo.IsSelected and string.format("✓ %s (Lv.%d)", petInfo.DisplayName, petInfo.Level) or string.format("%s (Lv.%d)", petInfo.DisplayName, petInfo.Level)
        PetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        PetButton.TextSize = 9
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
    
    updateCanvasSize(PetListFrame, 25, 3)
end

-- Scan target pets
local function scanTargetPets()
    local petsData = getPlayerPetData()
    if not petsData then return {} end
    
    local inventory = petsData.PetInventory.Data or {}
    local teamUUIDs = {}
    
    if selectedTeamPreset then
        local uuids = getPresetUUIDs(selectedTeamPreset)
        for _, uuid in ipairs(uuids) do
            teamUUIDs[uuid] = true
        end
    end
    
    local weightTarget = getWeightTarget()
    local levelTargetForWeight = getLevelTargetForWeight()
    local effectiveTargetLevel = isAutoWeight and levelTargetForWeight or targetLevel
    
    local petTypes = {}
    
    for petUUID, _ in pairs(inventory) do
        if not teamUUIDs[petUUID] then
            local petType = getPetType(petUUID)
            local petLevel = getPetLevel(petUUID)
            local petWeight = getPetWeight(petUUID)
            
            local needsLeveling = petLevel < effectiveTargetLevel
            local needsWeight = isAutoWeight and (petWeight < weightTarget)
            
            if needsLeveling or needsWeight then
                if not petTypes[petType] then
                    petTypes[petType] = {}
                end
                table.insert(petTypes[petType], {
                    UUID = petUUID,
                    Level = petLevel,
                    Weight = petWeight,
                    NeedsLeveling = needsLeveling,
                    NeedsWeight = needsWeight
                })
            end
        end
    end
    
    return petTypes
end

-- Populate Target Dropdown
local function populateTargetDropdown()
    clearDropdown(TargetListFrame)
    
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
        PetButton.Size = UDim2.new(1, 0, 0, 25)
        PetButton.BackgroundColor3 = petInfo.IsSelected and Color3.fromRGB(200, 150, 50) or Color3.fromRGB(70, 70, 85)
        PetButton.BorderSizePixel = 0
        PetButton.Font = Enum.Font.Gotham
        PetButton.Text = petInfo.IsSelected and string.format("✓ %s (x%d)", petInfo.PetType, petInfo.Count) or string.format("%s (x%d)", petInfo.PetType, petInfo.Count)
        PetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        PetButton.TextSize = 9
        PetButton.Parent = TargetListFrame
        
        local UICornerTarget = Instance.new("UICorner")
        UICornerTarget.CornerRadius = UDim.new(0, 3)
        UICornerTarget.Parent = PetButton
        
        PetButton.MouseButton1Click:Connect(function()
            local typeIndex = table.find(selectedPetTypes, petInfo.PetType)
            
            if typeIndex then
                table.remove(selectedPetTypes, typeIndex)
                for j = #queuedPets, 1, -1 do
                    if getPetType(queuedPets[j]) == petInfo.PetType then
                        table.remove(queuedPets, j)
                    end
                end
                for j = #allSelectedPets, 1, -1 do
                    if getPetType(allSelectedPets[j]) == petInfo.PetType then
                        table.remove(allSelectedPets, j)
                    end
                end
            else
                table.insert(selectedPetTypes, petInfo.PetType)
                for _, petInstance in ipairs(petInfo.Instances) do
                    if not table.find(queuedPets, petInstance.UUID) then
                        table.insert(queuedPets, petInstance.UUID)
                    end
                    if not table.find(allSelectedPets, petInstance.UUID) then
                        table.insert(allSelectedPets, petInstance.UUID)
                    end
                end
            end
            
            populateTargetDropdown()
            updateStatus()
        end)
    end
    
    updateCanvasSize(TargetListFrame, 25, 3)
end

-- ==========================================
-- EVENT HANDLERS
-- ==========================================
SavePresetButton.MouseButton1Click:Connect(function()
    local presetName = PresetNameInput.Text
    if presetName == "" then StatusLabel.Text = "⚠️ Masukkan nama preset!" return end
    if #tempPresetPets == 0 then StatusLabel.Text = "⚠️ Pilih minimal 1 pet!" return end
    
    saveTeamPreset(presetName, tempPresetPets)
    StatusLabel.Text = string.format("✅ Preset '%s' disimpan!", presetName)
    PresetNameInput.Text = ""
    tempPresetPets = {}
    populatePetList()
end)

PresetDropdownButton.MouseButton1Click:Connect(function()
    PresetListFrame.Visible = not PresetListFrame.Visible
    if PresetListFrame.Visible then
        populatePresetDropdown(PresetListFrame, selectedTeamPreset, function(name)
            selectedTeamPreset = name
            SelectedTeamLabel.Text = string.format("Tim Leveling: %s", name)
        end)
    end
end)

WeightPresetButton.MouseButton1Click:Connect(function()
    WeightPresetListFrame.Visible = not WeightPresetListFrame.Visible
    if WeightPresetListFrame.Visible then
        populatePresetDropdown(WeightPresetListFrame, selectedWeightPreset, function(name)
            selectedWeightPreset = name
            WeightPresetButton.Text = string.format("📂 %s", name)
        end)
    end
end)

MutationPresetButton.MouseButton1Click:Connect(function()
    MutationPresetListFrame.Visible = not MutationPresetListFrame.Visible
    if MutationPresetListFrame.Visible then
        populatePresetDropdown(MutationPresetListFrame, selectedMutationPreset, function(name)
            selectedMutationPreset = name
            MutationPresetButton.Text = string.format("📂 %s", name)
        end)
    end
end)

AdvancedPresetButton.MouseButton1Click:Connect(function()
    AdvancedPresetListFrame.Visible = not AdvancedPresetListFrame.Visible
    if AdvancedPresetListFrame.Visible then
        populatePresetDropdown(AdvancedPresetListFrame, selectedAdvancedPreset, function(name)
            selectedAdvancedPreset = name
            AdvancedPresetButton.Text = string.format("📂 %s", name)
        end)
    end
end)

WeightToggleButton.MouseButton1Click:Connect(function()
    isAutoWeight = not isAutoWeight
    if isAutoWeight then
        WeightToggleButton.Text = "⚖️ Auto Weight: ON"
        WeightToggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    else
        WeightToggleButton.Text = "⚖️ Auto Weight: OFF"
        WeightToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
    end
    updateStatus()
end)

AdvancedToggleButton.MouseButton1Click:Connect(function()
    isAdvancedLeveling = not isAdvancedLeveling
    if isAdvancedLeveling then
        AdvancedToggleButton.Text = "🚀 Advanced: ON"
        AdvancedToggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    else
        AdvancedToggleButton.Text = "🚀 Advanced: OFF"
        AdvancedToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
    end
    updateStatus()
end)

MutationToggleButton.MouseButton1Click:Connect(function()
    isAutoMutation = not isAutoMutation
    if isAutoMutation then
        MutationToggleButton.Text = "🧬 Auto Mutation: ON"
        MutationToggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    else
        MutationToggleButton.Text = "🧬 Auto Mutation: OFF"
        MutationToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
    end
    updateStatus()
end)

RainbowModeButton.MouseButton1Click:Connect(function()
    rainbowMode = not rainbowMode
    if rainbowMode then
        RainbowModeButton.Text = "☑ Rainbow Mode (BW: 5.5, Lv: 40)"
        RainbowModeButton.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
    else
        RainbowModeButton.Text = "☐ Rainbow Mode (BW: 5.5, Lv: 40)"
        RainbowModeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
    end
    updateStatus()
end)

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
    StatusLabel.Text = "Scanning..."
    wait(0.1)
    populateTargetDropdown()
    updateStatus()
end)

-- ==========================================
-- MAIN LOGIC
-- ==========================================
ToggleButton.MouseButton1Click:Connect(function()
    if isLeveling then
        isLeveling = false
        ToggleButton.Text = "▶️ Mulai"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
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
    ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    
    local function unequipAllPets()
    StatusLabel.Text = "🔄 Membersihkan semua slot..."
    local maxAttempts = 3
    local attempt = 0
    
    while attempt < maxAttempts and isLeveling do
        local equippedPets = getEquippedPets()
        
        if #equippedPets == 0 then
            StatusLabel.Text = "✅ Semua slot bersih!"
            return true
        end
        
        -- Unequip satu per satu dengan delay
        for _, petUUID in ipairs(equippedPets) do
            pcall(function()
                unequipPet(petUUID)
            end)
            wait(0.5) -- Delay lebih lama untuk menghindari race condition
        end
        
        attempt = attempt + 1
        wait(2) -- Tunggu 2 detik sebelum cek lagi
    end
    
    return #getEquippedPets() == 0
end
    
    local function equipPet(petUUID)
    local success, err = pcall(function()
        PetsService:EquipPet(petUUID, CFrame.new(0, 10, 0))
    end)
    
    if not success then
        warn("Equip error:", err)
        return false
    end
    
    -- Tunggu pet benar-benar ter-equip
    wait(0.5)
    return true
        end
    
    spawn(function()
        -- UNEQUIP SEMUA DI AWAL
        unequipAllPets()
        wait(2)
        
        -- ==========================================
        -- PRIORITAS 1: AUTO WEIGHT (jika aktif)
        -- ==========================================
        if isAutoWeight then
            local weightLoopActive = true
            
            while isLeveling and weightLoopActive do
                local weightTarget = getWeightTarget()
                local levelTargetForWeight = getLevelTargetForWeight()
                
                StatusLabel.Text = string.format("⚖️ Scan weight (Target: %.1f)...", weightTarget)
                
                local weightPets = {}
                for _, petUUID in ipairs(allSelectedPets) do
                    if getPetWeight(petUUID) < weightTarget then
                        table.insert(weightPets, petUUID)
                    end
                end
                
                if #weightPets == 0 then
                    StatusLabel.Text = "✅ Semua base weight tercapai!"
                    isAutoWeight = false
                    WeightToggleButton.Text = "⚖️ Auto Weight: OFF"
                    WeightToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
                    weightLoopActive = false
                    break
                end
                
                -- Leveling ke 40/50
                local levelTargets = {}
                for _, petUUID in ipairs(weightPets) do
                    if getPetLevel(petUUID) < levelTargetForWeight then
                        table.insert(levelTargets, petUUID)
                    end
                end
                
                if #levelTargets > 0 then
                    unequipAllPets()
                    wait(1)
                    
                    local teamUUIDs = getPresetUUIDs(selectedTeamPreset)
                    equipPetList(teamUUIDs, "Tim:")
                    wait(1)
                    
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
                            equipPet(petUUID)
                            table.insert(levelingEquippedPets, petUUID)
                            wait(0.3)
                        end
                    end
                    
                    while isLeveling and #levelingEquippedPets > 0 do
                        for i = #levelingEquippedPets, 1, -1 do
                            local petUUID = levelingEquippedPets[i]
                            if getPetLevel(petUUID) >= levelTargetForWeight then
                                unequipPet(petUUID)
                                table.remove(levelingEquippedPets, i)
                                
                                if #pendingLevelTargets > 0 then
                                    local nextPet = pendingLevelTargets[1]
                                    table.remove(pendingLevelTargets, 1)
                                    if getPetLevel(nextPet) < levelTargetForWeight then
                                        equipPet(nextPet)
                                        table.insert(levelingEquippedPets, nextPet)
                                        wait(0.3)
                                    end
                                end
                            end
                        end
                        
                        local allLeveled = true
                        for _, petUUID in ipairs(levelTargets) do
                            if getPetLevel(petUUID) < levelTargetForWeight then
                                allLeveled = false
                                break
                            end
                        end
                        
                        if allLeveled then break end
                        if #levelingEquippedPets == 0 and #pendingLevelTargets == 0 then break end
                        
                        updateStatus()
                        wait(5)
                    end
                end
                
                -- Proses weight
                unequipAllPets()
                wait(1)
                
                local weightUUIDs = getPresetUUIDs(selectedWeightPreset)
                equipPetList(weightUUIDs, "Weight:")
                wait(2)
                
                local readyForWeight = {}
                for _, petUUID in ipairs(weightPets) do
                    if getPetLevel(petUUID) >= levelTargetForWeight then
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
                            equipPet(petUUID)
                            table.insert(weightEquippedPets, petUUID)
                            wait(0.3)
                        end
                    end
                    
                    while isLeveling and #weightEquippedPets > 0 do
                        for i = #weightEquippedPets, 1, -1 do
                            local petUUID = weightEquippedPets[i]
                            if getPetWeight(petUUID) >= weightTarget then
                                unequipPet(petUUID)
                                table.remove(weightEquippedPets, i)
                                
                                if #pendingWeightPets > 0 then
                                    local nextPet = pendingWeightPets[1]
                                    table.remove(pendingWeightPets, 1)
                                    if getPetLevel(nextPet) >= levelTargetForWeight then
                                        equipPet(nextPet)
                                        table.insert(weightEquippedPets, nextPet)
                                        wait(0.3)
                                    end
                                end
                            elseif getPetLevel(petUUID) < levelTargetForWeight then
                                unequipPet(petUUID)
                                table.remove(weightEquippedPets, i)
                                
                                if #pendingWeightPets > 0 then
                                    local nextPet = pendingWeightPets[1]
                                    table.remove(pendingWeightPets, 1)
                                    if getPetLevel(nextPet) >= levelTargetForWeight then
                                        equipPet(nextPet)
                                        table.insert(weightEquippedPets, nextPet)
                                        wait(0.3)
                                    end
                                end
                            end
                        end
                        
                        local allWeightDone = true
                        for _, petUUID in ipairs(allSelectedPets) do
                            if getPetWeight(petUUID) < weightTarget then
                                allWeightDone = false
                                break
                            end
                        end
                        
                        if allWeightDone then
                            StatusLabel.Text = "✅ Semua base weight tercapai!"
                            isAutoWeight = false
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
        
        -- ==========================================
        -- PRIORITAS 2: AUTO MUTATION (jika aktif)
        -- ==========================================
        if isAutoMutation and isLeveling then
            local mutationLoopActive = true
            
            while isLeveling and mutationLoopActive do
                StatusLabel.Text = "🧬 Scan status mutasi pet target..."
                
                local needMutation = {}
                local needCleansing = {}
                local alreadyGood = {}
                
                for _, petUUID in ipairs(allSelectedPets) do
                    local status, mutationName = getMutationStatus(petUUID)
                    
                    if status == "none" then
                        table.insert(needMutation, petUUID)
                    elseif status == "unwanted" then
                        table.insert(needCleansing, {UUID = petUUID, Mutation = mutationName})
                    else
                        table.insert(alreadyGood, petUUID)
                    end
                end
                
                if #needMutation == 0 and #needCleansing == 0 then
                    StatusLabel.Text = "🎉 Semua pet target sudah bermutasi diinginkan!"
                    isAutoMutation = false
                    MutationToggleButton.Text = "🧬 Auto Mutation: OFF"
                    MutationToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
                    mutationLoopActive = false
                    break
                end
                
                StatusLabel.Text = string.format(
                    "🧬 Tanpa: %d | Cleansing: %d | OK: %d",
                    #needMutation,
                    #needCleansing,
                    #alreadyGood
                )
                
                -- LANGKAH 1: CLEANSING MUTASI TIDAK DIINGINKAN
if #needCleansing > 0 then
    unequipAllPets()
    wait(2)
    
    local mutationTeamUUIDs = getPresetUUIDs(selectedMutationPreset)
    equipPetList(mutationTeamUUIDs, "Mutation Team:")
    wait(3) -- Delay lebih lama setelah equip tim
    
    local availableSlots = MAX_PET_SLOTS - #mutationTeamUUIDs
    local toProcess = math.min(availableSlots, #needCleansing)
    
    for i = 1, toProcess do
        local petInfo = needCleansing[i]
        local petUUID = petInfo.UUID
        local petType = getPetType(petUUID)
        
        -- Equip pet satu per satu dengan delay
        local equipSuccess = equipPet(petUUID)
        if not equipSuccess then
            StatusLabel.Text = string.format("⚠️ Gagal equip %s", petType)
            continue
        end
        
        wait(2) -- Tunggu pet benar-benar muncul di workspace
        
        StatusLabel.Text = string.format("🧬 Cleansing %s (%s)...", petType, petInfo.Mutation)
        
        -- Verifikasi pet model ada sebelum cleansing
        local petModel = findPetModelByUUID(petUUID)
        if not petModel then
            StatusLabel.Text = string.format("⚠️ Model %s tidak ditemukan", petType)
            wait(1)
            continue
        end
        
        -- Gunakan cleansing shard dengan pcall
        local success = false
        local ok, err = pcall(function()
            success = useCleansingShard(petUUID)
        end)
        
        if not ok then
            warn("Cleansing error:", err)
            StatusLabel.Text = string.format("⚠️ Error cleansing %s", petType)
        elseif success then
            StatusLabel.Text = string.format("✅ %s di-cleansing!", petType)
        else
            StatusLabel.Text = string.format("⚠️ Gagal cleansing %s", petType)
        end
        
        -- Delay sebelum proses pet berikutnya
        wait(3)
    end
    
    wait(3)
                        end
                
                -- LANGKAH 2: EQUIP PET TANPA MUTASI + TUNGGU MUTASI
if #needMutation > 0 then
    unequipAllPets()
    wait(2)
    
    local mutationTeamUUIDs = getPresetUUIDs(selectedMutationPreset)
    equipPetList(mutationTeamUUIDs, "Mutation Team:")
    wait(3)
    
    local availableSlots = MAX_PET_SLOTS - #mutationTeamUUIDs
    local toEquip = math.min(availableSlots, #needMutation)
    
    local equippedForMutation = {}
    local pendingMutationList = {}
    
    for _, petUUID in ipairs(needMutation) do
        table.insert(pendingMutationList, petUUID)
    end
    
    -- Equip satu per satu dengan delay
    for i = 1, toEquip do
        if #pendingMutationList > 0 then
            local petUUID = pendingMutationList[1]
            table.remove(pendingMutationList, 1)
            
            local equipSuccess = equipPet(petUUID)
            if equipSuccess then
                table.insert(equippedForMutation, petUUID)
                wait(1) -- Delay antar equip
            end
        end
    end
    
    wait(2) -- Tunggu semua pet muncul di workspace
    
    StatusLabel.Text = string.format("🧬 Menunggu %d pet mendapat mutasi...", #equippedForMutation)
    
    while isLeveling and #equippedForMutation > 0 do
        for i = #equippedForMutation, 1, -1 do
            local petUUID = equippedForMutation[i]
            local petType = getPetType(petUUID)
            local status, mutationName = getMutationStatus(petUUID)
            
            if status == "desired" then
                StatusLabel.Text = string.format("✅ %s mendapat %s!", petType, mutationName)
                
                -- Unequip dengan pcall
                pcall(function()
                    unequipPet(petUUID)
                end)
                
                table.remove(equippedForMutation, i)
                wait(1)
                
                if #pendingMutationList > 0 then
                    local nextPet = pendingMutationList[1]
                    table.remove(pendingMutationList, 1)
                    
                    local equipSuccess = equipPet(nextPet)
                    if equipSuccess then
                        table.insert(equippedForMutation, nextPet)
                        StatusLabel.Text = string.format("🔄 Ganti dengan %s...", getPetType(nextPet))
                    end
                    wait(1)
                end
            elseif status == "unwanted" then
                StatusLabel.Text = string.format("⚠️ %s dapat %s, cleansing...", petType, mutationName)
                
                -- Pastikan pet model ada
                local petModel = findPetModelByUUID(petUUID)
                if petModel then
                    local ok, err = pcall(function()
                        useCleansingShard(petUUID)
                    end)
                    
                    if not ok then
                        warn("Cleansing error:", err)
                        StatusLabel.Text = string.format("⚠️ Error cleansing %s", petType)
                    else
                        StatusLabel.Text = string.format("✅ %s di-cleansing, tunggu lagi...", petType)
                    end
                else
                    StatusLabel.Text = string.format("⚠️ Model %s hilang, re-equip...", petType)
                    -- Re-equip pet
                    pcall(function()
                        unequipPet(petUUID)
                    end)
                    wait(1)
                    equipPet(petUUID)
                    wait(1)
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
                        end
                
                wait(3)
            end
        end
        
        -- ==========================================
        -- PRIORITAS 3: LEVELING NORMAL
        -- ==========================================
        if isLeveling then
            StatusLabel.Text = string.format("📈 Leveling normal ke Lv.%d...", targetLevel)
            
            local pendingNormalPets = {}
            for _, petUUID in ipairs(allSelectedPets) do
                if getPetLevel(petUUID) < targetLevel then
                    table.insert(pendingNormalPets, petUUID)
                end
            end
            
            if #pendingNormalPets > 0 then
                unequipAllPets()
                wait(1)
                
                local teamUUIDs = getPresetUUIDs(selectedTeamPreset)
                equipPetList(teamUUIDs, "Tim:")
                wait(1)
                
                local availableSlots = MAX_PET_SLOTS - #teamUUIDs
                local toEquip = math.min(availableSlots, #pendingNormalPets)
                
                local normalEquippedPets = {}
                local pendingNormalList = {}
                
                for _, petUUID in ipairs(pendingNormalPets) do
                    table.insert(pendingNormalList, petUUID)
                end
                
                for i = 1, toEquip do
                    if #pendingNormalList > 0 then
                        local petUUID = pendingNormalList[1]
                        table.remove(pendingNormalList, 1)
                        equipPet(petUUID)
                        table.insert(normalEquippedPets, petUUID)
                        wait(0.3)
                    end
                end
                
                while isLeveling and #normalEquippedPets > 0 do
                    for i = #normalEquippedPets, 1, -1 do
                        local petUUID = normalEquippedPets[i]
                        if getPetLevel(petUUID) >= targetLevel then
                            unequipPet(petUUID)
                            table.remove(normalEquippedPets, i)
                            
                            if #pendingNormalList > 0 then
                                local nextPet = pendingNormalList[1]
                                table.remove(pendingNormalList, 1)
                                if getPetLevel(nextPet) < targetLevel then
                                    equipPet(nextPet)
                                    table.insert(normalEquippedPets, nextPet)
                                    wait(0.3)
                                end
                            end
                        end
                    end
                    
                    local allNormalDone = true
                    for _, petUUID in ipairs(allSelectedPets) do
                        if getPetLevel(petUUID) < targetLevel then
                            allNormalDone = false
                            break
                        end
                    end
                    
                    if allNormalDone then break end
                    if #normalEquippedPets == 0 and #pendingNormalList == 0 then break end
                    
                    updateStatus()
                    wait(5)
                end
            end
        end
        
        -- ==========================================
        -- PRIORITAS 4: ADVANCED LEVELING
        -- ==========================================
        if isAdvancedLeveling and isLeveling then
            local allReachedNormalTarget = true
            for _, petUUID in ipairs(allSelectedPets) do
                if getPetLevel(petUUID) < targetLevel then
                    allReachedNormalTarget = false
                    break
                end
            end
            
            if allReachedNormalTarget then
                unequipAllPets()
                wait(1)
                
                local advancedUUIDs = getPresetUUIDs(selectedAdvancedPreset)
                equipPetList(advancedUUIDs, "Advanced:")
                wait(2)
                
                local pendingAdvancedList = {}
                for _, petUUID in ipairs(allSelectedPets) do
                    if getPetLevel(petUUID) < advancedTargetLevel then
                        table.insert(pendingAdvancedList, petUUID)
                    end
                end
                
                if #pendingAdvancedList > 0 then
                    local availableSlots = MAX_PET_SLOTS - #advancedUUIDs
                    local toEquip = math.min(availableSlots, #pendingAdvancedList)
                    
                    local advancedEquippedPets = {}
                    
                    for i = 1, toEquip do
                        if #pendingAdvancedList > 0 then
                            local petUUID = pendingAdvancedList[1]
                            table.remove(pendingAdvancedList, 1)
                            equipPet(petUUID)
                            table.insert(advancedEquippedPets, petUUID)
                            wait(0.3)
                        end
                    end
                    
                    while isLeveling and #advancedEquippedPets > 0 do
                        for i = #advancedEquippedPets, 1, -1 do
                            local petUUID = advancedEquippedPets[i]
                            if getPetLevel(petUUID) >= advancedTargetLevel then
                                unequipPet(petUUID)
                                table.remove(advancedEquippedPets, i)
                                
                                if #pendingAdvancedList > 0 then
                                    local nextPet = pendingAdvancedList[1]
                                    table.remove(pendingAdvancedList, 1)
                                    if getPetLevel(nextPet) < advancedTargetLevel then
                                        equipPet(nextPet)
                                        table.insert(advancedEquippedPets, nextPet)
                                        wait(0.3)
                                    end
                                end
                            end
                        end
                        
                        local allAdvancedDone = true
                        for _, petUUID in ipairs(allSelectedPets) do
                            if getPetLevel(petUUID) < advancedTargetLevel then
                                allAdvancedDone = false
                                break
                            end
                        end
                        
                        if allAdvancedDone then break end
                        
                        if #advancedEquippedPets == 0 and #pendingAdvancedList == 0 then
                            local stillNeed = false
                            for _, petUUID in ipairs(allSelectedPets) do
                                if getPetLevel(petUUID) < advancedTargetLevel then
                                    stillNeed = true
                                    break
                                end
                            end
                            
                            if stillNeed then
                                for _, petUUID in ipairs(allSelectedPets) do
                                    if getPetLevel(petUUID) < advancedTargetLevel then
                                        table.insert(pendingAdvancedList, petUUID)
                                    end
                                end
                                
                                local reEquip = math.min(availableSlots, #pendingAdvancedList)
                                for i = 1, reEquip do
                                    if #pendingAdvancedList > 0 then
                                        local petUUID = pendingAdvancedList[1]
                                        table.remove(pendingAdvancedList, 1)
                                        equipPet(petUUID)
                                        table.insert(advancedEquippedPets, petUUID)
                                        wait(0.3)
                                    end
                                end
                            else
                                break
                            end
                        end
                        
                        updateStatus()
                        wait(5)
                    end
                end
            end
        end
        
        -- ==========================================
        -- SELESAI
        -- ==========================================
        StatusLabel.Text = "🎉 Semua proses selesai!"
        isLeveling = false
        ToggleButton.Text = "▶️ Mulai"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
        updateStatus()
    end)
end)

-- Initial setup
populatePetList()
populateMutationList()
updateStatus()

AutoLevelGUI.Parent = playerGui

print("✅ Auto Leveling v3 dengan Auto Mutation loaded!")
