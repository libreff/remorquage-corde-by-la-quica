local placement
local carryRope
local carryProp
local ropeStates = {}
local ropeHandles = {}
local ownedRopeId
local breakPending = {}
local textVisible = false
local detachBusy = false

local function notify(description, kind)
    lib.notify({ title = 'Corde de remorquage', description = description, type = kind or 'inform' })
end

local function hideText()
    if textVisible then lib.hideTextUI() end
    textVisible = false
end

local function showText(text)
    if textVisible == text then return end
    if textVisible then lib.hideTextUI() end
    lib.showTextUI(text, { position = 'right-center', icon = 'link' })
    textVisible = text
end

local function loadRopeTextures()
    if RopeAreTexturesLoaded() then return true end
    RopeLoadTextures()
    local timeout = GetGameTimer() + 3000
    while not RopeAreTexturesLoaded() and GetGameTimer() < timeout do Wait(0) end
    return RopeAreTexturesLoaded()
end

local function deleteRopeHandle(handle)
    if handle and DoesRopeExist(handle) then DeleteRope(handle) end
end

local function requestControl(entity, duration)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if NetworkHasControlOfEntity(entity) then return true end
    local timeout = GetGameTimer() + (duration or 1000)
    NetworkRequestControlOfEntity(entity)
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
        Wait(0)
        NetworkRequestControlOfEntity(entity)
    end
    return NetworkHasControlOfEntity(entity)
end

local function attachmentPoint(vehicle, rear)
    local minimum, maximum = GetModelDimensions(GetEntityModel(vehicle))
    local y = rear and (minimum.y - 0.08) or (maximum.y + 0.08)
    local height = maximum.z - minimum.z
    local z = minimum.z + math.max(0.28, height * 0.32)
    return GetOffsetFromEntityInWorldCoords(vehicle, 0.0, y, z)
end

local function nearestAttachment(rear)
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local selectedVehicle, selectedPoint, selectedDistance

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) and (not placement or not placement.tractorNetId or VehToNet(vehicle) ~= placement.tractorNetId) then
            local point = attachmentPoint(vehicle, rear)
            local currentDistance = #(pedCoords - point)
            if currentDistance <= Config.InteractionDistance and (not selectedDistance or currentDistance < selectedDistance) then
                selectedVehicle, selectedPoint, selectedDistance = vehicle, point, currentDistance
            end
        end
    end

    return selectedVehicle, selectedPoint
end

local function deleteCarryVisuals()
    deleteRopeHandle(carryRope)
    carryRope = nil
    if carryProp and DoesEntityExist(carryProp) then DeleteEntity(carryProp) end
    carryProp = nil
end

local function createCarryProp()
    if Config.RopeOnly then return end
    local model = joaat(Config.CarryProp)
    if not IsModelInCdimage(model) or not IsModelValid(model) then return end
    lib.requestModel(model, 3000)
    carryProp = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
    AttachEntityToEntity(carryProp, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), 57005), 0.10, 0.02, -0.02, 90.0, 20.0, 15.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)
end

