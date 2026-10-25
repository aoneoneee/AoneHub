-- ==================================================================
-- AONEHUB UNIVERSAL LOADER (FIXED REGISTER LIMIT)
-- ==================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Deteksi World
local TradeWorldData = require(ReplicatedStorage.Data.TradeWorldData)
local TRADE_WORLD_PLACE_ID = TradeWorldData.PlaceId
local isInTradeWorld = (game.PlaceId == TRADE_WORLD_PLACE_ID)

-- Bersihkan GUI lama
local oldGui = playerGui:FindFirstChild("AoneHub")
if oldGui then oldGui:Destroy() end
local oldTradeGui = playerGui:FindFirstChild("AoneHubTrade")
if oldTradeGui then oldTradeGui:Destroy() end

-- Kill Switch
if _G.AoneHub_Cleanup then
    pcall(_G.AoneHub_Cleanup)
    _G.AoneHub_Cleanup = nil
end
_G.AoneHub_IsAlive = true

-- ==================================================================
-- FUNGSI UNTUK MEMBUNGKUS SCRIPT (ANTI LOCAL REGISTER LIMIT)
-- ==================================================================
local function loadAoneHubTrade()
    
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

_G.AoneHub_IsAlive = true

local cleanupReconnectListeners = nil

-- [PATCH 1A] Expose cleanup functions dari do-end block
local cleanupAutoBuy = nil
local cleanupAutoListing = nil
local cleanupSellMonitor = nil
    
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
    claimSkinEnabled     = true,
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
    
    -- Pastikan 'data' adalah tabel (jika nil, jadikan tabel kosong)
    data = data or {}
    
    local title, color, description
    local currentTime = os.date("%d/%m/%y, %H.%M | %m/%d/%Y %I:%M %p")
    
    -- Sensor nama (S********3)
    local function censorName(name)
        if not name or #name < 3 then return name or "Unknown" end
        local first, last = name:sub(1,1), name:sub(-1)
        local mid = string.rep("*", #name - 2)
        return first .. mid .. last
    end

    local buyerName = censorName(player.Name)
    local sellerName = data.sellerName and censorName(data.sellerName) or "Unknown"

    -- ⭐ Ambil nilai dengan pengaman fallback (jika nil, ganti dengan nilai default)
    local petName = tostring(data.petName or "Unknown")
    local age = tonumber(data.age) or 1
    local weight = tonumber(data.weight) or 0
    local price = tostring(data.price or "0")
    local mutation = tostring(data.mutation or "Normal")
    local reason = tostring(data.reason or "Script Dihentikan")

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
            petName, age, weight, price, mutation,
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
            petName, age, weight, price, mutation,
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
            reason, buyerName, os.date("%H:%M:%S")
        )
    end
    
    -- Jika tidak ada tipe yang cocok, hentikan eksekusi
    if not title then return end
    
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
local function applyBoothSkin(force)
    if not config.claimSkinEnabled then return false end
    local skinId = config.claimSkinID
    if not skinId or skinId == "" then return false end
    if not BoothSkinRegistry[skinId] then return false end

    -- ⭐ Jika tidak dipaksa (force), cek apakah sudah pernah ditembak
    if not force and MainState.lastAppliedSkinID == skinId then 
        return false 
    end

    -- Cari service
    local GameEvents = ReplicatedStorage:FindFirstChild("GameEvents")
    if not GameEvents then return false end
    
    local skinService = GameEvents:FindFirstChild("TradeBoothSkinService")
    if not skinService then return false end

    local equipRemote = skinService:FindFirstChild("Equip")
    if not equipRemote then return false end

    -- Tembak server
    local ok = pcall(function()
        equipRemote:FireServer(skinId)
    end)
    
    if ok then
        MainState.lastAppliedSkinID = skinId
        print("[BoothSkin] ✅ Skin " .. skinId .. " berhasil ditembak.")
    end
    return ok
end

local function teleportToBooth(boothInstance)
    if not boothInstance then return end
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    -- ⭐ 1. Matikan kontrol karakter sementara
    hum.AutoRotate = false
    hum:ChangeState(Enum.HumanoidStateType.Physics) -- Menghentikan animasi lari/berjalan

    -- 2. Hitung Posisi Tujuan
    local offset = CFrame.new(0, -1, 7) 
    local targetPos = (boothInstance:GetPivot() * offset).Position
    local centerPos = boothInstance:GetPivot().Position
    local lookAtCFrame = CFrame.lookAt(targetPos, centerPos, Vector3.new(0, 1, 0))
    
    -- 3. Teleport Karakter
    hrp.CFrame = lookAtCFrame
    
    -- 4. Pindahkan Kamera ke Belakang Karakter
    local camera = workspace.CurrentCamera
    if camera then
        -- Arah pandang horizontal (abaikan pitch naik/turun)
        local lookDir = (centerPos - targetPos).Unit
        local flatLook = Vector3.new(lookDir.X, 0, lookDir.Z).Unit
        
        -- Kamera berada 12 stud di belakang karakter dan 4 stud lebih tinggi
        local camPos = targetPos - (flatLook * 12) + Vector3.new(0, 4, 0)
        
        -- Arahkan kamera dari camPos ke arah booth (bukan ke kepala karakter)
        camera.CFrame = CFrame.lookAt(camPos, camPos + flatLook, Vector3.new(0, 1, 0))
    end

    -- ⭐ 5. Nyalakan kembali kontrol setelah jeda
    task.wait(0.1) -- Beri waktu 1 frame agar engine Roblox sinkron
    hum:ChangeState(Enum.HumanoidStateType.GettingUp) -- Kembalikan ke state berdiri
    hum.AutoRotate = true
end

local function startClaimLoop()
    if MainState.isClaimRunning then return end
    if not isInTradeWorld() then return end
    MainState.isClaimRunning = true

    MainState.claimThread = task.spawn(function()
        task.wait(3)

        while MainState.isClaimRunning do
            if not _G.AoneHub_IsAlive then return end
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
    
                        -- ⭐ FORCE EQUIP SKIN DULU
                        MainState.lastAppliedSkinID = nil
                        applyBoothSkin(true)
                        task.wait(0.5)
    
                        pcall(function() RemoveBoothRE:FireServer() end)
                        task.wait(1.5)
                        pcall(function() ClaimBoothRE:FireServer(best.instance) end)
                        task.wait(1.5)

                        if getMyPlayerBoothId() then
                            teleportToBooth(best.instance)
                            ok = true
                            msg = "Re-Claim & Skin berhasil"
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
    
                    -- ⭐ FORCE EQUIP SKIN DULU
                    MainState.lastAppliedSkinID = nil -- Reset state
                    applyBoothSkin(true)              -- Force tembak
                    task.wait(0.5) 
    
                    pcall(function() ClaimBoothRE:FireServer(target.instance) end)
                    task.wait(1.5)

                    if getMyPlayerBoothId() then
                        teleportToBooth(target.instance)
                        ok = true
                        msg = "Claim berhasil & Skin terpasang"
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
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AoneHubTrade"
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
        
    if buyConnection then
        buyConnection:Disconnect()
        buyConnection = nil
    end
        
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

-- [PATCH 1B] Expose ke scope atas loadAoneHubTrade
cleanupAutoBuy = stopBuyLoop
    
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
                selectedPetsLbl.Text = "Klik untuk memilih pet... (Wajib pilih minimal 1)"
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

local isListing = false
local buyConnection = nil
local queue = {} -- ⭐ Tabel Antrian
local isProcessingQueue = false -- Mencegah bentrok saat antrian diproses
local isUserUnlisting = false
        
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
        -- [PATCH 7] Guard isGuiDestroyed
        while #queue > 0 and isListing and not isGuiDestroyed do
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

-- Sebelum startBuyLoop, inisialisasi snapshot
local lastKnownListings = {}  -- { [listUUID] = { petType=..., price=... } }

local function snapshotMyListings()
    local snapshot = {}
    local data = getBoothsData()
    if not data or not data.Players then return snapshot end
    local myId = "Player_" .. tostring(player.UserId)
    local myData = data.Players[myId]
    if myData and myData.Listings then
        for listUUID, listing in pairs(myData.Listings) do
            local petType, weight, level, mutation = "Unknown", 0, 1, "Normal"
            local item = myData.Items and listing.ItemId and myData.Items[listing.ItemId]
            if item then
                petType = item.PetType or (item.PetData and item.PetData.PetType) or "Unknown"
                weight = item.BaseWeight or (item.PetData and item.PetData.BaseWeight) or 0
                level = item.Level or (item.PetData and item.PetData.Level) or 1
                local rawMut = item.MutationType or (item.PetData and item.PetData.MutationType) or "m"
                if rawMut ~= "m" and rawMut ~= "Normal" then
                    local mutReg = require(ReplicatedStorage.Data.PetRegistry.PetMutationRegistry)
                    mutation = mutReg.EnumToPetMutation[rawMut] or rawMut
                end
            end
            snapshot[listUUID] = {
                itemId = listing.ItemId,
                petType = petType,
                weight = weight,
                age = level,
                mutation = mutation,
                price = listing.Price,
            }
        end
    end
    return snapshot
end

-- ⭐ Snapshot: UUID yang sedang kamu list + UUID yang kamu miliki
local function snapshotMyState()
    local myState = {
        listings = {},     -- [listUUID] = { itemId, petType, weight, ... }
        ownedUUIDs = {},   -- [petUUID] = true (dari inventory + equipped)
    }
    
    -- 1. Ambil listings kamu
    local data = getBoothsData()
    if data and data.Players then
        local myId = "Player_" .. tostring(player.UserId)
        local myData = data.Players[myId]
        if myData and myData.Listings then
            for listUUID, listing in pairs(myData.Listings) do
                local petType, weight, level, mutation = "Unknown", 0, 1, "Normal"
                local item = myData.Items and listing.ItemId and myData.Items[listing.ItemId]
                if item then
                    petType = item.PetType or (item.PetData and item.PetData.PetType) or "Unknown"
                    weight = item.BaseWeight or (item.PetData and item.PetData.BaseWeight) or 0
                    level = item.Level or (item.PetData and item.PetData.Level) or 1
                    local rawMut = item.MutationType or (item.PetData and item.PetData.MutationType) or "m"
                    if rawMut ~= "m" and rawMut ~= "Normal" then
                        local mutReg = require(ReplicatedStorage.Data.PetRegistry.PetMutationRegistry)
                        mutation = mutReg.EnumToPetMutation[rawMut] or rawMut
                    end
                end
                myState.listings[listUUID] = {
                    itemId = listing.ItemId,  -- ini UUID pet
                    petType = petType,
                    weight = weight,
                    age = level,
                    mutation = mutation,
                    price = listing.Price,
                }
            end
        end
    end
    
    -- 2. Ambil UUID yang kamu miliki (inventory + equipped)
    local petsData = DataService:GetData() and DataService:GetData().PetsData
    if petsData then
        -- Inventory
        local inventory = petsData.PetInventory and petsData.PetInventory.Data
        if inventory then
            for uuid, _ in pairs(inventory) do
                myState.ownedUUIDs[uuid] = true
            end
        end
        -- Equipped
        local equipped = petsData.EquippedPets
        if equipped then
            for _, uuid in ipairs(equipped) do
                myState.ownedUUIDs[uuid] = true
            end
        end
    end
    
    return myState
end

-- ⭐ Snapshot state lengkap: listings kamu + UUID yang kamu miliki
local function snapshotSellState()
    local state = {
        listings = {},     -- [listUUID] = { itemId, petType, weight, age, mutation, price }
        ownedUUIDs = {},   -- [petUUID] = true
    }
    
    -- Listings kamu
    local data = getBoothsData()
    if data and data.Players then
        local myId = "Player_" .. tostring(player.UserId)
        local myData = data.Players[myId]
        if myData and myData.Listings then
            for listUUID, listing in pairs(myData.Listings) do
                local petType, weight, age, mutation = "Unknown", 0, 1, "Normal"
                local item = myData.Items and listing.ItemId and myData.Items[listing.ItemId]
                if item then
                    petType = item.PetType or (item.PetData and item.PetData.PetType) or "Unknown"
                    weight = item.BaseWeight or (item.PetData and item.PetData.BaseWeight) or 0
                    age = item.Level or (item.PetData and item.PetData.Level) or 1
                    local rawMut = item.MutationType or (item.PetData and item.PetData.MutationType) or "m"
                    if rawMut ~= "m" and rawMut ~= "Normal" then
                        local mutReg = require(ReplicatedStorage.Data.PetRegistry.PetMutationRegistry)
                        mutation = mutReg.EnumToPetMutation[rawMut] or rawMut
                    end
                end
                state.listings[listUUID] = {
                    itemId = listing.ItemId,
                    petType = petType,
                    weight = weight,
                    age = age,
                    mutation = mutation,
                    price = listing.Price,
                }
            end
        end
    end
    
    -- Inventory + Equipped
    local petsData = DataService:GetData() and DataService:GetData().PetsData
    if petsData then
        local inv = petsData.PetInventory and petsData.PetInventory.Data
        if inv then
            for uuid, _ in pairs(inv) do
                state.ownedUUIDs[uuid] = true
            end
        end
        if petsData.EquippedPets then
            for _, uuid in ipairs(petsData.EquippedPets) do
                state.ownedUUIDs[uuid] = true
            end
        end
    end
    
    return state
end
        
local sellMonitorConn = nil
local lastSellState = nil

local function startSellMonitor()
    if sellMonitorConn then return end
    
    -- ⭐ Tunggu data booth sync dulu
    task.wait(3)
    
    lastSellState = snapshotSellState()
    
    local myId = "Player_" .. tostring(player.UserId)
    sellMonitorConn = boothReceiver:GetPathSignal("Players/" .. myId .. "/Listings"):Connect(function()
        -- ⭐ Retry 5x @ 2 detik untuk tunggu inventory replication
        local currentState = nil
        local soldPets, unlistedPets = {}, {}
        
        for attempt = 1, 5 do
            task.wait(2)
            
            currentState = snapshotSellState()
            soldPets, unlistedPets = {}, {}
            
            -- Cari UUID yang hilang dari listings
            for listUUID, info in pairs(lastSellState.listings) do
                if not currentState.listings[listUUID] then
                    local petUUID = info.itemId
                    local stillOwned = petUUID and currentState.ownedUUIDs[petUUID] == true
                    
                    if stillOwned then
                        table.insert(unlistedPets, { listUUID = listUUID, info = info })
                    else
                        table.insert(soldPets, { listUUID = listUUID, info = info })
                    end
                end
            end
            
            -- Kalau semua sudah terklasifikasi (semua UUID hilang ketemu
            -- status-nya: entah di inventory atau tidak), break retry
            local totalRemoved = 0
            for listUUID, _ in pairs(lastSellState.listings) do
                if not currentState.listings[listUUID] then
                    totalRemoved = totalRemoved + 1
                end
            end
            if totalRemoved > 0 and #soldPets + #unlistedPets == totalRemoved then
                break
            end
        end
        
        -- ⭐ KIRIM WEBHOOK hanya untuk yang BENAR-BENAR TERJUAL
        if #soldPets > 0 then
            for _, sold in ipairs(soldPets) do
                _G.SniperHub.SendWebhook("Sell", {
                    petName = sold.info.petType or "Unknown",
                    age = sold.info.age or 1,
                    weight = sold.info.weight or 0,
                    price = sold.info.price or 0,
                    mutation = sold.info.mutation or "Normal",
                    sellerName = player.Name,
                })
            end
            print(string.format("[Sell Monitor] 💰 %d pet TERJUAL", #soldPets))
            
            if _G.SniperHub.ResetHopTimer then
                _G.SniperHub.ResetHopTimer()
            end
        end
        
        -- ⭐ Log unlist (tapi tidak kirim webhook)
        if #unlistedPets > 0 then
            print(string.format("[Sell Monitor] 🗑️ %d pet di-unlist (skip webhook)", #unlistedPets))
        end
        
        lastSellState = currentState
    end)
    
    print("[Sell Monitor] ✅ Aktif di background")
end

local function stopSellMonitor()
    if sellMonitorConn then
        sellMonitorConn:Disconnect()
        sellMonitorConn = nil
    end
    lastSellState = nil
    print("[Sell Monitor] ❌ Dimatikan")
end

-- [PATCH 1C] Expose cleanup functions ke scope atas loadAoneHubTrade
cleanupSellMonitor = stopSellMonitor
cleanupAutoListing = function()
    isListing = false
    if buyConnection then
        buyConnection:Disconnect()
        buyConnection = nil
    end
    table.clear(queue)
    print("[AutoListing] ❌ Cleanup via close handler")
end

-- ⭐ Auto-start sell monitor saat script load (kalau webhook enabled)
if config.discordWebhookEnabled then
    task.defer(function()
        task.wait(3)  -- beri waktu script lain selesai load & booth data sync
        startSellMonitor()
    end)
end
        
local function startBuyLoop()
    if isListing then return end
    isListing = true
    table.clear(queue) -- Reset antrian setiap mulai baru

    if buyConnection then
        buyConnection:Disconnect()
        buyConnection = nil
    end
            
    -- 1. SCAN AWAL: Kumpulkan pet yang lolos filter dan belum dilisting
    local pets = getMyInventoryPets()
    local listedUUIDs = getMyListedUUIDs()
    
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

    task.wait(1)  -- beri waktu scan selesai
    lastKnownListings = snapshotMyListings()
            
    -- 2. JALANKAN PROSES ANTRIAN
    processQueue()
    
    -- 3. EVENT LISTENER: Deteksi jika ada slot kosong (pet terjual)
if not buyConnection then
    local myId = "Player_" .. tostring(player.UserId)

    local lastMyState = snapshotMyState()

buyConnection = boothReceiver:GetPathSignal("Players/" .. myId .. "/Listings"):Connect(function()
    task.wait(3)  -- beri waktu replication
    
    local currentMyState = snapshotMyState()
    
    -- ⭐ Cari UUID yang hilang dari listings
    local removedUUIDs = {}
    for listUUID, info in pairs(lastMyState.listings) do
        if not currentMyState.listings[listUUID] then
            table.insert(removedUUIDs, { listUUID = listUUID, info = info })
        end
    end
    
    -- ⭐ Untuk setiap UUID hilang, cek apakah masih kamu miliki
    local soldPets = {}
    local unlistedPets = {}
    
    for _, removed in ipairs(removedUUIDs) do
        local petUUID = removed.info.itemId
        local stillOwned = petUUID and currentMyState.ownedUUIDs[petUUID] == true
        
        if stillOwned then
            -- Pet kembali ke inventory = UNLIST
            table.insert(unlistedPets, removed)
            print(string.format("[AutoListing] 🗑️ %s di-unlist (kembali ke inventory)", 
                removed.info.petType or "?"))
        else
            -- Pet tidak di inventory, tidak di equipped = TERJUAL
            table.insert(soldPets, removed)
            print(string.format("[AutoListing] 💰 %s TERJUAL (hilang dari akun)", 
                removed.info.petType or "?"))
        end
    end
    
    if #soldPets > 0 then
        if _G.SniperHub.ResetHopTimer then
            _G.SniperHub.ResetHopTimer()
        end
    end
    
    -- Update baseline
    lastMyState = currentMyState
    
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
    config.autoListingEnabled = false
    saveConfig()
    table.clear(queue)
    if buyConnection then buyConnection:Disconnect() buyConnection = nil end
    if startListBtn and startListBtn.Parent then
        startListBtn.Text = "▶️ MULAI AUTO LISTING"
        startListBtn.BackgroundColor3 = C.success
    end

    -- ⭐ Kumpulkan UUID yang akan kamu unlist
    local unlistedUUIDs = {}
    local data = getBoothsData()
    if data and data.Players then
        local myId = "Player_" .. tostring(player.UserId)
        local myData = data.Players[myId]
        if myData and myData.Listings then
            for listUUID, _ in pairs(myData.Listings) do
                unlistedUUIDs[listUUID] = true
            end
        end
    end

    -- ⭐ Update baseline SEBELUM unlist — jadi listener tidak perlu di-skip
    for listUUID in pairs(unlistedUUIDs) do
        lastKnownListings[listUUID] = nil
    end

    -- Proses unlist (tanpa flag isUserUnlisting)
    local ok, err = pcall(function()
        if data and data.Players then
            local myId = "Player_" .. tostring(player.UserId)
            local myData = data.Players[myId]
            if myData and myData.Listings then
                local count = 0
                for listUUID, _ in pairs(myData.Listings) do
                    pcall(function() RemoveListingRF:InvokeServer(listUUID) end)
                    count = count + 1
                    task.wait(1)
                end
                print("[AutoListing] Unlist All selesai. " .. count .. " item dihapus.")
                _G.SniperHub.UpdateStatus("🗑️ " .. count .. " listing dihapus", C.warning)
            end
        end
    end)

    if not ok then warn("[AutoListing] Unlist error:", err) end
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
                selectedPetsLbl.Text = "Klik untuk memilih pet... (Wajib pilih minimal 1)"
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

forceHopBtn.MouseButton1Click:Connect(function()
    print("[AutoHop] ⚡ Force Hop ditekan pengguna!")
    hopStatusLbl.Text = "Status: Mencari server baru..."
    local success = hopServer()
    if not success then
        print("[AutoHop] ❌ Gagal menemukan server. Cek koneksi atau coba lagi.")
    end
end)
    
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
local teleportFailedConn = TeleportService.TeleportInitFailed:Connect(function(teleportPlayer, result, errorMessage, placeId)
    if teleportPlayer ~= player or not config.autoReconnectEnabled then return end
    warn("[AutoReconnect] Teleport gagal: " .. tostring(result) .. " | " .. tostring(errorMessage))
    tryReconnect("TeleportInitFailed")
end)

local errorMsgConn
pcall(function()
    errorMsgConn = GuiService.ErrorMessageChanged:Connect(function(message)
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

-- ⭐ Helper untuk disconnect semua
cleanupReconnectListeners = function()
    if teleportFailedConn then pcall(function() teleportFailedConn:Disconnect() end) end
    if errorMsgConn then pcall(function() errorMsgConn:Disconnect() end) end
end
        
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
                if not _G.AoneHub_IsAlive then return end
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
    isGuiDestroyed = true
    _G.AoneHub_IsAlive = false
    
    -- [PATCH 1D] Stop SEMUA loop dan listener
    if cleanupAutoBuy then pcall(cleanupAutoBuy) end
    if cleanupAutoListing then pcall(cleanupAutoListing) end
    if cleanupSellMonitor then pcall(cleanupSellMonitor) end
    if stopClaimLoop then pcall(stopClaimLoop) end
    if cleanupReconnectListeners then pcall(cleanupReconnectListeners) end
            
    _G.SniperHub.SendWebhook("TradeInactive", { reason = "Script Di-close (Tombol X)" })
    screenGui:Destroy()
end)

screenGui.Destroying:Connect(function()
    _G.AoneHub_IsAlive = false
    isGuiDestroyed = true
    
    -- [PATCH 1E] Stop SEMUA loop dan listener
    if cleanupAutoBuy then pcall(cleanupAutoBuy) end
    if cleanupAutoListing then pcall(cleanupAutoListing) end
    if cleanupSellMonitor then pcall(cleanupSellMonitor) end
    if stopClaimLoop then pcall(stopClaimLoop) end
    if cleanupReconnectListeners then pcall(cleanupReconnectListeners) end
    
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
    
-- ⭐ KILL SWITCH UNTUK INSTANCE BERIKUTNYA
_G.AoneHub_Cleanup = function()
    _G.AoneHub_IsAlive = false
    isGuiDestroyed = true
    isShuttingDown = true

    -- [PATCH 1F] Stop SEMUA loop dan listener
    if cleanupAutoBuy then pcall(cleanupAutoBuy) end
    if cleanupAutoListing then pcall(cleanupAutoListing) end
    if cleanupSellMonitor then pcall(cleanupSellMonitor) end
    if stopClaimLoop then pcall(stopClaimLoop) end
    if cleanupReconnectListeners then pcall(cleanupReconnectListeners) end
        
    if screenGui then 
        pcall(function() screenGui:Destroy() end) 
    end
end
end  -- ← end penutup loadAoneHubTrade        

local function loadAoneHubMain()
    
-- [PATCH 2A-FIX] Cleanup instance lama (execute 2x protection)
-- ⭐ pakai _G saja, TIDAK tambah local variable di scope ini
if _G.AoneHub_MainCleanup then
    pcall(_G.AoneHub_MainCleanup)
    _G.AoneHub_MainCleanup = nil
end
do
    local oldGui = playerGui:FindFirstChild("AoneHub")
    if oldGui then
        pcall(function() oldGui:Destroy() end)
    end
end

-- Instance ID disimpan di _G — tidak butuh local
_G.AoneHub_InstanceId = tostring(os.time()) .. "_" .. tostring(math.random(1, 999999))

-- ==================================================================
-- SERVICES & REQUIREMENTS
-- ==================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remotes
local PetEggService = ReplicatedStorage.GameEvents:WaitForChild("PetEggService")
local PetsServiceRE = ReplicatedStorage.GameEvents:WaitForChild("PetsService")
local FavoriteItemRE = ReplicatedStorage.GameEvents:WaitForChild("Favorite_Item")
local SellAllRE = ReplicatedStorage.GameEvents:WaitForChild("SellAllPets_RE")
local GiftPetEvent = ReplicatedStorage.GameEvents:WaitForChild("GiftPet")
local AcceptPetGift = ReplicatedStorage.GameEvents:WaitForChild("AcceptPetGift")
local PetGiftingService = ReplicatedStorage.GameEvents:WaitForChild("PetGiftingService")
local DeleteObjectRE = ReplicatedStorage.GameEvents:WaitForChild("DeleteObject")
local CropsCollectRE = ReplicatedStorage.GameEvents:WaitForChild("Crops"):WaitForChild("Collect")
local SellInventoryRE = ReplicatedStorage.GameEvents:WaitForChild("Sell_Inventory")

-- ⭐ Modules untuk teleport & data (pakai pcall, tidak butuh safeRequire)
local TeleportPlayer = nil
local GetFarm = nil
pcall(function() TeleportPlayer = require(ReplicatedStorage.Modules.TeleportPlayer) end)
pcall(function() GetFarm = require(ReplicatedStorage.Modules.GetFarm) end)

-- Services untuk Auto Leveling
local DataService = require(ReplicatedStorage.Modules.DataService)
local PetsService = require(ReplicatedStorage.Modules.PetServices.PetsService)
local PetShardService_RE = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetShardService_RE")
local PetRegistry = require(ReplicatedStorage.Data.PetRegistry)
local PetList = PetRegistry.PetList or {}

-- Constants
local MAX_PET_SLOTS = 8
local BASE_WEIGHT_NORMAL = 3.5
local BASE_WEIGHT_RAINBOW = 5.5
local LEVEL_TARGET_NORMAL = 50
local LEVEL_TARGET_RAINBOW = 40

-- Colors
local C = {
    bg = Color3.fromRGB(28, 28, 35),
    sidebar = Color3.fromRGB(22, 22, 28),
    accent = Color3.fromRGB(80, 120, 200),
    text = Color3.fromRGB(240, 240, 240),
    textDim = Color3.fromRGB(150, 150, 160),
    success = Color3.fromRGB(50, 180, 50),
    danger = Color3.fromRGB(200, 50, 50),
    warning = Color3.fromRGB(255, 200, 0),
    section = Color3.fromRGB(38, 38, 48),
    input = Color3.fromRGB(55, 55, 70),
}

-- ==================================================================
-- STRUKTUR do-end BLOCK (isolasi variable local)
-- Batas Lua/Luau: maksimal 200 local aktif per scope. Script dipecah
-- jadi beberapa do-end block; variable yang dipakai lintas block
-- dideklarasikan dulu ("shared") lalu diisi di dalam block-nya.
-- ==================================================================

-- shared: diisi di BLOCK 1 (CONFIG, MUTATION HELPERS, DISCORD WEBHOOK)
local SAVE_FILE, config, saveConfig, safeRequire
-- shared: diisi di BLOCK 2 (AUTO LEVELING STATE, STATISTICS TRACKING)
local speedPreset, hatchPreset, sellPreset, selectedTeamPreset, selectedWeightPreset, selectedAdvancedPreset, selectedMutationPreset,
    selectedPetTypes, allSelectedPets, targetLevel, advancedTargetLevel, isLeveling,
    isAutoWeight, isAdvancedLeveling, isAutoMutation, rainbowMode, targetSearchText,
    petSearchText, mutationSearchText, tempPresetPets, unwantedMutations, unwantedMutationsHatch, availableMutations,
    editingPresetName, isGuiDestroyed, isRunning, isGiftPetRunning, giftPetUserStarted,
    statusCallback, StatusLabel, updateStatus, rainbowTask, isAlive, A, rainbowColors,
    colorIndex, isAutoShovelRunning, autoShovelStatus,
    isAutoCollectRunning, autoCollectStatus, autoCollectSelectedFruits,
    autoCollectSelectedMutations, autoCollectMaxWeight, autoCollectInterval,
    autoCollectSellEnabled, autoCollectDelayAfterTeleport,
    autoCollectDelayAfterSell, autoCollectDelayAfterReturn
-- shared: diisi di BLOCK 3 (HELPER: PET COUNT, EGG, FARM, BACKPACK)
local getBackpackEggs, parsePetName, getAllPetTypesFromRegistry, getPlayerNames
-- shared: diisi di BLOCK 4 (PET DATA & PRESET FUNCTIONS)
local getPreset, getPlayerPetData, getPetType, getPetLevel, getPetDisplayName, getPetWeight, getPetMutationName, 
    getEquippedPets, isPetValid, cleanupInvalidPets, equipPet, unequipPet, getMutationStatus,
    useCleansingShard, saveTeamPreset, loadTeamPresets, getPresetUUIDs, deletePreset,
    getWeightTarget, getLevelTargetForWeight, getPetsForWeight, getPetsForMutation,
    getPetsForAdvanced, getPetsForNormalLeveling, sessionStats, startDiscordSession,
    finishDiscordSession, sendProgressWebhook
-- shared: diisi di BLOCK 5 (LOADOUT, FAVORIT, GIFT, MONITOR, AUTO HATCH LOOP)
local lastLoadoutSlot, GIFT_STATS, giftQueue, autoGiftAllFiltered, giftSharingPet, monitorLabels,
    refreshMonitor, startAutoHatch, stopAutoHatch,
    startAutoShovel, stopAutoShovel,
    startAutoCollect, stopAutoCollect, scanFruits,
    loadMutationList, loadFruitList, KNOWN_FRUITS, KNOWN_MUTATIONS, getFruitCapacity

do -- GROUP: BACKEND (logic, state, helper, data) (BLOCK 1-5)

    -- shared: diisi di BLOCK 1 (CONFIG, MUTATION HELPERS, DISCORD WEBHOOK)
    local splitPetName, sendDiscordWebhook, sendDiscordEmbed

    do -- BLOCK 1: CONFIG, MUTATION HELPERS, DISCORD WEBHOOK
        -- ==================================================================
        -- CONFIG
        -- ==================================================================
        local function getConfigPath()
            local basePath = "AoneHub"
            pcall(function() makefolder(basePath) end)
            return basePath .. "/AoneHub_Gag1.json"
        end

        SAVE_FILE = getConfigPath()

        config = {
            eggGridOffsets = {
                Vector3.new(13.63, -4.97, 7.74),
                Vector3.new(13.63, -4.97, 1.74),
                Vector3.new(13.63, -4.97, -5.74),
                Vector3.new(13.63, -4.97, -11.74),
                Vector3.new(31.63, -4.97, 7.74),
                Vector3.new(31.63, -4.97, 1.74),
                Vector3.new(31.63, -4.97, -5.74),
                Vector3.new(31.63, -4.97, -11.74),
                Vector3.new(19.63, -4.97, -2.74),
                Vector3.new(25.63, -4.97, -2.74),
                Vector3.new(18.13, -4.97, -16.24),
                Vector3.new(22.63, -4.97, -16.24),
                Vector3.new(27.13, -4.97, -16.24),
            },

            speedLoadout = 1,
            hatchLoadout = 2,
            sellLoadout = 3,

            speedPreset = nil,
            hatchPreset = nil,
            sellPreset = nil,

            selectedEggs = {},
            cycleCount = 1,
            autoSell = true,

            -- Delay
            delayAfterLoadout = 6.0,
            hatchDelay = 1.0,
            placeDelay = 1.0,
            scanSettleDelay = 1.5,
            delayAfterHatchAll = 2.0,
            delayAfterSpeed = 2.0,
            delayAfterHatch = 3.0,
            delayAfterSell = 2.0,
            delayBeforeSell = 3.0,
            equipDelay = 0.4,
            syncWaitTime = 2.0,

            -- Filter
            maxWeight = 3.5,
            maxLevel = 1,
            unwantedPetTypes = {},

            -- Webhook
            webhookUrl = "",
            webhookUsername = "Auto Hatch Report",

            -- Auto Accept Gift (giftDelayAfter default, bukan di GUI)
            giftEnabled = true,
            giftHideUI = true,
            giftDelayAfter = 2,
            giftDelayBetween = 3,

            -- Auto Gift Pet
            giftPetTarget = nil,
            giftPetMinWeight = 0,
            giftPetMaxWeight = 5.0,
            giftPetMinLevel = 0,
            giftPetMaxLevel = 100,
            giftPetDelayEquip = 1.0,
            giftPetDelayUnfavorit = 0.5,
            giftPetDelayBetween = 3.0,
            giftPetSelectedTypes = {},
            delayAfterGiftSync = 10,

            petSharingMutationEnabled = false,
            petSharingWeightEnabled = false,
            petSharingSelectedPet = nil,           -- fallback lama (boleh dipertahankan)
            petSharingTargetUsername = nil,
            petSharingSavedPetInfo = nil,           -- fallback lama
            petSharingWeightPetUUID = nil,
            petSharingMutationPetUUID = nil,
            -- BARU:
            petSharingWeightPet = nil,
            petSharingWeightSavedInfo = nil,
            petSharingMutationPet = nil,
            petSharingMutationSavedInfo = nil,

            teamPresets = {},
            weightPresets = {},
            mutationPresets = {},
            advancedPresets = {},
            targetLevel = 50,
            advancedTargetLevel = 500,
            maxWeightPetsPerSession = 1,      -- ⭐ BARU
            maxMutationPetsPerSession = 1,    -- ⭐ BARU
            maxAdvancedPetsPerSession = 1,    -- ⭐ BARU
            maxNormalPetsPerSession = 1,      -- ⭐ BARU
            rainbowMode = false,
            unwantedMutations = {},
            unwantedMutationsHatch = {},
            selectedTeamPreset = nil,
            selectedWeightPreset = nil,
            selectedMutationPreset = nil,
            selectedAdvancedPreset = nil,
            isAutoWeight = false,
            isAutoMutation = false,
            isAdvancedLeveling = false,
            selectedPetTypes = {},
            antiAfkToggle = false,
            discordWebhookEnabled = false,
            discordWebhook = "",
            sectionStates = {},

            -- Auto Collect
            autoCollectMaxWeight = 0,
            autoCollectInterval = 2,
            autoCollectSellEnabled = true,
            autoCollectDelayAfterTeleport = 1,
            autoCollectDelayAfterSell = 3,
            autoCollectDelayAfterReturn = 1,
            autoCollectSelectedFruits = {},
            autoCollectSelectedMutations = {},
        }

        local function loadConfig()
            local s, d = pcall(readfile, SAVE_FILE)
            if s and d then
                local s2, loaded = pcall(HttpService.JSONDecode, HttpService, d)
                if s2 and loaded then
                    for k, v in pairs(loaded) do 
                        config[k] = v 
                    end

                    if config.teamPresets == nil then config.teamPresets = {} end
                    if config.weightPresets == nil then config.weightPresets = {} end
                    if config.mutationPresets == nil then config.mutationPresets = {} end
                    if config.advancedPresets == nil then config.advancedPresets = {} end
                    if config.targetLevel == nil then config.targetLevel = 50 end
                    if config.advancedTargetLevel == nil then config.advancedTargetLevel = 500 end
                    if config.maxWeightPetsPerSession == nil then config.maxWeightPetsPerSession = 1 end
                    if config.maxMutationPetsPerSession == nil then config.maxMutationPetsPerSession = 1 end
                    if config.maxAdvancedPetsPerSession == nil then config.maxAdvancedPetsPerSession = 1 end
                    if config.maxNormalPetsPerSession == nil then config.maxNormalPetsPerSession = 1 end
                    if config.rainbowMode == nil then config.rainbowMode = false end
                    if config.unwantedMutations == nil then config.unwantedMutations = {} end
                    if config.isAutoWeight == nil then config.isAutoWeight = false end
                    if config.isAutoMutation == nil then config.isAutoMutation = false end
                    if config.isAdvancedLeveling == nil then config.isAdvancedLeveling = false end
                    if config.selectedPetTypes == nil then config.selectedPetTypes = {} end
                    if config.antiAfkToggle == nil then config.antiAfkToggle = false end
                    if config.discordWebhookEnabled == nil then config.discordWebhookEnabled = false end
                    if config.discordWebhook == nil then config.discordWebhook = "" end
                    if config.sectionStates == nil then config.sectionStates = {} end
                    if config.unwantedMutationsHatch == nil then config.unwantedMutationsHatch = {} end
                    if config.unwantedPetTypes == nil then config.unwantedPetTypes = {} end
                    if config.giftPetSelectedTypes == nil then config.giftPetSelectedTypes = {} end
                    if config.petSharingMutationEnabled == nil then config.petSharingMutationEnabled = false end
                    if config.petSharingWeightEnabled == nil then config.petSharingWeightEnabled = false end
                    if config.petSharingSelectedPet == nil then config.petSharingSelectedPet = nil end
                    if config.petSharingTargetUsername == nil then config.petSharingTargetUsername = nil end
                    if config.petSharingSavedPetInfo == nil then config.petSharingSavedPetInfo = nil end
                    if config.petSharingWeightPetUUID == nil then config.petSharingWeightPetUUID = nil end
                    if config.petSharingMutationPetUUID == nil then config.petSharingMutationPetUUID = nil end
                    if config.petSharingWeightPet == nil then config.petSharingWeightPet = nil end
                    if config.petSharingWeightSavedInfo == nil then config.petSharingWeightSavedInfo = nil end
                    if config.petSharingMutationPet == nil then config.petSharingMutationPet = nil end
                    if config.petSharingMutationSavedInfo == nil then config.petSharingMutationSavedInfo = nil end
                    if config.autoCollectMaxWeight == nil then config.autoCollectMaxWeight = 0 end
                    if config.autoCollectInterval == nil then config.autoCollectInterval = 2 end
                    if config.autoCollectSellEnabled == nil then config.autoCollectSellEnabled = true end
                    if config.autoCollectDelayAfterTeleport == nil then config.autoCollectDelayAfterTeleport = 1 end
                    if config.autoCollectDelayAfterSell == nil then config.autoCollectDelayAfterSell = 3 end
                    if config.autoCollectDelayAfterReturn == nil then config.autoCollectDelayAfterReturn = 1 end
                    if config.autoCollectSelectedFruits == nil then config.autoCollectSelectedFruits = {} end
                    if config.autoCollectSelectedMutations == nil then config.autoCollectSelectedMutations = {} end

                    return true
                end
            end
            return false
        end

        -- ⭐ Simpan instance ID lokal supaya saveConfig tahu miliknya siapa
        -- (dideklarasi di scope loadAoneHubMain via task.defer di Patch 2B)
        function saveConfig()
            -- [PATCH 5-FIX] Guard: hanya instance aktif yang boleh save
            -- Bandingkan dengan instance ID yang di-set saat runtime
            if _G.AoneHub_MySaveId and _G.AoneHub_MySaveId ~= _G.AoneHub_InstanceId then
                return
            end
    
            local data = {}
            for k, v in pairs(config) do
                if k ~= "eggGridOffsets" then
                    data[k] = v
                end
            end
            local s, json = pcall(HttpService.JSONEncode, HttpService, data)
            if s then 
                pcall(writefile, SAVE_FILE, json) 
            end
        end

        -- ⭐ Expose ke global agar bisa diakses Block 16
        _G.AoneHub_SaveConfig = saveConfig
        _G.AoneHub_Config = config
        
        loadConfig()

        -- ==================================================================
        -- MUTATION HELPERS
        -- ==================================================================
        local function getUnwantedMutations()
            return config.unwantedMutationsHatch or {}
        end

        function splitPetName(petName)
            if not petName then
                return petName, nil
            end

            for _, mutName in ipairs(getUnwantedMutations()) do
                if petName:sub(1, #mutName + 1) == mutName .. " " then
                    return petName:sub(#mutName + 2), mutName
                end
            end

            return petName, nil
        end

        -- ==================================================================
        -- DISCORD WEBHOOK
        -- ==================================================================
        local function getHttpRequest()
            if typeof(request) == "function" then
                return request
            end
            if typeof(http_request) == "function" then
                return http_request
            end
            if syn and typeof(syn.request) == "function" then
                return syn.request
            end
            if fluxus and typeof(fluxus.request) == "function" then
                return fluxus.request
            end
            return nil
        end

        function sendDiscordWebhook(payload)
            if not config.discordWebhookEnabled then
                return false, "Webhook OFF"
            end

            local webhookUrl = tostring(config.discordWebhook or "")
            if webhookUrl == "" then
                return false, "Webhook URL kosong"
            end

            local httpRequest = getHttpRequest()
            if not httpRequest then
                warn("[AoneHub] Discord Webhook: executor tidak menyediakan request()")
                return false, "Executor tidak mendukung HTTP request"
            end

            local ok, result = pcall(function()
                return httpRequest({
                    Url = webhookUrl,
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json"
                    },
                    Body = HttpService:JSONEncode(payload)
                })
            end)

            if not ok then
                warn("[AoneHub] Discord Webhook Error:", result)
                return false, tostring(result)
            end

            return true, result
        end

        function sendDiscordEmbed(title, description, color)
            return sendDiscordWebhook({
                username = "AoneHub",
                embeds = {{
                    title = title,
                    description = description,
                    color = color or 3447003,
                    footer = {
                        text = "AoneHub • Auto Leveling"
                    },
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }}
            })
        end

        function safeRequire(path)
            local s, r = pcall(function() 
                return require(path) 
            end)
            if s then return r end
            return nil
        end
    end -- BLOCK 1

    -- shared: diisi di BLOCK 2 (AUTO LEVELING STATE, STATISTICS TRACKING)
    local queuedPets, equippedTargetPets, isWaitingEggTimer, isAutoGiftActive,
        isAutoAcceptActive, isCheckingPetSharing, STATS, resetStats, getInventoryUUIDs, scanNewPetsAfterSell

    do -- BLOCK 2: AUTO LEVELING STATE, STATISTICS TRACKING
        -- ==================================================================
        -- AUTO LEVELING STATE
        -- ==================================================================
        speedPreset = config.speedPreset
        hatchPreset = config.hatchPreset
        sellPreset = config.sellPreset
        selectedTeamPreset = config.selectedTeamPreset
        selectedWeightPreset = config.selectedWeightPreset
        selectedAdvancedPreset = config.selectedAdvancedPreset
        selectedMutationPreset = config.selectedMutationPreset
        selectedPetTypes = config.selectedPetTypes or {}
        queuedPets = {}
        allSelectedPets = {}
        equippedTargetPets = {}
        targetLevel = config.targetLevel or 50
        advancedTargetLevel = config.advancedTargetLevel or 500
        isLeveling = false
        isAutoWeight = config.isAutoWeight or false
        isAdvancedLeveling = config.isAdvancedLeveling or false
        isAutoMutation = config.isAutoMutation or false
        rainbowMode = config.rainbowMode or false
        targetSearchText = ""
        petSearchText = ""
        mutationSearchText = ""
        tempPresetPets = {}
        unwantedMutations = config.unwantedMutations or {}
        unwantedMutationsHatch = config.unwantedMutationsHatch or {}
        availableMutations = {}
        editingPresetName = nil
        isGuiDestroyed = false  -- ⭐ TAMBAHKAN INI

        -- Auto Hatch State
        isRunning = false
        isGiftPetRunning = false
        giftPetUserStarted = false
        isWaitingEggTimer = false
        isAutoGiftActive = false
        isAutoAcceptActive = false
        isCheckingPetSharing = false
        statusCallback = nil
        -- ⭐ Auto Shovel State
        isAutoShovelRunning = false
        autoShovelStatus = nil

        -- ⭐ Auto Collect State
        isAutoCollectRunning = false
        autoCollectStatus = nil
        autoCollectSelectedFruits = {}     -- set: ["strawberry"] = true
        autoCollectSelectedMutations = {}  -- set: ["glimmering"] = true
        autoCollectMaxWeight = 0
        autoCollectInterval = 2
        autoCollectSellEnabled = true
        autoCollectDelayAfterTeleport = 1
        autoCollectDelayAfterSell = 3
        autoCollectDelayAfterReturn = 1

        -- Forward declarations
        rainbowTask = nil

        -- ⭐ Helper function untuk cek apakah masih alive
        function isAlive()
            return not isGuiDestroyed and isLeveling
        end

        -- Warna yang digunakan
        A = {
            warning = Color3.fromRGB(255, 200, 0),
            danger = Color3.fromRGB(255, 60, 60),
        }

        -- Daftar warna rainbow
        rainbowColors = {
            Color3.fromRGB(255, 60, 60),   -- 🔴 Merah
            Color3.fromRGB(255, 200, 0),   -- 🟡 Kuning
            Color3.fromRGB(60, 200, 80),   -- 🟢 Hijau
            Color3.fromRGB(30, 100, 220),  -- 🔵 Biru
            Color3.fromRGB(150, 60, 220),  -- 🟣 Ungu
        }

        colorIndex = 1

        -- ==================================================================
        -- STATISTICS TRACKING
        -- ==================================================================
        STATS = {}

        function resetStats()
            STATS = {
                sessionStart = os.time(),
                totalHatchCycles = 0,
                totalHatched = 0,
                cycleStartTime = 0,
                lastCycleDuration = 0,
                huntStats = { Huge = {}, Titan = {}, Godly = {}, Special = {} },
                eggBeforePlace = 0,
                eggAfterSell = 0,
                knownUUIDs = {},
            }
        end

        resetStats()

        local function extractPetInfo(petData)
            if typeof(petData) ~= "table" then return nil end
            local petName = petData.PetType or petData.Name or (petData.PetData and petData.PetData.PetType) or "?"
            local baseWeight = petData.BaseWeight or (petData.PetData and petData.PetData.BaseWeight) or 0
            local level = petData.Level or (petData.PetData and petData.PetData.Level) or 0
            local isFav = petData.IsFavorite or (petData.PetData and petData.PetData.IsFavorite) or false
            return { petName = petName, baseWeight = baseWeight, level = level, isFavorited = isFav }
        end

        function getInventoryUUIDs()
            local uuids = {}
            local data = DataService:GetData()
            if not data or not data.PetsData then return uuids end
            local inventory = data.PetsData.PetInventory and data.PetsData.PetInventory.Data
            if not inventory then return uuids end
            for uuid, _ in pairs(inventory) do uuids[uuid] = true end
            return uuids
        end

        local function getPetRarityFromBaseWeight(petName, baseWeight)
            if baseWeight then
                if baseWeight >= 10 and baseWeight <= 12 then return "Godly" end
                if baseWeight >= 7 and baseWeight <= 9 then return "Titan" end
                if baseWeight >= 4 and baseWeight <= 6 then return "Huge" end
            end
            if petName and not (config.unwantedPetTypes and config.unwantedPetTypes[petName]) then
                return "Special"
            end            
            return nil
        end

        local function addHuntStat(rarity, petName, weight)
            if not rarity then return end
            local bucket = STATS.huntStats[rarity]
            if not bucket then return end
            if not bucket[petName] then
                bucket[petName] = { count = 0, minWeight = weight, maxWeight = weight }
            end
            local entry = bucket[petName]
            entry.count = entry.count + 1
            if weight < entry.minWeight then entry.minWeight = weight end
            if weight > entry.maxWeight then entry.maxWeight = weight end
        end

        function scanNewPetsAfterSell()
            local data = DataService:GetData()
            if not data or not data.PetsData then return 0 end
            local inventory = data.PetsData.PetInventory and data.PetsData.PetInventory.Data
            if not inventory then return 0 end
            local newCount = 0
            for uuid, petData in pairs(inventory) do
                if not STATS.knownUUIDs[uuid] then
                    STATS.knownUUIDs[uuid] = true
                    newCount = newCount + 1
                    local info = extractPetInfo(petData)
                    if not info then continue end
                    local petName = info.petName
                    local baseWeight = info.baseWeight
                    local baseName = splitPetName(petName)
                    if config.unwantedPetTypes[baseName] 
                       and baseWeight <= config.maxWeight 
                       and info.level <= config.maxLevel then
                        print(string.format("[Stats] Skip unwanted: %s", petName))
                    else
                        local rarity = getPetRarityFromBaseWeight(petName, baseWeight)
                        addHuntStat(rarity, petName, baseWeight)
                    end
                end
            end
            return newCount
        end
    end -- BLOCK 2

    -- shared: diisi di BLOCK 3 (HELPER: PET COUNT, EGG, FARM, BACKPACK)
    local getPetCountFromData, countEggsInBackpack, getCenterPoint, getMyGardenEggs,
        getEmptySlots, hatchEgg, findEggTool, getBackpackPets, findPetToolByName,
        findPlayerByName

    do -- BLOCK 3: HELPER: PET COUNT, EGG, FARM, BACKPACK
        -- ==================================================================
        -- HELPER: Pet Count
        -- ==================================================================
        function getPetCountFromData()
            local data = DataService:GetData()
            if not data or not data.PetsData then return 0, 0 end
            local petsData = data.PetsData
            local current = 0
            if petsData.PetInventory and petsData.PetInventory.Data then
                for _ in pairs(petsData.PetInventory.Data) do current = current + 1 end
            end
            local max = 0
            if petsData.MutableStats and petsData.MutableStats.MaxPetsInInventory then
                max = petsData.MutableStats.MaxPetsInInventory
            end
            return current, max
        end


        -- ==================================================================
        -- HELPER: Count Egg
        -- ==================================================================
        function countEggsInBackpack()
            local total = 0
            local seen = {}
            local locations = {}
            local backpack = player:FindFirstChild("Backpack")
            if backpack then table.insert(locations, backpack) end
            if player.Character then table.insert(locations, player.Character) end
            for _, container in ipairs(locations) do
                for _, tool in ipairs(container:GetChildren()) do
                    if tool:IsA("Tool") and tool:GetAttribute("b") == "c" then
                        if not seen[tool] then
                            seen[tool] = true
                            local eggName = tool:GetAttribute("h")
                            local isSelected = false
                            if next(config.selectedEggs) == nil then
                                isSelected = true
                            else
                                for name, val in pairs(config.selectedEggs) do
                                    if name == eggName and val then isSelected = true break end
                                end
                            end
                            if isSelected then
                                total = total + (tool:GetAttribute("e") or 0)
                            end
                        end
                    end
                end
            end
            return total
        end

        -- ==================================================================
        -- HELPER: FARM
        -- ==================================================================
        local function getMyFarm()
            local farmContainer = workspace:FindFirstChild("Farm")
            if not farmContainer then return nil end
            for _, farm in ipairs(farmContainer:GetChildren()) do
                local important = farm:FindFirstChild("Important")
                local dataFolder = important and important:FindFirstChild("Data")
                if dataFolder then
                    for _, obj in ipairs(dataFolder:GetChildren()) do
                        if obj:IsA("StringValue") and obj.Value == player.Name then
                            return farm
                        end
                    end
                end
            end
            return nil
        end

        function getCenterPoint()
            local farm = getMyFarm()
            if not farm then return nil end
            local center = farm:FindFirstChild("Center_Point")
            if center then return center end
            for _, obj in ipairs(farm:GetDescendants()) do
                if obj.Name == "Center_Point" then return obj end
            end
            return nil
        end

        -- ==================================================================
        -- HELPER: EGG
        -- ==================================================================
        function getMyGardenEggs()
            local eggs = {}
            for _, egg in CollectionService:GetTagged("PetEggServer") do
                if egg:GetAttribute("OWNER") == player.Name then
                    table.insert(eggs, egg)
                end
            end
            return eggs
        end

        local function getOccupiedSlots()
            local center = getCenterPoint()
            if not center then return {} end
            local occupied = {}
            local centerPos = center.Position
            local THRESHOLD = 3
            for _, egg in ipairs(getMyGardenEggs()) do
                local offset = egg:GetPivot().Position - centerPos
                for i, gridOffset in ipairs(config.eggGridOffsets) do
                    if (offset - gridOffset).Magnitude < THRESHOLD then
                        occupied[i] = true
                        break
                    end
                end
            end
            return occupied
        end

        function getEmptySlots()
            local occupied = getOccupiedSlots()
            local emptySlots = {}
            for i = 1, #config.eggGridOffsets do
                if not occupied[i] then table.insert(emptySlots, i) end
            end
            return emptySlots, occupied
        end

        function hatchEgg(eggModel)
            pcall(function()
                PetEggService:FireServer("HatchPet", eggModel)
            end)
        end

        -- ==================================================================
        -- HELPER: BACKPACK
        -- ==================================================================
        local function isEggTool(tool)
            return tool:IsA("Tool") and tool:GetAttribute("b") == "c"
        end

        local function isPetTool(tool)
            return tool:IsA("Tool") and tool:GetAttribute("ItemType") == "Pet"
        end

        function findEggTool()
            local locations = {}
            local backpack = player:FindFirstChild("Backpack")
            if backpack then table.insert(locations, {name="Backpack", container=backpack}) end
            if player.Character then table.insert(locations, {name="Tangan", container=player.Character}) end
            for _, loc in ipairs(locations) do
                for _, tool in ipairs(loc.container:GetChildren()) do
                    if isEggTool(tool) then
                        local eggName = tool:GetAttribute("h")
                        local count = tool:GetAttribute("e") or 0
                        local isSelected = false
                        if next(config.selectedEggs) == nil then
                            isSelected = true
                        else
                            for name, val in pairs(config.selectedEggs) do
                                if name == eggName and val then isSelected = true break end
                            end
                        end
                        if count > 0 and isSelected then return tool end
                    end
                end
            end
            return nil
        end

        function getBackpackEggs()
            local eggs = {}
            local backpack = player:FindFirstChild("Backpack")
            if not backpack then return eggs end
            for _, tool in ipairs(backpack:GetChildren()) do
                if isEggTool(tool) then
                    local name = tool:GetAttribute("h")
                    local count = tool:GetAttribute("e") or 0
                    if name and count > 0 then
                        table.insert(eggs, { tool = tool, name = name, count = count })
                    end
                end
            end
            return eggs
        end

        function parsePetName(toolName)
            local name, weight, level = toolName:match("^(.+) %[([%d%.]+) KG%] %[Age (%d+)%]$")
            if not name then
                name, weight, level = toolName:match("^(.+)%s+%[([%d%.]+) KG%]%s+%[Age (%d+)%]")
            end
            if name then
                return name:gsub("%s+$", ""), tonumber(weight) or 0, tonumber(level) or 0
            end
            name, weight = toolName:match("^(.+) %[([%d%.]+) KG%]$")
            if name then
                return name:gsub("%s+$", ""), tonumber(weight) or 0, 0
            end
            return nil, 0, 0
        end

        function getBackpackPets()
            local pets = {}
            local seen = {}
            local locations = {}
            local backpack = player:FindFirstChild("Backpack")
            if backpack then table.insert(locations, {name="Backpack", container=backpack}) end
            if player.Character then table.insert(locations, {name="Tangan", container=player.Character}) end
            for _, loc in ipairs(locations) do
                for _, tool in ipairs(loc.container:GetChildren()) do
                    if isPetTool(tool) and not seen[tool] then
                        seen[tool] = true
                        local name, weight, level = parsePetName(tool.Name)
                        if name then
                            table.insert(pets, {
                                tool = tool,
                                name = name,
                                weight = weight,
                                level = level,
                                isFavorited = tool:GetAttribute("d") == true,
                                location = loc.name,
                            })
                        end
                    end
                end
            end
            return pets
        end

        function getAllPetTypesFromRegistry()
            local types = {}
            for petName, _ in pairs(PetList) do
                table.insert(types, petName)
            end
            table.sort(types)
            return types
        end

        function findPetToolByName(petName)
            local locations = {}
            local backpack = player:FindFirstChild("Backpack")
            if backpack then table.insert(locations, backpack) end
            if player.Character then table.insert(locations, player.Character) end
            for _, container in ipairs(locations) do
                for _, tool in ipairs(container:GetChildren()) do
                    if tool:IsA("Tool") and tool:GetAttribute("ItemType") == "Pet" then
                        local name = parsePetName(tool.Name)
                        if name == petName then return tool end
                    end
                end
            end
            return nil
        end

        function getPlayerNames()
            local names = {}
            for _, p in ipairs(game.Players:GetPlayers()) do
                if p ~= player then table.insert(names, p.Name) end
            end
            table.sort(names)
            return names
        end

        function findPlayerByName(name)
            for _, p in ipairs(game.Players:GetPlayers()) do
                if p.Name == name then return p end
            end
            return nil
        end
    end -- BLOCK 3

    -- shared: diisi di BLOCK 4 (PET DATA & PRESET FUNCTIONS)
    local isPetUUIDValid, isPetInPreset, buildWebhookEmbed

    do -- BLOCK 4: PET DATA & PRESET FUNCTIONS
        -- ==================================================================
        -- PET DATA FUNCTIONS
        -- ==================================================================
        function getPlayerPetData()
            local playerData = DataService:GetData()
            if playerData and playerData.PetsData then
                return playerData.PetsData
            end
            return nil
        end

        function isPetUUIDValid(uuid)
            local petsData = getPlayerPetData()
            if not petsData or not petsData.PetInventory then return false end
            return petsData.PetInventory.Data[uuid] ~= nil
        end

        function getPetType(petUUID)
            local petsData = getPlayerPetData()
            if not petsData then return "Unknown" end

            local petData = petsData.PetInventory.Data[petUUID]
            if petData then
                if petData.PetType then
                    return petData.PetType
                elseif petData.PetData then
                    return petData.PetData.PetType or petData.PetData.Type or "Unknown"
                elseif petData.Type then
                    return petData.Type
                end
            end
            return "Unknown"
        end

        function getPetLevel(petUUID)
            local petsData = getPlayerPetData()
            if not petsData then return 0 end

            local petData = petsData.PetInventory.Data[petUUID]
            if petData then
                if petData.Level then
                    return petData.Level
                elseif petData.PetData then
                    return petData.PetData.Level or petData.PetData.CurrentLevel or 0
                end
            end
            return 0
        end

        function getPetMutationName(petUUID)
            local petsData = getPlayerPetData()
            if not petsData then return nil end

            local petData = petsData.PetInventory.Data[petUUID]
            if not petData then return nil end

            local mutationType = nil
            if petData.PetData then
                mutationType = petData.PetData.MutationType
            end
            if not mutationType then
                mutationType = petData.MutationType
            end

            if mutationType and mutationType ~= "None" and mutationType ~= "Normal" and mutationType ~= "m" then
                local registry = safeRequire(ReplicatedStorage.Data.PetRegistry.PetMutationRegistry)
                if registry and registry.EnumToPetMutation then
                    local mutationName = registry.EnumToPetMutation[mutationType]
                    if mutationName then
                        return mutationName
                    end
                end
                return mutationType
            end
            return nil
        end

        function getPetDisplayName(petUUID)
            local petType = getPetType(petUUID)
            local mutation = getPetMutationName(petUUID)
            if mutation then
                return string.format("%s %s", mutation, petType)
            end
            return petType
        end

        function getPetWeight(petUUID)
            local petsData = getPlayerPetData()
            if not petsData then return 0 end

            local petData = petsData.PetInventory.Data[petUUID]
            if petData then
                if petData.BaseWeight then
                    return petData.BaseWeight
                elseif petData.PetData and petData.PetData.BaseWeight then
                    return petData.PetData.BaseWeight
                elseif petData.Weight then
                    return petData.Weight
                elseif petData.PetData and petData.PetData.Weight then
                    return petData.PetData.Weight
                end
            end
            return 0
        end

        function getEquippedPets()
            local petsData = getPlayerPetData()
            if not petsData then return {} end
            return petsData.EquippedPets or {}
        end

        function isPetValid(petUUID)
            if not petUUID then return false end

            local petsData = getPlayerPetData()
            if not petsData then return false end

            local inventory = petsData.PetInventory.Data
            if not inventory then return false end

            return inventory[petUUID] ~= nil
        end

        function cleanupInvalidPets()
            local removedCount = 0

            for i = #allSelectedPets, 1, -1 do
                if not isPetValid(allSelectedPets[i]) then
                    table.remove(allSelectedPets, i)
                    removedCount = removedCount + 1
                end
            end

            for i = #queuedPets, 1, -1 do
                if not isPetValid(queuedPets[i]) then
                    table.remove(queuedPets, i)
                end
            end

            for i = #equippedTargetPets, 1, -1 do
                if not isPetValid(equippedTargetPets[i]) then
                    table.remove(equippedTargetPets, i)
                end
            end

            if removedCount > 0 and StatusLabel then
                StatusLabel.Text = string.format("⚠️ %d pet hilang, dihapus", removedCount)
            end

            return removedCount
        end

        function equipPet(petUUID)
            if not isPetValid(petUUID) then
                return false, "Pet tidak valid/hilang"
            end

            local success, err = pcall(function()
                PetsService:EquipPet(petUUID, CFrame.new(0, 10, 0))
            end)

            if not success then
                return false, tostring(err)
            end

            wait(0.5)
            local equipped = getEquippedPets()
            if not table.find(equipped, petUUID) then
                return false, "Pet tidak ter-equip"
            end

            return true, nil
        end

        function unequipPet(petUUID)
            local success = pcall(function()
                PetsService:UnequipPet(petUUID)
            end)
            return success
        end

        function getMutationStatus(petUUID)
            local petsData = getPlayerPetData()
            if not petsData then return "none" end

            local petData = petsData.PetInventory.Data[petUUID]
            if not petData then return "none" end

            local mutationType = nil
            if petData.PetData then
                mutationType = petData.PetData.MutationType
            end
            if not mutationType then
                mutationType = petData.MutationType
            end

            if not mutationType or mutationType == "None" or mutationType == "Normal" or mutationType == "m" then
                return "none"
            end

            local mutationName = mutationType
            local registry = safeRequire(ReplicatedStorage.Data.PetRegistry.PetMutationRegistry)
            if registry and registry.EnumToPetMutation then
                mutationName = registry.EnumToPetMutation[mutationType] or mutationType
            end

            for _, unwanted in ipairs(unwantedMutations) do
                if unwanted == mutationName then
                    return "unwanted", mutationName
                end
            end

            return "desired", mutationName
        end

        local function findPetModelByUUID(petUUID)
            local petsPhysical = workspace:FindFirstChild("PetsPhysical")
            if not petsPhysical then return nil end

            for _, child in ipairs(petsPhysical:GetChildren()) do
                if child.Name == "PetMover" then
                    local petModel = child:FindFirstChild(petUUID)
                    if petModel then
                        return petModel
                    end
                end
            end

            for _, descendant in ipairs(petsPhysical:GetDescendants()) do
                if descendant:IsA("Model") and descendant.Name == petUUID then
                    return descendant
                end
            end

            return nil
        end

        local function isCleansingShard(tool)
            if not tool:IsA("Tool") then return false end

            local shardType = tool:GetAttribute("u")
            if shardType then
                return tostring(shardType) == "Cleansing Pet Shard"
            end

            local nameLower = string.lower(tool.Name)
            return string.find(nameLower, "cleansing") ~= nil
        end

        function useCleansingShard(petUUID)
            if not isPetValid(petUUID) then
                return false, "Pet sudah tidak ada"
            end

            local backpack = player:FindFirstChild("Backpack")
            if not backpack then 
                return false, "Backpack tidak ditemukan"
            end

            local cleansingTool = nil
            for _, tool in ipairs(backpack:GetChildren()) do
                if isCleansingShard(tool) then
                    cleansingTool = tool
                    break
                end
            end

            if not cleansingTool then
                return false, "Tidak ada Cleansing Shard"
            end

            local petModel = findPetModelByUUID(petUUID)
            if not petModel then
                for i = 1, 10 do
                    wait(0.5)
                    petModel = findPetModelByUUID(petUUID)
                    if petModel then break end
                end

                if not petModel then
                    return false, "Pet model tidak ditemukan"
                end
            end

            local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if not humanoid then
                return false, "Humanoid tidak ditemukan"
            end

            local equipOk = pcall(function()
                humanoid:EquipTool(cleansingTool)
            end)

            if not equipOk then
                return false, "Gagal equip tool"
            end

            wait(0.5)

            local fireOk, fireErr = pcall(function()
                PetShardService_RE:FireServer("ApplyShard", petModel)
            end)

            if not fireOk then
                return false, "FireServer error: " .. tostring(fireErr)
            end

            wait(2)

            pcall(function()
                humanoid:UnequipTools()
            end)

            wait(0.5)

            return true, nil
        end

        -- ==================================================================
        -- PRESET FUNCTIONS
        -- ==================================================================
        function saveTeamPreset(presetName, petList)
            local petsWithInfo = {}
            for _, petUUID in ipairs(petList) do
                local mutation = getPetMutationName(petUUID)
                table.insert(petsWithInfo, {
                    UUID = petUUID,
                    PetType = getPetType(petUUID),
                    Mutation = mutation,
                    Level = getPetLevel(petUUID)
                })
            end

            config.teamPresets[presetName] = {
                name = presetName,
                pets = petsWithInfo,
                savedAt = os.time()
            }

            saveConfig()
        end

        function loadTeamPresets()
            return config.teamPresets or {}
        end

        function deletePreset(presetName)
            if not presetName then return false end

            if config.teamPresets[presetName] then
                config.teamPresets[presetName] = nil
                saveConfig()
                return true
            end
            return false
        end

        local function getPresetNames()
            if not config or not config.teamPresets then
                return {}
            end

            local names = {}

            for name, _ in pairs(config.teamPresets) do
                table.insert(names, name)
            end

            table.sort(names)
            return names
        end

        function getPreset(presetName)
            if not config or not config.teamPresets then
                return nil
            end

            return config.teamPresets[presetName]
        end

        function getPresetUUIDs(presetName)
            local preset = getPreset(presetName)

            if not preset or not preset.pets then
                return {}
            end

            local uuids = {}

            for _, petInfo in ipairs(preset.pets) do
                if isPetUUIDValid(petInfo.UUID) then
                    table.insert(uuids, petInfo.UUID)
                end
            end

            return uuids
        end

        function isPetInPreset(petDisplayName)
            local baseName = splitPetName(petDisplayName)

            for _, presetName in ipairs({
                config.speedPreset,
                config.hatchPreset,
                config.sellPreset
            }) do
                if presetName then
                    local preset = getPreset(presetName)

                    if preset and preset.pets then
                        for _, petInfo in ipairs(preset.pets) do
                            if petInfo.PetType == baseName
                                or petInfo.PetType == petDisplayName then
                                return true
                            end

                            if petInfo.Mutation
                                and petInfo.Mutation ~= "Normal"
                                and (petInfo.Mutation .. " " .. petInfo.PetType) == petDisplayName then
                                return true
                            end
                        end
                    end
                end
            end

            return false
        end

        function getWeightTarget()
            return rainbowMode and BASE_WEIGHT_RAINBOW or BASE_WEIGHT_NORMAL
        end

        function getLevelTargetForWeight()
            return rainbowMode and LEVEL_TARGET_RAINBOW or LEVEL_TARGET_NORMAL
        end

        function getPetsForWeight()
            local weightTarget = getWeightTarget()
            local result = {}

            for _, petUUID in ipairs(allSelectedPets) do
                if isPetValid(petUUID) then
                    local petWeight = getPetWeight(petUUID)
                    if petWeight < weightTarget then
                        table.insert(result, petUUID)
                    end
                end
            end

            return result
        end

        function getPetsForMutation()
            local result = {}

            for _, petUUID in ipairs(allSelectedPets) do
                if isPetValid(petUUID) then
                    local status = getMutationStatus(petUUID)
                    if status == "none" or status == "unwanted" then
                        table.insert(result, petUUID)
                    end
                end
            end

            return result
        end

        function getPetsForAdvanced()
            local result = {}

            for _, petUUID in ipairs(allSelectedPets) do
                if isPetValid(petUUID) then
                    local petLevel = getPetLevel(petUUID)
                    if petLevel < advancedTargetLevel then
                        table.insert(result, petUUID)
                    end
                end
            end

            return result
        end

        function getPetsForNormalLeveling()
            local result = {}

            for _, petUUID in ipairs(allSelectedPets) do
                if isPetValid(petUUID) then
                    local petLevel = getPetLevel(petUUID)
                    if petLevel < targetLevel then
                        table.insert(result, petUUID)
                    end
                end
            end

            return result
        end

        local function formatDuration(seconds)
            local hours = math.floor(seconds / 3600)
            local minutes = math.floor((seconds % 3600) / 60)
            local secs = seconds % 60

            if hours > 0 then
                return string.format("%02d:%02d:%02d", hours, minutes, secs)
            end

            return string.format("%02d:%02d", minutes, secs)
        end

        sessionStats = {
            active = false,
            startedAt = 0,
            totalPets = 0,
            modes = {},
            presets = {},
            -- ⭐ BARU: Progress tracking
            progress = {
                weight = { done = {}, total = {} },       -- { done = {UUID=true}, total = {UUID=true} }
                mutation = { done = {}, total = {} },
                normal = { done = {}, total = {} },
                advanced = { done = {}, total = {} },
            },
        }

        local function getSessionModesText()
            local modes = {}

            if sessionStats.modes.weight then
                table.insert(modes, "⚖️ Auto Weight")
            end
            if sessionStats.modes.mutation then
                table.insert(modes, "🧬 Auto Mutation")
            end
            if sessionStats.modes.advanced then
                table.insert(modes, "🚀 Advanced")
            end

            -- Normal leveling selalu menjadi tahap akhir script.
            table.insert(modes, "📈 Normal Leveling")

            return table.concat(modes, "\n")
        end

        -- Pet dianggap selesai jika seluruh target yang aktif pada saat sesi dimulai
        -- sudah tercapai. Ini menghindari satu pet terhitung berulang pada beberapa tahap.
        local function isSessionPetCompleted(petUUID)
            if not petUUID or not isPetValid(petUUID) then
                return false
            end

            if getPetLevel(petUUID) < targetLevel then
                return false
            end

            if sessionStats.modes.weight then
                if getPetWeight(petUUID) < getWeightTarget() then
                    return false
                end
            end

            if sessionStats.modes.mutation then
                local status = getMutationStatus(petUUID)
                if status ~= "desired" then
                    return false
                end
            end

            if sessionStats.modes.advanced then
                if getPetLevel(petUUID) < advancedTargetLevel then
                    return false
                end
            end

            return true
        end

        local function getSessionProcessedCount()
            local count = 0

            for _, petUUID in ipairs(allSelectedPets) do
                if isSessionPetCompleted(petUUID) then
                    count += 1
                end
            end

            return count
        end

        function startDiscordSession()
            sessionStats.active = true
            sessionStats.startedAt = os.time()
            sessionStats.totalPets = #allSelectedPets
            sessionStats.modes = {
                weight = isAutoWeight,
                mutation = isAutoMutation,
                advanced = isAdvancedLeveling,
                normal = true,
            }
            sessionStats.presets = {
                team = selectedTeamPreset,
                weight = selectedWeightPreset,
                mutation = selectedMutationPreset,
                advanced = selectedAdvancedPreset,
            }

            -- ⭐ RESET progress tracking
            sessionStats.progress = {
                weight = { done = {}, total = {} },
                mutation = { done = {}, total = {} },
                normal = { done = {}, total = {} },
                advanced = { done = {}, total = {} },
            }

            -- ⭐ ISI total pet per sesi
            if isAutoWeight then
                for _, uuid in ipairs(getPetsForWeight()) do
                    sessionStats.progress.weight.total[uuid] = true
                end
            end
            if isAutoMutation then
                for _, uuid in ipairs(getPetsForMutation()) do
                    sessionStats.progress.mutation.total[uuid] = true
                end
            end
            for _, uuid in ipairs(getPetsForNormalLeveling()) do
                sessionStats.progress.normal.total[uuid] = true
            end
            if isAdvancedLeveling then
                for _, uuid in ipairs(getPetsForAdvanced()) do
                    sessionStats.progress.advanced.total[uuid] = true
                end
            end
        end

        function finishDiscordSession(reason)
            sessionStats.active = false
        end

        -- ==================================================================
-- PROGRESS WEBHOOK
-- ==================================================================
local function countPetsByType(uuidSet)
    local groups = {}
    for uuid, _ in pairs(uuidSet) do
        if isPetValid(uuid) then
            local petType = getPetType(uuid)
            groups[petType] = (groups[petType] or 0) + 1
        end
    end
    local list = {}
    for name, count in pairs(groups) do
        table.insert(list, { name = name, count = count })
    end
    table.sort(list, function(a, b) return a.count > b.count end)
    return list
end

local function formatPetGroups(list)
    if #list == 0 then return "• (kosong)" end
    local parts = {}
    for _, item in ipairs(list) do
        table.insert(parts, string.format("• %s x%d", item.name, item.count))
    end
    return table.concat(parts, "\n")
end

local function countDonePets(doneSet)
    local count = 0
    for _ in pairs(doneSet) do count = count + 1 end
    return count
end

local function countTotalPets(totalSet)
    local count = 0
    for _ in pairs(totalSet) do count = count + 1 end
    return count
end

local function getPresetTextForWebhook()
    local function formatOnePreset(presetName)
        if not presetName then return "-" end
        local preset = getPreset(presetName)
        if not preset or not preset.pets then return "-" end
        local groups = {}
        for _, petInfo in ipairs(preset.pets) do
            local key = petInfo.PetType or "?"
            if petInfo.Mutation and petInfo.Mutation ~= "Normal" then
                key = petInfo.Mutation .. " " .. key
            end
            groups[key] = (groups[key] or 0) + 1
        end
        local list = {}
        for name, count in pairs(groups) do
            table.insert(list, string.format("%d %s", count, name))
        end
        return table.concat(list, ", ")
    end
    return {
        leveling = formatOnePreset(selectedTeamPreset),
        weight = formatOnePreset(selectedWeightPreset),
        mutation = formatOnePreset(selectedMutationPreset),
        advanced = formatOnePreset(selectedAdvancedPreset),
    }
end

local function formatDurationHMS(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

function sendProgressWebhook()
    print("[Webhook Debug] sendProgressWebhook dipanggil")
    print(string.format("[Webhook Debug] discordWebhookEnabled=%s | sessionStats.active=%s",
        tostring(config.discordWebhookEnabled),
        tostring(sessionStats.active)))

    if not config.discordWebhookEnabled then 
        print("[Webhook Debug] ❌ Webhook disabled")
        return 
    end
    if not sessionStats.active then 
        print("[Webhook Debug] ❌ Session not active")
        return 
    end

    local progress = sessionStats.progress
    local presets = getPresetTextForWebhook()
    local duration = math.max(0, os.time() - sessionStats.startedAt)

    local lines = {}
    table.insert(lines, "")
    table.insert(lines, string.format("**👤 Username:** `%s`", player.Name))
    table.insert(lines, "")

    -- ⭐ Auto Weight
    local wDone = countDonePets(progress.weight.done)
    local wTotal = countTotalPets(progress.weight.total)
    table.insert(lines, string.format("**🐘 Auto Weight %d/%d**", wDone, wTotal))
    table.insert(lines, formatPetGroups(countPetsByType(progress.weight.total)))
    table.insert(lines, "")

    -- ⭐ Auto Mutation
    local mDone = countDonePets(progress.mutation.done)
    local mTotal = countTotalPets(progress.mutation.total)
    table.insert(lines, string.format("**🧬 Auto Mutation %d/%d**", mDone, mTotal))
    table.insert(lines, formatPetGroups(countPetsByType(progress.mutation.total)))
    table.insert(lines, "")

    -- ⭐ Normal Leveling
    local nDone = countDonePets(progress.normal.done)
    local nTotal = countTotalPets(progress.normal.total)
    table.insert(lines, string.format("**📈 Normal Leveling %d/%d**", nDone, nTotal))
    table.insert(lines, formatPetGroups(countPetsByType(progress.normal.total)))
    table.insert(lines, "")

    -- ⭐ Advanced (kalau aktif)
    
    local aDone = countDonePets(progress.advanced.done)
    local aTotal = countTotalPets(progress.advanced.total)
    table.insert(lines, string.format("**🚀 Advanced %d/%d**", aDone, aTotal))
    table.insert(lines, formatPetGroups(countPetsByType(progress.advanced.total)))
    table.insert(lines, "")

    -- ⭐ Preset
    table.insert(lines, "**📋 Preset**")
    table.insert(lines, string.format("> Leveling: %s", presets.leveling))
    table.insert(lines, string.format("> Weight: %s", presets.weight))
    table.insert(lines, string.format("> Mutation: %s", presets.mutation))
    table.insert(lines, string.format("> Advanced: %s", presets.advanced))
    table.insert(lines, "")

    -- ⭐ Durasi
    table.insert(lines, "**⏱️ Durasi**")
    table.insert(lines, formatDurationHMS(duration))
    table.insert(lines, "")

    -- ⭐ Helper: mode dianggap selesai kalau:
--   - total = 0 (tidak ada pet) → dianggap selesai otomatis
--   - atau done == total dan total > 0
local function isModeDone(done, total, modeEnabled)
    -- Kalau mode tidak aktif → skip
    if not modeEnabled then return true end
    -- Kalau tidak ada pet di mode ini → dianggap selesai
    if total == 0 then return true end
    -- Normal: done harus sama dengan total
    return done >= total
end

local allDone = 
    isModeDone(wDone, wTotal, sessionStats.modes.weight) and
    isModeDone(mDone, mTotal, sessionStats.modes.mutation) and
    isModeDone(nDone, nTotal, sessionStats.modes.normal) and
    isModeDone(aDone, aTotal, sessionStats.modes.advanced)

    local status = allDone and "✅ Selesai" or "⏳ Proses"
    table.insert(lines, string.format("**Status:** %s", status))

    local description = table.concat(lines, "\n")

    task.spawn(function()
        sendDiscordWebhook({
            username = "AoneHub",
            embeds = {{
                title = "📊 AoneHub Progress",
                description = description,
                color = allDone and 5763719 or 16776960,
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }}
        })
    end)
end
        
        function buildWebhookEmbed()
            local eggName = "?"
            for name, _ in pairs(config.selectedEggs) do eggName = name break end
            local petCurrent, petMax = getPetCountFromData()

            local function formatPreset(presetName)
                if not presetName then return "-" end
                local preset = getPreset(presetName)
                if not preset or not preset.pets then return "-" end
                local groups = {}
                for _, petInfo in ipairs(preset.pets) do
                    local key = petInfo.PetType or "?"
                    if petInfo.Mutation and petInfo.Mutation ~= "Normal" then
                        key = petInfo.Mutation .. " " .. key
                    end
                    groups[key] = (groups[key] or 0) + 1
                end
                local list = {}
                for name, count in pairs(groups) do table.insert(list, {name = name, count = count}) end
                table.sort(list, function(a, b) return a.count > b.count end)
                local parts = {}
                for _, item in ipairs(list) do
                    table.insert(parts, string.format("%d %s", item.count, item.name))
                end
                return table.concat(parts, ", ")
            end

            local function formatHuntBucket(bucket)
                local count = 0
                local lines = {}
                for petName, entry in pairs(bucket) do
                    count = count + entry.count
                    local weightStr
                    if math.abs(entry.minWeight - entry.maxWeight) < 0.01 then
                        weightStr = string.format("%.2f kg", entry.minWeight)
                    else
                        weightStr = string.format("%.2f-%.2f kg", entry.minWeight, entry.maxWeight)
                    end
                    table.insert(lines, string.format("• %s x%d (%s)", petName, entry.count, weightStr))
                end
                return count, table.concat(lines, "\n")
            end

            local specialCount, specialList = formatHuntBucket(STATS.huntStats.Special)
            local hugeCount, hugeList = formatHuntBucket(STATS.huntStats.Huge)
            local titanCount, titanList = formatHuntBucket(STATS.huntStats.Titan)
            local godlyCount, godlyList = formatHuntBucket(STATS.huntStats.Godly)

            local eggBefore = STATS.eggBeforePlace or 0
            local eggCurrent = STATS.eggAfterSell or 0
            local netResult = eggCurrent - eggBefore
            local netStr = netResult >= 0 and ("+" .. netResult) or tostring(netResult)

            local totalDuration = os.time() - STATS.sessionStart
            local hours = math.floor(totalDuration / 3600)
            local minutes = math.floor((totalDuration % 3600) / 60)
            local seconds = totalDuration % 60
            local durationStr = string.format("%dh %dm %ds", hours, minutes, seconds)

            local desc = {}
            table.insert(desc, "**Profile :**")
            table.insert(desc, string.format("> 👤 Username : ||%s||", player.Name))
            table.insert(desc, string.format("> 🥚 Egg Name: ``%s``", eggName))
            table.insert(desc, string.format("> 🐾 Pet on backpack: ``%d/%d``", petCurrent, petMax))
            table.insert(desc, "")
            table.insert(desc, "**Teams :**")
            table.insert(desc, "> Core: " .. formatPreset(config.speedPreset))
            table.insert(desc, "> Hatch: " .. formatPreset(config.hatchPreset))
            table.insert(desc, "> Sell: " .. formatPreset(config.sellPreset))
            table.insert(desc, "")
            table.insert(desc, "**Hunt Statistics :**")
            table.insert(desc, string.format("> ⭐ Special: %d", specialCount))
            if specialList ~= "" then table.insert(desc, specialList) end
            table.insert(desc, string.format("> 🥉 Huge: %d", hugeCount))
            if hugeList ~= "" then table.insert(desc, hugeList) end
            table.insert(desc, string.format("> 🥈 Titan: %d", titanCount))
            if titanList ~= "" then table.insert(desc, titanList) end
            table.insert(desc, string.format("> 🥇 Godly: %d", godlyCount))
            if godlyList ~= "" then table.insert(desc, godlyList) end
            table.insert(desc, "")
            table.insert(desc, "**Egg Statistics :**")
            table.insert(desc, string.format("> 📦 Egg Before: ``%d``", eggBefore))
            table.insert(desc, string.format("> 📊 Current Amount: ``%d``", eggCurrent))
            table.insert(desc, string.format("> 📈 Net Result: ``%s``", netStr))
            table.insert(desc, "")
            table.insert(desc, "**Hatch Statistics :**")
            table.insert(desc, string.format("> 🔄 Hatch Cycles: ``%d``", STATS.totalHatchCycles))
            table.insert(desc, string.format("> 🐣 Total Hatched: ``%d``", STATS.totalHatched))
            table.insert(desc, string.format("> ⏱️ Cycle Duration: ``%ds``", STATS.lastCycleDuration))
            table.insert(desc, string.format("> ⏳ All Time Duration: ``%s``", durationStr))

            return {
                title = "🥚 Auto Hatch Report",
                description = table.concat(desc, "\n"),
                color = 3447003,
                footer = { text = "AoneHub" .. os.date("%Y-%m-%d %H:%M:%S") }
            }
        end
    end -- BLOCK 4
    
    do -- BLOCK 5: LOADOUT, FAVORIT, GIFT, MONITOR, AUTO HATCH LOOP
        -- ==================================================================
        -- HELPER: LOADOUT SWAP
        -- ==================================================================
        lastLoadoutSlot = nil

        local function swapLoadout(slotNumber)
            if not slotNumber then return false end
            pcall(function()
                PetsServiceRE:FireServer("SwapPetLoadout", slotNumber)
            end)
            task.wait(config.delayAfterLoadout)
            return true
        end

        local function verifyEquippedMatchesPreset(presetName)
            if not presetName then return true, {}, {} end
            local expectedUUIDs = getPresetUUIDs(presetName)
            local equippedUUIDs = getEquippedPets()
            local equippedSet = {}
            for _, uuid in ipairs(equippedUUIDs) do equippedSet[uuid] = true end
            local presetSet = {}
            for _, uuid in ipairs(expectedUUIDs) do presetSet[uuid] = true end
            local toUnequip = {}
            for _, uuid in ipairs(equippedUUIDs) do
                if not presetSet[uuid] then table.insert(toUnequip, uuid) end
            end
            local toEquip = {}
            for _, uuid in ipairs(expectedUUIDs) do
                if not equippedSet[uuid] then table.insert(toEquip, uuid) end
            end
            return (#toUnequip == 0 and #toEquip == 0), toUnequip, toEquip
        end

        local function fixEquippedToMatchPreset(presetName)
            local isMatch, toUnequip, toEquip = verifyEquippedMatchesPreset(presetName)
            if isMatch then return true end
            for _, uuid in ipairs(toUnequip) do
                pcall(function() PetsService:UnequipPet(uuid) end)
                task.wait(config.equipDelay)
            end
            for _, uuid in ipairs(toEquip) do
                if isPetUUIDValid(uuid) then
                    pcall(function() PetsService:EquipPet(uuid, CFrame.new(0, 10, 0)) end)
                    task.wait(config.equipDelay)
                end
            end
            task.wait(config.syncWaitTime)
            return verifyEquippedMatchesPreset(presetName)
        end

        local function equipTeamByPreset(presetName, loadoutSlot, forceRefresh)
            if not presetName then return false end
            if not loadoutSlot then return false end
            if not forceRefresh and lastLoadoutSlot == loadoutSlot then
                local isMatch = verifyEquippedMatchesPreset(presetName)
                if isMatch then return true end
            end
            swapLoadout(loadoutSlot)
            lastLoadoutSlot = loadoutSlot
            local isMatch = verifyEquippedMatchesPreset(presetName)
            if isMatch then return true end
            fixEquippedToMatchPreset(presetName)
            return true
        end

        -- ==================================================================
        -- HELPER: FAVORIT
        -- ==================================================================
        local function ensureFavorit(tool, shouldBeFavorite, timeout)
            timeout = timeout or 2
            local current = tool:GetAttribute("d") == true
            if current == shouldBeFavorite then return true end
            pcall(function() FavoriteItemRE:FireServer(tool) end)
            local startTime = os.clock()
            while os.clock() - startTime < timeout do
                if (tool:GetAttribute("d") == true) == shouldBeFavorite then return true end
                task.wait(0.1)
            end
            return false
        end

        -- ==================================================================
        -- HELPER: UNWANTED
        -- ==================================================================
        local function isUnwantedPet(pet)
            local baseName, mutation = splitPetName(pet.name)
            if not config.unwantedPetTypes[baseName] then return false end
            if pet.weight > config.maxWeight then return false end
            if pet.level > config.maxLevel then return false end
            return true
        end

        local function sellAll()
            pcall(function() SellAllRE:FireServer() end)
            task.wait(3)
        end

        -- ==================================================================
        -- AUTO ACCEPT GIFT
        -- ==================================================================
        GIFT_STATS = {
            totalAccepted = 0,
            totalFailed = 0,
            history = {},
        }

        giftQueue = {}
        local isProcessingGiftQueue = false

        local function hideGiftUI()
            if not config.giftHideUI then return end
            local giftGui = playerGui:FindFirstChild("Gift_Notification")
            if not giftGui then return end
            local frame = giftGui:FindFirstChild("Frame")
            if not frame then return end
            for _, obj in ipairs(frame:GetDescendants()) do
                if obj.Name == "Gift_Notification" and obj:IsA("GuiObject") then
                    obj.Visible = false
                end
            end
        end

        -- ==================================================================
        -- AUTO GIFT PET
        -- ==================================================================
        local function autoGiftOnePet(petName, targetUsername)
            local target = findPlayerByName(targetUsername)
            if not target then return false end

            local petTool = findPetToolByName(petName)
            if not petTool then return false end

            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if not humanoid then return false end

            -- Equip
            pcall(function() humanoid:EquipTool(petTool) end)

            -- ⭐ Delay setelah equip sebelum cek favorit
            task.wait(config.giftPetDelayEquip)

            -- Cek & unfavorit
            if petTool:GetAttribute("d") == true then
                pcall(function() FavoriteItemRE:FireServer(petTool) end)
                task.wait(config.giftPetDelayUnfavorit)
            end

            -- Fire gift
            print(string.format("[Gift Pet] Kirim %s → %s", petName, targetUsername))
            local ok = pcall(function()
                PetGiftingService:FireServer("GivePet", target)
            end)

            task.wait(config.giftPetDelayBetween)
            return ok
        end

        function autoGiftAllFiltered()
            if not config.giftPetTarget then return end
            local target = findPlayerByName(config.giftPetTarget)
            if not target then return end

            isAutoGiftActive = true

            local pets = getBackpackPets()
            local toGift = {}

            for _, pet in ipairs(pets) do
                local skip = false
                if pet.weight < config.giftPetMinWeight then skip = true end
                if pet.weight > config.giftPetMaxWeight then skip = true end
                if pet.level < config.giftPetMinLevel then skip = true end
                if pet.level > config.giftPetMaxLevel then skip = true end

                if not skip and next(config.giftPetSelectedTypes) ~= nil then
                    local baseName = splitPetName(pet.name)
                    if not config.giftPetSelectedTypes[baseName] and not config.giftPetSelectedTypes[pet.name] then
                        skip = true
                    end
                end

                if not skip then table.insert(toGift, pet) end
            end

            print(string.format("[Gift Pet] %d pet lolos filter", #toGift))

            if #toGift == 0 then
                isAutoGiftActive = false
                return
            end

            for i, pet in ipairs(toGift) do
                -- [PATCH 4B] Guard isGuiDestroyed
                if not isGiftPetRunning or isGuiDestroyed then break end
                print(string.format("[Gift Pet] [%d/%d] %s", i, #toGift, pet.name))
                autoGiftOnePet(pet.name, config.giftPetTarget)
            end

            isAutoGiftActive = false
        end

        -- ==================================================================
        -- PET SHARING: GIFT PET
        -- ==================================================================
        local function findPetToolByUUID(petUUID)
    local petType = getPetType(petUUID)
    if not petType or petType == "Unknown" then 
        warn("[findPetToolByUUID] petType Unknown untuk UUID:", petUUID)
        return nil 
    end

    local mutation = getPetMutationName(petUUID)
    local expectedFull = mutation and (mutation .. " " .. petType) or petType

    print(string.format("[findPetToolByUUID] Cari: UUID=%s | PetType=%s | Expected=%s",
        petUUID:sub(1, 8), petType, expectedFull))

    -- ⭐ Retry 6x @ 0.5s = 3 detik (tunggu sync server)
    for attempt = 1, 6 do
        local locations = {}
        local backpack = player:FindFirstChild("Backpack")
        if backpack then table.insert(locations, backpack) end
        if player.Character then table.insert(locations, player.Character) end

        -- ⭐ PRIORITAS 1: Match PetType (paling reliable, karena PetType sudah include mutation)
        for _, container in ipairs(locations) do
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("ItemType") == "Pet" then
                    local name = parsePetName(tool.Name)
                    if name == petType then 
                        print(string.format("[findPetToolByUUID] ✅ Match PetType: %s (attempt %d)", name, attempt))
                        return tool 
                    end
                end
            end
        end

        -- ⭐ PRIORITAS 2: Match Expected (nama lengkap dengan mutation)
        if expectedFull ~= petType then
            for _, container in ipairs(locations) do
                for _, tool in ipairs(container:GetChildren()) do
                    if tool:IsA("Tool") and tool:GetAttribute("ItemType") == "Pet" then
                        local name = parsePetName(tool.Name)
                        if name == expectedFull then 
                            print(string.format("[findPetToolByUUID] ✅ Match Expected: %s (attempt %d)", name, attempt))
                            return tool 
                        end
                    end
                end
            end
        end

        if attempt < 6 then
            task.wait(0.5)
        end
    end

    print("[findPetToolByUUID] ❌ TIDAK DITEMUKAN setelah 6x retry")
    return nil
        end
        
        function giftSharingPet(sharingType)
    local enabled, selectedPet, selectedUUID, savedInfo

    if sharingType == "mutation" then
        enabled = config.petSharingMutationEnabled
        selectedPet = config.petSharingMutationPet
        selectedUUID = config.petSharingMutationPetUUID
        savedInfo = config.petSharingMutationSavedInfo
    elseif sharingType == "weight" then
        enabled = config.petSharingWeightEnabled
        selectedPet = config.petSharingWeightPet
        selectedUUID = config.petSharingWeightPetUUID
        savedInfo = config.petSharingWeightSavedInfo
    else
        enabled = false
    end

    if not enabled then return false end
    if not selectedPet and not selectedUUID then
        warn("[Pet Sharing] Tidak ada pet yang dipilih untuk", sharingType)
        return false
    end
    if not config.petSharingTargetUsername then
        warn("[Pet Sharing] Tidak ada target username")
        return false
    end

    local target = findPlayerByName(config.petSharingTargetUsername)
    if not target then
        warn("[Pet Sharing] Target tidak ditemukan:", config.petSharingTargetUsername)
        return false
    end

    print(string.format("[Pet Sharing:%s] === START GIFT ===", sharingType))
    print(string.format("[Pet Sharing:%s] selectedPet=%s | selectedUUID=%s",
        sharingType, tostring(selectedPet), tostring(selectedUUID)))

    -- ⭐ STEP 1: UNEQUIP DULU (pindah ke atas!)
    if selectedUUID then
        local equippedUUIDs = getEquippedPets()
        local isEquipped = table.find(equippedUUIDs, selectedUUID) ~= nil

        if isEquipped then
            print(string.format("[Pet Sharing:%s] Unequip %s (masih di-equipped)", sharingType, tostring(selectedPet)))
            pcall(function() PetsService:UnequipPet(selectedUUID) end)

            -- ⭐ Tunggu sampai tool benar-benar muncul di backpack (max 15s)
            local timeout = 15
            local waited = 0
            local toolFound = false

            while waited < timeout do
                task.wait(0.5)
                waited = waited + 0.5

                -- Cek apakah tool sudah ada di backpack/character
                if findPetToolByUUID(selectedUUID) then
                    toolFound = true
                    print(string.format("[Pet Sharing:%s] ✅ Tool muncul di backpack dalam %.1fs", sharingType, waited))
                    break
                end

                if waited % 3 == 0 then
                    print(string.format("[Pet Sharing:%s] ⏳ Menunggu tool di backpack... (%.1fs)", sharingType, waited))
                end
            end

            if not toolFound then
                warn(string.format("[Pet Sharing:%s] ❌ Tool tidak muncul setelah %.1fs", sharingType, timeout))
            end
        else
            print(string.format("[Pet Sharing:%s] %s tidak ter-equip, skip unequip", sharingType, tostring(selectedPet)))
        end
    end

    -- ⭐ STEP 2: BARU CARI TOOL
    local petTool = nil
    if selectedUUID then
        petTool = findPetToolByUUID(selectedUUID)
    end
    if not petTool and selectedPet then
        petTool = findPetToolByName(selectedPet)
    end

    if not petTool then
        warn("[Pet Sharing] Pet tidak ada di backpack:", tostring(selectedPet), "| UUID:", tostring(selectedUUID))
        -- ⭐ Debug: list semua pet di backpack
        print("[Pet Sharing] Daftar pet di backpack:")
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            for _, tool in ipairs(backpack:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("ItemType") == "Pet" then
                    print("  -", tool.Name)
                end
            end
        end
        return false
    end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end

    local petName = selectedPet or petTool.Name
    print(string.format("[Pet Sharing:%s] Proses gift %s → %s", sharingType, petName, config.petSharingTargetUsername))

    -- STEP 3: Unfavorit (kalau favorit)
    if petTool:GetAttribute("d") == true then
        print(string.format("[Pet Sharing:%s] Unfavorit %s", sharingType, petName))
        pcall(function() FavoriteItemRE:FireServer(petTool) end)
        task.wait(0.5)
    end

    -- STEP 4: Equip ke tangan
    print(string.format("[Pet Sharing:%s] Equip %s ke tangan", sharingType, petName))
    pcall(function() humanoid:EquipTool(petTool) end)
    task.wait(1)

    -- STEP 5: Fire gift
    print(string.format("[Pet Sharing:%s] Kirim %s → %s", sharingType, petName, config.petSharingTargetUsername))
    local ok = pcall(function()
        PetGiftingService:FireServer("GivePet", target)
    end)

    task.wait(2)

    if ok then
        print("[Pet Sharing:" .. sharingType .. "] ✅ Gift berhasil")
    else
        warn("[Pet Sharing:" .. sharingType .. "] ❌ Gift gagal")
    end

    return ok
end

        -- ==================================================================
        -- PET SHARING: CEK GIFT MASUK
        -- ==================================================================
            local function checkPetSharingReceived(sharingType)
local selectedPet, selectedUUID, savedInfo
if sharingType == "mutation" then
    selectedPet = config.petSharingMutationPet
    selectedUUID = config.petSharingMutationPetUUID
    savedInfo = config.petSharingMutationSavedInfo
elseif sharingType == "weight" then
    selectedPet = config.petSharingWeightPet
    selectedUUID = config.petSharingWeightPetUUID
    savedInfo = config.petSharingWeightSavedInfo
else
    selectedPet = config.petSharingSelectedPet
    savedInfo = config.petSharingSavedPetInfo
end

if not selectedUUID and not selectedPet then return false end

local petsData = getPlayerPetData()
if not petsData then return false end

local inventory = petsData.PetInventory.Data or {}

-- ⭐ Cari by UUID dulu, fallback ke nama
local foundUUID = nil
if selectedUUID and inventory[selectedUUID] then
    foundUUID = selectedUUID
elseif selectedPet then
    for uuid, _ in pairs(inventory) do
        if getPetType(uuid) == selectedPet then
            foundUUID = uuid
            break
        end
    end
end

if not foundUUID then return false end

local targetPetName = getPetType(foundUUID)

print(string.format("[Pet Sharing:%s] 🎁 Terima %s (UUID: %s)",
    sharingType, targetPetName, foundUUID:sub(1, 8)))

-- ⭐ Cari tool by UUID, fallback by nama
local petTool = findPetToolByUUID(foundUUID)
if not petTool then
    petTool = findPetToolByName(targetPetName)
end

if not petTool then
    warn(string.format("[Pet Sharing:%s] Tool tidak ditemukan untuk %s", sharingType, targetPetName))
    return false
end

-- STEP 1: Auto favorit
if petTool:GetAttribute("d") ~= true then
    print(string.format("[Pet Sharing:%s] Favorit %s", sharingType, targetPetName))
    pcall(function() FavoriteItemRE:FireServer(petTool) end)
    task.wait(0.5)
end

-- STEP 2: Cek apakah termasuk tim preset
local currentPreset = nil
if isAutoWeight and selectedWeightPreset then
    currentPreset = selectedWeightPreset
elseif isAutoMutation and selectedMutationPreset then
    currentPreset = selectedMutationPreset
elseif isAdvancedLeveling and selectedAdvancedPreset then
    currentPreset = selectedAdvancedPreset
elseif isLeveling and selectedTeamPreset then
    currentPreset = selectedTeamPreset
end

if not currentPreset then
    return true
end

local preset = getPreset(currentPreset)
if not preset or not preset.pets then
    return true
end

-- Cek apakah pet ini ada di preset
local isInPreset = false
for _, petInfo in ipairs(preset.pets) do
    if petInfo.UUID == foundUUID then
        isInPreset = true
        break
    end
end

if not isInPreset then
    return true
end

-- ============================================================
-- STEP 3: CEK SLOT SEBELUM EQUIP (DENGAN PRIORITAS)
-- ============================================================
local equippedPets = getEquippedPets()

if #equippedPets >= MAX_PET_SLOTS then
    print(string.format("[Pet Sharing:%s] ⚠️ Slot penuh (%d/%d), cari pet untuk di-unequip...",
        sharingType, #equippedPets, MAX_PET_SLOTS))

    -- ⭐ Ambil UUID tim preset
    local currentPreset = nil
    if isAutoWeight and selectedWeightPreset then
        currentPreset = selectedWeightPreset
    elseif isAutoMutation and selectedMutationPreset then
        currentPreset = selectedMutationPreset
    elseif isAdvancedLeveling and selectedAdvancedPreset then
        currentPreset = selectedAdvancedPreset
    elseif isLeveling and selectedTeamPreset then
        currentPreset = selectedTeamPreset
    end

    local presetUUIDs = currentPreset and getPresetUUIDs(currentPreset) or {}
    local presetSet = {}
    for _, uuid in ipairs(presetUUIDs) do presetSet[uuid] = true end

    local targetSet = {}
    for _, uuid in ipairs(allSelectedPets) do targetSet[uuid] = true end

    -- ⭐ PRIORITAS 1: Pet yang BUKAN preset DAN BUKAN target
    -- ⭐ PRIORITAS 2: Pet yang BUKAN preset (tapi target)
    local priority1, priority2 = nil, nil

    for _, uuid in ipairs(equippedPets) do
        local isInPreset = presetSet[uuid] == true
        local isInTarget = targetSet[uuid] == true

        if not isInPreset and not isInTarget then
            priority1 = priority1 or uuid
        elseif not isInPreset and isInTarget then
            priority2 = priority2 or uuid
        end
    end

    local unequipTarget = priority1 or priority2

    if unequipTarget then
        local reason = ""
        if unequipTarget == priority1 then reason = "bukan preset & bukan target"
        else reason = "bukan preset (tapi target)" end

        print(string.format("[Pet Sharing:%s] 🔄 Unequip %s [%s] — alasan: %s",
            sharingType, getPetType(unequipTarget), unequipTarget:sub(1, 8), reason))

        pcall(function()
            PetsService:UnequipPet(unequipTarget)
        end)
        task.wait(1)  -- ⭐ tunggu slot benar-benar kosong
    else
        print(string.format("[Pet Sharing:%s] ❌ Semua slot terisi tim preset, skip gift",
            sharingType))
        return false
    end
            end

-- ============================================================
-- STEP 4: EQUIP PET BARU
-- ============================================================
print(string.format("[Pet Sharing:%s] Equip %s (bagian tim %s)",
    sharingType, targetPetName, currentPreset))

pcall(function()
    PetsService:EquipPet(foundUUID, CFrame.new(0, 10, 0))
end)
task.wait(0.5)

local equippedAfter = getEquippedPets()
if table.find(equippedAfter, foundUUID) then
    print(string.format("[Pet Sharing:%s] ✅ %s berhasil di-equip", sharingType, targetPetName))
else
    print(string.format("[Pet Sharing:%s] ⚠️ %s gagal di-equip", sharingType, targetPetName))
end

return true
    end

        local function processGiftQueue()
            if isProcessingGiftQueue then return end
            if #giftQueue == 0 then return end  -- ⭐ skip kalau kosong

            isProcessingGiftQueue = true
            isAutoAcceptActive = true

            task.spawn(function()
                -- [PATCH 4A] Guard isGuiDestroyed + config check
                while #giftQueue > 0 and not isGuiDestroyed do
                    if not config.giftEnabled then break end
                    local gift = table.remove(giftQueue, 1)
                    print(string.format("[Gift] Process: %s | %s", gift.id, gift.pet))

                    task.wait(config.giftDelayAfter)

                    local ok = pcall(function()
                        AcceptPetGift:FireServer(true, gift.id)
                    end)

                    if ok then
                        GIFT_STATS.totalAccepted = GIFT_STATS.totalAccepted + 1
                    else
                        GIFT_STATS.totalFailed = GIFT_STATS.totalFailed + 1
                    end

                    task.wait(0.5)
                    hideGiftUI()
                    task.wait(0.3)
                    hideGiftUI()

                    if #giftQueue > 0 then
                        task.wait(config.giftDelayBetween)
                    end
                end
                task.wait(0.5)
                hideGiftUI()
                isProcessingGiftQueue = false
                isAutoAcceptActive = false

                -- ⭐ SETELAH SEMUA GIFT ACCEPTED: Cek pet sharing 3x @ 10s
                if isLeveling and not isCheckingPetSharing then
                    local anySharing = config.petSharingWeightPet or config.petSharingMutationPet
                    if anySharing then
                        isCheckingPetSharing = true

                        task.spawn(function()
                            print("[Pet Sharing] Semua gift di-accept, mulai cek 3x @ 10s...")

                            for i = 1, 3 do
                                task.wait(10)

                                if not isLeveling or isGuiDestroyed then
                                    print("[Pet Sharing] Sesi berakhir, stop cek")
                                    isCheckingPetSharing = false
                                    return
                                end

                                print(string.format("[Pet Sharing] Cek #%d...", i))

                                -- Cek weight sharing
                                if config.petSharingWeightEnabled and config.petSharingWeightPet then
                                    local received = checkPetSharingReceived("weight")
                                    if received then
                                        print("[Pet Sharing] ✅ Pet weight diterima")
                                    end
                                end

                                -- Cek mutation sharing
                                if config.petSharingMutationEnabled and config.petSharingMutationPet then
                                    local received = checkPetSharingReceived("mutation")
                                    if received then
                                        print("[Pet Sharing] ✅ Pet mutation diterima")
                                    end
                                end
                            end

                            print("[Pet Sharing] 3x cek selesai")
                            isCheckingPetSharing = false
                        end)
                    end
                end
            end)
        end

        GiftPetEvent.OnClientEvent:Connect(function(giftId, petName, weightInfo)
            if not config.giftEnabled then return end
            if not giftId or typeof(giftId) ~= "string" then return end

            -- ⭐ SELALU tambahkan ke queue
            table.insert(giftQueue, { 
                id = giftId, 
                pet = petName, 
                weight = weightInfo, 
                time = os.time() 
            })
            table.insert(GIFT_STATS.history, { 
                id = giftId, 
                pet = petName, 
                weight = weightInfo, 
                time = os.time() 
            })

            print(string.format("[Gift] 📥 Queued: %s | %s (queue: %d)", 
                giftId, tostring(petName), #giftQueue))

            -- ⭐ HANYA process kalau SEDANG TUNGGU EGG TIMER
            if isRunning and not isWaitingEggTimer then
                print("[Gift] Skip process — tunggu fase tunggu egg timer")
                return
            end

            -- Process queue (hanya kalau tunggu timer atau auto hatch OFF)
            processGiftQueue()
        end)
        
        -- ==================================================================
        -- MONITOR TAB
        -- ==================================================================
        monitorLabels = {}

        function refreshMonitor()
            if not monitorLabels.profileLabel then return end

            -- Profile
            local eggName = "?"
            for name, _ in pairs(config.selectedEggs) do eggName = name break end
            local petCurrent, petMax = getPetCountFromData()

            monitorLabels.profileLabel.Text = string.format(
                "Profile :\n" ..
                "👤 Username: %s\n" ..
                "🥚 Egg Name: %s\n" ..
                "🐾 Pet on backpack: %d/%d",
                player.Name, eggName, petCurrent, petMax
            )

            -- Teams
            local function formatPreset(presetName)
                if not presetName then return "-" end
                local preset = getPreset(presetName)
                if not preset or not preset.pets then return "-" end
                local groups = {}
                for _, petInfo in ipairs(preset.pets) do
                    local key = petInfo.PetType or "?"
                    if petInfo.Mutation and petInfo.Mutation ~= "Normal" then
                        key = petInfo.Mutation .. " " .. key
                    end
                    groups[key] = (groups[key] or 0) + 1
                end
                local list = {}
                for name, count in pairs(groups) do
                    table.insert(list, {name = name, count = count})
                end
                table.sort(list, function(a, b) return a.count > b.count end)
                local parts = {}
                for _, item in ipairs(list) do
                    table.insert(parts, string.format("%d %s", item.count, item.name))
                end
                return table.concat(parts, ", ")
            end

            monitorLabels.teamsLabel.Text = string.format(
                "Teams :\n" ..
                "> Core: %s\n" ..
                "> Hatch: %s\n" ..
                "> Sell: %s",
                formatPreset(config.speedPreset),
                formatPreset(config.hatchPreset),
                formatPreset(config.sellPreset)
            )

            -- Hunt Statistics
            local function formatHuntBucket(bucket, emoji, label)
                local count = 0
                local lines = {}
                for petName, entry in pairs(bucket) do
                    count = count + entry.count
                    local weightStr
                    if math.abs(entry.minWeight - entry.maxWeight) < 0.01 then
                        weightStr = string.format("%.2f kg", entry.minWeight)
                    else
                        weightStr = string.format("%.2f-%.2f kg", entry.minWeight, entry.maxWeight)
                    end
                    table.insert(lines, string.format("  • %s x%d (%s)", petName, entry.count, weightStr))
                end
                table.sort(lines)
                local result = string.format("%s %s: %d", emoji, label, count)
                if #lines > 0 then
                    result = result .. "\n" .. table.concat(lines, "\n")
                end
                return result
            end

            monitorLabels.huntLabel.Text = "Hunt Statistics :\n" ..
                formatHuntBucket(STATS.huntStats.Special, "⭐", "Special") .. "\n" ..
                formatHuntBucket(STATS.huntStats.Huge, "🥉", "Huge") .. "\n" ..
                formatHuntBucket(STATS.huntStats.Titan, "🥈", "Titan") .. "\n" ..
                formatHuntBucket(STATS.huntStats.Godly, "🥇", "Godly")

            -- Egg Statistics
            local eggBefore = STATS.eggBeforePlace or 0
            local eggCurrent = STATS.eggAfterSell or 0
            local netResult = eggCurrent - eggBefore
            local netStr = netResult >= 0 and ("+" .. netResult) or tostring(netResult)

            monitorLabels.eggLabel.Text = string.format(
                "Egg Statistics :\n" ..
                "> 📦 Egg Before: %d\n" ..
                "> 📊 Current Amount: %d\n" ..
                "> 📈 Net Result: %s",
                eggBefore, eggCurrent, netStr
            )

            -- Hatch Statistics
            local totalDuration = os.time() - STATS.sessionStart
            local hours = math.floor(totalDuration / 3600)
            local minutes = math.floor((totalDuration % 3600) / 60)
            local seconds = totalDuration % 60
            local durationStr = string.format("%dh %dm %ds", hours, minutes, seconds)

            monitorLabels.hatchLabel.Text = string.format(
                "Hatch Statistics :\n" ..
                "> 🔄 Hatch Cycles: %d\n" ..
                "> 🐣 Total Hatched: %d\n" ..
                "> ⏱️ Cycle Duration: %ds\n" ..
                "> ⏳ All Time Duration: %s",
                STATS.totalHatchCycles, STATS.totalHatched,
                STATS.lastCycleDuration, durationStr
            )

            -- Updated timestamp
            monitorLabels.timestamp.Text = "🕐 Updated: " .. os.date("%H:%M:%S")
        end

        -- ==================================================================
        -- STATUS
        -- ==================================================================
        local function updatesStatus(text)
            if statusCallback and not isGuiDestroyed then statusCallback(text) end
            print("[AutoHatch]", text)
        end

        -- ==================================================================
        -- FASE 1: PLACE EGG
        -- ==================================================================
        local function placeEggsFromBackpack()
            local totalSlots = #config.eggGridOffsets
            task.wait(config.scanSettleDelay)
            local emptySlots, occupied = getEmptySlots()
            if #emptySlots == 0 then
                updatesStatus("⚠️ Garden penuh")
                return 0
            end
            updatesStatus(string.format("📦 %d slot kosong", #emptySlots))
            local eggTool = findEggTool()
            if not eggTool then
                updatesStatus("⚠️ Tidak ada egg")
                return 0
            end
            local backpack = player:FindFirstChild("Backpack")
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if eggTool.Parent == backpack and humanoid then
                pcall(function() humanoid:EquipTool(eggTool) end)
                task.wait(0.5)
            end
            local center = getCenterPoint()
            if not center then return 0 end
            local placed = 0
            for _, slotIndex in ipairs(emptySlots) do
                if not isRunning then break end
                local currentEggTool = findEggTool()
                if not currentEggTool then break end
                if currentEggTool.Parent == backpack and humanoid then
                    pcall(function() humanoid:EquipTool(currentEggTool) end)
                    task.wait(0.5)
                end
                local pos = center.Position + config.eggGridOffsets[slotIndex]
                local ok = pcall(function()
                    PetEggService:FireServer("CreateEgg", pos)
                end)
                if ok then
                    placed = placed + 1
                    updatesStatus(string.format("📦 Place %d/%d", placed, #emptySlots))
                    task.wait(config.placeDelay)
                end
            end
            if humanoid then
                pcall(function() humanoid:UnequipTools() end)
                task.wait(0.5)
            end
            return placed
        end

        -- ==================================================================
        -- FASE 2: CYCLE
        -- ==================================================================
        local function runOneCycle(cycleNum, totalCycles)
            if cycleNum == 1 then STATS.cycleStartTime = os.time() end
            updatesStatus(string.format("[%d/%d] 📦 Place egg...", cycleNum, totalCycles))
            local placed = placeEggsFromBackpack()
            
            STATS.eggAfterSell = countEggsInBackpack()
            refreshMonitor()
            
            if config.discordWebhookEnabled then
                local embed = buildWebhookEmbed()
                task.spawn(function()
                    sendDiscordWebhook({
                        username = "AoneHub",
                        embeds = { embed }
                    })
                end)
            end
            local existingEggs = getMyGardenEggs()
            local allReady = false
            if placed == 0 then
                if #existingEggs == 0 then return false end
                allReady = true
                for _, egg in ipairs(existingEggs) do
                    if (egg:GetAttribute("TimeToHatch") or 999) > 0 then allReady = false break end
                end
            end
            task.wait(2)

            -- ⭐ FASE TUNGGU TIMER dengan Auto Gift & Auto Accept
            if not allReady then
                updatesStatus(string.format("[%d/%d] ⚡ Tim Speed...", cycleNum, totalCycles))
                equipTeamByPreset(config.speedPreset, config.speedLoadout)
                task.wait(config.delayAfterSpeed)

                updatesStatus(string.format("[%d/%d] ⏳ Menunggu ready...", cycleNum, totalCycles))

                -- ⭐ SET STATE: Tunggu egg timer
                isWaitingEggTimer = true

                -- ⭐ Process gift queue yang menumpuk
                if #giftQueue > 0 then
                    print(string.format("[AutoHatch] Process %d gift dari queue...", #giftQueue))
                    processGiftQueue()
                end

                -- ⭐ Auto-start auto gift
                if giftPetUserStarted and not isGiftPetRunning and config.giftPetTarget then
                    local hasPetsToGift = false
                    for _, pet in ipairs(getBackpackPets()) do
                        if pet.weight >= config.giftPetMinWeight 
                           and pet.weight <= config.giftPetMaxWeight
                           and pet.level >= config.giftPetMinLevel
                           and pet.level <= config.giftPetMaxLevel then
                            hasPetsToGift = true
                            break
                        end
                    end
                    if hasPetsToGift then
                        print("[AutoHatch] Auto-start Auto Gift...")
                        isGiftPetRunning = true
                        task.spawn(function()
                            autoGiftAllFiltered()
                            if isGiftPetRunning then
                                isGiftPetRunning = false
                            end
                        end)
                    end
                end

                local waitStart = os.clock()
                while (os.clock() - waitStart) < 900 and isRunning do
                    local eggs = getMyGardenEggs()
                    if #eggs == 0 then break end
                    local readyAll = true
                    for _, egg in ipairs(eggs) do
                        if (egg:GetAttribute("TimeToHatch") or 0) > 0 then readyAll = false break end
                    end
                    if readyAll then break end
                    task.wait(3)
                end

                -- ⭐ TUNGGU AUTO GIFT & AUTO ACCEPT SELESAI
                updatesStatus(string.format("[%d/%d] ⏳ Menunggu gift/accept selesai...", cycleNum, totalCycles))
                local hasActiveProcess = false
                while (isAutoGiftActive or isAutoAcceptActive or isGiftPetRunning) and isRunning do
                    hasActiveProcess = true
                    task.wait(1)
                end

                -- ⭐ Kalau ADA proses yang aktif → delay
                if hasActiveProcess then
                    updatesStatus(string.format("[%d/%d] ⏳ Delay %ss...", 
                        cycleNum, totalCycles, config.delayAfterGiftSync))
                    task.wait(config.delayAfterGiftSync)
                end

                -- ⭐ CLEAR STATE
                isWaitingEggTimer = false

                if not isRunning then return false end
                task.wait(1)
            end

            updatesStatus(string.format("[%d/%d] 🥚 Tim Hatch...", cycleNum, totalCycles))
            equipTeamByPreset(config.hatchPreset, config.hatchLoadout)
            task.wait(config.delayAfterHatch)
            local eggsToHatch = {}
            for _, egg in ipairs(getMyGardenEggs()) do
                if (egg:GetAttribute("TimeToHatch") or 999) <= 0 then table.insert(eggsToHatch, egg) end
            end
            local hatchCount = #eggsToHatch
            for _, egg in ipairs(eggsToHatch) do
                if not isRunning then break end
                hatchEgg(egg)
                task.wait(config.hatchDelay)
            end
            local timeout = os.clock() + 60
            while isRunning and os.clock() < timeout do
                local hasReadyEgg = false
                for _, egg in ipairs(getMyGardenEggs()) do
                    if (egg:GetAttribute("TimeToHatch") or 999) <= 0 then hasReadyEgg = true break end
                end
                if not hasReadyEgg then break end
                task.wait(1)
            end
            STATS.totalHatched = STATS.totalHatched + hatchCount
            task.wait(config.delayAfterHatchAll)
            STATS.totalHatchCycles = STATS.totalHatchCycles + 1
            STATS.lastCycleDuration = os.time() - STATS.cycleStartTime
            task.wait(2)
            return true
        end

        -- ==================================================================
        -- FASE 3: FILTER + SELL
        -- ==================================================================
        local function runFilterAndSell()
            if not config.autoSell then return end
            updatesStatus("💸 Tim Sell...")
            equipTeamByPreset(config.sellPreset, config.sellLoadout)
            task.wait(config.delayAfterSell)
            updatesStatus("⭐ Filter pet...")
            local pets = getBackpackPets()
            local favCount = 0
            local skipCount = 0
            local presetProtectCount = 0
            for _, pet in ipairs(pets) do
                if not isRunning then return end
                local shouldBeFav = isPetInPreset(pet.name) or not isUnwantedPet(pet)
                if shouldBeFav then
                    local ok = ensureFavorit(pet.tool, true)
                    if ok then
                        if isPetInPreset(pet.name) then presetProtectCount = presetProtectCount + 1
                        else favCount = favCount + 1 end
                    end
                else
                    skipCount = skipCount + 1
                end
            end
            updatesStatus(string.format("⭐ Preset:%d Fav:%d Skip:%d", presetProtectCount, favCount, skipCount))
            task.wait(1)
            for _, pet in ipairs(getBackpackPets()) do
                local shouldBeFav = isPetInPreset(pet.name) or not isUnwantedPet(pet)
                if shouldBeFav and not pet.isFavorited then
                    ensureFavorit(pet.tool, true)
                end
            end
            task.wait(config.delayBeforeSell)
            updatesStatus("💰 Sell all...")
            sellAll()
            task.wait(2)
            updatesStatus("✅ Sell selesai")
            task.wait(1)
            scanNewPetsAfterSell()
        end

        -- ==================================================================
        -- MAIN LOOP
        -- ==================================================================
        local function refreshUnwantedMutationsCache()
            unwantedMutationsHatch = config.unwantedMutationsHatch or {}
        end

        function startAutoHatch()
            if isRunning then return end
            refreshUnwantedMutationsCache()
            resetStats()
            STATS.knownUUIDs = getInventoryUUIDs()
            STATS.eggBeforePlace = countEggsInBackpack()
            isRunning = true
            task.spawn(function()
                while isRunning and not isGuiDestroyed do
                    for cycle = 1, config.cycleCount do
                        if not isRunning or isGuiDestroyed then break end
                        runOneCycle(cycle, config.cycleCount)
                    end
                    if not isRunning or isGuiDestroyed then break end
                    runFilterAndSell()
                    updatesStatus("🔄 Cycle baru...")
                    task.wait(1)
                end
                if not isGuiDestroyed then updatesStatus("Status: Stopped") end
                isRunning = false
            end)
        end

            function stopAutoHatch()
        isRunning = false
        updatesStatus("⏹️ Stopping...")
    end

    -- ==================================================================
    -- AUTO SHOVEL SPRINKLER
    -- ==================================================================
    local function getMyFarmForShovel()
        local farmContainer = workspace:FindFirstChild("Farm")
        if not farmContainer then return nil end
        for _, farm in ipairs(farmContainer:GetChildren()) do
            local important = farm:FindFirstChild("Important")
            local dataFolder = important and important:FindFirstChild("Data")
            if dataFolder then
                for _, obj in ipairs(dataFolder:GetChildren()) do
                    if obj:IsA("StringValue") and obj.Value == player.Name then
                        return farm
                    end
                end
            end
        end
        return nil
    end

    local function getObjectsPhysicalForShovel()
        local farm = getMyFarmForShovel()
        if not farm then return nil end
        local important = farm:FindFirstChild("Important")
        if important then
            local objs = important:FindFirstChild("Objects_Physical")
            if objs then return objs end
        end
        for _, desc in ipairs(farm:GetDescendants()) do
            if desc.Name == "Objects_Physical" then return desc end
        end
        return nil
    end

    local function scanSprinklers()
        local objs = getObjectsPhysicalForShovel()
        if not objs then return {} end

        local result = {}
        for _, obj in ipairs(objs:GetChildren()) do
            if obj:IsA("Model") then
                local nameMatch = obj.Name:lower():find("sprinkler")
                local typeAttr = obj:GetAttribute("OBJECT_TYPE")
                local typeMatch = typeAttr and tostring(typeAttr):lower():find("sprinkler")
                if nameMatch or typeMatch then
                    table.insert(result, obj)
                end
            end
        end
        return result
    end

    local function findShovelForAuto()
        local shovelName = "Shovel [Destroy Plants]"
        local locations = {}
        local backpack = player:FindFirstChild("Backpack")
        if backpack then table.insert(locations, backpack) end
        if player.Character then table.insert(locations, player.Character) end

        for _, container in ipairs(locations) do
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and tool.Name == shovelName then
                    return tool
                end
            end
        end
        return nil
    end

    local function equipShovelForAuto()
        local shovel = findShovelForAuto()
        if not shovel then
            warn("[Auto Shovel] ❌ Shovel tidak ditemukan: Shovel [Destroy Plants]")
            return false
        end

        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return false end

        if shovel.Parent == character then
            return true
        end

        pcall(function() humanoid:EquipTool(shovel) end)
        task.wait(0.5)
        return shovel.Parent == character
    end

    local function unequipShovelForAuto()
        local shovel = findShovelForAuto()
        if not shovel then return true end

        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return false end

        if shovel.Parent == character then
            pcall(function() humanoid:UnequipTools() end)
            task.wait(0.5)
        end
        return true
    end

    local function deleteSprinklerObject(sprinkler)
        if not sprinkler or not sprinkler.Parent then return false end

        local ok = pcall(function()
            DeleteObjectRE:FireServer(sprinkler)
        end)

        task.wait(0.3)

        return ok and not sprinkler.Parent
    end

    function startAutoShovel()
        if isAutoShovelRunning then return end
        if isRunning then
            if autoShovelStatus then autoShovelStatus("⚠️ Stop Auto Hatch dulu") end
            return
        end
        if isLeveling then
            if autoShovelStatus then autoShovelStatus("⚠️ Stop Auto Leveling dulu") end
            return
        end

        isAutoShovelRunning = true

        task.spawn(function()
            -- 1. Scan sprinkler
            if autoShovelStatus then autoShovelStatus("🔍 Scan sprinkler...") end
            local sprinklers = scanSprinklers()

            if #sprinklers == 0 then
                if autoShovelStatus then autoShovelStatus("⚠️ Tidak ada sprinkler") end
                isAutoShovelRunning = false
                return
            end

            if autoShovelStatus then
                autoShovelStatus(string.format("🎯 %d sprinkler ditemukan", #sprinklers))
            end

            -- 2. Equip shovel
            if autoShovelStatus then autoShovelStatus("🔨 Equip shovel...") end
            if not equipShovelForAuto() then
                if autoShovelStatus then autoShovelStatus("❌ Gagal equip shovel") end
                isAutoShovelRunning = false
                return
            end

            -- 3. Shovel semua sprinkler
            local successCount = 0
            for i, sprinkler in ipairs(sprinklers) do
                if not isAutoShovelRunning then break end
                if not sprinkler.Parent then
                    continue
                end

                if autoShovelStatus then
                    autoShovelStatus(string.format("🔄 [%d/%d] %s",
                        i, #sprinklers, sprinkler.Name))
                end

                if deleteSprinklerObject(sprinkler) then
                    successCount = successCount + 1
                end

                task.wait(0.5)
            end

            -- 4. Unequip shovel
            if autoShovelStatus then autoShovelStatus("🔨 Unequip shovel...") end
            unequipShovelForAuto()

            -- 5. Selesai
            if autoShovelStatus then
                autoShovelStatus(string.format("✅ Selesai! %d/%d terhapus",
                    successCount, #sprinklers))
            end
            isAutoShovelRunning = false
        end)
    end

        function stopAutoShovel()
        isAutoShovelRunning = false
        if autoShovelStatus then autoShovelStatus("⏹️ Stopping...") end
    end

    -- ==================================================================
    -- AUTO COLLECT FRUIT
    -- ==================================================================
    KNOWN_FRUITS = {}
    KNOWN_MUTATIONS = {}
    
    function loadMutationList()
        local ok, MutationHandler = pcall(function()
            return require(ReplicatedStorage.Modules.MutationHandler)
        end)
        if ok and MutationHandler then
            local success, mutations = pcall(function()
                return MutationHandler:GetMutations()
            end)
            if success and mutations then
                for name, _ in pairs(mutations) do
                    KNOWN_MUTATIONS[name] = true
                end
                return
            end
        end
        -- Fallback: minimal mutations
        warn("[Auto Collect] Fallback mutations")
        local FALLBACK = {
            "Glimmering","Wet","Chilled","Frozen","Gold","Rainbow",
            "Diamond","Silver","Bronze","Disco","Gilded","Enchanted",
            "Shocked","Fried","Molten","Vamp","Ghostly","Volcanic",
            "Flaming","Blazing","Infernal","Corrupt","Toxic","Acidic",
            "Cosmic","Astral","Abyssal","Stormbound","Riptide","Grim",
        }
        for _, name in ipairs(FALLBACK) do
            KNOWN_MUTATIONS[name] = true
        end
    end

    function loadFruitList()
        local names, seen = {}, {}
    
        -- ⭐ Ambil dari SeedData (Sumber FWF)
        local SeedData_local = nil
        pcall(function()
            SeedData_local = require(ReplicatedStorage.Data.SeedData)
        end)
    
        if SeedData_local then
            for name, _ in pairs(SeedData_local) do
                if not seen[name] then
                    seen[name] = true
                    table.insert(names, name)
                end
            end
        end
    
        -- Fallback jika SeedData kosong
        if #names == 0 then
            for _, f in ipairs(CollectionService:GetTagged("Harvestable")) do
                if f:IsA("Model") and not seen[f.Name] then
                    seen[f.Name] = true
                    table.insert(names, f.Name)
                end
            end
        end
    
        -- Masukkan ke table KNOWN_FRUITS
        for _, fruitName in ipairs(names) do
            KNOWN_FRUITS[fruitName:lower()] = fruitName
        end
    end
            
    function getFruitCapacity()
        if not DataService then return 0, 0 end
        local data = DataService:GetData()
        if not data or not data.InventoryData then return 0, 0 end
        local count = 0
        for _, item in pairs(data.InventoryData) do
            if item.ItemType == "Holdable" then count = count + 1 end
        end
        local bonus = player:GetAttribute("BonusBackpackSize") or 0
        return count, 200 + bonus
    end

    local function isFruitInventoryFull()
        local current, max = getFruitCapacity()
        return current >= max, current, max
    end

    local function getFruitInfo(fruit)
        if not fruit then return nil end
        local name = fruit.Name
        local weight = 0

        local w1 = fruit:GetAttribute("Weight")
        local w2 = fruit:GetAttribute("BaseWeight")
        if w1 then weight = tonumber(w1) or 0
        elseif w2 then weight = tonumber(w2) or 0 end

        if weight == 0 then
            for _, child in ipairs(fruit:GetChildren()) do
                if child:IsA("NumberValue") or child:IsA("IntValue") then
                    local cn = child.Name:lower()
                    if cn:find("weight") or cn:find("value") then
                        weight = tonumber(child.Value) or 0
                        break
                    end
                end
            end
        end

        local mutationList = {}
        for attrName, attrValue in pairs(fruit:GetAttributes()) do
            if attrValue == true and KNOWN_MUTATIONS[attrName] then
                table.insert(mutationList, attrName)
            end
        end
        table.sort(mutationList)

        return {
            instance = fruit,
            name = name,
            weight = weight,
            mutationList = mutationList,
            mutationStr = #mutationList > 0 and table.concat(mutationList, ","):lower() or "",
        }
    end
            
    local function isFruit(object)
        if not object or not object:IsA("Model") then return false end
        local nameLower = object.Name:lower()
        if KNOWN_FRUITS[nameLower] then return true end
        for fruitLower, _ in pairs(KNOWN_FRUITS) do
            if nameLower:find(fruitLower, 1, true) then return true end
        end
        return false
    end

    local function matchTargetFruit(fruitInfo)
        if next(autoCollectSelectedFruits) == nil then return true end
        local nameLower = fruitInfo.name:lower()
        for selected in pairs(autoCollectSelectedFruits) do
            if nameLower:find(selected, 1, true) then return true end
        end
        return false
    end

    local function matchWeight(fruitInfo)
        if autoCollectMaxWeight <= 0 then return true end
        if fruitInfo.weight <= 0 then return true end
        return fruitInfo.weight <= autoCollectMaxWeight
    end

    local function matchMutation(fruitInfo)
        if next(autoCollectSelectedMutations) == nil then return true end
        if fruitInfo.mutationStr == "" then return false end
        for selected in pairs(autoCollectSelectedMutations) do
            if fruitInfo.mutationStr:find(selected, 1, true) then return true end
        end
        return false
    end

    local function IsMyFruit(fruit)
        local ancestor = fruit:FindFirstAncestor("Important")
        if not ancestor then return false end
    
        local data = ancestor:FindFirstChild("Data")
        if not data then return false end
    
        local owner = data:FindFirstChild("Owner")
        if not owner or not owner.Value then return false end
        return owner.Value == player.Name
    end

    local function isFruitReady(fruit)
        -- Wajib punya tag Harvestable
        if not fruit:HasTag("Harvestable") then return false end
    
        -- Wajib punya Grow & Age
        local grow = fruit:FindFirstChild("Grow")
        if not grow then return false end
        local ageValue = grow:FindFirstChild("Age")
        local maxAge = fruit:GetAttribute("MaxAge")
    
        if not ageValue or not maxAge then return false end
    
        -- Wajib 100% matang
        return ageValue.Value >= maxAge
    end
            
    function scanFruits()
        local matched, allFound = {}, {}
    
        -- Kita tetap pakai GetTagged agar lebih ringan dari GetDescendants
        for _, fruit in ipairs(CollectionService:GetTagged("Harvestable")) do
            if fruit:IsA("Model") and IsMyFruit(fruit) then
                local info = getFruitInfo(fruit)
            
                if info and info.name ~= "" then
                    table.insert(allFound, info)
                
                    -- ⭐ FILTER GABUNGAN: Harus lolos isFruitReady (Tag + 100%)
                    if isFruitReady(fruit) and matchTargetFruit(info) and matchWeight(info) and matchMutation(info) then
                        table.insert(matched, info)
                    end
                end
            end
        end
    
        return matched, allFound
    end

    local function autoSellFruit()
        if not autoCollectSellEnabled then
            return false, "Auto Sell OFF"
        end

        local full, current, max = isFruitInventoryFull()
        if not full then
            return false, string.format("Belum penuh (%d/%d)", current, max)
        end

        if autoCollectStatus then
            autoCollectStatus(string.format("💰 Penuh (%d/%d), auto sell...", current, max))
        end

        -- Simpan posisi
        local character = player.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        local savedCFrame = hrp and hrp.CFrame or nil

        -- Teleport ke Sell Shop
        if TeleportPlayer then
            local tp = workspace:FindFirstChild("Tutorial_Points")
            local sellPoint = tp and tp:FindFirstChild("Tutorial_Point_2")
            if sellPoint then
                pcall(function()
                    TeleportPlayer(player, sellPoint.CFrame, "Sell Shop")
                end)
            end
        end
        task.wait(autoCollectDelayAfterTeleport)

        -- Sell
        pcall(function()
            SellInventoryRE:FireServer()
        end)
        task.wait(autoCollectDelayAfterSell)

        -- Teleport balik ke posisi terakhir
        if TeleportPlayer and savedCFrame then
            pcall(function()
                TeleportPlayer(player, savedCFrame, "Return")
            end)
        elseif TeleportPlayer and GetFarm then
            local ok, farm = pcall(function() return GetFarm(player) end)
            if ok and farm then
                local sp = farm:FindFirstChild("Spawn_Point")
                if sp then
                    pcall(function()
                        TeleportPlayer(player, sp.CFrame, "Farm")
                    end)
                end
            end
        end
        task.wait(autoCollectDelayAfterReturn)

        local newCurrent, newMax = getFruitCapacity()
        return true, string.format("Selesai: %d/%d", newCurrent, newMax)
    end

    function startAutoCollect()
        if isAutoCollectRunning then return end
        if isRunning then
            if autoCollectStatus then autoCollectStatus("⚠️ Stop Auto Hatch dulu") end
            return
        end
        if isLeveling then
            if autoCollectStatus then autoCollectStatus("⚠️ Stop Auto Leveling dulu") end
            return
        end
        if isAutoShovelRunning then
            if autoCollectStatus then autoCollectStatus("⚠️ Stop Auto Shovel dulu") end
            return
        end

        isAutoCollectRunning = true

        task.spawn(function()
            while isAutoCollectRunning and not isGuiDestroyed do
                task.wait(autoCollectInterval)

                if not player.Character or not player.Character:FindFirstChildOfClass("Humanoid") then
                    continue
                end

                -- Cek inventory penuh
                local full, current, max = isFruitInventoryFull()
                if full then
                    if autoCollectStatus then
                        autoCollectStatus(string.format("💰 Penuh (%d/%d), auto sell...", current, max))
                    end
                    local ok, msg = autoSellFruit()
                    if not ok and autoCollectStatus then
                        autoCollectStatus("⚠️ " .. tostring(msg))
                        task.wait(5)
                    end
                    continue
                end

                -- Scan & collect
                local matched, allFound = scanFruits()

                if #matched == 0 then
                    if autoCollectStatus then
                        -- Tampilkan total buah yang ada di kebun vs yang siap panen
                        autoCollectStatus(string.format("⏳ Menunggu matang (%d total, %d/%d slot)",
                            #allFound, current, max))
                    end
                    continue
                end

                if autoCollectStatus then
                    autoCollectStatus(string.format("🔄 Collect %d buah (%d/%d)",
                        #matched, current, max))
                end

                local instances = {}
                for _, info in ipairs(matched) do
                    table.insert(instances, info.instance)
                end

                pcall(function()
                    CropsCollectRE:FireServer(instances)
                end)
            end

            if autoCollectStatus and not isGuiDestroyed then
                autoCollectStatus("⏹️ Stopped")
            end
            isAutoCollectRunning = false
        end)
    end

    function stopAutoCollect()
        isAutoCollectRunning = false
        if autoCollectStatus then autoCollectStatus("⏹️ Stopping...") end
    end
end -- BLOCK 5
end -- GROUP: BACKEND (logic, state, helper, data)

-- shared: diisi di BLOCK 6 (GUI SKELETON, MINIMIZE/DRAG, WEIGHT TAB)
local tabs, tabBtns, activeTab, defaultView, tabFrames, makeInputRow, makeToggle, weightScroll

do -- BLOCK 6: GUI SKELETON, MINIMIZE/DRAG, WEIGHT TAB
    -- ==================================================================
    -- GUI SKELETON
    -- ==================================================================
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AoneHub"
    screenGui.Parent = playerGui
    screenGui.ResetOnSpawn = false

    screenGui.Destroying:Connect(function()
        isGuiDestroyed = true
        isLeveling = false
        -- [PATCH 3] Stop Auto Hatch & Auto Gift
        isRunning = false
        isGiftPetRunning = false
        giftPetUserStarted = false
        isAutoShovelRunning = false
        isAutoCollectRunning = false

        if AutoMutation_Shared and AutoMutation_Shared.state then
            AutoMutation_Shared.state.isRunning = false
        end

        if AutoBuyBackend and AutoBuyBackend.stop then
            AutoBuyBackend.stop()
        end
    
        rainbowMode = false
        if rainbowTask then
            task.cancel(rainbowTask)
            rainbowTask = nil
        end

        config.selectedTeamPreset = selectedTeamPreset
        config.selectedWeightPreset = selectedWeightPreset
        config.selectedAdvancedPreset = selectedAdvancedPreset
        config.selectedMutationPreset = selectedMutationPreset
        config.targetLevel = targetLevel
        config.advancedTargetLevel = advancedTargetLevel
        config.rainbowMode = rainbowMode
        config.unwantedMutations = unwantedMutations
        config.isAutoWeight = isAutoWeight
        config.isAutoMutation = isAutoMutation
        config.isAdvancedLeveling = isAdvancedLeveling
        config.selectedPetTypes = selectedPetTypes
        saveConfig()
    end)

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
    mainFrame.Size = UDim2.new(0, 580, 0, 320)
    mainFrame.Position = UDim2.new(0.5, -290, 0.5, -160)
    mainFrame.BackgroundColor3 = C.bg
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Active = true
    mainFrame.Parent = screenGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 28)
    titleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

    local titleFill = Instance.new("Frame")
    titleFill.Size = UDim2.new(1, 0, 0.5, 0)
    titleFill.Position = UDim2.new(0, 0, 0.5, 0)
    titleFill.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    titleFill.BorderSizePixel = 0
    titleFill.Parent = titleBar

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.6, 0, 1, 0)
    titleLabel.Position = UDim2.new(0, 12, 0, 0)
    titleLabel.Text = "AoneHub"
    titleLabel.TextColor3 = C.text
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 11
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

    --==================================================
    -- MINIMIZE / RESTORE
    --==================================================

    local lastMainPosition = mainFrame.Position
    local circlePosition = nil

    minimizeBtn.MouseButton1Click:Connect(function()

        -- Simpan posisi MainFrame
        lastMainPosition = mainFrame.Position

        -- Jika circle belum pernah diposisikan,
        -- letakkan di posisi MainFrame
        if not circlePosition then
            circlePosition = UDim2.new(
                0,
                mainFrame.AbsolutePosition.X,
                0,
                mainFrame.AbsolutePosition.Y
            )
        end

        minimizedCircle.Position = circlePosition

        mainFrame.Visible = false
        minimizedCircle.Visible = true
    end)

    minimizedCircle.MouseButton1Click:Connect(function()

        -- Simpan posisi circle setelah kemungkinan digeser
        circlePosition = minimizedCircle.Position

        -- Kembalikan MainFrame ke posisi terakhir
        mainFrame.Position = lastMainPosition

        minimizedCircle.Visible = false
        mainFrame.Visible = true
    end)

    closeBtn.MouseButton1Click:Connect(function()
        isGuiDestroyed = true
        isLeveling = false
        -- [PATCH 6] Reset flag sebelum Destroy()
        isRunning = false
        isGiftPetRunning = false
        giftPetUserStarted = false
        isAutoShovelRunning = false
        isAutoCollectRunning = false

        if AutoMutation_Shared and AutoMutation_Shared.state then
            AutoMutation_Shared.state.isRunning = false
        end

        if AutoBuyBackend and AutoBuyBackend.stop then
            AutoBuyBackend.stop()
        end
        
        screenGui:Destroy()
    end)

    --==================================================
    -- DRAG FUNCTION
    --==================================================

    local function makeDraggable(handle, target)
        local dragging = false
        local dragStart
        local startPos
        local dragInput

        handle.Active = true

        handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then

                dragging = true
                dragStart = input.Position
                startPos = target.Position

                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)

        handle.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then

                dragInput = input
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and input == dragInput then
                local delta = input.Position - dragStart

                target.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,

                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end)
    end

    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0.2, 0, 1, -28)
    sidebar.Position = UDim2.new(0, 0, 0, 28)
    sidebar.BackgroundColor3 = C.sidebar
    sidebar.BorderSizePixel = 0
    sidebar.Parent = mainFrame
    Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 10)

    local sidebarFill = Instance.new("Frame")
    sidebarFill.Size = UDim2.new(1, 0, 0.3, 0)
    sidebarFill.Position = UDim2.new(0, 0, 0.85, 0)
    sidebarFill.BackgroundColor3 = C.sidebar
    sidebarFill.BorderSizePixel = 0
    sidebarFill.Parent = sidebar

    local menuLabel = Instance.new("TextLabel")
    menuLabel.Size = UDim2.new(1, 0, 0, 16)
    menuLabel.Position = UDim2.new(0, 0, 0, 6)
    menuLabel.Text = "MENU"
    menuLabel.TextColor3 = Color3.fromRGB(120, 120, 130)
    menuLabel.Font = Enum.Font.GothamBold
    menuLabel.TextSize = 9
    menuLabel.TextXAlignment = Enum.TextXAlignment.Center
    menuLabel.BackgroundTransparency = 1
    menuLabel.Parent = sidebar

    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(0.7, 0, 0, 1)
    sep.Position = UDim2.new(0.15, 0, 0, 26)
    sep.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    sep.BorderSizePixel = 0
    sep.Parent = sidebar

    tabs = {
        {name="Farm", label="🌾 Farm"},
        {name="Weight", label="🤖 Automaton"},
        {name="Hatch", label="🥚 Hatch"},
        {name="Event", label="🔥 Event"},
        {name="Mutation", label="🧬 Mutation"},
        {name="AutoBuy", label="🛒 Buy"},
        {name="Inventory", label="🎒 Inventory"},
        {name="Ekstra", label="⚙️ Extra"}
    }

    tabBtns = {}
    activeTab = nil

    for i, tab in ipairs(tabs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.82, 0, 0, 22)
        btn.Position = UDim2.new(0.09, 0, 0, 30 + (i-1)*27)
        btn.Text = tab.label
        btn.TextColor3 = C.textDim
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 8
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.Parent = sidebar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        btn.MouseEnter:Connect(function()
            if activeTab ~= tab.name then
                btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
            end
        end)

        btn.MouseLeave:Connect(function()
            if activeTab ~= tab.name then
                btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
            end
        end)

        tabBtns[tab.name] = btn
    end

    local contentArea = Instance.new("Frame")
    contentArea.Size = UDim2.new(0.8, -8, 1, -34)
    contentArea.Position = UDim2.new(0.2, 4, 0, 32)
    contentArea.BackgroundTransparency = 1
    contentArea.ClipsDescendants = true
    contentArea.Parent = mainFrame

    defaultView = Instance.new("Frame")
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

    makeDraggable(titleBar, mainFrame)
    makeDraggable(minimizedCircle, minimizedCircle)

    tabFrames = {}
    for _, tab in ipairs(tabs) do
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 1, 0)
        f.BackgroundTransparency = 1
        f.Visible = false
        f.Parent = contentArea
        tabFrames[tab.name] = f
    end

    function makeInputRow(parent, yPos, label, configKey, isNumber, min, max)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.55, -15, 0, 16)
        lbl.Position = UDim2.new(0, 10, 0, yPos)
        lbl.Text = label
        lbl.TextColor3 = C.textDim
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 8
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.BackgroundTransparency = 1
        lbl.Parent = parent

        local input = Instance.new("TextBox")
        input.Size = UDim2.new(0.45, -15, 0, 20)
        input.Position = UDim2.new(0.55, 5, 0, yPos)
        input.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
        input.BorderSizePixel = 0
        input.Font = Enum.Font.Gotham
        input.Text = tostring(config[configKey])
        input.TextColor3 = C.text
        input.TextSize = 8
        input.Parent = parent
        Instance.new("UICorner", input).CornerRadius = UDim.new(0, 3)
        input.FocusLost:Connect(function()
            if isNumber then
                local n = tonumber(input.Text)
                if n and (min == nil or n >= min) and (max == nil or n <= max) then
                    config[configKey] = n
                    saveConfig()
                end
            end
            input.Text = tostring(config[configKey])
        end)
        return input
    end

    function makeToggle(parent, yPos, onText, offText, configKey)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -20, 0, 22)
        btn.Position = UDim2.new(0, 10, 0, yPos)
        btn.BackgroundColor3 = config[configKey] and C.success or Color3.fromRGB(70, 70, 85)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.Gotham
        btn.Text = config[configKey] and onText or offText
        btn.TextColor3 = C.text
        btn.TextSize = 9
        btn.Parent = parent
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        btn.MouseButton1Click:Connect(function()
            config[configKey] = not config[configKey]
            btn.Text = config[configKey] and onText or offText
            btn.BackgroundColor3 = config[configKey] and C.success or Color3.fromRGB(70, 70, 85)
            saveConfig()
        end)
        return btn
    end

    -- ==================================================================
    -- WEIGHT TAB
    -- ==================================================================
    local weightTab = tabFrames["Weight"]

    weightScroll = Instance.new("ScrollingFrame")
    weightScroll.Size = UDim2.new(1, -10, 1, -10)
    weightScroll.Position = UDim2.new(0, 5, 0, 5)
    weightScroll.BackgroundTransparency = 1
    weightScroll.BorderSizePixel = 0
    weightScroll.ScrollBarThickness = 4
    weightScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    weightScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    weightScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    weightScroll.Parent = weightTab

    local weightLayout = Instance.new("UIListLayout")
    weightLayout.Padding = UDim.new(0, 6)
    weightLayout.SortOrder = Enum.SortOrder.LayoutOrder
    weightLayout.Parent = weightScroll
end -- BLOCK 6

-- shared: diisi di BLOCK 7 (UI HELPERS, DYNAMIC DROPDOWN SYSTEM)
local createSection, createDynamicDropdown, sectionMeta

do -- BLOCK 7: UI HELPERS, DYNAMIC DROPDOWN SYSTEM
    -- ==================================================================
    -- UI HELPERS
    -- ==================================================================
    sectionMeta = {}

    function createSection(parent, title, sectionKey)
        local SectionFrame = Instance.new("Frame")
        local expandedHeight = 200
        local collapsedHeight = 28

        SectionFrame.Size = UDim2.new(1, -10, 0, expandedHeight)
        SectionFrame.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
        SectionFrame.BorderSizePixel = 0
        SectionFrame.ClipsDescendants = true
        SectionFrame.Parent = parent

        local UICornerSection = Instance.new("UICorner")
        UICornerSection.CornerRadius = UDim.new(0, 6)
        UICornerSection.Parent = SectionFrame

        -- Section tanpa title tetap seperti sebelumnya.
        if not title then
            return SectionFrame, nil
        end

        sectionKey = sectionKey or title

        -- true = terbuka, false = tertutup
        local expanded = config.sectionStates[sectionKey] ~= false

        local SectionTitle = Instance.new("TextButton")
        SectionTitle.Name = "SectionHeader"
        SectionTitle.Size = UDim2.new(1, 0, 0, collapsedHeight)
        SectionTitle.Position = UDim2.new(0, 0, 0, 0)
        SectionTitle.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
        SectionTitle.BorderSizePixel = 0
        SectionTitle.AutoButtonColor = false
        SectionTitle.Font = Enum.Font.GothamBold
        SectionTitle.Text = (expanded and "▼  " or "▶  ") .. title
        SectionTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
        SectionTitle.TextSize = 11
        SectionTitle.TextXAlignment = Enum.TextXAlignment.Left
        SectionTitle.ZIndex = 20
        SectionTitle.Parent = SectionFrame

        local HeaderPadding = Instance.new("UIPadding")
        HeaderPadding.PaddingLeft = UDim.new(0, 10)
        HeaderPadding.Parent = SectionTitle

        sectionMeta[SectionFrame] = {
            title = title,
            key = sectionKey,
            expanded = expanded,
            expandedHeight = expandedHeight,
            collapsedHeight = collapsedHeight,
            header = SectionTitle,
        }

        if not expanded then
            SectionFrame.Size = UDim2.new(1, -10, 0, collapsedHeight)
        end

        SectionTitle.MouseEnter:Connect(function()
            SectionTitle.BackgroundColor3 = Color3.fromRGB(48, 48, 60)
        end)

        SectionTitle.MouseLeave:Connect(function()
            SectionTitle.BackgroundColor3 = Color3.fromRGB(38, 38, 48)
        end)

        -- Beberapa section lama mengatur Size setelah createSection().
        -- Tunggu sampai kode pembuat section selesai, lalu terapkan state config.
        task.defer(function()
            local meta = sectionMeta[SectionFrame]
            if not meta then return end

            local currentHeight = SectionFrame.Size.Y.Offset

            if meta.expanded then
                meta.expandedHeight = currentHeight
                SectionFrame.Size = UDim2.new(1, -10, 0, currentHeight)
            else
                meta.expandedHeight = currentHeight
                SectionFrame.Size = UDim2.new(1, -10, 0, meta.collapsedHeight)
                SectionTitle.Text = "▶  " .. meta.title
            end
        end)

        SectionTitle.MouseButton1Click:Connect(function()
            local meta = sectionMeta[SectionFrame]
            if not meta then return end

            meta.expanded = not meta.expanded

            -- Simpan status langsung ke config.
            config.sectionStates[meta.key] = meta.expanded
            saveConfig()

            if meta.expanded then
                -- Ambil tinggi terakhir saat section terbuka.
                local targetHeight = meta.expandedHeight

                SectionTitle.Text = "▼  " .. meta.title

                SectionFrame.Size = UDim2.new(
                    1, -10, 0, targetHeight
                )
            else
                -- Simpan tinggi sebelum ditutup agar dropdown dinamis tidak kehilangan ukurannya.
                meta.expandedHeight = SectionFrame.Size.Y.Offset

                SectionTitle.Text = "▶  " .. meta.title

                SectionFrame.Size = UDim2.new(
                    1, -10, 0, meta.collapsedHeight
                )
            end
        end)

        return SectionFrame, SectionTitle
    end

    -- =========================================================
    -- DYNAMIC DROPDOWN SYSTEM
    -- Support banyak dropdown dalam 1 section
    -- =========================================================

    local dynamicDropdownSections = {}

    function createDynamicDropdown(
        parent,
        position,
        placeholder,
        parentSection,
        baseSectionHeight,
        parentScroll
    )
        local width = 1
        local offsetX = -20
        local itemHeight = 22
        local maxListHeight = 100

        parentSection = parentSection or parent

        -- =====================================================
        -- REGISTER SECTION
        -- =====================================================

        if not dynamicDropdownSections[parentSection] then
            dynamicDropdownSections[parentSection] = {
                baseHeight = baseSectionHeight or parentSection.Size.Y.Offset,
                dropdowns = {},
                originalPositions = {}
            }
        end

        local sectionData = dynamicDropdownSections[parentSection]

        -- =====================================================
        -- CONTAINER
        -- =====================================================

        local Container = Instance.new("Frame")
        Container.Name = "DynamicDropdown"
        Container.Size = UDim2.new(width, offsetX, 0, 28)
        Container.Position = position
        Container.BackgroundTransparency = 1
        Container.ClipsDescendants = true
        Container.ZIndex = 10
        Container.Parent = parent

        -- Simpan posisi asli dropdown
        local originalPosition = position

        -- =====================================================
        -- HEADER
        -- =====================================================

        local HeaderFrame = Instance.new("Frame")
        HeaderFrame.Size = UDim2.new(1, 0, 0, 28)
        HeaderFrame.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
        HeaderFrame.BorderSizePixel = 0
        HeaderFrame.ZIndex = 10
        HeaderFrame.Parent = Container

        local UICornerHeader = Instance.new("UICorner")
        UICornerHeader.CornerRadius = UDim.new(0, 4)
        UICornerHeader.Parent = HeaderFrame

        local HeaderButton = Instance.new("TextButton")
        HeaderButton.Size = UDim2.new(1, -20, 1, 0)
        HeaderButton.BackgroundTransparency = 1
        HeaderButton.Font = Enum.Font.Gotham
        HeaderButton.Text = placeholder
        HeaderButton.TextColor3 = Color3.fromRGB(200, 200, 200)
        HeaderButton.TextSize = 9
        HeaderButton.TextXAlignment = Enum.TextXAlignment.Left
        HeaderButton.ZIndex = 11
        HeaderButton.Parent = HeaderFrame

        local HeaderPadding = Instance.new("UIPadding")
        HeaderPadding.PaddingLeft = UDim.new(0, 8)
        HeaderPadding.Parent = HeaderButton

        local ArrowLabel = Instance.new("TextLabel")
        ArrowLabel.Size = UDim2.new(0, 15, 0, 20)
        ArrowLabel.Position = UDim2.new(1, -18, 0, 4)
        ArrowLabel.BackgroundTransparency = 1
        ArrowLabel.Font = Enum.Font.GothamBold
        ArrowLabel.Text = "▼"
        ArrowLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
        ArrowLabel.TextSize = 10
        ArrowLabel.ZIndex = 11
        ArrowLabel.Parent = HeaderFrame

        -- =====================================================
        -- LIST CONTAINER
        -- =====================================================

        local ListContainer = Instance.new("Frame")
        ListContainer.Size = UDim2.new(1, 0, 0, 0)
        ListContainer.Position = UDim2.new(0, 0, 0, 30)
        ListContainer.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
        ListContainer.BorderSizePixel = 0
        ListContainer.Visible = false
        ListContainer.ZIndex = 10
        ListContainer.Parent = Container

        local UICornerList = Instance.new("UICorner")
        UICornerList.CornerRadius = UDim.new(0, 4)
        UICornerList.Parent = ListContainer

        -- =====================================================
        -- LIST SCROLL
        -- =====================================================

        local ListScroll = Instance.new("ScrollingFrame")
        ListScroll.Size = UDim2.new(1, -4, 1, -4)
        ListScroll.Position = UDim2.new(0, 2, 0, 2)
        ListScroll.BackgroundTransparency = 1
        ListScroll.BorderSizePixel = 0
        ListScroll.ScrollBarThickness = 3
        ListScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
        ListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        ListScroll.ZIndex = 11
        ListScroll.Parent = ListContainer

        local ListLayout = Instance.new("UIListLayout")
        ListLayout.Padding = UDim.new(0, 2)
        ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ListLayout.Parent = ListScroll

        local isOpen = false

        -- =====================================================
        -- REGISTER DROPDOWN
        -- =====================================================

        local dropdownData = {
            Container = Container,
            OriginalPosition = originalPosition,
            IsOpen = function()
                return isOpen
            end,

            GetExtraHeight = function()
                if not isOpen then
                    return 0
                end

                return ListContainer.Size.Y.Offset + 2
            end
        }

        table.insert(sectionData.dropdowns, dropdownData)

        -- =====================================================
        -- SIMPAN POSISI CHILDREN ASLI
        -- =====================================================

        local function registerOriginalPositions()
            for _, child in ipairs(parentSection:GetChildren()) do
                if child:IsA("GuiObject") then

                    -- Jangan simpan dropdown sebagai child biasa
                    local isDropdown = false

                    for _, dropdown in ipairs(sectionData.dropdowns) do
                        if dropdown.Container == child then
                            isDropdown = true
                            break
                        end
                    end

                    if not isDropdown then
                        if not sectionData.originalPositions[child] then
                            sectionData.originalPositions[child] = child.Position
                        end
                    end
                end
            end
        end

        -- =====================================================
        -- HITUNG POSISI BARU SEMUA ELEMENT
        -- =====================================================

        local function reflowSection()

            registerOriginalPositions()

            -- =============================================
            -- 1. Hitung total extra height
            -- =============================================

            local totalExtraHeight = 0

            for _, dropdown in ipairs(sectionData.dropdowns) do
                totalExtraHeight =
                    totalExtraHeight +
                    dropdown.GetExtraHeight()
            end

            -- =============================================
            -- 2. Update posisi semua dropdown
            -- =============================================

            for _, dropdown in ipairs(sectionData.dropdowns) do

                local originalY = dropdown.OriginalPosition.Y.Offset

                local shift = 0

                for _, previousDropdown in ipairs(sectionData.dropdowns) do

                    if previousDropdown ~= dropdown then

                        local previousY =
                            previousDropdown.OriginalPosition.Y.Offset

                        -- Hanya dropdown yang berada
                        -- DI ATAS dropdown ini
                        if previousY < originalY then

                            shift =
                                shift +
                                previousDropdown.GetExtraHeight()
                        end
                    end
                end

                dropdown.Container.Position = UDim2.new(
                    dropdown.OriginalPosition.X.Scale,
                    dropdown.OriginalPosition.X.Offset,
                    dropdown.OriginalPosition.Y.Scale,
                    originalY + shift
                )
            end

            -- =============================================
            -- 3. Geser element lain yang berada di bawah
            -- =============================================

            for child, originalPos in pairs(sectionData.originalPositions) do

                if child
                    and child.Parent == parentSection
                    and child:IsA("GuiObject")
                then

                    local originalY = originalPos.Y.Offset
                    local shift = 0

                    for _, dropdown in ipairs(sectionData.dropdowns) do

                        local dropdownY =
                            dropdown.OriginalPosition.Y.Offset

                        -- Jika dropdown berada di atas child
                        if dropdownY < originalY then
                            shift =
                                shift +
                                dropdown.GetExtraHeight()
                        end
                    end

                    child.Position = UDim2.new(
                        originalPos.X.Scale,
                        originalPos.X.Offset,
                        originalPos.Y.Scale,
                        originalY + shift
                    )
                end
            end

            -- =============================================
            -- 4. Update tinggi section
            -- =============================================

            local calculatedHeight = sectionData.baseHeight + totalExtraHeight

            -- Jika section sedang terbuka, simpan tinggi dinamisnya.
            -- Jika tertutup, jangan biarkan dropdown mengubah tinggi 28 px.
            local meta = sectionMeta[parentSection]
            if meta then
                meta.expandedHeight = calculatedHeight

                if meta.expanded then
                    parentSection.Size = UDim2.new(
                        parentSection.Size.X.Scale,
                        parentSection.Size.X.Offset,
                        0,
                        calculatedHeight
                    )
                end
            else
                parentSection.Size = UDim2.new(
                    parentSection.Size.X.Scale,
                    parentSection.Size.X.Offset,
                    0,
                    calculatedHeight
                )
            end

            -- =============================================
            -- 5. Update CanvasSize parent Scroll
            -- =============================================

            if parentScroll then

                local layout =
                    parentScroll:FindFirstChildOfClass("UIListLayout")

                if layout then

                    task.defer(function()

                        parentScroll.CanvasSize = UDim2.new(
                            0,
                            0,
                            0,
                            math.max(
                                layout.AbsoluteContentSize.Y + 20,
                                500
                            )
                        )

                    end)

                end
            end
        end

        -- =====================================================
        -- UPDATE SIZE DROPDOWN
        -- =====================================================

        local function updateAll()

            local itemCount = 0

            for _, child in ipairs(ListScroll:GetChildren()) do
                if child:IsA("TextButton") then
                    itemCount = itemCount + 1
                end
            end

            local contentHeight =
                itemCount * (itemHeight + 2) + 2

            local listHeight =
                math.min(contentHeight, maxListHeight)

            -- List
            ListContainer.Size = UDim2.new(
                1,
                0,
                0,
                listHeight
            )

            ListScroll.CanvasSize = UDim2.new(
                0,
                0,
                0,
                contentHeight
            )

            -- Dropdown sendiri
            if isOpen then

                Container.Size = UDim2.new(
                    width,
                    offsetX,
                    0,
                    30 + listHeight + 2
                )

            else

                Container.Size = UDim2.new(
                    width,
                    offsetX,
                    0,
                    28
                )

            end

            -- Re-layout seluruh section
            reflowSection()
        end

        -- =====================================================
        -- CLOSE
        -- =====================================================

        local function close()

            if not isOpen then
                return
            end

            isOpen = false

            ListContainer.Visible = false
            ArrowLabel.Text = "▼"

            updateAll()
        end

        -- =====================================================
        -- TOGGLE
        -- =====================================================

        local function toggle()

            isOpen = not isOpen

            if isOpen then

                ListContainer.Visible = true
                ArrowLabel.Text = "▲"

            else

                ListContainer.Visible = false
                ArrowLabel.Text = "▼"

            end

            updateAll()
        end

        HeaderButton.MouseButton1Click:Connect(toggle)

        -- =====================================================
        -- RETURN
        -- =====================================================

        return {
            Container = Container,

            HeaderButton = HeaderButton,

            ListContainer = ListContainer,

            ListScroll = ListScroll,

            ItemHeight = itemHeight,

            UpdateSize = updateAll,

            Close = close,

            Toggle = toggle,

            IsOpen = function()
                return isOpen
            end,

            GetItemCount = function()

                local count = 0

                for _, child in ipairs(ListScroll:GetChildren()) do
                    if child:IsA("TextButton") then
                        count = count + 1
                    end
                end

                return count

            end,

            ParentSection = parentSection,

            BaseHeight = sectionData.baseHeight
        }
    end
end -- BLOCK 7

-- shared: diisi di BLOCK 8 (UI SECTION: PRESET, PET TARGET, PILIH TIM)
local PresetNameInput, PetSearchBox, PetListFrame, EditPresetDropdown, SavePresetButton,
    DeletePresetButton, TargetSearchBox, TargetListFrame, ScanButton, TeamPresetDropdown,
    AdvancedToggleButton, AdvancedPresetDropdown

do -- BLOCK 8: UI SECTION: PRESET, PET TARGET, PILIH TIM
    -- ==================================================================
    -- SECTION: BUAT/EDIT PRESET (DROPDOWN DINAMIS)
    -- ==================================================================
    local CreatePresetSection = createSection(weightScroll, "💾 Buat/Edit Preset", "createPreset")
    CreatePresetSection.LayoutOrder = 1
    CreatePresetSection.Size = UDim2.new(1, -10, 0, 239)

    PresetNameInput = Instance.new("TextBox")
    PresetNameInput.Size = UDim2.new(1, -20, 0, 22)
    PresetNameInput.Position = UDim2.new(0, 10, 0, 28)
    PresetNameInput.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    PresetNameInput.BorderSizePixel = 0
    PresetNameInput.Font = Enum.Font.Gotham
    PresetNameInput.PlaceholderText = "Nama preset tim..."
    PresetNameInput.Text = ""
    PresetNameInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    PresetNameInput.TextSize = 9
    PresetNameInput.Parent = CreatePresetSection

    local UICornerPresetName = Instance.new("UICorner")
    UICornerPresetName.CornerRadius = UDim.new(0, 4)
    UICornerPresetName.Parent = PresetNameInput

    PetSearchBox = Instance.new("TextBox")
    PetSearchBox.Size = UDim2.new(1, -20, 0, 22)
    PetSearchBox.Position = UDim2.new(0, 10, 0, 55)
    PetSearchBox.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    PetSearchBox.BorderSizePixel = 0
    PetSearchBox.Font = Enum.Font.Gotham
    PetSearchBox.PlaceholderText = "🔍 Cari pet..."
    PetSearchBox.Text = ""
    PetSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    PetSearchBox.TextSize = 9
    PetSearchBox.Parent = CreatePresetSection

    local UICornerPetSearch = Instance.new("UICorner")
    UICornerPetSearch.CornerRadius = UDim.new(0, 4)
    UICornerPetSearch.Parent = PetSearchBox

    PetListFrame = Instance.new("ScrollingFrame")
    PetListFrame.Size = UDim2.new(1, -20, 0, 60)
    PetListFrame.Position = UDim2.new(0, 10, 0, 82)
    PetListFrame.BackgroundTransparency = 1
    PetListFrame.BorderSizePixel = 0
    PetListFrame.ScrollBarThickness = 3
    PetListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    PetListFrame.CanvasSize = UDim2.new(0, 0, 0, 60)
    PetListFrame.Parent = CreatePresetSection

    local PetListLayout = Instance.new("UIListLayout")
    PetListLayout.Padding = UDim.new(0, 2)
    PetListLayout.Parent = PetListFrame

    -- Dropdown untuk Edit Preset
    EditPresetDropdown = createDynamicDropdown(
        CreatePresetSection,
        UDim2.new(0, 10, 0, 147),
        "📂 Pilih Preset untuk Diedit/Dihapus",
        CreatePresetSection,
        239,
        weightScroll
    )

    SavePresetButton = Instance.new("TextButton")
    SavePresetButton.Size = UDim2.new(1, -20, 0, 22)
    SavePresetButton.Position = UDim2.new(0, 10, 0, 180)
    SavePresetButton.BackgroundColor3 = C.success
    SavePresetButton.BorderSizePixel = 0
    SavePresetButton.Font = Enum.Font.GothamBold
    SavePresetButton.Text = "💾 Simpan Preset"
    SavePresetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SavePresetButton.TextSize = 9
    SavePresetButton.Parent = CreatePresetSection

    local UICornerSave = Instance.new("UICorner")
    UICornerSave.CornerRadius = UDim.new(0, 4)
    UICornerSave.Parent = SavePresetButton

    DeletePresetButton = Instance.new("TextButton")
    DeletePresetButton.Size = UDim2.new(1, -20, 0, 22)
    DeletePresetButton.Position = UDim2.new(0, 10, 0, 207)
    DeletePresetButton.BackgroundColor3 = C.danger
    DeletePresetButton.BorderSizePixel = 0
    DeletePresetButton.Font = Enum.Font.GothamBold
    DeletePresetButton.Text = "🗑️ Hapus Preset"
    DeletePresetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    DeletePresetButton.TextSize = 9
    DeletePresetButton.Parent = CreatePresetSection

    local UICornerDelete = Instance.new("UICorner")
    UICornerDelete.CornerRadius = UDim.new(0, 4)
    UICornerDelete.Parent = DeletePresetButton

    -- ==================================================================
    -- SECTION: PET TARGET
    -- ==================================================================
    local TargetSection = createSection(weightScroll, "🎯 Pet Target", "petTarget")
    TargetSection.LayoutOrder = 2
    TargetSection.Size = UDim2.new(1, -10, 0, 172)

    TargetSearchBox = Instance.new("TextBox")
    TargetSearchBox.Size = UDim2.new(1, -20, 0, 22)
    TargetSearchBox.Position = UDim2.new(0, 10, 0, 28)
    TargetSearchBox.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    TargetSearchBox.BorderSizePixel = 0
    TargetSearchBox.Font = Enum.Font.Gotham
    TargetSearchBox.PlaceholderText = "🔍 Cari pet target..."
    TargetSearchBox.Text = ""
    TargetSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    TargetSearchBox.TextSize = 9
    TargetSearchBox.Parent = TargetSection

    local UICornerTargetSearch = Instance.new("UICorner")
    UICornerTargetSearch.CornerRadius = UDim.new(0, 4)
    UICornerTargetSearch.Parent = TargetSearchBox

    TargetListFrame = Instance.new("ScrollingFrame")
    TargetListFrame.Size = UDim2.new(1, -20, 0, 80)
    TargetListFrame.Position = UDim2.new(0, 10, 0, 55)
    TargetListFrame.BackgroundTransparency = 1
    TargetListFrame.BorderSizePixel = 0
    TargetListFrame.ScrollBarThickness = 3
    TargetListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    TargetListFrame.CanvasSize = UDim2.new(0, 0, 0, 80)
    TargetListFrame.Parent = TargetSection

    local TargetListLayout = Instance.new("UIListLayout")
    TargetListLayout.Padding = UDim.new(0, 2)
    TargetListLayout.Parent = TargetListFrame

    ScanButton = Instance.new("TextButton")
    ScanButton.Size = UDim2.new(1, -20, 0, 22)
    ScanButton.Position = UDim2.new(0, 10, 0, 140)
    ScanButton.BackgroundColor3 = C.accent
    ScanButton.BorderSizePixel = 0
    ScanButton.Font = Enum.Font.GothamBold
    ScanButton.Text = "🔍 Refresh List"
    ScanButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ScanButton.TextSize = 9
    ScanButton.Parent = TargetSection

    local UICornerScan = Instance.new("UICorner")
    UICornerScan.CornerRadius = UDim.new(0, 4)
    UICornerScan.Parent = ScanButton

    -- ==================================================================
    -- SECTION: PILIH TIM (DROPDOWN DINAMIS)
    -- ==================================================================
    local TeamSelectSection = createSection(weightScroll, "📈 Auto Leveling", "autoLeveling")
    TeamSelectSection.LayoutOrder = 3
    TeamSelectSection.Size = UDim2.new(1, -10, 0, 252)

    local LevelInput = Instance.new("TextBox")
    LevelInput.Size = UDim2.new(1, -20, 0, 22)
    LevelInput.Position = UDim2.new(0, 10, 0, 28)
    LevelInput.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    LevelInput.BorderSizePixel = 0
    LevelInput.Font = Enum.Font.Gotham
    LevelInput.PlaceholderText = "Target Level"
    LevelInput.Text = tostring(targetLevel)
    LevelInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    LevelInput.TextSize = 9
    LevelInput.Parent = TeamSelectSection

    local UICornerLevelInput = Instance.new("UICorner")
    UICornerLevelInput.CornerRadius = UDim.new(0, 4)
    UICornerLevelInput.Parent = LevelInput

    LevelInput.FocusLost:Connect(function()
        local newLevel = tonumber(LevelInput.Text)
        if newLevel and newLevel > 0 then
            targetLevel = newLevel
            config.targetLevel = newLevel
            saveConfig()
        else
            LevelInput.Text = tostring(targetLevel)
        end
    end)

    -- Dropdown Tim Leveling
    TeamPresetDropdown = createDynamicDropdown(
        TeamSelectSection,
        UDim2.new(0, 10, 0, 55),
        selectedTeamPreset and string.format("📂 %s", selectedTeamPreset) or "📂 Pilih Preset Tim Leveling",
        TeamSelectSection,
        252,
        weightScroll
    )

    makeInputRow(TeamSelectSection, 88, "Max Pet Target:", "maxNormalPetsPerSession", true, 1, 8)

    AdvLabel = Instance.new("TextLabel")
    AdvLabel.Size = UDim2.new(1, -20, 0, 22)
    AdvLabel.Position = UDim2.new(0, 10, 0, 109)
    AdvLabel.BackgroundTransparency = 1
    AdvLabel.Font = Enum.Font.GothamBold
    AdvLabel.Text = "🚀 Advanced Leveling"
    AdvLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    AdvLabel.TextSize = 11
    AdvLabel.TextXAlignment = Enum.TextXAlignment.Left
    AdvLabel.Parent = TeamSelectSection

    AdvancedToggleButton = Instance.new("TextButton")
    AdvancedToggleButton.Size = UDim2.new(1, -20, 0, 25)
    AdvancedToggleButton.Position = UDim2.new(0, 10, 0, 136)
    AdvancedToggleButton.BackgroundColor3 = isAdvancedLeveling and C.success or Color3.fromRGB(70, 70, 85)
    AdvancedToggleButton.BorderSizePixel = 0
    AdvancedToggleButton.Font = Enum.Font.GothamBold
    AdvancedToggleButton.Text = isAdvancedLeveling and "🚀 Advanced: ON" or "🚀 Advanced: OFF"
    AdvancedToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    AdvancedToggleButton.TextSize = 9
    AdvancedToggleButton.Parent = TeamSelectSection

    local UICornerAdvancedToggle = Instance.new("UICorner")
    UICornerAdvancedToggle.CornerRadius = UDim.new(0, 4)
    UICornerAdvancedToggle.Parent = AdvancedToggleButton

    local AdvancedLevelInput = Instance.new("TextBox")
    AdvancedLevelInput.Size = UDim2.new(1, -20, 0, 22)
    AdvancedLevelInput.Position = UDim2.new(0, 10, 0, 166)
    AdvancedLevelInput.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    AdvancedLevelInput.BorderSizePixel = 0
    AdvancedLevelInput.Font = Enum.Font.Gotham
    AdvancedLevelInput.PlaceholderText = "Advanced Target Level"
    AdvancedLevelInput.Text = tostring(advancedTargetLevel)
    AdvancedLevelInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    AdvancedLevelInput.TextSize = 9
    AdvancedLevelInput.Parent = TeamSelectSection

    local UICornerAdvancedLevel = Instance.new("UICorner")
    UICornerAdvancedLevel.CornerRadius = UDim.new(0, 4)
    UICornerAdvancedLevel.Parent = AdvancedLevelInput

    AdvancedLevelInput.FocusLost:Connect(function()
        local newLevel = tonumber(AdvancedLevelInput.Text)
        if newLevel and newLevel > 0 then
            advancedTargetLevel = newLevel
            config.advancedTargetLevel = newLevel
            saveConfig()
        else
            AdvancedLevelInput.Text = tostring(advancedTargetLevel)
        end
    end)

    -- Dropdown Advanced Preset
    AdvancedPresetDropdown = createDynamicDropdown(
        TeamSelectSection,
        UDim2.new(0, 10, 0, 193),
        selectedAdvancedPreset and string.format("📂 %s", selectedAdvancedPreset) or "📂 Pilih Preset Advanced",
        TeamSelectSection,
        252,
        weightScroll
    )

    -- ⭐ BARU: Input max pet/sesi
    makeInputRow(TeamSelectSection, 226, "Max pet Target:", "maxAdvancedPetsPerSession", true, 1, 8)
end -- BLOCK 8

-- shared: diisi di BLOCK 9 (UI SECTION: WEIGHT, MUTATION, KONTROL, POPULATE, EVENT HANDLERS)
local WeightToggleButton, MutationToggleButton, ToggleButton, populateDynamicDropdown,
    populatePetList, populateMutationList, populateTargetDropdown

do -- BLOCK 9: UI SECTION: WEIGHT, MUTATION, KONTROL, POPULATE, EVENT HANDLERS
    -- ==================================================================
    -- SECTION: AUTO WEIGHT (DROPDOWN DINAMIS)
    -- ==================================================================
    local WeightSection = createSection(weightScroll, "🐘 Auto Weight", "autoWeight")
    WeightSection.LayoutOrder = 4
    WeightSection.Size = UDim2.new(1, -10, 0, 150)

    WeightToggleButton = Instance.new("TextButton")
    WeightToggleButton.Size = UDim2.new(1, -20, 0, 28)
    WeightToggleButton.Position = UDim2.new(0, 10, 0, 28)
    WeightToggleButton.BackgroundColor3 = isAutoWeight and C.success or Color3.fromRGB(70, 70, 85)
    WeightToggleButton.BorderSizePixel = 0
    WeightToggleButton.Font = Enum.Font.GothamBold
    WeightToggleButton.Text = isAutoWeight and "🐘 Auto Weight: ON" or "🐘 Auto Weight: OFF"
    WeightToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    WeightToggleButton.TextSize = 10
    WeightToggleButton.Parent = WeightSection

    local UICornerWeightToggle = Instance.new("UICorner")
    UICornerWeightToggle.CornerRadius = UDim.new(0, 5)
    UICornerWeightToggle.Parent = WeightToggleButton

    local RainbowModeButton = Instance.new("TextButton")
    RainbowModeButton.Size = UDim2.new(1, -20, 0, 25)
    RainbowModeButton.Position = UDim2.new(0, 10, 0, 61)
    RainbowModeButton.BackgroundColor3 = rainbowMode and A.warning or Color3.fromRGB(60, 60, 75)
    RainbowModeButton.BorderSizePixel = 0
    RainbowModeButton.Font = Enum.Font.Gotham
    RainbowModeButton.Text = rainbowMode and "☑ Rainbow Elephant" or "☐ Rainbow Elephant"
    RainbowModeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    RainbowModeButton.TextSize = 9
    RainbowModeButton.Parent = WeightSection

    local UICornerRainbow = Instance.new("UICorner")
    UICornerRainbow.CornerRadius = UDim.new(0, 4)
    UICornerRainbow.Parent = RainbowModeButton

    -- Dropdown Weight Preset
    local WeightPresetDropdown = createDynamicDropdown(
        WeightSection,
        UDim2.new(0, 10, 0, 91),
        selectedWeightPreset and string.format("📂 %s", selectedWeightPreset) or "📂 Pilih Preset Auto Weight",
        WeightSection,
        150,
        weightScroll
    )

    -- ⭐ BARU: Input max pet per sesi
    makeInputRow(WeightSection, 124, "Max Pet Target:", "maxWeightPetsPerSession", true, 1, 8)

    -- Semua GUI yang ingin mengikuti warna rainbow
    local rainbowTargets = {
        RainbowModeButton,
    }

    -- ==================================================================
    -- SECTION: AUTO MUTATION (DROPDOWN DINAMIS)
    -- ==================================================================
    local MutationSection = createSection(weightScroll, "🧬 Auto Mutation", "autoMutation")
    MutationSection.LayoutOrder = 5
    MutationSection.Size = UDim2.new(1, -10, 0, 299)

    MutationToggleButton = Instance.new("TextButton")
    MutationToggleButton.Size = UDim2.new(1, -20, 0, 28)
    MutationToggleButton.Position = UDim2.new(0, 10, 0, 28)
    MutationToggleButton.BackgroundColor3 = isAutoMutation and C.success or Color3.fromRGB(70, 70, 85)
    MutationToggleButton.BorderSizePixel = 0
    MutationToggleButton.Font = Enum.Font.GothamBold
    MutationToggleButton.Text = isAutoMutation and "🧬 Auto Mutation: ON" or "🧬 Auto Mutation: OFF"
    MutationToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    MutationToggleButton.TextSize = 10
    MutationToggleButton.Parent = MutationSection

    local UICornerMutationToggle = Instance.new("UICorner")
    UICornerMutationToggle.CornerRadius = UDim.new(0, 5)
    UICornerMutationToggle.Parent = MutationToggleButton

    -- Dropdown Mutation Preset
    local MutationPresetDropdown = createDynamicDropdown(
        MutationSection,
        UDim2.new(0, 10, 0, 61),
        selectedMutationPreset and string.format("📂 %s", selectedMutationPreset) or "📂 Pilih Preset Tim Mutation",
        MutationSection,
        299,
        weightScroll
    )

    -- ⭐ BARU: Input max pet per sesi
    makeInputRow(MutationSection, 94, "Max Pet Target:", "maxMutationPetsPerSession", true, 1, 8)

    MutLabel = Instance.new("TextLabel")
    MutLabel.Size = UDim2.new(1, -20, 0, 22)
    MutLabel.Position = UDim2.new(0, 10, 0, 115)
    MutLabel.BackgroundTransparency = 1
    MutLabel.Font = Enum.Font.GothamBold
    MutLabel.Text = "❌ Mutasi yg tidak diinginkan:"
    MutLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    MutLabel.TextSize = 11
    MutLabel.TextXAlignment = Enum.TextXAlignment.Left
    MutLabel.Parent = MutationSection

    local MutationSearchBox = Instance.new("TextBox")
    MutationSearchBox.Size = UDim2.new(1, -20, 0, 22)
    MutationSearchBox.Position = UDim2.new(0, 10, 0, 142)
    MutationSearchBox.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    MutationSearchBox.BorderSizePixel = 0
    MutationSearchBox.Font = Enum.Font.Gotham
    MutationSearchBox.PlaceholderText = "🔍 Cari mutasi..."
    MutationSearchBox.Text = ""
    MutationSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    MutationSearchBox.TextSize = 9
    MutationSearchBox.Parent = MutationSection

    local UICornerMutationSearch = Instance.new("UICorner")
    UICornerMutationSearch.CornerRadius = UDim.new(0, 4)
    UICornerMutationSearch.Parent = MutationSearchBox

    local MutationListFrame = Instance.new("ScrollingFrame")
    MutationListFrame.Size = UDim2.new(1, -20, 0, 120)
    MutationListFrame.Position = UDim2.new(0, 10, 0, 169)
    MutationListFrame.BackgroundTransparency = 1
    MutationListFrame.BorderSizePixel = 0
    MutationListFrame.ScrollBarThickness = 3
    MutationListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    MutationListFrame.CanvasSize = UDim2.new(0, 0, 0, 120)
    MutationListFrame.Parent = MutationSection

    local MutationListLayout = Instance.new("UIListLayout")
    MutationListLayout.Padding = UDim.new(0, 2)
    MutationListLayout.Parent = MutationListFrame

    -- ==================================================================
    -- SECTION: PET SHARING
    -- ==================================================================
    local PetSharingSection = createSection(weightScroll, "🎁 Pet Sharing", "petSharing")
    PetSharingSection.LayoutOrder = 6  -- Ganti LayoutOrder ButtonSection jadi 7
    PetSharingSection.Size = UDim2.new(1, -10, 0, 418)

    -- Toggle Pet Sharing Mutation
    local mutationSharingBtn = Instance.new("TextButton")
    mutationSharingBtn.Size = UDim2.new(1, -20, 0, 25)
    mutationSharingBtn.Position = UDim2.new(0, 10, 0, 28)
    mutationSharingBtn.BackgroundColor3 = config.petSharingMutationEnabled and C.success or Color3.fromRGB(70, 70, 85)
    mutationSharingBtn.BorderSizePixel = 0
    mutationSharingBtn.Font = Enum.Font.GothamBold
    mutationSharingBtn.Text = config.petSharingMutationEnabled and "🧬 Pet Sharing Mutation: ON" or "🧬 Pet Sharing Mutation: OFF"
    mutationSharingBtn.TextColor3 = C.text
    mutationSharingBtn.TextSize = 9
    mutationSharingBtn.Parent = PetSharingSection
    Instance.new("UICorner", mutationSharingBtn).CornerRadius = UDim.new(0, 4)

    mutationSharingBtn.MouseButton1Click:Connect(function()
        if not isAutoMutation then
            StatusLabel.Text = "⚠️ Aktifkan Auto Mutation dulu!"
            return
        end
        config.petSharingMutationEnabled = not config.petSharingMutationEnabled
        mutationSharingBtn.Text = config.petSharingMutationEnabled and "🧬 Pet Sharing Mutation: ON" or "🧬 Pet Sharing Mutation: OFF"
        mutationSharingBtn.BackgroundColor3 = config.petSharingMutationEnabled and C.success or Color3.fromRGB(70, 70, 85)
        saveConfig()
    end)

    -- Toggle Pet Sharing Weight
    local weightSharingBtn = Instance.new("TextButton")
    weightSharingBtn.Size = UDim2.new(1, -20, 0, 25)
    weightSharingBtn.Position = UDim2.new(0, 10, 0, 58)
    weightSharingBtn.BackgroundColor3 = config.petSharingWeightEnabled and C.success or Color3.fromRGB(70, 70, 85)
    weightSharingBtn.BorderSizePixel = 0
    weightSharingBtn.Font = Enum.Font.GothamBold
    weightSharingBtn.Text = config.petSharingWeightEnabled and "🐘 Pet Sharing Weight: ON" or "🐘 Pet Sharing Weight: OFF"
    weightSharingBtn.TextColor3 = C.text
    weightSharingBtn.TextSize = 9
    weightSharingBtn.Parent = PetSharingSection
    Instance.new("UICorner", weightSharingBtn).CornerRadius = UDim.new(0, 4)

    weightSharingBtn.MouseButton1Click:Connect(function()
        if not isAutoWeight then
            StatusLabel.Text = "⚠️ Aktifkan Auto Weight dulu!"
            return
        end
        config.petSharingWeightEnabled = not config.petSharingWeightEnabled
        weightSharingBtn.Text = config.petSharingWeightEnabled and "🐘 Pet Sharing Weight: ON" or "🐘 Pet Sharing Weight: OFF"
        weightSharingBtn.BackgroundColor3 = config.petSharingWeightEnabled and C.success or Color3.fromRGB(70, 70, 85)
        saveConfig()
    end)

    -- Special Pet Label
    local specialLabel = Instance.new("TextLabel")
    specialLabel.Size = UDim2.new(1, -20, 0, 16)
    specialLabel.Position = UDim2.new(0, 10, 0, 88)
    specialLabel.Text = "⭐ Special Pet (pilih 1):"
    specialLabel.TextColor3 = C.text
    specialLabel.Font = Enum.Font.GothamBold
    specialLabel.TextSize = 9
    specialLabel.TextXAlignment = Enum.TextXAlignment.Left
    specialLabel.BackgroundTransparency = 1
    specialLabel.Parent = PetSharingSection

    -- Saved Pet Info
    local selectedSpecialLabel = Instance.new("TextLabel")
    selectedSpecialLabel.Size = UDim2.new(1, -20, 0, 14)
    selectedSpecialLabel.Position = UDim2.new(0, 10, 0, 109)
    selectedSpecialLabel.Text = config.petSharingSavedPetInfo and 
        string.format("Saved: %s", config.petSharingSavedPetInfo.PetType) or 
        "Belum ada pet dipilih"
    selectedSpecialLabel.TextColor3 = C.textDim
    selectedSpecialLabel.Font = Enum.Font.Gotham
    selectedSpecialLabel.TextSize = 7
    selectedSpecialLabel.TextXAlignment = Enum.TextXAlignment.Left
    selectedSpecialLabel.BackgroundTransparency = 1
    selectedSpecialLabel.Parent = PetSharingSection

    -- Search
    local specialSearch = Instance.new("TextBox")
    specialSearch.Size = UDim2.new(1, -20, 0, 22)
    specialSearch.Position = UDim2.new(0, 10, 0, 128)
    specialSearch.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    specialSearch.BorderSizePixel = 0
    specialSearch.Font = Enum.Font.Gotham
    specialSearch.PlaceholderText = "🔍 Cari pet..."
    specialSearch.Text = ""
    specialSearch.TextColor3 = C.text
    specialSearch.TextSize = 9
    specialSearch.Parent = PetSharingSection
    Instance.new("UICorner", specialSearch).CornerRadius = UDim.new(0, 4)

    -- List frame
    local specialListFrame = Instance.new("ScrollingFrame")
    specialListFrame.Size = UDim2.new(1, -20, 0, 90)
    specialListFrame.Position = UDim2.new(0, 10, 0, 155)
    specialListFrame.BackgroundTransparency = 1
    specialListFrame.BorderSizePixel = 0
    specialListFrame.ScrollBarThickness = 3
    specialListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    specialListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    specialListFrame.Parent = PetSharingSection

    local specialListLayout = Instance.new("UIListLayout")
    specialListLayout.Padding = UDim.new(0, 2)
    specialListLayout.Parent = specialListFrame

    -- Fungsi populate list
    local function populateSpecialPetList()
        for _, c in ipairs(specialListFrame:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end

        local search = specialSearch.Text:lower()
        local petsData = getPlayerPetData()
        if not petsData then return end

        local inventory = petsData.PetInventory.Data or {}
        local equippedUUIDs = getEquippedPets()
        local equippedSet = {}
        for _, uuid in ipairs(equippedUUIDs) do equippedSet[uuid] = true end

        local items = {}
        for uuid, _ in pairs(inventory) do
            local displayName = getPetDisplayName(uuid)
            local level = getPetLevel(uuid)
            local weight = getPetWeight(uuid)
            local isEquipped = equippedSet[uuid]

            if search == "" or displayName:lower():find(search) then
                table.insert(items, {
                    uuid = uuid,
                    displayName = displayName,
                    petType = getPetType(uuid),
                    mutation = getPetMutationName(uuid),
                    level = level,
                    weight = weight,
                    isEquipped = isEquipped,
                    isSelected = config.petSharingSavedPetInfo 
                        and config.petSharingSavedPetInfo.UUID == uuid,
                })
            end
        end

        table.sort(items, function(a, b)
            if a.isSelected ~= b.isSelected then return a.isSelected end
            if a.isEquipped ~= b.isEquipped then return a.isEquipped end
            return a.displayName < b.displayName
        end)

        local i = 0
        for _, item in ipairs(items) do
            i = i + 1
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -4, 0, 22)
            btn.BackgroundColor3 = item.isSelected and C.warning or (item.isEquipped and C.accent or Color3.fromRGB(65, 65, 80))
            btn.BorderSizePixel = 0
            btn.Font = Enum.Font.Gotham
            btn.Text = string.format("%s %s | %.2f kg | Lv.%d%s", 
                item.isSelected and "⭐" or (item.isEquipped and "🎯" or "○"),
                item.displayName, item.weight, item.level,
                item.isEquipped and " (Eq)" or ""
            )
            btn.TextColor3 = C.text
            btn.TextSize = 8
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.LayoutOrder = i
            btn.Parent = specialListFrame
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = UDim.new(0, 6)
            pad.Parent = btn

            btn.MouseButton1Click:Connect(function()
    local savedData = {
        UUID = item.uuid,
        PetType = item.petType,
        DisplayName = item.displayName,
        Mutation = item.mutation,
        Level = item.level,
    }

    -- Simpan ke yang sedang "aktif" diedit.
    -- Cara sederhana: simpan ke dua-duanya sekaligus,
    -- lalu user pilih tombol mana yang mau dipakai.
    config.petSharingWeightSavedInfo = savedData
    config.petSharingMutationSavedInfo = savedData
    config.petSharingSavedPetInfo = savedData  -- fallback

    saveConfig()
    selectedSpecialLabel.Text = string.format("Saved: %s", item.displayName)
    populateSpecialPetList()
end)
        end
    end

    specialSearch:GetPropertyChangedSignal("Text"):Connect(populateSpecialPetList)

    -- ====== DROPDOWN WEIGHT SHARING ======
local weightSharingLabel = Instance.new("TextLabel")
weightSharingLabel.Size = UDim2.new(1, -20, 0, 14)
weightSharingLabel.Position = UDim2.new(0, 10, 0, 250)
weightSharingLabel.Text = "🐘 Pet Sharing Weight:"
weightSharingLabel.TextColor3 = C.textDim
weightSharingLabel.Font = Enum.Font.Gotham
weightSharingLabel.TextSize = 8
weightSharingLabel.TextXAlignment = Enum.TextXAlignment.Left
weightSharingLabel.BackgroundTransparency = 1
weightSharingLabel.Parent = PetSharingSection

local weightSharingBtn = Instance.new("TextButton")
weightSharingBtn.Size = UDim2.new(1, -20, 0, 22)
weightSharingBtn.Position = UDim2.new(0, 10, 0, 269)
weightSharingBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
weightSharingBtn.BorderSizePixel = 0
weightSharingBtn.Font = Enum.Font.Gotham
weightSharingBtn.Text = config.petSharingWeightPet and ("🐘 " .. config.petSharingWeightPet) or "🐘 Pilih Pet Weight..."
weightSharingBtn.TextColor3 = C.text
weightSharingBtn.TextSize = 8
weightSharingBtn.TextXAlignment = Enum.TextXAlignment.Left
weightSharingBtn.Parent = PetSharingSection
Instance.new("UICorner", weightSharingBtn).CornerRadius = UDim.new(0, 4)
local wsPad = Instance.new("UIPadding")
wsPad.PaddingLeft = UDim.new(0, 8)
wsPad.Parent = weightSharingBtn

weightSharingBtn.MouseButton1Click:Connect(function()
    if not config.petSharingWeightSavedInfo then
        weightSharingBtn.Text = "⚠️ Pilih Special Pet dulu!"
        task.wait(1)
        weightSharingBtn.Text = config.petSharingWeightPet and ("🐘 " .. config.petSharingWeightPet) or "🐘 Pilih Pet Weight..."
        return
    end
    config.petSharingWeightPetUUID = config.petSharingWeightSavedInfo.UUID
    config.petSharingWeightPet = config.petSharingWeightSavedInfo.DisplayName
    weightSharingBtn.Text = "🐘 " .. config.petSharingWeightPet
    saveConfig()
end)

-- ====== DROPDOWN MUTATION SHARING ======
local mutationSharingPetLabel = Instance.new("TextLabel")
mutationSharingPetLabel.Size = UDim2.new(1, -20, 0, 14)
mutationSharingPetLabel.Position = UDim2.new(0, 10, 0, 296)
mutationSharingPetLabel.Text = "🧬 Pet Sharing Mutation:"
mutationSharingPetLabel.TextColor3 = C.textDim
mutationSharingPetLabel.Font = Enum.Font.Gotham
mutationSharingPetLabel.TextSize = 8
mutationSharingPetLabel.TextXAlignment = Enum.TextXAlignment.Left
mutationSharingPetLabel.BackgroundTransparency = 1
mutationSharingPetLabel.Parent = PetSharingSection

local mutationSharingBtnPet = Instance.new("TextButton")
mutationSharingBtnPet.Size = UDim2.new(1, -20, 0, 22)
mutationSharingBtnPet.Position = UDim2.new(0, 10, 0, 315)
mutationSharingBtnPet.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
mutationSharingBtnPet.BorderSizePixel = 0
mutationSharingBtnPet.Font = Enum.Font.Gotham
mutationSharingBtnPet.Text = config.petSharingMutationPet and ("🧬 " .. config.petSharingMutationPet) or "🧬 Pilih Pet Mutation..."
mutationSharingBtnPet.TextColor3 = C.text
mutationSharingBtnPet.TextSize = 8
mutationSharingBtnPet.TextXAlignment = Enum.TextXAlignment.Left
mutationSharingBtnPet.Parent = PetSharingSection
Instance.new("UICorner", mutationSharingBtnPet).CornerRadius = UDim.new(0, 4)
local msPad = Instance.new("UIPadding")
msPad.PaddingLeft = UDim.new(0, 8)
msPad.Parent = mutationSharingBtnPet

mutationSharingBtnPet.MouseButton1Click:Connect(function()
    if not config.petSharingMutationSavedInfo then
        mutationSharingBtnPet.Text = "⚠️ Pilih Special Pet dulu!"
        task.wait(1)
        mutationSharingBtnPet.Text = config.petSharingMutationPet and ("🧬 " .. config.petSharingMutationPet) or "🧬 Pilih Pet Mutation..."
        return
    end
    -- ⭐ Simpan UUID + display name
    config.petSharingMutationPetUUID = config.petSharingMutationSavedInfo.UUID
    config.petSharingMutationPet = config.petSharingMutationSavedInfo.DisplayName
    mutationSharingBtnPet.Text = "🧬 " .. config.petSharingMutationPet
    saveConfig()
end)

    -- Target Username Label
    local targetSharingLabel = Instance.new("TextLabel")
    targetSharingLabel.Size = UDim2.new(1, -20, 0, 14)
    targetSharingLabel.Position = UDim2.new(0, 10, 0, 342)
    targetSharingLabel.Text = "👤 Target Username:"
    targetSharingLabel.TextColor3 = C.textDim
    targetSharingLabel.Font = Enum.Font.Gotham
    targetSharingLabel.TextSize = 8
    targetSharingLabel.TextXAlignment = Enum.TextXAlignment.Left
    targetSharingLabel.BackgroundTransparency = 1
    targetSharingLabel.Parent = PetSharingSection

    -- Target Username Button
    local targetSharingBtn = Instance.new("TextButton")
    targetSharingBtn.Size = UDim2.new(1, -20, 0, 22)
    targetSharingBtn.Position = UDim2.new(0, 10, 0, 361)
    targetSharingBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    targetSharingBtn.BorderSizePixel = 0
    targetSharingBtn.Font = Enum.Font.Gotham
    targetSharingBtn.Text = config.petSharingTargetUsername and ("👤 " .. config.petSharingTargetUsername) or "👤 Pilih target..."
    targetSharingBtn.TextColor3 = C.text
    targetSharingBtn.TextSize = 8
    targetSharingBtn.TextXAlignment = Enum.TextXAlignment.Left
    targetSharingBtn.Parent = PetSharingSection
    Instance.new("UICorner", targetSharingBtn).CornerRadius = UDim.new(0, 4)
    local tsPad = Instance.new("UIPadding")
    tsPad.PaddingLeft = UDim.new(0, 8)
    tsPad.Parent = targetSharingBtn

    targetSharingBtn.MouseButton1Click:Connect(function()
        local names = getPlayerNames()
        if #names == 0 then
            targetSharingBtn.Text = "❌ Tidak ada player lain"
            task.wait(1)
            targetSharingBtn.Text = config.petSharingTargetUsername and ("👤 " .. config.petSharingTargetUsername) or "👤 Pilih target..."
            return
        end
        local currentIdx = 1
        if config.petSharingTargetUsername then
            for i, n in ipairs(names) do
                if n == config.petSharingTargetUsername then currentIdx = i + 1 break end
            end
        end
        if currentIdx > #names then currentIdx = 1 end
        config.petSharingTargetUsername = names[currentIdx]
        targetSharingBtn.Text = "👤 " .. names[currentIdx]
        saveConfig()
    end)

    -- Refresh Button
    local refreshPetSharingBtn = Instance.new("TextButton")
    refreshPetSharingBtn.Size = UDim2.new(1, -20, 0, 20)
    refreshPetSharingBtn.Position = UDim2.new(0, 10, 0, 388)
    refreshPetSharingBtn.BackgroundColor3 = C.accent
    refreshPetSharingBtn.BorderSizePixel = 0
    refreshPetSharingBtn.Font = Enum.Font.Gotham
    refreshPetSharingBtn.Text = "🔄 Refresh Pet List"
    refreshPetSharingBtn.TextColor3 = C.text
    refreshPetSharingBtn.TextSize = 7
    refreshPetSharingBtn.Parent = PetSharingSection
    Instance.new("UICorner", refreshPetSharingBtn).CornerRadius = UDim.new(0, 3)

    refreshPetSharingBtn.MouseButton1Click:Connect(populateSpecialPetList)

    -- Init list
    populateSpecialPetList()
    
    -- ==================================================================
    -- SECTION: KONTROL
    -- ==================================================================
    local ButtonSection = createSection(weightScroll)
    ButtonSection.LayoutOrder = 7
    ButtonSection.Size = UDim2.new(1, -10, 0, 69)

    ToggleButton = Instance.new("TextButton")
    ToggleButton.Size = UDim2.new(1, -20, 0, 30)
    ToggleButton.Position = UDim2.new(0, 10, 0, 10)
    ToggleButton.BackgroundColor3 = C.success
    ToggleButton.BorderSizePixel = 0
    ToggleButton.Font = Enum.Font.GothamBold
    ToggleButton.Text = "▶️ Mulai"
    ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleButton.TextSize = 10
    ToggleButton.Parent = ButtonSection

    local UICornerToggle = Instance.new("UICorner")
    UICornerToggle.CornerRadius = UDim.new(0, 5)
    UICornerToggle.Parent = ToggleButton

    StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size = UDim2.new(1, -20, 0, 14)
    StatusLabel.Position = UDim2.new(0, 10, 0, 45)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.Text = "Status: Idle"
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.TextSize = 8
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.Parent = ButtonSection

    -- ==================================================================
    -- POPULATE FUNCTIONS
    -- ==================================================================
    updateStatus = function()
        -- Hitung equipped pets (slot yang terpakai)
        local equippedPets = getEquippedPets()
        local equippedCount = #equippedPets

        -- Hitung total pet target yang masih perlu diproses
        local totalPending = 0
        if isAutoWeight then
            totalPending = #getPetsForWeight()
        elseif isAutoMutation then
            totalPending = #getPetsForMutation()
        elseif isAdvancedLeveling then
            totalPending = #getPetsForAdvanced()
        else
            totalPending = #getPetsForNormalLeveling()
        end

        -- Mode text
        local modeText = rainbowMode and "🌈" or "📊"

        -- Format status baru
        StatusLabel.Text = string.format(
            "%s Slot: %d/%d | Antrian: %d | Weight:%s Advanced:%s Mutation:%s",
            modeText,
            equippedCount,
            MAX_PET_SLOTS,
            totalPending,
            isAutoWeight and "✓" or "x",
            isAdvancedLeveling and "✓" or "x",
            isAutoMutation and "✓" or "x"
        )
    end

    -- Populate dropdown generic
    function populateDynamicDropdown(dropdown, selectedPreset, onSelect)
        -- Clear
        for _, child in pairs(dropdown.ListScroll:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        local presets = loadTeamPresets()
        local presetNames = {}
        for name in pairs(presets) do
            table.insert(presetNames, name)
        end
        table.sort(presetNames)

        for i, presetName in ipairs(presetNames) do
            local preset = presets[presetName]

            local validCount = 0
            for _, petInfo in ipairs(preset.pets) do
                if isPetValid(petInfo.UUID) then
                    validCount = validCount + 1
                end
            end

            local PresetButton = Instance.new("TextButton")
            PresetButton.Size = UDim2.new(1, -4, 0, dropdown.ItemHeight)
            PresetButton.BackgroundColor3 = selectedPreset == presetName and C.success or Color3.fromRGB(65, 65, 80)
            PresetButton.BorderSizePixel = 0
            PresetButton.Font = Enum.Font.Gotham
            PresetButton.Text = string.format("📁 %s (%d/%d)", presetName, validCount, #preset.pets)
            PresetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            PresetButton.TextSize = 8
            PresetButton.TextXAlignment = Enum.TextXAlignment.Left
            PresetButton.LayoutOrder = i
            PresetButton.ZIndex = 12
            PresetButton.Parent = dropdown.ListScroll

            local UICornerPreset = Instance.new("UICorner")
            UICornerPreset.CornerRadius = UDim.new(0, 3)
            UICornerPreset.Parent = PresetButton

            local Padding = Instance.new("UIPadding")
            Padding.PaddingLeft = UDim.new(0, 6)
            Padding.Parent = PresetButton

            PresetButton.MouseButton1Click:Connect(function()
                onSelect(presetName)
                dropdown.Close()
                updateStatus()
            end)
        end

        dropdown.UpdateSize()
    end

    -- Populate team preset dropdown
    local function populateTeamPresetDropdown()
        populateDynamicDropdown(TeamPresetDropdown, selectedTeamPreset, function(name)
            selectedTeamPreset = name
            config.selectedTeamPreset = name
            saveConfig()
            TeamPresetDropdown.HeaderButton.Text = string.format("📂 %s", name)
        end)
    end

    -- Populate weight preset dropdown
    local function populateWeightPresetDropdown()
        populateDynamicDropdown(WeightPresetDropdown, selectedWeightPreset, function(name)
            selectedWeightPreset = name
            config.selectedWeightPreset = name
            saveConfig()
            WeightPresetDropdown.HeaderButton.Text = string.format("📂 %s", name)
        end)
    end

    -- Populate mutation preset dropdown
    local function populateMutationPresetDropdown()
        populateDynamicDropdown(MutationPresetDropdown, selectedMutationPreset, function(name)
            selectedMutationPreset = name
            config.selectedMutationPreset = name
            saveConfig()
            MutationPresetDropdown.HeaderButton.Text = string.format("📂 %s", name)
        end)
    end

    -- Populate advanced preset dropdown
    local function populateAdvancedPresetDropdown()
        populateDynamicDropdown(AdvancedPresetDropdown, selectedAdvancedPreset, function(name)
            selectedAdvancedPreset = name
            config.selectedAdvancedPreset = name
            saveConfig()
            AdvancedPresetDropdown.HeaderButton.Text = string.format("📂 %s", name)
        end)
    end

    -- Populate pet list (untuk preset editor)
    function populatePetList()
        for _, child in pairs(PetListFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        local petsData = getPlayerPetData()
        if not petsData then return end

        local inventory = petsData.PetInventory.Data or {}
        local allPets = {}

        for petUUID, _ in pairs(inventory) do
            local displayName = getPetDisplayName(petUUID)
            local petLevel = getPetLevel(petUUID)
            local isSelected = table.find(tempPresetPets, petUUID) ~= nil

            if petSearchText == "" or displayName:lower():find(petSearchText:lower()) then
                table.insert(allPets, {
                    UUID = petUUID,
                    DisplayName = displayName,
                    Level = petLevel,
                    IsSelected = isSelected
                })
            end
        end

        table.sort(allPets, function(a, b)
            if a.IsSelected ~= b.IsSelected then return a.IsSelected
            else return a.DisplayName < b.DisplayName end
        end)

        for i, petInfo in ipairs(allPets) do
            local PetButton = Instance.new("TextButton")
            PetButton.Size = UDim2.new(1, 0, 0, 20)
            PetButton.BackgroundColor3 = petInfo.IsSelected and C.success or Color3.fromRGB(65, 65, 80)
            PetButton.BorderSizePixel = 0
            PetButton.Font = Enum.Font.Gotham
            PetButton.Text = petInfo.IsSelected and string.format("✓ %s (Lv.%d)", petInfo.DisplayName, petInfo.Level) or string.format("%s (Lv.%d)", petInfo.DisplayName, petInfo.Level)
            PetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            PetButton.TextSize = 8
            PetButton.Parent = PetListFrame

            local UICornerPet = Instance.new("UICorner")
            UICornerPet.CornerRadius = UDim.new(0, 3)
            UICornerPet.Parent = PetButton

            PetButton.MouseButton1Click:Connect(function()
                local index = table.find(tempPresetPets, petInfo.UUID)
                if index then
                    table.remove(tempPresetPets, index)
                else
                    if #tempPresetPets < MAX_PET_SLOTS then
                        table.insert(tempPresetPets, petInfo.UUID)
                    end
                end
                populatePetList()
            end)
        end

        local count = 0
        for _, child in pairs(PetListFrame:GetChildren()) do
            if child:IsA("TextButton") then
                count = count + 1
            end
        end
        PetListFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(count * 22, 50))
    end

    -- Populate edit preset dropdown - DENGAN TOGGLE UN-SELECT
    local function populateEditPresetDropdown()
        for _, child in pairs(EditPresetDropdown.ListScroll:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        local presets = loadTeamPresets()
        local presetNames = {}
        for name in pairs(presets) do
            table.insert(presetNames, name)
        end
        table.sort(presetNames)

        for i, presetName in ipairs(presetNames) do
            local preset = presets[presetName]

            local validCount = 0
            for _, petInfo in ipairs(preset.pets) do
                if isPetValid(petInfo.UUID) then
                    validCount = validCount + 1
                end
            end

            local PresetButton = Instance.new("TextButton")
            PresetButton.Size = UDim2.new(1, -4, 0, EditPresetDropdown.ItemHeight)
            PresetButton.BackgroundColor3 = editingPresetName == presetName and C.success or Color3.fromRGB(65, 65, 80)
            PresetButton.BorderSizePixel = 0
            PresetButton.Font = Enum.Font.Gotham
            PresetButton.Text = string.format("📁 %s (%d pet)", presetName, validCount)
            PresetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            PresetButton.TextSize = 8
            PresetButton.TextXAlignment = Enum.TextXAlignment.Left
            PresetButton.LayoutOrder = i
            PresetButton.ZIndex = 12
            PresetButton.Parent = EditPresetDropdown.ListScroll

            local UICornerPreset = Instance.new("UICorner")
            UICornerPreset.CornerRadius = UDim.new(0, 3)
            UICornerPreset.Parent = PresetButton

            local Padding = Instance.new("UIPadding")
            Padding.PaddingLeft = UDim.new(0, 6)
            Padding.Parent = PresetButton

            PresetButton.MouseButton1Click:Connect(function()
                -- ⭐ CEK: Jika preset yang sama diklik lagi → UNSELECT
                if editingPresetName == presetName then
                    -- Unselect
                    editingPresetName = nil
                    tempPresetPets = {}
                    PresetNameInput.Text = ""
                    EditPresetDropdown.HeaderButton.Text = "📂 Pilih Preset untuk Diedit/Dihapus"

                    -- Refresh pet list (hapus semua centang)
                    populatePetList()

                    -- Update status
                    StatusLabel.Text = "✏️ Preset unselected"

                    -- Update button appearance
                    PresetButton.BackgroundColor3 = Color3.fromRGB(65, 65, 80)

                    -- Auto close dropdown
                    EditPresetDropdown.Close()
                else
                    -- Select preset
                    editingPresetName = presetName
                    PresetNameInput.Text = presetName

                    -- Load pets dari preset
                    tempPresetPets = {}
                    for _, petInfo in ipairs(preset.pets) do
                        if isPetValid(petInfo.UUID) then
                            table.insert(tempPresetPets, petInfo.UUID)
                        end
                    end

                    -- Refresh pet list dengan pet yang sudah dipilih
                    populatePetList()

                    -- Update header text
                    EditPresetDropdown.HeaderButton.Text = string.format("📂 %s", presetName)

                    -- Update status
                    StatusLabel.Text = string.format("✏️ Preset '%s' dimuat (%d pet)", presetName, #tempPresetPets)

                    -- Update button appearance
                    PresetButton.BackgroundColor3 = C.success

                    -- Auto close dropdown
                    EditPresetDropdown.Close()
                end
            end)
        end

        EditPresetDropdown.UpdateSize()
    end

    -- Populate mutation list - DENGAN SELECTED DI ATAS + AUTO CLEAR SEARCH
    function populateMutationList()
        for _, child in pairs(MutationListFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        -- ⭐ Kumpulkan mutations dalam 2 kategori
        local selectedMutations = {}
        local unselectedMutations = {}

        for _, mutationName in ipairs(availableMutations) do
            -- Filter berdasarkan search text
            if mutationSearchText == "" or mutationName:lower():find(mutationSearchText:lower()) then
                local isSelected = table.find(unwantedMutations, mutationName) ~= nil

                if isSelected then
                    table.insert(selectedMutations, mutationName)
                else
                    table.insert(unselectedMutations, mutationName)
                end
            end
        end

        -- ⭐ Sort masing-masing kategori alphabetically
        table.sort(selectedMutations)
        table.sort(unselectedMutations)

        -- ⭐ Gabungkan: selected dulu, lalu unselected
        local allMutations = {}
        for _, name in ipairs(selectedMutations) do
            table.insert(allMutations, {Name = name, IsSelected = true})
        end
        for _, name in ipairs(unselectedMutations) do
            table.insert(allMutations, {Name = name, IsSelected = false})
        end

        -- Buat button untuk setiap mutation
        for i, mutationInfo in ipairs(allMutations) do
            local mutationName = mutationInfo.Name
            local isSelected = mutationInfo.IsSelected

            local MutationButton = Instance.new("TextButton")
            MutationButton.Size = UDim2.new(1, 0, 0, 20)
            MutationButton.BackgroundColor3 = isSelected and C.danger or Color3.fromRGB(65, 65, 80)
            MutationButton.BorderSizePixel = 0
            MutationButton.Font = Enum.Font.Gotham
            MutationButton.Text = mutationName
            MutationButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            MutationButton.TextSize = 8
            MutationButton.TextXAlignment = Enum.TextXAlignment.Center
            MutationButton.LayoutOrder = i
            MutationButton.Parent = MutationListFrame

            local UICorner = Instance.new("UICorner")
            UICorner.CornerRadius = UDim.new(0, 3)
            UICorner.Parent = MutationButton

            MutationButton.MouseButton1Click:Connect(function()
                local idx = table.find(unwantedMutations, mutationName)
                if idx then
                    table.remove(unwantedMutations, idx)
                else
                    table.insert(unwantedMutations, mutationName)
                end
                config.unwantedMutations = unwantedMutations
                saveConfig()

                -- ⭐ AUTO CLEAR SEARCH BAR
                mutationSearchText = ""
                MutationSearchBox.Text = ""

                -- ⭐ Refresh list (selected akan naik ke atas)
                populateMutationList()
            end)
        end

        -- Update canvas
        local count = #allMutations
        MutationListFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(count * 22, 50))
    end

    -- Scan target pets
    local function scanTargetPets()
        local petsData = getPlayerPetData()
        if not petsData then return {} end

        local inventory = petsData.PetInventory.Data or {}
        local petTypes = {}

        for petUUID, _ in pairs(inventory) do
            local petType = getPetType(petUUID)

            if not petTypes[petType] then
                petTypes[petType] = {}
            end

            table.insert(petTypes[petType], {
                UUID = petUUID,
                Level = getPetLevel(petUUID),
                Weight = getPetWeight(petUUID),
                MutationStatus = getMutationStatus(petUUID)
            })
        end

        return petTypes
    end

    -- Populate target dropdown (pet target)
    function populateTargetDropdown()
        for _, child in pairs(TargetListFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        local petTypes = scanTargetPets()
        local allPetTypes = {}

        for petType, petInstances in pairs(petTypes) do
            if targetSearchText == "" or petType:lower():find(targetSearchText:lower()) then
                local isSelected = table.find(selectedPetTypes, petType) ~= nil
                table.insert(allPetTypes, {PetType = petType, Instances = petInstances, Count = #petInstances, IsSelected = isSelected})
            end
        end

        table.sort(allPetTypes, function(a, b)
            if a.IsSelected ~= b.IsSelected then return a.IsSelected
            else return a.PetType < b.PetType end
        end)

        for i, petInfo in ipairs(allPetTypes) do
            local PetButton = Instance.new("TextButton")
            PetButton.Size = UDim2.new(1, 0, 0, 20)
            PetButton.BackgroundColor3 = petInfo.IsSelected and C.success or Color3.fromRGB(65, 65, 80)
            PetButton.BorderSizePixel = 0
            PetButton.Font = Enum.Font.Gotham
            PetButton.Text = petInfo.IsSelected and string.format("✓ %s (x%d)", petInfo.PetType, petInfo.Count) or string.format("%s (x%d)", petInfo.PetType, petInfo.Count)
            PetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            PetButton.TextSize = 8
            PetButton.Parent = TargetListFrame

            local UICornerTarget = Instance.new("UICorner")
            UICornerTarget.CornerRadius = UDim.new(0, 3)
            UICornerTarget.Parent = PetButton

            PetButton.MouseButton1Click:Connect(function()
                local typeIndex = table.find(selectedPetTypes, petInfo.PetType)

                if typeIndex then
                    table.remove(selectedPetTypes, typeIndex)
                    for j = #allSelectedPets, 1, -1 do
                        if getPetType(allSelectedPets[j]) == petInfo.PetType then
                            table.remove(allSelectedPets, j)
                        end
                    end
                else
                    table.insert(selectedPetTypes, petInfo.PetType)
                    for _, petInstance in ipairs(petInfo.Instances) do
                        if not table.find(allSelectedPets, petInstance.UUID) then
                            table.insert(allSelectedPets, petInstance.UUID)
                        end
                    end
                end

                config.selectedPetTypes = selectedPetTypes
                saveConfig()

                populateTargetDropdown()
                updateStatus()
            end)
        end

        local count = 0
        for _, child in pairs(TargetListFrame:GetChildren()) do
            if child:IsA("TextButton") then
                count = count + 1
            end
        end
        TargetListFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(count * 22, 50))
    end

    -- Fungsi untuk menerapkan warna ke semua target
    local function updateRainbowTargets()
        for _, target in ipairs(rainbowTargets) do
            if target and target:IsA("GuiObject") then
                target.BackgroundColor3 = A.warning
            end
        end
    end

    -- Memulai rainbow
    local function startRainbowUpdate()
        if rainbowTask then return end

        rainbowTask = task.spawn(function()
            while rainbowMode and not isGuiDestroyed do
                -- Ambil warna berikutnya
                A.warning = rainbowColors[colorIndex]

                -- Terapkan ke semua GUI
                updateRainbowTargets()

                -- Ke warna berikutnya
                colorIndex = colorIndex + 1

                if colorIndex > #rainbowColors then
                    colorIndex = 1
                end

                -- Ganti warna setiap 1 detik
                task.wait(1)
            end

            rainbowTask = nil
        end)
    end

    -- ==================================================================
    -- HOOK DROPDOWN TOGGLE UNTUK POPULATE
    -- ==================================================================
    TeamPresetDropdown.HeaderButton.MouseButton1Click:Connect(function()
        if not TeamPresetDropdown.IsOpen() then
            populateTeamPresetDropdown()
        end
    end)

    WeightPresetDropdown.HeaderButton.MouseButton1Click:Connect(function()
        if not WeightPresetDropdown.IsOpen() then
            populateWeightPresetDropdown()
        end
    end)

    MutationPresetDropdown.HeaderButton.MouseButton1Click:Connect(function()
        if not MutationPresetDropdown.IsOpen() then
            populateMutationPresetDropdown()
        end
    end)

    AdvancedPresetDropdown.HeaderButton.MouseButton1Click:Connect(function()
        if not AdvancedPresetDropdown.IsOpen() then
            populateAdvancedPresetDropdown()
        end
    end)

    EditPresetDropdown.HeaderButton.MouseButton1Click:Connect(function()
        if not EditPresetDropdown.IsOpen() then
            populateEditPresetDropdown()
        end
    end)

    -- ==================================================================
    -- EVENT HANDLERS
    -- ==================================================================
    SavePresetButton.MouseButton1Click:Connect(function()
        local presetName = PresetNameInput.Text

        if presetName == "" then 
            StatusLabel.Text = "⚠️ Masukkan nama preset!" 
            return 
        end

        if #tempPresetPets == 0 then 
            StatusLabel.Text = "⚠️ Pilih minimal 1 pet!" 
            return 
        end

        if editingPresetName and editingPresetName ~= presetName then
            deletePreset(editingPresetName)
        end

        saveTeamPreset(presetName, tempPresetPets)

        if editingPresetName then
            StatusLabel.Text = string.format("✅ Preset '%s' diupdate!", presetName)
        else
            StatusLabel.Text = string.format("✅ Preset '%s' disimpan!", presetName)
        end

        editingPresetName = nil
        PresetNameInput.Text = ""
        tempPresetPets = {}
        EditPresetDropdown.HeaderButton.Text = "📂 Pilih Preset untuk Diedit/Dihapus"

        -- ⭐ Refresh pet list (hapus centang)
        populatePetList()

        -- ⭐ Refresh dropdown list agar preset baru muncul
        populateEditPresetDropdown()
    end)

    DeletePresetButton.MouseButton1Click:Connect(function()
        if not editingPresetName then
            StatusLabel.Text = "⚠️ Pilih preset dulu!"
            return
        end

        deletePreset(editingPresetName)
        StatusLabel.Text = string.format("🗑️ Preset '%s' dihapus!", editingPresetName)

        -- ⭐ Reset editor
        editingPresetName = nil
        tempPresetPets = {}
        PresetNameInput.Text = ""
        EditPresetDropdown.HeaderButton.Text = "📂 Pilih Preset untuk Diedit/Dihapus"

        -- ⭐ Refresh pet list (hapus semua centang)
        populatePetList()
    end)

    WeightToggleButton.MouseButton1Click:Connect(function()
        isAutoWeight = not isAutoWeight
        config.isAutoWeight = isAutoWeight
        saveConfig()

        if isAutoWeight then
            WeightToggleButton.Text = "⚖️ Auto Weight: ON"
            WeightToggleButton.BackgroundColor3 = C.success
        else
            WeightToggleButton.Text = "⚖️ Auto Weight: OFF"
            WeightToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
    
            -- ⭐ Sync: Matikan Pet Sharing Weight juga
            if config.petSharingWeightEnabled then
                config.petSharingWeightEnabled = false
                saveConfig()
            end
        end
        updateStatus()
    end)

    AdvancedToggleButton.MouseButton1Click:Connect(function()
        isAdvancedLeveling = not isAdvancedLeveling
        config.isAdvancedLeveling = isAdvancedLeveling
        saveConfig()

        if isAdvancedLeveling then
            AdvancedToggleButton.Text = "🚀 Advanced: ON"
            AdvancedToggleButton.BackgroundColor3 = C.success
        else
            AdvancedToggleButton.Text = "🚀 Advanced: OFF"
            AdvancedToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
        end
        updateStatus()
    end)

    MutationToggleButton.MouseButton1Click:Connect(function()
        isAutoMutation = not isAutoMutation
        config.isAutoMutation = isAutoMutation
        saveConfig()

        if isAutoMutation then
            MutationToggleButton.Text = "🧬 Auto Mutation: ON"
            MutationToggleButton.BackgroundColor3 = C.success
        else
            MutationToggleButton.Text = "🧬 Auto Mutation: OFF"
            MutationToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
    
            -- ⭐ Sync: Matikan Pet Sharing Mutation juga
            if config.petSharingMutationEnabled then
                config.petSharingMutationEnabled = false
                saveConfig()
                -- Kalau ada referensi ke mutationSharingBtn, update juga
            end
        end
        updateStatus()
    end)

    -- Tombol Rainbow Mode
    RainbowModeButton.MouseButton1Click:Connect(function()
        rainbowMode = not rainbowMode
        config.rainbowMode = rainbowMode
        saveConfig()

        if rainbowMode then
            RainbowModeButton.Text = "☑ Rainbow Elephant"

            -- Terapkan warna sekarang
            A.warning = rainbowColors[colorIndex]
            updateRainbowTargets()

            -- Mulai loop
            startRainbowUpdate()
        else
            RainbowModeButton.Text = "☐ Rainbow Elephant"

            -- Kembalikan warna semua target
            for _, target in ipairs(rainbowTargets) do
                if target and target:IsA("GuiObject") then
                    target.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
                end
            end
        end

        updateStatus()
    end)

    -- Jika Rainbow Mode sudah aktif dari config saat script dijalankan
    if rainbowMode then
        A.warning = rainbowColors[colorIndex]
        updateRainbowTargets()
        startRainbowUpdate()
    end

    PetSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        petSearchText = PetSearchBox.Text
        populatePetList()
    end)

    TargetSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        targetSearchText = TargetSearchBox.Text
        populateTargetDropdown()
    end)

    MutationSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        mutationSearchText = MutationSearchBox.Text
        populateMutationList()
    end)

    ScanButton.MouseButton1Click:Connect(function()
        StatusLabel.Text = "Refreshing..."
        wait(0.1)
        populateTargetDropdown()
        updateStatus()
    end)
end -- BLOCK 9

-- shared: diisi di BLOCK 10 (MAIN LOGIC AUTO LEVELING, TAB SWITCHING, INITIAL SETUP)
local switchTab

do -- BLOCK 10: MAIN LOGIC AUTO LEVELING, TAB SWITCHING, INITIAL SETUP
    -- ==================================================================
    -- MAIN LOGIC - AUTO LEVELING
    -- ==================================================================
    ToggleButton.MouseButton1Click:Connect(function()
    if isLeveling then
        isLeveling = false
        ToggleButton.Text = "▶️ Mulai"
        ToggleButton.BackgroundColor3 = C.success
        updateStatus()
        return
    end

    if isRunning then
        StatusLabel.Text = "⚠️ Stop Auto Hatch dulu sebelum mulai Auto Leveling!"
        return
    end

    -- ⭐ GUARD: Cek Auto Mutation
    if AutoMutation_Shared and AutoMutation_Shared.state and AutoMutation_Shared.state.isRunning then
        StatusLabel.Text = "⚠️ Stop Auto Mutation dulu!"
        return
    end

        if not selectedTeamPreset then
            StatusLabel.Text = "⚠️ Pilih preset tim leveling!"
            return
        end

        if #allSelectedPets == 0 then
            StatusLabel.Text = "⚠️ Pilih pet target dulu!"
            return
        end

        if isAutoWeight and not selectedWeightPreset then
            StatusLabel.Text = "⚠️ Pilih preset auto weight!"
            return
        end

        if isAdvancedLeveling and not selectedAdvancedPreset then
            StatusLabel.Text = "⚠️ Pilih preset advanced!"
            return
        end

        if isAutoMutation and not selectedMutationPreset then
            StatusLabel.Text = "⚠️ Pilih preset mutation!"
            return
        end

        if isAutoMutation and #unwantedMutations == 0 then
            StatusLabel.Text = "⚠️ Pilih minimal 1 mutasi tidak diinginkan!"
            return
        end

        isLeveling = true
        startDiscordSession()
        ToggleButton.Text = "⏹️ Stop"
        ToggleButton.BackgroundColor3 = C.danger

        local function unequipAllPets()
            StatusLabel.Text = "🔄 Membersihkan semua slot..."
            local maxAttempts = 3
            local attempt = 0

            while attempt < maxAttempts and isAlive() do  -- ⭐ GANTI isLeveling → isAlive()
                local equippedPets = getEquippedPets()

                if #equippedPets == 0 then
                    return true
                end

                for _, petUUID in ipairs(equippedPets) do
                    -- ⭐ Cek sebelum unequip
                    if not isAlive() then return false end

                    pcall(function()
                        unequipPet(petUUID)
                    end)
                    wait(0.5)

                    -- ⭐ Cek setelah unequip
                    if not isAlive() then return false end
                end

                attempt = attempt + 1
                wait(2)
            end

            return #getEquippedPets() == 0
        end

        local function equipPetList(petList, label)
            for _, petUUID in ipairs(petList) do
                -- ⭐ Cek di setiap iterasi
                if not isAlive() then return end

                if isPetValid(petUUID) then
                    equipPet(petUUID)
                end
                wait(0.3)
            end
        end

        spawn(function()
            unequipAllPets()
            wait(2)

            -- ⭐ Cek setelah wait
            if not isAlive() then return end

            cleanupInvalidPets()

            -- PRIORITAS 1: AUTO WEIGHT
            if isAutoWeight then
                local weightLoopActive = true

                while isAlive() and weightLoopActive do  -- ⭐ GANTI
                    -- ⭐ Cek di awal loop
                    if not isAlive() then return end

                    cleanupInvalidPets()

                    -- ⭐ Cek alive
                    if not isAlive() then return end

                    if #allSelectedPets == 0 then
                        StatusLabel.Text = "⚠️ Semua pet target hilang!"
                        break
                    end

                    local weightTarget = getWeightTarget()
                    local levelTargetForWeight = getLevelTargetForWeight()

                    local weightPets = getPetsForWeight()

                    if #weightPets == 0 then
                        StatusLabel.Text = "✅ Semua base weight tercapai!"
                        isAutoWeight = false
                        config.isAutoWeight = false
                        saveConfig()
                        WeightToggleButton.Text = "⚖️ Auto Weight: OFF"
                        WeightToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
                        weightLoopActive = false
                        break
                    end

                    StatusLabel.Text = string.format("⚖️ %d pet butuh weight", #weightPets)

                    local levelTargets = {}
                    for _, petUUID in ipairs(weightPets) do
                        if getPetLevel(petUUID) < levelTargetForWeight then
                            table.insert(levelTargets, petUUID)
                        end
                    end

                    if #levelTargets > 0 then
                        unequipAllPets()

                        -- ⭐ Cek setelah unequip
                        if not isAlive() then return end

                        wait(1)

                        local teamUUIDs = getPresetUUIDs(selectedTeamPreset)
                        equipPetList(teamUUIDs, "Tim:")
                        wait(2)

                        local availableSlots = MAX_PET_SLOTS - #teamUUIDs
                        local userLimit = config.maxWeightPetsPerSession or 1
                        local toEquip = math.min(availableSlots, #levelTargets, userLimit)  -- ⭐ tambah userLimit
                                
                        local levelingEquippedPets = {}
                        local pendingLevelTargets = {}

                        for _, petUUID in ipairs(levelTargets) do
                            table.insert(pendingLevelTargets, petUUID)
                        end

                        for i = 1, toEquip do
                            if #pendingLevelTargets > 0 then
                                local petUUID = pendingLevelTargets[1]
                                table.remove(pendingLevelTargets, 1)
                                if isPetValid(petUUID) then
                                    equipPet(petUUID)
                                    table.insert(levelingEquippedPets, petUUID)
                                end
                                wait(0.5)
                            end
                        end

                        while isAlive() and #levelingEquippedPets > 0 do  -- ⭐ GANTI
                            for i = #levelingEquippedPets, 1, -1 do
                                -- ⭐ Cek di setiap iterasi for
                                if not isAlive() then return end

                                local petUUID = levelingEquippedPets[i]

                                if not isPetValid(petUUID) then
                                    table.remove(levelingEquippedPets, i)
                                    continue
                                end

                                if getPetLevel(petUUID) >= levelTargetForWeight then
                                    pcall(function() unequipPet(petUUID) end)
                                    table.remove(levelingEquippedPets, i)

                                    -- ⭐ TRACK DONE + TRIGGER WEBHOOK
                                    if sessionStats.active then
                                        sessionStats.progress.weight.done[petUUID] = true
                                        task.spawn(function() sendProgressWebhook() end)
                                    end

                                    if #pendingLevelTargets > 0 then
                                        local nextPet = pendingLevelTargets[1]
                                        table.remove(pendingLevelTargets, 1)
                                        if isPetValid(nextPet) and getPetLevel(nextPet) < levelTargetForWeight then
                                            equipPet(nextPet)
                                            table.insert(levelingEquippedPets, nextPet)
                                            wait(0.5)
                                        end
                                    end
                                end
                            end

                            local allLeveled = true
                            for _, petUUID in ipairs(levelTargets) do
                                if isPetValid(petUUID) and getPetLevel(petUUID) < levelTargetForWeight then
                                    allLeveled = false
                                    break
                                end
                            end

                            if allLeveled then break end
                            if #levelingEquippedPets == 0 and #pendingLevelTargets == 0 then break end

                                -- ⭐ Cek sebelum update status
                            if not isAlive() then return end

                            updateStatus()
                            wait(5)
                        end
                    end

                    -- Proses Weight
                    unequipAllPets()
                    wait(1)

                    local weightUUIDs = getPresetUUIDs(selectedWeightPreset)
                    equipPetList(weightUUIDs, "Weight:")
                    wait(2)

                    local readyForWeight = {}
                    for _, petUUID in ipairs(weightPets) do
                        if isPetValid(petUUID) and getPetLevel(petUUID) >= levelTargetForWeight then
                            table.insert(readyForWeight, petUUID)
                        end
                    end

                    if #readyForWeight > 0 then
                        local availableSlots = MAX_PET_SLOTS - #weightUUIDs
                        local userLimit = config.maxWeightPetsPerSession or 1
                        local toEquip = math.min(availableSlots, #readyForWeight, userLimit)

                        local weightEquippedPets = {}
                        local pendingWeightPets = {}

                        for _, petUUID in ipairs(readyForWeight) do
                            table.insert(pendingWeightPets, petUUID)
                        end

                        for i = 1, toEquip do
                            if #pendingWeightPets > 0 then
                                local petUUID = pendingWeightPets[1]
                                table.remove(pendingWeightPets, 1)
                                if isPetValid(petUUID) then
                                    equipPet(petUUID)
                                    table.insert(weightEquippedPets, petUUID)
                                end
                                wait(0.5)
                            end
                        end

                        while isAlive() and #weightEquippedPets > 0 do  -- ⭐ GANTI
                            for i = #weightEquippedPets, 1, -1 do
                                -- ⭐ Cek
                                if not isAlive() then return end
                                local petUUID = weightEquippedPets[i]

                                if not isPetValid(petUUID) then
                                    table.remove(weightEquippedPets, i)
                                    continue
                                end

                                if getPetWeight(petUUID) >= weightTarget then
                                    pcall(function() unequipPet(petUUID) end)
                                    table.remove(weightEquippedPets, i)
    
                                    -- ⭐ TRACK DONE + TRIGGER WEBHOOK
                                    if sessionStats.active then
                                        sessionStats.progress.weight.done[petUUID] = true
                                        task.spawn(function() sendProgressWebhook() end)
                                    end

                                    if #pendingWeightPets > 0 then
                                        local nextPet = pendingWeightPets[1]
                                        table.remove(pendingWeightPets, 1)
                                        if isPetValid(nextPet) and getPetLevel(nextPet) >= levelTargetForWeight then
                                            equipPet(nextPet)
                                            table.insert(weightEquippedPets, nextPet)
                                            wait(0.5)
                                        end
                                    end
                                elseif getPetLevel(petUUID) < levelTargetForWeight then
                                    pcall(function() unequipPet(petUUID) end)
                                    table.remove(weightEquippedPets, i)

                                    if #pendingWeightPets > 0 then
                                        local nextPet = pendingWeightPets[1]
                                        table.remove(pendingWeightPets, 1)
                                        if isPetValid(nextPet) and getPetLevel(nextPet) >= levelTargetForWeight then
                                            equipPet(nextPet)
                                            table.insert(weightEquippedPets, nextPet)
                                            wait(0.5)
                                        end
                                    end
                                end
                            end

                            local allWeightDone = true
                            for _, petUUID in ipairs(weightPets) do
                                if isPetValid(petUUID) and getPetWeight(petUUID) < weightTarget then
                                    allWeightDone = false
                                    break
                                end
                            end

                            if allWeightDone then
                                StatusLabel.Text = "✅ Semua base weight tercapai!"
                                isAutoWeight = false
                                config.isAutoWeight = false
                                saveConfig()
                                WeightToggleButton.Text = "⚖️ Auto Weight: OFF"
                                WeightToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
                                weightLoopActive = false
                                break
                            end

                            if #weightEquippedPets == 0 and #pendingWeightPets == 0 then
                                break
                            end

                            updateStatus()
                            wait(5)
                        end
                    end

                    wait(3)
                end
                -- ⭐ SETELAH AUTO WEIGHT SELESAI: Gift Pet Sharing
                if isAlive() and config.petSharingWeightEnabled then
                    StatusLabel.Text = "🎁 Gift pet sharing (weight)..."
                    giftSharingPet("weight")
                    task.wait(3)
                end
            end

            -- ⭐ Cek sebelum lanjut ke PRIORITAS 2
            if not isAlive() then return end

            -- PRIORITAS 2: AUTO MUTATION
            if isAutoMutation and isAlive() then  -- ⭐ GANTI
                local mutationLoopActive = true

                while isAlive() and mutationLoopActive do  -- ⭐ GANTI
                    -- ⭐ Cek
                    if not isAlive() then return end

                    cleanupInvalidPets()

                    if #allSelectedPets == 0 then
                        StatusLabel.Text = "⚠️ Semua pet target hilang!"
                        break
                    end

                    local mutationPets = getPetsForMutation()

                    if #mutationPets == 0 then
                        StatusLabel.Text = "🎉 Semua pet target sudah bermutasi diinginkan!"
                        isAutoMutation = false
                        config.isAutoMutation = false
                        saveConfig()
                        MutationToggleButton.Text = "🧬 Auto Mutation: OFF"
                        MutationToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
                        mutationLoopActive = false
                        break
                    end

                    StatusLabel.Text = string.format("🧬 %d pet perlu mutasi", #mutationPets)

                    unequipAllPets()
                    wait(2)

                    local mutationTeamUUIDs = getPresetUUIDs(selectedMutationPreset)
                    equipPetList(mutationTeamUUIDs, "Mutation Team:")
                    wait(3)

                    local availableSlots = MAX_PET_SLOTS - #mutationTeamUUIDs
                    local userLimit = config.maxMutationPetsPerSession or 1
                    local toEquip = math.min(availableSlots, #mutationPets, userLimit)

                    local equippedForMutation = {}
                    local pendingMutationList = {}

                    for _, petUUID in ipairs(mutationPets) do
                        table.insert(pendingMutationList, petUUID)
                    end

                    for i = 1, toEquip do
                        if #pendingMutationList > 0 then
                            local petUUID = pendingMutationList[1]
                            table.remove(pendingMutationList, 1)
                            if isPetValid(petUUID) then
                                equipPet(petUUID)
                                table.insert(equippedForMutation, petUUID)
                            end
                            wait(1)
                        end
                    end

                    wait(2)

                    while isAlive() and #equippedForMutation > 0 do  -- ⭐ GANTI
                        for i = #equippedForMutation, 1, -1 do
                            -- ⭐ Cek
                            if not isAlive() then return end
                            local petUUID = equippedForMutation[i]

                            if not isPetValid(petUUID) then
                                table.remove(equippedForMutation, i)
                                if #pendingMutationList > 0 then
                                    local nextPet = pendingMutationList[1]
                                    table.remove(pendingMutationList, 1)
                                    if isPetValid(nextPet) then
                                        equipPet(nextPet)
                                        table.insert(equippedForMutation, nextPet)
                                    end
                                end
                                continue
                            end

                            local petType = getPetType(petUUID)
                            local status, mutationName = getMutationStatus(petUUID)

                            if status == "desired" then
                                StatusLabel.Text = string.format("✅ %s dapat %s!", petType, mutationName)
                                pcall(function() unequipPet(petUUID) end)
                                table.remove(equippedForMutation, i)
    
                                -- ⭐ TRACK DONE + TRIGGER WEBHOOK
                                if sessionStats.active then
                                    sessionStats.progress.mutation.done[petUUID] = true
                                    task.spawn(function() sendProgressWebhook() end)
                                end
                                wait(1)

                                if #pendingMutationList > 0 then
                                    local nextPet = pendingMutationList[1]
                                    table.remove(pendingMutationList, 1)
                                    if isPetValid(nextPet) then
                                        equipPet(nextPet)
                                        table.insert(equippedForMutation, nextPet)
                                    end
                                    wait(1)
                                end
                            elseif status == "unwanted" then
                                StatusLabel.Text = string.format("⚠️ %s dapat %s, cleansing...", petType, mutationName)

                                local success, errMsg = false, nil
                                local ok, err = pcall(function()
                                    success, errMsg = useCleansingShard(petUUID)
                                end)

                                if not ok or not success then
                                    StatusLabel.Text = string.format("⚠️ Gagal cleansing %s", petType)
                                else
                                    StatusLabel.Text = string.format("✅ %s di-cleansing!", petType)
                                end

                                wait(3)
                            end
                        end

                        if #equippedForMutation == 0 and #pendingMutationList == 0 then
                            break
                        end

                        updateStatus()
                        wait(5)
                    end

                    wait(3)
                end
                -- ⭐ SETELAH AUTO MUTATION SELESAI: Gift Pet Sharing
                if isAlive() and config.petSharingMutationEnabled then
                    StatusLabel.Text = "🎁 Gift pet sharing (mutation)..."
                    giftSharingPet("mutation")
                    task.wait(3)
                end
            end

            -- ⭐ Cek sebelum lanjut ke PRIORITAS 3
            if not isAlive() then return end

            -- PRIORITAS 3: NORMAL LEVELING
            if isAlive() then  -- ⭐ GANTI
                cleanupInvalidPets()

                local normalPets = getPetsForNormalLeveling()

                if #normalPets > 0 then
                    StatusLabel.Text = string.format("📈 Leveling normal (%d pet)...", #normalPets)

                    unequipAllPets()
                    wait(1)

                    local teamUUIDs = getPresetUUIDs(selectedTeamPreset)
                    equipPetList(teamUUIDs, "Tim:")
                    wait(2)

                    local availableSlots = MAX_PET_SLOTS - #teamUUIDs
                    local userLimit = config.maxNormalPetsPerSession or 1
                    local toEquip = math.min(availableSlots, #normalPets, userLimit)

                    local normalEquippedPets = {}
                    local pendingNormalList = {}

                    for _, petUUID in ipairs(normalPets) do
                        table.insert(pendingNormalList, petUUID)
                    end

                    for i = 1, toEquip do
                        if #pendingNormalList > 0 then
                            local petUUID = pendingNormalList[1]
                            table.remove(pendingNormalList, 1)
                            if isPetValid(petUUID) then
                                equipPet(petUUID)
                                table.insert(normalEquippedPets, petUUID)
                            end
                            wait(0.5)
                        end
                    end

                    while isAlive() and #normalEquippedPets > 0 do  -- ⭐ GANTI
                        for i = #normalEquippedPets, 1, -1 do
                            -- ⭐ Cek
                            if not isAlive() then return end
                            local petUUID = normalEquippedPets[i]

                            if not isPetValid(petUUID) then
                                table.remove(normalEquippedPets, i)
                                continue
                            end

                            if getPetLevel(petUUID) >= targetLevel then
                                pcall(function() unequipPet(petUUID) end)
                                table.remove(normalEquippedPets, i)
    
                                -- ⭐ TRACK DONE + TRIGGER WEBHOOK
                                if sessionStats.active then
                                    sessionStats.progress.normal.done[petUUID] = true
                                    task.spawn(function() sendProgressWebhook() end)
                                end
                                        
                                if #pendingNormalList > 0 then
                                    local nextPet = pendingNormalList[1]
                                    table.remove(pendingNormalList, 1)
                                    if isPetValid(nextPet) and getPetLevel(nextPet) < targetLevel then
                                        equipPet(nextPet)
                                        table.insert(normalEquippedPets, nextPet)
                                        wait(0.5)
                                    end
                                end
                            end
                        end

                        local allNormalDone = true
                        for _, petUUID in ipairs(normalPets) do
                            if isPetValid(petUUID) and getPetLevel(petUUID) < targetLevel then
                                allNormalDone = false
                                break
                            end
                        end

                        if allNormalDone then break end
                        if #normalEquippedPets == 0 and #pendingNormalList == 0 then break end

                        updateStatus()
                        wait(3)
                    end
                end
            end
            -- ⭐ Cek sebelum lanjut ke PRIORITAS 4
            if not isAlive() then return end

            -- PRIORITAS 4: ADVANCED LEVELING
            if isAdvancedLeveling and isAlive() then  -- ⭐ GANTI
                cleanupInvalidPets()

                local advancedPets = getPetsForAdvanced()

                if #advancedPets > 0 then
                    StatusLabel.Text = string.format("🚀 Advanced leveling (%d pet)...", #advancedPets)

                    unequipAllPets()
                    if not isAlive() then return end

                    wait(1)

                    local advancedUUIDs = getPresetUUIDs(selectedAdvancedPreset)
                    equipPetList(advancedUUIDs, "Advanced:")
                    wait(3)

                    local availableSlots = MAX_PET_SLOTS - #advancedUUIDs
                    local userLimit = config.maxAdvancedPetsPerSession or 1
                    local toEquip = math.min(availableSlots, #advancedPets, userLimit)

                    local advancedEquippedPets = {}
                    local pendingAdvancedList = {}

                    for _, petUUID in ipairs(advancedPets) do
                        table.insert(pendingAdvancedList, petUUID)
                    end

                    for i = 1, toEquip do
                        if #pendingAdvancedList > 0 then
                            local petUUID = pendingAdvancedList[1]
                            table.remove(pendingAdvancedList, 1)
                            if isPetValid(petUUID) then
                                equipPet(petUUID)
                                table.insert(advancedEquippedPets, petUUID)
                            end
                            wait(0.5)
                        end
                    end

                    while isAlive() and #advancedEquippedPets > 0 do  -- ⭐ GANTI
                        for i = #advancedEquippedPets, 1, -1 do
                            -- ⭐ Cek
                            if not isAlive() then return end
                            local petUUID = advancedEquippedPets[i]

                            if not isPetValid(petUUID) then
                                table.remove(advancedEquippedPets, i)
                                continue
                            end

                            if getPetLevel(petUUID) >= advancedTargetLevel then
                                pcall(function() unequipPet(petUUID) end)
                                table.remove(advancedEquippedPets, i)
    
                                -- ⭐ TRACK DONE + TRIGGER WEBHOOK
                                if sessionStats.active then
                                    sessionStats.progress.advanced.done[petUUID] = true
                                    task.spawn(function() sendProgressWebhook() end)
                                end

                                if #pendingAdvancedList > 0 then
                                    local nextPet = pendingAdvancedList[1]
                                    table.remove(pendingAdvancedList, 1)
                                    if isPetValid(nextPet) and getPetLevel(nextPet) < advancedTargetLevel then
                                        equipPet(nextPet)
                                        table.insert(advancedEquippedPets, nextPet)
                                        wait(0.5)
                                    end
                                end
                            end
                        end

                        local allAdvancedDone = true
                        for _, petUUID in ipairs(advancedPets) do
                            if isPetValid(petUUID) and getPetLevel(petUUID) < advancedTargetLevel then
                                allAdvancedDone = false
                                break
                            end
                        end

                        if allAdvancedDone then break end

                        if #advancedEquippedPets == 0 and #pendingAdvancedList == 0 then
                            local stillNeed = {}
                            for _, petUUID in ipairs(advancedPets) do
                                if isPetValid(petUUID) and getPetLevel(petUUID) < advancedTargetLevel then
                                    table.insert(stillNeed, petUUID)
                                end
                            end

                            if #stillNeed > 0 then
                                for _, petUUID in ipairs(stillNeed) do
                                    table.insert(pendingAdvancedList, petUUID)
                                end

                                local reEquip = math.min(availableSlots, #pendingAdvancedList)
                                for i = 1, reEquip do
                                    if #pendingAdvancedList > 0 then
                                        local petUUID = pendingAdvancedList[1]
                                        table.remove(pendingAdvancedList, 1)
                                        if isPetValid(petUUID) then
                                            equipPet(petUUID)
                                            table.insert(advancedEquippedPets, petUUID)
                                        end
                                        wait(0.5)
                                    end
                                end
                            else
                                break
                            end
                        end

                        if not isAlive() then return end

                        updateStatus()
                        wait(5)
                    end
                end
            end

            -- ⭐ Cek sebelum selesai (hanya jika GUI destroyed)
            if isGuiDestroyed then return end

            -- SELESAI
            StatusLabel.Text = "🎉 Semua proses selesai!"
            isLeveling = false
            ToggleButton.Text = "▶️ Mulai"
            ToggleButton.BackgroundColor3 = C.success
            updateStatus()
        end)
    end)

    -- ==================================================================
    -- TAB SWITCHING
    -- ==================================================================
    function switchTab(tabName)
        defaultView.Visible = false
        for _, f in pairs(tabFrames) do
            f.Visible = false
        end
        for _, btn in pairs(tabBtns) do
            btn.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
            btn.TextColor3 = C.textDim
        end

        if tabFrames[tabName] then
            tabFrames[tabName].Visible = true
            tabBtns[tabName].BackgroundColor3 = C.accent
            tabBtns[tabName].TextColor3 = C.text
            activeTab = tabName
        end
    end

    for _, tab in ipairs(tabs) do
        tabBtns[tab.name].MouseButton1Click:Connect(function()
            switchTab(tab.name)
        end)
    end

    -- ==================================================================
    -- INITIAL SETUP
    -- ==================================================================
    local function loadAvailableMutations()
        local mutations = {}
        local registry = safeRequire(ReplicatedStorage.Data.PetRegistry.PetMutationRegistry)

        if registry and registry.PetMutationRegistry then
            for mutationName, _ in pairs(registry.PetMutationRegistry) do
                if mutationName ~= "Normal" and mutationName ~= "Rideable" then
                    table.insert(mutations, mutationName)
                end
            end
        end

        table.sort(mutations)
        return mutations
    end

    availableMutations = loadAvailableMutations()

    -- Populate UI
    populatePetList()
    populateMutationList()
    populateTargetDropdown()
    updateStatus()

    -- Auto-load selected pet types dari config
    if config.selectedPetTypes and #config.selectedPetTypes > 0 then
        for _, petType in ipairs(config.selectedPetTypes) do
            local petsData = getPlayerPetData()
            if petsData then
                local inventory = petsData.PetInventory.Data or {}
                for petUUID, _ in pairs(inventory) do
                    if getPetType(petUUID) == petType then
                        if not table.find(allSelectedPets, petUUID) then
                            table.insert(allSelectedPets, petUUID)
                        end
                    end
                end
            end
        end
    end
        print("✅ AoneHub Auto Leveling loaded! Config:", SAVE_FILE)
end -- BLOCK 10

-- [PATCH 2B-FIX] Kill switch — pakai _G saja, tidak tambah local
task.defer(function()
    -- ⭐ Simpan instance ID milik instance INI ke _G khusus
    _G.AoneHub_MySaveId = _G.AoneHub_InstanceId
    
    _G.AoneHub_MainCleanup = function()
        -- Cek: masih instance aktif?
        if _G.AoneHub_MySaveId ~= _G.AoneHub_InstanceId then
            return
        end
        
        -- Set flag via _G (tidak bisa akses local isRunning dll dari sini!)
        -- ⚠️ Karena isRunning, isLeveling, dll adalah local di scope ini,
        -- kita HARUS akses lewat closure. Tapi closure tetap tidak menambah
        -- local slot di parent scope — hanya di scope task.defer ini.
        if _G.AoneHub_SetFlag then
            pcall(_G.AoneHub_SetFlag, "isGuiDestroyed", true)
            pcall(_G.AoneHub_SetFlag, "isLeveling", false)
            pcall(_G.AoneHub_SetFlag, "isRunning", false)
            pcall(_G.AoneHub_SetFlag, "isGiftPetRunning", false)
            pcall(_G.AoneHub_SetFlag, "giftPetUserStarted", false)
            pcall(_G.AoneHub_SetFlag, "isAutoShovelRunning", false)
            pcall(_G.AoneHub_SetFlag, "isAutoCollectRunning", false)
            pcall(_G.AoneHub_SetFlag, "rainbowMode", false)
        end
        
        if AutoMutation_Shared and AutoMutation_Shared.state then
            AutoMutation_Shared.state.isRunning = false
        end
        if AutoBuyBackend and AutoBuyBackend.stop then
            pcall(AutoBuyBackend.stop)
        end
        
        local gui = playerGui:FindFirstChild("AoneHub")
        if gui then pcall(function() gui:Destroy() end) end
    end
end)

-- ⭐ Expose setter untuk flag supaya kill switch bisa akses
-- (didefinisikan sebagai function, bukan local variable)
_G.AoneHub_SetFlag = function(flagName, value)
    if flagName == "isGuiDestroyed" then isGuiDestroyed = value
    elseif flagName == "isLeveling" then isLeveling = value
    elseif flagName == "isRunning" then isRunning = value
    elseif flagName == "isGiftPetRunning" then isGiftPetRunning = value
    elseif flagName == "giftPetUserStarted" then giftPetUserStarted = value
    elseif flagName == "isAutoShovelRunning" then isAutoShovelRunning = value
    elseif flagName == "isAutoCollectRunning" then isAutoCollectRunning = value
    elseif flagName == "rainbowMode" then rainbowMode = value
    end
end

-- shared: diisi di BLOCK 11 (TAB HATCH)
local statusLabel, refreshEggList, refreshUnwantedList, populateMutationhaList

do -- BLOCK 11: TAB HATCH
    -- ==================================================================
    -- TAB HATCH
    -- ==================================================================
    local hatchTab = tabFrames["Hatch"]

    local hatchScroll = Instance.new("ScrollingFrame")
    hatchScroll.Size = UDim2.new(1, -10, 1, -10)
    hatchScroll.Position = UDim2.new(0, 5, 0, 5)
    hatchScroll.BackgroundTransparency = 1
    hatchScroll.BorderSizePixel = 0
    hatchScroll.ScrollBarThickness = 4
    hatchScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    hatchScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    hatchScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y  -- Auto size
    hatchScroll.Parent = hatchTab

    local hatchLayout = Instance.new("UIListLayout")
    hatchLayout.Padding = UDim.new(0, 6)
    hatchLayout.SortOrder = Enum.SortOrder.LayoutOrder
    hatchLayout.Parent = hatchScroll

    local MonitorSection = createSection(hatchScroll, "📊 Hatch Monitoring", "monitorPreset")
    MonitorSection.LayoutOrder = 1

    -- Wadah isi (AutomaticSize) supaya tinggi section ikut isi, bukan angka tetap.
    local MonitorContent = Instance.new("Frame")
    MonitorContent.Size = UDim2.new(1, -20, 0, 0)
    MonitorContent.Position = UDim2.new(0, 10, 0, 28)
    MonitorContent.BackgroundTransparency = 1
    MonitorContent.AutomaticSize = Enum.AutomaticSize.Y
    MonitorContent.Parent = MonitorSection

    local MonitorContentLayout = Instance.new("UIListLayout")
    MonitorContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    MonitorContentLayout.Padding = UDim.new(0, 4)
    MonitorContentLayout.Parent = MonitorContent

    -- Sinkronkan tinggi MonitorSection (lewat sectionMeta) tiap kali isi MonitorContent berubah.
    local function syncMonitorSectionHeight()
        local meta = sectionMeta[MonitorSection]
        local totalHeight = 28 + 8 + MonitorContent.AbsoluteSize.Y + 8
        if meta then
            meta.expandedHeight = totalHeight
            if meta.expanded then
                MonitorSection.Size = UDim2.new(1, -10, 0, totalHeight)
            end
        else
            MonitorSection.Size = UDim2.new(1, -10, 0, totalHeight)
        end
    end
    MonitorContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncMonitorSectionHeight)
    task.defer(syncMonitorSectionHeight)

    monitorLabels.profileLabel = Instance.new("TextLabel")
    monitorLabels.profileLabel.Size = UDim2.new(1, 0, 0, 0)
    monitorLabels.profileLabel.AutomaticSize = Enum.AutomaticSize.Y
    monitorLabels.profileLabel.BackgroundTransparency = 1
    monitorLabels.profileLabel.Font = Enum.Font.Code
    monitorLabels.profileLabel.TextSize = 9
    monitorLabels.profileLabel.TextColor3 = C.text
    monitorLabels.profileLabel.TextXAlignment = Enum.TextXAlignment.Left
    monitorLabels.profileLabel.TextYAlignment = Enum.TextYAlignment.Top
    monitorLabels.profileLabel.TextWrapped = true
    monitorLabels.profileLabel.LayoutOrder = 1
    monitorLabels.profileLabel.Text = "Loading..."
    monitorLabels.profileLabel.Parent = MonitorContent

    monitorLabels.teamsLabel = Instance.new("TextLabel")
    monitorLabels.teamsLabel.Size = UDim2.new(1, 0, 0, 0)
    monitorLabels.teamsLabel.AutomaticSize = Enum.AutomaticSize.Y
    monitorLabels.teamsLabel.BackgroundTransparency = 1
    monitorLabels.teamsLabel.Font = Enum.Font.Code
    monitorLabels.teamsLabel.TextSize = 9
    monitorLabels.teamsLabel.TextColor3 = C.text
    monitorLabels.teamsLabel.TextXAlignment = Enum.TextXAlignment.Left
    monitorLabels.teamsLabel.TextYAlignment = Enum.TextYAlignment.Top
    monitorLabels.teamsLabel.TextWrapped = true
    monitorLabels.teamsLabel.LayoutOrder = 2
    monitorLabels.teamsLabel.Text = "Loading..."
    monitorLabels.teamsLabel.Parent = MonitorContent

    monitorLabels.huntLabel = Instance.new("TextLabel")
    monitorLabels.huntLabel.Size = UDim2.new(1, 0, 0, 0)
    monitorLabels.huntLabel.AutomaticSize = Enum.AutomaticSize.Y
    monitorLabels.huntLabel.BackgroundTransparency = 1
    monitorLabels.huntLabel.Font = Enum.Font.Code
    monitorLabels.huntLabel.TextSize = 9
    monitorLabels.huntLabel.TextColor3 = C.text
    monitorLabels.huntLabel.TextXAlignment = Enum.TextXAlignment.Left
    monitorLabels.huntLabel.TextYAlignment = Enum.TextYAlignment.Top
    monitorLabels.huntLabel.TextWrapped = true
    monitorLabels.huntLabel.LayoutOrder = 3
    monitorLabels.huntLabel.Text = "Loading..."
    monitorLabels.huntLabel.Parent = MonitorContent

    monitorLabels.eggLabel = Instance.new("TextLabel")
    monitorLabels.eggLabel.Size = UDim2.new(1, 0, 0, 0)
    monitorLabels.eggLabel.AutomaticSize = Enum.AutomaticSize.Y
    monitorLabels.eggLabel.BackgroundTransparency = 1
    monitorLabels.eggLabel.Font = Enum.Font.Code
    monitorLabels.eggLabel.TextSize = 9
    monitorLabels.eggLabel.TextColor3 = C.text
    monitorLabels.eggLabel.TextXAlignment = Enum.TextXAlignment.Left
    monitorLabels.eggLabel.TextYAlignment = Enum.TextYAlignment.Top
    monitorLabels.eggLabel.TextWrapped = true
    monitorLabels.eggLabel.LayoutOrder = 4
    monitorLabels.eggLabel.Text = "Loading..."
    monitorLabels.eggLabel.Parent = MonitorContent

    monitorLabels.hatchLabel = Instance.new("TextLabel")
    monitorLabels.hatchLabel.Size = UDim2.new(1, 0, 0, 0)
    monitorLabels.hatchLabel.AutomaticSize = Enum.AutomaticSize.Y
    monitorLabels.hatchLabel.BackgroundTransparency = 1
    monitorLabels.hatchLabel.Font = Enum.Font.Code
    monitorLabels.hatchLabel.TextSize = 9
    monitorLabels.hatchLabel.TextColor3 = C.text
    monitorLabels.hatchLabel.TextXAlignment = Enum.TextXAlignment.Left
    monitorLabels.hatchLabel.TextYAlignment = Enum.TextYAlignment.Top
    monitorLabels.hatchLabel.TextWrapped = true
    monitorLabels.hatchLabel.LayoutOrder = 5
    monitorLabels.hatchLabel.Text = "Loading..."
    monitorLabels.hatchLabel.Parent = MonitorContent

    monitorLabels.timestamp = Instance.new("TextLabel")
    monitorLabels.timestamp.Size = UDim2.new(1, 0, 0, 14)
    monitorLabels.timestamp.BackgroundTransparency = 1
    monitorLabels.timestamp.Font = Enum.Font.Gotham
    monitorLabels.timestamp.TextSize = 7
    monitorLabels.timestamp.TextColor3 = C.textDim
    monitorLabels.timestamp.TextXAlignment = Enum.TextXAlignment.Left
    monitorLabels.timestamp.LayoutOrder = 6
    monitorLabels.timestamp.Text = "🕐 Belum ada data"
    monitorLabels.timestamp.Parent = MonitorContent

    local refreshMonitorBtn = Instance.new("TextButton")
    refreshMonitorBtn.Size = UDim2.new(1, 0, 0, 22)
    refreshMonitorBtn.BackgroundColor3 = C.accent
    refreshMonitorBtn.BorderSizePixel = 0
    refreshMonitorBtn.Font = Enum.Font.GothamBold
    refreshMonitorBtn.Text = "🔄 Refresh Monitor"
    refreshMonitorBtn.TextColor3 = C.text
    refreshMonitorBtn.TextSize = 9
    refreshMonitorBtn.LayoutOrder = 7
    refreshMonitorBtn.Parent = MonitorContent
    Instance.new("UICorner", refreshMonitorBtn).CornerRadius = UDim.new(0, 4)
    refreshMonitorBtn.MouseButton1Click:Connect(function()
        refreshMonitor()
    end)

    local ConfigSection = createSection(hatchScroll, "⚙️ Configuration", "configPreset")
    ConfigSection.LayoutOrder = 2
    ConfigSection.Size = UDim2.new(1, -10, 0, 449)

    PresLabel = Instance.new("TextLabel")
    PresLabel.Size = UDim2.new(1, -20, 0, 22)
    PresLabel.Position = UDim2.new(0, 10, 0, 28)
    PresLabel.BackgroundTransparency = 1
    PresLabel.Font = Enum.Font.GothamBold
    PresLabel.Text = "🐣 Tim Preset"
    PresLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    PresLabel.TextSize = 11
    PresLabel.TextXAlignment = Enum.TextXAlignment.Left
    PresLabel.Parent = ConfigSection

    -- Dropdown Tim Leveling
    local TeamSpeedDropdown = createDynamicDropdown(
        ConfigSection,
        UDim2.new(0, 10, 0, 55),
        speedPreset and string.format("📂 %s", speedPreset) or "📂 Pilih Preset Tim Utama",
        ConfigSection,
        449,
        hatchScroll
    )

    -- Dropdown Tim Leveling
    local TeamHatchDropdown = createDynamicDropdown(
        ConfigSection,
        UDim2.new(0, 10, 0, 88),
        hatchPreset and string.format("📂 %s", hatchPreset) or "📂 Pilih Preset Tim Hatch",
        ConfigSection,
        449,
        hatchScroll
    )

    -- Dropdown Tim Leveling
    local TeamSellDropdown = createDynamicDropdown(
        ConfigSection,
        UDim2.new(0, 10, 0, 121),
        sellPreset and string.format("📂 %s", sellPreset) or "📂 Pilih Preset Tim Sell",
        ConfigSection,
        449,
        hatchScroll
    )
    
    makeInputRow(ConfigSection, 154, "Loadout Swap:", "delayAfterLoadout", true, 0, 30)
    makeInputRow(ConfigSection, 175, "Antar Hatch:", "hatchDelay", true, 0, 30)
    makeInputRow(ConfigSection, 196, "Place Egg:", "placeDelay", true, 0, 30)
    makeInputRow(ConfigSection, 217, "Jumlah cycle:", "cycleCount", true, 1, 10)
    makeToggle(ConfigSection, 238, "💰 Auto Sell: ON", "💰 Auto Sell: OFF", "autoSell")

    MuthaLabel = Instance.new("TextLabel")
    MuthaLabel.Size = UDim2.new(1, -20, 0, 22)
    MuthaLabel.Position = UDim2.new(0, 10, 0, 265)
    MuthaLabel.BackgroundTransparency = 1
    MuthaLabel.Font = Enum.Font.GothamBold
    MuthaLabel.Text = "❌ Mutasi yg tidak diinginkan:"
    MuthaLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    MuthaLabel.TextSize = 11
    MuthaLabel.TextXAlignment = Enum.TextXAlignment.Left
    MuthaLabel.Parent = ConfigSection

    local MutationhaSearchBox = Instance.new("TextBox")
    MutationhaSearchBox.Size = UDim2.new(1, -20, 0, 22)
    MutationhaSearchBox.Position = UDim2.new(0, 10, 0, 292)
    MutationhaSearchBox.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    MutationhaSearchBox.BorderSizePixel = 0
    MutationhaSearchBox.Font = Enum.Font.Gotham
    MutationhaSearchBox.PlaceholderText = "🔍 Cari mutasi..."
    MutationhaSearchBox.Text = ""
    MutationhaSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    MutationhaSearchBox.TextSize = 9
    MutationhaSearchBox.Parent = ConfigSection

    local UICornerMutationhaSearch = Instance.new("UICorner")
    UICornerMutationhaSearch.CornerRadius = UDim.new(0, 4)
    UICornerMutationhaSearch.Parent = MutationhaSearchBox

    local MutationhaListFrame = Instance.new("ScrollingFrame")
    MutationhaListFrame.Size = UDim2.new(1, -20, 0, 120)
    MutationhaListFrame.Position = UDim2.new(0, 10, 0, 319)
    MutationhaListFrame.BackgroundTransparency = 1
    MutationhaListFrame.BorderSizePixel = 0
    MutationhaListFrame.ScrollBarThickness = 3
    MutationhaListFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    MutationhaListFrame.CanvasSize = UDim2.new(0, 0, 0, 120)
    MutationhaListFrame.Parent = ConfigSection

    local MutationhaListLayout = Instance.new("UIListLayout")
    MutationhaListLayout.Padding = UDim.new(0, 2)
    MutationhaListLayout.Parent = MutationhaListFrame

    local EggSection = createSection(hatchScroll, "🥚 Pilih Egg", "selectEgg")
    EggSection.LayoutOrder = 3
    EggSection.Size = UDim2.new(1, -10, 0, 243)

    local eggRefreshBtn = Instance.new("TextButton")
    eggRefreshBtn.Size = UDim2.new(1, -20, 0, 20)
    eggRefreshBtn.Position = UDim2.new(0, 10, 0, 28)
    eggRefreshBtn.BackgroundColor3 = C.accent
    eggRefreshBtn.BorderSizePixel = 0
    eggRefreshBtn.Font = Enum.Font.Gotham
    eggRefreshBtn.Text = "🔄 Refresh Egg List"
    eggRefreshBtn.TextColor3 = C.text
    eggRefreshBtn.TextSize = 8
    eggRefreshBtn.Parent = EggSection
    Instance.new("UICorner", eggRefreshBtn).CornerRadius = UDim.new(0, 4)

    local eggScroll = Instance.new("ScrollingFrame")
    eggScroll.Size = UDim2.new(1, -20, 0, 180)
    eggScroll.Position = UDim2.new(0, 10, 0, 53)
    eggScroll.BackgroundTransparency = 1
    eggScroll.BorderSizePixel = 0
    eggScroll.ScrollBarThickness = 3
    eggScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    eggScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    eggScroll.Parent = EggSection

    local eggLayout = Instance.new("UIListLayout")
    eggLayout.Padding = UDim.new(0, 3)
    eggLayout.Parent = eggScroll

    function refreshEggList()
        for _, c in ipairs(eggScroll:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local eggList = {}
        for _, eggInfo in ipairs(getBackpackEggs()) do
            eggList[eggInfo.name] = (eggList[eggInfo.name] or 0) + eggInfo.count
        end
        local items = {}
        for eggName, count in pairs(eggList) do
            table.insert(items, {
                name = eggName,
                count = count,
                isSelected = config.selectedEggs[eggName] == true,
            })
        end
        table.sort(items, function(a, b)
            if a.isSelected ~= b.isSelected then return a.isSelected end
            return a.name < b.name
        end)
        local i = 0
        for _, item in ipairs(items) do
            i = i + 1
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -4, 0, 24)
            btn.BackgroundColor3 = item.isSelected and C.success or Color3.fromRGB(65, 65, 80)
            btn.BorderSizePixel = 0
            btn.Font = Enum.Font.Gotham
            btn.Text = string.format("%s %s (x%d)", item.isSelected and "✓" or "○", item.name, item.count)
            btn.TextColor3 = C.text
            btn.TextSize = 9
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.LayoutOrder = i
            btn.Parent = eggScroll
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = UDim.new(0, 8)
            pad.Parent = btn
            btn.MouseButton1Click:Connect(function()
                if config.selectedEggs[item.name] then
                    config.selectedEggs[item.name] = nil
                else
                    config.selectedEggs[item.name] = true
                end
                saveConfig()
                refreshEggList()
            end)
        end
        if i == 0 then
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -4, 0, 30)
            lbl.Text = "(Tidak ada egg di backpack)"
            lbl.TextColor3 = C.textDim
            lbl.Font = Enum.Font.Gotham
            lbl.TextSize = 9
            lbl.BackgroundTransparency = 1
            lbl.Parent = eggScroll
        end
    end
    eggRefreshBtn.MouseButton1Click:Connect(refreshEggList)

    local FilterSection = createSection(hatchScroll, "😺 Filter Pet", "petFilter")
    FilterSection.LayoutOrder = 4
    FilterSection.Size = UDim2.new(1, -10, 0, 368)

    makeInputRow(FilterSection, 28, "Max Weight (KG):", "maxWeight", true, 0, 1000)
    makeInputRow(FilterSection, 49, "Max Level:", "maxLevel", true, 0, 1000)

    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -20, 0, 22)
    searchBox.Position = UDim2.new(0, 10, 0, 76)
    searchBox.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    searchBox.BorderSizePixel = 0
    searchBox.Font = Enum.Font.Gotham
    searchBox.PlaceholderText = "🔍 Cari pet..."
    searchBox.Text = ""
    searchBox.TextColor3 = C.text
    searchBox.TextSize = 9
    searchBox.Parent = FilterSection
    Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 4)

    local countLabel = Instance.new("TextLabel")
    countLabel.Size = UDim2.new(1, -20, 0, 14)
    countLabel.Position = UDim2.new(0, 10, 0, 103)
    countLabel.Text = ""
    countLabel.TextColor3 = C.textDim
    countLabel.Font = Enum.Font.Gotham
    countLabel.TextSize = 7
    countLabel.TextXAlignment = Enum.TextXAlignment.Left
    countLabel.BackgroundTransparency = 1
    countLabel.Parent = FilterSection

    local listFrame = Instance.new("ScrollingFrame")
    listFrame.Size = UDim2.new(1, -20, 0, 230)
    listFrame.Position = UDim2.new(0, 10, 0, 122)
    listFrame.BackgroundTransparency = 1
    listFrame.BorderSizePixel = 0
    listFrame.ScrollBarThickness = 3
    listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    listFrame.Parent = FilterSection

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 2)
    listLayout.Parent = listFrame

    function refreshUnwantedList()
        for _, c in ipairs(listFrame:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local search = searchBox.Text:lower()
        local petTypes = getAllPetTypesFromRegistry()
        local items = {}
        for _, petType in ipairs(petTypes) do
            if search == "" or petType:lower():find(search) then
                table.insert(items, {
                    name = petType,
                    isSelected = config.unwantedPetTypes[petType] == true,
                })
            end
        end
        table.sort(items, function(a, b)
            if a.isSelected ~= b.isSelected then return a.isSelected end
            return a.name < b.name
        end)
        local i = 0
        local selectedCount = 0
        for _, item in ipairs(items) do
            i = i + 1
            if item.isSelected then selectedCount = selectedCount + 1 end
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -4, 0, 20)
            btn.BackgroundColor3 = item.isSelected and C.danger or Color3.fromRGB(65, 65, 80)
            btn.BorderSizePixel = 0
            btn.Font = Enum.Font.Gotham
            btn.Text = string.format("%s %s", item.isSelected and "✓" or "○", item.name)
            btn.TextColor3 = C.text
            btn.TextSize = 8
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.LayoutOrder = i
            btn.Parent = listFrame
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = UDim.new(0, 6)
            pad.Parent = btn
            btn.MouseButton1Click:Connect(function()
                if config.unwantedPetTypes[item.name] then
                    config.unwantedPetTypes[item.name] = nil
                else
                    config.unwantedPetTypes[item.name] = true
                end
                saveConfig()
                refreshUnwantedList()
            end)
        end
        countLabel.Text = string.format("Total: %d pet | Terpilih: %d", i, selectedCount)
    end
    searchBox:GetPropertyChangedSignal("Text"):Connect(refreshUnwantedList)

    local StartHatchSection = createSection(hatchScroll)
    StartHatchSection.LayoutOrder = 5
    StartHatchSection.Size = UDim2.new(1, -10, 0, 69)
    
    local startBtn = Instance.new("TextButton")
    startBtn.Size = UDim2.new(1, -20, 0, 30)
    startBtn.Position = UDim2.new(0, 10, 0, 10)
    startBtn.BackgroundColor3 = C.success
    startBtn.BorderSizePixel = 0
    startBtn.Font = Enum.Font.GothamBold
    startBtn.Text = "▶️ MULAI"
    startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    startBtn.TextSize = 10
    startBtn.Parent = StartHatchSection
    Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 5)

    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -20, 0, 14)
    statusLabel.Position = UDim2.new(0, 10, 0, 45)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.Text = "Status: Idle"
    statusLabel.TextColor3 = C.textDim
    statusLabel.TextSize = 10
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = StartHatchSection

    statusCallback = function(text) statusLabel.Text = text end

    startBtn.MouseButton1Click:Connect(function()
    if isRunning then
        stopAutoHatch()
        startBtn.Text = "▶️ MULAI"
        startBtn.BackgroundColor3 = C.success
    else
        if isLeveling then
            statusLabel.Text = "⚠️ Stop Auto Leveling dulu sebelum mulai Auto Hatch!"
            return
        end

        -- ⭐ GUARD: Cek Auto Mutation
        if AutoMutation_Shared and AutoMutation_Shared.state and AutoMutation_Shared.state.isRunning then
            statusLabel.Text = "⚠️ Stop Auto Mutation dulu!"
            return
        end

            if next(config.selectedEggs) == nil then
                statusLabel.Text = "⚠️ Pilih egg dulu!"
                return
            end
            if not speedPreset then
                statusLabel.Text = "⚠️ Pilih preset Speed!"
                return
            end
            if not hatchPreset then
                statusLabel.Text = "⚠️ Pilih preset Hatch!"
                return
            end
            if config.autoSell and not sellPreset then
                statusLabel.Text = "⚠️ Pilih preset Sell!"
                return
            end
            lastLoadoutSlot = nil
            startAutoHatch()
            startBtn.Text = "⏹️ STOP"
            startBtn.BackgroundColor3 = C.danger
        end
    end)
    
    -- Populate team speed dropdown
    local function populateTeamSpeedDropdown()
        populateDynamicDropdown(TeamSpeedDropdown, speedPreset, function(name)
            speedPreset = name
            config.speedPreset = name
            saveConfig()
            TeamSpeedDropdown.HeaderButton.Text = string.format("📂 %s", name)
        end)
    end

    -- Populate team hatch dropdown
    local function populateTeamHatchDropdown()
        populateDynamicDropdown(TeamHatchDropdown, hatchPreset, function(name)
            hatchPreset = name
            config.hatchPreset = name
            saveConfig()
            TeamHatchDropdown.HeaderButton.Text = string.format("📂 %s", name)
        end)
    end

    -- Populate team sell dropdown
    local function populateTeamSellDropdown()
        populateDynamicDropdown(TeamSellDropdown, sellPreset, function(name)
            sellPreset = name
            config.sellPreset = name
            saveConfig()
            TeamSellDropdown.HeaderButton.Text = string.format("📂 %s", name)
        end)
    end

    function populateMutationhaList()
        for _, child in pairs(MutationhaListFrame:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        -- ⭐ Kumpulkan mutations dalam 2 kategori
        local selectedMutationsha = {}
        local unselectedMutationsha = {}

        for _, mutationName in ipairs(availableMutations) do
            -- Filter berdasarkan search text
            if mutationSearchText == "" or mutationName:lower():find(mutationSearchText:lower()) then
                local isSelected = table.find(unwantedMutationsHatch, mutationName) ~= nil

                if isSelected then
                    table.insert(selectedMutationsha, mutationName)
                else
                    table.insert(unselectedMutationsha, mutationName)
                end
            end
        end

        -- ⭐ Sort masing-masing kategori alphabetically
        table.sort(selectedMutationsha)
        table.sort(unselectedMutationsha)

        -- ⭐ Gabungkan: selected dulu, lalu unselected
        local allMutations = {}
        for _, name in ipairs(selectedMutationsha) do
            table.insert(allMutations, {Name = name, IsSelected = true})
        end
        for _, name in ipairs(unselectedMutationsha) do
            table.insert(allMutations, {Name = name, IsSelected = false})
        end

        -- Buat button untuk setiap mutation
        for i, mutationInfo in ipairs(allMutations) do
            local mutationName = mutationInfo.Name
            local isSelected = mutationInfo.IsSelected

            local MutationhaButton = Instance.new("TextButton")
            MutationhaButton.Size = UDim2.new(1, 0, 0, 20)
            MutationhaButton.BackgroundColor3 = isSelected and C.danger or Color3.fromRGB(65, 65, 80)
            MutationhaButton.BorderSizePixel = 0
            MutationhaButton.Font = Enum.Font.Gotham
            MutationhaButton.Text = mutationName
            MutationhaButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            MutationhaButton.TextSize = 8
            MutationhaButton.TextXAlignment = Enum.TextXAlignment.Center
            MutationhaButton.LayoutOrder = i
            MutationhaButton.Parent = MutationhaListFrame

            local UICorner = Instance.new("UICorner")
            UICorner.CornerRadius = UDim.new(0, 3)
            UICorner.Parent = MutationhaButton

            MutationhaButton.MouseButton1Click:Connect(function()
                local idx = table.find(unwantedMutationsHatch, mutationName)
                if idx then
                    table.remove(unwantedMutationsHatch, idx)
                else
                    table.insert(unwantedMutationsHatch, mutationName)
                end
                config.unwantedMutationsHatch = unwantedMutationsHatch
                saveConfig()

                -- ⭐ AUTO CLEAR SEARCH BAR
                mutationSearchText = ""
                MutationhaSearchBox.Text = ""

                -- ⭐ Refresh list (selected akan naik ke atas)
                populateMutationhaList()
            end)
        end

        -- Update canvas
        local count = #allMutations
        MutationhaListFrame.CanvasSize = UDim2.new(0, 0, 0, math.max(count * 22, 50))
    end

    MutationhaSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        mutationSearchText = MutationhaSearchBox.Text
        populateMutationhaList()
    end)
    
    TeamSpeedDropdown.HeaderButton.MouseButton1Click:Connect(function()
        if not TeamSpeedDropdown.IsOpen() then
            populateTeamSpeedDropdown()
        end
    end)

    TeamHatchDropdown.HeaderButton.MouseButton1Click:Connect(function()
        if not TeamHatchDropdown.IsOpen() then
            populateTeamHatchDropdown()
        end
    end)

    TeamSellDropdown.HeaderButton.MouseButton1Click:Connect(function()
        if not TeamSellDropdown.IsOpen() then
            populateTeamSellDropdown()
        end
    end)
end -- BLOCK 11

-- shared: diisi di BLOCK 12 (TAB INVENTORY)
local refreshGiftPetList

do -- BLOCK 12: TAB INVENTORY
    -- ==================================================================
    -- TAB INVENTORY
    -- ==================================================================
    local invTab = tabFrames["Inventory"]

    local invScroll = Instance.new("ScrollingFrame")
    invScroll.Size = UDim2.new(1, -10, 1, -10)
    invScroll.Position = UDim2.new(0, 5, 0, 5)
    invScroll.BackgroundTransparency = 1
    invScroll.BorderSizePixel = 0
    invScroll.ScrollBarThickness = 4
    invScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    invScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    invScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    invScroll.Parent = invTab

    local invLayout = Instance.new("UIListLayout")
    invLayout.Padding = UDim.new(0, 6)
    invLayout.SortOrder = Enum.SortOrder.LayoutOrder
    invLayout.Parent = invScroll

    local AccSection = createSection(invScroll, "😘 Auto Accept", "acceptEgg")
    AccSection.LayoutOrder = 1
    AccSection.Size = UDim2.new(1, -10, 0, 154)

    local giftEnableBtn = Instance.new("TextButton")
    giftEnableBtn.Size = UDim2.new(1, -20, 0, 22)
    giftEnableBtn.Position = UDim2.new(0, 10, 0, 28)
    giftEnableBtn.BackgroundColor3 = config.giftEnabled and C.success or Color3.fromRGB(70, 70, 85)
    giftEnableBtn.BorderSizePixel = 0
    giftEnableBtn.Font = Enum.Font.Gotham
    giftEnableBtn.Text = config.giftEnabled and "😘 Auto Accept: ON" or "😘 Auto Accept: OFF"
    giftEnableBtn.TextColor3 = C.text
    giftEnableBtn.TextSize = 9
    giftEnableBtn.Parent = AccSection
    Instance.new("UICorner", giftEnableBtn).CornerRadius = UDim.new(0, 4)
    giftEnableBtn.MouseButton1Click:Connect(function()
        config.giftEnabled = not config.giftEnabled
        giftEnableBtn.Text = config.giftEnabled and "😘 Auto Accept: ON" or "😘 Auto Accept: OFF"
        giftEnableBtn.BackgroundColor3 = config.giftEnabled and C.success or Color3.fromRGB(70, 70, 85)
        saveConfig()
    end)

    local hideUIBtn = Instance.new("TextButton")
    hideUIBtn.Size = UDim2.new(1, -20, 0, 22)
    hideUIBtn.Position = UDim2.new(0, 10, 0, 55)
    hideUIBtn.BackgroundColor3 = config.giftHideUI and C.success or Color3.fromRGB(70, 70, 85)
    hideUIBtn.BorderSizePixel = 0
    hideUIBtn.Font = Enum.Font.Gotham
    hideUIBtn.Text = config.giftHideUI and "👁️ Hide UI: ON" or "👁️ Hide UI: OFF"
    hideUIBtn.TextColor3 = C.text
    hideUIBtn.TextSize = 9
    hideUIBtn.Parent = AccSection
    Instance.new("UICorner", hideUIBtn).CornerRadius = UDim.new(0, 4)
    hideUIBtn.MouseButton1Click:Connect(function()
        config.giftHideUI = not config.giftHideUI
        hideUIBtn.Text = config.giftHideUI and "👁️ Hide UI: ON" or "👁️ Hide UI: OFF"
        hideUIBtn.BackgroundColor3 = config.giftHideUI and C.success or Color3.fromRGB(70, 70, 85)
        saveConfig()
    end)

    makeInputRow(AccSection, 83, "Delay antar gift:", "giftDelayBetween", true, 0, 60)

    local giftStatsLabel = Instance.new("TextLabel")
    giftStatsLabel.Size = UDim2.new(1, -20, 0, 40)
    giftStatsLabel.Position = UDim2.new(0, 10, 0, 104)
    giftStatsLabel.BackgroundTransparency = 1
    giftStatsLabel.Font = Enum.Font.Gotham
    giftStatsLabel.TextSize = 8
    giftStatsLabel.TextColor3 = C.textDim
    giftStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
    giftStatsLabel.TextYAlignment = Enum.TextYAlignment.Top
    giftStatsLabel.Text = "Stats: 0 accepted, 0 failed"
    giftStatsLabel.Parent = AccSection

    task.spawn(function()
        while not isGuiDestroyed do
            task.wait(2)
            if giftStatsLabel and giftStatsLabel.Parent then
                giftStatsLabel.Text = string.format(
                    "Stats:\n✅ Accepted: %d\n❌ Failed: %d\n📥 Queue: %d",
                    GIFT_STATS.totalAccepted, GIFT_STATS.totalFailed, #giftQueue
                )
            end
        end
    end)

    local GiftSection = createSection(invScroll, "🎁 Auto Gift", "giftEgg")
    GiftSection.LayoutOrder = 2
    GiftSection.Size = UDim2.new(1, -10, 0, 516)

    local targetLabel = Instance.new("TextLabel")
    targetLabel.Size = UDim2.new(1, -20, 0, 14)
    targetLabel.Position = UDim2.new(0, 10, 0, 28)
    targetLabel.Text = "Target Player:"
    targetLabel.TextColor3 = C.textDim
    targetLabel.Font = Enum.Font.Gotham
    targetLabel.TextSize = 8
    targetLabel.TextXAlignment = Enum.TextXAlignment.Left
    targetLabel.BackgroundTransparency = 1
    targetLabel.Parent = GiftSection

    local targetBtn = Instance.new("TextButton")
    targetBtn.Size = UDim2.new(1, -20, 0, 22)
    targetBtn.Position = UDim2.new(0, 10, 0, 47)
    targetBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    targetBtn.BorderSizePixel = 0
    targetBtn.Font = Enum.Font.Gotham
    targetBtn.Text = config.giftPetTarget and ("👤 " .. config.giftPetTarget) or "👤 Pilih player..."
    targetBtn.TextColor3 = C.text
    targetBtn.TextSize = 8
    targetBtn.TextXAlignment = Enum.TextXAlignment.Left
    targetBtn.Parent = GiftSection
    Instance.new("UICorner", targetBtn).CornerRadius = UDim.new(0, 4)
    local targetPad = Instance.new("UIPadding")
    targetPad.PaddingLeft = UDim.new(0, 8)
    targetPad.Parent = targetBtn

    targetBtn.MouseButton1Click:Connect(function()
        local names = getPlayerNames()
        if #names == 0 then
            targetBtn.Text = "❌ Tidak ada player lain"
            task.wait(1)
            targetBtn.Text = config.giftPetTarget and ("👤 " .. config.giftPetTarget) or "👤 Pilih player..."
            return
        end
        local currentIdx = 1
        if config.giftPetTarget then
            for i, n in ipairs(names) do
                if n == config.giftPetTarget then currentIdx = i + 1 break end
            end
        end
        if currentIdx > #names then currentIdx = 1 end
        config.giftPetTarget = names[currentIdx]
        targetBtn.Text = "👤 " .. names[currentIdx]
        saveConfig()
    end)

    local refreshTargetBtn = Instance.new("TextButton")
    refreshTargetBtn.Size = UDim2.new(1, -20, 0, 18)
    refreshTargetBtn.Position = UDim2.new(0, 10, 0, 74)
    refreshTargetBtn.BackgroundColor3 = C.accent
    refreshTargetBtn.BorderSizePixel = 0
    refreshTargetBtn.Font = Enum.Font.Gotham
    refreshTargetBtn.Text = "🔄 Refresh Player List"
    refreshTargetBtn.TextColor3 = C.text
    refreshTargetBtn.TextSize = 7
    refreshTargetBtn.Parent = GiftSection
    Instance.new("UICorner", refreshTargetBtn).CornerRadius = UDim.new(0, 3)
    refreshTargetBtn.MouseButton1Click:Connect(function()
        local names = getPlayerNames()
        print("[Gift Pet] Players:", #names)
        for _, n in ipairs(names) do print("  -", n) end
        if #names > 0 and not config.giftPetTarget then
            config.giftPetTarget = names[1]
            targetBtn.Text = "👤 " .. names[1]
            saveConfig()
        end
    end)

    makeInputRow(GiftSection, 97, "Min Weight (KG):", "giftPetMinWeight", true, 0, 1000)
    makeInputRow(GiftSection, 118, "Max Weight (KG):", "giftPetMaxWeight", true, 0, 1000)
    makeInputRow(GiftSection, 139, "Min Level:", "giftPetMinLevel", true, 0, 1000)
    makeInputRow(GiftSection, 160, "Max Level:", "giftPetMaxLevel", true, 0, 1000)

    local giftPetSelectInfo = Instance.new("TextLabel")
    giftPetSelectInfo.Size = UDim2.new(1, -20, 0, 14)
    giftPetSelectInfo.Position = UDim2.new(0, 10, 0, 181)
    giftPetSelectInfo.BackgroundTransparency = 1
    giftPetSelectInfo.Font = Enum.Font.Gotham
    giftPetSelectInfo.TextSize = 7
    giftPetSelectInfo.TextColor3 = C.textDim
    giftPetSelectInfo.TextXAlignment = Enum.TextXAlignment.Left
    giftPetSelectInfo.Text = "Pilih pet yang mau di-gift"
    giftPetSelectInfo.Parent = GiftSection

    local giftPetSearch = Instance.new("TextBox")
    giftPetSearch.Size = UDim2.new(1, -20, 0, 22)
    giftPetSearch.Position = UDim2.new(0, 10, 0, 200)
    giftPetSearch.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    giftPetSearch.BorderSizePixel = 0
    giftPetSearch.Font = Enum.Font.Gotham
    giftPetSearch.PlaceholderText = "🔍 Cari pet..."
    giftPetSearch.Text = ""
    giftPetSearch.TextColor3 = C.text
    giftPetSearch.TextSize = 9
    giftPetSearch.Parent = GiftSection
    Instance.new("UICorner", giftPetSearch).CornerRadius = UDim.new(0, 4)

    local giftPetListFrame = Instance.new("ScrollingFrame")
    giftPetListFrame.Size = UDim2.new(1, -20, 0, 200)
    giftPetListFrame.Position = UDim2.new(0, 10, 0, 227)
    giftPetListFrame.BackgroundTransparency = 1
    giftPetListFrame.BorderSizePixel = 0
    giftPetListFrame.ScrollBarThickness = 3
    giftPetListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    giftPetListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    giftPetListFrame.Parent = GiftSection

    local giftPetListLayout = Instance.new("UIListLayout")
    giftPetListLayout.Padding = UDim.new(0, 2)
    giftPetListLayout.Parent = giftPetListFrame

    function refreshGiftPetList()
        for _, c in ipairs(giftPetListFrame:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local search = giftPetSearch.Text:lower()
        local petTypes = getAllPetTypesFromRegistry()
        local items = {}
        for _, petType in ipairs(petTypes) do
            if search == "" or petType:lower():find(search) then
                table.insert(items, {
                    name = petType,
                    isSelected = config.giftPetSelectedTypes[petType] == true,
                })
            end
        end
        table.sort(items, function(a, b)
            if a.isSelected ~= b.isSelected then return a.isSelected end
            return a.name < b.name
        end)
        local i = 0
        for _, item in ipairs(items) do
            i = i + 1
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -4, 0, 20)
            btn.BackgroundColor3 = item.isSelected and C.success or Color3.fromRGB(65, 65, 80)
            btn.BorderSizePixel = 0
            btn.Font = Enum.Font.Gotham
            btn.Text = string.format("%s %s", item.isSelected and "✓" or "○", item.name)
            btn.TextColor3 = C.text
            btn.TextSize = 8
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.LayoutOrder = i
            btn.Parent = giftPetListFrame
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = UDim.new(0, 6)
            pad.Parent = btn
            btn.MouseButton1Click:Connect(function()
                if config.giftPetSelectedTypes[item.name] then
                    config.giftPetSelectedTypes[item.name] = nil
                else
                    config.giftPetSelectedTypes[item.name] = true
                end
                saveConfig()
                refreshGiftPetList()
            end)
        end
    end
    giftPetSearch:GetPropertyChangedSignal("Text"):Connect(refreshGiftPetList)

    local refreshGiftPetListBtn = Instance.new("TextButton")
    refreshGiftPetListBtn.Size = UDim2.new(1, -20, 0, 18)
    refreshGiftPetListBtn.Position = UDim2.new(0, 10, 0, 432)
    refreshGiftPetListBtn.BackgroundColor3 = C.accent
    refreshGiftPetListBtn.BorderSizePixel = 0
    refreshGiftPetListBtn.Font = Enum.Font.Gotham
    refreshGiftPetListBtn.Text = "🔄 Refresh Pet List"
    refreshGiftPetListBtn.TextColor3 = C.text
    refreshGiftPetListBtn.TextSize = 7
    refreshGiftPetListBtn.Parent = GiftSection
    Instance.new("UICorner", refreshGiftPetListBtn).CornerRadius = UDim.new(0, 3)
    refreshGiftPetListBtn.MouseButton1Click:Connect(refreshGiftPetList)

    makeInputRow(GiftSection, 455, "Delay antar gift:", "giftPetDelayBetween", true, 0, 100)

    local startGiftBtn = Instance.new("TextButton")
    startGiftBtn.Size = UDim2.new(1, -20, 0, 30)
    startGiftBtn.Position = UDim2.new(0, 10, 0, 476)
    startGiftBtn.BackgroundColor3 = C.success
    startGiftBtn.BorderSizePixel = 0
    startGiftBtn.Font = Enum.Font.GothamBold
    startGiftBtn.Text = "▶️ MULAI AUTO GIFT"
    startGiftBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    startGiftBtn.TextSize = 10
    startGiftBtn.Parent = GiftSection
    Instance.new("UICorner", startGiftBtn).CornerRadius = UDim.new(0, 5)

    startGiftBtn.MouseButton1Click:Connect(function()
        if isGiftPetRunning then
            -- STOP
            isGiftPetRunning = false
            giftPetUserStarted = false   -- ⭐ user STOP → reset flag
            startGiftBtn.Text = "▶️ MULAI AUTO GIFT"
            startGiftBtn.BackgroundColor3 = C.success
            return
        end

        if not config.giftPetTarget then
            statusLabel.Text = "⚠️ Pilih target player!"
            return
        end
        if next(config.giftPetSelectedTypes) == nil then
            statusLabel.Text = "⚠️ Pilih minimal 1 pet untuk di-gift!"
            return
        end

        isGiftPetRunning = true
        giftPetUserStarted = true        -- ⭐ user klik MULAI
        startGiftBtn.Text = "⏹️ STOP"
        startGiftBtn.BackgroundColor3 = C.danger

        task.spawn(function()
            autoGiftAllFiltered()
            if isGiftPetRunning then
                isGiftPetRunning = false
                startGiftBtn.Text = "▶️ MULAI AUTO GIFT"
                startGiftBtn.BackgroundColor3 = C.success
            end
        end)
    end)
end -- BLOCK 12

do -- BLOCK 13: TAB EKSTRA, WEBHOOK SETTINGS, INIT, ANTI-AFK
    -- ==================================================================
    -- TAB EKSTRA
    -- ==================================================================
    local extraTab = tabFrames["Ekstra"]

    local extraScroll = Instance.new("ScrollingFrame")
    extraScroll.Size = UDim2.new(1, -10, 1, -10)
    extraScroll.Position = UDim2.new(0, 5, 0, 5)
    extraScroll.BackgroundTransparency = 1
    extraScroll.BorderSizePixel = 0
    extraScroll.ScrollBarThickness = 4
    extraScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    extraScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    extraScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y  -- Auto size
    extraScroll.Parent = extraTab

    local extraLayout = Instance.new("UIListLayout")
    extraLayout.Padding = UDim.new(0, 6)
    extraLayout.SortOrder = Enum.SortOrder.LayoutOrder
    extraLayout.Parent = extraScroll

    -- ==================================================================
    -- TOGGLE CREATOR (untuk Extra Tab)
    -- ==================================================================
    local function createToggle(title, description, configKey, layoutOrder, defaultColor)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -12, 0, 44)
        container.LayoutOrder = layoutOrder
        container.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
        container.BorderSizePixel = 0
        container.Parent = extraScroll

        Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)

        -- Title
        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, -50, 0, 16)
        titleLabel.Position = UDim2.new(0, 10, 0, 4)
        titleLabel.Text = title
        titleLabel.TextColor3 = C.text
        titleLabel.Font = Enum.Font.GothamSemibold
        titleLabel.TextSize = 10
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.BackgroundTransparency = 1
        titleLabel.Parent = container

        -- Description
        local descLabel = Instance.new("TextLabel")
        descLabel.Size = UDim2.new(1, -50, 0, 14)
        descLabel.Position = UDim2.new(0, 10, 0, 20)
        descLabel.Text = description
        descLabel.TextColor3 = C.textDim
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextSize = 8
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.BackgroundTransparency = 1
        descLabel.Parent = container

        -- Toggle Button
        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Size = UDim2.new(0, 36, 0, 18)
        toggleBtn.Position = UDim2.new(1, -42, 0.5, -9)
        toggleBtn.Text = ""
        toggleBtn.BorderSizePixel = 0
        toggleBtn.AutoButtonColor = false
        toggleBtn.Parent = container

        Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)

        -- Toggle dot
        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 12, 0, 12)
        dot.Position = UDim2.new(0, 3, 0.5, -6)
        dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        dot.BorderSizePixel = 0
        dot.Parent = toggleBtn

        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        -- Status label
        local statusLabel = Instance.new("TextLabel")
        statusLabel.Size = UDim2.new(0, 34, 1, 0)
        statusLabel.Position = UDim2.new(1, -82, 0, 0)
        statusLabel.Text = config[configKey] and "ON" or "OFF"
        statusLabel.TextColor3 = config[configKey] and C.success or C.danger
        statusLabel.Font = Enum.Font.GothamBold
        statusLabel.TextSize = 7
        statusLabel.TextXAlignment = Enum.TextXAlignment.Right
        statusLabel.BackgroundTransparency = 1
        statusLabel.Parent = container

        -- Update function
        local function updateToggle()
            local isOn = config[configKey]

            if isOn then
                toggleBtn.BackgroundColor3 = C.success
                dot.Position = UDim2.new(1, -15, 0.5, -6)
                statusLabel.Text = "ON"
                statusLabel.TextColor3 = C.success
            else
                toggleBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 75)
                dot.Position = UDim2.new(0, 3, 0.5, -6)
                statusLabel.Text = "OFF"
                statusLabel.TextColor3 = C.danger
            end
        end

        toggleBtn.MouseButton1Click:Connect(function()
            config[configKey] = not config[configKey]
            saveConfig()
            updateToggle()

            if configKey == "antiAfkToggle" then
                if config[configKey] then
                    print("[AoneHub] ⏳ Anti-AFK: Delay 15 menit sebelum aktif...")
                else
                    print("[AoneHub] ❌ Anti-AFK: OFF")
                end
            end
        end)

        updateToggle()
        return container
    end

    -- ⭐ TAMBAHKAN TOGGLE ANTI-AFK DI SINI
    createToggle("🛡️ Anti-AFK", "Mencegah Idle", "antiAfkToggle", 2)

    -- ==================================================================
    -- DISCORD WEBHOOK SETTINGS
    -- ==================================================================
    createToggle("🔔 Discord Webhook", "Kirim start & summary sesi ke Discord", "discordWebhookEnabled", 3)

    local webhookContainer = Instance.new("Frame")
    webhookContainer.Size = UDim2.new(1, -12, 0, 62)
    webhookContainer.LayoutOrder = 4
    webhookContainer.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    webhookContainer.BorderSizePixel = 0
    webhookContainer.Parent = extraScroll
    Instance.new("UICorner", webhookContainer).CornerRadius = UDim.new(0, 6)

    local webhookTitle = Instance.new("TextLabel")
    webhookTitle.Size = UDim2.new(1, -20, 0, 16)
    webhookTitle.Position = UDim2.new(0, 10, 0, 4)
    webhookTitle.BackgroundTransparency = 1
    webhookTitle.Text = "🔗 Discord Webhook URL"
    webhookTitle.TextColor3 = C.text
    webhookTitle.Font = Enum.Font.GothamSemibold
    webhookTitle.TextSize = 10
    webhookTitle.TextXAlignment = Enum.TextXAlignment.Left
    webhookTitle.Parent = webhookContainer

    local WebhookUrlInput = Instance.new("TextBox")
    WebhookUrlInput.Size = UDim2.new(1, -20, 0, 25)
    WebhookUrlInput.Position = UDim2.new(0, 10, 0, 29)
    WebhookUrlInput.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    WebhookUrlInput.BorderSizePixel = 0
    WebhookUrlInput.Font = Enum.Font.Gotham
    WebhookUrlInput.PlaceholderText = "https://discord.com/api/webhooks/..."
    WebhookUrlInput.Text = tostring(config.discordWebhook or "")
    WebhookUrlInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    WebhookUrlInput.PlaceholderColor3 = C.textDim
    WebhookUrlInput.TextSize = 8
    WebhookUrlInput.ClearTextOnFocus = false
    WebhookUrlInput.TextXAlignment = Enum.TextXAlignment.Left
    WebhookUrlInput.Parent = webhookContainer
    Instance.new("UICorner", WebhookUrlInput).CornerRadius = UDim.new(0, 4)

    local WebhookPadding = Instance.new("UIPadding")
    WebhookPadding.PaddingLeft = UDim.new(0, 7)
    WebhookPadding.PaddingRight = UDim.new(0, 7)
    WebhookPadding.Parent = WebhookUrlInput

    WebhookUrlInput.FocusLost:Connect(function()
        config.discordWebhook = WebhookUrlInput.Text:gsub("%s+$", "")
        saveConfig()
        WebhookUrlInput.Text = config.discordWebhook
        print("[AoneHub] ✅ Discord Webhook URL tersimpan")
    end)

    -- ==================================================================
    -- INIT
    -- ==================================================================
    refreshEggList()
    refreshUnwantedList()
    refreshGiftPetList()
    refreshMonitor()
    populateMutationhaList()

    -- ==================================================================
    -- ANTI-AFK SYSTEM
    -- ==================================================================
    do
        --==================================================
        -- AoneHub Anti-AFK - Hotbar Safe
        -- Tidak menekan Space dan tidak menggunakan Humanoid:Move()
        --==================================================
        local VirtualInputManager = game:GetService("VirtualInputManager")
        local antiAFKActive = false
        local antiAFKDelayActive = false
        local antiAFKFirstRun = true

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

            local initialDelay
            if antiAFKFirstRun then
                initialDelay = 600
                antiAFKFirstRun = false
                print("[AoneHub] ⏳ Anti-AFK: Delay 10 menit (auto-start awal)")
            else
                initialDelay = 900
                print("[AoneHub] ⏳ Anti-AFK: Delay 15 menit (di-on-kan manual)")
            end

            antiAFKDelayActive = true

            task.spawn(function()
                local remainingDelay = initialDelay
                while remainingDelay > 0 do
                    if isGuiDestroyed or not config.antiAfkToggle then
                        antiAFKDelayActive = false
                        print("[AoneHub] ❌ Anti-AFK: Dibatalkan (destroyed atau OFF)")
                        return
                    end

                    if remainingDelay % 60 == 0 or remainingDelay <= 10 then
                        local minutes = math.floor(remainingDelay / 60)
                        local seconds = remainingDelay % 60
                        if minutes > 0 then
                            print("[AoneHub] ⏳ Anti-AFK aktif dalam: " .. minutes .. " menit " .. seconds .. " detik")
                        else
                            print("[AoneHub] ⏳ Anti-AFK aktif dalam: " .. seconds .. " detik")
                        end
                    end
                    task.wait(1)
                    remainingDelay -= 1
                end

                if config.antiAfkToggle and not isGuiDestroyed then
                    antiAFKDelayActive = false
                    antiAFKActive = true
                    print("[AoneHub] ✅ Anti-AFK: AKTIF! (Hotbar-safe)")

                    while antiAFKActive and config.antiAfkToggle and not isGuiDestroyed do
                        PerformAntiAFKAction()
                        local waitTime = 420 + math.random() * 180
                        local waited = 0
                        while waited < waitTime and antiAFKActive and config.antiAfkToggle and not isGuiDestroyed do
                            task.wait(1)
                            waited += 1
                        end
                    end
                    antiAFKActive = false
                else
                    antiAFKDelayActive = false
                    print("[AoneHub] ❌ Anti-AFK: OFF (toggle dimatikan)")
                end
            end)
        end

        local function StopAntiAFK()
            antiAFKActive = false
            antiAFKDelayActive = false
            print("[AoneHub] ❌ Anti-AFK: OFF")
        end

        task.spawn(function()
            local lastToggleState = config.antiAfkToggle
            while not isGuiDestroyed do
                task.wait(0.5)
                if config.antiAfkToggle ~= lastToggleState then
                    lastToggleState = config.antiAfkToggle
                    if config.antiAfkToggle then
                        if not antiAFKActive and not antiAFKDelayActive then
                            StartAntiAFK()
                        end
                    else
                        StopAntiAFK()
                    end
                end
            end
        end)

        if config.antiAfkToggle then
            task.delay(1, function()
                if config.antiAfkToggle and not isGuiDestroyed then
                    StartAntiAFK()
                    print("[AoneHub] ✅ Anti-AFK auto-started dengan delay 10 menit!")
                end
            end)
        end
    end
end -- BLOCK 13

-- shared: diisi di BLOCK 14A (AUTO BUY BACKEND)
local AutoBuyBackend

do -- BLOCK 14A: AUTO BUY BACKEND (Config, Scanner, Loop)
    -- ==================================================================
    -- CONFIG
    -- ==================================================================
    local ABCfg = {
        selected = {},              -- Key: "shop::name"
        autoBuyEnabled = false,
        checkInterval = 1,
        buyDelay = 0.8,
        maxBuysPerCycle = 50,
        minStock = 1,
        refreshIntervals = {
            Seeds = 5, Gear = 5, Eggs = 10, Cosmetics = 10, Merchant = 10,
        },
        refreshDelaySeconds = 2,
        requiredNPC = "Sam",
        requiredNPCLevel = 5,
    }
    
    if config.autoBuySelected then ABCfg.selected = config.autoBuySelected end
    if config.autoBuyEnabled ~= nil then ABCfg.autoBuyEnabled = config.autoBuyEnabled end

    -- ==================================================================
    -- DEPS
    -- ==================================================================
    local DataSvc = DataService
    local SeedShop = safeRequire(ReplicatedStorage.Data.SeedShopData) or {}
    local DailySeedShop = safeRequire(ReplicatedStorage.Data.DailySeedShopData) or {}
    local NPCLevel = safeRequire(ReplicatedStorage.Data.NPCLevels.NPCLevelData) or {}
    local PetEgg = safeRequire(ReplicatedStorage.Data.PetEggData) or {}
    local GearShop = safeRequire(ReplicatedStorage.Data.GearShopData) or {}
    local CosmeticTab = safeRequire(ReplicatedStorage.Data.CosmeticShopTabData) or {}
    local MerchantData = safeRequire(ReplicatedStorage.Data.TravelingMerchant.TravelingMerchantData) or {}
    local NPCLevelHandlerLocal = safeRequire(ReplicatedStorage.Modules.NPCLevelHandler)
    local RebirthService = safeRequire(ReplicatedStorage.Modules.RebirthUnlocksSharedService)

    local GE = ReplicatedStorage:WaitForChild("GameEvents")
    local BuySeedRE = GE:WaitForChild("BuySeedStock")
    local BuyDailySeedRE = GE:WaitForChild("BuyDailySeedShopStock")
    local BuyPetEggRE = GE:WaitForChild("BuyPetEgg")
    local BuyGearRE = GE:WaitForChild("BuyGearStock")
    local BuyCosmeticRE = GE:WaitForChild("BuyCosmeticItem")
    local BuyFenceRE = GE:WaitForChild("BuyCosmeticShopFence")
    local BuyMerchantRE = GE:WaitForChild("BuyTravelingMerchantShopStock")

    -- ==================================================================
    -- HELPERS
    -- ==================================================================
    local function fmtNum(n)
        if type(n) ~= "number" then return tostring(n) end
        if n ~= n then return "NaN" end
        if n == math.huge then return "∞" end
        local neg = n < 0
        n = math.abs(n)
        if n < 1000 then
            return (neg and "-" or "") .. tostring(math.floor(n))
        end
        local suf = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No",
                     "Dc", "UDc", "DDc", "TDc", "QaDc", "QiDc", "SxDc", "SpDc", "OcDc"}
        local tier = math.min(math.floor(math.log10(n) / 3), #suf - 1)
        local scaled = n / (10 ^ (tier * 3))
        local trunc = math.floor(scaled * 10) / 10
        local str = trunc >= 100 and string.format("%d", math.floor(trunc))
                    or string.format("%.1f", trunc)
        str = str:gsub("%.0$", "")
        return (neg and "-" or "") .. str .. suf[tier + 1]
    end

    local function getNPCLevel(npcName)
        if not NPCLevel then return 0 end
        local d = DataSvc:GetData()
        if not d or not d.Progress or not d.Progress.NPCPoints then return 0 end
        return NPCLevel:GetLevelFromPoints(npcName, d.Progress.NPCPoints[npcName] or 0)
    end

    local function isSamUnlocked()
        return getNPCLevel("Sam") >= ABCfg.requiredNPCLevel
    end

    local function checkLevelLocks(levelLocks)
        if not levelLocks then return true end
        if NPCLevelHandlerLocal and NPCLevelHandlerLocal.HasRequiredNPCLevels then
            local ok, res = pcall(function()
                return NPCLevelHandlerLocal:HasRequiredNPCLevels(levelLocks)
            end)
            if ok then return res end
        end
        if not NPCLevel then return true end
        for npcName, reqLvl in pairs(levelLocks) do
            if getNPCLevel(npcName) < reqLvl then return false end
        end
        return true
    end

    local function checkRebirth(shopType, itemName)
        if not RebirthService then return true, 0 end
        local okAB, hasAB = pcall(function()
            return RebirthService:HasBeenAssignedABTest(player)
        end)
        if not okAB or not hasAB then return true, 0 end
        local okU, isU = pcall(function()
            return RebirthService:HasUnlockedShopItem(player, shopType, itemName)
        end)
        if not okU or isU then return true, 0 end
        local okR, rem = pcall(function()
            return RebirthService:GetRemainingRebirthsNeededForItem(player, shopType, itemName)
        end)
        return false, (okR and rem) or 0
    end

    local function getPlayerCurrency(currencyType)
        local d = DataSvc:GetData()
        if not d then return 0 end
        if currencyType == "Sheckles" then return d.Sheckles or 0 end
        if d.SpecialCurrency and d.SpecialCurrency[currencyType] then
            return d.SpecialCurrency[currencyType] or 0
        end
        return 0
    end

    -- ==================================================================
    -- SCANNERS
    -- ==================================================================
    local function scanSeeds()
        local items = {}
        local d = DataSvc:GetData()
        if not d or not d.SeedStocks then return items end
        local seen = {}
        local isUnlock = isSamUnlocked()

        local function add(name, cfg, shopName, currency)
            local key = shopName .. "::" .. name
            if seen[key] then return end
            seen[key] = true
            local stock = 0
            local sd = d.SeedStocks[shopName]
            if sd and sd.Stocks and sd.Stocks[name] then
                stock = sd.Stocks[name].Stock or 0
            end
            local isLocked, lockReason = false, ""
            if currency == "GardenCoins" and not isUnlock then
                isLocked = true
                lockReason = string.format("Sam Lv.%d/5", getNPCLevel("Sam"))
            end
            if not isLocked then
                local u, rem = checkRebirth("Seed", name)
                if not u then
                    isLocked = true
                    lockReason = string.format("Rebirth %d+ lagi", rem)
                end
            end
            table.insert(items, {
                key = "Seeds::" .. key,
                shopName = shopName,
                itemName = name,
                displayName = name,
                stock = stock,
                price = cfg.Price or 0,
                currency = currency,
                isLocked = isLocked,
                isPaused = false,
                lockReason = lockReason,
                prefix = shopName == "Daily Deals" and "🌙"
                    or (currency == "GardenCoins" and "🌼" or "🏪"),
                buyFn = function()
                    if shopName == "Daily Deals" then
                        BuyDailySeedRE:FireServer(name)
                    else
                        BuySeedRE:FireServer(shopName, name)
                    end
                end,
            })
        end

        for shopName, sd in pairs(d.SeedStocks) do
            if sd.Stocks then
                for name in pairs(sd.Stocks) do
                    local cfg, curr
                    if shopName == "Daily Deals" then
                        cfg = DailySeedShop[name]; curr = "Sheckles"
                    else
                        cfg = SeedShop[name]
                        curr = (cfg and cfg.SpecialCurrencyType) or "Sheckles"
                    end
                    if cfg then add(name, cfg, shopName, curr) end
                end
            end
        end
        for name, cfg in pairs(SeedShop) do
            if cfg.DisplayInShop then
                local k = "Shop::" .. name
                if not seen[k] then
                    add(name, cfg, "Shop", cfg.SpecialCurrencyType or "Sheckles")
                end
            end
        end
        for name, cfg in pairs(DailySeedShop) do
            local k = "Daily Deals::" .. name
            if not seen[k] then add(name, cfg, "Daily Deals", "Sheckles") end
        end
        return items
    end

    local function scanEggs()
        local items = {}
        local d = DataSvc:GetData()
        if not d or not d.PetEggStock then return items end
        local stockMap = {}
        for _, e in ipairs(d.PetEggStock.Stocks or {}) do
            stockMap[e.EggName] = (stockMap[e.EggName] or 0) + e.Stock
        end
        for eggName, cfg in pairs(PetEgg) do
            if cfg.DisplayInShop == false then continue end
            local stock = stockMap[eggName] or 0
            local isLocked, lockReason = false, ""
            if cfg.LevelLocks and not checkLevelLocks(cfg.LevelLocks) then
                isLocked = true
                local hi, n = 0, ""
                for nn, ll in pairs(cfg.LevelLocks) do
                    if ll > hi then hi = ll; n = nn end
                end
                lockReason = string.format("%s Lv.%d", n, hi)
            end
            if not isLocked then
                local u, rem = checkRebirth("Egg", eggName)
                if not u then
                    isLocked = true
                    lockReason = string.format("Rebirth %d+ lagi", rem)
                end
            end
            table.insert(items, {
                key = "Eggs::Shop::" .. eggName,
                shopName = "Pet Shop",
                itemName = eggName,
                displayName = eggName,
                stock = stock,
                price = cfg.Price or 0,
                currency = cfg.SpecialCurrencyType or "Sheckles",
                isLocked = isLocked,
                isPaused = false,
                lockReason = lockReason,
                prefix = "🥚",
                buyFn = function() BuyPetEggRE:FireServer(eggName) end,
            })
        end
        return items
    end

    local function scanGear()
        local items = {}
        local d = DataSvc:GetData()
        if not d or not d.GearStock then return items end
        for gearName, cfg in pairs(GearShop.Gear or {}) do
            if cfg.LayoutOrder == -1 then continue end
            local sd = d.GearStock.Stocks[gearName]
            local stock = sd and sd.Stock or 0
            local isLocked, lockReason = false, ""
            if cfg.LevelLocks and not checkLevelLocks(cfg.LevelLocks) then
                isLocked = true; lockReason = "NPC Level"
            end
            if not isLocked then
                local u, rem = checkRebirth("Gear", gearName)
                if not u then
                    isLocked = true
                    lockReason = string.format("Rebirth %d+ lagi", rem)
                end
            end
            table.insert(items, {
                key = "Gear::Shop::" .. gearName,
                shopName = "Gear Shop",
                itemName = gearName,
                displayName = gearName,
                stock = stock,
                price = cfg.Price or 0,
                currency = "Sheckles",
                isLocked = isLocked,
                isPaused = false,
                lockReason = lockReason,
                prefix = "⚙️",
                buyFn = function() BuyGearRE:FireServer(gearName) end,
            })
        end
        return items
    end

    local function scanCosmetics()
        local items = {}
        local d = DataSvc:GetData()
        if not d or not d.CosmeticStock then return items end
        local cosTab = CosmeticTab.Tabs and CosmeticTab.Tabs["Cosmetics"]
        if cosTab then
            local iS = d.CosmeticStock.TabStocks["Cosmetics"]
                and d.CosmeticStock.TabStocks["Cosmetics"].ItemStocks or {}
            for nm, si in pairs(iS) do
                local cfg = cosTab.Items and cosTab.Items[nm]
                if cfg then
                    table.insert(items, {
                        key = "Cosmetics::Cosmetics::" .. nm,
                        shopName = "Cosmetic Shop",
                        itemName = nm, displayName = nm,
                        stock = si.Stock or 0, price = cfg.Price or 0,
                        currency = "Sheckles",
                        isLocked = false, isPaused = false, lockReason = "",
                        prefix = "🎨",
                        buyFn = function() BuyCosmeticRE:FireServer(nm, "Cosmetics") end,
                    })
                end
            end
        end
        local fTab = CosmeticTab.Tabs and CosmeticTab.Tabs["Fences"]
        if fTab then
            local fS = d.CosmeticStock.TabStocks["Cosmetics"]
                and d.CosmeticStock.TabStocks["Cosmetics"].FenceStocks or {}
            for nm, si in pairs(fS) do
                local cfg = fTab.Fences and fTab.Fences[nm]
                if cfg then
                    table.insert(items, {
                        key = "Cosmetics::Fences::" .. nm,
                        shopName = "Fence Shop",
                        itemName = nm, displayName = nm,
                        stock = si.Stock or 0, price = cfg.Price or 0,
                        currency = "Sheckles",
                        isLocked = false, isPaused = false, lockReason = "",
                        prefix = "🚧",
                        buyFn = function() BuyFenceRE:FireServer(nm, "Fences") end,
                    })
                end
            end
        end
        return items
    end

    local function scanMerchant()
        local items = {}
        local d = DataSvc:GetData()
        if not d then return items end
        local activeM = nil
        local mS = d.TravelingMerchantShopStock
        if mS and mS.MerchantType and mS.MerchantType ~= "" then
            activeM = mS.MerchantType
        end
        local activeStocks = (mS and mS.Stocks) or {}
        for mType, mInfo in pairs(MerchantData) do
            if not mInfo.ShopData then continue end
            for nm, cfg in pairs(mInfo.ShopData) do
                if cfg.DisplayInShop == false then continue end
                local isActive = (mType == activeM)
                local stock = 0
                if isActive and activeStocks[nm] then
                    stock = activeStocks[nm].Stock or 0
                end
                local isPaused = not isActive
                local iType = cfg.ItemType or "Item"
                local prefix = "🛒"
                if iType == "Seed" then prefix = "🌾"
                elseif iType == "Seed Pack" then prefix = "📦"
                elseif iType == "Egg" then prefix = "🥚"
                elseif iType == "Pet" then prefix = "🐾"
                elseif iType == "Gear" then prefix = "⚙️"
                elseif iType == "Crate" then prefix = "🎁"
                elseif iType == "Cosmetic" then prefix = "🎨" end
                table.insert(items, {
                    key = "Merchant::" .. mType .. "::" .. nm,
                    shopName = mInfo.Title or mType,
                    merchantType = mType,
                    itemName = nm, displayName = nm,
                    stock = stock, price = cfg.Price or 0,
                    currency = cfg.SpecialCurrencyType or "Sheckles",
                    isLocked = false, isPaused = isPaused, lockReason = "",
                    prefix = isPaused and ("⏸️" .. prefix) or prefix,
                    buyFn = function() BuyMerchantRE:FireServer(nm) end,
                })
            end
        end
        return items
    end

    local function scanByTab(tab)
        if tab == "Seeds" then return scanSeeds() end
        if tab == "Eggs" then return scanEggs() end
        if tab == "Gear" then return scanGear() end
        if tab == "Cosmetics" then return scanCosmetics() end
        if tab == "Merchant" then return scanMerchant() end
        return {}
    end

    -- ==================================================================
    -- LOOP
    -- ==================================================================
    local autoBuyRunning = false
    local loopThread = nil

    local function autoBuyLoop()
        while autoBuyRunning and not isGuiDestroyed do
            task.wait(ABCfg.checkInterval)
            if not ABCfg.autoBuyEnabled or isGuiDestroyed then continue end
            local selCount = 0
            for _ in pairs(ABCfg.selected) do selCount = selCount + 1 end
            if selCount == 0 then continue end

            local buys = 0
            for _, tab in ipairs({"Seeds", "Eggs", "Gear", "Cosmetics", "Merchant"}) do
                if not autoBuyRunning then break end
                if buys >= ABCfg.maxBuysPerCycle then break end
                local items = scanByTab(tab)
                for _, item in ipairs(items) do
                    if not autoBuyRunning then break end
                    if buys >= ABCfg.maxBuysPerCycle then break end
                    if not ABCfg.selected[item.key] then continue end
                    if item.isLocked or item.isPaused then continue end
                    if item.stock < ABCfg.minStock then continue end
                    local bal = getPlayerCurrency(item.currency)
                    if bal >= item.price then
                        print(string.format("[AutoBuy] 🛒 %s [%s] stock:%s",
                            item.itemName, item.shopName, fmtNum(item.stock)))
                        local ok = pcall(item.buyFn)
                        if ok then
                            buys = buys + 1
                            task.wait(ABCfg.buyDelay)
                            -- ⭐ Callback ke frontend
                            if AutoBuyBackend.onBuySuccess then
                                pcall(AutoBuyBackend.onBuySuccess)
                            end
                        end
                    end
                end
            end
        end
    end

    -- ==================================================================
    -- SHARE KE BLOCK 14B
    -- ==================================================================
    AutoBuyBackend = {
        Cfg = ABCfg,
        scanByTab = scanByTab,
        fmtNum = fmtNum,
        getPlayerCurrency = getPlayerCurrency,
        getNPCLevel = getNPCLevel,
        onBuySuccess = nil,
        saveConfig = function()
            config.autoBuySelected = ABCfg.selected
            config.autoBuyEnabled = ABCfg.autoBuyEnabled
            saveConfig()
        end,
        start = function()
            ABCfg.autoBuyEnabled = true
            autoBuyRunning = true
            if loopThread then
                task.cancel(loopThread)
                loopThread = nil
            end
            loopThread = task.spawn(autoBuyLoop)
        end,
        stop = function()
            ABCfg.autoBuyEnabled = false
            autoBuyRunning = false
            if loopThread then
                task.cancel(loopThread)
                loopThread = nil
            end
        end,
        isRunning = function() return autoBuyRunning end,
    }
    
    print("✅ [AutoBuy] Backend loaded")
end -- BLOCK 14A

do -- BLOCK 14B: AUTO BUY FRONTEND (2 Sections)
    if not AutoBuyBackend then
        warn("❌ AutoBuyBackend tidak ada, skip frontend")
        return
    end
    
    local ABCfg = AutoBuyBackend.Cfg
    local scanByTab = AutoBuyBackend.scanByTab
    local fmtNum = AutoBuyBackend.fmtNum

    local buyTab = tabFrames["AutoBuy"]
    if not buyTab then
        warn("❌ Tab AutoBuy tidak ditemukan, skip frontend")
        return
    end

    -- ==================================================================
    -- SCROLL
    -- ==================================================================
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

    -- State
    local currentBuyTab = "Seeds"
    local itemButtons = {}
    local statusLabelAB = nil
    local renderListFn = nil

    -- ==================================================================
    -- SECTION 1: CONTROL
    -- ==================================================================
    local ControlSection = createSection(buyScroll)
    ControlSection.LayoutOrder = 2
    ControlSection.Size = UDim2.new(1, -10, 0, 71)

    local startABBtn = Instance.new("TextButton")
    startABBtn.Size = UDim2.new(1, -20, 0, 32)
    startABBtn.Position = UDim2.new(0, 10, 0, 10)
    startABBtn.BackgroundColor3 = ABCfg.autoBuyEnabled and C.danger or C.success
    startABBtn.BorderSizePixel = 0
    startABBtn.Font = Enum.Font.GothamBold
    startABBtn.Text = ABCfg.autoBuyEnabled and "⏹️ STOP AUTO BUY" or "▶️ START AUTO BUY"
    startABBtn.TextColor3 = C.text
    startABBtn.TextSize = 10
    startABBtn.Parent = ControlSection
    Instance.new("UICorner", startABBtn).CornerRadius = UDim.new(0, 5)

    statusLabelAB = Instance.new("TextLabel")
    statusLabelAB.Size = UDim2.new(1, -20, 0, 14)
    statusLabelAB.Position = UDim2.new(0, 10, 0, 47)
    statusLabelAB.BackgroundTransparency = 1
    statusLabelAB.Text = ABCfg.autoBuyEnabled and "Status: Running" or "Status: Idle"
    statusLabelAB.TextColor3 = C.textDim
    statusLabelAB.Font = Enum.Font.GothamBold
    statusLabelAB.TextSize = 9
    statusLabelAB.TextXAlignment = Enum.TextXAlignment.Left
    statusLabelAB.Parent = ControlSection

    startABBtn.MouseButton1Click:Connect(function()
        if ABCfg.autoBuyEnabled then
            AutoBuyBackend.stop()
            startABBtn.Text = "▶️ START AUTO BUY"
            startABBtn.BackgroundColor3 = C.success
            statusLabelAB.Text = "Status: Stopped"
            AutoBuyBackend.saveConfig()
        else
            local cnt = 0
            for _ in pairs(ABCfg.selected) do cnt = cnt + 1 end
            if cnt == 0 then
                statusLabelAB.Text = "⚠️ Pilih minimal 1 item!"
                return
            end
            AutoBuyBackend.start()
            startABBtn.Text = "⏹️ STOP AUTO BUY"
            startABBtn.BackgroundColor3 = C.danger
            statusLabelAB.Text = string.format("✅ Running (%d item)", cnt)
            AutoBuyBackend.saveConfig()
        end
    end)

    -- ==================================================================
    -- SECTION 2: ITEM LIST
    -- ==================================================================
    local ListSection = createSection(buyScroll, "📋 Item List", "autoBuyList")
    ListSection.LayoutOrder = 1
    ListSection.Size = UDim2.new(1, -10, 0, 400)

    -- Sub tabs
    local subTabs = {
        {"Seeds", "🌱"}, {"Eggs", "🥚"}, {"Gear", "⚙️"},
        {"Cosmetics", "🎨"}, {"Merchant", "🛒"},
    }
    local subTabBtns = {}
    local subTabBar = Instance.new("Frame")
    subTabBar.Size = UDim2.new(1, -20, 0, 22)
    subTabBar.Position = UDim2.new(0, 10, 0, 28)
    subTabBar.BackgroundTransparency = 1
    subTabBar.Parent = ListSection

    local subTabLayout = Instance.new("UIListLayout")
    subTabLayout.FillDirection = Enum.FillDirection.Horizontal
    subTabLayout.Padding = UDim.new(0, 3)
    subTabLayout.Parent = subTabBar

    local function setBuyTab(name)
        currentBuyTab = name
        for n, b in pairs(subTabBtns) do
            if n == name then
                b.BackgroundColor3 = C.accent
                b.TextColor3 = C.text
            else
                b.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
                b.TextColor3 = C.textDim
            end
        end
        if renderListFn then pcall(renderListFn) end
    end

    for _, st in ipairs(subTabs) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.2, -3, 1, 0)
        btn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
        btn.Text = st[2] .. " " .. st[1]
        btn.TextColor3 = C.textDim
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 8
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.Parent = subTabBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
        btn.MouseButton1Click:Connect(function() setBuyTab(st[1]) end)
        subTabBtns[st[1]] = btn
    end

    -- Search
    local searchAB = Instance.new("TextBox")
    searchAB.Size = UDim2.new(1, -20, 0, 22)
    searchAB.Position = UDim2.new(0, 10, 0, 54)
    searchAB.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    searchAB.BorderSizePixel = 0
    searchAB.Font = Enum.Font.Gotham
    searchAB.PlaceholderText = "🔍 Cari..."
    searchAB.Text = ""
    searchAB.TextColor3 = C.text
    searchAB.TextSize = 9
    searchAB.ClearTextOnFocus = false
    searchAB.Parent = ListSection
    Instance.new("UICorner", searchAB).CornerRadius = UDim.new(0, 4)

    -- Select all / Clear
    local selAllAB = Instance.new("TextButton")
    selAllAB.Size = UDim2.new(0.5, -15, 0, 22)
    selAllAB.Position = UDim2.new(0, 10, 0, 81)
    selAllAB.BackgroundColor3 = C.accent
    selAllAB.BorderSizePixel = 0
    selAllAB.Font = Enum.Font.GothamBold
    selAllAB.Text = "✓ Semua di Tab"
    selAllAB.TextColor3 = C.text
    selAllAB.TextSize = 8
    selAllAB.AutoButtonColor = false
    selAllAB.Parent = ListSection
    Instance.new("UICorner", selAllAB).CornerRadius = UDim.new(0, 3)

    local clrAB = Instance.new("TextButton")
    clrAB.Size = UDim2.new(0.5, -15, 0, 22)
    clrAB.Position = UDim2.new(0.5, 5, 0, 81)
    clrAB.BackgroundColor3 = C.danger
    clrAB.BorderSizePixel = 0
    clrAB.Font = Enum.Font.GothamBold
    clrAB.Text = "✕ Clear"
    clrAB.TextColor3 = C.text
    clrAB.TextSize = 8
    clrAB.AutoButtonColor = false
    clrAB.Parent = ListSection
    Instance.new("UICorner", clrAB).CornerRadius = UDim.new(0, 3)

    -- List
    local itemScroll = Instance.new("ScrollingFrame")
    itemScroll.Size = UDim2.new(1, -20, 0, 260)
    itemScroll.Position = UDim2.new(0, 10, 0, 108)
    itemScroll.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    itemScroll.BorderSizePixel = 0
    itemScroll.ScrollBarThickness = 4
    itemScroll.ScrollBarImageColor3 = C.accent
    itemScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    itemScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    itemScroll.Parent = ListSection
    Instance.new("UICorner", itemScroll).CornerRadius = UDim.new(0, 4)

    local itemLayout = Instance.new("UIListLayout")
    itemLayout.Padding = UDim.new(0, 2)
    itemLayout.SortOrder = Enum.SortOrder.LayoutOrder
    itemLayout.Parent = itemScroll

    local itemPad = Instance.new("UIPadding")
    itemPad.PaddingLeft = UDim.new(0, 4)
    itemPad.PaddingRight = UDim.new(0, 4)
    itemPad.PaddingTop = UDim.new(0, 4)
    itemPad.Parent = itemScroll

    local function renderList()
        for _, b in ipairs(itemButtons) do b:Destroy() end
        itemButtons = {}

        local search = searchAB.Text:lower()
        local items = scanByTab(currentBuyTab)
        local filtered = {}
        for _, item in ipairs(items) do
            if search == "" or item.displayName:lower():find(search, 1, true) then
                table.insert(filtered, item)
            end
        end

        table.sort(filtered, function(a, b)
            if a.isPaused ~= b.isPaused then return not a.isPaused end
            if a.isLocked ~= b.isLocked then return not a.isLocked end
            local aSel = ABCfg.selected[a.key] == true
            local bSel = ABCfg.selected[b.key] == true
            if aSel ~= bSel then return aSel end
            if (a.stock > 0) ~= (b.stock > 0) then return a.stock > 0 end
            if a.shopName ~= b.shopName then return a.shopName < b.shopName end
            return a.displayName < b.displayName
        end)

        if #filtered == 0 then
            local ph = Instance.new("TextLabel")
            ph.Size = UDim2.new(1, -8, 0, 40)
            ph.BackgroundTransparency = 1
            ph.Text = "📭 Tidak ada item"
            ph.TextColor3 = C.textDim
            ph.Font = Enum.Font.Gotham
            ph.TextSize = 9
            ph.Parent = itemScroll
            table.insert(itemButtons, ph)
            itemScroll.CanvasSize = UDim2.new(0, 0, 0, 48)
            return
        end

        for i, item in ipairs(filtered) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -8, 0, 24)

            local isSel = ABCfg.selected[item.key] == true
            -- Urutan prioritas: Locked → Selected → Paused → Unselected
            if item.isLocked then
                btn.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
            elseif isSel then
                btn.BackgroundColor3 = Color3.fromRGB(60, 130, 220)  -- BIRU
            elseif item.isPaused then
                btn.BackgroundColor3 = Color3.fromRGB(40, 45, 55)
            else
                btn.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
            end
            btn.BorderSizePixel = 0
            btn.Text = ""
            btn.AutoButtonColor = false
            btn.LayoutOrder = i
            btn.Parent = itemScroll
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)

            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = UDim.new(0, 8)
            pad.Parent = btn

            -- Icon
            local icon = Instance.new("TextLabel")
            icon.Size = UDim2.new(0, 18, 1, 0)
            icon.BackgroundTransparency = 1
            if item.isLocked then
                icon.Text = "🔒"
                icon.TextColor3 = Color3.fromRGB(120, 80, 80)
            elseif isSel then
                icon.Text = "✓"
                icon.TextColor3 = C.text
            elseif item.isPaused then
                icon.Text = "⏸️"
                icon.TextColor3 = Color3.fromRGB(130, 140, 160)
            else
                icon.Text = "○"
                icon.TextColor3 = C.text
            end
            icon.Font = Enum.Font.GothamBold
            icon.TextSize = 10
            icon.TextXAlignment = Enum.TextXAlignment.Left
            icon.Parent = btn

            -- Name
            local nameL = Instance.new("TextLabel")
            nameL.Size = UDim2.new(0.45, 0, 1, 0)
            nameL.Position = UDim2.new(0, 20, 0, 0)
            nameL.BackgroundTransparency = 1
            nameL.Text = item.prefix .. " " .. item.displayName
            if item.isLocked then
                nameL.TextColor3 = Color3.fromRGB(120, 80, 80)
            elseif item.isPaused then
                nameL.TextColor3 = Color3.fromRGB(130, 140, 160)
            else
                nameL.TextColor3 = C.text
            end
            nameL.Font = Enum.Font.GothamSemibold
            nameL.TextSize = 8
            nameL.TextXAlignment = Enum.TextXAlignment.Left
            nameL.Parent = btn

            -- Price
            local priceL = Instance.new("TextLabel")
            priceL.Size = UDim2.new(0.22, 0, 1, 0)
            priceL.Position = UDim2.new(0.65, 0, 0, 0)
            priceL.BackgroundTransparency = 1
            local sym = (item.currency == "GardenCoins") and "🌼" or "💵"
            priceL.Text = string.format("%s %s", sym, fmtNum(item.price))
            if item.isLocked then
                priceL.TextColor3 = Color3.fromRGB(120, 80, 80)
            elseif item.isPaused then
                priceL.TextColor3 = Color3.fromRGB(130, 140, 160)
            else
                priceL.TextColor3 = Color3.fromRGB(255, 200, 0)
            end
            priceL.Font = Enum.Font.Gotham
            priceL.TextSize = 8
            priceL.TextXAlignment = Enum.TextXAlignment.Right
            priceL.Parent = btn

            -- Stock
            local stockL = Instance.new("TextLabel")
            stockL.Size = UDim2.new(0.13, 0, 1, 0)
            stockL.Position = UDim2.new(0.84, 0, 0, 0)
            stockL.BackgroundTransparency = 1
            if item.stock > 0 then
                stockL.Text = "📦" .. fmtNum(item.stock)
                stockL.TextColor3 = item.isLocked and Color3.fromRGB(120, 80, 80)
                    or item.isPaused and Color3.fromRGB(130, 140, 160) or C.success
            else
                stockL.Text = "❌0"
                stockL.TextColor3 = item.isLocked and Color3.fromRGB(120, 80, 80)
                    or item.isPaused and Color3.fromRGB(130, 140, 160) or C.danger
            end
            stockL.Font = Enum.Font.GothamBold
            stockL.TextSize = 8
            stockL.TextXAlignment = Enum.TextXAlignment.Right
            stockL.Parent = btn

            btn.MouseButton1Click:Connect(function()
                if item.isLocked then
                    local reason = item.lockReason ~= "" and item.lockReason or "Locked"
                    if statusLabelAB then
                        statusLabelAB.Text = "🔒 " .. item.displayName .. " — " .. reason
                    end
                    return
                end
                if ABCfg.selected[item.key] then
                    ABCfg.selected[item.key] = nil
                else
                    ABCfg.selected[item.key] = true
                end
                AutoBuyBackend.saveConfig()
                renderList()
            end)

            table.insert(itemButtons, btn)
        end

        itemScroll.CanvasSize = UDim2.new(0, 0, 0, #filtered * 26 + 8)
    end

    renderListFn = renderList

    -- ⭐ Daftarkan callback refresh setelah beli
    AutoBuyBackend.onBuySuccess = function()
        if renderListFn then
            pcall(renderListFn)
        end
    end
    searchAB:GetPropertyChangedSignal("Text"):Connect(renderList)

    selAllAB.MouseButton1Click:Connect(function()
        local items = scanByTab(currentBuyTab)
        for _, item in ipairs(items) do
            if not item.isLocked then
                ABCfg.selected[item.key] = true
            end
        end
        AutoBuyBackend.saveConfig()
        renderList()
    end)

    clrAB.MouseButton1Click:Connect(function()
        local items = scanByTab(currentBuyTab)
        for _, item in ipairs(items) do
            ABCfg.selected[item.key] = nil
        end
        AutoBuyBackend.saveConfig()
        renderList()
    end)

    setBuyTab("Seeds")

    -- ==================================================================
    -- AUTO REFRESH per tab
    -- ==================================================================
    local lastRefreshBuyTab = {}

    task.spawn(function()
        while not isGuiDestroyed and buyScroll and buyScroll.Parent do
            task.wait(1)
            local now = os.date("*t")
            if now.sec >= ABCfg.refreshDelaySeconds then
                for tabName, interval in pairs(ABCfg.refreshIntervals) do
                    local lastMin = lastRefreshBuyTab[tabName]
                    if now.min % interval == 0 and lastMin ~= now.min then
                        lastRefreshBuyTab[tabName] = now.min
                        if currentBuyTab == tabName then
                            pcall(renderList)
                        end
                    end
                end
            end
        end
    end)

        task.spawn(function()
        task.wait(0.5)
        pcall(renderList)
    end)

    -- ⭐ AUTO-START kalau config sebelumnya enabled
    if ABCfg.autoBuyEnabled then
        task.spawn(function()
            task.wait(2)
            local cnt = 0
            for _ in pairs(ABCfg.selected) do cnt = cnt + 1 end
            if cnt > 0 then
                AutoBuyBackend.start()
                startABBtn.Text = "⏹️ STOP AUTO BUY"
                startABBtn.BackgroundColor3 = C.danger
                statusLabelAB.Text = string.format("✅ Auto-started (%d item)", cnt)
                print(string.format("[AutoBuy] 🚀 Auto-started dengan %d item", cnt))
            else
                ABCfg.autoBuyEnabled = false
                startABBtn.Text = "▶️ START AUTO BUY"
                startABBtn.BackgroundColor3 = C.success
                statusLabelAB.Text = "Status: Idle (tidak ada item dipilih)"
                AutoBuyBackend.saveConfig()
                print("[AutoBuy] ⚠️ Auto-start dibatalkan: tidak ada item dipilih")
            end
        end)
    end

    print("✅ [AutoBuy] Frontend loaded — 2 sections")
end -- BLOCK 14B

-- shared: diisi di BLOCK 14 (TAB FARM: AUTO SHOVEL)
do -- BLOCK 14: TAB FARM — AUTO SHOVEL
    local farmTab = tabFrames["Farm"]

    local farmScroll = Instance.new("ScrollingFrame")
    farmScroll.Size = UDim2.new(1, -10, 1, -10)
    farmScroll.Position = UDim2.new(0, 5, 0, 5)
    farmScroll.BackgroundTransparency = 1
    farmScroll.BorderSizePixel = 0
    farmScroll.ScrollBarThickness = 4
    farmScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
    farmScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    farmScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    farmScroll.Parent = farmTab

    local farmLayout = Instance.new("UIListLayout")
    farmLayout.Padding = UDim.new(0, 6)
    farmLayout.SortOrder = Enum.SortOrder.LayoutOrder
    farmLayout.Parent = farmScroll

    _G.AoneHub_registry = _G.AoneHub_registry or {}
    _G.AoneHub_registry.farmScroll = farmScroll
    _G.AoneHub_registry.createSection = createSection
    _G.AoneHub_registry.C = C
    
    -- ==================================================================
    -- SECTION: AUTO SHOVEL
    -- ==================================================================
    local ShovelSection = createSection(farmScroll, "🔨 Auto Shovel Sprinkler", "autoShovel")
    ShovelSection.LayoutOrder = 1
    ShovelSection.Size = UDim2.new(1, -10, 0, 89)

    local AutoShovelBtn = Instance.new("TextButton")
    AutoShovelBtn.Size = UDim2.new(1, -20, 0, 32)
    AutoShovelBtn.Position = UDim2.new(0, 10, 0, 28)
    AutoShovelBtn.BackgroundColor3 = C.success
    AutoShovelBtn.BorderSizePixel = 0
    AutoShovelBtn.Font = Enum.Font.GothamBold
    AutoShovelBtn.Text = "▶️ START AUTO SHOVEL"
    AutoShovelBtn.TextColor3 = C.text
    AutoShovelBtn.TextSize = 10
    AutoShovelBtn.Parent = ShovelSection
    Instance.new("UICorner", AutoShovelBtn).CornerRadius = UDim.new(0, 5)

    local AutoShovelStatus = Instance.new("TextLabel")
    AutoShovelStatus.Size = UDim2.new(1, -20, 0, 14)
    AutoShovelStatus.Position = UDim2.new(0, 10, 0, 65)
    AutoShovelStatus.BackgroundTransparency = 1
    AutoShovelStatus.Font = Enum.Font.GothamBold
    AutoShovelStatus.Text = "Status: Idle"
    AutoShovelStatus.TextColor3 = C.textDim
    AutoShovelStatus.TextSize = 9
    AutoShovelStatus.TextXAlignment = Enum.TextXAlignment.Left
    AutoShovelStatus.Parent = ShovelSection

    autoShovelStatus = function(text)
        AutoShovelStatus.Text = text
        AutoShovelStatus.TextColor3 = C.text
        print("[Auto Shovel]", text)
    end

    AutoShovelBtn.MouseButton1Click:Connect(function()
        if isAutoShovelRunning then
            stopAutoShovel()
            AutoShovelBtn.Text = "▶️ START AUTO SHOVEL"
            AutoShovelBtn.BackgroundColor3 = C.success
        else
            AutoShovelBtn.Text = "⏹️ STOP"
            AutoShovelBtn.BackgroundColor3 = C.danger

            task.spawn(function()
                startAutoShovel()

                -- Auto-reset tombol setelah selesai
                local waitStart = os.clock()
                while isAutoShovelRunning and (os.clock() - waitStart) < 300 do
                    task.wait(0.5)
                end

                if AutoShovelBtn and AutoShovelBtn.Parent then
                    AutoShovelBtn.Text = "▶️ START AUTO SHOVEL"
                    AutoShovelBtn.BackgroundColor3 = C.success
                end
            end)
        end
    end)

        -- ==================================================================
    -- SECTION: AUTO COLLECT FRUIT
    -- ==================================================================
    local CollectSection = createSection(farmScroll, "🍓 Auto Collect Fruit", "autoCollect")
    CollectSection.LayoutOrder = 2
    CollectSection.Size = UDim2.new(1, -10, 0, 221)

    -- Info label
    local collectInfoLabel = Instance.new("TextLabel")
    collectInfoLabel.Size = UDim2.new(1, -20, 0, 24)
    collectInfoLabel.Position = UDim2.new(0, 10, 0, 28)
    collectInfoLabel.BackgroundTransparency = 1
    collectInfoLabel.Font = Enum.Font.Gotham
    collectInfoLabel.TextSize = 8
    collectInfoLabel.TextColor3 = C.textDim
    collectInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
    collectInfoLabel.TextWrapped = true
    collectInfoLabel.Text = "🎯 Klik 'Buka List' untuk pilih buah & mutation\nKosong = semua"
    collectInfoLabel.Parent = CollectSection

    -- Tombol Buka List Buah
    local openFruitListBtn = Instance.new("TextButton")
    openFruitListBtn.Size = UDim2.new(0.5, -15, 0, 26)
    openFruitListBtn.Position = UDim2.new(0, 10, 0, 57)
    openFruitListBtn.BackgroundColor3 = C.accent
    openFruitListBtn.BorderSizePixel = 0
    openFruitListBtn.Font = Enum.Font.GothamBold
    openFruitListBtn.Text = "🍎 Pilih Buah"
    openFruitListBtn.TextColor3 = C.text
    openFruitListBtn.TextSize = 9
    openFruitListBtn.AutoButtonColor = false
    openFruitListBtn.Parent = CollectSection
    Instance.new("UICorner", openFruitListBtn).CornerRadius = UDim.new(0, 4)

    -- Tombol Buka List Mutation
    local openMutListBtn = Instance.new("TextButton")
    openMutListBtn.Size = UDim2.new(0.5, -15, 0, 26)
    openMutListBtn.Position = UDim2.new(0.5, 5, 0, 57)
    openMutListBtn.BackgroundColor3 = C.accent
    openMutListBtn.BorderSizePixel = 0
    openMutListBtn.Font = Enum.Font.GothamBold
    openMutListBtn.Text = "✨ Pilih Mutation"
    openMutListBtn.TextColor3 = C.text
    openMutListBtn.TextSize = 9
    openMutListBtn.AutoButtonColor = false
    openMutListBtn.Parent = CollectSection
    Instance.new("UICorner", openMutListBtn).CornerRadius = UDim.new(0, 4)

    -- Input max weight
    local maxWeightLbl = Instance.new("TextLabel")
    maxWeightLbl.Size = UDim2.new(0.55, -15, 0, 14)
    maxWeightLbl.Position = UDim2.new(0, 10, 0, 88)
    maxWeightLbl.BackgroundTransparency = 1
    maxWeightLbl.Text = "⚖️ Max Weight (0 = unlimited):"
    maxWeightLbl.TextColor3 = C.textDim
    maxWeightLbl.Font = Enum.Font.Gotham
    maxWeightLbl.TextSize = 8
    maxWeightLbl.TextXAlignment = Enum.TextXAlignment.Left
    maxWeightLbl.Parent = CollectSection

    local maxWeightInput = Instance.new("TextBox")
    maxWeightInput.Size = UDim2.new(0.45, -15, 0, 20)
    maxWeightInput.Position = UDim2.new(0.55, 5, 0, 85)
    maxWeightInput.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    maxWeightInput.BorderSizePixel = 0
    maxWeightInput.Font = Enum.Font.Gotham
    maxWeightInput.Text = tostring(autoCollectMaxWeight)
    maxWeightInput.TextColor3 = C.text
    maxWeightInput.TextSize = 9
    maxWeightInput.Parent = CollectSection
    Instance.new("UICorner", maxWeightInput).CornerRadius = UDim.new(0, 3)

    maxWeightInput.FocusLost:Connect(function()
        local n = tonumber(maxWeightInput.Text)
        autoCollectMaxWeight = n or 0
        config.autoCollectMaxWeight = autoCollectMaxWeight
        saveConfig()
        maxWeightInput.Text = tostring(autoCollectMaxWeight)
    end)

    -- Toggle Auto Sell
    local autoSellToggle = Instance.new("TextButton")
    autoSellToggle.Size = UDim2.new(1, -20, 0, 26)
    autoSellToggle.Position = UDim2.new(0, 10, 0, 110)
    autoSellToggle.BackgroundColor3 = autoCollectSellEnabled and C.success or Color3.fromRGB(70, 70, 85)
    autoSellToggle.BorderSizePixel = 0
    autoSellToggle.Font = Enum.Font.GothamBold
    autoSellToggle.Text = autoCollectSellEnabled
        and "💰 Auto Sell when Full: ON"
        or "💰 Auto Sell when Full: OFF"
    autoSellToggle.TextColor3 = C.text
    autoSellToggle.TextSize = 9
    autoSellToggle.AutoButtonColor = false
    autoSellToggle.Parent = CollectSection
    Instance.new("UICorner", autoSellToggle).CornerRadius = UDim.new(0, 4)

    autoSellToggle.MouseButton1Click:Connect(function()
        autoCollectSellEnabled = not autoCollectSellEnabled
        config.autoCollectSellEnabled = autoCollectSellEnabled
        saveConfig()
        autoSellToggle.Text = autoCollectSellEnabled
            and "💰 Auto Sell when Full: ON"
            or "💰 Auto Sell when Full: OFF"
        autoSellToggle.BackgroundColor3 = autoCollectSellEnabled and C.success or Color3.fromRGB(70, 70, 85)
    end)

    -- Info kapasitas
    local capacityLabel = Instance.new("TextLabel")
    capacityLabel.Size = UDim2.new(1, -20, 0, 14)
    capacityLabel.Position = UDim2.new(0, 10, 0, 141)
    capacityLabel.BackgroundTransparency = 1
    capacityLabel.Text = "📦 Fruit: -/-"
    capacityLabel.TextColor3 = C.textDim
    capacityLabel.Font = Enum.Font.Gotham
    capacityLabel.TextSize = 8
    capacityLabel.TextXAlignment = Enum.TextXAlignment.Left
    capacityLabel.Parent = CollectSection

    -- Update capacity berkala
    task.spawn(function()
        while CollectSection and CollectSection.Parent and not isGuiDestroyed do
            task.wait(2)
            local current, max = getFruitCapacity()
            local fruitSel = 0
            for _ in pairs(autoCollectSelectedFruits) do fruitSel = fruitSel + 1 end
            local mutSel = 0
            for _ in pairs(autoCollectSelectedMutations) do mutSel = mutSel + 1 end
            capacityLabel.Text = string.format("📦 Fruit: %d/%d | 🍎 %d selected | ✨ %d selected",
                current, max, fruitSel, mutSel)
        end
    end)

    -- Tombol START
    local AutoCollectBtn = Instance.new("TextButton")
    AutoCollectBtn.Size = UDim2.new(1, -20, 0, 32)
    AutoCollectBtn.Position = UDim2.new(0, 10, 0, 160)
    AutoCollectBtn.BackgroundColor3 = C.success
    AutoCollectBtn.BorderSizePixel = 0
    AutoCollectBtn.Font = Enum.Font.GothamBold
    AutoCollectBtn.Text = "▶️ START AUTO COLLECT"
    AutoCollectBtn.TextColor3 = C.text
    AutoCollectBtn.TextSize = 10
    AutoCollectBtn.AutoButtonColor = false
    AutoCollectBtn.Parent = CollectSection
    Instance.new("UICorner", AutoCollectBtn).CornerRadius = UDim.new(0, 5)

    -- Status
    local AutoCollectStatusLbl = Instance.new("TextLabel")
    AutoCollectStatusLbl.Size = UDim2.new(1, -20, 0, 14)
    AutoCollectStatusLbl.Position = UDim2.new(0, 10, 0, 197)
    AutoCollectStatusLbl.BackgroundTransparency = 1
    AutoCollectStatusLbl.Text = "Status: Idle"
    AutoCollectStatusLbl.TextColor3 = C.textDim
    AutoCollectStatusLbl.Font = Enum.Font.GothamBold
    AutoCollectStatusLbl.TextSize = 9
    AutoCollectStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
    AutoCollectStatusLbl.Parent = CollectSection

    -- Binding status
    autoCollectStatus = function(text)
        AutoCollectStatusLbl.Text = text
        AutoCollectStatusLbl.TextColor3 = C.text
        print("[Auto Collect]", text)
    end

    AutoCollectBtn.MouseButton1Click:Connect(function()
        if isAutoCollectRunning then
            stopAutoCollect()
            AutoCollectBtn.Text = "▶️ START AUTO COLLECT"
            AutoCollectBtn.BackgroundColor3 = C.success
        else
            AutoCollectBtn.Text = "⏹️ STOP"
            AutoCollectBtn.BackgroundColor3 = C.danger
            task.spawn(function()
                startAutoCollect()
                local waitStart = os.clock()
                while isAutoCollectRunning and (os.clock() - waitStart) < 3600 do
                    task.wait(0.5)
                end
                if AutoCollectBtn and AutoCollectBtn.Parent then
                    AutoCollectBtn.Text = "▶️ START AUTO COLLECT"
                    AutoCollectBtn.BackgroundColor3 = C.success
                end
            end)
        end
    end)

    -- ============================================================
    -- POPUP: Pilih Buah
    -- ============================================================
    local function openFruitSelector()
        
    -- ⭐ Bungkus dalam ScreenGui dengan DisplayOrder tinggi
    local popupGui = Instance.new("ScreenGui")
    popupGui.Name = "AutoCollectFruitPopup"
    popupGui.DisplayOrder = 999
    popupGui.ResetOnSpawn = false
    popupGui.Parent = playerGui
    
    local popup = Instance.new("Frame")
    popup.Size = UDim2.new(0, 400, 0, 400)
    popup.Position = UDim2.new(0.5, -200, 0.5, -210)
    popup.BackgroundColor3 = C.bg
    popup.BorderSizePixel = 0
    popup.ZIndex = 100
    popup.Parent = popupGui   -- ⭐ parent ke popupGui
    Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 8)
        
        -- Title bar
        local ptb = Instance.new("Frame")
        ptb.Size = UDim2.new(1, 0, 0, 28)
        ptb.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
        ptb.BorderSizePixel = 0
        ptb.Active = true
        ptb.Parent = popup
        Instance.new("UICorner", ptb).CornerRadius = UDim.new(0, 8)

        -- ⭐ Drag handler untuk popup
local dragging = false
local dragStart = nil
local startPos = nil

ptb.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = popup.Position

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
        local delta = input.Position - dragStart
        popup.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)
        
        local pt = Instance.new("TextLabel")
        pt.Size = UDim2.new(1, -50, 1, 0)
        pt.Position = UDim2.new(0, 12, 0, 0)
        pt.BackgroundTransparency = 1
        pt.Text = "🍎 Pilih Buah"
        pt.TextColor3 = C.text
        pt.Font = Enum.Font.GothamBold
        pt.TextSize = 11
        pt.TextXAlignment = Enum.TextXAlignment.Left
        pt.Parent = ptb

        local pclose = Instance.new("TextButton")
        pclose.Size = UDim2.new(0, 22, 0, 22)
        pclose.Position = UDim2.new(1, -26, 0, 3)
        pclose.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
        pclose.Text = "✕"
        pclose.TextColor3 = Color3.fromRGB(255, 120, 120)
        pclose.Font = Enum.Font.GothamBold
        pclose.TextSize = 11
        pclose.BorderSizePixel = 0
        pclose.AutoButtonColor = false
        pclose.Parent = ptb
        Instance.new("UICorner", pclose).CornerRadius = UDim.new(0, 4)
        pclose.MouseButton1Click:Connect(function() 
            popupGui:Destroy()   -- ⭐ destroy popupGui, bukan cuma popup
        end)
        
        -- Search
        local search = Instance.new("TextBox")
        search.Size = UDim2.new(1, -20, 0, 24)
        search.Position = UDim2.new(0, 10, 0, 35)
        search.BackgroundColor3 = C.input
        search.BorderSizePixel = 0
        search.Font = Enum.Font.Gotham
        search.PlaceholderText = "🔍 Cari buah..."
        search.Text = ""
        search.TextColor3 = C.text
        search.TextSize = 9
        search.ClearTextOnFocus = false
        search.Parent = popup
        Instance.new("UICorner", search).CornerRadius = UDim.new(0, 4)

        -- Buttons
        local sAllBtn = Instance.new("TextButton")
        sAllBtn.Size = UDim2.new(0.5, -15, 0, 22)
        sAllBtn.Position = UDim2.new(0, 10, 0, 65)
        sAllBtn.BackgroundColor3 = C.accent
        sAllBtn.BorderSizePixel = 0
        sAllBtn.Text = "✓ All"
        sAllBtn.TextColor3 = C.text
        sAllBtn.Font = Enum.Font.GothamBold
        sAllBtn.TextSize = 8
        sAllBtn.AutoButtonColor = false
        sAllBtn.Parent = popup
        Instance.new("UICorner", sAllBtn).CornerRadius = UDim.new(0, 3)

        local cAllBtn = Instance.new("TextButton")
        cAllBtn.Size = UDim2.new(0.5, -15, 0, 22)
        cAllBtn.Position = UDim2.new(0.5, 5, 0, 65)
        cAllBtn.BackgroundColor3 = C.danger
        cAllBtn.BorderSizePixel = 0
        cAllBtn.Text = "✕ Clear"
        cAllBtn.TextColor3 = C.text
        cAllBtn.Font = Enum.Font.GothamBold
        cAllBtn.TextSize = 8
        cAllBtn.AutoButtonColor = false
        cAllBtn.Parent = popup
        Instance.new("UICorner", cAllBtn).CornerRadius = UDim.new(0, 3)

        -- Scroll list
        local scr = Instance.new("ScrollingFrame")
        scr.Size = UDim2.new(1, -20, 1, -105)
        scr.Position = UDim2.new(0, 10, 0, 95)
        scr.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        scr.BorderSizePixel = 0
        scr.ScrollBarThickness = 4
        scr.ScrollBarImageColor3 = C.accent
        scr.CanvasSize = UDim2.new(0, 0, 0, 0)
        scr.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scr.Parent = popup
        Instance.new("UICorner", scr).CornerRadius = UDim.new(0, 4)

        local lay = Instance.new("UIListLayout")
        lay.Padding = UDim.new(0, 2)
        lay.SortOrder = Enum.SortOrder.LayoutOrder
        lay.Parent = scr

        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 4)
        pad.PaddingRight = UDim.new(0, 4)
        pad.PaddingTop = UDim.new(0, 4)
        pad.Parent = scr

        local buttons = {}
local function render()
    for _, b in ipairs(buttons) do b:Destroy() end
    buttons = {}

    local s = search.Text:lower()

    -- ⭐ Kumpulkan jadi 2 kategori
    local selectedList = {}
    local unselectedList = {}

    for lower, orig in pairs(KNOWN_FRUITS) do
        if s == "" or lower:find(s, 1, true) then
            if autoCollectSelectedFruits[lower] then
                table.insert(selectedList, orig)
            else
                table.insert(unselectedList, orig)
            end
        end
    end

    -- Sort masing-masing kategori
    table.sort(selectedList)
    table.sort(unselectedList)

    -- Gabung: selected dulu, lalu unselected
    local list = {}
    for _, name in ipairs(selectedList) do
        table.insert(list, name)
    end
    for _, name in ipairs(unselectedList) do
        table.insert(list, name)
    end

    -- Set CanvasSize
    scr.CanvasSize = UDim2.new(0, 0, 0, #list * 24 + 8)
    print("[Debug Render] CanvasSize set:", scr.CanvasSize, "Items:", #list,
          "Selected:", #selectedList, "Unselected:", #unselectedList)

    for i, name in ipairs(list) do
        local isSel = autoCollectSelectedFruits[name:lower()] == true
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -8, 0, 22)
        btn.Position = UDim2.new(0, 4, 0, (i-1) * 24 + 4)
        btn.BackgroundColor3 = isSel and C.success or Color3.fromRGB(55, 55, 70)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.Gotham
        btn.Text = string.format("%s %s", isSel and "✓" or "○", name)
        btn.TextColor3 = C.text
        btn.TextSize = 9
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.LayoutOrder = i
        btn.AutoButtonColor = false
        btn.Visible = true
        btn.ZIndex = 200
        btn.Parent = scr
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
        local p = Instance.new("UIPadding")
        p.PaddingLeft = UDim.new(0, 6)
        p.Parent = btn
        btn.MouseButton1Click:Connect(function()
            local k = name:lower()
            if autoCollectSelectedFruits[k] then
                autoCollectSelectedFruits[k] = nil
            else
                autoCollectSelectedFruits[k] = true
            end
            config.autoCollectSelectedFruits = autoCollectSelectedFruits
            saveConfig()

            -- ⭐ AUTO CLEAR SEARCH BAR
            search.Text = ""

            -- ⭐ Refresh list (selected akan naik ke atas)
            render()
        end)
        table.insert(buttons, btn)
    end
end

        search:GetPropertyChangedSignal("Text"):Connect(render)
        sAllBtn.MouseButton1Click:Connect(function()
            for lower, _ in pairs(KNOWN_FRUITS) do
                autoCollectSelectedFruits[lower] = true
            end
            config.autoCollectSelectedFruits = autoCollectSelectedFruits
            saveConfig()
            render()
        end)
        cAllBtn.MouseButton1Click:Connect(function()
            autoCollectSelectedFruits = {}
            config.autoCollectSelectedFruits = {}
            saveConfig()
            render()
        end)
        -- Set semua descendant ZIndex = 200
        for _, child in ipairs(popup:GetDescendants()) do
            if child:IsA("GuiObject") then
                child.ZIndex = 200
            end
        end
        render()
    end

    -- ============================================================
    -- POPUP: Pilih Mutation
    -- ============================================================
    local function openMutSelector()
    -- ⭐ Bungkus dalam ScreenGui
    local popupGui = Instance.new("ScreenGui")
    popupGui.Name = "AutoCollectMutPopup"
    popupGui.DisplayOrder = 999
    popupGui.ResetOnSpawn = false
    popupGui.Parent = playerGui
    
    local popup = Instance.new("Frame")
    popup.Size = UDim2.new(0, 400, 0, 400)
    popup.Position = UDim2.new(0.5, -200, 0.5, -210)
    popup.BackgroundColor3 = C.bg
    popup.BorderSizePixel = 0
    popup.ZIndex = 100
    popup.Parent = popupGui   -- ⭐
    Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 8)
    
        local ptb = Instance.new("Frame")
        ptb.Size = UDim2.new(1, 0, 0, 28)
        ptb.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
        ptb.BorderSizePixel = 0
        ptb.Active = true
        ptb.Parent = popup
        Instance.new("UICorner", ptb).CornerRadius = UDim.new(0, 8)

        -- ⭐ Drag handler untuk popup
local dragging = false
local dragStart = nil
local startPos = nil

ptb.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = popup.Position

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
        local delta = input.Position - dragStart
        popup.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)
        
        local pt = Instance.new("TextLabel")
        pt.Size = UDim2.new(1, -50, 1, 0)
        pt.Position = UDim2.new(0, 12, 0, 0)
        pt.BackgroundTransparency = 1
        pt.Text = "✨ Pilih Mutation"
        pt.TextColor3 = C.text
        pt.Font = Enum.Font.GothamBold
        pt.TextSize = 11
        pt.TextXAlignment = Enum.TextXAlignment.Left
        pt.Parent = ptb

        local pclose = Instance.new("TextButton")
        pclose.Size = UDim2.new(0, 22, 0, 22)
        pclose.Position = UDim2.new(1, -26, 0, 3)
        pclose.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
        pclose.Text = "✕"
        pclose.TextColor3 = Color3.fromRGB(255, 120, 120)
        pclose.Font = Enum.Font.GothamBold
        pclose.TextSize = 11
        pclose.BorderSizePixel = 0
        pclose.AutoButtonColor = false
        pclose.Parent = ptb
        Instance.new("UICorner", pclose).CornerRadius = UDim.new(0, 4)
        pclose.MouseButton1Click:Connect(function() 
            popupGui:Destroy()   -- ⭐
        end)
            
        local search = Instance.new("TextBox")
        search.Size = UDim2.new(1, -20, 0, 24)
        search.Position = UDim2.new(0, 10, 0, 35)
        search.BackgroundColor3 = C.input
        search.BorderSizePixel = 0
        search.Font = Enum.Font.Gotham
        search.PlaceholderText = "🔍 Cari mutasi..."
        search.Text = ""
        search.TextColor3 = C.text
        search.TextSize = 9
        search.ClearTextOnFocus = false
        search.Parent = popup
        Instance.new("UICorner", search).CornerRadius = UDim.new(0, 4)

        local sAllBtn = Instance.new("TextButton")
        sAllBtn.Size = UDim2.new(0.5, -15, 0, 22)
        sAllBtn.Position = UDim2.new(0, 10, 0, 65)
        sAllBtn.BackgroundColor3 = C.accent
        sAllBtn.BorderSizePixel = 0
        sAllBtn.Text = "✓ All"
        sAllBtn.TextColor3 = C.text
        sAllBtn.Font = Enum.Font.GothamBold
        sAllBtn.TextSize = 8
        sAllBtn.AutoButtonColor = false
        sAllBtn.Parent = popup
        Instance.new("UICorner", sAllBtn).CornerRadius = UDim.new(0, 3)

        local cAllBtn = Instance.new("TextButton")
        cAllBtn.Size = UDim2.new(0.5, -15, 0, 22)
        cAllBtn.Position = UDim2.new(0.5, 5, 0, 65)
        cAllBtn.BackgroundColor3 = C.danger
        cAllBtn.BorderSizePixel = 0
        cAllBtn.Text = "✕ Clear"
        cAllBtn.TextColor3 = C.text
        cAllBtn.Font = Enum.Font.GothamBold
        cAllBtn.TextSize = 8
        cAllBtn.AutoButtonColor = false
        cAllBtn.Parent = popup
        Instance.new("UICorner", cAllBtn).CornerRadius = UDim.new(0, 3)

        local scr = Instance.new("ScrollingFrame")
        scr.Size = UDim2.new(1, -20, 1, -105)
        scr.Position = UDim2.new(0, 10, 0, 95)
        scr.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        scr.BorderSizePixel = 0
        scr.ScrollBarThickness = 4
        scr.ScrollBarImageColor3 = C.accent
        scr.CanvasSize = UDim2.new(0, 0, 0, 0)
        scr.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scr.Parent = popup
        Instance.new("UICorner", scr).CornerRadius = UDim.new(0, 4)

        local lay = Instance.new("UIListLayout")
        lay.Padding = UDim.new(0, 2)
        lay.SortOrder = Enum.SortOrder.LayoutOrder
        lay.Parent = scr

        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 4)
        pad.PaddingRight = UDim.new(0, 4)
        pad.PaddingTop = UDim.new(0, 4)
        pad.Parent = scr

                local buttons = {}
local function render()
    for _, b in ipairs(buttons) do b:Destroy() end
    buttons = {}

    local s = search.Text:lower()

    -- ⭐ Kumpulkan jadi 2 kategori
    local selectedList = {}
    local unselectedList = {}

    for name, _ in pairs(KNOWN_MUTATIONS) do
        local nameLower = name:lower()
        if s == "" or nameLower:find(s, 1, true) then
            if autoCollectSelectedMutations[nameLower] then
                table.insert(selectedList, name)
            else
                table.insert(unselectedList, name)
            end
        end
    end

    -- Sort masing-masing kategori
    table.sort(selectedList)
    table.sort(unselectedList)

    -- Gabung: selected dulu
    local list = {}
    for _, name in ipairs(selectedList) do
        table.insert(list, name)
    end
    for _, name in ipairs(unselectedList) do
        table.insert(list, name)
    end

    -- Set CanvasSize
    scr.CanvasSize = UDim2.new(0, 0, 0, #list * 24 + 8)
    print("[Debug Render] CanvasSize set:", scr.CanvasSize, "Items:", #list,
          "Selected:", #selectedList, "Unselected:", #unselectedList)

    for i, name in ipairs(list) do
        local isSel = autoCollectSelectedMutations[name:lower()] == true
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -8, 0, 22)
        btn.Position = UDim2.new(0, 4, 0, (i-1) * 24 + 4)
        btn.BackgroundColor3 = isSel and C.success or Color3.fromRGB(55, 55, 70)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.Gotham
        btn.Text = string.format("%s %s", isSel and "✓" or "○", name)
        btn.TextColor3 = C.text
        btn.TextSize = 9
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.LayoutOrder = i
        btn.AutoButtonColor = false
        btn.Visible = true
        btn.ZIndex = 200
        btn.Parent = scr
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
        local p = Instance.new("UIPadding")
        p.PaddingLeft = UDim.new(0, 6)
        p.Parent = btn
        btn.MouseButton1Click:Connect(function()
            local k = name:lower()
            if autoCollectSelectedMutations[k] then
                autoCollectSelectedMutations[k] = nil
            else
                autoCollectSelectedMutations[k] = true
            end
            config.autoCollectSelectedMutations = autoCollectSelectedMutations
            saveConfig()

            -- ⭐ AUTO CLEAR SEARCH BAR
            search.Text = ""

            -- ⭐ Refresh list (selected akan naik ke atas)
            render()
        end)
        table.insert(buttons, btn)
    end
        end

        search:GetPropertyChangedSignal("Text"):Connect(render)
        sAllBtn.MouseButton1Click:Connect(function()
            for name, _ in pairs(KNOWN_MUTATIONS) do
                autoCollectSelectedMutations[name:lower()] = true
            end
            config.autoCollectSelectedMutations = autoCollectSelectedMutations
            saveConfig()
            render()
        end)
        cAllBtn.MouseButton1Click:Connect(function()
            autoCollectSelectedMutations = {}
            config.autoCollectSelectedMutations = {}
            saveConfig()
            render()
        end)
        -- Set semua descendant ZIndex = 200
        for _, child in ipairs(popup:GetDescendants()) do
            if child:IsA("GuiObject") then
                child.ZIndex = 200
            end
        end
        render()
    end

openFruitListBtn.MouseButton1Click:Connect(function()
    openFruitSelector()
end)

openMutListBtn.MouseButton1Click:Connect(function()
    openMutSelector()
end)
    
    -- Load initial
    task.spawn(function()
    task.wait(0.5)
    loadMutationList()
    loadFruitList()
    
    local fruitCount = 0
    for _ in pairs(KNOWN_FRUITS or {}) do fruitCount = fruitCount + 1 end
    local mutCount = 0
    for _ in pairs(KNOWN_MUTATIONS or {}) do mutCount = mutCount + 1 end
        
    if config.autoCollectSelectedFruits then
        autoCollectSelectedFruits = config.autoCollectSelectedFruits
    end
    if config.autoCollectSelectedMutations then
        autoCollectSelectedMutations = config.autoCollectSelectedMutations
    end
end)
end -- BLOCK 14

do -- BLOCK 14C: FRUIT WEIGHT FARM (isolated)
    local farmScroll = _G.AoneHub_registry.farmScroll
    local createSection = _G.AoneHub_registry.createSection
    local C = _G.AoneHub_registry.C
        
    if not farmScroll or not createSection then
        warn("[AoneHub] FruitWeightFarm: registry tidak lengkap")
        return
    end
    
    -- ══════════════════════════════════════════════════════════════
    -- SECTION: FRUIT WEIGHT FARM
    -- ══════════════════════════════════════════════════════════════
    do  -- SUB-BLOCK: FruitWeightFarm (isolated)
        -- ============================================================
        -- STATE ISOLATION (Tanpa 'local' agar tidak Out of Registers)
        -- ============================================================
        FWF_Config = {
            maxWeight = 50,
            shovelInterval = 0.5,
            scanInterval = 10,
            selectedFruits = {},
        }
        
        FWF_State = {
            isRunning = false,
            currentCycle = 0,
            totalShoveled = 0,
        }
        
        FWF_UIRefs = {}
        
        -- Ambil langsung dari ReplicatedStorage agar tidak error nil
        RemoveItemRE = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("Remove_Item")
        DeleteObjectRE = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("DeleteObject")
                
        -- ⭐ LOAD dari AoneHub config
        if _G.AoneHub_Config then
            if _G.AoneHub_Config.fwfMaxWeight then
                FWF_Config.maxWeight = _G.AoneHub_Config.fwfMaxWeight
            end
            if _G.AoneHub_Config.fwfShovelInterval then
                FWF_Config.shovelInterval = _G.AoneHub_Config.fwfShovelInterval
            end
            if _G.AoneHub_Config.fwfScanInterval then
                FWF_Config.scanInterval = _G.AoneHub_Config.fwfScanInterval
            end
            if _G.AoneHub_Config.fwfSelectedFruits then
                FWF_Config.selectedFruits = _G.AoneHub_Config.fwfSelectedFruits
            end
        end

        -- ⭐ SAVE ke AoneHub config
        function FWF_SaveConfig()
            if _G.AoneHub_Config and _G.AoneHub_SaveConfig then
                _G.AoneHub_Config.fwfMaxWeight = FWF_Config.maxWeight
                _G.AoneHub_Config.fwfShovelInterval = FWF_Config.shovelInterval
                _G.AoneHub_Config.fwfScanInterval = FWF_Config.scanInterval
                _G.AoneHub_Config.fwfSelectedFruits = FWF_Config.selectedFruits
                _G.AoneHub_SaveConfig()
            end
        end

        -- ============================================================
        -- HELPERS
        -- ============================================================
        FWF_ShovelToolName = "Shovel [Destroy Plants]"
        
        function FWF_IsMyFruit(fruit)
            local ancestor = fruit:FindFirstAncestor("Important")
            if not ancestor then return false end
            local data = ancestor:FindFirstChild("Data")
            if not data then return false end
            local owner = data:FindFirstChild("Owner")
            if not owner or not owner.Value then return false end
            return owner.Value == player.Name
        end
        
        function FWF_GetSeedValue(fruit)
            local seedAttr = fruit:GetAttribute("Seed")
            if seedAttr then return seedAttr end
            local itemSeed = fruit:FindFirstChild("Item_Seed")
            if itemSeed then return itemSeed.Value end
            local plant = fruit:FindFirstAncestorWhichIsA("Model")
            if plant then
                local ps = plant:GetAttribute("Seed")
                if ps then return ps end
                local pis = plant:FindFirstChild("Item_Seed")
                if pis then return pis.Value end
            end
            return nil
        end
        
        function FWF_PredictWeight(fruit)
            local seedValue = FWF_GetSeedValue(fruit)
            if not seedValue then return nil end
            local plant = fruit:FindFirstAncestorWhichIsA("Model")
            local plantName = plant and plant.Name or fruit.Name
            
            local baseWeight = nil
            local CalculateWeightModule = nil
            pcall(function()
                CalculateWeightModule = require(ReplicatedStorage.Calculate_Weight)
            end)
            
            if CalculateWeightModule and CalculateWeightModule.Calculate_Weight then
                local ok, result = pcall(CalculateWeightModule.Calculate_Weight, seedValue, plantName)
                if ok and result then baseWeight = result end
            end
            if not baseWeight then
                local fw = fruit:FindFirstChild("Weight")
                if fw and fw:IsA("NumberValue") then baseWeight = fw.Value end
                if not baseWeight and plant then
                    local pw = plant:FindFirstChild("Weight")
                    if pw and pw:IsA("NumberValue") then baseWeight = pw.Value end
                end
            end
            if not baseWeight then baseWeight = fruit:GetAttribute("BaseWeight") end
            if not baseWeight then return nil end
            
            local wm = fruit:GetAttribute("WeightMulti") or 1
            if plant then wm = plant:GetAttribute("WeightMulti") or wm end
            return baseWeight * wm
        end
        
        function FWF_FindShovelTool()
            local bp = player:FindFirstChild("Backpack")
            if bp then 
                local t = bp:FindFirstChild(FWF_ShovelToolName)
                if t then return t end 
            end
            local char = player.Character
            if char then 
                local t = char:FindFirstChild(FWF_ShovelToolName)
                if t then return t end 
            end
            return nil
        end
        
        function FWF_EquipShovel()
            local char = player.Character
            if char and char:FindFirstChild(FWF_ShovelToolName) then return true end
            local shovel = FWF_FindShovelTool()
            if not shovel then return false end
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hum then return false end
            pcall(function() hum:EquipTool(shovel) end)
            task.wait(0.3)
            return char:FindFirstChild(FWF_ShovelToolName) ~= nil
        end
        
        function FWF_ShovelFruit(fruit)
            if not fruit or not fruit.Parent then return false end
            if not FWF_IsMyFruit(fruit) then return false end
    
            -- ⭐ Cek favorit sebelum shovel
            if fruit:GetAttribute("Favorited") then 
                return false 
            end
    
            if not FWF_EquipShovel() then return false end

            if fruit:FindFirstChild("Grow") then
                local ok = pcall(function() RemoveItemRE:FireServer(fruit) end)
                if ok then
                    task.wait(0.15)
                    if not fruit.Parent then return true end
                end
            end
            local ok2 = pcall(function() DeleteObjectRE:FireServer(fruit) end)
            if ok2 then
                task.wait(0.15)
                if not fruit.Parent then return true end
            end
            local ok3 = pcall(function() RemoveItemRE:FireServer(fruit) end)
            task.wait(0.15)
            return fruit.Parent == nil
        end
        
        function FWF_ScanFruits()
            local results = { passed = {}, failed = {} }
            for _, fruit in ipairs(CollectionService:GetTagged("Harvestable")) do
                if not (fruit:IsA("Model") and FWF_IsMyFruit(fruit) and fruit.Parent) then continue end
        
                -- ⭐ Tambahkan baris ini untuk skip buah favorit
                if fruit:GetAttribute("Favorited") then continue end
        
                local name = fruit.Name
                if next(FWF_Config.selectedFruits) ~= nil and not FWF_Config.selectedFruits[name] then
                    continue
                end
                local weight = FWF_PredictWeight(fruit)
                if not weight then continue end
                local entry = { fruit = fruit, name = name, weight = weight }
                if weight <= FWF_Config.maxWeight then
                    table.insert(results.failed, entry)
                else
                    table.insert(results.passed, entry)
                end
            end
            table.sort(results.passed, function(a, b) return a.weight > b.weight end)
            table.sort(results.failed, function(a, b) return a.weight > b.weight end)
            return results
        end
        
        -- ============================================================
        -- GET FRUIT NAMES
        -- ============================================================
        function FWF_GetAllFruitNames()
            local names, seen = {}, {}
            local SeedData_local = nil
            pcall(function()
                SeedData_local = require(ReplicatedStorage.Data.SeedData)
            end)
            if SeedData_local then
                for name, _ in pairs(SeedData_local) do
                    if not seen[name] then
                        seen[name] = true
                        table.insert(names, name)
                    end
                end
            end
            if #names == 0 then
                for _, f in ipairs(CollectionService:GetTagged("Harvestable")) do
                    if f:IsA("Model") and not seen[f.Name] then
                        seen[f.Name] = true
                        table.insert(names, f.Name)
                    end
                end
            end
            table.sort(names)
            return names
        end
        
        FWF_ALL_FRUIT_NAMES = FWF_GetAllFruitNames()
        
        -- ============================================================
        -- MONITOR PANEL HELPERS
        -- ============================================================
        function FWF_CreateMonitorPanel(parent, xPos, title, color)
            local panel = Instance.new("Frame")
            panel.Size = UDim2.new(0.5, -5, 1, 0)
            panel.Position = UDim2.new(xPos, 0, 0, 0)
            panel.BackgroundColor3 = C.section
            panel.BorderSizePixel = 0
            panel.Parent = parent
            Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 6)
            
            local titleFrame = Instance.new("Frame")
            titleFrame.Size = UDim2.new(1, 0, 0, 22)
            titleFrame.BackgroundColor3 = color
            titleFrame.BackgroundTransparency = 0.4
            titleFrame.BorderSizePixel = 0
            titleFrame.Parent = panel
            Instance.new("UICorner", titleFrame).CornerRadius = UDim.new(0, 6)
            
            local titleFill = Instance.new("Frame")
            titleFill.Size = UDim2.new(1, 0, 0.5, 0)
            titleFill.Position = UDim2.new(0, 0, 0.5, 0)
            titleFill.BackgroundColor3 = color
            titleFill.BackgroundTransparency = 0.4
            titleFill.BorderSizePixel = 0
            titleFill.Parent = titleFrame
            
            local titleLbl = Instance.new("TextLabel")
            titleLbl.Size = UDim2.new(1, -45, 1, 0)
            titleLbl.Position = UDim2.new(0, 6, 0, 0)
            titleLbl.BackgroundTransparency = 1
            titleLbl.Text = title
            titleLbl.TextColor3 = C.text
            titleLbl.Font = Enum.Font.GothamBold
            titleLbl.TextSize = 8
            titleLbl.TextXAlignment = Enum.TextXAlignment.Left
            titleLbl.Parent = titleFrame
            
            local countLbl = Instance.new("TextLabel")
            countLbl.Size = UDim2.new(0, 35, 1, 0)
            countLbl.Position = UDim2.new(1, -38, 0, 0)
            countLbl.BackgroundTransparency = 1
            countLbl.Text = "0"
            countLbl.TextColor3 = C.text
            countLbl.Font = Enum.Font.GothamBold
            countLbl.TextSize = 9
            countLbl.TextXAlignment = Enum.TextXAlignment.Right
            countLbl.Parent = titleFrame
            
            local bodyScroll = Instance.new("ScrollingFrame")
            bodyScroll.Size = UDim2.new(1, -8, 1, -28)
            bodyScroll.Position = UDim2.new(0, 4, 0, 24)
            bodyScroll.BackgroundTransparency = 1
            bodyScroll.BorderSizePixel = 0
            bodyScroll.ScrollBarThickness = 3
            bodyScroll.ScrollBarImageColor3 = C.accent
            bodyScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
            bodyScroll.ScrollingDirection = Enum.ScrollingDirection.Y
            bodyScroll.Parent = panel
            
            local bodyLayout = Instance.new("UIListLayout")
            bodyLayout.Padding = UDim.new(0, 2)
            bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
            bodyLayout.Parent = bodyScroll
            
            return {
                panel = panel,
                bodyScroll = bodyScroll,
                bodyLayout = bodyLayout,
                countLbl = countLbl,
                titleLbl = titleLbl,
            }
        end
        
        function FWF_ClearAndRender(panelRef, entries, isPassed, emptyText)
            for _, child in ipairs(panelRef.bodyScroll:GetChildren()) do
                if child:IsA("Frame") or child:IsA("TextLabel") then
                    child:Destroy()
                end
            end
            
            if #entries == 0 then
                local empty = Instance.new("TextLabel")
                empty.Size = UDim2.new(1, -8, 0, 22)
                empty.BackgroundTransparency = 1
                empty.Text = emptyText or "✓ Kosong"
                empty.TextColor3 = C.textDim
                empty.Font = Enum.Font.Gotham
                empty.TextSize = 8
                empty.LayoutOrder = 0
                empty.Parent = panelRef.bodyScroll
                task.defer(function()
                    panelRef.bodyScroll.CanvasSize = UDim2.new(0, 0, 0, 26)
                end)
                return
            end
            
            for i, entry in ipairs(entries) do
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, -4, 0, 20)
                row.BackgroundColor3 = isPassed and C.itemPassed or Color3.fromRGB(90, 45, 45)
                row.BorderSizePixel = 0
                row.LayoutOrder = i
                row.Parent = panelRef.bodyScroll
                Instance.new("UICorner", row).CornerRadius = UDim.new(0, 3)
                
                local nameLbl = Instance.new("TextLabel")
                nameLbl.Size = UDim2.new(0.6, 0, 1, 0)
                nameLbl.Position = UDim2.new(0, 5, 0, 0)
                nameLbl.BackgroundTransparency = 1
                nameLbl.Text = entry.name
                nameLbl.TextColor3 = C.text
                nameLbl.Font = Enum.Font.GothamSemibold
                nameLbl.TextSize = 8
                nameLbl.TextXAlignment = Enum.TextXAlignment.Left
                nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
                nameLbl.Parent = row
                
                local weightLbl = Instance.new("TextLabel")
                weightLbl.Size = UDim2.new(0.38, 0, 1, 0)
                weightLbl.Position = UDim2.new(0.61, 0, 0, 0)
                weightLbl.BackgroundTransparency = 1
                weightLbl.Text = string.format("%.2f kg", entry.weight or 0)
                weightLbl.TextColor3 = isPassed and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(255, 150, 150)
                weightLbl.Font = Enum.Font.GothamBold
                weightLbl.TextSize = 8
                weightLbl.TextXAlignment = Enum.TextXAlignment.Right
                weightLbl.Parent = row
                local pad = Instance.new("UIPadding")
                pad.PaddingRight = UDim.new(0, 5)
                pad.Parent = weightLbl
            end
            
            local totalHeight = #entries * 22 + 6
            task.defer(function()
                panelRef.bodyScroll.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
            end)
        end
        
        -- ============================================================
        -- BUILD SECTION UI
        -- ============================================================
        FWF_Section = createSection(farmScroll, "⚖️ Fruit Weight Farm", "fruitWeightFarm")
        FWF_Section.LayoutOrder = 4
        FWF_Section.Size = UDim2.new(1, -10, 0, 580)
        
        -- ============================================================
        -- CONFIG INPUTS
        -- ============================================================
        function FWF_MakeInputRow(parent, yPos, label, value, callback, minVal)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0.55, -15, 0, 20)
            lbl.Position = UDim2.new(0, 10, 0, yPos)
            lbl.BackgroundTransparency = 1
            lbl.Text = label
            lbl.TextColor3 = C.textDim
            lbl.Font = Enum.Font.Gotham
            lbl.TextSize = 9
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = parent
            
            local box = Instance.new("TextBox")
            box.Size = UDim2.new(0.45, -15, 0, 20)
            box.Position = UDim2.new(0.55, 5, 0, yPos)
            box.BackgroundColor3 = C.input
            box.BorderSizePixel = 0
            box.Font = Enum.Font.Gotham
            box.Text = tostring(value)
            box.TextColor3 = C.text
            box.TextSize = 9
            box.ClearTextOnFocus = false
            box.Parent = parent
            Instance.new("UICorner", box).CornerRadius = UDim.new(0, 3)
            box.FocusLost:Connect(function()
                local n = tonumber(box.Text)
                if n and (minVal == nil or n >= minVal) then
                    callback(n)
                    box.Text = tostring(n)
                else
                    box.Text = tostring(value)
                end
            end)
            return box
        end
        
        FWF_MakeInputRow(FWF_Section, 32, "⚖️ Max Weight (shovel ≤):", FWF_Config.maxWeight, function(n)
            FWF_Config.maxWeight = math.max(0, n)
            FWF_SaveConfig()
        end, 0)
        
        FWF_MakeInputRow(FWF_Section, 56, "🔨 Interval Shovel (s):", FWF_Config.shovelInterval, function(n)
            FWF_Config.shovelInterval = math.max(0.1, n)
            FWF_SaveConfig()
        end, 0.1)
        
        FWF_MakeInputRow(FWF_Section, 80, "🔍 Interval Scan (s):", FWF_Config.scanInterval, function(n)
            FWF_Config.scanInterval = math.max(0.5, n)
            FWF_SaveConfig()
        end, 0.5)
        
        -- ============================================================
        -- FRUIT FILTER
        -- ============================================================
        local fwfFilterTitle = Instance.new("TextLabel")
        fwfFilterTitle.Size = UDim2.new(1, -20, 0, 16)
        fwfFilterTitle.Position = UDim2.new(0, 10, 0, 108)
        fwfFilterTitle.BackgroundTransparency = 1
        fwfFilterTitle.Text = "🍎 Filter Buah (kosong = semua):"
        fwfFilterTitle.TextColor3 = C.text
        fwfFilterTitle.Font = Enum.Font.GothamBold
        fwfFilterTitle.TextSize = 9
        fwfFilterTitle.TextXAlignment = Enum.TextXAlignment.Left
        fwfFilterTitle.Parent = FWF_Section
        
        local fwfSelAll = Instance.new("TextButton")
        fwfSelAll.Size = UDim2.new(0.5, -15, 0, 20)
        fwfSelAll.Position = UDim2.new(0, 10, 0, 128)
        fwfSelAll.BackgroundColor3 = C.accent
        fwfSelAll.Text = "✓ All"
        fwfSelAll.TextColor3 = C.text
        fwfSelAll.Font = Enum.Font.GothamBold
        fwfSelAll.TextSize = 9
        fwfSelAll.BorderSizePixel = 0
        fwfSelAll.AutoButtonColor = false
        fwfSelAll.Parent = FWF_Section
        Instance.new("UICorner", fwfSelAll).CornerRadius = UDim.new(0, 3)
        
        local fwfSelClr = Instance.new("TextButton")
        fwfSelClr.Size = UDim2.new(0.5, -15, 0, 20)
        fwfSelClr.Position = UDim2.new(0.5, 5, 0, 128)
        fwfSelClr.BackgroundColor3 = C.danger
        fwfSelClr.Text = "✕ Clear"
        fwfSelClr.TextColor3 = C.text
        fwfSelClr.Font = Enum.Font.GothamBold
        fwfSelClr.TextSize = 9
        fwfSelClr.BorderSizePixel = 0
        fwfSelClr.AutoButtonColor = false
        fwfSelClr.Parent = FWF_Section
        Instance.new("UICorner", fwfSelClr).CornerRadius = UDim.new(0, 3)
        
        local fwfSearch = Instance.new("TextBox")
        fwfSearch.Size = UDim2.new(1, -20, 0, 20)
        fwfSearch.Position = UDim2.new(0, 10, 0, 152)
        fwfSearch.BackgroundColor3 = C.input
        fwfSearch.BorderSizePixel = 0
        fwfSearch.Font = Enum.Font.Gotham
        fwfSearch.PlaceholderText = "🔍 Cari buah..."
        fwfSearch.Text = ""
        fwfSearch.TextColor3 = C.text
        fwfSearch.TextSize = 9
        fwfSearch.ClearTextOnFocus = false
        fwfSearch.Parent = FWF_Section
        Instance.new("UICorner", fwfSearch).CornerRadius = UDim.new(0, 4)
        
        local fwfListScroll = Instance.new("ScrollingFrame")
        fwfListScroll.Size = UDim2.new(1, -20, 0, 140)
        fwfListScroll.Position = UDim2.new(0, 10, 0, 176)
        fwfListScroll.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        fwfListScroll.BorderSizePixel = 0
        fwfListScroll.ScrollBarThickness = 4
        fwfListScroll.ScrollBarImageColor3 = C.accent
        fwfListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        fwfListScroll.ScrollingDirection = Enum.ScrollingDirection.Y
        fwfListScroll.Parent = FWF_Section
        Instance.new("UICorner", fwfListScroll).CornerRadius = UDim.new(0, 4)
        
        local fwfLayout = Instance.new("UIListLayout")
        fwfLayout.Padding = UDim.new(0, 2)
        fwfLayout.SortOrder = Enum.SortOrder.LayoutOrder
        fwfLayout.Parent = fwfListScroll
        
        local fwfRowBtns = {}
        
        local function FWF_RenderFruitList()
            for _, b in ipairs(fwfRowBtns) do b:Destroy() end
            fwfRowBtns = {}
            
            local search = fwfSearch.Text:lower()
            local selectedList, unselectedList = {}, {}
            
            for _, name in ipairs(FWF_ALL_FRUIT_NAMES) do
                if search == "" or name:lower():find(search, 1, true) then
                    if FWF_Config.selectedFruits[name] then
                        table.insert(selectedList, name)
                    else
                        table.insert(unselectedList, name)
                    end
                end
            end
            
            local displayList = {}
            for _, name in ipairs(selectedList) do table.insert(displayList, name) end
            for _, name in ipairs(unselectedList) do table.insert(displayList, name) end
            
            for i, name in ipairs(displayList) do
                local isSel = FWF_Config.selectedFruits[name] == true
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, -8, 0, 20)
                btn.BackgroundColor3 = isSel and C.success or Color3.fromRGB(55, 55, 70)
                btn.BorderSizePixel = 0
                btn.Font = Enum.Font.Gotham
                btn.Text = string.format("%s %s", isSel and "✓" or "○", name)
                btn.TextColor3 = C.text
                btn.TextSize = 8
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.LayoutOrder = i
                btn.AutoButtonColor = false
                btn.Parent = fwfListScroll
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
                local pad = Instance.new("UIPadding")
                pad.PaddingLeft = UDim.new(0, 6)
                pad.Parent = btn
                
                btn.MouseButton1Click:Connect(function()
                    if FWF_Config.selectedFruits[name] then
                        FWF_Config.selectedFruits[name] = nil
                    else
                        FWF_Config.selectedFruits[name] = true
                    end
                    if fwfSearch.Text ~= "" then fwfSearch.Text = "" end
                    FWF_RenderFruitList()
                    FWF_SaveConfig()
                end)
                
                table.insert(fwfRowBtns, btn)
            end
            
            task.defer(function()
                fwfListScroll.CanvasSize = UDim2.new(0, 0, 0, #displayList * 22 + 6)
            end)
        end
        
        fwfSearch:GetPropertyChangedSignal("Text"):Connect(FWF_RenderFruitList)
        
        fwfSelAll.MouseButton1Click:Connect(function()
            for _, name in ipairs(FWF_ALL_FRUIT_NAMES) do
                FWF_Config.selectedFruits[name] = true
            end
            FWF_RenderFruitList()
            FWF_SaveConfig()
        end)
        
        fwfSelClr.MouseButton1Click:Connect(function()
            FWF_Config.selectedFruits = {}
            FWF_RenderFruitList()
            FWF_SaveConfig()
        end)
        
        FWF_RenderFruitList()
        
        -- ============================================================
        -- MONITOR (2 PANEL)
        -- ============================================================
        local fwfMonitorTitle = Instance.new("TextLabel")
        fwfMonitorTitle.Size = UDim2.new(1, -20, 0, 16)
        fwfMonitorTitle.Position = UDim2.new(0, 10, 0, 322)
        fwfMonitorTitle.BackgroundTransparency = 1
        fwfMonitorTitle.Text = "📊 Monitor (refresh setelah scan):"
        fwfMonitorTitle.TextColor3 = C.text
        fwfMonitorTitle.Font = Enum.Font.GothamBold
        fwfMonitorTitle.TextSize = 9
        fwfMonitorTitle.TextXAlignment = Enum.TextXAlignment.Left
        fwfMonitorTitle.Parent = FWF_Section
        
        local fwfMonitorContainer = Instance.new("Frame")
        fwfMonitorContainer.Size = UDim2.new(1, -20, 0, 160)
        fwfMonitorContainer.Position = UDim2.new(0, 10, 0, 342)
        fwfMonitorContainer.BackgroundTransparency = 1
        fwfMonitorContainer.Parent = FWF_Section
        
        FWF_UIRefs.leftPanel = FWF_CreateMonitorPanel(
            fwfMonitorContainer, 0, "❌ Akan Di-Shovel", C.danger
        )
        FWF_UIRefs.rightPanel = FWF_CreateMonitorPanel(
            fwfMonitorContainer, 0.5, "✅ Disimpan", C.success
        )
        
        -- ============================================================
        -- START BUTTON
        -- ============================================================
        local fwfStartBtn = Instance.new("TextButton")
        fwfStartBtn.Size = UDim2.new(1, -20, 0, 28)
        fwfStartBtn.Position = UDim2.new(0, 10, 0, 510)
        fwfStartBtn.BackgroundColor3 = C.success
        fwfStartBtn.BorderSizePixel = 0
        fwfStartBtn.Font = Enum.Font.GothamBold
        fwfStartBtn.Text = "▶️ START"
        fwfStartBtn.TextColor3 = C.text
        fwfStartBtn.TextSize = 10
        fwfStartBtn.AutoButtonColor = false
        fwfStartBtn.Parent = FWF_Section
        Instance.new("UICorner", fwfStartBtn).CornerRadius = UDim.new(0, 5)
        FWF_UIRefs.startBtn = fwfStartBtn
        
        local fwfStatusLbl = Instance.new("TextLabel")
        fwfStatusLbl.Size = UDim2.new(1, -20, 0, 14)
        fwfStatusLbl.Position = UDim2.new(0, 10, 0, 542)
        fwfStatusLbl.BackgroundTransparency = 1
        fwfStatusLbl.Text = "Status: Idle"
        fwfStatusLbl.TextColor3 = C.textDim
        fwfStatusLbl.Font = Enum.Font.Gotham
        fwfStatusLbl.TextSize = 8
        fwfStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
        fwfStatusLbl.Parent = FWF_Section
        FWF_UIRefs.statusLbl = fwfStatusLbl
        
        -- ============================================================
        -- RENDER MONITOR
        -- ============================================================
        local function FWF_RenderMonitor(results)
            FWF_UIRefs.leftPanel.countLbl.Text = tostring(#results.failed)
            FWF_UIRefs.leftPanel.titleLbl.Text = string.format("❌ Akan Di-Shovel (%d)", #results.failed)
            FWF_ClearAndRender(FWF_UIRefs.leftPanel, results.failed, false, "✓ Tidak ada")
            
            FWF_UIRefs.rightPanel.countLbl.Text = tostring(#results.passed)
            FWF_UIRefs.rightPanel.titleLbl.Text = string.format("✅ Disimpan (%d)", #results.passed)
            FWF_ClearAndRender(FWF_UIRefs.rightPanel, results.passed, true, "✓ Tidak ada")
        end
        
        local function FWF_SetStatus(text, color)
            if FWF_UIRefs.statusLbl then
                FWF_UIRefs.statusLbl.Text = text
                FWF_UIRefs.statusLbl.TextColor3 = color or C.textDim
            end
            print("[FruitWeightFarm]", text)
        end
        
        -- ============================================================
        -- MAIN LOOP
        -- ============================================================
        local function FWF_StartLoop()
            if FWF_State.isRunning then return end
            FWF_State.isRunning = true
            FWF_State.currentCycle = 0
            FWF_State.totalShoveled = 0
            
            FWF_UIRefs.startBtn.Text = "⏹️ STOP"
            FWF_UIRefs.startBtn.BackgroundColor3 = C.danger
            
            task.spawn(function()
                while FWF_State.isRunning do
                    FWF_State.currentCycle = FWF_State.currentCycle + 1
                    
                    if not FWF_FindShovelTool() then
                        FWF_SetStatus("⚠️ Tidak ada Shovel [Destroy Plants]!", C.warning)
                        task.wait(2)
                        continue
                    end
                    
                    FWF_SetStatus(string.format("🔄 Cycle %d - Scanning...", FWF_State.currentCycle), C.accent)
                    local results = FWF_ScanFruits()
                    FWF_RenderMonitor(results)
                    
                    FWF_SetStatus(string.format(
                        "📊 Cycle %d | Shovel: %d | Simpan: %d",
                        FWF_State.currentCycle, #results.failed, #results.passed
                    ), C.accent)
                    
                    if #results.failed == 0 then
                        FWF_SetStatus(string.format(
                            "✅ Tidak ada yang ≤ %.1f kg. Wait %ss...",
                            FWF_Config.maxWeight, FWF_Config.scanInterval
                        ), C.success)
                        task.wait(FWF_Config.scanInterval)
                        continue
                    end
                    
                    FWF_SetStatus(string.format("🔨 Shuvel %d buah...", #results.failed), C.warning)
                    
                    local shovelCount = 0
                    for i, entry in ipairs(results.failed) do
                        if not FWF_State.isRunning then break end
                        if not entry.fruit or not entry.fruit.Parent then continue end
                        
                        local ok = FWF_ShovelFruit(entry.fruit)
                        if ok then
                            shovelCount = shovelCount + 1
                            FWF_State.totalShoveled = FWF_State.totalShoveled + 1
                            FWF_SetStatus(string.format(
                                "🔨 [%d/%d] %s (%.2f kg)",
                                i, #results.failed, entry.name, entry.weight
                            ), C.warning)
                        else
                            FWF_SetStatus(string.format(
                                "❌ [%d/%d] %s gagal",
                                i, #results.failed, entry.name
                            ), C.danger)
                        end
                        
                        task.wait(FWF_Config.shovelInterval)
                    end
                    
                    FWF_SetStatus(string.format(
                        "✅ Cycle %d selesai. Shovel: %d | Total: %d",
                        FWF_State.currentCycle, shovelCount, FWF_State.totalShoveled
                    ), C.success)
                    
                    task.wait(FWF_Config.scanInterval)
                end
                
                FWF_UIRefs.startBtn.Text = "▶️ START"
                FWF_UIRefs.startBtn.BackgroundColor3 = C.success
                FWF_SetStatus("⏹️ Stopped", C.textDim)
            end)
        end
        
        -- ============================================================
        -- HOOK BUTTON
        -- ============================================================
        fwfStartBtn.MouseButton1Click:Connect(function()
            if FWF_State.isRunning then
                FWF_State.isRunning = false
                FWF_SetStatus("⏹️ Stopping...", C.warning)
            else
                if next(FWF_Config.selectedFruits) == nil then
                    FWF_SetStatus("ℹ️ Tidak ada filter, akan scan SEMUA", C.accent)
                end
                FWF_StartLoop()
            end
        end)
    end
end -- BLOCK 14C
-- ==================================================================
-- BLOCK 15A: AUTO CRAFTING — HELPERS (isolated)
-- ==================================================================
local AutoCraft_Helpers

do
    local CraftingRecipeRegistry_local = require(
        ReplicatedStorage.Data.CraftingData.CraftingRecipeRegistry
    )
    local CraftingService_local = require(
        ReplicatedStorage.Modules.CraftingService.CraftingGlobalObjectService
    )
    local InventoryService_local = require(ReplicatedStorage.Modules.InventoryService)

    local DataService_local = nil
    pcall(function()
        DataService_local = require(ReplicatedStorage.Modules.DataService)
    end)

    local PetBoostRegistry_local = nil
    pcall(function()
        PetBoostRegistry_local = require(ReplicatedStorage.Data.PetRegistry.PetBoostRegistry)
    end)

    local AC_SLOT_INDEX = 1

    local function findWB(machineType)
        for _, obj in ipairs(CollectionService:GetTagged("CraftingObject")) do
            if obj:IsA("Model") then
                if obj:GetAttribute("CraftingObjectType") == machineType then
                    return obj
                end
            end
        end
        return nil
    end

    local function getMachineStatus(workbench)
        if not workbench or not workbench.Parent then
            return "invalid", nil
        end
        local ok, machineData = pcall(function()
            local wbType = workbench:GetAttribute("CraftingObjectType")
            return CraftingService_local:GetIndividualCraftingMachineData(workbench, wbType)
        end)
        if not ok or not machineData then
            return "empty", nil
        end
        local craftingItems = machineData.CraftingItems
        if craftingItems and craftingItems[1] then
            local item = craftingItems[1]
            if item.IsDone then
                return "done", { recipeId = item.RecipeId, timeRemaining = 0 }
            else
                return "waiting", {
                    recipeId = item.RecipeId,
                    timeRemaining = item.TimeRemaining or 0,
                }
            end
        end
        return "empty", { recipeId = machineData.RecipeId }
    end

    local function getRecipesForMachine(machineType)
        local result = {}
        for recipeName, recipe in pairs(CraftingRecipeRegistry_local.ItemRecipes) do
            if recipe.MachineTypes then
                for _, mt in ipairs(recipe.MachineTypes) do
                    if mt == machineType then
                        table.insert(result, { id = recipeName, recipe = recipe })
                        break
                    end
                end
            end
        end
        table.sort(result, function(a, b)
            local ao = a.recipe.LayoutOrder or 9999
            local bo = b.recipe.LayoutOrder or 9999
            if ao ~= bo then return ao < bo end
            return a.id < b.id
        end)
        return result
    end

    local function findItemUUID(itemName, itemType)
        local ok, result = pcall(function()
            return InventoryService_local:Find(itemType, function(itemData)
                local displayName
                if itemType == "PetEgg" then
                    displayName = itemData.EggName
                elseif itemType == "CosmeticCrate" then
                    displayName = itemData.CrateType
                elseif itemType == "SprayBottle" then
                    displayName = itemData.SprayType
                elseif itemType == "PetBoost" then
                    local size = itemData.PetBoostSize
                    local boostType = itemData.PetBoostType
                    local boostName = PetBoostRegistry_local
                        and PetBoostRegistry_local.BoostTypeToPetModelName
                        and PetBoostRegistry_local.BoostTypeToPetModelName[boostType]
                        or ""
                    displayName = string.format("%s %s", tostring(size), tostring(boostName))
                elseif itemType == "Seed Pack" then
                    displayName = itemData.Type
                elseif itemType == "PetShard" then
                    displayName = itemData.ShardType
                else
                    displayName = itemData.ItemName or itemData.ITEM_TYPE or itemType
                end
                return displayName == itemName
            end)
        end)
        if not ok or not result then return nil end
        for uuid, itemData in pairs(result) do
            if not (itemData.IsFavorite or itemData.Favorited) then
                return uuid
            end
        end
        return nil
    end

    local function resolveItemUUID(itemName, itemType)
        local uuid = findItemUUID(itemName, itemType)
        if uuid then return uuid end
        local locations = {}
        local bp = player:FindFirstChild("Backpack")
        if bp then table.insert(locations, bp) end
        if player.Character then table.insert(locations, player.Character) end
        for _, container in ipairs(locations) do
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") then
                    local name = tool:GetAttribute("ItemName")
                        or tool:GetAttribute("EggName")
                        or tool:GetAttribute("CrateType")
                        or tool:GetAttribute("SprayType")
                        or tool.Name
                    if name == itemName then
                        local toolUUID = tool:GetAttribute("ITEM_UUID")
                            or tool:GetAttribute("PET_UUID")
                        if toolUUID then return toolUUID end
                    end
                end
            end
        end
        return nil
    end

    local function checkInputs(recipe)
        if not recipe.Inputs then return true, {} end
        local missing = {}
        for idx, input in ipairs(recipe.Inputs) do
            local itemName = input.ItemData and input.ItemData.ItemName
            local itemType = input.ItemType
            if not itemName then
                table.insert(missing, "[Input " .. idx .. "]")
            else
                if not resolveItemUUID(itemName, itemType) then
                    table.insert(missing, string.format("%s (%s)", itemName, itemType))
                end
            end
        end
        return (#missing == 0), missing
    end

    local function checkCost(recipe)
        if not recipe.Cost then return true, nil end
        if not DataService_local then return true, nil end
        local ok, data = pcall(function() return DataService_local:GetData() end)
        if not ok or not data then return true, nil end
        local cType = recipe.Cost.CurrencyType or "Sheckles"
        local amount = recipe.Cost.Amount or 0
        local balance = 0
        if cType == "Sheckles" then
            balance = data.Sheckles or 0
        elseif data.SpecialCurrency then
            balance = data.SpecialCurrency[cType] or 0
        end
        if balance < amount then
            return false, string.format("%s kurang (%s/%s)", cType, tostring(balance), tostring(amount))
        end
        return true, nil
    end

    local function setRecipe(wb, recipeId)
        local wbType = wb:GetAttribute("CraftingObjectType")
        if not wbType then return false, "no type" end
        local ok, err = pcall(function()
            CraftingService_local:SetRecipe(wb, wbType, recipeId)
        end)
        return ok, err
    end

    local function inputItem(wb, slotIndex, itemName, itemType)
        local wbType = wb:GetAttribute("CraftingObjectType")
        if not wbType then return false, "no type" end
        local uuid = resolveItemUUID(itemName, itemType)
        if not uuid then return false, "UUID not found: " .. tostring(itemName) end
        local payload = { ItemType = itemType, ItemData = { UUID = uuid } }
        local ok, err = pcall(function()
            CraftingService_local:InputItem(wb, wbType, slotIndex, payload)
        end)
        return ok, err
    end

    local function craft(wb)
        local wbType = wb:GetAttribute("CraftingObjectType")
        if not wbType then return false, "no type" end
        local ok, err = pcall(function()
            CraftingService_local:Craft(wb, wbType)
        end)
        return ok, err
    end

    local function claim(wb)
        local wbType = wb:GetAttribute("CraftingObjectType")
        if not wbType then return false, "no type" end
        local ok, err = pcall(function()
            CraftingService_local:Claim(wb, wbType, AC_SLOT_INDEX)
        end)
        return ok, err
    end

    local function processSubmit(wb, recipeId)
        local recipe = CraftingRecipeRegistry_local.ItemRecipes[recipeId]
        if not recipe then return false, "recipe not found" end
        local ok, err = setRecipe(wb, recipeId)
        if not ok then return false, "SetRecipe: " .. tostring(err) end
        task.wait(0.5)
        if recipe.Inputs then
            for slotIndex, input in ipairs(recipe.Inputs) do
                local itemName = input.ItemData and input.ItemData.ItemName
                local itemType = input.ItemType
                if not itemName then return false, "input invalid" end
                local iOk, iErr = inputItem(wb, slotIndex, itemName, itemType)
                if not iOk then return false, "Input " .. itemName .. ": " .. tostring(iErr) end
                task.wait(0.4)
            end
        end
        local cOk, cErr = craft(wb)
        if not cOk then return false, "Craft: " .. tostring(cErr) end
        return true
    end

    -- ⭐ Helper: urutkan resep (selected di atas, lalu LayoutOrder)
local function sortRecipes(recipes, selectedRecipeId)
    table.sort(recipes, function(a, b)
        local aSel = (a.id == selectedRecipeId)
        local bSel = (b.id == selectedRecipeId)
        -- Selected selalu di atas
        if aSel ~= bSel then return aSel end
        -- Lalu urut by LayoutOrder
        local ao = a.recipe.LayoutOrder or 9999
        local bo = b.recipe.LayoutOrder or 9999
        if ao ~= bo then return ao < bo end
        -- Terakhir by nama
        return a.id < b.id
    end)
    return recipes
end

-- ⭐ Helper: filter resep berdasarkan search text (tanpa sort)
local function filterRecipes(recipes, searchText)
    if searchText == "" then return recipes end
    local filtered = {}
    local search = searchText:lower()
    for _, r in ipairs(recipes) do
        if r.id:lower():find(search, 1, true) then
            table.insert(filtered, r)
        end
    end
    return filtered
end
    
    -- ⭐ EKSPOSE ke BLOCK 15B via table
    AutoCraft_Helpers = {
    findWB = findWB,
    getMachineStatus = getMachineStatus,
    getRecipesForMachine = getRecipesForMachine,
    checkInputs = checkInputs,
    checkCost = checkCost,
    processSubmit = processSubmit,
    claim = claim,
    AC_SLOT_INDEX = AC_SLOT_INDEX,
    sortRecipes = sortRecipes,       -- ⭐ BARU
    filterRecipes = filterRecipes,   -- ⭐ BARU
    }
end -- BLOCK 15A

-- ==================================================================
-- BLOCK 15B: AUTO CRAFTING — UI + LOOP (isolated)
-- ==================================================================
do
    local H = AutoCraft_Helpers
    if not H then
        warn("[AoneHub] AutoCraft helpers tidak tersedia")
        return
    end

    local farmScroll = _G.AoneHub_registry and _G.AoneHub_registry.farmScroll
    local createSection = _G.AoneHub_registry and _G.AoneHub_registry.createSection

    if not farmScroll or not createSection then
        warn("[AoneHub] AutoCraft registry tidak lengkap")
        return
    end

    -- ⭐ C lokal untuk Auto Crafting section
    local C = {
        bg        = Color3.fromRGB(28, 28, 35),
        header    = Color3.fromRGB(18, 18, 24),
        accent    = Color3.fromRGB(80, 120, 200),
        success   = Color3.fromRGB(50, 180, 50),
        danger    = Color3.fromRGB(200, 50, 50),
        warning   = Color3.fromRGB(255, 200, 0),
        text      = Color3.fromRGB(240, 240, 240),
        textDim   = Color3.fromRGB(150, 150, 160),
        input     = Color3.fromRGB(55, 55, 70),
        section   = Color3.fromRGB(38, 38, 48),
        itemRow   = Color3.fromRGB(45, 45, 58),
        itemSel   = Color3.fromRGB(60, 130, 220),
    }

    -- ============================================================
    -- ⭐ CONFIG AUTO-CRAFTING (disimpan di `config`)
    -- ============================================================
    if config.autoCraftGearRecipe == nil then config.autoCraftGearRecipe = nil end
    if config.autoCraftSeedRecipe == nil then config.autoCraftSeedRecipe = nil end
    if config.autoCraftGearRunning == nil then config.autoCraftGearRunning = false end
    if config.autoCraftSeedRunning == nil then config.autoCraftSeedRunning = false end

    local AC = {
        MAX_FAILS = 3,
        POLL_INTERVAL = 2,
    }

    -- ⭐ Load state dari config
    local acState = {
        gear = {
            workbench = nil,
            selectedRecipe = config.autoCraftGearRecipe,
            running = false,
            failCount = 0,
        },
        seed = {
            workbench = nil,
            selectedRecipe = config.autoCraftSeedRecipe,
            running = false,
            failCount = 0,
        },
    }

    local WORKBENCH_LIST = {
        {
            key = "gear",
            label = "[GEAR]",
            machineType = "GearEventWorkbench",
            color = Color3.fromRGB(120, 180, 255),
            configRecipeKey = "autoCraftGearRecipe",
            configRunningKey = "autoCraftGearRunning",
        },
        {
            key = "seed",
            label = "[SEED]",
            machineType = "SeedEventWorkbench",
            color = Color3.fromRGB(120, 220, 120),
            configRecipeKey = "autoCraftSeedRecipe",
            configRunningKey = "autoCraftSeedRunning",
        },
    }

    -- ============================================================
    -- SECTION UI
    -- ============================================================
    local ACSection = createSection(farmScroll, "🧰 Auto Crafting", "autoCrafting")
    ACSection.LayoutOrder = 3
    ACSection.Size = UDim2.new(1, -10, 0, 300)

    local acContainer = Instance.new("Frame")
    acContainer.Size = UDim2.new(1, -20, 0, 264)
    acContainer.Position = UDim2.new(0, 10, 0, 30)
    acContainer.BackgroundTransparency = 1
    acContainer.Parent = ACSection

    local acPanelRefs = {}

    for i, cfg in ipairs(WORKBENCH_LIST) do
        local panel = Instance.new("Frame")
        panel.Name = "ACPanel_" .. cfg.key
        panel.Size = UDim2.new(0.5, -5, 1, 0)
        panel.Position = UDim2.new((i-1) * 0.5, (i-1) * 10, 0, 0)
        panel.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
        panel.BorderSizePixel = 0
        panel.Parent = acContainer
        Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 5)

        -- Header
        local hdr = Instance.new("Frame")
        hdr.Size = UDim2.new(1, 0, 0, 22)
        hdr.BackgroundColor3 = cfg.color
        hdr.BackgroundTransparency = 0.7
        hdr.BorderSizePixel = 0
        hdr.Parent = panel
        Instance.new("UICorner", hdr).CornerRadius = UDim.new(0, 5)
        local hdrFill = Instance.new("Frame")
        hdrFill.Size = UDim2.new(1, 0, 0.5, 0)
        hdrFill.Position = UDim2.new(0, 0, 0.5, 0)
        hdrFill.BackgroundColor3 = cfg.color
        hdrFill.BackgroundTransparency = 0.7
        hdrFill.BorderSizePixel = 0
        hdrFill.Parent = hdr

        local hdrLbl = Instance.new("TextLabel")
        hdrLbl.Size = UDim2.new(1, -10, 1, 0)
        hdrLbl.Position = UDim2.new(0, 6, 0, 0)
        hdrLbl.BackgroundTransparency = 1
        hdrLbl.Text = cfg.label
        hdrLbl.TextColor3 = C.text
        hdrLbl.Font = Enum.Font.GothamBold
        hdrLbl.TextSize = 9
        hdrLbl.TextXAlignment = Enum.TextXAlignment.Left
        hdrLbl.Parent = hdr

        -- Status
        local statusLbl = Instance.new("TextLabel")
        statusLbl.Size = UDim2.new(1, -12, 0, 22)
        statusLbl.Position = UDim2.new(0, 6, 0, 26)
        statusLbl.BackgroundTransparency = 1
        statusLbl.Text = "Status: Idle"
        statusLbl.TextColor3 = C.textDim
        statusLbl.Font = Enum.Font.Gotham
        statusLbl.TextSize = 7
        statusLbl.TextXAlignment = Enum.TextXAlignment.Left
        statusLbl.TextYAlignment = Enum.TextYAlignment.Top
        statusLbl.TextWrapped = true
        statusLbl.Parent = panel

        -- Search
        local search = Instance.new("TextBox")
        search.Size = UDim2.new(1, -12, 0, 18)
        search.Position = UDim2.new(0, 6, 0, 52)
        search.BackgroundColor3 = C.input
        search.BorderSizePixel = 0
        search.Font = Enum.Font.Gotham
        search.PlaceholderText = "Search..."
        search.Text = ""
        search.TextColor3 = C.text
        search.TextSize = 8
        search.ClearTextOnFocus = false
        search.Parent = panel
        Instance.new("UICorner", search).CornerRadius = UDim.new(0, 3)

        -- List (naik + lebih tinggi, karena tombol auto-start dihapus)
        local listFrame = Instance.new("Frame")
        listFrame.Size = UDim2.new(1, -12, 0, 160)
        listFrame.Position = UDim2.new(0, 6, 0, 74)
        listFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        listFrame.BorderSizePixel = 0
        listFrame.Parent = panel
        Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 3)

        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, -4, 1, -4)
        scroll.Position = UDim2.new(0, 2, 0, 2)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 3
        scroll.ScrollBarImageColor3 = C.accent
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.Parent = listFrame

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 2)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = scroll

        -- Start Button
        local startBtn = Instance.new("TextButton")
        startBtn.Size = UDim2.new(1, -12, 0, 24)
        startBtn.Position = UDim2.new(0, 6, 1, -30)
        startBtn.BackgroundColor3 = C.success
        startBtn.BorderSizePixel = 0
        startBtn.Font = Enum.Font.GothamBold
        startBtn.Text = "START"
        startBtn.TextColor3 = C.text
        startBtn.TextSize = 9
        startBtn.AutoButtonColor = false
        startBtn.Parent = panel
        Instance.new("UICorner", startBtn).CornerRadius = UDim.new(0, 4)

        acPanelRefs[cfg.key] = {
            panel = panel,
            statusLbl = statusLbl,
            search = search,
            scroll = scroll,
            startBtn = startBtn,
            cfg = cfg,
        }
    end

    -- ============================================================
    -- UI HELPERS
    -- ============================================================
    local function setStatus(key, text, color)
        local ref = acPanelRefs[key]
        if not ref then return end
        ref.statusLbl.Text = "Status: " .. text
        ref.statusLbl.TextColor3 = color or C.text
    end

    local function clearChildren(parent)
        for _, c in ipairs(parent:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
    end

    -- ============================================================
    -- RENDER (⭐ selected di atas)
    -- ============================================================
    local function renderList(key)
        local ref = acPanelRefs[key]
        if not ref then return end
        local st = acState[key]
        local cfg = ref.cfg

        clearChildren(ref.scroll)

        -- Ambil semua resep untuk machine ini
        local recipes = H.getRecipesForMachine(cfg.machineType)

        -- Filter by search
        local filtered = H.filterRecipes(recipes, ref.search.Text)

        -- ⭐ SORT: selected di atas
        H.sortRecipes(filtered, st.selectedRecipe)

        if #filtered == 0 then
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, 0, 0, 24)
            lbl.BackgroundTransparency = 1
            lbl.Text = "No recipe"
            lbl.TextColor3 = C.textDim
            lbl.Font = Enum.Font.Gotham
            lbl.TextSize = 8
            lbl.Parent = ref.scroll
            return
        end

        for i, r in ipairs(filtered) do
            local isSel = (st.selectedRecipe == r.id)
            local recipe = r.recipe
            local timeSec = recipe.TimeToCraft or 0
            local timeStr = string.format("%dm", math.floor(timeSec / 60))
            local costStr = ""
            if recipe.Cost then
                costStr = string.format(" | $%s", tostring(recipe.Cost.Amount))
            end

            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -4, 0, 22)
            btn.BackgroundColor3 = isSel and C.itemSel or C.itemRow
            btn.BorderSizePixel = 0
            btn.Font = Enum.Font.Gotham
            btn.Text = string.format("%s %s%s (%s)",
                isSel and "[✔️]" or "[ ]", r.id, costStr, timeStr)
            btn.TextColor3 = C.text
            btn.TextSize = 7
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.TextTruncate = Enum.TextTruncate.AtEnd
            btn.LayoutOrder = i
            btn.AutoButtonColor = false
            btn.Parent = ref.scroll
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = UDim.new(0, 4)
            pad.Parent = btn

            btn.MouseButton1Click:Connect(function()
                -- ⭐ Toggle: klik lagi untuk unselect
                if st.selectedRecipe == r.id then
                    st.selectedRecipe = nil
                    config[cfg.configRecipeKey] = nil
                else
                    st.selectedRecipe = r.id
                    config[cfg.configRecipeKey] = r.id
                end
                saveConfig()

                -- ⭐ Reset search supaya item yang di-select langsung kelihatan
                if ref.search.Text ~= "" then
                    ref.search.Text = ""
                end

                -- ⭐ Re-render → selected akan naik ke atas
                renderList(key)
            end)
        end
    end

    -- ============================================================
    -- CRAFT LOOP
    -- ============================================================
    local function runLoop(key)
        local st = acState[key]
        local ref = acPanelRefs[key]
        if not ref then return end

        task.spawn(function()
            while st.running do
                st.workbench = H.findWB(ref.cfg.machineType)

                if not st.workbench or not st.workbench.Parent then
                    setStatus(key, "Workbench not found", C.danger)
                    task.wait(2)
                else
                    local recipeId = st.selectedRecipe

                    if not recipeId then
                        st.running = false
                    else
                        local recipe = require(
                            ReplicatedStorage.Data.CraftingData.CraftingRecipeRegistry
                        ).ItemRecipes[recipeId]

                        if not recipe then
                            setStatus(key, "Recipe not found", C.danger)
                            st.running = false
                        else
                            local status, info = H.getMachineStatus(st.workbench)

                            if status == "done" then
                                setStatus(key, "Claiming...", C.warning)
                                local cOk, cErr = H.claim(st.workbench)
                                if cOk then
                                    setStatus(key, "Claimed!", C.success)
                                else
                                    setStatus(key, "Claim fail: " .. tostring(cErr), C.warning)
                                end
                                task.wait(2)

                            elseif status == "waiting" then
                                local rem = info and info.timeRemaining or 0
                                local remStr = string.format("%dm%ds",
                                    math.floor(rem / 60), math.floor(rem % 60))
                                setStatus(key, "Crafting (" .. remStr .. ")", C.accent)
                                task.wait(AC.POLL_INTERVAL)

                            elseif status == "empty" then
                                local hasInputs, missing = H.checkInputs(recipe)
                                if not hasInputs then
                                    setStatus(key, "Missing: " .. table.concat(missing, ", "), C.danger)
                                    st.running = false
                                else
                                    local hasCost, costErr = H.checkCost(recipe)
                                    if not hasCost then
                                        setStatus(key, tostring(costErr), C.danger)
                                        st.running = false
                                    else
                                        setStatus(key, "Submit " .. recipeId, C.text)
                                        local ok, err = H.processSubmit(st.workbench, recipeId)
                                        if ok then
                                            st.failCount = 0
                                            setStatus(key, recipeId .. " sent", C.success)
                                        else
                                            st.failCount = st.failCount + 1
                                            setStatus(key, string.format("(%d/%d) %s",
                                                st.failCount, AC.MAX_FAILS, tostring(err)), C.warning)
                                            if st.failCount >= AC.MAX_FAILS then
                                                setStatus(key, "Failed " .. AC.MAX_FAILS .. "x", C.danger)
                                                st.running = false
                                            else
                                                task.wait(3)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                task.wait(0.5)
            end

            st.running = false
            st.failCount = 0
            if ref.startBtn and ref.startBtn.Parent then
                ref.startBtn.Text = "START"
                ref.startBtn.BackgroundColor3 = C.success
            end
            setStatus(key, "Idle", C.textDim)
        end)
    end

    -- ============================================================
-- START / STOP FUNCTIONS
-- ============================================================
local function startPanel(key)
    local ref = acPanelRefs[key]
    local st = acState[key]
    if not ref or not st then return end

    st.workbench = H.findWB(ref.cfg.machineType)
    if not st.workbench then
        setStatus(key, "Workbench not found", C.warning)
        return
    end
    if not st.selectedRecipe then
        setStatus(key, "Select recipe first!", C.warning)
        return
    end

    st.running = true
    st.failCount = 0
    ref.startBtn.Text = "STOP"
    ref.startBtn.BackgroundColor3 = C.danger
    
    -- ⭐ TAMBAHKAN INI: Simpan status ke config
    config[ref.cfg.configRunningKey] = true
    saveConfig()
    
    runLoop(key)
end

local function stopPanel(key)
    local ref = acPanelRefs[key]
    local st = acState[key]
    if not ref or not st then return end

    st.running = false
    st.failCount = 0
    ref.startBtn.Text = "START"
    ref.startBtn.BackgroundColor3 = C.success
    setStatus(key, "Stopped", C.textDim)
    
    -- ⭐ TAMBAHKAN INI: Hapus/simpan status OFF ke config
    config[ref.cfg.configRunningKey] = false
    saveConfig()
end

    -- ============================================================
    -- EVENT HANDLERS
    -- ============================================================
    for _, cfg in ipairs(WORKBENCH_LIST) do
        local key = cfg.key
        local ref = acPanelRefs[key]
        local st = acState[key]

        -- START button
        ref.startBtn.MouseButton1Click:Connect(function()
            if st.running then
                stopPanel(key)
            else
                startPanel(key)
            end
        end)

        -- Search
        ref.search:GetPropertyChangedSignal("Text"):Connect(function()
            renderList(key)
        end)
    end

    -- ============================================================
-- INIT
-- ============================================================
task.spawn(function()
    task.wait(0.5)

    for _, cfg in ipairs(WORKBENCH_LIST) do
        local key = cfg.key
        local st = acState[key]

        -- Render list (selected akan di atas)
        renderList(key)

        -- Cek workbench
        local wb = H.findWB(cfg.machineType)
        if wb then
            st.workbench = wb
            local status, info = H.getMachineStatus(wb)
            if status == "waiting" and info then
                local rem = info.timeRemaining or 0
                local remStr = string.format("%dm%ds",
                    math.floor(rem / 60), math.floor(rem % 60))
                setStatus(key, "Crafting (" .. remStr .. ")", C.accent)
            elseif status == "done" then
                setStatus(key, "Ready to claim", C.warning)
            else
                setStatus(key, "Ready", C.success)
            end
        else
            setStatus(key, "Workbench not found", C.warning)
        end
    end

    -- ⭐ TAMBAHKAN BLOK AUTO-START INI:
    task.wait(1)
    for _, cfg in ipairs(WORKBENCH_LIST) do
        local key = cfg.key
        local st = acState[key]
        local isAutoStartOn = config[cfg.configRunningKey] == true

        if isAutoStartOn and st.selectedRecipe then
            print(string.format("[AutoCraft] Auto-start %s: %s", key, st.selectedRecipe))
            startPanel(key) -- Ini akan otomatis mengubah tombol menjadi STOP
        elseif isAutoStartOn and not st.selectedRecipe then
            setStatus(key, "Auto-start ON tapi resep belum dipilih", C.warning)
            print(string.format("[AutoCraft] Auto-start %s gagal: resep kosong", key))
        end
    end
end)
    -- ============================================================
    -- AUTO REFRESH STATUS
    -- ============================================================
    task.spawn(function()
        while ACSection and ACSection.Parent and not isGuiDestroyed do
            task.wait(3)
            for _, cfg in ipairs(WORKBENCH_LIST) do
                local st = acState[cfg.key]
                if not st.running then
                    local wb = H.findWB(cfg.machineType)
                    if wb then
                        st.workbench = wb
                        local status, info = H.getMachineStatus(wb)
                        if status == "waiting" and info then
                            local rem = info.timeRemaining or 0
                            local remStr = string.format("%dm%ds",
                                math.floor(rem / 60), math.floor(rem % 60))
                            setStatus(cfg.key, "Crafting (" .. remStr .. ")", C.accent)
                        elseif status == "done" then
                            setStatus(cfg.key, "Ready to claim", C.warning)
                        elseif status == "empty" and st.workbench then
                            setStatus(cfg.key, "Ready", C.success)
                        end
                    else
                        if st.workbench then
                            setStatus(cfg.key, "Workbench gone", C.warning)
                            st.workbench = nil
                        end
                    end
                end
            end
        end
    end)

    print("[AoneHub] Auto Crafting section loaded")
end -- BLOCK 15B

-- ==================================================================
-- BLOCK 16A: AUTO MUTATION - STATE & HELPERS
-- ==================================================================
local AutoMutation_Shared = nil

do 
    local DataService = DataService -- Ambil dari AoneHub utama
    local PetsService = PetsService
    local PetsServiceRE = ReplicatedStorage.GameEvents:WaitForChild("PetsService")
    local PetMutationRE = ReplicatedStorage.GameEvents:WaitForChild("PetMutationMachineService_RE")
    
    local PetMutationMachineData = nil
    pcall(function() PetMutationMachineData = require(ReplicatedStorage.Data.PetMutationMachineData) end)
    local PetMutationRegistry = nil
    pcall(function() PetMutationRegistry = require(ReplicatedStorage.Data.PetRegistry.PetMutationRegistry) end)
    local PetRegistry = nil
    pcall(function() PetRegistry = require(ReplicatedStorage.Data.PetRegistry) end)

    local AONEHUB_CONFIG_PATH = "AoneHub/AoneHub_Gag1.json"
    local cachedAoneHubConfig = nil

    local function loadAoneHubConfig(forceRefresh)
        if cachedAoneHubConfig and not forceRefresh then return cachedAoneHubConfig end
        local ok, raw = pcall(readfile, AONEHUB_CONFIG_PATH)
        if not ok or not raw then return nil end
        local ok2, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
        if not ok2 or type(decoded) ~= "table" then return nil end
        cachedAoneHubConfig = decoded
        return decoded
    end

    local function refreshAoneHubConfig()
        cachedAoneHubConfig = nil
        return loadAoneHubConfig(true)
    end

    local function getPresetNamesFromAoneHub()
    -- ⭐ Baca dari config memori AoneHub, bukan dari file
    local config = _G.AoneHub_Config
    if not config or not config.teamPresets then return {} end
    local names = {}
    for name, _ in pairs(config.teamPresets) do table.insert(names, name) end
    table.sort(names)
    return names
end

local function getPresetUUIDs(presetName)
    if not presetName then return {} end
    -- ⭐ Baca dari config memori AoneHub, bukan dari file
    local config = _G.AoneHub_Config
    if not config or not config.teamPresets then return {} end
    local preset = config.teamPresets[presetName]
    if not preset or not preset.pets then return {} end
    local uuids = {}
    for _, petInfo in ipairs(preset.pets) do
        if petInfo.UUID then table.insert(uuids, petInfo.UUID) end
    end
    return uuids
    end

    -- ⭐ PENTING: Gunakan tabel dari config utama AoneHub secara langsung
-- agar saat saveConfig() dipanggil, data state ini ikut tersimpan.
local state

if _G.AoneHub_Config then
    -- Jika config utama sudah punya autoMutationState, pakai itu
    _G.AoneHub_Config.autoMutationState = _G.AoneHub_Config.autoMutationState or {
        selectedPetTypes = {},
        unwantedMutations = {},
        levelingPreset = nil,
        machinePreset = nil,
        claimPreset = nil,
        levelingSlot = 1,
        machineSlot = 2,
        claimSlot = 3,
        minLevel = 50,
        isRunning = false,
        currentPhase = "idle",
        lastLoadoutSlot = nil,
    }
    state = _G.AoneHub_Config.autoMutationState
else
    -- Fallback jika _G tidak ada (harusnya tidak terjadi)
    state = {
        selectedPetTypes = {},
        unwantedMutations = {},
        levelingPreset = nil,
        machinePreset = nil,
        claimPreset = nil,
        levelingSlot = 1,
        machineSlot = 2,
        claimSlot = 3,
        minLevel = 50,
        isRunning = false,
        currentPhase = "idle",
        lastLoadoutSlot = nil,
    }
    end

    -- ⭐ Simpan referensi state ke config utama AoneHub
    if _G.AoneHub_Config then
        _G.AoneHub_Config.autoMutationState = state
    end

    -- Helper Data
    local function getPetInventory()
        local data = DataService:GetData()
        if not data or not data.PetsData then return {} end
        return data.PetsData.PetInventory.Data or {}
    end
    
    local function getPetData(uuid) return getPetInventory()[uuid] end
    local function getPetType(uuid) local p = getPetData(uuid); return p and (p.PetType or (p.PetData and p.PetData.PetType)) or "Unknown" end
    local function getPetLevel(uuid) local p = getPetData(uuid); return p and (p.Level or (p.PetData and p.PetData.Level)) or 0 end
    local function isPetFavorited(uuid) local p = getPetData(uuid); return p and (p.IsFavorite or (p.PetData and p.PetData.IsFavorite)) or false end
    
    local function getPetMutation(uuid)
        local p = getPetData(uuid)
        if not p then return nil end
        local mt = p.MutationType or (p.PetData and p.PetData.MutationType)
        if not mt or mt == "None" or mt == "Normal" or mt == "m" then return nil end
        if PetMutationRegistry and PetMutationRegistry.EnumToPetMutation then
            return PetMutationRegistry.EnumToPetMutation[mt] or mt
        end
        return mt
    end

    local function getEquippedPets()
        local data = DataService:GetData()
        return (data and data.PetsData and data.PetsData.EquippedPets) or {}
    end

    local function getMachineData()
        local data = DataService:GetData()
        return data and data.PetMutationMachine
    end

    -- ⭐ Simpan state ke config utama AoneHub
    if _G.AoneHub_Config then
        _G.AoneHub_Config.autoMutationState = state
    end
    
    -- Ekpos ke blok berikutnya
    AutoMutation_Shared = {
        state = state,
        loadAoneHubConfig = loadAoneHubConfig,
        refreshAoneHubConfig = refreshAoneHubConfig,
        getPresetNamesFromAoneHub = getPresetNamesFromAoneHub,
        getPresetUUIDs = getPresetUUIDs,
        getPetInventory = getPetInventory,
        getPetData = getPetData,
        getPetType = getPetType,
        getPetLevel = getPetLevel,
        isPetFavorited = isPetFavorited,
        getPetMutation = getPetMutation,
        getEquippedPets = getEquippedPets,
        getMachineData = getMachineData,
        DataService = DataService,
        PetsService = PetsService,
        PetsServiceRE = PetsServiceRE,
        PetMutationRE = PetMutationRE,
        PetMutationRegistry = PetMutationRegistry,
        PetRegistry = PetRegistry,
    }
end

-- ==================================================================
-- BLOCK 16B: AUTO MUTATION - CORE LOGIC
-- ==================================================================
local AutoMutation_Logic = nil

do
    local S = AutoMutation_Shared
    if not S then return end

    local state = S.state
    local DataService = S.DataService
    local PetsService = S.PetsService
    local PetsServiceRE = S.PetsServiceRE
    local PetMutationRE = S.PetMutationRE

    local function setLog(text)
        if _G.AoneHub_AM_SetLog then _G.AoneHub_AM_SetLog(text) end
        print("[AutoMutation]", text)
    end
    local function setStatus(text)
        if _G.AoneHub_AM_SetStatus then _G.AoneHub_AM_SetStatus(text) end
    end

    local function verifyEquippedMatchesPreset(presetName)
        if not presetName then return true, {}, {} end
        local expected = S.getPresetUUIDs(presetName)
        local equipped = S.getEquippedPets()
        if #expected == 0 then return true, {}, {} end
        local expSet, eqSet = {}, {}
        for _, u in ipairs(expected) do expSet[u] = true end
        for _, u in ipairs(equipped) do eqSet[u] = true end
        
        local toUnequip, toEquip = {}, {}
        for _, u in ipairs(equipped) do if not expSet[u] then table.insert(toUnequip, u) end end
        for _, u in ipairs(expected) do if not eqSet[u] then table.insert(toEquip, u) end end
        return (#toUnequip == 0 and #toEquip == 0), toUnequip, toEquip
    end

    local function fixEquippedToMatchPreset(presetName)
        local isMatch, toUnequip, toEquip = verifyEquippedMatchesPreset(presetName)
        if isMatch then return true end
        for _, uuid in ipairs(toUnequip) do pcall(function() PetsService:UnequipPet(uuid) end); task.wait(0.4) end
        for _, uuid in ipairs(toEquip) do 
            if S.getPetData(uuid) then pcall(function() PetsService:EquipPet(uuid, CFrame.new(0,10,0)) end); task.wait(0.4) end
        end
        task.wait(1)
        return (verifyEquippedMatchesPreset(presetName))
    end

    local function swapLoadout(slotNumber, presetName)
        if not slotNumber then return false end
        if state.lastLoadoutSlot == slotNumber then
            if presetName then
                local isMatch = verifyEquippedMatchesPreset(presetName)
                if isMatch then return true end
                return fixEquippedToMatchPreset(presetName)
            end
            return true
        end
        pcall(function() PetsServiceRE:FireServer("SwapPetLoadout", slotNumber) end)
        task.wait(6)
        state.lastLoadoutSlot = slotNumber
        if presetName then
            local isMatch = verifyEquippedMatchesPreset(presetName)
            if isMatch then setLog("OK "..presetName) return true end
            setLog("Fixing "..presetName)
            return fixEquippedToMatchPreset(presetName)
        end
        return true
    end

    local function equipPresetBySlot(slotNumber, presetName)
        if not slotNumber then return false end
        return swapLoadout(slotNumber, presetName)
    end

    local function unequipAllPets()
        local equipped = S.getEquippedPets()
        for _, uuid in ipairs(equipped) do pcall(function() PetsService:UnequipPet(uuid) end); task.wait(0.4) end
        state.lastLoadoutSlot = nil
    end

    local function fireSubmit() return pcall(function() PetMutationRE:FireServer("SubmitHeldPet") end) end
    local function fireStart() return pcall(function() PetMutationRE:FireServer("StartMachine") end) end
    local function fireClaim() return pcall(function() PetMutationRE:FireServer("ClaimMutatedPet") end) end

    local function findPetToolByUUID(uuid)
        local targetType = S.getPetType(uuid)
        local mutation = S.getPetMutation(uuid)
        local expectedName = mutation and (mutation .. " " .. targetType) or targetType
        local locations = {}
        local bp = player:FindFirstChild("Backpack")
        if bp then table.insert(locations, bp) end
        if player.Character then table.insert(locations, player.Character) end
        for _, container in ipairs(locations) do
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and tool:GetAttribute("ItemType") == "Pet" then
                    local toolName = tool.Name
                    if toolName == expectedName or toolName == targetType or tool:GetAttribute("PET_UUID") == uuid then
                        return tool
                    end
                end
            end
        end
        return nil
    end

    local function submitPet(petUUID)
        local petType = S.getPetType(petUUID)
        if table.find(S.getEquippedPets(), petUUID) then
            setStatus("Unequip "..petType)
            pcall(function() PetsService:UnequipPet(petUUID) end)
            task.wait(2)
        end
        setStatus("Cari tool "..petType)
        local waitStart = os.clock()
        local tool = nil
        while (os.clock() - waitStart) < 10 do
            tool = findPetToolByUUID(petUUID)
            if tool then break end
            task.wait(0.5)
        end
        if not tool then setStatus("Tool tidak ada") return false end
        
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return false end
        pcall(function() humanoid:EquipTool(tool) end)
        task.wait(1)
        return fireSubmit()
    end

    local function getMutationStatus(uuid)
        local mutation = S.getPetMutation(uuid)
        if not mutation then return "none" end
        if state.unwantedMutations[mutation] then return "unwanted" end
        return "desired"
    end

    local function getTargetPets()
        local inv = S.getPetInventory()
        local result = {}
        for uuid, _ in pairs(inv) do
            local petType = S.getPetType(uuid)
            if state.selectedPetTypes[petType] and not S.isPetFavorited(uuid) then
                table.insert(result, uuid)
            end
        end
        return result
    end

    local function getPetsNeedingLevel()
        local result = {}
        for _, uuid in ipairs(getTargetPets()) do
            if S.getPetLevel(uuid) < state.minLevel and getMutationStatus(uuid) ~= "desired" then
                table.insert(result, uuid)
            end
        end
        return result
    end

    local function getPetsReadyForSubmit()
        local result = {}
        for _, uuid in ipairs(getTargetPets()) do
            if S.getPetLevel(uuid) >= state.minLevel and getMutationStatus(uuid) ~= "desired" then
                table.insert(result, uuid)
            end
        end
        return result
    end

    local function isMachineBusy()
        local m = S.getMachineData()
        if not m then return false end
        return (m.SubmittedPet ~= nil or m.IsRunning == true or (m.TimeLeft and m.TimeLeft > 0) or m.PetReady == true)
    end

    local function runLoop()
        task.spawn(function()
            local failCount = 0
            while state.isRunning and not isGuiDestroyed do
                task.wait(2)
                if not state.isRunning then break end
                
                local machineData = S.getMachineData()
                local machineBusy = isMachineBusy()

                if not machineBusy and #getTargetPets() > 0 then
                    local allDone = true
                    for _, u in ipairs(getTargetPets()) do if getMutationStatus(u) ~= "desired" then allDone = false break end end
                    if allDone then setStatus("All Done!") state.isRunning = false break end
                end

                if not machineData then
                    failCount = failCount + 1
                    if failCount >= 3 then state.isRunning = false break end
                else
                    failCount = 0
                    if machineData.PetReady then
                        setStatus("Claiming...")
                        if state.claimPreset then equipPresetBySlot(state.claimSlot, state.claimPreset) end
                        fireClaim()
                        task.wait(3)
                        if _G.AoneHub_AM_RenderTargetList then _G.AoneHub_AM_RenderTargetList() end
                        if state.machinePreset then equipPresetBySlot(state.machineSlot, state.machinePreset) end
                        task.wait(1)
                    elseif machineData.IsRunning or (machineData.TimeLeft and machineData.TimeLeft > 0) then
                        local t = machineData.TimeLeft or 0
                        setStatus(string.format("Running (%dm%ds)", math.floor(t/60), t%60))
                        if state.machinePreset then equipPresetBySlot(state.machineSlot, state.machinePreset) end
                    elseif machineData.SubmittedPet and not machineData.IsRunning then
                        setStatus("Starting...")
                        if state.machinePreset then equipPresetBySlot(state.machineSlot, state.machinePreset) end
                        fireStart()
                        task.wait(3)
                    else
                        local ready = getPetsReadyForSubmit()
                        if #ready > 0 then
                            setStatus("Submit "..S.getPetType(ready[1]))
                            if submitPet(ready[1]) then
                                task.wait(3)
                                if _G.AoneHub_AM_RenderTargetList then _G.AoneHub_AM_RenderTargetList() end
                                if state.machinePreset then equipPresetBySlot(state.machineSlot, state.machinePreset) end
                            else task.wait(2) end
                        else
                            local needLvl = getPetsNeedingLevel()
                            if #needLvl > 0 then
                                setStatus("Leveling "..#needLvl.." pet...")
                                if state.levelingPreset then equipPresetBySlot(state.levelingSlot, state.levelingPreset) end
                                local slots = 8 - #S.getEquippedPets()
                                local eqList = {}
                                for i = 1, math.min(slots, #needLvl) do
                                    pcall(function() PetsService:EquipPet(needLvl[i], CFrame.new(0,10,0)) end)
                                    table.insert(eqList, needLvl[i])
                                    task.wait(0.5)
                                end
                                -- Wait Level
                                local tStart = os.clock()
                                while state.isRunning and (os.clock() - tStart) < 900 do
                                    local allDone = true
                                    for _, u in ipairs(eqList) do if S.getPetLevel(u) < state.minLevel then allDone = false break end end
                                    if allDone then break end
                                    task.wait(2)
                                end
                            else
                                setStatus("Menunggu...")
                                task.wait(5)
                            end
                        end
                    end
                end
            end
            setStatus("Stopped")
        end)
    end

    AutoMutation_Logic = {
    runLoop = runLoop,
    getPresetNames = S.getPresetNamesFromAoneHub,
    saveState = function()
        -- Karena state sudah berupa referensi ke config utama,
        -- cukup panggil saveConfig() milik AoneHub.
        if _G.AoneHub_SaveConfig then
            _G.AoneHub_SaveConfig()
        else
            warn("[AutoMutation] Gagal save: _G.AoneHub_SaveConfig tidak ditemukan.")
        end
    end
    }
end

-- ==================================================================
-- BLOCK 16C: AUTO MUTATION - UI
-- ==================================================================
do
    local S = AutoMutation_Shared
    local L = AutoMutation_Logic
    if not S or not L then return end
    
    local state = S.state
    local mutationTab = tabFrames["Mutation"]
    if not mutationTab then return end

    -- Scroll Utama Tab Mutation
    local amScroll = Instance.new("ScrollingFrame")
    amScroll.Size = UDim2.new(1, -10, 1, -10)
    amScroll.Position = UDim2.new(0, 5, 0, 5)
    amScroll.BackgroundTransparency = 1
    amScroll.BorderSizePixel = 0
    amScroll.ScrollBarThickness = 4
    amScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    amScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    amScroll.ScrollingDirection = Enum.ScrollingDirection.Y
    amScroll.Parent = mutationTab

    local amLayout = Instance.new("UIListLayout")
    amLayout.Padding = UDim.new(0, 6)
    amLayout.SortOrder = Enum.SortOrder.LayoutOrder
    amLayout.Parent = amScroll

    -- ============================================================
    -- SECTION 1: CONFIG (Min Level)
    -- ============================================================
    local cfgSection = createSection(amScroll, "⚙️ Configuration", "amConfig")
    cfgSection.LayoutOrder = 1
    cfgSection.Size = UDim2.new(1, -10, 0, 211)
    
    local minLvlLbl = Instance.new("TextLabel")
    minLvlLbl.Size = UDim2.new(0.5, -15, 0, 16)
    minLvlLbl.Position = UDim2.new(0, 10, 0, 28)
    minLvlLbl.BackgroundTransparency = 1
    minLvlLbl.Text = "Minimum Level Target:"
    minLvlLbl.TextColor3 = C.textDim
    minLvlLbl.Font = Enum.Font.Gotham
    minLvlLbl.TextSize = 9
    minLvlLbl.TextXAlignment = Enum.TextXAlignment.Left
    minLvlLbl.Parent = cfgSection

    local minLvlBox = Instance.new("TextBox")
    minLvlBox.Size = UDim2.new(0.5, -15, 0, 20)
    minLvlBox.Position = UDim2.new(0.5, 5, 0, 26)
    minLvlBox.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    minLvlBox.BorderSizePixel = 0
    minLvlBox.Font = Enum.Font.GothamBold
    minLvlBox.Text = tostring(state.minLevel)
    minLvlBox.TextColor3 = C.text
    minLvlBox.TextSize = 9
    minLvlBox.Parent = cfgSection
    Instance.new("UICorner", minLvlBox).CornerRadius = UDim.new(0, 3)
    
    minLvlBox.FocusLost:Connect(function()
        local n = tonumber(minLvlBox.Text)
        if n and n >= 50 and n <= 9999 then
            state.minLevel = math.floor(n)
            L.saveState()
        else
            minLvlBox.Text = tostring(state.minLevel)
        end
    end)

    local presetButtons = {}

    -- ⭐ Helper untuk membuat baris dropdown preset + slot
    local function createPresetRow(yPos, label, presetKey, slotKey)
    -- Label
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 12)
    lbl.Position = UDim2.new(0, 10, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = C.textDim
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 8
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = cfgSection

    -- ⭐ Dropdown Dinamis untuk Preset
    local dropdown = createDynamicDropdown(
        cfgSection,
        UDim2.new(0, 10, 0, yPos + 14),
        state[presetKey] and string.format("📂 %s", state[presetKey]) or "📂 Pilih preset...",
        cfgSection,
        211, -- base height (bisa disesuaikan)
        amScroll
    )
    
    -- Simpan referensi
    presetButtons[presetKey] = dropdown
    presetButtons[slotKey] = nil -- slot button akan dibuat manual

    -- Callback saat dropdown dibuka (populate list)
    dropdown.HeaderButton.MouseButton1Click:Connect(function()
        if not dropdown.IsOpen() then
            local names = S.getPresetNamesFromAoneHub()
            -- Clear existing
            for _, child in pairs(dropdown.ListScroll:GetChildren()) do
                if child:IsA("TextButton") then child:Destroy() end
            end
            
            local isClaim = (presetKey == "claimPreset")
            local list = {}
            if isClaim then table.insert(list, "") end
            for _, n in ipairs(names) do table.insert(list, n) end

            if #list == 0 then
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, -4, 0, dropdown.ItemHeight)
                btn.BackgroundColor3 = Color3.fromRGB(65, 65, 80)
                btn.Text = "❌ Tidak ada preset"
                btn.TextColor3 = C.text
                btn.TextSize = 8
                btn.Parent = dropdown.ListScroll
                return
            end
            for i, presetName in ipairs(list) do
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, -4, 0, dropdown.ItemHeight)
                btn.BackgroundColor3 = (state[presetKey] == presetName) and C.success or Color3.fromRGB(65, 65, 80)
                btn.Text = presetName == "" and "❌ (Kosong)" or string.format("📁 %s", presetName)
                btn.TextColor3 = C.text
                btn.TextSize = 8
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.LayoutOrder = i
                btn.ZIndex = 12
                btn.Parent = dropdown.ListScroll
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
                local pad = Instance.new("UIPadding")
                pad.PaddingLeft = UDim.new(0, 6)
                pad.Parent = btn

                btn.MouseButton1Click:Connect(function()
                    if presetName == "" then
                        state[presetKey] = nil
                        dropdown.HeaderButton.Text = "📂 Pilih preset..."
                    else
                        state[presetKey] = presetName
                        dropdown.HeaderButton.Text = string.format("📂 %s", presetName)
                    end
                    L.saveState()
                    dropdown.Close()
                end)
            end
            dropdown.UpdateSize()
        end
    end)

    -- ⭐ Tombol Slot (tetap manual)
    local slotBtn = Instance.new("TextButton")
    slotBtn.Size = UDim2.new(0.28, -15, 0, 28) -- Sesuaikan tinggi dengan dropdown header (28px)
    slotBtn.Position = UDim2.new(0.72, 5, 0, yPos + 14)
    slotBtn.BackgroundColor3 = C.accent
    slotBtn.BorderSizePixel = 0
    slotBtn.Font = Enum.Font.GothamBold
    slotBtn.Text = "Slot " .. tostring(state[slotKey])
    slotBtn.TextColor3 = C.text
    slotBtn.TextSize = 8
    slotBtn.AutoButtonColor = false
    slotBtn.ZIndex = 5
    slotBtn.Parent = cfgSection
    Instance.new("UICorner", slotBtn).CornerRadius = UDim.new(0, 3)
    
    presetButtons[slotKey] = slotBtn

    slotBtn.MouseButton1Click:Connect(function()
        local next = (state[slotKey] or 1) + 1
        if next > 3 then next = 1 end
        state[slotKey] = next
        slotBtn.Text = "Slot " .. tostring(next)
        L.saveState()
    end)
end

    createPresetRow(51, "Tim Leveling (wajib)", "levelingPreset", "levelingSlot")
    createPresetRow(101, "Tim Machine (wajib)", "machinePreset", "machineSlot") -- ⭐ Jarak diperlebar
    createPresetRow(151, "Tim Claim (opsional)", "claimPreset", "claimSlot")  -- ⭐ Jarak diperlebar

    -- ============================================================
    -- SECTION 2: PET TARGET
    -- ============================================================
    local targetSection = createSection(amScroll, "🎯 Pet Target", "amTarget")
    targetSection.LayoutOrder = 2
    targetSection.Size = UDim2.new(1, -10, 0, 170)

    local targetSearch = Instance.new("TextBox")
    targetSearch.Size = UDim2.new(1, -75, 0, 20)
    targetSearch.Position = UDim2.new(0, 10, 0, 28)
    targetSearch.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    targetSearch.BorderSizePixel = 0
    targetSearch.Font = Enum.Font.Gotham
    targetSearch.PlaceholderText = "Cari pet..."
    targetSearch.Text = ""
    targetSearch.TextColor3 = C.text
    targetSearch.TextSize = 9
    targetSearch.Parent = targetSection
    Instance.new("UICorner", targetSearch).CornerRadius = UDim.new(0, 4)

    local targetAllBtn = Instance.new("TextButton")
    targetAllBtn.Size = UDim2.new(0, 25, 0, 20)
    targetAllBtn.Position = UDim2.new(1, -60, 0, 28)
    targetAllBtn.BackgroundColor3 = C.accent
    targetAllBtn.Text = "All"
    targetAllBtn.TextColor3 = C.text
    targetAllBtn.TextSize = 8
    targetAllBtn.Font = Enum.Font.GothamBold
    targetAllBtn.Parent = targetSection
    Instance.new("UICorner", targetAllBtn).CornerRadius = UDim.new(0, 3)

    local targetClrBtn = Instance.new("TextButton")
    targetClrBtn.Size = UDim2.new(0, 25, 0, 20)
    targetClrBtn.Position = UDim2.new(1, -30, 0, 28)
    targetClrBtn.BackgroundColor3 = C.danger
    targetClrBtn.Text = "Clr"
    targetClrBtn.TextColor3 = C.text
    targetClrBtn.TextSize = 8
    targetClrBtn.Font = Enum.Font.GothamBold
    targetClrBtn.Parent = targetSection
    Instance.new("UICorner", targetClrBtn).CornerRadius = UDim.new(0, 3)

    -- ⭐ PERBAIKAN SCROLL: Kanvas Size otomatis & Scrolling Direction Y
    local targetList = Instance.new("ScrollingFrame")
    targetList.Size = UDim2.new(1, -20, 0, 105)
    targetList.Position = UDim2.new(0, 10, 0, 55)
    targetList.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    targetList.BorderSizePixel = 0
    targetList.ScrollBarThickness = 4
    targetList.CanvasSize = UDim2.new(0, 0, 0, 0)
    targetList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    targetList.ScrollingDirection = Enum.ScrollingDirection.Y
    targetList.Parent = targetSection
    Instance.new("UICorner", targetList).CornerRadius = UDim.new(0, 4)
    
    local tLayout = Instance.new("UIListLayout")
    tLayout.Padding = UDim.new(0, 2)
    tLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tLayout.Parent = targetList

    -- ============================================================
    -- SECTION 3: UNWANTED MUTATION
    -- ============================================================
    local unwantedSection = createSection(amScroll, "❌ Unwanted Mutation", "amUnwanted")
    unwantedSection.LayoutOrder = 3
    unwantedSection.Size = UDim2.new(1, -10, 0, 170)

    local unwantedSearch = Instance.new("TextBox")
    unwantedSearch.Size = UDim2.new(1, -75, 0, 20)
    unwantedSearch.Position = UDim2.new(0, 10, 0, 28)
    unwantedSearch.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    unwantedSearch.BorderSizePixel = 0
    unwantedSearch.Font = Enum.Font.Gotham
    unwantedSearch.PlaceholderText = "Cari mutasi..."
    unwantedSearch.Text = ""
    unwantedSearch.TextColor3 = C.text
    unwantedSearch.TextSize = 9
    unwantedSearch.Parent = unwantedSection
    Instance.new("UICorner", unwantedSearch).CornerRadius = UDim.new(0, 4)

    local unwantedAllBtn = Instance.new("TextButton")
    unwantedAllBtn.Size = UDim2.new(0, 25, 0, 20)
    unwantedAllBtn.Position = UDim2.new(1, -60, 0, 28)
    unwantedAllBtn.BackgroundColor3 = C.accent
    unwantedAllBtn.Text = "All"
    unwantedAllBtn.TextColor3 = C.text
    unwantedAllBtn.TextSize = 8
    unwantedAllBtn.Font = Enum.Font.GothamBold
    unwantedAllBtn.Parent = unwantedSection
    Instance.new("UICorner", unwantedAllBtn).CornerRadius = UDim.new(0, 3)

    local unwantedClrBtn = Instance.new("TextButton")
    unwantedClrBtn.Size = UDim2.new(0, 25, 0, 20)
    unwantedClrBtn.Position = UDim2.new(1, -30, 0, 28)
    unwantedClrBtn.BackgroundColor3 = C.danger
    unwantedClrBtn.Text = "Clr"
    unwantedClrBtn.TextColor3 = C.text
    unwantedClrBtn.TextSize = 8
    unwantedClrBtn.Font = Enum.Font.GothamBold
    unwantedClrBtn.Parent = unwantedSection
    Instance.new("UICorner", unwantedClrBtn).CornerRadius = UDim.new(0, 3)

    -- ⭐ PERBAIKAN SCROLL
    local unwantedList = Instance.new("ScrollingFrame")
    unwantedList.Size = UDim2.new(1, -20, 0, 105)
    unwantedList.Position = UDim2.new(0, 10, 0, 55)
    unwantedList.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    unwantedList.BorderSizePixel = 0
    unwantedList.ScrollBarThickness = 4
    unwantedList.CanvasSize = UDim2.new(0, 0, 0, 0)
    unwantedList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    unwantedList.ScrollingDirection = Enum.ScrollingDirection.Y
    unwantedList.Parent = unwantedSection
    Instance.new("UICorner", unwantedList).CornerRadius = UDim.new(0, 4)
    
    local uLayout = Instance.new("UIListLayout")
    uLayout.Padding = UDim.new(0, 2)
    uLayout.SortOrder = Enum.SortOrder.LayoutOrder
    uLayout.Parent = unwantedList

    -- ============================================================
    -- SECTION 4: PRESET & CONTROL
    -- ============================================================
    local presetSection = createSection(amScroll)
    presetSection.LayoutOrder = 4
    -- ⭐ Perbesar tinggi section agar dropdown muat
    presetSection.Size = UDim2.new(1, -10, 0, 65)
    
    local startAMBtn = Instance.new("TextButton")
    startAMBtn.Size = UDim2.new(1, -20, 0, 26)
    startAMBtn.Position = UDim2.new(0, 10, 0, 10)
    startAMBtn.BackgroundColor3 = C.success
    startAMBtn.Text = "▶️ MULAI AUTO MUTATION"
    startAMBtn.TextColor3 = C.text
    startAMBtn.Font = Enum.Font.GothamBold
    startAMBtn.TextSize = 9
    startAMBtn.Parent = presetSection
    Instance.new("UICorner", startAMBtn).CornerRadius = UDim.new(0, 4)

    local amStatusLbl = Instance.new("TextLabel")
    amStatusLbl.Size = UDim2.new(1, -20, 0, 14)
    amStatusLbl.Position = UDim2.new(0, 10, 0, 41)
    amStatusLbl.BackgroundTransparency = 1
    amStatusLbl.Text = "Status: Idle"
    amStatusLbl.TextColor3 = C.textDim
    amStatusLbl.Font = Enum.Font.GothamBold
    amStatusLbl.TextSize = 8
    amStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
    amStatusLbl.Parent = presetSection

    -- Ekspos callback ke blok logic
    _G.AoneHub_AM_SetStatus = function(txt) 
        if amStatusLbl and amStatusLbl.Parent then 
            amStatusLbl.Text = "Status: " .. txt 
        end 
    end
    _G.AoneHub_AM_SetLog = function(txt) print("[AutoMutation]", txt) end

    -- ============================================================
    -- RENDER LISTS
    -- ============================================================
    local function renderTargetList()
        for _, c in ipairs(targetList:GetChildren()) do 
            if c:IsA("TextButton") then c:Destroy() end 
        end

        -- ⭐ AMBIL SEMUA PET DARI REGISTRY (Seperti v9)
        local allPetTypes = {}
        if S.PetRegistry and S.PetRegistry.PetList then
            for name, _ in pairs(S.PetRegistry.PetList) do
                table.insert(allPetTypes, name)
            end
            table.sort(allPetTypes)
        end

        local search = targetSearch.Text:lower()
        local items = {}
        
        -- Hitung jumlah yang dimiliki
        local invCounts = {}
        for p, _ in pairs(S.getPetInventory()) do
            local pType = S.getPetType(p)
            invCounts[pType] = (invCounts[pType] or 0) + 1
        end

        for _, pType in ipairs(allPetTypes) do
            if search == "" or pType:lower():find(search, 1, true) then
                table.insert(items, {
                    name = pType,
                    count = invCounts[pType] or 0
                })
            end
        end
        
        table.sort(items, function(a,b) 
            local aSel = state.selectedPetTypes[a.name] and 1 or 0
            local bSel = state.selectedPetTypes[b.name] and 1 or 0
            if aSel ~= bSel then return aSel > bSel end
            
            local aOwn = (a.count > 0) and 1 or 0
            local bOwn = (b.count > 0) and 1 or 0
            if aOwn ~= bOwn then return aOwn > bOwn end
            
            return a.name < b.name 
        end)
        
        for i, item in ipairs(items) do
            local isSel = state.selectedPetTypes[item.name]
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -4, 0, 18)
            btn.BackgroundColor3 = isSel and C.success or Color3.fromRGB(55,55,70)
            
            local ownedStr = (item.count > 0) and ("x" .. item.count) or "-"
            btn.Text = string.format("%s %s (%s)", isSel and "+" or "o", item.name, ownedStr)
            
            btn.TextColor3 = C.text
            btn.TextSize = 8
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.LayoutOrder = i
            btn.Parent = targetList
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 2)
            
            local pad = Instance.new("UIPadding")
            pad.PaddingLeft = UDim.new(0, 5)
            pad.Parent = btn
            
            btn.MouseButton1Click:Connect(function()
                state.selectedPetTypes[item.name] = not isSel and true or nil
                L.saveState()
                renderTargetList()
            end)
        end
    end

    local function renderUnwantedList()
        for _, c in ipairs(unwantedList:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        local list = {}
        
        if S.PetMutationRegistry and S.PetMutationRegistry.PetMutationRegistry then
            for name, _ in pairs(S.PetMutationRegistry.PetMutationRegistry) do
                if name ~= "Normal" and name ~= "Rideable" then
                    if unwantedSearch.Text == "" or name:lower():find(unwantedSearch.Text:lower()) then
                        table.insert(list, name)
                    end
                end
            end
        end
        
        table.sort(list, function(a,b) 
            local aSel = state.unwantedMutations[a] and 1 or 0
            local bSel = state.unwantedMutations[b] and 1 or 0
            if aSel ~= bSel then return aSel < bSel end -- Selected di bawah
            return a < b 
        end)
        
        for i, name in ipairs(list) do
            local isSel = state.unwantedMutations[name]
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -4, 0, 18)
            btn.BackgroundColor3 = isSel and C.danger or Color3.fromRGB(55,55,70)
            btn.Text = string.format("%s %s", isSel and "+" or "o", name)
            btn.TextColor3 = C.text
            btn.TextSize = 8
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.LayoutOrder = i
            btn.Parent = unwantedList
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 2)
            btn.MouseButton1Click:Connect(function()
                state.unwantedMutations[name] = not isSel and true or nil
                L.saveState()
                renderUnwantedList()
            end)
        end
    end

    targetSearch:GetPropertyChangedSignal("Text"):Connect(renderTargetList)
    unwantedSearch:GetPropertyChangedSignal("Text"):Connect(renderUnwantedList)
    
    targetAllBtn.MouseButton1Click:Connect(function() 
        for name, _ in pairs(S.PetRegistry.PetList) do 
            state.selectedPetTypes[name] = true 
        end 
        L.saveState() 
        renderTargetList() 
    end)
    
    targetClrBtn.MouseButton1Click:Connect(function() 
        state.selectedPetTypes = {} 
        L.saveState() 
        renderTargetList() 
    end)
    
    unwantedAllBtn.MouseButton1Click:Connect(function() 
        for m, _ in pairs(S.PetMutationRegistry.PetMutationRegistry) do 
            state.unwantedMutations[m] = true 
        end 
        L.saveState() 
        renderUnwantedList() 
    end)
    
    unwantedClrBtn.MouseButton1Click:Connect(function() 
        state.unwantedMutations = {} 
        L.saveState() 
        renderUnwantedList() 
    end)

    _G.AoneHub_AM_RenderTargetList = renderTargetList

    -- ============================================================
    -- START BUTTON
    -- ============================================================
    startAMBtn.MouseButton1Click:Connect(function()
    -- ⭐ FORCE RESET kalau visual masih START tapi state nyangkut di true
    if not state.isRunning and startAMBtn.Text == "⏹️ STOP" then
        startAMBtn.Text = "▶️ MULAI AUTO MUTATION"
        startAMBtn.BackgroundColor3 = C.success
    end

    if state.isRunning then
        -- STOP
        state.isRunning = false
        startAMBtn.Text = "▶️ MULAI AUTO MUTATION"
        startAMBtn.BackgroundColor3 = C.success
        amStatusLbl.Text = "Status: Stopped"
        return
    end

    -- ⭐ GUARD: Cek fitur lain
    if isLeveling then
        amStatusLbl.Text = "⚠️ Stop Auto Leveling dulu!"
        return
    end
    if isRunning then
        amStatusLbl.Text = "⚠️ Stop Auto Hatch dulu!"
        return
    end
    if not state.levelingPreset then
        amStatusLbl.Text = "Pilih preset Leveling!"
        return
    end
    
    if not state.machinePreset then
        amStatusLbl.Text = "Pilih preset Machine!"
        return
    end

    state.isRunning = true
    startAMBtn.Text = "⏹️ STOP"
    startAMBtn.BackgroundColor3 = C.danger
    amStatusLbl.Text = "Status: Starting..."
    renderTargetList()
    L.runLoop()
end)

    -- Init Render Pertama
task.spawn(function()
    task.wait(1)
    
    -- ⭐ Refresh teks dropdown preset dari state yang di-load
    if presetButtons.levelingPreset and presetButtons.levelingPreset.HeaderButton then
        presetButtons.levelingPreset.HeaderButton.Text = state.levelingPreset and ("📂 " .. state.levelingPreset) or "📂 Pilih preset..."
    end
    if presetButtons.machinePreset and presetButtons.machinePreset.HeaderButton then
        presetButtons.machinePreset.HeaderButton.Text = state.machinePreset and ("📂 " .. state.machinePreset) or "📂 Pilih preset..."
    end
    if presetButtons.claimPreset and presetButtons.claimPreset.HeaderButton then
        presetButtons.claimPreset.HeaderButton.Text = state.claimPreset and ("📂 " .. state.claimPreset) or "📂 Pilih preset..."
    end
    if presetButtons.levelingSlot then
        presetButtons.levelingSlot.Text = "Slot " .. tostring(state.levelingSlot)
    end
    if presetButtons.machineSlot then
        presetButtons.machineSlot.Text = "Slot " .. tostring(state.machineSlot)
    end
    if presetButtons.claimSlot then
        presetButtons.claimSlot.Text = "Slot " .. tostring(state.claimSlot)
    end
    
    -- Tampilan tombol Start/Stop
    startAMBtn.Text = state.isRunning and "⏹️ STOP" or "▶️ MULAI AUTO MUTATION"
    startAMBtn.BackgroundColor3 = state.isRunning and C.danger or C.success

    renderTargetList()
    renderUnwantedList()

    -- ⭐ AUTO-START LOGIC
    if state.isRunning then
        print("[AutoMutation] 🚀 Auto-starting karena toggle ON...")
        amStatusLbl.Text = "Status: Auto-starting..."
        L.runLoop()
    end
end)
end
end

-- ==================================================================
-- LOADER BERDASARKAN WORLD
-- ==================================================================

if isInTradeWorld then
    warn("[AoneHub] 🌍 Terdeteksi Trade World. Menjalankan AoneHubTrade...")
    loadAoneHubTrade()
else
    warn("[AoneHub] 🌍 Terdeteksi Main World. Menjalankan AoneHub...")
    loadAoneHubMain()
end
