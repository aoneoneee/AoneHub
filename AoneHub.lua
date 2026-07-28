--[[
    Auto Sell All GUI - Fixed Dropdown
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

-- Fixed jitter settings
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
    "Atlantic Giant Pumpkin",
    "Carrot"
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

-- Jitter Functions
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

-- ============================================
-- CREATE GUI (SIMPLIFIED & FIXED)
-- ============================================
local function createGUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "AutoSellGUI"
    gui.Parent = coreGui
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 300, 0, 350)
    mainFrame.Position = UDim2.new(0.5, -150, 0.5, -175)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
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
        if isDragging then
            local delta = input.Position - dragStart
            local newX = math.clamp(startPos.X.Offset + delta.X, -250, workspace.CurrentCamera.ViewportSize.X - 50)
            local newY = math.clamp(startPos.Y.Offset + delta.Y, 0, workspace.CurrentCamera.ViewportSize.Y - 50)
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
    contentFrame.Size = UDim2.new(1, -20, 1, -50)
    contentFrame.Position = UDim2.new(0, 10, 0, 45)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame
    
    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 10)
    contentLayout.Parent = contentFrame
    
    -- === FRUIT SELECTION (SIMPLE DROPDOWN) ===
    local fruitLabel = Instance.new("TextLabel")
    fruitLabel.Size = UDim2.new(1, 0, 0, 25)
    fruitLabel.BackgroundTransparency = 1
    fruitLabel.Text = "🍇 Pilih Buah:"
    fruitLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    fruitLabel.Font = Enum.Font.GothamBold
    fruitLabel.TextSize = 14
    fruitLabel.TextXAlignment = Enum.TextXAlignment.Left
    fruitLabel.Parent = contentFrame
    
    -- Dropdown button
    local dropdownBtn = Instance.new("TextButton")
    dropdownBtn.Size = UDim2.new(1, 0, 0, 35)
    dropdownBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    dropdownBtn.Text = "▼ " .. selectedFruit
    dropdownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropdownBtn.Font = Enum.Font.Gotham
    dropdownBtn.TextSize = 14
    dropdownBtn.ZIndex = 10
    dropdownBtn.Parent = contentFrame
    
    local dropdownBtnCorner = Instance.new("UICorner")
    dropdownBtnCorner.CornerRadius = UDim.new(0, 6)
    dropdownBtnCorner.Parent = dropdownBtn
    
    -- Dropdown list (separate frame di parent yang sama)
    local dropdownList = Instance.new("Frame")
    dropdownList.Size = UDim2.new(1, 0, 0, 0)
    dropdownList.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    dropdownList.BorderSizePixel = 0
    dropdownList.Visible = false
    dropdownList.ZIndex = 100
    dropdownList.Parent = contentFrame
    
    local dropdownListCorner = Instance.new("UICorner")
    dropdownListCorner.CornerRadius = UDim.new(0, 6)
    dropdownListCorner.Parent = dropdownList
    
    local dropdownListLayout = Instance.new("UIListLayout")
    dropdownListLayout.Padding = UDim.new(0, 0)
    dropdownListLayout.Parent = dropdownList
    
    -- Buat opsi dropdown
    for i, fruitName in ipairs(FRUIT_LIST) do
        local option = Instance.new("TextButton")
        option.Size = UDim2.new(1, 0, 0, 35)
        option.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        option.Text = fruitName
        option.TextColor3 = Color3.fromRGB(255, 255, 255)
        option.Font = Enum.Font.Gotham
        option.TextSize = 13
        option.ZIndex = 101
        option.Parent = dropdownList
        
        local optionCorner = Instance.new("UICorner")
        optionCorner.CornerRadius = UDim.new(0, 0)
        optionCorner.Parent = option
        
        option.MouseButton1Click:Connect(function()
            selectedFruit = fruitName
            dropdownBtn.Text = "▼ " .. fruitName
            dropdownList.Visible = false
            dropdownList.Size = UDim2.new(1, 0, 0, 0)
            hasSold = false
            currentMultiplier = 0
            print("✅ Selected: " .. fruitName)
        end)
        
        -- Hover effect
        option.MouseEnter:Connect(function()
            option.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
        end)
        option.MouseLeave:Connect(function()
            option.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        end)
    end
    
    -- Toggle dropdown
    dropdownBtn.MouseButton1Click:Connect(function()
        if dropdownList.Visible then
            dropdownList.Visible = false
            dropdownList.Size = UDim2.new(1, 0, 0, 0)
        else
            dropdownList.Visible = true
            dropdownList.Size = UDim2.new(1, 0, 0, #FRUIT_LIST * 35)
        end
    end)
    
    -- === MULTIPLIER INPUT ===
    local multLabel = Instance.new("TextLabel")
    multLabel.Size = UDim2.new(1, 0, 0, 25)
    multLabel.BackgroundTransparency = 1
    multLabel.Text = "📊 Minimal Multiplier (X):"
    multLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    multLabel.Font = Enum.Font.GothamBold
    multLabel.TextSize = 14
    multLabel.TextXAlignment = Enum.TextXAlignment.Left
    multLabel.Parent = contentFrame
    
    local multInput = Instance.new("TextBox")
    multInput.Size = UDim2.new(1, 0, 0, 35)
    multInput.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    multInput.Text = "4.0"
    multInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    multInput.Font = Enum.Font.Gotham
    multInput.TextSize = 14
    multInput.PlaceholderText = "Masukkan angka (e.g. 4.0)"
    multInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    multInput.Parent = contentFrame
    
    local multInputCorner = Instance.new("UICorner")
    multInputCorner.CornerRadius = UDim.new(0, 6)
    multInputCorner.Parent = multInput
    
    multInput.FocusLost:Connect(function()
        local num = tonumber(multInput.Text)
        if num and num > 0 then
            minMultiplier = num
            hasSold = false
            print("📊 Target multiplier: X" .. num)
        else
            multInput.Text = tostring(minMultiplier)
        end
    end)
    
    -- === STATUS DISPLAY ===
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 70)
    statusLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    statusLabel.Text = "🔴 Siap!\nPilih buah & tekan START"
    statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 11
    statusLabel.TextWrapped = true
    statusLabel.Parent = contentFrame
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 6)
    statusCorner.Parent = statusLabel
    
    -- === JITTER INFO (KECIL) ===
    local jitterInfo = Instance.new("TextLabel")
    jitterInfo.Size = UDim2.new(1, 0, 0, 15)
    jitterInfo.BackgroundTransparency = 1
    jitterInfo.Text = "⚙️ Jitter: " .. JITTER_MIN .. "-" .. JITTER_MAX .. "s | Cooldown: " .. COOLDOWN .. "s"
    jitterInfo.TextColor3 = Color3.fromRGB(120, 120, 120)
    jitterInfo.Font = Enum.Font.Gotham
    jitterInfo.TextSize = 9
    jitterInfo.Parent = contentFrame
    
    -- === BUTTONS ===
    local startBtn = Instance.new("TextButton")
    startBtn.Size = UDim2.new(1, 0, 0, 40)
    startBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
    startBtn.Text = "▶ START"
    startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    startBtn.Font = Enum.Font.GothamBold
    startBtn.TextSize = 16
    startBtn.Parent = contentFrame
    
    local startCorner = Instance.new("UICorner")
    startCorner.CornerRadius = UDim.new(0, 8)
    startCorner.Parent = startBtn
    
    local stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.new(1, 0, 0, 40)
    stopBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    stopBtn.Text = "⏹ STOP"
    stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    stopBtn.Font = Enum.Font.GothamBold
    stopBtn.TextSize = 16
    stopBtn.Visible = false
    stopBtn.Parent = contentFrame
    
    local stopCorner = Instance.new("UICorner")
    stopCorner.CornerRadius = UDim.new(0, 8)
    stopCorner.Parent = stopBtn
    
    return gui, statusLabel, startBtn, stopBtn, dropdownBtn, dropdownList
