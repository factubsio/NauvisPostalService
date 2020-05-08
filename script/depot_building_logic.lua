
local tubs = require("libtubs")

print(serpent.block(script.active_mods))
local profiler = nil
if script.active_mods["profiler"] then
    profiler = require('__profiler__/profiler.lua')
end


local service_radius = 16

local script_data =
{
  update_rate = 60,
  loading_docks = {},
  depot_docks = {},
  depots = {},
  kill_gui = nil,
  dock_gui = {},
  vans_busy = {},
  scheduled = {},
}
local overlay =
{
    visible = false,
}

local nil_logistic_network = {

}

local float_text = function(entity, text)
    entity.surface.create_entity{name = "fast-flying-text", position = entity.position, text = text}
end

local get_dock = function(entity)
    return script_data.loading_docks[entity.unit_number]
end

local get_depot_dock = function(entity)
    return script_data.depot_docks[entity.unit_number]
end

local get_depot = function(entity)
    return script_data.depots[entity.unit_number]
end

local bay_position = function(data, offset)
    return {data.entity.position.x, data.entity.position.y + (offset or 1)}
end

local get_depot_neighbours = function(entity)
    local position = {x = entity.position.x, y = entity.position.y}
    local left_offset = 1
    if entity.name == "tubs-ups-depot" then left_offset = 2 end
    local box = {
        {math.floor(position.x) - left_offset, math.floor(position.y)},
        {math.floor(position.x) + 2, math.floor(position.y)},
    }

    local neighbours = entity.surface.find_entities_filtered{area = box, name = {"tubs-ups-depot-dock", "tubs-ups-depot"}}

    local left_depot = nil
    local right_depot = nil
    local left_dock = nil
    local right_dock = nil

    for _, n in pairs (neighbours) do
        if n.position.x < entity.position.x then
            left_dock = get_depot_dock(n)
            left_depot = get_depot(n) or (left_dock and left_dock.depot)
        elseif n.position.x > entity.position.x then
            right_dock = get_depot_dock(n)
            right_depot = get_depot(n) or (right_dock and right_dock.depot)
        end
    end

    return {left_depot = left_depot, right_depot = right_depot, left_dock = left_dock, right_dock = right_dock}
end


Van = {}
Van_mt = { __index = Van }

function Van:regenerate_entity(pos)

    local entity_name = nil

    if self.inventory:count() == 0 then
        entity_name = "tubs-ups-delivery-van"
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

function Van:new(entity, owner, spawn_offset)
    local dummy = entity.surface.create_entity{
        name = "tubs-nps-dummy",
        position = entity.position,
        force = entity.force,
        player = entity.last_user,

    }
    local van = setmetatable(
        {
            dummy = dummy,
            home = bay_position(owner, 2),
            owner = owner,
            inventory = tubs.Inventory:new(),
            state = "idle",
            delivery_queue = {},
            current_target = nil,
            id = dummy.unit_number,
        },
        Van_mt
    )

    van:regenerate_entity{entity.position.x, entity.position.y + 1}
    van.inventory:set_stack_limit(3)
    return van
end

function Van:stop()
    self.entity.set_command{type = defines.command.stop}
end

function Van:sleep()
    self:stop()

    if self.inventory:count() > 0 then
        local spill = nil
        local depot = self.owner.depot
        if depot and depot.entity.valid then
            spill = tubs.Inventory:new()
            local insert = depot.entity.get_output_inventory().insert
            for name,amount in pairs(self.inventory) do
                local amount_inserted = insert({name = name, count = amount})
                if amount_inserted < amount then
                    local to_spill = amount - amount_inserted
                    spill:emplace(name, to_spill)
                end
            end
        else
            spill = self.inventory
        end

        local do_spill = self.entity.surface.spill_item_stack

        for name,amount in pairs(spill) do
            do_spill(self.entity.position, {name=name, count=amount})
        end

        self.inventory:clear()
    end

    self:regenerate_entity(self.entity.position)
    self.state = "idle"
    script_data.vans_busy[self.id] = nil
