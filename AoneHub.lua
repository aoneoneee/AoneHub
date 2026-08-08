-- AONEHUB PART 2: AUTO BUY ENGINE (FIXED)
if not _G.AoneHub_TabFrame then
    warn("[Part 2] ❌ Part 1 not loaded! Execute Part 1 first.")
    return
end

local parent = _G.AoneHub_TabFrame
local config = _G.AoneHub_Config
local saveConfig = _G.AoneHub_SaveConfig

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local C = {
    accent = Color3.fromRGB(90, 140, 255),
    text = Color3.fromRGB(255, 255, 255),
    textDim = Color3.fromRGB(170, 170, 180),
    green = Color3.fromRGB(50, 200, 50),
    red = Color3.fromRGB(200, 50, 50),
    input = Color3.fromRGB(38, 38, 48),
    inputLocked = Color3.fromRGB(28, 28, 35),
    accordionSeed = Color3.fromRGB(35, 42, 35),
    accordionGear = Color3.fromRGB(42, 35, 35),
    accordionProp = Color3.fromRGB(40, 35, 45),
    accordionBody = Color3.fromRGB(30, 30, 36),
    itemRow = Color3.fromRGB(38, 38, 45),
    itemRowSelected = Color3.fromRGB(35, 55, 40),
    searchBg = Color3.fromRGB(32, 32, 38),
}

-- Get items
local function safeRequire(path)
    local s, r = pcall(function() return require(path) end)
    if s then return r end
    return nil
end

local ALL_SEEDS = {}
local ALL_GEARS = {}
local ALL_PROPS = {}

pcall(function()
    local seedData = safeRequire(ReplicatedStorage.SharedModules.SeedData)
    if seedData then
        for _, seed in ipairs(seedData) do
            if seed and seed.RestockShop and seed.SeedName then
                table.insert(ALL_SEEDS, seed.SeedName)
            end
        end
    end
    if #ALL_SEEDS == 0 then ALL_SEEDS = {"Hypno Bloom", "Dragon's Breath", "Sun Bloom", "Star Fruit"} end
    table.sort(ALL_SEEDS)
end)

pcall(function()
    local gearData = safeRequire(ReplicatedStorage.SharedModules.GearShopData)
    if gearData and gearData.Data then
        for _, gear in ipairs(gearData.Data) do
            if gear and not gear.RobuxOnly and not gear.HideFromShop and gear.ItemName then
                table.insert(ALL_GEARS, gear.ItemName)
            end
        end
    end
    table.sort(ALL_GEARS)
end)

pcall(function()
    local crateData = safeRequire(ReplicatedStorage.SharedModules.CrateData)
    if crateData and crateData.GetAllCrates then
        for _, crate in ipairs(crateData.GetAllCrates()) do
            if crate and crate.RestockChance and crate.Name then
                table.insert(ALL_PROPS, crate.Name)
            end
        end
    end
    table.sort(ALL_PROPS)
end)

print("[Part 2] 📋 Seeds:" .. #ALL_SEEDS .. " Gears:" .. #ALL_GEARS .. " Props:" .. #ALL_PROPS)

-- Merge config items
local function mergeItems(saved, current)
    local merged = {}
    if type(saved) == "table" then for k, v in pairs(saved) do merged[k] = v end end
    for _, name in ipairs(current) do if merged[name] == nil then merged[name] = false end end
    return merged
end

config.selectedSeeds = mergeItems(config.selectedSeeds, ALL_SEEDS)
config.selectedGears = mergeItems(config.selectedGears, ALL_GEARS)
config.selectedProps = mergeItems(config.selectedProps, ALL_PROPS)
saveConfig()

-- Auto Buy Variables
local OPCODE_SEED = config.opcodeSeed or 133
local OPCODE_GEAR = config.opcodeGear or 137
local OPCODE_PROP = config.opcodeProp or 135

local buyStats = {total = 0, success = 0, failed = 0}
local isRunning, isBuying = false, false
local itemStatusSeed, itemStatusGear, itemStatusProp = {}, {}, {}
local nextScanTime, scanCount = 0, 0
local shopElementsSeed, shopElementsGear, shopElementsProp = {}, {}, {}

-- Build UI
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, 0, 1, 0)
scroll.CanvasSize = UDim2.new(0, 0, 0, 1200)
scroll.ScrollBarThickness = 3
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.Parent = parent

