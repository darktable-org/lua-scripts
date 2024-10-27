--[[

    auto_snapshot.lua - automatically take a snapshot when an image is loaded in darkroom

    Copyright (C) 2024 Bill Ferguson <wpferguson@gamil.com>.

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
    auto_snapshot - 

    automatically take a snapshot when an image is loaded in darkroom

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    None

    USAGE
    * start the script from script_manager
    * open an image in darkroom

    BUGS, COMMENTS, SUGGESTIONS
    Bill Ferguson <wpferguson@gamil.com>

    CHANGES
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local log = require "lib/dtutils.log"

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local MODULE <const> = "auto_snapshot"
local DEFAULT_LOG_LEVEL <const> = log.error

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A P I  C H E C K
-- - - - - - - - - - - - - - - - - - - - - - - - 

du.check_min_api_version("7.0.0", MODULE)   -- choose the minimum version that contains the features you need


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
  name = _("auto snapshot"),            -- name of script
  purpose = _("automatically take a snapshot when an image is loaded in darkroom"),   -- purpose of script
  author = "Bill Ferguson <wpferguson@gamil.com>",          -- your name and optionally e-mail address
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/auto_snapshot/"                   -- URL to help/documentation
}


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- L O G  L E V E L
-- - - - - - - - - - - - - - - - - - - - - - - - 

log.log_level(DEFAULT_LOG_LEVEL)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- N A M E  S P A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

local auto_snapshot = {}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- P R E F E R E N C E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.preferences.register(MODULE, "always_create_snapshot", "bool", "auto_snapshot - " .. _("always automatically create_snapshot"), 
    _("create a snapshot even if the image is altered"), false)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- D A R K T A B L E  I N T E G R A T I O N 
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function destroy()
  dt.destroy_event(MODULE, "darkroom-image-loaded")
end

script_data.destroy = destroy

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- E V E N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.register_event(MODULE, "darkroom-image-loaded",
  function(event, clean, image)
    local always = dt.preferences.read(MODULE, "always_create_snapshot", "bool")
    if clean and always then
      dt.gui.libs.snapshots.take_snapshot()
    elseif clean and not image.is_altered then
      dt.gui.libs.snapshots.take_snapshot()
    end

  end 
)


return script_data