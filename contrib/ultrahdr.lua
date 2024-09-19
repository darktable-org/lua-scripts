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

]] --[[

ULTRAHDR
Add a new storage option to generate UltraHDR JPG images.

https://developer.android.com/media/platform/hdr-image-format

Of all exported files, the storage detects pairs of files generated from the same source image, 
assuming the first one encountered is the base SDR image, and the second one is the gainmap
(alternatively, you can tag the gainmaps with a "gainmap" tag).

The images are merged using libultrahdr example application (ultrahdr_app).

ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
* ultrahdr_app (built using https://github.com/google/libultrahdr/blob/main/docs/building.md instructions)
* exiftool
* ffmpeg

USAGE
* require this file from your main luarc config file
* set binary tool paths

]] local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local log = require "lib/dtutils.log"
local dtsys = require "lib/dtutils.system"
local dd = require "lib/dtutils.debug"
local gettext = dt.gettext.gettext

local namespace = "module_ultrahdr"

-- works with darktable API version from 5.0.0 on
du.check_min_api_version("7.0.0", "ultrahdr")

dt.gettext.bindtextdomain(namespace, dt.configuration.config_dir .. "/lua/locale/")

local function _(msgid)
    return gettext(msgid)
end

local job

local GUI = {
    optionwidgets = {
        settings_label = {},
        encoding_variant_combo = {},
        encoding_settings_box = {},
        output_settings_label = {},
        output_settings_box = {},
        use_original_directory = {},
        output_directory_widget = {},
        copy_exif = {},
        import_to_darktable = {},
        metadata_path_label = {},
        metadata_path_widget = {},
        metadata_path_box = {},
        edit_executables_button = {},
        executable_path_widget = {}
    },
    options = {},
    run = {}
}

local flags = {}
flags.event_registered = false -- keep track of whether we've added an event callback or not
flags.module_installed = false -- keep track of whether the module is module_installed

local script_data = {}

script_data.metadata = {
    name = "ultrahdr",
    purpose = _("generate UltraHDR images"),
    author = "Krzysztof Kotowicz"
}

local PS = dt.configuration.running_os == "windows" and "\\" or "/"
local ENCODING_VARIANT_SDR_AND_GAINMAP = 1
local ENCODING_VARIANT_SDR_AND_HDR = 2

local function save_preferences()
    dt.preferences.write(namespace, "encoding_variant", "integer", GUI.optionwidgets.encoding_variant_combo.selected)
    if GUI.optionwidgets.metadata_path_widget.value then
        dt.preferences.write(namespace, "metadata_path", "string", GUI.optionwidgets.metadata_path_widget.value)
    end
    dt.preferences.write(namespace, "use_original_directory", "bool", GUI.optionwidgets.use_original_directory.value)
    dt.preferences.write(namespace, "output_directory", "string", GUI.optionwidgets.output_directory_widget.value)
    dt.preferences.write(namespace, "import_to_darktable", "bool", GUI.optionwidgets.import_to_darktable.value)
    dt.preferences.write(namespace, "copy_exif", "bool", GUI.optionwidgets.copy_exif.value)
end

local function load_preferences()
    GUI.optionwidgets.encoding_variant_combo.selected = dt.preferences.read(namespace, "encoding_variant", "integer") or
                                                            ENCODING_VARIANT_SDR_AND_GAINMAP
    GUI.optionwidgets.metadata_path_widget.value = dt.preferences.read(namespace, "metadata_path", "string")
    GUI.optionwidgets.use_original_directory.value = dt.preferences.read(namespace, "use_original_directory", "bool")
    GUI.optionwidgets.output_directory_widget.value = dt.preferences.read(namespace, "output_directory", "string")
    GUI.optionwidgets.import_to_darktable.value = dt.preferences.read(namespace, "import_to_darktable", "bool")
    GUI.optionwidgets.copy_exif.value = dt.preferences.read(namespace, "copy_exif", "bool")
end

local function get_encoding_variant()
    return GUI.optionwidgets.encoding_variant_combo.selected
end

local function assert_settings_correct(encoding_variant)
    local settings = {
        bin = {
            ultrahdr_app = df.check_if_bin_exists("ultrahdr_app"),
            exiftool = df.check_if_bin_exists("exiftool"),
            ffmpeg = df.check_if_bin_exists("ffmpeg")
        },
        output = GUI.optionwidgets.output_directory_widget.value,
        use_original_dir = GUI.optionwidgets.use_original_directory.value,
        import_to_darktable = GUI.optionwidgets.import_to_darktable.value,
        copy_exif = GUI.optionwidgets.copy_exif.value,        
        metadata = GUI.optionwidgets.metadata_path_widget.value,
        tmpdir = dt.configuration.tmp_dir
    }

    if not settings.use_original_dir and not df.check_if_file_exists(settings.output) then
        dt.print(string.format(_("output directory (%s) not found, did you set the correct path?"), settings.output))
        return
    end

    for k, v in pairs(settings.bin) do
        if not v then
            dt.print(string.format(_("%s is not found, did you set the path?"), k))
            return
        end
    end

    if encoding_variant == ENCODING_VARIANT_SDR_AND_GAINMAP then
        if not df.check_if_file_exists(settings.metadata) then
            dt.print(_("metadata file not found, did you set the correct path?"))
            log.msg(log.error, "metadata file not found.")
            return
        end
    end

    return settings
end

local function get_stacks(images, encoding_variant)
    local stacks = {}
    local extra_image_content_type, extra_image_extension
    if encoding_variant == ENCODING_VARIANT_SDR_AND_GAINMAP then
        extra_image_content_type = "gainmap"
    elseif encoding_variant == ENCODING_VARIANT_SDR_AND_HDR then
        extra_image_extension = "jxl"
        extra_image_content_type = "hdr"
    end

    local tags = nil
    -- Group images into sdr, extra pairs based on their original filename, ignoring the extension
    -- Assume that the first encountered image from each filename is an sdr one, unless it has a tag matching the expected extra_image_type, or has the expected extension
    for k, v in pairs(images) do
        local is_extra = false
        tags = dt.tags.get_tags(v)
        for ignore, tag in pairs(tags) do
            if tag.name == extra_image_content_type then
                is_extra = true
            end
        end
        if extra_image_extension and df.get_filetype(v.filename) == extra_image_extension then
            is_extra = true
        end
        -- we assume every image in the stack is generated from the same source image file
        local key = df.chop_filetype(v.path .. PS .. v.filename)
        if stacks[key] == nil then
            stacks[key] = {}
        end
        if stacks[key]["sdr"] or is_extra then
            stacks[key][extra_image_content_type] = v
        else
            stacks[key]["sdr"] = v
        end
    end
    -- remove invalid stacks
    local count = 0
    for k, v in pairs(stacks) do
        if not v["sdr"] or not v[extra_image_content_type] then
            stacks[k] = nil
        elseif (v["sdr"].final_width ~= v[extra_image_content_type].final_width) or
            (v["sdr"].final_height ~= v[extra_image_content_type].final_height) then
            stacks[k] = nil
        elseif extra_image_extension and df.get_filetype(v[extra_image_content_type].filename) ~= extra_image_extension then
            stacks[k] = nil
        else
            count = count + 1
        end
    end
    return stacks, count
end

local function stop_job(job)
    job.valid = false
end

local function execute_cmd(cmd)
    log.msg(log.debug, cmd)
    return dtsys.external_command(cmd)
end

local function generate_ultrahdr(encoding_variant, images, settings, step, total_steps)
    local total_substeps
    local substep = 0
    local uhdr

    function update_job_progress()
        substep = substep + 1
        if substep > total_substeps then
            log.msg(log.debug,
                string.format("total_substeps count is too low for encoding_variant %d", encoding_variant))
        end
        job.percent = (total_substeps * step + substep) / (total_steps * total_substeps)
    end

    if encoding_variant == ENCODING_VARIANT_SDR_AND_GAINMAP then
        total_substeps = 6
        -- Export both SDR and gainmap to JPEGs
        local exporter = dt.new_format("jpeg")
        exporter.quality = 95
        local sdr = df.create_unique_filename(settings.tmpdir .. PS .. df.chop_filetype(images["sdr"].filename) ..
                                                  ".jpg")
        exporter:write_image(images["sdr"], sdr)
        local gainmap = df.create_unique_filename(settings.tmpdir .. PS .. images["gainmap"].filename .. "_gainmap.jpg")
        exporter:write_image(images["gainmap"], gainmap)

        log.msg(log.debug, string.format(_("Exported files: %s, %s"), sdr, gainmap))
        update_job_progress()
        -- Strip EXIFs
        execute_cmd(settings.bin.exiftool .. " -all= " .. df.sanitize_filename(sdr) .. " -o " ..
                        df.sanitize_filename(sdr .. ".noexif"))
        execute_cmd(settings.bin.exiftool .. " -all= " .. df.sanitize_filename(gainmap) .. " -overwrite_original")
        update_job_progress()
        -- Merge files
        uhdr = df.chop_filetype(sdr) .. "_ultrahdr.jpg"

        execute_cmd(settings.bin.ultrahdr_app .. " -m 0 -M 0 -i " .. df.sanitize_filename(sdr .. ".noexif") .. " -g " ..
                        df.sanitize_filename(gainmap) .. " -f " .. df.sanitize_filename(settings.metadata) .. " -z " ..
                        df.sanitize_filename(uhdr))
        update_job_progress()
        -- Copy SDR's EXIF to UltraHDR file
        if settings.copy_exif then
            execute_cmd(settings.bin.exiftool .. " -tagsfromfile " .. df.sanitize_filename(sdr) .. " -all>all " ..
                            df.sanitize_filename(uhdr) .. " -overwrite_original -preserve")
        end
        update_job_progress()
        -- Cleanup 
        os.remove(sdr)
        os.remove(sdr .. ".noexif")
        os.remove(gainmap)
        update_job_progress()
    elseif encoding_variant == ENCODING_VARIANT_SDR_AND_HDR then
        total_substeps = 5
        -- https://discuss.pixls.us/t/manual-creation-of-ultrahdr-images/45004/20
        -- Step 1: Export SDR to PNG (HDR is already a JPEG-XL)
        local exporter = dt.new_format("png")
        exporter.bpp = 8
        local sdr = df.create_unique_filename(settings.tmpdir .. PS .. df.chop_filetype(images["sdr"].filename) ..
                                                  ".png")
        exporter:write_image(images["sdr"], sdr)
        uhdr = df.chop_filetype(sdr) .. "_ultrahdr.jpg"

        update_job_progress()
        local extra = df.create_unique_filename(settings.tmpdir .. PS .. images["hdr"].filename .. ".raw")

        -- Step 3: Generate libultrahdr RAW images 
        execute_cmd(settings.bin.ffmpeg .. " -i " .. df.sanitize_filename(sdr) .. " -pix_fmt rgba -f rawvideo " ..
                        df.sanitize_filename(sdr .. ".raw"))
        execute_cmd(settings.bin.ffmpeg .. " -i " ..
                        df.sanitize_filename(images["hdr"].path .. PS .. images["hdr"].filename) ..
                        " -pix_fmt p010le -f rawvideo " .. df.sanitize_filename(extra))
        update_job_progress()
        execute_cmd(settings.bin.ultrahdr_app .. " -m 0 -y " .. df.sanitize_filename(sdr .. ".raw") .. " -p " ..
                        df.sanitize_filename(extra) .. " -a 0 -b 3 -c 1 -C 1 -t 2 -M 1 -s 1 -q 95 -Q 95 -D 1 " ..
                        " -w " .. tostring(images["sdr"].final_width) .. " -h " .. tostring(images["sdr"].final_height) ..
                        " -z " .. df.sanitize_filename(uhdr))
        update_job_progress()
        if settings.copy_exif then
            execute_cmd(settings.bin.exiftool .. " -tagsfromfile " .. df.sanitize_filename(sdr) .. " -all>all " ..
                            df.sanitize_filename(uhdr) .. " -overwrite_original -preserve")
        end
        -- Cleanup
        os.remove(sdr)
        os.remove(sdr .. ".raw")
        os.remove(extra)
        update_job_progress()
    end

    local output_dir = settings.use_original_dir and images["sdr"].path or settings.output
    local output_file = df.create_unique_filename(output_dir .. PS .. df.get_filename(uhdr))
    df.file_move(uhdr, output_file)
    if settings.import_to_darktable then
        local img = dt.database.import(output_file)
        -- Add "ultrahdr" tag to the imported image
        local tagnr = dt.tags.find("ultrahdr")
        if tagnr == nil then
            dt.tags.create("ultrahdr")
            tagnr = dt.tags.find("ultrahdr")
        end
        dt.tags.attach(tagnr, img)
    end

    local msg = string.format(_("Generated %s."), df.get_filename(output_file))
    log.msg(log.info, msg)
    dt.print(msg)    
    update_job_progress()
end

local function main()
    local saved_log_level = log.log_level()
    log.log_level(log.info)

    save_preferences()

    local encoding_variant = get_encoding_variant()
    log.msg(log.info, string.format("using encoding variant %d", encoding_variant))

    local settings = assert_settings_correct(encoding_variant)
    if not settings then
        dt.print(_("Export settings are incorrect, exiting..."))
        log.log_level(saved_log_level)
        return
    end

    local images = dt.gui.selection() -- get selected images
    if #images < 2 then
        dt.print(_("Select at least 2 images to generate UltraHDR image"))
        log.log_level(saved_log_level)
        return
    end

    local stacks, stack_count = get_stacks(images, encoding_variant)
    dt.print(string.format(_("Detected %d image stack(s)"), stack_count))
    if stack_count == 0 then
        log.log_level(saved_log_level)
        return
    end
    job = dt.gui.create_job(_("Generating UltraHDR images"), true, stop_job)
    local count = 0
    for i, v in pairs(stacks) do
        generate_ultrahdr(encoding_variant, v, settings, count, stack_count)
        count = count + 1
        -- sleep for a short moment to give stop_job callback function a chance to run
        dt.control.sleep(10)
    end
    -- stop job and remove progress_bar from ui, but only if not alreay canceled
    if (job.valid) then
        job.valid = false
    end

    local msg = string.format(_("Generated %d UltraHDR image(s)."), count)
    log.msg(log.info, msg)
    dt.print(msg)
    log.log_level(saved_log_level)
end

GUI.optionwidgets.settings_label = dt.new_widget("section_label") {
    label = _("UltraHDR settings")
}

GUI.optionwidgets.output_settings_label = dt.new_widget("section_label") {
    label = _("Output")
}

GUI.optionwidgets.output_directory_widget = dt.new_widget("file_chooser_button") {
    title = _("Select directory to write UltraHDR image files to"),
    is_directory = true
}

GUI.optionwidgets.use_original_directory = dt.new_widget("check_button") {
    label = _("Export to original directory"),
    tooltip = _("Write UltraHDR images to the same directory as their original images"),
    clicked_callback = function(self)
        GUI.optionwidgets.output_directory_widget.sensitive = not self.value
    end
}

GUI.optionwidgets.import_to_darktable = dt.new_widget("check_button") {
    label = _("Import UltraHDRs to Darktable"),
    tooltip = _("Import UltraHDR images to Darktable library after generating, with an 'ultrahdr' tag attached.")
}

GUI.optionwidgets.copy_exif = dt.new_widget("check_button") {
    label = _("Copy EXIF data from SDR file(s)"),
    tooltip = _("Copy EXIF data into UltraHDR file(s) from their SDR sources.")
}

GUI.optionwidgets.output_settings_box = dt.new_widget("box") {
    orientation = "vertical",
    GUI.optionwidgets.output_settings_label,
    GUI.optionwidgets.use_original_directory,
    GUI.optionwidgets.output_directory_widget,
    GUI.optionwidgets.import_to_darktable,
    GUI.optionwidgets.copy_exif
}

GUI.optionwidgets.metadata_path_label = dt.new_widget("label") {
    label = _("ultrahdr_app metadata.cfg file")
}

GUI.optionwidgets.metadata_path_widget = dt.new_widget("file_chooser_button") {
    title = "select libultrahdr metadata path",
    is_directory = false
}

GUI.optionwidgets.metadata_path_box = dt.new_widget("box") {
    orientation = "vertical",
    GUI.optionwidgets.metadata_path_label,
    GUI.optionwidgets.metadata_path_widget
}

GUI.optionwidgets.encoding_variant_combo = dt.new_widget("combobox") {
    label = _("Source images"),
    tooltip = string.format(_([[Select types of images in the selection.

%s: SDR image paired with a monochromatic gain map image
%s: SDR image paired with a JPEG-XL HDR image (10-bit, 'PQ P3 RGB' profile recommended)

UltraHDR image will be created for each pair of images that:
 - have the same underlying image path + filename (ignoring file extension)
 - have the same dimensions

 It is assumed that the first image in a pair is the SDR , unless it has a "hdr" / "gainmap" tag.
]]), _("SDR + monochrome gainmap"), _("SDR + JPEG-XL HDR")),
    selected = 0,
    changed_callback = function(self)
        if self.selected == ENCODING_VARIANT_SDR_AND_GAINMAP then
            GUI.optionwidgets.metadata_path_box.visible = true
        else
            GUI.optionwidgets.metadata_path_box.visible = false
        end
    end,
    _("SDR + monochrome gainmap"), -- ENCODING_VARIANT_SDR_AND_GAINMAP,
    _("SDR + JPEG-XL HDR") -- ENCODING_VARIANT_SDR_AND_HDR,
}

GUI.optionwidgets.encoding_settings_box = dt.new_widget("box") {
    orientation = "vertical",
    GUI.optionwidgets.encoding_variant_combo,
    GUI.optionwidgets.metadata_path_box
}

GUI.optionwidgets.executable_path_widget = df.executable_path_widget({"ultrahdr_app", "exiftool", "ffmpeg"})
GUI.optionwidgets.executable_path_widget.visible = false

GUI.optionwidgets.edit_executables_button = dt.new_widget("button") {
    label = _("Show / hide executables"),
    tooltip = _("Show / hide settings for executable files required for the plugin functionality"),
    clicked_callback = function()
        GUI.optionwidgets.executable_path_widget.visible = not GUI.optionwidgets.executable_path_widget.visible
    end
}

GUI.options = dt.new_widget("box") {
    orientation = "vertical",
    GUI.optionwidgets.settings_label,
    GUI.optionwidgets.encoding_settings_box,
    GUI.optionwidgets.edit_executables_button,
    GUI.optionwidgets.executable_path_widget,
    GUI.optionwidgets.output_settings_box
}

GUI.run = dt.new_widget("button") {
    label = _("Generate UltraHDR"),
    tooltip = _([[Generate UltraHDR image(s) from selection

Global options in the export module apply to the SDR image. Make sure that a proper color 'profile' setting is used (e.g. Display P3)
]]),
    clicked_callback = main
}

load_preferences()

local function install_module()
    if flags.module_installed then
        return
    end
    dt.register_lib( -- register module
    namespace, -- Module name
    _("UltraHDR"), -- name
    true, -- expandable
    true, -- resetable
    {
        [dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 99}
    }, -- containers
    dt.new_widget("box") {
        orientation = "vertical",
        GUI.options,
        GUI.run
    }, nil, -- view_enter
    nil -- view_leave
    )
end

local function destroy()
    dt.gui.libs[namespace].visible = false
end

local function restart()
    dt.gui.libs[namespace].visible = true
end

if dt.gui.current_view().id == "lighttable" then -- make sure we are in lighttable view
    install_module() -- register the lib
else
    if not flags.event_registered then -- if we are not in lighttable view then register an event to signal when we might be
        -- https://www.darktable.org/lua-api/index.html#darktable_register_event
        dt.register_event(namespace, "view-changed", -- we want to be informed when the view changes
        function(event, old_view, new_view)
            if new_view.name == "lighttable" and old_view.name == "darkroom" then -- if the view changes from darkroom to lighttable
                install_module() -- register the lib
            end
        end)
        flags.event_registered = true --  keep track of whether we have an event handler installed
    end
end

script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = restart

return script_data
