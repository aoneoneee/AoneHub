-- ──────────────────────────────────────────────────────────────────────
-- 1️⃣  Services & References
-- ──────────────────────────────────────────────────────────────────────
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local packetRemote = ReplicatedStorage:WaitForChild("SharedModules")
    :WaitForChild("Packet")
    :WaitForChild("RemoteEvent")

print("[AutoBuy] ✅ RemoteEvent:", packetRemote:GetFullName())

-- ──────────────────────────────────────────────────────────────────────
-- 2️⃣  Auto-detect opcode
-- ──────────────────────────────────────────────────────────────────────
local function countItem(itemName)
    local count = 0
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item.Name == itemName then count += 1 end
        end
    end
    return count
end

local function autoDetectOpcode()
    print("[AutoBuy] 🔍 Deteksi opcode...")
    local countBefore = countItem("Carrot")
    
    for _, testOpcode in ipairs({158, 158, 160, 161, 162, 163, 164, 165}) do
        local packetStr = string.char(testOpcode, 0, 6) .. "Carrot"
        pcall(function() 
            packetRemote:FireServer(buffer.fromstring(packetStr)) 
        end)
        task.wait(1.5)
        
        if countItem("Carrot") > countBefore then
            print("[AutoBuy] ✅ Opcode:", testOpcode)
            return testOpcode
        end
    end
    
    warn("[AutoBuy] ⚠️  Fallback 160")
    return 160
end

local OPCODE = autoDetectOpcode()

-- ──────────────────────────────────────────────────────────────────────
-- 3️⃣  Config
-- ──────────────────────────────────────────────────────────────────────
local TARGET_ITEMS = {
    "Hypno Bloom",
    "Dragon's Breath",
    "Sun Bloom",
    "Star Fruit",
    "Briar Rose",
    "Carrot",
    "Bamboo"
}

local RESTOCK_INTERVAL = 300   -- 5 menit
local JITTER_MIN = 3           -- Jitter minimal setelah restock
local JITTER_MAX = 5           -- Jitter maksimal setelah restock
local BUY_JITTER_MIN = 0.3     -- Jitter minimal antar pembelian
local BUY_JITTER_MAX = 2.8     -- Jitter maksimal antar pembelian

