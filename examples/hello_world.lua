--[[
    This file is part of darktable,
    copyright (c) 2014 Tobias Ellinghaus

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
HELLO WORLD
prints "hello world when DT starts


USAGE
* require this file from your main lua config file:


]]
local dt = require "darktable"
local du = require "lib/dtutils"

-- translation facilities

du.check_min_api_version("2.0.0", "hello_world") 

local gettext = dt.gettext.gettext

local function _(msg)
  return gettext(msg)
end

-- script_manager integration to allow a script to be removed
-- without restarting darktable
local function destroy()
    -- nothing to destroy
end

dt.print(_("hello, world"))

-- set the destroy routine so that script_manager can call it when
-- it's time to destroy the script and then return the data to 
-- script_manager
local script_data = {}

script_data.metadata = {
  name = _("hello world"),
  purpose = _("example of how to print a message to the screen"),
  author = "Tobias Ellinghaus",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/examples/hello_world"
}

script_data.destroy = destroy

return script_data
--
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
