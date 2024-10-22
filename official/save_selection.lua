--[[
  This file is part of darktable,
  copyright (c) 2014 Jérémy Rosen
  
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
SAVE SELECTION
Simple shortcuts to have multiple selection bufers


USAGE
* require this file from your main lua config file:
* go to configuration => preferences => lua
* set the shortcuts you want to use

This plugin will provide shortcuts to save to and restore from up to five temporary buffers

This plugin also provides a shortcut to swap the current selection with a quick-swap buffer

The variable "buffer_count" controls the number of selection buffers, 
increase it if you need more temporary selection buffers

]]
local dt = require "darktable"
local du = require "lib/dtutils"

du.check_min_api_version("7.0.0", "save_selection") 

local gettext = dt.gettext.gettext

local function _(msg)
  return gettext(msg)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("save selection"),
  purpose = _("shortcuts providing multiple selection buffers"),
  author = "Jérémy Rosen",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/official/save_selection"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

local buffer_count = 5

local function destroy()
  for i = 1, buffer_count do
    dt.destroy_event("save_selection save " .. i, "shortcut")
    dt.destroy_event("save_selection restore " .. i, "shortcut")
  end
  dt.destroy_event("save_selection switch", "shortcut")
end

for i = 1, buffer_count do
  local saved_selection
  dt.register_event("save_selection save " .. i, "shortcut", function()
    saved_selection = dt.gui.selection()
  end, string.format(_("save to buffer %d"), i))
  dt.register_event("save_selection restore " .. i, "shortcut", function()
    dt.gui.selection(saved_selection)
  end, string.format(_("restore from buffer %d"), i))
end

local bounce_buffer = {}
dt.register_event("save_selection switch", "shortcut", function()
  bounce_buffer = dt.gui.selection(bounce_buffer)
end, _("switch selection with temporary buffer"))

script_data.destroy = destroy

return script_data
--
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