-- ──────────────────────────────────────────────────────────────────────
-- 4️⃣  Build packet
-- ──────────────────────────────────────────────────────────────────────
local function buildPacket(itemName)
    return buffer.fromstring(string.char(OPCODE, 0, #itemName) .. itemName)
end

-- ──────────────────────────────────────────────────────────────────────
-- 5️⃣  Buy function
-- ──────────────────────────────────────────────────────────────────────
local buyStats = {total = 0, success = 0, failed = 0}
local buyHistory = {}  -- Track pembelian per sesi scan

local function buyItem(itemName)
    local packet = buildPacket(itemName)
    local success, err = pcall(function()
        packetRemote:FireServer(packet)
    end)
    
    buyStats.total += 1
    if success then
        buyStats.success += 1
        buyHistory[itemName] = (buyHistory[itemName] or 0) + 1
        return true
    else
        buyStats.failed += 1
        return false
    end
end

-- ──────────────────────────────────────────────────────────────────────
-- 6️⃣  Shop Detection
-- ──────────────────────────────────────────────────────────────────────
local shopElements = {}

local function cacheShopElements()
    if next(shopElements) then return end
    
    local seedShop = playerGui:FindFirstChild("SeedShop")
    if not seedShop then return end
    
    local frame = seedShop:FindFirstChild("Frame")
    if not frame then return end
    
    local normalShop = frame:FindFirstChild("NormalShop")
    if not normalShop then return end
    
    for _, itemContainer in ipairs(normalShop:GetChildren()) do
        local itemName = itemContainer.Name
        
        for _, targetName in ipairs(TARGET_ITEMS) do
            if itemName == targetName then
                local mainFrame = itemContainer:FindFirstChild("Main_Frame")
                if mainFrame then
                    local costText = mainFrame:FindFirstChild("Cost_Text")
                    if costText then
                        shopElements[itemName] = {
                            container = itemContainer,
                            costText = costText
                        }
                    end
                end
            end
        end
    end
    
    local count = 0
    for _ in pairs(shopElements) do count += 1 end
    print("[AutoBuy] 📋 Shop cached:", count, "items")
end

local function isItemAvailable(itemName)
    local elements = shopElements[itemName]
    if not elements then return false end
    if not elements.container.Visible then return false end
    
    local text = ""
    pcall(function() text = elements.costText.Text end)
    
    if text:upper():find("NO STOCK") then return false end
    if text == "" then return false end
    
    return true
end

-- ──────────────────────────────────────────────────────────────────────
-- 7️⃣  TIMING
-- ──────────────────────────────────────────────────────────────────────
local function getSecondsUntilNextRestock()
    local now = os.time()
    local currentMinute = math.floor(now / 60)
    local currentSecond = now % 60
    
    local jitter = JITTER_MIN + math.random() * (JITTER_MAX - JITTER_MIN)
    
    local nextRestockMinute = math.ceil(currentMinute / 5) * 5
    local minutesUntilRestock = nextRestockMinute - currentMinute
    
    if minutesUntilRestock == 0 and currentSecond < jitter then
        return jitter - currentSecond
    end
    
    local secondsUntilRestock = (minutesUntilRestock * 60) - currentSecond + jitter
    
    if secondsUntilRestock <= 0 then
        secondsUntilRestock = secondsUntilRestock + RESTOCK_INTERVAL
    end
    
    return secondsUntilRestock
end

-- ──────────────────────────────────────────────────────────────────────
-- 8️⃣  BORONG SEMUA ITEM SAMPAI HABIS
-- ──────────────────────────────────────────────────────────────────────
local isRunning = false
local itemStatus = {}
local nextScanTime = 0
local scanCount = 0
local isBuying = false  -- Flag biar gak tumpang tindih

local function buyAllAvailable()
    if isBuying then return end  -- Jangan mulai kalau masih beli
    isBuying = true
    
    print("[AutoBuy] 🛒 MULAI MEMBORONG...")
    
    local totalBought = 0
    
    -- Loop terus sampai semua item habis
    while isRunning do
        local boughtAny = false
        
        -- Cek setiap item target
        for _, itemName in ipairs(TARGET_ITEMS) do
            if not isRunning then break end
            
            -- Kalau item tersedia, beli!
            if isItemAvailable(itemName) then
                print("[AutoBuy] 🎯 Tersedia:", itemName, "- Membeli...")
                
                local success = buyItem(itemName)
                
                if success then
                    totalBought += 1
                    boughtAny = true
                    print("[AutoBuy] ✅ Dibeli:", itemName, "| Sesi:", totalBought)
                    itemStatus[itemName] = "stock"
                    
                    -- JITTER antar pembelian (0.3-0.8 detik)
                    local buyDelay = BUY_JITTER_MIN + math.random() * (BUY_JITTER_MAX - BUY_JITTER_MIN)
                    task.wait(buyDelay)
                else
                    print("[AutoBuy] ❌ Gagal beli:", itemName)
                    itemStatus[itemName] = "nostock"
                    task.wait(0.2)
                end
            else
                itemStatus[itemName] = "nostock"
            end
        end
        
        -- Kalau gak ada yang berhasil dibeli, berarti semua habis
        if not boughtAny then
            print("[AutoBuy] 🚫 Semua item HABIS!")
            break
        end
        
        -- Jeda kecil sebelum cek lagi (siapa tau masih ada stock)
        task.wait(0.2)
    end
    
    print("[AutoBuy] ✅ SESI SELESAI - Total dibeli:", totalBought)
    isBuying = false
end

local function scanAndBuy()
    scanCount += 1
    local now = os.date("%H:%M:%S")
    print("[AutoBuy] 🔍 Scan #" .. scanCount .. " | " .. now)
    
    cacheShopElements()
    
    if next(shopElements) == nil then
        print("[AutoBuy] ⚠️  Shop belum terdeteksi")
        return
    end
    
    -- Reset buy history untuk sesi ini
    buyHistory = {}
    
    -- Cek dulu apakah ada item tersedia
    local anyAvailable = false
    for _, itemName in ipairs(TARGET_ITEMS) do
        if isItemAvailable(itemName) then
            anyAvailable = true
            print("[AutoBuy] 🟢", itemName, "TERSEDIA!")
        else
            print("[AutoBuy] 🔴", itemName, "NO STOCK")
        end
    end
    
    if anyAvailable then
        print("[AutoBuy] 🛒 Ada item tersedia! Memulai pembelian...")
        buyAllAvailable()
    else
        print("[AutoBuy] ❌ Tidak ada item tersedia")
    end
end

local function mainLoop()
    while isRunning do
        local waitTime = getSecondsUntilNextRestock()
        nextScanTime = os.time() + waitTime
        
        local nextScan = os.date("%H:%M:%S", nextScanTime)
        local mins = math.floor(waitTime / 60)
        local secs = math.floor(waitTime % 60)
        
        print(string.format("[AutoBuy] ⏰ Scan berikutnya: %s (%d menit %d detik)", 
            nextScan, mins, secs))
        
        task.wait(waitTime)
        
        if not isRunning then break end
        
        pcall(scanAndBuy)
        task.wait(1)
    end
end

local function startMonitoring()
    if isRunning then return end
    isRunning = true
    
    print("[AutoBuy] ▶️  Monitoring dimulai")
    print("[AutoBuy] ⏰ Restock tiap 5 menit, scan dengan jitter", JITTER_MIN .. "-" .. JITTER_MAX, "detik")
    print("[AutoBuy] 🛒 Jitter beli:", BUY_JITTER_MIN .. "-" .. BUY_JITTER_MAX, "detik")
    
    cacheShopElements()
    
    -- 🔥 LANGSUNG SCAN SEKARANG!
    print("[AutoBuy] 🔍 Initial scan...")
    pcall(scanAndBuy)
    
    task.spawn(mainLoop)
end

local function stopMonitoring()
    if not isRunning then return end
    isRunning = false
    itemStatus = {}
    print("[AutoBuy] ⏹️  Stopped | ✅", buyStats.success, "❌", buyStats.failed)
end

-- ──────────────────────────────────────────────────────────────────────
-- 9️⃣  GUI
-- ──────────────────────────────────────────────────────────────────────
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoBuyGUI"
    screenGui.Parent = playerGui
    screenGui.ResetOnSpawn = false
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 250, 0, 330)
    mainFrame.Position = UDim2.new(1, -260, 0.5, -165)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = mainFrame
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar
    
    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -70, 1, 0)
    titleText.Position = UDim2.new(0, 15, 0, 0)
    titleText.Text = "🌿 AutoBuy Borong"
    titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 14
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.BackgroundTransparency = 1
    titleText.Parent = titleBar
    
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 2)
    closeButton.Text = "✕"
    closeButton.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 18
    closeButton.BackgroundTransparency = 1
    closeButton.Parent = titleBar
    
    local minimizeButton = Instance.new("TextButton")
    minimizeButton.Size = UDim2.new(0, 30, 0, 30)
    minimizeButton.Position = UDim2.new(1, -65, 0, 2)
    minimizeButton.Text = "─"
    minimizeButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    minimizeButton.Font = Enum.Font.GothamBold
    minimizeButton.TextSize = 18
    minimizeButton.BackgroundTransparency = 1
    minimizeButton.Parent = titleBar
    
    -- Content
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -20, 1, -80)
    contentFrame.Position = UDim2.new(0, 10, 0, 45)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame
    
    -- Status
    local statusText = Instance.new("TextLabel")
    statusText.Name = "StatusText"
    statusText.Size = UDim2.new(1, 0, 0, 25)
    statusText.Text = "Status: ⏹️ OFF"
    statusText.TextColor3 = Color3.fromRGB(255, 100, 100)
    statusText.Font = Enum.Font.GothamSemibold
    statusText.TextSize = 13
    statusText.BackgroundTransparency = 1
    statusText.TextXAlignment = Enum.TextXAlignment.Center
    statusText.Parent = contentFrame
    
    -- Timer
    local timerText = Instance.new("TextLabel")
    timerText.Name = "TimerText"
    timerText.Size = UDim2.new(1, 0, 0, 30)
    timerText.Position = UDim2.new(0, 0, 0, 26)
    timerText.Text = "Next scan: --:--:--"
    timerText.TextColor3 = Color3.fromRGB(255, 200, 50)
    timerText.Font = Enum.Font.GothamBold
    timerText.TextSize = 16
    timerText.BackgroundTransparency = 1
    timerText.TextXAlignment = Enum.TextXAlignment.Center
    timerText.Parent = contentFrame
    
    -- Countdown
    local countdownText = Instance.new("TextLabel")
    countdownText.Name = "CountdownText"
    countdownText.Size = UDim2.new(1, 0, 0, 18)
    countdownText.Position = UDim2.new(0, 0, 0, 56)
    countdownText.Text = ""
    countdownText.TextColor3 = Color3.fromRGB(200, 200, 200)
    countdownText.Font = Enum.Font.Gotham
    countdownText.TextSize = 10
    countdownText.BackgroundTransparency = 1
    countdownText.TextXAlignment = Enum.TextXAlignment.Center
    countdownText.Parent = contentFrame
    
    -- Buying status
    local buyingText = Instance.new("TextLabel")
    buyingText.Name = "BuyingText"
    buyingText.Size = UDim2.new(1, 0, 0, 18)
    buyingText.Position = UDim2.new(0, 0, 0, 74)
    buyingText.Text = ""
    buyingText.TextColor3 = Color3.fromRGB(255, 150, 50)
    buyingText.Font = Enum.Font.GothamSemibold
    buyingText.TextSize = 10
    buyingText.BackgroundTransparency = 1
    buyingText.TextXAlignment = Enum.TextXAlignment.Center
    buyingText.Parent = contentFrame
    
    -- Item List
    local itemListLabel = Instance.new("TextLabel")
    itemListLabel.Size = UDim2.new(1, 0, 0, 16)
    itemListLabel.Position = UDim2.new(0, 0, 0, 94)
    itemListLabel.Text = "📋 Status Items:"
    itemListLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    itemListLabel.Font = Enum.Font.GothamSemibold
    itemListLabel.TextSize = 10
    itemListLabel.BackgroundTransparency = 1
    itemListLabel.TextXAlignment = Enum.TextXAlignment.Left
    itemListLabel.Parent = contentFrame
    
    local itemList = Instance.new("ScrollingFrame")
    itemList.Size = UDim2.new(1, 0, 0, 85)
    itemList.Position = UDim2.new(0, 0, 0, 112)
    itemList.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    itemList.BorderSizePixel = 0
    itemList.CanvasSize = UDim2.new(0, 0, 0, #TARGET_ITEMS * 22)
    itemList.ScrollBarThickness = 4
    itemList.Parent = contentFrame
    
    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 5)
    listCorner.Parent = itemList
    
    local itemLabels = {}
    for i, itemName in ipairs(TARGET_ITEMS) do
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -10, 0, 20)
        label.Position = UDim2.new(0, 5, 0, (i-1) * 22)
        label.Text = "⏳ " .. itemName
        label.TextColor3 = Color3.fromRGB(200, 200, 200)
        label.Font = Enum.Font.Gotham
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.BackgroundTransparency = 1
        label.Parent = itemList
        itemLabels[itemName] = label
    end
    
    -- Stats
    local statsText = Instance.new("TextLabel")
    statsText.Name = "StatsText"
    statsText.Size = UDim2.new(1, 0, 0, 25)
    statsText.Position = UDim2.new(0, 0, 0, 202)
    statsText.Text = "✅ 0 | ❌ 0 | 🔄 0"
    statsText.TextColor3 = Color3.fromRGB(150, 150, 150)
    statsText.Font = Enum.Font.Gotham
    statsText.TextSize = 11
    statsText.BackgroundTransparency = 1
    statsText.TextXAlignment = Enum.TextXAlignment.Center
    statsText.Parent = contentFrame
    
    -- Toggle Button
    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(1, 0, 0, 40)
    toggleButton.Position = UDim2.new(0, 0, 0, 232)
    toggleButton.Text = "▶ START"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.TextSize = 14
    toggleButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    toggleButton.BorderSizePixel = 0
    toggleButton.Parent = contentFrame
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 8)
    buttonCorner.Parent = toggleButton
    
    -- Update UI
    local function updateUI()
        if isRunning then
            statusText.Text = isBuying and "Status: 🛒 MEMBORONG" or "Status: ⏰ MENUNGGU"
            statusText.TextColor3 = isBuying and Color3.fromRGB(255, 150, 50) or Color3.fromRGB(100, 200, 255)
            toggleButton.Text = "⏹ STOP"
            toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            
            if isBuying then
                buyingText.Text = "🛒 Sedang memborong..."
                countdownText.Text = ""
                timerText.Text = "BORONG!"
            elseif nextScanTime > 0 then
                buyingText.Text = ""
                local remaining = nextScanTime - os.time()
                if remaining > 0 then
                    local mins = math.floor(remaining / 60)
                    local secs = math.floor(remaining % 60)
                    countdownText.Text = string.format("Scan dalam: %d menit %d detik", mins, secs)
                    timerText.Text = os.date("%H:%M:%S", nextScanTime)
                else
                    countdownText.Text = "🔍 Scanning..."
                    timerText.Text = "SEKARANG"
                end
            end
        else
            statusText.Text = "Status: ⏹️ OFF"
            statusText.TextColor3 = Color3.fromRGB(255, 100, 100)
            toggleButton.Text = "▶ START"
            toggleButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
            timerText.Text = "Next scan: --:--:--"
            countdownText.Text = ""
            buyingText.Text = ""
        end
        
        for itemName, label in pairs(itemLabels) do
            local status = itemStatus[itemName] or "unknown"
            local bought = buyHistory[itemName] or 0
            if status == "stock" then
                label.Text = "🟢 " .. itemName .. (bought > 0 and " (+" .. bought .. ")" or "")
                label.TextColor3 = Color3.fromRGB(100, 255, 100)
            elseif status == "nostock" then
                label.Text = "🔴 " .. itemName .. (bought > 0 and " (+" .. bought .. ")" or "")
                label.TextColor3 = Color3.fromRGB(255, 100, 100)
            else
                label.Text = "⏳ " .. itemName
                label.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end
        
        statsText.Text = string.format("✅ %d | ❌ %d | 🔄 %d", 
            buyStats.success, buyStats.failed, scanCount)
    end
    
    -- Periodic UI refresh
    task.spawn(function()
        while screenGui.Parent do
            task.wait(0.3)
            pcall(updateUI)
        end
    end)
    
    toggleButton.MouseButton1Click:Connect(function()
        if isRunning then
            stopMonitoring()
        else
            startMonitoring()
        end
        updateUI()
    end)
    
    -- Draggable
    local dragging = false
    local dragStart = nil
    local frameStart = nil
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            frameStart = mainFrame.Position
        end
    end)
    
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                frameStart.X.Scale,
                frameStart.X.Offset + delta.X,
                frameStart.Y.Scale,
                frameStart.Y.Offset + delta.Y
            )
        end
    end)
    
    local isMinimized = false
    minimizeButton.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        contentFrame.Visible = not isMinimized
        mainFrame.Size = isMinimized and UDim2.new(0, 250, 0, 35) or UDim2.new(0, 250, 0, 335)
        minimizeButton.Text = isMinimized and "□" or "─"
    end)
    
    closeButton.MouseButton1Click:Connect(function()
        stopMonitoring()
        screenGui:Destroy()
    end)
    
    updateUI()
    print("[AutoBuy] 🖥️  GUI Loaded")
end

-- ──────────────────────────────────────────────────────────────────────
-- 🔟 Start
-- ──────────────────────────────────────────────────────────────────────
createGUI()
print("[AutoBuy] 🚀 Borong Mode Ready")
print("[AutoBuy] ⏰ Scan setiap 5 menit, jitter", JITTER_MIN .. "-" .. JITTER_MAX .. "s")
print("[AutoBuy] 🛒 Jitter beli:", BUY_JITTER_MIN .. "-" .. BUY_JITTER_MAX .. "s")
print("[AutoBuy] 🔥 Langsung borong semua item sampai habis!")
