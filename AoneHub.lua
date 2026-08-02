-- AUTO MAIL + AUTO CLAIM - GABUNGAN
-- Tab Mail: Scan menit 03, 08, 13... | Kirim stok item terpilih
-- Tab Claim: Scan menit 04, 09, 14... | Claim semua gift
-- Toggle terpisah, Claim langsung scan saat diaktifkan

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
-- DAFTAR ITEM UNTUK AUTO MAIL
-- ============================================
local AVAILABLE_ITEMS = {
    {Name = "Briar Rose", Category = "Seeds", DisplayName = "🌹 Briar Rose"},
    {Name = "Dragon's Breath", Category = "Seeds", DisplayName = "🐉 Dragon's Breath"},
    {Name = "Star Fruit", Category = "Seeds", DisplayName = "⭐ Star Fruit"},
    {Name = "Hypno Bloom", Category = "Seeds", DisplayName = "🌀 Hypno Bloom"},
    {Name = "Sun Bloom", Category = "Seeds", DisplayName = "☀️ Sun Bloom"},
    {Name = "Super Sprinkler", Category = "Sprinklers", DisplayName = "💦 Super Sprinkler"},
    {Name = "Super Watering Can", Category = "WateringCans", DisplayName = "🚿 Super Watering Can"},
}

local selectedItems = {}
local checkboxes = {}
local targetUsername = ""

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

-- ============================================
-- FUNGSI UPDATE STATUS
-- ============================================
local function updateMailStatus(msg)
    if mailStatusLabel then
        mailStatusLabel.Text = msg
    end
end

local function updateClaimStatus(msg)
    if claimStatusLabel then
        claimStatusLabel.Text = msg
    end
end

-- ============================================
-- FUNGSI ENCODE PANJANG
-- ============================================
local function encodeLength(len)
    if len < 10 then
        return "\00" .. tostring(len)
    elseif len < 20 then
        return "\0" .. tostring(len)
    else
        return "\v" .. string.char(len)
    end
end

-- ============================================
-- FUNGSI BUILD PACKET DATA (MAIL)
-- ============================================
local function buildPacketData(itemList)
    if #itemList == 0 then return nil end
    
    local itemEntries = {}
    
    for i, item in ipairs(itemList) do
        local entry = "\028\v\aItemKey\v"
        local nameLen = string.len(item.Name)
        entry = entry .. encodeLength(nameLen)
        entry = entry .. item.Name
        
        local count = item.Count
        if count < 10 then
            entry = entry .. "\v\005Count\005\00" .. tostring(count)
        else
            entry = entry .. "\v\005Count\005\0" .. tostring(count)
        end
        
        local catLen = string.len(item.Category)
        entry = entry .. "\v\bCategory\v"
        entry = entry .. encodeLength(catLen)
        entry = entry .. item.Category
        
        if i < #itemList then
            entry = entry .. "\000\005"
        end
        
        table.insert(itemEntries, entry)
    end
    
    return "]\001" .. table.concat(itemEntries) .. "\000\000\000"
end

-- ============================================
-- FUNGSI CEK STOK ITEM
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
-- FUNGSI DAPATKAN ITEM TERPILIH DENGAN STOK
-- ============================================
local function getSelectedItemsWithStock()
    local itemsWithStock = {}
    
    for _, item in ipairs(AVAILABLE_ITEMS) do
        if selectedItems[item.Name] then
            local stock = getItemCount(item.Name)
            if stock > 0 then
                table.insert(itemsWithStock, {
                    Name = item.Name,
                    Count = stock,
                    Category = item.Category
                })
            end
        end
    end
    
    return itemsWithStock
end

