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
darktable script to open a geo uri in gnome-maps

ADDITIANAL SOFTWARE NEEDED FOR THIS SCRIPT
* gnome-maps >= 3.20

WARNING
This script is not testet.

USAGE
* require this script from your main lua file
* register a shortcut
]]

local dt = require "darktable"
dt.configuration.check_version(...,{2,0,1})

local function checkIfBinExists(bin)
  local handle = io.popen("which "..bin)
  local result = handle:read()
  local ret
  handle:close()
  if (not result) then
    dt.print_error(bin.." not found")
    ret = false
  end
  ret = true
  return ret
end

local function openLocationInGnomeMaps()
  if not checkIfBinExists("gnome-maps") then
    darktable.print_error("gnome-maps not found")
    return
  end	
    
  local sel_images = dt.gui.selection()
  
  local lat1 = 0;
  local lon1 = 0;
  local i = 0;
  
  local sel_images = dt.gui.selection()
  
  -- Use the first image with geo information
  for _,image in ipairs(sel_images) do
    if ((image.longitude and image.latitude) and 
        (image.longitude ~= 0 and image.latitude ~= 90) -- Sometimes the north-pole but most likely just wrong data
       ) then
        
        i = i + 1;
        
        if (i == 1) then
          lat1 = image.latitude;
          lon1 = image.longitude;
        end
  
      end
    end

    if (lat1 and lon1) then
      local startCommand
      startCommand = "gnome-maps \"geo:" .. lat1 .. "," .. lon1 .."\""
      dt.print_error(startCommand)
    
      if coroutine.yield("RUN_COMMAND", startCommand) then
        dt.print("Command failed ...")
      end
    end
  
  end
end

-- Register
dt.register_event("shortcut", openLocationInGnomeMaps, "Open Location in Gnome Maps")