end

function Van:die()
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
        loc = bay_position(dest.target)
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
    -- script_data.vans_docking[self.dummy.unit_number] = self

    local removed = manifest.target:accept_delivery(self, manifest.drop_off)
    self.inventory:remove_inventory(removed)

    self:regenerate_entity{dock_pos.x, dock_pos.y + .5}
end

function Van:assign(stuff, target)

    local slot = self.delivery_queue[target:id()]
    if slot then
        slot.drop_off:add_inventory(stuff)
    else
        self.delivery_queue[target:id()] = {drop_off = stuff, target = target}
    end

    target.deliveries:add_inventory(stuff)
    self.inventory:add_inventory(stuff)

    if self.state ~= "ready" then
        local pos = self.owner.entity.position
        self:regenerate_entity{pos.x, pos.y + .6}
        self.state = "ready"
    end

end

Depot = {}
Depot_mt = { __index = Depot }

function Depot:new(entity)
    local depot = setmetatable(
        {
            entity = entity,
            customers = {},
            docks = {},
            range_indicator = nil,
            delivery = {},
            vans_busy = {}
        },
        Depot_mt)

    local customer_entities = entity.surface.find_entities_filtered{position = entity.position, radius = service_radius, name = {"tubs-ups-loading-dock"}}
    for _,customer_entity in pairs(customer_entities) do
        depot:add_customer(get_dock(customer_entity))
    end

    depot.range_indicator = rendering.draw_circle{
        color = {r=0, g=0.25, b=0, a=0},
        radius = service_radius,
        filled = true,
        target = entity,
        target_offset = {0, 0},
        draw_on_ground = false,
        surface = entity.surface,
        visible = overlay.visible,
    }

    depot.radar_anim = rendering.draw_animation{
        animation = "tubs-nps-depot-radar",
        x_scale = .4,
        y_scale = .4,
        target = entity,
        surface = entity.surface,
    }

    depot.shadow_anim = rendering.draw_animation{
        animation = "tubs-nps-depot-shadow",
        x_scale = .4,
        y_scale = .4,
        target = entity,
        surface = entity.surface,
        render_layer = 92,
    }

    script_data.depots[entity.unit_number] = depot




    local neighbours = get_depot_neighbours(entity)

    if neighbours.left_dock then
        neighbours.left_dock:validate({left = true})
    end
    if neighbours.right_dock then
        neighbours.right_dock:validate({right = true})
    end


    return depot
end

function Depot:remove_customer(customer)
    self.customers[customer.entity.unit_number] = nil
end

function Depot:add_customer(customer)
    float_text(customer.entity, "Connected!")
    local customer_data = {dock = customer, line = nil}

    customer_data.line = rendering.draw_line{
        color = {r=0, g=0, b=1, a=0.25},
        width = 2,
        from = self.entity,
        from_offset = {0,0},
        to = customer.entity,
        to_offset = {0,1},
        surface = self.entity.surface,
        visible = true,
        only_in_alt_mode = true,
    }

    self.customers[customer.entity.unit_number] = customer_data

end

function Depot:die()
    script_data.depots[self.entity.unit_number] = nil

    local neighbours = get_depot_neighbours(self.entity)


    if neighbours.left_dock then
        neighbours.left_dock:disconnect("right")
    end
    if neighbours.right_dock then
        neighbours.right_dock:disconnect("left")
    end

    rendering.destroy(self.range_indicator)
end

LoadingDock = {}
LoadingDock_mt = { __index = LoadingDock }

function LoadingDock:animate(speed)
    if not self.anim then
        self.anim = rendering.draw_animation{
            animation = "tubs-nps-dock-animation",
            surface = self.entity.surface,
            target = self.entity,
            x_scale = .4,
            y_scale = .4,
        }
    end
    tubs.set_frame(game.tick, 0, {frames=31, speed=speed}, self.anim)
    game.print("starting (dock) anim at: " .. rendering.get_animation_offset(self.anim))
end

