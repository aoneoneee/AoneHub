-- ──────────────────────────────────────────────────────────────────────
-- AONEHUB GUI SYSTEM
-- ──────────────────────────────────────────────────────────────────────

-- 1️⃣ Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 2️⃣ Main GUI Variables
local screenGui
local mainFrame
local tabButtons = {}
local tabFrames = {}
local currentTab = nil
local isMinimized = false

-- 3️⃣ Colors
local colors = {
    background = Color3.fromRGB(20, 20, 25),
    sidebar = Color3.fromRGB(25, 25, 32),
    accent = Color3.fromRGB(100, 150, 255),
    accentHover = Color3.fromRGB(130, 170, 255),
    text = Color3.fromRGB(255, 255, 255),
    textDim = Color3.fromRGB(180, 180, 190),
    tabActive = Color3.fromRGB(35, 35, 45),
    tabInactive = Color3.fromRGB(25, 25, 32),
    tabHover = Color3.fromRGB(40, 40, 50),
    button = Color3.fromRGB(50, 200, 50),
    buttonHover = Color3.fromRGB(70, 220, 70),
    buttonStop = Color3.fromRGB(200, 50, 50),
    buttonStopHover = Color3.fromRGB(220, 70, 70),
}

-- 4️⃣ Create GUI
local function createGUI()
    -- ScreenGui
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AoneHub"
    screenGui.Parent = playerGui
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- ==================================================================
    -- MINIMIZED CIRCLE "AH"
    -- ==================================================================
    local minimizedCircle = Instance.new("Frame")
    minimizedCircle.Name = "MinimizedCircle"
    minimizedCircle.Size = UDim2.new(0, 50, 0, 50)
    minimizedCircle.Position = UDim2.new(0.5, -25, 0.5, -25)
    minimizedCircle.BackgroundColor3 = colors.accent
    minimizedCircle.BorderSizePixel = 0
    minimizedCircle.Visible = false
    minimizedCircle.ZIndex = 10
    minimizedCircle.Parent = screenGui
    
    local circleCorner = Instance.new("UICorner")
    circleCorner.CornerRadius = UDim.new(1, 0)
    circleCorner.Parent = minimizedCircle
    
    local circleText = Instance.new("TextLabel")
    circleText.Size = UDim2.new(1, 0, 1, 0)
    circleText.Text = "AH"
    circleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    circleText.Font = Enum.Font.GothamBlack
    circleText.TextSize = 20
    circleText.BackgroundTransparency = 1
    circleText.Parent = minimizedCircle
    
    -- ==================================================================
    -- MAIN FRAME
    -- ==================================================================
    mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 650, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -325, 0.5, -200)
    mainFrame.BackgroundColor3 = colors.background
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = mainFrame
    
    -- Outer shadow
    local shadow = Instance.new("Frame")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 6, 1, 6)
    shadow.Position = UDim2.new(0, -3, 0, -3)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.5
    shadow.BorderSizePixel = 0
    shadow.ZIndex = -1
    shadow.Parent = mainFrame
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 13)
    shadowCorner.Parent = shadow
    
    -- ==================================================================
    -- TITLE BAR (Draggable)
    -- ==================================================================
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    -- Bottom fill (biar corner cuma di atas)
    local titleFill = Instance.new("Frame")
    titleFill.Size = UDim2.new(1, 0, 0.5, 0)
    titleFill.Position = UDim2.new(0, 0, 0.5, 0)
    titleFill.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    titleFill.BorderSizePixel = 0
    titleFill.Parent = titleBar
    
    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(0.7, 0, 1, 0)
    titleText.Position = UDim2.new(0, 15, 0, 0)
    titleText.Text = "AoneHub"
    titleText.TextColor3 = colors.text
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 15
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.BackgroundTransparency = 1
    titleText.Parent = titleBar
    
    -- Control buttons container
    local controls = Instance.new("Frame")
    controls.Size = UDim2.new(0, 70, 1, 0)
    controls.Position = UDim2.new(1, -75, 0, 0)
    controls.BackgroundTransparency = 1
    controls.Parent = titleBar
    
    -- Minimize button
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 28, 0, 28)
    minimizeBtn.Position = UDim2.new(0, 0, 0.5, -14)
    minimizeBtn.Text = "–"
    minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 20
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Parent = controls
    
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 6)
    minCorner.Parent = minimizeBtn
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(0, 34, 0.5, -14)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = controls
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    
    -- ==================================================================
    -- SIDEBAR (1/4 kiri)
    -- ==================================================================
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0.25, 0, 1, -40)
    sidebar.Position = UDim2.new(0, 0, 0, 40)
    sidebar.BackgroundColor3 = colors.sidebar
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainFrame
    
    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim.new(0, 12)
    sidebarCorner.Parent = sidebar
    
    -- Fill top sidebar corner
    local sidebarFill = Instance.new("Frame")
    sidebarFill.Size = UDim2.new(1, 0, 0.02, 0)
    sidebarFill.BackgroundColor3 = colors.sidebar
    sidebarFill.BorderSizePixel = 0
    sidebarFill.Parent = sidebar
    
    -- Sidebar title
    local sidebarTitle = Instance.new("TextLabel")
    sidebarTitle.Size = UDim2.new(1, 0, 0, 35)
    sidebarTitle.Position = UDim2.new(0, 0, 0, 10)
    sidebarTitle.Text = "Menu"
    sidebarTitle.TextColor3 = colors.textDim
    sidebarTitle.Font = Enum.Font.GothamSemibold
    sidebarTitle.TextSize = 12
    sidebarTitle.TextXAlignment = Enum.TextXAlignment.Center
    sidebarTitle.BackgroundTransparency = 1
    sidebarTitle.Parent = sidebar
    
    -- Separator
    local separator = Instance.new("Frame")
    separator.Size = UDim2.new(0.8, 0, 0, 1)
    separator.Position = UDim2.new(0.1, 0, 0, 45)
    separator.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    separator.BorderSizePixel = 0
    separator.Parent = sidebar
    
    -- ==================================================================
    -- TAB BUTTONS
    -- ==================================================================
    local tabs = {
        {name = "Auto Buy", icon = "🛒"},
        {name = "Auto Mail", icon = "📧"},
        {name = "Ekstra", icon = "⚙️"},
    }
    
    local tabContainer = Instance.new("Frame")
    tabContainer.Size = UDim2.new(1, 0, 0.7, 0)
    tabContainer.Position = UDim2.new(0, 0, 0, 55)
    tabContainer.BackgroundTransparency = 1
    tabContainer.Parent = sidebar
    
    for i, tab in ipairs(tabs) do
        local tabBtn = Instance.new("TextButton")
        tabBtn.Name = "TabButton_" .. tab.name
        tabBtn.Size = UDim2.new(0.85, 0, 0, 40)
        tabBtn.Position = UDim2.new(0.075, 0, 0, (i-1) * 48 + 5)
        tabBtn.Text = "  " .. tab.icon .. "  " .. tab.name
        tabBtn.TextColor3 = colors.textDim
        tabBtn.Font = Enum.Font.GothamSemibold
        tabBtn.TextSize = 13
        tabBtn.TextXAlignment = Enum.TextXAlignment.Left
        tabBtn.BackgroundColor3 = colors.tabInactive
        tabBtn.BorderSizePixel = 0
        tabBtn.AutoButtonColor = false
        tabBtn.Parent = tabContainer
        
        local tabCorner = Instance.new("UICorner")
        tabCorner.CornerRadius = UDim.new(0, 8)
        tabCorner.Parent = tabBtn
        
        -- Hover effect
        tabBtn.MouseEnter:Connect(function()
            if currentTab ~= tab.name then
                tabBtn.BackgroundColor3 = colors.tabHover
            end
        end)
        
        tabBtn.MouseLeave:Connect(function()
            if currentTab ~= tab.name then
                tabBtn.BackgroundColor3 = colors.tabInactive
            end
        end)
        
        tabButtons[tab.name] = tabBtn
    end
    
    -- ==================================================================
    -- CONTENT AREA (3/4 kanan)
    -- ==================================================================
    local contentArea = Instance.new("Frame")
    contentArea.Name = "ContentArea"
    contentArea.Size = UDim2.new(0.75, -10, 1, -50)
    contentArea.Position = UDim2.new(0.25, 5, 0, 45)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = mainFrame
    
    -- ==================================================================
    -- DEFAULT FRAME (sebelum tab diklik)
    -- ==================================================================
    local defaultFrame = Instance.new("Frame")
    defaultFrame.Name = "DefaultFrame"
    defaultFrame.Size = UDim2.new(1, 0, 1, 0)
    defaultFrame.BackgroundTransparency = 1
    defaultFrame.Parent = contentArea
    
    -- Logo
    local logoText = Instance.new("TextLabel")
    logoText.Size = UDim2.new(1, 0, 0, 60)
    logoText.Position = UDim2.new(0, 0, 0.4, -30)
    logoText.Text = "AoneHub"
    logoText.TextColor3 = colors.accent
    logoText.Font = Enum.Font.GothamBlack
    logoText.TextSize = 40
    logoText.BackgroundTransparency = 1
    logoText.Parent = defaultFrame
    
    -- Subtitle
    local subText = Instance.new("TextLabel")
    subText.Size = UDim2.new(1, 0, 0, 25)
    subText.Position = UDim2.new(0, 0, 0.5, 10)
    subText.Text = "Select a tab to begin"
    subText.TextColor3 = colors.textDim
    subText.Font = Enum.Font.Gotham
    subText.TextSize = 14
    subText.BackgroundTransparency = 1
    subText.Parent = defaultFrame
    
    -- Decorative line
    local line = Instance.new("Frame")
    line.Size = UDim2.new(0, 100, 0, 3)
    line.Position = UDim2.new(0.5, -50, 0.55, 0)
    line.BackgroundColor3 = colors.accent
    line.BorderSizePixel = 0
    line.Parent = defaultFrame
    
    local lineCorner = Instance.new("UICorner")
    lineCorner.CornerRadius = UDim.new(1, 0)
    lineCorner.Parent = line
    
    -- ==================================================================
    -- TAB FRAMES (dibuat tapi hidden dulu)
    -- ==================================================================
    for _, tab in ipairs(tabs) do
        local tabFrame = Instance.new("Frame")
        tabFrame.Name = "TabFrame_" .. tab.name
        tabFrame.Size = UDim2.new(1, 0, 1, 0)
        tabFrame.BackgroundTransparency = 1
        tabFrame.Visible = false
        tabFrame.Parent = contentArea
        tabFrames[tab.name] = tabFrame
    end
    
    -- ==================================================================
    -- TAB CLICK HANDLER
    -- ==================================================================
    local function switchTab(tabName)
        -- Hide all frames
        defaultFrame.Visible = false
        for _, frame in pairs(tabFrames) do
            frame.Visible = false
        end
        
        -- Reset all tab buttons
        for _, btn in pairs(tabButtons) do
            btn.BackgroundColor3 = colors.tabInactive
            btn.TextColor3 = colors.textDim
        end
        
        -- Show selected
        if tabFrames[tabName] then
            tabFrames[tabName].Visible = true
            tabButtons[tabName].BackgroundColor3 = colors.tabActive
            tabButtons[tabName].TextColor3 = colors.accent
            currentTab = tabName
        end
    end
    
    for _, tab in ipairs(tabs) do
        tabButtons[tab.name].MouseButton1Click:Connect(function()
            switchTab(tab.name)
        end)
    end
    
    -- ==================================================================
    -- DRAGGING (untuk main frame)
    -- ==================================================================
    local dragging = false
    local dragStart = nil
    local frameStart = nil
    local dragTarget = nil  -- Bisa mainFrame atau minimizedCircle
    
    local function startDrag(input, target)
        dragging = true
        dragStart = input.Position
        frameStart = target.Position
        dragTarget = target
    end
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            startDrag(input, mainFrame)
        end
    end)
    
    minimizedCircle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            startDrag(input, minimizedCircle)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and dragTarget and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            dragTarget.Position = UDim2.new(
                frameStart.X.Scale,
                frameStart.X.Offset + delta.X,
                frameStart.Y.Scale,
                frameStart.Y.Offset + delta.Y
            )
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            dragTarget = nil
        end
    end)
    
    -- ==================================================================
    -- MINIMIZE / RESTORE
    -- ==================================================================
    local function minimize()
        isMinimized = true
        mainFrame.Visible = false
        minimizedCircle.Visible = true
    end
    
    local function restore()
        isMinimized = false
        mainFrame.Visible = true
        minimizedCircle.Visible = false
    end
    
    minimizeBtn.MouseButton1Click:Connect(minimize)
    minimizedCircle.MouseButton1Click:Connect(restore)
    
    -- Double click minimized circle to restore
    local lastClickTime = 0
    minimizedCircle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local now = tick()
            if now - lastClickTime < 0.3 then
                restore()
            end
            lastClickTime = now
        end
    end)
    
    -- ==================================================================
    -- CLOSE / DESTROY
    -- ==================================================================
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    -- ==================================================================
    -- POPULATE TAB 1: AUTO BUY (Script dari sebelumnya)
    -- ==================================================================
    populateAutoBuyTab(tabFrames["Auto Buy"])
    
    -- ==================================================================
    -- POPULATE TAB 2 & 3 (Placeholder)
    -- ==================================================================
    populatePlaceholderTab(tabFrames["Auto Mail"], "📧", "Auto Mail", "Coming soon...")
    populatePlaceholderTab(tabFrames["Ekstra"], "⚙️", "Ekstra", "Coming soon...")
    
    print("[AoneHub] 🖥️  GUI Loaded")
    return screenGui
