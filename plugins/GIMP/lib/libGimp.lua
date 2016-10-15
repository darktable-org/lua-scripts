--[[
    GIMP plugin library

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


]]

local dt = require "darktable"
local dtutils = require "lib/dtutils"
local dtfileutils = require "lib/dtutils.file"
local libPlugin = require "lib/libPlugin"

local gettext = dt.gettext
-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("gimp",dt.configuration.config_dir.."/lua/")

local function _(msgid)
    return gettext.dgettext("gimp", msgid)
end

libGimp = {}

--[[
  NAME
    libGimp.gimp_edit - edit the selected images with GIMP

  SYNOPSIS
    libGimp.gimp_edit(image_table, plugin_data)
      image_table - a table of images and exported image filenames to create the panorama from
      plugin_data - plugin configuration data

  DESCRIPTION
    gimp_edit opens the selected images in GIMP for further editing.  After editing the image is
    saved by overwriting the exported image.  The xcf file can also be saved and will be moved into
    the collection directory under pluin_data/gimp.  On exit from GIMP, the overwitten files are moved
    into the collection, imported into darktable, and grouped with the original images.

  RETURN VALUE
    none

  ERRORS
    


]]

function libGimp.gimp_edit(image_table, plugin_data) --finalize

  local collection_path = dtutils.extract_collection_path(image_table)

  local data_dir = collection_path .. "/" .. plugin_data.DtPluginDataDir

  libPlugin.create_data_dir(data_dir)

  -- list of exported images 
  local img_list = dtutils.extract_image_list(image_table)

  dt.print(_("Launching GIMP..."))

  local gimpStartCommand
  gimpStartCommand = "gimp "..img_list
  
  dt.print_error(gimpStartCommand)

  dt.control.execute( gimpStartCommand)

  -- for each of the image, exported image pairs
  --   move the exported image into the directory with the original  
  --   then import the image into the database which will group it with the original
  --   and then copy over any tags other than darktable tags

  for image,exported_image in pairs(image_table) do

    local myimage_name = image.path .. "/" .. dtfileutils.get_filename(exported_image)

    while dtfileutils.check_if_file_exists(myimage_name) do
      myimage_name = dtfileutils.filename_increment(myimage_name)
      -- limit to 99 more exports of the original export
      if string.match(dtfileutils.get_basename(myimage_name), "_(d-)$") == "99" then 
        break 
      end
    end

    dt.print_error("moving " .. exported_image .. " to " .. myimage_name)
    local result = dtfileutils.fileMove(exported_image, myimage_name)
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
    else
      dt.print(string.format(_("Unable to move edited file into collection. Leaving it as %s"), exported_image))
    end
    
    -- save the xcf file if it was created

    local xcf_file = dtfileutils.chop_filetype(exported_image) .. ".xcf"
    if dtfileutils.check_if_file_exists(xcf_file) then
      local xcf_result = dtfileutils.fileMove(xcf_file, data_dir .. "/" .. dtfileutils.get_filename(xcf_file))
      if not xcf_result then
        dt.print(string.format(_("Unable to move xcf file into data directory. Leaving it as %s"), xcf_file))
      end
    end
  end
end

return libGimp
