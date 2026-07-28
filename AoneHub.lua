--[[
    Auto Sell All GUI - Clean Version
    No jitter UI + Fixed dropdown z-index
--]]

-- Services
local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local coreGui = game:GetService("CoreGui")

-- Variables
local currentMultiplier = 0
local hasSold = false
local lastSellTime = 0
local isRunning = false
local selectedFruit = "Dragon's Breath"
local minMultiplier = 4.0
local cycleSeconds = 600
local lastRefreshTime = 0
local lastTimeLeft = nil

-- Fixed jitter settings (not shown in UI)
local JITTER_MIN = 0.5
local JITTER_MAX = 3.0
local COOLDOWN = 30
local HUMANIZE = true

-- Data buah
local FRUIT_LIST = {
    "Dragon's Breath",
    "Hypno Bloom", 
    "Moon Bloom",
    "Sun Bloom",
    "Star Fruit",
    "Briar Rose",
    "Amber Cranberry",
    "Atlantic Giant Pumpkin"
}

-- Dapatkan cycle time
local function getCycleTime()
    local success, result = pcall(function()
        local networking = require(replicatedStorage.SharedModules.Networking)
        local data = networking.FruitStock.Request:Fire()
        if data and data.cycleSeconds then
            return data.cycleSeconds
        end
    end)
    
    if success and result then
        cycleSeconds = result
    end
    
    return cycleSeconds
end

-- Baca multiplier dari GUI
local function readMultiplier()
    local playerGui = players.LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    
    local stockGui = playerGui:FindFirstChild("FruitStockPrice")
    if not stockGui or not stockGui.Enabled then return nil end
    
    local scrollFrame = stockGui:FindFirstChild("Frame")
    if scrollFrame then
        scrollFrame = scrollFrame:FindFirstChild("ScrollingFrame")
    end
    
    if not scrollFrame then return nil end
    
    for _, card in pairs(scrollFrame:GetChildren()) do
        if card:IsA("Frame") and card.Name == "FruitCard" then
            local attr = card:GetAttribute("SeedToolTip")
            if attr == selectedFruit then
                local frame = card:FindFirstChild("Frame")
                if frame then
                    local multLabel = frame:FindFirstChild("Multiplier")
                    if multLabel and multLabel:IsA("TextLabel") then
                        local num = multLabel.Text:match("X([%d.]+)")
                        if num then
                            return tonumber(num)
                        end
                    end
                end
            end
        end
    end
    
    return nil
end

-- Baca timer countdown
local function getTimeUntilRefresh()
    local playerGui = players.LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil end
    
    local stockGui = playerGui:FindFirstChild("FruitStockPrice")
    if not stockGui or not stockGui.Enabled then return nil end
    
    local timer = stockGui:FindFirstChild("Timer", true)
    if timer and timer:IsA("TextLabel") then
        local text = timer.Text
        local minutes, seconds = text:match("(%d+)m (%d+)s")
        if minutes and seconds then
            return tonumber(minutes) * 60 + tonumber(seconds)
        end
    end
    
    return nil
end

-- Get multiplier
local function getMultiplier(forceUpdate)
    if forceUpdate or currentMultiplier == 0 then
        local mult = readMultiplier()
        if mult then
            currentMultiplier = mult
            return mult
        end
        
        local success, result = pcall(function()
            local networking = require(replicatedStorage.SharedModules.Networking)
            local data = networking.FruitStock.Request:Fire()
            if data and data.entries then
                local fruitData = data.entries[selectedFruit]
                if fruitData then
                    return fruitData.multiplier or 1
                end
            end
        end)
        
        if success and result then
            currentMultiplier = result
            return result
        end
    end
    
    return currentMultiplier
end

