-- ==================================================================
-- SERVICES & REQUIREMENTS
-- ==================================================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Services untuk Auto Leveling
local DataService = require(ReplicatedStorage.Modules.DataService)
local PetsService = require(ReplicatedStorage.Modules.PetServices.PetsService)
local PetShardService_RE = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetShardService_RE")

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
}

-- ==================================================================
-- CONFIG
-- ==================================================================
local function getConfigPath()
    local basePath = "AoneHub"
    pcall(function() makefolder(basePath) end)
    return basePath .. "/AoneHub_Gag1.json"
end

local SAVE_FILE = getConfigPath()

local config = {
    teamPresets = {},
    weightPresets = {},
    mutationPresets = {},
    advancedPresets = {},
    targetLevel = 50,
    advancedTargetLevel = 500,
    rainbowMode = false,
    unwantedMutations = {},
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
            
            return true
        end
    end
    return false
end

local function saveConfig()
    local s, json = pcall(HttpService.JSONEncode, HttpService, config)
    if s then 
        pcall(writefile, SAVE_FILE, json) 
    end
end

loadConfig()

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

local function sendDiscordWebhook(payload)
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

local function sendDiscordEmbed(title, description, color)
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

local function safeRequire(path)
    local s, r = pcall(function() 
        return require(path) 
    end)
    if s then return r end
    return nil
end

-- ==================================================================
-- AUTO LEVELING STATE
-- ==================================================================
local selectedTeamPreset = config.selectedTeamPreset
local selectedWeightPreset = config.selectedWeightPreset
local selectedAdvancedPreset = config.selectedAdvancedPreset
local selectedMutationPreset = config.selectedMutationPreset
local selectedPetTypes = config.selectedPetTypes or {}
local queuedPets = {}
local allSelectedPets = {}
local equippedTargetPets = {}
local targetLevel = config.targetLevel or 50
local advancedTargetLevel = config.advancedTargetLevel or 500
local isLeveling = false
local isAutoWeight = config.isAutoWeight or false
local isAdvancedLeveling = config.isAdvancedLeveling or false
local isAutoMutation = config.isAutoMutation or false
local rainbowMode = config.rainbowMode or false
local targetSearchText = ""
local petSearchText = ""
local mutationSearchText = ""
local tempPresetPets = {}
local unwantedMutations = config.unwantedMutations or {}
local availableMutations = {}
local editingPresetName = nil
local isGuiDestroyed = false  -- ⭐ TAMBAHKAN INI

-- Forward declarations
local StatusLabel
local updateStatus
local rainbowTask = nil

-- ⭐ Helper function untuk cek apakah masih alive
local function isAlive()
    return not isGuiDestroyed and isLeveling
end

-- Warna yang digunakan
local A = {
    warning = Color3.fromRGB(255, 200, 0),
    danger = Color3.fromRGB(255, 60, 60),
}

-- Daftar warna rainbow
local rainbowColors = {
    Color3.fromRGB(255, 60, 60),   -- 🔴 Merah
    Color3.fromRGB(255, 200, 0),   -- 🟡 Kuning
    Color3.fromRGB(60, 200, 80),   -- 🟢 Hijau
    Color3.fromRGB(30, 100, 220),  -- 🔵 Biru
    Color3.fromRGB(150, 60, 220),  -- 🟣 Ungu
}

local colorIndex = 1
    
-- ==================================================================
-- PET DATA FUNCTIONS
-- ==================================================================
local function getPlayerPetData()
    local playerData = DataService:GetData()
    if playerData and playerData.PetsData then
        return playerData.PetsData
    end
    return nil
end

local function getPetType(petUUID)
    local petsData = Aode.getPlayerPetData()
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

local function getPetLevel(petUUID)
    local petsData = Aode.getPlayerPetData()
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

local function getPetMutationName(petUUID)
    local petsData = Aode.getPlayerPetData()
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

local function getPetDisplayName(petUUID)
    local petType = getPetType(petUUID)
    local mutation = getPetMutationName(petUUID)
    if mutation then
        return string.format("%s %s", mutation, petType)
    end
    return petType
end

local function getPetWeight(petUUID)
    local petsData = Aode.getPlayerPetData()
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

local function getEquippedPets()
    local petsData = Aode.getPlayerPetData()
    if not petsData then return {} end
    return petsData.EquippedPets or {}
end

local function isPetValid(petUUID)
    if not petUUID then return false end
    
    local petsData = Aode.getPlayerPetData()
    if not petsData then return false end
    
    local inventory = petsData.PetInventory.Data
    if not inventory then return false end
    
    return inventory[petUUID] ~= nil
end

local function cleanupInvalidPets()
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

local function equipPet(petUUID)
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

local function unequipPet(petUUID)
    local success = pcall(function()
        PetsService:UnequipPet(petUUID)
    end)
    return success
end

local function getMutationStatus(petUUID)
    local petsData = Aode.getPlayerPetData()
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

local function useCleansingShard(petUUID)
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
local function saveTeamPreset(presetName, petList)
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

local function loadTeamPresets()
    return config.teamPresets or {}
end

local function getPresetUUIDs(presetName)
    local preset = config.teamPresets[presetName]
    if preset then
        local uuids = {}
        for _, petInfo in ipairs(preset.pets) do
            if isPetValid(petInfo.UUID) then
                table.insert(uuids, petInfo.UUID)
            end
        end
        return uuids
    end
    return {}
end

local function deletePreset(presetName)
    if not presetName then return false end
    
    if config.teamPresets[presetName] then
        config.teamPresets[presetName] = nil
        saveConfig()
        return true
    end
    return false
end

local function getWeightTarget()
    return rainbowMode and BASE_WEIGHT_RAINBOW or BASE_WEIGHT_NORMAL
end

local function getLevelTargetForWeight()
    return rainbowMode and LEVEL_TARGET_RAINBOW or LEVEL_TARGET_NORMAL
end

local function getPetsForWeight()
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

local function getPetsForMutation()
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

local function getPetsForAdvanced()
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

local function getPetsForNormalLeveling()
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

local sessionStats = {
    active = false,
    startedAt = 0,
    totalPets = 0,
    modes = {},
    presets = {},
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

local function startDiscordSession()
    sessionStats.active = true
    sessionStats.startedAt = os.time()
    sessionStats.totalPets = #allSelectedPets
    sessionStats.modes = {
        weight = isAutoWeight,
        mutation = isAutoMutation,
        advanced = isAdvancedLeveling,
    }
    sessionStats.presets = {
        team = selectedTeamPreset,
        weight = selectedWeightPreset,
        mutation = selectedMutationPreset,
        advanced = selectedAdvancedPreset,
    }

    local description = string.format(
        "## 🚀 Session Dimulai\n\n" ..
        "**👤 Player:** `%s`\n" ..
        "**🐾 Total Pet:** `%d`\n\n" ..
        "### ⚙️ Mode\n%s\n\n" ..
        "### 📋 Preset\n" ..
        "**Team:** `%s`\n" ..
        "**Weight:** `%s`\n" ..
        "**Mutation:** `%s`\n" ..
        "**Advanced:** `%s`",
        player.Name,
        sessionStats.totalPets,
        getSessionModesText(),
        tostring(sessionStats.presets.team or "-"),
        tostring(sessionStats.presets.weight or "-"),
        tostring(sessionStats.presets.mutation or "-"),
        tostring(sessionStats.presets.advanced or "-")
    )

    sendDiscordEmbed("🟢 AoneHub Session Dimulai", description, 5763719)
end

local function finishDiscordSession(reason)
    if not sessionStats.active then
        return
    end

    local duration = math.max(0, os.time() - sessionStats.startedAt)
    local processed = getSessionProcessedCount()
    local total = sessionStats.totalPets
    local remaining = math.max(0, total - processed)
    local completed = remaining == 0 and reason ~= "stopped"
    local title = completed and "📊 AoneHub Session Selesai" or "📊 AoneHub Session Summary"
    local statusText = completed and "✅ Selesai" or (reason == "stopped" and "⏹️ Dihentikan" or "⚠️ Berakhir")
    local color = completed and 5763719 or 16776960

    local description = string.format(
        "## %s\n\n" ..
        "**👤 Player:** `%s`\n\n" ..
        "### 🐾 Pet\n" ..
        "**Total:** `%d`\n" ..
        "**Diproses:** `%d`\n" ..
        "**Tersisa:** `%d`\n\n" ..
        "### ⚙️ Mode\n%s\n\n" ..
        "### 📋 Preset\n" ..
        "**Team:** `%s`\n" ..
        "**Weight:** `%s`\n" ..
        "**Mutation:** `%s`\n" ..
        "**Advanced:** `%s`\n\n" ..
        "### ⏱️ Durasi\n`%s`\n\n" ..
        "**Status:** %s",
        statusText,
        player.Name,
        total,
        processed,
        remaining,
        getSessionModesText(),
        tostring(sessionStats.presets.team or "-"),
        tostring(sessionStats.presets.weight or "-"),
        tostring(sessionStats.presets.mutation or "-"),
        tostring(sessionStats.presets.advanced or "-"),
        formatDuration(duration),
        statusText
    )

    sendDiscordEmbed(title, description, color)
    sessionStats.active = false
end


-- ==================================================================
-- GUI SKELETON
-- ==================================================================
local oldGui = playerGui:FindFirstChild("AoneHub")

if oldGui then
    oldGui:Destroy()
end

local Aode = {}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AoneHub"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false

screenGui.Destroying:Connect(function()
    -- Stop both AobeHub and migrated AodeHub engines.
    isGuiDestroyed = true
    isLeveling = false
    if Aode.shutdownEngine then
        Aode.shutdownEngine()
    end
    
    rainbowMode = false
    if rainbowTask then
        task.cancel(rainbowTask)
        rainbowTask = nil
    end
    
    -- ⭐ Finish Discord session jika masih aktif
    if sessionStats.active then
        finishDiscordSession("stopped")
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
closeBtn.Text = "✕"
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

local tabs = {
    {name="Farm", label="🌾 Farm"},
    {name="Weight", label="🤖 Automaton"},
    {name="Hatch", label="🥚 Hatch"},
    {name="Event", label="🔥 Event"},
    {name="Mutation", label="🧬 Mutation"},
    {name="AutoBuy", label="🛒 Buy"},
    {name="Inventory", label="🎒 Inventory"},
    {name="Ekstra", label="⚙️ Extra"}
}

local tabBtns = {}
local activeTab = nil

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

makeDraggable(titleBar, mainFrame)
makeDraggable(minimizedCircle, minimizedCircle)

local tabFrames = {}
for _, tab in ipairs(tabs) do
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundTransparency = 1
    f.Visible = false
    f.Parent = contentArea
    tabFrames[tab.name] = f
end

-- ==================================================================
-- WEIGHT TAB
-- ==================================================================
local weightTab = tabFrames["Weight"]

local weightScroll = Instance.new("ScrollingFrame")
weightScroll.Size = UDim2.new(1, -10, 1, -10)
weightScroll.Position = UDim2.new(0, 5, 0, 5)
weightScroll.BackgroundTransparency = 1
weightScroll.BorderSizePixel = 0
weightScroll.ScrollBarThickness = 4
weightScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 100)
weightScroll.CanvasSize = UDim2.new(0, 0, 0, 2000)
weightScroll.Parent = weightTab

local weightLayout = Instance.new("UIListLayout")
weightLayout.Padding = UDim.new(0, 6)
weightLayout.SortOrder = Enum.SortOrder.LayoutOrder
weightLayout.Parent = weightScroll



do
-- ==================================================================
-- AUTO HATCH ENGINE (migrated from AodeHub)
-- UI/config/webhook are owned by AobeHub.
-- ==================================================================
local CollectionService = game:GetService("CollectionService")
local RS = ReplicatedStorage

local PetEggService = RS.GameEvents:WaitForChild("PetEggService")
local PetsServiceRE = RS.GameEvents:WaitForChild("PetsService")
local FavoriteItemRE = RS.GameEvents:WaitForChild("Favorite_Item")
local SellAllRE = RS.GameEvents:WaitForChild("SellAllPets_RE")
local GiftPetEvent = RS.GameEvents:WaitForChild("GiftPet")
local AcceptPetGift = RS.GameEvents:WaitForChild("AcceptPetGift")
local PetGiftingService = RS.GameEvents:WaitForChild("PetGiftingService")

local PetRegistry = require(RS.Data.PetRegistry)
local PetList = PetRegistry.PetList or {}

local hatchConfig = {
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
    hatchDelay = 1.5,
    placeDelay = 1.5,
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
    maxLevel = 50,
    unwantedPetTypes = {},
    
    -- Webhook
    
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
    
    -- ⭐ Sync
    delayAfterGiftSync = 10,  -- delay 10s setelah auto gift/accept selesai sebelum hatch
}

-- Merge the old AodeHub config if present, otherwise use AobeHub's
-- embedded hatch config. This keeps old AutoHatch settings usable.
do
    local saved = config.hatch
    if type(saved) ~= "table" then
        saved = {}
        local ok, raw = pcall(readfile, "AutoHatch_Config.json")
        if ok and raw then
            local ok2, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
            if ok2 and type(decoded) == "table" then
                saved = decoded
            end
        end
    end

    for k, v in pairs(saved) do
        if hatchConfig[k] ~= nil and k ~= "eggGridOffsets" then
            hatchConfig[k] = v
        end
    end
end

-- ==================================================================
-- MUTATION HELPERS (migrated from AodeHub)
-- Uses AobeHub config.unwantedMutations instead of a separate file.
-- ==================================================================
local unwantedMutationsCache = nil

local function getUnwantedMutations()
    if unwantedMutationsCache then return unwantedMutationsCache end

    local list = {}
    for _, mutName in ipairs(config.unwantedMutations or {}) do
        if type(mutName) == "string" and mutName ~= "" then
            table.insert(list, mutName)
        end
    end

    table.sort(list, function(a, b)
        return #a > #b
    end)

    unwantedMutationsCache = list
    return list
end

local function refreshUnwantedMutationsCache()
    unwantedMutationsCache = nil
    return getUnwantedMutations()
end

local function splitPetName(petName)
    if not petName then return petName, nil end

    for _, mutName in ipairs(getUnwantedMutations()) do
        if petName:sub(1, #mutName + 1) == mutName .. " " then
            return petName:sub(#mutName + 2), mutName
        end
    end

    return petName, nil
end

local function saveHatchConfig()
    local snapshot = {}
    for k, v in pairs(hatchConfig) do
        if k ~= "eggGridOffsets" then
            snapshot[k] = v
        end
    end
    config.hatch = snapshot
    saveConfig()
end

local isRunning = false
local isGiftPetRunning = false
local giftPetUserStarted = false
local isWaitingEggTimer = false
local isAutoGiftActive = false
local isAutoAcceptActive = false
local statusCallback = nil
local guiDestroyed = false

-- ==================================================================
-- STATISTICS TRACKING
-- ==================================================================
local STATS = {}

local function resetStats()
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

local function getInventoryUUIDs()
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
    if petName and not hatchConfig.unwantedPetTypes[petName] then return "Special" end
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

local function scanNewPetsAfterSell()
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
            if hatchConfig.unwantedPetTypes[baseName] 
               and baseWeight <= hatchConfig.maxWeight 
               and info.level <= hatchConfig.maxLevel then
                print(string.format("[Stats] Skip unwanted: %s", petName))
            else
                local rarity = getPetRarityFromBaseWeight(petName, baseWeight)
                addHuntStat(rarity, petName, baseWeight)
            end
        end
    end
    return newCount
end

-- ==================================================================
-- HELPER: Pet Count
-- ==================================================================
local function getPetCountFromData()
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
local function countEggsInBackpack()
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
                    if next(hatchConfig.selectedEggs) == nil then
                        isSelected = true
                    else
                        for name, val in pairs(hatchConfig.selectedEggs) do
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

local function getCenterPoint()
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
local function getMyGardenEggs()
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
        for i, gridOffset in ipairs(hatchConfig.eggGridOffsets) do
            if (offset - gridOffset).Magnitude < THRESHOLD then
                occupied[i] = true
                break
            end
        end
    end
    return occupied
end

local function getEmptySlots()
    local occupied = getOccupiedSlots()
    local emptySlots = {}
    for i = 1, #hatchConfig.eggGridOffsets do
        if not occupied[i] then table.insert(emptySlots, i) end
    end
    return emptySlots, occupied
end

local function hatchEgg(eggModel)
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

local function findEggTool()
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
                if next(hatchConfig.selectedEggs) == nil then
                    isSelected = true
                else
                    for name, val in pairs(hatchConfig.selectedEggs) do
                        if name == eggName and val then isSelected = true break end
                    end
                end
                if count > 0 and isSelected then return tool end
            end
        end
    end
    return nil
end

local function getBackpackEggs()
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

local function parsePetName(toolName)
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

local function getBackpackPets()
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

local function getAllPetTypesFromRegistry()
    local types = {}
    for petName, _ in pairs(PetList) do
        table.insert(types, petName)
    end
    table.sort(types)
    return types
end

local function findPetToolByName(petName)
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

local function getPlayerNames()
    local names = {}
    for _, p in ipairs(game.Players:GetPlayers()) do
        if p ~= player then table.insert(names, p.Name) end
    end
    table.sort(names)
    return names
end

local function findPlayerByName(name)
    for _, p in ipairs(game.Players:GetPlayers()) do
        if p.Name == name then return p end
    end
    return nil
end

local function isPetUUIDValid(uuid)
    local petsData = Aode.getPlayerPetData()
    if not petsData or not petsData.PetInventory then return false end
    return petsData.PetInventory.Data[uuid] ~= nil
end

local function getEquippedPets()
    local petsData = Aode.getPlayerPetData()
    return (petsData and petsData.EquippedPets) or {}
end

-- ==================================================================
-- HELPER: PRESET
-- ==================================================================
local function getPresetNames()
    local ok, data = pcall(readfile, "AoneHub/AoneHub_Gag1.json")
    if not ok or not data then return {} end
    local ok2, decoded = pcall(HttpService.JSONDecode, HttpService, data)
    if not ok2 or not decoded or not decoded.teamPresets then return {} end
    local names = {}
    for name, _ in pairs(decoded.teamPresets) do table.insert(names, name) end
    table.sort(names)
    return names
end

local function getPresetFromFile(presetName)
    local ok, data = pcall(readfile, "AoneHub/AoneHub_Gag1.json")
    if not ok or not data then return nil end
    local ok2, decoded = pcall(HttpService.JSONDecode, HttpService, data)
    if not ok2 or not decoded or not decoded.teamPresets then return nil end
    return decoded.teamPresets[presetName]
end

local function getPresetUUIDs(presetName)
    local preset = getPresetFromFile(presetName)
    if not preset or not preset.pets then return {} end
    local uuids = {}
    for _, petInfo in ipairs(preset.pets) do
        if isPetUUIDValid(petInfo.UUID) then table.insert(uuids, petInfo.UUID) end
    end
    return uuids
end

local function isPetInPreset(petDisplayName)
    local baseName = splitPetName(petDisplayName)
    for _, presetName in ipairs({hatchConfig.speedPreset, hatchConfig.hatchPreset, hatchConfig.sellPreset}) do
        if presetName then
            local preset = getPresetFromFile(presetName)
            if preset and preset.pets then
                for _, petInfo in ipairs(preset.pets) do
                    if petInfo.PetType == baseName or petInfo.PetType == petDisplayName then
                        return true
                    end
                    if petInfo.Mutation and petInfo.Mutation ~= "Normal" then
                        if (petInfo.Mutation .. " " .. petInfo.PetType) == petDisplayName then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

-- ==================================================================
-- HELPER: LOADOUT SWAP
-- ==================================================================
local lastLoadoutSlot = nil

local function swapLoadout(slotNumber)
    if not slotNumber then return false end
    pcall(function()
        PetsServiceRE:FireServer("SwapPetLoadout", slotNumber)
    end)
    task.wait(hatchConfig.delayAfterLoadout)
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
        task.wait(hatchConfig.equipDelay)
    end
    for _, uuid in ipairs(toEquip) do
        if isPetUUIDValid(uuid) then
            pcall(function() PetsService:EquipPet(uuid, CFrame.new(0, 10, 0)) end)
            task.wait(hatchConfig.equipDelay)
        end
    end
    task.wait(hatchConfig.syncWaitTime)
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
    if not hatchConfig.unwantedPetTypes[baseName] then return false end
    if pet.weight > hatchConfig.maxWeight then return false end
    if pet.level > hatchConfig.maxLevel then return false end
    return true
end

local function sellAll()
    pcall(function() SellAllRE:FireServer() end)
    task.wait(3)
end

-- ==================================================================
-- AUTO ACCEPT GIFT
-- ==================================================================
local GIFT_STATS = {
    totalAccepted = 0,
    totalFailed = 0,
    history = {},
}

local giftQueue = {}
local isProcessingGiftQueue = false

local function hideGiftUI()
    if not hatchConfig.giftHideUI then return end
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

local function processGiftQueue()
    if isProcessingGiftQueue then return end
    if #giftQueue == 0 then return end  -- ⭐ skip kalau kosong
    
    isProcessingGiftQueue = true
    isAutoAcceptActive = true
    
    -- ⭐ SAVE previous state
    local wasWaitingEggTimer = isWaitingEggTimer
    
    task.spawn(function()
        while #giftQueue > 0 do
            local gift = table.remove(giftQueue, 1)
            print(string.format("[Gift] Process: %s | %s", gift.id, gift.pet))
            
            task.wait(hatchConfig.giftDelayAfter)
            
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
                task.wait(hatchConfig.giftDelayBetween)
            end
        end
        task.wait(0.5)
        hideGiftUI()
        isProcessingGiftQueue = false
        isAutoAcceptActive = false
    end)
end

GiftPetEvent.OnClientEvent:Connect(function(giftId, petName, weightInfo)
    if not hatchConfig.giftEnabled then return end
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
    task.wait(hatchConfig.giftPetDelayEquip)
    
    -- Cek & unfavorit
    if petTool:GetAttribute("d") == true then
        pcall(function() FavoriteItemRE:FireServer(petTool) end)
        task.wait(hatchConfig.giftPetDelayUnfavorit)
    end
    
    -- Fire gift
    print(string.format("[Gift Pet] Kirim %s → %s", petName, targetUsername))
    local ok = pcall(function()
        PetGiftingService:FireServer("GivePet", target)
    end)
    
    task.wait(hatchConfig.giftPetDelayBetween)
    return ok
end

local function autoGiftAllFiltered()
    if not hatchConfig.giftPetTarget then return end
    local target = findPlayerByName(hatchConfig.giftPetTarget)
    if not target then return end
    
    isAutoGiftActive = true
    
    local pets = getBackpackPets()
    local toGift = {}
    
    for _, pet in ipairs(pets) do
        local skip = false
        if pet.weight < hatchConfig.giftPetMinWeight then skip = true end
        if pet.weight > hatchConfig.giftPetMaxWeight then skip = true end
        if pet.level < hatchConfig.giftPetMinLevel then skip = true end
        if pet.level > hatchConfig.giftPetMaxLevel then skip = true end
        
        if not skip and next(hatchConfig.giftPetSelectedTypes) ~= nil then
            local baseName = splitPetName(pet.name)
            if not hatchConfig.giftPetSelectedTypes[baseName] and not hatchConfig.giftPetSelectedTypes[pet.name] then
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
        if not isGiftPetRunning then break end
        print(string.format("[Gift Pet] [%d/%d] %s", i, #toGift, pet.name))
        autoGiftOnePet(pet.name, hatchConfig.giftPetTarget)
    end
    
    isAutoGiftActive = false
end

-- ==================================================================
-- WEBHOOK
-- ==================================================================
-- AodeHub sekarang memakai webhook terpusat milik AobeHub.
local function sendWebhookEmbed(embed)
    if not config.discordWebhookEnabled then return end
    if not config.discordWebhook or config.discordWebhook == "" then return end

    pcall(function()
        sendDiscordWebhook({
            username = "AoneHub",
            embeds = {embed},
        })
    end)
end

local function buildWebhookEmbed()
    local eggName = "?"
    for name, _ in pairs(hatchConfig.selectedEggs) do eggName = name break end
    local petCurrent, petMax = getPetCountFromData()
    
    local function formatPreset(presetName)
        if not presetName then return "-" end
        local preset = getPresetFromFile(presetName)
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
    table.insert(desc, "> Core: " .. formatPreset(hatchConfig.speedPreset))
    table.insert(desc, "> Hatch: " .. formatPreset(hatchConfig.hatchPreset))
    table.insert(desc, "> Sell: " .. formatPreset(hatchConfig.sellPreset))
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
        footer = { text = "Auto Hatch v16.0 • " .. os.date("%Y-%m-%d %H:%M:%S") }
    }
end

-- ==================================================================
-- STATUS
-- ==================================================================
local function updateStatus(text)
    if statusCallback and not guiDestroyed then statusCallback(text) end
    print("[AutoHatch]", text)
end

-- ==================================================================
-- FASE 1: PLACE EGG
-- ==================================================================
local function placeEggsFromBackpack()
    local totalSlots = #hatchConfig.eggGridOffsets
    task.wait(hatchConfig.scanSettleDelay)
    local emptySlots, occupied = getEmptySlots()
    if #emptySlots == 0 then
        updateStatus("⚠️ Garden penuh")
        return 0
    end
    updateStatus(string.format("📦 %d slot kosong", #emptySlots))
    local eggTool = findEggTool()
    if not eggTool then
        updateStatus("⚠️ Tidak ada egg")
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
        local pos = center.Position + hatchConfig.eggGridOffsets[slotIndex]
        local ok = pcall(function()
            PetEggService:FireServer("CreateEgg", pos)
        end)
        if ok then
            placed = placed + 1
            updateStatus(string.format("📦 Place %d/%d", placed, #emptySlots))
            task.wait(hatchConfig.placeDelay)
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
    updateStatus(string.format("[%d/%d] 📦 Place egg...", cycleNum, totalCycles))
    local placed = placeEggsFromBackpack()
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
        updateStatus(string.format("[%d/%d] ⚡ Tim Speed...", cycleNum, totalCycles))
        equipTeamByPreset(hatchConfig.speedPreset, hatchConfig.speedLoadout)
        task.wait(hatchConfig.delayAfterSpeed)
    
        updateStatus(string.format("[%d/%d] ⏳ Menunggu ready...", cycleNum, totalCycles))
    
        -- ⭐ SET STATE: Tunggu egg timer
        isWaitingEggTimer = true
    
        -- ⭐ Process gift queue yang menumpuk
        if #giftQueue > 0 then
            print(string.format("[AutoHatch] Process %d gift dari queue...", #giftQueue))
            processGiftQueue()
        end
    
        -- ⭐ Auto-start auto gift
        if giftPetUserStarted and not isGiftPetRunning and hatchConfig.giftPetTarget then
            local hasPetsToGift = false
            for _, pet in ipairs(getBackpackPets()) do
                if pet.weight >= hatchConfig.giftPetMinWeight 
                   and pet.weight <= hatchConfig.giftPetMaxWeight
                   and pet.level >= hatchConfig.giftPetMinLevel
                   and pet.level <= hatchConfig.giftPetMaxLevel then
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
        updateStatus(string.format("[%d/%d] ⏳ Menunggu gift/accept selesai...", cycleNum, totalCycles))
        local hasActiveProcess = false
        while (isAutoGiftActive or isAutoAcceptActive or isGiftPetRunning) and isRunning do
            hasActiveProcess = true
            task.wait(1)
        end
    
        -- ⭐ Kalau ADA proses yang aktif → delay
        if hasActiveProcess then
            updateStatus(string.format("[%d/%d] ⏳ Delay %ss...", 
                cycleNum, totalCycles, hatchConfig.delayAfterGiftSync))
            task.wait(hatchConfig.delayAfterGiftSync)
        end
    
        -- ⭐ CLEAR STATE
        isWaitingEggTimer = false
    
        if not isRunning then return false end
        task.wait(1)
    end
    
    updateStatus(string.format("[%d/%d] 🥚 Tim Hatch...", cycleNum, totalCycles))
    equipTeamByPreset(hatchConfig.hatchPreset, hatchConfig.hatchLoadout)
    task.wait(hatchConfig.delayAfterHatch)
    local eggsToHatch = {}
    for _, egg in ipairs(getMyGardenEggs()) do
        if (egg:GetAttribute("TimeToHatch") or 999) <= 0 then table.insert(eggsToHatch, egg) end
    end
    local hatchCount = #eggsToHatch
    for _, egg in ipairs(eggsToHatch) do
        if not isRunning then break end
        hatchEgg(egg)
        task.wait(hatchConfig.hatchDelay)
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
    task.wait(hatchConfig.delayAfterHatchAll)
    STATS.totalHatchCycles = STATS.totalHatchCycles + 1
    STATS.lastCycleDuration = os.time() - STATS.cycleStartTime
    task.wait(2)
    return true
end

-- ==================================================================
-- FASE 3: FILTER + SELL
-- ==================================================================
local function runFilterAndSell()
    if not hatchConfig.autoSell then return end
    updateStatus("💸 Tim Sell...")
    equipTeamByPreset(hatchConfig.sellPreset, hatchConfig.sellLoadout)
    task.wait(hatchConfig.delayAfterSell)
    updateStatus("⭐ Filter pet...")
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
    updateStatus(string.format("⭐ Preset:%d Fav:%d Skip:%d", presetProtectCount, favCount, skipCount))
    task.wait(1)
    for _, pet in ipairs(getBackpackPets()) do
        local shouldBeFav = isPetInPreset(pet.name) or not isUnwantedPet(pet)
        if shouldBeFav and not pet.isFavorited then
            ensureFavorit(pet.tool, true)
        end
    end
    task.wait(hatchConfig.delayBeforeSell)
    updateStatus("💰 Sell all...")
    sellAll()
    task.wait(3)
    STATS.eggAfterSell = countEggsInBackpack()
    updateStatus("✅ Sell selesai")
    task.wait(2)
    scanNewPetsAfterSell()
end

-- ==================================================================
-- MAIN LOOP
-- ==================================================================
local function startAutoHatch()
    if isRunning then return end
    refreshUnwantedMutationsCache()
    resetStats()
    STATS.knownUUIDs = getInventoryUUIDs()
    STATS.eggBeforePlace = countEggsInBackpack()
    isRunning = true
    task.spawn(function()
        while isRunning and not guiDestroyed do
            for cycle = 1, hatchConfig.cycleCount do
                if not isRunning or guiDestroyed then break end
                runOneCycle(cycle, hatchConfig.cycleCount)
            end
            if not isRunning or guiDestroyed then break end
            runFilterAndSell()
            if not isRunning or guiDestroyed then break end
            if config.discordWebhookEnabled then
                local embed = buildWebhookEmbed()
                task.spawn(function() sendWebhookEmbed(embed) end)
            end
            updateStatus("🔄 Cycle baru...")
            task.wait(5)
        end
        if not guiDestroyed then updateStatus("Status: Stopped") end
        isRunning = false
    end)
end

local function stopAutoHatch()
    isRunning = false
    updateStatus("⏹️ Stopping...")
end

-- ==================================================================


-- Export only what the integrated UI needs.
Aode.hatchConfig = hatchConfig
Aode.saveHatchConfig = saveHatchConfig
Aode.getBackpackEggs = getBackpackEggs
Aode.loadTeamPresets = loadTeamPresets
Aode.isPetValid = isPetValid
Aode.getBackpackPets = getBackpackPets
Aode.splitPetName = splitPetName
Aode.autoGiftAllFiltered = autoGiftAllFiltered
Aode.getPlayerPetData = getPlayerPetData
Aode.countEggsInBackpack = countEggsInBackpack
Aode.startAutoHatch = startAutoHatch
Aode.stopAutoHatch = stopAutoHatch
Aode.getRunning = function() return isRunning end
Aode.setRunning = function(v) isRunning = v end
Aode.getGiftRunning = function() return isGiftPetRunning end
Aode.setGiftRunning = function(v) isGiftPetRunning = v end
Aode.setGiftUserStarted = function(v) giftPetUserStarted = v end
Aode.getGuiDestroyed = function() return guiDestroyed end
Aode.setStatusCallback = function(fn) statusCallback = fn end
Aode.shutdownEngine = function()
    guiDestroyed = true
    isRunning = false
    isGiftPetRunning = false
    giftPetUserStarted = false
    isAutoGiftActive = false
    isAutoAcceptActive = false
end
Aode.refreshUnwantedMutationsCache = refreshUnwantedMutationsCache

end

-- ==================================================================
-- UI HELPERS
-- ==================================================================
local sectionMeta = {}

local function createSection(parent, title, sectionKey)
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

local function createDynamicDropdown(
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

-- ==================================================================
-- SECTION: BUAT/EDIT PRESET (DROPDOWN DINAMIS)
-- ==================================================================
local CreatePresetSection = createSection(weightScroll, "💾 Buat/Edit Preset", "createPreset")
CreatePresetSection.LayoutOrder = 1
CreatePresetSection.Size = UDim2.new(1, -10, 0, 239)

local PresetNameInput = Instance.new("TextBox")
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

local PetSearchBox = Instance.new("TextBox")
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

local PetListFrame = Instance.new("ScrollingFrame")
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
local EditPresetDropdown = createDynamicDropdown(
    CreatePresetSection,
    UDim2.new(0, 10, 0, 147),
    "📂 Pilih Preset untuk Diedit/Dihapus",
    CreatePresetSection,
    239,
    weightScroll
)

local SavePresetButton = Instance.new("TextButton")
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

local DeletePresetButton = Instance.new("TextButton")
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

local TargetSearchBox = Instance.new("TextBox")
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

local TargetListFrame = Instance.new("ScrollingFrame")
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

local ScanButton = Instance.new("TextButton")
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
TeamSelectSection.Size = UDim2.new(1, -10, 0, 210)

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
local TeamPresetDropdown = createDynamicDropdown(
    TeamSelectSection,
    UDim2.new(0, 10, 0, 55),
    selectedTeamPreset and string.format("📂 %s", selectedTeamPreset) or "📂 Pilih Preset Tim Leveling",
    TeamSelectSection,
    210,
    weightScroll
)

AdvLabel = Instance.new("TextLabel")
AdvLabel.Size = UDim2.new(1, -20, 0, 22)
AdvLabel.Position = UDim2.new(0, 10, 0, 88)
AdvLabel.BackgroundTransparency = 1
AdvLabel.Font = Enum.Font.GothamBold
AdvLabel.Text = "🚀 Advanced Leveling"
AdvLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
AdvLabel.TextSize = 11
AdvLabel.TextXAlignment = Enum.TextXAlignment.Left
AdvLabel.Parent = TeamSelectSection

local AdvancedToggleButton = Instance.new("TextButton")
AdvancedToggleButton.Size = UDim2.new(1, -20, 0, 25)
AdvancedToggleButton.Position = UDim2.new(0, 10, 0, 115)
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
AdvancedLevelInput.Position = UDim2.new(0, 10, 0, 145)
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
local AdvancedPresetDropdown = createDynamicDropdown(
    TeamSelectSection,
    UDim2.new(0, 10, 0, 172),
    selectedAdvancedPreset and string.format("📂 %s", selectedAdvancedPreset) or "📂 Pilih Preset Advanced",
    TeamSelectSection,
    210,
    weightScroll
)

-- ==================================================================
-- SECTION: AUTO WEIGHT (DROPDOWN DINAMIS)
-- ==================================================================
local WeightSection = createSection(weightScroll, "🐘 Auto Weight", "autoWeight")
WeightSection.LayoutOrder = 4
WeightSection.Size = UDim2.new(1, -10, 0, 129)

local WeightToggleButton = Instance.new("TextButton")
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
    129,
    weightScroll
)

-- Semua GUI yang ingin mengikuti warna rainbow
local rainbowTargets = {
    RainbowModeButton,
}

-- ==================================================================
-- SECTION: AUTO MUTATION (DROPDOWN DINAMIS)
-- ==================================================================
local MutationSection = createSection(weightScroll, "🧬 Auto Mutation", "autoMutation")
MutationSection.LayoutOrder = 5
MutationSection.Size = UDim2.new(1, -10, 0, 278)

local MutationToggleButton = Instance.new("TextButton")
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
    278,
    weightScroll
)

MutLabel = Instance.new("TextLabel")
MutLabel.Size = UDim2.new(1, -20, 0, 22)
MutLabel.Position = UDim2.new(0, 10, 0, 94)
MutLabel.BackgroundTransparency = 1
MutLabel.Font = Enum.Font.GothamBold
MutLabel.Text = "❌ Mutasi yg tidak diinginkan:"
MutLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
MutLabel.TextSize = 11
MutLabel.TextXAlignment = Enum.TextXAlignment.Left
MutLabel.Parent = MutationSection

local MutationSearchBox = Instance.new("TextBox")
MutationSearchBox.Size = UDim2.new(1, -20, 0, 22)
MutationSearchBox.Position = UDim2.new(0, 10, 0, 121)
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
MutationListFrame.Position = UDim2.new(0, 10, 0, 148)
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
-- SECTION: KONTROL
-- ==================================================================
local ButtonSection = createSection(weightScroll)
ButtonSection.LayoutOrder = 6
ButtonSection.Size = UDim2.new(1, -10, 0, 69)

local ToggleButton = Instance.new("TextButton")
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
local function populateDynamicDropdown(dropdown, selectedPreset, onSelect)
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
local function populatePetList()
    for _, child in pairs(PetListFrame:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    local petsData = Aode.getPlayerPetData()
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
local function populateMutationList()
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
    local petsData = Aode.getPlayerPetData()
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
local function populateTargetDropdown()
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
local teamDropdownOriginalToggle = TeamPresetDropdown.Toggle
local function teamToggleWrapper()
    if not TeamPresetDropdown.IsOpen() then
        populateTeamPresetDropdown()
    end
end
TeamPresetDropdown.HeaderButton.MouseButton1Click:Connect(teamToggleWrapper)

local weightDropdownOriginalToggle = WeightPresetDropdown.Toggle
WeightPresetDropdown.HeaderButton.MouseButton1Click:Connect(function()
    if not WeightPresetDropdown.IsOpen() then
        populateWeightPresetDropdown()
    end
end)

local mutationDropdownToggle = MutationPresetDropdown.Toggle
MutationPresetDropdown.HeaderButton.MouseButton1Click:Connect(function()
    if not MutationPresetDropdown.IsOpen() then
        populateMutationPresetDropdown()
    end
end)

local advancedDropdownToggle = AdvancedPresetDropdown.Toggle
AdvancedPresetDropdown.HeaderButton.MouseButton1Click:Connect(function()
    if not AdvancedPresetDropdown.IsOpen() then
        populateAdvancedPresetDropdown()
    end
end)

local editDropdownToggle = EditPresetDropdown.Toggle
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

-- ==================================================================
-- MAIN LOGIC - AUTO LEVELING
-- ==================================================================
ToggleButton.MouseButton1Click:Connect(function()
    if isLeveling then
        isLeveling = false
        finishDiscordSession("stopped")
        ToggleButton.Text = "▶️ Mulai"
        ToggleButton.BackgroundColor3 = C.success
        updateStatus()
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
                    local toEquip = math.min(availableSlots, #levelTargets)
                    
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
                    local toEquip = math.min(availableSlots, #readyForWeight)
                    
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
                local toEquip = math.min(availableSlots, #mutationPets)
                
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
                local toEquip = math.min(availableSlots, #normalPets)
                
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
                local toEquip = math.min(availableSlots, #advancedPets)
                
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
        finishDiscordSession("completed")
        StatusLabel.Text = "🎉 Semua proses selesai!"
        isLeveling = false
        ToggleButton.Text = "▶️ Mulai"
        ToggleButton.BackgroundColor3 = C.success
        updateStatus()
    end)
end)




do
local AUI = Aode
-- ==================================================================
-- INTEGRATED AODE -> AOBE HATCH / INVENTORY UI
-- Split into small builder functions to stay below Luau's 200-local
-- register limit in the large AobeHub main scope.
-- ==================================================================

AUI.hatchTab = tabFrames["Hatch"]
AUI.hatchScroll = Instance.new("ScrollingFrame")
AUI.hatchScroll.Size = UDim2.new(1, -10, 1, -10)
AUI.hatchScroll.Position = UDim2.new(0, 5, 0, 5)
AUI.hatchScroll.BackgroundTransparency = 1
AUI.hatchScroll.BorderSizePixel = 0
AUI.hatchScroll.ScrollBarThickness = 4
AUI.hatchScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
AUI.hatchScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
AUI.hatchScroll.Parent = AUI.hatchTab

AUI.hatchLayout = Instance.new("UIListLayout")
AUI.hatchLayout.Padding = UDim.new(0, 6)
AUI.hatchLayout.SortOrder = Enum.SortOrder.LayoutOrder
AUI.hatchLayout.Parent = AUI.hatchScroll

function AUI.hatchInput(parent, y, label, key, minValue, maxValue, decimals)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -20, 0, 26)
    row.Position = UDim2.new(0, 10, 0, y)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(0.58, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.Text = label
    text.TextColor3 = C.text
    text.Font = Enum.Font.Gotham
    text.TextSize = 9
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Parent = row

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.38, 0, 0, 22)
    box.Position = UDim2.new(0.62, 0, 0, 2)
    box.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.Gotham
    box.TextSize = 9
    box.TextColor3 = C.text
    box.Text = tostring(AUI.hatchConfig[key] or "")
    box.TextXAlignment = Enum.TextXAlignment.Center
    box.Parent = row
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)

    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then
            if minValue then n = math.max(minValue, n) end
            if maxValue then n = math.min(maxValue, n) end
            if not decimals then n = math.floor(n) end
            AUI.hatchConfig[key] = n
            box.Text = tostring(n)
            AUI.saveHatchConfig()
        else
            box.Text = tostring(AUI.hatchConfig[key] or "")
        end
    end)
    return row, box
end

function AUI.hatchToggle(parent, y, label, key)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -20, 0, 24)
    button.Position = UDim2.new(0, 10, 0, y)
    button.BorderSizePixel = 0
    button.AutoButtonColor = false
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 9
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.Parent = parent
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 4)

    local function refresh()
        local on = AUI.hatchConfig[key] == true
        button.Text = (on and "☑ " or "☐ ") .. label
        button.TextColor3 = on and C.success or C.text
        button.BackgroundColor3 = on and Color3.fromRGB(45, 75, 50) or Color3.fromRGB(55, 55, 70)
    end
    button.MouseButton1Click:Connect(function()
        AUI.hatchConfig[key] = not AUI.hatchConfig[key]
        AUI.saveHatchConfig()
        refresh()
    end)
    refresh()
    return button
end

function AUI.hatchActionButton(parent, y, textValue, callback, color)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -20, 0, 28)
    button.Position = UDim2.new(0, 10, 0, y)
    button.BackgroundColor3 = color or C.accent
    button.BorderSizePixel = 0
    button.AutoButtonColor = true
    button.Font = Enum.Font.GothamBold
    button.TextSize = 9
    button.TextColor3 = C.text
    button.Text = textValue
    button.Parent = parent
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 4)
    button.MouseButton1Click:Connect(callback)
    return button
end

function AUI.populateHatchPresetDropdown(dropdown, key, label)
    for _, child in ipairs(dropdown.ListScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local presets = AUI.loadTeamPresets()
    local names = {}
    for name in pairs(presets) do table.insert(names, name) end
    table.sort(names)
    for i, name in ipairs(names) do
        local p = presets[name]
        local valid = 0
        for _, petInfo in ipairs(p.pets or {}) do
            if AUI.isPetValid(petInfo.UUID) then valid += 1 end
        end
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -4, 0, dropdown.ItemHeight)
        b.BackgroundColor3 = AUI.hatchConfig[key] == name and C.success or Color3.fromRGB(65, 65, 80)
        b.BorderSizePixel = 0
        b.Font = Enum.Font.Gotham
        b.TextSize = 8
        b.TextColor3 = C.text
        b.TextXAlignment = Enum.TextXAlignment.Left
        b.Text = string.format("📁 %s (%d/%d)", name, valid, #(p.pets or {}))
        b.LayoutOrder = i
        b.ZIndex = 12
        b.Parent = dropdown.ListScroll
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 3)
        local pad = Instance.new("UIPadding")
        pad.PaddingLeft = UDim.new(0, 6)
        pad.Parent = b
        b.MouseButton1Click:Connect(function()
            AUI.hatchConfig[key] = name
            dropdown.HeaderButton.Text = label .. ": " .. name
            AUI.saveHatchConfig()
            dropdown.Close()
            AUI.populateHatchPresetDropdown(dropdown, key, label)
        end)
    end
    dropdown.UpdateSize()
end

function AUI.buildHatchMain()
    local section = createSection(AUI.hatchScroll, "⚙️ Main", "Hatch.Main")
    section.LayoutOrder = 1
    local speed = createDynamicDropdown(section, UDim2.new(0,10,0,32), "⚡ Speed — pilih Team Preset", section, 250, AUI.hatchScroll)
    local hatch = createDynamicDropdown(section, UDim2.new(0,10,0,70), "🥚 Hatch — pilih Team Preset", section, 250, AUI.hatchScroll)
    local sell = createDynamicDropdown(section, UDim2.new(0,10,0,108), "💸 Sell — pilih Team Preset", section, 250, AUI.hatchScroll)
    AUI.hatchInput(section,146,"Jumlah Cycle:","cycleCount",1,100,false)
    AUI.hatchToggle(section,176,"💰 Auto Sell","autoSell")
    local status = Instance.new("TextLabel")
    status.Size=UDim2.new(1,-20,0,24); status.Position=UDim2.new(0,10,0,205); status.BackgroundTransparency=1
    status.TextColor3=C.textDim; status.Font=Enum.Font.Gotham; status.TextSize=8; status.TextWrapped=true
    status.TextXAlignment=Enum.TextXAlignment.Left; status.Parent=section
    AUI.hatchStatus = status
    Aode.setStatusCallback(function(v)
        if status and status.Parent then status.Text=tostring(v) end
    end)
    AUI.hatchActionButton(section,232,"▶️ Mulai Auto Hatch",function()
        if Aode.getRunning() then
            AUI.stopAutoHatch()
        else
            if next(AUI.hatchConfig.selectedEggs)==nil then status.Text="⚠️ Pilih minimal 1 egg di section Egg."; return end
            if not AUI.hatchConfig.hatchPreset then status.Text="⚠️ Pilih preset Hatch terlebih dahulu."; return end
            AUI.saveHatchConfig(); AUI.startAutoHatch()
        end
    end,C.success)
    AUI.speedDropdown=speed; AUI.hatchDropdown=hatch; AUI.sellDropdown=sell
    AUI.populateHatchPresetDropdown(speed,"speedPreset","⚡ Speed")
    AUI.populateHatchPresetDropdown(hatch,"hatchPreset","🥚 Hatch")
    AUI.populateHatchPresetDropdown(sell,"sellPreset","💸 Sell")
    if AUI.hatchConfig.speedPreset then speed.HeaderButton.Text="⚡ Speed: "..AUI.hatchConfig.speedPreset end
    if AUI.hatchConfig.hatchPreset then hatch.HeaderButton.Text="🥚 Hatch: "..AUI.hatchConfig.hatchPreset end
    if AUI.hatchConfig.sellPreset then sell.HeaderButton.Text="💸 Sell: "..AUI.hatchConfig.sellPreset end
end

function AUI.buildHatchEgg()
    local section=createSection(AUI.hatchScroll,"📦 Egg","Hatch.Egg")
    section.LayoutOrder=2; section.Size=UDim2.new(1,-10,0,310)
    local list=Instance.new("ScrollingFrame")
    list.Size=UDim2.new(1,-20,0,235); list.Position=UDim2.new(0,10,0,66); list.BackgroundTransparency=1
    list.BorderSizePixel=0; list.ScrollBarThickness=3; list.AutomaticCanvasSize=Enum.AutomaticSize.Y
    list.CanvasSize=UDim2.new(0,0,0,0); list.Parent=section
    local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,3); layout.Parent=list
    AUI.eggListFrame=list
    function AUI.refreshIntegratedEggList()
        for _,child in ipairs(list:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
        local counts={}
        for _,egg in ipairs(AUI.getBackpackEggs()) do counts[egg.name]=(counts[egg.name] or 0)+egg.count end
        local names={}; for name in pairs(counts) do table.insert(names,name) end; table.sort(names)
        for _,name in ipairs(names) do
            local selected=AUI.hatchConfig.selectedEggs[name]==true
            local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,22)
            b.BackgroundColor3=selected and C.success or Color3.fromRGB(65,65,80); b.BorderSizePixel=0
            b.Font=Enum.Font.Gotham; b.TextSize=8; b.TextColor3=C.text; b.TextXAlignment=Enum.TextXAlignment.Left
            b.Text=string.format("%s %s (x%d)",selected and "✓" or "□",name,counts[name]); b.Parent=list
            Instance.new("UICorner",b).CornerRadius=UDim.new(0,3)
            local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,7); pad.Parent=b
            b.MouseButton1Click:Connect(function()
                AUI.hatchConfig.selectedEggs[name]=not selected and true or nil
                AUI.saveHatchConfig(); AUI.refreshIntegratedEggList()
            end)
        end
        if #names==0 then
            local info=Instance.new("TextLabel"); info.Size=UDim2.new(1,0,0,30); info.BackgroundTransparency=1
            info.Text="Tidak ada egg di backpack."; info.TextColor3=C.textDim; info.Font=Enum.Font.Gotham; info.TextSize=8; info.Parent=list
        end
    end
    local refresh=AUI.hatchActionButton(section,32,"🔄 Refresh Egg List",AUI.refreshIntegratedEggList,C.accent)
    AUI.eggRefresh=refresh
    AUI.refreshIntegratedEggList()
end

function AUI.buildHatchDelay()
    local section=createSection(AUI.hatchScroll,"⏱️ Delay","Hatch.Delay")
    section.LayoutOrder=3; section.Size=UDim2.new(1,-10,0,330)
    AUI.hatchInput(section,32,"Loadout Swap:","delayAfterLoadout",0,60,true)
    AUI.hatchInput(section,62,"Setelah Hatch All:","delayAfterHatchAll",0,60,true)
    AUI.hatchInput(section,92,"Antar Hatch:","hatchDelay",0,60,true)
    AUI.hatchInput(section,122,"Place Egg:","placeDelay",0,60,true)
    AUI.hatchInput(section,152,"Scan Settle:","scanSettleDelay",0,60,true)
    AUI.hatchInput(section,182,"Setelah Speed:","delayAfterSpeed",0,60,true)
    AUI.hatchInput(section,212,"Setelah Hatch:","delayAfterHatch",0,60,true)
    AUI.hatchInput(section,242,"Setelah Sell:","delayAfterSell",0,60,true)
    AUI.hatchInput(section,272,"Sebelum Sell:","delayBeforeSell",0,60,true)
    AUI.hatchInput(section,302,"Gift → Hatch Sync:","delayAfterGiftSync",0,120,true)
end

function AUI.buildHatchUnwanted()
    local section=createSection(AUI.hatchScroll,"🎯 Unwanted","Hatch.Unwanted")
    section.LayoutOrder=4; section.Size=UDim2.new(1,-10,0,410)
    AUI.hatchInput(section,32,"Max Weight (KG):","maxWeight",0,1000,true)
    AUI.hatchInput(section,62,"Max Level:","maxLevel",0,10000,false)
    local info=Instance.new("TextLabel"); info.Size=UDim2.new(1,-20,0,22); info.Position=UDim2.new(0,10,0,92); info.BackgroundTransparency=1
    info.Text="Pet diproses jika termasuk unwanted + weight ≤ max + level ≤ max."; info.TextColor3=C.textDim; info.Font=Enum.Font.Gotham; info.TextSize=7; info.TextWrapped=true; info.TextXAlignment=Enum.TextXAlignment.Left; info.Parent=section
    local list=Instance.new("ScrollingFrame"); list.Size=UDim2.new(1,-20,0,275); list.Position=UDim2.new(0,10,0,125); list.BackgroundTransparency=1; list.BorderSizePixel=0; list.ScrollBarThickness=3; list.AutomaticCanvasSize=Enum.AutomaticSize.Y; list.CanvasSize=UDim2.new(0,0,0,0); list.Parent=section
    local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,3); layout.Parent=list
    AUI.unwantedList=list
    function AUI.refreshIntegratedUnwantedList()
        for _,child in ipairs(list:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
        local types={}; for _,pet in ipairs(AUI.getBackpackPets()) do types[AUI.splitPetName(pet.name)]=true end
        local names={}; for name in pairs(types) do table.insert(names,name) end; table.sort(names)
        for _,name in ipairs(names) do
            local selected=AUI.hatchConfig.unwantedPetTypes[name]==true
            local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,22); b.BackgroundColor3=selected and C.danger or Color3.fromRGB(65,65,80); b.BorderSizePixel=0
            b.Font=Enum.Font.Gotham; b.TextSize=8; b.TextColor3=C.text; b.Text=(selected and "✓ " or "□ ")..name; b.TextXAlignment=Enum.TextXAlignment.Left; b.Parent=list
            Instance.new("UICorner",b).CornerRadius=UDim.new(0,3); local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,7); pad.Parent=b
            b.MouseButton1Click:Connect(function()
                AUI.hatchConfig.unwantedPetTypes[name]=not selected and true or nil; AUI.saveHatchConfig(); AUI.refreshIntegratedUnwantedList(); Aode.refreshUnwantedMutationsCache()
            end)
        end
    end
    AUI.refreshIntegratedUnwantedList()
end

function AUI.buildInventory()
    AUI.inventoryTab=tabFrames["Inventory"]
    AUI.inventoryScroll=Instance.new("ScrollingFrame")
    AUI.inventoryScroll.Size=UDim2.new(1,-10,1,-10); AUI.inventoryScroll.Position=UDim2.new(0,5,0,5); AUI.inventoryScroll.BackgroundTransparency=1; AUI.inventoryScroll.BorderSizePixel=0; AUI.inventoryScroll.ScrollBarThickness=4; AUI.inventoryScroll.CanvasSize=UDim2.new(0,0,0,0); AUI.inventoryScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; AUI.inventoryScroll.Parent=AUI.inventoryTab
    AUI.inventoryLayout=Instance.new("UIListLayout"); AUI.inventoryLayout.Padding=UDim.new(0,6); AUI.inventoryLayout.SortOrder=Enum.SortOrder.LayoutOrder; AUI.inventoryLayout.Parent=AUI.inventoryScroll

    local accept=createSection(AUI.inventoryScroll,"🎁 Auto Accept Pet Gift","Inventory.AutoAcceptGift"); accept.LayoutOrder=1; accept.Size=UDim2.new(1,-10,0,175)
    AUI.hatchToggle(accept,32,"Auto Accept Gift","giftEnabled"); AUI.hatchToggle(accept,62,"Sembunyikan UI Gift","giftHideUI"); AUI.hatchInput(accept,92,"Delay antar gift:","giftDelayBetween",0,60,true)
    local acceptStatus=Instance.new("TextLabel"); acceptStatus.Size=UDim2.new(1,-20,0,35); acceptStatus.Position=UDim2.new(0,10,0,125); acceptStatus.BackgroundTransparency=1; acceptStatus.Text="Auto accept aktif saat fase tunggu egg timer."; acceptStatus.TextColor3=C.textDim; acceptStatus.TextSize=8; acceptStatus.Font=Enum.Font.Gotham; acceptStatus.TextWrapped=true; acceptStatus.TextXAlignment=Enum.TextXAlignment.Left; acceptStatus.Parent=accept

    local gift=createSection(AUI.inventoryScroll,"🎁 Auto Gift Pet","Inventory.AutoGiftPet"); gift.LayoutOrder=2; gift.Size=UDim2.new(1,-10,0,355)
    local target=createDynamicDropdown(gift,UDim2.new(0,10,0,32),"👤 Pilih Target Player",gift,355,AUI.inventoryScroll); AUI.targetDropdown=target
    AUI.hatchInput(gift,70,"Min Weight (KG):","giftPetMinWeight",0,1000,true); AUI.hatchInput(gift,100,"Max Weight (KG):","giftPetMaxWeight",0,1000,true); AUI.hatchInput(gift,130,"Min Level:","giftPetMinLevel",0,10000,false); AUI.hatchInput(gift,160,"Max Level:","giftPetMaxLevel",0,10000,false)
    local running=Instance.new("TextLabel"); running.Size=UDim2.new(1,-20,0,24); running.Position=UDim2.new(0,10,0,194); running.BackgroundTransparency=1; running.TextColor3=C.textDim; running.Font=Enum.Font.Gotham; running.TextSize=8; running.TextXAlignment=Enum.TextXAlignment.Left; running.Parent=gift; AUI.giftRunningLabel=running
    AUI.hatchActionButton(gift,225,"🎁 Mulai / Stop Auto Gift",function()
        if Aode.getGiftRunning() then Aode.setGiftRunning(false); Aode.setGiftUserStarted(false); running.Text="⏹️ Auto Gift dihentikan."
        else
            if not AUI.hatchConfig.giftPetTarget then running.Text="⚠️ Pilih target player dulu."; return end
            Aode.setGiftUserStarted(true); Aode.setGiftRunning(true); AUI.saveHatchConfig(); running.Text="▶️ Auto Gift berjalan..."
            task.spawn(function() AUI.autoGiftAllFiltered(); if Aode.getGiftRunning() then Aode.setGiftRunning(false); running.Text="✅ Auto Gift selesai." end end)
        end
    end,C.accent)
    function AUI.populateTargetPlayerDropdown()
        for _,child in ipairs(target.ListScroll:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
        local names={}; for _,plr in ipairs(Players:GetPlayers()) do if plr~=player then table.insert(names,plr.Name) end end; table.sort(names)
        for i,name in ipairs(names) do
            local b=Instance.new("TextButton"); b.Size=UDim2.new(1,-4,0,target.ItemHeight); b.BackgroundColor3=AUI.hatchConfig.giftPetTarget==name and C.success or Color3.fromRGB(65,65,80); b.BorderSizePixel=0; b.Font=Enum.Font.Gotham; b.TextSize=8; b.TextColor3=C.text; b.TextXAlignment=Enum.TextXAlignment.Left; b.Text="👤 "..name; b.LayoutOrder=i; b.ZIndex=12; b.Parent=target.ListScroll
            Instance.new("UICorner",b).CornerRadius=UDim.new(0,3); local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,6); pad.Parent=b
            b.MouseButton1Click:Connect(function() AUI.hatchConfig.giftPetTarget=name; target.HeaderButton.Text="👤 "..name; AUI.saveHatchConfig(); target.Close() end)
        end
        target.UpdateSize()
    end
    AUI.populateTargetPlayerDropdown(); if AUI.hatchConfig.giftPetTarget then target.HeaderButton.Text="👤 "..tostring(AUI.hatchConfig.giftPetTarget) end

    local petSection=createSection(AUI.inventoryScroll,"📋 Pet untuk Gift","Inventory.GiftPetFilter"); petSection.LayoutOrder=3; petSection.Size=UDim2.new(1,-10,0,310)
    local petList=Instance.new("ScrollingFrame"); petList.Size=UDim2.new(1,-20,0,255); petList.Position=UDim2.new(0,10,0,32); petList.BackgroundTransparency=1; petList.BorderSizePixel=0; petList.ScrollBarThickness=3; petList.AutomaticCanvasSize=Enum.AutomaticSize.Y; petList.CanvasSize=UDim2.new(0,0,0,0); petList.Parent=petSection
    local petLayout=Instance.new("UIListLayout"); petLayout.Padding=UDim.new(0,3); petLayout.Parent=petList
    AUI.giftPetList=petList
    function AUI.refreshGiftPetTypes()
        for _,child in ipairs(petList:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
        local types={}; for _,pet in ipairs(AUI.getBackpackPets()) do types[AUI.splitPetName(pet.name)]=true end
        local names={}; for name in pairs(types) do table.insert(names,name) end; table.sort(names)
        for _,name in ipairs(names) do
            local selected=AUI.hatchConfig.giftPetSelectedTypes[name]==true
            local b=Instance.new("TextButton"); b.Size=UDim2.new(1,0,0,22); b.BackgroundColor3=selected and C.success or Color3.fromRGB(65,65,80); b.BorderSizePixel=0; b.Font=Enum.Font.Gotham; b.TextSize=8; b.TextColor3=C.text; b.Text=(selected and "✓ " or "□ ")..name; b.TextXAlignment=Enum.TextXAlignment.Left; b.Parent=petList
            Instance.new("UICorner",b).CornerRadius=UDim.new(0,3); local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,7); pad.Parent=b
            b.MouseButton1Click:Connect(function() AUI.hatchConfig.giftPetSelectedTypes[name]=selected and nil or true; AUI.saveHatchConfig(); AUI.refreshGiftPetTypes() end)
        end
    end
    AUI.refreshGiftPetTypes()

    local info=createSection(AUI.inventoryScroll,"📊 Inventory Info","Inventory.Info"); info.LayoutOrder=4; info.Size=UDim2.new(1,-10,0,90)
    local inv=Instance.new("TextLabel"); inv.Size=UDim2.new(1,-20,1,-38); inv.Position=UDim2.new(0,10,0,32); inv.BackgroundTransparency=1; inv.TextColor3=C.textDim; inv.Font=Enum.Font.Gotham; inv.TextSize=8; inv.TextWrapped=true; inv.TextXAlignment=Enum.TextXAlignment.Left; inv.Parent=info
    function AUI.refreshIntegratedInventoryInfo()
        local data=AUI.getPlayerPetData()
        if not data or not data.PetInventory then inv.Text="Inventory tidak tersedia."; return end
        local current=0; for _ in pairs(data.PetInventory.Data or {}) do current+=1 end
        local max=data.MutableStats and data.MutableStats.MaxPetsInInventory or 0
        inv.Text=string.format("🐾 Pet: %d / %d\n🥚 Egg terpilih: %d",current,max,AUI.countEggsInBackpack())
    end
    AUI.hatchActionButton(info,2,"🔄 Refresh Inventory",function() AUI.refreshGiftPetTypes(); AUI.refreshIntegratedUnwantedList(); AUI.refreshIntegratedInventoryInfo(); AUI.populateTargetPlayerDropdown() end,C.accent)
    AUI.refreshIntegratedInventoryInfo()
end

AUI.buildHatchMain()
AUI.buildHatchEgg()
AUI.buildHatchDelay()
AUI.buildHatchUnwanted()
AUI.buildInventory()

task.spawn(function()
    while not Aode.getGuiDestroyed() do
        task.wait(5)
        if AUI.hatchTab.Visible then
            AUI.refreshIntegratedEggList()
            AUI.refreshGiftPetTypes()
            AUI.refreshIntegratedUnwantedList()
            AUI.refreshIntegratedInventoryInfo()
            AUI.populateTargetPlayerDropdown()
        end
    end
end)
end

-- ==================================================================
-- TAB SWITCHING
-- ==================================================================
local function switchTab(tabName)
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
        local petsData = Aode.getPlayerPetData()
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

-- Switch ke Weight tab default
switchTab("Hatch")

print("✅ AoneHub integrated Hatch/Inventory loaded! Config:", SAVE_FILE)

-- Setup Extra Tab dengan Scroll
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



-- Persist the migrated hatch settings in the unified AobeHub config.
Aode.saveHatchConfig()
