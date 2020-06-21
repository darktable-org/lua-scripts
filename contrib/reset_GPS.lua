--[[

    reset_GPS.lua - reset GPS data from image file

    Copyright (C) 2020 Bill Ferguson <wpferguson@gmail.com>.

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
    reset_GPS - reset the GPS information from the image file

    This shortcut resets the GPS information to that contained within
    the image file.  If no GPS info is in the image file, the GPS data
    is cleared.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    * exiv2

    USAGE
    * require this script from your main lua file
    * select an image or images
    * click the shortcut, reset GPS data

    BUGS, COMMENTS, SUGGESTIONS
    * Send to Bill Ferguson, wpferguson@gmail.com

    CHANGES
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"

du.check_min_api_version("3.0.0", "reset_GPS") 

local PS = dt.configuration.running_os == windows and '\\' or '/'

local gettext = dt.gettext

-- not a number
local NaN = 0/0

local exiv2 = df.check_if_bin_exists("exiv2")

if exiv2 then


  -- Tell gettext where to find the .mo file translating messages for a particular domain
  gettext.bindtextdomain("reset_GPS",dt.configuration.config_dir.."/lua/locale/")

  local function _(msgid)
      return gettext.dgettext("reset_GPS", msgid)
  end

  local function extract_altitude(dat)
    return string.match(dat, "(%d-.?%d?) m$")
  end

  local function extract_degrees(dat)
    local deg = nil
    local min = nil
    local sec = nil
    local result = nil

    if string.match(dat, '"') then
      deg, min, sec = string.match(dat, "(%d+)deg (%d+)' (%d+.?%d+)")
    else
      deg, min = string.match(dat, "(%d-)deg (%d+.?%d+)")
    end

    if sec then
      min = min + sec / 60.
    end
    if min then
      deg = deg + min / 60.
    end
    if deg then
      result = deg
    end
    return result
  end

  local function process_data(ref, dat)
    local sign = nil
    local result = nil

    if string.match(ref, "Above") or string.match(ref, "North") or string.match(ref, "East") then
      sign = 1
    else
      sign = -1
    end

    if string.match(dat, "deg") then
      result = extract_degrees(dat)
    else
      result = extract_altitude(dat)
    end

    if result and sign then
      result = result * sign
    else
      result = nil
    end

    return result
  end

  local function reset_GPS(images)
    local exiv2_args = " -g GPSInfo "
    for _, image in ipairs(images) do
      dt.print_log(_("processing ") .. image.filename)
      local p = io.popen(exiv2 .. exiv2_args .. image.path .. PS .. image.filename)
      if p then
        local altitude = nil
        local latitude = nil
        local longitude = nil
        local GPSLatitudeRef = nil
        local GPSLatitude = nil
        local GPSLongitudeRef = nil
        local GPSLongitude = nil
        local GPSAltitudeRef = nil
        local GPSAltitude = nil
        for line in p:lines() do
          if string.match(line, "GPSLatitudeRef") then
            GPSLatitudeRef = line
          elseif string.match(line, "GPSLatitude") then
            GPSLatitude = line
          elseif string.match(line, "GPSLongitudeRef") then
            GPSLongitudeRef = line
          elseif string.match(line, "GPSLongitude") then
            GPSLongitude = line
          elseif string.match(line, "GPSAltitudeRef") then
            GPSAltitudeRef = line
          elseif string.match(line, "GPSAltitude") then
            GPSAltitude = line
          end
        end
        p:close()
        if GPSAltitudeRef and GPSAltitude then
          altitude = process_data(GPSAltitudeRef, GPSAltitude)
        end
        if GPSLatitudeRef and GPSLatitude then
          latitude = process_data(GPSLatitudeRef, GPSLatitude)
        end
        if GPSLongitudeRef and GPSLongitude then
          longitude = process_data(GPSLongitudeRef, GPSLongitude)
        end
        if latitude and longitude then
          if altitude then 
            image.elevation = alititude 
            dt.print_log(_("altitude detected, set elevation to ") .. altitude)
          end
          image.latitude = latitude 
          dt.print_log(_("latitude detected, set latitude to ") .. latitude)
          image.longitude = longitude 
          dt.print_log(_("longitude detected, set longitude to ") .. longitude)
        else -- no gps info in image, so just clear it
          dt.print_log(_("no gps data detected, resetting to NaN"))
          image.elevation = NaN
          image.latitude = NaN
          image.longitude = NaN
        end
      else
        dt.print(_("Unable to read GPSInfo from image"))
        dt.print_error(_("Unable to read GPSInfo from image"))
      end
    end
  end


  dt.gui.libs.image.register_action(
    _("reset GPS data"),
    function(event, images) reset_GPS(images) end,
    "reset GPS data"
  )

  dt.register_event(
    "shortcut",
    function(event, shortcut) reset_GPS(dt.gui.action_images) end,
    _("reset GPS data")
  )
else
  dt.print(_("Unable to locate exiv2.  Please ensure it is installed and in the path,\nor specifiy it's location using executable manager."))
end