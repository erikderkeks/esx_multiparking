Config = {}

-- Allgemein
Config.Locale = 'de'

-- Datenbank
Config.UseOxMysql   = false                -- true, wenn du oxmysql verwendest
Config.TableName    = 'owned_vehicles'     -- oder 'ownvehicles', je nach Server

-- Marker / Interaktion
Config.DrawDistance = 25.0                 -- Sichtweite für Marker
Config.Marker = {
    type  = 27,                            -- 27 = runder Marker, sieht gut aus
    size  = vector3(2.7, 2.7, 1.0),
    color = { r = 0, g = 150, b = 255, a = 180 }
}

Config.InteractKey      = 38               -- E
Config.InteractKeyLabel = '~INPUT_PICKUP~' -- E im Text

-- Menü-Design (vMenu-Style Header)
Config.Menu = {
    Align       = 'top-left',
    GarageTitle = '~b~[ GARAGE ]~s~',
    DepotTitle  = '~o~[ ABSCHLEPPHOF ]~s~'
}

-- Abschlepper-Einstellungen + Insurance-Preise
Config.Tow = {
    Enabled  = true,
    Jobs     = { 'mechanic', 'police' },   -- diese Jobs dürfen im Depot abschleppen

    -- Preise je nach Versicherung
    Fees = {
        default  = 300,    -- Fallback, wenn nix passt
        standard = 200,
        premium  = 0,
        none     = 300     -- explizit "keine"
    },

    -- Von welchem Konto wird abgebucht? 'bank' oder 'money'
    PayAccount = 'bank'
}

-- GARAGEN (Key = ID, gleiche ID steht dann in der DB-Spalte "garage")
Config.Garages = {
    ['central'] = {
        label  = 'Stadtgarage Zentrum',
        coords = vector3(215.124, -791.377, 30.8),
        spawn  = {
            coords  = vector3(229.700, -800.114, 30.6),
            heading = 160.0
        },
        blip = {
            sprite = 357,
            color  = 3,
            scale  = 0.8
        }
    },

    ['sandy'] = {
        label  = 'Sandy Shores Garage',
        coords = vector3(1737.0, 3710.0, 34.1),
        spawn  = {
            coords  = vector3(1745.0, 3705.0, 34.1),
            heading = 120.0
        },
        blip = {
            sprite = 357,
            color  = 46,
            scale  = 0.8
        }
    },

    ['paleto'] = {
        label  = 'Paleto Bay Garage',
        coords = vector3(-188.34, 6427.33, 31.66),
        spawn  = {
            coords  = vector3(-171.52, 6407.07, 31.92),
            heading = 225.0
        },
        blip = {
            sprite = 357,
            color  = 2,
            scale  = 0.8
        }
    }
}

-- ABSCHLEPPHÖFE / DEPOTS
Config.Depots = {
    ['citydepot'] = {
        label  = 'Abschlepphof Stadt',
        coords = vector3(409.37, -1623.62, 29.29),
        spawn  = {
            coords  = vector3(402.48, -1644.97, 29.29),
            heading = 230.0
        },
        blip = {
            sprite = 68,
            color  = 5,
            scale  = 0.8
        }
    },

    ['sandydepot'] = {
        label  = 'Abschlepphof Sandy',
        coords = vector3(1653.63, 3809.10, 34.99),
        spawn  = {
            coords  = vector3(1662.19, 3800.88, 34.77),
            heading = 210.0
        },
        blip = {
            sprite = 68,
            color  = 46,
            scale  = 0.8
        }
    }
}
