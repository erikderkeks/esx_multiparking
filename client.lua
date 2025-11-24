local ESX = exports["es_extended"]:getSharedObject()

local PlayerData = {}
local IsInMarker  = false
local CurrentZone = nil -- { type = "garage" / "depot", id = "central" / "citydepot" }

-- ESX Events
RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob', function(job)
    if PlayerData then
        PlayerData.job = job
    end
end)

-- Abschlepper-Job?
local function IsTowJob()
    if not PlayerData or not PlayerData.job then return false end
    for _, jobName in ipairs(Config.Tow.Jobs) do
        if PlayerData.job.name == jobName then
            return true
        end
    end
    return false
end

-- Insurance → Gebühr (für Anzeige)
local function GetDepotFeeForInsurance(insuranceType)
    local fees = Config.Tow.Fees or {}
    local ins  = insuranceType and insuranceType:lower() or 'default'

    return fees[ins] or fees.default or 0
end

-- Blips erstellen
CreateThread(function()
    -- Garagen
    for id, garage in pairs(Config.Garages) do
        if garage.blip then
            local blip = AddBlipForCoord(garage.coords)
            SetBlipSprite(blip, garage.blip.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, garage.blip.scale)
            SetBlipColour(blip, garage.blip.color)
            SetBlipAsShortRange(blip, true)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(garage.label)
            EndTextCommandSetBlipName(blip)
        end
    end

    -- Depots
    for id, depot in pairs(Config.Depots) do
        if depot.blip then
            local blip = AddBlipForCoord(depot.coords)
            SetBlipSprite(blip, depot.blip.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, depot.blip.scale)
            SetBlipColour(blip, depot.blip.color)
            SetBlipAsShortRange(blip, true)

            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(depot.label)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- Marker zeichnen
local function DrawMarkerAt(coords)
    DrawMarker(
        Config.Marker.type,
        coords.x, coords.y, coords.z - 1.0,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        Config.Marker.size.x, Config.Marker.size.y, Config.Marker.size.z,
        Config.Marker.color.r, Config.Marker.color.g, Config.Marker.color.b, Config.Marker.color.a,
        false, true, 2, nil, nil, false
    )
end

-- Hauptloop: Marker + Notify + E
CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local coords    = GetEntityCoords(playerPed)

        local newZone = nil

        -- Garagen
        for id, garage in pairs(Config.Garages) do
            local dist = #(coords - garage.coords)

            if dist < Config.DrawDistance then
                sleep = 0
                DrawMarkerAt(garage.coords)
            end

            if dist < Config.Marker.size.x then
                newZone = { type = 'garage', id = id }
            end
        end

        -- Depots
        for id, depot in pairs(Config.Depots) do
            local dist = #(coords - depot.coords)

            if dist < Config.DrawDistance then
                sleep = 0
                DrawMarkerAt(depot.coords)
            end

            if dist < Config.Marker.size.x then
                newZone = { type = 'depot', id = id }
            end
        end

        -- Betreten / Verlassen
        if newZone and not IsInMarker then
            IsInMarker  = true
            CurrentZone = newZone

            if newZone.type == 'garage' then
                local g = Config.Garages[newZone.id]
                ESX.ShowNotification(
                    ('Garage: ~b~%s~s~\nDrücke %s um das Parkmenü zu öffnen.')
                        ):format(g.label, Config.InteractKeyLabel)
            elseif newZone.type == 'depot' then
                local d = Config.Depots[newZone.id]
                ESX.ShowNotification(
                    ('Abschlepphof: ~o~%s~s~\nDrücke %s um das Abschlepp-Menü zu öffnen.')
                        ):format(d.label, Config.InteractKeyLabel)
            end

        elseif not newZone and IsInMarker then
            IsInMarker  = false
            CurrentZone = nil
        end

        -- E drücken im Marker
        if IsInMarker and CurrentZone then
            sleep = 0
            if IsControlJustReleased(0, Config.InteractKey) then
                if CurrentZone.type == 'garage' then
                    OpenGarageMenu(CurrentZone.id)
                elseif CurrentZone.type == 'depot' then
                    OpenDepotMenu(CurrentZone.id)
                end
            end
        end

        Wait(sleep)
    end
end)

-- G A R A G E   M E N Ü
function OpenGarageMenu(garageId)
    local garage = Config.Garages[garageId]
    if not garage then return end

    local elements = {}

    table.insert(elements, { label = 'Fahrzeug einparken', value = 'store' })
    table.insert(elements, { label = '──────────────', value = 'sep', disabled = true })

    ESX.TriggerServerCallback('esx_garage:getStoredVehicles', function(vehicles)
        if #vehicles == 0 then
            table.insert(elements, { label = 'Keine Fahrzeuge in dieser Garage.', value = 'none', disabled = true })
        else
            for _, v in ipairs(vehicles) do
                if v.storedStatus == 1 then
                    local label = string.format('%s | %s', GetDisplayNameFromVehicleModel(v.model), v.plate)
                    table.insert(elements, {
                        label    = label,
                        value    = 'spawn',
                        vehProps = v
                    })
                end
            end
        end

        ESX.UI.Menu.CloseAll()

        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'garage_menu', {
            title    = string.format('%s ~w~%s', Config.Menu.GarageTitle, garage.label),
            align    = Config.Menu.Align,
            elements = elements
        }, function(data, menu)
            if data.current.value == 'store' then
                StoreVehicle(garageId)
            elseif data.current.value == 'spawn' then
                SpawnVehicleFromLocation(garageId, 'garage', data.current.vehProps, false)
            end
        end, function(data, menu)
            menu.close()
        end)
    end, 'garage', garageId)
