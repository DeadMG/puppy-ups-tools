local gui = require("lib.gui")
local event = require("__flib__.event")
local search = require('script.search')

local windowName = "ups-tools-host"
local renderingName = "puppy-ups-tools"

local LINE_COLOR = { r = 0.35, g = 0.35, b = 1, a = 1 }
local LINE_WIDTH = 4
local HALF_WIDTH = (LINE_WIDTH / 2) / 32  -- 32 pixels per tile

function createWindow(player_index)
    local player = game.get_player(player_index)
    
    local dialog_settings = ensureDialogSettings(player_index)
    
    dialog_settings.close_on_goto = dialog_settings.close_on_goto or false
    dialog_settings.highlight_all_scan_results = dialog_settings.highlight_all_scan_results or false
    dialog_settings.search_electric = (dialog_settings.search_electric == nil and true) or dialog_settings.search_electric
    dialog_settings.filter = dialog_settings.filter or "all"
    
    local rootgui = player.gui.screen
    local dialog = gui.build(rootgui, {
        {type="frame", direction="vertical", save_as="main_window", name=windowName, children={
            -- Title Bar
            {type="flow", save_as="titlebar.flow", children={
                {type="label", style="frame_title", caption={"ups-tools.window-title"}, elem_mods={ignored_by_interaction=true}},
                {template="drag_handle"},
                {template="close_button", handlers="ups_tools_handlers.close_button"}}},                
            {type="frame", style="inside_shallow_frame_with_padding", style_mods={padding=8}, children={
                {type="flow", direction="vertical", style_mods={horizontal_align="left"}, children={
                    -- Search options
                    {type="label", caption={"ups-tools.search-title"}},
                    {type="checkbox", caption={"ups-tools.search-electric"}, save_as="search_electric", state=dialog_settings.search_electric, handlers="ups_tools_handlers.search_electric"},
                    {type="checkbox", caption={"ups-tools.close_on_goto"}, save_as="close_on_goto", state=dialog_settings.close_on_goto, handlers="ups_tools_handlers.close_on_goto"},
                    {type="checkbox", caption={"ups-tools.highlight_all_scan_results"}, save_as="highlight_all_scan_results", state=dialog_settings.highlight_all_scan_results, handlers="ups_tools_handlers.highlight_all_scan_results"},
                    -- Results
                    {type="flow", direction="vertical", save_as="results"},
                    -- Search button
                    {type="flow", style_mods={horizontal_align="right"}, children={              
                         {type="empty-widget", style_mods={horizontally_stretchable=true}},                    
                         {template="frame_action_button", sprite="utility/search_icon", handlers="ups_tools_handlers.search" }}}}}}}
            }}})
            
    dialog.titlebar.flow.drag_target = dialog.main_window
    dialog_settings.dialog = dialog
    
    if dialog_settings.location then
        dialog.main_window.location = dialog_settings.location
    else
        dialog.main_window.force_auto_center()    
    end
    
    player.opened = dialog.main_window
    
    renderResults(player_index)
end

function renderResults(player_index)
    if not global.results then return end
    
    local dialog_settings = ensureDialogSettings(player_index)
    if not dialog_settings.dialog then return end    
    
    renderElectricNetworks(dialog_settings.dialog.results, global.results.electric_networks, dialog_settings.filter, dialog_settings.last_network)
end

function renderElectricNetworks(parent, networks, filter, lastNetworkId)
    parent.clear()   

    gui.build(parent, {renderNetworks(networks, filter, lastNetworkId)})
end

