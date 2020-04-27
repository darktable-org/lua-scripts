--[[
german_umlauts script for darktable
]]

--[[About this plugin
This plugin adds the module "german_umlauts" to darktable's lighttable view.
]]

local dt = require "darktable"
local gettext = dt.gettext

gettext.bindtextdomain("german_umlauts",dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
    return gettext.dgettext("german_umlauts", msgid)
end

-- GUI --
dt.gui.libs.image.register_action(
  _("German Umlauts"),
  function() dt.print(_("Sentence with German umlauts")) end,
  _("Print a sentence with German umlauts")
  )
