Config = {}

Config.Commands = {
    jail    = 'jail',
    unjail  = 'unjail',
    menu    = 'jailmenu',
    time    = 'jailtime'
}

Config.Webhook = ''
Config.DevMode = true -- DevMode enable permanent access for everyone
Config.AcePermission = 'dmz.admin' -- add_ace group.admin dmz.admin allow
Config.Fade = { out = 600, hold = 800, back = 600 }
Config.NoPeds = true

Config.MinMinutes     = 1
Config.MaxMinutes     = 240
Config.TimePresets    = { 1, 5, 10, 15, 30, 60 }
Config.ReasonPresets  = { 'Freekill', 'Nopain', 'RDM', 'VDM', 'Carkill', 'Fail RP', 'Metagaming', 'Powergaming', 'Troll', 'Insultes', 'Déco en scène' }

Config.Prison = {
    center = vec3(-2176.3650, 5189.3560, 16.9032),
    radius = 140.0,
    cells  = {
        vec4(-2176.3650, 5189.3560, 16.9032, 227.7059)
    }
}

Config.Release = vec4(1847.9, 2585.9, 45.67, 270.0)

Config.Tasks = {
    enabled   = false,
    reduction = 60,
    cooldown  = 45,
    duration  = 7000,
    points = {
        -- { label = 'Nettoyer la cour', scenario = 'WORLD_HUMAN_JANITOR',  coords = vec3(1685.9, 2551.2, 45.56) } -- EXEMPLE
    }
}