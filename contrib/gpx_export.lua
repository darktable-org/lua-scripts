--[[
    This file is part of darktable,
    copyright (c) 2017 Jannis_V

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
Simple darktable GPX generator script

This script generates a GPX track from all images having GPS latitude
and longitude information.
For each source folder, a separate <trk> is generated in the gpx file.
]]

local dt = require "darktable"
local df = require "lib/dtutils.file"
local dl = require "lib/dtutils"
local gettext = dt.gettext.gettext

dl.check_min_api_version("7.0.0", "gpx_export") 

local function _(msgid)
  return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("gpx export"),
  purpose = _("export gpx information to a file"),
  author = "Jannis_V",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/gpx_export"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

local gpx = {}
gpx.module_installed = false
gpx.event_registered = false

local path_entry = dt.new_widget("entry")
{
  text = dt.preferences.read("gpx_exporter", "gpxExportPath", "string"),
  editable=true,
  reset_callback = function(self)
    self.text = "~/darktable.gpx"
    dt.preferences.write("gpx_exporter", "gpxExportPath", "string", self.text)
  end,
  tooltip = _("gpx file path"),
}

local function stop_job(job)
  job.valid = false
end

local function create_gpx_file()
  dt.preferences.write("gpx_exporter", "gpxExportPath", "string", path_entry.text)

  path = path_entry.text:gsub("^~", os.getenv("HOME")) -- Expand ~ to home
  path = path:gsub("//", "/")

  dt.print(_("exporting gpx file..."))

  job = dt.gui.create_job(_("gpx export"), true, stop_job)

  local sel_images = dt.gui.action_images
  local segments = {}
  for key,image in dl.spairs(sel_images, function(t, a, b) return t[b].path > t[a].path end) do

    print(image.path)

    if (job.valid) then
      job.percent = (key - 1) / #sel_images

      if ((image.longitude and image.latitude) and
        (image.longitude ~= 0 and image.latitude ~= 90) -- Just in case
      ) then
        if (segments[image.path] == nil) then
          segments[image.path] = {}
        end

        if (image.exif_datetime_taken == "") then
          dt.print(image.path.."/"..image.filename.._(" does not have date information and won't be processed"))
          print(image.path.."/"..image.filename.._(" does not have date information and won't be processed")) -- Also print to terminal
        else
          segments[image.path][image.filename] = image
        end
      end
    else
      break
    end
  end

  local gpx_file = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>\n"
  gpx_file = gpx_file.."<gpx xmlns=\"http://www.topografix.com/GPX/1/1\" creator=\"Darktable GPX Exporter\"\n"
  gpx_file = gpx_file.."version=\"1.1\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n"
  gpx_file = gpx_file.."xsi:schemaLocation=\"http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd\">\n"

  for key, folder in dl.spairs(segments) do
    gpx_file = gpx_file.."\t<trk>\n"
    gpx_file = gpx_file.."\t\t<name>"..key.."</name>\n";
    gpx_file = gpx_file.."\t\t<trkseg>\n";
    for key2, image in dl.spairs(folder, function(t, a, b) return t[b].exif_datetime_taken > t[a].exif_datetime_taken end) do
      date_format = "(%d+):(%d+):(%d+) (%d+):(%d+):(%d+)"
      my_year, my_month, my_day, my_hour, my_min, my_sec = image.exif_datetime_taken:match(date_format)

      local my_timestamp = os.time({year=my_year, month=my_month, day=my_day, hour=my_hour, min=my_min, sec=my_sec})

      gpx_file = gpx_file.."\t\t\t<trkpt lat=\""..string.gsub(tostring(image.latitude), ",", ".").."\" lon=\""..string.gsub(tostring(image.longitude), ",", ".").."\">\n"
      gpx_file = gpx_file.."\t\t\t\t<time>"..os.date("!%Y-%m-%dT%H:%M:%SZ", my_timestamp).."</time>\n"
      gpx_file = gpx_file.."\t\t\t\t<name>"..image.path.."/"..image.filename.."</name>\n"
      gpx_file = gpx_file.."\t\t\t</trkpt>\n"
    end
    gpx_file = gpx_file.."\t\t</trkseg>\n";
    gpx_file = gpx_file.."\t</trk>\n";
  end

  job.valid = false

  gpx_file = gpx_file.."</gpx>\n";

  local file = io.open(path, "w")
  if (file == nil) then
    dt.print(string.format(_("invalid path: %s"), path))
  else
    file:write(gpx_file)
    file:close()
    dt.print(string.format(_("gpx file created: "), path))
  end
end

local function install_module()
  if not gpx.module_installed then
    dt.register_lib(
      "gpx_exporter",
      _("gpx export"),
      true, -- expandable
      true, -- resetable
      {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},   -- containers
      gpx.widget,
      nil,-- view_enter
      nil -- view_leave
    )
    gpx.module_installed = true
  end
end

local function destroy()
  dt.gui.libs["gpx_exporter"].visible = false
end

local function restart()
  dt.gui.libs["gpx_exporter"].visible = true
end

gpx.widget = dt.new_widget("box")
{
  orientation = "vertical",
  dt.new_widget("button")
  {
    label = _("export"),
    tooltip = _("export gpx file"),
    clicked_callback = create_gpx_file
  },
  dt.new_widget("box")
  {
    orientation = "horizontal",
    dt.new_widget("label")
    {
      label = _("file:"),
    },
    path_entry
  },
}


if dt.gui.current_view().id == "lighttable" then
  install_module()
else
  if not gpx.event_registered then
    dt.register_event(
      "gpx_export", "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module()
         end
      end
    )
    gpx.event_registered = true
  end
end

script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = restart

return script_data
