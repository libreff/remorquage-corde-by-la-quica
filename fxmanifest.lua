fx_version 'cerulean'
game 'gta5'

author 'La Quica'
description 'Remorquage physique et synchronisé par corde'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_script 'client/main.lua'
server_script 'server/main.lua'

dependencies {
    'ox_lib',
    'ox_target',
    'es_extended',
    'acn_inventory'
}
