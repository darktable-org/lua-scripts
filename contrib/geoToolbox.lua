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
labelDistance.label = _("Distance:")

local label_copy_gps_lat = dt.new_widget("check_button")
{
  label = _("latitude:"), 
  value = true
}
local label_copy_gps_lon = dt.new_widget("check_button")
{
  label = _("longitude:"), 
  value = true
}
local label_copy_gps_ele = dt.new_widget("check_button")
{
  label = _("elevation:"), 
  value = true
}
-- </GUI> 

local function select_with_gps()
  local selection = {}
  job = dt.gui.create_job(_("GPS selection"), true, stop_selection)

  for key,image in ipairs(dt.collection) do
    if job.valid then
      job.percent = (key-1)/#dt.collection

      if (image.longitude and image.latitude) then
        table.insert(selection,image)
      end
    else
      break
    end
  end

  dt.gui.selection(selection)
  job.valid = false
end

local function select_without_gps()
  local selection = {}
  job = dt.gui.create_job(_("GPS selection"), true, stop_selection)

  for key,image in ipairs(dt.collection) do
    if job.valid then
      job.percent = (key-1)/#dt.collection

      if (not image.longitude and not image.latitude) then
        table.insert(selection,image)
      end
    else
      break
    end
  end
  dt.gui.selection(selection)
  job.valid = false
end

local function stop_selection(job)
    job.valid = false
end

-- This is used for older images in the DB
function isnan(x) return x ~= x end

-- Function from:
-- https://forums.coronalabs.com/topic/29019-convert-string-to-date/
-- This looks much scarier than it really is. The goal is to turn that string 
-- into a Unix timestamp (number of seconds since Jan 1, 1970, the standard 
-- used by most systems). So we use the string.match() method to fetch the 
-- various date and time parts into their own variables: xyear, xmonth,etc.
function make_time_stamp(dateString)
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

local function get_first_coordinate()
  local sel_images = dt.gui.action_images

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
          first_image_date = make_time_stamp(image.exif_datetime_taken)
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

local function get_second_coordinate()
  local sel_images = dt.gui.action_images

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
          second_image_date = make_time_stamp(image.exif_datetime_taken)
      end
    end
    return
  end
end

local calc_in_between_slider = dt.new_widget("slider")
{
  label = "Position between", 
  soft_min = 0,      -- The soft minimum value for the slider, the slider can't go beyond this point
  soft_max = 100,     -- The soft maximum value for the slider, the slider can't go beyond this point
  hard_min = -100,       -- The hard minimum value for the slider, the user can't manually enter a value beyond this point
  hard_max = 200,    -- The hard maximum value for the slider, the user can't manually enter a value beyond this point
  value = 50          -- The current value of the slider
}

--ToDo: this needs more love
local function calc_in_between()
  local sel_images = dt.gui.action_images
  for _,image in ipairs(sel_images) do
    if image then
      image_date = make_time_stamp(image.exif_datetime_taken)
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
        calc_in_between_slider.value = percent_in_between * 100
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

local copy_gps_have_data = false
local copy_gps_latitude = ''
local copy_gps_longitude = ''
local copy_gps_elevation = ''

local function copy_gps()
  local sel_images = dt.gui.action_images

  copy_gps_latitude = ''    
  copy_gps_longitude = ''
  copy_gps_elevation = ''

  for _,image in ipairs(sel_images) do
    if not image then
      copy_gps_have_data = false
    else
      copy_gps_have_data = true
      if (image.latitude and label_copy_gps_lat.value) then
        copy_gps_latitude = image.latitude    
      end
      if (image.longitude and label_copy_gps_lon.value) then
          copy_gps_longitude = image.longitude
      end
      if (image.elevation and label_copy_gps_ele.value) then
          copy_gps_elevation = image.elevation
      end
    end

    label_copy_gps_lat.label = _("latitude: ") .. copy_gps_latitude
    label_copy_gps_lon.label = _("longitude: ") ..copy_gps_longitude
    label_copy_gps_ele.label = _("elevation: ") .. copy_gps_elevation

    return
  end
end

