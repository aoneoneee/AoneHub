-- ──────────────────────────────────────────────────────────────────────
-- AONEHUB - FULL SCRIPT (ALL 5 TABS - FINAL)
-- ──────────────────────────────────────────────────────────────────────

local function main()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")
    local Workspace = game:GetService("Workspace")

    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    -- ==================================================================
    -- CONFIG
    -- ==================================================================
    local function getConfigPath()
        local basePath = "AoneHub"
        pcall(function() makefolder(basePath) end)
        return basePath .. "/AoneHub_Config.json"
    end
    local SAVE_FILE = getConfigPath()

    local config = {
        selectedSeeds = {}, selectedGears = {}, selectedProps = {},
        accordionSeedOpen = false, accordionGearOpen = false, accordionPropOpen = false,
        searchSeed = "", searchGear = "", searchProp = "", searchSell = "",
        isRunningBuy = false, isRunningSell = false,
        selectedSellFruits = {}, sellTargets = {},
        mailFruitUsers = {}, mailTargetUsername = "", mailSelectedItems = {}, isAutoMailRunning = false, isAutoClaimRunning = false, extraToggle1 = false, extraToggle2 = true, extraToggle3 = false, valueDisplayEnabled = false,
    }

    local function loadConfig()
        local s, d = pcall(readfile, SAVE_FILE)
        if s and d then local s2, loaded = pcall(HttpService.JSONDecode, HttpService, d)
            if s2 and loaded then for k, v in pairs(loaded) do config[k] = v end; if config.mailTargetUsername == nil then config.mailTargetUsername = "" end; if config.mailSelectedItems == nil then config.mailSelectedItems = {} end; if config.isAutoMailRunning == nil then config.isAutoMailRunning = false end; if config.isAutoClaimRunning == nil then config.isAutoClaimRunning = false end; return true end
        end; return false
    end
    local function saveConfig()
        local s, json = pcall(HttpService.JSONEncode, HttpService, config)
        if s then pcall(writefile, SAVE_FILE, json) end
    end
    loadConfig()

    local function safeRequire(path)
        local s, r = pcall(function() return require(path) end)
        if s then return r end; return nil
    end

    -- ==================================================================
    -- OPCODES
    -- ==================================================================
    local function getOpcodes()
        local Networking = safeRequire(ReplicatedStorage.SharedModules.Networking)
        if not Networking then return 133, 137, 135 end
        local opSeed, opGear, opProp = 133, 137, 135
        pcall(function() if Networking.SeedShop and Networking.SeedShop.PurchaseSeed then opSeed = Networking.SeedShop.PurchaseSeed.Id end end)
        pcall(function() if Networking.GearShop and Networking.GearShop.PurchaseGear then opGear = Networking.GearShop.PurchaseGear.Id end end)
        pcall(function() if Networking.CrateShop and Networking.CrateShop.PurchaseCrate then opProp = Networking.CrateShop.PurchaseCrate.Id end end)
        return opSeed, opGear, opProp
    end
    local OPCODE_SEED, OPCODE_GEAR, OPCODE_PROP = getOpcodes()

    -- ==================================================================
    -- COLORS
    -- ==================================================================
    local C = {
        bg = Color3.fromRGB(22, 22, 28), sidebar = Color3.fromRGB(28, 28, 35),
        accent = Color3.fromRGB(90, 140, 255), text = Color3.fromRGB(255, 255, 255),
        textDim = Color3.fromRGB(170, 170, 180), green = Color3.fromRGB(50, 200, 50),
        red = Color3.fromRGB(200, 50, 50), orange = Color3.fromRGB(255, 150, 50),
        yellow = Color3.fromRGB(255, 200, 50),
        accordionSeed = Color3.fromRGB(35, 42, 35), accordionGear = Color3.fromRGB(42, 35, 35),
        accordionProp = Color3.fromRGB(40, 35, 45), accordionSell = Color3.fromRGB(45, 40, 35),
        accordionBody = Color3.fromRGB(30, 30, 36),
        itemRow = Color3.fromRGB(38, 38, 45), itemRowSelected = Color3.fromRGB(35, 55, 40),
        searchBg = Color3.fromRGB(32, 32, 38), input = Color3.fromRGB(38, 38, 48),
    }

    -- ==================================================================
    -- GET ITEMS
    -- ==================================================================
    local ALL_SEEDS, ALL_GEARS, ALL_PROPS = {}, {}, {}
    pcall(function()
        local sd = safeRequire(ReplicatedStorage.SharedModules.SeedData)
        if sd then for _, s in ipairs(sd) do if s and s.RestockShop and s.SeedName then table.insert(ALL_SEEDS, s.SeedName) end end end
        if #ALL_SEEDS == 0 then ALL_SEEDS = {"Hypno Bloom", "Dragon's Breath", "Sun Bloom", "Star Fruit"} end
        table.sort(ALL_SEEDS)
    end)
    pcall(function()
        local gd = safeRequire(ReplicatedStorage.SharedModules.GearShopData)
        if gd and gd.Data then for _, g in ipairs(gd.Data) do if g and not g.RobuxOnly and not g.HideFromShop and g.ItemName then table.insert(ALL_GEARS, g.ItemName) end end end
        table.sort(ALL_GEARS)
    end)
    pcall(function()
        local cd = safeRequire(ReplicatedStorage.SharedModules.CrateData)
        if cd and cd.GetAllCrates then for _, c in ipairs(cd.GetAllCrates()) do if c and c.RestockChance and c.Name then table.insert(ALL_PROPS, c.Name) end end end
        table.sort(ALL_PROPS)
    end)
    local ALL_SELL_FRUITS = {}; for _, n in ipairs(ALL_SEEDS) do table.insert(ALL_SELL_FRUITS, n) end

    local function mergeItems(saved, current)
        local m = {}; if type(saved) == "table" then for k, v in pairs(saved) do m[k] = v end end
        for _, n in ipairs(current) do if m[n] == nil then m[n] = false end end; return m
    end
    config.selectedSeeds = mergeItems(config.selectedSeeds, ALL_SEEDS)
    config.selectedGears = mergeItems(config.selectedGears, ALL_GEARS)
    config.selectedProps = mergeItems(config.selectedProps, ALL_PROPS)
    config.selectedSellFruits = mergeItems(config.selectedSellFruits, ALL_SELL_FRUITS)
    for _, n in ipairs(ALL_SELL_FRUITS) do if config.sellTargets[n] == nil then config.sellTargets[n] = 4.0 end end

    -- ==================================================================
    -- GUI SKELETON
    -- ==================================================================
    local screenGui = Instance.new("ScreenGui"); screenGui.Name = "AoneHub"; screenGui.Parent = playerGui; screenGui.ResetOnSpawn = false
    screenGui.Destroying:Connect(function() config.isRunningBuy = isRunningBuy; config.isRunningSell = isRunningSell; saveConfig() end)

    local minimizedCircle = Instance.new("TextButton"); minimizedCircle.Size = UDim2.new(0, 50, 0, 50); minimizedCircle.Position = UDim2.new(0.5, -25, 0.5, -25)
    minimizedCircle.Text = "AH"; minimizedCircle.TextColor3 = C.text; minimizedCircle.Font = Enum.Font.GothamBlack; minimizedCircle.TextSize = 20
    minimizedCircle.BackgroundColor3 = C.accent; minimizedCircle.BorderSizePixel = 0; minimizedCircle.Visible = false
    minimizedCircle.AutoButtonColor = false; minimizedCircle.Draggable = true; minimizedCircle.Parent = screenGui
    Instance.new("UICorner", minimizedCircle).CornerRadius = UDim.new(1, 0)

    local mainFrame = Instance.new("Frame"); mainFrame.Size = UDim2.new(0, 580, 0, 300); mainFrame.Position = UDim2.new(0.5, -290, 0.5, -150)
    mainFrame.BackgroundColor3 = C.bg; mainFrame.BorderSizePixel = 0; mainFrame.ClipsDescendants = true
    mainFrame.Active = true; mainFrame.Draggable = true; mainFrame.Parent = screenGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

    local titleBar = Instance.new("Frame"); titleBar.Size = UDim2.new(1, 0, 0, 28); titleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    titleBar.BorderSizePixel = 0; titleBar.Parent = mainFrame; Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)
    local titleFill = Instance.new("Frame"); titleFill.Size = UDim2.new(1, 0, 0.5, 0); titleFill.Position = UDim2.new(0, 0, 0.5, 0)
    titleFill.BackgroundColor3 = Color3.fromRGB(18, 18, 24); titleFill.BorderSizePixel = 0; titleFill.Parent = titleBar
    local titleLabel = Instance.new("TextLabel"); titleLabel.Size = UDim2.new(0.6, 0, 1, 0); titleLabel.Position = UDim2.new(0, 12, 0, 0)
    titleLabel.Text = "AoneHub"; titleLabel.TextColor3 = C.text; titleLabel.Font = Enum.Font.GothamBold; titleLabel.TextSize = 11
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left; titleLabel.BackgroundTransparency = 1; titleLabel.Parent = titleBar
    local minimizeBtn = Instance.new("TextButton"); minimizeBtn.Size = UDim2.new(0, 22, 0, 22); minimizeBtn.Position = UDim2.new(1, -50, 0, 3)
    minimizeBtn.Text = "–"; minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200); minimizeBtn.Font = Enum.Font.GothamBold; minimizeBtn.TextSize = 14
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55); minimizeBtn.BorderSizePixel = 0; minimizeBtn.AutoButtonColor = false; minimizeBtn.Parent = titleBar
    Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 4)
    local closeBtn = Instance.new("TextButton"); closeBtn.Size = UDim2.new(0, 22, 0, 22); closeBtn.Position = UDim2.new(1, -25, 0, 3)
    closeBtn.Text = "✕"; closeBtn.TextColor3 = Color3.fromRGB(255, 120, 120); closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 11
    closeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55); closeBtn.BorderSizePixel = 0; closeBtn.AutoButtonColor = false; closeBtn.Parent = titleBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
    minimizeBtn.MouseButton1Click:Connect(function()
        minimizedCircle.Position = UDim2.new(0, mainFrame.AbsolutePosition.X, 0, mainFrame.AbsolutePosition.Y)
        mainFrame.Visible = false; minimizedCircle.Visible = true
    end)
    minimizedCircle.MouseButton1Click:Connect(function()
        mainFrame.Position = UDim2.new(0, minimizedCircle.AbsolutePosition.X, 0, minimizedCircle.AbsolutePosition.Y)
        minimizedCircle.Visible = false; mainFrame.Visible = true
    end)
    closeBtn.MouseButton1Click:Connect(function() config.isRunningBuy=isRunningBuy; config.isRunningSell=isRunningSell; saveConfig(); screenGui:Destroy() end)

    local sidebar = Instance.new("Frame"); sidebar.Size = UDim2.new(0.2, 0, 1, -28); sidebar.Position = UDim2.new(0, 0, 0, 28)
    sidebar.BackgroundColor3 = C.sidebar; sidebar.BorderSizePixel = 0; sidebar.Parent = mainFrame; Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 10)
    local sidebarFill = Instance.new("Frame"); sidebarFill.Size = UDim2.new(1, 0, 0.3, 0); sidebarFill.Position = UDim2.new(0, 0, 0.85, 0)
    sidebarFill.BackgroundColor3 = C.sidebar; sidebarFill.BorderSizePixel = 0; sidebarFill.Parent = sidebar
    local menuLabel = Instance.new("TextLabel"); menuLabel.Size = UDim2.new(1, 0, 0, 16); menuLabel.Position = UDim2.new(0, 0, 0, 6)
    menuLabel.Text = "MENU"; menuLabel.TextColor3 = Color3.fromRGB(120, 120, 130); menuLabel.Font = Enum.Font.GothamBold; menuLabel.TextSize = 9
    menuLabel.TextXAlignment = Enum.TextXAlignment.Center; menuLabel.BackgroundTransparency = 1; menuLabel.Parent = sidebar
    local sep = Instance.new("Frame"); sep.Size = UDim2.new(0.7, 0, 0, 1); sep.Position = UDim2.new(0.15, 0, 0, 26)
    sep.BackgroundColor3 = Color3.fromRGB(60, 60, 70); sep.BorderSizePixel = 0; sep.Parent = sidebar

    local tabs = {{name="AutoBuy", label="🛒 Buy"}, {name="AutoSell", label="💰 Sell"}, {name="AutoMail", label="📧 Mail"}, {name="MailFruit", label="🎯 Fruit"}, {name="Ekstra", label="⚙️ Extra"}}
    local tabBtns = {}; local activeTab = nil
    for i, tab in ipairs(tabs) do
        local btn = Instance.new("TextButton"); btn.Size = UDim2.new(0.82, 0, 0, 22); btn.Position = UDim2.new(0.09, 0, 0, 30 + (i-1)*27)
        btn.Text = tab.label; btn.TextColor3 = C.textDim; btn.Font = Enum.Font.GothamSemibold; btn.TextSize = 8
        btn.TextXAlignment = Enum.TextXAlignment.Left; btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
        btn.BorderSizePixel = 0; btn.AutoButtonColor = false; btn.Parent = sidebar; Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        btn.MouseEnter:Connect(function() if activeTab ~= tab.name then btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55) end end)
        btn.MouseLeave:Connect(function() if activeTab ~= tab.name then btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40) end end)
        tabBtns[tab.name] = btn
    end

    local contentArea = Instance.new("Frame"); contentArea.Size = UDim2.new(0.8, -8, 1, -34); contentArea.Position = UDim2.new(0.2, 4, 0, 32)
    contentArea.BackgroundTransparency = 1; contentArea.ClipsDescendants = true; contentArea.Parent = mainFrame
    local defaultView = Instance.new("Frame"); defaultView.Size = UDim2.new(1, 0, 1, 0); defaultView.BackgroundTransparency = 1; defaultView.Parent = contentArea
    local logoLabel = Instance.new("TextLabel"); logoLabel.Size = UDim2.new(1, 0, 0, 32); logoLabel.Position = UDim2.new(0, 0, 0.35, -16)
    logoLabel.Text = "AoneHub"; logoLabel.TextColor3 = C.accent; logoLabel.Font = Enum.Font.GothamBlack; logoLabel.TextSize = 24; logoLabel.BackgroundTransparency = 1; logoLabel.Parent = defaultView
    local subLabel = Instance.new("TextLabel"); subLabel.Size = UDim2.new(1, 0, 0, 14); subLabel.Position = UDim2.new(0, 0, 0.5, 0)
    subLabel.Text = "Pilih menu di samping"; subLabel.TextColor3 = C.textDim; subLabel.Font = Enum.Font.Gotham; subLabel.TextSize = 10; subLabel.BackgroundTransparency = 1; subLabel.Parent = defaultView
    local tabFrames = {}
    for _, tab in ipairs(tabs) do local f = Instance.new("Frame"); f.Size = UDim2.new(1, 0, 1, 0); f.BackgroundTransparency = 1; f.Visible = false; f.Parent = contentArea; tabFrames[tab.name] = f end
    local function switchTab(tabName)
        defaultView.Visible = false; for _, f in pairs(tabFrames) do f.Visible = false end
        for _, btn in pairs(tabBtns) do btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40); btn.TextColor3 = C.textDim end
        if tabFrames[tabName] then tabFrames[tabName].Visible = true; tabBtns[tabName].BackgroundColor3 = C.accent; tabBtns[tabName].TextColor3 = C.text; activeTab = tabName end
    end
    for _, tab in ipairs(tabs) do tabBtns[tab.name].MouseButton1Click:Connect(function() switchTab(tab.name) end) end

    -- ==================================================================
-- TAB 5: EKSTRA (DENGAN TOGGLES)
-- ==================================================================
do local f = tabFrames["Ekstra"]
    -- Scroll untuk konten
    local extraScroll = Instance.new("ScrollingFrame")
    extraScroll.Size = UDim2.new(1, 0, 1, 0)
    extraScroll.CanvasSize = UDim2.new(0, 0, 0, 400)
    extraScroll.ScrollBarThickness = 3
    extraScroll.BackgroundTransparency = 1
    extraScroll.BorderSizePixel = 0
    extraScroll.Parent = f
    
    local extraLayout = Instance.new("UIListLayout")
    extraLayout.Padding = UDim.new(0, 6)
    extraLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    extraLayout.SortOrder = Enum.SortOrder.LayoutOrder
    extraLayout.Parent = extraScroll
    
    -- Header
    local extraHdr = Instance.new("TextLabel")
    extraHdr.Size = UDim2.new(1, -12, 0, 24)
    extraHdr.LayoutOrder = 1
    extraHdr.Text = "⚙️  Ekstra Settings"
    extraHdr.TextColor3 = C.text
    extraHdr.Font = Enum.Font.GothamBold
    extraHdr.TextSize = 12
    extraHdr.TextXAlignment = Enum.TextXAlignment.Left
    extraHdr.BackgroundTransparency = 1
    extraHdr.Parent = extraScroll
    
    -- ============ FUNGSI MEMBUAT TOGGLE ============
    local function createToggle(title, description, configKey, layoutOrder, defaultColor)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -12, 0, 44)
        container.LayoutOrder = layoutOrder
        container.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
        container.BorderSizePixel = 0
        container.Parent = extraScroll
        Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)
        
        -- Title
        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, -50, 0, 16)
        titleLabel.Position = UDim2.new(0, 10, 0, 4)
        titleLabel.Text = title
        titleLabel.TextColor3 = C.text
        titleLabel.Font = Enum.Font.GothamSemibold
        titleLabel.TextSize = 10
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.BackgroundTransparency = 1
        titleLabel.Parent = container
        
        -- Description
        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, -50, 0, 14)
        descLabel.Position = UDim2.new(0, 10, 0, 20)
        descLabel.Text = description
        descLabel.TextColor3 = C.textDim
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextSize = 8
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.BackgroundTransparency = 1
        descLabel.Parent = container
        
        -- Toggle Button
        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.new(0, 36, 0, 18)
        toggleBtn.Position = UDim2.new(1, -42, 0.5, -9)
        toggleBtn.Text = ""
        toggleBtn.BorderSizePixel = 0
        toggleBtn.AutoButtonColor = false
        toggleBtn.Parent = container
        Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)
        
        -- Toggle dot
        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 12, 0, 12)
        dot.Position = UDim2.new(0, 3, 0.5, -6)
        dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        dot.BorderSizePixel = 0
        dot.Parent = toggleBtn
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
        
        -- Status label
        local statusLabel = Instance.new("TextLabel")
        statusLabel.Size = UDim2.new(0, 34, 1, 0)
        statusLabel.Position = UDim2.new(1, -82, 0, 0)
        statusLabel.Text = config[configKey] and "ON" or "OFF"
        statusLabel.TextColor3 = config[configKey] and C.green or C.red
        statusLabel.Font = Enum.Font.GothamBold
        statusLabel.TextSize = 7
        statusLabel.TextXAlignment = Enum.TextXAlignment.Right
        statusLabel.BackgroundTransparency = 1
        statusLabel.Parent = container
        
        -- Update function
        local function updateToggle()
            local isOn = config[configKey]
            if isOn then
                toggleBtn.BackgroundColor3 = C.green
                dot.Position = UDim2.new(1, -15, 0.5, -6)
                statusLabel.Text = "ON"
                statusLabel.TextColor3 = C.green
            else
                toggleBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 75)
                dot.Position = UDim2.new(0, 3, 0.5, -6)
                statusLabel.Text = "OFF"
                statusLabel.TextColor3 = C.red
            end
        end
        
        toggleBtn.MouseButton1Click:Connect(function()
    config[configKey] = not config[configKey]
    saveConfig()
    updateToggle()
    
    -- Special handling untuk Value Display (Toggle 1)
    if configKey == "extraToggle1" then
        if config[configKey] then
            print("[AoneHub] ✅ Value Display: ON")
            task.wait(0.5)
            pcall(function()
                local backpackGui = playerGui:FindFirstChild("BackpackGui")
                if backpackGui then
                    local backpackFrame = backpackGui:FindFirstChild("Backpack")
                    if backpackFrame then
                        local gameToggle = backpackFrame:FindFirstChild("ValueToggleButton")
                        if gameToggle then
                            gameToggle.Text = "ON"
                            gameToggle.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
                        end
                    end
                end
            end)
        else
            print("[AoneHub] ❌ Value Display: OFF")
            pcall(function()
                local backpackGui = playerGui:FindFirstChild("BackpackGui")
                if backpackGui then
                    local backpackFrame = backpackGui:FindFirstChild("Backpack")
                    if backpackFrame then
                        local gameToggle = backpackFrame:FindFirstChild("ValueToggleButton")
                        if gameToggle then
                            gameToggle.Text = "OFF"
                            gameToggle.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
                        end
                        
                        local function removeLabels(container)
                            if not container then return end
                            for _, slot in container:GetChildren() do
                                if slot:IsA("TextButton") or slot:IsA("Frame") then
                                    local label = slot:FindFirstChild("SellValue")
                                    if label then label:Destroy() end
                                end
                            end
                        end
                        
                        local inventory = backpackFrame:FindFirstChild("Inventory")
                        if inventory then
                            local scrollingFrame = inventory:FindFirstChild("ScrollingFrame")
                            if scrollingFrame then
                                local gridFrame = scrollingFrame:FindFirstChild("UIGridFrame")
                                removeLabels(gridFrame)
                            end
                        end
                        
                        local hotbar = backpackFrame:FindFirstChild("Hotbar")
                        removeLabels(hotbar)
                        
                        local backpackTotal = backpackFrame:FindFirstChild("BackpackTotalFrame")
                        if backpackTotal then backpackTotal:Destroy() end
                        
                        local gardenTotal = backpackFrame:FindFirstChild("GardenTotalFrame")
                        if gardenTotal then gardenTotal:Destroy() end
                    end
                end
            end)
        end
    end
    
    -- Special handling untuk Anti-AFK (Toggle 2)
    if configKey == "extraToggle2" then
        if config[configKey] then
            print("[AoneHub] ✅ Anti-AFK: ON")
        else
            print("[AoneHub] ❌ Anti-AFK: OFF")
        end
    end
end)
        
        updateToggle()
        return container
    end
    
    -- Toggle 1: Auto Reconnect
    createToggle("👁 Value Display", "Tampilkan nilai buah di inventory & garden", "extraToggle1", 2)
    
    createToggle("🛡️ Anti-AFK", "Cegah kick karena idle/afk", "extraToggle2", 3)
        
    -- Toggle 3: Notifikasi
    createToggle("Notifikasi", "Tampilkan notifikasi saat ada event penting", "extraToggle3", 4)
    
    -- Info tambahan
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, -12, 0, 30)
    infoLabel.LayoutOrder = 99
    infoLabel.Text = "More features coming soon..."
    infoLabel.TextColor3 = C.textDim
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 8
    infoLabel.TextXAlignment = Enum.TextXAlignment.Center
    infoLabel.BackgroundTransparency = 1
    infoLabel.Parent = extraScroll
