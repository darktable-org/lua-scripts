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

]]

local darktable = require "darktable"
local debug = require "darktable.debug"

-- GUI entries
local old_tag = darktable.new_widget("entry") { tooltip = "Enter old tag" }
local new_tag = darktable.new_widget("entry") { tooltip = "Enter new tag" }

-- This function does the renaming
local function rename_tags(widget)
  -- If entries are empty, return
  if old_tag.text == '' then
    darktable.print ("Old tag can't be empty")
    return
  end
  if new_tag.text == '' then
    darktable.print ("New tag can't be empty")
    return
  end
  
  local Count = 0

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

  -- Search images for old tag
  dbcount = #darktable.database
  for i,image in ipairs(darktable.database) do
    -- Update progress bar
    job.percent = i / dbcount
    
    local tags = image:get_tags ()
    for _,t in ipairs (tags) do
      if t.name == old_tag.text then
        -- Found it, attach new tag
        image:attach_tag (nt)
        Count = Count + 1
      end
    end
  end

  -- Delete old tag, this removes it from all images
  darktable.tags.delete (ot)

  job.valid = false
  darktable.print ("Renamed tags for " .. Count .. " images")
  old_tag.editable = true
  new_tag.editable = true
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

local function rename_reset(widget)
    old_tag.text = ''
    new_tag.text = ''
end

local rename_widget = darktable.new_widget ("box") {
    orientation = "vertical",
    reset_callback = rename_reset,
    old_widget,
    new_widget,
    darktable.new_widget("button") { label = "Go", clicked_callback = rename_tags }
}


darktable.register_lib ("rename_tags", "rename tag", true, true, {[darktable.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 20},}, rename_widget, nil, nil)

