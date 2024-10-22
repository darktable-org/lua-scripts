--[[
    This file is part of darktable,
    copyright (c) 2017 Tobias Jakobs

    darktable is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    darktable is distributed in the hope that it will be useful,
     but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with darktable.  If not, see <http://www.gnu.org/licenses/>.
]]
--[[

USAGE
* require this script from your main lua file
  To do this add this line to the file .config/darktable/luarc: 
require "running_os"

prints the operating system

]]
local dt = require "darktable"
local du = require "lib/dtutils"

du.check_min_api_version("5.0.0", "running_os") 

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

dt.print(string.format(_("you are running: %s"), dt.configuration.running_os))

-- set the destroy routine so that script_manager can call it when
-- it's time to destroy the script and then return the data to 
-- script_manager
local script_data = {}

script_data.metadata = {
  name = _("running OS"),
  purpose = _("example of how to determine the operating system being used"),
  author = "Tobias Jakobs",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/examples/running_os"
}

script_data.destroy = destroy

return script_data

--
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
