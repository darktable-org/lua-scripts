--[[
    This file is part of darktable,
    Copyright (C) 2016 by Christian Kanzian

    Thanks to
    Copyright (C) 2016 Bill Ferguson

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
   QUICKTAGS
   This script that will create shortcuts, a list of tag entries in the preferences and
   add a modul in lighttable mode to quickly attach tags. If the tags do not exist in your databse,
   you have to create them in the tagging module.

   INSTALATION
   * copy this file in $CONFIGDIR/lua/ where CONFIGDIR is your darktable configuration directory
   * add the following line in the file $CONFIGDIR/luarc require "quicktag"

USAGE
   * set the shortcuts and prefered tags your in the preferences dialog
   * use the shortcuts or the buttons to attach the tags to selected images
   * change the entries as needed
   * use the "save taglist" button to update your preferences
 
TODO
   * enhance button and entry layout in the module
   * autosave tag entries
 ]]


local dt = require "darktable"
dt.configuration.check_version(...,{4,0,0})

-- register number of quicktags
dt.preferences.register("quickTag",         
                        "quickTagnumber",  
                        "integer",                    -- type
                        "number of quick tag fields",           -- label
                        "number of quick tag fields from 2 to 10 - needs a restart",   -- tooltip
                        3,                            -- default
                        2,                            -- min
                     10)   

local qnr = dt.preferences.read("quickTag", "quickTagnumber", "integer")

-- set quicktag in the preferences
for j=1,qnr do
   dt.preferences.register("quickTag",
                        "quicktag"..j,
                        "string",                    -- type
                        "quick tag "..j,           -- label
                        "please create the tags before in the tagging module",   -- tooltip
                        ""                            -- default
                        )
end

-- get quicktags from the preferences
local quicktag_table = {}

for j=1,qnr do
   quicktag_table[j] = dt.preferences.read("quickTag", "quicktag"..j, "string")
end


-- quicktag function to attach tags
local function tagattach(tag)
  if tag == nil then
    return true
  end
  
  local tagnr = dt.tags.find(tag)
  
  if tagnr == nil then
    dt.print("quick tag \""..tag.."\" not found in your taglist, please add it first!")
    return true
  end
  
  local sel_images = dt.gui.action_images
  
  if next(sel_images) == nil then
    dt.print("no images selected")
    return true
  end

  local counter = 0

  for _,image in ipairs(sel_images) do
     dt.tags.attach(tagnr,image)
     counter = counter+1
  end
  dt.print("tag \""..tag.."\" attached to "..counter.." images")
end


-- quicktag module elements
local tagentries = {}

for j=1,qnr do
  tagentries[#tagentries+1] = dt.new_widget("entry")
    {
    text = quicktag_table[j],
    placeholder = "your tag "..j,
    is_password = true,
    editable = true,
    tooltip = "enter your tag here",
   -- would be nice if the tags gets autosaved to the preferences?
   -- reset_callback =
    }
end


local button = {}

for j=1,qnr do
  button[#button+1] = dt.new_widget("button") {
         label = "apply tag "..j,
         clicked_callback = function() tagattach(tostring(tagentries[j].text)) end}
end

-- back UI elements in a table
-- thanks to wpferguson for the hint
local widget_table = {}

for i=1,qnr do
  widget_table[#widget_table  + 1] = tagentries[i]
  widget_table[#widget_table + 1] = button[i]
end

local dump_to_preferences = dt.new_widget("button") {
         label = "save taglist",
         tooltip = "update the taglist in the preferences",
         clicked_callback = function()
           for j=1,qnr do
             dt.preferences.write("quickTag", "quicktag"..j, "string",  tagentries[j].text)
           end
     end}

-- add to dump button to widget_table
widget_table[#widget_table  + 1] = dt.new_widget("separator"){}
widget_table[#widget_table  + 1] = dump_to_preferences


     
--create modul static. it would be nice to place button and entry side by side
dt.register_lib(
  "quicktag",     -- Module name
  "quick tag",     -- name
  true,                -- expandable
  false,               -- resetable
  {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 490}},
    
  dt.new_widget("box"){
    orientation = "vertical",
    table.unpack(widget_table),

  },
  nil,-- view_enter
  nil -- view_leave
)

-- create shortcuts
for i=1,qnr do
  dt.register_event("shortcut", 
		   function(event, shortcut) tagattach(tostring(tagentries[i].text)) end,
		  "quick tag "..i)
end

-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: tab-indents: off; indent-width 2; replace-tabs on; remove-trailing-space on;
