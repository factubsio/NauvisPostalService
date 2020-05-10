
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
depot.name = "tubs-nps-depot"
depot.localised_name = {"tubs-nps-depot"}
depot.icon_mipmaps = 0
depot.inventory_size = 16
depot.picture = {
    filename = util.path("data/entities/depot_base.png"),
    size = 256,
    scale = 0.4,
}
depot.icon = util.path("data/entities/depot-icon.png")
depot.icon_size = 256
depot.minable = { result = "tubs-nps-depot", mining_time = 1 }
depot.collision_box = mkbox(2, 2, true)
depot.selection_box = mkbox(2, 2, false)

local loading_dock = mkproto("container", "tubs-nps-loading-dock")
loading_dock.inventory_size = 12
loading_dock.allow_copy_paste = true
loading_dock.additional_pastable_entities = {"assembling-machine-2"}
loading_dock.picture = {
    filename = util.path("data/entities/dock_base.png"),
    size = 192,
    scale = 0.4
}
loading_dock.icon = util.path("data/entities/dock-icon.png")
loading_dock.icon_size = 192
loading_dock.collision_box = mkbox(2, 1, true)
loading_dock.selection_box = mkbox(2, 1, false)

local garage = mkproto("accumulator", "tubs-nps-garage")
garage.picture = blank
garage.icon = util.path("data/entities/garage-icon.png")
garage.icon_size = 256
garage.collision_box = mkbox(1, 2, true)
garage.selection_box = mkbox(1, 2, false)
garage.minable.result = "tubs-nps-garage-proxy"

local garage_proxy = mkproto("simple-entity", "tubs-nps-garage-proxy")
garage_proxy.picture = {
    filename = util.path("data/entities/garage-base-proxy.png"),
    size = 256,
    scale = 0.4
}
for _,k in pairs{"icon", "icon_size", "collision_box", "selection_box"} do
    garage_proxy[k] = garage[k]
    garage_proxy[k] = garage[k]
end


local mksimpleanim = function(name, size, frame_count, line_width, lines, shadow)
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
    anim.draw_as_shadow = shadow or false
    return anim
end

local garage_anim = mksimpleanim("garage-base", 256, 36, 8, 5)
garage_anim.repeat_count = 1
local garage_lower_anim = mksimpleanim("garage-base-lower", 256, 36, 8, 5)
local garage_shadow_anim = mksimpleanim("garage-shadow", 256, 36, 8, 5)
garage_shadow_anim.draw_as_shadow = true


local dock_base = mksimpleanim("dock_base", 192, 38, 10, 4)
local dock_shadow = mksimpleanim("dock_shadow", 192, 38, 10, 4, true)

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
    

local mkitem = function(entity, ingredients, proxy)
    return
    {
        {
            type = "item",
            name = proxy and proxy.name or entity.name,
            localised_name = {entity.name},
            icon = entity.icon,
            icon_size = entity.icon_size,
            flags = {},
            subgroup = "tubs-nps",
            order = "e-a-c",
            stack_size = 10,
            place_result = proxy and proxy.name or entity.name,
        },
        {
            type = "recipe",
            name = entity.name,
            localised_name = {entity.name},
            icon = entity.icon,
            icon_size = entity.icon_size,
            enabled = true,
            ingredients = ingredients or
            {
                {"iron-plate", 1},
            },
            energy_required = 5,
            result = proxy and proxy.name or entity.name

        }

    }
end

local fast_flying_text = util.copy(data.raw["flying-text"]["flying-text"])
fast_flying_text.time_to_live = 15
fast_flying_text.speed = fast_flying_text.speed * 2
fast_flying_text.name = "fast-flying-text"

data:extend{fast_flying_text}
data:extend{depot}
data:extend(mkitem(depot, {
    {"iron-plate",  20},
    {"stone-brick", 20},
    {"iron-gear-wheel", 10},
    {"electronic-circuit", 5},
}))

data:extend{loading_dock}
data:extend(mkitem(loading_dock, {
    {"iron-plate", 10},
    {"iron-gear-wheel", 10},
    {"electronic-circuit", 3},
}))
data:extend{garage, garage_proxy}
data:extend(mkitem(garage_proxy, {
    {"iron-plate", 15},
    {"iron-gear-wheel", 15}
}))
data:extend{garage_link_left}
data:extend{garage_link_right}
data:extend{warning_no_depot}
data:extend{depot_radar_anim, depot_shadow_anim}
data:extend{depot_shadow_anim}
data:extend{dummy}
data:extend{dock_base, dock_shadow}
data:extend{garage_anim}
data:extend{garage_lower_anim}
data:extend{garage_shadow_anim}