local function paste_gps(image)
  local sel_images = dt.gui.action_images

  for _,image in ipairs(sel_images) do
    if (label_copy_gps_lat.value) then
      image.latitude = copy_gps_latitude
    end
    if (label_copy_gps_lon.value) then    
      image.longitude = copy_gps_longitude
    end
    if (label_copy_gps_ele.value) then
      image.elevation = copy_gps_elevation
    end
  end
end

local function open_location_in_gnome_maps()

  if not df.check_if_bin_exists("gnome-maps") then
    dt.print_error(_("gnome-maps not found"))
    return
  end	
    
  local sel_images = dt.gui.action_images
  
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
local function get_distance(lat1, lon1, ele1, lat2, lon2, ele2)

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

local function calc_distance()

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

    local distance = get_distance(lat1, lon1, ele1, lat2, lon2, ele2)

    if (distance < 1) then
        distance = distance * 1000
        distanceUnit = _("m")
    else
        distanceUnit = _("km")
    end
    
    return string.format(_("Distance: %.2f %s"), distance, distanceUnit)
end

local function print_calc_distance()
    dt.print(calc_distance())
end

local function toolbox_calc_distance()
    labelDistance.label = calc_distance()
end

local altitude_file_chooser_button = dt.new_widget("file_chooser_button")
  {
    title = _("export altitude CSV"),  -- The title of the window when choosing a file
    value = "",                     -- The currently selected file
    is_directory = true             -- True if the file chooser button only allows directories to be selecte
  }
local altitude_filename = dt.new_widget("entry")
  {
    text = "altitude.csv", 
    placeholder = "altitude.csv",
    editable = true,
    tooltip = _("Name of the exported file"),
    reset_callback = function(self) self.text = "text" end
  }

local function altitude_profile()
	  dt.print(_("Start export"))
    local sel_images = dt.gui.action_images

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

    local sel_images = dt.gui.action_images
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
          local distance = get_distance(lat1, lon1, ele1, lat2, lon2, ele2)
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
    dt.print(_("File created in ")..exportDirectory)

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
      label = _("select geo images"),
      tooltip = _("Select all images with GPS information"),
      clicked_callback = select_with_gps
    },
    dt.new_widget("button")
    {
      label = _("select not geo images"),
      tooltip = _("Select all images without GPS information"),
      clicked_callback = select_without_gps
    },
    separator,--------------------------------------------------------
    dt.new_widget("button")
    {
      label = _("copy GPS data"),
      tooltip = _("Copy GPS data"),
      clicked_callback = copy_gps
    },
    label_copy_gps_lat,
    label_copy_gps_lon,
    label_copy_gps_ele,
    dt.new_widget("button")
    {
      label = _("paste GPS data"),
      tooltip = _("Paste GPS data"),
      clicked_callback = paste_gps
    },
    separator2,--------------------------------------------------------
--ToDo: This need a better UI
--[[
    dt.new_widget("button")
    {
      label = "get 1st coordinate",
      tooltip = "Select first image and click this button",
      clicked_callback = get_first_coordinate
    },
    dt.new_widget("button")
    {
      label = "get 2nd coordinate",
      tooltip = "Select second image and click this button",
      clicked_callback = get_second_coordinate
    },
    dt.new_widget("button")
    {
      label = "calc in between",
      tooltip = "Select third image and click this button",
      clicked_callback = calc_in_between
    },
    calc_in_between_slider,
    separator3,--------------------------------------------------------
]]    
    dt.new_widget("button")
    {
      label = _("open in Gnome Maps"),
      tooltip = _("Open location in Gnome Maps"),
      clicked_callback = open_location_in_gnome_maps
    },
    separator4,--------------------------------------------------------
    dt.new_widget("label"){label = _("altitude CSV export")},
    altitude_file_chooser_button,
    altitude_filename,
    dt.new_widget("button")
    {
      label = _("export altitude CSV file"),
      tooltip = _("Create an altitude profile using the GPS data in the metadata"),
      clicked_callback = altitude_profile
    },
    labelDistance
  },
  nil,-- view_enter
  nil -- view_leave
)


-- Register
dt.register_event("shortcut", print_calc_distance, _("Calculate the distance from latitude and longitude in km"))
dt.register_event("mouse-over-image-changed", toolbox_calc_distance)

dt.register_event("shortcut", select_with_gps, _("Select all images with GPS information"))
dt.register_event("shortcut", select_without_gps, _("Select all images without GPS information"))

-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: hl Lua;
