--[[
OpenInExplorer plugin for darktable

  copyright (c) 2018  Kevin Ertel
  Update 2020: copyright (c) 2020 Volker Lenhardt
  
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
This plugin adds the module "OpenInExplorer" to darktable's lighttable view

----REQUIRED SOFTWARE----
Apple macOS, Microsoft Windows or Linux with installed Nautilus

----USAGE----
Install: (see here for more detail: https://github.com/darktable-org/lua-scripts )
 1) Copy this file in to your "lua/contrib" folder where all other scripts reside. 
 2) Require this file in your luarc file, as with any other dt plug-in

Select the photo(s) you wish to find in explorer and press "Go to Folder". 
A file explorer window will be opened for each selected file at the file's location; the file will be highlighted.

----KNOWN ISSUES----
Under macOS the file manager Finder opens only once and selects the file name of the last in DT selected image.
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

--Detect OS and modify accordingly--	
local proper_install = true
if act_os ~= "macos" and act_os ~= "windows" and act_os ~= "linux" then
  proper_install = false
  dt.print_error(_('OpenInExplorer plug-in only supports Windows and Linux at this time'))
  return
end

--The commands to open the OSes' file managers
local fmng_cmd = {}
fmng_cmd.linux = [[busctl --user call org.freedesktop.FileManager1 /org/freedesktop/FileManager1 org.freedesktop.FileManager1 ShowItems ass 1 ]]
fmng_cmd.macos = 'open -R '
fmng_cmd.windows = 'explorer.exe /select, '

--The working function that opens the file manager with the image file name selected.
local function open_in_fmanager(os, fmcmd)
  local images = dt.gui.selection()
  local curr_image = ""
  if #images == 0 then
    dt.print(_('Please select an image'))
  elseif #images <= 15 then
    for _,image in pairs(images) do 
      curr_image = df.sanitize_filename(image.path..PS..image.filename)
      local run_cmd = fmcmd..curr_image
      if os == 'linux' then run_cmd = run_cmd .. [[ ""]] end
      dt.print_log("OpenInExplorer run_cmd = "..run_cmd)
      resp = dsys.external_command(run_cmd)
    end
  else
    dt.print(_('Please select fewer images (max 15)'))
  end
end


-- GUI --
if proper_install then
  dt.gui.libs.image.register_action(
    _("Show in file explorer"),
    function() open_in_fmanager(act_os, fmng_cmd[act_os]) end,
    _("Opens File Explorer at the selected image's location")
  )
end
