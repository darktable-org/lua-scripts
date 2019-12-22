--[[

	DESCRIPTION
    ext_editor.lua - edit images with external editors - for Windows only at the moment

    This script provides helpers to edit image files with programs external to darktable.
	It adds:
		-	a new target storage "collection". Image exported will be reimported to collection for
			further edit with external programs
		-	a new lighttable module "external editors", to select a program from a list of up to
		-	9 external editors and run it on a selected image
		-	a set of lua preferences in order to configure name and path of up to 9 external editors
		-	a set of lua shortcuts in order to quick launch the external editors
		
	USAGE
    * require this script from main lua file
	
	* in "preferences / lua options" configure name and path of external programs
	* in "preferences / shortcuts / lua" configure shortcuts for external programs (optional)
		
    * in the export dialog choose "collection" and select the format and bit depth for the
      exported image
    * press "export"
	* the exported image will be imported into collection and grouped with the original image
    
	* select an image for editing with en external program
		* in lighttable / external editors, select program and press "edit"
		* edit the image with the external editor, overwite the file, quit the external program
		* the selected image will be updated
		or
		* in lighttable / external editors, select program and press "edit a copy"
		* edit the image with the external editor, overwite the file, quit the external program
		* a copy of the selected image will be created and updated
		or
		* in lighttable select target storage "collection"
		* enter in darkroom
		* to create an export or a copy press CRTL+E
		* use the shortcut to edit the current image with the corresponding external editor
		* overwite the file, quit the external program
		* the darkroom view will be updated
	
	* warning: mouseover on lighttable / filmstrip will prevail on current image
	* this is the default DT behavior, not a bug of this script

    CAVEATS
    * currently developed and tested only for Windows
	
	TODO
	* localization
	* check min API version
	* support other OS
	* buttons are not equal in size and centered
	
    BUGS, COMMENTS, SUGGESTIONS
    * send to Marco Carrarini, marco.carrarini@gmail.com

    CHANGES
    * 20191220 - initial version, PR done
	* 20191221 - reworked, cleaned, added "copy and edit"
	* 20191222 - added darkroom mode
	
]]


local dt = require "darktable"
local df = require "lib/dtutils.file"
local dtsys = require "lib/dtutils.system"


-- executables of the external editors
local program_paths = {
	[1] = dt.preferences.read("ext_editor","program_path_1", "string"),
	[2] = dt.preferences.read("ext_editor","program_path_2", "string"),
	[3] = dt.preferences.read("ext_editor","program_path_3", "string"),
	[4] = dt.preferences.read("ext_editor","program_path_4", "string"),
	[5] = dt.preferences.read("ext_editor","program_path_5", "string"),
	[6] = dt.preferences.read("ext_editor","program_path_6", "string"),
	[7] = dt.preferences.read("ext_editor","program_path_7", "string"),
	[8] = dt.preferences.read("ext_editor","program_path_8", "string"),
	[9] = dt.preferences.read("ext_editor","program_path_9", "string")
	}


-- friendly name of the external editors
local program_names = {
	[1] = dt.preferences.read("ext_editor","program_name_1", "string"),
	[2] = dt.preferences.read("ext_editor","program_name_2", "string"),
	[3] = dt.preferences.read("ext_editor","program_name_3", "string"),
	[4] = dt.preferences.read("ext_editor","program_name_4", "string"),
	[5] = dt.preferences.read("ext_editor","program_name_5", "string"),
	[6] = dt.preferences.read("ext_editor","program_name_6", "string"),
	[7] = dt.preferences.read("ext_editor","program_name_7", "string"),
	[8] = dt.preferences.read("ext_editor","program_name_8", "string"),
	[9] = dt.preferences.read("ext_editor","program_name_9", "string")
	}


-- last used editor
if not (dt.preferences.read("ext_editor","initialized", "bool")) then
	dt.preferences.write("ext_editor","lastchoice", "integer", 1)
	dt.preferences.write("ext_editor","initialized", "bool", true)
	end
local lastchoice = dt.preferences.read("ext_editor","lastchoice", "integer")


