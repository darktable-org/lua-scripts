--[[ fujifilm_dynamic_range-0.1

Compensate for Fujifilm raw files made using "dynamic range".

Copyright (C) 2020 Dan Torop <dant@pnym.net>

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
]]

--[[About this Plugin
Support for adjusting darktable exposure by Fujifilm raw exposure
bias. This corrects for a DR100/DR200/DR400 "dynamic range" setting.

Dependencies:
- exiftool (https://www.sno.phy.queensu.ca/~phil/exiftool/)

Based upon fujifilm_ratings by Ben Mendis

--]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local gettext = dt.gettext

du.check_min_api_version("4.0.0", "fujifilm_dynamic_range")

gettext.bindtextdomain("fujifilm_dynamic_range", dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
	return gettext.dgettext("fujifilm_dynamic_range", msgid)
end

local function detect_dynamic_range(event, image)
	-- exiftool knows about the RawExposureBias tag, unlike exiv2, but it is also 10x slower
	if not df.check_if_bin_exists("exiftool") then
		dt.print_error(_("exiftool not found"))
		return
	end
	local RAF_filename = df.sanitize_filename(tostring(image))
	local command = "exiftool -RawExposureBias " .. RAF_filename
	dt.print_error(command)
	output = io.popen(command)
	local raf_result = output:read("*all")
	output:close()
	if string.len(raf_result) > 0 then
		raf_result = string.gsub(raf_result, "^Raw Exposure Bias.-([%d%.%-]+)", "%1")
		if image.exif_exposure_bias ~= image.exif_exposure_bias then
			-- is NAN (this is unlikely as RAFs should have ExposureBiasValue set)
			image.exif_exposure_bias = 0
		end
		-- this should be auto-applied if plugins/darkroom/workflow is scene-referred
		-- FIXME: scene-referred workflow pushes exposure up 0.5 EV, but DR100 pushes up 0.7 EV -- should reduce this by 0.5 EV?
		image.exif_exposure_bias = image.exif_exposure_bias + tonumber(raf_result)
		dt.print_error(_("Using RAF exposure bias: ") .. tostring(raf_result))
	end
end

dt.register_event("post-import-image", detect_dynamic_range)

print(_("fujifilm_dynamic_range loaded."))
