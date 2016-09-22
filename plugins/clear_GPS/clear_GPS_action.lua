local dt = require "darktable"
require "plugins/clear_GPS/lib/libClearGPS"
local gettext = dt.gettext

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("clear_GPS",dt.configuration.config_dir.."/lua/")

local function _(msgid)
    return gettext.dgettext("clear_GPS", msgid)
end

dt.gui.libs.image.register_action(
  _("clear GPS data"),
  function(event, images) libClearGPS.clear_GPS(images) end,
  "clear GPS data"
)
