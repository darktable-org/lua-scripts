--[[HDRMerge plugin for darktable

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

--[[About this Plugin
This plugin adds the module "HDRMerge" to darktable's lighttable view

----REQUIRED SOFTWARE----
HDRMerge ver. 4.5 or greater

----USAGE----
Install: (see here for more detail: https://github.com/darktable-org/lua-scripts )
 1) Copy this file in to your "lua/contrib" folder where all other scripts reside. 
 2) Require this file in your luarc file, as with any other dt plug-in
On the initial startup go to darktable settings > lua options and set your executable paths and other preferences, then restart darktable

Select bracketed images and press the Run HDRMerge button. The resulting DNG will be auto-imported into darktable.
Additional tags or style can be applied on auto import as well, if you desire.

Base Options:
Select your desired BPS (bits per sample and Embedded Preview Size. 

Batch Options:
Select if you want to run in batch mode or not
Select the gap, in seconds, between images for auto grouping in batch mode

See HDRMerge manual for further detail: http://jcelaya.github.io/hdrmerge/documentation/2014/07/11/user-manual.html

Auto-import Options:
Select a style, whether you want tags to be copied from the original, and any additional tags you desire added when the new image is auto-imported
]]

local dt = require "darktable"
local df = require "lib/dtutils.file"
local dsys = require "lib/dtutils.system"
local mod = 'module_HDRMerge'
local os_path_seperator = '/'
if dt.configuration.running_os == 'windows' then os_path_seperator = '\\' end

dt.preferences.register("executable_paths", "HDRMerge",	-- name
	"file",	-- type
	'HDRMerge: binary location',	-- label
	'Install location of HDRMerge. Requires restart to take effect.',	-- tooltip
	"HDRMerge"	-- default
)
local temp
local HDRM = {
	name = 'HDRMerge',
	bin = '',
	first_run = true,
	install_error = false,
	arg_string = '',
	images_string = '',
	args = {
		bps			={text = '-b ', style = 'integer'},
		size		={text = '-p ', style = 'string'},
		batch		={text = '-B ', style = 'bool'},
		gap			={text = '-g ', style = 'integer'}
	}
}
local GUI = {
	HDR = {
		bps 		={},
		size		={},
		batch		={},
		gap			={}
	},
	Target = {
		style		={},
		copy_tags	={},
		add_tags	={}
	},
	run = {}
}

--Detect User Styles--
local styles = dt.styles
local styles_count = 1 -- "none" = 1
for _,i in pairs(dt.styles) do
	if type(i) == "userdata" then styles_count = styles_count + 1 end
end

local function InRange(test, low, high) --tests if test value is within range of low and high (inclusive)
	if test >= low and test <= high then
		return true
	else
		return false
	end
end

local function GetFileName(full_path)
	--[[Parses a full path (path/filename_identifier.extension) into individual parts
	Input: Folder1/Folder2/Folder3/Img_0001.CR2
	
	Returns:
	path: Folder1/Folder2/Folder3/
	filename: Img_0001
	identifier: 0001
	extension: .CR2
	
	EX:
	path_1, file_1, id_1, ext_1 = GetFileName(full_path_1)
	]]
	local path = string.match(full_path, ".*[\\/]")
	local filename = string.gsub(string.match(full_path, "[%w-_]*%.") , "%." , "" ) 
	local identifier = string.match(filename, "%d*$")
	local extension = string.match(full_path, "%.%w*")
    return path, filename, identifier, extension
end

local function CleanSpaces(text) --removes spaces from the front and back of the passed in text string
	front = string.match(text, '^%s')
	back = string.match(text, '%s$')
	if front then 
		text = string.sub(text,2)
	end
	if back then
		text = string.sub(text,1,-2)
	end
	return text
end

local function BuildExecuteCmd(prog_table)
	local result = prog_table.bin..' '..prog_table.arg_string..' '..prog_table.images_string
	return result
end

local function PreCall(prog_tbl)
	for _,prog in pairs(prog_tbl) do
		if prog.first_run then
			prog.bin = df.check_if_bin_exists(prog.name)
			if not prog.bin then 
				prog.install_error = true
			else
				prog.bin = CleanSpaces(prog.bin)
			end
			prog.first_run = false
		end
	end
end

local function UpdateActivePreference()
	temp = GUI.HDR.gap.value
	dt.preferences.write(mod, 'active_gap', 'integer', temp)
	temp = GUI.Target.add_tags.text
	dt.preferences.write(mod, 'active_add_tags', 'string', temp)
end

local function HDRMerge_main()
	PreCall({HDRM})
	if HDRM.install_error then
		dt.print_error('HDRMerge install issue, please ensure the binary path is proper')
		return
	end
	images = dt.gui.selection()
	local count = 0
	for _,image in pairs(images) do
		count = count + 1
	end
	if count < 2 then
		dt.print_error('not enough images selected, select at least 2 images to merge')
		return
	end
	
	UpdateActivePreference()
	
	--create image string and output path
	HDRM.images_string = ''
	local out_path = ''
	local smallest_id = math.huge
	local smallest_name = ''
	local largest_id  = 0
	local source_raw = {}
	for _,image in pairs(images) do
		local curr_image = image.path..os_path_seperator..image.filename
		HDRM.images_string = HDRM.images_string..df.sanitize_filename(curr_image).." "
		out_path = image.path
		_, source_name, source_id = GetFileName(image.filename)
		source_id = tonumber(source_id)
		if source_id < smallest_id then 
			smallest_id = source_id
			smallest_name = source_name
			source_raw = image
		end
		if source_id > largest_id then largest_id = source_id end
	end
	HDRM.images_string = CleanSpaces(HDRM.images_string)
	out_path = out_path..os_path_seperator..smallest_name..'-'..largest_id..'.dng'
	out_path = df.create_unique_filename(out_path)
	
	--create argument string
	HDRM.arg_string = HDRM.args.bps.text..GUI.HDR.bps.value..' '..HDRM.args.size.text..GUI.HDR.size.value..' '
	if GUI.HDR.batch.value then 
		HDRM.arg_string = HDRM.arg_string..HDRM.args.batch.text..HDRM.args.gap.text..math.floor(GUI.HDR.gap.value)..' -a'
	else
		HDRM.arg_string = HDRM.arg_string..'-o '..df.sanitize_filename(out_path)
	end
	HDRM.arg_string = CleanSpaces(HDRM.arg_string)
	
	-- create run command and execute
	local run_cmd = BuildExecuteCmd(HDRM)
	resp = dsys.external_command(run_cmd)
	
	if resp == 0 and not GUI.HDR.batch.value then
		local imported = dt.database.import(out_path)
		if GUI.Target.style.selected > 1 then
			local set_style = styles[GUI.Target.style.selected - 1]
			dt.styles.apply(set_style , imported)
		end
		if GUI.Target.copy_tags.value then
			local all_tags = dt.tags.get_tags(source_raw) 
			for _,tag in pairs(all_tags) do
				if string.match(tag.name, 'darktable|') == nil then dt.tags.attach(tag, imported) end
			end
		end
		local set_tag = GUI.Target.add_tags.text
		if set_tag ~= nil then
			for tag in string.gmatch(set_tag, '[^,]+') do
				tag = CleanSpaces(tag)
				tag = dt.tags.create(tag)
				dt.tags.attach(tag, imported) 
			end
		end
	else
		dt.print_error('HDRMerge failed')
	end

end

local lbl_hdr = dt.new_widget('section_label'){
	label = 'HDRMerge options'
}
temp = dt.preferences.read(mod, 'active_bps_ind', 'integer')
if not InRange(temp, 1, 3) then temp = 3 end 
GUI.HDR.bps = dt.new_widget('combobox'){
	label = 'bits per sample', 
	tooltip ='number of bits per sample in the output image',
	selected = temp,
	'16','24','32',             
	changed_callback = function(self)
		dt.preferences.write(mod, 'active_bps', 'integer', self.value) 
		dt.preferences.write(mod, 'active_bps_ind', 'integer', self.selected)
	end,
	reset_callback = function(self) 
		self.selected = 3
		dt.preferences.write(mod, 'active_bps', 'integer', self.value) 
		dt.preferences.write(mod, 'active_bps_ind', 'integer', self.selected)
	end
} 
temp = dt.preferences.read(mod, 'active_size_ind', 'integer')
if not InRange(temp, 1, 3) then temp = 2 end 
GUI.HDR.size = dt.new_widget('combobox'){
	label = 'embedded preview size', 
	tooltip ='size of the embedded preview in output image',
	selected = temp,
	'none','half','full',             
	changed_callback = function(self)
		dt.preferences.write(mod, 'active_size', 'string', self.value) 
		dt.preferences.write(mod, 'active_size_ind', 'integer', self.selected)
	end,
	reset_callback = function(self) 
		self.selected = 2
		dt.preferences.write(mod, 'active_size', 'string', self.value) 
		dt.preferences.write(mod, 'active_size_ind', 'integer', self.selected)
	end
} 
GUI.HDR.batch = dt.new_widget('check_button'){
	label = 'batch mode',
	value = dt.preferences.read(mod, 'active_batch', 'bool'),
	tooltip = 'enable batch mode operation \nNOTE: resultant files will NOT be auto-imported',
	clicked_callback = function(self)
		dt.preferences.write(mod, 'active_batch', 'bool', self.value)
		GUI.HDR.gap.sensitive = self.value
	end,
	reset_callback = function(self) self.value = false end
}
temp = dt.preferences.read(mod, 'active_gap', 'integer')
if not InRange(temp, 1, 3600) then temp = 3 end
GUI.HDR.gap = dt.new_widget('slider'){
	label = 'batch gap [sec.]',
	tooltip = 'gap, in seconds, between batch mode groups',
	soft_min = 1,
	soft_max = 30,
	hard_min = 1,
	hard_max = 3600,
	step = 1,
	digits = 0,
	value = temp,
	sensitive = GUI.HDR.batch.value,
	reset_callback = function(self) 
		self.value = 3
	end
}
local lbl_import = dt.new_widget('section_label'){
	label = 'import options'
}
GUI.Target.style = dt.new_widget('combobox'){
	label = 'apply style on import',
	tooltip = "Apply selected style on auto-import to newly created image",
	selected = 1,
	"none",
	changed_callback = function(self)
		dt.preferences.write(mod, 'active_style', 'string', self.value) 
		dt.preferences.write(mod, 'active_style_ind', 'integer', self.selected)
	end,
	reset_callback = function(self) 
		self.selected = 1
		dt.preferences.write(mod, 'active_style', 'string', self.value) 
		dt.preferences.write(mod, 'active_style_ind', 'integer', self.selected)
	end	
}
for k=1, (styles_count-1) do
	GUI.Target.style[k+1] = styles[k].name
end
temp = dt.preferences.read(mod, 'active_style_ind', 'integer')
if not InRange(temp, 1, styles_count) then temp = 1 end
GUI.Target.style.selected = temp
GUI.Target.copy_tags = dt.new_widget('check_button'){
	label = 'copy tags',
	value = dt.preferences.read(mod, 'active_copy_tags', 'bool'),
	tooltip = 'copy tags from first source image',
	clicked_callback = function(self) dt.preferences.write(mod, 'active_copy_tags', 'bool', self.value) end,
	reset_callback = function(self) self.value = true end
}
temp = dt.preferences.read(mod, 'active_add_tags', 'string')
if temp == '' then temp = nil end 
GUI.Target.add_tags = dt.new_widget("entry"){
	tooltip = "Additional tags to be added on import. Seperate with commas, all spaces will be removed",
	text = temp,
	placeholder = "Enter tags, seperated by commas",
	editable = true
}
GUI.run = dt.new_widget("button"){
	label = 'merge',
	tooltip ='run HDRMerge with the above specified settings',
	clicked_callback = function() HDRMerge_main() end
}
dt.register_lib(
	"HDRMerge_Lib",	-- Module name
	"HDRMerge",	-- name
	true,	-- expandable
	true,	-- resetable
	{[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 99}},	-- containers
	dt.new_widget("box"){
		orientation = "vertical",
		lbl_hdr,
		GUI.HDR.bps,
		GUI.HDR.size,
		GUI.HDR.batch,
		GUI.HDR.gap,
		lbl_import,
		GUI.Target.style,
		GUI.Target.copy_tags,
		GUI.Target.add_tags,
		GUI.run
		}
)

