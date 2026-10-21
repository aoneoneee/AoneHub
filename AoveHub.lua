-- ==================================================================
-- SNIPER HUB — FULL v15 (Euclidean Distance Math)
-- ==================================================================

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local UserInputService   = game:GetService("UserInputService")
local HttpService        = game:GetService("HttpService")
local CollectionService  = game:GetService("CollectionService")
local PetRegistry = require(ReplicatedStorage.Data.PetRegistry)
local TokenRAPController = require(ReplicatedStorage.Modules.TradeTokens.TokenRAPController)
local BuyListingRF = ReplicatedStorage.GameEvents.TradeEvents.Booths.BuyListing

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ==================================================================
-- KONSTANTA
-- ==================================================================
local SAVE_DIR  = "SniperHub"
local SAVE_FILE = SAVE_DIR .. "/SniperHub_Config.json"

local TradeWorldData = require(ReplicatedStorage.Data.TradeWorldData)
local TRADE_WORLD_PLACE_ID = TradeWorldData.PlaceId

local TRADE_EVENTS  = ReplicatedStorage.GameEvents.TradeEvents
local BoothsEvent   = TRADE_EVENTS:WaitForChild("Booths")
local ClaimBoothRE  = BoothsEvent:WaitForChild("ClaimBooth")
local RemoveBoothRE = BoothsEvent:WaitForChild("RemoveBooth")

local BoothSkinRegistry = require(ReplicatedStorage.Data.TradeBoothSkinRegistry)
local ReplicationReciever = require(ReplicatedStorage.Modules.ReplicationReciever)
local DataService = require(ReplicatedStorage.Modules.DataService)

-- ==================================================================
-- THEME & HELPER FILE
-- ==================================================================
local C = {
    bg      = Color3.fromRGB(28, 28, 35),
    sidebar = Color3.fromRGB(22, 22, 28),
    accent  = Color3.fromRGB(80, 120, 200),
    text    = Color3.fromRGB(240, 240, 240),
    textDim = Color3.fromRGB(150, 150, 160),
    success = Color3.fromRGB(50, 180, 50),
    danger  = Color3.fromRGB(200, 50, 50),
    warning = Color3.fromRGB(255, 200, 0),
    section = Color3.fromRGB(38, 38, 48),
    input   = Color3.fromRGB(55, 55, 70),
}

pcall(function() makefolder(SAVE_DIR) end)

local function encodeTbl(t)
    local ok, s = pcall(function() return HttpService:JSONEncode(t) end)
    return ok and s or "{}"
end

local function decodeTbl(s)
    if type(s) ~= "string" or s == "" then return {} end
    local ok, t = pcall(function() return HttpService:JSONDecode(s) end)
    return (ok and type(t) == "table") and t or {}
end

-- ==================================================================
-- CONFIG
-- ==================================================================
local CONFIG_DEFAULTS = {
    autoClaimEnabled     = false,
    claimSkinEnabled     = false,
    claimSkinID          = "Default",
    claimPriority        = "front", -- "front" | "back" | "random"
    autoBuyFilters       = {},
    autoListingFilters   = {},
    antiAfkEnabled       = false,
    webhookEnabled       = false,
    webhookUrl           = "",
    webhookUsername      = "Sniper Hub",
    sectionStates        = {},
    autoBuyEnabled = false,
    autoBuyFilters = {},
}

local config = {}

local function deepCopy(src)
    local out = {}
    for k, v in pairs(src) do
        out[k] = type(v) == "table" and deepCopy(v) or v
    end
    return out
end

local function loadConfig()
    local loaded = {}
    local ok, raw = pcall(readfile, SAVE_FILE)
    if ok and raw then loaded = decodeTbl(raw) end
    config = deepCopy(CONFIG_DEFAULTS)
    for k, v in pairs(loaded) do
        if type(v) == type(CONFIG_DEFAULTS[k]) or CONFIG_DEFAULTS[k] == nil then
            config[k] = v
        end
    end
end

local function saveConfig()
    pcall(writefile, SAVE_FILE, encodeTbl(config))
end

loadConfig()

_G.SniperHub = {
    Config      = config,
    SaveConfig  = saveConfig,
    Colors      = C,
    PlaceId     = TRADE_WORLD_PLACE_ID,
}

-- ==================================================================
-- SHARED STATE
-- ==================================================================
local MainState = {
    isClaimRunning      = false,
    claimThread         = nil,
    lastClaimBooth      = nil,
    lastStatus          = "Idle",
    lastAppliedSkinID   = nil,
}
_G.SniperHub.MainState = MainState

-- ==================================================================
-- BOOTH DATA HELPER
-- ==================================================================
local boothReceiver = ReplicationReciever.new("Booths")

local function isInTradeWorld()
    return game.PlaceId == TRADE_WORLD_PLACE_ID
end

local function getBoothsData()
    local ok, data = pcall(function() return boothReceiver:GetDataAsync() end)
    if ok then return data end
    return nil
end

local function getPhysicalBooths()
    local list = {}
    for _, inst in ipairs(CollectionService:GetTagged("TradeBooth")) do
        if inst:IsA("Model") then
            table.insert(list, inst)
        end
    end
    return list
end

local function getBoothInfo(booth)
    local data = getBoothsData()
    local ownerId = nil
    if data and data.Booths and data.Booths[booth.Name] then
        ownerId = data.Booths[booth.Name].Owner
    end
    local pos = booth:GetPivot().Position
    return {
        instance = booth,
        name     = booth.Name,
        posX     = pos.X,
        posZ     = pos.Z,
        ownerId  = ownerId,
    }
end

local function getMyPlayerBoothId()
    local data = getBoothsData()
    if not data or not data.Players then return nil end
    local myId = "Player_" .. tostring(player.UserId)
    local pdata = data.Players[myId]
    return pdata and pdata.Booth or nil
end

-- ==================================================================
-- LOGIC CLAIM & TELEPORT
-- ==================================================================
local function applyBoothSkin()
    if not config.claimSkinEnabled then return false end
    local skinId = config.claimSkinID
    if not skinId or skinId == "" then return false end
    if not BoothSkinRegistry[skinId] then return false end
    if MainState.lastAppliedSkinID == skinId then return false end

    local skinService = TRADE_EVENTS:FindFirstChild("TradeBoothSkinService")
    if not skinService then
        task.spawn(function()
            local s = TRADE_EVENTS:WaitForChild("TradeBoothSkinService", 10)
            if s and MainState.lastAppliedSkinID ~= skinId then
                pcall(function() s.Equip:FireServer(skinId) end)
                MainState.lastAppliedSkinID = skinId
            end
        end)
        return false
    end

    local ok = pcall(function()
        skinService.Equip:FireServer(skinId)
    end)
    if ok then
        MainState.lastAppliedSkinID = skinId
    end
    return ok
end

local function teleportToBooth(boothInstance)
    if not boothInstance then return end
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local targetPos = (boothInstance:GetPivot() * CFrame.new(0, 5, 12)).Position
    hrp.CFrame = CFrame.new(targetPos)
end

