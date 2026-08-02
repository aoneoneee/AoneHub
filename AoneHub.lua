-- AUTO MAIL & CLAIM - FINAL WORKING
-- Set target via REMOTE (bukan klik UI) + Kirim item + Claim

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local isMailRunning = false
local isClaimRunning = false
local lastMailMinute = -1
local lastClaimMinute = -1
local targetUsername = "aoneoneee"

-- ============================================
-- REMOTE
-- ============================================
local function getRemote()
    return ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")
end

-- ============================================
-- DAFTAR ITEM
-- ============================================
local AVAILABLE_ITEMS = {
    "Dragon's Breath",
    "Hypno Bloom",
    "Moon Bloom",
    "Briar Rose",
    "Star Fruit",
    "Sun Bloom",
    "Carrot",
    "Corn",
    "Super Sprinkler",
    "Rare Sprinkler",
    "Super Watering Can",
}

local selectedItems = {}
for _, name in ipairs(AVAILABLE_ITEMS) do
    selectedItems[name] = false
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
-- KATEGORI
-- ============================================
local function getCategory(itemName)
    if string.find(itemName, "Sprinkler") then return "Sprinklers"
    elseif string.find(itemName, "Watering") then return "WateringCans"
    else return "Seeds" end
end

-- ============================================
-- ENCODE
-- ============================================
local function encodeCount(count)
    if count <= 9 then return "\005\00" .. tostring(count) end
    -- Count > 9 pakai karakter khusus
    return "\005" .. string.char(count)
end

local function encodeLen(len)
    if len < 10 then return "\00" .. tostring(len)
    elseif len < 20 then return "\0" .. tostring(len)
    else return "\v" .. string.char(len) end
end

-- ============================================
-- SET TARGET VIA REMOTE (BUKAN KLIK UI!)
-- ============================================
local function setTargetRemote(username)
    -- Format: ^\001B\busername
    -- \b = panjang username (1 byte)
    local len = string.len(username)
    local packet = "^\001B"
    
    if len < 10 then
        packet = packet .. "\00" .. tostring(len)
    else
        packet = packet .. "\0" .. tostring(len)
    end
    
    packet = packet .. username
    
    print("[Mail] Set target: " .. username .. " (len=" .. len .. ")")
    
    local success = false
    pcall(function()
        getRemote():FireServer(buffer.fromstring(packet))
        success = true
    end)
    
    return success
end

-- ============================================
-- KIRIM ITEM VIA REMOTE
-- ============================================
local function sendItemRemote(itemName, count, category)
    if count <= 0 then return false end
    
    local nameLen = string.len(itemName)
    local catLen = string.len(category)
    
    -- Build packet sesuai format terbukti
    local packet = "]\001"
    -- Header (dari contoh yang berhasil)
    packet = packet .. "\031\000\000\176\187\006\175\001B\028\005\001"
    packet = packet .. "\028\v\aItemKey\v"
    packet = packet .. encodeLen(nameLen)
    packet = packet .. itemName
    packet = packet .. "\v\005Count" .. encodeCount(count)
    packet = packet .. "\v\bCategory\v"
    packet = packet .. encodeLen(catLen)
    packet = packet .. category
    packet = packet .. "\000\000\000"
    
    print("[Mail] Kirim: " .. count .. "x " .. itemName)
    
    local success = false
    pcall(function()
        getRemote():FireServer(buffer.fromstring(packet))
        success = true
    end)
    
    return success
end

