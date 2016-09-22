--[[
  Hugin storage for darktable 

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

--[[
HUGIN
Add a new storage option to send images to hugin. 
Images are exported to darktable tmp dir first. 

ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
* hugin

USAGE
* require this file from your main luarc config file.

This plugin will add a new storage option and calls hugin after export.
]]

local dt = require "darktable"
local dtutils = require "lib/dtutils"
local libpi = require "lib/libPlugins"
local pd = require "plugins/hugin/plugin-data"


local gettext = dt.gettext

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("hugin",dt.configuration.config_dir.."/lua/")

local function _(msgid)
    return gettext.dgettext("hugin", msgid)
end

local function create_panorama(storage, image_table, extra_data) --finalize

-- Since Hugin 2015.0.0 hugin provides a command line tool to start the assistant
-- http://wiki.panotools.org/Hugin_executor
-- We need pto_gen to create pto file for hugin_executor
-- http://hugin.sourceforge.net/docs/manual/Pto_gen.html

  local hugin_executor = false
  if (dtutils.checkIfBinExists("hugin_executor") and dtutils.checkIfBinExists("pto_gen")) then
    hugin_executor = true
  end

  -- list of exported images 
  local img_list = dtutils.extract_image_list(image_table)
  local collection_path = dtutils.extract_collection_path(image_table)

  local data_dir = collection_path .. "/" .. pd.DtPluginDataDir

  libpi.create_data_dir(data_dir)

  local data_filename = dtutils.makeOutputFileName(img_list)

  
  dt.print(_("Will try to stitch now"))

  local huginStartCommand
  if (hugin_executor) then
    huginStartCommand = "pto_gen "..img_list.." -o "..dt.configuration.tmp_dir.."/project.pto"
    dt.print(_("Creating pto file"))
    dt.control.execute( huginStartCommand)

    dt.print(_("Running Assistent"))
    huginStartCommand = "hugin_executor --assistant "..dt.configuration.tmp_dir.."/project.pto"
    dt.control.execute( huginStartCommand)

    huginStartCommand = "hugin "..dt.configuration.tmp_dir.."/project.pto"
  else
    huginStartCommand = "hugin "..img_list
  end
  
  dt.print_error(huginStartCommand)

  if dt.control.execute( huginStartCommand)
    then
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
      while checkIfFileExists(pto_filename) do
        pto_filename = filename_increment(pto_filename)
        -- limit to 99 more exports of the original export
        if string.match(get_basename(pto_filename), "_(d-)$") == "99" then 
          break 
        end
      end
      dtutils.fileMove(dt.configuration.tmp_dir.."/project.pto", pto_filename)
    end
    -- the only tif left should be the program output
    -- move the resulting tif, project.tif into the collection and import it
    -- then tag it as created by hugin
    local myimg_name = collection_path .. "/" .. data_filename .. ".tif"
    while checkIfFileExists(myimg_name) do
      myimg_name = filename_increment(myimg_name)
      -- limit to 99 more exports of the original export
      if string.match(get_basename(myimg_name), "_(d-)$") == "99" then 
        break 
      end
    end
    dtutils.fileMove(dt.configuration.tmp_dir.."/project.tif", myimg_name)
    local myimage = dt.database.import(myimg_name)
    local tag = dt.tags.create("Creator|Hugin")
    dt.tags.attach(tag, myimage)

    -- remove any other "project" effects
    os.execute("rm " .. dt.configuration.tmp_dir .. "/project.*")
  end
end

-- Register
dt.register_storage("module_hugin", _("Hugin Panorama"), dtutils.show_status, create_panorama)

--
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
