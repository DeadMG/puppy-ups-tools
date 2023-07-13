function tableContains(t, element)
  for _, value in pairs(t) do
    if value == element then
      return true
    end
  end
  return false
end

function search(settings)
    local results = {
        electric_networks = {},
        unpowered_stuff = {}
    }
    if settings.search_electric or settings.search_unpowered then --why search when you don't want to find anything
        for _, surface in pairs(game.surfaces) do
            for _, entity in pairs(surface.find_entities()) do
                evaluateEntity(entity, settings, results)
            end
        end
    end
    return results
end

function evaluateEntity(entity, settings, results)
    if entity.electric_buffer_size then -- don't check any if the entity isn't electrical
        if settings.search_electric then
            evaluateElectricNetwork(entity, results)
        end
        if settings.search_unpowered then
            evaluateUnpoweredStuff(entity, results)
        end
    end
    --other stuff can be teste
end

function evaluateUnpoweredStuff(entity, results)
    local id = entity.surface.index
    if not id then return end --does this ever happen?
    
    if (entity.electric_buffer_size) and (not entity.is_connected_to_electric_network()) then
        results.unpowered_stuff[id] = results.unpowered_stuff[id] or { surfaces = {}, entities = {} , id = id }    
        table.insert(results.unpowered_stuff[id].entities, entity)
        if not tableContains(results.unpowered_stuff[id].surfaces, entity.surface) then
            table.insert(results.unpowered_stuff[id].surfaces, entity.surface)
        end
    end
end

function evaluateElectricNetwork(entity, results)
    local id = entity.electric_network_id
    if not id then return end
    results.electric_networks[id] = results.electric_networks[id] or { surfaces = {}, entities = {}, id = id }
    table.insert(results.electric_networks[id].entities, entity)
    if not tableContains(results.electric_networks[id].surfaces, entity.surface) then
        table.insert(results.electric_networks[id].surfaces, entity.surface)
    end
end

return { search = search }
