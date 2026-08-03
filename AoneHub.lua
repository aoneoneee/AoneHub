-- AUTO MAIL + AUTO CLAIM - GABUNGAN FINAL V2
-- Textbox jumlah item per item (0 = kirim semua stok)
-- Langsung scan & kirim saat toggle ON
-- Pakai remote & buffer TERBUKTI BERHASIL

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- ============================================
-- STATE
-- ============================================
local isMailRunning = false
local isClaimRunning = false
local lastMailMinute = -1
local lastClaimMinute = -1

-- ============================================
-- DAFTAR ITEM
-- ============================================
local AVAILABLE_ITEMS = {
    {Name = "Briar Rose", Category = "Seeds", DisplayName = "🌹 Briar Rose"},
    {Name = "Dragon's Breath", Category = "Seeds", DisplayName = "🐉 Dragon's Breath"},
    {Name = "Star Fruit", Category = "Seeds", DisplayName = "⭐ Star Fruit"},
    {Name = "Hypno Bloom", Category = "Seeds", DisplayName = "🌀 Hypno Bloom"},
    {Name = "Sun Bloom", Category = "Seeds", DisplayName = "☀️ Sun Bloom"},
    {Name = "Moon Bloom", Category = "Seeds", DisplayName = "🌙 Moon Bloom"},
    {Name = "Carrot", Category = "Seeds", DisplayName = "🥕 Carrot"},
    {Name = "Corn", Category = "Seeds", DisplayName = "🌽 Corn"},
    {Name = "Super Sprinkler", Category = "Sprinklers", DisplayName = "💦 Super Sprinkler"},
    {Name = "Rare Sprinkler", Category = "Sprinklers", DisplayName = "💎 Rare Sprinkler"},
    {Name = "Super Watering Can", Category = "WateringCans", DisplayName = "🚿 Super Watering Can"},
}

local selectedItems = {}
local itemCounts = {} -- Jumlah yang mau dikirim per item (0 = semua)
local checkboxes = {}
local countTextboxes = {}
local targetUsername = "aoneoneee"

for _, item in ipairs(AVAILABLE_ITEMS) do
    selectedItems[item.Name] = false
    itemCounts[item.Name] = 0 -- Default: kirim semua
end

-- ============================================
-- REFERENCE GUI
-- ============================================
local mailStatusLabel = nil
local claimStatusLabel = nil

-- ============================================
-- FUNGSI UPDATE STATUS
-- ============================================
local function updateMailStatus(msg)
    if mailStatusLabel then mailStatusLabel.Text = msg end
end

local function updateClaimStatus(msg)
    if claimStatusLabel then claimStatusLabel.Text = msg end
end

-- ============================================
-- GET REMOTE
-- ============================================
local function getRemote()
    return ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")
end

-- ============================================
-- ENCODE (FORMAT TERBUKTI)
-- ============================================
local function encodeCount(count)
    if count <= 9 then return "\005\00" .. tostring(count)
    else return "\005" .. string.char(count) end
end

local function encodeLen(len)
    if len < 10 then return "\00" .. tostring(len)
    elseif len < 20 then return "\0" .. tostring(len)
    else return "\v" .. string.char(len) end
end

local function encodeUsernameLen(len)
    if len < 10 then return "\00" .. tostring(len)
    else return "\0" .. tostring(len) end
end

-- ============================================
-- SET TARGET VIA REMOTE
-- ============================================
local function setTargetRemote(username)
    local len = string.len(username)
    local packet = "^\001b" .. encodeUsernameLen(len) .. username
    local success = false
    pcall(function() getRemote():FireServer(buffer.fromstring(packet)); success = true end)
    return success
end

