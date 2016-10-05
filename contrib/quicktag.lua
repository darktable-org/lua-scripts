--[[
    This file is part of darktable,
    copyright 2016 by Christian Kanzian.

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
   This script that will create shortcuts and add a modul in lighttable mode to quickly attach tags. You have to create this tags before in the tagging module

INSTALATION
 * copy this file in $CONFIGDIR/lua/ where CONFIGDIR is your darktable configuration directory
 * add the following line in the file $CONFIGDIR/luarc require "quicktag"

USAGE
 * set the shortcuts your in the preferences dialog
 * change the entries as needed
 
TODO
 * make number of quicktag entries dynamic
 * store tag entries in the hidden preferences

]]


local dt = require "darktable"
dt.configuration.check_version(...,{4,0,0})

-- register number of quicktags
--dt.preferences.register("quickTag",         
--                        "quickTagnumber",  
--                        "integer",                    -- type
--                        "number of quick tag fields",           -- label
--                        "number of quick tag fields from 2 to 10",   -- tooltip
--                        3,                            -- default
--                        2,                            -- min
--                     10)   

--local qnr = dt.preferences.read("quickTag", "quickTagnumber", "integer")			

-- set number of entries static now because i do not know howto create the modul dynamic
local qnr = 5

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
  
  for _,image in ipairs(sel_images) do
    dt.tags.attach(tagnr,image)
  end
  dt.print("tag \""..tag.."\" attached")
end


-- quicktag module

local tagentries = {}

for j=1,qnr do
  tagentries[#tagentries+1] = dt.new_widget("entry")
    {
    text = "qtest", 
    placeholder = "placeholder",
    is_password = true,
    editable = true,
    tooltip = "Tooltip Text",
    reset_callback = function(self) self.text = "test" end
    }
end

local label = dt.new_widget("label")
label.label = "MyLabel" -- This is an alternative way to the "{}" syntax to set a property 
--end

local button_tab = {}

for j=1,qnr do
  button_tab[#button_tab+1] = dt.new_widget("button") {
         label = "tag "..j,
         clicked_callback = function () tagattach(tostring(tagentries[j].text)) end}
end

     
--create modul static. it would be nice to place button and entry side by side
dt.register_lib(
  "quicktag",     -- Module name
  "quick tag",     -- name
  true,                -- expandable
  false,               -- resetable
  {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 490}},   -- containers
    
  dt.new_widget("box"){
    orientation = "vertical",
    button_tab[1],
    tagentries[1],
    button_tab[2],
    tagentries[2],
    button_tab[3],
    tagentries[3],
    button_tab[4],
    tagentries[4],
    button_tab[5],
    tagentries[5]},
  nil,-- view_enter
  nil -- view_leave
)

print(tostring(tagentries.text))

--local testtag = "qtest"
-- create shortcuts
for i=1,qnr do
  dt.register_event("shortcut", 
		   function(event, shortcut) tagattach(tostring(tagentries[i].text)) end,
		  "quick tag "..i)
end

-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: tab-indents: off; indent-width 2; replace-tabs on; remove-trailing-space on;