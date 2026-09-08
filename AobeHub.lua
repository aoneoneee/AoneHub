-- Auto Leveling System GUI (Fixed Nil Value)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Services
local DataService = require(ReplicatedStorage.Modules.DataService)

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
MainFrame.Size = UDim2.new(0, 300, 0, 450)
MainFrame.Position = UDim2.new(1, -320, 0.5, -225)
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
TitleText.Size = UDim2.new(0.7, 0, 1, 0)
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
        MainFrame.Size = UDim2.new(0, 300, 0, 40)
        ContentFrame.Visible = false
        MinimizeButton.Text = "+"
    else
        MainFrame.Size = UDim2.new(0, 300, 0, 450)
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
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 700)
ScrollFrame.Parent = ContentFrame

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 8)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Parent = ScrollFrame

-- Variables
local teamPets = {}
local targetPets = {}
local targetLevel = TARGET_LEVEL_DEFAULT
local isLeveling = false
local equippedPetsCount = 0

-- Create Section function
local function createSection(parent, title)
    local SectionFrame = Instance.new("Frame")
    SectionFrame.Size = UDim2.new(1, -10, 0, 150)
    SectionFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    SectionFrame.BorderSizePixel = 0
    SectionFrame.Parent = parent
    
    local UICornerSection = Instance.new("UICorner")
    UICornerSection.CornerRadius = UDim.new(0, 6)
    UICornerSection.Parent = SectionFrame
    
    local SectionTitle = Instance.new("TextLabel")
    SectionTitle.Size = UDim2.new(1, -20, 0, 25)
    SectionTitle.Position = UDim2.new(0, 10, 0, 3)
    SectionTitle.BackgroundTransparency = 1
    SectionTitle.Font = Enum.Font.GothamBold
    SectionTitle.Text = title
    SectionTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    SectionTitle.TextSize = 13
    SectionTitle.TextXAlignment = Enum.TextXAlignment.Left
    SectionTitle.Parent = SectionFrame
    
    return SectionFrame, SectionTitle
end

-- Create all sections first
local TeamSection, TeamTitleLabel = createSection(ScrollFrame, "👥 Tim Leveling")
TeamSection.LayoutOrder = 1
TeamSection.Size = UDim2.new(1, -10, 0, 180)

local LevelSection, LevelTitleLabel = createSection(ScrollFrame, "🎯 Target Level")
LevelSection.LayoutOrder = 2
LevelSection.Size = UDim2.new(1, -10, 0, 80)

local TargetSection, TargetTitleLabel = createSection(ScrollFrame, "🎯 Pet Target")
TargetSection.LayoutOrder = 3
TargetSection.Size = UDim2.new(1, -10, 0, 200)

local ButtonSection, ButtonTitleLabel = createSection(ScrollFrame, "⚙️ Kontrol")
ButtonSection.LayoutOrder = 4
ButtonSection.Size = UDim2.new(1, -10, 0, 120)

-- Team Pets Dropdown
local TeamDropdown = Instance.new("Frame")
TeamDropdown.Size = UDim2.new(1, -20, 0, 30)
TeamDropdown.Position = UDim2.new(0, 10, 0, 30)
TeamDropdown.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
TeamDropdown.BorderSizePixel = 0
TeamDropdown.Parent = TeamSection

local UICornerTeamDropdown = Instance.new("UICorner")
UICornerTeamDropdown.CornerRadius = UDim.new(0, 5)
UICornerTeamDropdown.Parent = TeamDropdown

local TeamDropdownButton = Instance.new("TextButton")
TeamDropdownButton.Size = UDim2.new(1, 0, 1, 0)
TeamDropdownButton.BackgroundTransparency = 1
TeamDropdownButton.Font = Enum.Font.Gotham
TeamDropdownButton.Text = "Pilih Pet Tim"
TeamDropdownButton.TextColor3 = Color3.fromRGB(200, 200, 200)
TeamDropdownButton.TextSize = 12
TeamDropdownButton.Parent = TeamDropdown

-- Team Pets List
local TeamListFrame = Instance.new("ScrollingFrame")
TeamListFrame.Size = UDim2.new(1, -20, 0, 120)
TeamListFrame.Position = UDim2.new(0, 10, 0, 65)
TeamListFrame.BackgroundTransparency = 1
TeamListFrame.BorderSizePixel = 0
TeamListFrame.ScrollBarThickness = 3
TeamListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
TeamListFrame.CanvasSize = UDim2.new(0, 0, 0, 100)
TeamListFrame.Visible = false
TeamListFrame.Parent = TeamSection

local TeamListLayout = Instance.new("UIListLayout")
TeamListLayout.Padding = UDim.new(0, 2)
TeamListLayout.Parent = TeamListFrame