local function startClaimLoop()
    if MainState.isClaimRunning then return end
    if not isInTradeWorld() then return end
    MainState.isClaimRunning = true

    MainState.claimThread = task.spawn(function()
        task.wait(3)

        while MainState.isClaimRunning do
            local booths = getPhysicalBooths()
            if #booths == 0 then
                if _G.SniperHub.UpdateStatus then
                    _G.SniperHub.UpdateStatus("⏳ Tidak ada booth terdeteksi", C.textDim)
                end
                task.wait(30)
                continue
            end

            local infos = {}
            for _, b in ipairs(booths) do
                table.insert(infos, getBoothInfo(b))
            end

            -- ⭐ HITUNG TITIK PUSAT (CENTER POINT)
            local sumX, sumZ = 0, 0
            for _, info in ipairs(infos) do
                sumX = sumX + info.posX
                sumZ = sumZ + info.posZ
            end
            local centerX = sumX / #infos
            local centerZ = sumZ / #infos

            local myBoothId = getMyPlayerBoothId()
            local myInfo = nil
            if myBoothId then
                for _, info in ipairs(infos) do
                    if info.name == myBoothId then myInfo = info break end
                end
            end

            -- Kumpulkan booth kosong
            local claimable = {}
            for _, info in ipairs(infos) do
                if info.ownerId == nil then
                    table.insert(claimable, info)
                end
            end

            -- ⭐ SORTING BERDASARKAN JARAK EUCLIDEAN KE PUSAT
            if config.claimPriority == "front" then
                -- Depan: Jarak paling DEKAT ke pusat
                table.sort(claimable, function(a, b)
                    local distA = math.sqrt((a.posX - centerX)^2 + (a.posZ - centerZ)^2)
                    local distB = math.sqrt((b.posX - centerX)^2 + (b.posZ - centerZ)^2)
                    return distA < distB
                end)
            elseif config.claimPriority == "back" then
                -- Belakang: Jarak paling JAUH dari pusat
                table.sort(claimable, function(a, b)
                    local distA = math.sqrt((a.posX - centerX)^2 + (a.posZ - centerZ)^2)
                    local distB = math.sqrt((b.posX - centerX)^2 + (b.posZ - centerZ)^2)
                    return distA > distB
                end)
            else
                for i = #claimable, 2, -1 do
                    local j = math.random(i)
                    claimable[i], claimable[j] = claimable[j], claimable[i]
                end
            end

            local ok, msg = false, ""

            if myBoothId then
                if #claimable > 0 and myInfo then
                    local best = claimable[1]
                    local myDist = math.sqrt((myInfo.posX - centerX)^2 + (myInfo.posZ - centerZ)^2)
                    local bestDist = math.sqrt((best.posX - centerX)^2 + (best.posZ - centerZ)^2)
                    local better = false

                    if config.claimPriority == "front" then
                        better = bestDist < myDist
                    elseif config.claimPriority == "back" then
                        better = bestDist > myDist
                    end

                    if better then
                        if _G.SniperHub.UpdateStatus then
                            _G.SniperHub.UpdateStatus(string.format("🔄 Pindah prioritas"), C.warning)
                        end
                        pcall(function() RemoveBoothRE:FireServer() end)
                        task.wait(1.5)
                        pcall(function() ClaimBoothRE:FireServer(best.instance) end)
                        task.wait(1.5)

                        if getMyPlayerBoothId() then
                            MainState.lastAppliedSkinID = nil
                            applyBoothSkin()
                            teleportToBooth(best.instance)
                            ok = true
                            msg = "Re-Claim berhasil"
                        else
                            msg = "Gagal pindah"
                        end
                    else
                        applyBoothSkin()
                        ok = true
                        msg = "Booth sudah optimal"
                    end
                end
            else
                if #claimable > 0 then
                    local target = claimable[1]
                    pcall(function() ClaimBoothRE:FireServer(target.instance) end)
                    task.wait(1.5)

                    if getMyPlayerBoothId() then
                        MainState.lastAppliedSkinID = nil
                        applyBoothSkin()
                        teleportToBooth(target.instance)
                        ok = true
                        msg = "Claim berhasil"
                    else
                        msg = "Claim gagal"
                    end
                else
                    msg = "Tidak ada booth kosong"
                end
            end

            if _G.SniperHub.UpdateStatus then
                _G.SniperHub.UpdateStatus((ok and "✅ " or "⏳ ") .. msg, ok and C.success or C.textDim)
            end
            task.wait(30)
        end
        MainState.isClaimRunning = false
    end)
end

local function stopClaimLoop()
    MainState.isClaimRunning = false
    if MainState.claimThread then
        pcall(task.cancel, MainState.claimThread)
        MainState.claimThread = nil
    end
end

-- ==================================================================
-- GUI: SCREEN + MAIN FRAME + MINIMIZE
-- ==================================================================
local oldGui = playerGui:FindFirstChild("SniperHub")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SniperHub"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local minimizedCircle = Instance.new("ImageButton")
minimizedCircle.Size = UDim2.new(0, 50, 0, 50)
minimizedCircle.Position = UDim2.new(0.5, -25, 0.5, -25)
minimizedCircle.Image = "rbxassetid://78929291660435"
minimizedCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
minimizedCircle.BackgroundTransparency = 1
minimizedCircle.BorderSizePixel = 0
minimizedCircle.Visible = false
minimizedCircle.AutoButtonColor = false
minimizedCircle.Parent = screenGui
Instance.new("UICorner", minimizedCircle).CornerRadius = UDim.new(0, 15)

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 600, 0, 360)
mainFrame.Position = UDim2.new(0.5, -300, 0.5, -180)
mainFrame.BackgroundColor3 = C.bg
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 28)
titleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0.7, 0, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.Text = "🎯 Sniper Hub"
titleLabel.TextColor3 = C.text
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 12
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.BackgroundTransparency = 1
titleLabel.Parent = titleBar

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 22, 0, 22)
minimizeBtn.Position = UDim2.new(1, -50, 0, 3)
minimizeBtn.Text = "–"
minimizeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 14
minimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
minimizeBtn.BorderSizePixel = 0
minimizeBtn.AutoButtonColor = false
minimizeBtn.Parent = titleBar
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 4)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 22, 0, 22)
closeBtn.Position = UDim2.new(1, -25, 0, 3)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 11
closeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = false
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)

local lastMainPosition = mainFrame.Position
local circlePosition = nil

minimizeBtn.MouseButton1Click:Connect(function()
    lastMainPosition = mainFrame.Position
    if not circlePosition then
        circlePosition = UDim2.new(0, mainFrame.AbsolutePosition.X, 0, mainFrame.AbsolutePosition.Y)
    end
    minimizedCircle.Position = circlePosition
    mainFrame.Visible = false
    minimizedCircle.Visible = true
end)

minimizedCircle.MouseButton1Click:Connect(function()
    circlePosition = minimizedCircle.Position
    mainFrame.Position = lastMainPosition
    minimizedCircle.Visible = false
    mainFrame.Visible = true
end)

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0.22, 0, 1, -28)
sidebar.Position = UDim2.new(0, 0, 0, 28)
sidebar.BackgroundColor3 = C.sidebar
sidebar.BorderSizePixel = 0
sidebar.Parent = mainFrame
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 10)

local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(0.78, 0, 1, -34)
contentArea.Position = UDim2.new(0.22, 4, 0, 32)
contentArea.BackgroundTransparency = 1
contentArea.ClipsDescendants = true
contentArea.Parent = mainFrame

-- ==================================================================
-- HELPER UI GLOBAL
-- ==================================================================
local sectionMeta = {}

local function createSection(parent, title, sectionKey, initialHeight)
    initialHeight = initialHeight or 200
    local Section = Instance.new("Frame")
    Section.Size = UDim2.new(1, -10, 0, initialHeight)
    Section.BackgroundColor3 = C.section
    Section.BorderSizePixel = 0
    Section.ClipsDescendants = true
    Section.Parent = parent
    Instance.new("UICorner", Section).CornerRadius = UDim.new(0, 6)

    if not title then return Section, nil end

    sectionKey = sectionKey or title
    local expanded = config.sectionStates[sectionKey] ~= false

    local header = Instance.new("TextButton")
    header.Size = UDim2.new(1, 0, 0, 28)
    header.BackgroundColor3 = C.section
    header.BorderSizePixel = 0
    header.AutoButtonColor = false
    header.Font = Enum.Font.GothamBold
    header.Text = (expanded and "▼  " or "▶  ") .. title
    header.TextColor3 = C.text
    header.TextSize = 11
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.ZIndex = 20
    header.Parent = Section

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.Parent = header

    sectionMeta[Section] = {
        title = title, key = sectionKey, expanded = expanded,
        expandedHeight = initialHeight, collapsedHeight = 28, header = header,
    }

    if not expanded then
        Section.Size = UDim2.new(1, -10, 0, 28)
    end

    header.MouseButton1Click:Connect(function()
        local meta = sectionMeta[Section]
        if not meta then return end
        meta.expanded = not meta.expanded
        config.sectionStates[meta.key] = meta.expanded
        saveConfig()
        if meta.expanded then
            header.Text = "▼  " .. meta.title
            Section.Size = UDim2.new(1, -10, 0, meta.expandedHeight)
        else
            meta.expandedHeight = Section.Size.Y.Offset
            header.Text = "▶  " .. meta.title
            Section.Size = UDim2.new(1, -10, 0, meta.collapsedHeight)
        end
    end)

    return Section, header
