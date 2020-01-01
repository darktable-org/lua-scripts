--[[

	DESCRIPTION
    ext_editor.lua - edit images with external editors

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
	
	-- setup --
	* in "preferences/lua options" configure name and path/command of external programs
	* note that if a program name is left empty, that and all following entries will be ignored
	* in "preferences/shortcuts/lua" configure shortcuts for external programs (optional)
	* whenever programs preferences are changed, in lighttable/external editors, press "update list"

	-- use --
    * in the export dialog choose "collection" and select the format and bit depth for the
      exported image
    * press "export"
	* the exported image will be imported into collection and grouped with the original image
    
	* select an image for editing with en external program, and:
		* in lighttable/external editors, select program and press "edit"
		* edit the image with the external editor, overwite the file, quit the external program
		* the selected image will be updated
		or
		* in lighttable/external editors, select program and press "edit a copy"
		* edit the image with the external editor, overwite the file, quit the external program
		* a copy of the selected image will be created and updated
		or
		* in lighttable select target storage "collection"
		* enter in darkroom
		* to create an export or a copy press CRTL+E
		* use the shortcut to edit the current image with the corresponding external editor
		* overwite the file, quit the external program
		* the darkroom view will be updated
	
	* warning: mouseover on lighttable/filmstrip will prevail on current image
	* this is the default DT behavior, not a bug of this script

    CAVEATS
	* MAC compatibility not tested
	
	TODO
	* send multiple images to the same program, maybe
	
    BUGS, COMMENTS, SUGGESTIONS
    * send to Marco Carrarini, marco.carrarini@gmail.com

    CHANGES
    * 20191224 - initial version
	* 20191227 - added button "update list", better error handling, fixed bug with groups/tags in "edit"
	
]]


local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local dtsys = require "lib/dtutils.system"


-- module name
local MODULE_NAME = "ext_editor"


-- check API version
du.check_min_api_version("5.0.2", MODULE_NAME)  -- darktable 3.0


-- OS compatibility
local PS = dt.configuration.running_os == "windows" and  "\\"  or  "/"


-- translation
local gettext = dt.gettext
gettext.bindtextdomain(MODULE_NAME, dt.configuration.config_dir..PS.."lua"..PS.."locale"..PS)
local function _(msgid)
  return gettext.dgettext(MODULE_NAME, msgid)
end


-- number of valid entries in the list of external programs
local n_entries


-- allowed file extensions, to exclude RAW, which cannot be edited externally
local allowed_file_types = {"JPG", "jpg", "JPEG", "jpeg", "TIF", "tif", "TIFF", "tiff", "EXR", "exr"}


-- last used editor initialization
if not dt.preferences.read(MODULE_NAME,"initialized", "bool") then
	dt.preferences.write(MODULE_NAME,"lastchoice", "integer", 0)
	dt.preferences.write(MODULE_NAME,"initialized", "bool", true)
	end 
local lastchoice = 0


-- update lists of program names and paths, as well as combobox ---------------
local function UpdateProgramList(combobox, button1, button2, update_button_pressed) 

	-- initialize lists
	program_names = {}
	program_paths = {}

	-- build lists from preferences
	local name
	local last = false
	n_entries = 0
	for i = 1, 9 do
		name = dt.preferences.read(MODULE_NAME,"program_name_"..i, "string")
		if (name == "" or name == nil) then last = true end
		if last then 
			if combobox[n_entries + 1] then combobox[n_entries + 1] = nil end -- remove extra combobox entries
		else 
			combobox[i] = i..": "..name
			program_names[i] = name
			program_paths[i] = df.sanitize_filename(dt.preferences.read(MODULE_NAME, "program_path_"..i, "string"))
			n_entries = i
			end
		end 

		lastchoice = dt.preferences.read(MODULE_NAME, "lastchoice", "integer")
		if lastchoice == 0 and n_entries > 0 then lastchoice = 1 end
		if lastchoice > n_entries then lastchoice = n_entries end
		dt.preferences.write(MODULE_NAME, "lastchoice", "integer", lastchoice)

		-- widgets enabled if there is at least one program configured
		combobox.selected = lastchoice 
		local active = n_entries > 0
        combobox.sensitive = active
        button1.sensitive = active
        button2.sensitive = active

		if update_button_pressed then dt.print(n_entries.._(" editors configured")) end
	end


