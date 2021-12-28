--[[
  Copyright (c) 2016 Sebastian Witt <se.witt@gmx.net>
  Copyright (c) 2018 Bill Ferguson <wpferguson@gmail.com>
]]
--[[
Rename tags

AUTHOR
Sebastian Witt (se.witt@gmx.net)

INSTALLATION
* copy this file in $CONFIGDIR/lua/ where CONFIGDIR
is your darktable configuration directory
* add the following line in the file $CONFIGDIR/luarc
  require "rename-tags"

USAGE
* In lighttable there is a new entry: 'rename tag'
* Enter old tag (this one gets deleted!)
* Enter new tag name

LICENSE
GPLv2

Changes
* 20180912 - Did an RTFM and read a bug (12277, thanks Christian G) that showed 
  a way to get the images containing the old tag one by one instead of searching 
  the entire database.  Changed rename_tags() function to use this method.
]]

local darktable = require "darktable"
local du = require "lib/dtutils"
local debug = require "darktable.debug"

-- check API version
du.check_min_api_version("7.0.0", "rename-tags") 
du.deprecated("contrib/rename-tags.lua","darktable release 4.0")

-- return data structure for script_manager

local script_data = {}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again

local rt = {}
rt.module_installed = false
rt.event_registered = false

-- GUI entries
local old_tag = darktable.new_widget("entry") { tooltip = "Enter old tag" }
local new_tag = darktable.new_widget("entry") { tooltip = "Enter new tag" }

local function rename_reset()
    old_tag.text = ''
    new_tag.text = ''
end

-- This function does the renaming
local function rename_tags()
  -- If entries are empty, return
  if old_tag.text == '' then
    darktable.print ("Old tag can't be empty")
    return
  end
  if new_tag.text == '' then
    darktable.print ("New tag can't be empty")
    return
  end
  
  local count = 0

  -- Check if old tag exists
  local ot = darktable.tags.find (old_tag.text)
  
  if not ot then
    darktable.print ("Old tag does not exist")
    return
  end

  -- Show job
  local job = darktable.gui.create_job ("Renaming tag", true)
  
  old_tag.editable = false
  new_tag.editable = false

  -- Create if it does not exists
  local nt = darktable.tags.create (new_tag.text)

  -- Get number of images for old tag
  local dbcount = #ot

  -- loop through the images containing the old tag, and attach the new tag
  for i=1, #ot do
    -- Update progress bar
    job.percent = i / dbcount
    ot[i]:attach_tag(nt)
    count = count + 1
  end

  -- Delete old tag, this removes it from all images
  darktable.tags.delete (ot)

  job.valid = false
  darktable.print ("Renamed tags for " .. count .. " images")
  old_tag.editable = true
  new_tag.editable = true

  -- reset the gui fields

  rename_reset()
end

local function install_module()
  if not rt.module_installed then
    darktable.register_lib ("rename_tags", "rename tag", true, true, {[darktable.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 20},}, rt.rename_widget, nil, nil)
    rt.module_installed = true
  end
end

local function destroy()
  darktable.gui.libs["rename_tags"].visible = false
end

local function restart()
  darktable.gui.libs["rename_tags"].visible = true
end

-- GUI
local old_widget = darktable.new_widget ("box") {
    orientation = "horizontal",
    darktable.new_widget("label") { label = "Old tag" },
    old_tag
}

local new_widget = darktable.new_widget ("box") {
    orientation = "horizontal",
    darktable.new_widget("label") { label = "New tag" },
    new_tag
}

rt.rename_widget = darktable.new_widget ("box") {
    orientation = "vertical",
    reset_callback = rename_reset,
    old_widget,
    new_widget,
    darktable.new_widget("button") { label = "Go", clicked_callback = rename_tags }
}

if darktable.gui.current_view().id == "lighttable" then
  install_module()
else
  if not rt.event_registered then
    darktable.register_event(
      "rename_tags", "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module()
         end
      end
    )
    rt.event_registered = true
  end
end

script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = restart

return script_data


