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
    local countBefore = countItem("Carrot")
    for _, testOpcode in ipairs({133, 131, 130, 132, 134}) do
        local packetStr = string.char(testOpcode, 0, 6) .. "Carrot"
        pcall(function() packetRemote:FireServer(buffer.fromstring(packetStr)) end)
        task.wait(1)
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
-- 3️⃣  Target items
-- ──────────────────────────────────────────────────────────────────────
local TARGET_ITEMS = {
    "Hypno Bloom",
    "Dragon's Breath",
    "Sun Bloom",
    "Star Fruit",
    "Carrot"
}

-- ──────────────────────────────────────────────────────────────────────
-- 4️⃣  Build packet
-- ──────────────────────────────────────────────────────────────────────
local function buildPacket(itemName)
    return buffer.fromstring(string.char(OPCODE, 0, #itemName) .. itemName)
end

-- ──────────────────────────────────────────────────────────────────────
-- 5️⃣  Buy function
-- ──────────────────────────────────────────────────────────────────────
local function buyItem(itemName)
    local packet = buildPacket(itemName)
    local success, err = pcall(function()
        packetRemote:FireServer(packet)
    end)
    return success, err
end

-- ──────────────────────────────────────────────────────────────────────
-- 6️⃣  AMAN: Hook OnClientEvent untuk deteksi restock
-- ──────────────────────────────────────────────────────────────────────
local shopItems = {}
local buyHistory = {}
local BUY_COOLDOWN = 2

-- Cara 1: Listen server response (PALING AMAN - gak scan GUI)
packetRemote.OnClientEvent:Connect(function(response)
    -- Coba parse response sebagai data shop/restock
    if typeof(response) == "buffer" then
        -- Coba baca sebagai string
        local str = ""
        for i = 0, buffer.len(response) - 1 do
            local byte = buffer.readu8(response, i)
            if byte >= 32 and byte <= 126 then
                str = str .. string.char(byte)
            end
        end
        
        -- Cek apakah response mengandung nama item target
        for _, itemName in ipairs(TARGET_ITEMS) do
            if str:find(itemName) then
                print("[AutoBuy] 🛒 Restock terdeteksi via server:", itemName)
                onItemAvailable(itemName)
                break
            end
        end
    elseif typeof(response) == "table" then
        -- Response table (mungkin data shop)
        for _, itemName in ipairs(TARGET_ITEMS) do
            if response[itemName] or (response.Name and response.Name == itemName) then
                print("[AutoBuy] 🛒 Restock terdeteksi via table:", itemName)
                onItemAvailable(itemName)
                break
            end
        end
    end
end)

-- Cara 2: Hook GUI updates (lebih aman daripada scan)
local guiConnections = {}

local function hookShopGUI()
    -- Cari TextLabel yang mungkin menampilkan nama item
    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, element in ipairs(gui:GetDescendants()) do
                if element:IsA("TextLabel") or element:IsA("TextButton") then
                    local text = element.Text
                    
                    -- Cek apakah mengandung nama item target
                    for _, itemName in ipairs(TARGET_ITEMS) do
                        if text:find(itemName) and not guiConnections[element] then
                            -- Hook perubahan text
                            local conn = element:GetPropertyChangedSignal("Text"):Connect(function()
                                local newText = element.Text
                                if newText:find(itemName) then
                                    -- Cek apakah text berubah jadi available
                                    local oldText = shopItems[itemName] and shopItems[itemName].text or ""
                                    if newText ~= oldText and not newText:lower():find("sold") then
                                        print("[AutoBuy] 🛒 GUI update:", itemName)
                                        shopItems[itemName] = {text = newText, time = tick()}
                                        onItemAvailable(itemName)
                                    end
                                end
                            end)
                            guiConnections[element] = conn
                        end
                    end
                end
            end
        end
    end
end

-- Cara 3: Hook backpack changes (deteksi item baru)
local backpackConnection
local function hookBackpack()
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return end
    
    backpackConnection = backpack.ChildAdded:Connect(function(child)
        -- Kalau item target masuk backpack, berarti berhasil beli
        for _, itemName in ipairs(TARGET_ITEMS) do
            if child.Name == itemName then
                print("[AutoBuy] ✅", itemName, "masuk backpack!")
                buyHistory[itemName] = tick()
            end
        end
    end)
end

-- ──────────────────────────────────────────────────────────────────────
-- 7️⃣  Logic: Beli saat item tersedia
-- ──────────────────────────────────────────────────────────────────────
local function onItemAvailable(itemName)
    local now = tick()
    local lastBuy = buyHistory[itemName] or 0
    
    -- Cek cooldown
    if now - lastBuy < BUY_COOLDOWN then return end
    
    -- Cek apakah masih di cooldown global (hindari burst)
    if onItemAvailable._globalCooldown and now - onItemAvailable._globalCooldown < 0.5 then return end
    onItemAvailable._globalCooldown = now
    
    print("[AutoBuy] 🎯 Beli:", itemName)
    
    task.delay(math.random() * 0.5, function()  -- Jitter kecil
        local success, err = buyItem(itemName)
        if success then
            buyHistory[itemName] = now
            print("[AutoBuy] ✅ Berhasil:", itemName)
        else
            warn("[AutoBuy] ❌ Gagal:", itemName, err)
        end
    end)
end

-- ──────────────────────────────────────────────────────────────────────
-- 8️⃣  State
-- ──────────────────────────────────────────────────────────────────────
local isRunning = false

local function startMonitoring()
    if isRunning then return end
    isRunning = true
    
    print("[AutoBuy] 👀 Passive monitoring aktif...")
    
    -- Hook GUI (sekali aja)
    hookShopGUI()
    
    -- Hook backpack
    hookBackpack()
    
    print("[AutoBuy] ✅ Menunggu notifikasi restock...")
end

local function stopMonitoring()
    isRunning = false
    
    -- Cleanup GUI hooks
    for element, conn in pairs(guiConnections) do
        conn:Disconnect()
    end
    guiConnections = {}
    
    -- Cleanup backpack hook
    if backpackConnection then
        backpackConnection:Disconnect()
        backpackConnection = nil
    end
    
    shopItems = {}
    print("[AutoBuy] ⏹️  Stopped")
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
    mainFrame.Size = UDim2.new(0, 240, 0, 200)
    mainFrame.Position = UDim2.new(1, -250, 0.5, -100)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = mainFrame
    
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
    titleText.Text = "🌿 AutoBuy Passive"
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
    
    local methodText = Instance.new("TextLabel")
    methodText.Size = UDim2.new(1, 0, 0, 30)
    methodText.Position = UDim2.new(0, 0, 0, 30)
    methodText.Text = "Method: Event Hook (Safe)"
    methodText.TextColor3 = Color3.fromRGB(100, 255, 100)
    methodText.Font = Enum.Font.Gotham
    methodText.TextSize = 11
    methodText.BackgroundTransparency = 1
    methodText.TextXAlignment = Enum.TextXAlignment.Center
    methodText.Parent = contentFrame
    
    local infoText = Instance.new("TextLabel")
    infoText.Size = UDim2.new(1, 0, 0, 40)
    infoText.Position = UDim2.new(0, 0, 0, 60)
    infoText.Text = "No scanning\nPassive detection via events"
    infoText.TextColor3 = Color3.fromRGB(150, 150, 150)
    infoText.Font = Enum.Font.Gotham
    infoText.TextSize = 10
    infoText.BackgroundTransparency = 1
    infoText.TextXAlignment = Enum.TextXAlignment.Center
    infoText.Parent = contentFrame
    
    local itemsText = Instance.new("TextLabel")
    itemsText.Size = UDim2.new(1, 0, 0, 20)
    itemsText.Position = UDim2.new(0, 0, 0, 105)
    itemsText.Text = "Target: " .. #TARGET_ITEMS .. " items"
    itemsText.TextColor3 = Color3.fromRGB(150, 150, 150)
    itemsText.Font = Enum.Font.Gotham
    itemsText.TextSize = 11
    itemsText.BackgroundTransparency = 1
    itemsText.TextXAlignment = Enum.TextXAlignment.Center
    itemsText.Parent = contentFrame
    
    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(1, 0, 0, 40)
    toggleButton.Position = UDim2.new(0, 0, 0, 135)
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
    
    local function updateUI()
        if isRunning then
            statusText.Text = "Status: 👀 LISTENING"
            statusText.TextColor3 = Color3.fromRGB(100, 200, 255)
            toggleButton.Text = "⏹ STOP"
            toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        else
            statusText.Text = "Status: ⏹️ OFF"
            statusText.TextColor3 = Color3.fromRGB(255, 100, 100)
            toggleButton.Text = "▶ START"
            toggleButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
        end
    end
    
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
        mainFrame.Size = isMinimized and UDim2.new(0, 240, 0, 35) or UDim2.new(0, 240, 0, 215)
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
print("[AutoBuy] 🚀 Passive AutoBuy Loaded | Opcode:", OPCODE)
print("[AutoBuy] 🛡️  Safe mode: No active scanning, only event hook")
