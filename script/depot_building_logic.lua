local Van = require("__NauvisPostalService__/script/van")
local tubs = require("libtubs")
local inv = require("inventory")
local bag = inv.contents
local slider_mapping = require("slider_mapping")

local profiler = nil
if script.active_mods["profiler"] then
    profiler = require('__profiler__/profiler.lua')
end


local service_radius = 16

local script_data =
{
  update_rate = 60,
  loading_docks = {},
  garages = {},
  depots = {},
  kill_gui = nil,
  dock_gui = {},
  depot_gui = {},
  scheduled = {},

  on_gui_event = {},
}

local refresh_gui_all = function(tbl, refresh)
    for i,gui in pairs(tbl) do
        if not gui.entity.valid then
            gui.gui.destroy()
            script_data[i] = nil
        else
            refresh(gui)
        end
    end
end


local update_depot_filter = function(params, event)
    local depot = params.depot
    local filters = depot.filters

    filters[params.index] = event.element.elem_value

    depot.to_collect = {}
    for _,value in pairs(filters) do
        depot.to_collect[value] = 1
    end

end

local dock_gui_impl = {}

local gui_callbacks = {
    update_depot_filter = update_depot_filter,
}

local add_gui_callback = function(index, func, mask, params)
    script_data.on_gui_event[index] = {
        func = func,
        mask = mask,
        payload = params
    }
end

local fire_gui_callback = function(event, mask)
  local player = game.get_player(event.player_index)
  if not (player and player.valid) then return end

  local callback = script_data.on_gui_event[event.element.index]
  if callback and callback.mask ==  mask then
    gui_callbacks[callback.func](callback.payload, event)
    return
  end
end


local overlay =
{
    visible = false,
}

local nil_logistic_network = {

}


local float_text = function(entity, text, slow)
    local name = slow and "flying-text" or "fast-flying-text"
    entity.surface.create_entity{name = name, position = entity.position, text = text}
end

local get_dock = function(entity)
    return script_data.loading_docks[entity.unit_number]
end

local get_garage = function(entity)
    return script_data.garages[entity.unit_number]
end

local get_depot = function(entity)
    return script_data.depots[entity.unit_number]
end

local get_depot_neighbours = function(entity)
    local position = {x = entity.position.x, y = entity.position.y}
    local left_offset = 1
    if entity.name == "tubs-nps-depot" then left_offset = 2 end
    local box = {
        {math.floor(position.x) - left_offset, math.floor(position.y)},
        {math.floor(position.x) + 2, math.floor(position.y)},
    }

    local neighbours = entity.surface.find_entities_filtered{area = box, name = {"tubs-nps-garage", "tubs-nps-depot"}}

    local left_depot = nil
    local right_depot = nil
    local left_dock = nil
    local right_dock = nil

    for _, n in pairs (neighbours) do
        if n.position.x < entity.position.x then
            left_dock = get_garage(n)
            left_depot = get_depot(n) or (left_dock and left_dock.depot)
        elseif n.position.x > entity.position.x then
            right_dock = get_garage(n)
            right_depot = get_depot(n) or (right_dock and right_dock.depot)
        end
    end

    return {left_depot = left_depot, right_depot = right_depot, left_dock = left_dock, right_dock = right_dock}
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

            -- array
            filters = {},
            -- set of filtered items
            to_collect = {},
        },
        Depot_mt)

    local customer_entities = entity.surface.find_entities_filtered{position = entity.position, radius = service_radius, name = {"tubs-nps-loading-dock"}}
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
            animation = "tubs-nps-dock_base",
            surface = self.entity.surface,
            target = self.entity,
            x_scale = .4,
            y_scale = .4,
        }
        self.shadow = rendering.draw_animation{
            animation = "tubs-nps-dock_shadow",
            surface = self.entity.surface,
            target = self.entity,
            x_scale = .4,
            y_scale = .4,
        }
    end
    tubs.set_frame(game.tick, 0, {frames=38, speed=speed}, self.anim)
    tubs.set_frame(game.tick, 0, {frames=38, speed=speed}, self.shadow)
