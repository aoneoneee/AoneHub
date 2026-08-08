-- ──────────────────────────────────────────────────────────────────────
-- AONEHUB - ACCORDION FIX (FULL SCRIPT)
-- ──────────────────────────────────────────────────────────────────────

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ==================================================================
-- CONFIG
-- ==================================================================
local SAVE_FILE = "AoneHub_Config.json"
local config = {
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

-- ==================================================================
-- GET OPCODES
-- ==================================================================
local function getOpcodes()
    local s, Networking = pcall(require, ReplicatedStorage.SharedModules.Networking)
    if not s then return 133, 137, 135 end
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
    accordionSeed = Color3.fromRGB(35, 42, 35), accordionGear = Color3.fromRGB(42, 35, 35),
    accordionProp = Color3.fromRGB(40, 35, 45), accordionBody = Color3.fromRGB(30, 30, 36),
    itemRow = Color3.fromRGB(38, 38, 45), itemRowSelected = Color3.fromRGB(35, 55, 40),
    searchBg = Color3.fromRGB(32, 32, 38),
}

-- ==================================================================
-- GET ITEMS
-- ==================================================================
local function safeRequire(path)
    local s, r = pcall(function() return require(path) end)
    if s then return r end; return nil
end

local ALL_SEEDS, ALL_GEARS, ALL_PROPS = {}, {}, {}

pcall(function()
    local seedData = safeRequire(ReplicatedStorage.SharedModules.SeedData)
    if seedData then for _, seed in ipairs(seedData) do
        if seed and seed.RestockShop and seed.SeedName then table.insert(ALL_SEEDS, seed.SeedName) end
    end end
    if #ALL_SEEDS == 0 then ALL_SEEDS = {"Hypno Bloom", "Dragon's Breath", "Sun Bloom", "Star Fruit"} end
    table.sort(ALL_SEEDS)
end)

pcall(function()
    local gearData = safeRequire(ReplicatedStorage.SharedModules.GearShopData)
    if gearData and gearData.Data then for _, gear in ipairs(gearData.Data) do
        if gear and not gear.RobuxOnly and not gear.HideFromShop and gear.ItemName then table.insert(ALL_GEARS, gear.ItemName) end
    end end
    table.sort(ALL_GEARS)
end)

pcall(function()
    local crateData = safeRequire(ReplicatedStorage.SharedModules.CrateData)
    if crateData and crateData.GetAllCrates then for _, crate in ipairs(crateData.GetAllCrates()) do
        if crate and crate.RestockChance and crate.Name then table.insert(ALL_PROPS, crate.Name) end
    end end
    table.sort(ALL_PROPS)
end)

local function mergeItems(saved, current)
    local merged = {}
    if type(saved) == "table" then for k, v in pairs(saved) do merged[k] = v end end
    for _, name in ipairs(current) do if merged[name] == nil then merged[name] = false end end
    return merged
end

config.selectedSeeds = mergeItems(config.selectedSeeds, ALL_SEEDS)
config.selectedGears = mergeItems(config.selectedGears, ALL_GEARS)
config.selectedProps = mergeItems(config.selectedProps, ALL_PROPS)

-- ==================================================================
-- GUI SKELETON
-- ==================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AoneHub"; screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false; screenGui.Destroying:Connect(saveConfig)

