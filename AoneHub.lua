-- ──────────────────────────────────────────────────────────────────────
-- AONEHUB - FULL SCRIPT (TAB 2: AUTO SELL ADVANCED COMPLETE)
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
    selectedSellFruits = {},
    accordionSeedOpen = true, accordionGearOpen = false, accordionPropOpen = false,
    accordionSellOpen = true,
    searchSeed = "", searchGear = "", searchProp = "", searchSell = "",
    sellMultiplier = "x4",
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
-- GET OPCODES & NETWORKING
-- ==================================================================
local Networking = nil
local function getNetworking()
    if Networking then return Networking end
    local s, net = pcall(require, ReplicatedStorage.SharedModules.Networking)
    if s then Networking = net; return net end
    return nil
end

local function getOpcodes()
    local net = getNetworking()
    if not net then return 133, 137, 135, 190 end
    local opSeed, opGear, opProp, opSellAll = 133, 137, 135, 190
    pcall(function() if net.SeedShop and net.SeedShop.PurchaseSeed then opSeed = net.SeedShop.PurchaseSeed.Id end end)
    pcall(function() if net.GearShop and net.GearShop.PurchaseGear then opGear = net.GearShop.PurchaseGear.Id end end)
    pcall(function() if net.CrateShop and net.CrateShop.PurchaseCrate then opProp = net.CrateShop.PurchaseCrate.Id end end)
    -- SellAll opcode (dari script: \190)
    pcall(function() if net.NPCS and net.NPCS.SellAll then opSellAll = net.NPCS.SellAll.Id end end)
    return opSeed, opGear, opProp, opSellAll
end

local OPCODE_SEED, OPCODE_GEAR, OPCODE_PROP, OPCODE_SELLALL = getOpcodes()

-- ==================================================================
-- COLORS
-- ==================================================================
local C = {
    bg = Color3.fromRGB(22, 22, 28), sidebar = Color3.fromRGB(28, 28, 35),
    accent = Color3.fromRGB(90, 140, 255), text = Color3.fromRGB(255, 255, 255),
    textDim = Color3.fromRGB(170, 170, 180), green = Color3.fromRGB(50, 200, 50),
    red = Color3.fromRGB(200, 50, 50), orange = Color3.fromRGB(255, 150, 50),
    purple = Color3.fromRGB(180, 100, 255),
    accordionSeed = Color3.fromRGB(35, 42, 35), accordionGear = Color3.fromRGB(42, 35, 35),
    accordionProp = Color3.fromRGB(40, 35, 45), accordionSell = Color3.fromRGB(35, 35, 50),
    accordionBody = Color3.fromRGB(30, 30, 36),
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

local ALL_SEEDS, ALL_GEARS, ALL_PROPS, ALL_FRUITS = {}, {}, {}, {}

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

pcall(function()
    local seen = {}
    local seedData = safeRequire(ReplicatedStorage.SharedModules.SeedData)
    if seedData then for _, seed in ipairs(seedData) do
        if seed and seed.SeedName and not seen[seed.SeedName] then
            table.insert(ALL_FRUITS, seed.SeedName); seen[seed.SeedName] = true
        end
    end end
    table.sort(ALL_FRUITS)
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
config.selectedSellFruits = mergeItems(config.selectedSellFruits, ALL_FRUITS)

-- ==================================================================
-- GUI SKELETON (KOMPAK)
-- ==================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AoneHub"; screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false; screenGui.Destroying:Connect(saveConfig)

local minimizedCircle = Instance.new("TextButton")
minimizedCircle.Size = UDim2.new(0, 42, 0, 42); minimizedCircle.Position = UDim2.new(0.5, -21, 0.5, -21)
minimizedCircle.Text = "AH"; minimizedCircle.TextColor3 = C.text
minimizedCircle.Font = Enum.Font.GothamBlack; minimizedCircle.TextSize = 17
minimizedCircle.BackgroundColor3 = C.accent; minimizedCircle.BorderSizePixel = 0
minimizedCircle.Visible = false; minimizedCircle.AutoButtonColor = false
minimizedCircle.Draggable = true; minimizedCircle.Parent = screenGui
Instance.new("UICorner", minimizedCircle).CornerRadius = UDim.new(1, 0)

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 520, 0, 350); mainFrame.Position = UDim2.new(0.5, -260, 0.5, -175)
mainFrame.BackgroundColor3 = C.bg; mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true; mainFrame.Active = true; mainFrame.Draggable = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

-- Title bar (compact)
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 30); titleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
titleBar.BorderSizePixel = 0; titleBar.Parent = mainFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)
local titleFill = Instance.new("Frame"); titleFill.Size = UDim2.new(1, 0, 0.5, 0); titleFill.Position = UDim2.new(0, 0, 0.5, 0)
titleFill.BackgroundColor3 = Color3.fromRGB(18, 18, 24); titleFill.BorderSizePixel = 0; titleFill.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0.6, 0, 1, 0); titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.Text = "AoneHub"; titleLabel.TextColor3 = C.text; titleLabel.Font = Enum.Font.GothamBold; titleLabel.TextSize = 12
titleLabel.TextXAlignment = Enum.TextXAlignment.Left; titleLabel.BackgroundTransparency = 1; titleLabel.Parent = titleBar

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 22, 0, 22); minimizeBtn.Position = UDim2.new(1, -48, 0, 4)
minimizeBtn.Text = "–"; minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200); minimizeBtn.Font = Enum.Font.GothamBold; minimizeBtn.TextSize = 14
minimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55); minimizeBtn.BorderSizePixel = 0; minimizeBtn.AutoButtonColor = false; minimizeBtn.Parent = titleBar
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 3)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 22, 0, 22); closeBtn.Position = UDim2.new(1, -23, 0, 4)
closeBtn.Text = "✕"; closeBtn.TextColor3 = Color3.fromRGB(255, 120, 120); closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 12
closeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55); closeBtn.BorderSizePixel = 0; closeBtn.AutoButtonColor = false; closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 3)

