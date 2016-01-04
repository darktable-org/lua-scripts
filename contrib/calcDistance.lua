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
darktable calc distance script

This script calcs the distance between two images using the GPS data in the metadata

USAGE
* require this script from your main lua file
* register a shortcut
]]
   
local dt = require "darktable"
dt.configuration.check_version(...,{2,0,1},{3,0,0})

local function calcDistance()
	local sel_images = dt.gui.selection()

    local lat1 = 0;
    local lon1 = 0;
    local lat2 = 0;
    local lon2 = 0;
    local i = 0;

    local sel_images = dt.gui.selection()

    for _,image in ipairs(sel_images) do
	if ((image.longitude and image.latitude) and 
            (image.longitude ~= 0 and image.latitude ~= 90) -- Sometimes the north-pole but most likely just wrong data
           ) then
          
          i = i + 1;
          
          if (i == 1) then
            lat1 = image.latitude;
            lon1 = image.longitude;
          end
         
         lat2 = image.latitude;
         lon2 = image.longitude;

        end
    end

-- I used code from here:
-- http://stackoverflow.com/questions/27928/how-do-i-calculate-distance-between-two-latitude-longitude-points

    local earthRadius = 6371; -- Radius of the earth in km
    local dLat = math.rad(lat2-lat1);  -- deg2rad below
    local dLon = math.rad(lon2-lon1); 
    local a = 
      math.sin(dLat/2) * math.sin(dLat/2) +
      math.cos(math.rad(lat1)) * math.cos(math.rad(lat2)) * 
      math.sin(dLon/2) * math.sin(dLon/2)
      ; 
    local angle = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a)); 
    local distance = earthRadius * angle; -- Distance in km  

    dt.print(distance.." km")


end

-- Register
dt.register_event("shortcut",calcDistance,"Calculate the distance from latitude and longitude in km")
