-- ──────────────────────────────────────────────────────────────────────
-- 1️⃣  Services & References
-- ──────────────────────────────────────────────────────────────────────
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

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
    
    for _, testOpcode in ipairs({133, 131, 130, 132, 134, 135}) do
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
    
    warn("[AutoBuy] ⚠️  Fallback 133")
    return 133
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
    "Bamboo"
}

local SCAN_INTERVAL = 3        -- Scan tiap 3 detik (lebih aman dari 0.5s)
local BUY_COOLDOWN = 5         -- Jeda minimal beli item sama
local RANDOM_OFFSET = 1.5      -- Tambahan acak biar natural

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

local function buyItem(itemName)
    local packet = buildPacket(itemName)
    local success, err = pcall(function()
        packetRemote:FireServer(packet)
    end)
    
    buyStats.total += 1
    if success then
        buyStats.success += 1
        print("[AutoBuy] ✅", itemName, "| Total:", buyStats.success)
    else
        buyStats.failed += 1
        warn("[AutoBuy] ❌", itemName, "|", err)
    end
    
    return success, err
end

-- ──────────────────────────────────────────────────────────────────────
-- 6️⃣  Shop detection - Cari item di GUI (NATURAL SCAN)
-- ──────────────────────────────────────────────────────────────────────
local shopItems = {}
local buyHistory = {}
local shopElements = {}  -- Cache GUI elements

