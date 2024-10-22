--[[Enfuse Advanced plugin for darktable 2.2.X and 2.4.X

  copyright (c) 2017, 2018  Holger Klemm (Original Linux-only version)
  Modified by: Kevin Ertel
  
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

--[[About this plugin
This plugin will add the new export module 'fusion to DRI or DFF image'.
   
----REQUIRED SOFTWARE----
align_image_stack
enfuse ver. 4.2 or greater
exiftool

----USAGE----
Install:
 1) Get the Lua scripts: https://github.com/darktable-org/lua-scripts#download-and-install
 2) Require this file in your luarc file, as with any other dt plug-in: require "contrib/enfuseAdvanced"
 3) Then select "DRI or DFF image" as storage option
 4) On the initial startup set your executable paths 

DRI = Dynamic Range Increase (Blend multiple bracket images into a single LDR file)
DFF = Depth From Focus ('Focus Stacking' - Blend multiple images with different focus into a single image)
Select multiple images that are either bracketed, or focus-shifted, set your desired operating parameters, and press the export button. A new image will be created. The image will
be auto imported into darktable if you have that option enabled. Additional tags or style can be applied on auto import as well, if you desire.

image align options:
See align_image_stack documentation for further explanation of how it specifically works and the options provided (http://hugin.sourceforge.net/docs/manual/Align_image_stack.html)

image fustion options:
See enfuse documentation for further explanation of how it specifically works and the options provided (https://wiki.panotools.org/Enfuse)
If you have a specific set of parameters you frequently like to use, you can save them to a preset. There are 3 presets available for DRI, and 3 for DFF.

target file:
Select your file destination path, or check the 'save to source image location' option.
'Create Unique Filename' is enabled by default at startup, the user can choose to overwrite existing
Set any tags or style you desire to be added to the new image (only available if the auto-import option is enabled). You can also change the defaults for this under settings > lua options

format options:
Same as other export modules

global options:
Same as other export modules

]]

local dt = require 'darktable'
local df = require 'lib/dtutils.file'
local dsys = require 'lib/dtutils.system'
local du = require 'lib/dtutils'
local mod = 'module_enfuseAdvanced'
local os_path_seperator = '/'
if dt.configuration.running_os == 'windows' then os_path_seperator = '\\' end

du.check_min_api_version("7.0.0", "enfuseAdvanced") 

-- Tell gettext where to find the .mo file translating messages for a particular domain
local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("enfuse advanced"),
  purpose = _("focus stack or exposure blend images"),
  author = "Kevin Ertel",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/enfuseAdvanced"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

-- INITS --
local AIS = {
    name = 'align_image_stack',
    bin = '',
    first_run = true,
    install_error = false,
    arg_string = '',
    images_string = '',
    args = {
        radial_distortion       = {text = '-d',             style = 'bool'},
        optimize_field          = {text = '-m',             style = 'bool'},
        optimize_image_center   = {text = '-i',             style = 'bool'},
        auto_crop               = {text = '-C',             style = 'bool'},
        distortion              = {text = '--distortion',   style = 'bool'},
        gpu                     = {text = '--gpu',          style = 'bool'},
        grid_size               = {text = '-g ',            style = 'integer'},
        control_points          = {text = '-c ',            style = 'integer'},
        control_points_remove   = {text = '-t ',            style = 'integer'},
        correlation             = {text = '--corr=',        style = 'float'}
    }
}
local ENF = {
    name = 'enfuse',
    bin = '',
    first_run = true,
    install_error = false,
    arg_string = '',
    image_string = '',
    args = {
        exposure_weight         = {text = '--exposure-weight=',         style = 'float'},
        saturation_weight       = {text = '--saturation-weight=',       style = 'float'},
        contrast_weight         = {text = '--contrast-weight=',         style = 'float'},
        exposure_optimum        = {text = '--exposure-optimum=',        style = 'float'},
        exposure_width          = {text = '--exposure-width=',          style = 'float'},
        hard_masks              = {text = '--hard-mask',                style = 'bool'},
        save_masks              = {text = '--save-masks',               style = 'bool'},
        contrast_window_size    = {text = '--contrast-window-size=',    style = 'integer'},
        contrast_edge_scale     = {text = '--contrast-edge-scale=',     style = 'float'},
        contrast_min_curvature  = {text = '--contrast-min-curvature=', style = 'string'}
    }
}
local EXF = {
    name = 'exiftool',
    bin = '',
    first_run = true,
    install_error = false
}
local GUI = {
    AIS = {
        radial_distortion       = {},
        optimize_field          = {},
        optimize_image_center   = {},
        auto_crop               = {},
        distortion              = {},
        grid_size               = {},
        control_points          = {},
        control_points_remove   = {},
        correlation             = {}},
    ENF = {
        exposure_weight         = {},
        saturation_weight       = {},
        contrast_weight         = {},
        exposure_optimum        = {},
        exposure_width          = {},
        hard_masks              = {},
        save_masks              = {},
        contrast_window_size    = {},
        contrast_edge_scale     = {},
        contrast_min_curvature  = {}},
    Target = {
        format                  = {},
        depth                   = {},   
        compression_level_tif   = {},
        compression_level_jpg   = {},
        output_compress         = {},
        output_directory        = {},
        source_location         = {},
        on_conflict             = {},
        auto_import             = {},
        apply_style             = {},
        copy_tags               = {},
        add_tags                = {}},
    Presets = {
        current_preset      ={};
        load                ={};
        save                ={};
        variants            ={};
        variants_type       ={}},
    exes = {
        align_image_stack = {},
        enfuse = {},
        exiftool = {},
        update = {}
    },
    align                   = {},
    options_contain         = {},
    show_options            = {}
}

local styles = dt.styles
local styles_count = 1 -- 'none' = 1
for _,i in pairs(dt.styles) do
    if type(i) == 'userdata' then styles_count = styles_count + 1 end
end

-- FUNCTION --

local function sanitize_decimals(cmd) -- make sure decimal separator is a '.'
    return string.gsub(cmd, '(%d),(%d)', "%1.%2")
end

local function InRange(test, low, high) -- tests if test value is within range of low and high (inclusive)
    if test >= low and test <= high then
        return true
    else
        return false
    end
end

