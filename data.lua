---@diagnostic disable

data:extend({
    {
        type = "shortcut",
        name = "ups_tools_open_interface",
        action = "lua",
        toggleable = false,
        order = "st-a[open]",
        icon = data.raw["utility-sprites"].default.clock
    }
})
