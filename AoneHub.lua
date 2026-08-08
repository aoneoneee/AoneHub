-- AONEHUB PART 1: GUI SKELETON
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SAVE_FILE = "AoneHub_Config.json"
local config = {
    opcodeSeed = 133, opcodeGear = 137, opcodeProp = 135,
    opcodeDetected = false, lastScannedOpcode = 158,
    selectedSeeds = {}, selectedGears = {}, selectedProps = {},
    accordionSeedOpen = true, accordionGearOpen = false, accordionPropOpen = false,
    searchSeed = "", searchGear = "", searchProp = "",
}

local function loadConfig()
    local s, d = pcall(readfile, SAVE_FILE)
    if s and d then
        local s2, loaded = pcall(HttpService.JSONDecode, HttpService, d)
        if s2 and loaded then for k, v in pairs(loaded) do config[k] = v end end
        return true
    end
    return false
end

local function saveConfig()
    local s, json = pcall(HttpService.JSONEncode, HttpService, config)
    if s then pcall(writefile, SAVE_FILE, json) end
end

loadConfig()

local C = {
    bg = Color3.fromRGB(22, 22, 28),
    sidebar = Color3.fromRGB(28, 28, 35),
    accent = Color3.fromRGB(90, 140, 255),
    text = Color3.fromRGB(255, 255, 255),
    textDim = Color3.fromRGB(170, 170, 180),
    green = Color3.fromRGB(50, 200, 50),
    red = Color3.fromRGB(200, 50, 50),
    input = Color3.fromRGB(38, 38, 48),
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AoneHub"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false
screenGui.Destroying:Connect(saveConfig)

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
minimizedCircle.AutoButtonColor = false
minimizedCircle.Draggable = true
minimizedCircle.Parent = screenGui
Instance.new("UICorner", minimizedCircle).CornerRadius = UDim.new(1, 0)

-- Main frame
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 700, 0, 460)
mainFrame.Position = UDim2.new(0.5, -350, 0.5, -230)
mainFrame.BackgroundColor3 = C.bg
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 38)
titleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

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

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 28, 0, 28)
minimizeBtn.Position = UDim2.new(1, -65, 0, 5)
minimizeBtn.Text = "–"
minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 20
minimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
minimizeBtn.BorderSizePixel = 0
minimizeBtn.AutoButtonColor = false
minimizeBtn.Parent = titleBar
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 5)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -32, 0, 5)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 15
closeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = false
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)

minimizeBtn.MouseButton1Click:Connect(function()
    minimizedCircle.Position = UDim2.new(0, mainFrame.AbsolutePosition.X, 0, mainFrame.AbsolutePosition.Y)
    mainFrame.Visible = false
    minimizedCircle.Visible = true
end)

minimizedCircle.MouseButton1Click:Connect(function()
    mainFrame.Position = UDim2.new(0, minimizedCircle.AbsolutePosition.X, 0, minimizedCircle.AbsolutePosition.Y)
    minimizedCircle.Visible = false
    mainFrame.Visible = true
end)

closeBtn.MouseButton1Click:Connect(function()
    saveConfig()
    screenGui:Destroy()
end)

-- Sidebar
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0.21, 0, 1, -38)
sidebar.Position = UDim2.new(0, 0, 0, 38)
sidebar.BackgroundColor3 = C.sidebar
sidebar.BorderSizePixel = 0
sidebar.Parent = mainFrame
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 10)

local sidebarFill = Instance.new("Frame")
sidebarFill.Size = UDim2.new(1, 0, 0.3, 0)
sidebarFill.Position = UDim2.new(0, 0, 0.85, 0)
sidebarFill.BackgroundColor3 = C.sidebar
sidebarFill.BorderSizePixel = 0
sidebarFill.Parent = sidebar

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

local sep = Instance.new("Frame")
sep.Size = UDim2.new(0.7, 0, 0, 1)
sep.Position = UDim2.new(0.15, 0, 0, 36)
sep.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
sep.BorderSizePixel = 0
sep.Parent = sidebar

-- Tab Buttons
local tabs = {
    {name = "AutoBuy", label = "🛒  Auto Buy"},
    {name = "AutoMail", label = "📧  Auto Mail"},
    {name = "Ekstra", label = "⚙️  Ekstra"},
}

local tabBtns = {}
local activeTab = nil

for i, tab in ipairs(tabs) do
    local btn = Instance.new("TextButton")
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
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    
    btn.MouseEnter:Connect(function()
        if activeTab ~= tab.name then btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55) end
    end)
    btn.MouseLeave:Connect(function()
        if activeTab ~= tab.name then btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40) end
    end)
    
    tabBtns[tab.name] = btn
end

-- Content area
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(0.79, -10, 1, -48)
contentArea.Position = UDim2.new(0.21, 5, 0, 43)
contentArea.BackgroundTransparency = 1
contentArea.ClipsDescendants = true
contentArea.Parent = mainFrame

-- Default view
local defaultView = Instance.new("Frame")
defaultView.Size = UDim2.new(1, 0, 1, 0)
defaultView.BackgroundTransparency = 1
defaultView.Parent = contentArea

local logoLabel = Instance.new("TextLabel")
logoLabel.Size = UDim2.new(1, 0, 0, 50)
logoLabel.Position = UDim2.new(0, 0, 0.35, -25)
logoLabel.Text = "AoneHub"
logoLabel.TextColor3 = C.accent
logoLabel.Font = Enum.Font.GothamBlack
logoLabel.TextSize = 36
logoLabel.BackgroundTransparency = 1
logoLabel.Parent = defaultView

local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(1, 0, 0, 20)
subLabel.Position = UDim2.new(0, 0, 0.5, 0)
subLabel.Text = "Pilih menu di samping"
subLabel.TextColor3 = C.textDim
subLabel.Font = Enum.Font.Gotham
subLabel.TextSize = 13
subLabel.BackgroundTransparency = 1
subLabel.Parent = defaultView

-- Tab frames
local tabFrames = {}
for _, tab in ipairs(tabs) do
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = false
    f.Parent = contentArea
    tabFrames[tab.name] = f
end

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

-- Placeholder tabs
for _, tab in ipairs({"AutoMail", "Ekstra"}) do
    local f = tabFrames[tab]
    local ic = Instance.new("TextLabel")
    ic.Size = UDim2.new(1, 0, 0, 50)
    ic.Position = UDim2.new(0, 0, 0.35, -25)
    ic.Text = tab == "AutoMail" and "📧" or "⚙️"
    ic.Font = Enum.Font.Gotham
    ic.TextSize = 45
    ic.BackgroundTransparency = 1
    ic.Parent = f
    
    local tt = Instance.new("TextLabel")
    tt.Size = UDim2.new(1, 0, 0, 28)
    tt.Position = UDim2.new(0, 0, 0.45, 0)
    tt.Text = tab == "AutoMail" and "Auto Mail" or "Ekstra"
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

-- Mark AutoBuy tab as ready to load
_G.AoneHub_TabFrame = tabFrames["AutoBuy"]
_G.AoneHub_Config = config
_G.AoneHub_SaveConfig = saveConfig
_G.AoneHub_Parent = tabFrames["AutoBuy"]

print("[AoneHub Part 1] ✅ GUI skeleton ready")
print("[AoneHub Part 1] Execute Part 2 now...")
