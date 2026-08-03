-- AUTO MAIL - GUI TEST (STOK DARI ATRIBUT COUNT)
-- Stok: Players>USN>Backpack>NamaItem (Count = jumlah)
local player = game:GetService("Players").LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")

local isRunning = false
local lastScanMinute = -1

-- ============================================
-- DATA ITEM PER KATEGORI
-- ============================================
local CATEGORIES = {
    {
        Name = "Seeds",
        Items = {
            "Dragon's Breath",
            "Hypno Bloom",
            "Moon Bloom",
            "Briar Rose",
            "Star Fruit",
            "Sun Bloom",
            "Carrot",
            "Corn",
            "Pineapple",
        }
    },
    {
        Name = "Sprinklers",
        Items = {
            "Super Sprinkler",
            "Rare Sprinkler",
        }
    },
    {
        Name = "WateringCans",
        Items = {
            "Super Watering Can",
            "Common Watering Can",
        }
    },
}

local selectedCategory = "Seeds"
local selectedItems = {}
local allItems = {}

for _, cat in ipairs(CATEGORIES) do
    for _, itemName in ipairs(cat.Items) do
        selectedItems[itemName] = false
        table.insert(allItems, itemName)
    end
end

-- ============================================
-- FUNGSI CEK STOK (DARI ATRIBUT COUNT)
-- ============================================
local function getItemCount(itemName)
    local total = 0
    
    -- Cek di Backpack
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        local tool = backpack:FindFirstChild(itemName)
        if tool and tool:IsA("Tool") then
            -- Cek atribut Count
            local count = tool:GetAttribute("Count")
            if count and type(count) == "number" then
                total = total + count
            else
                -- Fallback: kalau tidak ada atribut, anggap 1
                total = total + 1
            end
        end
    end
    
    -- Cek di Character (item yang sedang dipegang)
    local character = player.Character
    if character then
        local tool = character:FindFirstChild(itemName)
        if tool and tool:IsA("Tool") then
            local count = tool:GetAttribute("Count")
            if count and type(count) == "number" then
                total = total + count
            else
                total = total + 1
            end
        end
    end
    
    return total
end

-- ============================================
-- FUNGSI ENCODE
-- ============================================
local function encodeLen(len)
    if len < 10 then return "\00" .. tostring(len)
    elseif len < 20 then return "\0" .. tostring(len)
    else return "\v" .. string.char(len) end
end

local function encodeCount(count)
    if count <= 9 then return "\005\00" .. tostring(count)
    else return "\005" .. string.char(count) end
end

-- ============================================
-- SET TARGET (FORMAT TERBUKTI)
-- ============================================
local function setTarget(username)
    local len = string.len(username)
    local lenStr
    
    if len < 10 then
        lenStr = "\00" .. tostring(len)
    else
        lenStr = "\0" .. tostring(len)
    end
    
    local packet = "^\001b" .. lenStr .. username
    
    print("[Mail] Set target: " .. username)
    
    local success = false
    pcall(function()
        remote:FireServer(buffer.fromstring(packet))
        success = true
    end)
    return success
end

-- ============================================
-- KIRIM ITEM (FORMAT TERBUKTI)
-- ============================================
local function sendItem(itemName, count, category)
    if count <= 0 then return false end
    
    local nameLen = string.len(itemName)
    local catLen = string.len(category)
    
    local packet = "]\001c\000\000\000<y%\166A\028\005\001"
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
        remote:FireServer(buffer.fromstring(packet))
        success = true
    end)
    return success
end

