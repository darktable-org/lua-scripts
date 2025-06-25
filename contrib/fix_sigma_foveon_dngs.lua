--[[ fix-sigma-foveon-dngs-v0.1

Fix Sigma Foveon DNGs white balance handling

Copyright (C) 2025 Stephan Kleinert <stephan@schallundstille.de>

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

This plugin provides a workaround for a bug that causes the colors in a
Sigma Foveon DNG to be displayed incorrectly. The bug is described in
depth here:

https://github.com/darktable-org/darktable/issues/16586

It works by disabling color calibration and resetting white balance
to "as shot" upon first loading a Sigma Foveon DNG image in the darkroom. It
is applied only once, i.e., you're free to adjust the white balance
setting as you see fit without the plugin interfering on the next load.

With many thanks to Bill Ferguson for pointing me on the right track.

]]

local dt = require "darktable"
local du = require "lib/dtutils"
local gettext = dt.gettext.gettext

du.check_min_api_version("7.0.0", "fix_sigma_foveon_dngs")

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
    name = _("Fix Sigma Foveon DNG files"),
    purpose = _("Workaround for Sigma Foveon DNG white balance problems"),
    author = "Stephan Kleinert <stephan@schallundstille.de>",
    help = "https://schallundstille.de/"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

sad_cameras = { "sd Quattro", "sd Quattro H", "SIGMA dp2 Quattro",                  -- unfortunately, I've only ever had these
                "SIGMA dp3 Quattro", "SIGMA dp1 Quattro", "SIGMA dp0 Quattro" }     -- not sure about these

dt_fixed_tag = dt.tags.create("darktable|foveon_fixed")

function contains(list, target)
    for _, value in ipairs(list) do
        if value == target then
            return true
        end
    end
    return false
end

local function fix_image()
    -- first, disable colour calibration, as it wreaks havoc with sigma foveon DNGs
    dt.gui.action("iop/channelmixerrgb/adaptation", "selection", "item:none (bypass)", 1,000, 0)
    -- then, set white balance to "as shot", forcing the white balance module to re-read the white balance data from the DNG
    -- (if there was a way to simply re-apply *this* setting via a preset, none of this would be necessary, just saying)
    dt.gui.action("iop/temperature/settings/as shot", "", "on", 1,000)
end

local function fix_on_load(event, clean, image)
    if not clean then
        return
    end
    if image.exif_maker ~= "SIGMA" then
        dt.print_log("[fix_sigma_foveon_dngs] ignoring non-Sigma image")
        return
    end
    if not contains(sad_cameras, image.exif_model) then
            dt.print_log("[fix_sigma_foveon_dngs] ignoring (seemingly) non-foveon camera: "..image.exif_model)
        return
    end
    if contains(dt.tags.get_tags(image), dt_fixed_tag) then
        dt.print_log("image already foveon_fixed")
        return
    end
    fix_image()
    dt.tags.attach(dt_fixed_tag, image)
end

dt.register_event("fix_sigma_foveon_dngs", "darkroom-image-loaded", fix_on_load)

dt.print_log("[fix_sigma_foveon_dngs] loaded")
