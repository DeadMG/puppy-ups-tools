local gui = require("lib.gui")
local event = require("__flib__.event")
local search = require('script.search')

local windowName = "ups-tools-host"

function createWindow(player_index)
    local player = game.get_player(player_index)
    
    global.dialog_settings = global.dialog_settings or {}
    global.dialog_settings[player_index] = global.dialog_settings[player_index] or {
        search_electric = true,
		filter = "all"
    }
    
    local dialog_settings = global.dialog_settings[player_index]
    
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
                    -- Results
                    {type="flow", direction="vertical", save_as="results"},
                    -- Search button
                    {type="flow", style_mods={horizontal_align="right"}, children={              
                         {type="empty-widget", style_mods={horizontally_stretchable=true}},                    
                         {template="frame_action_button", sprite="utility/search_icon", handlers="ups_tools_handlers.search" }}}}}}}
            }}})
            
    dialog.titlebar.flow.drag_target = dialog.main_window
    dialog.main_window.force_auto_center()    
    dialog_settings.dialog = dialog
    
    player.opened = dialog.main_window
    
    renderResults(player_index)
end

function renderResults(player_index)
    if not global.results then return end
    
    local dialog_settings = global.dialog_settings[player_index] or {}
    if not dialog_settings.dialog then return end    
    
    renderElectricNetworks(dialog_settings.dialog.results, global.results.electric_networks, dialog_settings.filter)
end

function renderElectricNetworks(parent, networks, filter)
    parent.clear()   

    gui.build(parent, {renderNetworks(networks, filter)})
end

function renderNetworks(networks, filter)    
	local selectableSurfaces = getSelectableSurfaces(networks)
	filter = filter or "all"
	
    networks = filterForSurfaces(networks, filter)
    table.sort(networks, function(network1, network2) return #network1.entities < #network2.entities end)
	
    return {type="flow", direction="vertical", children={
	    {type="drop-down", caption="Surface", items=selectableSurfaces, selected_index=indexOf(selectableSurfaces, filter) or 1,handlers="ups_tools_handlers.electric_network_filter_changed"},
	    {type="scroll-pane", horizontal_scroll_policy="never", vertical_scroll_policy="always", style_mods={horizontally_stretchable=true,maximal_height=700}, children={
	        {type="table", column_count=3, children=flatten(mapArray(networks, renderNetwork))}
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
	return table.concat(mapArray(network.surfaces, getSurfaceName), ", ")
end

function getSurfaceName(surface)
    if surface.valid then return surface.name else return nil end
end

function renderNetwork(network)
    local sample_entity = firstValidEntity(network)
    if not sample_entity then return end
    return {
        {type="label", caption="#"..network.id .. " (" .. getSurfaceLabel(network) ..  ")" .. ": " .. tostring(#network.entities) .. " entities" },
        {
            type="sprite-button", 
            sprite="utility/go_to_arrow", 
            tags={entity=sample_entity.name, position=sample_entity.position, surface_index=sample_entity.surface.index}, 
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

function goTo(player, entity, x, y, surface_index)
    if isNavsatAvailable(player) then
	    local zone = remote.call('space-exploration', 'get_zone_from_surface_index', { surface_index=surface_index })
		if zone then		
	        remote.call('space-exploration', 'remote_view_start', { player = player, zone_name = zone.name, position={x=x, y=y}, location_name="", freeze_history=true })
		    return
		end
	end
	player.print("[entity=" .. entity .. "] at [gps=" .. x .. "," .. y .. "," .. game.surfaces[surface_index].name .. "]")
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
					goTo(player, e.element.tags.entity, e.element.tags.position.x, e.element.tags.position.y, e.element.tags.surface_index)
                    closeGui(e.player_index)
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