end

function LoadingDock:new(entity)
    local dock = setmetatable(
        {
            entity = entity,
            deliveries = inv.new(),
            collections = inv.new(),
            req_arr = { },
            req = nil,
        },
        LoadingDock_mt)

    inv.set_stack_limit(dock.deliveries, 16)
    inv.set_stack_limit(dock.collections, 16)
    dock:animate(0)

    local providers = entity.surface.find_entities_filtered{position = entity.position, radius = service_radius, name = {"tubs-nps-depot"}}
    for _,depot_entity in pairs(providers) do
        get_depot(depot_entity):add_customer(dock)
    end

    script_data.loading_docks[entity.unit_number] = dock

    return dock
end

function LoadingDock:set_request(req, refresh_array)
    if req == nil then
        self.req = nil
        self.req_arr = {}
    else
        self.req = req

        if refresh_array then
            local i = 1

            for item,count in bag(self.req) do
                self.req_arr[i] = {name = item, count = count}
                i = i + 1
            end
        end
    end

    dock_gui_impl.refresh()

end

function LoadingDock:set_request_from_array()
    self.req = nil
    for i=1,5 do
        local item = self.req_arr[i]
        if item and item.name then
            if self.req == nil then self.req = inv.new() end
            inv.emplace(self.req, item.name, item.count)
        end
    end
end

function LoadingDock:set_request_from_recipe(recipe)
    if recipe == nil then
        self:set_request(nil, true)
    else
        local req = inv.from_recipe(recipe)
        inv.map(req, (function(name,count) return count * 4 end))
        self:set_request(req, true)
    end
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

function LoadingDock:collect(van, collection)
    self:animate(-.5)
    schedule(game.tick + 60, script_data.scheduled, function()
        self:animate(0)
        van:continue()
    end)

    inv.remove_inventory(self.collections, collection)
    local actual = inv.new()
    local inventory = self.entity.get_output_inventory()
    local current = inventory.get_contents()
    for name,amount in bag(collection) do
        local current_amount = current[name]
        if current_amount then
            amount = math.min(current_amount, amount)
            inv.emplace(actual, name, amount)
            inventory.remove{name = name, count = amount}
        end
    end
    return actual
end

function LoadingDock:accept_delivery(van, delivery)
    self:animate(.5)
    schedule(game.tick + 60, script_data.scheduled, function()
        self:animate(0)
        van:continue()
    end)

    inv.remove_inventory(self.deliveries, delivery)
    local inserted = inv.new()
    local insert = self.entity.get_output_inventory().insert
    for name,amount in bag(delivery) do
        local amount_inserted = insert({name = name, count = amount})
        if amount_inserted > 0 then
            inv.emplace(inserted, name, amount_inserted)
        end
    end
    return inserted
end

function LoadingDock:die()
    script_data.loading_docks[self.entity.unit_number] = nil

    local providers = self.entity.surface.find_entities_filtered{position = self.entity.position, radius = service_radius, name = {"tubs-nps-depot"}}
    for _,depot_entity in pairs(providers) do
        get_depot(depot_entity):remove_customer(self)
    end
end

local Garage = {}
local Garage_mt = {__index = Garage}

