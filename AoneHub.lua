-- AUTO MAIL & CLAIM - FINAL FIX
-- Target dicari di PlayerList berdasarkan PlayerUsername TextLabel

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local isMailRunning = false
local isClaimRunning = false
local lastMailMinute = -1
local lastClaimMinute = -1
local targetUsername = "aoneoneee"

-- ============================================
-- DAFTAR ITEM
-- ============================================
local AVAILABLE_ITEMS = {
    {Name = "Briar Rose", Category = "Seeds", Icon = "🌹"},
    {Name = "Dragon's Breath", Category = "Seeds", Icon = "🐉"},
    {Name = "Star Fruit", Category = "Seeds", Icon = "⭐"},
    {Name = "Hypno Bloom", Category = "Seeds", Icon = "🌀"},
    {Name = "Sun Bloom", Category = "Seeds", Icon = "☀️"},
    {Name = "Moon Bloom", Category = "Seeds", Icon = "🌙"},
    {Name = "Carrot", Category = "Seeds", Icon = "🥕"},
    {Name = "Corn", Category = "Seeds", Icon = "🌽"},
    {Name = "Super Sprinkler", Category = "Sprinklers", Icon = "💦"},
    {Name = "Rare Sprinkler", Category = "Sprinklers", Icon = "💎"},
    {Name = "Super Watering Can", Category = "WateringCans", Icon = "🚿"},
}

local selectedItems = {}
local checkboxes = {}

for _, item in ipairs(AVAILABLE_ITEMS) do
    selectedItems[item.Name] = false
end

-- ============================================
-- REFERENCE GUI
-- ============================================
local mailStatusLabel = nil
local claimStatusLabel = nil
local mailToggleBtn = nil
local claimToggleBtn = nil
local userTextBox = nil
local nextMailLabel = nil
local nextClaimLabel = nil

-- ============================================
-- UPDATE STATUS
-- ============================================
local function updateMailStatus(msg, color)
    if mailStatusLabel then
        mailStatusLabel.Text = msg
        if color then mailStatusLabel.TextColor3 = color end
    end
end

local function updateClaimStatus(msg, color)
    if claimStatusLabel then
        claimStatusLabel.Text = msg
        if color then claimStatusLabel.TextColor3 = color end
    end
end

-- ============================================
-- CEK STOK
-- ============================================
local function getItemCount(itemName)
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return 0 end
    
    local total = 0
    for _, item in pairs(backpack:GetChildren()) do
        if item:IsA("Tool") and item.Name == itemName then
            total = total + 1
        end
    end
    
    local character = player.Character
    if character then
        for _, item in pairs(character:GetChildren()) do
            if item:IsA("Tool") and item.Name == itemName then
                total = total + 1
            end
        end
    end
    
    return total
end

-- ============================================
-- KATEGORI
-- ============================================
local function getCategory(itemName)
    if string.find(itemName, "Sprinkler") then return "Sprinklers"
    elseif string.find(itemName, "Watering") then return "WateringCans"
    else return "Seeds" end
end

-- ============================================
-- SET TARGET - CARI PlayerUsername "@username" (CASE INSENSITIVE)
-- ============================================
local function setMailTarget(username)
    local found = false
    
    pcall(function()
        -- Path: MailboxUI > Frame > SendingFrame > SelectPlayerFrame > PlayerList
        local playerList = player.PlayerGui:FindFirstChild("MailboxUI")
        if playerList then playerList = playerList:FindFirstChild("Frame") end
        if playerList then playerList = playerList:FindFirstChild("SendingFrame") end
        if playerList then playerList = playerList:FindFirstChild("SelectPlayerFrame") end
        if playerList then playerList = playerList:FindFirstChild("PlayerList") end
        
        if not playerList then
            print("[Mail] PlayerList tidak ditemukan!")
            return
        end
        
        print("[Mail] Mencari target: @" .. username)
        print("[Mail] Jumlah template: " .. #playerList:GetChildren())
        
        for _, template in ipairs(playerList:GetChildren()) do
            if template:IsA("Frame") then
                local button = template:FindFirstChild("Button")
                if button and (button:IsA("ImageButton") or button:IsA("TextButton")) then
                    local usernameLabel = button:FindFirstChild("PlayerUsername")
                    
                    if usernameLabel and usernameLabel:IsA("TextLabel") then
                        local labelText = usernameLabel.Text:gsub("@", "") -- Hapus @
                        
                        print("[Mail]   Cek: " .. usernameLabel.Text .. " | Template: " .. template.Name)
                        
                        -- Case insensitive compare
                        if string.lower(labelText) == string.lower(username) then
                            print("[Mail] ✓ TARGET DITEMUKAN: " .. usernameLabel.Text)
                            
                            -- Klik button
                            local pos = button.AbsolutePosition + button.AbsoluteSize / 2
                            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 1)
                            wait(0.1)
                            VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 1)
                            
                            found = true
                            return
                        end
                    end
                end
            end
        end
    end)
    
    if not found then
        print("[Mail] ✗ Target @" .. username .. " TIDAK ditemukan di PlayerList!")
    end
    
    return found
