--[[	HDRMerge plugin for darktable

  copyright (c) 2018  Kevin Ertel
  
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

--[[	Version 1.0.2     3/20/2018

This plugin adds the module "HDRMerge" to darktable's lighttable view

****Dependencies****
OS: Windows (tested), Linux (not verified), MacOS (not verified)
HDRMerge 4.5 or greater

****How to use****
Require this file from your luarc file, as with any other dt plug-in.
On initial run setup HDRMerge's install path via the settings > lua options dialog. Restart may be required.
Select a group of photos you desire to merge and press HDRMerge

****Options****
Bits Per Sample - Bit depth of the final image
Preview Size - Preview size of the built-in preview
Batch - Allows user to select multiple groups and HDRMerge will auto-group them based on time seperation "gap"
Gap - Time seperation between groupings when running in batch mode
Style - Style to be applied when image is auto-imported (Auto-import only supported in non-batch mode)
Copy Tags - Enable to copy tags from first file in selection
Additional Tags - Additional tags to be added, works with or without Copy Tags enabled.

****Known Bugs / Deficiencies****:
CMD window pops up when run
Slider double-click sets to 31, not 3
Removes spaces from tags (desired to only removed spaces at front and end)

****Features for future releases****


****Versions****
Version 0.1 - Implemented via "Selected Images"
Version 0.2 - Implemented as it's own module - windows only
Version 0.3 - Improved cross-platform compatibility, improved performance ( switched from io.popen() to dt.control.execute() )
Version 1.0 - Added:
					Copy Tags Option
					Additional Tags Option
					User Defined Default Style
					Progress Bar
		1.0.1 - Added check for at least 2 images selected
				Fixed issue with status bar not disappearing when HDRmerge not installed or not enough images selected
		1.0.2 - Changes for grabbing executable path and setting preference (to imporve cross-platform support)
				Changes to building the run_cmd (to improve cross-platform support)
]]

local dt = require "darktable"
local df = require "lib/dtutils.file"
require "official/yield"

--Detect OS and modify accordingly--	
op_sys = dt.configuration.running_os
if op_sys == "windows" then
	os_path_seperator = "\\"
else
	os_path_seperator = "/"
end

-- READ PREFERENCES --
pref_bps = dt.preferences.read("module_HDRMerge", "bits_per_sample", "enum")
if pref_bps == "32" then
	pref_bps_enum = 3
elseif pref_bps == "24" then
	pref_bps_enum = 2
else
	pref_bps_enum = 1
end
pref_size = dt.preferences.read("module_HDRMerge", "preview_size", "enum")
if pref_size == "none" then
	pref_size_enum = 3
elseif pref_size == "full" then
	pref_size_enum = 2
else
	pref_size_enum = 1
end
pref_cpytags = dt.preferences.read("module_HDRMerge", "copy_tags", "bool")
pref_addtags = dt.preferences.read("module_HDRMerge", "add_tags", "string")
pref_style = dt.preferences.read("module_HDRMerge", "style", "string")

--Detect User Styles--
styles = dt.styles
styles_count = 1 -- "none" = 1
for _,i in pairs(dt.styles) do
	if type(i) == "userdata" then styles_count = styles_count + 1 end
end

local function build_execute_command(cmd, args, file_list)
	local result = false

	if dt.configuration.running_os == "macos" then
		cmd = string.gsub(cmd, "open", "")
		cmd = string.gsub(cmd, "-W", "")
		cmd = string.gsub(cmd, "-a", "")
	--	result = cmd.." "..file_list.." "..args
	--else
	--	result = cmd..""..args.." "..file_list
	end
	result = cmd.." "..args.." "..file_list
	return result
end

-- FUNCTION --
local function HDRMerge()
	dt.print_log("Running HDRMerge")
	dt.print("Running HDRMerge")
	gui_job = dt.gui.create_job("HDRMerge", 1)
	df.set_executable_path_preference("hdrmerge", dt.preferences.read("module_HDRMerge", "bin_path", "string"))
	dt.print_log("Executable Path Preference: "..df.get_executable_path_preference("hdrmerge"))
	
	--Inits--
	local images = dt.gui.selection()
	local images_to_merge = ""
	local image_path = ""
	local curr_image = ""
	local first_image = ""
	local last_image = ""
	local output_file = ""
	local num_images = 0
	
	--Read Settings--
	set_bps = HDRMerge_cmbx_bps.value
	set_size = HDRMerge_cmbx_size.value
	set_batch = HDRMerge_chkbtn_batch.value
	set_gap = HDRMerge_sldr_gap.value
	set_cpytags = HDRMerge_chkbtn_cpytags.value
	set_tag = HDRMerge_entry_tag.text
	
	--Create Images String--
	for _,image in pairs(images) do 
		curr_image = image.path..os_path_seperator..image.filename
		images_to_merge = images_to_merge..curr_image.." "
		last_image = string.gsub(string.match(image.filename,'^.*%.'), "%." , "")
		image_path = image.path
		if _ == 1 then first_image = last_image end
		num_images = num_images + 1
	end
	output_file = image_path..os_path_seperator..first_image.."-"..string.match(last_image, '%d*$')..".dng"
	
	--Check if at least 2 images selected--
	if num_images < 2 then
		dt.print_error("Less than 2 images selected")
		dt.print("ERROR - please select at least 2 images")
		gui_job.valid = false
		return
	end
	
	--Check if HDRMerge is installed--
	local HDRMerge_Path = df.check_if_bin_exists("hdrmerge")
	if not HDRMerge_Path then
		dt.print_error("HDRMerge not found")
		dt.print("ERROR - HDRMerge not found")
		gui_job.valid = false
		return
	end
	
	--Create Command Args--
	cmd_args = "-b "..set_bps.." -p "..set_size
	if (set_batch) then 
		cmd_args = cmd_args.." -B -g "..set_gap.." -a"
	else                                              --add ability to launch with gui here by omiting -o arg
		cmd_args = cmd_args.." -o "..output_file
	end  
	
	gui_job.percent = .1
	
	--Execute with Run Command--
	run_cmd = build_execute_command(HDRMerge_Path, cmd_args, images_to_merge)
	dt.print_log("run_cmd = "..run_cmd)
	resp = dt.control.execute(run_cmd)
	
	gui_job.percent = .9
	
	if resp == 0 and not(set_batch) then
		--Import Image--
		imported = dt.database.import(output_file)
		
		--Apply Selected Style (IF)--
		if HDRMerge_cmbx_style.selected > 1 then
			set_style = styles[HDRMerge_cmbx_style.selected - 1]
			dt.styles.apply(set_style , imported)
		end
		
		--Copy Tags (IF)--
		if (set_cpytags) then
			all_tags = dt.tags.get_tags(images[1])
			for _,tag in pairs(all_tags) do
				if string.match(tag.name, 'darktable|') == nil then
					dt.tags.attach(tag, imported)
				end
			end
		end
		
		--Apply Entered Tags (IF)--
		if set_tag ~= nil then
			for tag in string.gmatch(set_tag, '[^,]+') do
				tag = string.gsub(tag, " ", "")
				tag = dt.tags.create(tag)
				dt.tags.attach(tag, imported) 
			end
		end
		
		dt.print_log("Merge Successful")
		dt.print("Merge Successful")
	elseif resp == 0 then
		dt.print_log("Merge Successful")
		dt.print("Merge Successful")
	else
		dt.print_error("Merge Not Successful")
		dt.print("ERROR - Merge Not Successful")
	end
	gui_job.percent = 1
	gui_job.valid = false
end

-- GUI --
local executables = {"hdrmerge"}
if dt.configuration.running_os ~= "linux" then
  path_widget = df.executable_path_widget(executables)
end

HDRMerge_lbl_base= dt.new_widget("section_label"){
     label = "Base Options",
	}
HDRMerge_cmbx_bps = dt.new_widget("combobox"){	
	label = 'Bits Per Sample', 
    tooltip = 'Output file\'s bit depth \ndefault: '..pref_bps,
    value = pref_bps_enum,
    "16", "24", "32",     
	}  
HDRMerge_cmbx_size = dt.new_widget("combobox"){
    label = 'Preview Size', 
    tooltip = 'Output file\'s built-in preview size \ndefault: '..pref_size,
    value = pref_size_enum,
    "half", "full", "none",        
	}  
HDRMerge_lbl_batch= dt.new_widget("section_label"){
     label = "Batch Options",
	}
HDRMerge_chkbtn_batch = dt.new_widget("check_button"){
    label = '  Batch Mode', 
    value = false, --pref_batch,
    tooltip ='Operate in batch mode. When operating in batch mode output files will NOT be auto-imported \ndefault: (false).',  
	}
HDRMerge_sldr_gap = dt.new_widget("slider"){
	label = 'Batch Gap [sec.]',
	tooltip = 'Gap, in seconds, between batch mode groups \ndefault: (3).',
	soft_min = 1,
	soft_max = 60,
	hard_min = 1,
	hard_max = 60,
	step = 1,
	digits = 0,
	value = 3, --pref_gap,
	}
HDRMerge_lbl_out= dt.new_widget("section_label"){
     label = "Auto-import Options",
	}
HDRMerge_cmbx_style = dt.new_widget("combobox"){
	label = "Apply Style on Import",
	tooltip = "Apply selected style on auto-import to newly created HDRMerge DNG\nDoes not apply when in Batch mode.",
	value = 1,
	"none",
	}
pref_style_enum = 1
	for k=1, (styles_count-1) do
		HDRMerge_cmbx_style[k+1] = styles[k].name
	if styles[k].name == pref_style then pref_style_enum = k+1 end
end
HDRMerge_cmbx_style.value = pref_style_enum
HDRMerge_chkbtn_cpytags = dt.new_widget("check_button"){
    label = '  Copy Tags', 
    value = pref_cpytags,
    tooltip ='Copy tags from first image. When operating in batch mode this will NOT be performed. \ndefault: (true).',  
	}
HDRMerge_lbl_tags= dt.new_widget("label"){
     label = 'Additional Tags',
	}
HDRMerge_entry_tag = dt.new_widget("entry"){
	tooltip = "Additional tags to be added on import. Seperate with commas, all spaces will be removed",
	text = pref_addtags,
	placeholder = "Enter tags, seperated by commas",
	editable = true
}
HDRMerge_btn_run = dt.new_widget("button"){
	label = "Run HDRMerge",
	tooltip = "Runs HDRMerge on selected images, with selected settings",
	clicked_callback = function() HDRMerge() end
	}
HDRMerge_lbl_note= dt.new_widget("label"){
     label = 'Defaults can be adjusted under:\n"Settings > lua options"',
	}
dt.register_lib(
	"HDRMerge_Lib",	-- Module name
	"HDRMerge",	-- name
	true,	-- expandable
	false,	-- resetable
	{[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 99}},	-- containers
	dt.new_widget("box"){
		orientation = "vertical",
		HDRMerge_lbl_base,
		HDRMerge_cmbx_bps,
		HDRMerge_cmbx_size,
		HDRMerge_lbl_batch,
		HDRMerge_chkbtn_batch,
		HDRMerge_sldr_gap,
		HDRMerge_lbl_out,
		HDRMerge_cmbx_style,
		HDRMerge_chkbtn_cpytags,
		HDRMerge_lbl_tags,
		HDRMerge_entry_tag,
		HDRMerge_btn_run,
		HDRMerge_lbl_note
	}
)

-- PREFERENCES --
entry_widget_tags = dt.new_widget("entry"){
	tooltip = "Seperate with commas, all spaces will be removed",
	text = nil,
	placeholder = "Enter default tags",
	editable = true
}
dt.preferences.register("module_HDRMerge", "add_tags",	-- name
	"string",	-- type
	'HDRMerge: Defualt additional tags',	-- label
	'Changes DEFAULT entry in the additional tags option. Requires restart to take effect.',	-- tooltip
	"",	-- default
	entry_widget_tags
) 
entry_widget_style = dt.new_widget("entry"){
	tooltip = "Enter the style name exactly as it is",
	text = nil,
	placeholder = "Enter Style name",
	editable = true
}
dt.preferences.register("module_HDRMerge", "style",	-- name
	"string",	-- type
	'HDRMerge: Defualt Style',	-- label
	'Changes DEFAULT entry in the Style option. Requires restart to take effect.',	-- tooltip
	"",	-- default
	entry_widget_style
) 
dt.preferences.register("module_HDRMerge", "copy_tags",	-- name
	"bool",	-- type
	'HDRMerge: Copy tags from first image by default',	-- label
	'Changes DEFAULT selection for Copy Tags, Requires restart to take effect.',	-- tooltip
	true	-- default
) 
dt.preferences.register("module_HDRMerge", "preview_size",	-- name
	"enum",	-- type
	'HDRMerge: Default DNG Preview Size',	-- label
	"Change the DEFAULT preview size. Requires restart to take effect.",	-- tooltip
	"half",	-- default
	"full", "none"	--values
)
dt.preferences.register("module_HDRMerge", "bits_per_sample",	-- name
	"enum",	-- type
	'HDRMerge: Default Bits Per Sample',	-- label
	'Change the DEFAULT bit depth. Requires restart to take effect.',	-- tooltip
	"16",	-- default
	"24","32"	--value
)
executable = "hdrmerge"
bin_path = df.get_executable_path_preference(executable)
if not bin_path then 
	bin_path = ""
end
path_widget = dt.new_widget("file_chooser_button"){
	title = "Select HDRMerge[.exe] file",
	value = bin_path,
	is_directory = false,
}
dt.preferences.register("module_HDRMerge", "bin_path",	-- name
	"file",	-- type
	'HDRMerge: Binary Location',	-- label
	'Install location of HDRMerge[.exe]. Requires restart to take effect.',	-- tooltip
	"hdrmerge",	-- default
	path_widget
)
