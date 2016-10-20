local dtutils_processor = {}

local dt = require "darktable"
local dtutils = require "lib/dtutils"
local df = require "lib/dtutils.file"
local log = require "lib/dtutils.log"

dtutils_processor.libdoc = {
  Name = [[dtutils.processor]],
  Synopsis = [[Darktable lua functions for building processor scripts]],
  Usage = [[local dp = require "lib/dtutils.processor"]],
  Description = [[dtutils.processor provides common functions used for building scripts
    that send images out to an external process, process them, and return the result (i.e. processors).]],
  Return_Value = [[dp - library - the darktable lua processor functions]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = dtutils.libdoc.License,
  Copyright = [[Copyright (c) 2016 Bill Ferguson]],
  functions = {}
}


local gettext = dt.gettext

dt.configuration.check_version(...,{3,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
-- This should be $HOME/.config/darktable/lua/locale/
gettext.bindtextdomain("dtutils",dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
    return gettext.dgettext("dtutils.processor", msgid)
end

dtutils_processor.libdoc.functions["exporter_status"] = {
  Name = [[exporter_status]],
  Synopsis = [[show the status while exporting images]],
  Usage = [[local dp = require "lib/dtutils.processor"

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
    know how many images, out of the total, have been exported.  This routine can be used as the [store] argument to
    darktable.register_storage()]],
  Return_Value = [[]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_processor.exporter_status(storage, image, format, filename,
  number, total, high_quality, extra_data)
    dt.print(string.format(_("Export Image %i/%i"), number, total))
end

dtutils_processor.libdoc.functions["extract_image_list"] = {
  Name = [[extract_image_list]],
  Synopsis = [[assemble the exported image filenames from an image_table into a string]],
  Usage = [[local dp = require "lib/dtutils.processor"
    
    result = dp.extract_image_list(image_table)
      image_table - table - a table of images such as supplied by the exporter or by libPlugin.build_image_table]],
  Description = [[extract_image_list concatenates the exported image names into a space separated string suitable for
    passing as an argument to a processor.  Each filename is bracketed with single quotes to protect against
    spaces and special characters in the filepath]],
  Return_Value = [[result - string - the assembled image list on success, or an empty image list on error]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_processor.extract_image_list(image_table)
  local img_list = ""
  for _,exp_img in pairs(image_table) do
    img_list = img_list .. " " .. "'" .. exp_img .. "'"
  end
  return img_list
end

dtutils_processor.libdoc.functions["extract_collection_path"] = {
  Name = [[extract_collection_path]],
  Synopsis = [[extract the collection path from an image table]],
  Usage = [[local dp = require "lib/dtutils.processor"

    local result = dp.extract_collection_path(image_table)
      image_table - table - a table of images such as supplied by the exporter or by libPlugin.build_image_table]],
  Description = [[extract_collection_path looks at the first image in the image_table and returns the path]],
  Return_Value = [[result - string - the collection path on success, or nil if there was an error]],
  Limitations = [[The collection path is determined from the first image.  If the table consists of images from different
    collections, then only the first collection is used.]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
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

dtutils_processor.libdoc.functions["make_output_filename"] = {
  Name = [[make_output_filename]],
  Synopsis = [[make an output filename from an image list]],
  Usage = [[local dp = require "lib/dtutils.processor"
    
    local result = dtutils.make_output_filename(image_table)
      image_table - table - a table of images such as supplied by the exporter or by libPlugin.build_image_table]],
  Description = [[make_output_filename takes an image table, gets the filenames, then
    combines them in a way that makes some sense.  This is useful in routines
    that do panoramas, hdr, or focus stacks.  The returned filename is a representation
    of the files used to construct the image.  If there are 3 or fewer images, then the file
    basenames are concatenated with a separator. If there is more than 3 images, the first and 
    last file basenames are concatenated with a separator.]],
  Return_Value = [[result - string - the constructed filename on success, nil on error]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_processor.make_output_filename(image_table)
  local images = {}
  local cnt = 1
  local max_distinct_names = 3
  local name_separator = "-"
  local outputFileName = nil
  local result = {}

  for img,expimg in pairs(image_table) do
    table.insert(result, expimg)
  end
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

dtutils_processor.libdoc.functions["update_combobox_choices"] = {
  Name = [[update_combobox_choices]],
  Synopsis = [[change the list of choices in a combobox]],
  Usage = [[local du = require "lib/dtutils"

    du.update_combobox_choices(combobox_widget, choice_table)
      combobox_widget - lua_combobox - a combobox widget
      choice_table - table - a table of strings for the combobox choices]],
  Description = [[Set the combobox choices to the supplied list.  Remove any extra choices from the end. After
  reloading the choices, the value is set to 1 to force the combobox to update the displayed choices.]],
  Return_Value = [[]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function dtutils_processor.update_combobox_choices(combobox, choice_table)
  local items = #combobox
  local choices = #choice_table
  for i, name in ipairs(choice_table) do 
    log.msg(log.debug, "Setting choice " .. i .. " to " .. name)
    combobox[i] = name
  end
  if choices < items then
    for j = items, choices + 1, -1 do
      log.msg(log.debug, "Removing choice " .. j)
      combobox[j] = nil
    end
  end
  combobox.value = 1
end

return dtutils_processor
