local max_integer = 4294967295

local slider_mapping = {
    slider_to_textfield = {
      [0] = 0,
      [1] = 1,
      [2] = 2,
      [3] = 3,
      [4] = 4,
      [5] = 5,
      [6] = 6,
      [7] = 7,
      [8] = 8,
      [9] = 9,
      [10] = 10,
      [11] = 20,
      [12] = 30,
      [13] = 40,
      [14] = 50,
      [15] = 60,
      [16] = 70,
      [17] = 80,
      [18] = 90,
      [19] = 100,
      [20] = 200,
      [21] = 300,
      [22] = 400,
      [23] = 500,
      [24] = 600,
      [25] = 700,
      [26] = 800,
      [27] = 900,
      [28] = 1000,
      [29] = 2000,
      [30] = 3000,
      [31] = 4000,
      [32] = 5000,
      [33] = 6000,
      [34] = 7000,
      [35] = 8000,
      [36] = 9000,
      [37] = 10000,
      [38] = max_integer
    },
    textfield_to_slider = {
      [0] = 0,
      [1] = 1,
      [2] = 2,
      [3] = 3,
      [4] = 4,
      [5] = 5,
      [6] = 6,
      [7] = 7,
      [8] = 8,
      [9] = 9,
      [10] = 10,
      [20] = 11,
      [30] = 12,
      [40] = 13,
      [50] = 14,
      [60] = 15,
      [70] = 16,
      [80] = 17,
      [90] = 18,
      [100] = 19,
      [200] = 20,
      [300] = 21,
      [400] = 22,
      [500] = 23,
      [600] = 24,
      [700] = 25,
      [800] = 26,
      [900] = 27,
      [1000] = 28,
      [2000] = 29,
      [3000] = 30,
      [4000] = 31,
      [5000] = 32,
      [6000] = 33,
      [7000] = 34,
      [8000] = 35,
      [9000] = 36,
      [10000] = 37,
      [max_integer] = 38
    },

    translate_to_slider = function(value)
      if value == nil or value == 0 then return 0 end
      if value == 10000 then return 37 end
      local bucket = math.floor(math.log10(value))
      if bucket > 3 then return 38 end
      local divisor = math.pow(10, bucket)
      local bucket_bases = {[0] = 0, [1] = 10, [2] = 19, [3] = 28}
      return bucket_bases[bucket] + math.floor(value / divisor) - 1
    end


}
return slider_mapping