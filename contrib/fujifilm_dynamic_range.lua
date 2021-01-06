--[[ fujifilm_dynamic_range-0.1

Compensate for Fujifilm raw files made using "dynamic range".

Copyright (C) 2021 Dan Torop <dant@pnym.net>

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

The relevant tag is RawExposureBias (0x9650). This appears to
represent the shift in EV for the chosen DR setting (whether manual or
automatic). Note that even at 100DR ("standard") there is an EV shift:

100 DR -> -0.72 EV
200 DR -> -1.72 EV
400 DR -> -2.72 EV

The ideal would be to use exiv2 to read this tag, as this is the same
code which darktable import uses. Unfortunately, exiv2 as of v0.27.3
can't read this tag. As it is encoded as a 4-byte ratio of two signed
shorts -- a novel data type -- it will require some attention to fix
this.

There is an exiv2-readable DevelopmentDynamicRange tag which maps to
RawExposureBias as above.  DevelopmentDynamicRange is only present
when tag DynamicRangeSetting (0x1402) is Manual/Raw (0x0001). When it
is Auto (0x0000), the equivalent data is tag AutoDynamicRange
(0x140b). But exiv2 currently can't read that tag either.

Hence for now this code uses exiftool to read RawExposureBias, as a
more general solution. As exiftool is approx. 10x slower than exiv2
(Perl vs. C++), this may slow large imports.

These tags have been checked on a Fujifilm X100S and X100V. Other
cameras may behave in other ways.

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
	if not df.check_if_bin_exists("exiftool") then
		dt.print_error(_("exiftool not found"))
		return
	end
	local RAF_filename = df.sanitize_filename(tostring(image))
	-- without -n flag, exiftool will round to the nearest tenth
	local command = "exiftool -RawExposureBias -n -t " .. RAF_filename
	dt.print_log(command)
	output = io.popen(command)
	local raf_result = output:read("*all")
	output:close()
	if string.len(raf_result) > 0 then
		raf_result = string.match(raf_result, "\t(.*)")
		if raf_result then
			if image.exif_exposure_bias ~= image.exif_exposure_bias then
				-- is NAN (this is unlikely as RAFs should have ExposureBiasValue set)
				image.exif_exposure_bias = 0
			end
			-- this should be auto-applied if plugins/darkroom/workflow is scene-referred
			-- note that scene-referred workflow exposure preset also pushes exposure up by 0.5 EV
			image.exif_exposure_bias = image.exif_exposure_bias + tonumber(raf_result)
			dt.print_log(_("Using RAF exposure bias: ") .. tostring(raf_result))
		else
			dt.print_error(_("Could not parse exiftool output."))
		end
	else
		dt.print_error(_("No output returned by exiftool."))
	end
end

dt.register_event("post-import-image", detect_dynamic_range)

dt.print_log(_("fujifilm_dynamic_range loaded."))