function LoadingDock:new(entity)
    local dock = setmetatable(
        {
            entity = entity,
            deliveries = tubs.Inventory:new(),
            last_req = nil,
            req = nil,
        },
        LoadingDock_mt)

    dock.deliveries:set_stack_limit(16)
    dock:animate(0)

    local providers = entity.surface.find_entities_filtered{position = entity.position, radius = service_radius, name = {"tubs-ups-depot"}}
    for _,depot_entity in pairs(providers) do
        get_depot(depot_entity):add_customer(dock)
    end

    script_data.loading_docks[entity.unit_number] = dock

    return dock
end

function LoadingDock:id()
    return self.entity.unit_number
end

function LoadingDock:on_the_way(name)
    return self.deliveries[name] or 0
end

function LoadingDock:in_storage(name)
    return self.entity.get_output_inventory().get_item_count(name)
end

function LoadingDock:x()
    return self.entity.position.x
end
function LoadingDock:y()
    return self.entity.position.y
end

local schedule = function(when, tbl, what)
    local arr = tbl[when]
    if arr then
        table.insert(arr, what)
    else
        tbl[when] = {what}
    end

end

function LoadingDock:accept_delivery(van, delivery)
    self:animate(.5)
    schedule(game.tick + 60, script_data.scheduled, function()
        self:animate(0)
        van:continue()
    end)

    self.deliveries:remove_inventory(delivery)
    local inserted = tubs.Inventory:new()
    local insert = self.entity.get_output_inventory().insert
    for name,amount in pairs(delivery) do
        local amount_inserted = insert({name = name, count = amount})
        if amount_inserted > 0 then
            inserted:emplace(name, amount_inserted)
        end
    end
    return inserted
end

function LoadingDock:die()
    script_data.loading_docks[self.entity.unit_number] = nil

    local providers = self.entity.surface.find_entities_filtered{position = self.entity.position, radius = service_radius, name = {"tubs-ups-depot"}}
    for _,depot_entity in pairs(providers) do
        get_depot(depot_entity):remove_customer(self)
    end
end

local DepotDock = {}
local DepotDock_mt = {__index = DepotDock}

function DepotDock:animate(speed)
    if not self.anim then
        self.anim = rendering.draw_animation{
            animation = "tubs-nps-garage-animation",
            surface = self.entity.surface,
            target = self.entity,
            x_scale = .4,
            y_scale = .4,
        }
    end

    if not self.lower_anim then
        self.lower_anim = rendering.draw_animation{
            animation = "tubs-nps-garage-lower-animation",
            surface = self.entity.surface,
            target = self.entity,
            x_scale = .4,
            y_scale = .4,
            render_layer = "floor",
        }
    end

    if not self.shadow_anim then
        self.shadow_anim = rendering.draw_animation{
            animation = "tubs-nps-garage-shadow-animation",
            surface = self.entity.surface,
            target = self.entity,
            x_scale = .4,
            y_scale = .4,
        }
    end

    tubs.set_frame(game.tick, 0, {frames=36, speed=speed}, self.anim)
    tubs.set_frame(game.tick, 0, {frames=36, speed=speed}, self.lower_anim)
    tubs.set_frame(game.tick, 0, {frames=36, speed=speed}, self.shadow_anim)
end

function DepotDock:new(entity)
    local dock = setmetatable(
        {
            entity = entity,
            depot = nil,
            links = {},
            docks = {},
            id = entity.unit_number,
            warning_no_depot = nil,
        },
        DepotDock_mt)

    script_data.depot_docks[entity.unit_number] = dock
    dock:animate(0)

    dock.warning_no_depot = rendering.draw_animation{
        animation = "tubs-nps-warning-no-depot",
        surface = entity.surface,
        target = entity,
        x_scale = .4,
        y_scale = .4,
    }

    dock.hint_right = rendering.draw_sprite{
        sprite = "utility/indication_arrow",
        surface = entity.surface,
        x_scale = .7,
        y_scale = .7,
        target = entity,
        target_offset = {.5, 0},
        orientation = .25,
        visible = false,
        only_in_alt_mode = true,
    }
    dock.hint_left = rendering.draw_sprite{
        sprite = "utility/indication_arrow",
        surface = entity.surface,
        x_scale = .7,
        y_scale = .7,
        target = entity,
        target_offset = {-.5, 0},
        orientation = .75,
        visible = false,
        only_in_alt_mode = true,
    }

    dock:validate({left = true, right = true})

    dock.van = Van:new(entity, dock, 0)

    return dock
