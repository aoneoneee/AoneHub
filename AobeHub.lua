-- Auto Leveling System GUI (Full Featured)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Services
local DataService = require(ReplicatedStorage.Modules.DataService)
local PetsService = require(ReplicatedStorage.Modules.PetServices.PetsService)

-- Constants
local MAX_PET_SLOTS = 8
local TARGET_LEVEL_DEFAULT = 100

-- Main GUI
local AutoLevelGUI = Instance.new("ScreenGui")
AutoLevelGUI.Name = "AutoLevelGUI"
AutoLevelGUI.ResetOnSpawn = false
AutoLevelGUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 350, 0, 500)
MainFrame.Position = UDim2.new(1, -370, 0.5, -250)
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
        MainFrame.Size = UDim2.new(0, 350, 0, 500)
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
local teamPets = {} -- Pet tim yang dipilih (UUID list)
local selectedPetTypes = {} -- Pet type yang dipilih untuk target
local queuedPets = {} -- Antrian semua pet target
local equippedTargetPets = {} -- Pet target yang sedang di-equip
local targetLevel = TARGET_LEVEL_DEFAULT
local isLeveling = false
local equippedPetsCount = 0
local teamSearchText = ""
local targetSearchText = ""

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

-- Create all sections
local TeamSection, TeamTitleLabel = createSection(ScrollFrame, "👥 Tim Leveling")
TeamSection.LayoutOrder = 1
TeamSection.Size = UDim2.new(1, -10, 0, 200)

local LevelSection, LevelTitleLabel = createSection(ScrollFrame, "🎯 Target Level")
LevelSection.LayoutOrder = 2
LevelSection.Size = UDim2.new(1, -10, 0, 70)

local TargetSection, TargetTitleLabel = createSection(ScrollFrame, "🎯 Pet Target")
TargetSection.LayoutOrder = 3
TargetSection.Size = UDim2.new(1, -10, 0, 200)

local ButtonSection, ButtonTitleLabel = createSection(ScrollFrame, "⚙️ Kontrol")
ButtonSection.LayoutOrder = 4
ButtonSection.Size = UDim2.new(1, -10, 0, 120)

-- ============ TEAM SECTION ============
-- Search Bar Team
local TeamSearchBox = Instance.new("TextBox")
TeamSearchBox.Size = UDim2.new(1, -20, 0, 25)
TeamSearchBox.Position = UDim2.new(0, 10, 0, 32)
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
TeamListFrame.Size = UDim2.new(1, -20, 0, 140)
TeamListFrame.Position = UDim2.new(0, 10, 0, 60)
TeamListFrame.BackgroundTransparency = 1
TeamListFrame.BorderSizePixel = 0
TeamListFrame.ScrollBarThickness = 3
TeamListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
TeamListFrame.CanvasSize = UDim2.new(0, 0, 0, 100)
TeamListFrame.Parent = TeamSection

local TeamListLayout = Instance.new("UIListLayout")
TeamListLayout.Padding = UDim.new(0, 3)
TeamListLayout.SortOrder = Enum.SortOrder.LayoutOrder
TeamListLayout.Parent = TeamListFrame

-- ============ TARGET LEVEL SECTION ============
local LevelInput = Instance.new("TextBox")
LevelInput.Size = UDim2.new(1, -20, 0, 30)
LevelInput.Position = UDim2.new(0, 10, 0, 32)
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
-- Search Bar Target
local TargetSearchBox = Instance.new("TextBox")
TargetSearchBox.Size = UDim2.new(1, -20, 0, 25)
TargetSearchBox.Position = UDim2.new(0, 10, 0, 32)
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
TargetListFrame.Size = UDim2.new(1, -20, 0, 140)
TargetListFrame.Position = UDim2.new(0, 10, 0, 60)
TargetListFrame.BackgroundTransparency = 1
TargetListFrame.BorderSizePixel = 0
TargetListFrame.ScrollBarThickness = 3
TargetListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
TargetListFrame.CanvasSize = UDim2.new(0, 0, 0, 100)
TargetListFrame.Parent = TargetSection

