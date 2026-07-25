-- ──────────────────────────────────────────────────────────────────────
-- 1️⃣  Services & References
-- ──────────────────────────────────────────────────────────────────────
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local packetRemote = ReplicatedStorage:WaitForChild("SharedModules")
    :WaitForChild("Packet")
    :WaitForChild("RemoteEvent")

print("[AutoBuy] RemoteEvent:", packetRemote:GetFullName())

-- ──────────────────────────────────────────────────────────────────────
-- 2️⃣  Auto-detect opcode (RUN ONCE, READ ONLY)
-- ──────────────────────────────────────────────────────────────────────
local function detectOpcode()
    local connections = getconnections or debug.getconnections
    
    -- Method 1: Scan OnServerEvent connections
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
    
    -- Method 2: Cek Packet ModuleScript
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
    
    -- Method 3: Cek Config/Network modules
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
    
    -- Fallback
    warn("[AutoBuy] ⚠️  Opcode tidak terdeteksi, menggunakan default 133")
    return 133
end

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
}

local MIN_DELAY = 5
local MAX_DELAY = 15

-- ──────────────────────────────────────────────────────────────────────
-- 4️⃣  Build packet dengan auto-detected opcode
-- ──────────────────────────────────────────────────────────────────────
local function buildPacket(itemName)
    local len = #itemName
    -- Format: \opcode\000\{length}\{itemName}
    return string.char(OPCODE, 0, len) .. itemName
end

-- ──────────────────────────────────────────────────────────────────────
-- 5️⃣  Auto-buy loop (recursive)
-- ──────────────────────────────────────────────────────────────────────
local function buyLoop(itemName, count)
    count = count or 1
    
    -- Build & send packet
    local packet = buildPacket(itemName)
    local success, err = pcall(function()
        packetRemote:FireServer(packet)
    end)
    
    if success then
        print("[AutoBuy] ✅", itemName, "| #" .. count)
    else
        warn("[AutoBuy] ❌", itemName, "| #" .. count, "|", err)
    end
    
    -- Schedule next buy
    local waitTime = MIN_DELAY + math.random() * (MAX_DELAY - MIN_DELAY)
    print("[AutoBuy] ⏳ Next", itemName, "in", math.floor(waitTime), "s")
    
    task.delay(waitTime, function()
        buyLoop(itemName, count + 1)
    end)
end

-- ──────────────────────────────────────────────────────────────────────
-- 6️⃣  Start dengan JITTER AWAL biar gak barengan
-- ──────────────────────────────────────────────────────────────────────
print("[AutoBuy] 🚀 Starting | Items:", #ITEMS, "| Opcode:", OPCODE)

for _, item in ipairs(ITEMS) do
    -- JITTER AWAL: tiap item mulai di waktu acak 0-10 detik
    local initialJitter = math.random() * 10
    print("[AutoBuy] 🕐", item, "mulai dalam", string.format("%.1f", initialJitter), "s")
    
    task.delay(initialJitter, function()
        buyLoop(item)
    end)
end
