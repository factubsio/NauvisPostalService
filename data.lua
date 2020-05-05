
--data.lua

util = require "data/tf_util/tf_util"
require("shared")

require "data/entities/depot"
require "data/entities/van"
-- require "data/technologies/transport_speed"
-- require "data/technologies/transport_capacity"
-- require "data/technologies/transport_system"
-- require "data/hotkey"
-- require "data/shortcut"
-- require("data/tiles/road_tile")

local hotkeys =
{
  {
    type = "custom-input",
    name = "toggle-tubs-ups-overlay",
    localised_named = {"toggle-tubs-ups-overlay"},
    key_sequence = "CONTROL + L",
    enabled_while_in_cutscene = true
  },
}

data:extend(hotkeys)