local TargetListLayout = Instance.new("UIListLayout")
TargetListLayout.Padding = UDim.new(0, 3)
TargetListLayout.SortOrder = Enum.SortOrder.LayoutOrder
TargetListLayout.Parent = TargetListFrame

-- ============ BUTTON SECTION ============
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

-- Populate Team Dropdown (dengan search dan selected di atas)
local function populateTeamDropdown()
    clearDropdown(TeamListFrame)
    
    local petsData = getPlayerPetData()
    if not petsData then return end
    
    local inventory = petsData.PetInventory.Data or {}
    local equippedPets = getEquippedPets()
    
    -- Buat list pet dengan status
    local allPets = {}
    for petUUID, _ in pairs(inventory) do
        local petType = getPetType(petUUID)
        local petLevel = getPetLevel(petUUID)
        local isEquipped = table.find(equippedPets, petUUID) ~= nil
        local isSelected = table.find(teamPets, petUUID) ~= nil
        
        -- Filter by search text
        if teamSearchText == "" or petType:lower():find(teamSearchText:lower()) then
            table.insert(allPets, {
                UUID = petUUID,
                PetType = petType,
                Level = petLevel,
                IsEquipped = isEquipped,
                IsSelected = isSelected
            })
        end
    end
    
    -- Sort: Selected di atas, lalu equipped, lalu lainnya
    table.sort(allPets, function(a, b)
        if a.IsSelected ~= b.IsSelected then
            return a.IsSelected -- Selected dulu
        elseif a.IsEquipped ~= b.IsEquipped then
            return a.IsEquipped -- Equipped kedua
        else
            return a.PetType < b.PetType -- Alphabetical
        end
    end)
    
    -- Update canvas size
    TeamListFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(#allPets * 28, 50))
    
    -- Create buttons
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
        
        -- Set warna berdasarkan status
        if petInfo.IsSelected then
            PetButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50) -- Hijau untuk selected
            PetButton.Text = string.format("✓ %s (Lv.%d) [Tim]", petInfo.PetType, petInfo.Level)
        elseif petInfo.IsEquipped then
            PetButton.BackgroundColor3 = Color3.fromRGB(100, 100, 120) -- Abu untuk equipped
            PetButton.Text = string.format("%s (Lv.%d) [Equipped]", petInfo.PetType, petInfo.Level)
        else
            PetButton.Text = string.format("%s (Lv.%d)", petInfo.PetType, petInfo.Level)
        end
        
        PetButton.MouseButton1Click:Connect(function()
            local teamIndex = table.find(teamPets, petInfo.UUID)
            if teamIndex then
                -- Hapus dari tim
                table.remove(teamPets, teamIndex)
                PetButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
                StatusLabel.Text = string.format("❌ %s dihapus dari tim", petInfo.PetType)
            else
                -- Tambahkan ke tim
                if #teamPets < MAX_PET_SLOTS then
                    table.insert(teamPets, petInfo.UUID)
                    PetButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
                    StatusLabel.Text = string.format("✅ %s ditambahkan ke tim", petInfo.PetType)
                else
                    StatusLabel.Text = "⚠️ Slot tim penuh!"
                end
            end
            
            -- Refresh dropdown
            wait(0.1)
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
    
    -- Kumpulkan semua pet yang bukan tim dan di bawah target level
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

-- Populate Target Dropdown (dengan search dan selected di atas)
local function populateTargetDropdown()
    clearDropdown(TargetListFrame)
    
    local petTypes = scanTargetPets()
    local allPetTypes = {}
    
    -- Convert ke array untuk sorting
    for petType, petInstances in pairs(petTypes) do
        -- Filter by search text
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
    
    -- Sort: Selected di atas, lalu alphabetical
    table.sort(allPetTypes, function(a, b)
        if a.IsSelected ~= b.IsSelected then
            return a.IsSelected
        else
            return a.PetType < b.PetType
        end
    end)
    
    -- Update canvas size
    TargetListFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(#allPetTypes * 28, 50))
    
    -- Create buttons
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
            PetButton.BackgroundColor3 = Color3.fromRGB(200, 150, 50) -- Orange untuk selected
            PetButton.Text = string.format("✓ %s (x%d)", petInfo.PetType, petInfo.Count)
        else
            PetButton.Text = string.format("%s (x%d)", petInfo.PetType, petInfo.Count)
        end
        
        PetButton.MouseButton1Click:Connect(function()
            local typeIndex = table.find(selectedPetTypes, petInfo.PetType)
            
            if typeIndex then
                -- Remove dari selected
                table.remove(selectedPetTypes, typeIndex)
                PetButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
                
                -- Remove dari queue
                for j = #queuedPets, 1, -1 do
                    if getPetType(queuedPets[j]) == petInfo.PetType then
                        table.remove(queuedPets, j)
                    end
                end
                
                StatusLabel.Text = string.format("❌ %s dihapus dari target", petInfo.PetType)
            else
                -- Tambahkan ke selected
                table.insert(selectedPetTypes, petInfo.PetType)
                PetButton.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
                
                -- Tambahkan semua instance ke queue
                for _, petInstance in ipairs(petInfo.Instances) do
                    if not table.find(queuedPets, petInstance.UUID) then
                        table.insert(queuedPets, petInstance.UUID)
                    end
                end
                
                StatusLabel.Text = string.format("✅ %s (x%d) ditambahkan ke target", petInfo.PetType, petInfo.Count)
            end
            
            -- Refresh dropdown
            wait(0.1)
            populateTargetDropdown()
            updateSlotInfo()
        end)
    end
end

local function updateSlotInfo()
    equippedPetsCount = getEquippedPetsCount()
    
    local availableSlots = math.max(MAX_PET_SLOTS - equippedPetsCount, 0)
    
    if TeamTitleLabel then
        TeamTitleLabel.Text = string.format(
            "👥 Tim Leveling (Dipilih: %d)", 
            #teamPets
        )
    end
    
    if TargetTitleLabel then
        TargetTitleLabel.Text = string.format(
            "🎯 Pet Target (Dipilih: %d tipe, Antrian: %d)", 
            #selectedPetTypes,
            #queuedPets
        )
    end
    
    if StatusLabel then
        StatusLabel.Text = string.format(
            "Tim: %d | Target: %d | Antrian: %d | Equipped: %d/%d",
            #teamPets,
            #selectedPetTypes,
            #queuedPets,
            equippedPetsCount,
            MAX_PET_SLOTS
        )
    end
end

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
        -- Stop leveling
        isLeveling = false
        ToggleButton.Text = "▶️ Mulai"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
        StatusLabel.Text = "Status: Stopped"
        return
    end
    
    -- Start leveling
    if #queuedPets == 0 then
        StatusLabel.Text = "Status: Pilih pet target dulu!"
        return
    end
    
    if #teamPets == 0 then
        StatusLabel.Text = "Status: Pilih minimal 1 pet tim!"
        return
    end
    
    isLeveling = true
    ToggleButton.Text = "⏹️ Stop"
    ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    StatusLabel.Text = "Status: Membersihkan slot..."
    
    -- Auto Leveling Loop
    spawn(function()
        -- LANGKAH 1: UNEQUIP SEMUA
        StatusLabel.Text = "🔄 Membersihkan semua slot..."
        
        local currentEquipped = getEquippedPets()
        for _, petUUID in ipairs(currentEquipped) do
            local petType = getPetType(petUUID)
            unequipPet(petUUID)
            StatusLabel.Text = string.format("❌ Unequip %s...", petType)
            wait(0.5)
        end
        
        wait(2)
        StatusLabel.Text = "✅ Semua slot bersih!"
        
        -- LANGKAH 2: EQUIP TIM
        StatusLabel.Text = "🔄 Meng-equip pet tim..."
        
        local teamEquippedCount = 0
        for _, petUUID in ipairs(teamPets) do
            local petType = getPetType(petUUID)
            
            StatusLabel.Text = string.format("Meng-equip tim: %s...", petType)
            
            local success = equipPet(petUUID)
            if success then
                teamEquippedCount = teamEquippedCount + 1
                StatusLabel.Text = string.format("✅ Tim %s di-equip!", petType)
            else
                StatusLabel.Text = string.format("❌ Gagal equip tim %s", petType)
            end
            
            wait(1)
        end
        
        wait(2)
        StatusLabel.Text = string.format("✅ %d pet tim di-equip!", teamEquippedCount)
        
        -- LANGKAH 3: EQUIP TARGET
        local availableSlots = MAX_PET_SLOTS - teamEquippedCount
        
        StatusLabel.Text = string.format(
            "Sisa slot: %d | Antrian: %d",
            availableSlots,
            #queuedPets
        )
        
        local petsToEquip = math.min(availableSlots, #queuedPets)
        
        for i = 1, petsToEquip do
            if #queuedPets > 0 then
                local petUUID = queuedPets[1]
                local petType = getPetType(petUUID)
                local petLevel = getPetLevel(petUUID)
                
                if petLevel < targetLevel then
                    StatusLabel.Text = string.format(
                        "Meng-equip target: %s (Lv.%d)...",
                        petType,
                        petLevel
                    )
                    
                    local success = equipPet(petUUID)
                    if success then
                        table.remove(queuedPets, 1)
                        table.insert(equippedTargetPets, petUUID)
                        StatusLabel.Text = string.format(
                            "✅ Target %s di-equip! (Antrian: %d)",
                            petType,
                            #queuedPets
                        )
                    else
                        StatusLabel.Text = string.format("❌ Gagal equip target %s", petType)
                    end
                else
                    table.remove(queuedPets, 1)
                    StatusLabel.Text = string.format("⏭️ %s sudah Lv.%d, skip", petType, petLevel)
                end
                
                wait(1)
            end
        end
        
        wait(2)
        StatusLabel.Text = string.format(
            "✅ Setup selesai! Tim: %d | Target: %d | Antrian: %d",
            teamEquippedCount,
            #equippedTargetPets,
            #queuedPets
        )
        
        -- LANGKAH 4: MONITORING LOOP
        while isLeveling do
            equippedPetsCount = getEquippedPetsCount()
            
            -- Cek equipped target pets
            for i = #equippedTargetPets, 1, -1 do
                local petUUID = equippedTargetPets[i]
                local petLevel = getPetLevel(petUUID)
                local petType = getPetType(petUUID)
                
                if petLevel >= targetLevel then
                    StatusLabel.Text = string.format("🎉 %s mencapai Lv.%d!", petType, targetLevel)
                    
                    unequipPet(petUUID)
                    table.remove(equippedTargetPets, i)
                    
                    wait(1)
                    equippedPetsCount = getEquippedPetsCount()
                    
                    -- Isi slot kosong dari antrian
                    if #queuedPets > 0 then
                        local nextPetUUID = queuedPets[1]
                        local nextPetType = getPetType(nextPetUUID)
                        local nextPetLevel = getPetLevel(nextPetUUID)
                        
                        if nextPetLevel < targetLevel then
                            StatusLabel.Text = string.format(
                                "Meng-equip %s (Lv.%d)...",
                                nextPetType,
                                nextPetLevel
                            )
                            
                            local success = equipPet(nextPetUUID)
                            if success then
                                table.remove(queuedPets, 1)
                                table.insert(equippedTargetPets, nextPetUUID)
                                StatusLabel.Text = string.format(
                                    "✅ %s di-equip! (Antrian: %d)",
                                    nextPetType,
                                    #queuedPets
                                )
                            end
                        else
                            table.remove(queuedPets, 1)
                        end
                        
                        wait(1)
                    end
                end
            end
            
            -- Cek jika semua selesai
            if #queuedPets == 0 and #equippedTargetPets == 0 then
                StatusLabel.Text = "🎉 Semua pet target selesai leveling!"
                isLeveling = false
                ToggleButton.Text = "▶️ Mulai"
                ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
                updateSlotInfo()
                break
            end
            
            updateSlotInfo()
            wait(5)
        end
    end)
end)

-- Initial setup
populateTeamDropdown()
updateSlotInfo()

-- Add GUI to PlayerGui
AutoLevelGUI.Parent = playerGui

print("✅ Auto Leveling System GUI loaded!")
