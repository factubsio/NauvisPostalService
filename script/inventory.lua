
local tubs = require("libtubs")
local Inventory = {}

function Inventory.new()

 return {
    __count = 0,
    __stack_limit = 8,
  }
end

function Inventory.clone(self)
  local inv = Inventory.new()

  -- Not contents here since we want to clone __count and __stack_limit
  for n,v in pairs(self) do
    inv[n] = v
  end
  return inv
end

function Inventory.from_container(container)
  local inv = Inventory.new()
  local inventory = container.get_output_inventory()

  for name,amount in pairs(inventory.get_contents()) do
        Inventory.emplace(inv, name, amount)
  end
  return inv
end

function Inventory.from_recipe(recipe, stack_limit)
  local inv = Inventory.new()
  Inventory.set_stack_limit(inv, stack_limit or 8)

  for _,ingredient in pairs(recipe.ingredients) do
      local name = ingredient.name
      if ingredient.type ==  "item" then
          Inventory.emplace(inv, name, ingredient.amount)
      else
          -- liquids
      end
  end

  return inv
end

function Inventory.clear(self)
    Inventory.set_count(self, 0)
  for k in next, self do
    if k ~= "__count" and k ~= "__stack_limit" then rawset(self, k, nil) end
  end
end

function Inventory.set_stack_limit(self, limit)
  self.__stack_limit = limit
end
function Inventory.stack_limit(self)
  return self.__stack_limit
end

function Inventory.set_count(self, count)
  self.__count = count
end
function Inventory.adjust_count(self, delta)
  self.__count = self.__count + delta
end
function Inventory.count(self)
  return self.__count
end

function Inventory.map(self, func)
  for name,count in Inventory.contents(self) do
    -- FIXME: use emplace to respect stack sizes...
    local val = func(name, count)
    if val <= 0 then
      self[name] = nil
    else
      self[name] = val
    end
  end
end

function Inventory.total_count(self)
  local total_count = 0
  for name,count in Inventory.contents(self) do
    total_count = total_count + count
  end
  return total_count
end

function Inventory.validate(self)
  for k,v in Inventory.contents(self) do
    assert(v > 0)
  end
end


function Inventory.emplace(self, name, amount)
  local to_add = 0
  if amount > 0 then
    local current = self[name] or 0
    local current_stacks,remaining_space,stack_size = tubs.get_stack_count(name, current)

    if remaining_space > amount then
      to_add = amount
    else
      local stacks_remaining = self.__stack_limit - self.__count
      if stacks_remaining == 0 then return 0 end

      local stacks_needed = tubs.get_stack_count(name, amount - remaining_space)

      if stacks_remaining >= stacks_needed then
        to_add = amount
        Inventory.adjust_count(self, stacks_needed)
      else
        to_add = remaining_space + stacks_remaining * stack_size
        Inventory.adjust_count(self, stacks_remaining)
      end
    end

    self[name] = current + to_add
  end
  return to_add
end

function Inventory.add_inventory(self, t2)
  for k,v in Inventory.contents(t2) do
    Inventory.emplace(self, k,v)
  end
end

function Inventory.remove(self, name, count)
    local current = self[name]
    local current_stacks = tubs.get_stack_count(name, current)
    current = current - count
    local new_stacks = tubs.get_stack_count(name, current)
    Inventory.adjust_count(self, new_stacks - current_stacks)
    self[name] = (current > 0) and current or nil
end

local function next_skip(self, index)
  local value = nil
  index,value = next(self, index)
  while index == "__count" or index == "__stack_limit" do
    index,value = next(self,index)
  end
  return index,value
end

function Inventory.contents(self)
  if self == nil then return nil, nil end

  local index,value = nil,nil
  return function()
    index,value = next_skip(self, index)
    return index,value
  end
end

function Inventory.remove_inventory(self, t2)
  for name,count in Inventory.contents(t2) do
    Inventory.remove(self, name,count)
  end
end

function Inventory.mkgui(self, parent)

  if self.__count == 0 then return end

  local tbl = parent.add{
      type = "table",
      column_count = self.__count,
      name = "requesting",
  }

  for name,amount in Inventory.contents(self) do
    tbl.add(tubs.item_button(name, amount))
  end
end

return Inventory