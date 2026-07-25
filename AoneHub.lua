-- ──────────────────────────────────────────────────────────────────────
-- 1️⃣  Services & References
-- ──────────────────────────────────────────────────────────────────────
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local packetRemote = ReplicatedStorage:FindFirstChild("SharedModules")
if packetRemote then
    packetRemote = packetRemote:FindFirstChild("Packet")
    if packetRemote then
        if packetRemote:IsA("Folder") or packetRemote:IsA("Model") then
            packetRemote = packetRemote:FindFirstChild("RemoteEvent")
        elseif not packetRemote:IsA("RemoteEvent") then
            packetRemote = nil
        end
    end
end

if not packetRemote then
    packetRemote = ReplicatedStorage:FindFirstChild("PacketRemote")
        or ReplicatedStorage:FindFirstChild("PacketEvent")
        or ReplicatedStorage:FindFirstChild("BuyRemote")
end

if not packetRemote then
    error("[AutoBuy] RemoteEvent tidak ditemukan!")
end

print("[AutoBuy] RemoteEvent:", packetRemote:GetFullName())

-- ──────────────────────────────────────────────────────────────────────
-- 2️⃣  Safe & fast opcode detection (RUN ONCE, READ ONLY)
-- ──────────────────────────────────────────────────────────────────────
local function detectOpcode()
    local connections = getconnections or debug.getconnections
    
    -- Method 1: Scan OnServerEvent connections (targeted, fast)
    if connections and packetRemote.OnServerEvent then
        local conns = connections(packetRemote.OnServerEvent)
        for _, conn in ipairs(conns) do
            local func = conn.Function
            if func then
                local success, upvalues = pcall(debug.getupvalues, func)
                if success then
                    for _, upval in ipairs(upvalues) do
                        if type(upval) == "number" and upval >= 100 and upval <= 200 then
                            print("[AutoBuy] ✅ Opcode dari OnServerEvent:", upval)
                            return upval
                        end
                    end
                end
            end
        end
    end
    
    -- Method 2: Cek Packet ModuleScript (targeted, fast)
    local sharedModules = ReplicatedStorage:FindFirstChild("SharedModules")
    if sharedModules then
        local packetModule = sharedModules:FindFirstChild("Packet")
        if packetModule and packetModule:IsA("ModuleScript") then
            local success, module = pcall(require, packetModule)
            if success and type(module) == "table" then
                for key, value in pairs(module) do
                    if type(value) == "number" and value >= 100 and value <= 200 then
                        print("[AutoBuy] ✅ Opcode dari Packet module:", value)
                        return value
                    end
                end
            end
        end
    end
    
    -- Method 3: Cek Network/Config modules (targeted, fast)
    local configNames = {"NetworkConfig", "Config", "Settings", "Constants"}
    for _, name in ipairs(configNames) do
        local config = ReplicatedStorage:FindFirstChild(name)
        if config and config:IsA("ModuleScript") then
            local success, data = pcall(require, config)
            if success and type(data) == "table" then
                for key, value in pairs(data) do
                    if type(value) == "number" and value >= 100 and value <= 200 then
                        print("[AutoBuy] ✅ Opcode dari", name, ":", value)
                        return value
                    end
                end
            end
        end
    end
    
    -- Fallback: coba 133 dulu
    warn("[AutoBuy] ⚠️  Opcode tidak terdeteksi, menggunakan default 133")
    return 131
end

-- RUN ONCE
local OPCODE = detectOpcode()
print("[AutoBuy] 🔢 Opcode:", OPCODE)

-- ──────────────────────────────────────────────────────────────────────
-- 3️⃣  Items & Config
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
-- 4️⃣  Build packet
-- ──────────────────────────────────────────────────────────────────────
local function buildPacket(name)
    local len = #name
    if len > 255 then return nil end
    
    local pkt = buffer.create(3 + len)
    buffer.writeu8(pkt, 0, OPCODE)
    buffer.writeu8(pkt, 1, 0)
    buffer.writeu8(pkt, 2, len)
    
    for i = 1, len do
        buffer.writeu8(pkt, 2 + i, string.byte(name, i))
    end
    
    return pkt
end

-- ──────────────────────────────────────────────────────────────────────
-- 5️⃣  Buy function
-- ──────────────────────────────────────────────────────────────────────
local buyStats = {}

local function buyItem(itemName)
    local packet = buildPacket(itemName)
    if not packet then return false end
    
    local success, err = pcall(function()
        packetRemote:FireServer(packet)
    end)
    
    if not buyStats[itemName] then
        buyStats[itemName] = {sent = 0, failed = 0}
    end
    buyStats[itemName].sent += 1
    
    if not success then
        buyStats[itemName].failed += 1
        if buyStats[itemName].failed <= 3 then  -- Cuma warn 3x pertama
            warn("[AutoBuy] ❌", itemName, "-", err)
        end
        return false
    end
    
    return true
end

-- ──────────────────────────────────────────────────────────────────────
-- 6️⃣  Auto‑buy loop
-- ──────────────────────────────────────────────────────────────────────
local function startAutoBuy()
    local running = true
    
    local function stopAutoBuy()
        running = false
        print("\n[AutoBuy] 📊 Stats:")
        for item, stats in pairs(buyStats) do
            print(string.format("  %s: %d sent", item, stats.sent))
        end
    end
    
    for _, item in ipairs(ITEMS) do
        task.spawn(function()
            task.wait(math.random() * 5)  -- Spread out initial buys
            
            while running do
                buyItem(item)
                task.wait(MIN_DELAY + math.random() * (MAX_DELAY - MIN_DELAY))
            end
        end)
    end
    
    return stopAutoBuy
end

-- ──────────────────────────────────────────────────────────────────────
-- 7️⃣  Start
-- ──────────────────────────────────────────────────────────────────────
print(string.format("[AutoBuy] 🚀 Started | Items: %d | Delay: %d-%ds", 
    #ITEMS, MIN_DELAY, MAX_DELAY))
local stopFunction = startAutoBuy()a