end

local function createDropdown(parent, position, placeholder, onSelect, options)
    options = options or {}
    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, -20, 0, 28)
    Container.Position = position
    Container.BackgroundTransparency = 1
    Container.ClipsDescendants = true
    Container.ZIndex = 10
    Container.Parent = parent

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 28)
    header.BackgroundColor3 = C.input
    header.BorderSizePixel = 0
    header.ZIndex = 10
    header.Parent = Container
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 4)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Font = Enum.Font.Gotham
    btn.Text = placeholder
    btn.TextColor3 = C.text
    btn.TextSize = 9
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.ZIndex = 11
    btn.Parent = header
    local bp = Instance.new("UIPadding")
    bp.PaddingLeft = UDim.new(0, 8)
    bp.Parent = btn

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 15, 0, 20)
    arrow.Position = UDim2.new(1, -18, 0, 4)
    arrow.BackgroundTransparency = 1
    arrow.Font = Enum.Font.GothamBold
    arrow.Text = "▼"
    arrow.TextColor3 = C.textDim
    arrow.TextSize = 10
    arrow.ZIndex = 11
    arrow.Parent = header

    local list = Instance.new("ScrollingFrame")
    list.Size = UDim2.new(1, 0, 0, 0)
    list.Position = UDim2.new(0, 0, 0, 30)
    list.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
    list.BorderSizePixel = 0
    list.Visible = false
    list.ScrollBarThickness = 3
    list.CanvasSize = UDim2.new(0, 0, 0, 0)
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.ZIndex = 10
    list.Parent = Container
    Instance.new("UICorner", list).CornerRadius = UDim.new(0, 4)

    local isOpen = false
    local api = {
        Container = Container,
        HeaderButton = btn,
        ListScroll = list,
        ItemHeight = 22,
        Close = function()
            isOpen = false
            list.Visible = false
            arrow.Text = "▼"
            Container.Size = UDim2.new(1, -20, 0, 28)
        end,
    }

    local function render()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local items = typeof(options) == "function" and options() or options
        for i, item in ipairs(items) do
            local label = type(item) == "table" and item.label or tostring(item)
            local value = type(item) == "table" and item.value or item
            local ib = Instance.new("TextButton")
            ib.Size = UDim2.new(1, -4, 0, 22)
            ib.BackgroundColor3 = Color3.fromRGB(65, 65, 80)
            ib.BorderSizePixel = 0
            ib.Font = Enum.Font.Gotham
            ib.Text = tostring(label)
            ib.TextColor3 = C.text
            ib.TextSize = 8
            ib.TextXAlignment = Enum.TextXAlignment.Left
            ib.LayoutOrder = i
            ib.ZIndex = 12
            ib.Parent = list
            Instance.new("UICorner", ib).CornerRadius = UDim.new(0, 3)
            local ip = Instance.new("UIPadding")
            ip.PaddingLeft = UDim.new(0, 6)
            ip.Parent = ib
            ib.MouseButton1Click:Connect(function()
                btn.Text = tostring(label)
                api.Close()
                onSelect(value)
            end)
        end
        local layout = list:FindFirstChildOfClass("UIListLayout")
        if not layout then
            layout = Instance.new("UIListLayout")
            layout.Padding = UDim.new(0, 2)
            layout.Parent = list
        end
        local total = #items * 24 + 8
        list.Size = UDim2.new(1, 0, 0, math.min(total, 160))
        Container.Size = UDim2.new(1, -20, 0, math.min(total, 160) + 32)
    end

    btn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        if isOpen then
            render()
            list.Visible = true
            arrow.Text = "▲"
        else
            api.Close()
        end
    end)

    return api
end

local function makeToggle(parent, yPos, label, configKey, onText, offText)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 26)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.BackgroundColor3 = config[configKey] and C.success or Color3.fromRGB(70, 70, 85)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.Text = config[configKey] and (onText or label .. ": ON") or (offText or label .. ": OFF")
    btn.TextColor3 = C.text
    btn.TextSize = 9
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    btn.MouseButton1Click:Connect(function()
        config[configKey] = not config[configKey]
        btn.Text = config[configKey] and (onText or label .. ": ON") or (offText or label .. ": OFF")
        btn.BackgroundColor3 = config[configKey] and C.success or Color3.fromRGB(70, 70, 85)
        saveConfig()
    end)
    return btn
end

-- ==================================================================
-- TAB SYSTEM
-- ==================================================================
local TABS = {
    {name = "Main",        label = "🎯 Main"},
    {name = "AutoBuy",     label = "🛒 AutoBuy"},
    {name = "AutoListing", label = "📋 AutoListing"},
    {name = "Misc",        label = "⚙️ Misc"},
}

local tabFrames, tabBtns = {}, {}
local activeTab = nil

for i, tab in ipairs(TABS) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.82, 0, 0, 24)
    btn.Position = UDim2.new(0.09, 0, 0, 8 + (i-1)*30)
    btn.Text = tab.label
    btn.TextColor3 = C.textDim
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 9
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.Parent = btn
    tabBtns[tab.name] = btn

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Visible = false
    frame.Parent = contentArea
    tabFrames[tab.name] = frame
end

local function switchTab(name)
    for n, f in pairs(tabFrames) do f.Visible = (n == name) end
    for n, b in pairs(tabBtns) do
        b.BackgroundColor3 = (n == name) and C.accent or Color3.fromRGB(32, 32, 40)
        b.TextColor3       = (n == name) and C.text   or C.textDim
    end
    activeTab = name
end

for n, b in pairs(tabBtns) do
    b.MouseButton1Click:Connect(function() switchTab(n) end)
end

do
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

do
    local dragging, dragStart, startPos
    minimizedCircle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = minimizedCircle.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            minimizedCircle.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- ==================================================================
