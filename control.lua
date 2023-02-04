local event = require("__flib__.event")
local mod_gui = require 'mod-gui'
local gui = require('script/gui')

local button_name = 'puppy_ups_tools_button'

function create_flow_button(player)
    if mod_gui.get_button_flow(player)[button_name] then
        return
    end

    mod_gui.get_button_flow(player).add{
        type = "sprite-button",
        name = button_name,
        sprite = "utility/time_editor_icon",
        style = mod_gui.button_style
    }
end

script.on_init(function(event)
    gui.onInit()
    for _, player in pairs(game.players) do
        create_flow_button(player)
    end
end)

event.register(defines.events.on_player_created, function(event)
    create_flow_button(game.players[event.player_index])
end)

event.register(defines.events.on_gui_click, function(event)
    if gui.passthroughGuiEvent(event) then return end
    local target = event.element
    local player = game.players[event.player_index]
    if not (player and player.valid and target and target.valid) then return end

    if target.name ~= button_name then return end
    
    if mod_gui.get_frame_flow(player)[button_name] then
        mod_gui.get_frame_flow(player)[button_name].destroy()
    else
        gui.toggleGui(event.player_index)
    end
end)