-- ============================================
-- FUNGSI KIRIM MAIL
-- ============================================
local function sendMail(itemsToSend)
    if #itemsToSend == 0 then return false end
    if targetUsername == "" then return false end
    
    local summaryParts = {}
    for _, item in ipairs(itemsToSend) do
        table.insert(summaryParts, item.Count .. "x " .. item.Name)
    end
    local summary = table.concat(summaryParts, ", ")
    
    print("[Mail] Mengirim: " .. summary .. " → " .. targetUsername)
    
    local success = false
    
    pcall(function()
        local remote = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")
        local packetData = buildPacketData(itemsToSend)
        
        if packetData then
            local args = {buffer.fromstring(packetData)}
            remote:FireServer(unpack(args))
            success = true
            print("[Mail] BERHASIL! " .. summary .. " → " .. targetUsername)
        end
    end)
    
    return success
end

-- ============================================
-- FUNGSI SCAN & KIRIM MAIL (DENGAN RETRY JITTER)
-- ============================================
local function scanAndSendMail()
    if not isMailRunning then return end
    if targetUsername == "" then return end
    
    print("[Mail] ===== SCANNING BACKPACK =====")
    
    local itemsToSend = getSelectedItemsWithStock()
    
    if #itemsToSend == 0 then
        print("[Mail] Tidak ada item terpilih di backpack")
        updateMailStatus("Stok kosong - Menunggu scan berikutnya")
        return
    end
    
    local sent = sendMail(itemsToSend)
    
    if not sent then
        updateMailStatus("Gagal mengirim!")
        return
    end
    
    -- Retry jika masih ada stok
    local retryCount = 0
    while isMailRunning do
        wait(math.random(21, 25))
        
        local remainingItems = getSelectedItemsWithStock()
        
        if #remainingItems == 0 then
            print("[Mail] Stok habis, menunggu scan berikutnya...")
            updateMailStatus("Stok habis - Menunggu scan berikutnya")
            break
        end
        
        retryCount = retryCount + 1
        print("[Mail] Masih ada stok! Retry #" .. retryCount)
        updateMailStatus("Retry #" .. retryCount .. " - Mengirim lagi...")
        sendMail(remainingItems)
    end
end

-- ============================================
-- FUNGSI CEK WAKTU SCAN MAIL (03, 08, 13, dst)
-- ============================================
local function isMailScanTime()
    local minutes = os.date("*t").min
    local seconds = os.date("*t").sec
    local targetMinute = minutes % 5 == 3
    local targetSecond = seconds >= 0 and seconds <= 2
    
    if targetMinute and targetSecond and lastMailMinute ~= minutes then
        lastMailMinute = minutes
        return true
    end
    
    return false
end

-- ============================================
-- FUNGSI GET RECEIVE FRAME
-- ============================================
local function getReceiveFrame()
    local success, result = pcall(function()
        local mailboxUI = player.PlayerGui:FindFirstChild("MailboxUI")
        if mailboxUI then
            local frame = mailboxUI:FindFirstChild("Frame")
            if frame then
                return frame:FindFirstChild("ReceiveFrame")
            end
        end
        return nil
    end)
    
    if success and result then
        return result
    end
    
    return nil
end

-- ============================================
-- FUNGSI SCAN GIFT FRAMES
-- ============================================
local function scanGiftFrames()
    local receiveFrame = getReceiveFrame()
    if not receiveFrame then return {} end
    
    local giftFrames = {}
    
    for _, child in ipairs(receiveFrame:GetChildren()) do
        if child:IsA("Frame") and string.find(child.Name, "Gift_4:") then
            local itemId = string.match(child.Name, "Gift_4:(.+)")
            if itemId and itemId ~= "" then
                table.insert(giftFrames, {
                    itemId = itemId,
                    name = child.Name
                })
            end
        end
    end
    
    return giftFrames
end

-- ============================================
-- FUNGSI CLAIM SATU GIFT
-- ============================================
local function claimGift(itemId)
    local success = false
    
    pcall(function()
        local remote = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")
        local packetData = "b\0014&4:" .. itemId
        local args = {buffer.fromstring(packetData)}
        remote:FireServer(unpack(args))
        success = true
    end)
    
    return success
end

