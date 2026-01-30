--[[
    rawforge_refinery.lua - AI based modification of ext_editor to 
                            process RAW files with rawforge Python tool


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
    This script provides batch processing of RAW files using the rawforge Python tool.
    It adds a new module "Rawforge Refinery", visible in lighttable and darkroom, to:
      - configure rawforge Python script path and processing parameters
      - batch process selected RAW images (CR2, CR3, NEF, ARW, DNG)
      - automatically import processed DNG files back into collection
      - preserve metadata (tags, ratings, color labels) on processed images
      - group processed images with their originals
    
    USAGE
      * require this script from main lua file
    
      -- setup --
      
      install https://github.com/rymuelle/RawForge via pip nstall rawforge
        * in "preferences/lua options" configure:
          - Python Script Path: full command to run rawforge.py
            (e.g., "python3 /home/user/rawforge.py" or just "rawforge.py" if in PATH)
          - Model Name: the rawforge model to use (required)
          - Device: processing backend (cuda/cpu/mps)
          - Output Suffix: text added to output filename (default: "_denoised")
          - Extra Parameters: additional rawforge options (e.g., "--cfa --tile_size 512")
        * or configure these directly in the "Rawforge Refinery" module panel
        * preferences are saved automatically when processing images
        * in "preferences/shortcuts/lua" configure shortcut for quick processing (optional)
      
      -- use --
        * in lighttable, select one or more RAW images for processing
        * in the "Rawforge Refinery" panel:
          - verify/adjust your settings (path, model, device, suffix, extra parameters)
          - press "Process Selected Images"
        * processing progress is shown in darktable status bar
        * processed DNG files are automatically imported and grouped with originals
        * files are skipped if output DNG already exists
    
    RAWFORGE PARAMETERS
      * model: name of the model to use (required)
      * device: cuda, cpu, or mps (optional, leave empty for default)
      * suffix: output filename suffix (default: "_denoised")
      * extra parameters examples:
        --cfa                    : save as CFA image
        --tile_size 512          : set tile size (default: 256)
        --disable_tqdm           : disable progress bar
        --conditioning "array"   : conditioning array for model
        --dims x0 x1 y0 y1       : crop dimensions
    
    EXAMPLE COMMAND
      python3 rawforge.py mymodel input.CR2 output.dng --device cuda --tile_size 512
    
    CAVEATS
      * requires rawforge Python tool installed and accessible
      * processing is sequential (one image at a time)
      * large tile sizes may require more GPU/system memory
]]


local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local dtsys = require "lib/dtutils.system"

-- Configuration
local MODULE_NAME = "rawforge_refinery"
local ALLOWED_EXTS = {cr2=true, cr3=true, nef=true, arw=true, dng=true}
local DEFAULT_SUFFIX = "_denoised"
local DEFAULT_MODEL = "model_name"
local DEFAULT_DEVICE = "cuda"

du.check_min_api_version("7.0.0", MODULE_NAME)
local _ = dt.gettext.gettext

-- OS-specific separator
local PS = dt.configuration.running_os == "windows" and "\\" or "/"

-- Helper: Get file extension
local function get_ext(filename)
    if not filename then return "" end
    local ext = filename:match("^.+(%..+)$")
    return ext and ext:sub(2):lower() or ""
end

-- Helper: Escape command line arguments
local function escape_arg(arg)
    if dt.configuration.running_os == "windows" then
        return '"' .. arg:gsub('"', '""') .. '"'
    else
        return "'" .. arg:gsub("'", "'\\''") .. "'"
    end
end

-- Process a single image
local function process_image(image, python_path, model, device, suffix, extra_params)
    local raw_path = image.path .. PS .. image.filename
    local base_name = image.filename:match("(.+)%..+$") or image.filename
    local dng_filename = base_name .. suffix .. ".dng"
    local dng_path = image.path .. PS .. dng_filename

    if df.check_if_file_exists(dng_path) then
        dt.print(string.format(_("Skipping %s: DNG already exists"), image.filename))
        return nil
    end

    local tags = dt.tags.get_tags(image)
    local rating = image.rating
    local labels = {
        red = image.red, blue = image.blue, green = image.green,
        yellow = image.yellow, purple = image.purple
    }

    -- Build rawforge command
    -- python rawforge.py model in_file out_file --device cuda [extra_params]
    local cmd_parts = {
        escape_arg(python_path),
        escape_arg(model),
        escape_arg(raw_path),
        escape_arg(dng_path)
    }
    
    if device and device ~= "" then
        table.insert(cmd_parts, "--device")
        table.insert(cmd_parts, escape_arg(device))
    end
    
    -- Add extra parameters if provided
    if extra_params and extra_params ~= "" then
        table.insert(cmd_parts, extra_params)
    end
    
    local run_cmd = table.concat(cmd_parts, " ")
    
    dt.print(string.format(_("Executing: %s"), run_cmd))
    local result = dtsys.external_command(run_cmd)

    if result ~= 0 or not df.check_if_file_exists(dng_path) then
        dt.print(string.format(_("Error processing %s (exit code: %d)"), image.filename, result))
        return nil
    end

    local dng_image = dt.database.import(dng_path)
    if dng_image then
        dng_image:group_with(image.group_leader)
        for _, tag in ipairs(tags) do
            if not tag.name:find("darktable") then dt.tags.attach(tag, dng_image) end
        end
        dng_image.rating = rating
        for color, val in pairs(labels) do dng_image[color] = val end
        return dng_image
    end
    return nil
