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
        electric_networks = {}
    }
    for _, surface in pairs(game.surfaces) do
        for _, entity in pairs(surface.find_entities()) do
            evaluateEntity(entity, settings, results)
        end
    end
    return results
end

function evaluateEntity(entity, settings, results)
    if settings.search_electric then
        evaluateElectricNetwork(entity, results)
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
