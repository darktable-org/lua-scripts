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
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local log = require "lib/dtutils.log"
local dtsys = require "lib/dtutils.system"
local gettext = dt.gettext.gettext

local namespace = 'module_hugin'
local user_pref_str = 'prefer_gui'
local user_prefer_gui = dt.preferences.read(namespace, user_pref_str, "bool")
log.msg(log.info, "user_prefer_gui set to ", user_prefer_gui)
local hugin_widget = nil
local exec_widget = nil
local executable_table = {"hugin", "hugin_executor", "pto_gen"}

-- get the proper path quoting quote
local PQ = dt.configuration.running_os == "windows" and '"' or "'"

-- works with darktable API version from 5.0.0 on
du.check_min_api_version("7.0.0", "hugin") 

local function _(msgid)
  return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("hugin"),
  purpose = _("stitch images into a panorama"),
  author = "Wolfgang Goetz",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/hugin"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

local function user_preference_changed(widget)
  user_prefer_gui = widget.value
  dt.preferences.write(namespace, user_pref_str, "bool", user_prefer_gui)
end

local function show_status(storage, image, format, filename,
  number, total, high_quality, extra_data)
  dt.print(string.format(_("exporting to hugin: %d / %d"), number, total))
end

local function create_panorama(storage, image_table, extra_data) --finalize
-- Since Hugin 2015.0.0 hugin provides a command line tool to start the assistant
-- http://wiki.panotools.org/Hugin_executor
-- We need pto_gen to create pto file for hugin_executor
-- http://hugin.sourceforge.net/docs/manual/Pto_gen.html

  -- save the current log level and set log level to
  --   log.error for normal operations
  --   log.info for more insight about what is happening
  --   log.debug for even more information

  local saved_log_level = log.log_level()
  log.log_level(log.error)

  local hugin = df.check_if_bin_exists("hugin")
  log.msg(log.info, "hugin set to ", hugin)
  local hugin_executor = df.check_if_bin_exists("hugin_executor")
  log.msg(log.info, "hugin_executor set to ", hugin_executor)
  local pto_gen = df.check_if_bin_exists("pto_gen")
  log.msg(log.info, "pto_gen set to ", pto_gen)

  local gui_available = false
  if hugin then
    gui_available = true
  else
    dt.print(_("hugin is not found, did you set the path?"))
    log.msg(log.error, "hugin executable not found.  Check if the executable is installed.")
    log.msg(log.error, "If the executable is installed, check that the path is set correctly.")
    return
  end

  local cmd_line_available = false
  if hugin_executor and pto_gen then
    cmd_line_available = true
  end

  -- list of exported images
  local img_list = ""
  local img_set = {}

  -- reset and create image list
  for k,v in pairs(image_table) do
    log.msg(log.debug, "k is ", k, " and v is ", v)
    img_list = img_list .. PQ .. v .. PQ .. ' '  -- surround the filename with single quotes to handle spaces
    table.insert(img_set, k)
  end

  log.msg(log.info, "img_list is ", img_list)

  -- use first file as basename for output file
  table.sort(img_set, function(a,b) return a.filename<b.filename end);
  local first_file
  for _, k in ipairs(img_set) do
    first_file = k 
    break
  end

  if first_file == nil then
    dt.print(_("no file selected"))
    return
  end

  local pto_path = dt.configuration.tmp_dir..'/project.pto'
  log.msg(log.info, "pto_path is ", pto_path)
  local filepath = df.split_filepath(first_file.filename)
  log.msg(log.info, "filepath is ", filepath)
  local tmp_filename = filepath['basename'].."_pano.tif"
  log.msg(log.info, "tmp_filename is ", tmp_filename)
-- some versions of hugin_executor don't seem to output the result
-- to the --prefix location, so assume we are working in the tmp
-- directory and then move the file to the original file location afterwards
  local src_path = dt.configuration.tmp_dir.."/"..tmp_filename
  log.msg(log.info, "src_path is ", src_path)
  local dst_path = first_file.path..'/'..tmp_filename
  log.msg(log.info, "dst_path is ", dst_path)

  if df.check_if_file_exists(dst_path) then
    dst_path = df.create_unique_filename(dst_path)
    log.msg(log.info, "dst_path updated to ", dts_path)
  end

  dt.print(_("will try to stitch now"))
  local huginStartCommand = nil
  if (cmd_line_available and not user_prefer_gui) then
    log.msg(log.info, "using the command line tools to create panorama")
    huginStartCommand = pto_gen.." "..img_list.." -o "..pto_path
    dt.print(_("creating pto file"))
    log.msg(log.info, "pto creation command is ", huginStartCommand)
    dtsys.external_command(huginStartCommand)

    dt.print(_("running assistant"))
    huginStartCommand = hugin_executor.." --assistant "..pto_path
    dtsys.external_command(huginStartCommand)

    huginStartCommand = hugin_executor..' --stitching --prefix=' .. "'" .. src_path .. "'" .. ' ' .. pto_path
    log.msg(log.info, "command line huginStartCommand is ", huginStartCommand)
  elseif gui_available then
    if (user_prefer_gui) then
      dt.print(_("launching hugin"))
    else
      dt.print(_("unable to find command line tools, launching hugin"))
    end
    -- the gui produces a differnt output filename than the command line
    src_path = dt.configuration.tmp_dir .. "/" .. df.get_basename(img_set[1].filename) .. " - " .. df.get_basename(img_set[#img_set].filename) .. ".tif"
    log.msg(log.info, "set src_path to ", src_path)
    huginStartCommand = hugin..' '..img_list
    log.msg(log.info, "gui huginStartCommand is ", huginStartCommand)
  else
    dt.print(_("hugin isn't available."))
  end

  if not (huginStartCommand==nil) then
    if not dtsys.external_command(huginStartCommand) then
      dt.print(_("hugin failed ..."))
      log.msg(log.error, huginStartCommand, " failed")
    else
      if df.check_if_file_exists(src_path) then
        log.msg(log.debug, "found ", src_path, " importing to ", dst_path)
        df.file_move(src_path, dst_path)
        dt.print(string.format(_("importing file %s"), dst_path))
        dt.database.import(dst_path)
      end
    end
    log.log_level(saved_log_level)
  end

  -- cleanup the temp files
  for k,v in pairs(image_table) do
    os.remove(v)
  end
end

local function destroy()
  dt.destroy_storage(namespace)
end

-- Register
if dt.configuration.running_os ~= "linux" then
  exec_widget = df.executable_path_widget(executable_table)
end

hugin_widget = dt.new_widget("box") {
  orientation = "vertical",
  dt.new_widget("check_button")
  {
    label = _("launch hugin gui"),
    value = user_prefer_gui,
    tooltip = _('launch hugin in gui mode'),
    clicked_callback = user_preference_changed
  },
  exec_widget
}

dt.register_storage(namespace, _("hugin panorama"), show_status, create_panorama, nil, nil, hugin_widget)

script_data.destroy = destroy

return script_data
--
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
