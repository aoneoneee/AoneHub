-- AUTO MAIL & CLAIM - FINAL WORKING
-- Format buffer TERBUKTI berhasil

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local isMailRunning = false
local isClaimRunning = false
local lastMailMinute = -1
local lastClaimMinute = -1
local targetUsername = "aoneoneee"

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
function getItemCount(itemName)
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
function getCategory(itemName)
    if string.find(itemName, "Sprinkler") then return "Sprinklers"
    elseif string.find(itemName, "Watering") then return "WateringCans"
    else return "Seeds" end
end

-- ============================================
-- ENCODE COUNT (sesuai format terbukti)
-- ============================================
function encodeCount(count)
    if count <= 9 then
        return "\005\00" .. tostring(count)
    else
        -- 10+ pakai karakter khusus
        return "\005" .. string.char(count)
    end
end

-- ============================================
-- ENCODE PANJANG NAMA
-- ============================================
function encodeLen(len)
    if len < 10 then
        return "\00" .. tostring(len)
    elseif len < 20 then
        return "\0" .. tostring(len)
    else
        return "\v" .. string.char(len)
    end
end

-- ============================================
-- ENCODE USERNAME LENGTH (untuk set target)
-- ============================================
function encodeUsernameLen(len)
    if len < 10 then
        return "\00" .. tostring(len)
    else
        return "\0" .. tostring(len)
    end
end

-- ============================================
-- SET TARGET (pakai remote TERBUKTI)
-- ============================================
function setTargetRemote(username)
    local len = string.len(username)
    
    -- Format: ^\001b\?username
    local packet = "^\001b" .. encodeUsernameLen(len) .. username
    
    print("[Mail] Set target: " .. username .. " (len=" .. len .. ")")
    
    local success = false
    pcall(function()
        getRemote():FireServer(buffer.fromstring(packet))
        success = true
    end)
    
    return success
end

