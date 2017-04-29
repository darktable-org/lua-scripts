--[[

    export2collection.lua - export a file and import it to the collection

    Copyright (C) 2016 Bill Ferguson <wpferguson@gmail.com>.

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
    export2collection - export an image then import it into the collection

    This script provides another storage (export target) for darktable.  Selected
    images are exported in the specified format to temporary storage.   The exported 
    files are moved into the current collection and imported into the database.  Any 
    tags that have been added to the original image are copied to the imported image.
    The imported files then show up grouped with the originally selected images.
    If there is a filename conflict on import, the incoming filename will have an 
    increment added to it, i.e. _7D_1234.jpg would be _7D_1234_01.jpg.

    USAGE
    * require this script from your main lua file
    * select an image or images to export
    * in the export dialog select "file to collection" and select the format and bit depth for the
      exported image
    * Press "export"
    * The exported image will be imported and grouped with the original image

    BUGS, COMMENTS, SUGGESTIONS
    * Send to Bill Ferguson, wpferguson@gmail.com

]]

local dt = require "darktable"
local gettext = dt.gettext

dt.configuration.check_version(...,{3,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("export2collection",dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
    return gettext.dgettext("export2collection", msgid)
end

local function split_filepath(str)
  local result = {}
  -- strip out single quotes from quoted pathnames
  str = string.gsub(str, "'", "")
  -- Thank you Tobias Jakobs for the awesome regular expression, which I tweaked a little
  result["path"], result["filename"], result["basename"], result["filetype"] = string.match(str, "(.-)(([^\\/]-)%.?([^%.\\/]*))$")
  return result
end

local function get_path(str)
  local parts = split_filepath(str)
  return parts["path"]
end

local function get_filename(str)
  local parts = split_filepath(str)
  return parts["filename"]
end

local function get_basename(str)
  local parts = split_filepath(str)
  return parts["basename"]
end

local function get_filetype(str)
  local parts = split_filepath(str)
  return parts["filetype"]
end

function check_if_bin_exists(bin)
  local result = os.execute("which " .. bin)
  if not result then
    result = false
  end
  return result
end

-- Thanks Tobias Jakobs for the idea 
function check_if_file_exists(filepath)
  local result = os.execute("test -e " .. filepath)
  if not result then
    result = false
  end
  return result
end

local function filename_increment(filepath)

  -- break up the filepath into parts
  local path = get_path(filepath)
  local basename = get_basename(filepath)
  local filetype = get_filetype(filepath)

  -- check to see if we've incremented before
  local increment = string.match(basename, "_(%d-)$")

  if increment then
    -- we do 2 digit increments so make sure we didn't grab part of the filename
    if string.len(increment) > 2 then
      -- we got the filename so set the increment to 01
      increment = "01"
    else
      increment = string.format("%02d", tonumber(increment) + 1)
      basename = string.gsub(basename, "_(%d-)$", "")
    end
  else
    increment = "01"
  end
  local incremented_filepath = path .. basename .. "_" .. increment .. "." .. filetype

  dt.print_error("original file was " .. filepath)
  dt.print_error("incremented file is " .. incremented_filepath)

  return incremented_filepath
end

local function show_status(storage, image, format, filename,
  number, total, high_quality, extra_data)
    dt.print(string.format(_("Export Image %i/%i"), number, total))
end

local function file_move(fromFile, toFile)
  local success = os.rename(fromFile, toFile)
  if not success then
    -- an error occurred, so let's try using the operating system function
    if checkIfBinExists("mv") then
      success = os.execute("mv '" .. fromFile .. "' '" .. toFile .. "'")
    end
  end
  return success  -- nil on error, some value if success
end

local function import_exports(storage, image_table, extra_data) --finalize

  -- for each of the image, exported image pairs
  --   move the exported image into the directory with the original  
  --   then import the image into the database which will group it with the original
  --   and then copy over any tags other than darktable tags

  for image,exported_image in pairs(image_table) do

    local myimage_name = image.path .. "/" .. get_filename(exported_image)

    while check_if_file_exists(myimage_name) do
      myimage_name = filename_increment(myimage_name)
      -- limit to 99 more exports of the original export
      if string.match(get_basename(myimage_name), "_(d-)$") == "99" then 
        break 
      end
    end

    dt.print_error("moving " .. exported_image .. " to " .. myimage_name)
    local result = file_move(exported_image, myimage_name)

    if result then
      dt.print_error("importing file")
      local myimage = dt.database.import(myimage_name)

      myimage:group_with(image.group_leader)

      for _,tag in pairs(dt.tags.get_tags(image)) do 
        if not (string.sub(tag.name,1,9) == "darktable") then
          dt.print_error("attaching tag")
          dt.tags.attach(tag,myimage)
        end
      end
    end
  end

end

-- Register
dt.register_storage("export2collection", _("file to collection"), show_status, import_exports)

--


