local dt = require "darktable"
local gettext = dt.gettext

libClearGPS = {}

dt.configuration.check_version(...,{3,0,0})


-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("clear_GPS",dt.configuration.config_dir.."/lua/")

local function _(msgid)
    return gettext.dgettext("clear_GPS", msgid)
end

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
