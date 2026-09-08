-- Auto Leveling System GUI (Dengan Save/Load Tim)
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

-- Save/Load Tim System
local function saveTeamPreset(presetName, petList)
    local saveData = {
        presets = {}
    }
    
    -- Load existing data
    local existingData = readfile("AutoLevel_Presets.json")
    if existingData then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(existingData)
        end)
        if success and decoded and decoded.presets then
            saveData = decoded
        end
    end
    
    -- Add/Update preset
    saveData.presets[presetName] = {
        name = presetName,
        pets = petList,
        savedAt = os.time()
    }
    
    -- Save
    writefile("AutoLevel_Presets.json", HttpService:JSONEncode(saveData))
end

local function loadTeamPresets()
    local success, data = pcall(function()
        return readfile("AutoLevel_Presets.json")
    end)
    
    if success and data then
        local decoded = HttpService:JSONDecode(data)
        return decoded.presets or {}
    end
    return {}
end

local function deleteTeamPreset(presetName)
    local presets = loadTeamPresets()
    presets[presetName] = nil
    
    writefile("AutoLevel_Presets.json", HttpService:JSONEncode({presets = presets}))
end

-- Main GUI
local AutoLevelGUI = Instance.new("ScreenGui")
AutoLevelGUI.Name = "AutoLevelGUI"
AutoLevelGUI.ResetOnSpawn = false
AutoLevelGUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 380, 0, 550)
MainFrame.Position = UDim2.new(1, -400, 0.5, -275)
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
        MainFrame.Size = UDim2.new(0, 380, 0, 40)
        ContentFrame.Visible = false
        MinimizeButton.Text = "+"
    else
        MainFrame.Size = UDim2.new(0, 380, 0, 550)
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
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 900)
ScrollFrame.Parent = ContentFrame

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 8)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Parent = ScrollFrame

-- Variables
local teamPets = {} -- Pet tim yang dipilih (UUID list)
local selectedPetTypes = {} -- Pet type yang dipilih untuk target
local queuedPets = {} -- Antrian semua pet target
local equippedTargetPets = {} -- Pet target yang sedang di-equip
local targetLevel = TARGET_LEVEL_DEFAULT
local isLeveling = false
local equippedPetsCount = 0
local teamSearchText = ""
local targetSearchText = ""
local currentPresetName = ""

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

-- ============ PRESET SECTION ============
local PresetSection, PresetTitleLabel = createSection(ScrollFrame, "💾 Preset Tim")
PresetSection.LayoutOrder = 1
PresetSection.Size = UDim2.new(1, -10, 0, 120)

-- Preset Name Input
local PresetNameInput = Instance.new("TextBox")
PresetNameInput.Size = UDim2.new(0.6, -10, 0, 28)
PresetNameInput.Position = UDim2.new(0, 10, 0, 30)
PresetNameInput.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
PresetNameInput.BorderSizePixel = 0
PresetNameInput.Font = Enum.Font.Gotham
PresetNameInput.PlaceholderText = "Nama tim..."
PresetNameInput.Text = ""
PresetNameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
PresetNameInput.TextSize = 11
PresetNameInput.Parent = PresetSection

local UICornerPresetName = Instance.new("UICorner")
UICornerPresetName.CornerRadius = UDim.new(0, 4)
UICornerPresetName.Parent = PresetNameInput

-- Save Button
local SavePresetButton = Instance.new("TextButton")
SavePresetButton.Size = UDim2.new(0.35, -10, 0, 28)
SavePresetButton.Position = UDim2.new(0.62, 5, 0, 30)
SavePresetButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
SavePresetButton.BorderSizePixel = 0
SavePresetButton.Font = Enum.Font.GothamBold
SavePresetButton.Text = "💾 Simpan"
SavePresetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
SavePresetButton.TextSize = 11
SavePresetButton.Parent = PresetSection

local UICornerSave = Instance.new("UICorner")
UICornerSave.CornerRadius = UDim.new(0, 4)
UICornerSave.Parent = SavePresetButton

