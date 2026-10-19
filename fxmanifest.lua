version '1.0.0-7dd9b6b'
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'DmZ Corp'
description 'dmz_jail simple system jail'

ui_page 'web/index.html'

files {
    'web/*'
}

shared_script 'config.lua'
client_script 'client/main.lua'
server_script 'server/main.lua'
