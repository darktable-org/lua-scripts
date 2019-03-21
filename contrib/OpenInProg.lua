--[[OpenInProg plugin for darktable

  copyright (c) 2019  Kevin Ertel
  
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
This plugin adds an easy way for users to configure programs, which images can then be "opened" in or "exported" to. With the behavior being as such:
Open All In - will attempt to open the source files select in the specified programs (useful when you want to edit the RAW file without any of dt's history stack applied)
Open Each In - will issue a sperate open command for each image, potentially launching mulitple instances of the program, with a different image loaded in each instance
Export To - will export the selected images via dt's export functionality, then attempt to open those exported images in the specified program (useful for programs like Hugin which cannot open RAW files)

----REQUIRED SOFTWARE----
External programs

----USAGE----
Install: (see here for more detail: https://github.com/darktable-org/lua-scripts )
 1) Copy this file in to your "lua/contrib" folder where all other scripts reside. 
 2) Require this file in your luarc file, as with any other dt plug-in: require "contrib/OpenInProg"
On the initial startup go to darktable settings > lua options and set your executable paths and other preferences, then restart darktable

]]

local dt = require "darktable"
local df = require "lib/dtutils.file"
local dsys = require "lib/dtutils.system"
local du = require "lib/dtutils"
local mod = 'module_OpenInProg'
local os_path_separator = '/'
if dt.configuration.running_os == 'windows' then os_path_separator = '\\' end
du.check_min_api_version("5.0.0", "enfuseAdvanced") 
local temp
local programs = {}
local index = {}
local GUI = {} -- only contains gui elements that are NOT tied to a specific program

GUI.show_programs = {}