-- ================= TAB MAIN (ISOLATED DO-END) =====================
-- ==================================================================
do
    local mainTab = tabFrames["Main"]

    local mainScroll = Instance.new("ScrollingFrame")
    mainScroll.Size = UDim2.new(1, -10, 1, -10)
    mainScroll.Position = UDim2.new(0, 5, 0, 5)
    mainScroll.BackgroundTransparency = 1
    mainScroll.BorderSizePixel = 0
    mainScroll.ScrollBarThickness = 4
    mainScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    mainScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    mainScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    mainScroll.Parent = mainTab

    local mainLayout = Instance.new("UIListLayout")
    mainLayout.Padding = UDim.new(0, 6)
    mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
    mainLayout.Parent = mainScroll

    -- SECTION 1: STATUS
    local StatusSection = createSection(mainScroll, "📊 Status", "mainStatus", 120)
    StatusSection.LayoutOrder = 1

    local worldStatusLbl = Instance.new("TextLabel")
    worldStatusLbl.Size = UDim2.new(1, -20, 0, 16)
    worldStatusLbl.Position = UDim2.new(0, 10, 0, 32)
    worldStatusLbl.BackgroundTransparency = 1
    worldStatusLbl.Font = Enum.Font.Gotham
    worldStatusLbl.TextSize = 9
    worldStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
    worldStatusLbl.TextColor3 = C.text
    worldStatusLbl.Parent = StatusSection

    local ownedBoothLbl = Instance.new("TextLabel")
    ownedBoothLbl.Size = UDim2.new(1, -20, 0, 16)
    ownedBoothLbl.Position = UDim2.new(0, 10, 0, 50)
    ownedBoothLbl.BackgroundTransparency = 1
    ownedBoothLbl.Font = Enum.Font.Gotham
    ownedBoothLbl.TextSize = 9
    ownedBoothLbl.TextXAlignment = Enum.TextXAlignment.Left
    ownedBoothLbl.TextColor3 = C.text
    ownedBoothLbl.Parent = StatusSection

    local mainStatusLbl = Instance.new("TextLabel")
    mainStatusLbl.Size = UDim2.new(1, -20, 0, 16)
    mainStatusLbl.Position = UDim2.new(0, 10, 0, 68)
    mainStatusLbl.BackgroundTransparency = 1
    mainStatusLbl.Font = Enum.Font.GothamBold
    mainStatusLbl.TextSize = 9
    mainStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
    mainStatusLbl.TextColor3 = C.textDim
    mainStatusLbl.Text = "Status: Idle"
    mainStatusLbl.Parent = StatusSection

    local refreshStatusBtn = Instance.new("TextButton")
    refreshStatusBtn.Size = UDim2.new(1, -20, 0, 22)
    refreshStatusBtn.Position = UDim2.new(0, 10, 0, 90)
    refreshStatusBtn.BackgroundColor3 = C.accent
    refreshStatusBtn.BorderSizePixel = 0
    refreshStatusBtn.Font = Enum.Font.GothamBold
    refreshStatusBtn.Text = "🔄 Refresh Status"
    refreshStatusBtn.TextColor3 = C.text
    refreshStatusBtn.TextSize = 9
    refreshStatusBtn.Parent = StatusSection
    Instance.new("UICorner", refreshStatusBtn).CornerRadius = UDim.new(0, 4)

    -- Ekspos callback update status ke global _G agar bisa dipanggil loop di atas
    _G.SniperHub.UpdateStatus = function(text, color)
        if mainStatusLbl and mainStatusLbl.Parent then
            mainStatusLbl.Text = "Status: " .. text
            mainStatusLbl.TextColor3 = color or C.textDim
        end
    end

    local function refreshOwnedBoothInfo()
        if not isInTradeWorld() then
            worldStatusLbl.Text = "🌍 World: Main World"
            worldStatusLbl.TextColor3 = C.danger
            ownedBoothLbl.Text = "🏛️ Booth: -"
            ownedBoothLbl.TextColor3 = C.textDim
            return
        end
        worldStatusLbl.Text = "🌍 World: Trade World ✅"
        worldStatusLbl.TextColor3 = C.success

        local data = getBoothsData()
        local myId = "Player_" .. tostring(player.UserId)
        local pdata = data and data.Players and data.Players[myId]
        if pdata and pdata.Booth then
            ownedBoothLbl.Text = "🏛️ Booth: " .. tostring(pdata.Booth)
            ownedBoothLbl.TextColor3 = C.success
        else
            ownedBoothLbl.Text = "🏛️ Booth: Belum punya"
            ownedBoothLbl.TextColor3 = C.warning
        end
    end

    refreshStatusBtn.MouseButton1Click:Connect(refreshOwnedBoothInfo)
    task.spawn(function()
        while screenGui.Parent do
            task.wait(2)
            pcall(refreshOwnedBoothInfo)
        end
    end)

    -- SECTION 2: KONFIGURASI CLAIM
    local ConfigSection = createSection(mainScroll, "⚙️ Konfigurasi Claim Booth", "mainConfig", 240)
    ConfigSection.LayoutOrder = 2

    local startClaimBtn = Instance.new("TextButton")
    startClaimBtn.Size = UDim2.new(1, -20, 0, 34)
    startClaimBtn.Position = UDim2.new(0, 10, 0, 32)
    startClaimBtn.BackgroundColor3 = C.success
    startClaimBtn.BorderSizePixel = 0
    startClaimBtn.Font = Enum.Font.GothamBold
    startClaimBtn.Text = "▶️ MULAI CLAIM BOOTH"
    startClaimBtn.TextColor3 = C.text
    startClaimBtn.TextSize = 11
    startClaimBtn.Parent = ConfigSection
    Instance.new("UICorner", startClaimBtn).CornerRadius = UDim.new(0, 5)

    local priorityLbl = Instance.new("TextLabel")
    priorityLbl.Size = UDim2.new(1, -20, 0, 14)
    priorityLbl.Position = UDim2.new(0, 10, 0, 82)
    priorityLbl.BackgroundTransparency = 1
    priorityLbl.Font = Enum.Font.Gotham
    priorityLbl.Text = "📍 Prioritas Posisi Booth:"
    priorityLbl.TextColor3 = C.textDim
    priorityLbl.TextSize = 8
    priorityLbl.TextXAlignment = Enum.TextXAlignment.Left
    priorityLbl.Parent = ConfigSection

    local PRIORITY_OPTIONS = {
        {label = "⬆️ Paling Depan (Tengah Map)", value = "front"},
        {label = "⬇️ Paling Belakang (Ujung Map)", value = "back"},
        {label = "🎲 Random", value = "random"},
    }
    local priorityLabels = {
        front  = "⬆️ Paling Depan",
        back   = "⬇️ Paling Belakang",
        random = "🎲 Random",
    }

    local priorityDropdown = createDropdown(
        ConfigSection,
        UDim2.new(0, 10, 0, 98),
        priorityLabels[config.claimPriority] or "📍 Pilih Prioritas",
        function(v) config.claimPriority = v; saveConfig() end,
        PRIORITY_OPTIONS
    )
    priorityDropdown.HeaderButton.Text = priorityLabels[config.claimPriority] or "📍 Pilih Prioritas"

    -- TOMBOL DEBUG
    local debugBtn = Instance.new("TextButton")
    debugBtn.Size = UDim2.new(1, -20, 0, 22)
    debugBtn.Position = UDim2.new(0, 10, 0, 132)
    debugBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
    debugBtn.BorderSizePixel = 0
    debugBtn.Font = Enum.Font.GothamBold
    debugBtn.Text = "🛠️ Debug Data Booth (Cek Console)"
    debugBtn.TextColor3 = C.text
    debugBtn.TextSize = 8
    debugBtn.Parent = ConfigSection
    Instance.new("UICorner", debugBtn).CornerRadius = UDim.new(0, 3)

    debugBtn.MouseButton1Click:Connect(function()
        local booths = getPhysicalBooths()
        if #booths == 0 then return print("Tidak ada booth!") end
        local infos = {}
        for _, b in ipairs(booths) do table.insert(infos, getBoothInfo(b)) end
        
        local sumX, sumZ = 0, 0
        for _, info in ipairs(infos) do sumX = sumX + info.posX; sumZ = sumZ + info.posZ end
        local cx, cz = sumX / #infos, sumZ / #infos
        
        print("=== DEBUG BOOTH ===")
        print("Center Point: X="..math.floor(cx).." Z="..math.floor(cz))
        
        local sorted = {}
        for _, info in ipairs(infos) do
            table.insert(sorted, {
                name = info.name, x = info.posX, z = info.posZ,
                dist = math.sqrt((info.posX - cx)^2 + (info.posZ - cz)^2),
                owner = info.ownerId and "Taken" or "KOSONG"
            })
        end
        table.sort(sorted, function(a,b) return a.dist < b.dist end)
        
        print("Urutan dari Paling Depan (Jarak < ke Pusat):")
        for i = 1, math.min(5, #sorted) do
            print(string.format("%d. %s | X:%.0f Z:%.0f | Jarak:%.1f | %s", 
                i, sorted[i].name, sorted[i].x, sorted[i].z, sorted[i].dist, sorted[i].owner))
        end
        print("=== END DEBUG ===")
    end)

    makeToggle(
        ConfigSection, 162,
        "Apply Booth Skin", "claimSkinEnabled",
        "🎨 Apply Skin: ON", "🎨 Apply Skin: OFF"
    )

    local hintLbl = Instance.new("TextLabel")
    hintLbl.Size = UDim2.new(1, -20, 0, 24)
    hintLbl.Position = UDim2.new(0, 10, 0, 200)
    hintLbl.BackgroundTransparency = 1
    hintLbl.Font = Enum.Font.Gotham
    hintLbl.TextSize = 8
    hintLbl.TextColor3 = C.textDim
    hintLbl.TextWrapped = true
    hintLbl.TextXAlignment = Enum.TextXAlignment.Left
    hintLbl.Text = "ℹ️ Cek tiap 30 detik. Auto Re-Claim jika ada booth prioritas lebih baik. Auto teleport setelah claim."
    hintLbl.Parent = ConfigSection

    local function syncClaimUI()
        local running = MainState.isClaimRunning
        startClaimBtn.Text = running and "⏹️ STOP CLAIM" or "▶️ MULAI CLAIM BOOTH"
        startClaimBtn.BackgroundColor3 = running and C.danger or C.success
    end

    startClaimBtn.MouseButton1Click:Connect(function()
        if MainState.isClaimRunning then
            config.autoClaimEnabled = false
            saveConfig()
            stopClaimLoop()
            syncClaimUI()
            _G.SniperHub.UpdateStatus("⏹️ Stopped: manual STOP", C.textDim)
        else
            if not isInTradeWorld() then
                _G.SniperHub.UpdateStatus("⚠️ Harus di Trade World!", C.warning)
                return
            end
            config.autoClaimEnabled = true
            saveConfig()
            startClaimLoop()
            syncClaimUI()
            _G.SniperHub.UpdateStatus("🚀 Auto-start: manual START", C.accent)
        end
    end)

    -- SECTION 3: DAFTAR SKIN
    local SkinSection = createSection(mainScroll, "🎨 Pilih Booth Skin", "mainSkin", 290)
    SkinSection.LayoutOrder = 3

    local skinSearch = Instance.new("TextBox")
    skinSearch.Size = UDim2.new(1, -20, 0, 22)
    skinSearch.Position = UDim2.new(0, 10, 0, 32)
    skinSearch.BackgroundColor3 = C.input
    skinSearch.BorderSizePixel = 0
    skinSearch.Font = Enum.Font.Gotham
    skinSearch.PlaceholderText = "🔍 Cari booth skin..."
    skinSearch.Text = ""
    skinSearch.TextColor3 = C.text
    skinSearch.TextSize = 9
    skinSearch.ClearTextOnFocus = false
    skinSearch.Parent = SkinSection
    Instance.new("UICorner", skinSearch).CornerRadius = UDim.new(0, 4)

    local skinListFrame = Instance.new("ScrollingFrame")
    skinListFrame.Size = UDim2.new(1, -20, 0, 200)
    skinListFrame.Position = UDim2.new(0, 10, 0, 60)
    skinListFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    skinListFrame.BorderSizePixel = 0
    skinListFrame.ScrollBarThickness = 3
    skinListFrame.ScrollBarImageColor3 = C.accent
    skinListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    skinListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    skinListFrame.Parent = SkinSection
    Instance.new("UICorner", skinListFrame).CornerRadius = UDim.new(0, 3)
    local skinListLayout = Instance.new("UIListLayout")
    skinListLayout.Padding = UDim.new(0, 2)
    skinListLayout.Parent = skinListFrame

    local function getOwnedSkinSet()
        local set = { Default = true }
        local ok, data = pcall(function() return DataService:GetData() end)
        if ok and data and data.TradeBoothSkinData and data.TradeBoothSkinData.OwnedSkins then
            for name, val in pairs(data.TradeBoothSkinData.OwnedSkins) do
                if typeof(val) == "boolean" and val then
                    set[name] = true
                elseif typeof(val) == "number" and val > 0 then
                    set[name] = true
                end
            end
        end
        return set
    end

    local function renderSkinList()
        for _, c in ipairs(skinListFrame:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end

        local owned = getOwnedSkinSet()
        local search = skinSearch.Text:lower()
        local items = {}

        for skinId, info in pairs(BoothSkinRegistry) do
            local displayName = info.DisplayName or skinId
            local rarity = info.Rarity or "?"
            local isOwned = owned[skinId] == true
            local isSelected = config.claimSkinID == skinId

            if search == "" or displayName:lower():find(search, 1, true) then
                table.insert(items, {
                    id = skinId, display = displayName,
                    rarity = rarity, owned = isOwned, selected = isSelected,
                })
            end
        end

        table.sort(items, function(a, b)
            if a.selected ~= b.selected then return a.selected end
            if a.owned ~= b.owned then return a.owned end
            return a.display < b.display
        end)

        for i, item in ipairs(items) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -4, 0, 24)
            btn.BackgroundColor3 = item.selected and C.success
                or (item.owned and Color3.fromRGB(55, 55, 70) or Color3.fromRGB(40, 40, 50))
            btn.BorderSizePixel = 0
            btn.Font = Enum.Font.Gotham
            btn.Text = string.format("%s %s [%s]%s",
                item.selected and "✓" or (item.owned and "●" or "🔒"),
                item.display, item.rarity,
                item.owned and "" or " (unowned)")
            btn.TextColor3 = item.owned and C.text or C.textDim
            btn.TextSize = 8
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.LayoutOrder = i
            btn.AutoButtonColor = false
            btn.Parent = skinListFrame
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
            local p = Instance.new("UIPadding")
            p.PaddingLeft = UDim.new(0, 6)
            p.Parent = btn

            btn.MouseButton1Click:Connect(function()
                if not item.owned then
                    _G.SniperHub.UpdateStatus("⚠️ Skin belum dimiliki", C.warning)
                    return
                end
                config.claimSkinID = item.id
                MainState.lastAppliedSkinID = nil
                saveConfig()
                renderSkinList()
            end)
        end
    end

    skinSearch:GetPropertyChangedSignal("Text"):Connect(renderSkinList)

    local refreshSkinBtn = Instance.new("TextButton")
    refreshSkinBtn.Size = UDim2.new(1, -20, 0, 20)
    refreshSkinBtn.Position = UDim2.new(0, 10, 0, 264)
    refreshSkinBtn.BackgroundColor3 = C.accent
    refreshSkinBtn.BorderSizePixel = 0
    refreshSkinBtn.Font = Enum.Font.GothamBold
    refreshSkinBtn.Text = "🔄 Refresh Daftar Skin"
    refreshSkinBtn.TextColor3 = C.text
    refreshSkinBtn.TextSize = 8
    refreshSkinBtn.Parent = SkinSection
    Instance.new("UICorner", refreshSkinBtn).CornerRadius = UDim.new(0, 3)
    refreshSkinBtn.MouseButton1Click:Connect(renderSkinList)

    renderSkinList()

    -- INIT TAB MAIN (Auto Start)
    syncClaimUI()
    if config.autoClaimEnabled then
        if isInTradeWorld() then
            task.delay(2, function()
                startClaimLoop()
                syncClaimUI()
                _G.SniperHub.UpdateStatus("🚀 Auto-start: script load", C.accent)
            end)
        else
            _G.SniperHub.UpdateStatus("⏳ Auto Claim aktif — menunggu Trade World", C.warning)
        end
    end

    -- Watcher pindah world
    local lastInTradeWorld = isInTradeWorld()
    task.spawn(function()
        while screenGui.Parent do
            task.wait(1)
            local now = isInTradeWorld()
            if now ~= lastInTradeWorld then
                lastInTradeWorld = now
                if now then
                    if config.autoClaimEnabled then
                        startClaimLoop()
                        syncClaimUI()
                        _G.SniperHub.UpdateStatus("🚀 Auto-start: enter Trade World", C.accent)
                    end
                else
                    if MainState.isClaimRunning then
                        stopClaimLoop()
                        syncClaimUI()
                        _G.SniperHub.UpdateStatus("⏹️ Stopped: exit Trade World", C.textDim)
                    end
                end
            end
        end
    end)

end -- END OF TAB MAIN BLOCK

-- ==================================================================
-- PLACEHOLDER TAB LAINNYA
-- ==================================================================
local function makePlaceholder(tabName, text)
    local f = tabFrames[tabName]
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 1, -20)
    lbl.Position = UDim2.new(0, 10, 0, 10)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = text
    lbl.TextColor3 = C.textDim
    lbl.TextSize = 14
    lbl.TextWrapped = true
    lbl.Parent = f
