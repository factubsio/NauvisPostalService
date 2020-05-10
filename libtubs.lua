
local lib = {}


lib.elem_button = function(name, amount)
  local icon = nil
  if name then
    icon = lib.get_item_icon_and_locale(name).icon
  end
  return {
      type = "choose-elem-button",
      elem_type = "item",
      sprite = icon,
      number = amount,
      style = "slot_button",
      item = name,
      tooltip = amount,
  }
end

lib.item_button = function(name, amount, style)
    local icon = nil
    if name then
      icon = lib.get_item_icon_and_locale(name).icon
    end
    return {
        type = "sprite-button",
        sprite = icon,
        number = amount,
        style = style or "slot_button",
        name = name,
        tooltip = amount,
    }
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

lib.get_frame = function(tick, anim_def)
  return math.floor((tick * anim_def.speed) % anim_def.frames)
end

lib.set_frame = function(tick, frame, anim_def, anim)
  rendering.set_animation_speed(anim, anim_def.speed)
  if anim_def.speed == 0 then
    rendering.set_animation_offset(anim, frame)
  else
    local current_frame = lib.get_frame(tick, anim_def)
    rendering.set_animation_offset(anim, frame - current_frame)
  end
end


return lib