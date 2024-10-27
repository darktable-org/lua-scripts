--[[
    This file is part of darktable,
    copyright (c) 2015 Tobias Ellinghaus

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
IMPORT FILTER MANAGER
This script adds a dropdown list with import filters to the import dialog.
Scripts can add new filters by registering them with
  darktable.register_import_filter(name, callback)
The callback has type function(event, images), i.e., it is the same as when
directly registering the pre-import event.


USAGE
* require this script from your main lua file
* also require some files with import filters, for example import_filters.lua.
  it is important to add them AFTER this one!
]]

local dt = require "darktable"

local gettext = dt.gettext.gettext

local function _(msg)
  return gettext(msg)
end

local script_data = {}

script_data.metadata = {
  name = _("import filter manager"),
  purpose = _("manage import filters"),
  author = "Tobias Ellinghaus",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/official/import_filter_manager"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

local import_filter_list = {}
local n_import_filters = 1

-- allow changing the filter from the preferences
dt.preferences.register("import_filter_manager", "active_filter", "string",
  _("import filter"), _("the name of the filter used for importing images"), "")


-- the dropdown to select the active filter from the import dialog
local filter_dropdown = dt.new_widget("combobox")
{
  label = _("import filter"),
  editable = false,
  tooltip = _("import filters are applied after completion of the import dialog"),

  changed_callback = function(widget)
    dt.preferences.write("import_filter_manager", "active_filter", "string", widget.value)
  end,

  "" -- the first entry in the list is hard coded to "" so it's possible to have no filter
}
dt.gui.libs.import.register_widget(filter_dropdown)


-- this is just a wrapper which calls the active import filter
dt.register_event("ifm", "pre-import", function(event, images)
  local active_filter = dt.preferences.read("import_filter_manager", "active_filter", "string")
  if active_filter == "" then return end
  local callback = import_filter_list[active_filter]
  if callback then callback(event, images) end
end)


-- add a new global function to register import filters
dt.register_import_filter = function(name, callback)
  local active_filter = dt.preferences.read("import_filter_manager", "active_filter", "string")
  dt.print_log("registering import filter `" .. name .. "'")
  import_filter_list[name] = callback
  n_import_filters = n_import_filters  + 1
  filter_dropdown[n_import_filters] = name
  if name == active_filter then filter_dropdown.value = n_import_filters end
end

local function destroy()
  --noting to destroy
end

script_data.destroy = destroy

return script_data
-- vim: shiftwidth=2 expandtab tabstop=2 cindent
-- kate: tab-indents: off; indent-width 2; replace-tabs on; remove-trailing-space on;
