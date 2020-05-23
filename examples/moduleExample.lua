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
* require this script from your luarc file
  To do this add this line to the file .config/darktable/luarc: 
require "examples/moduleExample"

* it creates a new example lighttable module

More informations about building user interface elements:
https://www.darktable.org/usermanual/ch09.html.php#lua_gui_example
And about new_widget here:
https://www.darktable.org/lua-api/index.html.php#darktable_new_widget
]]

local dt = require "darktable"
local du = require "lib/dtutils"

du.check_min_api_version("3.0.0", "moduleExample") 

-- translation

-- https://www.darktable.org/lua-api/index.html#darktable_gettext
local gettext = dt.gettext

gettext.bindtextdomain("moduleExample", dt.configuration.config_dir .. "/lua/locale/")

local function _(msgid)
    return gettext.dgettext("moduleExample", msgid)
end


-- https://www.darktable.org/lua-api/types_lua_check_button.html
local check_button = dt.new_widget("check_button"){label = _("MyCheck_button"), value = true}

-- https://www.darktable.org/lua-api/types_lua_combobox.html
local combobox = dt.new_widget("combobox"){label = _("MyCombobox"), value = 2, "8", "16", "32"}

-- https://www.darktable.org/lua-api/types_lua_entry.html
local entry = dt.new_widget("entry")
{
    text = "test", 
    placeholder = _("placeholder"),
    is_password = false,
    editable = true,
    tooltip = _("Tooltip Text"),
    reset_callback = function(self) self.text = "text" end
}

-- https://www.darktable.org/lua-api/types_lua_file_chooser_button.html
local file_chooser_button = dt.new_widget("file_chooser_button")
{
    title = _("MyFile_chooser_button"),  -- The title of the window when choosing a file
    value = "",                       -- The currently selected file
    is_directory = false              -- True if the file chooser button only allows directories to be selecte
}

-- https://www.darktable.org/lua-api/types_lua_label.html
local label = dt.new_widget("label")
label.label = _("MyLabel") -- This is an alternative way to the "{}" syntax to set a property 

-- https://www.darktable.org/lua-api/types_lua_separator.html
local separator = dt.new_widget("separator"){}

-- https://www.darktable.org/lua-api/types_lua_slider.html
local slider = dt.new_widget("slider")
{
  label = _("MySlider"), 
  soft_min = 10,      -- The soft minimum value for the slider, the slider can't go beyond this point
  soft_max = 100,     -- The soft maximum value for the slider, the slider can't go beyond this point
  hard_min = 0,       -- The hard minimum value for the slider, the user can't manually enter a value beyond this point
  hard_max = 1000,    -- The hard maximum value for the slider, the user can't manually enter a value beyond this point
  value = 52          -- The current value of the slider
}

-- https://www.darktable.org/lua-api/index.html#darktable_register_lib
dt.register_lib(
  "exampleModule",     -- Module name
  "exampleModule",     -- name
  true,                -- expandable
  false,               -- resetable
  {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},   -- containers
  -- https://www.darktable.org/lua-api/types_lua_box.html
  dt.new_widget("box") -- widget
  {
    orientation = "vertical",
    dt.new_widget("button")
    {
      label = _("MyButton"),
      clicked_callback = function (_)
        dt.print(_("Button clicked"))
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
