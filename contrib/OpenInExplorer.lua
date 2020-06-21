--[[
OpenInExplorer plugin for darktable

  copyright (c) 2018  Kevin Ertel
  Update 2020 and macOS support by Volker Lenhardt
  Linux support 2020 by Bill Ferguson
  
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

--[[About this plugin
This plugin adds the module "OpenInExplorer" to darktable's lighttable view.

----REQUIRED SOFTWARE----
Apple macOS, Microsoft Windows or Linux

----USAGE----
Install: (see here for more detail: https://github.com/darktable-org/lua-scripts )
 1) Copy this file into your "lua/contrib" folder where all other scripts reside. 
 2) Require this file in your luarc file, as with any other dt plug-in

Select the photo(s) you wish to find in your operating system's file manager and press "show in file explorer" in the "selected images" section.

- Nautilus (Linux), Explorer (Windows), and Finder (macOS prior to Mojave) will open one window for each selected image at the file's location. The file name will be highlighted.

- On macOS Mojave and Catalina the Finder will open one window for each different directory. In these windows only the last one of the corresponding files will be highlighted (bug or feature?).

- Dolphin (Linux) will open one window with tabs for the different directories. All the selected images' file names are highlighted in their respective directories.

As an alternative option you can choose to show the image file names as symbolic links in an arbitrary directory. Go to preferences|Lua options. This option is not available for Windows users as on Windows solely admins are allowed to create links.

- Pros: You do not clutter up your display with multiple windows. So there is no need to limit the number of selections.

- Cons: If you want to work with the files you are one step behind the original data.

----KNOWN ISSUES----
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local dsys = require "lib/dtutils.system"
local gettext = dt.gettext

--Check API version
du.check_min_api_version("5.0.0", "OpenInExplorer") 

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("OpenInExplorer",dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
    return gettext.dgettext("OpenInExplorer", msgid)
end

local act_os = dt.configuration.running_os
local PS = act_os == "windows" and  "\\"  or  "/"

--Detect OS and quit if it is not supported.	
if act_os ~= "macos" and act_os ~= "windows" and act_os ~= "linux" then
  dt.print(_("OpenInExplorer plug-in only supports Linux, macOS, and Windows at this time"))
  dt.print_error("OpenInExplorer plug-in only supports Linux, macOS, and Windows at this time")
  return
end

local use_links, links_dir = false, ""
if act_os ~= "windows" then
  use_links = dt.preferences.read("OpenInExplorer", "use_links", "bool")
  links_dir = dt.preferences.read("OpenInExplorer", "linked_image_files_dir", "string")
end

--Check if the directory exists that was chosen for the file links. Return boolean.
local function check_if_links_dir_exists()
  local dir_exists = true
  if not links_dir then
    --Just for paranoic reasons. I tried, but I couldn't devise a setting for a nil value.
    dt.print(_("No links directory selected.\nPlease check the dt preferences (lua options)"))
    dt.print_error("OpenInExplorer: No links directory selected")
    dir_exists = false
  elseif not df.check_if_file_exists(links_dir) then
    dt.print(string.format(_("Links directory '%s' not found.\nPlease check the dt preferences (lua options)"), links_dir))
    dt.print_error(string.format("OpenInExplorer: Links directory '%s' not found", links_dir))
    dir_exists = false
  end
  return dir_exists
end

--Format strings for the commands to open the corresponding OS's file manager.
local open_dir = {}
open_dir.windows = "explorer.exe /n, %s"
open_dir.macos = "open %s"
open_dir.linux = [[busctl --user call org.freedesktop.FileManager1 /org/freedesktop/FileManager1 org.freedesktop.FileManager1 ShowFolders ass 1 %s ""]]

local open_files = {}
open_files.windows = "explorer.exe /select, %s"
open_files.macos = "open -Rn %s"
open_files.linux = [[busctl --user call org.freedesktop.FileManager1 /org/freedesktop/FileManager1 org.freedesktop.FileManager1 ShowItems ass %d %s ""]]

--Call the file mangager for each selected image on Linux.
--There is one call to busctl containing a list of all the image file names.
local function call_list_of_files(selected_images)
  local current_image, file_uris, run_cmd = "", "", ""
  for _, image in pairs(selected_images) do
    current_image = image.path..PS..image.filename
    file_uris = file_uris .. df.sanitize_filename("file://" .. current_image) .. " "
    dt.print_log("file_uris is " .. file_uris)
  end
  run_cmd = string.format(open_files.linux, #selected_images, file_uris)
  dt.print_log("OpenInExplorer run_cmd = "..run_cmd)
  dsys.external_command(run_cmd)
end

--Call the file manager for each selected image on Windows and macOS.
local function call_file_by_file(selected_images)
  local current_image, run_cmd = "", ""
  for _, image in pairs(selected_images) do
    current_image = image.path..PS..image.filename
    run_cmd = string.format(open_files[act_os], df.sanitize_filename(current_image))
    dt.print_log("OpenInExplorer run_cmd = "..run_cmd)
    dsys.external_command(run_cmd)
  end
end

--Create a link for each selected image, and finally call the file manager.
local function set_links(selected_images)
  local current_image, link_target, run_cmd, k = "", "", "", nil
  for k, image in pairs(selected_images) do
    current_image = image.path..PS..image.filename
    link_target = df.create_unique_filename(links_dir .. PS .. image.filename)
    run_cmd = string.format("ln -s %s %s", df.sanitize_filename(current_image), df.sanitize_filename(link_target))
    --[[
    In case Windows will allow normal users to create soft links:
    if act_os == "windows" then
      run_cmd = string.format("mklink %s %s", df.sanitize_filename(link_target), df.sanitize_filename(current_image))
    end
    ]]
    if dsys.external_command(run_cmd) ~= 0 then
      dt.print(_("Failed to create links. Missing rights?"))
      dt.print_error("OpenInExplorer: Failed to create links")
      return
    end
  end
  --The URI format is necessary only for the Linux busctl command.
  --But it is accepted by the Windows Explorer and macOS's Finder all the same.
  run_cmd = string.format(open_dir[act_os], df.sanitize_filename("file://"..links_dir))
  dt.print_log("OpenInExplorer run_cmd = "..run_cmd)
  dsys.external_command(run_cmd)
end

--The working function that starts the particular task.
local function open_in_fmanager()
  local images = dt.gui.selection()
  if #images == 0 then
    dt.print(_("Please select an image"))
  else
    if use_links and not check_if_links_dir_exists() then
      return
    end
    if #images > 15 and not use_links then
      dt.print(_("Please select fewer images (max. 15)"))
    elseif use_links then
      set_links(images)
    else
      if act_os == "linux" then
        call_list_of_files(images)
      else
        call_file_by_file(images)
      end
    end
  end
end


-- GUI --
dt.gui.libs.image.register_action(
  _("show in file explorer"),
  function() open_in_fmanager() end,
  _("Open the file manager at the selected image's location")
)
if act_os ~= "windows" then
  dt.preferences.register("OpenInExplorer", "linked_image_files_dir",  -- name
    "directory", -- type
    _("OpenInExplorer: linked files directory"), -- label
    _("Directory to store the links to the file names. Requires restart to take effect"),  -- tooltip
    "Links to image files",  -- default
    dt.new_widget("file_chooser_button"){
      title = _("Select directory"),
      is_directory = true,
    }
  )
  dt.preferences.register("OpenInExplorer", "use_links",  -- name
    "bool", -- type
    _("OpenInExplorer: use links"), -- label
    _("Use links instead of multiple windows. Requires restart to take effect"),  -- tooltip
    false,  -- default
    ""
  )
end

dt.register_event(
    "shortcut",
    function(event, shortcut) open_in_fmanager() end,
    "OpenInExplorer"
)  

