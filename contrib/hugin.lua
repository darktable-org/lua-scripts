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
* set the hugin tool paths (on some platforms)
* if hugin gui mode is used, save the final result in the tmp directory with the first file name and _pano as suffix for the image to be automatically imported to DT afterwards

This plugin will add a new storage option and calls hugin after export.
]]

local dt = require "darktable"
local df = require "lib/dtutils.file"
require "official/yield"
local gettext = dt.gettext

local namespace = 'module_hugin'
local user_pref_str = 'prefer_gui'
local user_prefer_gui = dt.preferences.read(namespace, user_pref_str, "bool")
local hugin_widget = nil
local exec_widget = nil
local executable_table = {"hugin", "hugin_executor", "pto_gen"}

-- works with darktable API version from 2.0.0 to 5.0.0
dt.configuration.check_version(...,{5,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("hugin",dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
  return gettext.dgettext("hugin", msgid)
end

local function user_preference_changed(widget)
  user_prefer_gui = widget.value
  dt.preferences.write(namespace, user_pref_str, "bool", user_prefer_gui)
end

local function show_status(storage, image, format, filename,
  number, total, high_quality, extra_data)
  dt.print("exporting to hugin: "..tostring(number).."/"..tostring(total))
end

local function create_panorama(storage, image_table, extra_data) --finalize
-- Since Hugin 2015.0.0 hugin provides a command line tool to start the assistant
-- http://wiki.panotools.org/Hugin_executor
-- We need pto_gen to create pto file for hugin_executor
-- http://hugin.sourceforge.net/docs/manual/Pto_gen.html

  local hugin = df.check_if_bin_exists("hugin")
  local hugin_executor = df.check_if_bin_exists("hugin_executor")
  local pto_gen = df.check_if_bin_exists("pto_gen")

  local gui_available = false
  if hugin then
    gui_available = true
  else
    dt.print(_("hugin is not found, did you set the path?"))
    return
  end

  local cmd_line_available = false
  if hugin_executor and pto_gen then
    cmd_line_available = true
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

  if first_file == nil then
    dt.print("no file selected")
    return
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
    if (user_prefer_gui) then
      dt.print(_("launching hugin"))
    else
      dt.print(_("unable to find command line tools, launching hugin"))
    end
    huginStartCommand = hugin..' '..img_list
  else
    dt.print(_("hugin isn't available."))
  end

  if not (huginStartCommand==nil) then
    if not dt.control.execute(huginStartCommand) then
      dt.print(_("hugin failed ..."))
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
if dt.configuration.running_os ~= "linux" then
  exec_widget = df.executable_path_widget(executable_table)
end

hugin_widget = dt.new_widget("box") {
  orientation = "vertical",
  dt.new_widget("check_button")
  {
    label = _("  launch hugin gui"),
    value = user_prefer_gui,
    tooltip = _('launch hugin in gui mode'),
    clicked_callback = user_preference_changed
  },
  exec_widget
}

dt.register_storage(namespace, _("hugin panorama"), show_status, create_panorama, nil, nil, hugin_widget)

--
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua