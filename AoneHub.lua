-- ──────────────────────────────────────────────────────────────────────
-- 1️⃣  Services & References
-- ──────────────────────────────────────────────────────────────────────
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Coba berbagai kemungkinan path
local packetRemote = ReplicatedStorage:FindFirstChild("SharedModules")
if packetRemote then
    -- Jika SharedModules adalah Folder, cari Packet di dalamnya
    packetRemote = packetRemote:FindFirstChild("Packet")
    if packetRemote then
        -- Jika Packet adalah Folder/Model, cari RemoteEvent di dalamnya
        if packetRemote:IsA("Folder") or packetRemote:IsA("Model") then
            packetRemote = packetRemote:FindFirstChild("RemoteEvent")
        -- Jika Packet langsung RemoteEvent
        elseif packetRemote:IsA("RemoteEvent") then
            -- sudah benar
        else
            warn("[AutoBuy] Packet bukan Folder/Model/RemoteEvent, type:", packetRemote.ClassName)
            packetRemote = nil
        end
    end
end

-- Fallback: cari langsung di ReplicatedStorage
if not packetRemote then
    packetRemote = ReplicatedStorage:FindFirstChild("PacketRemote")
        or ReplicatedStorage:FindFirstChild("PacketEvent")
        or ReplicatedStorage:FindFirstChild("BuyRemote")
end

-- Validasi final
if not packetRemote then
    error("[AutoBuy] RemoteEvent tidak ditemukan! Periksa struktur ReplicatedStorage.")
elseif not packetRemote:IsA("RemoteEvent") then
    error("[AutoBuy] Object ditemukan tapi bukan RemoteEvent! Type: " .. packetRemote.ClassName)
end

print("[AutoBuy] RemoteEvent ditemukan:", packetRemote:GetFullName())

-- ──────────────────────────────────────────────────────────────────────
-- 2️⃣  Items to auto‑buy
-- ──────────────────────────────────────────────────────────────────────
local ITEMS = {
    "Hypno Bloom",
    "Dragon's Breath",
    "Sun Bloom",
    "Star Fruit",
}

-- ──────────────────────────────────────────────────────────────────────
-- 3️⃣  Utility: Build the binary packet required by the game
-- ──────────────────────────────────────────────────────────────────────
local function buildPacket(name)
    local len = #name
    if len > 255 then
        warn("[AutoBuy] Nama item terlalu panjang:", name)
        return nil
    end
    
    local pkt = buffer.create(3 + len)          -- 3 header bytes + string
    buffer.writeu8(pkt, 0, 131)                 -- Opcode 131
    buffer.writeu8(pkt, 1, 0)                   -- Padding
    buffer.writeu8(pkt, 2, len)                 -- Length of string
    
    for i = 1, len do
        buffer.writeu8(pkt, 2 + i, string.byte(name, i))
    end
    
    return pkt
end

-- ──────────────────────────────────────────────────────────────────────
-- 4️⃣  Buy function with error handling
-- ──────────────────────────────────────────────────────────────────────
local function buyItem(itemName)
    local packet = buildPacket(itemName)
    if not packet then
        warn("[AutoBuy] Gagal build packet untuk:", itemName)
        return false
    end
    
    local success, err = pcall(function()
        packetRemote:FireServer(packet)
    end)
    
    if not success then
        warn("[AutoBuy] Error saat membeli", itemName, ":", err)
        return false
    end
    
    print("[AutoBuy] Berhasil mengirim packet untuk:", itemName)
    return true
end

-- ──────────────────────────────────────────────────────────────────────
-- 5️⃣  Auto‑buy loop with proper delays
-- ──────────────────────────────────────────────────────────────────────
local function startAutoBuy()
    local running = true
    
    -- Cleanup function
    local function stopAutoBuy()
        running = false
        print("[AutoBuy] Dihentikan")
    end
    
    for _, item in ipairs(ITEMS) do
        task.spawn(function()
            -- Initial random delay to prevent all items firing at once
            task.wait(math.random() * 5)
            
            while running do
                buyItem(item)
                -- Jittered wait between 5-15 seconds
                task.wait(5 + math.random() * 10)
            end
        end)
    end
    
    return stopAutoBuy
end

-- ──────────────────────────────────────────────────────────────────────
-- 6️⃣  Start the script
-- ──────────────────────────────────────────────────────────────────────
print("[AutoBuy] Script dimulai dengan", #ITEMS, "items")
local stopFunction = startAutoBuy()

-- Optional: Stop after certain time (uncomment if needed)
-- task.delay(3600, function()  -- Stop after 1 hour
--     stopFunction()
-- end)

-- Optional: Bind to key to toggle (uncomment if needed)
-- local UserInputService = game:GetService("UserInputService")
-- local toggled = true
-- UserInputService.InputBegan:Connect(function(input, gameProcessed)
--     if gameProcessed then return end
--     if input.KeyCode == Enum.KeyCode.F then
--         toggled = not toggled
--         if toggled then
--             stopFunction = startAutoBuy()
--             print("[AutoBuy] ON")
--         else
--             stopFunction()
--             print("[AutoBuy] OFF")
--         end
--     end
-- end)
