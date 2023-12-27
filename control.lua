local event = require("__flib__.event")
local gui = require('script/gui')
local mod_gui = require 'mod-gui'

local button_name = 'puppy_ups_tools_button'

script.on_init(function(event)
    gui.onInit()
end)

script.on_load(function(event)
    gui.onLoad()
end)

script.on_configuration_changed(function()
    gui.onConfigurationChanged()
    for _, player in pairs(game.players) do
         local button = mod_gui.get_button_flow(player)[button_name]
         if button then button.destroy() end
    end
end)

event.register(defines.events.on_lua_shortcut, function(event)
    local player = game.players[event.player_index]
    if not (player and player.valid) then return end
    if event.prototype_name ~= "ups_tools_open_interface" then return end

    gui.toggleGui(event.player_index)
end)