-- ============================================
-- KIRIM ITEM VIA REMOTE
-- ============================================
local function sendItemRemote(itemName, count, category)
    if count <= 0 then return false end
    
    local nameLen = string.len(itemName)
    local catLen = string.len(category)
    
    local packet = "]\001c\000\000\000<y%\166A"
    packet = packet .. "\028\005\001"
    packet = packet .. "\028\v\aItemKey\v"
    packet = packet .. encodeLen(nameLen)
    packet = packet .. itemName
    packet = packet .. "\v\005Count" .. encodeCount(count)
    packet = packet .. "\v\bCategory\v"
    packet = packet .. encodeLen(catLen)
    packet = packet .. category
    packet = packet .. "\000\000\000"
    
    local success = false
    pcall(function() getRemote():FireServer(buffer.fromstring(packet)); success = true end)
    return success
end

-- ============================================
-- CEK STOK
-- ============================================
local function getItemCount(itemName)
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return 0 end
    local total = 0
    for _, item in pairs(backpack:GetChildren()) do
        if item:IsA("Tool") and item.Name == itemName then total = total + 1 end
    end
    local character = player.Character
    if character then
        for _, item in pairs(character:GetChildren()) do
            if item:IsA("Tool") and item.Name == itemName then total = total + 1 end
        end
    end
    return total
end

-- ============================================
-- DAPATKAN ITEM DENGAN STOK & JUMLAH CUSTOM
-- ============================================
local function getItemsToSend()
    local itemsToSend = {}
    
    for _, item in ipairs(AVAILABLE_ITEMS) do
        if selectedItems[item.Name] then
            local stock = getItemCount(item.Name)
            if stock > 0 then
                local customCount = tonumber(itemCounts[item.Name]) or 0
                local sendCount
                
                if customCount <= 0 then
                    -- 0 atau kosong = kirim semua stok
                    sendCount = stock
                else
                    -- Kirim sesuai custom, tapi maksimal stok yang ada
                    sendCount = math.min(customCount, stock)
                end
                
                if sendCount > 0 then
                    table.insert(itemsToSend, {
                        Name = item.Name,
                        Count = sendCount,
                        Category = item.Category
                    })
                end
            end
        end
    end
    
    return itemsToSend
end