end

-- ============================================
-- ENCODE PANJANG
-- ============================================
local function encodeLen(len)
    if len < 10 then return "\00" .. tostring(len)
    elseif len < 20 then return "\0" .. tostring(len)
    else return "\v" .. string.char(len) end
end

-- ============================================
-- KIRIM SATU ITEM
-- ============================================
local function sendSingleItem(itemName, count, category)
    if count <= 0 then return false end
    
    local nameLen = string.len(itemName)
    local catLen = string.len(category)
    
    local countStr = count <= 9 and "\005\00" .. tostring(count) or "\005\0" .. tostring(count)
    
    local packet = "]\001\031\000\000\176\187\006\175\001B\028\005\001\028\v\aItemKey\v"
    packet = packet .. encodeLen(nameLen)
    packet = packet .. itemName
    packet = packet .. "\v\005Count" .. countStr
    packet = packet .. "\v\bCategory\v"
    packet = packet .. encodeLen(catLen)
    packet = packet .. category
    packet = packet .. "\000\000\000"
    
    local success = false
    pcall(function()
        local remote = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")
        remote:FireServer(buffer.fromstring(packet))
        success = true
    end)
    
    return success
end

-- ============================================
-- KIRIM SEMUA ITEM TERPILIH
-- ============================================
local function sendAllSelectedItems()
    updateMailStatus("Set target...", Color3.fromRGB(255, 200, 0))
    
    local targetSet = setMailTarget(targetUsername)
    if not targetSet then
        updateMailStatus("Target @" .. targetUsername .. " tidak ada!", Color3.fromRGB(255, 80, 80))
        return false
    end
    
    wait(0.3)
    
    local toSend = {}
    for _, item in ipairs(AVAILABLE_ITEMS) do
        if selectedItems[item.Name] then
            local stock = getItemCount(item.Name)
            if stock > 0 then
                table.insert(toSend, {Name = item.Name, Count = stock, Category = item.Category})
            end
        end
    end
    
    if #toSend == 0 then
        updateMailStatus("Stok kosong", Color3.fromRGB(255, 200, 0))
        return true
    end
    
    updateMailStatus("Mengirim " .. #toSend .. " item...", Color3.fromRGB(0, 200, 255))
    
    for _, item in ipairs(toSend) do
        print("[Mail] " .. item.Count .. "x " .. item.Name)
        local ok = sendSingleItem(item.Name, item.Count, item.Category)
        print(ok and "[Mail] ✓" or "[Mail] ✗")
        if #toSend > 1 then wait(math.random(1, 2)) end
    end
    
    updateMailStatus("Terkirim! " .. #toSend .. " item", Color3.fromRGB(0, 255, 100))
    return true
end

-- ============================================
-- CLAIM
-- ============================================
local function getReceiveFrame()
    local success, result = pcall(function()
        return player.PlayerGui:FindFirstChild("MailboxUI")
            and player.PlayerGui.MailboxUI:FindFirstChild("Frame")
            and player.PlayerGui.MailboxUI.Frame:FindFirstChild("ReceiveFrame")
    end)
    return success and result or nil
end

local function scanGifts()
    local receiveFrame = getReceiveFrame()
    if not receiveFrame then return {} end
    
    local gifts = {}
    for _, child in ipairs(receiveFrame:GetChildren()) do
        if child:IsA("Frame") and string.find(child.Name, "Gift_4:") then
            local itemId = string.match(child.Name, "Gift_4:(.+)")
            if itemId then table.insert(gifts, itemId) end
        end
    end
    return gifts
end

local function claimAllGifts()
    if not isClaimRunning then return end
    
    updateClaimStatus("Scanning...", Color3.fromRGB(0, 200, 255))
    local gifts = scanGifts()
    
    if #gifts == 0 then
        updateClaimStatus("Tidak ada gift", Color3.fromRGB(255, 200, 0))
        return
    end
    
    updateClaimStatus("Claiming " .. #gifts .. " gift...", Color3.fromRGB(0, 255, 200))
    
    for i, giftId in ipairs(gifts) do
        if not isClaimRunning then break end
        pcall(function()
            local remote = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")
            remote:FireServer(buffer.fromstring("b\0014&4:" .. giftId))
        end)
        if i < #gifts and isClaimRunning then wait(math.random(10, 30) / 10) end
    end
    
    updateClaimStatus("Selesai! " .. #gifts .. " gift", Color3.fromRGB(0, 255, 100))
end

-- ============================================
-- SCAN & KIRIM + RETRY
-- ============================================
local function scanAndSend()
    if not isMailRunning then return end
    sendAllSelectedItems()
    
    wait(math.random(21, 25))
    
    if isMailRunning then
        local hasStock = false
        for _, item in ipairs(AVAILABLE_ITEMS) do
            if selectedItems[item.Name] and getItemCount(item.Name) > 0 then
                hasStock = true
                break
            end
        end
        if hasStock then
            updateMailStatus("Retry - stok masih ada", Color3.fromRGB(255, 180, 0))
            sendAllSelectedItems()
        end
    end
end

-- ============================================
-- TIME CHECK
-- ============================================
local function isMailScanTime()
    local m = os.date("*t").min
    local s = os.date("*t").sec
    if m % 5 == 3 and s <= 2 and lastMailMinute ~= m then
        lastMailMinute = m
        return true
    end
    return false
end

local function isClaimScanTime()
    local m = os.date("*t").min
    local s = os.date("*t").sec
    if m % 5 == 4 and s <= 2 and lastClaimMinute ~= m then
        lastClaimMinute = m
        return true
    end
    return false
end

-- ============================================
-- CHECKBOX VISUAL
-- ============================================
local function updateCheckboxVisual(itemName)
    local cb = checkboxes[itemName]
    if not cb then return end
    
    if selectedItems[itemName] then
        cb.button.BackgroundColor3 = Color3.fromRGB(0, 160, 80)
        cb.mark.Visible = true
        cb.frame.BackgroundColor3 = Color3.fromRGB(40, 60, 45)
    else
        cb.button.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
        cb.mark.Visible = false
        cb.frame.BackgroundColor3 = Color3.fromRGB(42, 42, 48)
    end
end

-- ============================================
-- BUILD GUI
-- ============================================
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoMailClaim_GUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 300, 0, 460)
    mainFrame.Position = UDim2.new(0, 10, 0.5, -230)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    mainFrame.BackgroundTransparency = 0.03
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = mainFrame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 28)
    title.Position = UDim2.new(0, 0, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "📦📬 AUTO MAIL & CLAIM"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.Parent = mainFrame
    
    -- Tab Bar
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -16, 0, 32)
    tabBar.Position = UDim2.new(0, 8, 0, 44)
    tabBar.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    tabBar.BorderSizePixel = 0
    tabBar.Parent = mainFrame
    Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 6)
    
    -- Tab Mail
    local tabMailBtn = Instance.new("TextButton")
    tabMailBtn.Size = UDim2.new(0.5, -2, 1, -4)
    tabMailBtn.Position = UDim2.new(0, 2, 0, 2)
    tabMailBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 80)
    tabMailBtn.Text = "📦 MAIL"
    tabMailBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    tabMailBtn.Font = Enum.Font.GothamBold
    tabMailBtn.TextSize = 12
    tabMailBtn.BorderSizePixel = 0
    tabMailBtn.Parent = tabBar
    Instance.new("UICorner", tabMailBtn).CornerRadius = UDim.new(0, 5)
    
    -- Tab Claim
    local tabClaimBtn = Instance.new("TextButton")
    tabClaimBtn.Size = UDim2.new(0.5, -2, 1, -4)
    tabClaimBtn.Position = UDim2.new(0.5, 0, 0, 2)
    tabClaimBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    tabClaimBtn.Text = "📬 CLAIM"
    tabClaimBtn.TextColor3 = Color3.fromRGB(170, 170, 170)
    tabClaimBtn.Font = Enum.Font.GothamBold
    tabClaimBtn.TextSize = 12
    tabClaimBtn.BorderSizePixel = 0
    tabClaimBtn.Parent = tabBar
    Instance.new("UICorner", tabClaimBtn).CornerRadius = UDim.new(0, 5)
    
    -- ============================================
    -- TAB MAIL CONTENT
    -- ============================================
    local mailContent = Instance.new("Frame")
    mailContent.Size = UDim2.new(1, -16, 0, 370)
    mailContent.Position = UDim2.new(0, 8, 0, 82)
    mailContent.BackgroundTransparency = 1
    mailContent.Visible = true
    mailContent.Parent = mainFrame
    
    -- Username
    local userLabel = Instance.new("TextLabel")
    userLabel.Size = UDim2.new(1, 0, 0, 16)
    userLabel.BackgroundTransparency = 1
    userLabel.Text = "🎯 Target Username:"
    userLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    userLabel.Font = Enum.Font.Gotham
    userLabel.TextSize = 10
    userLabel.TextXAlignment = Enum.TextXAlignment.Left
    userLabel.Parent = mailContent
    
    local userTextBoxLocal = Instance.new("TextBox")
    userTextBoxLocal.Size = UDim2.new(1, 0, 0, 28)
    userTextBoxLocal.Position = UDim2.new(0, 0, 0, 18)
    userTextBoxLocal.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    userTextBoxLocal.TextColor3 = Color3.fromRGB(255, 255, 255)
    userTextBoxLocal.PlaceholderText = "Masukkan username..."
    userTextBoxLocal.PlaceholderColor3 = Color3.fromRGB(110, 110, 110)
    userTextBoxLocal.Font = Enum.Font.Gotham
    userTextBoxLocal.TextSize = 13
    userTextBoxLocal.Text = targetUsername
    userTextBoxLocal.Parent = mailContent
    Instance.new("UICorner", userTextBoxLocal).CornerRadius = UDim.new(0, 5)
    userTextBox = userTextBoxLocal
    
    -- Items Label
    local itemsLabel = Instance.new("TextLabel")
    itemsLabel.Size = UDim2.new(1, 0, 0, 16)
    itemsLabel.Position = UDim2.new(0, 0, 0, 52)
    itemsLabel.BackgroundTransparency = 1
    itemsLabel.Text = "📋 Pilih Item:"
    itemsLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    itemsLabel.Font = Enum.Font.Gotham
    itemsLabel.TextSize = 10
    itemsLabel.TextXAlignment = Enum.TextXAlignment.Left
    itemsLabel.Parent = mailContent
    
    -- ScrollingFrame
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, 0, 0, 195)
    scrollFrame.Position = UDim2.new(0, 0, 0, 70)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 33)
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 5
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 100)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #AVAILABLE_ITEMS * 32 + 10)
    scrollFrame.Parent = mailContent
    Instance.new("UICorner", scrollFrame).CornerRadius = UDim.new(0, 5)
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 2)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scrollFrame
    
    for i, item in ipairs(AVAILABLE_ITEMS) do
        local itemFrame = Instance.new("Frame")
        itemFrame.Size = UDim2.new(1, -8, 0, 28)
        itemFrame.BackgroundColor3 = Color3.fromRGB(42, 42, 48)
        itemFrame.BorderSizePixel = 0
        itemFrame.Parent = scrollFrame
        Instance.new("UICorner", itemFrame).CornerRadius = UDim.new(0, 4)
        
        local checkBtn = Instance.new("TextButton")
        checkBtn.Size = UDim2.new(0, 20, 0, 20)
        checkBtn.Position = UDim2.new(0, 5, 0.5, -10)
        checkBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
        checkBtn.Text = ""
        checkBtn.BorderSizePixel = 0
        checkBtn.Parent = itemFrame
        Instance.new("UICorner", checkBtn).CornerRadius = UDim.new(0, 3)
        
        local checkMark = Instance.new("TextLabel")
        checkMark.Size = UDim2.new(1, 0, 1, 0)
        checkMark.BackgroundTransparency = 1
        checkMark.Text = "✓"
        checkMark.TextColor3 = Color3.fromRGB(0, 255, 100)
        checkMark.Font = Enum.Font.GothamBold
        checkMark.TextSize = 14
        checkMark.Visible = false
        checkMark.Parent = checkBtn
        
        local stockLabel = Instance.new("TextLabel")
        stockLabel.Size = UDim2.new(0, 30, 1, 0)
        stockLabel.Position = UDim2.new(1, -32, 0, 0)
        stockLabel.BackgroundTransparency = 1
        stockLabel.Text = "0"
        stockLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        stockLabel.Font = Enum.Font.Gotham
        stockLabel.TextSize = 9
        stockLabel.TextXAlignment = Enum.TextXAlignment.Right
        stockLabel.Parent = itemFrame
        
        local itemLabel = Instance.new("TextLabel")
        itemLabel.Size = UDim2.new(1, -70, 1, 0)
        itemLabel.Position = UDim2.new(0, 28, 0, 0)
        itemLabel.BackgroundTransparency = 1
        itemLabel.Text = item.Icon .. " " .. item.Name
        itemLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        itemLabel.Font = Enum.Font.Gotham
        itemLabel.TextSize = 11
        itemLabel.TextXAlignment = Enum.TextXAlignment.Left
        itemLabel.Parent = itemFrame
        
        checkboxes[item.Name] = {
            button = checkBtn,
            mark = checkMark,
            frame = itemFrame,
            stockLabel = stockLabel
        }
        
        local clickHandler = function()
            selectedItems[item.Name] = not selectedItems[item.Name]
            updateCheckboxVisual(item.Name)
        end
        
        checkBtn.MouseButton1Click:Connect(clickHandler)
        itemFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then clickHandler() end
        end)
    end
    
    -- Next scan
    nextMailLabel = Instance.new("TextLabel")
    nextMailLabel.Size = UDim2.new(1, 0, 0, 14)
    nextMailLabel.Position = UDim2.new(0, 0, 0, 270)
    nextMailLabel.BackgroundTransparency = 1
    nextMailLabel.Text = "⏰ Scan: menit 03, 08, 13..."
    nextMailLabel.TextColor3 = Color3.fromRGB(140, 140, 150)
    nextMailLabel.Font = Enum.Font.Gotham
    nextMailLabel.TextSize = 9
    nextMailLabel.TextXAlignment = Enum.TextXAlignment.Left
    nextMailLabel.Parent = mailContent
    
    -- Status
    mailStatusLabel = Instance.new("TextLabel")
    mailStatusLabel.Size = UDim2.new(1, 0, 0, 16)
    mailStatusLabel.Position = UDim2.new(0, 0, 0, 285)
    mailStatusLabel.BackgroundTransparency = 1
    mailStatusLabel.Text = "Status: SIAP"
    mailStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
    mailStatusLabel.Font = Enum.Font.Gotham
    mailStatusLabel.TextSize = 10
    mailStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    mailStatusLabel.Parent = mailContent
    
    -- Toggle Mail
    mailToggleBtn = Instance.new("TextButton")
    mailToggleBtn.Size = UDim2.new(1, 0, 0, 32)
    mailToggleBtn.Position = UDim2.new(0, 0, 0, 305)
    mailToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
    mailToggleBtn.Text = "▶ MULAI MAIL"
    mailToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    mailToggleBtn.Font = Enum.Font.GothamBold
    mailToggleBtn.TextSize = 13
    mailToggleBtn.BorderSizePixel = 0
    mailToggleBtn.Parent = mailContent
    Instance.new("UICorner", mailToggleBtn).CornerRadius = UDim.new(0, 5)
    
    -- ============================================
    -- TAB CLAIM CONTENT
    -- ============================================
    local claimContent = Instance.new("Frame")
    claimContent.Size = UDim2.new(1, -16, 0, 370)
    claimContent.Position = UDim2.new(0, 8, 0, 82)
    claimContent.BackgroundTransparency = 1
    claimContent.Visible = false
    claimContent.Parent = mainFrame
    
    local claimInfo = Instance.new("TextLabel")
    claimInfo.Size = UDim2.new(1, 0, 0, 140)
    claimInfo.Position = UDim2.new(0, 0, 0, 20)
    claimInfo.BackgroundTransparency = 1
    claimInfo.Text = "📬 Auto Claim Mailbox\n\n✅ Scan tiap menit 04, 09, 14...\n✅ Claim semua gift di ReceiveFrame\n✅ Jitter 1-3 detik antar claim\n✅ Tidak perlu buka mailbox\n✅ Claim langsung saat ON"
    claimInfo.TextColor3 = Color3.fromRGB(190, 190, 200)
    claimInfo.Font = Enum.Font.Gotham
    claimInfo.TextSize = 11
    claimInfo.TextXAlignment = Enum.TextXAlignment.Left
    claimInfo.TextWrapped = true
    claimInfo.Parent = claimContent
    
    nextClaimLabel = Instance.new("TextLabel")
    nextClaimLabel.Size = UDim2.new(1, 0, 0, 14)
    nextClaimLabel.Position = UDim2.new(0, 0, 0, 260)
    nextClaimLabel.BackgroundTransparency = 1
    nextClaimLabel.Text = "⏰ Scan: menit 04, 09, 14..."
    nextClaimLabel.TextColor3 = Color3.fromRGB(140, 140, 150)
    nextClaimLabel.Font = Enum.Font.Gotham
    nextClaimLabel.TextSize = 9
    nextClaimLabel.TextXAlignment = Enum.TextXAlignment.Left
    nextClaimLabel.Parent = claimContent
    
    claimStatusLabel = Instance.new("TextLabel")
    claimStatusLabel.Size = UDim2.new(1, 0, 0, 16)
    claimStatusLabel.Position = UDim2.new(0, 0, 0, 278)
    claimStatusLabel.BackgroundTransparency = 1
    claimStatusLabel.Text = "Status: SIAP"
    claimStatusLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
    claimStatusLabel.Font = Enum.Font.Gotham
    claimStatusLabel.TextSize = 10
    claimStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    claimStatusLabel.Parent = claimContent
    
    claimToggleBtn = Instance.new("TextButton")
    claimToggleBtn.Size = UDim2.new(1, 0, 0, 32)
    claimToggleBtn.Position = UDim2.new(0, 0, 0, 300)
    claimToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 200)
    claimToggleBtn.Text = "▶ MULAI CLAIM"
    claimToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    claimToggleBtn.Font = Enum.Font.GothamBold
    claimToggleBtn.TextSize = 13
    claimToggleBtn.BorderSizePixel = 0
    claimToggleBtn.Parent = claimContent
    Instance.new("UICorner", claimToggleBtn).CornerRadius = UDim.new(0, 5)
    
    -- ============================================
    -- TAB SWITCHING
    -- ============================================
    tabMailBtn.MouseButton1Click:Connect(function()
        mailContent.Visible = true
        claimContent.Visible = false
        tabMailBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 80)
        tabMailBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        tabClaimBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
        tabClaimBtn.TextColor3 = Color3.fromRGB(170, 170, 170)
    end)
    
    tabClaimBtn.MouseButton1Click:Connect(function()
        mailContent.Visible = false
        claimContent.Visible = true
        tabClaimBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 200)
        tabClaimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        tabMailBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
        tabMailBtn.TextColor3 = Color3.fromRGB(170, 170, 170)
    end)
    
    -- ============================================
    -- TOGGLE HANDLERS
    -- ============================================
    mailToggleBtn.MouseButton1Click:Connect(function()
        isMailRunning = not isMailRunning
        
        if isMailRunning then
            targetUsername = userTextBoxLocal.Text
            if targetUsername == "" then
                updateMailStatus("ISI USERNAME DULU!", Color3.fromRGB(255, 80, 80))
                isMailRunning = false
                return
            end
            
            local hasSelection = false
            for _, item in ipairs(AVAILABLE_ITEMS) do
                if selectedItems[item.Name] then hasSelection = true break end
            end
            
            if not hasSelection then
                updateMailStatus("PILIH ITEM DULU!", Color3.fromRGB(255, 80, 80))
                isMailRunning = false
                return
            end
            
            mailToggleBtn.Text = "⏸ BERHENTI MAIL"
            mailToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            updateMailStatus("AKTIF - Menunggu scan...", Color3.fromRGB(0, 255, 100))
            lastMailMinute = -1
            print("[Mail] AUTO MAIL DIMULAI | Target: @" .. targetUsername)
        else
            mailToggleBtn.Text = "▶ MULAI MAIL"
            mailToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
            updateMailStatus("BERHENTI", Color3.fromRGB(255, 200, 0))
            print("[Mail] AUTO MAIL BERHENTI")
        end
    end)
    
    claimToggleBtn.MouseButton1Click:Connect(function()
        isClaimRunning = not isClaimRunning
        
        if isClaimRunning then
            claimToggleBtn.Text = "⏸ BERHENTI CLAIM"
            claimToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            updateClaimStatus("AKTIF - Claiming...", Color3.fromRGB(0, 255, 100))
            lastClaimMinute = -1
            print("[Claim] AUTO CLAIM DIMULAI")
            claimAllGifts()
            if isClaimRunning then
                updateClaimStatus("AKTIF - Menunggu scan...", Color3.fromRGB(0, 255, 100))
            end
        else
            claimToggleBtn.Text = "▶ MULAI CLAIM"
            claimToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 200)
            updateClaimStatus("BERHENTI", Color3.fromRGB(255, 200, 0))
            print("[Claim] AUTO CLAIM BERHENTI")
        end
    end)
    
    return screenGui
