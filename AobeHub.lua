-- Auto Leveling System - Standalone Script (Fixed Scrolling)
-- Script ini berdiri sendiri dan tidak bertabrakan dengan script lain

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Services
local DataService = require(ReplicatedStorage.Modules.DataService)
local PetsService = require(ReplicatedStorage.Modules.PetServices.PetsService)

-- Constants
local MAX_PET_SLOTS = 8
local TARGET_LEVEL_DEFAULT = 100
local BASE_WEIGHT_NORMAL = 3.5
local BASE_WEIGHT_RAINBOW = 5.5
local LEVEL_TARGET_NORMAL = 50
local LEVEL_TARGET_RAINBOW = 40

-- Check if GUI already exists
if playerGui:FindFirstChild("AutoLevelGUI_Standalone") then
    playerGui:FindFirstChild("AutoLevelGUI_Standalone"):Destroy()
end

-- Functions
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

-- Main GUI
local AutoLevelGUI = Instance.new("ScreenGui")
AutoLevelGUI.Name = "AutoLevelGUI_Standalone"
AutoLevelGUI.ResetOnSpawn = false
AutoLevelGUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 380, 0, 620)
MainFrame.Position = UDim2.new(1, -400, 0.5, -310)
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = AutoLevelGUI

local UICornerMain = Instance.new("UICorner")
UICornerMain.CornerRadius = UDim.new(0, 10)
UICornerMain.Parent = MainFrame

-- Title Bar
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
TitleText.Text = "🐾 Auto Leveling v2"
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
        MainFrame.Size = UDim2.new(0, 380, 0, 620)
        ContentFrame.Visible = true
        MinimizeButton.Text = "—"
    end
end)

-- Draggable
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

-- Scroll Frame
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -20, 1, -10)
ScrollFrame.Position = UDim2.new(0, 10, 0, 5)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 1050)
ScrollFrame.Parent = ContentFrame

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 8)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Parent = ScrollFrame

-- Variables
local selectedTeamPreset = nil
local selectedWeightPreset = nil
local selectedAdvancedPreset = nil
local selectedPetTypes = {}
local queuedPets = {}
local allSelectedPets = {}
local equippedTargetPets = {}
local targetLevel = TARGET_LEVEL_DEFAULT
local advancedTargetLevel = 150
local isLeveling = false
local isAutoWeight = false
local isAdvancedLeveling = false
local rainbowMode = false
local targetSearchText = ""
local petSearchText = ""
local tempPresetPets = {}

local function getWeightTarget()
    return rainbowMode and BASE_WEIGHT_RAINBOW or BASE_WEIGHT_NORMAL
end

local function getLevelTargetForWeight()
    return rainbowMode and LEVEL_TARGET_RAINBOW or LEVEL_TARGET_NORMAL
end

-- Create Section
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

-- Fungsi untuk membuat dropdown yang bisa di-scroll
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

-- ============ PILIH TIM SECTION ============
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

-- ============ BUAT PRESET SECTION ============
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

-- ============ TARGET LEVEL SECTION ============
local LevelSection = createSection(ScrollFrame, "🎯 Target Level")
LevelSection.LayoutOrder = 3
LevelSection.Size = UDim2.new(1, -10, 0, 70)

local LevelInput = Instance.new("TextBox")
LevelInput.Size = UDim2.new(1, -20, 0, 25)
LevelInput.Position = UDim2.new(0, 10, 0, 28)
LevelInput.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
LevelInput.BorderSizePixel = 0
LevelInput.Font = Enum.Font.Gotham
LevelInput.PlaceholderText = "Target Level (untuk non-weight)"
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

-- ============ PET TARGET SECTION ============
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

-- ============ AUTO WEIGHT SECTION ============
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

-- ============ ADVANCED SECTION ============
local AdvancedSection = createSection(ScrollFrame, "🚀 Advanced (Opsional)")
AdvancedSection.LayoutOrder = 6
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

-- ============ BUTTON SECTION ============
local ButtonSection = createSection(ScrollFrame, "⚙️ Kontrol")
ButtonSection.LayoutOrder = 7
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

-- Helper Functions
local function clearDropdown(listFrame)
    for _, child in pairs(listFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
end

-- Update canvas size dengan mempertimbangkan UIListLayout
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
        "%s Mode: %s | Tim: %d | Target: %d | Antrian: %d | Weight: %s | Adv: %s",
        modeText,
        rainbowMode and "Rainbow" or "Normal",
        teamCount,
        #equippedTargetPets,
        #queuedPets,
        isAutoWeight and "ON" or "OFF",
        isAdvancedLeveling and "ON" or "OFF"
    )