function Garage:animate(speed)
    if not self.anim then
        self.anim = rendering.draw_animation{
            animation = "tubs-nps-garage-base",
            surface = self.entity.surface,
            target = self.entity,
            x_scale = .4,
            y_scale = .4,
        }
    end

    if not self.lower_anim then
        self.lower_anim = rendering.draw_animation{
            animation = "tubs-nps-garage-base-lower",
            surface = self.entity.surface,
            target = self.entity,
            x_scale = .4,
            y_scale = .4,
            render_layer = "floor",
        }
    end

    if not self.shadow_anim then
        self.shadow_anim = rendering.draw_animation{
            animation = "tubs-nps-garage-shadow",
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

function Garage:new(proxy)

    local entity = proxy.surface.create_entity{
        name = "tubs-nps-garage",
        position = proxy.position,
        force = proxy.force,
        player = proxy.last_user,
    }

    proxy.destroy()

    local dock = setmetatable(
        {
            entity = entity,
            depot = nil,
            links = {},
            docks = {},
            id = entity.unit_number,
            warning_no_depot = nil,
            preferred_mode = 1,
        },
        Garage_mt)

    script_data.garages[entity.unit_number] = dock
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

    dock.van = Van:new(dock, 0)

    return dock
end

function Garage:x()
    return self.entity.position.x
end
function Garage:y()
    return self.entity.position.y
end

function Garage:make_link(dir)

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

function Garage:validate(dir_mask, player)

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

function Garage:refresh_hints()
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

function Garage:break_links()
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

function Garage:disconnect(depot_dir, destroy)
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
        script_data.garages[self.entity.unit_number] = nil
    end

    if last then
        last:validate({left = true, right = true})
    end

    -- if self.docks[depot_dir]
end

function Garage:die()
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

  if entity.name == "tubs-nps-depot" then
    local u = Depot:new(entity)
  end

  if entity.name == "tubs-nps-loading-dock" then
    local u = LoadingDock:new(entity)
  end

  if entity.name == "tubs-nps-garage-proxy" then
    local u = Garage:new(entity)
  end

 
end

local on_entity_removed = function(event)
  local entity = event.entity or event.created_entity
  if not (entity and entity.valid) then return end

  if entity.name == "tubs-nps-loading-dock" then
    get_dock(entity):die(game.get_player(event.player_index))
  end

  if entity.name == "tubs-nps-depot" then
    get_depot(entity):die()
  end

  if entity.name == "tubs-nps-garage" then
    get_garage(entity):die()
  end
end

local toggle_overlay = function(event)
    overlay.visible = not overlay.visible

    for _,depot in pairs(script_data.depots) do
        rendering.set_visible(depot.range_indicator, overlay.visible)
    end
end

local refresh_depot_gui = function(depot_gui)
    local frame = depot_gui.gui
    if frame == nil or not frame.valid then return end
    local depot = depot_gui.depot
    local gui = depot_gui.gui


    local busy = 0
    local idle = 0
    local loading = 0

    for _,dock in pairs(depot.docks) do
        if dock.van.state == "ready" or dock.van.state == "loading" then
            loading = loading + 1
        elseif dock.van.state == "idle" then
            idle = idle + 1
        else
            busy = busy + 1
        end
    end

    for i,filter_button in ipairs(depot_gui.filters) do
        filter_button.elem_value = depot.filters[i]
    end

    depot_gui.vans_busy.caption = tostring(busy)
    depot_gui.vans_idle.caption = tostring(idle)
    depot_gui.vans_loading.caption = tostring(loading)

    local custoemrs_list = {}
    for _,customer in pairs(depot.customers) do
        table.insert(custoemrs_list, tostring(customer.dock.entity.unit_number))
    end

    depot_gui.customers.items = custoemrs_list

end


local refresh_dock_gui = function(dock_gui)
    local frame = dock_gui.gui
    if frame == nil or not frame.valid then return end
    local dock = dock_gui.dock
    local req = dock.req

    -- local old_req = dock_gui.last_recipe
    -- dock_gui.last_recipe = req

    -- if old_req ~= req then
    --     frame.requesting_flow_title.clear()
    --     frame.requesting_flow.clear()


    -- dock_gui.requests.clear()


    for i = 1,5 do
        local item = dock.req_arr[i]
        local button = dock_gui.requests[i]

        local name = item and item.name or nil
        local count = item and item.count or 0

        local copy = tubs.item_button(name, count, "CGUI_logistic_slot_button")
        button.sprite = copy.sprite
        button.number = copy.number
        button.tooltip = copy.tooltip
    end

    if req ~= nil then
        frame.on_the_way_flow_title.clear()
        frame.on_the_way_flow_title.add{type = "label", caption = "On the way: ", style = "frame_title"}
        frame.on_the_way_flow.clear()
        inv.mkgui(dock.deliveries, frame.on_the_way_flow)
    end
end

dock_gui_impl.refresh = function()
    refresh_gui_all(script_data.dock_gui, refresh_dock_gui)
end

gui_callbacks.derive_dock_request = function(dock_gui, event)
    local dock = dock_gui[event.element.index]
    if not dock then return end

    dock:set_request_from_recipe(game.recipe_prototypes[event.element.elem_value])
    event.element.elem_value = nil
    refresh_dock_gui(dock_gui)
end

gui_callbacks.update_dock_item_req_count = function(param, event)
    param.dock_gui.dialog_textfield.caption = tostring(slider_mapping.slider_to_textfield[event.element.slider_value])
    refresh_dock_gui(param.dock_gui)
end

gui_callbacks.update_dock_item_req_count_text = function(param, event)
    param.dock_gui.dialog_slider.slider_value = slider_mapping.translate_to_slider(tonumber(event.element.text))
    refresh_dock_gui(param.dock_gui)
end

gui_callbacks.cancel_dock_item_req_dialog = function(param, event)
    param.dock_gui.requests[param.index].style = "CGUI_logistic_slot_button"
    param.dock_gui.dialog.destroy()
end

gui_callbacks.confirm_dock_item_req_dialog = function(param, event)
    local dock_gui = param.dock_gui
    local dock = dock_gui.dock

    dock_gui.requests[param.index].style = "CGUI_logistic_slot_button"

    local name = dock_gui.dialog_elem.elem_value
    if name then
        local count = tonumber(param.dock_gui.dialog_textfield.caption)
        dock.req_arr[param.index] = { name = name, count = count }
    else
        dock.req_arr[param.index] = nil
    end
    dock:set_request_from_array()

    param.dock_gui.dialog.destroy()

    refresh_dock_gui(dock_gui)
end

gui_callbacks.on_dock_req_button = function(param, event)
    if event.button == defines.mouse_button_type.right then
        param.dock_gui.dock.req_arr[param.index] = nil
        param.dock_gui.dock:set_request_from_array()
        refresh_dock_gui(param.dock_gui)
    else
        local dock_gui = param.dock_gui
        if dock_gui.dialog then
            dock_gui.dialog_source.style = "CGUI_logistic_slot_button"
            dock_gui.dialog.destroy()
        end

        dock_gui.dialog_source = dock_gui.requests[param.index]
        dock_gui.dialog_source.style = "CGUI_selected_logistic_slot_button"
        -- source.style.graphical_set = source.CGUI_selected_logistic_slot_button style.hovered_graphical_set

        local dialog = dock_gui.gui.add{type = "frame", direction = "vertical", name = "requestor_frame"}
        dialog.style.width = 380
        dialog.style.height = 100

        local title_flow = dialog.add{type = "flow", name = "title_flow"}
        local title = title_flow.add{type = "label", caption = {"tubs-nps-dock-set-request-item"}, style = "frame_title"}
        title.style.width = 320
        dock_gui.dialog_cancel = title_flow.add{type = "button", caption = "✕", style = "close_button"}

        local contents_flow = dialog.add{type = "flow", name = "contents_flow"}
        contents_flow.style.vertical_align = "center"
        local current = param.dock_gui.dock.req_arr[param.index]
        dock_gui.dialog_elem = contents_flow.add{
            type = "choose-elem-button", elem_type = "item", item = current and current.name or nil
        }
        dock_gui.dialog_slider = contents_flow.add{
            type = "slider", minimum_value = 0, maximum_value = 37,
            value = slider_mapping.translate_to_slider(current and current.count or 0),
        }
        dock_gui.dialog_textfield = contents_flow.add{
            type = "textfield", style = "slider_value_textfield", numeric = true,
            text = tostring(current and current.count or 0),
        }
        dock_gui.dialog_textfield.style.maximal_width = 80
        dock_gui.dialog_ok = contents_flow.add{type = "button", style = "item_and_count_select_confirm", caption = "✔"}
        dock_gui.dialog_ok.style.maximal_width = 32

        add_gui_callback(dock_gui.dialog_slider.index, "update_dock_item_req_count", "on_slide", param)
        add_gui_callback(dock_gui.dialog_textfield.index, "update_dock_item_req_count_text", "on_text_changed", param)
        add_gui_callback(dock_gui.dialog_cancel.index, "cancel_dock_item_req_dialog", "on_click", param)
        add_gui_callback(dock_gui.dialog_ok.index, "confirm_dock_item_req_dialog", "on_click", param)

        dock_gui.dialog = dialog
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
        local proxy = inv.clone(van.inventory)
        local satisfaction = inv.new()

        for name,amount in bag(ingredients) do
            local available = math.min(amount, current_inventory[name] or 0)
            local satisfied = inv.emplace(proxy, name, available)
            inv.emplace(satisfaction, name, satisfied)
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
            if garage.preferred_mode == 1 and van.state == "idle" or van.state == "ready" then
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

    local handle_customer = function(depot, dock, delivery_vans, collection_vans)
        local req = dock.req
        if req then
            local ingredients = inv.clone(req)
            local surplus = inv.new()

            local in_target_storage = dock.entity.get_output_inventory().get_contents()

            for name,amount in pairs(in_target_storage) do
                if depot.to_collect[name] then
                    amount = amount - (dock.collections[name] or 0)
                    if ingredients[name] == nil then
                        inv.emplace(surplus, name, amount)
                    end
                end
            end

            inv.map(ingredients, (function(name,count)
                return count - dock:on_the_way(name) - dock:in_storage(name)
            end))

            local verify_space = dock.entity.get_output_inventory().get_insertable_count
            local current_inventory = depot.entity.get_output_inventory().get_contents()

            for name,_ in bag(ingredients) do
                if verify_space(name) == 0 or current_inventory[name] == nil then
                    ingredients[name] = nil
                end
            end


            for id,van in pairs(collection_vans) do
                for name,count in bag(surplus) do
                    local removed = inv.emplace(van.collection, name, count)
                    if removed > 0 then
                        inv.emplace(dock.collections, name, removed)
                        inv.remove(surplus, name, removed)
                        van:assign_collection({name, removed}, dock)
                    end
                end
            end

            if inv.count(ingredients) == 0 then
                return 1
            end

            local satisfied = 0
            local satisfied_100 = inv.total_count(ingredients)

            while inv.count(ingredients) > 0 do
                local ranking = rank_vans(depot, ingredients)
                if ranking == nil then
                    return satisfied/satisfied_100
                end


                local _,result = next(ranking)
                if result then
                    print("Assigning delivery of " .. serpent.line(result.score.satisfaction))

                    inv.remove_inventory(ingredients, result.score.satisfaction)
                    for name,count in bag(result.score.satisfaction) do
                        depot.entity.get_output_inventory().remove({name=name,count=count})
                    end
                    inv.validate(result.score.satisfaction)
                    result.van:assign(result.score.satisfaction, dock)
                else
                    assert(false)
                end
            end

            return satisfied/satisfied_100
        end

        return 0
    end

    if event.tick % 61 == 0 then
        if profiler then profiler.Start() end
        for depot_id,depot in pairs(script_data.depots) do
            if depot.entity.valid then
                local delivery_vans = {}
                local collection_vans = {}
                for _,dock in pairs(depot.docks) do
                    local van = dock.van
                    if van.state == "ready" or van.state == "idle" then
                        if dock.preferred_mode == 1 then
                            delivery_vans[van.id] = van
                        else
                            collection_vans[van.id] = van
                        end
                    end
                end
                for _,customer in pairs(depot.customers) do
                    handle_customer(depot, customer.dock, delivery_vans, collection_vans)
                end
                for _,dock in pairs(depot.docks) do
                    local van = dock.van
                    if van.state == "ready" then
                        van.state = "loading"
                        if van.mode == 1 then
                            dock:animate(0.5)
                            schedule(event.tick + 71, script_data.scheduled, function()
                                van.current_target = nil
                                dock:animate(0)
                                van:regenerate_entity{dock.entity.position.x, dock.entity.position.y + 1}
                                van:continue()
                            end)
                        else
                            van:continue()
                        end
                    end
                end
            else
                script_data.depots[depot_id] = nil
            end
        end


        refresh_gui_all(script_data.depot_gui, refresh_depot_gui)
        if profiler then profiler.Stop() end
    end
end
local on_runtime_mod_setting_changed = function(event)
end

local on_entity_settings_pasted = function(event)
    if event.destination.name == "tubs-nps-loading-dock" then
        if event.source.name == "tubs-nps-loading-dock" then
            local from = get_dock(event.source)
            get_dock(event.destination):set_request(inv.clone(from.req), true)
        else
            get_dock(event.destination):set_request_from_recipe(event.source.get_recipe())
        end
    end
end

local on_gui_closed = function(event)
    local player = game.get_player(event.player_index)
    if player == nil then return end

    if (event.entity and event.entity.name == "tubs-nps-depot") then
        local gui = player.gui.screen
        local frame = gui.tubs_nps_depot_frame
        if frame then frame.destroy() end
        script_data.depot_gui[event.player_index] = nil
    end

    if (event.entity and event.entity.name == "tubs-nps-loading-dock") then
        local gui = player.gui.screen
        local frame = gui.tubs_nps_dock_frame
        if frame then frame.destroy() end
        script_data.dock_gui[event.player_index] = nil
    end
end

local on_gui_click = function(event)
    fire_gui_callback(event, "on_click")
end
local on_gui_text_changed = function(event)
    fire_gui_callback(event, "on_text_changed")
end
local on_gui_value_changed = function(event)
    fire_gui_callback(event, "on_slide")
end

local on_gui_elem_changed = function(event)
    fire_gui_callback(event, "on_choose_elem")
end

local on_gui_opened = function(event)
    if (event.entity and event.entity.valid and event.entity.name == "tubs-nps-depot") then
        local player = game.get_player(event.player_index)
        if player == nil then return end

        local depot = get_depot(event.entity)

        assert(depot) -- one day I will learn...

        local gui = player.gui.screen
        local frame = gui.tubs_nps_depot_frame
        if frame then
            frame.clear()
        else
            frame = gui.add{type = "frame", direction = "vertical", name = "tubs_nps_depot_frame"}
        end

        local scale = player.display_scale

        local width = 400
        local raw_screen_width = player.display_resolution.width

        local cx = raw_screen_width/2

        frame.style.width = width
        frame.style.height = 250

        frame.location = {cx - width, 20}

        local depot_gui = {
            entity = depot.entity,
            gui = frame,
            last_recipe = nil,
            depot = depot,
            filters = {},
        }

        local title_flow = frame.add{type = "flow", name = "title_flow"}
        local title = title_flow.add{type = "label", caption = {"tubs-nps-depot-status"}, style = "frame_title"}
        title.drag_target = frame

        local control_flow = frame.add{type = "flow", name = "control_flow"}
        control_flow.add{
            type = "label",
            caption = "Filter picked up items",
            style = "heading_2_label"
        }
        for i=1,5,1 do
            local filter = control_flow.add{
                type = "choose-elem-button",
                elem_type = "item",
                style = "CGUI_logistic_slot_button"
            }
            depot_gui.filters[i] = filter
            add_gui_callback(filter.index, "update_depot_filter", "on_choose_elem", {depot = depot, index = i})
        end

        local status = frame.add{type = "flow", name = "current_status"}


        status.add{type = "label", caption = "Vans", style = "heading_2_label"}
        status.add{type = "label", caption = "idle:", style = "heading_3_label"}
        depot_gui.vans_idle = status.add{type = "label", caption = "1", name = "vans_idle"}
        status.add{type = "label", caption = "loading:", style = "heading_3_label"}
        depot_gui.vans_loading = status.add{type = "label", caption = "1", name = "vans_loading"}
        status.add{type = "label", caption = "busy:", style = "heading_3_label"}
        depot_gui.vans_busy = status.add{type = "label", caption = "1", name = "vans_busy"}

        frame.add{type = "label", caption = "Customers", style = "heading_2_label"}
        depot_gui.customers = frame.add{
            type = "list-box",
            items = {
           
            }
        }

        refresh_depot_gui(depot_gui)
        script_data.depot_gui[event.player_index] = depot_gui
    end
    if (event.entity and event.entity.valid and event.entity.name == "tubs-nps-loading-dock") then
        local player = game.get_player(event.player_index)
        if player == nil then return end

        local dock = get_dock(event.entity)

        local gui = player.gui.screen
        local frame = gui.tubs_nps_dock_frame
        if frame then
            frame.clear()
        else
            frame = gui.add{type = "frame", direction = "vertical", name = "tubs_nps_dock_frame"}
        end
       
        local scale = player.display_scale

        local width = 400
        local raw_screen_width = player.display_resolution.width

        local cx = raw_screen_width/2

        frame.style.width = width
        frame.style.height = 250

        frame.location = {cx - width, 20}

        local dock_gui = {
            entity = dock.entity,
            gui = frame,
            last_recipe = nil,
            dock = dock,
        }

        local title_flow = frame.add{type = "flow", name = "title_flow"}
        local title = title_flow.add{type = "label", caption = {"tubs-nps-dock-status"}, style = "frame_title"}
        title.drag_target = frame

        local control_flow = frame.add{type = "flow", name = "control_flow"}
        control_flow.add{
            type = "label",
            caption = "Derive request from recipe for:",
        }
        local derive_ingredients_from = control_flow.add{
            type = "choose-elem-button",
            elem_type = "recipe",
            style = "CGUI_logistic_slot_button",
        }
        add_gui_callback(derive_ingredients_from.index, "derive_dock_request", "on_choose_elem", dock_gui)


        dock_gui[derive_ingredients_from.index] = dock

        frame.add{type = "flow", name = "requesting_flow_title"}
        local requests = frame.add{
            type = "table",
            column_count = 5,
            name = "req_tbl",
            style = "filter_slot_table"
        }

        dock_gui.requests = {}

        for i = 1,5,1 do
            local button = requests.add(tubs.item_button(nil, 0, "CGUI_logistic_slot_button"))
            dock_gui.requests[i] = button
            add_gui_callback(button.index, "on_dock_req_button", "on_click", {
                dock_gui = dock_gui,
                index = i,
            })
        end

        frame.add{type = "flow", name = "on_the_way_flow_title"}
        frame.add{type = "flow", name = "on_the_way_flow"}


        script_data.dock_gui[event.player_index] = dock_gui

        refresh_dock_gui(dock_gui)
    end
end

function on_ai_command_completed()
end

local lib = {}

local toggle_garage_direction = function(event)
    local entity = game.players[event.player_index].selected
    if not entity then return end
    if entity.name ~= "tubs-nps-garage" then return end

    local garage = get_garage(entity)
    garage.preferred_mode = -garage.preferred_mode

    local orientation = 0
    local text = nil

    if garage.preferred_mode == 1 then
        orientation = 0
        text = "delivery"
    else
        orientation = .5
        text = "collection"
    end
    -- rendering.set_orientation(garage.hint_mode, orientation)
    float_text(entity, text, true)


end

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
  [defines.events.on_gui_value_changed] = on_gui_value_changed,
  [defines.events.on_gui_click] = on_gui_click,
  [defines.events.on_gui_text_changed] = on_gui_text_changed,

  ["toggle-tubs-nps-overlay"] = toggle_overlay,
  ["toggle-nps-garage-direction"] = toggle_garage_direction,

}

lib.on_init = function()
  global.tubs_ups_depots = global.tubs_ups_depots or script_data
  global.tubs_ups_overlay = global.tubs_ups_overlay or overlay
--   global.tubs_cars = global.tubs_cars or cars
end

lib.on_load = function()
    script_data = global.tubs_ups_depots or script_data
    overlay = global.tubs_ups_overlay or overlay
    for _,garage in pairs(script_data.garages) do
        setmetatable(garage, Garage_mt)
    end
    for _,depot in pairs(script_data.depots) do
        setmetatable(depot, Depot_mt)
    end
    for _,dock in pairs(script_data.loading_docks) do
        setmetatable(dock, LoadingDock_mt)
    end
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
end

return lib