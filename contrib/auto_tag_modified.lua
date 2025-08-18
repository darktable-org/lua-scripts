--[[

    auto_tag_modified.lua - automatically tag an image when it has been manually modified in darkroom

    Copyright (C) 2025 Michael Reiger <michael@rauschpfeife.net>, modeled after auto_snapshot.lua by Bill Ferguson <wpferguson@gamil.com>.

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
    auto_tag_modified -

    automatically tag an image when it has been manually modified in the darkroom, that is if its history has changed at the time it is closed from the darkroom.
    (This will not catch applying styles from the light table though.)

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    None

    USAGE
    * start the script from script_manager
    * open an image in darkroom, and close it after making an operation that changes the history

    BUGS, COMMENTS, SUGGESTIONS
    Michael Reiger <michael@rauschpfeife.net>

    CHANGES
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local log = require "lib/dtutils.log"

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local MODULE <const> = "auto_tag_modified"
local DEFAULT_TAG_NAME <const> = "darktable manually modified"
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
  name = _("auto tag modified"),            -- name of script
  purpose = _("automatically tag an image when it has been manually modified in darkroom"),   -- purpose of script
  author = "Michael Reiger <michael@rauschpfeife.net>",          -- your name and optionally e-mail address
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/auto_tag_modified/"                   -- URL to help/documentation
}


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- L O G  L E V E L
-- - - - - - - - - - - - - - - - - - - - - - - - 

log.log_level(DEFAULT_LOG_LEVEL)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- N A M E  S P A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

local auto_tag_modified = {}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- P R E F E R E N C E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.preferences.register(MODULE, "auto_modified_tag_name", "string", "auto_tag_modified - " .. _("tag name to use for auto tagging modified images"),
    _("tag name to use for auto tagging modified images"), DEFAULT_TAG_NAME)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- D A R K T A B L E  I N T E G R A T I O N 
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function destroy()
  dt.destroy_event(MODULE, "darkroom-image-history-changed")
end

script_data.destroy = destroy

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- E V E N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.register_event(MODULE, "darkroom-image-history-changed",
  function(event, image)
    local tag_name = dt.preferences.read(MODULE, "auto_modified_tag_name", "string")
    local tag = dt.tags.create(tag_name)
    dt.tags.attach(tag, image)
  end
)

return script_data