end

-- ==================================================================
-- VALUE DISPLAY SYSTEM (DENGAN CACHE - HANYA HITUNG SAAT ON)
-- ==================================================================
do
    local valueDisplaySystem = {
        initialized = false,
        backpackTotalFrame = nil,
        gardenTotalFrame = nil,
    }
    
    -- Cache system
    local valueCache = {
        backpackTotal = 0,
        gardenTotal = 0,
        lastBackpackUpdate = 0,
        lastGardenUpdate = 0,
    }
    
    -- Safe require
    local function SafeRequireVD(parent, moduleName)
        local success, module = pcall(function()
            return require(parent:WaitForChild(moduleName, 10))
        end)
        if success then return module else return nil end
    end
    
    -- Load modules
    local sharedModules = ReplicatedStorage:WaitForChild("SharedModules", 10)
    if not sharedModules then
        print("[AoneHub] ❌ SharedModules not found!")
        return
    end
    
    local SellValueData = SafeRequireVD(sharedModules, "SellValueData")
    local FruitValueCalc = SafeRequireVD(sharedModules, "FruitValueCalc")
    local SellFlags = SafeRequireVD(sharedModules:FindFirstChild("Flags") or sharedModules, "SellFlags")
    local NumberUtils = SafeRequireVD(sharedModules, "NumberUtils")
    local Worlds = SafeRequireVD(sharedModules, "Worlds")
    
    if not (SellValueData and FruitValueCalc and SellFlags and NumberUtils and Worlds) then
        print("[AoneHub] ❌ Value Display modules not found!")
        return
    end
    
    local backpackGui = playerGui:FindFirstChild("BackpackGui")
    if not backpackGui then
        print("[AoneHub] ❌ BackpackGui not found!")
        return
    end
    
    print("[AoneHub] ✅ Value Display modules loaded!")
    
    -- Friend Boost
    local function GetFriendBoostPercentage()
        local success, result = pcall(function()
            local hud = playerGui:FindFirstChild("HUD")
            if not hud then return 0 end
            local currencies = hud:FindFirstChild("Currencies")
            if not currencies then return 0 end
            local friendBoost = currencies:FindFirstChild("FriendBoost")
            if not friendBoost then return 0 end
            local textLabel = friendBoost:FindFirstChild("TextLabel")
            if not textLabel then return 0 end
            local percentage = textLabel.Text:match("(%d+)%%")
            if percentage then return tonumber(percentage) or 0 end
            return 0
        end)
        if success then return result else return 0 end
    end
    
    local FRIEND_BOOST_PERCENT = GetFriendBoostPercentage()
    
    -- Calculate fruit value
    local function CalculateFruitValue(fruitName, sizeMultiplier, mutation)
        if not fruitName or not SellValueData[fruitName] then return nil end
        
        local success, baseValue = pcall(function()
            return FruitValueCalc(fruitName, sizeMultiplier or 1, mutation, player, nil)
        end)
        if not success or not baseValue then return nil end
        
        local success2, valueWithBoost = pcall(function()
            return SellFlags.Apply(fruitName, baseValue)
        end)
        if not success2 or not valueWithBoost then return nil end
        
        if FRIEND_BOOST_PERCENT > 0 then
            valueWithBoost = valueWithBoost / (1 + FRIEND_BOOST_PERCENT / 100)
        end
        
        return math.floor(valueWithBoost)
    end
    
    -- Format value
    local function FormatValue(value)
        if not value or value <= 0 then return "0" end
        local success, result = pcall(function()
            return NumberUtils.Abbreviate(value) .. Worlds.Current.CurrencySuffix
        end)
        if success then return result else return tostring(value) end
    end
    
    -- Parse tool count
    local function ParseToolCount(toolCountText)
        if not toolCountText then return nil end
        local cleaned = toolCountText:gsub("kg", ""):gsub(" ", "")
        return tonumber(cleaned)
    end
    
    -- Check if instance is fruit
    local function IsFruitInstance(instance)
        if instance:IsA("Configuration") or instance:IsA("Tool") then
            local success, fruitName = pcall(function()
                return instance:GetAttribute("FruitName")
            end)
            return success and fruitName ~= nil and fruitName ~= ""
        end
        return false
    end
    
    -- Get fruit attributes
    local function GetFruitAttributes(instance)
        local success, attrs = pcall(function()
            return {
                fruitName = instance:GetAttribute("FruitName"),
                sizeMultiplier = instance:GetAttribute("SizeMultiplier") or 1,
                mutation = instance:GetAttribute("Mutation"),
                weight = instance:GetAttribute("Weight"),
                id = instance:GetAttribute("Id")
            }
        end)
        if success then return attrs end
        return nil
    end
    
    -- Find fruit by count and name
    local function FindFruitByCountAndName(toolCountText, fruitName)
        if not config.extraToggle1 then return nil end
        
        local backpack = player:FindFirstChild("Backpack")
        if not backpack then return nil end
        
        local character = player.Character
        local uiWeight = ParseToolCount(toolCountText)
        local matchingFruits = {}
        
        for _, instance in backpack:GetChildren() do
            if IsFruitInstance(instance) then
                local attrs = GetFruitAttributes(instance)
                if attrs and attrs.fruitName == fruitName then
                    table.insert(matchingFruits, attrs)
                end
            end
        end
        
        if character then
            for _, instance in character:GetChildren() do
                if IsFruitInstance(instance) then
                    local attrs = GetFruitAttributes(instance)
                    if attrs and attrs.fruitName == fruitName then
                        table.insert(matchingFruits, attrs)
                    end
                end
            end
        end
        
        if #matchingFruits == 0 then return nil end
        if #matchingFruits == 1 then return matchingFruits[1] end
        
        if uiWeight then
            local bestMatch = nil
            local closestDifference = math.huge
            
            for _, attrs in matchingFruits do
                local fruitWeight = attrs.weight
                if fruitWeight then
                    local roundedUiWeight = math.floor(uiWeight * 100 + 0.5) / 100
                    local roundedFruitWeight = math.floor(fruitWeight * 100 + 0.5) / 100
                    local difference = math.abs(roundedFruitWeight - roundedUiWeight)
                    
                    if difference < 0.005 then
                        return attrs
                    elseif difference < closestDifference then
                        closestDifference = difference
                        bestMatch = attrs
                    end
                end
            end
            
            if bestMatch and closestDifference < 0.1 then
                return bestMatch
            end
        end
        
        return nil
    end
    
    -- Create label for slot
    local function CreateLabelForSlot(slot)
        if not config.extraToggle1 then return end
        if not slot or not slot:IsA("TextButton") then return end
        if slot:FindFirstChild("SellValue") then return end
        
        local toolNameLabel = slot:FindFirstChild("ToolName")
        local toolCountLabel = slot:FindFirstChild("ToolCount")
        
        if not toolNameLabel then
            for _, child in slot:GetDescendants() do
                if child:IsA("TextLabel") and child.Name == "ToolName" then
                    toolNameLabel = child
                    break
                end
            end
        end
        
        if not toolCountLabel then
            for _, child in slot:GetDescendants() do
                if child:IsA("TextLabel") and child.Name == "ToolCount" then
                    toolCountLabel = child
                    break
                end
            end
        end
        
        if not toolNameLabel or not toolNameLabel:IsA("TextLabel") then return end
        
        local fruitName = toolNameLabel.Text
        if fruitName == "" then return end
        
        local toolCountText = toolCountLabel and toolCountLabel.Text or ""
        local fruitData = FindFruitByCountAndName(toolCountText, fruitName)
        if not fruitData then return end
        
        local value = CalculateFruitValue(fruitData.fruitName, fruitData.sizeMultiplier, fruitData.mutation)
        
        local sellValueLabel = Instance.new("TextLabel")
        sellValueLabel.Name = "SellValue"
        sellValueLabel.BackgroundTransparency = 1
        sellValueLabel.Font = Enum.Font.GothamSemibold
        sellValueLabel.TextSize = 11
        sellValueLabel.TextXAlignment = Enum.TextXAlignment.Left
        sellValueLabel.BorderSizePixel = 0
        sellValueLabel.ZIndex = 5
        
        if toolCountLabel then
            sellValueLabel.Size = UDim2.new(1, -8, 0, 14)
            sellValueLabel.Position = UDim2.new(
                toolCountLabel.Position.X.Scale,
                toolCountLabel.Position.X.Offset,
                0,
                toolCountLabel.Position.Y.Offset + toolCountLabel.Size.Y.Offset + 2
            )
        elseif toolNameLabel then
            sellValueLabel.Size = UDim2.new(1, -8, 0, 14)
            sellValueLabel.Position = UDim2.new(
                toolNameLabel.Position.X.Scale,
                toolNameLabel.Position.X.Offset,
                0,
                toolNameLabel.Position.Y.Offset + toolNameLabel.Size.Y.Offset + 2
            )
        else
            sellValueLabel.Size = UDim2.new(1, -8, 0, 14)
            sellValueLabel.Position = UDim2.new(0, 4, 0, 40)
        end
        
        sellValueLabel:SetAttribute("FruitId", fruitData.id or "unknown")
        sellValueLabel:SetAttribute("FruitName", fruitName)
        
        local displayText = value and ("💰 " .. FormatValue(value)) or "💰 N/A"
        sellValueLabel.Text = displayText
        
        if value then
            if value >= 1000000 then
                sellValueLabel.TextColor3 = Color3.fromRGB(255, 100, 255)
            elseif value >= 100000 then
                sellValueLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
            elseif value >= 10000 then
                sellValueLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
            else
                sellValueLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        else
            sellValueLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
        
        sellValueLabel.Parent = slot
    end
    
    -- Initialize inventory slots
    local function InitializeInventorySlots()
        if not config.extraToggle1 then return end
        if not backpackGui then return end
        
        local backpackFrame = backpackGui:FindFirstChild("Backpack")
        if not backpackFrame then return end
        
        local inventory = backpackFrame:FindFirstChild("Inventory")
        if not inventory then return end
        
        if not inventory.Visible then return end
        
        local scrollingFrame = inventory:FindFirstChild("ScrollingFrame")
        if not scrollingFrame then return end
        
        local gridFrame = scrollingFrame:FindFirstChild("UIGridFrame")
        if not gridFrame then return end
        
        for _, slot in gridFrame:GetChildren() do
            if slot:IsA("TextButton") then
                pcall(function() CreateLabelForSlot(slot) end)
            end
        end
    end
    
    -- Initialize hotbar slots
    local function InitializeHotbarSlots()
        if not config.extraToggle1 then return end
        if not backpackGui then return end
        
        local backpackFrame = backpackGui:FindFirstChild("Backpack")
        if not backpackFrame then return end
        
        local hotbar = backpackFrame:FindFirstChild("Hotbar")
        if not hotbar then return end
        
        for _, slot in hotbar:GetChildren() do
            if slot:IsA("TextButton") or slot:IsA("Frame") then
                pcall(function() CreateLabelForSlot(slot) end)
            end
        end
    end
    
    -- Initialize all slots
    local function InitializeAllSlots()
        if not config.extraToggle1 then return end
        pcall(InitializeInventorySlots)
        pcall(InitializeHotbarSlots)
    end
    
    -- Calculate backpack total value (HANYA JIKA TOGGLE ON)
    local function CalculateBackpackTotalValue()
        if not config.extraToggle1 then return 0 end
        
        local backpack = player:FindFirstChild("Backpack")
        if not backpack then return 0 end
        
        local totalValue = 0
        for _, instance in backpack:GetChildren() do
            if IsFruitInstance(instance) then
                local attrs = GetFruitAttributes(instance)
                if attrs then
                    local value = CalculateFruitValue(attrs.fruitName, attrs.sizeMultiplier, attrs.mutation)
                    if value then
                        totalValue = totalValue + value
                    end
                end
            end
        end
        
        return totalValue
    end
    
    -- Calculate garden total value (HANYA JIKA TOGGLE ON)
    local function CalculateGardenTotalValue()
        if not config.extraToggle1 then return 0 end
        
        local gardensFolder = workspace:FindFirstChild("Gardens")
        if not gardensFolder then return 0 end
        
        local userId = player.UserId
        local totalValue = 0
        
        for _, plot in gardensFolder:GetChildren() do
            local ownerId = plot:GetAttribute("OwnerUserId")
            local plotUserId = plot:GetAttribute("UserId")
            
            if ownerId == userId or plotUserId == userId then
                local plants = plot:FindFirstChild("Plants")
                if plants then
                    for _, plant in plants:GetChildren() do
                        if plant:IsA("Model") then
                            local fruitsFolder = plant:FindFirstChild("Fruits")
                            if fruitsFolder then
                                for _, fruit in fruitsFolder:GetChildren() do
                                    if fruit:IsA("Model") then
                                        local fruitName = fruit:GetAttribute("CorePartName")
                                        local sizeMulti = fruit:GetAttribute("SizeMulti") or 1
                                        local mutation = fruit:GetAttribute("Mutation")
                                        
                                        if mutation == "" then mutation = nil end
                                        
                                        if fruitName then
                                            local value = CalculateFruitValue(fruitName, sizeMulti, mutation)
                                            if value then
                                                totalValue = totalValue + value
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        
        return totalValue
    end
    
    -- Create backpack total frame
    local function CreateBackpackTotalFrame()
        local backpackFrame = backpackGui:FindFirstChild("Backpack")
        if not backpackFrame then return end
        
        local inventory = backpackFrame:FindFirstChild("Inventory")
        if not inventory then return end
        
        local existingFrame = backpackFrame:FindFirstChild("BackpackTotalFrame")
        if existingFrame then existingFrame:Destroy() end
        
        local invX = inventory.Position.X.Scale
        local invXOffset = inventory.Position.X.Offset
        local invY = inventory.Position.Y.Scale
        local invYOffset = inventory.Position.Y.Offset
        
        local totalFrame = Instance.new("Frame")
        totalFrame.Name = "BackpackTotalFrame"
        totalFrame.Size = UDim2.new(0, 140, 0, 25)
        totalFrame.Position = UDim2.new(invX, invXOffset, invY, invYOffset - 29)
        totalFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        totalFrame.BackgroundTransparency = 0
        totalFrame.BorderSizePixel = 0
        totalFrame.ZIndex = 10
        totalFrame.Parent = backpackFrame
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = totalFrame
        
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(255, 255, 255)
        stroke.Thickness = 1
        stroke.Transparency = 0.5
        stroke.Parent = totalFrame
        
        local valueLabel = Instance.new("TextLabel")
        valueLabel.Name = "Value"
        valueLabel.Size = UDim2.new(1, 0, 1, 0)
        valueLabel.Position = UDim2.new(0, 0, 0, 0)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = "💰 " .. FormatValue(valueCache.backpackTotal)
        valueLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextSize = 14
        valueLabel.TextXAlignment = Enum.TextXAlignment.Center
        valueLabel.TextYAlignment = Enum.TextYAlignment.Center
        valueLabel.ZIndex = 11
        valueLabel.Parent = totalFrame
        
        totalFrame.Visible = inventory.Visible and config.extraToggle1
        
        return totalFrame
    end
    
    -- Create garden total frame
    local function CreateGardenTotalFrame()
        local backpackFrame = backpackGui:FindFirstChild("Backpack")
        if not backpackFrame then return end
        
        local inventory = backpackFrame:FindFirstChild("Inventory")
        if not inventory then return end
        
        local existingFrame = backpackFrame:FindFirstChild("GardenTotalFrame")
        if existingFrame then existingFrame:Destroy() end
        
        local invX = inventory.Position.X.Scale
        local invXOffset = inventory.Position.X.Offset
        local invY = inventory.Position.Y.Scale
        local invYOffset = inventory.Position.Y.Offset
        
        local totalFrame = Instance.new("Frame")
        totalFrame.Name = "GardenTotalFrame"
        totalFrame.Size = UDim2.new(0, 140, 0, 25)
        totalFrame.Position = UDim2.new(invX, invXOffset + 190, invY, invYOffset - 29)
        totalFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        totalFrame.BackgroundTransparency = 0
        totalFrame.BorderSizePixel = 0
        totalFrame.ZIndex = 10
        totalFrame.Parent = backpackFrame
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = totalFrame
        
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(255, 255, 255)
        stroke.Thickness = 1
        stroke.Transparency = 0.5
        stroke.Parent = totalFrame
        
        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "Title"
        titleLabel.Size = UDim2.new(1, 0, 0, 10)
        titleLabel.Position = UDim2.new(0, 0, 0, 1)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = "GARDEN"
        titleLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = 8
        titleLabel.TextXAlignment = Enum.TextXAlignment.Center
        titleLabel.ZIndex = 11
        titleLabel.Parent = totalFrame
        
        local valueLabel = Instance.new("TextLabel")
        valueLabel.Name = "Value"
        valueLabel.Size = UDim2.new(1, 0, 0, 13)
        valueLabel.Position = UDim2.new(0, 0, 0, 11)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = "💰 " .. FormatValue(valueCache.gardenTotal)
        valueLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextSize = 12
        valueLabel.TextXAlignment = Enum.TextXAlignment.Center
        valueLabel.TextYAlignment = Enum.TextYAlignment.Center
        valueLabel.ZIndex = 11
        valueLabel.Parent = totalFrame
        
        totalFrame.Visible = inventory.Visible and config.extraToggle1
        
        return totalFrame
    end
    
    -- Update backpack total value (gunakan cache)
    local function UpdateBackpackTotalValue()
        if not config.extraToggle1 then return end
        
        local backpackFrame = backpackGui:FindFirstChild("Backpack")
        if not backpackFrame then return end
        
        local totalFrame = backpackFrame:FindFirstChild("BackpackTotalFrame")
        if not totalFrame then
            totalFrame = CreateBackpackTotalFrame()
        end
        
        if not totalFrame then return end
        
        local inventory = backpackFrame:FindFirstChild("Inventory")
        
        if inventory and not inventory.Visible then
            totalFrame.Visible = false
            return
        end
        
        totalFrame.Visible = true
        
        local valueLabel = totalFrame:FindFirstChild("Value")
        if valueLabel then
            valueLabel.Text = "💰 " .. FormatValue(valueCache.backpackTotal)
            
            if valueCache.backpackTotal >= 10000000 then
                valueLabel.TextColor3 = Color3.fromRGB(255, 0, 255)
            elseif valueCache.backpackTotal >= 1000000 then
                valueLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
            elseif valueCache.backpackTotal >= 100000 then
                valueLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            else
                valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        end
    end
    
    -- Update garden total value (gunakan cache)
    local function UpdateGardenTotalValue()
        if not config.extraToggle1 then return end
        
        local backpackFrame = backpackGui:FindFirstChild("Backpack")
        if not backpackFrame then return end
        
        local totalFrame = backpackFrame:FindFirstChild("GardenTotalFrame")
        if not totalFrame then
            totalFrame = CreateGardenTotalFrame()
        end
        
        if not totalFrame then return end
        
        local inventory = backpackFrame:FindFirstChild("Inventory")
        
        if inventory and not inventory.Visible then
            totalFrame.Visible = false
            return
        end
        
        totalFrame.Visible = true
        
        local valueLabel = totalFrame:FindFirstChild("Value")
        if valueLabel then
            valueLabel.Text = "💰 " .. FormatValue(valueCache.gardenTotal)
            
            if valueCache.gardenTotal >= 10000000 then
                valueLabel.TextColor3 = Color3.fromRGB(255, 0, 255)
            elseif valueCache.gardenTotal >= 1000000 then
                valueLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
            elseif valueCache.gardenTotal >= 100000 then
                valueLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            else
                valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
        end
    end
    
    -- Cleanup semua label dan frame
    local function CleanupAll()
        local function removeLabels(container)
            if not container then return end
            for _, slot in container:GetChildren() do
                if slot:IsA("TextButton") or slot:IsA("Frame") then
                    local label = slot:FindFirstChild("SellValue")
                    if label then label:Destroy() end
                end
            end
        end
        
        local backpackFrame = backpackGui:FindFirstChild("Backpack")
        if backpackFrame then
            local inventory = backpackFrame:FindFirstChild("Inventory")
            if inventory then
                local scrollingFrame = inventory:FindFirstChild("ScrollingFrame")
                if scrollingFrame then
                    local gridFrame = scrollingFrame:FindFirstChild("UIGridFrame")
                    removeLabels(gridFrame)
                end
            end
            
            local hotbar = backpackFrame:FindFirstChild("Hotbar")
            removeLabels(hotbar)
            
            local backpackTotal = backpackFrame:FindFirstChild("BackpackTotalFrame")
            if backpackTotal then backpackTotal:Destroy() end
            
            local gardenTotal = backpackFrame:FindFirstChild("GardenTotalFrame")
            if gardenTotal then gardenTotal:Destroy() end
        end
        
        -- Reset cache
        valueCache.backpackTotal = 0
        valueCache.gardenTotal = 0
    end
    
    -- Update cache di background (HANYA JIKA TOGGLE ON)
    local function UpdateCacheInBackground()
        task.spawn(function()
            while true do
                task.wait(5)  -- Update cache setiap 5 detik
                
                if config.extraToggle1 then
                    -- HANYA hitung jika toggle ON
                    pcall(function()
                        valueCache.backpackTotal = CalculateBackpackTotalValue()
                        valueCache.lastBackpackUpdate = os.time()
                    end)
                    
                    -- Garden lebih jarang diupdate (setiap 5 detik)
                    if os.time() - valueCache.lastGardenUpdate > 5 then
                        pcall(function()
                            valueCache.gardenTotal = CalculateGardenTotalValue()
                            valueCache.lastGardenUpdate = os.time()
                        end)
                    end
                end
            end
        end)
    end
    
    -- Watch Inventory visibility (INSTANT menggunakan cache)
    local function SetupInventoryWatcher()
        local backpackFrame = backpackGui:FindFirstChild("Backpack")
        if not backpackFrame then return end
        
        local inventory = backpackFrame:FindFirstChild("Inventory")
        if not inventory then return end
        
        inventory:GetPropertyChangedSignal("Visible"):Connect(function()
            if not config.extraToggle1 then return end
            
            if inventory.Visible then
                -- Inventory dibuka - LANGSUNG tampilkan dengan nilai cache
                pcall(function()
                    local backpackTotal = backpackFrame:FindFirstChild("BackpackTotalFrame")
                    local gardenTotal = backpackFrame:FindFirstChild("GardenTotalFrame")
                    
                    if backpackTotal then
                        backpackTotal.Visible = true
                        local valueLabel = backpackTotal:FindFirstChild("Value")
                        if valueLabel then
                            valueLabel.Text = "💰 " .. FormatValue(valueCache.backpackTotal)
                        end
                    else
                        CreateBackpackTotalFrame()
                    end
                    
                    if gardenTotal then
                        gardenTotal.Visible = true
                        local valueLabel = gardenTotal:FindFirstChild("Value")
                        if valueLabel then
                            valueLabel.Text = "💰 " .. FormatValue(valueCache.gardenTotal)
                        end
                    else
                        CreateGardenTotalFrame()
                    end
                    
                    -- Update labels
                    InitializeAllSlots()
                end)
            else
                -- Inventory ditutup - LANGSUNG sembunyikan
                local backpackTotal = backpackFrame:FindFirstChild("BackpackTotalFrame")
                if backpackTotal then backpackTotal.Visible = false end
                
                local gardenTotal = backpackFrame:FindFirstChild("GardenTotalFrame")
                if gardenTotal then gardenTotal.Visible = false end
            end
        end)
    end
    
    -- Update frame dengan nilai cache (cepat)
    local function StartPeriodicUpdate()
        task.spawn(function()
            while true do
                task.wait(0.5)
                
                if config.extraToggle1 then
                    pcall(function()
                        local backpackFrame = backpackGui:FindFirstChild("Backpack")
                        if backpackFrame then
                            local inventory = backpackFrame:FindFirstChild("Inventory")
                            
                            if inventory and inventory.Visible then
                                local backpackTotal = backpackFrame:FindFirstChild("BackpackTotalFrame")
                                if backpackTotal and backpackTotal.Visible then
                                    local valueLabel = backpackTotal:FindFirstChild("Value")
                                    if valueLabel then
                                        valueLabel.Text = "💰 " .. FormatValue(valueCache.backpackTotal)
                                    end
                                end
                                
                                local gardenTotal = backpackFrame:FindFirstChild("GardenTotalFrame")
                                if gardenTotal and gardenTotal.Visible then
                                    local valueLabel = gardenTotal:FindFirstChild("Value")
                                    if valueLabel then
                                        valueLabel.Text = "💰 " .. FormatValue(valueCache.gardenTotal)
                                    end
                                end
                            end
                        end
                    end)
                end
            end
        end)
    end
    
    -- Watch garden (HANYA JIKA TOGGLE ON)
    local function SetupGardenWatcher()
        local gardensFolder = workspace:FindFirstChild("Gardens")
        if not gardensFolder then return end
        
        for _, plot in gardensFolder:GetChildren() do
            plot.DescendantAdded:Connect(function(descendant)
                if not config.extraToggle1 then return end
                
                if descendant:IsA("Model") then
                    local corePartName = descendant:GetAttribute("CorePartName")
                    if corePartName then
                        task.wait(0.3)
                        pcall(function()
                            valueCache.gardenTotal = CalculateGardenTotalValue()
                            valueCache.lastGardenUpdate = os.time()
                        end)
                    end
                end
            end)
            
            plot.DescendantRemoving:Connect(function(descendant)
                if not config.extraToggle1 then return end
                
                if descendant:IsA("Model") then
                    local corePartName = descendant:GetAttribute("CorePartName")
                    if corePartName then
                        task.wait(0.3)
                        pcall(function()
                            valueCache.gardenTotal = CalculateGardenTotalValue()
                            valueCache.lastGardenUpdate = os.time()
                        end)
                    end
                end
            end)
        end
    end
    
    -- Watch backpack (HANYA JIKA TOGGLE ON)
    local function SetupFruitWatcher()
        local backpack = player:FindFirstChild("Backpack")
        if not backpack then return end
        
        backpack.ChildAdded:Connect(function(instance)
            if not config.extraToggle1 then return end
            
            if IsFruitInstance(instance) then
                task.wait(0.5)
                pcall(function()
                    valueCache.backpackTotal = CalculateBackpackTotalValue()
                    valueCache.lastBackpackUpdate = os.time()
                end)
                pcall(InitializeAllSlots)
            end
        end)
        
        backpack.ChildRemoved:Connect(function(instance)
            if not config.extraToggle1 then return end
            
            if IsFruitInstance(instance) then
                task.wait(0.3)
                pcall(function()
                    valueCache.backpackTotal = CalculateBackpackTotalValue()
                    valueCache.lastBackpackUpdate = os.time()
                end)
                pcall(InitializeAllSlots)
            end
        end)
    end
    
    -- Initialize
    task.wait(2)
    
    pcall(function()
        SetupFruitWatcher()
        SetupGardenWatcher()
        SetupInventoryWatcher()
        
        -- Mulai cache dan update di background
        UpdateCacheInBackground()
        StartPeriodicUpdate()
        
        -- Jika toggle ON, hitung cache awal
        if config.extraToggle1 then
            task.spawn(function()
                valueCache.backpackTotal = CalculateBackpackTotalValue()
                valueCache.gardenTotal = CalculateGardenTotalValue()
                valueCache.lastBackpackUpdate = os.time()
                valueCache.lastGardenUpdate = os.time()
                
                -- Buat frame jika Inventory visible
                local backpackFrame = backpackGui:FindFirstChild("Backpack")
                if backpackFrame then
                    local inventory = backpackFrame:FindFirstChild("Inventory")
                    if inventory and inventory.Visible then
                        CreateBackpackTotalFrame()
                        CreateGardenTotalFrame()
                        InitializeAllSlots()
                    end
                end
            end)
        end
        
        print("[AoneHub] ✅ Value Display system initialized with cache!")
    end)
    end