local y = 10

-- Header
local hdr = Instance.new("TextLabel")
hdr.Size = UDim2.new(1, -20, 0, 24)
hdr.Position = UDim2.new(0, 10, 0, y)
hdr.Text = "🛒  Auto Buy (Seed + Gear + Prop)"
hdr.TextColor3 = C.text
hdr.Font = Enum.Font.GothamBold
hdr.TextSize = 14
hdr.TextXAlignment = Enum.TextXAlignment.Left
hdr.BackgroundTransparency = 1
hdr.Parent = scroll
y += 28

-- Status
local statusText = Instance.new("TextLabel")
statusText.Size = UDim2.new(1, -20, 0, 18)
statusText.Position = UDim2.new(0, 10, 0, y)
statusText.Text = "⏹️  OFF"
statusText.TextColor3 = C.red
statusText.Font = Enum.Font.GothamSemibold
statusText.TextSize = 12
statusText.TextXAlignment = Enum.TextXAlignment.Left
statusText.BackgroundTransparency = 1
statusText.Parent = scroll
y += 22

-- Opcode row
local opRow = Instance.new("Frame")
opRow.Size = UDim2.new(1, -20, 0, 40)
opRow.Position = UDim2.new(0, 10, 0, y)
opRow.BackgroundTransparency = 1
opRow.Parent = scroll

-- Seed opcode
local opl1 = Instance.new("TextLabel")
opl1.Size = UDim2.new(0, 35, 0, 15)
opl1.Text = "Seed:"
opl1.TextColor3 = Color3.fromRGB(100, 200, 100)
opl1.Font = Enum.Font.Gotham
opl1.TextSize = 10
opl1.BackgroundTransparency = 1
opl1.Parent = opRow

local opInputSeed = Instance.new("TextBox")
opInputSeed.Size = UDim2.new(0, 40, 0, 15)
opInputSeed.Position = UDim2.new(0, 37, 0, 0)
opInputSeed.Text = tostring(OPCODE_SEED)
opInputSeed.TextColor3 = C.text
opInputSeed.Font = Enum.Font.GothamBold
opInputSeed.TextSize = 10
opInputSeed.BackgroundColor3 = C.input
opInputSeed.BorderSizePixel = 0
opInputSeed.Parent = opRow
Instance.new("UICorner", opInputSeed).CornerRadius = UDim.new(0, 3)

-- Gear opcode (READ-ONLY style, bukan TextBox)
local opl2 = Instance.new("TextLabel")
opl2.Size = UDim2.new(0, 35, 0, 15)
opl2.Position = UDim2.new(0, 85, 0, 0)
opl2.Text = "Gear:"
opl2.TextColor3 = Color3.fromRGB(255, 150, 50)
opl2.Font = Enum.Font.Gotham
opl2.TextSize = 10
opl2.BackgroundTransparency = 1
opl2.Parent = opRow

local opDisplayGear = Instance.new("TextLabel")  -- Pakai TextLabel, bukan TextBox
opDisplayGear.Size = UDim2.new(0, 40, 0, 15)
opDisplayGear.Position = UDim2.new(0, 122, 0, 0)
opDisplayGear.Text = tostring(OPCODE_GEAR)
opDisplayGear.TextColor3 = Color3.fromRGB(255, 200, 150)
opDisplayGear.Font = Enum.Font.GothamBold
opDisplayGear.TextSize = 10
opDisplayGear.BackgroundColor3 = C.inputLocked
opDisplayGear.BorderSizePixel = 0
opDisplayGear.TextXAlignment = Enum.TextXAlignment.Center
opDisplayGear.Parent = opRow
Instance.new("UICorner", opDisplayGear).CornerRadius = UDim.new(0, 3)

-- Prop opcode (READ-ONLY style)
local opl3 = Instance.new("TextLabel")
opl3.Size = UDim2.new(0, 35, 0, 15)
opl3.Position = UDim2.new(0, 170, 0, 0)
opl3.Text = "Prop:"
opl3.TextColor3 = Color3.fromRGB(200, 100, 255)
opl3.Font = Enum.Font.Gotham
opl3.TextSize = 10
opl3.BackgroundTransparency = 1
opl3.Parent = opRow