end

-- Main Conversion Handler
local function run_conversion(images, python_path, model, device, suffix, extra_params)
    if not python_path or python_path == "" then
        dt.print(_("Please enter the path to rawforge Python script"))
        return
    end
    
    if not model or model == "" then
        dt.print(_("Please enter the model name"))
        return
    end

    local queue = {}
    for _, img in ipairs(images) do
        if ALLOWED_EXTS[get_ext(img.filename)] then
            table.insert(queue, img)
        end
    end

    if #queue == 0 then
        dt.print(_("No supported RAW files selected"))
        return
    end

    local job = nil
    if dt.gui.create_job then
        job = dt.gui.create_job(string.format(_("Processing %d images with rawforge"), #queue), true)
    end
    
    for i, img in ipairs(queue) do
        if job and job.valid == false then break end 
        if job then job.percent = (i - 1) / #queue end
        
        dt.print(string.format(_("Processing %d/%d: %s"), i, #queue, img.filename))
        process_image(img, python_path, model, device, suffix, extra_params)
    end

    if job then job.valid = false end
    dt.print(_("Rawforge processing finished"))
end

-- UI Setup
local function install_module()
    -- Python script path
    local path_entry = dt.new_widget("entry"){
        text = dt.preferences.read(MODULE_NAME, "python_path", "string"),
        tooltip = _("Full path to rawforge.py (e.g., python /path/to/rawforge.py or just rawforge.py if in PATH)"),
    }

    -- Model name
    local model_entry = dt.new_widget("entry"){
        text = dt.preferences.read(MODULE_NAME, "model_name", "string"),
        tooltip = _("Model name to use with rawforge"),
    }

    -- Device selection
    local device_entry = dt.new_widget("entry"){
        text = dt.preferences.read(MODULE_NAME, "device", "string"),
        tooltip = _("Device backend: cuda, cpu, or mps (leave empty for default)"),
    }

    -- Output suffix
    local suffix_entry = dt.new_widget("entry"){
        text = dt.preferences.read(MODULE_NAME, "output_suffix", "string"),
        tooltip = _("Suffix to add to output filename (e.g., _denoised)"),
    }

    -- Extra parameters
    local extra_params_entry = dt.new_widget("entry"){
        text = dt.preferences.read(MODULE_NAME, "extra_params", "string"),
        tooltip = _("Additional rawforge parameters (e.g., --cfa --tile_size 512 --disable_tqdm)"),
    }

    -- Run button
    local btn_run = dt.new_widget("button") {
        label = _("Process Selected Images"),
        clicked_callback = function()
            -- Save preferences
            if path_entry.text ~= "" then
                dt.preferences.write(MODULE_NAME, "python_path", "string", path_entry.text)
            end
            if model_entry.text ~= "" then
                dt.preferences.write(MODULE_NAME, "model_name", "string", model_entry.text)
            end
            if device_entry.text ~= "" then
                dt.preferences.write(MODULE_NAME, "device", "string", device_entry.text)
            end
            if suffix_entry.text ~= "" then
                dt.preferences.write(MODULE_NAME, "output_suffix", "string", suffix_entry.text)
            end
            if extra_params_entry.text ~= "" then
                dt.preferences.write(MODULE_NAME, "extra_params", "string", extra_params_entry.text)
            end
            
            run_conversion(
                dt.gui.selection(),
                path_entry.text,
                model_entry.text,
                device_entry.text,
                suffix_entry.text,
                extra_params_entry.text
            )
        end
    }

    dt.register_lib(
        MODULE_NAME, _("Rawforge Refinery"), true, false,
        {
            [dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100},
            [dt.gui.views.darkroom] = {"DT_UI_CONTAINER_PANEL_LEFT_CENTER", 100}
        },
        dt.new_widget("box") {
            orientation = "vertical",
            dt.new_widget("label"){ label = _("Python Script Path:") },
            path_entry,
            dt.new_widget("label"){ label = _("Model Name:") },
            model_entry,
            dt.new_widget("label"){ label = _("Device (cuda/cpu/mps):") },
            device_entry,
            dt.new_widget("label"){ label = _("Output Suffix:") },
            suffix_entry,
            dt.new_widget("label"){ label = _("Extra Parameters:") },
            extra_params_entry,
            btn_run
        }
    )
end

-- Initialization
dt.preferences.register(MODULE_NAME, "python_path", "string", _("Rawforge Python Path"), "", "python rawforge.py")
dt.preferences.register(MODULE_NAME, "model_name", "string", _("Model Name"), "", DEFAULT_MODEL)
dt.preferences.register(MODULE_NAME, "device", "string", _("Device"), "", DEFAULT_DEVICE)
dt.preferences.register(MODULE_NAME, "output_suffix", "string", _("Output Suffix"), "", DEFAULT_SUFFIX)
dt.preferences.register(MODULE_NAME, "extra_params", "string", _("Extra Parameters"), "", "")

dt.register_event(MODULE_NAME, "shortcut", function() 
    local p = dt.preferences.read(MODULE_NAME, "python_path", "string")
    local m = dt.preferences.read(MODULE_NAME, "model_name", "string")
    local d = dt.preferences.read(MODULE_NAME, "device", "string")
    local s = dt.preferences.read(MODULE_NAME, "output_suffix", "string")
    local e = dt.preferences.read(MODULE_NAME, "extra_params", "string")
    run_conversion(dt.gui.action_images, p, m, d, s, e) 
end, _("Run Rawforge Refinery"))

install_module()
