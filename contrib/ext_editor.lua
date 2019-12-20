--[[

	DESCRIPTION
    ext_editor.lua - edit images with external editors - for Windows only at the moment

    This script provides helpers to edit image files with programs extenal to darktable.
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
	* in lighttable / external editors, select program and press "edit with external program"
    * edit the image with the external editor, overwite the file, quit the external program
    * lighttable will be updated

    CAVEATS
    * currently developed and tested only for Windows

    BUGS, COMMENTS, SUGGESTIONS
    * send to Marco Carrarini, marco.carrarini@gmail.com

    CHANGES
    * 20191220 - initial version
	
]]

local dt = require "darktable"
local df = require "lib/dtutils.file"
local dtsys = require "lib/dtutils.system"

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

local programs = {
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

local names = {
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

if not (dt.preferences.read("ext_editor","initialized", "bool")) then
	dt.preferences.write("ext_editor","lastchoice", "integer", 1)
	dt.preferences.write("ext_editor","initialized", "bool", true)
	end

local lastchoice = dt.preferences.read("ext_editor","lastchoice", "integer")

local combobox = dt.new_widget("combobox")
	{
	label = "choose program", 
	value = lastchoice, -- remember status,
	names[1],
	names[2],
	names[3],
	names[4],
	names[5],
	names[6],
	names[7],
	names[8],
	names[9]
	}


local function OpenWith(choice)
	
	local images = dt.gui.selection()
	local curr_image = ""
	
	if #images == 1 then
		for _,image in pairs(images) do 
			curr_image = image.path.."\\"..image.filename 					
			local run_cmd = '"'..programs[choice]..'" "'..curr_image..'"'  	--additional quotes for spaces in filename
			dt.print("Launching "..names[choice].."...")	
			dtsys.external_command(run_cmd)
			--image:drop_cache()  *** it doesn't work! why ? Delete and Import instead ***
			image:delete()
			local myimage = dt.database.import(curr_image)
			dt.preferences.write("ext_editor","lastchoice", "integer", choice)
			end
	else
		dt.print('please select one image')
		end
		
	end

local button1 = dt.new_widget("button")
	{
	label = "edit with external program",
	clicked_callback = function (_)
		local choice = combobox.selected
		OpenWith(choice)
		end
	}


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


local function show_status(storage, image, format, filename,
	number, total, high_quality, extra_data)
    dt.print(string.format(_("Export Image %i/%i"), number, total))
	end


local function export2collection(storage, image_table, extra_data) 

	--	list of exported images
	local img_list

	--	reset and create image list
	img_list = ""

	for _,exp_img in pairs(image_table) do
		exp_img = df.sanitize_filename(exp_img)
		img_list = img_list ..exp_img.. " "
		end
		
--[[
	for each of the image, exported image pairs
	move the exported image into the directory with the original
	then import the image into the database which will group it with the original
	and then copy over any tags other than darktable tags
]]
	for image,exported_image in pairs(image_table) do

		local myimage_name = image.path .. "/" .. df.get_filename(exported_image)

		while df.check_if_file_exists(myimage_name) do
			myimage_name = df.filename_increment(myimage_name)
			-- limit to 99 more exports of the original export
			if string.match(df.get_basename(myimage_name), "_(d-)$") == "99" then
				break
				end
			end

		local result = df.file_move(exported_image, myimage_name)

		if result then
			local myimage = dt.database.import(myimage_name)

			group_if_not_member(image, myimage)

			for _,tag in pairs(dt.tags.get_tags(image)) do
				if not (string.sub(tag.name,1,9) == "darktable") then
					dt.tags.attach(tag,myimage)
					end
				end
			end
		end
	end


local function program_shortcut(event, shortcut)
	local choice = tonumber(string.sub(shortcut, -1))
	OpenWith(choice)
end


dt.register_storage("exp2coll", "collection", show_status, export2collection)

dt.register_lib(
	"ext_editor",        -- module name
	"external editors",  -- name
	true,                -- expandable
	false,               -- resetable
	{[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},   -- containers
	dt.new_widget("box") -- widget
	{
    orientation = "vertical",
    combobox,
	button1
	},
	nil,-- view_enter
	nil -- view_leave
	)
	
dt.register_event("shortcut", program_shortcut, "edit with program 1") 
dt.register_event("shortcut", program_shortcut, "edit with program 2") 
dt.register_event("shortcut", program_shortcut, "edit with program 3") 
dt.register_event("shortcut", program_shortcut, "edit with program 4") 
dt.register_event("shortcut", program_shortcut, "edit with program 5") 
dt.register_event("shortcut", program_shortcut, "edit with program 6") 
dt.register_event("shortcut", program_shortcut, "edit with program 7") 
dt.register_event("shortcut", program_shortcut, "edit with program 8") 
dt.register_event("shortcut", program_shortcut, "edit with program 9") 

-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: hl Lua;