minimizeBtn.MouseButton1Click:Connect(function()
    minimizedCircle.Position = UDim2.new(0, mainFrame.AbsolutePosition.X, 0, mainFrame.AbsolutePosition.Y)
    mainFrame.Visible = false; minimizedCircle.Visible = true
end)
minimizedCircle.MouseButton1Click:Connect(function()
    mainFrame.Position = UDim2.new(0, minimizedCircle.AbsolutePosition.X, 0, minimizedCircle.AbsolutePosition.Y)
    minimizedCircle.Visible = false; mainFrame.Visible = true
end)
closeBtn.MouseButton1Click:Connect(function() saveConfig(); screenGui:Destroy() end)

-- Sidebar (compact)
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0.22, 0, 1, -30); sidebar.Position = UDim2.new(0, 0, 0, 30)
sidebar.BackgroundColor3 = C.sidebar; sidebar.BorderSizePixel = 0; sidebar.Parent = mainFrame
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 10)
local sidebarFill = Instance.new("Frame"); sidebarFill.Size = UDim2.new(1, 0, 0.3, 0); sidebarFill.Position = UDim2.new(0, 0, 0.88, 0)
sidebarFill.BackgroundColor3 = C.sidebar; sidebarFill.BorderSizePixel = 0; sidebarFill.Parent = sidebar

local menuLabel = Instance.new("TextLabel")
menuLabel.Size = UDim2.new(1, 0, 0, 16); menuLabel.Position = UDim2.new(0, 0, 0, 6)
menuLabel.Text = "MENU"; menuLabel.TextColor3 = Color3.fromRGB(120, 120, 130); menuLabel.Font = Enum.Font.GothamBold; menuLabel.TextSize = 9
menuLabel.TextXAlignment = Enum.TextXAlignment.Center; menuLabel.BackgroundTransparency = 1; menuLabel.Parent = sidebar

local sep = Instance.new("Frame"); sep.Size = UDim2.new(0.7, 0, 0, 1); sep.Position = UDim2.new(0.15, 0, 0, 26)
sep.BackgroundColor3 = Color3.fromRGB(60, 60, 70); sep.BorderSizePixel = 0; sep.Parent = sidebar

local tabs = {
    {name="AutoBuy", label="🛒 Buy"},
    {name="AutoSell", label="💰 Sell"},
    {name="AutoMail", label="📧 Mail"},
    {name="Ekstra", label="⚙️ Extra"},
}
local tabBtns = {}; local activeTab = nil

for i, tab in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.84, 0, 0, 28); btn.Position = UDim2.new(0.08, 0, 0, 34 + (i-1)*32)
    btn.Text = tab.label; btn.TextColor3 = C.textDim; btn.Font = Enum.Font.GothamSemibold; btn.TextSize = 10
    btn.TextXAlignment = Enum.TextXAlignment.Left; btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    btn.BorderSizePixel = 0; btn.AutoButtonColor = false; btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    btn.MouseEnter:Connect(function() if activeTab ~= tab.name then btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55) end end)
    btn.MouseLeave:Connect(function() if activeTab ~= tab.name then btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40) end end)
    tabBtns[tab.name] = btn
end

local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(0.78, -6, 1, -36); contentArea.Position = UDim2.new(0.22, 3, 0, 33)
contentArea.BackgroundTransparency = 1; contentArea.ClipsDescendants = true; contentArea.Parent = mainFrame

local defaultView = Instance.new("Frame"); defaultView.Size = UDim2.new(1, 0, 1, 0); defaultView.BackgroundTransparency = 1; defaultView.Parent = contentArea
local logoLabel = Instance.new("TextLabel"); logoLabel.Size = UDim2.new(1, 0, 0, 36); logoLabel.Position = UDim2.new(0, 0, 0.35, -18)
logoLabel.Text = "AoneHub"; logoLabel.TextColor3 = C.accent; logoLabel.Font = Enum.Font.GothamBlack; logoLabel.TextSize = 28; logoLabel.BackgroundTransparency = 1; logoLabel.Parent = defaultView
local subLabel = Instance.new("TextLabel"); subLabel.Size = UDim2.new(1, 0, 0, 14); subLabel.Position = UDim2.new(0, 0, 0.48, 0)
subLabel.Text = "Pilih menu di samping"; subLabel.TextColor3 = C.textDim; subLabel.Font = Enum.Font.Gotham; subLabel.TextSize = 10; subLabel.BackgroundTransparency = 1; subLabel.Parent = defaultView

local tabFrames = {}
for _, tab in ipairs(tabs) do
    local f = Instance.new("Frame"); f.Size = UDim2.new(1, 0, 1, 0); f.BackgroundTransparency = 1; f.Visible = false; f.Parent = contentArea; tabFrames[tab.name] = f
end

local function switchTab(tabName)
    defaultView.Visible = false; for _, f in pairs(tabFrames) do f.Visible = false end
    for _, btn in pairs(tabBtns) do btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40); btn.TextColor3 = C.textDim end
    if tabFrames[tabName] then tabFrames[tabName].Visible = true; tabBtns[tabName].BackgroundColor3 = C.accent; tabBtns[tabName].TextColor3 = C.text; activeTab = tabName end
