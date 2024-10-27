--[[
  ext_editor.lua - edit images with external editors

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
    ext_editor.lua - edit images with external editors

    This script provides helpers to edit image files with programs external to darktable. It adds:
      - a new target storage "collection". Image exported will be reimported to collection for further edit with external programs
      - a new module "external editors", visible in lightable and darkroom, to select a program from a list 
      - of up to 9 external editors and run it on a selected image (adjust this limit by changing MAX_EDITORS)
      - a set of lua preferences in order to configure name and path of up to 9 external editors
      - a set of lua shortcuts in order to quick launch the external editors
    
  USAGE
    * require this script from main lua file
  
    -- setup --
      * in "preferences/lua options" configure name and path/command of external programs
      * note that if a program name is left empty, that and all following entries will be ignored
      * in "preferences/shortcuts/lua" configure shortcuts for external programs (optional)
      * whenever programs preferences are changed, in external editors GUI, press "update list"

    -- use --
      * in the export dialog choose "collection" and select the format and bit depth for the
        exported image
      * press "export"
      * the exported image will be imported into collection and grouped with the original image
      
      * in lighttable, select an image for editing with en external program 
      * (or in darkroom for the image being edited):
      * in external editors GUI, select program and press "edit"
      * edit the image with the external editor, overwite the file, quit the external program
      * the selected image will be updated
      or
      * in external editors GUI, select program and press "edit a copy"
      * edit the image with the external editor, overwite the file, quit the external program
      * a copy of the selected image will be created and updated
      or
      * use the shortcut to edit the current image with the corresponding external editor
      * overwite the file, quit the external program
      * the image will be updated
    
    * warning: mouseover on lighttable/filmstrip will prevail on current image
    * this is the default DT behavior, not a bug of this script

  CAVEATS
    * MAC compatibility not tested
  
  BUGS, COMMENTS, SUGGESTIONS
    * send to Marco Carrarini, marco.carrarini@gmail.com
]]


local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local dtsys = require "lib/dtutils.system"


-- module name
local MODULE_NAME = "ext_editor"
du.check_min_api_version("7.0.0", MODULE_NAME) 

-- translation
local gettext = dt.gettext.gettext

local function _(msgid)
  return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("external editors"),
  purpose = _("edit images with external editors"),
  author = "Marco Carrarini, marco.carrarini@gmail.com",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/ext_editor"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

-- OS compatibility
local PS = dt.configuration.running_os == "windows" and  "\\"  or  "/"

-- namespace
local ee = {}
ee.module_installed = false
ee.event_registered = false
ee.widgets = {}


-- maximum number of external programs, can be increased to necessity
local MAX_EDITORS = 9

-- number of valid entries in the list of external programs
local n_entries


-- allowed file extensions for external editors
local allowed_file_types = {"JPG", "jpg", "JPEG", "jpeg", "TIF", "tif", "TIFF", "tiff", "EXR", "exr", "PNG", "png"}


-- last used editor initialization
if not dt.preferences.read(MODULE_NAME, "initialized", "bool") then
  dt.preferences.write(MODULE_NAME, "lastchoice", "integer", 0)
  dt.preferences.write(MODULE_NAME, "initialized", "bool", true)
end 
local lastchoice = 0


-- update lists of program names and paths, as well as combobox ---------------
local function UpdateProgramList(combobox, button_edit, button_edit_copy, update_button_pressed) 

  -- initialize lists
  program_names = {}
  program_paths = {}

  -- build lists from preferences
  local name
  local last = false
  n_entries = 0
  for i = 1, MAX_EDITORS do
    name = dt.preferences.read(MODULE_NAME, "program_name_"..i, "string")
    if (name == "" or name == nil) then last = true end
    if last then 
      if combobox[n_entries + 1] then combobox[n_entries + 1] = nil end -- remove extra combobox entries
    else 
      combobox[i] = i..": "..name
      program_names[i] = name
      program_paths[i] = df.sanitize_filename(dt.preferences.read(MODULE_NAME, "program_path_"..i, "string"))
      n_entries = i
    end
  end 

  lastchoice = dt.preferences.read(MODULE_NAME, "lastchoice", "integer")
  if lastchoice == 0 and n_entries > 0 then lastchoice = 1 end
  if lastchoice > n_entries then lastchoice = n_entries end
  dt.preferences.write(MODULE_NAME, "lastchoice", "integer", lastchoice)

  -- widgets enabled if there is at least one program configured
  combobox.selected = lastchoice 
  local active = n_entries > 0
      combobox.sensitive = active
      button_edit.sensitive = active
      button_edit_copy.sensitive = active

  if update_button_pressed then dt.print(string.format(_("%d editors configured"), n_entries)) end
end


