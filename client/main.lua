local QBCore = exports['qb-core']:GetCoreObject()
local firstAlarm = false
local smashing = false

-- Functions

local function loadParticle()
	if not HasNamedPtfxAssetLoaded("scr_jewelheist") then
		RequestNamedPtfxAsset("scr_jewelheist")
    end
    while not HasNamedPtfxAssetLoaded("scr_jewelheist") do
		Wait(0)
    end
    SetPtfxAssetNextCall("scr_jewelheist")
end

local function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Wait(3)
    end
end

local function validWeapon()
    local ped = PlayerPedId()
    local pedWeapon = GetSelectedPedWeapon(ped)

    for k, _ in pairs(Config.WhitelistedWeapons) do
        if pedWeapon == k then
            return true
        end
    end
    return false
end

local function IsWearingHandshoes()
    local armIndex = GetPedDrawableVariation(PlayerPedId(), 3)
    local model = GetEntityModel(PlayerPedId())
    local retval = true
    if model == `mp_m_freemode_01` then
        if Config.MaleNoHandshoes[armIndex] ~= nil and Config.MaleNoHandshoes[armIndex] then
            retval = false
        end
    else
        if Config.FemaleNoHandshoes[armIndex] ~= nil and Config.FemaleNoHandshoes[armIndex] then
            retval = false
        end
    end
    return retval
end

local function smashVitrine(k)
    QBCore.Functions.TriggerCallback('qb-jewellery:server:getCops', function(cops)
        if cops >= Config.RequiredCops then
            local animDict = "missheist_jewel"
            local animName = "smash_case"
            local ped = PlayerPedId()
            local plyCoords = GetOffsetFromEntityInWorldCoords(ped, 0, 0.6, 0)
            local pedWeapon = GetSelectedPedWeapon(ped)
            if math.random(1, 100) <= 80 and not IsWearingHandshoes() then
                TriggerServerEvent("evidence:server:CreateFingerDrop", plyCoords)
            elseif math.random(1, 100) <= 5 and IsWearingHandshoes() then
                TriggerServerEvent("evidence:server:CreateFingerDrop", plyCoords)
                QBCore.Functions.Notify(Lang:t('error.fingerprints'), "error")
            end
            smashing = true
            QBCore.Functions.Progressbar("smash_vitrine", Lang:t('info.progressbar'), Config.WhitelistedWeapons[pedWeapon]["timeOut"], false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }, {}, {}, {}, function() -- Done
                TriggerServerEvent('qb-jewellery:server:vitrineReward', k)
                TriggerServerEvent('qb-jewellery:server:setTimeout')
                if not firstAlarm then                                                             --Code moved here to prevent multiple notif.
                    TriggerServerEvent('police:server:policeAlert', 'Robbery in progress')
                    firstAlarm = true
                end
                smashing = false
                TaskPlayAnim(ped, animDict, "exit", 3.0, 3.0, -1, 2, 0, 0, 0, 0)
            end, function() -- Cancel
                TriggerServerEvent('qb-jewellery:server:setVitrineState', "isBusy", false, k)
                smashing = false
                TaskPlayAnim(ped, animDict, "exit", 3.0, 3.0, -1, 2, 0, 0, 0, 0)
            end)
            TriggerServerEvent('qb-jewellery:server:setVitrineState', "isBusy", true, k)

            CreateThread(function()
                while smashing do
                    loadAnimDict(animDict)
                    TaskPlayAnim(ped, animDict, animName, 3.0, 3.0, -1, 2, 0, 0, 0, 0 )
                    Wait(500)
                    TriggerServerEvent("InteractSound_SV:PlayOnSource", "breaking_vitrine_glass", 0.25)
                    loadParticle()
                    StartParticleFxLoopedAtCoord("scr_jewel_cab_smash", plyCoords.x, plyCoords.y, plyCoords.z, 0.0, 0.0, 0.0, 1.0, false, false, false, false)
                    Wait(2500)
                end
            end)
        else
            QBCore.Functions.Notify(Lang:t('error.minimum_police', {value = Config.RequiredCops}), 'error')
        end
    end)
end

-- Events
local alarmon = false                                                                               --new boolean value for Client Alarm State

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
	QBCore.Functions.TriggerCallback('qb-jewellery:server:getVitrineState', function(result)
		Config.Locations = result
	end)
    QBCore.Functions.TriggerCallback('qb-jewellery:server:getAlarmState', function(result2)         --Load alarm state from server on spawn--
        alarmon = result2
    end)
end)

RegisterNetEvent('qb-jewellery:client:setVitrineState', function(stateType, state, k)
    Config.Locations[k][stateType] = state
end)

-- Threads

CreateThread(function()
    local Dealer = AddBlipForCoord(Config.JewelleryLocation["coords"]["x"], Config.JewelleryLocation["coords"]["y"], Config.JewelleryLocation["coords"]["z"])
    SetBlipSprite (Dealer, 617)
    SetBlipDisplay(Dealer, 4)
    SetBlipScale  (Dealer, 0.7)
    SetBlipAsShortRange(Dealer, true)
    SetBlipColour(Dealer, 3)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("Vangelico Jewelry")
    EndTextCommandSetBlipName(Dealer)
end)