-- Deteksi & cache shop elements (sekali aja, gak loop)
local function cacheShopElements()
    if next(shopElements) then return end  -- Udah di-cache
    
    print("[AutoBuy] 🔍 Mencari shop elements...")
    
    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, element in ipairs(gui:GetDescendants()) do
                if element:IsA("TextLabel") or element:IsA("TextButton") then
                    for _, itemName in ipairs(TARGET_ITEMS) do
                        if element.Text:find(itemName) and not shopElements[itemName] then
                            shopElements[itemName] = element
                            print("[AutoBuy] 📍 Ditemukan:", itemName, "di", element:GetFullName())
                        end
                    end
                end
            end
        end
    end
    
    print("[AutoBuy] 📋 Cached:", #table.getn or #table.keys(shopElements), "elements")
end

-- Scan item availability (ringan - cuma baca text dari cached elements)
local function checkItemAvailability(itemName)
    local element = shopElements[itemName]
    if not element then return false end
    
    -- Baca text element
    local text = ""
    pcall(function() text = element.Text end)
    
    if not text or text == "" then return false end
    
    -- Cek indikator sold out
    local lowerText = text:lower()
    if lowerText:find("sold") or lowerText:find("out") or lowerText:find("empty") then
        return false
    end
    
    -- Cek warna text (kalau abu-abu biasanya sold out)
    local color = nil
    pcall(function() color = element.TextColor3 end)
    if color and color.r < 0.4 and color.g < 0.4 and color.b < 0.4 then
        return false
    end
    
    -- Cek parent visible
    local parent = element.Parent
    while parent do
        if parent:IsA("GuiObject") and not parent.Visible then
            return false
        end
        parent = parent.Parent
    end
    
    return true
end

-- Scan semua item (dipanggil tiap SCAN_INTERVAL)
local function scanAllItems()
    -- Update cache kalau belum
    cacheShopElements()
    
    local availableItems = {}
    
    for _, itemName in ipairs(TARGET_ITEMS) do
        local isAvailable = checkItemAvailability(itemName)
        
        if isAvailable then
            table.insert(availableItems, itemName)
            
            if not shopItems[itemName] then
                -- Baru tersedia = RESTOCK!
                print("[AutoBuy] 🛒 RESTOCK:", itemName)
            end
            
            shopItems[itemName] = tick()
        else
            if shopItems[itemName] then
                print("[AutoBuy] 🚫 SOLD OUT:", itemName)
            end
            shopItems[itemName] = nil
        end
    end
    
    return availableItems
end

-- ──────────────────────────────────────────────────────────────────────
-- 7️⃣  Smart buy - Beli item yang tersedia dengan cooldown
-- ──────────────────────────────────────────────────────────────────────
local function processAvailableItems()
    local available = scanAllItems()
    
    if #available == 0 then return end
    
    -- Pilih item yang belum di-cooldown
    local now = tick()
    local buyTargets = {}
    
    for _, itemName in ipairs(available) do
        local lastBuy = buyHistory[itemName] or 0
        if now - lastBuy >= BUY_COOLDOWN then
            table.insert(buyTargets, itemName)
        end
    end
    
    -- Beli item (max 1 per scan biar gak spam)
    if #buyTargets > 0 then
        -- Pilih random biar natural
        local target = buyTargets[math.random(1, #buyTargets)]
        
        print("[AutoBuy] 🎯 Membeli:", target)
        local success = buyItem(target)
        
        if success then
            buyHistory[target] = now
            print("[AutoBuy] ✅ Berhasil:", target)
        end
    end
end

-- ──────────────────────────────────────────────────────────────────────
-- 8️⃣  State & Loop
-- ──────────────────────────────────────────────────────────────────────
local isRunning = false
local scanTask = nil

local function scanLoop()
    while isRunning do
        pcall(processAvailableItems)
        
        -- Jitter biar gak ketahuan pattern
        local delay = SCAN_INTERVAL + (math.random() - 0.5) * RANDOM_OFFSET
        task.wait(delay)
    end
end

local function startMonitoring()
    if isRunning then return end
    isRunning = true
    
    print("[AutoBuy] ▶️  Monitoring dimulai | Interval:", SCAN_INTERVAL, "s")
    
    -- Cache shop elements dulu
    cacheShopElements()
    
    -- Mulai scan loop
    scanTask = task.spawn(scanLoop)
end

local function stopMonitoring()
    if not isRunning then return end
    isRunning = false
    
    if scanTask then
        task.cancel(scanTask)
        scanTask = nil
    end
    
    shopItems = {}
    print("[AutoBuy] ⏹️  Stopped | Stats:", buyStats)
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
    mainFrame.Size = UDim2.new(0, 240, 0, 260)
    mainFrame.Position = UDim2.new(1, -250, 0.5, -130)
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
    titleText.Text = "🌿 AutoBuy Restock"
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
    
    local opcodeText = Instance.new("TextLabel")
    opcodeText.Size = UDim2.new(1, 0, 0, 20)
    opcodeText.Position = UDim2.new(0, 0, 0, 28)
    opcodeText.Text = "Opcode: " .. OPCODE .. " | Scan: " .. SCAN_INTERVAL .. "s"
    opcodeText.TextColor3 = Color3.fromRGB(150, 150, 150)
    opcodeText.Font = Enum.Font.Gotham
    opcodeText.TextSize = 10
    opcodeText.BackgroundTransparency = 1
    opcodeText.TextXAlignment = Enum.TextXAlignment.Center
    opcodeText.Parent = contentFrame
    
    -- Item List
    local itemListLabel = Instance.new("TextLabel")
    itemListLabel.Size = UDim2.new(1, 0, 0, 20)
    itemListLabel.Position = UDim2.new(0, 0, 0, 50)
    itemListLabel.Text = "📋 Items:"
    itemListLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    itemListLabel.Font = Enum.Font.GothamSemibold
    itemListLabel.TextSize = 11
    itemListLabel.BackgroundTransparency = 1
    itemListLabel.TextXAlignment = Enum.TextXAlignment.Left
    itemListLabel.Parent = contentFrame
    
    local itemList = Instance.new("ScrollingFrame")
    itemList.Size = UDim2.new(1, 0, 0, 90)
    itemList.Position = UDim2.new(0, 0, 0, 70)
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
    statsText.Position = UDim2.new(0, 0, 0, 165)
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
    toggleButton.Position = UDim2.new(0, 0, 0, 195)
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
            statusText.Text = "Status: 👀 MONITORING"
            statusText.TextColor3 = Color3.fromRGB(100, 200, 255)
            toggleButton.Text = "⏹ STOP"
            toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        else
            statusText.Text = "Status: ⏹️ OFF"
            statusText.TextColor3 = Color3.fromRGB(255, 100, 100)
            toggleButton.Text = "▶ START"
            toggleButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
        end
        
        -- Update item status
        for itemName, label in pairs(itemLabels) do
            if shopItems[itemName] then
                label.Text = "🟢 " .. itemName
                label.TextColor3 = Color3.fromRGB(100, 255, 100)
            else
                label.Text = "🔴 " .. itemName
                label.TextColor3 = Color3.fromRGB(255, 100, 100)
            end
        end
        
        statsText.Text = string.format("✅ %d | ❌ %d | 🔄 %d", 
            buyStats.success, buyStats.failed, buyStats.total)
    end
    
    -- Periodic UI refresh
    task.spawn(function()
        while screenGui.Parent do
            task.wait(1)
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
        mainFrame.Size = isMinimized and UDim2.new(0, 240, 0, 35) or UDim2.new(0, 240, 0, 270)
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
print("[AutoBuy] 🚀 Ready | Opcode:", OPCODE, "| Scan:", SCAN_INTERVAL, "s")
print("[AutoBuy] 💡 Scan interval", SCAN_INTERVAL, "detik - aman & efektif")