end

function DepotDock:x()
    return self.entity.position.x
end
function DepotDock:y()
    return self.entity.position.y
end

function DepotDock:make_link(dir)

    if dir == "left" then
        rendering.set_visible(self.hint_left, true)
    else
        rendering.set_visible(self.hint_right, true)
    end

    if self.links[dir] then return end

    local entity = self.entity
    local link = rendering.draw_sprite{
        sprite = "tubs-nps-garage-link-" .. dir,
        surface = entity.surface,
        target = entity,
    }
    self.links[dir] = link
end

function DepotDock:validate(dir_mask, player)

    local entity = self.entity
    local n = get_depot_neighbours(entity)

    if self.depot then self.depot.docks[self.id] = nil end
    self.depot = nil

    local link_visible = {false,false}

    self.docks.left = n.left_dock
    self.docks.right = n.right_dock

    if n.left_depot then
        if self.depot then
            if  self.depot ~= n.left_depot then
                self.entity.surface.create_entity{name = "flying-text", position = self.entity.position, text = "Can't connect a dock to two depots"}
            end
        else
            self.depot = n.left_depot
            self.depot.docks[self.id] = self
        end
    end

    if n.right_depot then
        if self.depot then
            if  self.depot ~= n.right_depot then
                self.entity.surface.create_entity{name = "flying-text", position = self.entity.position, text = "Can't connect a dock to two depots"}
            end
        else
            self.depot = n.right_depot
            self.depot.docks[self.id] = self
        end
    end

    self:refresh_hints()

    if n.left_dock and dir_mask.left then n.left_dock:validate({left = true}, player) end
    if n.right_dock and dir_mask.right then n.right_dock:validate({right = true}, player) end


end

function DepotDock:refresh_hints()
    local have_depot = self.depot and self.depot.entity.valid
    if have_depot then
        if self.depot.entity.position.x < self.entity.position.x then
            self.depot_dir = "left"
        else
            self.depot_dir = "right"
        end

    end

    rendering.set_visible(self.hint_left, have_depot and self.depot_dir == "left")
    rendering.set_visible(self.hint_right, have_depot and self.depot_dir == "right")

    rendering.set_visible(self.warning_no_depot, have_depot ~= true)
end

function DepotDock:break_links()
    if self.links.left then
        rendering.destroy(self.links.left)
        self.links.left = nil
    end
    if self.links.right then
        rendering.destroy(self.links.right)
        self.links.right = nil
    end

    if self.depot then self.depot.docks[self.id] = nil end
    self.depot = nil

    self:refresh_hints()
end

function DepotDock:disconnect(depot_dir, destroy)
    if self.docks.left then self.docks.left.docks.right = nil end
    if self.docks.right then self.docks.right.docks.left = nil end

    self:break_links()

    if depot_dir == "left" and self.docks.right and self.docks.right.links.left then
        rendering.destroy(self.docks.right.links.left)
        self.docks.right.links.left = nil
    elseif depot_dir == "right" and self.docks.left and self.docks.left.links.right then
        rendering.destroy(self.docks.left.links.right)
        self.docks.left.links.right = nil
    end

    local opposite = function(dir)
        if dir == "left" then return "right" else return "left" end
    end

    local dir = opposite(depot_dir)
    local n = self.docks[dir]

    local last = nil

    while n do
        n:break_links()
        n.depot = nil
        last = n
        n =  n.docks[dir]
    end

    if destroy then 
        script_data.depot_docks[self.entity.unit_number] = nil
    end

    if last then
        last:validate({left = true, right = true})
    end

    -- if self.docks[depot_dir]
