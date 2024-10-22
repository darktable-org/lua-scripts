--[[
    This file is part of darktable,
    copyright (c) 2015-2016 Tobias Ellinghaus & Christian Mandel

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
EXAMPLE IMPORT FILTERS
This script goes along with the import filter manager. It adds two filters:
* ignore jpegs: this one does the same as the existing option in the import dialog
                and just skips all JPEGs during import.
* prefer raw over jpeg: this one is a bit more elaborate, it ignores JPEGs when there
                        is also another file with the same basename, otherwise it
                        allows JPEGs, too.

USAGE
* require this script from your main lua file AFTER import_filter_manager.lua
]]

local dt = require "darktable"

local gettext = dt.gettext.gettext

local function _(msg)
  return gettext(msg)
end

local script_data = {}

script_data.metadata = {
  name = _("import filters"),
  purpose = _("import filtering"),
  author = "Tobias Ellinghaus & Christian Mandel",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/official/import_filters"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

-- we get fed a sorted list of filenames. just setting images to ignore to nil is enough

-- ignore jpeg
dt.register_import_filter("ignore jpegs", function(event, images)
  dt.print_log("ignoring all jpegs")
  for i, img in ipairs(images) do
    local extension = img:match("[^.]*$"):upper()
    if (extension == "JPG") or (extension == "JPEG") then
      images[i] = nil
    end
  end
end)


-- ignore jpeg iff another format for the image is found
dt.register_import_filter("prefer raw over jpeg", function(event, images)
  dt.print_error("prefering raw over jpeg")
  local current_base = ""
  local jpg_indices = {}
  local other_format_found = false

  -- add dummy image to force processing for the last image
  local last_index
  table.insert(images, "")

  for i, img in ipairs(images) do
    local extension = img:match("[^.]*$"):upper()
    local base = img:match("^.*[.]")

    if base ~= current_base then
      -- we are done with the base name, act according to what we found out
      if other_format_found then
        for _, jpg in ipairs(jpg_indices) do
          images[jpg] = nil
        end
      end
      current_base = base
      other_format_found = false
      for k,_ in pairs(jpg_indices) do jpg_indices[k] = nil end
    end

    -- remember what we have here to act accordingly after all instances of this base name were checked
    if (extension == "JPG") or (extension == "JPEG") then
      table.insert(jpg_indices, i)
    else
      other_format_found = true
    end

    last_index = i
  end

  -- remove dummy image from list (just to make sure, it works even with keeping
  -- the dummy but that may break in the future), table.remove(images) does not
  -- work reliable because it can fail for sparse tables
  images[last_index] = nil

end)

local function destroy()
  -- nothing to destroy
end

script_data.destroy = destroy

return script_data

-- vim: shiftwidth=2 expandtab tabstop=2 cindent
-- kate: tab-indents: off; indent-width 2; replace-tabs on; remove-trailing-space on;