-- ============================================
-- KIRIM SEMUA ITEM TERPILIH
-- ============================================
local function sendAllSelectedItems()
    -- STEP 1: Set target via REMOTE
    print("[Mail] === SET TARGET ===")
    local targetSet = setTargetRemote(targetUsername)
    if not targetSet then
        print("[Mail] GAGAL set target!")
        return false
    end
    
    wait(0.5)
    
    -- STEP 2: Scan stok
    local toSend = {}
    for _, itemName in ipairs(AVAILABLE_ITEMS) do
        if selectedItems[itemName] then
            local stock = getItemCount(itemName)
            if stock > 0 then
                table.insert(toSend, {
                    Name = itemName,
                    Count = stock,
                    Category = getCategory(itemName)
                })
            end
        end
    end
    
    if #toSend == 0 then
        print("[Mail] Stok kosong")
        return true
    end
    
    -- STEP 3: Kirim item satu per satu
    print("[Mail] === KIRIM " .. #toSend .. " ITEM ===")
    
    for _, item in ipairs(toSend) do
        local ok = sendItemRemote(item.Name, item.Count, item.Category)
        print(ok and "[Mail] ✓ " .. item.Name .. " x" .. item.Count or "[Mail] ✗ " .. item.Name)
        
        if #toSend > 1 then
            wait(math.random(1, 2))
        end
    end
    
    print("[Mail] === SELESAI ===")
    return true
end

-- ============================================
-- CLAIM (TETAP PAKAI REMOTE)
-- ============================================
local function scanGifts()
    local gifts = {}
    pcall(function()
        local receiveFrame = player.PlayerGui:FindFirstChild("MailboxUI")
        if receiveFrame then receiveFrame = receiveFrame:FindFirstChild("Frame") end
        if receiveFrame then receiveFrame = receiveFrame:FindFirstChild("ReceiveFrame") end
        if not receiveFrame then return end
        
        for _, child in ipairs(receiveFrame:GetChildren()) do
            if child:IsA("Frame") and string.find(child.Name, "Gift_4:") then
                local itemId = string.match(child.Name, "Gift_4:(.+)")
                if itemId then table.insert(gifts, itemId) end
            end
        end
    end)
    return gifts
end

local function claimAllGifts()
    if not isClaimRunning then return end
    
    print("[Claim] Scanning...")
    local gifts = scanGifts()
    
    if #gifts == 0 then
        print("[Claim] Tidak ada gift")
        return
    end
    
    print("[Claim] " .. #gifts .. " gift ditemukan")
    
    for i, giftId in ipairs(gifts) do
        if not isClaimRunning then break end
        pcall(function()
            getRemote():FireServer(buffer.fromstring("b\0014&4:" .. giftId))
        end)
        print("[Claim] #" .. i .. " ✓")
        if i < #gifts and isClaimRunning then
            wait(math.random(10, 30) / 10)
        end
    end
    
    print("[Claim] Selesai")
end

-- ============================================
-- SCAN & RETRY
-- ============================================
local function scanAndSend()
    if not isMailRunning then return end
    sendAllSelectedItems()
    
    -- Retry setelah jitter
    wait(math.random(21, 25))
    
    if isMailRunning then
        local hasStock = false
        for _, itemName in ipairs(AVAILABLE_ITEMS) do
            if selectedItems[itemName] and getItemCount(itemName) > 0 then
                hasStock = true
                break
            end
        end
        if hasStock then
            print("[Mail] Retry - stok masih ada")
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
-- SIMPLE GUI
-- ============================================
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoMailClaim_GUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 300, 0, 460)
    mainFrame.Position = UDim2.new(0, 10, 0.5, -230)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    mainFrame.BackgroundTransparency = 0.03
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
    
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
    tabClaimBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    tabClaimBtn.Text = "📬 CLAIM"
    tabClaimBtn.TextColor3 = Color3.fromRGB(170, 170, 170)
    tabClaimBtn.Font = Enum.Font.GothamBold
    tabClaimBtn.TextSize = 12
    tabClaimBtn.BorderSizePixel = 0
    tabClaimBtn.Parent = tabBar
    Instance.new("UICorner", tabClaimBtn).CornerRadius = UDim.new(0, 5)
    
    -- Mail Content
    local mailContent = Instance.new("Frame")
    mailContent.Size = UDim2.new(1, -16, 0, 370)
    mailContent.Position = UDim2.new(0, 8, 0, 82)
    mailContent.BackgroundTransparency = 1
    mailContent.Visible = true
    mailContent.Parent = mainFrame
    
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
    userTextBoxLocal.PlaceholderText = "Username..."
    userTextBoxLocal.PlaceholderColor3 = Color3.fromRGB(110, 110, 110)
    userTextBoxLocal.Font = Enum.Font.Gotham
    userTextBoxLocal.TextSize = 13
    userTextBoxLocal.Text = targetUsername
    userTextBoxLocal.Parent = mailContent
    Instance.new("UICorner", userTextBoxLocal).CornerRadius = UDim.new(0, 5)
    
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
    
    for i, itemName in ipairs(AVAILABLE_ITEMS) do
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
        
        local itemLabel = Instance.new("TextLabel")
        itemLabel.Size = UDim2.new(1, -30, 1, 0)
        itemLabel.Position = UDim2.new(0, 28, 0, 0)
        itemLabel.BackgroundTransparency = 1
        itemLabel.Text = itemName
        itemLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        itemLabel.Font = Enum.Font.Gotham
        itemLabel.TextSize = 11
        itemLabel.TextXAlignment = Enum.TextXAlignment.Left
        itemLabel.Parent = itemFrame
        
        local clickHandler = function()
            selectedItems[itemName] = not selectedItems[itemName]
            if selectedItems[itemName] then
                checkBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 80)
                checkMark.Visible = true
                itemFrame.BackgroundColor3 = Color3.fromRGB(40, 60, 45)
            else
                checkBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
                checkMark.Visible = false
                itemFrame.BackgroundColor3 = Color3.fromRGB(42, 42, 48)
            end
        end
        
        checkBtn.MouseButton1Click:Connect(clickHandler)
        itemFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then clickHandler() end
        end)
    end
    
    local mailStatus = Instance.new("TextLabel")
    mailStatus.Size = UDim2.new(1, 0, 0, 16)
    mailStatus.Position = UDim2.new(0, 0, 0, 275)
    mailStatus.BackgroundTransparency = 1
    mailStatus.Text = "Status: SIAP - Set target via REMOTE"
    mailStatus.TextColor3 = Color3.fromRGB(255, 200, 0)
    mailStatus.Font = Enum.Font.Gotham
    mailStatus.TextSize = 9
    mailStatus.TextXAlignment = Enum.TextXAlignment.Left
    mailStatus.Parent = mailContent
    
    local mailToggle = Instance.new("TextButton")
    mailToggle.Size = UDim2.new(1, 0, 0, 32)
    mailToggle.Position = UDim2.new(0, 0, 0, 298)
    mailToggle.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
    mailToggle.Text = "▶ MULAI MAIL"
    mailToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    mailToggle.Font = Enum.Font.GothamBold
    mailToggle.TextSize = 13
    mailToggle.BorderSizePixel = 0
    mailToggle.Parent = mailContent
    Instance.new("UICorner", mailToggle).CornerRadius = UDim.new(0, 5)
    
    -- Claim Content
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
    claimInfo.Text = "📬 Auto Claim Mailbox\n\n✅ Scan tiap menit 04, 09, 14...\n✅ Claim semua gift di ReceiveFrame\n✅ Jitter 1-3 detik\n✅ Tidak perlu buka mailbox\n✅ Claim langsung saat ON"
    claimInfo.TextColor3 = Color3.fromRGB(190, 190, 200)
    claimInfo.Font = Enum.Font.Gotham
    claimInfo.TextSize = 11
    claimInfo.TextXAlignment = Enum.TextXAlignment.Left
    claimInfo.TextWrapped = true
    claimInfo.Parent = claimContent
    
    local claimStatus = Instance.new("TextLabel")
    claimStatus.Size = UDim2.new(1, 0, 0, 16)
    claimStatus.Position = UDim2.new(0, 0, 0, 280)
    claimStatus.BackgroundTransparency = 1
    claimStatus.Text = "Status: SIAP"
    claimStatus.TextColor3 = Color3.fromRGB(255, 200, 0)
    claimStatus.Font = Enum.Font.Gotham
    claimStatus.TextSize = 10
    claimStatus.TextXAlignment = Enum.TextXAlignment.Left
    claimStatus.Parent = claimContent
    
    local claimToggle = Instance.new("TextButton")
    claimToggle.Size = UDim2.new(1, 0, 0, 32)
    claimToggle.Position = UDim2.new(0, 0, 0, 302)
    claimToggle.BackgroundColor3 = Color3.fromRGB(0, 140, 200)
    claimToggle.Text = "▶ MULAI CLAIM"
    claimToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    claimToggle.Font = Enum.Font.GothamBold
    claimToggle.TextSize = 13
    claimToggle.BorderSizePixel = 0
    claimToggle.Parent = claimContent
    Instance.new("UICorner", claimToggle).CornerRadius = UDim.new(0, 5)
    
    -- Tab switching
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
    
    -- Toggle handlers
    mailToggle.MouseButton1Click:Connect(function()
        isMailRunning = not isMailRunning
        if isMailRunning then
            targetUsername = userTextBoxLocal.Text
            if targetUsername == "" then
                mailStatus.Text = "ISI USERNAME DULU!"
                isMailRunning = false
                return
            end
            mailToggle.Text = "⏸ BERHENTI MAIL"
            mailToggle.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            mailStatus.Text = "AKTIF - Menunggu scan..."
            mailStatus.TextColor3 = Color3.fromRGB(0, 255, 100)
            lastMailMinute = -1
        else
            mailToggle.Text = "▶ MULAI MAIL"
            mailToggle.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
            mailStatus.Text = "BERHENTI"
            mailStatus.TextColor3 = Color3.fromRGB(255, 200, 0)
        end
    end)
    
    claimToggle.MouseButton1Click:Connect(function()
        isClaimRunning = not isClaimRunning
        if isClaimRunning then
            claimToggle.Text = "⏸ BERHENTI CLAIM"
            claimToggle.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            claimStatus.Text = "AKTIF - Claiming..."
            claimStatus.TextColor3 = Color3.fromRGB(0, 255, 100)
            lastClaimMinute = -1
            claimAllGifts()
        else
            claimToggle.Text = "▶ MULAI CLAIM"
            claimToggle.BackgroundColor3 = Color3.fromRGB(0, 140, 200)
            claimStatus.Text = "BERHENTI"
            claimStatus.TextColor3 = Color3.fromRGB(255, 200, 0)
        end
    end)