end
for _, tab in ipairs(tabs) do tabBtns[tab.name].MouseButton1Click:Connect(function() switchTab(tab.name) end) end

for _, tab in ipairs({"AutoMail", "Ekstra"}) do
    local f = tabFrames[tab]; local ic = Instance.new("TextLabel"); ic.Size = UDim2.new(1, 0, 0, 36); ic.Position = UDim2.new(0, 0, 0.35, -18)
    ic.Text = tab=="AutoMail" and "📧" or "⚙️"; ic.Font = Enum.Font.Gotham; ic.TextSize = 32; ic.BackgroundTransparency = 1; ic.Parent = f
    local tt = Instance.new("TextLabel"); tt.Size = UDim2.new(1, 0, 0, 20); tt.Position = UDim2.new(0, 0, 0.45, 0)
    tt.Text = tab=="AutoMail" and "Auto Mail" or "Ekstra"; tt.TextColor3 = C.text; tt.Font = Enum.Font.GothamBold; tt.TextSize = 14; tt.BackgroundTransparency = 1; tt.Parent = f
    local st = Instance.new("TextLabel"); st.Size = UDim2.new(1, 0, 0, 12); st.Position = UDim2.new(0, 0, 0.52, 0)
    st.Text = "Coming soon..."; st.TextColor3 = C.textDim; st.Font = Enum.Font.Gotham; st.TextSize = 9; st.BackgroundTransparency = 1; st.Parent = f
end

print("[AoneHub] ✅ GUI Ready")

-- ==================================================================
-- REMOTE
-- ==================================================================
local packetRemote = nil
local function getRemote()
    if packetRemote then return true end
    local s, r = pcall(function() return ReplicatedStorage:WaitForChild("SharedModules",5):WaitForChild("Packet",5):WaitForChild("RemoteEvent",5) end)
    if s and r then packetRemote = r; return true end; return false
end