-- Target Level Input
local LevelInput = Instance.new("TextBox")
LevelInput.Size = UDim2.new(1, -20, 0, 30)
LevelInput.Position = UDim2.new(0, 10, 0, 35)
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

-- Target Pets Dropdown
local TargetDropdown = Instance.new("Frame")
TargetDropdown.Size = UDim2.new(1, -20, 0, 30)
TargetDropdown.Position = UDim2.new(0, 10, 0, 30)
TargetDropdown.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
TargetDropdown.BorderSizePixel = 0
TargetDropdown.Parent = TargetSection

local UICornerTargetDropdown = Instance.new("UICorner")
UICornerTargetDropdown.CornerRadius = UDim.new(0, 5)
UICornerTargetDropdown.Parent = TargetDropdown

local TargetDropdownButton = Instance.new("TextButton")
TargetDropdownButton.Size = UDim2.new(1, 0, 1, 0)
TargetDropdownButton.BackgroundTransparency = 1
TargetDropdownButton.Font = Enum.Font.Gotham
TargetDropdownButton.Text = "Pilih Pet Target"
TargetDropdownButton.TextColor3 = Color3.fromRGB(200, 200, 200)
TargetDropdownButton.TextSize = 12
TargetDropdownButton.Parent = TargetDropdown

-- Target Pets List
local TargetListFrame = Instance.new("ScrollingFrame")
TargetListFrame.Size = UDim2.new(1, -20, 0, 140)
TargetListFrame.Position = UDim2.new(0, 10, 0, 65)
TargetListFrame.BackgroundTransparency = 1
TargetListFrame.BorderSizePixel = 0
TargetListFrame.ScrollBarThickness = 3
TargetListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
TargetListFrame.CanvasSize = UDim2.new(0, 0, 0, 120)
TargetListFrame.Visible = false
TargetListFrame.Parent = TargetSection

local TargetListLayout = Instance.new("UIListLayout")
TargetListLayout.Padding = UDim.new(0, 2)
TargetListLayout.Parent = TargetListFrame

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

local function getEquippedPetsCount()
    local petsData = getPlayerPetData()
    if not petsData then return 0 end
    
    local equippedPets = petsData.EquippedPets or {}
    return #equippedPets
end