local function NewProgram(index) -- creates a new program object and initializes it with values found in preferences for the program specified by index, generate all gui elements for that program as well
	local this = { --initialize all elements
		name = '',
		bin = '',
		first_run = true,
		install_error = false,
		open_all_created = false,
		open_each_created = false,
		export_all_created = false,
		arg_string = '',
		images_string = '',
		args = {},
		GUI = {
			name = {},
			change_name = {},
			bin = {},
			open_all = {},
			open_each = {},
			export_all = {},
			enable = {},
			box = {},
			temp_loc = {},
			source_loc = {},
		}
	}
	
	function this:manage_sensitivity() --to ensure all options are stored to the appropriate preference lock out all options until the name is saved. if the name is changed update all preferences with the new name, also update the stack list chooser
		local sense = false
		temp = self.GUI.name.text
		temp = string.gsub(temp, ' ', '')
		local name_is_valid = #temp >= 1
		name_is_valid = name_is_valid and not string.match(temp,'^program')
		if self.GUI.change_name.label == 'change name' then --user requested to change program name, lock all other controls
			sense = false
			self.GUI.change_name.label = 'save name'
		elseif name_is_valid then --user requested to save new name and the new name is valid, update name, save all settings to pref with new name, update the program chooser list, unlock all other controls
			sense = true
			self.GUI.change_name.label = 'change name'
			self.name = self.GUI.name.text
			dt.preferences.write(mod, 'prog'..index, 'string', self.name)
			dt.preferences.write(mod, self.name..'bin', 'string', self.GUI.bin.value)
			dt.preferences.write(mod, self.name..'openAll', 'bool', self.GUI.open_all.value)
			dt.preferences.write(mod, self.name..'openEach', 'bool', self.GUI.open_each.value)
			dt.preferences.write(mod, self.name..'exportAll', 'bool', self.GUI.export_all.value)
			dt.preferences.write(mod, self.name..'enable', 'bool', self.GUI.enable.value)
			dt.preferences.write(mod, self.name..'loc', 'string', self.GUI.temp_loc.value)
			dt.preferences.write(mod, self.name..'source', 'bool', self.GUI.source_loc.value)
			GUI.show_programs[index] = self.name
		else --user requested to save a new name which is not valid
			sense = false
			dt.print('new name is not valid')
		end
		self.GUI.name.editable = not sense
		self.GUI.bin.sensitive = sense
		self.GUI.open_all.sensitive = sense
		self.GUI.open_each.sensitive = sense
		self.GUI.export_all.sensitive = sense
		self.GUI.enable.sensitive = sense
		self.GUI.temp_loc.sensitive = sense
		self.GUI.source_loc.sensitive = sense
	end
	
	local temp = dt.preferences.read(mod, 'prog'..index, 'string')
	local name_existed = false
	if (temp and temp ~= '') then
		this.name = temp
		name_existed = true
	else
		this.name = 'program '..index
	end
	this.GUI.name = dt.new_widget('entry'){
		text = this.name,
		placeholder = '',
		editable = true
	}
	
	this.GUI.change_name = dt.new_widget('button'){
		label = 'save name',
		clicked_callback = function() this:manage_sensitivity() end
	}
	
	temp = dt.preferences.read(mod, this.name..'bin', 'string')
	this.GUI.bin = dt.new_widget('file_chooser_button'){
		title = this.name..' binary path',
		value = temp,
		tooltip = temp,
		is_directory = false,
		sensitive = false,
		changed_callback = function(self)
			dt.preferences.write(mod, this.name..'bin', 'string', self.value)
			self.tooltip = self.value
		end
	}
	
	this.GUI.open_all = dt.new_widget('check_button'){
		label = 'create "open all" button', 
		value = dt.preferences.read(mod, this.name..'openAll', 'bool'),
		tooltip ='create a button that will enable the "open all" behavior for specified program',
		sensitive = false,
		clicked_callback = function(self) 
			dt.preferences.write(mod, this.name..'openAll', 'bool', self.value) 
		end,
		reset_callback = function(self) self.value = false end
	}

	this.GUI.open_each = dt.new_widget('check_button'){
		label = 'create "open each" button', 
		value = dt.preferences.read(mod, this.name..'openEach', 'bool'),
		tooltip ='create a button that will enable the "open each" behavior for specified program',
		sensitive = false,
		clicked_callback = function(self) 
			dt.preferences.write(mod, this.name..'openEach', 'bool', self.value) 
		end,
		reset_callback = function(self) self.value = false end
	}
	
	this.GUI.export_all = dt.new_widget('check_button'){
		label = 'create "export all" button', 
		value = dt.preferences.read(mod, this.name..'exportAll', 'bool'),
		tooltip ='create a button that will enable the "export all" behavior for specified program',
		sensitive = false,
		clicked_callback = function(self) 
			dt.preferences.write(mod, this.name..'exportAll', 'bool', self.value) 
		end,
		reset_callback = function(self) self.value = false end
	}
		
	this.GUI.enable = dt.new_widget('check_button'){
		label = 'enable',
		value = dt.preferences.read(mod, this.name..'enable', 'bool'),
		tooltip = 'generate this programs specified actions on startup or when generate is clicked',
		sensitive = false,
		clicked_callback = function(self) 
			dt.preferences.write(mod, this.name..'enable', 'bool', self.value) 
		end,
		reset_callback = function(self) self.value = false end
	}	
	
	this.GUI.box = dt.new_widget('box'){
		orientation = 'vertical',
		this.GUI.name,
		this.GUI.change_name,
		this.GUI.bin,
		this.GUI.open_all,
		this.GUI.open_each,
		this.GUI.export_all,
		this.GUI.enable
	}
	
	temp = dt.preferences.read(mod, this.name..'loc', 'string')
	this.GUI.temp_loc = dt.new_widget('file_chooser_button'){
		title = 'title',
		value = temp,
		tooltip = temp,
		is_directory = true,
		sensitive = false,
		changed_callback = function(self)
			self.tooltip = self.value
			dt.preferences.write(mod, this.name..'loc', 'string', self.value)
		end
	}
	
	this.GUI.source_loc = dt.new_widget('check_button'){
		label = 'save to source location',
		value = dt.preferences.read(mod, this.name..'source', 'bool'),
		tooltip ='generate this programs specified actions on startup or when generate is clicked',
		sensitive = false,
		clicked_callback = function(self) 
			dt.preferences.write(mod, this.name..'source', 'bool', self.value) 
		end,
		reset_callback = function(self) self.value = false end
	}
	
	if name_existed then this:manage_sensitivity() end --if a valid program name was found at startup then unlock the controls
	
	return this
