local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
local Window = Library.CreateLib("AoneHub", "Synapse")
local MainTab = Window:NewTab("Main")
local MailTab = Window:NewTab("Mail")
local MainSection = MainTab:NewSection("Main")
local MailSection = MailTab:NewSection("Mail")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local packetRemote = ReplicatedStorage:WaitForChild("SharedModules")
    :WaitForChild("Packet")
    :WaitForChild("RemoteEvent")

local ITEMS = {
    "Hypno Bloom", "Carrot",
    "Dragon's Breath",
    "Sun Bloom",
    "Star Fruit",
}

local isEnabled = true -- Default OFF
local buyThreads = {} -- Simpan thread reference

local function buildPacket(name)
    local len = #name
    local pkt = buffer.create(3 + len)
    buffer.writeu8(pkt, 0, 131)
    buffer.writeu8(pkt, 1, 0)
    buffer.writeu8(pkt, 2, len)
    for i = 1, len do
        buffer.writeu8(pkt, 2 + i, string.byte(name, i))
    end
    return pkt
end

local function startAutoBuy()
    if isEnabled then return end -- Sudah berjalan
    
    isEnabled = true
    print("[Auto Buy] Memulai auto-buy untuk " .. #ITEMS .. " items")
    
    for _, item in ipairs(ITEMS) do
        local thread = task.spawn(function()
            while isEnabled do
                local success, err = pcall(function()
                    packetRemote:FireServer(buildPacket(item))
                end)
                if not success then
                    warn("[AutoBuy] Failed for", item, ":", err)
                end
                task.wait(5 + math.random() * 10)
            end
        end)
        table.insert(buyThreads, thread)
    end
end

local function stopAutoBuy()
    if not isEnabled then return end -- Sudah berhenti
    
    isEnabled = false
    print("[Auto Buy] Menghentikan auto-buy")
    buyThreads = {} -- Clear thread references (threads akan mati sendiri karena cek isEnabled)
end

-- Toggle GUI
MainSection:NewToggle("Auto Buy", "Seeds", function(state)
    if state then
        startAutoBuy()
    else
        stopAutoBuy()
    end
end)