local minimizedCircle = Instance.new("TextButton")
minimizedCircle.Size = UDim2.new(0, 50, 0, 50); minimizedCircle.Position = UDim2.new(0.5, -25, 0.5, -25)
minimizedCircle.Text = "AH"; minimizedCircle.TextColor3 = C.text
minimizedCircle.Font = Enum.Font.GothamBlack; minimizedCircle.TextSize = 20
minimizedCircle.BackgroundColor3 = C.accent; minimizedCircle.BorderSizePixel = 0
minimizedCircle.Visible = false; minimizedCircle.AutoButtonColor = false
minimizedCircle.Draggable = true; minimizedCircle.Parent = screenGui
Instance.new("UICorner", minimizedCircle).CornerRadius = UDim.new(1, 0)

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 700, 0, 460); mainFrame.Position = UDim2.new(0.5, -350, 0.5, -230)
mainFrame.BackgroundColor3 = C.bg; mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true; mainFrame.Active = true; mainFrame.Draggable = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 38); titleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
titleBar.BorderSizePixel = 0; titleBar.Parent = mainFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local titleFill = Instance.new("Frame")
titleFill.Size = UDim2.new(1, 0, 0.5, 0); titleFill.Position = UDim2.new(0, 0, 0.5, 0)
titleFill.BackgroundColor3 = Color3.fromRGB(18, 18, 24); titleFill.BorderSizePixel = 0; titleFill.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0.6, 0, 1, 0); titleLabel.Position = UDim2.new(0, 16, 0, 0)
titleLabel.Text = "AoneHub"; titleLabel.TextColor3 = C.text
titleLabel.Font = Enum.Font.GothamBold; titleLabel.TextSize = 14
titleLabel.TextXAlignment = Enum.TextXAlignment.Left; titleLabel.BackgroundTransparency = 1; titleLabel.Parent = titleBar

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 28, 0, 28); minimizeBtn.Position = UDim2.new(1, -65, 0, 5)
minimizeBtn.Text = "–"; minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
minimizeBtn.Font = Enum.Font.GothamBold; minimizeBtn.TextSize = 20
minimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55); minimizeBtn.BorderSizePixel = 0
minimizeBtn.AutoButtonColor = false; minimizeBtn.Parent = titleBar
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 5)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28); closeBtn.Position = UDim2.new(1, -32, 0, 5)
closeBtn.Text = "✕"; closeBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 15
closeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55); closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = false; closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)

minimizeBtn.MouseButton1Click:Connect(function()
    minimizedCircle.Position = UDim2.new(0, mainFrame.AbsolutePosition.X, 0, mainFrame.AbsolutePosition.Y)
    mainFrame.Visible = false; minimizedCircle.Visible = true
end)
minimizedCircle.MouseButton1Click:Connect(function()
    mainFrame.Position = UDim2.new(0, minimizedCircle.AbsolutePosition.X, 0, minimizedCircle.AbsolutePosition.Y)
    minimizedCircle.Visible = false; mainFrame.Visible = true
end)
closeBtn.MouseButton1Click:Connect(function() saveConfig(); screenGui:Destroy() end)

-- Sidebar
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0.21, 0, 1, -38); sidebar.Position = UDim2.new(0, 0, 0, 38)
sidebar.BackgroundColor3 = C.sidebar; sidebar.BorderSizePixel = 0; sidebar.Parent = mainFrame
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 10)

local sidebarFill = Instance.new("Frame")
sidebarFill.Size = UDim2.new(1, 0, 0.3, 0); sidebarFill.Position = UDim2.new(0, 0, 0.85, 0)
sidebarFill.BackgroundColor3 = C.sidebar; sidebarFill.BorderSizePixel = 0; sidebarFill.Parent = sidebar

local menuLabel = Instance.new("TextLabel")
menuLabel.Size = UDim2.new(1, 0, 0, 22); menuLabel.Position = UDim2.new(0, 0, 0, 10)
menuLabel.Text = "MENU"; menuLabel.TextColor3 = Color3.fromRGB(120, 120, 130)
menuLabel.Font = Enum.Font.GothamBold; menuLabel.TextSize = 11
menuLabel.TextXAlignment = Enum.TextXAlignment.Center; menuLabel.BackgroundTransparency = 1; menuLabel.Parent = sidebar

local sep = Instance.new("Frame")
sep.Size = UDim2.new(0.7, 0, 0, 1); sep.Position = UDim2.new(0.15, 0, 0, 36)
sep.BackgroundColor3 = Color3.fromRGB(60, 60, 70); sep.BorderSizePixel = 0; sep.Parent = sidebar

-- Tab Buttons
local tabs = {{name="AutoBuy", label="🛒  Auto Buy"}, {name="AutoMail", label="📧  Auto Mail"}, {name="Ekstra", label="⚙️  Ekstra"}}
local tabBtns = {}; local activeTab = nil

