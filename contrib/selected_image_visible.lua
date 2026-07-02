--[[

    selected_image_visible.lua - make the selected image visible in lighttable

    Copyright (C) 2026 Bill Ferguson <wpferguson@gmail.com>.

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]
--[[
    selected_image_visible - make the selected image visible in lighttable

    selected_image_visible adds a bshortcut to make the currently
    selected image or the first image of a selection visible in lighttable

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    None

    USAGE
    * enable the script in script_manager

    BUGS, COMMENTS, SUGGESTIONS
    Bill Ferguson <wpferguson@gmail.com>

    CHANGES
]]

local dt = require "darktable"
local du = require "lib/dtutils"
-- local df = require "lib/dtutils.file"
-- local ds = require "lib/dtutils.string"
-- local dtsys = require "lib/dtutils.system"
local log = require "lib/dtutils.log"
-- local debug = require "darktable.debug"


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A P I  C H E C K
-- - - - - - - - - - - - - - - - - - - - - - - - 

du.check_min_api_version("9.6.0", MODULE)   -- choose the minimum version that contains the features you need


-- - - - - - - - - - - - - - - - - - - - - - - - - -
-- I 1 8 N
-- - - - - - - - - - - - - - - - - - - - - - - - - -

local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end


-- - - - - - - - - - - - - - - - - - - - - - - - - -
-- S C R I P T  M A N A G E R  I N T E G R A T I O N
-- - - - - - - - - - - - - - - - - - - - - - - - - -

local script_data = {}

script_data.destroy = nil           -- function to destory the script
script_data.destroy_method = nil    -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil           -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil              -- only required for libs since the destroy_method only hides them

script_data.metadata = {
  name = _("selected image visible"),         -- visible name of script
  purpose = _("make the selected image visible in lighttable"),   -- purpose of script
  author = "Bill Ferguson <wpferguson@gmail.com>",   -- your name and optionally e-mail address
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/selected_image_visible/" -- URL to help/documentation
}


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local MODULE <const> = "selected_image_visible"
local DEFAULT_LOG_LEVEL <const> = log.info
local TMP_DIR <const> = dt.configuration.tmp_dir

-- path separator
local PS <const> = dt.configuration.running_os == "windows" and "\\" or "/"

-- command separator
local CS <const> = dt.configuration.running_os == "windows" and "&" or ";"

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- L O G  L E V E L
-- - - - - - - - - - - - - - - - - - - - - - - - 

log.log_level(DEFAULT_LOG_LEVEL)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- N A M E  S P A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

local selected_image_visible = {}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- G L O B A L  V A R I A B L E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

selected_image_visible.log_level = DEFAULT_LOG_LEVEL

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- P R E F E R E N C E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A L I A S E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local namespace = selected_image_visible

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function set_image_visible()
  if dt.gui.current_view().name == "lighttable" and #dt.gui.action_images > 0 then
    dt.gui.views.lighttable.set_image_visible(dt.gui.action_images[1])
  end
end

local function set_button_sensitive()
  if dt.gui.current_view().name == "lighttable" 
    and #dt.gui.selection() > 0 
    and not dt.gui.views.lighttable.is_image_visible(dt.gui.selection()[1]) then
    dt.gui.libs.image.set_sensitive(MODULE, true)
  else
    dt.gui.libs.image.set_sensitive(MODULE, false)
  end
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- M A I N  P R O G R A M
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- U S E R  I N T E R F A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.gui.libs.image.register_action(
  MODULE, _("selected image visible"),
  function(event, images) set_image_visible() end,
  _("make selected image visible in lighttable")
)

set_button_sensitive()

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- D A R K T A B L E  I N T E G R A T I O N 
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function destroy()
  -- put things to destroy (events, storages, etc) here
  dt.destroy_event(MODULE, "selection-changed")
  dt.destroy_event(MODULE, "mouse-over-image-changed")
  dt.gui.libs.image.destroy_action(MODULE)
end

script_data.destroy = destroy

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- E V E N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

if not dt.query_event(MODULE, "shortcut") then
  dt.register_event(MODULE, "shortcut",
    function(event, shortcut)
      set_image_visible()
    end, _("make selected image visible in lighttable")
  )
end

dt.register_event(MODULE, "selection-changed",
  function(event)
    set_button_sensitive()
  end
)

dt.register_event(MODULE, "mouse-over-image-changed",
  function(event, image)
    set_button_sensitive()
  end
)

return script_data