-- Preset Dropdown
local PresetDropdown = Instance.new("Frame")
PresetDropdown.Size = UDim2.new(1, -20, 0, 30)
PresetDropdown.Position = UDim2.new(0, 10, 0, 65)
PresetDropdown.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
PresetDropdown.BorderSizePixel = 0
PresetDropdown.Parent = PresetSection

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
PresetListFrame.Position = UDim2.new(0, 10, 0, 100)
PresetListFrame.BackgroundTransparency = 1
PresetListFrame.BorderSizePixel = 0
PresetListFrame.ScrollBarThickness = 3
PresetListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
PresetListFrame.CanvasSize = UDim2.new(0, 0, 0, 80)
PresetListFrame.Visible = false
PresetListFrame.Parent = PresetSection

local PresetListLayout = Instance.new("UIListLayout")
PresetListLayout.Padding = UDim.new(0, 3)
PresetListLayout.Parent = PresetListFrame

-- ============ TEAM SECTION ============
local TeamSection, TeamTitleLabel = createSection(ScrollFrame, "👥 Tim Leveling")
TeamSection.LayoutOrder = 2
TeamSection.Size = UDim2.new(1, -10, 0, 180)

-- Search Bar Team
local TeamSearchBox = Instance.new("TextBox")
TeamSearchBox.Size = UDim2.new(1, -20, 0, 25)
TeamSearchBox.Position = UDim2.new(0, 10, 0, 30)
TeamSearchBox.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
TeamSearchBox.BorderSizePixel = 0
TeamSearchBox.Font = Enum.Font.Gotham
TeamSearchBox.PlaceholderText = "🔍 Cari pet tim..."
TeamSearchBox.Text = ""
TeamSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TeamSearchBox.TextSize = 11
TeamSearchBox.Parent = TeamSection

local UICornerTeamSearch = Instance.new("UICorner")
UICornerTeamSearch.CornerRadius = UDim.new(0, 4)
UICornerTeamSearch.Parent = TeamSearchBox

-- Team Pets List
local TeamListFrame = Instance.new("ScrollingFrame")
TeamListFrame.Size = UDim2.new(1, -20, 0, 120)
TeamListFrame.Position = UDim2.new(0, 10, 0, 58)
TeamListFrame.BackgroundTransparency = 1
TeamListFrame.BorderSizePixel = 0
TeamListFrame.ScrollBarThickness = 3
TeamListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
TeamListFrame.CanvasSize = UDim2.new(0, 0, 0, 100)
TeamListFrame.Parent = TeamSection

local TeamListLayout = Instance.new("UIListLayout")
TeamListLayout.Padding = UDim.new(0, 3)
TeamListLayout.Parent = TeamListFrame

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

-- Search Bar Target
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

-- Target Pets List
local TargetListFrame = Instance.new("ScrollingFrame")
TargetListFrame.Size = UDim2.new(1, -20, 0, 120)
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

-- ============ BUTTON SECTION ============
local ButtonSection, ButtonTitleLabel = createSection(ScrollFrame, "⚙️ Kontrol")
ButtonSection.LayoutOrder = 5
ButtonSection.Size = UDim2.new(1, -10, 0, 120)

-- Scan Button
local ScanButton = Instance.new("TextButton")
ScanButton.Size = UDim2.new(1, -20, 0, 30)
ScanButton.Position = UDim2.new(0, 10, 0, 30)
ScanButton.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
ScanButton.BorderSizePixel = 0
ScanButton.Font = Enum.Font.GothamBold
ScanButton.Text = "🔍 Scan Pet Target"
ScanButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ScanButton.TextSize = 12
ScanButton.Parent = ButtonSection

local UICornerScan = Instance.new("UICorner")
UICornerScan.CornerRadius = UDim.new(0, 5)
UICornerScan.Parent = ScanButton

