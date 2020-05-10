
local shared = require("shared")
local util = require("script/script_util")

local handler = require("event_handler")

local a = require("__NauvisPostalService__/script/van")
local b = require("__NauvisPostalService__/script/van")
print(a == b)

handler.add_lib(require("__NauvisPostalService__/script/van"))
handler.add_lib(require("script/depot_building_logic"))
-- handler.add_lib(require("script/depot_common"))
-- handler.add_lib(require("script/transport_drone"))
-- handler.add_lib(require("script/proxy_tile"))
-- handler.add_lib(require("script/blueprint_correction"))
-- handler.add_lib(require("script/transport_technologies"))
-- handler.add_lib(require("script/gui"))

-- require("script/remote_interface")
