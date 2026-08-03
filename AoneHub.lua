-- ──────────────────────────────────────────────────────────────────────
-- AONEHUB - COMPLETE GUI SYSTEM
-- ──────────────────────────────────────────────────────────────────────

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ==================================================================
-- CREATE MAIN GUI
-- ==================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AoneHub"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- ==================================================================
-- COLORS
-- ==================================================================
local C = {
    bg = Color3.fromRGB(22, 22, 28),
    sidebar = Color3.fromRGB(28, 28, 35),
    accent = Color3.fromRGB(90, 140, 255),
    text = Color3.fromRGB(255, 255, 255),
    textDim = Color3.fromRGB(170, 170, 180),
    green = Color3.fromRGB(50, 200, 50),
    red = Color3.fromRGB(200, 50, 50),
    input = Color3.fromRGB(38, 38, 48),
    hover = Color3.fromRGB(45, 45, 55),
}

-- ==================================================================
-- MINIMIZED CIRCLE
-- ==================================================================
local minimizedCircle = Instance.new("TextButton")
minimizedCircle.Name = "Minimized"
minimizedCircle.Size = UDim2.new(0, 52, 0, 52)
minimizedCircle.Position = UDim2.new(0.5, -26, 0.5, -26)
minimizedCircle.Text = "AH"
minimizedCircle.TextColor3 = C.text
minimizedCircle.Font = Enum.Font.GothamBlack
minimizedCircle.TextSize = 22
minimizedCircle.BackgroundColor3 = C.accent
minimizedCircle.BorderSizePixel = 0
minimizedCircle.Visible = false
minimizedCircle.ZIndex = 10
minimizedCircle.Parent = screenGui

local circCorner = Instance.new("UICorner")
circCorner.CornerRadius = UDim.new(1, 0)
circCorner.Parent = minimizedCircle

-- ==================================================================
-- MAIN FRAME
-- ==================================================================
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 620, 0, 390)
mainFrame.Position = UDim2.new(0.5, -310, 0.5, -195)
mainFrame.BackgroundColor3 = C.bg
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = mainFrame

-- ==================================================================
-- TITLE BAR
-- ==================================================================
local titleBar = Instance.new("TextButton")  -- TextButton biar bisa drag
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 38)
titleBar.Text = ""
titleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
titleBar.BorderSizePixel = 0
titleBar.AutoButtonColor = false
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = titleBar

-- Title fill (biar corner cuma di atas)
local titleFill = Instance.new("Frame")
titleFill.Size = UDim2.new(1, 0, 0.5, 0)
titleFill.Position = UDim2.new(0, 0, 0.5, 0)
titleFill.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
titleFill.BorderSizePixel = 0
titleFill.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0.6, 0, 1, 0)
titleLabel.Position = UDim2.new(0, 16, 0, 0)
titleLabel.Text = "AoneHub"
titleLabel.TextColor3 = C.text
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.BackgroundTransparency = 1
titleLabel.Parent = titleBar

-- Minimize button
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 28, 0, 28)
minimizeBtn.Position = UDim2.new(1, -65, 0, 5)
minimizeBtn.Text = "–"
minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 20
minimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
minimizeBtn.BorderSizePixel = 0
minimizeBtn.Parent = titleBar

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 5)
minCorner.Parent = minimizeBtn

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -32, 0, 5)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 15
closeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 5)
closeCorner.Parent = closeBtn

-- ==================================================================
-- SIDEBAR (1/4 LEFT)
-- ==================================================================
local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Size = UDim2.new(0.26, 0, 1, -38)
sidebar.Position = UDim2.new(0, 0, 0, 38)
sidebar.BackgroundColor3 = C.sidebar
sidebar.BorderSizePixel = 0
sidebar.Parent = mainFrame

local sidebarCorner = Instance.new("UICorner")
sidebarCorner.CornerRadius = UDim.new(0, 10)
sidebarCorner.Parent = sidebar

-- Sidebar bottom fill
local sidebarFill = Instance.new("Frame")
sidebarFill.Size = UDim2.new(1, 0, 0.3, 0)
sidebarFill.Position = UDim2.new(0, 0, 0.85, 0)
sidebarFill.BackgroundColor3 = C.sidebar
sidebarFill.BorderSizePixel = 0
sidebarFill.Parent = sidebar