local opDisplayProp = Instance.new("TextLabel")  -- Pakai TextLabel
opDisplayProp.Size = UDim2.new(0, 40, 0, 15)
opDisplayProp.Position = UDim2.new(0, 207, 0, 0)
opDisplayProp.Text = tostring(OPCODE_PROP)
opDisplayProp.TextColor3 = Color3.fromRGB(220, 180, 255)
opDisplayProp.Font = Enum.Font.GothamBold
opDisplayProp.TextSize = 10
opDisplayProp.BackgroundColor3 = C.inputLocked
opDisplayProp.BorderSizePixel = 0
opDisplayProp.TextXAlignment = Enum.TextXAlignment.Center
opDisplayProp.Parent = opRow
Instance.new("UICorner", opDisplayProp).CornerRadius = UDim.new(0, 3)

-- Set button
local opSetBtn = Instance.new("TextButton")
opSetBtn.Size = UDim2.new(0, 32, 0, 15)
opSetBtn.Position = UDim2.new(0, 255, 0, 0)
opSetBtn.Text = "Set"
opSetBtn.TextColor3 = C.text
opSetBtn.Font = Enum.Font.GothamSemibold
opSetBtn.TextSize = 9
opSetBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
opSetBtn.BorderSizePixel = 0
opSetBtn.AutoButtonColor = false
opSetBtn.Parent = opRow
Instance.new("UICorner", opSetBtn).CornerRadius = UDim.new(0, 3)

opSetBtn.MouseButton1Click:Connect(function()
    local n = tonumber(opInputSeed.Text)
    if n and n >= 100 and n <= 200 then
        OPCODE_SEED = n
        OPCODE_GEAR = n + 4
        OPCODE_PROP = n + 2
        config.opcodeSeed = OPCODE_SEED
        config.opcodeGear = OPCODE_GEAR
        config.opcodeProp = OPCODE_PROP
        saveConfig()
        updateUI()
    end
end)

-- Status label
local opDetectStatus = Instance.new("TextLabel")
opDetectStatus.Size = UDim2.new(1, 0, 0, 14)
opDetectStatus.Position = UDim2.new(0, 0, 0, 24)
opDetectStatus.Text = "🔍 S:" .. OPCODE_SEED .. " G:" .. OPCODE_GEAR .. " P:" .. OPCODE_PROP
opDetectStatus.TextColor3 = Color3.fromRGB(255, 200, 50)
opDetectStatus.Font = Enum.Font.Gotham
opDetectStatus.TextSize = 9
opDetectStatus.TextXAlignment = Enum.TextXAlignment.Left
opDetectStatus.BackgroundTransparency = 1
opDetectStatus.Parent = opRow
y += 46

-- Timer + Stats
local timerText = Instance.new("TextLabel")
timerText.Size = UDim2.new(1, -20, 0, 18)
timerText.Position = UDim2.new(0, 10, 0, y)
timerText.Text = "Next scan: --:--:--"
timerText.TextColor3 = Color3.fromRGB(255, 200, 50)
timerText.Font = Enum.Font.GothamBold
timerText.TextSize = 12
timerText.TextXAlignment = Enum.TextXAlignment.Left
timerText.BackgroundTransparency = 1
timerText.Parent = scroll
y += 20

local statsText = Instance.new("TextLabel")
statsText.Size = UDim2.new(1, -20, 0, 14)
statsText.Position = UDim2.new(0, 10, 0, y)
statsText.Text = "✅ 0  |  ❌ 0  |  🔄 0"
statsText.TextColor3 = C.textDim
statsText.Font = Enum.Font.Gotham
statsText.TextSize = 10
statsText.TextXAlignment = Enum.TextXAlignment.Left
statsText.BackgroundTransparency = 1
statsText.Parent = scroll
y += 20

-- Simple buy function
local packetRemote = nil
local function getRemote()
    if packetRemote then return true end
    local s, r = pcall(function()
        return ReplicatedStorage:WaitForChild("SharedModules", 5)
            :WaitForChild("Packet", 5)
            :WaitForChild("RemoteEvent", 5)
    end)
    if s and r then packetRemote = r; return true end
    return false