local function clearDropdown(listFrame)
    for _, child in pairs(listFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
end

local function populateTeamDropdown()
    clearDropdown(TeamListFrame)
    
    local petsData = getPlayerPetData()
    if not petsData then return end
    
    local equippedPets = petsData.EquippedPets or {}
    equippedPetsCount = #equippedPets
    
    TeamListFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(#equippedPets * 25, 50))
    
    for _, petUUID in ipairs(equippedPets) do
        local petType = getPetType(petUUID)
        local petLevel = getPetLevel(petUUID)
        
        local PetButton = Instance.new("TextButton")
        PetButton.Size = UDim2.new(1, 0, 0, 22)
        PetButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
        PetButton.BorderSizePixel = 0
        PetButton.Font = Enum.Font.Gotham
        PetButton.Text = string.format("%s (Lv.%d)", petType, petLevel)
        PetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        PetButton.TextSize = 10
        PetButton.Parent = TeamListFrame
        
        local UICornerPet = Instance.new("UICorner")
        UICornerPet.CornerRadius = UDim.new(0, 3)
        UICornerPet.Parent = PetButton
        
        if table.find(teamPets, petUUID) then
            PetButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        end
        
        PetButton.MouseButton1Click:Connect(function()
            local teamIndex = table.find(teamPets, petUUID)
            if teamIndex then
                table.remove(teamPets, teamIndex)
                PetButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
            else
                table.insert(teamPets, petUUID)
                PetButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
            end
            updateSlotInfo()
        end)
    end
end

local function scanTargetPets()
    local petsData = getPlayerPetData()
    if not petsData then return {} end
    
    local inventory = petsData.PetInventory.Data or {}
    local equippedPets = petsData.EquippedPets or {}
    local petTypes = {}
    
    local equippedSet = {}
    for _, uuid in ipairs(equippedPets) do
        equippedSet[uuid] = true
    end
    
    for petUUID, petData in pairs(inventory) do
        if not equippedSet[petUUID] then
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

local function populateTargetDropdown()
    clearDropdown(TargetListFrame)
    
    local petTypes = scanTargetPets()
    
    local totalCount = 0
    for _ in pairs(petTypes) do
        totalCount = totalCount + 1
    end
    
    TargetListFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(totalCount * 25, 50))
    
    for petType, petInstances in pairs(petTypes) do
        local firstPet = petInstances[1]
        
        local PetButton = Instance.new("TextButton")
        PetButton.Size = UDim2.new(1, 0, 0, 22)
        PetButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
        PetButton.BorderSizePixel = 0
        PetButton.Font = Enum.Font.Gotham
        PetButton.Text = string.format("%s (x%d) - Lv.%d", petType, #petInstances, firstPet.Level)
        PetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        PetButton.TextSize = 10
        PetButton.Parent = TargetListFrame
        
        local UICornerTarget = Instance.new("UICorner")
        UICornerTarget.CornerRadius = UDim.new(0, 3)
        UICornerTarget.Parent = PetButton
        
        local isSelected = false
        for _, targetUUID in ipairs(targetPets) do
            if getPetType(targetUUID) == petType then
                isSelected = true
                break
            end
        end
        
        if isSelected then
            PetButton.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
        end
        
        PetButton.MouseButton1Click:Connect(function()
            local availableSlots = MAX_PET_SLOTS - equippedPetsCount
            
            local selectedCount = 0
            for _, targetUUID in ipairs(targetPets) do
                if getPetType(targetUUID) == petType then
                    selectedCount = selectedCount + 1
                end
            end
            
            if selectedCount > 0 then
                for i = #targetPets, 1, -1 do
                    if getPetType(targetPets[i]) == petType then
                        table.remove(targetPets, i)
                    end
                end
                PetButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
            else
                for _, petInstance in ipairs(petInstances) do
                    if #targetPets < availableSlots then
                        if not table.find(targetPets, petInstance.UUID) then
                            table.insert(targetPets, petInstance.UUID)
                        end
                    else
                        break
                    end
                end
                PetButton.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
            end
            updateSlotInfo()
        end)
    end
end

local function updateSlotInfo()
    equippedPetsCount = getEquippedPetsCount()
    
    local availableSlots = math.max(MAX_PET_SLOTS - equippedPetsCount, 0)
    
    if TeamTitleLabel then
        TeamTitleLabel.Text = string.format(
            "👥 Tim Leveling (Equipped: %d/%d)", 
            equippedPetsCount, 
            MAX_PET_SLOTS
        )
    end
    
    if TargetTitleLabel then
        TargetTitleLabel.Text = string.format(
            "🎯 Pet Target (Sisa Slot: %d)", 
            math.max(availableSlots - #targetPets, 0)
        )
    end
    
    if StatusLabel then
        StatusLabel.Text = string.format(
            "Equipped: %d | Target: %d | Sisa: %d",
            equippedPetsCount,
            #targetPets,
            math.max(availableSlots - #targetPets, 0)
        )
    end
end

-- Dropdown toggle handlers
TeamDropdownButton.MouseButton1Click:Connect(function()
    TeamListFrame.Visible = not TeamListFrame.Visible
    if TeamListFrame.Visible then
        populateTeamDropdown()
    end
end)

TargetDropdownButton.MouseButton1Click:Connect(function()
    TargetListFrame.Visible = not TargetListFrame.Visible
    if TargetListFrame.Visible then
        populateTargetDropdown()
    end
end)

-- Scan Button
ScanButton.MouseButton1Click:Connect(function()
    StatusLabel.Text = "Status: Scanning..."
    wait(0.1)
    populateTargetDropdown()
    StatusLabel.Text = "Status: Scan selesai!"
end)

-- Toggle Button
ToggleButton.MouseButton1Click:Connect(function()
    if isLeveling then
        isLeveling = false
        ToggleButton.Text = "▶️ Mulai"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
        StatusLabel.Text = "Status: Stopped"
        return
    end
    
    if #targetPets == 0 then
        StatusLabel.Text = "Status: Pilih pet target!"
        return
    end
    
    isLeveling = true
    ToggleButton.Text = "⏹️ Stop"
    ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    StatusLabel.Text = "Status: Leveling..."
    
    spawn(function()
        while isLeveling do
            local allComplete = true
            
            for i = #targetPets, 1, -1 do
                local petUUID = targetPets[i]
                local petLevel = getPetLevel(petUUID)
                local petType = getPetType(petUUID)
                
                if petLevel >= targetLevel then
                    table.remove(targetPets, i)
                    StatusLabel.Text = string.format("✅ %s Lv.%d!", petType, targetLevel)
                else
                    allComplete = false
                end
            end
            
            if allComplete then
                StatusLabel.Text = "🎉 Semua selesai!"
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

-- Initial setup (panggil setelah semua UI dibuat)
updateSlotInfo()

-- Add GUI to PlayerGui
AutoLevelGUI.Parent = playerGui

print("✅ Auto Leveling System GUI loaded!")
