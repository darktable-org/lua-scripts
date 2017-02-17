--[[
    This file is part of darktable,
    Copyright (C) 2017 by Christian Kanzian

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
QUICKTAG
   For faster attaching your favorite tags, the script adds shortcuts and
   the module "quicktag" in lighttable mode with a changeable number of buttons.
   To each button a tag can be assigned. If the tags do not exist in your database,
   they are added to the database once they get the first time attached to an image.

   The number of buttons/shortcuts can be changed in the lua preferences.
   Changes in the number require a restart of darktable.

INSTALATION
   * copy this file in $CONFIGDIR/lua/ where CONFIGDIR is your darktable configuration directory
   * add the following line in the file $CONFIGDIR/luarc require "quicktag"

USAGE
   * set the number of quicktags between 2 and 10 in the preferences dialog and restart darktable
   * if wanted set the shortcuts in the preferences dialog
   * to add or change a quicktag, first select the old tag with the combobox "old quicktag",
     enter a new tag in the "new quicktag" filed and press "set quicktag"
   * use a shortcut or button to attach the tag to selected images

TODO
    * abbrevate button labels
  ]]


local dt = require "darktable"
local debug = require "darktable.debug"

dt.configuration.check_version(...,{3,0,0},{4,0,0},{5,0,0})

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
-- remove this for now, because the taglist can be set from within the modul now
--[[for j=1,qnr do
   dt.preferences.register("quickTag",
                        "quicktag"..j,
                        "string",                    -- type
                        "quick tag "..j,           -- label
                        "please create the tags before in the tagging module",   -- tooltip
                        ""                            -- default
                        )
  end
]]

-- get quicktags from the preferences
local quicktag_table = {}

local function read_pref_tags()
  for j=1,qnr do
    quicktag_table[j] = dt.preferences.read("quickTag", "quicktag"..j, "string")
    end
  end



-- quicktag function to attach tags
local function tagattach(tag,qtagnr)
  if tag == "" then
    dt.print("quicktag "..qtagnr.." empty, please set a tag")
    return true
  end
  
  local tagnr = dt.tags.find(tag)
 
--create tag if it does not exist 
  if tagnr == nil then
    dt.tags.create(tag)
    tagnr = dt.tags.find(tag)
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


-- create quicktag module elements
-- read tags from preferences for initialization
read_pref_tags()


local button = {}

-- function to create buttons with tags as labels
for j=1,qnr do
      button[#button+1] = dt.new_widget("button") {
         label = j..": "..quicktag_table[j],
         clicked_callback = function() tagattach(tostring(quicktag_table[j]),j) end}
    end


local old_quicktag = dt.new_widget("combobox"){
    label = "old quicktag:",
    tooltip = "select the quicktag to replace"
}

local function update_quicktag_list()
 -- read_pref_tags()
  for j=1,qnr do
      button[j].label = j..": "..quicktag_table[j]
      old_quicktag[j] = j..": "..quicktag_table[j]
  end
end

update_quicktag_list()

local new_quicktag = dt.new_widget("entry"){
    text = "",
    placeholder = "new quicktag ",
    is_password = true,
    editable = true,
    tooltip = "enter your tag here"
}

local set_quicktag_button = dt.new_widget("button") {
  label = "set quicktag",
  clicked_callback = function()
    local old_tag = quicktag_table[old_quicktag.selected]
    if new_quicktag.text == "" then
      dt.print("new quicktag is empty!")
    else
      quicktag_table[old_quicktag.selected] = new_quicktag.text
      dt.preferences.write("quickTag", "quicktag"..old_quicktag.selected, "string",  new_quicktag.text)
      dt.print("quicktag \""..old_tag.."\" replaced by \""..new_quicktag.text.."\"")
      update_quicktag_list()
      new_quicktag.text = ""
    end
  end,
}

local new_qt_widget = dt.new_widget ("box") {
    orientation = "horizontal",
    dt.new_widget("label") { label = "new quicktag" },
    new_quicktag,
    set_quicktag_button
}


-- back UI elements in a table
-- thanks to wpferguson for the hint
local widget_table = {}

for i=1,qnr do
  widget_table[#widget_table  + 1] =  button[i]
end

widget_table[#widget_table  + 1] = dt.new_widget("separator"){}
widget_table[#widget_table  + 1] = old_quicktag
widget_table[#widget_table  + 1] = new_qt_widget


--create module
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
		   function(event, shortcut) tagattach(tostring(quicktag_table[i])) end,
		  "quick tag "..i)
end

-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: tab-indents: off; indent-width 2; replace-tabs on; remove-trailing-space on;
