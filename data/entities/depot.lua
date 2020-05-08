
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

local blank = {
    filename = util.path("data/entities/blank_64x64.png"),
    size = 64,
}

local dummy = mkproto("accumulator", "tubs-nps-dummy")
dummy.picture = blank
dummy.minable = nil

local depot = {}
depot.type = "container"
depot.name = "tubs-ups-depot"
depot.localised_name = {"tubs-ups-depot"}
depot.icon_mipmaps = 0
depot.inventory_size = 16
depot.picture = {
    filename = util.path("data/entities/depot.png"),
    size = 256,
    scale = 0.4,
}

local dock_animation = {}
dock_animation.type = "animation"
dock_animation.name = "tubs-nps-dock-animation"
dock_animation.stripes = {
    {
        filename = util.path("data/entities/dock_animation.png"),
        width_in_frames = 10,
        height_in_frames = 4,
    },
}
dock_animation.size = 192
dock_animation.run_mode = "forward"
dock_animation.frame_count = 31
dock_animation.animation_speed = 1
dock_animation.repeat_count = 1

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
    filename = util.path("data/entities/delivery_port.png"),
    size = 192,
    scale = 0.4
}
loading_dock.icon = data.raw["container"]["wooden-chest"].icon
loading_dock.icon_size = data.raw["container"]["wooden-chest"].icon_size
loading_dock.collision_box = mkbox(2, 1, true)
loading_dock.selection_box = mkbox(2, 1, false)

local garage = mkproto("accumulator", "tubs-ups-depot-dock")
garage.picture = blank
garage.icon = data.raw["container"]["wooden-chest"].icon
garage.icon_size = data.raw["container"]["wooden-chest"].icon_size
garage.collision_box = mkbox(1, 2, true)
garage.selection_box = mkbox(1, 2, false)


local mksimpleanim = function(name, size, frame_count, line_width, lines)
    local anim = {}
    anim.type = "animation"
    anim.name = "tubs-nps-" .. name
    anim.stripes = {
        {
            filename = util.path("data/entities/" .. name .. ".png"),
            width_in_frames = line_width,
            height_in_frames = lines,
        },
    }
    anim.size = size
    anim.frame_count = frame_count
    anim.animation_speed = 1
    return anim
end

local garage_anim = mksimpleanim("garage-animation", 256, 36, 8, 5)
garage_anim.repeat_count = 1
local garage_lower_anim = mksimpleanim("garage-lower-animation", 256, 36, 8, 5)
local garage_shadow_anim = mksimpleanim("garage-shadow-animation", 256, 36, 8, 5)
garage_shadow_anim.draw_as_shadow = true

local garage_link_left = {
    type = "sprite",
    filename = util.path("data/entities/garage-link-left.png"),
    name = "tubs-nps-garage-link-left",
    size = 256,
    scale = 0.4,
}

local garage_link_right = {
    type = "sprite",
    filename = util.path("data/entities/garage-link-right.png"),
    name = "tubs-nps-garage-link-right",
    size = 256,
    scale = 0.4,
}

local warning_no_depot = {}
warning_no_depot.type = "animation"
warning_no_depot.name = "tubs-nps-warning-no-depot"
warning_no_depot.stripes = {
        {
            filename = "__core__/graphics/icons/alerts/too-far-from-roboport-icon.png",
            width_in_frames = 1,
            height_in_frames = 1,
        },
        {
            filename = util.path("data/entities/blank_64x64.png"),
            width_in_frames = 1,
            height_in_frames = 1,
        },
}
warning_no_depot.size = 64
warning_no_depot.frame_count = 2
warning_no_depot.animation_speed = 0.03

local depot_radar_anim = {}
depot_radar_anim.type = "animation"
depot_radar_anim.name = "tubs-nps-depot-radar"
depot_radar_anim.stripes = {
        {
            filename = util.path("data/entities/depot_radar.png"),
            width_in_frames = 8,
            height_in_frames = 5,
        },
}
depot_radar_anim.size = 256
depot_radar_anim.frame_count = 40
depot_radar_anim.animation_speed = .5
depot_radar_anim.run_mode = "forward-then-backward"


local depot_shadow_anim = {}
depot_shadow_anim.type = "animation"
depot_shadow_anim.name = "tubs-nps-depot-shadow"
depot_shadow_anim.stripes = {
        {
            filename = util.path("data/entities/depot_shadow.png"),
            width_in_frames = 8,
            height_in_frames = 5,
        },
}
depot_shadow_anim.size = 256
depot_shadow_anim.frame_count = 40
depot_shadow_anim.animation_speed = .5
depot_shadow_anim.run_mode = "forward-then-backward"
    

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

data:extend{fast_flying_text}
data:extend{depot}
data:extend(mkitem(depot))
data:extend{loading_dock}
data:extend(mkitem(loading_dock))
data:extend{garage}
data:extend(mkitem(garage))
data:extend{garage_link_left}
data:extend{garage_link_right}
data:extend{warning_no_depot}
data:extend{depot_radar_anim}
data:extend{depot_shadow_anim}
data:extend{dummy}
data:extend{dock_animation}
data:extend{garage_anim}
data:extend{garage_lower_anim}
data:extend{garage_shadow_anim}