for i, tab in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.82, 0, 0, 38); btn.Position = UDim2.new(0.09, 0, 0, 50 + (i-1)*46)
    btn.Text = tab.label; btn.TextColor3 = C.textDim; btn.Font = Enum.Font.GothamSemibold; btn.TextSize = 13
    btn.TextXAlignment = Enum.TextXAlignment.Left; btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    btn.BorderSizePixel = 0; btn.AutoButtonColor = false; btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    btn.MouseEnter:Connect(function() if activeTab ~= tab.name then btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55) end end)
    btn.MouseLeave:Connect(function() if activeTab ~= tab.name then btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40) end end)
    tabBtns[tab.name] = btn
end

-- Content area
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(0.79, -10, 1, -48); contentArea.Position = UDim2.new(0.21, 5, 0, 43)
contentArea.BackgroundTransparency = 1; contentArea.ClipsDescendants = true; contentArea.Parent = mainFrame

local defaultView = Instance.new("Frame")
defaultView.Size = UDim2.new(1, 0, 1, 0); defaultView.BackgroundTransparency = 1; defaultView.Parent = contentArea

local logoLabel = Instance.new("TextLabel")
logoLabel.Size = UDim2.new(1, 0, 0, 50); logoLabel.Position = UDim2.new(0, 0, 0.35, -25)
logoLabel.Text = "AoneHub"; logoLabel.TextColor3 = C.accent
logoLabel.Font = Enum.Font.GothamBlack; logoLabel.TextSize = 36; logoLabel.BackgroundTransparency = 1; logoLabel.Parent = defaultView

local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(1, 0, 0, 20); subLabel.Position = UDim2.new(0, 0, 0.5, 0)
subLabel.Text = "Pilih menu di samping"; subLabel.TextColor3 = C.textDim
subLabel.Font = Enum.Font.Gotham; subLabel.TextSize = 13; subLabel.BackgroundTransparency = 1; subLabel.Parent = defaultView

local tabFrames = {}
for _, tab in ipairs(tabs) do
    local f = Instance.new("Frame"); f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1; f.Visible = false; f.Parent = contentArea; tabFrames[tab.name] = f
end

local function switchTab(tabName)
    defaultView.Visible = false
    for _, f in pairs(tabFrames) do f.Visible = false end
    for _, btn in pairs(tabBtns) do btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40); btn.TextColor3 = C.textDim end
    if tabFrames[tabName] then tabFrames[tabName].Visible = true; tabBtns[tabName].BackgroundColor3 = C.accent; tabBtns[tabName].TextColor3 = C.text; activeTab = tabName end
end

for _, tab in ipairs(tabs) do tabBtns[tab.name].MouseButton1Click:Connect(function() switchTab(tab.name) end) end

for _, tab in ipairs({"AutoMail", "Ekstra"}) do
    local f = tabFrames[tab]
    local ic = Instance.new("TextLabel"); ic.Size = UDim2.new(1, 0, 0, 50); ic.Position = UDim2.new(0, 0, 0.35, -25)
    ic.Text = tab=="AutoMail" and "📧" or "⚙️"; ic.Font = Enum.Font.Gotham; ic.TextSize = 45; ic.BackgroundTransparency = 1; ic.Parent = f
    local tt = Instance.new("TextLabel"); tt.Size = UDim2.new(1, 0, 0, 28); tt.Position = UDim2.new(0, 0, 0.45, 0)
    tt.Text = tab=="AutoMail" and "Auto Mail" or "Ekstra"; tt.TextColor3 = C.text; tt.Font = Enum.Font.GothamBold; tt.TextSize = 18; tt.BackgroundTransparency = 1; tt.Parent = f
    local st = Instance.new("TextLabel"); st.Size = UDim2.new(1, 0, 0, 18); st.Position = UDim2.new(0, 0, 0.52, 0)
    st.Text = "Coming soon..."; st.TextColor3 = C.textDim; st.Font = Enum.Font.Gotham; st.TextSize = 12; st.BackgroundTransparency = 1; st.Parent = f
end

print("[AoneHub] ✅ GUI Ready")

-- ==================================================================
-- AUTO BUY ENGINE
-- ==================================================================
local parent = tabFrames["AutoBuy"]

