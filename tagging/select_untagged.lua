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
local gettext = dt.gettext

du.check_min_api_version("3.0.0", "select_untagged") 

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("select_untagged",dt.configuration.config_dir.."/lua/locale/")
local CURR_API_STRING = dt.configuration.api_version_string

local function _(msgid)
  return gettext.dgettext("select_untagged", msgid)
end

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

if CURR_API_STRING >= "6.2.2" then
  dt.gui.libs.select.register_selection(
    "select_untagged", _("select untagged"),
    select_untagged_images,
    _("select all images containing no tags or only tags added by darktable"))
else
  dt.gui.libs.select.register_selection(
    _("select untagged"),
    select_untagged_images,
    _("select all images containing no tags or only tags added by darktable"))
end