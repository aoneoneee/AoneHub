-- AUTO MAIL & CLAIM - TANPA BUKA MAILBOX
-- Set target via Button di PlayerList (background) + Kirim + Claim

local Players = game:GetService("Players")
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
    "Briar Rose",
    "Dragon's Breath", 
    "Star Fruit",
    "Hypno Bloom",
    "Sun Bloom",
    "Moon Bloom",
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
-- FUNGSI CEK STOK
-- ============================================
function getItemCount(itemName)
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
function getCategory(itemName)
    if string.find(itemName, "Sprinkler") then
        return "Sprinklers"
    elseif string.find(itemName, "Watering") then
        return "WateringCans"
    else
        return "Seeds"
    end
end

-- ============================================
-- SET TARGET USERNAME DI UI MAILBOX (BACKGROUND)
-- ============================================
function setMailTarget(username)
    local targetText = "@" .. username
    local found = false
    
    -- Cari langsung dari path yang kamu kasih
    pcall(function()
        local playerList = player.PlayerGui:FindFirstChild("MailboxUI")
        if playerList then
            playerList = playerList:FindFirstChild("Frame")
        end
        if playerList then
            playerList = playerList:FindFirstChild("SendingFrame")
        end
        if playerList then
            playerList = playerList:FindFirstChild("SendPlayerFrame")
        end
        if playerList then
            playerList = playerList:FindFirstChild("PlayerList")
        end
        
        if not playerList then
            print("[Mail] PlayerList tidak ditemukan")
            return
        end
        
        -- Loop semua SendTemplate
        for _, template in ipairs(playerList:GetChildren()) do
            if template:IsA("Frame") or template:IsA("GuiObject") then
                local button = template:FindFirstChild("Button")
                if button then
                    local usernameLabel = button:FindFirstChild("PlayerUsername")
                    if usernameLabel and usernameLabel:IsA("TextLabel") then
                        if usernameLabel.Text == targetText then
                            print("[Mail] Target ditemukan: " .. usernameLabel.Text)
                            
                            -- Simulasi klik button
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
        print("[Mail] Target @" .. username .. " TIDAK ditemukan di PlayerList")
        
        -- Debug: tampilkan semua username yang ada
        print("[Mail] Username yang tersedia:")
        pcall(function()
            local playerList = player.PlayerGui.MailboxUI.Frame.SendingFrame.SendPlayerFrame.PlayerList
            for _, template in ipairs(playerList:GetChildren()) do
                if template:IsA("Frame") then
                    local button = template:FindFirstChild("Button")
                    if button then
                        local label = button:FindFirstChild("PlayerUsername")
                        if label then
                            print("  - " .. label.Text)
                        end
                    end
                end
            end
        end)
    end
    
    return found
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
-- KIRIM SATU ITEM
-- ============================================
function sendSingleItem(itemName, count, category)
    if count <= 0 then return false end
    
    local nameLen = string.len(itemName)
    local catLen = string.len(category)
    
    -- Encode count
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
function sendAllSelectedItems()
    -- Set target dulu
    print("[Mail] Set target: @" .. targetUsername)
    local targetSet = setMailTarget(targetUsername)
    
    if not targetSet then
        print("[Mail] GAGAL set target!")
        return false
    end
    
    wait(0.3)
    
    -- Scan stok
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
    
    print("[Mail] ===== KIRIM " .. #toSend .. " ITEM =====")
    
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
    
    print("[Mail] ===== SELESAI =====")
    return true
end

-- ============================================
-- CLAIM FUNCTIONS
-- ============================================
function getReceiveFrame()
    local success, result = pcall(function()
        return player.PlayerGui:FindFirstChild("MailboxUI")
            and player.PlayerGui.MailboxUI:FindFirstChild("Frame")
            and player.PlayerGui.MailboxUI.Frame:FindFirstChild("ReceiveFrame")
    end)
    if success then return result end
    return nil
end

function scanGifts()
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

function claimAllGifts()
    if not isClaimRunning then return end
    
    print("[Claim] ===== SCAN =====")
    local gifts = scanGifts()
    
    if #gifts == 0 then
        print("[Claim] Tidak ada gift")
        return
    end
    
    print("[Claim] " .. #gifts .. " gift ditemukan")
    
    for i, giftId in ipairs(gifts) do
        if not isClaimRunning then break end
        
        print("[Claim] Claim #" .. i .. ": " .. giftId)
        pcall(function()
            local remote = ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Packet"):WaitForChild("RemoteEvent")
            local args = {buffer.fromstring("b\0014&4:" .. giftId)}
            remote:FireServer(unpack(args))
            print("[Claim] ✓")
        end)
        
        if i < #gifts and isClaimRunning then
            wait(math.random(10, 30) / 10)
        end
    end
    
    print("[Claim] Selesai")
end

-- ============================================
-- SCAN & KIRIM + RETRY
-- ============================================
function scanAndSend()
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
            print("[Mail] Retry - masih ada stok")
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
-- COMMANDS
-- ============================================
print("========================================")
print(" AUTO MAIL & CLAIM")
print(" TANPA perlu buka mailbox")
print("========================================")
print("Commands:")
print("  slist()       - Lihat stok item")
print("  select(nama)  - Pilih item")
print("  unselect(nama)- Batal pilih")
print("  settarget(n)  - Set target username")
print("  startmail()   - Mulai auto mail")
print("  stopmail()    - Berhenti")
print("  startclaim()  - Mulai auto claim")
print("  stopclaim()   - Berhenti")
print("  sendnow()     - Kirim sekarang")
print("  claimnow()    - Claim sekarang")
print("  testtarget()  - Test set target")
print(" ")

function slist()
    print("=== STOK ===")
    for _, name in ipairs(AVAILABLE_ITEMS) do
        local stock = getItemCount(name)
        local mark = selectedItems[name] and "[✓]" or "[ ]"
        print(mark .. " " .. name .. ": " .. stock)
    end
end

function select(name)
    if selectedItems[name] ~= nil then
        selectedItems[name] = true
        print("✓ " .. name)
    else
        print("✗ Tidak ada: " .. name)
        print("  Tersedia:")
        for _, n in ipairs(AVAILABLE_ITEMS) do
            print("    - " .. n)
        end
    end
end

function unselect(name)
    if selectedItems[name] ~= nil then
        selectedItems[name] = false
        print("✗ " .. name)
    end
end

function settarget(name)
    targetUsername = name
    print("Target: @" .. targetUsername)
end

function startmail()
    isMailRunning = true
    lastMailMinute = -1
    print("✓ AUTO MAIL AKTIF")
    print("  Target: @" .. targetUsername)
    print("  Scan: menit 03, 08, 13...")
end

function stopmail()
    isMailRunning = false
    print("✗ AUTO MAIL BERHENTI")
end

function startclaim()
    isClaimRunning = true
    lastClaimMinute = -1
    print("✓ AUTO CLAIM AKTIF")
    print("  Scan: menit 04, 09, 14...")
    claimAllGifts()
end

function stopclaim()
    isClaimRunning = false
    print("✗ AUTO CLAIM BERHENTI")
end

function sendnow()
    print("Kirim sekarang ke @" .. targetUsername .. "...")
    scanAndSend()
end

function claimnow()
    claimAllGifts()
end

function testtarget()
    print("Test set target @" .. targetUsername)
    local ok = setMailTarget(targetUsername)
    if ok then
        print("✓ BERHASIL!")
    else
        print("✗ GAGAL! Cek apakah @" .. targetUsername .. " ada di PlayerList")
    end
end

-- Default
settarget("aoneoneee")
select("Dragon's Breath")
select("Super Sprinkler")
slist()
print(" ")
print("💡 Ketik testtarget() untuk test set target")
print("💡 Ketik sendnow() untuk test kirim")

-- ============================================
-- MAIN LOOP
-- ============================================
spawn(function()
    while true do
        wait(1)
        
        if isMailRunning and isMailScanTime() then
            print("[Mail] SCAN TIME: " .. os.date("%H:%M:%S"))
            scanAndSend()
        end
        
        if isClaimRunning and isClaimScanTime() then
            print("[Claim] SCAN TIME: " .. os.date("%H:%M:%S"))
            claimAllGifts()
        end
    end
end)