end

GUI.stack = dt.new_widget('stack'){}

GUI.s_label = dt.new_widget('section_label'){
	label = 'program options'
}

GUI.show_programs = dt.new_widget('combobox'){
    label = "show program",
    tooltip = "show options for specified program",
    changed_callback = function(self)
        GUI.stack.active = self.selected
    end 
}

GUI.qty_prog_entry = dt.new_widget('entry'){
	text = dt.preferences.read(mod, 'qty_programs', 'integer'),
	placeholder = '',
	editable = true
}

local function UpdateProgramList() -- updates the stack to contain only the number of programs specified, updates program chooser list as well
	local temp = #programs
	local qty_programs = tonumber(GUI.qty_prog_entry.text)
	dt.preferences.write(mod, 'qty_programs', 'integer', qty_programs)
	if temp < qty_programs then --add programs
		for j = (temp + 1), qty_programs, 1 do
			table.insert(programs, NewProgram(j))
			GUI.stack[j] = programs[j].GUI.box
			GUI.show_programs[j] = programs[j].name
		end
	elseif temp > qty_programs then --remove programs
		for j = temp, qty_programs+1, -1 do
			table.remove(programs, j)
			GUI.stack[j] = nil
			GUI.show_programs[j] = nil
		end
	end
	for ind, prog in pairs(programs) do
		index[prog.name] = ind
		GUI.show_programs[ind] = programs[ind].name
	end
end

local function pre_call(prog) --checks if program exists (only on initial call), returns true if there is an install error
	if prog.first_run then
		prog.bin = df.check_if_bin_exists(prog.name)
		if not prog.bin then
			dt.print_error(prog.name..' not found')
			dt.print('ERROR - '..prog.name..' not found')
			prog.install_error = true
		end
		prog.first_run = false
	end
	return prog.install_error
end

local function build_execute_command(prog) --builds an executeion command from the appropriate fields in the input program object
	local result = false
	result = prog.bin
	if prog.arg_string ~= '' then
		result = result..' '..prog.arg_string
	end
	result = result..' '..prog.images_string
	return result
end

local function Func_OpenAll(ButtonText) --parses button text to determine what program object to use while executing, attempts to open all images in a single call
	local idx = index[string.sub(string.match(ButtonText, ': .*'), 3)]	--looks at button text to determine what button was pressed and it's associated program index
	if pre_call(programs[idx]) then
		dt.print('resolve install issue with '..programs[idx].name)
		return
	end
	
	dt.print('opening all in '..programs[idx].name)
	
	local images = dt.gui.selection()
	local curr_image = ""
	local images_to_open = ''
	
	for _,image in pairs(images) do 
		curr_image = image.path..os_path_separator..image.filename
		images_to_open = images_to_open..df.sanitize_filename(curr_image)..' '
	end
	programs[idx].images_string = images_to_open
	local run_cmd = build_execute_command(programs[idx])
	local resp = dsys.external_command(run_cmd)
	if resp ~= 0 then
		dt.print_error('an error occured while trying to open images in '..programs[idx].name)
	end
end

local function Func_OpenEach(ButtonText) --parses button text to determine what program object to use while executing, attempts to open each image in a unique call
	local idx = index[string.sub(string.match(ButtonText, ': .*'), 3)]
	if pre_call(programs[idx]) then
		dt.print('resolve install issue with '..programs[idx].name)
		return
	end
		
	dt.print('opening each in '..programs[idx].name)
	
	local images = dt.gui.selection()
	local curr_image = ''
	
	for _,image in pairs(images) do 
		curr_image = image.path..os_path_separator..image.filename
		curr_image = df.sanitize_filename(curr_image)
		programs[idx].images_string = curr_image
		local run_cmd = build_execute_command(programs[idx])
		local resp = dsys.external_command(run_cmd, true)
		if resp ~= 0 then
			dt.print_error('an error occured while trying to open images in '..programs[idx].name)
		end	
	end