end

function DepotDock:die()
    if self.depot then
        self:disconnect(self.depot_dir, true)
    end

    if self.van.state == "idle" then
        self.van:die()
    end
end

local on_created_entity = function(event)
  local entity = event.entity or event.created_entity
  if not (entity and entity.valid) then return end

  local surface = entity.surface
  local position = entity.position
  local force = entity.force

  if entity.name == "tubs-ups-depot" then
    local u = Depot:new(entity)
  end

  if entity.name == "tubs-ups-loading-dock" then
    local u = LoadingDock:new(entity)
  end

  if entity.name == "tubs-ups-depot-dock" then
    local u = DepotDock:new(entity)
  end

 
end

local on_entity_removed = function(event)
  local entity = event.entity or event.created_entity
  if not (entity and entity.valid) then return end

  if entity.name == "tubs-ups-loading-dock" then
    get_dock(entity):die(game.get_player(event.player_index))
  end

  if entity.name == "tubs-ups-depot" then
    get_depot(entity):die()
  end

  if entity.name == "tubs-ups-depot-dock" then
    get_depot_dock(entity):die()
  end
end

local toggle_overlay = function(event)
    overlay.visible = not overlay.visible

    for _,depot in pairs(script_data.depots) do
        rendering.set_visible(depot.range_indicator, overlay.visible)
    end
end


local refresh_dock_gui = function(dock_gui)
    local frame = dock_gui.gui
    if frame == nil or not frame.valid then return end
    local dock = dock_gui.dock

    local old_req = dock_gui.last_recipe
    local req = dock.req
    dock_gui.last_recipe = req

    if old_req ~= req then
        frame.requesting_flow_title.clear()
        frame.requesting_flow.clear()

        if req ~= nil then
            frame.requesting_flow_title.add{type = "label", caption = "Requesting: ", style = "frame_title"}
            local req_inv = tubs.Inventory:from_recipe(req)
            req_inv:map(function(name,count) return count * 4 end)
            req_inv:mkgui(frame.requesting_flow)
        end
    end

    if req ~= nil then
        frame.on_the_way_flow_title.clear()
        frame.on_the_way_flow_title.add{type = "label", caption = "On the way: ", style = "frame_title"}
        frame.on_the_way_flow.clear()
        dock.deliveries:mkgui(frame.on_the_way_flow)
    end
end

local refresh_dock_gui_all = function()
    for i,dock_gui in pairs(script_data.dock_gui) do
        if not dock_gui.dock.entity.valid then
            dock_gui.gui.destroy()
            script_data[i] = nil
        else
            refresh_dock_gui(dock_gui)
        end
    end
end

