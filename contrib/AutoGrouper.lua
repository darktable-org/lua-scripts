--[[AutoGrouper plugin for darktable

  copyright (c) 2019  Kevin Ertel
  
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

--[[About this Plugin
This plugin adds the module "Auto Group" to darktable's lighttable view

----REQUIRED SOFTWARE----
None

----USAGE----
Install: (see here for more detail: https://github.com/darktable-org/lua-scripts )
 1) Copy this file in to your "lua/contrib" folder where all other scripts reside. 
 2) Require this file in your luarc file, as with any other dt plug-in

Set a gap amount in second which will be used to determine when images should no 
longer be added to a group. If an image is more then the specified amount of time
from the last image in the group it will not be added. Images without timestamps 
in exif data will be ignored.

There are two buttons. One allows the grouping to be performed only on the currently
selected images, the other button performs grouping on the entire active collection
]]

local dt = require "darktable"
local du = require "lib/dtutils"

du.check_min_api_version("7.0.0", "AutoGrouper")

local MOD = 'autogrouper'

local gettext = dt.gettext.gettext

local function _(msgid)
  return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("auto group"),
  purpose = _("automatically group images by time interval"),
  author = "Kevin Ertel",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/AutoGrouper/"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

local Ag = {}
Ag.module_installed = false
Ag.event_registered = false

local GUI = {
  gap =        {},
  selected =   {},
  collection = {}
}


local function InRange(test, low, high) --tests if test value is within range of low and high (inclusive)
  if test >= low and test <= high then
    return true
  else
    return false
  end
end

local function CompTime(first, second) --compares the timestamps and returns true if first was taken before second
  first_time = first.exif_datetime_taken
  if string.match(first_time, '[0-9]') == nil then first_time = '9999:99:99 99:99:99' end
  first_time = tonumber(string.gsub(first_time, '[^0-9]*',''))
  second_time = second.exif_datetime_taken
  if string.match(second_time, '[0-9]') == nil then second_time = '9999:99:99 99:99:99' end
  second_time = tonumber(string.gsub(second_time, '[^0-9]*',''))
  return first_time < second_time
end

local function SeperateTime(str) --seperates the timestamp into individual components for used with OS.time operations
  local cleaned = string.gsub(str, '[^%d]',':')
  cleaned = string.gsub(cleaned, '::*',':')  --YYYY:MM:DD:hh:mm:ss
  local year = string.sub(cleaned,1,4)
  local month = string.sub(cleaned,6,7)
  local day = string.sub(cleaned,9,10)
  local hour = string.sub(cleaned,12,13)
  local min = string.sub(cleaned,15,16)
  local sec = string.sub(cleaned,18,19)
  return {year = year, month = month, day = day, hour = hour, min = min, sec = sec}
end

local function GetTimeDiff(curr_image, prev_image) --returns the time difference (in sec.) from current image and the previous image
  local curr_time = SeperateTime(curr_image.exif_datetime_taken)
  local prev_time = SeperateTime(prev_image.exif_datetime_taken)
  return os.time(curr_time)-os.time(prev_time)
end

local function main(on_collection)
  local images = {}
  if on_collection then 
    local col_images = dt.collection
    for i,image in ipairs(col_images) do --copy images to a standard table, table.sort barfs on type dt_lua_singleton_image_collection
      table.insert(images,i,image)
    end
  else
    images = dt.gui.selection()
  end
  dt.preferences.write(MOD, 'active_gap', 'integer', GUI.gap.value)
  if #images < 2 then 
    dt.print('please select at least 2 images')
    return
  end
  table.sort(images, function(first, second) return CompTime(first,second) end)  --sort images by timestamp
  
  for i, image in ipairs(images) do
    if i == 1 then 
      prev_image = image
      image:make_group_leader()
    elseif string.match(image.exif_datetime_taken, '[%d]') ~= nil then --make sure current image has a timestamp, if so check if it is within the user specified gap value and add to group
      local curr_image = image
      if GetTimeDiff(curr_image, prev_image) <= GUI.gap.value then
        images[i]:group_with(images[i-1].group_leader)
      end
      prev_image = curr_image
    end
  end
end

local function install_module()
  if not Ag.module_installed then
    dt.print_log("installing module")
    dt.register_lib(
      MOD,    -- Module name
      _('auto group'),    -- name
      true,   -- expandable
      true,   -- resetable
      {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 99}},   -- containers
      dt.new_widget("box"){
        orientation = "vertical",
        GUI.gap,
        GUI.selected,
        GUI.collection
      }
    )
    Ag.module_installed = true
    dt.print_log("module installed")
    dt.print_log("styles module visibility is " .. tostring(dt.gui.libs["styles"].visible))
  end
end

local function destroy()
  dt.gui.libs[MOD].visible = false
end

local function restart()
  dt.gui.libs[MOD].visible = true
end

-- GUI --
temp = dt.preferences.read(MOD, 'active_gap', 'integer')
if not InRange(temp, 1, 86400) then temp = 3 end
GUI.gap = dt.new_widget('slider'){
  label = _('group gap [sec.]'),
  tooltip = _('minimum gap, in seconds, between groups'),
  soft_min = 1,
  soft_max = 60,
  hard_min = 1,
  hard_max = 86400,
  step = 1,
  digits = 0,
  value = temp,
  reset_callback = function(self) 
    self.value = 3
  end
}
GUI.selected = dt.new_widget("button"){
  label = _('auto group: selected'),
  tooltip =_('auto group selected images'),
  clicked_callback = function() main(false) end
}
GUI.collection = dt.new_widget("button"){
  label = _('auto group: collection'),
  tooltip =_('auto group the entire collection'),
  clicked_callback = function() main(true) end
}

if dt.gui.current_view().id == "lighttable" then
  install_module()
else
  if not Ag.event_registered then
    dt.register_event(
     "AutoGrouper", "view-changed",
     function(event, old_view, new_view)
      if new_view.name == "lighttable" and old_view.name == "darkroom" then
        install_module()
       end
    end
  )
  Ag.event_registered = true
  end
end

script_data.destroy = destroy
script_data.destroy_method = "hide"
script_data.restart = restart
script_data.show = restart

return script_data
