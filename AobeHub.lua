-- Auto Leveling System GUI
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

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
MainFrame.Size = UDim2.new(0, 400, 0, 600)
MainFrame.Position = UDim2.new(1, -420, 0.5, -300)
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = AutoLevelGUI

-- Rounded Corners
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 50)
TitleBar.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local UICornerTitle = Instance.new("UICorner")
UICornerTitle.CornerRadius = UDim.new(0, 12)
UICornerTitle.Parent = TitleBar

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(0.8, 0, 1, 0)
TitleText.Position = UDim2.new(0, 15, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Font = Enum.Font.GothamBold
TitleText.Text = "🐾 Auto Leveling System"
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.TextSize = 20
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

-- Close Button
local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Position = UDim2.new(1, -40, 0, 10)
CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseButton.BorderSizePixel = 0
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 16
CloseButton.Parent = TitleBar

local UICornerClose = Instance.new("UICorner")
UICornerClose.CornerRadius = UDim.new(0, 6)
UICornerClose.Parent = CloseButton

CloseButton.MouseButton1Click:Connect(function()
    AutoLevelGUI:Destroy()
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
ScrollFrame.Size = UDim2.new(1, -20, 1, -60)
ScrollFrame.Position = UDim2.new(0, 10, 0, 55)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 6
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 800)
ScrollFrame.Parent = MainFrame

-- Content Layout
local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 10)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Parent = ScrollFrame

-- Variables
local teamPets = {} -- UUIDs of team pets
local targetPets = {} -- UUIDs of target pets
local targetLevel = TARGET_LEVEL_DEFAULT
local isLeveling = false
local currentTargets = {} -- Currently selected target pets

-- Functions
local function getPlayerPetData()
    local playerData = DataService:GetData()
    if playerData and playerData.PetsData then
        return playerData.PetsData
    end
    return nil
end

local function getPetDisplayName(petUUID)
    local petsData = getPlayerPetData()
    if not petsData then return "Unknown" end
    
    local petData = petsData.PetInventory.Data[petUUID]
    if petData and petData.PetData then
        return petData.PetData.Name or petData.PetData.DisplayName or "Unknown Pet"
    end
    return "Unknown"
end

local function getPetLevel(petUUID)
    local petsData = getPlayerPetData()
    if not petsData then return 0 end
    
    local petData = petsData.PetInventory.Data[petUUID]
    if petData and petData.PetData then
        return petData.PetData.Level or petData.PetData.CurrentLevel or 0
    end
    return 0
end

-- Create Section
local function createSection(parent, title)
    local SectionFrame = Instance.new("Frame")
    SectionFrame.Size = UDim2.new(1, -10, 0, 200)
    SectionFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    SectionFrame.BorderSizePixel = 0
    SectionFrame.Parent = parent
    
    local UICornerSection = Instance.new("UICorner")
    UICornerSection.CornerRadius = UDim.new(0, 8)
    UICornerSection.Parent = SectionFrame
    
    local SectionTitle = Instance.new("TextLabel")
    SectionTitle.Size = UDim2.new(1, 0, 0, 30)
    SectionTitle.Position = UDim2.new(0, 10, 0, 5)
    SectionTitle.BackgroundTransparency = 1
    SectionTitle.Font = Enum.Font.GothamBold
    SectionTitle.Text = title
    SectionTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    SectionTitle.TextSize = 16
    SectionTitle.TextXAlignment = Enum.TextXAlignment.Left
    SectionTitle.Parent = SectionFrame
    
    return SectionFrame
end

-- Team Pets Section
local TeamSection = createSection(ScrollFrame, "👥 Tim Leveling (Sisa Slot: " .. MAX_PET_SLOTS .. ")")
TeamSection.LayoutOrder = 1
TeamSection.Size = UDim2.new(1, -10, 0, 250)

-- Team Pets Dropdown
local TeamDropdown = Instance.new("Frame")
TeamDropdown.Size = UDim2.new(1, -20, 0, 35)
TeamDropdown.Position = UDim2.new(0, 10, 0, 40)
TeamDropdown.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
TeamDropdown.BorderSizePixel = 0
TeamDropdown.Parent = TeamSection

local UICornerTeamDropdown = Instance.new("UICorner")
UICornerTeamDropdown.CornerRadius = UDim.new(0, 6)
UICornerTeamDropdown.Parent = TeamDropdown