end

local function buyItem(itemName, opcode)
    if not getRemote() then return false end
    local packet = buffer.fromstring(string.char(opcode, 0, #itemName) .. itemName)
    local s = pcall(function() packetRemote:FireServer(packet) end)
    buyStats.total = buyStats.total + 1
    if s then buyStats.success = buyStats.success + 1; return true
    else buyStats.failed = buyStats.failed + 1; return false end
end

local function isAvailable(itemName, elements)
    local el = elements[itemName]
    if not el then return false end
    if not el.container.Visible then return false end
    local txt = ""
    pcall(function() txt = el.costText.Text end)
    return not (txt:upper():find("NO STOCK") or txt == "")
end

local function cacheShop()
    -- Seeds
    pcall(function()
        local ss = playerGui:FindFirstChild("SeedShop")
        if ss then
            local f = ss:FindFirstChild("Frame")
            if f then
                local ns = f:FindFirstChild("NormalShop")
                if ns then
                    for _, ic in ipairs(ns:GetChildren()) do
                        if config.selectedSeeds[ic.Name] then
                            local mf = ic:FindFirstChild("Main_Frame") or ic:FindFirstChild("MainFrame")
                            if mf then
                                local ct = mf:FindFirstChild("Cost_Text") or mf:FindFirstChild("CostText")
                                if ct then shopElementsSeed[ic.Name] = {container = ic, costText = ct} end
                            end
                        end
                    end
                end
            end
        end
    end)
    
    -- Gears
    pcall(function()
        local gs = playerGui:FindFirstChild("GearShop")
        if gs then
            local f = gs:FindFirstChild("Frame")
            if f then
                local sf = f:FindFirstChild("ScrollingFrame")
                if sf then
                    for _, ic in ipairs(sf:GetChildren()) do
                        if config.selectedGears[ic.Name] then
                            local ct = ic:FindFirstChild("Cost_Text") or ic:FindFirstChild("CostText")
                            if ct then shopElementsGear[ic.Name] = {container = ic, costText = ct} end
                        end
                    end
                end
            end
        end
    end)
    
    -- Props
    pcall(function()
        local cs = playerGui:FindFirstChild("CrateShop")
        if cs then
            local f = cs:FindFirstChild("Frame")
            if f then
                local sf = f:FindFirstChild("ScrollingFrame")
                if sf then
                    for _, ic in ipairs(sf:GetChildren()) do
                        if config.selectedProps[ic.Name] then
                            local ct = ic:FindFirstChild("Cost_Text") or ic:FindFirstChild("CostText")
                            if ct then shopElementsProp[ic.Name] = {container = ic, costText = ct} end
                        end
                    end
                end
            end
        end
    end)
end

local function buyAll()
    if isBuying then return end
    isBuying = true
    while isRunning do
        local any = false
        
        for _, itemName in ipairs(ALL_SEEDS) do
            if not isRunning then break end
            if config.selectedSeeds[itemName] and isAvailable(itemName, shopElementsSeed) then
                if buyItem(itemName, OPCODE_SEED) then
                    any = true; itemStatusSeed[itemName] = "stock"
                    task.wait(0.3 + math.random() * 0.5)
                else itemStatusSeed[itemName] = "nostock"; task.wait(0.2) end
            else itemStatusSeed[itemName] = "nostock" end
        end
        
        for _, itemName in ipairs(ALL_GEARS) do
            if not isRunning then break end
            if config.selectedGears[itemName] and isAvailable(itemName, shopElementsGear) then
                if buyItem(itemName, OPCODE_GEAR) then
                    any = true; itemStatusGear[itemName] = "stock"
                    task.wait(0.3 + math.random() * 0.5)
                else itemStatusGear[itemName] = "nostock"; task.wait(0.2) end
            else itemStatusGear[itemName] = "nostock" end
        end
        
        for _, itemName in ipairs(ALL_PROPS) do
            if not isRunning then break end
            if config.selectedProps[itemName] and isAvailable(itemName, shopElementsProp) then
                if buyItem(itemName, OPCODE_PROP) then
                    any = true; itemStatusProp[itemName] = "stock"
                    task.wait(0.3 + math.random() * 0.5)
                else itemStatusProp[itemName] = "nostock"; task.wait(0.2) end
            else itemStatusProp[itemName] = "nostock" end
        end
        
        if not any then break end
        task.wait(0.2)
    end
    isBuying = false
    updateUI()
end

local function scanAndBuy()
    scanCount = scanCount + 1
    cacheShop()
    local any = false
    
    for _, itemName in ipairs(ALL_SEEDS) do
        if config.selectedSeeds[itemName] then
            if isAvailable(itemName, shopElementsSeed) then any = true; itemStatusSeed[itemName] = "stock"
            else itemStatusSeed[itemName] = "nostock" end
        end
    end
    
    for _, itemName in ipairs(ALL_GEARS) do
        if config.selectedGears[itemName] then
            if isAvailable(itemName, shopElementsGear) then any = true; itemStatusGear[itemName] = "stock"
            else itemStatusGear[itemName] = "nostock" end
        end
    end
    
    for _, itemName in ipairs(ALL_PROPS) do
        if config.selectedProps[itemName] then
            if isAvailable(itemName, shopElementsProp) then any = true; itemStatusProp[itemName] = "stock"
            else itemStatusProp[itemName] = "nostock" end
        end
    end
    
    updateUI()
    if any then buyAll() end
end

local function mainLoop()
    while isRunning do
        local now = os.time()
        local jitter = 3 + math.random() * 2
        local nrm = math.ceil(math.floor(now / 60) / 5) * 5
        local mutr = nrm - math.floor(now / 60)
        local sutr = (mutr * 60) - (now % 60) + jitter
        if sutr <= 0 then sutr = sutr + 300 end
        
        nextScanTime = os.time() + sutr
        updateUI()
        task.wait(sutr)
        
        if not isRunning then break end
        pcall(scanAndBuy)
        task.wait(1)
    end
end

local function startMonitoring()
    if isRunning then return end
    if not getRemote() then return end
    isRunning = true
    cacheShop()
    pcall(scanAndBuy)
    task.spawn(mainLoop)
    updateUI()
end

local function stopMonitoring()
    isRunning = false
    itemStatusSeed = {}
    itemStatusGear = {}
    itemStatusProp = {}
    updateUI()
end

-- Create simple item list
local function createSimpleList(title, items, selectedItems, itemStatus, headerColor, yStart)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -20, 0, 180)
    container.Position = UDim2.new(0, 10, 0, yStart)
    container.BackgroundTransparency = 1
    container.Parent = scroll
    
    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 26)
    header.BackgroundColor3 = headerColor
    header.BorderSizePixel = 0
    header.Parent = container
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 5)
    
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -10, 1, 0)
    titleLbl.Position = UDim2.new(0, 8, 0, 0)
    titleLbl.Text = title .. " (" .. #items .. ")"
    titleLbl.TextColor3 = C.text
    titleLbl.Font = Enum.Font.GothamSemibold
    titleLbl.TextSize = 11
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.BackgroundTransparency = 1
    titleLbl.Parent = header
    
    -- Item list
    local itemList = Instance.new("ScrollingFrame")
    itemList.Size = UDim2.new(1, 0, 0, 152)
    itemList.Position = UDim2.new(0, 0, 0, 28)
    itemList.BackgroundColor3 = C.accordionBody
    itemList.BorderSizePixel = 0
    itemList.ScrollBarThickness = 3
    itemList.CanvasSize = UDim2.new(0, 0, 0, #items * 20 + 4)
    itemList.Parent = container
    Instance.new("UICorner", itemList).CornerRadius = UDim.new(0, 5)
    
    for i, itemName in ipairs(items) do
        local isSelected = selectedItems[itemName] or false
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -6, 0, 18)
        row.Position = UDim2.new(0, 3, 0, (i-1) * 20 + 2)
        row.BackgroundColor3 = isSelected and C.itemRowSelected or C.itemRow
        row.BorderSizePixel = 0
        row.Parent = itemList
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 2)
        
        local cb = Instance.new("TextButton")
        cb.Size = UDim2.new(0, 13, 0, 13)
        cb.Position = UDim2.new(0, 3, 0.5, -6)
        cb.Text = isSelected and "✅" or "⬜"
        cb.TextSize = 8
        cb.BackgroundTransparency = 1
        cb.BorderSizePixel = 0
        cb.AutoButtonColor = false
        cb.Parent = row
        
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -20, 1, 0)
        lbl.Position = UDim2.new(0, 18, 0, 0)
        lbl.Text = itemName
        lbl.TextColor3 = C.textDim
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 9
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.BackgroundTransparency = 1
        lbl.Parent = row
        
        local st = itemStatus[itemName]
        if st == "stock" then lbl.TextColor3 = Color3.fromRGB(100, 255, 100)
        elseif st == "nostock" then lbl.TextColor3 = Color3.fromRGB(255, 100, 100) end
        
        cb.MouseButton1Click:Connect(function()
            selectedItems[itemName] = not selectedItems[itemName]
            cb.Text = selectedItems[itemName] and "✅" or "⬜"
            row.BackgroundColor3 = selectedItems[itemName] and C.itemRowSelected or C.itemRow
            lbl.TextColor3 = selectedItems[itemName] and C.text or C.textDim
            saveConfig()
        end)
    end
    
    return container