end

-- ============================================
-- UPDATE STOK & TIMER
-- ============================================
local function updateStockDisplay()
    for _, item in ipairs(AVAILABLE_ITEMS) do
        local cb = checkboxes[item.Name]
        if cb and cb.stockLabel then
            local stock = getItemCount(item.Name)
            cb.stockLabel.Text = tostring(stock)
            cb.stockLabel.TextColor3 = stock > 0 and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(120, 120, 120)
        end
    end
end

local function updateNextScanLabel()
    local m = os.date("*t").min
    local s = os.date("*t").sec
    
    local nextMail = 3 - (m % 5)
    if nextMail <= 0 then nextMail = nextMail + 5 end
    if m % 5 == 3 and s > 2 then nextMail = 5 end
    
    if nextMailLabel then
        nextMailLabel.Text = "⏰ Scan berikutnya: ±" .. nextMail .. " menit"
    end
    
    local nextClaim = 4 - (m % 5)
    if nextClaim <= 0 then nextClaim = nextClaim + 5 end
    if m % 5 == 4 and s > 2 then nextClaim = 5 end
    
    if nextClaimLabel then
        nextClaimLabel.Text = "⏰ Scan berikutnya: ±" .. nextClaim .. " menit"
    end
end

-- ============================================
-- MAIN LOOP
-- ============================================
spawn(function()
    createGUI()
    
    -- Auto-select default
    selectedItems["Dragon's Breath"] = true
    selectedItems["Super Sprinkler"] = true
    
    wait(0.5)
    for _, item in ipairs(AVAILABLE_ITEMS) do
        updateCheckboxVisual(item.Name)
    end
    updateStockDisplay()
    updateNextScanLabel()
    
    print("========================================")
    print(" AUTO MAIL & CLAIM - GUI AKTIF")
    print(" Target: @" .. targetUsername)
    print(" TANPA perlu buka mailbox")
    print("========================================")
    
    while true do
        wait(1)
        updateStockDisplay()
        updateNextScanLabel()
        
        if isMailRunning and isMailScanTime() then
            print("[Mail] SCAN TIME: " .. os.date("%H:%M:%S"))
            scanAndSend()
            if isMailRunning then
                updateMailStatus("AKTIF - Menunggu scan...", Color3.fromRGB(0, 255, 100))
            end
        end
        
        if isClaimRunning and isClaimScanTime() then
            print("[Claim] SCAN TIME: " .. os.date("%H:%M:%S"))
            claimAllGifts()
            if isClaimRunning then
                updateClaimStatus("AKTIF - Menunggu scan...", Color3.fromRGB(0, 255, 100))
            end
        end
    end
end)
