-- Auto Leveling System GUI (Preset Based)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Services
local DataService = require(ReplicatedStorage.Modules.DataService)
local PetsService = require(ReplicatedStorage.Modules.PetServices.PetsService)

-- Constants
local MAX_PET_SLOTS = 8
local TARGET_LEVEL_DEFAULT = 100

-- Save/Load System
local function saveTeamPreset(presetName, petList)
    local saveFolder = workspace:FindFirstChild("AutoLevel_Presets")
    if not saveFolder then
        saveFolder = Instance.new("Folder")
        saveFolder.Name = "AutoLevel_Presets"
        saveFolder.Parent = workspace
    end
    
    local presetData = {
        name = presetName,
        pets = petList,
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
    
    local saveFolder = workspace:FindFirstChild("AutoLevel_Presets")
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

local function deleteTeamPreset(presetName)
    local saveFolder = workspace:FindFirstChild("AutoLevel_Presets")
    if saveFolder then
        local preset = saveFolder:FindFirstChild(presetName)
        if preset then
            preset:Destroy()
        end
    end
end

-- Main GUI
local AutoLevelGUI = Instance.new("ScreenGui")
AutoLevelGUI.Name = "AutoLevelGUI"
AutoLevelGUI.ResetOnSpawn = false
AutoLevelGUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 350, 0, 480)
MainFrame.Position = UDim2.new(1, -370, 0.5, -240)
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = AutoLevelGUI

local UICornerMain = Instance.new("UICorner")
UICornerMain.CornerRadius = UDim.new(0, 10)
UICornerMain.Parent = MainFrame

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
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
TitleText.Text = "🐾 Auto Leveling"
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.TextSize = 16
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

-- Minimize Button
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

-- Close Button
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

-- Content Frame
local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, 0, 1, -40)
ContentFrame.Position = UDim2.new(0, 0, 0, 40)
ContentFrame.BackgroundTransparency = 1
ContentFrame.BorderSizePixel = 0
ContentFrame.Parent = MainFrame

-- Minimize Functionality
local isMinimized = false
MinimizeButton.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        MainFrame.Size = UDim2.new(0, 350, 0, 40)
        ContentFrame.Visible = false
        MinimizeButton.Text = "+"
    else
        MainFrame.Size = UDim2.new(0, 350, 0, 480)
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
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 800)
ScrollFrame.Parent = ContentFrame

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 8)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Parent = ScrollFrame

-- Variables
local selectedTeamPreset = nil -- Preset tim yang dipilih untuk leveling
local selectedPetTypes = {} -- Pet type yang dipilih untuk target
local queuedPets = {} -- Antrian semua pet target
local equippedTargetPets = {} -- Pet target yang sedang di-equip
local targetLevel = TARGET_LEVEL_DEFAULT
local isLeveling = false
local targetSearchText = ""
local petSearchText = "" -- Search untuk membuat preset

-- Create Section function
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

-- ============ PILIH TIM SECTION ============
local TeamSelectSection, TeamSelectTitle = createSection(ScrollFrame, "👥 Pilih Tim Leveling")
TeamSelectSection.LayoutOrder = 1
TeamSelectSection.Size = UDim2.new(1, -10, 0, 120)

-- Selected Team Display
local SelectedTeamLabel = Instance.new("TextLabel")
SelectedTeamLabel.Size = UDim2.new(1, -20, 0, 25)
SelectedTeamLabel.Position = UDim2.new(0, 10, 0, 30)
SelectedTeamLabel.BackgroundColor3 = Color3.fromRGB(50, 80, 50)
SelectedTeamLabel.BorderSizePixel = 0
SelectedTeamLabel.Font = Enum.Font.GothamBold
SelectedTeamLabel.Text = "Belum ada tim dipilih"
SelectedTeamLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SelectedTeamLabel.TextSize = 11
SelectedTeamLabel.Parent = TeamSelectSection

local UICornerSelectedTeam = Instance.new("UICorner")
UICornerSelectedTeam.CornerRadius = UDim.new(0, 4)
UICornerSelectedTeam.Parent = SelectedTeamLabel

-- Preset Dropdown
local PresetDropdown = Instance.new("Frame")
PresetDropdown.Size = UDim2.new(1, -20, 0, 30)
PresetDropdown.Position = UDim2.new(0, 10, 0, 60)
PresetDropdown.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
PresetDropdown.BorderSizePixel = 0
PresetDropdown.Parent = TeamSelectSection