local TeamDropdownButton = Instance.new("TextButton")
TeamDropdownButton.Size = UDim2.new(1, 0, 1, 0)
TeamDropdownButton.BackgroundTransparency = 1
TeamDropdownButton.Font = Enum.Font.Gotham
TeamDropdownButton.Text = "Pilih Pet Tim (Click)"
TeamDropdownButton.TextColor3 = Color3.fromRGB(200, 200, 200)
TeamDropdownButton.TextSize = 14
TeamDropdownButton.Parent = TeamDropdown

-- Team Pets List
local TeamListFrame = Instance.new("ScrollingFrame")
TeamListFrame.Size = UDim2.new(1, -20, 0, 150)
TeamListFrame.Position = UDim2.new(0, 10, 0, 80)
TeamListFrame.BackgroundTransparency = 1
TeamListFrame.BorderSizePixel = 0
TeamListFrame.ScrollBarThickness = 4
TeamListFrame.CanvasSize = UDim2.new(0, 0, 0, 200)
TeamListFrame.Visible = false
TeamListFrame.Parent = TeamSection

local TeamListLayout = Instance.new("UIListLayout")
TeamListLayout.Padding = UDim.new(0, 3)
TeamListLayout.Parent = TeamListFrame

-- Target Level Section
local LevelSection = createSection(ScrollFrame, "🎯 Target Level")
LevelSection.LayoutOrder = 2
LevelSection.Size = UDim2.new(1, -10, 0, 100)

local LevelInput = Instance.new("TextBox")
LevelInput.Size = UDim2.new(1, -20, 0, 40)
LevelInput.Position = UDim2.new(0, 10, 0, 40)
LevelInput.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
LevelInput.BorderSizePixel = 0
LevelInput.Font = Enum.Font.Gotham
LevelInput.PlaceholderText = "Target Level (default: 100)"
LevelInput.Text = tostring(TARGET_LEVEL_DEFAULT)
LevelInput.TextColor3 = Color3.fromRGB(255, 255, 255)
LevelInput.TextSize = 14
LevelInput.Parent = LevelSection

local UICornerLevelInput = Instance.new("UICorner")
UICornerLevelInput.CornerRadius = UDim.new(0, 6)
UICornerLevelInput.Parent = LevelInput

LevelInput.FocusLost:Connect(function(enterPressed)
    local newLevel = tonumber(LevelInput.Text)
    if newLevel and newLevel > 0 then
        targetLevel = newLevel
    else
        LevelInput.Text = tostring(targetLevel)
    end
end)

-- Target Pets Section
local TargetSection = createSection(ScrollFrame, "🎯 Pet Target Leveling")
TargetSection.LayoutOrder = 3
TargetSection.Size = UDim2.new(1, -10, 0, 300)

-- Target Pets Dropdown
local TargetDropdown = Instance.new("Frame")
TargetDropdown.Size = UDim2.new(1, -20, 0, 35)
TargetDropdown.Position = UDim2.new(0, 10, 0, 40)
TargetDropdown.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
TargetDropdown.BorderSizePixel = 0
TargetDropdown.Parent = TargetSection

local UICornerTargetDropdown = Instance.new("UICorner")
UICornerTargetDropdown.CornerRadius = UDim.new(0, 6)
UICornerTargetDropdown.Parent = TargetDropdown

local TargetDropdownButton = Instance.new("TextButton")
TargetDropdownButton.Size = UDim2.new(1, 0, 1, 0)
TargetDropdownButton.BackgroundTransparency = 1
TargetDropdownButton.Font = Enum.Font.Gotham
TargetDropdownButton.Text = "Pilih Pet Target (Click)"
TargetDropdownButton.TextColor3 = Color3.fromRGB(200, 200, 200)
TargetDropdownButton.TextSize = 14
TargetDropdownButton.Parent = TargetDropdown

-- Target Pets List
local TargetListFrame = Instance.new("ScrollingFrame")
TargetListFrame.Size = UDim2.new(1, -20, 0, 200)
TargetListFrame.Position = UDim2.new(0, 10, 0, 80)
TargetListFrame.BackgroundTransparency = 1
TargetListFrame.BorderSizePixel = 0
TargetListFrame.ScrollBarThickness = 4
TargetListFrame.CanvasSize = UDim2.new(0, 0, 0, 300)
TargetListFrame.Visible = false
TargetListFrame.Parent = TargetSection

