-- ──────────────────────────────────────────────────────────────────────
-- 1️⃣  Services & References
-- ──────────────────────────────────────────────────────────────────────
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local packetRemote = ReplicatedStorage:WaitForChild("SharedModules")
    :WaitForChild("Packet")
    :WaitForChild("RemoteEvent")

print("[AutoBuy] RemoteEvent:", packetRemote:GetFullName())

-- ──────────────────────────────────────────────────────────────────────
-- 2️⃣  Items & Config
-- ──────────────────────────────────────────────────────────────────────
local ITEMS = {
    "Hypno Bloom",
    "Dragon's Breath",
    "Sun Bloom",
    "Star Fruit",
    "Carrot"
}

local MIN_DELAY = 5
local MAX_DELAY = 15

-- ──────────────────────────────────────────────────────────────────────
-- 3️⃣  Build packet pakai string escape (SEPERTI CONTOH)
-- ──────────────────────────────────────────────────────────────────────
local function buildPacket(itemName)
    local len = #itemName
    -- Format: \133\000\{length}\{itemName}
    -- Gunakan string.char untuk membuat string byte
    return string.char(133, 0, len) .. itemName
end

-- ──────────────────────────────────────────────────────────────────────
-- 4️⃣  Auto-buy loop (recursive, PASTI LOOP)
-- ──────────────────────────────────────────────────────────────────────
local function buyLoop(itemName, count)
    count = count or 1
    
    -- Build packet
    local packet = buildPacket(itemName)
    
    -- Kirim packet SEPERTI CONTOH
    local success, err = pcall(function()
        packetRemote:FireServer(packet)  -- Tanpa unpack(), langsung string
    end)
    
    if success then
        print("[AutoBuy] ✅", itemName, "| #" .. count)
    else
        warn("[AutoBuy] ❌", itemName, "| #" .. count, "|", err)
    end
    
    -- Jadwalkan pembelian berikutnya
    local waitTime = MIN_DELAY + math.random() * (MAX_DELAY - MIN_DELAY)
    print("[AutoBuy] ⏳ Next", itemName, "in", math.floor(waitTime), "s")
    
    task.delay(waitTime, function()
        buyLoop(itemName, count + 1)
    end)
end

-- ──────────────────────────────────────────────────────────────────────
-- 5️⃣  Start
-- ──────────────────────────────────────────────────────────────────────
print("[AutoBuy] 🚀 Starting | Items:", #ITEMS)

for _, item in ipairs(ITEMS) do
    -- Jeda awal acak biar gak barengan
    task.delay(math.random() * 5, function()
        buyLoop(item)
    end)
end