-- ============================================
-- KIRIM SEMUA
-- ============================================
local function sendAllMail()
    if targetUsername == "" then return false end
    
    print("[Mail] ===== SET TARGET: " .. targetUsername .. " =====")
    updateMailStatus("Set target...")
    
    if not setTargetRemote(targetUsername) then
        print("[Mail] GAGAL set target!")
        updateMailStatus("Gagal set target!")
        return false
    end
    
    wait(0.5)
    
    print("[Mail] ===== SCANNING BACKPACK =====")
    local itemsToSend = getItemsToSend()
    
    if #itemsToSend == 0 then
        print("[Mail] Tidak ada item untuk dikirim")
        updateMailStatus("Stok kosong")
        return true
    end
    
    -- Tampilkan ringkasan
    print("[Mail] Rencana kirim:")
    for _, item in ipairs(itemsToSend) do
        print("  - " .. item.Count .. "x " .. item.Name)
    end
    
    print("[Mail] ===== MENGIRIM " .. #itemsToSend .. " ITEM =====")
    
    local successCount = 0
    for _, item in ipairs(itemsToSend) do
        local ok = sendItemRemote(item.Name, item.Count, item.Category)
        if ok then
            successCount = successCount + 1
            print("[Mail] ✓ " .. item.Name .. " x" .. item.Count)
        else
            print("[Mail] ✗ " .. item.Name)
        end
        if #itemsToSend > 1 then wait(math.random(1, 2)) end
    end
    
    print("[Mail] ===== SELESAI: " .. successCount .. "/" .. #itemsToSend .. " =====")
    updateMailStatus("Terkirim: " .. successCount .. " item")
    return true
end

-- ============================================
-- SCAN & KIRIM + RETRY
-- ============================================
local function scanAndSendMail()
    if not isMailRunning then return end
    if targetUsername == "" then return end
    
    sendAllMail()
    
    -- Retry
    local retryCount = 0
    while isMailRunning do
        wait(math.random(21, 25))
        local remaining = getItemsToSend()
        if #remaining == 0 then
            print("[Mail] Stok habis")
            updateMailStatus("Stok habis - Menunggu scan")
            break
        end
        retryCount = retryCount + 1
        print("[Mail] Retry #" .. retryCount)
        updateMailStatus("Retry #" .. retryCount)
        sendAllMail()
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
-- CLAIM FUNCTIONS
-- ============================================
local function getReceiveFrame()
    local success, result = pcall(function()
        local mailboxUI = player.PlayerGui:FindFirstChild("MailboxUI")
        if mailboxUI then
            local frame = mailboxUI:FindFirstChild("Frame")
            if frame then return frame:FindFirstChild("ReceiveFrame") end
        end
        return nil
    end)
    return success and result or nil
end

local function scanGiftFrames()
    local receiveFrame = getReceiveFrame()
    if not receiveFrame then return {} end
    local gifts = {}
    for _, child in ipairs(receiveFrame:GetChildren()) do
        if child:IsA("Frame") and string.find(child.Name, "Gift_4:") then
            local itemId = string.match(child.Name, "Gift_4:(.+)")
            if itemId and itemId ~= "" then table.insert(gifts, {itemId = itemId}) end
        end
    end
    return gifts
end

local function claimAllGifts()
    if not isClaimRunning then return end
    updateClaimStatus("Scanning...")
    local gifts = scanGiftFrames()
    if #gifts == 0 then updateClaimStatus("Tidak ada gift"); return end
    updateClaimStatus("Claiming " .. #gifts .. " gifts...")
    local claimed = 0
    for i, gift in ipairs(gifts) do
        if not isClaimRunning then break end
        pcall(function() getRemote():FireServer(buffer.fromstring("b\0014&4:" .. gift.itemId)) end)
        claimed = claimed + 1
        if i < #gifts and isClaimRunning then wait(math.random(10, 30) / 10) end
    end
    updateClaimStatus("Selesai: " .. claimed .. "/" .. #gifts)
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
        cb.button.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
        cb.mark.Visible = false
        cb.frame.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
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
    mainFrame.Size = UDim2.new(0, 310, 0, 460)
    mainFrame.Position = UDim2.new(0, 10, 0.5, -230)
    mainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    mainFrame.BackgroundTransparency = 0.05
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 25)
    title.Position = UDim2.new(0, 10, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "📦📬 AUTO MAIL & CLAIM v2"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Parent = mainFrame
    
    -- Tab Bar
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -20, 0, 30)
    tabBar.Position = UDim2.new(0, 10, 0, 38)
    tabBar.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    tabBar.BorderSizePixel = 0
    tabBar.Parent = mainFrame
    Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 6)
    
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
    
    local tabClaimBtn = Instance.new("TextButton")
    tabClaimBtn.Size = UDim2.new(0.5, -2, 1, -4)
    tabClaimBtn.Position = UDim2.new(0.5, 0, 0, 2)
    tabClaimBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    tabClaimBtn.Text = "📬 CLAIM"
    tabClaimBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    tabClaimBtn.Font = Enum.Font.GothamBold
    tabClaimBtn.TextSize = 12
    tabClaimBtn.BorderSizePixel = 0
    tabClaimBtn.Parent = tabBar
    Instance.new("UICorner", tabClaimBtn).CornerRadius = UDim.new(0, 5)
    
    -- ============================================
    -- TAB MAIL
    -- ============================================
    local mailContent = Instance.new("Frame")
    mailContent.Size = UDim2.new(1, -20, 0, 355)
    mailContent.Position = UDim2.new(0, 10, 0, 75)
    mailContent.BackgroundTransparency = 1
    mailContent.Visible = true
    mailContent.Parent = mainFrame
    
    -- Username
    local userLabel = Instance.new("TextLabel")
    userLabel.Size = UDim2.new(1, 0, 0, 14)
    userLabel.BackgroundTransparency = 1
    userLabel.Text = "🎯 Target Username:"
    userLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    userLabel.Font = Enum.Font.Gotham
    userLabel.TextSize = 9
    userLabel.TextXAlignment = Enum.TextXAlignment.Left
    userLabel.Parent = mailContent
    
    local userTextBox = Instance.new("TextBox")
    userTextBox.Size = UDim2.new(1, 0, 0, 24)
    userTextBox.Position = UDim2.new(0, 0, 0, 15)
    userTextBox.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    userTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    userTextBox.PlaceholderText = "Username..."
    userTextBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
    userTextBox.Font = Enum.Font.Gotham
    userTextBox.TextSize = 11
    userTextBox.Text = targetUsername
    userTextBox.Parent = mailContent
    Instance.new("UICorner", userTextBox).CornerRadius = UDim.new(0, 4)
    
    -- Header: Item | Jumlah
    local headerFrame = Instance.new("Frame")
    headerFrame.Size = UDim2.new(1, 0, 0, 16)
    headerFrame.Position = UDim2.new(0, 0, 0, 44)
    headerFrame.BackgroundTransparency = 1
    headerFrame.Parent = mailContent
    
    local headerItem = Instance.new("TextLabel")
    headerItem.Size = UDim2.new(0.6, -5, 1, 0)
    headerItem.BackgroundTransparency = 1
    headerItem.Text = "Item"
    headerItem.TextColor3 = Color3.fromRGB(150, 150, 160)
    headerItem.Font = Enum.Font.GothamBold
    headerItem.TextSize = 9
    headerItem.TextXAlignment = Enum.TextXAlignment.Left
    headerItem.Parent = headerFrame
    
    local headerCount = Instance.new("TextLabel")
    headerCount.Size = UDim2.new(0.4, -5, 1, 0)
    headerCount.Position = UDim2.new(0.6, 5, 0, 0)
    headerCount.BackgroundTransparency = 1
    headerCount.Text = "Jumlah (0=All)"
    headerCount.TextColor3 = Color3.fromRGB(150, 150, 160)
    headerCount.Font = Enum.Font.GothamBold
    headerCount.TextSize = 9
    headerCount.TextXAlignment = Enum.TextXAlignment.Center
    headerCount.Parent = headerFrame
    
    -- Scrolling Frame
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, 0, 0, 210)
    scrollFrame.Position = UDim2.new(0, 0, 0, 62)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 4
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 110)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #AVAILABLE_ITEMS * 34 + 8)
    scrollFrame.Parent = mailContent
    Instance.new("UICorner", scrollFrame).CornerRadius = UDim.new(0, 4)
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 2)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scrollFrame
    
    -- Items dengan checkbox + textbox jumlah
    for i, item in ipairs(AVAILABLE_ITEMS) do
        local itemFrame = Instance.new("Frame")
        itemFrame.Size = UDim2.new(1, -8, 0, 30)
        itemFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
        itemFrame.BorderSizePixel = 0
        itemFrame.Parent = scrollFrame
        Instance.new("UICorner", itemFrame).CornerRadius = UDim.new(0, 3)
        
        -- Checkbox
        local checkBtn = Instance.new("TextButton")
        checkBtn.Size = UDim2.new(0, 18, 0, 18)
        checkBtn.Position = UDim2.new(0, 3, 0.5, -9)
        checkBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
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
        checkMark.TextSize = 12
        checkMark.Visible = false
        checkMark.Parent = checkBtn
        
        -- Nama item
        local itemLabel = Instance.new("TextLabel")
        itemLabel.Size = UDim2.new(0.6, -30, 1, 0)
        itemLabel.Position = UDim2.new(0, 24, 0, 0)
        itemLabel.BackgroundTransparency = 1
        itemLabel.Text = item.DisplayName
        itemLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        itemLabel.Font = Enum.Font.Gotham
        itemLabel.TextSize = 10
        itemLabel.TextXAlignment = Enum.TextXAlignment.Left
        itemLabel.Parent = itemFrame
        
        -- Textbox jumlah
        local countBox = Instance.new("TextBox")
        countBox.Size = UDim2.new(0, 40, 0, 20)
        countBox.Position = UDim2.new(0.65, 0, 0.5, -10)
        countBox.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
        countBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        countBox.PlaceholderText = "0"
        countBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
        countBox.Font = Enum.Font.Gotham
        countBox.TextSize = 10
        countBox.Text = "0"
        countBox.Parent = itemFrame
        Instance.new("UICorner", countBox).CornerRadius = UDim.new(0, 3)
        
        -- Label stok
        local stockLabel = Instance.new("TextLabel")
        stockLabel.Size = UDim2.new(0, 50, 0, 20)
        stockLabel.Position = UDim2.new(1, -55, 0.5, -10)
        stockLabel.BackgroundTransparency = 1
        stockLabel.Text = "Stok:0"
        stockLabel.TextColor3 = Color3.fromRGB(120, 120, 130)
        stockLabel.Font = Enum.Font.Gotham
        stockLabel.TextSize = 8
        stockLabel.TextXAlignment = Enum.TextXAlignment.Right
        stockLabel.Parent = itemFrame
        
        -- Simpan reference
        checkboxes[item.Name] = {
            button = checkBtn,
            mark = checkMark,
            frame = itemFrame,
            stockLabel = stockLabel
        }
        countTextboxes[item.Name] = countBox
        
        -- Click handlers
        local clickHandler = function()
            selectedItems[item.Name] = not selectedItems[item.Name]
            updateCheckboxVisual(item.Name)
        end
        checkBtn.MouseButton1Click:Connect(clickHandler)
        itemFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then clickHandler() end
        end)
        
        -- Update itemCounts saat textbox berubah
        countBox.FocusLost:Connect(function(enterPressed)
            local val = tonumber(countBox.Text)
            if val and val >= 0 then
                itemCounts[item.Name] = val
            else
                countBox.Text = "0"
                itemCounts[item.Name] = 0
            end
        end)
    end
    
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #AVAILABLE_ITEMS * 34 + 8)
    
    -- Status
    local mailStatus = Instance.new("TextLabel")
    mailStatus.Size = UDim2.new(1, 0, 0, 14)
    mailStatus.Position = UDim2.new(0, 0, 0, 278)
    mailStatus.BackgroundTransparency = 1
    mailStatus.Text = "Status: SIAP - Remote OK"
    mailStatus.TextColor3 = Color3.fromRGB(255, 200, 0)
    mailStatus.Font = Enum.Font.Gotham
    mailStatus.TextSize = 9
    mailStatus.TextXAlignment = Enum.TextXAlignment.Left
    mailStatus.Parent = mailContent
    mailStatusLabel = mailStatus
    
    -- Toggle Mail
    local mailToggle = Instance.new("TextButton")
    mailToggle.Size = UDim2.new(1, 0, 0, 30)
    mailToggle.Position = UDim2.new(0, 0, 0, 296)
    mailToggle.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
    mailToggle.Text = "▶ MULAI MAIL (Langsung Kirim)"
    mailToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    mailToggle.Font = Enum.Font.GothamBold
    mailToggle.TextSize = 11
    mailToggle.BorderSizePixel = 0
    mailToggle.Parent = mailContent
    Instance.new("UICorner", mailToggle).CornerRadius = UDim.new(0, 5)
    
    -- ============================================
    -- TAB CLAIM
    -- ============================================
    local claimContent = Instance.new("Frame")
    claimContent.Size = UDim2.new(1, -20, 0, 355)
    claimContent.Position = UDim2.new(0, 10, 0, 75)
    claimContent.BackgroundTransparency = 1
    claimContent.Visible = false
    claimContent.Parent = mainFrame
    
    local claimInfo = Instance.new("TextLabel")
    claimInfo.Size = UDim2.new(1, 0, 0, 80)
    claimInfo.Position = UDim2.new(0, 0, 0, 20)
    claimInfo.BackgroundTransparency = 1
    claimInfo.Text = "📬 Auto Claim Mailbox\n\n• Scan setiap menit 04, 09, 14...\n• Claim semua gift di ReceiveFrame\n• Jitter 1-3 detik antar claim\n• Tidak perlu buka mailbox"
    claimInfo.TextColor3 = Color3.fromRGB(200, 200, 200)
    claimInfo.Font = Enum.Font.Gotham
    claimInfo.TextSize = 11
    claimInfo.TextXAlignment = Enum.TextXAlignment.Left
    claimInfo.TextWrapped = true
    claimInfo.Parent = claimContent
    
    local claimStatus = Instance.new("TextLabel")
    claimStatus.Size = UDim2.new(1, 0, 0, 14)
    claimStatus.Position = UDim2.new(0, 0, 0, 270)
    claimStatus.BackgroundTransparency = 1
    claimStatus.Text = "Status: SIAP"
    claimStatus.TextColor3 = Color3.fromRGB(255, 200, 0)
    claimStatus.Font = Enum.Font.Gotham
    claimStatus.TextSize = 9
    claimStatus.TextXAlignment = Enum.TextXAlignment.Left
    claimStatus.Parent = claimContent
    claimStatusLabel = claimStatus
    
    local claimToggle = Instance.new("TextButton")
    claimToggle.Size = UDim2.new(1, 0, 0, 30)
    claimToggle.Position = UDim2.new(0, 0, 0, 290)
    claimToggle.BackgroundColor3 = Color3.fromRGB(0, 150, 200)
    claimToggle.Text = "▶ MULAI CLAIM (Langsung Scan)"
    claimToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    claimToggle.Font = Enum.Font.GothamBold
    claimToggle.TextSize = 11
    claimToggle.BorderSizePixel = 0
    claimToggle.Parent = claimContent
    Instance.new("UICorner", claimToggle).CornerRadius = UDim.new(0, 5)
    
    -- ============================================
    -- TAB SWITCHING
    -- ============================================
    tabMailBtn.MouseButton1Click:Connect(function()
        mailContent.Visible = true
        claimContent.Visible = false
        tabMailBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 80)
        tabMailBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        tabClaimBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
        tabClaimBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    end)
    
    tabClaimBtn.MouseButton1Click:Connect(function()
        mailContent.Visible = false
        claimContent.Visible = true
        tabClaimBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 200)
        tabClaimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        tabMailBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
        tabMailBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    end)
    
    -- ============================================
    -- TOGGLE MAIL - LANGSUNG KIRIM SAAT ON
    -- ============================================
    mailToggle.MouseButton1Click:Connect(function()
        isMailRunning = not isMailRunning
        
        if isMailRunning then
            targetUsername = userTextBox.Text
            if targetUsername == "" then
                updateMailStatus("ISI USERNAME DULU!")
                isMailRunning = false
                return
            end
            
            local hasSelection = false
            for _, item in ipairs(AVAILABLE_ITEMS) do
                if selectedItems[item.Name] then hasSelection = true; break end
            end
            
            if not hasSelection then
                updateMailStatus("PILIH ITEM DULU!")
                isMailRunning = false
                return
            end
            
            mailToggle.Text = "⏸ BERHENTI MAIL"
            mailToggle.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            updateMailStatus("LANGSUNG KIRIM...")
            lastMailMinute = -1
            print("[Mail] ===== AUTO MAIL DIMULAI + LANGSUNG KIRIM =====")
            
            -- LANGSUNG SCAN & KIRIM SEKARANG!
            sendAllMail()
            
            if isMailRunning then
                updateMailStatus("AKTIF - Menunggu scan berikutnya")
            end
        else
            mailToggle.Text = "▶ MULAI MAIL (Langsung Kirim)"
            mailToggle.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
            updateMailStatus("BERHENTI")
            print("[Mail] ===== AUTO MAIL BERHENTI =====")
        end
    end)
    
    -- ============================================
    -- TOGGLE CLAIM - LANGSUNG SCAN SAAT ON
    -- ============================================
    claimToggle.MouseButton1Click:Connect(function()
        isClaimRunning = not isClaimRunning
        
        if isClaimRunning then
            claimToggle.Text = "⏸ BERHENTI CLAIM"
            claimToggle.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            updateClaimStatus("LANGSUNG SCAN...")
            lastClaimMinute = -1
            print("[Claim] ===== AUTO CLAIM DIMULAI + LANGSUNG SCAN =====")
            claimAllGifts()
            if isClaimRunning then
                updateClaimStatus("AKTIF - Menunggu scan berikutnya")
            end
        else
            claimToggle.Text = "▶ MULAI CLAIM (Langsung Scan)"
            claimToggle.BackgroundColor3 = Color3.fromRGB(0, 150, 200)
            updateClaimStatus("BERHENTI")
            print("[Claim] ===== AUTO CLAIM BERHENTI =====")
        end
    end)
    
    return screenGui
