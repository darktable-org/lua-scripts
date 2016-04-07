--[[

    gimp.lua - export and edit with gimp

    Copyright (C) 2016 Bill Ferguson <wpferguson@gmail.com>.

    Portions are lifted from hugin.lua and thus are 

    Copyright (c) 2014  Wolfgang Goetz
    Copyright (c) 2015  Christian Kanzian
    Copyright (c) 2015  Tobias Jakobs


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
    gimp - export an image and open with gimp for editing

    This script provides another storage (export target) for darktable.  Selected
    images are exported in the specified format to temporary storage.  Gimp is launched
    and opens the files.  After editing, the exported images are overwritten to save the 
    changes.  When gimp exits, the exported files are moved into the current collection
    and imported into the database.  The imported files then show up grouped with the 
    originally selected images.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    * gimp - http://www.gimp.org

    USAGE
    * require this script from your main lua file
    * select an image or images for editing with gimp
    * in the export dialog select "Edit with gimp" and select the format and bit depth for the
      exported image
    * Press "export"
    * Edit the image with gimp then save the changes with File->Overwrite....
    * Exit gimp
    * The edited image will be imported and grouped with the original image

    CAVEATS
    * Developed and tested on Ubuntu 14.04 LTS with darktable 2.0.3 and gimp 2.9.3 (development version with
      > 8 bit color)
    * There is no provision for dealing with the xcf files generated by gimp, since darktable doesn't deal with 
      them.  You may want to save the xcf file if you intend on doing further edits to the image or need to save 
      the layers used.  Where you save them is up to you.

    BUGS, COMMENTS, SUGGESTIONS
    * Send to Bill Ferguson, wpferguson@gmail.com
]]

local dt = require "darktable"
local gettext = dt.gettext

dt.configuration.check_version(...,{3,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("gimp",dt.configuration.config_dir.."/lua/")

-- Thanks to http://lua-users.org/wiki/SplitJoin for the split and split_path functions
local function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
        table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

local function split_path(str)
   return split(str,'[\\/]+')
end

local function get_filename(str)
  parts = split_path(str)
  return parts[#parts]
end

local function basename(str)
  return string.sub(str,1,-4)
end

local function _(msgid)
    return gettext.dgettext("gimp", msgid)
end

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

local function show_status(storage, image, format, filename,
  number, total, high_quality, extra_data)
  dt.print("Exporting to gimp "..tostring(number).."/"..tostring(total))
end

local function gimp_edit(storage, image_table, extra_data) --finalize
  if not checkIfBinExists("gimp") then
    dt.print_error(_("gimp not found"))
    return
  end

  -- list of exported images 
  local img_list

   -- reset and create image list
  img_list = ""

  for _,v in pairs(image_table) do
    img_list = img_list ..v.. " "
  end

  dt.print(_("Launching gimp..."))

  local gimpStartCommand
  gimpStartCommand = "gimp "..img_list
  
  dt.print_error(gimpStartCommand)

  coroutine.yield("RUN_COMMAND", gimpStartCommand)

  -- for each of the exported images
  -- find the matching original image
  -- then move the exported image into the directory with the original  
  -- then import the image into the database which will group it with the original
  -- and then copy over any tags other than darktable tags

  for _,v in pairs(image_table) do
    local fname = get_filename(v)
    for _,w in pairs(dt.gui.action_images) do
      if basename(fname) == basename(w.filename) then
        os.execute("mv "..v.." "..w.path)
        local myimage = dt.database.import(w.path.."/"..fname)
        for _,x in pairs(dt.tags.get_tags(w)) do 
          if not (string.sub(x.name,1,9) == "darktable") then
            dt.tags.attach(x,myimage)
          end
        end
      end
    end
  end

end

-- Register
dt.register_storage("module_gimp", _("Edit with gimp"), show_status, gimp_edit)

--

