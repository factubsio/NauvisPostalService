for _,prototype in pairs(data.raw["assembling-machine"]) do
    local arr = prototype.additional_pastable_entities
    if arr then
        arr[#arr+1] = "tubs-ups-loading-dock"
    else
        prototype.additional_pastable_entities = {"tubs-ups-loading-dock"}
    end
end