--[[
  Hugin storage for darktable

  copyright (c) 2014  Wolfgang Goetz
  copyright (c) 2015  Christian Kanzian
  copyright (c) 2015  Tobias Jakobs

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
local df = require "lib/dtutils.file"
require "official/yield"
local gettext = dt.gettext

-- works with darktable API version from 2.0.0 to 5.0.0
dt.configuration.check_version(...,{2,0,0},{3,0,0},{4,0,0},{5,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("hugin",dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
    return gettext.dgettext("hugin", msgid)
end

local function show_status(storage, image, format, filename,
  number, total, high_quality, extra_data)
  dt.print("Export to Hugin "..tostring(number).."/"..tostring(total))
end

local function create_panorama(storage, image_table, extra_data) --finalize
  if not df.check_if_bin_exists("hugin") then
    dt.print_error(_("hugin not found"))
    return
  end

-- Since Hugin 2015.0.0 hugin provides a command line tool to start the assistant
-- http://wiki.panotools.org/Hugin_executor
-- We need pto_gen to create pto file for hugin_executor
-- http://hugin.sourceforge.net/docs/manual/Pto_gen.html

  local hugin_executor = false
  if (df.check_if_bin_exists("hugin_executor") and df.check_if_bin_exists("pto_gen")) then
    hugin_executor = true
  end

  -- list of exported images
  local img_list

  -- reset and create image list
  img_list = ""

  for _,v in pairs(image_table) do
    img_list = img_list ..v.. " "
  end

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

  if not dt.control.execute(huginStartCommand)
    then
    dt.print(_("Command hugin failed ..."))
  end

end

-- Register
dt.register_storage("module_hugin", _("Hugin Panorama"), show_status, create_panorama)

--
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