local function createCarryRope(vehicle)
    deleteCarryVisuals()
    if not loadRopeTextures() then return end

    local rear = attachmentPoint(vehicle, true)
    local hand = GetPedBoneCoords(PlayerPedId(), 57005, 0.0, 0.0, 0.0)
    local length = math.max(Config.MinRopeLength, #(rear - hand) + 1.0)
    carryRope = AddRope(rear.x, rear.y, rear.z, 0.0, 0.0, 0.0, Config.MaxPlacementDistance, Config.RopeType, length, 0.5, 0.5, false, false, true, 1.0, false, 0)
    AttachEntitiesToRope(carryRope, vehicle, PlayerPedId(), rear.x, rear.y, rear.z, hand.x, hand.y, hand.z, length, false, false, nil, nil)
    createCarryProp()
end

local function attachmentAnimation(vehicle, label, duration)
    TaskTurnPedToFaceEntity(PlayerPedId(), vehicle, 500)
    Wait(350)
    return lib.progressBar({
        duration = duration,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = Config.Animation
    })
end

local function errorText(code)
    local errors = {
        missing_item = 'Vous ne possédez pas l’item CORDE.',
        already_towing = 'Vous avez déjà une corde de remorquage active.',
        expired = 'La préparation de la corde a expiré.',
        invalid_vehicle = 'Ce véhicule n’est pas valide.',
        too_far = 'Vous êtes trop loin du véhicule.',
        vehicles_too_far = 'Les deux véhicules sont trop éloignés.',
        vehicle_busy = 'Un de ces véhicules est déjà relié à une corde.',
        not_owner = 'Seul le joueur ayant installé cette corde peut la retirer.'
    }
    return errors[code] or 'Action impossible.'
end

local function cancelPlacement(server, silent)
    placement = nil
    hideText()
    deleteCarryVisuals()
    if server then lib.callback.await('remorquage_corde:server:cancel', false) end
    if not silent then notify(Config.Text.cancelled, 'warning') end
end

local function attachFirst(vehicle)
    if not attachmentAnimation(vehicle, 'Fixation à l’arrière du véhicule tracteur', Config.AttachDuration) then return end
    local netId = VehToNet(vehicle)
    if netId == 0 then return notify('Ce véhicule n’est pas synchronisé.', 'error') end

    local response = lib.callback.await('remorquage_corde:server:setTractor', false, netId)
    if not response or not response.ok then return notify(errorText(response and response.code), 'error') end

    placement.stage = 'towed'
    placement.tractorNetId = netId
    createCarryRope(vehicle)
    notify(Config.Text.attachedFirst, 'success')
end

local function attachSecond(vehicle)
    if not attachmentAnimation(vehicle, 'Fixation à l’avant du véhicule tracté', Config.AttachDuration) then return end
    local netId = VehToNet(vehicle)
    if netId == 0 then return notify('Ce véhicule n’est pas synchronisé.', 'error') end

    local response = lib.callback.await('remorquage_corde:server:complete', false, netId)
    if not response or not response.ok then return notify(errorText(response and response.code), 'error') end

    placement = nil
    hideText()
    deleteCarryVisuals()
    notify(Config.Text.ropeReady, 'success')
end

local function startPlacement()
    if placement then return end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return notify('Descendez du véhicule pour manipuler la corde.', 'error') end

    local response = lib.callback.await('remorquage_corde:server:begin', false)
    if not response or not response.ok then return notify(errorText(response and response.code), 'error') end

    placement = { stage = 'tractor', candidate = nil, point = nil, lastScan = 0 }
    notify('Placez-vous derrière le véhicule qui servira de tracteur.', 'inform')

    CreateThread(function()
        while placement do
            local now = GetGameTimer()
            if now - placement.lastScan >= 180 then
                placement.lastScan = now
                placement.candidate, placement.point = nearestAttachment(placement.stage == 'tractor')
            end

            if placement.candidate and DoesEntityExist(placement.candidate) and placement.point then
                local colour = placement.stage == 'tractor' and Config.Marker.tractorColour or Config.Marker.towedColour
                DrawMarker(Config.Marker.type, placement.point.x, placement.point.y, placement.point.z + 0.08, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, Config.Marker.scale.x, Config.Marker.scale.y, Config.Marker.scale.z, colour[1], colour[2], colour[3], colour[4], false, true, 2, false, nil, nil, false)
                showText((placement.stage == 'tractor' and Config.Text.selectTractor or Config.Text.selectTowed) .. '\n' .. Config.Text.cancel)

                if IsControlJustReleased(0, Config.Controls.confirm) then
                    local vehicle = placement.candidate
                    if placement.stage == 'tractor' then attachFirst(vehicle) else attachSecond(vehicle) end
                end
            else
                showText(Config.Text.noVehicle .. '\n' .. Config.Text.cancel)
            end

            if carryRope and placement.tractorNetId then
                local tractor = NetToVeh(placement.tractorNetId)
                if tractor ~= 0 and DoesEntityExist(tractor) then
                    local rear = attachmentPoint(tractor, true)
                    local hand = GetPedBoneCoords(PlayerPedId(), 57005, 0.0, 0.0, 0.0)
                    RopeForceLength(carryRope, math.min(Config.MaxPlacementDistance, math.max(Config.MinRopeLength, #(rear - hand) + 0.8)))
                end
            end

            if IsControlJustReleased(0, Config.Controls.cancel) then cancelPlacement(true, false) end
            Wait(0)
        end
        hideText()
    end)
end

local function removeVisual(ropeId, keepState)
    deleteRopeHandle(ropeHandles[ropeId])
    ropeHandles[ropeId] = nil
    if not keepState then ropeStates[ropeId] = nil end
end

local function ensureVisual(ropeId)
    if ropeHandles[ropeId] or not ropeStates[ropeId] then return end
    local data = ropeStates[ropeId]
    local tractor = NetToVeh(data.tractorNetId)
    local towed = NetToVeh(data.towedNetId)
    if tractor == 0 or towed == 0 or not DoesEntityExist(tractor) or not DoesEntityExist(towed) then return end
    if not loadRopeTextures() then return end

    if data.owner == GetPlayerServerId(PlayerId()) then
        requestControl(tractor, 500)
        requestControl(towed, 1000)
        SetVehicleHandbrake(towed, false)
        SetVehicleBrake(towed, false)
        ActivatePhysics(towed)
    end

    local rear = attachmentPoint(tractor, true)
    local front = attachmentPoint(towed, false)
    local rope = AddRope(rear.x, rear.y, rear.z, 0.0, 0.0, 0.0, Config.MaxRopeLength, Config.RopeType, data.length, Config.MinRopeLength, 0.5, false, false, true, 1.0, false, 0)
    AttachEntitiesToRope(rope, tractor, towed, rear.x, rear.y, rear.z, front.x, front.y, front.z, data.length, false, false, nil, nil)
    RopeForceLength(rope, data.length)
    ropeHandles[ropeId] = rope
end

local function detachOwnedRope(targetVehicle)
    if not ownedRopeId or detachBusy then return end
    detachBusy = true
    local data = ropeStates[ownedRopeId]
    local vehicle = targetVehicle or (data and NetToVeh(data.tractorNetId) or 0)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        if not attachmentAnimation(vehicle, 'Détachement de la corde', Config.DetachDuration) then
            detachBusy = false
            return
        end
    end

    local response = lib.callback.await('remorquage_corde:server:detach', false, ownedRopeId)
    detachBusy = false
    if not response or not response.ok then return notify(errorText(response and response.code), 'error') end
    notify(Config.Text.detached, 'success')
end

local function useRope()
    if placement then return cancelPlacement(true, false) end
    if ownedRopeId then
        notify('Approchez-vous d’un point d’attache et appuyez sur E pour détacher la corde.', 'inform')
        return
    end
    startPlacement()
end

RegisterNetEvent('remorquage_corde:client:useItem', useRope)
exports('UseRope', useRope)

RegisterNetEvent('remorquage_corde:client:ropeCreated', function(data)
    if type(data) ~= 'table' or not data.id then return end
    ropeStates[data.id] = data
    if data.owner == GetPlayerServerId(PlayerId()) then ownedRopeId = data.id end
    CreateThread(function() ensureVisual(data.id) end)
end)

RegisterNetEvent('remorquage_corde:client:ropeRemoved', function(ropeId, reason)
    ropeId = math.floor(tonumber(ropeId) or 0)
    removeVisual(ropeId, false)
    breakPending[ropeId] = nil
    if ownedRopeId == ropeId then
        ownedRopeId = nil
        if reason == 'broken' then notify('La corde a cassé : les véhicules se sont trop éloignés.', 'error')
        elseif reason == 'owner_left' then notify('La corde a été retirée.', 'warning') end
    end
end)

CreateThread(function()
    while true do
        local wait = 1500
        local promptVisible = textVisible == Config.Text.detachPrompt

        if ownedRopeId and not placement and not detachBusy then
            wait = 350
            local data = ropeStates[ownedRopeId]
            local tractor = data and NetToVeh(data.tractorNetId) or 0
            local towed = data and NetToVeh(data.towedNetId) or 0

            if tractor ~= 0 and towed ~= 0 and DoesEntityExist(tractor) and DoesEntityExist(towed) then
                local rear = attachmentPoint(tractor, true)
                local front = attachmentPoint(towed, false)
                local pedCoords = GetEntityCoords(PlayerPedId())
                local rearDistance = #(pedCoords - rear)
                local frontDistance = #(pedCoords - front)
                local point, vehicle

                if rearDistance <= Config.InteractionDistance and rearDistance <= frontDistance then
                    point, vehicle = rear, tractor
                elseif frontDistance <= Config.InteractionDistance then
                    point, vehicle = front, towed
                end

                if point then
                    wait = 0
                    DrawMarker(Config.Marker.type, point.x, point.y, point.z + 0.08, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, Config.Marker.scale.x, Config.Marker.scale.y, Config.Marker.scale.z, Config.Marker.detachColour[1], Config.Marker.detachColour[2], Config.Marker.detachColour[3], Config.Marker.detachColour[4], false, true, 2, false, nil, nil, false)
                    showText(Config.Text.detachPrompt)

                    if IsControlJustReleased(0, Config.Controls.confirm) then
                        hideText()
                        detachOwnedRope(vehicle)
                    end
                elseif promptVisible then
                    hideText()
                end
            elseif promptVisible then
                hideText()
            end
        elseif promptVisible then
            hideText()
        end

        Wait(wait)
    end
end)

CreateThread(function()
    Wait(1200)
    local current = lib.callback.await('remorquage_corde:server:getRopes', false) or {}
    for _, data in ipairs(current) do
        ropeStates[data.id] = data
        if data.owner == GetPlayerServerId(PlayerId()) then ownedRopeId = data.id end
        ensureVisual(data.id)
    end

    while true do
        local active = next(ropeStates) ~= nil
        for ropeId, data in pairs(ropeStates) do
            local tractor = NetToVeh(data.tractorNetId)
            local towed = NetToVeh(data.towedNetId)

            if tractor ~= 0 and towed ~= 0 and DoesEntityExist(tractor) and DoesEntityExist(towed) then
                if not ropeHandles[ropeId] then ensureVisual(ropeId) end

                if data.owner == GetPlayerServerId(PlayerId()) then
                    requestControl(towed, 100)
                    SetVehicleHandbrake(towed, false)
                    SetVehicleBrake(towed, false)
                    local currentDistance = #(GetEntityCoords(tractor) - GetEntityCoords(towed))
                    if currentDistance > Config.BreakDistance and not breakPending[ropeId] then
                        breakPending[ropeId] = true
                        CreateThread(function() lib.callback.await('remorquage_corde:server:break', false, ropeId) end)
                    end
                end
            elseif ropeHandles[ropeId] then
                removeVisual(ropeId, true)
            end
        end
        Wait(active and 750 or 2500)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    hideText()
    deleteCarryVisuals()
    for ropeId in pairs(ropeHandles) do removeVisual(ropeId, true) end
    if RopeAreTexturesLoaded() then RopeUnloadTextures() end
end)
