local ESX = exports.es_extended:getSharedObject()

local builders = {}
local pendingVehicles = {}
local ropes = {}
local ropeByOwner = {}
local vehicleRopes = {}
local nextRopeId = 1

local function itemCount(source)
    local ok, count = pcall(function()
        return exports.acn_inventory:GetItemCount(source, Config.ItemName, nil)
    end)

    return ok and math.max(0, tonumber(count) or 0) or 0
end

local function getVehicle(netId)
    netId = math.floor(tonumber(netId) or 0)
    if netId <= 0 then return nil end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return nil end
    return entity, netId
end

local function distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function playerNearVehicle(source, vehicle, maximum)
    local ped = GetPlayerPed(source)
    if ped == 0 or not DoesEntityExist(ped) then return false end
    return distance(GetEntityCoords(ped), GetEntityCoords(vehicle)) <= maximum
end

local function releaseBuilder(source)
    local builder = builders[source]
    if not builder then return end
    if builder.tractorNetId and pendingVehicles[builder.tractorNetId] == source then
        pendingVehicles[builder.tractorNetId] = nil
    end
    builders[source] = nil
end

local function removeRope(ropeId, reason)
    ropeId = math.floor(tonumber(ropeId) or 0)
    local rope = ropes[ropeId]
    if not rope then return false end

    ropes[ropeId] = nil
    ropeByOwner[rope.owner] = nil
    vehicleRopes[rope.tractorNetId] = nil
    vehicleRopes[rope.towedNetId] = nil
    TriggerClientEvent('remorquage_corde:client:ropeRemoved', -1, ropeId, reason or 'detached')
    return true
end

lib.callback.register('remorquage_corde:server:begin', function(source)
    if itemCount(source) < 1 then return { ok = false, code = 'missing_item' } end
    if ropeByOwner[source] then return { ok = false, code = 'already_towing', ropeId = ropeByOwner[source] } end

    releaseBuilder(source)
    builders[source] = { expiresAt = os.time() + Config.BuilderTimeout }
    return { ok = true }
end)

lib.callback.register('remorquage_corde:server:setTractor', function(source, netId)
    local builder = builders[source]
    if not builder or builder.expiresAt < os.time() then
        releaseBuilder(source)
        return { ok = false, code = 'expired' }
    end
    if itemCount(source) < 1 then return { ok = false, code = 'missing_item' } end

    local vehicle, validNetId = getVehicle(netId)
    if not vehicle then return { ok = false, code = 'invalid_vehicle' } end
    if not playerNearVehicle(source, vehicle, Config.ServerValidationDistance) then return { ok = false, code = 'too_far' } end
    if vehicleRopes[validNetId] or (pendingVehicles[validNetId] and pendingVehicles[validNetId] ~= source) then
        return { ok = false, code = 'vehicle_busy' }
    end

    if builder.tractorNetId and pendingVehicles[builder.tractorNetId] == source then
        pendingVehicles[builder.tractorNetId] = nil
    end

    builder.tractorNetId = validNetId
    builder.expiresAt = os.time() + Config.BuilderTimeout
    pendingVehicles[validNetId] = source
    return { ok = true, tractorNetId = validNetId }
end)

lib.callback.register('remorquage_corde:server:complete', function(source, towedNetId)
    local builder = builders[source]
    if not builder or not builder.tractorNetId or builder.expiresAt < os.time() then
        releaseBuilder(source)
        return { ok = false, code = 'expired' }
    end
    if itemCount(source) < 1 then return { ok = false, code = 'missing_item' } end

    local tractor = getVehicle(builder.tractorNetId)
    local towed, validTowedNetId = getVehicle(towedNetId)
    if not tractor or not towed or builder.tractorNetId == validTowedNetId then
        return { ok = false, code = 'invalid_vehicle' }
    end
    if not playerNearVehicle(source, towed, Config.ServerValidationDistance) then return { ok = false, code = 'too_far' } end
    if vehicleRopes[builder.tractorNetId] or vehicleRopes[validTowedNetId] or pendingVehicles[validTowedNetId] then
        return { ok = false, code = 'vehicle_busy' }
    end

    local vehicleDistance = distance(GetEntityCoords(tractor), GetEntityCoords(towed))
    if vehicleDistance > Config.MaxPlacementDistance then return { ok = false, code = 'vehicles_too_far' } end

    local ropeId = nextRopeId
    nextRopeId = nextRopeId + 1
    local ropeLength = math.max(Config.MinRopeLength, math.min(Config.MaxRopeLength, vehicleDistance + Config.RopeSlack))
    local rope = {
        id = ropeId,
        owner = source,
        tractorNetId = builder.tractorNetId,
        towedNetId = validTowedNetId,
        length = ropeLength,
        createdAt = os.time()
    }

    ropes[ropeId] = rope
    ropeByOwner[source] = ropeId
    vehicleRopes[rope.tractorNetId] = ropeId
    vehicleRopes[rope.towedNetId] = ropeId
    releaseBuilder(source)
    TriggerClientEvent('remorquage_corde:client:ropeCreated', -1, rope)
    return { ok = true, rope = rope }
end)

lib.callback.register('remorquage_corde:server:cancel', function(source)
    releaseBuilder(source)
    return true
end)

lib.callback.register('remorquage_corde:server:detach', function(source, ropeId)
    ropeId = math.floor(tonumber(ropeId) or 0)
    local rope = ropes[ropeId]
    if not rope or rope.owner ~= source then return { ok = false, code = 'not_owner' } end
    removeRope(ropeId, 'detached')
    return { ok = true }
end)

lib.callback.register('remorquage_corde:server:break', function(source, ropeId)
    ropeId = math.floor(tonumber(ropeId) or 0)
    local rope = ropes[ropeId]
    if not rope or rope.owner ~= source then return false end
    return removeRope(ropeId, 'broken')
end)

lib.callback.register('remorquage_corde:server:getRopes', function()
    local result = {}
    for _, rope in pairs(ropes) do result[#result + 1] = rope end
    return result
end)

ESX.RegisterUsableItem(Config.ItemName, function(source)
    if itemCount(source) < 1 then return end
    TriggerClientEvent('remorquage_corde:client:useItem', source)
end)

AddEventHandler('playerDropped', function()
    local source = source
    releaseBuilder(source)
    if ropeByOwner[source] then removeRope(ropeByOwner[source], 'owner_left') end
end)

CreateThread(function()
    while true do
        local now = os.time()
        for source, builder in pairs(builders) do
            if builder.expiresAt < now then releaseBuilder(source) end
        end

        for ropeId, rope in pairs(ropes) do
            local tractor = getVehicle(rope.tractorNetId)
            local towed = getVehicle(rope.towedNetId)
            if not tractor or not towed then removeRope(ropeId, 'entity_missing') end
        end

        Wait(next(ropes) and 5000 or 15000)
    end
end)
