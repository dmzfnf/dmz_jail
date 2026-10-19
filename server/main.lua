local RES   = GetCurrentResourceName()
local FILE  = 'data/jail_data.json'
local jailed   = {}
local lastTask = {}

local function load()
    local raw = LoadResourceFile(RES, FILE)
    if raw and raw ~= '' then
        local ok, data = pcall(json.decode, raw)
        if ok and type(data) == 'table' then jailed = data end
    end
end

local function save()
    SaveResourceFile(RES, FILE, json.encode(jailed), -1)
end

local function getLicense(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'license:' then return id end
    end
end

local function findSource(license)
    for _, p in ipairs(GetPlayers()) do
        if getLicense(tonumber(p)) == license then return tonumber(p) end
    end
end

local function fmt(sec)
    sec = math.max(0, math.floor(sec))
    local h, m, s = sec // 3600, (sec % 3600) // 60, sec % 60
    if h > 0 then return ('%dh %02dmin'):format(h, m) end
    return ('%dmin %02ds'):format(m, s)
end

local function notify(src, kind, text)
    if src == 0 then print(('[dmz_jail] %s'):format(text)) return end
    TriggerClientEvent('dmz:client:notify', src, kind, text)
end

local function log(text)
    if Config.Webhook == '' then return end
    PerformHttpRequest(Config.Webhook, function() end, 'POST',
        json.encode({ username = 'Prison', content = text }),
        { ['Content-Type'] = 'application/json' })
end

local function isStaff(src)
    if src == 0 then return true end
    if Config.DevMode then return true end
    return IsPlayerAceAllowed(src, Config.AcePermission)
end

local function jailPlayer(staff, target, minutes, reason)
    local license = getLicense(target)
    if not license then return false end

    local by  = staff == 0 and 'Console' or GetPlayerName(staff)
    local old = jailed[license]

    if old then
        old.remaining = old.remaining + minutes * 60
        old.total     = old.total + minutes * 60
        old.reason    = (old.reason .. ' + ' .. reason):sub(1, 300)
        old.by        = by
        save()

        TriggerClientEvent('dmz:client:extend', target, old)
        log(('**%s** : +%d min par **%s** — %s (motif total : %s)'):format(old.name, minutes, by, reason, old.reason))
        return true, true
    end

    jailed[license] = {
        name      = GetPlayerName(target),
        remaining = minutes * 60,
        total     = minutes * 60,
        reason    = reason,
        by        = by,
        at        = os.time()
    }
    save()

    TriggerClientEvent('dmz:client:jail', target, jailed[license], false)
    log(('**%s** emprisonné %d min par **%s** — %s'):format(GetPlayerName(target), minutes, jailed[license].by, reason))
    return true
end

local function releasePlayer(license, by)
    local data = jailed[license]
    if not data then return false end
    jailed[license] = nil
    save()

    local src = findSource(license)
    if src then TriggerClientEvent('dmz:client:release', src) end
    log(('**%s** libéré%s'):format(data.name, by and (' par **' .. by .. '**') or ' (peine terminée)'))
    return true
end

local function menuData()
    local players, list = {}, {}
    for _, p in ipairs(GetPlayers()) do
        local id = tonumber(p)
        players[#players + 1] = { id = id, name = GetPlayerName(id), jailed = jailed[getLicense(id) or ''] ~= nil }
    end
    table.sort(players, function(a, b) return a.id < b.id end)

    for license, d in pairs(jailed) do
        list[#list + 1] = {
            license = license, name = d.name, remaining = d.remaining,
            total = d.total, reason = d.reason, by = d.by, online = findSource(license) ~= nil
        }
    end
    table.sort(list, function(a, b) return a.remaining < b.remaining end)
    return { players = players, jailed = list }
end

local function pushMenu(src)
    TriggerClientEvent('dmz:client:menuData', src, menuData())
end

local function parseJail(src, target, minutes, reason)
    target  = tonumber(target)
    minutes = math.floor(tonumber(minutes) or 0)
    reason  = tostring(reason or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if reason == '' then reason = 'Non précisé' end
    reason = reason:sub(1, 100)

    if not target or not GetPlayerName(target) then
        notify(src, 'error', 'Joueur introuvable.') return
    end
    if minutes < Config.MinMinutes or minutes > Config.MaxMinutes then
        notify(src, 'error', ('Durée invalide (%d à %d minutes).'):format(Config.MinMinutes, Config.MaxMinutes)) return
    end
    local ok, extended = jailPlayer(src, target, minutes, reason)
    if not ok then return end
    if extended then
        notify(src, 'success', ('%d min ajoutées à %s.'):format(minutes, GetPlayerName(target)))
        notify(target, 'info', ('Votre temps a été rajouté de %d min pour le motif : %s'):format(minutes, reason))
    else
        notify(src, 'success', ('%s emprisonné pour %d min.'):format(GetPlayerName(target), minutes))
        notify(target, 'info', ('Vous êtes emprisonné pour %d min. Motif : %s'):format(minutes, reason))
    end
end

RegisterCommand(Config.Commands.jail, function(src, args)
    if not isStaff(src) then return notify(src, 'error', 'Vous n\'avez pas accès à cette commande.') end
    if #args < 2 then
        if src == 0 then return print('Usage : jail [id] [minutes] [motif]') end
        return TriggerClientEvent('dmz:client:openMenu', src, menuData())
    end
    local id, min = args[1], args[2]
    table.remove(args, 1); table.remove(args, 1)
    parseJail(src, id, min, table.concat(args, ' '))
end, false)

RegisterCommand(Config.Commands.unjail, function(src, args)
    if not isStaff(src) then return notify(src, 'error', 'Vous n\'avez pas accès à cette commande.') end
    local target = tonumber(args[1])
    local license = target and GetPlayerName(target) and getLicense(target)
    if not license or not jailed[license] then
        return notify(src, 'error', 'Ce joueur n\'est pas en prison.')
    end
    releasePlayer(license, src == 0 and 'Console' or GetPlayerName(src))
    notify(src, 'success', 'Détenu libéré.')
end, false)

RegisterCommand(Config.Commands.menu, function(src)
    if src == 0 then return end
    if not isStaff(src) then return notify(src, 'error', 'Vous n\'avez pas accès au menu.') end
    TriggerClientEvent('dmz:client:openMenu', src, menuData())
end, false)

RegisterCommand(Config.Commands.time, function(src)
    if src == 0 then return print('Cette commande est réservée aux joueurs.') end

    local data = jailed[getLicense(src) or '']
    if not data then
        return notify(src, 'info', 'Vous n\'êtes pas en prison.')
    end

    notify(src, 'info', ('Temps restant : %s. Motif : %s'):format(fmt(data.remaining), data.reason))
end, false)

RegisterNetEvent('dmz:server:jail', function(target, minutes, reason)
    local src = source
    if not isStaff(src) then return end
    parseJail(src, target, minutes, reason)
    pushMenu(src)
end)

RegisterNetEvent('dmz:server:release', function(license)
    local src = source
    if not isStaff(src) or type(license) ~= 'string' then return end
    if releasePlayer(license, GetPlayerName(src)) then
        notify(src, 'success', 'Détenu libéré.')
    end
    pushMenu(src)
end)

RegisterNetEvent('dmz:server:refresh', function()
    local src = source
    if isStaff(src) then pushMenu(src) end
end)

RegisterNetEvent('dmz:server:ready', function()
    local src = source
    local d = jailed[getLicense(src) or '']
    if d then TriggerClientEvent('dmz:client:jail', src, d, true) end
end)

RegisterNetEvent('dmz:server:task', function(index)
    local src = source
    local license = getLicense(src)
    local d = license and jailed[license]
    local point = Config.Tasks.points[tonumber(index) or 0]
    if not (Config.Tasks.enabled and d and point) then return end

    if os.time() - (lastTask[src] or 0) < Config.Tasks.cooldown - 2 then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - point.coords) > 8.0 then return end
    lastTask[src] = os.time()

    d.remaining = math.max(0, d.remaining - Config.Tasks.reduction)
    if d.remaining <= 0 then
        notify(src, 'success', 'Bon travail, votre peine est terminée.')
        releasePlayer(license)
    else
        TriggerClientEvent('dmz:client:sync', src, d.remaining)
        notify(src, 'success', ('Peine réduite de %d s.'):format(Config.Tasks.reduction))
    end
end)

AddEventHandler('playerDropped', function()
    lastTask[source] = nil
    save()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == RES then save() end
end)

CreateThread(function()
    load()
    local tick = 0
    while true do
        Wait(10000)
        tick = tick + 1
        for _, p in ipairs(GetPlayers()) do
            local src = tonumber(p)
            local license = getLicense(src)
            local d = license and jailed[license]
            if d then
                d.remaining = d.remaining - 10
                if d.remaining <= 0 then
                    notify(src, 'success', 'Votre peine est terminée.')
                    releasePlayer(license)
                else
                    TriggerClientEvent('dmz:client:sync', src, d.remaining)
                end
            end
        end
        if tick % 6 == 0 then save() end
    end
end)