-- shows export progress ------------------------------------------------------
local function show_status(storage, image, format, filename, number, total, high_quality, extra_data) 
	
	dt.print(_("exporting image ").. number.." / "..total.." ...")
	end


-- callback for buttons "edit" and "edit a copy" ------------------------------
local function OpenWith(images, choice, copy) 
		
	-- check choice is valid, return if not
	if choice > n_entries then
		dt.print(_("not a valid choice"))
		return
		end

	-- check if one image is selected, return if not
	if #images ~= 1 then
		dt.print(_("please select one image"))
		return
		end
	
	local bin = program_paths[choice]
	local friendly_name = program_names[choice]

	-- check if external program executable exists, return if not
	if not df.check_if_bin_exists(bin) then
		dt.print(friendly_name.._(" not found"))
		return
		end

	-- image to be edited
	local image
	i, image = next(images)
	local name = image.path..PS..image.filename

	-- check if image is raw, return if it is
	-- please note that the image property image.is_raw fails when filepath contains spaces
	-- so as a workaround we allow only TIF, JPG and EXR
	local file_ext = df.get_filetype (image.filename)
	local allowed = false
	for i,v in pairs(allowed_file_types) do
		if v == file_ext then
			allowed = true
			break
			end
		end	
	if not allowed then
		dt.print(_("file type not allowed"))
		return
		end

	-- save image tags, rating and color
	local tags = {}
    for i, tag in ipairs(dt.tags.get_tags(image)) do
		if not (string.sub(tag.name, 1, 9) == "darktable") then table.insert(tags, tag)	end
		end 
	local rating = image.rating
	local red = image.red
	local blue = image.blue
	local green = image.green
	local yellow = image.yellow
	local purple = image.purple

    -- new image
    local new_name = name
	local new_image = image
    
    if copy then

		-- create unique filename
		while true do -- dirty solution to workaround issue in lib function check_if_file_exists()
			if dt.configuration.running_os == "windows" then 
				if not df.check_if_file_exists(df.sanitize_filename(new_name)) then break end
			else  
				if not df.check_if_file_exists(new_name) then break end
				end
			new_name = df.filename_increment(new_name)
			-- limit to 50 more exports of the original export
			if string.match(df.get_basename(new_name), "_%d%d$") == "_50" then break end
			end
		    
	    -- physical copy, check result, return if error
	    local copy_success = df.file_copy(name, new_name)
	    if not copy_success then
		    dt.print(_("error copying file ")..name)
		    return
		    end    
        end

	-- launch the external editor, check result, return if error
	local run_cmd = bin.." "..df.sanitize_filename(new_name) 
	dt.print(_("launching ")..friendly_name.."...")	
	local result = dtsys.external_command(run_cmd)
	if result ~= 0 then
		dt.print(_("error launching ")..friendly_name)
		return
		end

    if copy then
	    -- import in database and group
	    new_image = dt.database.import(new_name)
	    new_image:group_with(image)
    else 
        -- refresh the image view
	    -- note that only image:drop_cache() is not enough to refresh view in darkroom mode
	    -- therefore image must be deleted and reimported to force refresh

        -- find the grouping status
	    local image_leader = image.group_leader
	    local group_members = image:get_group_members()
	    local new_leader
	    local index = nil
	    local found = false
	    
	    -- membership status, three different cases
	    if image_leader == image then
		    if  #group_members > 1 then
			    -- case 1: image is leader in a group with more members
		    while not found do
			    index, new_leader = next(group_members, index)
			    if new_leader ~= image_leader then found = true end
			    end
			    new_leader:make_group_leader()
			    image:delete()
			    new_image = dt.database.import(name)
			    new_image:group_with(new_leader)
			    new_image:make_group_leader()
		    else 
			    -- case 2: image is the only member in group
			    image:delete()
			    new_image = dt.database.import(name)
			    new_image:group_with()
			    end
	    else 
		    -- case 3: image is in a group but is not leader
		    image:delete()
		    new_image = dt.database.import(name)
		    new_image:group_with(image_leader)
		    end
	    -- refresh darkroom view
	    if dt.gui.current_view() == dt.gui.views.darkroom then
		    dt.gui.views.darkroom.display_image(new_image)
		    end
        end	  

	-- restore image tags, rating and color, must be put after refresh darkroom view
	for i, tag in ipairs(tags) do dt.tags.attach(tag, new_image) end
	new_image.rating = rating
	new_image.red = red
	new_image.blue = blue
	new_image.green = green
	new_image.yellow = yellow
	new_image.purple = purple

    -- select the new image
	local selection = {}
	table.insert(selection, new_image)
	dt.gui.selection (selection)

	end


