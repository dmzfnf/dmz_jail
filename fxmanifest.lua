<<<<<<< HEAD
version '1.0.0-1f84ef3'
=======
version '1.0.0'
>>>>>>> 35612b1 (delete all system version commit ect)
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