end

-- ==================================================================
-- ================= TAB AUTO BUY (ISOLATED DO-END) =================
-- ==================================================================
do
    local buyTab = tabFrames["AutoBuy"]
    
    -- ⭐ PERBAIKAN 1: Jeda sedikit agar GUI dari Tab Main selesai dimuat
    task.wait(0.5)

    -- Sanitasi Config
    if type(config.autoBuyFilters) ~= "table" then config.autoBuyFilters = {} end
    for i = 1, 4 do
        local f = config.autoBuyFilters[i]
        if type(f) ~= "table" then f = {} end
        if type(f.pets) ~= "table" then f.pets = {} end
        if type(f.mutations) ~= "table" then f.mutations = {} end
        f.enabled = f.enabled or false
        f.maxPrice = tonumber(f.maxPrice) or 0
        f.minWeight = tonumber(f.minWeight) or 0
        config.autoBuyFilters[i] = f
    end
    saveConfig()

    local buyScroll = Instance.new("ScrollingFrame")
    buyScroll.Size = UDim2.new(1, -10, 1, -10)
    buyScroll.Position = UDim2.new(0, 5, 0, 5)
    buyScroll.BackgroundTransparency = 1
    buyScroll.BorderSizePixel = 0
    buyScroll.ScrollBarThickness = 4
    buyScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    buyScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    buyScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    buyScroll.Parent = buyTab

    local buyLayout = Instance.new("UIListLayout")
    buyLayout.Padding = UDim.new(0, 6)
    buyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    buyLayout.Parent = buyScroll

    -- ==============================================================
    -- HELPER
    -- ==============================================================
    local function getAllPets()
        local list = {}
        -- ⭐ PERBAIKAN 2: Gunakan pcall agar aman jika PetRegistry telat dimuat
        local ok = pcall(function()
            for name, _ in pairs(PetRegistry.PetList) do
                table.insert(list, name)
            end
        end)
        if not ok or #list == 0 then
            -- Fallback darurat jika gagal load
            list = {"Huge Cat", "Titan Dog", "Godly Dragon"} 
        end
        table.sort(list)
        return list
    end

    local function getMyTokens()
        local ok, data = pcall(function() return DataService:GetData() end)
        if ok and data and data.TradeData and data.TradeData.Tokens then
            return data.TradeData.Tokens
        end
        return 0
    end

    -- ==============================================================
    -- LOGIC LOOP
    -- ==============================================================
    -- ⭐ Penyimpanan state