-- ============================================
-- FUNGSI CLAIM SEMUA GIFT
-- ============================================
local function claimAllGifts()
    if not isClaimRunning then return end
    
    print("[Claim] ===== SCANNING GIFTS =====")
    
    local giftFrames = scanGiftFrames()
    
    if #giftFrames == 0 then
        print("[Claim] Tidak ada gift di ReceiveFrame")
        updateClaimStatus("Tidak ada gift")
        return
    end
    
    print("[Claim] Ditemukan " .. #giftFrames .. " gift!")
    updateClaimStatus("Claiming " .. #giftFrames .. " gifts...")
    
    local claimedCount = 0
    
    for i, gift in ipairs(giftFrames) do
        if not isClaimRunning then break end
        
        print("[Claim] Claim #" .. i .. ": " .. gift.itemId)
        
        local success = claimGift(gift.itemId)
        
        if success then
            claimedCount = claimedCount + 1
            print("[Claim] ✓ BERHASIL: " .. gift.itemId)
        else
            print("[Claim] ✗ GAGAL: " .. gift.itemId)
        end
        
        if i < #giftFrames and isClaimRunning then
            local jitter = math.random(10, 30) / 10
            wait(jitter)
        end
    end
    
    print("[Claim] ===== SELESAI: " .. claimedCount .. "/" .. #giftFrames .. " =====")
    updateClaimStatus("Selesai: " .. claimedCount .. "/" .. #giftFrames)
end

-- ============================================
-- FUNGSI CEK WAKTU SCAN CLAIM (04, 09, 14, dst)
-- ============================================
local function isClaimScanTime()
    local minutes = os.date("*t").min
    local seconds = os.date("*t").sec
    local targetMinute = minutes % 5 == 4
    local targetSecond = seconds >= 0 and seconds <= 2
    
    if targetMinute and targetSecond and lastClaimMinute ~= minutes then
        lastClaimMinute = minutes
        return true
    end
    
    return false
end

-- ============================================
-- FUNGSI UPDATE CHECKBOX VISUAL
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
-- BUILD GUI GABUNGAN (TAB MAIL + TAB CLAIM)
-- ============================================
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoMailClaim_GUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 290, 0, 440)
    mainFrame.Position = UDim2.new(0, 10, 0.5, -220)
    mainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    mainFrame.BackgroundTransparency = 0.05
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = mainFrame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 25)
    title.Position = UDim2.new(0, 10, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "📦📬 AUTO MAIL & CLAIM"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Parent = mainFrame
    
    -- Tab Bar Background
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -20, 0, 30)
    tabBar.Position = UDim2.new(0, 10, 0, 38)
    tabBar.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    tabBar.BorderSizePixel = 0
    tabBar.Parent = mainFrame
    
    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 6)
    tabCorner.Parent = tabBar
    
    -- Tab Mail Button
    local tabMailBtn = Instance.new("TextButton")
    tabMailBtn.Name = "TabMailBtn"
    tabMailBtn.Size = UDim2.new(0.5, -2, 1, -4)
    tabMailBtn.Position = UDim2.new(0, 2, 0, 2)
    tabMailBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 80)
    tabMailBtn.Text = "📦 MAIL"
    tabMailBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    tabMailBtn.Font = Enum.Font.GothamBold
    tabMailBtn.TextSize = 12
    tabMailBtn.BorderSizePixel = 0
    tabMailBtn.Parent = tabBar
    
    local tabMailCorner = Instance.new("UICorner")
    tabMailCorner.CornerRadius = UDim.new(0, 5)
    tabMailCorner.Parent = tabMailBtn
    
    -- Tab Claim Button
    local tabClaimBtn = Instance.new("TextButton")
    tabClaimBtn.Name = "TabClaimBtn"
    tabClaimBtn.Size = UDim2.new(0.5, -2, 1, -4)
    tabClaimBtn.Position = UDim2.new(0.5, 0, 0, 2)
    tabClaimBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    tabClaimBtn.Text = "📬 CLAIM"
    tabClaimBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    tabClaimBtn.Font = Enum.Font.GothamBold
    tabClaimBtn.TextSize = 12
    tabClaimBtn.BorderSizePixel = 0
    tabClaimBtn.Parent = tabBar
    
    local tabClaimCorner = Instance.new("UICorner")
    tabClaimCorner.CornerRadius = UDim.new(0, 5)
    tabClaimCorner.Parent = tabClaimBtn
    
    -- ============================================
    -- TAB MAIL CONTENT
    -- ============================================
    local mailContent = Instance.new("Frame")
    mailContent.Name = "MailContent"
    mailContent.Size = UDim2.new(1, -20, 0, 335)
    mailContent.Position = UDim2.new(0, 10, 0, 75)
    mailContent.BackgroundTransparency = 1
    mailContent.Visible = true
    mailContent.Parent = mainFrame
    
    -- Username Label
    local userLabel = Instance.new("TextLabel")
    userLabel.Size = UDim2.new(1, 0, 0, 16)
    userLabel.BackgroundTransparency = 1
    userLabel.Text = "Target Username:"
    userLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    userLabel.Font = Enum.Font.Gotham
    userLabel.TextSize = 10
    userLabel.TextXAlignment = Enum.TextXAlignment.Left
    userLabel.Parent = mailContent
    
    -- Username TextBox
    local userTextBox = Instance.new("TextBox")
    userTextBox.Name = "UserTextBox"
    userTextBox.Size = UDim2.new(1, 0, 0, 26)
    userTextBox.Position = UDim2.new(0, 0, 0, 18)
    userTextBox.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    userTextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    userTextBox.PlaceholderText = "Masukkan username..."
    userTextBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
    userTextBox.Font = Enum.Font.Gotham
    userTextBox.TextSize = 12
    userTextBox.Text = ""
    userTextBox.Parent = mailContent
    
    local userCorner = Instance.new("UICorner")
    userCorner.CornerRadius = UDim.new(0, 4)
    userCorner.Parent = userTextBox
    
    -- Items Label
    local itemsLabel = Instance.new("TextLabel")
    itemsLabel.Size = UDim2.new(1, 0, 0, 16)
    itemsLabel.Position = UDim2.new(0, 0, 0, 50)
    itemsLabel.BackgroundTransparency = 1
    itemsLabel.Text = "Pilih Item:"
    itemsLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    itemsLabel.Font = Enum.Font.Gotham
    itemsLabel.TextSize = 10
    itemsLabel.TextXAlignment = Enum.TextXAlignment.Left
    itemsLabel.Parent = mailContent
    
    -- Scrolling Frame
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, 0, 0, 200)
    scrollFrame.Position = UDim2.new(0, 0, 0, 68)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 36)
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 5
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 110)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #AVAILABLE_ITEMS * 30 + 8)
    scrollFrame.Parent = mailContent
    
    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0, 4)
    scrollCorner.Parent = scrollFrame
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 2)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scrollFrame
    
    -- Checkbox items
    for i, item in ipairs(AVAILABLE_ITEMS) do
        local itemFrame = Instance.new("Frame")
        itemFrame.Name = item.Name
        itemFrame.Size = UDim2.new(1, -8, 0, 26)
        itemFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
        itemFrame.BorderSizePixel = 0
        itemFrame.Parent = scrollFrame
        
        local itemCorner = Instance.new("UICorner")
        itemCorner.CornerRadius = UDim.new(0, 3)
        itemCorner.Parent = itemFrame
        
        local checkBtn = Instance.new("TextButton")
        checkBtn.Name = "CheckBtn"
        checkBtn.Size = UDim2.new(0, 20, 0, 20)
        checkBtn.Position = UDim2.new(0, 3, 0.5, -10)
        checkBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
        checkBtn.Text = ""
        checkBtn.BorderSizePixel = 0
        checkBtn.Parent = itemFrame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 3)
        btnCorner.Parent = checkBtn
        
        local checkMark = Instance.new("TextLabel")
        checkMark.Name = "CheckMark"
        checkMark.Size = UDim2.new(1, 0, 1, 0)
        checkMark.BackgroundTransparency = 1
        checkMark.Text = "✓"
        checkMark.TextColor3 = Color3.fromRGB(0, 255, 100)
        checkMark.Font = Enum.Font.GothamBold
        checkMark.TextSize = 13
        checkMark.Visible = false
        checkMark.Parent = checkBtn
        
        local itemLabel = Instance.new("TextLabel")
        itemLabel.Name = "ItemLabel"
        itemLabel.Size = UDim2.new(1, -30, 1, 0)
        itemLabel.Position = UDim2.new(0, 26, 0, 0)
        itemLabel.BackgroundTransparency = 1
        itemLabel.Text = item.DisplayName
        itemLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        itemLabel.Font = Enum.Font.Gotham
        itemLabel.TextSize = 11
        itemLabel.TextXAlignment = Enum.TextXAlignment.Left
        itemLabel.Parent = itemFrame
        
        checkboxes[item.Name] = {
            button = checkBtn,
            mark = checkMark,
            frame = itemFrame
        }
        
        local clickHandler = function()
            selectedItems[item.Name] = not selectedItems[item.Name]
            updateCheckboxVisual(item.Name)
        end
        
        checkBtn.MouseButton1Click:Connect(clickHandler)
        itemFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                clickHandler()
            end
        end)
    end
    
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #AVAILABLE_ITEMS * 30 + 8)
    
    -- Mail Status Label
    local mailStatus = Instance.new("TextLabel")
    mailStatus.Name = "MailStatus"
    mailStatus.Size = UDim2.new(1, 0, 0, 16)
    mailStatus.Position = UDim2.new(0, 0, 0, 274)
    mailStatus.BackgroundTransparency = 1
    mailStatus.Text = "Status: SIAP"
    mailStatus.TextColor3 = Color3.fromRGB(255, 200, 0)
    mailStatus.Font = Enum.Font.Gotham
    mailStatus.TextSize = 10
    mailStatus.TextXAlignment = Enum.TextXAlignment.Left
    mailStatus.Parent = mailContent
    
    mailStatusLabel = mailStatus
    
    -- Mail Toggle Button
    local mailToggle = Instance.new("TextButton")
    mailToggle.Name = "MailToggleBtn"
    mailToggle.Size = UDim2.new(1, 0, 0, 30)
    mailToggle.Position = UDim2.new(0, 0, 0, 295)
    mailToggle.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
    mailToggle.Text = "▶ MULAI MAIL"
    mailToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    mailToggle.Font = Enum.Font.GothamBold
    mailToggle.TextSize = 13
    mailToggle.BorderSizePixel = 0
    mailToggle.Parent = mailContent
    
    local mailToggleCorner = Instance.new("UICorner")
    mailToggleCorner.CornerRadius = UDim.new(0, 5)
    mailToggleCorner.Parent = mailToggle
    
    mailToggleBtn = mailToggle
    
    -- ============================================
    -- TAB CLAIM CONTENT
    -- ============================================
    local claimContent = Instance.new("Frame")
    claimContent.Name = "ClaimContent"
    claimContent.Size = UDim2.new(1, -20, 0, 335)
    claimContent.Position = UDim2.new(0, 10, 0, 75)
    claimContent.BackgroundTransparency = 1
    claimContent.Visible = false
    claimContent.Parent = mainFrame
    
    -- Claim Info
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
    
    -- Claim Status Label
    local claimStatus = Instance.new("TextLabel")
    claimStatus.Name = "ClaimStatus"
    claimStatus.Size = UDim2.new(1, 0, 0, 16)
    claimStatus.Position = UDim2.new(0, 0, 0, 260)
    claimStatus.BackgroundTransparency = 1
    claimStatus.Text = "Status: SIAP"
    claimStatus.TextColor3 = Color3.fromRGB(255, 200, 0)
    claimStatus.Font = Enum.Font.Gotham
    claimStatus.TextSize = 10
    claimStatus.TextXAlignment = Enum.TextXAlignment.Left
    claimStatus.Parent = claimContent
    
    claimStatusLabel = claimStatus
    
    -- Claim Toggle Button
    local claimToggle = Instance.new("TextButton")
    claimToggle.Name = "ClaimToggleBtn"
    claimToggle.Size = UDim2.new(1, 0, 0, 30)
    claimToggle.Position = UDim2.new(0, 0, 0, 285)
    claimToggle.BackgroundColor3 = Color3.fromRGB(0, 150, 200)
    claimToggle.Text = "▶ MULAI CLAIM"
    claimToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    claimToggle.Font = Enum.Font.GothamBold
    claimToggle.TextSize = 13
    claimToggle.BorderSizePixel = 0
    claimToggle.Parent = claimContent
    
    local claimToggleCorner = Instance.new("UICorner")
    claimToggleCorner.CornerRadius = UDim.new(0, 5)
    claimToggleCorner.Parent = claimToggle
    
    claimToggleBtn = claimToggle
    
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
    -- TOGGLE HANDLERS
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
                if selectedItems[item.Name] then
                    hasSelection = true
                    break
                end
            end
            
            if not hasSelection then
                updateMailStatus("PILIH ITEM DULU!")
                isMailRunning = false
                return
            end
            
            mailToggle.Text = "⏸ BERHENTI MAIL"
            mailToggle.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            updateMailStatus("AKTIF - Menunggu scan...")
            lastMailMinute = -1
            print("[Mail] ===== AUTO MAIL DIMULAI =====")
            print("[Mail] Target: " .. targetUsername)
        else
            mailToggle.Text = "▶ MULAI MAIL"
            mailToggle.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
            updateMailStatus("BERHENTI")
            print("[Mail] ===== AUTO MAIL BERHENTI =====")
        end
    end)
    
    claimToggle.MouseButton1Click:Connect(function()
        isClaimRunning = not isClaimRunning
        
        if isClaimRunning then
            claimToggle.Text = "⏸ BERHENTI CLAIM"
            claimToggle.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            updateClaimStatus("AKTIF - Scan & claim...")
            lastClaimMinute = -1
            print("[Claim] ===== AUTO CLAIM DIMULAI =====")
            
            -- LANGSUNG SCAN SEKALI SAAT DIAKTIFKAN
            print("[Claim] Scan awal saat diaktifkan...")
            claimAllGifts()
            
            if isClaimRunning then
                updateClaimStatus("AKTIF - Menunggu scan berikutnya")
            end
        else
            claimToggle.Text = "▶ MULAI CLAIM"
            claimToggle.BackgroundColor3 = Color3.fromRGB(0, 150, 200)
            updateClaimStatus("BERHENTI")
            print("[Claim] ===== AUTO CLAIM BERHENTI =====")
        end
    end)
    
    return screenGui