end

-- ============================================
-- UPDATE STOK DISPLAY
-- ============================================
local function updateStockDisplay()
    for _, item in ipairs(AVAILABLE_ITEMS) do
        local cb = checkboxes[item.Name]
        if cb and cb.stockLabel then
            local stock = getItemCount(item.Name)
            cb.stockLabel.Text = "Stok:" .. stock
            cb.stockLabel.TextColor3 = stock > 0 and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(120, 120, 130)
        end
    end
end

-- ============================================
-- MAIN LOOP
-- ============================================
spawn(function()
    createGUI()
    
    -- Default
    selectedItems["Dragon's Breath"] = true
    selectedItems["Super Sprinkler"] = true
    
    wait(0.5)
    updateCheckboxVisual("Dragon's Breath")
    updateCheckboxVisual("Super Sprinkler")
    updateStockDisplay()
    
    print("========================================")
    print(" AUTO MAIL & CLAIM v2")
    print(" Textbox jumlah: 0 = kirim semua stok")
    print(" Saat ON: LANGSUNG scan & kirim")
    print(" Ketik sendnow() untuk kirim manual")
    print("========================================")
    
    while true do
        wait(1)
        updateStockDisplay()
        
        if isMailRunning and isMailScanTime() then
            print("[Mail] SCAN: " .. os.date("%H:%M:%S"))
            updateMailStatus("Scanning...")
            scanAndSendMail()
            if isMailRunning then updateMailStatus("AKTIF - Menunggu scan") end
        end
        
        if isClaimRunning and isClaimScanTime() then
            print("[Claim] SCAN: " .. os.date("%H:%M:%S"))
            updateClaimStatus("Scanning...")
            claimAllGifts()
            if isClaimRunning then updateClaimStatus("AKTIF - Menunggu scan") end
        end
    end
end)

-- Commands
function sendnow()
    print("=================================")
    print(" KIRIM SEKARANG ke " .. targetUsername)
    print("=================================")
    sendAllMail()
end

function claimnow()
    local wasRunning = isClaimRunning
    isClaimRunning = true
    claimAllGifts()
    isClaimRunning = wasRunning
end

function status()
    print("=== STATUS ===")
    print("Mail: " .. (isMailRunning and "ON" or "OFF"))
    print("Claim: " .. (isClaimRunning and "ON" or "OFF"))
    print("Target: @" .. targetUsername)
    for _, item in ipairs(AVAILABLE_ITEMS) do
        local stock = getItemCount(item.Name)
        if selectedItems[item.Name] or stock > 0 then
            local count = tonumber(itemCounts[item.Name]) or 0
            local info = selectedItems[item.Name] and "✓" or " "
            local sendInfo = count == 0 and "ALL(" .. stock .. ")" or tostring(math.min(count, stock))
            print("  [" .. info .. "] " .. item.Name .. " | Stok:" .. stock .. " | Kirim:" .. sendInfo)
        end
    end
end