end

-- ==================================================================
-- TAB 1: AUTO BUY SCRIPT (Diintegrasikan ke dalam frame)
-- ==================================================================
function populateAutoBuyTab(parentFrame)
    -- Ini script auto buy lengkap (di-compress ke dalam fungsi)
    
    local function setupAutoBuy()
        local packetRemote = ReplicatedStorage:WaitForChild("SharedModules")
            :WaitForChild("Packet")
            :WaitForChild("RemoteEvent")
        
        local OPCODE = 133
        local TARGET_ITEMS = {"Hypno Bloom", "Dragon's Breath", "Sun Bloom", "Star Fruit"}
        local RESTOCK_INTERVAL = 300
        local JITTER_MIN = 3
        local JITTER_MAX = 5
        local BUY_JITTER_MIN = 0.3
        local BUY_JITTER_MAX = 0.8
        local buyStats = {total = 0, success = 0, failed = 0}
        local buyHistory = {}
        local shopElements = {}
        local isRunning = false
        local isBuying = false
        local itemStatus = {}
        local nextScanTime = 0
        local scanCount = 0
        
        -- Build packet
        local function buildPacket(itemName)
            return buffer.fromstring(string.char(OPCODE, 0, #itemName) .. itemName)
        end
        
        -- Buy item
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
        
        -- Cache shop elements
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
                        local mainFrame = itemContainer:FindFirstChild("Main_Frame") or itemContainer:FindFirstChild("MainFrame")
                        if mainFrame then
                            local costText = mainFrame:FindFirstChild("Cost_Text") or mainFrame:FindFirstChild("CostText")
                            if costText then
                                shopElements[itemName] = {container = itemContainer, costText = costText}
                            end
                        end
                    end
                end
            end
            local count = 0
            for _ in pairs(shopElements) do count += 1 end
            print("[AutoBuy] 📋 Shop cached:", count, "items")
        end
        
        -- Check availability
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
        
        -- Timing
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
        
        -- Borong semua
        local function buyAllAvailable()
            if isBuying then return end
            isBuying = true
            local totalBought = 0
            while isRunning do
                local boughtAny = false
                for _, itemName in ipairs(TARGET_ITEMS) do
                    if not isRunning then break end
                    if isItemAvailable(itemName) then
                        if buyItem(itemName) then
                            totalBought += 1
                            boughtAny = true
                            itemStatus[itemName] = "stock"
                            local delay = BUY_JITTER_MIN + math.random() * (BUY_JITTER_MAX - BUY_JITTER_MIN)
                            task.wait(delay)
                        else
                            itemStatus[itemName] = "nostock"
                            task.wait(0.2)
                        end
                    else
                        itemStatus[itemName] = "nostock"
                    end
                end
                if not boughtAny then break end
                task.wait(0.2)
            end
            print("[AutoBuy] ✅ SESI SELESAI - Dibeli:", totalBought)
            isBuying = false
            updateUI()
        end
        
        local function scanAndBuy()
            scanCount += 1
            cacheShopElements()
            if next(shopElements) == nil then return end
            buyHistory = {}
            local anyAvailable = false
            for _, itemName in ipairs(TARGET_ITEMS) do
                if isItemAvailable(itemName) then
                    anyAvailable = true
                    itemStatus[itemName] = "stock"
                else
                    itemStatus[itemName] = "nostock"
                end
            end
            updateUI()
            if anyAvailable then
                buyAllAvailable()
            end
        end
        
        local function mainLoop()
            while isRunning do
                local waitTime = getSecondsUntilNextRestock()
                nextScanTime = os.time() + waitTime
                updateUI()
                task.wait(waitTime)
                if not isRunning then break end
                pcall(scanAndBuy)
                task.wait(1)
            end
        end
        
        local function startMonitoring()
            if isRunning then return end
            isRunning = true
            cacheShopElements()
            pcall(scanAndBuy)
            task.spawn(mainLoop)
            updateUI()
        end
        
        local function stopMonitoring()
            isRunning = false
            itemStatus = {}
            updateUI()
        end
        
        -- ==================================================================
        -- GUI ELEMENTS INSIDE TAB 1
        -- ==================================================================
        
        -- Clear placeholder
        for _, child in ipairs(parentFrame:GetChildren()) do
            child:Destroy()
        end
        
        -- Scrollable container
        local scrollFrame = Instance.new("ScrollingFrame")
        scrollFrame.Size = UDim2.new(1, 0, 1, 0)
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 620)
        scrollFrame.ScrollBarThickness = 4
        scrollFrame.BackgroundTransparency = 1
        scrollFrame.Parent = parentFrame
        
        local y = 5
        
        -- Header
        local header = Instance.new("TextLabel")
        header.Size = UDim2.new(1, 0, 0, 30)
        header.Position = UDim2.new(0, 10, 0, y)
        header.Text = "🛒 Auto Buy Borong"
        header.TextColor3 = Color3.fromRGB(255, 255, 255)
        header.Font = Enum.Font.GothamBold
        header.TextSize = 18
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.BackgroundTransparency = 1
        header.Parent = scrollFrame
        y += 35
        
        -- Status
        local statusText = Instance.new("TextLabel")
        statusText.Name = "StatusText"
        statusText.Size = UDim2.new(1, -20, 0, 25)
        statusText.Position = UDim2.new(0, 10, 0, y)
        statusText.Text = "Status: ⏹️ OFF"
        statusText.TextColor3 = Color3.fromRGB(255, 100, 100)
        statusText.Font = Enum.Font.GothamSemibold
        statusText.TextSize = 13
        statusText.TextXAlignment = Enum.TextXAlignment.Left
        statusText.BackgroundTransparency = 1
        statusText.Parent = scrollFrame
        y += 30
        
        -- Opcode
        local opcodeFrame = Instance.new("Frame")
        opcodeFrame.Size = UDim2.new(1, -20, 0, 28)
        opcodeFrame.Position = UDim2.new(0, 10, 0, y)
        opcodeFrame.BackgroundTransparency = 1
        opcodeFrame.Parent = scrollFrame
        
        local opcodeLabel = Instance.new("TextLabel")
        opcodeLabel.Size = UDim2.new(0, 55, 1, 0)
        opcodeLabel.Text = "Opcode:"
        opcodeLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
        opcodeLabel.Font = Enum.Font.Gotham
        opcodeLabel.TextSize = 12
        opcodeLabel.BackgroundTransparency = 1
        opcodeLabel.Parent = opcodeFrame
        
        local opcodeInput = Instance.new("TextBox")
        opcodeInput.Size = UDim2.new(0, 70, 1, 0)
        opcodeInput.Position = UDim2.new(0, 58, 0, 0)
        opcodeInput.Text = tostring(OPCODE)
        opcodeInput.TextColor3 = Color3.fromRGB(255, 255, 255)
        opcodeInput.Font = Enum.Font.GothamBold
        opcodeInput.TextSize = 13
        opcodeInput.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        opcodeInput.BorderSizePixel = 0
        opcodeInput.Parent = opcodeFrame
        
        local inputCorner = Instance.new("UICorner")
        inputCorner.CornerRadius = UDim.new(0, 5)
        inputCorner.Parent = opcodeInput
        
        local updateBtn = Instance.new("TextButton")
        updateBtn.Size = UDim2.new(0, 70, 1, 0)
        updateBtn.Position = UDim2.new(0, 135, 0, 0)
        updateBtn.Text = "Update"
        updateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        updateBtn.Font = Enum.Font.GothamSemibold
        updateBtn.TextSize = 11
        updateBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
        updateBtn.BorderSizePixel = 0
        updateBtn.Parent = opcodeFrame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 5)
        btnCorner.Parent = updateBtn
        
        updateBtn.MouseButton1Click:Connect(function()
            local newOpcode = tonumber(opcodeInput.Text)
            if newOpcode and newOpcode >= 100 and newOpcode <= 200 then
                OPCODE = newOpcode
            end
        end)
        y += 35
        
        -- Timer
        local timerText = Instance.new("TextLabel")
        timerText.Name = "TimerText"
        timerText.Size = UDim2.new(1, -20, 0, 25)
        timerText.Position = UDim2.new(0, 10, 0, y)
        timerText.Text = "Next scan: --:--:--"
        timerText.TextColor3 = Color3.fromRGB(255, 200, 50)
        timerText.Font = Enum.Font.GothamBold
        timerText.TextSize = 14
        timerText.TextXAlignment = Enum.TextXAlignment.Left
        timerText.BackgroundTransparency = 1
        timerText.Parent = scrollFrame
        y += 28
        
        local countdownText = Instance.new("TextLabel")
        countdownText.Name = "CountdownText"
        countdownText.Size = UDim2.new(1, -20, 0, 18)
        countdownText.Position = UDim2.new(0, 10, 0, y)
        countdownText.TextColor3 = Color3.fromRGB(180, 180, 190)
        countdownText.Font = Enum.Font.Gotham
        countdownText.TextSize = 11
        countdownText.TextXAlignment = Enum.TextXAlignment.Left
        countdownText.BackgroundTransparency = 1
        countdownText.Parent = scrollFrame
        y += 25
        
        -- Items
        local itemsLabel = Instance.new("TextLabel")
        itemsLabel.Size = UDim2.new(1, -20, 0, 20)
        itemsLabel.Position = UDim2.new(0, 10, 0, y)
        itemsLabel.Text = "Target Items:"
        itemsLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
        itemsLabel.Font = Enum.Font.GothamSemibold
        itemsLabel.TextSize = 12
        itemsLabel.TextXAlignment = Enum.TextXAlignment.Left
        itemsLabel.BackgroundTransparency = 1
        itemsLabel.Parent = scrollFrame
        y += 22
        
        local itemLabels = {}
        for _, itemName in ipairs(TARGET_ITEMS) do
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -20, 0, 20)
            label.Position = UDim2.new(0, 15, 0, y)
            label.Text = "⏳ " .. itemName
            label.TextColor3 = Color3.fromRGB(200, 200, 200)
            label.Font = Enum.Font.Gotham
            label.TextSize = 11
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.BackgroundTransparency = 1
            label.Parent = scrollFrame
            itemLabels[itemName] = label
            y += 22
        end
        
        y += 5
        
        -- Stats
        local statsText = Instance.new("TextLabel")
        statsText.Name = "StatsText"
        statsText.Size = UDim2.new(1, -20, 0, 20)
        statsText.Position = UDim2.new(0, 10, 0, y)
        statsText.Text = "✅ 0 | ❌ 0 | 🔄 0"
        statsText.TextColor3 = Color3.fromRGB(180, 180, 190)
        statsText.Font = Enum.Font.Gotham
        statsText.TextSize = 12
        statsText.TextXAlignment = Enum.TextXAlignment.Left
        statsText.BackgroundTransparency = 1
        statsText.Parent = scrollFrame
        y += 30
        
        -- Start/Stop Button
        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Name = "ToggleButton"
        toggleBtn.Size = UDim2.new(1, -20, 0, 40)
        toggleBtn.Position = UDim2.new(0, 10, 0, y)
        toggleBtn.Text = "▶ START"
        toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.TextSize = 14
        toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
        toggleBtn.BorderSizePixel = 0
        toggleBtn.Parent = scrollFrame
        
        local toggleCorner = Instance.new("UICorner")
        toggleCorner.CornerRadius = UDim.new(0, 8)
        toggleCorner.Parent = toggleBtn
        
        -- Update UI function
        function updateUI()
            if isRunning then
                statusText.Text = isBuying and "Status: 🛒 MEMBORONG" or "Status: ⏰ MENUNGGU"
                statusText.TextColor3 = isBuying and Color3.fromRGB(255, 150, 50) or Color3.fromRGB(100, 200, 255)
                toggleBtn.Text = "⏹ STOP"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                
                if not isBuying and nextScanTime > 0 then
                    local remaining = nextScanTime - os.time()
                    if remaining > 0 then
                        local mins = math.floor(remaining / 60)
                        local secs = math.floor(remaining % 60)
                        countdownText.Text = string.format("Scan dalam: %d menit %d detik", mins, secs)
                        timerText.Text = os.date("%H:%M:%S", nextScanTime)
                    end
                else
                    timerText.Text = "BORONG!"
                    countdownText.Text = "🛒 Membeli item..."
                end
            else
                statusText.Text = "Status: ⏹️ OFF"
                statusText.TextColor3 = Color3.fromRGB(255, 100, 100)
                toggleBtn.Text = "▶ START"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
                timerText.Text = "Next scan: --:--:--"
                countdownText.Text = ""
            end
            
            for itemName, label in pairs(itemLabels) do
                local status = itemStatus[itemName] or "unknown"
                local bought = buyHistory[itemName] or 0
                if status == "stock" then
                    label.Text = "🟢 " .. itemName .. (bought > 0 and " +" .. bought or "")
                    label.TextColor3 = Color3.fromRGB(100, 255, 100)
                else
                    label.Text = "🔴 " .. itemName
                    label.TextColor3 = Color3.fromRGB(255, 100, 100)
                end
            end
            
            statsText.Text = string.format("✅ %d | ❌ %d | 🔄 %d", buyStats.success, buyStats.failed, scanCount)
        end
        
        toggleBtn.MouseButton1Click:Connect(function()
            if isRunning then stopMonitoring() else startMonitoring() end
            updateUI()
        end)
        
        -- Periodic UI update
        task.spawn(function()
            while parentFrame.Parent do
                task.wait(0.5)
                pcall(updateUI)
            end
        end)
        
        -- Cleanup on destroy
        parentFrame.Destroying:Connect(stopMonitoring)
    end
    
    setupAutoBuy()
