--[[

    image_time.lua - synchronize image time for images shot with different cameras

    Copyright (C) 2019, 2020 Bill Ferguson <wpferguson@gmail.com>.

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
    image_time - non-destructively modify the image time

    DESCRIPTION

    image_time non destructively adjusts image times by modifying the 
    database image exif_datetime_taken field.  There are 4 modes: adjust time,
    set time, synchronize time, and reset time.

      ADJUST TIME

        adjust time mode lets you chose an offset in terms of years, months,
        days, hours, minutes, and seconds.  The adjustment can be added or
        subtracted.  

        WARNING:  When adding and subtracting months the result will usually
        be what is expected unless the time being adjusted is at the end of 
        the month.  This is because a month is a variable amount of time that
        can be 28, 29, 30 or 31 days depending on the month.  Example: It's 
        March 31st and I subtract a month which not sets the time to February
        31st.  When that gets set to a valid time, then the date changes to
        March 3rd.

      SET TIME

        set time mode allows you to pick a date and time and set the image
        time accordingly.  Fields may be left out.  This is useful when 
        importing scanned images that don't have an embedded date.  

      SYNCHRONIZE TIME

        I recently purchased a 7DmkII to replace my aging 7D.  My 7D was still
        serviceable, so I bought a remote control and figured I'd try shooting
        events from 2 different perspectives.  I didn't think to synchonize the 
        time between the 2 cameras, so when I loaded the images and sorted by
        time it was a disaster.  I hacked a script together with hard coded values
        to adjust the exif_datetime_taken value in the database for the 7D images 
        so that everything sorted properly.  I've tried shooting with 2 cameras 
        several times since that first attempt.  I've gotten better at getting the
        camera times close, but still haven't managed to get them to sync.  So I
        decided to think the problem through and write a proper script to take 
        care of the problem.

      RESET TIME

        Select the images and click reset.  

    USAGE

      ADJUST TIME

        Change the year, month, day, hour, minute, second dropdowns to the amount
        of change desired.  Select add or subtract.  Select the images.  Click 
        adjust.

      SET TIME

        Set the time fields to the desired time.  Select the images to change.  Click
        set.

      SYNCHRONIZE TIME

        Select 2 images, one from each camera, of the same moment in time.  Click
        the Calculate button to calculate the time difference.  The difference is
        displayed in the difference entry.  You can manually adjust it by changing
        the value if necessary.

        Select the images that need their time adjusted.  Determine which way to adjust
        adjust the time (add or subtract) and select the appropriate choice.

        If the image times get messed up and you just want to start over, select reset time
        from the mode and reset the image times.

      RESET TIME

        Select the images and click reset.

    ADDITIONAL SOFTWARE REQUIRED
    * exiv2

    BUGS, COMMENTS, SUGGESTIONS
    * Send to Bill Ferguson, wpferguson@gmail.com

    CHANGES

]]
local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local ds = require "lib/dtutils.string"
local dtsys = require "lib/dtutils.system"
local gettext = dt.gettext.gettext

local img_time = {}
img_time.module_installed = false
img_time.event_registered = false

du.check_min_api_version("7.0.0", "image_time") 

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("image time"),
  purpose = _("synchronize image time for images shot with different cameras or adjust or set image time"),
  author = "Bill Ferguson <wpferguson@gmail.com>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/image_time"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them



local PS = dt.configuration.runnin_os == "windows" and "\\" or "/"
local ERROR = -1

-- function to convert from exif time to system time
local function exiftime2systime(exiftime)
  local yr,mo,dy,h,m,s = string.match(exiftime, "(%d-):(%d-):(%d-) (%d-):(%d-):(%d+)")
  return(os.time{year=yr, month=mo, day=dy, hour=h, min=m, sec=s})
end

-- function to convert from systime to exif time
local function systime2exiftime(systime)
  local t = os.date("*t", systime)
  return(string.format("%4d:%02d:%02d %02d:%02d:%02d", t.year, t.month, t.day, t.hour, t.min, t.sec))
end

local function vars2exiftime(year, month, day, hour, min, sec)
  local y = tonumber(year) and string.format("%4d", year) or "0000"
  local mo = tonumber(month) and string.format("%02d", month) or "00"
  local d = tonumber(day) and string.format("%02d", day) or "00"
  local h = tonumber(hour) and string.format("%02d", hour) or "00"
  local m = tonumber(min) and string.format("%02d", min) or "00"
  local s = tonumber(sec) and string.format("%02d", sec) or "00"
 return(y .. ":" .. mo .. ":" .. d .. " " .. h .. ":" .. m .. ":" .. s)
