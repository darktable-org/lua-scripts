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
Print Examples
prints "hello world when DT starts
USAGE
* require this file from your main lua config file:
]]
local dt = require "darktable"
local du = require "lib/dtutils"

du.check_min_api_version("5.0.0", "printExamples") 

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

-- Will print a string to the darktable control log (the long
-- overlayed window that appears over the main panel).
dt.print(_("print"))

-- This function will print its parameter if the Lua logdomain is
-- activated. Start darktable with the "-d lua" command line option
-- to enable the Lua logdomain.
dt.print_error("print error")

-- This function will print its parameter if the Lua logdomain is
-- activated. Start darktable with the "-d lua" command line option
-- to enable the Lua logdomain.
dt.print_log("print log")

-- set the destroy routine so that script_manager can call it when
-- it's time to destroy the script and then return the data to 
-- script_manager
local script_data = {}

script_data.metadata = {
  name = _("print examples"),
  purpose = _("example showing the different types of printing messages"),
  author = "Tobias Jakobs",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/examples/printExamples"
}

script_data.destroy = destroy

return script_data
--
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
