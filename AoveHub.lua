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
local SAVE_DIR  = "AoneHubTrade"
local SAVE_FILE = SAVE_DIR .. "/AoneHubTrade.json"

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
    autoListingEnabled = false,
    autoListingFilters = {},
    autoListingMaxPrice = 1000,
    antiAfkEnabled = false,
    discordWebhookEnabled = false,
    discordWebhookUrl = "",
    autoHopEnabled = false,
    autoHopTime = 30, -- Menit tanpa penjualan sebelum hop
    autoHopMinBooths = 10,
    autoReconnectEnabled = false,
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
-- WEBHOOK HELPER
-- ==================================================================
local function sendDiscordWebhook(webhookType, data)
    if not config.discordWebhookEnabled then return end
    if not config.discordWebhookUrl or config.discordWebhookUrl == "" then return end
    
    local title, color, description
    local currentTime = os.date("%d/%m/%y, %H.%M | %m/%d/%Y %I:%M %p")
    
    -- Sensor nama (S********3)
    local function censorName(name)
        if not name or #name < 3 then return name end
        local first, last = name:sub(1,1), name:sub(-1)
        local mid = string.rep("*", #name - 2)
        return first .. mid .. last
    end

    local buyerName = censorName(player.Name)
    local sellerName = data.sellerName and censorName(data.sellerName) or "Unknown"

    if webhookType == "Snipe" then
        title = "Snipe Alert! (Pet)"
        color = 5763719 -- Hijau
        description = string.format(
            "**Item Sniped**\n" ..
            "> Pet : **%s**\n" ..
            "> Age : %d\n" ..
            "> Weight : %.2f kg\n" ..
            "> Price : **%s** Token\n" ..
            "> Mutation : %s\n\n" ..
            "**Trade Info**\n" ..
            "> Buyer : ||%s||\n" ..
            "> Seller : ||%s||",
            data.petName, data.age or 1, data.weight or 0, tostring(data.price), data.mutation,
            buyerName, sellerName
        )
    elseif webhookType == "Sell" then
        title = "Sell Alert! (Pet)"
        color = 16776960 -- Kuning
        description = string.format(
            "**Item Sold**\n" ..
            "> Pet : **%s**\n" ..
            "> Age : %d\n" ..
            "> Weight : %.2f kg\n" ..
            "> Price : **%s** Token\n" ..
            "> Mutation : %s\n\n" ..
            "**Trade Info**\n" ..
            "> Buyer : ||%s||\n" ..
            "> Seller : ||%s||",
            data.petName, data.age or 1, data.weight or 0, tostring(data.price), data.mutation,
            buyerName, sellerName
        )
    elseif webhookType == "TradeActive" then
        title = "🟢 Trade Aktif"
        color = 5763719 -- Hijau
        description = string.format(
            "**Sesi Dimulai**\n" ..
            "> Status : **Script Berjalan**\n" ..
            "> Player : ||%s||\n" ..
            "> Waktu : %s",
            buyerName, os.date("%H:%M:%S")
        )
    elseif webhookType == "TradeInactive" then
        title = "🔴 Trade Nonaktif"
        color = 16711680 -- Merah
        description = string.format(
            "**Sesi Berakhir**\n" ..
            "> Status : **%s**\n" ..
            "> Player : ||%s||\n" ..
            "> Waktu : %s",
            data.reason or "Script Dihentikan", buyerName, os.date("%H:%M:%S")
        )
    end
    
    local payload = {
        username = "AoneHub",
        embeds = {{
            title = title,
            description = description,
            color = color,
            footer = {
                text = "AoneHub  " .. currentTime
            }
        }}
    }
    
    local httpReq = (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request) or request or http_request
    if httpReq then
        pcall(function()
            httpReq({
                Url = config.discordWebhookUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end
end
_G.SniperHub.SendWebhook = sendDiscordWebhook

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

local isGuiDestroyed = false
local isShuttingDown = false -- ⭐ Tambahkan di SHARED STATE

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

    -- 1. Posisi tujuan
    local offset = CFrame.new(0, -1, 7) 
    local targetPos = (boothInstance:GetPivot() * offset).Position
    
    -- 2. Titik pusat booth (untuk arah pandang)
    local centerPos = boothInstance:GetPivot().Position
    
    -- 3. Hitung arah pandang (dari posisi pemain ke tengah booth)
    -- Vector3.new(0,1,0) adalah sumbu Up agar karakter tidak miring
    local lookAtCFrame = CFrame.lookAt(targetPos, centerPos, Vector3.new(0, 1, 0))
    
    -- 4. Terapkan ke karakter
    hrp.CFrame = lookAtCFrame
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

                    -- ⭐ TAMBAHKAN BATAS TOLERANSI DI SINI
                    local THRESHOLD = 2 -- Jarak minimal (dalam stud) untuk memicu pindah

                    if config.claimPriority == "front" then
                        better = (myDist - bestDist) > THRESHOLD
                    elseif config.claimPriority == "back" then
                        better = (bestDist - myDist) > THRESHOLD
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
screenGui.Name = "AoneHub"
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

-- ==============================================================
-- DEFAULT VIEW (Halaman Depan)
-- ==============================================================
local defaultView = Instance.new("Frame")
defaultView.Size = UDim2.new(1, 0, 1, 0)
defaultView.BackgroundTransparency = 1
defaultView.Parent = contentArea

local logoLabel = Instance.new("TextLabel")
logoLabel.Size = UDim2.new(1, 0, 0, 32)
logoLabel.Position = UDim2.new(0, 0, 0.35, -16)
logoLabel.Text = "AoneHub"
logoLabel.TextColor3 = C.accent
logoLabel.Font = Enum.Font.GothamBlack
logoLabel.TextSize = 24
logoLabel.BackgroundTransparency = 1
logoLabel.Parent = defaultView

local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(1, 0, 0, 14)
subLabel.Position = UDim2.new(0, 0, 0.5, 0)
subLabel.Text = "Pilih menu di samping"
subLabel.TextColor3 = C.textDim
subLabel.Font = Enum.Font.Gotham
subLabel.TextSize = 10
subLabel.BackgroundTransparency = 1
subLabel.Parent = defaultView

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

-- ==============================================================
-- DYNAMIC DROPDOWN (Anti-Overlap seperti AoneHub)
-- ==============================================================
local function createDynamicDropdown(parent, position, placeholder, onSelect, options, parentSection, baseHeight)
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
    local baseSectionHeight = baseHeight or (parentSection and parentSection.Size.Y.Offset) or 275

    -- Fungsi pembantu untuk memperbarui tinggi section dan memindahkan elemen lain
    local function updateLayout(extraHeight)
        if parentSection then
            local meta = sectionMeta[parentSection]
            if meta then
                meta.expandedHeight = baseSectionHeight + extraHeight
                if meta.expanded then
                    parentSection.Size = UDim2.new(1, -10, 0, meta.expandedHeight)
                end
            end
            -- Geser semua elemen di bawah dropdown ini ke bawah
            for _, child in ipairs(parentSection:GetChildren()) do
                if child:IsA("TextButton") and child ~= btn and child.Position.Y.Offset > position.Y.Offset then
                    local originalY = child:GetAttribute("OriginalY") or child.Position.Y.Offset
                    child:SetAttribute("OriginalY", originalY)
                    child.Position = UDim2.new(child.Position.X.Scale, child.Position.X.Offset, 0, originalY + extraHeight)
                end
            end
        end
    end

    local api = {
        Container = Container,
        HeaderButton = btn,
        ListScroll = list,
        ItemHeight = 22,
        IsOpen = function() return isOpen end,
        Close = function()
            if not isOpen then return end
            isOpen = false
            list.Visible = false
            arrow.Text = "▼"
            Container.Size = UDim2.new(1, -20, 0, 28)
            updateLayout(0)
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
        local listHeight = math.min(total, 160)
        list.Size = UDim2.new(1, 0, 0, listHeight)
        return listHeight
    end

    btn.MouseButton1Click:Connect(function()
        if isOpen then
            api.Close()
        else
            isOpen = true
            local listHeight = render()
            list.Visible = true
            arrow.Text = "▲"
            Container.Size = UDim2.new(1, -20, 0, 30 + listHeight + 2)
            updateLayout(listHeight + 10) -- Geser elemen di bawah dropdown
        end
    end)

    return api
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
    -- Sembunyikan halaman depan
    defaultView.Visible = false

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
    local StatusSection = createSection(mainScroll, "⚙️ Konfigurasi Booth", "mainStatus", 213)
    StatusSection.LayoutOrder = 1

    local StatusLbl = Instance.new("TextLabel")
    StatusLbl.Size = UDim2.new(1, -20, 0, 16)
    StatusLbl.Position = UDim2.new(0, 10, 0, 33)
    StatusLbl.BackgroundTransparency = 1
    StatusLbl.Font = Enum.Font.Gotham
    StatusLbl.TextSize = 11
    StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
    StatusLbl.TextColor3 = C.text
    StatusLbl.Text = "📊 Status"
    StatusLbl.Parent = StatusSection
    
    local worldStatusLbl = Instance.new("TextLabel")
    worldStatusLbl.Size = UDim2.new(1, -20, 0, 16)
    worldStatusLbl.Position = UDim2.new(0, 10, 0, 54)
    worldStatusLbl.BackgroundTransparency = 1
    worldStatusLbl.Font = Enum.Font.Gotham
    worldStatusLbl.TextSize = 9
    worldStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
    worldStatusLbl.TextColor3 = C.text
    worldStatusLbl.Parent = StatusSection

    local ownedBoothLbl = Instance.new("TextLabel")
    ownedBoothLbl.Size = UDim2.new(1, -20, 0, 16)
    ownedBoothLbl.Position = UDim2.new(0, 10, 0, 75)
    ownedBoothLbl.BackgroundTransparency = 1
    ownedBoothLbl.Font = Enum.Font.Gotham
    ownedBoothLbl.TextSize = 9
    ownedBoothLbl.TextXAlignment = Enum.TextXAlignment.Left
    ownedBoothLbl.TextColor3 = C.text
    ownedBoothLbl.Parent = StatusSection

    local mainStatusLbl = Instance.new("TextLabel")
    mainStatusLbl.Size = UDim2.new(1, -20, 0, 16)
    mainStatusLbl.Position = UDim2.new(0, 10, 0, 96)
    mainStatusLbl.BackgroundTransparency = 1
    mainStatusLbl.Font = Enum.Font.GothamBold
    mainStatusLbl.TextSize = 9
    mainStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
    mainStatusLbl.TextColor3 = C.textDim
    mainStatusLbl.Text = "Status: Idle"
    mainStatusLbl.Parent = StatusSection

    local startClaimBtn = Instance.new("TextButton")
    startClaimBtn.Size = UDim2.new(1, -20, 0, 34)
    startClaimBtn.Position = UDim2.new(0, 10, 0, 117)
    startClaimBtn.BackgroundColor3 = C.success
    startClaimBtn.BorderSizePixel = 0
    startClaimBtn.Font = Enum.Font.GothamBold
    startClaimBtn.Text = "▶️ MULAI CLAIM BOOTH"
    startClaimBtn.TextColor3 = C.text
    startClaimBtn.TextSize = 11
    startClaimBtn.Parent = StatusSection
    Instance.new("UICorner", startClaimBtn).CornerRadius = UDim.new(0, 5)

    local priorityLbl = Instance.new("TextLabel")
    priorityLbl.Size = UDim2.new(1, -20, 0, 14)
    priorityLbl.Position = UDim2.new(0, 10, 0, 156)
    priorityLbl.BackgroundTransparency = 1
    priorityLbl.Font = Enum.Font.Gotham
    priorityLbl.Text = "📍 Prioritas Posisi Booth:"
    priorityLbl.TextColor3 = C.textDim
    priorityLbl.TextSize = 8
    priorityLbl.TextXAlignment = Enum.TextXAlignment.Left
    priorityLbl.Parent = StatusSection

    local PRIORITY_OPTIONS = {
        {label = "⬆️ Paling Depan", value = "front"},
        {label = "⬇️ Paling Belakang", value = "back"},
        {label = "🎲 Random", value = "random"},
    }
    local priorityLabels = {
        front  = "⬆️ Paling Depan",
        back   = "⬇️ Paling Belakang",
        random = "🎲 Random",
    }

    local priorityDropdown = createDynamicDropdown(
        StatusSection,
        UDim2.new(0, 10, 0, 175),
        priorityLabels[config.claimPriority] or "📍 Pilih Prioritas",
        function(v) config.claimPriority = v; saveConfig() end,
        PRIORITY_OPTIONS,
        StatusSection, -- ⭐ Parent Section
        213            -- ⭐ Tinggi awal Section
    )
    priorityDropdown.HeaderButton.Text = priorityLabels[config.claimPriority] or "📍 Pilih Prioritas"
    
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

    task.spawn(function()
        while screenGui.Parent do
            task.wait(2)
            pcall(refreshOwnedBoothInfo)
        end
    end)

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

    -- SECTION 2: DAFTAR SKIN
    local SkinSection = createSection(mainScroll, "🎨 Pilih Booth Skin", "mainSkin", 296)
    SkinSection.LayoutOrder = 2

    makeToggle(
        SkinSection, 28,
        "Apply Booth Skin", "claimSkinEnabled",
        "🎨 Apply Skin: ON", "🎨 Apply Skin: OFF"
    )
    
    local skinSearch = Instance.new("TextBox")
    skinSearch.Size = UDim2.new(1, -20, 0, 22)
    skinSearch.Position = UDim2.new(0, 10, 0, 59)
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
    skinListFrame.Position = UDim2.new(0, 10, 0, 86)
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
        f.maxPrice = tonumber(f.maxPrice) or 100
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
local MutRegistry = require(ReplicatedStorage.Data.PetRegistry.PetMutationRegistry)
local enumToMut = MutRegistry.EnumToPetMutation
    
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

    -- ⭐ PERBAIKAN MUTASI: Konversi Enum ID ke Nama (misal "b" -> "Golden")
    local rawMut = item.MutationType or (item.PetData and item.PetData.MutationType) or "m"
    local mutation = "Normal"
    if rawMut ~= "m" and rawMut ~= "Normal" then
        mutation = enumToMut[rawMut] or rawMut 
    end
    local price = listing.Price or 99999

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
    
    -- ⭐ PEMANGGILAN WEBHOOK SNIPE
    local sellerName = sellerPlayerObj.Name
    _G.SniperHub.SendWebhook("Snipe", {
        petName = petType,
        age = item.Level or (item.PetData and item.PetData.Level) or 1,
        weight = baseWeight,
        price = price,
        mutation = mutation,
        sellerName = sellerName
    })
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
    local ControlSection = createSection(buyScroll, "⚙️ Kontrol Sniper", "buyControl", 91)
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
    tokenStatusLbl.Position = UDim2.new(0, 10, 0, 67)
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

        local render
render = function()
    -- 1. Bersihkan list sebelumnya
    for _, c in ipairs(scr:GetChildren()) do 
        if c:IsA("TextButton") then c:Destroy() end 
    end
    
    local s = search.Text:lower()
    local selectedList = {}
    local unselectedList = {}

    -- 2. Pisahkan antara yang terpilih dan tidak
    for _, item in ipairs(items) do
        if s == "" or item:lower():find(s, 1, true) then
            if currentSelected[item] == true then
                table.insert(selectedList, item)
            else
                table.insert(unselectedList, item)
            end
        end
    end

    -- 3. Gabungkan: Yang terpilih taruh paling atas
    local combined = {}
    for _, v in ipairs(selectedList) do table.insert(combined, v) end
    for _, v in ipairs(unselectedList) do table.insert(combined, v) end

    -- 4. Render ke GUI
    for i, item in ipairs(combined) do
        local isSel = currentSelected[item] == true
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -4, 0, 22)
        -- Warna background: Hijau jika dipilih, Abu-abu jika tidak
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
            -- Toggle status
            currentSelected[item] = not isSel and true or nil
            saveConfig()
            
            -- ⭐ AUTO CLEAR SEARCH BAR (opsional, agar barang yang dipilih langsung kelihatan)
            -- search.Text = "" 
            
            -- Render ulang (warna berubah & naik ke atas)
            render()
            onSelect()
        end)
    end
end

-- Hubungkan pencarian dan jalankan render pertama kali
search:GetPropertyChangedSignal("Text"):Connect(render)
render()
end

    -- ==============================================================
    -- PEMBUAT SECTION FILTER (Dengan Jeda Aman)
    -- ==============================================================
    local function buildFilterSection(index)
        local fData = config.autoBuyFilters[index]
        -- ⭐ PERBAIKAN: Pastikan tabel pets dan mutations tidak nil
        if type(fData.pets) ~= "table" then fData.pets = {} end
        if type(fData.mutations) ~= "table" then fData.mutations = {} end
    
        local Section = createSection(buyScroll, "🎯 Filter Sniper #" .. index, "buyFilter" .. index, 252)
        Section.LayoutOrder = index + 1

        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.new(1, -20, 0, 26)
        toggleBtn.Position = UDim2.new(0, 10, 0, 28)
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
        priceLbl.Position = UDim2.new(0, 10, 0, 59)
        priceLbl.Text = "Max Harga (Tokens, 0=All):"
        priceLbl.TextColor3 = C.textDim
        priceLbl.Font = Enum.Font.Gotham
        priceLbl.TextSize = 8
        priceLbl.TextXAlignment = Enum.TextXAlignment.Left
        priceLbl.BackgroundTransparency = 1
        priceLbl.Parent = Section

        local priceInput = Instance.new("TextBox")
        priceInput.Size = UDim2.new(0.45, -15, 0, 20)
        priceInput.Position = UDim2.new(0.55, 5, 0, 56)
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
        weightLbl.Position = UDim2.new(0, 10, 0, 81)
        weightLbl.Text = "Min Base Weight (KG, 0=All):"
        weightLbl.TextColor3 = C.textDim
        weightLbl.Font = Enum.Font.Gotham
        weightLbl.TextSize = 8
        weightLbl.TextXAlignment = Enum.TextXAlignment.Left
        weightLbl.BackgroundTransparency = 1
        weightLbl.Parent = Section

        local weightInput = Instance.new("TextBox")
        weightInput.Size = UDim2.new(0.45, -15, 0, 20)
        weightInput.Position = UDim2.new(0.55, 5, 0, 78)
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
        pickPetBtn.Position = UDim2.new(0, 10, 0, 103)
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
        selectedPetsLbl.Position = UDim2.new(0, 10, 0, 130)
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
        pickMutBtn.Position = UDim2.new(0, 10, 0, 175)
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
        selectedMutLbl.Position = UDim2.new(0, 10, 0, 202)
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

-- ==================================================================
-- ================ TAB AUTO LISTING (ISOLATED DO-END) ==============
-- ==================================================================
do
    local listTab = tabFrames["AutoListing"]
    task.wait(0.5)

    -- Sanitasi Config
    if type(config.autoListingFilters) ~= "table" then config.autoListingFilters = {} end
    for i = 1, 4 do
        local f = config.autoListingFilters[i]
        if type(f) ~= "table" then f = {} end
        if type(f.pets) ~= "table" then f.pets = {} end
        if type(f.mutations) ~= "table" then f.mutations = {} end
        f.enabled = f.enabled or false
        f.price = tonumber(f.price) or 1000
        f.maxWeight = tonumber(f.maxWeight) or 3 -- ⭐ Ubah ke Max Weight
        config.autoListingFilters[i] = f
    end
    saveConfig()

    local listScroll = Instance.new("ScrollingFrame")
    listScroll.Size = UDim2.new(1, -10, 1, -10)
    listScroll.Position = UDim2.new(0, 5, 0, 5)
    listScroll.BackgroundTransparency = 1
    listScroll.BorderSizePixel = 0
    listScroll.ScrollBarThickness = 4
    listScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    listScroll.Parent = listTab

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 6)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = listScroll

    -- ==============================================================
    -- HELPER
    -- ==============================================================
    local CreateListingRF = ReplicatedStorage.GameEvents.TradeEvents.Booths.CreateListing
    local RemoveListingRF = ReplicatedStorage.GameEvents.TradeEvents.Booths.RemoveListing

    local function getMyInventoryPets()
    local data = DataService:GetData()
    if not data or not data.PetsData or not data.PetsData.PetInventory then return {} end
    
    -- ⭐ Ambil Registry Mutasi
    local mutRegistry = require(ReplicatedStorage.Data.PetRegistry.PetMutationRegistry)
    local enumToMut = mutRegistry.EnumToPetMutation

    local list = {}
    for uuid, pet in pairs(data.PetsData.PetInventory.Data) do
        local isEquipped = false
            if data.PetsData.EquippedPets then
                for _, eqUUID in ipairs(data.PetsData.EquippedPets) do
                    if eqUUID == uuid then isEquipped = true break end
                end
            end
            
            local isFavorited = pet.IsFavorite or (pet.PetData and pet.PetData.IsFavorite) or false
        
        if not isEquipped and not isFavorited then
            local petType = pet.PetType or (pet.PetData and pet.PetData.PetType) or "?"
            local baseWeight = pet.BaseWeight or (pet.PetData and pet.PetData.BaseWeight) or 0
            
            -- ⭐ PERBAIKAN MUTASI: Konversi Enum ID ke Nama (misal "b" -> "Golden")
            local rawMut = pet.MutationType or (pet.PetData and pet.PetData.MutationType) or "m"
            local mutation = "Normal"
            if rawMut ~= "m" and rawMut ~= "Normal" then
                mutation = enumToMut[rawMut] or rawMut 
            end
            
            table.insert(list, {
                uuid = uuid,
                type = "Pet",
                petType = petType,
                weight = baseWeight,
                mutation = mutation,
            })
        end
    end
    return list
    end

    local function getMyCurrentListingCount()
        local data = getBoothsData()
        if not data or not data.Players then return 0 end
        local myId = "Player_" .. tostring(player.UserId)
        local myData = data.Players[myId]
        
        local count = 0
        if myData and myData.Listings then
            for _ in pairs(myData.Listings) do
                count = count + 1
            end
        end
        return count
    end

    local function getMyListedUUIDs()
    local listed = {}
    local data = getBoothsData()
    if not data or not data.Players then return listed end
    
    local myId = "Player_" .. tostring(player.UserId)
    local myData = data.Players[myId]
    
    if myData and myData.Listings then
        for _, listing in pairs(myData.Listings) do
            -- Simpan ItemId (yang merupakan UUID pet) ke dalam tabel
            if listing.ItemId then
                listed[listing.ItemId] = true 
            end
        end
    end
    return listed
end
    
    local isListing = false
local buyConnection = nil
local queue = {} -- ⭐ Tabel Antrian
local isProcessingQueue = false -- Mencegah bentrok saat antrian diproses

-- Fungsi untuk mengambil daftar UUID yang sudah ada di booth
local function getMyListedUUIDs()
    local listed = {}
    local data = getBoothsData()
    if not data or not data.Players then return listed end
    local myId = "Player_" .. tostring(player.UserId)
    local myData = data.Players[myId]
    if myData and myData.Listings then
        for _, listing in pairs(myData.Listings) do
            if listing.ItemId then listed[listing.ItemId] = true end
        end
    end
    return listed
end

-- Fungsi untuk memproses antrian
local function processQueue()
    if isProcessingQueue or not isListing then return end
    if #queue == 0 then return end

    isProcessingQueue = true
    
    task.spawn(function()
        while #queue > 0 and isListing do
            -- Cek kapasitas saat ini
            local currentListings = getMyCurrentListingCount()
            if currentListings >= 50 then
                break -- Booth penuh, keluar dari loop (script tetap menyala)
            end
            
            -- Ambil pet dari antrian terdepan
            local pet = table.remove(queue, 1)
            
            if pet then
                print(string.format("[AutoListing] Memasang dari Antrian: %s | Sisa Antrian: %d", pet.petType, #queue))
                
                pcall(function()
                    CreateListingRF:InvokeServer(pet.type, pet.uuid, pet.price)
                end)
                
                task.wait(5.5) -- Cooldown wajib dari server
            end
        end
        isProcessingQueue = false
        
        -- ⭐ HAPUS LOGIKA AUTO-STOP DI SINI
        -- Script akan tetap menyala dan standby menunggu event listener
    end)
end

local function startBuyLoop()
    if isListing then return end
    isListing = true
    table.clear(queue) -- Reset antrian setiap mulai baru

    -- 1. SCAN AWAL: Kumpulkan pet yang lolos filter dan belum dilisting
    local pets = getMyInventoryPets()
    local listedUUIDs = getMyListedUUIDs()
    local currentListings = getMyCurrentListingCount()
    
    for _, pet in ipairs(pets) do
        if not listedUUIDs[pet.uuid] then
            -- Cek filter
            for _, filter in ipairs(config.autoListingFilters) do
                if filter.enabled then
                    local hasPetFilter = false
                    for _ in pairs(filter.pets) do hasPetFilter = true break end
                    local typeMatch = hasPetFilter and filter.pets[pet.petType] == true
                    local weightMatch = (filter.maxWeight == 0) or (pet.weight <= filter.maxWeight)
                    
                    local hasMutFilter = false
                    for _ in pairs(filter.mutations) do hasMutFilter = true break end
                    local mutMatch = true
                    if hasMutFilter then mutMatch = filter.mutations[pet.mutation] == true end

                    if typeMatch and weightMatch and mutMatch then
                        table.insert(queue, {
                            uuid = pet.uuid,
                            type = pet.type,
                            petType = pet.petType,
                            price = filter.price
                        })
                        break
                    end
                end
            end
        end
    end
    
    print("[AutoListing] Menemukan " .. #queue .. " pet baru untuk diantrikan.")
    
    -- 2. JALANKAN PROSES ANTRIAN
    processQueue()

    -- 3. EVENT LISTENER: Deteksi jika ada slot kosong (pet terjual)
if not buyConnection then
    local myId = "Player_" .. tostring(player.UserId)
    local previousListingCount = getMyCurrentListingCount() -- ⭐ Inisialisasi awal

    buyConnection = boothReceiver:GetPathSignal("Players/" .. myId .. "/Listings"):Connect(function()
        task.wait(2) -- Beri jeda sinkronisasi data
        local currentCount = getMyCurrentListingCount()
        
        -- ⭐ DETEKSI TERJUAL & KIRIM WEBHOOK
        if currentCount < previousListingCount then
            local sold = previousListingCount - currentCount
    
            -- ⭐ RESET TIMER HOP KARENA ADA PENJUALAN
            if _G.SniperHub.ResetHopTimer then
                _G.SniperHub.ResetHopTimer()
            end
                        
            -- Ambil data pet dari antrian (jika ada) sebagai sampel info
            local samplePet = queue[1] or { petType = "Unknown", weight = 0, price = 0, mutation = "Normal" }

            _G.SniperHub.SendWebhook("Sell", {
                petName = samplePet.petType,
                age = 1,
                weight = samplePet.weight,
                price = samplePet.price,
                mutation = samplePet.mutation,
                sellerName = player.Name
            })
            print("[AutoListing] 💰 " .. sold .. " Pet terjual! Mengisi ulang slot...")
        end
        
        previousListingCount = currentCount
        
        -- Isi ulang slot yang kosong
        if isListing and #queue > 0 then
            processQueue() 
        end
    end)
        end
    end

    -- ==============================================================
    -- SECTION 1: KONTROL UTAMA
    -- ==============================================================
    local CtrlSection = createSection(listScroll, "⚙️ Kontrol Auto Listing", "listControl", 105)
    CtrlSection.LayoutOrder = 1

    local startListBtn = Instance.new("TextButton")
    startListBtn.Size = UDim2.new(1, -20, 0, 34)
    startListBtn.Position = UDim2.new(0, 10, 0, 28)
    startListBtn.BackgroundColor3 = C.success
    startListBtn.BorderSizePixel = 0
    startListBtn.Font = Enum.Font.GothamBold
    startListBtn.Text = "▶️ MULAI AUTO LISTING"
    startListBtn.TextColor3 = C.text
    startListBtn.TextSize = 10
    startListBtn.Parent = CtrlSection
    Instance.new("UICorner", startListBtn).CornerRadius = UDim.new(0, 5)

    -- Tambahkan variabel ini di atas tombol atau di dalam fungsi (jika belum ada)
startListBtn.MouseButton1Click:Connect(function()
    if isListing then
        -- PROSES STOP
        isListing = false
        config.autoListingEnabled = false -- ⭐ Simpan ke config
        saveConfig()
        
        table.clear(queue)
        if buyConnection then
            buyConnection:Disconnect()
            buyConnection = nil
        end
        startListBtn.Text = "▶️ MULAI AUTO LISTING"
        startListBtn.BackgroundColor3 = C.success
        print("[AutoListing] Dihentikan oleh pengguna. Antrian dihapus.")
    else
        -- PROSES START
        local hasActive = false
        for _, f in ipairs(config.autoListingFilters) do
            if f.enabled then hasActive = true break end
        end
        if not hasActive then
            _G.SniperHub.UpdateStatus("⚠️ Aktifkan minimal 1 filter!", C.warning)
            return
        end
        
        config.autoListingEnabled = true -- ⭐ Simpan ke config
        saveConfig()
        
        startListBtn.Text = "⏹️ STOP LISTING"
        startListBtn.BackgroundColor3 = C.danger
        startBuyLoop()
    end
end)
    
    local unlistAllBtn = Instance.new("TextButton")
    unlistAllBtn.Size = UDim2.new(1, -20, 0, 28)
    unlistAllBtn.Position = UDim2.new(0, 10, 0, 67)
    unlistAllBtn.BackgroundColor3 = C.danger
    unlistAllBtn.BorderSizePixel = 0
    unlistAllBtn.Font = Enum.Font.GothamBold
    unlistAllBtn.Text = "🗑️ UNLIST ALL (Hapus Semua)"
    unlistAllBtn.TextColor3 = C.text
    unlistAllBtn.TextSize = 10
    unlistAllBtn.Parent = CtrlSection
    Instance.new("UICorner", unlistAllBtn).CornerRadius = UDim.new(0, 5)

    unlistAllBtn.MouseButton1Click:Connect(function()
    isListing = false
    config.autoListingEnabled = false -- ⭐ Matikan di config
    saveConfig()
    
    table.clear(queue)
    if buyConnection then
        buyConnection:Disconnect()
        buyConnection = nil
    end
    if startListBtn and startListBtn.Parent then
        startListBtn.Text = "▶️ MULAI AUTO LISTING"
        startListBtn.BackgroundColor3 = C.success
    end

    local data = getBoothsData()
    if not data or not data.Players then return end
    local myId = "Player_" .. tostring(player.UserId)
    local myData = data.Players[myId]
    
    if myData and myData.Listings then
        local count = 0
        for listUUID, _ in pairs(myData.Listings) do
            pcall(function() RemoveListingRF:InvokeServer(listUUID) end)
            count = count + 1
            task.wait(1) -- Beri jeda agar server tidak stress
        end
        print("[AutoListing] Unlist All selesai. " .. count .. " item dihapus.")
        _G.SniperHub.UpdateStatus("🗑️ " .. count .. " listing dihapus", C.warning)
    else
        print("[AutoListing] Tidak ada listing untuk dihapus.")
    end
end)

    -- ==============================================================
    -- FUNGSI POPUP
    -- ==============================================================
    local allPets = {}
    local ok = pcall(function()
        for name, _ in pairs(PetRegistry.PetList) do table.insert(allPets, name) end
    end)
    if not ok or #allPets == 0 then allPets = {"Huge Cat", "Titan Dog"} end
    table.sort(allPets)

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

        local render
        render = function()
            for _, c in ipairs(scr:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
            local s = search.Text:lower()
            local selectedList, unselectedList = {}, {}
            
            for _, item in ipairs(items) do
                if s == "" or item:lower():find(s, 1, true) then
                    if currentSelected[item] == true then table.insert(selectedList, item)
                    else table.insert(unselectedList, item) end
                end
            end
            
            local combined = {}
            for _, v in ipairs(selectedList) do table.insert(combined, v) end
            for _, v in ipairs(unselectedList) do table.insert(combined, v) end

            for i, item in ipairs(combined) do
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
                    render()
                    onSelect()
                end)
            end
        end
        search:GetPropertyChangedSignal("Text"):Connect(render)
        render()
    end

    -- ==============================================================
    -- PEMBUAT SECTION FILTER
    -- ==============================================================
    local function buildListFilter(index)
        local fData = config.autoListingFilters[index]
        if type(fData.pets) ~= "table" then fData.pets = {} end
        if type(fData.mutations) ~= "table" then fData.mutations = {} end

        local Section = createSection(listScroll, "🎯 Filter Listing #" .. index, "listFilter" .. index, 252)
        Section.LayoutOrder = index + 1

        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.new(1, -20, 0, 26)
        toggleBtn.Position = UDim2.new(0, 10, 0, 28)
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
        priceLbl.Position = UDim2.new(0, 10, 0, 59)
        priceLbl.Text = "Harga Jual (Tokens):"
        priceLbl.TextColor3 = C.textDim
        priceLbl.Font = Enum.Font.Gotham
        priceLbl.TextSize = 8
        priceLbl.TextXAlignment = Enum.TextXAlignment.Left
        priceLbl.BackgroundTransparency = 1
        priceLbl.Parent = Section

        local priceInput = Instance.new("TextBox")
        priceInput.Size = UDim2.new(0.45, -15, 0, 20)
        priceInput.Position = UDim2.new(0.55, 5, 0, 56)
        priceInput.BackgroundColor3 = C.input
        priceInput.BorderSizePixel = 0
        priceInput.Font = Enum.Font.Gotham
        priceInput.Text = tostring(fData.price)
        priceInput.TextColor3 = C.text
        priceInput.TextSize = 9
        priceInput.Parent = Section
        Instance.new("UICorner", priceInput).CornerRadius = UDim.new(0, 3)
        priceInput.FocusLost:Connect(function()
            fData.price = tonumber(priceInput.Text) or 1000
            priceInput.Text = tostring(fData.price)
            saveConfig()
        end)

        local weightLbl = Instance.new("TextLabel")
        weightLbl.Size = UDim2.new(0.55, -15, 0, 16)
        weightLbl.Position = UDim2.new(0, 10, 0, 81)
        weightLbl.Text = "Max Base Weight (KG, 0=All):"
        weightLbl.TextColor3 = C.textDim
        weightLbl.Font = Enum.Font.Gotham
        weightLbl.TextSize = 8
        weightLbl.TextXAlignment = Enum.TextXAlignment.Left
        weightLbl.BackgroundTransparency = 1
        weightLbl.Parent = Section

        local weightInput = Instance.new("TextBox")
        weightInput.Size = UDim2.new(0.45, -15, 0, 20)
        weightInput.Position = UDim2.new(0.55, 5, 0, 78)
        weightInput.BackgroundColor3 = C.input
        weightInput.BorderSizePixel = 0
        weightInput.Font = Enum.Font.Gotham
        weightInput.Text = tostring(fData.maxWeight)
        weightInput.TextColor3 = C.text
        weightInput.TextSize = 9
        weightInput.Parent = Section
        Instance.new("UICorner", weightInput).CornerRadius = UDim.new(0, 3)
        weightInput.FocusLost:Connect(function()
            fData.maxWeight = tonumber(weightInput.Text) or 0
            weightInput.Text = tostring(fData.maxWeight)
            saveConfig()
        end)

        local pickPetBtn = Instance.new("TextButton")
        pickPetBtn.Size = UDim2.new(1, -20, 0, 22)
        pickPetBtn.Position = UDim2.new(0, 10, 0, 103)
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
        selectedPetsLbl.Position = UDim2.new(0, 10, 0, 130)
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
        pickMutBtn.Position = UDim2.new(0, 10, 0, 175)
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
        selectedMutLbl.Position = UDim2.new(0, 10, 0, 202)
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
            createPopup("🎯 Pilih Pet untuk Listing #" .. index, allPets, fData.pets, updateSelectedPetsLabel)
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
            createPopup("✨ Pilih Mutasi untuk Listing #" .. index, mutList, fData.mutations, updateSelectedMutLabel)
        end)
    end

    for i = 1, 4 do
        buildListFilter(i)
        task.wait(0.1)
    end
    
    -- ⭐ AUTO-START SAAT SCRIPT DIMUAT
if config.autoListingEnabled then
    local hasActive = false
    for _, f in ipairs(config.autoListingFilters) do
        if f.enabled then hasActive = true break end
    end
    
    if hasActive then
        task.delay(2, function()
            if startListBtn and startListBtn.Parent then
                startListBtn.Text = "⏹️ STOP LISTING"
                startListBtn.BackgroundColor3 = C.danger
                startBuyLoop()
                print("[AutoListing] 🚀 Auto-start berhasil dijalankan dari config.")
            end
        end)
    end
end
end -- END OF TAB AUTO LISTING BLOCK

-- ==================================================================
-- =================== TAB MISC (ISOLATED DO-END) ===================
-- ==================================================================
do
    local miscTab = tabFrames["Misc"]
    
    local miscScroll = Instance.new("ScrollingFrame")
    miscScroll.Size = UDim2.new(1, -10, 1, -10)
    miscScroll.Position = UDim2.new(0, 5, 0, 5)
    miscScroll.BackgroundTransparency = 1
    miscScroll.BorderSizePixel = 0
    miscScroll.ScrollBarThickness = 4
    miscScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    miscScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    miscScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    miscScroll.Parent = miscTab

    local miscLayout = Instance.new("UIListLayout")
    miscLayout.Padding = UDim.new(0, 6)
    miscLayout.SortOrder = Enum.SortOrder.LayoutOrder
    miscLayout.Parent = miscScroll

    -- ==============================================================
    -- SECTION 1: ANTI-AFK
    -- ==============================================================
    local AfkSection = createSection(miscScroll, "🛡️ Anti-AFK System", "miscAfk", 83)
    AfkSection.LayoutOrder = 1

    local afkToggleBtn = Instance.new("TextButton")
    afkToggleBtn.Size = UDim2.new(1, -20, 0, 26)
    afkToggleBtn.Position = UDim2.new(0, 10, 0, 28)
    afkToggleBtn.BackgroundColor3 = config.antiAfkEnabled and C.success or Color3.fromRGB(70, 70, 85)
    afkToggleBtn.BorderSizePixel = 0
    afkToggleBtn.Font = Enum.Font.GothamBold
    afkToggleBtn.Text = config.antiAfkEnabled and "🛡️ Anti-AFK: ON" or "🛡️ Anti-AFK: OFF"
    afkToggleBtn.TextColor3 = C.text
    afkToggleBtn.TextSize = 9
    afkToggleBtn.Parent = AfkSection
    Instance.new("UICorner", afkToggleBtn).CornerRadius = UDim.new(0, 4)

    afkToggleBtn.MouseButton1Click:Connect(function()
        config.antiAfkEnabled = not config.antiAfkEnabled
        saveConfig()
        afkToggleBtn.Text = config.antiAfkEnabled and "🛡️ Anti-AFK: ON" or "🛡️ Anti-AFK: OFF"
        afkToggleBtn.BackgroundColor3 = config.antiAfkEnabled and C.success or Color3.fromRGB(70, 70, 85)
    end)

    local afkHint = Instance.new("TextLabel")
    afkHint.Size = UDim2.new(1, -20, 0, 14)
    afkHint.Position = UDim2.new(0, 10, 0, 59)
    afkHint.BackgroundTransparency = 1
    afkHint.Font = Enum.Font.Gotham
    afkHint.Text = "Mencegah kick karena AFK (Idle) di dalam game."
    afkHint.TextColor3 = C.textDim
    afkHint.TextSize = 8
    afkHint.TextXAlignment = Enum.TextXAlignment.Left
    afkHint.Parent = AfkSection

    -- ==============================================================
    -- SECTION 2: DISCORD WEBHOOK
    -- ==============================================================
    local WebhookSection = createSection(miscScroll, "🔔 Discord Webhook", "miscWebhook", 112)
    WebhookSection.LayoutOrder = 2

    local webToggleBtn = Instance.new("TextButton")
    webToggleBtn.Size = UDim2.new(1, -20, 0, 26)
    webToggleBtn.Position = UDim2.new(0, 10, 0, 28)
    webToggleBtn.BackgroundColor3 = config.discordWebhookEnabled and C.success or Color3.fromRGB(70, 70, 85)
    webToggleBtn.BorderSizePixel = 0
    webToggleBtn.Font = Enum.Font.GothamBold
    webToggleBtn.Text = config.discordWebhookEnabled and "🔔 Webhook: ON" or "🔔 Webhook: OFF"
    webToggleBtn.TextColor3 = C.text
    webToggleBtn.TextSize = 9
    webToggleBtn.Parent = WebhookSection
    Instance.new("UICorner", webToggleBtn).CornerRadius = UDim.new(0, 4)

    webToggleBtn.MouseButton1Click:Connect(function()
        config.discordWebhookEnabled = not config.discordWebhookEnabled
        saveConfig()
        webToggleBtn.Text = config.discordWebhookEnabled and "🔔 Webhook: ON" or "🔔 Webhook: OFF"
        webToggleBtn.BackgroundColor3 = config.discordWebhookEnabled and C.success or Color3.fromRGB(70, 70, 85)
    end)

    local urlInput = Instance.new("TextBox")
    urlInput.Size = UDim2.new(1, -20, 0, 24)
    urlInput.Position = UDim2.new(0, 10, 0, 59)
    urlInput.BackgroundColor3 = C.input
    urlInput.BorderSizePixel = 0
    urlInput.Font = Enum.Font.Gotham
    urlInput.PlaceholderText = "https://discord.com/api/webhooks/..."
    urlInput.Text = config.discordWebhookUrl or ""
    urlInput.TextColor3 = C.text
    urlInput.TextSize = 8
    urlInput.ClearTextOnFocus = false
    urlInput.TextTruncate = Enum.TextTruncate.AtEnd
    urlInput.Parent = WebhookSection
    Instance.new("UICorner", urlInput).CornerRadius = UDim.new(0, 4)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 6)
    pad.Parent = urlInput

    urlInput.FocusLost:Connect(function()
        config.discordWebhookUrl = urlInput.Text:gsub("%s+$", "")
        saveConfig()
        _G.SniperHub.UpdateStatus("✅ Webhook URL disimpan", C.success)
    end)

    local webHint = Instance.new("TextLabel")
    webHint.Size = UDim2.new(1, -20, 0, 14)
    webHint.Position = UDim2.new(0, 10, 0, 88)
    webHint.BackgroundTransparency = 1
    webHint.Font = Enum.Font.Gotham
    webHint.Text = "Kirim Webhook Snipe & Sell"
    webHint.TextColor3 = C.textDim
    webHint.TextSize = 8
    webHint.TextWrapped = true
    webHint.TextXAlignment = Enum.TextXAlignment.Left
    webHint.Parent = WebhookSection

    -- ==============================================================
-- SECTION 3: AUTO HOP SERVER
-- ==============================================================
local HopSection = createSection(miscScroll, "🌐 Auto Server Hop", "miscHop", 160)
HopSection.LayoutOrder = 3

-- Toggle On/Off
local hopToggleBtn = Instance.new("TextButton")
hopToggleBtn.Size = UDim2.new(1, -20, 0, 26)
hopToggleBtn.Position = UDim2.new(0, 10, 0, 28)
hopToggleBtn.BackgroundColor3 = config.autoHopEnabled and C.success or Color3.fromRGB(70, 70, 85)
hopToggleBtn.BorderSizePixel = 0
hopToggleBtn.Font = Enum.Font.GothamBold
hopToggleBtn.Text = config.autoHopEnabled and "🌐 Auto Hop: ON" or "🌐 Auto Hop: OFF"
hopToggleBtn.TextColor3 = C.text
hopToggleBtn.TextSize = 9
hopToggleBtn.Parent = HopSection
Instance.new("UICorner", hopToggleBtn).CornerRadius = UDim.new(0, 4)

hopToggleBtn.MouseButton1Click:Connect(function()
    config.autoHopEnabled = not config.autoHopEnabled
    saveConfig()
    hopToggleBtn.Text = config.autoHopEnabled and "🌐 Auto Hop: ON" or "🌐 Auto Hop: OFF"
    hopToggleBtn.BackgroundColor3 = config.autoHopEnabled and C.success or Color3.fromRGB(70, 70, 85)
end)

-- Input Waktu
local timeLbl = Instance.new("TextLabel")
timeLbl.Size = UDim2.new(0.6, -15, 0, 16)
timeLbl.Position = UDim2.new(0, 10, 0, 59)
timeLbl.Text = "Waktu Hop (Menit):"
timeLbl.TextColor3 = C.textDim
timeLbl.Font = Enum.Font.Gotham
timeLbl.TextSize = 8
timeLbl.TextXAlignment = Enum.TextXAlignment.Left
timeLbl.BackgroundTransparency = 1
timeLbl.Parent = HopSection

local timeInput = Instance.new("TextBox")
timeInput.Size = UDim2.new(0.4, -15, 0, 20)
timeInput.Position = UDim2.new(0.6, 5, 0, 56)
timeInput.BackgroundColor3 = C.input
timeInput.BorderSizePixel = 0
timeInput.Font = Enum.Font.Gotham
timeInput.Text = tostring(config.autoHopTime)
timeInput.TextColor3 = C.text
timeInput.TextSize = 9
timeInput.Parent = HopSection
Instance.new("UICorner", timeInput).CornerRadius = UDim.new(0, 3)
timeInput.FocusLost:Connect(function()
    config.autoHopTime = tonumber(timeInput.Text) or 30
    timeInput.Text = tostring(config.autoHopTime)
    saveConfig()
end)

-- Input Minimal Booth
local boothLbl = Instance.new("TextLabel")
boothLbl.Size = UDim2.new(0.6, -15, 0, 16)
boothLbl.Position = UDim2.new(0, 10, 0, 81)
boothLbl.Text = "Minimal Booth Aktif:"
boothLbl.TextColor3 = C.textDim
boothLbl.Font = Enum.Font.Gotham
boothLbl.TextSize = 8
boothLbl.TextXAlignment = Enum.TextXAlignment.Left
boothLbl.BackgroundTransparency = 1
boothLbl.Parent = HopSection

local boothInput = Instance.new("TextBox")
boothInput.Size = UDim2.new(0.4, -15, 0, 20)
boothInput.Position = UDim2.new(0.6, 5, 0, 78)
boothInput.BackgroundColor3 = C.input
boothInput.BorderSizePixel = 0
boothInput.Font = Enum.Font.Gotham
boothInput.Text = tostring(config.autoHopMinBooths)
boothInput.TextColor3 = C.text
boothInput.TextSize = 9
boothInput.Parent = HopSection
Instance.new("UICorner", boothInput).CornerRadius = UDim.new(0, 3)
boothInput.FocusLost:Connect(function()
    config.autoHopMinBooths = tonumber(boothInput.Text) or 7
    boothInput.Text = tostring(config.autoHopMinBooths)
    saveConfig()
end)

-- Status
local hopStatusLbl = Instance.new("TextLabel")
hopStatusLbl.Size = UDim2.new(1, -20, 0, 16)
hopStatusLbl.Position = UDim2.new(0, 10, 0, 103)
hopStatusLbl.BackgroundTransparency = 1
hopStatusLbl.Font = Enum.Font.GothamBold
hopStatusLbl.Text = "Status: Menunggu..."
hopStatusLbl.TextColor3 = C.textDim
hopStatusLbl.TextSize = 8
hopStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
hopStatusLbl.Parent = HopSection

-- Tombol Force Hop (Pindah Paksa Sekarang)
local forceHopBtn = Instance.new("TextButton")
forceHopBtn.Size = UDim2.new(1, -20, 0, 26)
forceHopBtn.Position = UDim2.new(0, 10, 0, 124)
forceHopBtn.BackgroundColor3 = C.accent
forceHopBtn.BorderSizePixel = 0
forceHopBtn.Font = Enum.Font.GothamBold
forceHopBtn.Text = "🚀 Force Server Hop Sekarang"
forceHopBtn.TextColor3 = C.text
forceHopBtn.TextSize = 9
forceHopBtn.Parent = HopSection
Instance.new("UICorner", forceHopBtn).CornerRadius = UDim.new(0, 4)

-- ==============================================================
-- AUTO HOP HELPER
-- ==============================================================
local TeleportService = game:GetService("TeleportService")

local function countActiveBooths()
    local data = getBoothsData()
    if not data or not data.Booths then return 0 end
    local count = 0
    for _, booth in pairs(data.Booths) do
        if booth.Owner ~= nil then count = count + 1 end
    end
    return count
end

local function hopServer()
    if not config.autoHopEnabled then return false end
    
    hopStatusLbl.Text = "Status: Mencari server ramai..."
    print("[AutoHop] Mencari server baru...")
    
    local ok, serverList = pcall(function()
        return game:GetService("HttpService"):JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    
    if not ok or not serverList or not serverList.data then 
        hopStatusLbl.Text = "Status: Gagal mengambil data server."
        return false
    end
    
    local currentJobId = game.JobId
    local candidateServers = {}
    local minPlayers = config.autoHopMinBooths or 7
    
    for _, server in ipairs(serverList.data) do
        if server.playing >= minPlayers and server.playing < server.maxPlayers and server.id ~= currentJobId then
            table.insert(candidateServers, server)
        end
    end
    
    if #candidateServers == 0 then
        for _, server in ipairs(serverList.data) do
            if server.playing < server.maxPlayers and server.id ~= currentJobId then
                table.insert(candidateServers, server)
            end
        end
    end

    if #candidateServers > 0 then
        table.sort(candidateServers, function(a, b)
            return a.playing > b.playing
        end)

        local topServers = {}
        for i = 1, math.min(15, #candidateServers) do
            table.insert(topServers, candidateServers[i])
        end

        local randomIndex = math.random(1, #topServers)
        local targetServer = topServers[randomIndex]
        
        hopStatusLbl.Text = string.format("Status: Hop ke server (%d/%d)...", targetServer.playing, targetServer.maxPlayers)
        print(string.format("[AutoHop] Teleport ke server ramai (%d/%d)", targetServer.playing, targetServer.maxPlayers))
        
        local teleportSuccess, teleportErr = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, targetServer.id, player)
        end)
        
        if teleportSuccess then
            return true
        else
            print("[AutoHop] ❌ Gagal hop (Server penuh/Error):", teleportErr)
            hopStatusLbl.Text = "Status: Gagal hop, mencoba lagi..."
            return false
        end
    else
        hopStatusLbl.Text = "Status: Tidak ada server tersedia."
        return false
    end
end

-- ==============================================================
-- LOGIKA LOOP AUTO HOP (Revisi Total)
-- ==============================================================
local lastSellTime = tick()
local checkHopThread = task.spawn(function()
    -- ⭐ TAHAP 1: Cek awal 10 detik setelah masuk server
    task.wait(10)
    
    if config.autoHopEnabled and isInTradeWorld() then
        local activeBooths = countActiveBooths()
        hopStatusLbl.Text = string.format("Status: Cek awal (%d booth)", activeBooths)
        
        if activeBooths < config.autoHopMinBooths then
            -- Booth kurang, langsung hop!
            hopServer()
            return -- Hentikan loop karena akan teleport
        else
            -- Booth cukup, lanjut ke tahap 2
            lastSellTime = tick() -- Mulai timer
            hopStatusLbl.Text = "Status: Server ramai, timer berjalan..."
        end
    end

    -- ⭐ TAHAP 2: Timer berjalan
    while screenGui.Parent do
        task.wait(5) -- Cek tiap 5 detik
        
        if config.autoHopEnabled and isInTradeWorld() then
            local currentTime = tick()
            local minutesSinceLastSell = (currentTime - lastSellTime) / 60
            
            -- Update label status
            if hopStatusLbl and hopStatusLbl.Parent then
                hopStatusLbl.Text = string.format("Status: %d/%d menit tanpa penjualan", math.floor(minutesSinceLastSell), config.autoHopTime)
            end

            -- Cek apakah sudah melewati batas waktu
            if minutesSinceLastSell >= config.autoHopTime then
                hopStatusLbl.Text = "Status: Waktu habis! Hop..."
                local success = hopServer()
    
                if success then
                    task.wait(5) 
                    break -- Keluar loop karena akan teleport
                else
                    -- Jika gagal, reset timer 1 menit agar tidak spam request API
                    lastSellTime = tick() - (config.autoHopTime * 60) + 60 
                    task.wait(10) -- Tunggu 10 detik sebelum mencoba lagi
                end
            end
        end
    end
end)

-- Fungsi untuk mereset timer saat ada pet terjual
_G.SniperHub.ResetHopTimer = function()
    lastSellTime = tick()
    if hopStatusLbl and hopStatusLbl.Parent then
        hopStatusLbl.Text = "Status: Timer di-reset (ada pembeli!)"
    end
end

-- ==============================================================
-- SECTION 4: AUTO RECONNECT
-- ==============================================================
local ReconnectSection = createSection(miscScroll, "📡 Auto Reconnect", "miscReconnect", 85)
ReconnectSection.LayoutOrder = 4

local rejoinToggle = Instance.new("TextButton")
rejoinToggle.Size = UDim2.new(1, -20, 0, 26)
rejoinToggle.Position = UDim2.new(0, 10, 0, 28)
rejoinToggle.BackgroundColor3 = config.autoReconnectEnabled and C.success or Color3.fromRGB(70, 70, 85)
rejoinToggle.BorderSizePixel = 0
rejoinToggle.Font = Enum.Font.GothamBold
rejoinToggle.Text = config.autoReconnectEnabled and "📡 Auto Reconnect: ON" or "📡 Auto Reconnect: OFF"
rejoinToggle.TextColor3 = C.text
rejoinToggle.TextSize = 9
rejoinToggle.Parent = ReconnectSection
Instance.new("UICorner", rejoinToggle).CornerRadius = UDim.new(0, 4)

rejoinToggle.MouseButton1Click:Connect(function()
    config.autoReconnectEnabled = not config.autoReconnectEnabled
    saveConfig()
    rejoinToggle.Text = config.autoReconnectEnabled and "📡 Auto Reconnect: ON" or "📡 Auto Reconnect: OFF"
    rejoinToggle.BackgroundColor3 = config.autoReconnectEnabled and C.success or Color3.fromRGB(70, 70, 85)
end)

local reconnectHint = Instance.new("TextLabel")
reconnectHint.Size = UDim2.new(1, -20, 0, 16)
reconnectHint.Position = UDim2.new(0, 10, 0, 59)
reconnectHint.BackgroundTransparency = 1
reconnectHint.Font = Enum.Font.Gotham
reconnectHint.Text = "Mencoba rejoin kalau Disconnect"
reconnectHint.TextColor3 = C.textDim
reconnectHint.TextSize = 8
reconnectHint.TextWrapped = true
reconnectHint.TextXAlignment = Enum.TextXAlignment.Left
reconnectHint.Parent = ReconnectSection

-- ==============================================================
-- LOGIKA AUTO RECONNECT (Best-effort untuk Delta)
-- ==============================================================
local GuiService = game:GetService("GuiService")
local reconnectBusy = false
local lastReconnectAttempt = 0
local RECONNECT_COOLDOWN = 8

local function tryReconnect(reason)
    if not config.autoReconnectEnabled or reconnectBusy then return end
    if os.clock() - lastReconnectAttempt < RECONNECT_COOLDOWN then return end

    -- ⭐ KIRIM WEBHOOK DISCONNECT
    _G.SniperHub.SendWebhook("TradeInactive", { reason = "Terputus: " .. tostring(reason) })

    reconnectBusy = true
    lastReconnectAttempt = os.clock()
    print("[AutoReconnect] Mencoba masuk kembali: " .. tostring(reason))

    task.spawn(function()
        task.wait(3)
        if not config.autoReconnectEnabled then
            reconnectBusy = false
            return
        end

        local ok, err = pcall(function()
            -- Teleport ke PlaceId saat ini; Roblox akan memilih server yang tersedia.
            TeleportService:Teleport(game.PlaceId, player)
        end)

        if not ok then
            warn("[AutoReconnect] Permintaan teleport gagal: " .. tostring(err))
        end

        -- Lepas kunci jika teleport tidak segera dimulai, agar bisa mencoba lagi.
        task.wait(RECONNECT_COOLDOWN)
        reconnectBusy = false
    end)
end

-- Tangani kegagalan teleport dan coba lagi dengan jeda agar tidak spam.
TeleportService.TeleportInitFailed:Connect(function(teleportPlayer, result, errorMessage, placeId)
    if teleportPlayer ~= player or not config.autoReconnectEnabled then return end
    warn("[AutoReconnect] Teleport gagal: " .. tostring(result) .. " | " .. tostring(errorMessage))
    tryReconnect("TeleportInitFailed")
end)

-- Beberapa jenis error/disconnect dapat memunculkan pesan error Roblox.
-- Event ini tidak selalu tersedia/terpicu untuk semua disconnect atau kick.
pcall(function()
    GuiService.ErrorMessageChanged:Connect(function(message)
        if type(message) ~= "string" or message == "" then return end
        local lowerMessage = message:lower()
        if lowerMessage:find("disconnect", 1, true)
            or lowerMessage:find("connection", 1, true)
            or lowerMessage:find("kicked", 1, true)
            or lowerMessage:find("idle", 1, true) then
            tryReconnect("Roblox error: " .. message)
        end
    end)
end)

    -- ==============================================================
-- LOGIKA ANTI-AFK (AoneHub Style - Hotbar Safe)
-- ==============================================================
local VirtualInputManager = game:GetService("VirtualInputManager")
local antiAFKActive = false
local antiAFKDelayActive = false

local function PerformAntiAFKAction()
    pcall(function()
        VirtualInputManager:SendMouseMoveEvent(
            math.random(100, 500),
            math.random(100, 500),
            nil
        )
    end)
end

local function StartAntiAFK()
    if antiAFKActive or antiAFKDelayActive then return end

    local initialDelay = 600 -- 10 menit
    antiAFKDelayActive = true

    task.spawn(function()
        local remainingDelay = initialDelay
        while remainingDelay > 0 do
            if isGuiDestroyed or not config.antiAfkEnabled then
                antiAFKDelayActive = false
                return
            end

            task.wait(1)
            remainingDelay -= 1
        end

        if config.antiAfkEnabled and not isGuiDestroyed then
            antiAFKDelayActive = false
            antiAFKActive = true
            
            while antiAFKActive and config.antiAfkEnabled and not isGuiDestroyed do
                PerformAntiAFKAction()
                local waitTime = 420 + math.random() * 180 -- 7 s/d 10 menit
                local waited = 0
                while waited < waitTime and antiAFKActive and config.antiAfkEnabled and not isGuiDestroyed do
                    task.wait(1)
                    waited += 1
                end
            end
            antiAFKActive = false
        else
            antiAFKDelayActive = false
            
        end
    end)
end

local function StopAntiAFK()
    antiAFKActive = false
    antiAFKDelayActive = false
end

-- Watcher untuk deteksi toggle
task.spawn(function()
    local lastToggleState = config.antiAfkEnabled
    while screenGui.Parent do
        task.wait(0.5)
        if config.antiAfkEnabled ~= lastToggleState then
            lastToggleState = config.antiAfkEnabled
            if config.antiAfkEnabled then
                if not antiAFKActive and not antiAFKDelayActive then
                    StartAntiAFK()
                end
            else
                StopAntiAFK()
            end
        end
    end
end)

-- Auto-start jika config ON saat script di-load
if config.antiAfkEnabled then
    task.delay(1, function()
        if config.antiAfkEnabled and not isGuiDestroyed then
            StartAntiAFK()
            
        end
    end)
end

-- Auto reconnect ditangani oleh satu listener di atas.
end -- END OF TAB MISC BLOCK

-- ==================================================================
-- INIT GLOBAL
-- ==================================================================
closeBtn.MouseButton1Click:Connect(function()
    isShuttingDown = true
    stopClaimLoop()
    _G.SniperHub.SendWebhook("TradeInactive", { reason = "Script Di-close (Tombol X)" })
    screenGui:Destroy()
end)

screenGui.Destroying:Connect(function()
    isGuiDestroyed = true
    stopClaimLoop()
    
    -- Hanya kirim jika belum dikirim oleh tombol X
    if not isShuttingDown then
        if _G.SniperHub.SendWebhook then
            _G.SniperHub.SendWebhook("TradeInactive", { reason = "GUI Destroyed / Script Dimatikan" })
        end
    end
end)

-- ⭐ KIRIM WEBHOOK SAAT SCRIPT BARU DIBUKA
task.delay(2, function()
    _G.SniperHub.SendWebhook("TradeActive", {})
end)

print("✅ Sniper Hub loaded — Tab Main terisolasi dengan baik (Euclidean Distance).")