-- Sidebar menu label
local menuLabel = Instance.new("TextLabel")
menuLabel.Size = UDim2.new(1, 0, 0, 22)
menuLabel.Position = UDim2.new(0, 0, 0, 10)
menuLabel.Text = "MENU"
menuLabel.TextColor3 = Color3.fromRGB(120, 120, 130)
menuLabel.Font = Enum.Font.GothamBold
menuLabel.TextSize = 11
menuLabel.TextXAlignment = Enum.TextXAlignment.Center
menuLabel.BackgroundTransparency = 1
menuLabel.Parent = sidebar

-- Separator line
local sep = Instance.new("Frame")
sep.Size = UDim2.new(0.7, 0, 0, 1)
sep.Position = UDim2.new(0.15, 0, 0, 36)
sep.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
sep.BorderSizePixel = 0
sep.Parent = sidebar

-- ==================================================================
-- TAB BUTTONS
-- ==================================================================
local tabs = {
    {name = "AutoBuy", label = "🛒  Auto Buy"},
    {name = "AutoMail", label = "📧  Auto Mail"},
    {name = "Ekstra", label = "⚙️  Ekstra"},
}

local tabBtns = {}
local activeTab = nil

for i, tab in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Name = tab.name
    btn.Size = UDim2.new(0.82, 0, 0, 38)
    btn.Position = UDim2.new(0.09, 0, 0, 50 + (i-1)*46)
    btn.Text = tab.label
    btn.TextColor3 = C.textDim
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 13
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = sidebar
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 7)
    btnCorner.Parent = btn
    
    -- Hover
    btn.MouseEnter:Connect(function()
        if activeTab ~= tab.name then
            btn.BackgroundColor3 = C.hover
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeTab ~= tab.name then
            btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
        end
    end)
    
    tabBtns[tab.name] = btn
end

-- ==================================================================
-- CONTENT AREA (3/4 RIGHT)
-- ==================================================================
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(0.74, -10, 1, -48)
contentArea.Position = UDim2.new(0.26, 5, 0, 43)
contentArea.BackgroundTransparency = 1
contentArea.ClipsDescendants = true
contentArea.Parent = mainFrame

-- ==================================================================
-- DEFAULT VIEW (AoneHub branding)
-- ==================================================================
local defaultView = Instance.new("Frame")
defaultView.Size = UDim2.new(1, 0, 1, 0)
defaultView.BackgroundTransparency = 1
defaultView.Parent = contentArea

local logoLabel = Instance.new("TextLabel")
logoLabel.Size = UDim2.new(1, 0, 0, 50)
logoLabel.Position = UDim2.new(0, 0, 0.38, -25)
logoLabel.Text = "AoneHub"
logoLabel.TextColor3 = C.accent
logoLabel.Font = Enum.Font.GothamBlack
logoLabel.TextSize = 36
logoLabel.BackgroundTransparency = 1
logoLabel.Parent = defaultView

local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(1, 0, 0, 20)
subLabel.Position = UDim2.new(0, 0, 0.48, 0)
subLabel.Text = "Pilih menu di samping"
subLabel.TextColor3 = C.textDim
subLabel.Font = Enum.Font.Gotham
subLabel.TextSize = 13
subLabel.BackgroundTransparency = 1
subLabel.Parent = defaultView

local accentLine = Instance.new("Frame")
accentLine.Size = UDim2.new(0, 80, 0, 2)
accentLine.Position = UDim2.new(0.5, -40, 0.54, 0)
accentLine.BackgroundColor3 = C.accent
accentLine.BorderSizePixel = 0
accentLine.Parent = defaultView

-- ==================================================================
-- TAB CONTENT FRAMES
-- ==================================================================
local tabFrames = {}

for _, tab in ipairs(tabs) do
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = false
    f.Parent = contentArea
    tabFrames[tab.name] = f
end

-- ==================================================================
-- SWITCH TAB FUNCTION
-- ==================================================================
local function switchTab(tabName)
    defaultView.Visible = false
    
    -- Hide all
    for _, f in pairs(tabFrames) do
        f.Visible = false
    end
    
    -- Reset buttons
    for _, btn in pairs(tabBtns) do
        btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
        btn.TextColor3 = C.textDim
    end
    
    -- Show selected
    if tabFrames[tabName] then
        tabFrames[tabName].Visible = true
        tabBtns[tabName].BackgroundColor3 = C.accent
        tabBtns[tabName].TextColor3 = C.text
        activeTab = tabName
    end
end

-- Connect tab buttons
for _, tab in ipairs(tabs) do
    tabBtns[tab.name].MouseButton1Click:Connect(function()
        switchTab(tab.name)
    end)
