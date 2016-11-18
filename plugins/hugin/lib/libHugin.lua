--[[
  Hugin plugin library for darktable 

  copyright (c) 2014  Wolfgang Goetz
  copyright (c) 2015  Christian Kanzian
  copyright (c) 2015  Tobias Jakobs
  copyright (c) 2016  Bill Ferguson
  
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

local dt = require "darktable"
local dtutils = require "lib/dtutils"
local df = require "lib/dtutils.file"
local dp = require "lib/dtutils.processor"
local libPlugin = require "lib/libPlugin"

libHugin = {}

local gettext = dt.gettext

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("hugin",dt.configuration.config_dir.."/lua/")

local function _(msgid)
    return gettext.dgettext("hugin", msgid)
end

--[[
  NAME
    libHugin.create_panorama - create a panorama from the supplied images

  SYNOPSIS
    libHugin.create_panorama(image_table, pd)
      image_table - a table of images and exported image filenames to create the panorama from
      pd - plugin configuration data

  DESCRIPTION
    create_panorama takes the supplied images and passes that to hugin for processing.  On exit
    from hugin, the resulting image is imported into darktable.  Artifacts (the pto file) is moved
    into the collection directory under plugin_data/hugin

  RETURN VALUE
    none

  ERRORS
    A message is printed if the process fails.  Any leftover files are cleaned up.


]]
function libHugin.create_panorama(image_table, pd)

-- Since Hugin 2015.0.0 hugin provides a command line tool to start the assistant
-- http://wiki.panotools.org/Hugin_executor
-- We need pto_gen to create pto file for hugin_executor
-- http://hugin.sourceforge.net/docs/manual/Pto_gen.html

  local hugin_executor = false
  if (df.check_if_bin_exists("hugin_executor") and df.check_if_bin_exists("pto_gen")) then
    hugin_executor = true
  end

  -- list of exported images 
  local img_list = dp.extract_image_list(image_table)
  local collection_path = dp.extract_collection_path(image_table)

  local data_dir = collection_path .. "/" .. pd.DtPluginDataDir

  libPlugin.create_data_dir(data_dir)

  local data_filename = dp.make_output_filename(image_table)

  
  dt.print(_("Will try to stitch now"))

  local huginStartCommand
  if (hugin_executor) then
    huginStartCommand = "pto_gen "..img_list.." -o "..dt.configuration.tmp_dir.."/project.pto"
    dt.print(_("Creating pto file"))
    dt.control.execute( huginStartCommand)

    dt.print(_("Running Assistant"))
    huginStartCommand = "hugin_executor --assistant "..dt.configuration.tmp_dir.."/project.pto"
    dt.control.execute( huginStartCommand)

    huginStartCommand = "hugin "..dt.configuration.tmp_dir.."/project.pto"
  else
    huginStartCommand = "hugin "..img_list
  end
  
  dt.print_error(huginStartCommand)

  if dp.job_failed(dt.control.execute( huginStartCommand)) then
    dt.print(_("Command hugin failed ..."))
    -- cleanup after
    -- use os.execute("rm") because it can remove the whole list at once
    os.execute("rm" .. img_list)
    if hugin_executor then
      os.remove(dt.configuration.tmp_dir.."/project.pto")
    end
  else
    -- remove the exported files
    -- use os.execute("rm") because it can remove the whole list at once
    os.execute("rm" .. img_list)
    if hugin_executor then
      -- save the pto file in the plugin data dir
      local pto_filename = data_dir .. "/" .. data_filename .. ".pto"
      while df.check_if_file_exists(pto_filename) do
        pto_filename = df.filename_increment(pto_filename)
        -- limit to 99 more exports of the original export
        if string.match(df.get_basename(pto_filename), "_(d-)$") == "99" then 
          break 
        end
      end
      df.file_move(dt.configuration.tmp_dir.."/project.pto", pto_filename)
    end
    -- the only tif left should be the program output
    -- move the resulting tif, project.tif into the collection and import it
    -- then tag it as created by hugin
    local myimg_name = collection_path .. "/" .. data_filename .. ".tif"
    while df.check_if_file_exists(myimg_name) do
      myimg_name = df.filename_increment(myimg_name)
      -- limit to 99 more exports of the original export
      if string.match(df.get_basename(myimg_name), "_(d-)$") == "99" then 
        break 
      end
    end
    df.file_move(dt.configuration.tmp_dir.."/project.tif", myimg_name)
    local myimage = dt.database.import(myimg_name)
    local tag = dt.tags.create("Creator|Hugin")
    dt.tags.attach(tag, myimage)

    -- remove any other "project" effects
    os.execute("rm " .. dt.configuration.tmp_dir .. "/project*")
  end
end

return libHugin