-- Create GUI
local function createGUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "AutoSellGUI"
    gui.Parent = coreGui
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999 -- Selalu di depan
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 300, 0, 420)
    mainFrame.Position = UDim2.new(0.5, -150, 0.5, -210)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    mainFrame.BorderSizePixel = 0
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.Active = true
    mainFrame.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    titleBar.BorderSizePixel = 0
    titleBar.Active = true
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(0.7, 0, 1, 0)
    titleText.Position = UDim2.new(0.05, 0, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "🍎 Auto Sell All"
    titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 18
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = titleBar
    
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 30, 0, 30)
    minimizeBtn.Position = UDim2.new(0.85, 0, 0, 5)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    minimizeBtn.Text = "_"
    minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 20
    minimizeBtn.Parent = titleBar
    
    local minimizeCorner = Instance.new("UICorner")
    minimizeCorner.CornerRadius = UDim.new(0, 6)
    minimizeCorner.Parent = minimizeBtn
    
    -- DRAG SYSTEM
    local isDragging = false
    local dragStart = nil
    local startPos = nil
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    
    userInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or 
                          input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            local newX = math.clamp(startPos.X.Offset + delta.X, -mainFrame.Size.X.Offset + 50, 
                                   workspace.CurrentCamera.ViewportSize.X - 50)
            local newY = math.clamp(startPos.Y.Offset + delta.Y, 0, 
                                   workspace.CurrentCamera.ViewportSize.Y - 50)
            mainFrame.Position = UDim2.new(0, newX, 0, newY)
        end
    end)
    
    userInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)
    
    -- Content Frame
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, -20, 1, -50)
    contentFrame.Position = UDim2.new(0, 10, 0, 45)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame
    
    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 8)
    contentLayout.Parent = contentFrame
    
    -- === FRUIT SELECTION ===
    local fruitSection = Instance.new("Frame")
    fruitSection.Size = UDim2.new(1, 0, 0, 50)
    fruitSection.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    fruitSection.BackgroundTransparency = 0.3
    fruitSection.Parent = contentFrame
    
    local fruitCorner = Instance.new("UICorner")
    fruitCorner.CornerRadius = UDim.new(0, 8)
    fruitCorner.Parent = fruitSection
    
    local fruitLabel = Instance.new("TextLabel")
    fruitLabel.Size = UDim2.new(1, -10, 0, 20)
    fruitLabel.Position = UDim2.new(0, 10, 0, 3)
    fruitLabel.BackgroundTransparency = 1
    fruitLabel.Text = "🍇 Pilih Buah"
    fruitLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    fruitLabel.Font = Enum.Font.GothamBold
    fruitLabel.TextSize = 13
    fruitLabel.TextXAlignment = Enum.TextXAlignment.Left
    fruitLabel.Parent = fruitSection
    
    -- Dropdown Container (untuk z-index)
    local dropdownContainer = Instance.new("Frame")
    dropdownContainer.Name = "DropdownContainer"
    dropdownContainer.Size = UDim2.new(1, 0, 0, 25)
    dropdownContainer.Position = UDim2.new(0, 0, 0, 23)
    dropdownContainer.BackgroundTransparency = 1
    dropdownContainer.ZIndex = 100 -- HIGH Z-INDEX
    dropdownContainer.Parent = fruitSection
    
    local fruitDropdown = Instance.new("TextButton")
    fruitDropdown.Name = "FruitDropdown"
    fruitDropdown.Size = UDim2.new(1, 0, 0, 25)
    fruitDropdown.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    fruitDropdown.Text = selectedFruit
    fruitDropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
    fruitDropdown.Font = Enum.Font.Gotham
    fruitDropdown.TextSize = 12
    fruitDropdown.ZIndex = 100
    fruitDropdown.Parent = dropdownContainer
    
    local dropdownCorner = Instance.new("UICorner")
    dropdownCorner.CornerRadius = UDim.new(0, 4)
    dropdownCorner.Parent = fruitDropdown
    
    -- Dropdown List (SEPARATE dari content, langsung di gui untuk z-index tertinggi)
    local dropdownList = Instance.new("ScrollingFrame")
    dropdownList.Name = "DropdownList"
    dropdownList.Size = UDim2.new(0, 280, 0, 200)
    dropdownList.Position = UDim2.new(0, 0, 0, 0)
    dropdownList.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    dropdownList.BorderSizePixel = 0
    dropdownList.ScrollBarThickness = 4
    dropdownList.Visible = false
    dropdownList.ZIndex = 999 -- SUPER HIGH Z-INDEX
    dropdownList.Parent = gui -- Langsung di ScreenGui
    
    local dropdownListCorner = Instance.new("UICorner")
    dropdownListCorner.CornerRadius = UDim.new(0, 6)
    dropdownListCorner.Parent = dropdownList
    
    -- Shadow untuk dropdown
    local dropdownShadow = Instance.new("ImageLabel")
    dropdownShadow.Size = UDim2.new(1, 20, 1, 20)
    dropdownShadow.Position = UDim2.new(0, -10, 0, -10)
    dropdownShadow.BackgroundTransparency = 1
    dropdownShadow.Image = "rbxassetid://6014261993"
    dropdownShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    dropdownShadow.ImageTransparency = 0.6
    dropdownShadow.ScaleType = Enum.ScaleType.Slice
    dropdownShadow.SliceCenter = Rect.new(49, 49, 450, 450)
    dropdownShadow.ZIndex = 998
    dropdownShadow.Parent = dropdownList
    
    local dropdownLayout = Instance.new("UIListLayout")
    dropdownLayout.Padding = UDim.new(0, 2)
    dropdownLayout.Parent = dropdownList
    
    -- Populate dropdown
    for _, fruitName in ipairs(FRUIT_LIST) do
        local option = Instance.new("TextButton")
        option.Size = UDim2.new(1, -10, 0, 30)
        option.Position = UDim2.new(0, 5, 0, 0)
        option.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        option.Text = fruitName
        option.TextColor3 = Color3.fromRGB(255, 255, 255)
        option.Font = Enum.Font.Gotham
        option.TextSize = 13
        option.ZIndex = 1000
        option.Parent = dropdownList
        
        local optionCorner = Instance.new("UICorner")
        optionCorner.CornerRadius = UDim.new(0, 4)
        optionCorner.Parent = option
        
        -- Hover effect
        option.MouseEnter:Connect(function()
            option.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
        end)
        
        option.MouseLeave:Connect(function()
            option.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        end)
        
        option.MouseButton1Click:Connect(function()
            selectedFruit = fruitName
            fruitDropdown.Text = fruitName
            dropdownList.Visible = false
            hasSold = false
            currentMultiplier = 0
            print("🍎 Selected: " .. fruitName)
        end)
    end
    
    dropdownList.CanvasSize = UDim2.new(0, 0, 0, #FRUIT_LIST * 32)
    
    -- Update dropdown position before showing
    local function updateDropdownPosition()
        local absolutePos = fruitDropdown.AbsolutePosition
        local absoluteSize = fruitDropdown.AbsoluteSize
        dropdownList.Position = UDim2.new(0, absolutePos.X, 0, absolutePos.Y + absoluteSize.Y + 5)
    end
    
    fruitDropdown.MouseButton1Click:Connect(function()
        if dropdownList.Visible then
            dropdownList.Visible = false
        else
            updateDropdownPosition()
            dropdownList.Visible = true
        end
    end)
    
    -- Close dropdown when clicking outside
    gui.MouseEnter:Connect(function() end) -- Dummy untuk tracking
    
    userInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and dropdownList.Visible then
            -- Cek apakah klik di luar dropdown
            local mousePos = userInputService:GetMouseLocation()
            local dropAbsPos = dropdownList.AbsolutePosition
            local dropAbsSize = dropdownList.AbsoluteSize
            local fruitAbsPos = fruitDropdown.AbsolutePosition
            local fruitAbsSize = fruitDropdown.AbsoluteSize
            
            local inDropdown = mousePos.X >= dropAbsPos.X and mousePos.X <= dropAbsPos.X + dropAbsSize.X
                and mousePos.Y >= dropAbsPos.Y and mousePos.Y <= dropAbsPos.Y + dropAbsSize.Y
            
            local inButton = mousePos.X >= fruitAbsPos.X and mousePos.X <= fruitAbsPos.X + fruitAbsSize.X
                and mousePos.Y >= fruitAbsPos.Y and mousePos.Y <= fruitAbsPos.Y + fruitAbsSize.Y
            
            if not inDropdown and not inButton then
                dropdownList.Visible = false
            end
        end
    end)
    
    -- === MULTIPLIER SECTION ===
    local multSection = Instance.new("Frame")
    multSection.Size = UDim2.new(1, 0, 0, 50)
    multSection.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    multSection.BackgroundTransparency = 0.3
    multSection.Parent = contentFrame
    
    local multSectionCorner = Instance.new("UICorner")
    multSectionCorner.CornerRadius = UDim.new(0, 8)
    multSectionCorner.Parent = multSection
    
    local multLabel = Instance.new("TextLabel")
    multLabel.Size = UDim2.new(1, -10, 0, 20)
    multLabel.Position = UDim2.new(0, 10, 0, 3)
    multLabel.BackgroundTransparency = 1
    multLabel.Text = "📊 Minimal Multiplier (X)"
    multLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    multLabel.Font = Enum.Font.GothamBold
    multLabel.TextSize = 13
    multLabel.TextXAlignment = Enum.TextXAlignment.Left
    multLabel.Parent = multSection
    
    local multInput = Instance.new("TextBox")
    multInput.Size = UDim2.new(1, 0, 0, 25)
    multInput.Position = UDim2.new(0, 0, 0, 23)
    multInput.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    multInput.Text = "4.0"
    multInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    multInput.Font = Enum.Font.Gotham
    multInput.TextSize = 12
    multInput.PlaceholderText = "e.g. 4.0"
    multInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    multInput.Parent = multSection
    
    local multInputCorner = Instance.new("UICorner")
    multInputCorner.CornerRadius = UDim.new(0, 4)
    multInputCorner.Parent = multInput
    
    multInput.FocusLost:Connect(function()
        local num = tonumber(multInput.Text)
        if num and num > 0 then
            minMultiplier = num
            hasSold = false
        else
            multInput.Text = tostring(minMultiplier)
        end
    end)
    
    -- === CYCLE INFO ===
    local cycleSection = Instance.new("Frame")
    cycleSection.Size = UDim2.new(1, 0, 0, 55)
    cycleSection.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    cycleSection.BackgroundTransparency = 0.3
    cycleSection.Parent = contentFrame
    
    local cycleCorner = Instance.new("UICorner")
    cycleCorner.CornerRadius = UDim.new(0, 8)
    cycleCorner.Parent = cycleSection
    
    local cycleLabel = Instance.new("TextLabel")
    cycleLabel.Size = UDim2.new(1, -10, 0, 50)
    cycleLabel.Position = UDim2.new(0, 5, 0, 3)
    cycleLabel.BackgroundTransparency = 1
    cycleLabel.Text = "⏰ Cycle: 10 menit\nNext refresh: --:--"
    cycleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    cycleLabel.Font = Enum.Font.Gotham
    cycleLabel.TextSize = 11
    cycleLabel.TextWrapped = true
    cycleLabel.TextXAlignment = Enum.TextXAlignment.Left
    cycleLabel.Parent = cycleSection
    
    -- === STATUS SECTION ===
    local statusSection = Instance.new("Frame")
    statusSection.Size = UDim2.new(1, 0, 0, 90)
    statusSection.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    statusSection.BackgroundTransparency = 0.3
    statusSection.Parent = contentFrame
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 8)
    statusCorner.Parent = statusSection
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -10, 0, 85)
    statusLabel.Position = UDim2.new(0, 5, 0, 3)
    statusLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    statusLabel.Text = "🔴 Not monitoring\nSelect fruit and press START"
    statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 11
    statusLabel.TextWrapped = true
    statusLabel.Parent = statusSection
    
    local statusInnerCorner = Instance.new("UICorner")
    statusInnerCorner.CornerRadius = UDim.new(0, 4)
    statusInnerCorner.Parent = statusLabel
    
    -- === CONTROL BUTTONS ===
    local controlSection = Instance.new("Frame")
    controlSection.Size = UDim2.new(1, 0, 0, 90)
    controlSection.BackgroundTransparency = 1
    controlSection.Parent = contentFrame
    
    local startBtn = Instance.new("TextButton")
    startBtn.Size = UDim2.new(1, 0, 0, 40)
    startBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
    startBtn.Text = "▶ START MONITORING"
    startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    startBtn.Font = Enum.Font.GothamBold
    startBtn.TextSize = 15
    startBtn.Parent = controlSection
    
    local startCorner = Instance.new("UICorner")
    startCorner.CornerRadius = UDim.new(0, 8)
    startCorner.Parent = startBtn
    
    -- Info jitter (tersembunyi)
    local jitterInfo = Instance.new("TextLabel")
    jitterInfo.Size = UDim2.new(1, 0, 0, 20)
    jitterInfo.Position = UDim2.new(0, 0, 0, 45)
    jitterInfo.BackgroundTransparency = 1
    jitterInfo.Text = "⚙️ Jitter: " .. JITTER_MIN .. "-" .. JITTER_MAX .. "s | CD: " .. COOLDOWN .. "s"
    jitterInfo.TextColor3 = Color3.fromRGB(150, 150, 150)
    jitterInfo.Font = Enum.Font.Gotham
    jitterInfo.TextSize = 10
    jitterInfo.Parent = controlSection
    
    local stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.new(1, 0, 0, 40)
    stopBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    stopBtn.Text = "⏹ STOP MONITORING"
    stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    stopBtn.Font = Enum.Font.GothamBold
    stopBtn.TextSize = 15
    stopBtn.Visible = false
    stopBtn.Parent = controlSection
    
    local stopCorner = Instance.new("UICorner")
    stopCorner.CornerRadius = UDim.new(0, 8)
    stopCorner.Parent = stopBtn
    
    -- Minimize
    local minimized = false
    minimizeBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        contentFrame.Visible = not minimized
        mainFrame.Size = minimized and UDim2.new(0, 300, 0, 40) or UDim2.new(0, 300, 0, 420)
    end)
    
    return gui, statusLabel, startBtn, stopBtn, cycleLabel
