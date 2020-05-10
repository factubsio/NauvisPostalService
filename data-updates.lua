for _,prototype in pairs(data.raw["assembling-machine"]) do
    local arr = prototype.additional_pastable_entities
    if arr then
        arr[#arr+1] = "tubs-nps-loading-dock"
    else
        prototype.additional_pastable_entities = {"tubs-nps-loading-dock"}
    end
end