end

-- ==================================================================
-- DRAGGING SYSTEM
-- ==================================================================
local dragObj = nil
local dragStart = nil
local objStart = nil

local function startDrag(obj, input)
    dragObj = obj
    dragStart = input.Position
    objStart = obj.Position
end

local function stopDrag()
    dragObj = nil
    dragStart = nil
    objStart = nil
end

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        startDrag(mainFrame, input)
    end
end)

minimizedCircle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        startDrag(minimizedCircle, input)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragObj and dragStart and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        dragObj.Position = UDim2.new(
            objStart.X.Scale,
            objStart.X.Offset + delta.X,
            objStart.Y.Scale,
            objStart.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        stopDrag()
    end
end)

-- ==================================================================
-- MINIMIZE / RESTORE
-- ==================================================================
local function minimizeGUI()
    mainFrame.Visible = false
    minimizedCircle.Visible = true
end

local function restoreGUI()
    minimizedCircle.Visible = false
    mainFrame.Visible = true
end

minimizeBtn.MouseButton1Click:Connect(minimizeGUI)
minimizedCircle.MouseButton1Click:Connect(restoreGUI)

-- ==================================================================
-- CLOSE / DESTROY
-- ==================================================================
closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

-- ==================================================================
-- POPULATE TAB 1: AUTO BUY
-- ==================================================================
(function()
    local parent = tabFrames["AutoBuy"]
    
    -- Auto Buy Script Variables
    local packetRemote = ReplicatedStorage:WaitForChild("SharedModules")
        :WaitForChild("Packet")
        :WaitForChild("RemoteEvent")
    
    local OPCODE = 133
    local ALL_ITEMS = {"Hypno Bloom", "Dragon's Breath", "Sun Bloom", "Star Fruit"}
    local SELECTED_ITEMS = {}
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
    
    -- Initialize all items as selected
    for _, item in ipairs(ALL_ITEMS) do
        SELECTED_ITEMS[item] = true
    end
    
    -- Build packet
    local function buildPacket(itemName)
        return buffer.fromstring(string.char(OPCODE, 0, #itemName) .. itemName)
    end
    
    -- Buy item
    local function buyItem(itemName)
        local packet = buildPacket(itemName)
        local success = pcall(function() packetRemote:FireServer(packet) end)
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
    
    -- Cache shop
    local function cacheShopElements()
        if next(shopElements) then return end
        local seedShop = playerGui:FindFirstChild("SeedShop")
        if not seedShop then return end
        local f = seedShop:FindFirstChild("Frame")
        if not f then return end
        local ns = f:FindFirstChild("NormalShop")
        if not ns then return end
        for _, ic in ipairs(ns:GetChildren()) do
            if SELECTED_ITEMS[ic.Name] then
                local mf = ic:FindFirstChild("Main_Frame") or ic:FindFirstChild("MainFrame")
                if mf then
                    local ct = mf:FindFirstChild("Cost_Text") or mf:FindFirstChild("CostText")
                    if ct then
                        shopElements[ic.Name] = {container = ic, costText = ct}
                    end
                end
            end
        end
    end
    
    -- Check availability
    local function isItemAvailable(itemName)
        local el = shopElements[itemName]
        if not el then return false
        if not el.container.Visible then return false end
        local txt = ""
        pcall(function() txt = el.costText.Text end)
        if txt:upper():find("NO STOCK") or txt == "" then return false end
        return true
    end
    
    -- Timing
    local function getSecondsUntilNextRestock()
        local now = os.time()
        local cm = math.floor(now / 60)
        local cs = now % 60
        local jitter = JITTER_MIN + math.random() * (JITTER_MAX - JITTER_MIN)
        local nrm = math.ceil(cm / 5) * 5
        local mutr = nrm - cm
        if mutr == 0 and cs < jitter then return jitter - cs end
        local sutr = (mutr * 60) - cs + jitter
        if sutr <= 0 then sutr += RESTOCK_INTERVAL end
        return sutr
    end
    
    -- Buy all
    local function buyAllAvailable()
        if isBuying then return end
        isBuying = true
        local total = 0
        while isRunning do
            local any = false
            for _, itemName in ipairs(ALL_ITEMS) do
                if not isRunning then break end
                if SELECTED_ITEMS[itemName] and isItemAvailable(itemName) then
                    if buyItem(itemName) then
                        total += 1
                        any = true
                        itemStatus[itemName] = "stock"
                        task.wait(BUY_JITTER_MIN + math.random() * (BUY_JITTER_MAX - BUY_JITTER_MIN))
                    else
                        itemStatus[itemName] = "nostock"
                        task.wait(0.2)
                    end
                else
                    itemStatus[itemName] = "nostock"
                end
            end
            if not any then break end
            task.wait(0.2)
        end
        isBuying = false
        updateUI()
    end
    
    local function scanAndBuy()
        scanCount += 1
        cacheShopElements()
        if next(shopElements) == nil then return end
        buyHistory = {}
        local any = false
        for _, itemName in ipairs(ALL_ITEMS) do
            if SELECTED_ITEMS[itemName] then
                if isItemAvailable(itemName) then
                    any = true
                    itemStatus[itemName] = "stock"
                else
                    itemStatus[itemName] = "nostock"
                end
            end
        end
        updateUI()
        if any then buyAllAvailable() end
    end
    
    local function mainLoop()
        while isRunning do
            local wt = getSecondsUntilNextRestock()
            nextScanTime = os.time() + wt
            updateUI()
            task.wait(wt)
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
    -- BUILD UI IN TAB
    -- ==================================================================
    
    -- Scroll
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 550)
    scroll.ScrollBarThickness = 3
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Parent = parent
    
    local y = 8
    
    -- Header
    local hdr = Instance.new("TextLabel")
    hdr.Size = UDim2.new(1, -20, 0, 28)
    hdr.Position = UDim2.new(0, 10, 0, y)
    hdr.Text = "🛒  Auto Buy Borong"
    hdr.TextColor3 = C.text
    hdr.Font = Enum.Font.GothamBold
    hdr.TextSize = 16
    hdr.TextXAlignment = Enum.TextXAlignment.Left
    hdr.BackgroundTransparency = 1
    hdr.Parent = scroll
    y += 32
    
    -- Status
    local statusText = Instance.new("TextLabel")
    statusText.Name = "StatusText"
    statusText.Size = UDim2.new(1, -20, 0, 22)
    statusText.Position = UDim2.new(0, 10, 0, y)
    statusText.Text = "⏹️  OFF"
    statusText.TextColor3 = C.red
    statusText.Font = Enum.Font.GothamSemibold
    statusText.TextSize = 13
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.BackgroundTransparency = 1
    statusText.Parent = scroll
    y += 26
    
    -- Opcode row
    local opRow = Instance.new("Frame")
    opRow.Size = UDim2.new(1, -20, 0, 26)
    opRow.Position = UDim2.new(0, 10, 0, y)
    opRow.BackgroundTransparency = 1
    opRow.Parent = scroll
    
    local opLabel = Instance.new("TextLabel")
    opLabel.Size = UDim2.new(0, 55, 1, 0)
    opLabel.Text = "Opcode:"
    opLabel.TextColor3 = C.textDim
    opLabel.Font = Enum.Font.Gotham
    opLabel.TextSize = 12
    opLabel.BackgroundTransparency = 1
    opLabel.Parent = opRow
    
    local opInput = Instance.new("TextBox")
    opInput.Size = UDim2.new(0, 55, 1, 0)
    opInput.Position = UDim2.new(0, 57, 0, 0)
    opInput.Text = "133"
    opInput.TextColor3 = C.text
    opInput.Font = Enum.Font.GothamBold
    opInput.TextSize = 12
    opInput.BackgroundColor3 = C.input
    opInput.BorderSizePixel = 0
    opInput.Parent = opRow
    
    local opCorner = Instance.new("UICorner")
    opCorner.CornerRadius = UDim.new(0, 4)
    opCorner.Parent = opInput
    
    local opUpdate = Instance.new("TextButton")
    opUpdate.Size = UDim2.new(0, 60, 1, 0)
    opUpdate.Position = UDim2.new(0, 118, 0, 0)
    opUpdate.Text = "Update"
    opUpdate.TextColor3 = C.text
    opUpdate.Font = Enum.Font.GothamSemibold
    opUpdate.TextSize = 11
    opUpdate.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
    opUpdate.BorderSizePixel = 0
    opUpdate.Parent = opRow
    
    local opUpCorner = Instance.new("UICorner")
    opUpCorner.CornerRadius = UDim.new(0, 4)
    opUpCorner.Parent = opUpdate
    
    opUpdate.MouseButton1Click:Connect(function()
        local n = tonumber(opInput.Text)
        if n and n >= 100 and n <= 200 then OPCODE = n end
    end)
    y += 32
    
    -- Timer
    local timerText = Instance.new("TextLabel")
    timerText.Name = "TimerText"
    timerText.Size = UDim2.new(1, -20, 0, 22)
    timerText.Position = UDim2.new(0, 10, 0, y)
    timerText.Text = "Next scan: --:--:--"
    timerText.TextColor3 = Color3.fromRGB(255, 200, 50)
    timerText.Font = Enum.Font.GothamBold
    timerText.TextSize = 13
    timerText.TextXAlignment = Enum.TextXAlignment.Left
    timerText.BackgroundTransparency = 1
    timerText.Parent = scroll
    y += 24
    
    local countdownText = Instance.new("TextLabel")
    countdownText.Name = "CountdownText"
    countdownText.Size = UDim2.new(1, -20, 0, 16)
    countdownText.Position = UDim2.new(0, 10, 0, y)
    countdownText.TextColor3 = C.textDim
    countdownText.Font = Enum.Font.Gotham
    countdownText.TextSize = 10
    countdownText.TextXAlignment = Enum.TextXAlignment.Left
    countdownText.BackgroundTransparency = 1
    countdownText.Parent = scroll
    y += 22
    
    -- Item checklist
    local checkLabel = Instance.new("TextLabel")
    checkLabel.Size = UDim2.new(1, -20, 0, 20)
    checkLabel.Position = UDim2.new(0, 10, 0, y)
    checkLabel.Text = "📋  Pilih Item:"
    checkLabel.TextColor3 = C.textDim
    checkLabel.Font = Enum.Font.GothamSemibold
    checkLabel.TextSize = 12
    checkLabel.TextXAlignment = Enum.TextXAlignment.Left
    checkLabel.BackgroundTransparency = 1
    checkLabel.Parent = scroll
    y += 22
    
    local itemChecks = {}
    
    for _, itemName in ipairs(ALL_ITEMS) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -20, 0, 24)
        row.Position = UDim2.new(0, 10, 0, y)
        row.BackgroundTransparency = 1
        row.Parent = scroll
        
        local cb = Instance.new("TextButton")
        cb.Size = UDim2.new(0, 20, 0, 20)
        cb.Position = UDim2.new(0, 0, 0, 2)
        cb.Text = "✅"
        cb.TextSize = 14
        cb.BackgroundTransparency = 1
        cb.BorderSizePixel = 0
        cb.AutoButtonColor = false
        cb.Parent = row
        
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -25, 1, 0)
        lbl.Position = UDim2.new(0, 25, 0, 0)
        lbl.Text = itemName
        lbl.TextColor3 = C.text
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.BackgroundTransparency = 1
        lbl.Parent = row
        
        cb.MouseButton1Click:Connect(function()
            SELECTED_ITEMS[itemName] = not SELECTED_ITEMS[itemName]
            cb.Text = SELECTED_ITEMS[itemName] and "✅" or "⬜"
            lbl.TextColor3 = SELECTED_ITEMS[itemName] and C.text or Color3.fromRGB(100, 100, 110)
        end)
        
        itemChecks[itemName] = {btn = cb, lbl = lbl, status = nil}
        y += 26
    end
    
    y += 4
    
    -- Stats
    local statsText = Instance.new("TextLabel")
    statsText.Name = "StatsText"
    statsText.Size = UDim2.new(1, -20, 0, 18)
    statsText.Position = UDim2.new(0, 10, 0, y)
    statsText.Text = "✅ 0  |  ❌ 0  |  🔄 0"
    statsText.TextColor3 = C.textDim
    statsText.Font = Enum.Font.Gotham
    statsText.TextSize = 11
    statsText.TextXAlignment = Enum.TextXAlignment.Left
    statsText.BackgroundTransparency = 1
    statsText.Parent = scroll
    y += 26
    
    -- Toggle button
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleBtn"
    toggleBtn.Size = UDim2.new(1, -20, 0, 40)
    toggleBtn.Position = UDim2.new(0, 10, 0, y)
    toggleBtn.Text = "▶  START"
    toggleBtn.TextColor3 = C.text
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 14
    toggleBtn.BackgroundColor3 = C.green
    toggleBtn.BorderSizePixel = 0
    toggleBtn.AutoButtonColor = false
    toggleBtn.Parent = scroll
    
    local tgCorner = Instance.new("UICorner")
    tgCorner.CornerRadius = UDim.new(0, 8)
    tgCorner.Parent = toggleBtn
    
    -- Toggle hover
    toggleBtn.MouseEnter:Connect(function()
        if not isRunning then
            toggleBtn.BackgroundColor3 = Color3.fromRGB(70, 220, 70)
        else
            toggleBtn.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
        end
    end)
    toggleBtn.MouseLeave:Connect(function()
        if not isRunning then
            toggleBtn.BackgroundColor3 = C.green
        else
            toggleBtn.BackgroundColor3 = C.red
        end
    end)
    
    -- Update UI function
    function updateUI()
        if isRunning then
            statusText.Text = isBuying and "🛒  MEMBORONG..." or "⏰  MENUNGGU RESTOCK"
            statusText.TextColor3 = isBuying and Color3.fromRGB(255, 150, 50) or Color3.fromRGB(100, 200, 255)
            toggleBtn.Text = "⏹  STOP"
            toggleBtn.BackgroundColor3 = C.red
            
            if not isBuying and nextScanTime > 0 then
                local rem = nextScanTime - os.time()
                if rem > 0 then
                    local m = math.floor(rem / 60)
                    local s = math.floor(rem % 60)
                    countdownText.Text = string.format("Scan dalam %d menit %d detik", m, s)
                    timerText.Text = os.date("%H:%M:%S", nextScanTime)
                end
            elseif isBuying then
                timerText.Text = "MEMBORONG..."
                countdownText.Text = "Membeli semua item tersedia"
            end
        else
            statusText.Text = "⏹️  OFF"
            statusText.TextColor3 = C.red
            toggleBtn.Text = "▶  START"
            toggleBtn.BackgroundColor3 = C.green
            timerText.Text = "Next scan: --:--:--"
            countdownText.Text = ""
        end
        
        -- Update item status
        for itemName, data in pairs(itemChecks) do
            local st = itemStatus[itemName]
            if st == "stock" then
                data.lbl.TextColor3 = Color3.fromRGB(100, 255, 100)
            elseif st == "nostock" then
                data.lbl.TextColor3 = Color3.fromRGB(255, 100, 100)
            end
        end
        
        statsText.Text = string.format("✅ %d  |  ❌ %d  |  🔄 %d", buyStats.success, buyStats.failed, scanCount)
    end
    
    toggleBtn.MouseButton1Click:Connect(function()
        if isRunning then stopMonitoring() else startMonitoring() end
        updateUI()
    end)
    
    -- Periodic refresh
    task.spawn(function()
        while parent.Parent do
            task.wait(0.5)
            pcall(updateUI)
        end
    end)
    
    -- Cleanup
    parent.Destroying:Connect(stopMonitoring)
    