end

-- Create 3 lists
local seedList = createSimpleList("🌱 Seeds", ALL_SEEDS, config.selectedSeeds, itemStatusSeed, C.accordionSeed, y)
local gearY = y + 190
local gearList = createSimpleList("⚙️ Gears", ALL_GEARS, config.selectedGears, itemStatusGear, C.accordionGear, gearY)
local propY = gearY + 190
local propList = createSimpleList("📦 Props", ALL_PROPS, config.selectedProps, itemStatusProp, C.accordionProp, propY)

-- Toggle button
local toggleY = propY + 190
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(1, -20, 0, 36)
toggleBtn.Position = UDim2.new(0, 10, 0, toggleY)
toggleBtn.Text = "▶  START"
toggleBtn.TextColor3 = C.text
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 13
toggleBtn.BackgroundColor3 = C.green
toggleBtn.BorderSizePixel = 0
toggleBtn.AutoButtonColor = false
toggleBtn.Parent = scroll
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)

toggleBtn.MouseEnter:Connect(function()
    toggleBtn.BackgroundColor3 = isRunning and Color3.fromRGB(220, 70, 70) or Color3.fromRGB(70, 220, 70)
end)
toggleBtn.MouseLeave:Connect(function()
    toggleBtn.BackgroundColor3 = isRunning and C.red or C.green
end)