-- ==================================================================
-- ACCORDION BUILDER (shared)
-- ==================================================================
local function createAccordion(title, items, selectedItems, itemStatus, headerColor, openKey, searchKey, layoutOrder, scrollRef)
    local accordionOpen = config[openKey] or false
    local container = Instance.new("Frame"); container.Size = UDim2.new(1, -12, 0, accordionOpen and 200 or 24); container.BackgroundTransparency = 1; container.LayoutOrder = layoutOrder; container.Parent = scrollRef
    
    local header = Instance.new("TextButton"); header.Size = UDim2.new(1, 0, 0, 24); header.BackgroundColor3 = headerColor; header.BorderSizePixel = 0
    header.Text = ""; header.AutoButtonColor = false; header.Parent = container; Instance.new("UICorner", header).CornerRadius = UDim.new(0, 4)
    
    local arrow = Instance.new("TextLabel"); arrow.Size = UDim2.new(0, 14, 1, 0); arrow.Position = UDim2.new(0, 3, 0, 0)
    arrow.Text = accordionOpen and "▼" or "▶"; arrow.TextColor3 = C.textDim; arrow.Font = Enum.Font.GothamBold; arrow.TextSize = 7; arrow.BackgroundTransparency = 1; arrow.Parent = header
    
    local titleLbl = Instance.new("TextLabel"); titleLbl.Size = UDim2.new(1, -45, 1, 0); titleLbl.Position = UDim2.new(0, 18, 0, 0)
    titleLbl.Text = title.." ("..#items..")"; titleLbl.TextColor3 = C.text; titleLbl.Font = Enum.Font.GothamSemibold; titleLbl.TextSize = 9
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.BackgroundTransparency = 1; titleLbl.Parent = header
    
    local selectAllBtn = Instance.new("TextButton"); selectAllBtn.Size = UDim2.new(0, 28, 0, 13); selectAllBtn.Position = UDim2.new(1, -31, 0.5, -6)
    selectAllBtn.Text = "All"; selectAllBtn.TextColor3 = C.text; selectAllBtn.Font = Enum.Font.Gotham; selectAllBtn.TextSize = 7; selectAllBtn.BackgroundColor3 = C.accent; selectAllBtn.BorderSizePixel = 0; selectAllBtn.AutoButtonColor = false; selectAllBtn.Parent = header; Instance.new("UICorner", selectAllBtn).CornerRadius = UDim.new(0, 2)
    
    local body = Instance.new("Frame"); body.Size = UDim2.new(1, 0, 0, 170); body.Position = UDim2.new(0, 0, 0, 26); body.BackgroundColor3 = C.accordionBody; body.BorderSizePixel = 0; body.Visible = accordionOpen; body.Parent = container; Instance.new("UICorner", body).CornerRadius = UDim.new(0, 4)
    
    local searchFrame = Instance.new("Frame"); searchFrame.Size = UDim2.new(1, -6, 0, 18); searchFrame.Position = UDim2.new(0, 3, 0, 3); searchFrame.BackgroundColor3 = C.searchBg; searchFrame.BorderSizePixel = 0; searchFrame.Parent = body; Instance.new("UICorner", searchFrame).CornerRadius = UDim.new(0, 3)
    local searchIcon = Instance.new("TextLabel"); searchIcon.Size = UDim2.new(0, 12, 1, 0); searchIcon.Position = UDim2.new(0, 2, 0, 0); searchIcon.Text = "🔍"; searchIcon.TextSize = 6; searchIcon.BackgroundTransparency = 1; searchIcon.Parent = searchFrame
    local searchBox = Instance.new("TextBox"); searchBox.Size = UDim2.new(1, -15, 1, 0); searchBox.Position = UDim2.new(0, 14, 0, 0); searchBox.PlaceholderText = "Cari..."; searchBox.PlaceholderColor3 = Color3.fromRGB(100,100,110); searchBox.Text = config[searchKey] or ""; searchBox.TextColor3 = C.text; searchBox.Font = Enum.Font.Gotham; searchBox.TextSize = 8; searchBox.BackgroundTransparency = 1; searchBox.BorderSizePixel = 0; searchBox.Parent = searchFrame
    
    local itemList = Instance.new("ScrollingFrame"); itemList.Size = UDim2.new(1, -6, 1, -24); itemList.Position = UDim2.new(0, 3, 0, 22); itemList.BackgroundTransparency = 1; itemList.BorderSizePixel = 0; itemList.ScrollBarThickness = 2; itemList.Parent = body
    local itemRows = {}; local selectAllState = false
    
    local function rebuildList()
        local query = searchBox.Text:lower(); config[searchKey] = query; saveConfig()
        for _, row in pairs(itemRows) do row.frame:Destroy() end; itemRows = {}
        local allDisplay, seen = {}, {}
        for _, name in ipairs(items) do if not seen[name] then table.insert(allDisplay, name); seen[name] = true end end
        for name in pairs(selectedItems) do if not seen[name] then table.insert(allDisplay, name); seen[name] = true end end
        local filtered = {}
        for _, name in ipairs(allDisplay) do if query == "" or name:lower():find(query) then table.insert(filtered, name) end end
        table.sort(filtered, function(a,b) local aA=table.find(items,a)~=nil; local bA=table.find(items,b)~=nil; if aA and not bA then return true; elseif not aA and bA then return false; else return a<b end end)
        
        local rh = 15; itemList.CanvasSize = UDim2.new(0,0,0,#filtered*rh+2); titleLbl.Text = title.." ("..#filtered..")"
        for i, itemName in ipairs(filtered) do
            local isAvailable = table.find(items, itemName) ~= nil; local isSelected = selectedItems[itemName] or false
            local row = Instance.new("Frame"); row.Size = UDim2.new(1,-2,0,rh-1); row.Position = UDim2.new(0,1,0,(i-1)*rh+1); row.BackgroundColor3 = isSelected and C.itemRowSelected or C.itemRow; row.BorderSizePixel = 0; row.Parent = itemList; Instance.new("UICorner", row).CornerRadius = UDim.new(0,2)
            local cb = Instance.new("TextButton"); cb.Size = UDim2.new(0,11,0,11); cb.Position = UDim2.new(0,2,0.5,-5); cb.Text = isSelected and "✅" or "⬜"; cb.TextSize = 6; cb.BackgroundTransparency = 1; cb.BorderSizePixel = 0; cb.AutoButtonColor = false; cb.Parent = row
            local icon = Instance.new("TextLabel"); icon.Size = UDim2.new(0,11,1,0); icon.Position = UDim2.new(0,14,0,0); icon.Text = isAvailable and "🟢" or "🔒"; icon.TextSize = 5; icon.BackgroundTransparency = 1; icon.Parent = row
            local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1,-28,1,0); lbl.Position = UDim2.new(0,27,0,0); lbl.Text = isAvailable and itemName or itemName.." (off)"; lbl.TextColor3 = isAvailable and (isSelected and Color3.fromRGB(100,255,100) or C.textDim) or Color3.fromRGB(120,120,130); lbl.Font = Enum.Font.Gotham; lbl.TextSize = 7; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.BackgroundTransparency = 1; lbl.Parent = row
            local st = itemStatus[itemName]; if isAvailable and st=="stock" then lbl.TextColor3 = Color3.fromRGB(100,255,100); elseif isAvailable and st=="nostock" then lbl.TextColor3 = Color3.fromRGB(255,100,100) end
            local function toggleItem() if not isAvailable then return end; selectedItems[itemName] = not (selectedItems[itemName] or false); saveConfig(); rebuildList() end
            cb.MouseButton1Click:Connect(toggleItem); row.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 then toggleItem() end end)
            itemRows[itemName] = {frame=row, lbl=lbl}
        end
        local itemH = math.min(#filtered*rh+26, 145); body.Size = UDim2.new(1,0,0,itemH)
        if accordionOpen then container.Size = UDim2.new(1,-12,0,itemH+26) end
    end
    searchBox:GetPropertyChangedSignal("Text"):Connect(rebuildList)
    selectAllBtn.MouseButton1Click:Connect(function() selectAllState = not selectAllState; selectAllBtn.Text = selectAllState and "None" or "All"; selectAllBtn.BackgroundColor3 = selectAllState and C.red or C.accent; for _, name in ipairs(items) do selectedItems[name] = not selectAllState end; saveConfig(); rebuildList() end)
    header.MouseButton1Click:Connect(function() accordionOpen = not accordionOpen; body.Visible = accordionOpen; arrow.Text = accordionOpen and "▼" or "▶"; config[openKey] = accordionOpen; saveConfig(); container.Size = UDim2.new(1,-12,0,accordionOpen and (body.Size.Y.Offset+26) or 24) end)
    rebuildList(); return container
end

-- ==================================================================
-- TAB 1: AUTO BUY (compact)
-- ==================================================================
local parent1 = tabFrames["AutoBuy"]
local buyStats = {total=0, success=0, failed=0}
local isRunning, isBuying = false, false
local itemStatusSeed, itemStatusGear, itemStatusProp = {}, {}, {}
local nextScanTime, scanCount = 0, 0
local shopElementsSeed, shopElementsGear, shopElementsProp = {}, {}, {}

local function buyItem(itemName, opcode)
    if not getRemote() then return false end
    local s = pcall(function() packetRemote:FireServer(buffer.fromstring(string.char(opcode,0,#itemName)..itemName)) end)
    buyStats.total = buyStats.total + 1
    if s then buyStats.success = buyStats.success + 1; return true else buyStats.failed = buyStats.failed + 1; return false end
end

local function cacheShop()
    pcall(function() local ss=playerGui:FindFirstChild("SeedShop"); if ss then local f=ss:FindFirstChild("Frame"); if f then local ns=f:FindFirstChild("NormalShop"); if ns then for _,ic in ipairs(ns:GetChildren()) do if config.selectedSeeds[ic.Name] then local mf=ic:FindFirstChild("Main_Frame") or ic:FindFirstChild("MainFrame"); if mf then local ct=mf:FindFirstChild("Cost_Text") or mf:FindFirstChild("CostText"); if ct then shopElementsSeed[ic.Name]={container=ic, costText=ct} end end end end end end end end)
    pcall(function() local gs=playerGui:FindFirstChild("GearShop"); if gs then local f=gs:FindFirstChild("Frame"); if f then local sf=f:FindFirstChild("ScrollingFrame"); if sf then for _,ic in ipairs(sf:GetChildren()) do if config.selectedGears[ic.Name] then local ct=ic:FindFirstChild("Cost_Text") or ic:FindFirstChild("CostText"); if ct then shopElementsGear[ic.Name]={container=ic, costText=ct} end end end end end end end)
    pcall(function() local cs=playerGui:FindFirstChild("CrateShop"); if cs then local f=cs:FindFirstChild("Frame"); if f then local sf=f:FindFirstChild("ScrollingFrame"); if sf then for _,ic in ipairs(sf:GetChildren()) do if config.selectedProps[ic.Name] then local ct=ic:FindFirstChild("Cost_Text") or ic:FindFirstChild("CostText"); if ct then shopElementsProp[ic.Name]={container=ic, costText=ct} end end end end end end end)
end

local function isAvailable(itemName, elements)
    local el=elements[itemName]; if not el then return false end; if not el.container.Visible then return false end
    local txt=""; pcall(function() txt=el.costText.Text end); return not (txt:upper():find("NO STOCK") or txt=="")
end

local function buyAll()
    if isBuying then return end; isBuying=true
    while isRunning do local any=false
        for _,itemName in ipairs(ALL_SEEDS) do if not isRunning then break end; if config.selectedSeeds[itemName] and isAvailable(itemName, shopElementsSeed) then if buyItem(itemName, OPCODE_SEED) then any=true; itemStatusSeed[itemName]="stock"; task.wait(1.25+math.random()*3.4) else itemStatusSeed[itemName]="nostock"; task.wait(0.15) end else itemStatusSeed[itemName]="nostock" end end
        for _,itemName in ipairs(ALL_GEARS) do if not isRunning then break end; if config.selectedGears[itemName] and isAvailable(itemName, shopElementsGear) then if buyItem(itemName, OPCODE_GEAR) then any=true; itemStatusGear[itemName]="stock"; task.wait(2.25+math.random()*4.4) else itemStatusGear[itemName]="nostock"; task.wait(0.15) end else itemStatusGear[itemName]="nostock" end end
        for _,itemName in ipairs(ALL_PROPS) do if not isRunning then break end; if config.selectedProps[itemName] and isAvailable(itemName, shopElementsProp) then if buyItem(itemName, OPCODE_PROP) then any=true; itemStatusProp[itemName]="stock"; task.wait(3.25+math.random()*5.4) else itemStatusProp[itemName]="nostock"; task.wait(0.15) end else itemStatusProp[itemName]="nostock" end end
        if not any then break end; task.wait(0.15)
    end; isBuying=false; updateBuyUI()
end

local function scanAndBuy() scanCount=scanCount+1; cacheShop(); local any=false
    for _,itemName in ipairs(ALL_SEEDS) do if config.selectedSeeds[itemName] then if isAvailable(itemName, shopElementsSeed) then any=true; itemStatusSeed[itemName]="stock" else itemStatusSeed[itemName]="nostock" end end end
    for _,itemName in ipairs(ALL_GEARS) do if config.selectedGears[itemName] then if isAvailable(itemName, shopElementsGear) then any=true; itemStatusGear[itemName]="stock" else itemStatusGear[itemName]="nostock" end end end
    for _,itemName in ipairs(ALL_PROPS) do if config.selectedProps[itemName] then if isAvailable(itemName, shopElementsProp) then any=true; itemStatusProp[itemName]="stock" else itemStatusProp[itemName]="nostock" end end end
    updateBuyUI(); if any then buyAll() end
end

local function mainLoop() while isRunning do local now=os.time(); local jitter=3+math.random()*2; local nrm=math.ceil(math.floor(now/60)/5)*5; local mutr=nrm-math.floor(now/60); local sutr=(mutr*60)-(now%60)+jitter; if sutr<=0 then sutr=sutr+300 end; nextScanTime=os.time()+sutr; updateBuyUI(); task.wait(sutr); if not isRunning then break end; pcall(scanAndBuy); task.wait(1) end end

local function startBuy() if isRunning then return end; if not getRemote() then return end; isRunning=true; cacheShop(); pcall(scanAndBuy); task.spawn(mainLoop); updateBuyUI() end
local function stopBuy() isRunning=false; itemStatusSeed={}; itemStatusGear={}; itemStatusProp={}; updateBuyUI() end

local scroll1 = Instance.new("ScrollingFrame"); scroll1.Size = UDim2.new(1,0,1,0); scroll1.CanvasSize = UDim2.new(0,0,0,1000); scroll1.ScrollBarThickness = 2; scroll1.BackgroundTransparency = 1; scroll1.BorderSizePixel = 0; scroll1.Parent = parent1
local buyLayout = Instance.new("UIListLayout"); buyLayout.Padding = UDim.new(0,5); buyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; buyLayout.SortOrder = Enum.SortOrder.LayoutOrder; buyLayout.Parent = scroll1

local buyHdr = Instance.new("TextLabel"); buyHdr.Size = UDim2.new(1,-12,0,20); buyHdr.LayoutOrder=1; buyHdr.Text="🛒  Auto Buy"; buyHdr.TextColor3=C.text; buyHdr.Font=Enum.Font.GothamBold; buyHdr.TextSize=12; buyHdr.TextXAlignment=Enum.TextXAlignment.Left; buyHdr.BackgroundTransparency=1; buyHdr.Parent=scroll1
local buyStatus = Instance.new("TextLabel"); buyStatus.Size=UDim2.new(1,-12,0,14); buyStatus.LayoutOrder=2; buyStatus.Text="⏹️  OFF"; buyStatus.TextColor3=C.red; buyStatus.Font=Enum.Font.GothamSemibold; buyStatus.TextSize=10; buyStatus.TextXAlignment=Enum.TextXAlignment.Left; buyStatus.BackgroundTransparency=1; buyStatus.Parent=scroll1
local buyTimer = Instance.new("TextLabel"); buyTimer.Size=UDim2.new(1,-12,0,14); buyTimer.LayoutOrder=3; buyTimer.Text="Next scan: --:--:--"; buyTimer.TextColor3=Color3.fromRGB(255,200,50); buyTimer.Font=Enum.Font.GothamBold; buyTimer.TextSize=10; buyTimer.TextXAlignment=Enum.TextXAlignment.Left; buyTimer.BackgroundTransparency=1; buyTimer.Parent=scroll1
local buyStatsText = Instance.new("TextLabel"); buyStatsText.Size=UDim2.new(1,-12,0,11); buyStatsText.LayoutOrder=4; buyStatsText.Text="✅ 0 | ❌ 0 | 🔄 0"; buyStatsText.TextColor3=C.textDim; buyStatsText.Font=Enum.Font.Gotham; buyStatsText.TextSize=8; buyStatsText.TextXAlignment=Enum.TextXAlignment.Left; buyStatsText.BackgroundTransparency=1; buyStatsText.Parent=scroll1

createAccordion("🌱 Seeds", ALL_SEEDS, config.selectedSeeds, itemStatusSeed, C.accordionSeed, "accordionSeedOpen", "searchSeed", 10, scroll1)
createAccordion("⚙️ Gears", ALL_GEARS, config.selectedGears, itemStatusGear, C.accordionGear, "accordionGearOpen", "searchGear", 20, scroll1)
createAccordion("📦 Props", ALL_PROPS, config.selectedProps, itemStatusProp, C.accordionProp, "accordionPropOpen", "searchProp", 30, scroll1)

local buyToggle = Instance.new("TextButton"); buyToggle.Size=UDim2.new(1,-12,0,28); buyToggle.LayoutOrder=100; buyToggle.Text="▶  START"; buyToggle.TextColor3=C.text; buyToggle.Font=Enum.Font.GothamBold; buyToggle.TextSize=11; buyToggle.BackgroundColor3=C.green; buyToggle.BorderSizePixel=0; buyToggle.AutoButtonColor=false; buyToggle.Parent=scroll1; Instance.new("UICorner", buyToggle).CornerRadius=UDim.new(0,5)
buyToggle.MouseEnter:Connect(function() buyToggle.BackgroundColor3 = isRunning and Color3.fromRGB(220,70,70) or Color3.fromRGB(70,220,70) end)
buyToggle.MouseLeave:Connect(function() buyToggle.BackgroundColor3 = isRunning and C.red or C.green end)

function updateBuyUI()
    if isRunning then buyStatus.Text=isBuying and "🛒  MEMBORONG..." or "⏰  MENUNGGU RESTOCK"; buyStatus.TextColor3=isBuying and C.orange or Color3.fromRGB(100,200,255); buyToggle.Text="⏹  STOP"; buyToggle.BackgroundColor3=C.red; if not isBuying and nextScanTime>0 then buyTimer.Text=os.date("%H:%M:%S", nextScanTime) elseif isBuying then buyTimer.Text="MEMBORONG..." end
    else buyStatus.Text="⏹️  OFF"; buyStatus.TextColor3=C.red; buyToggle.Text="▶  START"; buyToggle.BackgroundColor3=C.green; buyTimer.Text="Next scan: --:--:--" end
    buyStatsText.Text="✅ "..buyStats.success.." | ❌ "..buyStats.failed.." | 🔄 "..scanCount
end
buyToggle.MouseButton1Click:Connect(function() if isRunning then stopBuy() else startBuy() end; updateBuyUI() end)
task.spawn(function() while parent1.Parent do task.wait(0.5); pcall(updateBuyUI) end end)
parent1.Destroying:Connect(function() stopBuy(); saveConfig() end)

-- ==================================================================
-- TAB 2: AUTO SELL ADVANCED
-- ==================================================================
local parent2 = tabFrames["AutoSell"]
local sellStats = {total=0, success=0, failed=0}
local isSellRunning = false

-- Fungsi baca multiplier dari FruitStockPrice GUI
local function getFruitMultipliers()
    local multipliers = {}
    local stockGui = playerGui:FindFirstChild("FruitStockPrice")
    if not stockGui or not stockGui.Enabled then return multipliers end
    
    local scrollFrame = stockGui:FindFirstChild("Frame")
    if scrollFrame then scrollFrame = scrollFrame:FindFirstChild("ScrollingFrame") end
    if not scrollFrame then return multipliers end
    
    for _, card in pairs(scrollFrame:GetChildren()) do
        if card:IsA("Frame") and card.Name == "FruitCard" then
            local attr = card:GetAttribute("SeedToolTip")
            if attr then
                local frame = card:FindFirstChild("Frame")
                if frame then
                    local multLabel = frame:FindFirstChild("Multiplier")
                    if multLabel and multLabel:IsA("TextLabel") then
                        local num = multLabel.Text:match("X([%d.]+)")
                        if num then multipliers[attr] = tonumber(num) end
                    end
                end
            end
        end
    end
    return multipliers
end

-- Fungsi favorit/unfavorit buah
local function setFruitFavorite(fruitName, isFavorite)
    local net = getNetworking()
    if not net or not net.Backpack or not net.Backpack.SetFruitFavorite then return false end
    local s = pcall(function()
        local packet = buffer.fromstring(string.char(net.Backpack.SetFruitFavorite.Id, 0, #fruitName) .. fruitName .. string.char(isFavorite and 1 or 0))
        packetRemote:FireServer(packet)
    end)
    return s
end

-- Fungsi sell all
local function sellAllFruits()
    if not getRemote() then return false end
    local s = pcall(function()
        packetRemote:FireServer(buffer.fromstring(string.char(OPCODE_SELLALL, 0, 1) .. " "))
    end)
    sellStats.total = sellStats.total + 1
    if s then sellStats.success = sellStats.success + 1; return true
    else sellStats.failed = sellStats.failed + 1; return false end
end

-- Main sell logic
local function executeSell()
    local targetMult = config.sellMultiplier == "x4" and 4 or 2
    
    sellStatus.Text = "🔍 Membaca multiplier..."
    sellStatus.TextColor3 = C.orange
    
    -- Baca multiplier
    local multipliers = getFruitMultipliers()
    if next(multipliers) == nil then
        sellStatus.Text = "❌ FruitStockPrice GUI tidak terbuka!"
        sellStatus.TextColor3 = C.red
        return
    end
    
    -- Kategorikan buah
    local fruitsToSell = {}
    local fruitsToFav = {}
    
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and config.selectedSellFruits[item.Name] then
                local mult = multipliers[item.Name] or 1
                if mult >= targetMult then
                    table.insert(fruitsToSell, item.Name)
                else
                    table.insert(fruitsToFav, item.Name)
                end
            end
        end
    end
    
    if #fruitsToSell == 0 then
        sellStatus.Text = "❌ Tidak ada buah dengan multiplier ≥ x" .. targetMult
        sellStatus.TextColor3 = C.red
        return
    end
    
    sellStatus.Text = "📋 Favoritkan " .. #fruitsToFav .. " buah..."
    sellStatus.TextColor3 = C.orange
    
    -- Favoritkan buah yang TIDAK akan dijual
    for _, fruitName in ipairs(fruitsToFav) do
        setFruitFavorite(fruitName, true)
        task.wait(0.5 + math.random() * 1.5)
    end
    
    -- Unfavoritkan buah yang AKAN dijual
    for _, fruitName in ipairs(fruitsToSell) do
        setFruitFavorite(fruitName, false)
        task.wait(0.5 + math.random() * 1)
    end
    
    sellStatus.Text = "💰 Sell all " .. #fruitsToSell .. " buah (x" .. targetMult .. ")..."
    sellStatus.TextColor3 = C.orange
    
    -- Jeda sebelum sell
    task.wait(0.5 + math.random() * 1)
    
    -- Sell all
    local success = sellAllFruits()
    
    if success then
        sellStatus.Text = "✅ Berhasil menjual " .. #fruitsToSell .. " buah! (Total: " .. sellStats.success .. ")"
        sellStatus.TextColor3 = C.green
    else
        sellStatus.Text = "❌ Gagal sell all!"
        sellStatus.TextColor3 = C.red
    end
    
    -- Kembalikan favorit
    task.wait(1)
    for _, fruitName in ipairs(fruitsToFav) do
        setFruitFavorite(fruitName, false)
        task.wait(0.5 + math.random() * 1)
    end
end

-- UI for Tab 2
local scroll2 = Instance.new("ScrollingFrame"); scroll2.Size = UDim2.new(1,0,1,0); scroll2.CanvasSize = UDim2.new(0,0,0,600); scroll2.ScrollBarThickness = 2; scroll2.BackgroundTransparency = 1; scroll2.BorderSizePixel = 0; scroll2.Parent = parent2
local sellLayout = Instance.new("UIListLayout"); sellLayout.Padding = UDim.new(0,5); sellLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; sellLayout.SortOrder = Enum.SortOrder.LayoutOrder; sellLayout.Parent = scroll2

local sellHdr = Instance.new("TextLabel"); sellHdr.Size=UDim2.new(1,-12,0,20); sellHdr.LayoutOrder=1; sellHdr.Text="💰  Auto Sell Advanced"; sellHdr.TextColor3=C.text; sellHdr.Font=Enum.Font.GothamBold; sellHdr.TextSize=12; sellHdr.TextXAlignment=Enum.TextXAlignment.Left; sellHdr.BackgroundTransparency=1; sellHdr.Parent=scroll2

local sellDesc = Instance.new("TextLabel"); sellDesc.Size=UDim2.new(1,-12,0,22); sellDesc.LayoutOrder=2; sellDesc.Text="Favoritkan buah < multiplier,\nlalu sell all buah ≥ multiplier"; sellDesc.TextColor3=C.textDim; sellDesc.Font=Enum.Font.Gotham; sellDesc.TextSize=8; sellDesc.TextXAlignment=Enum.TextXAlignment.Left; sellDesc.BackgroundTransparency=1; sellDesc.Parent=scroll2

-- Multiplier selector
local multFrame = Instance.new("Frame"); multFrame.Size=UDim2.new(1,-12,0,24); multFrame.LayoutOrder=3; multFrame.BackgroundTransparency=1; multFrame.Parent=scroll2
local multLabel = Instance.new("TextLabel"); multLabel.Size=UDim2.new(0,50,1,0); multLabel.Text="Multiplier:"; multLabel.TextColor3=C.textDim; multLabel.Font=Enum.Font.Gotham; multLabel.TextSize=9; multLabel.BackgroundTransparency=1; multLabel.Parent=multFrame
local multBtnX2 = Instance.new("TextButton"); multBtnX2.Size=UDim2.new(0,30,0,18); multBtnX2.Position=UDim2.new(0,52,0,3); multBtnX2.Text="x2"; multBtnX2.TextColor3=C.text; multBtnX2.Font=Enum.Font.GothamBold; multBtnX2.TextSize=9; multBtnX2.BackgroundColor3=config.sellMultiplier=="x2" and C.accent or Color3.fromRGB(50,50,55); multBtnX2.BorderSizePixel=0; multBtnX2.AutoButtonColor=false; multBtnX2.Parent=multFrame; Instance.new("UICorner", multBtnX2).CornerRadius=UDim.new(0,3)
local multBtnX4 = Instance.new("TextButton"); multBtnX4.Size=UDim2.new(0,30,0,18); multBtnX4.Position=UDim2.new(0,86,0,3); multBtnX4.Text="x4"; multBtnX4.TextColor3=C.text; multBtnX4.Font=Enum.Font.GothamBold; multBtnX4.TextSize=9; multBtnX4.BackgroundColor3=config.sellMultiplier=="x4" and C.accent or Color3.fromRGB(50,50,55); multBtnX4.BorderSizePixel=0; multBtnX4.AutoButtonColor=false; multBtnX4.Parent=multFrame; Instance.new("UICorner", multBtnX4).CornerRadius=UDim.new(0,3)

local function updateMultBtns()
    multBtnX2.BackgroundColor3 = config.sellMultiplier=="x2" and C.accent or Color3.fromRGB(50,50,55)
    multBtnX4.BackgroundColor3 = config.sellMultiplier=="x4" and C.accent or Color3.fromRGB(50,50,55)
end
multBtnX2.MouseButton1Click:Connect(function() config.sellMultiplier="x2"; saveConfig(); updateMultBtns() end)
multBtnX4.MouseButton1Click:Connect(function() config.sellMultiplier="x4"; saveConfig(); updateMultBtns() end)

createAccordion("🍎 Fruits", ALL_FRUITS, config.selectedSellFruits, {}, C.purple, "accordionSellOpen", "searchSell", 10, scroll2)

local sellStatus = Instance.new("TextLabel"); sellStatus.Size=UDim2.new(1,-12,0,22); sellStatus.LayoutOrder=50; sellStatus.Text="Ready"; sellStatus.TextColor3=C.textDim; sellStatus.Font=Enum.Font.Gotham; sellStatus.TextSize=9; sellStatus.TextXAlignment=Enum.TextXAlignment.Left; sellStatus.BackgroundTransparency=1; sellStatus.Parent=scroll2

local sellStatsText = Instance.new("TextLabel"); sellStatsText.Size=UDim2.new(1,-12,0,11); sellStatsText.LayoutOrder=51; sellStatsText.Text="✅ 0 | ❌ 0"; sellStatsText.TextColor3=C.textDim; sellStatsText.Font=Enum.Font.Gotham; sellStatsText.TextSize=8; sellStatsText.TextXAlignment=Enum.TextXAlignment.Left; sellStatsText.BackgroundTransparency=1; sellStatsText.Parent=scroll2

local sellBtn = Instance.new("TextButton"); sellBtn.Size=UDim2.new(1,-12,0,28); sellBtn.LayoutOrder=100; sellBtn.Text="💰  EXECUTE SELL"; sellBtn.TextColor3=C.text; sellBtn.Font=Enum.Font.GothamBold; sellBtn.TextSize=11; sellBtn.BackgroundColor3=C.purple; sellBtn.BorderSizePixel=0; sellBtn.AutoButtonColor=false; sellBtn.Parent=scroll2; Instance.new("UICorner", sellBtn).CornerRadius=UDim.new(0,5)

sellBtn.MouseButton1Click:Connect(function()
    sellBtn.Text = "⏳ Processing..."; sellBtn.BackgroundColor3 = Color3.fromRGB(130,70,200)
    task.spawn(function()
        executeSell()
        sellBtn.Text = "💰  EXECUTE SELL"; sellBtn.BackgroundColor3 = C.purple
        sellStatsText.Text = "✅ "..sellStats.success.." | ❌ "..sellStats.failed
    end)
end)

saveConfig()
print("[AoneHub] ✅ Full Script Ready!")
print("[AoneHub] 🚀 Complete! Opcodes: Seed="..OPCODE_SEED.." Gear="..OPCODE_GEAR.." Prop="..OPCODE_PROP.." SellAll="..OPCODE_SELLALL)
