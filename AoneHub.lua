-- AUTO MAIL & CLAIM - GUI LENGKAP
-- Tanpa perlu buka mailbox
-- Tab Mail + Tab Claim + Checklist + Toggle

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")

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
-- FUNGSI UPDATE STATUS
-- ============================================
local function updateMailStatus(msg, color)
    if mailStatusLabel then
        mailStatusLabel.Text = msg
        if color then
            mailStatusLabel.TextColor3 = color
        end
    end
end

local function updateClaimStatus(msg, color)
    if claimStatusLabel then
        claimStatusLabel.Text = msg
        if color then
            claimStatusLabel.TextColor3 = color
        end
    end
end

-- ============================================
-- FUNGSI CEK STOK
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
    if string.find(itemName, "Sprinkler") then
        return "Sprinklers"
    elseif string.find(itemName, "Watering") then
        return "WateringCans"
    else
        return "Seeds"
    end
end

-- ============================================
-- SET TARGET DI UI BACKGROUND
-- ============================================
local function setMailTarget(username)
    local targetText = "@" .. username
    local found = false
    
    pcall(function()
        local playerList = player.PlayerGui:FindFirstChild("MailboxUI")
        if playerList then playerList = playerList:FindFirstChild("Frame") end
        if playerList then playerList = playerList:FindFirstChild("SendingFrame") end
        if playerList then playerList = playerList:FindFirstChild("SendPlayerFrame") end
        if playerList then playerList = playerList:FindFirstChild("PlayerList") end
        
        if not playerList then return end
        
        for _, template in ipairs(playerList:GetChildren()) do
            if template:IsA("Frame") or template:IsA("GuiObject") then
                local button = template:FindFirstChild("Button")
                if button then
                    local usernameLabel = button:FindFirstChild("PlayerUsername")
                    if usernameLabel and usernameLabel:IsA("TextLabel") then
                        if usernameLabel.Text == targetText then
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
    
    return found
end

-- ============================================
-- ENCODE PANJANG
-- ============================================
local function encodeLen(len)
    if len < 10 then
        return "\00" .. tostring(len)
    elseif len < 20 then
        return "\0" .. tostring(len)
    else
        return "\v" .. string.char(len)
    end
end

-- ============================================
-- KIRIM SATU ITEM
-- ============================================
local function sendSingleItem(itemName, count, category)
    if count <= 0 then return false end
    
    local nameLen = string.len(itemName)
    local catLen = string.len(category)
    
    local countStr
    if count <= 9 then
        countStr = "\005\00" .. tostring(count)
    else
        countStr = "\005\0" .. tostring(count)
    end
    
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
        local args = {buffer.fromstring(packet)}
        remote:FireServer(unpack(args))
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
                table.insert(toSend, {
                    Name = item.Name,
                    Count = stock,
                    Category = item.Category
                })
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
        
        if ok then
            print("[Mail] ✓ " .. item.Name)
        else
            print("[Mail] ✗ " .. item.Name)
        end
        
        if #toSend > 1 then
            wait(math.random(1, 2))
        end
    end
    
    updateMailStatus("Terkirim! " .. #toSend .. " item", Color3.fromRGB(0, 255, 100))
    return true
end

-- ============================================
-- CLAIM FUNCTIONS
-- ============================================
local function getReceiveFrame()
    local success, result = pcall(function()
        return player.PlayerGui:FindFirstChild("MailboxUI")
            and player.PlayerGui.MailboxUI:FindFirstChild("Frame")
            and player.PlayerGui.MailboxUI.Frame:FindFirstChild("ReceiveFrame")
    end)
    if success then return result end
    return nil
end

local function scanGifts()
    local receiveFrame = getReceiveFrame()
    if not receiveFrame then return {} end
    
    local gifts = {}
    for _, child in ipairs(receiveFrame:GetChildren()) do
        if child:IsA("Frame") and string.find(child.Name, "Gift_4:") then
            local itemId = string.match(child.Name, "Gift_4:(.+)")
            if itemId then
                table.insert(gifts, itemId)
            end
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
            local args = {buffer.fromstring("b\0014&4:" .. giftId)}
            remote:FireServer(unpack(args))
        end)
        
        if i < #gifts and isClaimRunning then
            wait(math.random(10, 30) / 10)
        end
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
-- UPDATE CHECKBOX VISUAL
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
    
    -- Main Frame
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
    
    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 6)
    tabCorner.Parent = tabBar
    
    -- Tab Mail Button
    local tabMailBtn = Instance.new("TextButton")
    tabMailBtn.Name = "TabMail"
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
    tabClaimBtn.Name = "TabClaim"
    tabClaimBtn.Size = UDim2.new(0.5, -2, 1, -4)
    tabClaimBtn.Position = UDim2.new(0.5, 0, 0, 2)
    tabClaimBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    tabClaimBtn.Text = "📬 CLAIM"
    tabClaimBtn.TextColor3 = Color3.fromRGB(170, 170, 170)
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
    mailContent.Size = UDim2.new(1, -16, 0, 370)
    mailContent.Position = UDim2.new(0, 8, 0, 82)
    mailContent.BackgroundTransparency = 1
    mailContent.Visible = true
    mailContent.Parent = mainFrame
    
    -- Username Label
    local userLabel = Instance.new("TextLabel")
    userLabel.Size = UDim2.new(1, 0, 0, 16)
    userLabel.BackgroundTransparency = 1
    userLabel.Text = "🎯 Target Username:"
    userLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    userLabel.Font = Enum.Font.Gotham
    userLabel.TextSize = 10
    userLabel.TextXAlignment = Enum.TextXAlignment.Left
    userLabel.Parent = mailContent
    
    -- Username TextBox
    local userTextBoxLocal = Instance.new("TextBox")
    userTextBoxLocal.Name = "UserTextBox"
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
    
    local userCorner = Instance.new("UICorner")
    userCorner.CornerRadius = UDim.new(0, 5)
    userCorner.Parent = userTextBoxLocal
    
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
    
    -- Scrolling Frame
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, 0, 0, 195)
    scrollFrame.Position = UDim2.new(0, 0, 0, 70)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 33)
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 5
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 100)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #AVAILABLE_ITEMS * 32 + 10)
    scrollFrame.Parent = mailContent
    
    local scrollCorner = Instance.new("UICorner")
    scrollCorner.CornerRadius = UDim.new(0, 5)
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
        itemFrame.Size = UDim2.new(1, -8, 0, 28)
        itemFrame.BackgroundColor3 = Color3.fromRGB(42, 42, 48)
        itemFrame.BorderSizePixel = 0
        itemFrame.Parent = scrollFrame
        
        local itemCorner = Instance.new("UICorner")
        itemCorner.CornerRadius = UDim.new(0, 4)
        itemCorner.Parent = itemFrame
        
        local checkBtn = Instance.new("TextButton")
        checkBtn.Name = "CheckBtn"
        checkBtn.Size = UDim2.new(0, 20, 0, 20)
        checkBtn.Position = UDim2.new(0, 5, 0.5, -10)
        checkBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
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
        checkMark.TextSize = 14
        checkMark.Visible = false
        checkMark.Parent = checkBtn
        
        -- Stock label
        local stockLabel = Instance.new("TextLabel")
        stockLabel.Name = "StockLabel"
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
        itemLabel.Name = "ItemLabel"
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
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                clickHandler()
            end
        end)
    end
    
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #AVAILABLE_ITEMS * 32 + 10)
    
    -- Next scan label (Mail)
    local nextMailLabelLocal = Instance.new("TextLabel")
    nextMailLabelLocal.Size = UDim2.new(1, 0, 0, 14)
    nextMailLabelLocal.Position = UDim2.new(0, 0, 0, 270)
    nextMailLabelLocal.BackgroundTransparency = 1
    nextMailLabelLocal.Text = "⏰ Scan: menit 03, 08, 13..."
    nextMailLabelLocal.TextColor3 = Color3.fromRGB(140, 140, 150)
    nextMailLabelLocal.Font = Enum.Font.Gotham
    nextMailLabelLocal.TextSize = 9
    nextMailLabelLocal.TextXAlignment = Enum.TextXAlignment.Left
    nextMailLabelLocal.Parent = mailContent
    
    nextMailLabel = nextMailLabelLocal
    
    -- Mail Status Label
    local mailStatus = Instance.new("TextLabel")
    mailStatus.Name = "MailStatus"
    mailStatus.Size = UDim2.new(1, 0, 0, 16)
    mailStatus.Position = UDim2.new(0, 0, 0, 285)
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
    mailToggle.Name = "MailToggle"
    mailToggle.Size = UDim2.new(1, 0, 0, 32)
    mailToggle.Position = UDim2.new(0, 0, 0, 305)
    mailToggle.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
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
    claimContent.Size = UDim2.new(1, -16, 0, 370)
    claimContent.Position = UDim2.new(0, 8, 0, 82)
    claimContent.BackgroundTransparency = 1
    claimContent.Visible = false
    claimContent.Parent = mainFrame
    
    -- Claim Info
    local claimInfo = Instance.new("TextLabel")
    claimInfo.Size = UDim2.new(1, 0, 0, 120)
    claimInfo.Position = UDim2.new(0, 0, 0, 20)
    claimInfo.BackgroundTransparency = 1
    claimInfo.Text = "📬 Auto Claim Mailbox\n\n✅ Scan setiap menit 04, 09, 14...\n✅ Claim semua gift di ReceiveFrame\n✅ Jitter 1-3 detik antar claim\n✅ Tidak perlu buka mailbox\n✅ Claim langsung saat diaktifkan"
    claimInfo.TextColor3 = Color3.fromRGB(190, 190, 200)
    claimInfo.Font = Enum.Font.Gotham
    claimInfo.TextSize = 11
    claimInfo.TextXAlignment = Enum.TextXAlignment.Left
    claimInfo.TextWrapped = true
    claimInfo.Parent = claimContent
    
    -- Next scan label (Claim)
    local nextClaimLabelLocal = Instance.new("TextLabel")
    nextClaimLabelLocal.Size = UDim2.new(1, 0, 0, 14)
    nextClaimLabelLocal.Position = UDim2.new(0, 0, 0, 260)
    nextClaimLabelLocal.BackgroundTransparency = 1
    nextClaimLabelLocal.Text = "⏰ Scan: menit 04, 09, 14..."
    nextClaimLabelLocal.TextColor3 = Color3.fromRGB(140, 140, 150)
    nextClaimLabelLocal.Font = Enum.Font.Gotham
    nextClaimLabelLocal.TextSize = 9
    nextClaimLabelLocal.TextXAlignment = Enum.TextXAlignment.Left
    nextClaimLabelLocal.Parent = claimContent
    
    nextClaimLabel = nextClaimLabelLocal
    
    -- Claim Status Label
    local claimStatus = Instance.new("TextLabel")
    claimStatus.Name = "ClaimStatus"
    claimStatus.Size = UDim2.new(1, 0, 0, 16)
    claimStatus.Position = UDim2.new(0, 0, 0, 278)
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
    claimToggle.Name = "ClaimToggle"
    claimToggle.Size = UDim2.new(1, 0, 0, 32)
    claimToggle.Position = UDim2.new(0, 0, 0, 300)
    claimToggle.BackgroundColor3 = Color3.fromRGB(0, 140, 200)
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
    mailToggle.MouseButton1Click:Connect(function()
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
                if selectedItems[item.Name] then
                    hasSelection = true
                    break
                end
            end
            
            if not hasSelection then
                updateMailStatus("PILIH ITEM DULU!", Color3.fromRGB(255, 80, 80))
                isMailRunning = false
                return
            end
            
            mailToggle.Text = "⏸ BERHENTI MAIL"
            mailToggle.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            updateMailStatus("AKTIF - Menunggu scan...", Color3.fromRGB(0, 255, 100))
            lastMailMinute = -1
            print("[Mail] AUTO MAIL DIMULAI | Target: @" .. targetUsername)
        else
            mailToggle.Text = "▶ MULAI MAIL"
            mailToggle.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
            updateMailStatus("BERHENTI", Color3.fromRGB(255, 200, 0))
            print("[Mail] AUTO MAIL BERHENTI")
        end
    end)
    
    claimToggle.MouseButton1Click:Connect(function()
        isClaimRunning = not isClaimRunning
        
        if isClaimRunning then
            claimToggle.Text = "⏸ BERHENTI CLAIM"
            claimToggle.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            updateClaimStatus("AKTIF - Claiming...", Color3.fromRGB(0, 255, 100))
            lastClaimMinute = -1
            print("[Claim] AUTO CLAIM DIMULAI")
            
            -- Langsung claim
            claimAllGifts()
            
            if isClaimRunning then
                updateClaimStatus("AKTIF - Menunggu scan...", Color3.fromRGB(0, 255, 100))
            end
        else
            claimToggle.Text = "▶ MULAI CLAIM"
            claimToggle.BackgroundColor3 = Color3.fromRGB(0, 140, 200)
            updateClaimStatus("BERHENTI", Color3.fromRGB(255, 200, 0))
            print("[Claim] AUTO CLAIM BERHENTI")
        end
    end)
    
    return screenGui
