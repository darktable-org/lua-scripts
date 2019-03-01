--[[
OpenInExplorer plugin for darktable

  copyright (c) 2018  Kevin Ertel
  
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
Microsoft Windows or Linux with installed Nautilus

----USAGE----
Install: (see here for more detail: https://github.com/darktable-org/lua-scripts )
 1) Copy this file in to your "lua/contrib" folder where all other scripts reside. 
 2) Require this file in your luarc file, as with any other dt plug-in

Select the photo(s) you wish to find in explorer and press "Go to Folder". 
A file explorer window will be opened for each selected file at the file's location; the file will be highlighted.

----KNOWN ISSUES----
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local dsys = require "lib/dtutils.system"

--Check API version
du.check_min_api_version("5.0.0", "OpenInExplorer") 

local PS = dt.configuration.running_os == "windows" and  "\\"  or  "/"

--Detect OS and modify accordingly--	
local proper_install = false
if dt.configuration.running_os ~= "macos" then
  proper_install = true
else
  dt.print_error('OpenInExplorer plug-in only supports Windows and Linux at this time')
  return
end


-- FUNCTIONS --

local function open_in_explorer() --Open in Explorer
  local images = dt.gui.selection()
  local curr_image = ""
  if #images == 0 then
    dt.print('please select an image')
  elseif #images <= 15 then
    for _,image in pairs(images) do 
      curr_image = image.path..PS..image.filename
      local run_cmd = "explorer.exe /select, "..curr_image
      dt.print_log("OpenInExplorer run_cmd = "..run_cmd)
      resp = dsys.external_command(run_cmd)
    end
  else
    dt.print('please select fewer images (max 15)')
  end
end

local function open_in_nautilus() --Open in Nautilus
  local images = dt.gui.selection()
  local curr_image = ""
  if #images == 0 then
    dt.print('please select an image')
  elseif #images <= 15 then
    for _,image in pairs(images) do 
      curr_image = image.path..PS..image.filename
      local run_cmd = "nautilus --select " .. df.sanitize_filename(curr_image)
      dt.print_log("OpenInExplorer run_cmd = "..run_cmd)
      resp = dsys.external_command(run_cmd)
    end
  else
    dt.print('please select fewer images (max 15)')
  end
end

local function open_in_filemanager() --Open
  --Inits--
  if not proper_install then
    return
  end

  if (dt.configuration.running_os == "windows") then
    open_in_explorer()
  elseif (dt.configuration.running_os == "linux") then
    open_in_nautilus()
  end  
end

-- GUI --
if proper_install then
  dt.gui.libs.image.register_action(
    "show in file explorer",
    function() open_in_filemanager() end,
    "Opens File Explorer at the selected image's location"
  )
end
