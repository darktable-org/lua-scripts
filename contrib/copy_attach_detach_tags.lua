--[[
    This file is part of darktable,
    copyright 2014-2015 by Christian Kanzian.

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

--[[
   (MULTI-)COPY ATTACH DETACH TAG 
   A simple script that will create three shortcuts to copy, attach and detach image tags.

INSTALATION
 * copy this file in $CONFIGDIR/lua/ where CONFIGDIR is your darktable configuration directory
 * add the following line in the file $CONFIGDIR/luarc require "copy_attach_detach_tags"

USAGE
 * set the shortcuts for copy, attach and detach in the preferences dialog
 * <your shortcut1> copy will create a list of tags from all selected images
 * <your shortcut2> attaches copied tags to selected images, whereby
   darktable internal tags starting with 'darktable|' will not be touched
 * <your shortcut3> detach removes all expect darktable internal tags from selected images

]]

local dt = require "darktable"
dt.configuration.check_version(...,{2,0,0},{3,0,0})

local image_tags = {}

local function mcopy_tags()
  local sel_images = dt.gui.action_images
  local tag_list_tmp = {}
  local hash = {}

  -- empty tag table before copy new tags
  image_tags = {}
  for _,image in ipairs(sel_images) do
      local image_tags_tmp = {}
      image_tags_tmp = dt.tags.get_tags(image)

      -- cumulate all tags from all selected images
      for _,v in pairs(image_tags_tmp) do
          table.insert(tag_list_tmp,v) end
      end

      --remove duplicate and 'darktable|' tags create final image_tags
      for _,k in ipairs(tag_list_tmp) do
        
         if not string.match(tostring(k), 'darktable|') then
           if not hash[k] then
             image_tags[#image_tags+1] = k
             hash[k] = true
           end
         end
      end

      dt.print("Image tags copied ...")
    return(image_tags)
  end
   
-- attach copied tags to all selected images
local function attach_tags()
  
  if next(image_tags) == nil then
    dt.print("No tags to attached, please copy tags first.")
  end
  
  local sel_images = dt.gui.action_images

  for _,image in ipairs(sel_images) do
    local present_image_tags = {}
    present_image_tags = dt.tags.get_tags(image)
    
    for _,ct in ipairs(image_tags) do
      -- check if image has tags and attach
      if next(present_image_tags) == nil then
        dt.tags.attach(ct,image)
      else
        for _,pt in ipairs(present_image_tags) do
          -- attach tag only if not already attached
          if pt ~= ct then
             dt.tags.attach(ct,image)
          end
        end
      end
    end
  end
 dt.print("Tags attached ...")
end




local function detach_tags()
  local sel_images = dt.gui.action_images

   for _,image in ipairs(sel_images) do
      local present_image_tags = {}
      present_image_tags = dt.tags.get_tags(image)
   
      for _,present_tag in ipairs(present_image_tags) do
        if not string.match(tostring(present_tag), 'darktable|')  then
          dt.tags.detach(present_tag,image)
        end
      end
   end
  dt.print("Tags removed from image(s).")
end

-- shortcut for copy
dt.register_event("shortcut",
                   mcopy_tags,
                   "copy tags from selected image(s)")

-- shortcut for attach
dt.register_event("shortcut",
                   attach_tags,
                   "attach tags to selected image(s)")

-- shortcut for detaching tags
dt.register_event("shortcut",
                   detach_tags,
                   "detach tags to selected image(s)")


-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: tab-indents: off; indent-width 2; replace-tabs on; remove-trailing-space on;
