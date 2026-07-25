-- ──────────────────────────────────────────────────────────────────────
-- 1️⃣  Services & References
-- ──────────────────────────────────────────────────────────────────────
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local packetRemote = ReplicatedStorage:WaitForChild("SharedModules")
    :WaitForChild("Packet")
    :WaitForChild("RemoteEvent")

print("[AutoBuy] RemoteEvent:", packetRemote:GetFullName())

-- ──────────────────────────────────────────────────────────────────────
-- 2️⃣  Auto-detect opcode (RUN ONCE, READ ONLY)
-- ──────────────────────────────────────────────────────────────────────
local function detectOpcode()
    local connections = getconnections or debug.getconnections
    
    if connections and packetRemote.OnServerEvent then
        local conns = connections(packetRemote.OnServerEvent)
        for _, conn in ipairs(conns) do
            local func = conn.Function
            if func then
                local success, upvalues = pcall(debug.getupvalues, func)
                if success then
                    for _, upval in ipairs(upvalues) do
                        if type(upval) == "number" and upval >= 100 and upval <= 200 then
                            print("[AutoBuy] ✅ Opcode dari OnServerEvent:", upval)
                            return upval
                        end
                    end
                end
            end
        end
    end
    
    local sharedModules = ReplicatedStorage:FindFirstChild("SharedModules")
    if sharedModules then
        local packetModule = sharedModules:FindFirstChild("Packet")
        if packetModule and packetModule:IsA("ModuleScript") then
            local success, module = pcall(require, packetModule)
            if success and type(module) == "table" then
                for key, value in pairs(module) do
                    if type(value) == "number" and value >= 100 and value <= 200 then
                        print("[AutoBuy] ✅ Opcode dari Packet module:", value)
                        return value
                    end
                end
            end
        end
    end
    
    local configNames = {"NetworkConfig", "Config", "Settings", "Constants"}
    for _, name in ipairs(configNames) do
        local config = ReplicatedStorage:FindFirstChild(name)
        if config and config:IsA("ModuleScript") then
            local success, data = pcall(require, config)
            if success and type(data) == "table" then
                for key, value in pairs(data) do
                    if type(value) == "number" and value >= 100 and value <= 200 then
                        print("[AutoBuy] ✅ Opcode dari", name, ":", value)
                        return value
                    end
                end
            end
        end
    end
    
    warn("[AutoBuy] ⚠️  Opcode tidak terdeteksi, menggunakan default 133")
    return 133
end

local OPCODE = detectOpcode()
print("[AutoBuy] 🔢 Opcode:", OPCODE)

-- ──────────────────────────────────────────────────────────────────────
-- 3️⃣  Items & Config
-- ──────────────────────────────────────────────────────────────────────
local ITEMS = {
    "Hypno Bloom",
    "Dragon's Breath",
    "Sun Bloom",
    "Star Fruit",
    "Carrot",
}

local MIN_DELAY = 5
local MAX_DELAY = 15

-- ──────────────────────────────────────────────────────────────────────
-- 4️⃣  Build packet
-- ──────────────────────────────────────────────────────────────────────
local function buildPacket(itemName)
    local len = #itemName
    return string.char(OPCODE, 0, len) .. itemName
end

-- ──────────────────────────────────────────────────────────────────────
-- 5️⃣  State
-- ──────────────────────────────────────────────────────────────────────
local isRunning = false
local buyTasks = {}  -- Simpan task.delay yang aktif

-- ──────────────────────────────────────────────────────────────────────
-- 6️⃣  Auto-buy loop
-- ──────────────────────────────────────────────────────────────────────
local function buyLoop(itemName, count)
    if not isRunning then return end  -- Stop kalau toggle off
    
    count = count or 1
    
    -- Kirim packet
    local packet = buildPacket(itemName)
    local success, err = pcall(function()
        packetRemote:FireServer(packet)
    end)
    
    if success then
        print("[AutoBuy] ✅", itemName, "| #" .. count)
    else
        warn("[AutoBuy] ❌", itemName, "| #" .. count, "|", err)
    end
    
    -- JITTER delay
    local baseDelay = MIN_DELAY + math.random() * (MAX_DELAY - MIN_DELAY)
    local jitter = (math.random() - 0.5) * 2
    local waitTime = math.max(MIN_DELAY, baseDelay + jitter)
    
    -- Schedule next buy & simpan reference
    buyTasks[itemName] = task.delay(waitTime, function()
        buyLoop(itemName, count + 1)
    end)
end

-- ──────────────────────────────────────────────────────────────────────
-- 7️⃣  Start / Stop functions
-- ──────────────────────────────────────────────────────────────────────
local function startAutoBuy()
    if isRunning then return end
    isRunning = true
    print("[AutoBuy] ▶️  STARTED")
    
    for _, item in ipairs(ITEMS) do
        local initialJitter = math.random() * 8
        buyTasks[item] = task.delay(initialJitter, function()
            if isRunning then
                buyLoop(item)
            end
        end)
    end
end

