--[[
    This file is part of darktable,
    copyright (c) 2020 Noah Clarke

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
Add the following line to .config/darktable/luarc to enable this lightable module: 
  require "contrib/exportLut"

Given a haldCLUT identity file this script generates haldCLUTS from all the user's
styles and exports them to a location of their choosing.

Warning: during export if a naming collision occurs the older file is automatically
overwritten silently.
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require("lib/dtutils.file")
local ds = require("lib/dtutils.system")

du.check_min_api_version("7.0.0", "exportLUT") 

local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("export LUT"),
  purpose = _("export a style as a LUT"),
  author = "Noah Clarke",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/exportLUT"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

du.check_min_api_version("5.0.0", "exportLUT") 

local eL = {}
eL.module_installed = false
eL.event_registered = false
eL.widgets = {}

-- Thanks Kevin Ertel for this bit
local os_path_seperator = '/'
if dt.configuration.running_os == 'windows' then os_path_seperator = '\\' end
local mkdir_command = 'mkdir -p '
if dt.configuration.running_os == 'windows' then mkdir_command = 'mkdir ' end

local file_chooser_button = dt.new_widget("file_chooser_button"){
    title = _("choose the identity file"),
    value = "",
    is_directory = false
}

local export_chooser_button = dt.new_widget("file_chooser_button"){
    title = _("choose the export location"),
    value = "",
    is_directory = true
}

local identity_label = dt.new_widget("label"){
  label = _("choose the identity haldclut file")
}

local output_label = dt.new_widget("label"){
  label = _("choose the output location")
}

local warning_label = dt.new_widget("label"){
  label = _("WARNING: files may be silently overwritten")
}

local function end_job(job)
  job.valid = false
end

local function output_path(style_name, job)
  local output_location = export_chooser_button.value .. os_path_seperator .. style_name .. ".png"
  output_location = string.gsub(output_location, "|", os_path_seperator)
  local output_dir = string.reverse(output_location)
  output_dir = string.gsub(output_dir, ".-" .. os_path_seperator, os_path_seperator, 1)
  output_dir = string.reverse(output_dir)
  if(output_dir ~= "") then
    df.mkdir(df.sanitize_filename(output_dir))
  end
  return output_location
end

local function export_luts()
  local identity = dt.database.import(file_chooser_button.value)
  if(type(identity) ~= "userdata") then
    dt.print(_("invalid identity lut file"))
  else
    local job = dt.gui.create_job(_('exporting styles as haldCLUTs'), true, end_job)
    
    local size = 1

    for style_num, style in ipairs(dt.styles) do
      size = size + 1
    end

    local count = 0
    for style_num, style in ipairs(dt.styles) do
      
      identity:reset()
      dt.styles.apply(style, identity)
      local io_lut = dt.new_format("png")
      io_lut.bpp = 8

      io_lut:write_image(identity, output_path(style.name, job))
      count = count + 1
      job.percent = count / size
      dt.print(string.format(_("exported: %s"), output_path(style.name, job)))
    end
    dt.print(_("done exporting haldCLUTs"))
    job.valid = false
    identity:reset()
  end
end

local function install_module()
  if not eL.module_installed then
    dt.register_lib(
      "export haldclut",
      _("export haldclut"),
      true,
      false,
      {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},
      dt.new_widget("box")
      {
        orientation = "vertical",
        table.unpack(eL.widgets),
      },
      nil,
      nil
    )
    eL.module_installed = true
  end
end

local function destroy()
  dt.gui.libs["export haldclut"].visible = false
end

local function restart()
  dt.gui.libs["export haldclut"].visible = true
end

local export_button = dt.new_widget("button"){
  label = _("export"),
  clicked_callback = export_luts
}

table.insert(eL.widgets, identity_label)
table.insert(eL.widgets, file_chooser_button)
table.insert(eL.widgets, output_label)
table.insert(eL.widgets, export_chooser_button)
table.insert(eL.widgets, warning_label)
table.insert(eL.widgets, export_button)

if dt.gui.current_view().id == "lighttable" then
  install_module()
else
  if not eL.event_registered then
    dt.register_event(
      "exportLUT", "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module()
         end
      end
    )
    eL.event_registered = true
  end
end

script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = restart

return script_data