local UICornerPresetDropdown = Instance.new("UICorner")
UICornerPresetDropdown.CornerRadius = UDim.new(0, 4)
UICornerPresetDropdown.Parent = PresetDropdown

local PresetDropdownButton = Instance.new("TextButton")
PresetDropdownButton.Size = UDim2.new(1, 0, 1, 0)
PresetDropdownButton.BackgroundTransparency = 1
PresetDropdownButton.Font = Enum.Font.Gotham
PresetDropdownButton.Text = "📂 Pilih Preset Tim"
PresetDropdownButton.TextColor3 = Color3.fromRGB(200, 200, 200)
PresetDropdownButton.TextSize = 11
PresetDropdownButton.Parent = PresetDropdown

-- Preset List
local PresetListFrame = Instance.new("ScrollingFrame")
PresetListFrame.Size = UDim2.new(1, -20, 0, 80)
PresetListFrame.Position = UDim2.new(0, 10, 0, 95)
PresetListFrame.BackgroundTransparency = 1
PresetListFrame.BorderSizePixel = 0
PresetListFrame.ScrollBarThickness = 3
PresetListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
PresetListFrame.CanvasSize = UDim2.new(0, 0, 0, 80)
PresetListFrame.Visible = false
PresetListFrame.Parent = TeamSelectSection

local PresetListLayout = Instance.new("UIListLayout")
PresetListLayout.Padding = UDim.new(0, 3)
PresetListLayout.Parent = PresetListFrame

-- ============ BUAT PRESET SECTION ============
local CreatePresetSection, CreatePresetTitle = createSection(ScrollFrame, "💾 Buat Preset Tim")
CreatePresetSection.LayoutOrder = 2
CreatePresetSection.Size = UDim2.new(1, -10, 0, 180)

-- Preset Name Input
local PresetNameInput = Instance.new("TextBox")
PresetNameInput.Size = UDim2.new(1, -20, 0, 28)
PresetNameInput.Position = UDim2.new(0, 10, 0, 30)
PresetNameInput.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
PresetNameInput.BorderSizePixel = 0
PresetNameInput.Font = Enum.Font.Gotham
PresetNameInput.PlaceholderText = "Nama preset tim..."
PresetNameInput.Text = ""
PresetNameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
PresetNameInput.TextSize = 11
PresetNameInput.Parent = CreatePresetSection

local UICornerPresetName = Instance.new("UICorner")
UICornerPresetName.CornerRadius = UDim.new(0, 4)
UICornerPresetName.Parent = PresetNameInput

-- Pet Search
local PetSearchBox = Instance.new("TextBox")
PetSearchBox.Size = UDim2.new(1, -20, 0, 25)
PetSearchBox.Position = UDim2.new(0, 10, 0, 62)
PetSearchBox.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
PetSearchBox.BorderSizePixel = 0
PetSearchBox.Font = Enum.Font.Gotham
PetSearchBox.PlaceholderText = "🔍 Cari pet..."
PetSearchBox.Text = ""
PetSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
PetSearchBox.TextSize = 11
PetSearchBox.Parent = CreatePresetSection

local UICornerPetSearch = Instance.new("UICorner")
UICornerPetSearch.CornerRadius = UDim.new(0, 4)
UICornerPetSearch.Parent = PetSearchBox

-- Pet List (untuk membuat preset)
local PetListFrame = Instance.new("ScrollingFrame")
PetListFrame.Size = UDim2.new(1, -20, 0, 80)
PetListFrame.Position = UDim2.new(0, 10, 0, 90)
PetListFrame.BackgroundTransparency = 1
PetListFrame.BorderSizePixel = 0
PetListFrame.ScrollBarThickness = 3
PetListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
PetListFrame.CanvasSize = UDim2.new(0, 0, 0, 100)
PetListFrame.Parent = CreatePresetSection

local PetListLayout = Instance.new("UIListLayout")
PetListLayout.Padding = UDim.new(0, 3)
PetListLayout.Parent = PetListFrame