local TargetListLayout = Instance.new("UIListLayout")
TargetListLayout.Padding = UDim.new(0, 3)
TargetListLayout.Parent = TargetListFrame

-- Buttons Section
local ButtonSection = createSection(ScrollFrame, "⚙️ Kontrol")
ButtonSection.LayoutOrder = 4
ButtonSection.Size = UDim2.new(1, -10, 0, 150)

-- Scan Button
local ScanButton = Instance.new("TextButton")
ScanButton.Size = UDim2.new(1, -20, 0, 35)
ScanButton.Position = UDim2.new(0, 10, 0, 40)
ScanButton.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
ScanButton.BorderSizePixel = 0
ScanButton.Font = Enum.Font.GothamBold
ScanButton.Text = "🔍 Scan Pet Target"
ScanButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ScanButton.TextSize = 14
ScanButton.Parent = ButtonSection

local UICornerScan = Instance.new("UICorner")
UICornerScan.CornerRadius = UDim.new(0, 6)
UICornerScan.Parent = ScanButton

-- Start Button
local StartButton = Instance.new("TextButton")
StartButton.Size = UDim2.new(1, -20, 0, 35)
StartButton.Position = UDim2.new(0, 10, 0, 80)
StartButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
StartButton.BorderSizePixel = 0
StartButton.Font = Enum.Font.GothamBold
StartButton.Text = "▶️ Mulai Auto Leveling"
StartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
StartButton.TextSize = 14
StartButton.Parent = ButtonSection

local UICornerStart = Instance.new("UICorner")
UICornerStart.CornerRadius = UDim.new(0, 6)
UICornerStart.Parent = StartButton

-- Status Label
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 25)
StatusLabel.Position = UDim2.new(0, 10, 0, 120)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "Status: Idle"
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.TextSize = 12
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = ButtonSection

