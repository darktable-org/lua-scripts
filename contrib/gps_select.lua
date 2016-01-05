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
darktable select images with or without GPS informations

USAGE
* require this script from your main lua file
* register a shortcuts
]]
   
local dt = require "darktable"
dt.configuration.check_version(...,{2,0,1},{3,0,0})
table = require "table"

local function selectWithGPS()
   local selection = {}
   for _,image in ipairs(dt.database) do
      if (image.longitude and image.latitude) then
         table.insert(selection,image)
      end
   end
   dt.gui.selection(selection)
end

local function selectWithoutGPS()
   local selection = {}
   for _,image in ipairs(dt.database) do
      if (not image.longitude and not image.latitude) then
         table.insert(selection,image)
      end
   end
   dt.gui.selection(selection)
end

dt.register_event("shortcut", selectWithGPS, "Select all images with GPS information")
dt.register_event("shortcut", selectWithoutGPS, "Select all images without GPS information")
