--[[
    This file is part of darktable,
    Copyright 2014 by Tobias Jakobs.

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
darktable script to show the Lua API version in the preferences

USAGE
* require this script from your main lua file
]] 
local dt = require "darktable"

-- translation facilities

local gettext = dt.gettext.gettext

local function _(msg)
  return gettext(msg)
end

-- script_manager integration to allow a script to be removed
-- without restarting darktable
local function destroy()
    -- nothing to destroy
end

local result = dt.configuration.api_version_string
dt.print_log("API Version: " .. result)
dt.print("API " .. _("version") .. ": " .. result)

-- set the destroy routine so that script_manager can call it when
-- it's time to destroy the script and then return the data to 
-- script_manager
local script_data = {}

script_data.metadata = {
  name = _("APIversion"),
  purpose = _("display api_version example"),
  author = "Tobias Jakobs",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/examples/api_version"
}

script_data.destroy = destroy

return script_data