end)()

-- ==================================================================
-- POPULATE TAB 2 & 3 (Placeholder)
-- ==================================================================
for _, tab in ipairs({"AutoMail", "Ekstra"}) do
    local parent = tabFrames[tab]
    local icons = {AutoMail = "📧", Ekstra = "⚙️"}
    
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(1, 0, 0, 60)
    iconLabel.Position = UDim2.new(0, 0, 0.35, -30)
    iconLabel.Text = icons[tab]
    iconLabel.Font = Enum.Font.Gotham
    iconLabel.TextSize = 50
    iconLabel.BackgroundTransparency = 1
    iconLabel.Parent = parent
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 30)
    titleLabel.Position = UDim2.new(0, 0, 0.45, 0)
    titleLabel.Text = tab == "AutoMail" and "Auto Mail" or "Ekstra"
    titleLabel.TextColor3 = C.text
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 20
    titleLabel.BackgroundTransparency = 1
    titleLabel.Parent = parent
    
    local subLabel = Instance.new("TextLabel")
    subLabel.Size = UDim2.new(1, 0, 0, 20)
    subLabel.Position = UDim2.new(0, 0, 0.52, 0)
    subLabel.Text = "Coming soon..."
    subLabel.TextColor3 = C.textDim
    subLabel.Font = Enum.Font.Gotham
    subLabel.TextSize = 13
    subLabel.BackgroundTransparency = 1
    subLabel.Parent = parent
end

-- ==================================================================
-- FINAL SETUP
-- ==================================================================
print("[AoneHub] ✅ GUI Ready")
print("[AoneHub] 📐 Drag: Title bar")
print("[AoneHub] 🔵 Minimize: Lingkaran AH (klik untuk restore)")
print("[AoneHub] ❌ Close: Tombol ✕")
print("[AoneHub] 🛒 Tab Auto Buy: Checklist item + Toggle START/STOP")
