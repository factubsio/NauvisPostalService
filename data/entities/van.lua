local tubs = require("libtubs")

local sprite_base = util.copy(data.raw.car.tank)

local van = {}
van.type = "unit"
van.name = "tubs-ups-delivery-van"
van.localised_name = "tubs-ups-delivery-van"
van.icon = util.path("data/entities/van-icon.png")
van.icon_size = 113
van.icon_mipmaps = 0
van.flags = {"placeable-off-grid", "not-in-kill-statistics"}
van.map_color = {r=.5, b=.5}
van.enemy_map_color = {r=1}
van.max_health = 100
van.radar_range = 1
van.order = "i-d"
van.subgroup = "transport"
van.healing_per_tick = 0.1
van.collision_box = tubs.mkbox(.2)
van.selection_box = tubs.mkbox(.6)
-- van.collision_mask[#van.collision_mask+1] = "not-colliding-with-itself"
van.has_belt_immunity = true
van.not_controllable = true
van.movement_speed = 0.08
van.pollution_to_join_attack = 10000
van.distance_per_frame = 0.0
van.distraction_cooldown = 1
van.vision_distance = 50
van.attack_parameters =
{
    type = "beam",
    range = 1,
    cooldown = 1,
    source_direction_count = 0,
    source_offset = {0,0},
    animation = sprite_base.animation,
    ammo_type =
    {
        category = util.ammo_category("transport-drone"),
        target_type = "entity",
        action =
        {
            type = "direct",
            action_delivery =
            {
            {
                type = "instant",
                target_effects =
                {
                {
                    type = "damage",
                    damage = {amount = 5 , type = util.damage_type("physical")}
                }
                }
            }
            }
        },
    },
}

local function mkstripes(frames_per_dir, direction_count, path)
    local stripes = {}
    for dir = 0, direction_count-1, 1 do
            local dir_str = tostring(math.floor(dir))

            while string.len(dir_str) ~= 4 do
                dir_str = "0" .. dir_str
            end
        stripes[#stripes+1] =
        {
            filename = util.path(path .. "/" .. dir_str .. ".png"),
            width_in_frames = 1,
            height_in_frames = 1,
        }
    end

    return stripes
end

van.run_animation =
{
    priority = "low",
    width = 192,
    height = 192,
    scale = 0.4,
    frame_count = 5,
    direction_count = 36,
    shift = {0,0},
    animation_speed = 8,
    max_advance = 0.2,
    stripes = {
        {
            filename = util.path("data/entities/truck_mk1_cargo-0.png"),
            width_in_frames = 5,
            height_in_frames = 10,
        },
        {
            filename = util.path("data/entities/truck_mk1_cargo-1.png"),
            width_in_frames = 5,
            height_in_frames = 10,
        },
        {
            filename = util.path("data/entities/truck_mk1_cargo-2.png"),
            width_in_frames = 5,
            height_in_frames = 10,
        },
        {
            filename = util.path("data/entities/truck_mk1_cargo-3.png"),
            width_in_frames = 5,
            height_in_frames = 6,
        },
    }

}
van.distance_per_frame = 4

data:extend{van}