local isBuying = false
local buyConnection = nil
local scannedListings = {}  -- Mencegah scan berulang
local recentlyFailed = {}   -- Mencegah spam barang yang sudah tidak ada

-- Fungsi pembantu untuk mengecek 1 listing
local function processListing(sellerId, listingUUID, listing)
    if not isBuying then return end
    if not listing or listing.ItemType ~= "Pet" then return end

    if scannedListings[listingUUID] then return end

    local data = getBoothsData()
    if not data or not data.Players[sellerId] or not data.Players[sellerId].Items then return end
    
    local item = data.Players[sellerId].Items[listing.ItemId]
    if not item then return end

    local petType = item.PetType or (item.PetData and item.PetData.PetType) or "?"
    local baseWeight = item.BaseWeight or (item.PetData and item.PetData.BaseWeight) or 0
    local mutation = item.MutationType or (item.PetData and item.PetData.MutationType) or "Normal"
    local price = listing.Price or 999999
    if mutation == "m" or mutation == "None" then mutation = "Normal" end

    for i, filter in ipairs(config.autoBuyFilters) do
        if filter.enabled then
            local hasPetFilter = false
            for _ in pairs(filter.pets) do hasPetFilter = true break end
            local typeMatch = false
            if hasPetFilter then
                typeMatch = filter.pets[petType] == true
            end

            local priceMatch = (filter.maxPrice == 0) or (price <= filter.maxPrice)
            local weightMatch = (filter.minWeight == 0) or (baseWeight >= filter.minWeight)

            local hasMutFilter = false
            for _ in pairs(filter.mutations) do hasMutFilter = true break end
            local mutMatch = true
            if hasMutFilter then
                mutMatch = filter.mutations[mutation] == true
            end

            if typeMatch and priceMatch and weightMatch and mutMatch then
                local myTokens = getMyTokens()
                
                if myTokens >= price and not recentlyFailed[listingUUID] then
                    print(string.format("[AutoBuy] 🎯 SNIPE! %s (%s) | Weight: %.1f | Price: %d", petType, mutation, baseWeight, price))
                    
                    -- ⭐ PERBAIKAN: Cari objek Player berdasarkan UserId
                    local userIdStr = sellerId:match("Player_(%-?%d+)")
                    local userId = userIdStr and tonumber(userIdStr)
                    local sellerPlayerObj = userId and Players:GetPlayerByUserId(userId)
                    
                    -- Jika player ada di server
                    if sellerPlayerObj then
                        local success, err = pcall(function() 
                            BuyListingRF:InvokeServer(sellerPlayerObj, listingUUID) 
                        end)
                        
                        if success then
                            scannedListings[listingUUID] = true
                            print("[AutoBuy] ✅ Pembelian berhasil ditembak!")
                        else
                            warn("[AutoBuy] ❌ Gagal beli:", err)
                            recentlyFailed[listingUUID] = true
                            task.delay(5, function() recentlyFailed[listingUUID] = nil end)
                        end
                    else
                        print("[AutoBuy] ⚠️ Seller (UserId: ".. tostring(userId) ..") sudah keluar dari server.")
                        recentlyFailed[listingUUID] = true
                        task.delay(5, function() recentlyFailed[listingUUID] = nil end)
                    end

                    task.wait(1.5) 
                end
                return 
            end
        end
    end
end

local function startBuyLoop()
    if isBuying then return end
    isBuying = true
    table.clear(scannedListings) -- Reset data scan awal
    table.clear(recentlyFailed)

    -- ⭐ 1. SCAN AWAL (Hanya berjalan 1x putaran)
    print("[AutoBuy] Memindai listing yang sudah ada...")
    task.spawn(function()
        local data = getBoothsData()
        if data and data.Players then
            for sellerId, pData in pairs(data.Players) do
                if not isBuying then break end
                if pData.Listings then
                    for listUUID, listing in pairs(pData.Listings) do
                        if not isBuying then break end
                        processListing(sellerId, listUUID, listing)
                    end
                end
            end
        end
        print("[AutoBuy] Scan awal selesai. Beralih ke mode Siaga (Event).")
    end)

    -- ⭐ 2. EVENT LISTENER (Untuk listing baru setelah START)
    buyConnection = boothReceiver:GetPathSignal("Players/*/Listings/*"):Connect(function(sellerId, listingUUID)
        if not isBuying then return end
        
        local data = getBoothsData()
        if data and data.Players and data.Players[sellerId] and data.Players[sellerId].Listings then
            local listing = data.Players[sellerId].Listings[listingUUID]
            if listing then
                -- Hapus dari daftar scanned agar barang ini diproses kembali (karena ini event baru)
                scannedListings[listingUUID] = nil 
                task.spawn(function()
                    processListing(sellerId, listingUUID, listing)
                end)
            end
        end
    end)
    
    print("[AutoBuy] ✅ Sistem Sniper Aktif (Scan Awal + Event Listener)")
end

local function stopBuyLoop()
    isBuying = false
    if buyConnection then
        buyConnection:Disconnect()
        buyConnection = nil
    end
    print("[AutoBuy] ❌ Event Listener Dimatikan.")