-- group image with leader image
local function group_if_not_member(img, new_img)
	local image_table = img:get_group_members()
	local is_member = false
	for _,image in ipairs(image_table) do
		if image.filename == new_img.filename then
			is_member = true
			end
		end
	if not is_member then
		new_img:group_with(img.group_leader)
		end
	end


-- shows export progress
local function show_status(storage, image, format, filename,
	number, total, high_quality, extra_data)
    dt.print(string.format("Exporting Image %i/%i ...", number, total))
	end


-- callback for button "edit"
local function OpenWith(images, choice)
		
	if #images == 1 then
		for _, image in pairs(images) do 
			
			-- image to be edited
			name = image.path.."\\"..image.filename 					
			
			-- launch the external editor
			local run_cmd = '"'..program_paths[choice]..'" "'..name..'"' 
			dt.print("Launching "..program_names[choice].."...")	
			dtsys.external_command(run_cmd)
			
			-- refresh the image view
			-- note that only image:drop_cache() is not enough to refresh view in darkroom mode
			-- therefore image must be deleted and reimported to force refresh
			
			local image_leader = image.group_leader
			image:delete ()
			local new_image = dt.database.import(name)
			new_image:group_with(image_leader)

			-- copy tags from image leader
			for _,tag in pairs(dt.tags.get_tags(image_leader)) do
				if not (string.sub(tag.name,1,9) == "darktable") then
					dt.tags.attach(tag, new_image)
					end
				end
			
			-- remember the last editor used
			dt.preferences.write("ext_editor","lastchoice", "integer", choice)
			
			-- refresh darkroom view
			if dt.gui.current_view () == dt.gui.views.darkroom then
				dt.gui.views.darkroom.display_image(new_image)
				end
			end
	else
		dt.print('please select one image')
		end
		
	end


-- callback for button "copy and edit"
local function CopyAndOpenWith(images, choice)
	
	if #images == 1 then
		for _,image in pairs(images) do 
			
			-- image to be copied and edited
			local name = image.path.."\\"..image.filename
			local new_name = name
			
			-- create unique filename
			while df.check_if_file_exists(new_name) do
				new_name = df.filename_increment(new_name)
				end
			
			-- limit to 99 more exports of the original export
			if string.match(df.get_basename(new_name), "_(d-)$") == "99" then
					break
				end
				
			-- physical copy
			local result = df.file_copy(name, new_name)
			
			if result then
				-- launch the external editor
				local run_cmd = '"'..program_paths[choice]..'" "'..new_name..'"'  	
				dt.print("Launching "..program_names[choice].."...")	
				dtsys.external_command(run_cmd)
				
				-- import in database and group
				local new_image = dt.database.import(new_name)
				group_if_not_member(image, new_image)
				
				-- copy image tags
				for _,tag in pairs(dt.tags.get_tags(image)) do
					if not (string.sub(tag.name,1,9) == "darktable") then
						dt.tags.attach(tag, new_image)
						end
					end
				
				-- remember the last editor used
				dt.preferences.write("ext_editor","lastchoice", "integer", choice)
				end	
			end
	else
		dt.print('please select one image')
		end
		
		
	end


-- callback function for shortcuts
local function program_shortcut(event, shortcut)
	local choice = tonumber(string.sub(shortcut, -1))
	OpenWith(dt.gui.action_images, choice)
	end


-- export images and reimport in collection
local function export2collection(storage, image_table, extra_data) 

	for image, temp_name in pairs(image_table) do

		-- images are first exported in temp folder
		-- create unique filename
		local new_name = image.path .."\\"..df.get_filename(temp_name)
		while df.check_if_file_exists(new_name) do
			new_name = df.filename_increment(new_name)
			
			-- limit to 99 more exports of the original export
			if string.match(df.get_basename(new_name), "_(d-)$") == "99" then
					break
				end
			end

		-- image moved to collection folder
		local result = df.file_move(temp_name, new_name)

		if result then
			-- import in database and group
			local new_image = dt.database.import(new_name)
			group_if_not_member(image, new_image)
			end
		end
	end