end

-- ============================================
-- MAIN LOOP
-- ============================================
spawn(function()
    createGUI()
    
    print("========================================")
    print(" AUTO MAIL & CLAIM - GABUNGAN")
    print(" Tab Mail: Scan menit 03, 08, 13...")
    print(" Tab Claim: Scan menit 04, 09, 14...")
    print(" Claim langsung scan saat toggle ON")
    print(" Toggle terpisah untuk masing-masing")
    print("========================================")
    
    while true do
        wait(1)
        
        -- Cek scan mail
        if isMailRunning and isMailScanTime() then
            local currentTime = os.date("%H:%M:%S")
            print("[Mail] ===== SCAN TIME: " .. currentTime .. " =====")
            updateMailStatus("Scanning... " .. currentTime)
            scanAndSendMail()
            if isMailRunning then
                updateMailStatus("AKTIF - Menunggu scan berikutnya")
            end
        end
        
        -- Cek scan claim
        if isClaimRunning and isClaimScanTime() then
            local currentTime = os.date("%H:%M:%S")
            print("[Claim] ===== SCAN TIME: " .. currentTime .. " =====")
            updateClaimStatus("Scanning... " .. currentTime)
            claimAllGifts()
            if isClaimRunning then
                updateClaimStatus("AKTIF - Menunggu scan berikutnya")
            end
        end
    end
end)