end

-- ============================================
-- MAIN LOOP
-- ============================================
spawn(function()
    createGUI()
    
    selectedItems["Dragon's Breath"] = true
    selectedItems["Super Sprinkler"] = true
    
    print("========================================")
    print(" AUTO MAIL & CLAIM - FINAL")
    print(" Target: @" .. targetUsername)
    print(" Set target via REMOTE (bukan UI)")
    print("========================================")
    print(" ")
    print("Commands: sendnow(), claimnow(), status()")
    print(" ")
    
    while true do
        wait(1)
        
        if isMailRunning and isMailScanTime() then
            print("[Mail] SCAN: " .. os.date("%H:%M:%S"))
            scanAndSend()
        end
        
        if isClaimRunning and isClaimScanTime() then
            print("[Claim] SCAN: " .. os.date("%H:%M:%S"))
            claimAllGifts()
        end
    end
end)

function sendnow() scanAndSend() end
function claimnow() claimAllGifts() end
function status()
    print("=== STATUS ===")
    print("Mail: " .. (isMailRunning and "ON" or "OFF"))
    print("Claim: " .. (isClaimRunning and "ON" or "OFF"))
    print("Target: @" .. targetUsername)
    for _, name in ipairs(AVAILABLE_ITEMS) do
        if selectedItems[name] then
            print("  ✓ " .. name .. ": " .. getItemCount(name))
        end
    end
end
