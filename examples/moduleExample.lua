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

du.check_min_api_version("7.0.0", "moduleExample") 

-- https://www.darktable.org/lua-api/index.html#darktable_gettext
local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = ("module example"),
  purpose = _("example of how to create a lighttable module"),
  author = "Tobias Jakobs",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/examples/moduleExample"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

-- translation

-- declare a local namespace and a couple of variables we'll need to install the module
local mE = {}
mE.widgets = {}
mE.event_registered = false  -- keep track of whether we've added an event callback or not
mE.module_installed = false  -- keep track of whether the module is module_installed

--[[ We have to create the module in one of two ways depending on which view darktable starts
     in.  In orker to not repeat code, we wrap the darktable.register_lib in a local function.
  ]]

local function install_module()
  if not mE.module_installed then
    -- https://www.darktable.org/lua-api/index.html#darktable_register_lib
    dt.register_lib(
      "exampleModule",     -- Module name
      _("example module"),     -- name
      true,                -- expandable
      false,               -- resetable
      {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},   -- containers
      -- https://www.darktable.org/lua-api/types_lua_box.html
      dt.new_widget("box") -- widget
      {
        orientation = "vertical",
        dt.new_widget("button")
        {
          label = _("my ") .. "button",
          clicked_callback = function (_)
            dt.print(_("button clicked"))
          end
        },
        table.unpack(mE.widgets),
      },
      nil,-- view_enter
      nil -- view_leave
    )
    mE.module_installed = true
  end
end

-- script_manager integration to allow a script to be removed
-- without restarting darktable
local function destroy()
    dt.gui.libs["exampleModule"].visible = false -- we haven't figured out how to destroy it yet, so we hide it for now
end

local function restart()
    dt.gui.libs["exampleModule"].visible = true -- the user wants to use it again, so we just make it visible and it shows up in the UI
end

-- https://www.darktable.org/lua-api/types_lua_check_button.html
local check_button = dt.new_widget("check_button"){label = _("my ") .. "check_button", value = true}

-- https://www.darktable.org/lua-api/types_lua_combobox.html
local combobox = dt.new_widget("combobox"){label = _("my ") .. "combobox", value = 2, "8", "16", "32"}

-- https://www.darktable.org/lua-api/types_lua_entry.html
local entry = dt.new_widget("entry")
{
    text = "test", 
    placeholder = _("placeholder"),
    is_password = false,
    editable = true,
    tooltip = _("tooltip text"),
    reset_callback = function(self) self.text = "text" end
}

-- https://www.darktable.org/lua-api/types_lua_file_chooser_button.html
local file_chooser_button = dt.new_widget("file_chooser_button")
{
    title = _("my ") .. "file_chooser_button",  -- The title of the window when choosing a file
    value = "",                       -- The currently selected file
    is_directory = false              -- True if the file chooser button only allows directories to be selecte
}

-- https://www.darktable.org/lua-api/types_lua_label.html
local label = dt.new_widget("label")
label.label = _("my ") .. "label" -- This is an alternative way to the "{}" syntax to set a property 

-- https://www.darktable.org/lua-api/types_lua_separator.html
local separator = dt.new_widget("separator"){}

-- https://www.darktable.org/lua-api/types_lua_slider.html
local slider = dt.new_widget("slider")
{
  label = _("my ") .. "slider", 
  soft_min = 10,      -- The soft minimum value for the slider, the slider can't go beyond this point
  soft_max = 100,     -- The soft maximum value for the slider, the slider can't go beyond this point
  hard_min = 0,       -- The hard minimum value for the slider, the user can't manually enter a value beyond this point
  hard_max = 1000,    -- The hard maximum value for the slider, the user can't manually enter a value beyond this point
  value = 52          -- The current value of the slider
}

-- pack the widgets in a table for loading in the module

table.insert(mE.widgets, check_button)
table.insert(mE.widgets, combobox)
table.insert(mE.widgets, entry)
table.insert(mE.widgets, file_chooser_button)
table.insert(mE.widgets, label)
table.insert(mE.widgets, separator)
table.insert(mE.widgets, slider)

-- ... and tell dt about it all


if dt.gui.current_view().id == "lighttable" then -- make sure we are in lighttable view
  install_module()  -- register the lib
else
  if not mE.event_registered then -- if we are not in lighttable view then register an event to signal when we might be
    -- https://www.darktable.org/lua-api/index.html#darktable_register_event
    dt.register_event(
      "mdouleExample", "view-changed",  -- we want to be informed when the view changes
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then  -- if the view changes from darkroom to lighttable
          install_module()  -- register the lib
         end
      end
    )
    mE.event_registered = true  --  keep track of whether we have an event handler installed
  end
end

-- set the destroy routine so that script_manager can call it when
-- it's time to destroy the script and then return the data to 
-- script_manager
script_data.destroy = destroy
script_data.restart = restart  -- only required for lib modules until we figure out how to destroy them
script_data.destroy_method = "hide" -- tell script_manager that we are hiding the lib so it knows to use the restart function
script_data.show = restart  -- if the script was "off" when darktable exited, the module is hidden, so force it to show on start

return script_data
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: hl Lua;