end

-- ============================================
-- UPDATE STOK DI GUI
-- ============================================
local function updateStockDisplay()
    for _, item in ipairs(AVAILABLE_ITEMS) do
        local cb = checkboxes[item.Name]
        if cb and cb.stockLabel then
            local stock = getItemCount(item.Name)
            cb.stockLabel.Text = tostring(stock)
            if stock > 0 then
                cb.stockLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
            else
                cb.stockLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
            end
        end
    end
end

-- ============================================
-- UPDATE NEXT SCAN TIME
-- ============================================
local function updateNextScanLabel()
    local m = os.date("*t").min
    local s = os.date("*t").sec
    
    -- Next mail scan
    local nextMail = 3 - (m % 5)
    if nextMail <= 0 then nextMail = nextMail + 5 end
    if m % 5 == 3 and s > 2 then nextMail = 5 end
    local mailMinute = m + nextMail
    if mailMinute >= 60 then mailMinute = mailMinute - 60 end
    
    if nextMailLabel then
        nextMailLabel.Text = "⏰ Scan berikutnya: ±" .. nextMail .. " menit (menit ke-" .. mailMinute .. ")"
    end
    
    -- Next claim scan
    local nextClaim = 4 - (m % 5)
    if nextClaim <= 0 then nextClaim = nextClaim + 5 end
    if m % 5 == 4 and s > 2 then nextClaim = 5 end
    local claimMinute = m + nextClaim
    if claimMinute >= 60 then claimMinute = claimMinute - 60 end
    
    if nextClaimLabel then
        nextClaimLabel.Text = "⏰ Scan berikutnya: ±" .. nextClaim .. " menit (menit ke-" .. claimMinute .. ")"
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
    
    -- Update visuals
    wait(0.5)
    for _, item in ipairs(AVAILABLE_ITEMS) do
        updateCheckboxVisual(item.Name)
    end
    updateStockDisplay()
    updateNextScanLabel()
    
    print("========================================")
    print(" AUTO MAIL & CLAIM - GUI AKTIF")
    print(" Tab MAIL: Kirim item ke target")
    print(" Tab CLAIM: Claim gift dari mailbox")
    print(" TANPA perlu buka mailbox")
    print("========================================")
    
    while true do
        wait(1)
        
        -- Update display setiap detik
        updateStockDisplay()
        updateNextScanLabel()
        
        -- Cek scan mail
        if isMailRunning and isMailScanTime() then
            print("[Mail] SCAN TIME: " .. os.date("%H:%M:%S"))
            scanAndSend()
            if isMailRunning then
                updateMailStatus("AKTIF - Menunggu scan...", Color3.fromRGB(0, 255, 100))
            end
        end
        
        -- Cek scan claim
        if isClaimRunning and isClaimScanTime() then
            print("[Claim] SCAN TIME: " .. os.date("%H:%M:%S"))
            claimAllGifts()
            if isClaimRunning then
                updateClaimStatus("AKTIF - Menunggu scan...", Color3.fromRGB(0, 255, 100))
            end
        end
    end
end)
