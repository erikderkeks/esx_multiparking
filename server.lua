local ESX = exports["es_extended"]:getSharedObject()

local usingOx   = Config.UseOxMysql
local tableName = Config.TableName

-- Wrapper für mysql-async / oxmysql
local function fetchAll(query, params, cb)
    if usingOx then
        exports.oxmysql:execute(query, params, cb)
    else
        MySQL.Async.fetchAll(query, params, cb)
    end
end

local function execute(query, params, cb)
    if usingOx then
        exports.oxmysql:update(query, params, cb)
    else
        MySQL.Async.execute(query, params, cb)
    end
end

-- Insurance → Gebühr
local function GetDepotFeeForInsurance(insurance)
    local fees = Config.Tow.Fees or {}
    local ins  = insurance and insurance:lower() or 'default'

    return fees[ins] or fees.default or 0
end

-- Fahrzeuge für Spieler holen (Garage oder Depot)
ESX.RegisterServerCallback('esx_garage:getStoredVehicles', function(source, cb, zoneType, zoneId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then cb({}) return end

    local identifier = xPlayer.getIdentifier()
    local query
    local params = {
        ['@owner']  = identifier,
        ['@garage'] = zoneId
    }

    if zoneType == 'garage' then
        query = ([[SELECT plate, vehicle, stored, garage, insurance
                   FROM %s
                   WHERE owner = @owner
                     AND stored = 1
                     AND (garage IS NULL OR garage = @garage)]])
            :format(tableName)
    elseif zoneType == 'depot' then
        query = ([[SELECT plate, vehicle, stored, garage, insurance
                   FROM %s
                   WHERE owner = @owner
                     AND stored = 2
                     AND garage = @garage]])
            :format(tableName)
    else
        cb({})
        return
    end

    fetchAll(query, params, function(result)
        local vehicles = {}

        for i = 1, #result do
            local row = result[i]
            local veh = json.decode(row.vehicle)

            veh.plate        = row.plate
            veh.storedStatus = row.stored
            veh.garage       = row.garage
            veh.insurance    = row.insurance  -- z.B. 'premium' oder 'standard'

            table.insert(vehicles, veh)
        end

        cb(vehicles)
    end)
end)

-- Fahrzeug einparken (Garage)
RegisterNetEvent('esx_garage:storeVehicle', function(plate, vehicleProps, garageId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local identifier = xPlayer.getIdentifier()

    local query = ([[UPDATE %s
                     SET vehicle = @vehicle,
                         stored  = 1,
                         garage  = @garage
                     WHERE owner = @owner AND plate = @plate]])
        :format(tableName)

    local params = {
        ['@vehicle'] = json.encode(vehicleProps),
        ['@garage']  = garageId,
        ['@owner']   = identifier,
        ['@plate']   = plate
    }

    execute(query, params, function(rowsChanged)
        if rowsChanged == 0 then
            TriggerClientEvent('esx:showNotification', src, 'Dieses Fahrzeug gehört dir nicht oder ist nicht registriert.')
        else
            TriggerClientEvent('esx:showNotification', src, 'Fahrzeug eingeparkt.')
        end
    end)
end)

-- Fahrzeug ausparken (Garage / Depot → Straße)
RegisterNetEvent('esx_garage:setVehicleOut', function(plate)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local identifier = xPlayer.getIdentifier()

    local query = ([[UPDATE %s
                     SET stored = 0
                     WHERE owner = @owner AND plate = @plate]])
        :format(tableName)

    local params = {
        ['@owner'] = identifier,
        ['@plate'] = plate
    }

    execute(query, params, function(rowsChanged)
        if rowsChanged == 0 then
            TriggerClientEvent('esx:showNotification', src, 'Fehler beim Ausparken.')
        end
    end)
end)

-- Fahrzeug in Abschlepphof setzen (Impound)
RegisterNetEvent('esx_garage:impoundVehicle', function(plate, depotId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    if not Config.Tow.Enabled then
        TriggerClientEvent('esx:showNotification', src, 'Abschleppen ist aktuell deaktiviert.')
        return
    end

    -- Job-Check
    local allowed = false
    for _, jobName in ipairs(Config.Tow.Jobs) do
        if xPlayer.job and xPlayer.job.name == jobName then
            allowed = true
            break
        end
    end

    if not allowed then
        TriggerClientEvent('esx:showNotification', src, 'Du darfst keine Fahrzeuge abschleppen.')
        return
    end

    local query = ([[UPDATE %s
                     SET stored = 2,
                         garage = @depot
                     WHERE plate = @plate]])
        :format(tableName)

    local params = {
        ['@depot'] = depotId,
        ['@plate'] = plate
    }

    execute(query, params, function(rowsChanged)
        if rowsChanged > 0 then
            TriggerClientEvent('esx:showNotification', src, 'Fahrzeug wurde in den Abschlepphof gebracht.')
        else
            TriggerClientEvent('esx:showNotification', src, 'Fahrzeug nicht in der Datenbank gefunden.')
        end
    end)
end)

-- Gebühr fürs Auslösen im Depot bezahlen
ESX.RegisterServerCallback('esx_garage:payDepotFee', function(source, cb, plate)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then cb(false, 'Fehler: Spieler nicht gefunden.') return end

    local identifier = xPlayer.getIdentifier()

    local query = ([[SELECT insurance
                     FROM %s
                     WHERE owner = @owner
                       AND plate = @plate
                       AND stored = 2]])
        :format(tableName)

    fetchAll(query, {
        ['@owner'] = identifier,
        ['@plate'] = plate
    }, function(result)
        if not result or #result == 0 then
            cb(false, 'Fahrzeug nicht im Abschlepphof gefunden.')
            return
        end

        local insurance = result[1].insurance or 'default'
        local fee       = GetDepotFeeForInsurance(insurance)

        if fee <= 0 then
            cb(true, 'Kein Betrag fällig (Premium-Versicherung).')
            return
        end

        local account = Config.Tow.PayAccount or 'bank'
        local money

        if account == 'bank' then
            money = xPlayer.getAccount('bank').money
        else
            money = xPlayer.getMoney()
        end

        if money < fee then
            cb(false, ('Du hast nicht genug Geld (benötigt: %s$).'):format(fee))
            return
        end

        if account == 'bank' then
            xPlayer.removeAccountMoney('bank', fee)
        else
            xPlayer.removeMoney(fee)
        end

        cb(true, ('Es wurden ~g~%s$~s~ für das Auslösen bezahlt.'):format(fee))
    end)
end)
