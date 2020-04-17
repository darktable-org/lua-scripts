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
require "moduleExample"

* it creates a new example lighttable module

More informations about building user interface elements:
https://www.darktable.org/usermanual/ch09.html.php#lua_gui_example
And about new_widget here:
https://www.darktable.org/lua-api/index.html.php#darktable_new_widget
]]

local dt = require "darktable"
local du = require "lib/dtutils"

du.check_min_api_version("3.0.0", "exportLUT") 

-- add a new lib

local combobox = dt.new_widget("combobox"){label = "on conflict", value = 1, "skip", "overwrite"}

--https://www.darktable.org/lua-api/ar01s02s54.html.php

local file_chooser_button = dt.new_widget("file_chooser_button")
{
    title = "Identity_file_chooser",  -- The title of the window when choosing a file
    value = "",                       -- The currently selected file
    is_directory = false              -- True if the file chooser button only allows directories to be selecte
}

local export_chooser_button = dt.new_widget("file_chooser_button")
{
    title = "Export_location_chooser",  -- The title of the window when choosing a file
    value = "",                       -- The currently selected file
    is_directory = true              -- True if the file chooser button only allows directories to be selecte
}

local identity_label = dt.new_widget("label"){
  label = "choose the identity haldclut file"
}

local output_label = dt.new_widget("label"){
  label = "choose the output location"
}

local separator = dt.new_widget("separator"){
  
}

local function create_lut(style, haldclut)
  haldclut.reset
  dt.styles.apply(style, haldclut)
end

local function export_lut(haldclut)
  
end

local function export_luts()
  identity = dt.database.import(file_chooser_button)
  for style_num, style in ipairs(dt.styles) do
    identity = create_lut(style, identity)
    export_lut(identity)
    dt.print(style.name)
  end
end

if (dt.configuration.api_version_major >= 6) then
  local section_label = dt.new_widget("section_label")
  {
    label = "MySectionLabel"
  }

  dt.register_lib(
    "export haldclut",     -- Module name
    "export haldclut",     -- name
    true,                -- expandable
    false,               -- resetable
    {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},   -- containers
    identity_label,
    file_chooser_button,
    output_label,
    export_chooser_button,
    combobox,
    separator,
    dt.new_widget("box") -- widget
    {
      orientation = "vertical",
      dt.new_widget("button")
      {
        label = "export",
        clicked_callback = function (_)
          dt.print("Button clicked")
        end
      },
	  section_label
    },
    nil,-- view_enter
    nil -- view_leave
  )
else
  dt.register_lib(
    "export haldclut",     -- Module name
    "export haldclut",     -- name
    true,                -- expandable
    false,               -- resetable
    {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},   -- containers
    dt.new_widget("box") -- widget
    {
      orientation = "vertical",
      identity_label,
      file_chooser_button,
      output_label,
      export_chooser_button,
      combobox,
      separator,
      dt.new_widget("button")
      {
        label = "export",
        clicked_callback = export_luts
      }
    },
    nil,-- view_enter
    nil -- view_leave
  )
end

-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: hl Lua;
