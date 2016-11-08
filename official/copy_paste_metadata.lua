--[[
    This file is part of darktable,
    copyright (c) 2016 Tobias Ellinghaus

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
ADD SUPPORT FOR COPYING METADATA+RATING+COLOR LABELS+TAGS BETWEEN IMAGES
This script adds keyboard shortcuts and buttons to copy/paste metadata between images.

USAGE
  * require this script from your main lua file
  * it adds buttons to the selected images module
  * it adds two keyboard shortcuts
]]

local dt = require "darktable"

dt.configuration.check_version(...,{3,0,0},{4,0,0})

-- set this to "false" if you don't want to overwrite metadata fields
-- (title, description, creator, publisher and rights) that are already set
local overwrite = true

local have_data = false
local rating = 1
local red = false
local green = false
local yellow = false
local blue = false
local purple = false
local title = ""
local description = ""
local creator = ""
local publisher = ""
local rights = ""
local tags = {}

local function copy(image)
  if not image then
    have_data = false
  else
    have_data = true
    rating = image.rating
    red = image.red
    green = image.green
    yellow = image.yellow
    blue = image.blue
    purple = image.purple
    title = image.title
    description = image.description
    creator = image.creator
    publisher = image.publisher
    rights = image.rights
    tags = {}
    for _, tag in ipairs(image:get_tags()) do
      if not (string.sub(tag.name, 1, string.len("darktable|")) == "darktable|") then
        table.insert(tags, tag)
      end
    end
  end
end

local function paste(images)
  if have_data then
    for _, image in ipairs(images) do
      image.rating = rating
      image.red = red
      image.green = green
      image.yellow = yellow
      image.blue = blue
      image.purple = purple
      if image.title == "" or overwrite then
        image.title = title
      end
      if image.description == "" or overwrite then
        image.description = description
      end
      if image.creator == "" or overwrite then
        image.creator = creator
      end
      if image.publisher == "" or overwrite then
        image.publisher = publisher
      end
      if image.rights == "" or overwrite then
        image.rights = rights
      end
      for _, tag in ipairs(tags) do
        image:attach_tag(tag)
      end
    end
  end
end

dt.gui.libs.image.register_action(
  "copy metadata",
  function(event, images) copy(images[1]) end,
  "copy metadata of the first selected image"
)

dt.gui.libs.image.register_action(
  "paste metadata",
  function(event, images) paste(images) end,
  "paste metadata to the selected images"
)

dt.register_event(
  "shortcut",
  function(event, shortcut) copy(dt.gui.action_images[1]) end,
  "copy metadata"
)

dt.register_event(
  "shortcut",
  function(event, shortcut) paste(dt.gui.action_images) end,
  "paste metadata"
)
