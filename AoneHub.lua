-- ──────────────────────────────────────────────────────────────────────
-- Auto‑Buy Menu (CoreGui) – Toggle + Minimize
-- ──────────────────────────────────────────────────────────────────────
-- Author:  Your Name (or “ChatGPT”)
-- Date:    2026‑07‑20
-- ──────────────────────────────────────────────────────────────────────

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui           = game:GetService("CoreGui")
local UserInputService  = game:GetService("UserInputService")

-- ──────────────────────────────────────────────────────────────────────
-- 1️⃣  RemoteEvent path (change if your game uses a different name)
-- ──────────────────────────────────────────────────────────────────────
local packetRemote = ReplicatedStorage:WaitForChild("SharedModules")
    :WaitForChild("Packet")
    :WaitForChild("RemoteEvent")

-- ──────────────────────────────────────────────────────────────────────
-- 2️⃣  Items to auto‑buy
-- ──────────────────────────────────────────────────────────────────────
local ITEMS = {
    "Carrot",
    "Dragon's Breath",
    "Sun Bloom",
    "Star Fruit",
    "Hypno Bloom"
}

-- ──────────────────────────────────────────────────────────────────────
-- 3️⃣  Utility: Build the binary packet required by the game
-- ──────────────────────────────────────────────────────────────────────
local function buildPacket(name)
    local len = #name
    local pkt = buffer.create(3 + len)          -- 3 header bytes + string
    buffer.writeu8(pkt, 0, 133)                 -- Opcode 131
    buffer.writeu8(pkt, 1, 0)                   -- Padding
    buffer.writeu8(pkt, 2, len)                 -- Length of string
    for i = 1, len do
        buffer.writeu8(pkt, 2 + i, string.byte(name, i))
    end
    return pkt
end

-- ──────────────────────────────────────────────────────────────────────
-- 4️⃣  GUI creation
-- ──────────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui", CoreGui)
gui.Name = "AutoBuyMenu"

-- Main container (the thing that can be dragged and minimized)
local frame = Instance.new("Frame", gui)
frame.Name = "MainFrame"
frame.Size = UDim2.new(0, 250, 0, 350)
frame.Position = UDim2.new(0.05, 0, 0.2, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0

-- Title bar (drag handle)
local titleBar = Instance.new("Frame", frame)
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(70, 70, 70)

local titleText = Instance.new("TextLabel", titleBar)
titleText.Size = UDim2.new(1, -10, 1, -10)
titleText.Position = UDim2.new(0, 5, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "Auto‑Buy Menu"
titleText.TextColor3 = Color3.new(1, 1, 1)
titleText.Font = Enum.Font.SourceSansBold
titleText.TextSize = 18

-- Minimize/restore button
local minBtn = Instance.new("TextButton", titleBar)
minBtn.Name = "MinButton"
minBtn.Size = UDim2.new(0, 30, 1, 0)
minBtn.Position = UDim2.new(1, -30, 0, 0)
minBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
minBtn.Text = "_"
minBtn.TextColor3 = Color3.new(1, 1, 1)
minBtn.Font = Enum.Font.SourceSansBold
minBtn.TextSize = 18

-- Scrollable area that will hold the item buttons
local scroll = Instance.new("ScrollingFrame", frame)
scroll.Name = "ItemList"
scroll.Size = UDim2.new(1, -4, 1, -34)
scroll.Position = UDim2.new(0, 2, 0, 32)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 6
scroll.CanvasPosition = Vector2.new(0, 0)

-- ──────────────────────────────────────────────────────────────────────
-- 5️⃣  Dragging logic for the main frame
-- ──────────────────────────────────────────────────────────────────────
local dragging = false
local dragStart = nil
local frameStart = nil

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = UserInputService:GetMouseLocation() - Vector2.new(frame.AbsolutePosition.X, frame.AbsolutePosition.Y)
        frameStart = Vector2.new(frame.AbsolutePosition.X, frame.AbsolutePosition.Y)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local newPos = UserInputService:GetMouseLocation() - dragStart
        frame.Position = UDim2.new(0, newPos.X, 0, newPos.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- ──────────────────────────────────────────────────────────────────────
-- 6️⃣  Minimize / Restore logic
-- ──────────────────────────────────────────────────────────────────────
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        -- Collapse to a thin bar
        frame.Size = UDim2.new(0, 250, 0, 30)
        scroll.Visible = false
        minBtn.Text = "▢"  -- full‑screen icon
    else
        -- Restore to original size
        frame.Size = UDim2.new(0, 250, 0, 350)
        scroll.Visible = true
        minBtn.Text = "_"
    end
end)

-- ──────────────────────────────────────────────────────────────────────
-- 7️⃣  Auto‑buy toggle per item
-- ──────────────────────────────────────────────────────────────────────
local autoBuyStates = {}   -- key: item name, value: bool

for i, item in ipairs(ITEMS) do
    autoBuyStates[item] = false

    local btn = Instance.new("TextButton", scroll)
    btn.Name = "Btn_" .. item:gsub("%s+", "_")
    btn.Size = UDim2.new(0, 220, 0, 30)
    btn.Position = UDim2.new(0, 10, 0, (i-1)*34 + 5)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.Text = "Buy " .. item
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 16

    local function toggleAutoBuy()
        autoBuyStates[item] = not autoBuyStates[item]
        btn.BackgroundColor3 = autoBuyStates[item] and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(50, 50, 50)
        btn.Text = (autoBuyStates[item] and "STOP" or "START") .. " " .. item
    end

    btn.MouseButton1Click:Connect(toggleAutoBuy)

    -- Background thread that sends the packet while toggled on
    task.spawn(function()
        while true do
            if autoBuyStates[item] then
                local success, err = pcall(function()
                    packetRemote:Event(buildPacket(item))
                end)
                if not success then
                    warn("[AutoBuy] Failed for", item, ":", err)
                end
                task.wait(0.75 + math.random() * 0.5)   -- jittered wait
            else
                task.wait(0.1)  -- idle sleep to avoid spamming the loop
            end
        end
    end)
end

-- ──────────────────────────────────────────────────────────────────────
-- 8️⃣  Final touches
-- ──────────────────────────────────────────────────────────────────────
scroll.CanvasSize = UDim2.new(0, 0, 0, #ITEMS * 34)

print("[AutoBuy] Menu loaded – click items to toggle, use '_' button to minimize.")