-- callback for buttons "edit" and "edit a copy" ------------------------------
local function OpenWith(images, choice, copy) 
    
  -- check choice is valid, return if not
  if choice > n_entries then
    dt.print(_("not a valid choice"))
    return
  end

  -- check if one image is selected, return if not
  if #images ~= 1 then
    dt.print(_("please select one image"))
    return
  end
  
  local bin = program_paths[choice]
  local friendly_name = program_names[choice]

  if dt.configuration.running_os == "macos" then bin = "open -W -a "..bin end

  -- image to be edited
  local image
  i, image = next(images)
  local name = image.path..PS..image.filename

  -- check if image format is allowed
  local file_ext = df.get_filetype(image.filename)
  local allowed = false
  for i,v in pairs(allowed_file_types) do
    if v == file_ext then
      allowed = true
      break
    end
  end 
  if not allowed then
    dt.print(_("file type not allowed"))
    return
  end

  -- save image tags, rating and color
  local tags = {}
  for i, tag in ipairs(dt.tags.get_tags(image)) do
    if not (string.sub(tag.name, 1, 9) == "darktable") then table.insert(tags, tag) end
  end 
  local rating = image.rating
  local red = image.red
  local blue = image.blue
  local green = image.green
  local yellow = image.yellow
  local purple = image.purple

  -- new image
  local new_name = name
  local new_image = image
    
  if copy then

    -- create unique filename
    new_name = df.create_unique_filename(new_name)
        
    -- physical copy, check result, return if error
    local copy_success = df.file_copy(name, new_name)
    if not copy_success then
      dt.print(string.format(_("error copying file %s"), name))
      return
    end    
  end

  -- launch the external editor, check result, return if error
  local run_cmd = bin.." "..df.sanitize_filename(new_name) 
  dt.print(string.format(_("launching %s..."), friendly_name))
  local result = dtsys.external_command(run_cmd)
  if result ~= 0 then
    dt.print(string.format(_("error launching %s"), friendly_name))
    return
  end

  if copy then
    -- import in database and group
    new_image = dt.database.import(new_name)
    new_image:group_with(image)
  else 
    -- refresh the image view
    -- note that only image:drop_cache() is not enough to refresh view in darkroom mode
    -- therefore image must be deleted and reimported to force refresh

    -- find the grouping status
    local image_leader = image.group_leader
    local group_members = image:get_group_members()
    local new_leader
    local index = nil
    local found = false
    
    -- membership status, three different cases
    if image_leader == image then
      if  #group_members > 1 then
        -- case 1: image is leader in a group with more members
        while not found do
          index, new_leader = next(group_members, index)
          if new_leader ~= image_leader then found = true end
        end
        new_leader:make_group_leader()
        image:delete()
        if image.local_copy then image:drop_cache() end -- to fix fail to allocate cache error
        new_image = dt.database.import(name)
        new_image:group_with(new_leader)
        new_image:make_group_leader()
      else 
        -- case 2: image is the only member in group
        image:delete()
        if image.local_copy then image:drop_cache() end -- to fix fail to allocate cache error
        new_image = dt.database.import(name)
        new_image:group_with()
      end
    else 
      -- case 3: image is in a group but is not leader
      image:delete()
      if image.local_copy then image:drop_cache() end -- to fix fail to allocate cache error
      new_image = dt.database.import(name)
      new_image:group_with(image_leader)
    end
  end   

  -- restore image tags, rating and color
  for i, tag in ipairs(tags) do dt.tags.attach(tag, new_image) end
  new_image.rating = rating
  new_image.red = red
  new_image.blue = blue
  new_image.green = green
  new_image.yellow = yellow
  new_image.purple = purple

    -- select the new image
  local selection = {}
  table.insert(selection, new_image)
  dt.gui.selection(selection)

  -- refresh darkroom view
  if dt.gui.current_view().id == "darkroom" then
    dt.gui.views.darkroom.display_image(new_image)
  end
end


-- callback function for shortcuts --------------------------------------------
local function program_shortcut(event, shortcut)
  OpenWith(dt.gui.action_images, tonumber(string.sub(shortcut, -2)), false)
end


-- export images and reimport in collection -----------------------------------
local function export2collection(storage, image_table, extra_data) 

  local temp_name, new_name, new_image, move_success

  for image, temp_name in pairs(image_table) do

    -- images are first exported in temp folder then moved to collection folder

    -- create unique filename
    new_name = image.path..PS..df.get_filename(temp_name)
    new_name = df.create_unique_filename(new_name)

    -- move image to collection folder, check result, return if error
    move_success = df.file_move(temp_name, new_name)
    if not move_success then
      dt.print(string.format(_("error moving file %s"), temp_name))
      return
    end

    -- import in database and group
    new_image = dt.database.import(new_name)
    new_image:group_with(image.group_leader)
  end 
  
  dt.print(_("finished exporting"))