-- Functions to populate dropdowns
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
    local inventory = petsData.PetInventory.Data or {}
    
    TeamListFrame.CanvasSize = UDim2.new(0, 0, 0, #equippedPets * 25)
    
    for _, petUUID in ipairs(equippedPets) do
        local petName = getPetDisplayName(petUUID)
        local petLevel = getPetLevel(petUUID)
        
        local PetButton = Instance.new("TextButton")
        PetButton.Size = UDim2.new(1, 0, 0, 22)
        PetButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
        PetButton.BorderSizePixel = 0
        PetButton.Font = Enum.Font.Gotham
        PetButton.Text = string.format("%s (Lv.%d)", petName, petLevel)
        PetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        PetButton.TextSize = 12
        PetButton.Parent = TeamListFrame
        
        local UICornerPet = Instance.new("UICorner")
        UICornerPet.CornerRadius = UDim.new(0, 4)
        UICornerPet.Parent = PetButton
        
        -- Check if already in team
        if table.find(teamPets, petUUID) then
            PetButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        end
        
        PetButton.MouseButton1Click:Connect(function()
            local teamIndex = table.find(teamPets, petUUID)
            if teamIndex then
                table.remove(teamPets, teamIndex)
                PetButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
            else
                if #teamPets < MAX_PET_SLOTS then
                    table.insert(teamPets, petUUID)
                    PetButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
                end
            end
            updateSlotInfo()
        end)
    end
end

local function scanTargetPets()
    local petsData = getPlayerPetData()
    if not petsData then return end
    
    local inventory = petsData.PetInventory.Data or {}
    local petNames = {}
    
    -- Collect unique pet names below target level
    for petUUID, petData in pairs(inventory) do
        local petName = getPetDisplayName(petUUID)
        local petLevel = getPetLevel(petUUID)
        
        if petLevel < targetLevel and not table.find(teamPets, petUUID) then
            if not petNames[petName] then
                petNames[petName] = {}
            end
            table.insert(petNames[petName], {
                UUID = petUUID,
                Level = petLevel
            })
        end
    end
    
    return petNames
end

local function populateTargetDropdown()
    clearDropdown(TargetListFrame)
    
    local petNames = scanTargetPets()
    if not petNames then return end
    
    local totalCount = 0
    for _, pets in pairs(petNames) do
        totalCount = totalCount + 1
    end
    
    TargetListFrame.CanvasSize = UDim2.new(0, 0, 0, totalCount * 30)
    
    for petName, petInstances in pairs(petNames) do
        -- Only show one entry per pet name
        local firstPet = petInstances[1]
        
        local PetButton = Instance.new("TextButton")
        PetButton.Size = UDim2.new(1, 0, 0, 25)
        PetButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
        PetButton.BorderSizePixel = 0
        PetButton.Font = Enum.Font.Gotham
        PetButton.Text = string.format("%s (x%d) - Lv.%d", petName, #petInstances, firstPet.Level)
        PetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        PetButton.TextSize = 12
        PetButton.Parent = TargetListFrame
        
        local UICornerTarget = Instance.new("UICorner")
        UICornerTarget.CornerRadius = UDim.new(0, 4)
        UICornerTarget.Parent = PetButton
        
        -- Check if this pet type is selected
        local isSelected = false
        for _, targetUUID in ipairs(targetPets) do
            if getPetDisplayName(targetUUID) == petName then
                isSelected = true
                break
            end
        end
        
        if isSelected then
            PetButton.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
        end
        
        PetButton.MouseButton1Click:Connect(function()
            -- Calculate available slots
            local availableSlots = MAX_PET_SLOTS - #teamPets
            
            -- Check if already selected
            local selectedCount = 0
            for _, targetUUID in ipairs(targetPets) do
                if getPetDisplayName(targetUUID) == petName then
                    selectedCount = selectedCount + 1
                end
            end
            
            if selectedCount > 0 then
                -- Remove all pets with this name
                for i = #targetPets, 1, -1 do
                    if getPetDisplayName(targetPets[i]) == petName then
                        table.remove(targetPets, i)
                    end
                end
                PetButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
            else
                -- Add pets until slots are full
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
    local usedSlots = #teamPets + #targetPets
    local availableSlots = MAX_PET_SLOTS - usedSlots
    
    TeamSection.TitleText.Text = "👥 Tim Leveling (Sisa Slot: " .. availableSlots .. ")"
    StatusLabel.Text = string.format(
        "Status: Team: %d | Target: %d | Sisa Slot: %d",
        #teamPets,
        #targetPets,
        availableSlots
    )
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

-- Start Button
StartButton.MouseButton1Click:Connect(function()
    if isLeveling then
        isLeveling = false
        StartButton.Text = "▶️ Mulai Auto Leveling"
        StartButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
        StatusLabel.Text = "Status: Stopped"
        return
    end
    
    if #targetPets == 0 then
        StatusLabel.Text = "Status: Pilih pet target dulu!"
        return
    end
    
    if #teamPets == 0 then
        StatusLabel.Text = "Status: Pilih minimal 1 pet tim!"
        return
    end
    
    isLeveling = true
    StartButton.Text = "⏹️ Stop Auto Leveling"
    StartButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    StatusLabel.Text = "Status: Leveling..."
    
    -- Auto Leveling Loop
    spawn(function()
        while isLeveling do
            local allComplete = true
            
            -- Check all target pets
            for i = #targetPets, 1, -1 do
                local petUUID = targetPets[i]
                local petLevel = getPetLevel(petUUID)
                
                if petLevel >= targetLevel then
                    -- Pet reached target level, remove from targets
                    table.remove(targetPets, i)
                    StatusLabel.Text = string.format("Status: %s mencapai level %d!", getPetDisplayName(petUUID), targetLevel)
                else
                    allComplete = false
                end
            end
            
            -- Check if all targets complete
            if allComplete then
                StatusLabel.Text = "Status: Semua pet target selesai leveling!"
                isLeveling = false
                StartButton.Text = "▶️ Mulai Auto Leveling"
                StartButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
                break
            end
            
            -- Here you would implement the actual leveling logic
            -- This is where you'd equip target pets and do leveling activities
            
            wait(5) -- Check every 5 seconds
        end
    end)
end)

-- Initial setup
updateSlotInfo()

-- Add GUI to PlayerGui
AutoLevelGUI.Parent = playerGui

print("Auto Leveling System GUI loaded!")