-- Save Preset Button
local SavePresetButton = Instance.new("TextButton")
SavePresetButton.Size = UDim2.new(1, -20, 0, 25)
SavePresetButton.Position = UDim2.new(0, 10, 0, 150)
SavePresetButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
SavePresetButton.BorderSizePixel = 0
SavePresetButton.Font = Enum.Font.GothamBold
SavePresetButton.Text = "💾 Simpan Preset"
SavePresetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SavePresetButton.TextSize = 11
SavePresetButton.Parent = CreatePresetSection

local UICornerSave = Instance.new("UICorner")
UICornerSave.CornerRadius = UDim.new(0, 4)
UICornerSave.Parent = SavePresetButton

-- ============ TARGET LEVEL SECTION ============
local LevelSection, LevelTitleLabel = createSection(ScrollFrame, "🎯 Target Level")
LevelSection.LayoutOrder = 3
LevelSection.Size = UDim2.new(1, -10, 0, 70)

local LevelInput = Instance.new("TextBox")
LevelInput.Size = UDim2.new(1, -20, 0, 30)
LevelInput.Position = UDim2.new(0, 10, 0, 30)
LevelInput.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
LevelInput.BorderSizePixel = 0
LevelInput.Font = Enum.Font.Gotham
LevelInput.PlaceholderText = "Target Level"
LevelInput.Text = tostring(TARGET_LEVEL_DEFAULT)
LevelInput.TextColor3 = Color3.fromRGB(255, 255, 255)
LevelInput.TextSize = 12
LevelInput.Parent = LevelSection

local UICornerLevelInput = Instance.new("UICorner")
UICornerLevelInput.CornerRadius = UDim.new(0, 5)
UICornerLevelInput.Parent = LevelInput

LevelInput.FocusLost:Connect(function(enterPressed)
    local newLevel = tonumber(LevelInput.Text)
    if newLevel and newLevel > 0 then
        targetLevel = newLevel
    else
        LevelInput.Text = tostring(targetLevel)
    end
end)

-- ============ TARGET SECTION ============
local TargetSection, TargetTitleLabel = createSection(ScrollFrame, "🎯 Pet Target")
TargetSection.LayoutOrder = 4
TargetSection.Size = UDim2.new(1, -10, 0, 180)

local TargetSearchBox = Instance.new("TextBox")
TargetSearchBox.Size = UDim2.new(1, -20, 0, 25)
TargetSearchBox.Position = UDim2.new(0, 10, 0, 30)
TargetSearchBox.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
TargetSearchBox.BorderSizePixel = 0
TargetSearchBox.Font = Enum.Font.Gotham
TargetSearchBox.PlaceholderText = "🔍 Cari pet target..."
TargetSearchBox.Text = ""
TargetSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TargetSearchBox.TextSize = 11
TargetSearchBox.Parent = TargetSection

local UICornerTargetSearch = Instance.new("UICorner")
UICornerTargetSearch.CornerRadius = UDim.new(0, 4)
UICornerTargetSearch.Parent = TargetSearchBox

local TargetListFrame = Instance.new("ScrollingFrame")
TargetListFrame.Size = UDim2.new(1, -20, 0, 100)
TargetListFrame.Position = UDim2.new(0, 10, 0, 58)
TargetListFrame.BackgroundTransparency = 1
TargetListFrame.BorderSizePixel = 0
TargetListFrame.ScrollBarThickness = 3
TargetListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
TargetListFrame.CanvasSize = UDim2.new(0, 0, 0, 100)
TargetListFrame.Parent = TargetSection

local TargetListLayout = Instance.new("UIListLayout")
TargetListLayout.Padding = UDim.new(0, 3)
TargetListLayout.Parent = TargetListFrame

-- Scan Button
local ScanButton = Instance.new("TextButton")
ScanButton.Size = UDim2.new(1, -20, 0, 25)
ScanButton.Position = UDim2.new(0, 10, 0, 155)
ScanButton.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
ScanButton.BorderSizePixel = 0
ScanButton.Font = Enum.Font.GothamBold
ScanButton.Text = "🔍 Scan Pet Target"
ScanButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ScanButton.TextSize = 11
ScanButton.Parent = TargetSection

local UICornerScan = Instance.new("UICorner")
UICornerScan.CornerRadius = UDim.new(0, 4)
UICornerScan.Parent = ScanButton