-- callback function for shortcuts --------------------------------------------
local function program_shortcut(event, shortcut)
	OpenWith(dt.gui.action_images, tonumber(string.sub(shortcut, -1)), false)
	end


-- export images and reimport in collection -----------------------------------
local function export2collection(storage, image_table, extra_data) 

	local new_name, new_image, result

	for image, temp_name in pairs(image_table) do

		-- images are first exported in temp folder then moved to collection folder

		-- create unique filename
		new_name = image.path..PS..df.get_filename(temp_name)
		while true do -- dirty solution to workaround issue in lib function check_if_file_exists()
			if dt.configuration.running_os == "windows" then 
				if not df.check_if_file_exists(df.sanitize_filename(new_name)) then break end
			else  
				if not df.check_if_file_exists(new_name) then break end
				end
			new_name = df.filename_increment(new_name)
			-- limit to 50 more exports of the original export
			if string.match(df.get_basename(new_name), "_%d%d$") == "_50" then break end
			end

		-- move image to collection folder, check result, return if error
		move_success = df.file_move(temp_name, new_name)
		if not move_success then
			dt.print(_("error moving file ")..temp_name)
			return
			end

		-- import in database and group
		new_image = dt.database.import(new_name)
		new_image:group_with(image.group_leader)
		end 
	end


-- register new storage -------------------------------------------------------
-- note that placing this declaration later makes the export selected module
-- not to remember the choice "collection" when restarting DT, don't know why
dt.register_storage("exp2coll", _("collection"), show_status, export2collection)


-- combobox, with variable number of entries ----------------------------------
local combobox = dt.new_widget("combobox") {
	label = _("choose program"), 
	tooltip = _("select the external editor from the list"),
	changed_callback = function(self)
		dt.preferences.write(MODULE_NAME, "lastchoice", "integer", self.selected)
		end,
	""
	}


-- button edit ----------------------------------------------------------------
local button1 = dt.new_widget("button") {
	label = _("edit"),
	tooltip = _("open the selected image in external editor"),
	--sensitive = false,
	clicked_callback = function()
		OpenWith(dt.gui.action_images, combobox.selected, false)
		end
	}


-- button edit a copy ---------------------------------------------------------
local button2 = dt.new_widget("button") {
	label = _("edit a copy"),
	tooltip = _("create a copy of the selected image and open it in external editor"),
	clicked_callback = function()
		OpenWith(dt.gui.action_images, combobox.selected, true)
		end
	}


-- button update list ---------------------------------------------------------
local button3 = dt.new_widget("button") {
	label = _("update list"),
	tooltip = _("update list of programs if lua preferences are changed"),
	clicked_callback = function()
		UpdateProgramList(combobox, button1, button2, true)
		end
	}


-- box for the buttons --------------------------------------------------------
-- it doesn't seem there is a way to make the buttons equal in size
local box1 = dt.new_widget("box") {
    orientation = "horizontal",
	button1,
	button2,
	button3
	}


-- register new module "external editors" in lighttable ------------------------
dt.register_lib(
	MODULE_NAME,       	 	
	_("external editors"),  
	true,	-- expandable
	false,	-- resetable
	{[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},  
	dt.new_widget("box") {
		orientation = "vertical",
		combobox,
		box1
		},
	nil,	-- view_enter
	nil		-- view_leave
	)


-- initialize list of programs and widgets ------------------------------------ 
UpdateProgramList(combobox, button1, button2, false) 


-- register the new preferences -----------------------------------------------
for i = 9, 1, -1 do
	dt.preferences.register(MODULE_NAME, "program_path_"..i, "file", 
	_("executable for external editor ")..i, 
	_("select executable for external editor")	, _("(None)"))
	dt.preferences.register(MODULE_NAME, "program_name_"..i, "string", 
	_("name of external editor ")..i, 
	_("friendly name of external editor"), "")
	end


-- register the new shortcuts	-------------------------------------------------
for i = 1, 9 do
	dt.register_event("shortcut", program_shortcut, _("edit with program ")..i) 
	end


-- end of script --------------------------------------------------------------

-- vim: shiftwidth=4 expandtab tabstop=4 cindent syntax=lua
-- kate: hl Lua;