-- ============================================
-- KIRIM ITEM (pakai header TERBUKTI)
-- ============================================
function sendItemRemote(itemName, count, category)
    if count <= 0 then return false end
    
    local nameLen = string.len(itemName)
    local catLen = string.len(category)
    
    -- Pakai header yang terbukti: ]\001c\000\000\000<y%\166A
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
function sendAllSelectedItems()
    -- Step 1: Set target
    print("[Mail] === SET TARGET ===")
    local targetSet = setTargetRemote(targetUsername)
    if not targetSet then
        print("[Mail] GAGAL set target!")
        return false
    end
    
    wait(0.5)
    
    -- Step 2: Scan stok
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
    
    -- Step 3: Kirim item satu per satu
    print("[Mail] === KIRIM " .. #toSend .. " ITEM ===")
    
    for _, item in ipairs(toSend) do
        local ok = sendItemRemote(item.Name, item.Count, item.Category)
        
        if ok then
            print("[Mail] ✓ " .. item.Name .. " x" .. item.Count)
        else
            print("[Mail] ✗ " .. item.Name)
        end
        
        -- Jeda antar item
        if #toSend > 1 then
            wait(math.random(1, 2))
        end
    end
    
    print("[Mail] === SELESAI ===")
    return true
end

-- ============================================
-- CLAIM FUNCTIONS
-- ============================================
function scanGifts()
    local gifts = {}
    pcall(function()
        local rf = player.PlayerGui:FindFirstChild("MailboxUI")
        if rf then rf = rf:FindFirstChild("Frame") end
        if rf then rf = rf:FindFirstChild("ReceiveFrame") end
        if rf then
            for _, c in ipairs(rf:GetChildren()) do
                if c:IsA("Frame") and string.find(c.Name, "Gift_4:") then
                    local id = string.match(c.Name, "Gift_4:(.+)")
                    if id then table.insert(gifts, id) end
                end
            end
        end
    end)
    return gifts
end

function claimAllGifts()
    if not isClaimRunning then return end
    
    print("[Claim] Scan...")
    local gifts = scanGifts()
    
    if #gifts == 0 then
        print("[Claim] Tidak ada gift")
        return
    end
    
    print("[Claim] " .. #gifts .. " gift")
    
    for i, id in ipairs(gifts) do
        if not isClaimRunning then break end
        pcall(function()
            getRemote():FireServer(buffer.fromstring("b\0014&4:" .. id))
        end)
        print("[Claim] #" .. i .. " ✓")
        if i < #gifts then
            wait(math.random(10, 30) / 10)
        end
    end
    
    print("[Claim] Selesai")
end

-- ============================================
-- SCAN & RETRY
-- ============================================
function scanAndSend()
    if not isMailRunning then return end
    
    sendAllSelectedItems()
    
    -- Retry setelah jitter
    wait(math.random(21, 25))
    
    if isMailRunning then
        local hasStock = false
        for _, name in ipairs(AVAILABLE_ITEMS) do
            if selectedItems[name] and getItemCount(name) > 0 then
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
function isMailScanTime()
    local m = os.date("*t").min
    local s = os.date("*t").sec
    if m % 5 == 3 and s <= 2 and lastMailMinute ~= m then
        lastMailMinute = m
        return true
    end
    return false
end

function isClaimScanTime()
    local m = os.date("*t").min
    local s = os.date("*t").sec
    if m % 5 == 4 and s <= 2 and lastClaimMinute ~= m then
        lastClaimMinute = m
        return true
    end
    return false
end

-- ============================================
-- GUI
-- ============================================
local function createGUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "AutoMail_GUI"
    sg.ResetOnSpawn = false
    sg.Parent = player:WaitForChild("PlayerGui")
    
    local mf = Instance.new("Frame")
    mf.Size = UDim2.new(0, 290, 0, 420)
    mf.Position = UDim2.new(0, 10, 0.5, -210)
    mf.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    mf.BackgroundTransparency = 0.03
    mf.BorderSizePixel = 0
    mf.Active = true
    mf.Draggable = true
    mf.Parent = sg
    Instance.new("UICorner", mf).CornerRadius = UDim.new(0, 10)
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 25)
    title.Position = UDim2.new(0, 0, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "📦📬 AUTO MAIL & CLAIM"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = mf
    
    -- Target Label
    local ul = Instance.new("TextLabel")
    ul.Size = UDim2.new(1, -20, 0, 14)
    ul.Position = UDim2.new(0, 10, 0, 40)
    ul.BackgroundTransparency = 1
    ul.Text = "🎯 Target Username:"
    ul.TextColor3 = Color3.fromRGB(180, 180, 180)
    ul.Font = Enum.Font.Gotham
    ul.TextSize = 10
    ul.TextXAlignment = Enum.TextXAlignment.Left
    ul.Parent = mf
    
    -- Target TextBox
    local ut = Instance.new("TextBox")
    ut.Size = UDim2.new(1, -20, 0, 26)
    ut.Position = UDim2.new(0, 10, 0, 56)
    ut.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    ut.TextColor3 = Color3.fromRGB(255, 255, 255)
    ut.PlaceholderText = "Username..."
    ut.PlaceholderColor3 = Color3.fromRGB(110, 110, 110)
    ut.Font = Enum.Font.Gotham
    ut.TextSize = 12
    ut.Text = targetUsername
    ut.Parent = mf
    Instance.new("UICorner", ut).CornerRadius = UDim.new(0, 5)
    
    -- Items Label
    local il = Instance.new("TextLabel")
    il.Size = UDim2.new(1, -20, 0, 14)
    il.Position = UDim2.new(0, 10, 0, 88)
    il.BackgroundTransparency = 1
    il.Text = "📋 Pilih Item:"
    il.TextColor3 = Color3.fromRGB(180, 180, 180)
    il.Font = Enum.Font.Gotham
    il.TextSize = 10
    il.TextXAlignment = Enum.TextXAlignment.Left
    il.Parent = mf
    
    -- ScrollFrame
    local sf = Instance.new("ScrollingFrame")
    sf.Size = UDim2.new(1, -10, 0, 200)
    sf.Position = UDim2.new(0, 5, 0, 104)
    sf.BackgroundColor3 = Color3.fromRGB(28, 28, 33)
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 5
    sf.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 100)
    sf.CanvasSize = UDim2.new(0, 0, 0, #AVAILABLE_ITEMS * 30 + 8)
    sf.Parent = mf
    Instance.new("UICorner", sf).CornerRadius = UDim.new(0, 5)
    
    local ly = Instance.new("UIListLayout")
    ly.Padding = UDim.new(0, 2)
    ly.HorizontalAlignment = Enum.HorizontalAlignment.Center
    ly.Parent = sf
    
    -- Checkbox items
    for i, name in ipairs(AVAILABLE_ITEMS) do
        local fr = Instance.new("Frame")
        fr.Size = UDim2.new(1, -8, 0, 26)
        fr.BackgroundColor3 = Color3.fromRGB(42, 42, 48)
        fr.BorderSizePixel = 0
        fr.Parent = sf
        Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 4)
        
        local cb = Instance.new("TextButton")
        cb.Size = UDim2.new(0, 18, 0, 18)
        cb.Position = UDim2.new(0, 4, 0.5, -9)
        cb.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
        cb.Text = ""
        cb.BorderSizePixel = 0
        cb.Parent = fr
        Instance.new("UICorner", cb).CornerRadius = UDim.new(0, 3)
        
        local cm = Instance.new("TextLabel")
        cm.Size = UDim2.new(1, 0, 1, 0)
        cm.BackgroundTransparency = 1
        cm.Text = "✓"
        cm.TextColor3 = Color3.fromRGB(0, 255, 100)
        cm.Font = Enum.Font.GothamBold
        cm.TextSize = 13
        cm.Visible = false
        cm.Parent = cb
        
        local lb = Instance.new("TextLabel")
        lb.Size = UDim2.new(1, -28, 1, 0)
        lb.Position = UDim2.new(0, 26, 0, 0)
        lb.BackgroundTransparency = 1
        lb.Text = name
        lb.TextColor3 = Color3.fromRGB(220, 220, 220)
        lb.Font = Enum.Font.Gotham
        lb.TextSize = 10
        lb.TextXAlignment = Enum.TextXAlignment.Left
        lb.Parent = fr
        
        local function ch()
            selectedItems[name] = not selectedItems[name]
            if selectedItems[name] then
                cb.BackgroundColor3 = Color3.fromRGB(0, 160, 80)
                cm.Visible = true
                fr.BackgroundColor3 = Color3.fromRGB(40, 60, 45)
            else
                cb.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
                cm.Visible = false
                fr.BackgroundColor3 = Color3.fromRGB(42, 42, 48)
            end
        end
        
        cb.MouseButton1Click:Connect(ch)
        fr.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 then ch() end
        end)
    end
    
    -- Status
    local st = Instance.new("TextLabel")
    st.Size = UDim2.new(1, -20, 0, 14)
    st.Position = UDim2.new(0, 10, 0, 312)
    st.BackgroundTransparency = 1
    st.Text = "Status: SIAP - Kirim via REMOTE"
    st.TextColor3 = Color3.fromRGB(255, 200, 0)
    st.Font = Enum.Font.Gotham
    st.TextSize = 9
    st.TextXAlignment = Enum.TextXAlignment.Left
    st.Parent = mf
    
    -- Toggle Mail
    local tm = Instance.new("TextButton")
    tm.Size = UDim2.new(1, -20, 0, 30)
    tm.Position = UDim2.new(0, 10, 0, 332)
    tm.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
    tm.Text = "▶ MULAI MAIL"
    tm.TextColor3 = Color3.fromRGB(255, 255, 255)
    tm.Font = Enum.Font.GothamBold
    tm.TextSize = 12
    tm.BorderSizePixel = 0
    tm.Parent = mf
    Instance.new("UICorner", tm).CornerRadius = UDim.new(0, 5)
    
    -- Toggle Claim
    local tc = Instance.new("TextButton")
    tc.Size = UDim2.new(1, -20, 0, 30)
    tc.Position = UDim2.new(0, 10, 0, 370)
    tc.BackgroundColor3 = Color3.fromRGB(0, 140, 200)
    tc.Text = "▶ MULAI CLAIM"
    tc.TextColor3 = Color3.fromRGB(255, 255, 255)
    tc.Font = Enum.Font.GothamBold
    tc.TextSize = 12
    tc.BorderSizePixel = 0
    tc.Parent = mf
    Instance.new("UICorner", tc).CornerRadius = UDim.new(0, 5)
    
    -- Toggle handlers
    tm.MouseButton1Click:Connect(function()
        isMailRunning = not isMailRunning
        if isMailRunning then
            targetUsername = ut.Text
            if targetUsername == "" then
                st.Text = "ISI USERNAME DULU!"
                isMailRunning = false
                return
            end
            tm.Text = "⏸ BERHENTI MAIL"
            tm.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            st.Text = "AKTIF - Menunggu scan..."
            st.TextColor3 = Color3.fromRGB(0, 255, 100)
            lastMailMinute = -1
        else
            tm.Text = "▶ MULAI MAIL"
            tm.BackgroundColor3 = Color3.fromRGB(0, 170, 80)
            st.Text = "BERHENTI"
            st.TextColor3 = Color3.fromRGB(255, 200, 0)
        end
    end)
    
    tc.MouseButton1Click:Connect(function()
        isClaimRunning = not isClaimRunning
        if isClaimRunning then
            tc.Text = "⏸ BERHENTI CLAIM"
            tc.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            st.Text = "CLAIM AKTIF"
            st.TextColor3 = Color3.fromRGB(0, 255, 100)
            lastClaimMinute = -1
            claimAllGifts()
        else
            tc.Text = "▶ MULAI CLAIM"
            tc.BackgroundColor3 = Color3.fromRGB(0, 140, 200)
            st.Text = "BERHENTI"
            st.TextColor3 = Color3.fromRGB(255, 200, 0)
        end
    end)
