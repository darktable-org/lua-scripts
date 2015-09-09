--[[
  Hugin storage for darktable 

  copyright (c) 2014  Wolfgang Goetz
  copyright (c) 2015  Christian Kanzian
  
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
HUGIN
Add a new storage option to send images to hugin. 
Images are exported to darktable tmp dir first. 

ADDITIANAL SOFTWARE NEEDED FOR THIS SCRIPT
* hugin

USAGE
* require this file from your main luarc config file.

This plugin will add a new storage option and calls hugin after export.
]]

dt = require "darktable"

-- should work with darktable API version 2.0.0
dt.configuration.check_version(...,{2,0,0})

dt.register_storage("module_hugin","Hugin panorama",
   function(storage, image, format, filename,
        number,total,high_quality,extra_data)
        dt.print("Export to hugin " .. tostring(number).."/"..tostring(total))
   end,
   function(storage,image_table,extra_data) --finalize
       -- list of exported images 
        local img_list
        
        -- reset and create image list
        img_list = ""
                
        for _,v in pairs(image_table) do
         img_list = img_list ..v.. " "
        end
       
        dt.print("Will try to stitch now")
       
        if coroutine.yield("RUN_COMMAND","hugin "..img_list)
           then
           dt.print("Command hugin failed ...")
        end
	
    end,
    nil,
    nil
)

--
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