end

local function exiftime2vars(exiftime)
  return string.match(exiftime, "(%d+):(%d+):(%d+) (%d+):(%d+):(%d+)")
end

local function calc_time_difference(image1, image2)
  return math.abs(exiftime2systime(image1.exif_datetime_taken) - exiftime2systime(image2.exif_datetime_taken))
end

local function adjust_image_time(image, difference)
  image.exif_datetime_taken = systime2exiftime(exiftime2systime(image.exif_datetime_taken) + difference)
  return
end

local function calculate_difference(images)
  if #images == 2 then
    img_time.diff_entry.text = calc_time_difference(images[1], images[2])
    img_time.btn.sensitive = true
  else
    dt.print(_("ERROR: 2 images must be selected"))
  end
end

local function synchronize_times(images, difference)
  for _, image in ipairs(images) do
    adjust_image_time(image, difference)
  end
end

local function synchronize_time(images)
  local sign = 1
  if img_time.sdir.value == _("subtract") then
    sign = -1
  end
  synchronize_times(images, tonumber(img_time.diff_entry.text) * sign)
end

local function add_time(images)
  synchronize_times(images, tonumber(img_time.diff_entry.text))
end

local function year_month2months(year, month)
  year_months = tonumber(year) and year * 12 or 0
  local months = tonumber(month) and tonumber(month) or 0

  return year_months + months
end

local function months2year_month(months)
  dt.print_log("months is " .. months)
  local year = math.floor(months / 12)
  local month = months - (year * 12)

  return year, month
end

local function get_image_taken_time(image)
  -- get original image time
  local datetime = nil

  local exiv2 = df.check_if_bin_exists("exiv2")
  if exiv2 then
    p = io.popen(exiv2 .. " -K Exif.Image.DateTime " .. image.path .. PS .. image.filename)
    if p then
      for line in p:lines() do
        if string.match(line, "Exif.Image.DateTime") then
          datetime = string.match(line, "(%d-:%d-:%d- %d-:%d-:%d+)")
        end
      end
      p:close()
    end
  else
    dt.print(_("unable to detect exiv2"))
    datetime = ERROR
  end
  return datetime
end

local function _get_windows_image_file_creation_time(image)
  local datetime = nil
  local p = io.popen("dir " .. image.path .. PS .. image.filename)
  if p then
    for line in p:lines() do
      if string.match(line, ds.sanitize_lua(image.filename)) then
        local mo, day, yr, hr, min, apm = string.match(line, "(%d+)/(%d+)/(%d+)  (%d-):(%d+) (%S+)")
        if apm == "PM" then
          hr = hr + 12
        end
        datetime = vars2exiftime(yr, mo, day, hr, min, 0)
      end
    end
    p:close()
  else
    dt.print(string.format(_("unable to get information for %s"), image.filename))
    datetime = ERROR
  end
  return datetime
end

local function _get_nix_image_file_creation_time(image)
  local datetime = nil
  local p = io.popen("ls -lL --time-style=full-iso " .. image.path .. PS .. image.filename)
  if p then
    for line in p:lines() do
      if string.match(line, ds.sanitize_lua(image.filename)) then
        datetime = vars2exiftime(string.match(line, "(%d+)%-(%d-)%-(%d-) (%d-):(%d-):(%d+)."))
      end
    end
    p:close()
  else
    dt.print(string.format(_("unable to get information for %s"), image.filename))
    datetime = ERROR
  end
  return datetime
end

local function get_image_file_creation_time(image)
  -- no exif time in the image file so get the creation time
  local datetime = nil
  if dt.configuration.running_os == "windows" then
    datetime = _get_windows_image_file_creation_time(image)
  else
    datetime = _get_nix_image_file_creation_time(image)
  end
  return datetime
end

local function get_original_image_time(image)
  local image_time = image.exif_datetime_taken
  local reset_time = nil

  reset_time = get_image_taken_time(image)

  if reset_time then
    if reset_time == ERROR then
      return image_time
    else
      return reset_time
    end
  else
    reset_time = get_image_file_creation_time(image)

    if reset_time then
      if reset_time == ERROR then
        return image_time
      else
        return reset_time
      end
    end
  end
