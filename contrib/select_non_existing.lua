--[[
    This file is part of darktable,
    copyright (c) 2023 Dirk Dittmar

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
Enable selection of non-existing images in the the currently worked on images, e.g. the ones selected by the collection module.
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local ds = require "lib/dtutils.string"
local log = require "lib/dtutils.log"

-- module name
local MODULE <const> = "select_non_existing"

du.check_min_api_version("9.1.0", MODULE)

-- figure out the path separator
local PS <const> = dt.configuration.running_os == "windows" and  "\\"  or  "/"
local DEFAULT_LOG_LEVEL <const> = log.info

log.log_level(DEFAULT_LOG_LEVEL)

local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

local function stop_job(job)
    job.valid = false
end

local function get_file_list(dir)
  log.log_level(DEFAULT_LOG_LEVEL)
  local file_list = {}
  local cmd = nil
  log.msg(log.debug, "called get_file_list with " .. dir)

  if dt.configuration.running_os == "windows" then
    cmd = "forfiles /P " .. ds.sanitize(dir) .. " /M * /C \"cmd /c echo @file\""
  else
    cmd = "cd " .. ds.sanitize(dir) ..";ls -1"
  end
  log.msg(log.info, "cmd is " .. cmd)

  local p = io.popen(cmd)
  if p then
    for line in p:lines() do
      if line:len() > 4 then
        if not string.match(line, "xmp$") and not string.match(line, "XMP$") then
          line = line:gsub("\"", "")
          file_list[line] = true
        end
      end
    end
    p:close()
  end

  return file_list
end

local function select_nonexisting_images(event, images)
  log.log_level(DEFAULT_LOG_LEVEL)
  local selection = {}
  local known_files = {}

  local job = dt.gui.create_job(_("select non existing images"), true, stop_job)
  for key,image in ipairs(images) do
    if(job.valid) then
      if not known_files[image.path] then
        known_files[image.path] = get_file_list(image.path)
      end
      if key % 10 == 0 then
        job.percent = key/#images
      end
      local file_exists = known_files[image.path][image.filename]
      log.msg(log.debug, image.path .. PS .. image.filename .." exists? => "..tostring(file_exists))
      if (not file_exists) then
        table.insert(selection, image)
      end
    else
      break
    end
  end    
  stop_job(job)
  
  return selection
end

local function destroy()
    dt.gui.libs.select.destroy_selection(MODULE)
end
  
dt.gui.libs.select.register_selection(
    MODULE,
    _("select non existing"),
    select_nonexisting_images,
    _("select all non-existing images in the current images"))

local script_data = {}

script_data.metadata = {
  name = _("select non existing"),
  purpose = _("enable selection of non-existing images"),
  author = "Dirk Dittmar",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/select_non_existing"
}

script_data.destroy = destroy
return script_data