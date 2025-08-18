--[[
    This file is part of darktable,
    copyright (c) 2016 Tobias Jakobs
    copyright (c) 2025 Balázs Dura-Kovács

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
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local dtsys = require "lib/dtutils.system"
local gettext = dt.gettext.gettext

du.check_min_api_version("7.0.0", "geoToolbox") 

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("geo toolbox"),
  purpose = _("geodata tools"),
  author = "Tobias Jakobs",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/geoToolbox"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them


local gT = {}
gT.module_installed = false
gT.event_registered = false


-- <GUI>
local labelDistance = dt.new_widget("label")
labelDistance.label = _("distance:")

local checkbox_copy_gps_lat = dt.new_widget("check_button")
{
  value = true
}
local entry_gps_lat = dt.new_widget("entry")
{
  tooltip = _("latitude (editable)"),
  placeholder = _("latitude")
}
local checkbox_copy_gps_lon = dt.new_widget("check_button")
{
  value = true
}
local entry_gps_lon = dt.new_widget("entry")
{
  tooltip = _("longitude (editable)"),
  placeholder = _("longitude")
}
local checkbox_copy_gps_ele = dt.new_widget("check_button")
{
  value = true
}
local entry_gps_ele = dt.new_widget("entry")
{
  tooltip = _("elevation (editable)"),
  placeholder = _("elevation")
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

  for jj,image in ipairs(sel_images) do
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

  for jj,image in ipairs(sel_images) do
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
  for jj,image in ipairs(sel_images) do
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

  for jj,image in ipairs(sel_images) do
    if not image then
      copy_gps_have_data = false
    else
      copy_gps_have_data = true
      if (image.latitude and checkbox_copy_gps_lat.value) then
        copy_gps_latitude = image.latitude
      end
      if (image.longitude and checkbox_copy_gps_lon.value) then
          copy_gps_longitude = image.longitude
      end
      if (image.elevation and checkbox_copy_gps_ele.value) then
          copy_gps_elevation = image.elevation
      end
    end

    entry_gps_lat.text = copy_gps_latitude
    entry_gps_lon.text = copy_gps_longitude
    entry_gps_ele.text = copy_gps_elevation

    return
  end
end

local function paste_gps(image)
  local sel_images = dt.gui.action_images

  for jj,image in ipairs(sel_images) do
    if (checkbox_copy_gps_lat.value) then
      image.latitude = entry_gps_lat.text
    end
    if (checkbox_copy_gps_lon.value) then
      image.longitude = entry_gps_lon.text
    end
    if (checkbox_copy_gps_ele.value) then
      image.elevation = entry_gps_ele.text
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
  for jj,image in ipairs(sel_images) do
    if ((image.longitude and image.latitude) and
        (image.longitude ~= 0 and image.latitude ~= 90) -- Sometimes the north-pole but most likely just wrong data
       ) then
        lat1 = string.gsub(image.latitude, ",", ".");
        lon1 = string.gsub(image.longitude, ",", ".");
        break
    end
  end

  local startCommand
  startCommand = "gnome-maps \"geo:" .. lat1 .. "," .. lon1 .."\""
  dt.print_error(startCommand)

  dt.control.execute(startCommand)

end

-- Trim Funktion from: http://lua-users.org/wiki/StringTrim
local function trim12(s)
 local from = s:match"^%s*()"
 return from > #s and "" or s:match(".*%S", from)
end

local function reverse_geocode()

  if not df.check_if_bin_exists("curl") then
    dt.print_error("curl not found")
    return
  end	

  if not df.check_if_bin_exists("jq") then
    dt.print_error("jq not found")
    return
  end	

  local sel_images = dt.gui.selection() --action_images
  
  local lat1 = 0;
  local lon1 = 0;
  local i = 0;

  -- Use the first image with geo information
  for jj,image in ipairs(sel_images) do
    if ((image.longitude and image.latitude) and
        (image.longitude ~= 0 and image.latitude ~= 90) -- Sometimes the north-pole but most likely just wrong data
       ) then
        lat1 = string.gsub(image.latitude, ",", ".");
        lon1 = string.gsub(image.longitude, ",", ".");
        break
      end
    end

    local startCommand
    
    local tokan = dt.preferences.read("geoToolbox","mapBoxKey","string")
    local types = "country";
    local types = "region";
    local types = "place";
    local types = "poi";

    -- MapBox documentation
    -- https://www.mapbox.com/api-documentation/#retrieve-places-near-a-location
    -- curl -s, --silent        Silent mode (don't output anything)
    -- jq could be replaced with a Lua JSON parser
    startCommand = string.format("curl --silent \"https://api.mapbox.com/geocoding/v5/mapbox.places/%s,%s.json?types=%s&access_token=%s\" | jq '.features | .[0] | '.text''", lon1, lat1, types, tokan)

    local handle = io.popen(startCommand)
    local result = trim12(handle:read("*a"))
    handle:close()
    
    -- Errorhandling would be nice
    --dt.print_error("startCommand: "..startCommand)
    --dt.print_error("result: '"..result.."'")

    if (result ~= "null") then
      dt.print(string.sub(result, 2, string.len(result)-2))   
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
    local angle = 2 * math.atan(math.sqrt(a), math.sqrt(1-a));
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

    for jj,image in ipairs(sel_images) do
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
        distanceUnit = "m"
    else
        distanceUnit = "km"
    end

    return string.format(_("distance: %.2f %s"), distance, distanceUnit)
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
    tooltip = _("name of the exported file"),
    reset_callback = function(self) self.text = "text" end
  }

local function altitude_profile()
	  dt.print(_("start export"))
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
    for jj,image in ipairs(sel_images) do
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
    dt.print(string.format(_("file created in %s"), exportDirectory))

end

local function install_module()
  if not gT.module_installed then
    dt.register_lib(
      "geoToolbox",        -- Module name
      _("geo toolbox"),       -- name
      true,                -- expandable
      false,               -- resetable
      {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},   -- containers
      gT.widget,
      nil,-- view_enter
      nil -- view_leave
    )
    gT.module_installed = true
  end
end

local function destroy()
  dt.gui.libs["geoToolbox"].visible = false
  dt.destroy_event("geoToolbox_cd", "shortcut")
  dt.destroy_event("geoToolbox", "mouse-over-image-changed")
  dt.destroy_event("geoToolbox_wg", "shortcut")
  dt.destroy_event("geoToolbox_ng", "shortcut")
end

local function restart()
  dt.register_event("geoToolbox_cd", "shortcut", 
    print_calc_distance, _("calculate the distance from latitude and longitude in km"))
  dt.register_event("geoToolbox", "mouse-over-image-changed", 
    toolbox_calc_distance)

  dt.register_event("geoToolbox_wg", "shortcut", 
    select_with_gps, _("select all images with GPS information"))
  dt.register_event("geoToolbox_ng", "shortcut", 
    select_without_gps, _("select all images without GPS information"))

  dt.gui.libs["geoToolbox"].visible = true
end

local function show()
  dt.gui.libs["geoToolbox"].visible = true
end



local separator = dt.new_widget("separator"){}
local separator2 = dt.new_widget("separator"){}
local separator3 = dt.new_widget("separator"){}
local separator4 = dt.new_widget("separator"){}
local separator5 = dt.new_widget("separator"){}

gT.widget = dt.new_widget("box")
  {
    orientation = "vertical",
    dt.new_widget("button")
    {
      label = _("select geo images"),
      tooltip = _("select all images with GPS information"),
      clicked_callback = select_with_gps
    },
    dt.new_widget("button")
    {
      label = _("select non-geo images"),
      tooltip = _("select all images without GPS information"),
      clicked_callback = select_without_gps
    },
    separator,--------------------------------------------------------
    dt.new_widget("button")
    {
      label = _("copy GPS data"),
      tooltip = _("copy GPS data"),
      clicked_callback = copy_gps
    },
    dt.new_widget("box"){
      orientation = "horizontal",
      checkbox_copy_gps_lat,
      entry_gps_lat
    },
    dt.new_widget("box"){
      orientation = "horizontal",
      checkbox_copy_gps_lon,
      entry_gps_lon
    },
    dt.new_widget("box"){
      orientation = "horizontal",
      checkbox_copy_gps_ele,
      entry_gps_ele
    },
    dt.new_widget("button")
    {
      label = _("apply GPS data to image"),
      tooltip = _("apply GPS data to image"),
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
      tooltip = _("open location in Gnome Maps"),
      clicked_callback = open_location_in_gnome_maps
    },
    separator4,--------------------------------------------------------
    dt.new_widget("button")
    {
      label = _("reverse geocode"),
      tooltip = _("this just shows the name of the location, but doesn't add it as tag"),
      clicked_callback = reverse_geocode
    },
    separator5,--------------------------------------------------------
    dt.new_widget("label"){label = _("altitude CSV export")},
    altitude_file_chooser_button,
    altitude_filename,
    dt.new_widget("button")
    {
      label = _("export altitude CSV file"),
      tooltip = _("create an altitude profile using the GPS data in the metadata"),
      clicked_callback = altitude_profile
    },
    labelDistance
  }


if dt.gui.current_view().id == "lighttable" then
  install_module()
else
  if not gT.event_registered then
    dt.register_event(
      "geoToolbox", "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module()
         end
      end
    )
    gT.event_registered = true
  end
end

-- Preferences
dt.preferences.register("geoToolbox",
	"mapBoxKey",
	"string",
	_("geoToolbox export: MapBox Key"),
	"https://www.mapbox.com/studio/account/tokens",
	'' )

-- Register
dt.register_event("geoToolbox_cd", "shortcut", 
  print_calc_distance, _("calculate the distance from latitude and longitude in km"))
dt.register_event("geoToolbox", "mouse-over-image-changed", 
  toolbox_calc_distance)

dt.register_event("geoToolbox_wg", "shortcut", 
  select_with_gps, _("select all images with GPS information"))
dt.register_event("geoToolbox_ng", "shortcut", 
  select_without_gps, _("select all images without GPS information"))

script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = show

return script_data
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: hl Lua;
