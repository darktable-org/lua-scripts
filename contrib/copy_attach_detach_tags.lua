--[[
    This file is part of darktable,
    Copyright 2014-2016 by Christian Kanzian
    Copyright 2016 by Holger Klemm

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
   (MULTI-)COPY ATTACH DETACH REPLACE TAGS
   This script that will create four shortcuts and add a modul in lighttable mode to copy,
   paste, replace and remove tags from images.

INSTALATION
 * copy this file in $CONFIGDIR/lua/ where CONFIGDIR is your darktable configuration directory
 * add the following line in the file $CONFIGDIR/luarc require "copy_attach_detach_tags"

USAGE
 * set the shortcuts for copy, attach and detach in the preferences dialog
 * <your shortcut1> copy will create a list of tags from all selected images
 * <your shortcut2> paste copied tags to selected images, whereby
   darktable internal tags starting with 'darktable|' will not be touched
 * <your shortcut3> removes all expect darktable internal tags from selected images
 * <your shortcut4> replaces all tags expect darktable internals
 * A module reset will empty the clipboard
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local debug = require "darktable.debug"

local gettext = dt.gettext.gettext

du.check_min_api_version("7.0.0", "copy_attach_detach_tags") 

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("copy attach detach tags"),
  purpose = _("shortcuts to copy, paste, replace, or remove tags from images"),
  author = "Christian Kanzian",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/copy_attach_detach_tags"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

local cadt = {}
cadt.module_installed = false
cadt.event_registered = false
cadt.widget_table = {}


local image_tags = {}


local taglist_label = dt.new_widget("label"){selectable = true, ellipsize = "middle", halign = "start"}
taglist_label.label = ""

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

      dt.print(_('image tags copied ...'))

     --create UI tag list
     local taglist = ""

     for _,tag in ipairs(image_tags) do
       if taglist == "" then
          taglist = tostring(tag)
       else
          taglist = taglist.."\n"..tostring(tag)
        end
       end

	taglist_label.label = taglist

     return(image_tags)
  end

-- attach copied tags to all selected images
local function attach_tags()

  if next(image_tags) == nil then
    dt.print(_('no tag to attach, please copy tags first.'))
    return true
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
 dt.print(_('tags attached ...'))
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
  dt.print(_('tags removed from image(s).'))
end

local function replace_tags()
  detach_tags()
  attach_tags()
  dt.print(_('tags replaced'))
end

local function install_module()
  if not cadt.module_installed then
    dt.register_lib("tagging_addon",_('tagging addon'),true,true,{
        [dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER",500}
        },
        dt.new_widget("box") {
      --    orientation = "vertical",
          reset_callback = function()
                        taglist_label.label = ""
                        image_tags = {}
                        end,
          table.unpack(cadt.widget_table),
          },
       nil,
       nil
      )
    cadt.module_installed = true
  end
end

local function destroy()
  dt.destroy_event("cadt_ct", "shortcut")
  dt.destroy_event("cadt_at", "shortcut")
  dt.destroy_event("cadt_dt", "shortcut")
  dt.destroy_event("cadt_rt", "shortcut")
  dt.gui.libs["tagging_addon"].visible = false
end

local function restart()
  -- shortcut for copy
  dt.register_event("cadt_ct", "shortcut",
                     mcopy_tags,
                     _('copy tags from selected image(s)'))

  -- shortcut for attach
  dt.register_event("cadt_at", "shortcut",
                     attach_tags,
                     _('paste tags to selected image(s)'))

  -- shortcut for detaching tags
  dt.register_event("cadt_dt", "shortcut",
                     detach_tags,
                     _('remove tags from selected image(s)'))

                     -- shortcut for replace tags
  dt.register_event("cadt_rt", "shortcut",
                     replace_tags,
                     _('replace tags from selected image(s)'))
  dt.gui.libs["tagging_addon"].visible = true
end

local function show()
  dt.gui.libs["tagging_addon"].visible = true
end

-- create modul Tagging addons
taglist_label.reset_callback = mcopy_tags

-- create buttons and elements
local taglabel = dt.new_widget("label") {
         label = _('tag clipboard'),
         selectable = false,
         ellipsize = "middle",
         halign = "start"}

local box1 = dt.new_widget("box"){
                  orientation = "horizontal",
                  dt.new_widget("button") {
                    label = _('multi copy tags'),
                    tooltip = _('copy tags from selected image(s)'),
                    clicked_callback = mcopy_tags},
                  dt.new_widget("button") {
		    tooltip = _('paste tags to selected image(s)'),
                    label = _('paste tags'),
                    clicked_callback = attach_tags}
                  }

local box2 = dt.new_widget("box"){
                  orientation = "horizontal",
                  dt.new_widget("button") {
                    label = _('replace tags'),
		    tooltip = _('replace tags from selected image(s)'),
                    clicked_callback = replace_tags},
                  dt.new_widget("button") {
                    label = _('remove all tags'),
		    tooltip = _('remove tags from selected image(s)'),
                    clicked_callback = detach_tags}
                  }

local sep = dt.new_widget("separator"){}

-- pack elements into widget table for a nicer layout

cadt.widget_table[1] = box1
cadt.widget_table[#cadt.widget_table+1] = box2

cadt.widget_table[#cadt.widget_table+1] = sep
cadt.widget_table[#cadt.widget_table+1] = taglabel
cadt.widget_table[#cadt.widget_table+1] = taglist_label


-- create modul
if dt.gui.current_view().id == "lighttable" then
  install_module()
else
  if not cadt.event_registered then
    dt.register_event(
      "cadt", "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module()
         end
      end
    )
    cadt.event_registered = true
  end
end


-- shortcut for copy
dt.register_event("cadt_ct", "shortcut",
                   mcopy_tags,
                   _('copy tags from selected image(s)'))

-- shortcut for attach
dt.register_event("cadt_at", "shortcut",
                   attach_tags,
                   _('paste tags to selected image(s)'))

-- shortcut for detaching tags
dt.register_event("cadt_dt", "shortcut",
                   detach_tags,
                   _('remove tags from selected image(s)'))

                   -- shortcut for replace tags
dt.register_event("cadt_rt", "shortcut",
                   replace_tags,
                   _('replace tags from selected image(s)'))

script_data.destroy = destroy 
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = show

return script_data
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: tab-indents: off; indent-width 2; replace-tabs on; remove-trailing-space on;
