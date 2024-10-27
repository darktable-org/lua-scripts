--[[

    clear_GPS.lua - plugin for Darktable

    Copyright (C) 2016 Bill Ferguson <wpferguson@gmail.com>.

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
    clear_GPS - clear GPS data from selected image(s)

    This shortcut removes the GPS coordinate data from the selected images.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    * None

    USAGE
    * require this script from your main lua file
    * select an image or images
    * click the shortcut, clear GPS data

    BUGS, COMMENTS, SUGGESTIONS
    * Send to Bill Ferguson, wpferguson@gmail.com

    CHANGES
]]

local dt = require "darktable"
local du = require "lib/dtutils"

local gettext = dt.gettext.gettext 

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("clear GPS info"),
  purpose = _("remove GPS data from selected image(s)"),
  author = "Bill Ferguson <wpferguson@gmail.com>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/clear_gps/"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

-- not a number
local NaN = 0/0

du.check_min_api_version("7.0.0", "clear_GPS") 

local function clear_GPS(images)
  for _, image in ipairs(images) do
    -- set the location information to Not a Number (NaN) so it displays correctly
    image.elevation = NaN
    image.latitude = NaN
    image.longitude = NaN
  end
end

local function destroy()
  dt.destroy_event("clear_GPS", "shortcut")
  dt.gui.libs.image.destroy_action("clear_GPS")
end

script_data.destroy = destroy

dt.gui.libs.image.register_action(
  "clear_GPS", _("clear GPS data"),
  function(event, images) clear_GPS(images) end,
  _("clear GPS data from selected images")
)

dt.register_event(
  "clear_GPS", "shortcut",
  function(event, shortcut) clear_GPS(dt.gui.action_images) end,
  _("clear GPS data from selected images")
)

return script_data