local function stopAutoBuy()
    if not isRunning then return end
    isRunning = false
    
    -- Cancel semua task yang pending
    for itemName, taskRef in pairs(buyTasks) do
        task.cancel(taskRef)
    end
    buyTasks = {}
    
    print("[AutoBuy] ⏹️  STOPPED")
end

-- ──────────────────────────────────────────────────────────────────────
-- 8️⃣  GUI Creation
-- ──────────────────────────────────────────────────────────────────────
local function createGUI()
    -- ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoBuyGUI"
    screenGui.Parent = playerGui
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 220, 0, 180)
    mainFrame.Position = UDim2.new(1, -230, 0.5, -90)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.Parent = screenGui
    
    -- Corner
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = mainFrame
    
    -- Shadow
    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 4, 1, 4)
    shadow.Position = UDim2.new(0, -2, 0, -2)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.5
    shadow.BorderSizePixel = 0
    shadow.ZIndex = 0
    shadow.Parent = mainFrame
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 10)
    shadowCorner.Parent = shadow
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleBar
    
    -- Title Text
    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -40, 1, 0)
    titleText.Position = UDim2.new(0, 15, 0, 0)
    titleText.Text = "🌿 AutoBuy Farm"
    titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 16
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.BackgroundTransparency = 1
    titleText.Parent = titleBar
    
    -- Close Button
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 2)
    closeButton.Text = "✕"
    closeButton.TextColor3 = Color3.fromRGB(255, 100, 100)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 18
    closeButton.BackgroundTransparency = 1
    closeButton.Parent = titleBar
    
    -- Minimize Button
    local minimizeButton = Instance.new("TextButton")
    minimizeButton.Size = UDim2.new(0, 30, 0, 30)
    minimizeButton.Position = UDim2.new(1, -65, 0, 2)
    minimizeButton.Text = "─"
    minimizeButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    minimizeButton.Font = Enum.Font.GothamBold
    minimizeButton.TextSize = 18
    minimizeButton.BackgroundTransparency = 1
    minimizeButton.Parent = titleBar
    
    -- Content Frame
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -20, 1, -80)
    contentFrame.Position = UDim2.new(0, 10, 0, 45)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame
    
    -- Status Text
    local statusText = Instance.new("TextLabel")
    statusText.Name = "StatusText"
    statusText.Size = UDim2.new(1, 0, 0, 30)
    statusText.Text = "Status: ⏹️ OFF"
    statusText.TextColor3 = Color3.fromRGB(255, 100, 100)
    statusText.Font = Enum.Font.GothamSemibold
    statusText.TextSize = 14
    statusText.BackgroundTransparency = 1
    statusText.TextXAlignment = Enum.TextXAlignment.Center
    statusText.Parent = contentFrame
    
    -- Opcode Text
    local opcodeText = Instance.new("TextLabel")
    opcodeText.Name = "OpcodeText"
    opcodeText.Size = UDim2.new(1, 0, 0, 25)
    opcodeText.Position = UDim2.new(0, 0, 0, 35)
    opcodeText.Text = "Opcode: " .. OPCODE
    opcodeText.TextColor3 = Color3.fromRGB(150, 150, 150)
    opcodeText.Font = Enum.Font.Gotham
    opcodeText.TextSize = 12
    opcodeText.BackgroundTransparency = 1
    opcodeText.TextXAlignment = Enum.TextXAlignment.Center
    opcodeText.Parent = contentFrame
    
    -- Toggle Button
    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleButton"
    toggleButton.Size = UDim2.new(1, 0, 0, 40)
    toggleButton.Position = UDim2.new(0, 0, 0, 70)
    toggleButton.Text = "▶ START"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.TextSize = 16
    toggleButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    toggleButton.BorderSizePixel = 0
    toggleButton.Parent = contentFrame
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 8)
    buttonCorner.Parent = toggleButton
    
    -- Toggle Button Function
    local function updateUI()
        if isRunning then
            statusText.Text = "Status: ▶️ RUNNING"
            statusText.TextColor3 = Color3.fromRGB(100, 255, 100)
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
            stopAutoBuy()
        else
            startAutoBuy()
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
    
    -- Minimize function
    local isMinimized = false
    minimizeButton.MouseButton1Click:Connect(function()
        isMinimized = not isMinimized
        if isMinimized then
            contentFrame.Visible = false
            mainFrame.Size = UDim2.new(0, 220, 0, 35)
            minimizeButton.Text = "□"
        else
            contentFrame.Visible = true
            mainFrame.Size = UDim2.new(0, 220, 0, 180)
            minimizeButton.Text = "─"
        end
    end)
    
    -- Close button
    closeButton.MouseButton1Click:Connect(function()
        stopAutoBuy()
        screenGui:Destroy()
    end)
    
    -- Initial update
    updateUI()
    
    print("[AutoBuy] 🖥️  GUI Loaded")
end

-- ──────────────────────────────────────────────────────────────────────
-- 9️⃣  Start GUI
-- ──────────────────────────────────────────────────────────────────────
createGUI()
print("[AutoBuy] 🚀 Script Loaded | Items:", #ITEMS, "| Opcode:", OPCODE)