end

-- Jitter Functions (hidden from UI)
local function getJitter()
    local min = JITTER_MIN
    local max = JITTER_MAX
    if HUMANIZE then
        local r1 = math.random()
        local r2 = math.random()
        return min + (((r1 + r2) / 2) * (max - min))
    end
    return min + (math.random() * (max - min))
end

-- Sell Function
local function sellAllWithJitter()
    local delay = getJitter()
    print("⏳ Jitter delay: " .. string.format("%.2f", delay) .. "s")
    
    task.wait(delay)
    
    if HUMANIZE then
        task.wait(math.random() * 0.3)
    end
    
    local args = {buffer.fromstring("\190\000 ")}
    local remote = replicatedStorage:FindFirstChild("SharedModules")
    if remote then
        remote = remote:FindFirstChild("Packet")
        if remote then
            remote = remote:FindFirstChild("RemoteEvent")
            if remote then
                local success, err = pcall(function()
                    remote:FireServer(unpack(args))
                end)
                if success then
                    print("✅ SOLD at X" .. currentMultiplier)
                    lastSellTime = tick()
                    hasSold = true
                end
            end
        end
    end
end

-- Create GUI
local gui, statusLabel, startBtn, stopBtn, cycleLabel = createGUI()

-- Update status
local function updateStatus(message)
    local timeLeft = getTimeUntilRefresh()
    local timeStr = os.date("%H:%M:%S")
    local countdown = ""
    
    if timeLeft then
        local min = math.floor(timeLeft / 60)
        local sec = math.floor(timeLeft % 60)
        countdown = string.format("\nNext refresh: %dm %02ds", min, sec)
    end
    
    statusLabel.Text = string.format("[%s] %s\n🍎 %s | X%.1f (target: X%.1f)%s",
        timeStr, message, selectedFruit, currentMultiplier, minMultiplier, countdown)
    
    cycleLabel.Text = string.format("⏰ Cycle: %d detik (%d menit)\nNext refresh: %s", 
        cycleSeconds, cycleSeconds/60,
        timeLeft and string.format("%dm %02ds", math.floor(timeLeft/60), math.floor(timeLeft%60)) or "--:--")
