--[[
    This file is part of darktable,
    copyright (c) 2014--2018 Tobias Ellinghaus

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
DELETE LONG TAGS
A simple script that will automatically delete all tags longer than a set length

USAGE
* require this script from your main lua file
* set the the maximum length in darktable's preference
* restart darktable

all tags longer than the given length will be automatically deleted at every restart

]]

local dt = require "darktable"
local du = require "lib/dtutils"

du.check_min_api_version("2.0.0", "delete_long_tags") 

local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("delete long tags"),
  purpose = _("delete all tags longer than a set length"),
  author = "Tobias Ellinghaus",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/official/delete_long_tags"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

dt.preferences.register("delete_long_tags", "length", "integer",
                        "maximum length of tags to keep",
                        "tags longer than this get deleted on start",
                        666, 0, 65536)

local function destroy()
  -- noting to destroy
end

local max_length = dt.preferences.read("delete_long_tags", "length", "integer")

-- deleting while iterating the tags list seems to break the iterator!
local long_tags = {}

for _,t in ipairs(dt.tags) do
  local len = #t.name
  if len > max_length then
    dt.print_log("deleting tag `"..t.name.."' (length: "..len..")")
    table.insert(long_tags, t.name)
  end
end

for _,name in pairs(long_tags) do
  tag = dt.tags.find(name)
  tag:delete()
end

script_data.destroy = destroy

return script_data