-- ============ BUTTON SECTION ============
local ButtonSection, ButtonTitleLabel = createSection(ScrollFrame, "⚙️ Kontrol")
ButtonSection.LayoutOrder = 5
ButtonSection.Size = UDim2.new(1, -10, 0, 100)

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(1, -20, 0, 35)
ToggleButton.Position = UDim2.new(0, 10, 0, 30)
ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
ToggleButton.BorderSizePixel = 0
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Text = "▶️ Mulai"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 12
ToggleButton.Parent = ButtonSection

local UICornerToggle = Instance.new("UICorner")
UICornerToggle.CornerRadius = UDim.new(0, 5)
UICornerToggle.Parent = ToggleButton

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 20)
StatusLabel.Position = UDim2.new(0, 10, 0, 70)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "Status: Idle"
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.TextSize = 10
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = ButtonSection

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
            return petData.PetData.PetType or 
                   petData.PetData.Type or 
                   "Unknown"
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
            return petData.PetData.Level or 
                   petData.PetData.CurrentLevel or 
                   0
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

local function clearDropdown(listFrame)
    for _, child in pairs(listFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
end

-- Temporary selected pets untuk membuat preset
local tempPresetPets = {}

-- Populate Preset Dropdown (untuk memilih tim)
local function populatePresetDropdown()
    clearDropdown(PresetListFrame)
    
    local presets = loadTeamPresets()
    local presetNames = {}
    
    for name in pairs(presets) do
        table.insert(presetNames, name)
    end
    
    table.sort(presetNames)
    
    PresetListFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(#presetNames * 28, 50))
    
    for i, presetName in ipairs(presetNames) do
        local preset = presets[presetName]
        
        local PresetButton = Instance.new("TextButton")
        PresetButton.Size = UDim2.new(1, 0, 0, 25)
        PresetButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
        PresetButton.BorderSizePixel = 0
        PresetButton.Font = Enum.Font.Gotham
        PresetButton.Text = string.format("📁 %s (%d pet)", presetName, #preset.pets)
        PresetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        PresetButton.TextSize = 10
        PresetButton.Parent = PresetListFrame
        PresetButton.LayoutOrder = i
        
        local UICornerPreset = Instance.new("UICorner")
        UICornerPreset.CornerRadius = UDim.new(0, 4)
        UICornerPreset.Parent = PresetButton
        
        -- Highlight jika dipilih
        if selectedTeamPreset == presetName then
            PresetButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        end
        
        PresetButton.MouseButton1Click:Connect(function()
            selectedTeamPreset = presetName
            SelectedTeamLabel.Text = string.format("✅ Tim: %s (%d pet)", presetName, #preset.pets)
            StatusLabel.Text = string.format("✅ Preset '%s' dipilih!", presetName)
            PresetListFrame.Visible = false
        end)
        
        PresetButton.MouseButton2Click:Connect(function()
            deleteTeamPreset(presetName)
            if selectedTeamPreset == presetName then
                selectedTeamPreset = nil
                SelectedTeamLabel.Text = "Belum ada tim dipilih"
            end
            StatusLabel.Text = string.format("🗑️ Preset '%s' dihapus!", presetName)
            populatePresetDropdown()
        end)
    end
end

-- Populate Pet List (untuk membuat preset)
local function populatePetList()
    clearDropdown(PetListFrame)
    
    local petsData = getPlayerPetData()
    if not petsData then return end
    
    local inventory = petsData.PetInventory.Data or {}
    local allPets = {}
    
    for petUUID, _ in pairs(inventory) do
        local petType = getPetType(petUUID)
        local petLevel = getPetLevel(petUUID)
        local isSelected = table.find(tempPresetPets, petUUID) ~= nil
        
        if petSearchText == "" or petType:lower():find(petSearchText:lower()) then
            table.insert(allPets, {
                UUID = petUUID,
                PetType = petType,
                Level = petLevel,
                IsSelected = isSelected
            })
        end
    end
    
    table.sort(allPets, function(a, b)
        if a.IsSelected ~= b.IsSelected then
            return a.IsSelected
        else
            return a.PetType < b.PetType
        end
    end)
    
    PetListFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(#allPets * 25, 50))
    
    for i, petInfo in ipairs(allPets) do
        local PetButton = Instance.new("TextButton")
        PetButton.Size = UDim2.new(1, 0, 0, 22)
        PetButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
        PetButton.BorderSizePixel = 0
        PetButton.Font = Enum.Font.Gotham
        PetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        PetButton.TextSize = 10
        PetButton.Parent = PetListFrame
        PetButton.LayoutOrder = i
        
        local UICornerPet = Instance.new("UICorner")
        UICornerPet.CornerRadius = UDim.new(0, 3)
        UICornerPet.Parent = PetButton
        
        if petInfo.IsSelected then
            PetButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
            PetButton.Text = string.format("✓ %s (Lv.%d)", petInfo.PetType, petInfo.Level)
        else
            PetButton.Text = string.format("%s (Lv.%d)", petInfo.PetType, petInfo.Level)
        end
        
        PetButton.MouseButton1Click:Connect(function()
            local index = table.find(tempPresetPets, petInfo.UUID)
            if index then
                table.remove(tempPresetPets, index)
            else
                if #tempPresetPets < MAX_PET_SLOTS then
                    table.insert(tempPresetPets, petInfo.UUID)
                else
                    StatusLabel.Text = "⚠️ Maksimal 8 pet per preset!"
                    return
                end
            end
            populatePetList()
        end)
    end
end

-- Scan target pets
local function scanTargetPets()
    local petsData = getPlayerPetData()
    if not petsData then return {} end
    
    local inventory = petsData.PetInventory.Data or {}
    local teamUUIDs = {}
    
    -- Get UUIDs dari preset yang dipilih
    if selectedTeamPreset then
        local presets = loadTeamPresets()
        local preset = presets[selectedTeamPreset]
        if preset then
            for _, uuid in ipairs(preset.pets) do
                teamUUIDs[uuid] = true
            end
        end
    end
    
    local petTypes = {}
    
    for petUUID, _ in pairs(inventory) do
        if not teamUUIDs[petUUID] then
            local petType = getPetType(petUUID)
            local petLevel = getPetLevel(petUUID)
            
            if petLevel < targetLevel then
                if not petTypes[petType] then
                    petTypes[petType] = {}
                end
                table.insert(petTypes[petType], {
                    UUID = petUUID,
                    Level = petLevel
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
            table.insert(allPetTypes, {
                PetType = petType,
                Instances = petInstances,
                Count = #petInstances,
                IsSelected = isSelected
            })
        end
    end
    
    table.sort(allPetTypes, function(a, b)
        if a.IsSelected ~= b.IsSelected then
            return a.IsSelected
        else
            return a.PetType < b.PetType
        end
    end)
    
    TargetListFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(#allPetTypes * 25, 50))
    
    for i, petInfo in ipairs(allPetTypes) do
        local PetButton = Instance.new("TextButton")
        PetButton.Size = UDim2.new(1, 0, 0, 22)
        PetButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
        PetButton.BorderSizePixel = 0
        PetButton.Font = Enum.Font.Gotham
        PetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        PetButton.TextSize = 10
        PetButton.Parent = TargetListFrame
        PetButton.LayoutOrder = i
        
        local UICornerTarget = Instance.new("UICorner")
        UICornerTarget.CornerRadius = UDim.new(0, 3)
        UICornerTarget.Parent = PetButton
        
        if petInfo.IsSelected then
            PetButton.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
            PetButton.Text = string.format("✓ %s (x%d)", petInfo.PetType, petInfo.Count)
        else
            PetButton.Text = string.format("%s (x%d)", petInfo.PetType, petInfo.Count)
        end
        
        PetButton.MouseButton1Click:Connect(function()
            local typeIndex = table.find(selectedPetTypes, petInfo.PetType)
            
            if typeIndex then
                table.remove(selectedPetTypes, typeIndex)
                
                for j = #queuedPets, 1, -1 do
                    if getPetType(queuedPets[j]) == petInfo.PetType then
                        table.remove(queuedPets, j)
                    end
                end
            else
                table.insert(selectedPetTypes, petInfo.PetType)
                
                for _, petInstance in ipairs(petInfo.Instances) do
                    if not table.find(queuedPets, petInstance.UUID) then
                        table.insert(queuedPets, petInstance.UUID)
                    end
                end
            end
            
            populateTargetDropdown()
        end)
    end
end

-- Save Preset Button
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
    
    saveTeamPreset(presetName, tempPresetPets)
    StatusLabel.Text = string.format("✅ Preset '%s' disimpan!", presetName)
    PresetNameInput.Text = ""
    tempPresetPets = {}
    populatePetList()
    populatePresetDropdown()
end)

-- Preset Dropdown toggle
PresetDropdownButton.MouseButton1Click:Connect(function()
    PresetListFrame.Visible = not PresetListFrame.Visible
    if PresetListFrame.Visible then
        populatePresetDropdown()
    end
end)

-- Search handlers
PetSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    petSearchText = PetSearchBox.Text
    populatePetList()
end)

TargetSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    targetSearchText = TargetSearchBox.Text
    populateTargetDropdown()
end)

-- Scan Button
ScanButton.MouseButton1Click:Connect(function()
    StatusLabel.Text = "Status: Scanning..."
    wait(0.1)
    populateTargetDropdown()
    StatusLabel.Text = "Status: Scan selesai!"
end)

-- Toggle Button - MAIN LOGIC
ToggleButton.MouseButton1Click:Connect(function()
    if isLeveling then
        isLeveling = false
        ToggleButton.Text = "▶️ Mulai"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
        StatusLabel.Text = "Status: Stopped"
        return
    end
    
    if not selectedTeamPreset then
        StatusLabel.Text = "Status: Pilih preset tim dulu!"
        return
    end
    
    if #queuedPets == 0 then
        StatusLabel.Text = "Status: Pilih pet target dulu!"
        return
    end
    
    -- Get team pets dari preset
    local presets = loadTeamPresets()
    local preset = presets[selectedTeamPreset]
    if not preset then
        StatusLabel.Text = "Status: Preset tidak ditemukan!"
        return
    end
    
    local teamPets = preset.pets
    
    isLeveling = true
    ToggleButton.Text = "⏹️ Stop"
    ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    StatusLabel.Text = "Status: Membersihkan slot..."
    
    spawn(function()
        -- UNEQUIP SEMUA
        local currentEquipped = getEquippedPets()
        for _, petUUID in ipairs(currentEquipped) do
            unequipPet(petUUID)
            wait(0.5)
        end
        
        wait(2)
        StatusLabel.Text = "✅ Slot bersih!"
        
        -- EQUIP TIM
        for _, petUUID in ipairs(teamPets) do
            equipPet(petUUID)
            wait(1)
        end
        
        wait(2)
        StatusLabel.Text = "✅ Tim di-equip!"
        
        -- EQUIP TARGET
        local availableSlots = MAX_PET_SLOTS - #teamPets
        local petsToEquip = math.min(availableSlots, #queuedPets)
        
        for i = 1, petsToEquip do
            if #queuedPets > 0 then
                local petUUID = queuedPets[1]
                local petLevel = getPetLevel(petUUID)
                
                if petLevel < targetLevel then
                    local success = equipPet(petUUID)
                    if success then
                        table.remove(queuedPets, 1)
                        table.insert(equippedTargetPets, petUUID)
                    end
                else
                    table.remove(queuedPets, 1)
                end
                
                wait(1)
            end
        end
        
        wait(2)
        StatusLabel.Text = "✅ Setup selesai!"
        
        -- MONITORING
        while isLeveling do
            for i = #equippedTargetPets, 1, -1 do
                local petUUID = equippedTargetPets[i]
                local petLevel = getPetLevel(petUUID)
                local petType = getPetType(petUUID)
                
                if petLevel >= targetLevel then
                    StatusLabel.Text = string.format("🎉 %s Lv.%d!", petType, targetLevel)
                    
                    unequipPet(petUUID)
                    table.remove(equippedTargetPets, i)
                    
                    wait(1)
                    
                    if #queuedPets > 0 then
                        local nextPetUUID = queuedPets[1]
                        local nextPetLevel = getPetLevel(nextPetUUID)
                        
                        if nextPetLevel < targetLevel then
                            equipPet(nextPetUUID)
                            table.remove(queuedPets, 1)
                            table.insert(equippedTargetPets, nextPetUUID)
                        else
                            table.remove(queuedPets, 1)
                        end
                        
                        wait(1)
                    end
                end
            end
            
            if #queuedPets == 0 and #equippedTargetPets == 0 then
                StatusLabel.Text = "🎉 Semua selesai!"
                isLeveling = false
                ToggleButton.Text = "▶️ Mulai"
                ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
                break
            end
            
            wait(5)
        end
    end)
end)

-- Initial setup
populatePetList()
populatePresetDropdown()

AutoLevelGUI.Parent = playerGui

print("✅ Auto Leveling System (Preset Based) loaded!")
