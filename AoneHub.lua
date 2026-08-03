-- PROTECTED SCRIPT
local function main()
    print("[AoneHub] Starting...")
    
    -- Get services safely
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    
    local player = Players.LocalPlayer
    if not player then
        warn("[AoneHub] Player not found!")
        return
    end
    
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then
        warn("[AoneHub] PlayerGui not found!")
        return
    end
    
    print("[AoneHub] Services OK")
    
    -- Create ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AoneHub"
    screenGui.Parent = playerGui
    screenGui.ResetOnSpawn = false
    
    print("[AoneHub] ScreenGui created")
    
    -- Colors
    local C = {
        bg = Color3.fromRGB(22, 22, 28),
        sidebar = Color3.fromRGB(28, 28, 35),
        accent = Color3.fromRGB(90, 140, 255),
        text = Color3.fromRGB(255, 255, 255),
        textDim = Color3.fromRGB(170, 170, 180),
        green = Color3.fromRGB(50, 200, 50),
        red = Color3.fromRGB(200, 50, 50),
    }
    
    -- Minimized circle
    local minimizedCircle = Instance.new("TextButton")
    minimizedCircle.Size = UDim2.new(0, 50, 0, 50)
    minimizedCircle.Position = UDim2.new(0.5, -25, 0.5, -25)
    minimizedCircle.Text = "AH"
    minimizedCircle.TextColor3 = C.text
    minimizedCircle.Font = Enum.Font.GothamBlack
    minimizedCircle.TextSize = 20
    minimizedCircle.BackgroundColor3 = C.accent
    minimizedCircle.BorderSizePixel = 0
    minimizedCircle.Visible = false
    minimizedCircle.ZIndex = 10
    minimizedCircle.AutoButtonColor = false
    minimizedCircle.Parent = screenGui
    
    local circCorner = Instance.new("UICorner")
    circCorner.CornerRadius = UDim.new(1, 0)
    circCorner.Parent = minimizedCircle
    
    -- Main frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 600, 0, 380)
    mainFrame.Position = UDim2.new(0.5, -300, 0.5, -190)
    mainFrame.BackgroundColor3 = C.bg
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = mainFrame
    
    print("[AoneHub] Main frame created")
    
    -- Title bar
    local titleBar = Instance.new("TextButton")
    titleBar.Size = UDim2.new(1, 0, 0, 36)
    titleBar.Text = ""
    titleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    titleBar.BorderSizePixel = 0
    titleBar.AutoButtonColor = false
    titleBar.Parent = mainFrame
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.5, 0, 1, 0)
    titleLabel.Position = UDim2.new(0, 15, 0, 0)
    titleLabel.Text = "AoneHub"
    titleLabel.TextColor3 = C.text
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.BackgroundTransparency = 1
    titleLabel.Parent = titleBar
    
    -- Minimize button
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 26, 0, 26)
    minimizeBtn.Position = UDim2.new(1, -60, 0, 5)
    minimizeBtn.Text = "–"
    minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 18
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.AutoButtonColor = false
    minimizeBtn.Parent = titleBar
    
    Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 5)
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -32, 0, 5)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    closeBtn.BorderSizePixel = 0
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = titleBar
    
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)
    
    -- Sidebar
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0.26, 0, 1, -36)
    sidebar.Position = UDim2.new(0, 0, 0, 36)
    sidebar.BackgroundColor3 = C.sidebar
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainFrame
    
    local sidebarCorner = Instance.new("UICorner")
    sidebarCorner.CornerRadius = UDim.new(0, 10)
    sidebarCorner.Parent = sidebar
    
    print("[AoneHub] Layout created")
    
    -- Tab buttons
    local tabBtns = {}
    local tabs = {
        {name = "AutoBuy", label = "🛒  Auto Buy"},
        {name = "AutoMail", label = "📧  Auto Mail"},
        {name = "Ekstra", label = "⚙️  Ekstra"},
    }
    
    for i, tab in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Name = tab.name
        btn.Size = UDim2.new(0.82, 0, 0, 36)
        btn.Position = UDim2.new(0.09, 0, 0, 45 + (i-1)*42)
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
        
        tabBtns[tab.name] = btn
    end
    
    -- Content area
    local contentArea = Instance.new("Frame")
    contentArea.Size = UDim2.new(0.74, -10, 1, -46)
    contentArea.Position = UDim2.new(0.26, 5, 0, 41)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = mainFrame
    
    -- Default view
    local defaultView = Instance.new("Frame")
    defaultView.Size = UDim2.new(1, 0, 1, 0)
    defaultView.BackgroundTransparency = 1
    defaultView.Parent = contentArea
    
    local logoText = Instance.new("TextLabel")
    logoText.Size = UDim2.new(1, 0, 0, 45)
    logoText.Position = UDim2.new(0, 0, 0.38, -22)
    logoText.Text = "AoneHub"
    logoText.TextColor3 = C.accent
    logoText.Font = Enum.Font.GothamBlack
    logoText.TextSize = 34
    logoText.BackgroundTransparency = 1
    logoText.Parent = defaultView
    
    local subText = Instance.new("TextLabel")
    subText.Size = UDim2.new(1, 0, 0, 18)
    subText.Position = UDim2.new(0, 0, 0.48, 0)
    subText.Text = "Pilih menu di samping"
    subText.TextColor3 = C.textDim
    subText.Font = Enum.Font.Gotham
    subText.TextSize = 12
    subText.BackgroundTransparency = 1
    subText.Parent = defaultView
    
    -- Tab frames
    local tabFrames = {}
    local activeTab = nil
    
    for _, tab in ipairs(tabs) do
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 1, 0)
        f.BackgroundTransparency = 1
        f.Visible = false
        f.Parent = contentArea
        tabFrames[tab.name] = f
    end
    
    -- Switch tab
    local function switchTab(tabName)
        defaultView.Visible = false
        for _, f in pairs(tabFrames) do f.Visible = false end
        for _, btn in pairs(tabBtns) do
            btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
            btn.TextColor3 = C.textDim
        end
        if tabFrames[tabName] then
            tabFrames[tabName].Visible = true
            tabBtns[tabName].BackgroundColor3 = C.accent
            tabBtns[tabName].TextColor3 = C.text
            activeTab = tabName
        end
    end
    
    for _, tab in ipairs(tabs) do
        tabBtns[tab.name].MouseButton1Click:Connect(function()
            switchTab(tab.name)
        end)
    end
    
    -- Drag system
    local dragObj = nil
    local dragStart = nil
    local objStart = nil
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragObj = mainFrame
            dragStart = input.Position
            objStart = mainFrame.Position
        end
    end)
    
    minimizedCircle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragObj = minimizedCircle
            dragStart = input.Position
            objStart = minimizedCircle.Position
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
            dragObj = nil
        end
    end)
    
    -- Minimize/Restore
    minimizeBtn.MouseButton1Click:Connect(function()
        mainFrame.Visible = false
        minimizedCircle.Visible = true
    end)
    
    minimizedCircle.MouseButton1Click:Connect(function()
        minimizedCircle.Visible = false
        mainFrame.Visible = true
    end)
    
    -- Close
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    print("[AoneHub] ✅ GUI Loaded")
    
    -- Setup placeholder tabs
    for _, tab in ipairs({"AutoMail", "Ekstra"}) do
        local icon = tab == "AutoMail" and "📧" or "⚙️"
        local title = tab == "AutoMail" and "Auto Mail" or "Ekstra"
        local f = tabFrames[tab]
        
        local ic = Instance.new("TextLabel")
        ic.Size = UDim2.new(1, 0, 0, 50)
        ic.Position = UDim2.new(0, 0, 0.35, -25)
        ic.Text = icon
        ic.Font = Enum.Font.Gotham
        ic.TextSize = 45
        ic.BackgroundTransparency = 1
        ic.Parent = f
        
        local tt = Instance.new("TextLabel")
        tt.Size = UDim2.new(1, 0, 0, 28)
        tt.Position = UDim2.new(0, 0, 0.45, 0)
        tt.Text = title
        tt.TextColor3 = C.text
        tt.Font = Enum.Font.GothamBold
        tt.TextSize = 18
        tt.BackgroundTransparency = 1
        tt.Parent = f
        
        local st = Instance.new("TextLabel")
        st.Size = UDim2.new(1, 0, 0, 18)
        st.Position = UDim2.new(0, 0, 0.52, 0)
        st.Text = "Coming soon..."
        st.TextColor3 = C.textDim
        st.Font = Enum.Font.Gotham
        st.TextSize = 12
        st.BackgroundTransparency = 1
        st.Parent = f
    end
    
    print("[AoneHub] Placeholder tabs ready")
    print("[AoneHub] Tab AutoBuy masih kosong, siap diisi script auto-buy")
end

-- Jalankan dengan pcall
local success, err = pcall(main)
if not success then
    warn("[AoneHub] FATAL ERROR:", err)
end