local function GetFileName(full_path) -- Parses a full path (path/filename_identifier.extension) into individual parts
--[[Input: Folder1/Folder2/Folder3/Img_0001.CR2
    
    Returns:
    path: Folder1/Folder2/Folder3/
    filename: Img_0001
    identifier: 0001
    extension: .CR2
    
    EX:
    path_1, file_1, id_1, ext_1 = GetFileName(full_path_1)
    ]]
    local path = string.match(full_path, '.*[\\/]')
    local filename = string.gsub(string.match(full_path, '[%w-_]*%.') , '%.' , '' ) 
    local identifier = string.match(filename, '%d*$')
    local extension = string.match(full_path, '%.%w*')
    return path, filename, identifier, extension
end

local function CleanSpaces(text) --removes spaces from the front and back of passed in text
    text = string.gsub(text,'^%s*','')
    text = string.gsub(text,'%s*$','')
    return text
end

local function BuildExecuteCmd(prog_table) --creates a program command using elements of the passed in program table
    local result = CleanSpaces(prog_table.bin)..' '..CleanSpaces(prog_table.arg_string)..' '..CleanSpaces(prog_table.images_string)
    return result
end

local function PreCall(prog_tbls) --looks to see if this is the first call, if so checks to see if program is installed properly
    for _,prog in pairs(prog_tbls) do
        if prog.first_run then
            prog.bin = df.check_if_bin_exists(prog.name)
            if not prog.bin then 
                prog.install_error = true
                dt.preferences.write(mod, 'bin_exists', 'bool', false)
            else
                prog.bin = CleanSpaces(prog.bin)
            end
            prog.first_run = false
        end
    end
    if not dt.preferences.read(mod, 'bin_exists', 'bool') then
        GUI.options_contain.active = 4
        GUI.show_options.sensitive = false
        dt.print(_('please update your binary locations'))
    end
end

local function ExeUpdate(prog_tbl) --updates executable paths and verifies them
    dt.preferences.write(mod, 'bin_exists', 'bool', true)
    for x,prog in pairs(prog_tbl) do
        dt.preferences.write('executable_paths', prog.name, 'string', GUI.exes[prog.name].value)
        prog.bin = df.check_if_bin_exists(prog.name)
        if not prog.bin then 
            prog.install_error = true
            dt.preferences.write(mod, 'bin_exists', 'bool', false)
            dt.print(string.format(_("issue with %s executable"), prog.name))
        else
            prog.bin = CleanSpaces(prog.bin)
        end
        prog.first_run = false
    end
    if dt.preferences.read(mod, 'bin_exists', 'bool') then
        GUI.options_contain.active = 2
        GUI.show_options.sensitive = true
        dt.print(_('update successful'))
    else
        dt.print(_('update unsuccessful, please try again'))
    end
end

