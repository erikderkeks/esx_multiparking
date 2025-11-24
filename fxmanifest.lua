fx_version 'cerulean'
game 'gta5'

author 'erikderkeks'
description 'ESX Garage + Abschlepphof mit Marker & E, Insurance-Preisen und vMenu-Style Header'
version '1.0.0'

shared_script 'config.lua'

server_scripts {
    '@mysql-async/lib/MySQL.lua', -- bei oxmysql: entfernen / anpassen, siehe config.lua
    'server.lua'
}

client_scripts {
    'client.lua'
}