end

local function Func_Export(storage, image_table, extra_data) --uses storage name to determine what program object to use while executing, attempts to export all images, move them to designated folder, then open those all in a single call
	local idx = index[storage.name]
	if pre_call(programs[idx]) then
		dt.print('resolve install issue with '..programs[idx].name)
		return
	end	

	if (programs[idx].GUI.temp_loc.value == nil or programs[idx].GUI.temp_loc.value == '') and not programs[idx].GUI.source_loc.value then   --Check that an output path is selected
		dt.print('ERROR: no target directory selected')
		return
	end
	dt.preferences.write(mod, programs[idx].name..'loc', 'string', programs[idx].GUI.temp_loc.value)
	dt.print("Opening exported images in "..programs[idx].name)
	local images_to_open = ''
	for source_image,temp_path in pairs(image_table) do
		local new_path = programs[idx].GUI.temp_loc.value
		if programs[idx].GUI.source_loc.value then new_path = source_image.path end
		new_path = new_path..os_path_separator..df.get_filename(temp_path)
		new_path = df.create_unique_filename(new_path)
		result = df.file_move(temp_path, new_path)
		images_to_open = images_to_open..df.sanitize_filename(new_path)..' '
	end
	programs[idx].images_string = images_to_open
	run_cmd = build_execute_command(programs[idx])
	resp = dsys.external_command(run_cmd, true)
end

local function show_status(storage, image, format, filename, number, total, high_quality, extra_data) --shows how many images are being exported
	dt.print('exporting '..tostring(number)..'/'..tostring(total))   
end

local function GenerateProgramControls() --generates user spcified controls for each program object that exists
	for ind, prog in ipairs(programs) do
		if prog.GUI.enable then
			if prog.GUI.open_all.value and not prog.open_all_created then
				prog.open_all_created = true
				dt.gui.libs.image.register_action(
					'open all in: '..prog.name,
					function(self)Func_OpenAll(self) end,
					'Opens all selected images in '..prog.name..' at once'
				)
			end
			if prog.GUI.open_each.value and not prog.open_each_created then
				prog.open_each_created = true
				dt.gui.libs.image.register_action(
					'open each in: '..prog.name,
					function(self) Func_OpenEach(self) end,
					'Opens each selected image in '..prog.name..' individually'
				)
			end
			if prog.GUI.export_all.value and not prog.export_all_created then
				prog.export_all_created = true
				dt.register_storage(
					'module_OpenInProg_'..prog.name, --Module name
					prog.name, --Name
					show_status, --store: called once per exported image
					Func_Export,  --finalize: called once when all images are exported and store calls completenil
					nil, --supported: 
					nil, --initialize: 
					dt.new_widget("box"){
						orientation = "vertical",
						prog.GUI.temp_loc,
						prog.GUI.source_loc
					}
				)
			end 
		end
	end
end

GUI.refresh = dt.new_widget('button'){
	label = 'refresh',
	tooltip = 'refresh list of programs available',
	clicked_callback = function() UpdateProgramList() end
}

GUI.generate = dt.new_widget('button'){
	label =  'generate controls',
	tooltip = 'generate buttons for all programs. If new programs have been added they will be generated now, if you have removed programs they will no longer appear after a restart of dt',
	clicked_callback = function() GenerateProgramControls() end
}

UpdateProgramList()
GenerateProgramControls()

dt.register_lib(
	mod,
	'Open In Program Configurator',
	true,
	false,
	{[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_LEFT_BOTTOM", 100}},
	dt.new_widget('box'){
		orientation = 'vertical',
		GUI.qty_prog_entry,
		GUI.refresh,
		GUI.show_programs,
		GUI.s_label,
		GUI.stack,
		GUI.generate
	},
	nil,
	nil
)