end

-- D E P O T   M E N Ü  (Abschlepper + Auslösen)
function OpenDepotMenu(depotId)
    local depot = Config.Depots[depotId]
    if not depot then return end

    local elements = {}

    local playerPed = PlayerPedId()
    local coords    = GetEntityCoords(playerPed)

    local canImpound = false
    local impoundPlate
    local nearestVeh, vehDist = ESX.Game.GetClosestVehicle(coords)

    if Config.Tow.Enabled and IsTowJob() and nearestVeh ~= 0 and vehDist < 8.0 then
        impoundPlate = ESX.Math.Trim(GetVehicleNumberPlateText(nearestVeh))
        canImpound   = true

        table.insert(elements, {
            label = 'Fahrzeug in Abschlepphof einparken',
            value = 'impound',
            plate = impoundPlate
        })
        table.insert(elements, { label = '──────────────', value = 'sep1', disabled = true })
    end

    ESX.TriggerServerCallback('esx_garage:getStoredVehicles', function(vehicles)
        table.insert(elements, {
            label    = 'Gebühr je nach Versicherung (premium/standard/keine).',
            value    = 'info',
            disabled = true
        })
        table.insert(elements, { label = '──────────────', value = 'sep2', disabled = true })

        local found = false

        for _, v in ipairs(vehicles) do
            if v.storedStatus == 2 then
                found = true
                local insurance = v.insurance or 'default'
                local fee       = GetDepotFeeForInsurance(insurance)

                local label = string.format(
                    '%s | %s (~c~%s~s~, ~g~%s$~s~)',
                    GetDisplayNameFromVehicleModel(v.model),
                    v.plate,
                    insurance,
                    fee
                )

                table.insert(elements, {
                    label      = label,
                    value      = 'spawn',
                    vehProps   = v,
                    insurance  = insurance,
                    depotFee   = fee
                })
            end
        end

        if not found then
            table.insert(elements, { label = 'Keine Fahrzeuge im Abschlepphof.', value = 'none', disabled = true })
        end

        ESX.UI.Menu.CloseAll()

        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'depot_menu', {
            title    = string.format('%s ~w~%s', Config.Menu.DepotTitle, depot.label),
            align    = Config.Menu.Align,
            elements = elements
        }, function(data, menu)
            if data.current.value == 'impound' then
                if not canImpound or not impoundPlate then
                    ESX.ShowNotification('Kein Fahrzeug zum Abschleppen gefunden.')
                    return
                end

                -- Sicherheit: erneut prüfen
                local veh, dist = ESX.Game.GetClosestVehicle(GetEntityCoords(PlayerPedId()))
                if veh ~= 0 and dist < 8.0 then
                    TriggerServerEvent('esx_garage:impoundVehicle', impoundPlate, depotId)
                    ESX.Game.DeleteVehicle(veh)
                else
                    ESX.ShowNotification('Kein Fahrzeug in der Nähe.')
                end

            elseif data.current.value == 'spawn' then
                local plate = data.current.vehProps.plate

                ESX.TriggerServerCallback('esx_garage:payDepotFee', function(paid, msg)
                    if msg then
                        ESX.ShowNotification(msg)
                    end

                    if paid then
                        SpawnVehicleFromLocation(depotId, 'depot', data.current.vehProps, true)
                    end
                end, plate)
            end
        end, function(data, menu)
            menu.close()
        end)
    end, 'depot', depotId)
end

-- Fahrzeug einparken (Garage)
function StoreVehicle(garageId)
    local garage = Config.Garages[garageId]
    if not garage then return end

    local playerPed = PlayerPedId()

    if not IsPedInAnyVehicle(playerPed, false) then
        ESX.ShowNotification('Du sitzt in keinem Fahrzeug.')
        return
    end

    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if GetPedInVehicleSeat(vehicle, -1) ~= playerPed then
        ESX.ShowNotification('Du musst Fahrer sein.')
        return
    end

    local plate    = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))
    local vehProps = ESX.Game.GetVehicleProperties(vehicle)

    TriggerServerEvent('esx_garage:storeVehicle', plate, vehProps, garageId)
    ESX.Game.DeleteVehicle(vehicle)
end

-- Fahrzeug an Garage oder Depot spawnen
function SpawnVehicleFromLocation(locationId, zoneType, vehProps, fromDepot)
    local location

    if zoneType == 'garage' then
        location = Config.Garages[locationId]
    else
        location = Config.Depots[locationId]
    end

    if not location then return end

    ESX.Game.SpawnVehicle(vehProps.model, location.spawn.coords, location.spawn.heading, function(vehicle)
        ESX.Game.SetVehicleProperties(vehicle, vehProps)
        SetVehicleNumberPlateText(vehicle, vehProps.plate or 'GARAGE')
        SetVehicleOnGroundProperly(vehicle)
        TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    end)

    TriggerServerEvent('esx_garage:setVehicleOut', vehProps.plate)

    if fromDepot then
        ESX.ShowNotification('Fahrzeug aus dem Abschlepphof abgeholt.')
    else
        ESX.ShowNotification('Fahrzeug ausgeparkt.')
    end
end