end
    
    -- ==============================================================
    -- SECTION 1: KONTROL UTAMA
    -- ==============================================================
    local ControlSection = createSection(buyScroll, "⚙️ Kontrol Sniper", "buyControl", 110)
    ControlSection.LayoutOrder = 1

    local startBuyBtn = Instance.new("TextButton")
    startBuyBtn.Size = UDim2.new(1, -20, 0, 34)
    startBuyBtn.Position = UDim2.new(0, 10, 0, 28)
    startBuyBtn.BackgroundColor3 = config.autoBuyEnabled and C.danger or C.success
    startBuyBtn.BorderSizePixel = 0
    startBuyBtn.Font = Enum.Font.GothamBold
    startBuyBtn.Text = config.autoBuyEnabled and "⏹️ STOP SNIPER" or "▶️ MULAI SNIPER"
    startBuyBtn.TextColor3 = C.text
    startBuyBtn.TextSize = 11
    startBuyBtn.Parent = ControlSection
    Instance.new("UICorner", startBuyBtn).CornerRadius = UDim.new(0, 5)

    local tokenStatusLbl = Instance.new("TextLabel")
    tokenStatusLbl.Size = UDim2.new(1, -20, 0, 14)
    tokenStatusLbl.Position = UDim2.new(0, 10, 0, 70)
    tokenStatusLbl.BackgroundTransparency = 1
    tokenStatusLbl.Font = Enum.Font.Gotham
    tokenStatusLbl.Text = "💰 Tokens: Loading..."
    tokenStatusLbl.TextColor3 = C.warning
    tokenStatusLbl.TextSize = 9
    tokenStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
    tokenStatusLbl.Parent = ControlSection

    task.spawn(function()
        while screenGui.Parent do
            task.wait(2)
            if tokenStatusLbl and tokenStatusLbl.Parent then
                tokenStatusLbl.Text = "💰 Tokens: " .. tostring(getMyTokens())
            end
        end
    end)

    startBuyBtn.MouseButton1Click:Connect(function()
        if isBuying then
            config.autoBuyEnabled = false
            saveConfig()
            stopBuyLoop()
            startBuyBtn.Text = "▶️ MULAI SNIPER"
            startBuyBtn.BackgroundColor3 = C.success
        else
            local hasActiveFilter = false
            for _, f in ipairs(config.autoBuyFilters) do
                if f.enabled then hasActiveFilter = true break end
            end
            
            if not hasActiveFilter then
                _G.SniperHub.UpdateStatus("⚠️ Aktifkan minimal 1 filter!", C.warning)
                return
            end

            config.autoBuyEnabled = true
            saveConfig()
            startBuyBtn.Text = "⏹️ STOP SNIPER"
            startBuyBtn.BackgroundColor3 = C.danger
            startBuyLoop()
        end
    end)

    -- ==============================================================
    -- FUNGSI POPUP (Dipisah agar tidak crash)
    -- ==============================================================
    local allPets = getAllPets()
    
    local function createPopup(titleText, items, currentSelected, onSelect)
        local popupGui = Instance.new("ScreenGui")
        popupGui.Name = "SniperHubPopup"
        popupGui.DisplayOrder = 999
        popupGui.ResetOnSpawn = false
        popupGui.Parent = playerGui

        local popup = Instance.new("Frame")
        popup.Size = UDim2.new(0, 350, 0, 400)
        popup.Position = UDim2.new(0.5, -175, 0.5, -200)
        popup.BackgroundColor3 = C.bg
        popup.BorderSizePixel = 0
        popup.Parent = popupGui
        Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 8)
        
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, 0, 0, 28)
        title.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
        title.Text = titleText
        title.TextColor3 = C.text
        title.Font = Enum.Font.GothamBold
        title.TextSize = 11
        title.Parent = popup
        Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

        local close = Instance.new("TextButton")
        close.Size = UDim2.new(0, 22, 0, 22)
        close.Position = UDim2.new(1, -26, 0, 3)
        close.BackgroundColor3 = C.danger
        close.Text = "X"
        close.TextColor3 = C.text
        close.Font = Enum.Font.GothamBold
        close.TextSize = 10
        close.Parent = popup
        Instance.new("UICorner", close).CornerRadius = UDim.new(0, 4)
        close.MouseButton1Click:Connect(function() popupGui:Destroy() end)

        local search = Instance.new("TextBox")
        search.Size = UDim2.new(1, -20, 0, 24)
        search.Position = UDim2.new(0, 10, 0, 35)
        search.BackgroundColor3 = C.input
        search.BorderSizePixel = 0
        search.Font = Enum.Font.Gotham
        search.PlaceholderText = "🔍 Cari..."
        search.Text = ""
        search.TextColor3 = C.text
        search.TextSize = 9
        search.ClearTextOnFocus = false
        search.Parent = popup
        Instance.new("UICorner", search).CornerRadius = UDim.new(0, 4)

        local scr = Instance.new("ScrollingFrame")
        scr.Size = UDim2.new(1, -20, 1, -70)
        scr.Position = UDim2.new(0, 10, 0, 65)
        scr.BackgroundTransparency = 1
        scr.ScrollBarThickness = 3
        scr.CanvasSize = UDim2.new(0, 0, 0, 0)
        scr.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scr.Parent = popup

        local lay = Instance.new("UIListLayout")
        lay.Padding = UDim.new(0, 2)
        lay.Parent = scr

        local render = function()
            for _, c in ipairs(scr:GetChildren()) do 
                if c:IsA("TextButton") then c:Destroy() end 
            end
            local s = search.Text:lower()
            for i, item in ipairs(items) do
                if s == "" or item:lower():find(s, 1, true) then
                    local isSel = currentSelected[item] == true
                    local btn = Instance.new("TextButton")
                    btn.Size = UDim2.new(1, -4, 0, 22)
                    btn.BackgroundColor3 = isSel and C.success or Color3.fromRGB(55, 55, 70)
                    btn.BorderSizePixel = 0
                    btn.Font = Enum.Font.Gotham
                    btn.Text = string.format("%s %s", isSel and "✓" or "○", item)
                    btn.TextColor3 = C.text
                    btn.TextSize = 9
                    btn.TextXAlignment = Enum.TextXAlignment.Left
                    btn.LayoutOrder = i
                    btn.Parent = scr
                    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
                    local pad = Instance.new("UIPadding")
                    pad.PaddingLeft = UDim.new(0, 6)
                    pad.Parent = btn

                    btn.MouseButton1Click:Connect(function()
                        currentSelected[item] = not isSel and true or nil
                        saveConfig()
                        search.Text = "" 
                        render()
                        onSelect()
                    end)
                end
            end
        end
        search:GetPropertyChangedSignal("Text"):Connect(render)
        render()
    end

    -- ==============================================================
    -- PEMBUAT SECTION FILTER (Dengan Jeda Aman)
    -- ==============================================================
    local function buildFilterSection(index)
        local fData = config.autoBuyFilters[index]
        local Section = createSection(buyScroll, "🎯 Filter Sniper #" .. index, "buyFilter" .. index, 400)
        Section.LayoutOrder = index + 1

        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.new(1, -20, 0, 26)
        toggleBtn.Position = UDim2.new(0, 10, 0, 32)
        toggleBtn.BackgroundColor3 = fData.enabled and C.success or Color3.fromRGB(70, 70, 85)
        toggleBtn.BorderSizePixel = 0
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.Text = fData.enabled and "Filter ON" or "Filter OFF"
        toggleBtn.TextColor3 = C.text
        toggleBtn.TextSize = 9
        toggleBtn.Parent = Section
        Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 4)

        toggleBtn.MouseButton1Click:Connect(function()
            fData.enabled = not fData.enabled
            saveConfig()
            toggleBtn.Text = fData.enabled and "Filter ON" or "Filter OFF"
            toggleBtn.BackgroundColor3 = fData.enabled and C.success or Color3.fromRGB(70, 70, 85)
        end)

        local priceLbl = Instance.new("TextLabel")
        priceLbl.Size = UDim2.new(0.55, -15, 0, 16)
        priceLbl.Position = UDim2.new(0, 10, 0, 66)
        priceLbl.Text = "Max Harga (Tokens, 0=All):"
        priceLbl.TextColor3 = C.textDim
        priceLbl.Font = Enum.Font.Gotham
        priceLbl.TextSize = 8
        priceLbl.TextXAlignment = Enum.TextXAlignment.Left
        priceLbl.BackgroundTransparency = 1
        priceLbl.Parent = Section

        local priceInput = Instance.new("TextBox")
        priceInput.Size = UDim2.new(0.45, -15, 0, 20)
        priceInput.Position = UDim2.new(0.55, 5, 0, 63)
        priceInput.BackgroundColor3 = C.input
        priceInput.BorderSizePixel = 0
        priceInput.Font = Enum.Font.Gotham
        priceInput.Text = tostring(fData.maxPrice)
        priceInput.TextColor3 = C.text
        priceInput.TextSize = 9
        priceInput.Parent = Section
        Instance.new("UICorner", priceInput).CornerRadius = UDim.new(0, 3)
        priceInput.FocusLost:Connect(function()
            local n = tonumber(priceInput.Text) or 0
            fData.maxPrice = n
            priceInput.Text = tostring(n)
            saveConfig()
        end)

        local weightLbl = Instance.new("TextLabel")
        weightLbl.Size = UDim2.new(0.55, -15, 0, 16)
        weightLbl.Position = UDim2.new(0, 10, 0, 90)
        weightLbl.Text = "Min Weight (KG, 0=All):"
        weightLbl.TextColor3 = C.textDim
        weightLbl.Font = Enum.Font.Gotham
        weightLbl.TextSize = 8
        weightLbl.TextXAlignment = Enum.TextXAlignment.Left
        weightLbl.BackgroundTransparency = 1
        weightLbl.Parent = Section

        local weightInput = Instance.new("TextBox")
        weightInput.Size = UDim2.new(0.45, -15, 0, 20)
        weightInput.Position = UDim2.new(0.55, 5, 0, 87)
        weightInput.BackgroundColor3 = C.input
        weightInput.BorderSizePixel = 0
        weightInput.Font = Enum.Font.Gotham
        weightInput.Text = tostring(fData.minWeight)
        weightInput.TextColor3 = C.text
        weightInput.TextSize = 9
        weightInput.Parent = Section
        Instance.new("UICorner", weightInput).CornerRadius = UDim.new(0, 3)
        weightInput.FocusLost:Connect(function()
            local n = tonumber(weightInput.Text) or 0
            fData.minWeight = n
            weightInput.Text = tostring(n)
            saveConfig()
        end)

        local pickPetBtn = Instance.new("TextButton")
        pickPetBtn.Size = UDim2.new(1, -20, 0, 22)
        pickPetBtn.Position = UDim2.new(0, 10, 0, 114)
        pickPetBtn.BackgroundColor3 = C.accent
        pickPetBtn.BorderSizePixel = 0
        pickPetBtn.Font = Enum.Font.GothamBold
        pickPetBtn.Text = "📋 Pilih Pet Target"
        pickPetBtn.TextColor3 = C.text
        pickPetBtn.TextSize = 8
        pickPetBtn.Parent = Section
        Instance.new("UICorner", pickPetBtn).CornerRadius = UDim.new(0, 3)

        local selectedPetsLbl = Instance.new("TextLabel")
        selectedPetsLbl.Size = UDim2.new(1, -20, 0, 40)
        selectedPetsLbl.Position = UDim2.new(0, 10, 0, 140)
        selectedPetsLbl.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
        selectedPetsLbl.BorderSizePixel = 0
        selectedPetsLbl.Font = Enum.Font.Gotham
        selectedPetsLbl.Text = "Klik untuk memilih pet..."
        selectedPetsLbl.TextColor3 = C.textDim
        selectedPetsLbl.TextSize = 8
        selectedPetsLbl.TextWrapped = true
        selectedPetsLbl.TextXAlignment = Enum.TextXAlignment.Left
        selectedPetsLbl.TextYAlignment = Enum.TextYAlignment.Top
        selectedPetsLbl.Parent = Section
        Instance.new("UICorner", selectedPetsLbl).CornerRadius = UDim.new(0, 3)
        
        local function updateSelectedPetsLabel()
            local selected = {}
            for pet, val in pairs(fData.pets) do
                if val then table.insert(selected, pet) end
            end
            if #selected == 0 then
                selectedPetsLbl.Text = "Klik untuk memilih pet... (Wajib pilih 1)"
            else
                selectedPetsLbl.Text = table.concat(selected, ", ")
            end
        end
        updateSelectedPetsLabel()

        local pickMutBtn = Instance.new("TextButton")
        pickMutBtn.Size = UDim2.new(1, -20, 0, 22)
        pickMutBtn.Position = UDim2.new(0, 10, 0, 186)
        pickMutBtn.BackgroundColor3 = C.accent
        pickMutBtn.BorderSizePixel = 0
        pickMutBtn.Font = Enum.Font.GothamBold
        pickMutBtn.Text = "✨ Pilih Mutasi (Opsional)"
        pickMutBtn.TextColor3 = C.text
        pickMutBtn.TextSize = 8
        pickMutBtn.Parent = Section
        Instance.new("UICorner", pickMutBtn).CornerRadius = UDim.new(0, 3)

        local selectedMutLbl = Instance.new("TextLabel")
        selectedMutLbl.Size = UDim2.new(1, -20, 0, 40)
        selectedMutLbl.Position = UDim2.new(0, 10, 0, 212)
        selectedMutLbl.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
        selectedMutLbl.BorderSizePixel = 0
        selectedMutLbl.Font = Enum.Font.Gotham
        selectedMutLbl.Text = "Klik untuk memilih mutasi..."
        selectedMutLbl.TextColor3 = C.textDim
        selectedMutLbl.TextSize = 8
        selectedMutLbl.TextWrapped = true
        selectedMutLbl.TextXAlignment = Enum.TextXAlignment.Left
        selectedMutLbl.TextYAlignment = Enum.TextYAlignment.Top
        selectedMutLbl.Parent = Section
        Instance.new("UICorner", selectedMutLbl).CornerRadius = UDim.new(0, 3)

        local function updateSelectedMutLabel()
            local selected = {}
            for mut, val in pairs(fData.mutations) do
                if val then table.insert(selected, mut) end
            end
            if #selected == 0 then
                selectedMutLbl.Text = "Klik untuk memilih mutasi... (Kosong = Semua Mutasi)"
            else
                selectedMutLbl.Text = table.concat(selected, ", ")
            end
        end
        updateSelectedMutLabel()

        pickPetBtn.MouseButton1Click:Connect(function()
            createPopup("🎯 Pilih Pet untuk Filter #" .. index, allPets, fData.pets, updateSelectedPetsLabel)
        end)

        pickMutBtn.MouseButton1Click:Connect(function()
            local mutList = {}
            local ok, registry = pcall(function() return require(ReplicatedStorage.Data.PetRegistry.PetMutationRegistry) end)
            if ok and registry and registry.PetMutationRegistry then
                for mutName, _ in pairs(registry.PetMutationRegistry) do
                    if mutName ~= "Normal" and mutName ~= "Rideable" then
                        table.insert(mutList, mutName)
                    end
                end
            end
            table.sort(mutList)
            createPopup("✨ Pilih Mutasi untuk Filter #" .. index, mutList, fData.mutations, updateSelectedMutLabel)
        end)
    end

    -- ⭐ PERBAIKAN 3: Buat 4 Section Filter dengan jeda aman (Task.defer)
    for i = 1, 4 do
        task.defer(function()
            buildFilterSection(i)
        end)
    end

    if config.autoBuyEnabled then
        startBuyBtn.Text = "⏹️ STOP SNIPER"
        startBuyBtn.BackgroundColor3 = C.danger
        startBuyLoop()
    end
end -- END OF TAB AUTO BUY BLOCK

makePlaceholder("AutoListing", "📋 Tab AutoListing\n(menyusul)")
makePlaceholder("Misc",        "⚙️ Tab Misc\nAntiAfk & Discord Webhook\n(menyusul)")

-- ==================================================================
-- INIT GLOBAL
-- ==================================================================
switchTab("Main")

closeBtn.MouseButton1Click:Connect(function()
    stopClaimLoop()
    screenGui:Destroy()
end)

screenGui.Destroying:Connect(function()
    stopClaimLoop()
end)

print("✅ Sniper Hub loaded — Tab Main terisolasi dengan baik (Euclidean Distance).")
