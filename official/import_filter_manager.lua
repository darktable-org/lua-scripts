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

local import_filter_list = {}
local n_import_filters = 1

-- allow changing the filter from the preferences
dt.preferences.register("import_filter_manager", "active_filter", "string",
  "import filter", "the name of the filter used for importing images", "")


-- the dropdown to select the active filter from the import dialog
local filter_dropdown = dt.new_widget("combobox")
{
  label = "import filter",
  editable = false,

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


-- vim: shiftwidth=2 expandtab tabstop=2 cindent
-- kate: tab-indents: off; indent-width 2; replace-tabs on; remove-trailing-space on;