end

local function reset_time(images)
  if #images > 0 then
    for _, image in ipairs(images) do
      image.exif_datetime_taken = get_original_image_time(image)
    end
  else
    dt.print_error("reset time: no images selected")
    dt.print(_("please select the images that need their time reset"))
  end
end

local function adjust_time(images)
  local SEC_MIN = 60
  local SEC_HR = SEC_MIN * 60
  local SEC_DY = SEC_HR * 24

  local offset = nil
  local sign = 1

  if #images < 1 then
    dt.print(_("please select some images and try again"))
    return
  end

  if img_time.adir.value == _("subtract") then
    sign = -1
  end

  for _, image in ipairs(images) do
    local y, mo, d, h, m, s = exiftime2vars(image.exif_datetime_taken)
    local image_months = year_month2months(y, mo)
    local months_diff = year_month2months(img_time.ayr.value, img_time.amo.value)
    y, mo = months2year_month(image_months + (months_diff * sign))
    local exif_new = vars2exiftime(y, mo, d, h, m, s)
    offset = img_time.ady.value * SEC_DY 
    offset = offset + img_time.ahr.value * SEC_HR 
    offset = offset + img_time.amn.value * SEC_MIN 
    offset = offset + img_time.asc.value 
    offset = offset * sign
    image.exif_datetime_taken = systime2exiftime(exiftime2systime(exif_new) + offset)
  end
end

local function set_time(images)
  if #images < 1 then
    dt.print(_("please select some images and try again"))
    return
  end

  local y = img_time.syr.value
  local mo = img_time.smo.value
  local d = img_time.sdy.value
  local h = img_time.shr.value
  local m = img_time.smn.value
  local s = img_time.ssc.value

  for _, image in ipairs(images) do
    image.exif_datetime_taken = vars2exiftime(y, mo, d, h, m, s)
  end
end

local function seq(first, last)
  local result = {}

  local num = first

  while num <= last do
    table.insert(result, num)
    num = num + 1
  end

  return table.unpack(result)
end

local function reset_widgets()
  dt.print_log("took the reset function")
  img_time.ayr.selected = 1
  img_time.amo.selected = 1
  img_time.ady.selected = 1
  img_time.ahr.selected = 1
  img_time.ayr.selected = 1
  img_time.amn.selected = 1
  img_time.asc.selected = 1
  img_time.adir.selected = 1
  img_time.syr.selected = #img_time.syr
  img_time.smo.selected = 1
  img_time.sdy.selected = 1
  img_time.shr.selected = 1
  img_time.smn.selected = 1
  img_time.ssc.selected = 1
  img_time.adir.selected = 1
end

local function install_module()
  if not img_time.module_installed then
    dt.register_lib(
      "image_time",     -- Module name
      _("image time"),     -- Visible name
      true,                -- expandable
      true,               -- resetable
      {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},   -- containers
      img_time.widget,
      nil,-- view_enter
      nil -- view_leave
    )
    img_time.module_installed = true
  end
end

local function destroy()
  dt.gui.libs["image_time"].visible = false
end

local function restart()
  dt.gui.libs["image_time"].visible = true
end

-- widgets

img_time.widgets  = {
  -- name, type, tooltip, placeholder,
  {"ayr", "combobox", _("years"), _("years to adjust by, 0 - ?"), {seq(0,20)}, 1},
  {"amo", "combobox", _("months"), _("months to adjust by, 0-12"), {seq(0,12)}, 1},
  {"ady", "combobox", _("days"), _("days to adjust by, 0-31"), {seq(0,31)}, 1},
  {"ahr", "combobox", _("hours"), _("hours to adjust by, 0-23"), {seq(0,23)}, 1},
  {"amn", "combobox", _("minutes"), _("minutes to adjust by, 0-59"), {seq(0,59)}, 1},
  {"asc", "combobox", _("seconds"), _("seconds to adjust by, 0-59"), {seq(0,59)}, 1},
  {"adir", "combobox", _("add/subtract"), _("add or subtract time"), {_("add"), _("subtract")}, 1},
  {"syr", "combobox", _("year"), _("year to set,  1900 - now"), {"  ", seq(1900,os.date("*t", os.time()).year)}, 1},
  {"smo", "combobox", _("month"), _("month to set, 1-12"), {"  ", seq(1,12)}, 1},
  {"sdy", "combobox", _("day"), _("day to set, 1-31"), {"  ", seq(1,31)}, 1},
  {"shr", "combobox", _("hour"), _("hour to set, 0-23"), {"  ", seq(0,23)}, 1},
  {"smn", "combobox", _("minute"), _("minutes to set, 0-59"), {"  ", seq(0, 59)}, 1},
  {"ssc", "combobox", _("seconds"), _("seconds to set, 0-59"), {"  ", seq(0,59)}, 1},
  {"sdir", "combobox", _("add/subtract"), _("add or subtract time"), {_("add"), _("subtract")}, 1},
}

