--[[
    This file is part of darktable,
    copyright 2016 by Christian Kanzian.

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
EXIFTOOL ACTIONS ON EXPORT 
  This script adds a new UI element in the lighttable mode beyond the export modul. 
  If the tickbox is checked the script calls the 'exiftool' with the selected command line options on currently exported images.
  The original exported image will be overwritten. Following options are selectable:
  * -XMP-dc:Subject > IPTC:Keywords -> will copy tags from xmp to IPTC
  * -XMP:all= -> remove darktable history
  * -all= -> remove all metadata
  * -@ -> load ARGuments from text file which contains several options line by line.

ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
* exiftool - from Phil Harvey http://www.sno.phy.queensu.ca/~phil/exiftool/. 
             Linux distribtions typically ship this as a package. 
             Please check if it is installed.


LIMITATIONS
  You can not save any presets.


INSTALATION
 * copy this file in $CONFIGDIR/lua/ where CONFIGDIR is your darktable configuration directory
 * add the following line in the file $CONFIGDIR/luarc require "exiftool_export"

USAGE

]]

local dt = require "darktable"
dt.configuration.check_version(...,{3,0,0})


-- function copied from hugin.lua
local function checkIfBinExists(bin)
  local handle = io.popen("which "..bin)
  local result = handle:read()
  local ret
  handle:close()
  if (result) then
    dt.print_error("true checkIfBinExists: "..bin)
    ret = true
  else
    dt.print_error(bin.." not found")
    ret = false
  end


  return ret
end


if not checkIfBinExists("exiftool") then
    dt.print_error("exiftool not found")
    return
  end



  local exiftool_enable = dt.new_widget("check_button") { label = "enable exiftool" }

  -- TODO: add another checkbox to switch the overwrite option on/off
  --local exif_overwrite_img =  dt.new_widget("check_button") { label = "overwrite original"}

  local cmd_options = dt.new_widget("combobox"){ 
    label = "options:", 
    tooltip = "-XMP-dc:Subject > IPTC:Keywords -> will copy tags from xmp to IPTC\n-XMP:all= -> remove darktable history\n-all= -> remove all metadata\n-@ -> load ARGuments file"}

    cmd_options[1] = "-XMP-dc:Subject > IPTC:Keywords"
    cmd_options[2] = "-XMP:all="
    cmd_options[3] = "-all="
    cmd_options[4] = "-@"

    cmd_options.editable = "TRUE"


  -- add file chooser button for the '-@' option

  local arg_file_label = dt.new_widget("label"){
   label = "Argumentsfile",
   halign = "start"
   }
  
  local arg_file = dt.new_widget("file_chooser_button"){
   title = "Please choose an arguments file" 
   }


  local exif_widget = dt.new_widget("box"){
    orientation = horizontal,
    -- exif_overwrite_img 
    exiftool_enable,
    cmd_options,
    arg_file_label,
    arg_file
    }


dt.register_lib("exiftool_ui","exiftool on export",true,false,{
    [dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 0}
    }, exif_widget
    );
 

-- function to build command
local function exiftool_call(img)
   local exif_cmd 

   if (cmd_options.value == "-@") then
     --check if argumentsfile 
     dt.print_error(tostring(arg_file.value))
     if (arg_file.value == nil)
       then
       dt.print("Command exiftool on export failed: Please select an arguments file!")
       return
      end
    
      exif_cmd = "exiftool "..tostring(cmd_options.value).." '"..arg_file.value.."'".." -overwrite_original ".."'" .. img .. "'"

    else
 
      exif_cmd = "exiftool ".."'"..tostring(cmd_options.value).."'".." -overwrite_original ".."'" .. img .. "'"

    end   
      
   return exif_cmd
end   


-- final call exiftool if enabled on export events 
dt.register_event("intermediate-export-image", function(event,img)
    
    if not exiftool_enable.value == true then
       return
    end
   
    local cmd = exiftool_call(img)  
    dt.print("Call "..cmd) 

    coroutine.yield("RUN_COMMAND", cmd)
      
end
)
