--[[
    This file is part of darktable,
    Copyright (C) 2017 by Christian Kanzian

    Thanks to
    Copyright (C) 2016 Bill Ferguson
    Copyright (C) 2017 Tobias Jakobs

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
]]


local dt = require "darktable"
local du = require "lib/dtutils"
local debug = require "darktable.debug"

du.check_min_api_version("7.0.0", "quicktag") 

local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("quick tag"),
  purpose = _("use buttons to quickly apply tags assigned to them"),
  author = "Christian Kanzian",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/quicktag"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again

local qt = {}
qt.module_installed = false
qt.event_registered = false
qt.widget_table = {}

-- maximum length of button labels
dt.preferences.register("quickTag",
                        "labellength",
                        "integer",                    -- type
                        _("max. length of button labels"),           -- label
                        _("may range from 15 to 60 - needs a restart"),   -- tooltip
                       25,                            -- default
                       15,                            -- min
                      60)



local max_label_length = dt.preferences.read("quickTag", "labellength", "integer")

-- register number of quicktags
dt.preferences.register("quickTag",
                        "quickTagnumber",
                        "integer",                    -- type
                        _("number of quicktag fields"),           -- label
                        _("may range from 2 to 20 - needs a restart"),   -- tooltip
                        5,                            -- default
                        2,                            -- min
                        20)

local qnr = dt.preferences.read("quickTag", "quickTagnumber", "integer")



-- get quicktags from the preferences
local quicktag_table = {}


local function read_pref_tags()
  for j=1,qnr do
    quicktag_table[j] = dt.preferences.read("quickTag", "quicktag"..j, "string")
    end
  end


local quicktag_label = {}


local function abbrevate_tags(t)
  for i=1,qnr do
    local taglength = string.len(t[i])
    if taglength > max_label_length then
      local max_2 = math.floor(max_label_length/2)
      quicktag_label[i] = string.sub(t[i],0,max_2).."..."..string.sub(t[i],taglength - max_2)
    else
      quicktag_label[i] = t[i]
    end
    -- print(quicktag_label[i])
  end
end


-- quicktag function to attach tags
local function tagattach(tag,qtagnr)
  if tag == "" then
    dt.print(string.format(_("quicktag %i is empty, please set a tag"), qtagnr))
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
    dt.print(_("no images selected"))
    return true
  end

  local counter = 0

  for _,image in ipairs(sel_images) do
     dt.tags.attach(tagnr,image)
     counter = counter+1
  end
  dt.print(string.format(_("tag \"%s\" attached to %i image(s)"), tag, counter))
end


-- create quicktag module elements
-- read tags from preferences for initialization
read_pref_tags()
abbrevate_tags(quicktag_table)


local button = {}

-- function to create buttons with tags as labels
for j = 1, qnr do
      button[#button+1] = dt.new_widget("button") {
         label = j..": "..quicktag_table[j],
         clicked_callback = function() tagattach(tostring(quicktag_table[j]),j) end}
    end


local old_quicktag = dt.new_widget("combobox"){
    label = _("old tag"),
    tooltip = _("select the quicktag to replace")
}

local function update_quicktag_list()
  -- abrevate long tags for the labels
  abbrevate_tags(quicktag_table)
  for j=1,qnr do
      button[j].label = j..": "..quicktag_label[j]
      old_quicktag[j] = j..": "..quicktag_table[j]
  end
end

local function install_module()
  if not qt.module_installed then
    dt.register_lib(
      "quicktag",     -- Module name
      _("quick tag"),     -- name
      true,                -- expandable
      false,               -- resetable
      {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 490}},

      dt.new_widget("box"){
        orientation = "vertical",
        table.unpack(qt.widget_table),

      },
      nil,-- view_enter
      nil -- view_leave
    )
    qt.module_installed = true
  end
end

local function destroy()
  dt.gui.libs["quicktag"].visible = false
  for i=1,qnr do
    dt.destroy_event("quicktag " .. tostring(i), "shortcut")
  end
end

local function restart()
  dt.gui.libs["quicktag"].visible = true
  for i = 1 ,qnr do
  dt.register_event("quicktag", "shortcut",
       function(event, shortcut) tagattach(tostring(quicktag_table[i])) end,
      string.format(_("quicktag %i"),i))
  end
end

local function show()
  dt.gui.libs["quicktag"].visible = true
end




update_quicktag_list()

local new_quicktag = dt.new_widget("entry"){
    text = "",
    placeholder = _("new tag"),
    is_password = false,
    editable = true,
    tooltip = _("enter your tag here")
}

local set_quicktag_button = dt.new_widget("button") {
  label = _("set tag"),
  clicked_callback = function()
    local old_tag = quicktag_table[old_quicktag.selected]
    if new_quicktag.text == "" then
      dt.print(_("new quicktag is empty!"))
    else
      quicktag_table[old_quicktag.selected] = new_quicktag.text
      dt.preferences.write("quickTag", "quicktag"..old_quicktag.selected, "string",  new_quicktag.text)
      dt.print(string.format(_("quicktag \"%s\" replaced by \"%s\""), old_tag, new_quicktag.text))
      update_quicktag_list()
      new_quicktag.text = ""
    end
  end,
}

local new_qt_widget = dt.new_widget ("box") {
    orientation = "horizontal",
    dt.new_widget("label") { label = _("new tag") },
    new_quicktag,
    set_quicktag_button
}


-- back UI elements in a table
-- thanks to wpferguson for the hint

for i=1,qnr do
  qt.widget_table[#qt.widget_table  + 1] =  button[i]
end

qt.widget_table[#qt.widget_table  + 1] = dt.new_widget("separator"){}
qt.widget_table[#qt.widget_table  + 1] = old_quicktag
qt.widget_table[#qt.widget_table  + 1] = new_qt_widget


--create module
if dt.gui.current_view().id == "lighttable" then
  install_module()
else
  if not qt.event_registered then
    dt.register_event(
      "quicktag", "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module()
         end
      end
    )
    qt.event_registered = true
  end
end

-- create shortcuts
for i=1,qnr do
  dt.register_event("quicktag " .. tostring(i), "shortcut",
		   function(event, shortcut) tagattach(tostring(quicktag_table[i])) end,
		  string.format(_("quick tag %i"),i))
end

script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = show

return script_data

-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: tab-indents: off; indent-width 2; replace-tabs on; remove-trailing-space on;