end

-- Main monitoring loop
local function monitoringLoop()
    getCycleTime()
    local mult = getMultiplier(true)
    updateStatus("🟢 Monitoring...")
    
    local lastMult = mult
    local lastTimerCheck = 0
    
    while isRunning do
        -- Update countdown setiap detik
        if tick() - lastTimerCheck > 1 then
            lastTimerCheck = tick()
            updateStatus("🟢 Monitoring...")
        end
        
        -- Deteksi cycle refresh
        local currentTimeLeft = getTimeUntilRefresh()
        if currentTimeLeft and lastTimeLeft then
            if currentTimeLeft > lastTimeLeft + 30 then
                print("🔄 Cycle refresh detected!")
                local newMult = getMultiplier(true)
                if newMult ~= currentMultiplier then
                    currentMultiplier = newMult
                    updateStatus("📊 Updated to X" .. newMult)
                    
                    if currentMultiplier >= minMultiplier and not hasSold then
                        updateStatus("🔥 Target reached! Selling...")
                        sellAllWithJitter()
                        updateStatus("✅ SOLD at X" .. currentMultiplier)
                    end
                end
            end
        end
        lastTimeLeft = currentTimeLeft
        
        -- Backup check setiap 30 detik
        if tick() - lastRefreshTime > 30 then
            local newMult = getMultiplier(true)
            if newMult ~= lastMult then
                lastMult = newMult
                currentMultiplier = newMult
                updateStatus("📊 Multiplier: X" .. newMult)
                
                if currentMultiplier >= minMultiplier and not hasSold and (tick() - lastSellTime > COOLDOWN) then
                    updateStatus("🔥 Selling at X" .. currentMultiplier)
                    sellAllWithJitter()
                    updateStatus("✅ SOLD!")
                end
            end
            lastRefreshTime = tick()
        end
        
        -- Reset hasSold
        if currentMultiplier < minMultiplier and hasSold and (tick() - lastSellTime > 5) then
            hasSold = false
        end
        
        task.wait(1)
    end
end

-- Start/Stop
local function startMonitoring()
    isRunning = true
    hasSold = false
    lastSellTime = 0
    currentMultiplier = 0
    lastRefreshTime = 0
    
    updateStatus("🟢 Starting...")
    task.spawn(monitoringLoop)
end

local function stopMonitoring()
    isRunning = false
    updateStatus("🔴 Stopped")
end

startBtn.MouseButton1Click:Connect(function()
    startBtn.Visible = false
    stopBtn.Visible = true
    startMonitoring()
end)

stopBtn.MouseButton1Click:Connect(function()
    stopBtn.Visible = false
    startBtn.Visible = true
    stopMonitoring()
end)

updateStatus("Ready! Select fruit & press START")
print("✅ Auto Sell GUI Loaded!")
print("🍎 " .. #FRUIT_LIST .. " fruits available")