-- ==================================================================
-- ANTI-AFK SYSTEM (DENGAN TOGGLE DI TAB 5)
-- ==================================================================
do
    local antiAFKEnabled = config.extraToggle2  -- Default sesuai config
    local VirtualInputManager = game:GetService("VirtualInputManager")
    local antiAFKActive = false
    
    -- Fungsi untuk menjalankan Anti-AFK
    local function StartAntiAFK()
        if antiAFKActive then return end
        antiAFKActive = true
        
        task.spawn(function()
            while antiAFKActive and config.extraToggle2 do
                -- Simulasi mouse movement
                pcall(function()
                    VirtualInputManager:SendMouseMoveEvent(
                        math.random(100, 500), 
                        math.random(100, 500), 
                        nil
                    )
                end)
                
                -- Simulasi key press
                pcall(function()
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, nil)
                    task.wait(0.1)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, nil)
                end)
                
                -- Gerakin karakter dikit (bonus)
                pcall(function()
                    local char = player.Character
                    if char and char:FindFirstChild("Humanoid") then
                        char.Humanoid:Move(Vector3.new(math.random(-5, 5), 0, math.random(-5, 5)))
                    end
                end)
                
                -- Tunggu 7-10 menit sebelum simulasi lagi
                task.wait(420 + math.random() * 180)
            end
            
            antiAFKActive = false
        end)
        
        print("[AoneHub] ✅ Anti-AFK: ON")
    end
    
    -- Fungsi untuk menghentikan Anti-AFK
    local function StopAntiAFK()
        antiAFKActive = false
        print("[AoneHub] ❌ Anti-AFK: OFF")
    end
    
    -- Monitor config.extraToggle2 untuk perubahan
    task.spawn(function()
        while true do
            task.wait(0.5)
            
            if config.extraToggle2 then
                -- Toggle ON, jalankan Anti-AFK
                if not antiAFKActive then
                    StartAntiAFK()
                end
            else
                -- Toggle OFF, hentikan Anti-AFK
                if antiAFKActive then
                    StopAntiAFK()
                end
            end
        end
    end)
    
    -- Auto-start jika config true
    if config.extraToggle2 then
        task.delay(1, function()
            StartAntiAFK()
            print("[AoneHub] ✅ Anti-AFK auto-started!")
        end)
    end
    end
    
    -- ==================================================================
    -- TAB 1: AUTO BUY
    -- ==================================================================
    local parentBuy = tabFrames["AutoBuy"]
    local buyStats = {total=0, success=0, failed=0, skipped=0}
    local isRunningBuy = config.isRunningBuy or false; local isBuying = false
    local itemStatusSeed, itemStatusGear, itemStatusProp = {}, {}, {}
    local nextScanTime, scanCount = 0, 0
    local shopElementsSeed, shopElementsGear, shopElementsProp = {}, {}, {}

    local packetRemote = nil
    local function getRemote() if packetRemote then return true end
        local s, r = pcall(function() return ReplicatedStorage:WaitForChild("SharedModules",5):WaitForChild("Packet",5):WaitForChild("RemoteEvent",5) end)
        if s and r then packetRemote = r; return true end; return false
    end
    local function getWorldId() local s, id = pcall(function() return Workspace.ActiveWorldId end); return s and id or "Main" end
    local function getCurrencyName() return getWorldId()=="FallHarvest" and "Leaves" or "Sheckles" end
    local function getSheckles()
        local cn = getCurrencyName(); local a = 0
        pcall(function()
            local ls = player:FindFirstChild("leaderstats")
            if ls then for _, s in ipairs(ls:GetChildren()) do if s.Name:lower():find(cn:lower()) then a=tonumber(s.Value)or 0; break end end
            if a==0 then for _, s in ipairs(ls:GetChildren()) do if s.Name:lower():find("sheckle")or s.Name:lower():find("money")or s.Name:lower():find("cash")or s.Name:lower():find("coin")or s.Name:lower():find("leaves")or s.Name:lower():find("leaf") then a=tonumber(s.Value)or 0; break end end end end
        end); return a
    end
    local function getItemPrice(itemName, elements)
        local el = elements[itemName]
        if not el then return nil end
    
        local txt = ""
        pcall(function() txt = el.costText.Text end)
    
        -- Hapus simbol ¢
        txt = txt:gsub("¢", "")
    
        if txt:upper():find("NO STOCK") or txt:upper():find("SOLD") or txt == "" then return nil end
    
        local num = string.match(txt, "([%d,.]+)")
        if not num then return nil end
        num = num:gsub(",", "")
        local price = tonumber(num)
        if not price then return nil end
    
        local lower = txt:lower()
        if lower:find("k") then price = price * 1000
        elseif lower:find("m") then price = price * 1000000
        elseif lower:find("b") then price = price * 1000000000 end
    
        return price
    end
    local function buyItem(itemName, opcode)
        if not getRemote() then return false end
        local s = pcall(function() packetRemote:FireServer(buffer.fromstring(string.char(opcode,0,#itemName)..itemName)) end)
        buyStats.total=buyStats.total+1; if s then buyStats.success=buyStats.success+1; return true else buyStats.failed=buyStats.failed+1; return false end
    end
    local function cacheBuyShop()
        -- Seeds (NormalShop > NamaItem > Main_Frame > Cost_Text)
        pcall(function()
            local ss = playerGui:FindFirstChild("SeedShop")
            if ss then local f = ss:FindFirstChild("Frame")
                if f then local ns = f:FindFirstChild("NormalShop")
                    if ns then for _, ic in ipairs(ns:GetChildren()) do
                        if ic:IsA("Frame") then
                            local mf = ic:FindFirstChild("Main_Frame") or ic:FindFirstChild("MainFrame")
                            if mf then local ct = mf:FindFirstChild("Cost_Text") or mf:FindFirstChild("CostText")
                                if ct then shopElementsSeed[ic.Name] = {container = ic, costText = ct} end
                            end
                        end
                    end end
                end
            end
        end)
    
        -- Gears (ScrollingFrame > NamaItem > Main_Frame > Cost_Text) — SAMA PERSIS
        pcall(function()
            local gs = playerGui:FindFirstChild("GearShop")
            if gs then local f = gs:FindFirstChild("Frame")
                if f then local sf = f:FindFirstChild("ScrollingFrame")
                    if sf then for _, ic in ipairs(sf:GetChildren()) do
                        -- Skip UIListLayout, Padding, ItemTemplate, GenerateItems, Robux_Shelf, Sheckles_Shelf
                        if ic:IsA("Frame") and ic.Name ~= "UIListLayout" 
                            and ic.Name ~= "Padding" and ic.Name ~= "ItemTemplate"
                            and ic.Name ~= "Robux_Shelf" and ic.Name ~= "Sheckles_Shelf"
                            and ic.Name ~= "GenerateItems" and ic.Name ~= "Item_Size" then
                        
                            local mf = ic:FindFirstChild("Main_Frame") or ic:FindFirstChild("MainFrame")
                            if mf then local ct = mf:FindFirstChild("Cost_Text") or mf:FindFirstChild("CostText")
                                if ct then shopElementsGear[ic.Name] = {container = ic, costText = ct} end
                            end
                        end
                    end end
                end
            end
        end)
    
        -- Props (ScrollingFrame > NamaItem > Main_Frame > Cost_Text) — SAMA PERSIS
        pcall(function()
            local cs = playerGui:FindFirstChild("CrateShop")
            if cs then local f = cs:FindFirstChild("Frame")
                if f then local sf = f:FindFirstChild("ScrollingFrame")
                    if sf then for _, ic in ipairs(sf:GetChildren()) do
                        if ic:IsA("Frame") and ic.Name ~= "UIListLayout" 
                            and ic.Name ~= "Padding" and ic.Name ~= "ItemTemplate"
                            and ic.Name ~= "Robux_Shelf" and ic.Name ~= "Sheckles_Shelf"
                            and ic.Name ~= "GenerateItems" and ic.Name ~= "Item_Size" then
                        
                            local mf = ic:FindFirstChild("Main_Frame") or ic:FindFirstChild("MainFrame")
                            if mf then local ct = mf:FindFirstChild("Cost_Text") or mf:FindFirstChild("CostText")
                                if ct then shopElementsProp[ic.Name] = {container = ic, costText = ct} end
                            end
                        end
                    end end
                end
            end
        end)
    end
    
    local function isAvailable(itemName, elements)
        local el = elements[itemName]
        if not el then return false end
    
        -- Cek container visible
        if el.container:IsA("GuiObject") then
            if not el.container.Visible then return false end
        end
    
        -- Cek Cost_Text
        local txt = ""
        pcall(function() txt = el.costText.Text end)
        txt = txt:gsub("¢", "")  -- Hapus simbol ¢
        if txt:upper():find("NO STOCK") or txt:upper():find("SOLD") or txt == "" then 
            return false 
        end
    
        -- Cek Stock_Text (kalau ada di Main_Frame)
        local mf = el.container:FindFirstChild("Main_Frame") or el.container:FindFirstChild("MainFrame")
        if mf then
            local stockText = mf:FindFirstChild("Stock_Text")
            if stockText then
                local st = ""
                pcall(function() st = stockText.Text end)
                local num = string.match(st, "(%d+)")
                if num and tonumber(num) == 0 then return false end
            end
        end
    
        return true
    end

    local function buyAll()
        if isBuying then return end; isBuying=true
        while isRunningBuy do local any=false; local bal=getSheckles()
            for _,n in ipairs(ALL_SEEDS) do if not isRunningBuy then break end
                if config.selectedSeeds[n] and isAvailable(n,shopElementsSeed) then local p=getItemPrice(n,shopElementsSeed)
                    if p and p>bal then itemStatusSeed[n]="expensive"; buyStats.skipped=buyStats.skipped+1
                    else if buyItem(n,OPCODE_SEED) then any=true; itemStatusSeed[n]="stock"; bal=bal-(p or 0); task.wait(2+math.random()*3) else itemStatusSeed[n]="nostock" end end
                else itemStatusSeed[n]="nostock" end
            end
            for _,n in ipairs(ALL_GEARS) do if not isRunningBuy then break end
                if config.selectedGears[n] and isAvailable(n,shopElementsGear) then local p=getItemPrice(n,shopElementsGear)
                    if p and p>bal then itemStatusGear[n]="expensive"; buyStats.skipped=buyStats.skipped+1
                    else if buyItem(n,OPCODE_GEAR) then any=true; itemStatusGear[n]="stock"; bal=bal-(p or 0); task.wait(2+math.random()*3) else itemStatusGear[n]="nostock" end end
                else itemStatusGear[n]="nostock" end
            end
            for _,n in ipairs(ALL_PROPS) do if not isRunningBuy then break end
                if config.selectedProps[n] and isAvailable(n,shopElementsProp) then local p=getItemPrice(n,shopElementsProp)
                    if p and p>bal then itemStatusProp[n]="expensive"; buyStats.skipped=buyStats.skipped+1
                    else if buyItem(n,OPCODE_PROP) then any=true; itemStatusProp[n]="stock"; bal=bal-(p or 0); task.wait(2+math.random()*3) else itemStatusProp[n]="nostock" end end
                else itemStatusProp[n]="nostock" end
            end
            if not any then break end; task.wait(0.5)
        end; isBuying=false; updateBuyUI()
    end
    local function scanAndBuy()
        scanCount=scanCount+1; cacheBuyShop(); local any=false
        for _,n in ipairs(ALL_SEEDS) do if config.selectedSeeds[n] then if isAvailable(n,shopElementsSeed) then any=true; itemStatusSeed[n]="stock" else itemStatusSeed[n]="nostock" end end end
        for _,n in ipairs(ALL_GEARS) do if config.selectedGears[n] then if isAvailable(n,shopElementsGear) then any=true; itemStatusGear[n]="stock" else itemStatusGear[n]="nostock" end end end
        for _,n in ipairs(ALL_PROPS) do if config.selectedProps[n] then if isAvailable(n,shopElementsProp) then any=true; itemStatusProp[n]="stock" else itemStatusProp[n]="nostock" end end end
        updateBuyUI(); if any then buyAll() end
    end
    local function getSecondsUntilNextBuyScan()
        local now=os.time(); local cm=math.floor(now/60); local cs=now%60; local j=3+math.random()*2; local nrm=math.ceil(cm/5)*5; local mutr=nrm-cm
        if mutr==0 and cs<j then return j-cs end; local s=(mutr*60)-cs+j; return s<=0 and s+300 or s
    end
    local function buyMainLoop() while isRunningBuy do local w=getSecondsUntilNextBuyScan(); nextScanTime=os.time()+w; updateBuyUI(); task.wait(w); if not isRunningBuy then break end; pcall(scanAndBuy); task.wait(1) end end
    local function startBuy() if isRunningBuy then return end; if not getRemote() then return end; isRunningBuy=true; config.isRunningBuy=true; saveConfig(); cacheBuyShop(); pcall(scanAndBuy); task.spawn(buyMainLoop); updateBuyUI() end
    local function stopBuy() if not isRunningBuy then return end; isRunningBuy=false; config.isRunningBuy=false; saveConfig(); itemStatusSeed={}; itemStatusGear={}; itemStatusProp={}; updateBuyUI() end

    -- Buy UI
    local buyScroll = Instance.new("ScrollingFrame"); buyScroll.Size=UDim2.new(1,0,1,0); buyScroll.CanvasSize=UDim2.new(0,0,0,900); buyScroll.ScrollBarThickness=3; buyScroll.BackgroundTransparency=1; buyScroll.BorderSizePixel=0; buyScroll.Parent=parentBuy
    local buyLayout=Instance.new("UIListLayout"); buyLayout.Padding=UDim.new(0,4); buyLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center; buyLayout.SortOrder=Enum.SortOrder.LayoutOrder; buyLayout.Parent=buyScroll
    local buyHdr=Instance.new("TextLabel"); buyHdr.Size=UDim2.new(1,-12,0,16); buyHdr.LayoutOrder=1; buyHdr.Text="🛒  Auto Buy"; buyHdr.TextColor3=C.text; buyHdr.Font=Enum.Font.GothamBold; buyHdr.TextSize=10; buyHdr.TextXAlignment=Enum.TextXAlignment.Left; buyHdr.BackgroundTransparency=1; buyHdr.Parent=buyScroll
    local buyStatusText=Instance.new("TextLabel"); buyStatusText.Size=UDim2.new(1,-12,0,14); buyStatusText.LayoutOrder=2; buyStatusText.Text=isRunningBuy and "⏰  MENUNGGU" or "⏹️  OFF"; buyStatusText.TextColor3=isRunningBuy and Color3.fromRGB(100,200,255) or C.red; buyStatusText.Font=Enum.Font.GothamSemibold; buyStatusText.TextSize=9; buyStatusText.TextXAlignment=Enum.TextXAlignment.Left; buyStatusText.BackgroundTransparency=1; buyStatusText.Parent=buyScroll
    local buyCountdownText=Instance.new("TextLabel"); buyCountdownText.Size=UDim2.new(1,-12,0,12); buyCountdownText.LayoutOrder=3; buyCountdownText.Text="Next scan: --:--:--"; buyCountdownText.TextColor3=Color3.fromRGB(255,200,50); buyCountdownText.Font=Enum.Font.GothamBold; buyCountdownText.TextSize=9; buyCountdownText.TextXAlignment=Enum.TextXAlignment.Left; buyCountdownText.BackgroundTransparency=1; buyCountdownText.Parent=buyScroll
    local buyStatsText=Instance.new("TextLabel"); buyStatsText.Size=UDim2.new(1,-12,0,10); buyStatsText.LayoutOrder=4; buyStatsText.Text="✅0 ❌0 💸0 🔄0"; buyStatsText.TextColor3=C.textDim; buyStatsText.Font=Enum.Font.Gotham; buyStatsText.TextSize=8; buyStatsText.TextXAlignment=Enum.TextXAlignment.Left; buyStatsText.BackgroundTransparency=1; buyStatsText.Parent=buyScroll
    local buyShecklesText=Instance.new("TextLabel"); buyShecklesText.Size=UDim2.new(1,-12,0,10); buyShecklesText.LayoutOrder=5; buyShecklesText.Text="💰 --"; buyShecklesText.TextColor3=Color3.fromRGB(255,200,50); buyShecklesText.Font=Enum.Font.Gotham; buyShecklesText.TextSize=8; buyShecklesText.TextXAlignment=Enum.TextXAlignment.Left; buyShecklesText.BackgroundTransparency=1; buyShecklesText.Parent=buyScroll

    function updateBuyUI()
        if isRunningBuy then buyStatusText.Text=isBuying and "🛒  MEMBORONG..." or "⏰  MENUNGGU RESTOCK"; buyStatusText.TextColor3=isBuying and C.orange or Color3.fromRGB(100,200,255)
            if not isBuying and nextScanTime>0 then local r=nextScanTime-os.time(); if r>0 then local m=math.floor(r/60); local s=math.floor(r%60); buyCountdownText.Text=string.format("⏳ %02d:%02d",m,s) else buyCountdownText.Text="⏳ Scanning..." end
            elseif isBuying then buyCountdownText.Text="⏳ Membeli..." end
        else buyStatusText.Text="⏹️  OFF"; buyStatusText.TextColor3=C.red; buyCountdownText.Text="Next scan: --:--:--" end
        local s=getSheckles(); local icon=getCurrencyName()=="Leaves" and "🍃" or "💰"
        local f=s>=1e9 and string.format("%.1fB",s/1e9) or (s>=1e6 and string.format("%.1fM",s/1e6) or (s>=1e3 and string.format("%.1fk",s/1e3) or tostring(s)))
        buyShecklesText.Text=icon.." "..f; buyStatsText.Text="✅"..buyStats.success.." ❌"..buyStats.failed.." 💸"..buyStats.skipped.." 🔄"..scanCount
    end

    local function createBuyAccordion(title,items,selItems,itemStatus,elements,hdrColor,openKey,searchKey,layoutOrder)
        local open=config[openKey] or false
        local c=Instance.new("Frame"); c.Size=UDim2.new(1,-12,0,open and 150 or 22); c.BackgroundTransparency=1; c.LayoutOrder=layoutOrder; c.Parent=buyScroll
        local h=Instance.new("TextButton"); h.Size=UDim2.new(1,0,0,22); h.BackgroundColor3=hdrColor; h.BorderSizePixel=0; h.Text=""; h.AutoButtonColor=false; h.Parent=c; Instance.new("UICorner",h).CornerRadius=UDim.new(0,4)
        local a=Instance.new("TextLabel"); a.Size=UDim2.new(0,12,1,0); a.Position=UDim2.new(0,3,0,0); a.Text=open and "▼" or "▶"; a.TextColor3=C.textDim; a.Font=Enum.Font.GothamBold; a.TextSize=7; a.BackgroundTransparency=1; a.Parent=h
        local sc=0; for _,n in ipairs(items) do if selItems[n] then sc=sc+1 end end
        local tl=Instance.new("TextLabel"); tl.Size=UDim2.new(1,-45,1,0); tl.Position=UDim2.new(0,16,0,0); tl.Text=title.." ("..#items..") ✅"..sc; tl.TextColor3=C.text; tl.Font=Enum.Font.GothamSemibold; tl.TextSize=9; tl.TextXAlignment=Enum.TextXAlignment.Left; tl.BackgroundTransparency=1; tl.Parent=h
        local sa=Instance.new("TextButton"); sa.Size=UDim2.new(0,26,0,12); sa.Position=UDim2.new(1,-30,0.5,-6); sa.Text="All"; sa.TextColor3=C.text; sa.Font=Enum.Font.Gotham; sa.TextSize=6; sa.BackgroundColor3=C.accent; sa.BorderSizePixel=0; sa.AutoButtonColor=false; sa.Parent=h; Instance.new("UICorner",sa).CornerRadius=UDim.new(0,2)
        local b=Instance.new("Frame"); b.Size=UDim2.new(1,0,0,126); b.Position=UDim2.new(0,0,0,24); b.BackgroundColor3=C.accordionBody; b.BorderSizePixel=0; b.Visible=open; b.Parent=c; Instance.new("UICorner",b).CornerRadius=UDim.new(0,4)
        local sf=Instance.new("Frame"); sf.Size=UDim2.new(1,-4,0,18); sf.Position=UDim2.new(0,2,0,2); sf.BackgroundColor3=C.searchBg; sf.BorderSizePixel=0; sf.Parent=b; Instance.new("UICorner",sf).CornerRadius=UDim.new(0,3)
        local si=Instance.new("TextLabel"); si.Size=UDim2.new(0,12,1,0); si.Position=UDim2.new(0,2,0,0); si.Text="🔍"; si.TextSize=6; si.BackgroundTransparency=1; si.Parent=sf
        local sb=Instance.new("TextBox"); sb.Size=UDim2.new(1,-16,1,0); sb.Position=UDim2.new(0,16,0,0); sb.PlaceholderText="Cari..."; sb.PlaceholderColor3=Color3.fromRGB(100,100,110); sb.Text=config[searchKey]or""; sb.TextColor3=C.text; sb.Font=Enum.Font.Gotham; sb.TextSize=8; sb.BackgroundTransparency=1; sb.BorderSizePixel=0; sb.Parent=sf
        local il=Instance.new("ScrollingFrame"); il.Size=UDim2.new(1,-4,1,-22); il.Position=UDim2.new(0,2,0,22); il.BackgroundTransparency=1; il.BorderSizePixel=0; il.ScrollBarThickness=2; il.Parent=b
        local ir={}; local sas=false
        local function rb()
            local q=sb.Text:lower(); config[searchKey]=q; saveConfig(); for _,r in pairs(ir) do r.frame:Destroy() end; ir={}
            local ad,se={},{}; for _,n in ipairs(items) do if not se[n] then table.insert(ad,n); se[n]=true end end
            for n in pairs(selItems) do if not se[n] then table.insert(ad,n); se[n]=true end end
            local ft={}; for _,n in ipairs(ad) do if q=="" or n:lower():find(q) then table.insert(ft,n) end end
            table.sort(ft,function(a,b) local aA=table.find(items,a)~=nil; local bA=table.find(items,b)~=nil; if aA and not bA then return true elseif not aA and bA then return false else return a<b end end)
            sc=0; for _,n in ipairs(items) do if selItems[n] then sc=sc+1 end end; tl.Text=title.." ("..#ft..") ✅"..sc
            local rh=15; il.CanvasSize=UDim2.new(0,0,0,#ft*rh+4)
            for i,n in ipairs(ft) do local ia=table.find(items,n)~=nil; local is=selItems[n] or false; local p=ia and elements and getItemPrice(n,elements) or nil; local st=itemStatus[n]
                local r=Instance.new("Frame"); r.Size=UDim2.new(1,-4,0,rh-2); r.Position=UDim2.new(0,2,0,(i-1)*rh+1); r.BackgroundColor3=is and C.itemRowSelected or C.itemRow; r.BorderSizePixel=0; r.Parent=il; Instance.new("UICorner",r).CornerRadius=UDim.new(0,2)
                local cb=Instance.new("TextButton"); cb.Size=UDim2.new(0,10,0,10); cb.Position=UDim2.new(0,2,0.5,-5); cb.Text=is and "✅" or "⬜"; cb.TextSize=6; cb.BackgroundTransparency=1; cb.BorderSizePixel=0; cb.AutoButtonColor=false; cb.Parent=r
                local ic=Instance.new("TextLabel"); ic.Size=UDim2.new(0,10,1,0); ic.Position=UDim2.new(0,13,0,0); ic.Text=ia and "🟢" or "🔒"; ic.TextSize=5; ic.BackgroundTransparency=1; ic.Parent=r
                local lb=Instance.new("TextLabel"); lb.Size=UDim2.new(1,-26,1,0); lb.Position=UDim2.new(0,24,0,0); lb.Font=Enum.Font.Gotham; lb.TextSize=7; lb.TextXAlignment=Enum.TextXAlignment.Left; lb.BackgroundTransparency=1; lb.Parent=r
                if ia then local ps=p and " ("..(p>=1000 and string.format("%.1fk",p/1000) or tostring(p))..")" or ""
                    if st=="stock" then 
                        lb.Text=n..ps; lb.TextColor3=Color3.fromRGB(100,255,100)       -- Hijau = available
                    elseif st=="expensive" then 
                        lb.Text=n..ps.." 💸"; lb.TextColor3=C.yellow                     -- Kuning = gak cukup uang
                    elseif st=="nostock" then 
                        lb.Text=n..ps; lb.TextColor3=Color3.fromRGB(255,255,255)        -- PUTIH = no stock
                    else 
                        lb.Text=n..ps; lb.TextColor3=is and Color3.fromRGB(100,255,100) or C.textDim 
                    end
                else 
                    lb.Text=n.." (off)"; lb.TextColor3=Color3.fromRGB(120,120,130)      -- Abu-abu = unavailable
                end
                local function ti() if not ia then return end; selItems[n]=not(selItems[n] or false); saveConfig(); rb() end
                cb.MouseButton1Click:Connect(ti); r.InputBegan:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 then ti() end end); ir[n]={frame=r,lbl=lb}
            end
            local ih=math.min(#ft*rh+24,110); b.Size=UDim2.new(1,0,0,ih); if open then c.Size=UDim2.new(1,-12,0,ih+24) end
        end
        sb:GetPropertyChangedSignal("Text"):Connect(rb); sa.MouseButton1Click:Connect(function() sas=not sas; sa.Text=sas and "None" or "All"; sa.BackgroundColor3=sas and C.red or C.accent; for _,n in ipairs(items) do selItems[n]=not sas end; saveConfig(); rb() end)
        h.MouseButton1Click:Connect(function() open=not open; b.Visible=open; a.Text=open and "▼" or "▶"; config[openKey]=open; saveConfig(); c.Size=UDim2.new(1,-12,0,open and(b.Size.Y.Offset+24)or 22) end); rb(); return c
    end
    createBuyAccordion("🌱 Seeds",ALL_SEEDS,config.selectedSeeds,itemStatusSeed,shopElementsSeed,C.accordionSeed,"accordionSeedOpen","searchSeed",10)
    createBuyAccordion("⚙️ Gears",ALL_GEARS,config.selectedGears,itemStatusGear,shopElementsGear,C.accordionGear,"accordionGearOpen","searchGear",20)
    createBuyAccordion("📦 Props",ALL_PROPS,config.selectedProps,itemStatusProp,shopElementsProp,C.accordionProp,"accordionPropOpen","searchProp",30)

    local buyToggleBtn=Instance.new("TextButton"); buyToggleBtn.Size=UDim2.new(1,-12,0,28); buyToggleBtn.LayoutOrder=100; buyToggleBtn.Text=isRunningBuy and "⏹ STOP" or "▶ START"
    buyToggleBtn.TextColor3=C.text; buyToggleBtn.Font=Enum.Font.GothamBold; buyToggleBtn.TextSize=10; buyToggleBtn.BackgroundColor3=isRunningBuy and C.red or C.green
    buyToggleBtn.BorderSizePixel=0; buyToggleBtn.AutoButtonColor=false; buyToggleBtn.Parent=buyScroll; Instance.new("UICorner",buyToggleBtn).CornerRadius=UDim.new(0,5)
    buyToggleBtn.MouseEnter:Connect(function() buyToggleBtn.BackgroundColor3=isRunningBuy and Color3.fromRGB(220,70,70) or Color3.fromRGB(70,220,70) end)
    buyToggleBtn.MouseLeave:Connect(function() buyToggleBtn.BackgroundColor3=isRunningBuy and C.red or C.green end)
    buyToggleBtn.MouseButton1Click:Connect(function() if isRunningBuy then stopBuy() else startBuy() end; updateBuyUI() end)
    task.spawn(function() while parentBuy.Parent do task.wait(0.5); pcall(updateBuyUI) end end)
    parentBuy.Destroying:Connect(function() stopBuy(); saveConfig() end)

    -- ==================================================================
    -- TAB 2: AUTO SELL
    -- ==================================================================
    local parentSell = tabFrames["AutoSell"]
    local net = safeRequire(ReplicatedStorage.SharedModules.Networking)
    local isRunningSell = config.isRunningSell or false; local currentMultipliers = {}; local nextSellScanTime = 0; local sellItemRows = {}
    local function getBackpack() return player:FindFirstChild("Backpack") end
    local function findFruitById(fid) local bp=getBackpack(); if not bp then return nil end; for _,i in ipairs(bp:GetChildren()) do if i:GetAttribute("Id")==fid then return i end end; return nil end
    local function getAllFruitItems() local it={}; local bp=getBackpack(); if not bp then return it end; for _,i in ipairs(bp:GetChildren()) do if i:GetAttribute("HarvestedFruit")==true then local id=i:GetAttribute("Id"); local nm=i:GetAttribute("FruitName")or i.Name; if id and nm then table.insert(it,{name=nm,id=id,item=i}) end end end; return it end
    local function initFav() local bp=getBackpack(); if not bp then return end; for _,i in ipairs(bp:GetChildren()) do if i:GetAttribute("HarvestedFruit")==true and i:GetAttribute("IsFavorite")==nil then i:SetAttribute("IsFavorite",false) end end end
    local function favById(fid) for _=1,3 do pcall(function() net.Backpack.SetFruitFavorite:Fire(fid,true) end); task.wait(0.5); local f=findFruitById(fid); if f and f:GetAttribute("IsFavorite")==true then return true end; task.wait(0.3) end; return false end
    local function unfavById(fid) for _=1,3 do pcall(function() net.Backpack.SetFruitFavorite:Fire(fid,false) end); task.wait(0.5); local f=findFruitById(fid); if f and f:GetAttribute("IsFavorite")~=true then return true end; task.wait(0.3) end; return false end
    local function favUnmatched(names)
    initFav()
    
    -- names = daftar buah yang akan DIJUAL (sudah dicek diselect + multiplier >= target)
    local ms = {}
    for _, n in ipairs(names) do ms[n] = true end
    
    local ai = getAllFruitItems()
    
    -- STEP 1: UNFAVORIT buah yang akan dijual (yang ada di names)
    for _, d in ipairs(ai) do
        if ms[d.name] then
            if d.item:GetAttribute("IsFavorite") == true then
                if not unfavById(d.id) then return false end
                task.wait(0.3)
            end
        end
    end
    
    -- STEP 2: FAVORIT SEMUA buah yang TIDAK akan dijual
    for _, d in ipairs(ai) do
        if not ms[d.name] then
            if d.item:GetAttribute("IsFavorite") ~= true then
                if not favById(d.id) then return false end
                task.wait(0.5 + math.random() * 1.0)
            end
        end
    end
    
    -- STEP 3: Verifikasi
    for _, d in ipairs(ai) do
        local willSell = ms[d.name] ~= nil
        local isFav = d.item:GetAttribute("IsFavorite") == true
        
        if willSell and isFav then
            -- Seharusnya tidak favorit
            if not unfavById(d.id) then return false end
        elseif not willSell and not isFav then
            -- Seharusnya favorit
            if not favById(d.id) then return false end
        end
    end
    
    return true
    end
    local function unfavAll() for _,d in ipairs(getAllFruitItems()) do if d.item:GetAttribute("IsFavorite")==true then pcall(function() net.Backpack.SetFruitFavorite:Fire(d.id,false) end); task.wait(0.5+math.random()*1.5) end end end
    local function readMult(fn) local pg=player:FindFirstChild("PlayerGui"); if not pg then return nil end; local sg=pg:FindFirstChild("FruitStockPrice"); if not sg or not sg.Enabled then return nil end; local sf=sg:FindFirstChild("Frame"); if sf then sf=sf:FindFirstChild("ScrollingFrame") end; if not sf then return nil end
        for _,c in ipairs(sf:GetChildren()) do if c:IsA("Frame") and c.Name=="FruitCard" and c:GetAttribute("SeedToolTip")==fn then local f=c:FindFirstChild("Frame"); if f then local ml=f:FindFirstChild("Multiplier"); if ml and ml:IsA("TextLabel") then local num=ml.Text:match("X([%d.]+)"); if num then return tonumber(num) end end end end end; return nil end
    local function updateMults() for fn,_ in pairs(config.selectedSellFruits) do local m=readMult(fn); if m then currentMultipliers[fn]=m end end
        if net.FruitStock and net.FruitStock.Request then local _,d=pcall(function() return net.FruitStock.Request:Fire() end); if d and d.entries then for fn,_ in pairs(config.selectedSellFruits) do local e=d.entries[fn]; if e then currentMultipliers[fn]=e.multiplier or 1 end end end end end
    local function getMatching()
    local mt = {}
    for fn, isSelected in pairs(config.selectedSellFruits) do
        if isSelected then  -- ⬅️ HANYA DISELECT
            local t = config.sellTargets[fn] or 4.0
            local m = currentMultipliers[fn] or 1
            if m >= t then  -- ⬅️ HANYA multiplier >= target
                table.insert(mt, {name = fn, current = m, target = t})
            end
        end
    end
    return mt
    end
    local function getSecUntilSell() local now=os.time(); local cm=math.floor(now/60); local cs=now%60; local nrm=math.ceil(cm/10)*10; local mutr=nrm-cm; if mutr==0 then return 600-cs end; return(mutr*60)-cs end
    local function sellAll() task.wait(0.5+math.random()*2.5); local s=pcall(function() net.NPCS.SellAll:Fire() end); return s end
    local function processSell(mt) local ns={}; for _,m in ipairs(mt) do table.insert(ns,m.name) end; if not favUnmatched(ns) then return false end; task.wait(0.5+math.random()); if not sellAll() then unfavAll(); return false end; task.wait(1+math.random()); unfavAll(); return true end
    local function checkAndSell() updateMults(); local mt=getMatching(); if #mt>0 then local ok=processSell(mt); updateSellUI(ok and "✅ SOLD!" or "🛑 GAGAL!"); return ok else updateSellUI("⏳ Menunggu..."); return false end end
    local function sellLoop() initFav(); nextSellScanTime=os.time()+getSecUntilSell(); updateSellUI(); while isRunningSell do updateMults(); updateSellUI(); if os.time()>=nextSellScanTime then checkAndSell(); nextSellScanTime=os.time()+600 end; task.wait(1) end end
    local function startSell() if isRunningSell then return end; if not net or not net.NPCS or not net.NPCS.SellAll then return end; isRunningSell=true; config.isRunningSell=true; saveConfig(); nextSellScanTime=os.time()+getSecUntilSell(); task.spawn(function() updateMults(); checkAndSell(); updateSellUI() end); task.spawn(sellLoop); updateSellUI() end
    local function stopSell() isRunningSell=false; config.isRunningSell=false; saveConfig(); updateSellUI() end

    -- Sell UI
    local sellScroll=Instance.new("ScrollingFrame"); sellScroll.Size=UDim2.new(1,0,1,0); sellScroll.CanvasSize=UDim2.new(0,0,0,900); sellScroll.ScrollBarThickness=3; sellScroll.BackgroundTransparency=1; sellScroll.BorderSizePixel=0; sellScroll.Parent=parentSell
    local sellLayout=Instance.new("UIListLayout"); sellLayout.Padding=UDim.new(0,4); sellLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center; sellLayout.SortOrder=Enum.SortOrder.LayoutOrder; sellLayout.Parent=sellScroll
    local sellHdr=Instance.new("TextLabel"); sellHdr.Size=UDim2.new(1,-12,0,16); sellHdr.LayoutOrder=1; sellHdr.Text="💰  Auto Sell"; sellHdr.TextColor3=C.text; sellHdr.Font=Enum.Font.GothamBold; sellHdr.TextSize=10; sellHdr.TextXAlignment=Enum.TextXAlignment.Left; sellHdr.BackgroundTransparency=1; sellHdr.Parent=sellScroll
    local sellStatusText=Instance.new("TextLabel"); sellStatusText.Size=UDim2.new(1,-12,0,14); sellStatusText.LayoutOrder=2; sellStatusText.Text=isRunningSell and "🟢  MONITORING" or "⏹️  OFF"; sellStatusText.TextColor3=isRunningSell and C.green or C.red; sellStatusText.Font=Enum.Font.GothamSemibold; sellStatusText.TextSize=9; sellStatusText.TextXAlignment=Enum.TextXAlignment.Left; sellStatusText.BackgroundTransparency=1; sellStatusText.Parent=sellScroll
    local sellTimerText=Instance.new("TextLabel"); sellTimerText.Size=UDim2.new(1,-12,0,12); sellTimerText.LayoutOrder=3; sellTimerText.Text="Next scan: --:--"; sellTimerText.TextColor3=Color3.fromRGB(255,200,50); sellTimerText.Font=Enum.Font.GothamBold; sellTimerText.TextSize=9; sellTimerText.TextXAlignment=Enum.TextXAlignment.Left; sellTimerText.BackgroundTransparency=1; sellTimerText.Parent=sellScroll

    function updateSellUI(msg) if msg then sellStatusText.Text=msg end
        if isRunningSell then local r=nextSellScanTime-os.time(); if r>0 then local m=math.floor(r/60); local s=math.floor(r%60); sellTimerText.Text=string.format("⏳ %02d:%02d",m,s) else sellTimerText.Text="⏳ Scanning..." end
        else sellTimerText.Text="Next scan: --:--" end
        for fn,row in pairs(sellItemRows) do if row and row.multLbl then local m=currentMultipliers[fn]or 1; local t=config.sellTargets[fn]or 4.0; row.multLbl.Text="X"..string.format("%.1f",m); row.multLbl.TextColor3=m>=t and C.orange or Color3.fromRGB(150,150,150) end end
    end

    local sellOpen=true
    local sellCont=Instance.new("Frame"); sellCont.Size=UDim2.new(1,-12,0,sellOpen and 220 or 22); sellCont.BackgroundTransparency=1; sellCont.LayoutOrder=10; sellCont.Parent=sellScroll
    local sellHead=Instance.new("TextButton"); sellHead.Size=UDim2.new(1,0,0,22); sellHead.BackgroundColor3=C.accordionSell; sellHead.BorderSizePixel=0; sellHead.Text=""; sellHead.AutoButtonColor=false; sellHead.Parent=sellCont; Instance.new("UICorner",sellHead).CornerRadius=UDim.new(0,4)
    local sellArr=Instance.new("TextLabel"); sellArr.Size=UDim2.new(0,12,1,0); sellArr.Position=UDim2.new(0,3,0,0); sellArr.Text=sellOpen and "▼" or "▶"; sellArr.TextColor3=C.textDim; sellArr.Font=Enum.Font.GothamBold; sellArr.TextSize=7; sellArr.BackgroundTransparency=1; sellArr.Parent=sellHead
    local sellSC=0; for _,s in pairs(config.selectedSellFruits) do if s then sellSC=sellSC+1 end end
    local sellTL=Instance.new("TextLabel"); sellTL.Size=UDim2.new(1,-45,1,0); sellTL.Position=UDim2.new(0,16,0,0); sellTL.Text="🍎 Buah ("..#ALL_SELL_FRUITS..") ✅"..sellSC; sellTL.TextColor3=C.text; sellTL.Font=Enum.Font.GothamSemibold; sellTL.TextSize=9; sellTL.TextXAlignment=Enum.TextXAlignment.Left; sellTL.BackgroundTransparency=1; sellTL.Parent=sellHead
    local sellBody=Instance.new("Frame"); sellBody.Size=UDim2.new(1,0,0,196); sellBody.Position=UDim2.new(0,0,0,24); sellBody.BackgroundColor3=C.accordionBody; sellBody.BorderSizePixel=0; sellBody.Visible=sellOpen; sellBody.Parent=sellCont; Instance.new("UICorner",sellBody).CornerRadius=UDim.new(0,4)
    local sellSF=Instance.new("Frame"); sellSF.Size=UDim2.new(1,-4,0,18); sellSF.Position=UDim2.new(0,2,0,2); sellSF.BackgroundColor3=C.searchBg; sellSF.BorderSizePixel=0; sellSF.Parent=sellBody; Instance.new("UICorner",sellSF).CornerRadius=UDim.new(0,3)
    local sellSI=Instance.new("TextLabel"); sellSI.Size=UDim2.new(0,12,1,0); sellSI.Position=UDim2.new(0,2,0,0); sellSI.Text="🔍"; sellSI.TextSize=6; sellSI.BackgroundTransparency=1; sellSI.Parent=sellSF
    local sellSB=Instance.new("TextBox"); sellSB.Size=UDim2.new(1,-16,1,0); sellSB.Position=UDim2.new(0,16,0,0); sellSB.PlaceholderText="Cari buah..."; sellSB.PlaceholderColor3=Color3.fromRGB(100,100,110); sellSB.Text=config.searchSell or""; sellSB.TextColor3=C.text; sellSB.Font=Enum.Font.Gotham; sellSB.TextSize=8; sellSB.BackgroundTransparency=1; sellSB.BorderSizePixel=0; sellSB.Parent=sellSF
    local sellIL=Instance.new("ScrollingFrame"); sellIL.Size=UDim2.new(1,-4,1,-22); sellIL.Position=UDim2.new(0,2,0,22); sellIL.BackgroundTransparency=1; sellIL.BorderSizePixel=0; sellIL.ScrollBarThickness=2; sellIL.Parent=sellBody
    local function rebuildSell() local q=sellSB.Text:lower(); config.searchSell=q; saveConfig(); for _,r in pairs(sellItemRows) do r.frame:Destroy() end; sellItemRows={}
        local ff={}; for _,fn in ipairs(ALL_SELL_FRUITS) do if q=="" or fn:lower():find(q) then table.insert(ff,fn) end end
        sellSC=0; for _,fn in ipairs(ALL_SELL_FRUITS) do if config.selectedSellFruits[fn] then sellSC=sellSC+1 end end; sellTL.Text="🍎 Buah ("..#ff.."/"..#ALL_SELL_FRUITS..") ✅"..sellSC
        sellIL.CanvasSize=UDim2.new(0,0,0,#ff*17+4)
        for i,fn in ipairs(ff) do local is=config.selectedSellFruits[fn] or false; local t=config.sellTargets[fn]or 4.0; local m=currentMultipliers[fn]or 1
            local r=Instance.new("Frame"); r.Size=UDim2.new(1,-4,0,15); r.Position=UDim2.new(0,2,0,(i-1)*17+1); r.BackgroundColor3=is and C.itemRowSelected or C.itemRow; r.BorderSizePixel=0; r.Parent=sellIL; Instance.new("UICorner",r).CornerRadius=UDim.new(0,2)
            local cb=Instance.new("TextButton"); cb.Size=UDim2.new(0,10,0,10); cb.Position=UDim2.new(0,2,0.5,-5); cb.Text=is and "✅" or "⬜"; cb.TextSize=6; cb.BackgroundTransparency=1; cb.BorderSizePixel=0; cb.AutoButtonColor=false; cb.Parent=r
            local lb=Instance.new("TextLabel"); lb.Size=UDim2.new(0,75,1,0); lb.Position=UDim2.new(0,14,0,0); lb.Text=fn; lb.TextColor3=is and C.text or C.textDim; lb.Font=Enum.Font.Gotham; lb.TextSize=7; lb.TextXAlignment=Enum.TextXAlignment.Left; lb.BackgroundTransparency=1; lb.Parent=r
            local ml=Instance.new("TextLabel"); ml.Size=UDim2.new(0,32,1,0); ml.Position=UDim2.new(0,90,0,0); ml.Text="X"..string.format("%.1f",m); ml.TextColor3=m>=t and C.orange or Color3.fromRGB(150,150,150); ml.Font=Enum.Font.Gotham; ml.TextSize=7; ml.BackgroundTransparency=1; ml.Parent=r
            local inp=Instance.new("TextBox"); inp.Size=UDim2.new(0,30,0,12); inp.Position=UDim2.new(1,-33,0.5,-6); inp.BackgroundColor3=Color3.fromRGB(50,50,60); inp.Text=string.format("%.1f",t); inp.TextColor3=C.text; inp.Font=Enum.Font.Gotham; inp.TextSize=7; inp.BorderSizePixel=0; inp.Visible=is; inp.Parent=r; Instance.new("UICorner",inp).CornerRadius=UDim.new(0,2)
            inp.FocusLost:Connect(function() local n=tonumber(inp.Text); if n and n>0 then config.sellTargets[fn]=n; saveConfig(); inp.Text=string.format("%.1f",n) else inp.Text=string.format("%.1f",t) end end)
            local function ti() config.selectedSellFruits[fn]=not config.selectedSellFruits[fn]; saveConfig(); rebuildSell() end
            cb.MouseButton1Click:Connect(ti); r.InputBegan:Connect(function(ip) if ip.UserInputType==Enum.UserInputType.MouseButton1 then ti() end end); sellItemRows[fn]={frame=r,multLbl=ml,inp=inp}
        end
    end
    sellSB:GetPropertyChangedSignal("Text"):Connect(rebuildSell); sellHead.MouseButton1Click:Connect(function() sellOpen=not sellOpen; sellBody.Visible=sellOpen; sellArr.Text=sellOpen and "▼" or "▶"; sellCont.Size=UDim2.new(1,-12,0,sellOpen and(sellBody.Size.Y.Offset+24)or 22) end); rebuildSell()
    local sellToggleBtn=Instance.new("TextButton"); sellToggleBtn.Size=UDim2.new(1,-12,0,28); sellToggleBtn.LayoutOrder=100; sellToggleBtn.Text=isRunningSell and "⏹ STOP" or "▶ START"; sellToggleBtn.TextColor3=C.text; sellToggleBtn.Font=Enum.Font.GothamBold; sellToggleBtn.TextSize=10; sellToggleBtn.BackgroundColor3=isRunningSell and C.red or C.green; sellToggleBtn.BorderSizePixel=0; sellToggleBtn.AutoButtonColor=false; sellToggleBtn.Parent=sellScroll; Instance.new("UICorner",sellToggleBtn).CornerRadius=UDim.new(0,5)
    sellToggleBtn.MouseEnter:Connect(function() sellToggleBtn.BackgroundColor3=isRunningSell and Color3.fromRGB(220,70,70) or Color3.fromRGB(70,220,70) end)
    sellToggleBtn.MouseLeave:Connect(function() sellToggleBtn.BackgroundColor3=isRunningSell and C.red or C.green end)
    sellToggleBtn.MouseButton1Click:Connect(function() if isRunningSell then stopSell() else startSell() end; updateSellUI() end)
    task.spawn(function() while parentSell.Parent do task.wait(0.5); pcall(updateSellUI) end end)
    parentSell.Destroying:Connect(function() stopSell(); saveConfig() end)

    -- ==================================================================
    -- TAB 3: AUTO MAIL
    -- ==================================================================
    local parentMail = tabFrames["AutoMail"]
    local SharedModules = ReplicatedStorage.SharedModules
    local MailboxItemCatalog = nil; pcall(function() MailboxItemCatalog = require(player.PlayerScripts.Controllers.MailboxController.MailboxItemCatalog) end)
    local function getBackpackStock(itemName) local bp=player:FindFirstChild("Backpack"); if not bp then return 0 end; local t=bp:FindFirstChild(itemName); if t then local c=t:GetAttribute("Count"); if c and type(c)=="number" then return c end; return 1 end; return 0 end
    local function getBackpackPets() local pets={}; local bp=player:FindFirstChild("Backpack"); if bp then for _,i in ipairs(bp:GetChildren()) do if i:IsA("Tool")or i:IsA("Configuration") then local pn=i:GetAttribute("Pet"); local pi=i:GetAttribute("PetId"); if pn and pi then if not pets[pn] then pets[pn]={name=pn,count=0,ids={}} end; if not pets[pn].ids[pi] then pets[pn].ids[pi]=true; pets[pn].count=pets[pn].count+1 end end end end end; local r={}; for _,pd in pairs(pets) do table.insert(r,{name=pd.name,count=pd.count,id=next(pd.ids)}) end; return r end
    local ALL_DATA={Seeds={icon="🌱",items={},isUUID=false,maxInput=9999,getStock=getBackpackStock},Sprinklers={icon="💦",items={},isUUID=false,maxInput=9999,getStock=getBackpackStock},WateringCans={icon="🚿",items={"Common Watering Can","Super Watering Can","Syrup Watering Can","Super Syrup Watering Can"},isUUID=false,maxInput=9999,getStock=getBackpackStock},Pets={icon="🐾",items={},isUUID=true,maxInput=20,getStock=function() return 1 end},Crates={icon="📦",items={},isUUID=false,maxInput=9999,getStock=getBackpackStock},Eggs={icon="🥚",items={},isUUID=false,maxInput=9999,getStock=getBackpackStock},Props={icon="🏗️",items={},isUUID=false,maxInput=9999,getStock=getBackpackStock}}
    do local mod=safeRequire(SharedModules.SeedData); if mod then for _,d in ipairs(mod) do if d.SeedName then table.insert(ALL_DATA.Seeds.items,d.SeedName) end end end end
    do local mod=safeRequire(SharedModules.SprinklerData); if mod then for _,d in ipairs(mod) do if d.SprinklerName then table.insert(ALL_DATA.Sprinklers.items,d.SprinklerName) end end end end
    do local mod=safeRequire(SharedModules.CrateData); if mod and mod.GetAllCrates then local cr=mod.GetAllCrates(); if cr then for _,d in ipairs(cr) do if d.Name then table.insert(ALL_DATA.Crates.items,d.Name) end end end end end
    do local mod=safeRequire(SharedModules.EggData); if mod and mod.Data then for _,d in ipairs(mod.Data) do if d.EggName then table.insert(ALL_DATA.Eggs.items,d.EggName) end end end end
    do local mod=safeRequire(SharedModules.PropData); if mod and mod.Data then for _,d in ipairs(mod.Data) do if d.PropName then table.insert(ALL_DATA.Props.items,d.PropName) end end end end
    do local pm=SharedModules:FindFirstChild("PetModules"); local pn={}; if pm then for _,c in ipairs(pm:GetChildren()) do if c:IsA("ModuleScript") then table.insert(pn,c.Name) end end end; local bp=getBackpackPets(); local bm={}; for _,p in ipairs(bp) do bm[p.name]=p end; local it={}; for _,n in ipairs(pn) do local d=bm[n]; table.insert(it,{name=n,count=d and d.count or 0,id=d and d.id or nil}) end; ALL_DATA.Pets.items=it end
    local selectedCat="Seeds"; local selMailItems=config.mailSelectedItems or {}; local isAutoRunning=config.isAutoMailRunning or false; local isClaimRunning=config.isAutoClaimRunning or false; local searchMailText=""; local catNames={"Seeds","Sprinklers","WateringCans","Pets","Crates","Eggs","Props"}; local autoScanMin,autoScanMax=60,120; local lastAutoScan,currentScanInterval=0,60; local lastClaimScan,currentClaimInterval=0,30; local claimScanMin,claimScanMax=30,60; local cachedUserId,cachedUsername=nil,nil
    local function countMailSelected() local c=0; for _,s in pairs(selMailItems) do if s.selected then c=c+(s.isPet and math.min(s.count,20)or 1) end end; return c end
    local function claimAllGifts() if not isClaimRunning then return false,"Claim OFF" end; local s,inbox=pcall(function() return net.Mailbox.OpenInbox:Fire() end); if not s or type(inbox)~="table" then return false,"Inbox kosong" end; local Worlds=require(ReplicatedStorage.SharedModules.Worlds); local cw=Worlds.CurrentId; local claimed,skipped=0,0; for id,gift in pairs(inbox) do if not isClaimRunning then break end; local gw=gift.FromWorld or"Main"; if gw==cw then pcall(function() net.Mailbox.Claim:Fire(id) end); claimed=claimed+1 else skipped=skipped+1 end; if claimed>0 then task.wait(math.random(10,30)/10) end end; if claimed==0 and skipped==0 then return false,"Tidak ada gift" end; local msg="Claimed "..claimed; if skipped>0 then msg=msg.." | Skip "..skipped end; return true,msg end

    local mailScroll=Instance.new("ScrollingFrame"); mailScroll.Size=UDim2.new(1,0,1,0); mailScroll.CanvasSize=UDim2.new(0,0,0,800); mailScroll.ScrollBarThickness=3; mailScroll.BackgroundTransparency=1; mailScroll.BorderSizePixel=0; mailScroll.Parent=parentMail
    local mailLayout=Instance.new("UIListLayout"); mailLayout.Padding=UDim.new(0,4); mailLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center; mailLayout.SortOrder=Enum.SortOrder.LayoutOrder; mailLayout.Parent=mailScroll
    local mailHdr=Instance.new("TextLabel"); mailHdr.Size=UDim2.new(1,-12,0,16); mailHdr.LayoutOrder=1; mailHdr.Text="📦  Auto Mail & Claim"; mailHdr.TextColor3=C.text; mailHdr.Font=Enum.Font.GothamBold; mailHdr.TextSize=10; mailHdr.TextXAlignment=Enum.TextXAlignment.Left; mailHdr.BackgroundTransparency=1; mailHdr.Parent=mailScroll
    local userBox=Instance.new("TextBox"); userBox.Size=UDim2.new(1,-12,0,22); userBox.LayoutOrder=2; userBox.BackgroundColor3=C.input; userBox.TextColor3=C.text; userBox.PlaceholderText="Username target..."; userBox.PlaceholderColor3=Color3.fromRGB(100,100,110); userBox.Font=Enum.Font.Gotham; userBox.TextSize=10; userBox.Text=config.mailTargetUsername or ""; userBox.BorderSizePixel=0; userBox.Parent=mailScroll; Instance.new("UICorner",userBox).CornerRadius=UDim.new(0,4)
    local playerInfoFrame=Instance.new("Frame"); playerInfoFrame.Size=UDim2.new(1,-12,0,30); playerInfoFrame.LayoutOrder=3; playerInfoFrame.BackgroundColor3=Color3.fromRGB(30,30,36); playerInfoFrame.BorderSizePixel=0; playerInfoFrame.Visible=false; playerInfoFrame.Parent=mailScroll; Instance.new("UICorner",playerInfoFrame).CornerRadius=UDim.new(0,4)
    local playerImage=Instance.new("ImageLabel"); playerImage.Size=UDim2.new(0,22,0,22); playerImage.Position=UDim2.new(0,4,0.5,-11); playerImage.BackgroundColor3=Color3.fromRGB(40,40,45); playerImage.Image="rbxasset://textures/ui/GuiImagePlaceholder.png"; playerImage.Parent=playerInfoFrame; Instance.new("UICorner",playerImage).CornerRadius=UDim.new(1,0)
    local playerDisplayLabel=Instance.new("TextLabel"); playerDisplayLabel.Size=UDim2.new(1,-30,0,14); playerDisplayLabel.Position=UDim2.new(0,30,0,0); playerDisplayLabel.BackgroundTransparency=1; playerDisplayLabel.Text=""; playerDisplayLabel.TextColor3=C.text; playerDisplayLabel.Font=Enum.Font.GothamBold; playerDisplayLabel.TextSize=10; playerDisplayLabel.TextXAlignment=Enum.TextXAlignment.Left; playerDisplayLabel.Parent=playerInfoFrame
    local playerNameLabel=Instance.new("TextLabel"); playerNameLabel.Size=UDim2.new(1,-30,0,10); playerNameLabel.Position=UDim2.new(0,30,0,14); playerNameLabel.BackgroundTransparency=1; playerNameLabel.Text=""; playerNameLabel.TextColor3=Color3.fromRGB(150,150,160); playerNameLabel.Font=Enum.Font.Gotham; playerNameLabel.TextSize=8; playerNameLabel.TextXAlignment=Enum.TextXAlignment.Left; playerNameLabel.Parent=playerInfoFrame
    local function updatePlayerInfo(un) if not un or un=="" then playerInfoFrame.Visible=false; cachedUserId=nil; cachedUsername=nil; return end; playerInfoFrame.Visible=true; playerNameLabel.Text="@"..un; playerDisplayLabel.Text="Loading..."; playerImage.Image="rbxasset://textures/ui/GuiImagePlaceholder.png"; task.spawn(function() local uid,dn=net.Mailbox.LookupPlayer:Fire(un); if uid and uid>0 then cachedUserId=uid; cachedUsername=un; if MailboxItemCatalog then local hs=MailboxItemCatalog.GetCachedHeadshot(uid); if hs and hs~="" then playerImage.Image=hs else task.spawn(function() local img=MailboxItemCatalog.GetHeadshot(uid); if img~="" then playerImage.Image=img end end) end end; playerDisplayLabel.Text=(dn and dn~="" and dn or un) else cachedUserId=nil; cachedUsername=nil; playerDisplayLabel.Text="User tidak ditemukan"; playerNameLabel.Text="" end end) end
    userBox.FocusLost:Connect(function() if userBox.Text~="" then config.mailTargetUsername=userBox.Text; saveConfig(); updatePlayerInfo(userBox.Text) end end)
    local selMailLabel=Instance.new("TextLabel"); selMailLabel.Size=UDim2.new(1,-12,0,12); selMailLabel.LayoutOrder=4; selMailLabel.BackgroundTransparency=1; selMailLabel.Text="📋 Terpilih: 0/20"; selMailLabel.TextColor3=C.yellow; selMailLabel.Font=Enum.Font.GothamBold; selMailLabel.TextSize=9; selMailLabel.TextXAlignment=Enum.TextXAlignment.Left; selMailLabel.Parent=mailScroll
    local searchBox=Instance.new("TextBox"); searchBox.Size=UDim2.new(1,-12,0,20); searchBox.LayoutOrder=5; searchBox.BackgroundColor3=C.input; searchBox.TextColor3=C.text; searchBox.PlaceholderText="🔍 Cari item..."; searchBox.PlaceholderColor3=Color3.fromRGB(100,100,110); searchBox.Font=Enum.Font.Gotham; searchBox.TextSize=9; searchBox.Text=""; searchBox.ClearTextOnFocus=false; searchBox.BorderSizePixel=0; searchBox.Parent=mailScroll; Instance.new("UICorner",searchBox).CornerRadius=UDim.new(0,4)
    searchBox:GetPropertyChangedSignal("Text"):Connect(function() searchMailText=searchBox.Text:lower(); refreshMailList() end)
    local tabFrame=Instance.new("Frame"); tabFrame.Size=UDim2.new(1,-12,0,22); tabFrame.LayoutOrder=6; tabFrame.BackgroundColor3=Color3.fromRGB(25,25,30); tabFrame.BorderSizePixel=0; tabFrame.Parent=mailScroll; Instance.new("UICorner",tabFrame).CornerRadius=UDim.new(0,4)
    local tabButtons={}; local tabWidth=1/#catNames
    for i,cat in ipairs(catNames) do local btn=Instance.new("TextButton"); btn.Size=UDim2.new(tabWidth,-1,1,-2); btn.Position=UDim2.new(tabWidth*(i-1),1,0,1); btn.BackgroundColor3=i==1 and Color3.fromRGB(0,140,80) or Color3.fromRGB(40,40,45); btn.Text=ALL_DATA[cat].icon; btn.TextColor3=C.text; btn.Font=Enum.Font.GothamBold; btn.TextSize=12; btn.BorderSizePixel=0; btn.Parent=tabFrame; Instance.new("UICorner",btn).CornerRadius=UDim.new(0,3)
        btn.MouseButton1Click:Connect(function() selectedCat=cat; searchMailText=""; searchBox.Text=""; for _,b in pairs(tabButtons) do b.BackgroundColor3=Color3.fromRGB(40,40,45) end; btn.BackgroundColor3=Color3.fromRGB(0,140,80); if cat=="Pets" then local bp=getBackpackPets(); local bm={}; for _,p in ipairs(bp) do bm[p.name]=p end; for _,item in ipairs(ALL_DATA.Pets.items) do local d=bm[item.name]; item.count=d and d.count or 0; item.id=d and d.id or nil end end; refreshMailList() end); tabButtons[cat]=btn end
    local mailItemList=Instance.new("ScrollingFrame"); mailItemList.Size=UDim2.new(1,-12,0,120); mailItemList.LayoutOrder=7; mailItemList.BackgroundColor3=Color3.fromRGB(24,24,30); mailItemList.BorderSizePixel=0; mailItemList.ScrollBarThickness=3; mailItemList.Parent=mailScroll; Instance.new("UICorner",mailItemList).CornerRadius=UDim.new(0,4)
    local mailItemLayout=Instance.new("UIListLayout"); mailItemLayout.Padding=UDim.new(0,2); mailItemLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center; mailItemLayout.Parent=mailItemList
    local mailStatusText=Instance.new("TextLabel"); mailStatusText.Size=UDim2.new(1,-12,0,12); mailStatusText.LayoutOrder=8; mailStatusText.BackgroundTransparency=1; mailStatusText.Text="✅ SIAP"; mailStatusText.TextColor3=C.green; mailStatusText.Font=Enum.Font.GothamBold; mailStatusText.TextSize=9; mailStatusText.TextXAlignment=Enum.TextXAlignment.Left; mailStatusText.Parent=mailScroll
    local autoStatusLabel=Instance.new("TextLabel"); autoStatusLabel.Size=UDim2.new(1,-12,0,10); autoStatusLabel.LayoutOrder=9; autoStatusLabel.BackgroundTransparency=1; autoStatusLabel.Text="🔄 Auto Mail: OFF"; autoStatusLabel.TextColor3=Color3.fromRGB(150,150,150); autoStatusLabel.Font=Enum.Font.Gotham; autoStatusLabel.TextSize=8; autoStatusLabel.TextXAlignment=Enum.TextXAlignment.Left; autoStatusLabel.Parent=mailScroll
    local claimStatusLabel=Instance.new("TextLabel"); claimStatusLabel.Size=UDim2.new(1,-12,0,10); claimStatusLabel.LayoutOrder=10; claimStatusLabel.BackgroundTransparency=1; claimStatusLabel.Text="📬 Auto Claim: OFF"; claimStatusLabel.TextColor3=Color3.fromRGB(150,150,150); claimStatusLabel.Font=Enum.Font.Gotham; claimStatusLabel.TextSize=8; claimStatusLabel.TextXAlignment=Enum.TextXAlignment.Left; claimStatusLabel.Parent=mailScroll
    local sendBtn=Instance.new("TextButton"); sendBtn.Size=UDim2.new(1,-12,0,24); sendBtn.LayoutOrder=11; sendBtn.BackgroundColor3=Color3.fromRGB(0,160,100); sendBtn.Text="📤 KIRIM SEKARANG"; sendBtn.TextColor3=C.text; sendBtn.Font=Enum.Font.GothamBold; sendBtn.TextSize=10; sendBtn.BorderSizePixel=0; sendBtn.AutoButtonColor=false; sendBtn.Parent=mailScroll; Instance.new("UICorner",sendBtn).CornerRadius=UDim.new(0,4)
    local autoBtn=Instance.new("TextButton"); autoBtn.Size=UDim2.new(1,-12,0,24); autoBtn.LayoutOrder=12; autoBtn.BackgroundColor3=Color3.fromRGB(0,120,180); autoBtn.Text="🔄 MULAI AUTO MAIL"; autoBtn.TextColor3=C.text; autoBtn.Font=Enum.Font.GothamBold; autoBtn.TextSize=10; autoBtn.BorderSizePixel=0; autoBtn.AutoButtonColor=false; autoBtn.Parent=mailScroll; Instance.new("UICorner",autoBtn).CornerRadius=UDim.new(0,4)
    local claimBtn=Instance.new("TextButton"); claimBtn.Size=UDim2.new(1,-12,0,24); claimBtn.LayoutOrder=13; claimBtn.BackgroundColor3=Color3.fromRGB(120,60,160); claimBtn.Text="📬 MULAI AUTO CLAIM"; claimBtn.TextColor3=C.text; claimBtn.Font=Enum.Font.GothamBold; claimBtn.TextSize=10; claimBtn.BorderSizePixel=0; claimBtn.AutoButtonColor=false; claimBtn.Parent=mailScroll; Instance.new("UICorner",claimBtn).CornerRadius=UDim.new(0,4)

    local function updateMailSelLabel() local c=countMailSelected(); selMailLabel.Text="📋 Terpilih: "..c.."/20"; selMailLabel.TextColor3=c>20 and C.red or(c>0 and C.green or C.yellow) end
    function refreshMailList()
        for _,child in ipairs(mailItemList:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
        local data=ALL_DATA[selectedCat]; if not data then return end; local items={}
        for _,id in ipairs(data.items) do local name=type(id)=="table" and(id.name or"?")or tostring(id); if searchMailText=="" or name:lower():find(searchMailText) then table.insert(items,id) end end
        mailItemList.CanvasSize=UDim2.new(0,0,0,math.max(#items*24+8,10))
        for _,id in ipairs(items) do local name,itemId,itemCount=nil,nil,0; if type(id)=="table" then name=id.name or"?"; itemId=id.id; itemCount=id.count or data.getStock(name) else name=tostring(id); itemCount=data.getStock(name) end; local key=itemId or name; if not selMailItems[key] then selMailItems[key]={selected=false,count=1,isPet=data.isUUID} end; local sel=selMailItems[key]; sel.isPet=data.isUUID
            local fr=Instance.new("Frame",mailItemList); fr.Size=UDim2.new(1,-8,0,22); fr.BackgroundColor3=sel.selected and Color3.fromRGB(40,60,45) or Color3.fromRGB(38,38,44); fr.BorderSizePixel=0; Instance.new("UICorner",fr).CornerRadius=UDim.new(0,3)
            local cb=Instance.new("TextButton",fr); cb.Size=UDim2.new(0,14,0,14); cb.Position=UDim2.new(0,4,0.5,-7); cb.BackgroundColor3=sel.selected and Color3.fromRGB(0,160,80) or Color3.fromRGB(55,55,60); cb.Text=""; cb.BorderSizePixel=0; Instance.new("UICorner",cb).CornerRadius=UDim.new(0,2)
            local cm=Instance.new("TextLabel",cb); cm.Size=UDim2.new(1,0,1,0); cm.BackgroundTransparency=1; cm.Text="✓"; cm.TextColor3=C.green; cm.Font=Enum.Font.GothamBold; cm.TextSize=10; cm.Visible=sel.selected
            local lb=Instance.new("TextLabel",fr); lb.Size=UDim2.new(1,-100,1,0); lb.Position=UDim2.new(0,22,0,0); lb.BackgroundTransparency=1; lb.Text=#name>18 and name:sub(1,16)..".." or name; lb.TextColor3=Color3.fromRGB(220,220,220); lb.Font=Enum.Font.Gotham; lb.TextSize=8; lb.TextXAlignment=Enum.TextXAlignment.Left
            local sl=Instance.new("TextLabel",fr); sl.Size=UDim2.new(0,28,1,0); sl.Position=UDim2.new(1,-68,0,0); sl.BackgroundTransparency=1; sl.Text="x"..itemCount; sl.TextColor3=itemCount>0 and Color3.fromRGB(0,255,150) or Color3.fromRGB(120,120,120); sl.Font=Enum.Font.GothamBold; sl.TextSize=7; sl.TextXAlignment=Enum.TextXAlignment.Right
            local ci=Instance.new("TextBox",fr); ci.Size=UDim2.new(0,32,0,14); ci.Position=UDim2.new(1,-36,0.5,-7); ci.BackgroundColor3=Color3.fromRGB(50,50,55); ci.TextColor3=C.text; ci.Font=Enum.Font.Gotham; ci.TextSize=7; ci.Text=tostring(sel.count); ci.BorderSizePixel=0; Instance.new("UICorner",ci).CornerRadius=UDim.new(0,2)
            ci.FocusLost:Connect(function() local v=tonumber(ci.Text); if v and v>0 then sel.count=math.min(v,data.maxInput); ci.Text=tostring(sel.count) else ci.Text=tostring(sel.count) end; updateMailSelLabel() end)
            local function ti() if not sel.selected then if countMailSelected()+(data.isUUID and math.min(sel.count,20)or 1)>20 then mailStatusText.Text="❌ Max 20!"; mailStatusText.TextColor3=C.red; return end end; sel.selected=not sel.selected; cb.BackgroundColor3=sel.selected and Color3.fromRGB(0,160,80) or Color3.fromRGB(55,55,60); cm.Visible=sel.selected; fr.BackgroundColor3=sel.selected and Color3.fromRGB(40,60,45) or Color3.fromRGB(38,38,44);
config.mailSelectedItems=selMailItems; saveConfig(); updateMailSelLabel() end
            cb.MouseButton1Click:Connect(ti)
        end; updateMailSelLabel()
    end
    local function doSend(forceSend)
    local un = userBox.Text
    if un == "" then return false, "ISI USERNAME!" end
    if countMailSelected() > 20 then return false, "Max 20!" end
    
    local uid
    if cachedUsername == un and cachedUserId then uid = cachedUserId
    else updatePlayerInfo(un); task.wait(1); uid = cachedUserId end
    if not uid or uid <= 0 then return false, "User tidak ditemukan!" end
    
    -- Refresh pets
    local bp = getBackpackPets(); local bm = {}
    for _, p in ipairs(bp) do bm[p.name] = p end
    for _, item in ipairs(ALL_DATA.Pets.items) do
        local d = bm[item.name]
        item.count = d and d.count or 0
        item.id = d and d.id or nil
    end
    
    -- ⬇️ SIMPAN STOCK SEBELUM KIRIM (format: [key] = {name, count, isUUID})
    local stockBefore = {}
    for cat, data in pairs(ALL_DATA) do
        for _, id in ipairs(data.items) do
            local name = type(id) == "table" and (id.name or "?") or tostring(id)
            local iid = type(id) == "table" and id.id or nil
            local key = iid or name
            stockBefore[key] = {
                name = name,
                count = data.getStock(name),
                isUUID = data.isUUID,
                category = cat
            }
        end
    end
    
    local its = {}  -- Items to send
    
    -- Loop & kirim yang ready
    for cat, data in pairs(ALL_DATA) do
        for _, id in ipairs(data.items) do
            local name = type(id) == "table" and (id.name or "?") or tostring(id)
            local iid = type(id) == "table" and id.id or nil
            local key = iid or name
            local sel = selMailItems[key]
            
            if sel and sel.selected then
                local count = sel.count
                if count <= 0 then count = type(id) == "table" and (id.count or 1) or data.getStock(name) end
                local stock = type(id) == "table" and (id.count or data.getStock(name)) or data.getStock(name)
                
                if forceSend or stock >= count then
                    count = math.min(count, stock, data.maxInput or 9999)
                    if count > 0 then
                        table.insert(its, {
                            Category = cat,
                            ItemKey = data.isUUID and (iid or name) or name,
                            Count = count
                        })
                    end
                end
            end
        end
    end
    
    if #its == 0 then return false, "Stok kosong!" end
    if #its > 20 then return false, "Max 20 jenis!" end
    
    -- ⬇️ KIRIM ⬇️
    local sendSuccess = pcall(function()
        net.Mailbox.SendBatch:Fire(uid, its, "")
    end)
    
    if not sendSuccess then return false, "Gagal kirim (error)" end
    
    -- ⬇️ TUNGGU SERVER PROSES ⬇️
    task.wait(3)
    
    -- ⬇️ VERIFIKASI: cek stock BERKURANG untuk setiap item yang dikirim ⬇️
    local sentAny = false
    
    for _, item in ipairs(its) do
        local key = item.ItemKey
        local before = stockBefore[key]
        
        if before then
            if before.isUUID then
                -- Cek pet hilang dari backpack
                local found = false
                local currentPets = getBackpackPets()
                for _, p in ipairs(currentPets) do
                    if p.id == key or p.name == before.name then
                        found = true
                        break
                    end
                end
                if not found then
                    sentAny = true
                    break
                end
            else
                -- Cek stock berkurang
                local afterStock = ALL_DATA[before.category].getStock(before.name)
                if afterStock < before.count then
                    sentAny = true
                    break
                end
            end
        end
    end
    
    if not sentAny then
        return false, "Gagal terkirim (stock tidak berubah)"
    end
    
    -- Refresh GUI
    task.delay(1, refreshMailList)
    
    return true, "TERKIRIM! " .. #its .. " jenis"
    end
    
    sendBtn.MouseButton1Click:Connect(function() updatePlayerInfo(userBox.Text); mailStatusText.Text="📤 Mengirim..."; mailStatusText.TextColor3=Color3.fromRGB(0,200,255); local ok,msg=doSend(true); mailStatusText.Text=(ok and"✅ "or"❌ ")..msg; mailStatusText.TextColor3=ok and C.green or C.red; if ok then task.delay(1,refreshMailList); task.delay(3,refreshMailList) end end)
    autoBtn.MouseButton1Click:Connect(function()
    isAutoRunning = not isAutoRunning
    config.isAutoMailRunning = isAutoRunning
    saveConfig()
    
    if isAutoRunning then
        if userBox.Text == "" then
            mailStatusText.Text = "❌ ISI USERNAME!"
            mailStatusText.TextColor3 = C.red
            isAutoRunning = false
            config.isAutoMailRunning = false
            saveConfig()
            return
        end
        updatePlayerInfo(userBox.Text)
        autoBtn.Text = "⏸ STOP AUTO MAIL"
        autoBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        lastAutoScan = 0
        currentScanInterval = math.random(autoScanMin, autoScanMax)
        autoStatusLabel.Text = "🔄 Auto Mail: ON (scan " .. currentScanInterval .. "s)"
        autoStatusLabel.TextColor3 = C.green
        
        -- Langsung kirim saat start
        task.spawn(function()
            local ok, msg = doSend(false)
            if ok then
                mailStatusText.Text = "✅ " .. msg
                mailStatusText.TextColor3 = C.green
                task.delay(1, refreshMailList)
                task.delay(3, refreshMailList)
            else
                mailStatusText.Text = "❌ " .. msg
                mailStatusText.TextColor3 = C.red
            end
        end)
    else
        autoBtn.Text = "🔄 MULAI AUTO MAIL"
        autoBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 180)
        autoStatusLabel.Text = "🔄 Auto Mail: OFF"
        autoStatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        task.delay(1, refreshMailList) end end)
    claimBtn.MouseButton1Click:Connect(function() isClaimRunning=not isClaimRunning; config.isAutoClaimRunning=isClaimRunning; saveConfig(); if isClaimRunning then claimBtn.Text="⏸ STOP AUTO CLAIM"; claimBtn.BackgroundColor3=Color3.fromRGB(180,50,120); lastClaimScan=0; currentClaimInterval=math.random(claimScanMin,claimScanMax); claimStatusLabel.Text="📬 Auto Claim: ON (scan "..currentClaimInterval.."s)"; claimStatusLabel.TextColor3=Color3.fromRGB(200,100,255); local ok,msg=claimAllGifts(); if ok then mailStatusText.Text="✅ "..msg; mailStatusText.TextColor3=C.green end else claimBtn.Text="📬 MULAI AUTO CLAIM"; claimBtn.BackgroundColor3=Color3.fromRGB(120,60,160); claimStatusLabel.Text="📬 Auto Claim: OFF"; claimStatusLabel.TextColor3=Color3.fromRGB(150,150,150) end end)
    task.spawn(function()
    while parentMail.Parent do
        task.wait(1)
        
        if isAutoRunning then
            lastAutoScan = lastAutoScan + 1
            autoStatusLabel.Text = "🔄 Auto Mail: ON (scan " .. (currentScanInterval - lastAutoScan) .. "s)"
            
            if lastAutoScan >= currentScanInterval then
                lastAutoScan = 0
                currentScanInterval = math.random(autoScanMin, autoScanMax)
                
                local bp = getBackpackPets(); local bm = {}
                for _, p in ipairs(bp) do bm[p.name] = p end
                for _, item in ipairs(ALL_DATA.Pets.items) do
                    local d = bm[item.name]
                    item.count = d and d.count or 0
                    item.id = d and d.id or nil
                end
                refreshMailList()
                
                local ok, msg = doSend(false)
                if ok then
                    mailStatusText.Text = "✅ " .. msg
                    mailStatusText.TextColor3 = C.green
                    task.delay(5, refreshMailList)
                else
                    mailStatusText.Text = "❌ " .. msg
                    mailStatusText.TextColor3 = C.red
                end
            end
        end
        
        if isClaimRunning then
            lastClaimScan = lastClaimScan + 1
            claimStatusLabel.Text = "📬 Auto Claim: ON (scan " .. (currentClaimInterval - lastClaimScan) .. "s)"
            
            if lastClaimScan >= currentClaimInterval then
                lastClaimScan = 0
                currentClaimInterval = math.random(claimScanMin, claimScanMax)
                local ok, msg = claimAllGifts()
                if ok then
                    mailStatusText.Text = "✅ " .. msg
                    mailStatusText.TextColor3 = C.green
                else
                    mailStatusText.Text = "❌ " .. msg
                    mailStatusText.TextColor3 = C.red end end end end end)
    refreshMailList()
    parentMail.Destroying:Connect(function() config.mailTargetUsername=userBox.Text; config.mailSelectedItems=selMailItems; config.isAutoMailRunning=isAutoRunning; config.isAutoClaimRunning=isClaimRunning; saveConfig() end) 
    -- ==================================================================
-- TAB 4: MAIL FRUIT (FULL FIX - UI DULU, FUNGSI BELAKANGAN)
-- ==================================================================
-- ==================================================================
-- TAB 4: MAIL FRUIT (FULL FIX - POSITION ABSOLUTE)
-- ==================================================================
local parentFruit = tabFrames["MailFruit"]
local netFruit = safeRequire(ReplicatedStorage.SharedModules.Networking)
local FruitValueCalc = safeRequire(ReplicatedStorage.SharedModules.FruitValueCalc)
local SellFlags = safeRequire(ReplicatedStorage.SharedModules.Flags.SellFlags)

local MAX_ITEMS_PER_BATCH = 20
local BATCH_DELAY = 21
local DEFAULT_TOLERANCE = 10
local usernameList = config.mailFruitUsers or {}
local selectedUserIndex = nil
local isFruitAutoRunning = false
local lastFailedIndex = nil

-- ==================================================================
-- HELPER FUNCTIONS
-- ==================================================================
local function getFruitValues()
    local fruits = {}
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return fruits end
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Configuration") or item:IsA("Tool") then
            local fruitId = item:GetAttribute("Id")
            local fruitName = item:GetAttribute("FruitName") or item.Name
            local sizeMultiplier = item:GetAttribute("SizeMultiplier") or 1
            local mutation = item:GetAttribute("Mutation") or ""
            if fruitId and fruitName then
                local finalValue = 0
                if FruitValueCalc and SellFlags then
                    pcall(function()
                        local baseValue = FruitValueCalc(fruitName, sizeMultiplier, mutation, player, nil)
                        local valueWithBoost = SellFlags.Apply(fruitName, baseValue)
                        finalValue = math.floor(valueWithBoost / 1.10)
                    end)
                end
                if finalValue == 0 then finalValue = math.floor(sizeMultiplier * 1000) end
                table.insert(fruits, {name = fruitName, id = fruitId, value = finalValue, size = sizeMultiplier, mutation = mutation})
            end
        end
    end
    table.sort(fruits, function(a, b) return a.value > b.value end)
    return fruits
end

local function formatValue(v)
    if v >= 1e12 then return string.format("%.2fT", v/1e12)
    elseif v >= 1e9 then return string.format("%.2fB", v/1e9)
    elseif v >= 1e6 then return string.format("%.2fM", v/1e6)
    elseif v >= 1e3 then return string.format("%.1fK", v/1e3)
    else return tostring(v) end
end

local function sendToUser(username, targetValue, tolerance)
    local fruits = getFruitValues()
    if #fruits == 0 then return false, "Tidak ada fruit!" end
    
    local userId = netFruit.Mailbox.LookupPlayer:Fire(username)
    if not userId or userId <= 0 then return false, "User tidak ditemukan!" end
    
    local minValue = targetValue * (1 - tolerance/100)
    local maxValue = targetValue * (1 + tolerance/100)
    local selected, totalValue = {}, 0
    
    for _, fruit in ipairs(fruits) do
        if totalValue + fruit.value <= maxValue then
            table.insert(selected, fruit); totalValue = totalValue + fruit.value
            if totalValue >= minValue then break end
        end
    end
    
    if totalValue < minValue then return false, "Stok kurang! Maks: " .. formatValue(totalValue) end
    if #selected > 60 then return false, "Terlalu banyak! " .. #selected .. " items" end
    
    -- Send batch
    local idsBefore = {}; for _, f in ipairs(selected) do idsBefore[f.id] = true end
    local batchesNeeded = math.ceil(#selected / MAX_ITEMS_PER_BATCH)
    
    for batchNum = 1, batchesNeeded do
        local si = (batchNum-1)*MAX_ITEMS_PER_BATCH+1; local ei = math.min(batchNum*MAX_ITEMS_PER_BATCH, #selected)
        local items = {}
        for i = si, ei do table.insert(items, {Category="HarvestedFruits", ItemKey=selected[i].id, Count=1}) end
        pcall(function() netFruit.Mailbox.SendBatch:Fire(userId, items, "") end)
        if batchNum < batchesNeeded then task.wait(BATCH_DELAY) end
    end
    
    task.wait(2)
    local currentIds = {}; local cf = getFruitValues(); for _, f in ipairs(cf) do currentIds[f.id] = true end
    local sc, fc = 0, 0
    for fid, _ in pairs(idsBefore) do if currentIds[fid] then fc=fc+1 else sc=sc+1 end end
    
    if sc > 0 then
        if fc > 0 then return true, "TERKIRIM! " .. formatValue(totalValue) .. " | " .. fc .. " gagal"
        else return true, "TERKIRIM! " .. formatValue(totalValue) .. " | " .. #selected .. " buah" end
    end
    return false, "Gagal terkirim"
end

-- Scroll (TANPA UIListLayout)
local fruitScroll = Instance.new("ScrollingFrame")
fruitScroll.Size = UDim2.new(1, 0, 1, 0)
fruitScroll.CanvasSize = UDim2.new(0, 0, 0, 520)
fruitScroll.ScrollBarThickness = 3
fruitScroll.BackgroundTransparency = 1
fruitScroll.BorderSizePixel = 0
fruitScroll.Parent = parentFruit

local y = 4  -- Posisi Y awal

-- Header
local fruitHdr = Instance.new("TextLabel")
fruitHdr.Size = UDim2.new(1, -12, 0, 16); fruitHdr.Position = UDim2.new(0, 6, 0, y)
fruitHdr.Text = "🎯  Smart Sender (Mail Fruit)"; fruitHdr.TextColor3 = C.text
fruitHdr.Font = Enum.Font.GothamBold; fruitHdr.TextSize = 10
fruitHdr.TextXAlignment = Enum.TextXAlignment.Left; fruitHdr.BackgroundTransparency = 1; fruitHdr.Parent = fruitScroll
y += 20

-- Value input
local valueBox = Instance.new("TextBox")
valueBox.Size = UDim2.new(1, -12, 0, 22); valueBox.Position = UDim2.new(0, 6, 0, y)
valueBox.BackgroundColor3 = C.input; valueBox.TextColor3 = C.text
valueBox.PlaceholderText = "Nilai target (contoh: 10000000)"; valueBox.PlaceholderColor3 = Color3.fromRGB(100,100,110)
valueBox.Font = Enum.Font.Gotham; valueBox.TextSize = 10; valueBox.Text = ""; valueBox.BorderSizePixel = 0; valueBox.Parent = fruitScroll
Instance.new("UICorner", valueBox).CornerRadius = UDim.new(0, 4)
y += 26

-- Tolerance
local toleranceInput = Instance.new("TextBox")
toleranceInput.Size = UDim2.new(1, -12, 0, 22); toleranceInput.Position = UDim2.new(0, 6, 0, y)
toleranceInput.BackgroundColor3 = C.input; toleranceInput.TextColor3 = C.text
toleranceInput.PlaceholderText = "Toleransi % (default: 10)"; toleranceInput.PlaceholderColor3 = Color3.fromRGB(100,100,110)
toleranceInput.Font = Enum.Font.Gotham; toleranceInput.TextSize = 10; toleranceInput.Text = tostring(DEFAULT_TOLERANCE)
toleranceInput.BorderSizePixel = 0; toleranceInput.Parent = fruitScroll
Instance.new("UICorner", toleranceInput).CornerRadius = UDim.new(0, 4)
y += 26

-- Add username
local addFrame = Instance.new("Frame")
addFrame.Size = UDim2.new(1, -12, 0, 22); addFrame.Position = UDim2.new(0, 6, 0, y); addFrame.BackgroundTransparency = 1; addFrame.Parent = fruitScroll
local addBox = Instance.new("TextBox")
addBox.Size = UDim2.new(1, -42, 1, 0); addBox.BackgroundColor3 = C.input; addBox.TextColor3 = C.text
addBox.PlaceholderText = "Tambah username..."; addBox.PlaceholderColor3 = Color3.fromRGB(100,100,110)
addBox.Font = Enum.Font.Gotham; addBox.TextSize = 10; addBox.Text = ""; addBox.BorderSizePixel = 0; addBox.Parent = addFrame
Instance.new("UICorner", addBox).CornerRadius = UDim.new(0, 4)
local addBtn = Instance.new("TextButton")
addBtn.Size = UDim2.new(0, 38, 1, 0); addBtn.Position = UDim2.new(1, -38, 0, 0)
addBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 200); addBtn.Text = "+"; addBtn.TextColor3 = C.text
addBtn.Font = Enum.Font.GothamBold; addBtn.TextSize = 14; addBtn.BorderSizePixel = 0; addBtn.AutoButtonColor = false; addBtn.Parent = addFrame
Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0, 4)
y += 26

-- User list label
local userListLabel = Instance.new("TextLabel")
userListLabel.Size = UDim2.new(1, -12, 0, 14); userListLabel.Position = UDim2.new(0, 6, 0, y)
userListLabel.BackgroundTransparency = 1; userListLabel.Text = "📋 Daftar Target (klik untuk pilih):"
userListLabel.TextColor3 = C.textDim; userListLabel.Font = Enum.Font.Gotham; userListLabel.TextSize = 9
userListLabel.TextXAlignment = Enum.TextXAlignment.Left; userListLabel.Parent = fruitScroll
y += 16

-- Player Info Frame (untuk selected user)
local fruitPlayerInfo = Instance.new("Frame")
fruitPlayerInfo.Size = UDim2.new(1, -12, 0, 36)
fruitPlayerInfo.Position = UDim2.new(0, 6, 0, y)
fruitPlayerInfo.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
fruitPlayerInfo.BorderSizePixel = 0
fruitPlayerInfo.Visible = false
fruitPlayerInfo.Parent = fruitScroll
Instance.new("UICorner", fruitPlayerInfo).CornerRadius = UDim.new(0, 4)
y += 40

local fruitPlayerImage = Instance.new("ImageLabel")
fruitPlayerImage.Size = UDim2.new(0, 26, 0, 26)
fruitPlayerImage.Position = UDim2.new(0, 5, 0.5, -13)
fruitPlayerImage.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
fruitPlayerImage.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
fruitPlayerImage.Parent = fruitPlayerInfo
Instance.new("UICorner", fruitPlayerImage).CornerRadius = UDim.new(1, 0)

local fruitPlayerDisplay = Instance.new("TextLabel")
fruitPlayerDisplay.Size = UDim2.new(1, -36, 0, 16)
fruitPlayerDisplay.Position = UDim2.new(0, 36, 0, 2)
fruitPlayerDisplay.BackgroundTransparency = 1
fruitPlayerDisplay.Text = ""
fruitPlayerDisplay.TextColor3 = C.text
fruitPlayerDisplay.Font = Enum.Font.GothamBold
fruitPlayerDisplay.TextSize = 11
fruitPlayerDisplay.TextXAlignment = Enum.TextXAlignment.Left
fruitPlayerDisplay.Parent = fruitPlayerInfo

local fruitPlayerName = Instance.new("TextLabel")
fruitPlayerName.Size = UDim2.new(1, -36, 0, 12)
fruitPlayerName.Position = UDim2.new(0, 36, 0, 18)
fruitPlayerName.BackgroundTransparency = 1
fruitPlayerName.Text = ""
fruitPlayerName.TextColor3 = Color3.fromRGB(150, 150, 160)
fruitPlayerName.Font = Enum.Font.Gotham
fruitPlayerName.TextSize = 8
fruitPlayerName.TextXAlignment = Enum.TextXAlignment.Left
fruitPlayerName.Parent = fruitPlayerInfo

-- User list frame
local userListFrame = Instance.new("ScrollingFrame")
userListFrame.Size = UDim2.new(1, -12, 0, 70); userListFrame.Position = UDim2.new(0, 6, 0, y)
userListFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 30); userListFrame.BorderSizePixel = 0
userListFrame.ScrollBarThickness = 3; userListFrame.Parent = fruitScroll
Instance.new("UICorner", userListFrame).CornerRadius = UDim.new(0, 4)
y += 74

-- Status
local fruitStatusText = Instance.new("TextLabel")
fruitStatusText.Size = UDim2.new(1, -12, 0, 12); fruitStatusText.Position = UDim2.new(0, 6, 0, y)
fruitStatusText.BackgroundTransparency = 1; fruitStatusText.Text = "✅ SIAP"; fruitStatusText.TextColor3 = C.green
fruitStatusText.Font = Enum.Font.GothamBold; fruitStatusText.TextSize = 9
fruitStatusText.TextXAlignment = Enum.TextXAlignment.Left; fruitStatusText.Parent = fruitScroll
y += 14

-- Setelah fruitStatusText:
local fruitStockLabel = Instance.new("TextLabel")
fruitStockLabel.Size = UDim2.new(1, -12, 0, 12)
fruitStockLabel.Position = UDim2.new(0, 6, 0, y)  -- Sesuaikan posisi
fruitStockLabel.BackgroundTransparency = 1
fruitStockLabel.Text = "📦 Klik Refresh untuk lihat stok"
fruitStockLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
fruitStockLabel.Font = Enum.Font.Gotham
fruitStockLabel.TextSize = 8
fruitStockLabel.TextXAlignment = Enum.TextXAlignment.Left
fruitStockLabel.Parent = fruitScroll
y += 14

-- Refresh stock button
local refreshStockBtn = Instance.new("TextButton")
refreshStockBtn.Size = UDim2.new(1, -12, 0, 18); refreshStockBtn.Position = UDim2.new(0, 6, 0, y)
refreshStockBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60); refreshStockBtn.Text = "🔄 Refresh Stok"
refreshStockBtn.TextColor3 = C.text; refreshStockBtn.Font = Enum.Font.Gotham; refreshStockBtn.TextSize = 8
refreshStockBtn.BorderSizePixel = 0; refreshStockBtn.AutoButtonColor = false; refreshStockBtn.Parent = fruitScroll
Instance.new("UICorner", refreshStockBtn).CornerRadius = UDim.new(0, 4)
y += 22

-- Resume button
local resumeBtn = Instance.new("TextButton")
resumeBtn.Size = UDim2.new(1, -12, 0, 22); resumeBtn.Position = UDim2.new(0, 6, 0, y)
resumeBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 180); resumeBtn.Text = "▶ LANJUTKAN (RESUME)"
resumeBtn.TextColor3 = C.text; resumeBtn.Font = Enum.Font.GothamBold; resumeBtn.TextSize = 9
resumeBtn.BorderSizePixel = 0; resumeBtn.AutoButtonColor = false; resumeBtn.Visible = false; resumeBtn.Parent = fruitScroll
Instance.new("UICorner", resumeBtn).CornerRadius = UDim.new(0, 4)
y += 26

-- Send button
local fruitSendBtn = Instance.new("TextButton")
fruitSendBtn.Size = UDim2.new(1, -12, 0, 22); fruitSendBtn.Position = UDim2.new(0, 6, 0, y)
fruitSendBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 100); fruitSendBtn.Text = "📤 KIRIM KE TARGET"
fruitSendBtn.TextColor3 = C.text; fruitSendBtn.Font = Enum.Font.GothamBold; fruitSendBtn.TextSize = 9
fruitSendBtn.BorderSizePixel = 0; fruitSendBtn.AutoButtonColor = false; fruitSendBtn.Parent = fruitScroll
Instance.new("UICorner", fruitSendBtn).CornerRadius = UDim.new(0, 4)
y += 26

-- Auto button
local fruitAutoBtn = Instance.new("TextButton")
fruitAutoBtn.Size = UDim2.new(1, -12, 0, 22); fruitAutoBtn.Position = UDim2.new(0, 6, 0, y)
fruitAutoBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 160); fruitAutoBtn.Text = "🔄 MULAI AUTO (MULTI)"
fruitAutoBtn.TextColor3 = C.text; fruitAutoBtn.Font = Enum.Font.GothamBold; fruitAutoBtn.TextSize = 9
fruitAutoBtn.BorderSizePixel = 0; fruitAutoBtn.AutoButtonColor = false; fruitAutoBtn.Parent = fruitScroll
Instance.new("UICorner", fruitAutoBtn).CornerRadius = UDim.new(0, 4)
y += 26

-- Update CanvasSize
fruitScroll.CanvasSize = UDim2.new(0, 0, 0, y + 10)

-- ==================================================================
-- FUNGSI REFRESH + ADD
-- ==================================================================

local function updateFruitPlayerInfo()
    if not selectedUserIndex then
        fruitPlayerInfo.Visible = false
        return
    end
    
    local username = usernameList[selectedUserIndex].username
    fruitPlayerInfo.Visible = true
    fruitPlayerName.Text = "@" .. username
    fruitPlayerDisplay.Text = "Loading..."
    fruitPlayerImage.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
    
    task.spawn(function()
        local userId, displayName = netFruit.Mailbox.LookupPlayer:Fire(username)
        
        if userId and userId > 0 then
            fruitPlayerDisplay.Text = (displayName and displayName ~= "" and displayName or username)
            
            -- LANGSUNG PAKAI PLAYERS SERVICE
            local Players = game:GetService("Players")
            local success, thumb = pcall(function()
                return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
            end)
            
            if success and thumb then
                fruitPlayerImage.Image = thumb
            end
        else
            fruitPlayerDisplay.Text = "User tidak ditemukan"
            fruitPlayerName.Text = ""
        end
    end)
end
    
local function refreshUsernameList()
    for _, child in ipairs(userListFrame:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
    local count = #usernameList
    userListFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(count * 22 + 8, 40))
    
    if count == 0 then
        local empty = Instance.new("TextLabel", userListFrame)
        empty.Size = UDim2.new(1, -8, 0, 20); empty.Position = UDim2.new(0, 4, 0, 10)
        empty.BackgroundTransparency = 1; empty.Text = "Belum ada username"
        empty.TextColor3 = Color3.fromRGB(150, 150, 150); empty.Font = Enum.Font.Gotham; empty.TextSize = 9
        resumeBtn.Visible = false
        lastFailedIndex = nil
        return
    end
    
    local sc = {waiting=Color3.fromRGB(255,200,0), sent=C.green, failed=C.red, skipped=Color3.fromRGB(150,150,150)}
    for i, data in ipairs(usernameList) do
        local isSel = (selectedUserIndex == i)
        local row = Instance.new("Frame", userListFrame)
        row.Size = UDim2.new(1, -6, 0, 20); row.Position = UDim2.new(0, 3, 0, (i-1)*22+2)
        row.BackgroundColor3 = isSel and Color3.fromRGB(50,70,85) or Color3.fromRGB(38,38,44); row.BorderSizePixel = 0
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 3)
        
        local idx = Instance.new("TextLabel", row); idx.Size=UDim2.new(0,16,1,0); idx.Position=UDim2.new(0,2,0,0)
        idx.BackgroundTransparency=1; idx.Text=i; idx.TextColor3=isSel and C.text or Color3.fromRGB(150,150,150); idx.Font=Enum.Font.GothamBold; idx.TextSize=8
        
        local nm = Instance.new("TextLabel", row); nm.Size=UDim2.new(1,-130,1,0); nm.Position=UDim2.new(0,18,0,0)
        nm.BackgroundTransparency=1; nm.Text=data.username; nm.TextColor3=isSel and Color3.fromRGB(200,240,255) or Color3.fromRGB(220,220,220)
        nm.Font=Enum.Font.Gotham; nm.TextSize=8; nm.TextXAlignment=Enum.TextXAlignment.Left
        
        local st = Instance.new("TextLabel", row); st.Size=UDim2.new(0,35,1,0); st.Position=UDim2.new(1,-108,0,0)
        st.BackgroundTransparency=1; st.Text=data.status; st.TextColor3=sc[data.status]or Color3.fromRGB(150,150,150)
        st.Font=Enum.Font.GothamBold; st.TextSize=6; st.TextXAlignment=Enum.TextXAlignment.Right
        
        -- Skip/Unskip toggle
        local skipBtn = Instance.new("TextButton", row)
        skipBtn.Size=UDim2.new(0,30,1,-2); skipBtn.Position=UDim2.new(1,-72,0,1)
        if data.status == "skipped" then
            skipBtn.BackgroundColor3=Color3.fromRGB(50,60,40); skipBtn.Text="Unskip"; skipBtn.TextColor3=Color3.fromRGB(150,255,150)
        else
            skipBtn.BackgroundColor3=Color3.fromRGB(60,50,30); skipBtn.Text="Skip"; skipBtn.TextColor3=Color3.fromRGB(255,200,150)
        end
        skipBtn.Font=Enum.Font.GothamBold; skipBtn.TextSize=6; skipBtn.BorderSizePixel=0
        Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 2)
        skipBtn.MouseButton1Click:Connect(function()
            if usernameList[i].status == "skipped" then usernameList[i].status = "waiting"
            else usernameList[i].status = "skipped" end
            config.mailFruitUsers=usernameList; saveConfig(); refreshUsernameList()
        end)
        
        -- Select
        local sb = Instance.new("TextButton", row); sb.Size=UDim2.new(0,22,1,-2); sb.Position=UDim2.new(1,-40,0,1)
        sb.BackgroundColor3=isSel and Color3.fromRGB(0,140,200) or Color3.fromRGB(40,40,50)
        sb.Text=isSel and "✓" or "Sel"; sb.TextColor3=C.text; sb.Font=Enum.Font.GothamBold; sb.TextSize=6; sb.BorderSizePixel=0
        Instance.new("UICorner", sb).CornerRadius = UDim.new(0, 2)
        sb.MouseButton1Click:Connect(function() selectedUserIndex=i; refreshUsernameList(); updateFruitPlayerInfo() end)
        
        -- Delete
        local db = Instance.new("TextButton", row); db.Size=UDim2.new(0,18,1,-2); db.Position=UDim2.new(1,-16,0,1)
        db.BackgroundColor3=Color3.fromRGB(60,30,30); db.Text="✕"; db.TextColor3=Color3.fromRGB(255,100,100)
        db.Font=Enum.Font.GothamBold; db.TextSize=6; db.BorderSizePixel=0
        Instance.new("UICorner", db).CornerRadius = UDim.new(0, 2)
        db.MouseButton1Click:Connect(function() table.remove(usernameList,i); if selectedUserIndex==i then selectedUserIndex=nil; fruitPlayerInfo.Visible=false end; config.mailFruitUsers=usernameList; saveConfig(); refreshUsernameList() end)
    end
    
    if lastFailedIndex then
        resumeBtn.Visible = true
    else
        resumeBtn.Visible = false
    end
end

local function addUsername(name)
    if name ~= "" then
        for _, d in ipairs(usernameList) do if d.username:lower()==name:lower() then return end end
        table.insert(usernameList, {username=name, status="waiting"})
        config.mailFruitUsers=usernameList; saveConfig(); refreshUsernameList()
    end
end

local function resetAllStatus()
    for _, data in ipairs(usernameList) do data.status = "waiting" end
    lastFailedIndex = nil; config.mailFruitUsers=usernameList; saveConfig(); refreshUsernameList()
end

-- ==================================================================
-- BUTTON HANDLERS
-- ==================================================================
addBtn.MouseButton1Click:Connect(function() addUsername(addBox.Text); addBox.Text="" end)

refreshStockBtn.MouseButton1Click:Connect(function()
    local fruits = getFruitValues(); local tv = 0; for _, f in ipairs(fruits) do tv=tv+f.value end
    fruitStatusText.Text = "📦 "..#fruits.." buah | Total: "..formatValue(tv)
end)

fruitSendBtn.MouseButton1Click:Connect(function()
    local tv = tonumber(valueBox.Text); local tol = tonumber(toleranceInput.Text) or DEFAULT_TOLERANCE
    if #usernameList==0 then fruitStatusText.Text="❌ Tambah username!"; return end
    if not tv then fruitStatusText.Text="❌ ISI NILAI!"; return end
    if not selectedUserIndex then fruitStatusText.Text="❌ Pilih username!"; fruitStatusText.TextColor3=C.red; return end
    local un = usernameList[selectedUserIndex].username
    fruitStatusText.Text="📤 "..un.."..."; fruitStatusText.TextColor3=Color3.fromRGB(0,200,255)
    local ok, msg = sendToUser(un, tv, tol)
    if ok then usernameList[selectedUserIndex].status="sent"; fruitStatusText.Text="✅ "..msg; fruitStatusText.TextColor3=C.green
    else usernameList[selectedUserIndex].status="failed"; fruitStatusText.Text="❌ "..msg; fruitStatusText.TextColor3=C.red end
    config.mailFruitUsers=usernameList; saveConfig(); refreshUsernameList()
end)

resumeBtn.MouseButton1Click:Connect(function()
    if not lastFailedIndex then return end
    local tv = tonumber(valueBox.Text); local tol = tonumber(toleranceInput.Text) or DEFAULT_TOLERANCE
    if not tv then fruitStatusText.Text="❌ ISI NILAI!"; return end
    isFruitAutoRunning=true; resumeBtn.Visible=false
    fruitAutoBtn.Text="⏸ STOP AUTO"; fruitAutoBtn.BackgroundColor3=Color3.fromRGB(180,50,50)
    task.spawn(function()
        for i=lastFailedIndex, #usernameList do
            if not isFruitAutoRunning then break end
            if usernameList[i].status=="skipped" then 
                fruitStatusText.Text="⏭ Skip #"..i..": "..usernameList[i].username
                fruitStatusText.TextColor3 = C.yellow
            elseif usernameList[i].status=="sent" then
                fruitStatusText.Text="✅ #"..i.." sudah terkirim"
                fruitStatusText.TextColor3 = C.green
            elseif usernameList[i].status=="waiting" or usernameList[i].status=="failed" then
                local un=usernameList[i].username; fruitStatusText.Text="📤 "..un.."..."; fruitStatusText.TextColor3=Color3.fromRGB(0,200,255)
                local ok, msg = sendToUser(un, tv, tol)
                if ok then usernameList[i].status="sent"; fruitStatusText.Text="✅ "..msg; fruitStatusText.TextColor3=C.green; refreshUsernameList()
                    if i<#usernameList then for t=BATCH_DELAY,1,-1 do if not isFruitAutoRunning then break end; fruitStatusText.Text="⏳ Jeda "..t.."s..."; task.wait(1) end end
                else usernameList[i].status="failed"; fruitStatusText.Text="❌ "..un..": "..msg; fruitStatusText.TextColor3=C.red; refreshUsernameList()
                    lastFailedIndex=i; resumeBtn.Visible=true; isFruitAutoRunning=false; fruitAutoBtn.Text="🔄 MULAI AUTO (MULTI)"; fruitAutoBtn.BackgroundColor3=Color3.fromRGB(120,60,160); return
                end
            end; refreshUsernameList()
        end
        isFruitAutoRunning=false; fruitAutoBtn.Text="🔄 MULAI AUTO (MULTI)"; fruitAutoBtn.BackgroundColor3=Color3.fromRGB(120,60,160)
        fruitStatusText.Text="✅ Auto selesai! Status di-reset."; fruitStatusText.TextColor3=C.green; resumeBtn.Visible=false
        task.delay(2, resetAllStatus)
    end)
end)

fruitAutoBtn.MouseButton1Click:Connect(function()
    if isFruitAutoRunning then isFruitAutoRunning=false; fruitAutoBtn.Text="🔄 MULAI AUTO (MULTI)"; fruitAutoBtn.BackgroundColor3=Color3.fromRGB(120,60,160); fruitStatusText.Text="⏸ Dihentikan"; fruitStatusText.TextColor3=C.yellow; return end
    if #usernameList==0 then fruitStatusText.Text="❌ Tambah username!"; return end
    local tv = tonumber(valueBox.Text); local tol = tonumber(toleranceInput.Text) or DEFAULT_TOLERANCE
    if not tv then fruitStatusText.Text="❌ ISI NILAI!"; return end
    for _, data in ipairs(usernameList) do if data.status~="skipped" then data.status="waiting" end end; refreshUsernameList()
    isFruitAutoRunning=true; fruitAutoBtn.Text="⏸ STOP AUTO"; fruitAutoBtn.BackgroundColor3=Color3.fromRGB(180,50,50); resumeBtn.Visible=false; lastFailedIndex=nil
    task.spawn(function()
        for i=1, #usernameList do
            if not isFruitAutoRunning then break end
            if usernameList[i].status=="skipped" then fruitStatusText.Text="⏭ Skip #"..i..": "..usernameList[i].username
            elseif usernameList[i].status=="waiting" then
                local un=usernameList[i].username; fruitStatusText.Text="📤 #"..i.."/"..#usernameList..": "..un; fruitStatusText.TextColor3=Color3.fromRGB(0,200,255)
                local ok, msg = sendToUser(un, tv, tol)
                if ok then usernameList[i].status="sent"; fruitStatusText.Text="✅ "..msg; fruitStatusText.TextColor3=C.green; refreshUsernameList()
                    if i<#usernameList then for t=BATCH_DELAY,1,-1 do if not isFruitAutoRunning then break end; fruitStatusText.Text="⏳ Jeda "..t.."s..."; task.wait(1) end end
                else usernameList[i].status="failed"; fruitStatusText.Text="❌ "..un..": "..msg; fruitStatusText.TextColor3=C.red; refreshUsernameList()
                    lastFailedIndex=i; resumeBtn.Visible=true; isFruitAutoRunning=false; fruitAutoBtn.Text="🔄 MULAI AUTO (MULTI)"; fruitAutoBtn.BackgroundColor3=Color3.fromRGB(120,60,160); return
                end
            end; refreshUsernameList()
        end
        isFruitAutoRunning=false; fruitAutoBtn.Text="🔄 MULAI AUTO (MULTI)"; fruitAutoBtn.BackgroundColor3=Color3.fromRGB(120,60,160)
        fruitStatusText.Text="✅ Auto selesai! Status di-reset."; fruitStatusText.TextColor3=C.green; resumeBtn.Visible=false
        task.delay(2, resetAllStatus)
    end)
end)

refreshUsernameList()
print("[AoneHub] ✅ Tab Mail Fruit Ready (Absolute Position)")

-- Auto-refresh stock
task.spawn(function()
    while parentFruit.Parent do
        task.wait(30)
        if fruitStockLabel and fruitStockLabel.Parent then  -- ⬅️ Cek nil
            local fruits = getFruitValues()
            local totalValue = 0
            for _, f in ipairs(fruits) do totalValue = totalValue + f.value end
            fruitStockLabel.Text = "📦 " .. #fruits .. " buah | Total: " .. formatValue(totalValue)
        end
    end
end)

print("[AoneHub] ✅ Tab Mail Fruit Ready (with Real Values)")

    -- ==================================================================
    -- AUTO-START
    -- ==================================================================
    if config.isRunningBuy then task.delay(2,function() if getRemote() then isRunningBuy=true; cacheBuyShop(); pcall(scanAndBuy); task.spawn(buyMainLoop); updateBuyUI() end end) end
    if config.isRunningSell then task.delay(3,function() if net and net.NPCS and net.NPCS.SellAll then isRunningSell=true; task.spawn(sellLoop); updateSellUI() end end) end
    if config.isAutoMailRunning then task.delay(4,function() if config.mailTargetUsername ~= "" then isAutoRunning=true; userBox.Text=config.mailTargetUsername; updatePlayerInfo(config.mailTargetUsername); autoBtn.Text = "⏸ STOP AUTO MAIL"; autoBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50); autoStatusLabel.Text = "🔄 Auto Mail: ON"; autoStatusLabel.TextColor3 = C.green end end) end
    if config.isAutoClaimRunning then task.delay(5,function() isClaimRunning = true; claimBtn.Text = "⏸ STOP AUTO CLAIM"; claimBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 120); claimStatusLabel.Text = "📬 Auto Claim: ON"; claimStatusLabel.TextColor3 = Color3.fromRGB(200, 100, 255) end) end
    -- Auto-start Value Display
if config.extraToggle1 then
    task.delay(6, function()
        print("[AoneHub] ✅ Value Display auto-started!")
    end)
end

-- Auto-start Anti-AFK (default ON)
if config.extraToggle2 then
    task.delay(1, function()
        print("[AoneHub] ✅ Anti-AFK auto-started!")
    end)
    end
    saveConfig()
    print("[AoneHub] ✅ Complete! All 5 tabs ready. Config: " .. SAVE_FILE)
end

local s, e = pcall(main)
if not s then warn("[AoneHub] ERROR: " .. tostring(e)) end
