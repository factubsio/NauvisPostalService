
local lib = {}

lib.Inventory = {}

function lib.Inventory:new()
  return setmetatable({}, {
    __count = 0,
    __stack_limit = 8,
    __index = lib.Inventory
  })
end

function lib.Inventory:clear()
  self:set_count(0)
  for k in next, self do rawset(self, k, nil) end
end

function lib.Inventory:set_stack_limit(limit)
  getmetatable(self).__stack_limit = limit
end
function lib.Inventory:stack_limit()
  return getmetatable(self).__stack_limit
end

function lib.Inventory:set_count(count)
  getmetatable(self).__count = count
end
function lib.Inventory:adjust_count(delta)
  local tbl = getmetatable(self)
  tbl.__count = tbl.__count + delta
end
function lib.Inventory:count()
  return getmetatable(self).__count
end

function lib.Inventory:clone()
  local mt = getmetatable(self)
  local inv = lib.Inventory:new()
  for n,v in pairs(self) do
    inv[n] = v
  end
  setmetatable(inv, {
    __count = mt.__count,
    __stack_limit = mt.__stack_limit,
    __index = mt.__index,
  })
  return inv
end

function lib.Inventory:from_container(container)
  local inv = lib.Inventory:new()
  local inventory = container.get_output_inventory()

  for name,amount in pairs(inventory.get_contents()) do
        inv:emplace(name, amount)
  end
  return inv
end

function lib.Inventory:from_recipe(recipe)
  local inv = lib.Inventory:new()

  for _,ingredient in pairs(recipe.ingredients) do
      local name = ingredient.name
      if ingredient.type ==  "item" then
          inv:emplace(name, ingredient.amount)
      else
          -- liquids
      end
  end

  return inv
end
function lib.Inventory:map(func)
  for name,count in pairs(self) do
    local val = func(name, count)
    if val <= 0 then self[name] = nil else self[name] = val end
  end
end

function lib.Inventory:total_count()
  local total_count = 0
  for name,count in pairs(self) do
    total_count = total_count + count
  end
  return total_count
end

function lib.Inventory:validate()
  for k,v in pairs(self) do
    assert(v > 0)
  end
end


function lib.Inventory:emplace(name, amount)
  local to_add = 0
  if amount > 0 then
    local current = self[name] or 0
    local current_stacks,remaining_space,stack_size = lib.get_stack_count(name, current)

    if remaining_space > amount then
      to_add = amount
    else
      local stacks_remaining = self:stack_limit() - self:count()
      if stacks_remaining == 0 then return 0 end


      local stacks_needed = lib.get_stack_count(name, amount - remaining_space)

      if stacks_remaining >= stacks_needed then
        to_add = amount
        self:adjust_count(stacks_needed)
      else
        to_add = remaining_space + stacks_remaining * stack_size
        self:adjust_count(stacks_remaining)
      end
    end

    self[name] = current + to_add
  end
  return to_add
end

function lib.Inventory:add_inventory(t2)
  for k,v in pairs(t2) do
    self:emplace(k,v)
  end
end

function lib.Inventory:remove_inventory(t2)
  for k,v in pairs(t2) do
    local current = self[k]
    local current_stacks = lib.get_stack_count(k, current)
    current = current - v
    local new_stacks = lib.get_stack_count(k, current)
    self:adjust_count(new_stacks - current_stacks)
    self[k] = (current > 0) and current or nil
  end
end

function lib.Inventory:mkgui(parent)

  if self:count() == 0 then return end

  local tbl = parent.add{
      type = "table",
      column_count = self:count(),
      name = "requesting",
  }

  for name,amount in pairs(self) do
      local item_locale = lib.get_item_icon_and_locale(name)
      local button = tbl.add{
          type = "sprite-button",
          sprite = item_locale.icon,
          number = amount,
          style = "slot_button",
          name = name,
          tooltip = amount,
      }
  end

end


lib.mkbox = function(w, h, pad)
    h = h or w
    local hw = w/2 - (pad and .1 or 0)
    local hh = h/2 - (pad and .1 or 0)
    return { {-hw, -hh}, {hw, hh} }
end

local stack_cache = {}
lib.get_stack_size = function(item)
  local size = stack_cache[item]
  if not size then
    size = game.item_prototypes[item].stack_size
    stack_cache[item] = size
  end
  return size
end

lib.get_stack_count = function(item, count)
  local stack_size = lib.get_stack_size(item)
  local usage = math.ceil(count / stack_size)
  return usage, (usage * stack_size) - count, stack_size
end

local icon_cache = {}
lib.get_item_icon_and_locale = function(name)
  if icon_cache[name] then
    return icon_cache[name]
  end

  local items = game.item_prototypes
  if items[name] then
    icon = "item/"..name 
    locale = items[name].localised_name
    local value = {icon = icon, locale = locale}
    icon_cache[name] = value
    return value
  end

  local fluids = game.fluid_prototypes
  if fluids[name] then
    icon = "fluid/"..name
    locale = fluids[name].localised_name
    local value = {icon = icon, locale = locale}
    icon_cache[name] = value
    return value
  end

end



return lib