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
local df = require "lib/dtutils.file"
local gettext = dt.gettext

dt.configuration.check_version(..., {4,0,0})

gettext.bindtextdomain("fujifilm_ratings", dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
	return gettext.dgettext("fujifilm_ratings", msgid)
end

local function detect_rating(event, image)
	if not df.check_if_bin_exists("exiftool") then
		dt.print_error(_("exiftool not found"))
		return
	end
	local RAF_filename = tostring(image)
	local JPEG_filename = string.gsub(RAF_filename, "%.RAF$", ".JPG")
	local command = "exiftool -Rating " .. JPEG_filename
	dt.print_error(command)
	local output = io.popen(command)
	local jpeg_result = output:read("*all")
	output:close()
	if string.len(jpeg_result) > 0 then
		jpeg_result = string.gsub(jpeg_result, "^Rating.*(%d)", "%1")
		image.rating = tonumber(jpeg_result)
		dt.print_error(_("Using JPEG Rating: ") .. tostring(jpeg_result))
		return
	end
	command = "exiftool -Rating " .. RAF_filename
	dt.print_error(command)
	output = io.popen(command)
	local raf_result = output:read("*all")
	output:close()
	if string.len(raf_result) > 0 then
		raf_result = string.gsub(raf_result, "^Rating.*(%d)", "%1")
		image.rating = tonumber(raf_result)
		dt.print_error(_("Using RAF Rating: ") .. tostring(raf_result))
	end
end

dt.register_event("post-import-image", detect_rating)

print(_("fujifilm_ratings loaded."))
