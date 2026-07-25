local ReplicatedStorage = game:GetService("ReplicatedStorage")

local packetRemote = ReplicatedStorage:WaitForChild("SharedModules")
    :WaitForChild("Packet")
    :WaitForChild("RemoteEvent")

-- ──────────────────────────────────────────────────────────────────────
-- 2️⃣  Items to auto‑buy
-- ──────────────────────────────────────────────────────────────────────
local ITEMS = {
    "Hypno Bloom",
    "Carrot", 
    "Dragon's Breath",
    "Sun Bloom",
    "Star Fruit",
}

-- ──────────────────────────────────────────────────────────────────────
-- 3️⃣  Utility: Build the binary packet required by the game
-- ──────────────────────────────────────────────────────────────────────
local function buildPacket(name)
    local len = #name
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
-- 4️⃣  Auto‑buy loop
-- ──────────────────────────────────────────────────────────────────────
for _, item in ipairs(ITEMS) do
    task.spawn(function()
        while true do
            local success, err = pcall(function()
                packetRemote:FireServer(buildPacket(item))
            end)
            if not success then
                warn("[AutoBuy] Failed for", item, ":", err)
            end
            task.wait(5 + math.random() * 10)   -- jittered wait
        end
    end)
end