end

-- ==================================================================
-- PLACEHOLDER TAB
-- ==================================================================
function populatePlaceholderTab(parentFrame, icon, title, subtitle)
    -- Clear
    for _, child in ipairs(parentFrame:GetChildren()) do
        child:Destroy()
    end
    
    local iconText = Instance.new("TextLabel")
    iconText.Size = UDim2.new(1, 0, 0, 60)
    iconText.Position = UDim2.new(0, 0, 0.35, -30)
    iconText.Text = icon
    iconText.Font = Enum.Font.Gotham
    iconText.TextSize = 50
    iconText.BackgroundTransparency = 1
    iconText.Parent = parentFrame
    
    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, 0, 0, 30)
    titleText.Position = UDim2.new(0, 0, 0.45, 0)
    titleText.Text = title
    titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 20
    titleText.BackgroundTransparency = 1
    titleText.Parent = parentFrame
    
    local subText = Instance.new("TextLabel")
    subText.Size = UDim2.new(1, 0, 0, 20)
    subText.Position = UDim2.new(0, 0, 0.52, 0)
    subText.Text = subtitle
    subText.TextColor3 = Color3.fromRGB(160, 160, 170)
    subText.Font = Enum.Font.Gotham
    subText.TextSize = 13
    subText.BackgroundTransparency = 1
    subText.Parent = parentFrame
end

-- ==================================================================
-- INITIALIZE
-- ==================================================================
createGUI()
print("[AoneHub] 🚀 Loaded")
