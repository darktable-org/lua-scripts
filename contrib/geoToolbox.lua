--[[
    This file is part of darktable,
    copyright (c) 2016 Tobias Jakobs

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
require "geoToolbox"

* it creates a new geoToolbox lighttable module
]]

local dt = require "darktable"
local df = require "lib/dtutils.file"
local gettext = dt.gettext

dt.configuration.check_version(...,{3,0,0},{4,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("geoToolbox",dt.configuration.config_dir.."/lua/")

local function _(msgid)
    return gettext.dgettext("geoToolbox", msgid)
end

-- <GUI>
local labelDistance = dt.new_widget("label")
labelDistance.label = "Distance:"

local labelCopyGPSlat = dt.new_widget("check_button")
{
  label = "latitude:", 
  value = true
}
local labelCopyGPSlon = dt.new_widget("check_button")
{
  label = "longitude:", 
  value = true
}
local labelCopyGPSele = dt.new_widget("check_button")
{
  label = "elevation:", 
  value = true
}
-- </GUI> 

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

-- This is used for older images in the DB
function isnan(x) return x ~= x end

-- Function from:
-- https://forums.coronalabs.com/topic/29019-convert-string-to-date/
-- This looks much scarier than it really is. The goal is to turn that string 
-- into a Unix timestamp (number of seconds since Jan 1, 1970, the standard 
-- used by most systems). So we use the string.match() method to fetch the 
-- various date and time parts into their own variables: xyear, xmonth,etc.
function makeTimeStamp(dateString)
  local convertedTimestamp
--dt.print_error(dateString)
  if (dateString) then
    local pattern = "(%d+)%:(%d+)%:(%d+) (%d+):(%d+):(%d+)"
    local xyear, xmonth, xday, xhour, xminute, xseconds = dateString:match(pattern)
--dt.print_error(xyear)
    convertedTimestamp = os.time({
        year = xyear, 
        month = xmonth, 
        day = xday, 
        hour = xhour, 
        min = xminute, 
        sec = xseconds})
  else
    convertedTimestamp = 0
  end

  return convertedTimestamp
end

local first_have_data = false
local first_latitude = ''
local first_longitude = ''
local first_elevation = ''
local first_image_date = 0

local function getFirstCoordinate()
  local sel_images = dt.gui.selection()

  first_latitude = ''    
  first_longitude = ''
  first_elevation = ''
  first_image_date = 0

  for _,image in ipairs(sel_images) do
    if not image then
      first_have_data = false
    else
      image_date = image.exif_datetime_taken
      first_have_data = true
      if (image.latitude) then
        first_latitude = image.latitude    
      end
      if (image.longitude) then
          first_longitude = image.longitude
      end
      if (image.elevation) then
          first_elevation = image.elevation
      end
      if (image.exif_datetime_taken) then
          first_image_date = makeTimeStamp(image.exif_datetime_taken)
--dt.print_error(image.exif_datetime_taken)
--dt.print_error(first_image_date)      
      end
    end
    return
  end
end

local second_have_data = false
local second_latitude = ''
local second_longitude = ''
local second_elevation = ''
local second_image_date = 0

local function getSecondCoordinate()
  local sel_images = dt.gui.selection()

  second_latitude = ''    
  second_longitude = ''
  second_elevation = ''
  second_image_date = 0

  for _,image in ipairs(sel_images) do
    if not image then
      second_have_data = false
    else
      image_date = image.exif_datetime_taken
      second_have_data = true
      if (image.latitude) then
        second_latitude = image.latitude    
      end
      if (image.longitude) then
          second_longitude = image.longitude
      end
      if (image.elevation) then
          second_elevation = image.elevation
      end
      if (image.exif_datetime_taken) then
          second_image_date = makeTimeStamp(image.exif_datetime_taken)
      end
    end
    return
  end
end

local calcInBetweenSlider = dt.new_widget("slider")
{
  label = "Position between", 
  soft_min = 0,      -- The soft minimum value for the slider, the slider can't go beyond this point
  soft_max = 100,     -- The soft maximum value for the slider, the slider can't go beyond this point
  hard_min = -100,       -- The hard minimum value for the slider, the user can't manually enter a value beyond this point
  hard_max = 200,    -- The hard maximum value for the slider, the user can't manually enter a value beyond this point
  value = 50          -- The current value of the slider
}

--ToDo: this needs more love
local function calcInBetween()
  local sel_images = dt.gui.selection()
  for _,image in ipairs(sel_images) do
    if image then
      image_date = makeTimeStamp(image.exif_datetime_taken)
      if (first_have_data and second_have_data) then
        local start_new      = 0
        local end_new        = second_image_date - first_image_date
        local image_date_new = image_date - first_image_date

        local percent_in_between
        if (end_new == 0) then
          percent_in_between = 1
        else
          percent_in_between = image_date_new/end_new
        end        
        calcInBetweenSlider.value = percent_in_between * 100
dt.print_error(percent_in_between)
        local in_between_latitude  = first_latitude + (second_latitude - first_latitude) * percent_in_between
        local in_between_longitude = first_longitude + (second_longitude - first_longitude) * percent_in_between

        if (first_elevation and second_elevation) then
          local in_between_elevation = first_elevation + (second_elevation - first_elevation) * percent_in_between

dt.print_error(first_image_date)
dt.print_error(second_image_date)
dt.print_error(image_date)
dt.print_error(first_elevation)
dt.print_error(second_elevation)
dt.print_error(in_between_elevation)

        end
      end
    end
  end
end

local copyGPS_have_data = false
local copyGPS_latitude = ''
local copyGPS_longitude = ''
local copyGPS_elevation = ''

local function copyGPS()
  local sel_images = dt.gui.selection()

  copyGPS_latitude = ''    
  copyGPS_longitude = ''
  copyGPS_elevation = ''

  for _,image in ipairs(sel_images) do
    if not image then
      copyGPS_have_data = false
    else
      copyGPS_have_data = true
      if (image.latitude and labelCopyGPSlat.value) then
        copyGPS_latitude = image.latitude    
      end
      if (image.longitude and labelCopyGPSlon.value) then
          copyGPS_longitude = image.longitude
      end
      if (image.elevation and labelCopyGPSele.value) then
          copyGPS_elevation = image.elevation
      end
    end

    labelCopyGPSlat.label = "latitude: " .. copyGPS_latitude
    labelCopyGPSlon.label = "longitude: " ..copyGPS_longitude
    labelCopyGPSele.label = "elevation: " .. copyGPS_elevation

    return
  end
end

local function pastGPS(image)
  local sel_images = dt.gui.selection()

  for _,image in ipairs(sel_images) do
    if (labelCopyGPSlat.value) then
      image.latitude = copyGPS_latitude
    end
    if (labelCopyGPSlon.value) then    
      image.longitude = copyGPS_longitude
    end
    if (labelCopyGPSele.value) then
      image.elevation = copyGPS_elevation
    end
  end
end

local function openLocationInGnomeMaps()

  if not df.check_if_bin_exists("gnome-maps") then
    dt.print_error(_("gnome-maps not found"))
    return
  end	
    
  local sel_images = dt.gui.selection()
  
  local lat1 = 0;
  local lon1 = 0;
  local i = 0;
  
  -- Use the first image with geo information
  for _,image in ipairs(sel_images) do
    if ((image.longitude and image.latitude) and 
        (image.longitude ~= 0 and image.latitude ~= 90) -- Sometimes the north-pole but most likely just wrong data
       ) then
        lat1 = image.latitude;
        lon1 = image.longitude;
        break
    end

    local startCommand
    startCommand = "gnome-maps \"geo:" .. lat1 .. "," .. lon1 .."\""
    dt.print_error(startCommand)
    
    if coroutine.yield("RUN_COMMAND", startCommand) then
      dt.print(_("Command failed ..."))
    end

  end

end


-- I used code from here:
-- http://stackoverflow.com/questions/27928/how-do-i-calculate-distance-between-two-latitude-longitude-points
local function getDistance(lat1, lon1, ele1, lat2, lon2, ele2)

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

    -- Add the elevation to the calculation
    local elevation = 0
    elevation = math.abs(ele1 - ele2) / 1000;  --in km

    if (elevation > 0) then
      distance = math.sqrt(math.pow(elevation,2) + math.pow(distance,2) )
    end
    return distance
end

local function calcDistance()

	local sel_images = dt.gui.selection()

    local lat1 = 0;
    local lon1 = 0;
    local lat2 = 0;
    local lon2 = 0;
    local ele1 = 0;
    local ele2 = 0;
    local i = 0;

    local sel_images = dt.gui.selection()

    for _,image in ipairs(sel_images) do
      if ((image.longitude and image.latitude) and
            (image.longitude ~= 0 and image.latitude ~= 90) -- Sometimes the north-pole but most likely just wrong data
           ) then
          
        i = i + 1;
          
        if (i == 1) then
          lat1 = image.latitude
          lon1 = image.longitude
          if (image.elevation) then
            ele1 = image.elevation
          else
            ele1 = 0
          end
        end
         
        lat2 = image.latitude
        lon2 = image.longitude
        if (image.elevation) then
          ele2 = image.elevation
        else
          ele2 = 0;
        end

      end
    end

    local distance = getDistance(lat1, lon1, ele1, lat2, lon2, ele2)

    if (distance < 1) then
        distance = distance * 1000
        distanceUnit = "m"
    else
        distanceUnit = "km"
    end
    
    return string.format("Distance: %.2f %s", distance, distanceUnit)
end

local function printCalcDistance()
    dt.print(calcDistance())
end

local function toolboxCalcDistance()
    labelDistance.label = calcDistance()
end

local altitude_file_chooser_button = dt.new_widget("file_chooser_button")
  {
    title = "export altitude CSV",  -- The title of the window when choosing a file
    value = "",                     -- The currently selected file
    is_directory = true             -- True if the file chooser button only allows directories to be selecte
  }
local altitude_filename = dt.new_widget("entry")
  {
    text = "altitude.csv", 
    placeholder = "altitude.csv",
    editable = true,
    tooltip = "Name of the exported file",
    reset_callback = function(self) self.text = "text" end
  }

local function altitudeProfile()
	  dt.print("Start export")
    local sel_images = dt.gui.selection()

    local lat1 = 0;
    local lon1 = 0;
    local lat2 = 0;
    local lon2 = 0;
    local ele1 = 0;
    local ele2 = 0;
    local i = 0;
    local csv_file = '';
    csv_file = "km;m".."\n";

    local distance = 0;
    local distanceFromStart = 0;
    local elevation = 0;
    local elevationAdd = 0;

    local sel_images = dt.gui.selection()
    for _,image in ipairs(sel_images) do
      if ((not isnan(image.longitude) and not isnan(image.latitude) and not isnan(image.elevation) and image.elevation) and 
            (image.longitude ~= 0 and image.latitude ~= 90) -- Sometimes the north-pole but most likely just wrong data
           ) then
          
        i = i + 1;
          
        if (i == 1) then
          lat1 = image.latitude
          lon1 = image.longitude
          ele1 = image.elevation
        else
          lat1 = lat2
          lon1 = lon2
          ele1 = ele2
        end
         
        lat2 = image.latitude
        lon2 = image.longitude
        ele2 = image.elevation

        if (i == 1) then
          distanceFromStart = 0
        else
          local distance = getDistance(lat1, lon1, ele1, lat2, lon2, ele2)
          distanceFromStart = distanceFromStart + distance;
        end

        csv_file = csv_file .. distanceFromStart..";"..image.elevation.."\n";

      end

    end --for

    local exportDirectory = altitude_file_chooser_button.value
    local exportFilename = altitude_filename.text
    if (exportFilename == '') then
      exportFilename = altitude_filename.placeholder
    end
    file = io.open(exportDirectory.."/"..exportFilename, "w")
    file:write(csv_file)
    file:close()
    dt.print("File created in "..exportDirectory)

end


local separator = dt.new_widget("separator"){}
local separator2 = dt.new_widget("separator"){}
local separator3 = dt.new_widget("separator"){}
local separator4 = dt.new_widget("separator"){}

dt.register_lib(
  "geoToolbox",        -- Module name
  "geo toolbox",       -- name
  true,                -- expandable
  false,               -- resetable
  {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},   -- containers
  dt.new_widget("box")
  {
    orientation = "vertical",
    dt.new_widget("button")
    {
      label = "select geo images",
      tooltip = "Select all images with GPS information",
      clicked_callback = selectWithGPS
    },
    dt.new_widget("button")
    {
      label = "select not geo images",
      tooltip = "Select all images without GPS information",
      clicked_callback = selectWithoutGPS
    },
    separator,--------------------------------------------------------
    dt.new_widget("button")
    {
      label = "copy GPS data",
      tooltip = "Copy the GPS data",
      clicked_callback = copyGPS
    },
    labelCopyGPSlat,
    labelCopyGPSlon,
    labelCopyGPSele,
    dt.new_widget("button")
    {
      label = "past GPS data",
      tooltip = "Past the GPS data",
      clicked_callback = pastGPS
    },
    separator2,--------------------------------------------------------
--ToDo: This need a better UI
--[[
    dt.new_widget("button")
    {
      label = "get 1st coordinate",
      tooltip = "Select first image and click this button",
      clicked_callback = getFirstCoordinate
    },
    dt.new_widget("button")
    {
      label = "get 2nd coordinate",
      tooltip = "Select second image and click this button",
      clicked_callback = getSecondCoordinate
    },
    dt.new_widget("button")
    {
      label = "calc in between",
      tooltip = "Select third image and click this button",
      clicked_callback = calcInBetween
    },
    calcInBetweenSlider,
    separator3,--------------------------------------------------------
]]    
    dt.new_widget("button")
    {
      label = "Open in Gnome Maps",
      tooltip = "Open Location in Gnome Maps",
      clicked_callback = openLocationInGnomeMaps
    },
    separator4,--------------------------------------------------------
    dt.new_widget("label"){label = "altitude CSV export"},
    altitude_file_chooser_button,
    altitude_filename,
    dt.new_widget("button")
    {
      label = "export altitude CSV file",
      tooltip = "create an altitude profile using the GPS data in the metadata",
      clicked_callback = altitudeProfile
    },
    labelDistance
  },
  nil,-- view_enter
  nil -- view_leave
)


-- Register
dt.register_event("shortcut",printCalcDistance,_("Calculate the distance from latitude and longitude in km"))
dt.register_event("mouse-over-image-changed",toolboxCalcDistance)

dt.register_event("shortcut", selectWithGPS, _("Select all images with GPS information"))
dt.register_event("shortcut", selectWithoutGPS, _("Select all images without GPS information"))

-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: hl Lua;