-- Toggle Button
local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(1, -20, 0, 30)
ToggleButton.Position = UDim2.new(0, 10, 0, 65)
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

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 20)
StatusLabel.Position = UDim2.new(0, 10, 0, 100)
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

local function getEquippedPetsCount()
    return #getEquippedPets()
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

local function updateSlotInfo()
    if TeamTitleLabel then
        TeamTitleLabel.Text = string.format(
            "👥 Tim Leveling (Dipilih: %d%s)", 
            #teamPets,
            currentPresetName ~= "" and " - " .. currentPresetName or ""
        )
    end
    
    if TargetTitleLabel then
        TargetTitleLabel.Text = string.format(
            "🎯 Pet Target (Tipe: %d, Antrian: %d)", 
            #selectedPetTypes,
            #queuedPets
        )
    end
    
    if StatusLabel then
        StatusLabel.Text = string.format(
            "Tim: %d | Target: %d | Antrian: %d",
            #teamPets,
            #selectedPetTypes,
            #queuedPets
        )
    end
end

-- Populate Preset Dropdown
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
        
        -- Load button
        PresetButton.MouseButton1Click:Connect(function()
            teamPets = {}
            for _, petUUID in ipairs(preset.pets) do
                table.insert(teamPets, petUUID)
            end
            currentPresetName = presetName
            StatusLabel.Text = string.format("✅ Preset '%s' dimuat!", presetName)
            populateTeamDropdown()
            updateSlotInfo()
        end)
        
        -- Delete button (right-click)
        PresetButton.MouseButton2Click:Connect(function()
            deleteTeamPreset(presetName)
            StatusLabel.Text = string.format("🗑️ Preset '%s' dihapus!", presetName)
            populatePresetDropdown()
        end)
    end
end

