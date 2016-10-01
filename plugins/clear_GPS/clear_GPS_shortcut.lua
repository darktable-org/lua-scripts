--[[
  clear_GPS plugin register event

  copyright (c) 2016 Bill Ferguson

]]

local dt = require "darktable"
require "plugins/clear_GPS/lib/libClearGPS"

dt.register_event(
  "shortcut",
  function(event, shortcut) libClearGPS.clear_GPS(dt.gui.action_images) end,
  "clear GPS data"
)