local function GetArgsFromPreference(prog_table, prefix) --for each arg in a program table reads in the associated value in the active preference (which is continually updated via clicked/changed callback in GUI elements
    prog_table.arg_string = ''
    for argument, arg_data in pairs(prog_table.args) do
        local temp = dt.preferences.read(mod, prefix..argument, arg_data.style)
        if arg_data.style == 'bool' and temp then
            prog_table.arg_string = prog_table.arg_string..arg_data.text..' '
        elseif arg_data.style == 'integer' or arg_data.style == 'string' then
            prog_table.arg_string = prog_table.arg_string..arg_data.text..temp..' '
        elseif arg_data.style == 'float' then
            temp = string.sub(tostring(temp),1,3)
            prog_table.arg_string = prog_table.arg_string..arg_data.text..temp..' '
        end
    end
    prog_table.arg_string = CleanSpaces(prog_table.arg_string)
    return prog_table.arg_string
end

local function UpdateAISargs(image_table, images_to_remove) --updates the AIS arguments, builds the input image string, returns a modified image table which contains the aligned image names in place of the exported image names also updates the images to remove string with new aligned images and a string of the images to align
    GetArgsFromPreference(AIS, 'active_')
    local source_path = ''
    local images_to_align = ''
    local index = 0
    for raw, temp_image in pairs(image_table) do
        local index_str = ''
        source_path = GetFileName(temp_image)
        images_to_align = images_to_align..df.sanitize_filename(temp_image)..' '
        if InRange(index,0,9) then index_str = '000'..tostring(index)
        elseif InRange(index,10,99) then index_str = '00'..tostring(index)
        end
        image_table[raw] = source_path..'aligned_'..index_str..'.tif'
        images_to_remove = images_to_remove..df.sanitize_filename(image_table[raw])..' '
        index = index + 1
    end
    source_path = df.sanitize_filename(source_path..'aligned_')
    AIS.arg_string = AIS.arg_string..' -a '..source_path
    images_to_align = CleanSpaces(images_to_align)
    
    return image_table, images_to_remove, images_to_align
end

local function UpdateENFargs(image_table, prefix) --updates the Enfuse arguments, builds the input image string, generates output filename, returns string of images to blend, the name of the outout image, and the first raw image object
    GetArgsFromPreference(ENF, prefix)
    local images_to_blend = ''
    local out_path = ''
    local out_name = ''
    local smallest_name = ''
    local smallest_id = math.huge
    local largest_id = 0
    local first_raw = {}
    for raw, temp_image in pairs(image_table) do
        local _, source_name, source_id = GetFileName(raw.filename)
        source_id = tonumber(source_id)
        if source_id < smallest_id then 
            smallest_id = source_id
            smallest_name = source_name
            first_raw = raw
        end
        if source_id > largest_id then largest_id = source_id end
        out_path = raw.path
        images_to_blend = images_to_blend..df.sanitize_filename(temp_image)..' '
    end
    ENF.arg_string = ENF.arg_string..' --depth='..GUI.Target.depth.value..' '
    if GUI.Target.format.value == 'tif' then ENF.arg_string = ENF.arg_string..'--compression='..GUI.Target.compression_level_tif.value..' '
    elseif GUI.Target.format.value == 'jpg' then ENF.arg_string = ENF.arg_string..'--compression='..GUI.Target.compression_level_jpg.value..' '
    end
    if not GUI.Target.source_location.value then out_path = GUI.Target.output_directory.value end
    out_name = smallest_name..'-'..largest_id
    out_path = out_path..os_path_seperator..out_name..'.'..GUI.Target.format.value
    if GUI.Target.on_conflict.value == 'create unique filename' then out_path = df.create_unique_filename(out_path) end
    ENF.arg_string = ENF.arg_string..'--output='..df.sanitize_filename(out_path)
    images_to_blend = CleanSpaces(images_to_blend)
    
    return images_to_blend, out_path, first_raw
end

local function UpdateActivePreference() --sliders & entry boxes do not have a click/changed callback, so their values must be saved to the active preference 'manually'
    local enf = {'exposure_weight','saturation_weight','contrast_weight','exposure_optimum','exposure_width'}
    for _,descriptor in pairs(enf) do
        temp = GUI.ENF[descriptor].value
        dt.preferences.write(mod, 'active_'..descriptor, 'float', temp)
    end
    temp = GUI.Target.compression_level_jpg.value
    temp = math.floor(temp)
    dt.preferences.write(mod, 'active_compression_level_jpg', 'integer', temp)
    temp = GUI.Target.add_tags.text
    dt.preferences.write(mod, 'active_add_tags', 'string', temp)
end

local function SaveToPreference(preset) --save the present values of enfuse GUI elements to the specified 'preset'
    UpdateActivePreference()
    for argument, arg_data in pairs(ENF.args) do
        local temp
        if argument == 'contrast_window_size' or argument == 'contrast_edge_scale' or argument == 'contrast_min_curvature' then --comboboxes must be handled specially via an index value
            temp = dt.preferences.read(mod, 'active_'..argument..'_ind', 'integer')
            dt.preferences.write(mod, preset..argument..'_ind', 'integer', temp)
            temp = dt.preferences.read(mod, 'active_'..argument, arg_data.style)
            dt.preferences.write(mod, preset..argument, arg_data.style, temp)
        else
            temp = dt.preferences.read(mod, 'active_'..argument, arg_data.style)
            dt.preferences.write(mod, preset..argument, arg_data.style, temp)
        end
    end
    dt.print(string.format(_("saved to %s"), preset))
end

local function LoadFromPreference(preset) --load values from the specified 'preset' into the GUI elements
    for argument, arg_data in pairs(ENF.args) do
    local temp
        if argument == 'contrast_window_size' or argument == 'contrast_edge_scale' or argument == 'contrast_min_curvature' then  --comboboxes must be handled specially via an index value
            temp = dt.preferences.read(mod, preset..argument..'_ind', 'integer')
            GUI.ENF[argument].selected = temp
            dt.preferences.write(mod, 'active_'..argument..'_ind', 'integer', temp)
        else
            temp = dt.preferences.read(mod, preset..argument, arg_data.style)
            GUI.ENF[argument].value = temp
            dt.preferences.write(mod, 'active_'..argument, arg_data.style, temp)
        end     
    end
    dt.print(string.format(_("loaded from %s"), preset))
end

local function remove_temp_files(images_to_remove) --deletes all files specified by the input string
    if dt.configuration.running_os == 'windows' then
        dt.control.execute('del '..images_to_remove)
    else
        dt.control.execute('rm '..images_to_remove)
    end
end

local function initial(storage, format, images, high_quality, extra_data) --called before export happens, ensure enough images selected and all necesary programs installed correctly, if error then it sets a bit in extra_data for use by main and cancels export
    if #images <2 then
        table.insert(extra_data, 1, 1)
        return {}
    else
        PreCall({ENF,AIS,EXF})
        if AIS.install_error or ENF.install_error or EXF.install_error then
            table.insert(extra_data, 1, 2)
            return {}
        else
            table.insert(extra_data, 1, 0)
            return images
        end
    end
end

local function support_format(storage, format) --tells dt we only support TIFF export type
    local ret = false
    local temp = string.find(format.name, 'TIFF')
    if temp ~= nil then ret = true end
    return ret
end

local function show_status(storage, image, format, filename, number, total, high_quality, extra_data) --outputs message to user showing script export status
    dt.print(string.format(_("export for image fusion %d / %d"), math.floor(number), math.floor(total)))
end

local function main(storage, image_table, extra_data)
    if extra_data[1] == 1 then
        dt.print(_('too few images selected, please select at least 2 images'))
        return
    elseif extra_data[1] == 2 then
        dt.print(_('installation error, please verify binary paths are correct'))
        return
    end
    local images_to_remove = ''
    local final_image = nil
    local source_raw = nil
    for raw,exported in pairs(image_table) do --add the exported files to list of images to remove when complete\fail
        images_to_remove = images_to_remove..df.sanitize_filename(exported)..' '
    end
    if GUI.align.value then --if user selected to align images then update AIS arguments and execute AIS command
        local job = dt.gui.create_job('aligning images')
        image_table, images_to_remove, AIS.images_string = UpdateAISargs(image_table, images_to_remove)
        local run_cmd = BuildExecuteCmd(AIS)
        dt.print_log("AIS run command is " .. run_cmd)
        run_cmd = sanitize_decimals(run_cmd)
        dt.print_log("AIS decimaal sanitized command is " .. run_cmd)
        local resp = dsys.external_command(run_cmd)
        job.valid = false
        if resp ~= 0 then
            remove_temp_files(images_to_remove)
            dt.print(string.format(_("%s failed"), AIS.name))
            dt.print_error(AIS.name .. ' failed')
            return
        end
    end
    variants = {'active_'} --default to 'active' settings unless user selected to create multiple image variants from the specified preset types
    if GUI.Presets.variants.value then
        if GUI.Presets.variants_type.value == 'dri' then
            variants = {'dri_1', 'dri_2', 'dri_3'}
        else
            variants = {'dff_2', 'dff_2', 'dff_3'}
        end
    end
    local image_num = 0
    local job = dt.gui.create_job('blending '..#variants..' image(s)', true) --create a GUI job bar to display enfuse progress
    UpdateActivePreference() --load current GUI values into active preference (only applies to elements without a clicked/changed callback)
    for x,prefix in pairs(variants) do --for each image to be created load in the preference values, build arguments string, output image, and run command then execute.
        job.percent = image_num /(#variants)
        image_num = image_num+1
        ENF.images_string, final_image, source_raw = UpdateENFargs(image_table, prefix)
        local run_cmd = BuildExecuteCmd(ENF)
        dt.print_log("ENF run command is " .. run_cmd)
        run_cmd = sanitize_decimals(run_cmd)
        dt.print_log("ENF decimaal sanitized command is " .. run_cmd)
        local resp = dsys.external_command(run_cmd)
        if resp ~= 0 then
            remove_temp_files(images_to_remove)
            dt.print_error(ENF.name..' failed')
            dt.print(string.format(_("%s failed"), ENF.name))
            return
        end
        
        --copy exif data from original file
        run_cmd = EXF.bin..' -TagsFromFile '..df.sanitize_filename(source_raw.path..os_path_seperator..source_raw.filename)..' -exif:all --subifd:all -overwrite_original '..df.sanitize_filename(final_image)
        -- replace comma decimal separator with period
        dt.print_log("EXF run command is " .. run_cmd)
        run_cmd = sanitize_decimals(run_cmd)
        dt.print_log("EXF decimaal sanitized command is " .. run_cmd)
        resp = dsys.external_command(run_cmd)
        
        
        if GUI.Target.auto_import.value then --import image into dt if specified
            local imported = dt.database.import(final_image)
            dt.print_log("image imported")
            if GUI.Target.apply_style.selected > 1 then --apply specified style to imported image
                local set_style = styles[GUI.Target.apply_style.selected - 1]
                dt.styles.apply(set_style , imported)
            end
            if GUI.Target.copy_tags.value then --copy tags from source image
                local all_tags = dt.tags.get_tags(source_raw) 
                for _,tag in pairs(all_tags) do
                    if string.match(tag.name, 'darktable|') == nil then dt.tags.attach(tag, imported) end
                end
            end
            local set_tag = GUI.Target.add_tags.text
            if set_tag ~= nil then --add additional user-specified tags
                for tag in string.gmatch(set_tag, '[^,]+') do
                    tag = CleanSpaces(tag)
                    tag = dt.tags.create(tag)
                    dt.tags.attach(tag, imported) 
                end
            end
        end
    end
    remove_temp_files(images_to_remove)
    job.valid = false
    dt.print('image fusion process complete')
end

local function destroy()
    dt.destroy_storage('module_enfuseAdvanced')
end

--GUI--
stack_compression = dt.new_widget('stack'){}
local label_AIS_options= dt.new_widget('section_label'){
    label = _('image align options')
}
GUI.align = dt.new_widget('check_button'){
    label = _('align images'),
    value = dt.preferences.read(mod, 'active_align', 'bool'),
    tooltip = _('automatically align images prior to enfuse'),
    clicked_callback = function(self) 
        dt.preferences.write(mod, 'active_align', 'bool', self.value) 
        for _,widget in pairs(GUI.AIS) do
            widget.sensitive = self.value
        end
    end,
    reset_callback = function(self) self.value = true end
}
GUI.AIS.radial_distortion = dt.new_widget('check_button'){
    label = _('optimize radial distortion'),
    value = dt.preferences.read(mod, 'active_radial_distortion', 'bool'),
    tooltip = _('optimize radial distortion for all images, \nexcept for first'),
    clicked_callback = function(self) dt.preferences.write(mod, 'active_radial_distortion', 'bool', self.value) end,
    reset_callback = function(self) self.value = true end
}
GUI.AIS.optimize_field = dt.new_widget('check_button'){
    label = _('optimize field of view'), 
    value = dt.preferences.read(mod, 'active_optimize_field', 'bool'),
    tooltip = _('optimize field of view for all images, except for first. \nUseful for aligning focus stacks (DFF) with slightly \ndifferent magnification.'),
    clicked_callback = function(self) dt.preferences.write(mod, 'active_optimize_field', 'bool', self.value) end,
    reset_callback = function(self) self.value = true end
}
GUI.AIS.optimize_image_center = dt.new_widget('check_button'){
    label = _('optimize image center shift'), 
    value = dt.preferences.read(mod, 'active_optimize_image_center', 'bool'),
    tooltip = _('optimize image center shift for all images, \nexcept for first.'),
    clicked_callback = function(self) dt.preferences.write(mod, 'active_optimize_image_center', 'bool', self.value) end,
    reset_callback = function(self) self.value = true end
}
GUI.AIS.auto_crop = dt.new_widget('check_button'){
    label = _('auto crop'), 
    value = dt.preferences.read(mod, 'active_auto_crop', 'bool'),
    tooltip = _('auto crop the image to the area covered by all images.'),
    clicked_callback = function(self) dt.preferences.write(mod, 'active_auto_crop', 'bool', self.value) end,
    reset_callback = function(self) self.value = true end
}
GUI.AIS.distortion = dt.new_widget('check_button'){
    label = _('load distortion from lens database'), 
    value = dt.preferences.read(mod, 'active_distortion', 'bool'),
    tooltip = _('try to load distortion information from lens database'),
    clicked_callback = function(self) dt.preferences.write(mod, 'active_distortion', 'bool', self.value) end,
    reset_callback = function(self) self.value = true end
}
GUI.AIS.gpu = dt.new_widget('check_button'){
    label = _('use gpu'), 
    value = dt.preferences.read(mod, 'active_gpu', 'bool'),
    tooltip = _('use gpu during alignment'),
    clicked_callback = function(self) dt.preferences.write(mod, 'active_gpu', 'bool', self.value) end,
    reset_callback = function(self) self.value = true end
}
temp = dt.preferences.read(mod, 'active_grid_size_ind', 'integer')
if not InRange(temp, 1, 9) then temp = 5 end 
GUI.AIS.grid_size = dt.new_widget('combobox'){
    label = _('image grid size'), 
    tooltip = _('break image into a rectangular grid \nand attempt to find num control points in each section.\ndefault: (5x5)'),
    selected = temp,
    '1','2','3','4','5','6','7','8','9',
    changed_callback = function(self)
        dt.preferences.write(mod, 'active_grid_size', 'integer', self.value) 
        dt.preferences.write(mod, 'active_grid_size_ind', 'integer', self.selected)
    end,
    reset_callback = function(self) 
        self.selected = 5
        dt.preferences.write(mod, 'active_grid_size', 'integer', self.value) 
        dt.preferences.write(mod, 'active_grid_size_ind', 'integer', self.selected)
    end
} 
temp = dt.preferences.read(mod, 'active_control_points_ind', 'integer')
if not InRange(temp, 1, 9) then temp = 8 end 
GUI.AIS.control_points = dt.new_widget('combobox'){
    label = _('control points/grid'), 
    tooltip = _('number of control points (per grid, see option -g) \nto create between adjacent images \ndefault: (8).'),
    selected = temp,
    '1','2','3','4','5','6','7','8','9',             
    changed_callback = function(self)
        dt.preferences.write(mod, 'active_control_points', 'integer', self.value) 
        dt.preferences.write(mod, 'active_control_points_ind', 'integer', self.selected)
    end,
    reset_callback = function(self) 
        self.selected = 8
        dt.preferences.write(mod, 'active_control_points', 'integer', self.value) 
        dt.preferences.write(mod, 'active_control_points_ind', 'integer', self.selected)
    end
} 
temp = dt.preferences.read(mod, 'active_control_points_remove_ind', 'integer')
if not InRange(temp, 1, 9) then temp = 3 end 
GUI.AIS.control_points_remove = dt.new_widget('combobox'){
    label = _('remove control points with error'), 
    tooltip = _('remove all control points with an error higher \nthan num pixels \ndefault: (3)'),
    selected = temp,
    '1','2','3','4','5','6','7','8','9',             
    changed_callback = function(self)
        dt.preferences.write(mod, 'active_control_points_remove', 'integer', self.value) 
        dt.preferences.write(mod, 'active_control_points_remove_ind', 'integer', self.selected)
    end,
    reset_callback = function(self) 
        self.selected = 3
        dt.preferences.write(mod, 'active_control_points_remove', 'integer', self.value) 
        dt.preferences.write(mod, 'active_control_points_remove_ind', 'integer', self.selected)
    end
}
temp = dt.preferences.read(mod, 'active_correlation_ind', 'integer')
if not InRange(temp, 1, 10) then temp = 9 end 
GUI.AIS.correlation  = dt.new_widget('combobox'){
    label = _('correlation threshold for control points'), 
    tooltip = _('correlation threshold for identifying \ncontrol points \ndefault: (0.9).'),
    selected = temp,
    '0.1','0.2','0.3','0.4','0.5','0.6','0.7','0.8','0.9','1.0',     
    changed_callback = function(self)
        dt.preferences.write(mod, 'active_correlation', 'float', self.value) 
        dt.preferences.write(mod, 'active_correlation_ind', 'integer', self.selected)
    end,
    reset_callback = function(self) 
        self.selected = 9
        dt.preferences.write(mod, 'active_correlation', 'float', self.value) 
        dt.preferences.write(mod, 'active_correlation_ind', 'integer', self.selected)
    end
} 
local label_ENF_options= dt.new_widget('section_label'){
    label = _('image fusion options')
}
temp = dt.preferences.read(mod, 'active_exposure_weight', 'float')
if not InRange(temp, 0, 1) then temp = 1 end
GUI.ENF.exposure_weight = dt.new_widget('slider'){
    label = _('exposure weight'),
    tooltip = _('set the relative weight of the well-exposedness criterion \nas defined by the chosen exposure weight function. \nincreasing this weight relative to the others will\n make well-exposed pixels contribute more to\n the final output. \ndefault: (1.0)'),
    hard_min = 0,
    hard_max = 1,
    value = temp,
    reset_callback = function(self) 
        self.value = 1
    end
}
temp = dt.preferences.read(mod, 'active_saturation_weight', 'float')
if not InRange(temp, 0, 1) then temp = .2 end
GUI.ENF.saturation_weight = dt.new_widget('slider'){
    label = _('saturation weight'),
    tooltip = _('set the relative weight of high-saturation pixels. \nincreasing this weight makes pixels with high \nsaturation contribute more to the final output. \ndefault: (0.2)'),
    hard_min = 0,
    hard_max = 1,
    value = temp,
    reset_callback = function(self) 
        self.value = 0.2
    end
}
temp = dt.preferences.read(mod, 'active_contrast_weight', 'float')
if not InRange(temp, 0, 1) then temp = 0 end
GUI.ENF.contrast_weight = dt.new_widget('slider'){
    label = _('contrast weight'),
    tooltip = _('sets the relative weight of high local-contrast pixels. \ndefault: (0.0).'),
    hard_min = 0,
    hard_max = 1,
    value = temp,
    reset_callback = function(self) 
        self.value = 0
    end
}
temp = dt.preferences.read(mod, 'active_exposure_optimum', 'float')
if not InRange(temp, 0, 1) then temp = 0.5 end
GUI.ENF.exposure_optimum = dt.new_widget('slider'){
    label = _('exposure optimum'),
    tooltip = _('determine at what normalized exposure value\n the optimum exposure of the input images\n is. this is, set the position of the maximum\n of the exposure weight curve. use this \noption to fine-tune exposure weighting. \ndefault: (0.5)'),
    hard_min = 0,
    hard_max = 1,
    value = temp,
    reset_callback = function(self) 
        self.value = 0.5
    end
}
temp = dt.preferences.read(mod, 'active_exposure_width', 'float')
if not InRange(temp, 0, 1) then temp = 0.2 end
GUI.ENF.exposure_width = dt.new_widget('slider'){
    label = _('exposure width'),
    tooltip = _('set the characteristic width (FWHM) of the exposure \nweight function. low numbers give less weight to \npixels that are far from the user-defined \noptimum and vice versa. use this option to \nfine-tune exposure weighting. \ndefault: (0.2)'),
    hard_min = 0,
    hard_max = 1,
    value = temp,
    reset_callback = function(self) 
        self.value = 0.2
    end
}
GUI.ENF.hard_masks = dt.new_widget('check_button'){
    label = _('hard mask'), 
    value = dt.preferences.read(mod, 'active_hard_masks', 'bool'),
    tooltip = _('force hard blend masks on the finest scale. this avoids \naveraging of fine details (only), at the expense \nof increasing the noise. this improves the \nsharpness of focus stacks considerably.\ndefault (soft mask)'),   
    clicked_callback = function(self) dt.preferences.write(mod, 'active_hard_masks', 'bool', self.value) end,
    reset_callback = function(self) self.value = false end
}
GUI.ENF.save_masks = dt.new_widget('check_button'){
    label = _('save masks'), 
    value = dt.preferences.read(mod, 'active_save_masks', 'bool'),
    tooltip = _('save the generated weight masks to your home directory,\nenblend saves masks as 8 bit grayscale, \ni.e. single channel images. \nfor accuracy we recommend to choose a lossless format.'),  
    clicked_callback = function(self) dt.preferences.write(mod, 'active_save_masks', 'bool', self.value) end,
    reset_callback = function(self) self.value = false end
}
temp = dt.preferences.read(mod, 'active_contrast_window_size_ind', 'integer')
if not InRange(temp, 1, 8) then temp = 3 end 
GUI.ENF.contrast_window_size = dt.new_widget('combobox'){
    label = _('contrast window size'), 
    tooltip = _('set the window size for local contrast analysis. \nthe window will be a square of size × size pixels. \nif given an even size, Enfuse will \nautomatically use the next odd number.\nfor contrast analysis size values larger \nthan 5 pixels might result in a \nblurry composite image. values of 3 and \n5 pixels have given good results on \nfocus stacks. \ndefault: (5) pixels'),
    selected = temp,
    '3','4','5','6','7','8','9','10',
    changed_callback = function(self)
        dt.preferences.write(mod, 'active_contrast_window_size', 'integer', self.value) 
        dt.preferences.write(mod, 'active_contrast_window_size_ind', 'integer', self.selected)
    end,
    reset_callback = function(self) 
        self.selected = 3
        dt.preferences.write(mod, 'active_contrast_window_size', 'integer', self.value) 
        dt.preferences.write(mod, 'active_contrast_window_size_ind', 'integer', self.selected)
    end
} 
temp = dt.preferences.read(mod, 'active_contrast_edge_scale_ind', 'integer')
if not InRange(temp, 1, 6) then temp = 1 end 
GUI.ENF.contrast_edge_scale = dt.new_widget('combobox'){
    label = _('contrast edge scale'), 
    tooltip = _('a non-zero value for EDGE-SCALE switches on the \nLaplacian-of-Gaussian (LoG) edge detection algorithm.\n edage-scale is the radius of the Gaussian used \nin the search for edges. a positive LCE-SCALE \nturns on local contrast enhancement (LCE) \nbefore the LoG edge detection. \nDefault: (0.0) pixels.'),
    selected = temp,
    '0.0','0.1','0.2','0.3','0.4','0.5',
    changed_callback = function(self)
        dt.preferences.write(mod, 'active_contrast_edge_scale', 'float', self.value) 
        dt.preferences.write(mod, 'active_contrast_edge_scale_ind', 'integer', self.selected)
    end,
    reset_callback = function(self) 
        self.selected = 1
        dt.preferences.write(mod, 'active_contrast_edge_scale', 'float', self.value) 
        dt.preferences.write(mod, 'active_contrast_edge_scale_ind', 'integer', self.selected)
    end
}
temp = dt.preferences.read(mod, 'active_contrast_min_curvature_ind', 'integer')
if not InRange(temp, 1, 11) then temp = 1 end 
GUI.ENF.contrast_min_curvature = dt.new_widget('combobox'){
    label = _('contrast min curvature [%]'),
    tooltip = _('define the minimum curvature for the LoG edge detection. Append a ‘%’ to specify the minimum curvature relative to maximum pixel value in the source image. Default: (0.0%)'),
    selected = temp, 
    '0.0%','0.1%','0.2%','0.3%','0.4%','0.5%','0.6%','0.7%','0.8%','0.9%','1.0%',
    changed_callback = function(self)
        dt.preferences.write(mod, 'active_contrast_min_curvature', 'string', self.value) 
        dt.preferences.write(mod, 'active_contrast_min_curvature_ind', 'integer', self.selected)
    end,
    reset_callback = function(self) 
        self.selected = 1
        dt.preferences.write(mod, 'active_contrast_min_curvature', 'string', self.value) 
        dt.preferences.write(mod, 'active_contrast_min_curvature_ind', 'integer', self.selected)
    end
} 
local label_target_options= dt.new_widget('section_label'){
    label = _('target file')
}
temp = dt.preferences.read(mod, 'active_compression_level_tif_ind', 'integer')
if not InRange(temp, 1, 4) then temp = 1 end 
GUI.Target.compression_level_tif = dt.new_widget('combobox'){
    label = _('tiff compression'), 
    tooltip = _('compression method for tiff files'),
    selected = temp,
    'none','deflate','lzw','packbits',
    changed_callback = function(self)
        dt.preferences.write(mod, 'active_compression_level_tif', 'string', self.value) 
        dt.preferences.write(mod, 'active_compression_level_tif_ind', 'integer', self.selected)
    end,
    reset_callback = function(self) 
        self.selected = 1
        dt.preferences.write(mod, 'active_compression_level_tif', 'string', self.value) 
        dt.preferences.write(mod, 'active_compression_level_tif_ind', 'integer', self.selected)
    end 
}
temp = dt.preferences.read(mod, 'active_compression_level_jpg', 'integer')
if not InRange(temp, 0, 100) then temp = 0 end
GUI.Target.compression_level_jpg = dt.new_widget('slider'){
    label = _('jpeg compression'),
    tooltip = _('jpeg compression level'),
    soft_min = 0,
    soft_max = 100,
    hard_min = 0,
    hard_max = 100,
    step = 5,
    digits = 0,
    value = temp,
    reset_callback = function(self) 
        self.value = 0
    end
}
local blank = dt.new_widget('box'){}
stack_compression = dt.new_widget('stack'){
    GUI.Target.compression_level_tif,
    GUI.Target.compression_level_jpg,
    blank,
    active = 1
}
temp = dt.preferences.read(mod, 'active_format_ind', 'integer')
if not InRange(temp, 1, 6) then temp = 1 end 
GUI.Target.format = dt.new_widget('combobox'){
    label = _('file format'), 
    tooltip = _('file format of the enfused final image'),
    selected = temp,
    'tif','jpg','png','pnm','pbm','ppm',
    changed_callback = function(self)
        dt.preferences.write(mod, 'active_format', 'string', self.value) 
        dt.preferences.write(mod, 'active_format_ind', 'integer', self.selected)
        if self.value == 'tif' then stack_compression.active = 1
        elseif self.value == 'jpg' then stack_compression.active = 2
        else stack_compression.active = 3
        end
    end,
    reset_callback = function(self) 
        self.selected = 1
        dt.preferences.write(mod, 'active_format', 'string', self.value) 
        dt.preferences.write(mod, 'active_format_ind', 'integer', self.selected)
    end 
}
temp = dt.preferences.read(mod, 'active_depth_ind', 'integer')
if not InRange(temp, 1, 5) then temp = 3 end 
GUI.Target.depth = dt.new_widget('combobox'){
    label = _('bit depth'), 
    tooltip = _('bit depth of the enfused file'),
    selected = temp,
    '8','16','32','r32','r64',
    changed_callback = function(self)
        dt.preferences.write(mod, 'active_depth', 'string', self.value) 
        dt.preferences.write(mod, 'active_depth_ind', 'integer', self.selected)
    end,
    reset_callback = function(self) 
        self.selected = 2
        dt.preferences.write(mod, 'active_depth', 'string', self.value) 
        dt.preferences.write(mod, 'active_depth_ind', 'integer', self.selected)
    end 
}
local label_directory = dt.new_widget('label'){
    label = _('directory'),
    ellipsize = 'start',
    halign = 'start'
}
temp = dt.preferences.read(mod, 'active_output_directory', 'string')
if temp == '' or temp == nil then temp = dt.collection[1].path end
GUI.Target.output_directory = dt.new_widget('file_chooser_button'){
    title = 'Select export path', 
    is_directory = true,
    tooltip = _('select the target directory for the fused image. \nthe filename is created automatically.'),
    value = temp,
    changed_callback = function(self) dt.preferences.write(mod, 'active_output_directory', 'string', self.value) end
}
GUI.Target.source_location = dt.new_widget('check_button'){
    label = _('save to source image location'), 
    value = dt.preferences.read(mod, 'active_source_location', 'bool'),
    tooltip = _('if checked ignores the location above and saves output image(s) to the same location as the source images.'),  
    clicked_callback = function(self) dt.preferences.write(mod, 'active_source_location', 'bool', self.value) end,
    reset_callback = function(self) self.value = true end
}
temp = dt.preferences.read(mod, 'active_on_conflict_ind', 'integer')
if not InRange(temp, 1, 2) then temp = 1 end 
GUI.Target.on_conflict = dt.new_widget('combobox'){
    label = _('on conflict'), 
    selected = 1,  
    'create unique filename','overwrite',           
    changed_callback = function(self)
        dt.preferences.write(mod, 'active_on_conflict', 'string', self.value) 
        dt.preferences.write(mod, 'active_on_conflict_ind', 'integer', self.selected)
    end,
    reset_callback = function(self) 
        self.selected = 1
        dt.preferences.write(mod, 'active_on_conflict', 'string', self.value) 
        dt.preferences.write(mod, 'active_on_conflict_ind', 'integer', self.selected)
    end 
}  
GUI.Target.auto_import = dt.new_widget('check_button'){
    label = _('auto import'), 
    value = dt.preferences.read(mod, 'active_auto_import', 'bool'),
    tooltip = _('import the image into darktable database when enfuse completes'),  
    clicked_callback = function(self)
        dt.preferences.write(mod, 'active_auto_import', 'bool', self.value)
        GUI.Target.apply_style.sensitive = self.value
        GUI.Target.copy_tags.sensitive = self.value
        GUI.Target.add_tags.sensitive = self.value
    end,
    reset_callback = function(self) self.value = true end
}
temp = dt.preferences.read(mod, 'active_apply_style_ind', 'integer')
GUI.Target.apply_style = dt.new_widget('combobox'){
    label = _('apply style on Import'),
    tooltip = _('apply selected style on auto-import to newly created blended image'),
    selected = 1,
    'none',
    changed_callback = function(self)
        dt.preferences.write(mod, 'active_apply_style', 'string', self.value) 
        dt.preferences.write(mod, 'active_apply_style_ind', 'integer', self.selected)
    end,
    reset_callback = function(self) 
        self.selected = 1
        dt.preferences.write(mod, 'active_apply_style', 'string', self.value) 
        dt.preferences.write(mod, 'active_apply_style_ind', 'integer', self.selected)
    end 
}
for k=1, (styles_count-1) do
    GUI.Target.apply_style[k+1] = styles[k].name
end
if not InRange(temp, 1, styles_count) then temp = 1 end
GUI.Target.apply_style.selected = temp
GUI.Target.copy_tags = dt.new_widget('check_button'){
    label = _('copy tags'), 
    value = dt.preferences.read(mod, 'active_copy_tags', 'bool'),
    tooltip = _('copy tags from first image.'), 
    clicked_callback = function(self) dt.preferences.write(mod, 'active_copy_tags', 'bool', self.value) end,
    reset_callback = function(self) self.value = true end
}
temp = dt.preferences.read(mod, 'active_add_tags', 'string')
if temp == '' then temp = nil end 
GUI.Target.add_tags = dt.new_widget('entry'){
    tooltip = _('additional tags to be added on import, seperate with commas, all spaces will be removed'),
    text = temp,
    placeholder = _('enter tags, separated by commas'),
    editable = true
}
temp = dt.preferences.read(mod, 'active_current_preset_ind', 'integer')
if not InRange(temp, 1, 6) then temp = 1 end
GUI.Presets.current_preset = dt.new_widget('combobox'){
    label = _('active preset'),
    tooltip = _('preset to be loaded from or saved to'),
    value = temp,
    'dri_1', 'dri_2', 'dri_3', 'dff_1', 'dff_2', 'dff_3',
    changed_callback = function(self)
        dt.preferences.write(mod, 'active_current_preset', 'string', self.value) 
        dt.preferences.write(mod, 'active_current_preset_ind', 'integer', self.selected)
    end,
    reset_callback = function(self) 
        self.selected = 1
        dt.preferences.write(mod, 'active_current_preset', 'string', self.value) 
        dt.preferences.write(mod, 'active_current_preset_ind', 'integer', self.selected)
    end 
}
GUI.Presets.load = dt.new_widget('button'){
    label = _('load fusion preset'),
    tooltip = _('load current fusion parameters from selected preset'),
    clicked_callback = function() LoadFromPreference(GUI.Presets.current_preset.value) end
}
GUI.Presets.save = dt.new_widget('button'){
    label = _('save to fusion preset'),
    tooltip = _('save current fusion parameters to selected preset'),
    clicked_callback = function() SaveToPreference(GUI.Presets.current_preset.value) end
}
GUI.Presets.variants = dt.new_widget('check_button'){
    label = _('create image variants from presets'), 
    value = dt.preferences.read(mod, 'active_variants', 'bool'),
    tooltip = _('create multiple image variants based on the three different presets of the specified type'),   
    clicked_callback = function(self) 
        dt.preferences.write(mod, 'active_variants', 'bool', self.value)
        if self.value then
            GUI.Target.on_conflict.selected = 1
            GUI.Target.on_conflict.sensitive = false
            GUI.Presets.variants_type.sensitive = true
        else
            GUI.Target.on_conflict.sensitive = true
            GUI.Presets.variants_type.sensitive = false
        end
    end,
    reset_callback = function(self) self.value = false end
}
temp = dt.preferences.read(mod, 'active_variants_type_ind', 'integer')
if not InRange(temp, 1, 2) then temp = 1 end
GUI.Presets.variants_type = dt.new_widget('combobox'){
    label = _('create variants type'),
    tooltip = _('preset type to be used when creating image variants'),
    selected = temp,
    'dri', 'dff',
    changed_callback = function(self)
        dt.preferences.write(mod, 'active_variants_type', 'string', self.value) 
        dt.preferences.write(mod, 'active_variants_type_ind', 'integer', self.selected)
    end,
    reset_callback = function(self) 
        self.selected = 1
        dt.preferences.write(mod, 'active_variants_type', 'string', self.value) 
        dt.preferences.write(mod, 'active_variants_type_ind', 'integer', self.selected)
    end 
}
GUI.Presets.variants_type.sensitive = GUI.Presets.variants.value
temp = df.get_executable_path_preference(AIS.name)
GUI.exes.align_image_stack = dt.new_widget('file_chooser_button'){
    title = 'align_image_stack ' .. _('binary path'),
    value = temp,
    tooltip = temp,
    is_directory = false,
    changed_callback = function(self) self.tooltip = self.value end
}
temp = df.get_executable_path_preference(ENF.name)
GUI.exes.enfuse = dt.new_widget('file_chooser_button'){
    title = 'enfuse ' .. _('binary path'),
    value = temp,
    tooltip = temp,
    is_directory = false,
    changed_callback = function(self) self.tooltip = self.value end
}
temp = df.get_executable_path_preference(EXF.name)
GUI.exes.exiftool = dt.new_widget('file_chooser_button'){
    title = 'exiftool ' .. _('binary path'),
    value = temp,
    tooltip = temp,
    is_directory = false,
    changed_callback = function(self) self.tooltip = self.value end
} 
GUI.exes.update = dt.new_widget('button'){
    label = _('update'),
    tooltip = _('update the binary paths with current values'),
    clicked_callback = function() ExeUpdate({AIS,ENF,EXF}) end
}
temp = GUI.Target.format.value
if temp == 'tif' then temp = 1
elseif temp == 'jpg' then temp = 2
else temp = 3
end
stack_compression.active = temp
for _,widget in pairs(GUI.AIS) do
    widget.sensitive = GUI.align.value
end
GUI.Target.apply_style.sensitive = GUI.Target.auto_import.value
GUI.Target.copy_tags.sensitive = GUI.Target.auto_import.value
GUI.Target.add_tags.sensitive = GUI.Target.auto_import.value

local box_AIS = dt.new_widget('box'){
    orientation = 'vertical',
    label_AIS_options,
    GUI.align,
    GUI.AIS.radial_distortion,
    GUI.AIS.optimize_field,
    GUI.AIS.optimize_image_center,
    GUI.AIS.auto_crop,
    GUI.AIS.distortion,
    GUI.AIS.gpu,
    GUI.AIS.grid_size,
    GUI.AIS.control_points,
    GUI.AIS.control_points_remove,
    GUI.AIS.correlation
}
local box_ENF = dt.new_widget('box'){
    orientation = 'vertical',
    label_ENF_options,
    GUI.ENF.exposure_weight,
    GUI.ENF.saturation_weight,
    GUI.ENF.contrast_weight,
    GUI.ENF.exposure_optimum,
    GUI.ENF.exposure_width,
    GUI.ENF.hard_masks,
    GUI.ENF.save_masks,
    GUI.ENF.contrast_window_size,
    GUI.ENF.contrast_edge_scale,
    GUI.ENF.contrast_min_curvature,
    GUI.Presets.current_preset,
    GUI.Presets.load,
    GUI.Presets.save
}
local box_Target = dt.new_widget('box'){
    orientation = 'vertical',
    label_target_options,
    GUI.Target.format,
    GUI.Target.depth,
    stack_compression,
    label_directory,
    GUI.Target.output_directory,
    GUI.Target.source_location,
    GUI.Target.on_conflict,
    GUI.Presets.variants,
    GUI.Presets.variants_type,
    GUI.Target.auto_import,
    GUI.Target.apply_style,
    GUI.Target.copy_tags,
    GUI.Target.add_tags
}
local box_exes = dt.new_widget('box'){
    orientation = 'vertical',
    GUI.exes.align_image_stack,
    GUI.exes.enfuse,
    GUI.exes.exiftool,
    GUI.exes.update
}
GUI.options_contain = dt.new_widget('stack'){
    box_AIS,
    box_ENF,
    box_Target,
    box_exes,
    active = 2
}
GUI.show_options = dt.new_widget('combobox'){
    label = _('show options'),
    tooltip = _('show options for specified aspect of output'),
    selected = 2,
    'align image stack', 'enfuse/enblend', 'target file',
    changed_callback = function(self)
        GUI.options_contain.active = self.selected
    end,
    reset_callback = function(self) 
        self.selected = 1
        dt.preferences.write(mod, 'active_current_preset', 'string', self.value) 
        dt.preferences.write(mod, 'active_current_preset_ind', 'integer', self.selected)
    end 
}
local storage_widget = dt.new_widget('box') {
    orientation = 'vertical',
    GUI.show_options,
    GUI.options_contain
} 

-- Register new storage --
dt.register_storage(
    'module_enfuseAdvanced', --Module name
    _('DRI or DFF image'), --Name
    show_status, --store: called once per exported image
    main, --finalize: called once when all images have finished exporting
    support_format, --supported
    initial, --initialize
    storage_widget
)

if dt.preferences.read(mod, 'bin_exists', 'bool') then 
    GUI.options_contain.active = 2
    GUI.show_options.sensitive = true
else
    GUI.options_contain.active = 4
    GUI.show_options.sensitive = false
end

script_data.destroy = destroy

return script_data