-- Update UI
function updateUI()
    opInputSeed.Text = tostring(OPCODE_SEED)
    opDisplayGear.Text = tostring(OPCODE_GEAR)
    opDisplayProp.Text = tostring(OPCODE_PROP)
    opDetectStatus.Text = "🔍 S:" .. OPCODE_SEED .. " G:" .. OPCODE_GEAR .. " P:" .. OPCODE_PROP
    
    if isRunning then
        statusText.Text = isBuying and "🛒  MEMBORONG..." or "⏰  MENUNGGU RESTOCK"
        statusText.TextColor3 = isBuying and Color3.fromRGB(255, 150, 50) or Color3.fromRGB(100, 200, 255)
        toggleBtn.Text = "⏹  STOP"
        toggleBtn.BackgroundColor3 = C.red
        if not isBuying and nextScanTime > 0 then
            timerText.Text = os.date("%H:%M:%S", nextScanTime)
        elseif isBuying then
            timerText.Text = "MEMBORONG..."
        end
    else
        statusText.Text = "⏹️  OFF"
        statusText.TextColor3 = C.red
        toggleBtn.Text = "▶  START"
        toggleBtn.BackgroundColor3 = C.green
        timerText.Text = "Next scan: --:--:--"
    end
    statsText.Text = "✅ " .. buyStats.success .. "  |  ❌ " .. buyStats.failed .. "  |  🔄 " .. scanCount
end

toggleBtn.MouseButton1Click:Connect(function()
    if isRunning then stopMonitoring() else startMonitoring() end
    updateUI()
end)

task.spawn(function()
    while parent.Parent do
        task.wait(0.5)
        pcall(updateUI)
    end
end)

parent.Destroying:Connect(function()
    stopMonitoring()
    saveConfig()
end)

saveConfig()
print("[Part 2] ✅ Auto Buy Ready!")
print("[AoneHub] 🚀 Complete!")
