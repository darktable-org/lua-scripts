--[[
  TRANSFER HIERARCHY
  Allows the moving or copying of images from one directory
  tree to another, while preserving the existing hierarchy.

  AUTHOR
  August Schwerdfeger (august@schwerdfeger.name)

  ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
  None.

  USAGE
  darktable's native operations for moving and copying images in
  batches allow only one directory to be specified as the destination
  for each batch. Those wanting to move or copy images from a _hierarchy_
  of directories within darktable while preserving the directory structure,
  must take the laborious step of performing the operation one individual
  directory at a time.

  This module allows the intact moving and copying of whole directory trees.
  It was designed for the specific use case of rapidly transferring images
  from a customary source (e.g., a staging directory on the local disk)
  to a customary destination (e.g., a directory on a NAS device).

  Instructions for operation:

  1. Select the set of images you want to copy.

  2. Click the "calculate" button. This will calculate the
     lowest directory in the hierarchy that contains every selected
     file (i.e., the common prefix of all the images' pathnames), and
     write its path into the "existing root" text box.

  3. If (a) you have specified the "customary source root" and "customary
     destination root" preferences, and (b) the selected images are all
     contained under the directory specified as the customary source
     root, then the "root of destination" text box will also be
     automatically filled out.

     For example, suppose that you have specified '/home/user/Staging'
     as your customary source root and '/mnt/storage' as your customary
     destination root. If all selected images fell under the directory
     '/home/user/Staging/2020/Roll0001', the "root of destination" would
     be automatically filled out with '/mnt/storage/2020/Roll0001'.

     But if all selected images fall under a directory outside the
     specified customary source root (e.g., '/opt/other'), the "root
     of destination" text box must be filled out manually.

     It is also possible to edit the "root of destination" further once
     it has been automatically filled out.

  4. Click the "move" or "copy" button.

     Before moving or copying any images, the module will first
     replicate the necessary directory hierarchy by creating all
     destination directories that do not already exist; should a
     directory creation attempt fail, the operation will be
     aborted, but any directories already created will not be
     removed.

     During the actual move/copy operation, the module transfers an
     image by taking its path and replacing the string in the "existing
     root" text box with that in the "root of destination" text box
     (e.g., '/home/user/Staging/2020/Roll0001/DSC_0001.jpg' would be
     transferred to '/mnt/storage/2020/Roll0001/DSC_0001.jpg').

  LICENSE
  LGPLv2+
]]


-- Header material: BEGIN

local darktable = require("darktable")
local dtutils = require("lib/dtutils")
local dtutils_file = require("lib/dtutils.file")
local dtutils_system = require("lib/dtutils.system")
local gettext = darktable.gettext.gettext

local LIB_ID = "transfer_hierarchy"
dtutils.check_min_api_version("7.0.0", LIB_ID) 

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("transfer hierarchy"),
  purpose = _("allows the moving or copying of images from one directory tree to another, while preserving the existing hierarchy"),
  author = "August Schwerdfeger (august@schwerdfeger.name)",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/transfer_hierarchy"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

local MKDIR_COMMAND = darktable.configuration.running_os == "windows" and "mkdir " or "mkdir -p "
local PATH_SEPARATOR = darktable.configuration.running_os == "windows" and "\\\\"  or  "/"
local PATH_SEGMENT_REGEX = "(" .. PATH_SEPARATOR .. "?)([^" .. PATH_SEPARATOR .. "]+)"

unpack = unpack or table.unpack
gmatch = string.gfind or string.gmatch

-- Header material: END



-- Helper functions: BEGIN

local th = {}
th.module_installed = false
th.event_registered = false

local function pathExists(path)
   local success, err, errno = os.rename(path, path)
   if not success then
      if errno == 13 then
         return true
      end
   end
   return success, err
end

local function pathIsDirectory(path)
   return pathExists(path..PATH_SEPARATOR)
end

local function createDirectory(path)
   local errorlevel = dtutils_system.external_command(MKDIR_COMMAND .. dtutils_file.sanitize_filename(path))
   if errorlevel == 0 and pathIsDirectory(path) then
      return path
   else
      return nil
   end
end

local function install_module()
  if not th.module_installed then
    darktable.register_lib(LIB_ID,
               _("transfer hierarchy"), true, true, {
            [darktable.gui.views.lighttable] = { "DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 700 }
               }, th.transfer_widget, nil, nil)
    th.module_installed = true
  end
end

-- Helper functions: END


-- Widgets and business logic: BEGIN

local sourceTextBox = darktable.new_widget("entry") {
   tooltip = _("lowest directory containing all selected images"),
   editable = false
						    }
sourceTextBox.reset_callback = function() sourceTextBox.text = "" end

local destinationTextBox = darktable.new_widget("entry") {
   text = ""
}
destinationTextBox.reset_callback = function() destinationTextBox.text = "" end









local function findRootPath(films)
   local commonSegments = nil
   local prefix = ""
   for film, _ in pairs(films) do
      local path = film.path
      if commonSegments == nil then
	 commonSegments = {}
	 local firstMatchIndex = string.find(path, PATH_SEGMENT_REGEX)
	 if firstMatchIndex ~= nil then
	    prefix = string.sub(path, 1, firstMatchIndex-1)
	 end
	 string.gsub(path, PATH_SEGMENT_REGEX, function(w, x)
			if w ~= "" then table.insert(commonSegments, w) end
			table.insert(commonSegments, x)
	 end)
      else
	 local matcher = gmatch(path, PATH_SEGMENT_REGEX)
	 local i = 1
	 while i < #commonSegments do
	    match, match2 = matcher()
	    if match == nil then
	       while i <= #commonSegments do
		  table.remove(commonSegments, #commonSegments)
	       end
	       break
	    elseif match ~= "" then
	       if commonSegments[i] ~= match then
		  while i <= #commonSegments do
		     table.remove(commonSegments, #commonSegments)
		  end
		  break
	       else
		  i = i+1
	       end
	    end
	    if match2 == nil or commonSegments[i] ~= match2 then
	       while i <= #commonSegments do
		  table.remove(commonSegments, #commonSegments)
	       end
	       break
	    else
	       i = i+1
	    end
	 end
      end
   end
   if commonSegments == nil then
      return prefix
   end
   if commonSegments[#commonSegments] == PATH_SEPARATOR then
      table.remove(commonSegments, #commonSegments)
   end
   rv = prefix .. table.concat(commonSegments)
   return rv
end

local function calculateRoot()
   films = {}
   for _,img in ipairs(darktable.gui.action_images) do
      films[img.film] = true
   end
   return findRootPath(films), films
end

local function doCalculate()
   local rootPath = calculateRoot()
   if rootPath ~= nil then
      sourceTextBox.text = rootPath
      local sourceBase = darktable.preferences.read(LIB_ID, "source_base", "directory")
      local destBase = darktable.preferences.read(LIB_ID, "destination_base", "directory")
      if sourceBase ~= nil and sourceBase ~= "" and
	 destBase ~= nil and destBase ~= "" and
	 string.sub(rootPath, 1, #sourceBase) == sourceBase then
      	 destinationTextBox.text = destBase .. string.sub(rootPath, #sourceBase+1)
      end
   end
end

local function stopTransfer(transferJob)
   transferJob.valid = false
end

local function doTransfer(transferFunc)
    rootPath, films = calculateRoot()
    if rootPath ~= sourceTextBox.text then
       darktable.print(_("transfer hierarchy: ERROR: existing root is out of sync -- click 'calculate' to update"))
       return
    end
    if destinationTextBox.text == "" then
       darktable.print(_("transfer hierarchy: ERROR: destination not specified"))
       return
    end
    local sourceBase = sourceTextBox.text
    local destBase = destinationTextBox.text
    local destFilms = {}
    for film, _ in pairs(films) do
       films[film] = destBase .. string.sub(film.path, #sourceBase+1)
       if not pathExists(films[film]) then
           if createDirectory(films[film]) == nil then
	       darktable.print(string.format(_("transfer hierarchy: ERROR: could not create directory: %s"),  films[film]))
	       return
	   end
       end
       if not pathIsDirectory(films[film]) then
           darktable.print(string.format(_("transfer hierarchy: ERROR: not a directory: %s"), films[film]))
	   return
       end
       destFilms[film] = darktable.films.new(films[film])
       if destFilms[film] == nil then
           darktable.print(string.format(_("transfer hierarchy: ERROR: could not create film: %s"), film.path))
       end
    end

    local srcFilms = {}
    for _,img in ipairs(darktable.gui.action_images) do
       srcFilms[img] = img.film
    end

    local job = darktable.gui.create_job(string.format(_("transfer hierarchy (%d image%s)"), #(darktable.gui.action_images), (#(darktable.gui.action_images) == 1 and "" or "s")), true, stopTransfer)
    job.percent = 0.0
    local pctIncrement = 1.0 / #(darktable.gui.action_images)
    for _,img in ipairs(darktable.gui.action_images) do
       if job.valid and img.film == srcFilms[img] then
    	  destFilm = destFilms[img.film]
	  transferFunc(img, destFilm)
	  job.percent = job.percent + pctIncrement
       end
    end
    job.valid = false
    local filterRules = darktable.gui.libs.collect.filter()
    darktable.gui.libs.collect.filter(filterRules)
end

local function doMove()
    doTransfer(darktable.database.move_image)
end

local function doCopy()
    doTransfer(darktable.database.copy_image)
end

local function destroy()
   darktable.gui.libs[LIB_ID].visible = false
end

local function restart()
   darktable.gui.libs[LIB_ID].visible = true
end





th.transfer_widget = darktable.new_widget("box") {
   orientation = "vertical",
   darktable.new_widget("button") {
     label = _("calculate"),
     clicked_callback = doCalculate
   },
   darktable.new_widget("label") {
      label = _("existing root"),
      halign = "start"
   },
   sourceTextBox,
   darktable.new_widget("label") {
     label = _("root of destination"),
     halign = "start"
   },
   destinationTextBox,
   darktable.new_widget("button") {
     label = _("move"),
     tooltip = "Move all selected images",
     clicked_callback = doMove
   },
   darktable.new_widget("button") {
     label = _("copy"),
     tooltip = _("copy all selected images"),
     clicked_callback = doCopy
   }
}

-- Widgets and business logic: END






-- Preferences: BEGIN

darktable.preferences.register(
      LIB_ID,
      "source_base",
      "string",
      "[transfer hierarchy] Customary source root",
      "",
      "")

darktable.preferences.register(
      LIB_ID,
      "destination_base",
      "string",
      "[transfer hierarchy] Customary destination root",
      "",
      "")

-- Preferences: END

if darktable.gui.current_view().id == "lighttable" then
  install_module()
else
  if not th.event_registered then
    darktable.register_event(
      LIB_ID, "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module()
         end
      end
    )
    th.event_registered = true
  end
end


script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = restart

return script_data