function renderNetworks(networks, filter, lastNetworkId)    
	local selectableSurfaces = getSelectableSurfaces(networks)
	filter = filter or "all"
	
    networks = filterForSurfaces(networks, filter)
    table.sort(networks, function(network1, network2) return #network1.entities < #network2.entities end)
	
    return {type="flow", direction="vertical", children={
	    {type="drop-down", caption="Surface", items=selectableSurfaces, selected_index=indexOf(selectableSurfaces, filter) or 1,handlers="ups_tools_handlers.electric_network_filter_changed"},
	    {type="scroll-pane", horizontal_scroll_policy="never", vertical_scroll_policy="always", style_mods={horizontally_stretchable=true,maximal_height=700}, children={
	        {type="table", column_count=3, children=flatten(mapArray(networks, function(network)
                return renderNetwork(network, network.id == lastNetworkId)
            end))}
	    }}
	}}
end

function getSelectableSurfaces(networks)
    local surfaces = flatten(mapArray(toArray(networks), function(network) return network.surfaces end))
	local names = distinctArray(mapArray(surfaces, getSurfaceName))
	table.insert(names, 1, "all")
	return names
end

function filterForSurfaces(networks, filter)
    networks = toArray(networks)
	if filter == "all" then return networks end
	return mapArray(networks, function(network)
        if any(network.surfaces, function(surface) return getSurfaceName(surface) == filter end) then
		    return network
		end
		return nil
	end)
end

function getSurfaceLabel(network)
	local surfaces = table.concat(mapArray(network.surfaces, getSurfaceName), ", ")
    if #surfaces < 40 then return surfaces end
    return string.sub(surfaces, 1, 37) .. "..."
end

function getSurfaceName(surface)
    if surface.valid then return surface.name else return nil end
end

function renderNetwork(network, isLast)
    local sample_entity = firstValidEntity(network)
    if not sample_entity then return end
    local style = (isLast and { font_color=LINE_COLOR }) or {}
    return {
        {type="label", caption="#"..network.id .. " (" .. getSurfaceLabel(network) ..  ")" .. ": " .. tostring(#network.entities) .. " entities", style_mods=style },
        {
            type="sprite-button", 
            sprite="utility/go_to_arrow", 
            tags={network_id=network.id}, 
            style_mods={height=20,width=20}, 
            handlers="ups_tools_handlers.go_to_network"
        },
        {
            type="sprite-button", 
            sprite="utility/trash", 
            tags={id=network.id}, 
            style_mods={height=20,width=20}, 
            handlers="ups_tools_handlers.delete_network"
        }
    }
end

function firstValidEntity(network)
    for _, entity in pairs(network.entities) do
        if entity.valid and entity.electric_network_id == network.id then return entity end
    end
end

function allValidEntities(network)
    local results = {}
    for _, entity in pairs(network.entities) do
        if entity.valid and entity.electric_network_id == network.id then table.insert(results, entity) end
    end
    return results
end

function closeGui(player_index)
    local player = game.get_player(player_index)
    local rootgui = player.gui.screen
    if rootgui[windowName] then
        rootgui[windowName].destroy()
    end
end

function indexOf(array, value)
    for i, v in ipairs(array) do
        if v == value then
            return i
        end
    end
    return nil
end

function any(original, filter)
    for k, v in pairs(original) do
	    if filter(v) then return true end
	end
	return false
end

function flatten(original)
    local result = {}
    for _, v in ipairs(original) do
        for _, vv in ipairs(v) do
            table.insert(result,vv)
        end
    end
    return result
end

function mapArray(original, map)
    local result = {}
    for _, v in ipairs(original) do
        local value = map(v)
        if value ~= nil then
            table.insert(result, value)
        end
    end
    return result
end

function distinctArray(original)
    local result = {}
	local cache = {}	
    for _, v in ipairs(original) do
	    if not cache[v] then 
     	    table.insert(result, v)
		    cache[v] = true
		end
    end
    return result
end

function mapTable(original, map)
    local result = {}
    for k, v in pairs(original) do
        result[k] = map(v)
    end
    return result
end

function toArray(original)
    local result = {}
    for _, v in pairs(original) do
     	table.insert(result, v)
    end
    return result
end

function isNavsatAvailable(player)
    if not remote.interfaces['space-exploration'] then return false end
	if not remote.interfaces['space-exploration'].remote_view_is_unlocked then return false end
	return remote.call('space-exploration', 'remote_view_is_unlocked', {player=player})
end

function goTo(player, entity, selection_boxes)
    local x = entity.position.x or entity.position[1]
    local y = entity.position.y or entity.position[2]

    if isNavsatAvailable(player) then
	    local zone = remote.call('space-exploration', 'get_zone_from_surface_index', { surface_index=entity.surface.index })
		if zone then		
	        remote.call('space-exploration', 'remote_view_start', { player = player, zone_name = zone.name, position={x=x, y=y}, location_name="", freeze_history=true })
            highlight(player, entity.surface, selection_boxes)
		    return
		end
	end
	player.print("[entity=" .. entity.name .. "] at [gps=" .. x .. "," .. y .. "," .. entity.surface.name .. "]")
end

function clear_markers(player)
  -- Clear all old markers belonging to player
  if #game.players == 1 then
    rendering.clear(renderingName)
  else
    local ids = rendering.get_all_ids(renderingName)
    for _, id in pairs(ids) do
      if rendering.get_players(id)[1].index == player.index then
        rendering.destroy(id)
      end
    end
  end
end

function draw_markers(player, surface, selection_boxes)  
  local time_to_live = 5 * 60
  -- Draw new markers
  for _, raw_box in pairs(selection_boxes) do
    local selection_box = {
        orientation = raw_box.orientation,
        left_top = {
            x = raw_box.left_top.x or raw_box.left_top[1],
            y = raw_box.left_top.y or raw_box.left_top[2]
        },
        right_bottom = {
            x = raw_box.right_bottom.x or raw_box.right_bottom[1],
            y = raw_box.right_bottom.y or raw_box.right_bottom[2]
        }
    }
    
    if selection_box.orientation then
      local angle = selection_box.orientation * 360

      -- Four corners
      local left_top = selection_box.left_top
      local right_bottom = selection_box.right_bottom
      local right_top = {x = right_bottom.x, y = left_top.y}
      local left_bottom = {x = left_top.x, y = right_bottom.y}

      -- Extend the end of each line by HALF_WIDTH so that corners are still right angles despite `width`
      local lines = {
        {from = {x = left_top.x - HALF_WIDTH, y = left_top.y}, to = {x = right_top.x + HALF_WIDTH, y = right_top.y}},  -- Top
        {from = {x = left_bottom.x - HALF_WIDTH, y = left_bottom.y}, to = {x = right_bottom.x + HALF_WIDTH, y = right_bottom.y}},  -- Bottom
        {from = {x = left_top.x, y = left_top.y - HALF_WIDTH}, to = {x = left_bottom.x, y = left_bottom.y + HALF_WIDTH}},  -- Left
        {from = {x = right_top.x, y = right_top.y - HALF_WIDTH}, to = {x = right_bottom.x, y = right_bottom.y + HALF_WIDTH}},  -- Right
      }

      local center = {x = (left_top.x + right_bottom.x) / 2, y = (left_top.y + right_bottom.y) / 2}
      for _, line in pairs(lines) do
        -- Translate each point to origin, rotate, then translate back
        local rotated_from = add_vector(rotate_vector(subtract_vector(line.from, center), angle), center)
        local rotated_to = add_vector(rotate_vector(subtract_vector(line.to, center), angle), center)

        rendering.draw_line{
          color = LINE_COLOR,
          width = LINE_WIDTH,
          from = rotated_from,
          to = rotated_to,
          surface = surface,
          time_to_live = time_to_live,
          players = {player},
        }
      end
    else
      rendering.draw_rectangle{
        color = LINE_COLOR,
        width = LINE_WIDTH,
        filled = false,
        left_top = selection_box.left_top,
        right_bottom = selection_box.right_bottom,
        surface = surface,
        time_to_live = time_to_live,
        players = {player},
      }
    end
  end
end

function highlight(player, surface, selection_boxes)
  clear_markers(player)
  draw_markers(player, surface, selection_boxes)
end

function ensureDialogSettings(player_index)
    global.dialog_settings = global.dialog_settings or {}
    global.dialog_settings[player_index] = global.dialog_settings[player_index] or {}
    
    return global.dialog_settings[player_index]    
end

function registerHandlers()
    gui.add_handlers({
        ups_tools_handlers = {
		    electric_network_filter_changed = {
			    on_gui_selection_state_changed  = function(e)
                    global.dialog_settings[e.player_index].filter = e.element.items[e.element.selected_index]		
                    renderResults(e.player_index)		    
			    end
		    },
            go_to_network = {
                on_gui_click = function(e)
                    local player = game.get_player(e.player_index)
                    local network = global.results.electric_networks[e.element.tags.network_id]
                    local entity = network and firstValidEntity(network)
                    local dialog_settings = ensureDialogSettings(e.player_index)
                    
                    if network and entity then
                        local entities = (dialog_settings.highlight_all_scan_results and allValidEntities(network)) or {entity}
                        local selection_boxes = mapArray(entities, function(entity) return entity.selection_box end)
                        goTo(player, entity, selection_boxes)
                        dialog_settings.last_network = e.element.tags.network_id
                        if (dialog_settings.close_on_goto) then closeGui(e.player_index)
                        else renderResults(e.player_index) end
                    else
                        renderResults(e.player_index)
                    end
                end
            },
            delete_network = {
                on_gui_click = function(e)
                    local player = game.get_player(e.player_index)
                    if not global.results then return end
                    if not global.results.electric_networks then return end
                    if not global.results.electric_networks[e.element.tags.id] then return end
                    
                    for _, entity in pairs(global.results.electric_networks[e.element.tags.id].entities) do
                        if entity.valid then
                            entity.order_deconstruction(player.force, player)
                        end
                    end
                end
            },
            close_button = {
                on_gui_click = function(e)
                    closeGui(e.player_index)
                end
            },
            search = {
                on_gui_click = function(e)
                    global.results = search.search({
                        search_electric = global.dialog_settings[e.player_index].search_electric
                    })
					
					if global.dialog_settings then
					    for _, settings in pairs(global.dialog_settings) do
						    settings.filter = "all"
						end
					end
                    
                    renderResults(e.player_index)
                end
            },
            search_electric = {
                on_gui_checked_state_changed = function(e)
                    global.dialog_settings[e.player_index].search_electric = e.element.state
                end
            },
            close_on_goto = {
                on_gui_checked_state_changed = function(e)
                    global.dialog_settings[e.player_index].close_on_goto = e.element.state
                end
            },
            highlight_all_scan_results = {
                on_gui_checked_state_changed = function(e)
                    global.dialog_settings[e.player_index].highlight_all_scan_results = e.element.state
                end
            }
        },
    })
    gui.register_handlers()
end

function registerTemplates() 
  gui.add_templates{
    frame_action_button = {type="sprite-button", style="frame_action_button", mouse_button_filter={"left"}},
    drag_handle = {type="empty-widget", style="flib_titlebar_drag_handle", elem_mods={ignored_by_interaction=true}},
    close_button = {template="frame_action_button", sprite="utility/close_white", hovered_sprite="utility/close_black"},
  }
end

registerHandlers()
registerTemplates()

event.on_load(function()
  gui.build_lookup_tables()
end)

function onInit()
  global.dialog_settings = {}
  gui.init()
  gui.build_lookup_tables()
end

function passthroughGuiEvent(event)
    return gui.dispatch_handlers(event)
end

event.register(defines.events.on_gui_location_changed, function(e)
    if not e.element or e.element.name ~= windowName then return end
    
    global.dialog_settings = global.dialog_settings or {}
    global.dialog_settings[e.player_index] = global.dialog_settings[e.player_index] or {}
    global.dialog_settings[e.player_index].location = e.element.location
end)

script.on_configuration_changed(function()
    for _, player in pairs(game.players) do
        closeGui(player.index)
    end
    for _, settings in pairs(global.dialog_settings or {}) do      
        settings.location = nil
    end
end)

function toggleGui(player_index)
    local player = game.get_player(player_index)
    local rootgui = player.gui.screen
    if rootgui[windowName] then 
        closeGui(player_index) 
    else    
        createWindow(player_index)
    end
end

return { toggleGui = toggleGui, onInit = onInit, passthroughGuiEvent = passthroughGuiEvent }
