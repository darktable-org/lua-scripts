--[[
  clear_GPS plugin library

  copyright (c) 2016 Bill Ferguson
]]

local dt = require "darktable"
local gettext = dt.gettext

libClearGPS = {}

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("clear_GPS",dt.configuration.config_dir.."/lua/")

local function _(msgid)
    return gettext.dgettext("clear_GPS", msgid)
end

--[[
  NAME
    libClearGPS.clear_GPS - clear GPS imformation from the selected images

  SYNOPSIS
    libClearGPS.clear_GPS(images)
      images - a table of images such as supplied by the exporter or by libPlugin.build_image_table

  DESCRIPTION
    clear_GPS resets the GPS information for the image to Not a Number (NaN), which clears it
    in the darktable database.

  RETURN VALUE
    none

  ERRORS



]]

function libClearGPS.clear_GPS(images)
  -- not a number
  local NaN = 0/0
  -- set the location data for each image to NaN to clear it
  for _, image in ipairs(images) do
    -- set the location information to Not a Number (NaN) so it displays correctly
    image.elevation = NaN
    image.latitude = NaN
    image.longitude = NaN
  end
end