-- combobox
local combobox = dt.new_widget("combobox")
	{
	label = "choose program", 
	tooltip = "select the external editor from the list",
	value = lastchoice, -- remember status,
	program_names[1],
	program_names[2],
	program_names[3],
	program_names[4],
	program_names[5],
	program_names[6],
	program_names[7],
	program_names[8],
	program_names[9]
	}


-- button edit
local button1 = dt.new_widget("button")
	{
	label = "       edit        ",
	tooltip = "open the selected image in external editor",
	dt_lua_align_t = center,
	clicked_callback = function (_)
		local choice = combobox.selected
		OpenWith(dt.gui.action_images, choice)
		end
	}


-- button edit a copy
local button2 = dt.new_widget("button")
	{
	label = " edit a copy ",
	tooltip = "create a copy of the selected image and open it in external editor",
	clicked_callback = function (_)
		local choice = combobox.selected
		CopyAndOpenWith(dt.gui.action_images, choice)
		end
	}


-- box for the two buttons
local box1 = dt.new_widget ("box") {
    orientation = "horizontal",
	button1,
	button2
}


-- register new lighttable module
dt.register_lib(
	"ext_editor",        -- module name
	"external editors",  -- name
	true,                -- expandable
	false,               -- resetable
	{[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},  
	dt.new_widget("box") -- widget
	{
    orientation = "vertical",
    combobox,
	box1
	},
	nil,-- view_enter
	nil -- view_leave
	)


-- register new storage
dt.register_storage("exp2coll", "collection", show_status, export2collection)


-- register the new preferences
dt.preferences.register("ext_editor","program_path_9", "string","path to external editor 9", "path to external editor","")
dt.preferences.register("ext_editor","program_name_9", "string","name of external editor 9", "name of external editor","")

dt.preferences.register("ext_editor","program_path_8", "string","path to external editor 8", "path to external editor","")
dt.preferences.register("ext_editor","program_name_8", "string","name of external editor 8", "name of external editor","")

dt.preferences.register("ext_editor","program_path_7", "string","path to external editor 7", "path to external editor","")
dt.preferences.register("ext_editor","program_name_7", "string","name of external editor 7", "name of external editor","")

dt.preferences.register("ext_editor","program_path_6", "string","path to external editor 6", "path to external editor","")
dt.preferences.register("ext_editor","program_name_6", "string","name of external editor 6", "name of external editor","")

dt.preferences.register("ext_editor","program_path_5", "string","path to external editor 5", "path to external editor","")
dt.preferences.register("ext_editor","program_name_5", "string","name of external editor 5", "name of external editor","")

dt.preferences.register("ext_editor","program_path_4", "string","path to external editor 4", "path to external editor","")
dt.preferences.register("ext_editor","program_name_4", "string","name of external editor 4", "name of external editor","")

dt.preferences.register("ext_editor","program_path_3", "string","path to external editor 3", "path to external editor","")
dt.preferences.register("ext_editor","program_name_3", "string","name of external editor 3", "name of external editor","")

dt.preferences.register("ext_editor","program_path_2", "string","path to external editor 2", "path to external editor","")
dt.preferences.register("ext_editor","program_name_2", "string","name of external editor 2", "name of external editor","")

dt.preferences.register("ext_editor","program_path_1", "string","path to external editor 1", "path to external editor","")
dt.preferences.register("ext_editor","program_name_1", "string","name of external editor 1", "name of external editor","")


-- register the new shortcuts	
dt.register_event("shortcut", program_shortcut, "edit with program 1") 
dt.register_event("shortcut", program_shortcut, "edit with program 2") 
dt.register_event("shortcut", program_shortcut, "edit with program 3") 
dt.register_event("shortcut", program_shortcut, "edit with program 4") 
dt.register_event("shortcut", program_shortcut, "edit with program 5") 
dt.register_event("shortcut", program_shortcut, "edit with program 6") 
dt.register_event("shortcut", program_shortcut, "edit with program 7") 
dt.register_event("shortcut", program_shortcut, "edit with program 8") 
dt.register_event("shortcut", program_shortcut, "edit with program 9") 

-- end of script

-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: hl Lua;