local listen = false
local function Listen4Control(case)
    listen = true
    CreateThread(function()
        while listen do
            if IsControlJustPressed(0, 38) then
                listen = false
                if not Config.Locations[case]["isBusy"] and not Config.Locations[case]["isOpened"] then
                    exports['qb-core']:KeyPressed()
                        if validWeapon() and alarmon then                                                           --validWeapon AND alarmon
                            smashVitrine(case)
                        elseif not alarmon then
                            QBCore.Functions.Notify('You have to trigger the alarm by shooting', 'error')
                        else
                            QBCore.Functions.Notify(Lang:t('error.wrong_weapon'), 'error')
                        end
                    else
                        exports['qb-core']:DrawText(Lang:t('general.drawtextui_broken'), 'left')
                    end
                end
            Wait(1)
        end
    end)
end

CreateThread(function()
    if Config.UseTarget then
        for k, v in pairs(Config.Locations) do
            exports["qb-target"]:AddBoxZone("jewelstore" .. k, v.coords, 1, 1, {
                name = "jewelstore" .. k,
                heading = 40,
                minZ = v.coords.z - 1,
                maxZ = v.coords.z + 1,
                debugPoly = false
            }, {
                options = {
                    {
                        type = "client",
                        icon = "fa fa-hand",
                        label = Lang:t('general.target_label'),
                        action = function()
                            if validWeapon() then
                                smashVitrine(k)
                            else
                                QBCore.Functions.Notify(Lang:t('error.wrong_weapon'), 'error')
                            end
                        end,
                        canInteract = function()
                            if v["isOpened"] or v["isBusy"] then
                                return false
                            end
                            return true
                        end,
                    }
                },
                distance = 1.5
            })
        end
    else
        for k, v in pairs(Config.Locations) do
            local boxZone = BoxZone:Create(v.coords, 1, 1, {
                name="jewelstore"..k,
                heading = 40,
                minZ = v.coords.z - 1,
                maxZ = v.coords.z + 1,
                debugPoly = false
            })
            boxZone:onPlayerInOut(function(isPointInside)
                if isPointInside then
                    Listen4Control(k)
                    exports['qb-core']:DrawText(Lang:t('general.drawtextui_grab'), 'left')
                else
                    listen = false
                    exports['qb-core']:HideText()
                end
            end)
        end
    end
end)


-- NEW CODE START HERE


--Events
local playingsound = false
soundid = GetSoundId()

RegisterNetEvent('qb-jewellery:client:setAlarm', function(alarmstate2)
    if alarmstate2 then
        alarmon = true
    else
        firstAlarm = false
        alarmon = false
        playingsound = false
        StopSound(soundid)
        exports['qb-core']:HideText()
    end
end)

--Functions
local listenforalarm = false
local function Listen4Alarm()                                                                                           -- Triggered by PolyZone box Inside ++
    listenforalarm = true
    CreateThread(function()
        while listenforalarm do
            if alarmon then
                listenforalarm = false
                if not playingsound then
                    PlaySoundFromCoord(soundid, "VEHICLES_HORNS_AMBULANCE_WARNING", -622.01, -230.72, 40.01)            -- Change alarm sound coords here -- alarm coords
                    exports['qb-core']:DrawText('There is an alarm going on!', 'left')
                end
                playingsound = true
            end
            Wait(500)                                                                                                   -- Wait 500ms to check if alarm is on again --
        end
    end)
end

local listenforshot = false
local function Listen4Shot()
    listenforshot = true
    CreateThread(function()
        while listenforshot do
            if IsPedShooting(GetPlayerPed(-1)) then                                                                     --Is the player currently shooting
                listenforshot = false
                QBCore.Functions.TriggerCallback('qb-jewellery:server:getCops', function(cops)
                    if cops >= Config.RequiredCops then
                        QBCore.Functions.TriggerCallback('qb-scoreboard:server:GetConfig', function(config)
                            if not config.jewellery.busy then
                                TriggerServerEvent('qb-jewellery:server:setAlarm', true)
                                TriggerServerEvent('police:server:policeAlert', 'Alarm alert')
                            else
                                QBCore.Functions.Notify('Robbery on cooldown! Try later.') -- scoreboard said jewelery is unavailable / on cooldown
                            end
                        end)
                    else
                        QBCore.Functions.Notify('There is not enough cops right now!')
                    end
                end)
            end
            Wait(1)                                                                                                        -- Wait 1ms to check if player is shooting -- Need fast thread to catch shooting frame -- Need to test 2ms or more
        end
    end)
end

-- Threads

CreateThread(function() -- ALARM ZONE
    local boxZone = BoxZone:Create(vector3(-632.0, -249.0, 40.0), 200, 150, {                                              --Listen for Alarm sound box
        name="box_zone_jewelery_alarm",
        heading = 30,
        minZ = 30,
        maxZ = 50,
        debugPoly=false,
        })
        boxZone:onPlayerInOut(function(isPointInside) --JOUER ALARME SI EN COURS ET ARRET QUAND EN DEHORS DE LA ZONE
        if isPointInside then
            Listen4Alarm()
        else
            if playingsound then
                StopSound(soundid)
                exports['qb-core']:HideText()
                playingsound = false
            end
        end
    end)
end)

CreateThread(function() --SHOOT ZONE
    local boxZone2 = BoxZone:Create(vector3(-624.0, -232.0, 40.0), 20, 17, {                                                --Listen for Shooting box
        name="box_zone_jewelery_shot",
        heading = 36,
        minZ = 35,
        maxZ = 42,
        debugPoly=false,
    })
    boxZone2:onPlayerInOut(function(isPointInside)
        if isPointInside then
            if not alarmon then
                if not notified then
                    notified = true
                    QBCore.Functions.Notify('Shoot to start robbery')
                end
                Listen4Shot()
            end
        else
            listenforshot = false
            notified = false
        end
    end)
end)