for _, widget in ipairs(img_time.widgets) do
  img_time[widget[1]] = dt.new_widget(widget[2]){
    label = widget[3],
    tooltip = widget[4],
    selected = widget[6],
    table.unpack(widget[5])
  }
end

img_time.syr.selected = #img_time.syr

img_time.diff_entry = dt.new_widget("entry"){
  tooltip = _("time difference between images in seconds"),
  placeholder = _("select 2 images and use the calculate button"),
  text = "",
}

img_time.calc_btn = dt.new_widget("button"){
  label = _("calculate"),
  tooltip = _("calculate time difference between 2 images"),
  clicked_callback = function()
    calculate_difference(dt.gui.action_images)
  end
}

img_time.btn = dt.new_widget("button"){
  label = _("synchronize image times"),
  tooltip = _("apply the time difference from selected images"),
  sensitive = false,
  clicked_callback = function()
    synchronize_time(dt.gui.action_images)
  end
}

img_time.stack = dt.new_widget("stack"){
  dt.new_widget("box"){
    orientation = "vertical",
    dt.new_widget("label"){label = _("adjust time")},
    dt.new_widget("section_label"){label = _("days, months, years")},
    img_time.ady,
    img_time.amo,
    img_time.ayr,
    dt.new_widget("section_label"){label = _("hours, minutes, seconds")},
    img_time.ahr,
    img_time.amn,
    img_time.asc,
    dt.new_widget("section_label"){label = _("adjustment direction")},
    img_time.adir,
    dt.new_widget("button"){
      label = _("adjust"),
      clicked_callback = function()
        adjust_time(dt.gui.action_images)
      end
    }
  },
  dt.new_widget("box"){
    orientation = "vertical",
    dt.new_widget("label"){label = _("set time")},
    dt.new_widget("section_label"){label = _("date:")},
    img_time.sdy,
    img_time.smo,
    img_time.syr,
    dt.new_widget("section_label"){label = _("time:")},
    img_time.shr,
    img_time.smn,
    img_time.ssc,
    dt.new_widget("button"){
      label = _("set"),
      clicked_callback = function()
        set_time(dt.gui.action_images)
      end
    }
  },
  dt.new_widget("box"){
    orientation = "vertical",
    dt.new_widget("label"){label = _("synchronize image time")},
    dt.new_widget("section_label"){label = _("calculate difference between images")},
    img_time.diff_entry,
    img_time.calc_btn,
    dt.new_widget("section_label"){label = _("apply difference")},
    img_time.sdir,
    img_time.btn,
  },
  dt.new_widget("box"){
    orientation = "vertical",
    dt.new_widget("label"){label = _("reset to original time")},
    dt.new_widget("separator"){},
    dt.new_widget("button"){
      label = _("reset"),
      clicked_callback = function()
        reset_time(dt.gui.action_images)
      end
    }
  },
}

img_time.mode = dt.new_widget("combobox"){
  label = _("mode"),
  tooltip = _("select mode"),
  selected = 1,
  changed_callback = function(this)
    img_time.stack.active = this.selected
  end,
  _("adjust time"),
  _("set time"),
  _("synchronize time"),
  _("reset time")
}

img_time.widget = dt.new_widget("box"){
  orientation = "vertical",
  reset_callback = function(this)
    reset_widgets()
  end,
  img_time.mode,
  img_time.stack,
}

if dt.gui.current_view().id == "lighttable" then
  install_module()
else
  if not img_time.event_registered then
    dt.register_event(
      "image_time", "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module()
         end
      end
    )
    img_time.event_registered = true
  end
end

script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = restart

return script_data
