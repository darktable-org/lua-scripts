--[[
    This file is part of darktable,
    copyright (c) 2018 Tobias Ellinghaus

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
DELETE UNUSED TAGS
A simple script that will automatically delete all tags that are not attached to any images

USAGE
* require this script from your main lua file
* restart darktable

all tags that are not used will be automatically deleted at every restart
]]

local dt = require "darktable"
local du = require "lib/dtutils"

du.check_min_api_version("5.0.0", "delete_unused_tags") 

local script_data = {}

local function destroy()
  -- noting to destroy
end

local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("delete unused tags"),
  purpose = _("delete unused tags"),
  author = "Tobias Ellinghaus",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/official/delete_unused_tags"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

-- deleting while iterating the tags list seems to break the iterator!
local unused_tags = {}

for _, t in ipairs(dt.tags) do
  if #t == 0 then
    table.insert(unused_tags, t.name)
  end
end

for _,name in pairs(unused_tags) do
  dt.print_log("deleting tag `" .. name .. "'")
  tag = dt.tags.find(name)
  tag:delete()
end

script_data.destroy = destroy
return script_data