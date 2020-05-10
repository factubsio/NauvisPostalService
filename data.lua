
--data.lua

util = require "data/tf_util/tf_util"
require("shared")


data:extend{
  {
    type = "recipe-category",
    name = "tubs-nps",
    order = "z[drone-fuel-refining]"
  }
}

data:extend{
  {
    icon = util.path("data/icons/transport-drone-icon.png"),
    icon_size = 113,
    type = "item-group",
    name = "drones",
    order = "z[drones]",
    localised_name = {"drones-item-group"},
    localised_description = {"drones-item-group-description"},
  }
}


local transport_drones_subgroup = data.raw["item-subgroup"]["transport-drones"]
if transport_drones_subgroup then
  transport_drones_subgroup.group = "drones"
  data:extend{
    {
      type = "item-subgroup",
      group = "drones",
      name = "mining-drones",
      order = "a[mining-drones]",
      localised_name = {"mining-drones-item-subgroup"},
      localised_description = {"mining-drones-item-subgroup-description"},
    }
  }

  data.raw.item["mining-depot"].subgroup = "mining-drones"
  data.raw.item["mining-drone"].subgroup = "mining-drones"

  -- Why is this not working??
  data.raw.item["Construction Drone"].group = "drones"
end

data:extend{
  {
    type = "item-subgroup",
    group = "drones",
    name = "tubs-nps",
    order = "z[tubs-nps]",
    localised_name = {"tubs-nps-item-subgroup"},
    localised_description = {"tubs-nps-item-subgroup-description"},
  }
}


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
    name = "toggle-tubs-nps-overlay",
    localised_named = {"toggle-tubs-nps-overlay"},
    key_sequence = "CONTROL + L",
    enabled_while_in_cutscene = true
  },
  {
    type = "custom-input",
    name = "toggle-nps-garage-direction",
    localised_named = {"toggle-nps-garage-direction"},
    key_sequence = "R",
    enabled_while_in_cutscene = true
  },
}


data:extend(hotkeys)