local buyStats = {total = 0, success = 0, failed = 0}
local isRunning, isBuying = false, false
local itemStatusSeed, itemStatusGear, itemStatusProp = {}, {}, {}
local nextScanTime, scanCount = 0, 0
local shopElementsSeed, shopElementsGear, shopElementsProp = {}, {}, {}

local packetRemote = nil
local function getRemote()
    if packetRemote then return true end
    local s, r = pcall(function() return ReplicatedStorage:WaitForChild("SharedModules",5):WaitForChild("Packet",5):WaitForChild("RemoteEvent",5) end)
    if s and r then packetRemote = r; return true end; return false
end

local function buyItem(itemName, opcode)
    if not getRemote() then return false end
    local s = pcall(function() packetRemote:FireServer(buffer.fromstring(string.char(opcode,0,#itemName)..itemName)) end)
    buyStats.total = buyStats.total + 1
    if s then buyStats.success = buyStats.success + 1; return true
    else buyStats.failed = buyStats.failed + 1; return false end
end

local function cacheShop()
    pcall(function()
        local ss = playerGui:FindFirstChild("SeedShop")
        if ss then local f = ss:FindFirstChild("Frame"); if f then local ns = f:FindFirstChild("NormalShop")
            if ns then for _, ic in ipairs(ns:GetChildren()) do if config.selectedSeeds[ic.Name] then
                local mf = ic:FindFirstChild("Main_Frame") or ic:FindFirstChild("MainFrame")
                if mf then local ct = mf:FindFirstChild("Cost_Text") or mf:FindFirstChild("CostText")
                    if ct then shopElementsSeed[ic.Name] = {container=ic, costText=ct} end
                end
            end end end
        end end
    end)
    pcall(function()
        local gs = playerGui:FindFirstChild("GearShop")
        if gs then local f = gs:FindFirstChild("Frame"); if f then local sf = f:FindFirstChild("ScrollingFrame")
            if sf then for _, ic in ipairs(sf:GetChildren()) do if config.selectedGears[ic.Name] then
                local ct = ic:FindFirstChild("Cost_Text") or ic:FindFirstChild("CostText")
                if ct then shopElementsGear[ic.Name] = {container=ic, costText=ct} end
            end end end
        end end
    end)
    pcall(function()
        local cs = playerGui:FindFirstChild("CrateShop")
        if cs then local f = cs:FindFirstChild("Frame"); if f then local sf = f:FindFirstChild("ScrollingFrame")
            if sf then for _, ic in ipairs(sf:GetChildren()) do if config.selectedProps[ic.Name] then
                local ct = ic:FindFirstChild("Cost_Text") or ic:FindFirstChild("CostText")
                if ct then shopElementsProp[ic.Name] = {container=ic, costText=ct} end
            end end end
        end end
    end)
end

local function isAvailable(itemName, elements)
    local el = elements[itemName]; if not el then return false end
    if not el.container.Visible then return false end
    local txt = ""; pcall(function() txt = el.costText.Text end)
    return not (txt:upper():find("NO STOCK") or txt == "")
end

local function buyAll()
    if isBuying then return end; isBuying = true
    while isRunning do local any = false
        for _, itemName in ipairs(ALL_SEEDS) do if not isRunning then break end
            if config.selectedSeeds[itemName] and isAvailable(itemName, shopElementsSeed) then
                if buyItem(itemName, OPCODE_SEED) then any=true; itemStatusSeed[itemName]="stock"; task.wait(0.3+math.random()*0.5)
                else itemStatusSeed[itemName]="nostock"; task.wait(0.2) end
            else itemStatusSeed[itemName]="nostock" end
        end
        for _, itemName in ipairs(ALL_GEARS) do if not isRunning then break end
            if config.selectedGears[itemName] and isAvailable(itemName, shopElementsGear) then
                if buyItem(itemName, OPCODE_GEAR) then any=true; itemStatusGear[itemName]="stock"; task.wait(0.3+math.random()*0.5)
                else itemStatusGear[itemName]="nostock"; task.wait(0.2) end
            else itemStatusGear[itemName]="nostock" end
        end
        for _, itemName in ipairs(ALL_PROPS) do if not isRunning then break end
            if config.selectedProps[itemName] and isAvailable(itemName, shopElementsProp) then
                if buyItem(itemName, OPCODE_PROP) then any=true; itemStatusProp[itemName]="stock"; task.wait(0.3+math.random()*0.5)
                else itemStatusProp[itemName]="nostock"; task.wait(0.2) end
            else itemStatusProp[itemName]="nostock" end
        end
        if not any then break end; task.wait(0.2)
    end; isBuying = false; updateUI()
end

local function scanAndBuy()
    scanCount = scanCount + 1; cacheShop(); local any = false
    for _, itemName in ipairs(ALL_SEEDS) do if config.selectedSeeds[itemName] then
        if isAvailable(itemName, shopElementsSeed) then any=true; itemStatusSeed[itemName]="stock" else itemStatusSeed[itemName]="nostock" end
    end end
    for _, itemName in ipairs(ALL_GEARS) do if config.selectedGears[itemName] then
        if isAvailable(itemName, shopElementsGear) then any=true; itemStatusGear[itemName]="stock" else itemStatusGear[itemName]="nostock" end
    end end
    for _, itemName in ipairs(ALL_PROPS) do if config.selectedProps[itemName] then
        if isAvailable(itemName, shopElementsProp) then any=true; itemStatusProp[itemName]="stock" else itemStatusProp[itemName]="nostock" end
    end end
    updateUI(); if any then buyAll() end
end

local function mainLoop()
    while isRunning do
        local now = os.time(); local jitter = 3 + math.random() * 2
        local nrm = math.ceil(math.floor(now/60)/5)*5; local mutr = nrm - math.floor(now/60)
        local sutr = (mutr*60) - (now%60) + jitter
        if sutr <= 0 then sutr = sutr + 300 end
        nextScanTime = os.time() + sutr; updateUI(); task.wait(sutr)
        if not isRunning then break end; pcall(scanAndBuy); task.wait(1)
    end
end

local function startMonitoring()
    if isRunning then return end; if not getRemote() then return end
    isRunning = true; cacheShop(); pcall(scanAndBuy); task.spawn(mainLoop); updateUI()
end

local function stopMonitoring()
    isRunning = false; itemStatusSeed={}; itemStatusGear={}; itemStatusProp={}; updateUI()
end

-- ==================================================================
-- BUILD AUTO BUY UI (WITH FIXED ACCORDION)
-- ==================================================================
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, 0, 1, 0); scroll.CanvasSize = UDim2.new(0, 0, 0, 1500)
scroll.ScrollBarThickness = 3; scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0; scroll.Parent = parent

-- UIListLayout untuk auto-posisi
local mainLayout = Instance.new("UIListLayout")
mainLayout.Padding = UDim.new(0, 8)
mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
mainLayout.Parent = scroll

-- Header
local hdr = Instance.new("TextLabel")
hdr.Size = UDim2.new(1, -20, 0, 24); hdr.LayoutOrder = 1
hdr.Text = "🛒  Auto Buy (Seed + Gear + Prop)"; hdr.TextColor3 = C.text
hdr.Font = Enum.Font.GothamBold; hdr.TextSize = 14
hdr.TextXAlignment = Enum.TextXAlignment.Left; hdr.BackgroundTransparency = 1; hdr.Parent = scroll

-- Status
local statusText = Instance.new("TextLabel")
statusText.Size = UDim2.new(1, -20, 0, 18); statusText.LayoutOrder = 2
statusText.Text = "⏹️  OFF"; statusText.TextColor3 = C.red
statusText.Font = Enum.Font.GothamSemibold; statusText.TextSize = 12
statusText.TextXAlignment = Enum.TextXAlignment.Left; statusText.BackgroundTransparency = 1; statusText.Parent = scroll

-- Timer + Stats
local timerText = Instance.new("TextLabel")
timerText.Size = UDim2.new(1, -20, 0, 18); timerText.LayoutOrder = 3
timerText.Text = "Next scan: --:--:--"; timerText.TextColor3 = Color3.fromRGB(255,200,50)
timerText.Font = Enum.Font.GothamBold; timerText.TextSize = 12
timerText.TextXAlignment = Enum.TextXAlignment.Left; timerText.BackgroundTransparency = 1; timerText.Parent = scroll

local statsText = Instance.new("TextLabel")
statsText.Size = UDim2.new(1, -20, 0, 14); statsText.LayoutOrder = 4
statsText.Text = "✅ 0  |  ❌ 0  |  🔄 0"; statsText.TextColor3 = C.textDim
statsText.Font = Enum.Font.Gotham; statsText.TextSize = 10
statsText.TextXAlignment = Enum.TextXAlignment.Left; statsText.BackgroundTransparency = 1; statsText.Parent = scroll

-- ==================================================================
-- FIXED ACCORDION BUILDER
-- ==================================================================
local function createAccordion(title, items, selectedItems, itemStatus, headerColor, openKey, searchKey, layoutOrder)
    local accordionOpen = config[openKey] or false
    
    -- Container
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -20, 0, accordionOpen and 230 or 28)
    container.BackgroundTransparency = 1
    container.LayoutOrder = layoutOrder
    container.Parent = scroll
    
    -- Header
    local header = Instance.new("TextButton")
    header.Size = UDim2.new(1, 0, 0, 28)
    header.BackgroundColor3 = headerColor; header.BorderSizePixel = 0
    header.Text = ""; header.AutoButtonColor = false; header.Parent = container
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 5)
    
    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 18, 1, 0); arrow.Position = UDim2.new(0, 5, 0, 0)
    arrow.Text = accordionOpen and "▼" or "▶"; arrow.TextColor3 = C.textDim
    arrow.Font = Enum.Font.GothamBold; arrow.TextSize = 9; arrow.BackgroundTransparency = 1; arrow.Parent = header
    
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -55, 1, 0); titleLbl.Position = UDim2.new(0, 24, 0, 0)
    titleLbl.Text = title.." ("..#items..")"; titleLbl.TextColor3 = C.text
    titleLbl.Font = Enum.Font.GothamSemibold; titleLbl.TextSize = 11
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.BackgroundTransparency = 1; titleLbl.Parent = header
    
    local selectAllBtn = Instance.new("TextButton")
    selectAllBtn.Size = UDim2.new(0, 35, 0, 16); selectAllBtn.Position = UDim2.new(1, -40, 0.5, -8)
    selectAllBtn.Text = "All"; selectAllBtn.TextColor3 = C.text
    selectAllBtn.Font = Enum.Font.Gotham; selectAllBtn.TextSize = 8
    selectAllBtn.BackgroundColor3 = C.accent; selectAllBtn.BorderSizePixel = 0
    selectAllBtn.AutoButtonColor = false; selectAllBtn.Parent = header
    Instance.new("UICorner", selectAllBtn).CornerRadius = UDim.new(0, 3)
    
    -- Body
    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, 0, 0, 200)
    body.Position = UDim2.new(0, 0, 0, 30)
    body.BackgroundColor3 = C.accordionBody; body.BorderSizePixel = 0
    body.Visible = accordionOpen; body.Parent = container
    Instance.new("UICorner", body).CornerRadius = UDim.new(0, 5)
    
    -- Search
    local searchFrame = Instance.new("Frame")
    searchFrame.Size = UDim2.new(1, -8, 0, 24); searchFrame.Position = UDim2.new(0, 4, 0, 4)
    searchFrame.BackgroundColor3 = C.searchBg; searchFrame.BorderSizePixel = 0; searchFrame.Parent = body
    Instance.new("UICorner", searchFrame).CornerRadius = UDim.new(0, 4)
    
    local searchIcon = Instance.new("TextLabel")
    searchIcon.Size = UDim2.new(0, 16, 1, 0); searchIcon.Position = UDim2.new(0, 3, 0, 0)
    searchIcon.Text = "🔍"; searchIcon.TextSize = 8; searchIcon.BackgroundTransparency = 1; searchIcon.Parent = searchFrame
    
    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -20, 1, 0); searchBox.Position = UDim2.new(0, 20, 0, 0)
    searchBox.PlaceholderText = "Cari..."; searchBox.PlaceholderColor3 = Color3.fromRGB(100,100,110)
    searchBox.Text = config[searchKey] or ""; searchBox.TextColor3 = C.text
    searchBox.Font = Enum.Font.Gotham; searchBox.TextSize = 10
    searchBox.BackgroundTransparency = 1; searchBox.BorderSizePixel = 0; searchBox.Parent = searchFrame
    
    -- Item list
    local itemList = Instance.new("ScrollingFrame")
    itemList.Size = UDim2.new(1, -8, 1, -32); itemList.Position = UDim2.new(0, 4, 0, 30)
    itemList.BackgroundTransparency = 1; itemList.BorderSizePixel = 0
    itemList.ScrollBarThickness = 3; itemList.Parent = body
    
    local itemRows = {}; local selectAllState = false
    
    local function rebuildList()
        local query = searchBox.Text:lower(); config[searchKey] = query; saveConfig()
        for _, row in pairs(itemRows) do row.frame:Destroy() end; itemRows = {}
        
        -- Gabung available + saved
        local allDisplay, seen = {}, {}
        for _, name in ipairs(items) do if not seen[name] then table.insert(allDisplay, name); seen[name] = true end end
        for name in pairs(selectedItems) do if not seen[name] then table.insert(allDisplay, name); seen[name] = true end end
        
        -- Filter
        local filtered = {}
        for _, name in ipairs(allDisplay) do
            if query == "" or name:lower():find(query) then table.insert(filtered, name) end
        end
        
        -- Sort
        table.sort(filtered, function(a, b)
            local aA = table.find(items, a) ~= nil
            local bA = table.find(items, b) ~= nil
            if aA and not bA then return true
            elseif not aA and bA then return false
            else return a < b end
        end)
        
        -- Set canvas size
        local rowHeight = 20
        itemList.CanvasSize = UDim2.new(0, 0, 0, #filtered * rowHeight + 4)
        titleLbl.Text = title.." ("..#filtered..")"
        
        -- Buat rows
        for i, itemName in ipairs(filtered) do
            local isAvailable = table.find(items, itemName) ~= nil
            local isSelected = selectedItems[itemName] or false
            
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -4, 0, rowHeight - 2)
            row.Position = UDim2.new(0, 2, 0, (i-1) * rowHeight + 1)
            row.BackgroundColor3 = isSelected and C.itemRowSelected or C.itemRow
            row.BorderSizePixel = 0; row.Parent = itemList
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 2)
            
            local cb = Instance.new("TextButton")
            cb.Size = UDim2.new(0, 14, 0, 14); cb.Position = UDim2.new(0, 3, 0.5, -7)
            cb.Text = isSelected and "✅" or "⬜"; cb.TextSize = 9
            cb.BackgroundTransparency = 1; cb.BorderSizePixel = 0
            cb.AutoButtonColor = false; cb.Parent = row
            
            local icon = Instance.new("TextLabel")
            icon.Size = UDim2.new(0, 14, 1, 0); icon.Position = UDim2.new(0, 18, 0, 0)
            icon.Text = isAvailable and "🟢" or "🔒"; icon.TextSize = 7
            icon.BackgroundTransparency = 1; icon.Parent = row
            
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -36, 1, 0); lbl.Position = UDim2.new(0, 34, 0, 0)
            lbl.Text = isAvailable and itemName or itemName.." (off)"
            lbl.TextColor3 = isAvailable and (isSelected and Color3.fromRGB(100,255,100) or C.textDim) or Color3.fromRGB(120,120,130)
            lbl.Font = Enum.Font.Gotham; lbl.TextSize = 9
            lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.BackgroundTransparency = 1; lbl.Parent = row
            
            -- Stock status
            local st = itemStatus[itemName]
            if isAvailable and st == "stock" then lbl.TextColor3 = Color3.fromRGB(100,255,100)
            elseif isAvailable and st == "nostock" then lbl.TextColor3 = Color3.fromRGB(255,100,100) end
            
            local function toggleItem()
                if not isAvailable then return end
                selectedItems[itemName] = not (selectedItems[itemName] or false)
                saveConfig(); rebuildList()
            end
            
            cb.MouseButton1Click:Connect(toggleItem)
            row.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then toggleItem() end
            end)
            
            itemRows[itemName] = {frame = row, lbl = lbl}
        end
        
        -- Update body & container size
        local itemH = math.min(#filtered * rowHeight + 34, 180)
        body.Size = UDim2.new(1, 0, 0, itemH)
        if accordionOpen then
            container.Size = UDim2.new(1, -20, 0, itemH + 32)
        end
    end
    
    searchBox:GetPropertyChangedSignal("Text"):Connect(rebuildList)
    
    -- Select All
    selectAllBtn.MouseButton1Click:Connect(function()
        selectAllState = not selectAllState
        selectAllBtn.Text = selectAllState and "None" or "All"
        selectAllBtn.BackgroundColor3 = selectAllState and C.red or C.accent
        for _, name in ipairs(items) do selectedItems[name] = not selectAllState end
        saveConfig(); rebuildList()
    end)
    
    -- Toggle accordion
    header.MouseButton1Click:Connect(function()
        accordionOpen = not accordionOpen
        body.Visible = accordionOpen
        arrow.Text = accordionOpen and "▼" or "▶"
        config[openKey] = accordionOpen
        saveConfig()
        
        if accordionOpen then
            container.Size = UDim2.new(1, -20, 0, body.Size.Y.Offset + 32)
        else
            container.Size = UDim2.new(1, -20, 0, 28)
        end
    end)
    
    rebuildList()
    return container
end

-- Create accordions
createAccordion("🌱 Seeds", ALL_SEEDS, config.selectedSeeds, itemStatusSeed, C.accordionSeed, "accordionSeedOpen", "searchSeed", 10)
createAccordion("⚙️ Gears", ALL_GEARS, config.selectedGears, itemStatusGear, C.accordionGear, "accordionGearOpen", "searchGear", 20)
createAccordion("📦 Props", ALL_PROPS, config.selectedProps, itemStatusProp, C.accordionProp, "accordionPropOpen", "searchProp", 30)

-- Toggle button
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(1, -20, 0, 38); toggleBtn.LayoutOrder = 100
toggleBtn.Text = "▶  START"; toggleBtn.TextColor3 = C.text
toggleBtn.Font = Enum.Font.GothamBold; toggleBtn.TextSize = 13
toggleBtn.BackgroundColor3 = C.green; toggleBtn.BorderSizePixel = 0
toggleBtn.AutoButtonColor = false; toggleBtn.Parent = scroll
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)