end

-- Populate Preset Dropdown dengan scrolling yang benar
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
    
    -- Update canvas size
    updateCanvasSize(listFrame, 25, 3)
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

-- Event Handlers
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

ScanButton.MouseButton1Click:Connect(function()
    StatusLabel.Text = "Scanning..."
    wait(0.1)
    populateTargetDropdown()
    updateStatus()
end)

-- MAIN LOGIC (Fixed Leveling Rotation)
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
            
            for _, petUUID in ipairs(equippedPets) do
                local petType = getPetType(petUUID)
                unequipPet(petUUID)
                StatusLabel.Text = string.format("❌ Unequip %s...", petType)
                wait(0.3)
            end
            
            attempt = attempt + 1
            wait(1)
        end
        
        return #getEquippedPets() == 0
    end
    
    local function equipPetList(petList, label)
        for _, petUUID in ipairs(petList) do
            local petType = getPetType(petUUID)
            equipPet(petUUID)
            StatusLabel.Text = string.format("✅ %s %s...", label, petType)
            wait(0.3)
        end
    end
    
    spawn(function()
    -- UNEQUIP SEMUA DI AWAL
    unequipAllPets()
    wait(2)
    
    -- ============ MAIN LOOP ============
    while isLeveling do
        local weightTarget = getWeightTarget()
        local levelTargetForWeight = getLevelTargetForWeight()
        
        -- ==========================================
        -- AUTO WEIGHT LOOP (TERPISAH DARI MAIN LOOP)
        -- ==========================================
        if isAutoWeight then
            -- Loop weight terpisah, TIDAK lanjut ke leveling normal sampai selesai
            local weightLoopActive = true
            
            while isLeveling and weightLoopActive do
                StatusLabel.Text = string.format("⚖️ Scan weight (Target: %.1f)...", weightTarget)
                
                -- Scan pet yang butuh weight
                local weightPets = {}
                for _, petUUID in ipairs(allSelectedPets) do
                    local petWeight = getPetWeight(petUUID)
                    if petWeight < weightTarget then
                        table.insert(weightPets, petUUID)
                    end
                end
                
                if #weightPets == 0 then
                    -- Semua weight sudah tercapai
                    StatusLabel.Text = "✅ Semua base weight tercapai!"
                    isAutoWeight = false
                    WeightToggleButton.Text = "⚖️ Auto Weight: OFF"
                    WeightToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
                    weightLoopActive = false
                    break
                end
                
                StatusLabel.Text = string.format("⚖️ %d pet butuh weight", #weightPets)
                
                -- ============ LEVELING KE 40/50 ============
                local levelTargets = {}
                for _, petUUID in ipairs(weightPets) do
                    if getPetLevel(petUUID) < levelTargetForWeight then
                        table.insert(levelTargets, petUUID)
                    end
                end
                
                if #levelTargets > 0 then
                    StatusLabel.Text = string.format("📈 Leveling %d pet ke Lv.%d...", #levelTargets, levelTargetForWeight)
                    
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
                    
                    -- Monitoring leveling
                    while isLeveling and #levelingEquippedPets > 0 do
                        for i = #levelingEquippedPets, 1, -1 do
                            local petUUID = levelingEquippedPets[i]
                            local petLevel = getPetLevel(petUUID)
                            local petType = getPetType(petUUID)
                            
                            if petLevel >= levelTargetForWeight then
                                StatusLabel.Text = string.format("✅ %s Lv.%d!", petType, petLevel)
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
                        
                        -- Cek semua levelTargets
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
                
                -- ============ PROSES WEIGHT ============
                StatusLabel.Text = "🔄 Ganti ke tim weight..."
                
                unequipAllPets()
                wait(1)
                
                local weightUUIDs = getPresetUUIDs(selectedWeightPreset)
                equipPetList(weightUUIDs, "Weight:")
                wait(2)
                
                -- Pet yang siap weight
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
                    
                    StatusLabel.Text = "⚖️ Proses weight..."
                    
                    -- Monitoring weight
                    while isLeveling and #weightEquippedPets > 0 do
                        for i = #weightEquippedPets, 1, -1 do
                            local petUUID = weightEquippedPets[i]
                            local petWeight = getPetWeight(petUUID)
                            local petLevel = getPetLevel(petUUID)
                            local petType = getPetType(petUUID)
                            
                            if petWeight >= weightTarget then
                                StatusLabel.Text = string.format("✅ %s weight %.1f!", petType, petWeight)
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
                            elseif petLevel < levelTargetForWeight then
                                StatusLabel.Text = string.format("⚠️ %s level turun", petType)
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
                        
                        -- Cek jika semua weight tercapai
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
                            StatusLabel.Text = "🔄 Kembali ke scan weight..."
                            break -- Keluar dari monitoring weight, kembali ke scan
                        end
                        
                        updateStatus()
                        wait(5)
                    end
                else
                    StatusLabel.Text = "🔄 Tidak ada pet siap weight, kembali ke scan..."
                    -- Tidak ada yang siap, kembali ke scan weight
                end
                
                -- Tunggu sebentar sebelum scan ulang
                wait(3)
                -- Loop akan kembali ke awal weightLoopActive dan scan lagi
            end
        end
        
        -- ============ LEVELING NORMAL (HANYA SETELAH WEIGHT SELESAI) ============
        StatusLabel.Text = string.format("📈 Leveling normal ke Lv.%d...", targetLevel)
        
        queuedPets = {}
        for _, petUUID in ipairs(allSelectedPets) do
            if getPetLevel(petUUID) < targetLevel then
                table.insert(queuedPets, petUUID)
            end
        end
        
        if #queuedPets > 0 then
            unequipAllPets()
            wait(1)
            
            local teamUUIDs = getPresetUUIDs(selectedTeamPreset)
            equipPetList(teamUUIDs, "Tim:")
            
            local availableSlots = MAX_PET_SLOTS - #teamUUIDs
            local toEquip = math.min(availableSlots, #queuedPets)
            
            equippedTargetPets = {}
            for i = 1, toEquip do
                if #queuedPets > 0 then
                    local petUUID = queuedPets[1]
                    table.remove(queuedPets, 1)
                    equipPet(petUUID)
                    table.insert(equippedTargetPets, petUUID)
                    wait(0.3)
                end
            end
            
            while isLeveling and #equippedTargetPets > 0 do
                for i = #equippedTargetPets, 1, -1 do
                    local petUUID = equippedTargetPets[i]
                    local petLevel = getPetLevel(petUUID)
                    
                    if petLevel >= targetLevel then
                        unequipPet(petUUID)
                        table.remove(equippedTargetPets, i)
                        
                        if #queuedPets > 0 then
                            local nextPet = queuedPets[1]
                            table.remove(queuedPets, 1)
                            equipPet(nextPet)
                            table.insert(equippedTargetPets, nextPet)
                        end
                        wait(0.3)
                    end
                end
                
                updateStatus()
                wait(5)
            end
        end
        
        -- ============ CEK ADVANCED ============
        if isAdvancedLeveling then
            local allReachedNormalTarget = true
            for _, petUUID in ipairs(allSelectedPets) do
                if getPetLevel(petUUID) < targetLevel then
                    allReachedNormalTarget = false
                    break
                end
            end
            
            if allReachedNormalTarget then
                StatusLabel.Text = string.format("✅ Semua Lv.%d tercapai!", targetLevel)
                wait(1)
                
                unequipAllPets()
                wait(1)
                
                StatusLabel.Text = "🚀 Equip tim advanced..."
                
                local advancedUUIDs = getPresetUUIDs(selectedAdvancedPreset)
                equipPetList(advancedUUIDs, "Advanced:")
                
                wait(2)
                StatusLabel.Text = string.format("🚀 Leveling advanced ke Lv.%d...", advancedTargetLevel)
                
                local availableSlots = MAX_PET_SLOTS - #advancedUUIDs
                local toEquip = math.min(availableSlots, #allSelectedPets)
                
                for i = 1, toEquip do
                    equipPet(allSelectedPets[i])
                    wait(0.3)
                end
                
                while isLeveling do
                    local allAdvancedDone = true
                    for _, petUUID in ipairs(allSelectedPets) do
                        if getPetLevel(petUUID) < advancedTargetLevel then
                            allAdvancedDone = false
                            break
                        end
                    end
                    
                    if allAdvancedDone then
                        StatusLabel.Text = string.format("🎉 Semua Lv.%d (Advanced)!", advancedTargetLevel)
                        isLeveling = false
                        ToggleButton.Text = "▶️ Mulai"
                        ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
                        updateStatus()
                        break
                    end
                    
                    updateStatus()
                    wait(5)
                end
                
                break
            end
        else
            local allDone = true
            for _, petUUID in ipairs(allSelectedPets) do
                if getPetLevel(petUUID) < targetLevel then
                    allDone = false
                    break
                end
            end
            
            if allDone then
                StatusLabel.Text = string.format("🎉 Semua selesai Lv.%d!", targetLevel)
                isLeveling = false
                ToggleButton.Text = "▶️ Mulai"
                ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
                updateStatus()
                break
            end
        end
        
        wait(5)
    end
end)
            
            -- ============ LEVELING NORMAL ============
            StatusLabel.Text = string.format("📈 Leveling normal ke Lv.%d...", targetLevel)
            
            queuedPets = {}
            for _, petUUID in ipairs(allSelectedPets) do
                if getPetLevel(petUUID) < targetLevel then
                    table.insert(queuedPets, petUUID)
                end
            end
            
            if #queuedPets > 0 then
                unequipAllPets()
                wait(1)
                
                local teamUUIDs = getPresetUUIDs(selectedTeamPreset)
                equipPetList(teamUUIDs, "Tim:")
                
                local availableSlots = MAX_PET_SLOTS - #teamUUIDs
                local toEquip = math.min(availableSlots, #queuedPets)
                
                equippedTargetPets = {}
                for i = 1, toEquip do
                    if #queuedPets > 0 then
                        local petUUID = queuedPets[1]
                        table.remove(queuedPets, 1)
                        equipPet(petUUID)
                        table.insert(equippedTargetPets, petUUID)
                        wait(0.3)
                    end
                end
                
                while isLeveling and #equippedTargetPets > 0 do
                    for i = #equippedTargetPets, 1, -1 do
                        local petUUID = equippedTargetPets[i]
                        local petLevel = getPetLevel(petUUID)
                        
                        if petLevel >= targetLevel then
                            unequipPet(petUUID)
                            table.remove(equippedTargetPets, i)
                            
                            if #queuedPets > 0 then
                                local nextPet = queuedPets[1]
                                table.remove(queuedPets, 1)
                                equipPet(nextPet)
                                table.insert(equippedTargetPets, nextPet)
                            end
                            wait(0.3)
                        end
                    end
                    
                    updateStatus()
                    wait(5)
                end
            end
            
            -- ============ CEK ADVANCED ============
            if isAdvancedLeveling then
                local allReachedNormalTarget = true
                for _, petUUID in ipairs(allSelectedPets) do
                    if getPetLevel(petUUID) < targetLevel then
                        allReachedNormalTarget = false
                        break
                    end
                end
                
                if allReachedNormalTarget then
                    StatusLabel.Text = string.format("✅ Semua Lv.%d tercapai!", targetLevel)
                    wait(1)
                    
                    unequipAllPets()
                    wait(1)
                    
                    StatusLabel.Text = "🚀 Equip tim advanced..."
                    
                    local advancedUUIDs = getPresetUUIDs(selectedAdvancedPreset)
                    equipPetList(advancedUUIDs, "Advanced:")
                    
                    wait(2)
                    StatusLabel.Text = string.format("🚀 Leveling advanced ke Lv.%d...", advancedTargetLevel)
                    
                    local availableSlots = MAX_PET_SLOTS - #advancedUUIDs
                    local toEquip = math.min(availableSlots, #allSelectedPets)
                    
                    for i = 1, toEquip do
                        equipPet(allSelectedPets[i])
                        wait(0.3)
                    end
                    
                    while isLeveling do
                        local allAdvancedDone = true
                        for _, petUUID in ipairs(allSelectedPets) do
                            if getPetLevel(petUUID) < advancedTargetLevel then
                                allAdvancedDone = false
                                break
                            end
                        end
                        
                        if allAdvancedDone then
                            StatusLabel.Text = string.format("🎉 Semua Lv.%d tercapai (Advanced)!", advancedTargetLevel)
                            isLeveling = false
                            ToggleButton.Text = "▶️ Mulai"
                            ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
                            updateStatus()
                            break
                        end
                        
                        updateStatus()
                        wait(5)
                    end
                    
                    break
                end
            else
                local allDone = true
                for _, petUUID in ipairs(allSelectedPets) do
                    if getPetLevel(petUUID) < targetLevel then
                        allDone = false
                        break
                    end
                end
                
                if allDone then
                    StatusLabel.Text = string.format("🎉 Semua selesai Lv.%d!", targetLevel)
                    isLeveling = false
                    ToggleButton.Text = "▶️ Mulai"
                    ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
                    updateStatus()
                    break
                end
            end
            
            wait(5)
        end
    end)
end)

-- Initial setup
populatePetList()
updateStatus()

AutoLevelGUI.Parent = playerGui

print("✅ Auto Leveling v2 loaded (Standalone)!")