end

-- Create GUI
local gui, statusLabel, startBtn, stopBtn, dropdownBtn, dropdownList = createGUI()

-- Update status
local function updateStatus(message)
    local timeLeft = getTimeUntilRefresh()
    local timeStr = os.date("%H:%M:%S")
    local countdown = ""
    
    if timeLeft then
        local min = math.floor(timeLeft / 60)
        local sec = math.floor(timeLeft % 60)
        countdown = " | Next: " .. min .. "m " .. sec .. "s"
    end
    
    statusLabel.Text = string.format("[%s] %s\n🍎 %s | X%.1f → X%.1f%s",
        timeStr, message, selectedFruit, currentMultiplier, minMultiplier, countdown)
end

-- Main monitoring loop
local function monitoringLoop()
    getCycleTime()
    local mult = getMultiplier(true)
    updateStatus("🟢 Monitoring...")
    
    local lastMult = mult
    local lastTimerCheck = 0
    
    while isRunning do
        if tick() - lastTimerCheck > 1 then
            lastTimerCheck = tick()
            updateStatus("🟢 Monitoring...")
        end
        
        local currentTimeLeft = getTimeUntilRefresh()
        if currentTimeLeft and lastTimeLeft then
            if currentTimeLeft > lastTimeLeft + 30 then
                print("🔄 Cycle refreshed!")
                local newMult = getMultiplier(true)
                if newMult ~= currentMultiplier then
                    currentMultiplier = newMult
                    updateStatus("📊 X" .. newMult)
                    
                    if currentMultiplier >= minMultiplier and not hasSold then
                        updateStatus("🔥 SELLING!")
                        sellAllWithJitter()
                        updateStatus("✅ SOLD at X" .. currentMultiplier)
                    end
                end
            end
        end
        lastTimeLeft = currentTimeLeft
        
        if tick() - lastRefreshTime > 30 then
            local newMult = getMultiplier(true)
            if newMult ~= lastMult then
                lastMult = newMult
                currentMultiplier = newMult
                updateStatus("📊 X" .. newMult)
                
                if currentMultiplier >= minMultiplier and not hasSold and (tick() - lastSellTime > COOLDOWN) then
                    updateStatus("🔥 SELLING!")
                    sellAllWithJitter()
                    updateStatus("✅ SOLD!")
                end
            end
            lastRefreshTime = tick()
        end
        
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

-- Debug
print("✅ Auto Sell GUI v4 Loaded!")
print("🍎 Buah tersedia: " .. #FRUIT_LIST)
print("📋 " .. table.concat(FRUIT_LIST, ", "))
