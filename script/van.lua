local tubs = require("libtubs")
local inv = require("inventory")

Van = {}
Van_mt = { __index = Van }

local script_data = {
    vans_busy = {},
    all_vans = {},
}


local blah = function()
    game.print(serpent.line(script_data))
end


function Van:new(owner, spawn_offset)
    local entity = owner.entity
    local pos = entity.position

    local dummy = entity.surface.create_entity{
        name = "tubs-nps-dummy",
        position = pos,
        force = entity.force,
        player = entity.last_user,

    }
    local van = setmetatable(
        {
            dummy = dummy,
            home = {pos.x, pos.y + 2},
            owner = owner,
            inventory = inv.new(),
            collection = inv.new(),
            state = "idle",
            delivery_queue = {},
            current_target = nil,
            id = dummy.unit_number,
        },
        Van_mt
    )

    script_data.all_vans[dummy.unit_number] = van

    van:regenerate_entity{entity.position.x, entity.position.y + 1}
    inv.set_stack_limit(van.inventory, 3)
    inv.set_stack_limit(van.collection, 3)
    return van
end

function Van:regenerate_entity(pos)

    local entity_name = nil

    if inv.count(self.inventory) == 0 then
        entity_name = "tubs-nps-delivery-van"
    else
        entity_name = "tubs-nps-delivery-van-loaded"
    end

    if self.entity_name ~= entity_name then
        if self.entity then self.entity.destroy() end

        self.entity = self.dummy.surface.create_entity{
            name = entity_name,
            position = pos,
            force = self.dummy.force,
            player = self.player,
        }
        self.entity_name = entity_name
    else
        self.entity.teleport(pos)
    end
    self:stop()
end
function Van:stop()
    self.entity.set_command{type = defines.command.stop}
end

function Van:sleep()
    self:stop()

    if inv.count(self.inventory) > 0 then
        local spill = nil
        local depot = self.owner.depot
        if depot and depot.entity.valid then
            spill = inv.new()
            local insert = depot.entity.get_output_inventory().insert
            for name,amount in inv.contents(self.inventory) do
                local amount_inserted = insert({name = name, count = amount})
                if amount_inserted < amount then
                    local to_spill = amount - amount_inserted
                    inv.emplace(spill, name, to_spill)
                end
            end
        else
            spill = self.inventory
        end

        local do_spill = self.entity.surface.spill_item_stack

        for name,amount in inv.contents(spill) do
            do_spill(self.entity.position, {name=name, count=amount})
        end

        inv.clear(self.inventory)
    end

    inv.clear(self.collection)

    self:regenerate_entity(self.entity.position)
    self.state = "idle"
    script_data.vans_busy[self.id] = nil
end

function Van:die()

    script_data.all_vans[self.dummy.unit_number] = nil

    self.dummy.destroy()
    self.entity.destroy()
end

function Van:continue()

    self.current_target,dest = next(self.delivery_queue, self.current_target)

    loc = {0,0}

    local radius = .75

    if dest == nil then
        loc = self.home
        radius = .3
        self.state = "go-home"
    else
        loc = {dest.target.entity.position.x, dest.target.entity.position.y + .7}
        self.state = "working"
        radius = .3
    end

    script_data.vans_busy[self.entity.unit_number] = self

    self.entity.set_command{
        type = defines.command.go_to_location,
        destination = loc,
        radius = radius,
        pathfind_flags = { prefer_straight_paths = true, cache = true, no_break = true }
    }

end

function Van:service_dock()
    local manifest = self.delivery_queue[self.current_target]

    local pos = self.entity.position
    local dock_pos = manifest.target.entity.position

    script_data.vans_busy[self.entity.unit_number] = nil


    if self.mode == 1 then
        local removed = manifest.target:accept_delivery(self, manifest.drop_off)
        inv.remove_inventory(self.inventory, removed)
    else
        local collection = manifest.target:collect(self, manifest.collect)
        inv.add_inventory(self.inventory, collection)
    end

    self:regenerate_entity{dock_pos.x, dock_pos.y + .5}
end

function Van:become_ready(mode, move)
    if self.state ~= "ready" then
        if move then
            local pos = self.owner.entity.position
            self:regenerate_entity{pos.x, pos.y + .6}
        end
        self.state = "ready"
    end
    self.mode = mode
end

function Van:assign_collection(stuff, target)
    local slot = self.delivery_queue[target:id()]
    if not slot then
        slot = {collect = inv.new(), target = target}
        self.delivery_queue[target:id()] = slot
    end
    inv.emplace(slot.collect, stuff[1], stuff[2])
    self:become_ready(-1, false)
end

function Van:assign(stuff, target)

    local slot = self.delivery_queue[target:id()]
    if slot then
        inv.add_inventory(slot.drop_off, stuff)
    else
        self.delivery_queue[target:id()] = {drop_off = stuff, target = target}
    end

    inv.add_inventory(target.deliveries, stuff)
    inv.add_inventory(self.inventory, stuff)

    self:become_ready(1, true)
end

local on_ai_command_completed = function(event)
    local van = script_data.vans_busy[event.unit_number]
    if not van then return end
    if not van.entity.valid then return end

    if event.result ~= defines.behavior_result.success then
        -- HELP
        game.message("van failed path finding and is now lost and alone")
        return
    end

    if van.state == "working" then
        van:service_dock()
        -- TODO: REFERESH THIS
        -- refresh_dock_gui_all()
    elseif van.state == "go-home" then
        van.delivery_queue = {}
        van:sleep()

        if not van.owner.entity.valid then
            van:die()
        end
    end
end

Van.events = {
    [defines.events.on_ai_command_completed] = on_ai_command_completed,
}

Van.on_init = function()
    global.script_data = global.script_data or script_data
end
Van.on_load = function()
    script_data = global.script_data or script_data
    for _,van in pairs(script_data.all_vans) do
        setmetatable(van, Van_mt)
    end
end

Van.on_configuration_changed = function()
end
    

return Van