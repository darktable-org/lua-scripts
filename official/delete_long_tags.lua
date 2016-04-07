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
DELETE LONG TAGS
A simple script that will automatically delete all tag longer than a set length

USAGE
* require this script from your main lua file
* set the the maximum length in darktable's preference
* restart darktable

all tags longer than the given length will be automatically deleted at every restart

]]

local dt = require "darktable"
dt.configuration.check_version(...,{2,0,0},{3,0,0})

dt.preferences.register("delete_long_tags", "length", "integer",
                        "maximum length of tags to keep",
                        "tags longer than this get deleted on start",
                        666, 0, 65536)

local max_length = dt.preferences.read("delete_long_tags", "length", "integer")

for _,t in ipairs(dt.tags) do
  local len = #t.name
  if len > max_length then
    print("deleting tag `"..t.name.."' (length: "..len..")")
    t:delete()
  end
end
