-- ──────────────────────────────────────────────────────────────────────
-- 1️⃣  Services & References
-- ──────────────────────────────────────────────────────────────────────
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
elseif not packetRemote:IsA("RemoteEvent") then
    error("[AutoBuy] Bukan RemoteEvent! Type: " .. packetRemote.ClassName)
end

print("[AutoBuy] RemoteEvent:", packetRemote:GetFullName())

-- ──────────────────────────────────────────────────────────────────────
-- 2️⃣  Opcode detection (RUN ONCE)
-- ──────────────────────────────────────────────────────────────────────
local function detectOpcode()
    local connections = getconnections or debug.getconnections
    
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
    
    warn("[AutoBuy] ⚠️  Opcode tidak terdeteksi, menggunakan default 133")
    return 131
end

local OPCODE = detectOpcode()
print("[AutoBuy] 🔢 Opcode:", OPCODE)

-- ──────────────────────────────────────────────────────────────────────
-- 3️⃣  Items & Config
-- ──────────────────────────────────────────────────────────────────────
local ITEMS = {
    "Hypno Bloom",
    "Carrot",
    "Dragon's Breath",
    "Sun Bloom",
    "Star Fruit",
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
-- 5️⃣  Simple auto-buy loop (PASTI LOOP)
-- ──────────────────────────────────────────────────────────────────────
for _, item in ipairs(ITEMS) do
    task.spawn(function()
        local itemName = item  -- Capture variable
        local count = 0
        
        print("[AutoBuy] 🔄 Starting loop for:", itemName)
        
        while true do  -- Infinite loop, PASTI jalan terus
            count += 1
            
            -- Build & send packet
            local packet = buildPacket(itemName)
            if packet then
                local success, err = pcall(function()
                    packetRemote:FireServer(packet)
                end)
                
                if success then
                    print("[AutoBuy] ✅", itemName, "| Attempt #" .. count)
                else
                    warn("[AutoBuy] ❌", itemName, "| Attempt #" .. count, "| Error:", err)
                end
            else
                warn("[AutoBuy] ⚠️  Gagal build packet untuk:", itemName)
            end
            
            -- Wait before next buy
            local waitTime = MIN_DELAY + math.random() * (MAX_DELAY - MIN_DELAY)
            print("[AutoBuy] ⏳", itemName, "| Waiting", math.floor(waitTime), "seconds...")
            task.wait(waitTime)
        end
    end)
end

print("[AutoBuy] 🚀 Script started | Items:", #ITEMS, "| Opcode:", OPCODE)