local on_tick = function(event)

    local scheduled = script_data.scheduled[event.tick]
    if scheduled then
        script_data.scheduled[event.tick] = nil
        for _,func in ipairs(scheduled) do
            func()
        end
    end

    local get_delivery_satisfaction = function(current_inventory, van, ingredients)
        local score = 0
        local proxy = van.inventory:clone()
        local satisfaction = tubs.Inventory:new()

        for name,amount in pairs(ingredients) do
            local available = math.min(amount, current_inventory[name] or 0)
            local satisfied = proxy:emplace(name, available)
            satisfaction:emplace(name, satisfied)
            score = score + satisfied
        end
        return {score = score, satisfaction = satisfaction}
    end

    local rank_vans = function(depot, ingredients)
        local scores = {}
        local fail_count = 0
        local total_count = 0

        local current_inventory = depot.entity.get_output_inventory().get_contents()

        for _,garage in pairs(depot.docks) do
            local van = garage.van
            if van.state == "idle" or van.state == "ready" then
                local score = get_delivery_satisfaction(current_inventory, van, ingredients)
                scores[#scores+1] = {score = score, van = van}
                if score.score < 0 then
                    print("ERROR")
                end
                if score.score == 0 then
                    fail_count = fail_count + 1
                end
                total_count = total_count + 1
            end
        end

        if fail_count == total_count then
            return nil
        end
        table.sort(scores, function(a,b) return a.score.score > b.score.score end)
        return scores
    end

    local handle_customer = function(depot, dock)
        local req = dock.req
        -- invalidate when the req changes otherwise vans could be en-route
        -- if req ~= dock.last_req then
        --     -- invalidate all current deliveries
        --     for _,van in pairs(depot.vans_available) do
        --         van.delivery_queue[dock:id()] = nil
        --     end
        --     dock.deliveries:clear()
        --     dock.last_req = req
        -- end
        if req then
            local ingredients = tubs.Inventory:from_recipe(req)
            ingredients:map(function(name, count)
                 return (count * 4) - dock:on_the_way(name) - dock:in_storage(name)
            end)
            ingredients:validate()

            local verify_space = dock.entity.get_output_inventory().get_insertable_count
            local current_inventory = depot.entity.get_output_inventory().get_contents()

            for name,_ in pairs(ingredients) do
                if verify_space(name) == 0 or current_inventory[name] == nil then
                    ingredients[name] = nil
                end
            end


            if ingredients:count() == 0 then
                return 1
            end

            local satisfied = 0
            local satisfied_100 = ingredients:total_count()

            while ingredients:count() > 0 do
                local ranking = rank_vans(depot, ingredients)
                if ranking == nil then
                    return satisfied/satisfied_100
                end


                local _,result = next(ranking)
                if result then
                    print("Assigning delivery of " .. serpent.line(result.score.satisfaction))

                    ingredients:remove_inventory(result.score.satisfaction)
                    for name,count in pairs(result.score.satisfaction) do
                        depot.entity.get_output_inventory().remove({name=name,count=count})
                    end
                    result.score.satisfaction:validate()
                    result.van:assign(result.score.satisfaction, dock)
                else
                    assert(false)
                end
            end

            game.print("satisfied: " .. (satisfied/satisfied_100))
            return satisfied/satisfied_100
        end

        return 0
    end

    if event.tick % 61 == 0 then
        if profiler then profiler.Start() end
        for depot_id,depot in pairs(script_data.depots) do
            if depot.entity.valid then
                for _,customer in pairs(depot.customers) do
                    handle_customer(depot, customer.dock)
                end
                for _,dock in pairs(depot.docks) do
                    local van = dock.van
                    if van.state == "ready" then
                        van.state = "loading"
                        dock:animate(0.5)
                        schedule(event.tick + 71, script_data.scheduled, function()
                            van.current_target = nil
                            dock:animate(0)
                            van:regenerate_entity{dock.entity.position.x, dock.entity.position.y + 1}
                            van:continue()
                        end)
                    end
                end
            else
                script_data.depots[depot_id] = nil
            end
        end

        -- for _,van in pairs(script_data.vans_busy) do
        --     if van.state == "ready" then
        --         van:continue()
        --     end
        -- end

        refresh_dock_gui_all()
        if profiler then profiler.Stop() end
    end
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
        refresh_dock_gui_all()
    elseif van.state == "go-home" then
        van.delivery_queue = {}
        van:sleep()

        if not van.owner.entity.valid then
            van:die()
        end
    end
end

local on_runtime_mod_setting_changed = function(event)
end

local on_entity_settings_pasted = function(event)
    if event.destination.name == "tubs-ups-loading-dock" then
        local req = nil
        if event.source.name == "tubs-ups-loading-dock" then
            req = get_dock(event.source).req
        else
            req = event.source.get_recipe()
        end
        get_dock(event.destination).req = req
    end
end

local on_gui_closed = function(event)
    if (event.entity and event.entity.name == "tubs-ups-loading-dock") then
        local player = game.get_player(event.player_index)
        if player == nil then return end

        local gui = player.gui.left
        local frame = gui.tubs_nps_dock_frame
        if frame then frame.destroy() end
        script_data.dock_gui[event.player_index] = nil
    end
end

local on_gui_elem_changed = function(event)
  local player = game.get_player(event.player_index)
  if not (player and player.valid) then return end

  local dock_gui = script_data.dock_gui[event.player_index]
  if not dock_gui then return end

  local dock = dock_gui[event.element.index]

  if not dock then return end

  dock.req = game.recipe_prototypes[event.element.elem_value]
  refresh_dock_gui(script_data.dock_gui[event.player_index])

end

local on_gui_opened = function(event)
    if (event.entity and event.entity.valid and event.entity.name == "tubs-ups-loading-dock") then
        local player = game.get_player(event.player_index)
        if player == nil then return end

        local dock = get_dock(event.entity)

        local gui = player.gui.left
        local frame = gui.tubs_nps_dock_frame
        if frame then
            frame.clear()
        else
            frame = gui.add{type = "frame", direction = "vertical", name = "tubs_nps_dock_frame"}
        end
        frame.style.maximal_height = 600 * player.display_scale
        frame.style.maximal_width = 400 * player.display_scale

        local dock_gui = {
            gui = frame,
            last_recipe = nil,
            dock = dock,
        }

        local title_flow = frame.add{type = "flow", name = "title_flow"}
        local title = title_flow.add{type = "label", caption = {"tubs-nps-dock-status"}, style = "frame_title"}

        local control_flow = frame.add{type = "flow", name = "control_flow"}
        control_flow.add{
            type = "label",
            caption = "Derive request from recipe for:",
        }
        local derive_ingredients_from = control_flow.add{
            type = "choose-elem-button",
            elem_type = "recipe",
            recipe = dock.req and dock.req.name or nil,
        }

        dock_gui[derive_ingredients_from.index] = dock

        frame.add{type = "flow", name = "requesting_flow_title"}
        frame.add{type = "flow", name = "requesting_flow"}
        frame.add{type = "flow", name = "on_the_way_flow_title"}
        frame.add{type = "flow", name = "on_the_way_flow"}


        script_data.dock_gui[event.player_index] = dock_gui

        refresh_dock_gui_all()
    end
end

local lib = {}

lib.events =
{
  [defines.events.on_built_entity] = on_created_entity,
  [defines.events.on_robot_built_entity] = on_created_entity,
  [defines.events.script_raised_built] = on_created_entity,
  [defines.events.script_raised_revive] = on_created_entity,

  [defines.events.on_entity_died] = on_entity_removed,
  [defines.events.on_robot_mined_entity] = on_entity_removed,
  [defines.events.script_raised_destroy] = on_entity_removed,
  [defines.events.on_player_mined_entity] = on_entity_removed,

  [defines.events.on_tick] = on_tick,
  [defines.events.on_runtime_mod_setting_changed] = on_runtime_mod_setting_changed,

  [defines.events.on_entity_settings_pasted] = on_entity_settings_pasted,
  [defines.events.on_gui_opened] = on_gui_opened,
  [defines.events.on_gui_closed] = on_gui_closed,
  [defines.events.on_ai_command_completed] = on_ai_command_completed,
  [defines.events.on_gui_elem_changed] = on_gui_elem_changed,

  ["toggle-tubs-ups-overlay"] = toggle_overlay,

}

lib.on_init = function()
  global.tubs_ups_depots = global.tubs_ups_depots or script_data
  global.tubs_ups_overlay = global.tubs_ups_overlay or overlay
--   global.tubs_cars = global.tubs_cars or cars
end

lib.on_load = function()
    script_data = global.tubs_ups_depot or script_data
    overlay = global.tubs_ups_overlay or overlay
    -- cars = global.tubs_cars or cars
--   setup_lib_values()
--   for k, depot in pairs (script_data.depots) do
--     if depot.entity.valid then
--       --Not sure if I should remove it here, as it will cry "oh modifying global during on load wtf"
--       load_depot(depot)
--     end
--   end

end

lib.on_configuration_changed = function()
  global.tubs_ups_depots = global.tubs_ups_depots or script_data
  global.tubs_ups_overlay = global.tubs_ups_overlay or overlay
--   global.tubs_cars = global.tubs_cars or cars
end

return lib