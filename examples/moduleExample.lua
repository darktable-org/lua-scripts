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

dt.configuration.check_version(...,{3,0,0},{4,0,0},{5,0,0})

-- add a new lib
local check_button = dt.new_widget("check_button"){label = "MyCheck_button", value = true}
local combobox = dt.new_widget("combobox"){label = "MyCombobox", value = 2, "8", "16", "32"}

--https://www.darktable.org/lua-api/ar01s02s54.html.php
local entry = dt.new_widget("entry")
{
    text = "test", 
    placeholder = "placeholder",
    is_password = false,
    editable = true,
    tooltip = "Tooltip Text",
    reset_callback = function(self) self.text = "text" end
}

local file_chooser_button = dt.new_widget("file_chooser_button")
{
    title = "MyFile_chooser_button",  -- The title of the window when choosing a file
    value = "",                       -- The currently selected file
    is_directory = false              -- True if the file chooser button only allows directories to be selecte
}

local label = dt.new_widget("label")
label.label = "MyLabel" -- This is an alternative way to the "{}" syntax to set a property 

local separator = dt.new_widget("separator"){}
local slider = dt.new_widget("slider")
{
  label = "MySlider", 
  soft_min = 10,      -- The soft minimum value for the slider, the slider can't go beyond this point
  soft_max = 100,     -- The soft maximum value for the slider, the slider can't go beyond this point
  hard_min = 0,       -- The hard minimum value for the slider, the user can't manually enter a value beyond this point
  hard_max = 1000,    -- The hard maximum value for the slider, the user can't manually enter a value beyond this point
  value = 52          -- The current value of the slider
}

dt.register_lib(
  "exampleModule",     -- Module name
  "exampleModule",     -- name
  true,                -- expandable
  false,               -- resetable
  {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},   -- containers
  dt.new_widget("box") -- widget
  {
    orientation = "vertical",
    dt.new_widget("button")
    {
      label = "MyButton",
      clicked_callback = function (_)
        dt.print("Button clicked")
      end
    },
    check_button,
    combobox,   
    entry,
    file_chooser_button,
    label,
    separator,
    slider
  },
  nil,-- view_enter
  nil -- view_leave
)

-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: hl Lua;