toggleBtn.MouseEnter:Connect(function() toggleBtn.BackgroundColor3 = isRunning and Color3.fromRGB(220,70,70) or Color3.fromRGB(70,220,70) end)
toggleBtn.MouseLeave:Connect(function() toggleBtn.BackgroundColor3 = isRunning and C.red or C.green end)

function updateUI()
    if isRunning then
        statusText.Text = isBuying and "🛒  MEMBORONG..." or "⏰  MENUNGGU RESTOCK"
        statusText.TextColor3 = isBuying and Color3.fromRGB(255,150,50) or Color3.fromRGB(100,200,255)
        toggleBtn.Text = "⏹  STOP"; toggleBtn.BackgroundColor3 = C.red
        if not isBuying and nextScanTime > 0 then timerText.Text = os.date("%H:%M:%S", nextScanTime)
        elseif isBuying then timerText.Text = "MEMBORONG..." end
    else
        statusText.Text = "⏹️  OFF"; statusText.TextColor3 = C.red
        toggleBtn.Text = "▶  START"; toggleBtn.BackgroundColor3 = C.green
        timerText.Text = "Next scan: --:--:--"
    end
    statsText.Text = "✅ "..buyStats.success.."  |  ❌ "..buyStats.failed.."  |  🔄 "..scanCount
end

toggleBtn.MouseButton1Click:Connect(function() if isRunning then stopMonitoring() else startMonitoring() end; updateUI() end)
task.spawn(function() while parent.Parent do task.wait(0.5); pcall(updateUI) end end)
parent.Destroying:Connect(function() stopMonitoring(); saveConfig() end)

saveConfig()
print("[AoneHub] ✅ Full Script Ready!")
print("[AoneHub] 🚀 Complete!")