-- Populate Team Dropdown
local function populateTeamDropdown()
    clearDropdown(TeamListFrame)
    
    local petsData = getPlayerPetData()
    if not petsData then return end
    
    local inventory = petsData.PetInventory.Data or {}
    local allPets = {}
    
    for petUUID, _ in pairs(inventory) do
        local petType = getPetType(petUUID)
        local petLevel = getPetLevel(petUUID)
        local isSelected = table.find(teamPets, petUUID) ~= nil
        
        if teamSearchText == "" or petType:lower():find(teamSearchText:lower()) then
            table.insert(allPets, {
                UUID = petUUID,
                PetType = petType,
                Level = petLevel,
                IsSelected = isSelected
            })
        end
    end
    
    -- Sort: Selected di atas
    table.sort(allPets, function(a, b)
        if a.IsSelected ~= b.IsSelected then
            return a.IsSelected
        else
            return a.PetType < b.PetType
        end
    end)
    
    TeamListFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(#allPets * 28, 50))
    
    for i, petInfo in ipairs(allPets) do
        local PetButton = Instance.new("TextButton")
        PetButton.Size = UDim2.new(1, 0, 0, 25)
        PetButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
        PetButton.BorderSizePixel = 0
        PetButton.Font = Enum.Font.Gotham
        PetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        PetButton.TextSize = 10
        PetButton.Parent = TeamListFrame
        PetButton.LayoutOrder = i
        
        local UICornerPet = Instance.new("UICorner")
        UICornerPet.CornerRadius = UDim.new(0, 4)
        UICornerPet.Parent = PetButton
        
        if petInfo.IsSelected then
            PetButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
            PetButton.Text = string.format("✓ %s (Lv.%d)", petInfo.PetType, petInfo.Level)
        else
            PetButton.Text = string.format("%s (Lv.%d)", petInfo.PetType, petInfo.Level)
        end
        
        PetButton.MouseButton1Click:Connect(function()
            local teamIndex = table.find(teamPets, petInfo.UUID)
            if teamIndex then
                table.remove(teamPets, teamIndex)
                StatusLabel.Text = string.format("❌ %s dihapus dari tim", petInfo.PetType)
            else
                if #teamPets < MAX_PET_SLOTS then
                    table.insert(teamPets, petInfo.UUID)
                    StatusLabel.Text = string.format("✅ %s ditambahkan ke tim", petInfo.PetType)
                else
                    StatusLabel.Text = "⚠️ Slot tim penuh!"
                end
            end
            
            populateTeamDropdown()
            updateSlotInfo()
        end)
    end
end

-- Scan target pets
local function scanTargetPets()
    local petsData = getPlayerPetData()
    if not petsData then return {} end
    
    local inventory = petsData.PetInventory.Data or {}
    local petTypes = {}
    
    for petUUID, _ in pairs(inventory) do
        if not table.find(teamPets, petUUID) then
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
    
    TargetListFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(#allPetTypes * 28, 50))
    
    for i, petInfo in ipairs(allPetTypes) do
        local PetButton = Instance.new("TextButton")
        PetButton.Size = UDim2.new(1, 0, 0, 25)
        PetButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
        PetButton.BorderSizePixel = 0
        PetButton.Font = Enum.Font.Gotham
        PetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        PetButton.TextSize = 10
        PetButton.Parent = TargetListFrame
        PetButton.LayoutOrder = i
        
        local UICornerTarget = Instance.new("UICorner")
        UICornerTarget.CornerRadius = UDim.new(0, 4)
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
                
                StatusLabel.Text = string.format("❌ %s dihapus dari target", petInfo.PetType)
            else
                table.insert(selectedPetTypes, petInfo.PetType)
                
                for _, petInstance in ipairs(petInfo.Instances) do
                    if not table.find(queuedPets, petInstance.UUID) then
                        table.insert(queuedPets, petInstance.UUID)
                    end
                end
                
                StatusLabel.Text = string.format("✅ %s (x%d) ditambahkan", petInfo.PetType, petInfo.Count)
            end
            
            populateTargetDropdown()
            updateSlotInfo()
        end)
    end
end

-- Save Preset
SavePresetButton.MouseButton1Click:Connect(function()
    local presetName = PresetNameInput.Text
    
    if presetName == "" then
        StatusLabel.Text = "⚠️ Masukkan nama tim dulu!"
        return
    end
    
    if #teamPets == 0 then
        StatusLabel.Text = "⚠️ Pilih pet tim dulu!"
        return
    end
    
    saveTeamPreset(presetName, teamPets)
    currentPresetName = presetName
    StatusLabel.Text = string.format("✅ Tim '%s' disimpan!", presetName)
    PresetNameInput.Text = ""
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
TeamSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    teamSearchText = TeamSearchBox.Text
    populateTeamDropdown()
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
    
    if #queuedPets == 0 then
        StatusLabel.Text = "Status: Pilih pet target dulu!"
        return
    end
    
    if #teamPets == 0 then
        StatusLabel.Text = "Status: Pilih tim dulu!"
        return
    end
    
    isLeveling = true
    ToggleButton.Text = "⏹️ Stop"
    ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    StatusLabel.Text = "Status: Membersihkan slot..."
    
    spawn(function()
        -- LANGKAH 1: UNEQUIP SEMUA
        local currentEquipped = getEquippedPets()
        for _, petUUID in ipairs(currentEquipped) do
            unequipPet(petUUID)
            wait(0.5)
        end
        
        wait(2)
        StatusLabel.Text = "✅ Slot bersih!"
        
        -- LANGKAH 2: EQUIP TIM
        for _, petUUID in ipairs(teamPets) do
            equipPet(petUUID)
            wait(1)
        end
        
        wait(2)
        StatusLabel.Text = "✅ Tim di-equip!"
        
        -- LANGKAH 3: EQUIP TARGET
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
        
        -- LANGKAH 4: MONITORING
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
populateTeamDropdown()
populatePresetDropdown()
updateSlotInfo()

AutoLevelGUI.Parent = playerGui

print("✅ Auto Leveling System dengan Preset Tim loaded!")
