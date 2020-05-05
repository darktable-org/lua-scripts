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
  require "exportLut"

Given a haldCLUT identity file this script generates haldCLUTS from all the user's
styles and exports them to a location of their choosing.

Warning: during export if a naming collision occurs the older file is automatically
overwritten silently.
]]

local dt = require "darktable"
local du = require "lib/dtutils"

du.check_min_api_version("5.0.0", "exportLUT") 

-- Thanks Kevin Ertel for this bit
local os_path_seperator = '/'
if dt.configuration.running_os == 'windows' then os_path_seperator = '\\' end

local file_chooser_button = dt.new_widget("file_chooser_button"){
    title = "Identity_file_chooser",
    value = "",
    is_directory = false
}

local export_chooser_button = dt.new_widget("file_chooser_button"){
    title = "Export_location_chooser",
    value = "",
    is_directory = true
}

local identity_label = dt.new_widget("label"){
  label = "choose the identity haldclut file"
}

local output_label = dt.new_widget("label"){
  label = "choose the output location"
}

local warning_label = dt.new_widget("label"){
  label = "WARNING: files may be silently overwritten"
}

local function export_luts()
  identity = dt.database.import(file_chooser_button.value)
  if(type(identity) ~= "userdata") then
    dt.print("Invalid identity lut file")
  else
    for style_num, style in ipairs(dt.styles) do
      
      identity:reset()
      dt.styles.apply(style, identity)
      
      io_lut = dt.new_format("png")
      io_lut.bpp = 16
      io_lut:write_image(identity, export_chooser_button.value .. os_path_seperator .. style.name .. ".png")
      dt.print("Exported: " .. export_chooser_button.value .. os_path_seperator .. style.name .. ".png")
    end
    identity:reset()
  end
end

local export_button = dt.new_widget("button"){
  label = "export",
  clicked_callback = export_luts
}

dt.register_lib(
  "export haldclut",
  "export haldclut",
  true,
  false,
  {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},
  dt.new_widget("box")
  {
    orientation = "vertical",
    identity_label,
    file_chooser_button,
    output_label,
    export_chooser_button,
    warning_label,
    export_button
  },
  nil,
  nil
)