end


-- install the module in the UI -----------------------------------------------
local function install_module(dr)
  
  local views = {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 90}}
  if dr then 
    views = {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 90},
            [dt.gui.views.darkroom] = {"DT_UI_CONTAINER_PANEL_LEFT_CENTER", 100}}
  end
  
  if not ee.module_installed then
    -- register new module "external editors" in lighttable and darkroom ----
    dt.register_lib(
      MODULE_NAME,          
      _("external editors"),  
      true, -- expandable
      false,  -- resetable
      views,
      dt.new_widget("box") {
        orientation = "vertical",
        table.unpack(ee.widgets),
        },
      nil,  -- view_enter
      nil   -- view_leave
      )
    ee.module_installed = true
  end
end

local function destroy()
  for i = 1, MAX_EDITORS do
    dt.destroy_event(MODULE_NAME .. i, "shortcut") 
  end
  dt.destroy_storage("exp2coll")
  dt.gui.libs[MODULE_NAME].visible = false
end

local function restart()
  for i = 1, MAX_EDITORS do
    dt.register_event(MODULE_NAME .. i, "shortcut", 
      program_shortcut, string.format(_("edit with program %02d"), i)) 
  end
  dt.register_storage("exp2coll", _("collection"), nil, export2collection)
  dt.gui.libs[MODULE_NAME].visible = true
end

local function show()
  dt.gui.libs[MODULE_NAME].visible = true
end


-- combobox, with variable number of entries ----------------------------------
local combobox = dt.new_widget("combobox") {
  label = _("choose program"), 
  tooltip = _("select the external editor from the list"),
  changed_callback = function(self)
    dt.preferences.write(MODULE_NAME, "lastchoice", "integer", self.selected)
    end,
  ""
}


-- button edit ----------------------------------------------------------------
local button_edit = dt.new_widget("button") {
  label = _("edit"),
  tooltip = _("open the selected image in external editor"),
  --sensitive = false,
  clicked_callback = function()
    OpenWith(dt.gui.action_images, combobox.selected, false)
  end
}


-- button edit a copy ---------------------------------------------------------
local button_edit_copy = dt.new_widget("button") {
  label = _("edit a copy"),
  tooltip = _("create a copy of the selected image and open it in external editor"),
  clicked_callback = function()
    OpenWith(dt.gui.action_images, combobox.selected, true)
  end
}


-- button update list ---------------------------------------------------------
local button_update_list = dt.new_widget("button") {
  label = _("update list"),
  tooltip = _("update list of programs if lua preferences are changed"),
  clicked_callback = function()
    UpdateProgramList(combobox, button_edit, button_edit_copy, true)
  end
}


-- box for the buttons --------------------------------------------------------
-- it doesn't seem there is a way to make the buttons equal in size
local box1 = dt.new_widget("box") {
  orientation = "horizontal",
  button_edit,
  button_edit_copy,
  button_update_list
}


-- table with all the widgets --------------------------------------------------
table.insert(ee.widgets, combobox)
table.insert(ee.widgets, box1)


-- register new module, but only when in lighttable ----------------------------
local show_dr = dt.preferences.read(MODULE_NAME, "show_in_darkrooom", "bool")
if dt.gui.current_view().id == "lighttable" then
  install_module(show_dr)
else
  if not ee.event_registered then
    dt.register_event(
      MODULE_NAME, "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module(show_dr)
         end
      end
    )
    ee.event_registered = true
  end
end


-- initialize list of programs and widgets ------------------------------------ 
UpdateProgramList(combobox, button_edit, button_edit_copy, false) 


-- register new storage -------------------------------------------------------
dt.register_storage("exp2coll", _("collection"), nil, export2collection)


-- register the new preferences -----------------------------------------------
for i = MAX_EDITORS, 1, -1 do
  dt.preferences.register(MODULE_NAME, "program_path_"..i, "file", 
  string.format(_("executable for external editor %d"), i), 
  _("select executable for external editor")  , _("(none)"))
  
  dt.preferences.register(MODULE_NAME, "program_name_"..i, "string", 
  string.format(_("name of external editor %d"), i), 
  _("friendly name of external editor"), "")
end
dt.preferences.register(MODULE_NAME, "show_in_darkrooom", "bool", 
  _("show external editors in darkroom"), 
  _("check to show external editors module also in darkroom (requires restart)"), false)


-- register the new shortcuts -------------------------------------------------
for i = 1, MAX_EDITORS do
  dt.register_event(MODULE_NAME .. i, "shortcut", 
    program_shortcut, string.format(_("edit with program %02d"), i)) 
end


script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = show

return script_data

-- end of script --------------------------------------------------------------

-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: hl Lua;
