--[[ fujifilm_ratings-0.1

Support for importing Fujifilm in-camera ratings in darktable.

Copyright (C) 2017 Ben Mendis <ben.mendis@gmail.com>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

Dependencies:
- exiftool (https://www.sno.phy.queensu.ca/~phil/exiftool/)

--]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local dtsys = require "lib/dtutils.system"
local gettext = dt.gettext.gettext

du.check_min_api_version("7.0.0", "fujifilm_ratings") 

local function _(msgid)
	return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("fujifilm ratings"),
  purpose = _("import Fujifilm in-camera ratings"),
  author = "Ben Mendis <ben.mendis@gmail.com>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/fujifilm_ratings"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

local function detect_rating(event, image)
	if not string.match(image.filename, "%.RAF$") and not string.match(image.filename, "%.raf$") then
		return
	end
	if not df.check_if_bin_exists("exiftool") then
		dt.print_error("exiftool not found")
		return
	end
	local RAF_filename = df.sanitize_filename(tostring(image))
	local JPEG_filename = string.gsub(RAF_filename, "%.RAF$", ".JPG")
	local command = "exiftool -Rating " .. JPEG_filename
	dt.print_log(command)
	local output = io.popen(command)
	local jpeg_result = output:read("*all")
	output:close()
	if string.len(jpeg_result) > 0 then
		jpeg_result = string.gsub(jpeg_result, "^Rating.*(%d)", "%1")
		image.rating = tonumber(jpeg_result)
		dt.print_log("using JPEG rating: " .. jpeg_result)
		return
	end
	command = "exiftool -Rating " .. RAF_filename
	dt.print_log(command)
	output = io.popen(command)
	local raf_result = output:read("*all")
	output:close()
	if string.len(raf_result) > 0 then
		raf_result = string.gsub(raf_result, "^Rating.*(%d)", "%1")
		image.rating = tonumber(raf_result)
		dt.print_log("using RAF rating: " .. raf_result)
	end
end

local function destroy()
	dt.destroy_event("fujifilm_rat", "post-import-image")
end

dt.register_event("fujifilm_rat", "post-import-image", 
	detect_rating)

script_data.destroy = destroy
return script_data