-- ============================================
-- KIRIM ITEM TERPILIH
-- ============================================
local function sendSelectedItems(username, manualCount)
    if not username or username == "" then
        print("[Mail] Username kosong!")
        return false
    end
    
    if not setTarget(username) then
        print("[Mail] GAGAL set target!")
        return false
    end
    wait(0.3)
    
    local toSend = {}
    for itemName, selected in pairs(selectedItems) do
        if selected then
            local stock = getItemCount(itemName)
            local count = (manualCount and manualCount > 0) and math.min(manualCount, stock) or stock
            
            if count > 0 then
                local cat = "Seeds"
                for _, c in ipairs(CATEGORIES) do
                    for _, n in ipairs(c.Items) do
                        if n == itemName then cat = c.Name; break end
                    end
                end
                
                table.insert(toSend, {Name = itemName, Count = count, Category = cat})
            end
        end
    end
    
    if #toSend == 0 then
        print("[Mail] Tidak ada item terpilih dengan stok!")
        return false
    end
    
    print("[Mail] ===== KIRIM " .. #toSend .. " ITEM =====")
    
    for _, item in ipairs(toSend) do
        local ok = sendItem(item.Name, item.Count, item.Category)
        print(ok and "[Mail] ✓ " .. item.Name .. " x" .. item.Count or "[Mail] ✗ " .. item.Name)
        if #toSend > 1 then wait(math.random(1, 2)) end
    end
    
    print("[Mail] ===== SELESAI =====")
    return true
end

-- ============================================
-- BUILD GUI
-- ============================================
local function createGUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "AutoMail_Test"
    sg.ResetOnSpawn = false
    sg.Parent = player:WaitForChild("PlayerGui")
    
    local mf = Instance.new("Frame")
    mf.Size = UDim2.new(0, 300, 0, 430)
    mf.Position = UDim2.new(0, 10, 0.5, -215)
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
    title.Text = "📦 AUTO MAIL (TEST)"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.Parent = mf
    
    -- Username
    local ul = Instance.new("TextLabel")
    ul.Size = UDim2.new(1, -20, 0, 14)
    ul.Position = UDim2.new(0, 10, 0, 42)
    ul.BackgroundTransparency = 1
    ul.Text = "🎯 Target Username:"
    ul.TextColor3 = Color3.fromRGB(180, 180, 180)
    ul.Font = Enum.Font.Gotham
    ul.TextSize = 10
    ul.TextXAlignment = Enum.TextXAlignment.Left
    ul.Parent = mf
    
    local userBox = Instance.new("TextBox")
    userBox.Size = UDim2.new(1, -20, 0, 28)
    userBox.Position = UDim2.new(0, 10, 0, 57)
    userBox.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    userBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    userBox.PlaceholderText = "theawan1 / aoneoneee / ..."
    userBox.PlaceholderColor3 = Color3.fromRGB(110, 110, 110)
    userBox.Font = Enum.Font.Gotham
    userBox.TextSize = 13
    userBox.Text = "theawan1"
    userBox.Parent = mf
    Instance.new("UICorner", userBox).CornerRadius = UDim.new(0, 5)
    
    -- Jumlah
    local jl = Instance.new("TextLabel")
    jl.Size = UDim2.new(1, -20, 0, 14)
    jl.Position = UDim2.new(0, 10, 0, 92)
    jl.BackgroundTransparency = 1
    jl.Text = "🔢 Jumlah (0 = semua stok):"
    jl.TextColor3 = Color3.fromRGB(180, 180, 180)
    jl.Font = Enum.Font.Gotham
    jl.TextSize = 10
    jl.TextXAlignment = Enum.TextXAlignment.Left
    jl.Parent = mf
    
    local countBox = Instance.new("TextBox")
    countBox.Size = UDim2.new(1, -20, 0, 28)
    countBox.Position = UDim2.new(0, 10, 0, 107)
    countBox.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    countBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    countBox.PlaceholderText = "0 = semua stok"
    countBox.PlaceholderColor3 = Color3.fromRGB(110, 110, 110)
    countBox.Font = Enum.Font.Gotham
    countBox.TextSize = 13
    countBox.Text = "0"
    countBox.Parent = mf
    Instance.new("UICorner", countBox).CornerRadius = UDim.new(0, 5)
    
    -- Kategori Label
    local kl = Instance.new("TextLabel")
    kl.Size = UDim2.new(1, -20, 0, 14)
    kl.Position = UDim2.new(0, 10, 0, 142)
    kl.BackgroundTransparency = 1
    kl.Text = "📂 Kategori:"
    kl.TextColor3 = Color3.fromRGB(180, 180, 180)
    kl.Font = Enum.Font.Gotham
    kl.TextSize = 10
    kl.TextXAlignment = Enum.TextXAlignment.Left
    kl.Parent = mf
    
    -- Kategori Dropdown
    local catFrame = Instance.new("Frame")
    catFrame.Size = UDim2.new(1, -20, 0, 30)
    catFrame.Position = UDim2.new(0, 10, 0, 157)
    catFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    catFrame.BorderSizePixel = 0
    catFrame.Parent = mf
    Instance.new("UICorner", catFrame).CornerRadius = UDim.new(0, 5)
    
    local catLabel = Instance.new("TextLabel")
    catLabel.Size = UDim2.new(1, -30, 1, 0)
    catLabel.Position = UDim2.new(0, 10, 0, 0)
    catLabel.BackgroundTransparency = 1
    catLabel.Text = "Seeds"
    catLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    catLabel.Font = Enum.Font.GothamBold
    catLabel.TextSize = 13
    catLabel.TextXAlignment = Enum.TextXAlignment.Left
    catLabel.Parent = catFrame
    
    local catArrow = Instance.new("TextLabel")
    catArrow.Size = UDim2.new(0, 20, 1, 0)
    catArrow.Position = UDim2.new(1, -25, 0, 0)
    catArrow.BackgroundTransparency = 1
    catArrow.Text = "▼"
    catArrow.TextColor3 = Color3.fromRGB(150, 150, 150)
    catArrow.Font = Enum.Font.GothamBold
    catArrow.TextSize = 14
    catArrow.Parent = catFrame
    
    -- Dropdown list
    local dropdown = Instance.new("Frame")
    dropdown.Size = UDim2.new(1, 0, 0, #CATEGORIES * 30)
    dropdown.Position = UDim2.new(0, 0, 1, 3)
    dropdown.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
    dropdown.BorderSizePixel = 0
    dropdown.Visible = false
    dropdown.ZIndex = 10
    dropdown.Parent = catFrame
    Instance.new("UICorner", dropdown).CornerRadius = UDim.new(0, 5)
    
    for i, cat in ipairs(CATEGORIES) do
        local opt = Instance.new("TextButton")
        opt.Size = UDim2.new(1, 0, 0, 30)
        opt.Position = UDim2.new(0, 0, 0, (i-1)*30)
        opt.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
        opt.Text = cat.Name
        opt.TextColor3 = Color3.fromRGB(200, 200, 200)
        opt.Font = Enum.Font.Gotham
        opt.TextSize = 13
        opt.BorderSizePixel = 0
        opt.ZIndex = 10
        opt.Parent = dropdown
        
        opt.MouseButton1Click:Connect(function()
            selectedCategory = cat.Name
            catLabel.Text = cat.Name
            dropdown.Visible = false
            updateItemList(scrollFrame)
        end)
    end
    
    catFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dropdown.Visible = not dropdown.Visible
        end
    end)
    catLabel.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dropdown.Visible = not dropdown.Visible
        end
    end)
    
    -- Items Label
    local il = Instance.new("TextLabel")
    il.Size = UDim2.new(1, -20, 0, 14)
    il.Position = UDim2.new(0, 10, 0, 194)
    il.BackgroundTransparency = 1
    il.Text = "📋 Item (Stok dari atribut Count):"
    il.TextColor3 = Color3.fromRGB(180, 180, 180)
    il.Font = Enum.Font.Gotham
    il.TextSize = 9
    il.TextXAlignment = Enum.TextXAlignment.Left
    il.Parent = mf
    
    -- Scrolling Frame
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -10, 0, 140)
    scrollFrame.Position = UDim2.new(0, 5, 0, 210)
    scrollFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 33)
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 5
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 100)
    scrollFrame.Parent = mf
    Instance.new("UICorner", scrollFrame).CornerRadius = UDim.new(0, 5)
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 2)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = scrollFrame
    
    -- Fungsi update item list
    function updateItemList(sf)
        for _, child in ipairs(sf:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        
        local items = {}
        for _, cat in ipairs(CATEGORIES) do
            if cat.Name == selectedCategory then
                items = cat.Items
                break
            end
        end
        
        sf.CanvasSize = UDim2.new(0, 0, 0, #items * 30 + 8)
        
        for _, itemName in ipairs(items) do
            local stock = getItemCount(itemName)
            
            local fr = Instance.new("Frame")
            fr.Size = UDim2.new(1, -8, 0, 26)
            fr.BackgroundColor3 = selectedItems[itemName] and Color3.fromRGB(40, 60, 45) or Color3.fromRGB(42, 42, 48)
            fr.BorderSizePixel = 0
            fr.Parent = sf
            Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 4)
            
            local cbtn = Instance.new("TextButton")
            cbtn.Size = UDim2.new(0, 18, 0, 18)
            cbtn.Position = UDim2.new(0, 4, 0.5, -9)
            cbtn.BackgroundColor3 = selectedItems[itemName] and Color3.fromRGB(0, 160, 80) or Color3.fromRGB(55, 55, 60)
            cbtn.Text = ""
            cbtn.BorderSizePixel = 0
            cbtn.Parent = fr
            Instance.new("UICorner", cbtn).CornerRadius = UDim.new(0, 3)
            
            local cm = Instance.new("TextLabel")
            cm.Size = UDim2.new(1, 0, 1, 0)
            cm.BackgroundTransparency = 1
            cm.Text = "✓"
            cm.TextColor3 = Color3.fromRGB(0, 255, 100)
            cm.Font = Enum.Font.GothamBold
            cm.TextSize = 13
            cm.Visible = selectedItems[itemName]
            cm.Parent = cbtn
            
            -- Stok label (dari atribut Count)
            local sl = Instance.new("TextLabel")
            sl.Size = UDim2.new(0, 40, 1, 0)
            sl.Position = UDim2.new(1, -42, 0, 0)
            sl.BackgroundTransparency = 1
            sl.Text = "x" .. tostring(stock)
            sl.TextColor3 = stock > 0 and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(120, 120, 120)
            sl.Font = Enum.Font.GothamBold
            sl.TextSize = 9
            sl.TextXAlignment = Enum.TextXAlignment.Right
            sl.Parent = fr
            
            local lb = Instance.new("TextLabel")
            lb.Size = UDim2.new(1, -70, 1, 0)
            lb.Position = UDim2.new(0, 26, 0, 0)
            lb.BackgroundTransparency = 1
            lb.Text = itemName
            lb.TextColor3 = Color3.fromRGB(220, 220, 220)
            lb.Font = Enum.Font.Gotham
            lb.TextSize = 10
            lb.TextXAlignment = Enum.TextXAlignment.Left
            lb.Parent = fr
            
            local function ch()
                selectedItems[itemName] = not selectedItems[itemName]
                cbtn.BackgroundColor3 = selectedItems[itemName] and Color3.fromRGB(0, 160, 80) or Color3.fromRGB(55, 55, 60)
                cm.Visible = selectedItems[itemName]
                fr.BackgroundColor3 = selectedItems[itemName] and Color3.fromRGB(40, 60, 45) or Color3.fromRGB(42, 42, 48)
            end
            
            cbtn.MouseButton1Click:Connect(ch)
            fr.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then ch() end
            end)
        end
    end
    
    -- Status
    local st = Instance.new("TextLabel")
    st.Size = UDim2.new(1, -20, 0, 14)
    st.Position = UDim2.new(0, 10, 0, 356)
    st.BackgroundTransparency = 1
    st.Text = "Status: SIAP"
    st.TextColor3 = Color3.fromRGB(255, 200, 0)
    st.Font = Enum.Font.Gotham
    st.TextSize = 9
    st.TextXAlignment = Enum.TextXAlignment.Left
    st.Parent = mf
    
    -- Tombol Kirim
    local sendBtn = Instance.new("TextButton")
    sendBtn.Size = UDim2.new(1, -20, 0, 30)
    sendBtn.Position = UDim2.new(0, 10, 0, 372)
    sendBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 220)
    sendBtn.Text = "📤 KIRIM SEKARANG"
    sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    sendBtn.Font = Enum.Font.GothamBold
    sendBtn.TextSize = 12
    sendBtn.BorderSizePixel = 0
    sendBtn.Parent = mf
    Instance.new("UICorner", sendBtn).CornerRadius = UDim.new(0, 5)
    
    sendBtn.MouseButton1Click:Connect(function()
        local username = userBox.Text
        local manualCount = tonumber(countBox.Text) or 0
        
        if username == "" then
            st.Text = "ISI USERNAME DULU!"
            st.TextColor3 = Color3.fromRGB(255, 80, 80)
            return
        end
        
        st.Text = "Mengirim..."
        st.TextColor3 = Color3.fromRGB(0, 200, 255)
        
        local ok = sendSelectedItems(username, manualCount > 0 and manualCount or nil)
        
        if ok then
            st.Text = "TERKIRIM! ✓"
            st.TextColor3 = Color3.fromRGB(0, 255, 100)
            -- Refresh stok
            updateItemList(scrollFrame)
        else
            st.Text = "GAGAL!"
            st.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
    end)
    
    -- Init
    updateItemList(scrollFrame)
end

-- ============================================
-- INIT
-- ============================================
createGUI()

print("========================================")
print(" AUTO MAIL TEST GUI - SIAP")
print(" Stok dari: Tool > GetAttribute('Count')")
print("========================================")
