local state      = nil
local menuOpen   = false
local taskBusy   = false
local nextTaskAt = 0

local function nui(data) SendNUIMessage(data) end

local function notify(kind, text)
    nui({ action = 'toast', kind = kind, text = text })
end

local function hud()
    if not state then return nui({ action = 'hud', show = false }) end
    nui({ action = 'hud', show = true, remaining = state.remaining, reason = state.reason, by = state.by })
end

local function teleport(c)
    local ped = PlayerPedId()
    DoScreenFadeOut(Config.Fade.out)
    while not IsScreenFadedOut() do Wait(0) end
    local blackAt = GetGameTimer()

    ClearPedTasksImmediately(ped)
    RequestCollisionAtCoord(c.x, c.y, c.z)
    SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
    SetEntityHeading(ped, c.w or 0.0)
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() - blackAt < 3000 do Wait(0) end

    local left = Config.Fade.hold - (GetGameTimer() - blackAt)
    if left > 0 then Wait(left) end
    DoScreenFadeIn(Config.Fade.back)
end

local function toCell()
    teleport(Config.Prison.cells[math.random(#Config.Prison.cells)])
end

local function help(msg)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

RegisterNetEvent('dmz:client:jail', function(data, restore)
    state = { remaining = data.remaining, total = data.total, reason = data.reason, by = data.by }
    RemoveAllPedWeapons(PlayerPedId(), true)
    hud()

    local dist = #(GetEntityCoords(PlayerPedId()) - Config.Prison.center)
    if not restore or dist > Config.Prison.radius then toCell() end
end)

RegisterNetEvent('dmz:client:extend', function(data)
    if not state then
        state = {}
    end
    state.remaining, state.total, state.reason, state.by = data.remaining, data.total, data.reason, data.by
    hud()
end)

RegisterNetEvent('dmz:client:sync', function(remaining)
    if state then state.remaining = remaining; hud() end
end)

RegisterNetEvent('dmz:client:release', function()
    state = nil
    taskBusy = false
    hud()
    nui({ action = 'progress', show = false })
    teleport(Config.Release)
end)

RegisterNetEvent('dmz:client:notify', function(kind, text)
    notify(kind, text)
end)

RegisterNetEvent('dmz:client:openMenu', function(data)
    menuOpen = true
    SetNuiFocus(true, true)
    nui({
        action   = 'open',
        players  = data.players,
        jailed   = data.jailed,
        settings = {
            min = Config.MinMinutes, max = Config.MaxMinutes,
            times = Config.TimePresets, reasons = Config.ReasonPresets
        }
    })
end)

RegisterNetEvent('dmz:client:menuData', function(data)
    if menuOpen then nui({ action = 'data', players = data.players, jailed = data.jailed }) end
end)

local function closeMenu()
    menuOpen = false
    SetNuiFocus(false, false)
    nui({ action = 'close' })
end

RegisterNUICallback('close',   function(_, cb) closeMenu(); cb('ok') end)
RegisterNUICallback('refresh', function(_, cb) TriggerServerEvent('dmz:server:refresh'); cb('ok') end)
RegisterNUICallback('jail',    function(d, cb) TriggerServerEvent('dmz:server:jail', d.target, d.minutes, d.reason); cb('ok') end)
RegisterNUICallback('release', function(d, cb) TriggerServerEvent('dmz:server:release', d.license); cb('ok') end)

CreateThread(function()
    while true do
        Wait(1000)
        if state and state.remaining > 0 then
            state.remaining = state.remaining - 1
            hud()
        end
    end
end)

CreateThread(function()
    local unarmed = GetHashKey('WEAPON_UNARMED')
    while true do
        if state then
            Wait(0)
            for _, c in ipairs({ 24, 25, 47, 58, 140, 141, 142, 143, 257, 263, 264, 23 }) do
                DisableControlAction(0, c, true)
            end
            local ped = PlayerPedId()
            if GetSelectedPedWeapon(ped) ~= unarmed then RemoveAllPedWeapons(ped, true) end
        else
            Wait(750)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1500)
        if state and not taskBusy then
            local dist = #(GetEntityCoords(PlayerPedId()) - Config.Prison.center)
            if dist > Config.Prison.radius then
                notify('error', 'Évasion impossible : retour en cellule.')
                toCell()
            end
        end
    end
end)

local function doTask(index, point)
    taskBusy = true
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    TaskStartScenarioInPlace(ped, point.scenario, 0, true)
    nui({ action = 'progress', show = true, label = point.label, duration = Config.Tasks.duration })

    local endAt = GetGameTimer() + Config.Tasks.duration
    while GetGameTimer() < endAt and state do Wait(100) end

    nui({ action = 'progress', show = false })
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    if state then
        TriggerServerEvent('dmz:server:task', index)
        nextTaskAt = GetGameTimer() + Config.Tasks.cooldown * 1000
    end
    taskBusy = false
end

CreateThread(function()
    while true do
        if state and Config.Tasks.enabled and not taskBusy then
            local pos, nearest = GetEntityCoords(PlayerPedId()), 9999.0
            for i, p in ipairs(Config.Tasks.points) do
                local d = #(pos - p.coords)
                nearest = math.min(nearest, d)
                if d < 25.0 then
                    DrawMarker(1, p.coords.x, p.coords.y, p.coords.z - 1.0, 0, 0, 0, 0, 0, 0,
                        1.2, 1.2, 0.5, 232, 96, 28, 140, false, false, 2, false, nil, nil, false)
                end
                if d < 1.4 then
                    local wait = nextTaskAt - GetGameTimer()
                    if wait > 0 then
                        help(('Reposez-vous encore %d s avant la prochaine tâche.'):format(math.ceil(wait / 1000)))
                    else
                        help(('~INPUT_CONTEXT~ %s (-%d s de peine)'):format(p.label, Config.Tasks.reduction))
                        if IsControlJustPressed(0, 38) then doTask(i, p) end
                    end
                end
            end
            Wait(nearest < 25.0 and 0 or 750)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    if not Config.NoPeds then return end
    local c, r = Config.Prison.center, Config.Prison.radius + 60.0
    AddScenarioBlockingArea(c.x - r, c.y - r, c.z - 80.0, c.x + r, c.y + r, c.z + 80.0, false, true, true, true)

    while true do
        local dist = #(GetEntityCoords(PlayerPedId()) - c)
        if dist < r + 150.0 then
            Wait(0)
            SetPedDensityMultiplierThisFrame(0.0)
            SetScenarioPedDensityMultiplierThisFrame(0.0, 0.0)
        else
            Wait(1500)
        end
    end
end)

CreateThread(function()
    if not Config.NoPeds then return end
    local c, r = Config.Prison.center, Config.Prison.radius + 60.0
    while true do
        Wait(1000)
        if #(GetEntityCoords(PlayerPedId()) - c) < r + 150.0 then
            ClearAreaOfPeds(c.x, c.y, c.z, r, 1)
            for _, p in ipairs(GetGamePool('CPed')) do
                if not IsPedAPlayer(p) and #(GetEntityCoords(p) - c) < r then
                    SetEntityAsMissionEntity(p, true, true)
                    DeleteEntity(p)
                end
            end
        end
    end
end)

local function askState() Wait(3000); TriggerServerEvent('dmz:server:ready') end

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    askState()
end)
AddEventHandler('playerSpawned', function() CreateThread(askState) end)

CreateThread(function()
    Wait(2000)
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.jail, 'Emprisonner un joueur (sans argument : ouvre le menu)', {
        { name = 'id', help = 'ID du joueur' }, { name = 'minutes', help = 'Durée' }, { name = 'motif', help = 'Motif' } })
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.unjail, 'Libérer un joueur', { { name = 'id', help = 'ID du joueur' } })
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.menu, 'Ouvrir le menu de la prison')
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.time, 'Voir votre temps restant en prison')
end)
