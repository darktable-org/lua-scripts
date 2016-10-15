--[[
  This file is part of darktable,
  copyright (c) 2016 Bill Ferguson
  
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

local dtutils_processor = {}

dtutils_processor.libdoc = {
  Sections = {"Name", "Synopsis", "Description", "License"},
  Name = [[dtutils.processor - Darktable lua functions for building processor scripts]],
  Synopsis = [[local dp = require "lib/dtutils.processor"]],
  Description = [[dtutils.processor provides common functions used for building scripts
    that send images out to an external process, process them, and return the result (i.e. processors).]],
  License = [[This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.]],
  functions = {}
}

local dt = require "darktable"
local dtutils = require "lib/dtutils"
local df = require "lib/dtutils.file"
local log = require "lib/libLog"

local gettext = dt.gettext

dt.configuration.check_version(...,{3,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
-- This should be $HOME/.config/darktable/lua/locale/
gettext.bindtextdomain("dtutils",dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
    return gettext.dgettext("dtutils.processor", msgid)
end

--[[
  NAME
    exporter_status - show the status while exporting images

  SYNOPSIS
    local dp = require "lib/dtutils.processor"

    local result = dp.exporter_status(storage, image, format, filename, number, total, high_quality, extra_data)
      storage - dt_imageio_module_storage_t - the storage that the status is being shown for
      image - dt_lua_image_t - the current image
      format - dt_imageio_module_format_t - the format of the export image
      filename - string - the filename being exported to
      number - integer - the number of this image in the sequence
      total - integer - the total number of images being exported
      high_quality - boolean
      extra_data - extra data from the storage

  DESCRIPTION
    exporter_status runs prior to each image being exported and prints out a status that lets the user
    know how many images, out of the total, have been exported

  RETURN VALUE
    none

]]

dtutils_processor.libdoc.functions[#dtutils_processor.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[exporter_status - show the status while exporting images]],
  Synopsis = [[local dp = require "lib/dtutils.processor"

    local result = dp.exporter_status(storage, image, format, filename, number, total, high_quality, extra_data)
      storage - dt_imageio_module_storage_t - the storage that the status is being shown for
      image - dt_lua_image_t - the current image
      format - dt_imageio_module_format_t - the format of the export image
      filename - string - the filename being exported to
      number - integer - the number of this image in the sequence
      total - integer - the total number of images being exported
      high_quality - boolean
      extra_data - extra data from the storage]],
  Description = [[exporter_status runs prior to each image being exported and prints out a status that lets the user
    know how many images, out of the total, have been exported]],
  Return_Value = [[none]],
}

function dtutils_processor.exporter_status(storage, image, format, filename,
  number, total, high_quality, extra_data)
    dt.print(string.format(_("Export Image %i/%i"), number, total))
end

--[[
  NAME
    extract_image_list - assemble the exported image filenames from an image_table into a string

  SYNOPSIS
    local dp = require "lib/dtutils.processor"

    result = dp.extract_image_list(image_table)
      image_table - table - a table of images such as supplied by the exporter or by libPlugin.build_image_table

  DESCRIPTION
    extract_image_list concatenates the exported image names into a space separated string suitable for
    passing as an argument to a processor.  Each filename is bracketed with single quotes to protect against
    spaces and special characters in the filepath

  RETURN VALUE
    result - string - the assembled image list on success, or an empty image list on error

]]

dtutils_processor.libdoc.functions[#dtutils_processor.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[extract_image_list - assemble the exported image filenames from an image_table into a string]],
  Synopsis = [[local dp = require "lib/dtutils.processor"
    
    result = dp.extract_image_list(image_table)
      image_table - table - a table of images such as supplied by the exporter or by libPlugin.build_image_table]],
  Description = [[extract_image_list concatenates the exported image names into a space separated string suitable for
    passing as an argument to a processor.  Each filename is bracketed with single quotes to protect against
    spaces and special characters in the filepath]],
  Return_Value = [[result - string - the assembled image list on success, or an empty image list on error]],
}

function dtutils_processor.extract_image_list(image_table)
  local img_list = ""
  for _,exp_img in pairs(image_table) do
    img_list = img_list .. " " .. "'" .. exp_img .. "'"
  end
  return img_list
end

--[[
  NAME
    extract_collection_path - extract the collection path from an image table

  SYNOPSIS
    local dp = require "lib/dtutils.processor"

    local result = dp.extract_collection_path(image_table)
      image_table - table - a table of images such as supplied by the exporter or by libPlugin.build_image_table

  DESCRIPTION
    extract_collection_path looks at the first image in the image_table and returns the path

  RETURN VALUE
    result - string - the collection path on success, or nil if there was an error

  LIMITATIONS
    The collection path is determined from the first image.  If the table consists of images from different
    collections, then only the first collection is used.

]]

dtutils_processor.libdoc.functions[#dtutils_processor.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value", "Limitations"},
  Name = [[extract_collection_path - extract the collection path from an image table]],
  Synopsis = [[local dp = require "lib/dtutils.processor"

    local result = dp.extract_collection_path(image_table)
      image_table - table - a table of images such as supplied by the exporter or by libPlugin.build_image_table]],
  Description = [[extract_collection_path looks at the first image in the image_table and returns the path]],
  Return_Value = [[result - string - the collection path on success, or nil if there was an error]],
  Limitations = [[The collection path is determined from the first image.  If the table consists of images from different
    collections, then only the first collection is used.]],
}

function dtutils_processor.extract_collection_path(image_table)
  collection_path = nil
  for i,_ in pairs(image_table) do
    collection_path = i.path
    break
  end
  return collection_path
end

--[[
  NAME
    make_output_filename- make an output filename from an image list

  SYNOPSIS
    local dp = require "lib/dtutils.processor"
    
    local result = dtutils.make_output_filename(img_list)
      img_list - string - a space separated list of filenames

  DESCRIPTION
    make_output_filename takes a string of filenames, breaks them apart, then
    combines them in a way that makes some sense.  This is useful in routines
    that do panoramas, hdr, or focus stacks.  The returned filename is a representation
    of the files used to construct the image.  If there are 3 or fewer images, then the file
    basenames are concatenated with a separator. If there is more than 3 images, the first and 
    last file basenames are concatenated with a separator.

  RETURN VALUE
    result - string - the constructed filename on success, nil on error

]]

dtutils_processor.libdoc.functions[#dtutils_processor.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[make_output_filename- make an output filename from an image list]],
  Synopsis = [[local dp = require "lib/dtutils.processor"
    
    local result = dtutils.make_output_filename(img_list)
      img_list - string - a space separated list of filenames]],
  Description = [[make_output_filename takes a string of filenames, breaks them apart, then
    combines them in a way that makes some sense.  This is useful in routines
    that do panoramas, hdr, or focus stacks.  The returned filename is a representation
    of the files used to construct the image.  If there are 3 or fewer images, then the file
    basenames are concatenated with a separator. If there is more than 3 images, the first and 
    last file basenames are concatenated with a separator.]],
  Return_Value = [[result - string - the constructed filename on success, nil on error]],
}

function dtutils_processor.make_output_filename(img_list)
  local images = {}
  local cnt = 1
  local max_distinct_names = 3
  local name_separator = "-"
  local outputFileName = nil
  log.msg(log.debug, "img_list is ", img_list)

  local result = dtutils.split(img_list, " ")
  table.sort(result)
  for _,img in pairs(result) do
    images[cnt] = df.get_basename(img)
    cnt = cnt + 1
  end

  cnt = cnt - 1

  if cnt > 1 then
    if cnt > max_distinct_names then
      -- take the first and last
      outputFileName = images[1] .. name_separator .. images[cnt]
    else
      -- join them
      outputFileName = dtutils.join(images, name_separator)
    end
  else
    -- return the single name
    outputFileName = images[cnt]
  end

  return outputFileName
end

return dtutils_processor