end

-- ============================================
-- MAIN LOOP
-- ============================================
spawn(function()
    createGUI()
    
    -- Default selection
    selectedItems["Dragon's Breath"] = true
    selectedItems["Super Sprinkler"] = true
    
    print("========================================")
    print(" AUTO MAIL & CLAIM - WORKING")
    print(" Target: @" .. targetUsername)
    print(" Format: Remote terbukti berhasil")
    print("========================================")
    print(" ")
    print("Commands:")
    print("  sendnow()  - Kirim sekarang")
    print("  claimnow() - Claim sekarang")
    print("  status()   - Cek status")
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

-- Global functions
function sendnow()
    print("[Mail] Kirim sekarang ke " .. targetUsername)
    sendAllSelectedItems()
end

function claimnow()
    print("[Claim] Claim sekarang")
    claimAllGifts()
end

function status()
    print("=== STATUS ===")
    print("Mail: " .. (isMailRunning and "ON" or "OFF"))
    print("Claim: " .. (isClaimRunning and "ON" or "OFF"))
    print("Target: @" .. targetUsername)
    print("Item dipilih:")
    for _, name in ipairs(AVAILABLE_ITEMS) do
        if selectedItems[name] then
            print("  ✓ " .. name .. ": " .. getItemCount(name))
        end
    end
    print("==============")
end
