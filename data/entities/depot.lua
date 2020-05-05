
local circuit_depot_base = function(shift)
  return
  {
    filename = util.path("data/entities/depot-base.png"),
    width = 200,
    height = 100,
    frame_count = 1,
    scale = 0.45,
    shift = shift
  }
end

local mkbox = function(w, h, pad)
    local hw = w/2 - (pad and .1 or 0)
    local hh = h/2 - (pad and .1 or 0)
    return { {-hw, -hh}, {hw, hh} }
end


local collision_box = {{-.4, -1.25},{1.25, 1.25}}
local selection_box = {{-1.5, -1.5}, {1.5, 1.5}}

local mkproto = function (type, name)

    local proto = {}
    proto.type = type
    proto.name = name
    proto.localised_name = {name}
    proto.minable = { result = name, mining_time = 1 }
    proto.icon_mipmaps = 0

    local nil_energy_source = {
        type = "electric",
        render_no_power_icon = false,
        render_no_network_icon = false,
        buffer_capacity = "0W",
        usage_priority = "tertiary"
    }

    if type == "accumulator" then
        -- accumulator protocal impl
        proto.charge_cooldown = 0
        proto.discharge_cooldown = 0
        proto.discharge_cooldown = 0
        proto.energy_source = nil_energy_source
    end

    return proto

end

local depot = {}
depot.type = "container"
depot.name = "tubs-ups-depot"
depot.localised_name = {"tubs-ups-depot"}
depot.icon_mipmaps = 0
depot.inventory_size = 16
depot.picture = data.raw["container"]["wooden-chest"].picture
depot.picture.zoom = 4
depot.picture.scale = 4
depot.icon = data.raw["container"]["wooden-chest"].icon
depot.icon_size = data.raw["container"]["wooden-chest"].icon_size
depot.minable = { result = "tubs-ups-depot", mining_time = 1 }
depot.collision_box = mkbox(2, 2, true)
depot.selection_box = mkbox(2, 2, false)

local loading_dock = mkproto("container", "tubs-ups-loading-dock")
loading_dock.inventory_size = 12
loading_dock.allow_copy_paste = true
loading_dock.additional_pastable_entities = {"assembling-machine-2"}
loading_dock.picture = {
    filename = util.path("data/entities/loading-dock.png"),
    size = 256,
    scale = 0.4
}
loading_dock.icon = data.raw["container"]["wooden-chest"].icon
loading_dock.icon_size = data.raw["container"]["wooden-chest"].icon_size
loading_dock.collision_box = mkbox(1, 2, true)
loading_dock.selection_box = mkbox(1, 2, false)

local depot_dock = mkproto("accumulator", "tubs-ups-depot-dock")
depot_dock.picture = {
    filename = util.path("data/entities/loading-dock.png"),
    size = 256,
    scale = 0.4
}
depot_dock.icon = data.raw["container"]["wooden-chest"].icon
depot_dock.icon_size = data.raw["container"]["wooden-chest"].icon_size
depot_dock.collision_box = mkbox(1, 2, true)
depot_dock.selection_box = mkbox(1, 2, false)

local loading_dock_link = mkproto("accumulator", "tubs-ups-loading-dock-link")
loading_dock_link.minable = nil
loading_dock_link.picture = {
    filename = util.path("data/entities/loading-dock-link.png"),
    size = 256,
    scale = 0.4
}
-- add blank icon please
loading_dock_link.icon = data.raw["container"]["wooden-chest"].icon
loading_dock_link.icon_size = data.raw["container"]["wooden-chest"].icon_size

local mkitem = function(entity)
    return
    {
        {
            type = "item",
            name = entity.name,
            localised_name = {entity.name},
            icon = entity.icon,
            icon_size = entity.icon_size,
            flags = {},
            subgroup = "transport-drones",
            order = "e-a-c",
            stack_size = 10,
            place_result = entity.name,
        },
        {
            type = "recipe",
            name = entity.name,
            localised_name = {entity.name},
            icon = entity.icon,
            icon_size = entity.icon_size,
            enabled = true,
            ingredients =
            {
                {"iron-plate", 1},
            },
            energy_required = 5,
            result = entity.name

        }

    }
end

local fast_flying_text = util.copy(data.raw["flying-text"]["flying-text"])
fast_flying_text.time_to_live = 15
fast_flying_text.speed = fast_flying_text.speed * 2
fast_flying_text.name = "fast-flying-text"

local delivery_van_mk1 = {}

data:extend{fast_flying_text}
data:extend{depot}
data:extend(mkitem(depot))
data:extend{loading_dock}
data:extend(mkitem(loading_dock))
data:extend{depot_dock}
data:extend(mkitem(depot_dock))
data:extend{loading_dock_link}