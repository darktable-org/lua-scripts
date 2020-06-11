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

- Nautilus (Linux), Explorer (Windows), and Finder (macOS before Catalina) will open one window for each selected image at the file's location. The file name will be highlighted.

- On macOS Catalina the Finder will open one window for each different directory. In these windows only the last one of the corresponding files will be highlighted (bug or feature?).

- Dolphin (Linux) will open one window with tabs for the different directories. All the selected images' file names are highlighted in their respective directories.

----KNOWN ISSUES----
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local dsys = require "lib/dtutils.system"
local gettext = dt.gettext

--Check API version
du.check_min_api_version("5.0.0", "OpenInExplorer") 

gettext.bindtextdomain("OpenInExplorer",dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
    return gettext.dgettext("OpenInExplorer", msgid)
end

local act_os = dt.configuration.running_os
local PS = act_os == "windows" and  "\\"  or  "/"

--Detect OS and quit if it is not supported--	
local proper_install = true
if act_os ~= "macos" and act_os ~= "windows" and act_os ~= "linux" then
  proper_install = false
  dt.print_error(_('OpenInExplorer plug-in only supports Linux, macOS, and Windows at this time'))
  return
end

--Format strings for the commands to open the corresponding OS' file manager
local fmng_cmd = {}
fmng_cmd.linux = [[busctl --user call org.freedesktop.FileManager1 /org/freedesktop/FileManager1 org.freedesktop.FileManager1 ShowItems ass %d %s""]]
fmng_cmd.macos = 'open -Rn %s'
fmng_cmd.windows = 'explorer.exe /select, %s'

--The working function that opens the file manager windows with the selected image file names highlighted.
local function open_in_fmanager(op_sys, fmcmd)
  local images = dt.gui.selection()
  local curr_image, run_cmd, file_uris = '', '', ''
  if #images == 0 then
    dt.print(_('Please select an image'))
  elseif #images <= 15 then
    for _,image in pairs(images) do
      curr_image = image.path..PS..image.filename
      if op_sys == 'linux' then
        file_uris = file_uris .. df.sanitize_filename("file://" .. curr_image) .. " "
        dt.print_log("file_uris is " .. file_uris)
      else
        run_cmd = string.format(fmcmd, df.sanitize_filename(curr_image))
        dt.print_log("OpenInExplorer run_cmd = "..run_cmd)
        dsys.external_command(run_cmd)
      end
    end
    if op_sys == 'linux' then
      run_cmd = string.format(fmcmd, #images, file_uris)
      dt.print_log("OpenInExplorer run_cmd = "..run_cmd)
      dsys.external_command(run_cmd)
    end
  else
    dt.print(_('Please select fewer images (max 15)'))
  end
end

-- GUI --
if proper_install then
  dt.gui.libs.image.register_action(
    _("show in file explorer"),
    function() open_in_fmanager(act_os, fmng_cmd[act_os]) end,
    _("Opens the file manager at the selected image's location")
  )
  dt.register_event(
      "shortcut",
      function(event, shortcut) open_in_fmanager(act_os, fmng_cmd[act_os]) end,
      "OpenInExplorer"
  )  
end
