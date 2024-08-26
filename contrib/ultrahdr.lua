--[[

  UltraHDR storage for darktable

  copyright (c) 2024  Krzysztof Kotowicz

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

ULTRAHDR
Add a new storage option to generate UltraHDR JPG images.

https://developer.android.com/media/platform/hdr-image-format

Of all exported files, the storage detects pairs of files generated from the same source image, 
assuming the first one encountered is the base SDR image, and the second one is the gainmap
(alternatively, you can tag the gainmaps with a "gainmap" tag).

The images are merged using libultrahdr example application (ultrahdr_app).

ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
* ultrahdr_app (from https://github.com/google/libultrahdr example dir)
* exiftool

USAGE
* require this file from your main luarc config file
* set exiftool and libultrahdr_app tool paths

This plugin will add a new storage option.

]]
local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local log = require "lib/dtutils.log"
local dtsys = require "lib/dtutils.system"
local gettext = dt.gettext.gettext

local namespace = 'module_ultrahdr'

-- works with darktable API version from 5.0.0 on
du.check_min_api_version("7.0.0", "ultrahdr")

dt.gettext.bindtextdomain("ultrahdr", dt.configuration.config_dir .. "/lua/locale/")

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
    name = "ultrahdr",
    purpose = _("generate UltraHDR images"),
    author = "Krzysztof Kotowicz"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

local function image_path(image)
    return image.path .. "/" .. image.filename
end

local ENCODING_VARIANT_API_4 = 1

local function get_encoding_variant()
    local encoding_variant = dt.preferences.read("ultrahdr", "encoding variant", "integer")
    if not encoding_variant then
        encoding_variant = ENCODING_VARIANT_API_4
    end
    return encoding_variant
end

local function merge_ultrahdr_api4(base, gainmap, ultrahdr_app, exiftool, output)
    local metadata = dt.preferences.read("ultrahdr", "metadata path", "string")
    if not df.check_if_file_exists(metadata) then
        dt.print(_("metadata file not found, did you set the correct path?"))
        log.msg(log.error, "metadata file not found.")
        return
    end
    local base_tmp = df.chop_filetype(base) .. ".tmp"
    local hdr = df.chop_filetype(base) .. "_hdr." .. df.get_filetype(base)
    dtsys.external_command(exiftool .. " -all= " .. df.sanitize_filename(base) .. " -o " ..
                               df.sanitize_filename(base_tmp))
    dtsys.external_command(exiftool .. " -all= " .. df.sanitize_filename(gainmap) .. " -overwrite_original")
    dtsys.external_command(ultrahdr_app .. " -m 0 -i " .. df.sanitize_filename(base_tmp) .. " -g " ..
                               df.sanitize_filename(gainmap) .. " -f " .. df.sanitize_filename(metadata) .. " -z " ..
                               df.sanitize_filename(hdr))
    dtsys.external_command(exiftool .. " -tagsfromfile " .. df.sanitize_filename(base) .. " -all>all " ..
                               df.sanitize_filename(hdr) .. " -overwrite_original")
    df.file_move(hdr, df.create_unique_filename(output .. "/" .. df.get_filename(hdr)))
    os.remove(base)
    os.remove(base_tmp)
    os.remove(gainmap)
end

local function assert_settings_correct()
    local ultrahdr_app = df.check_if_bin_exists("ultrahdr_app")
    log.msg(log.debug, "ultrahdr_app set to ", ultrahdr_app)
    local exiftool = df.check_if_bin_exists("exiftool")
    log.msg(log.debug, "exiftool set to ", exiftool)
    local output = dt.preferences.read("ultrahdr", "output dir", "string")
    log.msg(log.debug, "output dir set to ", output)

    if not ultrahdr_app then
        dt.print(_("ultrahdr_app is not found, did you set the path?"))
        log.msg(log.error, "ultrahdr_app executable not found.  Check if the executable is installed.")
        log.msg(log.error, "If the executable is installed, check that the path is set correctly.")
        return
    end

    if not exiftool then
        dt.print(_("exiftool is not found, did you set the path?"))
        log.msg(log.error, "exiftool executable not found.  Check if the executable is installed.")
        log.msg(log.error, "If the executable is installed, check that the path is set correctly.")
        return
    end

    return ultrahdr_app, exiftool, output
end

local function create_hdr(storage, image_table, extra_data) -- finalize
    local saved_log_level = log.log_level()
    log.log_level(log.info)

    local ultrahdr_app, exiftool, output = assert_settings_correct()
    if not ultrahdr_app or not exiftool then
        return
    end
    local encoding_variant = get_encoding_variant()
    log.msg(log.info, string.format("using encoding variant %d", encoding_variant))
    if encoding_variant == ENCODING_VARIANT_API_4 then
        local merged = 0
        for ignore, v in pairs(extra_data) do
            if not v then
                goto continue
            end
            local msg = string.format(_("Merging %s and %s"), df.get_filename(image_table[v["base"]]),
                df.get_filename(image_table[v["gainmap"]]))
            log.msg(log.info, msg)
            dt.print(msg)
            merge_ultrahdr_api4(image_table[v["base"]], image_table[v["gainmap"]], ultrahdr_app, exiftool, output)
            merged = merged + 1
            ::continue::
        end
        for ignore, v in pairs(image_table) do
            if df.check_if_file_exists(v) then os.remove(v) end
        end
        dt.print(string.format(_("Created %d UltraHDR image(s) in %s"), merged, output))
    else 
        local msg = string.format(_("Unknown encoding variant: %d"), encoding_variant)
        dt.print_error(msg)
        dt.print(msg)
    end
    log.log_level(saved_log_level)
end

local function destroy()
    dt.destroy_storage(namespace)
end



local function is_supported(storage, format)
    local encoding_variant = get_encoding_variant()
    if encoding_variant == ENCODING_VARIANT_API_4 then
        -- API-4 expects compressed base and gainmap
        -- https://github.com/google/libultrahdr/tree/main?tab=readme-ov-file#encoding-api-outline
        return format.extension == "jpg"
    end
    return false
end

local function initialize(storage, format, images, high_quality, extra_data)
    local saved_log_level = log.log_level()
    log.log_level(log.info)
    local tags = nil
    -- Group images into base, gainmap pairs based on their original filename.
    -- Assume that the first encountered image from each filename is a base one, unless it has a "gainmap" tag.
    for k, v in pairs(images) do
        local has_gainmap_tag = false
        tags = dt.tags.get_tags(v)
        for ignore, tag in pairs(tags) do
            if tag.name == "gainmap" then
                has_gainmap_tag = true
            end
        end
        local key = image_path(v)
        if extra_data[key] == nil then
            extra_data[key] = {}
        end
        if extra_data[key]["base"] or has_gainmap_tag then
            extra_data[key]["gainmap"] = v
        else
            extra_data[key]["base"] = v
        end
    end
    -- remove incomplete entries
    for k, v in pairs(extra_data) do
        if not v["base"] or not v["gainmap"] then
            extra_data[k] = nil
        end
    end
    log.log_level(saved_log_level)
    return nil
end

local function metadata_file_widget()
    local box_widgets = {}
    table.insert(box_widgets, dt.new_widget("label") {
        label = "libultrahdr metadata file"
    })
    local path = dt.preferences.read("ultrahdr", "metadata path", "string")
    if not path then
        path = ""
    end
    table.insert(box_widgets, dt.new_widget("file_chooser_button") {
        title = "select libultrahdr metadata path",
        value = path,
        is_directory = false,
        changed_callback = function(self)
            if df.check_if_file_exists(self.value) then
                dt.preferences.write("ultrahdr", "metadata path", "string", self.value)
            end
        end
    })

    local box = dt.new_widget("box") {
        orientation = "vertical",
        table.unpack(box_widgets)
    }
    return box
end

local function output_directory_widget()
    local box_widgets = {}
    table.insert(box_widgets, dt.new_widget("label") {
        label = "output directory"
    })
    local path = dt.preferences.read("ultrahdr", "output dir", "string")
    if not path then
        path = ""
    end
    table.insert(box_widgets, dt.new_widget("file_chooser_button") {
        title = "select libultrahdr metadata path",
        value = path,
        is_directory = true,
        changed_callback = function(self)
            dt.preferences.write("ultrahdr", "output dir", "string", self.value)
        end
    })

    local box = dt.new_widget("box") {
        orientation = "vertical",
        table.unpack(box_widgets)
    }
    return box
end

local function encoding_variant_widget()
    local metadata_widget = metadata_file_widget()
    local encoding_variant = get_encoding_variant()
    local combobox = dt.new_widget("combobox"){
        label = _("Generate HDR from"),
        selected = encoding_variant,
        changed_callback=function(self)
            dt.preferences.write("ultrahdr", "encoding variant", "integer", self.selected)
            if self.selected == ENCODING_VARIANT_API_4 then
                metadata_widget.visible = true
            else
                metadata_widget.visible = false
            end
        end,
        _("SDR + gainmap (API-4)") -- ENCODING_VARIANT_API_4,
    }

    combobox.changed_callback(combobox)
    return dt.new_widget("box") {
        orientation = "vertical",
        combobox,
        metadata_widget
    }
end

local ultrahdr_widget = dt.new_widget("box") {
    orientation = "vertical",
    output_directory_widget(),
    encoding_variant_widget(),
    df.executable_path_widget({"ultrahdr_app", "exiftool"})
}

-- Register

dt.register_storage(namespace, _("UltraHDR JPEG"), nil, create_hdr, is_supported, initialize, ultrahdr_widget)

script_data.destroy = destroy

return script_data
