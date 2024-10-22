--[[
    This file is part of darktable,
    copyright (c) 2017 Jannis_V

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
Enable selection of untagged images (darktable|* tags are ignored)
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local gettext = dt.gettext.gettext

du.check_min_api_version("7.0.0", "select_untagged") 

local function _(msgid)
  return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("select untagged"),
  purpose = _("enable selection of untagged images"),
  author = "Jannis_V",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/select_untagged"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

local function stop_job(job)
  job.valid = false
end

local function select_untagged_images(event, images)
  job = dt.gui.create_job(_("select untagged images"), true, stop_job)

  local selection = {}

  for key,image in ipairs(images) do
    if(job.valid) then
      job.percent = (key - 1)/#images
      local tags =  dt.tags.get_tags(image)
      local hasTags = false
      for _,tag in ipairs(tags) do
        if not string.match(tag.name, "darktable|") then
          hasTags = true
        end
      end
      if hasTags == false then
        table.insert(selection, image)
      end
    else
      break
    end
  end

  job.valid = false
  -- return table of images to set the selection to
  return selection
end

local function destroy()
  dt.gui.libs.select.destroy_selection("select_untagged")
end

dt.gui.libs.select.register_selection(
  "select_untagged", _("select untagged"),
  select_untagged_images,
  _("select all images containing no tags or only tags added by darktable"))

script_data.destroy = destroy

return script_data
