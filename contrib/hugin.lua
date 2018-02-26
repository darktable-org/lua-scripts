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
* require this file from your main luarc config file
* set the hugin tool paths in preferences
* if hugin gui mode is used, save the final result in the tmp directory with the first file name and _pano as suffix for the image to be automatically imported to DT afterwards

This plugin will add a new storage option and calls hugin after export.
]]

local dt = require "darktable"
local df = require "lib/dtutils.file"
require "official/yield"
local gettext = dt.gettext
local namespace = 'module_hugin'

-- works with darktable API version from 2.0.0 to 5.0.0
dt.configuration.check_version(...,{2,0,0},{3,0,0},{4,0,0},{5,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("hugin",dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
  return gettext.dgettext("hugin", msgid)
end

local function show_status(storage, image, format, filename,
  number, total, high_quality, extra_data)
  dt.print("exporting to Hugin: "..tostring(number).."/"..tostring(total))
end

-- windows platform don't like / or \ in the path when launching executables
local function clean_path(path)
  if (dt.configuration.running_os == 'windows') then
    return string.gsub(path, '[\\/]+', '\\\\')
  else
    return path
  end
end

local function create_panorama(storage, image_table, extra_data) --finalize
-- Since Hugin 2015.0.0 hugin provides a command line tool to start the assistant
-- http://wiki.panotools.org/Hugin_executor
-- We need pto_gen to create pto file for hugin_executor
-- http://hugin.sourceforge.net/docs/manual/Pto_gen.html

  local hugin = clean_path('"'..dt.preferences.read(namespace, "hugin", "file")..'"')
  local hugin_executor = clean_path('"'..dt.preferences.read(namespace, "hugin_executor", "file")..'"')
  local pto_gen = clean_path('"'..dt.preferences.read(namespace, "pto_gen", "file")..'"')
  local user_prefer_gui = dt.preferences.read(namespace, "hugin_prefer_gui", "bool")

  local cmd_line_available = false
  if df.check_if_bin_exists(hugin_executor) and df.check_if_bin_exists(pto_gen) then
    cmd_line_available = true
  end

  local gui_available = false
  if df.check_if_bin_exists(hugin) then
    gui_available = true
  end

  -- list of exported images
  local img_list
  local img_set = {}

  -- reset and create image list
  img_list = ""
  for k,v in pairs(image_table) do
    img_list = img_list..v..' '
    table.insert(img_set, k)
  end

  -- use first file as basename for output file
  table.sort(img_set, function(a,b) return a.filename<b.filename end);
  local first_file
  for _, k in ipairs(img_set) do
    first_file = k break
  end

  local pto_path = dt.configuration.tmp_dir..'/project.pto'
  local filepath = df.split_filepath(first_file.filename)
  local tmp_filename = filepath['basename'].."_pano.tif"
-- some versions of hugin_executor don't seem to output the result
-- to the --prefix location, so assume we are working in the tmp
-- directory and then move the file to the original file location afterwards
  local src_path = dt.configuration.tmp_dir.."/"..tmp_filename
  local dst_path = first_file.path..'/'..tmp_filename

  if df.check_if_file_exists(dst_path) then
    dst_path = df.create_unique_filename(dst_path)
  end

  dt.print(_("will try to stitch now"))
  local huginStartCommand = nil
  if (cmd_line_available and not user_prefer_gui) then
    huginStartCommand = pto_gen.." "..img_list.." -o "..pto_path
    dt.print(_("creating pto file"))
    dt.control.execute(huginStartCommand)

    dt.print(_("running assistent"))
    huginStartCommand = hugin_executor.." --assistant "..pto_path
    dt.control.execute(huginStartCommand)

    huginStartCommand = hugin_executor..' --stitching --prefix='..src_path..' '..pto_path
  elseif gui_available then
    dt.print(_("launching hugin"))
    huginStartCommand = hugin..' '..img_list
  else
    dt.print(_("hugin isn't available, please set its path in preferences."))
  end

  if not (huginStartCommand==nil) then
    if not dt.control.execute(huginStartCommand) then
      dt.print(_("command hugin failed ..."))
    else
      if df.check_if_file_exists(src_path) then
        df.file_move(src_path, dst_path)
        dt.print(_("importing file "..dst_path))
        dt.database.import(dst_path)
      end
    end
  end

  -- cleanup the temp files
  for k,v in pairs(image_table) do
    os.remove(v)
  end
end

-- Register
dt.register_storage(namespace, _("hugin panorama"), show_status, create_panorama)
dt.preferences.register(namespace, "pto_gen", "file", _("pto_gen location"), "choose the pto_gen executable.", "/usr/bin/pto_gen")
dt.preferences.register(namespace, "hugin_executor", "file", _("hugin_executor location"), "choose the hugin_executor executable.", "/usr/bin/hugin_executor")
dt.preferences.register(namespace, "hugin", "file", _("hugin location"), "choose the hugin executable", "/usr/bin/hugin")
dt.preferences.register(namespace, "hugin_prefer_gui", "bool", _("prefer hugin gui over command line"), "always launches hugin gui instead of automated from command line.", false)

--
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
